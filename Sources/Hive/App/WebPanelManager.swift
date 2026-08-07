import SwiftUI
import WebKit
import HiveCore

// MARK: - WebPanelManager
//
// Manages a persistent pool of WKWebView instances keyed by PinnedWebApp ID.
// Unlike the default behavior of recreating webviews on every panel switch,
// this keeps each panel's webview alive so JavaScript sessions, WebSockets,
// and audio contexts survive panel switches — crucial for WhatsApp, Slack,
// Notion, and Spotify to stay logged in.
//
// The manager is an NSObject subclass so it can act as KVO observer for
// WKWebView title and loading state changes. SwiftUI views read published
// properties through Combine publishers for reactivity.

final class WebPanelManager: NSObject, @unchecked Sendable {

    /// The shared instance used by the browser.
    static let shared = WebPanelManager()

    /// Persistent webview pool: panelID → WKWebView.
    /// Webviews are created lazily on first access and kept alive until
    /// explicitly evicted (panel removed, memory pressure, or app quit).
    private var webViews: [String: WKWebView] = [:]

    /// Per-panel navigation state: panelID → whether it's currently loading.
    private(set) var loadingStates: [String: Bool] = [:]
    /// Per-panel page titles, extracted via KVO on the webview's title property.
    private(set) var pageTitles: [String: String] = [:]
    /// Per-panel unread counts (updated via periodic JS injection).
    private(set) var unreadCounts: [String: Int] = [:]

    override private init() {
        super.init()
    }

    // MARK: - Access

    /// Returns the persistent WKWebView for a panel, creating it lazily if needed.
    /// The webview uses an isolated WKWebsiteDataStore so each panel has its own
    /// cookies, localStorage, and session — cross-panel data isolation.
    func webView(for panelID: String, url: URL) -> WKWebView {
        if let existing = webViews[panelID] {
            // If the webview's current URL is different and it's not actively loading,
            // navigate to the requested URL.
            if existing.url?.absoluteString != url.absoluteString,
               !(loadingStates[panelID] ?? false) {
                existing.load(URLRequest(url: url))
            }
            return existing
        }

        let config = WKWebViewConfiguration()
        // Use an isolated data store per panel for independent sessions.
        if #available(macOS 14.0, *) {
            let panelUUID = UUID(uuidString: panelID) ?? UUID()
            config.websiteDataStore = WKWebsiteDataStore(forIdentifier: panelUUID)
        }
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.load(URLRequest(url: url))
        wv.allowsBackForwardNavigationGestures = false

        // Observe title changes for KVO-based page title tracking.
        // We use the panelID string as the KVO context pointer (bridged).
        wv.addObserver(self, forKeyPath: "title", options: .new, context: context(for: panelID))

        webViews[panelID] = wv
        loadingStates[panelID] = true
        pageTitles[panelID] = url.host ?? ""

        // Track loading state.
        wv.addObserver(self, forKeyPath: "isLoading", options: .new, context: context(for: panelID))

        // Periodically inject JS to check for unread indicators.
        startUnreadPolling(for: panelID, webView: wv)

