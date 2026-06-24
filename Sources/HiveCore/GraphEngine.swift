import Foundation
import simd

public struct GraphFilter: Hashable, Sendable {
    public var query: String
    public var minimumConfidence: Double
    public var kinds: Set<GraphNodeKind>
    public var startDate: Date?
    public var endDate: Date?
    public var maxVisibleNodes: Int?

    public init(
        query: String = "",
        minimumConfidence: Double = 0,
        kinds: Set<GraphNodeKind> = Set(GraphNodeKind.allCases),
        startDate: Date? = nil,
        endDate: Date? = nil,
        maxVisibleNodes: Int? = nil
    ) {
        self.query = query
        self.minimumConfidence = minimumConfidence
        self.kinds = kinds
        self.startDate = startDate
        self.endDate = endDate
        self.maxVisibleNodes = maxVisibleNodes
    }
}

public struct GraphEngine: Sendable {
    public init() {}

    public func buildGraph(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        relationships: [RelationshipRecord],
        suppressedClaimIDs: Set<String> = [],
        visibility: DerivedMemoryVisibility = .allowAll
    ) -> HiveGraphSnapshot {
        var nodes: [GraphNodeRecord] = []
        let rawEvidenceSourceIDs = Self.rawEvidenceOnlySourceIDs(sources)
        let displayClaims = claims.filter { claim in
            claim.status != .retracted
                && !suppressedClaimIDs.contains(claim.id)
                && (visibility.shouldShowClaim(claim) || claim.claimType == "graph-insight")
                && claim.claimType != "user-context-consolidation"
                && !(claim.claimType == "supporting-detail" && claim.subjectEntityID != nil)
                && !Self.isRawEvidenceClaim(claim, rawEvidenceSourceIDs: rawEvidenceSourceIDs)
                && !Self.isGraphControlClaim(claim)
                && !MemoryCompiler.isRawLinkLike(claim.statement)
                && !Self.isLowInformationHoneycombTitle(claim.statement)
        }
        let highSignalEntities = entities.filter { entity in
            EntitySignalPolicy.isMeaningfulName(entity.name)
                && visibility.shouldShowEntity(entity)
                && !MemoryCompiler.isRawLinkLike(entity.name)
                && !Self.isLowInformationHoneycombTitle(entity.name)
                && (!entity.sourceRefs.contains { rawEvidenceSourceIDs.contains($0) } || Self.isPromotedUserContextEntity(entity))
        }
        let validDisplayIDs = Set(displayClaims.map(\.id)).union(highSignalEntities.map(\.id))
        let relationshipDegree = relationships.reduce(into: [String: Int]()) { counts, relationship in
            guard validDisplayIDs.contains(relationship.subjectID), validDisplayIDs.contains(relationship.objectID) else { return }
            counts[relationship.subjectID, default: 0] += 1
            counts[relationship.objectID, default: 0] += 1
        }
        let layerClassifier = MemoryNodeLayerClassifier()

        for claim in displayClaims {
            let classification = layerClassifier.classify(claim: claim, graphDegree: relationshipDegree[claim.id, default: 0])
            nodes.append(GraphNodeRecord(
                id: claim.id,
                title: claim.statement,
                kind: claim.claimType == "graph-insight" ? .insight : .claim,
                confidence: claim.confidence,
                sourceRefs: claim.sourceRefs,
                timestamp: claim.createdAt,
                memoryLayer: classification.layer,
                semanticColorKey: classification.semanticColorKey,
                memoryLayerOverrideSource: classification.overrideSource
            ))
        }

        for entity in highSignalEntities {
            let classification = layerClassifier.classify(entity: entity, graphDegree: relationshipDegree[entity.id, default: 0])
            nodes.append(GraphNodeRecord(
                id: entity.id,
                title: entity.name,
                kind: nodeKind(for: entity),
                confidence: entity.confidence,
                sourceRefs: entity.sourceRefs,
                timestamp: entity.createdAt,
                memoryLayer: classification.layer,
                semanticColorKey: classification.semanticColorKey,
                memoryLayerOverrideSource: classification.overrideSource
            ))
        }

        var edges: [GraphEdgeRecord] = []
        let validNodeIDs = Set(nodes.map(\.id))

        for relationship in relationships where validNodeIDs.contains(relationship.subjectID) && validNodeIDs.contains(relationship.objectID) && relationship.subjectID != relationship.objectID {
            edges.append(GraphEdgeRecord(
                id: relationship.id,
                fromID: relationship.subjectID,
                toID: relationship.objectID,
                predicate: relationship.predicate,
                strength: relationship.strength,
                confidence: relationship.confidence,
                evidenceCount: relationship.evidenceCount,
                sourceRefs: relationship.sourceSpanRefs,
                explanation: relationshipExplanation(relationship)
            ))
        }

        return HiveGraphSnapshot(nodes: positioned(nodes: nodes, edges: edges), edges: edges)
    }

