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
    @Environment(ChromiumBrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var horizontalUnpinnedTabs: [ChromiumBrowserState.Tab] {
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
                    HStack(spacing: 0) {
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
                                HorizontalTabPill(tab: tab)
                                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                            }
                        }
                        newTabButton
                    }
                    .padding(.horizontal, 3)
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

                ChromiumAddressBar()
                    .frame(minWidth: 240, idealWidth: 380)

                Spacer(minLength: HiveDesign.Space.sm - 2)

                rightControls
            }                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HiveDesign.Material.toolbar)
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
        HStack(spacing: HiveDesign.Space.xxs) {
            navButton("chevron.left", enabled: state.canGoBack) { state.goBack() }
            navButton("chevron.right", enabled: state.canGoForward) { state.goForward() }
            Button(action: { state.isLoading ? state.stop() : state.reload() }) {
                Image(systemName: state.isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .frame(width: HiveDesign.HitTarget.compact, height: HiveDesign.HitTarget.compact)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.isLoading ? "Stop loading" : "Reload page")
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
        .disabled(!enabled)
    }

    // MARK: - Group disclosure

    /// Compact horizontal equivalent of the vertical group header. The tab
    /// sequence stays in its existing order; a collapsed group contributes one
    /// disclosure chip and its member pills are omitted until expanded.
    private func horizontalGroupDisclosure(_ group: ChromiumBrowserState.TabGroup, count: Int) -> some View {
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

    private var newTabButton: some View {
        Button(action: { state.showFloatingURLBar(opensNewTab: true) }) {
            Image(systemName: "plus")
                .font(.system(size: HiveDesign.Typography.sizeSM, weight: .bold))
                .foregroundStyle(HiveDesign.Text.secondary)
                .frame(width: HiveDesign.HitTarget.compact - 4, height: HiveDesign.HitTarget.compact - 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New tab")
        .padding(.leading, 2)
    }

    // MARK: - Right Controls

    private var rightControls: some View {
        HStack(spacing: HiveDesign.Space.xxs) {
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
            iconButton("arrow.down.circle", active: state.downloads.contains(where: { !$0.isComplete })) { state.isDownloadsPanelOpen = true }
            iconButton("paintpalette", active: state.isCustomizePanelOpen) { state.isCustomizePanelOpen.toggle() }
            iconButton("rectangle.lefthalf.inset.filled", active: false) { state.toggleLayout() }
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
    @Environment(ChromiumBrowserState.self) private var state
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(state.bookmarks) { bookmark in
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
    @Environment(ChromiumBrowserState.self) private var state
    let bookmark: Bookmark
    @State private var isHovered: Bool = false
    var body: some View {
        Button(action: { state.navigateToURL(bookmark.url) }) {
            Text(bookmark.title)
                .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                .foregroundStyle(HiveDesign.Text.secondary)
                .lineLimit(1)
                .padding(.horizontal, HiveDesign.Space.xs)
                .padding(.vertical, 2)
                .background(isHovered ? HiveDesign.Surface.level2 : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xs, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - HorizontalEssentialPill

struct HorizontalEssentialPill: View {
    let tab: ChromiumBrowserState.Tab
    @Environment(ChromiumBrowserState.self) private var state
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
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
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
            if tab.isPinned { Button("Unpin") { state.togglePinTab(id: tab.id) } }
            else { Button("Pin") { state.togglePinTab(id: tab.id) } }
            Divider()
            TabGroupMenuSection(tab: tab)
        }
    }

    /// Shows the peek card after a short hover dwell so the preview doesn't
    /// flash while the cursor sweeps across the essentials row.
    private func schedulePeek(_ hovering: Bool) {
        ChromiumBrowserState.schedulePeek(
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
    let tab: ChromiumBrowserState.Tab
    @Environment(ChromiumBrowserState.self) private var state
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
            Spacer(minLength: 2)
            if let idx = tabIndex, !isHovered, !isActive {
                Text("\(Image(systemName: "command")) \(idx)")
                    .font(HiveDesign.Typography.shortcutBadge)
                    .foregroundStyle(HiveDesign.Text.tertiary)
            }
            // Live playing indicator from the media-state probe — only shows
            // for genuinely playing, unmuted media.
            if state.mediaPlayingTabIDs.contains(tab.id) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(HiveDesign.Typography.microLabel)
                    .foregroundStyle(HiveDesign.Accent.primary)
                    .help("Playing audio")
            }
            if isHovered || isActive {
                Button(action: { state.closeTab(id: tab.id) }) {
                    Image(systemName: "xmark")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(HiveDesign.Text.tertiary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 0)
        .frame(minWidth: 100, maxWidth: 240)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tabBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isDropTargeted ? HiveDesign.Accent.primary.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isDropTargeted ? HiveDesign.Accent.primary : (isActive ? HiveDesign.Surface.hairline : Color.clear),
                    lineWidth: isDropTargeted ? 2 : 1
                )
        )
        .overlay(alignment: .bottom) {
            if isActive {
                // Machined LED indicator: crisp flat amber bar, no glow/shadow.
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(HiveDesign.Accent.primary)
                    .frame(width: 28, height: 2)
                    .padding(.bottom, 1)
            }
        }
        .overlay(alignment: .bottom) {
            if let groupColor = state.tabGroupColor(tab) {
                Rectangle().fill(groupColor).frame(height: 2.5).padding(.horizontal, HiveDesign.Space.sm - 2)
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
            Button("Reload") { state.reloadTab(id: tab.id) }
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
        if tab.isHibernated { return "\(tab.model.title.isEmpty ? (tab.savedURL?.host ?? "Tab") : tab.model.title) · sleeping" }
        if !tab.model.title.isEmpty { return tab.model.title }
        if let host = tab.model.url?.host { return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host }
        return "New Tab"
    }

    /// Shows the peek card only after a short hover dwell so the preview
    /// doesn't flash while the cursor sweeps across adjacent tabs.
    private func schedulePeek(_ hovering: Bool) {
        ChromiumBrowserState.schedulePeek(
            hovering,
            task: $peekTask,
            tabID: tab.id,
            anchorRect: pillFrame,
            state: state
        )
    }
}
