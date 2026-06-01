import Foundation

public enum HiveCloudSyncMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case localOnly
    case iCloud

    public var id: String { rawValue }

    public static let `default`: HiveCloudSyncMode = .localOnly
}

public struct HiveCloudSyncSettings: Codable, Hashable, Sendable {
    public var mode: HiveCloudSyncMode
    public var syncsUserContent: Bool
    public var syncsAppState: Bool
    public var includesSearchableContent: Bool
    public var downloadsLargeContentAutomatically: Bool

    public init(
        mode: HiveCloudSyncMode = .default,
        syncsUserContent: Bool = true,
        syncsAppState: Bool = true,
        includesSearchableContent: Bool = true,
        downloadsLargeContentAutomatically: Bool = false
    ) {
        self.mode = mode
        self.syncsUserContent = syncsUserContent
        self.syncsAppState = syncsAppState
        self.includesSearchableContent = includesSearchableContent
        self.downloadsLargeContentAutomatically = downloadsLargeContentAutomatically
    }

    public var isEnabled: Bool {
        mode == .iCloud
    }
}

public enum HiveCloudSyncSettingsStore {
    public static let modeKey = "hive.iCloud.mode"
    public static let firstChoiceMadeKey = "hive.iCloud.firstChoiceMade"

    public static func load(defaults: UserDefaults = .standard) -> HiveCloudSyncSettings {
        let rawMode = defaults.string(forKey: modeKey) ?? HiveCloudSyncMode.default.rawValue
        return HiveCloudSyncSettings(mode: HiveCloudSyncMode(rawValue: rawMode) ?? .default)
    }

    public static func save(_ settings: HiveCloudSyncSettings, defaults: UserDefaults = .standard) {
        defaults.set(settings.mode.rawValue, forKey: modeKey)
        defaults.set(true, forKey: firstChoiceMadeKey)
    }

    public static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: modeKey)
        defaults.removeObject(forKey: firstChoiceMadeKey)
    }
}

public struct HiveCloudSyncPolicy: Hashable, Sendable {
    public var defaultContainerIdentifier: String
    public var offersOneWholeVaultChoice: Bool
    public var avoidsPerDocumentStorageChoices: Bool
    public var storesOnlyUserCreatedContent: Bool
    public var excludesRegenerableContent: Set<String>
    public var keepsAppStateInCloud: Bool
    public var warnsBeforeDeletingEverywhere: Bool
    public var resolvesConflictsEarly: Bool
    public var includesCloudContentInSearch: Bool
    public var unobtrusiveUnavailableMessage: String

    public init(
        defaultContainerIdentifier: String = "iCloud.local.hive.desktop",
        offersOneWholeVaultChoice: Bool = true,
        avoidsPerDocumentStorageChoices: Bool = true,
        storesOnlyUserCreatedContent: Bool = true,
        excludesRegenerableContent: Set<String> = ["Models", "Snapshots", "Artifacts"],
        keepsAppStateInCloud: Bool = true,
        warnsBeforeDeletingEverywhere: Bool = true,
        resolvesConflictsEarly: Bool = true,
        includesCloudContentInSearch: Bool = true,
        unobtrusiveUnavailableMessage: String = "iCloud is unavailable. Changes stay on this device until iCloud is back."
    ) {
        self.defaultContainerIdentifier = defaultContainerIdentifier
        self.offersOneWholeVaultChoice = offersOneWholeVaultChoice
        self.avoidsPerDocumentStorageChoices = avoidsPerDocumentStorageChoices
        self.storesOnlyUserCreatedContent = storesOnlyUserCreatedContent
        self.excludesRegenerableContent = excludesRegenerableContent
        self.keepsAppStateInCloud = keepsAppStateInCloud
        self.warnsBeforeDeletingEverywhere = warnsBeforeDeletingEverywhere
        self.resolvesConflictsEarly = resolvesConflictsEarly
        self.includesCloudContentInSearch = includesCloudContentInSearch
        self.unobtrusiveUnavailableMessage = unobtrusiveUnavailableMessage
    }

    public static let `default` = HiveCloudSyncPolicy()

    public var followsICloudGuidance: Bool {
        offersOneWholeVaultChoice
            && avoidsPerDocumentStorageChoices
            && storesOnlyUserCreatedContent
            && excludesRegenerableContent.isSuperset(of: ["Models", "Snapshots", "Artifacts"])
            && keepsAppStateInCloud
            && warnsBeforeDeletingEverywhere
            && resolvesConflictsEarly
            && includesCloudContentInSearch
    }
}

public enum HiveCloudSyncStatus: Hashable, Sendable {
    case localOnly
    case available(URL)
    case unavailable(String)

