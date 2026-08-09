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

    /// Supplies the Morning Brief JSON (real browsing data) at serve time.
    /// Set at registration; falls back to an empty brief if unavailable.
    /// Async: the scheme handler runs on a CEF IO thread, so the provider
    /// hops to MainActor to read BrowserState (never assumeIsolated).
    var briefJSONProvider: (@Sendable () async -> String)? = nil

    func response(for request: CefSchemeRequest) async -> CefSchemeResponse {
        let url = request.url
        let host = url?.host?.lowercased() ?? ""
        let path = url?.path ?? "/"

        // The Morning Brief lives at hive://brief/... — where "brief" is the
        // *host*, not a path segment. Route by host first so the brief shell
        // and its relative assets (style.css, app.js, fonts/…) all resolve.
        if host == "brief" || path.hasPrefix("/brief") {
            return await briefResponse(path: path)
        }

        // Polar AgentApp — full streaming agent surface with KaTeX, mermaid,
        // xlsx, docx rendering (copied from the Polar app bundle, legally
        // authorized). Served at hive://polar as a standalone agent workspace.
        if host == "polar" || path.hasPrefix("/polar") {
            return await polarResponse(path: path)
        }

        switch path {
        case "/", "/index.html", "/start":
            let html = WebChromeAssets.indexHTML.replacingOccurrences(
                of: "__HIVE_TOKEN__", with: sessionToken)
            return CefSchemeResponse(status: 200, mimeType: "text/html", body: Data(html.utf8))
        case "/styles.css":
            return CefSchemeResponse(status: 200, mimeType: "text/css", body: Data(WebChromeAssets.stylesCSS.utf8))
        case "/tokens.css":
            return CefSchemeResponse(status: 200, mimeType: "text/css", body: Data(WebChromeAssets.tokensCSS.utf8))
        case "/app.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(WebChromeAssets.appJS.utf8))
        default:
            return .notFound("No such asset: \(path)")
        }
    }

    /// Serves the Polar AgentApp — a full streaming agent surface with
    /// KaTeX math, mermaid diagrams, xlsx/docx preview, command panel,
    /// and agent workspace components. Copied from Polar's production
    /// Vite-bundled assets under explicit legal authorization.
    private func polarResponse(path: String) async -> CefSchemeResponse {
        let cleaned = path.hasPrefix("/polar") ? String(path.dropFirst(6)) : path
        let assetPath = cleaned == "/" || cleaned.isEmpty ? "/index.html" : cleaned
        switch assetPath {
        case "/", "/index.html":
            let branded = WebChromeAssets.polarIndex.replacingOccurrences(of: "Polar", with: "Hive")
            return CefSchemeResponse(status: 200, mimeType: "text/html", body: Data(branded.utf8))
        case "/assets/index-BY6JzNer.css":
            return CefSchemeResponse(status: 200, mimeType: "text/css", body: Data(WebChromeAssets.polarCSS.utf8))
        case "/assets/index-QWD3Wno1.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarAppJSBase64) ?? Data())
        case "/assets/agentSurface-TavgROI7.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarAgentSurfaceJSBase64) ?? Data())
        case "/assets/CommandPanelPage-CQPc9sFE.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarCommandPanelJSBase64) ?? Data())
        case "/assets/ModalAgentAppPage-DT0g5KTd.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarModalJSBase64) ?? Data())
        case "/assets/WindowAgentAppPage-CzJKotYB.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarWindowJSBase64) ?? Data())
        // Extended Polar assets (docx, mermaid, xlsx renderers, highlighted body, referral cards)
        case "/assets/docx-preview-ChFBTZoq.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarDocxJSBase64) ?? Data())
        case "/assets/mermaid-GHXKKRXX-D0lw7t8a.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarMermaidJSBase64) ?? Data())
        case "/assets/xlsx-CkFp8p6R.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarXlsxJSBase64) ?? Data())
        case "/assets/highlighted-body-OFNGDK62-BsqO-kRD.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarHighlightedBodyJSBase64) ?? Data())
        case "/assets/ReferralCardPreviewPage-CDEMiD_U.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarReferralCardJSBase64) ?? Data())
        case "/assets/ReferralMilestoneCard-DwOWE_LT.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(base64Encoded: WebChromeAssets.polarReferralMilestoneJSBase64) ?? Data())
        case "/assets/invite-envelope-n37wvGqS.png":
            if let data = Data(base64Encoded: WebChromeAssets.polarInvitePNGBase64) {
                return CefSchemeResponse(status: 200, mimeType: "image/png", body: data)
            }
            return .notFound("Corrupt invite envelope PNG")
        default:
            // KaTeX fonts served from fontBase64 (e.g. /assets/KaTeX_Main-Regular-B22Nviop.woff2)
            if assetPath.hasPrefix("/assets/KaTeX_") {
                let fontName = "polar" + assetPath.replacingOccurrences(of: "/assets/", with: "/")
                if let (base64, mime) = WebChromeAssets.fontBase64[fontName],
                   let data = Data(base64Encoded: base64) {
                    return CefSchemeResponse(status: 200, mimeType: mime, body: data)
                }
            }
            return .notFound("No such Polar asset: \(assetPath)")
        }
    }

    /// Serves the Morning Brief shell + its relative assets.
    private func briefResponse(path: String) async -> CefSchemeResponse {
        switch path {
        case "/", "/index.html":
            // The brief is a JSON-driven static template: the HTML holds a
            // __HIVE_BRIEF_JSON__ placeholder that we fill with real browsing
            // data at serve time. Zero JS surgery on the copied template.
            let json = await briefJSONProvider?() ?? "{}"
            let html = WebChromeAssets.briefHTML.replacingOccurrences(
                of: "__HIVE_BRIEF_JSON__", with: json)
            return CefSchemeResponse(status: 200, mimeType: "text/html", body: Data(html.utf8))
        case "/style.css":
            return CefSchemeResponse(status: 200, mimeType: "text/css", body: Data(WebChromeAssets.briefCSS.utf8))
        case "/feedback.css":
            return CefSchemeResponse(status: 200, mimeType: "text/css", body: Data(WebChromeAssets.briefFeedbackCSS.utf8))
        case "/looking-ahead.css":
            return CefSchemeResponse(status: 200, mimeType: "text/css", body: Data(WebChromeAssets.briefLookingAheadCSS.utf8))
        case "/app.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(WebChromeAssets.briefAppJS.utf8))
        case "/feedback.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(WebChromeAssets.briefFeedbackJS.utf8))
        case "/looking-ahead.js":
            return CefSchemeResponse(status: 200, mimeType: "application/javascript", body: Data(WebChromeAssets.briefLookingAheadJS.utf8))
        default:
            if path.hasPrefix("/fonts/") {
                let fontName = path.replacingOccurrences(of: "/fonts/", with: "")
                if let (base64, mime) = WebChromeAssets.fontBase64[fontName],
                   let data = Data(base64Encoded: base64) {
                    return CefSchemeResponse(status: 200, mimeType: mime, body: data)
                }
            }
            return .notFound("No such asset: \(path)")
        }
    }
}

