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

    @Test func allowPersistsAndResolvesAfterUpdate() {
        var permissions: [SitePermission] = []
        permissions = SitePermissionPolicy.applying(.allow, forHost: host, kind: .camera, to: permissions, isPrivate: false)
        #expect(permissions.count == 1)
        let state = SitePermissionPolicy.state(forHost: host, kind: .camera, permissions: permissions, isPrivate: false)
        #expect(state == .allow)
    }

    @Test func denyPersistsAndOverridesPreviousAllow() {
        var permissions = [SitePermission(host: host, kind: .camera, state: .allow)]
        permissions = SitePermissionPolicy.applying(.deny, forHost: host, kind: .camera, to: permissions, isPrivate: false)
        #expect(permissions.count == 1)
        #expect(permissions[0].state == .deny)
    }

    @Test func differentPermissionKindsAreIndependent() {
        var permissions = [SitePermission(host: host, kind: .camera, state: .allow)]
        permissions = SitePermissionPolicy.applying(.deny, forHost: host, kind: .microphone, to: permissions, isPrivate: false)
        #expect(permissions.count == 2)
        let cameraState = SitePermissionPolicy.state(forHost: host, kind: .camera, permissions: permissions, isPrivate: false)
        let micState = SitePermissionPolicy.state(forHost: host, kind: .microphone, permissions: permissions, isPrivate: false)
        #expect(cameraState == .allow)
        #expect(micState == .deny)
    }

    @Test func normalizedHostTrimsWhitespaceAndLowercases() {
        #expect(SitePermissionPolicy.normalizedHost("  Example.COM  ") == "example.com")
        #expect(SitePermissionPolicy.normalizedHost("EXAMPLE.COM") == "example.com")
    }

    @Test func normalizedHostHandlesEmptyString() {
        #expect(SitePermissionPolicy.normalizedHost("") == "")
        #expect(SitePermissionPolicy.normalizedHost("   ") == "")
    }
}
