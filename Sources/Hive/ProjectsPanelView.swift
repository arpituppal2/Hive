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
    @Environment(BrowserState.self) var state
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var projects: [Project] = []
    @State var selectedProjectID: String?
    @State var isCreatingProject = false
    @State var newProjectTitle = ""
    @State var newProjectPurpose = ""
    @State var projectError: String?
}

// MARK: - Project Row

struct ProjectRow: View {
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

struct ProjectDetailPanel: View {
    @Environment(BrowserState.self) var state
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let projectID: String
    var onBack: () -> Void

    @State var project: Project?
    @State var tasks: [HiveTask] = []
    @State var linkedNodes: [HoneycombStore.Node] = []
    @State var isAddingTask = false
    @State var newTaskTitle = ""
    @State var newTaskPriority: HiveTask.Priority = .medium
    @State var isCapturingPage = false
    @State var detailError: String?
}

// MARK: - Task Row

struct TaskRow: View {
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

struct LinkedNodeRow: View {
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
