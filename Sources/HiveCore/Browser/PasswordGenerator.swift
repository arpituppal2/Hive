import Foundation

// MARK: - PasswordGenerator
//
// Chrome-style strong-password generator. Produces cryptographically
// reasonable random passwords that guarantee at least one lowercase, one
// uppercase, one digit, and (by default) one symbol, drawn from an
// unambiguous character set (0/O/1/l/I excluded). The generated value is
// fully shuffled, so the guaranteed classes are never positioned predictably.

public enum PasswordGenerator {

    /// Generation options. Length is clamped to a sane browser range
    /// (8–64) regardless of input.
    public struct Options: Sendable, Equatable {
        public var length: Int
        public var includeSymbols: Bool

        public init(length: Int = 16, includeSymbols: Bool = true) {
            self.length = length
            self.includeSymbols = includeSymbols
        }
    }

    /// The unambiguous character pool. `0`, `O`, `1`, `l`, and `I` are
    /// excluded so generated passwords survive human transcription.
    public static let lowercase = "abcdefghijkmnopqrstuvwxyz"
    public static let uppercase = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    public static let digits = "23456789"
    public static let symbols = "!@#$%^&*()-_=+[]{};:,.<>?"

    /// Generates a password using a caller-provided RNG (injectable for
    /// deterministic tests).
    public static func generate(
        options: Options = .init(),
        using random: inout some RandomNumberGenerator
    ) -> String {
        let length = min(max(options.length, 8), 64)
        // One character from each required class first, then fill from the
        // full pool, then shuffle so the guaranteed classes aren't clumped.
        var characters: [Character] = [
            randomCharacter(from: lowercase, using: &random),
            randomCharacter(from: uppercase, using: &random),
            randomCharacter(from: digits, using: &random)
        ]
        if options.includeSymbols {
            characters.append(randomCharacter(from: symbols, using: &random))
        }
        let pool = lowercase + uppercase + digits + (options.includeSymbols ? symbols : "")
        while characters.count < length {
            characters.append(randomCharacter(from: pool, using: &random))
        }
        return String(characters.shuffled(using: &random))
    }

    /// Generates a password using the system RNG.
    public static func generate(options: Options = .init()) -> String {
        var random = SystemRandomNumberGenerator()
        return generate(options: options, using: &random)
    }

    // MARK: - Private

    private static func randomCharacter(
        from set: String,
        using random: inout some RandomNumberGenerator
    ) -> Character {
        let index = set.index(
            set.startIndex,
            offsetBy: Int.random(in: 0..<set.count, using: &random)
        )
        return set[index]
    }
}

// MARK: - CredentialSitePolicy

/// Normalizes the site string a user types when saving a credential, so the
/// Keychain key and the manager's dedupe both operate on the canonical host.
public enum CredentialSitePolicy {

    /// Strips scheme, credentials, path, query, and fragment, returning the
    /// lowercase host (a trailing DNS dot is equivalent to the undotted form).
    /// Bare hosts without a scheme ("github.com") are handled too. Empty
    /// input stays empty.
    public static func normalize(_ site: String) -> String {
        let trimmed = site.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let candidate: String
        if let url = URL(string: trimmed), let host = url.host {
            candidate = host
        } else {
            // Bare hosts without a scheme ("github.com") parse with a nil
            // host; take everything up to the first path separator.
            let slash = trimmed.firstIndex(of: "/")
            candidate = slash.map { String(trimmed[..<$0]) } ?? trimmed
        }
        var value = candidate.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix(".") { value.removeLast() }
        return value
    }
}
