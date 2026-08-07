import SwiftUI
import HiveCore

// MARK: - OmnibarSuggestionsView
//
// A dropdown suggestion list that appears below the omnibar as the user types.
// Matches against BrowsingHistoryEntry and Bookmarks (when implemented) locally —
// no remote suggestions, no telemetry. Shows favicon + title + URL for each match.
// Keyboard-navigable (arrow keys + Enter). Dismissed when the omnibar loses focus
// or the user submits a suggestion.
//
// Why a separate view instead of inlining: the dropdown needs to escape the omnibar's
// frame and appear as an overlay, and it needs independent scroll/keyboard state.

struct OmnibarSuggestionsView: View {

    let query: String
    let history: [BrowsingHistoryEntry]
    let bookmarks: [Bookmark]
    let onSelect: (URL) -> Void
    let onSelectBackground: (URL) -> Void
    let searchEngine: SearchEngineKind

    @State private var selectedIndex: Int = 0

    private var suggestions: [Suggestion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return [] }
        var results: [Suggestion] = []

        // Deduplicate by URL across sources.
        var seen = Set<String>()

        // 1. Bookmark matches (shown first — user explicitly saved these).
        for bm in bookmarks where !bm.isFolder {
            guard let url = bm.url else { continue }
            let key = url.absoluteString.lowercased()
            guard !seen.contains(key) else { continue }
            if bm.title.lowercased().contains(q) || url.absoluteString.lowercased().contains(q) {
                seen.insert(key)
                results.append(.init(title: bm.title, url: url, host: url.host ?? "", faviconURL: bm.faviconURL, source: .bookmark))
            }
        }

        // 2. History matches (deeper corpus).
        for entry in history {
            guard results.count < 8 else { break }
            let key = entry.url.absoluteString.lowercased()
            guard !seen.contains(key) else { continue }
            if entry.title.lowercased().contains(q) || entry.url.absoluteString.lowercased().contains(q) {
                seen.insert(key)
                results.append(.init(title: entry.title, url: entry.url, host: entry.host, faviconURL: entry.faviconURL, source: .history))
            }
        }

        // 3. Search suggestion (fallback — "Search for 'query'").
        if results.count < 6,
           let searchURL = SearchEngine.searchURL(for: q, engine: searchEngine) {
            results.append(.init(title: "Search for \"\(q)\"", url: searchURL, host: "", faviconURL: nil, source: .search))
        }

