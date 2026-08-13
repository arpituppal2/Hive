//
//  ProjectDetailPanel+Core.swift
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

// MARK: - ProjectDetailPanel + Core

@MainActor
extension ProjectDetailPanel {


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
}
