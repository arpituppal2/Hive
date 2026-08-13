import Foundation

// MARK: - BookmarkAllTabsEntry
//
// One tab's contribution to a "Bookmark All Tabs" batch. The app maps its
// richer Tab model onto this minimal shape so every batch decision — folder
// naming, eligibility, and deduplication — stays pure and deterministic in
// HiveCore.

public struct BookmarkAllTabsEntry: Sendable, Equatable {
    public let title: String
    public let urlString: String

    public init(title: String, urlString: String) {
        self.title = title
        self.urlString = urlString
    }
}

// MARK: - BookmarkAllTabsPolicy
//
// Pure rules for Chrome's ⌘⇧D "Bookmark All Tabs": a single date-named
// folder holding every eligible open tab, with duplicate URLs collapsed so
// the batch never contains two bookmarks for the same page.

public enum BookmarkAllTabsPolicy {

    /// The folder name Chrome uses: the current date (e.g. "Aug 10, 2026").
    /// Deterministic — a fixed format in the POSIX locale, so the same date
    /// always yields the same name regardless of the user's locale settings.
    public static func folderName(on date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Whether a URL string is eligible for a bookmark batch. Only real
    /// http(s) pages qualify — internal chrome pages, about:blank, data:,
    /// and empty strings are UI noise, not links worth saving.
    public static func isEligibleURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased()
        else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// Collapses duplicate URLs within a batch, preserving first-occurrence
    /// order. Comparison is case-insensitive on the absolute string — the
    /// same page reached via "EXAMPLE.com" and "example.com" is one bookmark,
    /// not two.
    public static func deduplicated(_ entries: [BookmarkAllTabsEntry]) -> [BookmarkAllTabsEntry] {
        var seen: Set<String> = []
        var result: [BookmarkAllTabsEntry] = []
        for entry in entries {
            let key = entry.urlString.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(entry)
        }
        return result
    }
}
