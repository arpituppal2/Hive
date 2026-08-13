import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit

/// Prevents URLSession from following redirects behind SourceFetcher’s back.
/// Returning nil gives the fetcher the 3xx response so it can resolve the
/// Location header itself and re-run scheme/SSRF policy on every hop.
final class HiveRedirectBlockingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

// MARK: - BrowserState
//
// The single source of truth for the Chromium browser shell. Browser-first: tabs, a layout
// mode, and a URL. Each tab owns a CefWebViewModel so the chrome can call navigation methods
// directly and observe title/loading/back/forward. Local AI Skills and tab groups live here too.

@Observable
@MainActor
final class BrowserState {

    // MARK: - Workspace
    struct Workspace: Identifiable, Hashable, Sendable {
        let id: UUID
        var name: String
        var colorHex: String
        var iconName: String
        var profileID: UUID

        init(id: UUID = UUID(), name: String, colorHex: String, iconName: String, profileID: UUID) {
            self.id = id
            self.name = name
            self.colorHex = colorHex
            self.iconName = iconName
            self.profileID = profileID
        }

        var swiftUIColor: Color {
            Color(hex: colorHex) ?? Color.hiveAccent
        }
    }

    // MARK: - Profile
    struct Profile: Identifiable, Hashable, Sendable {
        let id: UUID
        var name: String
        var iconName: String
        var colorHex: String

        init(id: UUID = UUID(), name: String, iconName: String, colorHex: String) {
            self.id = id
            self.name = name
            self.iconName = iconName
            self.colorHex = colorHex
        }

        var swiftUIColor: Color {
            Color(hex: colorHex) ?? Color.hiveAccent
        }
    }

    // MARK: - TabGroup
    struct TabGroup: Identifiable, Hashable, Sendable {
        let id: UUID
        var name: String
        var colorHex: String
        var workspaceID: UUID
        /// Visibility-only collapse state. Renderer lifetime is decided by the
        /// hibernation adapter; collapsing never bypasses its safety guards.
        var isCollapsed: Bool

        init(id: UUID = UUID(), name: String, colorHex: String, workspaceID: UUID, isCollapsed: Bool = false) {
            self.id = id
            self.name = name
            self.colorHex = colorHex
            self.workspaceID = workspaceID
            self.isCollapsed = isCollapsed
        }

        var swiftUIColor: Color {
            Color(hex: colorHex) ?? Color.hiveAccent
        }
    }

    enum TabLayout: String, CaseIterable, Identifiable, Sendable {
        case horizontal = "Horizontal"   // Chrome / Edge / Comet look
        case vertical = "Vertical"     // Zen / Arc / Dia look

        var id: String { rawValue }
        var title: String {
            switch self {
            case .horizontal: return "Horizontal"
            case .vertical:   return "Vertical"
            }
        }
        var icon: String {
            switch self {
            case .horizontal: return "rectangle.topthird.inset.filled"
            case .vertical:   return "rectangle.lefthalf.inset.filled"
            }
        }
    }

    /// Where the web chrome shell sits in the window: a left sidebar
    /// (vertical tabs, Arc/Zen/Dia style) or a top strip (horizontal tabs,
    /// Chrome/Brave style). The chrome itself is web content — this enum only
    /// describes the native frame it is given.
    enum ChromeMode: String, Sendable {
        case sidebar
        case strip
    }

    /// The URL of the web chrome shell — the persistent browser that renders
    /// the entire UI (tab strip, toolbar, panels). Distinct from
    /// ``webChromeStartURL`` which is the per-tab start page.
    static let webChromeURL = URL(string: "hive://start?chrome=1")!

    @MainActor
    final class Tab: Identifiable {
        let id: String
        var model: CefWebViewModel
        var isPinned: Bool
        var isEssential: Bool
        var workspaceID: UUID
        var profileID: UUID
        var groupID: UUID?
        /// Private tabs use an ephemeral CEF profile and never enter durable browser state.
        let isPrivate: Bool

        var isHibernated: Bool = false
        var lastAccessed: Date = Date()
        var savedURL: URL? = nil
        /// User-assigned nickname (Arc/Safari-style tab rename). Wins over the
        /// live page title in every tab surface; nil means "use the page title".
        /// Persisted with the session envelope for non-private tabs.
        var customTitle: String? = nil

        init(id: String = UUID().uuidString, url: URL? = nil, workspaceID: UUID, profileID: UUID, groupID: UUID? = nil, isPinned: Bool = false, isEssential: Bool = false, isPrivate: Bool = false, profile: CefProfile? = nil, savedURL: URL? = nil, customTitle: String? = nil) {
            self.id = id
            self.isPrivate = isPrivate
            self.savedURL = savedURL
            self.customTitle = customTitle
            var opts = CefBrowserOptions()
            opts.profile = profile
            self.model = CefWebViewModel(url: url, options: opts)
            self.isPinned = isPinned
            self.isEssential = isEssential
            self.workspaceID = workspaceID
            self.profileID = profileID
            self.groupID = groupID
            self.lastAccessed = Date()
        }
    }

     var tabs: [Tab] = []

    /// Ephemeral tab-scoped navigation generations. Load observers must
    /// validate both this token and their model identity before mutating
    /// history, probes, zoom, or hot memory.
    let navigationAttempts = NavigationAttemptRegistry()

     var activeTabID: String? {
        didSet {
            // Track last-access on the outgoing tab
            if let oldID = oldValue, let oldTab = tabs.first(where: { $0.id == oldID }) {
                oldTab.lastAccessed = Date()
            }
            // Maintain MRU tab cache: keep last 3 tab IDs so their CEF renderers
            // stay alive across switches (preserves scroll, forms, JS state).
            guard let newID = activeTabID else { return }
            mruTabIDs.removeAll { $0 == newID }
            mruTabIDs.insert(newID, at: 0)
            if mruTabIDs.count > 3 { mruTabIDs = Array(mruTabIDs.prefix(3)) }
            // Mark the newly active tab as accessed
            if let tab = tabs.first(where: { $0.id == newID }) {
                tab.lastAccessed = Date()
            }
        }
    }
     var mruTabIDs: [String] = []
    /// The Chromium target opens in the vertical rail by default, matching Hive's
    /// context-first workspace direction. Horizontal chrome remains an explicit choice.
    /// Direct SwiftUI bindings (Settings) flow through this observer so layout
    /// changes are durable even when they do not use a command/action method.
    var layout: TabLayout = .vertical {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }

    // MARK: Web chrome shell (the UI in web content)

    /// The persistent browser that renders the entire UI. Lives at
    /// ``webChromeURL``; never counted as a tab. Created after
    /// ``setupDefaults()`` in `init`.
    var chromeModel: CefWebViewModel?

    /// Where the chrome shell sits: left sidebar (vertical tabs) or top strip
    /// (horizontal tabs). Mirrors `layout` for the native frame only.
    var chromeMode: ChromeMode = .sidebar

    /// Sidebar width (vertical mode) or strip height (horizontal mode), in
    /// points. The web chrome reports its chosen size via
    /// `hive.setChromeDimension`; panels grow the chrome frame.
    var chromeDimension: CGFloat = HiveDesign.Zen.sidebarWidth

    /// Panel currently open inside the web chrome ("settings", "history",
    /// "bookmarks", "downloads", "commands"), or nil.
    var isChromePanelOpen: String?

    /// Suppresses autosave callbacks while the durable session projection is
    /// being applied during initialization. The complete restored state is
    /// already written by the initial clean/dirty snapshot after setupDefaults.
    @ObservationIgnored var isRestoringSession = false

    // MARK: - Tab Peek (Arc-style live preview)

    /// Named coordinate space (applied to the window root) tab pills use to
    /// report their window-space frame as the peek card's anchor.
    static let peekCoordinateSpaceName = "hiveWindow"

    /// JS probe injected into every loaded page. Reports media playback state
    /// changes (`HIVE_MEDIA|playing` / `HIVE_MEDIA|stopped`) via the console
    /// bridge. Event-driven (play/pause/volumechange/emptied listeners, capture
    /// phase, document-level delegation) — no timers, so background-tab timer
    /// throttling can't stall it. Reads only media element state, never page
    /// content. Self-guarding, so re-injection per navigation is safe.
    static let mediaStateProbeScript = """
    (function(){
      if (window.__hiveMediaProbeInstalled) return;
      window.__hiveMediaProbeInstalled = true;
      var reported = null;
      function playingOf(tag){
        var els = document.querySelectorAll(tag);
        for (var i = 0; i < els.length; i++){
          var e = els[i];
          if (!e.paused && !e.muted && !e.ended && e.readyState > 2) return e;
        }
        return null;
      }
      function sync(){
        var kind = playingOf('video') ? 'video' : (playingOf('audio') ? 'audio' : null);
        if (kind !== reported) {
          reported = kind;
          console.log(kind ? ('HIVE_MEDIA|' + kind) : 'HIVE_MEDIA|stopped');
        }
      }
      document.addEventListener('play', sync, true);
      document.addEventListener('pause', sync, true);
      document.addEventListener('volumechange', sync, true);
      document.addEventListener('emptied', sync, true);
      sync();
    })();
    """

    /// JS probe injected into every loaded page. Reports hovered links after a
    /// 220ms dwell (`HIVE_LINK_PEEK|<url>|<x>|<y>`) and clears on link exit
    /// (`HIVE_LINK_CLEAR`), using viewport coordinates. Self-guarding, so
    /// re-injection per navigation is safe. Reads only `a[href]` — the same
    /// data the browser already shows in the status bar on hover.
    static let linkPeekProbeScript = """
    (function(){
      if (window.__hiveLinkPeekInstalled) return;
      window.__hiveLinkPeekInstalled = true;        var timer = null;
      function linkOf(el){
        if (!el || el.nodeType !== 1) return null;
        return el.closest ? el.closest('a[href]') : null;
      }
      document.addEventListener('mouseover', function(e){
        var a = linkOf(e.target);
        if (!a) return;
        var href = a.href;
        if (!href || /^(javascript:|data:|#|mailto:|tel:)/i.test(href)) return;
        var r = a.getBoundingClientRect();
        var x = Math.round(r.left + r.width / 2);
        var y = Math.round(r.top + r.height / 2);
        clearTimeout(timer);
        timer = setTimeout(function(){
          // encodeURIComponent keeps the URL unambiguous on the native side
          // (a raw '|' in a query string must not collide with the delimiter).
          console.log('HIVE_LINK_PEEK|' + encodeURIComponent(href) + '|' + x + '|' + y);
        }, 220);
      }, true);
      document.addEventListener('mouseout', function(e){
        var a = linkOf(e.target);
        if (!a) return;
        var to = e.relatedTarget;
        var stillIn = to && to.nodeType === 1 && to.closest && to.closest('a[href]');
        if (!stillIn) { clearTimeout(timer); console.log('HIVE_LINK_CLEAR'); }
      }, true);
    })();
    """

    /// One pooled live CEF renderer of another tab's page. Each entry owns its
    /// own CefWebViewModel — the tab's real browser is already hosted by the
    /// main surface or the MRU keepalive cache, and CEF cannot attach one
    /// browser to two views, so the peek floats an independent second renderer
    /// of the same URL.
    struct TabPreviewEntry {
        let tabID: String
        let model: CefWebViewModel
        var lastUsed: Date
    }

