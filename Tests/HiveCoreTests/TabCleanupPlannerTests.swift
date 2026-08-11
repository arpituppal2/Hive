import Foundation
import Testing
@testable import HiveCore

@Suite("TabCleanupPlanner")
struct TabCleanupPlannerTests {

    private func input(
        _ id: String,
        _ url: URL?,
        at ageDays: Double = 0,
        pinned: Bool = false,
        essential: Bool = false,
        `private`: Bool = false,
        now: Date = Date()
    ) -> TabCleanupPlanner.TabInput {
        TabCleanupPlanner.TabInput(
            id: id,
            url: url,
            title: id,
            lastAccessed: now.addingTimeInterval(-ageDays * 86_400),
            isPinned: pinned,
            isEssential: essential,
            isPrivate: `private`
        )
    }

    private func url(_ s: String) -> URL? { URL(string: s) }

    @Test func duplicateGroupKeepsMostRecent() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("old", url("https://example.com/a"), at: 5, now: now),
            input("mid", url("https://example.com/a"), at: 2, now: now),
            input("new", url("https://example.com/a"), at: 0.1, now: now),
        ], now: now)
        #expect(plan.duplicateGroups.count == 1)
        let group = plan.duplicateGroups[0]
        #expect(group.keepID == "new")
        #expect(Set(group.closeIDs) == ["old", "mid"])
        #expect(plan.staleTabs.isEmpty)
    }

    @Test func normalizedURLEquivalenceGroupsVariants() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("a", url("https://EXAMPLE.com/path#frag"), at: 1, now: now),
            input("b", url("https://example.com/path/"), at: 0.1, now: now),
        ], now: now)
        #expect(plan.duplicateGroups.count == 1)
        #expect(plan.duplicateGroups[0].url == "https://example.com/path")
        #expect(Set(plan.duplicateGroups[0].closeIDs) == ["a"])
    }

    @Test func pinnedTabIsNeverClosedAndPreferredKeeper() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("pinned", url("https://example.com/"), at: 40, pinned: true, now: now),
            input("fresh", url("https://example.com/"), at: 0.1, now: now),
        ], now: now)
        let group = plan.duplicateGroups[0]
        #expect(group.keepID == "pinned")
        #expect(group.closeIDs == ["fresh"])
    }

    @Test func allPinnedDuplicatesAreNotSuggested() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("p1", url("https://example.com/"), at: 1, pinned: true, now: now),
            input("p2", url("https://example.com/"), at: 0.1, pinned: true, now: now),
        ], now: now)
        #expect(plan.duplicateGroups.isEmpty)
    }

    @Test func staleWindowRespectsCutoffAndProtectsPinned() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("old", url("https://old.example/"), at: 45, now: now),
            input("recent", url("https://recent.example/"), at: 1, now: now),
            input("pinnedOld", url("https://pin.example/"), at: 90, pinned: true, now: now),
        ], now: now, staleAfterDays: 30)
        #expect(plan.staleTabs.map(\.id) == ["old"])
    }

    @Test func internalChromeAndAboutPagesAreExcluded() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("brief", url("hive://brief"), at: 60, now: now),
            input("blank", url("about:blank"), at: 60, now: now),
            input("start", url("hive://start?private=1"), at: 60, now: now),
        ], now: now)
        #expect(plan.isEmpty)
    }

    @Test func staleDoesNotDoubleCountDuplicateClosers() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("dup-old", url("https://example.com/x"), at: 45, now: now),
            input("dup-new", url("https://example.com/x"), at: 0.1, now: now),
        ], now: now)
        #expect(plan.duplicateGroups.count == 1)
        #expect(plan.staleTabs.isEmpty)
        #expect(Set(plan.closeIDs) == ["dup-old"])
    }

    @Test func closeIDsAreStableAndDeduplicated() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("a", url("https://example.com/a"), at: 45, now: now),
            input("b", url("https://example.com/a"), at: 0.1, now: now),
            input("c", url("https://stale.example/"), at: 45, now: now),
        ], now: now)
        let ids = plan.closeIDs
        #expect(ids.count == 2)
        #expect(ids.contains("a"))
        #expect(ids.contains("c"))
        #expect(!plan.isEmpty)
    }

    @Test func privateTabsAreNeverSuggested() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("pv1", url("https://example.com/"), at: 45, `private`: true, now: now),
            input("pv2", url("https://example.com/"), at: 0.1, `private`: true, now: now),
        ], now: now)
        #expect(plan.isEmpty)
    }

    @Test func defaultPortsAreEquivalent() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("a", url("https://example.com:443/x"), at: 1, now: now),
            input("b", url("https://example.com/x"), at: 0.1, now: now),
        ], now: now)
        #expect(plan.duplicateGroups.count == 1)
        #expect(Set(plan.duplicateGroups[0].closeIDs) == ["a"])
    }

    @Test func uniqueURLsProduceEmptyPlan() {
        let now = Date()
        let plan = TabCleanupPlanner.plan(tabs: [
            input("a", url("https://one.example/"), at: 0.1, now: now),
            input("b", url("https://two.example/"), at: 0.2, now: now),
            input("c", url("https://three.example/"), at: 0.3, now: now),
        ], now: now)
        #expect(plan.isEmpty)
    }
}
