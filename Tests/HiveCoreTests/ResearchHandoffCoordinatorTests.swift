import CryptoKit
import Foundation
import Testing
@testable import HiveCore

@Suite("ResearchHandoffCoordinator")
struct ResearchHandoffCoordinatorTests {
    private final class CallRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var fetchedURLs: [URL] = []
        private(set) var fetchPrivateFlags: [Bool] = []
        private(set) var ingestedPayloads: [Data] = []
        private(set) var ingestedPrivacy: [ResearchHandoffAdapter.PrivacyScope] = []
        private(set) var ingestedSessions: [String?] = []
        private(set) var fetchCount = 0
        private(set) var ingestCount = 0

        func recordFetch(url: URL, isPrivate: Bool) {
            lock.lock()
            fetchedURLs.append(url)
            fetchPrivateFlags.append(isPrivate)
            fetchCount += 1
            lock.unlock()
        }

        func recordIngest(
            payload: Data,
            privacy: ResearchHandoffAdapter.PrivacyScope,
            sessionID: String?
        ) {
            lock.lock()
            ingestedPayloads.append(payload)
            ingestedPrivacy.append(privacy)
            ingestedSessions.append(sessionID)
            ingestCount += 1
            lock.unlock()
        }

        func snapshot() -> Snapshot {
            lock.lock()
            defer { lock.unlock() }
            return Snapshot(
                fetchedURLs: fetchedURLs,
                fetchPrivateFlags: fetchPrivateFlags,
                ingestedPayloads: ingestedPayloads,
                ingestedPrivacy: ingestedPrivacy,
                ingestedSessions: ingestedSessions,
                fetchCount: fetchCount,
                ingestCount: ingestCount
            )
        }

