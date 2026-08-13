import Foundation
import Security

// MARK: - KeychainPasswordStore
//
// Secure, Keychain-backed credential store for the browser. Stores username/password
// pairs per domain using the macOS Keychain Services API (SecItemAdd/SecItemCopyMatching/
// SecItemDelete). Credentials are encrypted at rest by the system Keychain and
// never written to plaintext config, logs, or source control.
//
// The store surfaces as an actor to serialize Keychain access. Every operation
// is synchronous (Keychain calls are fast and atomic) but isolated to prevent
// races on the shared keychain database.
//
// Integration: ChromeState holds an optional KeychainPasswordStore. When non-nil,
// the WKWebView autofill path queries it for matching credentials on page load.
// The user is prompted before any credential is injected into a page (permission
// gate in WebViewContainer.Coordinator).

// MARK: - Credential

/// A stored username/password pair for a specific domain.
public struct Credential: Sendable, Codable, Equatable, Identifiable {
    /// The domain (host) this credential belongs to, e.g. "github.com".
    public let domain: String
    /// The username or email.
    public let username: String
    /// The password (returned from Keychain only when explicitly requested).
    public let password: String
    /// When this credential was created or last updated.
    public let updatedAt: Date

    /// Composite unique key: "domain:username"
    public var id: String { "\(domain):\(username)" }

    /// Composite key for SwiftUI ForEach identity
    public var compositeKey: String { id }

    public init(domain: String, username: String, password: String, updatedAt: Date = Date()) {
        self.domain = domain
        self.username = username
        self.password = password
        self.updatedAt = updatedAt
    }
}

// MARK: - KeychainPasswordStore

/// Actor-isolated password store backed by the macOS Keychain.
/// Credentials are stored as internet passwords (kSecClassInternetPassword) keyed
/// by domain + username. The Keychain encrypts them at rest and requires device
/// unlock to access.
public actor KeychainPasswordStore {

    /// The Keychain access group (nil = default app access group).
    private let accessGroup: String?

    /// Service name used to namespace Hive credentials in the Keychain.
    private static let serviceName = "com.hive.browser.password"

    public init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }

    // MARK: - Public API

    /// Saves or updates a credential in the Keychain. If a credential for the
    /// same domain+username already exists, it is updated.
    public func save(_ credential: Credential) throws {
        // Check if an existing item needs updating.
        if try findItem(domain: credential.domain, username: credential.username) != nil {
            try update(credential)
        } else {
            try add(credential)
        }
    }

    /// Retrieves a single credential for the given domain and username.
    /// Returns nil if no match exists.
    public func get(domain: String, username: String) throws -> Credential? {
        return try findItem(domain: domain, username: username)
    }

    /// Retrieves all credentials for a given domain. Used for autofill suggestions
    /// (multiple accounts on the same site). Returns empty array if none found.
    public func getAll(forDomain domain: String) throws -> [Credential] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: domain,
            kSecAttrService as String: Self.serviceName,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        if let ag = accessGroup {
            query[kSecAttrAccessGroup as String] = ag
        }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            if status == errSecItemNotFound { return [] }
            throw KeychainError.unexpectedStatus(status)
        }

        return items.compactMap { itemToCredential($0) }
    }

    /// Returns all stored domains (for the password manager UI list view).
    /// Deduplicated set of server/domain values.
    public func getAllDomains() throws -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
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
            if status == errSecItemNotFound { return [] }
            throw KeychainError.unexpectedStatus(status)
        }

        var domains = Set<String>()
        for item in items {
            if let server = item[kSecAttrServer as String] as? String {
                domains.insert(server)
            }
        }
        return Array(domains).sorted()
    }

    /// Deletes a single credential for the given domain + username.
    /// No-op if no match exists.
    public func delete(domain: String, username: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: domain,
            kSecAttrAccount as String: username,
            kSecAttrService as String: Self.serviceName,
        ]
        if let ag = accessGroup {
            query[kSecAttrAccessGroup as String] = ag
        }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Deletes all credentials for a given domain.
    public func deleteAll(forDomain domain: String) throws {
        let creds = try getAll(forDomain: domain)
        for cred in creds {
            try delete(domain: cred.domain, username: cred.username)
        }
    }

    /// Deletes all stored credentials. Irreversible.
    public func deleteAll() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrService as String: Self.serviceName,
        ]
        if let ag = accessGroup {
            query[kSecAttrAccessGroup as String] = ag
        }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Returns the total count of stored credentials.
    public func count() throws -> Int {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
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
            throw KeychainError.unexpectedStatus(status)
        }
        return items.count
    }

    // MARK: - Private

    private func findItem(domain: String, username: String) throws -> Credential? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: domain,
            kSecAttrAccount as String: username,
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
            throw KeychainError.unexpectedStatus(status)
        }
        return itemToCredential(item)
    }

    private func add(_ credential: Credential) throws {
        guard let passwordData = credential.password.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: credential.domain,
            kSecAttrAccount as String: credential.username,
            kSecAttrService as String: Self.serviceName,
            kSecValueData as String: passwordData,
            kSecAttrLabel as String: "Hive Browser — \(credential.domain)",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        if let ag = accessGroup {
            query[kSecAttrAccessGroup as String] = ag
        }
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func update(_ credential: Credential) throws {
        guard let passwordData = credential.password.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        var searchQuery: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: credential.domain,
            kSecAttrAccount as String: credential.username,
            kSecAttrService as String: Self.serviceName,
        ]
        if let ag = accessGroup {
            searchQuery[kSecAttrAccessGroup as String] = ag
        }
        let updateAttributes: [String: Any] = [
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        let status = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func itemToCredential(_ item: [String: Any]) -> Credential? {
        guard let server = item[kSecAttrServer as String] as? String,
              let account = item[kSecAttrAccount as String] as? String,
              let passwordData = item[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            return nil
        }
        let date = (item[kSecAttrModificationDate as String] as? Date) ?? Date()
        return Credential(domain: server, username: account, password: password, updatedAt: date)
    }
}

// MARK: - KeychainError

public enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)"
        case .encodingFailed:
            return "Failed to encode password as UTF-8"
        }
    }
}