        return Array(results.prefix(9))
    }

    /// Grouped by source so the dropdown shows Chrome-class section headers
    /// (Bookmarks / History / Search) instead of an undifferentiated list.
    private var grouped: [(title: String, items: [Suggestion])] {
        let list = suggestions
        var groups: [(String, [Suggestion])] = []
        for source in [Suggestion.Source.bookmark, .history, .search] {
            let items = list.filter { $0.source == source }
            if !items.isEmpty {
                groups.append((source.headerTitle, items))
            }
        }
        return groups
    }

    var body: some View {
        let list = suggestions
        if list.isEmpty { EmptyView() } else {
            VStack(spacing: 0) {
                ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                    // Section header — Chrome-class grouping label.
                    HStack(spacing: HiveSpacing.s4) {
                        Image(systemName: group.title == "Bookmarks" ? "bookmark"
                              : group.title == "History" ? "clock"
                              : "magnifyingglass")
                            .font(HiveTypography.font(.microTinyMedium))
                            .foregroundStyle(.hiveMist)
                        Text(group.title.uppercased())
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveMist)
                            .kerning(0.8)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, HiveSpacing.s8)
                    .padding(.top, HiveSpacing.s4)
                    .padding(.bottom, 2)
                    .accessibilityHidden(true)

                    ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, suggestion in
                        let flatIdx = flatIndex(of: suggestion)
                        SuggestionRow(
                            suggestion: suggestion,
                            isSelected: flatIdx == selectedIndex,
                            onSelect: { onSelect(suggestion.url) }
                        )
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(suggestion.url) }
                            .onHover { hovering in if hovering { selectedIndex = flatIdx } }
                        if idx < group.items.count - 1 {
                            Divider()
                                .overlay(Color.hiveBorderSubtle)
                                .padding(.leading, HiveDimension.suggestionIconSize + HiveSpacing.s16)
                        }
                    }
                }
            }
            .padding(HiveSpacing.s4)
            .hiveSurface(.activeOverlay)
            .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r12))
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r12)
                    .stroke(Color.hiveBorderSubtle, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: HiveRadius.r16, x: 0, y: HiveSpacing.s8)
            .onKeyPress(.upArrow) {
                selectedIndex = max(0, selectedIndex - 1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                selectedIndex = min(list.count - 1, selectedIndex + 1)
                return .handled
            }
            .onSubmit {
                if selectedIndex < list.count {
                    onSelect(list[selectedIndex].url)
                }
            }
            // Chrome verbatim: ⌘⏎ opens the highlighted suggestion in a BACKGROUND tab
            // without leaving the current page. Hidden button + keyboardShortcut follows
            // the BrowserWindow pattern. The dropdown closes but the omnibox text stays.
            Button("") {
                if selectedIndex < list.count {
                    onSelectBackground(list[selectedIndex].url)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .hidden()
        }
    }

    /// Maps a suggestion back to its flattened index (keyboard nav stays linear).
    private func flatIndex(of suggestion: Suggestion) -> Int {
        suggestions.firstIndex { $0.id == suggestion.id } ?? 0
    }
}

// MARK: - Suggestion model

private struct Suggestion: Identifiable {
    var id: String { url.absoluteString }
    let title: String
    let url: URL
    let host: String
    let faviconURL: URL?
    let source: Source

    enum Source {
        case history, bookmark, search
        var headerTitle: String {
            switch self {
            case .bookmark: return "Bookmarks"
            case .history:  return "History"
            case .search:   return "Search"
            }
        }
    }
}

// MARK: - SuggestionRow

private struct SuggestionRow: View {
    @Environment(ChromeState.self) private var state
    let suggestion: Suggestion
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: HiveSpacing.s8) {
            // Icon
            Group {
                if suggestion.source == .search {
                    Image(systemName: "magnifyingglass")
                        .font(HiveTypography.font(.caption1))
                        .foregroundStyle(state.activeAccentColor)
                } else if let fav = suggestion.faviconURL {
                    FaviconView(url: fav).frame(width: 16, height: 16)
                } else {
                    Image(systemName: suggestion.source == .bookmark ? "bookmark.fill" : "clock")
                        .font(HiveTypography.font(.caption1))
                        .foregroundStyle(.hiveGraphite)
                }
            }
            .frame(width: HiveDimension.suggestionIconSize, height: HiveDimension.suggestionIconSize)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r6)
                    .fill(isSelected ? state.activeAccentColor.opacity(0.15) : Color.clear)
            )

            // Title + URL
            VStack(alignment: .leading, spacing: 1) {
                Text(suggestion.title.isEmpty ? suggestion.host : suggestion.title)
                    .hiveType(.chromeTitle)
                    .foregroundStyle(.hiveInk)
                    .lineLimit(1)
                if !suggestion.host.isEmpty && suggestion.source != .search {
                    Text(suggestion.host)
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveGraphite)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, HiveSpacing.s12)
        .padding(.vertical, HiveSpacing.s4)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(isSelected ? state.activeAccentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sourceLabel): \(suggestion.title.isEmpty ? suggestion.host : suggestion.title)")
        .accessibilityValue(suggestion.host.isEmpty ? "" : suggestion.host)
        .accessibilityHint("Press Return to open this suggestion")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction { onSelect() }
    }

    private var sourceLabel: String {
        switch suggestion.source {
        case .bookmark: return "Bookmark"
        case .history: return "History"
        case .search: return "Search"
        }
    }
}
