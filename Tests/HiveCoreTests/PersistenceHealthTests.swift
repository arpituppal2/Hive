import Foundation
import Testing
@testable import HiveCore

@Suite("PersistenceHealth")
struct PersistenceHealthTests {
    @Test("in-memory stores disclose their ephemeral state")
    func inMemoryStoresAreMarkedEphemeral() throws {
        let honeycomb = try HoneycombStore(path: ":memory:")
        let ledger = try EventLedgerStore(path: ":memory:")

        #expect(honeycomb.isEphemeral)
        #expect(ledger.isEphemeral)
    }

    @Test("file-backed stores disclose durable state")
    func fileBackedStoresAreNotEphemeral() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-persistence-health-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let honeycomb = try HoneycombStore(path: directory.appendingPathComponent("honeycomb.sqlite3").path)
        let ledger = try EventLedgerStore(path: directory.appendingPathComponent("ledger.sqlite3").path)

        #expect(!honeycomb.isEphemeral)
        #expect(!ledger.isEphemeral)
    }

    @Test("temporary file-backed store is durable but not ephemeral")
    func tempFileIsDurable() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-ph-test-\(UUID().uuidString).sqlite3").path
        let store = try HoneycombStore(path: path)
        #expect(!store.isEphemeral)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("invalid storage paths fail instead of pretending to be durable")
    func invalidStoragePathsThrow() {
        let invalidBase = "/dev/null/hive-persistence-health-\(UUID().uuidString)"
        #expect(throws: Error.self) {
            _ = try HoneycombStore(path: invalidBase)
        }
        #expect(throws: Error.self) {
            _ = try EventLedgerStore(path: invalidBase)
        }
    }

@Test func allFalseNotDegraded() {
        let p = PersistenceHealthPolicy(knowledgeDegraded: false, auditDegraded: false, sessionDegraded: false)
        #expect(!p.isDegraded)
    }
}