    /// MRU pool of preview renderers, newest first. Capped so memory stays
    /// sane — each entry is a full CEF browser + renderer process. Worst case
    /// on the 8GB floor: active + MRU keepalive (3) + preview pool (2) = 6
    /// live renderers. Do not raise maxPreviewPoolSize without a memory
    /// budget pass (AGENTS.md §10.1).
    var previewPool: [TabPreviewEntry] = []

    /// The tab currently being peeked; nil when no peek card is shown.
    var activePeekTabID: String? = nil

    /// Window-space rect of the hovered tab pill — the peek card anchors to it.
    var peekAnchorRect: CGRect = .zero

    /// Window-space frame of the web content area (the active tab's CefWebView).
    /// The page's link-hover probe reports viewport coordinates; this frame
    /// converts them into window coordinates for the peek card anchor.
    var contentAreaFrame: CGRect = .zero

    static let maxPreviewPoolSize = 2

    /// True while the cursor is over the peek card itself, so a dismissal
    /// scheduled when the cursor left the pill can be cancelled (Arc lets the
    /// preview dwell while the cursor moves from the pill onto the card).
    var isPeekCardHovered: Bool = false

    var peekEndTask: Task<Void, Never>?

    // MARK: - Link hover peek (Arc-style link preview)

    /// The link currently being hovered in the page; nil when no link peek is
    /// shown. Mutually exclusive with `activePeekTabID`.
    var activePeekLinkURL: String? = nil

    /// Dedicated transient renderer of the hovered link's destination. Unlike
    /// tab previews (which stay pooled for instant re-peeks), link previews
    /// are destroyed on dismiss — the hovered URL changes every time, so a
    /// pool would cache nothing. One extra renderer only while a link peek is
    /// live; worst case on the 8GB floor: active + MRU (3) + tab pool (2) +
    /// link (1) = 7 momentarily, dropping to 6 on dismiss.
     var linkPreviewModel: CefWebViewModel? = nil

    // MARK: - Media mini-player (Arc-style auto player)

    /// IDs of tabs whose pages currently have playing (unmuted) media, from the
    /// injected media-state probe. Drives the speaker indicators in the tab
    /// chrome and the auto mini-player.
     var mediaPlayingTabIDs: Set<String> = []

    /// Subset of `mediaPlayingTabIDs` whose media is a VIDEO element (not
    /// audio-only) — eligible for the OS-level Picture-in-Picture window on
    /// tab switch.
     var mediaVideoPlayingTabIDs: Set<String> = []

    /// IDs of tabs muted at the browser level (CEF `SetAudioMuted` — the same
    /// whole-renderer mute Chrome's tab speaker toggles). Independent of the
    /// page's own media elements, so it works before anything plays and
    /// survives page navigations. Session-scoped like Chrome's per-tab mute;
    /// re-applied whenever a tab's browser (re)attaches after wake.
     var mutedTabIDs: Set<String> = []

    /// Subset of ``mutedTabIDs`` whose mute came from the durable per-site
    /// mute (``siteMutedHosts``), tracked so "Unmute Site" can release only
    /// the tabs it muted — independent per-tab mutes survive, matching
    /// Chrome's layered mute model. Session-scoped like the per-tab set.
     var siteMutedTabIDs: Set<String> = []

    /// The tab whose playback the floating mini-player controls; nil when the
    /// player is hidden. Shown when the user switches away from a playing tab
    /// (Arc behavior — the audio/video keeps going and stays one click away).
    var miniPlayerTabID: String? = nil {
        didSet {
            // Single-sourced cleanup: any transient "PiP unavailable" hint dies
            // with the player it belongs to. Without this, the hint could linger
            // past dismissal and reappear stale on the next card.
            if miniPlayerTabID == nil {
                piPUnavailableTask?.cancel()
                isMiniPlayerPiPUnavailable = false
            }
        }
    }
    /// window (Chromium's `video.requestPictureInPicture()` — a real
    /// always-on-top window, Arc-style). The outcome is reported
    /// asynchronously via the console bridge: `HIVE_PIP|entered` hides the
    /// in-window player (the OS window is the player); `HIVE_PIP|failed` falls
    /// back to the in-window control-surface player. Rejection is expected on
    /// pages that block the API or have no eligible video.
    /// True for the most recent PiP attempt when it came from the mini-player's
    /// explicit "Float" button. The auto-trigger (tab switch) marks its attempt
    /// non-user-initiated so the expected rejection doesn't surface the
    /// "PiP isn't available" hint — the in-window card IS the honest fallback
    /// and needs no error chrome. The hint is meaningful only when the user
    /// explicitly asked for OS PiP and it didn't work.
    var lastPiPWasUserInitiated: Bool = false

    /// True while a short "PiP unavailable" hint should show on the
    /// mini-player card (set by a failed Float attempt, cleared after ~3s).
     var isMiniPlayerPiPUnavailable: Bool = false

    var piPUnavailableTask: Task<Void, Never>?

    // MARK: - Compact Mode (Zen-style chrome auto-hide)
    /// Persisted in the session envelope. Direct bindings and the command
    /// palette share this observer so compact chrome does not revert on relaunch.
    var isCompactMode: Bool = false {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }

    // Recently closed tabs for ⇧T
    var closedTabs: [Tab] = []

    // Focus trigger for the address bar (⌘L)
    var addressFocusTrigger: Int = 0

    // MARK: - Floating URL Bar
    var isFloatingURLBarVisible: Bool = false
    var floatingURLBarText: String = ""
    /// When true, submitting the floating bar opens a new tab; when false, it navigates the active tab.
    var floatingURLBarOpensNewTab: Bool = false

    // MARK: - Browser chrome state

    var isCommandPaletteOpen: Bool = false
    var commandPaletteQuery: String = ""

    // MARK: - Tab Search (Chrome / Edge / Safari parity)

    var isTabSearchOpen: Bool = false

    // MARK: - Tab Overview (Arc-style visual grid)

    /// Arc-style visual tab grid overlay — a grid of all open tabs across
    /// workspaces with favicons, titles, and group colors.
    var isTabGridOpen: Bool = false

    // MARK: - Page Zoom (Chrome / Edge / Safari parity)

    /// Native CEF zoom levels per tab id (0 = 100%; CEF's zoom level is
    /// log2-scaled, so 1.0 ≈ 200%, -1.0 ≈ 50%). Persisted in the session so
    /// zoom survives restart; stored separately from the tabs array so
    /// rehydration and hibernation can't lose the user's per-tab setting.
     var tabZoomLevels: [String: Double] = [:]

