import SwiftUI
import HiveCore

// MARK: - TabOverviewView (⌘⇧O)
//
// The §6 "find tabs" surface — a full-screen dark overlay showing every open tab as a
// tile in a scrollable grid. This is the primary navigation surface once the tab strip
// exceeds ~12 tabs (#1 friction fix per the Chang/Kittur academic research).
//
// v1 scope: open-tab grid (active space only) — favicon + title + host on a styled
// card, search field at top, arrow-key navigation + Enter to select, Esc to dismiss.
// Future slices add snapshots, Honeycomb matches, and archived-tab tiers.

struct TabOverviewView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 224, maximum: 320), spacing: HiveSpacing.s12)
    ]

    private var filteredTabs: [BrowserTab] {
        let visible = state.visibleTabs
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return visible }
        let lower = q.lowercased()
        return visible.filter {
            $0.displayTitle.lowercased().contains(lower)
                || ($0.url?.absoluteString.lowercased().contains(lower) ?? false)
                || ($0.promise?.lowercased().contains(lower) ?? false)
        }
    }

    private var safeIndex: Int {
        let cnt = filteredTabs.count
        guard cnt > 0 else { return 0 }
        return min(max(0, selectedIndex), cnt - 1)
    }

    var body: some View {
        ZStack {
            // Dark translucent backdrop — tapping it dismisses the overview.
            Color.hiveBackground.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, HiveSpacing.s24)
                    .padding(.top, HiveSpacing.s24)

                grid
                    .padding(.top, HiveSpacing.s16)
                    .padding(.horizontal, HiveSpacing.s16)

                Spacer(minLength: 0)
            }
            .padding(.bottom, HiveSpacing.s24)
        }
        .opacity(state.isTabOverviewOpened ? 1 : 0)
        .allowsHitTesting(state.isTabOverviewOpened)
        .animation(reduceMotion ? nil : .hiveMicro, value: state.isTabOverviewOpened)
        .onAppear { reset() }
        .onChange(of: searchText) { selectedIndex = 0 }
        .onChange(of: state.isTabOverviewOpened) { _, opened in
            if opened { isSearchFocused = true } else { searchText = "" }
        }
    }

    // MARK: - Header (search field + status line)

    private var header: some View {
        VStack(spacing: HiveSpacing.s8) {
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.hiveGraphite)
                TextField("Search open tabs…", text: $searchText)
                    .textFieldStyle(.plain)
                    .hiveType(.body)
                    .foregroundStyle(.hiveInk)
                    .focused($isSearchFocused)
                    .onKeyPress(.escape) { dismiss(); return .handled }
                    .onKeyPress(.return) { selectCurrent(); return .handled }
                    .onKeyPress(.downArrow) { nudgeSelection(+1); return .handled }
                    .onKeyPress(.upArrow) { nudgeSelection(-1); return .handled }
            }
            .padding(HiveSpacing.s12)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(Color.hiveSurfaceElevated)
            )

            HStack {
                let cnt = filteredTabs.count
                Text("\(cnt) \(cnt == 1 ? "tab" : "tabs")")
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveGraphite)
                Spacer()
                Text("Esc to dismiss · Enter to select")
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveGraphite.opacity(0.7))
            }
        }
        .padding(.bottom, HiveSpacing.s16)
    }

    // MARK: - Grid

    private var grid: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                let tiles = filteredTabs
                if tiles.isEmpty {
                    VStack(spacing: HiveSpacing.s8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.hiveMist)
                        Text(searchText.isEmpty
                             ? "No tabs open" : "No tabs match \"\(searchText)\"")
                            .hiveType(.bodySmall)
                            .foregroundStyle(.hiveGraphite)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    LazyVGrid(columns: columns, spacing: HiveSpacing.s12) {
                        ForEach(Array(tiles.enumerated()), id: \.element.id) { idx, tab in
                            TabOverviewCard(
                                tab: tab,
                                highlight: idx == safeIndex,
                                onSelect: { navigateTo(tab.id) }
                            )
                            .id("tok_\(tab.id)")
                            .overlay(
                                idx == safeIndex
                                    ? RoundedRectangle(cornerRadius: HiveRadius.r12)
                                        .stroke(state.activeAccentColor, lineWidth: 2)
                                    : nil
                            )
                            .onTapGesture { navigateTo(tab.id) }
                        }
                    }
                    .padding(.vertical, HiveSpacing.s8)
                }
                archiveSection
            }
            .onChange(of: safeIndex) { _, new in
                let tiles = filteredTabs
                guard !tiles.isEmpty, new < tiles.count else { return }
                withAnimation(reduceMotion ? nil : .hiveExpand) {
                    proxy.scrollTo("tok_\(tiles[new].id)", anchor: .center)
                }
            }
        }
    }

    // MARK: - Recently Archived (§7)

    private var archiveSection: some View {
        let records = state.archivedTabs
        guard !records.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: HiveSpacing.s12) {
                Divider().padding(.vertical, HiveSpacing.s8)
                Text("Recently Archived")
                    .hiveType(.chromeTitle)
                    .foregroundStyle(.hiveGraphite)
                    .padding(.horizontal, HiveSpacing.s4)

                LazyVGrid(columns: columns, spacing: HiveSpacing.s12) {
                    ForEach(records.suffix(12)) { record in
                        VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                            Text(record.title.isEmpty ? (record.url?.host ?? "Untitled") : record.title)
                                .hiveType(.chromeTitle)
                                .foregroundStyle(.hiveGraphite)
                                .lineLimit(1)
                            Text(formatDate(record.archivedAt))
                                .hiveType(.chromeLabel)
                                .foregroundStyle(.hiveMist)
                        }
                        .padding(HiveSpacing.s12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.r8)
                                .fill(Color.hiveSurfaceElevated.opacity(0.5))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: HiveRadius.r8))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(record.title.isEmpty ? (record.url?.host ?? "Untitled") : record.title)
                        .accessibilityValue("Archived \(formatDate(record.archivedAt))")
                        .accessibilityHint("Restores this tab")
                        .accessibilityAction {
                            state.restoreArchivedTab(record.id).flatMap { state.selectTab($0.id) }
                            dismiss()
                        }
                        .onTapGesture {
                            state.restoreArchivedTab(record.id).flatMap { state.selectTab($0.id) }
                            dismiss()
                        }
                    }
                }
            }
            .padding(.horizontal, HiveSpacing.s4)
        )
    }

    /// Shared formatter — RelativeDateTimeFormatter construction is expensive and the
    /// archived grid calls this per cell; cache it on the struct (same pattern as the
    /// StartPage date formatter).
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Actions

    private func navigateTo(_ id: String) {
        state.selectTab(id)
        dismiss()
    }

    private func dismiss() {
        state.isTabOverviewOpened = false
        searchText = ""
        selectedIndex = 0
    }

    private func selectCurrent() {
        let tiles = filteredTabs
        guard !tiles.isEmpty, safeIndex < tiles.count else { return }
        navigateTo(tiles[safeIndex].id)
    }

    private func nudgeSelection(_ delta: Int) {
        let tiles = filteredTabs
        guard !tiles.isEmpty else { return }
        selectedIndex = min(max(0, selectedIndex + delta), tiles.count - 1)
    }

    private func reset() {
        searchText = ""
        selectedIndex = 0
    }
}

