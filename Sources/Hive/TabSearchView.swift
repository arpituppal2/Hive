import SwiftUI

// MARK: - TabSearchOverlay
//
// Chrome / Edge / Safari-style tab search (⌘⇧A). Unlike Chrome (which spans
// windows), Hive's spans SPACES: every tab in the current profile is listed,
// grouped by workspace with the workspace icon and name as a section header.
// Selecting a tab in another space switches to it before activating.
//
// Keyboard: ↑/↓ navigate, ⏎ switch, esc close. Mouse: click to switch.

struct TabSearchOverlay: View {
    @Environment(BrowserState.self) private var state
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isFocused: Bool

    // A flat, navigable row: every entry knows whether it opens its
    // workspace's section so the header can be rendered inline (single
    // selectedIndex drives both headers and rows).
    /// fileprivate (not private): TabSearchRow below references this type for
    /// its row payload; the two live in the same file.
    fileprivate struct FlatEntry: Identifiable {
        let id: String          // tab id — unique across the browser
        let workspace: BrowserState.Workspace
        let tab: BrowserState.Tab
        let isFirstInGroup: Bool
    }

    /// Tabs in the current profile, grouped by workspace in display order.
    /// Workspaces with no matching tabs are omitted entirely.
    private var groupedTabs: [(workspace: BrowserState.Workspace, tabs: [BrowserState.Tab])] {
        let profileWorkspaces = state.workspacesForCurrentProfile
        let workspaceIDs = Set(profileWorkspaces.map(\.id))
        let candidates = state.tabs.filter { workspaceIDs.contains($0.workspaceID) }
        return profileWorkspaces.compactMap { workspace in
            let tabs = candidates.filter { $0.workspaceID == workspace.id && matches($0) }
            return tabs.isEmpty ? nil : (workspace, tabs)
        }
    }

    private var flatResults: [FlatEntry] {
        groupedTabs.flatMap { group in
            group.tabs.enumerated().map { index, tab in
                FlatEntry(
                    id: tab.id,
                    workspace: group.workspace,
                    tab: tab,
                    isFirstInGroup: index == 0
                )
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { state.closeTabSearch() }

            VStack(spacing: 0) {
                searchHeader
                Divider()
                resultsList
                footer
            }
            .background(HiveDesign.Material.panel)
            .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
            .frame(maxWidth: 620)
            .padding(.horizontal, 40)
            .onAppear { isFocused = true }
        }
    }

    // MARK: - Search header

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(HiveDesign.Typography.panelTitleMedium)
                .foregroundStyle(.secondary)

            TextField("Search tabs across spaces...", text: $query)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.subHeading)
                .focused($isFocused)
                .onSubmit { executeSelection() }
                .onChange(of: query) { _, _ in selectedIndex = 0 }
                .onKeyPress(.escape) { state.closeTabSearch(); return .handled }
                .onKeyPress(.upArrow) {
                    let count = flatResults.count
                    if count > 0 { selectedIndex = (selectedIndex - 1 + count) % count }
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    let count = flatResults.count
                    if count > 0 { selectedIndex = (selectedIndex + 1) % count }
                    return .handled
                }

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Results

