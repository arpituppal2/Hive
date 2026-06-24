import Foundation

public enum LifeDomain: String, Codable, CaseIterable, Sendable {
    case education
    case projects
    case hardware
    case finance
    case health
    case family
    case identity
    case background

    public var label: String {
        switch self {
        case .education:
            return "Education"
        case .projects:
            return "Projects"
        case .hardware:
            return "Hardware"
        case .finance:
            return "Finance"
        case .health:
            return "Health"
        case .family:
            return "Family"
        case .identity:
            return "Identity"
        case .background:
            return "Background"
        }
    }
}

public struct GraphLifeDomainClassifier: Sendable {
    public init() {}

    public static func domain(for node: GraphNodeRecord) -> LifeDomain {
        GraphLifeDomainClassifier().domain(for: node)
    }

    public func domain(for node: GraphNodeRecord) -> LifeDomain {
        let text = [
            node.title,
            node.kind.rawValue,
            node.semanticColorKey ?? "",
            node.memoryLayer.rawValue
        ]
            .joined(separator: " ")
            .lowercased()

        if containsAny(text, ["ucla", "mathematics", "math", "student", "education", "class", "course", "cs31", "physics", "khan academy"]) {
            return .education
        }
        if containsAny(text, ["finance", "grant", "money", "cash", "shopping", "buy", "funding", "scholarship", "alpaca", "stock", "quant"]) {
            return .finance
        }
        if containsAny(text, ["app", "startup", "project", "swiftui", "react", "vercel", "railway"]) {
            return .projects
        }
        if containsAny(text, ["laptop", "workstation", "gpu", "ram", "hardware", "ollama", "chrome", "playwright", "battery", "fan"]) {
            return .hardware
        }
        if containsAny(text, ["health", "sleep", "workout", "weight", "male", "height", "body", "dental", "root canal", "creatine", "swim"]) {
            return .health
        }
        if containsAny(text, ["family", "sister", "parents", "dad", "mom", "avni", "isabella", "rain", "relationship", "social"]) {
            return .family
        }
        if containsAny(text, ["preference", "prefers", "identity", "iq", "debate", "indian", "bio", "personality", "values", "dislikes"]) {
            return .identity
        }
        return .background
    }

    private func containsAny(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0) }
    }
}

public struct GraphRelationshipPolicy: Sendable {
    public static let visibleStrengthThreshold = 0.3
    public static let backgroundRenderStrengthThreshold = 0.78
    public static let backgroundRenderConfidenceThreshold = 0.72
    public static let backgroundRenderMinimumEvidenceCount = 2

    public init() {}

    public static func visibleOpacity(forStrength strength: Double) -> Double {
        let clamped = min(1, max(0, strength))
        return clamped >= visibleStrengthThreshold ? clamped : 0
    }

    public static func isVisibleConnection(_ edge: GraphEdgeRecord) -> Bool {
        visibleOpacity(forStrength: edge.strength) > 0
    }

    public static func isBackgroundRenderableConnection(_ edge: GraphEdgeRecord) -> Bool {
        guard isVisibleConnection(edge),
              edge.strength >= backgroundRenderStrengthThreshold,
              edge.confidence >= backgroundRenderConfidenceThreshold,
              edge.evidenceCount >= backgroundRenderMinimumEvidenceCount,
              !edge.id.hasPrefix("audit-") else {
            return false
        }
        switch edge.predicate {
        case .mentions, .sourceOf, .markovTransition, .markovLoop, .hamiltonianPath:
            return false
        case .supports, .contradicts, .related, .partOf, .causedBy, .temporal, .duplicates, .concludes:
            return true
        }
    }
}

public struct GraphCoordinateClassification: Codable, Hashable, Sendable {
    public var analyticalCreative: Double
    public var professionalPersonal: Double
    public var reason: String

    public init(analyticalCreative: Double, professionalPersonal: Double, reason: String) {
        self.analyticalCreative = min(1, max(-1, analyticalCreative))
        self.professionalPersonal = min(1, max(-1, professionalPersonal))
        self.reason = reason
    }
}

public struct GraphSemanticCoordinate: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum GraphSemanticAxes {
    public static let horizontalExtent: Double = 1_120
    public static let verticalExtent: Double = 780
    public static let horizontalNodeRange: Double = horizontalExtent / 2
    public static let verticalNodeRange: Double = verticalExtent / 2
    public static let overviewPadding: Double = 96

    public static let professionalLabel = "Professional"
    public static let personalLabel = "Personal"
    public static let analyticalLabel = "Analytical"
    public static let creativeLabel = "Creative"
    public static let semanticSummary = "Up is professional, down is personal; right is analytical, left is creative. Coordinates range from -1 to 1 on each axis; positive X leans right and positive Y leans up."
}

public struct GraphAxisVocabularyReview: Codable, Hashable, Sendable {
    public var isApproved: Bool
    public var message: String

    public init(isApproved: Bool, message: String) {
        self.isApproved = isApproved
        self.message = message
    }
}

public struct GraphAxisVocabulary: Codable, Hashable, Sendable {
    public static let topKey = "hive.graph.axis.top"
    public static let bottomKey = "hive.graph.axis.bottom"
    public static let rightKey = "hive.graph.axis.right"
    public static let leftKey = "hive.graph.axis.left"

    public static let `default` = GraphAxisVocabulary(
        top: GraphSemanticAxes.professionalLabel,
        bottom: GraphSemanticAxes.personalLabel,
        right: GraphSemanticAxes.analyticalLabel,
        left: GraphSemanticAxes.creativeLabel
    )

    public var top: String
    public var bottom: String
    public var right: String
    public var left: String

    public init(top: String, bottom: String, right: String, left: String) {
        self.top = GraphAxisVocabulary.clean(top)
        self.bottom = GraphAxisVocabulary.clean(bottom)
        self.right = GraphAxisVocabulary.clean(right)
        self.left = GraphAxisVocabulary.clean(left)
    }

    public static func current(defaults: UserDefaults = .standard) -> GraphAxisVocabulary {
        let candidate = GraphAxisVocabulary(
            top: defaults.string(forKey: topKey) ?? Self.default.top,
            bottom: defaults.string(forKey: bottomKey) ?? Self.default.bottom,
            right: defaults.string(forKey: rightKey) ?? Self.default.right,
            left: defaults.string(forKey: leftKey) ?? Self.default.left
        )
        return candidate.review.isApproved ? candidate : .default
    }

    public func save(defaults: UserDefaults = .standard) {
        defaults.set(top, forKey: Self.topKey)
        defaults.set(bottom, forKey: Self.bottomKey)
        defaults.set(right, forKey: Self.rightKey)
        defaults.set(left, forKey: Self.leftKey)
    }

