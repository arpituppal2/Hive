import CryptoKit
import Foundation
import Security

// MARK: - E2E sync key storage
//
// P3.4: the 256-bit AES key that encrypts every sync envelope before it
// reaches CloudKit. Mirrors KeychainHMACKeyStore's versioned load-or-create
// pattern: provisioned once, never overwritten, injectable backend so tests
// never touch a developer's Keychain.

/// Storage seam for the sync key. Production is Keychain-backed; tests inject
/// an in-memory implementation.
public protocol SyncKeyMaterialBackend: Sendable {
    func read(service: String, account: String, accessGroup: String?) throws -> Data?
    func write(_ data: Data, service: String, account: String, accessGroup: String?) throws
}

public actor SyncKeyStore {
    public enum StoreError: Error, Sendable, Equatable, CustomStringConvertible {
        case invalidVersion
        case corruptKeyMaterial(byteCount: Int)
        case keyUnavailable
        case backend(String)

        public var description: String {
            switch self {
            case .invalidVersion:
                return "sync key version must be positive"
            case .corruptKeyMaterial(let byteCount):
                return "sync key has invalid material (\(byteCount) bytes; expected 32)"
            case .keyUnavailable:
                return "sync key was not available after provisioning"
            case .backend(let message):
                return "sync key backend failed: \(message)"
            }
        }
    }

    public static let service = "com.hive.browser.sync-e2e"

    private let accessGroup: String?
    private let backend: any SyncKeyMaterialBackend

    public init(
        accessGroup: String? = nil,
        backend: (any SyncKeyMaterialBackend)? = nil
    ) {
        self.accessGroup = accessGroup
        self.backend = backend ?? KeychainSyncKeyBackend()
    }

    /// Loads the E2E key or provisions it once. Never overwrites existing
    /// material — losing the key would make previously synced envelopes
    /// undecryptable on this device.
    public func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try loadKey() { return existing }

        let material = SymmetricKey(size: .bits256)
        let bytes = material.withUnsafeBytes { Data($0) }
        do {
            try backend.write(bytes, service: Self.service, account: "e2e-key-v1", accessGroup: accessGroup)
        } catch {
            throw StoreError.backend(String(describing: error))
        }

        guard let persisted = try loadKey() else {
            throw StoreError.keyUnavailable
        }
        return persisted
    }

    /// Loads the key without provisioning it (distinguishes missing from new).
    public func loadKey() throws -> SymmetricKey? {
        let data: Data?
        do {
            data = try backend.read(service: Self.service, account: "e2e-key-v1", accessGroup: accessGroup)
        } catch {
            throw StoreError.backend(String(describing: error))
        }
        guard let data else { return nil }
        guard data.count == 32 else {
            throw StoreError.corruptKeyMaterial(byteCount: data.count)
        }
        return SymmetricKey(data: data)
    }
}

private struct KeychainSyncKeyBackend: SyncKeyMaterialBackend {
    func read(service: String, account: String, accessGroup: String?) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // The E2E key must arrive on the user's other Apple devices.
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainSyncBackendError.status(status) }
        return result as? Data
    }

    func write(_ data: Data, service: String, account: String, accessGroup: String?) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // Synchronizable items cannot use a ThisDeviceOnly class.
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecValueData as String: data,
            kSecAttrLabel as String: "Hive Browser E2E Sync Key — \(account)",
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            return // concurrent provisioning; caller reads back the winner
        }
        guard status == errSecSuccess else { throw KeychainSyncBackendError.status(status) }
    }
}

private enum KeychainSyncBackendError: Error, CustomStringConvertible {
    case status(OSStatus)

    var description: String {
        switch self {
        case .status(let status): return "Security framework status \(status)"
        }
    }
}

// MARK: - In-memory backend (tests)

/// Test double — keeps key material in process memory only.
public final class InMemorySyncKeyBackend: SyncKeyMaterialBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: Data] = [:]

    public init() {}

    public func read(service: String, account: String, accessGroup: String?) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return store["\(service).\(account)"]
    }

    public func write(_ data: Data, service: String, account: String, accessGroup: String?) throws {
        lock.lock(); defer { lock.unlock() }
        store["\(service).\(account)"] = data
    }
}
