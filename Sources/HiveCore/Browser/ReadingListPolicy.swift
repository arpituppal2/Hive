import Foundation

// MARK: - ReadingListPolicy
//
// Pure rules for the Safari-style Reading List. The model (ReadingListEntry)
// and its cap live in HiveCore already; this policy owns the behaviors that
// make the list feel right:
//
// - Article URLs are normalized (fragment stripped, trailing slash folded) so
//   re-saving the same article — possibly via a deep link or an anchor — never
//   duplicates a row.
// - Re-saving an already-listed article updates its title/favicon in place and
//   moves it to the FRONT (newest-first ordering), exactly like Safari: the
//   article you just saved is the one you want on top.
// - The list is capped (`hiveReadingListCap`), dropping the oldest entries so
//   the session file stays lean.
// - Notes are trimmed and length-capped so the panel's note editor cannot
//   balloon the session file.

public enum ReadingListPolicy {

    /// The longest note a reading-list entry may carry (keeps prefs lean while
    /// leaving room for a real reader note).
    public static let maxNoteLength = 280

    /// Normalizes an article URL for identity: lowercase scheme/host, no
    /// fragment (an anchor deep-link is the same article), no trailing slash
    /// on the path (a bare path is the same article). Returns nil for
    /// non-http(s) URLs — only real pages belong on the reading list.
    public static func normalizedArticleURL(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = scheme
        components?.host = url.host?.lowercased()
        components?.fragment = nil
        components?.query = nil
        guard var result = components?.url else { return url }
        // Fold a bare trailing slash: https://example.com/ == https://example.com
        if result.path == "/" {
            var noSlash = result.absoluteString
            while noSlash.hasSuffix("/") { noSlash.removeLast() }
            result = URL(string: noSlash) ?? result
        }
        return result
    }

    /// Merges a saved article into the list. A new article is prepended; an
    /// already-listed article (same normalized URL) is updated in place —
    /// title/favicon refreshed, `lastViewedAt`/`isRead` untouched — and moved
    /// to the front with its original identity and `savedAt` preserved. The
    /// result is always capped.
    public static func upsert(
        existing: [ReadingListEntry],
        url: URL,
        title: String,
        faviconURL: URL? = nil,
        cap: Int = [ReadingListEntry].hiveReadingListCap
    ) -> [ReadingListEntry] {
        guard let normalized = normalizedArticleURL(url) else { return existing }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = existing.firstIndex(where: { entry in
            normalizedArticleURL(entry.url) == normalized
        }) {
            let old = existing[index]
            var updated = existing
            updated.remove(at: index)
            updated.insert(
                ReadingListEntry(
                    id: old.id,
                    // Store the LATEST actual URL (query/fragment intact) so
                    // paginated or param-based articles open the right page;
                    // the normalized form is used only for identity.
                    url: url,
                    title: trimmedTitle.isEmpty ? old.title : trimmedTitle,
                    faviconURL: faviconURL ?? old.faviconURL,
                    note: old.note,
                    savedAt: old.savedAt,
                    lastViewedAt: old.lastViewedAt,
                    isRead: old.isRead,
                    isOfflineAvailable: old.isOfflineAvailable
                ),
                at: 0
            )
            return applyCap(updated, cap: cap)
        }
        var updated = existing
        updated.insert(
            ReadingListEntry(
                url: url,
                title: trimmedTitle,
                faviconURL: faviconURL
            ),
            at: 0
        )
        return applyCap(updated, cap: cap)
    }

    /// Drops entries beyond the cap. The list is newest-first, so the oldest
    /// (tail) entries go first.
    public static func applyCap(
        _ list: [ReadingListEntry],
        cap: Int = [ReadingListEntry].hiveReadingListCap
    ) -> [ReadingListEntry] {
        guard cap > 0, list.count > cap else { return list }
        return Array(list.prefix(cap))
    }

    /// Validates a reader note: whitespace-trimmed and length-capped.
    public static func validatedNote(_ note: String) -> String {
        String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNoteLength))
    }
}
