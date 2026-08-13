import Foundation
import Testing
@testable import HiveCore

@Suite("HostContextAdmission")
struct HostContextAdmissionTests {
    private let page = PageContext(
        tabID: "active",
        url: URL(string: "https://example.com/article"),
        title: "Article",
        text: "private page body"
    )

    @Test("blocked page scope excludes page content")
    func blockedScopeExcludesPage() {
        let scope = ContextScope(
            includesCurrentPage: true,
            pageVisibility: .blocked
        )
        #expect(!scope.admits(page: page))
        #expect(scope.diagnosticLabel.contains("page blocked"))
    }

    @Test("allowed page scope admits eligible page")
    func allowedScopeAdmitsPage() {
        let scope = ContextScope(
            includesCurrentPage: true,
            pageVisibility: .allowed
        )
        #expect(scope.admits(page: page))
    }

    @Test("private page remains excluded even if scope is allowed")
    func privatePageRemainsExcluded() {
        let privatePage = PageContext(
            tabID: "private",
            url: URL(string: "https://example.com/private"),
            title: "Private",
            text: "must not enter context",
            privateBrowsing: true
        )
        let scope = ContextScope(
            includesCurrentPage: true,
            includesPrivateContent: false,
            pageVisibility: .allowed
        )
        #expect(!scope.admits(page: privatePage))
    }

    @Test("blocked explicit tab is excluded rather than admitted")
    func blockedExplicitTabIsExcluded() {
        let candidate = TabAttachmentSummary.Candidate(
            id: "active",
            profileID: "profile",
            workspaceID: "workspace",
            isPrivate: false,
            isActive: true,
            hasUsableHTTPURL: true,
            pageVisibility: .blocked
        )
        let result = TabAttachmentSummary.classify(
            selectedIDs: ["active"],
            candidates: [candidate],
            currentProfileID: "profile",
            currentWorkspaceID: "workspace",
            isPrivateBrowsing: false,
            includesCurrentPage: true
        )
        #expect(result.first?.classification == .excluded)
    }

    @Test("authoritative referenced-tab policy rejects blocked and unavailable pages")
    func authoritativeReferencedTabPolicyFailsClosed() {
        #expect(!SwarmResponseContextPolicy.allowsReferencedTab(
            tabProfileID: "profile",
            tabWorkspaceID: "workspace",
            currentProfileID: "profile",
            currentWorkspaceID: "workspace",
            isPrivateBrowsing: false,
            tabIsPrivate: false,
            pageVisibility: .blocked
        ))
        #expect(!SwarmResponseContextPolicy.allowsReferencedTab(
            tabProfileID: "profile",
            tabWorkspaceID: "workspace",
            currentProfileID: "profile",
            currentWorkspaceID: "workspace",
            isPrivateBrowsing: false,
            tabIsPrivate: false,
            pageVisibility: .unavailable
        ))
        #expect(SwarmResponseContextPolicy.allowsReferencedTab(
            tabProfileID: "profile",
            tabWorkspaceID: "workspace",
            currentProfileID: "profile",
            currentWorkspaceID: "workspace",
            isPrivateBrowsing: false,
            tabIsPrivate: false,
            pageVisibility: .allowed
        ))
    }

    @Test("default visibility remains backward compatible")
    func defaultVisibilityRemainsCompatible() {
        let scope = ContextScope(includesCurrentPage: true)
        #expect(scope.pageVisibility == .allowed)
        #expect(scope.admits(page: page))
    }

@Test func effectiveStatesAreNonEmpty() {
        #expect(!HostContextPolicy.EffectiveState.allCases.isEmpty)
    }
}
