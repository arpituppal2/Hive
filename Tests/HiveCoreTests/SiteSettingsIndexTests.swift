import Testing
import Foundation
@testable import HiveCore

@Suite("SiteSettingsIndex")
struct SiteSettingsIndexTests {

    private func permission(_ host: String, _ kind: SitePermissionKind, _ state: SitePermissionState, at date: Date) -> SitePermission {
        SitePermission(host: host, kind: kind, state: state, modifiedAt: date)
    }

    @Test("empty stores produce an empty index")
    func emptyIndex() {
        let entries = SiteSettingsIndex.build(
            zoomLevels: [:], mutedHosts: [], httpsExceptions: [], permissions: [])
        #expect(entries.isEmpty)
    }

    @Test("merges all four stores and deduplicates hosts")
    func mergesStores() {
        let now = Date()
        let entries = SiteSettingsIndex.build(
            zoomLevels: ["github.com": 125, "news.ycombinator.com": 80],
            mutedHosts: ["github.com"],
            httpsExceptions: ["example.org"],
            permissions: [
                permission("example.org", .camera, .allow, at: now),
                permission("example.org", .notifications, .deny, at: now),
                permission("news.ycombinator.com", .location, .ask, at: now), // ask excluded
            ]
        )
        #expect(entries.map(\.host) == ["example.org", "github.com", "news.ycombinator.com"])
        guard let github = entries.first(where: { $0.host == "github.com" }) else {
            Issue.record("github.com missing"); return
        }
        #expect(github.zoomPercent == 125)
        #expect(github.isMuted)
        #expect(!github.isHTTPSException)
        #expect(github.decidedKinds.isEmpty)
        #expect(github.decisionCount == 2)
        guard let example = entries.first(where: { $0.host == "example.org" }) else {
            Issue.record("example.org missing"); return
        }
        #expect(example.isHTTPSException)
        #expect(example.zoomPercent == nil)
        #expect(example.decidedKinds.count == 2)
        #expect(example.decisionCount == 3)
        guard let hn = entries.first(where: { $0.host == "news.ycombinator.com" }) else {
            Issue.record("hn missing"); return
        }
        #expect(hn.zoomPercent == 80)
        #expect(hn.decidedKinds.isEmpty) // ask-state permission never counts
        #expect(hn.decisionCount == 1)
    }

    @Test("default 100% zoom and ask-state permissions never surface a host")
    func defaultsExcluded() {
        let entries = SiteSettingsIndex.build(
            zoomLevels: ["plain.example": 100],
            mutedHosts: [],
            httpsExceptions: [],
            permissions: [permission("plain.example", .camera, .ask, at: Date())]
        )
        #expect(entries.isEmpty)
    }

    @Test("permissions are ordered newest first")
    func permissionsNewestFirst() {
        let old = permission("site.test", .camera, .allow, at: Date(timeIntervalSince1970: 100))
        let new = permission("site.test", .notifications, .deny, at: Date(timeIntervalSince1970: 200))
        let entries = SiteSettingsIndex.build(
            zoomLevels: [:], mutedHosts: [], httpsExceptions: [],
            permissions: [old, new])
        guard let entry = entries.first else {
            Issue.record("no entry"); return
        }
        #expect(entry.decidedKinds == [.notifications, .camera])
    }

    @Test("summary strings describe the stored decisions")
    func summaries() {
        let now = Date()
        let entries = SiteSettingsIndex.build(
            zoomLevels: ["zoom.test": 150],
            mutedHosts: ["muted.test"],
            httpsExceptions: ["http.test"],
            permissions: [permission("perm.test", .location, .allow, at: now)])
        func summary(_ host: String) -> String {
            entries.first(where: { $0.host == host })?.summary ?? "missing"
        }
        #expect(summary("zoom.test") == "150% zoom")
        #expect(summary("muted.test") == "Muted")
        #expect(summary("http.test") == "HTTP allowed")
        #expect(summary("perm.test") == "1 permission")
    }

    @Test("sorting is case-insensitive")
    func caseInsensitiveSort() {
        let entries = SiteSettingsIndex.build(
            zoomLevels: ["Zebra.example": 125, "apple.example": 125],
            mutedHosts: [], httpsExceptions: [], permissions: [])
        #expect(entries.map(\.host) == ["apple.example", "Zebra.example"])
    }

    @Test("an https exception is listed even while the mode is off")
    func exceptionListedRegardlessOfMode() {
        let entries = SiteSettingsIndex.build(
            zoomLevels: [:], mutedHosts: [], httpsExceptions: ["inert.example"],
            permissions: [])
        #expect(entries.map(\.host) == ["inert.example"])
        #expect(entries.first?.isHTTPSException == true)
    }
}
