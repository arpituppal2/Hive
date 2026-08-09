import Foundation
import Testing
@testable import HiveCore

@Suite("PrivacyReportSummary")
struct PrivacyReportSummaryTests {
    @Test func aggregatesMeasuredCountsAndExcludesPrivateTabs() {
        let publicTab = BrowserTab(
            url: URL(string: "https://www.Example.com/path"),
            blockedCount: 4
        )
        let privateTab = BrowserTab(
            url: URL(string: "https://private.example"),
            isPrivate: true,
            blockedCount: 99
        )

        let summary = PrivacyReportSummary(tabs: [publicTab, privateTab])

        #expect(summary.totalBlocked == 4)
        #expect(summary.measuredTabCount == 1)
        #expect(summary.measuredSiteCount == 1)
        #expect(summary.topSites == [PrivacyReportSummary.SiteCount(host: "example.com", count: 4)])
    }

    @Test func clampsNegativeCountsAndSkipsTabsWithoutMeasuredBlocks() {
        let negative = BrowserTab(url: URL(string: "https://negative.example"), blockedCount: -5)
        let noURL = BrowserTab(url: nil, blockedCount: 7)
        let zero = BrowserTab(url: URL(string: "https://zero.example"), blockedCount: 0)

        let summary = PrivacyReportSummary(tabs: [negative, noURL, zero])

        #expect(summary.totalBlocked == 0)
        #expect(summary.topSites.isEmpty)
        #expect(summary.measuredTabCount == 2)
        #expect(summary.measuredSiteCount == 2)
    }

    @Test func sortsByCountThenHostAndCapsTopSites() {
        let tabs = [
            BrowserTab(url: URL(string: "https://www.B.example"), blockedCount: 2),
            BrowserTab(url: URL(string: "https://a.example"), blockedCount: 2),
            BrowserTab(url: URL(string: "https://c.example"), blockedCount: 1)
        ]

        let summary = PrivacyReportSummary(tabs: tabs, topSiteLimit: 2)

        #expect(summary.topSites == [
            PrivacyReportSummary.SiteCount(host: "a.example", count: 2),
            PrivacyReportSummary.SiteCount(host: "b.example", count: 2)
        ])
        #expect(summary.totalBlocked == 5)
        #expect(summary.measuredSiteCount == 3)
    }

    @Test func constructorNormalizesInvalidNegativeValues() {
        let summary = PrivacyReportSummary(
            totalBlocked: -1,
            topSites: [],
            measuredTabCount: -2,
            measuredSiteCount: -3
        )

        #expect(summary.totalBlocked == 0)
        #expect(summary.measuredTabCount == 0)
        #expect(summary.measuredSiteCount == 0)
    }
    @Test func emptyTabsProducesZeroAggregate() {
        let summary = PrivacyReportSummary(tabs: [])
        #expect(summary.totalBlocked == 0)
        #expect(summary.measuredTabCount == 0)
        #expect(summary.measuredSiteCount == 0)
        #expect(summary.topSites.isEmpty)
    }

    @Test func singleTabAggregatesCorrectly() {
        let tab = BrowserTab(url: URL(string: "https://single.example"), blockedCount: 7)
        let summary = PrivacyReportSummary(tabs: [tab])
        #expect(summary.totalBlocked == 7)
        #expect(summary.measuredSiteCount == 1)
        #expect(summary.topSites == [PrivacyReportSummary.SiteCount(host: "single.example", count: 7)])
    }

@Test func siteCountIDIsHost() {
        let sc = PrivacyReportSummary.SiteCount(host: "example.com", count: 42)
        #expect(sc.id == "example.com")
    }
}
