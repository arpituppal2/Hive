//
//  ProjectsPanel+Core.swift
//  Hive
//
//  Carved out of ProjectsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: 
//

import SwiftUI
import HiveCore

// MARK: - ProjectsPanel + Core

@MainActor
extension ProjectsPanel {


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
}
