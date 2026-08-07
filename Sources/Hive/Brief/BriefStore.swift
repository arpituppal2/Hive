import Foundation
import HiveCore

// MARK: - BriefStore

/// Actor-isolated persistence for `Brief` objects backed by HoneycombStore.
/// Each Brief is stored as a Honeycomb node of type `.brief` with its full
/// Markdown content in metadata and typed edges (`derivedFrom`) to each
/// cited source node.
///
/// The store does NOT own its own SQLite connection — it delegates to an
/// injected `HoneycombStore` so Briefs share the same knowledge graph as
/// captures, claims, and projects.

public actor BriefStore {

    private let honeycomb: HoneycombStore
    private let ledger: EventLedgerStore?

    public init(honeycomb: HoneycombStore, ledger: EventLedgerStore? = nil) {
        self.honeycomb = honeycomb
        self.ledger = ledger
    }

    // MARK: - CRUD

    /// Persists a Brief as a Honeycomb node + edges to each source.
    /// Returns the stored Brief (the caller's id is preserved).
    @discardableResult
    public func save(_ brief: Brief) async throws -> Brief {
        // 1. Insert the Brief node.
        let node = HoneycombStore.Node(
            id: brief.id,
            type: .brief,
            label: brief.title,
            metadata: .object([
                "title": .string(brief.title),
                "content": .string(brief.content),
                "sourceIDs": .array(brief.sourceIDs.map { .string($0) }),
                "provenance": .string(brief.provenance)
            ]),
            provenance: brief.provenance
        )
        _ = try await honeycomb.insertNode(node, checkDedup: false)

        // 2. Link Brief → each source via derivedFrom edges.
        for sourceID in brief.sourceIDs {
            let edge = HoneycombStore.Edge(
                sourceID: brief.id,
                targetID: sourceID,
                relation: .derivedFrom
            )
            _ = try? await honeycomb.insertEdge(edge)
        }

        // 3. Audit.
        if let ledger {
            let event = EventLedgerStore.LedgerEvent(
                actor: "user",
                intent: "Save Brief: \(brief.title)",
                actionKind: .capture,
                actionTarget: brief.id,
                actionPreview: "Saved Brief \"\(brief.title)\" with \(brief.sourceIDs.count) sources",
                trustLevel: .t0,
                policyDecision: .allowed,
                consentState: .auto,
                contextIDs: [brief.id] + brief.sourceIDs,
                result: .success,
                provenance: "brief-store"
            )
            _ = try? await ledger.record(event)
        }

        return brief
    }

    /// Retrieves a Brief by id. Returns nil if the node doesn't exist or isn't a brief.
    public func get(id: String) async throws -> Brief? {
        guard let node = try await honeycomb.getNode(id: id),
              node.type == .brief else { return nil }
        return brief(from: node)
    }

    /// Lists all Briefs, newest first. Respects the limit.
    public func list(limit: Int = 50) async throws -> [Brief] {
        let nodes = try await honeycomb.getNodesByType(.brief, limit: limit)
        return nodes.map { brief(from: $0) }
    }

    /// Deletes a Brief and all its edges. The source nodes are NOT deleted.
    public func delete(id: String) async throws {
        try await honeycomb.deleteNode(id: id)
    }

    // MARK: - Helpers

    private func brief(from node: HoneycombStore.Node) -> Brief {
        let title: String
        let content: String
        let sourceIDs: [String]
        switch node.metadata {
        case .object(let dict):
            title = dict.string("title") ?? node.label
            content = dict.string("content") ?? ""
            sourceIDs = dict.array("sourceIDs")?.compactMap { $0.stringValue } ?? []
        default:
            title = node.label
            content = ""
            sourceIDs = []
        }
        return Brief(
            id: node.id,
            title: title,
            content: content,
            sourceIDs: sourceIDs,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            provenance: node.provenance
        )
    }
}

// MARK: - JSONValue helpers

private extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String) -> String? {
        guard case .string(let s) = self[key] else { return nil }
        return s
    }
    func array(_ key: String) -> [JSONValue]? {
        guard case .array(let a) = self[key] else { return nil }
        return a
    }
}

private extension JSONValue {
    var stringValue: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }
}