// MARK: - WebChromeBridge
//
// Registers the JS ↔ Swift functions the start page calls. Every handler hops
// to the MainActor to touch BrowserState. Input is untrusted page
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

    @MainActor static func register(with state: BrowserState) {
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
            handler: HiveSchemeHandler(
                sessionToken: sessionToken,
                briefJSONProvider: {
                    // Filled lazily at serve time with real browsing data.
                    // BrowserState is @MainActor and the scheme handler runs
                    // on a CEF IO thread, so hop to the main actor.
                    await MainActor.run {
                        state.buildBriefJSON()
                    }
                }
            )
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

        // ---- hive.back / hive.forward / hive.reload / hive.stop ----
        bridge.register("hive.back") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.goBack() }
            return true
        }
        bridge.register("hive.forward") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.goForward() }
            return true
        }
        bridge.register("hive.reload") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.reload() }
            return true
        }
        bridge.register("hive.stop") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.stop() }
            return true
        }

        // ---- hive.pinTab / hive.duplicateTab / hive.closeOtherTabs ----
        bridge.register("hive.pinTab") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.togglePinTab(id: request.id) }
            return true
        }
        bridge.register("hive.duplicateTab") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.duplicateTab(id: request.id) }
            return true
        }
        bridge.register("hive.closeOtherTabs") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.closeOtherTabs(id: request.id) }
            return true
        }

        // ---- hive.reorderTab: move a tab to a new index ----
        bridge.register("hive.reorderTab") { (request: WebChromeReorderRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.moveTab(id: request.from, to: request.to) }
            return true
        }

        // ---- hive.setLayout: vertical ⇄ horizontal chrome ----
        bridge.register("hive.setLayout") { (request: WebChromeLayoutRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                switch request.mode {
                case "horizontal":
                    state.layout = .horizontal
                    state.chromeMode = .strip
                    state.chromeDimension = state.chromeDefaultDimension
                case "vertical":
                    state.layout = .vertical
                    state.chromeMode = .sidebar
                    state.chromeDimension = state.chromeDefaultDimension
                default:
                    break
                }
            }
            return true
        }

        // ---- hive.setPanel: open/close an in-chrome panel ----
        bridge.register("hive.setPanel") { (request: WebChromePanelRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                state.setChromePanel(request.panel.isEmpty ? nil : request.panel)
            }
            return true
        }

        // ---- hive.sidecar.open: open the Comet-style sidecar agent panel ----
        bridge.register("hive.sidecar.open") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.setChromePanel("sidecar") }
            return true
        }

        // ---- hive.sidecar.close: close the sidecar panel ----
        bridge.register("hive.sidecar.close") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.setChromePanel(nil) }
            return true
        }

        // ---- hive.setChromeDimension: sidebar width or strip height (CSS px) ----
        bridge.register("hive.setChromeDimension") { (request: WebChromeDimensionRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                state.chromeDimension = max(48, min(request.dimension, 900))
            }
            return true
        }

        // ---- hive.toggleBookmark: star the active page ----
        bridge.register("hive.toggleBookmark") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            return await MainActor.run {
                state.toggleBookmarkCurrentPage()
            }
        }

        // ---- hive.openSettingsWeb: in-chrome settings (no SwiftUI scene) ----
        bridge.register("hive.openSettingsWeb") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.setChromePanel("settings") }
            return true
        }

        // ---- hive.clearHistory: wipe browsing history ----
        bridge.register("hive.clearHistory") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            return await MainActor.run { state.clearBrowsingHistory() > 0 }
        }

        // ---- hive.removeBookmark: drop a bookmark by id ----
        bridge.register("hive.removeBookmark") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let id = UUID(uuidString: request.id) else { return false }
            return await MainActor.run {
                state.deleteBookmark(id: id)
                return true
            }
        }

        // ---- hive.openDownload: reopen a terminal download's source ----
        bridge.register("hive.openDownload") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let id = UUID(uuidString: request.id) else { return false }
            await MainActor.run { state.openDownloadSource(id: id) }
            return true
        }

        // ---- hive.reopenClosedTab: bring back the last closed tab (⌘⇧T) ----
        bridge.register("hive.reopenClosedTab") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.reopenLastClosed() }
            return true
        }

        // ---- hive.newPrivateTab: fresh incognito tab (⇧⌘N) ----
        bridge.register("hive.newPrivateTab") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.newPrivateTab() }
            return true
        }

        // ---- hive.toggleSplit: side-by-side with the active tab ----
        bridge.register("hive.toggleSplit") { (request: WebChromeToken) async throws -> Bool in

        // ---- hive.conveneCouncil: dispatch parallel AI model council ----
        bridge.register("hive.conveneCouncil") { (request: WebChromeTextRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard !request.text.isEmpty else { return false }
            await MainActor.run {
                let question = request.text
                let pageContext = state.activePageContext?.text
                Task { @MainActor in
                    await state.conveneCouncil(question: question, pageContext: pageContext)
                }
            }
            return true
        }

        // ---- hive.dismissCouncilVerdict: clear the AI council verdict ----
        bridge.register("hive.dismissCouncilVerdict") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.dismissCouncilVerdict() }
            return true
        }

        // ---- hive.agent.run: unified agent pipeline (council → research → actions) ----
        bridge.register("hive.agent.run") { (request: WebChromeTextRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard !request.text.isEmpty else { return false }
            await MainActor.run {
                state.runAgentPipeline(question: request.text)
            }
            return true
        }

        // ---- hive.agent.cancel: cancel the running agent pipeline ----
        bridge.register("hive.agent.cancel") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.cancelAgentPipeline() }
            return true
        }
            try Self.authorize(request.token)
            await MainActor.run {
                if let activeID = state.activeTabID {
                    state.toggleSplitWithActiveTab(id: activeID)
                }
            }
            return true
        }

        // ---- hive.toggleCompact: hide the chrome (focus mode) ----
        bridge.register("hive.toggleCompact") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.toggleCompactMode() }
            return true
        }

        // ---- hive.newWindow: open a fresh browser window (⌘N) ----
        bridge.register("hive.newWindow") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Notification.Name("HiveRequestNewWindow"),
                    object: nil
                )
            }
            return true
        }

        // ---- hive.goBack / hive.goForward: history navigation ----
        bridge.register("hive.goBack") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.goBack() }
            return true
        }
        bridge.register("hive.goForward") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.goForward() }
            return true
        }

        // ---- hive.togglePin: pin/unpin a tab ----
        bridge.register("hive.togglePin") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.togglePinTab(id: request.id) }
            return true
        }

        // ---- hive.toggleEssential: mark/unmark a tab as essential ----
        bridge.register("hive.toggleEssential") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.toggleEssentialTab(id: request.id) }
            return true
        }

        // ---- hive.createWorkspace: add a new space ----
        bridge.register("hive.createWorkspace") { (request: WebChromeWorkspaceRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                _ = state.addWorkspace(
                    name: request.name,
                    colorHex: request.colorHex ?? "#F97316",
                    iconName: request.iconName ?? "circle.fill"
                )
            }
            return true
        }

        // ---- hive.deleteWorkspace: remove a space (state guards ≥1 remaining) ----
        bridge.register("hive.deleteWorkspace") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let id = UUID(uuidString: request.id) else { return false }
            await MainActor.run { state.deleteWorkspace(id: id) }
            return true
        }

        // ---- hive.setAccent: recolor the chrome (persisted via setAccentColor) ----
        bridge.register("hive.setAccent") { (request: WebChromeAccentRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.setAccentColor(hex: request.hex) }
            return true
        }

        // ---- hive.openBookmarksManager: native SwiftUI bookmarks sheet ----
        bridge.register("hive.openBookmarksManager") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.openBookmarksManager() }
            return true
        }

        // ---- hive.openSettingsNative: SwiftUI Settings scene (⌘,) ----
        bridge.register("hive.openSettingsNative") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            return true
        }

        // ---- hive.searchHistory: substring match over browsing history ----
        bridge.register("hive.searchHistory") { (request: WebChromeSearchRequest) async throws -> [WebChromeRecentItem] in
            try Self.authorize(request.token)
            return await MainActor.run {
                let query = request.query.lowercased()
                guard !query.isEmpty else { return [] }
                return state.historyItems
                    .filter {
                        $0.title.lowercased().contains(query) ||
                        $0.url.absoluteString.lowercased().contains(query)
                    }
                    .suffix(40)
                    .reversed()
                    .map { item -> WebChromeRecentItem in
                        WebChromeRecentItem(
                            title: item.title,
                            url: item.url.absoluteString,
                            host: item.url.host ?? "",
                            faviconURL: item.faviconURL?.absoluteString,
                            timeLabel: item.visitedAt.formatted(.relative(presentation: .named))
                        )
                    }
            }
        }

        // ---- hive.closeWindow: close the key window (⌘W equivalent) ----
        bridge.register("hive.closeWindow") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run {
                NSApp.keyWindow?.performClose(nil)
            }
            return true
        }

        // ---- hive.toggleFullscreen: enter/exit native full screen ----
        bridge.register("hive.toggleFullscreen") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.toggleFullscreen() }
            return true
        }

        // ---- hive.copyLink: copy a URL to the clipboard (http/https only) ----
        bridge.register("hive.copyLink") { (request: WebChromeURLRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard Self.httpURL(from: request.url) != nil else { return false }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(request.url, forType: .string)
            return true
        }

        // ---- hive.snapshotSession: capture the current window as a snapshot ----
        bridge.register("hive.snapshotSession") { (request: WebChromeToken) async throws -> Bool in
            try Self.authorize(request.token)
            return await MainActor.run {
                let tabs = state.tabs.map { tab -> SessionSnapshotTab in
                    SessionSnapshotTab(
                        id: tab.id,
                        title: tab.model.title ?? (tab.model.url?.absoluteString ?? "Untitled"),
                        url: tab.model.url?.absoluteString ?? "",
                        faviconURL: tab.model.faviconURL?.absoluteString
                    )
                }
                SessionStore.shared.snapshot(tabs: tabs, workspaceID: state.currentWorkspaceID)
                return true
            }
        }

        // ---- hive.listSessions / hive.restoreSession / hive.deleteSession ----
        // Backed by BrowserSessions.SessionStore — a self-contained snapshot
        // store that persists independently of BrowserState's session
        // bootstrap. restoreSession opens a new window wired to that snapshot.
        bridge.register("hive.listSessions") { (request: WebChromeToken) async throws -> [WebChromeSession] in
            try Self.authorize(request.token)
            return await MainActor.run {
                SessionStore.shared.sessions.map { s -> WebChromeSession in
                    let fmt = s.formatted()
                    return WebChromeSession(
                        id: s.id.uuidString,
                        title: s.title,
                        windowCount: s.windowCount,
                        tabCount: s.tabCount,
                        faviconURL: s.faviconURL,
                        startedAt: fmt.startedAt,
                        lastActiveAt: fmt.lastActiveAt
                    )
                }
            }
        }

        bridge.register("hive.restoreSession") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard UUID(uuidString: request.id) != nil else { return false }
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Notification.Name("HiveRequestNewWindow"),
                    object: request.id
                )
            }
            return true
        }

        bridge.register("hive.deleteSession") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let id = UUID(uuidString: request.id) else { return false }
            await MainActor.run { SessionStore.shared.delete(id: id) }
            return true
        }

        // ---- hive.listDownloads: live + terminal downloads from browser state ----
        bridge.register("hive.listDownloads") { (request: WebChromeToken) async throws -> [WebChromeDownload] in
            try Self.authorize(request.token)
            return await MainActor.run {
                state.downloads.map { dl -> WebChromeDownload in
                    let stateName: String
                    if dl.isComplete { stateName = "completed" }
                    else if dl.isCanceled { stateName = "cancelled" }
                    else if dl.isInterrupted { stateName = "failed" }
                    else if dl.progress > 0 { stateName = "inProgress" }
                    else { stateName = "pending" }
                    return WebChromeDownload(
                        id: dl.id.uuidString,
                        name: dl.suggestedName,
                        url: dl.url.absoluteString,
                        state: stateName,
                        progress: dl.progress
                    )
                }
            }
        }

        // ---- hive.createTabGroup: group the active tab into a new colored group ----
        bridge.register("hive.createTabGroup") { (request: WebChromeGroupRequest) async throws -> Bool in
            try Self.authorize(request.token)
            await MainActor.run { state.createTabGroup(name: request.name, colorHex: request.colorHex) }
            return true
        }

        // ---- hive.deleteTabGroup: dissolve a group (tabs revert to ungrouped) ----
        bridge.register("hive.deleteTabGroup") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let id = UUID(uuidString: request.id) else { return false }
            await MainActor.run { state.deleteTabGroup(id: id) }
            return true
        }

        // ---- hive.toggleTabGroup: collapse / expand a group ----
        bridge.register("hive.toggleTabGroup") { (request: WebChromeIDRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let id = UUID(uuidString: request.id) else { return false }
            await MainActor.run { state.toggleTabGroup(id: id) }
            return true
        }

        // ---- hive.setTabGroupColor: recolor a group ----
        bridge.register("hive.setTabGroupColor") { (request: WebChromeGroupColorRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let id = UUID(uuidString: request.id) else { return false }
            await MainActor.run { state.setTabGroupColor(id: id, colorHex: request.colorHex) }
            return true
        }

        // ---- hive.renameTabGroup: rename a group (commit) ----
        bridge.register("hive.renameTabGroup") { (request: WebChromeGroupRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let id = UUID(uuidString: request.id) else { return false }
            await MainActor.run { state.renameTabGroup(id: id, name: request.name) }
            return true
        }

        // ---- hive.moveTabToGroup: assign a tab to a group (or nil to ungroup) ----
        bridge.register("hive.moveTabToGroup") { (request: WebChromeMoveTabGroupRequest) async throws -> Bool in
            try Self.authorize(request.token)
            let groupID = request.groupID.isEmpty ? nil : UUID(uuidString: request.groupID)
            await MainActor.run { state.moveTabToGroup(tabID: request.tabID, groupID: groupID) }
            return true
        }

        // ---- hive.moveTabToWorkspace: DND tab onto a workspace dot ----
        bridge.register("hive.moveTabToWorkspace") { (request: WebChromeMoveTabGroupRequest) async throws -> Bool in
            try Self.authorize(request.token)
            guard let wsID = UUID(uuidString: request.groupID) else { return false }
            await MainActor.run { state.moveTabToWorkspace(tabID: request.tabID, workspaceID: wsID) }
            return true
        }

        registerAgentTools(with: state, bridge: bridge)

    }

    /// Rejects calls that don't carry the per-session token.
    static func authorize(_ token: String) throws {
        guard token == sessionToken else { throw WebChromeBridgeError.unauthorized }
    }

    /// Parses a URL from untrusted input and whitelists its scheme to
    /// http/https (never javascript:, file:, data:, or the hive scheme).
    static func httpURL(from string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }
}
