import CryptoKit
import Foundation
import Testing
@testable import HiveCore

@Suite("ResearchHandoffSupervisor")
struct ResearchHandoffSupervisorTests {
    private final class MemoryBackend: HMACKeyMaterialBackend, @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: Data] = [:]

        func read(service: String, account: String, accessGroup: String?) throws -> Data? {
            lock.lock()
            defer { lock.unlock() }
            return values["\(service)|\(account)|\(accessGroup ?? "")"]
        }

        func write(_ data: Data, service: String, account: String, accessGroup: String?) throws {
            lock.lock()
            defer { lock.unlock() }
            let key = "\(service)|\(account)|\(accessGroup ?? "")"
            if values[key] == nil { values[key] = data }
        }
    }

    private func makeStores() throws -> (HoneycombStore, EventLedgerStore) {
        (try HoneycombStore(path: ":memory:"), try EventLedgerStore(path: ":memory:"))
    }

    private func makePaths() -> (root: URL, registry: String, journal: String) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-handoff-supervisor-\(UUID().uuidString)")
        return (
            root,
            root.appendingPathComponent("state/registry.sqlite").path,
            root.appendingPathComponent("state/journal.sqlite").path
        )
    }

    private func makePayload(retentionClass: String = "session", deletionScope: String = "this_source") throws -> Data {
        let body = Data("supervisor test body".utf8)
        let hash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let object: [String: Any] = [
            "schema_version": 1,
            "kind": "research_source",
            "provenance": "rust-research-boundary",
            "source": [
                "requested_url": "https://example.com/start",
                "final_url": "https://example.com/final",
                "status": 200,
                "content_type": "text/html",
                "redirect_count": 1,
                "retrieved_at_unix_ms": "1725000000000",
                "content_hash_sha256": hash,
                "body_base64": body.base64EncodedString(),
                "capture_method": "swarm-research"
            ],
            "retention": [
                "class": retentionClass,
                "deletion_scope": deletionScope
            ],
            "extraction": "not_extracted",
            "citation_ready": false
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func makeCapability() -> RetentionCapability {
        let body = Data("supervisor test body".utf8)
        let hash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        return RetentionCapability(
            nonce: "supervisor-grant",
            issuerID: "supervisor-test",
            retentionClass: "project",
            deletionScope: "provenance",
            sourceContentHash: hash,
            projectID: "project-1",
            provenance: "rust-research-boundary",
            issuedAt: Date().addingTimeInterval(-1),
            expiresAt: Date().addingTimeInterval(120)
        )
    }

    @Test func createsParentDirectoriesAndUsesPositiveActiveVersion() async throws {
        let (honeycomb, ledger) = try makeStores()
        let paths = makePaths()
        let backend = MemoryBackend()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        let supervisor = try await ResearchHandoffSupervisor(
            honeycomb: honeycomb,
            ledger: ledger,
            registryPath: paths.registry,
            journalPath: paths.journal,
            issuerID: "supervisor-test",
            keychainBackend: backend
        )

        #expect(supervisor.activeKeyVersion == 1)
        #expect(FileManager.default.fileExists(atPath: paths.registry))
        #expect(FileManager.default.fileExists(atPath: paths.journal))
        #expect(try await supervisor.reconcilePending().isEmpty)
    }

    @Test func rejectsEmptyAndSharedStoragePaths() async throws {
        let (honeycomb, ledger) = try makeStores()
        let backend = MemoryBackend()
        await #expect(throws: ResearchHandoffSupervisor.SupervisorError.emptyPath(label: "registry")) {
            _ = try await ResearchHandoffSupervisor(
                honeycomb: honeycomb,
                ledger: ledger,
                registryPath: "",
                journalPath: ":memory:",
                keychainBackend: backend
            )
        }

        await #expect(throws: ResearchHandoffSupervisor.SupervisorError.pathsMustBeDistinct) {
            _ = try await ResearchHandoffSupervisor(
                honeycomb: honeycomb,
                ledger: ledger,
                registryPath: ":memory:",
                journalPath: ":memory:",
                keychainBackend: backend
            )
        }
    }

    @Test func keyMaterialAndSignaturesSurviveSupervisorRecreation() async throws {
        let (honeycomb, ledger) = try makeStores()
        let paths = makePaths()
        let backend = MemoryBackend()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        let issuedAt = Date().addingTimeInterval(-1)
        let expiresAt = Date().addingTimeInterval(120)
        var capability = makeCapability()
        capability = RetentionCapability(
            nonce: capability.nonce,
            issuerID: capability.issuerID,
            retentionClass: capability.retentionClass,
            deletionScope: capability.deletionScope,
            sourceContentHash: capability.sourceContentHash,
            projectID: capability.projectID,
            provenance: capability.provenance,
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )

        let firstSigned: RetentionCapability
        do {
            let first = try await ResearchHandoffSupervisor(
                honeycomb: honeycomb,
                ledger: ledger,
                registryPath: paths.registry,
                journalPath: paths.journal,
                issuerID: "supervisor-test",
                keychainBackend: backend
            )
            firstSigned = try await first.issueApprovedCapability(capability)
        }

        let second = try await ResearchHandoffSupervisor(
            honeycomb: honeycomb,
            ledger: ledger,
            registryPath: paths.registry,
            journalPath: paths.journal,
            issuerID: "supervisor-test",
            keychainBackend: backend
        )
        let secondSigned = try await second.issueApprovedCapability(capability)

        #expect(firstSigned == secondSigned)
        #expect(firstSigned.keyVersion == 1)
    }

    @Test func durableApprovalIsSingleUseThroughTheCompositionRoot() async throws {
        let (honeycomb, ledger) = try makeStores()
        let paths = makePaths()
        let backend = MemoryBackend()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        let supervisor = try await ResearchHandoffSupervisor(
            honeycomb: honeycomb,
            ledger: ledger,
            registryPath: paths.registry,
            journalPath: paths.journal,
            issuerID: "supervisor-test",
            keychainBackend: backend
        )
        let capability = try await supervisor.issueApprovedCapability(makeCapability())
        let payload = try makePayload(retentionClass: "project", deletionScope: "provenance")

        _ = try await supervisor.ingest(
            json: payload,
            projectID: "project-1",
            retentionCapability: capability
        )
        await #expect(throws: ResearchHandoffAdapter.AdapterError.capabilityReplayed) {
            _ = try await supervisor.ingest(
                json: payload,
                projectID: "project-1",
                retentionCapability: capability
            )
        }
        #expect(try await ledger.countEvents(actionKind: .research) == 1)
    }

    @Test func recreatedSupervisorRepairsAStagedJournalRecord() async throws {
        let (honeycomb, ledger) = try makeStores()
        let paths = makePaths()
        let backend = MemoryBackend()
        defer { try? FileManager.default.removeItem(at: paths.root) }

        let body = Data("supervisor recovery body".utf8)
        let hash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let source = Source(
            id: "supervisor-recovery-source",
            url: "https://example.com/recovery",
            contentHash: hash,
            provenance: "rust-research-boundary",
            requestedURL: "https://example.com/recovery",
            httpStatus: 200,
            bodySize: body.count,
            retrievedAtUnixMS: "1725000000000",
            retentionClass: "session",
            deletionScope: "this_source",
            extractionState: "not_extracted",
            citationReady: false
        )
        let event = EventLedgerStore.LedgerEvent(
            id: "supervisor-recovery-event",
            actor: "research-boundary",
            intent: "Persist verified research source handoff",
            actionKind: .research,
            actionTarget: source.url,
            trustLevel: .t2,
            policyDecision: .allowed,
            consentState: .notRequired,
            contextIDs: [source.id],
            result: .success,
            verificationResult: .verified,
            provenance: source.provenance
        )
        // Bootstrap once so the composition root creates its durable parent
        // directory, then release that instance before simulating a restart.
        do {
            _ = try await ResearchHandoffSupervisor(
                honeycomb: honeycomb,
                ledger: ledger,
                registryPath: paths.registry,
                journalPath: paths.journal,
                issuerID: "supervisor-test",
                keychainBackend: backend
            )
        }

        do {
            let journal = try HandoffRecoveryJournal(path: paths.journal)
            try await journal.append(.init(source: source, event: event))
        }
        _ = try await honeycomb.createSource(source)

        let supervisor = try await ResearchHandoffSupervisor(
            honeycomb: honeycomb,
            ledger: ledger,
            registryPath: paths.registry,
            journalPath: paths.journal,
            issuerID: "supervisor-test",
            keychainBackend: backend
        )
        let results = try await supervisor.reconcilePending()

        #expect(results.count == 1)
        #expect(results[0].outcome == .repaired)
        #expect(results[0].sourceID == source.id)
        #expect(try await ledger.countEvents(actionKind: .research) == 1)
        let reopenedJournal = try HandoffRecoveryJournal(path: paths.journal)
        #expect(try await reopenedJournal.count() == 0)
    }

@Test func versionComparisonIsCorrect() async throws {
        let (honeycomb, ledger) = try makeStores()
        let paths = makePaths()
        let backend = MemoryBackend()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        let supervisor = try await ResearchHandoffSupervisor(
            honeycomb: honeycomb, ledger: ledger,
            registryPath: paths.registry, journalPath: paths.journal,
            issuerID: "version-test", keychainBackend: backend
        )
        #expect(supervisor.activeKeyVersion > 0)
    }

    @Test func supervisorActiveKeyVersionIsPositive() async throws {
        let (honeycomb, ledger) = try makeStores()
        let paths = makePaths()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        let backend = MemoryBackend()
        let supervisor = try await ResearchHandoffSupervisor(
            honeycomb: honeycomb, ledger: ledger,
            registryPath: paths.registry, journalPath: paths.journal,
            issuerID: "version-positive", keychainBackend: backend
        )
        #expect(supervisor.activeKeyVersion >= 1)
    }
}
