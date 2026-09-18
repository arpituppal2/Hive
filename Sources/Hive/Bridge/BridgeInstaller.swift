import Foundation
import CefKit
import HiveCore

public struct BridgeUnit: Codable, Sendable { public init() {} }

/// Per-launch bridge tokens. Arbitrary web content can never obtain these:
/// they exist only inside documents served by `HiveSchemeHandler`, and every
/// bridge call must present the right one.
struct TokenVault {
    let shell = UUID().uuidString
    let page = UUID().uuidString
}

/// Registers the `hive://` scheme handler and every bridge method.
/// All handlers hop to the MainActor (AppController is @MainActor).
enum BridgeInstaller {
    nonisolated(unsafe) private static var registered = false

    @MainActor
    static func register(controller: AppController) {
        precondition(CefRuntime.shared.isInitialized,
                     "BridgeInstaller.register must run after CEF initialization.")
        if registered { return }
        registered = true

        let tokens = TokenVault()
        let cs = controller.captureService!

        CefRuntime.shared.registerSchemeHandler(
            scheme: "hive",
            handler: HiveSchemeHandler(
                shellToken: tokens.shell,
                pageToken: tokens.page,
                readerProvider: { capID in
                    guard let cap = try? controller.store.capture(id: capID) else { return nil }
                    let spans = (try? controller.store.allSpans()) ?? []
                    return ReaderDocument(
                        title: cap.title,
                        host: URL(string: cap.url)?.host() ?? cap.url,
                        capturedAt: cap.capturedAt,
                        text: cap.text,
                        spans: spans.filter { $0.captureId == capID }
                            .map { ($0.id, $0.charStart, $0.charEnd) },
                        highlight: nil)
                }))

        let bridge = CefRuntime.shared.bridge
        bridge.autoInjectsShim = false   // only hive:// pages embed their own shim

        // MARK: tabs.*
        struct CreateReq: Decodable, Sendable { var token: String; var url: String? }
        struct IDReq: Decodable, Sendable { var token: String; var id: String }
        struct Empty: Decodable, Sendable { var token: String }

        bridge.register("tabs.create") { (req: CreateReq) in
            await mainEnvelope(req.token, tokens) {
                let url = req.url.flatMap { navURL(fromString: $0) }
                let tab = controller.newTab(url: url ?? AppController.startURL)
                return TabInfo(id: tab.id,
                               url: tab.model.url?.absoluteString ?? "",
                               title: tab.model.title.isEmpty ? "New Tab" : tab.model.title,
                               pinned: tab.pinned,
                               active: tab.id == controller.activeTabId)
            }
        }
        bridge.register("tabs.select") { (req: IDReq) in
            await mainEnvelope(req.token, tokens) {
                controller.selectTab(id: req.id)
                return TabListDTO(controller.tabInfos(), active: controller.activeTabId)
            }
        }
        bridge.register("tabs.close") { (req: IDReq) in
            await mainEnvelope(req.token, tokens) {
                controller.closeTab(id: req.id); return BridgeUnit()
            }
        }
        bridge.register("tabs.list") { (req: Empty) in
            await mainEnvelope(req.token, tokens) {
                TabListDTO(controller.tabInfos(), active: controller.activeTabId)
            }
        }

        // MARK: nav.*
        struct GoReq: Decodable, Sendable { var token: String; var url: String }
        bridge.register("nav.go") { (req: GoReq) in
            await mainEnvelope(req.token, tokens) {
                _ = controller.navigateActive(to: req.url)   // URL-detect + search fallback live here
                return BridgeUnit()
            }
        }
        bridge.register("nav.back") { (req: Empty) in
            await mainEnvelope(req.token, tokens) { controller.goBack(); return BridgeUnit() }
        }
        bridge.register("nav.forward") { (req: Empty) in
            await mainEnvelope(req.token, tokens) { controller.goForward(); return BridgeUnit() }
        }
        bridge.register("nav.reload") { (req: Empty) in
            await mainEnvelope(req.token, tokens) { controller.reloadActive(); return BridgeUnit() }
        }

        // MARK: omnibox.*
        struct SubmitReq: Decodable, Sendable { var token: String; var text: String }
        bridge.register("omnibox.submit") { (req: SubmitReq) in
            await mainEnvelope(req.token, tokens) { controller.omniboxSubmit(req.text) }
        }
        struct SuggestReq: Decodable, Sendable { var token: String; var query: String }
        bridge.register("omnibox.suggest") { (req: SuggestReq) in
            await mainEnvelope(req.token, tokens) { controller.suggestions(for: req.query) }
        }

        // MARK: bookmark.*
        struct AddBM: Decodable, Sendable { var token: String; var url: String; var title: String? }
        bridge.register("bookmark.add") { (req: AddBM) in
            await mainEnvelope(req.token, tokens) {
                guard let url = AppController.httpURL(from: req.url) else {
                    throw BridgeReject.invalidURL
                }
                _ = try controller.store.addBookmark(url: url.absoluteString,
                                                     title: req.title ?? url.host() ?? req.url)
                return BridgeUnit()
            }
        }
        bridge.register("bookmark.list") { (req: Empty) in
            await mainEnvelope(req.token, tokens) {
                (try controller.store.bookmarks()).map { BookmarkDTO(url: $0.url, title: $0.title) }
            }
        }
        struct RmBM: Decodable, Sendable { var token: String; var url: String }
        bridge.register("bookmark.remove") { (req: RmBM) in
            await mainEnvelope(req.token, tokens) {
                try controller.store.removeBookmark(url: req.url); return BridgeUnit()
            }
        }

        // MARK: capture.*
        struct CapReq: Decodable, Sendable { var token: String; var tabId: String? }
        bridge.register("capture.request") { (req: CapReq) in
            await mainEnvelope(req.token, tokens) {
                cs.requestCapture(controller: controller, tabId: req.tabId)
                return BridgeUnit()
            }
        }
        struct RawSave: Decodable, Sendable { var token: String; var url: String; var title: String?; var text: String? }
        bridge.register("capture.rawSave") { (req: RawSave) in
            await mainEnvelope(req.token, tokens, needShell: true) {
                cs.requestRawText(controller: controller, tabId: nil)   // native pulls visible text itself
                return CaptureDTO(captureId: -1, url: req.url, title: req.title ?? "",
                                  wordCount: 0, confidence: 0)
            }
        }
        struct PageResult: Decodable, Sendable {
            var id: String; var title: String?; var text: String?; var error: String?
        }
        bridge.register("capture.pageResult") { (req: PageResult) in
            await mainEnvelope("", tokens, skipAuth: true) {
                var p: [String: JSONValue] = [:]
                if let ti = req.title { p["title"] = .string(ti) }
                if let tx = req.text { p["text"] = .string(tx) }
                if let e = req.error { p["error"] = .string(e) }
                cs.handlePageResult(id: req.id, payload: p)
                return BridgeUnit()
            }
        }
        struct RecentReq: Decodable, Sendable { var token: String; var limit: Int? }
        bridge.register("captures.recent") { (req: RecentReq) in
            await mainEnvelope(req.token, tokens) {
                (try controller.store.recentCaptures(limit: min(req.limit ?? 8, 50))).map {
                    CaptureDTO(captureId: Int($0.id), url: $0.url, title: $0.title,
                               wordCount: $0.wordCount, confidence: $0.confidence)
                }
            }
        }

        // MARK: ask.*
        struct AskReq: Decodable, Sendable { var token: String; var question: String }
        bridge.register("ask.request") { (req: AskReq) in
            await mainEnvelope(req.token, tokens) {
                let askId = UUID().uuidString
                let engine = controller.engine!
                let bus = controller.bus
                Task.detached {
                    let terminal: AskEngine.Terminal
                    do {
                        terminal = try await engine.run(askId: askId, question: req.question) { delta in
                            bus.emit("ask.chunk", ["askId": .string(askId), "delta": .string(delta)])
                        }
                    } catch {
                        bus.emit("ask.refused", ["askId": .string(askId),
                                                 "flavor": .string("no-support"),
                                                 "message": .string("Generation failed - Try again.")])
                        return
                    }
                    switch terminal {
                    case .done(let answer, let citations, let dropped):
                        bus.emit("ask.done", [
                            "askId": .string(askId),
                            "answer": .string(answer),
                            "citations": .array(citations.map { .object([
                                "spanId": .string($0.spanId),
                                "captureId": .int(Int($0.captureId)),
                                "quote": .string($0.quote),
                            ])}),
                            "droppedClaims": .array(dropped.map(JSONValue.string)),
                        ])
                    case .refused(let flavor, let message):
                        bus.emit("ask.refused", ["askId": .string(askId),
                                                 "flavor": .string(flavor),
                                                 "message": .string(message)])
                    }
                }
                return AskStartedDTO(askId: askId)
            }
        }
        struct CancelReq: Decodable, Sendable { var token: String; var askId: String }
        bridge.register("ask.cancel") { (req: CancelReq) in
            await mainEnvelope(req.token, tokens) {
                Task { await controller.engine.cancel(askId: req.askId) }
                return BridgeUnit()
            }
        }

        // MARK: settings.*
        struct GetReq: Decodable, Sendable { var token: String; var keys: [String]? }
        bridge.register("settings.get") { (req: GetReq) in
            await mainEnvelope(req.token, tokens) {
                var out: [String: JSONValue] = [:]
                for key in ["railCollapsed", "tabOrientation", "askPanelOpen", "telemetryOptIn"] {
                    if let v = controller.store.setting(key) {
                        out[key] = v == "true" ? .bool(true) : (v == "false" ? .bool(false) : .string(v))
                    } else if key == "tabOrientation" {
                        out[key] = .string("vertical")
                    } else {
                        out[key] = .bool(false)
                    }
                }
                return out
            }
        }
        struct SetReq: Decodable, Sendable { var token: String; var patch: [String: JSONValue] }
        bridge.register("settings.set") { (req: SetReq) in
            await mainEnvelope(req.token, tokens, needShell: true) {
                for (k, v) in req.patch {
                    switch v {
                    case .bool(let b):
                        controller.persistSetting(k, b ? "true" : "false")
                        if k == "railCollapsed" { controller.railCollapsed = b }
                        if k == "askPanelOpen" { controller.askOpen = b }
                    case .string(let s): controller.persistSetting(k, s)
                    default: continue
                    }
                }
                return BridgeUnit()
            }
        }

        // MARK: session / events / captures / reader
        bridge.register("session.restore") { (req: Empty) in
            await mainEnvelope(req.token, tokens) {
                let tabs = controller.tabInfos()
                let payload: [String: JSONValue] = ["restored": .bool(!tabs.isEmpty),
                                                    "tabs": .int(tabs.count)]
                return payload
            }
        }
        struct EventsReq: Decodable, Sendable { var token: String; var cursor: Int }
        bridge.register("events.get") { (req: EventsReq) in
            await mainEnvelope(req.token, tokens) {
                let r = controller.bus.since(req.cursor)
                return EventsDTO(cursor: r.cursor,
                                 events: r.events.map { EventDTO(id: $0.id, type: $0.type, payload: $0.payload) })
            }
        }
        struct OpenSpan: Decodable, Sendable { var token: String; var spanId: String; var captureId: Int64? }
        bridge.register("reader.open") { (req: OpenSpan) in
            await mainEnvelope(req.token, tokens, needShell: true) {
                let spanIdx = req.spanId.split(separator: ":").last.map(String.init)
                var comps = URLComponents(string: "hive://reader")!
                comps.queryItems = [
                    URLQueryItem(name: "capture", value: "\(req.captureId ?? -1)"),
                    URLQueryItem(name: "span", value: spanIdx ?? ""),
                ]
                _ = controller.newTab(url: comps.url!)
                return BridgeUnit()
            }
        }
    }

