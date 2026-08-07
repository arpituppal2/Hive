import Foundation
import Testing
@testable import HiveCore

@Suite("SitePermissionPolicy")
struct SitePermissionPolicyTests {
    private let host = "example.com"

    @Test func normalizesHostsWithoutBroadeningOrigin() {
        #expect(SitePermissionPolicy.normalizedHost(" Example.COM. ") == "example.com")
        #expect(SitePermissionPolicy.normalizedHost("www.example.com") == "www.example.com")
    }

    @Test func defaultsToAskAndResolvesStoredDecision() {
        let permissions = [SitePermission(host: host, kind: .camera, state: .allow)]
        #expect(SitePermissionPolicy.state(
            forHost: "EXAMPLE.COM.", kind: .camera, permissions: permissions, isPrivate: false
        ) == .allow)
        #expect(SitePermissionPolicy.state(
            forHost: host, kind: .microphone, permissions: permissions, isPrivate: false
        ) == .ask)
    }

    @Test func privateTabsAlwaysResolveAsk() {
        let permissions = [SitePermission(host: host, kind: .camera, state: .allow)]
        #expect(SitePermissionPolicy.state(
            forHost: host, kind: .camera, permissions: permissions, isPrivate: true
        ) == .ask)
    }

    @Test func privateTabsCannotPersistDecisions() {
        let permissions = [SitePermission(host: host, kind: .camera, state: .allow)]
        let updated = SitePermissionPolicy.applying(
            .deny, forHost: host, kind: .camera, to: permissions, isPrivate: true)
        #expect(updated == permissions)
    }

    @Test func popupPolicyPreservesUserLinksAndBlocksDeniedScripts() {
        #expect(SitePermissionPolicy.allowsNewWindow(
            navigationType: .userActivatedLink, permission: .deny))
        #expect(!SitePermissionPolicy.allowsNewWindow(
            navigationType: .scriptOrUnknown, permission: .deny))
        #expect(SitePermissionPolicy.allowsNewWindow(
            navigationType: .scriptOrUnknown, permission: .ask))
    }
}
