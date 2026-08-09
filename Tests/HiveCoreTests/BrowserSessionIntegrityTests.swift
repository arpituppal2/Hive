import Foundation
import Testing
@testable import HiveCore

@Suite("BrowserSessionIntegrity")
struct BrowserSessionIntegrityTests {
    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-session-integrity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeRawSession(_ session: BrowserSession, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(session).write(to: url, options: .atomic)
    }

    @Test("normalization removes private tabs and dangling references")
    func removesPrivateAndDanglingReferences() {
        let kept = BrowserTab(id: "kept", url: URL(string: "https://example.com"))
        let privateTab = BrowserTab(id: "private", isPrivate: true)
        let space = Space(
            id: "space",
            name: "Work",
            tabIDs: ["missing", "kept", "private", "kept"],
            activeTabID: "missing",
            groups: [
                TabGroup(
                    id: "group",
                    name: "Research",
                    tabIDs: ["private", "missing", "kept", "kept"],
                    lastActiveTabID: "missing"
                )
            ]
        )
        let session = BrowserSession(
            windows: [BrowserSessionWindow(
                spaces: [space],
                tabs: [kept, privateTab],
                activeSpaceID: "unknown-space",
                activeTabID: "private"
            )],
            archivedTabs: [ArchivedTab(id: "archived-private", title: "Private", url: URL(string: "https://private.example")!, isPrivate: true)]
        )

        let normalization = session.normalizedForRestore
        let normalized = normalization.session
        let window = normalized.windows[0]
        let restoredSpace = window.spaces[0]

        #expect(window.tabs.map(\.id) == ["kept"])
        #expect(restoredSpace.tabIDs == ["kept"])
        #expect(restoredSpace.activeTabID == "kept")
        #expect(restoredSpace.groups.count == 1)
        #expect(restoredSpace.groups[0].tabIDs == ["kept"])
        #expect(restoredSpace.groups[0].tabIDs == ["kept"])
        #expect(restoredSpace.groups[0].lastActiveTabID == "kept")
        #expect(window.activeSpaceID == "space")
        #expect(window.activeTabID == "kept")
        #expect(normalized.archivedTabs.isEmpty)
        #expect(normalization.report.didRepair)
        #expect(session.windows[0].tabs.count == 2)
    }

    @Test("empty groups are preserved as user state")
    func preservesEmptyGroups() {
        let session = BrowserSession(windows: [BrowserSessionWindow(
            spaces: [Space(id: "space", name: "Work", groups: [
                TabGroup(id: "empty-group", name: "Saved group", tabIDs: ["missing"])
            ])]
        )])

        let normalization = session.normalizedForRestore
        let groups = normalization.session.windows[0].spaces[0].groups

        #expect(groups.count == 1)
        #expect(groups[0].id == "empty-group")
        #expect(groups[0].tabIDs.isEmpty)
        #expect(normalization.report.removedDanglingTabReferences == 1)
    }

    @Test("empty spaces and tabs do not invent restore state")
    func doesNotInventEntities() {
        let session = BrowserSession(windows: [BrowserSessionWindow(
            spaces: [Space(id: "empty", name: "Empty", tabIDs: ["ghost"])],
            tabs: [],
            activeSpaceID: "ghost-space",
            activeTabID: "ghost-tab"
        )])

        let normalization = session.normalizedForRestore
        let normalized = normalization.session
        let window = normalized.windows[0]

        #expect(window.tabs.isEmpty)
        #expect(window.spaces.count == 1)
        #expect(window.spaces[0].tabIDs.isEmpty)
        #expect(window.spaces[0].activeTabID == nil)
        #expect(window.activeSpaceID == "empty")
        #expect(window.activeTabID == nil)
    }

    @Test("store reports repairs for a malformed primary payload")
    func storeReportsPrimaryRepairs() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("session.json")
        let backup = directory.appendingPathComponent("session.prev.json")
        let kept = BrowserTab(id: "kept")
        let malformed = BrowserSession(windows: [BrowserSessionWindow(
            spaces: [Space(id: "space", name: "Work", tabIDs: ["ghost", "kept"])],
            tabs: [kept],
            activeSpaceID: "missing-space",
            activeTabID: "ghost"
        )])
        try writeRawSession(malformed, to: url)

        let result = BrowserSessionStore.loadSync(url: url, prevURL: backup)
        guard case .restored(let restored, let report) = result else {
            Issue.record("Expected restored primary payload")
            return
        }
        #expect(restored.windows[0].activeSpaceID == "space")
        #expect(restored.windows[0].activeTabID == "kept")
        #expect(report.didRepair)
        #expect(report.removedDanglingTabReferences == 1)
    }

    @Test("backup recovery carries semantic repair metadata")
    func backupRecoveryReportsRepairs() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("session.json")
        let backup = directory.appendingPathComponent("session.prev.json")
        let kept = BrowserTab(id: "kept")
        let malformed = BrowserSession(windows: [BrowserSessionWindow(
            spaces: [Space(id: "space", name: "Work", tabIDs: ["ghost", "kept"])],
            tabs: [kept],
            activeSpaceID: "space",
            activeTabID: "ghost"
        )])
        try Data("not-json".utf8).write(to: url)
        try writeRawSession(malformed, to: backup)

        let result = BrowserSessionStore.loadSync(url: url, prevURL: backup)
        guard case .corrupt(_, let recovered, let report) = result else {
            Issue.record("Expected corrupt result with backup recovery")
            return
        }
        #expect(recovered?.windows[0].activeTabID == "kept")
        #expect(report.didRepair)
        #expect(report.removedDanglingTabReferences == 1)
    }

    @Test("archived public tabs survive normalization")
    func archivedPublicTabsSurvive() {
        let session = BrowserSession(
            archivedTabs: [
                ArchivedTab(id: "arch-pub", title: "Public Archive", url: URL(string: "https://example.com")!, isPrivate: false),
                ArchivedTab(id: "arch-priv", title: "Private Archive", isPrivate: true)
            ]
        )
        let normalization = session.normalizedForRestore
        #expect(normalization.session.archivedTabs.map(\.id) == ["arch-pub"])
    }

    @Test("window without spaces is still valid after normalization")
    func emptyWindowNormalizes() {
        let session = BrowserSession(windows: [BrowserSessionWindow(
            spaces: [],
            tabs: [],
            activeSpaceID: nil,
            activeTabID: nil
        )])
        let normalization = session.normalizedForRestore
        #expect(normalization.session.windows.count == 1)
        #expect(normalization.session.windows[0].spaces.isEmpty)
    }

    @Test("valid active selection and ordering are preserved")
    func preservesValidSelectionAndOrder() {
        let first = BrowserTab(id: "first")
        let second = BrowserTab(id: "second")
        let session = BrowserSession(windows: [BrowserSessionWindow(
            spaces: [Space(id: "space", name: "Work", tabIDs: ["second", "first"], activeTabID: "first")],
            tabs: [first, second],
            activeSpaceID: "space",
            activeTabID: "first"
        )])

        let normalization = session.normalizedForRestore
        let normalized = normalization.session
        let window = normalized.windows[0]

        #expect(window.spaces[0].tabIDs == ["second", "first"])
        #expect(window.spaces[0].activeTabID == "first")
        #expect(window.activeSpaceID == "space")
        #expect(window.activeTabID == "first")
    }

@Test func repairReportDefaultsToZero() {
        let report = BrowserSessionRepairReport()
        #expect(report.removedPrivateTabs == 0)
    }
}
