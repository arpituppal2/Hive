import Foundation
import Testing
@testable import HiveCore

@Suite("HostContextPolicy")
struct HostContextPolicyTests {
    private let page = URL(string: "HTTPS://Example.COM:443/docs/read?token=secret#section")!

    @Test("canonicalizes a web origin and drops page data")
    func canonicalOriginDropsPageData() {
        #expect(HostContextPolicy.canonicalOrigin(for: page) == "https://example.com")
    }

    @Test("preserves non-default ports and trims a trailing host dot")
    func canonicalOriginPreservesNonDefaultPort() {
        #expect(HostContextPolicy.canonicalOrigin(for: URL(string: "http://Example.COM.:8080/path")) == "http://example.com:8080")
        #expect(HostContextPolicy.canonicalOrigin(for: URL(string: "https://example.com:443/path")) == "https://example.com")
    }

    @Test("rejects credentials and non-web URLs")
    func canonicalOriginRejectsUnsafeURLs() {
        #expect(HostContextPolicy.canonicalOrigin(for: URL(string: "https://user:pass@example.com/path")) == nil)
        #expect(HostContextPolicy.canonicalOrigin(for: URL(string: "file:///Users/example/file")) == nil)
        #expect(HostContextPolicy.canonicalOrigin(for: URL(string: "hive://start")) == nil)
        #expect(HostContextPolicy.canonicalOrigin(for: URL(string: "https:///missing-host")) == nil)
        #expect(HostContextPolicy.canonicalOrigin(for: nil) == nil)
    }

    @Test("default follows session permission")
    func defaultFollowsSessionPermission() {
        let policy = HostContextPolicy()
        #expect(policy.effectiveState(for: page, isPrivateBrowsing: false, sessionAllowsPageContext: true) == .default)
        #expect(policy.shouldAdmitPage(url: page, isPrivateBrowsing: false, sessionAllowsPageContext: true))
        #expect(policy.effectiveState(for: page, isPrivateBrowsing: false, sessionAllowsPageContext: false) == .blocked)
        #expect(!policy.shouldAdmitPage(url: page, isPrivateBrowsing: false, sessionAllowsPageContext: false))
    }

    @Test("allow cannot override a session that excludes page context")
    func allowCannotOverrideSession() {
        let policy = HostContextPolicy(decisions: ["https://example.com/private/path": .allow])
        #expect(policy.decision(for: page) == .allow)
        #expect(policy.effectiveState(for: page, isPrivateBrowsing: false, sessionAllowsPageContext: false) == .blocked)
        #expect(!policy.shouldAdmitPage(url: page, isPrivateBrowsing: false, sessionAllowsPageContext: false))
    }

    @Test("block overrides a session that allows page context")
    func blockOverridesSession() {
        let policy = HostContextPolicy(decisions: ["https://example.com/path": .block])
        #expect(policy.effectiveState(for: page, isPrivateBrowsing: false, sessionAllowsPageContext: true) == .blocked)
        #expect(!policy.shouldAdmitPage(url: page, isPrivateBrowsing: false, sessionAllowsPageContext: true))
    }

    @Test("private browsing always wins over an allow decision")
    func privateBrowsingAlwaysWins() {
        let policy = HostContextPolicy(decisions: ["https://example.com": .allow])
        #expect(policy.effectiveState(for: page, isPrivateBrowsing: true, sessionAllowsPageContext: true) == .privateBrowsing)
        #expect(!policy.shouldAdmitPage(url: page, isPrivateBrowsing: true, sessionAllowsPageContext: true))
    }

    @Test("unavailable pages fail closed")
    func unavailablePagesFailClosed() {
        let policy = HostContextPolicy()
        #expect(policy.effectiveState(for: URL(string: "about:blank"), isPrivateBrowsing: false, sessionAllowsPageContext: true) == .unavailable)
        #expect(!policy.shouldAdmitPage(url: URL(string: "about:blank"), isPrivateBrowsing: false, sessionAllowsPageContext: true))
    }

    @Test("decoding repairs non-canonical origin keys")
    func decodingRepairsNonCanonicalKeys() throws {
        let data = Data("{\"decisions\":{\"https://example.com/path?token=secret\":\"block\",\"file:///tmp/private\":\"allow\",\"https://safe.example\":\"allow\"}}".utf8)
        let policy = try JSONDecoder().decode(HostContextPolicy.self, from: data)
        #expect(policy.decisions == ["https://example.com": .block, "https://safe.example": .allow])
    }

    @Test("setting a decision changes only the canonical origin")
    func settingChangesCanonicalOrigin() {
        let policy = HostContextPolicy()
        let blocked = policy.setting(.block, for: page)
        #expect(blocked?.decision(for: URL(string: "https://example.com/other")) == .block)
        let blockedKeys = blocked?.decisions.map { $0.key } ?? []
        #expect(Set(blockedKeys) == ["https://example.com"])
        let reset = blocked?.setting(.default, for: page)
        #expect(reset?.decisions.isEmpty == true)
    }

@Test func hostContextDecisionsIncludeDefault() {
        #expect(HostContextPolicy.Decision.allCases.contains(.default))
    }

@Test func hostContextDecisionsAreNonEmpty() {
        #expect(!HostContextPolicy.Decision.allCases.isEmpty)
    }
}
