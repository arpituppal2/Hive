import Foundation

/// A semantic coordinate in the `[-1, 1]` plane.
///
/// - X axis: `-1` creative/artistic ... `+1` analytical/quantitative.
/// - Y axis: `-1` personal/private/emotional ... `+1` professional/work/institutional.
public struct SemanticCoordinate: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = min(1, max(-1, x))
        self.y = min(1, max(-1, y))
    }
}

/// Prompt 1b coordinate assignment.
///
/// A pure, deterministic on-device heuristic that maps claim text to a
/// `SemanticCoordinate`. Apple Intelligence may override this later via
/// `parseAIJSON(_:)`; the heuristic is the offline fallback.
public struct SemanticCoordinateClassifier: Sendable {
    public init() {}

    /// Maps `claimText` onto the two semantic axes using keyword lexicons.
    public func classify(claimText: String) -> SemanticCoordinate {
        let tokens = Self.tokenize(claimText)

        let profCount = count(of: Self.professionalTerms, in: tokens)
        let persCount = count(of: Self.personalTerms, in: tokens)
        let analyticalCount = count(of: Self.analyticalTerms, in: tokens)
        let creativeCount = count(of: Self.creativeTerms, in: tokens)

        let y = Double(profCount - persCount) / Double(max(1, profCount + persCount))
        let x = Double(analyticalCount - creativeCount) / Double(max(1, analyticalCount + creativeCount))

        return SemanticCoordinate(x: x, y: y)
    }

    /// Robustly parses a JSON object such as `{"x": 0.4, "y": -0.2}`.
    ///
    /// Locates the first `{...}` substring, decodes it, and returns a clamped
    /// `SemanticCoordinate`, or `nil` if it cannot be parsed.
    public func parseAIJSON(_ raw: String) -> SemanticCoordinate? {
        guard let open = raw.firstIndex(of: "{"),
              let close = raw.lastIndex(of: "}"),
              open < close else {
            return nil
        }

        let jsonSubstring = raw[open...close]
        guard let data = String(jsonSubstring).data(using: .utf8) else {
            return nil
        }

        guard let payload = try? JSONDecoder().decode(AICoordinatePayload.self, from: data) else {
            return nil
        }

        return SemanticCoordinate(x: payload.x, y: payload.y)
    }

    // MARK: - Internal payload

    private struct AICoordinatePayload: Decodable {
        var x: Double
        var y: Double
    }

    // MARK: - Matching

    /// Splits text into lowercased word tokens for word-boundary,
    /// case-insensitive matching.
    private static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func count(of lexicon: Set<String>, in tokens: [String]) -> Int {
        tokens.reduce(into: 0) { partial, token in
            if lexicon.contains(token) {
                partial += 1
            }
        }
    }

    // MARK: - Lexicons

    private static let professionalTerms: Set<String> = [
        "job", "work", "university", "college", "company", "research", "project",
        "institution", "degree", "career", "client", "meeting", "deadline",
        "revenue", "funding", "engineer", "manager", "academic", "course", "exam"
    ]

    private static let personalTerms: Set<String> = [
        "feel", "felt", "love", "hate", "family", "friend", "hobby", "habit",
        "home", "weekend", "favorite", "music", "playlist", "emotion",
        "relationship", "dream", "personal"
    ]

    private static let creativeTerms: Set<String> = [
        "paint", "painting", "music", "song", "art", "design", "draw",
        "creative", "poetry", "story", "melody", "compose", "aesthetic",
        "film", "photography"
    ]

    private static let analyticalTerms: Set<String> = [
        "algorithm", "proof", "math", "equation", "model", "data", "analysis",
        "financial", "calculate", "statistics", "logic", "theorem",
        "quantitative", "optimize", "benchmark", "code"
    ]
}
