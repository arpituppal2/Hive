import Foundation
import SQLite3
#if os(macOS) && canImport(AppKit)
import AppKit
#endif

public struct LocalFileDiscoveryOptions: Sendable {
    public var roots: [URL]
    public var maxDepth: Int
    public var maxFiles: Int
    public var includeHidden: Bool

    public init(
        roots: [URL],
        maxDepth: Int = 4,
        maxFiles: Int = 2_000,
        includeHidden: Bool = false
    ) {
        self.roots = roots
        self.maxDepth = maxDepth
        self.maxFiles = maxFiles
        self.includeHidden = includeHidden
    }

    public static func defaultHomeFolders(home: URL? = nil) -> LocalFileDiscoveryOptions {
        _ = home
        return LocalFileDiscoveryOptions(roots: [])
    }
}

public struct BrowserProfile: Identifiable, Hashable, Sendable {
    public var id: String
    public var browserName: String
    public var profileName: String
    public var historyURL: URL

    public init(browserName: String, profileName: String, historyURL: URL) {
        self.browserName = browserName
        self.profileName = profileName
        self.historyURL = historyURL
        let fingerprint = Hashing.sha256(data: Data("\(browserName):\(profileName):\(historyURL.path)".utf8))
        self.id = "\(browserName):\(profileName):\(fingerprint.prefix(20))"
    }
}

public struct BrowserHistoryEntry: Hashable, Sendable {
    public var title: String
    public var url: String
    public var visitCount: Int
    public var lastVisitAt: Date?
    public var engagement: BrowserEngagementScore
}

public struct BrowserBookmarkFile: Identifiable, Hashable, Sendable {
    public var id: String
    public var browserName: String
    public var profileName: String
    public var bookmarksURL: URL

    public init(browserName: String, profileName: String, bookmarksURL: URL) {
        self.browserName = browserName
        self.profileName = profileName
        self.bookmarksURL = bookmarksURL
        let fingerprint = Hashing.sha256(data: Data("\(browserName):\(profileName):\(bookmarksURL.path)".utf8))
        self.id = "\(browserName):\(profileName):bookmarks:\(fingerprint.prefix(20))"
    }
}

public struct BrowserBookmarkEntry: Hashable, Sendable {
    public var title: String
    public var url: String
    public var addedAt: Date?
    public var engagement: BrowserEngagementScore
}

public struct AppUsageSnapshotEntry: Codable, Hashable, Sendable, Identifiable {
    public var appName: String
    public var bundleIdentifier: String?
    public var path: String?
    public var isRunning: Bool
    public var lastUsed: Date?
    public var useCount: Int?

    public var id: String {
        let base = bundleIdentifier ?? path ?? appName
        return Hashing.sha256(data: Data(base.utf8)).prefix(20).description
    }

    public init(
        appName: String,
        bundleIdentifier: String? = nil,
        path: String? = nil,
        isRunning: Bool = false,
        lastUsed: Date? = nil,
        useCount: Int? = nil
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.isRunning = isRunning
        self.lastUsed = lastUsed
        self.useCount = useCount
    }
}

public struct AppUsageSnapshot: Codable, Hashable, Sendable {
    public var capturedAt: Date
    public var sourceName: String
    public var entries: [AppUsageSnapshotEntry]

    public init(
        capturedAt: Date = Date(),
        sourceName: String = "Local app context",
        entries: [AppUsageSnapshotEntry]
    ) {
        self.capturedAt = capturedAt
        self.sourceName = sourceName
        self.entries = entries
    }
}

public struct BrowserProfileConsent: Identifiable, Codable, Hashable, Sendable {
    public enum ImportMode: String, Codable, Sendable {
        case off
        case reviewOnly
        case intentionalOnly

        public var displayName: String {
            switch self {
            case .off: "Off"
            case .reviewOnly: "Signals only"
            case .intentionalOnly: "Intentional"
            }
        }
    }

    public var id: String
    public var profileID: String
    public var importMode: ImportMode
    public var includeTitles: Bool
    public var stripQueryAndFragment: Bool
    public var domainBlocklist: [String]
    public var grantedAt: Date?
    public var revokedAt: Date?

    public init(
        profileID: String,
        importMode: ImportMode = .off,
        includeTitles: Bool = true,
        stripQueryAndFragment: Bool = true,
        domainBlocklist: [String] = [],
        grantedAt: Date? = nil,
        revokedAt: Date? = nil
    ) {
        self.id = profileID
        self.profileID = profileID
        self.importMode = importMode
        self.includeTitles = includeTitles
        self.stripQueryAndFragment = stripQueryAndFragment
        self.domainBlocklist = domainBlocklist
        self.grantedAt = grantedAt
        self.revokedAt = revokedAt
    }

    public var allowsImport: Bool {
        importMode != .off && revokedAt == nil && grantedAt != nil
    }
}

public struct PersonalDataDiscovery: Sendable {
    public init() {}

