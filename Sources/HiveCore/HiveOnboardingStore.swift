import Foundation

/// Single source of truth for onboarding completion persistence.
public enum HiveOnboardingStore {
    public static let completedKey = "hive.onboarding.completed"
    private static let legacyKey = "hive.hasSeenOnboarding"

    public static func migrateLegacyIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: completedKey) == nil else { return }
        if defaults.bool(forKey: legacyKey) {
            defaults.set(true, forKey: completedKey)
            defaults.removeObject(forKey: legacyKey)
        }
    }

    public static func isCompleted(defaults: UserDefaults = .standard) -> Bool {
        migrateLegacyIfNeeded(defaults: defaults)
        return defaults.bool(forKey: completedKey)
    }

    public static func markCompleted(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: completedKey)
        defaults.synchronize()
        defaults.removeObject(forKey: legacyKey)
    }

    public static func resetForReplay(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: completedKey)
        defaults.removeObject(forKey: legacyKey)
        defaults.synchronize()
    }
}
