import SwiftUI
import AppKit
import HiveCore

// MARK: - BrowserWindow
//
// The assembled browser surface. It renders EXACTLY ONE chrome layout (the owner's locked
// directive: "HIVE LETS USERS PICK ONE OR THE OTHER. NOT BOTH AT THE SAME TIME.") keyed off
// `state.prefs.tabPosition`:
//
//   • `.top`        →  a top chrome strip: `TabBarView` + `OmniBarView` (in `TopChromeView`)
//   • `.vertical`  →  a left `VerticalTabBarView` + a top `CompactTopChromeView` (omnibar only)
//
// The layout-aware chrome is hosted via `safeAreaInset` so the **content (the WebView stack) is a
// single, always-present child**. Crucial consequence: the H↔V toggle and the rail
// expand/collapse do NOT recreate the WKWebViews → no page reload, scroll position preserved,
// exactly the SPEC §7.4 "content stays put; only chrome rearranges" behavior. A naive
// if/else-of-containers would swap the parent and tear down the webviews on every toggle.
//
// The H↔V morph itself uses `matchedGeometryEffect(id: "omnibar", …)` on `OmniBarView` across
// the two top-bar branches so the address bar hero-animates between its horizontal framing and
// its vertical framing. The toggle is wrapped in `withAnimation(.hiveExpand)`.
//
// `@Namespace` lives here (the assembler) per the plan, not inside the leaf views.

