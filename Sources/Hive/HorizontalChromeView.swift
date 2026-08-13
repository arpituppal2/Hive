import SwiftUI
import HiveCore

// MARK: - HorizontalChromeView
//
// Premium horizontal browser chrome. Chrome-parity proportions:
//   Toolbar height: 34px (Chromium source tree)
//   Tab height: 34px, radius: 8px (unified)
//   Close button: 16x16
//   Address bar: 34px height, 24px radius pill
//   Separators: hairline borders from design tokens
//
// All colors/spacing/typography use HiveDesign tokens.

struct HorizontalChromeView: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tabIndicatorNamespace

    private var horizontalUnpinnedTabs: [BrowserState.Tab] {
        state.unpinnedTabs
    }

    private var firstTabIDByGroup: [UUID: String] {
        var firstIDs: [UUID: String] = [:]
        for tab in horizontalUnpinnedTabs {
            guard let groupID = tab.groupID, firstIDs[groupID] == nil else { continue }
            firstIDs[groupID] = tab.id
        }
        return firstIDs
    }

    private var groupTabCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for tab in horizontalUnpinnedTabs {
            guard let groupID = tab.groupID else { continue }
            counts[groupID, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                navigationButtons

                Rectangle()
                    .fill(HiveDesign.Surface.hairline)
                    .frame(width: 1, height: 18)
                    .padding(.horizontal, HiveDesign.Space.xxs + 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    // Spec §3: 2px tab gap (visible pill separation).
                    HStack(spacing: 2) {
                        ForEach(state.iconTabs) { tab in
                            HorizontalEssentialPill(tab: tab)
                        }
                        if !state.iconTabs.isEmpty && !horizontalUnpinnedTabs.isEmpty {
                            Rectangle()
                                .fill(HiveDesign.Surface.hairline)
                                .frame(width: 1, height: 20)
                                .padding(.horizontal, 3)
                        }
                        ForEach(horizontalUnpinnedTabs) { tab in
                            if let group = state.groupForTab(tab),
                               firstTabIDByGroup[group.id] == tab.id {
                                horizontalGroupDisclosure(group, count: groupTabCounts[group.id] ?? 0)
                            }
                            if state.groupForTab(tab)?.isCollapsed != true {
                                HorizontalTabPill(tab: tab, indicatorNamespace: tabIndicatorNamespace)
                                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                            }
                        }
                        newTabButton
                    }
                    .padding(.horizontal, HiveDesign.Chrome.stripPadding)
                }
                .frame(height: HiveDesign.Tab.horizontalHeight)
                .layoutPriority(1)
                .mask(
                    HStack(spacing: 0) {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white, location: 1.0),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 20)
                        Color(hue: 0, saturation: 0, brightness: 1)
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0.0),
                                .init(color: .clear, location: 1.0),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 20)
                    }
                )

                Spacer(minLength: HiveDesign.Space.sm - 2)

                AddressBar()
                    .frame(minWidth: 240, idealWidth: 380)

                Spacer(minLength: HiveDesign.Space.sm - 2)

                rightControls
            }
                .padding(.horizontal, HiveDesign.Chrome.toolbarElementPadding)
                .padding(.vertical, HiveDesign.Chrome.toolbarElementPadding)
                .background(
                    // M3 surface tint (spec §3): the toolbar picks up a ~4%
                    // tint of the active page's theme color (derived from the
                    // favicon), falling back to plain canvas. Applied as a
                    // second background so it renders ABOVE the material — a
                    // flat 4% wash over the blurred surface (Chrome M3 look).
                    HiveDesign.Material.toolbarMaterial
                )
                .background {
                    if let tint = PageThemeColor.forURL(state.activeModel?.faviconURL) {
                        tint.opacity(HiveDesign.Chrome.tintAlpha)
                    }
                }
                // Favicons arrive asynchronously after tab load — re-sample the
                // tint once the active page's favicon materializes.
                .onChange(of: state.activeModel?.faviconURL) { _, _ in
                    // body re-evaluation reads PageThemeColor fresh; no stored
                    // state needed.
                }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(HiveDesign.Surface.hairline)
                    .frame(height: 1)
            }

            if state.showBookmarksBar {
                BookmarksBar()
                    .background(HiveDesign.Material.toolbar)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(HiveDesign.Surface.hairline)
                            .frame(height: 1)
                    }
            }
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: HiveDesign.Chrome.toolbarIconMargin) {
            navButton("chevron.left", enabled: state.canGoBack) { state.goBack() }
                // Chrome/Safari convention: right-click (or control-click) the
                // back/forward buttons to jump to a recent committed entry.
                .contextMenu {
                    if state.activeBackHistory.isEmpty {
                        Text("No back history")
                    } else {
                        ForEach(state.activeBackHistory.prefix(12), id: \.url) { entry in
                            Button {
                                state.navigateFromHistoryMenu(to: entry.url)
                            } label: {
                                Label(entry.title, systemImage: "arrow.left")
                            }
                        }
                    }
                }
            navButton("chevron.right", enabled: state.canGoForward) { state.goForward() }
                .contextMenu {
                    if state.activeForwardHistory.isEmpty {
                        Text("No forward history")
                    } else {
                        ForEach(state.activeForwardHistory.prefix(12), id: \.url) { entry in
                            Button {
                                state.navigateFromHistoryMenu(to: entry.url)
                            } label: {
                                Label(entry.title, systemImage: "arrow.right")
                            }
                        }
                    }
                }
            Button(action: { state.isLoading ? state.stop() : state.reload() }) {
                Image(systemName: state.isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .frame(width: HiveDesign.HitTarget.compact, height: HiveDesign.HitTarget.compact)
                    .symbolEffect(.bounce, value: state.isLoading)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: state.isLoading)
            .accessibilityLabel(state.isLoading ? "Stop loading" : "Reload page")
            .help(state.isLoading ? "Stop (Esc)" : "Reload (⌘R)")
        }
    }

    private func navButton(_ systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                .foregroundStyle(enabled ? HiveDesign.Text.secondary : HiveDesign.Text.tertiary)
                .frame(width: HiveDesign.HitTarget.compact, height: HiveDesign.HitTarget.compact)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "chevron.left" ? "Go back" : "Go forward")
        .help(systemName == "chevron.left" ? "Back (⌘[)" : "Forward (⌘])")
        .disabled(!enabled)
    }

    // MARK: - Group disclosure

    /// Compact horizontal equivalent of the vertical group header. The tab
    /// sequence stays in its existing order; a collapsed group contributes one
    /// disclosure chip and its member pills are omitted until expanded.
    private func horizontalGroupDisclosure(_ group: BrowserState.TabGroup, count: Int) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                state.toggleTabGroup(id: group.id)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                    .font(HiveDesign.Typography.microTinyBold)
                Circle()
                    .fill(group.swiftUIColor)
                    .frame(width: 6, height: 6)
                if group.isCollapsed {
                    Text("\(count)")
                        .font(HiveDesign.Typography.monoMicroMedium)
                }
            }
            .foregroundStyle(group.swiftUIColor)
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(HiveDesign.Surface.level1)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("\(group.name) group — \(group.isCollapsed ? "expand" : "collapse")")
        .accessibilityLabel("\(group.name) group")
        .accessibilityValue(group.isCollapsed ? "Collapsed, \(count) tabs" : "Expanded, \(count) tabs")
        .accessibilityHint("Activate to \(group.isCollapsed ? "expand" : "collapse")")
        .contextMenu {
            TabGroupActionsMenu(group: group)
        }
        .padding(.leading, 2)
        .padding(.trailing, 2)
    }

    // MARK: - New Tab Button

    @State private var newTabPressed: Bool = false

    private var newTabButton: some View {
        Button(action: {
            newTabPressed.toggle()
            state.showFloatingURLBar(opensNewTab: true)
        }) {
            Image(systemName: "plus")
                .font(.system(size: HiveDesign.Typography.sizeSM, weight: .bold))
                .foregroundStyle(HiveDesign.Text.secondary)
                .frame(width: HiveDesign.HitTarget.compact - 4, height: HiveDesign.HitTarget.compact - 4)
                .symbolEffect(.bounce, value: newTabPressed)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New tab")
        .help("New Tab (⌘T)")
        .padding(.leading, 2)
    }

    // MARK: - Right Controls

    private var rightControls: some View {
        HStack(spacing: HiveDesign.Chrome.toolbarIconMargin) {
            if state.isPrivateBrowsing { badge("theatermasks.fill", color: HiveDesign.Text.secondary) }
            if state.isMemorySaverEnabled {
                Button(action: { state.isMemorySaverEnabled.toggle() }) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: HiveDesign.Typography.sizeMD))
                        .foregroundStyle(.green)
                        .frame(width: HiveDesign.HitTarget.compact + 2, height: HiveDesign.HitTarget.compact + 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Memory saver")
                .accessibilityValue("Enabled")
                .help("Memory Saver (leaf)")
            }
            if state.isVoiceModeActive { badge("mic.fill", color: HiveDesign.Accent.primary) }
            if state.canUseWebPageActions {
                iconButton("doc.text.magnifyingglass", active: false) { state.summarizeCurrentPage() }
                iconButton("book", active: state.isReaderMode) { state.toggleReaderMode() }
            }
            Divider().frame(height: 18)
            iconButton("sparkles", active: state.isGeminiPanelOpen) { state.toggleGeminiPanel() }
            iconButton("hexagon.fill", active: state.isKnowledgePanelOpen) { state.toggleKnowledgePanel() }
            iconButton("chevron.left.forwardslash.chevron.right", active: state.isStudioPanelOpen) { state.toggleStudioPanel() }
            iconButton("doc.badge.plus", active: state.isBriefCaptureOpen) { state.toggleBriefCapture() }
            if !state.approvalQueue.pending.isEmpty {
                iconButton("checkmark.shield.fill", active: state.isApprovalPanelOpen) { state.toggleApprovalPanel() }
            }
            // Zoom badge — appears only when the active tab isn't at 100%;
            // click resets (Chrome shows the same affordance in the omnibox).
            if state.canUseWebPageActions && state.activeZoomPercent != 100 {
                Button(action: { state.resetZoom() }) {
                    Text("\(state.activeZoomPercent)%")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(HiveDesign.Surface.level1)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset page zoom")
                .accessibilityValue("Currently \(state.activeZoomPercent) percent")
                .accessibilityHint("Activate to restore 100 percent")
                .help("Zoom \(state.activeZoomPercent)% — click to reset")
            }
            DownloadsStatusView()
            iconButton("paintpalette", active: state.isCustomizePanelOpen) { state.isCustomizePanelOpen.toggle() }
            iconButton("rectangle.lefthalf.inset.filled", active: false) { state.toggleLayout() }
            SyncStatusView()
            Divider().frame(height: 18)
            profileIcon
        }
    }

    private var profileIcon: some View {
        Menu {
            ForEach(state.profiles) { profile in
                Button(action: { state.switchProfile(to: profile.id) }) {
                    HStack {
                        Image(systemName: profile.iconName); Text(profile.name); Spacer()
                        if state.currentProfileID == profile.id { Image(systemName: "checkmark") }
                    }
                }
            }
            Divider()
            ForEach(state.workspacesForCurrentProfile) { workspace in
                Button(action: { state.switchWorkspace(to: workspace.id) }) {
                    HStack {
                        Image(systemName: workspace.iconName); Text(workspace.name); Spacer()
                        if state.currentWorkspaceID == workspace.id { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            if let profile = state.currentProfile {
                Image(systemName: profile.iconName)
                    .font(.system(size: HiveDesign.Typography.sizeMD))
                    .foregroundStyle(profile.swiftUIColor)
                    .frame(width: HiveDesign.HitTarget.compact + 2, height: HiveDesign.HitTarget.compact + 2)
            }
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Profile and workspace menu")
        .help("Profile and workspaces")
    }

    private func iconButton(_ icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: HiveDesign.Icon.small))
                .foregroundStyle(active ? Color.hiveAccent : HiveDesign.Text.secondary)
                .frame(width: HiveDesign.HitTarget.compact + 2, height: HiveDesign.HitTarget.compact + 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(toolbarLabel(for: icon))
        .accessibilityValue(active ? "Open" : "Closed")
        .help(toolbarLabel(for: icon))
    }

    private func toolbarLabel(for icon: String) -> String {
        switch icon {
        case "doc.text.magnifyingglass": return "Summarize page"
        case "book": return "Reader mode"
        case "sparkles": return "Ask Hive"
        case "hexagon.fill": return "Knowledge"
        case "chevron.left.forwardslash.chevron.right": return "Studio"
        case "doc.badge.plus": return "Capture brief"
        case "checkmark.shield.fill": return "Approvals"
        case "arrow.down.circle": return "Downloads"
        case "paintpalette": return "Customize"
        case "rectangle.lefthalf.inset.filled": return "Toggle tab layout"
        default: return "Browser control"
        }
    }

    private func badge(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: HiveDesign.Icon.small))
            .foregroundStyle(color)
            .frame(width: HiveDesign.HitTarget.compact + 2, height: HiveDesign.HitTarget.compact + 2)
    }
}

// MARK: - BookmarksBar

struct BookmarksBar: View {
    @Environment(BrowserState.self) private var state
    /// Root-scope only: folders and content bookmarks at the top level. Items
    /// inside folders are reached by drilling in via the manager (Chrome/Safari
    /// bookmarks-bar behavior).
    private var rootItems: [Bookmark] {
        state.bookmarks.filter { $0.parentID == nil }
    }
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(rootItems) { bookmark in
                    BookmarkButton(bookmark: bookmark)
                }
            }
            .padding(.horizontal, HiveDesign.Space.sm)
            .padding(.vertical, 3)
        }
        .frame(height: 28)
    }
}

