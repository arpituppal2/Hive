import Foundation

// MARK: - BrowserTab
//
// The data model for a single browser tab. Pure Codable/Sendable/Identifiable — owns NO
// WKWebView (the view lives in the Hive target's WebViewContainer). This keeps models
// testable in HiveCore and lets tabs survive app restart / hibernation by serializing their
// state. Per SPEC §1.3 and the Honeycomb design, navigated URLs are also written as Honeycomb
// `source`/`note` nodes with provenance "browser-history" — but that is the store's job, not
// the model's.
//
// Lifecycle (matches CellManager's: spawned → running → completed|killed, adapted for tabs):
//   new (loading) → active (loaded) → background → hibernated → restored | closed

public struct BrowserTab: Sendable, Codable, Identifiable, Equatable, Hashable {

    /// Stable UUID. Survives restart; the WKWebView is reattached on restore.
    public let id: String

    /// Current page URL (nil on a fresh new-tab / start page).
    public var url: URL?

    /// The pending URL we're navigating to (transient; set during load, cleared on success).
    public var pendingURL: URL?

    /// Page title (empty until the page sets it OR falls back to host).
    public var title: String

    /// Display title for the tab pill: the page title, or the host, or "New Tab".
    public var displayTitle: String { title.isEmpty ? (url?.host ?? "New Tab") : title }

    /// Favicon URL (favicon is fetched by the view layer; model holds the resolved URL).
    public var faviconURL: URL?

    /// True while the page is loading. Drives the loading bar (SPEC §8.1) + spinner.
    public var isLoading: Bool

    /// 0...1 load progress (drives the 2pt bottom progress bar on the pill).
    public var loadProgress: Double

    /// Navigation back-stack depth (can the user go back?).
    public var canGoBack: Bool

    /// Navigation forward-stack depth (can the user go forward?).
    public var canGoForward: Bool

    /// True if this tab is currently selected. Exactly one tab per window is active.
    public var isActive: Bool

    /// Pinned tabs are favicon-only (SPEC §8.1: 48pt wide, no title, no close unless hovered).
    public var isPinned: Bool

    /// Private-browsing tab — non-persistent store, no history capture, no Honeycomb writes.
    /// (SPEC §8 context menu "Mute" analog; private mode is a user opt-in, AGENTS.md §9.2.)
    public var isPrivate: Bool

    /// Whether Swarm may inspect this tab's page text. This is per-tab rather than
    /// per-origin so the user can make a narrow decision without broadening it to
    /// every page on a site. Defaults on for backward-compatible session decoding.
    public var isAIContextAllowed: Bool

    /// Muted audio indicator — shows speaker icon on the pill.
    public var isMuted: Bool

    /// The Space (workspace) this tab belongs to. `nil` = the default space. Per Arc/Zen,
    /// vertical mode groups tabs by space; horizontal mode ignores spaces.
    public var spaceID: String?

    /// Optional parent tab id for tree-style vertical tabs (slice 7). `nil` means a root tab.
    public var parentTabID: String?

    /// Promise badge tag (slice 8) — a lightweight metadata label like "read later".
    /// `nil` means no promise badge is shown on the tab.
    public var promise: String?

    /// Promise badge color, stored as a HiveColorToken raw value (e.g. "accent", "mint").
    /// Used only when `promise` is non-nil. Defaults to "accent".
    public var promiseColor: String?

    /// Hibernated tabs have their WKWebView dropped (SPEC §28 + Appendix D). State is
    /// serialized so reload is fast; memory freed after 10min background.
    public var isHibernated: Bool

    /// Reader mode strips the page to its article text (SPEC §25).
    public var isReaderMode: Bool

    /// If non-nil, the tab is displaying a JSON preview instead of a web page.
    /// Set when the navigation response has a JSON content type. The view layer
    /// renders `JsonTreeView` instead of `WebViewContainer` when this is set.
    public var jsonPreviewData: Data?

    /// Whether the tab is currently playing audio.
    public var isPlayingAudio: Bool

    /// Count of trackers/ads/resources blocked by the content blocker on this page.
    /// Reset on navigation; incremented by ContentBlockerController as rules fire.
    public var blockedCount: Int

    /// Current zoom level (1.0 = 100%). Persisted per-tab.
    public var zoomLevel: Double

    /// Creation timestamp (ISO8601 with fractional seconds, like Honeycomb's convention).
    public let createdAt: Date

    /// Last-visited timestamp (for restoring most-recent tab ordering / history).
    public var lastVisitedAt: Date

    // MARK: Init

