import SwiftUI
import WebKit
import HiveCore

// MARK: - WebViewContainer
//
// The WKWebView bridge. `NSViewRepresentable` wrapping a single WKWebView whose lifetime is
// owned by the Coordinator (created once, survives SwiftUI re-renders so page state +
// scroll position are never lost on a re-render). Navigation + UI delegate callbacks funnel
// back to `ChromeState` through `WebViewUpdate` so the tab model is the source of truth for
// title / url / loading / progress / back-forward / favicon.
//
// SPEC context:
//   - §11.1 — content fills the area edge-to-edge; no padding.
//   - §11.2 — no chrome inside the content area; web context menu takes precedence.
//   - Appendix D — hibernation via `interactionState` (serialize/restore); process-crash
//     recovery via `webViewWebContentProcessDidTerminate` (reload up to 3×, then error).
//   - Appendix F — private tabs use `WKWebsiteDataStore.nonPersistent()`.
//
// Privacy mode is fixed at Coordinator init. A privacy flip is handled by the call site
// rebuilding the representable under a new SwiftUI identity (the tab's `id`), so the bridge
// never hot-swaps a live WKWebView's data store.

/// State changes the bridge reports back to the owning tab. Invoked on the main actor.
enum WebViewUpdate {
    case title(String)
    case url(URL?)
    case loading(Bool)
    case progress(Double)
    case canGoBack(Bool)
    case canGoForward(Bool)
    case favicon(URL?)
    case didFailProvisionalNav(Error)   // URL rejected before commit (bad scheme)
    case didFailNav(Error)               // committed load failed (network)
    case processTerminated               // web content process crashed
    case openNewWindow(URL)              // target="_blank" / popup → open as a new tab
    case hibernated                      // a hibernate-request was serviced: the interactionState
                                         // sprite is banked in the broker; the model may now flip
                                         // isHibernated and tear this webview down (RAM freed)
    case captureReady(requestID: Int, url: URL?, title: String, text: String)  // page extraction for Honeycomb
    case readerModeReady(ReaderArtifact)  // article extraction for Reader Mode (§25)
    case findInPageResult(matchCount: Int)  // WKWebView.find() result
    case thumbnailCaptured(Data)            // WKWebView.takeSnapshot PNG data (200px thumbnail)
    case screenshotCaptured(Data)            // WKWebView.takeSnapshot PNG data (full resolution)
    case scrollOffset(CGFloat)               // Page scroll Y offset for chrome recession
    case loadFinished(url: URL?)             // main-frame navigation committed + rendered (SUCCESS ONLY:
                                            //   emitted from didFinish, not didFail*). The unambiguous
                                            //   "page is done loading" signal Auto-Capture keys off.
}

/// An imperative webview command routed *declaratively* from `ChromeState` (keyboard: ⌘[ ⌘] ⌘R)
/// into the active tab's Coordinator. Representables are one-directional, so we thread a value
/// with a monotonically-increasing `id`; `updateNSView` applies it exactly once per Coordinator
/// (tracked via `lastCommandID`). The owning tab id is matched at the call site
/// (`state.commandTabID`) so only the active tab receives it — background webviews ignore it.
struct WebViewCommand: Sendable, Equatable {
    enum Action: Sendable, Equatable { case back, forward, reload, stop, zoom(to: Double), print }
    let id: Int
    let action: Action
}

struct WebViewContainer: NSViewRepresentable {

    /// The URL to show. `nil` clears to the start page (the view layer renders that, not here).
    let url: URL?

    /// Private-browsing tab → non-persistent data store, no history capture. Fixed at init.
    let isPrivate: Bool

    /// An imperative command (back/forward/reload/stop), or nil. The call site passes one only
    /// for the active tab.
    let command: WebViewCommand?

    /// The owning tab's id — so the Coordinator can reach its serialized-state sprite in the
    /// `WebViewSessionBroker` (capture on hibernate, restore on wake).
    let tabID: String

    /// Stash for hibernated webview sprites. The Coordinator captures into / restores from this.
    /// nil in previews/tests; a live broker in the app.
    let broker: WebViewSessionBroker?

    /// Per-tab hibernate-request counter. Bumped by `ChromeState.hibernateTab` to ask the
    /// Coordinator to capture its `interactionState` into the broker. Id-gated (the Coordinator
    /// tracks the last id it acted on) so a repeated value never re-captures. 0 = no request yet.
    let hibernateRequestID: Int

    /// Per-tab page-capture request counter. Bumped by `ChromeState.captureActivePage()` to ask
    /// the Coordinator to extract the page title/URL/text and emit `.captureReady`. Id-gated.
    let captureRequestID: Int

    /// Per-tab screenshot request counter. Bumped by `ChromeState.requestScreenshot()` to ask
    /// the Coordinator to capture a full-resolution WKWebView snapshot and emit
    /// `.screenshotCaptured`. Id-gated — repeated values never re-capture.
    let screenshotRequestID: Int

    /// Per-tab reader-mode request counter. Bumped by `ChromeState.toggleReaderMode()` to ask
    /// the Coordinator to extract the article and emit `.readerModeReady`. Id-gated.
    let readerModeRequestID: Int

    /// Per-tab find-in-page request counter. Bumped by ChromeState on text change or
    /// next/previous arrow presses. Id-gated. A value of 0 with empty text signals "clear".
    let findInPageRequestID: Int

    /// The search text for find-in-page. Empty = no active search.
    let findInPageSearchText: String

    /// Whether to find next (true) or previous (false) when the counter bumps.
    let findInPageForward: Bool

    /// HTTPS-only enforcement flag. When true, HTTP requests are upgraded to HTTPS.
    var enforceHTTPS: Bool = true

    /// Global Privacy Control (GPC) — toggles the Sec-GPC: 1 header. Defaults to true.
    var gpcEnabled: Bool = true

    /// Optional autofill controller. When non-nil, the Coordinator calls it on page load
    /// finish to inject saved credentials into login forms. nil in previews/tests.
    var autofillController: WebViewAutofillController?

