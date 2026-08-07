// MARK: - TabSearchView
//
// A floating ⌘⇧A tab search overlay: dimmed backdrop, search-filtered list
// of tabs grouped by workspace (and by zone in vertical layout), keyboard
// navigation (arrows / Enter / Escape), click to switch.
//
// Uses Hive design tokens, the shared FaviconView, and ChromeState for
// the live tab list. No external deps.

import SwiftUI
import HiveCore

struct TabSearchView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FocusState private var isFocused: Bool
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0

    // MARK: - Computed properties

    private var tabLayout: TabPosition {
        state.prefs.tabPosition
    }

    private var filteredTabs: [BrowserTab] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return state.tabs }
        return state.tabs.filter { tab in
            let titleMatch = tab.displayTitle.localizedCaseInsensitiveContains(query)
            let urlMatch = tab.url?.absoluteString.localizedCaseInsensitiveContains(query) ?? false
            let hostMatch = tab.url?.host?.localizedCaseInsensitiveContains(query) ?? false
            return titleMatch || urlMatch || hostMatch
        }
    }

    /// Tabs grouped by space, split into pinned / essential / regular / hibernated zones
    /// when in vertical layout; just pinned + regular when horizontal.
    private var groupedTabs: [TabSearchGroup] {
        let visible = filteredTabs.filter { tab in
            // Only show tabs that belong to a visible space
            state.spaces.contains { $0.tabIDs.contains(tab.id) }
        }

        return state.spaces.compactMap { space in
            let spaceTabs = visible.filter { space.tabIDs.contains($0.id) }
            guard !spaceTabs.isEmpty else { return nil }

            let pinned = spaceTabs.filter { $0.isPinned && !($0.isPlayingAudio) }
            let playing = spaceTabs.filter { $0.isPlayingAudio }
            let hibernated = spaceTabs.filter { $0.isHibernated && !$0.isPinned && !$0.isPlayingAudio }
            let regular = spaceTabs.filter { !$0.isPinned && !$0.isHibernated && !$0.isPlayingAudio }

            var sections: [TabSearchSection] = []
            if !pinned.isEmpty {
                sections.append(TabSearchSection(title: "Pinned", icon: "pin.fill", tabs: pinned))
            }
            if !playing.isEmpty {
                sections.append(TabSearchSection(title: "Playing", icon: "speaker.wave.2.fill", tabs: playing))
            }
            if tabLayout == .vertical && !hibernated.isEmpty {
                sections.append(TabSearchSection(title: "Sleeping", icon: "moon.star", tabs: hibernated))
            }
            sections.append(TabSearchSection(title: nil, icon: nil, tabs: regular))

            return TabSearchGroup(space: space, sections: sections)
        }
    }

    private var flattenedTabs: [BrowserTab] {
        groupedTabs.flatMap { $0.sections.flatMap { $0.tabs } }
    }

    private var tabIndexMap: [String: Int] {
        Dictionary(uniqueKeysWithValues: flattenedTabs.enumerated().map { ($1.id, $0) })
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.hiveMist)
                    .font(HiveTypography.font(.panelTitleRegular))
                TextField("Search tabs, spaces", text: $searchText, onCommit: selectHighlighted)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search tabs and spaces")
                    .accessibilityHint("Use the arrow keys to move through results and Return to switch tabs")
                    .foregroundStyle(.hiveInk)
                    .font(HiveTypography.font(.panelTitleRegular))
                    .focused($isFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        selectedIndex = 0
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.hiveMist)
                            .font(HiveTypography.font(.bodySmall))
                            .accessibilityLabel("Clear tab search")
                    }
                    // Deliberately NO keyboardShortcut here: ⌘X is the system Cut
                    // command, and a hidden ⌘X binding on this button would hijack
                    // Cut from every text field while the overlay is up.
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
                .frame(height: 1)
                .foregroundStyle(Color.hiveInk.opacity(0.08))

            // Results counter and keyboard hint keep the recovery path discoverable without
            // competing with the search field or tab list.
            if !flattenedTabs.isEmpty {
                HStack {
                    Text("\(selectedIndex + 1) of \(flattenedTabs.count)")
                        .font(HiveTypography.font(.captionMedium))
                        .foregroundStyle(.hiveMist)
                    Spacer()
                    Text("↑↓ Navigate  ·  Return Open  ·  Esc Close")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.hiveMist.opacity(0.8))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }

            // Tab list
            if flattenedTabs.isEmpty {
                VStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.hiveMist)
                        .padding(.bottom, 8)
                    Text(searchText.isEmpty ? "No tabs open" : "No tabs match \"\(searchText)\"")
                        .font(HiveTypography.font(.bodySmall))
                        .foregroundStyle(.hiveMist)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(groupedTabs, id: \.space.id) { group in
                                TabSearchGroupView(
                                    group: group,
                                    tabIndexMap: tabIndexMap,
                                    selectedIndex: selectedIndex,
                                    onSelect: selectAndDismiss,
                                    onSelectHover: { selectedIndex = $0 }
                                )
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        if let tab = flattenedTabs[safe: newIndex] {
                            if reduceMotion {
                                proxy.scrollTo(tab.id, anchor: .center)
                            } else {
                                withAnimation(.hiveMicro) {
                                    proxy.scrollTo(tab.id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 420, maxWidth: 520, minHeight: 320, maxHeight: 520)
        .background(Color.hiveSurface)
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
                .strokeBorder(Color.hiveInk.opacity(0.12), lineWidth: 1)
        )
        .cornerRadius(HiveRadius.r12)
        .shadow(color: Color.black.opacity(0.3), radius: 24, y: 8)
        .onAppear {
            isFocused = true
            selectedIndex = min(selectedIndex, max(0, flattenedTabs.count - 1))
        }
        .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(1); return .handled }
        .onKeyPress(.return) { selectHighlighted(); return .handled }
        .onKeyPress(.escape) { dismiss(); return .handled }
    }

    private func moveSelection(_ delta: Int) {
        guard !flattenedTabs.isEmpty else { return }
        let newIndex = max(0, min(flattenedTabs.count - 1, selectedIndex + delta))
        selectedIndex = newIndex
        isFocused = true
    }

    private func selectHighlighted() {
        guard let tab = flattenedTabs[safe: selectedIndex] else { return }
        selectAndDismiss(tab)
    }

    private func selectAndDismiss(_ tab: BrowserTab) {
        state.selectTab(tab.id)
        dismiss()
    }
}

