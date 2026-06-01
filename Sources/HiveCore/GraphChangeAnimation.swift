import Foundation

public enum GraphChangeAnimationKind: String, Codable, CaseIterable, Sendable {
    case insertion
    case deletion
    case movement
    case combination
    case split
    case connectionInsertion
    case connectionDeletion
}

public enum GraphChangeAnimationCurve: String, Codable, CaseIterable, Sendable {
    case sine
    case spring
    case bounce

    public func eased(_ progress: Double) -> Double {
        let t = min(1, max(0, progress))
        switch self {
        case .sine:
            return 0.5 - cos(t * .pi) * 0.5
        case .spring:
            let value = 1 - exp(-6 * t) * cos(10 * t)
            return min(1.08, max(0, value))
        case .bounce:
            if t < 1 / 2.75 {
                return 7.5625 * t * t
            } else if t < 2 / 2.75 {
                let shifted = t - 1.5 / 2.75
                return 7.5625 * shifted * shifted + 0.75
            } else if t < 2.5 / 2.75 {
                let shifted = t - 2.25 / 2.75
                return 7.5625 * shifted * shifted + 0.9375
            } else {
                let shifted = t - 2.625 / 2.75
                return 7.5625 * shifted * shifted + 0.984375
            }
        }
    }
}

public struct GraphChangeAnimationEvent: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: GraphChangeAnimationKind
    public var node: GraphNodeRecord?
    public var targetNode: GraphNodeRecord?
    public var edge: GraphEdgeRecord?
    public var from: GraphSemanticCoordinate?
    public var to: GraphSemanticCoordinate?
    public var startOffset: TimeInterval
    public var duration: TimeInterval
    public var curve: GraphChangeAnimationCurve
    public var strength: Double

    public init(
        id: String,
        kind: GraphChangeAnimationKind,
        node: GraphNodeRecord? = nil,
        targetNode: GraphNodeRecord? = nil,
        edge: GraphEdgeRecord? = nil,
        from: GraphSemanticCoordinate? = nil,
        to: GraphSemanticCoordinate? = nil,
        startOffset: TimeInterval = 0,
        duration: TimeInterval = 3,
        curve: GraphChangeAnimationCurve = .sine,
        strength: Double = 1
    ) {
        self.id = id
        self.kind = kind
        self.node = node
        self.targetNode = targetNode
        self.edge = edge
        self.from = from
        self.to = to
        self.startOffset = max(0, startOffset)
        self.duration = max(0.12, duration)
        self.curve = curve
        self.strength = min(1, max(0, strength))
    }

    public var affectedNodeIDs: Set<String> {
        var ids = Set<String>()
        if let node {
            ids.insert(node.id)
        }
        if let targetNode {
            ids.insert(targetNode.id)
        }
        if let edge {
            ids.insert(edge.fromID)
            ids.insert(edge.toID)
        }
        return ids
    }

    public var affectedEdgeID: String? {
        edge?.id
    }

    public func rawProgress(elapsed: TimeInterval) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, (elapsed - startOffset) / duration))
    }

    public func easedProgress(elapsed: TimeInterval) -> Double {
        curve.eased(rawProgress(elapsed: elapsed))
    }

    public func isActive(elapsed: TimeInterval) -> Bool {
        elapsed >= startOffset && elapsed <= startOffset + duration
    }
}

public struct GraphChangeAnimationList: Identifiable, Codable, Hashable, Sendable {
    public static let playbackDuration: TimeInterval = 15

