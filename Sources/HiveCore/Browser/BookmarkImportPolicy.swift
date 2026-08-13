import Foundation

/// Normalizes and merges bookmarks imported from another browser.
///
/// External profile databases are untrusted input. This policy admits only
/// navigable HTTP(S) URLs, removes credentials/fragments, bounds titles, and
/// deduplicates against both existing and earlier imported bookmarks.
public enum BookmarkImportPolicy {
    public struct Decision: Sendable, Equatable {
        public let entries: [ImportedBookmark]
        public let skippedCount: Int

        public init(entries: [ImportedBookmark], skippedCount: Int) {
            self.entries = entries
            self.skippedCount = max(0, skippedCount)
        }
    }

    public static func merge(
        existingURLs: Set<String>,
        candidates: [ImportedBookmark]
    ) -> Decision {
        let existingKeys: Set<String> = Set(existingURLs.compactMap { url in
            guard let parsed = URL(string: url) else { return nil }
            return canonicalKey(parsed)
        })
        var seen = existingKeys
        var accepted: [ImportedBookmark] = []
        var skipped = 0

        for candidate in candidates {
            guard let normalized = normalize(candidate),
                  let key = canonicalKey(normalized.url),
                  !seen.contains(key) else {
                skipped += 1
                continue
            }
            seen.insert(key)
            accepted.append(normalized)
        }
        return Decision(entries: accepted, skippedCount: skipped)
    }

    private static func normalize(_ candidate: ImportedBookmark) -> ImportedBookmark? {
        guard let url = BrowserURLImportNormalizer.normalizedURL(candidate.url) else { return nil }
        let trimmed = candidate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = String((trimmed.isEmpty ? (url.host ?? "Untitled") : trimmed).prefix(512))
        return ImportedBookmark(title: title, url: url)
    }

    private static func canonicalKey(_ url: URL) -> String? {
        BrowserURLImportNormalizer.canonicalKey(url)
    }
}
