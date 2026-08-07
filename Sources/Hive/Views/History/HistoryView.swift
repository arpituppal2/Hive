import SwiftUI
import HiveCore

// MARK: - HistoryView
//
// Browsing history panel (⌘Y). Groups entries by calendar date (Today, Yesterday,
// then individual dates). Each row shows favicon, title, URL host, and visit time.
// A search field filters by title or URL. Tapping a row opens the URL in a new tab.
// The "Clear History" button at the bottom removes all records.

struct HistoryView: View {

    @Environment(ChromeState.self) private var state

    @State private var searchText = ""
    /// Which history row is hovered, for the row wash (Chrome-class feedback).
    @State private var hoveredEntryID: String? = nil

    // Shared formatters — the per-call construction was the same perf anti-pattern
    // fixed on StartPage / SwarmHome / TabOverview / ArchivedShelf.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.hiveBorderSubtle)
            if groupedEntries.isEmpty && !searchText.isEmpty {
                emptySearch
            } else if groupedEntries.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .frame(width: 400, height: 520)
        .background(Color.hiveBackground)
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r12))
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
                .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    // MARK: Computed

    private var filtered: [BrowsingHistoryEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return state.prefs.historyEntries }
        return state.prefs.historyEntries.filter {
            $0.title.lowercased().contains(q) || $0.url.absoluteString.lowercased().contains(q)
        }
    }

    /// Returns entries grouped by calendar date, newest first.
    private var groupedEntries: [(date: Date, entries: [BrowsingHistoryEntry])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filtered) { entry in
            cal.startOfDay(for: entry.visitDate)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, entries: $0.value.sorted { $0.visitDate > $1.visitDate }) }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: HiveSpacing.s12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(HiveTypography.font(.panelTitle))
                .foregroundStyle(.hiveGraphite)
            Text("History")
                .hiveType(.body)
                .foregroundStyle(.hiveInk)
            Spacer()
            if !filtered.isEmpty {
                Button("Clear") {
                    state.clearHistory()
                }
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveAccent)
                .buttonStyle(.plain)
            }
            Button {
                state.toggleHistoryPanel()
            } label: {
                Image(systemName: "xmark")
                    .font(HiveTypography.font(.captionMedium))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: HiveDimension.toolbarButton, height: HiveDimension.toolbarButton)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, HiveSpacing.s16)
        .padding(.vertical, HiveSpacing.s12)
    }

    // MARK: Empty states

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.s12) {
            Spacer()
            Image(systemName: "clock")
                .font(HiveTypography.font(.display3))
                .foregroundStyle(.hiveMist)
            Text("No browsing history")
                .hiveType(.body)
                .foregroundStyle(.hiveGraphite)
            Text("Pages you visit will appear here.")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveMist)
            Spacer()
        }
    }

    private var emptySearch: some View {
        VStack(spacing: HiveSpacing.s12) {
            Spacer()
            Text("No results for \"\\(searchText)\"")
                .hiveType(.body)
                .foregroundStyle(.hiveGraphite)
            Spacer()
        }
    }

    // MARK: History list

    private var historyList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Search field
                HStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "magnifyingglass")
                        .font(HiveTypography.font(.caption1))
                        .foregroundStyle(.hiveGraphite)
                    TextField("Search history", text: $searchText)
                        .textFieldStyle(.plain)
                        .hiveType(.body)
                }
                .padding(HiveSpacing.s8)
                .background(RoundedRectangle(cornerRadius: HiveRadius.r6).fill(Color.hiveSurface.opacity(0.5)))
                .padding(.horizontal, HiveSpacing.s12)
                .padding(.vertical, HiveSpacing.s8)

                ForEach(groupedEntries, id: \.date) { group in
                    dateHeader(group.date)
                    ForEach(group.entries) { entry in
                        historyRow(entry)
                    }
                }
            }
        }
    }

    // MARK: Date header

    private func dateHeader(_ date: Date) -> some View {
        let label = dateLabel(for: date)
        return Text(label)
            .hiveType(.chromeLabel)
            .foregroundStyle(.hiveGraphite)
            .padding(.horizontal, HiveSpacing.s16)
            .padding(.vertical, HiveSpacing.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.hiveSurface.opacity(0.3))
    }

    private func dateLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return Self.dayFormatter.string(from: date)
    }

    // MARK: History row

    private func historyRow(_ entry: BrowsingHistoryEntry) -> some View {
        let isHovered = hoveredEntryID == entry.id
        return Button {
            state.newTab(url: entry.url)
            state.toggleHistoryPanel()
        } label: {
            HStack(spacing: HiveSpacing.s12) {
                // Favicon
                if let favURL = entry.faviconURL {
                    FaviconView(url: favURL)
                        .frame(width: HiveDimension.faviconVertical, height: HiveDimension.faviconVertical)
                } else {
                    Image(systemName: "globe")
                        .font(HiveTypography.font(.caption2))
                        .foregroundStyle(.hiveGraphite)
                        .frame(width: HiveDimension.faviconVertical, height: HiveDimension.faviconVertical)
                }
                // Title + URL
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? entry.host : entry.title)
                        .hiveType(.chromeTitle)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HStack(spacing: HiveSpacing.s4) {
                        Text(entry.host)
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveGraphite)
                            .lineLimit(1)
                        Text("·")
                            .foregroundStyle(.hiveMist)
                        Text(timeLabel(for: entry.visitDate))
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveMist)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, HiveSpacing.s16)
            .padding(.vertical, HiveSpacing.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r6)
                    .fill(Color.hiveSurface.opacity(isHovered ? 0.5 : 0))
            )
            .contentShape(Rectangle())
            .animation(.hiveMicro, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredEntryID = hovering ? entry.id : nil
        }
    }

    private func timeLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        }
        return ""
    }
}
