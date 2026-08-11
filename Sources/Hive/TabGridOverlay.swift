import SwiftUI

// MARK: - TabGridOverlay
//
// Arc-style visual tab overview — a grid of all open tabs across spaces,
// with favicons, titles, and group colors. Clicking a tab selects it
// (cross-workspace, like tab search). Keyboard: ↑↓←→ navigate, ⏎ select,
// esc close. Typing filters the grid.

struct TabGridOverlay: View {
    @Environment(BrowserState.self) private var state
    @State private var query: String = ""
    @State private var selectedCol: Int = 0
    @State private var selectedRow: Int = 0
    @FocusState private var isFocused: Bool

    private let columns = 4

    /// Tabs in the current profile, grouped by workspace, filtered by query.
    private var groupedTabs: [(workspace: BrowserState.Workspace, tabs: [BrowserState.Tab])] {
        let profileWorkspaces = state.workspacesForCurrentProfile
        let workspaceIDs = Set(profileWorkspaces.map(\.id))
        let candidates = state.tabs.filter { workspaceIDs.contains($0.workspaceID) }
        return profileWorkspaces.compactMap { workspace in
            let tabs = candidates.filter { $0.workspaceID == workspace.id && matches($0) }
            return tabs.isEmpty ? nil : (workspace, tabs)
        }
    }

    /// Flat grid of tiles for keyboard navigation and rendering.
    private var flatTiles: [(workspace: BrowserState.Workspace, tab: BrowserState.Tab)] {
        groupedTabs.flatMap { group in
            group.tabs.map { (group.workspace, $0) }
        }
    }

    /// Number of rows in the grid.
    private var rowCount: Int {
        max(1, (flatTiles.count + columns - 1) / columns)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { state.closeTabGrid() }

            VStack(spacing: 0) {
                header
                Divider()
                if flatTiles.isEmpty {
                    emptyState
                } else {
                    gridContent
                }
                footer
            }
            .background(HiveDesign.Material.panel)
            .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
            .frame(maxWidth: 680)
            .padding(.horizontal, 40)
            .onAppear { isFocused = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .font(HiveDesign.Typography.panelTitleMedium)
                .foregroundStyle(.secondary)

            TextField("Filter tabs...", text: $query)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.subHeading)
                .focused($isFocused)
                .onSubmit { executeSelection() }
                .onChange(of: query) { _, _ in selectedCol = 0; selectedRow = 0 }
                .onKeyPress(.escape) { state.closeTabGrid(); return .handled }
                .onKeyPress(.upArrow) {
                    if selectedRow > 0 { selectedRow -= 1 }
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    if selectedRow < rowCount - 1 { selectedRow += 1 }
                    return .handled
                }
                .onKeyPress(.leftArrow) {
                    if selectedCol > 0 { selectedCol -= 1 }
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    if selectedCol < columns - 1 { selectedCol += 1 }
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

    // MARK: - Grid Content

    private var gridContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groupedTabs, id: \.workspace.id) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Workspace header
                        HStack(spacing: 6) {
                            Image(systemName: group.workspace.iconName)
                                .font(HiveDesign.Typography.captionSemiBold)
                                .foregroundStyle(group.workspace.swiftUIColor)
                            Text(group.workspace.name)
                                .font(HiveDesign.Typography.smallLabelBold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Spacer()
                            Text("\(group.tabs.count) tab\(group.tabs.count == 1 ? "" : "s")")
                                .font(HiveDesign.Typography.buttonCaption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 4)

                        // Grid row
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                            ForEach(Array(group.tabs.enumerated()), id: \.element.id) { index, tab in
                                let globalIndex = flatTiles.firstIndex(where: { $0.tab.id == tab.id }) ?? 0
                                TabGridTile(
                                    tab: tab,
                                    isSelected: globalIndex == selectedRow * columns + selectedCol,
                                    displayTitle: displayTitle(tab),
                                    displayHost: displayHost(tab),
                                    action: { select(tab) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: 480)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
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
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(flatTiles.count) tab\(flatTiles.count == 1 ? "" : "s")")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.secondary)
            Spacer()
            Text("↑↓←→ navigate")
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
        let index = selectedRow * columns + selectedCol
        guard flatTiles.indices.contains(index) else { return }
        select(flatTiles[index].tab)
    }
}

// MARK: - TabGridTile

private struct TabGridTile: View {
    let tab: BrowserState.Tab
    let isSelected: Bool
    let displayTitle: String
    let displayHost: String
    let action: () -> Void

    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon area
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tileBackground)
                        .aspectRatio(1.5, contentMode: .fit)

                    Group {
                        if tab.isHibernated {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.tertiary)
                        } else if let favicon = tab.model.faviconURL {
                            FaviconImage(url: favicon)
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    // Group color chip
                    if let groupColor = state.tabGroupColor(tab) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(groupColor)
                            .frame(width: 8, height: 8)
                            .padding(4)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if state.isTabMuted(tab.id) {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(HiveDesign.Accent.primary)
                            .padding(4)
                    } else if state.mediaPlayingTabIDs.contains(tab.id) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(HiveDesign.Accent.primary)
                            .padding(4)
                    }
                }

                // Title
                Text(displayTitle)
                    .font(HiveDesign.Typography.captionSemiBold)
                    .foregroundStyle(tab.isHibernated ? .tertiary : .primary)
                    .lineLimit(1)

                // Host
                Text(displayHost)
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.hiveAccent : (isHovered ? HiveDesign.Surface.level2 : Color.clear), lineWidth: isSelected ? 2 : 1)
            )
            .background(isSelected ? Color.hiveAccent.opacity(0.06) : (isHovered ? HiveDesign.Surface.level1 : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var tileBackground: Color {
        if tab.isHibernated { return HiveDesign.Surface.level1.opacity(0.5) }
        if let favicon = tab.model.faviconURL, favicon.absoluteString.contains("google.com") {
            return Color.blue.opacity(0.08)
        }
        return HiveDesign.Surface.level1
    }
}