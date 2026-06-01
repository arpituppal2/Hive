import Foundation

public enum OrganicProcessingState: String, Codable, CaseIterable, Sendable {
    case resting = "Resting"
    case foraging = "Foraging"
    case digesting = "Digesting"
    case synthesizing = "Synthesizing"
    case confused = "Confused — tap to help"
    case understood = "Understood"
}

public enum SourceDisplayTier: String, Codable, CaseIterable, Sendable {
    case primary
    case incidental
}

public struct SourceAttachmentPreview: Hashable, Sendable {
    public enum PreviewKind: String, Hashable, Sendable {
        case image
        case document
        case folder
        case text
        case audio
        case video
        case web
        case file
    }

    public var kind: PreviewKind
    public var displayName: String
    public var kindLabel: String
    public var sizeLabel: String?
    public var originLabel: String?
    public var localPath: String?
    public var extractedSnippet: String?

    public init(
        kind: PreviewKind,
        displayName: String,
        kindLabel: String,
        sizeLabel: String? = nil,
        originLabel: String? = nil,
        localPath: String? = nil,
        extractedSnippet: String? = nil
    ) {
        self.kind = kind
        self.displayName = displayName
        self.kindLabel = kindLabel
        self.sizeLabel = sizeLabel
        self.originLabel = originLabel
        self.localPath = localPath
        self.extractedSnippet = extractedSnippet
    }

    public var detailLine: String {
        [kindLabel, sizeLabel, originLabel]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
    }
}

public struct SourcePresentationModel: Identifiable, Hashable, Sendable {
    public var id: String
    public var sourceID: String
    public var sourceKind: SourceKind
    public var sourceName: String
    public var rawURI: String
    public var title: String
    public var importedAt: Date
    public var observedAt: Date
    public var relativeAge: String
    public var age: Double
    public var recordStatus: RecordStatus
    public var status: OrganicProcessingState
    public var summary: String
    public var displayTier: SourceDisplayTier
    public var attachmentPreview: SourceAttachmentPreview?

    public init(
        source: SourceRecord,
        now: Date = Date(),
        rawBlob: RawBlobRecord? = nil,
        artifactPreviewText: String? = nil
    ) {
        let naturalTitle = Self.naturalTitle(for: source)
        let attachmentPreview = Self.attachmentPreview(
            for: source,
            rawBlob: rawBlob,
            artifactPreviewText: artifactPreviewText
        )
        self.id = source.id
        self.sourceID = source.id
        self.sourceKind = source.kind
        self.sourceName = Self.sourceName(for: source)
        self.rawURI = source.uri
        self.title = naturalTitle
        self.importedAt = source.importedAt
        self.observedAt = source.observedAt
        self.relativeAge = Self.relativeAge(from: source.observedAt, to: now)
        self.age = Self.ageFraction(from: source.observedAt, to: now)
        self.recordStatus = source.status
        self.status = Self.status(for: source.status)
        self.summary = Self.summary(for: source, attachmentPreview: attachmentPreview)
        self.displayTier = Self.displayTier(for: source, naturalTitle: naturalTitle)
        self.attachmentPreview = attachmentPreview
    }

    public var isDefaultVisibleRawInput: Bool {
        displayTier == .primary
    }

    public var isStaged: Bool {
        recordStatus == .queued
    }

    public var isProcessing: Bool {
        recordStatus == .extracting
    }

