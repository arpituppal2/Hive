import Foundation

// MARK: - UserDefinedCommand

/// A user-created palette command that opens a URL when selected.
/// Persisted in the session store so custom commands survive restart.
public struct UserDefinedCommand: Sendable, Codable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var url: String
    public var icon: String
    public var keywords: [String]

    /// Keep the palette visually reliable when a command is imported or hand-edited.
    /// These are intentionally common, bundled SF Symbols rather than arbitrary names.
    public static let allowedIcons: Set<String> = [
        "link", "bell", "bookmark", "star", "folder", "globe",
        "terminal", "doc.text", "calendar", "bolt", "gear", "sparkles",
        "rectangle.and.pencil.and.ellipsis"
    ]

    public init(id: String = UUID().uuidString,
                title: String,
                url: String,
                icon: String = "link",
                keywords: [String] = []) {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = trimmedID.isEmpty ? UUID().uuidString : trimmedID
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = Self.allowedIcons.contains(trimmedIcon) ? trimmedIcon : "link"
        self.keywords = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, url, icon, keywords
    }

    /// Decode through the same normalizing initializer used by UI-created commands.
    /// Preference/session JSON is user-editable data, so it must not bypass the
    /// trimming, icon fallback, or keyword cleanup performed at construction.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            url: try container.decode(String.self, forKey: .url),
            icon: try container.decodeIfPresent(String.self, forKey: .icon) ?? "link",
            keywords: try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        )
    }

    /// Custom commands are navigation affordances, so they are restricted to
    /// ordinary web URLs. This keeps malformed or privileged schemes out of
    /// the command palette even when a persisted file was hand-edited.
    public var isValidWebURL: Bool {
        guard !title.isEmpty,
              !url.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              let parsed = URL(string: url),
              let scheme = parsed.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = parsed.host,
              !host.isEmpty,
              parsed.user == nil,
              parsed.password == nil else {
            return false
        }
        return true
    }
}
