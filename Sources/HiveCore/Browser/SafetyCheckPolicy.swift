import Foundation

// MARK: - SafetyCheckPolicy
//
// Chrome's chrome://settings/safetyCheck parity: one surface that reports on
// saved passwords, Safe Browsing, extensions, updates, notification
// permissions, and the HTTPS-only preference. All classification is pure and
// deterministic so the report is unit-testable; the app supplies live inputs
// and the policy decides status, Chrome-style ordering, and copy.
//
// Honest scoping: this is a local check. We report what the local browser
// knows (weak/reused passwords, whether Safe Browsing is configured, how many
// extensions exist, whether auto-update is wired, how many sites may send
// notifications, whether HTTPS-only is on). We cannot inspect extension
// behavior or test passwords against breach databases — the copy never claims
// those checks.

/// How healthy a single check is.
public enum SafetyCheckStatus: String, Sendable, Equatable {
    /// All good — green checkmark.
    case pass
    /// Needs attention — orange alert.
    case warn
    /// Informational — blue, no action required.
    case info
}

/// One row of the Safety Check report.
public struct SafetyCheckItem: Identifiable, Sendable, Equatable {
    public enum Kind: String, Sendable {
        case passwords
        case safeBrowsing
        case extensions
        case updates
        case permissions
        case https
    }

    public let kind: Kind
    public let status: SafetyCheckStatus
    public let title: String
    public let detail: String

    public var id: String { kind.rawValue }

    public init(kind: Kind, status: SafetyCheckStatus, title: String, detail: String) {
        self.kind = kind
        self.status = status
        self.title = title
        self.detail = detail
    }
}

public enum SafetyCheckPolicy {
    /// Passwords shorter than this count as weak, matching the password
    /// generator's hint.
    public static let minimumStrongLength = 8

    // MARK: - Password classification

    /// Chrome-style strength heuristic: empty, shorter than 8 characters, or
    /// composed of a single character class counts as weak.
    public static func passwordIsWeak(_ password: String) -> Bool {
        guard !password.isEmpty else { return true }
        if password.count < minimumStrongLength { return true }
        var hasLower = false
        var hasUpper = false
        var hasDigit = false
        var hasSymbol = false
        for scalar in password.unicodeScalars {
            if CharacterSet.uppercaseLetters.contains(scalar) {
                hasUpper = true
            } else if CharacterSet.lowercaseLetters.contains(scalar) {
                hasLower = true
            } else if CharacterSet.decimalDigits.contains(scalar) {
                hasDigit = true
            } else {
                hasSymbol = true
            }
        }
        let classes = [hasLower, hasUpper, hasDigit, hasSymbol].filter { $0 }.count
        return classes < 2
    }

    /// Number of distinct password values that are shared by 2+ distinct
    /// sites. Empty passwords are ignored (an empty saved password is itself
    /// weak and counted there, not as a reuse).
    public static func reusedPasswordCount(passwords: [(site: String, password: String)]) -> Int {
        guard !passwords.isEmpty else { return 0 }
        var sitesByPassword: [String: Set<String>] = [:]
        for entry in passwords where !entry.password.isEmpty {
            sitesByPassword[entry.password, default: []].insert(entry.site)
        }
        return sitesByPassword.values.filter { $0.count >= 2 }.count
    }

    // MARK: - Report assembly

    /// Builds the full report in Chrome's order: passwords, Safe Browsing,
    /// extensions, updates, site permissions, HTTPS-only.
    public static func report(
        passwords: [(site: String, password: String)],
        safeBrowsingConfigured: Bool,
        extensionCount: Int,
        canCheckForUpdates: Bool,
        notificationGrantCount: Int,
        httpsOnlyEnabled: Bool
    ) -> [SafetyCheckItem] {
        var items: [SafetyCheckItem] = []

        // 1. Passwords
        let weakCount = passwords.filter { passwordIsWeak($0.password) }.count
        let reusedCount = reusedPasswordCount(passwords: passwords)
        if weakCount > 0 || reusedCount > 0 {
            var parts: [String] = []
            if weakCount > 0 { parts.append("\(weakCount) weak") }
            if reusedCount > 0 { parts.append("\(reusedCount) reused") }
            let noun = weakCount + reusedCount == 1 ? "password" : "passwords"
            items.append(SafetyCheckItem(
                kind: .passwords,
                status: .warn,
                title: "Review your passwords",
                detail: "\(parts.joined(separator: " and ")) \(noun) found in the password manager."
            ))
        } else if passwords.isEmpty {
            items.append(SafetyCheckItem(
                kind: .passwords,
                status: .pass,
                title: "No saved passwords",
                detail: "There's nothing to check. Passwords you save are checked here."
            ))
        } else {
            let noun = passwords.count == 1 ? "password" : "passwords"
            items.append(SafetyCheckItem(
                kind: .passwords,
                status: .pass,
                title: "No weak or reused passwords",
                detail: "Checked \(passwords.count) saved \(noun)."
            ))
        }

        // 2. Safe Browsing
        if safeBrowsingConfigured {
            items.append(SafetyCheckItem(
                kind: .safeBrowsing,
                status: .pass,
                title: "Safe Browsing is on",
                detail: "Protects you from deceptive sites and dangerous downloads."
            ))
        } else {
            items.append(SafetyCheckItem(
                kind: .safeBrowsing,
                status: .warn,
                title: "Safe Browsing isn't set up",
                detail: "Add a Google Safe Browsing API key in Settings → Privacy to get deceptive-site warnings."
            ))
        }

        // 3. Extensions
        if extensionCount == 0 {
            items.append(SafetyCheckItem(
                kind: .extensions,
                status: .pass,
                title: "No extensions installed",
                detail: "Nothing to review."
            ))
        } else {
            let noun = extensionCount == 1 ? "extension" : "extensions"
            items.append(SafetyCheckItem(
                kind: .extensions,
                status: .info,
                title: "\(extensionCount) \(noun) installed",
                detail: "Review them in the Extensions panel. Hive can't inspect extension behavior — install only from sources you trust."
            ))
        }

        // 4. Updates
        if canCheckForUpdates {
            items.append(SafetyCheckItem(
                kind: .updates,
                status: .pass,
                title: "Updates are checked automatically",
                detail: "Hive checks for a new version daily via Sparkle."
            ))
        } else {
            items.append(SafetyCheckItem(
                kind: .updates,
                status: .info,
                title: "Automatic updates aren't configured",
                detail: "This build has no update feed. Install new versions from the official download page."
            ))
        }

        // 5. Site permissions (notifications)
        if notificationGrantCount == 0 {
            items.append(SafetyCheckItem(
                kind: .permissions,
                status: .pass,
                title: "No sites can send notifications",
                detail: "Notification access is granted per site and can be revoked anytime in Site Settings."
            ))
        } else {
            let noun = notificationGrantCount == 1 ? "site" : "sites"
            items.append(SafetyCheckItem(
                kind: .permissions,
                status: .info,
                title: "\(notificationGrantCount) \(noun) can send notifications",
                detail: "Review or revoke notification access in Site Settings."
            ))
        }

        // 6. HTTPS-only
        if httpsOnlyEnabled {
            items.append(SafetyCheckItem(
                kind: .https,
                status: .pass,
                title: "Always use secure connections is on",
                detail: "Plaintext http:// addresses upgrade to https:// when possible."
            ))
        } else {
            items.append(SafetyCheckItem(
                kind: .https,
                status: .info,
                title: "Always use secure connections is off",
                detail: "Turn it on in Settings → Privacy to upgrade http:// pages to https://."
            ))
        }

        return items
    }
}
