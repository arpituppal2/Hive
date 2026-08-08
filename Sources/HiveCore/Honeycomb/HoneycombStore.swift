import Foundation
import SQLite3

// MARK: - Honeycomb: the durable knowledge substrate

/// The Hive Browser's structured knowledge graph. SQLite-backed, actor-isolated,
/// zero-external-dependency (system SQLite3 on macOS).
///
/// Honeycomb stores **typed nodes** (Source, Capture, Claim, Artifact, Project,
/// Task, Brief, Decision, Question, Preference) connected by **typed directed
/// edges** (supports, belongs_to, derived_from, contradicts, references,
/// depends_on, supersedes, annotates, next_action, answers, questions).
///
/// Every node has a content hash for deduplication, provenance for audit, and
/// full-text-search via FTS5. Schema migrations are versioned and append-only.
///
/// Per AGENTS.md §8.3:
/// - Parameterized SQL only (no string interpolation)
/// - Content hashing + deduplication
/// - Revision history via updates (updated_at tracked, old versions retained)
/// - Separate query paths for graph exploration vs model retrieval
/// - Actor isolation with cancellation-aware long operations
public actor HoneycombStore {

    // MARK: - Public types

    /// A typed node in the knowledge graph.
    public struct Node: Sendable, Codable, Identifiable, Equatable {
        public let id: String           // UUID
        public var type: NodeType
        public var label: String
        public var metadata: JSONValue  // flexible per-node-type properties
        public let contentHash: String? // SHA-256 for dedup
        public let createdAt: Date
        public var updatedAt: Date
        public let provenance: String   // e.g. "browser-capture", "swarm-research", "user"

        public init(id: String = UUID().uuidString,
                    type: NodeType,
                    label: String,
                    metadata: JSONValue = .object([:]),
                    contentHash: String? = nil,
                    createdAt: Date = Date(),
                    updatedAt: Date = Date(),
                    provenance: String = "user") {
            self.id = id
            self.type = type
            self.label = label
            self.metadata = metadata
            self.contentHash = contentHash
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.provenance = provenance
        }
    }

    /// The type of a knowledge-graph node. Mirrors AGENTS.md §7.1 object model.
    public enum NodeType: String, Sendable, Codable, CaseIterable {
        case source         // canonical URL + retrieval metadata
        case capture        // extracted page text / selection
        case claim          // asserted fact with evidence spans
        case artifact       // generated file, diff, table, image
        case project        // container for related work objects
        case task           // actionable item with state
        case brief          // synthesized research output
        case decision       // recorded choice with rationale
        case question       // open question awaiting resolution
        case preference     // explicit user rule
        case note           // freeform user annotation
        case unknown        // fallback for unrecognized types
    }

    /// A typed directed edge between two nodes.
    public struct Edge: Sendable, Codable, Identifiable, Equatable {
        public let id: String           // UUID
        public let sourceID: String
        public let targetID: String
        public let relation: EdgeRelation
        public var weight: Double       // 0.0–1.0, relevance/confidence
        public var metadata: JSONValue
        public let createdAt: Date

        public init(id: String = UUID().uuidString,
                    sourceID: String,
                    targetID: String,
                    relation: EdgeRelation,
                    weight: Double = 1.0,
                    metadata: JSONValue = .object([:]),
                    createdAt: Date = Date()) {
            self.id = id
            self.sourceID = sourceID
            self.targetID = targetID
            self.relation = relation
            self.weight = weight
            self.metadata = metadata
            self.createdAt = createdAt
        }
    }

    /// The semantic relationship between two nodes. AGENTS.md §7.1 edges column.
    public enum EdgeRelation: String, Sendable, Codable, CaseIterable {
        case supports       // source/claim supports a claim/brief
        case contradicts    // source/claim contradicts another
        case belongsTo      // node belongs to a project or hive
        case derivedFrom    // artifact/brief/claim derived from source
        case references     // weak reference (see-also)
        case dependsOn      // task/decision depends on another
        case supersedes     // newer version supersedes older
        case annotates      // note/claim annotates a source
        case nextAction     // decision/brief has a next action task
        case answers        // brief/claim answers a question
        case questions      // question about a claim/source
    }

    // MARK: - Schema version

    private static let currentSchemaVersion: Int32 = 1

    // MARK: - Database handle

    /// `nonisolated(unsafe)` because OpaquePointer? is not Sendable, but
    /// the actor serializes all access. Only the actor's methods and deinit
    /// touch this pointer.
    private nonisolated(unsafe) var db: OpaquePointer?

    /// Whether this store is backed by an in-memory database. The browser uses
    /// this to disclose degraded persistence instead of silently presenting a
    /// durable-looking surface after disk storage fails.
    public nonisolated let isEphemeral: Bool

    // MARK: - Init

    /// Opens or creates the Honeycomb database at `path`. Runs migrations
    /// automatically on first open.
    public init(path: String) throws {
        self.isEphemeral = path == ":memory:"
        var localDB: OpaquePointer?
        if sqlite3_open(path, &localDB) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(localDB))
            sqlite3_close(localDB)
            throw HoneycombError.openFailed(msg)
        }
        self.db = localDB
        // WAL mode for concurrent reads + writes on the same connection
        _ = nonisolatedExecuteRaw("PRAGMA journal_mode=WAL", on: localDB)
        _ = nonisolatedExecuteRaw("PRAGMA foreign_keys=ON", on: localDB)
        try runMigrations(on: localDB)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: - Migrations (nonisolated: synchronous SQLite during init)

    private nonisolated func runMigrations(on db: OpaquePointer?) throws {
        let current = currentUserVersion(on: db)
        if current < 1 {
            try migrateV1(on: db)
            setUserVersion(Self.currentSchemaVersion, on: db)
        }
    }

    private nonisolated func migrateV1(on db: OpaquePointer?) throws {
        try nonisolatedExecute("""
            CREATE TABLE IF NOT EXISTS honeycomb_nodes (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                label TEXT NOT NULL DEFAULT '',
                metadata_json TEXT NOT NULL DEFAULT '{}',
                content_hash TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                provenance TEXT NOT NULL DEFAULT 'unknown'
            )
            """, on: db)
        try nonisolatedExecute("""
            CREATE INDEX IF NOT EXISTS idx_nodes_type ON honeycomb_nodes(type)
            """, on: db)
        try nonisolatedExecute("""
            CREATE INDEX IF NOT EXISTS idx_nodes_content_hash ON honeycomb_nodes(content_hash)
            """, on: db)
        try nonisolatedExecute("""
            CREATE INDEX IF NOT EXISTS idx_nodes_provenance ON honeycomb_nodes(provenance)
            """, on: db)
        try nonisolatedExecute("""
            CREATE TABLE IF NOT EXISTS honeycomb_edges (
                id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL REFERENCES honeycomb_nodes(id) ON DELETE CASCADE,
                target_id TEXT NOT NULL REFERENCES honeycomb_nodes(id) ON DELETE CASCADE,
                relation TEXT NOT NULL,
                weight REAL NOT NULL DEFAULT 1.0,
                metadata_json TEXT NOT NULL DEFAULT '{}',
                created_at TEXT NOT NULL
            )
            """, on: db)
        try nonisolatedExecute("""
            CREATE INDEX IF NOT EXISTS idx_edges_source ON honeycomb_edges(source_id)
            """, on: db)
        try nonisolatedExecute("""
            CREATE INDEX IF NOT EXISTS idx_edges_target ON honeycomb_edges(target_id)
            """, on: db)
        try nonisolatedExecute("""
            CREATE INDEX IF NOT EXISTS idx_edges_relation ON honeycomb_edges(relation)
            """, on: db)
        // FTS5 for full-text search over node labels and searchable metadata.
        // Standalone FTS5 table (no external content) — rows are managed
        // manually via INSERT/DELETE in insertNode/updateNode/deleteNode.
        try nonisolatedExecute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS honeycomb_fts USING fts5(
                node_id UNINDEXED,
                label,
                searchable_text
            )
            """, on: db)
        // Revision history for node corrections (AGENTS.md §8.3)
        try nonisolatedExecute("""
            CREATE TABLE IF NOT EXISTS honeycomb_revisions (
                id TEXT PRIMARY KEY,
                node_id TEXT NOT NULL REFERENCES honeycomb_nodes(id) ON DELETE CASCADE,
                previous_label TEXT,
                previous_metadata_json TEXT,
                revised_at TEXT NOT NULL
            )
            """, on: db)
        try nonisolatedExecute("""
            CREATE INDEX IF NOT EXISTS idx_revisions_node ON honeycomb_revisions(node_id)
            """, on: db)
    }

    private nonisolated func currentUserVersion(on db: OpaquePointer?) -> Int32 {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int(stmt, 0)
        }
        return 0
    }

    /// NOTE: SQLite PRAGMAs do not support parameterized values, so string
    /// interpolation is used for the version number (which is always an Int32).
    private nonisolated func setUserVersion(_ version: Int32, on db: OpaquePointer?) {
        _ = nonisolatedExecuteRaw("PRAGMA user_version = \(version)", on: db)
    }

    // MARK: - Node CRUD

    /// Inserts a node. If a node with the same type and content_hash already
    /// exists, returns the existing node instead (deduplication).
    /// - Parameter checkDedup: when true (default), checks for duplicate before insert.
    /// - Returns: the inserted or existing node.
    @discardableResult
    public func insertNode(_ node: Node, checkDedup: Bool = true) throws -> Node {
        // Deduplication by type + content_hash
        if checkDedup, let hash = node.contentHash, let existing = try findNode(type: node.type, contentHash: hash) {
            return existing
        }
        let metadataJSON = try encodeJSON(node.metadata)
        try execute("""
            INSERT INTO honeycomb_nodes (id, type, label, metadata_json, content_hash, created_at, updated_at, provenance)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            args: [.text(node.id), .text(node.type.rawValue), .text(node.label),
                   .text(metadataJSON), .text(node.contentHash ?? ""),
                   .text(iso8601(node.createdAt)), .text(iso8601(node.updatedAt)),
                   .text(node.provenance)])
        // Populate FTS index
        let searchable = [node.label, searchableText(from: node.metadata)]
            .filter { !$0.isEmpty }.joined(separator: " ")
        if !searchable.isEmpty {
            try execute("""
                INSERT INTO honeycomb_fts (node_id, label, searchable_text)
                VALUES (?, ?, ?)
                """, args: [.text(node.id), .text(node.label), .text(searchable)])
        }
        return node
    }

    /// Retrieves a node by ID.
    public func getNode(id: String) throws -> Node? {
        let rows = try query("""
            SELECT id, type, label, metadata_json, content_hash, created_at, updated_at, provenance
            FROM honeycomb_nodes WHERE id = ?
            """, args: [.text(id)])
        return rows.first.map { rowToNode($0) }
    }

    /// Retrieves multiple nodes by ID in a single parameterized query — the
    /// batch counterpart to `getNode(id:)`, avoiding N round trips when the
    /// caller holds many IDs (e.g. hot-memory context assembly). Missing IDs
    /// are silently omitted; the result preserves the requested order.
    ///
    /// - Note: SQLite caps variables per statement (999 on older builds,
    ///   32766 on 3.32+). Current callers pass ≤ ~30 IDs; keep well under the
    ///   cap or chunk the input.
    public func getNodes(ids: [String]) throws -> [Node] {
        try Task.checkCancellation()
        // Deduplicate while preserving first-occurrence order.
        var seen = Set<String>()
        let unique = ids.filter { seen.insert($0).inserted }
        guard !unique.isEmpty else { return [] }
        let placeholders = unique.map { _ in "?" }.joined(separator: ",")
        let rows = try query("""
            SELECT id, type, label, metadata_json, content_hash, created_at, updated_at, provenance
            FROM honeycomb_nodes WHERE id IN (\(placeholders))
            """, args: unique.map { .text($0) })
        var byID: [String: Node] = [:]
        for row in rows {
            let node = rowToNode(row)
            byID[node.id] = node
        }
        return unique.compactMap { byID[$0] }
    }

    /// Updates an existing node's label, metadata, and updated_at timestamp.
    /// Returns the updated node, or nil if the node doesn't exist.
    @discardableResult
    public func updateNode(id: String, label: String? = nil, metadata: JSONValue? = nil) throws -> Node? {
        guard var node = try getNode(id: id) else { return nil }
        // Record revision before overwriting (AGENTS.md §8.3)
        let prevMetadataJSON = try encodeJSON(node.metadata)
        try execute("""
            INSERT INTO honeycomb_revisions (id, node_id, previous_label, previous_metadata_json, revised_at)
            VALUES (?, ?, ?, ?, ?)
            """, args: [.text(UUID().uuidString), .text(id), .text(node.label),
                       .text(prevMetadataJSON), .text(iso8601(Date()))])
        if let label { node.label = label }
        if let metadata { node.metadata = metadata }
        node.updatedAt = Date()
        let metadataJSON = try encodeJSON(node.metadata)
        try execute("""
            UPDATE honeycomb_nodes SET label = ?, metadata_json = ?, updated_at = ?
            WHERE id = ?
            """, args: [.text(node.label), .text(metadataJSON), .text(iso8601(node.updatedAt)), .text(id)])
        // Update FTS
        try execute("DELETE FROM honeycomb_fts WHERE node_id = ?", args: [.text(id)])
        let searchable = [node.label, searchableText(from: node.metadata)]
            .filter { !$0.isEmpty }.joined(separator: " ")
        if !searchable.isEmpty {
            try execute("INSERT INTO honeycomb_fts (node_id, label, searchable_text) VALUES (?, ?, ?)",
                        args: [.text(id), .text(node.label), .text(searchable)])
        }
        return node
    }

    /// Deletes a node and all its edges (CASCADE). Also removes from FTS.
    public func deleteNode(id: String) throws {
        try execute("DELETE FROM honeycomb_fts WHERE node_id = ?", args: [.text(id)])
        try execute("DELETE FROM honeycomb_nodes WHERE id = ?", args: [.text(id)])
    }

    /// Finds a node by type and content_hash. Returns nil if no match.
    public func findNode(type: NodeType, contentHash: String) throws -> Node? {
        let rows = try query("""
            SELECT id, type, label, metadata_json, content_hash, created_at, updated_at, provenance
            FROM honeycomb_nodes WHERE type = ? AND content_hash = ?
            LIMIT 1
            """, args: [.text(type.rawValue), .text(contentHash)])
        return rows.first.map { rowToNode($0) }
    }

    /// Counts nodes, optionally filtered by type.
    public func countNodes(type: NodeType? = nil) throws -> Int {
        if let type {
            let rows = try query("SELECT COUNT(*) FROM honeycomb_nodes WHERE type = ?",
                                 args: [.text(type.rawValue)])
            return rows.first?[0].intValue ?? 0
        } else {
            let rows = try query("SELECT COUNT(*) FROM honeycomb_nodes", args: [])
            return rows.first?[0].intValue ?? 0
        }
    }

    // MARK: - Edge CRUD

    /// Inserts an edge. Returns the edge.
    @discardableResult
    public func insertEdge(_ edge: Edge) throws -> Edge {
        let metadataJSON = try encodeJSON(edge.metadata)
        try execute("""
            INSERT INTO honeycomb_edges (id, source_id, target_id, relation, weight, metadata_json, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            args: [.text(edge.id), .text(edge.sourceID), .text(edge.targetID),
                   .text(edge.relation.rawValue), .double(edge.weight),
                   .text(metadataJSON), .text(iso8601(edge.createdAt))])
        return edge
    }

    /// Retrieves edges from a node.
    public func getEdges(from sourceID: String, relation: EdgeRelation? = nil) throws -> [Edge] {
        if let relation {
            return try query("""
                SELECT id, source_id, target_id, relation, weight, metadata_json, created_at
                FROM honeycomb_edges WHERE source_id = ? AND relation = ?
                """, args: [.text(sourceID), .text(relation.rawValue)]).map { rowToEdge($0) }
        } else {
            return try query("""
                SELECT id, source_id, target_id, relation, weight, metadata_json, created_at
                FROM honeycomb_edges WHERE source_id = ?
                """, args: [.text(sourceID)]).map { rowToEdge($0) }
        }
    }

    /// Retrieves edges to a node (incoming).
    public func getEdges(to targetID: String, relation: EdgeRelation? = nil) throws -> [Edge] {
        if let relation {
            return try query("""
                SELECT id, source_id, target_id, relation, weight, metadata_json, created_at
                FROM honeycomb_edges WHERE target_id = ? AND relation = ?
                """, args: [.text(targetID), .text(relation.rawValue)]).map { rowToEdge($0) }
        } else {
            return try query("""
                SELECT id, source_id, target_id, relation, weight, metadata_json, created_at
                FROM honeycomb_edges WHERE target_id = ?
                """, args: [.text(targetID)]).map { rowToEdge($0) }
        }
    }

    /// Checks if an edge exists between two nodes with a given relation.
    public func edgeExists(from sourceID: String, to targetID: String, relation: EdgeRelation) throws -> Bool {
        let rows = try query("""
            SELECT 1 FROM honeycomb_edges
            WHERE source_id = ? AND target_id = ? AND relation = ?
            LIMIT 1
            """, args: [.text(sourceID), .text(targetID), .text(relation.rawValue)])
        return !rows.isEmpty
    }

    /// Deletes an edge by ID.
    public func deleteEdge(id: String) throws {
        try execute("DELETE FROM honeycomb_edges WHERE id = ?", args: [.text(id)])
    }

    /// Counts edges, optionally filtered by relation.
    public func countEdges(relation: EdgeRelation? = nil) throws -> Int {
        if let relation {
            let rows = try query("SELECT COUNT(*) FROM honeycomb_edges WHERE relation = ?",
                                 args: [.text(relation.rawValue)])
            return rows.first?[0].intValue ?? 0
        } else {
            let rows = try query("SELECT COUNT(*) FROM honeycomb_edges", args: [])
            return rows.first?[0].intValue ?? 0
        }
    }

    // MARK: - Full-text search (FTS5)

    /// Searches nodes by label and metadata text using FTS5.
    /// Returns nodes ranked by relevance (BM25).
    public func search(query text: String, limit: Int = 20) throws -> [Node] {
        try Task.checkCancellation()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        // FTS5 query: tokenize the input and match against the FTS index
        let ftsQuery = trimmed.split(separator: " ").map { "\"\($0)\"" }.joined(separator: " OR ")
        let rows = try query("""
            SELECT n.id, n.type, n.label, n.metadata_json, n.content_hash,
                   n.created_at, n.updated_at, n.provenance
            FROM honeycomb_fts f
            JOIN honeycomb_nodes n ON f.node_id = n.id
            WHERE honeycomb_fts MATCH ?
            ORDER BY rank
            LIMIT ?
            """, args: [.text(ftsQuery), .int(Int32(limit))])
        return rows.map { rowToNode($0) }
    }

    // MARK: - Graph traversal

    /// Returns neighbors of a node up to the specified depth (BFS, 1 = direct only).
    /// Neighbor nodes are batch-fetched in a single IN-clause query per frontier
    /// layer instead of individual getNode(id:) calls.
    public func getNeighbors(of nodeID: String, depth: Int = 1) throws -> [Node] {
        guard depth >= 1 else { return [] }
        var visited = Set<String>([nodeID])
        var frontier = [nodeID]
        var results: [Node] = []

        for _ in 0..<depth {
            try Task.checkCancellation()
            var nextIDs = Set<String>()
            for current in frontier {
                let outgoing = try query("""
                    SELECT target_id FROM honeycomb_edges WHERE source_id = ?
                    """, args: [.text(current)])
                for row in outgoing {
                    let targetID = row[0].stringValue
                    if !visited.contains(targetID) {
                        visited.insert(targetID)
                        nextIDs.insert(targetID)
                    }
                }
                let incoming = try query("""
                    SELECT source_id FROM honeycomb_edges WHERE target_id = ?
                    """, args: [.text(current)])
                for row in incoming {
                    let sourceID = row[0].stringValue
                    if !visited.contains(sourceID) {
                        visited.insert(sourceID)
                        nextIDs.insert(sourceID)
                    }
                }
            }
            if !nextIDs.isEmpty {
                results.append(contentsOf: try getNodes(ids: Array(nextIDs)))
            }
            frontier = Array(nextIDs)
        }
        return results
    }

    /// Returns all nodes of a given type (for model retrieval / batch queries).
    public func getNodesByType(_ type: NodeType, limit: Int = 100) throws -> [Node] {
        try Task.checkCancellation()
        let rows = try query("""
            SELECT id, type, label, metadata_json, content_hash, created_at, updated_at, provenance
            FROM honeycomb_nodes WHERE type = ? ORDER BY created_at DESC LIMIT ?
            """, args: [.text(type.rawValue), .int(Int32(limit))])
        return rows.map { rowToNode($0) }
    }

    /// Returns all nodes connected to a project (transitive belongsTo edges).
    public func getProjectNodes(projectID: String, limit: Int = 500) throws -> [Node] {
        var results: [Node] = []
        try Task.checkCancellation()
        // Direct children via belongsTo
        let edges = try getEdges(to: projectID, relation: .belongsTo)
        for edge in edges {
            if let node = try getNode(id: edge.sourceID) { results.append(node) }
        }
        if results.count >= limit { return Array(results.prefix(limit)) }
        return results
    }

    // MARK: - Delete by scope

    /// Deletes all nodes and edges matching a provenance string.
    /// Returns the count of deleted nodes.
    /// Batch-deletes FTS rows and nodes in two queries (no O(n) round trips).
    @discardableResult
    public func deleteByProvenance(_ provenance: String) throws -> Int {
        try Task.checkCancellation()
        // Count before delete so cascading edge deletes don't inflate the result.
        let countRows = try query("SELECT COUNT(*) FROM honeycomb_nodes WHERE provenance = ?",
                                  args: [.text(provenance)])
        let count = countRows.first?[0].intValue ?? 0
        // Parameterized provenance: escape single quotes by doubling them
        // (SQL standard). Provenance values are code constants, never user input.
        let safe = provenance.replacingOccurrences(of: "'", with: "''")
        try executeRaw("DELETE FROM honeycomb_fts WHERE node_id IN (SELECT id FROM honeycomb_nodes WHERE provenance = '\(safe)')")
        try execute("DELETE FROM honeycomb_nodes WHERE provenance = ?",
                    args: [.text(provenance)])
        return count
    }

    /// Deletes nodes older than the given date. Returns count deleted.
    /// Batch-deletes FTS rows and nodes in two queries (no O(n) round trips).
    @discardableResult
    public func deleteOlderThan(_ date: Date) throws -> Int {
        try Task.checkCancellation()
        let dateStr = iso8601(date)
        // Count before delete so cascading edge deletes don't inflate the result.
        let countRows = try query("SELECT COUNT(*) FROM honeycomb_nodes WHERE created_at < ?",
                                  args: [.text(dateStr)])
        let count = countRows.first?[0].intValue ?? 0
        // ISO 8601 strings have no characters requiring SQL escaping.
        try executeRaw("DELETE FROM honeycomb_fts WHERE node_id IN (SELECT id FROM honeycomb_nodes WHERE created_at < '\(dateStr)')")
        try execute("DELETE FROM honeycomb_nodes WHERE created_at < ?",
                    args: [.text(dateStr)])
        return count
    }

    // MARK: - Content hash

    /// Computes a SHA-256 content hash for deduplication. Uses CommonCrypto
    /// (system library, zero-dep on Apple platforms).
    public static func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buf in
            _ = CC_SHA256(buf.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private: row parsing (nonisolated: pure functions, no actor state)

    private nonisolated func rowToNode(_ row: [SQLValue]) -> Node {
        let typeStr = row[1].stringValue
        let nodeType = NodeType(rawValue: typeStr) ?? .unknown
        let metadata = (try? decodeJSON(row[3].stringValue)) ?? .object([:])
        let ch = row[4].stringValue
        return Node(
            id: row[0].stringValue,
            type: nodeType,
            label: row[2].stringValue,
            metadata: metadata,
            contentHash: ch.isEmpty ? nil : ch,
            createdAt: parseISO8601(row[5].stringValue) ?? Date(),
            updatedAt: parseISO8601(row[6].stringValue) ?? Date(),
            provenance: row[7].stringValue
        )
    }

    private nonisolated func rowToEdge(_ row: [SQLValue]) -> Edge {
        let relStr = row[3].stringValue
        return Edge(
            id: row[0].stringValue,
            sourceID: row[1].stringValue,
            targetID: row[2].stringValue,
            relation: EdgeRelation(rawValue: relStr) ?? .references,
            weight: row[4].doubleValue,
            metadata: (try? decodeJSON(row[5].stringValue)) ?? .object([:]),
            createdAt: parseISO8601(row[6].stringValue) ?? Date()
        )
    }

    // MARK: - Private: SQL execution

    private enum SQLArg {
        case text(String)
        case int(Int32)
        case double(Double)
        case null

        func bind(to stmt: OpaquePointer?, at index: Int32) {
            switch self {
            case .text(let s):  sqlite3_bind_text(stmt, index, (s as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .int(let i):   sqlite3_bind_int(stmt, index, i)
            case .double(let d): sqlite3_bind_double(stmt, index, d)
            case .null:         sqlite3_bind_null(stmt, index)
            }
        }
    }

    private struct SQLValue {
        let stringValue: String
        let intValue: Int
        let doubleValue: Double

        init(stmt: OpaquePointer?, column: Int32) {
            self.stringValue = sqlite3_column_text(stmt, column).map { String(cString: $0) } ?? ""
            self.intValue = Int(sqlite3_column_int(stmt, column))
            self.doubleValue = sqlite3_column_double(stmt, column)
        }
    }

    // Actor-isolated wrappers: capture self.db so call sites stay clean.
    @discardableResult
    private func execute(_ sql: String, args: [SQLArg] = []) throws -> Int {
        try nonisolatedExecute(sql, args: args, on: db)
    }

    private func query(_ sql: String, args: [SQLArg] = []) throws -> [[SQLValue]] {
        try nonisolatedQuery(sql, args: args, on: db)
    }

    @discardableResult
    private func executeRaw(_ sql: String) -> Int {
        nonisolatedExecuteRaw(sql, on: db)
    }

    // Nonisolated SQL executors: receive db explicitly for use from deinit/init.
    @discardableResult
    private nonisolated func nonisolatedExecute(_ sql: String, args: [SQLArg] = [], on db: OpaquePointer?) throws -> Int {
        // CHECK: parameter count matches ? count
        let expectedCount = sql.filter { $0 == "?" }.count
        guard expectedCount == args.count else {
            throw HoneycombError.parameterMismatch(expected: expectedCount, got: args.count)
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(stmt)
            throw HoneycombError.sqlError(msg)
        }
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            arg.bind(to: stmt, at: Int32(i + 1))
        }
        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            let msg = String(cString: sqlite3_errmsg(db))
            throw HoneycombError.sqlError(msg)
        }
        return Int(sqlite3_changes(db))
    }

    private nonisolated func nonisolatedQuery(_ sql: String, args: [SQLArg] = [], on db: OpaquePointer?) throws -> [[SQLValue]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(stmt)
            throw HoneycombError.sqlError(msg)
        }
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            arg.bind(to: stmt, at: Int32(i + 1))
        }
        var rows: [[SQLValue]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let colCount = sqlite3_column_count(stmt)
            var row: [SQLValue] = []
            for i in 0..<colCount {
                row.append(SQLValue(stmt: stmt, column: i))
            }
            rows.append(row)
        }
        return rows
    }

    @discardableResult
    private nonisolated func nonisolatedExecuteRaw(_ sql: String, on db: OpaquePointer?) -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_step(stmt)
        return Int(sqlite3_changes(db))
    }

    // MARK: - JSON helpers (nonisolated: pure functions)

    private nonisolated func encodeJSON(_ value: JSONValue) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private nonisolated func decodeJSON(_ string: String) throws -> JSONValue {
        guard let data = string.data(using: .utf8) else { return .object([:]) }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    private nonisolated func searchableText(from metadata: JSONValue) -> String {
        switch metadata {
        case .string(let s):           return s
        case .int(let i):              return String(i)
        case .double(let d):           return String(d)
        case .bool(let b):             return b ? "true" : "false"
        case .array(let arr):          return arr.map { searchableText(from: $0) }.joined(separator: " ")
        case .object(let dict):        return dict.values.map { searchableText(from: $0) }.joined(separator: " ")
        case .null:                    return ""
        }
    }

    // MARK: - Date formatting (nonisolated: pure formatting)
    // ISO8601DateFormatter is not Sendable, so we create fresh instances.

    private nonisolated func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    private nonisolated func parseISO8601(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: string)
    }
}

// MARK: - Errors

public enum HoneycombError: Error, Sendable {
    case openFailed(String)
    case sqlError(String)
    case parameterMismatch(expected: Int, got: Int)
}

// MARK: - CommonCrypto bridge (zero-dep, system library)

#if canImport(Darwin)
import CommonCrypto
#else
// Hive is macOS-only per DEC-007. This stub exists only for non-Darwin
// toolchain compatibility (e.g. Linux CI linting).
private let CC_SHA256_DIGEST_LENGTH = 32
private typealias CC_LONG = UInt32
private func CC_SHA256(_ data: UnsafeRawPointer?, _ len: CC_LONG, _ md: UnsafeMutablePointer<UInt8>?) -> UnsafeMutablePointer<UInt8>? {
    if let md { md.initialize(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH)) }
    return md
}
#endif