    public var id: UUID
    public var createdAt: Date
    public var events: [GraphChangeAnimationEvent]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        events: [GraphChangeAnimationEvent] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.events = events
    }

    public static var empty: GraphChangeAnimationList {
        GraphChangeAnimationList(events: [])
    }

    public var isEmpty: Bool {
        events.isEmpty
    }

    public func elapsed(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(createdAt))
    }

    public func isActive(at date: Date) -> Bool {
        !events.isEmpty && elapsed(at: date) <= Self.playbackDuration
    }

    public func event(forNodeID nodeID: String, at date: Date) -> GraphChangeAnimationEvent? {
        let elapsed = elapsed(at: date)
        return events
            .filter { $0.affectedNodeIDs.contains(nodeID) && $0.rawProgress(elapsed: elapsed) < 1 }
            .sorted { lhs, rhs in
                if lhs.startOffset == rhs.startOffset {
                    return lhs.id < rhs.id
                }
                return lhs.startOffset < rhs.startOffset
            }
            .last
    }

    public func edgeRevealMultiplier(edgeID: String, fromID: String, toID: String, at date: Date) -> Double {
        let elapsed = elapsed(at: date)
        let matching = events.filter { event in
            if event.affectedEdgeID == edgeID {
                return true
            }
            return event.kind == .insertion
                && (event.affectedNodeIDs.contains(fromID) || event.affectedNodeIDs.contains(toID))
        }
        guard let event = matching.first else { return 1 }
        switch event.kind {
        case .connectionInsertion, .insertion, .split:
            return event.easedProgress(elapsed: elapsed)
        case .connectionDeletion, .deletion, .combination:
            return 1 - event.easedProgress(elapsed: elapsed)
        case .movement:
            return 1
        }
    }

    public static func make(
        previous: HiveGraphSnapshot,
        current: HiveGraphSnapshot,
        maxEvents: Int = 90,
        now: Date = Date()
    ) -> GraphChangeAnimationList {
        let previousNodes = Dictionary(uniqueKeysWithValues: visibleAnimationNodes(previous.nodes).map { ($0.id, $0) })
        let currentNodes = Dictionary(uniqueKeysWithValues: visibleAnimationNodes(current.nodes).map { ($0.id, $0) })
        let previousIDs = Set(previousNodes.keys)
        let currentIDs = Set(currentNodes.keys)
        guard !previousIDs.isEmpty || !currentIDs.isEmpty else {
            return GraphChangeAnimationList(createdAt: now)
        }

        let insertedIDs = currentIDs.subtracting(previousIDs)
        let removedIDs = previousIDs.subtracting(currentIDs)
        let sharedIDs = previousIDs.intersection(currentIDs)
        let insertedNodes = insertedIDs.compactMap { currentNodes[$0] }
        let removedNodes = removedIDs.compactMap { previousNodes[$0] }

        var rawEvents: [GraphChangeAnimationEvent] = []
        var splitInsertedIDs = Set<String>()
        var combinedRemovedIDs = Set<String>()

        for removed in removedNodes.sorted(by: stableNodeSort) {
            let candidates = insertedNodes.filter { !splitInsertedIDs.contains($0.id) && sharesMeaningfulEvidence(removed, $0) }
            if candidates.count >= 2 {
                for inserted in candidates.prefix(4) {
                    splitInsertedIDs.insert(inserted.id)
                    rawEvents.append(GraphChangeAnimationEvent(
                        id: "split-\(removed.id)-\(inserted.id)",
                        kind: .split,
                        node: inserted,
                        targetNode: removed,
                        from: coordinate(for: removed),
                        to: coordinate(for: inserted),
                        curve: .spring,
                        strength: inserted.confidence
                    ))
                }
            }
        }

        for removed in removedNodes.sorted(by: stableNodeSort) where !combinedRemovedIDs.contains(removed.id) {
            guard let target = bestCombinationTarget(for: removed, in: Array(currentNodes.values)) else { continue }
            combinedRemovedIDs.insert(removed.id)
            rawEvents.append(GraphChangeAnimationEvent(
                id: "combine-\(removed.id)-\(target.id)",
                kind: .combination,
                node: removed,
                targetNode: target,
                from: coordinate(for: removed),
                to: coordinate(for: target),
                curve: .spring,
                strength: max(removed.confidence, target.confidence)
            ))
        }

        for node in insertedNodes.sorted(by: stableNodeSort) where !splitInsertedIDs.contains(node.id) {
            rawEvents.append(GraphChangeAnimationEvent(
                id: "insert-\(node.id)",
                kind: .insertion,
                node: node,
                from: GraphSemanticCoordinate(x: 0, y: 0),
                to: coordinate(for: node),
                curve: .bounce,
                strength: node.confidence
            ))
        }

        for node in removedNodes.sorted(by: stableNodeSort) where !combinedRemovedIDs.contains(node.id) {
            rawEvents.append(GraphChangeAnimationEvent(
                id: "delete-\(node.id)",
                kind: .deletion,
                node: node,
                from: coordinate(for: node),
                to: GraphSemanticCoordinate(x: 0, y: 0),
                curve: .sine,
                strength: node.confidence
            ))
        }

        for id in sharedIDs.sorted() {
            guard let previousNode = previousNodes[id], let currentNode = currentNodes[id] else { continue }
            let distance = hypot(currentNode.x - previousNode.x, currentNode.y - previousNode.y)
            let layerChanged = previousNode.memoryLayer != currentNode.memoryLayer
            guard distance >= 18 || layerChanged else { continue }
            rawEvents.append(GraphChangeAnimationEvent(
                id: "move-\(id)",
                kind: .movement,
                node: currentNode,
                targetNode: previousNode,
                from: coordinate(for: previousNode),
                to: coordinate(for: currentNode),
                curve: .sine,
                strength: min(1, max(currentNode.confidence, distance / 220))
            ))
        }

        let previousEdges = Dictionary(uniqueKeysWithValues: visibleAnimationEdges(previous.edges).map { ($0.id, $0) })
        let currentEdges = Dictionary(uniqueKeysWithValues: visibleAnimationEdges(current.edges).map { ($0.id, $0) })
        for id in Set(currentEdges.keys).subtracting(previousEdges.keys).sorted() {
            guard let edge = currentEdges[id], currentNodes[edge.fromID] != nil, currentNodes[edge.toID] != nil else { continue }
            rawEvents.append(GraphChangeAnimationEvent(
                id: "edge-insert-\(id)",
                kind: .connectionInsertion,
                edge: edge,
                curve: .sine,
                strength: edge.strength
            ))
        }
        for id in Set(previousEdges.keys).subtracting(currentEdges.keys).sorted() {
            guard let edge = previousEdges[id] else { continue }
            rawEvents.append(GraphChangeAnimationEvent(
                id: "edge-delete-\(id)",
                kind: .connectionDeletion,
                edge: edge,
                curve: .sine,
                strength: edge.strength
            ))
        }

        let events = scheduled(Array(rawEvents.prefix(maxEvents)))
        return GraphChangeAnimationList(createdAt: now, events: events)
    }

    private static func scheduled(_ events: [GraphChangeAnimationEvent]) -> [GraphChangeAnimationEvent] {
        guard !events.isEmpty else { return [] }
        let sorted = events.sorted { lhs, rhs in
            let lhsRank = kindRank(lhs.kind)
            let rhsRank = kindRank(rhs.kind)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
            return lhs.id < rhs.id
        }
        let baseDuration = min(2.4, max(1.1, playbackDuration * 0.16))
        let latestStart = max(0, playbackDuration - baseDuration)
        return sorted.enumerated().map { index, event in
            var scheduled = event
            let denominator = max(1, sorted.count - 1)
            scheduled.startOffset = latestStart * Double(index) / Double(denominator)
            scheduled.duration = min(baseDuration, playbackDuration - scheduled.startOffset)
            return scheduled
        }
    }

    private static func visibleAnimationNodes(_ nodes: [GraphNodeRecord]) -> [GraphNodeRecord] {
        nodes.filter { node in
            node.isUserVisibleGraphNode && isUsefulAnimationTitle(node.title)
        }
    }

    private static func visibleAnimationEdges(_ edges: [GraphEdgeRecord]) -> [GraphEdgeRecord] {
        edges.filter(GraphRelationshipPolicy.isVisibleConnection)
    }

    private static func coordinate(for node: GraphNodeRecord) -> GraphSemanticCoordinate {
        GraphSemanticCoordinate(x: node.x, y: node.y)
    }

    private static func stableNodeSort(_ lhs: GraphNodeRecord, _ rhs: GraphNodeRecord) -> Bool {
        if lhs.memoryLayer != rhs.memoryLayer {
            return layerRank(lhs.memoryLayer) < layerRank(rhs.memoryLayer)
        }
        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }
        return lhs.id < rhs.id
    }

    private static func layerRank(_ layer: MemoryNodeLayer) -> Int {
        switch layer {
        case .definingTrait: 0
        case .importantTrait: 1
        case .connector: 2
        case .detail: 3
        }
    }

    private static func kindRank(_ kind: GraphChangeAnimationKind) -> Int {
        switch kind {
        case .combination:
            return 0
        case .split:
            return 1
        case .movement:
            return 2
        case .insertion:
            return 3
        case .connectionInsertion:
            return 4
        case .connectionDeletion:
            return 5
        case .deletion:
            return 6
        }
    }

    private static func bestCombinationTarget(for removed: GraphNodeRecord, in currentNodes: [GraphNodeRecord]) -> GraphNodeRecord? {
        currentNodes
            .filter { sharesMeaningfulEvidence(removed, $0) || titleSuggestsCombination(removed.title, $0.title) }
            .sorted { lhs, rhs in
                let lhsScore = combinationScore(removed, lhs)
                let rhsScore = combinationScore(removed, rhs)
                if lhsScore == rhsScore { return lhs.id < rhs.id }
                return lhsScore > rhsScore
            }
            .first
    }

    private static func combinationScore(_ removed: GraphNodeRecord, _ target: GraphNodeRecord) -> Double {
        let sourceOverlap = Set(removed.sourceRefs).intersection(Set(target.sourceRefs)).count
        let titleScore = titleSuggestsCombination(removed.title, target.title) ? 1.0 : 0.0
        return Double(sourceOverlap) + titleScore + target.confidence
    }

    private static func sharesMeaningfulEvidence(_ lhs: GraphNodeRecord, _ rhs: GraphNodeRecord) -> Bool {
        let left = Set(lhs.sourceRefs)
        let right = Set(rhs.sourceRefs)
        return !left.isEmpty && !left.intersection(right).isEmpty
    }

    private static func titleSuggestsCombination(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalizedTitle(lhs)
        let right = normalizedTitle(rhs)
        guard left.count > 5, right.count > 5 else { return false }
        return left.contains(right) || right.contains(left)
    }

    public static func isUsefulAnimationTitle(_ title: String) -> Bool {
        let normalized = normalizedTitle(title)
        guard normalized.count > 2 else { return false }
        let generic: Set<String> = [
            "work", "personal", "background", "professional", "creative", "analytical",
            "school", "education", "finance", "hardware", "health", "family",
            "project", "projects", "tools", "tool", "workflow", "research",
            "shopping", "apps", "app", "source", "note", "memory", "topic",
            "captured memory", "feed note", "browsing trail", "saved trail"
        ]
        return !generic.contains(normalized)
    }

    private static func normalizedTitle(_ title: String) -> String {
        SourcePresentationModel.cleanTitle(title)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }
}
