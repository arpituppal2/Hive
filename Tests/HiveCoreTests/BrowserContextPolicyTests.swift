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
