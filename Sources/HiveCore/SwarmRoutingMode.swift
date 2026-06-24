import Foundation

/// The five Swarm routing modes that determine how a request is answered,
/// ranging from fully local inference to deep online research.
public enum SwarmRoutingMode: String, Codable, Hashable, Sendable, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"

    /// A human-readable label for the routing mode.
    public var displayName: String {
        switch self {
        case .a: return "Local Only"
        case .b: return "Local + Colony"
        case .c: return "Online Augment"
        case .d: return "Full Online"
        case .e: return "Deep Research"
        }
    }

    /// Whether the mode requires retrieving information from online sources.
    public var requiresOnlineRetrieval: Bool {
        switch self {
        case .c, .d: return true
        case .a, .b, .e: return false
        }
    }

    /// Whether the mode is answered purely from on-device context.
    public var isLocalOnly: Bool {
        switch self {
        case .a, .b: return true
        case .c, .d, .e: return false
        }
    }
}

/// The output of the on-device routing classifier.
public struct SwarmRoutingClassification: Codable, Hashable, Sendable {
    /// The resolved routing mode for the request.
    public var mode: SwarmRoutingMode
    /// Confidence in the dominant signal category, clamped to `[0, 1]`.
    public var confidence: Double
    /// Human-readable reasons describing why the mode was chosen.
    public var signals: [String]

    public init(mode: SwarmRoutingMode, confidence: Double, signals: [String]) {
        self.mode = mode
        self.confidence = confidence
        self.signals = signals
    }
}

/// A deterministic, on-device heuristic classifier that maps a prompt to a
/// `SwarmRoutingMode`. The classifier performs no AI inference and is fast
/// enough to run synchronously on the main actor.
public struct SwarmRoutingClassifier: Sendable {
    public init() {}

    /// Minimum confidence required to keep a decisive (non-`C`) mode.
    private static let ambiguityThreshold = 0.72

    private static let firstPersonPatterns: [String] = [
        "\\bmy\\b", "\\bi\\b", "\\bwe\\b", "\\bi'm\\b", "\\bi am\\b", "\\bmine\\b"
    ]

    private static let relationalTerms: [String] = [
        "connect", "compare", "contradict", "between", "relationship", "versus"
    ]

    private static let temporalTerms: [String] = [
        "latest", "current", "recent", "now", "today", "this year",
        "price", "news", "released", "version"
    ]

    private static let definitionalTerms: [String] = [
        "what is", "who is", "explain", "capital of", "how does", "when did"
    ]

    /// Classifies a prompt into a routing mode using deterministic heuristics.
    ///
    /// - Parameters:
    ///   - prompt: The raw user prompt.
    ///   - hasColonyContext: Whether any on-device Colony context is available.
    ///   - knownEntityNames: Names the user has previously referenced; their
    ///     presence reinforces local-leaning signals.
    /// - Returns: A `SwarmRoutingClassification` describing the chosen mode.
    public func classify(
        prompt: String,
        hasColonyContext: Bool,
        knownEntityNames: [String] = []
    ) -> SwarmRoutingClassification {
        let lower = prompt.lowercased()
        var signals: [String] = []

        // Detect first-person / local-leaning signals.
        var localWeight = 0
        if Self.matchesAny(regexPatterns: Self.firstPersonPatterns, in: lower) {
            localWeight += 2
            signals.append("first-person language suggests personal context")
        }
        let matchedEntities = knownEntityNames.filter { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !trimmed.isEmpty && lower.contains(trimmed)
        }
        if !matchedEntities.isEmpty {
            localWeight += 1
            signals.append("references known entity: \(matchedEntities.joined(separator: ", "))")
        }

        // Detect relational language → favors Mode B.
        var relationalWeight = 0
        if Self.containsAny(lower, terms: Self.relationalTerms) {
            relationalWeight += 2
            signals.append("relational language suggests connecting local knowledge")
        }

        // Detect temporal / external signals → favors Mode C.
        var temporalWeight = 0
        if Self.containsAny(lower, terms: Self.temporalTerms) {
            temporalWeight += 2
            signals.append("temporal or external signals suggest current information")
        }

        // Detect purely-external definitional language → favors Mode D.
        var definitionalWeight = 0
        let hasDefinitional = Self.containsAny(lower, terms: Self.definitionalTerms)
        if hasDefinitional {
            definitionalWeight += 2
            signals.append("definitional phrasing suggests an external lookup")
        }

        let hasLocal = localWeight > 0
        let hasExternal = temporalWeight > 0
        let hasRelational = relationalWeight > 0

        // Decision rule producing a candidate mode.
        var mode: SwarmRoutingMode
        var dominantWeight: Int
        if !hasLocal && (hasExternal || hasDefinitional) {
            // No local signals + external/definitional present → D.
            mode = .d
            dominantWeight = max(definitionalWeight, temporalWeight)
        } else if hasExternal && hasLocal {
            // External + local both present → C.
            mode = .c
            dominantWeight = temporalWeight
        } else if hasRelational && hasLocal {
            // Relational + local → B.
            mode = .b
            dominantWeight = relationalWeight
        } else if hasLocal {
            // Local only → A.
            mode = .a
            dominantWeight = localWeight
        } else {
            // Nothing matched decisively; treat as ambiguous.
            mode = .e
            dominantWeight = 0
        }

        // Confidence = strength of dominant category / total signal weight.
        let totalWeight = localWeight + relationalWeight + temporalWeight + definitionalWeight
        let confidence: Double
        if totalWeight > 0 {
            confidence = Self.clamp(Double(dominantWeight) / Double(totalWeight))
        } else {
            confidence = 0.0
        }

        // Zero-context bias: local signals but nothing to answer from → C.
        if mode.isLocalOnly && !hasColonyContext {
            signals.append("zero local context available; biasing toward Online Augment")
            return SwarmRoutingClassification(mode: .c, confidence: confidence, signals: signals)
        }

        // Ambiguity resolution: Mode E (or low confidence) defaults to C with
        // full local context per spec.
        if mode == .e || confidence < Self.ambiguityThreshold {
            signals.append("ambiguous: defaulted to Online Augment")
            return SwarmRoutingClassification(mode: .c, confidence: confidence, signals: signals)
        }

        return SwarmRoutingClassification(mode: mode, confidence: confidence, signals: signals)
    }

    /// Maps an existing `SwarmRequestIntent` to a routing mode.
    public func mode(for intent: SwarmRequestIntent) -> SwarmRoutingMode {
        switch intent {
        case .answerDirectly: return .a
        case .answerFromContext: return .b
        case .lookOnline: return .c
        case .incorporateInformation: return .c
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    private static func containsAny(_ value: String, terms: [String]) -> Bool {
        terms.contains { value.contains($0) }
    }

    private static func matchesAny(regexPatterns: [String], in value: String) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        for pattern in regexPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            if regex.firstMatch(in: value, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }
}
