import Foundation

// MARK: - HiveTheme
//
// SPEC §23.1 — the three built-in appearance modes. `.system` follows the OS appearance
// setting; `.hiveDark` forces dark mode; `.hiveLight` forces light mode.

public enum HiveTheme: String, Sendable, Codable, CaseIterable {
    /// Follow the OS appearance setting (light/dark).
    case system
    /// Force Hive Dark — warm near-black with amber accent.
    case hiveDark
    /// Force Hive Light — warm near-white with deeper amber accent.
    case hiveLight

    public var displayName: String {
        switch self {
        case .system:   return "System"
        case .hiveDark:  return "Hive Dark"
        case .hiveLight: return "Hive Light"
        }
    }
}

// MARK: - ChromeUserPrefs (Codable, persisted)
//
// The durable browser preferences that survive restart: chosen tab layout (H or V — never
// both), tab density, sidebar open state, accent/tint. Pure Codable in HiveCore so it can
// be unit-tested, persisted, and read by the Hive target's observable ChromeState.
//
// The owner's binding directive — "HIVE LETS USERS PICK ONE OR THE OTHER. NOT BOTH AT THE
// SAME TIME." — is encoded as a single `tabPosition` field rather than a set; there is no
// "show both" knob.

public struct ChromeUserPrefs: Sendable, Codable, Equatable {

    /// Which tab layout is active. Exactly one is rendered. ⌘⇧L toggles (top ↔ vertical).
    public var tabPosition: TabPosition

    /// Horizontal tab pill density (compact / standard / spacious).
    public var tabDensity: TabDensity

    /// True when the left sidebar is open (bookmarks/history views). In vertical mode the
    /// sidebar is the tab bar itself, so this flag is reinterpreted there.
    public var sidebarOpen: Bool

    /// Default search engine (by case name; resolved in Hive's SearchEngine registry).
    public var defaultSearchEngine: String

    /// Whether Reduce-Motion-landing animations should additionally be honored even when
    /// the system preference is off (extra-respect).
    public var honorReduceMotion: Bool

    /// Last selected Space ID (restored on launch for vertical mode).
    public var activeSpaceID: String?

    /// Last fully-closed-tab records for ⌘⇧T (reopen). Capped to keep the file lean.
    public var recentlyClosed: [ClosedTabRecord]

    /// Whether the vertical tab rail renders tabs as a collapsible tree (slice 7).
    /// Off by default; only affects the vertical layout.
    public var isTreeMode: Bool

    /// Set of parent tab IDs whose children are currently collapsed in tree mode.
    public var treeCollapsedParentIDs: [String]

    /// Whether the first-launch onboarding flow (welcome → import → layout) has been completed.
    /// False by default so every fresh install sees onboarding; once complete the flag is persisted.
    public var hasCompletedOnboarding: Bool

    /// Tab IDs currently displayed in Split View (2–4 panes). Empty = no split.
    /// Order is display order (left→right in horizontal, top→bottom in vertical).
    public var splitTabIDs: [String]

    /// Whether the built-in content blocker (ad + tracker blocking via WKContentRuleList)
    /// is active. Defaults to true — privacy-first by default.
    public var contentBlockerEnabled: Bool

    /// Per-site permission grants (camera, microphone, location, notifications, etc.).
    public var sitePermissions: [SitePermission]

    /// Whether to enforce HTTPS-only connections, upgrading HTTP requests automatically.
    /// Defaults to true — secure by default.
    public var enforceHTTPS: Bool

    /// Hosts explicitly excepted from HTTPS-Only enforcement (e.g. "example.com"). When a
    /// host is in this list, http:// requests to it are allowed without upgrade. The list is
    /// user-managed and survives restart.
    public var httpsOnlyExceptions: [String]

    /// Browsing history entries (⌘Y panel). Newest first. Capped at `hiveHistoryCap`.
    public var historyEntries: [BrowsingHistoryEntry]

    /// User's bookmarks. Root-level bookmarks and folders. Nested via Bookmark.parentID.
    public var bookmarks: [Bookmark]

    /// Whether the bookmark bar is visible below the omnibar.
    public var showBookmarkBar: Bool

    /// The axis of the split layout. `.horizontal` = side-by-side, `.vertical` = stacked.
    public var splitOrientation: SplitOrientation

