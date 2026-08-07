import Foundation

// MARK: - BriefStore: durable, source-linked, editable, exportable briefs

/// DATA-005: Briefs are reproducible, source-linked, editable, and exportable,
/// backed by Honeycomb (typed `.brief` nodes + `references` edges) and the
/// EventLedger (the caller records the save). Every brief is a Markdown
/// document whose claims trace to stored Source nodes via `references` edges —
/// the same contract AGENTS.md §7.3 requires for research output.
extension HoneycombStore {

    /// Creates a Brief as a `.brief` Honeycomb node, linking each source ID
    /// with a `references` edge (see-also). No content-hash dedup — briefs are
    /// authored artifacts, not raw extractions.
    /// - Returns: the created Brief.
    @discardableResult
    public func createBrief(_ brief: Brief) throws -> Brief {
        let node = try insertNode(brief.toNode(), checkDedup: false)
        // Best-effort linking: a stale/nonexistent source ID degrades to "no
        // link" rather than aborting mid-write — a thrown link after insert
        // would orphan the brief node (partial-write hazard).
        for sourceID in brief.sourceIDs {
            _ = try? linkBriefToSource(briefID: node.id, sourceID: sourceID)
        }
        return Brief.from(node) ?? brief
    }

    /// Retrieves a Brief by node ID.
    public func getBrief(id: String) throws -> Brief? {
        guard let node = try getNode(id: id) else { return nil }
        return Brief.from(node)
    }

    /// Returns all Briefs, ordered by creation date descending.
    public func getAllBriefs(limit: Int = 100) throws -> [Brief] {
        try getNodesByType(.brief, limit: limit).compactMap { Brief.from($0) }
    }

    /// Finds Briefs by full-text search over title + content (FTS5).
    public func searchBriefs(query text: String, limit: Int = 20) throws -> [Brief] {
        try search(query: text, limit: limit)
            .filter { $0.type == .brief }
            .compactMap { Brief.from($0) }
    }

    /// Edits a Brief's title, content, or source list. The previous label and
    /// metadata are preserved in the revision history (AGENTS.md §8.3) before
    /// the overwrite, so edits are auditable. Source edges are reconciled to
    /// the new source list.
    /// - Returns: the updated Brief, or nil if the brief doesn't exist.
    public func updateBrief(
        briefID: String,
        title: String? = nil,
        content: String? = nil,
        sourceIDs: [String]? = nil
    ) throws -> Brief? {
        guard let brief = try getBrief(id: briefID) else { return nil }
        let newSourceIDs = sourceIDs ?? brief.sourceIDs
        let updated = Brief(
            id: brief.id,
            title: title ?? brief.title,
            content: content ?? brief.content,
            sourceIDs: newSourceIDs,
            createdAt: brief.createdAt,
            updatedAt: Date(),
            provenance: brief.provenance
        )
        guard let node = try updateNode(id: briefID, label: updated.title,
                                        metadata: updated.toNode().metadata) else {
            return nil
        }
        // Reconcile `references` edges ONLY when the source list changed — a
        // title/content-only edit shouldn't re-run the edge queries.
        if sourceIDs != nil {
            try reconcileBriefSources(briefID: briefID, to: newSourceIDs)
        }
        return Brief.from(node)
    }

    /// Deletes a Brief and its graph edges (references cascade via
    /// `ON DELETE CASCADE`). Type-checked — never deletes a non-brief node.
    /// - Returns: true if a brief was deleted, false if the ID didn't exist
    ///   or wasn't a `.brief` node.
    @discardableResult
    public func deleteBrief(id: String) throws -> Bool {
        guard let node = try getNode(id: id), node.type == .brief else { return false }
        try deleteNode(id: id)
        return true
    }

    /// Links a Brief to a Source with a `references` edge. Idempotent — an
    /// existing edge is returned, never duplicated.
    @discardableResult
    public func linkBriefToSource(briefID: String, sourceID: String) throws -> Edge {
        if try edgeExists(from: briefID, to: sourceID, relation: .references) {
            let existing = try getEdges(from: briefID, relation: .references)
            if let found = existing.first(where: { $0.targetID == sourceID }) {
                return found
            }
        }
        return try insertEdge(Edge(sourceID: briefID, targetID: sourceID,
                                   relation: .references, weight: 1.0))
    }

    /// Returns all Sources referenced by a Brief (via `references` edges).
    public func getSourcesForBrief(_ briefID: String) throws -> [Source] {
        try getEdges(from: briefID, relation: .references)
            .compactMap { try? getSource(id: $0.targetID) }
    }

    /// Exports a Brief as reproducible Markdown — title, content, and a
    /// numbered source list with real URLs resolved live from the graph.
    /// Every claim's evidence is traceable to the stored Source objects.
    public func exportMarkdown(_ brief: Brief) throws -> String {
        var lines: [String] = []
        lines.append("# \(brief.title)")
        lines.append("")
        lines.append(brief.content)
        let sources = try getSourcesForBrief(brief.id)
        if !sources.isEmpty {
            lines.append("")
            lines.append("## Sources")
            for (i, source) in sources.enumerated() {
                let title = source.title ?? source.url
                lines.append("\(i + 1). [\(title)](\(source.url))")
            }
        }
        lines.append("")
        let stamp = ISO8601DateFormatter().string(from: brief.updatedAt)
        lines.append("_Exported from Hive · \(stamp)_")
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    /// Reconciles a Brief's `references` edges to the given source list —
    /// adds missing edges, drops stale ones. Used by `updateBrief`.
    private func reconcileBriefSources(briefID: String, to sourceIDs: [String]) throws {
        let existing = try getEdges(from: briefID, relation: .references)
        let target = Set(sourceIDs)
        for edge in existing where !target.contains(edge.targetID) {
            try deleteEdge(id: edge.id)
        }
        for sourceID in sourceIDs {
            _ = try linkBriefToSource(briefID: briefID, sourceID: sourceID)
        }
    }
}
