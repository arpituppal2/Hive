import Foundation
import simd

public enum SemanticZoomLevel: String, Codable, CaseIterable, Sendable {
    case constellation
    case cluster
    case node

    public static func level(for scale: Double) -> SemanticZoomLevel {
        switch scale {
        case ..<0.72:
            return .constellation
        case 0.72..<1.55:
            return .cluster
        default:
            return .node
        }
    }

    public var showsDetailNodes: Bool {
        self == .node
    }

    public var showsClusterHull: Bool {
        self != .node
    }
}

public struct LivingGraphMotionPolicy: Codable, Hashable, Sendable {
    public var allowsIdleBreathing: Bool
    public var breathingAmplitude: Double
    public var relaxationStrength: Double
    public var reduceMotion: Bool
    public var resourcePressureReduced: Bool

    public init(
        allowsIdleBreathing: Bool = true,
        breathingAmplitude: Double = 0.018,
        relaxationStrength: Double = 0.22,
        reduceMotion: Bool = false,
        resourcePressureReduced: Bool = false
    ) {
        self.allowsIdleBreathing = allowsIdleBreathing
        self.breathingAmplitude = breathingAmplitude
        self.relaxationStrength = relaxationStrength
        self.reduceMotion = reduceMotion
        self.resourcePressureReduced = resourcePressureReduced
    }

    public var effectiveBreathingAmplitude: Double {
        guard allowsIdleBreathing, !reduceMotion, !resourcePressureReduced else { return 0 }
        return breathingAmplitude
    }
}

public struct GraphClusterRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var nodeIDs: [String]
    public var centerX: Double
    public var centerY: Double
    public var radius: Double
    public var color: SIMD4<Float>
    public var relevance: Double

    public init(
        id: String,
        title: String,
        nodeIDs: [String],
        centerX: Double,
        centerY: Double,
        radius: Double,
        color: SIMD4<Float>,
        relevance: Double
    ) {
        self.id = id
        self.title = title
        self.nodeIDs = nodeIDs
        self.centerX = centerX
        self.centerY = centerY
        self.radius = radius
        self.color = color
        self.relevance = relevance
    }
}

public struct GraphRenderNode: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var layer: MemoryNodeLayer
    public var x: Double
    public var y: Double
    public var radius: Double
    public var color: SIMD4<Float>
    public var alpha: Float
    public var labelVisible: Bool
    public var clusterID: String
}

public struct GraphRenderEdge: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var fromID: String
    public var toID: String
    public var fromX: Double
    public var fromY: Double
    public var toX: Double
    public var toY: Double
    public var alpha: Float
    public var strength: Float
    public var color: SIMD4<Float>
}

public struct GraphMorphState: Codable, Hashable, Sendable {
    public var sourceNodeID: String?
    public var targetWikiPageID: String?
    public var progress: Double

    public init(sourceNodeID: String? = nil, targetWikiPageID: String? = nil, progress: Double = 0) {
        self.sourceNodeID = sourceNodeID
        self.targetWikiPageID = targetWikiPageID
        self.progress = progress
    }
}

public struct GraphRenderSnapshot: Codable, Hashable, Sendable {
    public var zoomLevel: SemanticZoomLevel
    public var nodes: [GraphRenderNode]
    public var edges: [GraphRenderEdge]
    public var clusters: [GraphClusterRecord]
    public var morphState: GraphMorphState

    public init(
        zoomLevel: SemanticZoomLevel,
        nodes: [GraphRenderNode],
        edges: [GraphRenderEdge],
        clusters: [GraphClusterRecord],
        morphState: GraphMorphState = GraphMorphState()
    ) {
        self.zoomLevel = zoomLevel
        self.nodes = nodes
        self.edges = edges
        self.clusters = clusters
        self.morphState = morphState
    }