    public func currentAppUsageSnapshot(now: Date = Date()) -> AppUsageSnapshot {
        if Self.shouldSuppressLiveAppUsageSnapshot {
            return AppUsageSnapshot(capturedAt: now, sourceName: "Running Mac apps", entries: [])
        }
        #if os(macOS) && canImport(AppKit)
        let entries = NSWorkspace.shared.runningApplications.compactMap { app -> AppUsageSnapshotEntry? in
            guard app.activationPolicy == .regular else { return nil }
            let name = (app.localizedName ?? app.bundleIdentifier ?? app.bundleURL?.lastPathComponent ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return AppUsageSnapshotEntry(
                appName: name,
                bundleIdentifier: app.bundleIdentifier,
                path: app.bundleURL?.path,
                isRunning: !app.isTerminated,
                lastUsed: nil,
                useCount: nil
            )
        }
        return AppUsageSnapshot(capturedAt: now, sourceName: "Running Mac apps", entries: stableUniqueAppEntries(entries))
        #else
        _ = now
        return AppUsageSnapshot(entries: [])
        #endif
    }

    private static var shouldSuppressLiveAppUsageSnapshot: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["HIVE_DISABLE_LIVE_PERSONAL_CONTEXT"] == "1" {
            return true
        }
        return environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    public func discoverLocalFileSources(options: LocalFileDiscoveryOptions = .defaultHomeFolders()) throws -> [SourceRecord] {
        var results: [SourceRecord] = []
        let fileManager = FileManager.default
        for root in options.roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey],
                options: options.includeHidden ? [] : [.skipsHiddenFiles]
            ) else {
                continue
            }
            for case let url as URL in enumerator {
                if results.count >= options.maxFiles { return results }
                if shouldSkip(url) {
                    enumerator.skipDescendants()
                    continue
                }
                let depth = url.pathComponents.count - root.pathComponents.count
                if depth > options.maxDepth {
                    enumerator.skipDescendants()
                    continue
                }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey])
                guard values?.isRegularFile == true else { continue }
                let size = Int64(values?.fileSize ?? 0)
                let observed = values?.contentModificationDate ?? Date()
                let metadataHash = Hashing.sha256(data: Data(url.path.utf8))
                results.append(SourceRecord(
                    id: "local-discovery-\(metadataHash.prefix(20))",
                    kind: SourceTypeDetector.kind(for: url),
                    connector: "local-file-discovery",
                    uri: url.path,
                    title: url.lastPathComponent,
                    mimeType: SourceTypeDetector.mimeType(for: url),
                    sizeBytes: size,
                    sha256: metadataHash,
                    importedAt: Date(),
                    observedAt: observed,
                    retentionExpiresAt: HiveRawSourceRetention.fixedRawFileRetention.expirationDate(from: Date()),
                    privacyLabel: .privateSource,
                    status: .discovered
                ))
            }
        }
        return results
    }

    public func discoverBrowserProfiles(home: URL? = nil) -> [BrowserProfile] {
        #if os(macOS)
        let home = home ?? FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        let candidates = chromiumBrowserRoots(library: library)
        var profiles: [BrowserProfile] = []
        for (name, root) in candidates where FileManager.default.fileExists(atPath: root.path) {
            let profileNames = ["Default"] + ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [])
                .filter { $0.hasPrefix("Profile ") }
            for profileName in profileNames {
                let history = root.appendingPathComponent(profileName, isDirectory: true).appendingPathComponent("History")
                if FileManager.default.fileExists(atPath: history.path) {
                    profiles.append(BrowserProfile(browserName: name, profileName: profileName, historyURL: history))
                }
            }
        }
        let safariHistory = home.appendingPathComponent("Library/Safari/History.db")
        if FileManager.default.fileExists(atPath: safariHistory.path) {
            profiles.append(BrowserProfile(browserName: "Safari", profileName: "Default", historyURL: safariHistory))
        }
        return profiles.sorted { $0.id < $1.id }
        #else
        _ = home
        return []
        #endif
    }

    public func discoverBrowserBookmarkFiles(home: URL? = nil) -> [BrowserBookmarkFile] {
        #if os(macOS)
        let home = home ?? FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        let candidates = chromiumBrowserRoots(library: library)
        var files: [BrowserBookmarkFile] = []
        for (name, root) in candidates where FileManager.default.fileExists(atPath: root.path) {
            let profileNames = ["Default"] + ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [])
                .filter { $0.hasPrefix("Profile ") }
            for profileName in profileNames {
                let bookmarks = root.appendingPathComponent(profileName, isDirectory: true).appendingPathComponent("Bookmarks")
                if FileManager.default.fileExists(atPath: bookmarks.path) {
                    files.append(BrowserBookmarkFile(browserName: name, profileName: profileName, bookmarksURL: bookmarks))
                }
            }
        }
        let safariBookmarks = home.appendingPathComponent("Library/Safari/Bookmarks.plist")
        if FileManager.default.fileExists(atPath: safariBookmarks.path) {
            files.append(BrowserBookmarkFile(browserName: "Safari", profileName: "Default", bookmarksURL: safariBookmarks))
        }
        return uniqueBookmarkFiles(files)
        #else
        _ = home
        return []
        #endif
    }

    private func chromiumBrowserRoots(library: URL) -> [(String, URL)] {
        [
            ("Chrome", library.appendingPathComponent("Google/Chrome", isDirectory: true)),
            ("Chrome Canary", library.appendingPathComponent("Google/Chrome Canary", isDirectory: true)),
            ("Brave", library.appendingPathComponent("BraveSoftware/Brave-Browser", isDirectory: true)),
            ("Edge", library.appendingPathComponent("Microsoft Edge", isDirectory: true)),
            ("Arc", library.appendingPathComponent("Arc/User Data", isDirectory: true)),
            ("Comet", library.appendingPathComponent("Comet", isDirectory: true))
        ]
    }

    public func browserProfiles(fromExplicitURLs urls: [URL], fileManager: FileManager = .default) -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                profiles.append(contentsOf: explicitHistoryFiles(in: url, fileManager: fileManager).map {
                    BrowserProfile(browserName: explicitBrowserName(for: $0), profileName: $0.deletingLastPathComponent().lastPathComponent, historyURL: $0)
                })
            } else {
                profiles.append(BrowserProfile(browserName: explicitBrowserName(for: url), profileName: url.deletingLastPathComponent().lastPathComponent, historyURL: url))
            }
        }
        var seen = Set<String>()
        return profiles.filter { profile in
            guard !seen.contains(profile.historyURL.path) else { return false }
            seen.insert(profile.historyURL.path)
            return true
        }
    }

    public func browserBookmarkFiles(fromExplicitURLs urls: [URL], fileManager: FileManager = .default) -> [BrowserBookmarkFile] {
        var files: [BrowserBookmarkFile] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                files.append(contentsOf: explicitBookmarkFiles(in: url, fileManager: fileManager).map {
                    BrowserBookmarkFile(
                        browserName: explicitBrowserName(for: $0),
                        profileName: $0.deletingLastPathComponent().lastPathComponent,
                        bookmarksURL: $0
                    )
                })
            } else if url.lastPathComponent == "Bookmarks" || url.lastPathComponent == "Bookmarks.plist" {
                files.append(BrowserBookmarkFile(
                    browserName: explicitBrowserName(for: url),
                    profileName: url.deletingLastPathComponent().lastPathComponent,
                    bookmarksURL: url
                ))
            }
        }
        return uniqueBookmarkFiles(files)
    }

    private func shouldSkip(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") { return true }
        return [
            ".git", ".build", "node_modules", "DerivedData", "Library", "Applications",
            "Movies", "Music", "Pictures", "Photos Library.photoslibrary"
        ].contains(name)
    }

    private func explicitHistoryFiles(in root: URL, fileManager: FileManager) -> [URL] {
        let direct = root.appendingPathComponent("History")
        if fileManager.fileExists(atPath: direct.path) {
            return [direct]
        }
        let safari = root.appendingPathComponent("History.db")
        if fileManager.fileExists(atPath: safari.path) {
            return [safari]
        }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            if files.count >= 12 { break }
            let depth = url.pathComponents.count - root.pathComponents.count
            if depth > 2 {
                enumerator.skipDescendants()
                continue
            }
            if url.lastPathComponent == "History" || url.lastPathComponent == "History.db" {
                files.append(url)
            }
        }
        return files
    }

    private func explicitBookmarkFiles(in root: URL, fileManager: FileManager) -> [URL] {
        let direct = root.appendingPathComponent("Bookmarks")
        if fileManager.fileExists(atPath: direct.path) {
            return [direct]
        }
        let safari = root.appendingPathComponent("Bookmarks.plist")
        if fileManager.fileExists(atPath: safari.path) {
            return [safari]
        }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            if files.count >= 12 { break }
            let depth = url.pathComponents.count - root.pathComponents.count
            if depth > 2 {
                enumerator.skipDescendants()
                continue
            }
            if url.lastPathComponent == "Bookmarks" || url.lastPathComponent == "Bookmarks.plist" {
                files.append(url)
            }
        }
        return files
    }

    private func explicitBrowserName(for url: URL) -> String {
        url.lastPathComponent == "History.db" || url.lastPathComponent == "Bookmarks.plist" ? "Safari" : "Selected Browser"
    }

    private func uniqueBookmarkFiles(_ files: [BrowserBookmarkFile]) -> [BrowserBookmarkFile] {
        var seen = Set<String>()
        return files
            .sorted { $0.id < $1.id }
            .filter { file in
                guard !seen.contains(file.bookmarksURL.path) else { return false }
                seen.insert(file.bookmarksURL.path)
                return true
            }
    }

    private func stableUniqueAppEntries(_ entries: [AppUsageSnapshotEntry]) -> [AppUsageSnapshotEntry] {
        var seen = Set<String>()
        return entries
            .map { entry in
                AppUsageSnapshotEntry(
                    appName: sanitizedAppText(entry.appName, fallback: "App"),
                    bundleIdentifier: entry.bundleIdentifier.flatMap { sanitizedBundleIdentifier($0) },
                    path: entry.path.flatMap { sanitizedAppText($0, fallback: "") },
                    isRunning: entry.isRunning,
                    lastUsed: entry.lastUsed,
                    useCount: entry.useCount
                )
            }
            .filter { !$0.appName.isEmpty }
            .sorted { left, right in
                left.appName.localizedCaseInsensitiveCompare(right.appName) == .orderedAscending
            }
            .filter { entry in
                let key = entry.bundleIdentifier ?? entry.path ?? entry.appName.lowercased()
                guard !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }
    }

    private func sanitizedBundleIdentifier(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        let filtered = String(trimmed.unicodeScalars.filter { allowed.contains($0) })
        return filtered.isEmpty ? nil : String(filtered.prefix(160))
    }

    private func sanitizedAppText(_ value: String, fallback: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = collapsed.isEmpty ? fallback : collapsed
        return String(safe.prefix(220))
    }
}

