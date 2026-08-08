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

    @Test("localhost is treated as a valid web page")
    func localhostIsValid() {
        #expect(BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "http://localhost:3000")))
        #expect(BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "https://localhost")))
    }

    @Test("IP addresses are valid web pages")
    func ipAddressesAreValid() {
        #expect(BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "https://192.168.1.1")))
        #expect(BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "http://127.0.0.1:8080")))
    }

    @Test("custom protocol handlers are not web pages")
    func customProtocolsNotWeb() {
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "ftp://example.com/file")))
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "chrome://settings")))
        #expect(!BrowserPageActionPolicy.canUseWebPageActions(for: URL(string: "hive://brief")))
    }
}