    /// Whether Global Privacy Control (GPC / Sec-GPC: 1) is enabled. When true, every
    /// page request includes the Sec-GPC header signaling "Do Not Sell or Share My
    /// Personal Information." Honoured by CCPA-compliant sites. Defaults to true.
    public var globalPrivacyControlEnabled: Bool

    /// DNS-over-HTTPS resolver URL. Empty = system DNS. Examples:
    /// "https://cloudflare-dns.com/dns-query", "https://dns.quad9.net/dns-query".
    public var dohResolver: String

    /// DNS-over-TLS resolver host. Empty = system DNS.
    public var dotResolver: String

    /// Proxy type: "none", "http" (HTTP CONNECT), "socks5", "pac".
    public var proxyType: String

    /// Proxy server host. Only used when proxyType != "none" && proxyType != "pac".
    public var proxyHost: String

    /// Proxy server port. Only used when proxyType != "none" && proxyType != "pac".
    public var proxyPort: Int

    /// Proxy username for SOCKS5 authentication.
    public var proxyUsername: String

    /// PAC file URL. Only used when proxyType == "pac".
    public var pacFileURL: String

    /// Whether to bypass the proxy for local (loopback / RFC 1918) addresses.
    public var proxyBypassLocal: Bool

    // MARK: - BYOK (Bring Your Own Key) model provider config

    /// Whether the user has opted into using their own remote model provider.
    public var byokEnabled: Bool

    /// Whether Tavily cloud research is enabled (free tier, always-available).
    /// Requires TAVILY_API_KEY env var to actually function; this flag lets
    /// users explicitly opt out even when the key is present.
    public var tavilyEnabled: Bool

    /// Base URL for the OpenAI-compatible /chat/completions endpoint
    /// (e.g. "https://api.openai.com/v1" or a LiteLLM proxy).
    public var byokBaseURL: String

    /// Model ID to request from the endpoint (e.g. "gpt-4o", "deepseek-v4-pro").
    public var byokModelID: String

    /// Keychain alias under which the API key is stored. The actual key never
    /// touches prefs; only this alias does.
    /// Keychain alias under which the API key is stored. The actual key never
    /// touches prefs; only this alias does.
    public var byokKeyAlias: String

    // MARK: - Web research (Vane / Perplexica) config

    /// Whether the user has enabled the self-hosted Vane search provider.
    public var vaneEnabled: Bool

    /// Base URL of the Vane instance (e.g. "http://localhost:3000").
    public var vaneBaseURL: String

    /// Default focus mode for web research queries.
    public var vaneDefaultFocusMode: WebSearchFocusMode

    /// The active visual theme. SPEC §23 — determines dark/light/system appearance.
    /// Defaults to `.system` so new installs follow the OS setting.
    public var theme: HiveTheme

    /// Custom accent color, stored as a HiveColorToken raw value (e.g. "accent" for the
    /// default amber). Users can pick any of the predefined HiveColorToken values.
    /// Defaults to the Hive amber accent.
    public var accentColorName: String

    /// Whether the chrome (omnibar + tab bar) should auto-compress when scrolling down.
    /// When true, scrolling down telescopes the chrome to give more content space;
    /// scrolling up restores it. Defaults to true.
    public var chromeAutoHideEnabled: Bool

    /// User's pinned web apps — persistent app sidebar (Pinned Web Apps feature).
    /// Each entry is a lightweight model of a web app pinned to the sidebar rail.
    /// Persisted alongside bookmarks so pinned apps survive restart.
    public var pinnedWebApps: [PinnedWebApp]

    /// Whether Hive's Automatic-Capture moat (PITCH/competitive-ai-gap-ledger gap 7) is
    /// opted in. When true, on page-load-finish Hive runs the `captureScribe` Cell over
    /// the captured page text to decide keep/skip + extract {facts, decisions,
    /// commitments} into Honeycomb (see `ChromeState.autoCaptureDidFinish`). Defaults
    /// OFF: the `capture_scribe` prompt mandates per-surface opt-in ("Capture is opt-in
    /// per surface… absent → default skip"). Private tabs are ALWAYS excluded regardless
    /// of this flag. This is the backend integration of the scribe invocation route
    /// (PITCH/backend-completion.md Track A) — it degrades honestly to MockRuntime when
    /// MLX isn't linked, so the path is complete and correct with or without local
    /// inference wired.
    public var autoCaptureEnabled: Bool

