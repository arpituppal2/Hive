import SwiftUI
import CefSwiftUI

// MARK: - BrowserWindow
//
// The assembled browser surface. It switches between a Chrome/Edge-style horizontal layout
// and a Zen/Arc/Dia-style vertical layout. An MRU cache keeps the last 3 active tabs'
// CefWebViews alive so page state (scroll, forms, JS) is preserved across tab switches.

struct BrowserWindow: View {

    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var state = state
        baseView
            .overlay { modalOverlays }
            .overlay(alignment: .trailing) { trailingOverlays }
            .overlay(alignment: .center) { centerOverlays }
            .overlay(alignment: .top) { topBannerOverlays }
            .overlay(alignment: .topTrailing) { topTrailingOverlays }
            .overlay(alignment: .bottomTrailing) { MiniPlayerView().transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)) }
            .overlay(alignment: .bottom) { bottomChipOverlays }
            .overlay { TabPeekOverlay() }
            .overlay(alignment: .top) { notificationTray }
            .sheet(isPresented: $state.isBookmarksManagerOpen) { BookmarksManagerSheet() }
            .sheet(isPresented: $state.isCleanTabsPanelOpen) { CleanTabsSheet() }
            .sheet(isPresented: $state.isPasswordsManagerOpen) { PasswordManagerSheet() }
            .sheet(isPresented: $state.isExtensionsManagerOpen) { ExtensionsManagerSheet() }
            .sheet(isPresented: $state.isBoostsPanelOpen) { BoostsSheet() }
            .sheet(isPresented: $state.isPrivacyReportOpen) { PrivacyReportSheet() }
            .sheet(isPresented: $state.isHistoryPanelOpen) { HistoryPanelSheet() }
            .sheet(isPresented: $state.isReadingListPanelOpen) { ReadingListPanel() }
            .sheet(isPresented: $state.isPinnedAppsPanelOpen) { PinnedAppsPanel() }
            .sheet(isPresented: $state.isArchivePanelOpen) { ArchivePanel() }
            .sheet(isPresented: $state.isClearDataPanelOpen) { ClearBrowsingDataSheet() }
            .sheet(isPresented: $state.isSiteSettingsPanelOpen) { SiteSettingsSheet() }
            .sheet(isPresented: $state.isTaskManagerOpen) { TaskManagerSheet() }
            .sheet(isPresented: $state.isSafetyCheckPanelOpen) { SafetyCheckSheet() }
            .sheet(isPresented: $state.isDownloadsPanelOpen) { DownloadManagerSheet() }
            .sheet(isPresented: $state.isWorkspaceManagerPanelOpen) { WorkspaceManagerPanel() }
            .sheet(isPresented: $state.isProfileManagerPanelOpen) { ProfileManagerPanel() }
            .sheet(isPresented: $state.isTabGroupManagerPanelOpen) { TabGroupManagerPanel() }
            .sheet(isPresented: $state.isSearchEngineManagerPanelOpen) { SearchEngineManagerPanel() }
            .sheet(isPresented: $state.isKeyboardShortcutsPanelOpen) { KeyboardShortcutsPanel() }
            .sheet(isPresented: $state.isMemorySaverPanelOpen) { MemorySaverPanel() }
    }

    /// Asymmetric push transition: forward nav slides new content from right,
    /// backward nav slides from left. Initial load uses a plain opacity fade.
    private var navPushTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        switch state.lastNavigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case nil:
            return .opacity
        }
    }

    // MARK: - Base chrome + content

    private var baseView: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 0, height: 0)
                .task { state.setupAI() }
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
                contentArea
            }
        }
        .coordinateSpace(name: BrowserState.peekCoordinateSpaceName)
        .animation(HiveDesign.Animation.ease, value: state.activeTabID)
        .animation(HiveDesign.Animation.smooth, value: state.currentWorkspaceID)
        .sensoryFeedback(.selection, trigger: state.activeTabID)
        .sensoryFeedback(.selection, trigger: state.currentWorkspaceID)
        .background(state.isPrivateBrowsing ? Color(white: 0.12) : Color.hiveBackground)
        .navigationTitle(state.windowTitle)
        .overlay(alignment: .top) { if state.isCompactMode { compactHoverStrip } }
        .overlay(alignment: .leading) { leftEdgeTrigger }
        .background(NewWindowHandler(openWindow: openWindow))
    }

    // MARK: - Content area

    private var contentArea: some View {
        ZStack {
            // Ambient particle field — subtle living background
            HiveAmbientParticles()
                .opacity(state.isNewTab ? 0.5 : 0.15)
                .allowsHitTesting(false)

            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { state.contentAreaFrame = geo.frame(in: .named(BrowserState.peekCoordinateSpaceName)) }
                        .onChange(of: geo.frame(in: .named(BrowserState.peekCoordinateSpaceName))) { _, f in state.contentAreaFrame = f }
                })
                .allowsHitTesting(false)

            // Page load skeleton — shown while a page is loading with no content
            if state.isLoading, let active = state.activeTab, active.model.title.isEmpty {
                PageLoadSkeleton()
                    .transition(.opacity)
                    .padding(.top, 40)
            }
            ForEach(state.mruTabIDs, id: \.self) { tabID in
                if let tab = state.tabs.first(where: { $0.id == tabID }),
                   tabID != state.activeTabID, tabID != state.splitSecondaryTabID {
                    CefWebView(model: tab.model).opacity(0).allowsHitTesting(false)
                }
            }
            if state.isSplitViewActive, let active = state.activeTab, let secondary = state.splitSecondaryTab {
                SplitContentView(primary: active.model, secondary: secondary.model,
                    orientation: state.splitOrientation, ratio: state.splitRatio,
                    onRatioChanged: { state.setSplitRatio($0) }, unsplit: { state.unsplit() })
                    .transition(.opacity)
            } else if let active = state.activeTab {
                CefWebView(model: active.model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(active.id)
                    .transition(navPushTransition)
            }
        }
        // Zen ambient canvas (spec §4): content sits on a rounded, separated
        // outer edge — 8px radius + hairline border + canvas glow behind the
        // page. Chrome mode stays full-bleed.
        .clipShape(
            RoundedRectangle(
                cornerRadius: state.chromeMode == .sidebar ? HiveDesign.Zen.contentRadius : 0,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: state.chromeMode == .sidebar ? HiveDesign.Zen.contentRadius : 0,
                style: .continuous
            )
            .stroke(HiveDesign.Surface.hairline, lineWidth: 1)
        )
        .padding(state.chromeMode == .sidebar ? HiveDesign.Zen.floatGap : 0)
        .background(
            state.chromeMode == .sidebar
                ? AnyShapeStyle(HiveDesign.Surface.canvas)
                : AnyShapeStyle(Color.clear)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Overlay groups

    @ViewBuilder private var modalOverlays: some View {
        if state.isCommandPaletteOpen { CommandPaletteOverlay().transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity)) }
        if state.isTabSearchOpen { TabSearchOverlay().transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity)) }
        if state.isTabGridOpen { TabGridOverlay().transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity)) }
        if state.isGoogleLensActive { GoogleLensOverlay().transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity)) }
        if state.safeBrowsingWarning != nil { SafeBrowsingWarningView().transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity)) }
        if state.isReaderMode { ReaderModeView().transition(.opacity) }
    }

    @ViewBuilder private var trailingOverlays: some View {
        if state.isGeminiPanelOpen { GeminiSidePanel().transition(reduceMotion ? .opacity : .move(edge: .trailing)) }
        if state.isKnowledgePanelOpen { KnowledgePanel().transition(reduceMotion ? .opacity : .move(edge: .trailing)) }
        if state.isStudioPanelOpen { StudioPanel().transition(reduceMotion ? .opacity : .move(edge: .trailing)) }
        if state.isSheetsPanelOpen { SheetsPanel().transition(reduceMotion ? .opacity : .move(edge: .trailing)) }
    }

    @ViewBuilder private var centerOverlays: some View {
        if state.isBriefCaptureOpen { BriefCaptureView().transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity)) }
        if state.isApprovalPanelOpen, let action = state.presentedApprovalAction {
            ActionApprovalView(action: action).id(action.id).transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity))
        }
    }

    @ViewBuilder private var topBannerOverlays: some View {
        if state.isFloatingURLBarVisible { FloatingURLBarOverlay().transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
        if let _ = state.translateBar { TranslateBar().transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
        if state.httpsOnlyNotice != nil { HTTPSOnlyBanner().transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
    }

    @ViewBuilder private var topTrailingOverlays: some View {
        if state.isSiteSecurityPanelOpen { SiteSecurityPopover().padding(.top, 48).padding(.trailing, 12).transition(.opacity.combined(with: .scale(0.95))) }
        if state.isCustomizePanelOpen { CustomizePanel().padding(.top, 48).padding(.trailing, 12).transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)) }
        if state.isFindBarOpen { FindBar().padding(.top, 8).padding(.trailing, 12).transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
    }

    @ViewBuilder private var bottomChipOverlays: some View {
        VStack(spacing: 8) {
            if let offer = state.pendingPasswordCaptureOffer, offer.tabID == state.activeTabID {
                PasswordCaptureChipView(offer: offer).transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            if let suggestion = state.pendingAutofillSuggestion, suggestion.tabID == state.activeTabID {
                AutofillChipView(suggestion: suggestion).transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder private var notificationTray: some View {
        @Bindable var state = state
        VStack(spacing: HiveDesign.Space.xs) {
            if !state.sessionRepairReasons.isEmpty, !state.sessionRepairNoticeDismissed { SessionRepairNotice() }
            if let n = state.navigationHealthNotice { NavigationHealthBanner(notice: n).transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
            if let n = state.loadErrorNotice { NavigationErrorBanner(notice: n).transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
            if let n = state.sessionRecoveryNotice { SessionRecoveryBanner(notice: n).transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
            if let n = state.navigationBlockNotice { NavigationBlockBanner(notice: n).transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
            if let n = state.tabGroupingNotice { HiveToast(message: n, iconName: "square.stack.3d.up.fill").transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
            if let n = state.appNotice { HiveToast(message: n).transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
            if state.isPersistenceDegraded, !state.isPersistenceHealthNoticeDismissed { PersistenceHealthBanner().transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
            if let p = state.pendingPermissionRequests.first { PermissionPromptView(prompt: p).padding(.top, 6).transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
        }
        .padding(.top, state.layout == .horizontal ? 66 : 24)
        .alert("Rename Group", isPresented: Binding(get: { state.renameGroupTargetID != nil }, set: { if !$0 { state.cancelGroupRename() } })) {
            TextField("Group name", text: $state.renameGroupText)
            Button("Rename") { state.commitGroupRename() }
            Button("Cancel", role: .cancel) { state.cancelGroupRename() }
        }
        .alert("Rename Tab", isPresented: Binding(get: { state.renameTabTargetID != nil }, set: { if !$0 { state.cancelTabRename() } })) {
            TextField("Tab name", text: $state.renameTabText)
            Button("Rename") { state.commitTabRename() }
            Button("Cancel", role: .cancel) { state.cancelTabRename() }
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
    let orientation: BrowserState.SplitOrientation
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
