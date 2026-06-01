import Foundation

public enum HiveStartupSourcePluginKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case googleDrive
    case webPages
    case uploads
    case localDisk
    case downloadsFolder
    case browserHistory
    case appUsage

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .googleDrive:
            return "Google Drive"
        case .webPages:
            return "Links and web pages"
        case .uploads:
            return "Uploads"
        case .localDisk:
            return "Local disk"
        case .downloadsFolder:
            return "Downloads"
        case .browserHistory:
            return "Browser data"
        case .appUsage:
            return "Apps"
        }
    }

    public var summary: String {
        switch self {
        case .googleDrive:
            return "Paste Drive files or folder links. Hive treats Drive as a first-class source without scanning it silently."
        case .webPages:
            return "Paste article links or capture the current page from the menu bar."
        case .uploads:
            return "Attach PDFs, screenshots, audio, notes, books, or folders."
        case .localDisk:
            return "Paste a local file or folder path when you want Hive to read it."
        case .downloadsFolder:
            return "Point Hive at specific downloads you want organized."
        case .browserHistory:
            return "Import approved history and bookmarks; low-value visits stay out of The Hive."
        case .appUsage:
            return "Import local app context only; Hive records app identity and usage metadata, not private app contents."
        }
    }

    public var startupDefaultEnabled: Bool {
        switch self {
        case .googleDrive, .webPages, .uploads:
            return true
        case .localDisk, .downloadsFolder, .browserHistory, .appUsage:
            return false
        }
    }

    public var handlesPrivateMaterial: Bool {
        switch self {
        case .localDisk, .downloadsFolder, .browserHistory, .appUsage, .googleDrive:
            return true
        case .webPages, .uploads:
            return false
        }
    }
}

public struct HiveStartupSourcePluginSelection: Identifiable, Codable, Hashable, Sendable {
    public var kind: HiveStartupSourcePluginKind
    public var isEnabled: Bool

    public var id: HiveStartupSourcePluginKind { kind }

    public init(kind: HiveStartupSourcePluginKind, isEnabled: Bool? = nil) {
        self.kind = kind
        self.isEnabled = isEnabled ?? kind.startupDefaultEnabled
    }
}

public struct HiveStartupSourcePluginRequest: Codable, Hashable, Sendable {
    public var selections: [HiveStartupSourcePluginSelection]
    public var pasteLocation: String
    public var prompt: String
    public var createdAt: Date

    public init(
        selections: [HiveStartupSourcePluginSelection] = HiveStartupSourcePluginCatalog.defaultSelections,
        pasteLocation: String = "",
        prompt: String = "",
        createdAt: Date = Date()
    ) {
        self.selections = selections
        self.pasteLocation = pasteLocation
        self.prompt = prompt
        self.createdAt = createdAt
    }

    public var enabledSelections: [HiveStartupSourcePluginSelection] {
        selections.filter(\.isEnabled)
    }

    public var hasUserInstruction: Bool {
        !pasteLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var hasBrowserHistoryIntent: Bool {
        enabledSelections.contains { $0.kind == .browserHistory }
    }

    public var hasAppUsageIntent: Bool {
        enabledSelections.contains { $0.kind == .appUsage }
    }

    public var hasUploadIntent: Bool {
        enabledSelections.contains { $0.kind == .uploads }
    }

    public var canRunWithoutPicker: Bool {
        hasUserInstruction || hasBrowserHistoryIntent || hasAppUsageIntent
    }
}

public enum HiveStartupSourcePluginCatalog {
    public static let storageKey = "hive.startupSourcePlugins.request"
    public static let pasteLocationPlaceholder = "Paste a Google Drive link, web page URL, local folder, file path, or Downloads path"
    public static let promptPlaceholder = "Tell Hive what to grab, what matters, or how to organize it"

    public static var orderedKinds: [HiveStartupSourcePluginKind] {
        [.googleDrive, .webPages, .uploads, .localDisk, .downloadsFolder, .browserHistory, .appUsage]
    }

    public static var defaultSelections: [HiveStartupSourcePluginSelection] {
        orderedKinds.map { HiveStartupSourcePluginSelection(kind: $0) }
    }

