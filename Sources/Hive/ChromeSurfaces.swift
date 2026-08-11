import SwiftUI
import CefKit
import HiveCore

// MARK: - Gemini Side Panel

enum GeminiMessageRole: String, Sendable {
    case user = "user"
    case assistant = "assistant"
}

struct GeminiMessage: Identifiable, Sendable {
    let id: UUID
    let role: GeminiMessageRole
    let text: String
    let timestamp: Date

    init(role: GeminiMessageRole, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = Date()
    }

    init(id: UUID, role: GeminiMessageRole, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Context Diagnostics (Dia-style scope preview)

/// Diagnostics captured from the last orchestration pass.
/// Drives the ContextScopePreviewView in the AI side panel — shows
/// the user exactly what context the AI used before generating.
struct ContextDiagnostics: Sendable {
    let contextNodeCount: Int
    let contextSummary: String
    let rankerProvider: String?
    let providerLabel: String
    let durationMS: Int
    let pageTitle: String?
    let pageHost: String?
}

// MARK: - Extensions

struct ExtensionItem: Identifiable, Sendable, Codable {
    var id: UUID
    var name: String
    var iconName: String
    var isPinned: Bool
    var isEnabled: Bool
    /// Extension version from manifest.json (e.g. "1.2.0").
    var version: String
    var description: String
    /// Path to manifest.json on disk, if installed from a local folder.
    var manifestPath: String?

    init(id: UUID = UUID(), name: String, iconName: String = "puzzlepiece.extension", isPinned: Bool = true, isEnabled: Bool = true, version: String = "1.0", description: String = "", manifestPath: String? = nil) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.isPinned = isPinned
        self.isEnabled = isEnabled
        self.version = version
        self.description = description
        self.manifestPath = manifestPath
    }

    /// Extensions ship empty — users install their own from the Chrome Web Store
    /// or by selecting an unpacked extension folder.
    static let defaults: [ExtensionItem] = []
}

// MARK: - Passwords

struct SavedPassword: Identifiable, Sendable {
    /// Stable across edits — the password manager reuses the id when a row
    /// is updated so the List keeps row identity (no remove+insert churn).
    let id: UUID
    var username: String
    var password: String
    var site: String

    init(id: UUID = UUID(), username: String, password: String, site: String) {
        self.id = id
        self.username = username
        self.password = password
        self.site = site
    }

    /// Passwords start empty. Users import from Chrome/Safari or save as they browse.
    static let defaults: [SavedPassword] = []
}

// MARK: - History

struct HistoryItem: Identifiable, Sendable, Codable {
    let id: UUID
    let title: String
    let url: URL
    let visitedAt: Date
    var faviconURL: URL?

    init(id: UUID = UUID(), title: String, url: URL, visitedAt: Date = Date(), faviconURL: URL? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.visitedAt = visitedAt
        self.faviconURL = faviconURL
    }

    enum CodingKeys: String, CodingKey { case id, title, url, visitedAt, faviconURL }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        url = try c.decode(URL.self, forKey: .url)
        visitedAt = try c.decode(Date.self, forKey: .visitedAt)
        faviconURL = try c.decodeIfPresent(URL.self, forKey: .faviconURL)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(url, forKey: .url)
        try c.encode(visitedAt, forKey: .visitedAt)
        try c.encodeIfPresent(faviconURL, forKey: .faviconURL)
    }
}

// MARK: - Downloads

struct DownloadItem: Identifiable, Sendable, Codable {
    let id: UUID
    var cefID: UInt32 = 0
    let suggestedName: String
    let url: URL
    /// The tab that initiated this live download. Runtime-only: custom Codable
    /// persists terminal history through TerminalDownloadRecord and omits this
    /// transient browser association.
    var originatingTabID: String?
    var progress: Double = 0
    var isComplete: Bool = false
    var isCanceled: Bool = false
    var isInterrupted: Bool = false
    /// The destination is available after the native progress callback reports
    /// it.
    var destinationURL: URL?
    /// Live CEF controller for pause/resume/cancel, delivered with each
    /// progress update while the transfer is active. Runtime-only: custom
    /// Codable persists terminal history through `TerminalDownloadRecord`,
    /// which never carries process-local control state.
    var downloadControl: CefDownloadControl?
    /// UI-level pause/resume request state (HiveCore state machine).
    /// `requestPause`/`requestResume` run on the UI before the CEF control is
    /// invoked; every native progress update reconciles against the snapshot's
    /// authoritative `isPaused` bit.
    var controlState: DownloadControlStateMachine = DownloadControlStateMachine()

