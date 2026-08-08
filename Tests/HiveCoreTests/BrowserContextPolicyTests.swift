import Foundation
import HiveCore
import Testing

// Additional regression tests for the per-tab AI page-visibility boundary.
// The main BrowserContextPolicy suite remains in PreferenceMemoryTests.swift.

@Test
func disabledPageReturnsNoModelContext() {
    let page = PageContext(
        tabID: "tab-1",
        url: URL(string: "https://example.com"),
        title: "Example",
        text: "private-to-the-tab",
        aiContextAllowed: false
    )
    #expect(BrowserContextPolicy.scopePage(page) == nil)
    #expect(BrowserContextPolicy.untrustedPageBlock(page) == nil)
}

@Test
func allowedPageStillScopesAsUntrustedData() {
    let page = PageContext(
        tabID: "tab-1",
        url: URL(string: "https://example.com"),
        title: "Example",
        text: "ordinary page text",
        aiContextAllowed: true
    )
    let scoped = BrowserContextPolicy.scopePage(page)
    #expect(scoped?.text.contains("ordinary page text") == true)
    #expect(BrowserContextPolicy.untrustedPageBlock(page)?.contains("UNTRUSTED_PAGE_DATA") == true)
}

@Test
func hiveInternalPagesAreNeverScoped() {
    let page = PageContext(
        tabID: "tab-1",
        url: URL(string: "hive://start"),
        title: "New Tab",
        text: "internal content",
        aiContextAllowed: true
    )
    #expect(BrowserContextPolicy.scopePage(page) == nil)
}

@Test
func pageWithEmptyTextIsScoped() {
    let page = PageContext(
        tabID: "tab-2",
        url: URL(string: "https://blank.example"),
        title: "Blank",
        text: "",
        aiContextAllowed: true
    )
    let scoped = BrowserContextPolicy.scopePage(page)
    #expect(scoped != nil)
    #expect(scoped?.text.isEmpty == true)
}

@Test
func fbcdnSubdomainStillScopedAsHTTPS() {
    let page = PageContext(
        tabID: "tab-cdn",
        url: URL(string: "https://scontent-fra3-1.xx.fbcdn.net/image"),
        title: "Image",
        text: "cdn content",
        aiContextAllowed: true
    )
    #expect(BrowserContextPolicy.scopePage(page) != nil)
}

@Test
func nonHTTPSPagesAreNeverScoped() {
    for scheme in ["http", "ftp", "data", "blob"] {
        let page = PageContext(
            tabID: "tab-scheme",
            url: URL(string: scheme + "://example.com"),
            title: "Non-HTTPS",
            text: "content",
            aiContextAllowed: true
        )
        #expect(BrowserContextPolicy.scopePage(page) == nil)
    }
}