    @ViewBuilder private var resultsList: some View {
        if flatResults.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "square.on.square.dashed")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("No matching tabs")
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(.secondary)
                Text("Try a page title, host, or space name")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(flatResults.enumerated()), id: \.element.id) { index, entry in
                        VStack(spacing: 0) {
                            if entry.isFirstInGroup {
                                workspaceHeader(entry.workspace)
                            }
                            TabSearchRow(
                                entry: entry,
                                isSelected: index == selectedIndex,
                                displayTitle: displayTitle(entry.tab),
                                displayHost: displayHost(entry.tab)
                            ) {
                                select(entry.tab)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 460)
        }
    }

    private func workspaceHeader(_ workspace: BrowserState.Workspace) -> some View {
        HStack(spacing: 6) {
            Image(systemName: workspace.iconName)
                .font(HiveDesign.Typography.captionSemiBold)
                .foregroundStyle(workspace.swiftUIColor)
            Text(workspace.name)
                .font(HiveDesign.Typography.smallLabelBold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(flatResults.count) tab\(flatResults.count == 1 ? "" : "s")")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.secondary)
            Spacer()
            Text("↑↓ navigate")
            Text("⏎ switch")
            Text("esc close")
        }
        .font(HiveDesign.Typography.buttonCaption)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func matches(_ tab: BrowserState.Tab) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        let title = displayTitle(tab).lowercased()
        let host = displayHost(tab).lowercased()
        let url = (tab.model.url?.absoluteString ?? tab.savedURL?.absoluteString ?? "").lowercased()
        let workspaceName = state.workspacesForCurrentProfile.first { $0.id == tab.workspaceID }?.name.lowercased() ?? ""
        let groupName = state.groupForTab(tab)?.name.lowercased() ?? ""
        return title.contains(q) || host.contains(q) || url.contains(q)
            || workspaceName.contains(q) || groupName.contains(q)
    }

    private func displayTitle(_ tab: BrowserState.Tab) -> String {
        if let custom = tab.customTitle, !custom.isEmpty { return custom }
        if !tab.model.title.isEmpty { return tab.model.title }
        if let url = tab.model.url ?? tab.savedURL, url.absoluteString != "about:blank" {
            return url.host ?? url.absoluteString
        }
        return "New Tab"
    }

    private func displayHost(_ tab: BrowserState.Tab) -> String {
        if let url = tab.model.url ?? tab.savedURL, url.absoluteString != "about:blank", let host = url.host {
            return host
        }
        return tab.isHibernated ? "Sleeping tab" : "New tab page"
    }

    private func select(_ tab: BrowserState.Tab) {
        state.selectTabFromSearch(id: tab.id)
    }

    private func executeSelection() {
        guard flatResults.indices.contains(selectedIndex) else { return }
        select(flatResults[selectedIndex].tab)
    }
}

// MARK: - TabSearchRow

private struct TabSearchRow: View {
    let entry: TabSearchOverlay.FlatEntry
    let isSelected: Bool
    let displayTitle: String
    let displayHost: String
    let action: () -> Void

    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                leadingIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.system(size: 13, weight: entry.tab.id == state.activeTabID ? .semibold : .medium))
                        .foregroundStyle(entry.tab.isHibernated ? .tertiary : .primary)
                        .lineLimit(1)
                    Text(displayHost)
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Tab group color chip
                if let groupColor = state.tabGroupColor(entry.tab) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(groupColor)
                        .frame(width: 8, height: 8)
                        .help("Group: \(state.groupForTab(entry.tab)?.name ?? "")")
                }

                if entry.tab.isPinned {
                    Image(systemName: "pin.fill")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(.secondary)
                }

                // Browser-level mute / live playing indicator — muted takes
                // precedence so the row always tells the truth.
                if state.isTabMuted(entry.tab.id) {
                    Image(systemName: "speaker.slash.fill")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(HiveDesign.Accent.primary)
                        .help("Muted")
                } else if state.mediaPlayingTabIDs.contains(entry.tab.id) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(HiveDesign.Accent.primary)
                        .help("Playing audio")
                }

                // Active tab marker
                if entry.tab.id == state.activeTabID {
                    Image(systemName: "checkmark.circle.fill")
                        .font(HiveDesign.Typography.body)
                        .foregroundStyle(HiveDesign.Accent.primary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? HiveDesign.Surface.level2 : (isHovered ? HiveDesign.Surface.level1 : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder private var leadingIcon: some View {
        if entry.tab.isHibernated {
            Image(systemName: "moon.zzz.fill")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(.tertiary)
                .frame(width: 22, height: 22)
        } else if let favicon = entry.tab.model.faviconURL {
            FaviconImage(url: favicon)
                .frame(width: 16, height: 16)
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: "globe")
                .font(HiveDesign.Typography.sidebarItemMedium)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
        }
    }
}
