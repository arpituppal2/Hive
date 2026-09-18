import Foundation
import Observation
import HiveCore
import CefSwiftUI

@MainActor
final class AppController: Observable {
    static var shared: AppController?

    struct TabEntry: Identifiable {
        let id: String
        let model: CefWebViewModel
        var pinned: Bool
    }

    let store: CaptureStore
    let bus = EventBus()
    private(set) var engine: AskEngine!
    var captureService: CaptureService!

    let chromeModel: CefWebViewModel
    let askModel: CefWebViewModel
    private(set) var tabs: [TabEntry] = []
    private(set) var activeTabId: String = ""
    var railCollapsed: Bool = false
    var askOpen: Bool = false

    static let startURL = URL(string: "hive://start")!

    init(store: CaptureStore? = nil) {
        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hive", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        do {
            self.store = try store ?? CaptureStore(path: docs.appendingPathComponent("hive.sqlite").path)
        } catch {
            fatalError("capture store unavailable: \(error)")   // fail loudly, never silently fake
        }
        engine = AskEngine(store: self.store, provider: Self.makeProvider())
        captureService = CaptureService(store: self.store, bus: bus)

        chromeModel = CefWebViewModel(url: URL(string: "hive://chrome?pane=shell")!)
        askModel = CefWebViewModel(url: URL(string: "hive://chrome?pane=ask")!)
        AppController.shared = self
    }

    /// AI-stack decision (W1): out-of-process OpenAI-compatible server, spawned
    /// lazily by the launcher on first ask; mock provider when HIVE_MOCK_LLM=1 or
    /// no server configured — labeled honestly either way.
    static func makeProvider() -> LLMProvider {
        let env = ProcessInfo.processInfo.environment
        if env["HIVE_MOCK_LLM"] == "1" { return MockLLM() }
        if let base = env["HIVE_LLM_ENDPOINT"], !base.isEmpty {
            return HTTPLLM(endpoint: URL(string: base)!.appending(path: "chat/completions"),
                           model: env["HIVE_LLM_MODEL"] ?? "qwen3-4b",
                           label: "http:\(env["HIVE_LLM_MODEL"] ?? "qwen3-4b")")
        }
        return MockLLM()   // honest fallback until weights/server configured (W2 bring-up)
    }

    // MARK: Boot

    func bootstrap() async {
        railCollapsed = store.setting("railCollapsed") == "true"
        askOpen = store.setting("askPanelOpen") == "true"
        BridgeInstaller.register(controller: self)
        restoreSession()
    }

    func persistSetting(_ key: String, _ value: String) {
        store.setSetting(key, value)
    }

    // MARK: Tabs

    @discardableResult
    func newTab(url: URL? = nil, activate: Bool = true, pinned: Bool = false) -> TabEntry {
        let entry = TabEntry(id: UUID().uuidString,
                             model: CefWebViewModel(url: url ?? Self.startURL),
                             pinned: pinned)
        tabs.append(entry)
        if activate || tabs.count == 1 { activeTabId = entry.id }
        watchLoad(entry)
        emitState(); saveSession()
        return entry
    }

    func closeActiveTab() { closeTab(id: activeTabId) }

    func closeTab(id: String) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = id == activeTabId
        tabs.remove(at: idx)
        if tabs.isEmpty { newTab() ; return }   // ≥1 tab always (CHROME-SPEC)
        if wasActive {
            activeTabId = tabs[max(0, idx - 1)].id
        }
        emitState(); saveSession()
    }

    func selectTab(id: String) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabId = id
        emitState(); saveSession()
    }

    var activeTab: TabEntry? { tabs.first(where: { $0.id == activeTabId }) }

    func tabInfos() -> [TabInfo] {
        tabs.map { TabInfo(id: $0.id, url: $0.model.url?.absoluteString ?? "",
                           title: $0.model.title.isEmpty ? "New Tab" : $0.model.title,
                           pinned: $0.pinned, active: $0.id == activeTabId) }
    }

    // MARK: Navigation

    nonisolated static func httpURL(from text: String) -> URL? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let u = URL(string: t), let scheme = u.scheme?.lowercased(),
           scheme == "http" || scheme == "https", u.host() != nil { return u }
        if t.contains(".") && !t.contains(" "), let u = URL(string: "https://\(t)"), u.host() != nil { return u }
        return nil
    }

    nonisolated static func searchURL(for text: String) -> URL {
        URL(string: "https://duckduckgo.com/?q=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
    }

    func navigateActive(to raw: String) -> Bool {
        guard let tab = activeTab else { return false }
        let url = Self.httpURL(from: raw) ?? Self.searchURL(for: raw)
        bus.emit("nav.started", ["url": .string(url.absoluteString)])
        tab.model.url = url
        Task { @MainActor in await self.awaitLoadEnd(tab) }
        return true
    }

    func goBack() { activeTab?.model.browser?.goBack() }
    func goForward() { activeTab?.model.browser?.goForward() }
    func reloadActive() { activeTab?.model.browser?.reload() }

    private func watchLoad(_ entry: TabEntry) {
        entry.model.onConsoleMessage = { [weak self] _ in }   // reserved for debug surface
        Task { await awaitLoadEnd(entry) }
    }

    private func awaitLoadEnd(_ entry: TabEntry) async {
        bus.emit("state.changed", ["loading": .bool(true)])
        while entry.model.isLoading { try? await Task.sleep(nanoseconds: 80_000_000) }
        bus.emit("nav.finished", [
            "url": .string(entry.model.url?.absoluteString ?? ""),
            "title": .string(entry.model.title),
            "tabId": .string(entry.id),
        ])
        emitState(); saveSession()
    }

    // MARK: Omnibox / bookmarks / settings

    func omniboxSubmit(_ text: String) -> [String: JSONValue] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.httpURL(from: trimmed) != nil {
            _ = navigateActive(to: trimmed)
            return ["action": .string("navigate")]
        }
        _ = navigateActive(to: trimmed)
        return ["action": .string("search")]
    }

    func suggestions(for query: String) -> [[String: JSONValue]] {
        var out: [[String: JSONValue]] = []
        let q = query.lowercased()
        if q.isEmpty {
            for c in (try? store.recentCaptures(limit: 6)) ?? [] {
                out.append(["kind": .string("capture"), "title": .string(c.title),
                            "url": .string(c.url)])
            }
            return Array(out.prefix(6))
        }
        for b in (try? store.bookmarks()) ?? [] where b.title.lowercased().contains(q) || b.url.lowercased().contains(q) {
            out.append(["kind": .string("bookmark"), "title": .string(b.title), "url": .string(b.url)])
            if out.count >= 6 { return out }
        }
        for c in (try? store.recentCaptures(limit: 40)) ?? [] where c.title.lowercased().contains(q) {
            out.append(["kind": .string("capture"), "title": .string(c.title), "url": .string(c.url)])
            if out.count >= 6 { return out }
        }
        return out
    }

    func toggleBookmarkActive() {
        guard let tab = activeTab, let url = tab.model.url?.absoluteString, url.hasPrefix("http") else { return }
        let title = tab.model.title.isEmpty ? url : tab.model.title
        if (try? store.isBookmarked(url: url)) == true {
            try? store.removeBookmark(url: url)
        } else {
            _ = try? store.addBookmark(url: url, title: title)
        }
        bus.emit("state.changed", [:])
    }

    func toggleRail() {
        railCollapsed.toggle()
        persistSetting("railCollapsed", railCollapsed ? "true" : "false")
        bus.emit("state.changed", [:])
    }

    func toggleAsk() {
        askOpen.toggle()
        persistSetting("askPanelOpen", askOpen ? "true" : "false")
        bus.emit("state.changed", [:])
    }

    func captureActiveTab() { captureService.requestCapture(controller: self, tabId: nil) }

    func focusOmnibox() {
        chromeModel.browser?.executeJavaScript(
            "document.querySelector('[data-testid=\"omnibox\"]')?.focus()")
    }

    // MARK: Session (crash-only contract)

    func saveSession() {
        try? store.saveSession(tabs: tabInfos())
    }
    func flushSession() { saveSession() }

    private func restoreSession() {
        let restored = (try? store.loadSession()) ?? []
        if restored.isEmpty {
            newTab()
        } else {
            for info in restored {
                let url = URL(string: info.url).flatMap { $0.scheme == nil ? nil : $0 } ?? Self.startURL
                let entry = TabEntry(id: info.id,
                                     model: CefWebViewModel(url: url),
                                     pinned: info.pinned)
                tabs.append(entry)
                watchLoad(entry)
                if info.active { activeTabId = entry.id }
            }
            if activeTabId.isEmpty { activeTabId = tabs[0].id }
        }
    }

    func emitState() {
        bus.emit("state.changed", ["loading": .bool(activeTab?.model.isLoading ?? false)])
    }
}
