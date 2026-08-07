import Foundation

// MARK: - ProjectStore

extension HoneycombStore {

    // MARK: Project CRUD

    /// Creates a project node. Projects are authored artifacts — no dedup.
    @discardableResult
    public func createProject(_ project: Project) throws -> Project {
        _ = try insertNode(project.toNode(), checkDedup: false)
        return project
    }

    /// Fetches a project by node ID. Returns nil if missing or not a `.project`.
    public func getProject(id: String) throws -> Project? {
        guard let node = try getNode(id: id) else { return nil }
        return Project.from(node)
    }

    /// All projects, newest first. Optionally filtered by lifecycle.
    public func getAllProjects(lifecycle: Project.Lifecycle? = nil) throws -> [Project] {
        try getNodesByType(.project, limit: 1000)
            .compactMap { Project.from($0) }
            .filter { lifecycle == nil || $0.lifecycle == lifecycle }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// FTS search over project titles/purposes (label + metadata indexed).
    public func searchProjects(_ query: String, limit: Int = 20) throws -> [Project] {
        try search(query: query, limit: limit).compactMap { Project.from($0) }
    }

    /// Updates a project's title, purpose, and/or lifecycle. Bumps updatedAt,
    /// records a revision, and re-indexes FTS via updateNode. Returns nil if
    /// the node is missing or not a `.project`.
    @discardableResult
    public func updateProject(
        id: String,
        title: String? = nil,
        purpose: String? = nil,
        lifecycle: Project.Lifecycle? = nil
    ) throws -> Project? {
        guard let node = try getNode(id: id), node.type == .project else { return nil }
        guard let project = Project.from(node) else { return nil }
        let meta: [String: JSONValue] = [
            "purpose": .string(purpose ?? project.purpose),
            "lifecycle": .string(lifecycle?.rawValue ?? project.lifecycle.rawValue)
        ]
        let updated = try updateNode(id: id, label: title ?? project.title, metadata: .object(meta))
        guard let updated else { return nil }
        return Project.from(updated)
    }

    /// Deletes a project node. All incident edges cascade via ON DELETE CASCADE.
    /// Type-checked: refuses to delete a non-project node.
    @discardableResult
    public func deleteProject(id: String) throws -> Bool {
        guard let node = try getNode(id: id), node.type == .project else { return false }
        try deleteNode(id: id)
        return true
    }

    // MARK: Membership

    /// Attaches a task to a project via a `belongsTo` edge. Idempotent —
    /// returns nil if the edge already exists or either side is the wrong type.
    @discardableResult
    public func addTaskToProject(taskID: String, projectID: String) throws -> HoneycombStore.Edge? {
        let alreadyLinked = try edgeExists(from: taskID, to: projectID, relation: .belongsTo)
        guard try getNode(id: taskID)?.type == .task,
              try getNode(id: projectID)?.type == .project,
              !alreadyLinked
        else { return nil }
        return try insertEdge(HoneycombStore.Edge(
            sourceID: taskID,
            targetID: projectID,
            relation: .belongsTo
        ))
    }

    /// All tasks belonging to a project, via `belongsTo` edges. The task list
    /// is a live graph query, never a stored snapshot.
    public func getProjectTasks(projectID: String, limit: Int = 500) throws -> [HiveTask] {
        try getProjectNodes(projectID: projectID, limit: limit)
            .compactMap { HiveTask.from($0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Returns the task IDs belonging to a project (cheap — edges only).
    /// Deduplicated (handles both edge directions defensively) and sorted for
    /// deterministic callers.
    public func getProjectTaskIDs(projectID: String) throws -> [String] {
        var ids = Set<String>()
        for edge in try getEdges(from: projectID, relation: .belongsTo) { ids.insert(edge.targetID) }
        for edge in try getEdges(to: projectID, relation: .belongsTo) { ids.insert(edge.sourceID) }
        return ids.sorted()
    }

    // MARK: Export

    /// Exports a project as Markdown: header, purpose, lifecycle, and a
    /// state-grouped task list with priorities and due dates. Returns nil if
    /// the project is missing.
    public func exportProject(id: String) throws -> String? {
        guard let project = try getProject(id: id) else { return nil }
        var out = "# \(project.title)\n\n"
        if !project.purpose.isEmpty {
            out += "> \(project.purpose)\n\n"
        }
        out += "- Status: \(project.lifecycle.rawValue)\n"
        out += "- Updated: \(project.updatedAt.formatted(date: .abbreviated, time: .omitted))\n\n"

        let tasks = try getProjectTasks(projectID: id)
        let open = tasks.filter { $0.state == .open || $0.state == .inProgress }
        let done = tasks.filter { $0.state == .done }
        let cancelled = tasks.filter { $0.state == .cancelled }

        out += "## Open (\(open.count))\n\n"
        if open.isEmpty { out += "_None._\n\n" }
        for task in open {
            out += taskLine(task)
        }

        out += "## Done (\(done.count))\n\n"
        if done.isEmpty { out += "_None._\n\n" }
        for task in done {
            out += taskLine(task)
        }

        if !cancelled.isEmpty {
            out += "## Cancelled (\(cancelled.count))\n\n"
            for task in cancelled {
                out += taskLine(task)
            }
        }
        return out
    }

    private func taskLine(_ task: HiveTask) -> String {
        let checked = task.state == .done
        var line = "- [\(checked ? "x" : " ")] **\(task.title)**"
        line += " (priority: \(task.priority.rawValue)"
        if let due = task.dueDate {
            line += ", due: \(due.formatted(date: .abbreviated, time: .omitted))"
        }
        line += ")"
        if !task.notes.isEmpty {
            line += " — \(task.notes.replacingOccurrences(of: "\n", with: " "))"
        }
        return line + "\n"
    }
}
