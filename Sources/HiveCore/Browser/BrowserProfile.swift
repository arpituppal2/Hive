import Foundation

// MARK: - BrowserProfile
//
// A named browser profile (\"Work\", \"Personal\", \"Development\", etc.) with its own
// session, preferences, history, bookmarks, and credential store. Profiles are
// mutually isolated — switching profiles loads a completely separate browser state.
//
// The default profile is created on first launch and can never be deleted. Additional
// profiles share the same app binary but maintain separate data directories under
// ~/Library/Application Support/Hive/Profiles/<profile-id>/.

public struct BrowserProfile: Identifiable, Sendable, Codable, Equatable {
    /// Stable UUID for the profile.
    public let id: String
    /// User-visible name (e.g., \"Work\", \"Personal\").
    public var name: String
    /// When the profile was created.
    public let createdAt: Date
    /// Whether this is the default profile (created on first launch, undeletable).
    public let isDefault: Bool
    /// Order index for the profile switcher UI. Lower = earlier in the list.
    public var sortOrder: Int

    public init(id: String = UUID().uuidString,
                name: String,
                createdAt: Date = Date(),
                isDefault: Bool = false,
                sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }

    /// The on-disk directory for this profile's data.
    public var profileDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Hive/Profiles/\(id)")
    }

    /// Default profile factory. Created on first launch, never deletable.
    public static func defaultProfile() -> BrowserProfile {
        BrowserProfile(name: "Default", isDefault: true, sortOrder: 0)
    }
}

// MARK: - ProfileManager
//
// Manages the roster of browser profiles, persisted as JSON in the app's
// Application Support directory. The active profile ID is stored in UserDefaults
// so it survives restarts without loading all profile data first.
//
// Each profile gets its own:
//   - {profileDir}/session.json        (BrowserSession)
//   - {profileDir}/honeycomb.db         (HoneycombStore)
//   - {profileDir}/eventledger.db       (EventLedgerStore)
//   - Keychain access group (scoped per profile via kSecAttrService suffix)

public actor ProfileManager {

    /// The roster of available profiles.
    public private(set) var profiles: [BrowserProfile] = []

    /// The currently active profile ID.
    public private(set) var activeProfileID: String

    /// On-disk storage path for the profile roster.
    private let rosterURL: URL

    /// The profiles root directory.
    private let profilesRoot: URL

    // MARK: - Init

    public init() {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Hive")
        self.profilesRoot = appSupport.appendingPathComponent("Profiles")
        self.rosterURL = profilesRoot.appendingPathComponent("profiles.json")

        // Load existing profile roster or bootstrap with a default profile.
        if let loaded = Self.loadRoster(from: rosterURL), !loaded.isEmpty {
            self.profiles = loaded
            // Restore last active profile or fall back to default.
            let savedActive = UserDefaults.standard.string(forKey: "Hive.activeProfileID")
            if let saved = savedActive, loaded.contains(where: { $0.id == saved }) {
                self.activeProfileID = saved
            } else if let first = loaded.first {
                self.activeProfileID = first.id
            } else {
                // Fallback — shouldn't happen since loaded is non-empty.
                self.activeProfileID = loaded[0].id
            }
        } else {
            // First launch — create the default profile.
            let defaultProfile = BrowserProfile.defaultProfile()
            self.profiles = [defaultProfile]
            self.activeProfileID = defaultProfile.id
            UserDefaults.standard.set(defaultProfile.id, forKey: "Hive.activeProfileID")
            // Ensure directory structure exists.
            try? FileManager.default.createDirectory(at: profilesRoot,
                                                     withIntermediateDirectories: true)
            Self.saveRoster([defaultProfile], to: rosterURL)
            // Create the default profile's data directory.
            try? FileManager.default.createDirectory(at: defaultProfile.profileDirectory,
                                                     withIntermediateDirectories: true)
        }
    }

    // MARK: - Public API

    /// The currently active profile. Returns the default if the active ID is stale.
    public var activeProfile: BrowserProfile {
        profiles.first { $0.id == activeProfileID } ?? profiles.first ?? BrowserProfile.defaultProfile()
    }

    /// Creates a new profile with the given name. Returns the created profile.
    /// The new profile is NOT automatically activated — call switchTo(_:) to switch.
    @discardableResult
    public func createProfile(name: String) -> BrowserProfile {
        let maxOrder = profiles.map(\.sortOrder).max() ?? 0
        let profile = BrowserProfile(name: name, sortOrder: maxOrder + 1)
        profiles.append(profile)
        // Create the profile's data directory.
        try? FileManager.default.createDirectory(at: profile.profileDirectory,
                                                 withIntermediateDirectories: true)
        persistRoster()
        return profile
    }

    /// Switches to the profile with the given ID. No-op if already active.
    /// The caller (ChromeState) is responsible for tearing down the current state
    /// and loading the new profile's data.
    public func switchTo(_ profileID: String) -> Bool {
        guard profiles.contains(where: { $0.id == profileID }),
              profileID != activeProfileID else { return false }
        activeProfileID = profileID
        UserDefaults.standard.set(profileID, forKey: "Hive.activeProfileID")
        return true
    }

    /// Renames a profile. The default profile can be renamed.
    public func renameProfile(_ profileID: String, to name: String) {
        guard let idx = profiles.firstIndex(where: { $0.id == profileID }),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        profiles[idx].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persistRoster()
    }

    /// Deletes a profile. The default profile cannot be deleted. If the deleted
    /// profile was active, switches to the default. Returns true if deleted.
    @discardableResult
    public func deleteProfile(_ profileID: String) -> Bool {
        guard let profile = profiles.first(where: { $0.id == profileID }),
              !profile.isDefault else { return false }
        profiles.removeAll { $0.id == profileID }

        // Remove the profile's data directory.
        try? FileManager.default.removeItem(at: profile.profileDirectory)

        // If the deleted profile was active, switch to default.
        if activeProfileID == profileID, let def = profiles.first(where: { $0.isDefault }) {
            activeProfileID = def.id
            UserDefaults.standard.set(def.id, forKey: "Hive.activeProfileID")
        }
        persistRoster()
        return true
    }

    /// Reorders profiles. `orderedIDs` must contain exactly the same set of profile IDs.
    public func reorderProfiles(_ orderedIDs: [String]) {
        guard Set(orderedIDs) == Set(profiles.map(\.id)) else { return }
        var reordered: [BrowserProfile] = []
        for id in orderedIDs {
            if let p = profiles.first(where: { $0.id == id }) {
                var updated = p
                updated.sortOrder = reordered.count
                reordered.append(updated)
            }
        }
        profiles = reordered
        persistRoster()
    }

    /// Returns the Keychain access group suffix for a profile, used to namespace
    /// credentials per profile. The default profile uses no suffix for backward compat.
    public func keychainServiceName(for profileID: String) -> String {
        let profile = profiles.first { $0.id == profileID }
        if profile?.isDefault == true {
            return "com.hive.browser.password"
        }
        return "com.hive.browser.password.\(profileID)"
    }

    // MARK: - Persistence

    private func persistRoster() {
        Self.saveRoster(profiles, to: rosterURL)
    }

    private static func saveRoster(_ profiles: [BrowserProfile], to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(profiles) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func loadRoster(from url: URL) -> [BrowserProfile]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([BrowserProfile].self, from: data)
    }
}