    public var review: GraphAxisVocabularyReview {
        let pairs = [
            ("top and bottom", top, bottom),
            ("right and left", right, left)
        ]
        for pair in pairs {
            guard !pair.1.isEmpty, !pair.2.isEmpty else {
                return GraphAxisVocabularyReview(isApproved: false, message: "Each axis end needs a clear word.")
            }
            guard pair.1.count <= 28, pair.2.count <= 28 else {
                return GraphAxisVocabularyReview(isApproved: false, message: "Axis words need to stay short enough to scan.")
            }
            guard semanticDistance(pair.1, pair.2) >= 0.58 else {
                return GraphAxisVocabularyReview(isApproved: false, message: "The \(pair.0) words are too similar for Hive to place memories reliably.")
            }
        }
        return GraphAxisVocabularyReview(isApproved: true, message: "Approved. Hive can treat these as polar axes.")
    }

    public var semanticSummary: String {
        "Up is \(top), down is \(bottom); right is \(right), left is \(left). Coordinates range from -1 to 1 on each axis."
    }

    public var topTerms: [String] { terms(from: top) }
    public var bottomTerms: [String] { terms(from: bottom) }
    public var rightTerms: [String] { terms(from: right) }
    public var leftTerms: [String] { terms(from: left) }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func terms(from value: String) -> [String] {
        let lower = value.lowercased()
        let parts = lower
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
        return Array(Set(([lower] + parts).filter { !$0.isEmpty }))
    }

    private func semanticDistance(_ lhs: String, _ rhs: String) -> Double {
        let left = Set(terms(from: lhs))
        let right = Set(terms(from: rhs))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        if left == right { return 0 }
        let intersection = left.intersection(right)
        let union = left.union(right)
        let jaccard = Double(intersection.count) / Double(max(union.count, 1))
        let prefixPenalty = normalized(lhs).hasPrefix(normalized(rhs)) || normalized(rhs).hasPrefix(normalized(lhs)) ? 0.2 : 0
        return max(0, 1 - jaccard - prefixPenalty)
    }

    private func normalized(_ value: String) -> String {
        value.lowercased().filter(\.isLetter)
    }
}

public struct GraphCoordinateClassifier: Sendable {
    public var axisVocabulary: GraphAxisVocabulary

    public init(axisVocabulary: GraphAxisVocabulary = .default) {
        self.axisVocabulary = axisVocabulary.review.isApproved ? axisVocabulary : .default
    }

    public static func current(defaults: UserDefaults = .standard) -> GraphCoordinateClassifier {
        GraphCoordinateClassifier(axisVocabulary: GraphAxisVocabulary.current(defaults: defaults))
    }

    public func classify(_ node: GraphNodeRecord) -> GraphCoordinateClassification {
        let text = [
            node.title,
            node.kind.rawValue,
            node.semanticColorKey ?? "",
            node.memoryLayer.rawValue
        ]
            .joined(separator: " ")
            .lowercased()

        if isDemographicNoise(text) {
            return GraphCoordinateClassification(
                analyticalCreative: 0,
                professionalPersonal: -0.3,
                reason: "Demographic memories are low-signal and stay near the personal center unless the source gives stronger context."
            )
        }

        let xAxis = boostedAxisScore(
            base: semanticAxisScore(
                text,
                positive: axisVocabulary.rightTerms + analyticalTerms,
                negative: axisVocabulary.leftTerms + creativeTerms
            ),
            boost: creativeEventAxisBoost(text)
        )
        let yAxis = boostedAxisScore(
            base: semanticAxisScore(
                text,
                positive: axisVocabulary.topTerms + professionalTerms,
                negative: axisVocabulary.bottomTerms + personalTerms
            ),
            boost: projectProfessionalAxisBoost(text)
        )
        let combinedConfidence = max(xAxis.confidence, yAxis.confidence)
        let x = xAxis.confidence >= 0.4 ? xAxis.value : 0
        let y = yAxis.confidence >= 0.4 ? yAxis.value : 0
        let finalX = combinedConfidence >= 0.4 ? x : 0
        let finalY = combinedConfidence >= 0.4 ? y : 0

        return GraphCoordinateClassification(
            analyticalCreative: finalX,
            professionalPersonal: finalY,
            reason: combinedConfidence >= 0.4
                ? axisVocabulary.semanticSummary
                : "Not enough semantic evidence to place this memory away from center."
        )
    }

    public func unitCoordinate(for node: GraphNodeRecord) -> GraphSemanticCoordinate {
        let classification = classify(node)
        return GraphSemanticCoordinate(
            x: classification.analyticalCreative,
            y: classification.professionalPersonal
        )
    }

    public func coordinate(for node: GraphNodeRecord, index: Int = 0, total: Int = 1) -> GraphSemanticCoordinate {
        let classification = classify(node)
        let jitter = deterministicJitter(for: node.id.isEmpty ? node.title : node.id)
        let crowdingRadius = 24.0 * sqrt(Double(max(total, 1)))
        let angle = Double(index) * Double.pi * (3 - sqrt(5))
        let isCentered = abs(classification.analyticalCreative) < 0.001 && abs(classification.professionalPersonal) < 0.001
        let crowding = min(70, crowdingRadius) * (isCentered ? 0.08 : 0.22)
        let jitterScale = isCentered ? 0.14 : 1

        return GraphSemanticCoordinate(
            x: min(GraphSemanticAxes.horizontalExtent, max(-GraphSemanticAxes.horizontalExtent, classification.analyticalCreative * GraphSemanticAxes.horizontalNodeRange + jitter.x * 42 * jitterScale + cos(angle) * crowding)),
            y: min(GraphSemanticAxes.verticalExtent, max(-GraphSemanticAxes.verticalExtent, classification.professionalPersonal * GraphSemanticAxes.verticalNodeRange + jitter.y * 38 * jitterScale + sin(angle) * crowding))
        )
    }

