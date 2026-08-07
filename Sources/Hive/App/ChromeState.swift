import SwiftUI
import HiveCore

// MARK: - ChromeState
//
// The live, observable browser state the SwiftUI chrome binds to. It owns the in-memory
// truth — tabs, spaces, prefs — and writes durable prefs through `ChromePrefsStore` (an
// actor that does atomic disk writes). The UI never blocks on disk: mutations update the
// observable state synchronously, then a fire-and-forget `Task` persists.
//
// Owner's locked directive — "HIVE LETS USERS PICK ONE OR THE OTHER. NOT BOTH AT THE SAME
// TIME." — is enforced by `toggleLayout()`: it *flips* `prefs.tabPosition` between `.top`
// and `.vertical`, and the window renders exactly one of `TopChromeView` or
// `VerticalChromeView` from that single field. There is no "both" knob on this type.
//
// Single source of truth for "which tab is selected": `activeTabID`. The per-tab
// `BrowserTab.isActive` is a derived/synced convenience (kept honest by `recomputeActive`)
// so persisted state stays consistent, but views should prefer `state.activeTab`.

// MARK: - SessionRecoveryNotice
//
// Launch-time recovery state for the §9 crash-only contract: when the saved session is
// unreadable, Hive never *silently* starts fresh — it surfaces what happened and, where a
// last-known-good backup exists, restores from it. The notice drives BrowserWindow's alert so
// the user sees the choice, not a silent loss.

enum SessionRecoveryNotice: Sendable, Equatable {
    /// No notice; normal launch.
    case none
    /// `session.json` was unreadable; Hive restored the last known-good backup automatically.
    /// The user is offered "Start Fresh" in case the backup is also wrong.
    case recoveredFromBackup
    /// `session.json` was unreadable and no backup existed; Hive started fresh (one new tab).
    case lostNoBackup
}

@MainActor
@Observable
final class ChromeState {

    /// Whether the system accessibility reduce-motion setting is active.
    /// Callers gate `withAnimation` as `withAnimation(isReduceMotionEnabled ? nil : ...)`
    /// so every animation in the WKWebView shell respects the user's system preference.
    var isReduceMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    // MARK: - In-memory truth

    /// Every open tab across all spaces (the union set). Order = creation order; the
    /// Space's `tabIDs` defines display order within a space.
    private(set) var tabs: [BrowserTab] = []

    /// Workspaces. The first space is the default; vertical mode groups tabs by space.
    private(set) var spaces: [Space] = [Space.defaultSpace()]

    /// The currently-selected tab (the one whose WKWebView is frontmost). Exactly one per
    /// window; nil only transiently when the window has no tabs.
    private(set) var activeTabID: String?

    /// Durable + layout prefs (tab position, density, recently-closed stack, …).
    var prefs: ChromeUserPrefs

    // MARK: Imperative webview-command + focus plumbing
    //
    // Keyboard parity (⌘[ ⌘] ⌘R) needs to reach the *active* tab's WKWebView, which lives inside
    // the representable's Coordinator. Representables are declarative, so we thread a value:
    // `requestNav` stamps a monotonically-increasing `WebViewCommand.id` + records the active
    // tab as the target; BrowserWindow passes the command only to that tab's container, and its
    // `updateNSView` applies it id-gated (see WebViewContainer).
    var pendingCommand: WebViewCommand?
    var commandTabID: String?

    // MARK: Hibernation plumbing (§8)
    //
    // The WKWebView for a hibernated tab is dropped from the view tree (RAM freed); its session
    // (scroll/form/back-stack) is serialized into `sessionBroker` keyed by tab id, restored
    // losslessly when the tab wakes. Because SwiftUI representables are declarative, we drive
    // capture/restore with two per-tab counters read by WebViewContainer (id-gated, mirroring
    // the `WebViewCommand` channel): a request to hibernate bumps the counter → the still-alive
    // Coordinator captures `interactionState` into the broker during updateNSView → a deferred
    // tick sets `isHibernated = true` so the view tree tears the webview down. A wake sets
    // `isHibernated = false` → contentFill rebuilds the area → the fresh Coordinator's
    // makeNSView self-serves the sprite from the broker (drain-once).
    var sessionBroker = WebViewSessionBroker()
    /// per-tab id → last-requested hibernate counter. The view reads its value for a tab.
    var hibernateRequests: [String: Int] = [:]

    /// per-tab id → last-requested page-capture counter. The view reads its value for a tab.
    var captureRequests: [String: Int] = [:]

    /// Request-specific Auto-Capture bookkeeping. The ledger retains cancellation
    /// tombstones by `(tabID, requestID)` until the matching callback arrives.
    private var pageCaptureLedger = PageCaptureRequestLedger()

    /// Monotonic revision counter bumped whenever a page capture is successfully
    /// persisted to Honeycomb. SwarmHomeView observes this to refresh its
    /// "Today's Memory" list immediately after a capture — no reopen needed.
    var memoryRevision: Int = 0

    /// Bridges async Swarm requests for page text and the `.captureReady` webview update
    /// that fulfills them. Kept in a `let` (not a `var`) so the `@Observable` macro ignores
    /// it; the broker handles its own thread-safe storage of continuations.
    private let pageContextBroker = PageContextBroker()

    /// per-tab id → last-requested reader-mode extraction counter. The view reads its value for a tab.
    var readerModeRequests: [String: Int] = [:]

    /// Extracted reader-mode content keyed by tab id. The view renders these when a tab is in
    /// reader mode. Kept in memory only (no disk persistence) — the source page is the truth.
    var readerArtifacts: [String: ReaderArtifact] = [:]

    /// ⌘L requests omnibar focus. A counter (rather than a Bool) so each press is observable
    /// even when the field was already focused. `OmniBarView` watches this and focuses itself.
    var focusRequest: Int = 0

    /// Whether the ⌘O Tab Overview overlay is open. When true, `TabOverviewView` renders
    /// full-screen on top of the content, showing every open tab as a card in a searchable
    /// grid. Toggled by `toggleTabOverview()`; dismissed by Esc or selecting a tab.
    var isTabOverviewOpened = false

    /// Whether the ⌘K Command Palette overlay is open. When true, `CommandPaletteView`
    /// renders a centered, searchable command surface on top of the chrome + content.
    /// Dismissed by Esc or executing a command.
    var isCommandPaletteOpened = false

    /// Pre-filled command text set by the omnibar (> prefix). CommandPaletteView reads
    /// this on appear and clears it.
    var pendingCommandText: String?

    /// Whether the Tab Search overlay (⌘⇧A) is open. Renders `TabSearchView`
    /// as a floating overlay with search-filtered tabs grouped by workspace.
    var isTabSearchOpen = false

    /// Whether the Downloads panel is open. Renders `DownloadsView` as an overlay.
    var isDownloadsPanelOpen = false

    /// Whether the History panel is open. Renders `HistoryView` as an overlay (⌘Y).
    var isHistoryPanelOpen = false

    /// Whether the Bookmarks panel is open. Renders `BookmarksPanelView` as an overlay (⌘⌥B).
    var isBookmarksPanelOpen = false

    /// Whether the Reading List panel is open. Renders `ReadingListView` as an overlay (⌘⇧L).
    var isReadingListPanelOpen = false

    /// Whether the Pinned Web Apps sidebar section is open.
    var isPinnedAppsExpanded = false

    /// The currently active pinned web app (whose webview is shown when the rail is expanded).
    var activePinnedAppID: String?

    /// Whether the chrome is recessed (compressed after scrolling down). When true,
    /// the top chrome and tab bars telescope to give more vertical space to content.
    /// Set by the Coordinator when the user scrolls past a threshold.
    var chromeRecessed = false

    /// Whether Focus Mode is active — all chrome (omnibar, tab bar, sidebar, bookmark
    /// bar) is hidden so only the page content fills the window. Toggled via ⌘..
    /// When active, moving the mouse to the top edge reveals the chrome temporarily.
    /// Independent from full-screen mode — works within a normal window.
    var isFocusMode = false

    /// Whether the Quick Screenshot overlay is shown. Captured via ⌘⇧S.
    /// The overlay displays the captured page image with toolbar options
    /// (copy, save, save to Honeycomb, share). Cleared on dismiss.
    var isScreenshotOverlayShown = false

    /// The captured screenshot PNG data, shown in the overlay.
    var screenshotData: Data?

    /// Per-tab screenshot request counter. Bumped when the user presses ⌘⇧S.
    /// The Coordinator reads this in updateNSView to call WKWebView.takeSnapshot
    /// at full resolution, emitting `.screenshotCaptured` with the PNG data.
    var screenshotRequests: [String: Int] = [:]

    /// Requests a full-resolution screenshot of the active tab's visible viewport.
    /// Sets `isScreenshotOverlayShown = true` and bumps the request counter so the
    /// Coordinator captures and returns the image async. If no tab is active, no-op.
    func requestScreenshot() {
        guard let id = activeTabID else { return }
        isScreenshotOverlayShown = true
        screenshotData = nil
        screenshotRequests[id, default: 0] &+= 1
    }

    /// Dismisses the screenshot overlay and clears captured data.
    func dismissScreenshot() {
        isScreenshotOverlayShown = false
        screenshotData = nil
    }

    /// Whether the Swarm intelligence panel is open (right sidebar). Toggled via ⌘⇧Space
    /// or the brain icon in the omnibar. When open, shows `SwarmChatView` as a trailing
    /// sidebar connected to Honeycomb memory.
    var isSwarmOpen = false

    /// Whether the workspace knowledge browser (Projects/Briefs/Sources) is open
    /// inside the Swarm panel. Toggled by the sidebar button in SwarmChatView.
    var isWorkspaceOpen = false

    /// On-device neural TTS for spoken Swarm responses. Uses AVSpeechSynthesizer
    /// with Apple's highest-quality neural voice — zero network, zero cost.
    let voiceOutput = VoiceOutputManager()

    /// Conversation messages in the Swarm sidebar. Hoisted here (not @State in the view)
    /// so the conversation survives sidebar close/reopen. Cleared explicitly by the user.
    var swarmMessages: [SwarmMessage] = []

    /// Set by the omnibar when the user types `@ query` and presses Enter. SwarmChatView
    /// reads this on appear and immediately sends the query as a user message, then clears.
    var pendingSwarmQuery: String?

    /// The id of the tab currently showing a hover preview card. Set by `TabHoverPreviewModifier`
    /// after a 500ms sustained hover; cleared on hover exit. Rendered at window level in
    /// BrowserWindow's ZStack (above ScrollView clipping).
    var previewTabID: String?

    // MARK: - Find-in-Page (⌘F)

    /// Whether find-in-page is active (the search bar is visible).
    var isFindInPageActive = false

    /// The current find-in-page query string.
    var findInPageText = ""

    /// Total match count from the last find operation. Reset when search text changes.
    var findInPageMatchCount = 0

    /// The 1-based index of the currently highlighted match.
    var findInPageCurrentMatch = 1

    /// Per-tab find-in-page request counter. Bumped when the user types or presses Enter/arrows.
    /// The Coordinator reads this in updateNSView to call WKWebView.find().
    var findInPageRequests: [String: Int] = [:]

    /// Whether to find next (vs. previous). Set before bumping the request counter.
    var findInPageDirectionForward: Bool = true

    /// Toggles find-in-page for the active tab. Opens the bar if closed; closes if already open.
    func toggleFindInPage() {
        guard activeTabID != nil else { return }
        if isFindInPageActive {
            dismissFindInPage()
        } else {
            isFindInPageActive = true
            findInPageText = ""
            findInPageMatchCount = 0
            findInPageCurrentMatch = 1
        }
    }

    /// Dismisses the find-in-page bar and clears search state.
    func dismissFindInPage() {
        isFindInPageActive = false
        findInPageText = ""
        findInPageMatchCount = 0
        findInPageCurrentMatch = 1
        guard let id = activeTabID else { return }
        findInPageRequests[id, default: 0] &+= 1  // signals "clear" to the Coordinator
    }

    /// Requests the active tab's Coordinator to perform a find operation.
    /// Called on every text change in the find bar. Resets current match to 1.
    func requestFindInPage() {
        guard let id = activeTabID else { return }
        findInPageCurrentMatch = 1
        findInPageDirectionForward = true
        findInPageRequests[id, default: 0] &+= 1
    }

    /// Finds the next match (Enter key or down arrow). Wraps around.
    func findNextInPage() {
        guard let id = activeTabID, findInPageMatchCount > 0 else { return }
        findInPageCurrentMatch = findInPageCurrentMatch >= findInPageMatchCount
            ? 1 : findInPageCurrentMatch + 1
        findInPageDirectionForward = true
        findInPageRequests[id, default: 0] &+= 1
    }

    /// Finds the previous match (Shift+Enter or up arrow). Wraps around.
    func findPreviousInPage() {
        guard let id = activeTabID, findInPageMatchCount > 0 else { return }
        findInPageCurrentMatch = findInPageCurrentMatch <= 1
            ? findInPageMatchCount : findInPageCurrentMatch - 1
        findInPageDirectionForward = false
        findInPageRequests[id, default: 0] &+= 1
    }

    /// Clears find-in-page matches (empty search text).
    func clearFindInPage() {
        findInPageMatchCount = 0
        findInPageCurrentMatch = 1
    }

    /// Auto-archived tab records (§7). Persisted in the session so the "Recently Archived"
    /// tier survives restart. Capped to 500 records (oldest dropped on overflow).
    var archivedTabs: [ArchivedTab] = []

    // MARK: - Durability

    private let prefsStore: ChromePrefsStore?

    /// Durable full-session store. When present, every tab/space/group mutation schedules a
    /// debounced save (2s), and app-termination flushes synchronously. Nil → in-memory only
    /// (previews / tests), so existing test/preview call sites stay valid.
    private let sessionStore: BrowserSessionStore?

    /// Set on launch when the saved session was unreadable, so BrowserWindow can surface the
    /// §9 "Restore vs Start fresh" choice. `.none` = no notice. Reset by `startFresh()`.
    var sessionRecoveryNotice: SessionRecoveryNotice = .none

    // MARK: - Init

    /// - Parameters:
    ///   - prefsStore: Optional prefs store. If nil, prefs are not persisted (previews/tests).
    ///   - sessionStore: Optional session store. If nil, the full session (tabs/spaces/active
    ///     selection/layout) is not persisted — in-memory only (previews/tests). When present,
    ///     every mutation triggers a debounced save and termination a synchronous flush.
    // MARK: - Knowledge + audit stores

    /// Honeycomb durable knowledge graph. Optional so tests/previews can run without disk.
    let honeycomb: HoneycombStore?
    /// EventLedger append-only audit trail. Optional so tests/previews can run without disk.
    let eventLedger: EventLedgerStore?

    /// Shared download manager for the browser. Persists in memory for the session.
    let downloadManager = DownloadManager.shared

    /// Keychain-backed password store. nil in tests/previews; production wires the real keychain.
    let passwordStore: KeychainPasswordStore?

    /// Generic keychain-backed secret store for API keys and service tokens. nil in tests/previews.
    let secretStore: KeychainSecretStore?

    /// Multi-profile manager. Owns the roster of browser profiles and the active profile ID.
    /// When switching profiles, ChromeState tears down the current state and loads the new one.
    let profileManager: ProfileManager

    /// Brief store backed by Honeycomb. nil when honeycomb is unavailable (tests/previews).
    let briefStore: BriefStore?

    /// Loader for Swarm Cell system prompts. nil when the prompt directory is not found
    /// (tests/previews or an unbundled binary). Used by SwarmChatView to inject role-specific
    /// system prompts into model requests.
    let cellPromptLoader: CellPromptLoader?

