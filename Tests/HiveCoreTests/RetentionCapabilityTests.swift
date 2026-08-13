import CryptoKit
import Foundation
import Testing
@testable import HiveCore

@Suite("RetentionCapability")
struct RetentionCapabilityTests {
    private let hash = String(repeating: "a", count: 64)

    private func capability(
        nonce: String = "grant-1",
        issuedAt: Date = Date(timeIntervalSince1970: 1_000),
        expiresAt: Date = Date(timeIntervalSince1970: 2_000)
    ) -> RetentionCapability {
        RetentionCapability(
            nonce: nonce,
            retentionClass: "project",
            deletionScope: "provenance",
            sourceContentHash: hash,
            projectID: "project-1",
            provenance: "rust-research-boundary",
            issuedAt: issuedAt,
            expiresAt: expiresAt
        )
    }

    private func liveCapability(
        issuerID: String = "test-approval-controller",
        signature: String? = nil,
        keyVersion: Int? = nil,
        projectID: String? = "project-1"
    ) -> RetentionCapability {
        RetentionCapability(
            nonce: "live-grant",
            issuerID: issuerID,
            signature: signature,
            keyVersion: keyVersion,
            retentionClass: "project",
            deletionScope: "provenance",
            sourceContentHash: hash,
            projectID: projectID,
            provenance: "rust-research-boundary",
            issuedAt: Date().addingTimeInterval(-1),
            expiresAt: Date().addingTimeInterval(60)
        )
    }

    private func makeTestAuthority(
        keyByte: UInt8 = 7,
        issuerID: String = "test-approval-controller"
    ) throws -> RetentionCapabilityAuthority {
        try RetentionCapabilityAuthority(
            key: SymmetricKey(data: Data(repeating: keyByte, count: 32)),
            issuerID: issuerID
        )
    }

    @Test func validatesScopedCapabilityShape() throws {
        try capability().validate(at: Date(timeIntervalSince1970: 1_500))
        #expect(capability().action == "research_source.persist")
    }

    @Test func randomAuthorityStartsAtVersionOne() throws {
        let authority = try RetentionCapabilityAuthority.random(issuerID: "test-approval-controller")
        #expect(authority.keyVersion == 1)
        let signed = try authority.issue(liveCapability())
        #expect(signed.keyVersion == 1)
    }

    @Test func authoritySignsAndVerifiesCanonicalClaimsAfterCodableRoundTrip() throws {
        let authority = try makeTestAuthority()
        let signed = try authority.issue(liveCapability())
        #expect(signed.signature?.isEmpty == false)
        try authority.verify(signed)

        let encoded = try JSONEncoder().encode(signed)
        let decoded = try JSONDecoder().decode(RetentionCapability.self, from: encoded)
        try authority.verify(decoded)
    }

    @Test func authorityRejectsMutationWrongKeyIssuerAndMissingSignature() throws {
        let authority = try makeTestAuthority()
        let signed = try authority.issue(liveCapability())
        let mutated = RetentionCapability(
            nonce: signed.nonce,
            issuerID: signed.issuerID,
            signature: signed.signature,
            keyVersion: signed.keyVersion,
            retentionClass: signed.retentionClass,
            deletionScope: signed.deletionScope,
            sourceContentHash: signed.sourceContentHash,
            projectID: "different-project",
            provenance: signed.provenance,
            issuedAt: signed.issuedAt,
            expiresAt: signed.expiresAt
        )
        #expect(throws: RetentionCapabilityError.signatureInvalid) {
            try authority.verify(mutated)
        }

