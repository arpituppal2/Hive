import SwiftUI
import AppKit
import HiveCore

// MARK: - VerticalTabBarView
//
// The vertical tab bar (SPEC §8.2). Collapsed = 48pt favicon rail (favicon 20×20 centered,
// 32pt rows, surface@50% on hover, title tooltip after 500ms). Expanded = 240pt with
// favicon + truncated title + close-on-hover. Hovering the collapsed bar expands it with the
// `expand` spring (0.45s); the mouse leaving the expanded bar waits 300ms then collapses
// with the `collapse` spring (0.30s). When the sidebar is open the bar stays expanded (the
// sidebar IS the expanded state). Spaces are listed at the bottom (Arc/Zen model), divided.
//
// Animation is first-class here (owner directive). The width animation uses the expand /
// collapse spring presets; reduce-motion collapses both to the 0.12s linear fallback.
//
// Hive signature animation approach for the vertical rail:
//   - Expand: 0.45s spring (response: 0.45, damping: 0.78). The bar slides out with a
//     slight overshoot that settles immediately — feels alive, not robotic.
//   - Collapse: 0.30s spring (response: 0.30, damping: 0.88). Faster than expand so the
//     user never waits for the chrome to get out of the way.
//   - Tab hover: row background fades at 120ms — quick, responsive, no delay.
//   - Tab close: the removed row shrinks + fades with a 200ms ease-out.
//   - Space switching: space icon pulses briefly on tap (scale 0.92→1).
//
// Stagger intro: when the bar first appears, each tab row fades in with a 20ms stagger
// (capped at 200ms) so the list feels like it's cascading into place.