    public func stagedRemainingText(now: Date = Date(), delay: TimeInterval = 5 * 60) -> String {
        let remaining = max(0, importedAt.addingTimeInterval(delay).timeIntervalSince(now))
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "Processing in %d:%02d", minutes, seconds)
    }

    public func stagedProgress(now: Date = Date(), delay: TimeInterval = 5 * 60) -> Double {
        guard delay > 0 else { return 1 }
        let elapsed = max(0, min(delay, now.timeIntervalSince(importedAt)))
        return elapsed / delay
    }

    public static func status(for status: RecordStatus) -> OrganicProcessingState {
        switch status {
        case .discovered, .queued:
            return .resting
        case .extracting:
            return .digesting
        case .extracted:
            return .understood
        case .needsReview:
            return .synthesizing
        case .failed:
            return .confused
        case .deleted:
            return .resting
        }
    }

    public static func naturalTitle(for source: SourceRecord) -> String {
        if let seedTitle = semanticMemorySeedTitle(for: source) {
            return seedTitle
        }
        let cleaned = cleanTitle(source.title.isEmpty ? source.uri : source.title)
        switch source.kind {
        case .browserHistory:
            if isBareDomainTitle(cleaned) || cleaned == hostTitle(from: source.uri) {
                return "Browsing trail"
            }
            return browserMemoryTitle(cleaned, uri: source.uri)
        case .browserBookmark:
            if isBareDomainTitle(cleaned) || cleaned == hostTitle(from: source.uri) {
                return "Saved trail"
            }
            return browserMemoryTitle(cleaned, uri: source.uri, fallback: "Saved trail")
        case .clipboardExport:
            return cleaned.isEmpty ? "Copied thought" : cleaned
        case .calendarExport:
            return cleaned.isEmpty ? "Calendar memory" : cleaned
        case .taskExport:
            return cleaned.isEmpty ? "Task memory" : cleaned
        case .screenshot:
            return cleaned.isEmpty ? "Screenshot memory" : cleaned
        case .image:
            return cleaned.isEmpty ? "Image memory" : cleaned
        case .audio:
            return cleaned.isEmpty ? "Audio memory" : cleaned
        case .video:
            return cleaned.isEmpty ? "Video memory" : cleaned
        case .folder:
            return cleaned.isEmpty ? "Folder of evidence" : cleaned
        default:
            return cleaned.isEmpty ? "Captured memory" : cleaned
        }
    }

    private static func semanticMemorySeedTitle(for source: SourceRecord) -> String? {
        let combined = "\(source.connector) \(source.uri) \(source.title)"
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        let isSeed = combined.contains("memory seed")
            || combined.contains("hive seed")
            || combined.contains("hive start questions")
            || combined.contains("personal memory boundary reset")
        guard isSeed else { return nil }

        if combined.contains("hive start questions") || combined.contains("start questions") {
            return "Hive start questions"
        }
        if combined.contains("personal memory boundary reset") || combined.contains("boundary reset") {
            return "Memory boundary reset"
        }

        var stripped = source.title
            .replacingOccurrences(of: "AI Memory Seed", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "Hive Memory Seed", with: "", options: [.caseInsensitive])
        stripped = cleanTitle(stripped)
        if stripped != "Captured memory", stripped != "Imported memory", !stripped.isEmpty {
            return stripped
        }
        return "Captured memory seed"
    }

    public static func confidenceLanguage(_ confidence: Double) -> String {
        switch confidence {
        case 0.88...:
            return "sealed"
        case 0.72..<0.88:
            return "fairly confident"
        case 0.52..<0.72:
            return "pretty sure"
        case 0.30..<0.52:
            return "uncertain"
        default:
            return "barely formed"
        }
    }

    public static func cleanTitle(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let host = hostTitle(from: trimmedValue) {
            return host
        }
        if trimmedValue.range(of: #"(?i)^page\s+capture\s+\d+$"#, options: .regularExpression) != nil {
            return "Untitled capture"
        }

        var text = trimmedValue
            .replacingOccurrences(of: "AI Memory Seed", with: "Imported memory", options: [.caseInsensitive])
            .replacingOccurrences(of: "Hive Memory Seed", with: "Imported memory", options: [.caseInsensitive])
            .replacingOccurrences(of: "# HIVE MEMORY SEED", with: "Imported memory", options: [.caseInsensitive])
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        text = stripTimestampFragments(from: text)
        let extensions = [
            "json", "pdf", "db", "sqlite", "txt", "md", "markdown", "png", "jpg", "jpeg",
            "heic", "mov", "mp4", "mp3", "wav", "csv", "html", "xml"
        ]
        for ext in extensions {
            let suffix = ".\(ext)"
            if text.lowercased().hasSuffix(suffix) {
                text.removeLast(suffix.count)
                break
            }
        }
        text = text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if text.localizedCaseInsensitiveContains("safari history") {
            text = "Browsing memory"
        }
        if text.localizedCaseInsensitiveContains("quick thought") {
            text = "Quick thought"
        }
        return text.isEmpty ? "Captured memory" : text
    }

    private static func browserMemoryTitle(_ cleaned: String, uri: String, fallback: String = "Browsing thread") -> String {
        let title = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return fallback }
        let lower = title.lowercased()
        let host = hostTitle(from: uri)?.lowercased() ?? ""

        if lower.contains("google drive") {
            if lower.contains("search") { return "Drive search" }
            if lower.contains("home") { return "Google Drive home" }
            if lower.contains("activities") { return "Activity list" }
            return "Google Drive trail"
        }
        if lower.contains("google accounts") || lower.contains("sign in") {
            return "Google sign-in"
        }
        if host.contains("brev") || lower.contains("brev.dev") {
            if lower.contains("billing") { return "Brev billing" }
            if lower.contains("instance") { return "Brev instance settings" }
            return "Brev trail"
        }
        if host.contains("youtube") || lower.contains("youtube") {
            if lower.hasPrefix("what is") || lower.contains("?") { return "Video question" }
            return "Video trail"
        }
        if lower.contains("21st") || lower.contains("community") || lower.contains("component") {
            if lower.contains("notification") { return "Notification component reference" }
            if lower.contains("sticky") || lower.contains("scroll") { return "Scroll interaction reference" }
            if lower.contains("tab") { return "Tab interaction reference" }
            if lower.contains("button") { return "Button interaction reference" }
            return "Interface component research"
        }

        let semantic = strippingKnownBrowserSuffixes(from: title)
        if semantic.count <= 3 { return fallback }
        return semantic
    }

    private static func displayTier(for source: SourceRecord, naturalTitle: String) -> SourceDisplayTier {
        let lowerTitle = naturalTitle.lowercased()
        let lowerRaw = "\(source.title) \(source.uri) \(source.connector)".lowercased()
        let isBrowserLike = source.kind == .browserHistory || source.kind == .browserBookmark
        guard isBrowserLike else { return .primary }

        let incidentalExactTitles: Set<String> = [
            "google sign-in",
            "google drive home",
            "activity list",
            "button interaction reference",
            "scroll interaction reference",
            "tab interaction reference",
            "interface component research",
            "notification component reference"
        ]
        if incidentalExactTitles.contains(lowerTitle) {
            return .incidental
        }

        let incidentalFragments = [
            "accounts.google",
            "signin",
            "sign in",
            "login",
            "oauth",
            "consent",
            "drive.google.com/drive/home",
            "myactivity.google",
            "browser appearance alone is incidental"
        ]
        if incidentalFragments.contains(where: { lowerRaw.contains($0) }) {
            return .incidental
        }
        if isBrowserLike,
           Date().timeIntervalSince(source.observedAt) > 48 * 3_600,
           !containsAny(lowerRaw, [
                "ucla", "class", "course", "deadline", "application", "grant", "scholarship",
                "cabin", "hive", "lamt", "brev", "gpu", "mac studio", "m3 ultra", "512gb"
           ]) {
            return .incidental
        }
        return .primary
    }

    private static func strippingKnownBrowserSuffixes(from title: String) -> String {
        let separators = [" | ", " — ", " – ", " - ", " · "]
        for separator in separators {
            let parts = title.components(separatedBy: separator)
            guard parts.count > 1 else { continue }
            let tail = parts.last?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let knownTails = [
                "google drive", "google docs", "google accounts", "youtube", "brev.dev",
                "21st", "21st.dev", "notion", "github", "vercel", "railway"
            ]
            if knownTails.contains(where: { tail.contains($0) }) {
                return parts.dropLast().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return title
    }

    private static func containsAny(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0) }
    }

    private static func hostTitle(from value: String) -> String? {
        if let host = URL(string: value)?.host?.replacingOccurrences(of: "www.", with: ""), !host.isEmpty {
            return host
        }
        let firstToken = value.split(separator: " ").first.map(String.init) ?? value
        guard firstToken.contains("."), firstToken.contains("/") else { return nil }
        let hostish = firstToken
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/")
            .first
            .map(String.init)?
            .replacingOccurrences(of: "www.", with: "")
        return hostish?.isEmpty == false ? hostish : nil
    }

    private static func isBareDomainTitle(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("."), !trimmed.contains(" "), trimmed.count <= 80 else { return false }
        let parts = trimmed.split(separator: ".")
        guard parts.count >= 2 else { return false }
        let validCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.")
        return trimmed.unicodeScalars.allSatisfy { validCharacters.contains($0) }
    }

    private static func stripTimestampFragments(from value: String) -> String {
        let patterns = [
            #"\b20\d{2}[ ._-]?\d{2}[ ._-]?\d{2}(?:[ ._:-]?\d{2}[ ._:-]?\d{2}(?:[ ._:-]?\d{2})?)?\b"#,
            #"\b\d{4}[ ._-]\d{2}[ ._-]\d{2}\b"#,
            #"\b\d{1,2}[.:]\d{2}(?:[.:]\d{2})?\b"#
        ]
        return patterns.reduce(value) { partial, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return partial }
            let range = NSRange(partial.startIndex..<partial.endIndex, in: partial)
            return regex.stringByReplacingMatches(in: partial, range: range, withTemplate: " ")
        }
    }

    public static func sourceName(for source: SourceRecord) -> String {
        switch source.kind {
        case .browserHistory, .browserBookmark:
            if let host = URL(string: source.uri)?.host?.replacingOccurrences(of: "www.", with: ""), !host.isEmpty {
                return host
            }
            return "browser"
        case .clipboardExport:
            return "clipboard"
        case .calendarExport:
            return "calendar"
        case .taskExport:
            return "tasks"
        case .screenshot:
            return "screenshot"
        case .folder:
            return "folder"
        case .image:
            return "image"
        case .audio:
            return "audio"
        case .video:
            return "video"
        case .text:
            return "text"
        case .pdf, .attachment, .genericFile:
            return "file"
        }
    }

    public static func relativeAge(from date: Date, to now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3_600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "\(Int(seconds / 3_600))h ago" }
        if seconds < 172_800 { return "yesterday" }
        if seconds < 1_209_600 { return "\(Int(seconds / 86_400))d ago" }
        return "\(Int(seconds / 604_800))w ago"
    }

    public static func ageFraction(from date: Date, to now: Date = Date()) -> Double {
        let rawFileWindow = 48.0 * 3_600.0
        return min(1, max(0, now.timeIntervalSince(date) / rawFileWindow))
    }

    private static func summary(for source: SourceRecord, attachmentPreview: SourceAttachmentPreview?) -> String {
        if let attachmentPreview {
            switch status(for: source.status) {
            case .understood, .resting:
                return attachmentPreview.detailLine
            case .confused:
                return "Needs review before Hive can use this \(attachmentPreview.kindLabel.lowercased())."
            case .digesting:
                return "Reading \(attachmentPreview.displayName)."
            case .synthesizing:
                return "Filing useful parts from \(attachmentPreview.displayName)."
            case .foraging:
                return "Adding context from \(attachmentPreview.displayName)."
            }
        }
        switch status(for: source.status) {
        case .understood:
            return ""
        case .confused:
            return "Needs review before Hive can use it."
        case .digesting:
            return "Reading the source."
        case .synthesizing:
            return "Updating useful memories."
        case .foraging:
            return "Adding source context."
        case .resting:
            return "Ready when you are."
        }
    }

    private static func attachmentPreview(
        for source: SourceRecord,
        rawBlob: RawBlobRecord?,
        artifactPreviewText: String?
    ) -> SourceAttachmentPreview? {
        guard let kind = previewKind(for: source.kind) else { return nil }
        let localPath = rawBlob?.localPath ?? filePath(from: source.uri)
        guard localPath != nil || source.kind == .folder else { return nil }
        let displayName = sourceDisplayName(for: source)
        let sizeLabel = formattedSize(source.sizeBytes)
        let originLabel = originLabel(for: source.uri)
        let snippet = cleanedSnippet(from: artifactPreviewText)
        return SourceAttachmentPreview(
            kind: kind.kind,
            displayName: displayName,
            kindLabel: kind.label,
            sizeLabel: sizeLabel,
            originLabel: originLabel,
            localPath: localPath,
            extractedSnippet: snippet
        )
    }

    private static func previewKind(for kind: SourceKind) -> (kind: SourceAttachmentPreview.PreviewKind, label: String)? {
        switch kind {
        case .pdf:
            return (.document, "Document")
        case .attachment, .genericFile:
            return (.file, "File")
        case .image, .screenshot:
            return (.image, "Image")
        case .video:
            return (.video, "Video")
        case .audio:
            return (.audio, "Audio")
        case .text, .clipboardExport:
            return (.text, "Text")
        case .folder:
            return (.folder, "Folder")
        case .browserHistory, .browserBookmark:
            return nil
        case .calendarExport, .taskExport:
            return nil
        }
    }

    private static func sourceDisplayName(for source: SourceRecord) -> String {
        let title = source.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }
        if let path = filePath(from: source.uri) {
            let name = URL(fileURLWithPath: path).lastPathComponent
            if !name.isEmpty { return name }
        }
        if let url = URL(string: source.uri), !url.lastPathComponent.isEmpty {
            return url.lastPathComponent
        }
        return cleanTitle(source.uri)
    }

    private static func formattedSize(_ bytes: Int64) -> String? {
        guard bytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private static func originLabel(for uri: String) -> String? {
        guard let path = filePath(from: uri) else { return nil }
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
        guard !parent.isEmpty else { return nil }
        return "From \(cleanTitle(parent))"
    }

    private static func filePath(from uri: String) -> String? {
        if let url = URL(string: uri), url.isFileURL {
            return url.path
        }
        guard uri.hasPrefix("/") else { return nil }
        return uri
    }

    private static func cleanedSnippet(from value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        if cleaned.count <= 180 { return cleaned }
        let end = cleaned.index(cleaned.startIndex, offsetBy: 180)
        return String(cleaned[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct RawInputSemanticCluster: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var primary: SourcePresentationModel
    public var sources: [SourcePresentationModel]
    public var isSynthetic: Bool

    public var count: Int {
        sources.count
    }

    public init(
        id: String,
        title: String,
        summary: String,
        primary: SourcePresentationModel,
        sources: [SourcePresentationModel],
        isSynthetic: Bool
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.primary = primary
        self.sources = sources
        self.isSynthetic = isSynthetic
    }

    public func contains(sourceID: String?) -> Bool {
        guard let sourceID else { return false }
        return sources.contains { $0.id == sourceID }
    }
}

public struct RawInputSemanticClusterer: Sendable {
    public init() {}

    public static func defaultVisibleSourceIDs(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        visibility: DerivedMemoryVisibility,
        now: Date = Date()
    ) -> Set<String> {
        let visibleClaimSourceIDs = Set(claims.filter { visibility.shouldAnswerFromClaim($0) || visibility.shouldCompileClaim($0) }.flatMap(\.sourceRefs))
        return Set(sources.compactMap { source in
            let presentation = SourcePresentationModel(source: source, now: now)
            guard presentation.isDefaultVisibleRawInput else { return nil }
            let isBrowserLike = source.kind == .browserHistory || source.kind == .browserBookmark
            guard isBrowserLike else { return source.id }
            if semanticDescriptorTextLooksClusterable("\(presentation.title) \(presentation.sourceName) \(source.title) \(source.uri)") {
                return source.id
            }
            if isLowInformationBrowserTrail("\(presentation.title) \(presentation.sourceName) \(source.title) \(source.uri)") {
                return nil
            }
            if visibleClaimSourceIDs.contains(source.id) { return source.id }
            return nil
        })
    }

    public func clusters(from sources: [SourcePresentationModel], limit: Int = 72) -> [RawInputSemanticCluster] {
        var orderedKeys: [String] = []
        var grouped: [String: [SourcePresentationModel]] = [:]
        var descriptors: [String: SemanticDescriptor] = [:]

        for source in sources.prefix(limit) {
            let descriptor = semanticDescriptor(for: source)
            if descriptor == nil,
               (source.sourceKind == .browserHistory || source.sourceKind == .browserBookmark),
               Self.isLowInformationBrowserTrail("\(source.title) \(source.sourceName)") {
                continue
            }
            let key = descriptor?.id ?? exactBrowserKey(for: source) ?? "single:\(source.id)"
            if grouped[key] == nil {
                orderedKeys.append(key)
                grouped[key] = []
                if let descriptor {
                    descriptors[key] = descriptor
                }
            }
            grouped[key]?.append(source)
        }

        return orderedKeys.compactMap { key in
            guard let items = grouped[key], let primary = items.first else { return nil }
            if let descriptor = descriptors[key] {
                return RawInputSemanticCluster(
                    id: key,
                    title: descriptor.title,
                    summary: descriptor.summary,
                    primary: primary,
                    sources: items,
                    isSynthetic: true
                )
            }
            return RawInputSemanticCluster(
                id: key,
                title: primary.title,
                summary: primary.summary,
                primary: primary,
                sources: items,
                isSynthetic: false
            )
        }
    }

    private func semanticDescriptor(for source: SourcePresentationModel) -> SemanticDescriptor? {
        guard source.sourceKind == .browserHistory || source.sourceKind == .browserBookmark else { return nil }
        let text = normalized("\(source.title) \(source.sourceName)")
        if isMacHardwareFundingTrail(text) {
            return SemanticDescriptor(
                id: "semantic:mac-studio-funding",
                title: "Mac Studio funding research",
                summary: "Apple hardware, used/refurbished options, and upgrade funding grouped for review."
            )
        }
        if isGrantScholarshipTrail(text) {
            return SemanticDescriptor(
                id: "semantic:grant-scholarship-applications",
                title: "Grant and scholarship applications",
                summary: "Funding opportunities and application work grouped into one intake trail."
            )
        }
        if containsAny(text, ["ucla", "class", "course", "math", "gradescope", "homework", "syllabus"]) {
            return SemanticDescriptor(
                id: "semantic:current-ucla-coursework",
                title: "Current UCLA coursework",
                summary: "Coursework, classes, assignments, and student context grouped for review."
            )
        }
        if containsAny(text, ["cabin", "focusflight", "aircraft", "polaris", "3d", "blender", "cesium"]) {
            return SemanticDescriptor(
                id: "semantic:cabin-build-workflow",
                title: "Cabin build workflow",
                summary: "Cabin app references, 3D assets, and build workflow evidence grouped together."
            )
        }
        if containsAny(text, ["hive", "memory", "wiki", "graph", "second brain"]) {
            return SemanticDescriptor(
                id: "semantic:hive-product-work",
                title: "Hive product work",
                summary: "Hive product, memory, graph, and wiki design evidence grouped together."
            )
        }
        if containsAny(text, ["lamt", "los angeles math tournament", "tournament", "prose"]) {
            return SemanticDescriptor(
                id: "semantic:lamt-work",
                title: "LAMT work",
                summary: "Tournament, PROSE, and LAMT operations evidence grouped together."
            )
        }
        if containsAny(text, ["brev", "a6000", "gpu", "cuda", "instance"]) {
            return SemanticDescriptor(
                id: "semantic:brev-gpu-workflow",
                title: "BREV GPU workflow",
                summary: "GPU instance, billing, and compute workflow evidence grouped together."
            )
        }
        if containsAny(text, ["humanizer", "humanize", "undetectable", "gpthuman", "grammarly", "phrasy", "ai text"]) {
            return SemanticDescriptor(
                id: "semantic:ai-writing-tool-research",
                title: "AI writing tool research",
                summary: "AI writing, rewriting, and detector-evasion tool references grouped for review."
            )
        }
        if containsAny(text, ["susquehanna", "assessment", "follow up", "application status", "recruiting"]) {
            return SemanticDescriptor(
                id: "semantic:application-follow-ups",
                title: "Application follow-ups",
                summary: "Assessment, recruiting, and application follow-up evidence grouped together."
            )
        }
        return nil
    }

    private static func semanticDescriptorTextLooksClusterable(_ value: String) -> Bool {
        let text = value
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        let containsAny: ([String]) -> Bool = { fragments in
            fragments.contains { text.contains($0) }
        }
        let hasAppleHardware = containsAny([
            "apple", "mac", "macbook", "macbook pro", "mac studio", "m3 ultra", "m4 max",
            "m5 max", "refurbished", "amazon", "ebay"
        ])
        let hasUpgradeIntent = containsAny([
            "512gb", "512 gb", "128gb", "128 gb", "ram", "ultra", "studio", "buy",
            "deals", "products", "discount", "refurbished"
        ])
        return (hasAppleHardware && hasUpgradeIntent)
            || containsAny(["grant", "grants", "scholarship", "scholarships", "funding", "application", "applications", "fellowship", "cash"])
            || containsAny(["ucla", "class", "course", "math", "gradescope", "homework", "syllabus"])
            || containsAny(["cabin", "focusflight", "aircraft", "polaris", "3d", "blender", "cesium"])
            || containsAny(["hive", "memory", "wiki", "graph", "second brain"])
            || containsAny(["lamt", "los angeles math tournament", "tournament", "prose"])
            || containsAny(["brev", "a6000", "gpu", "cuda", "instance"])
            || containsAny(["humanizer", "humanize", "undetectable", "gpthuman", "grammarly", "phrasy", "ai text"])
            || containsAny(["susquehanna", "assessment", "follow up", "application status", "recruiting"])
    }

    private static func isLowInformationBrowserTrail(_ value: String) -> Bool {
        let text = value
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let exactTitles: Set<String> = [
            "dashboard",
            "just a moment",
            "just a moment...",
            "tracker",
            "youtube",
            "3 view",
            "video trail",
            "video question",
            "browsing trail",
            "drive search",
            "home google drive",
            "search results google drive"
        ]
        if exactTitles.contains(text) {
            return true
        }
        let lowValueFragments = [
            "sign in", "single sign on", "accounts google", "inbox", "gmail",
            "bing com ck", "ppl ai file upload", "google accounts", "login",
            "authenticate", "authorization", "search results", "google drive",
            "just a moment", "dashboard", "tracker", "video question", "video trail",
            "browsing trail", "drive search", "3 view"
        ]
        return lowValueFragments.contains { text.contains($0) }
    }

    private func exactBrowserKey(for source: SourcePresentationModel) -> String? {
        switch source.sourceKind {
        case .browserHistory, .browserBookmark:
            let normalizedTitle = normalized(source.title)
            guard normalizedTitle.count >= 3 else { return nil }
            return "browser:\(normalizedTitle)"
        default:
            return nil
        }
    }

    private func isMacHardwareFundingTrail(_ text: String) -> Bool {
        let hasAppleHardware = containsAny(text, [
            "apple", "mac", "macbook", "macbook pro", "mac studio", "m3 ultra", "m4 max",
            "m5 max", "refurbished", "amazon", "ebay"
        ])
        let hasUpgradeIntent = containsAny(text, [
            "512gb", "512 gb", "128gb", "128 gb", "ram", "ultra", "studio", "buy",
            "deals", "products", "discount", "refurbished"
        ])
        return hasAppleHardware && hasUpgradeIntent
    }

    private func isGrantScholarshipTrail(_ text: String) -> Bool {
        containsAny(text, [
            "grant", "grants", "scholarship", "scholarships", "funding", "application",
            "applications", "fellowship", "cash"
        ])
    }

    private func containsAny(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0) }
    }

    private func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private struct SemanticDescriptor: Hashable, Sendable {
        var id: String
        var title: String
        var summary: String
    }
}

public struct ClaimPresentationModel: Identifiable, Hashable, Sendable {
    public var id: String
    public var text: String
    public var confidenceText: String
    public var isStrong: Bool
    public var isConflict: Bool
    public var sourceCountText: String

    public init(claim: ClaimRecord) {
        self.id = claim.id
        self.text = SourcePresentationModel.cleanTitle(claim.statement)
        self.confidenceText = SourcePresentationModel.confidenceLanguage(claim.confidence)
        self.isStrong = claim.confidence >= 0.72 && claim.status == .active
        self.isConflict = claim.status == .contradicted || claim.status == .suspect || claim.contradictionGroupID != nil
        self.sourceCountText = claim.sourceRefs.count == 1
            ? "based on one source"
            : "based on \(claim.sourceRefs.count) sources"
    }
}

public struct WikiPresentationModel: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var summary: String
    public var updatedText: String

    public init(page: WikiPageRecord, now: Date = Date(), allPages: [WikiPageRecord]? = nil) {
        self.id = page.id
        self.title = SourcePresentationModel.cleanTitle(page.title)
        let renderedMarkdown = allPages.map { WikiQueryBlockRenderer().render(markdown: page.markdown, pages: $0) } ?? page.markdown
        self.body = Self.articleBody(from: renderedMarkdown)
        self.summary = page.summary.isEmpty ? SourcePresentationModel.cleanTitle(page.title) : page.summary
        self.updatedText = SourcePresentationModel.relativeAge(from: page.updatedAt, to: now)
    }

    public static func articleBody(from markdown: String) -> String {
        var inFrontmatter = false
        var hasClosedFrontmatter = false
        var visibleLines: [String] = []

        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---", !hasClosedFrontmatter {
                inFrontmatter.toggle()
                if !inFrontmatter { hasClosedFrontmatter = true }
                continue
            }
            guard !inFrontmatter else { continue }
            guard let cleaned = cleanArticleLine(trimmed), !cleaned.isEmpty else { continue }
            visibleLines.append(cleaned)
        }

        let body = visibleLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return body
    }

    private static func cleanArticleLine(_ line: String) -> String? {
        let lower = line.lowercased()
        let hiddenPrefixes = ["id:", "kind:", "slug:", "sourcerefs:", "claimrefs:"]
        if hiddenPrefixes.contains(where: { lower.hasPrefix($0) }) { return nil }
        let hiddenFragments = [
            "raw input",
            "source refs",
            "source:",
            "provenance",
            "browser signal",
            "web signal",
            "hamiltonian path",
            "high centrality memory node",
            "forms a recurrent local loop"
        ]
        if hiddenFragments.contains(where: { lower.contains($0) }) { return nil }
        if lower == "topics" || lower == "connections" { return nil }

        var cleaned = line
        while cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        if cleaned.hasPrefix("- ") {
            cleaned.removeFirst(2)
        }
        cleaned = cleaned
            .replacingOccurrences(of: " — topic", with: "")
            .replacingOccurrences(of: " — project", with: "")
            .replacingOccurrences(of: " -> ", with: " to ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLower = cleaned.lowercased()
        if cleanedLower == "topics" || cleanedLower == "connections" { return nil }
        return stripWikiLinks(from: cleaned)
    }

    private static func stripWikiLinks(from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"#) else {
            return text
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
        var result = text
        for match in matches {
            let labelRange = match.range(at: match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound ? 2 : 1)
            let label = nsText.substring(with: labelRange)
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: label)
            }
        }
        return result
    }
}