    public static func enabledTitles(in request: HiveStartupSourcePluginRequest) -> [String] {
        request.enabledSelections.map { $0.kind.title }
    }

    public static func sourceRequestTitle(for request: HiveStartupSourcePluginRequest) -> String {
        let titles = enabledTitles(in: sanitizedRequest(request))
        if titles.contains(HiveStartupSourcePluginKind.googleDrive.title) {
            return "Google Drive source request"
        }
        return titles.first.map { "\($0) source request" } ?? "Source request"
    }

    public static func sanitizedRequest(_ request: HiveStartupSourcePluginRequest) -> HiveStartupSourcePluginRequest {
        let selectionsByKind = Dictionary(uniqueKeysWithValues: request.selections.map { ($0.kind, $0.isEnabled) })
        let selections = orderedKinds.map { kind in
            HiveStartupSourcePluginSelection(kind: kind, isEnabled: selectionsByKind[kind] ?? kind.startupDefaultEnabled)
        }
        return HiveStartupSourcePluginRequest(
            selections: selections,
            pasteLocation: request.pasteLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            prompt: request.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: request.createdAt
        )
    }

    public static func persist(_ request: HiveStartupSourcePluginRequest, defaults: UserDefaults = .standard) {
        let sanitized = sanitizedRequest(request)
        guard let data = try? JSONEncoder().encode(sanitized) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public static func load(defaults: UserDefaults = .standard) -> HiveStartupSourcePluginRequest {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(HiveStartupSourcePluginRequest.self, from: data) else {
            return HiveStartupSourcePluginRequest()
        }
        return sanitizedRequest(decoded)
    }

    public static func importableLocalURLs(from request: HiveStartupSourcePluginRequest, fileManager: FileManager = .default) -> [URL] {
        let sanitized = sanitizedRequest(request)
        let enabledKinds = Set(sanitized.enabledSelections.map(\.kind))
        guard enabledKinds.contains(.localDisk) || enabledKinds.contains(.downloadsFolder) else {
            return []
        }
        let location = sanitized.pasteLocation
        guard !location.isEmpty, let url = localFileURL(from: location, fileManager: fileManager) else {
            return []
        }
        if enabledKinds.contains(.downloadsFolder), isDownloadsLocation(url, fileManager: fileManager) {
            return [url]
        }
        guard enabledKinds.contains(.localDisk) else { return [] }
        return [url]
    }

    public static func startupMarkdown(for request: HiveStartupSourcePluginRequest, now: Date = Date()) -> String? {
        let sanitized = sanitizedRequest(request)
        guard !sanitized.enabledSelections.isEmpty, sanitized.hasUserInstruction else { return nil }
        let formatter = ISO8601DateFormatter()
        let pluginList = enabledTitles(in: sanitized).joined(separator: ", ")
        let location = sanitized.pasteLocation.isEmpty ? "None pasted" : sanitized.pasteLocation
        let prompt = sanitized.prompt.isEmpty ? "Read this source and fold durable knowledge into existing Colony articles." : sanitized.prompt
        let driveNote = isGoogleDriveLocation(location)
            ? "\nGoogle Drive note: use this as a Drive source link. Do not treat sign-in or navigation pages as memory.\n"
            : ""
        return """
        ---
        capture_kind: "startup-source-plugins"
        captured_at: "\(formatter.string(from: now))"
        enabled_source_plugins: "\(pluginList.replacingOccurrences(of: "\"", with: "\\\""))"
        pasted_location: "\(location.replacingOccurrences(of: "\"", with: "\\\""))"
        ---

        # Source request

        Enabled sources: \(pluginList)

        Location to grab: \(location)

        Prompt for Hive: \(prompt)
        \(driveNote)
        Keep private material local unless the user explicitly enables online Ask. Expand existing Colony articles before creating new ones.
        """
    }

    public static func isGoogleDriveLocation(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("drive.google.com") || lower.contains("docs.google.com")
    }

    public static func webURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }

    public static func localFileURL(from value: String, fileManager: FileManager = .default) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate: URL
        if let url = URL(string: trimmed), url.isFileURL {
            candidate = url
        } else if trimmed.hasPrefix("~/") {
            candidate = homeDirectory(fileManager: fileManager).appendingPathComponent(String(trimmed.dropFirst(2)))
        } else {
            candidate = URL(fileURLWithPath: trimmed)
        }
        return fileManager.fileExists(atPath: candidate.path) ? candidate : nil
    }

    public static func isDownloadsLocation(_ url: URL, fileManager: FileManager = .default) -> Bool {
        #if os(macOS)
        let downloads = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true).standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == downloads || path.hasPrefix(downloads + "/")
        #else
        _ = url
        _ = fileManager
        return false
        #endif
    }

    private static func homeDirectory(fileManager: FileManager) -> URL {
        #if os(macOS)
        fileManager.homeDirectoryForCurrentUser
        #else
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .deletingLastPathComponent()
            ?? fileManager.temporaryDirectory
        #endif
    }
}

public struct HiveStartupSourcePluginExecutionResult: Codable, Hashable, Sendable {
    public var importedLocalCount: Int
    public var capturedWebCount: Int
    public var importedBrowserHistoryCount: Int
    public var importedBrowserBookmarkCount: Int
    public var importedAppUsageSnapshotCount: Int
    public var requestCount: Int
    public var auditDetails: [String]

    public init(
        importedLocalCount: Int = 0,
        capturedWebCount: Int = 0,
        importedBrowserHistoryCount: Int = 0,
        importedBrowserBookmarkCount: Int = 0,
        importedAppUsageSnapshotCount: Int = 0,
        requestCount: Int = 0,
        auditDetails: [String] = []
    ) {
        self.importedLocalCount = importedLocalCount
        self.capturedWebCount = capturedWebCount
        self.importedBrowserHistoryCount = importedBrowserHistoryCount
        self.importedBrowserBookmarkCount = importedBrowserBookmarkCount
        self.importedAppUsageSnapshotCount = importedAppUsageSnapshotCount
        self.requestCount = requestCount
        self.auditDetails = auditDetails
    }

    public var didWork: Bool {
        importedLocalCount + capturedWebCount + importedBrowserHistoryCount + importedBrowserBookmarkCount + importedAppUsageSnapshotCount + requestCount > 0
    }

    public var summary: String {
        var parts: [String] = []
        if importedLocalCount > 0 { parts.append("\(importedLocalCount) local import\(importedLocalCount == 1 ? "" : "s")") }
        if capturedWebCount > 0 { parts.append("\(capturedWebCount) web capture\(capturedWebCount == 1 ? "" : "s")") }
        if importedBrowserHistoryCount > 0 { parts.append("\(importedBrowserHistoryCount) browser item\(importedBrowserHistoryCount == 1 ? "" : "s")") }
        if importedBrowserBookmarkCount > 0 { parts.append("\(importedBrowserBookmarkCount) browser bookmark\(importedBrowserBookmarkCount == 1 ? "" : "s")") }
        if importedAppUsageSnapshotCount > 0 { parts.append("\(importedAppUsageSnapshotCount) app context snapshot\(importedAppUsageSnapshotCount == 1 ? "" : "s")") }
        if requestCount > 0 { parts.append("\(requestCount) Field request\(requestCount == 1 ? "" : "s")") }
        return parts.isEmpty ? "No source-plugin work ran." : parts.joined(separator: ", ")
    }

    public var userMessage: String {
        if didWork { return summary }
        return auditDetails.first(where: { !$0.contains("No source-plugin work ran.") }) ?? "No source work ran."
    }
}

public struct HiveStartupSourcePluginBackend {
    private let fileManager: FileManager
    private let safetyPolicy: URLSafetyPolicy

    public init(fileManager: FileManager = .default, safetyPolicy: URLSafetyPolicy = URLSafetyPolicy()) {
        self.fileManager = fileManager
        self.safetyPolicy = safetyPolicy
    }