    /// User's reading list — articles saved for later (⌘⇧L panel).
    /// Persisted alongside bookmarks and history. Newest first.
    public var readingList: [ReadingListEntry]

    /// User-defined palette commands — custom ⌘K launcher entries.
    /// Each entry opens a URL in a new tab when selected from the command palette.
    /// Persisted so commands survive restart.
    public var userDefinedCommands: [UserDefinedCommand]

    public init(tabPosition: TabPosition = .vertical,
                tabDensity: TabDensity = .standard,
                sidebarOpen: Bool = false,
                defaultSearchEngine: String = "Google",
                honorReduceMotion: Bool = true,
                activeSpaceID: String? = nil,
                recentlyClosed: [ClosedTabRecord] = [],
                isTreeMode: Bool = false,
                treeCollapsedParentIDs: [String] = [],
                hasCompletedOnboarding: Bool = false,
                splitTabIDs: [String] = [],
                splitOrientation: SplitOrientation = .horizontal,
                sitePermissions: [SitePermission] = [],
                contentBlockerEnabled: Bool = true,
                enforceHTTPS: Bool = true,
                httpsOnlyExceptions: [String] = [],
                historyEntries: [BrowsingHistoryEntry] = [],
                bookmarks: [Bookmark] = [],
                showBookmarkBar: Bool = false,
                globalPrivacyControlEnabled: Bool = true,
                dohResolver: String = "",
                dotResolver: String = "",
                proxyType: String = "none",
                proxyHost: String = "",
                proxyPort: Int = 0,
                proxyUsername: String = "",
                pacFileURL: String = "",
                proxyBypassLocal: Bool = true,
                byokEnabled: Bool = false,
                tavilyEnabled: Bool = true,
                byokBaseURL: String = "",
                byokModelID: String = "",
                byokKeyAlias: String = "",
                vaneEnabled: Bool = false,
                vaneBaseURL: String = "",
                vaneDefaultFocusMode: WebSearchFocusMode = .webSearch,
                readingList: [ReadingListEntry] = [],
                theme: HiveTheme = .system,
                accentColorName: String = HiveColorToken.accent.rawValue,
                chromeAutoHideEnabled: Bool = true,
                pinnedWebApps: [PinnedWebApp] = [],
                autoCaptureEnabled: Bool = false,
                userDefinedCommands: [UserDefinedCommand] = []) {
        self.tabPosition = tabPosition
        self.tabDensity = tabDensity
        self.sidebarOpen = sidebarOpen
        self.defaultSearchEngine = defaultSearchEngine
        self.honorReduceMotion = honorReduceMotion
        self.activeSpaceID = activeSpaceID
        self.recentlyClosed = recentlyClosed
        self.isTreeMode = isTreeMode
        self.treeCollapsedParentIDs = treeCollapsedParentIDs
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.splitTabIDs = splitTabIDs
        self.splitOrientation = splitOrientation
        self.sitePermissions = sitePermissions
        self.contentBlockerEnabled = contentBlockerEnabled
        self.enforceHTTPS = enforceHTTPS
        self.httpsOnlyExceptions = httpsOnlyExceptions
        self.historyEntries = historyEntries
        self.bookmarks = bookmarks
        self.showBookmarkBar = showBookmarkBar
        self.globalPrivacyControlEnabled = globalPrivacyControlEnabled
        self.dohResolver = dohResolver
        self.dotResolver = dotResolver
        self.proxyType = proxyType
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
        self.proxyUsername = proxyUsername
        self.pacFileURL = pacFileURL
        self.proxyBypassLocal = proxyBypassLocal
        self.byokEnabled = byokEnabled
        self.tavilyEnabled = tavilyEnabled
        self.byokBaseURL = byokBaseURL
        self.byokModelID = byokModelID
        self.byokKeyAlias = byokKeyAlias
        self.vaneEnabled = vaneEnabled
        self.vaneBaseURL = vaneBaseURL
        self.vaneDefaultFocusMode = vaneDefaultFocusMode
        self.theme = theme
        self.accentColorName = accentColorName
        self.readingList = readingList
        self.chromeAutoHideEnabled = chromeAutoHideEnabled
        self.pinnedWebApps = pinnedWebApps
        self.autoCaptureEnabled = autoCaptureEnabled
        self.userDefinedCommands = userDefinedCommands
    }

