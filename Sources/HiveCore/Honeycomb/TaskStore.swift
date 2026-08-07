import Foundation

// MARK: - TaskStore

extension HoneycombStore {

    // MARK: Task CRUD

    /// Creates a task node. Tasks are authored artifacts — no dedup.
    /// Any source IDs carried in the task's metadata are linked as `references`
    /// edges best-effort, so metadata and edges never drift apart.
    @discardableResult
    public func createTask(_ task: HiveTask) throws -> HiveTask {
        _ = try insertNode(task.toNode(), checkDedup: false)
        for sourceID in task.sourceIDs {
            _ = try? linkSourceToTask(sourceID: sourceID, taskID: task.id)
        }
        return task
    }

    /// Fetches a task by node ID. Returns nil if missing or not a `.task`.
    public func getTask(id: String) throws -> HiveTask? {
        guard let node = try getNode(id: id) else { return nil }
        return HiveTask.from(node)
    }

    /// All tasks, newest first. Optionally filtered by state.
    public func getAllTasks(state: HiveTask.State? = nil, limit: Int = 1000) throws -> [HiveTask] {
        try getNodesByType(.task, limit: limit)
            .compactMap { HiveTask.from($0) }
            .filter { state == nil || $0.state == state }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// FTS search over task titles/notes (label + metadata indexed).
    public func searchTasks(_ query: String, limit: Int = 20) throws -> [HiveTask] {
        try search(query: query, limit: limit).compactMap { HiveTask.from($0) }
    }

    /// The action inbox: all open and in-progress tasks, overdue first, then
    /// by priority. This is the §7.7 project action inbox query.
    ///
    /// The comparator is a strict weak ordering: overdue flag computed once
    /// against a fixed `now`, then an explicit priority rank (high > medium >
    /// low), then recency.
    public func getActionInbox(limit: Int = 200) throws -> [HiveTask] {
        let active = try getNodesByType(.task, limit: limit)
            .compactMap { HiveTask.from($0) }
            .filter { $0.state == .open || $0.state == .inProgress }
        let now = Date()
        return active.sorted { lhs, rhs in
            let lhsOverdue = lhs.dueDate.map { $0 < now } ?? false
            let rhsOverdue = rhs.dueDate.map { $0 < now } ?? false
            if lhsOverdue != rhsOverdue { return lhsOverdue }
            let lhsRank = priorityRank(lhs.priority)
            let rhsRank = priorityRank(rhs.priority)
            if lhsRank != rhsRank { return lhsRank > rhsRank }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func priorityRank(_ priority: HiveTask.Priority) -> Int {
        switch priority {
        case .high: return 2
        case .medium: return 1
        case .low: return 0
        }
    }

    /// Updates a task's editable fields. Bumps updatedAt, records a revision,
    /// and re-indexes FTS via updateNode. Pass `clearDueDate: true` to remove
    /// a previously set due date. Returns nil if the node is missing or not a
    /// `.task`.
    @discardableResult
    public func updateTask(
        id: String,
        title: String? = nil,
        notes: String? = nil,
        state: HiveTask.State? = nil,
        priority: HiveTask.Priority? = nil,
        dueDate: Date? = nil,
        clearDueDate: Bool = false
    ) throws -> HiveTask? {
        guard let node = try getNode(id: id), node.type == .task else { return nil }
        guard let task = HiveTask.from(node) else { return nil }
        var meta: [String: JSONValue] = [
            "notes": .string(notes ?? task.notes),
            "state": .string(state?.rawValue ?? task.state.rawValue),
            "priority": .string(priority?.rawValue ?? task.priority.rawValue)
        ]
        let newDueDate: Date?
        if clearDueDate {
            newDueDate = nil
        } else {
            newDueDate = dueDate ?? task.dueDate
        }
        if let newDueDate {
            meta["dueDate"] = .double(newDueDate.timeIntervalSince1970)
        }
        if !task.sourceIDs.isEmpty {
            meta["sourceIDs"] = .array(task.sourceIDs.map { .string($0) })
        }
        let updated = try updateNode(id: id, label: title ?? task.title, metadata: .object(meta))
        guard let updated else { return nil }
        return HiveTask.from(updated)
    }

    /// Marks a task done. Convenience wrapper over updateTask.
    @discardableResult
    public func completeTask(id: String) throws -> HiveTask? {
        try updateTask(id: id, state: .done)
    }

    /// Deletes a task node. All incident edges cascade via ON DELETE CASCADE.
    /// Type-checked: refuses to delete a non-task node.
    @discardableResult
    public func deleteTask(id: String) throws -> Bool {
        guard let node = try getNode(id: id), node.type == .task else { return false }
        try deleteNode(id: id)
        return true
    }

    // MARK: Source links

    /// Links a task to a source node via a `references` edge. Idempotent.
    @discardableResult
    public func linkSourceToTask(sourceID: String, taskID: String) throws -> HoneycombStore.Edge? {
        let alreadyLinked = try edgeExists(from: sourceID, to: taskID, relation: .references)
        guard try getNode(id: taskID)?.type == .task,
              try getNode(id: sourceID)?.type == .source,
              !alreadyLinked
        else { return nil }
        return try insertEdge(HoneycombStore.Edge(
            sourceID: sourceID,
            targetID: taskID,
            relation: .references
        ))
    }

    /// Resolves the source nodes referenced by a task.
    public func getSourcesForTask(taskID: String) throws -> [HoneycombStore.Node] {
        let incoming = try getEdges(to: taskID, relation: .references).map(\.sourceID)
        let outgoing = try getEdges(from: taskID, relation: .references).map(\.targetID)
        return try getNodes(ids: incoming + outgoing)
    }

    // MARK: Dependency graph

    /// Records that `taskID` depends on `dependencyID` via a `dependsOn` edge
    /// (taskID → dependencyID). Idempotent.
    @discardableResult
    public func addDependency(taskID: String, dependsOn dependencyID: String) throws -> HoneycombStore.Edge? {
        let alreadyLinked = try edgeExists(from: taskID, to: dependencyID, relation: .dependsOn)
        guard taskID != dependencyID,
              try getNode(id: taskID)?.type == .task,
              try getNode(id: dependencyID)?.type == .task,
              !alreadyLinked
        else { return nil }
        return try insertEdge(HoneycombStore.Edge(
            sourceID: taskID,
            targetID: dependencyID,
            relation: .dependsOn
        ))
    }

    /// Removes a dependency edge if present. Returns true if one was removed.
    @discardableResult
    public func removeDependency(taskID: String, dependsOn dependencyID: String) throws -> Bool {
        let edges = try getEdges(from: taskID, relation: .dependsOn)
            .filter { $0.targetID == dependencyID }
        for edge in edges {
            try deleteEdge(id: edge.id)
        }
        return !edges.isEmpty
    }

    /// The tasks this task directly depends on (its prerequisites).
    public func getDependencies(of taskID: String) throws -> [HiveTask] {
        let dependencyIDs = try getEdges(from: taskID, relation: .dependsOn).map(\.targetID)
        return try getNodes(ids: dependencyIDs).compactMap { HiveTask.from($0) }
    }

    /// The tasks that directly depend on this task (its dependents).
    public func getDependents(of taskID: String) throws -> [HiveTask] {
        let dependentIDs = try getEdges(to: taskID, relation: .dependsOn).map(\.sourceID)
        return try getNodes(ids: dependentIDs).compactMap { HiveTask.from($0) }
    }

    /// Tasks that are blocked: they depend on at least one task that is not
    /// done or cancelled. Useful for the project action inbox.
    public func getBlockedTasks(projectID: String) throws -> [HiveTask] {
        let tasks = try getProjectTasks(projectID: projectID)
        return try tasks.filter { task in
            let deps = try getDependencies(of: task.id)
            return deps.contains { $0.state != .done && $0.state != .cancelled }
        }
    }
}