public final class AppUsageSnapshotImporter: @unchecked Sendable {
    private let paths: HivePaths
    private let store: HiveStore
    private let knowledgeExtractor: DeterministicKnowledgeExtractor

    public init(
        paths: HivePaths,
        store: HiveStore,
        knowledgeExtractor: DeterministicKnowledgeExtractor = DeterministicKnowledgeExtractor()
    ) {
        self.paths = paths
        self.store = store
        self.knowledgeExtractor = knowledgeExtractor
    }

    @discardableResult
    public func importSnapshot(_ snapshot: AppUsageSnapshot) throws -> SourceRecord? {
        try paths.createDirectories()
        let entries = stableUniqueEntries(snapshot.entries)
        guard !entries.isEmpty else {
            try store.appendAudit(AuditEventRecord(
                eventType: "appUsageSnapshot.noEntries",
                targetType: "sourcePlugin",
                targetID: "appUsage",
                detail: "No local app context was available to import."
            ))
            return nil
        }

        let now = snapshot.capturedAt
        let sourceID = "app-usage-snapshot-\(Self.dayStamp(for: now))"
        let text = Self.snapshotText(snapshot: snapshot, entries: entries)
        let data = Data(text.utf8)
        let hash = Hashing.sha256(data: data)

        if let existing = try store.fetchSource(id: sourceID), existing.sha256 == hash {
            try store.appendAudit(AuditEventRecord(
                eventType: "appUsageSnapshot.skippedDuplicate",
                targetType: "source",
                targetID: sourceID,
                sourceRefs: [sourceID],
                detail: "Local app context has not changed since the last snapshot."
            ))
            return existing
        }

        let existing = try store.fetchSource(id: sourceID)
        try store.replaceDerivedContent(sourceID: sourceID)
        let artifactName = "app-usage-snapshot-\(hash).txt"
        let artifactURL = paths.artifacts.appendingPathComponent(artifactName)
        try data.write(to: artifactURL, options: [.atomic])

        let source = SourceRecord(
            id: sourceID,
            kind: .taskExport,
            connector: "app-usage-snapshot",
            uri: "app-usage://local/\(Self.dayStamp(for: now))",
            title: "App context snapshot",
            mimeType: "text/plain",
            sizeBytes: Int64(data.count),
            sha256: hash,
            importedAt: existing?.importedAt ?? now,
            observedAt: now,
            retentionExpiresAt: HiveRawSourceRetention.fixedRawFileRetention.expirationDate(from: now),
            pinned: existing?.pinned ?? false,
            privacyLabel: .cloudBlocked,
            status: .extracted
        )
        try store.saveSource(source)
        try store.saveRawBlob(RawBlobRecord(
            sourceID: source.id,
            contentAddress: artifactName,
            localPath: artifactURL.path,
            mimeType: "text/plain",
            sizeBytes: Int64(data.count),
            sha256: hash
        ))
        let artifact = ArtifactRecord(
            sourceID: source.id,
            artifactType: "app-usage-snapshot",
            localPath: artifactURL.path,
            inlineText: text,
            modelID: "deterministic-local:app-context"
        )
        try store.saveArtifact(artifact)
        let chunk = ChunkRecord(
            sourceID: source.id,
            artifactID: artifact.id,
            text: text,
            locationLabel: "local app context",
            extractionConfidence: 0.5
        )
        try store.saveChunk(chunk)
        for claim in knowledgeExtractor.claims(from: [chunk], source: source) {
            try store.saveClaim(claim)
        }
        for entity in knowledgeExtractor.entities(from: [chunk], source: source) {
            try store.saveEntity(entity)
        }
        try store.appendAudit(AuditEventRecord(
            eventType: "appUsageSnapshot.imported",
            targetType: "source",
            targetID: source.id,
            sourceRefs: [source.id],
            detail: "Imported \(entries.count) local app context rows as cloud-blocked Field evidence. Hive records app identity and usage metadata only, not private app contents."
        ))
        return source
    }

