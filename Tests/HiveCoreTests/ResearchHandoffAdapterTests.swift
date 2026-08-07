import CryptoKit
import Foundation
import Testing
@testable import HiveCore

@Suite("ResearchHandoffAdapter")
struct ResearchHandoffAdapterTests {
    private func makeStores() throws -> (HoneycombStore, EventLedgerStore) {
        (try HoneycombStore(path: ":memory:"), try EventLedgerStore(path: ":memory:"))
    }

    private func makeAuthority() throws -> RetentionCapabilityAuthority {
        try RetentionCapabilityAuthority(
            key: SymmetricKey(data: Data(repeating: 7, count: 32)),
            issuerID: "test-approval-controller"
        )
    }

    private func makeAdapter(
        honeycomb: HoneycombStore,
        ledger: EventLedgerStore,
        authority: RetentionCapabilityAuthority
    ) throws -> ResearchHandoffAdapter {
        ResearchHandoffAdapter(
            honeycomb: honeycomb,
            ledger: ledger,
            capabilityRegistry: try RetentionCapabilityRegistry(path: ":memory:"),
            recoveryJournal: try HandoffRecoveryJournal(path: ":memory:"),
            approvalAuthority: authority
        )
    }

    private func makePayload(
        timestamp: Any = "1725000000000",
        retentionClass: String = "session",
        deletionScope: String = "this_source",
        expiresAt: Any? = nil
    ) throws -> Data {
        let body = Data("verified research body".utf8)
        let hash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        var retention: [String: Any] = [
            "class": retentionClass,
            "deletion_scope": deletionScope
        ]
        if let expiresAt { retention["expires_at_unix_ms"] = expiresAt }
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
                "retrieved_at_unix_ms": timestamp,
                "content_hash_sha256": hash,
                "body_base64": body.base64EncodedString(),
                "capture_method": "swarm-research"
            ],
            "retention": retention,
            "extraction": "not_extracted",
            "citation_ready": false
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func makeCapability(
        retentionClass: String,
        deletionScope: String,
        projectID: String? = "project-1",
        provenance: String = "rust-research-boundary",
        issuedAt: Date = Date().addingTimeInterval(-1),
        expiresAt: Date = Date().addingTimeInterval(60),
        sourceContentHash: String? = nil,
        sign: Bool = true
    ) -> RetentionCapability {
        let body = Data("verified research body".utf8)
        let hash = sourceContentHash ?? SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let unsigned = RetentionCapability(
            issuerID: "test-approval-controller",
            retentionClass: retentionClass,
            deletionScope: deletionScope,
            sourceContentHash: hash,
            projectID: projectID,
            provenance: provenance,
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
        guard sign else { return unsigned }
        return try! makeAuthority().issue(unsigned)
    }

    @Test func validPayloadPersistsSourceAndFullTransportMetadata() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)
        let result = try await adapter.ingest(
            json: try makePayload(
                retentionClass: "project",
                deletionScope: "provenance",
                expiresAt: "1800000000000"
            ),
            sessionID: "session-1",
            projectID: "project-1",
            retentionCapability: makeCapability(
                retentionClass: "project",
                deletionScope: "provenance"
            )
        )

        #expect(result.rawBodyRetained == false)
        #expect(result.wasDeduplicated == false)
        #expect(result.source.url == "https://example.com/final")
        #expect(result.source.requestedURL == "https://example.com/start")
        #expect(result.source.redirectCount == 1)
        #expect(result.source.httpStatus == 200)
        #expect(result.source.contentType == "text/html")
        #expect(result.source.bodySize == Data("verified research body".utf8).count)
        #expect(result.source.retrievedAtUnixMS == "1725000000000")
        #expect(result.source.retentionClass == "project")
        #expect(result.source.deletionScope == "provenance")
        #expect(result.source.expiresAtUnixMS == "1800000000000")
        #expect(result.source.extractionState == "not_extracted")
        #expect(result.source.citationReady == false)

