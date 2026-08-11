import Testing
import Foundation
@testable import HiveCore

@Suite("SiteDataPolicy")
struct SiteDataPolicyTests {

    // MARK: History host matching

    @Test("www-stripped http(s) URLs match the stored host key")
    func hostMatchesWWW() {
        #expect(SiteDataPolicy.hostMatches(URL(string: "https://www.example.com/page"), host: "example.com"))
        #expect(SiteDataPolicy.hostMatches(URL(string: "http://example.com/"), host: "example.com"))
        #expect(SiteDataPolicy.hostMatches(URL(string: "https://EXAMPLE.com/Path"), host: "example.com"))
    }

    @Test("non-http schemes never match")
    func nonHTTPSchemesNeverMatch() {
        #expect(!SiteDataPolicy.hostMatches(URL(string: "hive://start?chrome=1"), host: "start"))
        #expect(!SiteDataPolicy.hostMatches(URL(string: "file:///tmp/a.html"), host: "tmp"))
        #expect(!SiteDataPolicy.hostMatches(nil, host: "example.com"))
    }

    @Test("subdomains stay outside the registrable-domain key")
    func subdomainsDoNotMatch() {
        #expect(!SiteDataPolicy.hostMatches(URL(string: "https://gist.github.com/x"), host: "github.com"))
        #expect(!SiteDataPolicy.hostMatches(URL(string: "https://mail.example.com"), host: "example.com"))
    }

    @Test("different hosts never match")
    func differentHostsNeverMatch() {
        #expect(!SiteDataPolicy.hostMatches(URL(string: "https://notexample.com"), host: "example.com"))
    }

    // MARK: Cookie domain matching

    @Test("exact domains match with or without the leading dot")
    func cookieExactMatch() {
        #expect(SiteDataPolicy.cookieDomainMatches("example.com", host: "example.com"))
        #expect(SiteDataPolicy.cookieDomainMatches(".example.com", host: "example.com"))
        #expect(SiteDataPolicy.cookieDomainMatches(".EXAMPLE.com", host: "example.com"))
    }

    @Test("domain cookies cover subdomains")
    func cookieSubdomainCoverage() {
        #expect(SiteDataPolicy.cookieDomainMatches(".example.com", host: "mail.example.com"))
        #expect(SiteDataPolicy.cookieDomainMatches("example.com", host: "a.b.example.com"))
    }

    @Test("dot-delimited suffix prevents prefix collisions")
    func cookieSuffixIsDotDelimited() {
        #expect(!SiteDataPolicy.cookieDomainMatches(".example.com", host: "notexample.com"))
        #expect(!SiteDataPolicy.cookieDomainMatches("ample.com", host: "example.com"))
    }

    @Test("empty cookie domains and IPs are handled")
    func cookieEdgeCases() {
        #expect(!SiteDataPolicy.cookieDomainMatches("", host: "example.com"))
        #expect(SiteDataPolicy.cookieDomainMatches("192.168.0.1", host: "192.168.0.1"))
        #expect(!SiteDataPolicy.cookieDomainMatches("192.168.0.1", host: "192.168.0.2"))
    }
}
