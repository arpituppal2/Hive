import Foundation
import AppKit
import CefKit

// MARK: - HiveSchemeHandler
//
// Serves the hand-drawn web chrome (start page) over the custom `hive://`
// scheme. The HTML/CSS/JS live as real files in Sources/HiveChromium/WebChrome/
// and are inlined into WebChromeAssets.swift by Scripts/embed_webchrome.py —
// the same shipping pattern CefSwift uses for its JS bridge shim.
//
// Security (AGENTS.md §9): arbitrary web pages can fetch `cefswift://` (CORS
// `*`), so the served HTML carries a per-session token (`__HIVE_TOKEN__`
// placeholder replaced at serve time) and every bridge function demands it.

struct HiveSchemeHandler: CefSchemeHandler {
    /// Per-session token injected into the start page HTML.
    let sessionToken: String

    func response(for request: CefSchemeRequest) async -> CefSchemeResponse {
        let path = request.url?.path ?? "/"
        switch path {
        case "/", "/index.html":
            let html = WebChromeAssets.indexHTML.replacingOccurrences(
                of: "__HIVE_TOKEN__", with: sessionToken)
            return CefSchemeResponse(status: 200, mimeType: "text/html", body: Data(html.utf8))
        case "/styles.css":
            return CefSchemeResponse(status: 200, mimeType: "text/css", body: Data(WebChromeAssets.stylesCSS.utf8))
        case "/app.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(WebChromeAssets.appJS.utf8))
        default:
            return .notFound("No such asset: \(path)")
        }
    }
}

// MARK: - Bridge DTOs
//
// JSON payloads exchanged with the web chrome. All Sendable + Codable so the
// typed CefBridge.register<Input, Output> overload applies. Every request
// carries the session `token` — validated before any side effect.

struct WebChromeToken: Codable, Sendable {
    let token: String
}

struct WebChromeTopSite: Codable, Sendable {
    let host: String
    let url: String
    let faviconURL: String?
}

struct WebChromeRecentItem: Codable, Sendable {
    let title: String
    let url: String
    let host: String
    let faviconURL: String?
    let timeLabel: String
}

struct WebChromeSpace: Codable, Sendable {
    let id: String
    let name: String
    let colorHex: String
    let tabCount: Int
}

struct WebChromeStartData: Codable, Sendable {
    let topSites: [WebChromeTopSite]
    let recent: [WebChromeRecentItem]
    let spaces: [WebChromeSpace]
    let accentHex: String
}

struct WebChromeURLRequest: Codable, Sendable {
    let token: String
    let url: String
}

struct WebChromeIDRequest: Codable, Sendable {
    let token: String
    let id: String
}

struct WebChromeTextRequest: Codable, Sendable {
    let token: String
    let text: String
}

struct WebChromeSuggestion: Codable, Sendable {
    let text: String
    let url: String?
    let kind: String
    let tabID: String?
}

struct WebChromeSuggestResponse: Codable, Sendable {
    let suggestions: [WebChromeSuggestion]
}

struct WebChromeActionRequest: Codable, Sendable {
    let token: String
    let action: String
}

enum WebChromeBridgeError: Error, LocalizedError {
    case unauthorized
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Rejected bridge call: missing or invalid session token."
        case .invalidURL:   return "Rejected bridge call: URL scheme must be http or https."
        }
    }
}

// MARK: - WebChromeBridge
//
// Registers the JS ↔ Swift functions the start page calls. Every handler hops
// to the MainActor to touch ChromiumBrowserState. Input is untrusted page
// input (AGENTS.md §9.1) — validated before acting; privileged navigation is
// whitelisted to http/https; browsing data is token-gated so arbitrary pages
// cannot read history through the bridge.

enum WebChromeBridge {

    static let schemeName = "hive"

    /// Per-session token injected into the start page HTML and demanded by
    /// every bridge call. Generated once at registration.
    static let sessionToken = UUID().uuidString