        let events = try await ledger.getEvents(byActionKind: .research)
        #expect(events.count == 1)
        #expect(events[0].contextIDs == [result.source.id])
        #expect(events[0].sessionID == "session-1")
        #expect(events[0].projectID == "project-1")
        #expect(events[0].trustLevel == .t2)
        #expect(events[0].verificationResult == .verified)
        #expect(events[0].outputSummary?.contains("status=200") == true)
        #expect(events[0].outputSummary?.contains("deletion_scope=provenance") == true)
    }

    @Test func durableRetentionRequiresExplicitApproval() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)

        await #expect(throws: ResearchHandoffAdapter.AdapterError.durableRetentionRequiresApproval) {
            _ = try await adapter.ingest(
                json: try makePayload(retentionClass: "project", deletionScope: "project")
            )
        }
        #expect(try await honeycomb.countNodes(type: .source) == 0)
        #expect(try await ledger.countEvents(actionKind: .research) == 0)
    }

    @Test func expiredCapabilityIsRejectedBeforePersistence() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)
        let expired = makeCapability(
            retentionClass: "project",
            deletionScope: "project",
            issuedAt: Date().addingTimeInterval(-120),
            expiresAt: Date().addingTimeInterval(-60),
            sign: false
        )

        await #expect(throws: ResearchHandoffAdapter.AdapterError.capabilityExpired) {
            _ = try await adapter.ingest(
                json: try makePayload(retentionClass: "project", deletionScope: "project"),
                projectID: "project-1",
                retentionCapability: expired
            )
        }
        #expect(try await honeycomb.countNodes(type: .source) == 0)
        #expect(try await ledger.countEvents(actionKind: .research) == 0)
    }

    @Test func capabilityBindingRejectsWrongScopeProjectOrHash() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)
        let wrongScope = makeCapability(retentionClass: "project", deletionScope: "this_source")

        await #expect(throws: ResearchHandoffAdapter.AdapterError.capabilityMismatch) {
            _ = try await adapter.ingest(
                json: try makePayload(retentionClass: "project", deletionScope: "provenance"),
                projectID: "project-1",
                retentionCapability: wrongScope
            )
        }

        let wrongProject = makeCapability(retentionClass: "project", deletionScope: "provenance", projectID: "other-project")
        await #expect(throws: ResearchHandoffAdapter.AdapterError.capabilityMismatch) {
            _ = try await adapter.ingest(
                json: try makePayload(retentionClass: "project", deletionScope: "provenance"),
                projectID: "project-1",
                retentionCapability: wrongProject
            )
        }

        let wrongHash = makeCapability(
            retentionClass: "project",
            deletionScope: "provenance",
            sourceContentHash: String(repeating: "a", count: 64)
        )
        await #expect(throws: ResearchHandoffAdapter.AdapterError.capabilityMismatch) {
            _ = try await adapter.ingest(
                json: try makePayload(retentionClass: "project", deletionScope: "provenance"),
                projectID: "project-1",
                retentionCapability: wrongHash
            )
        }
        #expect(try await honeycomb.countNodes(type: .source) == 0)
        #expect(try await ledger.countEvents(actionKind: .research) == 0)
    }

    @Test func capabilityIsSingleUseAndConsentIsAudited() async throws {
        let (honeycomb, ledger) = try makeStores()
        let registry = try RetentionCapabilityRegistry(path: ":memory:")
        let adapter = ResearchHandoffAdapter(
            honeycomb: honeycomb,
            ledger: ledger,
            capabilityRegistry: registry,
            recoveryJournal: try HandoffRecoveryJournal(path: ":memory:"),
            approvalAuthority: try makeAuthority()
        )
        let capability = makeCapability(retentionClass: "project", deletionScope: "provenance")
        let payload = try makePayload(retentionClass: "project", deletionScope: "provenance")

        let result = try await adapter.ingest(
            json: payload,
            projectID: "project-1",
            retentionCapability: capability
        )
        #expect(result.source.id.isEmpty == false)
        let events = try await ledger.getEvents(byActionKind: .research)
        #expect(events.first?.consentState == .approved)
        #expect(events.first?.outputSummary?.contains("approval_nonce=\(capability.nonce)") == true)
        #expect(try await registry.consumedCount() == 1)

        await #expect(throws: ResearchHandoffAdapter.AdapterError.capabilityReplayed) {
            _ = try await adapter.ingest(
                json: payload,
                projectID: "project-1",
                retentionCapability: capability
            )
        }
        #expect(try await ledger.countEvents(actionKind: .research) == 1)
    }

    @Test func legacyNumericTimestampIsAcceptedWithoutPrecisionLossInWireValue() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)
        let result = try await adapter.ingest(json: try makePayload(timestamp: 1_725_000_000_000))

        #expect(result.source.retrievedAtUnixMS == "1725000000000")
        #expect(result.source.retrievalTimestamp.timeIntervalSince1970 == 1_725_000_000)
    }

    @Test func tamperedBodyIsRejectedBeforeEitherStoreIsTouched() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)
        var object = try JSONSerialization.jsonObject(with: makePayload()) as! [String: Any]
        var source = object["source"] as! [String: Any]
        source["body_base64"] = Data("tampered body".utf8).base64EncodedString()
        object["source"] = source
        let tampered = try JSONSerialization.data(withJSONObject: object)

        do {
            _ = try await adapter.ingest(json: tampered)
            Issue.record("tampered body unexpectedly ingested")
        } catch let error as ResearchHandoffAdapter.AdapterError {
            guard case .invalidDocument(let message) = error else {
                Issue.record("unexpected adapter error: \(error)")
                return
            }
            #expect(message.contains("content hash"))
        }
        #expect(try await honeycomb.countNodes(type: .source) == 0)
        #expect(try await ledger.countEvents(actionKind: .research) == 0)
    }

    @Test func privateContentFailsClosedWithoutPersistence() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)

        do {
            _ = try await adapter.ingest(json: try makePayload(), privacy: .privateBrowsing)
            Issue.record("private content unexpectedly ingested")
        } catch let error as ResearchHandoffAdapter.AdapterError {
            #expect(error == .privateContentNotSupported)
        }
        #expect(try await honeycomb.countNodes(type: .source) == 0)
        #expect(try await ledger.countEvents(actionKind: .research) == 0)
    }

    @Test func duplicateContentReusesSourceButCreatesSecondAuditEvent() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)
        let payload = try makePayload()

        let first = try await adapter.ingest(json: payload)
        let second = try await adapter.ingest(json: payload, sessionID: "second-session")

        #expect(first.source.id == second.source.id)
        #expect(first.wasDeduplicated == false)
        #expect(second.wasDeduplicated == true)
        #expect(try await honeycomb.countNodes(type: .source) == 1)
        let events = try await ledger.getEvents(byActionKind: .research)
        #expect(events.count == 2)
        #expect(events.contains { $0.sessionID == "second-session" })
        let secondEvent = events.first { $0.sessionID == "second-session" }
        #expect(secondEvent?.outputSummary?.contains("content-addressed source reused") == true)
    }

    @Test func omittedExpiryIsAcceptedAndStoredAsNil() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)
        let result = try await adapter.ingest(json: try makePayload())
        #expect(result.source.expiresAtUnixMS == nil)
        #expect(try await ledger.countEvents(actionKind: .research) == 1)
    }

    @Test func explicitNullExpiryIsAcceptedAsNoExpiry() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)
        var object = try JSONSerialization.jsonObject(with: makePayload()) as! [String: Any]
        var retention = object["retention"] as! [String: Any]
        retention["expires_at_unix_ms"] = NSNull()
        object["retention"] = retention

        let result = try await adapter.ingest(
            json: try JSONSerialization.data(withJSONObject: object)
        )
        #expect(result.source.expiresAtUnixMS == nil)
        #expect(try await ledger.countEvents(actionKind: .research) == 1)
    }

    @Test func recoveryJournalRejectsSourceWithoutCanonicalHash() async throws {
        let journal = try HandoffRecoveryJournal(path: ":memory:")
        let source = Source(
            id: "source-no-hash",
            url: "https://example.com/no-hash",
            provenance: "rust-research-boundary"
        )
        let event = EventLedgerStore.LedgerEvent(
            id: "event-no-hash",
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

        await #expect(throws: HandoffRecoveryJournal.JournalError.malformedRecord("source content hash must be a lowercase SHA-256")) {
            try await journal.append(.init(source: source, event: event))
        }
        #expect(try await journal.count() == 0)
    }

    @Test func recoveryJournalRedactsPageProseButPreservesRepairMetadata() async throws {
        let journal = try HandoffRecoveryJournal(path: ":memory:")
        let source = Source(
            id: "source-redacted",
            url: "https://example.com/redacted",
            title: "Research title",
            contentHash: String(repeating: "c", count: 64),
            snippet: "private snippet must not persist",
            extractedText: "private extracted page prose must not persist",
            provenance: "rust-research-boundary",
            requestedURL: "https://example.com/requested",
            httpStatus: 200,
            bodySize: 123,
            retrievedAtUnixMS: "1725000000000",
            retentionClass: "session",
            deletionScope: "this_source"
        )
        let event = EventLedgerStore.LedgerEvent(
            id: "event-redacted",
            actor: "research-boundary",
            intent: "Persist verified research source handoff",
            actionKind: .research,
            actionTarget: source.url,
            trustLevel: .t2,
            policyDecision: .allowed,
            consentState: .notRequired,
            contextIDs: [source.id],
            outputSummary: "metadata-only",
            result: .success,
            verificationResult: .verified,
            provenance: "rust-research-boundary"
        )
        try await journal.append(.init(source: source, event: event))
        let pending = try await journal.pending()
        #expect(pending.count == 1)
        #expect(pending[0].source.snippet == nil)
        #expect(pending[0].source.extractedText == nil)
        #expect(pending[0].source.contentHash == source.contentHash)
        #expect(pending[0].source.url == source.url)
        #expect(pending[0].event.id == event.id)
    }

    @Test func successfulIngestClearsRecoveryJournal() async throws {
        let (honeycomb, ledger) = try makeStores()
        let journal = try HandoffRecoveryJournal(path: ":memory:")
        let adapter = ResearchHandoffAdapter(
            honeycomb: honeycomb,
            ledger: ledger,
            capabilityRegistry: try RetentionCapabilityRegistry(path: ":memory:"),
            recoveryJournal: journal,
            approvalAuthority: try makeAuthority()
        )

        _ = try await adapter.ingest(json: try makePayload())
        #expect(try await journal.count() == 0)
        #expect(try await journal.pending().isEmpty)
    }

    @Test func reconciliationRepairsSourceWithoutLedgerEventAndIsIdempotent() async throws {
        let (honeycomb, ledger) = try makeStores()
        let journal = try HandoffRecoveryJournal(path: ":memory:")
        let adapter = ResearchHandoffAdapter(
            honeycomb: honeycomb,
            ledger: ledger,
            capabilityRegistry: try RetentionCapabilityRegistry(path: ":memory:"),
            recoveryJournal: journal,
            approvalAuthority: try makeAuthority()
        )
        let body = Data("verified research body".utf8)
        let source = Source(
            id: "source-recovery",
            url: "https://example.com/final",
            captureMethod: "swarm-research",
            contentHash: SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined(),
            provenance: "rust-research-boundary",
            requestedURL: "https://example.com/start",
            redirectCount: 1,
            httpStatus: 200,
            contentType: "text/html",
            bodySize: body.count,
            retrievedAtUnixMS: "1725000000000",
            retentionClass: "session",
            deletionScope: "this_source",
            extractionState: "not_extracted",
            citationReady: false
        )
        let event = EventLedgerStore.LedgerEvent(
            id: "event-recovery",
            actor: "research-boundary",
            intent: "Persist verified research source handoff",
            actionKind: .research,
            actionTarget: source.requestedURL ?? source.url,
            trustLevel: .t2,
            policyDecision: .allowed,
            consentState: .notRequired,
            contextIDs: [source.id],
            result: .success,
            verificationResult: .verified,
            provenance: "rust-research-boundary"
        )
        try await journal.append(.init(source: source, event: event))
        _ = try await honeycomb.createSource(source)
        #expect(try await ledger.getEvent(id: event.id) == nil)
        #expect(try await journal.count() == 1)

        let first = try await adapter.reconcilePending()
        #expect(first.count == 1)
        #expect(first[0].outcome == .repaired)
        #expect(first[0].sourceID == source.id)
        #expect(first[0].ledgerEventID == event.id)
        #expect(try await ledger.countEvents(actionKind: .research) == 1)
        #expect(try await journal.count() == 0)

        let second = try await adapter.reconcilePending()
        #expect(second.isEmpty)
        #expect(try await ledger.countEvents(actionKind: .research) == 1)
    }

    @Test func reconciliationAdoptsExistingAuditWithoutDuplicatingIt() async throws {
        let (honeycomb, ledger) = try makeStores()
        let journal = try HandoffRecoveryJournal(path: ":memory:")
        let adapter = ResearchHandoffAdapter(
            honeycomb: honeycomb,
            ledger: ledger,
            capabilityRegistry: try RetentionCapabilityRegistry(path: ":memory:"),
            recoveryJournal: journal,
            approvalAuthority: try makeAuthority()
        )
        let source = Source(
            id: "source-complete",
            url: "https://example.com/complete",
            contentHash: String(repeating: "b", count: 64),
            provenance: "rust-research-boundary"
        )
        let stored = try await honeycomb.createSource(source)
        let event = EventLedgerStore.LedgerEvent(
            id: "event-complete",
            actor: "research-boundary",
            intent: "Persist verified research source handoff",
            actionKind: .research,
            actionTarget: source.url,
            trustLevel: .t2,
            policyDecision: .allowed,
            consentState: .notRequired,
            contextIDs: [stored.id],
            result: .success,
            verificationResult: .verified,
            provenance: "rust-research-boundary"
        )
        try await ledger.record(event)
        try await journal.append(.init(source: source, event: event))

        let results = try await adapter.reconcilePending()
        #expect(results.count == 1)
        #expect(results[0].outcome == .alreadyComplete)
        #expect(try await ledger.countEvents(actionKind: .research) == 1)
        #expect(try await journal.count() == 0)
    }

    @Test func deletionMetadataSurvivesAndSourceCanBeExplicitlyDeleted() async throws {
        let (honeycomb, ledger) = try makeStores()
        let authority = try makeAuthority()
        let adapter = try makeAdapter(honeycomb: honeycomb, ledger: ledger, authority: authority)
        let result = try await adapter.ingest(
            json: try makePayload(retentionClass: "ephemeral", deletionScope: "this_source")
        )

        #expect(result.source.retentionClass == "ephemeral")
        #expect(result.source.deletionScope == "this_source")
        #expect(try await honeycomb.deleteSource(id: result.source.id))
        #expect(try await honeycomb.getSource(id: result.source.id) == nil)
        // Deleting knowledge does not silently rewrite the append-only audit.
        #expect(try await ledger.countEvents(actionKind: .research) == 1)
    }
}