    public func deriveRelationships(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        existing: [RelationshipRecord],
        visibility: DerivedMemoryVisibility = .allowAll,
        learningSettings: HiveLearningSettings = .defaultValue
    ) -> [RelationshipRecord] {
        var emittedKeys = Set(existing.map { "\($0.subjectID)|\($0.predicate.rawValue)|\($0.objectID)" })
        var relationships: [RelationshipRecord] = []
        let analyzer = MarkovGraphAnalyzer()
        let rawEvidenceSourceIDs = Self.rawEvidenceOnlySourceIDs(sources)
        let highSignalEntities = entities.filter { entity in
            EntitySignalPolicy.isMeaningfulName(entity.name)
                && visibility.shouldShowEntity(entity)
                && !MemoryCompiler.isRawLinkLike(entity.name)
                && (!entity.sourceRefs.contains { rawEvidenceSourceIDs.contains($0) } || Self.isPromotedUserContextEntity(entity))
        }
        let highSignalEntityIDs = Set(highSignalEntities.map(\.id))

        let relationshipClaims = claims.filter {
            (visibility.shouldShowClaim($0) || $0.claimType == "graph-insight")
                && $0.claimType != "supporting-detail"
                && $0.claimType != "user-context-consolidation"
                && !Self.isGraphControlClaim($0)
        }

        for claim in relationshipClaims where claim.status != .retracted && !Self.isRawEvidenceClaim(claim, rawEvidenceSourceIDs: rawEvidenceSourceIDs) {
            guard let subjectID = claim.subjectEntityID,
                  highSignalEntityIDs.contains(subjectID) else { continue }
            let key = "\(subjectID)|\(RelationshipPredicate.supports.rawValue)|\(claim.id)"
            guard !emittedKeys.contains(key) else { continue }
            emittedKeys.insert(key)
            relationships.append(RelationshipRecord(
                subjectID: subjectID,
                predicate: .supports,
                objectID: claim.id,
                strength: learningSettings.adjustedRelationshipStrength(min(1, max(0.45, claim.confidence))),
                confidence: learningSettings.adjustedRelationshipConfidence(claim.confidence),
                evidenceCount: max(1, claim.sourceRefs.count),
                sourceSpanRefs: claim.sourceSpanRefs.isEmpty ? claim.sourceRefs : claim.sourceSpanRefs
            ))
        }

        for claim in relationshipClaims where claim.status != .retracted {
            guard !Self.isRawEvidenceClaim(claim, rawEvidenceSourceIDs: rawEvidenceSourceIDs),
                  !MemoryCompiler.isRawLinkLike(claim.statement) else { continue }
            let claimTokens = tokens(in: claim.statement)
            for entity in highSignalEntities where !claim.sourceRefs.isDisjoint(with: entity.sourceRefs) {
                let entityTokens = tokens(in: entity.name)
                let overlap = claimTokens.intersection(entityTokens)
                guard overlap.count >= learningSettings.minimumTokenOverlapForConnection else { continue }
                let key = "\(entity.id)|\(RelationshipPredicate.supports.rawValue)|\(claim.id)"
                guard !emittedKeys.contains(key) else { continue }
                emittedKeys.insert(key)
                let overlapWeight = 0.12 + learningSettings.connectionAggression * 0.08
                let strength = learningSettings.adjustedRelationshipStrength(0.26 + Double(overlap.count) * overlapWeight)
                relationships.append(RelationshipRecord(
                    subjectID: entity.id,
                    predicate: .supports,
                    objectID: claim.id,
                    strength: strength,
                    confidence: learningSettings.adjustedRelationshipConfidence(min(claim.confidence, entity.confidence + 0.2)),
                    evidenceCount: overlap.count,
                    sourceSpanRefs: claim.sourceSpanRefs
                ))
            }
        }

        let analysis = analyzer.analyze(sources: sources, claims: relationshipClaims, entities: highSignalEntities)
        for transition in analysis.transitions where transition.probability >= learningSettings.markovTransitionMinimumProbability {
            guard transition.fromID != transition.toID else { continue }
            let key = "\(transition.fromID)|\(RelationshipPredicate.markovTransition.rawValue)|\(transition.toID)"
            guard !emittedKeys.contains(key) else { continue }
            emittedKeys.insert(key)
            relationships.append(RelationshipRecord(
                subjectID: transition.fromID,
                predicate: .markovTransition,
                objectID: transition.toID,
                strength: learningSettings.adjustedRelationshipStrength(min(1, max(0.12, transition.probability))),
                confidence: min(0.92, learningSettings.adjustedRelationshipConfidence(max(0.35, transition.probability + 0.25))),
                evidenceCount: transition.evidenceCount,
                sourceSpanRefs: transition.sourceRefs
            ))
        }

        for loop in analysis.loops.prefix(learningSettings.maximumMarkovLoopCount) {
            guard let firstNodeID = loop.nodeIDs.first else { continue }
            let pairs = zip(loop.nodeIDs, loop.nodeIDs.dropFirst() + [firstNodeID])
            for (fromID, toID) in pairs {
                guard fromID != toID else { continue }
                let key = "\(fromID)|\(RelationshipPredicate.markovLoop.rawValue)|\(toID)"
                guard !emittedKeys.contains(key) else { continue }
                emittedKeys.insert(key)
                relationships.append(RelationshipRecord(
                    subjectID: fromID,
                    predicate: .markovLoop,
                    objectID: toID,
                    strength: learningSettings.adjustedRelationshipStrength(min(1, max(0.25, loop.probabilityScore))),
                    confidence: min(0.9, learningSettings.adjustedRelationshipConfidence(loop.probabilityScore + 0.25)),
                    evidenceCount: loop.nodeIDs.count,
                    sourceSpanRefs: loop.sourceRefs
                ))
            }
        }

        for path in analysis.hamiltonianPaths.prefix(learningSettings.maximumHamiltonianPathCount) {
            for (fromID, toID) in zip(path.nodeIDs, path.nodeIDs.dropFirst()) {
                guard fromID != toID else { continue }
                let key = "\(fromID)|\(RelationshipPredicate.hamiltonianPath.rawValue)|\(toID)"
                guard !emittedKeys.contains(key) else { continue }
                emittedKeys.insert(key)
                relationships.append(RelationshipRecord(
                    subjectID: fromID,
                    predicate: .hamiltonianPath,
                    objectID: toID,
                    strength: learningSettings.adjustedRelationshipStrength(min(1, max(0.2, path.probabilityScore))),
                    confidence: min(0.88, learningSettings.adjustedRelationshipConfidence(path.probabilityScore + (path.exact ? 0.28 : 0.16))),
                    evidenceCount: path.nodeIDs.count,
                    sourceSpanRefs: path.sourceRefs
                ))
            }
        }

        return relationships
    }

