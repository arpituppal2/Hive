import Foundation

/// Pure filename rules for browser-provided download suggestions.
public enum DownloadFilenamePolicy {
    private static let forbiddenCharacters = CharacterSet(charactersIn: "/\\:")

    public static func sanitizedFilename(_ suggested: String, fallback: String = "download") -> String {
        let trimmed = suggested.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? fallback : trimmed
        let scalars = source.unicodeScalars.map { scalar -> Character in
            if CharacterSet.controlCharacters.contains(scalar) || forbiddenCharacters.contains(scalar) {
                return "_"
            }
            return Character(String(scalar))
        }
        var result = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix(".") { result.removeFirst() }
        if result.isEmpty { result = fallback }
        return String(result.prefix(255))
    }

    /// Returns a collision-free name using the browser convention `name (N).ext`.
    public static func uniqueFilename(_ filename: String, existingNames: Set<String>) -> String {
        guard existingNames.contains(filename) else { return filename }
        let url = URL(fileURLWithPath: filename)
        let base = url.deletingPathExtension().lastPathComponent
        let extensionPart = url.pathExtension
        for index in 1...9999 {
            let candidateBase = "\(base) (\(index))"
            let candidate = extensionPart.isEmpty
                ? candidateBase
                : "\(candidateBase).\(extensionPart)"
            if !existingNames.contains(candidate) { return candidate }
        }
        return "\(UUID().uuidString)-\(filename)"
    }
}