    public static func build(
        graph: HiveGraphSnapshot,
        scale: Double,
        selectedNodeID: String? = nil,
        hoveredNodeID: String? = nil,
        focusedNodeIDs: Set<String> = [],
        motionPolicy: LivingGraphMotionPolicy = LivingGraphMotionPolicy(),
        time: TimeInterval = 0
    ) -> GraphRenderSnapshot {
        let zoomLevel = SemanticZoomLevel.level(for: scale)
        let clusters = makeClusters(graph: graph, scale: scale, motionPolicy: motionPolicy, time: time)
        let clusterByNode = Dictionary(uniqueKeysWithValues: clusters.flatMap { cluster in
            cluster.nodeIDs.map { ($0, cluster.id) }
        })
        let nodeLookup = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
        let visibleNodeIDs = visibleNodeIDs(
            graph: graph,
            clusters: clusters,
            zoomLevel: zoomLevel,
            selectedNodeID: selectedNodeID,
            hoveredNodeID: hoveredNodeID,
            focusedNodeIDs: focusedNodeIDs
        )
        let firstOrder = firstOrderIDs(in: graph, around: selectedNodeID)
        let nodes = graph.nodes.compactMap { node -> GraphRenderNode? in
            guard visibleNodeIDs.contains(node.id) else { return nil }
            let dimmed = selectedNodeID != nil && selectedNodeID != node.id && !firstOrder.contains(node.id)
            let radius = radius(for: node, selected: selectedNodeID == node.id, zoomLevel: zoomLevel)
            return GraphRenderNode(
                id: node.id,
                title: node.title,
                layer: node.memoryLayer,
                x: node.x,
                y: node.y,
                radius: radius,
                color: color(for: node),
                alpha: dimmed ? 0.20 : Float(max(0.32, min(1, node.confidence))),
                labelVisible: shouldShowLabel(node: node, zoomLevel: zoomLevel, selectedNodeID: selectedNodeID, hoveredNodeID: hoveredNodeID, firstOrderIDs: firstOrder),
                clusterID: clusterByNode[node.id] ?? "unclustered"
            )
        }
        let visibleIDs = Set(nodes.map(\.id))
        let edges = graph.edges.compactMap { edge -> GraphRenderEdge? in
            guard visibleIDs.contains(edge.fromID),
                  visibleIDs.contains(edge.toID),
                  let from = nodeLookup[edge.fromID],
                  let to = nodeLookup[edge.toID] else {
                return nil
            }
            let focused = selectedNodeID == nil || edge.fromID == selectedNodeID || edge.toID == selectedNodeID
            return GraphRenderEdge(
                id: edge.id,
                fromID: edge.fromID,
                toID: edge.toID,
                fromX: from.x,
                fromY: from.y,
                toX: to.x,
                toY: to.y,
                alpha: Float((focused ? 0.34 : 0.08) * max(0.25, edge.confidence)),
                strength: Float(max(0.2, min(1, edge.strength))),
                color: edgeColor(for: edge)
            )
        }
        return GraphRenderSnapshot(zoomLevel: zoomLevel, nodes: nodes, edges: edges, clusters: clusters)
    }

    private static func visibleNodeIDs(
        graph: HiveGraphSnapshot,
        clusters: [GraphClusterRecord],
        zoomLevel: SemanticZoomLevel,
        selectedNodeID: String?,
        hoveredNodeID: String?,
        focusedNodeIDs: Set<String>
    ) -> Set<String> {
        var visible = Set(graph.nodes.map(\.id))
        visible.formUnion(focusedNodeIDs)
        if let selectedNodeID {
            visible.insert(selectedNodeID)
            visible.formUnion(firstOrderIDs(in: graph, around: selectedNodeID))
        }
        if let hoveredNodeID {
            visible.insert(hoveredNodeID)
        }
        return visible
    }

    private static func makeClusters(
        graph: HiveGraphSnapshot,
        scale: Double,
        motionPolicy: LivingGraphMotionPolicy,
        time: TimeInterval
    ) -> [GraphClusterRecord] {
        let grouped = Dictionary(grouping: graph.nodes) { node in
            node.semanticColorKey ?? node.memoryLayer.rawValue
        }
        return grouped.map { key, nodes in
            let count = max(1, nodes.count)
            let baseX = nodes.map(\.x).reduce(0, +) / Double(count)
            let baseY = nodes.map(\.y).reduce(0, +) / Double(count)
            let breath = motionPolicy.effectiveBreathingAmplitude
            let phase = Double(abs(key.hashValue % 997)) / 997.0 * .pi * 2
            let wave = sin(time * 0.55 + phase) * breath
            let maxDistance = nodes.map { hypot($0.x - baseX, $0.y - baseY) }.max() ?? 28
            return GraphClusterRecord(
                id: key,
                title: title(forClusterKey: key),
                nodeIDs: nodes.sorted(by: clusterNodeSort).map(\.id),
                centerX: baseX * (1 + wave),
                centerY: baseY * (1 - wave),
                radius: max(38, maxDistance * (zoomLevelExpansion(scale: scale) + abs(wave))),
                color: color(forKey: key),
                relevance: min(1, nodes.map(\.confidence).reduce(0, +) / Double(count))
            )
        }
        .sorted { $0.relevance > $1.relevance }
    }

