import Foundation
import Testing
@testable import HiveCore

@Suite("BookmarkHTMLExporter")
struct BookmarkHTMLExporterTests {

    private func item(_ title: String, _ url: String, added: Int = 0) -> BookmarkHTMLExporter.Item {
        BookmarkHTMLExporter.Item(title: title, urlString: url, dateAdded: added)
    }

    @Test func emitsNetscapeDocumentHeader() {
        let html = BookmarkHTMLExporter.export(items: [])
        #expect(html.hasPrefix("<!DOCTYPE NETSCAPE-Bookmark-file-1>\n"))
        #expect(html.contains("<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">"))
        #expect(html.contains("<TITLE>Hive Bookmarks</TITLE>"))
        #expect(html.contains("<DL><p>"))
        #expect(html.hasSuffix("</DL><p>\n"))
    }

    @Test func rendersEachBookmarkWithHrefAndAddDate() {
        let html = BookmarkHTMLExporter.export(items: [
            item("Example", "https://example.com/", added: 1_700_000_000),
            item("Docs", "https://docs.example/", added: 1_700_000_001),
        ])
        #expect(html.contains("<DT><A HREF=\"https://example.com/\" ADD_DATE=\"1700000000\">Example</A>"))
        #expect(html.contains("<DT><A HREF=\"https://docs.example/\" ADD_DATE=\"1700000001\">Docs</A>"))
    }

    @Test func preservesInputOrder() {
        let html = BookmarkHTMLExporter.export(items: [
            item("Zebra", "https://z.example/"),
            item("Apple", "https://a.example/"),
        ])
        let zIndex = html.range(of: "Zebra")!.lowerBound
        let aIndex = html.range(of: "Apple")!.lowerBound
        #expect(zIndex < aIndex)
    }

    @Test func escapesTitlesAndURLs() {
        let html = BookmarkHTMLExporter.export(items: [
            item("A & B <\"quoted\">", "https://example.com/?q=a&b=2\"quote"),
        ])
        #expect(html.contains("A &amp; B &lt;&quot;quoted&quot;&gt;"))
        #expect(html.contains("HREF=\"https://example.com/?q=a&amp;b=2&quot;quote\""))
    }

    @Test func emptyBookmarksStillProduceValidDocument() {
        let html = BookmarkHTMLExporter.export(items: [])
        #expect(html.contains("</DL><p>\n"))
        #expect(!html.contains("<DT>"))
    }

    @Test func customTitleIsEscaped() {
        let html = BookmarkHTMLExporter.export(items: [], title: "My <Favorites> & More")
        #expect(html.contains("<TITLE>My &lt;Favorites&gt; &amp; More</TITLE>"))
    }
}
