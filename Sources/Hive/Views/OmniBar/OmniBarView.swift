import SwiftUI
import AppKit
import HiveCore

// MARK: - OmniBarView
//
// The 34pt address/search bar (Chrome verbatim §10.1). Bound to `ChromeState`: it shows the
// active tab's URL while unfocused, lets the user type a query or URL, and on Enter resolves
// the input via `OmnibarInput.resolveURL(for:)` and navigates the active tab.
//
// Chrome verbatim invariants:
//   - Height 34pt; input field 26pt, r4 machined corners (Chrome address bar: 4px).
//   - Background `surface` @ 80% → `surface` @ 100% on focus.
//   - Border `borderSubtle` → `accent` @ 30% on focus.
//   - Mode selector on leading edge (Search/URL/Swarm/Command) — auto-detects while typing.
//   - Security indicator (lock) on trailing edge: green HTTPS / amber mixed / red HTTP.
//
// "Instantly usable": Enter resolves, never telemetries keystrokes anywhere. Suggestions are
// local-only (history/bookmarks); the field works fully without them.

struct OmniBarView: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(ChromeState.self) private var state

    /// The tab whose URL this bar shows. Defaults to the active tab.
    var tabID: String? { state.activeTabID }

    /// Drives focus so the window can ⌘L-select-all via @FocusState.
    @FocusState private var isFocused: Bool

    /// Raw text being typed. Cleared/reseeded from the active tab's URL on tab switch.
    @State private var typed: String = ""
    @State private var showSuggestions = false
    private let fieldID = "hive-omnibar"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: HiveSpacing.s8) {
                // ← → ↻ — the navigation cluster at the leading edge. This is THE browser
                // silhouette anchor every browser puts leftmost (Chrome, Safari, Arc, Zen,
                // Brave, Dia, Comet). Hive had it inverted: only `🔍` here, with `↻` buried
                // among 7 trailing icons. See PITCH/browser-feel-fixes.md Wave 3.
                HStack(spacing: HiveSpacing.s4) {
                    navCluster
                    reloadButton
                }
                modeIndicator
                field
                trailing
            }
            if showSuggestions {
                OmnibarSuggestionsView(
                    query: typed,
                    history: state.prefs.historyEntries,
                    bookmarks: state.prefs.bookmarks,
                    onSelect: { url in
                        state.navigateActive(to: url)
                        typed = url.absoluteString
                        isFocused = false
                        showSuggestions = false
                    },
                    onSelectBackground: { url in
                        // Chrome verbatim: ⌘⏎ opens in a background tab; the current page
                        // stays frontmost and the omnibox keeps its text (dropdown closes).
                        state.newBackgroundTab(url: url)
                        showSuggestions = false
                    },
                    searchEngine: SearchEngineKind.resolve(state.prefs.defaultSearchEngine)
                )
                .padding(.top, 4)
                // Chrome-class dropdown: slides down from the bar on open, fades out on close.
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, HiveSpacing.s8)
        .frame(height: HiveDimension.omnibarH)
        .background(fieldBackground)
        .overlay(alignment: .bottom) { loadProgressBar }
        .animation(.hiveMicro, value: isFocused)
        .animation(.hiveMicro, value: currentMode)
        .animation(.hiveMicro, value: showSuggestions)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Address bar")
        .accessibilityValue(typed.isEmpty ? (activeTab?.url?.absoluteString ?? "") : typed)
    }

    /// Amber page-load progress line under the omnibar — the browser-feel affordance
    /// every browser ships. `loadProgress` (0..1) is reported by `WebViewContainer` from
    /// `webView.estimatedProgress` and stored on the tab by `ChromeState`; this renders
    /// it where it belongs. Safari-style: a 2pt amber line at the bar's bottom edge that
    /// fills left→right while loading and fades out when done. Amber (state.activeAccentColor)
    /// honors the locked palette; this reintroduces the bar that "Brand Guidelines v1.0"
    /// had removed in favor of a hexagon *pulse* alone — the pulse is deliberately kept
    /// (dual signal), but the progress bar is what makes it read as a browser. quietly,
    /// it also satisfies SPEC §29.2 rule-1 (progress bar, not a chrome spinner).
    private var loadProgressBar: some View {
        GeometryReader { geo in
            let loading = activeTab?.isLoading ?? false
            let progress = loading ? max(0.05, activeTab?.loadProgress ?? 0) : 0
            state.activeAccentColor
                .frame(width: geo.size.width * progress, height: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(loading ? 1 : 0)
        }
        .frame(height: 2)
        .allowsHitTesting(false)
        .animation(.hiveMicro, value: activeTab?.loadProgress)
        .animation(.hiveMicro, value: activeTab?.isLoading)
        .accessibilityHidden(true)
    }

    // MARK: Field

    private var field: some View {
        // A transparent TextField over a custom background/placeholder pair, so the field
        // gets standard text behavior + ⌘L select-all while the chrome controls the look.
        ZStack(alignment: .leading) {
            placeholderView
            inputField
        }
        .padding(.horizontal, HiveSpacing.s12)
        .background(fieldFill)
        .overlay(fieldBorder)
        .contentShape(shape)
        .onTapGesture { isFocused = true }
        .onChange(of: state.activeTabID) { _, _ in reseedFromTab() }
        .onChange(of: activeTab?.url) { _, _ in if !isFocused { reseedFromTab() } }
        .onChange(of: state.focusRequest) { _, _ in
            // ⌘L → focus the field + select-all (kills whole URL) for instant retyping.
            isFocused = true
            selectAll()
        }
        .onAppear { reseedFromTab() }
        .onChange(of: typed) { _, newValue in
            showSuggestions = newValue.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && isFocused
        }
    }

    /// Selects the entire field text (⌘L behavior: focus + select-all like Safari/Chrome).
    ///
    /// SwiftUI's `TextField` has no first-class select-all, but once it is the window's
    /// first responder (the runloop after `isFocused = true`), the standard AppKit
    /// `selectAll:` action targets it — `NSText` is the shared superclass of NSTextField
    /// and NSTextView. Two async hops mount the field's responder before the selector is
    /// dispatched, so the whole URL highlights (ready to be retyped or replaced).
    private func selectAll() {
        DispatchQueue.main.async {
            isFocused = true
            DispatchQueue.main.async {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: HiveRadius.r4)  // Chrome verbatim: 4px machined address bar
    }

    @ViewBuilder private var placeholderView: some View {
        if typed.isEmpty && !isFocused {
            Text(placeholder)
                .foregroundStyle(.hiveMist)
                .hiveType(.bodySmall)
                .allowsHitTesting(false)
        }
    }

    private var inputField: some View {
        TextField("Address bar", text: $typed)
            .focused($isFocused)
            .submitLabel(.go)
            .hiveType(.bodySmall)
            .foregroundStyle(inputColor)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .onSubmit(submit)
            .frame(height: HiveDimension.omnibarInputH)
    }

    private var inputColor: Color {
        (activeTab?.isPrivate == true) ? Color(hiveMistFor(scheme)) : Color.hiveInk
    }

    private var fieldFill: some View {
        shape.fill(Color.hiveSurface.opacity(isFocused ? 1.0 : 0.8))
    }

    private var fieldBorder: some View {
        shape.strokeBorder(isFocused ? state.activeAccentColor.opacity(0.30) : Color.hiveBorderSubtle,
                           lineWidth: 1)
    }

    private var placeholder: String {
        // ⌘< showed the Swarm mode prefix is `@`; Command is `>`. Hint it faintly.
        "Search or enter address"
    }

    // MARK: Navigation cluster (leading — back / forward)

    /// ← → at the leading edge — THE browser silhouette anchor. Every browser puts
    /// back/forward leftmost (Chrome, Safari, Arc, Zen, Brave, Dia, Comet). Hive had
    /// none here: "back" lived only as a command-palette entry + the ⌘[/⌘] keyboard
    /// bindings in `HiveApp`. That's the single biggest reason the chrome didn't read
    /// as a browser. `canGoBack`/`canGoForward` (reported by `WebViewContainer`) gate
    /// the disabled state; `.disabled()` dims without a fading-visibility dance so the
    /// buttons keep a stable silhouette (no layout shift). ⌘[/⌘] remain bound in
    /// HiveApp — no keyboardShortcut here, to avoid a duplicate-binding conflict.
    private var navCluster: some View {
        HStack(spacing: HiveSpacing.s4) {
            Button {
                state.requestNav(.back)
            } label: {
                Image(systemName: "chevron.left")
                    .font(HiveTypography.font(.bodyMedium))
                    .foregroundStyle((activeTab?.canGoBack ?? false) ? Color.hiveInk : Color.hiveGraphite.opacity(0.35))
                    .frame(width: HiveSpacing.s24)
            }
            .buttonStyle(.plain)
            .disabled(!(activeTab?.canGoBack ?? false))
            .accessibilityLabel("Back")
            .help("Back (⌘[)")

            Button {
                state.requestNav(.forward)
            } label: {
                Image(systemName: "chevron.right")
                    .font(HiveTypography.font(.bodyMedium))
                    .foregroundStyle((activeTab?.canGoForward ?? false) ? Color.hiveInk : Color.hiveGraphite.opacity(0.35))
                    .frame(width: HiveSpacing.s24)
            }
            .buttonStyle(.plain)
            .disabled(!(activeTab?.canGoForward ?? false))
            .accessibilityLabel("Forward")
            .help("Forward (⌘])")
        }
    }

    // MARK: Mode indicator (leading)

    private var currentMode: OmnibarMode {
        OmnibarMode.detect(from: typed, baseURL: activeTab?.url)
    }

    private var modeIndicator: some View {
        Image(systemName: currentMode.icon)
            .font(HiveTypography.font(.bodyMedium))
            .foregroundStyle(currentMode == .command ? state.activeAccentColor : .hiveGraphite)
            .frame(width: HiveSpacing.s24, height: HiveDimension.omnibarInputH)
            .accessibilityHidden(true)
    }

    // MARK: Trailing (security + reload)

    @ViewBuilder private var trailing: some View {
        if !isFocused {
            HStack(spacing: HiveSpacing.s8) {
                securityIndicator
                // Always reserve 24pt for the hexagon to prevent layout shift when
                // loading starts/stops. The pulsing hexagon overlays this space.
                Color.clear
                    .frame(width: HiveSpacing.s24, height: HiveDimension.omnibarInputH)
                    .overlay(alignment: .trailing) {
                        if let tab = activeTab, tab.isLoading {
                            Image(systemName: "hexagon")
                                .font(HiveTypography.font(.caption3Medium))
                                .foregroundStyle(.hiveAccent)
                                .modifier(AmberPulseModifier())
                        }
                    }
                // Chrome-class download bubble — live progress ring over the icon while
                // anything is downloading; click opens the ⌘⇧J panel. (Chrome 2023+)
                DownloadBubbleIndicator()
                overflowMenu
            }
        }
    }

    /// Whether the site security panel (lock icon popover) is visible.
    @State private var showSecurityPanel = false

    @ViewBuilder private var securityIndicator: some View {
        HStack(spacing: HiveSpacing.s4) {
            if let s = activeTab, let url = s.url, let level = SecurityLevel(for: url) {
                Button {
                    showSecurityPanel.toggle()
                } label: {
                    Image(systemName: level.icon)
                        .font(HiveTypography.font(.captionMedium))
                        .foregroundStyle(level.color(scheme: scheme))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(level.accessibilityLabel)
                .popover(isPresented: $showSecurityPanel, arrowEdge: .top) {
                    SiteSecurityPanel(tab: s, onDismiss: { showSecurityPanel = false })
                }
            }
            // Blocked resource counter — shows how many trackers/ads were blocked on this page.
            if ContentBlockerController.shared.isActive, let tab = activeTab, tab.blockedCount > 0 {
                Text("\(tab.blockedCount)")
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveAccent)
                    .accessibilityLabel("\(tab.blockedCount) trackers blocked")
            }
            // Honeycomb capture button — the differentiator. One-click to remember this page.
            // Reader mode toggle — only visible when reader mode is active.
            if let tab = activeTab, tab.isReaderMode {
                Button {
                    state.toggleReaderMode()
                } label: {
                    Image(systemName: "text.justify")
                        .font(HiveTypography.font(.caption3Medium))
                        .foregroundStyle(.hiveAccent)
                }
                .buttonStyle(.plain)
                .help("Exit Reader Mode")
            }
            // Bookmark star — always visible when there's a URL (including private tabs).
            if let tab = activeTab, tab.url != nil, !tab.isHibernated {
                Button {
                    state.toggleBookmark()
                } label: {
                    Image(systemName: state.isActiveTabBookmarked ? "star.fill" : "star")
                        .font(HiveTypography.font(.caption3Medium))
                        .foregroundStyle(state.isActiveTabBookmarked ? .hiveAccent : .hiveGraphite)
                }
                .buttonStyle(.plain)
                .help(state.isActiveTabBookmarked ? "Remove Bookmark" : "Bookmark This Page")
            }
            // Honeycomb capture button — the differentiator. One-click to remember this page.
            if let tab = activeTab, !tab.isPrivate, !tab.isHibernated {
                Button {
                    state.captureActivePage()
                } label: {
                    Image(systemName: "hexagon")
                        .font(HiveTypography.font(.caption3Medium))
                        .foregroundStyle(.hiveAccent)
                }
                .buttonStyle(.plain)
                .help("Capture page to Hive")
            }
        }
    }

    /// Overflow menu — the "⋯" affordance every browser puts at the omnibar's trailing edge
    /// (Edge's "...", Chrome's ⋮, Safari's chevron.right). Declutters the bar so it reads as
    /// an address bar, not a 7-icon feature list. Holds the translate + librarian actions
    /// that previously each had their own always-visible button. Both are genuine features,
    /// but neither is part of the universal browser silhouette — so they live here, behind
    /// one tap, exactly like Edge/Chrome/Firefox file menus. See PITCH/browser-feel-fixes.md
    /// Wave 3.
    @ViewBuilder private var overflowMenu: some View {
        Menu {
            if let tab = activeTab, let url = tab.url, !tab.isPrivate, !tab.isHibernated {
                Button {
                    if let translateURL = URL(string: "https://translate.google.com/translate?sl=auto&tl=en&u=\(url.absoluteString)") {
                        state.newTab(url: translateURL)
                    }
                } label: {
                    Label("Translate Page", systemImage: "character.bubble")
                }
            }
            if !state.isSwarmOpen {
                Button {
                    state.toggleSwarm()
                } label: {
                    Label("Open Librarian", systemImage: "books.vertical")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(HiveTypography.font(.bodyMedium))
                .foregroundStyle(.hiveGraphite)
                .frame(width: HiveSpacing.s24)
        }
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("More page actions")
        .help("More page actions")
    }

    /// Reload ↔ Stop. While the active tab is loading, the icon is `stop` and the card
    /// action is `requestNav(.stop)` — the universal browser affordance: click-to-cancel
    /// a load without hunting for Esc. Otherwise it's `arrow.clockwise` reload. Safari,
    /// Chrome, Arc, Comet all do this; Hive was leaving it stuck on reload.
    private var reloadButton: some View {
        let loading = activeTab?.isLoading ?? false
        return Button {
            state.requestNav(loading ? .stop : .reload)
        } label: {
            Image(systemName: loading ? "xmark" : "arrow.clockwise")
                .font(HiveTypography.font(.bodyMedium))
                .foregroundStyle(loading ? state.activeAccentColor : .hiveGraphite)
                .frame(width: HiveSpacing.s24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loading ? "Stop loading" : "Reload page")
        .help(loading ? "Stop loading" : "Reload page (⌘R)")
    }

    // MARK: Loading bar — reintroduced (2026-07-29)
    //
    // "Brand Guidelines v1.0" removed the 2pt load bar in favor of an Amber hexagon
    // *pulse* alone. That read as "clunky / not a browser": every browser (Safari,
    // Chrome, Arc, Comet) shows load *progress*, not just a presence indicator. The
    // `loadProgressBar` above renders the already-plumbed `loadProgress` (0..1) as a
    // slim amber line under the omnibar. The hexagon pulse is KEPT (dual signal) — but
    // the bar is what makes a page load legible. See PITCH/browser-feel-fixes.md fix #1.

    private var fieldBackground: some View {
        // The outer 36pt bar background (the full horizontal chrome strip). The inner input
        // field has its own surface fill above.
        Color.clear
    }

    // MARK: Reseed / submit

    private var activeTab: BrowserTab? {
        guard let id = tabID else { return nil }
        return state.tabs.first { $0.id == id }
    }

    private func reseedFromTab() {
        typed = activeTab?.url?.absoluteString ?? ""
    }

    private func submit() {
        // If the user hits Enter while typing, always resolve the typed input. Suggestion
        // selection is handled by the suggestions view's own .onSubmit; this path ensures
        // Enter never does nothing when suggestions are visible.
        let raw = typed
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // @ prefix → Librarian query. Strip the @, open the archive sidebar, and prefill.
        if raw.hasPrefix("@") {
            let query = String(raw.dropFirst())
            state.openSwarmWithQuery(query)
            typed = ""
            isFocused = false
            return
        }

        // > prefix → Command mode (routed through CommandPalette).
        if raw.hasPrefix(">") {
            let command = String(raw.dropFirst())
            state.openCommandWithText(command)
            typed = ""
            isFocused = false
            return
        }

        if let url = OmnibarInput.resolveURL(for: raw) {
            state.navigateActive(to: url)
            typed = url.absoluteString
            isFocused = false
        }
    }
}

// MARK: - OmnibarMode

enum OmnibarMode: Equatable {
    case search
    case url
    case swarm     // @ prefix — routes to Swarm for natural-language queries
    case command   // > prefix — browser commands

    /// The SF Symbol shown on the leading edge.
    var icon: String {
        switch self {
        case .search:  return "magnifyingglass"
        case .url:     return "globe"
        case .swarm:   return "bubble.left"
        case .command: return "terminal"
        }
    }

    /// Auto-detect from the live text. `>` → command, `@` → swarm, else if it looks like a
    /// URL → url, otherwise search.
    static func detect(from text: String, baseURL: URL?) -> OmnibarMode {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix(">") { return .command }
        if t.hasPrefix("@") { return .swarm }
        if t.isEmpty { return .search }   // empty → search placeholder glyph
        if OmnibarInput.looksLikeHost(t) { return .url }
        if URL(string: t)?.scheme != nil { return .url }
        return .search
    }
}

// MARK: - SecurityLevel

enum SecurityLevel: Equatable {
    case https
    case http
    case internalPage   // about:, hive: — neutral

    init?(for url: URL) {
        switch url.scheme?.lowercased() {
        case "https":       self = .https
        case "http":        self = .http
        case "about", "hive", "file": self = .internalPage
        default:            return nil   // unknown scheme — don't show a lock
        }
        return
    }

    var icon: String {
        switch self {
        case .https:         return "lock.fill"
        case .http:          return "exclamationmark.triangle.fill"
        case .internalPage:  return "circle.fill"
        }
    }

    /// Human-readable label for the security panel and accessibility.
    var label: String {
        switch self {
        case .https:        return "Secure Connection"
        case .http:         return "Insecure Connection"
        case .internalPage: return "Internal Page"
        }
    }

    /// Detailed description of the security state for the SiteSecurityPanel.
    var detail: String {
        switch self {
        case .https:
            return "Your connection to this site is encrypted and authenticated using TLS. Data you send and receive cannot be read by third parties."
        case .http:
            return "Your connection to this site is not encrypted. Information you send and receive could be visible to others on your network. Passwords and payment details should not be entered."
        case .internalPage:
            return "This is a built-in Hive page. No network connection is involved."
        }
    }

    func color(scheme: ColorScheme) -> Color {
        switch self {
        case .https:        return Color(hiveAccentFor(scheme))
        case .http:         return .orange
        case .internalPage: return Color(hiveMistFor(scheme))
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .https:         return "Secure connection"
        case .http:          return "Not secure connection"
        case .internalPage:  return "Browser page"
        }
    }
}

// MARK: - Workaround for a conditional deprecation
//
// `textInputAutocapitalization(.never)` is the supported path on iOS; on macOS TextFields
// don't autocapitalize, so URLs stay lowercase by default. The helper above documents intent
// without tripping deprecated APIs.