    @discardableResult
    public func execute(
        request: HiveStartupSourcePluginRequest,
        uploadedURLs: [URL] = [],
        browserHistoryURLs: [URL] = [],
        paths: HivePaths,
        store: HiveStore,
        ingestionEngine: IngestionCoordinator,
        now: Date = Date(),
        learningSettings: HiveLearningSettings = HiveLearningSettingsStore.load(),
        processImmediately: Bool = true
    ) throws -> HiveStartupSourcePluginExecutionResult {
        let sanitized = HiveStartupSourcePluginCatalog.sanitizedRequest(request)
        var enabledKinds = Set(sanitized.enabledSelections.map(\.kind))
        try paths.createDirectories()

        var result = HiveStartupSourcePluginExecutionResult()
        let blockedKinds = enabledKinds.filter { !learningSettings.allows(sourcePlugin: $0) }
        if !blockedKinds.isEmpty {
            enabledKinds.subtract(blockedKinds)
            let blockedTitles = blockedKinds
                .sorted { $0.rawValue < $1.rawValue }
                .map(\.title)
                .joined(separator: ", ")
            result.auditDetails.append("Privacy settings blocked \(blockedTitles).")
        }

        var ingestURLs: [URL] = []
        var metadataByPath: [String: SourcePluginImportMetadata] = [:]
        var localImportRoots: [URL: SourcePluginImportMetadata] = [:]

        if enabledKinds.contains(.uploads), learningSettings.allows(sourcePlugin: .uploads) {
            for uploadedURL in uploadedURLs where fileManager.fileExists(atPath: uploadedURL.path) {
                ingestURLs.append(uploadedURL)
                let metadata = SourcePluginImportMetadata(connector: "startup-uploads", title: nil, uri: uploadedURL.path)
                metadataByPath[uploadedURL.path] = metadata
                localImportRoots[uploadedURL] = metadata
            }
        }

        if let localURL = HiveStartupSourcePluginCatalog.localFileURL(from: sanitized.pasteLocation, fileManager: fileManager) {
            if enabledKinds.contains(.downloadsFolder), HiveStartupSourcePluginCatalog.isDownloadsLocation(localURL, fileManager: fileManager) {
                ingestURLs.append(localURL)
                let metadata = SourcePluginImportMetadata(connector: "startup-downloads", title: nil, uri: localURL.path)
                metadataByPath[localURL.path] = metadata
                localImportRoots[localURL] = metadata
            } else if enabledKinds.contains(.localDisk) {
                ingestURLs.append(localURL)
                let metadata = SourcePluginImportMetadata(connector: "startup-local-disk", title: nil, uri: localURL.path)
                metadataByPath[localURL.path] = metadata
                localImportRoots[localURL] = metadata
            }
        }

        if enabledKinds.contains(.webPages),
           let url = HiveStartupSourcePluginCatalog.webURL(from: sanitized.pasteLocation),
           !HiveStartupSourcePluginCatalog.isGoogleDriveLocation(url.absoluteString),
           safetyPolicy.isAllowed(url) {
            do {
                let capture = try writeWebCapture(for: url, request: sanitized, paths: paths, now: now)
                ingestURLs.append(capture.fileURL)
                metadataByPath[capture.fileURL.path] = SourcePluginImportMetadata(
                    connector: "startup-web-page",
                    title: capture.title,
                    uri: url.absoluteString
                )
                result.capturedWebCount += 1
            } catch {
                result.auditDetails.append("Web capture failed for \(url.host(percentEncoded: false) ?? "URL"); saved a Field request instead.")
            }
        }

        if !ingestURLs.isEmpty {
            let records = try ingestionEngine.ingest(urls: ingestURLs, privacyLabel: .privateSource, processImmediately: processImmediately)
            for var record in records {
                guard let metadata = metadataByPath[record.uri] ?? metadataForImportedChild(recordURI: record.uri, roots: localImportRoots) else { continue }
                record.connector = metadata.connector
                if metadata.connector == "startup-web-page" {
                    record.uri = metadata.uri
                }
                if let title = metadata.title, !title.isEmpty {
                    record.title = title
                }
                try store.saveSource(record)
            }
            result.importedLocalCount += records.filter { record in
                let metadata = metadataByPath[record.uri] ?? metadataForImportedChild(recordURI: record.uri, roots: localImportRoots)
                return metadata?.connector != nil && metadata?.connector != "startup-web-page"
            }.count
        }

        if enabledKinds.contains(.browserHistory) {
            let discovery = PersonalDataDiscovery()
            let explicitProfiles = discovery.browserProfiles(fromExplicitURLs: browserHistoryURLs, fileManager: fileManager)
            let explicitBookmarkFiles = discovery.browserBookmarkFiles(fromExplicitURLs: browserHistoryURLs, fileManager: fileManager)
            let profiles = explicitProfiles.isEmpty ? discovery.discoverBrowserProfiles() : explicitProfiles
            let bookmarkFiles = explicitBookmarkFiles.isEmpty ? discovery.discoverBrowserBookmarkFiles() : explicitBookmarkFiles
            if profiles.isEmpty {
                result.auditDetails.append("No supported browser history was found. Choose a browser profile folder or History file.")
                try store.appendAudit(AuditEventRecord(
                    eventType: "sourcePlugins.browserHistory.noProfiles",
                    targetType: "sourcePlugin",
                    targetID: HiveStartupSourcePluginKind.browserHistory.rawValue,
                    detail: "Browser history was enabled, but Hive did not find a supported local browser profile."
                ))
            } else {
                let consent = Dictionary(uniqueKeysWithValues: profiles.map {
                    ($0.id, BrowserProfileConsent(profileID: $0.id, importMode: .reviewOnly, grantedAt: now))
                })
                let imported = try BrowserHistoryImporter(paths: paths, store: store).importProfiles(
                    profiles,
                    consent: consent,
                    maxEntriesPerProfile: 2_500
                )
                result.importedBrowserHistoryCount = imported.count
                if imported.isEmpty {
                    result.auditDetails.append("Browser history needs permission or has no eligible recent entries.")
                }
            }
            if bookmarkFiles.isEmpty {
                result.auditDetails.append("No supported browser bookmarks were found. Choose a browser profile folder or bookmark file.")
                try store.appendAudit(AuditEventRecord(
                    eventType: "sourcePlugins.browserBookmarks.noFiles",
                    targetType: "sourcePlugin",
                    targetID: HiveStartupSourcePluginKind.browserHistory.rawValue,
                    detail: "Browser data was enabled, but Hive did not find a supported local bookmark file."
                ))
            } else {
                let imported = try BrowserBookmarkImporter(paths: paths, store: store).importBookmarkFiles(
                    bookmarkFiles,
                    maxEntriesPerFile: 1_000
                )
                result.importedBrowserBookmarkCount = imported.count
                if imported.isEmpty {
                    result.auditDetails.append("Browser bookmarks need permission or have no eligible entries.")
                }
            }
        }

        if enabledKinds.contains(.appUsage) {
            let snapshot = PersonalDataDiscovery().currentAppUsageSnapshot(now: now)
            if let source = try AppUsageSnapshotImporter(paths: paths, store: store).importSnapshot(snapshot) {
                result.importedAppUsageSnapshotCount = 1
                result.auditDetails.append("Imported local app context snapshot \(source.id).")
            } else {
                result.auditDetails.append("No local app context was available to import.")
            }
        }

        if shouldWriteRequestNote(sanitized, enabledKinds: enabledKinds, performedURLWork: !ingestURLs.isEmpty) {
            let requestURL = try writeSourceRequest(sanitized, paths: paths, now: now)
            let records = try ingestionEngine.ingest(urls: [requestURL], privacyLabel: .privateSource, processImmediately: processImmediately)
            for var record in records where record.uri == requestURL.path {
                record.title = HiveStartupSourcePluginCatalog.sourceRequestTitle(for: sanitized)
                record.connector = "startup-source-plugins"
                record.uri = "local://source-request/\(record.id)"
                try store.saveSource(record)
                result.requestCount += 1
            }
        }

        try store.appendAudit(AuditEventRecord(
            eventType: "sourcePlugins.applied",
            targetType: "sourcePluginRequest",
            targetID: "startup-source-plugins",
            sourceRefs: [],
            detail: ([result.summary] + result.auditDetails).joined(separator: " ")
        ))
        result.auditDetails.append(result.summary)
        return result
    }