struct VerticalTabBarView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isExpanded = false
    @State private var collapseWorkItem: DispatchWorkItem?
    @State private var hoveredTabID: String?
    @State private var hoveringNewTabRow = false
    @State private var draggedTabID: String?
    @State private var dropTargetRowID: String?

    /// Tab awaiting a custom-promise text entry via the context-menu "Promise: Custom…"
    /// action. Stale values are benign — the next "Custom…" press overwrites the id
    /// before presenting, and `Set` is guarded by `if let`.
    @State private var customPromiseTabID: String?
    @State private var customPromiseText = ""
    @State private var isShowingCustomPromise = false

    /// Group awaiting a rename-via-alert from the group context-menu "Rename Group…"
    /// action. The `.alert(item:)` attaches to `newTabRow` (a distinct sub-view), not
    /// the body-level promise `.alert(isPresented:)` — SwiftUI presents only one
    /// `isPresented:` alert per view tree, so a second on the same body would never
    /// fire. An `item:`-driven alert on a different concrete sub-view sidesteps that.
    @State private var renameGroupTarget: TabGroup?
    @State private var renameGroupText = ""

    private var collapsedWidth: CGFloat { HiveDimension.verticalCollapsedW }
    private var expandedWidth: CGFloat { HiveDimension.verticalExpandedW }
    private var rowHeight: CGFloat { HiveDimension.verticalTabRowH }

    var body: some View {
        VStack(spacing: 0) {
            if isExpandedOrSidebarOpen {
                searchField
                    .padding(.horizontal, HiveSpacing.s8)
                    .padding(.top, HiveSpacing.s4)
            }
            tabList
            Spacer(minLength: 0)
            archivedShelf
            spaceRail
            newTabRow
        }
        .frame(width: currentWidth)
        .frame(maxHeight: .infinity)
        .hiveSurface(.passiveChrome)
        .background(ExpansionHoverTarget(
            isExpanded: $isExpanded,
            cancelCollapse: cancelCollapse,
            expand: expand,
            scheduleCollapse: scheduleCollapse,
            sidebarOpen: state.prefs.sidebarOpen
        ))
        .animation(widthAnimation, value: currentWidth)
        .animation(hoverAnim, value: isExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Vertical tabs")
        .alert("Custom Promise", isPresented: $isShowingCustomPromise) {
            TextField("Promise text", text: $customPromiseText)
            Button("Cancel", role: .cancel) {
                customPromiseTabID = nil
                customPromiseText = ""
            }
            Button("Set") {
                if let id = customPromiseTabID {
                    state.setPromise(id, promise: customPromiseText)
                }
                customPromiseTabID = nil
                customPromiseText = ""
            }
            .disabled(customPromiseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Tag this tab with a short promise badge — shown on the tab and searchable in Tab Overview.")
        }
    }

    private var currentWidth: CGFloat {
        (isExpanded || state.prefs.sidebarOpen) ? expandedWidth : collapsedWidth
    }

    private var widthAnimation: Animation {
        reduceMotion ? .linear(duration: 0.12) : .hiveExpand
    }

    private var hoverAnim: Animation {
        reduceMotion ? .linear(duration: 0.12) : .easeOut(duration: 0.15)  // Zen verbatim: 150ms
    }

    private var tabTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.95, anchor: .leading)),
            removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .leading))
        )
    }

    // MARK: Tab list
    //
    // Renders: pinned tabs, then each group as a collapsible section, then ungrouped tabs.
    // Group membership is exclusive; pinned tabs are evicted from groups and live at the top.
    // Drag & drop (SPEC §16): onDrag/onDrop for tab reordering with ghost placeholder,
    // spring settle animation, and cross-window support via NSItemProvider.

    // MARK: Tab search field (visible when expanded)

    @State private var tabSearchQuery = ""

    /// Filters tabs by title or URL. Only active when the search query is non-empty.
    private var filteredTabIDs: Set<String>? {
        let q = tabSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty, q.count >= 2 else { return nil }
        return Set(state.visibleTabs.filter { tab in
            tab.displayTitle.lowercased().contains(q) ||
            tab.url?.absoluteString.lowercased().contains(q) ?? false
        }.map { $0.id })
    }

    private var tabList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                // Pinned rail (top, favicon-only rows).
                ForEach(Array(state.ungroupedTabs.filter { $0.isPinned }.enumerated()), id: \.element.id) { _, tab in
                    verticalRow(tab)
                        .transition(tabTransition)
                        .animation(hoverAnim, value: state.previewTabID)
                        .onDrag {
                            draggedTabID = tab.id
                            dropTargetRowID = nil
                            let provider = NSItemProvider(object: tab.id as NSString)
                            if let url = tab.url {
                                provider.registerObject(url as NSURL, visibility: .all)
                            }
                            return provider
                        }
                }

                // Groups: header + unfolded tabs.
                ForEach(state.visibleGroups) { group in
                    groupSection(group)
                }

                // Ungrouped, unpinned tabs. Filter by search query when active.
                let unpinnedTabs = state.ungroupedTabs.filter { !$0.isPinned }
                let filteredUnpinned = filterBySearch(unpinnedTabs)
                ForEach(Array(filteredUnpinned.enumerated()), id: \.element.id) { idx, tab in
                    // Zen/Arc-class same-window reorder: dragging an unpinned tab onto
                    // another unpinned tab moves it to that index, with a 2pt accent
                    // insertion line on the target row. While a search filter is active
                    // the enumerated index no longer maps to the model order, so per-row
                    // drops are disabled (the container receiver still handles
                    // cross-window + external URL drops).
                    let row = verticalRow(tab)
                        .transition(tabTransition)
                        .animation(hoverAnim, value: state.previewTabID)
                        .overlay(alignment: .top) {
                            if dropTargetRowID == tab.id {
                                Rectangle()
                                    .fill(state.activeAccentColor)
                                    .frame(height: 2)
                                    .transition(.opacity)
                            }
                        }
                        .onDrag {
                            draggedTabID = tab.id
                            dropTargetRowID = nil
                            let provider = NSItemProvider(object: tab.id as NSString)
                            if let url = tab.url {
                                provider.registerObject(url as NSURL, visibility: .all)
                            }
                            return provider
                        }
                    if filteredTabIDs == nil {
                        row.onDrop(of: [.text], delegate: VerticalRowDropReceiver(
                            targetIndex: idx,
                            draggedTabID: $draggedTabID,
                            dropTargetRowID: $dropTargetRowID,
                            rowID: tab.id,
                            state: state
                        ))
                    } else {
                        row
                    }
                }
            }
            .padding(.vertical, HiveSpacing.s4)
            .onDrop(of: [.text], delegate: VerticalTabDropReceiver(
                tabIDs: state.ungroupedTabs.filter { !$0.isPinned }.map { $0.id },
                state: state
            ))
        }
        .animation(.hiveMicro, value: state.tabs.count)  // animate tab add/remove
    }

    @ViewBuilder
    private func verticalRow(_ tab: BrowserTab) -> some View {
        let hovered = hoveredTabID == tab.id
        let depth = tabDepth(for: tab)
        let hasChildren = state.hasTreeChildren(tab.id)
        HStack(spacing: HiveSpacing.s8) {
            if state.prefs.isTreeMode && isExpandedOrSidebarOpen {
                disclosureChevron(for: tab, hasChildren: hasChildren)
                    .frame(width: HiveSpacing.s16)
            }
            faviconFor(tab)
        if isExpandedOrSidebarOpen {
            titleFor(tab)
            if tab.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
            if tab.isPlayingAudio || tab.isMuted {
                Button {
                    state.toggleMute(tab.id)
                } label: {
                    Image(systemName: tab.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(HiveTypography.font(.microMedium))
                        .foregroundStyle(tab.isMuted ? .hiveGraphite : state.activeAccentColor)
                        .padding(2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.isMuted ? "Unmute tab" : "Mute tab")
            }
            Spacer(minLength: 0)
            if hovered || tab.isActive {
                closeFor(tab)
            }
        }
        }
        .padding(.leading, leadingPadding(for: tab, depth: depth))
        .padding(.trailing, isExpandedOrSidebarOpen ? HiveSpacing.s4 : 0)
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity)
        .background(rowBackground(tab: tab, hovered: hovered))
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
        .contentShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
        .onHover { hoveredTabID = $0 ? tab.id : (hoveredTabID == tab.id ? nil : hoveredTabID) }
        .onTapGesture { state.selectTab(tab.id) }
        .contextMenu { contextMenu(for: tab) }
        .help(isExpandedOrSidebarOpen ? Text("") : Text(tab.displayTitle))  // collapsed → tooltip (SwiftUI .help)
        .tabHoverPreview(for: tab)
        .id(tab.id)
    }

    private var isExpandedOrSidebarOpen: Bool { isExpanded || state.prefs.sidebarOpen }

    /// Left padding for a vertical tab row. In tree mode, children indent 12pt per depth.
    private func leadingPadding(for tab: BrowserTab, depth: Int) -> CGFloat {
        if !isExpandedOrSidebarOpen { return 0 }
        let treeIndent = state.prefs.isTreeMode ? CGFloat(depth) * 12.0 : 0
        return HiveSpacing.s8 + treeIndent
    }

    /// Tree depth of a tab (0 for root, 1 for child, etc.). Always 0 when not in tree mode.
    private func tabDepth(for tab: BrowserTab) -> Int {
        guard state.prefs.isTreeMode else { return 0 }
        var depth = 0
        var current = tab.parentTabID
        while let pid = current, state.tabs.first(where: { $0.id == pid }) != nil {
            depth += 1
            current = state.tabs.first { $0.id == pid }?.parentTabID
        }
        return depth
    }

    // MARK: Group section

    @ViewBuilder
    private func groupSection(_ group: TabGroup) -> some View {
        VStack(spacing: 0) {
            groupHeader(group)
            if !group.isFolded {
                ForEach(state.tabs(in: group)) { tab in
                    verticalRow(tab)
                        .padding(.leading, isExpandedOrSidebarOpen ? HiveSpacing.s12 : 0)
                }
            }
        }
    }

    @ViewBuilder
    private func groupHeader(_ group: TabGroup) -> some View {
        let token = HiveColorToken(rawValue: group.colorDot) ?? .accent
        let collapsed = group.isFolded
        HStack(spacing: HiveSpacing.s8) {
            if state.prefs.isTreeMode && isExpandedOrSidebarOpen {
                // Reserve the same width as the tree disclosure chevron so headers align.
                Color.clear.frame(width: HiveSpacing.s16, height: 1)
            }
            Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                .font(HiveTypography.font(.microTinyMedium))
                .foregroundStyle(.hiveGraphite)
            Circle()
                .fill(Color(token))
                .frame(width: 8, height: 8)
            if isExpandedOrSidebarOpen {
                Text(group.name)
                    .hiveType(.chromeTitle)
                    .foregroundStyle(.hiveInk)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(group.tabIDs.count)")
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveGraphite)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, isExpandedOrSidebarOpen ? HiveSpacing.s8 : 0)
        .padding(.trailing, isExpandedOrSidebarOpen ? HiveSpacing.s4 : 0)
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity)
        .background(rowBackground(tab: nil, hovered: false))
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
        .contentShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
        .onTapGesture { state.toggleGroupFold(group.id) }
        .contextMenu { groupContextMenu(for: group) }
        .help(isExpandedOrSidebarOpen ? Text("") : Text(group.name))
    }

    @ViewBuilder
    private func disclosureChevron(for tab: BrowserTab, hasChildren: Bool) -> some View {
        if hasChildren {
            let collapsed = state.prefs.treeCollapsedParentIDs.contains(tab.id)
            Button {
                state.toggleTreeFold(tab.id)
            } label: {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(HiveTypography.font(.microTinyMedium))
                    .foregroundStyle(.hiveGraphite)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func faviconFor(_ tab: BrowserTab) -> some View {
        Group {
            if let url = tab.faviconURL {
                FaviconView(url: url)
                    .frame(width: isExpandedOrSidebarOpen
                           ? HiveDimension.favicon
                           : HiveDimension.faviconVertical,
                           height: isExpandedOrSidebarOpen
                           ? HiveDimension.favicon
                           : HiveDimension.faviconVertical)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: isExpandedOrSidebarOpen ? 11 : 14, weight: .regular))
                    .foregroundStyle(tab.isActive ? Color.hiveInk : Color.hiveGraphite)
                    .frame(width: HiveDimension.faviconVertical,
                           height: HiveDimension.faviconVertical)
            }
        }
        .frame(width: isExpandedOrSidebarOpen ? HiveDimension.favicon : HiveDimension.tabPillPinnedW)
    }

    private func titleFor(_ tab: BrowserTab) -> some View {
        HStack(spacing: HiveSpacing.s4) {
            Text(tab.displayTitle)
                .hiveType(.chromeTitle)
                .foregroundStyle(tab.isActive ? Color.hiveInk : Color.hiveGraphite)
                .lineLimit(1)
                .truncationMode(.tail)
            if let promise = tab.promise, !promise.isEmpty, isExpandedOrSidebarOpen {
                promiseBadge(promise, color: tab.promiseColor, isActive: tab.isActive)
            }
        }
    }

    /// Promise badge (slice 8): a small colored pill next to the tab title.
    private func promiseBadge(_ text: String, color: String?, isActive: Bool) -> some View {
        let token = HiveColorToken(rawValue: color ?? "accent") ?? .accent
        let tokenColor = Color(token)
        return HStack(spacing: 2) {
            Circle()
                .fill(tokenColor)
                .frame(width: 6, height: 6)
            Text(text)
                .hiveType(.chromeLabel)
                .foregroundStyle(isActive ? Color.hiveInk : Color.hiveGraphite)
                .lineLimit(1)
        }
        .padding(.horizontal, 3)
        .frame(height: 14)
        .background(tokenColor.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityLabel("Promise: \(text)")
    }

    private func closeFor(_ tab: BrowserTab) -> some View {
        Button {
            state.closeTab(tab.id)
        } label: {
            Image(systemName: "xmark")
                .font(HiveTypography.font(.microBold))
                .foregroundStyle(.hiveGraphite)
                .frame(width: HiveDimension.closeButtonHit, height: HiveDimension.closeButtonHit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close tab")
        .transition(.opacity)
    }

    /// Zen/Arc-verbatim row height — 34px unified (aligned via HiveDimension.verticalTabRowH).
    /// Active tab gets a distinct pill background; hovered gets a subtle wash at 150ms.
    private func rowBackground(tab: BrowserTab?, hovered: Bool) -> some View {
        Group {
            if let tab = tab, tab.isActive {
                Color.hiveSurface.opacity(0.85)
            } else if hovered {
                Color.hiveSurface.opacity(0.45)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func groupContextMenu(for group: TabGroup) -> some View {
        Button(group.isFolded ? "Unfold Group" : "Fold Group") {
            state.toggleGroupFold(group.id)
        }
        Button("Rename Group…") {
            renameGroupTarget = group
            renameGroupText = group.name
        }
        Divider()
        Button("Ungroup Tabs") { state.deleteGroup(group.id) }
        Button("Close Group Tabs", role: .destructive) {
            let ids = group.tabIDs
            state.deleteGroup(group.id)
            for id in ids { state.closeTab(id) }
        }
    }

    @ViewBuilder
    private func contextMenu(for tab: BrowserTab) -> some View {
        Button("Close Tab") { state.closeTab(tab.id) }
        Button("Close Other Tabs") { state.closeOtherTabs(keeping: tab.id) }
        Button("Close Tabs to the Right") { state.closeTabsToRight(of: tab.id) }
        Divider()
        Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") { state.togglePin(tab.id) }
        Button(tab.isMuted ? "Unmute Site" : "Mute Site") { state.toggleMute(tab.id) }
        Divider()
        Button(tab.isReaderMode ? "Exit Reader Mode" : "Enter Reader Mode") { state.toggleReaderMode(for: tab.id) }
        Divider()
        Button("Duplicate Tab") { state.duplicateTab(tab.id) }
        Divider()
        Button("Copy URL") {
            if let url = tab.url { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.absoluteString, forType: .string) }
        }
        Divider()
        Button(state.prefs.isTreeMode ? "Disable Tree Mode" : "Enable Tree Mode") {
            state.toggleTreeMode()
        }
        if state.prefs.isTreeMode {
            Button("New Child Tab") { state.newChildTab(parentID: tab.id) }
            if state.hasTreeChildren(tab.id) {
                Button(state.prefs.treeCollapsedParentIDs.contains(tab.id)
                       ? "Expand Children" : "Collapse Children") {
                    state.toggleTreeFold(tab.id)
                }
            }
        }
        Divider()
        groupMenu(for: tab)
        promiseMenu(for: tab)
    }

    @ViewBuilder
    private func groupMenu(for tab: BrowserTab) -> some View {
        if state.groupContaining(tab.id) != nil {
            Button("Remove from Group") { state.removeTabFromGroup(tab.id) }
        } else {
            Menu("Add to Group") {
                Button("New Group…") {
                    state.createGroup(name: "New Group", in: state.activeSpace.id, tabIDs: [tab.id])
                }
                if !state.visibleGroups.isEmpty {
                    Divider()
                    ForEach(state.visibleGroups) { group in
                        Button(group.name) {
                            state.addTabToGroup(tab.id, groupID: group.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func promiseMenu(for tab: BrowserTab) -> some View {
        if let promise = tab.promise, !promise.isEmpty {
            Button("Promise: \(promise)") {}
                .disabled(true)
            Button("Clear Promise") { state.clearPromise(tab.id) }
        } else {
            Button("Promise: Read Later") { state.setPromise(tab.id, promise: "read later") }
            Button("Promise: Custom…") {
                customPromiseTabID = tab.id
                customPromiseText = ""
                isShowingCustomPromise = true
            }
        }
        Divider()
        if let url = tab.url {
            Button {
                state.addToReadingList(url: url, title: tab.displayTitle, faviconURL: tab.faviconURL)
            } label: {
                Label("Add to Reading List", systemImage: "text.bookmark")
            }
            Button {
                state.pinAsApp(name: tab.displayTitle, url: url, faviconURL: tab.faviconURL)
            } label: {
                Label("Pin as App", systemImage: "pin")
            }
            Button {
                state.openInLittleArc(url: url)
            } label: {
                Label("Open in Little Arc", systemImage: "arrow.up.forward.app")
            }
            Button {
                state.toggleSplitTab(tab.id)
            } label: {
                Label(state.isSplitActive ? "Add to Split" : "Split with Active Tab", systemImage: "rectangle.split.2x1")
            }
            Button {
                Task {
                    let boost = Boost(name: tab.displayTitle, urlPattern: url.host ?? url.absoluteString,
                                     css: "", js: "", forceDarkMode: false, zappedSelectors: [], isEnabled: true)
                    await BoostStore.shared.create(boost)
                }
            } label: {
                Label("Create Boost for This Site", systemImage: "paintbrush.pointed")
            }
        }
    }

    // MARK: Archived shelf

    @ViewBuilder
    private var archivedShelf: some View {
        ArchivedShelfView()
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: Spaces rail (bottom)

    private var spaceRail: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.hiveBorderSubtle).frame(height: 1)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: HiveSpacing.s4) {
                    ForEach(state.spaces) { space in spaceIcon(space) }
                }
                .padding(.vertical, HiveSpacing.s8)
            }
        }
    }

    private func spaceIcon(_ space: Space) -> some View {
        let isActiveSpace = space.id == state.activeSpace.id
        let accent = Color(HiveColorToken(rawValue: space.accentTokenName) ?? .accent)
        return Button {
            state.switchSpace(to: space.id)
        } label: {
            RoundedRectangle(cornerRadius: HiveRadius.r6)
                .fill(isActiveSpace ? accent.opacity(0.18) : Color.clear)
                .frame(width: HiveDimension.faviconVertical, height: HiveDimension.faviconVertical)
                .overlay(
                    Image(systemName: space.iconName)
                        .font(HiveTypography.font(.sectionTitle))
                        .foregroundStyle(isActiveSpace ? accent : Color.hiveGraphite)
                )
        }
        .buttonStyle(SpaceIconPressStyle())
        .help(Text(space.name))
        .accessibilityLabel("Space: \(space.name)")
        .contextMenu { spaceContextMenu(for: space) }
    }

    @ViewBuilder
    private func spaceContextMenu(for space: Space) -> some View {
        Button("Rename Space…") {
            state.renameSpace(space.id, to: promptForSpaceName(space.name) ?? space.name)
        }
        SpaceAccentPicker(space: space, state: state)
        SpaceIconPicker(space: space, state: state)
        Divider()
        if state.spaces.count > 1 {
            Button("Delete Space", role: .destructive) {
                state.deleteSpace(space.id)
            }
        }
    }

    // MARK: Tab search filter

    /// Applies the search filter when a query is active; otherwise returns all tabs unchanged.
    private func filterBySearch(_ tabs: [BrowserTab]) -> [BrowserTab] {
        guard let filtered = filteredTabIDs else { return tabs }
        return tabs.filter { filtered.contains($0.id) }
    }

    // MARK: Search field

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: HiveSpacing.s4) {
            Image(systemName: "magnifyingglass")
                .font(HiveTypography.font(.captionMedium))
                .foregroundStyle(.hiveGraphite)
            TextField("Search tabs…", text: $tabSearchQuery)
                .hiveType(.chromeLabel)
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
            if !tabSearchQuery.isEmpty {
                Button {
                    tabSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveTypography.font(.caption2))
                        .foregroundStyle(.hiveGraphite)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, HiveSpacing.s8)
        .padding(.vertical, HiveSpacing.s4)
        .background(Color.hiveSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r6))
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r6)
                .stroke(Color.hiveBorder, lineWidth: 0.5)
        )
        .padding(.horizontal, HiveSpacing.s8)
        .padding(.vertical, HiveSpacing.s4)
        .animation(.hiveMicro, value: tabSearchQuery.isEmpty)
    }

    // MARK: New tab row

    private var newTabRow: some View {
        Button {
            state.newTab()
        } label: {
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "plus")
                    .font(.system(size: isExpandedOrSidebarOpen ? 12 : 14, weight: .medium))
                    .foregroundStyle(state.activeAccentColor)
                if isExpandedOrSidebarOpen {
                    Text("New Tab").hiveType(.chromeTitle).foregroundStyle(.hiveGraphite)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: rowHeight)
            .frame(maxWidth: .infinity)
            .padding(.leading, isExpandedOrSidebarOpen ? HiveSpacing.s8 : 0)
            // Hover fill matching the tab rows — same r8 radius, same 150ms fade.
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(Color.hiveSurface.opacity(hoveringNewTabRow ? 0.55 : 0))
            )
            .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
            .animation(.hiveMicro, value: hoveringNewTabRow)
        }
        .buttonStyle(.plain)
        .onHover { hoveringNewTabRow = $0 }
        .keyboardShortcut("t", modifiers: .command)
        .accessibilityLabel("New tab")
        .alert("Rename Group", isPresented: Binding(
            get: { renameGroupTarget != nil },
            set: { if !$0 { renameGroupTarget = nil } }
        )) {
            TextField("Group name", text: $renameGroupText)
            Button("Cancel", role: .cancel) {
                renameGroupTarget = nil
                renameGroupText = ""
            }
            Button("Rename") {
                if let group = renameGroupTarget {
                    let trimmed = renameGroupText.trimmingCharacters(in: .whitespacesAndNewlines)
                    state.renameGroup(group.id, to: trimmed.isEmpty ? group.name : trimmed)
                }
                renameGroupTarget = nil
                renameGroupText = ""
            }
            .disabled(renameGroupText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Rename this tab group. The name shows on the group header and is searchable in Tab Overview.")
        }
    }

    // MARK: Expand/collapse timing

    private func expand() {
        cancelCollapse()
        withAnimation(widthAnimation) { isExpanded = true }
    }

    private func scheduleCollapse() {
        cancelCollapse()
        let work = DispatchWorkItem { [self] in
            // Re-check on the main thread: the user may have re-entered the bar.
            if !state.prefs.sidebarOpen {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.12) : .hiveCollapse) {
                    isExpanded = false
                }
            }
        }
        collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: work)
    }

    private func cancelCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }
}

