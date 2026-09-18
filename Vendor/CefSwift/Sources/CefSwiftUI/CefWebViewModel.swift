import AppKit
import CefKit
import Observation

/// An observable view model driving a single ``CefWebView``.
///
/// `CefWebViewModel` is the SwiftUI-facing state container for one CEF browser. It acts as the
/// `CefBrowserDelegate` of its browser, mirroring navigation state (`title`, `isLoading`,
/// `estimatedProgress`, `canGoBack`, `canGoForward`, `faviconURL`) into `@Observable`
/// properties so SwiftUI views update automatically.
///
/// Setting ``url`` navigates the browser; the browser's own address changes are reflected back
/// into ``url`` without re-triggering navigation.
///
/// ```swift
/// @State private var model = CefWebViewModel(url: URL(string: "https://example.com")!)
///
/// var body: some View {
///     VStack {
///         Text(model.title)
///         CefWebView(model: model)
///     }
/// }
/// ```
@Observable @MainActor
public final class CefWebViewModel {

    // MARK: State

    /// The current URL. Assigning a new value navigates the browser.
    ///
    /// When the browser itself navigates (link click, redirect, …) this property is updated to
    /// the new address without issuing another load.
    public var url: URL? {
        didSet {
            // Feedback-loop guard: don't navigate when the change originated from the
            // browser's own address-change notification, and skip no-op assignments.
            guard !isApplyingBrowserURL, let url, url != oldValue else { return }
            browser?.load(url)
        }
    }

    /// The current page title.
    public private(set) var title: String = ""

    /// Whether the browser is currently loading.
    public private(set) var isLoading: Bool = false

    /// An estimate of the current load's progress, from 0.0 to 1.0.
    public private(set) var estimatedProgress: Double = 0

    /// Whether the browser can navigate back in its history.
    public private(set) var canGoBack: Bool = false

    /// Whether the browser can navigate forward in its history.
    public private(set) var canGoForward: Bool = false

    /// The URL of the page's favicon, if one has been reported.
    public private(set) var faviconURL: URL?

    /// The underlying CEF browser, available once the hosting view has created it.
    public private(set) var browser: CefBrowser?

    /// Options used when the browser is created. Changes after creation have no effect.
    public var options: CefBrowserOptions

    // MARK: Pluggable hooks (all optional)

    /// Called for every JavaScript console message emitted by the page.
    public var onConsoleMessage: ((String) -> Void)?

    /// Called when the page requests a popup (e.g. `window.open`). Return a
    /// `CefPopupDecision` (`.allow`, `.block`, or `.openInSameBrowser`).
    /// When `nil`, popups are allowed.
    ///
    /// - Note: Prefer ``onWindowOpen``, which carries the full request
    ///   (disposition, user gesture, popup features) and is OSR-safe by default.
    public var onPopupRequest: ((URL?) -> CefPopupDecision)?

    /// Called when the page tries to open a link/popup/new window, Electron
    /// `setWindowOpenHandler`-style. Return a ``CefWindowOpenAction``.
    ///
    /// When `nil`, CefSwift applies its safe default policy
    /// (``CefWindowOpenPolicy/defaultAction(for:)``): the target loads in the
    /// current browser — an OSR browser is never given an unsafe native popup.
    public var onWindowOpen: ((CefWindowOpenRequest) -> CefWindowOpenAction)?

    /// Called when a download is about to begin; return a
    /// `CefDownloadDecision`. When `nil`, downloads are saved to
    /// `~/Downloads/<suggested name>`.
    public var onDownloadDecision: ((CefDownload, _ suggestedName: String) -> CefDownloadDecision)?

    /// Called whenever a download's progress or state changes (including the
    /// final completed/canceled update). `control` is the live
    /// pause/resume/cancel controller while the transfer is active, `nil`
    /// from the terminal update on.
    public var onDownloadProgress: ((CefDownload, CefDownloadControl?) -> Void)?

    /// Called just before a page context menu is shown. Mutate `menu` to add,
    /// remove, or replace items (CEF's standard Back/Forward/Reload/Copy/Paste/
    /// View Source/etc. are already present). When `nil`, the default menu is
    /// shown unchanged.
    public var onConfigureContextMenu: ((CefMenuModel, CefContextMenuParams) -> Void)?

