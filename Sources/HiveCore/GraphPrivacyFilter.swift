import Foundation

public struct GraphPrivacyFilter: Sendable {
    public init() {}

    public func removingReviewOnlyNodes(_ graph: HiveGraphSnapshot, sources: [SourceRecord]) -> HiveGraphSnapshot {
        let reviewSourceIDs = Set(sources.filter { source in
            source.kind == .browserHistory
                || source.kind == .browserBookmark
                || source.privacyLabel == .cloudBlocked
                || source.status == .needsReview
                || source.deletionState == .fullForgotten
        }.map(\.id))

        guard !reviewSourceIDs.isEmpty else { return graph }

        let removedIDs = Set(graph.nodes.filter { node in
            if reviewSourceIDs.contains(node.id) { return true }
            if [.entity, .topic, .project].contains(node.kind), node.confidence >= 0.78 {
                return false
            }
            if node.title.lowercased().hasPrefix("incidental:") { return true }
            return node.sourceRefs.contains { reviewSourceIDs.contains($0) }
        }.map(\.id))

        guard !removedIDs.isEmpty else { return graph }

        let nodes = graph.nodes.filter { !removedIDs.contains($0.id) }
        let retainedIDs = Set(nodes.map(\.id))
        let edges = graph.edges.filter { edge in
            retainedIDs.contains(edge.fromID)
                && retainedIDs.contains(edge.toID)
                && !edge.sourceRefs.contains { reviewSourceIDs.contains($0) }
        }
        return HiveGraphSnapshot(nodes: GraphEngine().positioned(nodes: nodes, edges: edges), edges: edges)
    }
}
