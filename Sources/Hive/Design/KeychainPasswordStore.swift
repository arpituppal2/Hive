import Foundation
import Security

// MARK: - KeychainPasswordStore
//
// macOS Keychain-backed password storage using the Security framework.
// Every saved credential is stored in the system Keychain (hardware-backed
// on Macs with Secure Enclave). Replaces the old plaintext JSON storage.
//
// Migration: on first launch after upgrade, reads old plaintext passwords
// from session.json and migrates them into Keychain, then strips them
// from the JSON file.

struct KeychainPasswordStore {
    private static let service = "com.hive.browser"

    // MARK: - Public API

    static func allPasswords() -> [SavedPassword] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,
            kSecReturnData: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let items = result as? [[CFString: Any]] else { return [] }

        return items.compactMap { parseItem($0) }
    }

    @discardableResult
    static func save(username: String, password: String, site: String) -> Bool {
        let account = makeAccount(site: site, username: username)
        guard let passwordData = password.data(using: .utf8) else { return false }

        // Try update first — if the item exists, update it in-place.
        // If it doesn't exist, add a new item. This avoids the
        // delete-then-add race condition.
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let attrs: [CFString: Any] = [
            kSecAttrLabel: site,
            kSecValueData: passwordData,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        // Item doesn't exist yet — add it
        var addQuery = query
        addQuery[kSecAttrLabel] = site
        addQuery[kSecValueData] = passwordData
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess { return true }
        if addStatus == errSecDuplicateItem {
            // Race: someone else added it. Retry the update.
            return SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecSuccess
        }
        print("[KeychainPasswordStore] Failed to save credential for \(account): OSStatus \(addStatus)")
        return false
    }

    @discardableResult
    static func delete(site: String, username: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: makeAccount(site: site, username: username),
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func deleteAll() {
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
        ] as CFDictionary)
    }

    // MARK: - Migration

    /// Reads old plaintext passwords from session JSON and migrates them
    /// into Keychain. Call once on first launch after upgrade. Returns the
    /// number of passwords migrated.
    @discardableResult
    static func migrateFromLegacyJSON() -> Int {
        let sessionURL = sessionFileURL()
        guard let data = try? Data(contentsOf: sessionURL),
              let raw = try? JSONSerialization.jsonObject(with: data),
              let json = raw as? [String: Any],
              let passwords = json["passwords"] as? [[String: Any]] else { return 0 }

        var migrated = 0
        for entry in passwords {
            guard let username = entry["username"] as? String,
                  let password = entry["password"] as? String,
                  let site = entry["site"] as? String else { continue }
            if save(username: username, password: password, site: site) {
                migrated += 1
            }
        }

        // Strip passwords from session file if migration succeeded
        if migrated > 0 {
            var mutableJSON = json
            mutableJSON.removeValue(forKey: "passwords")
            if let updated = try? JSONSerialization.data(withJSONObject: mutableJSON, options: .prettyPrinted) {
                try? updated.write(to: sessionURL, options: .atomic)
            }
        }

        return migrated
    }

    // MARK: - Private

    private static func makeAccount(site: String, username: String) -> String {
        "\(site):\(username)"
    }

    private static func parseItem(_ item: [CFString: Any]) -> SavedPassword? {
        guard let account = item[kSecAttrAccount] as? String,
              let passwordData = item[kSecValueData] as? Data,
              let password = String(data: passwordData, encoding: .utf8),
              let label = item[kSecAttrLabel] as? String else { return nil }

        let parts = account.split(separator: ":", maxSplits: 1).map(String.init)
        let username = parts.count > 1 ? parts[1] : account
        let site = label.isEmpty ? (parts.first ?? "") : label

        return SavedPassword(username: username, password: password, site: site)
    }

    private static func sessionFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Hive", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }
}