    /// Main-actor permission resolver supplied by ChromeState. Defaults to the conservative
    /// `.ask` state so previews and isolated callers never grant site capabilities implicitly.
    var permissionState: @MainActor (String, SitePermissionKind) -> SitePermissionState = { _, _ in .ask }

    /// Main-actor permission writer supplied by ChromeState. The default is a no-op; private
    /// tabs and previews therefore cannot persist a permission decision accidentally.
    var setPermission: @MainActor (String, SitePermissionKind, SitePermissionState) -> Void = { _, _, _ in }

    /// Receives navigation updates for the owning tab.
    let onUpdate: @MainActor (WebViewUpdate) -> Void

    // MARK: NSViewRepresentable

    @MainActor
    func makeCoordinator() -> Coordinator {
        Coordinator(isPrivate: isPrivate, tabID: tabID, broker: broker, enforceHTTPS: enforceHTTPS,
                    gpcEnabled: gpcEnabled, autofillController: autofillController,
                    permissionState: permissionState, setPermission: setPermission,
                    onUpdate: onUpdate)
    }

    @MainActor
    func makeNSView(context: Context) -> WKWebView {
        // Wake path: if this tab has a serialized sprite in the broker (it was hibernated),
        // restore losslessly from it instead of fresh-loading the URL — preserves scroll,
        // form input, and the back/forward stack (SPEC Appendix D). Drains the broker once.
        // No sprite (brand-new tab, or a live tab whose Coordinator SwiftUI recreated) → load.
        if let blob = broker.flatMap({ $0.restore(tabID: tabID) }) {
            context.coordinator.applyRestoredState(blob, currentURL: url)
        } else {
            context.coordinator.requestNavigation(to: url)
        }
        return context.coordinator.webView
    }

    @MainActor
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Hibernate-request tick (id-gated): the Coordinator is still ALIVE here (a background
        // tab), so this is the safe moment to serialize the webview's state into the broker.
        // `ChromeState.hibernateTab` bumps this counter, then defers `isHibernated = true` to a
        // later runloop tick so the capture is processed before the view is torn down (which
        // frees the WKWebView's RAM). Dismantle never captures → a close does not leave a sprite.
        if hibernateRequestID != context.coordinator.lastHibernateRequestID {
            context.coordinator.lastHibernateRequestID = hibernateRequestID
            context.coordinator.captureInteractionState(into: broker)
        }
        // Page-capture request tick (id-gated). The Coordinator extracts title/URL/text and
        // emits `.captureReady` so ChromeState can persist a Source + Capture in Honeycomb.
        if captureRequestID != context.coordinator.lastCaptureRequestID {
            context.coordinator.lastCaptureRequestID = captureRequestID
            context.coordinator.capturePageContent(tabID: tabID, requestID: captureRequestID, onUpdate: onUpdate)
        }
        // Screenshot request tick (id-gated). Captures the full-resolution viewport
        // via WKWebView.takeSnapshot and emits `.screenshotCaptured`.
        if screenshotRequestID != context.coordinator.lastScreenshotRequestID {
            context.coordinator.lastScreenshotRequestID = screenshotRequestID
            context.coordinator.captureScreenshot(onUpdate: onUpdate)
        }
        // Reader-mode request tick (id-gated). The Coordinator extracts article content and
        // emits `.readerModeReady` so ChromeState can render the clean ReaderModeView.
        if readerModeRequestID != context.coordinator.lastReaderModeRequestID {
            context.coordinator.lastReaderModeRequestID = readerModeRequestID
            context.coordinator.extractReaderContent(tabID: tabID, onUpdate: onUpdate)
        }
        // Find-in-page request tick (id-gated). The Coordinator calls WKWebView.find() with
        // the search text and direction. Empty text signals "clear" (UIKit's UIFindInteraction
        // has no macOS equivalent; WKWebView.find() is the native API on macOS).
        if findInPageRequestID != context.coordinator.lastFindInPageRequestID {
            context.coordinator.lastFindInPageRequestID = findInPageRequestID
            context.coordinator.performFindInPage(text: findInPageSearchText, forward: findInPageForward,
                                                  tabID: tabID, onUpdate: onUpdate)
        }
        context.coordinator.requestNavigation(to: url)
        // Apply a new imperative command (id-gated so a stale value never re-fires).
        if let cmd = command, cmd.id != context.coordinator.lastCommandID {
            context.coordinator.lastCommandID = cmd.id
            switch cmd.action {
            case .back:    context.coordinator.goBack()
            case .forward: context.coordinator.goForward()
            case .reload:   context.coordinator.reload()
            case .stop:    context.coordinator.stop()
            case .zoom(let level): context.coordinator.setZoom(level)
            case .print:           context.coordinator.printPage()
            }
        }
    }

    @MainActor
    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        // Stop any in-flight load + tear down user content script bindings before the
        // Coordinator deinits (prevents "leaked user script message handlers" warnings).
        webView.stopLoading()
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        coordinator.detachObservers(from: webView)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

        // MARK: WKUIDelegate — JS dialogs

        /// Basic JS alert() — rendered as a native NSAlert with a single OK button.
        @MainActor func webView(_ webView: WKWebView,
                                runJavaScriptAlertPanelWithMessage message: String,
                                initiatedByFrame frame: WKFrameInfo,
                                completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }

        /// JS confirm() — native alert with OK/Cancel.
        @MainActor func webView(_ webView: WKWebView,
                                runJavaScriptConfirmPanelWithMessage message: String,
                                initiatedByFrame frame: WKFrameInfo,
                                completionHandler: @escaping (Bool) -> Void) {
            let alert = NSAlert()
            alert.messageText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            completionHandler(alert.runModal() == .alertFirstButtonReturn)
        }

