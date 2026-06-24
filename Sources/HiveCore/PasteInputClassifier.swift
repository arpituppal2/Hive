import Foundation

/// The classified kind of a pasted import input (Prompt 4, BUG 4).
public enum PasteInputType: String, Codable, Hashable, Sendable {
    case googleDriveURL
    case webURL
    case localPath
    case downloadsFilename
    case unknown

    /// The human-facing source plugin required to resolve this input type.
    public var requiredPlugin: String {
        switch self {
        case .googleDriveURL: return "Google Drive"
        case .webURL: return "Links"
        case .localPath: return "Local disk"
        case .downloadsFilename: return "Downloads"
        case .unknown: return ""
        }
    }
}

/// Pure-logic classifier that maps a raw pasted string to a `PasteInputType`.
public struct PasteInputClassifier: Sendable {
    public init() {}

    /// Classify a pasted input string.
    ///
    /// Rules (in priority order):
    /// 1. Trim whitespace; empty input is `.unknown`.
    /// 2. Contains `drive.google.com` -> `.googleDriveURL`.
    /// 3. Starts with `http://` or `https://` -> `.webURL`.
    /// 4. Starts with `/` or `~` -> `.localPath`.
    /// 5. Bare filename (no `/`, has a `.` with a 1–10 char extension) -> `.downloadsFilename`.
    /// 6. Otherwise `.unknown`.
    public func classify(_ input: String) -> PasteInputType {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown }

        if trimmed.contains("drive.google.com") {
            return .googleDriveURL
        }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return .webURL
        }

        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return .localPath
        }

        if looksLikeBareFilename(trimmed) {
            return .downloadsFilename
        }

        return .unknown
    }

    /// A bare filename has no path separator and ends with a `.ext` whose
    /// extension is 1–10 characters long.
    private func looksLikeBareFilename(_ value: String) -> Bool {
        guard !value.contains("/") else { return false }
        guard let dotIndex = value.lastIndex(of: ".") else { return false }

        let ext = value[value.index(after: dotIndex)...]
        guard (1...10).contains(ext.count) else { return false }

        let nameRange = value[..<dotIndex]
        return !nameRange.isEmpty
    }
}
