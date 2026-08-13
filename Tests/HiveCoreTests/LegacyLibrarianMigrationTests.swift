import Foundation
import SQLite3
import Testing
@testable import HiveCore

@Suite("LegacyLibrarianMigration")
struct LegacyLibrarianMigrationTests {
    @Test func schemaV2PurgesLegacyNodesBeforeReads() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-legacy-migration-\(UUID().uuidString).sqlite3").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Seed a legacy record using the current schema, then mark the file as
        // pre-v2 to exercise the real startup migration on the next open.
        do {
            let honeycomb = try HoneycombStore(path: path)
            _ = try await honeycomb.insertNode(
                HoneycombStore.Node(
                    type: .note,
                    label: "Legacy extracted claim",
                    metadata: .object(["claim": .string("old")]),
                    contentHash: HoneycombStore.sha256("legacy"),
                    provenance: "librarian-extraction"
                )
            )
            _ = try await honeycomb.insertNode(
                HoneycombStore.Node(type: .note, label: "User note", provenance: "user")
            )
        }
        var db: OpaquePointer?
        #expect(sqlite3_open(path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        _ = sqlite3_exec(db, "PRAGMA user_version = 1", nil, nil, nil)
        sqlite3_close(db)
        db = nil

        let migrated = try HoneycombStore(path: path)
        #expect(try await migrated.search(query: "Legacy extracted claim").isEmpty)
        #expect(try await migrated.getNodesByType(.note).contains { $0.provenance == "user" })
        #expect(try await migrated.purgeLegacyLibrarianExtraction() == 0)
    }

    @Test func explicitPurgeIsIdempotent() async throws {
        let honeycomb = try HoneycombStore(path: ":memory:")
        _ = try await honeycomb.insertNode(
            HoneycombStore.Node(type: .note, label: "Legacy", provenance: "librarian-extraction")
        )
        #expect(try await honeycomb.purgeLegacyLibrarianExtraction() == 1)
        #expect(try await honeycomb.purgeLegacyLibrarianExtraction() == 0)
    }
}
