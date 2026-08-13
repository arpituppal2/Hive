import Testing
import Foundation
@testable import HiveCore

@Suite("BrowserImportMergePolicy")
struct BrowserImportMergePolicyTests {
    private func existing(_ url: String, _ timestamp: TimeInterval) -> BrowserImportMergePolicy.ExistingHistoryEntry {
        BrowserImportMergePolicy.ExistingHistoryEntry(
            url: URL(string: url)!,
            visitedAt: Date(timeIntervalSince1970: timestamp)
        )
    }

    private func imported(_ url: String, _ timestamp: TimeInterval, title: String = "Page") -> ImportedHistoryEntry {
        ImportedHistoryEntry(
            url: URL(string: url)!,
            title: title,
            visitDate: Date(timeIntervalSince1970: timestamp)
        )
    }

    @Test func deduplicatesExistingURLsUsingSharedCanonicalization() {
        let decision = BrowserImportMergePolicy.mergeHistory(
            existing: [existing("HTTPS://example.com:443/#old", 10)],
            candidates: [
                imported("https://EXAMPLE.com", 20, title: "Duplicate"),
                imported("https://new.example/path", 30, title: "New")
            ],
            limit: 10
        )

        #expect(decision.retainedImported.map(\.title) == ["New"])
        #expect(decision.skippedCount == 1)
    }

    @Test func capReportsOnlyImportedRowsThatRemainRetained() {
        let decision = BrowserImportMergePolicy.mergeHistory(
            existing: [
                existing("https://old.example/1", 1),
                existing("https://old.example/2", 2),
                existing("https://old.example/3", 3)
            ],
            candidates: [
                imported("https://imported.example/old", 0, title: "Evicted import"),
                imported("https://imported.example/new", 4, title: "Retained import")
            ],
            limit: 3
        )

        #expect(decision.retainedImported.map(\.title) == ["Retained import"])
        #expect(decision.skippedCount == 1)
    }

    @Test func preservesOldestToNewestOrderAfterGlobalCap() {
        let decision = BrowserImportMergePolicy.mergeHistory(
            existing: [existing("https://existing.example", 20)],
            candidates: [
                imported("https://imported.example/new", 30, title: "New"),
                imported("https://imported.example/old", 10, title: "Old")
            ],
            limit: 10
        )

        #expect(decision.retainedImported.map(\.title) == ["Old", "New"])
    }

    @Test func invalidLimitSkipsWithoutRetaining() {
        let decision = BrowserImportMergePolicy.mergeHistory(
            existing: [],
            candidates: [imported("https://example.com", 1)],
            limit: 0
        )

        #expect(decision.retainedImported.isEmpty)
        #expect(decision.skippedCount == 1)
    }
}
