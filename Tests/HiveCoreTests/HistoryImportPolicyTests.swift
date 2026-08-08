import Testing
import Foundation
@testable import HiveCore

@Suite("HistoryImportPolicy")
struct HistoryImportPolicyTests {
    private let older = Date(timeIntervalSince1970: 100)
    private let newer = Date(timeIntervalSince1970: 200)

    @Test func importsOnlyWebHistoryAndSanitizesMetadata() {
        let candidates = [
            ImportedHistoryEntry(
                url: URL(string: "https://user:secret@example.com/path#private")!,
                title: "  Example  ",
                visitDate: newer,
                visitCount: -3
            ),
            ImportedHistoryEntry(url: URL(string: "file:///Users/me/secret")!, title: "File", visitDate: newer),
            ImportedHistoryEntry(url: URL(string: "hive://start")!, title: "Hive", visitDate: newer)
        ]

        let decision = HistoryImportPolicy.merge(existingURLs: [], candidates: candidates)

        #expect(decision.entries.count == 1)
        #expect(decision.entries[0].url.absoluteString == "https://example.com/path")
        #expect(decision.entries[0].title == "Example")
        #expect(decision.entries[0].visitCount == 0)
        #expect(decision.skippedCount == 2)
    }

    @Test func keepsNewestDuplicateAndSkipsExistingURLs() {
        let candidates = [
            ImportedHistoryEntry(url: URL(string: "https://example.com/page")!, title: "Old", visitDate: older),
            ImportedHistoryEntry(url: URL(string: "https://EXAMPLE.com/page#fragment")!, title: "New", visitDate: newer),
            ImportedHistoryEntry(url: URL(string: "https://existing.example")!, title: "Existing", visitDate: newer)
        ]

        let decision = HistoryImportPolicy.merge(
            existingURLs: ["https://existing.example"],
            candidates: candidates
        )

        #expect(decision.entries.count == 1)
        #expect(decision.entries[0].title == "New")
        #expect(decision.entries[0].url.absoluteString == "https://example.com/page")
        #expect(decision.skippedCount == 2)
    }

    @Test func returnsChronologicalOrderAndRetainsNewestLimit() {
        let candidates = (0..<4).map { index in
            ImportedHistoryEntry(
                url: URL(string: "https://example.com/\(index)")!,
                title: "Page \(index)",
                visitDate: Date(timeIntervalSince1970: Double(index))
            )
        }

        let decision = HistoryImportPolicy.merge(existingURLs: [], candidates: candidates, limit: 2)

        #expect(decision.entries.map(\.title) == ["Page 2", "Page 3"])
        #expect(decision.skippedCount == 2)
    }

    @Test func invalidLimitSkipsAllCandidates() {
        let candidate = ImportedHistoryEntry(url: URL(string: "https://example.com")!, title: "Example", visitDate: newer)
        let decision = HistoryImportPolicy.merge(existingURLs: [], candidates: [candidate], limit: 0)

        #expect(decision.entries.isEmpty)
        #expect(decision.skippedCount == 1)
    }

@Test func emptyCandidatesProducesEmptyDecision() {
        let decision = HistoryImportPolicy.merge(existingURLs: [], candidates: [])
        #expect(decision.entries.isEmpty)
        #expect(decision.skippedCount == 0)
    }

    @Test func limitExceedingCountReturnsAll() {
        let candidates = [
            ImportedHistoryEntry(url: URL(string: "https://a.example")!, title: "A", visitDate: older),
            ImportedHistoryEntry(url: URL(string: "https://b.example")!, title: "B", visitDate: newer)
        ]
        let decision = HistoryImportPolicy.merge(existingURLs: [], candidates: candidates, limit: 100)
        #expect(decision.entries.count == 2)
        #expect(decision.skippedCount == 0)
    }
}
