//
//  ProjectDetailPanel+LinkedSources.swift
//  Hive
//
//  Carved out of ProjectsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Linked Sources
//

import SwiftUI
import HiveCore

// MARK: - ProjectDetailPanel + LinkedSources

@MainActor
extension ProjectDetailPanel {


    // MARK: - Linked Sources

    var linkedSection: some View {
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
}
