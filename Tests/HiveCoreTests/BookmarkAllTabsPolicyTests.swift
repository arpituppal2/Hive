import Foundation
import Testing
@testable import HiveCore

@Suite("BookmarkAllTabsPolicy")
struct BookmarkAllTabsPolicyTests {

    // MARK: - Folder naming

    @Test func folderNameUsesChromeStyleDate() {
        // Fixed instant — the policy is timezone-aware but deterministic.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        let name = BookmarkAllTabsPolicy.folderName(on: date, timeZone: TimeZone(identifier: "UTC")!)
        #expect(name == "Aug 10, 2026")
    }

    @Test func folderNameIgnoresTimeOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 2))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 23))!
        let utc = TimeZone(identifier: "UTC")!
        #expect(BookmarkAllTabsPolicy.folderName(on: morning, timeZone: utc)
                == BookmarkAllTabsPolicy.folderName(on: evening, timeZone: utc))
        #expect(BookmarkAllTabsPolicy.folderName(on: morning, timeZone: utc) == "Jan 5, 2026")
    }

    @Test func folderNameIsLocaleIndependent() {
        // en_US_POSIX guarantees the format stays stable on any machine.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!
        let name = BookmarkAllTabsPolicy.folderName(on: date, timeZone: TimeZone(identifier: "UTC")!)
        #expect(name == "Dec 31, 2026")
    }

    // MARK: - Eligibility

    @Test func httpAndHTTPSAreEligible() {
        #expect(BookmarkAllTabsPolicy.isEligibleURL("https://example.com"))
        #expect(BookmarkAllTabsPolicy.isEligibleURL("http://example.com/page?q=1"))
    }

    @Test func internalAndBlankURLsAreNotEligible() {
        #expect(!BookmarkAllTabsPolicy.isEligibleURL("about:blank"))
        #expect(!BookmarkAllTabsPolicy.isEligibleURL("hive://start"))
        #expect(!BookmarkAllTabsPolicy.isEligibleURL("data:text/html,hello"))
        #expect(!BookmarkAllTabsPolicy.isEligibleURL("file:///tmp/page.html"))
    }

    @Test func emptyAndMalformedStringsAreNotEligible() {
        #expect(!BookmarkAllTabsPolicy.isEligibleURL(""))
        #expect(!BookmarkAllTabsPolicy.isEligibleURL("not a url"))
        #expect(!BookmarkAllTabsPolicy.isEligibleURL("javascript:alert(1)"))
    }

    // MARK: - Deduplication

    @Test func exactDuplicatesCollapseToFirstOccurrence() {
        let entries = [
            BookmarkAllTabsEntry(title: "A", urlString: "https://example.com/a"),
            BookmarkAllTabsEntry(title: "B", urlString: "https://example.com/b"),
            BookmarkAllTabsEntry(title: "A again", urlString: "https://example.com/a")
        ]
        let result = BookmarkAllTabsPolicy.deduplicated(entries)
        #expect(result.count == 2)
        #expect(result[0].title == "A")
        #expect(result[1].title == "B")
    }

    @Test func caseInsensitiveURLsAreTreatedAsDuplicates() {
        let entries = [
            BookmarkAllTabsEntry(title: "First", urlString: "https://EXAMPLE.com/Path"),
            BookmarkAllTabsEntry(title: "Second", urlString: "https://example.com/path")
        ]
        let result = BookmarkAllTabsPolicy.deduplicated(entries)
        #expect(result.count == 1)
        #expect(result[0].title == "First")
    }

    @Test func orderIsPreservedThroughDeduplication() {
        let entries = [
            BookmarkAllTabsEntry(title: "X", urlString: "https://x.com"),
            BookmarkAllTabsEntry(title: "Y", urlString: "https://y.com"),
            BookmarkAllTabsEntry(title: "X dup", urlString: "https://x.com"),
            BookmarkAllTabsEntry(title: "Z", urlString: "https://z.com")
        ]
        let result = BookmarkAllTabsPolicy.deduplicated(entries)
        #expect(result.map(\.title) == ["X", "Y", "Z"])
    }

    @Test func emptyBatchStaysEmpty() {
        #expect(BookmarkAllTabsPolicy.deduplicated([]).isEmpty)
    }
}
