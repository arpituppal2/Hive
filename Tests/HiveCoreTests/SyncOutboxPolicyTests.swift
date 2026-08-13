import Foundation
import Testing
@testable import HiveCore

@Suite("SyncOutboxPolicy")
struct SyncOutboxPolicyTests {

    @Test func privilegedBridgeActionsAreShellOnly() {
        let shell = "shell-token"
        #expect(WebChromeAuthorizationPolicy.allowsPrivilegedAction(token: shell, shellToken: shell))
        #expect(!WebChromeAuthorizationPolicy.allowsPrivilegedAction(token: "normal-token", shellToken: shell))
        #expect(!WebChromeAuthorizationPolicy.allowsPrivilegedAction(token: "private-token", shellToken: shell))
        #expect(!WebChromeAuthorizationPolicy.allowsPrivilegedAction(token: "", shellToken: shell))
    }

    @Test func startPageAudienceRemainsDistinct() {
        let audience = { (token: String) in
            WebChromeAuthorizationPolicy.audience(
                token: token,
                shellToken: "shell-token",
                normalToken: "normal-token",
                privateToken: "private-token"
            )
        }
        #expect(audience("shell-token") == .shell)
        #expect(audience("normal-token") == .normalStart)
        #expect(audience("private-token") == .privateStart)
        #expect(audience("attacker") == nil)
    }
    private let bookmarkID = "12345678-1234-1234-1234-123456789012"

    private func payload(revision: UInt64, title: String) -> SyncPayload {
        SyncPayload(
            kind: .bookmark,
            recordID: bookmarkID,
            revision: revision,
            updatedAt: Date(timeIntervalSince1970: TimeInterval(revision)),
            deviceID: "device-a",
            url: "https://example.com",
            title: title
        )
    }

    @Test("current snapshot may be uploaded")
    func currentSnapshotIsUploadable() {
        let current = payload(revision: 2, title: "new")
        #expect(SyncOutboxPolicy.shouldUpload(snapshot: current, current: current))
    }

    @Test("stale snapshot is rejected when a newer mutation is staged")
    func staleSnapshotIsRejected() {
        let old = payload(revision: 1, title: "old")
        let newer = payload(revision: 2, title: "new")
        #expect(!SyncOutboxPolicy.shouldUpload(snapshot: old, current: newer))
    }

    @Test("missing ledger entry is not uploadable")
    func missingSnapshotIsRejected() {
        let old = payload(revision: 1, title: "old")
        #expect(!SyncOutboxPolicy.shouldUpload(snapshot: old, current: nil))
    }

