import Foundation
import Testing
@testable import HiveCore

@Suite("BrowserPageActionPolicy")
struct BrowserPageActionPolicyTests {
    @Test("only hosted HTTP(S) pages expose page actions")
    func hostedWebPages() {
        #expect(BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "https://example.com/article")))
        #expect(BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "HTTP://EXAMPLE.COM")))
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "hive://start")))
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "about:blank")))
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "file:///tmp/article.html")))
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: nil))
    }

    @Test("private web pages retain ordinary page actions")
    func privateWebPages() {
        // Privacy is enforced at persistence/context boundaries, not by
        // removing standard controls from a private browsing tab.
        #expect(BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "https://private.example/")))
    }

    @Test("web schemes require a non-empty host")
    func hostRequired() {
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "https:///missing-host")))
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "http://")))
    }

    @Test("transient tabs without a live URL do not expose page actions")
    func transientTabStates() {
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: nil))
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "hive://start")))
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "about:blank")))
    }
}
