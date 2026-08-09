//
//  SheetEditorView+Grid.swift
//  Hive
//
//  Carved out of SheetsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Grid
//

import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - SheetEditorView + Grid

@MainActor
extension SheetEditorView {


    // MARK: - Grid

    var gridArea: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // Column headers
                headerRow
                // Data rows. `id: \.offset` is unique per display position;
                // the closure destructures the enumerated tuple directly
                // (tuple members can't be keypath-addressed).
                ForEach(Array(displayedRows.enumerated()), id: \.offset) { displayIndex, entry in
                    dataRow(displayIndex: displayIndex, originalIndex: entry.originalIndex, row: entry.row)
                }
            }
        }
        .background(HiveDesign.Surface.canvas)
    }


    var headerRow: some View {
        HStack(spacing: 0) {
            // Row number header — clicking it adds a row at the bottom.
            Button(action: addRow) {
                Image(systemName: "plus")
                    .font(HiveDesign.Typography.microLabelBold)
                    .foregroundStyle(HiveDesign.Text.tertiary)
            }
            .buttonStyle(.plain)
            .help("Add row")
            .accessibilityLabel("Add row")
            .frame(width: 36, height: 26)
            .background(HiveDesign.Surface.level1)

            // Column headers
            if let sheet {
                ForEach(Array(sheet.columns.enumerated()), id: \.element.id) { colIndex, col in
                    Button(action: { toggleSort(colIndex) }) {
                        HStack(spacing: 3) {
                            Text(col.name)
                                .font(HiveDesign.Typography.captionSemiBold)
                                .foregroundStyle(HiveDesign.Text.primary)
                            // Type badge
                            Text(col.kind.rawValue.uppercased())
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.6))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(HiveDesign.Surface.level2)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            // Sort indicator
                            if sortColumn == colIndex {
                                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(HiveDesign.Accent.primary)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sort by column \(col.name)")
                    .frame(width: columnWidth(col), height: 26, alignment: .leading)
                    .background(HiveDesign.Surface.level1)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(HiveDesign.Surface.hairline).frame(width: 0.5)
                    }
                    .contextMenu {
                        columnContextMenu(colIndex)
                    }
                }
            }
        }
        .background(HiveDesign.Surface.level1)
    }


    func dataRow(displayIndex: Int, originalIndex: Int, row: SheetRow) -> some View {
        HStack(spacing: 0) {
            // Row number — right-click to delete this row.
            Text("\(originalIndex + 1)")
                .font(HiveDesign.Typography.monoMicroMedium)
                .foregroundStyle(HiveDesign.Text.tertiary)
                .frame(width: 36, height: 26)
                .background(HiveDesign.Surface.level1.opacity(0.5))
                .overlay(alignment: .trailing) {
                    Rectangle().fill(HiveDesign.Surface.hairline).frame(width: 0.5)
                }
                .contextMenu {
                    Button("Delete Row \(originalIndex + 1)", role: .destructive) {
                        deleteRow(originalIndex)
                    }
                }

            if let sheet {
                ForEach(Array(sheet.columns.enumerated()), id: \.element.id) { colIndex, col in
                    cellView(row: originalIndex, col: colIndex, cell: colIndex < row.cells.count ? row.cells[colIndex] : .empty, column: col)
                        .frame(width: columnWidth(col), height: 26, alignment: .leading)
                }
            }
        }
        .background(displayIndex % 2 == 0 ? Color.clear : HiveDesign.Surface.canvas.opacity(0.3))
        .overlay(alignment: .bottom) {
            Rectangle().fill(HiveDesign.Surface.hairline.opacity(0.3)).frame(height: 0.5)
        }
    }


    @ViewBuilder
    func cellView(row: Int, col: Int, cell: SheetCell.Value, column: SheetColumn) -> some View {
        let isEditing = editingCell?.row == row && editingCell?.col == col

        if isEditing {
            TextField("", text: $editingText)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: column.kind == .number ? .monospaced : .default))
                .foregroundStyle(HiveDesign.Text.primary)
                .padding(.horizontal, 6)
                .background(HiveDesign.Accent.muted)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(HiveDesign.Accent.primary, lineWidth: 1.5)
                )
                .onSubmit { commitEdit() }
                .onExitCommand { cancelEdit() }
                // Keep the formula bar in sync so commitEdit() (which reads
                // formulaBarText) never loses inline edits.
                .onChange(of: editingText) { _, newValue in
                    formulaBarText = newValue
                }
        } else {
            let displayValue = evaluateDisplayText(cell)
            Text(displayValue)
                .font(.system(size: 11, design: column.kind == .number ? .monospaced : .default))
                .foregroundStyle(cellTextColor(cell))
                .padding(.horizontal, 6)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectCell(row: row, col: col, cell: cell)
                }

        }
    }
}