    public func decodeSnapshotJSON(_ data: Data) throws -> AppUsageSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppUsageSnapshot.self, from: data)
    }

    private func stableUniqueEntries(_ entries: [AppUsageSnapshotEntry]) -> [AppUsageSnapshotEntry] {
        var seen = Set<String>()
        return entries
            .map { entry in
                AppUsageSnapshotEntry(
                    appName: Self.clean(entry.appName, fallback: "App"),
                    bundleIdentifier: entry.bundleIdentifier.flatMap { Self.cleanBundleIdentifier($0) },
                    path: entry.path.flatMap { Self.clean($0, fallback: "") },
                    isRunning: entry.isRunning,
                    lastUsed: entry.lastUsed,
                    useCount: entry.useCount
                )
            }
            .filter { !$0.appName.isEmpty }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
            .filter { entry in
                let key = entry.bundleIdentifier ?? entry.path ?? entry.appName.lowercased()
                guard !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }
    }

    private static func snapshotText(snapshot: AppUsageSnapshot, entries: [AppUsageSnapshotEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        let captured = formatter.string(from: snapshot.capturedAt)
        let lines = entries.map { entry -> String in
            var parts = ["APP: \(entry.appName)"]
            if let bundleIdentifier = entry.bundleIdentifier { parts.append("bundle=\(bundleIdentifier)") }
            if let path = entry.path { parts.append("path=\(path)") }
            parts.append("running=\(entry.isRunning ? "yes" : "no")")
            if let lastUsed = entry.lastUsed { parts.append("lastUsed=\(formatter.string(from: lastUsed))") }
            if let useCount = entry.useCount { parts.append("uses=\(useCount)") }
            return parts.joined(separator: " | ")
        }
        return """
        app-usage-snapshot-v1
        Captured: \(captured)
        Source: \(clean(snapshot.sourceName, fallback: "Local app context"))
        Privacy: app identity and usage metadata only; no message, document, photo, mail, or private app database content.

        \(lines.joined(separator: "\n"))
        """
    }

    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func clean(_ value: String, fallback: String) -> String {
        let trimmed = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? fallback : trimmed).prefix(220))
    }

    private static func cleanBundleIdentifier(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        let filtered = String(trimmed.unicodeScalars.filter { allowed.contains($0) })
        return filtered.isEmpty ? nil : String(filtered.prefix(160))
    }
}

public final class BrowserHistoryImporter: @unchecked Sendable {
    private let paths: HivePaths
    private let store: HiveStore
    private let snapshotService: BrowserSnapshotService
    private let scorer: BrowserEngagementScorer
    private let knowledgeExtractor: DeterministicKnowledgeExtractor

    public init(
        paths: HivePaths,
        store: HiveStore,
        snapshotService: BrowserSnapshotService = BrowserSnapshotService(),
        scorer: BrowserEngagementScorer = BrowserEngagementScorer(),
        knowledgeExtractor: DeterministicKnowledgeExtractor = DeterministicKnowledgeExtractor()
    ) {
        self.paths = paths
        self.store = store
        self.snapshotService = snapshotService
        self.scorer = scorer
        self.knowledgeExtractor = knowledgeExtractor
    }

