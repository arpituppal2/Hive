import Foundation

public struct GraphEvidenceFilter: Sendable {
    public init() {}

    public func keepingPersonalEvidence(_ graph: HiveGraphSnapshot, query: String = "") -> HiveGraphSnapshot {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let processPredicates: Set<RelationshipPredicate> = [.markovTransition, .markovLoop, .hamiltonianPath]
        let evidenceEdges = graph.edges.filter { edge in
            edge.fromID != edge.toID && !processPredicates.contains(edge.predicate)
        }
        let nonProcessDegree = evidenceEdges.reduce(into: [String: Int]()) { degree, edge in
            degree[edge.fromID, default: 0] += 1
            degree[edge.toID, default: 0] += 1
        }
        let sourceCount = graph.nodes.reduce(into: [String: Int]()) { counts, node in
            for sourceID in node.sourceRefs {
                counts[node.id, default: 0] += sourceID.isEmpty ? 0 : 1
            }
        }

        let keptNodes = graph.nodes.filter { node in
            if !trimmedQuery.isEmpty && node.title.localizedCaseInsensitiveContains(trimmedQuery) {
                return node.kind != .insight
            }
            switch node.kind {
            case .source:
                return false
            case .claim:
                return node.confidence >= 0.5 || nonProcessDegree[node.id, default: 0] > 0
            case .entity, .topic, .project, .event, .task, .habit:
                return node.confidence >= 0.72
                    || sourceCount[node.id, default: 0] >= 2
                    || nonProcessDegree[node.id, default: 0] >= 3
            case .insight:
                return false
            }
        }
        let keptIDs = Set(keptNodes.map(\.id))
        let keptEdges = evidenceEdges.filter { keptIDs.contains($0.fromID) && keptIDs.contains($0.toID) }
        let connectedIDs = Set(keptEdges.flatMap { [$0.fromID, $0.toID] })
        let finalNodes = keptNodes.filter { node in
            if node.kind == .source || node.kind == .claim || connectedIDs.contains(node.id) {
                return true
            }
            if [.entity, .topic, .project].contains(node.kind),
               node.confidence >= 0.78,
               !node.sourceRefs.isEmpty {
                return true
            }
            return false
        }
        let finalIDs = Set(finalNodes.map(\.id))
        return HiveGraphSnapshot(
            nodes: finalNodes,
            edges: keptEdges.filter { finalIDs.contains($0.fromID) && finalIDs.contains($0.toID) }
        )
    }
}
