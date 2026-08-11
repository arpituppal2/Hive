import Foundation
import Testing
@testable import HiveCore

@Suite("HTTPSOnlyPolicy")
struct HTTPSOnlyPolicyTests {

    private func url(_ s: String) -> URL? { URL(string: s) }

    @Test("Plain http upgrades to https when enabled")
    func upgradesWhenEnabled() {
        let result = HTTPSOnlyPolicy.upgraded(
            url("http://example.com/a?b=1"), enabled: true, exceptions: []
        )
        #expect(result?.scheme == "https")
        #expect(result?.host == "example.com")
        #expect(result?.path == "/a")
        #expect(result?.query == "b=1")
    }

    @Test("No upgrade when disabled")
    func disabledNeverUpgrades() {
        #expect(HTTPSOnlyPolicy.upgraded(url("http://example.com"), enabled: false, exceptions: []) == nil)
    }

    @Test("Already-secure and non-http URLs pass through untouched")
    func nonHttpUntouched() {
        #expect(HTTPSOnlyPolicy.upgraded(url("https://example.com"), enabled: true, exceptions: []) == nil)
        #expect(HTTPSOnlyPolicy.upgraded(url("hive://start"), enabled: true, exceptions: []) == nil)
        #expect(HTTPSOnlyPolicy.upgraded(url("about:blank"), enabled: true, exceptions: []) == nil)
        #expect(HTTPSOnlyPolicy.upgraded(nil, enabled: true, exceptions: []) == nil)
    }

    @Test("Excepted hosts are never upgraded")
    func exceptionsRespected() {
        // Exceptions are stored as normalized keys (the app inserts the
        // www-stripped host), so a legacy.net exception covers www.legacy.net.
        let exceptions: Set<String> = ["example.com", "legacy.net"]
        #expect(HTTPSOnlyPolicy.upgraded(url("http://example.com/x"), enabled: true, exceptions: exceptions) == nil)
        #expect(HTTPSOnlyPolicy.upgraded(url("http://www.legacy.net/y"), enabled: true, exceptions: exceptions) == nil)
        #expect(HTTPSOnlyPolicy.upgraded(url("https://www.legacy.net/y"), enabled: true, exceptions: exceptions) == nil)
        // A different host still upgrades.
        #expect(HTTPSOnlyPolicy.upgraded(url("http://other.org"), enabled: true, exceptions: exceptions)?.scheme == "https")
    }

    @Test("Warning fires for un-excepted plaintext pages only")
    func warningCondition() {
        #expect(HTTPSOnlyPolicy.shouldWarn(for: url("http://example.com"), enabled: true, exceptions: []))
        #expect(!HTTPSOnlyPolicy.shouldWarn(for: url("https://example.com"), enabled: true, exceptions: []))
        #expect(!HTTPSOnlyPolicy.shouldWarn(for: url("http://example.com"), enabled: false, exceptions: []))
        #expect(!HTTPSOnlyPolicy.shouldWarn(for: url("http://example.com"), enabled: true, exceptions: ["example.com"]))
    }

    @Test("Ports and IP hosts upgrade like any site")
    func portsUpgrade() {
        let result = HTTPSOnlyPolicy.upgraded(url("http://localhost:8080/app"), enabled: true, exceptions: [])
        #expect(result?.scheme == "https")
        #expect(result?.port == 8080)
    }
}