    private func semanticAxisScore(_ text: String, positive: [String], negative: [String]) -> (value: Double, confidence: Double) {
        let tokens = Set(text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        let positiveScore = termEvidenceScore(text: text, tokens: tokens, terms: positive)
        let negativeScore = termEvidenceScore(text: text, tokens: tokens, terms: negative)
        let total = positiveScore + negativeScore
        guard total > 0 else { return (0, 0) }
        let raw = (positiveScore - negativeScore) / max(total, 1.0)
        let magnitude = min(0.98, abs(raw) * min(1, 0.52 + total / 4.2))
        let value = (raw < 0 ? -1.0 : 1.0) * magnitude
        let confidence = min(1, total / 2.6)
        return (min(1, max(-1, value)), confidence)
    }

    private func boostedAxisScore(
        base: (value: Double, confidence: Double),
        boost: (value: Double, confidence: Double)?
    ) -> (value: Double, confidence: Double) {
        guard let boost else { return base }
        if base.confidence < 0.4 || abs(boost.value) > abs(base.value) {
            return boost
        }
        let totalConfidence = max(0.001, base.confidence + boost.confidence)
        let value = ((base.value * base.confidence) + (boost.value * boost.confidence)) / totalConfidence
        return (
            value: min(1, max(-1, value)),
            confidence: min(1, max(base.confidence, boost.confidence))
        )
    }

    private func projectProfessionalAxisBoost(_ text: String) -> (value: Double, confidence: Double)? {
        let projectMarkers = [
            "app", "application", "project", "prototype", "built", "build", "developed",
            "development", "created", "launched", "implemented", "client", "role"
        ]
        let concreteWorkMarkers = [
            "react", "swift", "swiftui", "metal", "shader", "rendering", "3d", "software",
            "engineering", "code", "algorithm", "data", "model"
        ]
        guard projectMarkers.contains(where: { text.contains($0) }),
              concreteWorkMarkers.contains(where: { text.contains($0) }) else {
            return nil
        }
        return (0.74, 0.78)
    }

    private func creativeEventAxisBoost(_ text: String) -> (value: Double, confidence: Double)? {
        let eventMarkers = ["tournament", "event", "competition"]
        let leadershipMarkers = ["director", "organizer", "organized", "created", "designed", "planned"]
        guard eventMarkers.contains(where: { text.contains($0) }),
              leadershipMarkers.contains(where: { text.contains($0) }) else {
            return nil
        }
        return (-0.32, 0.56)
    }

    private func termEvidenceScore(text: String, tokens: Set<String>, terms: [String]) -> Double {
        var seen = Set<String>()
        return terms.reduce(0) { score, rawTerm in
            let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !term.isEmpty, seen.insert(term).inserted else { return score }
            let matches: Bool
            if term.contains(" ") {
                matches = text.contains(term)
            } else {
                matches = tokens.contains(term)
            }
            guard matches else { return score }
            return score + axisTermWeight(term)
        }
    }

    private func axisTermWeight(_ term: String) -> Double {
        if strongAxisTerms.contains(term) { return 1.55 }
        if genericAxisTerms.contains(term) { return 0.24 }
        return 1.0
    }

    private func isDemographicNoise(_ text: String) -> Bool {
        text.range(of: #"\b(age\s*)?[0-9]{1,2}\s*(years?\s*old|yo)\b"#, options: .regularExpression) != nil
            || text.range(of: #"\bage\s*[:\-]\s*[0-9]{1,2}\b"#, options: .regularExpression) != nil
    }

    private func polarizeAxis(_ value: Double) -> Double {
        guard abs(value) >= 0.01 else { return 0 }
        let sign = value < 0 ? -1.0 : 1.0
        let absolute = abs(value)
        let magnitude: Double
        if absolute < 0.3 {
            magnitude = min(0.36, absolute * 1.35)
        } else {
            magnitude = min(0.92, 0.26 + absolute * 0.68)
        }
        return sign * magnitude
    }

    private func defaultHorizontalBias(for domain: LifeDomain) -> Double {
        switch domain {
        case .education, .finance, .hardware:
            return 0.24
        case .projects:
            return -0.18
        case .health, .family, .identity:
            return -0.22
        case .background:
            return 0
        }
    }

    private func defaultVerticalBias(for domain: LifeDomain) -> Double {
        switch domain {
        case .education, .projects, .hardware, .finance:
            return 0.22
        case .health, .family, .identity:
            return -0.26
        case .background:
            return 0
        }
    }

    private func deterministicJitter(for value: String) -> (x: Double, y: Double) {
        let digest = Hashing.sha256(data: Data(value.utf8))
        let bytes = Array(digest.utf8)
        guard bytes.count >= 4 else { return (0, 0) }
        let xSeed = Double(Int(bytes[0]) + Int(bytes[1]) * 17)
        let ySeed = Double(Int(bytes[2]) + Int(bytes[3]) * 17)
        return (
            x: (xSeed.truncatingRemainder(dividingBy: 200) / 100) - 1,
            y: (ySeed.truncatingRemainder(dividingBy: 200) / 100) - 1
        )
    }

    private let analyticalTerms = [
        "analysis", "analytical", "algorithm", "algorithms", "architecture", "code",
        "consulting",
        "coding", "competitive", "computer science", "data", "debugging", "developed",
        "development", "engineering", "financial",
        "figures", "math", "mathematics", "metrics", "model", "performance", "python",
        "quant", "react", "research methodology", "shader", "specifications", "swift",
        "swiftui", "system", "systems", "technical", "testing", "metal", "rendering",
        "3d", "database", "programming"
    ]

    private let creativeTerms = [
        "aesthetic", "art", "brainstorming", "brand", "creative", "creative direction",
        "design", "ideation", "music", "narrative", "story", "visual", "visual output",
        "writing", "animation", "competition", "event", "event direction", "interface",
        "presentation", "essay", "content", "tournament", "ui", "ux"
    ]

    private let professionalTerms = [
        "academic", "achievement", "achievements", "certification", "certifications",
        "client", "company", "companies", "degree", "director", "employment",
        "institution", "institutions", "industry", "job", "published", "role", "roles",
        "skill", "skills", "tools", "work", "career", "professional", "project",
        "software", "development", "developed", "engineering", "consulting"
    ]

    private let personalTerms = [
        "body", "family", "fitness", "friend", "health", "hobby", "hobbies", "home",
        "lifestyle", "opinion", "opinions", "personal", "preference", "preferences",
        "relationship", "relationships", "sleep", "swimming", "routine", "journal",
        "likes", "dislikes", "mom", "dad", "sister", "parent"
    ]

    private let strongAxisTerms: Set<String> = [
        "algorithm", "algorithms", "code", "debugging", "engineering", "mathematics",
        "metal", "react", "rendering", "shader", "swiftui", "development", "employment",
        "director", "tournament director", "certification", "degree", "client",
        "design", "writing", "music", "art", "swimming", "health", "fitness",
        "personal", "professional"
    ]

    private let genericAxisTerms: Set<String> = [
        "app",
        "application",
        "battery",
        "class",
        "content",
        "course",
        "dashboard",
        "database",
        "education",
        "exam",
        "gpu",
        "grant",
        "hardware",
        "interface",
        "project",
        "projects",
        "ram",
        "research",
        "school",
        "scholarship",
        "task",
        "tools",
        "ui",
        "ux",
        "visual",
        "work",
        "workflow"
    ]
}

public enum GraphPersonalCenter {
    public static func weightedCenter(for nodes: [GraphNodeRecord]) -> GraphSemanticCoordinate {
        let weighted = nodes.reduce(into: (x: 0.0, y: 0.0, weight: 0.0)) { partial, node in
            let weight = weight(for: node)
            partial.x += node.x * weight
            partial.y += node.y * weight
            partial.weight += weight
        }
        guard weighted.weight > 0 else {
            return GraphSemanticCoordinate(x: 0, y: 0)
        }
        return GraphSemanticCoordinate(
            x: weighted.x / weighted.weight,
            y: weighted.y / weighted.weight
        )
    }

    public static func normalizedCoordinate(
        for node: GraphNodeRecord,
        center: GraphSemanticCoordinate
    ) -> GraphSemanticCoordinate {
        GraphSemanticCoordinate(
            x: node.x - center.x,
            y: node.y - center.y
        )
    }

    public static func weight(for node: GraphNodeRecord) -> Double {
        let confidence = max(0.18, min(1.0, node.confidence))
        return confidence * layerWeight(node.memoryLayer)
    }

    private static func layerWeight(_ layer: MemoryNodeLayer) -> Double {
        switch layer {
        case .definingTrait:
            return 2.8
        case .importantTrait:
            return 2.1
        case .connector:
            return 1.35
        case .detail:
            return 1.0
        }
    }
}

public enum GraphReindexOperation: String, Codable, Hashable, Sendable {
    case move
    case consolidate
    case reconnect
    case split
    case delete
    case create
    case edgeCheck
}

public struct GraphReindexStep: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var nodeID: String
    public var unitX: Double
    public var unitY: Double
    public var mergedWithNodeID: String?
    public var mergedTitle: String?
    public var mergedSizeMultiplier: Double
    public var operation: GraphReindexOperation

    public init(
        id: String,
        nodeID: String,
        unitX: Double,
        unitY: Double,
        mergedWithNodeID: String? = nil,
        mergedTitle: String? = nil,
        mergedSizeMultiplier: Double = 1,
        operation: GraphReindexOperation? = nil
    ) {
        self.id = id
        self.nodeID = nodeID
        self.unitX = min(1, max(-1, unitX))
        self.unitY = min(1, max(-1, unitY))
        self.mergedWithNodeID = mergedWithNodeID
        self.mergedTitle = mergedTitle
        self.mergedSizeMultiplier = min(1.75, max(0.75, mergedSizeMultiplier))
        self.operation = operation ?? (mergedWithNodeID == nil ? .move : .consolidate)
    }

    public var affectedNodeIDs: Set<String> {
        var ids = Set([nodeID])
        if let mergedWithNodeID {
            ids.insert(mergedWithNodeID)
        }
        return ids
    }

    enum CodingKeys: String, CodingKey {
        case id
        case nodeID
        case unitX
        case unitY
        case mergedWithNodeID
        case mergedTitle
        case mergedSizeMultiplier
        case operation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let nodeID = try container.decode(String.self, forKey: .nodeID)
        let unitX = try container.decode(Double.self, forKey: .unitX)
        let unitY = try container.decode(Double.self, forKey: .unitY)
        let mergedWithNodeID = try container.decodeIfPresent(String.self, forKey: .mergedWithNodeID)
        let mergedTitle = try container.decodeIfPresent(String.self, forKey: .mergedTitle)
        let mergedSizeMultiplier = try container.decodeIfPresent(Double.self, forKey: .mergedSizeMultiplier) ?? 1
        let operation = try container.decodeIfPresent(GraphReindexOperation.self, forKey: .operation)
        self.init(
            id: id,
            nodeID: nodeID,
            unitX: unitX,
            unitY: unitY,
            mergedWithNodeID: mergedWithNodeID,
            mergedTitle: mergedTitle,
            mergedSizeMultiplier: mergedSizeMultiplier,
            operation: operation
        )
    }
}

public struct GraphReindexApplication: Codable, Hashable, Sendable {
    public var snapshot: HiveGraphSnapshot
    public var pairAuditPairCount: Int
    public var acceptedPairAuditEdgeCount: Int
    public var deletedNodeIDs: Set<String>
    public var consolidatedNodeIDs: Set<String>

    public init(
        snapshot: HiveGraphSnapshot,
        pairAuditPairCount: Int,
        acceptedPairAuditEdgeCount: Int,
        deletedNodeIDs: Set<String> = [],
        consolidatedNodeIDs: Set<String> = []
    ) {
        self.snapshot = snapshot
        self.pairAuditPairCount = pairAuditPairCount
        self.acceptedPairAuditEdgeCount = acceptedPairAuditEdgeCount
        self.deletedNodeIDs = deletedNodeIDs
        self.consolidatedNodeIDs = consolidatedNodeIDs
    }
}

public struct GraphReindexPlan: Codable, Hashable, Sendable {
    public var steps: [GraphReindexStep]

    public init(steps: [GraphReindexStep]) {
        self.steps = steps
    }

    public struct PlanningResult: Hashable, Sendable {
        public var plan: GraphReindexPlan
        public var usedFoundationModels: Bool
        public var fallbackReason: String?

        public init(
            plan: GraphReindexPlan,
            usedFoundationModels: Bool,
            fallbackReason: String? = nil
        ) {
            self.plan = plan
            self.usedFoundationModels = usedFoundationModels
            self.fallbackReason = fallbackReason
        }
    }

    public static func make(
        nodes: [GraphNodeRecord],
        edges: [GraphEdgeRecord],
        maxSteps: Int = 28
    ) -> GraphReindexPlan {
        let coordinateFreeNodes = coordinateFreeInputNodes(nodes)
        let boundedMaxSteps = max(0, maxSteps)
        let junkNodeIDs = Set(coordinateFreeNodes.filter(isJunkReindexNode).map(\.id))
        let workNodes = coordinateFreeNodes.filter { !junkNodeIDs.contains($0.id) }
        let workNodeIDs = Set(workNodes.map(\.id))
        let nodeMap = Dictionary(uniqueKeysWithValues: workNodes.map { ($0.id, $0) })
        let visibleEdges = edges.filter {
            GraphRelationshipPolicy.isVisibleConnection($0)
                && workNodeIDs.contains($0.fromID)
                && workNodeIDs.contains($0.toID)
        }
        let candidateScores = Dictionary(uniqueKeysWithValues: workNodes.map { node in
            return (node.id, reindexPriority(for: node, edges: visibleEdges))
        })
        let rankedNodes = workNodes.sorted { lhs, rhs in
            let left = candidateScores[lhs.id, default: 0]
            let right = candidateScores[rhs.id, default: 0]
            if abs(left - right) > 0.0001 { return left > right }
            if layerRank(lhs.memoryLayer) == layerRank(rhs.memoryLayer) {
                if lhs.confidence == rhs.confidence {
                    return lhs.id < rhs.id
                }
                return lhs.confidence > rhs.confidence
            }
            return layerRank(lhs.memoryLayer) < layerRank(rhs.memoryLayer)
        }

        var consumed = Set<String>()
        var steps = coordinateFreeNodes
            .filter { junkNodeIDs.contains($0.id) }
            .sorted { $0.id < $1.id }
            .map { node in
                return GraphReindexStep(
                    id: "reindex-delete-\(node.id)",
                    nodeID: node.id,
                    unitX: 0,
                    unitY: 0,
                    mergedSizeMultiplier: 0.75,
                    operation: .delete
                )
            }
        guard boundedMaxSteps > 0 else {
            return GraphReindexPlan(steps: deconflictedSteps(steps))
        }

        var movementStepCount = 0
        for node in rankedNodes where !consumed.contains(node.id) && movementStepCount < boundedMaxSteps {
            let ownUnit = semanticReindexUnit(for: node, nodeMap: nodeMap, edges: visibleEdges)
            let merge = strongestMergeCandidate(
                for: node,
                nodeMap: nodeMap,
                edges: visibleEdges,
                consumed: consumed
            )

            if let merge, let other = nodeMap[merge.otherNodeID] {
                let otherUnit = semanticReindexUnit(for: other, nodeMap: nodeMap, edges: visibleEdges)
                let lhsWeight = max(0.2, node.confidence)
                let rhsWeight = max(0.2, other.confidence) * max(0.4, merge.edge.strength)
                let totalWeight = lhsWeight + rhsWeight
                let unitX = (ownUnit.x * lhsWeight + otherUnit.x * rhsWeight) / totalWeight
                let unitY = (ownUnit.y * lhsWeight + otherUnit.y * rhsWeight) / totalWeight
                steps.append(GraphReindexStep(
                    id: "reindex-\(node.id)-\(other.id)",
                    nodeID: node.id,
                    unitX: unitX,
                    unitY: unitY,
                    mergedWithNodeID: other.id,
                    mergedTitle: mergedTitle(node.title, other.title),
                    mergedSizeMultiplier: 1 + min(0.58, merge.edge.strength * 0.46),
                    operation: .consolidate
                ))
                movementStepCount += 1
                consumed.insert(other.id)
            } else {
                steps.append(GraphReindexStep(
                    id: "reindex-\(node.id)",
                    nodeID: node.id,
                    unitX: ownUnit.x,
                    unitY: ownUnit.y,
                    mergedSizeMultiplier: reindexSizeMultiplier(for: node),
                    operation: reindexOperation(for: node, edges: visibleEdges)
                ))
                movementStepCount += 1
            }
            consumed.insert(node.id)
        }

        return GraphReindexPlan(steps: deconflictedSteps(steps))
    }

    public static func makeWithFoundationModels(
        nodes: [GraphNodeRecord],
        edges: [GraphEdgeRecord],
        maxSteps: Int = 28,
        orchestrator: HiveFoundationModelsOrchestrator = HiveFoundationModelsOrchestrator()
    ) async -> GraphReindexPlan {
        await makeWithFoundationModelsResult(
            nodes: nodes,
            edges: edges,
            maxSteps: maxSteps,
            orchestrator: orchestrator
        ).plan
    }

    public static func makeWithFoundationModelsResult(
        nodes: [GraphNodeRecord],
        edges: [GraphEdgeRecord],
        maxSteps: Int = 28,
        orchestrator: HiveFoundationModelsOrchestrator = HiveFoundationModelsOrchestrator()
    ) async -> PlanningResult {
        let coordinateFreeNodes = coordinateFreeInputNodes(nodes)
        let deterministic = make(nodes: coordinateFreeNodes, edges: edges, maxSteps: maxSteps)
        let result = await orchestrator.planGraphReindex(nodes: coordinateFreeNodes, edges: edges, maxSteps: maxSteps)
        guard !result.proposal.steps.isEmpty else {
            return PlanningResult(
                plan: deterministic,
                usedFoundationModels: false,
                fallbackReason: result.fallbackReason
            )
        }
        return PlanningResult(
            plan: result.proposal.plan,
            usedFoundationModels: result.usedFoundationModels,
            fallbackReason: result.fallbackReason
        )
    }

    public func applying(to snapshot: HiveGraphSnapshot) -> HiveGraphSnapshot {
        applyingWithAudit(to: snapshot).snapshot
    }

    public func applyingWithAudit(to snapshot: HiveGraphSnapshot) -> GraphReindexApplication {
        guard !steps.isEmpty else {
            return GraphReindexApplication(
                snapshot: snapshot,
                pairAuditPairCount: Self.pairAuditPairCount(for: snapshot.nodes),
                acceptedPairAuditEdgeCount: 0
            )
        }
        let coordinateFreeSnapshotNodes = Self.coordinateFreeInputNodes(snapshot.nodes)
        var nodes = coordinateFreeSnapshotNodes
        let originalNodeMap = Dictionary(uniqueKeysWithValues: coordinateFreeSnapshotNodes.map { ($0.id, $0) })
        let deleteIDs = Set(steps.filter { $0.operation == .delete }.flatMap { Array($0.affectedNodeIDs) })
        let consolidationTargets = Dictionary(uniqueKeysWithValues: steps.compactMap { step -> (String, String)? in
            guard step.operation == .consolidate, let mergedWithNodeID = step.mergedWithNodeID else { return nil }
            return (mergedWithNodeID, step.nodeID)
        })
        nodes.removeAll { deleteIDs.contains($0.id) || consolidationTargets[$0.id] != nil }
        var edges = Self.rewiredEdges(
            snapshot.edges,
            deleting: deleteIDs,
            consolidating: consolidationTargets
        )
        nodes = Self.nodesWithFreshSemanticCoordinates(nodes, edges: edges)
        var targetByNodeID: [String: GraphReindexStep] = [:]
        for step in steps {
            for nodeID in step.affectedNodeIDs {
                targetByNodeID[nodeID] = step
            }
        }
        for index in nodes.indices {
            guard let step = targetByNodeID[nodes[index].id] else { continue }
            nodes[index].x = step.unitX * GraphSemanticAxes.horizontalNodeRange
            nodes[index].y = step.unitY * GraphSemanticAxes.verticalNodeRange
            if step.operation == .consolidate, nodes[index].id == step.nodeID {
                if let mergedTitle = step.mergedTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !mergedTitle.isEmpty {
                    nodes[index].title = mergedTitle
                }
                if let merged = step.mergedWithNodeID.flatMap({ originalNodeMap[$0] }) {
                    nodes[index].confidence = min(1, max(nodes[index].confidence, merged.confidence))
                    nodes[index].sourceRefs = Self.stableUnique(nodes[index].sourceRefs + merged.sourceRefs)
                }
            }
        }
        nodes = Self.deconflictedGraphNodes(nodes)
        let pairAuditPairCount = Self.pairAuditPairCount(for: nodes)
        let previousAuditEdgeIDs = Set(edges.filter(Self.isPairAuditEdge).map(\.id))
        edges = Self.auditedPairwiseEdges(for: nodes, existing: edges)
        let acceptedPairAuditEdgeCount = edges.filter {
            Self.isPairAuditEdge($0) && !previousAuditEdgeIDs.contains($0.id)
        }.count
        return GraphReindexApplication(
            snapshot: HiveGraphSnapshot(nodes: nodes, edges: edges),
            pairAuditPairCount: pairAuditPairCount,
            acceptedPairAuditEdgeCount: acceptedPairAuditEdgeCount,
            deletedNodeIDs: deleteIDs,
            consolidatedNodeIDs: Set(consolidationTargets.keys)
        )
    }

    static func coordinateFreeInputNodes(_ nodes: [GraphNodeRecord]) -> [GraphNodeRecord] {
        nodes.map { node in
            var updated = node
            updated.x = 0
            updated.y = 0
            return updated
        }
    }

    private static func isJunkReindexNode(_ node: GraphNodeRecord) -> Bool {
        let normalized = normalizedTitle(node.title)
        if isSourceMetadataFragmentTitle(node.title) {
            return true
        }
        guard node.kind != .source, node.kind != .insight else { return false }
        if bareLowInformationTitles.contains(normalized)
            || MemoryQualityPolicy.isLowInformationStandaloneTitle(normalized) {
            return true
        }
        if standaloneGeographicTitles.contains(normalized), !MemoryQualityPolicy.containsUserPredicate(node.title) {
            return true
        }
        let words = normalized.split(separator: " ")
        if words.count == 1, normalized.count <= 12, node.sourceRefs.isEmpty {
            return true
        }
        return false
    }

    private static func isSourceMetadataFragmentTitle(_ title: String) -> Bool {
        let raw = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return true }
        if MemoryQualityPolicy.isGeneratedMetadataFragment(raw) {
            return true
        }
        let lowercased = raw.lowercased()
        let normalized = normalizedTitle(raw)

        if lowercased.contains("bundle=")
            || lowercased.contains("path=/")
            || lowercased.contains("running=")
            || lowercased.contains("lastused=")
            || lowercased.contains("uses=")
            || lowercased.hasPrefix("app: ")
            || lowercased.hasPrefix("app |") {
            return true
        }

        if metadataFragmentPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return true
        }
        if metadataFragmentNeedles.contains(where: { lowercased.contains($0) || normalized.contains($0) }) {
            return true
        }
        if metadataFragmentTitles.contains(normalized) {
            return true
        }
        return false
    }

