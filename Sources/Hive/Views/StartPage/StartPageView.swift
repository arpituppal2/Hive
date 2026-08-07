import SwiftUI
import HiveCore

// MARK: - StartPageView
//
// Chrome-verbatim new tab page (2026). Search centered at ~35% viewport, time-based
// greeting above, fixed 5-column top-sites grid (48×48 Chrome-style tiles), recent
// tabs and bookmarks in card rows below. No clutter — quick actions removed; Chrome
// doesn't show toolbar chips on its NTP and neither should Hive.
//
// Chrome NTP layout reference:
//   - Greeting + search centered at 35–40% from top
//   - Top sites: 5-column grid, 48×48 rounded tiles, 16px gap, favicon 24×24 inside
//   - No card borders on tiles — background only on hover
//   - Below: modular card rows (recent tabs, bookmarks)
//   - Animation: 200ms ease-in section fade (Chrome MD3 timing)

struct StartPageView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var topSites: [TopSite] = []
    @State private var hasAppeared = false
    @State private var searchHovered = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    /// Shared formatter — DateFormatter construction is expensive and this view's
    /// body re-evaluates on hover/tab changes; cache it per struct (Apple guidance).
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    /// Full date readout under the greeting — "Monday, August 5". The premium-NTP
    /// touch Chrome/Arc/Dia all use: large greeting + subtle date, not two large
    /// lines competing for attention.
    private var fullDate: String {
        Self.dateFormatter.string(from: Date())
    }

    private var hasAnyContent: Bool {
        !topSites.isEmpty || !state.tabs.filter({ $0.url != nil }).isEmpty
        || !state.rootBookmarks.filter({ !$0.isFolder }).isEmpty
        || state.spaces.count > 1
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: HiveSpacing.s24) {
                    // Push search to ~35% viewport (Chrome NTP centering)
                    Color.clear.frame(height: max(0, geo.size.height * 0.25))

                    greetingSection
                    searchSection

                    if !topSites.isEmpty {
                        topSitesSection
                            .chromeAppear(index: 1, reduceMotion: reduceMotion, hasAppeared: hasAppeared)
                    } else if !hasAnyContent {
                        Color.clear.frame(height: HiveSpacing.s16)
                    }

                    recentTabsSection
                        .chromeAppear(index: 2, reduceMotion: reduceMotion, hasAppeared: hasAppeared)

                    bookmarksSection
                        .chromeAppear(index: 3, reduceMotion: reduceMotion, hasAppeared: hasAppeared)

                    spacesSection
                        .chromeAppear(index: 4, reduceMotion: reduceMotion, hasAppeared: hasAppeared)

                    swarmEntry
                        .chromeAppear(index: 5, reduceMotion: reduceMotion, hasAppeared: hasAppeared)
                        .padding(.bottom, HiveSpacing.s48)
                }
                .padding(.horizontal, HiveSpacing.s64)
                .frame(maxWidth: 720, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: geo.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hiveBackground)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.20)) { hasAppeared = true }
            computeTopSites()
        }
    }

    // MARK: - Greeting (Chrome-style time-based)

    private var greetingSection: some View {
        VStack(spacing: HiveSpacing.s8) {
            Text(greeting)
                .hiveType(.display1)
                .foregroundStyle(.hiveInk)
            Text(fullDate)
                .hiveType(.bodySmall)
                .foregroundStyle(.hiveGraphite.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting), \(fullDate)")
    }

    // MARK: - Search (centered, Chrome-style)

    private var searchSection: some View {
        Button(action: { state.focusOmnibar() }) {
            HStack(spacing: HiveSpacing.s12) {
                Image(systemName: "magnifyingglass")
                    .font(HiveTypography.font(.panelTitleRegular))
                    .foregroundStyle(.hiveGraphite)

                Text("Search or enter address")
                    .hiveType(.body)
                    .foregroundStyle(.hiveGraphite)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "command")
                        .font(HiveTypography.font(.microMedium))
                    Text("L")
                        .font(HiveTypography.font(.caption3Semibold))
                }
                .foregroundStyle(.hiveMist)
                .padding(.horizontal, HiveSpacing.s4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.r4)
                        .fill(Color.hiveSurface.opacity(0.6))
                )
            }
            .padding(.horizontal, HiveSpacing.s16)
            .padding(.vertical, HiveSpacing.s12)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(Color.hiveSurface.opacity(searchHovered ? 0.9 : 0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: HiveRadius.r8)
                            .stroke(
                                searchHovered ? Color.hiveAccent.opacity(0.35) : Color.hiveBorderSubtle,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: .black.opacity(searchHovered ? 0.10 : 0),
                        radius: searchHovered ? 12 : 0,
                        x: 0, y: searchHovered ? 4 : 0
                    )
            )
        }
        .buttonStyle(HiveCardButtonStyle())
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .hiveMicro) { searchHovered = hovering }
        }
        .accessibilityLabel("Search or enter address")
        .accessibilityHint("Focuses the address bar")
    }

    // MARK: - Top sites (Chrome-style: 5-column fixed grid, 48px tiles)

    private var topSitesSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            HStack {
                Text("Top Sites")
                    .hiveType(.chromeButton)
                    .foregroundStyle(.hiveInk.opacity(0.75))
                Spacer()
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(72), spacing: HiveSpacing.s8), count: 5),
                spacing: HiveSpacing.s8
            ) {
                ForEach(topSites.prefix(10)) { site in
                    TopSiteTileView(site: site)
                }
            }
        }
    }

    // MARK: - Recent tabs

    @ViewBuilder private var recentTabsSection: some View {
        let recent = Array(state.tabs
            .filter { $0.url != nil }
            .sorted { $0.lastVisitedAt > $1.lastVisitedAt }
            .prefix(6))

        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                HStack {
                    Text("Recent Tabs")
                        .hiveType(.chromeButton)
                        .foregroundStyle(.hiveInk.opacity(0.75))
                    Spacer()
                }
                VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                    ForEach(recent) { tab in
                        HomeListRow(
                            title: tab.displayTitle.isEmpty ? (tab.url?.host ?? "Untitled") : tab.displayTitle,
                            subtitle: tab.url?.host ?? "",
                            action: { state.selectTab(tab.id) }
                        ) {
                            if let url = tab.url {
                                faviconFor(url.absoluteString, size: HiveDimension.favicon)
                            } else {
                                Image(systemName: "globe")
                                    .foregroundStyle(.hiveGraphite)
                                    .frame(width: HiveDimension.favicon, height: HiveDimension.favicon)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bookmarks

    @ViewBuilder private var bookmarksSection: some View {
        let root = state.rootBookmarks
            .filter { !$0.isFolder }
            .prefix(6)

        if !root.isEmpty {
            VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                HStack {
                    Text("Bookmarks")
                        .hiveType(.chromeButton)
                        .foregroundStyle(.hiveInk.opacity(0.75))
                    Spacer()
                }
                VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                    ForEach(Array(root)) { bookmark in
                        HomeListRow(
                            title: bookmark.title,
                            subtitle: bookmark.host,
                            action: {
                                if let url = bookmark.url {
                                    state.newTab(url: url)
                                }
                            }
                        ) {
                            if let url = bookmark.url {
                                faviconFor(url.absoluteString, size: HiveDimension.favicon)
                            } else {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(.hiveGraphite)
                                    .frame(width: HiveDimension.favicon, height: HiveDimension.favicon)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Spaces

    @ViewBuilder private var spacesSection: some View {
        if state.spaces.count > 1 {
            VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                HStack {
                    Text("Spaces")
                        .hiveType(.chromeButton)
                        .foregroundStyle(.hiveInk.opacity(0.75))
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: HiveSpacing.s8) {
                        ForEach(state.spaces) { space in
                            SpaceCard(space: space)
                        }
                        newSpaceButton
                    }
                }
            }
        }
    }

    private var newSpaceButton: some View {
        Button(action: { state.newSpace() }) {
            VStack(spacing: HiveSpacing.s4) {
                Image(systemName: "plus")
                    .font(HiveTypography.font(.dialogTitle))
                    .foregroundStyle(.hiveGraphite)
                Text("New")
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveGraphite)
            }
            .frame(width: 72, height: 72)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .stroke(Color.hiveBorderSubtle, style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .buttonStyle(ScalePressButtonStyle())
        .accessibilityLabel("New space")
    }

    // MARK: - Optional Swarm entry (subtle footer)

    private var swarmEntry: some View {
        Button(action: { state.toggleSwarm() }) {
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(HiveTypography.font(.caption1Medium))
                    .foregroundStyle(.hiveGraphite)
                Text("Ask Swarm")
                    .hiveType(.caption1)
                    .foregroundStyle(.hiveGraphite)
                HStack(spacing: 2) {
                    Image(systemName: "command")
                        .font(HiveTypography.font(.microTinyMedium))
                    Image(systemName: "shift")
                        .font(HiveTypography.font(.microTinyMedium))
                    Image(systemName: "space")
                        .font(HiveTypography.font(.microTinyMedium))
                }
                .foregroundStyle(.hiveMist)
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(Color.hiveSurface.opacity(0.25))
            )
        }
        .buttonStyle(ScalePressButtonStyle())
        .help("Open Swarm (⌘⇧Space)")
    }

    // MARK: - Helpers

    private func computeTopSites() {
        let history = state.prefs.historyEntries
        var counts: [URL: Int] = [:]
        for entry in history {
            counts[entry.url, default: 0] += 1
        }
        let sorted = counts.sorted { $0.value > $1.value }.map { $0.key }
        topSites = sorted.prefix(8).map { TopSite(url: $0) }
    }
}

// MARK: - TopSite

private struct TopSite: Identifiable {
    let id = UUID().uuidString
    let url: URL

    var displayTitle: String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
    }
}

// MARK: - TopSiteTileView
//
// Chrome-verbatim NTP tile: a 48×48 rounded icon container whose fill strengthens on
// hover (Chrome paints the tile background only on hover), with a subtle lift + spring
// scale. The label stays fixed-width so the 5-column grid never reflows on hover.

private struct TopSiteTileView: View {
    let site: TopSite
    @Environment(ChromeState.self) private var state
    @State private var isHovered = false

    var body: some View {
        Button {
            state.newTab(url: site.url)
        } label: {
            VStack(spacing: HiveSpacing.s4) {
                faviconFor(site.url.absoluteString, size: 24)
                    .frame(width: 24, height: 24)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.r8)
                            .fill(Color.hiveSurface.opacity(isHovered ? 0.55 : 0.35))
                    )
                Text(site.displayTitle)
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveGraphite)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 72)
            }
            .frame(width: 72)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.hiveMicro, value: isHovered)
        }
        .buttonStyle(ScalePressButtonStyle())
        .onHover { isHovered = $0 }
        .help(site.url.absoluteString)
    }
}

