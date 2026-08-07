import Foundation

// MARK: - ArchivedTab
//
// A lightweight record of an auto-archived tab (§7 of hive-browser-base-design.md).
// Unlike BrowserTab (live, mutable, carries WKWebView state), an ArchivedTab is a
// frozen snapshot — just enough metadata to show in the Tab Overview's "Recently
// Archived" tier and to reopen the tab (either from interactionState if still in the
// broker, or by re-navigating to the URL).
//
// The id matches the original BrowserTab.id so restoring can check the broker for a
// still-cached sprite. Honoured-edge nodes are created in Honeycomb on archive
// (slice 6 binds the AutoArchiveTick → HoneycombStore write path).

public struct ArchivedTab: Sendable, Codable, Identifiable, Equatable, Hashable {
    /// Same id as the original BrowserTab — so restore can look up the broker sprite.
    public let id: String
    /// Page title at the time of archive.
    public var title: String
    /// Last known URL (restore target if the broker sprite is stale or absent).
    public var url: URL?
    /// Favicon URL, if captured.
    public var faviconURL: URL?
    /// The space the tab was in when archived (nil if the space was deleted).
    public var sourceSpaceID: String?
    /// The group the tab was in when archived (nil if ungrouped).
    public var sourceGroupID: String?
    /// When the tab was auto-archived.
    public let archivedAt: Date
    /// When the tab was last visited before archive (used for sort order).
    public var lastVisitedAt: Date
    /// Private tabs are never archived by policy and are filtered again at the
    /// session boundary. The marker makes that rule explicit for forward-
    /// compatible records and prevents hand-built records from becoming a
    /// durable privacy bypass.
    public var isPrivate: Bool

    public init(id: String = UUID().uuidString,
                title: String = "",
                url: URL? = nil,
                faviconURL: URL? = nil,
                sourceSpaceID: String? = nil,
                sourceGroupID: String? = nil,
                archivedAt: Date = Date(),
                lastVisitedAt: Date = Date(),
                isPrivate: Bool = false) {
        self.id = id
        self.title = title
        self.url = url
        self.faviconURL = faviconURL
        self.sourceSpaceID = sourceSpaceID
        self.sourceGroupID = sourceGroupID
        self.archivedAt = archivedAt
        self.lastVisitedAt = lastVisitedAt
        self.isPrivate = isPrivate
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, url, faviconURL, sourceSpaceID, sourceGroupID, archivedAt, lastVisitedAt, isPrivate
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        faviconURL = try c.decodeIfPresent(URL.self, forKey: .faviconURL)
        sourceSpaceID = try c.decodeIfPresent(String.self, forKey: .sourceSpaceID)
        sourceGroupID = try c.decodeIfPresent(String.self, forKey: .sourceGroupID)
        archivedAt = try c.decodeIfPresent(Date.self, forKey: .archivedAt) ?? Date()
        lastVisitedAt = try c.decodeIfPresent(Date.self, forKey: .lastVisitedAt) ?? Date()
        isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
    }
}