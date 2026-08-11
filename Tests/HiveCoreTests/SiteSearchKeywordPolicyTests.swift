import Foundation
import Testing
@testable import HiveCore

@Suite("SiteSearchKeywordPolicy")
struct SiteSearchKeywordPolicyTests {

    private let keywords = [
        SiteSearchKeyword(keyword: "yt", name: "YouTube", template: "https://www.youtube.com/results?search_query={query}"),
        SiteSearchKeyword(keyword: "w", name: "Wikipedia", template: "https://en.wikipedia.org/w/index.php?search={query}")
    ]

    // MARK: - Keyword normalization

    @Test func normalizedKeywordTrimsAndLowercases() {
        #expect(SiteSearchKeywordPolicy.normalizedKeyword("  YT ") == "yt")
        #expect(SiteSearchKeywordPolicy.normalizedKeyword("Wiki") == "wiki")
    }

    @Test func normalizedKeywordRejectsEmptyAndSpaces() {
        #expect(SiteSearchKeywordPolicy.normalizedKeyword("") == nil)
        #expect(SiteSearchKeywordPolicy.normalizedKeyword("   ") == nil)
        #expect(SiteSearchKeywordPolicy.normalizedKeyword("my keyword") == nil)
    }

    // MARK: - Keyword query parsing

    @Test func keywordQueryMatchesKnownKeyword() {
        let result = SiteSearchKeywordPolicy.keywordQuery(from: "yt kittens", keywords: keywords)
        #expect(result?.keyword.keyword == "yt")
        #expect(result?.query == "kittens")
    }

    @Test func keywordQueryIsCaseInsensitiveOnKeyword() {
        let result = SiteSearchKeywordPolicy.keywordQuery(from: "YT kittens", keywords: keywords)
        #expect(result?.keyword.keyword == "yt")
    }

    @Test func bareKeywordIsNotAQuery() {
        #expect(SiteSearchKeywordPolicy.keywordQuery(from: "yt", keywords: keywords) == nil)
    }

    @Test func unknownKeywordFallsThrough() {
        #expect(SiteSearchKeywordPolicy.keywordQuery(from: "zzz kittens", keywords: keywords) == nil)
    }

    @Test func emptyQueryAfterKeywordFallsThrough() {
        #expect(SiteSearchKeywordPolicy.keywordQuery(from: "yt  ", keywords: keywords) == nil)
    }

    // MARK: - URL building

    @Test func searchURLPercentEncodesQuery() {
        let youtube = keywords[0]
        let url = SiteSearchKeywordPolicy.searchURL(for: "a b&c", keyword: youtube)
        // Space → %20, & → %26 — identical to the shared SearchEngine builder.
        #expect(url?.absoluteString == "https://www.youtube.com/results?search_query=a%20b%26c")
    }

    @Test func searchURLForSingleWord() {
        let wikipedia = keywords[1]
        let url = SiteSearchKeywordPolicy.searchURL(for: "swift", keyword: wikipedia)
        #expect(url?.absoluteString == "https://en.wikipedia.org/w/index.php?search=swift")
    }

    // MARK: - Template validation

    @Test func validTemplateRequiresPlaceholderAndHTTPS() {
        #expect(SiteSearchKeywordPolicy.isValidTemplate("https://example.com/search?q={query}"))
        #expect(!SiteSearchKeywordPolicy.isValidTemplate("https://example.com/search?q=static"))
        #expect(!SiteSearchKeywordPolicy.isValidTemplate("javascript:alert({query})"))
        #expect(!SiteSearchKeywordPolicy.isValidTemplate("example.com/{query}"))
    }
}