    init(
        id: UUID = UUID(),
        cefID: UInt32 = 0,
        suggestedName: String,
        url: URL,
        originatingTabID: String? = nil,
        progress: Double = 0,
        isComplete: Bool = false,
        isCanceled: Bool = false,
        isInterrupted: Bool = false,
        destinationURL: URL? = nil
    ) {
        self.id = id
        self.cefID = cefID
        self.suggestedName = suggestedName
        self.url = url
        self.originatingTabID = originatingTabID
        self.progress = progress
        self.isComplete = isComplete
        self.isCanceled = isCanceled
        self.isInterrupted = isInterrupted
        self.destinationURL = destinationURL
        self.downloadControl = nil
        self.controlState = DownloadControlStateMachine()
    }

    /// Persist terminal download history through the dependency-light
    /// HiveCore value object. Runtime CEF identity, active-control state, and
    /// local destination paths never cross a process boundary.
    init(from decoder: Decoder) throws {
        let record = try TerminalDownloadRecord(from: decoder)
        self.init(
            id: record.id,
            suggestedName: record.suggestedName,
            url: record.url,
            originatingTabID: nil,
            progress: record.progress,
            isComplete: record.isComplete,
            isCanceled: record.isCanceled,
            isInterrupted: record.isInterrupted
        )
    }

    func encode(to encoder: Encoder) throws {
        try TerminalDownloadRecord(
            id: id,
            suggestedName: suggestedName,
            url: url,
            progress: progress,
            isComplete: isComplete,
            isCanceled: isCanceled,
            isInterrupted: isInterrupted
        ).encode(to: encoder)
    }
}

// MARK: - Safe Browsing

struct SafeBrowsingWarning: Sendable {
    let url: URL
    let reason: String
}

// MARK: - Translate

struct TranslateState: Sendable {
    var sourceLanguage: String
    var targetLanguage: String
    var isTranslating: Bool = false

    /// Maps a human-readable language name to a two-letter ISO 639-1 code
    /// for use with Google Translate. Returns "auto" for unknown languages.
    static func languageCode(for name: String) -> String {
        switch name.lowercased() {
        case "german": return "de"
        case "french": return "fr"
        case "spanish": return "es"
        case "italian": return "it"
        case "portuguese": return "pt"
        case "russian": return "ru"
        case "japanese": return "ja"
        case "korean": return "ko"
        case "chinese": return "zh-CN"
        case "arabic": return "ar"
        case "dutch": return "nl"
        case "polish": return "pl"
        case "turkish": return "tr"
        case "swedish": return "sv"
        case "norwegian": return "no"
        case "danish": return "da"
        case "finnish": return "fi"
        case "czech": return "cs"
        case "hungarian": return "hu"
        case "thai": return "th"
        case "vietnamese": return "vi"
        case "indonesian": return "id"
        case "romanian": return "ro"
        case "slovak": return "sk"
        case "ukrainian": return "uk"
        default: return "auto"
        }
    }
}

// MARK: - Theme Presets

struct ThemePreset: Identifiable, Sendable {
    let id = UUID()
    var name: String
    var colorHex: String
    var iconName: String

    static let presets: [ThemePreset] = [
        ThemePreset(name: "Hive Amber", colorHex: "#F5A623", iconName: "circle.fill"),
        ThemePreset(name: "Chrome Classic", colorHex: "#4285F4", iconName: "circle.fill"),
        ThemePreset(name: "Rose", colorHex: "#E11D48", iconName: "circle.fill"),
        ThemePreset(name: "Emerald", colorHex: "#10B981", iconName: "circle.fill"),
        ThemePreset(name: "Sky", colorHex: "#0EA5E9", iconName: "circle.fill"),
        ThemePreset(name: "Violet", colorHex: "#8B5CF6", iconName: "circle.fill"),
    ]
}

// MARK: - PanelSearchField
//
/// Reusable search bar for panels (Bookmarks, History, Passwords, Downloads).
/// Standardizes the magnifyingglass + TextField + clear button pattern used
/// across all management sheets.

struct PanelSearchField: View {
    let prompt: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(HiveDesign.Typography.sidebarItem)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.body)
                .focused(isFocused)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(HiveDesign.Typography.sidebarItem)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
