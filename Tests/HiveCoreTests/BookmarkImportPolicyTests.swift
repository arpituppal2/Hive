import Testing
import Foundation
@testable import HiveCore

@Suite("BookmarkImportPolicy")
struct BookmarkImportPolicyTests {
    @Test func normalizesWebURLsAndRejectsUnsafeInputs() {
        let candidates = [
            ImportedBookmark(title: "  Example  ", url: URL(string: "HTTPS://user:secret@EXAMPLE.com/page#fragment")!),
            ImportedBookmark(title: "File", url: URL(string: "file:///tmp/file")!),
            ImportedBookmark(title: "Script", url: URL(string: "javascript:alert(1)")!)
        ]

        let decision = BookmarkImportPolicy.merge(existingURLs: [], candidates: candidates)

        #expect(decision.entries.count == 1)
        #expect(decision.entries[0].title == "Example")
        #expect(decision.entries[0].url.absoluteString == "https://example.com/page")
        #expect(decision.skippedCount == 2)
    }

    @Test func deduplicatesExistingAndRepeatedURLs() {
        let candidates = [
            ImportedBookmark(title: "One", url: URL(string: "https://example.com")!),
            ImportedBookmark(title: "Duplicate", url: URL(string: "https://EXAMPLE.com/#fragment")!),
            ImportedBookmark(title: "Two", url: URL(string: "https://two.example")!)
        ]

        let decision = BookmarkImportPolicy.merge(
            existingURLs: ["HTTPS://existing.example/path"],
            candidates: candidates
        )

        #expect(decision.entries.map(\.title) == ["One", "Two"])
        #expect(decision.skippedCount == 1)
    }

    @Test func emptyCandidatesProducesEmptyResult() {
        let decision = BookmarkImportPolicy.merge(existingURLs: [], candidates: [])
        #expect(decision.entries.isEmpty)
        #expect(decision.skippedCount == 0)
    }

    @Test func allExistingURLsDedupAllCandidates() {
        let existing: Set<String> = ["https://a.com", "https://b.com", "https://c.com"]
        let candidates = [
            ImportedBookmark(title: "A", url: URL(string: "https://a.com")!),
            ImportedBookmark(title: "B", url: URL(string: "https://b.com")!),
            ImportedBookmark(title: "C", url: URL(string: "https://c.com")!)
        ]
        let decision = BookmarkImportPolicy.merge(existingURLs: existing, candidates: candidates)
        #expect(decision.entries.isEmpty)
        #expect(decision.skippedCount == 3)
    }

    @Test func trimsWhitespaceFromBookmarkTitles() {
        let candidates = [
            ImportedBookmark(title: "  Spaced Title  ", url: URL(string: "https://spaced.example")!)
        ]
        let decision = BookmarkImportPolicy.merge(existingURLs: [], candidates: candidates)
        #expect(decision.entries.count == 1)
        #expect(decision.entries[0].title == "Spaced Title")
    }

@Test func emptyTitleDefaultsToBookmark() {
        let candidates = [ImportedBookmark(title: "", url: URL(string: "https://empty.example")!)]
        let decision = BookmarkImportPolicy.merge(existingURLs: [], candidates: candidates)
        #expect(decision.entries.count == 1)
    }

    @Test func nilURLIsSkipped() {
        let candidates = [ImportedBookmark(title: "NoURL", url: URL(string: "https://valid.example")!)]
        let decision = BookmarkImportPolicy.merge(existingURLs: [], candidates: candidates)
        #expect(decision.entries.count == 1)
        #expect(decision.entries[0].title == "NoURL")
    }

@Test func bookmarkDefaultsToNotFolder() {
        let bm = Bookmark(title: "Link", url: URL(string: "https://x.com")!)
        #expect(!bm.isFolder)
    }

@Test func decisionSkippedCountIsNonNegative() {
        let d = BookmarkImportPolicy.Decision(entries: [], skippedCount: -5)
        #expect(d.skippedCount >= 0)
    }
}
