import Foundation
import Testing
@testable import HiveCore

@Suite("ReadingListPolicy")
struct ReadingListPolicyTests {

    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    private func entry(
        _ string: String,
        id: String = UUID().uuidString,
        savedAt: Date = Date(timeIntervalSince1970: 1_000),
        title: String = "Article"
    ) -> ReadingListEntry {
        ReadingListEntry(
            id: id,
            url: url(string),
            title: title,
            savedAt: savedAt
        )
    }

    // MARK: - Normalization

    @Test func normalizationStripsFragment() {
        let normalized = ReadingListPolicy.normalizedArticleURL(url("https://example.com/article#section-2"))
        #expect(normalized?.absoluteString == "https://example.com/article")
    }

    @Test func normalizationFoldsBareTrailingSlash() {
        let normalized = ReadingListPolicy.normalizedArticleURL(url("https://example.com/"))
        #expect(normalized?.absoluteString == "https://example.com")
    }

    @Test func normalizationLowercasesHost() {
        let normalized = ReadingListPolicy.normalizedArticleURL(url("HTTPS://Example.COM/Article"))
        #expect(normalized?.host == "example.com")
    }

    @Test func normalizationRejectsNonHTTP() {
        #expect(ReadingListPolicy.normalizedArticleURL(url("file:///etc/passwd")) == nil)
        #expect(ReadingListPolicy.normalizedArticleURL(url("hive://start")) == nil)
    }

    @Test func normalizationPreservesMeaningfulPath() {
        let normalized = ReadingListPolicy.normalizedArticleURL(url("https://example.com/a/b/c"))
        #expect(normalized?.absoluteString == "https://example.com/a/b/c")
    }

    // MARK: - Upsert

    @Test func upsertPrependsNewArticle() {
        let existing = [entry("https://example.com/old")]
        let result = ReadingListPolicy.upsert(
            existing: existing,
            url: url("https://example.com/new"),
            title: "New"
        )
        #expect(result.count == 2)
        #expect(result.first?.title == "New")
    }

    @Test func upsertSameArticleUpdatesInPlaceAndMovesToFront() {
        let id = "stable-id"
        let savedAt = Date(timeIntervalSince1970: 42)
        let existing = [
            entry("https://example.com/other"),
            entry("https://example.com/article", id: id, savedAt: savedAt, title: "Old Title")
        ]
        let result = ReadingListPolicy.upsert(
            existing: existing,
            url: url("https://example.com/article#anchor"),
            title: "New Title"
        )
        #expect(result.count == 2)
        #expect(result.first?.id == id, "Re-saving must keep the original identity")
        #expect(result.first?.savedAt == savedAt, "Re-saving must not reset savedAt")
        #expect(result.first?.title == "New Title")
        #expect(result.first?.isRead == false)
    }

    @Test func upsertSameArticleDoesNotResetReadState() {
        var readEntry = entry("https://example.com/article")
        readEntry.isRead = true
        readEntry.lastViewedAt = Date(timeIntervalSince1970: 99)
        let result = ReadingListPolicy.upsert(
            existing: [readEntry],
            url: url("https://example.com/article"),
            title: "Fresh Title"
        )
        #expect(result.first?.isRead == true)
        #expect(result.first?.lastViewedAt == readEntry.lastViewedAt)
    }

    @Test func upsertRejectsNonHTTP() {
        let existing = [entry("https://example.com/a")]
        let result = ReadingListPolicy.upsert(
            existing: existing,
            url: url("about:blank"),
            title: "Nope"
        )
        #expect(result.count == 1)
        #expect(result.first?.url.absoluteString == "https://example.com/a")
    }

    @Test func upsertPreservesEmptyTitleWithStoredTitle() {
        let existing = [entry("https://example.com/article", title: "Stored Title")]
        let result = ReadingListPolicy.upsert(
            existing: existing,
            url: url("https://example.com/article"),
            title: "   "
        )
        #expect(result.first?.title == "Stored Title", "A blank re-save title keeps the stored one")
    }

    @Test func storedURLKeepsQueryWhileIdentityIsQueryInsensitive() {
        // Identity ignores the query, but the STORED url keeps it so a
        // paginated or param-based article opens the right page.
        let result = ReadingListPolicy.upsert(
            existing: [],
            url: url("https://example.com/article?p=2"),
            title: "Page 2"
        )
        #expect(result.first?.url.absoluteString == "https://example.com/article?p=2")

        // Re-saving with a different query is the SAME article (identity), and
        // the stored url updates to the latest one without duplicating.
        let refreshed = ReadingListPolicy.upsert(
            existing: result,
            url: url("https://example.com/article?p=1"),
            title: "Page 1"
        )
        #expect(refreshed.count == 1)
        #expect(refreshed.first?.id == result.first?.id)
        #expect(refreshed.first?.url.absoluteString == "https://example.com/article?p=1")
    }

    @Test func storedURLKeepsFragment() {
        let result = ReadingListPolicy.upsert(
            existing: [],
            url: url("https://example.com/article#section-3"),
            title: "Anchored"
        )
        #expect(result.first?.url.absoluteString == "https://example.com/article#section-3")
    }

    // MARK: - Cap

    @Test func capDropsOldestEntries() {
        var list: [ReadingListEntry] = []
        for i in 0..<10 {
            list.append(entry("https://example.com/\(i)", savedAt: Date(timeIntervalSince1970: Double(i))))
        }
        // List is newest-first by construction in this test (i ascending).
        let capped = ReadingListPolicy.applyCap(list, cap: 4)
        #expect(capped.count == 4)
        #expect(capped.first?.url.absoluteString == "https://example.com/0")
    }

    @Test func upsertAppliesCap() {
        var existing: [ReadingListEntry] = []
        for i in 0..<10 {
            existing.append(entry("https://example.com/\(i)"))
        }
        let result = ReadingListPolicy.upsert(
            existing: existing,
            url: url("https://example.com/newest"),
            title: "Newest",
            cap: 5
        )
        #expect(result.count == 5)
        #expect(result.first?.title == "Newest")
    }

    // MARK: - Notes

    @Test func noteValidationTrimsAndCaps() {
        let long = String(repeating: "x", count: 500)
        let note = ReadingListPolicy.validatedNote("  \(long)  ")
        #expect(note.count == ReadingListPolicy.maxNoteLength)
        #expect(!note.hasPrefix(" "))
    }

    @Test func noteValidationAllowsEmpty() {
        #expect(ReadingListPolicy.validatedNote("   ") == "")
    }
}