    private static func rawEvidenceOnlySourceIDs(_ sources: [SourceRecord]) -> Set<String> {
        Set(sources.filter { source in
            source.kind == .browserHistory
                || source.kind == .browserBookmark
                || source.status == .needsReview
                || source.deletionState == .fullForgotten
        }.map(\.id))
    }

    private static func isRawEvidenceClaim(_ claim: ClaimRecord, rawEvidenceSourceIDs: Set<String>) -> Bool {
        claim.claimType == "browser-observation"
            || claim.claimType == "browser-signal"
            || claim.claimType == "browser-session-intent"
            || claim.sourceRefs.contains { rawEvidenceSourceIDs.contains($0) }
    }

    private static func isGraphControlClaim(_ claim: ClaimRecord) -> Bool {
        let graphControlTypes: Set<String> = [
            "ai-memory-seed-question",
            "ai-memory-seed-refused",
            "ai-memory-seed-unresolved"
        ]
        if graphControlTypes.contains(claim.claimType) {
            return true
        }
        let lower = claim.statement
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return lower.hasPrefix("should ")
            || lower.hasPrefix("which ")
            || lower.hasPrefix("do not ")
            || lower.hasPrefix("mark inferred ")
            || lower.hasPrefix("refused inference:")
            || lower.hasPrefix("hive should ")
    }

