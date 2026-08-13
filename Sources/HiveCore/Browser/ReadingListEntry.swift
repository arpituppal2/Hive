import Foundation

// MARK: - ReadingListEntry
//
// A lightweight, saved-for-later article — Safari Reading List style. Persisted in
// ChromeUserPrefs alongside bookmarks and history. Each entry stores the article URL,
// title, and metadata so the Reading List panel can display a clean, searchable list
// of saved-for-later content.
//
// Unlike ArchivedTab (auto-archived from inactivity), a ReadingListEntry is an explicit
// user save — the user chose to keep this article. It survives indefinitely until the
// user removes it.

public struct ReadingListEntry: Sendable, Codable, Identifiable, Equatable {
    /// Stable UUID.
    public let id: String
    /// The article URL.
    public var url: URL
    /// Page title at time of save.
    public var title: String
    /// Favicon URL, if available.
    public var faviconURL: URL?
    /// Optional user note (like Safari's reader notes).
    public var note: String?
    /// When the article was saved to the reading list.
    public let savedAt: Date
    /// When the article was last viewed (for sort order).
    public var lastViewedAt: Date?
    /// Whether the article has been read (marked by user or auto-detected).
    public var isRead: Bool
    /// Whether the article content has been fetched for offline reading (future).
    public var isOfflineAvailable: Bool

    public init(id: String = UUID().uuidString,
                url: URL,
                title: String,
                faviconURL: URL? = nil,
                note: String? = nil,
                savedAt: Date = Date(),
                lastViewedAt: Date? = nil,
                isRead: Bool = false,
                isOfflineAvailable: Bool = false) {
        self.id = id
        self.url = url
        self.title = title
        self.faviconURL = faviconURL
        self.note = note
        self.savedAt = savedAt
        self.lastViewedAt = lastViewedAt
        self.isRead = isRead
        self.isOfflineAvailable = isOfflineAvailable
    }

    /// The display host (without "www." prefix).
    public var host: String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }
}
