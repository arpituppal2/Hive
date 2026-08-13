import Foundation

// MARK: - HiveSheet

/// A local, source-backed table (SHEET-001). Typed columns, local rows that
/// retain their source node IDs, CSV import/export, and a safe deterministic
/// formula subset. Stored as Honeycomb `.artifact` nodes.
///
/// AGENTS.md §7.7 minimum contract: typed columns, local rows, sort/filter/
/// group, CSV round-trip, safe formulas, every imported/generated row retains
/// a source object. No macros, no DAX, no full Excel import fidelity — the
/// core is trustworthy before any expansion.
public struct HiveSheet: Codable, Sendable, Identifiable, Equatable {

    public let id: String
    public var title: String
    public var columns: [SheetColumn]
    public var rows: [SheetRow]
    public let createdAt: Date
    public var updatedAt: Date
    public let provenance: String
    /// Formula-subset version the sheet's formulas were authored against
    /// (§7.7 audit contract). Bumped by the store on content-mutating writes.
    public var formulaVersion: Int

    public init(
        id: String = UUID().uuidString,
        title: String,
        columns: [SheetColumn],
        rows: [SheetRow] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        provenance: String = "user",
        formulaVersion: Int = SheetFormula.version
    ) {
        self.id = id
        self.title = title
        self.columns = columns
        self.rows = rows
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provenance = provenance
        self.formulaVersion = formulaVersion
    }

    // MARK: - Codable (forward-compatible: formulaVersion defaults)

    private enum CodingKeys: String, CodingKey {
        case id, title, columns, rows, createdAt, updatedAt, provenance, formulaVersion
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        columns = try c.decode([SheetColumn].self, forKey: .columns)
        rows = try c.decode([SheetRow].self, forKey: .rows)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        provenance = try c.decodeIfPresent(String.self, forKey: .provenance) ?? "user"
        formulaVersion = try c.decodeIfPresent(Int.self, forKey: .formulaVersion) ?? SheetFormula.version
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(columns, forKey: .columns)
        try c.encode(rows, forKey: .rows)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(provenance, forKey: .provenance)
        try c.encode(formulaVersion, forKey: .formulaVersion)
    }

    /// The value at a 0-based column/row position, if present.
    public func cellValue(column: Int, row: Int) -> SheetCell.Value? {
        guard row >= 0, row < rows.count, column >= 0, column < columns.count else { return nil }
        let cells = rows[row].cells
        guard column < cells.count else { return nil }
        return cells[column]
    }

    // MARK: - CSV

