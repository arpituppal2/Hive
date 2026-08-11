import Foundation
import Testing
@testable import HiveCore

@Suite("SwarmMemoryAdmission")
struct SwarmMemoryAdmissionTests {
    private func makeLoader() throws -> (loader: CellPromptLoader, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-librarian-test-\(UUID().uuidString)", isDirectory: true)
        let librarianDirectory = directory.appendingPathComponent("librarian", isDirectory: true)
        try FileManager.default.createDirectory(at: librarianDirectory, withIntermediateDirectories: true)
        try """
        # Librarian

        ## Job (one sentence)
        Extract candidate claims for the current session.
        """.write(
            to: librarianDirectory.appendingPathComponent("100m_librarian.md"),
            atomically: true,
            encoding: .utf8
        )
        return (CellPromptLoader(promptsDir: directory), directory)
    }

    private func waitForCandidate(in store: HotMemoryStore) async -> HotMemoryStore.HotEntry? {
        for _ in 0..<20 {
            if let entry = await store.currentHotEntries().first(where: { $0.admission == .candidate }) {
                return entry
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return nil
    }

    @Test func librarianExtractionCreatesCandidateButNoDurableHoneycombNode() async throws {
        let (loader, directory) = try makeLoader()
        defer { try? FileManager.default.removeItem(at: directory) }
        let honeycomb = try HoneycombStore(path: ":memory:")
        let hotMemory = HotMemoryStore(honeycomb: honeycomb)
        let ledger = try EventLedgerStore(path: ":memory:")
        let orchestrator = SwarmOrchestrator(
            hotMemory: hotMemory,
            ledger: ledger,
            prompts: loader,
            librarianResultProvider: { _ in "Fact: A model-derived claim" }
        )

        _ = try await orchestrator.process(
            intent: "Explain the current research",
            page: PageContext(
                tabID: "tab-1",
                url: URL(string: "https://example.com"),
                title: "Research page",
                text: "Public research text"
            )
        )

        let candidate = await waitForCandidate(in: hotMemory)
        #expect(candidate != nil)
        #expect(candidate?.id.hasPrefix("candidate-") == true)
        #expect(candidate?.admission == .candidate)
        let durableNodeCount = try await honeycomb.countNodes()
        #expect(durableNodeCount == 0)
    }

    @Test func privateLibrarianExtractionCreatesNoCandidate() async throws {
        let (loader, directory) = try makeLoader()
        defer { try? FileManager.default.removeItem(at: directory) }
        let honeycomb = try HoneycombStore(path: ":memory:")
        let hotMemory = HotMemoryStore(honeycomb: honeycomb)
        let ledger = try EventLedgerStore(path: ":memory:")
        let orchestrator = SwarmOrchestrator(
            hotMemory: hotMemory,
            ledger: ledger,
            prompts: loader,
            librarianResultProvider: { _ in "Fact: A model-derived claim" }
        )

        _ = try await orchestrator.process(
            intent: "Summarize this private page",
            page: PageContext(
                tabID: "private-tab",
                url: URL(string: "https://private.example.com"),
                title: "Private page",
                text: "Private text",
                privateBrowsing: true
            )
        )

        try? await Task.sleep(for: .milliseconds(100))
        let privateEntries = await hotMemory.currentHotEntries()
        #expect(privateEntries.allSatisfy { $0.admission != .candidate })
        let durableNodeCount = try await honeycomb.countNodes()
        #expect(durableNodeCount == 0)
    }
}
