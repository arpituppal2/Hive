import Foundation

// MARK: - HiveTask

/// A single actionable item in the Hive project system. Tasks are Honeycomb
/// `.task` nodes; they attach to projects via `belongsTo` edges, reference
/// sources via `references` edges, and form a dependency graph via
/// `dependsOn` edges.
///
/// This is the §7.1 `Task` object: title, state, schedule, estimate,
/// dependency, and source link — all local-first on Honeycomb.
public struct HiveTask: Codable, Sendable, Identifiable, Equatable {

    /// Lifecycle state of a task. `done` and `cancelled` are terminal.
    public enum State: String, Codable, Sendable, CaseIterable {
        case open
        case inProgress
        case done
        case cancelled
    }

    /// Task priority. Pure ordering hint — never an authority decision.
    public enum Priority: String, Codable, Sendable, CaseIterable {
        case low
        case medium
        case high
    }

    public let id: String
    public var title: String
    public var notes: String
    public var state: State
    public var priority: Priority
    public var dueDate: Date?
    public var sourceIDs: [String]
    public let createdAt: Date
    public var updatedAt: Date
    public let provenance: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        notes: String = "",
        state: State = .open,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        sourceIDs: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        provenance: String = "user"
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.state = state
        self.priority = priority
        self.dueDate = dueDate
        self.sourceIDs = sourceIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provenance = provenance
    }

    // MARK: - Conversion

    /// Converts this task into a Honeycomb `.task` node. The label is the
    /// title (FTS-indexed); metadata carries notes, state, priority, due date
    /// (as epoch seconds — deterministic, no formatter needed), and source IDs.
    public func toNode() -> HoneycombStore.Node {
        var meta: [String: JSONValue] = [
            "notes": .string(notes),
            "state": .string(state.rawValue),
            "priority": .string(priority.rawValue)
        ]
        if let dueDate {
            meta["dueDate"] = .double(dueDate.timeIntervalSince1970)
        }
        if !sourceIDs.isEmpty {
            meta["sourceIDs"] = .array(sourceIDs.map { .string($0) })
        }
        return HoneycombStore.Node(
            id: id,
            type: .task,
            label: title,
            metadata: .object(meta),
            contentHash: nil,           // tasks are authored artifacts, no dedup
            createdAt: createdAt,
            updatedAt: updatedAt,
            provenance: provenance
        )
    }

    /// Creates a task from a Honeycomb node. Returns nil if the node is not
    /// a `.task` type.
    public static func from(_ node: HoneycombStore.Node) -> HiveTask? {
        guard node.type == .task else { return nil }
        let m = node.metadata
        var notes = ""
        var state = State.open
        var priority = Priority.medium
        var dueDate: Date?
        var sourceIDs: [String] = []
        if case .object(let dict) = m {
            if case .string(let s) = dict["notes"] { notes = s }
            if case .string(let s) = dict["state"], let st = State(rawValue: s) { state = st }
            if case .string(let s) = dict["priority"], let p = Priority(rawValue: s) { priority = p }
            if case .double(let t) = dict["dueDate"] { dueDate = Date(timeIntervalSince1970: t) }
            if case .array(let arr) = dict["sourceIDs"] {
                sourceIDs = arr.compactMap { span in
                    guard case .string(let s) = span else { return nil }
                    return s
                }
            }
        }
        return HiveTask(
            id: node.id,
            title: node.label,
            notes: notes,
            state: state,
            priority: priority,
            dueDate: dueDate,
            sourceIDs: sourceIDs,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            provenance: node.provenance
        )
    }
}