struct BookmarkButton: View {
    @Environment(BrowserState.self) private var state
    let bookmark: Bookmark
    @State private var isHovered: Bool = false
    var body: some View {
        // Folders drill into the manager; content bookmarks navigate. A
        // folder has no URL — navigating it would be a blank page.
        Button(action: {
            if bookmark.isFolder {
                state.openBookmarksManager(folderID: bookmark.id)
            } else {
                state.navigateToURL(bookmark.url)
            }
        }) {
            HStack(spacing: 4) {
                if bookmark.isFolder {
                    Image(systemName: "folder.fill")
                        .font(.system(size: HiveDesign.Typography.sizeSM))
                        .foregroundStyle(Color.hiveAccent)
                }
                Text(bookmark.title)
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, HiveDesign.Space.xs)
            .padding(.vertical, 2)
            .background(isHovered ? HiveDesign.Surface.level2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(bookmark.isFolder ? "Open \(bookmark.title) folder" : "Open \(bookmark.title)")
        .accessibilityLabel(bookmark.isFolder ? "\(bookmark.title) folder" : bookmark.title)
        .accessibilityHint(bookmark.isFolder ? "Opens the bookmarks manager in this folder" : "Opens this bookmark")
    }
}

// MARK: - HorizontalEssentialPill

struct HorizontalEssentialPill: View {
    let tab: BrowserState.Tab
    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false
    /// Delayed peek presentation — same Arc hover-preview behavior as full tabs.
    @State private var peekTask: Task<Void, Never>?
    /// The tile's window-space frame — the peek card anchors to it.
    @State private var pillFrame: CGRect = .zero
    private var isActive: Bool { state.activeTabID == tab.id }

    var body: some View {
        Button(action: { state.selectTab(id: tab.id) }) {
            tabIcon.frame(width: 16, height: 16)
                .frame(width: 34, height: 34)
                .scaleEffect(isHovered && !isActive ? 1.08 : 1.0)
                .animation(HiveDesign.Animation.snap, value: isHovered)
                .background(
                    RoundedRectangle(cornerRadius: HiveDesign.Tab.radius, style: .continuous)
                        .fill(isActive ? HiveDesign.Accent.muted : (isHovered ? HiveDesign.Surface.level2 : Color.clear))
                )
        }
        .buttonStyle(.plain)
        .tabPeekAnchor(into: $pillFrame)
        .onHover { hovering in
            isHovered = hovering
            schedulePeek(hovering)
        }
        .onDisappear {
            peekTask?.cancel()
            state.endPeek()
        }
        .contextMenu {
            Button("Close") { state.closeTab(id: tab.id) }
            Button("Reload") { state.reloadTab(id: tab.id) }
            Divider()
            Button("Bookmark All Tabs…") { state.bookmarkAllTabs() }
            Divider()
            if tab.isPinned { Button("Unpin") { state.togglePinTab(id: tab.id) } }
            else { Button("Pin") { state.togglePinTab(id: tab.id) } }
            Divider()
            TabGroupMenuSection(tab: tab)
        }
    }

    /// Shows the peek card after a short hover dwell so the preview doesn't
    /// flash while the cursor sweeps across the essentials row.
    private func schedulePeek(_ hovering: Bool) {
        BrowserState.schedulePeek(
            hovering,
            task: $peekTask,
            tabID: tab.id,
            anchorRect: pillFrame,
            state: state
        )
    }

    @ViewBuilder private var tabIcon: some View {
        if tab.model.isLoading { ProgressView().controlSize(.small).scaleEffect(0.5) }
        else if let favicon = tab.model.faviconURL { FaviconImage(url: favicon) }
        else { Image(systemName: "globe").font(HiveDesign.Typography.panelTitleMedium).foregroundStyle(HiveDesign.Text.tertiary) }
    }
}

// MARK: - HorizontalTabPill

struct HorizontalTabPill: View {
    let tab: BrowserState.Tab
    var indicatorNamespace: Namespace.ID
    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var dropEdge: TabInsertionPlanner.Edge?
    @State private var pillWidth: CGFloat = 100
    /// Delayed peek presentation — prevents card flicker when the cursor
    /// sweeps quickly across the tab strip (Arc hover-preview behavior).
    @State private var peekTask: Task<Void, Never>?
    /// The pill's frame in the window's named coordinate space — the peek card
    /// anchors to it so the preview floats next to the hovered tab.
    @State private var pillFrame: CGRect = .zero
    private var isActive: Bool { state.activeTabID == tab.id }

    private var tabIndex: Int? {
        let all = state.visibleTabs
        guard let idx = all.firstIndex(where: { $0.id == tab.id }), idx < 9 else { return nil }
        return idx + 1
    }

    private var tabBackground: some ShapeStyle {
        if isActive { return AnyShapeStyle(HiveDesign.Surface.level2) }
        if isHovered { return AnyShapeStyle(HiveDesign.Surface.level2) }
        return AnyShapeStyle(Color.clear)
    }

    var body: some View {
        HStack(spacing: 6) {
            tabIcon.frame(width: 14, height: 14)
            Text(displayTitle)
                .font(HiveDesign.Typography.tabTitle)
                .foregroundStyle(isActive ? HiveDesign.Text.primary : HiveDesign.Text.secondary)
                .lineLimit(1)
                .contentTransition(.numericText())
            Spacer(minLength: 2)
            if let idx = tabIndex, !isHovered, !isActive {
                Text("\(Image(systemName: "command")) \(idx)")
                    .font(HiveDesign.Typography.shortcutBadge)
                    .foregroundStyle(HiveDesign.Text.tertiary)
            }
            // Browser-level mute state (CEF SetAudioMuted) takes precedence
            // over the live playing indicator: one interactive speaker button
            // that shows and toggles the tab's real mute.
            if state.isTabMuted(tab.id) || state.mediaPlayingTabIDs.contains(tab.id) {
                Button(action: { state.toggleMuteTab(id: tab.id) }) {
                    Image(systemName: state.isTabMuted(tab.id) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(state.isTabMuted(tab.id) ? HiveDesign.Accent.primary : HiveDesign.Text.secondary)
                        .symbolEffect(.bounce, value: state.isTabMuted(tab.id))
                }
                .buttonStyle(.plain)
                .help(state.isTabMuted(tab.id) ? "Unmute tab" : "Mute tab")
                .accessibilityLabel(state.isTabMuted(tab.id) ? "Unmute tab" : "Mute tab")
            }
            if isHovered || isActive {
                Button(action: { state.closeTab(id: tab.id) }) {
                    Image(systemName: "xmark")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(HiveDesign.Text.tertiary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                        .symbolEffect(.bounce, value: isHovered)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, HiveDesign.Chrome.preTitlePadding)
        .padding(.trailing, HiveDesign.Chrome.postTitlePadding)
        .padding(.vertical, 0)
        .frame(minWidth: 100, maxWidth: 240)
        .frame(height: HiveDesign.Tab.horizontalHeight)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Tab.radius, style: .continuous)
                .fill(tabBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Tab.radius, style: .continuous)
                .fill(isDropTargeted ? HiveDesign.Accent.primary.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Tab.radius, style: .continuous)
                .stroke(
                    isDropTargeted ? HiveDesign.Accent.primary : (isActive ? HiveDesign.Surface.hairline : Color.clear),
                    lineWidth: isDropTargeted ? 2 : 1
                )
        )
        .overlay(alignment: .bottom) {
            // Always render the indicator so matchedGeometryEffect can slide it.
            // When inactive it's invisible; when active it's the amber LED bar.
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(HiveDesign.Accent.primary)
                .frame(width: 28, height: 2)
                .padding(.bottom, 1)
                .opacity(isActive ? 1 : 0)
                .matchedGeometryEffect(id: "activeTabIndicator", in: indicatorNamespace)
        }
        .overlay(alignment: .bottom) {
            if let groupColor = state.tabGroupColor(tab) {
                Rectangle()
                    .fill(groupColor)
                    .frame(height: 2.5)
                    .padding(.horizontal, HiveDesign.Space.sm - 2)
                    .opacity(isActive ? 1.0 : (isHovered ? 0.85 : 0.55))
                    .animation(HiveDesign.Animation.snap, value: isHovered)
            }
        }
        .contentShape(Rectangle())
        // Sleeping tabs remain fully selectable, but recede slightly so the
        // tab strip communicates that their renderer is not resident.
        .opacity(tab.isHibernated ? 0.72 : 1)
        .accessibilityValue(tab.isHibernated ? "Sleeping — select to wake" : (isActive ? "Active" : "Ready"))
        .accessibilityHint(tab.isHibernated ? "Selecting this tab wakes it" : "Select to view")
        .accessibilityAction(named: Text("Select previous visible tab")) {
            state.selectAdjacentVisibleTab(from: tab.id, direction: .previous)
        }
        .accessibilityAction(named: Text("Select next visible tab")) {
            state.selectAdjacentVisibleTab(from: tab.id, direction: .next)
        }
        .tabPeekAnchor(into: $pillFrame)
        .onTapGesture { state.selectTab(id: tab.id) }
        .onDrag { NSItemProvider(object: tab.id as NSString) }
        .overlay(alignment: .leading) {
            if isDropTargeted, dropEdge == .before {
                insertionIndicator
            }
        }
        .overlay(alignment: .trailing) {
            if isDropTargeted, dropEdge == .after {
                insertionIndicator
            }
        }
        .onDrop(of: [.text], delegate: HorizontalTabPillDropDelegate(
            targetID: tab.id,
            state: state,
            insertionEdge: $dropEdge,
            isTargeted: $isDropTargeted,
            pillWidth: pillWidth
        ))
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { pillWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, newWidth in pillWidth = newWidth }
            }
            .allowsHitTesting(false)
        )
        .onHover { hovered in
            isHovered = hovered
            schedulePeek(hovered)
        }
        .onDisappear {
            peekTask?.cancel()
            state.endPeek()
        }
        .contextMenu {
            Button("New Tab") { state.showFloatingURLBar(opensNewTab: true) }
            Divider()
            Button("Ask about this tab") { state.askAboutTab(id: tab.id) }
            Button("Duplicate") { state.duplicateTab(id: tab.id) }
            Button("Rename…") { state.presentTabRename(tab) }
            Button("Reload") { state.reloadTab(id: tab.id) }
            Button(state.isTabMuted(tab.id) ? "Unmute Tab" : "Mute Tab") { state.toggleMuteTab(id: tab.id) }
            Button(state.isSiteMuted(for: tab) ? "Unmute Site" : "Mute Site") { state.toggleSiteMute(for: tab) }
            Divider()
            if tab.id != state.activeTabID {
                if state.splitSecondaryTabID == tab.id {
                    Button("Unsplit") { state.unsplit() }
                } else {
                    Button("Split with Active Tab") { state.splitActiveTab(with: tab.id) }
                }
            }
            Divider()
            if tab.isPinned { Button("Unpin") { state.togglePinTab(id: tab.id) } }
            else { Button("Pin") { state.togglePinTab(id: tab.id) } }
            if !state.groupsForCurrentWorkspace.isEmpty {
                Menu("Move to Group") {
                    if tab.groupID != nil { Button("No Group") { state.moveTabToGroup(tabID: tab.id, groupID: nil) } }
                    ForEach(state.groupsForCurrentWorkspace) { group in
                        Button(group.name) { state.moveTabToGroup(tabID: tab.id, groupID: group.id) }
                    }
                }
            }
            Divider()
            Button("Close Other Tabs") { state.closeOtherTabs(id: tab.id) }
            Button("Close Tabs to Right") { state.closeTabsToRight(id: tab.id) }
            Button("Close", role: .destructive) { state.closeTab(id: tab.id) }
        }
    }

    private var insertionIndicator: some View {
        Capsule(style: .continuous)
            .fill(HiveDesign.Accent.primary)
            .frame(width: 2, height: 26)
            .padding(.vertical, 4)
            .shadow(color: HiveDesign.Accent.primary.opacity(0.35), radius: 2)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var tabIcon: some View {
        if tab.isHibernated { Image(systemName: "moon.zzz.fill").font(.system(size: HiveDesign.Typography.sizeSM)).foregroundStyle(.green) }
        else if tab.model.isLoading { ProgressView().controlSize(.small).scaleEffect(0.5) }
        else if let favicon = tab.model.faviconURL { FaviconImage(url: favicon) }
        else { Image(systemName: "globe").font(HiveDesign.Typography.sidebarItemMedium).foregroundStyle(HiveDesign.Text.tertiary) }
    }

    private var displayTitle: String {
        if let custom = tab.customTitle, !custom.isEmpty {
            return tab.isHibernated ? "\(custom) · sleeping" : custom
        }
        if tab.isHibernated { return "\(tab.model.title.isEmpty ? (tab.savedURL?.host ?? "Tab") : tab.model.title) · sleeping" }
        if !tab.model.title.isEmpty { return tab.model.title }
        if let host = tab.model.url?.host { return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host }
        return "New Tab"
    }

    /// Shows the peek card only after a short hover dwell so the preview
    /// doesn't flash while the cursor sweeps across adjacent tabs.
    private func schedulePeek(_ hovering: Bool) {
        BrowserState.schedulePeek(
            hovering,
            task: $peekTask,
            tabID: tab.id,
            anchorRect: pillFrame,
            state: state
        )
    }
}
