import Foundation

public enum HiveAccountProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case apple
    case google

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        }
    }

    public var statusLabel: String {
        switch self {
        case .apple:
            return "Using Sign in with Apple"
        case .google:
            return "Using Sign in with Google"
        }
    }
}

public enum HiveFirstLoginDataChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case cloud
    case local
    case swarmMerge

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cloud:
            return "Use Cloud Data"
        case .local:
            return "Use This Device"
        case .swarmMerge:
            return "Let Swarm Mix Both"
        }
    }

    public var detail: String {
        switch self {
        case .cloud:
            return "Use the Hive saved online as the starting point for this device."
        case .local:
            return "Keep the current local Hive and do not pull cloud content automatically."
        case .swarmMerge:
            return "Ask Swarm to compare local and cloud content, then propose a safe merge."
        }
    }

    public var cloudSyncMode: HiveCloudSyncMode {
        switch self {
        case .cloud, .swarmMerge:
            return .iCloud
        case .local:
            return .localOnly
        }
    }
}

public struct HiveAuthenticatedAccount: Codable, Hashable, Sendable {
    public var provider: HiveAccountProvider
    public var providerUserID: String
    public var displayName: String?
    public var email: String?
    public var authorizedAt: Date
    public var firstLoginDataChoice: HiveFirstLoginDataChoice?

    public init(
        provider: HiveAccountProvider,
        providerUserID: String,
        displayName: String? = nil,
        email: String? = nil,
        authorizedAt: Date = Date(),
        firstLoginDataChoice: HiveFirstLoginDataChoice? = nil
    ) {
        self.provider = provider
        self.providerUserID = providerUserID
        self.displayName = Self.clean(displayName)
        self.email = Self.clean(email)
        self.authorizedAt = authorizedAt
        self.firstLoginDataChoice = firstLoginDataChoice
    }

