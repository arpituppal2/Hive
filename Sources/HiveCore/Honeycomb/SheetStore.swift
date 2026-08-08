import Foundation

// MARK: - SheetStore: durable, source-linked, importable/exportable sheets

/// SHEET-001: Hive Sheets live on Honeycomb as typed `.artifact` nodes (the
/// §7.1 Artifact object) with `references` edges to their source nodes, so
/// every row's provenance is queryable. The EventLedger caller records
/// create/update/delete — this store only owns the durable state.
extension HoneycombStore {

    /// Creates a sheet as an `.artifact` Honeycomb node. No content-hash
    /// dedup — sheets are authored artifacts. Links each source ID with a
    /// `references` edge (best-effort, mirroring createBrief's partial-write
    /// protection).
    /// - Returns: the created HiveSheet.
    @discardableResult
    public func createSheet(_ sheet: HiveSheet) throws -> HiveSheet {
        let node = try insertNode(sheet.toNode(), checkDedup: false)
        let sourceIDs = Set(sheet.rows.flatMap { $0.sourceIDs })
        for sourceID in sourceIDs {
            _ = try? insertEdge(HoneycombStore.Edge(
                sourceID: node.id,
                targetID: sourceID,
                relation: .references
            ))
        }
        return HiveSheet.from(node) ?? sheet
    }

    /// Retrieves a sheet by node ID.
    public func getSheet(id: String) throws -> HiveSheet? {
        guard let node = try getNode(id: id) else { return nil }
        return HiveSheet.from(node)
    }

    /// Returns all sheets, ordered by creation date descending.
    public func getAllSheets(limit: Int = 100) throws -> [HiveSheet] {
        try getNodesByType(.artifact, limit: limit)
            .compactMap { HiveSheet.from($0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Updates a sheet's title/columns/rows. Bumps updatedAt, advances
    /// formulaVersion when content changed (§7.7 audit), and re-indexes FTS
    /// via updateNode (label + payload metadata).
    @discardableResult
    public func updateSheet(_ sheet: HiveSheet) throws -> HiveSheet? {
        guard let node = try getNode(id: sheet.id), node.type == .artifact else { return nil }
        let stored = try getSheet(id: sheet.id)
        let contentChanged = stored.map {
            $0.title != sheet.title || $0.columns != sheet.columns || $0.rows != sheet.rows
        } ?? true
        let version = (stored?.formulaVersion ?? SheetFormula.version) + (contentChanged ? 1 : 0)
        var meta: [String: JSONValue] = [:]
        if let payloadData = try? JSONEncoder().encode(SheetPayload(columns: sheet.columns, rows: sheet.rows, formulaVersion: version)),
           let payload = String(data: payloadData, encoding: .utf8) {
            meta["payload"] = .string(payload)
        }
        let updated = try updateNode(id: sheet.id, label: sheet.title, metadata: .object(meta))
        guard let updated else { return nil }
        return HiveSheet.from(updated)
    }

    /// Deletes a sheet node. All incident edges cascade via ON DELETE CASCADE.
    public func deleteSheet(id: String) throws -> Bool {
        guard let node = try getNode(id: id), node.type == .artifact else { return false }
        try deleteNode(id: id)
        return true
    }

    /// Links a sheet to a source node with a `references` edge. Idempotent.
    @discardableResult
    public func linkSheetToSource(sheetID: String, sourceID: String) throws -> HoneycombStore.Edge? {
        if try edgeExists(from: sheetID, to: sourceID, relation: .references) { return nil }
        return try insertEdge(HoneycombStore.Edge(
            sourceID: sheetID,
            targetID: sourceID,
            relation: .references
        ))
    }

    /// All source nodes a sheet references.
    public func getSourcesForSheet(_ sheetID: String) throws -> [HoneycombStore.Node] {
        let edges = try getEdges(from: sheetID, relation: .references)
        return try getNodes(ids: edges.map { $0.targetID })
    }

    /// Round-trips a sheet through CSV: export → import. Useful for testing
    /// the import/export contract end to end without UI.
    public static func csvRoundTrip(_ sheet: HiveSheet) -> HiveSheet {
        HiveSheet.importCSV(sheet.exportCSV(), title: sheet.title, provenance: "csv-import")
    }
}