    // MARK: plumbing

    private enum BridgeReject: Error {
        case unauthorized, invalidURL, badPayload
    }

    /// Single MainActor hop + auth + error mapping for every handler.
    private static func mainEnvelope<T: Codable & Sendable>(
        _ token: String, _ vault: TokenVault, needShell: Bool = false, skipAuth: Bool = false,
        _ body: @MainActor () throws -> T
    ) async -> Envelope<T> {
        await MainActor.run {
            do {
                if !skipAuth {
                    let ok = needShell ? (token == vault.shell)
                                       : (token == vault.shell || token == vault.page)
                    guard ok else { return .fail("unauthorized", "bad or missing token") }
                }
                return .ok(try body())
            } catch BridgeReject.invalidURL {
                return .fail("invalidURL", "only http(s) URLs are navigable")
            } catch BridgeReject.badPayload {
                return .fail("badPayload", "malformed payload")
            } catch {
                return .fail("storeError", "\(error)")
            }
        }
    }

    private static func navURL(fromString s: String) -> URL? {
        if s.hasPrefix("hive://") { return URL(string: s) }   // internal routes explicit only
        return AppController.httpURL(from: s)
    }
}

// MARK: - DTOs

struct TabListDTO: Codable, Sendable {
    var tabs: [TabInfo]; var activeId: String
    init(_ tabs: [TabInfo], active: String) { self.tabs = tabs; self.activeId = active }
}

struct BookmarkDTO: Codable, Sendable { var url: String; var title: String }

struct CaptureDTO: Codable, Sendable {
    var captureId: Int; var url: String; var title: String; var wordCount: Int; var confidence: Double
}

struct AskStartedDTO: Codable, Sendable { var askId: String }

struct EventDTO: Codable, Sendable {
    var id: Int; var type: String; var payload: [String: JSONValue]
}

struct EventsDTO: Codable, Sendable {
    var cursor: Int; var events: [EventDTO]
}