    public var displayLabel: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        if let email, !email.isEmpty {
            return email
        }
        return "\(provider.displayName) Account"
    }

    public var statusLabel: String {
        provider.statusLabel
    }

    public var syncAnchorDescription: String {
        switch provider {
        case .apple:
            return "This Apple Account can identify the same Hive vault on Mac, iPhone, iPad, and Apple Watch."
        case .google:
            return "This Google Account can identify the same Hive vault on this device and future Hive clients."
        }
    }

    public var usesPrivateRelay: Bool {
        provider == .apple && email?.localizedCaseInsensitiveContains("privaterelay.appleid.com") == true
    }

    public var appleAccount: HiveAppleAccount? {
        guard provider == .apple else { return nil }
        return HiveAppleAccount(
            appleUserID: providerUserID,
            displayName: displayName,
            email: email,
            authorizedAt: authorizedAt
        )
    }

    public var googleAccount: HiveGoogleAccount? {
        guard provider == .google else { return nil }
        return HiveGoogleAccount(
            googleUserID: providerUserID,
            displayName: displayName,
            email: email,
            authorizedAt: authorizedAt
        )
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct HiveAppleAccount: Codable, Hashable, Sendable {
    public var appleUserID: String
    public var displayName: String?
    public var email: String?
    public var authorizedAt: Date

    public init(
        appleUserID: String,
        displayName: String? = nil,
        email: String? = nil,
        authorizedAt: Date = Date()
    ) {
        self.appleUserID = appleUserID
        self.displayName = Self.clean(displayName)
        self.email = Self.clean(email)
        self.authorizedAt = authorizedAt
    }

    public var usesPrivateRelay: Bool {
        email?.localizedCaseInsensitiveContains("privaterelay.appleid.com") == true
    }

    public var displayLabel: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        if let email, !email.isEmpty {
            return email
        }
        return "Apple Account"
    }

    public var statusLabel: String {
        HiveAccountProvider.apple.statusLabel
    }

    public var syncAnchorDescription: String {
        "This Apple Account can identify the same Hive vault on Mac, iPhone, iPad, and Apple Watch."
    }

    public var authenticatedAccount: HiveAuthenticatedAccount {
        HiveAuthenticatedAccount(
            provider: .apple,
            providerUserID: appleUserID,
            displayName: displayName,
            email: email,
            authorizedAt: authorizedAt
        )
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct HiveGoogleAccount: Codable, Hashable, Sendable {
    public var googleUserID: String
    public var displayName: String?
    public var email: String?
    public var authorizedAt: Date

    public init(
        googleUserID: String,
        displayName: String? = nil,
        email: String? = nil,
        authorizedAt: Date = Date()
    ) {
        self.googleUserID = googleUserID
        self.displayName = Self.clean(displayName)
        self.email = Self.clean(email)
        self.authorizedAt = authorizedAt
    }

    public var displayLabel: String {
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        if let email, !email.isEmpty {
            return email
        }
        return "Google Account"
    }

    public var statusLabel: String {
        HiveAccountProvider.google.statusLabel
    }

    public var syncAnchorDescription: String {
        "This Google Account can identify the same Hive vault on this device and future Hive clients."
    }

    public var authenticatedAccount: HiveAuthenticatedAccount {
        HiveAuthenticatedAccount(
            provider: .google,
            providerUserID: googleUserID,
            displayName: displayName,
            email: email,
            authorizedAt: authorizedAt
        )
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum HiveAccountStore {
    public static let storageKey = "hive.authenticatedAccount"

    public static func load(defaults: UserDefaults = .standard) -> HiveAuthenticatedAccount? {
        if let data = defaults.data(forKey: storageKey),
           let account = try? JSONDecoder().decode(HiveAuthenticatedAccount.self, from: data) {
            return account
        }
        if let apple = HiveAppleAccountStore.loadLegacy(defaults: defaults) {
            return apple.authenticatedAccount
        }
        if let google = HiveGoogleAccountStore.loadLegacy(defaults: defaults) {
            return google.authenticatedAccount
        }
        return nil
    }

    public static func save(_ account: HiveAuthenticatedAccount, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    public static func clearIfProvider(_ provider: HiveAccountProvider, defaults: UserDefaults = .standard) {
        guard load(defaults: defaults)?.provider == provider else { return }
        clear(defaults: defaults)
    }
}

public enum HiveAppleAccountStore {
    public static let storageKey = "hive.appleAccount"

    public static func load(defaults: UserDefaults = .standard) -> HiveAppleAccount? {
        if let account = HiveAccountStore.load(defaults: defaults)?.appleAccount {
            return account
        }
        return loadLegacy(defaults: defaults)
    }

    fileprivate static func loadLegacy(defaults: UserDefaults = .standard) -> HiveAppleAccount? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(HiveAppleAccount.self, from: data)
    }

    public static func save(_ account: HiveAppleAccount, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        defaults.set(data, forKey: storageKey)
        HiveAccountStore.save(account.authenticatedAccount, defaults: defaults)
    }

    public static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
        HiveAccountStore.clearIfProvider(.apple, defaults: defaults)
    }
}

public enum HiveGoogleAccountStore {
    public static let storageKey = "hive.googleAccount"

    public static func load(defaults: UserDefaults = .standard) -> HiveGoogleAccount? {
        if let account = HiveAccountStore.load(defaults: defaults)?.googleAccount {
            return account
        }
        return loadLegacy(defaults: defaults)
    }

    fileprivate static func loadLegacy(defaults: UserDefaults = .standard) -> HiveGoogleAccount? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(HiveGoogleAccount.self, from: data)
    }

    public static func save(_ account: HiveGoogleAccount, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        defaults.set(data, forKey: storageKey)
        HiveAccountStore.save(account.authenticatedAccount, defaults: defaults)
    }

    public static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
        HiveAccountStore.clearIfProvider(.google, defaults: defaults)
    }
}

public enum HiveGuestAccessStore {
    public static let storageKey = "hive.temporaryGuestAccess"

    public static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: storageKey)
    }

    public static func enable(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: storageKey)
    }

    public static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}

public struct HiveFirstLoginDataChoicePrompt: Identifiable, Hashable, Sendable {
    public var account: HiveAuthenticatedAccount

    public init(account: HiveAuthenticatedAccount) {
        self.account = account
    }

    public var id: String {
        "\(account.provider.rawValue)-\(account.providerUserID)"
    }
}

public enum HiveFirstLoginDataChoiceStore {
    public static let choiceKey = "hive.firstLoginDataChoice"
    public static let swarmMergeKey = "hive.firstLoginDataChoice.swarmMergeRequested"

    public static func needsChoice(
        for account: HiveAuthenticatedAccount,
        defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.string(forKey: accountChoiceKey(for: account)) == nil
    }

