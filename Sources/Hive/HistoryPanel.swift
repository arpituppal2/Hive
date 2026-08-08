import SwiftUI

// MARK: - HistoryPanelSheet
//
// Safari/Chrome-style browsing history panel. Shows visited pages grouped
// by time period (Today, Yesterday, This Week, Older), with search filtering
// and a clear button.

struct HistoryPanelSheet: View {
    @Environment(BrowserState.self) private var state
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var confirmClear: Bool = false

    private var filteredItems: [HistoryItem] {
        let items = state.historyItems.reversed()
        guard !searchText.isEmpty else { return Array(items) }
        let q = searchText.lowercased()
        return items.filter { $0.title.lowercased().contains(q) || $0.url.absoluteString.lowercased().contains(q) }
    }

    private var groupedItems: [(header: String, items: [HistoryItem])] {
        let cal = Calendar.current
        let now = Date()
        var today: [HistoryItem] = []
        var yesterday: [HistoryItem] = []
        var thisWeek: [HistoryItem] = []
        var older: [HistoryItem] = []

        for item in filteredItems {
            if cal.isDateInToday(item.visitedAt) { today.append(item) }
            else if cal.isDateInYesterday(item.visitedAt) { yesterday.append(item) }
            else if cal.isDate(item.visitedAt, equalTo: now, toGranularity: .weekOfYear) { thisWeek.append(item) }
            else { older.append(item) }
        }

        var groups: [(String, [HistoryItem])] = []
        if !today.isEmpty { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !thisWeek.isEmpty { groups.append(("This Week", thisWeek)) }
        if !older.isEmpty { groups.append(("Older", older)) }
        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(HiveDesign.Typography.dialogTitle)
                    .foregroundStyle(Color.hiveAccent)

                Text("History")
                    .font(HiveDesign.Typography.subHeadingBold)

                Spacer()

                if !state.historyItems.isEmpty {
                    Button(action: { confirmClear = true }) {
                        Text("Clear")
                            .font(HiveDesign.Typography.sidebarItemMedium)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .alert("Clear browsing history?", isPresented: $confirmClear) {
                        Button("Clear", role: .destructive) { _ = state.clearBrowsingHistory() }
                        Button("Cancel", role: .cancel) {}
                    }
                }

                Button(action: { state.isHistoryPanelOpen = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            PanelSearchField(prompt: "Search history", text: $searchText, isFocused: $isSearchFocused)

            Divider()

            // List
            if state.historyItems.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(HiveDesign.Typography.heroDisplay)
                        .foregroundStyle(.tertiary)
                    Text("No browsing history")
                        .font(HiveDesign.Typography.panelTitleMedium)
                        .foregroundStyle(.secondary)
                    Text("Pages you visit will appear here")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else if filteredItems.isEmpty {
                // Search yielded no matches — never show a blank panel.
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(HiveDesign.Typography.heroDisplay)
                        .foregroundStyle(.tertiary)
                    Text("No matching pages")
                        .font(HiveDesign.Typography.panelTitleMedium)
                        .foregroundStyle(.secondary)
                    Text("Try a different title or address")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedItems, id: \.header) { group in
                            Section {
                                ForEach(group.items) { item in
                                    HistoryRow(item: item)
                                }
                            } header: {
                                HStack {
                                    Text(group.header)
                                        .font(HiveDesign.Typography.microLabel)
                                        .kerning(HiveDesign.Typography.microLabelTracking)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                    Spacer()
                                    Text("\(group.items.count)")
                                        .font(HiveDesign.Typography.monoReadout)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(HiveDesign.Surface.level1)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 480, height: 480)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
        .padding(24)
        .onAppear { isSearchFocused = true }
    }
}

// MARK: - HistoryRow

private struct HistoryRow: View {
    let item: HistoryItem
    @Environment(BrowserState.self) private var state

    var body: some View {
        Button(action: { state.navigateToURL(item.url); state.isHistoryPanelOpen = false }) {
            HStack(spacing: 10) {
                Group {
                    if let faviconURL = item.faviconURL {
                        FaviconImage(url: faviconURL)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "globe")
                            .font(HiveDesign.Typography.bodyMedium)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.url.host ?? item.url.absoluteString)
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                Text(item.visitedAt, style: .time)
                    .font(HiveDesign.Typography.monoReadout)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Divider().opacity(0.4).padding(.leading, 54)
    }
}