    private static func isPromotedUserContextEntity(_ entity: EntityRecord) -> Bool {
        entity.entityType == "user-context" && entity.confidence >= 0.9
    }

    private static func isLowInformationHoneycombTitle(_ title: String) -> Bool {
        MemoryQualityPolicy.isLowInformationStandaloneTitle(SourcePresentationModel.cleanTitle(title))
    }

    private func nodeKind(for entity: EntityRecord) -> GraphNodeKind {
        switch entity.entityType.lowercased() {
        case "project":
            return .project
        case "event":
            return .event
        case "task":
            return .task
        case "habit":
            return .habit
        case "topic":
            return .topic
        default:
            return .entity
        }
    }

    public func filter(_ graph: HiveGraphSnapshot, using filter: GraphFilter) -> HiveGraphSnapshot {
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowedNodes = graph.nodes.filter { node in
            node.confidence >= filter.minimumConfidence
                && filter.kinds.contains(node.kind)
                && isWithinDateBounds(node.timestamp, start: filter.startDate, end: filter.endDate)
        }
        let allowedIDs = Set(allowedNodes.map(\.id))
        let nodes: [GraphNodeRecord]
        let pinnedIDs: Set<String>
        if query.isEmpty {
            nodes = allowedNodes
            pinnedIDs = []
        } else {
            let matchedIDs = Set(allowedNodes.filter { $0.title.lowercased().contains(query) }.map(\.id))
            let expandedIDs = graph.edges.reduce(into: matchedIDs) { ids, edge in
                guard allowedIDs.contains(edge.fromID), allowedIDs.contains(edge.toID) else { return }
                if matchedIDs.contains(edge.fromID) {
                    ids.insert(edge.toID)
                }
                if matchedIDs.contains(edge.toID) {
                    ids.insert(edge.fromID)
                }
            }
            nodes = allowedNodes.filter { expandedIDs.contains($0.id) }
            pinnedIDs = matchedIDs
        }
        let limitedNodes = limitVisibleNodes(nodes, edges: graph.edges, maxVisibleNodes: filter.maxVisibleNodes, pinnedIDs: pinnedIDs)
        let ids = Set(limitedNodes.map(\.id))
        let edges = graph.edges.filter { ids.contains($0.fromID) && ids.contains($0.toID) }
        return HiveGraphSnapshot(nodes: positioned(nodes: limitedNodes, edges: edges), edges: edges)
    }

