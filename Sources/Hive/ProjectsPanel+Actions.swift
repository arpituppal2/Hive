//
//  ProjectsPanel+Actions.swift
//  Hive
//
//  Carved out of ProjectsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Actions
//

import SwiftUI
import HiveCore

// MARK: - ProjectsPanel + Actions

@MainActor
extension ProjectsPanel {


    // MARK: - Actions

    func createProject() async {
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


    func refresh() async {
        if let list = try? await state.honeycomb.getAllProjects() {
            await MainActor.run { projects = list }
        }
    }
}