// MARK: - HomeListRow

private struct HomeListRow<Icon: View>: View {
    let title: String
    let subtitle: String
    let action: () -> Void
    let icon: Icon
    @State private var isHovered = false

    init(title: String, subtitle: String, action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.icon = icon()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: HiveSpacing.s8) {
                icon
                    .frame(width: HiveDimension.favicon, height: HiveDimension.favicon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .hiveType(.chromeTitle)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(subtitle)
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveGraphite)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(HiveTypography.font(.caption3Medium))
                    .foregroundStyle(.hiveMist.opacity(isHovered ? 1 : 0.5))
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(Color.hiveSurface.opacity(isHovered ? 0.6 : 0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .stroke(Color.hiveBorderSubtle, lineWidth: 1)
            )
            .animation(.hiveMicro, value: isHovered)
        }
        .buttonStyle(ScalePressButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("Open \(title)")
    }
}

// MARK: - SpaceCard

private struct SpaceCard: View {
    let space: Space
    @Environment(ChromeState.self) private var state
    @State private var isHovered = false

    var body: some View {
        let isActive = space.id == state.activeSpace.id
        let accent = Color(HiveColorToken(rawValue: space.accentTokenName) ?? .accent)
        Button { state.switchSpace(to: space.id) } label: {
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: space.iconName)
                    .font(HiveTypography.font(.sectionTitle))
                    .foregroundStyle(isActive ? accent : Color.hiveGraphite)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.r6)
                            .fill(isActive ? accent.opacity(0.18) : Color.clear)
                    )
                Text(space.name)
                    .hiveType(.chromeTitle)
                    .foregroundStyle(isActive ? Color.hiveInk : Color.hiveGraphite)
                    .lineLimit(1)
            }
            .padding(.horizontal, HiveSpacing.s8)
            .padding(.vertical, HiveSpacing.s8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(isActive ? Color.hiveSurface.opacity(0.8) : Color.hiveSurface.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .stroke(isActive ? Color.hiveBorder : Color.hiveBorderSubtle, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .offset(y: isHovered ? -2 : 0)
            .shadow(color: .black.opacity(isHovered ? 0.10 : 0), radius: isHovered ? 8 : 0, y: isHovered ? 4 : 0)
            .animation(.hiveMicro, value: isHovered)
        }
        .buttonStyle(ScalePressButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("Switch to space \(space.name)")
    }
}

// MARK: - Favicon helper

@ViewBuilder
private func faviconFor(_ urlString: String, size: CGFloat) -> some View {
    if let url = URL(string: urlString), let faviconURL = faviconURL(for: url) {
        FaviconView(url: faviconURL)
            .frame(width: size, height: size)
    } else {
        Image(systemName: "globe")
            .font(.system(size: min(size, 18), weight: .regular))
            .foregroundStyle(.hiveGraphite.opacity(0.6))
            .frame(width: size, height: size)
    }
}

private func faviconURL(for url: URL) -> URL? {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true),
          components.host != nil else { return nil }
    components.path = "/favicon.ico"
    components.query = nil
    components.fragment = nil
    return components.url
}

// MARK: - Chrome appear (200ms ease-in, Chrome MD3 timing)

private struct ChromeAppearModifier: ViewModifier {
    let index: Int
    let reduceMotion: Bool
    let hasAppeared: Bool

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (hasAppeared ? 0 : 8))
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.20)
                    .delay(Double(index) * 0.05),
                value: hasAppeared
            )
    }
}

private extension View {
    func chromeAppear(index: Int, reduceMotion: Bool, hasAppeared: Bool) -> some View {
        modifier(ChromeAppearModifier(index: index, reduceMotion: reduceMotion, hasAppeared: hasAppeared))
    }
}

// MARK: - Button styles

private struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct HiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.995 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: configuration.isPressed)
    }
}