    public var title: String {
        switch self {
        case .localOnly:
            return "Stored on this device"
        case .available:
            return "Using iCloud"
        case .unavailable:
            return "Waiting for iCloud"
        }
    }

    public var message: String {
        switch self {
        case .localOnly:
            return "Hive works locally. Turn on iCloud when you want the same Hive on your Apple devices."
        case .available:
            return "Field sources, Colony articles, The Hive map, and app state can stay current across devices."
        case .unavailable(let message):
            return message
        }
    }

    public static func current(
        settings: HiveCloudSyncSettings = HiveCloudSyncSettingsStore.load(),
        policy: HiveCloudSyncPolicy = .default,
        fileManager: FileManager = .default
    ) -> HiveCloudSyncStatus {
        guard settings.mode == .iCloud else { return .localOnly }
        guard fileManager.ubiquityIdentityToken != nil else {
            return .unavailable(policy.unobtrusiveUnavailableMessage)
        }
        guard let root = HiveCloudSyncLocator.iCloudRootURL(policy: policy, fileManager: fileManager) else {
            return .unavailable(policy.unobtrusiveUnavailableMessage)
        }
        return .available(root)
    }
}

public enum HiveCloudSyncLocator {
    public static func iCloudRootURL(
        policy: HiveCloudSyncPolicy = .default,
        fileManager: FileManager = .default
    ) -> URL? {
        fileManager.url(forUbiquityContainerIdentifier: policy.defaultContainerIdentifier)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Hive", isDirectory: true)
    }

    public static func preferredRootURL(
        settings: HiveCloudSyncSettings = HiveCloudSyncSettingsStore.load(),
        policy: HiveCloudSyncPolicy = .default,
        fileManager: FileManager = .default
    ) -> URL? {
        guard settings.mode == .iCloud else { return nil }
        return iCloudRootURL(policy: policy, fileManager: fileManager)
    }
}

public struct HiveCloudContentPlan: Codable, Hashable, Sendable {
    public var userContentDirectories: [String]
    public var localOnlyDirectories: [String]
    public var searchIncludesCloudContent: Bool
    public var deletionWarning: String
    public var conflictResolutionLabel: String

    public init(
        userContentDirectories: [String] = ["Raw", "Vault"],
        localOnlyDirectories: [String] = ["Models", "Snapshots", "Artifacts"],
        searchIncludesCloudContent: Bool = true,
        deletionWarning: String = "Deleting synced Hive content removes it from iCloud and every device.",
        conflictResolutionLabel: String = "Choose the version to keep"
    ) {
        self.userContentDirectories = userContentDirectories
        self.localOnlyDirectories = localOnlyDirectories
        self.searchIncludesCloudContent = searchIncludesCloudContent
        self.deletionWarning = deletionWarning
        self.conflictResolutionLabel = conflictResolutionLabel
    }

    public var respectsICloudStorage: Bool {
        localOnlyDirectories.contains("Models")
            && localOnlyDirectories.contains("Snapshots")
            && localOnlyDirectories.contains("Artifacts")
            && userContentDirectories.contains("Raw")
            && userContentDirectories.contains("Vault")
            && searchIncludesCloudContent
    }
}

public struct HiveCloudAppStateSnapshot: Codable, Hashable, Sendable {
    public var selectedSurface: String
    public var selectedPageID: String?
    public var selectedNodeID: String?
    public var updatedAt: Date

    public init(
        selectedSurface: String,
        selectedPageID: String? = nil,
        selectedNodeID: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.selectedSurface = selectedSurface
        self.selectedPageID = selectedPageID
        self.selectedNodeID = selectedNodeID
        self.updatedAt = updatedAt
    }
}

public struct HiveCloudAppStateSync: Sendable {
    public static let key = "hive.iCloud.appState"

    public init() {}

    @discardableResult
    public func publish(
        _ snapshot: HiveCloudAppStateSnapshot,
        settings: HiveCloudSyncSettings = HiveCloudSyncSettingsStore.load(),
        store: NSUbiquitousKeyValueStore = .default
    ) -> Bool {
        guard settings.mode == .iCloud, settings.syncsAppState else { return false }
        guard let data = try? JSONEncoder().encode(snapshot) else { return false }
        store.set(data, forKey: Self.key)
        return store.synchronize()
    }

    public func load(
        settings: HiveCloudSyncSettings = HiveCloudSyncSettingsStore.load(),
        store: NSUbiquitousKeyValueStore = .default
    ) -> HiveCloudAppStateSnapshot? {
        guard settings.mode == .iCloud, settings.syncsAppState else { return nil }
        guard let data = store.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(HiveCloudAppStateSnapshot.self, from: data)
    }
}
