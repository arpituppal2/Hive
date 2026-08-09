import Foundation
import Testing
@testable import HiveCore

// MARK: - HiveSheet

@Suite("HiveSheet")
struct HiveSheetTests {

    /// A small sales-like sheet with a numeric column for formula tests.
    private func sampleSheet() -> HiveSheet {
        HiveSheet(
            title: "Q3 Sales",
            columns: [
                SheetColumn(name: "Region", kind: .text),
                SheetColumn(name: "Amount", kind: .number)
            ],
            rows: [
                SheetRow(cells: [.text("North"), .number(10)]),
                SheetRow(cells: [.text("South"), .number(20)]),
                SheetRow(cells: [.text("East"), .number(30)])
            ],
            provenance: "test"
        )
    }

    // MARK: - Node Round-Trip

    @Test func nodeRoundTripPreservesSheet() throws {
        let sheet = sampleSheet()
        let node = sheet.toNode()
        #expect(node.type == .artifact)
        let restored = HiveSheet.from(node)
        #expect(restored == sheet)
    }

    @Test func fromRejectsNonArtifactNode() throws {
        let sheet = sampleSheet()
        var node = sheet.toNode()
        node = HoneycombStore.Node(
            id: node.id,
            type: .brief,
            label: node.label,
            metadata: node.metadata
        )
        #expect(HiveSheet.from(node) == nil)
    }

    // MARK: - Formula Evaluator

    @Test func formulaArithmetic() throws {
        let grid: (String) -> Double? = { _ in nil }
        #expect(try SheetFormula.evaluate("=1+2*3", resolveCell: grid).get() == 7)
        #expect(try SheetFormula.evaluate("=(1+2)*3", resolveCell: grid).get() == 9)
        #expect(try SheetFormula.evaluate("=10/4", resolveCell: grid).get() == 2.5)
        #expect(try SheetFormula.evaluate("=-5+1", resolveCell: grid).get() == -4)
    }

    @Test func formulaDivisionByZero() throws {
        let grid: (String) -> Double? = { _ in nil }
        #expect(SheetFormula.evaluate("=1/0", resolveCell: grid) == .failure(.divisionByZero))
    }

    @Test func formulaCellReferences() throws {
        // A1 = 10, B1 = 20, C1 empty
        let grid: (String) -> Double? = { ref in
            switch ref {
            case "A1": return 10
            case "B1": return 20
            default: return nil
            }
        }
        #expect(try SheetFormula.evaluate("=A1+B1", resolveCell: grid).get() == 30)
        #expect(try SheetFormula.evaluate("=A1*B1", resolveCell: grid).get() == 200)
    }

    @Test func formulaUnknownCell() throws {
        let grid: (String) -> Double? = { _ in nil }
        #expect(SheetFormula.evaluate("=ZZ99+1", resolveCell: grid) == .failure(.unknownCell("ZZ99")))
    }

    @Test func formulaAggregates() throws {
        let grid: (String) -> Double? = { ref in
            switch ref {
            case "B1": return 10
            case "B2": return 20
            case "B3": return 30
            case "B4": return 40
            default: return nil
            }
        }
        #expect(try SheetFormula.evaluate("=SUM(B1:B4)", resolveCell: grid).get() == 100)
        #expect(try SheetFormula.evaluate("=AVERAGE(B1:B4)", resolveCell: grid).get() == 25)
        #expect(try SheetFormula.evaluate("=MIN(B1:B4)", resolveCell: grid).get() == 10)
        #expect(try SheetFormula.evaluate("=MAX(B1:B4)", resolveCell: grid).get() == 40)
        #expect(try SheetFormula.evaluate("=COUNT(B1:B4)", resolveCell: grid).get() == 4)
    }

    @Test func formulaAggregateOverEmptyRange() throws {
        let grid: (String) -> Double? = { _ in nil }
        #expect(SheetFormula.evaluate("=AVERAGE(B1:B4)", resolveCell: grid) == .failure(.emptyAggregate))
        #expect(try SheetFormula.evaluate("=SUM(B1:B4)", resolveCell: grid).get() == 0)
    }

    @Test func formulaCellReferenceHelpers() {
        #expect(SheetFormula.cellIndices("A1")?.col == 0)
        #expect(SheetFormula.cellIndices("A1")?.row == 0)
        #expect(SheetFormula.cellIndices("B2")?.col == 1)
        #expect(SheetFormula.cellIndices("AB12")?.col == 27)
        #expect(SheetFormula.cellIndices("AB12")?.row == 11)
        #expect(SheetFormula.refString(col: 0, row: 0) == "A1")
        #expect(SheetFormula.refString(col: 27, row: 11) == "AB12")
        #expect(SheetFormula.cellIndices("12A") == nil)
    }

