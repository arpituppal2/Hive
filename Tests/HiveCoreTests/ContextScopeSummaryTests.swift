import Testing
@testable import HiveCore

@Suite("ContextScopeSummary")
struct ContextScopeSummaryTests {
    @Test("workspace summary exposes scoped categories without identifiers")
    func workspaceSummary() {
        let summary = ContextScopeSummary(
            scope: ContextScope(
                profileID: "profile-id",
                workspaceID: "workspace-id",
                includesCurrentPage: true,
                includesHotMemory: true,
                includesProjectNodes: true,
                includesPreferences: true
            ),
            explicitTabCount: 2,
            isPrivateBrowsing: false
        )

        #expect(summary.title == "Workspace")
        #expect(summary.detail == "Current page + scoped memory")
        #expect(summary.privacyDetail == "Only this workspace's approved context")
        #expect(summary.explicitTabCount == 2)
        #expect(summary.rows.count == 4)
        let allRowsIncluded = summary.rows.allSatisfy { $0.isIncluded }
        let exposesProfileID = summary.rows.contains { $0.detail.contains("profile-id") }
        let exposesWorkspaceID = summary.rows.contains { $0.detail.contains("workspace-id") }
        #expect(allRowsIncluded)
        #expect(!exposesProfileID)
        #expect(!exposesWorkspaceID)
    }

    @Test("page-only summary excludes saved context")
    func pageOnlySummary() {
        let summary = ContextScopeSummary(
            scope: ContextScope(
                includesCurrentPage: true,
                includesHotMemory: false,
                includesProjectNodes: false,
                includesPreferences: false
            ),
            isPrivateBrowsing: false
        )

        #expect(summary.title == "Page only")
        #expect(summary.detail == "Current page")
        #expect(summary.explicitTabCount == 0)
        #expect(summary.rows[0].isIncluded)
        let savedRowsExcluded = summary.rows.dropFirst().allSatisfy { !$0.isIncluded }
        #expect(savedRowsExcluded)
    }

    @Test("private boundary is visibly unavailable")
    func privateSummary() {
        let summary = ContextScopeSummary(
            scope: ContextScope(
                includesCurrentPage: false,
                includesHotMemory: false,
                includesProjectNodes: false,
                includesPreferences: false,
                includesPrivateContent: false
            ),
            explicitTabCount: 4,
            isPrivateBrowsing: true
        )

        #expect(summary.title == "Private browsing")
        #expect(summary.detail == "Context unavailable")
        #expect(summary.privacyDetail == "Private content stays out of Swarm context")
        let allRowsExcluded = summary.rows.allSatisfy { !$0.isIncluded }
        #expect(allRowsExcluded)
        #expect(summary.explicitTabCount == 4)
    }

    @Test("site policy block is visible and excludes the current page")
    func blockedPageSummary() {
        let summary = ContextScopeSummary(
            scope: ContextScope(
                includesCurrentPage: true,
                includesHotMemory: true,
                pageVisibility: .blocked
            ),
            isPrivateBrowsing: false
        )

        #expect(summary.title == "Page context blocked")
        #expect(summary.detail == "Current page excluded by site policy")
        #expect(summary.privacyDetail == "Current page content will not be sent to Swarm")
        #expect(summary.rows[0].detail == "Blocked by site policy")
        #expect(!summary.rows[0].isIncluded)
    }

    @Test("private and unavailable page states are visibly excluded")
    func nonAdmissiblePageStatesAreExcluded() {
        for visibility in [HostContextPolicy.EffectiveState.privateBrowsing, .unavailable] {
            let summary = ContextScopeSummary(
                scope: ContextScope(includesCurrentPage: true, pageVisibility: visibility),
                isPrivateBrowsing: false
            )
            #expect(!summary.rows[0].isIncluded)
            #expect(summary.rows[0].detail.contains("Excluded"))
        }
    }

    @Test("negative attachment counts are clamped")
    func clampsNegativeTabCount() {
        let summary = ContextScopeSummary(
            scope: .browserDefault,
            explicitTabCount: -1,
            isPrivateBrowsing: false
        )
        #expect(summary.explicitTabCount == 0)
    }

@Test("rows always have nonEmpty labels")
    func rowsHaveLabels() {
        let summary = ContextScopeSummary(scope: .browserDefault, isPrivateBrowsing: false)
        for row in summary.rows {
            #expect(!row.label.isEmpty)
            #expect(!row.detail.isEmpty)
        }
    }

    @Test("workspace default includes hot memory")
    func workspaceDefaultIncludesHotMemory() {
        let scope = ContextScope(
            includesCurrentPage: true, includesHotMemory: true,
            includesProjectNodes: false, includesPreferences: false
        )
        let summary = ContextScopeSummary(scope: scope, isPrivateBrowsing: false)
        #expect(summary.rows.count >= 2)
        #expect(summary.rows[1].isIncluded)
    }

@Test func rowIDIsLabel() {
        let row = ContextScopeSummary.Row(label: "Tabs", detail: "3", isIncluded: true)
        #expect(row.id == "Tabs")
    }
}