    /// Live web research provider configured from prefs. Tries Tavily (cloud, free tier,
    /// always-available) first when enabled and the API key is set; falls back to self-hosted
    /// Vane when configured; returns nil when neither is available.
    var webSearchProvider: WebSearchProvider? {
        if prefs.tavilyEnabled, let tavily = TavilySearchProvider() {
            return tavily
        }
        if prefs.vaneEnabled, let url = URL(string: prefs.vaneBaseURL) {
            return VaneSearchProvider(baseURL: url)
        }
        return nil
    }

    init(prefs: ChromeUserPrefs = .defaults,
         prefsStore: ChromePrefsStore? = nil,
         sessionStore: BrowserSessionStore? = nil,
         honeycomb: HoneycombStore? = nil,
         eventLedger: EventLedgerStore? = nil,
         passwordStore: KeychainPasswordStore? = nil,
         secretStore: KeychainSecretStore? = nil,
         profileManager: ProfileManager = ProfileManager(),
         cellPromptLoader: CellPromptLoader? = nil) {
        self.prefs = prefs
        self.prefsStore = prefsStore
        self.sessionStore = sessionStore
        self.honeycomb = honeycomb
        self.eventLedger = eventLedger
        self.passwordStore = passwordStore
        self.secretStore = secretStore
        self.profileManager = profileManager
        self.cellPromptLoader = cellPromptLoader
        if let honeycomb {
            self.briefStore = BriefStore(honeycomb: honeycomb, ledger: eventLedger)
        } else {
            self.briefStore = nil
        }
    }

    // MARK: - Derived

    /// The active tab (the frontmost page), or nil.
    var activeTab: BrowserTab? { tabs.first { $0.id == activeTabID } }

    /// The frontmost space — authoritative, persisted. Falls back: persisted choice → tab's
    /// space → first space → default. This is the source of truth for `visibleTabs`, `newTab`
    /// routing, and the SpaceBar's fill state. A pure derivation from `activeTab.spaceID` would
    /// break switching to empty spaces and would leave `prefs.activeSpaceID` as dead weight.
    var activeSpace: Space {
        if let sid = prefs.activeSpaceID, let s = spaces.first(where: { $0.id == sid }) {
            return s
        }
        if let sid = activeTab?.spaceID, let s = spaces.first(where: { $0.id == sid }) {
            return s
        }
        return spaces.first ?? Space.defaultSpace()
    }

    /// Resolves the active space's accent color for tinting chrome elements
    /// (space rail, new-tab button, active tab indicators). Falls back to the
    /// global Hive accent when the stored token name is unrecognized.
    var activeAccentColor: Color {
        let token = HiveColorToken(rawValue: activeSpace.accentTokenName) ?? .accent
        return Color(token)
    }

    /// Tabs belonging to the active space, in display order.
    ///
    /// Order: pinned first, then unfolded group tabs in group order, then ungrouped tabs.
    /// Folded groups are represented by their group header, not their tabs, so their tabs
    /// are omitted here (they are hibernated and not keyboard-navigable until unfolded).
    /// In tree mode, any tab whose ancestor is collapsed is additionally hidden.
    var visibleTabs: [BrowserTab] {
        let space = activeSpace
        var visibleIDs: [String] = []
        // Groups render before ungrouped tabs in both layouts (chips in horizontal, sections
        // in vertical). Only unfolded groups expose their tabs.
        for group in space.groups where !group.isFolded {
            visibleIDs.append(contentsOf: group.tabIDs)
        }
        visibleIDs.append(contentsOf: space.tabIDs)
        var orderedTabs = visibleIDs.compactMap { id in tabs.first { $0.id == id } }
        // Pinned-first across the whole set so keyboard navigation (⌘1-9, cycle) matches view.
        let pinned = orderedTabs.filter { $0.isPinned }
        let unpinned = orderedTabs.filter { !$0.isPinned }
        orderedTabs = pinned + unpinned

        guard prefs.isTreeMode else { return orderedTabs }

        let collapsed = Set(prefs.treeCollapsedParentIDs)
        return orderedTabs.filter { tab in
            var ancestorID: String? = tab.parentTabID
            while let pid = ancestorID {
                if collapsed.contains(pid) { return false }
                ancestorID = tabs.first { $0.id == pid }?.parentTabID
            }
            return true
        }
    }

    /// All groups in the active space, in display order.
    var visibleGroups: [TabGroup] { activeSpace.groups }

    /// The ungrouped tabs of the active space (the ones still in `space.tabIDs`).
    var ungroupedTabs: [BrowserTab] {
        activeSpace.tabIDs.compactMap { id in tabs.first { $0.id == id } }
    }

    /// Returns the live tabs for a given group.
    func tabs(in group: TabGroup) -> [BrowserTab] {
        group.tabIDs.compactMap { id in tabs.first { $0.id == id } }
    }

    // MARK: - Layout toggle (the owner's "pick one" directive)

    /// Flips between horizontal (top) and vertical layouts — exactly one is ever rendered.
    /// Bound to ⌘⇧L. Persists the choice (prefs + the durable session snapshot).
    func toggleLayout() {
        prefs.tabPosition = prefs.tabPosition.toggled
        persistPrefs()
        scheduleSessionSave()
    }

    /// Sets the layout explicitly (used by onboarding Step 3 "Choose Your Layout").
    func setLayout(_ position: TabPosition) {
        guard prefs.tabPosition != position else { return }
        prefs.tabPosition = position
        persistPrefs()
        scheduleSessionSave()
    }

    // MARK: - Browser presets (automatic settings matching on import)

    /// Applies a BrowserPreset to the current preferences, instantly matching the source
    /// browser's layout, density, search engine, bookmark bar, and content blocker defaults.
    /// Called automatically during onboarding when the user selects a browser to import from.
    /// The user can still override any setting afterward in Settings or during layout choice.
    func applyPreset(_ preset: BrowserPreset) {
        prefs.tabPosition = preset.tabPosition
        prefs.tabDensity = preset.tabDensity
        prefs.defaultSearchEngine = preset.defaultSearchEngine
        prefs.showBookmarkBar = preset.showBookmarkBar
        prefs.contentBlockerEnabled = preset.contentBlockerEnabled
        persistPrefs()
        scheduleSessionSave()
    }

    /// Sends an imperative navigation command (back/forward/reload/stop) to the active tab's
    /// webview via the declarative `pendingCommand` channel.
    func requestNav(_ action: WebViewCommand.Action) {
        let nextID = (pendingCommand?.id ?? 0) &+ 1
        pendingCommand = WebViewCommand(id: nextID, action: action)
        commandTabID = activeTabID
    }

    /// Requests omnibar focus (⌘L). Each call bumps the counter so observers fire.
    func focusOmnibar() {
        focusRequest &+= 1
    }

    /// Toggles the §6 Tab Overview overlay (⌘⇧O). When opened, it shows every open tab as a
    /// card in a searchable grid; Esc or clicking a tab dismisses it.
    func toggleTabOverview() {
        isTabOverviewOpened.toggle()
    }

    /// Toggles Focus Mode (⌘.) — hides all chrome for distraction-free reading.
    /// When active, the omnibar, tab bar, sidebar, and bookmark bar are hidden
    /// with a smooth animation, and only the page content fills the window.
    /// Resets chromeRecessed on entry so exiting focus mode returns to full chrome.
    func toggleFocusMode() {
        withAnimation(isReduceMotionEnabled ? nil : .hiveCollapse) {
            isFocusMode.toggle()
            if isFocusMode {
                chromeRecessed = false
            }
        }
    }

    /// Toggles the Command Palette overlay (⌘K).
    func toggleCommandPalette() {
        isCommandPaletteOpened.toggle()
    }

    /// Opens the Command Palette with a pre-filled command from the omnibar (> prefix).
    /// If the palette is already open, the text is replaced.
    func openCommandWithText(_ text: String) {
        pendingCommandText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isCommandPaletteOpened { isCommandPaletteOpened = true }
    }

    /// Toggles the Downloads panel overlay (⌘J).
    func toggleDownloadsPanel() {
        isDownloadsPanelOpen.toggle()
    }

    /// Toggles the History panel overlay (⌘Y).
    func toggleHistoryPanel() {
        isHistoryPanelOpen.toggle()
    }

    /// Toggles the Tab Search overlay (⌘⇧A).
    func toggleTabSearch() {
        isTabSearchOpen.toggle()
    }

    /// Toggles the Bookmarks panel overlay (⌘⌥B).
    func toggleBookmarksPanel() {
        isBookmarksPanelOpen.toggle()
    }

    /// Toggles the Reading List panel overlay (⌘⇧L).
    func toggleReadingListPanel() {
        isReadingListPanelOpen.toggle()
    }

    // MARK: - Pinned Web Apps

    /// Pins the active tab as a web app in the sidebar. No-op if no tab is active or the URL is nil.
    /// Deduplicates by URL (moves existing entry to front).
    func pinActiveTabAsApp() {
        guard let tab = activeTab, let url = tab.url else { return }
        pinAsApp(name: tab.displayTitle, url: url, faviconURL: tab.faviconURL)
    }

    /// Pins a URL as a web app. Deduplicates by URL.
    @discardableResult
    func pinAsApp(name: String, url: URL, faviconURL: URL? = nil) -> PinnedWebApp {
        if let idx = prefs.pinnedWebApps.firstIndex(where: { $0.url == url }) {
            prefs.pinnedWebApps[idx].name = name
            prefs.pinnedWebApps[idx].faviconURL = faviconURL ?? prefs.pinnedWebApps[idx].faviconURL
            prefs.pinnedWebApps[idx].lastUsedAt = Date()
            let app = prefs.pinnedWebApps.remove(at: idx)
            prefs.pinnedWebApps.insert(app, at: 0)
            persistPrefs()
            return app
        }
        let app = PinnedWebApp(name: name, url: url, faviconURL: faviconURL, sortOrder: prefs.pinnedWebApps.count)
        prefs.pinnedWebApps.insert(app, at: 0)
        persistPrefs()
        return app
    }

    /// Removes a pinned web app by id.
    func unpinApp(id: String) {
        prefs.pinnedWebApps.removeAll { $0.id == id }
        if activePinnedAppID == id { activePinnedAppID = nil }
        persistPrefs()
    }

    /// Activates a pinned web app (shows its webview in the expanded sidebar).
    func selectPinnedApp(id: String) {
        activePinnedAppID = id
        isPinnedAppsExpanded = true
        if let idx = prefs.pinnedWebApps.firstIndex(where: { $0.id == id }) {
            prefs.pinnedWebApps[idx].lastUsedAt = Date()
            prefs.pinnedWebApps[idx].isLoaded = true
            persistPrefs()
        }
    }

    /// Toggles the pinned web apps section between expanded and collapsed.
    func togglePinnedApps() {
        isPinnedAppsExpanded.toggle()
        if !isPinnedAppsExpanded { activePinnedAppID = nil }
    }

    // MARK: - Little Arc

    /// The shared Little Arc popup window instance (lazy, one at a time).
    /// @MainActor because the window controller manages AppKit UI and is not Sendable.
    @MainActor private static let littleArcWindow = LittleArcWindow()

    /// Opens a URL in a Little Arc popup window — a lightweight, frameless popup
    /// for quick link previews without cluttering the tab bar.
    @MainActor
    func openInLittleArc(url: URL) {
        Self.littleArcWindow.show(url: url)
    }

    /// Opens the active tab's URL in a Little Arc popup. No-op if no URL.
    @MainActor
    func openActiveTabInLittleArc() {
        guard let url = activeTab?.url else { return }
        openInLittleArc(url: url)
    }

    /// Adds a URL to the reading list. Deduplicates by URL (updates title/favicon if
    /// the entry already exists). Returns the created/updated entry id.
    @discardableResult
    func addToReadingList(url: URL, title: String, faviconURL: URL? = nil) -> String {
        // Deduplicate: if an entry with this URL exists, update its title and favicon.
        if let idx = prefs.readingList.firstIndex(where: { $0.url == url }) {
            prefs.readingList[idx].title = title
            prefs.readingList[idx].faviconURL = faviconURL ?? prefs.readingList[idx].faviconURL
            prefs.readingList[idx].lastViewedAt = nil
            // Move to front (most recently saved).
            let entry = prefs.readingList.remove(at: idx)
            prefs.readingList.insert(entry, at: 0)
        } else {
            let entry = ReadingListEntry(url: url, title: title, faviconURL: faviconURL)
            prefs.readingList.insert(entry, at: 0)
        }
        // Cap at max to prevent unbounded prefs file growth.
        let cap = Array<ReadingListEntry>.hiveReadingListCap
        if prefs.readingList.count > cap {
            prefs.readingList = Array(prefs.readingList.prefix(cap))
        }
        persistPrefs()
        return url.absoluteString
    }

    /// Adds the active tab to the reading list. No-op if no tab is active or the URL is nil.
    func addActiveTabToReadingList() {
        guard let tab = activeTab, let url = tab.url else { return }
        addToReadingList(url: url, title: tab.displayTitle, faviconURL: tab.faviconURL)
    }

    /// Removes an entry from the reading list by id. Persists the change.
    func removeFromReadingList(id: String) {
        prefs.readingList.removeAll { $0.id == id }
        persistPrefs()
    }

    /// Marks a reading list entry as read (or unread). Persists the change.
    func toggleReadingListReadState(id: String) {
        guard let idx = prefs.readingList.firstIndex(where: { $0.id == id }) else { return }
        prefs.readingList[idx].isRead.toggle()
        prefs.readingList[idx].lastViewedAt = prefs.readingList[idx].isRead ? Date() : nil
        persistPrefs()
    }

    /// Opens a reading list entry in a new tab and marks it as read.
    func openReadingListEntry(_ entry: ReadingListEntry) {
        if let idx = prefs.readingList.firstIndex(where: { $0.id == entry.id }) {
            prefs.readingList[idx].isRead = true
            prefs.readingList[idx].lastViewedAt = Date()
            persistPrefs()
        }
        newTab(url: entry.url)
    }

    /// Toggles the Swarm intelligence sidebar (⌘⇧Space). Opens a right-side panel connected
    /// to Honeycomb memory for asking questions about your browsing context.
    func toggleSwarm() {
        isSwarmOpen.toggle()
    }