        struct Snapshot: Sendable {
            let fetchedURLs: [URL]
            let fetchPrivateFlags: [Bool]
            let ingestedPayloads: [Data]
            let ingestedPrivacy: [ResearchHandoffAdapter.PrivacyScope]
            let ingestedSessions: [String?]
            let fetchCount: Int
            let ingestCount: Int
        }
    }

    private final class MemoryKeychain: HMACKeyMaterialBackend, @unchecked Sendable {
        private let lock = NSLock()
        private var value: Data?

        func read(service: String, account: String, accessGroup: String?) throws -> Data? {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func write(_ data: Data, service: String, account: String, accessGroup: String?) throws {
            lock.lock()
            defer { lock.unlock() }
            if value == nil { value = data }
        }
    }

    private func fetchedSource() -> ResearchWorkerClient.FetchedSource {
        let body = Data("coordinator body".utf8)
        let hash = SHA256.hash(data: body)
            .map { String(format: "%02x", $0) }
            .joined()
        return ResearchWorkerClient.FetchedSource(
            requestID: "coordinator-request",
            requestedURL: "https://example.com/start",
            finalURL: "https://example.com/final",
            status: 200,
            contentType: "text/html",
            redirectCount: 1,
            body: body,
            contentHashSHA256: hash,
            retrievedAtUnixMS: 1_725_000_000_000
        )
    }

    private func ingestedSource() -> ResearchHandoffAdapter.IngestedSource {
        ResearchHandoffAdapter.IngestedSource(
            source: Source(
                id: "source-1",
                url: "https://example.com/final",
                contentHash: String(repeating: "a", count: 64),
                provenance: "rust-research-boundary"
            ),
            ledgerEventID: "event-1",
            rawBodyRetained: false,
            wasDeduplicated: false
        )
    }

    @Test func successfulHandoffUsesNonPrivateSessionRetention() async throws {
        let fetched = fetchedSource()
        let ingested = ingestedSource()
        let recorder = CallRecorder()
        let coordinator = ResearchHandoffCoordinator(
            fetch: { url in
                recorder.recordFetch(url: url, isPrivate: false)
                return fetched
            },
            ingest: { payload, privacy, sessionID in
                recorder.recordIngest(payload: payload, privacy: privacy, sessionID: sessionID)
                return ingested
            }
        )

        let result = try await coordinator.handoff(
            url: URL(string: "https://example.com/start")!,
            sessionID: "session-1"
        )
        let calls = recorder.snapshot()

        #expect(result.fetched == fetched)
        #expect(result.ingested == ingested)
        #expect(calls.fetchedURLs == [URL(string: "https://example.com/start")!])
        #expect(calls.fetchPrivateFlags == [false])
        #expect(calls.ingestedPrivacy == [.nonPrivate])
        #expect(calls.ingestedSessions == ["session-1"])
        #expect(calls.fetchCount == 1)
        #expect(calls.ingestCount == 1)
        let payload = try #require(calls.ingestedPayloads.first)
        let object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let retention = try #require(object["retention"] as? [String: Any])
        #expect(retention["class"] as? String == "session")
        #expect(retention["deletion_scope"] as? String == "this_source")
    }

    @Test func privateBrowsingFailsBeforeFetchOrIngest() async {
        let recorder = CallRecorder()
        let coordinator = ResearchHandoffCoordinator(
            fetch: { url in
                recorder.recordFetch(url: url, isPrivate: false)
                return fetchedSource()
            },
            ingest: { payload, privacy, sessionID in
                recorder.recordIngest(payload: payload, privacy: privacy, sessionID: sessionID)
                return ingestedSource()
            }
        )

        await #expect(throws: ResearchHandoffCoordinator.CoordinatorError.privateBrowsingNotAllowed) {
            _ = try await coordinator.handoff(
                url: URL(string: "https://example.com/private")!,
                isPrivateBrowsing: true
            )
        }
        let calls = recorder.snapshot()
        #expect(calls.fetchCount == 0)
        #expect(calls.ingestCount == 0)
    }

    @Test func credentialedAndNonHTTPURLsFailBeforeFetch() async {
        let recorder = CallRecorder()
        let coordinator = ResearchHandoffCoordinator(
            fetch: { url in
                recorder.recordFetch(url: url, isPrivate: false)
                return fetchedSource()
            },
            ingest: { payload, privacy, sessionID in
                recorder.recordIngest(payload: payload, privacy: privacy, sessionID: sessionID)
                return ingestedSource()
            }
        )

        for url in [
            URL(string: "file:///tmp/private")!,
            URL(string: "https://user:password@example.com/private")!
        ] {
            await #expect(throws: ResearchHandoffCoordinator.CoordinatorError.invalidURL) {
                _ = try await coordinator.handoff(url: url)
            }
        }
        #expect(recorder.snapshot().fetchCount == 0)
    }

    @Test func workerFailureDoesNotReachIngest() async {
        let recorder = CallRecorder()
        let coordinator = ResearchHandoffCoordinator(
            fetch: { _ in
                throw ResearchWorkerClient.ResearchWorkerError.executableUnavailable
            },
            ingest: { payload, privacy, sessionID in
                recorder.recordIngest(payload: payload, privacy: privacy, sessionID: sessionID)
                return ingestedSource()
            }
        )

        await #expect(throws: ResearchWorkerClient.ResearchWorkerError.executableUnavailable) {
            _ = try await coordinator.handoff(url: URL(string: "https://example.com")!)
        }
        #expect(recorder.snapshot().ingestCount == 0)
    }

    @Test func realSupervisorPathPersistsSessionSourceAndAudit() async throws {
        let honeycomb = try HoneycombStore(path: ":memory:")
        let ledger = try EventLedgerStore(path: ":memory:")
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-coordinator-integration-\(UUID().uuidString)")
        let registryPath = root.appendingPathComponent("registry.sqlite3").path
        let journalPath = root.appendingPathComponent("journal.sqlite3").path
        let supervisor = try await ResearchHandoffSupervisor(
            honeycomb: honeycomb,
            ledger: ledger,
            registryPath: registryPath,
            journalPath: journalPath,
            issuerID: "coordinator-test",
            keychainBackend: MemoryKeychain()
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = ResearchHandoffCoordinator(
            fetch: { _ in fetchedSource() },
            ingest: { payload, privacy, sessionID in
                try await supervisor.ingest(
                    json: payload,
                    privacy: privacy,
                    sessionID: sessionID
                )
            }
        )

        let result = try await coordinator.handoff(
            url: URL(string: "https://example.com/start")!,
            sessionID: "integration-session"
        )

        #expect(result.ingested.source.url == "https://example.com/final")
        #expect(result.ingested.rawBodyRetained == false)
        #expect(try await honeycomb.countNodes(type: .source) == 1)
        #expect(try await ledger.countEvents(actionKind: .research) == 1)
        let event = try #require(try await ledger.getEvents(byActionKind: .research).first)
        #expect(event.sessionID == "integration-session")
        #expect(event.verificationResult == .verified)
    }

@Test func nilSessionIDDefaultsToNilIngest() async throws {
        let fetched = fetchedSource()
        let ingested = ingestedSource()
        let recorder = CallRecorder()
        let coordinator = ResearchHandoffCoordinator(
            fetch: { url in
                recorder.recordFetch(url: url, isPrivate: false)
                return fetched
            },
            ingest: { payload, privacy, sessionID in
                recorder.recordIngest(payload: payload, privacy: privacy, sessionID: sessionID)
                return ingested
            }
        )
        let result = try await coordinator.handoff(url: URL(string: "https://example.com")!)
        let calls = recorder.snapshot()
        #expect(calls.ingestedSessions == [nil])
        #expect(result.ingested == ingested)
    }

    @Test func fetchThrowsBeforeIngest() async {
        let recorder = CallRecorder()
        let coordinator = ResearchHandoffCoordinator(
            fetch: { _ in throw ResearchWorkerClient.ResearchWorkerError.executableUnavailable },
            ingest: { payload, privacy, sessionID in
                recorder.recordIngest(payload: payload, privacy: privacy, sessionID: sessionID)
                return ingestedSource()
            }
        )
        await #expect(throws: ResearchWorkerClient.ResearchWorkerError.self) {
            _ = try await coordinator.handoff(url: URL(string: "https://example.com")!)
        }
        #expect(recorder.snapshot().ingestCount == 0)
    }
}