    @Test func formulaParseErrors() throws {
        let grid: (String) -> Double? = { _ in nil }
        #expect(SheetFormula.evaluate("=1+", resolveCell: grid) == .failure(.parse("unexpected end")))
        #expect(SheetFormula.evaluate("=BOGUS(A1)", resolveCell: grid) == .failure(.unknownFunction("BOGUS")))
        #expect(SheetFormula.evaluate("=1 2", resolveCell: grid) == .failure(.parse("trailing tokens")))
    }

    @Test func formulaVersionConstant() throws {
        // §7.7 audit contract: the supported subset is versioned.
        #expect(SheetFormula.version >= 1)
        #expect(try SheetFormula.evaluate("=SUM(A1:A2)", resolveCell: { _ in nil }).get() == 0)
    }

    @Test func numberDisplayTextNeverTrapsOnHugeValues() {
        // Int(d) would trap for values beyond Int64 — displayText must not crash.
        let huge = SheetCell.Value.number(1e19)
        #expect(huge.displayText == "1e+19")
        #expect(SheetCell.Value.number(42).displayText == "42")
        #expect(SheetCell.Value.number(2.5).displayText == "2.5")
    }

    // MARK: - §7.7 Audit Contract

    @Test func sheetFormulaVersionRoundTripsThroughStore() async throws {
        let store = try HoneycombStore(path: ":memory:")
        var sheet = sampleSheet()
        sheet.formulaVersion = 3
        _ = try await store.createSheet(sheet)
        let fetched = try await store.getSheet(id: sheet.id)
        #expect(fetched?.formulaVersion == 3)
    }

    @Test func storeBumpsFormulaVersionOnContentChange() async throws {
        let store = try HoneycombStore(path: ":memory:")
        let sheet = sampleSheet()
        _ = try await store.createSheet(sheet)
        #expect(try await store.getSheet(id: sheet.id)?.formulaVersion == SheetFormula.version)

        var updated = sheet
        updated.rows.append(SheetRow(cells: [.text("West"), .number(40)]))
        _ = try await store.updateSheet(updated)
        #expect(try await store.getSheet(id: sheet.id)?.formulaVersion == SheetFormula.version + 1)

        // A no-op write (same content) must NOT advance the audit version.
        _ = try await store.updateSheet(updated)
        #expect(try await store.getSheet(id: sheet.id)?.formulaVersion == SheetFormula.version + 1)
    }

    @Test func formulaResultIsDeterministic() throws {
        // Same inputs, same output — the evaluator is a pure function.
        let grid: (String) -> Double? = { ref in ref == "A1" ? 0.1 : nil }
        let first = try SheetFormula.evaluate("=A1+0.2", resolveCell: grid).get()
        let second = try SheetFormula.evaluate("=A1+0.2", resolveCell: grid).get()
        #expect(first == second)
    }

    // MARK: - CSV

    @Test func csvRoundTripPreservesValues() {
        let sheet = sampleSheet()
        let csv = sheet.exportCSV()
        #expect(csv.hasPrefix("Region,Amount"))
        let imported = HiveSheet.importCSV(csv, title: "Imported")
        #expect(imported.columns.count == 2)
        #expect(imported.rows.count == 3)
        #expect(imported.rows[0].cells[0] == .text("North"))
        #expect(imported.rows[2].cells[1] == .text("30"))
    }

    @Test func csvEscapesQuotedFields() {
        let sheet = HiveSheet(
            title: "Quoted",
            columns: [SheetColumn(name: "Note")],
            rows: [SheetRow(cells: [.text("Hello, \"world\"")])]
        )
        let csv = sheet.exportCSV()
        #expect(csv.contains("\"Hello, \"\"world\"\"\""))
        let imported = HiveSheet.importCSV(csv, title: "Back")
        #expect(imported.rows.first?.cells.first == .text("Hello, \"world\""))
    }

    @Test func csvSkipsEmptyLines() {
        let imported = HiveSheet.importCSV("A,B\n1,2\n\n\n3,4\n", title: "Sparse")
        #expect(imported.rows.count == 2)
    }

    @Test func csvEmptySheet() {
        let imported = HiveSheet.importCSV("", title: "Empty")
        #expect(imported.columns.isEmpty)
        #expect(imported.rows.isEmpty)
    }