    public func topicWeb(
        _ graph: HiveGraphSnapshot,
        seed: String,
        minimumConfidence: Double = 0,
        kinds: Set<GraphNodeKind> = Set(GraphNodeKind.allCases),
        startDate: Date? = nil,
        endDate: Date? = nil,
        depth: Int = 2,
        maxVisibleNodes: Int? = nil
    ) -> HiveGraphSnapshot {
        let normalizedSeed = seed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedSeed.isEmpty else {
            return filter(
                graph,
                using: GraphFilter(
                    minimumConfidence: minimumConfidence,
                    kinds: kinds,
                    startDate: startDate,
                    endDate: endDate,
                    maxVisibleNodes: maxVisibleNodes
                )
            )
        }
        let seedTokens = tokens(in: normalizedSeed)
        let allowedNodes = graph.nodes.filter {
            $0.confidence >= minimumConfidence
                && kinds.contains($0.kind)
                && isWithinDateBounds($0.timestamp, start: startDate, end: endDate)
        }
        let allowedIDs = Set(allowedNodes.map(\.id))

        var included = Set(allowedNodes.filter { node in
            let lower = node.title.lowercased()
            return lower.contains(normalizedSeed) || !tokens(in: lower).intersection(seedTokens).isEmpty
        }.map(\.id))

        for edge in graph.edges where allowedIDs.contains(edge.fromID) && allowedIDs.contains(edge.toID) {
            let edgeText = "\(edge.predicate.rawValue) \(edge.explanation)".lowercased()
            if edgeText.contains(normalizedSeed) || !tokens(in: edgeText).intersection(seedTokens).isEmpty {
                included.insert(edge.fromID)
                included.insert(edge.toID)
            }
        }

        guard !included.isEmpty else {
            return filter(
                graph,
                using: GraphFilter(
                    query: seed,
                    minimumConfidence: minimumConfidence,
                    kinds: kinds,
                    startDate: startDate,
                    endDate: endDate,
                    maxVisibleNodes: maxVisibleNodes
                )
            )
        }

        let adjacency = graph.edges.reduce(into: [String: Set<String>]()) { result, edge in
            guard allowedIDs.contains(edge.fromID), allowedIDs.contains(edge.toID) else { return }
            result[edge.fromID, default: []].insert(edge.toID)
            result[edge.toID, default: []].insert(edge.fromID)
        }

        var frontier = included
        for _ in 0..<max(0, min(depth, 3)) {
            let next = Set(frontier.flatMap { adjacency[$0] ?? [] }).subtracting(included)
            guard !next.isEmpty else { break }
            included.formUnion(next)
            frontier = next
        }

        let nodes = allowedNodes.filter { included.contains($0.id) }
        let limitedNodes = limitVisibleNodes(nodes, edges: graph.edges, maxVisibleNodes: maxVisibleNodes, pinnedIDs: included)
        let ids = Set(limitedNodes.map(\.id))
        let edges = graph.edges.filter { ids.contains($0.fromID) && ids.contains($0.toID) }
        return HiveGraphSnapshot(nodes: positioned(nodes: limitedNodes, edges: edges), edges: edges)
    }

