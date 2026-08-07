import SwiftUI
import HiveCore

// MARK: - CommandPaletteView
//
// A centered, searchable command surface triggered by ⌘K. It filters the typed command
// catalog from `CommandRegistry`, plus open tabs, bookmarks, history, and spaces. Results
// are grouped by source, scored with fuzzy matching + usage learning, and keyboard
// navigable with arrow keys and Enter.

struct CommandPaletteView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var query = ""
    @State private var selectedID: String?
    @State private var usageCounts: [String: Int] = [:]
    @FocusState private var isSearchFocused: Bool

    // MARK: Search

    private var sections: [CommandPaletteEngine.Section] {
        CommandPaletteEngine.search(
            query: query,
            state: state,
            usageCounts: usageCounts
        )
    }

    private var flatResults: [CommandPaletteEngine.ScoredResult] {
        sections.flatMap { $0.results }
    }

    var body: some View {
        ZStack {
            // Dim the chrome and content behind the palette.
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Centered palette card.
            VStack(spacing: 0) {
                searchField
                    .padding(HiveSpacing.s12)

                Divider().overlay(Color.hiveBorderSubtle)

                quickActionChips

                if sections.isEmpty || flatResults.isEmpty {
                    emptyState
                } else {
                    listBody
                }
            }
            .hiveSurface(.activeOverlay)
            .frame(width: 560, height: 420)
            .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 12)
            // Raycast/Dia-class entrance: the card scales in from the top edge while the
            // backdrop (BrowserWindow) fades in behind it. The same value drives open and
            // close, so the palette shrinks back up as it dismisses.
            .scaleEffect(state.isCommandPaletteOpened ? 1 : 0.97, anchor: .top)
            .offset(y: state.isCommandPaletteOpened ? 0 : -8)
            .animation(.hiveMicro, value: state.isCommandPaletteOpened)
        }
        .onAppear {
            // Pre-fill from omnibar > prefix if present.
            if let prefilled = state.pendingCommandText {
                state.pendingCommandText = nil
                query = prefilled
            }
            selectedID = flatResults.first?.id
            isSearchFocused = true
        }
        .onChange(of: query) { _, _ in
            selectedID = flatResults.first?.id
        }
    }

    // MARK: Search field

    private var searchField: some View {
        HStack(spacing: HiveSpacing.s8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.hiveGraphite)
            TextField("Search commands, tabs, bookmarks, history…", text: $query)
                .hiveType(.body)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onKeyPress(.upArrow) { selectPrevious(); return .handled }
                .onKeyPress(.downArrow) { selectNext(); return .handled }
                .onKeyPress(.return) { executeSelected(); return .handled }
                .onKeyPress(.escape) { dismiss(); return .handled }
            if !query.isEmpty {
                Button("Clear") { query = "" }
                    .buttonStyle(.plain)
                    .foregroundStyle(.hiveGraphite)
            }
        }
        .padding(.horizontal, HiveSpacing.s8)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r6)
                .fill(Color.hiveSurface.opacity(isSearchFocused ? 1.0 : 0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r6)
                .stroke(isSearchFocused ? state.activeAccentColor.opacity(0.30) : Color.hiveBorder,
                        lineWidth: 1)
        )
        .animation(.hiveMicro, value: isSearchFocused)
    }

    // MARK: Quick-action chips

    private var quickActionChips: some View {
        let actions = [
            ("New Tab", "plus", BrowserCommand.newTab),
            ("Private", "plus.square", BrowserCommand.newPrivateTab),
            ("Omnibar", "magnifyingglass", BrowserCommand.focusOmnibar),
            ("Reader", "doc.text", BrowserCommand.toggleReaderMode),
            ("Capture", "doc.text.magnifyingglass", BrowserCommand.capturePage),
            ("Swarm", "bubble.left", BrowserCommand.toggleSwarm)
        ]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HiveSpacing.s8) {
                ForEach(actions, id: \.2) { title, icon, command in
                    Button(action: { executeCommand(command) }) {
                        HStack(spacing: HiveSpacing.s4) {
                            Image(systemName: icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(title)
                                .hiveType(.caption1)
                        }
                        .foregroundStyle(.hiveInk)
                        .padding(.horizontal, HiveSpacing.s8)
                        .padding(.vertical, HiveSpacing.s4)
                        .background(Color.hiveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r6))
                        .overlay(
                            RoundedRectangle(cornerRadius: HiveRadius.r6)
                                .stroke(Color.hiveBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s8)
        }
    }

    // MARK: List

    private var listBody: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(sections) { section in
                    Section(header: sectionHeader(section.section)) {
                        ForEach(section.results) { scored in
                            resultRow(scored.result)
                                .id(scored.id)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { execute(scored.result) }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .onChange(of: selectedID) { _, newValue in
                if let newValue { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    private func sectionHeader(_ section: PaletteSection) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.hiveBorderSubtle).padding(.horizontal, HiveSpacing.s12)
            Text(section.displayName)
                .hiveType(.caption1)
                .foregroundStyle(.hiveMist)
                .padding(.horizontal, HiveSpacing.s12)
                .padding(.top, HiveSpacing.s8)
                .padding(.bottom, HiveSpacing.s4)
        }
    }

    private func resultRow(_ result: PaletteResult) -> some View {
        let isSelected = selectedID == result.id
        return HStack(spacing: HiveSpacing.s8) {
            resultIcon(result)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .hiveType(.chromeTitle)
                    .foregroundStyle(.hiveInk)
                    .lineLimit(1)
                Text(result.subtitle)
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveGraphite)
                    .lineLimit(1)
            }
            Spacer()
            resultTrailingContent(result)
        }
        .padding(.horizontal, HiveSpacing.s12)
        .padding(.vertical, HiveSpacing.s4)
        .background(isSelected ? Color.hiveSurface : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r6))
        .padding(.horizontal, HiveSpacing.s4)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .onHover { hovering in
            if hovering { selectedID = result.id }
        }
    }

    @ViewBuilder
    private func resultIcon(_ result: PaletteResult) -> some View {
        switch result {
        case .tab(let tab):
            if let fav = tab.faviconURL {
                FaviconView(url: fav)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r3))
            } else {
                Image(systemName: "globe")
                    .font(HiveTypography.font(.bodySmall))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: 22, height: 22)
            }
        case .bookmark(let bookmark):
            if let fav = bookmark.faviconURL {
                FaviconView(url: fav)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r3))
            } else {
                Image(systemName: "book.bookmark")
                    .font(HiveTypography.font(.bodySmall))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: 22, height: 22)
            }
        default:
            Image(systemName: result.iconName)
                .font(HiveTypography.font(.bodySmall))
                .foregroundStyle(.hiveGraphite)
                .frame(width: 22, height: 22)
        }
    }

    @ViewBuilder
    private func resultTrailingContent(_ result: PaletteResult) -> some View {
        switch result {
        case .command(let cmd):
            if let shortcut = cmd.shortcut {
                shortcutBadge(shortcut)
            }
        case .space(let space):
            if let idx = state.spaces.firstIndex(where: { $0.id == space.id }), idx < 9 {
                shortcutBadge(.init(key: String(idx + 1), modifiers: [.command, .option]))
            } else if let badge = result.badge {
                textBadge(badge)
            }
        default:
            if let badge = result.badge {
                textBadge(badge)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.s8) {
            Text("No matching results")
                .hiveType(.body)
                .foregroundStyle(.hiveGraphite)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HiveSpacing.s24)
    }

    // MARK: - Selection + execution

    private func selectNext() {
        guard let selectedID else { return }
        let ids = flatResults.map { $0.id }
        guard let idx = ids.firstIndex(of: selectedID) else { return }
        let next = (idx + 1) % ids.count
        self.selectedID = ids[next]
    }

    private func selectPrevious() {
        guard let selectedID else { return }
        let ids = flatResults.map { $0.id }
        guard let idx = ids.firstIndex(of: selectedID) else { return }
        let prev = (idx - 1 + ids.count) % ids.count
        self.selectedID = ids[prev]
    }

    private func executeSelected() {
        guard let selectedID,
              let result = flatResults.first(where: { $0.id == selectedID })?.result else { return }
        execute(result)
    }

    private func execute(_ result: PaletteResult) {
        bumpUsage(for: result)
        switch result {
        case .command(let cmd):
            state.executeCommand(cmd.id)
        case .tab(let tab):
            state.selectTab(tab.id)
        case .bookmark(let bookmark):
            if let url = bookmark.url {
                state.newTab(url: url)
            }
        case .history(let entry):
            state.navigateActive(to: entry.url)
        case .space(let space):
            state.switchSpace(to: space.id)
        case .fallback(let kind, _, _, _):
            switch kind {
            case .openURL(let url):
                state.newTab(url: url)
            case .searchWeb(let q):
                state.newTab(url: searchURL(for: q))
            case .askSwarm(let q):
                state.openSwarmWithQuery(q)
            case .searchHistory(let q):
                state.openCommandWithText(q)
            }
        }
        dismiss()
    }

    private func executeCommand(_ command: BrowserCommand) {
        state.executeCommand(command)
        dismiss()
    }

    private func bumpUsage(for result: PaletteResult) {
        usageCounts[result.actionID, default: 0] += 1
    }

    private func searchURL(for query: String) -> URL {
        let engine = SearchEngineKind.resolve(state.prefs.defaultSearchEngine)
        return SearchEngine.searchURL(for: query, engine: engine) ?? URL(string: "about:blank")!
    }

    private func dismiss() {
        state.isCommandPaletteOpened = false
        query = ""
    }

    // MARK: - Helpers

    private func textBadge(_ text: String) -> some View {
        Text(text)
            .hiveType(.caption2)
            .foregroundStyle(.hiveGraphite)
            .padding(.horizontal, HiveSpacing.s8)
            .padding(.vertical, 2)
            .background(Color.hiveSurface)
            .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r4))
    }

    private func shortcutBadge(_ shortcut: KeyboardShortcutDescriptor) -> some View {
        HStack(spacing: 2) {
            ForEach(shortcut.modifiers, id: \.self) { mod in
                Text(shortcutSymbol(for: mod))
                    .font(HiveTypography.font(.caption1Medium))
            }
            Text(shortcut.key.uppercased())
                .font(HiveTypography.font(.caption1Medium))
        }
        .padding(.horizontal, HiveSpacing.s8)
        .padding(.vertical, 2)
        .background(Color.hiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r4))
    }

    private func shortcutSymbol(for modifier: ShortcutModifier) -> String {
        switch modifier {
        case .command: return "⌘"
        case .shift:   return "⇧"
        case .option:  return "⌥"
        case .control: return "⌃"
        }
    }
}
