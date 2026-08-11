import Foundation
import Testing
@testable import HiveCore

// MARK: - PinnedWebAppPolicy tests

@Suite("PinnedWebAppPolicy")
struct PinnedWebAppPolicyTests {

    private let gmail = URL(string: "https://mail.google.com/mail/u/0/#inbox")!
    private let gmailNoFragment = URL(string: "https://mail.google.com/mail/u/0/")!
    private let slack = URL(string: "https://app.slack.com/client")!

    // MARK: - normalizedAppURL

    @Test func normalizedAppURLStripsFragmentAndwwwAndCase() {
        let url = URL(string: "HTTPS://WWW.Mail.Google.com/mail/u/0/#inbox")!
        let normalized = PinnedWebAppPolicy.normalizedAppURL(url)
        #expect(normalized?.host == "mail.google.com")
        #expect(normalized?.absoluteString.contains("#inbox") == false)
    }

    @Test func normalizedAppURLRejectsNonHTTP() {
        #expect(PinnedWebAppPolicy.normalizedAppURL(URL(string: "hive://start")) == nil)
        #expect(PinnedWebAppPolicy.normalizedAppURL(URL(string: "about:blank")) == nil)
        #expect(PinnedWebAppPolicy.normalizedAppURL(URL(string: "file:///tmp/x")) == nil)
    }

    @Test func normalizedAppURLRequiresHost() {
        #expect(PinnedWebAppPolicy.normalizedAppURL(URL(string: "https:///path")) == nil)
    }

    // MARK: - isSameApp

    @Test func isSameAppIgnoresFragment() {
        #expect(PinnedWebAppPolicy.isSameApp(gmail, gmailNoFragment))
    }

    @Test func isSameAppDistinguishesHosts() {
        #expect(!PinnedWebAppPolicy.isSameApp(gmail, slack))
    }

    @Test func normalizedAppURLPreservesPort() {
        let localhost = URL(string: "https://localhost:8080/app")!
        let noPort = URL(string: "https://localhost/app")!
        #expect(PinnedWebAppPolicy.normalizedAppURL(localhost)?.port == 8080)
        #expect(!PinnedWebAppPolicy.isSameApp(localhost, noPort))
    }

    @Test func upsertNewAppGetsLowestSortOrder() {
        let one = PinnedWebAppPolicy.upsert(existing: [], url: gmail, name: "Gmail", faviconURL: nil)
        let two = PinnedWebAppPolicy.upsert(existing: one, url: slack, name: "Slack", faviconURL: nil)
        // Slack was pinned last, so it must sort FIRST in the rail.
        #expect(PinnedWebAppPolicy.sortedForRail(two).first?.name == "Slack")
    }

    // MARK: - normalizedAppName

    @Test func normalizedAppNameTrimsAndCaps() {
        let name = PinnedWebAppPolicy.normalizedAppName("   A very long app name that definitely exceeds sixty characters in length for sure   ", url: gmail)
        #expect(name.count <= 60)
        #expect(name == name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test func normalizedAppNameFallsBackToHost() {
        #expect(PinnedWebAppPolicy.normalizedAppName("", url: gmail) == "mail.google.com")
    }

    @Test func normalizedAppNameFallsBackToDefault() {
        #expect(PinnedWebAppPolicy.normalizedAppName("   ", url: nil) == "App")
    }

    // MARK: - upsert

    @Test func upsertPrependsNewApp() {
        let apps = PinnedWebAppPolicy.upsert(existing: [], url: gmail, name: "Gmail", faviconURL: nil)
        #expect(apps.count == 1)
        #expect(apps.first?.name == "Gmail")
        #expect(apps.first?.url == gmail)
    }

    @Test func upsertRefreshesExistingInPlace() {
        let first = PinnedWebAppPolicy.upsert(existing: [], url: gmail, name: "Gmail", faviconURL: nil)
        let favicon = URL(string: "https://mail.google.com/favicon.ico")
        let second = PinnedWebAppPolicy.upsert(
            existing: first,
            url: gmailNoFragment, // same identity, different stored URL
            name: "Mail",
            faviconURL: favicon
        )
        #expect(second.count == 1)
        #expect(second.first?.id == first.first?.id) // identity preserved
        #expect(second.first?.name == "Mail")
        #expect(second.first?.faviconURL == favicon)
        #expect(second.first?.url == gmailNoFragment) // stored URL refreshed
        #expect(second.first?.createdAt == first.first?.createdAt) // createdAt preserved
    }

    @Test func upsertDistinctAppsBothRetained() {
        let one = PinnedWebAppPolicy.upsert(existing: [], url: gmail, name: "Gmail", faviconURL: nil)
        let two = PinnedWebAppPolicy.upsert(existing: one, url: slack, name: "Slack", faviconURL: nil)
        #expect(two.count == 2)
    }

    @Test func upsertRejectsNonHTTP() {
        let apps = PinnedWebAppPolicy.upsert(existing: [], url: URL(string: "hive://start")!, name: "X", faviconURL: nil)
        #expect(apps.isEmpty)
    }

    @Test func upsertAppliesCap() {
        var apps: [PinnedWebApp] = []
        for i in 0..<30 {
            let url = URL(string: "https://site\(i).example.com")!
            apps = PinnedWebAppPolicy.upsert(existing: apps, url: url, name: "Site \(i)", faviconURL: nil)
        }
        #expect(apps.count == PinnedWebAppPolicy.hivePinnedWebAppsCap)
        #expect(apps.first?.name == "Site 29") // newest first
    }

    // MARK: - applyCap

    @Test func applyCapTruncatesOldest() {
        var apps: [PinnedWebApp] = []
        for i in 0..<5 {
            apps.append(PinnedWebApp(name: "A\(i)", url: URL(string: "https://a\(i).example.com")!))
        }
        let capped = PinnedWebAppPolicy.applyCap(apps, cap: 3)
        #expect(capped.count == 3)
        #expect(capped[0].name == "A0") // newest first, oldest dropped
    }

    @Test func applyCapNoopWithinCap() {
        let apps = [PinnedWebApp(name: "A", url: gmail)]
        #expect(PinnedWebAppPolicy.applyCap(apps).count == 1)
    }

    // MARK: - sortedForRail

    @Test func sortedForRailOrdersBySortOrderStable() {
        let a = PinnedWebApp(name: "A", url: gmail, sortOrder: 2, createdAt: Date(timeIntervalSince1970: 1))
        let b = PinnedWebApp(name: "B", url: slack, sortOrder: 0, createdAt: Date(timeIntervalSince1970: 2))
        let c = PinnedWebApp(name: "C", url: URL(string: "https://c.example.com")!, sortOrder: 0, createdAt: Date(timeIntervalSince1970: 3))
        let ordered = PinnedWebAppPolicy.sortedForRail([a, b, c])
        #expect(ordered.map(\.name) == ["B", "C", "A"]) // B before C: equal sortOrder, earlier createdAt
    }

    // MARK: - isPinned

    @Test func isPinnedMatchesNormalizedIdentity() {
        let apps = PinnedWebAppPolicy.upsert(existing: [], url: gmail, name: "Gmail", faviconURL: nil)
        #expect(PinnedWebAppPolicy.isPinned(apps, url: gmailNoFragment))
        #expect(!PinnedWebAppPolicy.isPinned(apps, url: slack))
        #expect(!PinnedWebAppPolicy.isPinned(apps, url: nil))
    }
}
