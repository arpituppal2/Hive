//
//  SheetEditorView+Core.swift
//  Hive
//
//  Carved out of SheetsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: 
//

import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - SheetEditorView + Core

@MainActor
extension SheetEditorView {


    /// Displayed rows after filter/sort are applied.
    var displayedRows: [(originalIndex: Int, row: SheetRow)] {
        guard let sheet else { return [] }
        var indexed = sheet.rows.enumerated().map { (originalIndex: $0.offset, row: $0.element) }

        // Filter
        if !filterText.isEmpty {
            let query = filterText.lowercased()
            indexed = indexed.filter { entry in
                entry.row.cells.contains { cell in
                    cell.displayText.lowercased().contains(query)
                }
            }
        }

        // Sort
        if let sortCol = sortColumn, sortCol < sheet.columns.count {
            indexed.sort { a, b in
                let valA = a.row.cells.indices.contains(sortCol) ? a.row.cells[sortCol] : .empty
                let valB = b.row.cells.indices.contains(sortCol) ? b.row.cells[sortCol] : .empty
                let cmp = compareCellValues(valA, valB, kind: sheet.columns[sortCol].kind)
                return sortAscending ? cmp : !cmp
            }
        }

        return indexed
    }


    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            formulaBar
            Divider()
            gridArea
        }
        .task { await loadSheet() }
    }
}