    public static func load(
        for account: HiveAuthenticatedAccount,
        defaults: UserDefaults = .standard
    ) -> HiveFirstLoginDataChoice? {
        let raw = defaults.string(forKey: accountChoiceKey(for: account))
            ?? defaults.string(forKey: choiceKey)
        return raw.flatMap(HiveFirstLoginDataChoice.init(rawValue:))
    }

    public static func save(
        _ choice: HiveFirstLoginDataChoice,
        for account: HiveAuthenticatedAccount,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(choice.rawValue, forKey: choiceKey)
        defaults.set(choice.rawValue, forKey: accountChoiceKey(for: account))
        defaults.set(choice == .swarmMerge, forKey: swarmMergeKey)
        HiveCloudSyncSettingsStore.save(HiveCloudSyncSettings(mode: choice.cloudSyncMode), defaults: defaults)
        var updatedAccount = account
        updatedAccount.firstLoginDataChoice = choice
        HiveAccountStore.save(updatedAccount, defaults: defaults)
    }

    private static func accountChoiceKey(for account: HiveAuthenticatedAccount) -> String {
        let rawID = account.providerUserID
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "hive.firstLoginDataChoice.\(account.provider.rawValue).\(rawID)"
    }
}

public enum HiveAppleCredentialValidationResult: Equatable, Sendable {
    case authorized
    case revoked
    case notFound
    case transferred
    case failed(String)
}

public enum HiveAppleAuthenticationResolution: Equatable, Sendable {
    case authenticated(HiveAppleAccount)
    case locked(reason: String, shouldClearStoredAccount: Bool)

    public var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}

public enum HiveAppleCredentialStateResolver {
    public static func resolve(
        storedAccount: HiveAppleAccount?,
        validationResult: HiveAppleCredentialValidationResult?
    ) -> HiveAppleAuthenticationResolution {
        guard let account = storedAccount else {
            return .locked(
                reason: "Sign in with Apple is required before Hive can open your workspace.",
                shouldClearStoredAccount: false
            )
        }

        guard let validationResult else {
            return .locked(
                reason: "Hive could not verify this Apple Account. Sign in again to continue.",
                shouldClearStoredAccount: true
            )
        }

        switch validationResult {
        case .authorized, .transferred:
            return .authenticated(account)
        case .revoked:
            return .locked(
                reason: "Apple revoked this Hive sign-in. Sign in again to continue.",
                shouldClearStoredAccount: true
            )
        case .notFound:
            return .locked(
                reason: "Apple no longer recognizes this Hive sign-in. Sign in again to continue.",
                shouldClearStoredAccount: true
            )
        case .failed:
            return .locked(
                reason: "Hive could not verify this Apple Account. Sign in again to continue.",
                shouldClearStoredAccount: true
            )
        }
    }
}

public enum HiveAppleAccountPolicy {
    public static let signInIsRequired = true
    public static let requiresSignInBeforeUse = true
    public static let blocksUnauthenticatedAppAccess = true
    public static let signInIsOptional = false
    public static let delayedUntilSettings = false
    public static let usesSystemProvidedButton = true
    public static let requestsOnlyNameAndEmail = true
    public static let asksForPassword = false
    public static let respectsPrivateRelayEmail = true
    public static let minimumButtonWidth: Double = 140
    public static let minimumButtonHeight: Double = 30
    public static let minimumButtonMarginRatio: Double = 0.1
    public static let statusTextLineLimit = 1
    public static let accountIdentifierLineLimit = 1
    public static let signOutActionClearsOnlyIdentity = true
    public static let temporaryGuestAccessIsEnabled = true
    public static let signInWithGoogleIsEnabled = true
    public static let requiresFirstLoginDataChoice = true

    public static var followsSignInWithAppleGuidance: Bool {
        signInIsRequired
            && requiresSignInBeforeUse
            && blocksUnauthenticatedAppAccess
            && !signInIsOptional
            && !delayedUntilSettings
            && usesSystemProvidedButton
            && requestsOnlyNameAndEmail
            && !asksForPassword
            && respectsPrivateRelayEmail
            && minimumButtonWidth >= 140
            && minimumButtonHeight >= 30
            && minimumButtonMarginRatio >= 0.1
            && statusTextLineLimit == 1
            && accountIdentifierLineLimit == 1
            && signOutActionClearsOnlyIdentity
    }
}
