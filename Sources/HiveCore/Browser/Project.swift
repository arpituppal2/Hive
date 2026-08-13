import Foundation

// MARK: - Project

/// A Hive project — the container for related work objects (sources, briefs,
/// decisions, tasks). Projects are Honeycomb `.project` nodes; members attach
/// via `belongsTo` edges, which `getProjectNodes` traverses.
///
/// This is the §7.1 `Project or Hive` object: title, purpose, lifecycle,
/// ownership, and pinned context. Tasks and briefs link in through typed
/// edges, so a project view is always a live query over the graph, never a
/// snapshot list.
public struct Project: Codable, Sendable, Identifiable, Equatable {

    /// Lifecycle of a project. Archived projects remain queryable but are
    /// excluded from the default active list.
    public enum Lifecycle: String, Codable, Sendable, CaseIterable {
        case active
        case archived
    }

    public let id: String
    public var title: String
    public var purpose: String
    public var lifecycle: Lifecycle
    public let createdAt: Date
    public var updatedAt: Date
    public let provenance: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        purpose: String = "",
        lifecycle: Lifecycle = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        provenance: String = "user"
    ) {
        self.id = id
        self.title = title
        self.purpose = purpose
        self.lifecycle = lifecycle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provenance = provenance
    }

    // MARK: - Conversion

    /// Converts this Project into a Honeycomb `.project` node. The label is the
    /// title (FTS-indexed); metadata carries the purpose and lifecycle.
    public func toNode() -> HoneycombStore.Node {
        HoneycombStore.Node(
            id: id,
            type: .project,
            label: title,
            metadata: .object([
                "purpose": .string(purpose),
                "lifecycle": .string(lifecycle.rawValue)
            ]),
            contentHash: nil,           // projects are authored artifacts, no dedup
            createdAt: createdAt,
            updatedAt: updatedAt,
            provenance: provenance
        )
    }

    /// Creates a Project from a Honeycomb node. Returns nil if the node is not
    /// a `.project` type.
    public static func from(_ node: HoneycombStore.Node) -> Project? {
        guard node.type == .project else { return nil }
        let m = node.metadata
        var purpose = ""
        var lifecycle = Lifecycle.active
        if case .object(let dict) = m {
            if case .string(let s) = dict["purpose"] { purpose = s }
            if case .string(let s) = dict["lifecycle"], let lc = Lifecycle(rawValue: s) { lifecycle = lc }
        }
        return Project(
            id: node.id,
            title: node.label,
            purpose: purpose,
            lifecycle: lifecycle,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            provenance: node.provenance
        )
    }
}
