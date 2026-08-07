import SwiftUI
import HiveCore

// MARK: - ReadingListView
//
// A searchable, sortable sidebar panel for articles saved for later (⌘⇧L).
// Follows the same overlay-panel pattern as BookmarksPanelView, HistoryView,
// and DownloadsView: rendered in BrowserWindow's ZStack with opacity + hit-testing.
//
// Each entry shows favicon, title, host, time-ago label, and read/unread indicator.
// Clicking an entry opens it in a new tab and marks it as read.
// Empty state appears when the reading list is empty.
struct ReadingListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ChromeState.self) private var state

    /// The current search/filter text.
    @State private var searchText = ""

    /// Which sort mode is active.
    @State private var sortMode: SortMode = .savedDate

    /// Which entry row is hovered, for the row wash (Chrome-class feedback).
    @State private var hoveredEntryID: String? = nil

    private var readingList: [ReadingListEntry] {
        var results = state.prefs.readingList
        // Filter by search text.
        if !searchText.isEmpty {
            results = results.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.host.localizedCaseInsensitiveContains(searchText)
                || ($0.note?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        // Sort.
        switch sortMode {
        case .savedDate:
            results.sort { $0.savedAt > $1.savedAt }
        case .title:
            results.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .unreadFirst:
            results.sort { (!$0.isRead && $1.isRead) || ($0.isRead == $1.isRead && $0.savedAt > $1.savedAt) }
        }
        return results
    }

    private var unreadCount: Int {
        state.prefs.readingList.filter { !$0.isRead }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            Divider().overlay(.hiveGraphite.opacity(0.3))
            // Content
            if readingList.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        .frame(minWidth: 300, idealWidth: 360, maxWidth: 500,
               minHeight: 200, idealHeight: 400, maxHeight: .infinity)
        .background(Color.hiveBackground)
        .overlay(alignment: .topTrailing) {
            closeButton
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: HiveSpacing.s8) {
            Image(systemName: "bookmark")
                .font(HiveTypography.font(.bodyMedium))
                .foregroundStyle(.hiveAccent)
            Text("Reading List")
                .hiveType(.body)
                .foregroundStyle(.hiveInk)
            Spacer(minLength: 4)
            // Unread count badge.
            if unreadCount > 0 {
                Text("\\(unreadCount)")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveAccent)
                    .padding(.horizontal, HiveSpacing.s4)
                    .padding(.vertical, 2)
                    .background(.hiveAccent.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, HiveSpacing.s12)
        .padding(.vertical, HiveSpacing.s8)
    }

    // MARK: - Search + Sort bar

    private var searchSortBar: some View {
        HStack(spacing: HiveSpacing.s4) {
            // Search field.
            HStack(spacing: HiveSpacing.s4) {
                Image(systemName: "magnifyingglass")
                    .font(HiveTypography.font(.caption2))
                    .foregroundStyle(.hiveGraphite)
                TextField("Filter reading list", text: $searchText)
                    .textFieldStyle(.plain)
                    .hiveType(.caption1)
                    .foregroundStyle(.hiveInk)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
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
            .background(.hiveMist.opacity(0.3), in: RoundedRectangle(cornerRadius: HiveRadius.r6))

            // Sort picker.
            Menu {
                Button("Newest First") { sortMode = .savedDate }
                Button("Title A-Z") { sortMode = .title }
                Button("Unread First") { sortMode = .unreadFirst }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(HiveTypography.font(.captionMedium))
                    .foregroundStyle(.hiveGraphite)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, HiveSpacing.s12)
        .padding(.vertical, HiveSpacing.s4)
    }

    // MARK: - List

    private var listView: some View {
        VStack(spacing: 0) {
            searchSortBar
            Divider().overlay(.hiveGraphite.opacity(0.15))
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(readingList) { entry in
                        entryRow(entry)
                        Divider().overlay(.hiveGraphite.opacity(0.08))
                            .padding(.leading, 36)
                    }
                }
                .padding(.vertical, HiveSpacing.s4)
            }
            // Bottom bar with count.
            HStack {
                Text("\\(readingList.count) article\\(readingList.count == 1 ? \"\" : \"s\")")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
                Spacer()
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s4)
            .background(.hiveMist.opacity(0.08))
        }
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: ReadingListEntry) -> some View {
        let isHovered = hoveredEntryID == entry.id
        return HStack(spacing: HiveSpacing.s8) {
            // Read/unread dot.
            Circle()
                .fill(entry.isRead ? Color.clear : Color.hiveAccent)
                .frame(width: 6, height: 6)

            // Favicon.
            if let favicon = entry.faviconURL {
                FaviconView(url: favicon)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "doc.text")
                    .font(HiveTypography.font(.caption1))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: 16, height: 16)
            }

            // Title + host.
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .hiveType(.caption1)
                    .foregroundStyle(.hiveInk)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(entry.host)
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Time ago.
            Text(entry.savedAt, style: .relative)
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
                .lineLimit(1)
        }
        .padding(.horizontal, HiveSpacing.s12)
        .padding(.vertical, HiveSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r6)
                .fill(Color.hiveSurface.opacity(isHovered ? 0.5 : 0))
        )
        .contentShape(Rectangle())
        .animation(.hiveMicro, value: isHovered)
        .onHover { hovering in
            hoveredEntryID = hovering ? entry.id : nil
        }
        .onTapGesture {
            state.openReadingListEntry(entry)
            state.toggleReadingListPanel()
        }
        .contextMenu {
            Button {
                state.openReadingListEntry(entry)
                state.toggleReadingListPanel()
            } label: {
                Label("Open", systemImage: "arrow.up.forward")
            }
            Button {
                state.toggleReadingListReadState(id: entry.id)
            } label: {
                Label(entry.isRead ? "Mark as Unread" : "Mark as Read",
                      systemImage: entry.isRead ? "circle" : "checkmark.circle")
            }
            Divider()
            Button(role: .destructive) {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    state.removeFromReadingList(id: entry.id)
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HiveSpacing.s12) {
            Spacer()
            Image(systemName: "bookmark.slash")
                .font(HiveTypography.font(.display3))
                .foregroundStyle(.hiveGraphite.opacity(0.4))
            if searchText.isEmpty {
                Text("No saved articles")
                    .hiveType(.body)
                    .foregroundStyle(.hiveInk.opacity(0.6))
                Text("Use ⌘⇧L or the context menu\nto save pages for later")
                    .hiveType(.caption1)
                    .foregroundStyle(.hiveMist)
                    .multilineTextAlignment(.center)
            } else {
                Text("No matching articles")
                    .hiveType(.body)
                    .foregroundStyle(.hiveInk.opacity(0.6))
                Button("Clear filter") { searchText = "" }
                    .buttonStyle(.plain)
                    .hiveType(.caption1)
                    .foregroundStyle(.hiveAccent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Close

    private var closeButton: some View {
        Button {
            state.toggleReadingListPanel()
        } label: {
            Image(systemName: "xmark")
                .font(HiveTypography.font(.caption3Medium))
                .foregroundStyle(.hiveGraphite)
                .padding(HiveSpacing.s8)
                .background(.hiveMist.opacity(0.3), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(HiveSpacing.s8)
        .keyboardShortcut(.escape, modifiers: [])
    }
}

// MARK: - Sort Mode

private enum SortMode: String, CaseIterable {
    case savedDate = "Newest First"
    case title = "Title A-Z"
    case unreadFirst = "Unread First"
}
