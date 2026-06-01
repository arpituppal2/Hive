import Foundation

public struct MemoryNodeLayerClassification: Hashable, Sendable {
    public var layer: MemoryNodeLayer
    public var semanticColorKey: String?
    public var overrideSource: String?

    public init(layer: MemoryNodeLayer, semanticColorKey: String? = nil, overrideSource: String? = nil) {
        self.layer = layer
        self.semanticColorKey = semanticColorKey
        self.overrideSource = overrideSource
    }
}

public struct MemoryNodeLayerClassifier: Sendable {
    public init() {}

    public func classify(claim: ClaimRecord, graphDegree: Int = 0) -> MemoryNodeLayerClassification {
        let override = explicitLayer(in: claim.uncertaintyReason)
        let text = "\(claim.statement) \(claim.uncertaintyReason)"
        let inferred = override ?? inferredLayer(text: text, kind: .claim, confidence: claim.confidence, graphDegree: graphDegree)
        return MemoryNodeLayerClassification(
            layer: inferred,
            semanticColorKey: semanticColorKey(for: text, layer: inferred),
            overrideSource: override == nil ? nil : "claim.uncertaintyReason"
        )
    }

    public func classify(entity: EntityRecord, graphDegree: Int = 0) -> MemoryNodeLayerClassification {
        let text = "\(entity.name) \(entity.entityType) \(entity.aliases.joined(separator: " "))"
        let inferred = inferredLayer(text: text, kind: graphKind(for: entity), confidence: entity.confidence, graphDegree: graphDegree)
        return MemoryNodeLayerClassification(
            layer: inferred,
            semanticColorKey: semanticColorKey(for: text, layer: inferred)
        )
    }

    public func classify(node: GraphNodeRecord, graphDegree: Int = 0) -> MemoryNodeLayerClassification {
        MemoryNodeLayerClassification(
            layer: inferredLayer(text: node.title, kind: node.kind, confidence: node.confidence, graphDegree: graphDegree),
            semanticColorKey: semanticColorKey(for: node.title, layer: node.memoryLayer)
        )
    }

    private func explicitLayer(in text: String) -> MemoryNodeLayer? {
        let lower = text.lowercased()
        for layer in MemoryNodeLayer.allCases {
            let raw = layer.rawValue.lowercased()
            if lower.contains("memory layer: \(raw)") || lower.contains("layer:\(raw)") || lower.contains("layer: \(raw)") {
                return layer
            }
        }
        return nil
    }

    private func inferredLayer(text: String, kind: GraphNodeKind, confidence: Double, graphDegree: Int) -> MemoryNodeLayer {
        let lower = text.lowercased()
        if containsAny(lower, definingSignals) {
            return .definingTrait
        }
        if containsAny(lower, importantSignals) || kind == .project || kind == .insight {
            return promote(.importantTrait, confidence: confidence, graphDegree: graphDegree)
        }
        if containsAny(lower, detailSignals) {
            return promote(.detail, confidence: confidence, graphDegree: graphDegree)
        }
        if containsAny(lower, connectorSignals) || kind == .topic || kind == .entity || kind == .event || kind == .task || kind == .habit {
            return promote(.connector, confidence: confidence, graphDegree: graphDegree)
        }
        return promote(kind == .claim ? .detail : .connector, confidence: confidence, graphDegree: graphDegree)
    }

    private func promote(_ base: MemoryNodeLayer, confidence: Double, graphDegree: Int) -> MemoryNodeLayer {
        guard confidence >= 0.94, graphDegree >= 5 else { return base }
        switch base {
        case .detail:
            return .connector
        case .connector:
            return graphDegree >= 8 ? .importantTrait : .connector
        case .importantTrait, .definingTrait:
            return base
        }
    }

    private func graphKind(for entity: EntityRecord) -> GraphNodeKind {
        switch entity.entityType.lowercased() {
        case "project": return .project
        case "event": return .event
        case "task": return .task
        case "habit": return .habit
        case "topic": return .topic
        default: return .entity
        }
    }

    private func semanticColorKey(for text: String, layer: MemoryNodeLayer) -> String? {
        let lower = text.lowercased()
        if containsAny(lower, ["ucla", "mathematics", "student", "education", "school"]) { return "education" }
        if containsAny(lower, ["iq", "smart", "debate", "argument", "cognitive"]) { return "cognitive" }
        if containsAny(lower, ["male", "height", "6'", "6 ft", "indian", "body", "health"]) { return "body-identity" }
        if containsAny(lower, ["help", "volunteer", "eagle scout", "others", "service"]) { return "service" }
        if containsAny(lower, ["cabin", "hive", "locus", "local-computer", "ultimate-tracker", "project"]) { return "projects" }
        if containsAny(lower, ["money", "finance", "grant", "hardware", "macbook", "gpu"]) { return "constraints" }
        return layer == .definingTrait ? WikiPageRecord.slugify(text) : nil
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private let definingSignals = [
        "iq", "certified iq", "male", "female", "indian", "6'3", "6 ft 3", "6 foot 3",
        "height", "defining trait", "core value", "personality", "debate", "helps others",
        "underlying characteristic"
    ]

    private let importantSignals = [
        "ucla", "mathematics", "student at", "majoring", "bs/ma", "bsma", "founder",
        "co-directed", "active software developer", "zero money", "100% local", "major project",
        "eagle scout", "a6000", "m4 macbook", "startup", "career", "consulting"
    ]

    private let connectorSignals = [
        "currently enrolled", "class", "course", "uses", "using", "workflow", "browser automation",
        "tools", "templates", "task", "route", "part", "plan", "connected", "project"
    ]

    private let detailSignals = [
        "prefers", "preference", "latex", "format", "single-dollar", "responses", "wording",
        "button", "font", "color", "specific", "exactly", "does not want", "dislikes"
    ]
}