    public init(id: String = UUID().uuidString,
                url: URL? = nil,
                pendingURL: URL? = nil,
                title: String = "",
                faviconURL: URL? = nil,
                isLoading: Bool = false,
                loadProgress: Double = 0,
                canGoBack: Bool = false,
                canGoForward: Bool = false,
                isActive: Bool = false,
                isPinned: Bool = false,
                isPrivate: Bool = false,
                isAIContextAllowed: Bool = true,
                isMuted: Bool = false,
                jsonPreviewData: Data? = nil,
                isPlayingAudio: Bool = false,
                blockedCount: Int = 0,
                spaceID: String? = nil,
                parentTabID: String? = nil,
                promise: String? = nil,
                promiseColor: String? = nil,
                isHibernated: Bool = false,
                isReaderMode: Bool = false,
                zoomLevel: Double = 1.0,
                createdAt: Date = Date(),
                lastVisitedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.pendingURL = pendingURL
        self.title = title
        self.faviconURL = faviconURL
        self.isLoading = isLoading
        self.loadProgress = loadProgress
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isActive = isActive
        self.isPinned = isPinned
        self.isPrivate = isPrivate
        self.isAIContextAllowed = isAIContextAllowed
        self.isMuted = isMuted
        self.jsonPreviewData = jsonPreviewData
        self.isPlayingAudio = isPlayingAudio
        self.blockedCount = blockedCount
        self.spaceID = spaceID
        self.parentTabID = parentTabID
        self.promise = promise
        self.promiseColor = promiseColor
        self.isHibernated = isHibernated
        self.isReaderMode = isReaderMode
        self.zoomLevel = zoomLevel
        self.createdAt = createdAt
        self.lastVisitedAt = lastVisitedAt
    }

    // MARK: Factory

    /// A fresh new-tab (shows the start page until the user navigates).
    public static func newTab(isPrivate: Bool = false, spaceID: String? = nil) -> BrowserTab {
        BrowserTab(url: nil, isLoading: false, isActive: true, isPrivate: isPrivate, spaceID: spaceID)
    }

    /// True if `ancestorID` appears anywhere in this tab's parent chain.
    public func hasAncestor(_ ancestorID: String, in tabs: [BrowserTab]) -> Bool {
        var current = parentTabID
        while let pid = current {
            if pid == ancestorID { return true }
            current = tabs.first { $0.id == pid }?.parentTabID
        }
        return false
    }

    // MARK: Forward-compatible Codable
    //
    // BrowserTab is encoded in the durable session file; new fields must have sensible
    // defaults so older session.json files still decode after app updates.

    private enum CodingKeys: String, CodingKey {
        case id, url, pendingURL, title, faviconURL, isLoading, loadProgress
        case canGoBack, canGoForward, isActive, isPinned, isPrivate, isAIContextAllowed, isMuted
        case spaceID, parentTabID, promise, promiseColor
        case isHibernated, isReaderMode, jsonPreviewData, isPlayingAudio, blockedCount, zoomLevel, createdAt, lastVisitedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        pendingURL = try c.decodeIfPresent(URL.self, forKey: .pendingURL)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        faviconURL = try c.decodeIfPresent(URL.self, forKey: .faviconURL)
        isLoading = try c.decodeIfPresent(Bool.self, forKey: .isLoading) ?? false
        loadProgress = try c.decodeIfPresent(Double.self, forKey: .loadProgress) ?? 0
        canGoBack = try c.decodeIfPresent(Bool.self, forKey: .canGoBack) ?? false
        canGoForward = try c.decodeIfPresent(Bool.self, forKey: .canGoForward) ?? false
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        isAIContextAllowed = try c.decodeIfPresent(Bool.self, forKey: .isAIContextAllowed) ?? true
        isMuted = try c.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        jsonPreviewData = try c.decodeIfPresent(Data.self, forKey: .jsonPreviewData)
        isPlayingAudio = try c.decodeIfPresent(Bool.self, forKey: .isPlayingAudio) ?? false
        blockedCount = try c.decodeIfPresent(Int.self, forKey: .blockedCount) ?? 0
        spaceID = try c.decodeIfPresent(String.self, forKey: .spaceID)
        parentTabID = try c.decodeIfPresent(String.self, forKey: .parentTabID)
        promise = try c.decodeIfPresent(String.self, forKey: .promise)
        promiseColor = try c.decodeIfPresent(String.self, forKey: .promiseColor)
        isHibernated = try c.decodeIfPresent(Bool.self, forKey: .isHibernated) ?? false
        isReaderMode = try c.decodeIfPresent(Bool.self, forKey: .isReaderMode) ?? false
        zoomLevel = try c.decodeIfPresent(Double.self, forKey: .zoomLevel) ?? 1.0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastVisitedAt = try c.decodeIfPresent(Date.self, forKey: .lastVisitedAt) ?? Date()
    }
}
