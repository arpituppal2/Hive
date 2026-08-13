//
//  ProjectDetailPanel+Tasks.swift
//  Hive
//
//  Carved out of ProjectsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Tasks
//

import SwiftUI
import HiveCore

// MARK: - ProjectDetailPanel + Tasks

@MainActor
extension ProjectDetailPanel {


    // MARK: - Tasks

    var taskSection: some View {
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


    var newTaskForm: some View {
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


    func priorityLabel(_ priority: HiveTask.Priority) -> String {
        switch priority {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}
