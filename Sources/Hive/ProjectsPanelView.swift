import SwiftUI
import HiveCore

// MARK: - Projects Panel

/// The Organize step of the demo spine: captured knowledge becomes a project
/// with next-action tasks. Wraps the verified ProjectStore/TaskStore data
/// layer (Honeycomb `.project` / `.task` nodes + `belongsTo` edges).
///
/// Two levels:
/// 1. List — all projects, a create form, and a "capture this page as a
///    source" shortcut.
/// 2. Detail — the selected project's purpose, open next-action tasks (with
///    add / complete / delete), and the linked sources/briefs it draws on.
struct ProjectsPanel: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var projects: [Project] = []
    @State private var selectedProjectID: String?
    @State private var isCreatingProject = false
    @State private var newProjectTitle = ""
    @State private var newProjectPurpose = ""
    @State private var projectError: String?

    var body: some View {
        VStack(spacing: 0) {
            if let selectedProjectID {
                ProjectDetailPanel(projectID: selectedProjectID, onBack: { self.selectedProjectID = nil })
            } else {
                projectListView
            }
        }
        .task { await refresh() }
    }

    // MARK: - Project List

    private var projectListView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(HiveDesign.Typography.sidebarItemSemiBold)
                    .foregroundStyle(HiveDesign.Accent.primary)
                Text("Projects")
                    .font(HiveDesign.Typography.sidebarItem)
                    .foregroundStyle(HiveDesign.Text.primary)
                Spacer()
                Button(action: { withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) { isCreatingProject.toggle() } }) {
                    Image(systemName: isCreatingProject ? "xmark" : "plus")
                        .font(HiveDesign.Typography.sectionHeader)
                        .foregroundStyle(HiveDesign.Accent.primary)
                        .frame(width: 20, height: 20)
                        .background(HiveDesign.Surface.level2)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help(isCreatingProject ? "Cancel" : "New project")
                .accessibilityLabel(isCreatingProject ? "Cancel new project" : "Create new project")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if isCreatingProject {
                newProjectForm
            }

            if let error = projectError {
                Text(error)
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if projects.isEmpty && !isCreatingProject {
                        emptyProjectsState
                    } else {
                        ForEach(projects) { project in
                            ProjectRow(project: project) {
                                withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) {
                                    selectedProjectID = project.id
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    private var newProjectForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Project title", text: $newProjectTitle)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.sidebarItemMedium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onSubmit { Task { await createProject() } }
            TextField("What is this project about?", text: $newProjectPurpose)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.smallLabel)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onSubmit { Task { await createProject() } }
            HStack {
                Spacer()
                Button("Create") { Task { await createProject() } }
                    .buttonStyle(.borderedProminent)
                    .tint(HiveDesign.Accent.primary)
                    .font(HiveDesign.Typography.sectionHeader)
                    .disabled(newProjectTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var emptyProjectsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.5))
            Text("No projects yet")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(HiveDesign.Text.secondary)
            Text("Create a project to group your captures, briefs, and next actions around a goal.")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(HiveDesign.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Actions

    private func createProject() async {
        guard !state.isKnowledgePersistenceDegraded else {
            projectError = "Project creation blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        let title = newProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let purpose = newProjectPurpose.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let project = Project(title: title, purpose: purpose)
            try await state.honeycomb.createProject(project)
            await MainActor.run {
                newProjectTitle = ""
                newProjectPurpose = ""
                isCreatingProject = false
                projectError = nil
            }
            await refresh()
        } catch {
            await MainActor.run {
                projectError = "Could not create project: \(error.localizedDescription)"
                state.reportKnowledgePersistenceFailure()
            }
        }
    }

    private func refresh() async {
        if let list = try? await state.honeycomb.getAllProjects() {
            await MainActor.run { projects = list }
        }
    }
}

// MARK: - Project Row

private struct ProjectRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let project: Project
    var onOpen: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(HiveDesign.Accent.primary.opacity(0.12))
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "folder.fill")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(HiveDesign.Accent.primary)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(HiveDesign.Typography.sidebarItemMedium)
                    .foregroundStyle(HiveDesign.Text.primary)
                    .lineLimit(1)
                Text(project.purpose.isEmpty ? "No purpose set" : project.purpose)
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(HiveDesign.Typography.microLabel)
                .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Open \(project.title)")
        .onTapGesture(perform: onOpen)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) {
                isHovered = hovering
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? HiveDesign.Surface.level1 : .clear)
        )
    }

    @State private var isHovered = false
}

// MARK: - Project Detail

