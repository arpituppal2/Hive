import Foundation

public enum HiveSourcePluginToggleStore {
    public static func defaultsKey(for kind: HiveStartupSourcePluginKind) -> String {
        switch kind {
        case .googleDrive:
            return "hive.plugin.googledrive.enabled"
        case .webPages:
            return "hive.plugin.links.enabled"
        case .uploads:
            return "hive.plugin.uploads.enabled"
        case .localDisk:
            return "hive.plugin.localdisk.enabled"
        case .downloadsFolder:
            return "hive.plugin.downloads.enabled"
        case .browserHistory:
            return "hive.plugin.browser.enabled"
        case .appUsage:
            return "hive.plugin.apps.enabled"
        }
    }

    public static func bookmarkKey(for kind: HiveStartupSourcePluginKind) -> String? {
        switch kind {
        case .localDisk:
            return "hive.plugin.localdisk.bookmark"
        case .downloadsFolder:
            return "hive.plugin.downloads.bookmark"
        default:
            return nil
        }
    }

    public static func isEnabled(_ kind: HiveStartupSourcePluginKind, defaults: UserDefaults = .standard) -> Bool {
        let key = defaultsKey(for: kind)
        if defaults.object(forKey: key) == nil {
            return kind.startupDefaultEnabled
        }
        return defaults.bool(forKey: key)
    }

    public static func setEnabled(_ kind: HiveStartupSourcePluginKind, _ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: defaultsKey(for: kind))
        defaults.synchronize()
    }

    public static func loadSelections(defaults: UserDefaults = .standard) -> [HiveStartupSourcePluginSelection] {
        HiveStartupSourcePluginCatalog.orderedKinds.map { kind in
            HiveStartupSourcePluginSelection(kind: kind, isEnabled: isEnabled(kind, defaults: defaults))
        }
    }

    public static func persistBookmark(_ data: Data, for kind: HiveStartupSourcePluginKind, defaults: UserDefaults = .standard) {
        guard let key = bookmarkKey(for: kind) else { return }
        defaults.set(data, forKey: key)
        defaults.synchronize()
    }

    public static func loadBookmark(for kind: HiveStartupSourcePluginKind, defaults: UserDefaults = .standard) -> Data? {
        guard let key = bookmarkKey(for: kind) else { return nil }
        return defaults.data(forKey: key)
    }

    public static func clearBookmark(for kind: HiveStartupSourcePluginKind, defaults: UserDefaults = .standard) {
        guard let key = bookmarkKey(for: kind) else { return }
        defaults.removeObject(forKey: key)
    }
}

public enum PasteInputType: Sendable {
    case googleDriveURL
    case webURL
    case localPath
    case downloadsFilename
    case unknown
}

public enum PasteInputClassifier {
    public static func classify(_ input: String) -> PasteInputType {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.contains("drive.google.com") || lower.contains("docs.google.com") {
            return .googleDriveURL
        }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return .webURL
        }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return .localPath
        }
        if !trimmed.contains("/") && trimmed.contains(".") {
            return .downloadsFilename
        }
        return .unknown
    }

    public static func requiredPlugin(for type: PasteInputType) -> HiveStartupSourcePluginKind? {
        switch type {
        case .googleDriveURL:
            return .googleDrive
        case .webURL:
            return .webPages
        case .localPath:
            return .localDisk
        case .downloadsFilename:
            return .downloadsFolder
        case .unknown:
            return nil
        }
    }
}