    private static func strongestMergeCandidate(
        for node: GraphNodeRecord,
        nodeMap: [String: GraphNodeRecord],
        edges: [GraphEdgeRecord],
        consumed: Set<String>
    ) -> (edge: GraphEdgeRecord, otherNodeID: String)? {
        edges.compactMap { edge -> (edge: GraphEdgeRecord, otherNodeID: String)? in
            let otherID: String
            if edge.fromID == node.id {
                otherID = edge.toID
            } else if edge.toID == node.id {
                otherID = edge.fromID
            } else {
                return nil
            }
            guard !consumed.contains(otherID), nodeMap[otherID] != nil else { return nil }
            let threshold = edge.predicate == .duplicates ? GraphRelationshipPolicy.visibleStrengthThreshold : 0.72
            guard edge.strength >= threshold else { return nil }
            return (edge, otherID)
        }
        .sorted { lhs, rhs in
            if lhs.edge.strength == rhs.edge.strength {
                if lhs.edge.confidence == rhs.edge.confidence {
                    return lhs.otherNodeID < rhs.otherNodeID
                }
                return lhs.edge.confidence > rhs.edge.confidence
            }
            return lhs.edge.strength > rhs.edge.strength
        }
        .first
    }

    private static func semanticReindexUnit(
        for node: GraphNodeRecord,
        nodeMap: [String: GraphNodeRecord],
        edges: [GraphEdgeRecord]
    ) -> GraphSemanticCoordinate {
        let classifier = GraphCoordinateClassifier.current()
        let own = boundedSemanticUnit(classifier.unitCoordinate(for: node))
        let incident = edges
            .compactMap { edge -> (GraphSemanticCoordinate, Double)? in
                let otherID: String
                if edge.fromID == node.id {
                    otherID = edge.toID
                } else if edge.toID == node.id {
                    otherID = edge.fromID
                } else {
                    return nil
                }
                guard let other = nodeMap[otherID] else { return nil }
                return (boundedSemanticUnit(classifier.unitCoordinate(for: other)), max(0.05, min(1, edge.strength)))
            }
            .sorted { lhs, rhs in lhs.1 > rhs.1 }
            .prefix(6)

        guard !incident.isEmpty else { return own }

        let weighted = incident.reduce(into: (x: 0.0, y: 0.0, weight: 0.0)) { partial, item in
            partial.x += item.0.x * item.1
            partial.y += item.0.y * item.1
            partial.weight += item.1
        }
        guard weighted.weight > 0 else { return own }

        let neighbor = GraphSemanticCoordinate(
            x: weighted.x / weighted.weight,
            y: weighted.y / weighted.weight
        )
        let blend = min(0.24, weighted.weight / (weighted.weight + 4.0))
        return boundedSemanticUnit(GraphSemanticCoordinate(
            x: own.x * (1 - blend) + neighbor.x * blend,
            y: own.y * (1 - blend) + neighbor.y * blend
        ))
    }

