import Foundation

public enum HiveRawSourceRetention: String, CaseIterable, Codable, Identifiable, Sendable {
    case fortyEightHours = "48h"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .fortyEightHours:
            return "48 hours"
        }
    }

    public func expirationDate(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .hour, value: 48, to: date) ?? date.addingTimeInterval(48 * 3_600)
    }

    public static var fixedRawFileRetention: HiveRawSourceRetention { .fortyEightHours }
}

public struct HiveLearningSettings: Codable, Hashable, Sendable {
    public var connectionAggression: Double
    public var sensitiveTopics: String
    public var learnsFromBrowserCaptures: Bool
    public var learnsFromFiles: Bool
    public var learnsFromCalendar: Bool
    public var rawSourceRetention: HiveRawSourceRetention

    public init(
        connectionAggression: Double = 0.5,
        sensitiveTopics: String = "",
        learnsFromBrowserCaptures: Bool = true,
        learnsFromFiles: Bool = true,
        learnsFromCalendar: Bool = false,
        rawSourceRetention: HiveRawSourceRetention = .fixedRawFileRetention
    ) {
        self.connectionAggression = min(1, max(0, connectionAggression))
        self.sensitiveTopics = sensitiveTopics.trimmingCharacters(in: .whitespacesAndNewlines)
        self.learnsFromBrowserCaptures = learnsFromBrowserCaptures
        self.learnsFromFiles = learnsFromFiles
        self.learnsFromCalendar = learnsFromCalendar
        _ = rawSourceRetention
        self.rawSourceRetention = .fixedRawFileRetention
    }

    public static let defaultValue = HiveLearningSettings()

    public var connectionAggressionLabel: String {
        switch connectionAggression {
        case ..<0.34:
            return "Cautious"
        case 0.67...:
            return "Aggressive"
        default:
            return "Balanced"
        }
    }

    public var relationshipStrengthMultiplier: Double {
        0.78 + connectionAggression * 0.48
    }

    public var relationshipConfidenceMultiplier: Double {
        0.92 + connectionAggression * 0.12
    }

    public var minimumTokenOverlapForConnection: Int {
        connectionAggression < 0.34 ? 2 : 1
    }

    public var markovTransitionMinimumProbability: Double {
        max(0.08, 0.22 - connectionAggression * 0.14)
    }

    public var maximumMarkovLoopCount: Int {
        max(2, Int((4 + connectionAggression * 10).rounded()))
    }

    public var maximumHamiltonianPathCount: Int {
        max(2, Int((3 + connectionAggression * 7).rounded()))
    }

    public func adjustedRelationshipStrength(_ base: Double) -> Double {
        min(1, max(0, base * relationshipStrengthMultiplier))
    }

    public func adjustedRelationshipConfidence(_ base: Double) -> Double {
        min(1, max(0, base * relationshipConfidenceMultiplier))
    }

    public func allows(sourcePlugin kind: HiveStartupSourcePluginKind) -> Bool {
        switch kind {
        case .browserHistory, .appUsage:
            return learnsFromBrowserCaptures
        case .googleDrive, .uploads, .localDisk, .downloadsFolder:
            return learnsFromFiles
        case .webPages:
            return true
        }
    }
}

public enum HiveLearningSettingsStore {
    public static let connectionAggressionKey = "hive.learning.connectionAggression"
    public static let sensitiveTopicsKey = "hive.learning.sensitiveTopics"
    public static let learnsFromBrowserCapturesKey = "hive.learning.learnsFromBrowserCaptures"
    public static let learnsFromFilesKey = "hive.learning.learnsFromFiles"
    public static let learnsFromCalendarKey = "hive.learning.learnsFromCalendar"
    public static let rawSourceRetentionKey = "hive.learning.rawSourceRetention"

    public static func load(defaults: UserDefaults = .standard) -> HiveLearningSettings {
        HiveLearningSettings(
            connectionAggression: double(
                forKey: connectionAggressionKey,
                defaults: defaults,
                defaultValue: HiveLearningSettings.defaultValue.connectionAggression
            ),
            sensitiveTopics: defaults.string(forKey: sensitiveTopicsKey) ?? HiveLearningSettings.defaultValue.sensitiveTopics,
            learnsFromBrowserCaptures: bool(
                forKey: learnsFromBrowserCapturesKey,
                defaults: defaults,
                defaultValue: HiveLearningSettings.defaultValue.learnsFromBrowserCaptures
            ),
            learnsFromFiles: bool(
                forKey: learnsFromFilesKey,
                defaults: defaults,
                defaultValue: HiveLearningSettings.defaultValue.learnsFromFiles
            ),
            learnsFromCalendar: bool(
                forKey: learnsFromCalendarKey,
                defaults: defaults,
                defaultValue: HiveLearningSettings.defaultValue.learnsFromCalendar
            ),
            rawSourceRetention: HiveRawSourceRetention.fixedRawFileRetention
        )
    }

    public static func save(_ settings: HiveLearningSettings, defaults: UserDefaults = .standard) {
        defaults.set(settings.connectionAggression, forKey: connectionAggressionKey)
        defaults.set(settings.sensitiveTopics, forKey: sensitiveTopicsKey)
        defaults.set(settings.learnsFromBrowserCaptures, forKey: learnsFromBrowserCapturesKey)
        defaults.set(settings.learnsFromFiles, forKey: learnsFromFilesKey)
        defaults.set(settings.learnsFromCalendar, forKey: learnsFromCalendarKey)
        defaults.set(HiveRawSourceRetention.fixedRawFileRetention.rawValue, forKey: rawSourceRetentionKey)
    }

    public static func reset(defaults: UserDefaults = .standard) {
        [
            connectionAggressionKey,
            sensitiveTopicsKey,
            learnsFromBrowserCapturesKey,
            learnsFromFilesKey,
            learnsFromCalendarKey,
            rawSourceRetentionKey
        ].forEach(defaults.removeObject(forKey:))
    }

    private static func bool(forKey key: String, defaults: UserDefaults, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private static func double(forKey key: String, defaults: UserDefaults, defaultValue: Double) -> Double {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.double(forKey: key)
    }
}