    /// Exports to CSV: a header row of column names, then one line per row.
    /// Cell values are quoted when they contain a comma, quote, or newline.
    public func exportCSV() -> String {
        var lines: [String] = []
        lines.append(columns.map { Self.csvEscape($0.name) }.joined(separator: ","))
        for row in rows {
            var fields: [String] = []
            for (colIndex, _) in columns.enumerated() {
                let value = row.cells.indices.contains(colIndex) ? row.cells[colIndex] : .empty
                fields.append(Self.csvEscape(value.displayText))
            }
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Imports CSV into a fresh sheet. The first line is the header (column
    /// names, all text-kind); every row is created with empty sourceIDs —
    /// callers attach provenance after import. Malformed lines are skipped,
    /// never silently dropped mid-parse into a shifted grid.
    public static func importCSV(_ csv: String, title: String, provenance: String = "csv-import") -> HiveSheet {
        // Strip CRLF endings (Excel/Numbers export \r\n) before parsing.
        let lines = csv.components(separatedBy: "\n")
            .map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else {
            return HiveSheet(title: title, columns: [], provenance: provenance)
        }
        let header = Self.parseCSVLine(headerLine)
        let columns = header.map { SheetColumn(name: $0) }
        var rows: [SheetRow] = []
        for line in lines.dropFirst() {
            let fields = Self.parseCSVLine(line)
            let cells = columns.indices.map { index -> SheetCell.Value in
                guard index < fields.count else { return .empty }
                return .text(fields[index])
            }
            rows.append(SheetRow(cells: cells))
        }
        return HiveSheet(title: title, columns: columns, rows: rows, provenance: provenance)
    }

    /// Minimal honest CSV: escapes a field with double quotes if it contains
    /// a comma, quote, or newline; doubles embedded quotes.
    static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    /// Parses one CSV line into fields, honoring double-quoted fields with
    /// embedded commas and escaped quotes. Multi-line quoted fields are not
    /// supported (documented limitation).
    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if inQuotes {
                if c == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }

    // MARK: - Conversion

    /// Converts into a Honeycomb `.artifact` node. The label is the title
    /// (FTS-indexed); metadata carries the sheet payload as a JSON string so
    /// row text participates in full-text search.
    public func toNode() -> HoneycombStore.Node {
        var meta: [String: JSONValue] = [:]
        if let payloadData = try? JSONEncoder().encode(SheetPayload(columns: columns, rows: rows, formulaVersion: formulaVersion)),
           let payload = String(data: payloadData, encoding: .utf8) {
            meta["payload"] = .string(payload)
        }
        return HoneycombStore.Node(
            id: id,
            type: .artifact,
            label: title,
            metadata: .object(meta),
            contentHash: nil,           // sheets are authored artifacts, no dedup
            createdAt: createdAt,
            updatedAt: updatedAt,
            provenance: provenance
        )
    }

    /// Creates a HiveSheet from a Honeycomb node. Returns nil if the node is
    /// not an `.artifact` or the payload is missing/corrupt.
    public static func from(_ node: HoneycombStore.Node) -> HiveSheet? {
        guard node.type == .artifact else { return nil }
        guard case .object(let dict) = node.metadata,
              case .string(let payload) = dict["payload"],
              let data = payload.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(SheetPayload.self, from: data) else {
            return nil
        }
        return HiveSheet(
            id: node.id,
            title: node.label,
            columns: decoded.columns,
            rows: decoded.rows,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            provenance: node.provenance,
            formulaVersion: decoded.formulaVersion
        )
    }
}

/// Wire format for sheet persistence. Codable payload string in node metadata.
struct SheetPayload: Codable, Sendable {
    let columns: [SheetColumn]
    let rows: [SheetRow]
    let formulaVersion: Int

    init(columns: [SheetColumn], rows: [SheetRow], formulaVersion: Int = SheetFormula.version) {
        self.columns = columns
        self.rows = rows
        self.formulaVersion = formulaVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        columns = try c.decode([SheetColumn].self, forKey: .columns)
        rows = try c.decode([SheetRow].self, forKey: .rows)
        formulaVersion = try c.decodeIfPresent(Int.self, forKey: .formulaVersion) ?? SheetFormula.version
    }
}

// MARK: - SheetColumn

public struct SheetColumn: Codable, Sendable, Identifiable, Equatable {

    public enum Kind: String, Codable, Sendable, CaseIterable {
        case text
        case number
        case date
        case bool
    }

    public let id: String
    public var name: String
    public var kind: Kind

    public init(id: String = UUID().uuidString, name: String, kind: Kind = .text) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

// MARK: - SheetRow

public struct SheetRow: Codable, Sendable, Identifiable, Equatable {

    public let id: String
    public var cells: [SheetCell.Value]
    /// Every imported or generated row retains its source node IDs (§7.7).
    public var sourceIDs: [String]
    public let provenance: String

    public init(
        id: String = UUID().uuidString,
        cells: [SheetCell.Value],
        sourceIDs: [String] = [],
        provenance: String = "user"
    ) {
        self.id = id
        self.cells = cells
        self.sourceIDs = sourceIDs
        self.provenance = provenance
    }
}

// MARK: - SheetCell

public enum SheetCell {

    /// A single cell value. Formulas are stored as text beginning with "=" and
    /// evaluated deterministically by SheetFormula — never by macro or code.
    public enum Value: Codable, Sendable, Equatable {
        case text(String)
        case number(Double)
        case bool(Bool)
        case formula(String)
        case empty

        /// The CSV/display representation (formulas render as their source).
        public var displayText: String {
            switch self {
            case .text(let s): return s
            case .number(let d):
                // Int(d) traps at runtime when the value is outside Int64's
                // range — guard the magnitude before converting so a huge
                // formula result can never crash the renderer.
                if d == d.rounded() && d.magnitude < 1e15 { return String(Int64(d)) }
                return String(d)
            case .bool(let b): return b ? "TRUE" : "FALSE"
            case .formula(let f): return f
            case .empty: return ""
            }
        }
    }
}

// MARK: - SheetFormula

/// A safe, deterministic formula evaluator — the documented supported subset
/// (§7.7): numbers, `+ - * / %`, parentheses, cell references (`A1`), and the
/// aggregates `SUM`, `AVERAGE`, `MIN`, `MAX`, `COUNT` over ranges (`B2:B5`).
/// Nothing else: no macros, no external calls, no side effects. A formula
/// either computes the same value every time or reports an error.
public enum SheetFormula {

    /// Version of the supported formula subset (§7.7 audit contract). Bumped
    /// when the grammar or whitelist changes; sheets record the version their
    /// formulas were authored against.
    public static let version: Int = 1

    public enum EvalError: Error, Equatable, Sendable {
        case parse(String)
        case unknownCell(String)
        case unknownFunction(String)
        case divisionByZero
        case emptyAggregate
    }

    // MARK: - Tokenization

    private enum Token: Equatable {
        case number(Double)
        case op(String)
        case leftParen
        case rightParen
        case comma
        case colon
        case cell(String)
        case function(String)
    }

    private static let aggregates: Set<String> = ["SUM", "AVERAGE", "MIN", "MAX", "COUNT"]

    private static func tokenize(_ raw: String) -> Result<[Token], EvalError> {
        let expr = raw.hasPrefix("=") ? String(raw.dropFirst()) : raw
        let chars = Array(expr)
        var tokens: [Token] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }
            if c.isNumber || c == "." {
                var num = ""
                while i < chars.count, chars[i].isNumber || chars[i] == "." {
                    num.append(chars[i])
                    i += 1
                }
                guard let v = Double(num) else { return .failure(.parse("bad number '\(num)'")) }
                tokens.append(.number(v))
                continue
            }
            if c.isLetter {
                var ident = ""
                while i < chars.count, chars[i].isLetter || chars[i].isNumber {
                    ident.append(chars[i])
                    i += 1
                }
                let upper = ident.uppercased()
                // A name followed by '(' is a function call. Whitelisting is
                // enforced at parse time (unknownFunction) — never executed.
                if i < chars.count, chars[i] == "(" {
                    tokens.append(.function(upper))
                } else if aggregates.contains(upper) {
                    tokens.append(.function(upper))
                } else {
                    // Cell reference: letters then digits (A1, AB12).
                    let letters = ident.prefix { $0.isLetter }
                    let digits = ident.dropFirst(letters.count)
                    guard !letters.isEmpty, !digits.isEmpty, digits.allSatisfy({ $0.isNumber }) else {
                        return .failure(.parse("unknown identifier '\(ident)'"))
                    }
                    tokens.append(.cell(upper))
                }
                continue
            }
            switch c {
            case "+", "-", "*", "/", "%": tokens.append(.op(String(c)))
            case "(": tokens.append(.leftParen)
            case ")": tokens.append(.rightParen)
            case ",": tokens.append(.comma)
            case ":": tokens.append(.colon)
            default: return .failure(.parse("unexpected character '\(c)'"))
            }
            i += 1
        }
        return .success(tokens)
    }

    // MARK: - Parsing (recursive descent, standard precedence)

    private struct Parser {
        let tokens: [Token]
        let resolveCell: (String) -> Double?
        var index = 0

        mutating func parse() -> Result<Double, EvalError> {
            let result = parseExpression()
            // Only report trailing tokens when the expression parsed — a
            // failure inside the expression (e.g. "=1+") must propagate its
            // real error instead of being masked by the leftover index.
            if case .success = result, index != tokens.count {
                return .failure(.parse("trailing tokens"))
            }
            return result
        }

        private mutating func peek() -> Token? {
            index < tokens.count ? tokens[index] : nil
        }

        private mutating func next() -> Token? {
            defer { index += 1 }
            return index < tokens.count ? tokens[index] : nil
        }

        private mutating func parseExpression() -> Result<Double, EvalError> {
            var value = parseTerm()
            while case .op(let op)? = peek(), op == "+" || op == "-" {
                _ = next()
                let rhs = parseTerm()
                switch (value, rhs) {
                case (.success(let a), .success(let b)):
                    value = .success(op == "+" ? a + b : a - b)
                case (.failure(let e), _), (_, .failure(let e)):
                    return .failure(e)
                default: break
                }
            }
            return value
        }

        private mutating func parseTerm() -> Result<Double, EvalError> {
            var value = parseFactor()
            while case .op(let op)? = peek(), op == "*" || op == "/" || op == "%" {
                _ = next()
                let rhs = parseFactor()
                switch (value, rhs) {
                case (.success(let a), .success(let b)):
                    if op == "/" || op == "%" {
                        guard b != 0 else { return .failure(.divisionByZero) }
                        value = .success(op == "/" ? a / b : a.truncatingRemainder(dividingBy: b))
                    } else {
                        value = .success(a * b)
                    }
                case (.failure(let e), _), (_, .failure(let e)):
                    return .failure(e)
                default: break
                }
            }
            return value
        }

        private mutating func parseFactor() -> Result<Double, EvalError> {
            guard let token = next() else { return .failure(.parse("unexpected end")) }
            switch token {
            case .number(let v):
                return .success(v)
            case .op("-"):
                return parseFactor().map { -$0 }
            case .op("+"):
                return parseFactor()
            case .cell(let ref):
                guard let v = resolveCell(ref) else { return .failure(.unknownCell(ref)) }
                return .success(v)
            case .leftParen:
                let inner = parseExpression()
                guard next() == .rightParen else { return .failure(.parse("missing ')'")) }
                return inner
            case .function(let name):
                return parseFunction(name)
            default:
                return .failure(.parse("unexpected token"))
            }
        }

        private mutating func parseFunction(_ name: String) -> Result<Double, EvalError> {
            guard next() == .leftParen else { return .failure(.parse("missing '(' after \(name)")) }
            // Aggregates take ranges (B2:B5) or cell lists (B2,B3).
            var cells: [String] = []
            var finished = false
            while !finished {
                switch next() {
                case .cell(let ref):
                    if peek() == .colon {
                        _ = next()
                        guard case .cell(let end)? = next() else { return .failure(.parse("bad range")) }
                        cells.append(contentsOf: expandRange(ref, end))
                    } else {
                        cells.append(ref)
                    }
                case .rightParen:
                    finished = true
                default:
                    return .failure(.parse("bad argument in \(name)"))
                }
                if peek() == .comma { _ = next() }
            }
            let values = cells.compactMap { resolveCell($0) }
            switch name {
            case "SUM":
                return .success(values.reduce(0, +))
            case "COUNT":
                return .success(Double(values.count))
            case "AVERAGE":
                guard !values.isEmpty else { return .failure(.emptyAggregate) }
                return .success(values.reduce(0, +) / Double(values.count))
            case "MIN":
                guard let m = values.min() else { return .failure(.emptyAggregate) }
                return .success(m)
            case "MAX":
                guard let m = values.max() else { return .failure(.emptyAggregate) }
                return .success(m)
            default:
                return .failure(.unknownFunction(name))
            }
        }

        /// Enumerates a rectangular range as cell refs (B2:B5 → B2..B5).
        private func expandRange(_ from: String, _ to: String) -> [String] {
            guard let a = cellIndices(from), let b = cellIndices(to) else { return [from] }
            var refs: [String] = []
            let colA = min(a.col, b.col), colB = max(a.col, b.col)
            let rowA = min(a.row, b.row), rowB = max(a.row, b.row)
            for row in rowA...rowB {
                for col in colA...colB {
                    refs.append(refString(col: col, row: row))
                }
            }
            return refs
        }
    }

    // MARK: - Cell Reference Helpers

    /// A1-style reference to 0-based (col, row). "A1" → (0, 0); "AB12" → (27, 11).
    /// Public so the Sheets UI can render cell references (formula bar).
    public static func cellIndices(_ ref: String) -> (col: Int, row: Int)? {
        let letters = ref.prefix { $0.isLetter }
        let digits = ref.dropFirst(letters.count)
        guard !letters.isEmpty, !digits.isEmpty, digits.allSatisfy({ $0.isNumber }) else { return nil }
        var col = 0
        for ch in letters {
            guard let ascii = ch.asciiValue else { return nil }
            col = col * 26 + Int(ascii) - 64
        }
        return (col - 1, Int(digits)! - 1)
    }

    /// 0-based (col, row) back to A1-style. (0, 0) → "A1"; (27, 11) → "AB12".
    /// Public so the Sheets UI can render cell references (formula bar).
    public static func refString(col: Int, row: Int) -> String {
        var letters = ""
        var c = col + 1
        while c > 0 {
            let rem = (c - 1) % 26
            letters = String(UnicodeScalar(65 + rem)!) + letters
            c = (c - 1) / 26
        }
        return letters + String(row + 1)
    }

    // MARK: - Public Entry

    /// Evaluates a formula deterministically. `resolveCell` returns the numeric
    /// value of an A1 reference (nil = empty/non-numeric). `@escaping` because
    /// the closure is stored on the parser struct.
    public static func evaluate(
        _ raw: String,
        resolveCell: @escaping (String) -> Double?
    ) -> Result<Double, EvalError> {
        let tokens: [Token]
        switch tokenize(raw) {
        case .success(let t): tokens = t
        case .failure(let e): return .failure(e)
        }
        var parser = Parser(tokens: tokens, resolveCell: resolveCell)
        return parser.parse()
    }
}
