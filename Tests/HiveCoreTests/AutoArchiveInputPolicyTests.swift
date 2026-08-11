import Foundation
import Testing
@testable import HiveCore

// MARK: - AutoArchivePolicy (app-facing TabInput overload)

@Suite("AutoArchivePolicy (TabInput)")
struct AutoArchiveInputPolicyTests {

    private func coldTab(id: String = "t", url: URL? = URL(string: "https://example.com")) -> AutoArchivePolicy.TabInput {
        AutoArchivePolicy.TabInput(
            id: id,
            url: url,
            lastVisitedAt: Date().addingTimeInterval(-20 * 86_400), // 20 days cold
            isPrivate: false
        )
    }

    @Test func returnsEmptyForEmptyInputs() {
        #expect(AutoArchivePolicy.evaluate(tabs: [], now: Date()).isEmpty)
    }

    @Test func flagsColdTab() {
        let tab = coldTab(id: "cold")
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], now: Date()) == ["cold"])
    }

    @Test func skipsRecentTab() {
        let tab = AutoArchivePolicy.TabInput(
            id: "warm",
            url: URL(string: "https://example.com"),
            lastVisitedAt: Date(), // just now
            isPrivate: false
        )
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], now: Date()).isEmpty)
    }

    @Test func skipsActiveTab() {
        let tab = coldTab(id: "active")
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], activeTabID: "active", now: Date()).isEmpty)
    }

    @Test func skipsPinnedTab() {
        let tab = AutoArchivePolicy.TabInput(
            id: "pinned",
            url: URL(string: "https://example.com"),
            lastVisitedAt: Date().addingTimeInterval(-20 * 86_400),
            isPinned: true
        )
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], now: Date()).isEmpty)
    }

    @Test func skipsEssentialTab() {
        let tab = AutoArchivePolicy.TabInput(
            id: "essential",
            url: URL(string: "https://example.com"),
            lastVisitedAt: Date().addingTimeInterval(-20 * 86_400),
            isEssential: true
        )
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], now: Date()).isEmpty)
    }

    @Test func skipsPrivateTabEvenWhenCold() {
        let tab = AutoArchivePolicy.TabInput(
            id: "private",
            url: URL(string: "https://example.com"),
            lastVisitedAt: Date().addingTimeInterval(-20 * 86_400),
            isPrivate: true
        )
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], now: Date()).isEmpty)
    }

    @Test func skipsNoURLTab() {
        let tab = coldTab(id: "blank", url: nil)
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], now: Date()).isEmpty)
    }

    @Test func skipsCollapsedGroupMemberEvenWhenCold() {
        let tab = coldTab(id: "grouped")
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], collapsedGroupTabIDs: ["grouped"], now: Date()).isEmpty)
    }

    @Test func respectsCustomThreshold() {
        let tab = AutoArchivePolicy.TabInput(
            id: "t",
            url: URL(string: "https://example.com"),
            lastVisitedAt: Date().addingTimeInterval(-10 * 86_400), // 10 days
            isPrivate: false
        )
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], now: Date(), threshold: 7 * 86_400) == ["t"])
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], now: Date(), threshold: 14 * 86_400).isEmpty)
    }

    @Test func mixesConditionsCorrectly() {
        let cold = coldTab(id: "cold")
        let pinned = AutoArchivePolicy.TabInput(
            id: "pinned",
            url: URL(string: "https://example.com"),
            lastVisitedAt: Date().addingTimeInterval(-20 * 86_400),
            isPinned: true
        )
        let warm = AutoArchivePolicy.TabInput(
            id: "warm",
            url: URL(string: "https://example.com"),
            lastVisitedAt: Date(),
            isPrivate: false
        )
        let result = AutoArchivePolicy.evaluate(tabs: [cold, pinned, warm], now: Date())
        #expect(result == ["cold"])
    }

    @Test func legacyBrowserTabAPIStillWorks() {
        var tab = BrowserTab(url: URL(string: "https://x.com"), spaceID: "s")
        tab.lastVisitedAt = Date().addingTimeInterval(-20 * 86_400)
        #expect(AutoArchivePolicy.evaluate(tabs: [tab], now: Date()) == [tab.id])
    }
}

// MARK: - TabArchiveShelfPolicy

@Suite("TabArchiveShelfPolicy")
struct TabArchiveShelfPolicyTests {

    private func record(id: String, archivedAt: Date) -> ArchivedTab {
        ArchivedTab(
            id: id,
            title: "T\(id)",
            url: URL(string: "https://example.com/\(id)"),
            archivedAt: archivedAt,
            lastVisitedAt: archivedAt.addingTimeInterval(-86_400)
        )
    }

    @Test func sortedForShelfNewestFirst() {
        let old = record(id: "old", archivedAt: Date(timeIntervalSince1970: 100))
        let new = record(id: "new", archivedAt: Date(timeIntervalSince1970: 300))
        #expect(TabArchiveShelfPolicy.sortedForShelf([old, new]).map(\.id) == ["new", "old"])
    }

    @Test func applyCapDropsOldest() {
        // The caller feeds the shelf newest-first (inserted at the front);
        // the cap truncates that given order, dropping the tail (oldest).
        let records = [
            record(id: "new", archivedAt: Date(timeIntervalSince1970: 4)),
            record(id: "mid", archivedAt: Date(timeIntervalSince1970: 3)),
            record(id: "old", archivedAt: Date(timeIntervalSince1970: 2)),
        ]
        let capped = TabArchiveShelfPolicy.applyCap(records, cap: 2)
        #expect(capped.count == 2)
        #expect(capped.map(\.id) == ["new", "mid"]) // oldest dropped
    }

    @Test func applyCapNoopWithinCap() {
        let records = [record(id: "a", archivedAt: Date())]
        #expect(TabArchiveShelfPolicy.applyCap(records).count == 1)
    }

    @Test func defaultCapIs100() {
        #expect(TabArchiveShelfPolicy.hiveArchivedTabsCap == 100)
    }
}
