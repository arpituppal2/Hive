//
//  SheetEditorView+Formula.swift
//  Hive
//
//  Carved out of SheetsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Formula Bar
//

import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - SheetEditorView + Formula

@MainActor
extension SheetEditorView {


    // MARK: - Formula Bar

    var formulaBar: some View {
        HStack(spacing: 6) {
            // Cell reference
            if let editing = editingCell, sheet != nil {
                let ref = SheetFormula.refString(col: editing.col, row: editing.row)
                Text(ref)
                    .font(HiveDesign.Typography.monoCaptionBold)
                    .foregroundStyle(HiveDesign.Accent.primary)
                    .frame(width: 40)
            } else {
                Text("—")
                    .font(HiveDesign.Typography.monoCaptionBold)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                    .frame(width: 40)
            }

            Divider().frame(height: 16)

            // Formula / value input
            TextField("Select a cell to edit", text: $formulaBarText)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.monoSmall)
                .foregroundStyle(HiveDesign.Text.primary)
                .onSubmit { commitEdit() }

            if let error = editorError {
                Text(error)
                    .font(HiveDesign.Typography.microLabelSecondary)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(HiveDesign.Surface.level1)
    }
}