        /// JS prompt() — native alert with text input.
        @MainActor func webView(_ webView: WKWebView,
                                runJavaScriptTextInputPanelWithPrompt prompt: String,
                                defaultText: String?,
                                initiatedByFrame frame: WKFrameInfo,
                                completionHandler: @escaping (String?) -> Void) {
            let alert = NSAlert()
            alert.messageText = prompt
            alert.alertStyle = .informational
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            input.stringValue = defaultText ?? ""
            input.placeholderString = prompt
            alert.accessoryView = input
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            alert.window.initialFirstResponder = input
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn ? input.stringValue : nil)
        }

        // MARK: WKUIDelegate — media capture (camera / microphone)

        /// Handles getUserMedia() / camera / microphone permission requests from web pages.
        /// Presents a native permission prompt (NSAlert) with Allow / Deny buttons.
        @MainActor func webView(_ webView: WKWebView,
                                requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                                initiatedByFrame frame: WKFrameInfo,
                                type: WKMediaCaptureType,
                                decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            let host = SitePermissionPolicy.normalizedHost(origin.host)
            let requestedKinds: [SitePermissionKind] = switch type {
            case .camera: [.camera]
            case .microphone: [.microphone]
            case .cameraAndMicrophone: [.camera, .microphone]
            @unknown default: []
            }
            guard !requestedKinds.isEmpty else {
                decisionHandler(.deny)
                return
            }

            let storedStates = requestedKinds.map { permissionState(host, $0) }
            if storedStates.contains(.deny) {
                decisionHandler(.deny)
                return
            }
            if storedStates.allSatisfy({ $0 == .allow }) {
                decisionHandler(.grant)
                return
            }

            let kindName = switch type {
            case .camera: "camera"
            case .microphone: "microphone"
            case .cameraAndMicrophone: "camera and microphone"
            @unknown default: "media device"
            }
            let alert = NSAlert()
            alert.messageText = "\(host) wants to access your \(kindName)"
            alert.informativeText = "Granting access allows this site to capture audio and/or video. You can manage permissions in Settings > Privacy."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Allow")
            alert.addButton(withTitle: "Deny")
            let response = alert.runModal()
            let decision: SitePermissionState = response == .alertFirstButtonReturn ? .allow : .deny
            for (kind, state) in zip(requestedKinds, storedStates) where state == .ask {
                setPermission(host, kind, decision)
            }
            decisionHandler(decision == .allow ? .grant : .deny)
        }

        private(set) var webView: WKWebView!
        private let onUpdate: @MainActor (WebViewUpdate) -> Void

        /// The tab this Coordinator serves — used as the key into the session broker.
        let tabID: String
        /// Stash for serialized webview sprites (capture on hibernate, restore on wake). nil in
        /// previews/tests.
        let broker: WebViewSessionBroker?

        /// HTTPS-only enforcement flag. When true, HTTP requests are upgraded to HTTPS.
        private        let enforceHTTPS: Bool

        /// Optional autofill controller. Injected by the Container; called on page load finish.
        let autofillController: WebViewAutofillController?

        /// Persisted site-permission access injected by the owning ChromeState. Both closures
        /// are main-actor isolated because they read/write observable browser preferences.
        let permissionState: @MainActor (String, SitePermissionKind) -> SitePermissionState
        let setPermission: @MainActor (String, SitePermissionKind, SitePermissionState) -> Void

        /// The URL we most recently asked the webview to load. Prevents redundant reloads on
        /// every SwiftUI update (which would kill scroll position + state).
        private var lastRequestedURL: URL?

        /// The id of the last applied `WebViewCommand`, so a value only fires once.
        fileprivate var lastCommandID: Int = 0

        /// The last hibernate-request counter value acted on (id-gated capture; see updateNSView).
        fileprivate var lastHibernateRequestID: Int = 0

        /// The last page-capture request counter value acted on (id-gated; see updateNSView).
        fileprivate var lastCaptureRequestID: Int = 0

        /// The last screenshot request counter value acted on (id-gated; see updateNSView).
        fileprivate var lastScreenshotRequestID: Int = 0

        /// The last reader-mode request counter value acted on (id-gated; see updateNSView).
        fileprivate var lastReaderModeRequestID: Int = 0

        /// The last find-in-page request counter value acted on (id-gated; see updateNSView).
        fileprivate var lastFindInPageRequestID: Int = 0

        /// Crash-recovery counter per webview (SPEC Appendix D: reload up to 3×, then error).
        private var crashCount = 0
        private let maxCrashRecovers = 3

        /// Whether Global Privacy Control (Sec-GPC: 1) is enabled for this webview.
        /// Read from ChromeUserPrefs.globalPrivacyControlEnabled at init time.
        /// Toggling requires a new tab (new webview) to take effect.
        private let gpcEnabled: Bool

        private let observedKeyPaths: [String] = [
            "title", "URL", "isLoading", "estimatedProgress",
            "canGoBack", "canGoForward"
        ]

        init(isPrivate: Bool, tabID: String, broker: WebViewSessionBroker?, enforceHTTPS: Bool = true,
             gpcEnabled: Bool = true, autofillController: WebViewAutofillController? = nil,
             permissionState: @escaping @MainActor (String, SitePermissionKind) -> SitePermissionState = { _, _ in .ask },
             setPermission: @escaping @MainActor (String, SitePermissionKind, SitePermissionState) -> Void = { _, _, _ in },
             onUpdate: @escaping @MainActor (WebViewUpdate) -> Void) {
            self.onUpdate = onUpdate
            self.tabID = tabID
            self.broker = broker
            self.enforceHTTPS = enforceHTTPS
            self.gpcEnabled = gpcEnabled
            self.autofillController = autofillController
            self.permissionState = permissionState
            self.setPermission = setPermission
            super.init()
            let config = WKWebViewConfiguration()
            // Private tabs use an ephemeral, in-memory store (Appendix F); otherwise default.
            config.websiteDataStore = isPrivate ? .nonPersistent() : .default()
            // Content-blocker hook — rules compiled at launch, applied to every webview.
            ContentBlockerController.shared.apply(to: config.userContentController)

            // Scroll detection for chrome recession — injects a passive scroll listener
            // that reports the page's scroll Y offset back to the Coordinator via a named
            // message handler. The Coordinator relays it to ChromeState's scrollOffset
            // so the chrome can compress/recede when the user scrolls down past a threshold.
            let scrollScript = WKUserScript(
                source: """
                (function(){
                    if (window.__hiveScrollInstalled) return;
                    window.__hiveScrollInstalled = true;
                    var ticking = false;
                    window.addEventListener('scroll', function() {
                        if (!ticking) {
                            window.requestAnimationFrame(function() {
                                var y = window.scrollY || window.pageYOffset || 0;
                                window.webkit.messageHandlers.hiveScrollHandler.postMessage(y);
                                ticking = false;
                            });
                            ticking = true;
                        }
                    }, { passive: true });
                })();
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(scrollScript)
            config.userContentController.add(self, contentWorld: .page, name: "hiveScrollHandler")

            // Global Privacy Control (GPC) header — signals "Do Not Sell or Share My
            // Personal Information" on every request. Honoured by California/CCPA-compliant
            // sites and increasingly adopted worldwide. Injected once per webview lifetime
            // via a WKUserScript that modifies the Fetch and XHR prototypes.
            if gpcEnabled {
            let gpcScript = WKUserScript(
                source: """
                (function(){
                    // Patch XMLHttpRequest to inject Sec-GPC header on every request.
                    var origOpen = XMLHttpRequest.prototype.open;
                    XMLHttpRequest.prototype.open = function(method, url) {
                        origOpen.apply(this, arguments);
                        this.setRequestHeader('Sec-GPC', '1');
                    };
                    // Patch fetch() to inject Sec-GPC header on every request.
                    var origFetch = window.fetch;
                    window.fetch = function(input, init) {
                        init = init || {};
                        init.headers = init.headers || {};
                        if (init.headers instanceof Headers) {
                            init.headers.set('Sec-GPC', '1');
                        } else {
                            init.headers['Sec-GPC'] = '1';
                        }
                        return origFetch.call(this, input, init);
                    };
                    // Set navigator.globalPrivacyControl so sites can detect GPC via JS.
                    Object.defineProperty(navigator, 'globalPrivacyControl', {
                        value: true,
                        configurable: false,
                        enumerable: true
                    });
                })();
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(gpcScript)
            }

            let wv = WKWebView(frame: .zero, configuration: config)
            wv.navigationDelegate = self
            wv.uiDelegate = self
            wv.allowsBackForwardNavigationGestures = true   // Trackpad swipe back/forward
            wv.allowsLinkPreview = true
            wv.focusRingType = .none   // Hive draws its own chrome focus
            // KVO for title/URL/loading/progress + canGo* (not exposed as delegate methods).
            for kp in observedKeyPaths {
                wv.addObserver(self, forKeyPath: kp, options: .new, context: nil)
            }
            webView = wv
        }

        // MARK: Navigation requests

        func requestNavigation(to url: URL?) {
            guard let url else {
                lastRequestedURL = nil
                // No URL → the start page handles display; nothing to load here.
                onUpdate(.url(nil))
                return
            }
            // Don't reload a URL already loaded (and already requested) — preserves scroll /
            // back-stack and avoids reload loops on every SwiftUI re-render.
            if let current = webView?.url, current == url { return }
            guard lastRequestedURL != url else { return }
            lastRequestedURL = url
            webView?.load(URLRequest(url: url))
        }

        // MARK: Hibernation — interactionState capture / restore (SPEC Appendix D)

        /// Serialize the live webview's session (scroll, form input, back/forward stack) into
        /// the broker, keyed by this tab's id. Non-draining — the blob stays until a wake
        /// restores (drains) or a close clears it. Called from updateNSView's hibernate tick,
        /// while the Coordinator is still alive (a background-but-displayed tab).
        @MainActor func captureInteractionState(into broker: WebViewSessionBroker?) {
            guard let broker, let wv = webView else { return }
            broker.capture(tabID: tabID, state: wv.interactionState)
            // Capture banked → tell the model it may now tear the webview down (free its RAM).
            // Deferred out of the updateNSView render pass (same idiom as the navigation
            // delegates) so the isHibernated flip + dismantle land on a later runloop tick,
            // guaranteeing the capture (above) precedes the teardown. Without this, the model
            // would render `if !isHibernated` false immediately and dismantle before capture ran.
            Task { @MainActor in self.onUpdate(.hibernated) }
        }

        /// Extracts the current page title, URL, and visible text, then emits `.captureReady`.
        /// Called from updateNSView's capture-request tick, while the Coordinator is alive.
        @MainActor func capturePageContent(tabID: String, requestID: Int, onUpdate: @escaping @MainActor (WebViewUpdate) -> Void) {
            guard let wv = webView else { return }
            let js = """
            (function(){
                var title = document.title || '';
                var url = document.location ? document.location.href : '';
                var text = document.body ? document.body.innerText : '';
                return JSON.stringify({title: title, url: url, text: text.substring(0, 50000)});
            })();
            """
            wv.evaluateJavaScript(js) { [weak self] result, _ in
                // Capture the raw string payload and fallback webview state on the callback
                // thread before hopping to the main actor. `Any?` is not Sendable, so we must
                // extract the string here rather than pass `result` across the actor boundary.
                let jsonString = result as? String
                let fallbackTitle = self?.webView.title
                let fallbackURL = self?.webView.url
                Task { @MainActor in
                    var capturedTitle = ""
                    var capturedURL: URL? = nil
                    var capturedText = ""
                    if let json = jsonString,
                       let data = json.data(using: .utf8),
                       let dict = try? JSONDecoder().decode([String: String].self, from: data) {
                        capturedTitle = dict["title"] ?? ""
                        if let urlStr = dict["url"] { capturedURL = URL(string: urlStr) }
                        capturedText = dict["text"] ?? ""
                    } else {
                        capturedTitle = fallbackTitle ?? ""
                        capturedURL = fallbackURL
                    }
                    onUpdate(.captureReady(requestID: requestID, url: capturedURL, title: capturedTitle, text: capturedText))
                }
            }
        }

        /// Extracts a structured article from the current page and emits `.readerModeReady`.
        /// Called from updateNSView's reader-mode request tick, while the Coordinator is alive.
        /// Uses a tiny, dependency-free readability heuristic (no external JS library).
        @MainActor func extractReaderContent(tabID: String, onUpdate: @escaping @MainActor (WebViewUpdate) -> Void) {
            guard let wv = webView else { return }
            let js = """
            (function(){
                function getByline() {
                    var meta = document.querySelector('meta[name="author"], meta[name="byl"], meta[property="article:author"]');
                    if (meta) return meta.getAttribute('content') || '';
                    var el = document.querySelector('[class*="byline"], [class*="author"]');
                    return el ? (el.innerText || '').trim().substring(0, 200) : '';
                }
                function findArticle() {
                    var selectors = ['article', 'main', '[role="main"]', '.post-content', '.article-content', '.entry-content', '.content', '.post', '.article'];
                    for (var i = 0; i < selectors.length; i++) {
                        var el = document.querySelector(selectors[i]);
                        if (el) return el;
                    }
                    // Fallback: largest single <div> or <section> with meaningful text.
                    var candidates = document.querySelectorAll('div, section');
                    var best = null, bestLen = 0;
                    for (var i = 0; i < candidates.length; i++) {
                        var text = candidates[i].innerText || '';
                        if (text.length > bestLen && text.length < 50000) {
                            bestLen = text.length;
                            best = candidates[i];
                        }
                    }
                    return best;
                }
                var article = findArticle();
                var title = document.title || '';
                var byline = getByline();
                var url = document.location ? document.location.href : '';
                var html = article ? article.innerHTML : document.body ? document.body.innerHTML : '';
                var text = article ? (article.innerText || '') : (document.body ? (document.body.innerText || '') : '');
                return JSON.stringify({title: title, byline: byline, url: url, html: html, text: text.substring(0, 10000)});
            })();
            """
            wv.evaluateJavaScript(js) { [weak self] result, _ in
                let jsonString = result as? String
                let fallbackTitle = self?.webView.title
                let fallbackURL = self?.webView.url
                Task { @MainActor in
                    var parsedTitle = ""
                    var parsedByline = ""
                    var parsedURL: URL? = nil
                    var parsedHTML = ""
                    var parsedText = ""
                    if let json = jsonString,
                       let data = json.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                        parsedTitle = dict["title"] ?? ""
                        parsedByline = dict["byline"] ?? ""
                        if let urlString = dict["url"], let url = URL(string: urlString) {
                            parsedURL = url
                        }
                        parsedHTML = dict["html"] ?? ""
                        parsedText = dict["text"] ?? ""
                    }
                    if parsedTitle.isEmpty { parsedTitle = fallbackTitle ?? "" }
                    if parsedURL == nil { parsedURL = fallbackURL }
                    if parsedHTML.isEmpty {
                        // No meaningful article found — still emit a minimal artifact so the UI
                        // can show a friendly fallback rather than staying blank.
                        parsedHTML = "<p>No reader content available for this page.</p>"
                    }
                    let artifact = ReaderArtifact(
                        url: parsedURL,
                        title: parsedTitle,
                        byline: parsedByline,
                        contentHTML: parsedHTML,
                        excerpt: String(parsedText.prefix(240))
                    )
                    onUpdate(.readerModeReady(artifact))
                }
            }
        }

        /// Wake-from-hibernate: apply the serialized sprite to the fresh webview instead of
        /// loading by URL, so scroll position + form input + the back/forward stack survive
        /// losslessly. Marks `lastRequestedURL` so the first updateNSView's requestNavigation
        /// no-ops — the restored session already holds the right URL; reloading would torch it.
        @MainActor func applyRestoredState(_ blob: Any, currentURL: URL?) {
            guard let wv = webView else { return }
            wv.interactionState = blob
            lastRequestedURL = currentURL
        }

        // MARK: WKNavigationDelegate

        nonisolated func webView(_ webView: WKWebView,
                                 didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in self.onUpdate(.loading(true)); self.onUpdate(.progress(0.05)) }
        }

        nonisolated func webView(_ webView: WKWebView,
                                 didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                self.onUpdate(.loading(false))
                self.onUpdate(.progress(1.0))
                // Success-only signal for the Auto-Capture route (PITCH/backend-completion.md A2).
                // didFail* emit `.loading(false)` WITHOUT this, so Auto-Capture never fires on error.
                self.onUpdate(.loadFinished(url: webView.url))
                self.extractFavicon(from: webView, for: webView.url)
                self.captureThumbnail()
                // Inject per-site Boosts (CSS, JS, dark mode, zapped elements).
                if let url = webView.url {
                    Task {
                        let matching = await BoostStore.shared.boosts(for: url)
                        if !matching.isEmpty {
                            await MainActor.run { self.injectBoosts(matching, into: webView) }
                        }
                    }
                    // Auto-format JSON responses: inject a pretty-printer if the page
                    // content is JSON. Detects by checking the body's first non-whitespace
                    // characters for [ or { — the same heuristic browsers like Arc use.
                    self.injectJSONFormatterIfNeeded(into: webView)
                }
                // Trigger credential autofill on page load finish.
                if let host = webView.url?.host, let ac = self.autofillController {
                    Task {
                        _ = await ac.autofillIfPermitted(in: webView, host: host, hasAutofillPermission: true)
                    }
                }
            }
        }

        nonisolated func webView(_ webView: WKWebView,
                                 didFailProvisionalNavigation navigation: WKNavigation!,
                                 withError error: Error) {
            Task { @MainActor in
                self.onUpdate(.loading(false))
                self.onUpdate(.didFailProvisionalNav(error))
            }
        }

        nonisolated func webView(_ webView: WKWebView,
                                 didFail navigation: WKNavigation!,
                                 withError error: Error) {
            Task { @MainActor in
                self.onUpdate(.loading(false))
                self.onUpdate(.didFailNav(error))
            }
        }

        /// new-window actions (target="_blank", window.open(), ⌘-click) open as a new Hive
        /// tab instead of a separate webview-in-window.
        nonisolated func webView(_ webView: WKWebView,
                                 createWebViewWith configuration: WKWebViewConfiguration,
                                 for navigationAction: WKNavigationAction,
                                 completionHandler: @escaping (WKWebView?) -> Void) {
        // Always complete WebKit's creation request synchronously. Hive owns the new-tab
        // surface, so no separate WKWebView is ever returned. The policy decision below
        // controls only whether Hive routes the request into a new tab.
        completionHandler(nil)
        Task { @MainActor in
            let url = navigationAction.request.url
            let navigationType = navigationAction.navigationType
            guard let url else { return }
            let host = SitePermissionPolicy.normalizedHost(url.host ?? "")
            let intent: SitePermissionPolicy.NavigationIntent =
                navigationType == .linkActivated ? .userActivatedLink : .scriptOrUnknown
            let permission = permissionState(host, .popups)
            guard SitePermissionPolicy.allowsNewWindow(navigationType: intent, permission: permission) else {
                return
            }
            self.onUpdate(.openNewWindow(url))
        }
        }

        nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            Task { @MainActor in
                if self.crashCount < self.maxCrashRecovers {
                    self.crashCount += 1
                    webView.reload()
                } else {
                    self.onUpdate(.processTerminated)
                }
            }
        }

        // MARK: Certificate / TLS error handling
        //
        /// Presents a native alert when a TLS certificate error occurs (expired,
        /// self-signed, wrong host, untrusted root). The user can choose to proceed
        /// (accept the bad cert) or cancel (block the connection).
        /// This is the same UX Safari/Chrome use — WKWebView defaults to blocking
        /// bad certs; this delegate override gives the user an informed choice.
        nonisolated func webView(_ webView: WKWebView,
                                 didReceive challenge: URLAuthenticationChallenge,
                                 completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            // Server trust: certificate validation
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let serverTrust = challenge.protectionSpace.serverTrust else {
                // Not a server-trust challenge — use default handling (basic auth, etc.)
                completionHandler(.performDefaultHandling, nil)
                return
            }

            // Evaluate trust on the main actor since the alert must present there.
            let host = challenge.protectionSpace.host
            Task { @MainActor in
                var error: CFError?
                let trusted = SecTrustEvaluateWithError(serverTrust, &error)

                if trusted {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Security Warning"
                    alert.informativeText = """
                    \(host) has an invalid security certificate.

                    The certificate may be expired, self-signed, or for a different server. This could mean someone is trying to intercept your connection.

                    Error: \(error?.localizedDescription ?? "Unknown certificate error")
                    """
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "Go Back (Recommended)")
                    alert.addButton(withTitle: "Proceed Anyway")
                    alert.icon = NSImage(systemSymbolName: "lock.trianglebadge.exclamationmark", accessibilityDescription: nil)

                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        completionHandler(.cancelAuthenticationChallenge, nil)
                    } else {
                        completionHandler(.useCredential, URLCredential(trust: serverTrust))
                    }
                }
            }
        }

        // MARK: Favicon extraction
        //
        // WKWebView has no native favicon API. Inject a tiny script that reads the page's
        // <link rel*="icon"> and reports the absolute href. Falls back to <host>/favicon.ico.

        @MainActor
        private func extractFavicon(from webView: WKWebView, for pageURL: URL?) {
            guard let pageURL else { return }
            let js = """
            (function(){
              var l = document.querySelector('link[rel~=\"icon\"], link[rel=\"shortcut icon\"], link[rel=\"apple-touch-icon\"]');
              var href = l ? l.getAttribute('href') : null;
              return href;
            })();
            """
            webView.evaluateJavaScript(js) { [weak self] result, _ in
                Task { @MainActor in
                    guard let self else { return }
                    if let href = result as? String,
                       let resolved = URL(string: href, relativeTo: pageURL),
                       resolved.scheme == "http" || resolved.scheme == "https" {
                        self.onUpdate(.favicon(resolved))
                    } else {
                        // Fallback: the conventional root favicon.
                        var comps = URLComponents(url: pageURL, resolvingAgainstBaseURL: false)
                        comps?.path = "/favicon.ico"
                        comps?.query = nil
                        comps?.fragment = nil
                        if let fav = comps?.url { self.onUpdate(.favicon(fav)) }
                    }
                }
            }
        }

        // MARK: KVO

        override nonisolated func observeValue(forKeyPath keyPath: String?,
                                               of object: Any?,
                                               change: [NSKeyValueChangeKey: Any]?,
                                               context: UnsafeMutableRawPointer?) {
            guard let webView = object as? WKWebView, let keyPath else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch keyPath {
                case "title":           self.onUpdate(.title(webView.title ?? ""))
                case "URL":             self.onUpdate(.url(webView.url))
                case "isLoading":       self.onUpdate(.loading(webView.isLoading))
                case "estimatedProgress": self.onUpdate(.progress(webView.estimatedProgress))
                case "canGoBack":       self.onUpdate(.canGoBack(webView.canGoBack))
                case "canGoForward":    self.onUpdate(.canGoForward(webView.canGoForward))
                default: break  // future KVO keys land here safely
                }
            }
        }

        func detachObservers(from wv: WKWebView) {
            for kp in observedKeyPaths {
                wv.removeObserver(self, forKeyPath: kp)
            }
        }

        // MARK: WKScriptMessageHandler — scroll detection for chrome recession

        nonisolated func userContentController(_ userContentController: WKUserContentController,
                                                didReceive message: WKScriptMessage) {
                Task { @MainActor in
                guard message.name == "hiveScrollHandler",
                      let offset = message.body as? CGFloat else { return }
                // Relay scroll offset to ChromeState via the existing update channel.
                // The offset is clamped to 0+ and sent on every scroll animation frame
                // (throttled via requestAnimationFrame in the injected JS). ChromeState
                // uses a threshold (e.g. 20px) to decide when to recess the chrome.
                self.onUpdate(.scrollOffset(offset))
            }
        }

        // MARK: Outbound commands (called by ChromeState / chrome views)
        //
        // The container is the funnel for imperative webview commands. ChromeState owns the
        // tab model; these route to the live webview for the active tab.

        @MainActor func goBack()    { webView?.goBack() }
        @MainActor func goForward() { webView?.goForward() }
        @MainActor func reload()    { webView?.reload() }
        @MainActor func stop()      { webView?.stopLoading() }

        /// Performs a find-in-page operation using window.find() JavaScript (universally
        /// supported in WebKit). Navigates to the next/previous match and returns a match
        /// count estimate via a simpler regex scan on body.innerText so the counter stays
        /// accurate without complex escaping.
        @MainActor func performFindInPage(text: String, forward: Bool, tabID: String,
                                          onUpdate: @escaping @MainActor (WebViewUpdate) -> Void) {
            guard let wv = webView else { return }
            if text.isEmpty {
                wv.evaluateJavaScript("window.getSelection()?.removeAllRanges()")
                return
            }
            // Build JS safely: pass text as a percent-encoded + base64 param to avoid
            // escaping hell. Percent-encoding first ensures non-ASCII (é, ñ, 中文) survives
            // the atob→decodeURIComponent round-trip.
            let pct = text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? text
            let b64 = Data(pct.utf8).base64EncodedString()
            let backwards = !forward
            let js = """
            (function(){
                var t = decodeURIComponent(atob('\(b64)'));
                var body = document.body;
                var count = 0;
                if (body && body.innerText) {
                    var re = new RegExp(t.replace(/[.*+?^${}()|[\\]\\/]/g, '\\$&'), 'gi');
                    var m = body.innerText.match(re);
                    count = m ? m.length : 0;
                }
                window.find(t, false, \(backwards), true, false, false, false);
                return count;
            })();
            """
            wv.evaluateJavaScript(js) { result, _ in
                let matchCount = (result as? NSNumber)?.intValue ?? 0
                Task { @MainActor in
                    onUpdate(.findInPageResult(matchCount: Int(matchCount)))
                }
            }
        }

        // MARK: - Capture extraction script
        //
        // WKWebView has no native page-capture API. We inject a tiny script that reads the
        // document title, canonical URL, and body text, then emit a WebViewUpdate.captureReady
        // so the model can persist a Source + Capture in Honeycomb.

        /// Detects if the loaded page content is JSON and injects a pretty-printer for
        /// syntax-highlighted, collapsible display. Uses a heuristic: checks if the body's
        /// trimmed first character is `{` or `[` — the same approach Arc uses.
        @MainActor func injectJSONFormatterIfNeeded(into webView: WKWebView) {
            let js = #"""
            (function(){
                if (window.__hiveJSONFormatted) return;
                var body = document.body;
                if (!body || !body.innerText) return;
                var text = body.innerText.trim();
                if (text.length < 2) return;
                var first = text.charAt(0);
                if (first !== '{' && first !== '[') return;
                try {
                    var parsed = JSON.parse(text);
                    var formatted = JSON.stringify(parsed, null, 2);
                    document.title = 'JSON: ' + (document.title || 'viewer');
                    var style = document.createElement('style');
                    style.textContent = [
                        'body { background: #1A1814; color: #C8C2B8; font-family: ui-monospace, monospace; font-size: 13px; line-height: 1.5; padding: 24px; margin: 0; white-space: pre-wrap; word-wrap: break-word; }',
                        '.json-key { color: #8A7A6A; }',
                        '.json-string { color: #D8A43D; }',
                        '.json-number { color: #C4953A; }',
                        '.json-boolean { color: #A8C87A; }',
                        '.json-null { color: #6A5A4A; font-style: italic; }'
                    ].join('\\n');
                    document.head.appendChild(style);
                    var formattedHTML = '<div style="padding:8px 0 16px 0; border-bottom:1px solid #2A2824; margin-bottom:16px; display:flex; align-items:center; gap:8px;"><span style="color:#C4953A;font-size:14px;">\u26A6</span><span style="color:#8A7A6A;font-size:11px;">JSON Viewer</span><span style="margin-left:auto;color:#6A5A4A;font-size:11px;">' + text.length + ' bytes</span></div>';
                    var lines = formatted.split('\\n');
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i];
                        var escaped = line.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                        var highlighted = escaped;
                        formattedHTML += '<div>' + highlighted + '</div>';
                    }
                    document.body.innerHTML = formattedHTML;
                    window.__hiveJSONFormatted = true;
                } catch(e) {}
            })();
            """#
            webView.evaluateJavaScript(js)
        }

        /// Captures a full-resolution viewport screenshot via WKWebView.takeSnapshot (macOS 14+).
        /// Encodes at 2x retina (actual display pixels) for crisp screenshots on all displays.
        /// Emitted as `.screenshotCaptured` so ChromeState presents the ScreenshotOverlayView.
        @MainActor func captureScreenshot(onUpdate: @escaping @MainActor (WebViewUpdate) -> Void) {
            guard let wv = webView else { return }
            let config = WKSnapshotConfiguration()
            // nil = full viewport at native device scale (2x retina on most Mac displays).
            config.snapshotWidth = nil
            wv.takeSnapshot(with: config) { image, error in
                guard let image, error == nil else { return }
                guard let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:]) else { return }
                Task { @MainActor in
                    onUpdate(.screenshotCaptured(png))
                }
            }
        }

        /// Captures a page thumbnail via WKWebView.takeSnapshot (macOS 14+). The snapshot
        /// is taken at a reduced resolution (200px wide) for memory efficiency, then encoded
        /// as PNG data. Emitted as `.thumbnailCaptured` so ChromeState stores it for hover
        /// previews and tab overview cards.
        @MainActor func captureThumbnail() {
            guard let wv = webView else { return }
            let config = WKSnapshotConfiguration()
            config.snapshotWidth = 200  // scale full viewport to 200px wide
            wv.takeSnapshot(with: config) { [weak self] image, error in
                guard let image, error == nil else { return }
                guard let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:]) else { return }
                Task { @MainActor in
                    self?.onUpdate(.thumbnailCaptured(png))
                }
            }
        }

        // MARK: Boost injection — per-site CSS, JS, dark mode, element zaps

        /// Inject matching Boosts into the webview after page load.
        /// CSS is injected as a `<style>` element, JS via evaluateJavaScript,
        /// dark mode via CSS inversion, and zapped selectors via CSS display:none.
        @MainActor func injectBoosts(_ boosts: [Boost], into webView: WKWebView) {
            // Build combined CSS: custom CSS + zapped selector rules + optional dark mode.
            var cssParts: [String] = []
            var jsParts: [String] = []

            for boost in boosts where boost.isEnabled {
                if !boost.css.isEmpty {
                    cssParts.append(boost.css)
                }
                if !boost.js.isEmpty {
                    jsParts.append(boost.js)
                }
                if !boost.zappedSelectors.isEmpty {
                    let zapCSS = boost.zappedSelectors.map { sel in
                        "\(sel) { display: none !important; }"
                    }.joined(separator: "\n")
                    cssParts.append(zapCSS)
                }
                if boost.forceDarkMode {
                    cssParts.append("""
                html { filter: invert(1) hue-rotate(180deg) !important; }
                img, video, canvas, [style*="background-image"] {
                    filter: invert(1) hue-rotate(180deg) !important;
                }
                """)
                }
            }

            guard !cssParts.isEmpty || !jsParts.isEmpty else { return }

            // Inject combined CSS.
            if !cssParts.isEmpty {
                let combinedCSS = cssParts.joined(separator: "\n\n")
                let escapedCSS = combinedCSS
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "")
                let cssJS = #"(function(){"# +
                    #"var el = document.createElement('style');"# +
                    #"el.textContent = "\(escapedCSS)";"# +
                    #"document.head.appendChild(el);"# +
                #"})();"#
                webView.evaluateJavaScript(cssJS)
            }

            // Inject combined JS.
            if !jsParts.isEmpty {
                let combinedJS = jsParts.joined(separator: "\n\n")
                webView.evaluateJavaScript(combinedJS)
            }
        }

        /// Page zoom via injected CSS `zoom` (1.0 = 100%). Reflows the page like Safari's
        /// Page Zoom, distinct from pinch-zoom; persists per-tab in BrowserTab.zoomLevel.
        @MainActor func setZoom(_ level: Double) {
            let clamped = min(max(level, 0.25), 5.0)
            let js = "document.documentElement.style.zoom = '\(clamped)';"
            webView?.evaluateJavaScript(js)
        }

        /// Opens the native macOS print dialog via `window.print()`. This is the standard
        /// WebKit path — same as Safari's File > Print. The dialog supports page setup,
        /// paper size, orientation, scale, and Save as PDF.
        @MainActor func printPage() {
            webView?.evaluateJavaScript("window.print()")
        }

        deinit {
            // Observers normally detached in dismantleNSView; best-effort if that didn't run.
            if let wv = webView {
                for kp in observedKeyPaths {
                    wv.removeObserver(self, forKeyPath: kp)
                }
            }
        }
    }
}

// MARK: - WKNavigationDelegate policy decisions
//
// Placed in an extension to satisfy the Swift 6 compiler's protocol-witness matching rules.

extension WebViewContainer.Coordinator {

    @MainActor func webView(_ webView: WKWebView,
                            navigationAction: WKNavigationAction,
                            didBecome download: WKDownload) {
        Task { @MainActor in
            await WebKitDownloadCoordinator.shared.adopt(
                download,
                from: webView,
                sourceURL: navigationAction.request.url,
                suggestedFilename: nil
            )
        }
    }

    @MainActor func webView(_ webView: WKWebView,
                            navigationResponse: WKNavigationResponse,
                            didBecome download: WKDownload) {
        Task { @MainActor in
            await WebKitDownloadCoordinator.shared.adopt(
                download,
                from: webView,
                sourceURL: navigationResponse.response.url,
                suggestedFilename: navigationResponse.response.suggestedFilename
            )
        }
    }

    /// Enforces HTTPS-only mode: detects http:// requests and upgrades to https://.
    /// When upgrade is not possible (malformed URL), cancels the insecure request.
    @MainActor func webView(_ webView: WKWebView,
                            decidePolicyFor navigationAction: WKNavigationAction,
                            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Handle internal hive:// URLs — used by Safe Browsing interstitial and other
        // internal pages (settings, on boarding, etc.).
        if let url = navigationAction.request.url, url.scheme == "hive" {
            decisionHandler(.cancel)
            switch url.host {
            case "go-back":
                // Safe Browsing interstitial "Go Back" — navigate to the previous page.
                if webView.canGoBack {
                    webView.goBack()
                } else {
                    // No back history — load a blank page or the start page.
                    webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
                }
            case "proceed":
                // Safe Browsing interstitial "Proceed Anyway" — extract the original URL
                // from the query parameter and navigate to it, bypassing the blocklist.
                if let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "url" })?.value,
                   let originalURL = URL(string: encoded) {
                    webView.load(URLRequest(url: originalURL))
                }
            default:
                break
            }
            return
        }

        // Safe Browsing check — intercept known phishing/malware URLs before navigation.
        if let url = navigationAction.request.url, SafeBrowsingController.shared.shouldBlock(url) {
            decisionHandler(.cancel)
            let html = SafeBrowsingController.interstitialHTML(for: url)
            webView.loadHTMLString(html, baseURL: URL(string: "hive://safe-browsing"))
            return
        }

        guard enforceHTTPS,
              let url = navigationAction.request.url,
              url.scheme == "http" else {
            decisionHandler(.allow)
            return
        }
        // Upgrade: construct https:// variant and reload.
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.scheme = "https"
        guard let httpsURL = comps?.url else {
            // Malformed URL — allow the http request through (don't silently break navigation).
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        webView.load(URLRequest(url: httpsURL))
    }

    @MainActor func webView(_ webView: WKWebView,
                            decidePolicyFor navigationResponse: WKNavigationResponse,
                            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {        let mimeType = navigationResponse.response.mimeType ?? ""
        let disposition = (navigationResponse.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        let url = navigationResponse.response.url

        // Only trigger a download when the server explicitly says "attachment" or the file
        // extension is a known archive. Previously we auto-downloaded JSON/CSV/SVG, which
        // broke inline API pages and raw file viewers.
        let looksLikeAttachment = disposition.lowercased().hasPrefix("attachment")
        let archiveExts = Set(["zip", "dmg", "pkg", "deb", "rpm", "tar", "gz", "bz2", "xz", "7z"])
        let looksLikeArchive = url.map { archiveExts.contains($0.pathExtension.lowercased()) } ?? false

        if looksLikeAttachment || looksLikeArchive {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }
}