    private static func nodesWithFreshSemanticCoordinates(
        _ nodes: [GraphNodeRecord],
        edges: [GraphEdgeRecord]
    ) -> [GraphNodeRecord] {
        let nodeIDs = Set(nodes.map(\.id))
        let visibleEdges = edges.filter {
            GraphRelationshipPolicy.isVisibleConnection($0)
                && nodeIDs.contains($0.fromID)
                && nodeIDs.contains($0.toID)
        }
        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        return nodes.map { node in
            let unit = semanticReindexUnit(for: node, nodeMap: nodeMap, edges: visibleEdges)
            var updated = node
            updated.x = unit.x * GraphSemanticAxes.horizontalNodeRange
            updated.y = unit.y * GraphSemanticAxes.verticalNodeRange
            return updated
        }
    }

    private static func boundedSemanticUnit(_ coordinate: GraphSemanticCoordinate) -> GraphSemanticCoordinate {
        GraphSemanticCoordinate(
            x: min(reindexMaximumSemanticComponent, max(-reindexMaximumSemanticComponent, coordinate.x)),
            y: min(reindexMaximumSemanticComponent, max(-reindexMaximumSemanticComponent, coordinate.y))
        )
    }

    private static func reindexPriority(
        for node: GraphNodeRecord,
        edges: [GraphEdgeRecord]
    ) -> Double {
        let strongestEdge = edges.reduce(0.0) { current, edge in
            guard edge.fromID == node.id || edge.toID == node.id else { return current }
            return max(current, edge.strength)
        }
        let layer = Double(4 - min(3, layerRank(node.memoryLayer))) * 0.11
        return strongestEdge * 0.72 + max(0, min(1, node.confidence)) * 0.34 + layer
    }