    @discardableResult
    public func importProfiles(
        _ profiles: [BrowserProfile],
        consent: [String: BrowserProfileConsent],
        maxEntriesPerProfile: Int = 500
    ) throws -> [SourceRecord] {
        try paths.createDirectories()
        var imported: [SourceRecord] = []
        for profile in profiles {
            guard let profileConsent = consent[profile.id], profileConsent.allowsImport else {
                try store.appendAudit(AuditEventRecord(
                    eventType: "browserHistory.skippedNoConsent",
                    targetType: "browserProfile",
                    targetID: profile.id,
                    detail: "Profile was discovered but not read because consent was not granted."
                ))
                continue
            }
            do {
                let snapshot = try snapshotService.makeSafeSQLiteSnapshot(sourceURL: profile.historyURL, destinationDirectory: paths.snapshots)
                defer { try? FileManager.default.removeItem(at: snapshot) }
                let entries = try readHistory(snapshotURL: snapshot, profile: profile, consent: profileConsent, limit: maxEntriesPerProfile)
                guard !entries.isEmpty else { continue }
                let sources = try saveBrowserHistorySources(profile: profile, entries: entries, consent: profileConsent)
                imported.append(contentsOf: sources)
            } catch {
                try store.appendAudit(AuditEventRecord(
                    eventType: "browserHistory.importNeedsPermission",
                    targetType: "browserProfile",
                    targetID: profile.id,
                    detail: "Hive could not read this browser history profile. Choose the profile folder or History file, or grant the app permission in macOS Privacy settings."
                ))
                continue
            }
        }
        return imported
    }

    private func saveBrowserHistorySources(
        profile: BrowserProfile,
        entries: [BrowserHistoryEntry],
        consent: BrowserProfileConsent
    ) throws -> [SourceRecord] {
        try retireLegacyProfileSource(for: profile)
        var imported: [SourceRecord] = []
        for entry in entries {
            imported.append(try saveBrowserHistoryEntry(profile: profile, entry: entry, consent: consent))
        }
        try store.appendAudit(AuditEventRecord(
            eventType: "browserHistory.imported",
            targetType: "browserProfile",
            targetID: profile.id,
            sourceRefs: imported.map(\.id),
            detail: "Imported \(imported.count) sanitized browser observations as separate Field entries in \(consent.importMode.displayName) mode; passive items remain incidental. Browser database snapshot was transient and deleted."
        ))
        return imported
    }

    private func saveBrowserHistoryEntry(
        profile: BrowserProfile,
        entry: BrowserHistoryEntry,
        consent: BrowserProfileConsent
    ) throws -> SourceRecord {
        let now = Date()
        let entryID = stableEntryID(for: profile, entry: entry)
        let sourceID = "browser-history-entry-\(entryID)"
        let sourceURI = "\(profileURI(for: profile))/\(entryID)"
        let capsuleLine = "\(entry.engagement.intent.rawValue.uppercased()): \(entry.title) — \(entry.url) — \(entry.engagement.reason)"
        let capsuleVersion = "browser-capsule-v2-host-only-line-chunks"
        let persistedCapsuleText = "\(capsuleVersion)\n\(capsuleLine)"
        let capsuleData = Data(persistedCapsuleText.utf8)
        let capsuleHash = Hashing.sha256(data: capsuleData)

        let duplicateSources = try store.fetchSources(includeForgotten: true).filter {
            ($0.connector == "browser-history-entry" || $0.connector == "browser-history-snapshot")
                && $0.uri == sourceURI
                && $0.id != sourceID
            && $0.deletionState != .fullForgotten
        }
        for duplicate in duplicateSources {
            try store.fullForgetSource(id: duplicate.id)
        }

        if let existing = try store.fetchSource(id: sourceID), existing.sha256 == capsuleHash {
            if existing.status == .needsReview || existing.status == .queued || existing.status == .extracting {
                try store.markSourceStatus(id: sourceID, status: .extracted)
            }
            try store.appendAudit(AuditEventRecord(
                eventType: "browserHistory.skippedDuplicate",
                targetType: "source",
                targetID: sourceID,
                sourceRefs: [sourceID],
                detail: "Browser history entry is unchanged; keeping existing sanitized Field item."
            ))
            var updated = existing
            updated.status = .extracted
            return updated
        }

        let existing = try store.fetchSource(id: sourceID)
        try store.replaceDerivedContent(sourceID: sourceID)
        let capsuleName = "browser-capsule-\(capsuleHash).txt"
        let capsuleURL = paths.artifacts.appendingPathComponent(capsuleName)
        try capsuleData.write(to: capsuleURL, options: [.atomic])
        let source = SourceRecord(
            id: sourceID,
            kind: .browserHistory,
            connector: "browser-history-entry",
            uri: sourceURI,
            title: entry.title,
            mimeType: "text/plain",
            sizeBytes: Int64(capsuleData.count),
            sha256: capsuleHash,
            importedAt: existing?.importedAt ?? now,
            observedAt: entry.lastVisitAt ?? now,
            retentionExpiresAt: HiveRawSourceRetention.fixedRawFileRetention.expirationDate(from: now),
            pinned: existing?.pinned ?? false,
            privacyLabel: .cloudBlocked,
            status: .extracted
        )
        try store.saveSource(source)
        try store.saveRawBlob(RawBlobRecord(
            sourceID: source.id,
            contentAddress: capsuleName,
            localPath: capsuleURL.path,
            mimeType: "text/plain",
            sizeBytes: Int64(capsuleData.count),
            sha256: capsuleHash
        ))
        let artifact = ArtifactRecord(
            sourceID: source.id,
            artifactType: "browser-history-entry",
            localPath: capsuleURL.path,
            inlineText: persistedCapsuleText,
            modelID: "deterministic-local:browser-history"
        )
        try store.saveArtifact(artifact)

        let chunk = ChunkRecord(
            sourceID: source.id,
            artifactID: artifact.id,
            text: capsuleLine,
            locationLabel: "browser history entry",
            extractionConfidence: 0.45
        )
        try store.saveChunk(chunk)
        let claims = knowledgeExtractor.claims(from: [chunk], source: source)
        for claim in claims {
            try store.saveClaim(claim)
        }
        let entityChunks = capsuleLine.hasPrefix("\(BrowserIntent.incidental.rawValue.uppercased()):") ? [] : [chunk]
        let entities = knowledgeExtractor.entities(from: entityChunks, source: source)
        for entity in entities {
            try store.saveEntity(entity)
        }
        return source
    }

