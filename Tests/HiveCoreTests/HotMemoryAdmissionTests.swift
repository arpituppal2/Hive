import Foundation
import Testing
@testable import HiveCore

@Suite("HotMemoryAdmission")
struct HotMemoryAdmissionTests {
    @Test func candidateIsNotPersistedButDurableEntryIsRestored() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-hot-memory-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("hot-memory.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let honeycomb = try HoneycombStore(path: ":memory:")
        let first = HotMemoryStore(honeycomb: honeycomb, persistenceURL: url)
        await first.didAccessNode(
            id: "candidate-1",
            sourceHint: "candidate",
            label: "Model claim",
            content: "Derived from page text",
            admission: .candidate
        )
        await first.didAccessGlobalNode(
            id: "durable-1",
            sourceHint: "explicit",
            label: "User note",
            content: "Written by the user"
        )
        await first.saveNow()

        let second = HotMemoryStore(honeycomb: honeycomb, persistenceURL: url)
        let restored = await second.currentHotEntries()
        #expect(restored.contains { $0.id == "durable-1" })
        #expect(!restored.contains { $0.id == "candidate-1" })
    }

    @Test func legacyLibrarianEntriesAreNotRestored() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-legacy-hot-memory-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("hot-memory.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacyEntry = HotMemoryStore.HotEntry(
            id: "librarian-legacy",
            label: "Old extraction",
            content: "Must not return",
            admission: .durable
        )
        let data = try JSONEncoder().encode([legacyEntry])
        // The snapshot wrapper is private; use a valid legacy-shaped payload
        // with the entry and no admission field to exercise decoder defaults.
        let json = """
        {"entries":[\(String(data: data, encoding: .utf8)!.dropFirst().dropLast())],"forgotten":[],"activeProjectID":null,"activeWorkspaceID":null,"activeProfileID":null}
        """
        try Data(json.utf8).write(to: url)
        let store = HotMemoryStore(persistenceURL: url)
        #expect(await store.currentHotEntries().isEmpty)
    }

    @Test func candidateAdmissionIsMonotonicWithoutImplicitPromotion() async {
        let store = HotMemoryStore()
        await store.didAccessNode(id: "candidate", admission: .candidate)
        await store.didAccessNode(id: "candidate", admission: .durable)
        let entries = await store.currentHotEntries()
        #expect(entries.first?.admission == .candidate)
    }
}