    /// Per-site zoom levels remembered across sessions (Chrome/Safari
    /// parity). Keyed by the registrable domain (e.g. "github.com").
    /// Persisted in UserDefaults separately from the session envelope so
    /// zoom survives even if the session is corrupted.
    var siteZoomLevels: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: "HiveSiteZoomLevels") as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "HiveSiteZoomLevels") }
    }

    // MARK: - Navigation-entry stacks (back/forward menus)

    /// A committed navigation entry shown in the back/forward menus
    /// (Chrome/Safari convention). URLs are the source of truth; titles are
    /// backfilled lazily from the tab model at commit time.
    struct TabNavigationEntry: Equatable, Sendable {
        let url: URL
        let title: String
    }

    /// Back entries per tab id, newest first (index 0 = most recent). Fed by
    /// committed load completions (CEF 148 exposes only the current entry, so
    /// there is no API to enumerate the history). Private tabs are never
    /// tracked. Runtime-only: relaunch starts with an empty stack and the
    /// first committed navigation rebuilds it.
    var tabNavBack: [String: [TabNavigationEntry]] = [:]

    /// Forward entries per tab id, nearest first (index 0 = the page you'd
    /// go forward to next). Mirrors ``tabNavBack``.
    var tabNavForward: [String: [TabNavigationEntry]] = [:]

    /// The active tab's back entries for menus, capped for readability.
    var activeBackHistory: [TabNavigationEntry] {
        guard let tab = activeTab else { return [] }
        return Array((tabNavBack[tab.id] ?? []).prefix(12))
    }

    /// The active tab's forward entries for menus, capped for readability.
    var activeForwardHistory: [TabNavigationEntry] {
        guard let tab = activeTab else { return [] }
        return Array((tabNavForward[tab.id] ?? []).prefix(12))
    }

    /// Returns the registrable domain from a URL for per-site zoom keys.
    static func hostForZoom(_ url: URL?) -> String? {
        guard let host = url?.host?.lowercased() else { return nil }
        // Strip www. prefix for consistent keying.
        if host.hasPrefix("www.") { return String(host.dropFirst(4)) }
        return host
    }

    /// Hosts the user has permanently muted (Safari/Chrome "Mute Site"). Keyed
    /// by the same www-stripped lowercase host convention as ``siteZoomLevels``.
    /// Any tab whose current host is in this set is muted at the browser level
    /// automatically on navigation and attach, so a "mute this site" decision
    /// sticks across tabs and sessions. UserDefaults-backed so it survives
    /// relaunch without touching the session envelope (a preference, not
    /// browsing data).
    var siteMutedHosts: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "HiveSiteMutedHosts") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "HiveSiteMutedHosts") }
    }

    // MARK: - HTTPS-Only Mode (Chrome "Always use secure connections")

    /// When on, http URLs are upgraded to https at the app-controlled
    /// navigation entry points and any page that still lands on plaintext http
    /// shows a warning banner. UserDefaults-backed (a transport preference,
    /// never content). Defaults off; opt-in matches Chrome.
    var isHTTPSOnlyEnabled: Bool = {
        UserDefaults.standard.object(forKey: "HiveHTTPSOnlyEnabled") as? Bool ?? false
    }() {
        didSet {
            UserDefaults.standard.set(isHTTPSOnlyEnabled, forKey: "HiveHTTPSOnlyEnabled")
            // Turning the mode off dismisses any warning that's showing — a
            // plaintext page stops being a problem the moment the user opts out.
            if !isHTTPSOnlyEnabled { httpsOnlyNotice = nil }
        }
    }

    /// Hosts the user allowed to stay on plaintext http while HTTPS-Only is
    /// on ("Load anyway" from the warning banner). Keyed by the shared
    /// http(s) host convention, persisted in UserDefaults.
    var httpsOnlyExceptions: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "HiveHTTPSOnlyExceptions") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "HiveHTTPSOnlyExceptions") }
    }

    /// Current HTTPS-Only warning for the active tab; nil when no banner
    /// shows. Rendered in the top banner stack; cleared on dismiss, "Load
    /// anyway", "Use HTTPS", navigation away from http, and tab switch.
    var httpsOnlyNotice: HTTPSOnlyNotice? = nil

    /// A plaintext page surfaced by HTTPS-Only mode.
    struct HTTPSOnlyNotice: Equatable, Sendable {
        let host: String
        let url: URL

        var title: String { "Connection is not secure" }
        var detail: String { "\(host) loaded over plaintext HTTP while HTTPS-Only mode is on." }
        var accessibilityLabel: String { "\(title). \(detail)" }
    }

    /// Chrome's standard zoom ladder (percent). Steps are small near 100% and
    /// coarser at the extremes — the exact ladder users expect from ⌘+/⌘-.
    static let zoomLadder: [Double] = [25, 33, 50, 67, 75, 80, 90, 100, 110, 125, 150, 175, 200, 250, 300, 400, 500]

    var isFindBarOpen: Bool = false
    var findQuery: String = ""

    /// Find-in-page match counter ("3/12", "No matches") reported back from
    /// the page's find JS over the console bridge (`HIVE_FIND|<current>|<total>`).
    /// nil hides the counter entirely (empty field).
    var findMatchText: String? = nil
    /// Aa "Match case" toggle state (Chrome find-bar parity). Session-scoped;
    /// the next find (typing, ⌘G, or the toggle itself) honors it.
    var findMatchCaseSensitive: Bool = false
    /// Debounces the counter's full-page text walk while the user types.
    @ObservationIgnored var findCountDebounceTask: Task<Void, Never>?

    /// Persisted toolbar preference. This observer covers both Settings' direct
    /// binding and the Cmd+Shift+B command without duplicating storage calls.
    var showBookmarksBar: Bool = false {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }
    /// Approved taste decision (autoplan): new tabs open the Morning Brief by
    /// default. The hand-drawn start page (search + top sites + briefcard)
    /// remains one Settings toggle away.
    var openBriefOnNewTab: Bool = true {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }

    /// P2.6 Proactive Briefing: regenerate the daily brief from Honeycomb
    /// memory on the calendar-day rollover and refresh open brief tabs. On by
    /// default; the Settings toggle flips it off (static per-serve brief).
    var enableProactiveBriefing: Bool = true {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }

    /// P2.6 Proactive Briefing calendar half: opt-in calendar-aware looking
    /// ahead. Default off — EventKit permission is requested only when the
    /// user enables it in Settings.
    var includeCalendarInBrief: Bool = false {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }

    /// Network-level ad/tracker blocking (EasyList-based Rust engine plus the
    /// domain fallback list) and cosmetic hiding after page load. On by
    /// default. UserDefaults-backed like `contextMode` so it survives relaunch
    /// without touching the session envelope; toggling re-applies the policy
    /// to the live browser's CDP session immediately.
    var isAdBlockEnabled: Bool = {
        UserDefaults.standard.object(forKey: "HiveAdBlockEnabled") as? Bool ?? true
    }() {
        didSet {
            UserDefaults.standard.set(isAdBlockEnabled, forKey: "HiveAdBlockEnabled")
            applyAdBlockPolicy()
        }
    }
    var bookmarks: [Bookmark] = [] {
        didSet {
            // Auto-hide bookmarks bar when empty; show it when bookmarks appear
            if bookmarks.isEmpty { showBookmarksBar = false }
        }
    }
    var isBookmarksManagerOpen: Bool = false
    /// The folder currently being browsed in the bookmarks manager (nil =
    /// root). Also the target folder for a star-save while the manager is
    /// open (Chrome behavior: the star saves into the folder you're viewing).
    var bookmarksManagerFolderID: UUID? = nil

    // MARK: - Reading List (Safari)

    /// Articles the user explicitly saved for later — Safari Reading List
    /// parity. Newest first; upserts (re-saving an article) move it to the
    /// top without duplicating it. Persisted with the session envelope and
    /// capped by ``ReadingListPolicy``. Entries are never added from private
    /// tabs.
    var readingList: [ReadingListEntry] = [] {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }
    var isReadingListPanelOpen: Bool = false

    // MARK: - Pinned Web Apps (Arc / Sidekick)

    /// Quick-launch web apps pinned to the sidebar rail — Arc-style "Favorites".
    /// One app per site (identity-normalized), each opening its pinned URL in a
    /// new tab. Persisted with the session envelope and capped by
    /// ``PinnedWebAppPolicy``. Apps are never added from private tabs.
    var pinnedWebApps: [PinnedWebApp] = [] {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }
    /// Arc-style Pinned Apps manager sheet.
    var isPinnedAppsPanelOpen: Bool = false
    /// Clean Tabs (Arc/Boost parity) review sheet — duplicate/stale candidates.
    var isCleanTabsPanelOpen: Bool = false

    // MARK: - Auto-Archive (§7 cold-tab shelf)

    /// Durable "Recently Archived" shelf — records of auto-archived cold tabs
    /// (``AutoArchivePolicy``, 14-day default). Newest first, capped by
    /// ``TabArchiveShelfPolicy``; restoring a record reopens the tab and
    /// removes it from the shelf. Persisted with the session envelope.
    var archivedTabs: [ArchivedTab] = [] {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }
    /// Archive review sheet.
    var isArchivePanelOpen: Bool = false

    // MARK: - Workspace Management Panel

    /// Workspace management sheet (Arc/Safari parity).
    var isWorkspaceManagerPanelOpen: Bool = false

    // MARK: - Profile Manager Panel

    /// Profile management sheet (Chrome/Safari parity).
    var isProfileManagerPanelOpen: Bool = false

    // MARK: - Tab Group Manager Panel

    /// Tab group management sheet (Arc/Chrome parity).
    var isTabGroupManagerPanelOpen: Bool = false

    // MARK: - Search Engine Manager Panel

    /// Search engine management sheet.
    var isSearchEngineManagerPanelOpen: Bool = false

    // MARK: - Keyboard Shortcuts Panel

    /// Keyboard shortcuts reference sheet.
    var isKeyboardShortcutsPanelOpen: Bool = false

    // MARK: - Memory Saver Panel

    /// Memory Saver (tab sleep management) sheet.
    var isMemorySaverPanelOpen: Bool = false

    /// Safety Check (Chrome chrome://settings/safetyCheck parity) sheet.
    var isSafetyCheckPanelOpen: Bool = false

    // MARK: - Sync Status

    /// Human-readable sync state for the native chrome indicator.
    enum SyncState: Sendable, Equatable {
        case unavailable
        case available
        case syncing
        case error(String)

        var isActive: Bool {
            if case .available = self { return true }
            if case .syncing = self { return true }
            return false
        }

        var iconName: String {
            switch self {
            case .unavailable: return "icloud.slash"
            case .available: return "icloud.fill"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .error: return "exclamationmark.icloud"
            }
        }

        var label: String {
            switch self {
            case .unavailable: return "Sync unavailable"
            case .available: return "Sync available"
            case .syncing: return "Syncing…"
            case .error(let msg): return msg
            }
        }

        var color: Color {
            switch self {
            case .unavailable: return .secondary
            case .available: return .green
            case .syncing: return .blue
            case .error: return .orange
            }
        }
    }

    var syncState: SyncState = .unavailable
    var lastSyncDate: Date?
    /// Whether the periodic auto-archive pass runs (Settings → Performance).
    /// Default on, like Memory Saver; the shelf keeps archived tabs one click
    /// away so the pass is never destructive.
    var enableAutoArchive: Bool = true {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }
    /// Handle to the periodic auto-archive pass; cancelled on deinit.
    @ObservationIgnored var archiveTask: Task<Void, Never>?

    /// User-defined ⌘K commands persisted with the browser session.
    var userDefinedCommands: [UserDefinedCommand] = [] {
        didSet { scheduleAutosave() }
    }

    // MARK: - Search Engine

    /// A custom search engine the user has added.
    struct CustomSearchEngine: Identifiable, Hashable, Sendable, Codable {
        let id: String
        var name: String
        /// URL template with `{query}` placeholder, e.g.
        /// `https://example.com/search?q={query}`
        var template: String
        /// Chrome-style omnibox keyword (e.g. "yt" → `yt kittens` searches
        /// YouTube). Empty means no keyword. Optional + decode default keeps
        /// sessions saved before keywords shipped loading intact.
        var keyword: String? = nil

        /// Builds a search URL from the template.
        func searchURL(for query: String) -> URL? {
            let encoded = query.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed) ?? query
            let urlString = template.replacingOccurrences(of: "{query}", with: encoded)
            return URL(string: urlString)
        }

        /// The host extracted from the template for display purposes.
        var displayHost: String {
            if let url = URL(string: template), let host = url.host {
                return host
            }
            return template
        }
    }

    enum SearchEngine: String, CaseIterable, Identifiable, Sendable, Codable {
        case duckduckgo = "DuckDuckGo"
        case google = "Google"
        case bing = "Bing"
        case brave = "Brave Search"
        case startpage = "Startpage"
        case ecosia = "Ecosia"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .duckduckgo: return "magnifyingglass"
            case .google: return "g.circle.fill"
            case .bing: return "b.circle.fill"
            case .brave: return "shield"
            case .startpage: return "eye"
            case .ecosia: return "leaf.fill"
            }
        }

        var color: Color {
            switch self {
            case .duckduckgo: return .orange
            case .google: return .blue
            case .bing: return .teal
            case .brave: return .orange
            case .startpage: return .green
            case .ecosia: return .green
            }
        }

        var searchURL: String {
            switch self {
            case .duckduckgo: return "https://duckduckgo.com/?q="
            case .google: return "https://google.com/search?q="
            case .bing: return "https://bing.com/search?q="
            case .brave: return "https://search.brave.com/search?q="
            case .startpage: return "https://www.startpage.com/sp/search?query="
            case .ecosia: return "https://www.ecosia.org/search?q="
            }
        }

        var searchTemplate: String {
            searchURL + "{query}"
        }
    }

    /// User-added custom search engines, persisted in UserDefaults.
    var customSearchEngines: [CustomSearchEngine] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "HiveCustomSearchEngines"),
                  let decoded = try? JSONDecoder().decode([CustomSearchEngine].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: "HiveCustomSearchEngines")
        }
    }

    /// ID of the custom search engine currently selected as default, or nil.
    /// Persisted in UserDefaults; cleared if the engine is deleted.
    var activeCustomSearchEngineID: String? {
        get { UserDefaults.standard.string(forKey: "HiveActiveCustomSearchEngineID") }
        set { UserDefaults.standard.set(newValue, forKey: "HiveActiveCustomSearchEngineID") }
    }

    /// Builds a search URL using the active custom engine if one is selected,
    /// or the built-in search engine otherwise.
    func searchURL(for query: String) -> URL? {
        if let customID = activeCustomSearchEngineID,
           let custom = customSearchEngines.first(where: { $0.id == customID }) {
            return custom.searchURL(for: query)
        }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: searchEngine.searchURL + encoded)
    }

    /// The display name of the currently active search engine (custom or built-in).
    var searchEngineDisplayName: String {
        if let customID = activeCustomSearchEngineID,
           let custom = customSearchEngines.first(where: { $0.id == customID }) {
            return custom.name
        }
        return searchEngine.rawValue
    }

    /// Google is the fresh-install default; persisted user choices are restored below.
    var searchEngine: SearchEngine = .google

    // MARK: - AI Infrastructure (Swarm agent pipeline)

    /// Running hot memory — tracks recently browsed/captured nodes for context
    /// assembly. Wired to the durable graph below so relevance ranking uses
    /// real FTS5 matches, not ID-substring heuristics. Assigned in init()
    /// (after `honeycomb` is live) — `@Observable` forbids `lazy` properties.
    /// Getter is internal (GeminiSidePanel reads it); only init() assigns.
     var hotMemory: HotMemoryStore

    /// Durable knowledge graph — SQLite-backed typed nodes and edges.
    /// The bounded code workspace (STUDIO-001/002). File access and check
    /// commands stay inside the user-selected project root.
    let studioWorkspace = StudioWorkspace()

    let honeycomb: HoneycombStore = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Hive", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("honeycomb.sqlite3").path
        if let onDisk = try? HoneycombStore(path: path) { return onDisk }
        // :memory: SQLite databases cannot fail to open — this fallback is
        // unreachable in practice but keeps the store non-optional.
        guard let memory = try? HoneycombStore(path: ":memory:") else {
            fatalError("HoneycombStore could not open an in-memory database")
        }
        return memory
    }()

    /// Append-only audit trail — all model calls and orchestration decisions logged here.
    let eventLedger: EventLedgerStore = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Hive", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("event_ledger.sqlite3").path
        if let onDisk = try? EventLedgerStore(path: path) { return onDisk }
        // :memory: SQLite databases cannot fail to open — this fallback keeps
        // browsing alive, but the health flag below makes the loss of durable
        // audit evidence visible and blocks consequential actions.
        guard let memory = try? EventLedgerStore(path: ":memory:") else {
            fatalError("EventLedgerStore could not open an in-memory database")
        }
        return memory
    }()

    /// True when the durable knowledge graph fell back to memory.
     var isKnowledgePersistenceDegraded: Bool = false
    /// True when the append-only audit trail fell back to memory.
     var isAuditPersistenceDegraded: Bool = false
    /// True when a browser session snapshot could not be written. This is
    /// separate from Honeycomb/EventLedger because browser changes can be lost
    /// even while both knowledge stores remain healthy.
     var isSessionPersistenceDegraded: Bool = false
     var isPersistenceHealthNoticeDismissed: Bool = false

    /// The agent mix pipeline: orchestrator → retrievalRanker → librarian.
    /// Set in init() after setupDefaults() because it references self.hotMemory/self.eventLedger.
    var swarmOrchestrator: SwarmOrchestrator?

    /// Parallel multi-model council for AI queries. Set in init() after setupDefaults().
    var modelCouncil: ModelCouncil?

    /// CDP client for agentic browsing (Astro-aligned). Wired to CEF's
    /// sendDevToolsMessage via wireSend. The AI uses this to drive the browser.
    @MainActor  var cdpClient = CDPClient()

    /// Latest council verdict — observed by GeminiSidePanel for display.
     var latestCouncilVerdict: CouncilVerdict? = nil
    /// True while a council is convened and deliberating.

    /// Live responses collected during a streaming council deliberation.
    /// Cleared when the council starts, populated incrementally as models respond.
     var councilLiveResponses: [CouncilResponse] = []
     var isCouncilConvening: Bool = false
     var councilError: String? = nil
     var agentError: String? = nil
     var lastQuery: String = ""

    /// Handle to the in-flight council deliberation Task. Cancel to abort.
    var councilDeliberationTask: Task<Void, Never>? = nil

    /// Serializes browser transitions with background Swarm requests. The
    /// generation is incremented on every profile/workspace switch; a request
    /// carries the generation it observed and fails closed if the browser has
    /// moved on before the result returns.
    var contextRequestCoordinator: ContextRequestCoordinator?
    let contextTransitionToken = ContextTransitionToken()

    /// The user-visible context contract for Swarm requests. Keep this small
    /// until every broader source (history, screenshots, projects) has a
    /// complete provenance and deletion path.
    enum ContextMode: String, CaseIterable, Identifiable, Sendable {
        case workspace
        case pageOnly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .workspace: return "Workspace"
            case .pageOnly: return "Page only"
            }
        }

        var detail: String {
            switch self {
            case .workspace: return "Current page, scoped memory, and preferences"
            case .pageOnly: return "Current page only — no saved memory"
            }
        }

        var icon: String {
            switch self {
            case .workspace: return "square.stack.3d.up"
            case .pageOnly: return "doc.plaintext"
            }
        }

        var includesHotMemory: Bool {
            self == .workspace
        }
    }

    /// Session-level default is remembered locally, never sent as content.
    /// Unknown persisted values are repaired immediately to the safe, useful
    /// default instead of leaving an invalid preference in place.
    var contextMode: ContextMode = {
        let raw = UserDefaults.standard.string(forKey: "HiveContextMode")
        let mode = ContextMode(rawValue: raw ?? "") ?? .workspace
        if raw != mode.rawValue {
            UserDefaults.standard.set(mode.rawValue, forKey: "HiveContextMode")
        }
        return mode
    }() {
        didSet {
            UserDefaults.standard.set(contextMode.rawValue, forKey: "HiveContextMode")
        }
    }

    /// Durable local host decisions are loaded once at bootstrap and updated
    /// only by an explicit browser-chrome action. The cached snapshot keeps
    /// request admission synchronous and deterministic; the actor store remains
    /// the durable authority and rejects unsafe origins.
    let hostContextPolicyStore = HostContextPolicyStore()
    var hostContextPolicy = HostContextPolicy()
    var hostContextPolicyMutationGeneration: UInt64 = 0
     var isHostContextPolicyMutationPending: Bool = false
    /// A failed newest policy write forces runtime page context closed. The
    /// durable store may still contain the previous decision, but requests must
    /// not use an optimistic allow after persistence failure.
    var hostContextPolicyPersistenceFailed: Bool = false

    // MARK: - Durable research handoff lifecycle

    enum ResearchHandoffStatus: Equatable, Sendable {
        case notStarted
        case starting
        case recoveryReady(repairedCount: Int)
        case unavailable(String)
    }

    /// Diagnostic-only state for the background research boundary. Normal
    /// browsing does not depend on this service being available.
     var researchHandoffStatus: ResearchHandoffStatus = .notStarted
    var researchHandoffSupervisor: ResearchHandoffSupervisor?
    @ObservationIgnored var researchHandoffRecoveryTask: Task<Void, Never>?

    /// Tracks the current page in hot memory so it's available for context assembly.
    var lastTrackedURL: String? = nil

    // MARK: - Knowledge Panel (Honeycomb)

    var isKnowledgePanelOpen: Bool = false

    /// Monotonic revision counter for durable memory writes. Bumped after any
    /// capture or note lands so open knowledge surfaces can refresh live —
    /// memory appears in the panel as it is made ("keeps watching") without
    /// reopening the sidebar.
    var memoryRevision: Int = 0

    // MARK: - Brief Capture (Browse → Remember → Organize)
    var isBriefCaptureOpen: Bool = false

    enum CaptureError: Error, LocalizedError {
        case noPage
        case noNote
        case privateBrowsing
        case persistenceUnavailable
        case partialPersistence
        var errorDescription: String? {
            switch self {
            case .noPage: return "No page to capture — open a web page first."
            case .noNote: return "Nothing to capture — write a note first."
            case .privateBrowsing: return "Private pages and notes are not added to Hive memory."
            case .persistenceUnavailable:
                return "Capture blocked: durable storage is unavailable. Nothing was saved."
            case .partialPersistence:
                return "Capture partially saved: the source was stored, but its audit record was not. Restart Hive before capturing again."
            }
        }
    }

    // MARK: - Action Approval (Act)
    var approvalQueue = ApprovalQueue()
    var isApprovalPanelOpen: Bool = false

    /// The action currently rendered in the approval panel. Snapshotted here
    /// (rather than reading `approvalQueue.pending.first` in the window) so the
    /// panel survives decision-recording: `recordApproval` removes the action
    /// from `pending` for the audit trail, and the overlay gate must not
    /// unmount the view mid-decision — otherwise the "Action Approved"
    /// confirmation (which claims "Logged to EventLedger") would be dead code
    /// the user never sees.
    var presentedApprovalAction: PendingAction?

    /// SWARM-004 policy gate: the registry + engine that evaluate every
    /// envelope-carrying action BEFORE it may reach the panel or execute.
    /// The registry is populated lazily on first evaluation (ToolRegistry is
    /// an actor; defaultTools is the canonical static set).
    let policyEngine = PolicyEngine()
    let toolRegistry = ToolRegistry()
    var toolRegistryPopulated = false

    /// The last policy denial reason, surfaced by producers (Studio panel
    /// banner). Denied actions NEVER reach the approval panel — the denial is
    /// recorded to the EventLedger and surfaced here (AGENTS.md §16.2 deny
    /// path; §7.4 "denied actions never render a preview").
    var lastPolicyDenial: String?

    /// Results of the last approved studio.runCheck (STUDIO-002 → SWARM-004
    /// wiring). The Studio panel observes these to render the check output.
    var studioCheckResult: String?
    var studioCheckError: String?

    /// SWARM-005 session grants: tools the user pre-approved for this
    /// session. A grant downgrades requiresConfirmation → allowed for that
    /// tool only; it NEVER overrides a policy denial (the hard boundary
    /// stays intact). In-memory by design — a fresh launch always asks again.
    var sessionGrants: [SessionGrant] = []

    // MARK: - Studio Panel

    var isStudioPanelOpen: Bool = false

    /// The last edit applied through the Studio approval center. Nil until a
    /// codeApply is approved and written; cleared by a fresh edit or explicit
    /// rollback. `isGitRepo` at the panel controls whether the undo uses
    /// git-restore (stronger) or the .hivebak fallback.
    var lastAppliedEdit: StudioWorkspace.FileEdit? = nil

    // MARK: - Sheets Panel (SHEET-002)

    var isSheetsPanelOpen: Bool = false

    var isGeminiPanelOpen: Bool = false
    var geminiMessages: [GeminiMessage] = []
    var isGeminiGenerating: Bool = false

    /// Tracks the direction of the last navigation for push transitions.
    /// `.forward` when navigating to a new page via link or address bar;
    /// `.backward` when going back in history. `nil` on initial load.
    enum NavigationDirection { case forward, backward }
    var lastNavigationDirection: NavigationDirection? = nil
    var lastGeminiProvider: String = ""
    var lastContextDiagnostics: ContextDiagnostics? = nil
    /// User-selectable AI provider — Comet-style model toggle in the Gemini
    /// panel header. Raw values: "auto" | "mlx" | "appleFMF" | "byokRemote".
    var preferredModelProvider: String = "auto"
    var geminiGenerationTask: Task<Void, Never>?
    /// One advisory response implementation shared by text and voice. The
    /// browser state remains the owner of UI messages and lifecycle tokens.
    let responseExecutor = SwarmResponseExecutor()
    /// Shared response lifecycle gate for text, voice, and research turns.
    /// A provider may finish after cancellation, but it cannot publish through
    /// this gate once a newer turn or Stop has invalidated its request.
    let responseLifecycleToken = ResponseLifecycleToken()

    struct BrowserAction { let tool: String; let label: String; let url: String?; let selector: String?; let value: String? }

    var installedExtensions: [ExtensionItem] = ExtensionItem.defaults
    /// Arc-style site Boosts: user-authored CSS per host. Persisted with the
    /// session (like extensions); injected after page load by BoostMatcher.
    var boosts: [Boost] = [] {
        didSet { if !isRestoringSession { scheduleAutosave() } }
    }
    var isMemorySaverEnabled: Bool = true {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }

    var browserAccentColorHex: String = "#F97316"
    var savedPasswords: [SavedPassword] = []
    var safeBrowsingWarning: SafeBrowsingWarning? = nil

    /// Transient feedback for an omnibox scheme rejected before Chromium
    /// navigation. This is UI-only state: it is never persisted or included in
    /// page/memory context.
     var navigationBlockNotice: NavigationBlockNotice?
    @ObservationIgnored var navigationBlockNoticeTask: Task<Void, Never>?

    /// A navigation that remained unfinished for the full polling window.
    /// This is deliberately not called a renderer crash: CefSwiftUI does not
    /// expose CEF's renderer-termination callback to this target.
    struct NavigationHealthNotice: Equatable, Sendable {
        let tabID: String
        let url: URL

        var title: String { "Page did not finish loading" }
        var detail: String { "Hive waited 30 seconds and did not retry automatically." }
        var accessibilityLabel: String {
            "Page did not finish loading. Hive waited 30 seconds and did not retry automatically. This is a stalled navigation notice, not a renderer crash diagnosis."
        }
    }

     var navigationHealthNotice: NavigationHealthNotice?

    /// A failed main-frame load (Chromium's `didFailLoad`), keyed by tab id.
    /// Only the active tab's entry is surfaced; a new navigation attempt or a
    /// successful commit clears it. Not persisted — errors are session-local.
    struct LoadErrorNotice: Equatable, Sendable {
        let tabID: String
        let code: Int
        let text: String
        let url: URL

        /// A short human label for the banner (Chrome keeps it terse). Codes
        /// are Chromium net errors: ERR_NAME_NOT_RESOLVED -105,
        /// ERR_INTERNET_DISCONNECTED -106, ERR_CONNECTION_TIMED_OUT -118,
        /// ERR_CONNECTION_REFUSED -102, ERR_CONNECTION_RESET -101.
        /// ERR_CERT_* (-200..-216) also arrive through OnLoadError; they reuse
        /// the certificate-specific wording so the banner stays honest (the
        /// actionable bypass lives in the site-security popover).
        var title: String {
            switch code {
            case -105: return "The server name could not be resolved"
            case -106: return "The internet connection has been lost"
            case -118: return "The connection timed out"
            case -102: return "The server refused the connection"
            case -101: return "The connection was reset"
            case -200: return "The site's name does not match the certificate"
            case -201: return "The site's certificate has expired"
            case -202: return "The certificate authority is not trusted"
            case -206: return "The site's certificate has been revoked"
            case -207: return "The certificate is invalid"
            case -208: return "The certificate uses a weak signature algorithm"
            case -210: return "The certificate name is not unique"
            case -211: return "The certificate uses a weak key"
            default: return "This page couldn't be loaded"
            }
        }
    }

    var tabLoadErrors: [String: LoadErrorNotice] = [:]

    /// A certificate-validation failure for a tab's main frame (Chromium's
    /// `didEncounterCertificateError`), keyed by tab id. Only the active
    /// tab's entry is surfaced; a new navigation attempt clears it. Not
    /// persisted — errors are session-local.
    struct CertificateErrorNotice: Equatable, Sendable {
        let tabID: String
        let code: Int
        let url: URL

        var host: String { url.host ?? url.absoluteString }

        /// A short human label for the popover/banner. Codes are Chromium
        /// net errors: ERR_CERT_COMMON_NAME_INVALID -200,
        /// ERR_CERT_DATE_INVALID -201, ERR_CERT_AUTHORITY_INVALID -202,
        /// ERR_CERT_CONTAINS_ERRORS -203, ERR_CERT_REVOKED -206,
        /// ERR_CERT_INVALID -207, ERR_CERT_WEAK_SIGNATURE_ALGORITHM -208,
        /// ERR_CERT_NON_UNIQUE_NAME -210, ERR_CERT_WEAK_KEY -211.
        var title: String {
            switch code {
            case -200: return "The site's name does not match the certificate"
            case -201: return "The site's certificate has expired"
            case -202: return "The certificate authority is not trusted"
            case -206: return "The site's certificate has been revoked"
            case -207: return "The certificate is invalid"
            case -208: return "The certificate uses a weak signature algorithm"
            case -210: return "The certificate name is not unique"
            case -211: return "The certificate uses a weak key"
            default: return "The site's certificate could not be verified"
            }
        }
    }

    /// Certificate-validation failures keyed by tab id.
    var tabCertificateErrors: [String: CertificateErrorNotice] = [:]

    /// Hosts the user chose to proceed past a certificate error during this
    /// session (Chrome keeps bypasses non-persistent too). While a host is
    /// here the cert-error handler allows the load instead of cancelling.
    var certificateBypassHosts: Set<String> = []

    /// The active tab's load error, if any (drives the error banner).
    var loadErrorNotice: LoadErrorNotice? {
        guard let tab = activeTab else { return nil }
        return tabLoadErrors[tab.id]
    }

    /// Retry action for the error banner: reload the failed address and clear
    /// the notice (the retry's own outcome re-reports via didFailLoad or the
    /// successful commit clears it).
    func retryLoadError() {
        guard let notice = loadErrorNotice else { return }
        tabLoadErrors[notice.tabID] = nil
        if let tab = tabs.first(where: { $0.id == notice.tabID }) {
            tab.model.load(notice.url)
            armNavigationObservation(for: tab, attemptID: beginNavigationAttempt(for: tab), url: notice.url)
        }
    }

    /// Dismisses the active tab's load-error banner without retrying.
    func dismissLoadError() {
        guard let notice = loadErrorNotice else { return }
        tabLoadErrors[notice.tabID] = nil
    }

    /// The active tab's certificate error, if any (drives the security
    /// popover's warning state).
    var certificateErrorNotice: CertificateErrorNotice? {
        guard let tab = activeTab else { return nil }
        return tabCertificateErrors[tab.id]
    }

    /// Proceed-past-certificate-error: remember the host for this session,
    /// clear the notice, and reload the exact failed address. Subsequent
    /// loads for that host are allowed by the cert-error handler.
    func proceedPastCertificateError() {
        guard let notice = certificateErrorNotice else { return }
        certificateBypassHosts.insert(notice.host.lowercased())
        tabCertificateErrors[notice.tabID] = nil
        if let tab = tabs.first(where: { $0.id == notice.tabID }) {
            tab.model.load(notice.url)
            armNavigationObservation(for: tab, attemptID: beginNavigationAttempt(for: tab), url: notice.url)
        }
        broadcastWebChromeState()
    }

    var translateBar: TranslateState? = nil
    var isGoogleLensActive: Bool = false
    var isCustomizePanelOpen: Bool = false
    var isPasswordsManagerOpen: Bool = false
    var isExtensionsManagerOpen: Bool = false
    /// Arc-style Boosts manager sheet.
    var isBoostsPanelOpen: Bool = false
    /// Host prefill for the Boost editor, set by the page context menu's
    /// "Boost This Site…" action. Cleared once the editor opens.
    var pendingBoostHost: String? = nil

    // MARK: - History (Safari / Chrome / Edge / Arc)
    var historyItems: [HistoryItem] = []
    var isHistoryPanelOpen: Bool = false

    // MARK: - Downloads (Safari / Chrome / Edge)
    var downloads: [DownloadItem] = []
    var isDownloadsPanelOpen: Bool = false

    /// Whether macOS notifications are posted when a download completes
    /// (Chrome parity). UserDefaults-backed so it survives relaunch without
    /// touching the session envelope.
    var downloadNotificationsEnabled: Bool = {
        UserDefaults.standard.object(forKey: "HiveDownloadNotifications") as? Bool ?? true
    }() {
        didSet {
            UserDefaults.standard.set(downloadNotificationsEnabled, forKey: "HiveDownloadNotifications")
        }
    }
    /// Bounded-wait timers for pending pause/resume requests, keyed by
    /// download id. The HiveCore state machine stays pending until a native
    /// snapshot reconciles it; this timer falls back to the last actionable
    /// baseline so a stuck request can never trap the control behind a
    /// disabled button.
    @ObservationIgnored var downloadControlTimeouts: [UUID: Task<Void, Never>] = [:]

    // MARK: - Reader Mode (Safari / Edge / Arc / Brave / Zen)
    // Transforms the page in-place via CSS injection — no text extraction needed.
    var isReaderMode: Bool = false
    /// Word count of the reader content, reported over the console bridge
    /// (`HIVE_READER_WORDS|<n>`) by the injected reader JS. Shown in the
    /// Reader Mode bar like Safari; nil until the first report arrives.
    var readerWordCount: Int? = nil
    /// Reader-mode appearance (font scale × theme). Persisted in UserDefaults
    /// (like adblock); mutating it live-updates an open reader page through
    /// the CSS custom-property script without leaving reader mode.
    var readerStyle: ReaderStyle = {
        let scale = UserDefaults.standard.double(forKey: "HiveReaderFontScale")
        let themeRaw = UserDefaults.standard.string(forKey: "HiveReaderTheme") ?? ReaderTheme.auto.rawValue
        let familyRaw = UserDefaults.standard.string(forKey: "HiveReaderFontFamily") ?? ReaderFontFamily.serif.rawValue
        return ReaderStyle(
            fontScale: scale == 0 ? 1.0 : scale,
            theme: ReaderTheme(rawValue: themeRaw) ?? .auto,
            fontFamily: ReaderFontFamily(rawValue: familyRaw) ?? .serif
        )
    }() {
        didSet {
            guard readerStyle != oldValue else { return }
            UserDefaults.standard.set(readerStyle.fontScale, forKey: "HiveReaderFontScale")
            UserDefaults.standard.set(readerStyle.theme.rawValue, forKey: "HiveReaderTheme")
            UserDefaults.standard.set(readerStyle.fontFamily.rawValue, forKey: "HiveReaderFontFamily")
            if isReaderMode, let model = activeModel {
                model.executeJavaScript(readerStyle.cssVariableUpdateScript())
            }
        }
    }

    // MARK: - Privacy Report (Safari)

    var trackerBlockedCount: Int = 0
    var isPrivacyReportOpen: Bool = false
    var isSiteSecurityPanelOpen: Bool = false

    // MARK: - Site Permissions (Chrome parity)

    /// Per-site permission decisions (camera, microphone, location,
    /// notifications, popups, downloads). Private tabs never contribute
    /// durable entries — see ``SitePermissionPolicy``. The site-security
    /// popover and the permission banner both read and write through this
    /// single durable projection.
    var sitePermissions: [SitePermission] = [] {
        didSet {
            if !isRestoringSession { scheduleAutosave() }
        }
    }

    /// FIFO of permission requests awaiting a user decision (Chrome-style
    /// banner). Each entry owns its retained CEF callback; dropping an entry
    /// (resolve, CEF dismissal, tab close, navigation) releases the callback
    /// via deinit. The banner renders `pendingPermissionRequests.first`.
    var pendingPermissionRequests: [PendingPermissionRequest] = []

    /// A URL to open in a freshly spawned window (web-chrome "Open in New
    /// Window"). Set just before posting HiveRequestNewWindow; the new
    /// window's BrowserWindow consumes it on first appearance and navigates.
    var pendingNewWindowURL: URL? = nil

    /// The "Use saved password?" chip for the login form currently detected
    /// on the visible page; nil when no chip is shown. Filling is always an
    /// explicit user click (never automatic).
    var pendingAutofillSuggestion: AutofillSuggestion? = nil

    /// Hosts the user dismissed an autofill chip for this session, so an
    /// unchanged page doesn't re-nag on the next focus. Cleared implicitly by
    /// new navigations via `dropAutofillSuggestion(forTabID:)`.
    @ObservationIgnored var dismissedAutofillHosts: Set<String> = []

    /// The "Save password?" / "Update password?" offer for a just-submitted
    /// login form; nil when no offer is showing. The submitted credential is
    /// held transiently in memory only while the chip is visible — never
    /// logged, never persisted, and only written to the Keychain by an
    /// explicit Save/Update click.
    var pendingPasswordCaptureOffer: PasswordCaptureOffer? = nil

    /// Hosts the user chose "Never for this site" for this session (the
    /// durable list lives in UserDefaults and is read via
    /// `neverSavePasswordHosts`).
    @ObservationIgnored var sessionNeverSavePasswordHosts: Set<String> = []

    // MARK: - Voice Mode (Comet)
    enum VoiceExecutionError: Error {
        case persistenceUnavailable
    }

    var isVoiceModeActive: Bool = false

    /// One lifecycle owner for spoken turns. The coordinator is deliberately
    /// separate from the recognizer: transcription is audio plumbing, while
    /// routing, clarification, cancellation, and trust gates are product
    /// behavior.
     var voiceCoordinator = VoiceCommandCoordinator()
    /// Shared trusted front door for voice and future hands-free text turns.
    /// It reuses this state's coordinator and durable stores so pending
    /// confirmations, preference writes, and audit records cannot diverge.
    var trustedTurnGateway: TrustedTurnGateway?
    /// Invalidates a voice submission even when the gateway's awaited executor
    /// has not observed cancellation yet. This prevents a late result from
    /// reaching speech output after the user pressed Stop.
    var voiceTurnGeneration: UInt64 = 0

    // MARK: - Profiles
    var profiles: [Profile] = []
    var currentProfileID: UUID = UUID()

    // MARK: - Workspaces
    var workspaces: [Workspace] = []
    var currentWorkspaceID: UUID = UUID()

    /// Per-workspace CEF profiles for cookie/storage isolation.
    /// Each workspace gets its own `CefProfile.persistent(name:)` stored under
    /// `<rootCachePath>/Profiles/<workspaceID>`. Created lazily on first access.
    var workspaceProfiles: [UUID: CefProfile] = [:]

    // MARK: - Tab Groups
    var tabGroups: [TabGroup] = []

    // MARK: - Group rename (window-level alert)

    /// The group awaiting a rename in the window-level alert; nil when closed.
    var renameGroupTargetID: UUID?
    /// Draft name captured when the rename alert opens (the alert owns edits).
    var renameGroupText: String = ""

    // MARK: - Tab rename (window-level alert)

    /// The tab awaiting a rename in the window-level alert; nil when closed.
    var renameTabTargetID: String?
    /// Draft name captured when the rename alert opens (the alert owns edits).
    var renameTabText: String = ""

    /// Transient feedback for the "Group Similar Tabs" action (e.g. "Grouped
    /// 6 tabs into 2 groups"). UI-only, auto-cleared, never persisted or
    /// included in page/memory context.
    var tabGroupingNotice: String? = nil
    @ObservationIgnored var tabGroupingNoticeTask: Task<Void, Never>?

    /// Transient app-wide toast feedback (Clear Browsing Data, Site Data,
    /// Bookmark All Tabs, …). UI-only, auto-cleared, never persisted.
    var appNotice: String? = nil
    @ObservationIgnored var appNoticeTask: Task<Void, Never>?

    /// Shows a transient app-wide toast, replacing any prior one (its pending
    /// auto-clear is cancelled so it can never wipe this new message), and
    /// clears itself after a few seconds. The single owner of the
    /// `appNotice`/`appNoticeTask` lifecycle — every action that reports an
    /// outcome through the toast routes through here.
    func showAppNotice(_ message: String) {
        appNoticeTask?.cancel()
        appNotice = message
        appNoticeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3.5))
            guard let self, !Task.isCancelled else { return }
            self.appNotice = nil
        }
    }

    /// Clear Browsing Data (Chrome parity) review sheet.
    var isClearDataPanelOpen: Bool = false

    // MARK: - Site Settings hub (Chrome content-settings parity)

    /// Per-site Settings hub sheet — every host with a remembered zoom, mute,
    /// HTTPS-Only exception, or permission decision.
    var isSiteSettingsPanelOpen: Bool = false

    /// Chrome ⇧⎋ Task Manager — live per-process memory/CPU from CEF.
    var isTaskManagerOpen: Bool = false
    /// Bumped by the sheet's refresh timer so @Observable recomputes rows.
    var taskManagerRefreshTick: Int = 0
    /// Host the hub should scroll to and expand when opened (set by the Site
    /// Security popover's "Site settings" row); nil opens the flat list.
    var siteSettingsFocusHost: String? = nil
    /// Monotonic revision bumped by every hub mutation (zoom, mute, HTTPS-Only
    /// exception, reset). The hub's stores are UserDefaults-backed computed
    /// properties that @Observable cannot track directly — the sheet reads
    /// this stored counter so its rows recompute after any edit.
    var siteSettingsRevision: Int = 0

    /// The web-research backend used by `/research` queries. Honest defaults:
    /// an existing Vane URL migrates to `.vane`; otherwise research stays off
    /// until the user picks a provider in Settings → Performance → Web Research.
    enum ResearchProvider: String, CaseIterable, Identifiable, Sendable, Codable {
        case off
        case vane
        case tavily

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .off: return "Off"
            case .vane: return "Vane"
            case .tavily: return "Tavily"
            }
        }
    }

    /// The user's selected research provider. An observable stored property so
    /// Settings UI re-renders when the picker changes; persisted to
    /// UserDefaults in didSet (an enum value, not a credential — AGENTS.md
    /// §9.2 rule 7). A stored value wins; otherwise a configured Vane URL
    /// migrates to `.vane`, else `.off`.
    var researchProvider: ResearchProvider = {
        if let raw = UserDefaults.standard.string(forKey: "HiveResearchProvider"),
           let provider = ResearchProvider(rawValue: raw) {
            return provider
        }
        let vaneURLSet = !(UserDefaults.standard.string(forKey: "HiveVaneBaseURL") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return vaneURLSet ? .vane : .off
    }() {
        didSet {
            guard researchProvider != oldValue else { return }
            UserDefaults.standard.set(researchProvider.rawValue, forKey: "HiveResearchProvider")
        }
    }

    /// Keychain account for the Tavily API key. Keys are credentials and live
    /// in Keychain, never in UserDefaults or plaintext config (AGENTS.md §9.2).
    static let tavilyAPIKeyAccount = "hive.tavily.apiKey"

    // MARK: - Deep Research (multi-step research engine)

    /// Deep research planner instance. Initialized lazily — only allocated
    /// when the user first runs a deep research query (memory-conscious).
    var deepResearchPlanner: DeepResearchPlanner?

    /// Tracks deep research progress for UI display.
     var deepResearchStep: ResearchStep?

    /// Unified agent pipeline state — council → research → browser actions.
     var agentTask: WebChromeAgentTask?
    var agentPipelineTask: Task<Void, Never>?

    /// Handle to the in-flight deep research Task. Cancel to abort.
    var deepResearchTask: Task<Void, Never>? = nil

    /// Builds a PageContext from the active tab for the orchestrator.
    /// Includes a brief visible-text excerpt from the page model when available.
    /// The scope preview (redaction + limits + sensitivity) of the last page
    /// context handed to the orchestrator — surfaced in ContextDiagnostics.
    var lastPageContextSummary: String?

    static let translateTLDNames: [String: String] = [
        "de": "German", "fr": "French", "es": "Spanish", "it": "Italian",
        "pt": "Portuguese", "ru": "Russian", "ja": "Japanese", "ko": "Korean",
        "zh": "Chinese", "ar": "Arabic", "nl": "Dutch", "pl": "Polish",
        "tr": "Turkish", "sv": "Swedish", "no": "Norwegian", "da": "Danish",
        "fi": "Finnish", "cs": "Czech", "hu": "Hungarian", "th": "Thai",
        "vi": "Vietnamese", "id": "Indonesian", "ro": "Romanian",
        "sk": "Slovak", "uk": "Ukrainian"
    ]

    init() {
        // Invariant: CefSwiftApp.main() initializes the CEF runtime BEFORE
        // SwiftUI builds this App/@State, so WebChromeBridge.register's
        // precondition (isInitialized) holds here. Do not move this call
        // ahead of the App entry point, and do not construct a
        // BrowserState outside the app lifecycle without CEF up.
        // The hive:// web chrome (start page) must be registered before the
        // first tab loads — setupDefaults() creates the initial tab.
        // hotMemory depends on honeycomb (declared below it); @Observable
        // forbids lazy, so bind it FIRST — all stored properties must be
        // initialized before `self` can be passed to register(with:).
        hotMemory = HotMemoryStore(honeycomb: honeycomb,
                                   persistenceURL: HotMemoryStore.defaultPersistenceURL)
        // Remove claims written by the pre-admission librarian path. New model
        // extraction is session-only until explicit user admission; this
        // idempotent migration prevents old durable claims from remaining
        // searchable in Knowledge after upgrade.
        isKnowledgePersistenceDegraded = honeycomb.isEphemeral
        isAuditPersistenceDegraded = eventLedger.isEphemeral
        hostContextPolicy = hostContextPolicyStore.initialPolicy
        WebChromeBridge.register(with: self)
        setupDefaults()
        // Session restore is complete before sync starts, so encrypted remote
        // merges compare against the full local projection.
        setupSync()
        // Mark the restored/default state dirty immediately. A process that
        // crashes before its first mutation must still be distinguishable from
        // an orderly shutdown on the next launch.
        let didWriteInitialSession = saveSession(isCleanExit: false)
        if !didWriteInitialSession {
            reportSessionPersistenceFailure()
        }
        migrateLegacySecrets()
        // AI components are heavy (ModelCouncil creates Tavily/Vane providers,
        // SwarmOrchestrator wires hotMemory + ledger). Defer to after the
        // browser shell appears so the user sees a window immediately.
        // setupAI() is called from the window's onAppear.
        trustedTurnGateway = TrustedTurnGateway(
            coordinator: voiceCoordinator,
            honeycomb: honeycomb,
            hotMemory: hotMemory,
            ledger: eventLedger
        )
        startHibernationTimer()
        startArchiveTimer()
        startProactiveBriefTimer()
        startResearchHandoffRecovery()

        // The web chrome shell: one persistent browser that renders the whole
        // UI in web content (sidebar/strip tabs, toolbar, panels). It uses the
        // default workspace's profile and is not a tab. Created after
        // setupDefaults() so a workspace exists to borrow its profile from.
        if chromeModel == nil {
            let chromeWorkspaceID = workspaces.first?.id ?? currentWorkspaceID
            var chromeOpts = CefBrowserOptions()
            chromeOpts.profile = cefProfile(for: chromeWorkspaceID)
            let model = CefWebViewModel(url: Self.webChromeURL, options: chromeOpts)
            chromeModel = model
            chromeMode = layout == .vertical ? .sidebar : .strip
            chromeDimension = chromeDefaultDimension
        }
        broadcastWebChromeState()

        // Opt-in marker for the local Chromium smoke harness. This proves only
        // that the browser state completed bootstrap and has a usable shell;
        // it does not claim page loading, model inference, voice permissions,
        // or privileged action approval.
        if ProcessInfo.processInfo.environment["HIVE_EMIT_READINESS_MARKER"] == "1" {
            let shellReady = !tabs.isEmpty && activeTabID != nil
            print(HiveReadinessReport(
                appInitialized: true,
                browserShellReady: shellReady,
                message: "browser shell initialized"
            ).markerLine())
            if ProcessInfo.processInfo.environment["HIVE_EMIT_SESSION_EVIDENCE"] == "1" {
                let durableTabCount = tabs.reduce(into: 0) { count, tab in
                    if !tab.isPrivate { count += 1 }
                }
                print(HiveSessionEvidence(
                    restoredFromDisk: sessionWasRestoredFromDisk,
                    priorCleanExit: restoredSessionPriorCleanExit,
                    snapshotSequence: sessionSnapshotSequence,
                    durableTabCount: durableTabCount,
                    writeSucceeded: didWriteInitialSession
                ).markerLine())
            }
            fflush(stdout)
        }
    }

    deinit {
        researchHandoffRecoveryTask?.cancel()
        proactiveBriefTask?.cancel()
        archiveTask?.cancel()
    }

    // MARK: - Web Chrome (hive://)

    /// The hand-drawn web start page, served by HiveSchemeHandler over the
    /// custom `hive://` scheme. SwiftUI chrome reads it as a clean empty state.
    static let webChromeStartURL = URL(string: "hive://start")!

    /// The Morning Brief new-tab destination (approved taste decision: brief
    /// as the default new tab; ``openBriefOnNewTab`` flips back to the start
    /// page). Private tabs always land on the start page — the brief is built
    /// from browsing data and must never surface in a private window.
    static let webChromeBriefURL = URL(string: "hive://brief")!

    /// The local agent workspace imported from the authorized Polar bundle.
    /// It is an ordinary Hive tab, so it inherits the active workspace/profile
    /// and remains subject to the same tab lifecycle and persistence rules.
    static let webChromePolarURL = URL(string: "hive://polar")!

    // MARK: - Omnibox Suggestions

    struct OmniboxSuggestion: Identifiable, Sendable {
        let id = UUID()
        let text: String
        let url: URL?
        let kind: Kind
        /// Tab ID for `.tab` kind — calls selectTab instead of navigate.
        var tabID: String? = nil
        /// Typed browser command for `.command` kind — never inferred from display text.
        var command: BrowserCommand? = nil
        enum Kind: Sendable { case history, bookmark, search, tab, command }
    }

    static let omniboxCommandRegistry = CommandRegistry()

    // MARK: - Split View
    /// Split orientation. `.sideBySide` = vertical divider (left/right),
    /// `.topBottom` = horizontal divider (top/bottom). Zen/Arc parity — both
    /// arrangements are first-class; the orientation is user-selectable.
    enum SplitOrientation: String, Sendable {
        case sideBySide
        case topBottom
    }

    var splitSecondaryTabID: String?
    /// Fraction (0.1–0.9) of the primary pane's dimension in split view.
    var splitRatio: Double = 0.5
    var splitOrientation: SplitOrientation = .sideBySide

    struct SessionData: Codable, Sendable {
        var layout: String
        var isCompactMode: Bool = false
        var showBookmarksBar: Bool
        var isMemorySaverEnabled: Bool = true
        var openBriefOnNewTab: Bool = true
        var enableProactiveBriefing: Bool = true
        var includeCalendarInBrief: Bool = false
        var accentColorHex: String
        var searchEngine: String = "Google"
        var preferredModelProvider: String = "auto"
        var splitSecondaryTabID: String?
        var splitRatio: Double = 0.5
        var splitOrientation: String = "sideBySide"
        var activeTabID: String?
        var currentProfileID: UUID
        var currentWorkspaceID: UUID
        var profiles: [CodableProfile]
        var workspaces: [CodableWorkspace]
        var tabGroups: [CodableTabGroup]
        var tabInfos: [CodableTabInfo]
        var bookmarks: [Bookmark]
        var history: [HistoryItem]
        /// Terminal download history only. Active CEF downloads are process-local
        /// and are intentionally never restored as controllable transfers.
        var downloads: [DownloadItem] = []
        var userDefinedCommands: [UserDefinedCommand] = []
        var tabZoomLevels: [String: Double] = [:]
        var installedExtensions: [ExtensionItem] = []
        var boosts: [Boost] = []
        /// Per-site permission decisions (camera, microphone, location, …).
        var sitePermissions: [SitePermission] = []
        /// Articles saved for later (Safari Reading List). Newest first;
        /// absent in older session files (decodes to empty).
        var readingList: [ReadingListEntry] = []
        /// Quick-launch web apps (Arc/Sidekick). Absent in older session files
        /// (decodes to empty).
        var pinnedWebApps: [PinnedWebApp] = []
        /// Recently-archived cold tabs (§7). Absent in older session files
        /// (decodes to empty).
        var archivedTabs: [ArchivedTab] = []
        /// Whether the periodic auto-archive pass runs. Default true.
        var enableAutoArchive: Bool = true
        /// Monotonic snapshot identity used to reason about backup freshness.
        var snapshotSequence: UInt64 = 0
        /// False means the previous process did not complete an orderly quit.
        var isCleanExit: Bool = false
        /// Explicit payload schema. Missing legacy values decode to version 1.
        var schemaVersion: Int = 1

        enum CodingKeys: String, CodingKey {
            case layout, isCompactMode, showBookmarksBar, isMemorySaverEnabled, openBriefOnNewTab, enableProactiveBriefing, includeCalendarInBrief, accentColorHex, searchEngine,
                 preferredModelProvider, splitSecondaryTabID, splitRatio, splitOrientation,
                 activeTabID, currentProfileID, currentWorkspaceID,
                 profiles, workspaces, tabGroups, tabInfos, bookmarks, history, downloads,
                 userDefinedCommands, tabZoomLevels, installedExtensions, boosts, sitePermissions, readingList, pinnedWebApps, archivedTabs, enableAutoArchive, snapshotSequence, isCleanExit, schemaVersion
        }

        init(layout: String, isCompactMode: Bool, showBookmarksBar: Bool, isMemorySaverEnabled: Bool = true, openBriefOnNewTab: Bool = true, enableProactiveBriefing: Bool = true, includeCalendarInBrief: Bool = false, accentColorHex: String,
             searchEngine: String, preferredModelProvider: String,
             splitSecondaryTabID: String?, splitRatio: Double, splitOrientation: String,
             activeTabID: String?,
             currentProfileID: UUID, currentWorkspaceID: UUID, profiles: [CodableProfile],
             workspaces: [CodableWorkspace], tabGroups: [CodableTabGroup],
             tabInfos: [CodableTabInfo], bookmarks: [Bookmark], history: [HistoryItem],
             downloads: [DownloadItem] = [], userDefinedCommands: [UserDefinedCommand] = [],
             tabZoomLevels: [String: Double] = [:], installedExtensions: [ExtensionItem] = [],
             boosts: [Boost] = [], sitePermissions: [SitePermission] = [],
             readingList: [ReadingListEntry] = [], pinnedWebApps: [PinnedWebApp] = [],
             archivedTabs: [ArchivedTab] = [], enableAutoArchive: Bool = true,
             snapshotSequence: UInt64 = 0, isCleanExit: Bool = false, schemaVersion: Int = 1) {
            self.layout = layout
            self.isCompactMode = isCompactMode
            self.showBookmarksBar = showBookmarksBar
            self.isMemorySaverEnabled = isMemorySaverEnabled
            self.openBriefOnNewTab = openBriefOnNewTab
            self.enableProactiveBriefing = enableProactiveBriefing
            self.includeCalendarInBrief = includeCalendarInBrief
            self.accentColorHex = accentColorHex
            self.searchEngine = searchEngine
            self.preferredModelProvider = preferredModelProvider
            self.splitSecondaryTabID = splitSecondaryTabID
            self.splitRatio = splitRatio
            self.splitOrientation = splitOrientation
            self.activeTabID = activeTabID
            self.currentProfileID = currentProfileID
            self.currentWorkspaceID = currentWorkspaceID
            self.profiles = profiles
            self.workspaces = workspaces
            self.tabGroups = tabGroups
            self.tabInfos = tabInfos
            self.bookmarks = bookmarks
            self.history = history
            self.downloads = downloads.filter { $0.isComplete || $0.isCanceled || $0.isInterrupted }
            self.userDefinedCommands = BrowserState.normalizedUserDefinedCommands(userDefinedCommands)
            self.tabZoomLevels = tabZoomLevels
            self.installedExtensions = installedExtensions
            self.boosts = boosts
            self.sitePermissions = sitePermissions
            self.readingList = readingList
            self.pinnedWebApps = pinnedWebApps
            self.archivedTabs = archivedTabs
            self.enableAutoArchive = enableAutoArchive
            self.snapshotSequence = snapshotSequence
            self.isCleanExit = isCleanExit
            self.schemaVersion = schemaVersion
        }

        /// Forward/backward compatible decode: fields added after the first
        /// release decode via `decodeIfPresent` so older session files never
        /// fail to load (no silent session reset on upgrade).
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            layout = try c.decodeIfPresent(String.self, forKey: .layout)
                ?? BrowserChromePreferences.defaultLayout
            isCompactMode = try c.decodeIfPresent(Bool.self, forKey: .isCompactMode) ?? false
            showBookmarksBar = try c.decodeIfPresent(Bool.self, forKey: .showBookmarksBar) ?? false
            isMemorySaverEnabled = try c.decodeIfPresent(Bool.self, forKey: .isMemorySaverEnabled) ?? true
            openBriefOnNewTab = try c.decodeIfPresent(Bool.self, forKey: .openBriefOnNewTab) ?? true
            enableProactiveBriefing = try c.decodeIfPresent(Bool.self, forKey: .enableProactiveBriefing) ?? true
            includeCalendarInBrief = try c.decodeIfPresent(Bool.self, forKey: .includeCalendarInBrief) ?? false
            accentColorHex = try c.decode(String.self, forKey: .accentColorHex)
            searchEngine = try c.decodeIfPresent(String.self, forKey: .searchEngine) ?? "Google"
            preferredModelProvider = try c.decodeIfPresent(String.self, forKey: .preferredModelProvider) ?? "auto"
            splitSecondaryTabID = try c.decodeIfPresent(String.self, forKey: .splitSecondaryTabID)
            splitRatio = try c.decodeIfPresent(Double.self, forKey: .splitRatio) ?? 0.5
            splitOrientation = try c.decodeIfPresent(String.self, forKey: .splitOrientation) ?? "sideBySide"
            activeTabID = try c.decodeIfPresent(String.self, forKey: .activeTabID)
            currentProfileID = try c.decode(UUID.self, forKey: .currentProfileID)
            currentWorkspaceID = try c.decode(UUID.self, forKey: .currentWorkspaceID)
            profiles = try c.decode([CodableProfile].self, forKey: .profiles)
            workspaces = try c.decode([CodableWorkspace].self, forKey: .workspaces)
            tabGroups = try c.decode([CodableTabGroup].self, forKey: .tabGroups)
            tabInfos = try c.decode([CodableTabInfo].self, forKey: .tabInfos)
            bookmarks = try c.decode([Bookmark].self, forKey: .bookmarks)
            history = try c.decode([HistoryItem].self, forKey: .history)
            // Only terminal history is meaningful after relaunch. Older or
            // hand-edited session files may contain active rows; discard them
            // rather than showing controls backed by no CEF download object.
            downloads = (try c.decodeIfPresent([DownloadItem].self, forKey: .downloads) ?? [])
                .filter { $0.isComplete || $0.isCanceled || $0.isInterrupted }
            userDefinedCommands = BrowserState.normalizedUserDefinedCommands(
                try c.decodeIfPresent([UserDefinedCommand].self, forKey: .userDefinedCommands) ?? [])
            // Forward-compatible: older session files have no zoom levels.
            tabZoomLevels = try c.decodeIfPresent([String: Double].self, forKey: .tabZoomLevels) ?? [:]
            installedExtensions = try c.decodeIfPresent([ExtensionItem].self, forKey: .installedExtensions) ?? []
            boosts = try c.decodeIfPresent([Boost].self, forKey: .boosts) ?? []
            sitePermissions = try c.decodeIfPresent([SitePermission].self, forKey: .sitePermissions) ?? []
            readingList = try c.decodeIfPresent([ReadingListEntry].self, forKey: .readingList) ?? []
            pinnedWebApps = try c.decodeIfPresent([PinnedWebApp].self, forKey: .pinnedWebApps) ?? []
            archivedTabs = try c.decodeIfPresent([ArchivedTab].self, forKey: .archivedTabs) ?? []
            enableAutoArchive = try c.decodeIfPresent(Bool.self, forKey: .enableAutoArchive) ?? true
            snapshotSequence = try c.decodeIfPresent(UInt64.self, forKey: .snapshotSequence) ?? 0
            isCleanExit = try c.decodeIfPresent(Bool.self, forKey: .isCleanExit) ?? false
            schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            guard schemaVersion == 1 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .schemaVersion,
                    in: c,
                    debugDescription: "Unsupported Chromium session schema \(schemaVersion)"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(layout, forKey: .layout)
            try c.encode(isCompactMode, forKey: .isCompactMode)
            try c.encode(showBookmarksBar, forKey: .showBookmarksBar)
            try c.encode(isMemorySaverEnabled, forKey: .isMemorySaverEnabled)
            try c.encode(openBriefOnNewTab, forKey: .openBriefOnNewTab)
            try c.encode(enableProactiveBriefing, forKey: .enableProactiveBriefing)
            try c.encode(includeCalendarInBrief, forKey: .includeCalendarInBrief)
            try c.encode(accentColorHex, forKey: .accentColorHex)
            try c.encode(searchEngine, forKey: .searchEngine)
            try c.encode(preferredModelProvider, forKey: .preferredModelProvider)
            try c.encodeIfPresent(splitSecondaryTabID, forKey: .splitSecondaryTabID)
            try c.encode(splitRatio, forKey: .splitRatio)
            try c.encode(splitOrientation, forKey: .splitOrientation)
            try c.encodeIfPresent(activeTabID, forKey: .activeTabID)
            try c.encode(currentProfileID, forKey: .currentProfileID)
            try c.encode(currentWorkspaceID, forKey: .currentWorkspaceID)
            try c.encode(profiles, forKey: .profiles)
            try c.encode(workspaces, forKey: .workspaces)
            try c.encode(tabGroups, forKey: .tabGroups)
            try c.encode(tabInfos, forKey: .tabInfos)
            try c.encode(bookmarks, forKey: .bookmarks)
            try c.encode(history, forKey: .history)
            try c.encode(downloads.filter { $0.isComplete || $0.isCanceled || $0.isInterrupted }, forKey: .downloads)
            try c.encode(userDefinedCommands.filter(\.isValidWebURL), forKey: .userDefinedCommands)
            try c.encode(tabZoomLevels, forKey: .tabZoomLevels)
            try c.encode(installedExtensions, forKey: .installedExtensions)
            try c.encode(boosts, forKey: .boosts)
            try c.encode(readingList, forKey: .readingList)
            try c.encode(pinnedWebApps, forKey: .pinnedWebApps)
            try c.encode(archivedTabs, forKey: .archivedTabs)
            try c.encode(enableAutoArchive, forKey: .enableAutoArchive)
            try c.encode(sitePermissions, forKey: .sitePermissions)
            try c.encode(snapshotSequence, forKey: .snapshotSequence)
            try c.encode(isCleanExit, forKey: .isCleanExit)
            try c.encode(schemaVersion, forKey: .schemaVersion)
        }
    }

    struct CodableProfile: Codable, Sendable { let id: UUID; let name: String; let iconName: String; let colorHex: String }
    struct CodableWorkspace: Codable, Sendable { let id: UUID; let name: String; let colorHex: String; let iconName: String; let profileID: UUID }
    struct CodableTabGroup: Codable, Sendable {
        let id: UUID
        let name: String
        let colorHex: String
        let workspaceID: UUID
        let isCollapsed: Bool

        enum CodingKeys: String, CodingKey {
            case id, name, colorHex, workspaceID, isCollapsed
        }

        init(id: UUID, name: String, colorHex: String, workspaceID: UUID, isCollapsed: Bool = false) {
            self.id = id
            self.name = name
            self.colorHex = colorHex
            self.workspaceID = workspaceID
            self.isCollapsed = isCollapsed
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            colorHex = try container.decode(String.self, forKey: .colorHex)
            workspaceID = try container.decode(UUID.self, forKey: .workspaceID)
            // Older session files predate group collapse; preserve their
            // groups as expanded instead of rejecting the whole session.
            isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        }
    }
    struct CodableTabInfo: Codable, Sendable {
        let id: String
        /// The last committed URL. For a hibernated tab this is the saved URL,
        /// not the detached renderer's transient URL.
        let urlString: String?
        let workspaceID: UUID
        let profileID: UUID
        let groupID: UUID?
        let isPinned: Bool
        let isEssential: Bool
        /// Forward-compatible only; private tabs are dropped on save and restore.
        let isPrivate: Bool?
        /// Hibernation is a renderer-lifetime state, not page content. Persist
        /// it so relaunch does not eagerly recreate every cold renderer.
        let isHibernated: Bool?
        /// The URL to use when the renderer is woken. Kept separately from
        /// `urlString` so future schema changes cannot lose the cold tab's page.
        let savedURLString: String?
        /// User-assigned nickname; optional so pre-rename session files decode
        /// as unrenamed tabs (synthesized Codable uses `decodeIfPresent`).
        let customTitle: String?
    }

    /// Honest recovery metadata surfaced when the persisted session file could
    /// not be decoded. `recoveredFromBackup` is true when the last known-good
    /// rolling backup was used; `quarantineURL` points at the unreadable copy
    /// that was set aside (never deleted) so the user can inspect it.
    struct SessionRecoveryNotice: Sendable, Equatable {
        let recoveredFromBackup: Bool
        let quarantineURL: URL?
        let uncleanExit: Bool

        init(recoveredFromBackup: Bool, quarantineURL: URL?, uncleanExit: Bool = false) {
            self.recoveredFromBackup = recoveredFromBackup
            self.quarantineURL = quarantineURL
            self.uncleanExit = uncleanExit
        }
    }

    /// Set during `setupDefaults()` when a corrupt session file was detected;
    /// drives the honest recovery banner in the window. Nil on a clean start.
    var sessionRecoveryNotice: SessionRecoveryNotice?

    /// Repairs applied to the last durable session before CEF rehydration.
    /// Kept as structured data for diagnostics and future user-facing recovery
    /// detail; normal browsing never depends on this list being empty.
     var sessionRepairReasons: [TabOrganizationNormalizer.RepairReason] = []
    /// Session-health details are transient: dismissing them acknowledges this
    /// launch without deleting repair evidence from the durable session record.
    var sessionRepairNoticeDismissed: Bool = false

    /// The last committed snapshot number. It is local diagnostic state only;
    /// the payload never contains page text or private-tab data.
    var sessionSnapshotSequence: UInt64 = 0
    /// Local-only lifecycle facts used by the opt-in smoke contract. These
    /// values never enter Swarm context or product telemetry.
    var sessionWasRestoredFromDisk = false
    var restoredSessionPriorCleanExit: Bool?

    // MARK: - Tab hooks (downloads, history backfill)

    var tabObservationTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Native context menu (Chrome / Edge / Safari parity)

    /// App-defined context-menu command IDs (CEF's user range: 26500-28500).
    enum HiveContextMenuAction: Int {
        case openLinkInNewTab = 26501
        case openLinkInSplit = 26502
        case copyLinkAddress = 26503
        case openImageInNewTab = 26504
        case copyImageAddress = 26505
        case saveImageAs = 26506
        case searchSelection = 26507
        case askHiveSelection = 26508
        case askHivePage = 26509
        case createBoostForPage = 26510
        case addToReadingList = 26511
        case removeFromReadingList = 26512
        case addToPinnedApps = 26513
        case removeFromPinnedApps = 26514
        case capturePageScreenshot = 26515
        case copyPageScreenshot = 26516
        case copyPageURL = 26517
        case copyAllTabURLs = 26518
        case copyAllTabsMarkdown = 26519
        case captureFullPageScreenshot = 26520
        case copyFullPageScreenshot = 26521
    }

    var autosaveTask: Task<Void, Never>?

    // MARK: - Tab Hibernation

    var hibernationTask: Task<Void, Never>?

    // MARK: - Proactive Briefing (P2.6)

    /// Handle to the daily-rollover refresh task. Cancelled on deinit like the
    /// hibernation timer. `@ObservationIgnored` (matching the handoff recovery
    /// task) so deinit — a nonisolated context — can cancel it.
    @ObservationIgnored var proactiveBriefTask: Task<Void, Never>?

    /// The last calendar-day ordinal for which a proactive-brief pass ran.
    /// Drives the once-per-day regeneration; not persisted (the brief rebuilds
    /// on every serve regardless).
    var lastProactiveBriefDay: Int = 0
}