    @Test func csvRaggedRowsNeverShiftGrid() {
        // A short row pads with empty cells; a long row truncates — malformed
        // input is contained per-line, never dropped into a shifted grid
        // (§15.2: never silently discard malformed user data).
        let imported = HiveSheet.importCSV("A,B\n1\n2,3,4,5\n", title: "Ragged")
        #expect(imported.columns.count == 2)
        #expect(imported.rows.count == 2)
        #expect(imported.rows[0].cells == [.text("1"), .empty])
        #expect(imported.rows[1].cells == [.text("2"), .text("3")])
    }

    @Test func csvHeaderOnlySheet() {
        let imported = HiveSheet.importCSV("Name,Score\n", title: "Headers")
        #expect(imported.columns.count == 2)
        #expect(imported.rows.isEmpty)
    }

    @Test func csvHandlesCRLFImports() {
        // Excel/Numbers export CRLF — field values must not carry the \r.
        let imported = HiveSheet.importCSV("Region,Amount\r\nNorth,10\r\nSouth,20\r\n", title: "CRLF")
        #expect(imported.rows.count == 2)
        #expect(imported.rows[0].cells[0] == .text("North"))
        #expect(imported.rows[1].cells[1] == .text("20"))
    }

    // MARK: - Store CRUD

    @Test func storeCreatesAndRetrievesSheet() async throws {
        let store = try HoneycombStore(path: ":memory:")
        let sheet = sampleSheet()
        _ = try await store.createSheet(sheet)
        let fetched = try await store.getSheet(id: sheet.id)
        // Field-by-field: timestamps persist as ISO8601 (second precision),
        // so sub-second Date equality would be a false negative.
        #expect(fetched?.id == sheet.id)
        #expect(fetched?.title == sheet.title)
        #expect(fetched?.columns == sheet.columns)
        #expect(fetched?.rows == sheet.rows)
        #expect(fetched?.provenance == sheet.provenance)
        #expect(fetched?.formulaVersion == sheet.formulaVersion)
        #expect(try await store.getAllSheets().count == 1)
    }

    @Test func storeUpdatesSheet() async throws {
        let store = try HoneycombStore(path: ":memory:")
        let sheet = sampleSheet()
        _ = try await store.createSheet(sheet)
        var updated = sheet
        updated.title = "Q4 Sales"
        updated.rows.append(SheetRow(cells: [.text("West"), .number(40)]))
        let result = try await store.updateSheet(updated)
        #expect(result?.title == "Q4 Sales")
        #expect(result?.rows.count == 4)
        let fetched = try await store.getSheet(id: sheet.id)
        #expect(fetched?.title == "Q4 Sales")
        #expect(fetched?.rows.count == 4)
    }

    @Test func storeDeletesSheet() async throws {
        let store = try HoneycombStore(path: ":memory:")
        let sheet = sampleSheet()
        _ = try await store.createSheet(sheet)
        #expect(try await store.deleteSheet(id: sheet.id) == true)
        #expect(try await store.getSheet(id: sheet.id) == nil)
        #expect(try await store.deleteSheet(id: "missing") == false)
    }

    @Test func storeLinksAndFetchesSources() async throws {
        let store = try HoneycombStore(path: ":memory:")
        let sheet = sampleSheet()
        _ = try await store.createSheet(sheet)
        let source = HoneycombStore.Node(
            id: "src-1",
            type: .source,
            label: "https://example.com/data",
            metadata: .object([:])
        )
        _ = try await store.insertNode(source)
        let edge = try await store.linkSheetToSource(sheetID: sheet.id, sourceID: "src-1")
        #expect(edge != nil)
        // Idempotent second link
        #expect(try await store.linkSheetToSource(sheetID: sheet.id, sourceID: "src-1") == nil)
        let sources = try await store.getSourcesForSheet(sheet.id)
        #expect(sources.count == 1)
        #expect(sources.first?.id == "src-1")
    }

    @Test func storeCsvRoundTripHelper() {
        let sheet = sampleSheet()
        let round = HoneycombStore.csvRoundTrip(sheet)
        #expect(round.columns.count == sheet.columns.count)
        #expect(round.rows.count == sheet.rows.count)
    }

@Test func taskPrioritiesAreNonEmpty() {
        #expect(!HiveTask.Priority.allCases.isEmpty)
    }

@Test func sheetColumnKindsAreNonEmpty() {
        #expect(!SheetColumn.Kind.allCases.isEmpty)
    }

@Test func sheetRowInitPreservesID() {
        let row = SheetRow(id: "r1", cells: [])
        #expect(row.id == "r1")
    }

@Test func sheetColumnKindTextIsText() {
        #expect(SheetColumn.Kind.text == .text)
    }
}
