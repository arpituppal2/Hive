import Foundation

/// Process-independent download history metadata.
///
/// CEF download IDs, controllers, pause state, and local destination paths are
/// deliberately not part of this value. The browser target adapts its live CEF
/// download into this record only when writing session history.
public struct TerminalDownloadRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let suggestedName: String
    public let url: URL
    public let progress: Double
    public let isComplete: Bool
    public let isCanceled: Bool
    /// The engine stopped the transfer without an explicit user cancellation.
    /// This is intentionally coarse: the current CEF wrapper exposes no
    /// interrupt-reason enum, so Hive must not claim a specific network/file
    /// cause or resumability.
    public let isInterrupted: Bool

    public var isTerminal: Bool {
        isComplete || isCanceled || isInterrupted
    }

    public init(
        id: UUID = UUID(),
        suggestedName: String,
        url: URL,
        progress: Double = 0,
        isComplete: Bool = false,
        isCanceled: Bool = false,
        isInterrupted: Bool = false
    ) {
        self.id = id
        self.suggestedName = suggestedName
        self.url = Self.historyURL(from: url)
        self.progress = Self.clampedProgress(progress)
        self.isComplete = isComplete
        self.isCanceled = isCanceled
        self.isInterrupted = isInterrupted
    }

    private enum CodingKeys: String, CodingKey {
        case id, suggestedName, url, progress, isComplete, isCanceled, isInterrupted
    }

    /// Decodes only the stable history contract. Unknown legacy keys such as
    /// `destinationURL`, `cefID`, and `downloadController` are ignored by
    /// keyed decoding, so older session files remain readable.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            suggestedName: try container.decode(String.self, forKey: .suggestedName),
            url: try container.decode(URL.self, forKey: .url),
            progress: try container.decode(Double.self, forKey: .progress),
            isComplete: try container.decode(Bool.self, forKey: .isComplete),
            isCanceled: try container.decode(Bool.self, forKey: .isCanceled),
            // Added after the original history format; old sessions decode as
            // ordinary active/terminal rows until the caller filters them.
            isInterrupted: try container.decodeIfPresent(Bool.self, forKey: .isInterrupted) ?? false
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(suggestedName, forKey: .suggestedName)
        try container.encode(url, forKey: .url)
        try container.encode(progress, forKey: .progress)
        try container.encode(isComplete, forKey: .isComplete)
        try container.encode(isCanceled, forKey: .isCanceled)
        try container.encode(isInterrupted, forKey: .isInterrupted)
    }

    private static func clampedProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func historyURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.query = nil
        components.fragment = nil
        components.user = nil
        components.password = nil
        return components.url ?? url
    }
}