    private func retireLegacyProfileSource(for profile: BrowserProfile) throws {
        let legacyURI = profileURI(for: profile)
        let legacySources = try store.fetchSources(includeForgotten: true).filter {
            $0.connector == "browser-history-snapshot"
                && $0.uri == legacyURI
                && $0.deletionState != .fullForgotten
        }
        for source in legacySources {
            try store.fullForgetSource(id: source.id)
        }
    }

    private func readHistory(
        snapshotURL: URL,
        profile: BrowserProfile,
        consent: BrowserProfileConsent,
        limit: Int
    ) throws -> [BrowserHistoryEntry] {
        if profile.browserName == "Safari" {
            return try readSafariHistory(snapshotURL: snapshotURL, consent: consent, limit: limit)
        }
        return try readChromiumHistory(snapshotURL: snapshotURL, consent: consent, limit: limit)
    }

    private func readChromiumHistory(
        snapshotURL: URL,
        consent: BrowserProfileConsent,
        limit: Int
    ) throws -> [BrowserHistoryEntry] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(snapshotURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT url, title, visit_count, last_visit_time
        FROM urls
        WHERE url IS NOT NULL AND url != ''
        ORDER BY last_visit_time DESC
        LIMIT ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(max(1, min(limit, 5_000))))

        var entries: [BrowserHistoryEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let urlCString = sqlite3_column_text(statement, 0) else { continue }
            let urlString = String(cString: urlCString)
            guard let url = URL(string: urlString),
                  URLSafetyPolicy().isAllowed(url),
                  !isBlockedByDomainList(url, consent: consent),
                  let sanitizedURL = sanitize(url, stripQueryAndFragment: consent.stripQueryAndFragment) else {
                continue
            }
            let displayURL = redactedDisplayURL(for: sanitizedURL)
            let title = consent.includeTitles
                ? safeBrowserTitle(sqlite3_column_text(statement, 1).map { String(cString: $0) }, fallback: displayURL)
                : displayURL
            let visitCount = Int(sqlite3_column_int(statement, 2))
            let lastVisit = chromeTimestampToDate(sqlite3_column_int64(statement, 3))
            let signal = BrowserVisitSignal(
                url: sanitizedURL,
                title: title,
                durationSeconds: 0,
                repeatCount: visitCount,
                bookmarked: false,
                downloaded: false,
                shared: false,
                activeInteractionCount: 0
            )
            let engagement = scorer.score(signal)
            if consent.importMode == .intentionalOnly && engagement.intent != .intentional {
                continue
            }
            entries.append(BrowserHistoryEntry(
                title: title,
                url: displayURL,
                visitCount: visitCount,
                lastVisitAt: lastVisit,
                engagement: engagement
            ))
        }
        return entries
    }

    private func readSafariHistory(
        snapshotURL: URL,
        consent: BrowserProfileConsent,
        limit: Int
    ) throws -> [BrowserHistoryEntry] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(snapshotURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT history_items.url, COALESCE(history_items.title, ''), COUNT(history_visits.id), MAX(history_visits.visit_time)
        FROM history_items
        LEFT JOIN history_visits ON history_visits.history_item = history_items.id
        WHERE history_items.url IS NOT NULL AND history_items.url != ''
        GROUP BY history_items.id
        ORDER BY MAX(history_visits.visit_time) DESC
        LIMIT ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(max(1, min(limit, 5_000))))

        var entries: [BrowserHistoryEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let urlCString = sqlite3_column_text(statement, 0) else { continue }
            let urlString = String(cString: urlCString)
            guard let url = URL(string: urlString),
                  URLSafetyPolicy().isAllowed(url),
                  !isBlockedByDomainList(url, consent: consent),
                  let sanitizedURL = sanitize(url, stripQueryAndFragment: consent.stripQueryAndFragment) else {
                continue
            }
            let displayURL = redactedDisplayURL(for: sanitizedURL)
            let title = consent.includeTitles
                ? safeBrowserTitle(sqlite3_column_text(statement, 1).map { String(cString: $0) }, fallback: displayURL)
                : displayURL
            let visitCount = Int(sqlite3_column_int(statement, 2))
            let lastVisit = safariTimestampToDate(sqlite3_column_double(statement, 3))
            let signal = BrowserVisitSignal(
                url: sanitizedURL,
                title: title,
                durationSeconds: 0,
                repeatCount: visitCount,
                bookmarked: false,
                downloaded: false,
                shared: false,
                activeInteractionCount: 0
            )
            let engagement = scorer.score(signal)
            if consent.importMode == .intentionalOnly && engagement.intent != .intentional {
                continue
            }
            entries.append(BrowserHistoryEntry(
                title: title,
                url: displayURL,
                visitCount: visitCount,
                lastVisitAt: lastVisit,
                engagement: engagement
            ))
        }
        return entries
    }

    private func chromeTimestampToDate(_ value: Int64) -> Date? {
        guard value > 0 else { return nil }
        let unixMicroseconds = value - 11_644_473_600_000_000
        return Date(timeIntervalSince1970: Double(unixMicroseconds) / 1_000_000)
    }

    private func safariTimestampToDate(_ value: Double) -> Date? {
        guard value > 0 else { return nil }
        return Date(timeIntervalSinceReferenceDate: value)
    }

    private func sanitize(_ url: URL, stripQueryAndFragment: Bool) -> URL? {
        guard stripQueryAndFragment else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }

    private func isBlockedByDomainList(_ url: URL, consent: BrowserProfileConsent) -> Bool {
        guard let host = url.host(percentEncoded: false)?.lowercased() else { return true }
        return consent.domainBlocklist.contains { blocked in
            let normalized = blocked.lowercased()
            return host == normalized || host.hasSuffix(".\(normalized)")
        }
    }

    private func profileURI(for profile: BrowserProfile) -> String {
        "browser-history://\(profile.browserName)/\(profile.profileName)"
    }

    private func stableEntryID(for profile: BrowserProfile, entry: BrowserHistoryEntry) -> String {
        Hashing.sha256(data: Data("\(profile.id):\(entry.title):\(entry.url)".utf8)).prefix(24).description
    }

    private func redactedDisplayURL(for url: URL) -> String {
        guard var host = url.host(percentEncoded: false)?.lowercased(), !host.isEmpty else {
            return "web page"
        }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }

    private func safeBrowserTitle(_ rawTitle: String?, fallback: String) -> String {
        let title = (rawTitle ?? "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return fallback }
        if title.contains("://") {
            return fallback
        }
        return String(title.prefix(90))
    }
}