struct Bookmark: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var urlString: String
    var faviconURL: URL?
    /// True for a folder (no url). Folders group bookmarks via `parentID`.
    var isFolder: Bool
    /// The id of the folder this bookmark lives in; nil = root level.
    var parentID: UUID?

    var url: URL { URL(string: urlString) ?? URL(string: "about:blank")! }

    /// A folder bookmark has no navigation target.
    var isNavigable: Bool { !isFolder && !urlString.isEmpty }

    enum CodingKeys: String, CodingKey { case id, title, urlString, faviconURL, isFolder, parentID }

    init(id: UUID = UUID(), title: String, url: URL, faviconURL: URL? = nil) {
        self.id = id
        self.title = title
        self.urlString = url.absoluteString
        self.faviconURL = faviconURL
        self.isFolder = false
        self.parentID = nil
    }

    init(id: UUID = UUID(), title: String, urlString: String, faviconURL: URL? = nil, isFolder: Bool = false, parentID: UUID? = nil) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.faviconURL = faviconURL
        self.isFolder = isFolder
        self.parentID = parentID
    }

    /// Folder convenience initializer (no URL).
    init(folderID: UUID = UUID(), title: String, parentID: UUID? = nil) {
        self.init(id: folderID, title: title, urlString: "", isFolder: true, parentID: parentID)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        urlString = try c.decode(String.self, forKey: .urlString)
        faviconURL = try c.decodeIfPresent(URL.self, forKey: .faviconURL)
        // Folders shipped after the first session format; older files are all
        // root-level content bookmarks.
        isFolder = try c.decodeIfPresent(Bool.self, forKey: .isFolder) ?? false
        parentID = try c.decodeIfPresent(UUID.self, forKey: .parentID)
    }

    /// Bookmarks start empty — imported from other browsers or added by the user.
    static let defaults: [Bookmark] = []
}

// MARK: - Array safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - InferenceError user-facing messages

extension InferenceError {
    var userMessage: String {
        switch self {
        case .roleUnsupported(let role):
            return "The \(role.displayLabel) role is not supported on this device."
        case .weightsNotDownloaded(let repo):
            return "Model weights (\(repo)) need to be downloaded first. Connect an AI provider in Settings."
        case .generationFailed(let detail):
            return "Generation failed: \(detail)"
        case .appleFMFUnavailable:
            return "Apple on-device AI requires macOS 26 or later."
        case .byokNotConfigured:
            return "No AI provider connected. Add an API key in Settings."
        }
    }
}
