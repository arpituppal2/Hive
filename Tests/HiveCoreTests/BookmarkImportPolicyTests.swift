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
}