public final class BrowserBookmarkImporter: @unchecked Sendable {
    private let paths: HivePaths
    private let store: HiveStore
    private let scorer: BrowserEngagementScorer
    private let knowledgeExtractor: DeterministicKnowledgeExtractor
    private let safetyPolicy: URLSafetyPolicy

    public init(
        paths: HivePaths,
        store: HiveStore,
        scorer: BrowserEngagementScorer = BrowserEngagementScorer(),
        knowledgeExtractor: DeterministicKnowledgeExtractor = DeterministicKnowledgeExtractor(),
        safetyPolicy: URLSafetyPolicy = URLSafetyPolicy()
    ) {
        self.paths = paths
        self.store = store
        self.scorer = scorer
        self.knowledgeExtractor = knowledgeExtractor
        self.safetyPolicy = safetyPolicy
    }

    @discardableResult
    public func importBookmarkFiles(
        _ files: [BrowserBookmarkFile],
        maxEntriesPerFile: Int = 500
    ) throws -> [SourceRecord] {
        try paths.createDirectories()
        var imported: [SourceRecord] = []
        for file in files {
            do {
                let entries = try readBookmarks(file: file, limit: maxEntriesPerFile)
                guard !entries.isEmpty else { continue }
                for entry in entries {
                    imported.append(try saveBookmarkEntry(file: file, entry: entry))
                }
                try store.appendAudit(AuditEventRecord(
                    eventType: "browserBookmarks.imported",
                    targetType: "browserBookmarks",
                    targetID: file.id,
                    sourceRefs: imported.map(\.id),
                    detail: "Imported \(entries.count) sanitized browser bookmarks as explicit Field evidence. Full bookmark URLs were reduced to safe host-level context."
                ))
            } catch {
                try store.appendAudit(AuditEventRecord(
                    eventType: "browserBookmarks.importNeedsPermission",
                    targetType: "browserBookmarks",
                    targetID: file.id,
                    detail: "Hive could not read this bookmark file. Choose the browser profile folder or grant the app permission in macOS Privacy settings."
                ))
            }
        }
        return imported
    }

    private func saveBookmarkEntry(file: BrowserBookmarkFile, entry: BrowserBookmarkEntry) throws -> SourceRecord {
        let now = Date()
        let entryID = stableEntryID(for: file, entry: entry)
        let sourceID = "browser-bookmark-entry-\(entryID)"
        let sourceURI = "\(fileURI(for: file))/\(entryID)"
        let capsuleLine = "BOOKMARK: \(entry.title) - \(entry.url) - saved browser bookmark"
        let capsuleVersion = "browser-bookmark-capsule-v1-host-only-line-chunks"
        let persistedCapsuleText = "\(capsuleVersion)\n\(capsuleLine)"
        let capsuleData = Data(persistedCapsuleText.utf8)
        let capsuleHash = Hashing.sha256(data: capsuleData)

        let duplicateSources = try store.fetchSources(includeForgotten: true).filter {
            $0.connector == "browser-bookmark-entry"
                && $0.uri == sourceURI
                && $0.id != sourceID
                && $0.deletionState != .fullForgotten
        }
        for duplicate in duplicateSources {
            try store.fullForgetSource(id: duplicate.id)
        }

        if let existing = try store.fetchSource(id: sourceID), existing.sha256 == capsuleHash {
            if existing.status == .needsReview || existing.status == .queued || existing.status == .extracting {
                try store.markSourceStatus(id: sourceID, status: .extracted)
            }
            try store.appendAudit(AuditEventRecord(
                eventType: "browserBookmarks.skippedDuplicate",
                targetType: "source",
                targetID: sourceID,
                sourceRefs: [sourceID],
                detail: "Browser bookmark is unchanged; keeping existing sanitized Field item."
            ))
            var updated = existing
            updated.status = .extracted
            return updated
        }

        let existing = try store.fetchSource(id: sourceID)
        try store.replaceDerivedContent(sourceID: sourceID)
        let capsuleName = "browser-bookmark-capsule-\(capsuleHash).txt"
        let capsuleURL = paths.artifacts.appendingPathComponent(capsuleName)
        try capsuleData.write(to: capsuleURL, options: [.atomic])
        let source = SourceRecord(
            id: sourceID,
            kind: .browserBookmark,
            connector: "browser-bookmark-entry",
            uri: sourceURI,
            title: entry.title,
            mimeType: "text/plain",
            sizeBytes: Int64(capsuleData.count),
            sha256: capsuleHash,
            importedAt: existing?.importedAt ?? now,
            observedAt: entry.addedAt ?? now,
            retentionExpiresAt: HiveRawSourceRetention.fixedRawFileRetention.expirationDate(from: now),
            pinned: existing?.pinned ?? false,
            privacyLabel: .cloudBlocked,
            status: .extracted
        )
        try store.saveSource(source)
        try store.saveRawBlob(RawBlobRecord(
            sourceID: source.id,
            contentAddress: capsuleName,
            localPath: capsuleURL.path,
            mimeType: "text/plain",
            sizeBytes: Int64(capsuleData.count),
            sha256: capsuleHash
        ))
        let artifact = ArtifactRecord(
            sourceID: source.id,
            artifactType: "browser-bookmark-entry",
            localPath: capsuleURL.path,
            inlineText: persistedCapsuleText,
            modelID: "deterministic-local:browser-bookmarks"
        )
        try store.saveArtifact(artifact)

        let chunk = ChunkRecord(
            sourceID: source.id,
            artifactID: artifact.id,
            text: capsuleLine,
            locationLabel: "browser bookmark",
            extractionConfidence: 0.62
        )
        try store.saveChunk(chunk)
        for claim in knowledgeExtractor.claims(from: [chunk], source: source) {
            try store.saveClaim(claim)
        }
        for entity in knowledgeExtractor.entities(from: [chunk], source: source) {
            try store.saveEntity(entity)
        }
        return source
    }

