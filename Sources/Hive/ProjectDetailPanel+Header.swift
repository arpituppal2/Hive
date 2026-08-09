//
//  ProjectDetailPanel+Header.swift
//  Hive
//
//  Carved out of ProjectsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Header
//

import SwiftUI
import HiveCore

// MARK: - ProjectDetailPanel + Header

@MainActor
extension ProjectDetailPanel {


    // MARK: - Header

    func projectHeader(_ project: Project) -> some View {
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
}
