import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - Sheets Panel

/// The Hive Sheets UI (SHEET-002): a real spreadsheet interface backed by the
/// verified SheetStore/HiveSheet data layer. Typed columns, cell editing, safe
/// deterministic formulas, CSV import/export, and source-provenance per row.
struct SheetsPanel: View {
    @Environment(BrowserState.self) var state
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var sheets: [HiveSheet] = []
    @State var selectedSheetID: String?
    @State var isCreatingSheet = false
    @State var newSheetTitle = ""
    @State var sheetError: String?
}

// MARK: - Sheet List Item

/// One row in the sheet list. Named `SheetListItem` (not `SheetRow`) so the
/// view never shadows `HiveCore.SheetRow`, the data model it displays.
struct SheetListItem: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let sheet: HiveSheet
    var onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(HiveDesign.Accent.primary.opacity(0.12))
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "tablecells")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(HiveDesign.Accent.primary)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(sheet.title)
                    .font(HiveDesign.Typography.sidebarItemMedium)
                    .foregroundStyle(HiveDesign.Text.primary)
                    .lineLimit(1)
                Text("\(sheet.columns.count) columns · \(sheet.rows.count) rows")
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(HiveDesign.Typography.microLabel)
                .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Open \(sheet.title)")
        .onTapGesture(perform: onOpen)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) { isHovered = hovering }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? HiveDesign.Surface.level1 : .clear)
        )
    }
}

// MARK: - Sheet Editor View

/// The full spreadsheet editor: a scrollable grid with inline cell editing,
/// column type headers, row numbers, formula bar, and toolbar for add/delete
/// column/row, sort, filter, and CSV export.
struct SheetEditorView: View {
    @Environment(BrowserState.self) var state

    let sheetID: String
    var onBack: () -> Void

    @State var sheet: HiveSheet?
    @State var editingCell: (row: Int, col: Int)?
    @State var editingText: String = ""
    @State var formulaBarText: String = ""
    @State var sortColumn: Int?
    @State var sortAscending: Bool = true
    @State var filterText: String = ""
    @State var editorError: String?
    @State var isAddingColumn = false
    @State var newColumnName = ""
}
