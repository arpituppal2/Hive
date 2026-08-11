import Testing
import CryptoKit
import Foundation
@testable import HiveCore

// MARK: - SyncCipher Tests (P3.4 E2E envelope)

struct SyncCipherTests {

    private func samplePayload(
        recordID: String = "tab-1",
        revision: UInt64 = 7,
        deviceID: String = "device-a",
        url: String = "https://example.com/private/page",
        title: String = "Confidential"
    ) -> SyncPayload {
        SyncPayload(
            kind: .tab,
            recordID: recordID,
            revision: revision,
            deviceID: deviceID,
            url: url,
            title: title
        )
    }

    @Test("encrypt then decrypt round-trips the payload exactly")
    func roundTrip() throws {
        let cipher = SyncCipher()
        let key = SyncCipher.makeKey()
        let payload = samplePayload()

        let envelope = try cipher.encrypt(payload, with: key)
        let decrypted = try cipher.decrypt(envelope, with: key)

        #expect(decrypted == payload)
        #expect(decrypted.kind == .tab)
        #expect(decrypted.url == "https://example.com/private/page")
    }

    @Test("the plaintext URL never appears in the envelope")
    func plaintextNotExposed() throws {
        let cipher = SyncCipher()
        let key = SyncCipher.makeKey()
        let payload = samplePayload()

        let envelope = try cipher.encrypt(payload, with: key)
        let utf8 = String(data: envelope, encoding: .utf8)
        // Envelope is binary; even a substring scan must not find the URL or title.
        #expect(!envelope.contains(Data("example.com".utf8)))
        #expect(!envelope.contains(Data("Confidential".utf8)))
        #expect(utf8 == nil || !utf8!.contains("Confidential"))
    }

    @Test("a flipped byte in the envelope fails authentication")
    func tamperRejected() throws {
        let cipher = SyncCipher()
        let key = SyncCipher.makeKey()
        let envelope = try cipher.encrypt(samplePayload(), with: key)

        var tampered = envelope
        let last = tampered[envelope.count - 1]
        tampered[envelope.count - 1] = last ^ 0xFF

        #expect(throws: SyncCipher.Error.decryptionFailed) {
            _ = try cipher.decrypt(tampered, with: key)
        }
    }

    @Test("a different key fails to decrypt (wrong-key rejection)")
    func wrongKeyRejected() throws {
        let cipher = SyncCipher()
        let envelope = try cipher.encrypt(samplePayload(), with: SyncCipher.makeKey())

        #expect(throws: SyncCipher.Error.decryptionFailed) {
            _ = try cipher.decrypt(envelope, with: SyncCipher.makeKey())
        }
    }

    @Test("an unknown envelope version is rejected explicitly")
    func unsupportedVersionRejected() throws {
        let cipher = SyncCipher()
        let envelope = try cipher.encrypt(samplePayload(), with: SyncCipher.makeKey())

        var corrupted = envelope
        corrupted[0] = SyncCipher.version + 1

        #expect(throws: SyncCipher.Error.unsupportedVersion(SyncCipher.version + 1)) {
            _ = try cipher.decrypt(corrupted, with: SyncCipher.makeKey())
        }
    }

    @Test("tombstone marker survives encryption and decoding")
    func tombstoneMarkerRoundTrips() throws {
        let cipher = SyncCipher()
        let key = SyncCipher.makeKey()
        let tombstone = samplePayload().tombstone()
        let decoded = try cipher.decrypt(try cipher.encrypt(tombstone, with: key), with: key)
        #expect(decoded.isTombstone)
        #expect(decoded.deleted)
        #expect(decoded.revision == tombstone.revision)
    }

    @Test("two encryptions of the same payload differ (fresh nonce per record)")
    func freshNoncePerEncryption() throws {
        let cipher = SyncCipher()
        let key = SyncCipher.makeKey()
        let payload = samplePayload()

        let first = try cipher.encrypt(payload, with: key)
        let second = try cipher.encrypt(payload, with: key)

        #expect(first != second)
    }
}

// MARK: - SyncKeyStore Tests

struct SyncKeyStoreTests {

    @Test("loadOrCreateKey provisions once and is stable across loads")
    func loadOrCreateIsStable() async throws {
        let backend = InMemorySyncKeyBackend()
        let store = SyncKeyStore(backend: backend)

        let first = try await store.loadOrCreateKey()
        let second = try await store.loadOrCreateKey()
        let loadedOptional = try await store.loadKey()
        let loaded = try #require(loadedOptional)

        #expect(first == second)
        #expect(first == loaded)
    }

    @Test("a nil key is returned when nothing was provisioned")
    func missingKeyIsNil() async throws {
        let backend = InMemorySyncKeyBackend()
        let store = SyncKeyStore(backend: backend)
        let loaded = try await store.loadKey()
        #expect(loaded == nil)
    }

    @Test("corrupt stored material is rejected")
    func corruptMaterialRejected() async throws {
        let backend = InMemorySyncKeyBackend()
        try backend.write(Data(repeating: 0xAB, count: 16), service: SyncKeyStore.service, account: "e2e-key-v1", accessGroup: nil)
        let store = SyncKeyStore(backend: backend)

        do {
            _ = try await store.loadOrCreateKey()
            Issue.record("Corrupt sync key material should be rejected")
        } catch let error as SyncKeyStore.StoreError {
            #expect(error == .corruptKeyMaterial(byteCount: 16))
        } catch {
            Issue.record("Unexpected sync key error: \(error)")
        }
    }

    @Test("a key from one store decrypts envelopes from another store with the same key")
    func crossStoreRoundTrip() async throws {
        let backend = InMemorySyncKeyBackend()
        let producer = SyncKeyStore(backend: backend)
        let consumer = SyncKeyStore(backend: backend)

        let key = try await producer.loadOrCreateKey()
        let payload = SyncPayload(
            kind: .bookmark,
            recordID: "bm-9",
            revision: 3,
            deviceID: "device-b",
            url: "https://example.com/bookmark",
            title: "Saved"
        )
        let envelope = try SyncCipher().encrypt(payload, with: key)
        let decrypted = try SyncCipher().decrypt(envelope, with: try await consumer.loadOrCreateKey())
        #expect(decrypted == payload)
    }
}