// MARK: - Space icon press style
//
// The space rail's documented signature micro-interaction (header comment: "space icon
// pulses briefly on tap (scale 0.92→1)") — now actually wired as a Button press style.
// Spring out at 0.28s, damping 0.6, matching the rail's lively feel.

private struct SpaceIconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - VerticalTabDropReceiver
//
/// Handles drop events for the vertical tab bar. Accepts same-window tab reordering,
/// cross-window tab drops via NSItemProvider, and external URL drops.
@MainActor
private struct VerticalTabDropReceiver: DropDelegate {
    let tabIDs: [String]
    let state: ChromeState

    func performDrop(info: DropInfo) -> Bool {
        // Same-window: check for draggedTabID - not available in vertical view yet
        // For now, handle cross-window drops
        for provider in info.itemProviders(for: [.text]) {
            let capturedTabCount = tabIDs.count
            provider.loadObject(ofClass: NSString.self) { [capturedTabCount] (obj, _) in
                guard let id = obj as? String else { return }
                let targetIdx = min(capturedTabCount, capturedTabCount)
                DispatchQueue.main.async { [state] in
                    state.moveTab(id, to: max(0, targetIdx))
                }
            }
            return true
        }

        // Fallback: accept a dropped URL to open in new tab
        for provider in info.itemProviders(for: [.url]) {
            provider.loadObject(ofClass: NSURL.self) { (obj, _) in
                guard let url = obj as? URL else { return }
                DispatchQueue.main.async { [state] in
                    state.newTab(url: url as URL)
                }
            }
            return true
        }

        return false
    }
}

