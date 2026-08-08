import Foundation

// MARK: - BrowsingHistoryEntry
//
// A single record in the user's browsing history. Captured on every page navigation
// (main frame only). Persisted in ChromeUserPrefs with a 1000-entry cap. Used by the
// History panel (⌘Y) and omnibar autocomplete suggestions.
//
// Deduplication: entries with the same URL update the visit date rather than creating
// duplicates (same pattern as the recently-closed stack).

public struct BrowsingHistoryEntry: Sendable, Codable, Identifiable, Equatable {
    public let id: String
    public let url: URL
    public var title: String
    public var visitDate: Date
    public var faviconURL: URL?

    public init(id: String = UUID().uuidString,
                url: URL,
                title: String = "",
                visitDate: Date = Date(),
                faviconURL: URL? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.visitDate = visitDate
        self.faviconURL = faviconURL
    }

    /// The display host (without "www." prefix).
    public var host: String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }
}

public extension Array where Element == BrowsingHistoryEntry {
    /// Maximum history entries retained. Oldest entries drop on overflow.
    static let hiveHistoryCap = 1000
}
