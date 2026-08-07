import Foundation

/// Projects an imported history batch onto the browser's existing history.
///
/// `HistoryImportPolicy` decides which imported candidates are safe and unique
/// relative to existing URLs. This policy owns the second boundary: combining
/// those candidates with existing dated rows, applying the global cap, and
/// reporting only rows that actually remain retained. It is pure so the CEF
/// browser state can keep persistence and UI side effects at its boundary while
/// the cap/count contract remains testable without launching Chromium.
public enum BrowserImportMergePolicy {
    public struct ExistingHistoryEntry: Sendable, Equatable {
        public let url: URL
        public let visitedAt: Date

        public init(url: URL, visitedAt: Date) {
            self.url = url
            self.visitedAt = visitedAt
        }
    }

    public struct Decision: Sendable, Equatable {
        /// Imported entries that survive the combined history cap, in the same
        /// oldest-to-newest order used by the session projection.
        public let retainedImported: [ImportedHistoryEntry]
        /// Candidates rejected for policy/dedup reasons plus imported entries
        /// evicted immediately by the global cap.
        public let skippedCount: Int

        public init(retainedImported: [ImportedHistoryEntry], skippedCount: Int) {
            self.retainedImported = retainedImported
            self.skippedCount = max(0, skippedCount)
        }
    }

    public static func mergeHistory(
        existing: [ExistingHistoryEntry],
        candidates: [ImportedHistoryEntry],
        limit: Int = 1_000
    ) -> Decision {
        guard limit > 0 else {
            return Decision(retainedImported: [], skippedCount: candidates.count)
        }

        let importedDecision = HistoryImportPolicy.merge(
            existingURLs: Set(existing.map { $0.url.absoluteString }),
            candidates: candidates,
            limit: Int.max
        )

        struct Row {
            let url: URL
            let visitedAt: Date
            let imported: ImportedHistoryEntry?
        }

        var rows = existing.map { Row(url: $0.url, visitedAt: $0.visitedAt, imported: nil) }
        rows.append(contentsOf: importedDecision.entries.map {
            Row(url: $0.url, visitedAt: $0.visitDate, imported: $0)
        })
        rows.sort {
            if $0.visitedAt != $1.visitedAt { return $0.visitedAt < $1.visitedAt }
            return $0.url.absoluteString < $1.url.absoluteString
        }

        let evictedCount = max(0, rows.count - limit)
        if evictedCount > 0 {
            rows.removeFirst(evictedCount)
        }

        let retained = rows.compactMap(\.imported)
        return Decision(
            retainedImported: retained,
            skippedCount: importedDecision.skippedCount + (importedDecision.entries.count - retained.count)
        )
    }
}
