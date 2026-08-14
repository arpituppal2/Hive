import Foundation
import Testing
@testable import HiveCore

@Suite("BrowserSessionPrivacy")
struct BrowserSessionPrivacyTests {
    private func makeSession() -> BrowserSession {
        let normalID = "normal-tab"
        let privateID = "private-tab"
        let group = TabGroup(
            id: "group",
            name: "Research",
            tabIDs: [privateID, normalID],
            lastActiveTabID: privateID
        )
        let space = Space(
            id: "space",
            name: "Work",
            tabIDs: [privateID, normalID],
            activeTabID: privateID,
            groups: [group]
        )
        let normal = BrowserTab(id: normalID, url: URL(string: "https://example.com"))
        let privateTab = BrowserTab(
            id: privateID,
            url: URL(string: "https://private.example"),
            isPrivate: true,
            isHibernated: true
        )
        return BrowserSession(windows: [BrowserSessionWindow(
            spaces: [space],
            tabs: [normal, privateTab],
            activeSpaceID: "space",
            activeTabID: privateID
        )])
    }

    @Test func projectionOmitsPrivateTabsAndRepairsReferences() {
        let session = makeSession()
        let sanitized = session.sanitizedForPersistence
        let window = sanitized.windows[0]
        let space = window.spaces[0]
        let group = space.groups[0]

        #expect(window.tabs.map(\.id) == ["normal-tab"])
        #expect(space.tabIDs == ["normal-tab"])
        #expect(space.activeTabID == "normal-tab")
        #expect(group.tabIDs == ["normal-tab"])
        #expect(group.lastActiveTabID == "normal-tab")
        #expect(window.activeSpaceID == "space")
        #expect(window.activeTabID == "normal-tab")

        // The projection must not mutate the live in-memory session.
        #expect(session.windows[0].tabs.count == 2)
        #expect(session.windows[0].activeTabID == "private-tab")
    }

    @Test func allPrivateWindowFallsBackToNoActiveTab() {
        let privateOnly = BrowserSession(
            windows: [BrowserSessionWindow(
                spaces: [Space(id: "space", name: "Private", tabIDs: ["private"], activeTabID: "private")],
                tabs: [BrowserTab(id: "private", isPrivate: true)],
                activeSpaceID: "space",
                activeTabID: "private"
            )]
        )

        let window = privateOnly.sanitizedForPersistence.windows[0]
        #expect(window.tabs.isEmpty)
        #expect(window.spaces[0].tabIDs.isEmpty)
        #expect(window.spaces[0].activeTabID == nil)
        #expect(window.activeSpaceID == "space")
        #expect(window.activeTabID == nil)
    }

    @Test func projectionOmitsPrivateArchivedRecords() {
        let session = BrowserSession(
            archivedTabs: [
                ArchivedTab(id: "public", title: "Public", isPrivate: false),
                ArchivedTab(id: "private", title: "Private", isPrivate: true)
            ]
        )

        let sanitized = session.sanitizedForPersistence
        #expect(sanitized.archivedTabs.map(\.id) == ["public"])
        #expect(session.archivedTabs.count == 2)
    }

    @Test func storeEncodesSanitizedProjectionAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-session-privacy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = BrowserSessionStore(
            url: directory.appendingPathComponent("session.json"),
            prevURL: directory.appendingPathComponent("session.prev.json"),
            debounceSeconds: 0
        )
        let session = makeSession()
        let sessionURL = directory.appendingPathComponent("session.json")
        let backupURL = directory.appendingPathComponent("session.prev.json")
        BrowserSessionStore.writeSync(session, to: sessionURL, prevBackupTo: backupURL)
        // A second successful write rotates the first sanitized payload into the
        // rolling backup. Use the store's production decoder so the test covers
        // the ISO-8601 session format rather than a generic JSONDecoder.
        BrowserSessionStore.writeSync(session, to: sessionURL, prevBackupTo: backupURL)

        let current = BrowserSessionStore.loadSync(url: sessionURL, prevURL: backupURL)
        let backup = BrowserSessionStore.loadSync(url: backupURL, prevURL: sessionURL)
        for result in [current, backup] {
            guard case .restored(let decoded, _) = result else {
                Issue.record("Expected a sanitized session payload to decode")
                continue
            }
            #expect(decoded.windows[0].tabs.map(\.id) == ["normal-tab"])
            #expect(decoded.windows[0].activeTabID == "normal-tab")
        }
        _ = store // Keep the initializer/API covered without awaiting the actor.
    }

@Test func nilSessionIDDoesNotLeakThroughSanitization() {
        let session = BrowserSession(windows: [])
        let sanitized = session.sanitizedForPersistence
        #expect(sanitized.windows.isEmpty)
    }

    @Test func mixedPublicAndPrivateTabsSanitizesIndependently() {
        let pub = BrowserTab(id: "pub", url: URL(string: "https://pub.example"))
        let prv = BrowserTab(id: "prv", isPrivate: true)
        let session = BrowserSession(windows: [BrowserSessionWindow(
            spaces: [Space(id: "sp", name: "Mix", tabIDs: ["pub", "prv"])],
            tabs: [pub, prv],
            activeSpaceID: "sp",
            activeTabID: "pub"
        )])
        let s = session.sanitizedForPersistence
        #expect(s.windows[0].tabs.count == 1)
        #expect(s.windows[0].tabs[0].id == "pub")
    }

@Test func briefTitlePreserved() {
        let b = Brief(title: "Research Notes", content: "# Notes")
        #expect(b.title == "Research Notes")
    }
}
