//
//  ProjectDetailPanel+Refresh.swift
//  Hive
//
//  Carved out of ProjectsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Refresh
//

import SwiftUI
import HiveCore

// MARK: - ProjectDetailPanel + Refresh

@MainActor
extension ProjectDetailPanel {


    // MARK: - Refresh

    func refresh() async {
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