    private static func firstOrderIDs(in graph: HiveGraphSnapshot, around selectedID: String?) -> Set<String> {
        guard let selectedID else { return [] }
        return Set(graph.edges.flatMap { edge -> [String] in
            if edge.fromID == selectedID { return [edge.toID] }
            if edge.toID == selectedID { return [edge.fromID] }
            return []
        })
    }

    private static func shouldShowLabel(
        node: GraphNodeRecord,
        zoomLevel: SemanticZoomLevel,
        selectedNodeID: String?,
        hoveredNodeID: String?,
        firstOrderIDs: Set<String>
    ) -> Bool {
        if selectedNodeID == node.id || hoveredNodeID == node.id { return true }
        if selectedNodeID != nil { return firstOrderIDs.contains(node.id) }
        switch zoomLevel {
        case .constellation:
            return node.memoryLayer == .definingTrait
        case .cluster:
            return node.memoryLayer == .definingTrait || node.memoryLayer == .importantTrait
        case .node:
            return node.memoryLayer != .detail || node.confidence >= 0.9
        }
    }

    private static func radius(for node: GraphNodeRecord, selected: Bool, zoomLevel: SemanticZoomLevel) -> Double {
        let base: Double
        switch node.memoryLayer {
        case .detail: base = 5
        case .connector: base = 7
        case .importantTrait: base = 10
        case .definingTrait: base = 14
        }
        let zoomMultiplier: Double = zoomLevel == .constellation ? 1.5 : (zoomLevel == .cluster ? 1.18 : 1.0)
        return base * zoomMultiplier * (selected ? 1.45 : 1)
    }

    private static func color(for node: GraphNodeRecord) -> SIMD4<Float> {
        color(forKey: node.semanticColorKey ?? node.memoryLayer.rawValue)
    }

    private static func color(forKey key: String) -> SIMD4<Float> {
        let palette: [SIMD4<Float>] = [
            SIMD4<Float>(0.96, 0.55, 0.24, 1),
            SIMD4<Float>(0.24, 0.76, 0.70, 1),
            SIMD4<Float>(0.86, 0.76, 0.38, 1),
            SIMD4<Float>(0.62, 0.72, 0.92, 1),
            SIMD4<Float>(0.78, 0.62, 0.44, 1),
            SIMD4<Float>(0.72, 0.84, 0.50, 1)
        ]
        return palette[abs(key.hashValue) % palette.count]
    }

    private static func edgeColor(for edge: GraphEdgeRecord) -> SIMD4<Float> {
        switch edge.predicate {
        case .contradicts:
            return SIMD4<Float>(0.74, 0.36, 0.95, 1)
        case .sourceOf:
            return SIMD4<Float>(0.70, 0.66, 0.56, 1)
        case .supports, .concludes:
            return SIMD4<Float>(0.24, 0.76, 0.70, 1)
        default:
            return SIMD4<Float>(0.96, 0.55, 0.24, 1)
        }
    }

    private static func clusterNodeSort(_ left: GraphNodeRecord, _ right: GraphNodeRecord) -> Bool {
        if left.memoryLayer != right.memoryLayer {
            return layerRank(left.memoryLayer) > layerRank(right.memoryLayer)
        }
        if left.confidence != right.confidence {
            return left.confidence > right.confidence
        }
        return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
    }

    private static func layerRank(_ layer: MemoryNodeLayer) -> Int {
        switch layer {
        case .definingTrait: 4
        case .importantTrait: 3
        case .connector: 2
        case .detail: 1
        }
    }

    private static func title(forClusterKey key: String) -> String {
        key
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func zoomLevelExpansion(scale: Double) -> Double {
        switch SemanticZoomLevel.level(for: scale) {
        case .constellation: return 1.8
        case .cluster: return 1.35
        case .node: return 1.0
        }
    }
}
