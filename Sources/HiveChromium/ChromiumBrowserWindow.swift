import SwiftUI
import CefSwiftUI

// MARK: - ChromiumBrowserWindow
//
// The assembled browser surface. It switches between a Chrome/Edge-style horizontal layout
// and a Zen/Arc/Dia-style vertical layout. An MRU cache keeps the last 3 active tabs'
// CefWebViews alive so page state (scroll, forms, JS) is preserved across tab switches.

struct ChromiumBrowserWindow: View {

    @Environment(ChromiumBrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var state = state
        HStack(spacing: 0) {
            // The web chrome shell renders the ENTIRE UI (tabs, toolbar,
            // panels) in web content. Native SwiftUI only frames it: a left
            // sidebar in vertical mode, a top strip in horizontal mode.
            if state.chromeMode == .sidebar {
                chromeShell
                    .frame(width: state.chromeDimension)
                    .animation(reduceMotion ? nil : HiveDesign.Animation.spring, value: state.chromeDimension)
            }

            VStack(spacing: 0) {
                if state.chromeMode == .strip {
                    chromeShell
                        .frame(height: state.chromeDimension)
                        .animation(reduceMotion ? nil : HiveDesign.Animation.spring, value: state.chromeDimension)
                }

                    // Main content: active tab + split tab + MRU-cached keepalive tabs.
                    ZStack {
                        // Reports the web content area's window-space frame so
                        // the link-hover peek can convert the page's viewport
                        // coordinates into a card anchor.
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear { state.contentAreaFrame = geo.frame(in: .named(ChromiumBrowserState.peekCoordinateSpaceName)) }
                                        .onChange(of: geo.frame(in: .named(ChromiumBrowserState.peekCoordinateSpaceName))) { _, newFrame in
                                            state.contentAreaFrame = newFrame
                                        }
                                }
                            )
                            .allowsHitTesting(false)
                        // MRU cache: keep the last few active tabs' CEF renderers alive
                        // so page state survives tab switches (scroll, forms, JS).
                        // The split-secondary tab is excluded — it's already rendered
                        // live in the split pane, and CEF can't attach one browser to
                        // two views (double-render would break the renderer).
                        ForEach(state.mruTabIDs, id: \.self) { tabID in
                            if let tab = state.tabs.first(where: { $0.id == tabID }),
                               tabID != state.activeTabID,
                               tabID != state.splitSecondaryTabID {
                                CefWebView(model: tab.model)
                                    .opacity(0)
                                    .allowsHitTesting(false)
                            }
                        }

                        if state.isSplitViewActive,
                           let active = state.activeTab,
                           let secondary = state.splitSecondaryTab {
                            SplitContentView(
                                primary: active.model,
                                secondary: secondary.model,
                                orientation: state.splitOrientation,
                                ratio: state.splitRatio,
                                onRatioChanged: { state.setSplitRatio($0) },
                                unsplit: { state.unsplit() }
                            )
                        } else if let active = state.activeTab {
                            CefWebView(model: active.model)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .coordinateSpace(name: ChromiumBrowserState.peekCoordinateSpaceName)
        .background(state.isPrivateBrowsing ? Color(white: 0.12) : Color.hiveBackground)
        // Live window title: the active page's title, host, or "New Tab".
        // Applied at the window root so only this window is retitled (a
        // key-window probe would wrongly rename other windows when frontmost).
        .navigationTitle(state.windowTitle)
        .overlay(alignment: .top) {
            if state.isCompactMode { compactHoverStrip }
        }
        .overlay(alignment: .leading) {
            leftEdgeTrigger
        }
                .overlay { if state.isCommandPaletteOpen { CommandPaletteOverlay() } }
                .overlay { if state.isTabSearchOpen { TabSearchOverlay() } }
                .overlay { if state.isFloatingURLBarVisible { FloatingURLBarOverlay() } }
                .overlay(alignment: .trailing) { if state.isGeminiPanelOpen { GeminiSidePanel() } }
                .overlay(alignment: .trailing) { if state.isKnowledgePanelOpen { KnowledgePanel() } }
                .background(NewWindowHandler(openWindow: openWindow))
        .overlay(alignment: .trailing) { if state.isStudioPanelOpen { StudioPanel() } }
        .overlay(alignment: .trailing) { if state.isSheetsPanelOpen { SheetsPanel() } }
        .overlay(alignment: .center) { if state.isBriefCaptureOpen { BriefCaptureView() } }
        .overlay(alignment: .center) { if state.isApprovalPanelOpen, let action = state.presentedApprovalAction { ActionApprovalView(action: action).id(action.id) } }
        .overlay(alignment: .top) { if let _ = state.translateBar { TranslateBar() } }
        .overlay { if state.isGoogleLensActive { GoogleLensOverlay() } }
        .overlay { if state.safeBrowsingWarning != nil { SafeBrowsingWarningView() } }
        .overlay { if state.isReaderMode { ReaderModeView().transition(.opacity) } }
        .overlay(alignment: .topTrailing) {
            if state.isSiteSecurityPanelOpen {
                SiteSecurityPopover()
                    .padding(.top, 48)
                    .padding(.trailing, 12)
                    .transition(.opacity.combined(with: .scale(0.95)))
            }
        }
        .overlay(alignment: .topTrailing) {
            if state.isCustomizePanelOpen { CustomizePanel().padding(.top, 48).padding(.trailing, 12) }
        }
        .sheet(isPresented: $state.isBookmarksManagerOpen) { BookmarksManagerSheet() }
        .sheet(isPresented: $state.isPasswordsManagerOpen) { PasswordManagerSheet() }
        .sheet(isPresented: $state.isExtensionsManagerOpen) { ExtensionsManagerSheet() }
        .sheet(isPresented: $state.isPrivacyReportOpen) { PrivacyReportSheet() }
        .sheet(isPresented: $state.isHistoryPanelOpen) { HistoryPanelSheet() }
        .sheet(isPresented: $state.isDownloadsPanelOpen) { DownloadManagerSheet() }
        .overlay(alignment: .topTrailing) {
            if state.isFindBarOpen { FindBar().padding(.top, 8).padding(.trailing, 12) }
        }
        .overlay(alignment: .bottomTrailing) { MiniPlayerView() }
        // Arc-style live tab peek — always in the hierarchy so pooled preview
        // browsers stay alive; fades in/out around the hovered tab pill.
        .overlay { TabPeekOverlay() }
        .overlay(alignment: .top) {
            VStack(spacing: HiveDesign.Space.xs) {
                if !state.sessionRepairReasons.isEmpty, !state.sessionRepairNoticeDismissed {
                    SessionRepairNotice()
                }
                if let notice = state.navigationHealthNotice {
                    NavigationHealthBanner(notice: notice)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                if let notice = state.sessionRecoveryNotice {
                    SessionRecoveryBanner(notice: notice)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                if let notice = state.navigationBlockNotice {
                    NavigationBlockBanner(notice: notice)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                if state.isPersistenceDegraded, !state.isPersistenceHealthNoticeDismissed {
                    PersistenceHealthBanner()
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, state.layout == .horizontal ? 66 : 24)
            // Window-level rename alert for tab groups. Owned here (not in the
            // chrome views) so both group context menus share one prompt.
            .alert("Rename Group", isPresented: Binding(
                get: { state.renameGroupTargetID != nil },
                set: { if !$0 { state.cancelGroupRename() } }
            )) {
                TextField("Group name", text: $state.renameGroupText)
                Button("Rename") { state.commitGroupRename() }
                Button("Cancel", role: .cancel) { state.cancelGroupRename() }
            }
        }
    }

    // MARK: - Web chrome shell

    /// The persistent web-chrome browser. In sidebar mode it is the left rail
    /// (tabs, toolbar, panels); in strip mode it is the top bar. Everything
    /// inside it is HTML/CSS/JS served by the app itself.
    @ViewBuilder private var chromeShell: some View {
        if let chrome = state.chromeModel {
            CefWebView(model: chrome)
        }
    }

    // MARK: - Compact Mode hover-to-reveal (Zen-style edge reveals)

    /// Tracks whether the top reveal strip is being hovered.
    /// When true, the collapsed toolbar temporarily expands, floating over
    /// the page — content is never pushed down.
    @State private var isTopStripHovered: Bool = false

    /// Tracks whether the left-edge trigger zone is being hovered.
    /// Zen separates the two reveals: the top strip shows the toolbar,
    /// the left edge slides the sidebar out.
    @State private var isLeftEdgeHovered: Bool = false

    /// The vertical sidebar is revealed when compact mode is off, or when
    /// the left-edge trigger zone (or the sidebar itself, once open) is
    /// hovered. The top strip does NOT open the sidebar.
    private var isSidebarRevealed: Bool {
        !state.isCompactMode || isLeftEdgeHovered
    }

    /// A thin accent strip that overlays the top of the window in compact mode.
    /// Hovering reveals the full chrome without pushing page content down.
    private var compactHoverStrip: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(state.browserAccentColor.opacity(0.4))
                .frame(height: isTopStripHovered ? 0 : 4)
            if isTopStripHovered {
                if state.layout == .horizontal {
                    HorizontalChromeView()
                } else {
                    CompactAddressBar()
                }
            }
        }
        .background(state.browserAccentColor.opacity(isTopStripHovered ? 0.06 : 0))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : HiveDesign.Animation.springQuick) {
                isTopStripHovered = hovering
            }
        }
    }

    /// Zen-style left-edge trigger: a 6px transparent zone at the window's
    /// leading edge that slides the sidebar out when hovered. Present only
    /// while the sidebar is collapsed — once open, the sidebar's own hover
    /// keeps it open and it collapses when the cursor leaves.
    @ViewBuilder private var leftEdgeTrigger: some View {
        if state.isCompactMode && state.layout == .vertical && !isSidebarRevealed {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isLeftEdgeHovered ? state.browserAccentColor.opacity(0.35) : Color.clear)
                    .frame(width: isLeftEdgeHovered ? 3 : 2)
                Spacer(minLength: 0)
            }
            .frame(width: 6)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) {
                    isLeftEdgeHovered = hovering
                }
            }
        }
    }

}