        return wv
    }

    /// Returns an existing webview for a panel, or nil if not yet created.
    func existingWebView(for panelID: String) -> WKWebView? {
        webViews[panelID]
    }

    /// Reloads a panel's webview.
    func reload(panelID: String) {
        guard let wv = webViews[panelID] else { return }
        wv.reload()
    }

    /// Navigates the panel's webview to a new URL.
    func navigate(panelID: String, to url: URL) {
        guard let wv = webViews[panelID] else { return }
        wv.load(URLRequest(url: url))
    }

    /// Evicts a panel's webview from the pool. Call when a panel is removed.
    /// The webview's session data (cookies, localStorage) persists on disk
    /// via the WKWebsiteDataStore — re-adding the panel will restore the session.
    func evict(panelID: String) {
        guard let wv = webViews.removeValue(forKey: panelID) else { return }
        // Remove KVO observers using the exact stored context pointer.
        if let ctx = panelContexts.removeValue(forKey: panelID) {
            wv.removeObserver(self, forKeyPath: "title", context: ctx)
            wv.removeObserver(self, forKeyPath: "isLoading", context: ctx)
        }
        wv.stopLoading()
        loadingStates.removeValue(forKey: panelID)
        pageTitles.removeValue(forKey: panelID)
        unreadCounts.removeValue(forKey: panelID)
        stopUnreadPolling(for: panelID)
    }

    /// Evicts all panel webviews. Called on memory pressure or app termination.
    func evictAll() {
        for id in webViews.keys {
            evict(panelID: id)
        }
    }

        /// Stable KVO context pointers per panelID so addObserver/removeObserver
    /// use the exact same pointer (required by KVO).
    private var panelContexts: [String: UnsafeMutableRawPointer] = [:]
    private nonisolated(unsafe) var contextMap: [Int: String] = [:]
    private nonisolated(unsafe) var nextContext: Int = 1
    private let contextLock = NSLock()

    private func context(for panelID: String) -> UnsafeMutableRawPointer {
        // Return existing pointer if one already exists for this panel.
        if let existing = panelContexts[panelID] { return existing }
        contextLock.lock()
        let ptr = nextContext
        nextContext += 1
        contextMap[ptr] = panelID
        contextLock.unlock()
        let rawPtr = UnsafeMutableRawPointer(bitPattern: ptr)!
        panelContexts[panelID] = rawPtr
        return rawPtr
    }

    private nonisolated func panelIDForContext(_ ptrInt: Int) -> String? {
        contextLock.lock()
        let result = contextMap[ptrInt]
        contextLock.unlock()
        return result
    }

    // MARK: - KVO

    nonisolated override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                            change: [NSKeyValueChangeKey: Any]?,
                                            context: UnsafeMutableRawPointer?) {
        // Recover the panelID from the context pointer.
        let ptrInt = Int(bitPattern: context)
        guard let panelID = panelIDForContext(ptrInt) else { return }

        // Extract values from the change dictionary instead of accessing
        // main-actor-isolated WKWebView properties from a nonisolated callback.
        // Extract Sendable values from the change dictionary before crossing the
        // actor boundary (NSKeyValueChangeKey → Any is non-Sendable).
        let titleValue: String? = (keyPath == "title") ? change?[.newKey] as? String : nil
        let loadingValue: Bool? = (keyPath == "isLoading") ? change?[.newKey] as? Bool : nil

        Task { @MainActor in
            if let title = titleValue {
                self.pageTitles[panelID] = title
            }
            if let loading = loadingValue {
                self.loadingStates[panelID] = loading
            }
        }
    }

    // MARK: - Unread Badge Polling

    /// A lightweight timer-based unread counter poller. Injects JavaScript
    /// every 10 seconds to count elements that commonly indicate unread
    /// content (badge elements, unread indicators, specific selectors).
    /// The interval is intentionally long to minimize CPU impact.
    private var pollTimers: [String: Timer] = [:]

    private func startUnreadPolling(for panelID: String, webView: WKWebView) {
        let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self, weak webView] _ in
            guard let self, let wv = webView else { return }
            let js = """
            (function() {
                // Common unread indicator patterns across web apps
                var count = 0;
                // Badge elements with numbers
                document.querySelectorAll('[class*="badge"], [class*="unread"], [class*="notification"]').forEach(function(el) {
                    var text = el.textContent.trim();
                    var num = parseInt(text, 10);
                    if (!isNaN(num) && num > 0) count += num;
                });
                // Meta badge content
                var meta = document.querySelector('meta[name*="badge"], meta[name*="notification"]');
                if (meta) {
                    var num = parseInt(meta.content, 10);
                    if (!isNaN(num) && num > 0) count += num;
                }
                return count;
            })();
            """
            wv.evaluateJavaScript(js) { [weak self] result, _ in
                guard let self, let count = result as? Int else { return }
                self.unreadCounts[panelID] = count
            }
        }
        pollTimers[panelID] = timer
    }

    private func stopUnreadPolling(for panelID: String) {
        pollTimers[panelID]?.invalidate()
        pollTimers.removeValue(forKey: panelID)
    }
}
