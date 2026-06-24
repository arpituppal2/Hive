import Foundation
import Security

public enum HiveKeychainStore {
    public static func save(service: String, account: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    public static func load(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    public static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public struct GoogleDriveOAuthTokens: Codable, Hashable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var expiry: Date?

    public init(accessToken: String, refreshToken: String, expiry: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiry = expiry
    }
}

public enum GoogleDriveOAuthStore {
    public static let service = "com.hive.googledrive"
    public static let account = "oauth_tokens"

    public static func save(_ tokens: GoogleDriveOAuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        try HiveKeychainStore.save(service: service, account: account, data: data)
    }

    public static func load() -> GoogleDriveOAuthTokens? {
        guard let data = HiveKeychainStore.load(service: service, account: account) else { return nil }
        return try? JSONDecoder().decode(GoogleDriveOAuthTokens.self, from: data)
    }

    public static func delete() {
        HiveKeychainStore.delete(service: service, account: account)
    }

    public static var hasValidTokens: Bool {
        guard let tokens = load() else { return false }
        if let expiry = tokens.expiry {
            return expiry > Date()
        }
        return !tokens.accessToken.isEmpty
    }
}