// MARK: - Tab search data models

private struct TabSearchGroup: Identifiable {
    let id: String
    let space: Space
    let sections: [TabSearchSection]

    init(space: Space, sections: [TabSearchSection]) {
        self.id = space.id
        self.space = space
        self.sections = sections
    }
}

private struct TabSearchSection: Identifiable {
    let id: String
    let title: String?
    let icon: String?
    let tabs: [BrowserTab]

    init(title: String?, icon: String?, tabs: [BrowserTab]) {
        self.id = UUID().uuidString
        self.title = title
        self.icon = icon
        self.tabs = tabs
    }
}

// MARK: - TabSearchRowView

struct TabSearchRowView: View {
    let tab: BrowserTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onSelectHover: (Int?) -> Void
    let tabIndex: Int?

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator (active/playing/pinned)
            ZStack {
                if tab.isActive {
                    Circle()
                        .fill(Color.hiveAccent)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(Color.hiveInk.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 18, height: 18)

            // Favicon or icon
            if let faviconURL = tab.faviconURL {
                FaviconView(url: faviconURL)
                    .frame(width: 16, height: 16)
                    .cornerRadius(HiveRadius.r2)
            } else {
                Image(systemName: "globe")
                    .font(HiveTypography.font(.panelTitleRegular))
                    .foregroundStyle(.hiveMist)
                    .frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.displayTitle)
                    .font(HiveTypography.font(.bodySmall))
                    .foregroundStyle(.hiveInk)
                    .lineLimit(1)

                if let url = tab.url {
                    Text(url.host ?? url.absoluteString)
                        .font(HiveTypography.font(.caption2))
                        .foregroundStyle(.hiveGraphite)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Badges
            HStack(spacing: 4) {
                if tab.isHibernated {
                    Image(systemName: "moon.star")
                        .font(HiveTypography.font(.caption3Medium))
                        .foregroundStyle(.hiveMist)
                }
                if tab.isPlayingAudio {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(HiveTypography.font(.caption3Medium))
                        .foregroundStyle(.hiveInk)
                }
                if tab.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(width: 12, height: 12)
                }
                if tab.isPinned {
                    Image(systemName: "pin.fill")
                        .font(HiveTypography.font(.caption3Medium))
                        .foregroundStyle(.hiveMist)
                }
                if tab.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(HiveTypography.font(.caption3Medium))
                        .foregroundStyle(.hiveMist)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r6)
                .fill(isSelected ? Color.hiveAccent.opacity(0.12) : Color.clear)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(tab.displayTitle)
        .accessibilityValue(tab.url?.host ?? "")
        .accessibilityHint("Press Return to switch to this tab")
        .accessibilityAction { onSelect() }
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .onTapGesture(perform: onSelect)
        .onHover { isHovered in
            onSelectHover(isHovered ? tabIndex : nil)
        }
    }
}

// MARK: - TabSearchGroupView

private struct TabSearchGroupView: View {
    let group: TabSearchGroup
    let tabIndexMap: [String: Int]
    let selectedIndex: Int
    let onSelect: (BrowserTab) -> Void
    let onSelectHover: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: group.space.iconName.isEmpty ? "circle.hexagongrid" : group.space.iconName)
                    .font(HiveTypography.font(.captionMedium))
                    .foregroundStyle(.hiveMist)
                Text(group.space.name.isEmpty ? "Untitled" : group.space.name)
                    .font(HiveTypography.font(.caption1Medium))
                    .foregroundStyle(.hiveMist)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            ForEach(Array(group.sections.enumerated()), id: \.offset) { _, section in
                TabSearchSectionView(
                    section: section,
                    tabIndexMap: tabIndexMap,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect,
                    onSelectHover: onSelectHover
                )
            }
        }
    }
}

// MARK: - TabSearchSectionView

private struct TabSearchSectionView: View {
    let section: TabSearchSection
    let tabIndexMap: [String: Int]
    let selectedIndex: Int
    let onSelect: (BrowserTab) -> Void
    let onSelectHover: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = section.title {
                Text(title)
                    .font(HiveTypography.font(.caption3Semibold))
                    .foregroundStyle(.hiveGraphite)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)
            }

            ForEach(section.tabs) { tab in
                let idx = tabIndexMap[tab.id] ?? -1
                TabSearchRowView(
                    tab: tab,
                    isSelected: selectedIndex == idx,
                    onSelect: { onSelect(tab) },
                    onSelectHover: { idx in
                        if let idx { onSelectHover(idx) }
                    },
                    tabIndex: idx
                )
                .id(tab.id)
                .contentShape(Rectangle())
            }
        }
    }
}

// MARK: - Safe array access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
