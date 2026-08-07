import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - Sheets Panel

/// The Hive Sheets UI (SHEET-002): a real spreadsheet interface backed by the
/// verified SheetStore/HiveSheet data layer. Typed columns, cell editing, safe
/// deterministic formulas, CSV import/export, and source-provenance per row.
struct SheetsPanel: View {
    @Environment(ChromiumBrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sheets: [HiveSheet] = []
    @State private var selectedSheetID: String?
    @State private var isCreatingSheet = false
    @State private var newSheetTitle = ""
    @State private var sheetError: String?

    var body: some View {
        VStack(spacing: 0) {
            if let selectedSheetID {
                SheetEditorView(
                    sheetID: selectedSheetID,
                    onBack: { self.selectedSheetID = nil }
                )
            } else {
                sheetListView
            }
        }
        .task { await refresh() }
    }

    // MARK: - Sheet List

    private var sheetListView: some View {
        VStack(spacing: 0) {
            headerBar
            if isCreatingSheet { newSheetForm }
            if let error = sheetError {
                Text(error)
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if sheets.isEmpty && !isCreatingSheet {
                        emptyState
                    } else {
                        ForEach(sheets) { sheet in
                            SheetListItem(sheet: sheet) {
                                withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) {
                                    selectedSheetID = sheet.id
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "tablecells")
                .font(HiveDesign.Typography.sidebarItemSemiBold)
                .foregroundStyle(HiveDesign.Accent.primary)
            Text("Sheets")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(HiveDesign.Text.primary)
            Spacer()
            // Import CSV button
            Button(action: { importCSV() }) {
                Image(systemName: "square.and.arrow.down")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(HiveDesign.Text.tertiary)
                    .frame(width: 20, height: 20)
                    .background(HiveDesign.Surface.level2)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Import CSV")
            .accessibilityLabel("Import CSV")
            // Create new sheet
            Button(action: { withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) { isCreatingSheet.toggle() } }) {
                Image(systemName: isCreatingSheet ? "xmark" : "plus")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(HiveDesign.Accent.primary)
                    .frame(width: 20, height: 20)
                    .background(HiveDesign.Surface.level2)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help(isCreatingSheet ? "Cancel" : "New sheet")
            .accessibilityLabel(isCreatingSheet ? "Cancel new sheet" : "Create new sheet")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var newSheetForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Sheet title", text: $newSheetTitle)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.sidebarItemMedium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onSubmit { Task { await createSheet() } }
            HStack {
                Spacer()
                Button("Create") { Task { await createSheet() } }
                    .buttonStyle(.borderedProminent)
                    .tint(HiveDesign.Accent.primary)
                    .font(HiveDesign.Typography.sectionHeader)
                    .disabled(newSheetTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.5))
            Text("No sheets yet")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(HiveDesign.Text.secondary)
            Text("Create a sheet or import CSV to organize data with formulas and source provenance.")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(HiveDesign.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Actions

    private func createSheet() async {
        guard !state.isKnowledgePersistenceDegraded else {
            sheetError = "Sheet creation blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        let title = newSheetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        do {
            let sheet = HiveSheet(
                title: title,
                columns: [
                    SheetColumn(name: "A", kind: .text),
                    SheetColumn(name: "B", kind: .text),
                    SheetColumn(name: "C", kind: .text)
                ]
            )
            try await state.honeycomb.createSheet(sheet)
            await MainActor.run {
                newSheetTitle = ""
                isCreatingSheet = false
                sheetError = nil
            }
            await refresh()
        } catch {
            await MainActor.run {
                sheetError = "Could not create sheet: \(error.localizedDescription)"
                state.reportKnowledgePersistenceFailure()
            }
        }
    }

    private func importCSV() {
        guard !state.isKnowledgePersistenceDegraded else {
            sheetError = "CSV import blocked: knowledge storage is unavailable. Restart Hive to restore it."
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Import a CSV file into a new sheet"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let csv = try String(contentsOf: url, encoding: .utf8)
                let name = url.deletingPathExtension().lastPathComponent
                let sheet = HiveSheet.importCSV(csv, title: name)
                try await state.honeycomb.createSheet(sheet)
                await refresh()
            } catch {
                await MainActor.run {
                    sheetError = "Import failed: \(error.localizedDescription)"
                    state.reportKnowledgePersistenceFailure()
                }
            }
        }
    }

    private func refresh() async {
        if let list = try? await state.honeycomb.getAllSheets() {
            await MainActor.run { sheets = list }
        }
    }
}

// MARK: - Sheet List Item

/// One row in the sheet list. Named `SheetListItem` (not `SheetRow`) so the
/// view never shadows `HiveCore.SheetRow`, the data model it displays.
private struct SheetListItem: View {
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
    @Environment(ChromiumBrowserState.self) private var state

    let sheetID: String
    var onBack: () -> Void

    @State private var sheet: HiveSheet?
    @State private var editingCell: (row: Int, col: Int)?
    @State private var editingText: String = ""
    @State private var formulaBarText: String = ""
    @State private var sortColumn: Int?
    @State private var sortAscending: Bool = true
    @State private var filterText: String = ""
    @State private var editorError: String?
    @State private var isAddingColumn = false
    @State private var newColumnName = ""

    /// Displayed rows after filter/sort are applied.
    private var displayedRows: [(originalIndex: Int, row: SheetRow)] {
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

    // MARK: - Toolbar

    private var editorToolbar: some View {
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

    // MARK: - Formula Bar

    private var formulaBar: some View {
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

    // MARK: - Grid

    private var gridArea: some View {
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

    private var headerRow: some View {
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

    private func dataRow(displayIndex: Int, originalIndex: Int, row: SheetRow) -> some View {
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
    private func cellView(row: Int, col: Int, cell: SheetCell.Value, column: SheetColumn) -> some View {
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

    // MARK: - Cell Helpers

    /// Human-readable formula error label (user-visible, so not raw debug
    /// descriptions).
    private func formulaErrorLabel(_ error: SheetFormula.EvalError) -> String {
        switch error {
        case .parse(let detail): return "PARSE(\(detail))"
        case .unknownCell(let ref): return "UNKNOWN_CELL(\(ref))"
        case .unknownFunction(let name): return "UNKNOWN_FN(\(name))"
        case .divisionByZero: return "DIV/0!"
        case .emptyAggregate: return "EMPTY_RANGE"
        }
    }

    private func columnWidth(_ col: SheetColumn) -> CGFloat {
        switch col.kind {
        case .bool: return 60
        case .number: return 100
        case .date: return 110
        case .text: return 140
        }
    }

    private func evaluateDisplayText(_ cell: SheetCell.Value) -> String {
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
    private func resolveCellNumeric(_ ref: String, in sheet: HiveSheet, depth: Int = 0) -> Double? {
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

    private func cellTextColor(_ cell: SheetCell.Value) -> Color {
        switch cell {
        case .number: return HiveDesign.Text.primary
        case .bool: return HiveDesign.Accent.primary
        case .formula: return .indigo
        case .text: return HiveDesign.Text.primary
        case .empty: return HiveDesign.Text.tertiary
        }
    }

    private func compareCellValues(_ a: SheetCell.Value, _ b: SheetCell.Value, kind: SheetColumn.Kind) -> Bool {
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

    private func extractNumber(_ cell: SheetCell.Value) -> Double? {
        switch cell {
        case .number(let d): return d
        case .text(let s): return Double(s)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    private func extractBool(_ cell: SheetCell.Value) -> Bool? {
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
    private func selectCell(row: Int, col: Int, cell: SheetCell.Value) {
        editingCell = (row, col)
        editingText = cell.displayText
        formulaBarText = cell.displayText
    }

    private func commitEdit() {
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

    private func cancelEdit() {
        editingCell = nil
        editingText = ""
        formulaBarText = ""
    }

    // MARK: - Column Operations

    private func toggleSort(_ colIndex: Int) {
        if sortColumn == colIndex {
            sortAscending.toggle()
        } else {
            sortColumn = colIndex
            sortAscending = true
        }
    }

    private func addColumn() {
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

    private func deleteColumn(_ colIndex: Int) {
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

    private func addRow() {
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

    private func deleteRow(_ rowIndex: Int) {
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

    // MARK: - CSV Export

    private func exportCSV() {
        guard let sheet else { return }
        let csv = sheet.exportCSV()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(sheet.title).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            editorError = "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Column Context Menu

    private func columnContextMenu(_ colIndex: Int) -> some View {
        VStack {
            Button("Sort Ascending") { sortColumn = colIndex; sortAscending = true }
            Button("Sort Descending") { sortColumn = colIndex; sortAscending = false }
            Divider()
            Button("Delete Column", role: .destructive) { deleteColumn(colIndex) }
        }
    }

    // MARK: - Load

    private func loadSheet() async {
        if let loaded = try? await state.honeycomb.getSheet(id: sheetID) {
            await MainActor.run { self.sheet = loaded }
        }
    }
}