        let otherKeyAuthority = try makeTestAuthority(keyByte: 8)
        #expect(throws: RetentionCapabilityError.signatureInvalid) {
            try otherKeyAuthority.verify(signed)
        }

        let wrongIssuer = RetentionCapability(
            nonce: signed.nonce,
            issuerID: "other-issuer",
            signature: signed.signature,
            retentionClass: signed.retentionClass,
            deletionScope: signed.deletionScope,
            sourceContentHash: signed.sourceContentHash,
            projectID: signed.projectID,
            provenance: signed.provenance,
            issuedAt: signed.issuedAt,
            expiresAt: signed.expiresAt
        )
        #expect(throws: RetentionCapabilityError.issuerMismatch) {
            try authority.verify(wrongIssuer)
        }

        #expect(throws: RetentionCapabilityError.signatureMissing) {
            try authority.verify(liveCapability(keyVersion: authority.keyVersion))
        }
    }

    @Test func rejectsExpiredFutureAndMismatchedCapabilities() {
        #expect(throws: RetentionCapabilityError.expired) {
            try capability(expiresAt: Date(timeIntervalSince1970: 1_400))
                .validate(at: Date(timeIntervalSince1970: 1_500))
        }
        #expect(throws: RetentionCapabilityError.self) {
            try capability(issuedAt: Date(timeIntervalSince1970: 1_600))
                .validate(at: Date(timeIntervalSince1970: 1_500))
        }
        #expect(throws: RetentionCapabilityError.self) {
            try RetentionCapability(
                nonce: "grant-2",
                action: "other.action",
                retentionClass: "project",
                deletionScope: "provenance",
                sourceContentHash: hash,
                projectID: "project-1",
                provenance: "rust-research-boundary",
                issuedAt: Date(timeIntervalSince1970: 1_000),
                expiresAt: Date(timeIntervalSince1970: 2_000)
            ).validate(at: Date(timeIntervalSince1970: 1_500))
        }
    }

    @Test func registryReservesNonceExactlyOnce() async throws {
        let registry = try RetentionCapabilityRegistry(path: ":memory:")
        try await registry.reserve("nonce-1")
        await #expect(throws: RetentionCapabilityError.replayed) {
            try await registry.reserve("nonce-1")
        }
        #expect(try await registry.consumedCount() == 1)
    }

    @Test func registryReleaseAllowsRetryBeforePersistence() async throws {
        let registry = try RetentionCapabilityRegistry(path: ":memory:")
        try await registry.reserve("nonce-2")
        try await registry.release("nonce-2")
        try await registry.reserve("nonce-2")
        #expect(try await registry.consumedCount() == 1)
    }

    @Test func registryBindsApprovalToOneJournalAndEvent() async throws {
        let registry = try RetentionCapabilityRegistry(path: ":memory:")
        try await registry.reserve("bound-nonce")
        try await registry.bind("bound-nonce", journalID: "journal-1", eventID: "event-1")
        try await registry.bind("bound-nonce", journalID: "journal-1", eventID: "event-1")
        #expect(try await registry.binding(for: "bound-nonce") == .init(journalID: "journal-1", eventID: "event-1"))
        await #expect(throws: RetentionCapabilityError.bindingConflict) {
            try await registry.bind("bound-nonce", journalID: "journal-2", eventID: "event-1")
        }
        await #expect(throws: RetentionCapabilityError.bindingConflict) {
            try await registry.bind("unreserved", journalID: "journal-1", eventID: "event-1")
        }
    }

    @Test func registryPersistsReplayProtectionAcrossRestart() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-retention-\(UUID().uuidString).sqlite")
            .path
        defer { try? FileManager.default.removeItem(atPath: path) }

        do {
            let first = try RetentionCapabilityRegistry(path: path)
            try await first.reserve("restart-nonce")
            #expect(try await first.consumedCount() == 1)
        }

        let second = try RetentionCapabilityRegistry(path: path)
        await #expect(throws: RetentionCapabilityError.replayed) {
            try await second.reserve("restart-nonce")
        }
    }

    @Test func registryAllowsOnlyOneConcurrentReservation() async throws {
        let registry = try RetentionCapabilityRegistry(path: ":memory:")
        let successes = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    do {
                        try await registry.reserve("racing-nonce")
                        return true
                    } catch {
                        return false
                    }
                }
            }
            var count = 0
            for await success in group where success {
                count += 1
            }
            return count
        }
        #expect(successes == 1)
        #expect(try await registry.consumedCount() == 1)
    }
}
