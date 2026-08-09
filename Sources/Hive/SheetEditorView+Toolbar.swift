//
//  SheetEditorView+Toolbar.swift
//  Hive
//
//  Carved out of SheetsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Toolbar
//

import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - SheetEditorView + Toolbar

@MainActor
extension SheetEditorView {


    // MARK: - Toolbar

    var editorToolbar: some View {
        HStack(spacing: 6) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(HiveDesign.Typography.captionBold)
                    Text("Sheets")
                        .font(HiveDesign.Typography.smallLabelMedium)
                }
                .foregroundStyle(HiveDesign.Text.secondary)
            }
            .buttonStyle(.plain)

            if let sheet {
                Text(sheet.title)
                    .font(HiveDesign.Typography.sidebarItemBold)
                    .foregroundStyle(HiveDesign.Text.primary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
            }

            Spacer()

            // Filter field
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(HiveDesign.Typography.microLabel)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                TextField("Filter", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.caption)
                    .frame(width: 90)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(HiveDesign.Surface.level2)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            // Column count badge
            if let sheet {
                Text("\(sheet.columns.count) cols · \(sheet.rows.count) rows")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(HiveDesign.Text.tertiary)
            }

            // Add column
            if isAddingColumn {
                HStack(spacing: 4) {
                    TextField("Column name", text: $newColumnName)
                        .textFieldStyle(.plain)
                        .font(HiveDesign.Typography.caption)
                        .frame(width: 60)
                        .onSubmit { addColumn() }
                    Button(action: addColumn) {
                        Image(systemName: "checkmark")
                            .font(HiveDesign.Typography.microLabelBold)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Confirm add column")
                    Button(action: { isAddingColumn = false; newColumnName = "" }) {
                        Image(systemName: "xmark")
                            .font(HiveDesign.Typography.microLabelBold)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel add column")
                }
            } else {
                Button(action: { isAddingColumn = true }) {
                    Image(systemName: "plus")
                        .font(HiveDesign.Typography.captionSemiBold)
                }
                .buttonStyle(.plain)
                .help("Add column")
                .accessibilityLabel("Add column")
            }

            // Export CSV
            Button(action: exportCSV) {
                Image(systemName: "square.and.arrow.up")
                    .font(HiveDesign.Typography.captionSemiBold)
            }
            .buttonStyle(.plain)
            .help("Export CSV")
            .accessibilityLabel("Export sheet as CSV")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