    private static func reindexOperation(for node: GraphNodeRecord, edges: [GraphEdgeRecord]) -> GraphReindexOperation {
        let incident = edges.filter { $0.fromID == node.id || $0.toID == node.id }
        if incident.count >= 4 { return .reconnect }
        if node.title.count > 120 && incident.count >= 2 { return .split }
        return .move
    }

    private static func reindexSizeMultiplier(for node: GraphNodeRecord) -> Double {
        switch node.memoryLayer {
        case .definingTrait:
            return 1.16
        case .importantTrait:
            return 1.1
        case .connector:
            return 1.04
        case .detail:
            return 1
        }
    }

    private static func rewiredEdges(
        _ edges: [GraphEdgeRecord],
        deleting deleteIDs: Set<String>,
        consolidating consolidationTargets: [String: String]
    ) -> [GraphEdgeRecord] {
        var byKey: [String: GraphEdgeRecord] = [:]
        for edge in edges {
            guard !deleteIDs.contains(edge.fromID), !deleteIDs.contains(edge.toID) else { continue }
            guard !isPairAuditEdge(edge) else { continue }
            var updated = edge
            if let replacement = consolidationTargets[updated.fromID] {
                updated.fromID = replacement
            }
            if let replacement = consolidationTargets[updated.toID] {
                updated.toID = replacement
            }
            guard updated.fromID != updated.toID else { continue }
            let ordered = [updated.fromID, updated.toID].sorted().joined(separator: "::")
            let key = "\(ordered)::\(updated.predicate.rawValue)"
            if var existing = byKey[key] {
                existing.strength = max(existing.strength, updated.strength)
                existing.confidence = max(existing.confidence, updated.confidence)
                existing.evidenceCount += updated.evidenceCount
                existing.sourceRefs = stableUnique(existing.sourceRefs + updated.sourceRefs)
                if existing.explanation.isEmpty {
                    existing.explanation = updated.explanation
                }
                byKey[key] = existing
            } else {
                byKey[key] = updated
            }
        }
        return byKey.values.sorted { lhs, rhs in lhs.id < rhs.id }
    }