    private func readBookmarks(file: BrowserBookmarkFile, limit: Int) throws -> [BrowserBookmarkEntry] {
        if file.bookmarksURL.lastPathComponent == "Bookmarks.plist" {
            return try readSafariBookmarks(url: file.bookmarksURL, limit: limit)
        }
        return try readChromiumBookmarks(url: file.bookmarksURL, limit: limit)
    }

    private func readChromiumBookmarks(url: URL, limit: Int) throws -> [BrowserBookmarkEntry] {
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var entries: [BrowserBookmarkEntry] = []
        if let roots = root["roots"] as? [String: Any] {
            for value in roots.values {
                collectChromiumBookmarks(value, into: &entries, limit: limit)
            }
        }
        return entries
    }

    private func collectChromiumBookmarks(_ value: Any, into entries: inout [BrowserBookmarkEntry], limit: Int) {
        guard entries.count < limit, let item = value as? [String: Any] else { return }
        if item["type"] as? String == "url",
           let urlString = item["url"] as? String,
           let url = sanitizedPublicURL(from: urlString),
           let displayURL = redactedDisplayURL(for: url) {
            let title = safeBrowserTitle(item["name"] as? String, fallback: displayURL)
            let signal = BrowserVisitSignal(
                url: url,
                title: title,
                durationSeconds: 0,
                repeatCount: 1,
                bookmarked: true,
                downloaded: false,
                shared: false,
                activeInteractionCount: 1
            )
            entries.append(BrowserBookmarkEntry(
                title: title,
                url: displayURL,
                addedAt: chromeTimestampToDate(stringValue(item["date_added"])),
                engagement: scorer.score(signal)
            ))
        }
        guard let children = item["children"] as? [Any] else { return }
        for child in children where entries.count < limit {
            collectChromiumBookmarks(child, into: &entries, limit: limit)
        }
    }

    private func readSafariBookmarks(url: URL, limit: Int) throws -> [BrowserBookmarkEntry] {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        var entries: [BrowserBookmarkEntry] = []
        collectSafariBookmarks(plist, into: &entries, limit: limit)
        return entries
    }

    private func collectSafariBookmarks(_ value: Any, into entries: inout [BrowserBookmarkEntry], limit: Int) {
        guard entries.count < limit else { return }
        if let item = value as? [String: Any] {
            if item["WebBookmarkType"] as? String == "WebBookmarkTypeLeaf",
               let urlString = item["URLString"] as? String,
               let url = sanitizedPublicURL(from: urlString),
               let displayURL = redactedDisplayURL(for: url) {
                let dictionary = item["URIDictionary"] as? [String: Any]
                let title = safeBrowserTitle(dictionary?["title"] as? String ?? item["Title"] as? String, fallback: displayURL)
                let signal = BrowserVisitSignal(
                    url: url,
                    title: title,
                    durationSeconds: 0,
                    repeatCount: 1,
                    bookmarked: true,
                    downloaded: false,
                    shared: false,
                    activeInteractionCount: 1
                )
                entries.append(BrowserBookmarkEntry(
                    title: title,
                    url: displayURL,
                    addedAt: item["dateAdded"] as? Date,
                    engagement: scorer.score(signal)
                ))
            }
            if let children = item["Children"] as? [Any] {
                for child in children where entries.count < limit {
                    collectSafariBookmarks(child, into: &entries, limit: limit)
                }
            }
        } else if let children = value as? [Any] {
            for child in children where entries.count < limit {
                collectSafariBookmarks(child, into: &entries, limit: limit)
            }
        }
    }

    private func sanitizedPublicURL(from value: String) -> URL? {
        guard let original = URL(string: value), safetyPolicy.isAllowed(original) else { return nil }
        var components = URLComponents(url: original, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }

    private func redactedDisplayURL(for url: URL) -> String? {
        guard var host = url.host(percentEncoded: false)?.lowercased(), !host.isEmpty else {
            return nil
        }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }

    private func safeBrowserTitle(_ rawTitle: String?, fallback: String) -> String {
        let title = (rawTitle ?? "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return fallback }
        if title.contains("://") {
            return fallback
        }
        return String(title.prefix(140))
    }

    private func stringValue(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private func chromeTimestampToDate(_ value: String?) -> Date? {
        guard let value, let raw = Int64(value), raw > 0 else { return nil }
        let unixMicroseconds = raw - 11_644_473_600_000_000
        return Date(timeIntervalSince1970: Double(unixMicroseconds) / 1_000_000)
    }

    private func fileURI(for file: BrowserBookmarkFile) -> String {
        "browser-bookmarks://\(file.browserName)/\(file.profileName)"
    }

    private func stableEntryID(for file: BrowserBookmarkFile, entry: BrowserBookmarkEntry) -> String {
        Hashing.sha256(data: Data("\(file.id):\(entry.title):\(entry.url)".utf8)).prefix(24).description
    }
}
