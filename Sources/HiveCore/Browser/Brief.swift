import Foundation

// MARK: - Brief

/// A durable, source-linked knowledge object — the output of Swarm research,
/// saved into Honeycomb for later recall. Briefs are Markdown documents with
/// typed edges to their source Honeycomb nodes, so every claim is traceable
/// to what was captured.
///
/// Stored as Honeycomb nodes of type `.brief` with metadata carrying the full
/// Markdown content and an array of source node IDs for edge creation.
public struct Brief: Codable, Sendable, Identifiable, Equatable {

    public let id: String
    public var title: String
    public var content: String
    public var sourceIDs: [String]
    public let createdAt: Date
    public var updatedAt: Date
    public let provenance: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        content: String,
        sourceIDs: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        provenance: String = "swarm-research"
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.sourceIDs = sourceIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provenance = provenance
    }

    // MARK: - Conversion

    /// Converts this Brief into a Honeycomb `.brief` node. The label is the
    /// title (FTS-indexed); metadata carries the Markdown content and the
    /// source node IDs (used for `references` edges on create).
    public func toNode() -> HoneycombStore.Node {
        var meta: [String: JSONValue] = [
            "content": .string(content)
        ]
        if !sourceIDs.isEmpty {
            meta["sourceIDs"] = .array(sourceIDs.map { .string($0) })
        }
        return HoneycombStore.Node(
            id: id,
            type: .brief,
            label: title,
            metadata: .object(meta),
            contentHash: nil,           // briefs are authored artifacts, no dedup
            createdAt: createdAt,
            updatedAt: updatedAt,
            provenance: provenance
        )
    }

    /// Creates a Brief from a Honeycomb node. Returns nil if the node is not
    /// a `.brief` type.
    public static func from(_ node: HoneycombStore.Node) -> Brief? {
        guard node.type == .brief else { return nil }
        let m = node.metadata
        var content = ""
        var sourceIDs: [String] = []
        if case .object(let dict) = m {
            if case .string(let s) = dict["content"] { content = s }
            if case .array(let arr) = dict["sourceIDs"] {
                sourceIDs = arr.compactMap { span in
                    guard case .string(let s) = span else { return nil }
                    return s
                }
            }
        }
        return Brief(
            id: node.id,
            title: node.label,
            content: content,
            sourceIDs: sourceIDs,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            provenance: node.provenance
        )
    }
}