    private static func auditedPairwiseEdges(
        for nodes: [GraphNodeRecord],
        existing edges: [GraphEdgeRecord]
    ) -> [GraphEdgeRecord] {
        let visibleNodes = nodes.filter(\.isUserVisibleGraphNode)
        guard visibleNodes.count > 1 else { return edges }

        var audited = edges.filter { !isPairAuditEdge($0) }
        var visiblePairs = Set<String>()
        var existingRelatedKeys = Set<String>()
        var visibleDegree = Dictionary(uniqueKeysWithValues: visibleNodes.map { ($0.id, 0) })
        for edge in audited where GraphRelationshipPolicy.isVisibleConnection(edge) {
            visiblePairs.insert(edgePairKey(edge.fromID, edge.toID))
            existingRelatedKeys.insert(edgeKey(edge.fromID, edge.toID, edge.predicate))
            visibleDegree[edge.fromID, default: 0] += 1
            visibleDegree[edge.toID, default: 0] += 1
        }

        var candidates: [GraphEdgeRecord] = []
        for leftIndex in visibleNodes.indices {
            let lhs = visibleNodes[leftIndex]
            for rightIndex in visibleNodes.index(after: leftIndex)..<visibleNodes.endIndex {
                let rhs = visibleNodes[rightIndex]
                let pairKey = edgePairKey(lhs.id, rhs.id)
                let relatedKey = edgeKey(lhs.id, rhs.id, .related)
                guard !visiblePairs.contains(pairKey), !existingRelatedKeys.contains(relatedKey) else { continue }
                guard let edge = auditedSemanticEdge(lhs: lhs, rhs: rhs) else { continue }
                candidates.append(edge)
            }
        }

        let totalAuditLimit = min(maximumPairAuditEdges, max(visibleNodes.count, visibleNodes.count * 3))
        let sortedCandidates = candidates.sorted { lhs, rhs in
            if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
            if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
            if lhs.evidenceCount != rhs.evidenceCount { return lhs.evidenceCount > rhs.evidenceCount }
            return lhs.id < rhs.id
        }
        let startingCount = audited.count
        for edge in sortedCandidates {
            guard audited.count < startingCount + totalAuditLimit else { break }
            guard visibleDegree[edge.fromID, default: 0] < maximumPairAuditDegree,
                  visibleDegree[edge.toID, default: 0] < maximumPairAuditDegree else {
                continue
            }
            audited.append(edge)
            visibleDegree[edge.fromID, default: 0] += 1
            visibleDegree[edge.toID, default: 0] += 1
        }

        return audited.sorted { lhs, rhs in lhs.id < rhs.id }
    }

    private static func pairAuditPairCount(for nodes: [GraphNodeRecord]) -> Int {
        let count = nodes.filter(\.isUserVisibleGraphNode).count
        guard count > 1 else { return 0 }
        return count * (count - 1) / 2
    }

    private static func auditedSemanticEdge(lhs: GraphNodeRecord, rhs: GraphNodeRecord) -> GraphEdgeRecord? {
        let leftTokens = meaningfulTokens(lhs.title)
        let rightTokens = meaningfulTokens(rhs.title)
        guard !leftTokens.isEmpty, !rightTokens.isEmpty else { return nil }
        let sharedTokens = leftTokens.intersection(rightTokens)
        let unionCount = max(1, leftTokens.union(rightTokens).count)
        let tokenSimilarity = Double(sharedTokens.count) / Double(unionCount)
        let sharedSources = Set(lhs.sourceRefs).intersection(rhs.sourceRefs)
        let sameSemanticKey = lhs.semanticColorKey != nil && lhs.semanticColorKey == rhs.semanticColorKey

        let distance = normalizedGraphDistance(lhs, rhs)
        let hasSourceBasis = !sharedSources.isEmpty && sharedTokens.count >= 2
        let hasSemanticBasis = sharedTokens.count >= 2 && tokenSimilarity >= 0.28
        let hasClusterBasis = sameSemanticKey && sharedTokens.count >= 2 && tokenSimilarity >= 0.24
        guard hasSourceBasis || hasSemanticBasis || hasClusterBasis else { return nil }
        guard distance <= 1.15 || hasSourceBasis || sharedTokens.count >= 3 else { return nil }

        let sourceRefs = stableUnique(Array(sharedSources) + lhs.sourceRefs.prefix(2) + rhs.sourceRefs.prefix(2))
        let strength = min(0.78, max(0.42, tokenSimilarity + (hasSourceBasis ? 0.24 : 0) + (hasClusterBasis ? 0.12 : 0)))
        return GraphEdgeRecord(
            id: "audit-\(safeID(lhs.id))-\(safeID(rhs.id))-related",
            fromID: lhs.id,
            toID: rhs.id,
            predicate: .related,
            strength: strength,
            confidence: min(0.82, max(0.46, strength + 0.08)),
            evidenceCount: max(1, sharedTokens.count + sharedSources.count),
            sourceRefs: Array(sourceRefs.prefix(6)),
            explanation: "Hive pair audit found shared source context or topic language."
        )
    }

    private static func normalizedGraphDistance(_ lhs: GraphNodeRecord, _ rhs: GraphNodeRecord) -> Double {
        let x = (lhs.x - rhs.x) / max(1, GraphSemanticAxes.horizontalNodeRange)
        let y = (lhs.y - rhs.y) / max(1, GraphSemanticAxes.verticalNodeRange)
        return sqrt(x * x + y * y)
    }

    private static func deconflictedSteps(_ steps: [GraphReindexStep]) -> [GraphReindexStep] {
        var occupied = Set<String>()
        return steps.enumerated().map { index, step in
            guard step.operation != .delete else { return step }
            var updated = step
            var bucket = coordinateBucket(x: updated.unitX, y: updated.unitY)
            var attempt = 0
            while occupied.contains(bucket), attempt < 16 {
                attempt += 1
                let seed = deterministicSeed(for: "\(updated.id)-\(index)-\(attempt)")
                let angle = Double(seed % 720) / 720.0 * Double.pi * 2
                let radius = min(0.085, 0.014 + Double(attempt) * 0.006)
                updated.unitX = min(1, max(-1, updated.unitX + cos(angle) * radius))
                updated.unitY = min(1, max(-1, updated.unitY + sin(angle) * radius))
                bucket = coordinateBucket(x: updated.unitX, y: updated.unitY)
            }
            occupied.insert(bucket)
            return updated
        }
    }