// MARK: - TabOverviewCard

private struct TabOverviewCard: View {
    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tab: BrowserTab
    let highlight: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            // Top row: favicon + badges
            HStack(spacing: HiveSpacing.s4) {
                if let favURL = tab.faviconURL {
                    FaviconView(url: favURL)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "globe")
                        .font(HiveTypography.font(.caption2))
                        .foregroundStyle(.hiveGraphite)
                        .frame(width: 20, height: 20)
                }
                if tab.isPinned {
                    Image(systemName: "pin.fill")
                        .font(HiveTypography.font(.microBold))
                        .foregroundStyle(state.activeAccentColor)
                }
                Spacer()
                if tab.isHibernated {
                    Image(systemName: "moon.zzz.fill")
                        .font(HiveTypography.font(.caption3))
                        .foregroundStyle(.hiveGraphite)
                }
            }

            // Title (max 2 lines)
            Text(tab.displayTitle)
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Host
            if let host = tab.url?.host {
                Text(host)
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveGraphite)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("New Tab")
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveMist)
            }
        }
        .padding(HiveSpacing.s16)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
                .fill(cardFill)
        )
        .shadow(color: .black.opacity(isHovered ? 0.10 : 0.06),
                radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered && !reduceMotion ? 1.02 : 1.0)
        .animation(reduceMotion ? nil : .hiveMicro, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tab.displayTitle.isEmpty ? "Untitled tab" : tab.displayTitle)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Press Return to switch to this tab")
        .accessibilityAddTraits(highlight ? .isSelected : [])
        .accessibilityAction { onSelect() }
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if let host = tab.url?.host, !host.isEmpty { parts.append(host) }
        if tab.isPinned { parts.append("Pinned") }
        if tab.isHibernated { parts.append("Sleeping") }
        if tab.isPrivate { parts.append("Private") }
        if tab.isLoading { parts.append("Loading") }
        return parts.isEmpty ? "Open tab" : parts.joined(separator: ", ")
    }

    /// Selected = accent wash; hovered = lifted wash; hovered+selected stacks so hover
    /// still registers over the keyboard highlight; otherwise elevated surface.
    private var cardFill: Color {
        if highlight && isHovered { return state.activeAccentColor.opacity(0.12) }
        if highlight { return state.activeAccentColor.opacity(0.08) }
        if isHovered { return state.activeAccentColor.opacity(0.05) }
        return Color.hiveSurfaceElevated
    }
}