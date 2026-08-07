import Foundation
import Security

// MARK: - KeychainSecretStore
//
// Actor-isolated generic secret store backed by the macOS Keychain. Stores
// arbitrary string secrets keyed by a caller-defined alias using
// kSecClassGenericPassword. This is intentionally separate from
// KeychainPasswordStore, which is modeled around kSecClassInternetPassword
// for browser domain/username autofill credentials.
//
// Typical use: BYOK API keys, service tokens, and other non-credential
// secrets that must never be written to plaintext config or source control.

public actor KeychainSecretStore {

    /// Keychain access group (nil = default app access group).
    private let accessGroup: String?

    /// Service name used to namespace generic Hive secrets in the Keychain.
    private static let serviceName = "com.hive.browser.secret"

    public init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }

    // MARK: - Public API

    /// Saves or updates a secret for the given alias.
    public func save(_ value: String, for alias: String) throws {
        if try findItem(for: alias) != nil {
            try update(value: value, for: alias)
        } else {
            try add(value: value, for: alias)
        }
    }

    /// Retrieves the secret for the given alias, or nil if none exists.
    public func get(for alias: String) throws -> String? {
        return try findItem(for: alias)
    }

    /// Deletes the secret for the given alias. No-op if none exists.
    public func delete(for alias: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: alias,
            kSecAttrService as String: Self.serviceName,
        ]
        if let ag = accessGroup {
            query[kSecAttrAccessGroup as String] = ag
        }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretError.unexpectedStatus(status)
        }
    }

    /// Deletes all stored secrets. Irreversible.
    public func deleteAll() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
        ]
        if let ag = accessGroup {
            query[kSecAttrAccessGroup as String] = ag
        }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretError.unexpectedStatus(status)
        }
    }

    /// Returns the total count of stored secrets.
    public func count() throws -> Int {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: false,
        ]
        if let ag = accessGroup {
            query[kSecAttrAccessGroup as String] = ag
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            if status == errSecItemNotFound { return 0 }
            throw KeychainSecretError.unexpectedStatus(status)
        }
        return items.count
    }

    // MARK: - Private

    private func findItem(for alias: String) throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: alias,
            kSecAttrService as String: Self.serviceName,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        if let ag = accessGroup {
            query[kSecAttrAccessGroup as String] = ag
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let item = result as? [String: Any] else {
            if status == errSecItemNotFound { return nil }
            throw KeychainSecretError.unexpectedStatus(status)
        }
        return itemToSecret(item)
    }

    private func add(value: String, for alias: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainSecretError.encodingFailed
        }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: alias,
            kSecAttrService as String: Self.serviceName,
            kSecValueData as String: data,
            kSecAttrLabel as String: "Hive Browser Secret — \(alias)",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        if let ag = accessGroup {
            query[kSecAttrAccessGroup as String] = ag
        }
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainSecretError.unexpectedStatus(status)
        }
    }

    private func update(value: String, for alias: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainSecretError.encodingFailed
        }
        var searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: alias,
            kSecAttrService as String: Self.serviceName,
        ]
        if let ag = accessGroup {
            searchQuery[kSecAttrAccessGroup as String] = ag
        }
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        let status = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainSecretError.unexpectedStatus(status)
        }
    }

    private func itemToSecret(_ item: [String: Any]) -> String? {
        guard let data = item[kSecValueData as String] as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            return nil
        }
        return secret
    }
}

// MARK: - KeychainSecretError

public enum KeychainSecretError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain secret operation failed with status \(status)"
        case .encodingFailed:
            return "Failed to encode secret as UTF-8"
        }
    }
}
