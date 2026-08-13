//
//  ProjectsPanel+List.swift
//  Hive
//
//  Carved out of ProjectsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Project List
//

import SwiftUI
import HiveCore

// MARK: - ProjectsPanel + List

@MainActor
extension ProjectsPanel {


    // MARK: - Project List

    var projectListView: some View {
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


    var newProjectForm: some View {
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


    var emptyProjectsState: some View {
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
}