    // MARK: Forward-compatible Codable
    //
    // Prefs files outlive app updates. New fields must have a sensible default so an
    // older `chrome.json` still loads without failing the whole decode.

    private enum CodingKeys: String, CodingKey {
        case tabPosition, tabDensity, sidebarOpen, defaultSearchEngine
        case honorReduceMotion, activeSpaceID, recentlyClosed
        case isTreeMode, treeCollapsedParentIDs
        case hasCompletedOnboarding
        case splitTabIDs, splitOrientation
        case contentBlockerEnabled, enforceHTTPS, httpsOnlyExceptions, historyEntries, bookmarks, showBookmarkBar, sitePermissions, globalPrivacyControlEnabled, dohResolver, dotResolver, proxyType, proxyHost, proxyPort, proxyUsername, pacFileURL, proxyBypassLocal, byokEnabled, tavilyEnabled, byokBaseURL, byokModelID, byokKeyAlias, vaneEnabled, vaneBaseURL, vaneDefaultFocusMode, theme, accentColorName, readingList, chromeAutoHideEnabled, pinnedWebApps, autoCaptureEnabled, userDefinedCommands
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tabPosition = try c.decodeIfPresent(TabPosition.self, forKey: .tabPosition) ?? .vertical
        tabDensity = try c.decodeIfPresent(TabDensity.self, forKey: .tabDensity) ?? .standard
        sidebarOpen = try c.decodeIfPresent(Bool.self, forKey: .sidebarOpen) ?? false
        defaultSearchEngine = try c.decodeIfPresent(String.self, forKey: .defaultSearchEngine) ?? "Google"
        honorReduceMotion = try c.decodeIfPresent(Bool.self, forKey: .honorReduceMotion) ?? true
        activeSpaceID = try c.decodeIfPresent(String.self, forKey: .activeSpaceID)
        recentlyClosed = try c.decodeIfPresent([ClosedTabRecord].self, forKey: .recentlyClosed) ?? []
        isTreeMode = try c.decodeIfPresent(Bool.self, forKey: .isTreeMode) ?? false
        treeCollapsedParentIDs = try c.decodeIfPresent([String].self, forKey: .treeCollapsedParentIDs) ?? []
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        splitTabIDs = try c.decodeIfPresent([String].self, forKey: .splitTabIDs) ?? []
        splitOrientation = try c.decodeIfPresent(SplitOrientation.self, forKey: .splitOrientation) ?? .horizontal
        contentBlockerEnabled = try c.decodeIfPresent(Bool.self, forKey: .contentBlockerEnabled) ?? true
        enforceHTTPS = try c.decodeIfPresent(Bool.self, forKey: .enforceHTTPS) ?? true
        httpsOnlyExceptions = try c.decodeIfPresent([String].self, forKey: .httpsOnlyExceptions) ?? []
        sitePermissions = try c.decodeIfPresent([SitePermission].self, forKey: .sitePermissions) ?? []
        historyEntries = try c.decodeIfPresent([BrowsingHistoryEntry].self, forKey: .historyEntries) ?? []
        bookmarks = try c.decodeIfPresent([Bookmark].self, forKey: .bookmarks) ?? []
        showBookmarkBar = try c.decodeIfPresent(Bool.self, forKey: .showBookmarkBar) ?? false
        globalPrivacyControlEnabled = try c.decodeIfPresent(Bool.self, forKey: .globalPrivacyControlEnabled) ?? true
        dohResolver = try c.decodeIfPresent(String.self, forKey: .dohResolver) ?? ""
        dotResolver = try c.decodeIfPresent(String.self, forKey: .dotResolver) ?? ""
        proxyType = try c.decodeIfPresent(String.self, forKey: .proxyType) ?? "none"
        proxyHost = try c.decodeIfPresent(String.self, forKey: .proxyHost) ?? ""
        proxyPort = try c.decodeIfPresent(Int.self, forKey: .proxyPort) ?? 0
        proxyUsername = try c.decodeIfPresent(String.self, forKey: .proxyUsername) ?? ""
        pacFileURL = try c.decodeIfPresent(String.self, forKey: .pacFileURL) ?? ""
        proxyBypassLocal = try c.decodeIfPresent(Bool.self, forKey: .proxyBypassLocal) ?? true
        byokEnabled = try c.decodeIfPresent(Bool.self, forKey: .byokEnabled) ?? false
        tavilyEnabled = try c.decodeIfPresent(Bool.self, forKey: .tavilyEnabled) ?? true
        byokBaseURL = try c.decodeIfPresent(String.self, forKey: .byokBaseURL) ?? ""
        byokModelID = try c.decodeIfPresent(String.self, forKey: .byokModelID) ?? ""
        byokKeyAlias = try c.decodeIfPresent(String.self, forKey: .byokKeyAlias) ?? ""
        vaneEnabled = try c.decodeIfPresent(Bool.self, forKey: .vaneEnabled) ?? false
        vaneBaseURL = try c.decodeIfPresent(String.self, forKey: .vaneBaseURL) ?? ""
        vaneDefaultFocusMode = try c.decodeIfPresent(WebSearchFocusMode.self, forKey: .vaneDefaultFocusMode) ?? .webSearch
        theme = try c.decodeIfPresent(HiveTheme.self, forKey: .theme) ?? .system
        accentColorName = try c.decodeIfPresent(String.self, forKey: .accentColorName) ?? HiveColorToken.accent.rawValue
        readingList = try c.decodeIfPresent([ReadingListEntry].self, forKey: .readingList) ?? []
        chromeAutoHideEnabled = try c.decodeIfPresent(Bool.self, forKey: .chromeAutoHideEnabled) ?? true
        pinnedWebApps = try c.decodeIfPresent([PinnedWebApp].self, forKey: .pinnedWebApps) ?? []
        autoCaptureEnabled = try c.decodeIfPresent(Bool.self, forKey: .autoCaptureEnabled) ?? false
        userDefinedCommands = try c.decodeIfPresent([UserDefinedCommand].self, forKey: .userDefinedCommands) ?? []
    }