    @Test("internal Hive tab payloads are never uploadable")
    func internalHiveTabPayloadsAreNeverUploadable() {
        for host in ["start", "brief", "polar"] {
            let internalPayload = SyncPayload(
                kind: .tab,
                recordID: "tab-\(host)",
                revision: 1,
                deviceID: "device-a",
                url: "hive://\(host)",
                title: "Hive UI"
            )
            #expect(SyncOutboxPolicy.isInternalWebChromePayload(internalPayload))
            #expect(!SyncOutboxPolicy.shouldUpload(snapshot: internalPayload, current: internalPayload))
        }
        let normal = SyncPayload(
            kind: .tab,
            recordID: "tab-http",
            revision: 1,
            deviceID: "device-a",
            url: "https://example.com",
            title: "Example"
        )
        #expect(!SyncOutboxPolicy.isInternalWebChromePayload(normal))
        #expect(SyncOutboxPolicy.shouldUpload(snapshot: normal, current: normal))

        let legacyTombstone = SyncPayload(
            kind: .tab,
            recordID: "legacy-polar-tab",
            revision: 2,
            deviceID: "device-a",
            deleted: true
        )
        #expect(SyncOutboxPolicy.isInternalWebChromePayload(
            legacyTombstone,
            knownInternalTabIDs: ["legacy-polar-tab"]
        ))
        #expect(!SyncOutboxPolicy.shouldUpload(
            snapshot: legacyTombstone,
            current: legacyTombstone,
            knownInternalTabIDs: ["legacy-polar-tab"]
        ))
    }

    @Test("newer remote revision blocks stale upload")
    func newerRemoteRevisionBlocksStaleUpload() {
        let local = payload(revision: 2, title: "local")
        let remote = payload(revision: 3, title: "remote")
        #expect(!SyncOutboxPolicy.shouldUpload(local: local, remote: remote))
        #expect(SyncOutboxPolicy.shouldUpload(local: remote, remote: local))
        #expect(SyncOutboxPolicy.shouldUpload(local: local, remote: nil))
    }

    @Test("malformed remote payloads are not locally applicable")
    func malformedRemotePayloadsAreRejected() {
        let valid = payload(revision: 2, title: "valid")
        #expect(SyncOutboxPolicy.isLocallyApplicable(valid))
        #expect(!SyncOutboxPolicy.isLocallyApplicable(SyncPayload(
            kind: .bookmark,
            recordID: "not-a-uuid",
            revision: 2,
            deviceID: "device-a",
            url: "https://example.com",
            title: "bad"
        )))
        #expect(!SyncOutboxPolicy.isLocallyApplicable(SyncPayload(
            kind: .history,
            recordID: UUID().uuidString,
            revision: 2,
            deviceID: "device-a",
            url: "not a URL",
            title: "bad"
        )))
        #expect(!SyncOutboxPolicy.isLocallyApplicable(SyncPayload(
            kind: .tab,
            recordID: "tab-1",
            revision: 2,
            deviceID: "device-a",
            url: "javascript:alert(1)",
            title: "bad"
        )))
        #expect(SyncOutboxPolicy.isLocallyApplicable(SyncPayload(
            kind: .tab,
            recordID: "start-tab",
            revision: 2,
            deviceID: "device-a",
            url: "hive://start",
            title: "The Hive Brief"
        )))
    }

    @Test("only a strict remote winner counts as applied")
    func remoteApplyRequiresStrictWinner() {
        let local = payload(revision: 2, title: "same")
        let newer = payload(revision: 3, title: "newer")
        #expect(!SyncOutboxPolicy.didApplyRemotePayload(remote: local, local: local))
        #expect(SyncOutboxPolicy.didApplyRemotePayload(remote: newer, local: local))
        #expect(SyncOutboxPolicy.didApplyRemotePayload(remote: local, local: nil))
    }

    @Test("all pending conflicts must resolve before clearing")
    func multiplePendingConflictsRemainVisibleUntilAllResolve() {
        let diagnostic = "Encrypted sync conflict pending pull; local outbox retained."
        let pending = Set(["bookmark:bookmark-1", "tab:tab-1"])
        #expect(!SyncOutboxPolicy.shouldClearConflictDiagnostic(
            conflictRecordKeys: pending,
            appliedRecordKeys: ["bookmark:bookmark-1"],
            diagnostic: diagnostic
        ))
        #expect(SyncOutboxPolicy.shouldClearConflictDiagnostic(
            conflictRecordKeys: pending,
            appliedRecordKeys: pending,
            diagnostic: diagnostic
        ))
    }

    @Test("successful flush clears only its own retry diagnostic")
    func failureDiagnosticClearsOnlyWithoutNewerFailure() {
        let diagnostic = "Encrypted sync outbox retained; 1 upload(s) pending retry."
        #expect(SyncOutboxPolicy.shouldClearFailureDiagnostic(
            startingFailureEpoch: 4,
            currentFailureEpoch: 4,
            diagnostic: diagnostic
        ))
        #expect(!SyncOutboxPolicy.shouldClearFailureDiagnostic(
            startingFailureEpoch: 4,
            currentFailureEpoch: 4,
            diagnostic: "Encrypted sync conflict pending pull; local outbox retained."
        ))
        #expect(SyncOutboxPolicy.shouldClearConflictDiagnostic(
            conflictRecordKeys: ["bookmark:bookmark-1"],
            appliedRecordKeys: ["bookmark:bookmark-1"],
            diagnostic: "Encrypted sync conflict pending pull; local outbox retained."
        ))
        #expect(!SyncOutboxPolicy.shouldClearConflictDiagnostic(
            conflictRecordKeys: ["bookmark:bookmark-1"],
            appliedRecordKeys: ["tab:tab-1"],
            diagnostic: "Encrypted sync conflict pending pull; local outbox retained."
        ))
        #expect(!SyncOutboxPolicy.shouldClearConflictDiagnostic(
            conflictRecordKeys: ["bookmark:bookmark-1", "tab:tab-1"],
            appliedRecordKeys: ["bookmark:bookmark-1"],
            diagnostic: "Encrypted sync conflict pending pull; local outbox retained."
        ))
        #expect(!SyncOutboxPolicy.shouldClearFailureDiagnostic(
            startingFailureEpoch: 4,
            currentFailureEpoch: 5,
            diagnostic: diagnostic
        ))
        #expect(!SyncOutboxPolicy.shouldClearFailureDiagnostic(
            startingFailureEpoch: 4,
            currentFailureEpoch: 4,
            diagnostic: "Cloud sync is unavailable"
        ))
    }
}