    public func positioned(nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) -> [GraphNodeRecord] {
        guard !nodes.isEmpty else { return [] }
        if nodes.count > 260 {
            return fastPositioned(nodes: nodes, edges: edges)
        }
        let coordinateClassifier = GraphCoordinateClassifier.current()
        let sortedNodes = nodes.sorted {
            let left = memoryLayerPriority($0.memoryLayer)
            let right = memoryLayerPriority($1.memoryLayer)
            if left != right { return left < right }
            return $0.id < $1.id
        }
        var positions = Dictionary(uniqueKeysWithValues: sortedNodes.enumerated().map { index, node in
            let coordinate = coordinateClassifier.coordinate(for: node, index: index, total: sortedNodes.count)
            return (node.id, SIMD2<Double>(coordinate.x, coordinate.y))
        })
        let validIDs = Set(nodes.map(\.id))
        let layoutEdges = edges.filter { validIDs.contains($0.fromID) && validIDs.contains($0.toID) }
        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        guard !layoutEdges.isEmpty else {
            return nodes.map { node in
                var updated = node
                let point = clampedGraphPosition(positions[node.id] ?? .zero)
                updated.x = point.x
                updated.y = point.y
                return updated
            }
        }

        let iterations = min(180, max(48, nodes.count * 10))
        for iteration in 0..<iterations {
            var forces = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, SIMD2<Double>.zero) })
            let cooling = 1.0 - Double(iteration) / Double(iterations)

            for i in 0..<sortedNodes.count {
                for j in (i + 1)..<sortedNodes.count {
                    let a = sortedNodes[i]
                    let b = sortedNodes[j]
                    guard let pa = positions[a.id], let pb = positions[b.id] else { continue }
                    var delta = pa - pb
                    let distance = max(24, length(delta))
                    if distance == 0 {
                        delta = SIMD2<Double>(1, 0)
                    }
                    let direction = delta / distance
                    let repulsion = nodeRepulsion(a, b) / (distance * distance)
                    forces[a.id, default: .zero] += direction * repulsion
                    forces[b.id, default: .zero] -= direction * repulsion
                }
            }

            for edge in layoutEdges {
                guard let from = positions[edge.fromID],
                      let to = positions[edge.toID],
                      let fromNode = nodeByID[edge.fromID],
                      let toNode = nodeByID[edge.toID] else { continue }
                let delta = to - from
                let distance = max(1, length(delta))
                let direction = delta / distance
                let desired = desiredDistance(fromNode, toNode, edge: edge)
                let spring = (distance - desired) * edgeSpring(fromNode, toNode, edge: edge)
                forces[edge.fromID, default: .zero] += direction * spring
                forces[edge.toID, default: .zero] -= direction * spring
            }

            for node in sortedNodes {
                let radial = positions[node.id, default: .zero]
                let anchorCoordinate = coordinateClassifier.coordinate(for: node)
                let anchor = SIMD2<Double>(anchorCoordinate.x, anchorCoordinate.y)
                let anchorForce = (anchor - radial) * 0.014
                let radialForce: SIMD2<Double>
                switch node.memoryLayer {
                case .definingTrait:
                    let distance = max(1, length(radial))
                    radialForce = radial / distance * 0.34
                case .importantTrait:
                    radialForce = radial * -0.0016
                case .connector, .detail:
                    radialForce = radial * -0.0038
                }
                let force = forces[node.id, default: .zero] + radialForce + anchorForce
                let limited = clamp(force, maxLength: 16 * cooling)
                positions[node.id, default: .zero] = clampedGraphPosition(positions[node.id, default: .zero] + limited)
            }
        }

        return nodes.map { node in
            var updated = node
            let point = clampedGraphPosition(positions[node.id] ?? .zero)
            updated.x = point.x
            updated.y = point.y
            return updated
        }
    }

    private func memoryLayerPriority(_ layer: MemoryNodeLayer) -> Int {
        switch layer {
        case .definingTrait: 0
        case .importantTrait: 1
        case .connector: 2
        case .detail: 3
        }
    }

    private func nodeRepulsion(_ a: GraphNodeRecord, _ b: GraphNodeRecord) -> Double {
        switch (a.memoryLayer, b.memoryLayer) {
        case (.definingTrait, .definingTrait):
            return 34_000
        case (.importantTrait, .importantTrait):
            return 20_000
        case (.definingTrait, .importantTrait), (.importantTrait, .definingTrait):
            return 8_500
        case (.definingTrait, _), (_, .definingTrait):
            return 4_800
        case (.importantTrait, _), (_, .importantTrait):
            return 4_200
        case (.connector, .connector):
            return 1_900
        case (.detail, .detail):
            return 850
        default:
            return 1_250
        }
    }

    private func desiredDistance(_ from: GraphNodeRecord, _ to: GraphNodeRecord, edge: GraphEdgeRecord) -> Double {
        let base: Double
        switch (from.memoryLayer, to.memoryLayer) {
        case (.definingTrait, .importantTrait), (.importantTrait, .definingTrait):
            base = 118
        case (.importantTrait, .connector), (.connector, .importantTrait):
            base = 92
        case (.importantTrait, .detail), (.detail, .importantTrait):
            base = 104
        case (.definingTrait, .connector), (.connector, .definingTrait):
            base = 150
        case (.definingTrait, .detail), (.detail, .definingTrait):
            base = 172
        case (.connector, .detail), (.detail, .connector):
            base = 68
        default:
            base = 132
        }
        return max(42, base - edge.strength * 34)
    }

    private func edgeSpring(_ from: GraphNodeRecord, _ to: GraphNodeRecord, edge: GraphEdgeRecord) -> Double {
        let layerBoost: Double
        if from.memoryLayer == .importantTrait && to.memoryLayer == .definingTrait
            || from.memoryLayer == .definingTrait && to.memoryLayer == .importantTrait {
            layerBoost = 0.055
        } else if from.memoryLayer == .detail || to.memoryLayer == .detail {
            layerBoost = 0.024
        } else {
            layerBoost = 0.038
        }
        return layerBoost + edge.strength * 0.048
    }

    private func clampedGraphPosition(_ point: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2<Double>(
            min(GraphSemanticAxes.horizontalExtent, max(-GraphSemanticAxes.horizontalExtent, point.x)),
            min(GraphSemanticAxes.verticalExtent, max(-GraphSemanticAxes.verticalExtent, point.y))
        )
    }

    private func fastPositioned(nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) -> [GraphNodeRecord] {
        let coordinateClassifier = GraphCoordinateClassifier.current()
        let validIDs = Set(nodes.map(\.id))
        let layoutEdges = edges.filter { validIDs.contains($0.fromID) && validIDs.contains($0.toID) }
        let degree = layoutEdges.reduce(into: [String: Int]()) { counts, edge in
            counts[edge.fromID, default: 0] += 1
            counts[edge.toID, default: 0] += 1
        }
        let sortedNodes = nodes.sorted { lhs, rhs in
            let leftDegree = degree[lhs.id, default: 0]
            let rightDegree = degree[rhs.id, default: 0]
            if leftDegree != rightDegree { return leftDegree > rightDegree }
            let leftPriority = nodeKindPriority(lhs.kind)
            let rightPriority = nodeKindPriority(rhs.kind)
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            return lhs.id < rhs.id
        }
        var positions = Dictionary(uniqueKeysWithValues: sortedNodes.enumerated().map { index, node in
            let radius = 28 * sqrt(Double(index + 1))
            let angle = Double(index) * Double.pi * (3 - sqrt(5))
            let coordinate = coordinateClassifier.coordinate(for: node, index: index, total: sortedNodes.count)
            let anchor = SIMD2<Double>(coordinate.x, coordinate.y)
            return (
                node.id,
                SIMD2<Double>(
                    anchor.x + cos(angle) * radius * 0.52,
                    anchor.y + sin(angle) * radius * 0.52
                )
            )
        })
        let iterations = min(64, max(18, layoutEdges.count / 45))
        for iteration in 0..<iterations {
            var forces = Dictionary(uniqueKeysWithValues: sortedNodes.map { ($0.id, SIMD2<Double>.zero) })
            let cooling = 1.0 - Double(iteration) / Double(iterations)
            for edge in layoutEdges {
                guard let from = positions[edge.fromID], let to = positions[edge.toID] else { continue }
                let delta = to - from
                let distance = max(1, length(delta))
                let direction = delta / distance
                let desired = max(42, 145 - edge.strength * 82)
                let spring = (distance - desired) * (0.01 + edge.strength * 0.045)
                forces[edge.fromID, default: .zero] += direction * spring
                forces[edge.toID, default: .zero] -= direction * spring
            }
            for node in sortedNodes {
                let coordinate = coordinateClassifier.coordinate(for: node)
                let anchor = SIMD2<Double>(coordinate.x, coordinate.y)
                let anchorForce = (anchor - positions[node.id, default: .zero]) * 0.012
                let radial = positions[node.id, default: .zero] * -0.002
                let force = forces[node.id, default: .zero] + radial + anchorForce
                positions[node.id, default: .zero] = clampedGraphPosition(positions[node.id, default: .zero] + clamp(force, maxLength: 9 * cooling))
            }
        }
        return nodes.map { node in
            var updated = node
            let point = clampedGraphPosition(positions[node.id] ?? .zero)
            updated.x = point.x
            updated.y = point.y
            return updated
        }
    }

    private func tokens(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }
        )
    }

    private func relationshipExplanation(_ relationship: RelationshipRecord) -> String {
        switch relationship.predicate {
        case .markovTransition:
            return "Related through repeated local evidence."
        case .markovLoop:
            return "Part of a repeated local pattern."
        case .hamiltonianPath:
            return "Part of a connected local path."
        case .supports:
            return "Shared evidence links these items."
        case .mentions:
            return "The source mentions this item."
        case .sourceOf:
            return "Backed by this source."
        case .contradicts:
            return "These items disagree."
        case .concludes:
            return "Supported by connected evidence."
        default:
            return "Related by local evidence."
        }
    }

    private func isWithinDateBounds(_ timestamp: Date?, start: Date?, end: Date?) -> Bool {
        guard start != nil || end != nil else { return true }
        guard let timestamp else { return false }
        if let start, timestamp < start { return false }
        if let end, timestamp > end { return false }
        return true
    }

    private func clamp(_ vector: SIMD2<Double>, maxLength: Double) -> SIMD2<Double> {
        let current = length(vector)
        guard current > maxLength, current > 0 else { return vector }
        return vector / current * maxLength
    }

    private func limitVisibleNodes(
        _ nodes: [GraphNodeRecord],
        edges: [GraphEdgeRecord],
        maxVisibleNodes: Int?,
        pinnedIDs: Set<String>
    ) -> [GraphNodeRecord] {
        guard let maxVisibleNodes, nodes.count > maxVisibleNodes else { return nodes }
        let availableIDs = Set(nodes.map(\.id))
        let degree = edges.reduce(into: [String: Int]()) { counts, edge in
            guard availableIDs.contains(edge.fromID), availableIDs.contains(edge.toID) else { return }
            counts[edge.fromID, default: 0] += 1
            counts[edge.toID, default: 0] += 1
        }
        let ranked = nodes.sorted { lhs, rhs in
            let leftPinned = pinnedIDs.contains(lhs.id)
            let rightPinned = pinnedIDs.contains(rhs.id)
            if leftPinned != rightPinned { return leftPinned }
            let leftDegree = degree[lhs.id, default: 0]
            let rightDegree = degree[rhs.id, default: 0]
            if leftDegree != rightDegree { return leftDegree > rightDegree }
            if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
            let leftPriority = nodeKindPriority(lhs.kind)
            let rightPriority = nodeKindPriority(rhs.kind)
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return Array(ranked.prefix(maxVisibleNodes))
    }

    private func nodeKindPriority(_ kind: GraphNodeKind) -> Int {
        switch kind {
        case .insight: 0
        case .project: 1
        case .topic, .entity: 2
        case .claim: 3
        case .source: 4
        case .event, .task, .habit: 5
        }
    }

    private func kindBias(_ kind: GraphNodeKind) -> SIMD2<Double> {
        switch kind {
        case .project:
            return SIMD2<Double>(-90, -40)
        case .topic, .entity:
            return SIMD2<Double>(80, -70)
        case .claim:
            return SIMD2<Double>(0, 80)
        case .source:
            return SIMD2<Double>(-120, 95)
        case .insight:
            return SIMD2<Double>(115, 95)
        case .event:
            return SIMD2<Double>(145, 10)
        case .task, .habit:
            return SIMD2<Double>(-35, 135)
        }
    }
}

private extension Array where Element == String {
    func isDisjoint(with other: [String]) -> Bool {
        Set(self).isDisjoint(with: Set(other))
    }
}
