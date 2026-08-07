import Foundation

/// Normalizes and merges history imported from another browser.
///
/// The browser shell owns the durable `HistoryItem` array. This policy keeps
/// source filtering, URL sanitization, duplicate handling, chronological order,
/// and the cap deterministic and testable without a CEF-backed state.
public enum HistoryImportPolicy {
    public struct Decision: Sendable, Equatable {
        public let entries: [ImportedHistoryEntry]
        public let skippedCount: Int

        public init(entries: [ImportedHistoryEntry], skippedCount: Int) {
            self.entries = entries
            self.skippedCount = max(0, skippedCount)
        }
    }

    /// Returns sanitized, deduplicated entries in oldest-to-newest order.
    /// Existing URLs and duplicate candidates are counted as skipped. Only
    /// HTTP(S) history is imported; browser-internal and file URLs are not
    /// meaningful in Hive's durable web history surface.
    public static func merge(
        existingURLs: Set<String>,
        candidates: [ImportedHistoryEntry],
        limit: Int = 1_000
    ) -> Decision {
        guard limit > 0 else {
            return Decision(entries: [], skippedCount: candidates.count)
        }

        var skipped = 0
        var acceptedByURL: [String: ImportedHistoryEntry] = [:]

        for candidate in candidates {
            guard let sanitized = sanitize(candidate),
                  let key = canonicalKey(sanitized.url) else {
                skipped += 1
                continue
            }

            if existingURLs.contains(where: { canonicalKey($0) == key }) {
                skipped += 1
                continue
            }

            if let previous = acceptedByURL[key] {
                // Keep the newest visit for a URL. A source such as Safari can
                // expose one row per visit rather than one row per URL.
                if sanitized.visitDate > previous.visitDate {
                    acceptedByURL[key] = sanitized
                }
                skipped += 1
            } else {
                acceptedByURL[key] = sanitized
            }
        }

        let ordered = acceptedByURL.values.sorted {
            if $0.visitDate != $1.visitDate { return $0.visitDate < $1.visitDate }
            return $0.url.absoluteString < $1.url.absoluteString
        }
        guard ordered.count > limit else {
            return Decision(entries: ordered, skippedCount: skipped)
        }

        // Keep the newest entries while preserving chronological order for the
        // session store's append-and-reverse history presentation.
        let retained = Array(ordered.suffix(limit))
        return Decision(entries: retained, skippedCount: skipped + (ordered.count - retained.count))
    }

    private static func sanitize(_ candidate: ImportedHistoryEntry) -> ImportedHistoryEntry? {
        guard let url = BrowserURLImportNormalizer.normalizedURL(candidate.url),
              candidate.visitDate.timeIntervalSince1970.isFinite else {
            return nil
        }

        // History URLs are navigation metadata, not credential storage. The
        // shared normalizer strips userinfo and fragments before persistence.

        let title = candidate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = String((title.isEmpty ? (url.host ?? "Untitled") : title).prefix(512))
        return ImportedHistoryEntry(
            url: url,
            title: safeTitle,
            visitDate: candidate.visitDate,
            visitCount: max(0, candidate.visitCount)
        )
    }

    private static func canonicalKey(_ url: URL) -> String? {
        BrowserURLImportNormalizer.canonicalKey(url)
    }

    private static func canonicalKey(_ urlString: String) -> String? {
        BrowserURLImportNormalizer.canonicalKey(urlString)
    }
}