    private func shouldWriteRequestNote(
        _ request: HiveStartupSourcePluginRequest,
        enabledKinds: Set<HiveStartupSourcePluginKind>,
        performedURLWork: Bool
    ) -> Bool {
        guard !enabledKinds.isEmpty else { return false }
        guard request.hasUserInstruction else { return false }
        if HiveStartupSourcePluginCatalog.isGoogleDriveLocation(request.pasteLocation) {
            return enabledKinds.contains(.googleDrive)
        }
        if !request.prompt.isEmpty {
            return true
        }
        if !performedURLWork, !request.pasteLocation.isEmpty {
            return true
        }
        return false
    }

    private func writeSourceRequest(_ request: HiveStartupSourcePluginRequest, paths: HivePaths, now: Date) throws -> URL {
        let requestDirectory = paths.artifacts.appendingPathComponent("Source Requests", isDirectory: true)
        try fileManager.createDirectory(at: requestDirectory, withIntermediateDirectories: true)
        let nonce = UUID().uuidString.prefix(8)
        let noteURL = requestDirectory.appendingPathComponent("source-request-\(Int(now.timeIntervalSince1970))-\(nonce).md")
        let markdown = HiveStartupSourcePluginCatalog.startupMarkdown(for: request, now: now) ?? "# Source request\n"
        try markdown.write(to: noteURL, atomically: true, encoding: .utf8)
        return noteURL
    }