    private static func deconflictedGraphNodes(_ nodes: [GraphNodeRecord]) -> [GraphNodeRecord] {
        var occupied = Set<String>()
        return nodes.enumerated().map { index, node in
            var updated = node
            var bucket = graphCoordinateBucket(x: updated.x, y: updated.y)
            var attempt = 0
            while occupied.contains(bucket), attempt < 16 {
                attempt += 1
                let seed = deterministicSeed(for: "\(updated.id)-final-\(index)-\(attempt)")
                let angle = Double(seed % 720) / 720.0 * Double.pi * 2
                let radius = 3.5 + Double(attempt) * 2.5
                updated.x = min(GraphSemanticAxes.horizontalNodeRange, max(-GraphSemanticAxes.horizontalNodeRange, updated.x + cos(angle) * radius))
                updated.y = min(GraphSemanticAxes.verticalNodeRange, max(-GraphSemanticAxes.verticalNodeRange, updated.y + sin(angle) * radius))
                bucket = graphCoordinateBucket(x: updated.x, y: updated.y)
            }
            occupied.insert(bucket)
            return updated
        }
    }

    private static func edgePairKey(_ lhs: String, _ rhs: String) -> String {
        [lhs, rhs].sorted().joined(separator: "::")
    }

    private static func edgeKey(_ lhs: String, _ rhs: String, _ predicate: RelationshipPredicate) -> String {
        "\(edgePairKey(lhs, rhs))::\(predicate.rawValue)"
    }

    private static func isPairAuditEdge(_ edge: GraphEdgeRecord) -> Bool {
        edge.id.hasPrefix("audit-") && edge.predicate == .related
    }

    private static func coordinateBucket(x: Double, y: Double) -> String {
        "\(Int((x * 10_000).rounded()))::\(Int((y * 10_000).rounded()))"
    }

    private static func graphCoordinateBucket(x: Double, y: Double) -> String {
        "\(Int((x * 100).rounded()))::\(Int((y * 100).rounded()))"
    }

    private static func deterministicSeed(for value: String) -> Int {
        value.unicodeScalars.reduce(17) { partial, scalar in
            (partial &* 31 + Int(scalar.value)) % 100_000
        }
    }

    private static func meaningfulTokens(_ text: String) -> Set<String> {
        Set(normalizedTitle(text)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 4 && !semanticStopwords.contains($0) && !bareLowInformationTitles.contains($0) && !MemoryQualityPolicy.isLowInformationStandaloneTitle($0) })
    }

    private static func normalizedTitle(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func safeID(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private static func stableUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static let bareLowInformationTitles: Set<String> = [
        "work",
        "personal",
        "background",
        "professional",
        "creative",
        "analytical",
        "school",
        "education",
        "finance",
        "hardware",
        "health",
        "family",
        "system",
        "project",
        "projects",
        "tools",
        "workflow",
        "research",
        "shopping",
        "apps",
        "app",
        "battery health",
        "cycle count",
        "experience",
        "experiences",
        "life",
        "information",
        "thing",
        "things",
        "stuff",
        "note",
        "notes",
        "memory",
        "memories",
        "source",
        "sources",
        "idea",
        "ideas",
        "content",
        "topic",
        "topics",
        "general",
        "misc",
        "miscellaneous",
        "keep",
        "prose",
        "platform",
        "location",
        "captured",
        "uploads",
        "none pasted",
        "none",
        "enabled",
        "read",
        "capture",
        "captures",
        "applications",
        "utilities",
        "profiles",
        "achievements",
        "coursework",
        "relevant coursework",
        "ca relevant coursework"
    ]

    private static let standaloneGeographicTitles: Set<String> = [
        "los angeles",
        "california",
        "ca",
        "united states",
        "usa",
        "us",
        "new york",
        "san francisco",
        "bay area",
        "cupertino",
        "austin",
        "seattle"
    ]

    private static let metadataFragmentPrefixes: Set<String> = [
        "captured at:",
        "captured_at:",
        "captured:",
        "location to grab:",
        "location_to_grab:",
        "pasted location:",
        "pasted_location:",
        "enabled source plugins:",
        "enabled_source_plugins:",
        "prompt for hive:",
        "prompt_for_hive:",
        "capture kind:",
        "capture_kind:",
        "app:",
        "app |",
        "page capture"
    ]

    private static let metadataFragmentNeedles: Set<String> = [
        "none pasted",
        "from downloads",
        "from assets",
        "enabled source plugins",
        "google drive links and web pages uploads",
        "location to grab",
        "pasted location",
        "prompt for hive",
        "capture kind",
        "capture_kind",
        "bundle com",
        "system applications utilities",
        "application monitor",
        "activity monitor",
        "activitymonitor"
    ]

    private static let metadataFragmentTitles: Set<String> = [
        "aresume",
        "page capture",
        "memory boundary reset",
        "hive start questions",
        "captured memory seed"
    ]

    private static let reindexMaximumSemanticComponent = 0.86
    private static let maximumPairAuditDegree = 4
    private static let maximumPairAuditEdges = 420

    private static let semanticStopwords: Set<String> = [
        "about",
        "after",
        "also",
        "because",
        "before",
        "being",
        "between",
        "claim",
        "from",
        "have",
        "hive",
        "into",
        "keeps",
        "local",
        "more",
        "node",
        "only",
        "that",
        "their",
        "there",
        "this",
        "user",
        "using",
        "what",
        "when",
        "where",
        "which",
        "with",
        "without",
        "would"
    ]

    private static func mergedTitle(_ lhs: String, _ rhs: String) -> String {
        let left = cleanedTitle(lhs)
        let right = cleanedTitle(rhs)
        let leftLower = left.lowercased()
        let rightLower = right.lowercased()
        if leftLower == rightLower { return left }
        if leftLower.contains(rightLower) { return left }
        if rightLower.contains(leftLower) { return right }
        if left.count >= right.count {
            return left
        }
        return right
    }

    private static func cleanedTitle(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func layerRank(_ layer: MemoryNodeLayer) -> Int {
        switch layer {
        case .definingTrait:
            return 0
        case .importantTrait:
            return 1
        case .connector:
            return 2
        case .detail:
            return 3
        }
    }
}

public struct GraphSelectionModel: Hashable, Sendable {
    public var selectedID: String?
    public var firstOrderIDs: Set<String>
    public var dimmedIDs: Set<String>
    public var activeEdgeIDs: Set<String>

    public init(selectedID: String?, nodeIDs: Set<String>, edges: [GraphEdgeRecord]) {
        self.selectedID = selectedID
        guard let selectedID else {
            self.firstOrderIDs = []
            self.dimmedIDs = []
            self.activeEdgeIDs = []
            return
        }

        var neighbors = Set<String>()
        var activeEdges = Set<String>()
        for edge in edges where GraphRelationshipPolicy.isVisibleConnection(edge) {
            if edge.fromID == selectedID {
                neighbors.insert(edge.toID)
                activeEdges.insert(edge.id)
            } else if edge.toID == selectedID {
                neighbors.insert(edge.fromID)
                activeEdges.insert(edge.id)
            }
        }

        self.firstOrderIDs = neighbors
        self.activeEdgeIDs = activeEdges
        self.dimmedIDs = nodeIDs.subtracting(neighbors.union([selectedID]))
    }

    public func isFocused(nodeID: String) -> Bool {
        guard let selectedID else { return true }
        return nodeID == selectedID || firstOrderIDs.contains(nodeID)
    }
}
