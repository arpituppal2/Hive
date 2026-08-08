import CryptoKit
import Foundation
import SQLite3

// MARK: - Research handoff recovery journal

/// Durable write-ahead record for the gap between Honeycomb and EventLedger.
///
/// The journal stores typed, already-validated values rather than raw browser
/// content. It is written before a source side effect and removed only after
/// the corresponding audit event is durably present. The two stores still do
/// not form a distributed transaction; this journal makes the gap visible and
/// repairable after a crash.
public actor HandoffRecoveryJournal {
    public struct Record: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let source: Source
        public let event: EventLedgerStore.LedgerEvent
        public let retentionCapability: RetentionCapability?
        public let createdAt: Date

        public init(
            id: String = UUID().uuidString,
            source: Source,
            event: EventLedgerStore.LedgerEvent,
            retentionCapability: RetentionCapability? = nil,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.source = source
            self.event = event
            self.retentionCapability = retentionCapability
            self.createdAt = createdAt
        }

        /// Recovery never needs page prose. Keep transport identity and
        /// lifecycle metadata, but prevent snippets/extracted text from
        /// entering the journal's durable payload.
        fileprivate func redactedForRecovery() -> Record {
            let redactedSource = Source(
                id: source.id,
                url: source.url,
                title: source.title,
                captureMethod: source.captureMethod,
                contentHash: source.contentHash,
                author: source.author,
                publishedDate: source.publishedDate,
                retrievalTimestamp: source.retrievalTimestamp,
                license: source.license,
                robotsStatus: source.robotsStatus,
                qualityScore: source.qualityScore,
                snippet: nil,
                extractedText: nil,
                extractorVersion: source.extractorVersion,
                createdAt: source.createdAt,
                updatedAt: source.updatedAt,
                provenance: source.provenance,
                requestedURL: source.requestedURL,
                redirectCount: source.redirectCount,
                httpStatus: source.httpStatus,
                contentType: source.contentType,
                bodySize: source.bodySize,
                retrievedAtUnixMS: source.retrievedAtUnixMS,
                expiresAtUnixMS: source.expiresAtUnixMS,
                retentionClass: source.retentionClass,
                deletionScope: source.deletionScope,
                extractionState: source.extractionState,
                citationReady: false
            )
            return Record(
                id: id,
                source: redactedSource,
                event: event,
                retentionCapability: retentionCapability,
                createdAt: createdAt
            )
        }
    }

    public enum JournalError: Error, Sendable, Equatable, CustomStringConvertible {
        case openFailed(String)
        case storage(String)
        case malformedRecord(String)
        case integrityFailure(String)

        public var description: String {
            switch self {
            case .openFailed(let message): return "handoff journal open failed: \(message)"
            case .storage(let message): return "handoff journal storage failed: \(message)"
            case .malformedRecord(let message): return "handoff journal record is malformed: \(message)"
            case .integrityFailure(let message): return "handoff journal integrity check failed: \(message)"
            }
        }
    }

    private static let currentSchemaVersion: Int32 = 2
    private nonisolated(unsafe) var db: OpaquePointer?

    /// Opens or creates a journal at `path`. Use `:memory:` only in tests.
    public init(path: String) throws {
        var localDB: OpaquePointer?
        guard sqlite3_open(path, &localDB) == SQLITE_OK else {
            let message = localDB.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
            if let localDB { sqlite3_close(localDB) }
            throw JournalError.openFailed(message)
        }
        self.db = localDB
        guard sqlite3_exec(localDB, "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000;", nil, nil, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(localDB))
            sqlite3_close(localDB)
            throw JournalError.storage("pragma failed: \(message)")
        }
        do {
            try Self.runMigrations(on: localDB)
        } catch {
            sqlite3_close(localDB)
            throw error
        }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    /// Adds a recovery record before any Honeycomb side effect.
    public func append(_ record: Record) throws {
        guard let db else { throw JournalError.storage("database is closed") }
        guard Self.isValidSourceHash(record.source.contentHash) else {
            throw JournalError.malformedRecord("source content hash must be a lowercase SHA-256")
        }
        let safeRecord = record.redactedForRecovery()
        let payload: String
        do {
            let data = try JSONEncoder().encode(safeRecord)
            guard let json = String(data: data, encoding: .utf8) else {
                throw JournalError.malformedRecord("record is not UTF-8 JSON")
            }
            payload = json
        } catch let error as JournalError {
            throw error
        } catch {
            throw JournalError.malformedRecord(String(describing: error))
        }
        try execute(
            "INSERT INTO handoff_recovery (id, payload_json, payload_hash, created_at) VALUES (?, ?, ?, ?)",
            args: [.text(record.id), .text(payload), .text(Self.sha256(payload)), .double(record.createdAt.timeIntervalSince1970)],
            on: db
        )
    }

    /// Replaces a record after Honeycomb resolves a deduplicated source ID.
    public func replace(_ record: Record) throws {
        guard let db else { throw JournalError.storage("database is closed") }
        guard Self.isValidSourceHash(record.source.contentHash) else {
            throw JournalError.malformedRecord("source content hash must be a lowercase SHA-256")
        }
        let safeRecord = record.redactedForRecovery()
        let data: Data
        do { data = try JSONEncoder().encode(safeRecord) }
        catch { throw JournalError.malformedRecord(String(describing: error)) }
        guard let payload = String(data: data, encoding: .utf8) else {
            throw JournalError.malformedRecord("record is not UTF-8 JSON")
        }
        let changed = try execute(
            "UPDATE handoff_recovery SET payload_json = ?, payload_hash = ?, created_at = ? WHERE id = ?",
            args: [.text(payload), .text(Self.sha256(payload)), .double(record.createdAt.timeIntervalSince1970), .text(record.id)],
            on: db
        )
        guard changed == 1 else {
            throw JournalError.storage("recovery record \(record.id) does not exist")
        }
    }

    /// Returns pending records in creation order.
    public func pending() throws -> [Record] {
        guard let db else { throw JournalError.storage("database is closed") }
        let rows = try query(
            "SELECT payload_json, payload_hash FROM handoff_recovery ORDER BY created_at ASC, id ASC",
            args: [], on: db
        )
        return try rows.map { row in
            guard let payload = row.first, let expectedHash = row.dropFirst().first else {
                throw JournalError.malformedRecord("payload row is incomplete")
            }
            guard Self.sha256(payload) == expectedHash else {
                throw JournalError.integrityFailure("payload hash does not match record")
            }
            guard let data = payload.data(using: .utf8) else {
                throw JournalError.malformedRecord("payload is not UTF-8 JSON")
            }
            do { return try JSONDecoder().decode(Record.self, from: data) }
            catch { throw JournalError.malformedRecord(String(describing: error)) }
        }
    }

    public func remove(id: String) throws {
        guard let db else { throw JournalError.storage("database is closed") }
        _ = try execute("DELETE FROM handoff_recovery WHERE id = ?", args: [.text(id)], on: db)
    }

    public func count() throws -> Int {
        guard let db else { throw JournalError.storage("database is closed") }
        let rows = try query("SELECT COUNT(*) FROM handoff_recovery", args: [], on: db)
        guard let value = rows.first?.first, let count = Int(value) else {
            throw JournalError.storage("count query returned a non-integer value")
        }
        return count
    }

    private nonisolated static func runMigrations(on db: OpaquePointer?) throws {
        let version = try currentUserVersion(on: db)
        guard version <= currentSchemaVersion else {
            throw JournalError.storage("unsupported schema version \(version)")
        }
        if version < 1 {
            let schema = """
            BEGIN IMMEDIATE;
            CREATE TABLE IF NOT EXISTS handoff_recovery (
                id TEXT PRIMARY KEY NOT NULL,
                payload_json TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            PRAGMA user_version = 1;
            COMMIT;
            """
            guard sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK else {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw JournalError.storage("schema migration failed: \(lastError(on: db))")
            }
        }
        if version < 2 {
            // SQLite has no built-in sha256() function. Existing rows are
            // migrated below with a parameterized Swift pass instead.
            try migratePayloadHashes(on: db)
        }
    }

    private nonisolated static func migratePayloadHashes(on db: OpaquePointer?) throws {
        let hasHashColumn = try hasColumn("payload_hash", in: "handoff_recovery", on: db)
        guard sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil) == SQLITE_OK else {
            throw JournalError.storage("hash migration begin failed: \(lastError(on: db))")
        }
        var committed = false
        defer {
            if !committed {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            }
        }

        if !hasHashColumn {
            guard sqlite3_exec(db, "ALTER TABLE handoff_recovery ADD COLUMN payload_hash TEXT;", nil, nil, nil) == SQLITE_OK else {
                throw JournalError.storage("hash migration column failed: \(lastError(on: db))")
            }
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT id, payload_json FROM handoff_recovery", -1, &statement, nil) == SQLITE_OK else {
            throw JournalError.storage("hash migration read failed: \(lastError(on: db))")
        }
        var updates: [(String, String)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idPointer = sqlite3_column_text(statement, 0),
                  let payloadPointer = sqlite3_column_text(statement, 1) else {
                sqlite3_finalize(statement)
                throw JournalError.storage("hash migration encountered a null row")
            }
            updates.append((String(cString: idPointer), sha256(String(cString: payloadPointer))))
        }
        sqlite3_finalize(statement)

        for (id, hash) in updates {
            var update: OpaquePointer?
            guard sqlite3_prepare_v2(db, "UPDATE handoff_recovery SET payload_hash = ? WHERE id = ?", -1, &update, nil) == SQLITE_OK else {
                throw JournalError.storage("hash migration update failed: \(lastError(on: db))")
            }
            sqlite3_bind_text(update, 1, (hash as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(update, 2, (id as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            let result = sqlite3_step(update)
            sqlite3_finalize(update)
            guard result == SQLITE_DONE else {
                throw JournalError.storage("hash migration update failed: \(lastError(on: db))")
            }
        }
        guard sqlite3_exec(db, "PRAGMA user_version = 2;", nil, nil, nil) == SQLITE_OK else {
            throw JournalError.storage("hash migration version update failed: \(lastError(on: db))")
        }
        guard sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
            throw JournalError.storage("hash migration commit failed: \(lastError(on: db))")
        }
        committed = true
    }

    private nonisolated static func hasColumn(_ column: String, in table: String, on db: OpaquePointer?) throws -> Bool {
        // Both identifiers are private constants; keep this helper constrained
        // to the journal schema rather than accepting arbitrary SQL input.
        guard column == "payload_hash", table == "handoff_recovery" else {
            throw JournalError.storage("unsupported schema inspection")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(handoff_recovery);", -1, &statement, nil) == SQLITE_OK else {
            throw JournalError.storage("schema inspection failed: \(lastError(on: db))")
        }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 1), String(cString: name) == column {
                return true
            }
        }
        return false
    }

    private nonisolated static func isValidSourceHash(_ hash: String?) -> Bool {
        guard let hash, hash.count == 64,
              hash == hash.lowercased(),
              hash.allSatisfy(\.isHexDigit) else { return false }
        return true
    }

    private nonisolated static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func currentUserVersion(on db: OpaquePointer?) throws -> Int32 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK else {
            throw JournalError.storage("user_version read failed: \(lastError(on: db))")
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw JournalError.storage("user_version read failed: \(lastError(on: db))")
        }
        return sqlite3_column_int(statement, 0)
    }

    private enum SQLArg {
        case text(String)
        case double(Double)

        func bind(to statement: OpaquePointer?, at index: Int32) {
            switch self {
            case .text(let value):
                sqlite3_bind_text(statement, index, (value as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .double(let value):
                sqlite3_bind_double(statement, index, value)
            }
        }
    }

    @discardableResult
    private nonisolated func execute(_ sql: String, args: [SQLArg], on db: OpaquePointer?) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw JournalError.storage(Self.lastError(on: db))
        }
        defer { sqlite3_finalize(statement) }
        for (index, arg) in args.enumerated() {
            arg.bind(to: statement, at: Int32(index + 1))
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw JournalError.storage(Self.lastError(on: db))
        }
        return Int(sqlite3_changes(db))
    }

    private nonisolated func query(_ sql: String, args: [SQLArg], on db: OpaquePointer?) throws -> [[String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw JournalError.storage(Self.lastError(on: db))
        }
        defer { sqlite3_finalize(statement) }
        for (index, arg) in args.enumerated() {
            arg.bind(to: statement, at: Int32(index + 1))
        }
        var rows: [[String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String] = []
            for column in 0..<sqlite3_column_count(statement) {
                row.append(sqlite3_column_text(statement, column).map { String(cString: $0) } ?? "")
            }
            rows.append(row)
        }
        return rows
    }

    private nonisolated static func lastError(on db: OpaquePointer?) -> String {
        guard let db else { return "unknown SQLite error" }
        return String(cString: sqlite3_errmsg(db))
    }
}
