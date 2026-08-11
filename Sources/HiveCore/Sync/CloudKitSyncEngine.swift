import CloudKit
import CryptoKit
import Foundation

// MARK: - CloudKit Sync Engine (v1.0 foundation)
//
// Cross-device sync for tabs, bookmarks, and history via CloudKit private database.
// Last-write-wins conflict resolution with client-side timestamps.
//
// P3.4 E2E: content is stored exclusively as an AES-GCM envelope in a single
// opaque `payload` field — the server sees record IDs and revisions, never
// URLs or titles. Legacy plaintext convenience methods remain for migration
// but new writes should go through `saveEnvelope`.
//
// Usage:
//   let engine = CloudKitSyncEngine(containerIdentifier: "iCloud.com.hive.browser")
//   engine.setupSubscription()
//   try await engine.saveEnvelope(payload, key: syncKey)
//   let payloads = try await engine.fetchEnvelopes(kind: .tab, key: syncKey)

public actor CloudKitSyncEngine {
    public enum SaveConflict: Error {
        case remoteRevisionWins
    }

    public struct EnvelopeFetchReport: Sendable {
        public let payloads: [SyncPayload]
        public let rejectedCount: Int

        public init(payloads: [SyncPayload], rejectedCount: Int) {
            self.payloads = payloads
            self.rejectedCount = rejectedCount
        }
    }

    public enum RecordType: String, Sendable {
        case tab = "BrowserTab"
        case bookmark = "Bookmark"
        case historyItem = "HistoryItem"
    }

    private let container: CKContainer
    private let database: CKDatabase
    private var isSubscribed = false

    /// Creates an engine for an explicitly configured CloudKit container.
    /// The identifier is required so callers cannot accidentally invoke
    /// `CKContainer.default()` in an unentitled/local-only bundle.
    public init(containerIdentifier: String) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
    }

    // MARK: - Subscription

    public func setupSubscription() async throws {
        guard !isSubscribed else { return }
        let subscriptionID = "hive-private-db-changes"
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        _ = try await database.save(subscription)
        isSubscribed = true
    }

    // MARK: - E2E envelopes (P3.4)

    /// Applies the encrypted-only record shape. Kept as a small seam so the
    /// privacy boundary can be tested without contacting CloudKit.
    static func applyOpaqueEnvelope(_ ciphertext: Data, revision: UInt64, to record: CKRecord) {
        record["payload"] = ciphertext as CKRecordValue
        record["revision"] = revision as CKRecordValue
        record["url"] = nil
        record["title"] = nil
        record["visitedAt"] = nil
        record["updatedAt"] = nil
    }

    /// Saves a payload as a single encrypted `payload` field. The `revision`
    /// is mirrored as an unencrypted query hint so ordering is server-visible
    /// without leaking content. The conditional save policy refuses to
    /// overwrite a record that another device changed after this client last
    /// observed it; the caller retains the local outbox entry for a later pull
    /// and conflict-resolution retry.
    public func saveEnvelope(_ payload: SyncPayload, key: SymmetricKey) async throws {
        let recordID = CKRecord.ID(recordName: payload.recordID)
        let type = recordType(for: payload.kind)
        let record: CKRecord
        do {
            // Preserve the server change tag for conditional updates. A newly
            // reconstructed record has no tag and cannot safely update an
            // existing peer record with `.ifServerRecordUnchanged`.
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: type, recordID: recordID)
        }

        let cipher = SyncCipher()
        if let remoteData = record["payload"] as? Data {
            // Do not let a retry adopt a newer change tag and overwrite a
            // newer peer revision. Pull/conflict resolution must decide first.
            guard let remote = try? cipher.decrypt(remoteData, with: key) else {
                throw SyncEnvelopeSaveError.opaqueRemoteRecord
            }
            guard SyncOutboxPolicy.shouldUpload(local: payload, remote: remote) else {
                throw SaveConflict.remoteRevisionWins
            }
        }
        let ciphertext = try cipher.encrypt(payload, with: key)
        // Clear legacy plaintext fields on every encrypted write, including
        // records that predate the envelope migration. The cloud must never
        // retain URLs, titles, or visit dates beside the opaque payload.
        Self.applyOpaqueEnvelope(ciphertext, revision: payload.revision, to: record)
        let (saveResults, _) = try await database.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
            atomically: true
        )
        guard let result = saveResults[recordID] else {
            throw SyncEnvelopeSaveError.missingResult
        }
        _ = try result.get()
    }

    private enum SyncEnvelopeSaveError: Error {
        case missingResult
        case opaqueRemoteRecord
    }

    /// Migrates legacy plaintext records in place. Existing rows are read once,
    /// encrypted into `payload`, then their URL/title/date fields are cleared
    /// before save. New app versions never write those fields again.
    public func migrateLegacyPlaintextRecords(key: SymmetricKey, deviceID: String) async throws -> Int {
        var migrated = 0
        let cipher = SyncCipher()
        for kind in SyncPayload.Kind.allCases {
            let query = CKQuery(recordType: recordType(for: kind), predicate: NSPredicate(value: true))
            let (results, _) = try await database.records(matching: query, resultsLimit: 1000)
            for result in results {
                let record = try result.1.get()
                let existingPayload = record["payload"] as? Data
                let url = record["url"] as? String
                let title = record["title"] as? String
                let visitedAt = record["visitedAt"] as? Date
                let updatedAt = record["updatedAt"] as? Date ?? Date()

                // A partially completed migration may already have an
                // encrypted payload while legacy fields remain. Reuse the
                // authenticated payload in that case and still clear the
                // plaintext fields; this makes retries idempotent and closes
                // the mixed-record window after a transient CloudKit failure.
                let decodedPayload = existingPayload.flatMap { try? cipher.decrypt($0, with: key) }
                let payload: SyncPayload
                if let decodedPayload {
                    payload = decodedPayload
                } else {
                    // Never overwrite an opaque envelope that cannot be
                    // authenticated with the current key. It may belong to
                    // another iCloud-Keychain identity or be tampered with;
                    // legacy fields are not a safe recovery source.
                    guard existingPayload == nil, let url else { continue }
                    payload = SyncPayload(
                        kind: kind,
                        recordID: record.recordID.recordName,
                        revision: (record["revision"] as? Int64).map { UInt64(max(0, $0)) } ?? 1,
                        updatedAt: updatedAt,
                        deviceID: deviceID,
                        url: url,
                        title: title,
                        visitedAt: visitedAt
                    )
                }

                let hasLegacyFields = url != nil || title != nil || visitedAt != nil || record["updatedAt"] != nil
                let hasEnvelope = existingPayload != nil
                guard !hasEnvelope || hasLegacyFields else { continue }
                record["payload"] = try cipher.encrypt(payload, with: key) as CKRecordValue
                record["revision"] = payload.revision as CKRecordValue
                record["url"] = nil
                record["title"] = nil
                record["visitedAt"] = nil
                record["updatedAt"] = nil
                _ = try await database.save(record)
                migrated += 1
            }
        }
        return migrated
    }

    /// Fetches and decrypts every envelope of a kind. Authentication failures
    /// are counted so the caller can surface key mismatch/tampering instead of
    /// silently treating rejected records as an empty database.
    public func fetchEnvelopeReport(kind: SyncPayload.Kind, key: SymmetricKey) async throws -> EnvelopeFetchReport {
        let query = CKQuery(
            recordType: recordType(for: kind),
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "revision", ascending: false)]
        let (results, _) = try await database.records(matching: query, resultsLimit: 1000)
        let cipher = SyncCipher()
        var payloads: [SyncPayload] = []
        var rejectedCount = 0
        for result in results {
            guard let record = try? result.1.get(),
                  let data = record["payload"] as? Data,
                  let payload = try? cipher.decrypt(data, with: key) else {
                rejectedCount += 1
                continue
            }
            payloads.append(payload)
        }
        return EnvelopeFetchReport(payloads: payloads, rejectedCount: rejectedCount)
    }

    public func fetchEnvelopes(kind: SyncPayload.Kind, key: SymmetricKey) async throws -> [SyncPayload] {
        try await fetchEnvelopeReport(kind: kind, key: key).payloads
    }

    private func recordType(for kind: SyncPayload.Kind) -> String {
        switch kind {
        case .tab: return RecordType.tab.rawValue
        case .bookmark: return RecordType.bookmark.rawValue
        case .history: return RecordType.historyItem.rawValue
        }
    }

    // MARK: - Conflict resolution

    /// All writes use encrypted envelopes. The former plaintext
    /// `saveWithConflictResolution` surface was intentionally removed so a
    /// caller cannot accidentally reintroduce URL/title fields into CloudKit.


    // MARK: - Account status

    public func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
}