    private func writeWebCapture(
        for url: URL,
        request: HiveStartupSourcePluginRequest,
        paths: HivePaths,
        now: Date
    ) throws -> WebCaptureFile {
        let data = try Data(contentsOf: url)
        let raw = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? String(decoding: data.prefix(700_000), as: UTF8.self)
        let title = cleanTitle(extractHTMLTitle(raw) ?? url.host(percentEncoded: false) ?? "Web page")
        let body = cleanHTMLText(raw)
        let formatter = ISO8601DateFormatter()
        let directory = paths.artifacts.appendingPathComponent("Web Captures", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let nonce = UUID().uuidString.prefix(8)
        let fileURL = directory.appendingPathComponent("web-capture-\(Int(now.timeIntervalSince1970))-\(nonce).md")
        let prompt = request.prompt.isEmpty ? "Fold durable knowledge into existing Colony articles." : request.prompt
        let markdown = """
        ---
        capture_kind: "source-plugin-web-page"
        captured_at: "\(formatter.string(from: now))"
        source_url: "\(url.absoluteString.replacingOccurrences(of: "\"", with: "\\\""))"
        source_prompt: "\(prompt.replacingOccurrences(of: "\"", with: "\\\""))"
        ---

        # \(title)

        Source: \(url.absoluteString)

        Prompt for Hive: \(prompt)

        \(body)
        """
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        return WebCaptureFile(fileURL: fileURL, title: title)
    }

    private func extractHTMLTitle(_ html: String) -> String? {
        guard let range = html.range(of: #"<title[^>]*>(.*?)</title>"#, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let fragment = String(html[range])
        return fragment
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanHTMLText(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: #"</p>"#, with: "\n\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        text = decodeHTMLEntities(text)
        text = text
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return String(text.prefix(120_000))
    }

    private func cleanTitle(_ value: String) -> String {
        let cleaned = decodeHTMLEntities(value)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Web page" : String(cleaned.prefix(96))
    }

    private func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private func metadataForImportedChild(
        recordURI: String,
        roots: [URL: SourcePluginImportMetadata]
    ) -> SourcePluginImportMetadata? {
        roots
            .sorted { $0.key.path.count > $1.key.path.count }
            .first { root, _ in
                let rootPath = root.standardizedFileURL.path
                return recordURI == rootPath || recordURI.hasPrefix(rootPath + "/")
            }?
            .value
    }
}

private struct SourcePluginImportMetadata {
    var connector: String
    var title: String?
    var uri: String
}

private struct WebCaptureFile {
    var fileURL: URL
    var title: String
}