struct BrowserWindow: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var chromeNamespace

    private var isHorizontal: Bool { state.prefs.tabPosition == .top }

    /// Mission Control / Window-menu label, following the Chrome/Safari convention:
    /// the active page's title, the host when untitled, "New Tab" for the start page.
    /// `BrowserTab.displayTitle` already encodes that fallback chain.
    private var windowTitle: String { state.activeTab?.displayTitle ?? "Hive" }

    var body: some View {
        ZStack {
            contentFill
                .safeAreaInset(edge: .top, spacing: 0) { topBar }
                .safeAreaInset(edge: .leading, spacing: 0) { leadingRail }
                .safeAreaInset(edge: .trailing, spacing: 0) { trailingRail }
                .background(Color.hiveBackground)
                .navigationTitle(windowTitle)
                // Animate the chrome restructuring (H↔V) + any inset width change with the expand
                // spring. reduceMotion falls back to the 0.12s linear (HiveMotion respects it).
                //
                // The H↔V toggle uses a 0.45s spring (expand preset) so the omnibar has time
                // to hero-animate via matchedGeometryEffect. The top bar's VStack content
                // swaps between horizontal and vertical chrome, but the ZStack keeps webviews
                // alive — no page reload on layout switch.
                .animation(toggleMotion, value: isHorizontal)
                .animation(railMotion, value: state.prefs.sidebarOpen)
                .animation(railMotion, value: state.isPinnedAppsExpanded)
                .animation(.hiveMicro, value: state.prefs.showBookmarkBar)
                .animation(.hiveExpand, value: state.isSwarmOpen)
                .animation(.hiveCollapse, value: state.isFocusMode)
                .transaction { t in
                    // Ensure the H↔V morph always animates even if the state change happens
                    // outside a withAnimation block. This guarantees smooth layout switching
                    // from the Settings panel or Command Palette.
                    t.animation = t.animation ?? toggleMotion
                }
                // Native title-bar hiding is done at the scene level (windowStyle(.hiddenTitleBar)
                // in HiveApp) — not via a toolbar placement, which macOS doesn't expose here.
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Hive browser window")

            // §6 Tab Overview — hidden button for the ⌘⇧O keyboard shortcut (SwiftUI resolves
            // the gesture and fires toggleTabOverview on ChromeState).
            Button("") { state.toggleTabOverview() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .hidden()

            // Command Palette — hidden button for the ⌘K shortcut.
            Button("") { state.toggleCommandPalette() }
                .keyboardShortcut("k", modifiers: .command)
                .hidden()

            // Downloads — hidden button for the ⌘⇧J keyboard shortcut.
            Button("") { state.toggleDownloadsPanel() }
                .keyboardShortcut("j", modifiers: [.command, .shift])
                .hidden()

            // History — hidden button for the ⌘Y keyboard shortcut.
            Button("") { state.toggleHistoryPanel() }
                .keyboardShortcut("y", modifiers: .command)
                .hidden()

            // Bookmark — hidden button for the ⌘D keyboard shortcut.
            Button("") { state.toggleBookmark() }
                .keyboardShortcut("d", modifiers: .command)
                .hidden()

            // Bookmarks panel — hidden button for the ⌘⌥B keyboard shortcut.
            Button("") { state.toggleBookmarksPanel() }
                .keyboardShortcut("b", modifiers: [.command, .option])
                .hidden()

            // Reading List — hidden button for the ⌘⇧L keyboard shortcut.
            Button("") { state.toggleReadingListPanel() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .hidden()

            // Tab Search — hidden button for the ⌘⇧A keyboard shortcut.
            Button("") { state.toggleTabSearch() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .hidden()

            // Bookmark bar — hidden button for ⌘⇧B.
            Button("") { state.toggleBookmarkBar() }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .hidden()

            // Zoom — hidden buttons for ⌘+/⌘-/⌘0.
            Button("") { state.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)
                .hidden()
            Button("") { state.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .hidden()
            Button("") { state.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
                .hidden()

            // Print — hidden button for ⌘P.
            Button("") { state.printActiveTab() }
                .keyboardShortcut("p", modifiers: .command)
                .hidden()

            // Reload — ⌘R always reloads (decoupled from the omnibar's visible reload↔stop
            // button, which swaps to a stop affordance while loading). Standard browser
            // muscle memory: ⌘R reloads even mid-load. The on-screen button still offers
            // click-to-stop for pointer users.
            Button("") { state.requestNav(.reload) }
                .keyboardShortcut("r", modifiers: .command)
                .hidden()

            // Fullscreen — hidden button for ⌘⌃F.
            Button("") { state.toggleFullscreen() }
                .keyboardShortcut("f", modifiers: [.command, .control])
                .hidden()

            // Stop Loading — Esc key to stop the active tab's page load.
            Button("") { state.requestNav(.stop) }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()

            // Ctrl+Tab — cycle through tabs in most-recently-used order.
            Button("") { state.cycleMRU(forward: true) }
                .keyboardShortcut(.tab, modifiers: .control)
                .hidden()
            Button("") { state.cycleMRU(forward: false) }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
                .hidden()

            // Settings — ⌘, shortcut (standard macOS).
            Button("") {
                if #available(macOS 14.0, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
                .keyboardShortcut(",", modifiers: .command)
                .hidden()

            // Find-in-Page — hidden button for the ⌘F keyboard shortcut.
            Button("") { state.toggleFindInPage() }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()

            // Swarm sidebar — hidden button for ⌘⇧Space shortcut.
            Button("") { state.toggleSwarm() }
                .keyboardShortcut(.space, modifiers: [.command, .shift])
                .hidden()

            // Tree tabs — hidden buttons for ⌘⇧C (new child tab) and ⌘⇧E (toggle fold).
            Button("") { state.newChildTabUnderActive() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .hidden()
            Button("") { state.toggleTreeFoldForActive() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .hidden()

            // Little Arc — hidden button for ⌘⇧A keyboard shortcut.
            Button("") { state.openActiveTabInLittleArc() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .hidden()

            // Focus Mode — hidden button for ⌘. keyboard shortcut.
            Button("") { state.toggleFocusMode() }
                .keyboardShortcut(".", modifiers: .command)
                .hidden()

            // Screenshot — hidden button for ⌘⇧S keyboard shortcut.
            Button("") { state.requestScreenshot() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .hidden()

            // Split View — hidden buttons for ⌘\ (toggle split), ⌘⇧\ (close split),
            // and ⌘⌥\ (cycle orientation).
            Button("") { state.toggleSplit() }
                .keyboardShortcut("\\", modifiers: .command)
                .hidden()
            Button("") { state.closeSplit() }
                .keyboardShortcut("\\", modifiers: [.command, .shift])
                .hidden()
            Button("") { state.cycleSplitOrientation() }
                .keyboardShortcut("\\", modifiers: [.command, .option])
                .hidden()

            // §6 Tab Overview — the ⌘⇧O overlay, drawn on top of chrome + content. Always
            // rendered in the ZStack so webviews behind it survive open/close without a reload.
            TabOverviewView()

            // Command Palette — the ⌘K overlay, drawn on top of chrome + content.
            CommandPaletteView()
                .opacity(state.isCommandPaletteOpened ? 1 : 0)
                .allowsHitTesting(state.isCommandPaletteOpened)
                .animation(.hiveMicro, value: state.isCommandPaletteOpened)

            // Downloads — the ⌘J panel, drawn on top of chrome + content.
            DownloadsView()
                .opacity(state.isDownloadsPanelOpen ? 1 : 0)
                .allowsHitTesting(state.isDownloadsPanelOpen)
                .animation(.hiveMicro, value: state.isDownloadsPanelOpen)

            // History — the ⌘Y panel, drawn on top of chrome + content.
            HistoryView()
                .opacity(state.isHistoryPanelOpen ? 1 : 0)
                .allowsHitTesting(state.isHistoryPanelOpen)
                .animation(.hiveMicro, value: state.isHistoryPanelOpen)

            // Bookmarks — the ⌘⌥B panel, drawn on top of chrome + content.
            BookmarksPanelView()
                .opacity(state.isBookmarksPanelOpen ? 1 : 0)
                .allowsHitTesting(state.isBookmarksPanelOpen)
                .animation(.hiveMicro, value: state.isBookmarksPanelOpen)

            // Reading List — the ⌘⇧L panel, drawn on top of chrome + content.
            ReadingListView()
                .opacity(state.isReadingListPanelOpen ? 1 : 0)
                .allowsHitTesting(state.isReadingListPanelOpen)
                .animation(.hiveMicro, value: state.isReadingListPanelOpen)

            // Tab Search — the ⌘⇧A overlay (Brave-style tab_focus_page). Drawn above all
            // chrome + content with a dimmed backdrop and click-to-switch.
            if state.isTabSearchOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { state.isTabSearchOpen = false }
                TabSearchView()
                    .transition(.opacity)
            }

            // Tab Hover Preview — rendered at window level (above all chrome/clipping).
            // Driven by `state.previewTabID` which is set after a 500ms sustained hover
            // by TabHoverPreviewModifier on each tab pill/row. Positioned near the top
            // (horizontal layout) or leading edge (vertical layout) so it appears near
            // the tab that triggered it. zIndex below full-screen overlays (which get 100+).
            if let previewID = state.previewTabID,
               let previewTab = state.tabs.first(where: { $0.id == previewID }) {
                let edge: TabHoverPreview.Edge = state.prefs.tabPosition == .top ? .above : .trailing
                TabHoverPreview(tab: previewTab, edge: edge)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: edge == .above ? .top : .leading)
                    .padding(.top, edge == .above ? 44 : 8)
                    .padding(.leading, edge == .trailing ? 56 : 8)
                    .zIndex(5)
                    .transition(.opacity.combined(with: .scale(0.96)))
                    .animation(.hiveMicro, value: state.previewTabID)
            }

            // Screenshot overlay — fullscreen overlay shown after ⌘⇧S capture.
            if state.isScreenshotOverlayShown {
                ScreenshotOverlayView()
                    .zIndex(80)
                    .transition(.opacity)
            }

            // §19 First-launch onboarding — drawn above everything until completed.
            if !state.prefs.hasCompletedOnboarding {
                OnboardingView()
                    .zIndex(100)
            }
        }
            // §9 trust primitive — flush the session when the app is about to terminate, so the
            // last state lands on disk before the process exits. The synchronous path avoids
            // awaiting an actor (the notification fires on the main thread, often with no time
            // left to `await`); `flushSessionSync` writes via a nonisolated temp-file-then-swap.
            // Little Arc promote-to-tab — when the user clicks "Open in Main Window"
            // in a Little Arc popup, open the URL as a new tab in the active space.
            .onReceive(NotificationCenter.default.publisher(for: .littleArcPromoteToTab)) { note in
                if let url = note.userInfo?["url"] as? URL {
                    state.newTab(url: url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSApplication.willTerminateNotification)
            ) { _ in state.flushSessionSync() }
            // §8 hibernation — run the trigger policy on a ~30s cadence so idle tabs free their
            // WKWebView RAM without the user noticing. The policy decision is pure
            // (HibernationPolicy.evaluate); hibernationTick performs the capture + tear-down.
            // Audio-defer is empty until audio-detection is wired; the cadence is coarse enough
            // (30s ticks) that no per-frame work happens here. See ChromeState.hibernationTick.
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                state.hibernationTick()
            }
            // §7 auto-archive — runs the archive policy on a ~1h cadence (cheap — the policy is
            // a pure fn checking lastVisitedAt against a 14d threshold; typical response: empty set).
            .onReceive(Timer.publish(every: 3600, on: .main, in: .common).autoconnect()) { _ in
                state.archiveTick()
            }
            // §9 crash-only contract — surface the launch-time recovery notice (never a silent
            // loss). The alert is presented iff `sessionRecoveryNotice != .none`; "Start Fresh"
            // drops the offered state and seeds one tab (the backup file is left intact, so the
            // choice is reversible). See ChromeState.startFresh / restore.
            .alert(sessionRecoveryTitle,
                   isPresented: Binding(
                       get: { state.sessionRecoveryNotice != .none },
                       set: { if !$0 { state.sessionRecoveryNotice = .none } })
            ) {
                if state.sessionRecoveryNotice == .recoveredFromBackup {
                    Button("Start Fresh", role: .destructive) { state.startFresh() }
                    Button("Keep Restored Session") { state.sessionRecoveryNotice = .none }
                } else {
                    Button("OK", role: .cancel) { state.sessionRecoveryNotice = .none }
                }
            } message: {
                Text(sessionRecoveryMessage)
            }
    }

    // MARK: §9 recovery copy

    private var sessionRecoveryTitle: String {
        switch state.sessionRecoveryNotice {
        case .recoveredFromBackup: return "Restored from an earlier backup"
        case .lostNoBackup:         return "Couldn't restore your last session"
        case .none:                 return ""
        }
    }
    private var sessionRecoveryMessage: String {
        switch state.sessionRecoveryNotice {
        case .recoveredFromBackup:
            return "Hive couldn't read your most recent session, so it restored an earlier backup. Keep it, or start fresh."
        case .lostNoBackup:
            return "Your previous session was unreadable and no backup was found. Hive started fresh. Your saved bookmarks and history are unaffected."
        case .none:
            return ""
        }
    }

    // MARK: Content (the single, never-torn-down child)

    /// All open tabs' web views, stacked; only the active one is hit-testable + opaque. Each
    /// tab keeps its own WKWebView alive in the background (state/scroll preserved on switch).
    /// Hibernated tabs are OMITTED from the stack — their WKWebView is dropped to free RAM; a
    /// `.id(tab.id)` rebuild restores it from the broker sprite when the tab wakes (select/flip).
    ///
    /// When Split View is active (2–4 panes), renders `SplitContainerView` with draggable
    /// dividers instead of the stacked ZStack. Each pane hosts its own ChromeWebArea.
    /// If splitTabIDs contains stale IDs (closed/hibernated tabs reducing the live count
    /// below 2), falls back to the single-pane ZStack.
    @ViewBuilder private var contentFill: some View {
        if state.isSplitActive {
            SplitContainerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
        } else {
            ZStack(alignment: .topLeading) {
                if state.tabs.isEmpty {
                    StartPlaceholder()
                } else {
                    ForEach(state.tabs) { tab in
                        if !tab.isHibernated {
                            ChromeWebArea(tab: tab)
                                .opacity(tab.id == state.activeTabID ? 1 : 0)
                                .allowsHitTesting(tab.id == state.activeTabID)
                                .id(tab.id)
                        } else {
                            hibernationPlaceholder(tab)
                                .opacity(tab.id == state.activeTabID ? 1 : 0)
                                .allowsHitTesting(tab.id == state.activeTabID)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
            // Tab-switch crossfade — a fast ~120ms opacity blend between the old and new
            // active webview (Chrome-class). Background tabs are already resident in this
            // ZStack, so this is a pure layer-opacity animation: no reload, no teardown,
            // scroll position untouched. Respects reduce-motion with a 80ms linear fallback.
            .animation(reduceMotion ? .linear(duration: 0.08) : .easeInOut(duration: 0.12),
                       value: state.activeTabID)
        }
    }

    // MARK: Top bar (H ↔ V branch)

    @ViewBuilder private var topBar: some View {
        if !state.isFocusMode {
            VStack(spacing: 0) {
                if isHorizontal {
                    // No horizontal SpaceBar row here. The SPEC §7.4 Mode-A wireframe is
                    // two rows — tab strip, then omnibar — with nothing between. A workspace
                    // pills row (SpaceBarView) had been inserted between them, inflating the
                    // chrome to 3 rows and breaking the browser silhouette (the row no
                    // browser ships). It's not in the SPEC's top-tabs wireframe, and it
                    // duplicated Spaces' SPEC-sanctioned home: the vertical rail bottom
                    // (`VerticalTabBarView.spaceRail`, Arc/Zen model). Spaces remain fully
                    // reachable in top-tabs layout via ⌘⌥1–9 (jump), ⌘⌥[/⌘⌥] (cycle), and
                    // the command palette — no feature lost, only the non-browser row.
                    // `TopChromeView.spaceBar` defaults to `EmptyView()`, so omitting it
                    // collapses the chrome back to the 2-row SPEC silhouette. The
                    // `SpaceBarView` type is retained for potential rail/menu reuse.
                    // See PITCH/browser-feel-fixes.md Wave 3.
                    TopChromeView {
                        TabBarView()
                    } omnibar: {
                        OmniBarView()
                            .matchedGeometryEffect(id: "omnibar", in: chromeNamespace)
                    }
                } else {
                    CompactTopChromeView {
                        OmniBarView()
                            .matchedGeometryEffect(id: "omnibar", in: chromeNamespace)
                    }
                }
                // Bookmark bar — rendered below the chrome when enabled. Toggled via ⌘⇧B.
                if state.prefs.showBookmarkBar && !state.chromeRecessed {
                    BookmarkBarView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.hiveMicro, value: state.prefs.showBookmarkBar)
                }
            }
            // Animate chrome recession with a smooth spring.
            .scaleEffect(y: state.chromeRecessed ? 0.85 : 1.0, anchor: .top)
            .opacity(state.chromeRecessed ? 0.92 : 1.0)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Leading rail (vertical only)

    /// EmptyView when horizontal → no leading inset reserved (content goes edge-to-edge to the
    /// left). When vertical, the `VerticalTabBarView` reserves its own animated width (48→240),
    /// and `state.prefs.sidebarOpen` pins it expanded.
    // MARK: Hibernation placeholder

    @ViewBuilder
    private func hibernationPlaceholder(_ tab: BrowserTab) -> some View {
        VStack(spacing: HiveSpacing.s12) {
            if let faviconURL = tab.faviconURL {
                FaviconView(url: faviconURL)
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "globe")
                    .font(HiveTypography.font(.featureTitle))
                    .foregroundStyle(.hiveGraphite.opacity(0.5))
            }
            VStack(spacing: HiveSpacing.s4) {
                Text(tab.displayTitle.isEmpty ? "Hibernated Tab" : tab.displayTitle)
                    .hiveType(.body)
                    .foregroundStyle(.hiveInk.opacity(0.6))
                    .lineLimit(1)
                Text("Click to wake")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hiveBackground)
        .contentShape(Rectangle())
        .onTapGesture { state.selectTab(tab.id) }
        .accessibilityLabel("Hibernated tab: \(tab.displayTitle)")
    }

    @ViewBuilder private var leadingRail: some View {
        if !isHorizontal && !state.isFocusMode {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    VerticalTabBarView()
                    // Pinned web apps rail — appears below the tab bar when apps are pinned.
                    if !state.prefs.pinnedWebApps.isEmpty {
                        Divider().overlay(.hiveGraphite.opacity(0.15))
                        PinnedAppRailView()
                    }
                }
                // Pinned app webview panel — shows when a pinned app is selected and expanded.
                if state.isPinnedAppsExpanded, state.activePinnedAppID != nil {
                    Divider().overlay(.hiveGraphite.opacity(0.15))
                    PinnedAppPanelView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Trailing rail (Swarm intelligence panel)

    /// Right-side sidebar for Swarm: the integrated intelligence surface. Slides in from the
    /// right when `isSwarmOpen` is true. Connected to Honeycomb memory for context-aware Q&A.
    @ViewBuilder private var trailingRail: some View {
        if state.isSwarmOpen && !state.isFocusMode {
            SwarmChatView()
                .frame(minWidth: 280, idealWidth: 360, maxWidth: 480)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    // MARK: Motion presets

    private var toggleMotion: Animation {
        reduceMotion ? .linear(duration: 0.12) : .hiveExpand
    }
    private var railMotion: Animation {
        reduceMotion ? .linear(duration: 0.12) : .hiveExpand
    }
}

// MARK: - ChromeWebArea
//
// One tab's content surface. `WebViewContainer` is an NSViewRepresentable wrapping a single
// WKWebView owned by its Coordinator (created once, survives SwiftUI re-renders). Routing
// `WebViewUpdate` back into `ChromeState` keeps the tab model the source of truth for
// title/url/loading/back-forward/favicon. Privacy is fixed at Coordinator init per tab.

struct ChromeWebArea: View {
    let tab: BrowserTab
    @Environment(ChromeState.self) private var state
    @State private var currentUserActivity: NSUserActivity?

    var body: some View {
        // The command goes ONLY to the active tab; background tabs ignore it. We resolve it
        // here (not later) so when a new command lands while another tab is frontmost, the
        // old tab doesn't receive the stale value on its next update.
        let cmd: WebViewCommand? = (tab.id == state.commandTabID) ? state.pendingCommand : nil
        // The hibernate-request counter for this tab; the Coordinator captures into the broker
        // when it changes (id-gated, see WebViewContainer.updateNSView).
        let hibReq = state.hibernateRequests[tab.id] ?? 0
        let capReq = state.captureRequests[tab.id] ?? 0
        let shotReq = state.screenshotRequests[tab.id] ?? 0
        let readerReq = state.readerModeRequests[tab.id] ?? 0
        let findReq = state.findInPageRequests[tab.id] ?? 0

        ZStack {
            // PDF Viewer: when the tab navigates to a .pdf URL, show native PDFKit viewer.
            if let url = tab.url, url.pathExtension.lowercased() == "pdf" {
                PDFViewer(url: url, filename: url.lastPathComponent)
            } else if tab.url == nil {
                // New tab / empty tab shows the Hive start page instead of a blank webview.
                StartPageView()
            } else {
            WebViewContainer(
                url: tab.url,
                isPrivate: tab.isPrivate,
                command: cmd,
                tabID: tab.id,
                broker: state.sessionBroker,
                hibernateRequestID: hibReq,
                captureRequestID: capReq,
                screenshotRequestID: shotReq,
                readerModeRequestID: readerReq,
                findInPageRequestID: findReq,
                findInPageSearchText: state.findInPageText,
                findInPageForward: state.findInPageDirectionForward,
                enforceHTTPS: state.prefs.enforceHTTPS,
                gpcEnabled: state.prefs.globalPrivacyControlEnabled,
                autofillController: WebViewAutofillController(passwordStore: state.passwordStore),
                permissionState: { host, kind in
                    state.sitePermissionState(host: host, kind: kind, isPrivate: tab.isPrivate)
                },
                setPermission: { host, kind, decision in
                    state.setSitePermission(host: host, kind: kind, state: decision, isPrivate: tab.isPrivate)
                },
                onUpdate: { update in
                    state.applyWebViewUpdate(update, forTabID: tab.id)
                }
            )
            }

            if tab.isReaderMode, let artifact = state.readerArtifacts[tab.id] {
                ReaderModeView(artifact: artifact) {
                    state.toggleReaderMode()
                }
                .transition(.opacity.combined(with: .scale(1.02)))
            }

            // Find-in-Page bar — only visible when active and this tab is the active tab.
            if state.isFindInPageActive, tab.id == state.activeTabID {
                FindInPageBarView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Handoff: update NSUserActivity on every URL navigation so the page
        // is available for Handoff to other Apple devices (iPhone, iPad, other Macs).
        .onChange(of: tab.url) { _, newURL in
            updateHandoff(url: newURL)
        }
        // Share Sheet: right-click context menu on the web area.
        .contextMenu {
            if let url = tab.url {
                Button {
                    shareURL(url)
                } label: {
                    Label("Share…", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: Handoff

    private func updateHandoff(url: URL?) {
        guard let url, let scheme = url.scheme,
              scheme == "http" || scheme == "https" else {
            currentUserActivity?.invalidate()
            currentUserActivity = nil
            return
        }
        let activity = NSUserActivity(activityType: "com.hive.browser.browsing")
        activity.title = tab.displayTitle.isEmpty ? (url.host ?? "Web Page") : tab.displayTitle
        activity.webpageURL = url
        activity.isEligibleForHandoff = true
        activity.becomeCurrent()
        currentUserActivity?.invalidate()
        currentUserActivity = activity
    }

    // MARK: Share Sheet

    private func shareURL(_ url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        if let window = NSApp.keyWindow {
            picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .maxY)
        }
    }
}

// MARK: - StartPlaceholder
//
// Shown when the window has no tabs yet (the very first launch / after closing the last tab).
// Start page: greeting, search, top sites, recent sources, archived tabs. No ads/news.

private struct StartPlaceholder: View {
    var body: some View {
        StartPageView()
    }
}
