//
//  SheetEditorView+Columns.swift
//  Hive
//
//  Carved out of SheetsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Column Operations | - Column Context Menu
//

import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - SheetEditorView + Columns

@MainActor
extension SheetEditorView {


    // MARK: - Column Operations

    func toggleSort(_ colIndex: Int) {
        if sortColumn == colIndex {
            sortAscending.toggle()
        } else {
            sortColumn = colIndex
            sortAscending = true
        }
    }


    func addColumn() {
        let name = newColumnName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, var sheet else { return }
        sheet.columns.append(SheetColumn(name: name))
        // Extend existing rows
        for i in sheet.rows.indices {
            sheet.rows[i].cells.append(.empty)
        }
        sheet.updatedAt = Date()
        guard !state.isKnowledgePersistenceDegraded else {
            editorError = "Save blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        Task {
            do {
                try await state.honeycomb.updateSheet(sheet)
                await MainActor.run {
                    self.sheet = sheet
                    isAddingColumn = false
                    newColumnName = ""
                    editorError = nil
                }
            } catch {
                await MainActor.run {
                    editorError = "Save failed: knowledge storage is unavailable. Restart Hive to restore it."
                    state.reportKnowledgePersistenceFailure()
                }
            }
        }
    }


    func deleteColumn(_ colIndex: Int) {
        guard var sheet, colIndex < sheet.columns.count else { return }
        sheet.columns.remove(at: colIndex)
        for i in sheet.rows.indices {
            if colIndex < sheet.rows[i].cells.count {
                sheet.rows[i].cells.remove(at: colIndex)
            }
        }
        sheet.updatedAt = Date()
        sortColumn = nil
        guard !state.isKnowledgePersistenceDegraded else {
            editorError = "Save blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        Task {
            do {
                try await state.honeycomb.updateSheet(sheet)
                await MainActor.run {
                    self.sheet = sheet
                    self.editorError = nil
                }
            } catch {
                await MainActor.run {
                    editorError = "Save failed: knowledge storage is unavailable. Restart Hive to restore it."
                    state.reportKnowledgePersistenceFailure()
                }
            }
        }
    }


    func addRow() {
        guard var sheet else { return }
        let emptyCells = Array(repeating: SheetCell.Value.empty, count: sheet.columns.count)
        sheet.rows.append(SheetRow(cells: emptyCells))
        sheet.updatedAt = Date()
        guard !state.isKnowledgePersistenceDegraded else {
            editorError = "Save blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        Task {
            do {
                try await state.honeycomb.updateSheet(sheet)
                await MainActor.run {
                    self.sheet = sheet
                    self.editorError = nil
                }
            } catch {
                await MainActor.run {
                    editorError = "Save failed: knowledge storage is unavailable. Restart Hive to restore it."
                    state.reportKnowledgePersistenceFailure()
                }
            }
        }
    }


    func deleteRow(_ rowIndex: Int) {
        guard var sheet, rowIndex < sheet.rows.count else { return }
        sheet.rows.remove(at: rowIndex)
        sheet.updatedAt = Date()
        guard !state.isKnowledgePersistenceDegraded else {
            editorError = "Save blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        Task {
            do {
                try await state.honeycomb.updateSheet(sheet)
                await MainActor.run {
                    self.sheet = sheet
                    self.editorError = nil
                }
            } catch {
                await MainActor.run {
                    editorError = "Save failed: knowledge storage is unavailable. Restart Hive to restore it."
                    state.reportKnowledgePersistenceFailure()
                }
            }
        }
    }


    // MARK: - Column Context Menu

    func columnContextMenu(_ colIndex: Int) -> some View {
        VStack {
            Button("Sort Ascending") { sortColumn = colIndex; sortAscending = true }
            Button("Sort Descending") { sortColumn = colIndex; sortAscending = false }
            Divider()
            Button("Delete Column", role: .destructive) { deleteColumn(colIndex) }
        }
    }
}