    /// Whether the bridge + scheme handler have been registered. Guards
    /// against duplicate registration if a second state instance is ever
    /// created (registerSchemeHandler would otherwise re-register the scheme).
    /// MainActor-isolated like everything touching CefRuntime.shared.
    @MainActor private static var isRegistered = false

    @MainActor static func register(with state: ChromiumBrowserState) {
        guard !isRegistered else { return }
        isRegistered = true

        // Serve the web chrome assets. CefSwiftApp.main() initializes CEF
        // before SwiftUI creates the @State, so this is guaranteed — fail
        // loudly rather than silently shipping a broken start page.
        precondition(
            CefRuntime.shared.isInitialized,
            "WebChromeBridge.register must run after CEF initialization."
        )
        CefRuntime.shared.registerSchemeHandler(
            scheme: schemeName,
            handler: HiveSchemeHandler(sessionToken: sessionToken)
        )

        let bridge = CefRuntime.shared.bridge
        // Arbitrary pages must not receive the shim: only the start page
        // (which embeds it in its own HTML) gets `window.cefSwift`.
        bridge.autoInjectsShim = false

        // ---- hive.getStartData: top sites + recent + spaces ----
        bridge.register("hive.getStartData") { (request: WebChromeToken) async throws -> WebChromeStartData in
            try Self.authorize(request.token)
            return await MainActor.run {
                state.webChromeStartData()
            }
        }

        // ---- hive.navigate: load a URL in the active tab ----
        bridge.register("hive.navigate") { (request: WebChromeURLRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let url = Self.httpURL(from: request.url) else {
                throw WebChromeBridgeError.invalidURL
            }
            await MainActor.run {
                state.navigateToURL(url)
            }
            return true
        }

        // ---- hive.newTab: open a fresh start page ----
        bridge.register("hive.newTab") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                _ = state.newTab()
            }
            return true
        }

        // ---- hive.closeTab ----
        bridge.register("hive.closeTab") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                state.closeTab(id: request.id)
            }
            return true
        }

        // ---- hive.selectTab: switch to an open tab ----
        bridge.register("hive.selectTab") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                state.selectTab(id: request.id)
            }
            return true
        }

        // ---- hive.switchWorkspace ----
        bridge.register("hive.switchWorkspace") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let id = UUID(uuidString: request.id) else { return false }
            await MainActor.run {
                state.switchWorkspace(to: id)
            }
            return true
        }

        // ---- hive.submit: navigate-or-search (address bar semantics) ----
        bridge.register("hive.submit") { (request: WebChromeTextRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                state.navigateToAddress(request.text)
            }
            return true
        }

        // ---- hive.suggest: omnibox suggestions for the start page ----
        bridge.register("hive.suggest") { (request: WebChromeTextRequest) async throws -> WebChromeSuggestResponse in
            try Self.authorize(request.token)
            return await MainActor.run {
                let suggestions = state.omniboxSuggestions(for: request.text).map { s -> WebChromeSuggestion in
                    WebChromeSuggestion(
                        text: s.text,
                        url: s.url?.absoluteString,
                        kind: String(describing: s.kind),
                        tabID: s.tabID
                    )
                }
                return WebChromeSuggestResponse(suggestions: suggestions)
            }
        }

        // ---- hive.action: open panels from the footer ----
        bridge.register("hive.action") { (request: WebChromeActionRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                switch request.action {
                case "settings":
                    // Open the SwiftUI Settings scene (⌘, equivalent).
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                case "history":
                    state.isHistoryPanelOpen = true
                case "bookmarks":
                    state.openBookmarksManager()
                case "downloads":
                    state.isDownloadsPanelOpen = true
                case "commands":
                    state.openCommandPalette()
                default:
                    return
                }
            }
            return true
        }
    }

    /// Rejects calls that don't carry the per-session token.
    private static func authorize(_ token: String) throws {
        guard token == sessionToken else { throw WebChromeBridgeError.unauthorized }
    }

    /// Parses a URL from untrusted input and whitelists its scheme to
    /// http/https (never javascript:, file:, data:, or the hive scheme).
    private static func httpURL(from string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }
}
