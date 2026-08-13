import CryptoKit
import Foundation
import Testing
@testable import HiveCore

@Suite("KeychainHMACKeyStore")
struct KeychainHMACKeyStoreTests {
    private final class MemoryBackend: HMACKeyMaterialBackend, @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: Data] = [:]
        var failRead = false
        var failWrite = false
        var discardWrites = false

        func read(service: String, account: String, accessGroup: String?) throws -> Data? {
            lock.lock()
            defer { lock.unlock() }
            if failRead { throw BackendError.readFailed }
            return values["\(service)|\(account)|\(accessGroup ?? "")"]
        }

        func write(_ data: Data, service: String, account: String, accessGroup: String?) throws {
            lock.lock()
            defer { lock.unlock() }
            if failWrite { throw BackendError.writeFailed }
            if discardWrites { return }
            let key = "\(service)|\(account)|\(accessGroup ?? "")"
            // Match SecItemAdd duplicate behavior: never replace an existing key.
            if values[key] == nil { values[key] = data }
        }

        func seed(_ data: Data, version: KeychainHMACKeyStore.Version = .v1) {
            lock.lock()
            values["\(KeychainHMACKeyStore.service)|approval-hmac-v\(version.rawValue)|"] = data
            lock.unlock()
        }

        private enum BackendError: Error {
            case readFailed
            case writeFailed
        }
    }

    private func authorityCapability(keyVersion: Int? = nil) -> RetentionCapability {
        RetentionCapability(
            nonce: "provider-grant",
            issuerID: "provider-test",
            keyVersion: keyVersion,
            retentionClass: "project",
            deletionScope: "provenance",
            sourceContentHash: String(repeating: "a", count: 64),
            projectID: "project-1",
            provenance: "rust-research-boundary",
            issuedAt: Date().addingTimeInterval(-1),
            expiresAt: Date().addingTimeInterval(60)
        )
    }

    @Test func provisionsOnceAndLoadsTheSameMaterialAcrossProviderInstances() async throws {
        let backend = MemoryBackend()
        let first = KeychainHMACKeyStore(backend: backend)
        let second = KeychainHMACKeyStore(backend: backend)

        let firstKey = try await first.loadOrCreateKey()
        let secondKey = try await second.loadOrCreateKey()
        #expect(firstKey.withUnsafeBytes { Data($0) } == secondKey.withUnsafeBytes { Data($0) })

        let authority = try await second.makeAuthority(issuerID: "provider-test")
        let signed = try authority.issue(authorityCapability())
        try authority.verify(signed)
    }

    @Test func concurrentProvisioningConvergesOnOnePersistedKey() async throws {
        let backend = MemoryBackend()
        let stores = (0..<8).map { _ in KeychainHMACKeyStore(backend: backend) }
        let materials = await withTaskGroup(of: Data.self, returning: [Data].self) { group in
            for store in stores {
                group.addTask {
                    let key = try! await store.loadOrCreateKey()
                    return key.withUnsafeBytes { Data($0) }
                }
            }
            var result: [Data] = []
            for await material in group { result.append(material) }
            return result
        }
        #expect(Set(materials).count == 1)
    }

    @Test func corruptMaterialIsRejectedAndNeverOverwritten() async throws {
        let backend = MemoryBackend()
        backend.seed(Data(repeating: 0x01, count: 7))
        let store = KeychainHMACKeyStore(backend: backend)

        await #expect(throws: KeychainHMACKeyStore.StoreError.corruptKeyMaterial(version: .v1, byteCount: 7)) {
            _ = try await store.loadOrCreateKey()
        }
        await #expect(throws: KeychainHMACKeyStore.StoreError.corruptKeyMaterial(version: .v1, byteCount: 7)) {
            _ = try await store.loadKey()
        }
    }

    @Test func backendWriteFailureAndMissingReadbackFailClosed() async throws {
        let writeFailing = MemoryBackend()
        writeFailing.failWrite = true
        let writeStore = KeychainHMACKeyStore(backend: writeFailing)
        await #expect(throws: KeychainHMACKeyStore.StoreError.self) {
            _ = try await writeStore.loadOrCreateKey()
        }

        let disappearing = MemoryBackend()
        disappearing.discardWrites = true
        let disappearingStore = KeychainHMACKeyStore(backend: disappearing)
        await #expect(throws: KeychainHMACKeyStore.StoreError.keyUnavailable(version: .v1)) {
            _ = try await disappearingStore.loadOrCreateKey()
        }
    }

    @Test func unprovisionedStoreAutoCreatesKeyAndMakesAuthority() async throws {
        let backend = MemoryBackend()
        let store = KeychainHMACKeyStore(backend: backend)
        // makeAuthority calls loadOrCreateKey internally, so it auto-provisions
        let authority = try await store.makeAuthority(issuerID: "auto-provision")
        #expect(authority.issuerID == "auto-provision")
    }

    @Test func loadKeyReturnsNilWhenNotProvisioned() async throws {
        let backend = MemoryBackend()
        let store = KeychainHMACKeyStore(backend: backend)
        let key = try await store.loadKey()
        #expect(key == nil)
    }

    @Test func versionRotationIsExplicitAndOldAuthorityDoesNotAcceptNewVersion() async throws {
        let backend = MemoryBackend()
        let store = KeychainHMACKeyStore(backend: backend)
        let v1 = try await store.makeAuthority(issuerID: "provider-test", version: .v1)
        let v2Version = KeychainHMACKeyStore.Version(rawValue: 2)
        let v2 = try await store.makeAuthority(issuerID: "provider-test", version: v2Version)

        let signedV1 = try v1.issue(authorityCapability())
        try v1.verify(signedV1)
        #expect(throws: RetentionCapabilityError.keyVersionMismatch) {
            try v2.verify(signedV1)
        }

        let signedV2 = try v2.issue(authorityCapability())
        try v2.verify(signedV2)
        #expect(throws: RetentionCapabilityError.keyVersionMismatch) {
            try v1.verify(signedV2)
        }
    }
}
