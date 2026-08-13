import CloudKit
import CryptoKit
import Foundation
import Testing
@testable import HiveCore

@Suite("CloudKitEnvelopePrivacy")
struct CloudKitEnvelopePrivacyTests {
    @Test("opaque encrypted envelope clears legacy plaintext fields")
    func legacyFieldsAreCleared() throws {
        let record = CKRecord(recordType: "Bookmark", recordID: CKRecord.ID(recordName: "bookmark-1"))
        record["url"] = "https://private.example" as CKRecordValue
        record["title"] = "Private title" as CKRecordValue
        record["visitedAt"] = Date() as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        let key = SyncCipher.makeKey()
        let payload = SyncPayload(
            kind: .bookmark,
            recordID: "bookmark-1",
            revision: 7,
            deviceID: "device-a",
            url: "https://private.example",
            title: "Private title"
        )
        let ciphertext = try SyncCipher().encrypt(payload, with: key)
        CloudKitSyncEngine.applyOpaqueEnvelope(ciphertext, revision: payload.revision, to: record)

        #expect(record["payload"] as? Data == ciphertext)
        #expect(record["revision"] as? Int64 == 7)
        #expect(record["url"] == nil)
        #expect(record["title"] == nil)
        #expect(record["visitedAt"] == nil)
        #expect(record["updatedAt"] == nil)
        #expect(try SyncCipher().decrypt(ciphertext, with: key) == payload)
    }
}
