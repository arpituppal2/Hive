//
//  SheetEditorView+Cell.swift
//  Hive
//
//  Carved out of SheetsPanelView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Cell Helpers | - Cell Interaction
//

import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - SheetEditorView + Cell

@MainActor
extension SheetEditorView {


    // MARK: - Cell Helpers

    /// Human-readable formula error label (user-visible, so not raw debug
    /// descriptions).
    func formulaErrorLabel(_ error: SheetFormula.EvalError) -> String {
        switch error {
        case .parse(let detail): return "PARSE(\(detail))"
        case .unknownCell(let ref): return "UNKNOWN_CELL(\(ref))"
        case .unknownFunction(let name): return "UNKNOWN_FN(\(name))"
        case .divisionByZero: return "DIV/0!"
        case .emptyAggregate: return "EMPTY_RANGE"
        }
    }


    func columnWidth(_ col: SheetColumn) -> CGFloat {
        switch col.kind {
        case .bool: return 60
        case .number: return 100
        case .date: return 110
        case .text: return 140
        }
    }


    func evaluateDisplayText(_ cell: SheetCell.Value) -> String {
        switch cell {
        case .formula(let formula):
            guard let sheet else { return formula }
            let result = SheetFormula.evaluate(formula) { ref in
                resolveCellNumeric(ref, in: sheet)
            }
            switch result {
            case .success(let value):
                if value == value.rounded() && value.magnitude < 1e15 {
                    return String(Int64(value))
                }
                return String(value)
            case .failure(let error):
                return "#" + formulaErrorLabel(error)
            }
        default:
            return cell.displayText
        }
    }


    /// Resolves an A1 reference to a numeric value, following formula cells
    /// with a depth cap so a self-referential formula (=A1 in A1) or a cycle
    /// (A1=B1, B1=A1) terminates instead of recursing forever.
    func resolveCellNumeric(_ ref: String, in sheet: HiveSheet, depth: Int = 0) -> Double? {
        guard depth < 16 else { return nil }
        guard let indices = SheetFormula.cellIndices(ref) else { return nil }
        guard indices.row >= 0, indices.row < sheet.rows.count,
              indices.col >= 0, indices.col < sheet.columns.count else { return nil }
        let row = sheet.rows[indices.row]
        guard indices.col < row.cells.count else { return nil }
        let cell = row.cells[indices.col]
        switch cell {
        case .number(let d): return d
        case .text(let s): return Double(s)
        case .bool(let b): return b ? 1.0 : 0.0
        case .formula(let f):
            let inner = SheetFormula.evaluate(f) { resolveCellNumeric($0, in: sheet, depth: depth + 1) }
            if case .success(let v) = inner { return v }
            return nil
        case .empty: return nil
        }
    }


    func cellTextColor(_ cell: SheetCell.Value) -> Color {
        switch cell {
        case .number: return HiveDesign.Text.primary
        case .bool: return HiveDesign.Accent.primary
        case .formula: return .indigo
        case .text: return HiveDesign.Text.primary
        case .empty: return HiveDesign.Text.tertiary
        }
    }


    func compareCellValues(_ a: SheetCell.Value, _ b: SheetCell.Value, kind: SheetColumn.Kind) -> Bool {
        switch kind {
        case .number:
            let numA = extractNumber(a) ?? .greatestFiniteMagnitude
            let numB = extractNumber(b) ?? .greatestFiniteMagnitude
            return numA < numB
        case .bool:
            let boolA = extractBool(a) ?? false
            let boolB = extractBool(b) ?? false
            return (!boolA && boolB) // false < true
        default:
            return a.displayText.localizedCaseInsensitiveCompare(b.displayText) == .orderedAscending
        }
    }


    func extractNumber(_ cell: SheetCell.Value) -> Double? {
        switch cell {
        case .number(let d): return d
        case .text(let s): return Double(s)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }


    func extractBool(_ cell: SheetCell.Value) -> Bool? {
        switch cell {
        case .bool(let b): return b
        case .text(let s):
            let lower = s.lowercased()
            if lower == "true" || lower == "yes" || lower == "1" { return true }
            if lower == "false" || lower == "no" || lower == "0" { return false }
            return nil
        default: return nil
        }
    }


    // MARK: - Cell Interaction

    /// Single-click selects: the cell becomes the editing target with its
    /// value shown in the inline editor (select-to-type-replace behavior).
    /// editingText is set alongside editingCell so the inline TextField (which
    /// keys off editingCell) never appears empty after a single click.
    func selectCell(row: Int, col: Int, cell: SheetCell.Value) {
        editingCell = (row, col)
        editingText = cell.displayText
        formulaBarText = cell.displayText
    }


    func commitEdit() {
        guard !state.isKnowledgePersistenceDegraded else {
            editorError = "Save blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        guard let editing = editingCell, var sheet else { return }
        let value = formulaBarText.trimmingCharacters(in: .whitespaces)
        let cellValue: SheetCell.Value
        if value.isEmpty {
            cellValue = .empty
        } else if value.hasPrefix("=") {
            cellValue = .formula(value)
        } else if let num = Double(value) {
            cellValue = .number(num)
        } else if value.lowercased() == "true" || value.lowercased() == "false" {
            cellValue = .bool(value.lowercased() == "true")
        } else {
            cellValue = .text(value)
        }

        // Ensure rows/columns exist
        while sheet.rows.count <= editing.row {
            let emptyCells = Array(repeating: SheetCell.Value.empty, count: sheet.columns.count)
            sheet.rows.append(SheetRow(cells: emptyCells))
        }
        var row = sheet.rows[editing.row]
        while row.cells.count <= editing.col {
            row.cells.append(.empty)
        }
        row.cells[editing.col] = cellValue
        sheet.rows[editing.row] = row
        sheet.updatedAt = Date()

        Task {
            do {
                try await state.honeycomb.updateSheet(sheet)
                await MainActor.run {
                    self.sheet = sheet
                    self.editingCell = nil
                    self.editorError = nil
                    // Clear the committed text so the formula bar returns to
                    // its neutral "Select a cell to edit" state (consistent
                    // with cancelEdit's clearing behavior).
                    self.formulaBarText = ""
                }
            } catch {
                await MainActor.run {
                    editorError = "Save failed: knowledge storage is unavailable. Restart Hive to restore it."
                    state.reportKnowledgePersistenceFailure()
                }
            }
        }
    }


    func cancelEdit() {
        editingCell = nil
        editingText = ""
        formulaBarText = ""
    }
}