    /// Called when a context-menu command is selected. Return `true` if you
    /// handled a custom (user-range) command; `false` lets CEF run its built-in
    /// command (navigate, clipboard, view-source, …). When `nil`, all commands
    /// fall through to CEF.
    public var onContextMenuCommand: ((Int, CefContextMenuParams) -> Bool)?

    /// Called when the page requests one or more permissions (camera,
    /// microphone, geolocation, notifications, …). Return `true` if you
    /// retained the callback and will resolve it later (Chrome-style prompt);
    /// `false` falls back to the synchronous `requestsPermission` decision
    /// (which defaults to deny).
    public var onPermissionPrompt: ((CefPermissionRequest, CefPermissionPromptCallback) -> Bool)?

    /// Called when CEF dismisses an outstanding permission prompt without an
    /// app decision (the page closed or navigated away). Clear any UI you
    /// presented for the matching prompt id (the value on
    /// `CefPermissionRequest.promptID`).
    public var onPermissionPromptDismissed: ((UInt64) -> Void)?

    /// Called whenever the browser's main-frame URL changes (including
    /// navigations and in-page history transitions). Lets the host drop
    /// per-tab transient UI (e.g. a pending permission prompt for a page that
    /// just navigated away).
    public var onURLChanged: ((URL?) -> Void)?
    /// The main frame failed to load. Delivers the Chromium error code,
    /// a human-readable description, and the URL that failed.
    public var onLoadError: ((Int, String, URL?) -> Void)?

    /// The renderer process for this browser terminated unexpectedly (crash,
    /// out-of-memory, kill, or launch failure). Delivers the termination reason
    /// and the Chromium error code. The host owns recovery; this only reports.
    public var onRendererTerminated: ((CefTerminationReason, Int) -> Void)?

    /// The main frame encountered a certificate-validation failure.
    /// Returning `true` overrides the failure and continues the load;
    /// returning `false` cancels it (CEF shows its own error page).
    /// Delivers the failed URL and the Chromium net-error code
    /// (ERR_CERT_* — e.g. -200..-216).
    public var onCertificateError: ((URL?, Int) -> Bool)?

    /// Called before a navigation starts (`on_before_browse`). Return
    /// ``CefNavigationDecision/allow`` to proceed, or ``CefNavigationDecision/cancel``
    /// to block the load — e.g. to hand an external scheme (`mailto:`, `tel:`)
    /// to the OS instead of rendering an error page. When `nil`, all
    /// navigations are allowed.
    public var onNavigationPolicy: ((URL?, _ isRedirect: Bool, _ userGesture: Bool) -> CefNavigationDecision)?

    /// Called once when a CEF browser is created and attached to this model.
    /// Use this to wire up CDP or other per-browser infrastructure.
    public var onBrowserAttached: ((CefBrowser) -> Void)?

    /// Set while mirroring a browser-reported address change into ``url``,
    /// so the `didSet` observer doesn't navigate again.
    @ObservationIgnored private var isApplyingBrowserURL = false

    // MARK: Lifecycle

    /// Creates a view model, optionally with an initial URL and browser options.
    /// - Parameters:
    ///   - url: The URL to load once a browser is created.
    ///   - options: Creation-time browser options (runtime style, background color).
    public init(url: URL? = nil, options: CefBrowserOptions = .init()) {
        self.url = url
        self.options = options
    }

    /// Adopts a freshly created browser. Called by the hosting view.
    func attach(_ browser: CefBrowser) {
        self.browser = browser
        browser.delegate = self
        // Seed mirrored state from the browser's current values.
        title = browser.title
        isLoading = browser.isLoading
        canGoBack = browser.canGoBack
        canGoForward = browser.canGoForward
        if let browserURL = browser.url {
            isApplyingBrowserURL = true
            url = browserURL
            isApplyingBrowserURL = false
        }
        onBrowserAttached?(browser)
    }

    /// Disowns the current browser (closing is the hosting view's responsibility).
    func detach() {
        if browser?.delegate === self {
            browser?.delegate = nil
        }
        browser = nil
    }

    // MARK: Commands

    /// Navigates to `url` (equivalent to assigning ``url``).
    public func load(_ url: URL) {
        self.url = url
    }

    /// Navigates back in history.
    public func goBack() { browser?.goBack() }

    /// Navigates forward in history.
    public func goForward() { browser?.goForward() }

    /// Reloads the current page.
    public func reload() { browser?.reload() }

    /// Reloads the current page bypassing caches (hard reload, ⌥⌘R).
    public func reloadIgnoringCache() { browser?.reload(ignoreCache: true) }