private struct ProjectDetailPanel: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let projectID: String
    var onBack: () -> Void

    @State private var project: Project?
    @State private var tasks: [HiveTask] = []
    @State private var linkedNodes: [HoneycombStore.Node] = []
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskPriority: HiveTask.Priority = .medium
    @State private var isCapturingPage = false
    @State private var detailError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Back header
            HStack(spacing: 6) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(HiveDesign.Typography.captionBold)
                        Text("Projects")
                            .font(HiveDesign.Typography.smallLabelMedium)
                    }
                    .foregroundStyle(HiveDesign.Text.secondary)
                }
                .buttonStyle(.plain)
                .help("Back to all projects")
                .accessibilityLabel("Back to all projects")
                Spacer()
                if let project {
                    Text(project.lifecycle == .active ? "Active" : "Archived")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(project.lifecycle == .active ? HiveDesign.Accent.primary : HiveDesign.Text.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(HiveDesign.Surface.level2)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let project {
                        projectHeader(project)
                        taskSection
                        linkedSection
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .task { await refresh() }
    }

    // MARK: - Header

    private func projectHeader(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.title)
                .font(HiveDesign.Typography.panelTitleBold)
                .foregroundStyle(HiveDesign.Text.primary)
            if !project.purpose.isEmpty {
                Text(project.purpose)
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(HiveDesign.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Label("\(tasks.count) tasks", systemImage: "checkmark.circle")
                Label("\(linkedNodes.count) sources", systemImage: "link")
            }
            .font(HiveDesign.Typography.caption)
            .foregroundStyle(HiveDesign.Text.tertiary)
            .padding(.top, 2)

            if let error = detailError {
                Text(error)
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Tasks

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(HiveDesign.Typography.captionSemiBold)
                    .foregroundStyle(HiveDesign.Accent.primary)
                Text("NEXT ACTIONS")
                    .font(HiveDesign.Typography.microLabelBold)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                Spacer()
                Text("\(tasks.filter { $0.state == .open || $0.state == .inProgress }.count) open")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)

            if tasks.isEmpty {
                Text("No tasks yet. Add the first next action from this project's research.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            } else {
                ForEach(tasks) { task in
                    TaskRow(task: task, onToggle: { Task { await toggleTask(task) } }, onDelete: { Task { await deleteTask(task) } })
                }
            }

            if isAddingTask {
                newTaskForm
            } else {
                Button(action: { withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) { isAddingTask = true } }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle")
                            .font(HiveDesign.Typography.captionSemiBold)
                        Text("Add next action")
                            .font(HiveDesign.Typography.smallLabelMedium)
                    }
                    .foregroundStyle(HiveDesign.Accent.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add next action")
            }
        }
    }

    private var newTaskForm: some View {
        VStack(alignment: .leading, spacing: 7) {
            TextField("What needs to happen next?", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.sidebarItem)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onSubmit { Task { await createTask() } }
            HStack(spacing: 8) {
                Text("Priority")
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                Picker("", selection: $newTaskPriority) {
                    ForEach(HiveTask.Priority.allCases, id: \.self) { priority in
                        Text(priorityLabel(priority)).tag(priority)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 130)
                Spacer()
                Button("Cancel") {
                    withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) {
                        isAddingTask = false
                        newTaskTitle = ""
                    }
                }
                .buttonStyle(.borderless)
                .font(HiveDesign.Typography.smallLabel)
                Button("Add") { Task { await createTask() } }
                    .buttonStyle(.borderedProminent)
                    .tint(HiveDesign.Accent.primary)
                    .font(HiveDesign.Typography.sectionHeader)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func priorityLabel(_ priority: HiveTask.Priority) -> String {
        switch priority {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    // MARK: - Linked Sources

    private var linkedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(HiveDesign.Typography.captionSemiBold)
                    .foregroundStyle(HiveDesign.Accent.primary)
                Text("SOURCES")
                    .font(HiveDesign.Typography.microLabelBold)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 4)

            if linkedNodes.isEmpty {
                Text("No sources linked yet. Capture the current page into this project.")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            } else {
                ForEach(linkedNodes.prefix(20), id: \.id) { node in
                    LinkedNodeRow(node: node)
                }
            }

            // Capture current page into this project
            Button(action: { Task { await captureCurrentPage() } }) {
                HStack(spacing: 6) {
                    if isCapturingPage {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(HiveDesign.Typography.captionSemiBold)
                    }
                    Text("Capture current page into project")
                        .font(HiveDesign.Typography.smallLabelMedium)
                }
                .foregroundStyle(HiveDesign.Text.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .disabled(isCapturingPage)
            .accessibilityLabel(isCapturingPage ? "Capturing page" : "Capture current page into project")
        }
    }

    // MARK: - Task Actions

    private func createTask() async {
        guard !state.isKnowledgePersistenceDegraded else {
            detailError = "Task creation blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        do {
            let task = HiveTask(title: title, priority: newTaskPriority)
            try await state.honeycomb.createTask(task)
            _ = try await state.honeycomb.addTaskToProject(taskID: task.id, projectID: projectID)
            await MainActor.run {
                newTaskTitle = ""
                isAddingTask = false
                detailError = nil
            }
            await refresh()
        } catch {
            await MainActor.run {
                detailError = "Could not add task: \(error.localizedDescription)"
                state.reportKnowledgePersistenceFailure()
            }
        }
    }

    /// Toggles a task between done and open. The done-state button claims
    /// "Reopen", so the action must actually reopen — calling completeTask on
    /// an already-done task would be a lie (completeTask only sets .done).
    private func toggleTask(_ task: HiveTask) async {
        guard !state.isKnowledgePersistenceDegraded else {
            await MainActor.run { detailError = "Task update blocked: knowledge storage is unavailable. Restart Hive to restore it." }
            return
        }
        do {
            if task.state == .done {
                _ = try await state.honeycomb.updateTask(id: task.id, state: .open)
            } else {
                _ = try await state.honeycomb.completeTask(id: task.id)
            }
            await refresh()
        } catch {
            await MainActor.run {
                detailError = "Could not update task: \(error.localizedDescription)"
                state.reportKnowledgePersistenceFailure()
            }
        }
    }

    private func deleteTask(_ task: HiveTask) async {
        guard !state.isKnowledgePersistenceDegraded else {
            await MainActor.run { detailError = "Task deletion blocked: knowledge storage is unavailable. Restart Hive to restore it." }
            return
        }
        do {
            try await state.honeycomb.deleteTask(id: task.id)
            await refresh()
        } catch {
            await MainActor.run {
                detailError = "Could not delete task: \(error.localizedDescription)"
                state.reportKnowledgePersistenceFailure()
            }
        }
    }

    // MARK: - Capture

    private func captureCurrentPage() async {
        guard state.activePageContext != nil else {
            await MainActor.run { detailError = "Open a page first to capture it into this project." }
            return
        }
        await MainActor.run { isCapturingPage = true }
        do {
            let sourceID = try await state.captureCurrentPage()
            // Dedup: capturing the same page into the same project twice must
            // not create a second belongsTo edge (getProjectNodes would list
            // the source twice).
            let alreadyLinked = try await state.honeycomb.edgeExists(
                from: sourceID, to: projectID, relation: .belongsTo
            )
            if !alreadyLinked {
                _ = try await state.honeycomb.insertEdge(HoneycombStore.Edge(
                    sourceID: sourceID,
                    targetID: projectID,
                    relation: .belongsTo
                ))
            }
            await MainActor.run {
                isCapturingPage = false
                detailError = nil
            }
            await refresh()
        } catch {
            await MainActor.run {
                isCapturingPage = false
                detailError = "Capture failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        let p = try? await state.honeycomb.getProject(id: projectID)
        let t = try? await state.honeycomb.getProjectTasks(projectID: projectID)
        let nodes = try? await state.honeycomb.getProjectNodes(projectID: projectID)
        await MainActor.run {
            project = p
            tasks = t ?? []
            let sources = (nodes ?? []).filter { $0.type == .source || $0.type == .brief }
            linkedNodes = sources
        }
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: HiveTask
    var onToggle: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: task.state == .done ? "checkmark.circle.fill" : "circle")
                    .font(HiveDesign.Typography.body)
                    .foregroundStyle(task.state == .done ? HiveDesign.Accent.primary : HiveDesign.Text.tertiary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help(task.state == .done ? "Reopen" : "Mark done")
            .accessibilityLabel(task.state == .done ? "Reopen task" : "Mark task done")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(HiveDesign.Typography.smallLabelMedium)
                    .foregroundStyle(task.state == .done ? HiveDesign.Text.tertiary : HiveDesign.Text.primary)
                    .strikethrough(task.state == .done)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(priorityLabel(task.priority))
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(priorityColor(task.priority))
                    if let due = task.dueDate {
                        Text("·")
                            .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.4))
                        Text(due, style: .date)
                            .font(HiveDesign.Typography.microLabelSecondary)
                            .foregroundStyle(HiveDesign.Text.tertiary)
                    }
                }
            }
            Spacer(minLength: 4)
            if isHovered && task.state != .done {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Delete task")
                .accessibilityLabel("Delete task")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private func priorityLabel(_ priority: HiveTask.Priority) -> String {
        switch priority {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    private func priorityColor(_ priority: HiveTask.Priority) -> Color {
        switch priority {
        case .high: return .orange
        case .medium: return HiveDesign.Accent.primary
        case .low: return HiveDesign.Text.tertiary
        }
    }
}

// MARK: - Linked Node Row

private struct LinkedNodeRow: View {
    let node: HoneycombStore.Node

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: node.type == .brief ? "doc.plaintext" : "link")
                .font(HiveDesign.Typography.caption)
                .foregroundStyle(node.type == .brief ? .indigo : .blue)
                .frame(width: 14)
            Text(node.label.isEmpty ? "(untitled)" : node.label)
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(HiveDesign.Text.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(node.type.rawValue)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(HiveDesign.Text.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}