public extension WikiPageRecord {
    var isVisibleInColony: Bool {
        isUserVisibleArticle || kind == .question
    }

    var isColonySelectionEligible: Bool {
        isUserVisibleArticle
    }

    var isUserVisibleArticle: Bool {
        guard !Self.isBareLowInformationArticleTitle(title) else { return false }
        guard !isDiscardableBlankGeneratedArticle else { return false }
        if id.hasPrefix("entity-") {
            guard MemoryQualityPolicy.isGeneratedArticleSubstantial(self) else { return false }
        }
        switch kind {
        case .topic, .person, .project:
            return true
        case .overview, .index, .log, .source, .action, .question, .contradiction, .synthesis, .lintReport, .answer:
            return false
        }
    }

    var isDiscardableBlankGeneratedArticle: Bool {
        guard !UserWikiEditPolicy.isUserAuthored(self) else { return false }
        guard [.topic, .person, .project].contains(kind) else { return false }
        guard claimRefs.isEmpty else { return false }
        guard !Self.hasMeaningfulArticleFrontmatter(frontmatter) else { return false }
        let visibleBody = WikiPresentationModel.articleBody(from: markdown)
        let normalizedBody = Self.normalizedArticleText(visibleBody)
        let normalizedTitle = Self.normalizedArticleText(title)
        let normalizedSummary = Self.normalizedArticleText(summary)
        if !normalizedSummary.isEmpty, !Self.isBareLowInformationArticleTitle(title) { return false }
        if Self.isBareLowInformationArticleTitle(title), normalizedBody.isEmpty || normalizedBody == normalizedTitle { return true }
        if normalizedBody.isEmpty, sourceRefs.isEmpty { return true }
        if normalizedBody == normalizedTitle, sourceRefs.isEmpty { return true }
        if normalizedSummary.isEmpty,
           sourceRefs.isEmpty,
           normalizedBody.split(separator: " ").count < 5 {
            return true
        }
        return false
    }

