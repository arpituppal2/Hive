import Foundation
import Testing
@testable import HiveCore

@Suite("SessionDurabilityContract")
struct SessionDurabilityContractTests {
    private struct Payload: Codable, Sendable, Equatable {
        var value: String
    }

    private func makeStore() throws -> (SessionFileStore<Payload>, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-session-durability-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (
            SessionFileStore(
                url: dir.appendingPathComponent("session.json"),
                prevURL: dir.appendingPathComponent("session.prev.json")
            ),
            dir
        )
    }

    @Test func failedEncodeDoesNotRotatePrimaryOrBackup() throws {
        struct Failing: Codable, Sendable {
            func encode(to encoder: Encoder) throws {
                throw CocoaError(.coderInvalidValue)
            }
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-session-failure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("session.json")
        let prev = directory.appendingPathComponent("session.prev.json")
        try Data("primary".utf8).write(to: url)
        try Data("backup".utf8).write(to: prev)

        SessionFileStore<Failing>(url: url, prevURL: prev).write(Failing())

        #expect(try String(contentsOf: url, encoding: .utf8) == "primary")
        #expect(try String(contentsOf: prev, encoding: .utf8) == "backup")
    }

    @Test func legacyBrowserSessionPayloadDefaultsLifecycleFields() throws {
        let data = """
        {"windows": [], "savedAt": "2026-08-04T00:00:00Z", "archivedTabs": []}
        """.data(using: .utf8)!
        let session = try JSONDecoder.hiveSessionForTests.decode(BrowserSession.self, from: data)
        #expect(session.schemaVersion == BrowserSession.currentSchemaVersion)
        #expect(session.snapshotSequence == 0)
        #expect(session.isCleanExit == false)
    }

    @Test func browserSessionLifecycleFieldsRoundTripAndPrivateDataStaysExcluded() throws {
        let privateTab = BrowserTab(id: "private", isPrivate: true)
        let publicTab = BrowserTab(id: "public", url: URL(string: "https://example.com"))
        let session = BrowserSession(
            windows: [BrowserSessionWindow(
                spaces: [Space(id: "space", name: "Work", tabIDs: ["private", "public"])],
                tabs: [privateTab, publicTab],
                activeSpaceID: "space",
                activeTabID: "public"
            )],
            snapshotSequence: 42,
            isCleanExit: true
        )
        let sanitized = session.sanitizedForPersistence
        let data = try JSONEncoder().encode(sanitized)
        let restored = try JSONDecoder().decode(BrowserSession.self, from: data)

        #expect(restored.snapshotSequence == 42)
        #expect(restored.isCleanExit)
        #expect(restored.windows[0].tabs.map(\.id) == ["public"])
        #expect(restored.windows[0].spaces[0].tabIDs == ["public"])
    }

    @Test func secondWritePreservesPreviousPrimaryAsBackup() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.write(Payload(value: "one"))
        store.write(Payload(value: "two"))

        let backup = try Data(contentsOf: store.prevURL)
        #expect(try JSONDecoder().decode(Payload.self, from: backup).value == "one")
        guard case .restored(let current) = store.load() else {
            Issue.record("Expected current primary to remain restorable")
            return
        }
        #expect(current.value == "two")
    }
}

private extension JSONDecoder {
    static let hiveSessionForTests: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