// MARK: - SplitContentView
//
// Two-pane split view with a draggable divider (Safari/Arc parity).
// Extracted into its own struct so the parent window body stays
// type-checkable and so the divider can own its cursor state.

struct SplitContentView: View {
    let primary: CefWebViewModel
    let secondary: CefWebViewModel
    let orientation: ChromiumBrowserState.SplitOrientation
    let ratio: Double
    let onRatioChanged: (Double) -> Void
    let unsplit: () -> Void

    @State private var dividerHovered = false
    /// Ratio captured when the drag starts — frozen so cumulative translation
    /// can be applied without double-counting (render-time ratio re-updates
    /// mid-drag, which would accelerate the divider past the cursor).
    @State private var dragStartRatio: Double?

    /// True when the divider is a vertical line (side-by-side panes).
    private var isVerticalDivider: Bool { orientation == .sideBySide }

    var body: some View {
        GeometryReader { geo in
            if isVerticalDivider {
                sideBySideLayout(total: max(geo.size.width, 1))
            } else {
                topBottomLayout(total: max(geo.size.height, 1))
            }
        }
    }

    // MARK: Side-by-side (vertical divider)

    private func sideBySideLayout(total: CGFloat) -> some View {
        let primaryWidth = total * CGFloat(ratio)
        return HStack(spacing: 0) {
            CefWebView(model: primary)
                .frame(width: primaryWidth)
                .frame(maxHeight: .infinity)

            divider(.vertical, total: total)

            CefWebView(model: secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) { unsplitButton }
    }

    // MARK: Top-and-bottom (horizontal divider)

    private func topBottomLayout(total: CGFloat) -> some View {
        let primaryHeight = total * CGFloat(ratio)
        return VStack(spacing: 0) {
            CefWebView(model: primary)
                .frame(height: primaryHeight)
                .frame(maxWidth: .infinity)

            divider(.horizontal, total: total)

            CefWebView(model: secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) { unsplitButton }
    }

    // MARK: Divider

    /// Draggable divider (Safari/Arc parity). Wider transparent hit area
    /// (8pt) so hover + drag targets match; hairline drawn as overlay.
    /// Cursor matches the orientation: resizeLeftRight for side-by-side,
    /// resizeUpDown for top-and-bottom.
    private func divider(_ axis: Axis, total: CGFloat) -> some View {
        let isVertical = axis == .vertical
        return ZStack {
            Rectangle()
                .fill(Color.hiveAccent.opacity(0.25))
                .frame(width: isVertical ? 3 : nil, height: isVertical ? nil : 3)
            Rectangle()
                .fill(HiveDesign.Surface.hairline)
                .frame(width: isVertical ? 1 : nil, height: isVertical ? nil : 1)
        }
        .frame(width: isVertical ? 8 : nil, height: isVertical ? nil : 8)
        .frame(maxWidth: isVertical ? nil : .infinity, maxHeight: isVertical ? .infinity : nil)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    // Freeze the start ratio on the first event, then apply
                    // cumulative translation. Drift-free and independent of
                    // any coordinate-space API.
                    let start = dragStartRatio ?? ratio
                    dragStartRatio = start
                    let delta = isVertical
                        ? value.translation.width
                        : value.translation.height
                    onRatioChanged(start + Double(delta / total))
                }
                .onEnded { _ in
                    dragStartRatio = nil
                }
        )
        .onHover { hovering in
            dividerHovered = hovering
            if hovering {
                (isVertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            // Pop the resize cursor if the split ends while hovered
            // (push/pop is a stack — leaving it pushed would leak).
            if dividerHovered { NSCursor.pop() }
            // Reset drag state for interrupted drags (no onEnded fired).
            dragStartRatio = nil
        }
    }

    private var unsplitButton: some View {
        Button(action: unsplit) {
            HStack(spacing: 4) {
                Image(systemName: "xmark").font(HiveDesign.Typography.captionBold)
                Text("Unsplit").font(HiveDesign.Typography.smallLabelMedium)
            }
            .foregroundStyle(HiveDesign.Text.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(HiveDesign.Material.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close split view")
        .padding(.top, 6).padding(.trailing, 6)
    }
}

/// Minimal invisible view that opens a new WindowGroup window when the web
/// chrome's ⌘N bridge posts HiveRequestNewWindow. Kept separate from the main
/// modifier chain so the compiler can type-check it in reasonable time.
private struct NewWindowHandler: View {
    @Environment(\.openWindow) private var envOpenWindow
    let openWindow: OpenWindowAction

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name("HiveRequestNewWindow")
            )) { _ in
                envOpenWindow(id: "main")
            }
    }
}