    /// The default prefs a fresh install ships with.
    public static let defaults = ChromeUserPrefs()
}

// MARK: - Recently-closed cap

public extension Array where Element == ClosedTabRecord {
    /// Cap the closed-tab stack (SPEC ⌘⇧T reopens the most-recent; older overflow drops).
    static let hiveClosedTabCap = 25
}

// MARK: - Reading list cap

public extension Array where Element == ReadingListEntry {
    /// Maximum reading list entries retained. Oldest entries drop on overflow.
    /// Same order of magnitude as the history cap to keep prefs files lean.
    static let hiveReadingListCap = 500
}

// MARK: - UserDefinedCommand

/// A user-created palette command that opens a URL when selected.
/// Persisted in `ChromeUserPrefs` so custom commands survive restart.
public struct UserDefinedCommand: Sendable, Codable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var url: String
    public var icon: String
    public var keywords: [String]

    /// Keep the palette visually reliable when a command is imported or hand-edited.
    /// These are intentionally common, bundled SF Symbols rather than arbitrary names.
    public static let allowedIcons: Set<String> = [
        "link", "bell", "bookmark", "star", "folder", "globe",
        "terminal", "doc.text", "calendar", "bolt", "gear", "sparkles",
        "rectangle.and.pencil.and.ellipsis"
    ]

    public init(id: String = UUID().uuidString,
                title: String,
                url: String,
                icon: String = "link",
                keywords: [String] = []) {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = trimmedID.isEmpty ? UUID().uuidString : trimmedID
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = Self.allowedIcons.contains(trimmedIcon) ? trimmedIcon : "link"
        self.keywords = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, url, icon, keywords
    }

    /// Decode through the same normalizing initializer used by UI-created commands.
    /// Preference/session JSON is user-editable data, so it must not bypass the
    /// trimming, icon fallback, or keyword cleanup performed at construction.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            url: try container.decode(String.self, forKey: .url),
            icon: try container.decodeIfPresent(String.self, forKey: .icon) ?? "link",
            keywords: try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        )
    }

    /// Custom commands are navigation affordances, so they are restricted to
    /// ordinary web URLs. This keeps malformed or privileged schemes out of
    /// the command palette even when a persisted file was hand-edited.
    public var isValidWebURL: Bool {
        guard !title.isEmpty,
              !url.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              let parsed = URL(string: url),
              let scheme = parsed.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = parsed.host,
              !host.isEmpty,
              parsed.user == nil,
              parsed.password == nil else {
            return false
        }
        return true
    }
}