// MARK: - VerticalRowDropReceiver
//
// Per-row drop delegate for Zen/Arc-class same-window reordering in the vertical rail.
// Mirrors the horizontal `TabDropReceiver` contract: same-window drags (tracked via the
// shared `draggedTabID` binding) move the tab to this row's index; cross-window and
// external URL drops fall through to the same NSItemProvider handling the container
// receiver uses, so a drop onto any row never dead-ends.
//
// The target index is the enumerated position within `state.ungroupedTabs.filter {
// !$0.isPinned }` — the same ordering the container receiver and `moveTab(_:to:)` use.
// Per-row drops are only attached when no search filter is active (indices stay valid).

@MainActor
private struct VerticalRowDropReceiver: DropDelegate {
    let targetIndex: Int
    @Binding var draggedTabID: String?
    @Binding var dropTargetRowID: String?
    let rowID: String
    let state: ChromeState

    func dropEntered(info: DropInfo) {
        dropTargetRowID = rowID
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetRowID == rowID {
            dropTargetRowID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedTabID = nil
            dropTargetRowID = nil
        }

        // Same-window drag: move to this row's index in the ungrouped-unpinned order.
        if let draggedID = draggedTabID {
            state.moveTab(draggedID, to: max(0, targetIndex))
            return true
        }

        // Cross-window: accept the tab ID payload and insert at this index.
        for provider in info.itemProviders(for: [.text]) {
            let capturedIndex = targetIndex
            provider.loadObject(ofClass: NSString.self) { [capturedIndex] (obj, _) in
                guard let id = obj as? String else { return }
                DispatchQueue.main.async { [state] in
                    state.moveTab(id, to: max(0, capturedIndex))
                }
            }
            return true
        }

        // External URL: open in a new tab.
        for provider in info.itemProviders(for: [.url]) {
            provider.loadObject(ofClass: NSURL.self) { (obj, _) in
                guard let url = obj as? URL else { return }
                DispatchQueue.main.async { [state] in
                    state.newTab(url: url as URL)
                }
            }
            return true
        }

        return false
    }
}

// MARK: - Invisible hover zone that drives expand/collapse
//
// A clear hit-test layer covering the bar's frame. Entering the bar (or its hover margin)
// expands; leaving schedules a collapse. We give the collapsed 48pt rail a small hover
// margin so the cursor doesn't have to be pixel-perfect to expand (research: Zen's
// anti-flicker 150ms hold; Hive uses the 300ms collapse delay instead).

private struct ExpansionHoverTarget: View {
    @Binding var isExpanded: Bool
    let cancelCollapse: () -> Void
    let expand: () -> Void
    let scheduleCollapse: () -> Void
    let sidebarOpen: Bool

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onHover { hovering in
                if sidebarOpen { return }   // sidebar-open → permanent expanded, ignore hover
                if hovering {
                    expand()
                } else {
                    scheduleCollapse()
                }
            }
    }
}