    /// Opens Swarm with a pre-filled query from the omnibar (triggered by `@ query` in
    /// the address bar). Sets pendingSwarmQuery so SwarmChatView picks it up on render.
    func openSwarmWithQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingSwarmQuery = trimmed
        if !isSwarmOpen { isSwarmOpen = true }
    }

    /// The id of a Brief to show in the detail sheet. Set by BriefTile.open().
    /// BriefBrowserView reads this on appear and presents the detail sheet.
    var selectedBriefID: String?

    /// Opens a Brief in the detail viewer. Sets selectedBriefID so BriefBrowserView
    /// presents the detail sheet for the given Brief.
    func openBrief(_ briefID: String) {
        selectedBriefID = briefID
    }

    /// Loads a Brief's content into the Swarm chat as an assistant message.
    /// This lets the user inspect a saved brief directly in the conversation.
    func loadBriefIntoContext(_ brief: Brief) {
        isSwarmOpen = true
        let header = "# \(brief.title)\n"
        let sourceNote = brief.sourceIDs.isEmpty ? "" : "\n*Linked to \(brief.sourceIDs.count) source(s).*\n\n"
        swarmMessages.append(SwarmMessage(
            role: .assistant,
            content: header + sourceNote + brief.content,
            scope: .memory,
            providerLabel: "Brief — \(brief.createdAt.formatted(date: .abbreviated, time: .omitted))"
        ))
    }

    /// Clears the Swarm conversation. Called by the trash button in SwarmChatView.
    func clearSwarmMessages() {
        swarmMessages = []
    }

    /// Saves a Swarm assistant message as a durable Brief in Honeycomb.
    /// Links the Brief to cited source nodes so every claim is traceable.
    /// Called from SwarmChatView's "Save as Brief" button.
    func saveAsBrief(_ message: SwarmMessage) {
        guard let briefStore, let honeycomb else { return }
        let title = "Brief: \(String(message.content.prefix(60)))"
        let citationURLs = message.citations.map { $0.url }
        Task {
            // Look up existing Honeycomb source nodes by URL for linking.
            var sourceIDs: [String] = []
            for citationURL in citationURLs {
                let hash = HoneycombStore.sha256(citationURL)
                if let existing = try? await honeycomb.findNode(type: .source, contentHash: hash) {
                    sourceIDs.append(existing.id)
                }
            }
            let brief = Brief(title: title, content: message.content, sourceIDs: sourceIDs)
            _ = try? await briefStore.save(brief)
        }
    }

    /// Records a history entry (or updates the visit date if the URL already exists).
    /// Called from `applyWebViewUpdate` on every page navigation. Capped at the max.
    func recordHistory(url: URL, title: String, faviconURL: URL? = nil) {
        // Deduplicate: update existing entry if same URL.
        if let idx = prefs.historyEntries.firstIndex(where: { $0.url == url }) {
            prefs.historyEntries[idx].visitDate = Date()
            if !title.isEmpty { prefs.historyEntries[idx].title = title }
            prefs.historyEntries[idx].faviconURL = faviconURL ?? prefs.historyEntries[idx].faviconURL
            // Move to front (most recent).
            let entry = prefs.historyEntries.remove(at: idx)
            prefs.historyEntries.insert(entry, at: 0)
        } else {
            prefs.historyEntries.insert(
                BrowsingHistoryEntry(url: url, title: title, visitDate: Date(), faviconURL: faviconURL),
                at: 0
            )
        }
        // Cap at max.
        let cap = Array<BrowsingHistoryEntry>.hiveHistoryCap
        if prefs.historyEntries.count > cap {
            prefs.historyEntries = Array(prefs.historyEntries.prefix(cap))
        }
        persistPrefs()
        // Index the new/updated entry into Spotlight for system-wide search.
        if let latest = prefs.historyEntries.first {
            Task { @MainActor in SpotlightIndexer.shared.index(latest) }
        }
    }

    /// Clears all browsing history entries.
    func clearHistory() {
        prefs.historyEntries = []
        persistPrefs()
        Task { @MainActor in SpotlightIndexer.shared.clearAll() }
    }

    // MARK: - Bookmarks (⌘D)

    /// Returns true if the active tab's URL is already bookmarked.
    var isActiveTabBookmarked: Bool {
        guard let url = activeTab?.url else { return false }
        return prefs.bookmarks.contains { $0.url == url && !$0.isFolder }
    }

    /// Toggles bookmark for the active tab (⌘D). Adds if not bookmarked, removes if already.
    func toggleBookmark() {
        guard let url = activeTab?.url, let title = activeTab?.title else { return }
        if let idx = prefs.bookmarks.firstIndex(where: { $0.url == url && !$0.isFolder }) {
            prefs.bookmarks.remove(at: idx)
        } else {
            prefs.bookmarks.insert(
                Bookmark(title: title.isEmpty ? (url.host ?? "Untitled") : title,
                        url: url, faviconURL: activeTab?.faviconURL),
                at: 0
            )
        }
        persistPrefs()
    }

    /// Returns root-level bookmarks (flat list, folders first).
    var rootBookmarks: [Bookmark] {
        prefs.bookmarks.filter { $0.parentID == nil }
    }

    /// Toggles the bookmark bar visibility (Cmd+Shift+B).
    func toggleBookmarkBar() {
        prefs.showBookmarkBar.toggle()
        persistPrefs()
    }

    /// Removes a bookmark (or folder) by id, recursively removing any descendants,
    /// and persists prefs.
    func deleteBookmark(id: String) {
        let updated = BookmarkDeletionPolicy.deleting(bookmarkID: id, from: prefs.bookmarks)
        guard updated != prefs.bookmarks else { return }
        prefs.bookmarks = updated
        persistPrefs()
    }

    /// Creates a new bookmark folder with the given name. If `parentID` is provided, the
    /// folder is nested under that folder; otherwise it is created at the root level.
    /// Empty names are ignored. Returns the created folder.
    @discardableResult
    func createBookmarkFolder(name: String, parentID: String? = nil) -> Bookmark {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = Bookmark(title: trimmed.isEmpty ? "Untitled Folder" : trimmed,
                              isFolder: true, parentID: parentID)
        prefs.bookmarks.insert(folder, at: 0)
        persistPrefs()
        return folder
    }

    /// Renames a bookmark or folder by id. Empty names are ignored.
    func renameBookmark(id: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = prefs.bookmarks.firstIndex(where: { $0.id == id }) {
            prefs.bookmarks[idx].title = trimmed
            persistPrefs()
        }
    }

    /// Returns the total number of descendants (recursive) for a folder id.
    func descendantCount(of parentID: String) -> Int {
        let children = prefs.bookmarks.filter { $0.parentID == parentID }
        return children.count + children.reduce(0) { $0 + descendantCount(of: $1.id) }
    }

    /// Returns true if `descendantID` is somewhere under `ancestorID` (recursive).
    func isDescendant(_ descendantID: String, of ancestorID: String) -> Bool {
        let children = prefs.bookmarks.filter { $0.parentID == ancestorID }
        return children.contains { $0.id == descendantID }
            || children.contains { isDescendant(descendantID, of: $0.id) }
    }

    /// Moves a bookmark/folder to a new location. `targetID` is the folder or item being
    /// dropped on. Pass `nil` to move to the root. `dropOnFolder: true` drops the source
    /// inside the target folder; `false` places it adjacent to the target item, sharing the
    /// target's parent. Prevents cycles (a folder cannot be dropped into itself or its
    /// descendants). Persists prefs on success and returns `true`.
    @discardableResult
    func moveBookmark(sourceID: String, targetID: String?, dropOnFolder: Bool) -> Bool {
        guard let sourceIdx = prefs.bookmarks.firstIndex(where: { $0.id == sourceID }) else { return false }
        let source = prefs.bookmarks[sourceIdx]
        // Cycle guard: a folder cannot be dropped into itself or its own descendants.
        if source.isFolder, let target = targetID {
            guard target != sourceID, !isDescendant(target, of: sourceID) else { return false }
        }
        guard sourceID != targetID else { return false }
        if dropOnFolder, let folderID = targetID {
            // Move into the folder; place the source right after the folder in the flat array
            // so it renders under that folder.
            guard !source.isFolder || folderID != sourceID else { return false }
            var moved = prefs.bookmarks.remove(at: sourceIdx)
            moved.parentID = folderID
            if let folderIdx = prefs.bookmarks.firstIndex(where: { $0.id == folderID }) {
                prefs.bookmarks.insert(moved, at: folderIdx + 1)
            } else {
                prefs.bookmarks.append(moved)
            }
        } else if let itemID = targetID {
            // Drop adjacent to an item: share its parent and insert at the target's position.
            guard let itemIdx = prefs.bookmarks.firstIndex(where: { $0.id == itemID }) else { return false }
            let targetParent = prefs.bookmarks[itemIdx].parentID
            // Cycle guard: if the target is inside the source folder (parent is source or a
            // descendant of source), the move would create a loop.
            if let tp = targetParent, source.isFolder, (tp == sourceID || isDescendant(tp, of: sourceID)) { return false }
            var moved = prefs.bookmarks.remove(at: sourceIdx)
            moved.parentID = targetParent
            if let newItemIdx = prefs.bookmarks.firstIndex(where: { $0.id == itemID }) {
                prefs.bookmarks.insert(moved, at: newItemIdx)
            } else {
                prefs.bookmarks.append(moved)
            }
        } else {
            // Move to root.
            var moved = prefs.bookmarks.remove(at: sourceIdx)
            moved.parentID = nil
            prefs.bookmarks.append(moved)
        }
        persistPrefs()
        return true
    }

    // MARK: - Zoom (⌘+/⌘-/⌘0)

    /// Zooms in the active tab by 10%. Clamped at 500%.
    func zoomIn() {
        guard let id = activeTabID, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let newLevel = min(5.0, tabs[idx].zoomLevel + 0.10)
        tabs[idx].zoomLevel = newLevel
        requestNav(.zoom(to: newLevel))
    }

    /// Zooms out the active tab by 10%. Clamped at 25%.
    func zoomOut() {
        guard let id = activeTabID, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let newLevel = max(0.25, tabs[idx].zoomLevel - 0.10)
        tabs[idx].zoomLevel = newLevel
        requestNav(.zoom(to: newLevel))
    }

    /// Resets zoom to 100%.
    func resetZoom() {
        guard let id = activeTabID, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].zoomLevel = 1.0
        requestNav(.zoom(to: 1.0))
    }

    // MARK: - Fullscreen (⌘⌃F)

    /// Toggles native macOS fullscreen mode on the key window.
    func toggleFullscreen() {
        guard let window = NSApp.keyWindow else { return }
        window.toggleFullScreen(nil)
    }

    // MARK: - Print (⌘P)

    /// Triggers the native macOS print dialog for the active tab. Injects `window.print()`
    /// JavaScript which opens the standard WebKit print panel with page setup, PDF export,
    /// and printer selection. Bound to ⌘P in BrowserWindow.
    func printActiveTab() {
        guard activeTabID != nil else { return }
        requestNav(.print)
    }

    /// Opens the SwiftUI `Settings` scene. The action is dispatched through the macOS app
    /// so the framework handles window creation/focus the same way as the standard ⌘, menu.
    func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    // MARK: - Space switching (§5)

    /// Switches to a different space, persisting the choice and restoring the target space's
    /// last-active tab frontmost. Idempotent (already-active space is a no-op). If the target
    /// space is empty (no tabs), the content area shows the start placeholder. Switching wakes
    /// the target tab if it was hibernated (the §8 on-focus-wake contract).
    func switchSpace(to spaceID: String) {
        guard spaceID != activeSpace.id, spaces.contains(where: { $0.id == spaceID }) else { return }
        prefs.activeSpaceID = spaceID
        persistPrefs()
        guard let target = spaces.first(where: { $0.id == spaceID }) else { return }
        // Restore the space's last-active tab, its first tab, or clear (empty space).
        if let lastID = target.activeTabID, let tab = tabs.first(where: { $0.id == lastID }) {
            selectTab(tab.id)   // wakes if hibernated, bumps lastVisitedAt, saves
        } else if let firstID = target.tabIDs.first, let tab = tabs.first(where: { $0.id == firstID }) {
            selectTab(tab.id)
        } else {
            activeTabID = nil
            recomputeActive()
            scheduleSessionSave()
        }
    }

    /// Cycles to the next or previous space (⌘⇧] / ⌘⇧[). Wraps around at the ends. No-op when
    /// there are fewer than 2 spaces.
    func cycleSpaces(forward: Bool = true) {
        guard spaces.count >= 2 else { return }
        let currentID = activeSpace.id
        guard let idx = spaces.firstIndex(where: { $0.id == currentID }) else {
            switchSpace(to: spaces[0].id)
            return
        }
        let next = forward
            ? (idx + 1 >= spaces.count ? spaces[0] : spaces[idx + 1])
            : (idx - 1 < 0 ? spaces.last! : spaces[idx - 1])
        switchSpace(to: next.id)
    }

    /// Creates a new space with a unique default name ("Space 2", "Space 3", …), and switches to
    /// it, persisting the change to the session.
    @discardableResult
    func newSpace() -> Space {
        let count = spaces.count
        let name = count == 0 ? "Default" : "Space \(count + 1)"
        let space = Space(name: name)
        spaces.append(space)
        switchSpace(to: space.id)
        scheduleSessionSave()
        return space
    }

    /// Deletes a space, closing all of its tabs. If the deleted space was the active one,
    /// falls back to the first remaining space. No-op if the space is the last one.
    func deleteSpace(_ spaceID: String) {
        guard spaces.count > 1, let si = spaces.firstIndex(where: { $0.id == spaceID }) else { return }
        let wasActive = activeSpace.id == spaceID
        let ids = spaces[si].tabIDs
        for id in ids { closeTab(id) }
        spaces.remove(at: si)
        scheduleSessionSave()
        if wasActive, let first = spaces.first {
            switchSpace(to: first.id)
        }
    }

    /// Renames a space. Empty names are ignored.
    func renameSpace(_ spaceID: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let si = spaces.firstIndex(where: { $0.id == spaceID }) else { return }
        spaces[si].name = trimmed
        scheduleSessionSave()
    }

    /// Sets the accent color token for a space. Unknown tokens fall back to `.accent` at read time.
    func setSpaceAccent(_ spaceID: String, to tokenName: String) {
        guard let si = spaces.firstIndex(where: { $0.id == spaceID }) else { return }
        spaces[si].accentTokenName = tokenName
        scheduleSessionSave()
    }

    /// Sets the SFSymbol icon name for a space. Empty or invalid names fall back to the
    /// default icon at render time.
    func setSpaceIcon(_ spaceID: String, to iconName: String) {
        guard let si = spaces.firstIndex(where: { $0.id == spaceID }) else { return }
        let trimmed = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        spaces[si].iconName = trimmed.isEmpty ? Space.defaultIconName : trimmed
        scheduleSessionSave()
    }

    // MARK: - MRU tab cycling (Ctrl+Tab / Ctrl+Shift+Tab)

    /// Cycled by most-recently-used (MRU) order rather than display position.
    /// Ctrl+Tab = forward, Ctrl+Shift+Tab = backward. Same behavior as Chrome/Arc.
    func cycleMRU(forward: Bool = true) {
        let mru = tabs.filter { !$0.isHibernated }
            .sorted { ($0.lastVisitedAt) > ($1.lastVisitedAt) }
        guard mru.count >= 2,
              let idx = mru.firstIndex(where: { $0.id == activeTabID }) else {
            if let first = mru.first { selectTab(first.id) }
            return
        }
        let n = mru.count
        let next = forward ? ((idx + 1) % n) : ((idx - 1 + n) % n)
        selectTab(mru[next].id)
    }

    /// Cycles to the previous/next tab in display order (⌘⇧[ / ⌘⇧]). `+1` → next, `-1` → prev.
    func cycleTab(by delta: Int) {
        let visible = visibleTabs
        guard !visible.isEmpty,
              let idx = visible.firstIndex(where: { $0.id == activeTabID }) else {
            // No active selection → land on the first/last tab.
            selectTab(at: delta > 0 ? 0 : visible.count - 1)
            return
        }
        let n = visible.count
        let next = ((idx + delta) % n + n) % n   // safe modulo for negatives
        selectTab(visible[next].id)
    }

    // MARK: - Onboarding

    /// Completes the first-launch onboarding flow and persists the flag. Idempotent.
    func completeOnboarding() {
        guard !prefs.hasCompletedOnboarding else { return }
        prefs.hasCompletedOnboarding = true
        persistPrefs()
    }

    /// Resets the onboarding flag (for testing / "re-run first launch" from settings later).
    func resetOnboarding() {
        guard prefs.hasCompletedOnboarding else { return }
        prefs.hasCompletedOnboarding = false
        persistPrefs()
    }

    // MARK: - Density

    func setDensity(_ density: TabDensity) {
        guard prefs.tabDensity != density else { return }
        prefs.tabDensity = density
        persistPrefs()
        scheduleSessionSave()
    }

    // MARK: - Settings persistence helpers

    func setDefaultSearchEngine(_ engine: String) {
        guard prefs.defaultSearchEngine != engine else { return }
        prefs.defaultSearchEngine = engine
        persistPrefs()
    }

    func setSidebarOpen(_ open: Bool) {
        guard prefs.sidebarOpen != open else { return }
        prefs.sidebarOpen = open
        persistPrefs()
    }

    func setHonorReduceMotion(_ honor: Bool) {
        guard prefs.honorReduceMotion != honor else { return }
        prefs.honorReduceMotion = honor
        persistPrefs()
    }

    // MARK: - Tab lifecycle

    /// Opens a new tab (optionally pre-loaded with a URL) and selects it. The new tab joins
    /// the given space (defaults to the active space).
    @discardableResult
    func newTab(url: URL? = nil, isPrivate: Bool = false, spaceID: String? = nil) -> BrowserTab {
        let resolvedSpaceID = spaceID ?? activeSpace.id
        var tab = url.map { BrowserTab(url: $0, isLoading: true, isActive: true,
                                      isPrivate: isPrivate, spaceID: resolvedSpaceID) }
            ?? BrowserTab.newTab(isPrivate: isPrivate, spaceID: resolvedSpaceID)
        // The factory sets isActive=true for exactly this tab; mark it active.
        tab.isActive = true
        tabs.append(tab)
        if let spaceIndex = spaces.firstIndex(where: { $0.id == resolvedSpaceID }) {
            spaces[spaceIndex].addTab(tab.id)
        }
        activeTabID = tab.id
        recomputeActive()
        scheduleSessionSave()
        return tab
    }

    /// Opens a URL in a new BACKGROUND tab (Chrome verbatim: ⌘⏎ in the omnibox dropdown,
    /// ⌘-click on links). The current tab stays active; the new tab loads quietly behind
    /// it and is one ⌘⇧] away. No activation, no focus change.
    func newBackgroundTab(url: URL?, isPrivate: Bool = false, spaceID: String? = nil) -> BrowserTab {
        let resolvedSpaceID = spaceID ?? activeSpace.id
        var tab = url.map { BrowserTab(url: $0, isLoading: true, isActive: false,
                                       isPrivate: isPrivate, spaceID: resolvedSpaceID) }
            ?? BrowserTab.newTab(isPrivate: isPrivate, spaceID: resolvedSpaceID)
        tab.isActive = false
        tabs.append(tab)
        if let spaceIndex = spaces.firstIndex(where: { $0.id == resolvedSpaceID }) {
            spaces[spaceIndex].addTab(tab.id)
        }
        scheduleSessionSave()
        return tab
    }

    /// Closes a tab. Records it in the recently-closed stack for ⌘⇧T, then selects a
    /// neighbor (the next tab, or the previous if the closed tab was last).
    /// Tree-aware: children of a closed parent are promoted to the closed tab's parent
    /// (or to root if it had none), preserving the subtree shape.
    func closeTab(_ id: String) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        // Record for ⌘⇧T reopen.
        if let url = tab.url {
            let record = ClosedTabRecord(url: url, title: tab.displayTitle)
            recordClosedTabAsync(record)
        }
        // Drop any hibernation sprite so a recycled tab id can't resurrect a dead page.
        sessionBroker.clear(tabID: id)
        hibernateRequests.removeValue(forKey: id)
        cancelPendingPageContextExtraction(for: id)
        pageCaptureLedger.removeAll(for: id)
        // Remove from the owning space.
        if let sid = tab.spaceID, let i = spaces.firstIndex(where: { $0.id == sid }) {
            spaces[i].removeTab(id)
        }
        // Compute neighbor selection BEFORE removing (uses display order).
        let neighbors = visibleTabs
        let visibleIdx = neighbors.firstIndex { $0.id == id }
        let nextActive: String? = {
            guard let idx = visibleIdx else { return nil }
            if idx + 1 < neighbors.count { return neighbors[idx + 1].id }
            return idx > 0 ? neighbors[idx - 1].id : nil
        }()

        // Promote children to the closed tab's parent (or root), so the tree stays valid.
        let newParentID = tab.parentTabID
        for i in tabs.indices where tabs[i].parentTabID == id {
            tabs[i].parentTabID = newParentID
        }
        // Remove the closed parent id from the collapsed set (no longer relevant).
        prefs.treeCollapsedParentIDs.removeAll { $0 == id }
        tabs.removeAll { $0.id == id }
        activeTabID = nextActive ?? tabs.last?.id
        recomputeActive()
        scheduleSessionSave()
    }

    // MARK: - Drag-and-drop tab reordering

    /// Moves a tab to a new position within its current space.
    /// Delegates to `Space.moveTab(_:to:)` which uses final-index semantics.
    func moveTab(_ tabID: String, to newIndex: Int, in spaceID: String? = nil) {
        let sid = spaceID ?? activeSpace.id
        guard let si = spaces.firstIndex(where: { $0.id == sid }) else { return }
        spaces[si].moveTab(tabID, to: newIndex)
        scheduleSessionSave()
    }

    /// Moves a tab from its current space to a different space, placing it at the end.
    /// If the source and target are the same, this is a no-op.
    func moveTabToSpace(_ tabID: String, targetSpaceID: String) {
        guard let tab = tabs.first(where: { $0.id == tabID }),
              let sourceSI = spaces.firstIndex(where: { $0.id == tab.spaceID }),
              let targetSI = spaces.firstIndex(where: { $0.id == targetSpaceID }),
              tab.spaceID != targetSpaceID else { return }
        spaces[sourceSI].removeTab(tabID)
        spaces[targetSI].addTab(tabID)
        // Update the tab's spaceID
        if let idx = tabs.firstIndex(where: { $0.id == tabID }) {
            tabs[idx].spaceID = targetSpaceID
        }
        scheduleSessionSave()
    }

    /// Reopens the most-recently closed tab (⌘⇧T). Returns the reopened tab, or nil if the
    /// closed stack is empty.
    @discardableResult
    func reopenLastClosed() -> BrowserTab? {
        guard let record = prefs.recentlyClosed.first else { return nil }
        prefs.recentlyClosed.removeFirst()
        persistPrefs()
        return newTab(url: record.url)   // newTab() schedules the session save
    }

    /// Selects a tab by id (makes it the frontmost). Exactly one tab is active afterward.
    /// Syncs the frontmost space to the selected tab's space (two-way binding: switchSpace
    /// → selectTab → sets activeTabID; selectTab → syncs prefs.activeSpaceID + Space.activeTabID).
    func selectTab(_ id: String) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        // Selecting a hibernated tab wakes it (the §8 "on focus, it wakes" affordance): set the
        // model flag so contentFill rebuilds the area; the fresh Coordinator restores from the
        // broker game (lossless scroll/form/back-stack). No restart needed — waking
        // is a model flip, not a webview command.
        if tabs[idx].isHibernated {
            tabs[idx].isHibernated = false
        }
        activeTabID = id
        tabs[idx].lastVisitedAt = Date()
        // Sync the frontmost space to the selected tab's space (two-way binding).
        if let sid = tabs[idx].spaceID, let si = spaces.firstIndex(where: { $0.id == sid }) {
            prefs.activeSpaceID = sid
            spaces[si].activeTabID = id
            persistPrefs()
        }
        recomputeActive()
        scheduleSessionSave()
    }

    /// Selects a tab by ordinal position (⌘1–⌘9 map to the first nine visible tabs).
    func selectTab(at index: Int) {
        let visible = visibleTabs
        guard index >= 0, index < visible.count else { return }
        selectTab(visible[index].id)
    }

    // MARK: - Navigation (omnibar → webview)

    /// Navigates the active tab to a URL. Sets the model fields the WebViewContainer reads,
    /// which triggers the load via `updateNSView`; on success the webview's
    /// `WebViewUpdate` callbacks overwrite `isLoading`/`url`/`title`/etc. with the live
    /// values. For a private tab, no history is captured (the ephemeral store handles it).
    /// If there's no active tab (empty window), opens a new one.
    @discardableResult
    func navigateActive(to url: URL?) -> BrowserTab? {
        guard let url else { return activeTab }
        if activeTabID == nil { return newTab(url: url) }
        guard let i = tabs.firstIndex(where: { $0.id == activeTabID }) else { return nil }
        tabs[i].pendingURL = url
        tabs[i].url = url
        tabs[i].isLoading = true
        tabs[i].loadProgress = 0.05
        tabs[i].lastVisitedAt = Date()
        // The WebViewContainer's `requestNavigation` reads the tab's `url` and loads it.
        scheduleSessionSave()
        return tabs[i]
    }

    /// Routes a `WebViewUpdate` (from the WebViewContainer's delegate/KVO callbacks) into
    /// the owning tab's model. Idempotent over tabs that no longer exist (closed mid-load).
    /// The BrowserWindow wires each container's `onUpdate` to this with its tab's id.
    func applyWebViewUpdate(_ update: WebViewUpdate, forTabID tabID: String) {
        guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        switch update {
        case .title(let t):
            tabs[i].title = t
            scheduleSessionSave()
        case .url(let u):
            tabs[i].url = u
            tabs[i].pendingURL = nil
            // Record history on navigation (main frame only).
            if let url = u, !tabs[i].isPrivate {
                recordHistory(url: url, title: tabs[i].title, faviconURL: tabs[i].faviconURL)
            }
            scheduleSessionSave()
        case .loading(let l):             tabs[i].isLoading = l
        case .progress(let p):             tabs[i].loadProgress = p
        case .canGoBack(let b):           tabs[i].canGoBack = b
        case .canGoForward(let f):         tabs[i].canGoForward = f
        case .favicon(let f):             tabs[i].faviconURL = f
        case .didFailProvisionalNav:
            tabs[i].isLoading = false
            tabs[i].loadProgress = 0
        case .didFailNav:
            tabs[i].isLoading = false
        case .processTerminated:
            tabs[i].isLoading = false
        case .openNewWindow(let url):
            // Popups open as a new tab in the same space, selected.
            newTab(url: url)
        case .hibernated:
            // The Coordinator captured its interactionState into the broker and is signaling
            // that it's safe to tear the webview down. Flip isHibernated so the next render
            // drops the area (RAM freed); the broker holds the sprite for a lossless wake.
            guard let i = tabs.firstIndex(where: { $0.id == tabID }) else { return }
            tabs[i].isHibernated = true
            scheduleSessionSave()
        case .captureReady(let requestID, let url, let title, let text):
            // A webview callback is an untrusted ingress: the tab may have become private
            // after the request was armed. Cancel every waiter and pending auto-capture before
            // doing anything with the extracted bytes. Private content must not enter the
            // broker, Honeycomb, EventLedger, or the scribe model path.
            guard let tab = tabs.first(where: { $0.id == tabID }),
                  PageCaptureAdmission.evaluate(isPrivate: tab.isPrivate).isAllowed else {
                pageCaptureLedger.removeAll(for: tabID)
                pageContextBroker.cancel(for: tabID)
                return
            }

            // Capture requests serve two deliberately different contracts. An explicit user
            // capture may still write a page to Hive memory when Swarm inspection is disabled;
            // an armed Auto-Capture must be canceled before persistence if that setting flips
            // while the webview extraction is in flight. Resolve by request identity so a
            // canceled Auto-Capture cannot consume a later manual capture.
            let disposition = pageCaptureLedger.consume(tabID: tabID, requestID: requestID)
            let delivery = PageCaptureDeliveryPolicy.decide(
                disposition: disposition,
                isPrivate: tab.isPrivate,
                aiContextAllowed: tab.isAIContextAllowed
            )
            guard delivery.persistCapture else {
                pageContextBroker.cancel(for: tabID)
                return
            }

            // The Coordinator extracted the active page's title/URL/text. Persist an explicit
            // manual capture, or an allowed Auto-Capture, as a Honeycomb Source + Capture and
            // record its audit event.
            handlePageCapture(tabID: tabID, url: url, title: title, text: text)

            guard delivery.fulfillContext else {
                pageContextBroker.cancel(for: tabID)
                return
            }

            // Resume any async waiter (e.g., Swarm context extraction). Carry the tab's
            // provenance explicitly rather than relying on PageContext's safe default.
            let context = PageContext(
                tabID: tabID,
                url: url,
                title: title,
                text: text,
                privateBrowsing: tab.isPrivate,
                aiContextAllowed: tab.isAIContextAllowed
            )
            pageContextBroker.fulfill(context)
            // Auto-Capture continuation (A2): if `.loadFinished` armed a triage for this tab,
            // run the captureScribe Cell over this SAME extracted text — no second extraction.
            // Extracted to its own method so the Swift 6 region-isolation checker accepts the
            // detached `Task` (the inline guard-with-task pattern it can't certify).
            if delivery.launchAutoTriage {
                launchAutoCaptureTriage(pageContext: context)
            }
        case .readerModeReady(let artifact):
            // The Coordinator extracted article content for reader mode. Cache it and keep the
            // tab in reader mode so the clean view renders.
            readerArtifacts[tabID] = artifact
            scheduleSessionSave()
        case .findInPageResult(let matchCount):
            findInPageMatchCount = matchCount
            if matchCount > 0 && findInPageCurrentMatch > matchCount {
                findInPageCurrentMatch = matchCount
            }
        case .thumbnailCaptured(let data):
            thumbnailData[tabID] = data
        case .screenshotCaptured(let data):
            screenshotData = data
        case .scrollOffset(let offset):
            // Scroll detection for chrome recession: when the user scrolls past a
            // threshold (20px), compress the chrome; when they return to the top,
            // restore it. Only applies when chrome auto-hide is enabled.
            let wasRecessed = chromeRecessed
            if prefs.chromeAutoHideEnabled {
                chromeRecessed = offset > 20
            } else {
                chromeRecessed = false
            }
            // Only animate on actual state change to avoid unnecessary re-renders.
            if wasRecessed != chromeRecessed {
                // The BrowserWindow's chrome observes this flag via animation.
                // No further action needed — the SwiftUI bindings handle it.
            }
        case .loadFinished:
            // Success-only "page done loading" — Auto-Capture triages here, NOT on every
            // tab switch or partial-load. Honors the per-surface opt-in the capture_scribe
            // prompt mandates ("absent → default skip"); private tabs are always excluded.
            // This only ARM the route — the actual triage runs in `.captureReady` once the
            // Coordinator returns the extracted text (reuses the capture pipeline, no double
            // JS extraction, no second Source/Capture node).
            guard prefs.autoCaptureEnabled else { return }
            guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
            guard !tab.isPrivate, honeycomb != nil, eventLedger != nil else { return }
            captureRequests[tabID, default: 0] &+= 1
            pageCaptureLedger.armAutoCapture(tabID: tabID, requestID: captureRequests[tabID]!)
        }
    }

    // MARK: - Page capture → Honeycomb (P1 differentiated loop)

    /// Requests the active tab's Coordinator to extract page title/URL/text and emit a
    /// `.captureReady` update. The actual persistence happens asynchronously in
    /// `handlePageCapture` once the webview returns the extracted content.
    /// - Returns: true if a capture was requested for the active tab.
    @discardableResult
    func captureActivePage() -> Bool {
        guard let id = activeTabID, let tab = activeTab, !tab.isPrivate else { return false }
        guard honeycomb != nil else { return false }
        captureRequests[id, default: 0] &+= 1
        pageCaptureLedger.armManualCapture(tabID: id, requestID: captureRequests[id]!)
        return true
    }

    // MARK: - Page context extraction for Swarm

    /// Asks the live Coordinator for `tabID` to extract page text and waits for the result.
    /// Returns nil if the tab is private, hibernated, or no live webview is available.
    /// Time-bounded (5s) so a stuck webview does not block Swarm indefinitely.
    @MainActor
    func extractPageContext(for tabID: String) async -> PageContext? {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return nil }
        guard !tab.isPrivate, !tab.isHibernated, tab.url != nil, tab.isAIContextAllowed else { return nil }
        captureRequests[tabID, default: 0] &+= 1
        pageCaptureLedger.armManualCapture(tabID: tabID, requestID: captureRequests[tabID]!)
        return await pageContextBroker.request(for: tabID)
    }

    /// Convenience for the active tab.
    @MainActor
    func extractActivePageContext() async -> PageContext? {
        guard let id = activeTabID else { return nil }
        return await extractPageContext(for: id)
    }

    /// Extracts page context for every non-private, non-hibernated open tab that has a URL.
    /// Tabs that cannot be captured (e.g., no live webview) are skipped. This is sequential
    /// to avoid capturing `self` inside a `@Sendable` `withTaskGroup` closure and to cap
    /// pressure on the webview pool.
    @MainActor
    func extractAllTabsContext() async -> [PageContext] {
        let eligible = tabs.filter { !$0.isPrivate && !$0.isHibernated && $0.url != nil && $0.isAIContextAllowed }
        var results: [PageContext] = []
        for tab in eligible {
            if let context = await extractPageContext(for: tab.id) {
                results.append(context)
            }
        }
        return results
    }

    /// Called when a tab is closed to prevent abandoned continuations from hanging.
    func cancelPendingPageContextExtraction(for tabID: String) {
        pageContextBroker.cancel(for: tabID)
    }

    // MARK: - Start page data

    /// Per-tab page thumbnails (keyed by tab ID). Captured on page load finish by the
    /// Coordinator via WKWebView.takeSnapshot(). Stored as PNG data for rendering in
    /// TabHoverPreview and TabOverview cards. In-memory only (not persisted to disk).
    var thumbnailData: [String: Data] = [:]

    /// Returns the top N most-visited URLs from the current tab set, deduplicated by host,
    /// ordered by most-recently-visited first. Used for the Start Page speed dial grid.
    /// Falls back to the archived-tab URLs when live tabs are sparse.
    func topSites(limit: Int = 8) -> [BrowserTab] {
        var seen = Set<String>()
        var result: [BrowserTab] = []
        // Live tabs, sorted by most-recently-visited.
        let live = tabs
            .filter { $0.url != nil && !$0.isPrivate }
            .sorted { ($0.lastVisitedAt) > ($1.lastVisitedAt) }
        for tab in live {
            guard let host = tab.url?.host, !host.isEmpty else { continue }
            let normalized = host.replacingOccurrences(of: "www.", with: "")
            if seen.insert(normalized).inserted {
                result.append(tab)
                if result.count >= limit { return result }
            }
        }
        // Fill remaining slots from archived tabs.
        for record in archivedTabs {
            guard let host = record.url?.host, !host.isEmpty else { continue }
            let normalized = host.replacingOccurrences(of: "www.", with: "")
            if seen.insert(normalized).inserted {
                result.append(BrowserTab(url: record.url, title: record.title))
                if result.count >= limit { return result }
            }
        }
        return result
    }

    /// Returns the most-recently captured Honeycomb Sources for display on the start page.
    /// Safe to call from SwiftUI (`.task`) — the actor hop is handled here. Returns an capped,
    /// ordered list (newest first), or an empty list when Honeycomb is unavailable.
    @MainActor
    func recentSources(limit: Int = 8) async -> [Source] {
        guard let honeycomb else { return [] }
        return (try? await honeycomb.getAllSources(limit: limit)) ?? []
    }

    // MARK: - Reader mode (§25)

    /// Toggles reader mode on the active tab. Turning it on requests the webview to extract
    /// the article; turning it off immediately returns to the normal page view.
    func toggleReaderMode() {
        guard let id = activeTabID else { return }
        toggleReaderMode(for: id)
    }

    /// Toggles reader mode on a specific tab. If the tab is not active, selecting it will show
    /// the reader view. Extraction is requested for any non-hibernated tab with a URL.
    func toggleReaderMode(for tabID: String) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[idx].isReaderMode.toggle()
        let nowOn = tabs[idx].isReaderMode
        if nowOn {
            readerModeRequests[tabID, default: 0] &+= 1
        } else {
            readerArtifacts.removeValue(forKey: tabID)
        }
        scheduleSessionSave()
    }

    /// Stores an extracted reader artifact for a tab and schedules a session save.
    func setReaderArtifact(_ artifact: ReaderArtifact, forTabID id: String) {
        readerArtifacts[id] = artifact
        scheduleSessionSave()
    }

    /// Persists a captured page as Honeycomb Source + Capture nodes and records the event
    /// in the EventLedger. Runs on the main actor (called from the webview callback).
    private func handlePageCapture(tabID: String, url: URL?, title: String, text: String) {
        guard let tab = tabs.first(where: { $0.id == tabID }),
              PageCaptureAdmission.evaluate(isPrivate: tab.isPrivate).isAllowed else { return }
        guard let honeycomb, let eventLedger else { return }
        guard let url else { return }
        let capturedURL = url.absoluteString
        let capturedTitle = title.isEmpty ? url.host ?? "Untitled" : title
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                // 1. Source node (deduplicated by URL hash).
                let source = Source(
                    url: capturedURL,
                    title: capturedTitle,
                    captureMethod: "browser-capture",
                    provenance: "browser-capture"
                )
                let storedSource = try await honeycomb.createSource(source)

                // 2. Capture node for the extracted text, linked to the source.
                let captureNode = HoneycombStore.Node(
                    type: .capture,
                    label: "Capture: \(capturedTitle)",
                    metadata: .object([
                        "url": .string(capturedURL),
                        "title": .string(capturedTitle),
                        "text": .string(String(trimmedText.prefix(5000))),
                        "sourceID": .string(storedSource.id)
                    ]),
                    contentHash: HoneycombStore.sha256(trimmedText),
                    provenance: "browser-capture"
                )
                let storedCapture = try await honeycomb.insertNode(captureNode)

                // 3. Link capture → source.
                _ = try? await honeycomb.insertEdge(
                    HoneycombStore.Edge(
                        sourceID: storedCapture.id,
                        targetID: storedSource.id,
                        relation: .derivedFrom
                    )
                )

                // 4. Audit in EventLedger.
                let event = EventLedgerStore.LedgerEvent(
                    actor: "user",
                    intent: "Capture page to Honeycomb",
                    actionKind: .capture,
                    actionTarget: capturedURL,
                    actionPreview: "Captured \"\(capturedTitle)\" as Source + Capture nodes",
                    trustLevel: .t0,
                    policyDecision: .allowed,
                    consentState: .auto,
                    contextIDs: [storedSource.id, storedCapture.id],
                    result: .success,
                    provenance: "browser-capture"
                )
                _ = try? await eventLedger.record(event)

                // Signal memory observers (SwarmHome) that a capture landed.
                memoryRevision &+= 1
            } catch {
                let event = EventLedgerStore.LedgerEvent(
                    actor: "user",
                    intent: "Capture page to Honeycomb",
                    actionKind: .capture,
                    actionTarget: capturedURL,
                    actionPreview: "Failed to capture \"\(capturedTitle)\": \(error.localizedDescription)",
                    trustLevel: .t0,
                    policyDecision: .allowed,
                    consentState: .auto,
                    result: .failure,
                    errorDescription: error.localizedDescription,
                    provenance: "browser-capture"
                )
                _ = try? await eventLedger.record(event)
            }
        }
    }

    /// Launches the Auto-Capture scribe triage for a freshly-captured page (A2). Extracted from
    /// `applyWebViewUpdate`'s `.captureReady` case because the Swift 6 region-isolation checker
    /// can't certify the detached `Task` when the guard + the pending-set mutation + the Task
    /// are all inline inside a `switch` arm. As a top-level method with the guard first — exactly
    /// `handlePageCapture`'s idiom — the checker accepts it. No `self` crosses the Task boundary:
    /// `autoCaptureTriageAndWrite` is `static`; `honeycomb`/`eventLedger` are actors (Sendable);
    /// `CellPromptLoader` + `PageContext` are Sendable. The `Task` is main-actor-isolated to
    /// match this method's isolation, so captured values don't cross isolation (the inference/
    /// writes themselves still `await` to the actor stores → the main actor is freed mid-call).
    func launchAutoCaptureTriage(pageContext: PageContext) {
        guard PageCaptureAdmission.evaluate(isPrivate: pageContext.isPrivateBrowsing).isAllowed else { return }
        guard let honeycomb, let eventLedger else { return }
        let loader = cellPromptLoader
        Task { @MainActor in
            await Self.autoCaptureTriageAndWrite(
                pageContext: pageContext, honeycomb: honeycomb, eventLedger: eventLedger, loader: loader)
        }
    }

    // MARK: - Auto-Capture triage (scribe invocation route — PITCH/backend-completion.md A2)
    //
    // Runs the T0 `captureScribe` Cell over a captured page and applies the verdict:
    //   - `keep`  → writes each extracted fact/decision/commitment as a Honeycomb node
    //               (`.claim` / `.decision` / `.task`) linked to the page's Source via a
    //               `.derivedFrom` edge. Raw `insertNode` (content-hash dedup) + `insertEdge`,
    //               matching `handlePageCapture`'s idiom, so re-capturing a page never
    //               duplicates. The scribe's own `dedup` field is honored: a node flagged a
    //               duplicate of an existing one is skipped; one flagged `supersedes` an
    //               existing node gets a `.supersedes` edge instead of a fresh write.
    //   - `skip`  → no node. The skip (transient / duplicate / low-signal / parse-error / etc.)
    //               is recorded in EventLedger so the auto-capture loop is auditable, not silent.
    //
    // The Cell never holds a write handle (the scribe prompt's contract): `ScribeCoordinator`
    // parses its strict-JSON output into a `CaptureVerdict`, and THIS method — which owns the
    // honeycomb/eventLedger handles — applies the writes under the permission ladder.
    // Degradation is honest: with MLX not linked, `Dispatcher` serves `MockRuntime`, whose
    // capture_scribe body is `{"verdict":"skip","reason":"mock",...}` → the loop records a
    // `skip` audit labelled `mock` and writes nothing. Complete + correct with or without MLX.

    private static func autoCaptureTriageAndWrite(
        pageContext: PageContext, honeycomb: HoneycombStore,
        eventLedger: EventLedgerStore, loader: CellPromptLoader?
    ) async {
        let targetURL = pageContext.url?.absoluteString ?? ""

        // 1. Run the scribe triage (Cell call; parses strict-JSON → CaptureVerdict).
        let verdict = await ScribeCoordinator.autoCaptureTriage(
            pageContext: pageContext, loader: loader, boundedDedupContext: "")

        // 2. Honor the scribe's artifact-level dedup: if the Cell says this whole capture is
        //    a duplicate of existing material, write nothing — record it as a skip-duplicate
        //    (the auditable "we saw it, already had it" event). The per-item content-hash
        //    dedup inside `insertNode` is the second layer (exact-duplicate claim text is
        //    never re-stored). The scribe's `supersedes`/`duplicates_of` IDs are emitted by
        //    a real model seeded with `dedup_context`; for the mock (empty arrays) there's
        //    nothing to act on, so this branch is a no-op for the mock path.
        if verdict.deduplication.isDuplicate {
            await autoCaptureAudit(eventLedger: eventLedger, targetURL: targetURL, result: .partial,
                             intent: "Auto-Capture triage: skipped (duplicate)",
                             preview: "captureScribe(\(verdict.providerLabel)) flagged duplicate — not re-written",
                             modelProvider: verdict.providerLabel, modelRole: ModelRole.captureScribe, contextIDs: [])
            return
        }

        // 3. Apply the verdict.
        switch verdict.verdict {
        case .keep:
            // Find-or-create the page's Source node. Because `handlePageCapture` writes the
            // Source inside its own detached Task, it may not have landed yet — so a bare
            // `findSource` could miss it (a race). `createSource` is content-hash-deduplicated
            // (hash = sha256(url)), so this is idempotent: if handlePageCapture already wrote
            // it, this returns the same node; if not, it writes it. Either way, no duplicate.
            let source: Source
            if let existing = try? await honeycomb.findSource(byURL: targetURL) {
                source = existing
            } else {
                let s = Source(url: targetURL, title: pageContext.title,
                              captureMethod: "browser-capture", provenance: "browser-capture")
                guard let created = try? await honeycomb.createSource(s) else { return }
                source = created
            }
            var written: [String] = [source.id]
            // Facts → `.claim` nodes (typed Claim → insertNode; content-hash dedups by claim text).
            for fact in verdict.extracted.facts {
                guard !fact.claim.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let claim = Claim(text: fact.claim, confidence: max(0.0, min(1.0, fact.confidence)),
                                 evidenceSpans: [], freshness: .current,
                                 contradictionState: .uncontested, provenance: "auto-capture:\(verdict.providerLabel)")
                if let n = try? await honeycomb.insertNode(claim.toNode()) {
                    _ = try? await honeycomb.insertEdge(.init(sourceID: n.id, targetID: source.id, relation: .derivedFrom, weight: claim.confidence))
                    written.append(n.id)
                }
            }
            // Decisions → `.decision` nodes.
            for decision in verdict.extracted.decisions {
                guard !decision.decision.isEmpty else { continue }
                if let n = try? await honeycomb.insertNode(.init(type: .decision, label: decision.decision,
                    metadata: .object(["decision": .string(decision.decision), "decided_by": .string(decision.decidedBy),
                                       "confidence": .double(max(0.0, min(1.0, decision.confidence)))]),
                    contentHash: HoneycombStore.sha256(decision.decision), provenance: "auto-capture:\(verdict.providerLabel)")) {
                    _ = try? await honeycomb.insertEdge(.init(sourceID: n.id, targetID: source.id, relation: .derivedFrom, weight: decision.confidence))
                    written.append(n.id)
                }
            }
            // Commitments → `.task` nodes (actionable items, open status).
            for commitment in verdict.extracted.commitments {
                guard !commitment.commitment.isEmpty else { continue }
                if let n = try? await honeycomb.insertNode(.init(type: .task, label: commitment.commitment,
                    metadata: .object(["commitment": .string(commitment.commitment),
                                       "confidence": .double(max(0.0, min(1.0, commitment.confidence))), "status": .string("open")]),
                    contentHash: HoneycombStore.sha256(commitment.commitment), provenance: "auto-capture:\(verdict.providerLabel)")) {
                    _ = try? await honeycomb.insertEdge(.init(sourceID: n.id, targetID: source.id, relation: .derivedFrom, weight: commitment.confidence))
                    written.append(n.id)
                }
            }
            let kept = verdict.extracted.facts.count + verdict.extracted.decisions.count + verdict.extracted.commitments.count
            await autoCaptureAudit(eventLedger: eventLedger, targetURL: targetURL, result: .success,
                             intent: "Auto-Capture triage: kept \(kept) item(s)",
                             preview: "captureScribe(\(verdict.providerLabel)) kept \(kept) — \(written.count - 1) node(s)",
                             modelProvider: verdict.providerLabel, modelRole: ModelRole.captureScribe, contextIDs: written)
        case .skip:
            await autoCaptureAudit(eventLedger: eventLedger, targetURL: targetURL, result: .partial,
                             intent: "Auto-Capture triage: skipped",
                             preview: "captureScribe(\(verdict.providerLabel)) skipped — \(verdict.skipReason?.rawValue ?? "unknown")",
                             modelProvider: verdict.providerLabel, modelRole: ModelRole.captureScribe, contextIDs: [])
        }
    }

    /// Appends the Auto-Capture audit event (the auditable trail for both keep and skip).
    private static func autoCaptureAudit(
        eventLedger: EventLedgerStore, targetURL: String, result: EventLedgerStore.EventResult,
        intent: String, preview: String, modelProvider provider: String?, modelRole role: ModelRole?, contextIDs: [String]
    ) async {
        let event = EventLedgerStore.LedgerEvent(
            actor: role.map { $0.rawValue } ?? "swarm",
            intent: intent,
            actionKind: .capture,
            actionTarget: targetURL,
            actionPreview: preview,
            trustLevel: .t0,
            policyDecision: .allowed,
            consentState: .auto,                 // auto-capture is a T0 observe; opt-in at pref level
            contextIDs: contextIDs,
            modelProvider: provider,
            modelRole: role.map { $0.rawValue },
            result: result,
            provenance: "auto-capture"
        )
        _ = try? await eventLedger.record(event)
    }

    // MARK: - Page Q&A (scribe invocation route — PITCH/backend-completion.md A3)
    //
    // The Arc/Comet "ask on this page" parity: answer a question grounded in the active
    // page's captured text via the T0 `pageQa` Cell. When the page doesn't contain the
    // answer, `answerType == .pageDoesNotSay` — never a training guess (the pageQa prompt's
    // honesty rule). Degradation: Mock's pageQa body answers `page_does_not_say` with
    // confidence 0 — correct, honest, no fabrication. Surfaces via `@this <question>` (UI
    // frozen; routed in SwarmChatView).

    /// Answers a question about the current active page, grounded in its captured text.
    /// - Returns: a `PageQAAnswer` whose `providerLabel` makes honest degradation visible.
    @MainActor
    func askOnPage(question: String) async -> ScribeCoordinator.PageQaAnswer {
        guard let context = await extractActivePageContext() else {
            return ScribeCoordinator.PageQaAnswer(answer: "", answerType: .pageDoesNotSay, basis: [],
                                                  pageClaimUnverified: false, confidence: 0, providerLabel: "no-page")
        }
        let answer = await ScribeCoordinator.askOnPage(question: question, pageContext: context, loader: cellPromptLoader)
        // Audit the Q&A as a T0 observe (no writes — Q&A is read-only).
        if let eventLedger {
            _ = try? await eventLedger.record(EventLedgerStore.LedgerEvent(
                actor: "user",
                intent: "Ask on page: \(question)",
                actionKind: .modelCall,
                actionTarget: context.url?.absoluteString,
                actionPreview: "pageQa(\(answer.providerLabel)) → \(answer.answerType.rawValue)",
                trustLevel: .t0, policyDecision: .allowed, consentState: .auto,
                modelProvider: answer.providerLabel, modelRole: ModelRole.pageQa.rawValue,
                result: answer.answerType == .parseError ? .failure : .success,
                provenance: "page-qa"))
        }
        return answer
    }

    // MARK: - Active-tab sync

    /// Keeps `BrowserTab.isActive` honest with `activeTabID` so persisted state never lies.
    /// The view layer should prefer `state.activeTab`; this is for round-trip correctness.
    private func recomputeActive() {
        for i in tabs.indices {
            tabs[i].isActive = (tabs[i].id == activeTabID)
        }
    }

    // MARK: - Tab actions (pin / mute / duplicate / bulk close / reorder)

    /// Toggles the pinned state. Pinned tabs are favicon-only (SPEC §8.1) and archive-proof.
    /// Pinning a tab also evicts it from any group so the pinned rail remains top-level.
    func togglePin(_ id: String) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasPinned = tabs[i].isPinned
        tabs[i].isPinned.toggle()
        // Pinned tabs live above groups; evict from any group before reordering/saving.
        if !wasPinned {
            removeTabFromGroup(id)
        }
        // Re-order within the owning space so pinned tabs sit at the front (pinned-first).
        if let sid = tabs[i].spaceID, let si = spaces.firstIndex(where: { $0.id == sid }) {
            reorderSpacePinnedFirst(&spaces[si])
        }
        scheduleSessionSave()
    }

    /// Toggles mute on a tab (and its space-wide mute, since Hive tracks per-tab).
    func toggleMute(_ id: String) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[i].isMuted.toggle()
    }

    /// Duplicates a tab: opens a new tab with the same URL, in the same space, beside it.
    @discardableResult
    func duplicateTab(_ id: String) -> BrowserTab? {
        guard let tab = tabs.first(where: { $0.id == id }), let url = tab.url else { return nil }
        return newTab(url: url)
    }

    /// Closes every tab except `id`. Keeps `id` selected. Doesn't touch recently-closed.
    func closeOtherTabs(keeping id: String) {
        let toClose = visibleTabs.filter { $0.id != id }.map { $0.id }
        for cid in toClose { closeTab(cid) }
        selectTab(id)
    }

    /// Closes every tab to the right of `id` (lower index in display order). SPEC §8.1 menu.
    func closeTabsToRight(of id: String) {
        let visible = visibleTabs
        guard let idx = visible.firstIndex(where: { $0.id == id }) else { return }
        let toClose = visible[(idx + 1)...].map { $0.id }
        for cid in toClose { closeTab(cid) }
        selectTab(id)
    }

    /// Reorders tabs within the active space (drag-and-drop reorder). `from` and `to` are
    /// visible-tab indices; final-position semantics (the moved tab lands at index `to`).
    func moveVisibleTab(from: Int, to: Int) {
        let space = activeSpace
        let visible = visibleTabs
        guard from >= 0, from < visible.count,
              to >= 0, to < visible.count, from != to else { return }
        guard let si = spaces.firstIndex(where: { $0.id == space.id }) else { return }
        // Map visible indices back to Space.tabIDs positions, then use Space.moveTab.
        let movingTabID = visible[from].id
        // The destination's tabID position in the space, accounting for pinned-first order.
        let destTabID = visible[to].id
        guard let destSpaceIdx = spaces[si].tabIDs.firstIndex(of: destTabID) else { return }
        spaces[si].moveTab(movingTabID, to: destSpaceIdx)
        scheduleSessionSave()
    }

    // MARK: - Promise badges (slice 8)

    /// Attaches a lightweight promise badge to a tab (e.g. "read later").
    /// `color` is a HiveColorToken raw value; defaults to "accent".
    func setPromise(_ id: String, promise: String?, color: String = HiveColorToken.accent.rawValue) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = promise?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmpty = trimmed?.isEmpty ?? true
        tabs[i].promise = isEmpty ? nil : trimmed
        tabs[i].promiseColor = isEmpty ? nil : color
        scheduleSessionSave()
    }

    /// Clears the promise badge from a tab.
    func clearPromise(_ id: String) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[i].promise = nil
        tabs[i].promiseColor = nil
        scheduleSessionSave()
    }

    // MARK: - Tree mode (slice 7)

    /// Toggles tree mode in the vertical rail. Off by default; persists in prefs.
    func toggleTreeMode() {
        setTreeMode(!prefs.isTreeMode)
    }

    /// Sets tree mode explicitly. Used by the Settings window toggle binding.
    func setTreeMode(_ enabled: Bool) {
        guard prefs.isTreeMode != enabled else { return }
        prefs.isTreeMode = enabled
        persistPrefs()
        scheduleSessionSave()
    }

    /// True if the tab with `id` has at least one child in the current tree.
    func hasTreeChildren(_ id: String) -> Bool {
        tabs.contains { $0.parentTabID == id }
    }

    /// Adds a new tab as a child of the currently active tab. Falls back to a plain new tab
    /// if no tab is active. Returns the new tab.
    @discardableResult
    func newChildTabUnderActive() -> BrowserTab? {
        guard let activeID = activeTabID else { return newTab() }
        return newChildTab(parentID: activeID)
    }

    /// Toggles the fold state of the active tab's children. No-op if the active tab has no
    /// children. Bound to a keyboard shortcut in BrowserWindow.
    func toggleTreeFoldForActive() {
        guard let activeID = activeTabID, hasTreeChildren(activeID) else { return }
        toggleTreeFold(activeID)
    }

    /// Creates a new tab as a child of `parentID`. Returns the new tab, or nil if the parent
    /// is not found. The child is placed in the same space as the parent and selected.
    @discardableResult
    func newChildTab(parentID: String) -> BrowserTab? {
        guard let parent = tabs.first(where: { $0.id == parentID }) else { return nil }
        // Create directly in the parent's space so it doesn't also land in the active space.
        let child = newTab(url: nil, spaceID: parent.spaceID)
        // newTab() already appended to tabs and selected it; fix the parent reference on the
        // live model, not the returned value copy.
        if let idx = tabs.firstIndex(where: { $0.id == child.id }) {
            tabs[idx].parentTabID = parentID
            // Make sure the new child is visible even if the parent was folded.
            if prefs.treeCollapsedParentIDs.contains(parentID) {
                toggleTreeFold(parentID) // expands
            }
            scheduleSessionSave()
        }
        return tabs.first { $0.id == child.id }
    }

    /// Folds or unfolds the children of `parentID` in tree mode. Folding hibernates the
    /// children (and their descendants); unfolding wakes the immediate children so the user
    /// sees them. Persists the collapsed set in prefs.
    func toggleTreeFold(_ parentID: String) {
        guard tabs.first(where: { $0.id == parentID }) != nil else { return }

        var collapsed = Set(prefs.treeCollapsedParentIDs)
        let wasCollapsed = collapsed.contains(parentID)

        if wasCollapsed {
            collapsed.remove(parentID)
            // Wake immediate children. Deeper descendants whose own parent is still collapsed
            // will be hidden/hibernated by the visible-tabs filter and hibernation policy.
            let children = tabs.filter { $0.parentTabID == parentID }
            for child in children { wakeTab(child.id) }
        } else {
            collapsed.insert(parentID)
            // Hibernate all descendants so folding actually frees RAM.
            let descendants = tabs.filter { $0.hasAncestor(parentID, in: tabs) }
            for d in descendants { hibernateTab(d.id) }
        }

        prefs.treeCollapsedParentIDs = Array(collapsed)
        persistPrefs()
        scheduleSessionSave()
    }

    // MARK: - Split View (§10)

    /// True when split view is active (2–4 panes visible simultaneously).
    var isSplitActive: Bool { prefs.splitTabIDs.count >= 2 }

    /// The tabs currently participating in split view, in display order.
    /// Filters out closed/deleted/hibernated tabs that may linger in the ID array.
    var splitTabs: [BrowserTab] {
        prefs.splitTabIDs.compactMap { id in tabs.first { $0.id == id && !$0.isHibernated } }
    }

    /// Adds a tab to the split view array (max 4 panes). If the tab is already in split,
    /// removes it instead (toggle behavior). When split already has 4 tabs, adding another
    /// replaces the rightmost/bottommost pane. Persists the change.
    func toggleSplitTab(_ tabID: String) {
        if prefs.splitTabIDs.contains(tabID) {
            removeFromSplit(tabID)
        } else {
            addToSplit(tabID)
        }
    }

    /// Adds a tab to split view. Enforces the 4-pane cap (drops the last pane on overflow).
    /// Duplicates are silently skipped.
    func addToSplit(_ tabID: String) {
        guard tabs.contains(where: { $0.id == tabID }) else { return }
        var ids = prefs.splitTabIDs
        guard !ids.contains(tabID) else { return }
        ids.append(tabID)
        if ids.count > SplitConstants.maxPanes {
            ids.removeFirst() // drop the leftmost/topmost to make room
        }
        prefs.splitTabIDs = ids
        persistPrefs()
        scheduleSessionSave()
    }

    /// Removes a tab from split view. If the remaining count drops below 2, split view
    /// closes (reverts to normal single-tab layout).
    func removeFromSplit(_ tabID: String) {
        prefs.splitTabIDs.removeAll { $0 == tabID }
        // Clean up stale IDs (tabs that were closed while in split).
        prefs.splitTabIDs = prefs.splitTabIDs.filter { id in tabs.contains { $0.id == id } }
        persistPrefs()
        scheduleSessionSave()
    }

    /// Toggles split view with the active tab: if split has < 2 tabs, creates a 2-pane split
    /// using the active tab and the next visible tab (or the previously-active tab). If split
    /// already has ≥ 2 tabs, removes the active tab from split (closing split if count drops
    /// below 2). Bound to ⌘\ in BrowserWindow.
    func toggleSplit() {
        guard let activeID = activeTabID else { return }
        if prefs.splitTabIDs.count >= 2 {
            removeFromSplit(activeID)
        } else {
            // Start split with active tab + one more for an immediate 2-pane split.
            var ids = prefs.splitTabIDs
            if !ids.contains(activeID) { ids.append(activeID) }
            // Grab the next visible tab as the second pane (skip the active).
            if ids.count < 2 {
                let visible = visibleTabs
                if let next = visible.first(where: { $0.id != activeID && !ids.contains($0.id) }) {
                    ids.append(next.id)
                }
            }
            prefs.splitTabIDs = ids
            persistPrefs()
            scheduleSessionSave()
        }
    }

    /// Closes all split panes, keeping only the first tab (which becomes the active tab).
    /// Bound to ⌘⇧\ in BrowserWindow.
    func closeSplit() {
        guard let firstID = prefs.splitTabIDs.first else { return }
        prefs.splitTabIDs = []
        selectTab(firstID)
        persistPrefs()
        scheduleSessionSave()
    }

    /// Cycles the split orientation between horizontal and vertical.
    /// Bound to ⌘⌥\ in BrowserWindow.
    func cycleSplitOrientation() {
        prefs.splitOrientation = prefs.splitOrientation.toggled
        persistPrefs()
        scheduleSessionSave()
    }

    // MARK: - Content blocker toggle

    /// Whether the built-in ad/tracker blocker is active. Defaults to true.
    var isContentBlockerEnabled: Bool { prefs.contentBlockerEnabled }

    /// Enables or disables the content blocker. When enabled, compiles and applies
    /// the built-in blocklist to all webviews. When disabled, removes the blocklist.
    /// Content blocking is privacy-first by default.
    func setContentBlockerEnabled(_ enabled: Bool) {
        guard prefs.contentBlockerEnabled != enabled else { return }
        prefs.contentBlockerEnabled = enabled
        persistPrefs()
        scheduleSessionSave()
        Task {
            if enabled {
                try? await ContentBlockerController.shared.compileBuiltInRules()
            } else {
                await ContentBlockerController.shared.remove()
            }
        }
    }

    /// Whether HTTPS-only mode is active. Defaults to true.
    var isHTTPSEnforced: Bool { prefs.enforceHTTPS }

    /// Enables or disables HTTPS-only enforcement. When enabled, all HTTP requests
    /// are upgraded to HTTPS; insecure connections are blocked when the upgrade fails.
    func setHTTPSEnforced(_ enabled: Bool) {
        guard prefs.enforceHTTPS != enabled else { return }
        prefs.enforceHTTPS = enabled
        persistPrefs()
        scheduleSessionSave()
    }

    /// Whether Global Privacy Control (Sec-GPC: 1) is enabled. Defaults to true.
    var isGPCEnabled: Bool { prefs.globalPrivacyControlEnabled }

    /// Enables or disables the Global Privacy Control (GPC) header. When enabled,
    /// every page request includes the Sec-GPC: 1 header signaling "Do Not Sell or
    /// Share My Personal Information." Requires a new webview for the toggle to
    /// take full effect (injected at WKWebViewConfiguration init time).
    func setGlobalPrivacyControl(_ enabled: Bool) {
        guard prefs.globalPrivacyControlEnabled != enabled else { return }
        prefs.globalPrivacyControlEnabled = enabled
        persistPrefs()
        scheduleSessionSave()
    }

    // MARK: - Theme & appearance (SPEC §23)

    /// Sets the visual theme (system / dark / light). Persists the choice.
    func setTheme(_ theme: HiveTheme) {
        guard prefs.theme != theme else { return }
        prefs.theme = theme
        persistPrefs()
    }

    /// Sets the accent color by HiveColorToken name (e.g. "accent" for the default
    /// warm amber, or a custom token name like "gold", "ruby", etc.). Falls back to
    /// the default Hive amber at read time if the token is unrecognized.
    func setAccentColor(_ tokenName: String) {
        let trimmed = tokenName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, prefs.accentColorName != trimmed else { return }
        prefs.accentColorName = trimmed
        persistPrefs()
    }

    /// Resolves the current theme preference to a SwiftUI ColorScheme value that
    /// HiveApp passes as `preferredColorScheme`. `.system` maps to nil (follow OS).
    var resolvedColorScheme: ColorScheme? {
        switch prefs.theme {
        case .hiveDark:  return .dark
        case .hiveLight: return .light
        case .system:    return nil
        }
    }

    // MARK: - BYOK (Bring Your Own Key) model provider

    /// Saves the BYOK API key to the keychain under the given alias and persists the alias
    /// in prefs (so the runtime can resolve it later). Call from the settings UI on Save.
    /// Throws `ChromeStateError.noSecretStore` if the state was created without a secret store.
    @MainActor
    func saveBYOKKey(_ key: String, alias: String) async throws {
        guard let secretStore else { throw ChromeStateError.noSecretStore }
        try await secretStore.save(key, for: alias)
        prefs.byokKeyAlias = alias
        persistPrefs()
    }

    /// Deletes a BYOK API key from the keychain, clears its alias from prefs, and disables
    /// BYOK so the runtime does not keep trying the deleted key. No-op if the keychain item
    /// is already absent.
    @MainActor
    func deleteBYOKKey(alias: String) async throws {
        guard let secretStore else { throw ChromeStateError.noSecretStore }
        try await secretStore.delete(for: alias)
        if prefs.byokKeyAlias == alias { prefs.byokKeyAlias = "" }
        // Disable BYOK so a stale runtime cannot use the deleted key.
        if prefs.byokEnabled {
            prefs.byokEnabled = false
        }
        persistPrefs()
        Task { await refreshBYOKDispatcher() }
    }

    /// Updates the BYOK provider configuration and refreshes the shared Dispatcher so the
    /// next Swarm query routes to the remote model when enabled. Persists all fields.
    /// Throws `ChromeStateError.invalidBYOKURL` if the base URL is not a valid HTTPS URL.
    @MainActor
    func setBYOKConfig(baseURL: String, modelID: String, keyAlias: String, enabled: Bool) throws {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme == "https",
              !(url.host?.isEmpty ?? true) else {
            throw ChromeStateError.invalidBYOKURL(trimmed)
        }
        prefs.byokBaseURL = trimmed
        prefs.byokModelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.byokKeyAlias = keyAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.byokEnabled = enabled
        persistPrefs()
        Task { await refreshBYOKDispatcher() }
    }

    /// Updates the Vane (Perplexica) web-search configuration and persists it. Does not
    /// require a valid URL at save time; the provider is resolved lazily from prefs.
    @MainActor
    func setTavilyConfig(enabled: Bool) {
        guard prefs.tavilyEnabled != enabled else { return }
        prefs.tavilyEnabled = enabled
        persistPrefs()
    }

    func setVaneConfig(baseURL: String, enabled: Bool, focusMode: WebSearchFocusMode) {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        prefs.vaneBaseURL = trimmed
        prefs.vaneEnabled = enabled
        prefs.vaneDefaultFocusMode = focusMode
        persistPrefs()
    }

    /// Refreshes `Dispatcher.shared` with a BYOKRuntime configured from current prefs and
    /// the keychain. Call on launch and whenever BYOK prefs change. Safe to call repeatedly.
    @MainActor
    func refreshBYOKDispatcher() async {
        guard prefs.byokEnabled,
              !prefs.byokBaseURL.isEmpty,
              !prefs.byokModelID.isEmpty,
              !prefs.byokKeyAlias.isEmpty,
              let secretStore,
              let baseURL = URL(string: prefs.byokBaseURL),
              baseURL.scheme == "https" else {
            await Dispatcher.shared.setBYOK(nil)
            return
        }
        let keyAlias = prefs.byokKeyAlias
        let runtime = BYOKRuntime(
            config: .init(baseURL: baseURL, apiKeyAlias: keyAlias, modelID: prefs.byokModelID),
            keyResolver: { alias in
                try? await secretStore.get(for: alias)
            }
        )
        await Dispatcher.shared.setBYOK(runtime)
    }

    // MARK: - DNS / Proxy setters

    /// Sets the DNS-over-HTTPS resolver URL. Empty = system default.
    func setDOHResolver(_ url: String) {
        guard prefs.dohResolver != url else { return }
        prefs.dohResolver = url
        persistPrefs()
        scheduleSessionSave()
    }

    /// Sets the DNS-over-TLS resolver host. Empty = system default.
    func setDOTResolver(_ host: String) {
        guard prefs.dotResolver != host else { return }
        prefs.dotResolver = host
        persistPrefs()
        scheduleSessionSave()
    }

    /// Sets proxy configuration. All fields are written atomically.
    func setProxyConfig(type: String, host: String, port: Int,
                        username: String, pacURL: String, bypassLocal: Bool) {
        prefs.proxyType = type
        prefs.proxyHost = host
        prefs.proxyPort = port
        prefs.proxyUsername = username
        prefs.pacFileURL = pacURL
        prefs.proxyBypassLocal = bypassLocal
        persistPrefs()
        scheduleSessionSave()
    }

    // MARK: - Space bookkeeping

    /// Moves all pinned tabs to the front of a space's tabIDs (pinned-first display order).
    private func reorderSpacePinnedFirst(_ space: inout Space) {
        let pinned = space.tabIDs.filter { id in
            tabs.first { $0.id == id }?.isPinned == true
        }
        let unpinned = space.tabIDs.filter { id in
            tabs.first { $0.id == id }?.isPinned != true
        }
        space.tabIDs = pinned + unpinned
    }

    // MARK: - Tab Group operations (§5)

    /// Creates a new group in the given space, optionally wrapping the provided tab IDs into it.
    /// Returns the fresh group. The space's `groups` array is appended; the space org is persisted
    /// immediately (scheduled save). If `tabIDs` are given, each tab is scooped out of the
    /// ungrouped pool and placed into the group (group membership is exclusive).
    @discardableResult
    func createGroup(name: String, in spaceID: String, tabIDs: [String] = [],
                     colorDot: String = HiveColorToken.accent.rawValue) -> TabGroup? {
        guard let si = spaces.firstIndex(where: { $0.id == spaceID }) else { return nil }
        let group = TabGroup(name: name, colorDot: colorDot, tabIDs: tabIDs)
        spaces[si].groups.append(group)
        // Remove group-scoped tabs from the space-level ungrouped pool (exclusive membership).
        if !tabIDs.isEmpty {
            spaces[si].tabIDs.removeAll { tabIDs.contains($0) }
        }
        // If the active tab is the last-active in the group, record it.
        if let active = activeTabID, tabIDs.contains(active) {
            spaces[si].groups[spaces[si].groups.count - 1].lastActiveTabID = active
        }
        scheduleSessionSave()
        return group
    }

    /// Folds a group — hibernates all its tabs (the §8 policy's "folded-group-member → now"
    /// precedence), records the last-active tab for UNfold focus restore, and sets `isFolded`.
    /// Unfolding reverses this (wakes the last-active tab from its broker sprite). Idempotent.
    func toggleGroupFold(_ groupID: String) {
        for si in spaces.indices {
            guard let gi = spaces[si].groups.firstIndex(where: { $0.id == groupID }) else { continue }
            let wasFolded = spaces[si].groups[gi].isFolded
            if wasFolded {
                // Unfold — wake the last-active tab (or first). The §8 on-focus wake handles it.
                spaces[si].groups[gi].isFolded = false
                if let lastID = spaces[si].groups[gi].lastActiveTabID,
                   let tbi = tabs.firstIndex(where: { $0.id == lastID }) {
                    tabs[tbi].isHibernated = false
                    // Restore focus to the group's last-active tab on unfold.
                    if activeTabID != lastID {
                        selectTab(lastID)
                    }
                } else if let firstID = spaces[si].groups[gi].tabIDs.first,
                          let tbi = tabs.firstIndex(where: { $0.id == firstID }) {
                    tabs[tbi].isHibernated = false
                    if activeTabID != firstID {
                        selectTab(firstID)
                    }
                }
            } else {
                // Fold — hibernate each tab in the group, record last-active before teardown.
                spaces[si].groups[gi].isFolded = true
                if let active = activeTabID, spaces[si].groups[gi].tabIDs.contains(active) {
                    spaces[si].groups[gi].lastActiveTabID = active
                }
                for tid in spaces[si].groups[gi].tabIDs {
                    hibernateTab(tid)
                }
                // If the active tab just got folded away, move focus to a safe visible tab
                // so the content area doesn't point at a hibernated tab.
                if let active = activeTabID, spaces[si].groups[gi].tabIDs.contains(active) {
                    let visible = visibleTabs
                    if let next = visible.first(where: { $0.id != active }) {
                        selectTab(next.id)
                    } else {
                        activeTabID = nil
                        recomputeActive()
                    }
                }
            }
            scheduleSessionSave()
            return
        }
    }

    /// Adds a tab to a group (removes it from the space's ungrouped pool — group membership
    /// is exclusive: a tab can belong to at most one group at a time).
    func addTabToGroup(_ tabID: String, groupID: String) {
        // Find the tab and its owning space.
        guard let tab = tabs.first(where: { $0.id == tabID }),
              let spaceID = tab.spaceID,
              let si = spaces.firstIndex(where: { $0.id == spaceID }),
              let gi = spaces[si].groups.firstIndex(where: { $0.id == groupID }) else { return }
        // Remove from other groups in the SAME space (exclusive membership).
        for i in spaces[si].groups.indices where i != gi {
            spaces[si].groups[i].tabIDs.removeAll { $0 == tabID }
        }
        // Scoop out of the space-level ungrouped pool.
        spaces[si].tabIDs.removeAll { $0 == tabID }
        // Add to target group if not already there.
        if !spaces[si].groups[gi].tabIDs.contains(tabID) {
            spaces[si].groups[gi].tabIDs.append(tabID)
        }
        scheduleSessionSave()
    }

    /// Removes a tab from its group, placing it back in the space's ungrouped pool.
    /// Returns true if the tab was actually in a group.
    @discardableResult
    func removeTabFromGroup(_ tabID: String) -> Bool {
        for si in spaces.indices {
            for gi in spaces[si].groups.indices where spaces[si].groups[gi].tabIDs.contains(tabID) {
                spaces[si].groups[gi].tabIDs.removeAll { $0 == tabID }
                // Return to the space's ungrouped pool.
                spaces[si].tabIDs.append(tabID)
                scheduleSessionSave()
                return true
            }
        }
        return false
    }

    /// Renames a group (an opacity-affordance title change; no structural mutation).
    func renameGroup(_ groupID: String, to name: String) {
        for si in spaces.indices {
            guard let gi = spaces[si].groups.firstIndex(where: { $0.id == groupID }) else { continue }
            spaces[si].groups[gi].name = name
            scheduleSessionSave()
            return
        }
    }

    /// Deletes a group, freeing its tabs back to the space's ungrouped pool. The group model
    /// itself is removed; tabs survive (contrast with close-all-tabs, which deletes tabs).
    func deleteGroup(_ groupID: String) {
        for si in spaces.indices {
            guard let gi = spaces[si].groups.firstIndex(where: { $0.id == groupID }) else { continue }
            let orphaned = spaces[si].groups[gi].tabIDs
            spaces[si].groups.remove(at: gi)
            // Return orphans to the ungrouped level.
            for tid in orphaned where !spaces[si].tabIDs.contains(tid) {
                spaces[si].tabIDs.append(tid)
            }
            scheduleSessionSave()
            return
        }
    }

    // MARK: - Persistence helpers

    private func persistPrefs() {
        guard let store = prefsStore else { return }
        let snapshot = prefs
        Task { try? await store.save(snapshot) }
    }

    /// Resolves a site permission for a live tab. Private tabs deliberately return
    /// `.ask` and never inherit durable normal-profile grants.
    @MainActor
    func sitePermissionState(host: String, kind: SitePermissionKind, isPrivate: Bool) -> SitePermissionState {
        SitePermissionPolicy.state(
            forHost: host,
            kind: kind,
            permissions: prefs.sitePermissions,
            isPrivate: isPrivate
        )
    }

    /// Persists a site permission decision for a normal tab. Private tabs are a
    /// no-op: their permission prompts are ephemeral and cannot alter durable prefs.
    @MainActor
    func setSitePermission(host: String, kind: SitePermissionKind,
                           state: SitePermissionState, isPrivate: Bool) {
        guard !isPrivate else { return }
        prefs.sitePermissions = SitePermissionPolicy.applying(
            state,
            forHost: host,
            kind: kind,
            to: prefs.sitePermissions,
            isPrivate: false
        )
        persistPrefs()
    }

    /// Toggles whether Swarm may inspect a tab's page text. This is deliberately
    /// per-tab and follows the durable session snapshot; it does not alter browsing,
    /// bookmarks, history, or explicit manual capture.
    @MainActor
    func setAIContextAllowed(tabID: String, allowed: Bool) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }), !tabs[index].isPrivate else { return }
        tabs[index].isAIContextAllowed = allowed
        if !allowed {
            pageContextBroker.cancel(for: tabID)
            pageCaptureLedger.cancelPendingAutoCapture(for: tabID)
        }
        scheduleSessionSave()
    }

    private func recordClosedTabAsync(_ record: ClosedTabRecord) {
        // Mutate the in-memory stack synchronously so the UI (reopen menu, ⌘⇧T) is instant
        // — same cap + dedup-by-URL the store enforces, applied locally first.
        prefs.recentlyClosed.removeAll { $0.url == record.url }
        prefs.recentlyClosed.insert(record, at: 0)
        let cap = Array<ClosedTabRecord>.hiveClosedTabCap
        if prefs.recentlyClosed.count > cap {
            prefs.recentlyClosed = Array(prefs.recentlyClosed.prefix(cap))
        }
        // Persist a Sendable snapshot. We deliberately do NOT read the result back —
        // `self` is a non-Sendable @Observable, so crossing actor isolation to write `prefs`
        // back would race. The in-memory copy above is already authoritative.
        guard let store = prefsStore else { return }
        let snapshot = prefs
        Task { try? await store.save(snapshot) }
    }

    // MARK: - Session persistence + restore (design doc §9)
    //
    // `ChromeState` is the live, observable, non-Sendable truth; `BrowserSession` is its
    // Codable/Sendable projection that crosses the actor into `BrowserSessionStore`. Every
    // structural mutation (new/close/select/nav/reorder/pin/layout…) calls `scheduleSessionSave`,
    // which hands a fresh snapshot to the store's 2s debounced write. App termination calls the
    // synchronous `flushSessionSync` so the last state lands before the process exits.

    /// Builds a durable snapshot of everything a user trusts the browser not to lose: the union
    /// of tabs, all spaces (with their tabIDs + groups + activeTabID), the frontmost space/tab,
    /// and the layout + density. Single-window today; multi-window is a later additive.
    func makeSessionSnapshot() -> BrowserSession {
        let window = BrowserSessionWindow(
            spaces: spaces,
            tabs: tabs,
            // activeSpace is non-optional (falls back to a default), but a freshly-minted
            // default's UUID won't match a real window space — record nil when there are none.
            activeSpaceID: spaces.isEmpty ? nil : activeSpace.id,
            activeTabID: activeTabID,
            layout: prefs.tabPosition,
            density: prefs.tabDensity
        )
        return BrowserSession(windows: [window], archivedTabs: archivedTabs)
    }

    /// Schedules a coalesced debounced save (§9: 2s) of the current session. Cheap to call on
    /// every mutation — the store collapses a burst into a single write after the last change.
    func scheduleSessionSave() {
        guard let store = sessionStore else { return }
        let snapshot = makeSessionSnapshot()
        Task { await store.scheduleSave(snapshot) }
    }

    /// Synchronous terminal flush (`applicationWillTerminate` path): cannot `await` an actor from
    /// the notification handler, so the store writes synchronously through its nonisolated
    /// `flushSync`. Best-effort; if it misses, the prior debounced write (or the rolling
    /// backup) covers the gap.
    func flushSessionSync() {
        guard let store = sessionStore else { return }
        store.flushSync(makeSessionSnapshot())
    }

    /// Restores the in-memory state from a loaded session (called once at launch from
    /// HiveApp, after prefs are loaded). Dedups tabs by id, drains membership into each space
    /// (drops orphan tabIDs whose tabs are absent — a partial/corrupt session must not pull
    /// phantom tabs into the view), and restores the frontmost selection + layout/density.
    /// `recovery` carries the launch-time notice (normal / recovered-from-backup / lost-no-
    /// backup) so the window can surface the §9 choice.
    func restore(from session: BrowserSession, recovery: SessionRecoveryNotice = .none) {
        guard let window = session.windows.first, !window.spaces.isEmpty else {
            // No restorable window → leave a clean one-tab seed to HiveApp's fallback.
            sessionRecoveryNotice = recovery
            return
        }
        // 1. Spaces — dedup by id, preserve order. Always at least one (default) post-restore.
        var seen = Set<String>()
        let restoredSpaces = window.spaces.filter { seen.insert($0.id).inserted }
        self.spaces = restoredSpaces.isEmpty ? [Space.defaultSpace()] : restoredSpaces
        // 2. Tabs — dedup by id; strip transient load state so restored tabs read "ready", not
        //    "mid-load" (the webview reclaims live URLs; hibernated tabs wake losslessly).
        var tabSeen = Set<String>()
        let restoredTabs = window.tabs.filter { tabSeen.insert($0.id).inserted }
        self.tabs = restoredTabs.map { tab -> BrowserTab in
            var t = tab
            t.isLoading = false
            t.loadProgress = 0
            t.isActive = false
            return t
        }
        // 3. Clean each space's memberships to tabs that actually exist (no phantom tabIDs).
        let liveTabIDs = Set(self.tabs.map(\.id))
        for i in self.spaces.indices {
            self.spaces[i].tabIDs = self.spaces[i].tabIDs.filter { liveTabIDs.contains($0) }
            if let active = self.spaces[i].activeTabID, !liveTabIDs.contains(active) {
                self.spaces[i].activeTabID = self.spaces[i].tabIDs.last
            }
            for g in self.spaces[i].groups.indices {
                self.spaces[i].groups[g].tabIDs = self.spaces[i].groups[g].tabIDs
                    .filter { liveTabIDs.contains($0) }
            }
        }
        // 4. Frontmost tab — the saved one if it survived, else the active space's, else any.
        let liveActiveTab = window.activeTabID.flatMap { id in self.tabs.first { $0.id == id } }
        let liveActiveSpace = window.activeSpaceID.flatMap { id in self.spaces.first { $0.id == id } }
        let resolvedActiveTab = liveActiveTab
            ?? (liveActiveSpace?.activeTabID).flatMap { id in self.tabs.first { $0.id == id } }
            ?? self.spaces.first?.tabIDs.last.flatMap { id in self.tabs.first { $0.id == id } }
            ?? self.tabs.first
        self.activeTabID = resolvedActiveTab?.id
        if let s = liveActiveSpace, self.spaces.first?.id != s.id {
            // Keep the saved space frontmost if it's not already first (purely informational —
            // the chrome picks tabs off `activeTab`/`activeSpace`; we don't reorder for a single
            // window, but we record the intent for multi-window restore later).
            _ = s
        }
        // 5. Layout + density restored into prefs (the §9 "no snap" contract).
        prefs.tabPosition = window.layout
        prefs.tabDensity = window.density
        prefs.activeSpaceID = liveActiveSpace?.id
        self.sessionRecoveryNotice = recovery
        recomputeActive()
        // Restore archive records from the session (the §7 "Recently Archived" tier).
        archivedTabs = session.archivedTabs.filter { !$0.isPrivate }
        // Don't seed-save immediately; let the user's first mutation (or termination) write.
    }

    /// The §9 "Start fresh" recovery action — clears every tab/space and seeds one new tab,
    /// dismissing the recovery notice. Invoked by the BrowserWindow alert when the user, faced
    /// with a restored-from-backup or lost-no-backup session, chooses to abandon the offered
    /// state. The session store then holds the previous JSON untouched (plus its backup), so
    /// the choice is reversible until the next mutation overwrites current.
    func startFresh() {
        tabs = []
        spaces = [Space.defaultSpace()]
        activeTabID = nil
        hibernateRequests = [:]
        for tid in sessionBroker.tabIDs { sessionBroker.clear(tabID: tid) }  // drain sprites
        archivedTabs = []
        sessionRecoveryNotice = .none
        newTab()   // seeds one "New Tab" + schedules a save
    }

    // MARK: - Profile switching

    /// Switches to a different browser profile: saves the current session, tears down all
    /// in-memory state, switches the profile in ProfileManager, and loads the new profile's
    /// persisted session/prefs. Falls back to a fresh start if the new profile has no session.
    /// Called from ProfileSwitcherView when the user selects a different profile.
    func switchProfileAndReload(to profileID: String) async {
        guard let sessionStore else { return }
        // 1. Save current state before tearing down.
        flushSessionSync()
        persistPrefs()

        // 2. Switch the profile in the manager and fetch the active profile.
        let switched = await profileManager.switchTo(profileID)
        guard switched else { return }
        let profile = await profileManager.activeProfile
        let profileName = profile.name
        let profileDir = profile.profileDirectory

        // 3. Tear down current in-memory state.
        for tid in sessionBroker.tabIDs { sessionBroker.clear(tabID: tid) }
        tabs = []
        spaces = [Space.defaultSpace()]
        activeTabID = nil
        hibernateRequests = [:]
        captureRequests = [:]
        pageCaptureLedger = PageCaptureRequestLedger()
        readerModeRequests = [:]
        readerArtifacts = [:]
        archivedTabs = []
        thumbnailData = [:]
        findInPageRequests = [:]
        isFindInPageActive = false
        sessionRecoveryNotice = .none

        // 4. Load the new profile's prefs from its profile directory.
        let prefsURL = profileDir.appendingPathComponent("prefs.json")
        if let data = try? Data(contentsOf: prefsURL),
           let newPrefs = try? JSONDecoder().decode(ChromeUserPrefs.self, from: data) {
            self.prefs = newPrefs
        } else {
            self.prefs = .defaults
        }

        // 5. Load the new profile's session from its profile directory.
        let sessionURL = profileDir.appendingPathComponent("session.json")
        if let data = try? Data(contentsOf: sessionURL),
           let newSession = try? JSONDecoder().decode(BrowserSession.self, from: data) {
            restore(from: newSession, recovery: .none)
        } else {
            // No session for this profile — start fresh.
            newTab()
        }

        // 6. Record the profile switch in EventLedger.
        if let ledger = eventLedger {
            let event = EventLedgerStore.LedgerEvent(
                actor: "user",
                intent: "Switch browser profile to \(profileName)",
                actionKind: .modelCall,
                actionTarget: profileID,
                actionPreview: "Switched to profile: \(profileName)",
                trustLevel: .t0,
                policyDecision: .allowed,
                consentState: .auto,
                result: .success,
                provenance: "profile-switch"
            )
            _ = try? await ledger.record(event)
        }

        // 7. Persist the new state.
        scheduleSessionSave()
    }

    // MARK: - Hibernation control (§8)
    //
    // `hibernationTick` runs the §8 policy table against the live state and hibernates every
    // tab it returns. The timer in BrowserWindow drives the cadence (~30s); the *decision* is
    // always the pure `HibernationPolicy.evaluate` so the rules are exhaustively testable. The
    // *mechanism* (capture + tear-down) lives here so the view layer stays dumb.
    func hibernationTick(now: Date = Date(),
                         audioPlayingTabIDs: Set<String> = [],
                         thresholds: HibernationPolicy.Thresholds = .defaults) {
        let toHibernate = HibernationPolicy.evaluate(
            tabs: tabs, spaces: spaces,
            activeTabID: activeTabID,
            activeSpaceID: spaces.isEmpty ? nil : activeSpace.id,
            audioPlayingTabIDs: audioPlayingTabIDs,
            now: now, thresholds: thresholds)
        for id in toHibernate { hibernateTab(id) }
    }

    /// Hibernates a tab: bumps its hibernate-request counter so the live Coordinator captures
    /// its `interactionState` into the broker (during updateNSView, while still alive), then
    /// emits `.hibernated` — which `applyWebViewUpdate` turns into `isHibernated = true`, and
    /// the next render drops the WKWebView (RAM freed). Capture is guaranteed to precede
    /// teardown because both originate from the same updateNSView pass, in order. Idempotent on
    /// an already-hibernated tab.
    func hibernateTab(_ id: String) {
        guard let i = tabs.firstIndex(where: { $0.id == id }), !tabs[i].isHibernated else { return }
        // Bump the request counter → the Coordinator captures + emits `.hibernated` on its next
        // updateNSView pass; applyWebViewUpdate flips isHibernated from that emission.
        hibernateRequests[id, default: 0] &+= 1
    }

    /// Wakes a hibernated tab (also done implicitly by `selectTab`). Flips the model flag so
    /// contentFill rebuilds the area; the fresh Coordinator restores losslessly from the broker
    /// sprite in makeNSView. No-op on an already-awake tab.
    func wakeTab(_ id: String) {
        guard let i = tabs.firstIndex(where: { $0.id == id }), tabs[i].isHibernated else { return }
        tabs[i].isHibernated = false
        scheduleSessionSave()
    }

    // MARK: - Auto-archive (§7)

    /// Runs the archive policy against all tabs, archives cold ones (hibernates + records +
    /// removes from space/group), and persists. Called on a ~daily cadence from the timer in
    /// BrowserWindow. Pinned/active/unfolded tabs are never candidates per §7 rules.
    /// Capped at 500 archive records; oldest drops on overflow.
    func archiveTick(now: Date = Date(), threshold: TimeInterval = 14 * 86_400) {
        let pinned = Set(tabs.filter(\.isPinned).map(\.id))
        // Collect all tab IDs that are in folded groups (the group keeps them warm).
        var folded = Set<String>()
        for sp in spaces {
            for g in sp.groups where g.isFolded {
                folded.formUnion(g.tabIDs)
            }
        }
        let toArchive = AutoArchivePolicy.evaluate(
            tabs: tabs,
            pinnedTabIDs: pinned,
            activeTabID: activeTabID,
            foldedGroupTabIDs: folded,
            now: now,
            threshold: threshold
        )
        for tid in toArchive {
            guard let tab = tabs.first(where: { $0.id == tid }) else { continue }
            // Archiving = hibernate (capture sprite) + write record + remove from space.
            hibernateTab(tid)
            let record = ArchivedTab(
                id: tab.id,
                title: tab.displayTitle,
                url: tab.url,
                faviconURL: tab.faviconURL,
                sourceSpaceID: tab.spaceID,
                sourceGroupID: groupOwning(tab.id)?.id,
                archivedAt: now,
                lastVisitedAt: tab.lastVisitedAt,
                isPrivate: tab.isPrivate
            )
            archivedTabs.append(record)
            // Remove from the owning space (and group).
            if let sid = tab.spaceID, let si = spaces.firstIndex(where: { $0.id == sid }) {
                spaces[si].removeTab(tid)
                for gi in spaces[si].groups.indices {
                    spaces[si].groups[gi].tabIDs.removeAll { $0 == tid }
                }
            }
        }
        // Remove the archived tabs from the live tabs array (cleanup post-space removal).
        tabs.removeAll { toArchive.contains($0.id) }
        // preferences: max 500 records
        let cap = 500
        if archivedTabs.count > cap {
            archivedTabs = Array(archivedTabs.suffix(cap))
        }
        scheduleSessionSave()
    }

    /// Returns the group that owns a given tab ID, if any (public so views can offer
    /// "Remove from Group" contextually).
    func groupContaining(_ tabID: String) -> TabGroup? {
        for sp in spaces {
            for g in sp.groups where g.tabIDs.contains(tabID) {
                return g
            }
        }
        return nil
    }

    /// Returns the group that owns a given tab ID, if any.
    private func groupOwning(_ tabID: String) -> TabGroup? {
        for sp in spaces {
            for g in sp.groups where g.tabIDs.contains(tabID) {
                return g
            }
        }
        return nil
    }

    /// Restores a tab from the archive: removes the record, creates a live BrowserTab, adds it
    /// to the active space, and hibernates it (it was captured before archive). Returns the
    /// restored tab so the caller can select/show it. nil if the archive record wasn't found.
    @discardableResult
    func restoreArchivedTab(_ id: String) -> BrowserTab? {
        guard let idx = archivedTabs.firstIndex(where: { $0.id == id }) else { return nil }
        let record = archivedTabs.remove(at: idx)
        // The archived tab has an interactionState sprite in the broker — start hibernated
        // (frozen); click-to-wake restores it.
        var tab = BrowserTab(
            url: record.url,
            title: record.title,
            faviconURL: record.faviconURL,
            isActive: false,
            spaceID: record.sourceSpaceID ?? activeSpace.id,
            lastVisitedAt: record.lastVisitedAt
        )
        tab.isHibernated = false   // will be woken when selected
        tabs.append(tab)
        // Place it in the source space (or active space if source was deleted).
        let targetSpace = record.sourceSpaceID.flatMap { id in spaces.first { $0.id == id } }
        let spaceID = targetSpace?.id ?? activeSpace.id
        if let si = spaces.firstIndex(where: { $0.id == spaceID }) {
            spaces[si].addTab(tab.id)
            if let gid = record.sourceGroupID,
               let gi = spaces[si].groups.firstIndex(where: { $0.id == gid }) {
                spaces[si].groups[gi].tabIDs.append(tab.id)
            }
        }
        scheduleSessionSave()
        return tab
    }
}


// MARK: - ChromeStateError

public enum ChromeStateError: Error, LocalizedError {
    case noSecretStore
    case invalidBYOKURL(String)

    public var errorDescription: String? {
        switch self {
        case .noSecretStore:
            return "Keychain secret store is not available."
        case .invalidBYOKURL(let url):
            return "BYOK base URL is invalid or not HTTPS: \(url)"
        }
    }
}

    // MARK: - Zoom (⌘+/⌘-/⌘0)
