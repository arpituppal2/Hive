//
//  ProjectDetailPanel+TaskActions.swift
//  Hive
//
//  Carved out of ProjectsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Task Actions
//

import SwiftUI
import HiveCore

// MARK: - ProjectDetailPanel + TaskActions

@MainActor
extension ProjectDetailPanel {


    // MARK: - Task Actions

    func createTask() async {
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
    func toggleTask(_ task: HiveTask) async {
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


    func deleteTask(_ task: HiveTask) async {
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
}