    /// Stops the current load.
    public func stopLoading() { browser?.stopLoading() }

    /// Executes JavaScript in the page's main frame.
    /// - Parameter script: The JavaScript source to evaluate.
    public func executeJavaScript(_ script: String) {
        browser?.executeJavaScript(script)
    }
}

// MARK: - CefBrowserDelegate

extension CefWebViewModel: CefBrowserDelegate {

    public func browser(_ b: CefBrowser, didChangeTitle title: String) {
        self.title = title
    }

    public func browser(_ b: CefBrowser, didChangeURL url: URL?) {
        isApplyingBrowserURL = true
        self.url = url
        isApplyingBrowserURL = false
        onURLChanged?(url)
    }

    public func browser(_ b: CefBrowser, didFailLoad code: Int, errorText: String, failedURL: String) {
        onLoadError?(code, errorText, URL(string: failedURL))
    }

    public func browser(_ b: CefBrowser, renderProcessDidTerminate reason: CefTerminationReason, errorCode: Int) {
        onRendererTerminated?(reason, errorCode)
    }

    public func browser(_ b: CefBrowser, didEncounterCertificateError url: URL?, errorCode: Int) -> Bool {
        onCertificateError?(url, errorCode) ?? false
    }

    public func browser(
        _ b: CefBrowser,
        didChangeLoading isLoading: Bool,
        canGoBack: Bool,
        canGoForward: Bool
    ) {
        self.isLoading = isLoading
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        if !isLoading {
            estimatedProgress = 1
        }
    }

    public func browser(_ b: CefBrowser, didChangeProgress progress: Double) {
        estimatedProgress = progress
    }

    public func browser(_ b: CefBrowser, didChangeFavicon urls: [URL]) {
        faviconURL = urls.first
    }

    public func browser(_ b: CefBrowser, requestsPopupFor url: URL?) -> CefPopupDecision {
        onPopupRequest?(url) ?? .allow
    }

    public func browser(_ b: CefBrowser, decideWindowOpenFor request: CefWindowOpenRequest) -> CefWindowOpenAction {
        if let onWindowOpen {
            return CefWindowOpenPolicy.resolve(onWindowOpen(request), for: request)
        }
        // If only the legacy popup hook is set, bridge it; otherwise apply the
        // safe default policy (OSR never gets a native popup).
        if let onPopupRequest {
            return CefWindowOpenPolicy.action(for: onPopupRequest(request.targetURL), request: request)
        }
        return CefWindowOpenPolicy.defaultAction(for: request)
    }

    public func browserDidClose(_ b: CefBrowser) {
        detach()
        isLoading = false
        canGoBack = false
        canGoForward = false
    }

    public func browser(
        _ b: CefBrowser,
        didReceiveConsoleMessage message: String,
        level: CefLogSeverity,
        source: String,
        line: Int
    ) {
        onConsoleMessage?(message)
    }

    public func browser(
        _ b: CefBrowser,
        decidePolicyForDownload download: CefDownload,
        suggestedName: String
    ) -> CefDownloadDecision {
        onDownloadDecision?(download, suggestedName) ?? .allow(destination: nil)
    }

    public func browser(_ b: CefBrowser, downloadDidProgress download: CefDownload, control: CefDownloadControl?) {
        onDownloadProgress?(download, control)
    }

    public func browser(_ b: CefBrowser, configureContextMenu menu: CefMenuModel, params: CefContextMenuParams) {
        onConfigureContextMenu?(menu, params)
    }

    public func browser(_ b: CefBrowser, contextMenuCommand commandID: Int, params: CefContextMenuParams) -> Bool {
        onContextMenuCommand?(commandID, params) ?? false
    }

    public func browser(
        _ b: CefBrowser,
        presentPermissionPrompt request: CefPermissionRequest,
        callback: CefPermissionPromptCallback
    ) -> Bool {
        onPermissionPrompt?(request, callback) ?? false
    }

    public func browser(_ b: CefBrowser, didDismissPermissionPrompt promptID: UInt64) {
        onPermissionPromptDismissed?(promptID)
    }

    public func browser(
        _ b: CefBrowser,
        decidePolicyForNavigation url: URL?,
        isRedirect: Bool,
        userGesture: Bool
    ) -> CefNavigationDecision {
        onNavigationPolicy?(url, isRedirect, userGesture) ?? .allow
    }
}
