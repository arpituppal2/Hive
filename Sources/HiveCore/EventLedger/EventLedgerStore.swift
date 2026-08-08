import Foundation
import SQLite3

// MARK: - EventLedger: the append-only trust backbone

/// The Hive Browser's immutable audit trail. SQLite-backed, actor-isolated,
/// zero-external-dependency (system SQLite3 on macOS).
///
/// Every consequential event — model calls, user actions, tool executions,
/// consent decisions, permission grants, rollbacks — is recorded as an
/// append-only `LedgerEvent`. Events are never updated or deleted by
/// application code (delete-by-scope exists only for retention/pruning).
///
/// Per AGENTS.md §8.4, every event records:
/// - Event ID, time, actor, session, project, and parent action.
/// - User intent and typed action.
/// - Context identifiers, never raw secrets.
/// - Policy decision, trust level, and consent state.
/// - Tool version, environment, and output summary.
/// - Result, error, verification result, and rollback reference.
/// - Export and deletion scope.
///
/// The ledger is a trust feature, a debugging system, and the evidence
/// backbone for future partial handoffs — an agent can see what actually
/// happened instead of inferring it from UI state.
public actor EventLedgerStore {

    // MARK: - Public types

    /// An immutable audit event. Once written, never modified.
    public struct LedgerEvent: Sendable, Codable, Identifiable, Equatable {
        public let id: String
        public let timestamp: Date
        public let actor: String           // "user" | "swarm" | cell role rawValue
        public let sessionID: String?
        public let projectID: String?      // Honeycomb project node ID
        public let parentEventID: String?  // for event chains
        public let intent: String          // user intent / goal description
        public let actionKind: ActionKind
        public let actionTarget: String?   // file path, URL, node ID
        public let actionPreview: String?  // human-readable preview
        public let trustLevel: TrustLevel
        public let policyDecision: PolicyDecision
        public let consentState: ConsentState
        public let contextIDs: [String]    // Honeycomb node IDs (never raw data)
        public let modelProvider: String?  // if actionKind == .modelCall
        public let modelRole: String?      // ModelRole rawValue
        public let toolName: String?
        public let toolVersion: String?
        public let environment: String     // "swift-6", "macOS-27"
        public let outputSummary: String?
        public let result: EventResult
        public let errorDescription: String?
        public let verificationResult: VerificationResult
        public let rollbackEventID: String?
        public let durationMs: Int?
        public let createdAt: Date
        public let provenance: String      // "system" | "user" | "swarm"

        public init(
            id: String = UUID().uuidString,
            timestamp: Date = Date(),
            actor: String,
            sessionID: String? = nil,
            projectID: String? = nil,
            parentEventID: String? = nil,
            intent: String,
            actionKind: ActionKind,
            actionTarget: String? = nil,
            actionPreview: String? = nil,
            trustLevel: TrustLevel,
            policyDecision: PolicyDecision,
            consentState: ConsentState,
            contextIDs: [String] = [],
            modelProvider: String? = nil,
            modelRole: String? = nil,
            toolName: String? = nil,
            toolVersion: String? = nil,
            environment: String = "swift-6",
            outputSummary: String? = nil,
            result: EventResult,
            errorDescription: String? = nil,
            verificationResult: VerificationResult = .unchecked,
            rollbackEventID: String? = nil,
            durationMs: Int? = nil,
            createdAt: Date = Date(),
            provenance: String = "system"
        ) {
            self.id = id
            self.timestamp = timestamp
            self.actor = actor
            self.sessionID = sessionID
            self.projectID = projectID
            self.parentEventID = parentEventID
            self.intent = intent
            self.actionKind = actionKind
            self.actionTarget = actionTarget
            self.toolName = toolName
            self.toolVersion = toolVersion
            self.environment = environment
            self.outputSummary = outputSummary
            self.result = result
            self.errorDescription = errorDescription
            self.verificationResult = verificationResult
            self.rollbackEventID = rollbackEventID
            self.durationMs = durationMs
            self.createdAt = createdAt
            self.provenance = provenance
            self.actionPreview = actionPreview
            self.trustLevel = trustLevel
            self.policyDecision = policyDecision
            self.consentState = consentState
            self.contextIDs = contextIDs
            self.modelProvider = modelProvider
            self.modelRole = modelRole
        }

        /// Returns the same immutable event with a corrected Honeycomb context
        /// reference. Reconciliation uses this when a deduplicating source
        /// insert returns an existing node ID instead of the provisional ID.
        public func withContextIDs(_ contextIDs: [String]) -> LedgerEvent {
            LedgerEvent(
                id: id,
                timestamp: timestamp,
                actor: actor,
                sessionID: sessionID,
                projectID: projectID,
                parentEventID: parentEventID,
                intent: intent,
                actionKind: actionKind,
                actionTarget: actionTarget,
                actionPreview: actionPreview,
                trustLevel: trustLevel,
                policyDecision: policyDecision,
                consentState: consentState,
                contextIDs: contextIDs,
                modelProvider: modelProvider,
                modelRole: modelRole,
                toolName: toolName,
                toolVersion: toolVersion,
                environment: environment,
                outputSummary: outputSummary,
                result: result,
                errorDescription: errorDescription,
                verificationResult: verificationResult,
                rollbackEventID: rollbackEventID,
                durationMs: durationMs,
                createdAt: createdAt,
                provenance: provenance
            )
        }
    }

    /// Typed action categories. Every event falls into exactly one kind.
    public enum ActionKind: String, Sendable, Codable, CaseIterable {
        case capture              // page capture / extraction
        case research             // web research query
        case modelCall            // AI model invocation
        case codeRead             // reading repository files
        case codeWrite            // writing/changing repository files
        case codeTest             // running tests
        case browserNavigate      // navigating to a URL
        case browserAction        // clicking, scrolling, filling forms
        case fileRead             // reading a local file
        case fileWrite            // writing a local file
        case terminalCommand      // shell command execution
        case osAutomation         // AppleScript / Accessibility action
        case connectorSync        // external service sync
        case consentGranted       // user approved a permission
        case consentDenied        // user denied a permission
        case consentRevoked       // user revoked a permission
        case rollback             // rollback action
        case systemEvent          // internal system event (startup, shutdown, etc.)
    }

    /// Trust level per AGENTS.md §9.3.
    public enum TrustLevel: String, Sendable, Codable, CaseIterable {
        case t0 = "T0"  // Observe
        case t1 = "T1"  // Suggest
        case t2 = "T2"  // Assist
        case t3 = "T3"  // Act
        case t4 = "T4"  // Privileged
        case t5 = "T5"  // Developer
    }

    /// Policy decision: what the guard/policy engine decided.
    public enum PolicyDecision: String, Sendable, Codable, CaseIterable {
        case allowed
        case denied
        case requiresConfirmation
        case escalated            // escalated to council
    }

    /// Consent state: what the user actually did.
    public enum ConsentState: String, Sendable, Codable, CaseIterable {
        case auto                 // auto-approved (T0, T1)
        case approved             // user explicitly approved
        case denied               // user explicitly denied
        case pending              // awaiting user decision
        case notRequired          // no consent needed
    }

    /// Event outcome.
    public enum EventResult: String, Sendable, Codable, CaseIterable {
        case success
        case failure
        case partial
        case cancelled
    }

    /// Post-hoc verification by the auditor Cell.
    public enum VerificationResult: String, Sendable, Codable, CaseIterable {
        case verified
        case disputed
        case unchecked
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
    /// durable-looking audit surface after disk storage fails.
    public nonisolated let isEphemeral: Bool

    // MARK: - Init

    /// Opens or creates the EventLedger database at `path`.
    public init(path: String) throws {
        self.isEphemeral = path == ":memory:"
        var localDB: OpaquePointer?
        if sqlite3_open(path, &localDB) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(localDB))
            sqlite3_close(localDB)
            throw EventLedgerError.openFailed(msg)
        }
        self.db = localDB
        _ = nonisolatedExecuteRaw("PRAGMA journal_mode=WAL", on: localDB)
        _ = nonisolatedExecuteRaw("PRAGMA foreign_keys=ON", on: localDB)
        try runMigrations(on: localDB)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: - Migrations

    private nonisolated func runMigrations(on db: OpaquePointer?) throws {
        let current = currentUserVersion(on: db)
        if current < 1 {
            try migrateV1(on: db)
            setUserVersion(Self.currentSchemaVersion, on: db)
        }
    }

    private nonisolated func migrateV1(on db: OpaquePointer?) throws {
        try nonisolatedExecute("""
            CREATE TABLE IF NOT EXISTS event_ledger (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                actor TEXT NOT NULL,
                session_id TEXT,
                project_id TEXT,
                parent_event_id TEXT,
                intent TEXT NOT NULL,
                action_kind TEXT NOT NULL,
                action_target TEXT,
                action_preview TEXT,
                trust_level TEXT NOT NULL,
                policy_decision TEXT NOT NULL,
                consent_state TEXT NOT NULL,
                context_ids TEXT NOT NULL DEFAULT '',
                model_provider TEXT,
                model_role TEXT,
                tool_name TEXT,
                tool_version TEXT,
                environment TEXT NOT NULL DEFAULT 'swift-6',
                output_summary TEXT,
                result TEXT NOT NULL,
                error_description TEXT,
                verification_result TEXT NOT NULL DEFAULT 'unchecked',
                rollback_event_id TEXT,
                duration_ms INTEGER,
                created_at TEXT NOT NULL,
                provenance TEXT NOT NULL
            )
            """, on: db)
        // Indexes for common query patterns
        try nonisolatedExecute(
            "CREATE INDEX IF NOT EXISTS idx_events_timestamp ON event_ledger(timestamp)", on: db)
        try nonisolatedExecute(
            "CREATE INDEX IF NOT EXISTS idx_events_actor ON event_ledger(actor)", on: db)
        try nonisolatedExecute(
            "CREATE INDEX IF NOT EXISTS idx_events_session ON event_ledger(session_id)", on: db)
        try nonisolatedExecute(
            "CREATE INDEX IF NOT EXISTS idx_events_project ON event_ledger(project_id)", on: db)
        try nonisolatedExecute(
            "CREATE INDEX IF NOT EXISTS idx_events_action_kind ON event_ledger(action_kind)", on: db)
        try nonisolatedExecute(
            "CREATE INDEX IF NOT EXISTS idx_events_result ON event_ledger(result)", on: db)
        try nonisolatedExecute(
            "CREATE INDEX IF NOT EXISTS idx_events_trust_level ON event_ledger(trust_level)", on: db)
        try nonisolatedExecute(
            "CREATE INDEX IF NOT EXISTS idx_events_parent ON event_ledger(parent_event_id)", on: db)
        try nonisolatedExecute(
            "CREATE INDEX IF NOT EXISTS idx_events_created_at ON event_ledger(created_at)", on: db)
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

    // MARK: - Write (append-only)

    /// Records an event. Events are immutable — once written, they cannot be
    /// updated or deleted through normal application code.
    /// - Returns: the recorded event.
    @discardableResult
    public func record(_ event: LedgerEvent) throws -> LedgerEvent {
        let contextIDsJSON: String
        if let data = try? JSONEncoder().encode(event.contextIDs),
           let str = String(data: data, encoding: .utf8) {
            contextIDsJSON = str
        } else {
            contextIDsJSON = "[]"
        }
        try execute("""
            INSERT INTO event_ledger (
                id, timestamp, actor, session_id, project_id, parent_event_id,
                intent, action_kind, action_target, action_preview,
                trust_level, policy_decision, consent_state, context_ids,
                model_provider, model_role, tool_name, tool_version,
                environment, output_summary, result, error_description,
                verification_result, rollback_event_id, duration_ms,
                created_at, provenance
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            args: [
                .text(event.id), .text(iso8601(event.timestamp)), .text(event.actor),
                .text(event.sessionID ?? ""), .text(event.projectID ?? ""),
                .text(event.parentEventID ?? ""), .text(event.intent),
                .text(event.actionKind.rawValue), .text(event.actionTarget ?? ""),
                .text(event.actionPreview ?? ""),
                .text(event.trustLevel.rawValue), .text(event.policyDecision.rawValue),
                .text(event.consentState.rawValue), .text(contextIDsJSON),
                .text(event.modelProvider ?? ""), .text(event.modelRole ?? ""),
                .text(event.toolName ?? ""), .text(event.toolVersion ?? ""),
                .text(event.environment), .text(event.outputSummary ?? ""),
                .text(event.result.rawValue), .text(event.errorDescription ?? ""),
                .text(event.verificationResult.rawValue), .text(event.rollbackEventID ?? ""),
                event.durationMs.map { .int(Int32($0)) } ?? .null,
                .text(iso8601(event.createdAt)), .text(event.provenance)
            ])
        return event
    }

    /// Records an event exactly once by its stable event ID.
    ///
    /// Reconciliation can safely call this repeatedly: an existing event is
    /// returned unchanged, while a genuinely new event is appended. The
    /// append-only invariant remains intact because this method never updates
    /// an existing row.
    @discardableResult
    public func recordIfAbsent(_ event: LedgerEvent) throws -> LedgerEvent {
        if let existing = try getEvent(id: event.id) {
            guard Self.isIdempotentlyEquivalent(existing, event) else {
                throw EventLedgerError.conflictingEvent(id: event.id)
            }
            return existing
        }
        do {
            return try record(event)
        } catch {
            // Another EventLedgerStore instance may have won the race between
            // the read and insert. Adopt it only if the exact event ID now
            // exists; otherwise preserve the original storage failure.
            if let existing = try getEvent(id: event.id) {
                guard Self.isIdempotentlyEquivalent(existing, event) else {
                    throw EventLedgerError.conflictingEvent(id: event.id)
                }
                return existing
            }
            throw error
        }
    }

    /// Compares the complete event payload while matching the millisecond
    /// precision used by the SQLite ISO-8601 serializer. JSON Codable dates
    /// can retain finer precision than the ledger wire representation; that
    /// serialization detail must not turn a legitimate retry into a conflict.
    private nonisolated static func isIdempotentlyEquivalent(_ lhs: LedgerEvent, _ rhs: LedgerEvent) -> Bool {
        lhs.id == rhs.id &&
        lhs.actor == rhs.actor &&
        lhs.sessionID == rhs.sessionID &&
        lhs.projectID == rhs.projectID &&
        lhs.parentEventID == rhs.parentEventID &&
        lhs.intent == rhs.intent &&
        lhs.actionKind == rhs.actionKind &&
        lhs.actionTarget == rhs.actionTarget &&
        lhs.actionPreview == rhs.actionPreview &&
        lhs.trustLevel == rhs.trustLevel &&
        lhs.policyDecision == rhs.policyDecision &&
        lhs.consentState == rhs.consentState &&
        lhs.contextIDs == rhs.contextIDs &&
        lhs.modelProvider == rhs.modelProvider &&
        lhs.modelRole == rhs.modelRole &&
        lhs.toolName == rhs.toolName &&
        lhs.toolVersion == rhs.toolVersion &&
        lhs.environment == rhs.environment &&
        lhs.outputSummary == rhs.outputSummary &&
        lhs.result == rhs.result &&
        lhs.errorDescription == rhs.errorDescription &&
        lhs.verificationResult == rhs.verificationResult &&
        lhs.rollbackEventID == rhs.rollbackEventID &&
        lhs.durationMs == rhs.durationMs &&
        lhs.provenance == rhs.provenance &&
        normalizedMilliseconds(lhs.timestamp) == normalizedMilliseconds(rhs.timestamp) &&
        normalizedMilliseconds(lhs.createdAt) == normalizedMilliseconds(rhs.createdAt)
    }

    private nonisolated static func normalizedMilliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    // MARK: - Read (query by any dimension)

    /// Retrieves a single event by ID.
    public func getEvent(id: String) throws -> LedgerEvent? {
        let rows = try query(
            "SELECT * FROM event_ledger WHERE id = ?", args: [.text(id)])
        return rows.first.map { rowToEvent($0) }
    }

    /// Returns all events, ordered by timestamp descending. Supports limit/offset.
    public func getEvents(limit: Int = 100, offset: Int = 0) throws -> [LedgerEvent] {
        let rows = try query(
            "SELECT * FROM event_ledger ORDER BY timestamp DESC LIMIT ? OFFSET ?",
            args: [.int(Int32(limit)), .int(Int32(offset))])
        return rows.map { rowToEvent($0) }
    }

    /// Returns events for a specific actor.
    public func getEvents(byActor actor: String, limit: Int = 100) throws -> [LedgerEvent] {
        let rows = try query(
            "SELECT * FROM event_ledger WHERE actor = ? ORDER BY timestamp DESC LIMIT ?",
            args: [.text(actor), .int(Int32(limit))])
        return rows.map { rowToEvent($0) }
    }

    /// Returns events for a specific session.
    public func getEvents(bySession sessionID: String, limit: Int = 100) throws -> [LedgerEvent] {
        let rows = try query(
            "SELECT * FROM event_ledger WHERE session_id = ? ORDER BY timestamp DESC LIMIT ?",
            args: [.text(sessionID), .int(Int32(limit))])
        return rows.map { rowToEvent($0) }
    }

    /// Returns events for a specific project.
    public func getEvents(byProject projectID: String, limit: Int = 100) throws -> [LedgerEvent] {
        let rows = try query(
            "SELECT * FROM event_ledger WHERE project_id = ? ORDER BY timestamp DESC LIMIT ?",
            args: [.text(projectID), .int(Int32(limit))])
        return rows.map { rowToEvent($0) }
    }

    /// Returns events of a specific action kind.
    public func getEvents(byActionKind kind: ActionKind, limit: Int = 100) throws -> [LedgerEvent] {
        let rows = try query(
            "SELECT * FROM event_ledger WHERE action_kind = ? ORDER BY timestamp DESC LIMIT ?",
            args: [.text(kind.rawValue), .int(Int32(limit))])
        return rows.map { rowToEvent($0) }
    }

    /// Returns events with a specific result.
    public func getEvents(byResult result: EventResult, limit: Int = 100) throws -> [LedgerEvent] {
        let rows = try query(
            "SELECT * FROM event_ledger WHERE result = ? ORDER BY timestamp DESC LIMIT ?",
            args: [.text(result.rawValue), .int(Int32(limit))])
        return rows.map { rowToEvent($0) }
    }

    /// Returns events at or above a given trust level.
    /// Uses numeric trust-level ordering (T0=0, T5=5) rather than lexicographic
    /// comparison to avoid fragility if levels beyond T5 are added.
    public func getEvents(minTrustLevel level: TrustLevel, limit: Int = 100) throws -> [LedgerEvent] {
        let allLevels = TrustLevel.allCases
        guard let minIndex = allLevels.firstIndex(of: level) else { return [] }
        let qualifying = allLevels[minIndex...].map { $0.rawValue }
        let placeholders = qualifying.map { _ in "?" }.joined(separator: ",")
        var args: [SQLArg] = qualifying.map { .text($0) }
        args.append(.int(Int32(limit)))
        let rows = try query(
            "SELECT * FROM event_ledger WHERE trust_level IN (\(placeholders)) ORDER BY timestamp DESC LIMIT ?",
            args: args)
        return rows.map { rowToEvent($0) }
    }

    /// Returns child events of a parent event (event chains).
    public func getChildEvents(of parentID: String, limit: Int = 100) throws -> [LedgerEvent] {
        let rows = try query(
            "SELECT * FROM event_ledger WHERE parent_event_id = ? ORDER BY timestamp ASC LIMIT ?",
            args: [.text(parentID), .int(Int32(limit))])
        return rows.map { rowToEvent($0) }
    }

    /// Returns events within a date range.
    public func getEvents(from start: Date, to end: Date, limit: Int = 500) throws -> [LedgerEvent] {
        let rows = try query(
            "SELECT * FROM event_ledger WHERE timestamp >= ? AND timestamp <= ? ORDER BY timestamp DESC LIMIT ?",
            args: [.text(iso8601(start)), .text(iso8601(end)), .int(Int32(limit))])
        return rows.map { rowToEvent($0) }
    }

    /// Returns events that failed (for debugging/recovery).
    public func getFailedEvents(limit: Int = 100) throws -> [LedgerEvent] {
        let rows = try query(
            "SELECT * FROM event_ledger WHERE result = 'failure' ORDER BY timestamp DESC LIMIT ?",
            args: [.int(Int32(limit))])
        return rows.map { rowToEvent($0) }
    }

    /// Returns events awaiting verification by the auditor.
    public func getUnverifiedEvents(limit: Int = 100) throws -> [LedgerEvent] {
        let rows = try query(
            "SELECT * FROM event_ledger WHERE verification_result = 'unchecked' ORDER BY timestamp DESC LIMIT ?",
            args: [.int(Int32(limit))])
        return rows.map { rowToEvent($0) }
    }

    /// Counts events, optionally filtered.
    public func countEvents(
        actionKind: ActionKind? = nil,
        result: EventResult? = nil,
        actor: String? = nil
    ) throws -> Int {
        var sql = "SELECT COUNT(*) FROM event_ledger WHERE 1=1"
        var args: [SQLArg] = []
        if let actionKind {
            sql += " AND action_kind = ?"
            args.append(.text(actionKind.rawValue))
        }
        if let result {
            sql += " AND result = ?"
            args.append(.text(result.rawValue))
        }
        if let actor {
            sql += " AND actor = ?"
            args.append(.text(actor))
        }
        let rows = try query(sql, args: args)
        return rows.first?[0].intValue ?? 0
    }

    // MARK: - Delete by scope (retention/pruning only)

    /// Deletes events matching a provenance string. Returns count deleted.
    /// Use for retention/pruning only — events are logically immutable.
    @discardableResult
    public func deleteByProvenance(_ provenance: String) throws -> Int {
        try Task.checkCancellation()
        let result = try execute(
            "DELETE FROM event_ledger WHERE provenance = ?",
            args: [.text(provenance)])
        return result
    }

    /// Deletes events older than the given date. Returns count deleted.
    /// Use for retention/pruning only.
    @discardableResult
    public func deleteOlderThan(_ date: Date) throws -> Int {
        try Task.checkCancellation()
        let result = try execute(
            "DELETE FROM event_ledger WHERE timestamp < ?",
            args: [.text(iso8601(date))])
        return result
    }

    /// Deletes ALL events. Use with extreme caution (T5).
    /// Returns count deleted.
    @discardableResult
    public func deleteAll() throws -> Int {
        let result = try execute("DELETE FROM event_ledger", args: [])
        return result
    }

    // MARK: - Private: row parsing

    private nonisolated func rowToEvent(_ row: [SQLValue]) -> LedgerEvent {
        let contextIDsRaw = row[13].stringValue
        let contextIDs: [String]
        if contextIDsRaw.isEmpty {
            contextIDs = []
        } else if let data = contextIDsRaw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([String].self, from: data) {
            contextIDs = arr
        } else {
            contextIDs = []
        }

        return LedgerEvent(
            id: row[0].stringValue,
            timestamp: parseISO8601(row[1].stringValue) ?? Date(),
            actor: row[2].stringValue,
            sessionID: nilIfEmpty(row[3].stringValue),
            projectID: nilIfEmpty(row[4].stringValue),
            parentEventID: nilIfEmpty(row[5].stringValue),
            intent: row[6].stringValue,
            actionKind: ActionKind(rawValue: row[7].stringValue) ?? .systemEvent,
            actionTarget: nilIfEmpty(row[8].stringValue),
            actionPreview: nilIfEmpty(row[9].stringValue),
            trustLevel: TrustLevel(rawValue: row[10].stringValue) ?? .t0,
            policyDecision: PolicyDecision(rawValue: row[11].stringValue) ?? .allowed,
            consentState: ConsentState(rawValue: row[12].stringValue) ?? .notRequired,
            contextIDs: contextIDs,
            modelProvider: nilIfEmpty(row[14].stringValue),
            modelRole: nilIfEmpty(row[15].stringValue),
            toolName: nilIfEmpty(row[16].stringValue),
            toolVersion: nilIfEmpty(row[17].stringValue),
            environment: row[18].stringValue,
            outputSummary: nilIfEmpty(row[19].stringValue),
            result: EventResult(rawValue: row[20].stringValue) ?? .failure,
            errorDescription: nilIfEmpty(row[21].stringValue),
            verificationResult: VerificationResult(rawValue: row[22].stringValue) ?? .unchecked,
            rollbackEventID: nilIfEmpty(row[23].stringValue),
            durationMs: row[24].intValue != 0 ? row[24].intValue : nil,
            createdAt: parseISO8601(row[25].stringValue) ?? Date(),
            provenance: row[26].stringValue
        )
    }

    // MARK: - Private: SQL execution (actor-isolated wrappers + nonisolated helpers)

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

    @discardableResult
    private nonisolated func nonisolatedExecute(_ sql: String, args: [SQLArg] = [], on db: OpaquePointer?) throws -> Int {
        let expectedCount = sql.filter { $0 == "?" }.count
        guard expectedCount == args.count else {
            throw EventLedgerError.parameterMismatch(expected: expectedCount, got: args.count)
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(stmt)
            throw EventLedgerError.sqlError(msg)
        }
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            arg.bind(to: stmt, at: Int32(i + 1))
        }
        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            let msg = String(cString: sqlite3_errmsg(db))
            throw EventLedgerError.sqlError(msg)
        }
        return Int(sqlite3_changes(db))
    }

    private nonisolated func nonisolatedQuery(_ sql: String, args: [SQLArg] = [], on db: OpaquePointer?) throws -> [[SQLValue]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(stmt)
            throw EventLedgerError.sqlError(msg)
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

    // MARK: - Date formatting

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

    private nonisolated func nilIfEmpty(_ s: String) -> String? {
        s.isEmpty ? nil : s
    }
}

// MARK: - Errors

public enum EventLedgerError: Error, Sendable, Equatable {
    case openFailed(String)
    case sqlError(String)
    case parameterMismatch(expected: Int, got: Int)
    case conflictingEvent(id: String)
}
