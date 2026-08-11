import Foundation
import Testing
@testable import HiveCore

@Suite("SiteMutePolicy")
struct SiteMutePolicyTests {

    private func url(_ s: String) -> URL? { URL(string: s) }

    @Test("www prefix and case are normalized")
    func normalization() {
        #expect(SiteMutePolicy.hostKey(for: url("https://www.GitHub.com/a")) == "github.com")
        #expect(SiteMutePolicy.hostKey(for: url("http://github.com/b")) == "github.com")
        #expect(SiteMutePolicy.hostKey(for: url("https://WWW.Example.COM")) == "example.com")
    }

    @Test("Non-http schemes never produce a site key")
    func schemeGating() {
        #expect(SiteMutePolicy.hostKey(for: url("hive://start")) == nil)
        #expect(SiteMutePolicy.hostKey(for: url("about:blank")) == nil)
        #expect(SiteMutePolicy.hostKey(for: url("file:///tmp/a.html")) == nil)
        #expect(SiteMutePolicy.hostKey(for: url("ftp://example.com/file")) == nil)
        #expect(SiteMutePolicy.hostKey(for: url("javascript:void(0)")) == nil)
    }

    @Test("Nil and hostless URLs never produce a site key")
    func nilAndHostless() {
        #expect(SiteMutePolicy.hostKey(for: nil) == nil)
        #expect(SiteMutePolicy.hostKey(for: url("https:///path")) == nil)
    }

    @Test("Ports and IPs keep their host identity")
    func portsAndIPs() {
        #expect(SiteMutePolicy.hostKey(for: url("http://localhost:8080/app")) == "localhost")
        #expect(SiteMutePolicy.hostKey(for: url("https://127.0.0.1:3000")) == "127.0.0.1")
        // A bare host must not collide with a ported one through www-stripping.
        #expect(SiteMutePolicy.hostKey(for: url("https://www.example.com:8443")) == "example.com")
    }

    @Test("matchesHost compares against the normalized key")
    func matchesHost() {
        #expect(SiteMutePolicy.matchesHost(url("https://www.GitHub.com/x"), host: "github.com"))
        #expect(SiteMutePolicy.matchesHost(url("https://example.com/y"), host: "example.com"))
        #expect(!SiteMutePolicy.matchesHost(url("https://sub.example.com/y"), host: "example.com"))
        #expect(!SiteMutePolicy.matchesHost(url("hive://start"), host: "start"))
    }
}