    private static func hasMeaningfulArticleFrontmatter(_ frontmatter: [String: String]) -> Bool {
        let structuralKeys: Set<String> = [
            "id",
            "kind",
            "slug",
            UserWikiEditPolicy.authorityKey
        ]
        return frontmatter.contains { key, value in
            !structuralKeys.contains(key.lowercased()) &&
                !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private static func isBareLowInformationArticleTitle(_ title: String) -> Bool {
        shouldSuppressStandaloneGeneratedArticleTitle(title)
    }

    static func shouldSuppressStandaloneGeneratedArticleTitle(_ title: String) -> Bool {
        MemoryQualityPolicy.isLowInformationStandaloneTitle(title)
    }

    private static func normalizedArticleText(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "#", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

public extension ClaimRecord {
    var isUserVisibleWikiClaim: Bool {
        guard status != .retracted else { return false }
        if let relevanceTier, !relevanceTier.isVisibleDerivedMemory { return false }
        let hiddenTypes = ["browser-observation", "browser-signal", "browser-session-intent", "graph-insight"]
        if hiddenTypes.contains(claimType) { return false }
        let lower = statement.lowercased()
        let hiddenFragments = [
            "web signal",
            "browser signal",
            "hamiltonian path",
            "high centrality memory node",
            "forms a recurrent local loop"
        ]
        return !hiddenFragments.contains { lower.contains($0) }
    }
}

public enum HiveDisplaySanitizer {
    private static let captureMetadataKey = "capture_kind"
    private static let fusedRelatedConcepts = "Related ConceptsHive"
    private static let fusedKnownInformation = "KnownInformation"

    public static func shouldHideSourceSummary(_ summary: String) -> Bool {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return trimmed.localizedCaseInsensitiveContains(captureMetadataKey)
    }

    public static func sanitizedWikiContent(_ content: String, title: String) -> String {
        let normalized = content
            .replacingOccurrences(of: fusedRelatedConcepts, with: "Related Concepts\n\nHive")
            .replacingOccurrences(of: fusedKnownInformation, with: "Known Information")
            .replacingOccurrences(of: "Related Concepts\nHive", with: "Related Concepts\n\nHive")

        var keptLines: [String] = []
        for line in normalized.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if keptLines.last?.isEmpty == false {
                    keptLines.append("")
                }
                continue
            }
            guard trimmed.caseInsensitiveCompare(title) != .orderedSame else { continue }
            let lower = trimmed.lowercased()
            if lower.contains(captureMetadataKey) { continue }
            if lower.contains(fusedKnownInformation.lowercased()) { continue }
            if lower.contains(fusedRelatedConcepts.lowercased()) { continue }
            if lower.hasPrefix("the user is") { continue }
            if lower.hasPrefix("capture kind:") { continue }
            keptLines.append(line)
        }

        return keptLines
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
    }
}

public extension GraphNodeRecord {
    var isUserVisibleGraphNode: Bool {
        guard kind != .source, kind != .insight else { return false }
        let lower = title.lowercased()
        let hiddenFragments = [
            "capture kind",
            "capture_kind",
            "current page screenshot",
            "current-page-screenshot",
            "web signal",
            "browser signal",
            "hamiltonian path",
            "high centrality memory node",
            "forms a recurrent local loop"
        ]
        if Self.isBareLowInformationConceptTitle(lower) {
            return false
        }
        if lower.range(of: #"\b(the\s+user\s+is\s+)?[0-9]{1,2}\s+years?\s+old\b"#, options: .regularExpression) != nil {
            return false
        }
        return !hiddenFragments.contains { lower.contains($0) }
    }

    private static func isBareLowInformationConceptTitle(_ lowercasedTitle: String) -> Bool {
        MemoryQualityPolicy.isLowInformationStandaloneTitle(lowercasedTitle)
    }
}

public struct GraphPresentationModel: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var confidenceText: String
    public var sourceTraceText: String

    public init(node: GraphNodeRecord) {
        self.id = node.id
        self.title = SourcePresentationModel.cleanTitle(node.title)
        self.confidenceText = SourcePresentationModel.confidenceLanguage(node.confidence)
        self.sourceTraceText = node.sourceRefs.isEmpty
            ? "formed from local memory"
            : "mentioned in \(node.sourceRefs.count) evidence trails"
    }
}
