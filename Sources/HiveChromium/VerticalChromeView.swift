import SwiftUI
import HiveCore

// MARK: - VerticalChromeView
//
// Premium vertical browser chrome with Zen/Arc-inspired design.
//   Sidebar background: opaque Hive canvas
//   Tab row height: 34px (Chromium source tree)
//   Tab radius: 8px
//   Close button: 16x16
//   Workspace icons: 28px, grayscale inactive
//   Group headers: colored 6px circle + label
//
// All colors/spacing/typography use HiveDesign tokens.

struct VerticalChromeView: View {
    @Environment(ChromiumBrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sidebarHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Workspace header
            HStack(spacing: HiveDesign.Space.xs) {
                profilePicker
                if let workspace = state.currentWorkspace {
                    HStack(spacing: 5) {
                        Image(systemName: workspace.iconName)
                            .font(.system(size: HiveDesign.Icon.medium, weight: .medium))
                            .foregroundStyle(workspace.swiftUIColor)
                        Text(workspace.name)
                            .font(.system(size: HiveDesign.Typography.sizeLG, weight: .semibold))
                            .foregroundStyle(HiveDesign.Text.primary)
                    }
                    .contextMenu {
                        Button("New Workspace") { _ = state.addWorkspace(name: "New Workspace", colorHex: "#F5A623", iconName: "circle.fill") }
                        Divider()
                        ForEach(state.workspacesForCurrentProfile) { ws in
                            Button { state.switchWorkspace(to: ws.id) } label: {
                                HStack {
                                    Image(systemName: ws.iconName); Text(ws.name); Spacer()
                                    if ws.id == state.currentWorkspaceID { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                }
                Spacer()
                Button(action: { state.showFloatingURLBar(opensNewTab: true) }) {
                    Image(systemName: "plus")
                        .font(.system(size: HiveDesign.Icon.medium, weight: .semibold))
                        .foregroundStyle(HiveDesign.Text.secondary)
                        .frame(width: HiveDesign.HitTarget.compact + 2, height: HiveDesign.HitTarget.compact + 2)
                        .background(sidebarHovered ? HiveDesign.Surface.level2 : HiveDesign.Surface.level1)
                        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New tab")
            }
            .padding(.horizontal, HiveDesign.Space.xs)
            .padding(.top, HiveDesign.Space.sm - 2)
            .padding(.bottom, 6)

            // Separator
            Rectangle()
                .fill(HiveDesign.Surface.hairline)
                .frame(height: 1)
                .padding(.horizontal, HiveDesign.Space.sm)
                .padding(.vertical, HiveDesign.Space.xxs)

            // Essentials grid
            if !state.iconTabs.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 42, maximum: 42))], spacing: HiveDesign.Space.xxs) {
                    ForEach(state.iconTabs) { tab in
                        VerticalEssentialTile(tab: tab)
                    }
                }
                .padding(.horizontal, HiveDesign.Space.xs)
                .padding(.vertical, 6)

                Rectangle()
                    .fill(HiveDesign.Surface.hairline)
                    .frame(height: 1)
                    .padding(.horizontal, HiveDesign.Space.sm)
            }

            // Tab list
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(state.groupsForCurrentWorkspace) { group in
                        let tabsInGroup = state.unpinnedTabs.filter { $0.groupID == group.id }
                        if !tabsInGroup.isEmpty {
                            Button {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                                    state.toggleTabGroup(id: group.id)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                                        .font(HiveDesign.Typography.microTinyBold)
                                        .frame(width: 10)
                                    Circle().fill(group.swiftUIColor).frame(width: 6, height: 6)
                                    Text(group.name)
                                        .font(HiveDesign.Typography.caption)
                                        .foregroundStyle(group.swiftUIColor)
                                    if group.isCollapsed {
                                        Text("\(tabsInGroup.count)")
                                            .font(HiveDesign.Typography.monoMicroMedium)
                                            .foregroundStyle(HiveDesign.Text.tertiary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(group.name) group")
                            .accessibilityValue(group.isCollapsed ? "Collapsed, \(tabsInGroup.count) tabs" : "Expanded, \(tabsInGroup.count) tabs")
                            .accessibilityHint("Activate to \(group.isCollapsed ? "expand" : "collapse")")
                            .contextMenu {
                                TabGroupActionsMenu(group: group)
                            }
                            .padding(.horizontal, HiveDesign.Space.sm - 2)
                            .padding(.top, HiveDesign.Space.sm - 2)
                            .padding(.bottom, 2)
                            if !group.isCollapsed {
                                ForEach(tabsInGroup) { tab in
                                    VerticalTabRow(tab: tab)
                                        .padding(.vertical, 2)
                                        .transition(reduceMotion ? .identity : .asymmetric(insertion: .opacity.combined(with: .move(edge: .leading)), removal: .opacity.combined(with: .move(edge: .leading))))
                                }
                            }
                        }
                    }
                    let ungrouped = state.unpinnedTabs.filter { $0.groupID == nil }
                    if !ungrouped.isEmpty {
                        if !state.groupsForCurrentWorkspace.isEmpty {
                            HStack(spacing: 6) {
                                Circle().fill(HiveDesign.Text.tertiary).frame(width: 6, height: 6)
                                Text("Tabs")
                                    .font(HiveDesign.Typography.caption)
                                    .foregroundStyle(HiveDesign.Text.tertiary)
                                Spacer()
                            }
                            .padding(.horizontal, HiveDesign.Space.sm - 2)
                            .padding(.top, HiveDesign.Space.sm - 2)
                            .padding(.bottom, 2)
                        }
                        ForEach(ungrouped) { tab in
                            VerticalTabRow(tab: tab)
                                .padding(.vertical, 2)
                                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .leading)), removal: .opacity.combined(with: .move(edge: .leading))))
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }

            Spacer()

            // Workspace divider
            Rectangle()
                .fill(HiveDesign.Surface.hairline)
                .frame(height: 1)
                .padding(.horizontal, HiveDesign.Space.sm)

            // Workspace switcher — Arc-parity circular gradient badges.
            // Each workspace renders a 28px badge in its accent color (gradient
            // from full color to a dimmed variant, top-leading to bottom-trailing).
            // Active: 2px white ring + soft glow + slight scale-up (Arc: 24-28px
            // badge, active = subtle white stroke). Inactive: desaturated + dimmed.
            HStack(spacing: 8) {
                ForEach(state.workspacesForCurrentProfile) { workspace in
                    let isActive = state.currentWorkspaceID == workspace.id
                    Button(action: { state.switchWorkspace(to: workspace.id) }) {
                        ZStack {
                            Circle()
                                .fill(
                                    workspace.swiftUIColor
                                )
                                .shadow(color: isActive ? workspace.swiftUIColor.opacity(0.24) : .clear, radius: 4, x: 0, y: 1)
                            Image(systemName: workspace.iconName)
                                .font(HiveDesign.Typography.bodySemiBold)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                        }
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(
                                    isActive ? Color.white.opacity(0.9) : Color.white.opacity(0.12),
                                    lineWidth: isActive ? 2 : 1
                                )
                        )
                        .frame(width: HiveDesign.HitTarget.standard, height: HiveDesign.HitTarget.standard)
                        .contentShape(Circle())
                        .saturation(isActive ? 1.0 : 0.55)
                        .opacity(isActive ? 1.0 : 0.75)
                        .scaleEffect(isActive ? 1.08 : 1.0)
                        .animation(reduceMotion ? nil : HiveDesign.Animation.spring, value: isActive)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(workspace.name)
                    .accessibilityValue(isActive ? "Current workspace" : "Switch workspace")
                    .help(workspace.name)
                }
            }
            .padding(.horizontal, HiveDesign.Space.sm - 2)
            .padding(.vertical, HiveDesign.Space.xs)

            // Bottom bar
            HStack(spacing: HiveDesign.Space.sm) {
                Button(action: { state.openCommandPalette() }) {
                    Image(systemName: "command")
                        .font(.system(size: HiveDesign.Typography.sizeLG, weight: .medium))
                        .foregroundStyle(HiveDesign.Text.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open command palette")
                Spacer()
                if state.isVoiceModeActive {
                    Image(systemName: "mic.fill").font(.system(size: HiveDesign.Typography.sizeSM)).foregroundStyle(HiveDesign.Accent.primary)
                }
                if state.isPrivateBrowsing {
                    Image(systemName: "theatermasks.fill").font(.system(size: HiveDesign.Typography.sizeSM)).foregroundStyle(HiveDesign.Text.tertiary)
                }
                Button(action: { state.toggleLayout() }) {
                    Image(systemName: "rectangle.topthird.inset.filled")
                        .font(.system(size: HiveDesign.Typography.sizeLG, weight: .medium)).foregroundStyle(HiveDesign.Text.secondary)                }
                .buttonStyle(.plain)
                .accessibilityLabel("Switch to horizontal tabs")
                .help("Horizontal tabs")
            }
            .padding(.horizontal, HiveDesign.Space.sm)
            .padding(.vertical, HiveDesign.Space.sm - 2)
        }
        .frame(maxWidth: .infinity)
        .background(HiveDesign.Material.sidebar)
        .onHover { sidebarHovered = $0 }
    }

    private var profilePicker: some View {
        Menu {
            ForEach(state.profiles) { profile in
                Button(action: { state.switchProfile(to: profile.id) }) {
                    HStack {
                        Image(systemName: profile.iconName); Text(profile.name); Spacer()
                        if state.currentProfileID == profile.id { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            if let profile = state.currentProfile {
                Label(profile.name, systemImage: profile.iconName)
                    .font(.system(size: HiveDesign.Typography.sizeLG, weight: .bold))
                    .foregroundStyle(HiveDesign.Text.primary)
            }
        }
        .menuStyle(.borderlessButton)
    }
}

// MARK: - VerticalEssentialTile

struct VerticalEssentialTile: View {
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
            tabIcon.frame(width: 18, height: 18)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                        .fill(isActive ? HiveDesign.Surface.level2 : (isHovered ? HiveDesign.Surface.level1 : Color.clear))
                )
                .overlay(alignment: .leading) {
                    if isActive {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(HiveDesign.Accent.primary)
                            .frame(width: 3, height: 20)
                    }
                }
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
        }
    }

    /// Shows the peek card after a short hover dwell so the preview doesn't
    /// flash while the cursor sweeps across the essentials grid.
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
        if tab.model.isLoading { ProgressView().controlSize(.small).scaleEffect(0.65) }
        else if let favicon = tab.model.faviconURL { FaviconImage(url: favicon) }
        else { Image(systemName: "globe").font(HiveDesign.Typography.panelTitleMedium).foregroundStyle(HiveDesign.Text.tertiary) }
    }
}

// MARK: - VerticalTabRow

struct VerticalTabRow: View {
    let tab: ChromiumBrowserState.Tab
    @Environment(ChromiumBrowserState.self) private var state
    @State private var isHovered: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var dropEdge: TabInsertionPlanner.Edge?
    /// Delayed peek presentation — prevents card flicker when the cursor
    /// sweeps quickly across the tab list (Arc hover-preview behavior).
    @State private var peekTask: Task<Void, Never>?
    /// The row's frame in the window's named coordinate space — the peek card
    /// anchors to it so the preview floats next to the hovered tab.
    @State private var pillFrame: CGRect = .zero
    private var isActive: Bool { state.activeTabID == tab.id }

    private var tabIndex: Int? {
        let all = state.visibleTabs
        guard let idx = all.firstIndex(where: { $0.id == tab.id }), idx < 9 else { return nil }
        return idx + 1
    }

    var body: some View {
        HStack(spacing: 8) {
            tabIcon.frame(width: 16, height: 16)

            Text(displayTitle)
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(isActive ? HiveDesign.Text.primary : HiveDesign.Text.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            if let idx = tabIndex, !isHovered, !isActive {
                Text("\(Image(systemName: "command")) \(idx)")
                    .font(HiveDesign.Typography.shortcutBadge)
                    .foregroundStyle(HiveDesign.Text.tertiary)
            }

            if tab.model.isLoading {
                ProgressView().controlSize(.small).scaleEffect(0.5)
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
                        .frame(width: 16, height: 16).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous)
                .fill(isActive ? HiveDesign.Accent.muted : (isHovered ? HiveDesign.Surface.level2 : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous)
                .stroke(
                    isActive ? HiveDesign.Accent.primary.opacity(0.25) : Color.clear,
                    lineWidth: 1
                )
        )
        .overlay(alignment: .top) {
            if isDropTargeted && dropEdge == .before {
                insertionIndicator
            }
        }
        .overlay(alignment: .bottom) {
            if isDropTargeted && dropEdge == .after {
                insertionIndicator
            }
        }
        .overlay(alignment: .leading) {
            if let groupColor = state.tabGroupColor(tab) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(groupColor)
                    .frame(width: 3)
                    .padding(.vertical, 6)
                    .padding(.leading, 2)
            }
        }
        .contentShape(Rectangle())
        // Sleeping tabs remain fully selectable, but recede slightly so the
        // tab rail communicates that their renderer is not resident.
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
        .accessibilityAction(named: Text("Move tab up")) {
            moveByKeyboard(direction: -1)
        }
        .accessibilityAction(named: Text("Move tab down")) {
            moveByKeyboard(direction: 1)
        }
        .onDrag { NSItemProvider(object: tab.id as NSString) }
        .onDrop(of: [.text], delegate: VerticalTabRowDropDelegate(
            targetID: tab.id,
            state: state,
            insertionEdge: $dropEdge,
            isTargeted: $isDropTargeted
        ))
        .onHover { hovered in
            isHovered = hovered
            schedulePeek(hovered)
        }
        .onDisappear {
            peekTask?.cancel()
            state.endPeek()
        }
        .contextMenu {
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
            Divider()
            TabGroupMenuSection(tab: tab)
            Divider()
            Button("Move Tab Up") { moveByKeyboard(direction: -1) }
                .disabled(!canMoveByKeyboard(direction: -1))
            Button("Move Tab Down") { moveByKeyboard(direction: 1) }
                .disabled(!canMoveByKeyboard(direction: 1))
            Divider()
            Button("Close Other Tabs") { state.closeOtherTabs(id: tab.id) }
            Button("Close Tabs to Right") { state.closeTabsToRight(id: tab.id) }
            Button("Close", role: .destructive) { state.closeTab(id: tab.id) }
        }
    }

    /// Returns the reorderable projection for this row. It mirrors the state
    /// boundary used by `reorderTab`: current workspace, pinned/essential
    /// class, and group membership all stay fixed during a reorder.
    private var reorderableSiblings: [ChromiumBrowserState.Tab] {
        state.tabs.filter {
            $0.workspaceID == tab.workspaceID &&
            $0.isPinned == tab.isPinned &&
            $0.isEssential == tab.isEssential &&
            $0.groupID == tab.groupID
        }
    }

    private func canMoveByKeyboard(direction: Int) -> Bool {
        guard let index = reorderableSiblings.firstIndex(where: { $0.id == tab.id }) else { return false }
        return reorderableSiblings.indices.contains(index + direction)
    }

    /// Keyboard/VoiceOver equivalent of dragging a row. It invokes the exact
    /// same stable-ID contract as pointer drops, so accessibility cannot cross
    /// workspace, group, or pinned boundaries by taking a different path.
    private func moveByKeyboard(direction: Int) {
        guard let index = reorderableSiblings.firstIndex(where: { $0.id == tab.id }),
              reorderableSiblings.indices.contains(index + direction) else { return }
        let destination = reorderableSiblings[index + direction]
        let edge: TabInsertionPlanner.Edge = direction < 0 ? .before : .after
        _ = state.reorderTab(movingID: tab.id, targetID: destination.id, edge: edge)
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

    @ViewBuilder private var tabIcon: some View {
        if tab.isHibernated { Image(systemName: "moon.zzz.fill").font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium)).foregroundStyle(.green) }
        else if tab.model.isLoading { ProgressView().controlSize(.small).scaleEffect(0.6) }
        else if let favicon = tab.model.faviconURL { FaviconImage(url: favicon) }
        else { Image(systemName: "globe").font(HiveDesign.Typography.sidebarItemMedium).foregroundStyle(HiveDesign.Text.tertiary) }
    }

    private var insertionIndicator: some View {
        Capsule(style: .continuous)
            .fill(HiveDesign.Accent.primary)
            .frame(height: 2)
            .padding(.horizontal, 4)
            .shadow(color: HiveDesign.Accent.primary.opacity(0.35), radius: 2)
            .accessibilityHidden(true)
    }

    private var displayTitle: String {
        if tab.isHibernated { return "\(tab.model.title.isEmpty ? (tab.savedURL?.host ?? "Tab") : tab.model.title) · sleeping" }
        if !tab.model.title.isEmpty { return tab.model.title }
        if let host = tab.model.url?.host { return host }
        return "New Tab"
    }
}
