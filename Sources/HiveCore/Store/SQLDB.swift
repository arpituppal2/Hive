import Foundation
import SQLite3

/// Thin SQLite3 wrapper. System libsqlite3 (has FTS5 on macOS).
public final class SQLDB: @unchecked Sendable {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "hive.sql")

    public enum SQLError: Error, CustomStringConvertible {
        case open(String)
        case exec(String, String)
        case prepare(String, String)
        public var description: String {
            switch self {
            case .open(let m): return "sqlite open: \(m)"
            case .exec(let sql, let m): return "sqlite exec [\(sql.prefix(60))]: \(m)"
            case .prepare(let sql, let m): return "sqlite prepare [\(sql.prefix(60))]: \(m)"
            }
        }
    }

    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw SQLError.open(msg)
        }
        db = handle
        try? exec("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA foreign_keys=ON;")
    }

    deinit { if let db { sqlite3_close_v2(db) } }

    public func exec(_ sql: String) throws {
        try queue.sync {
            var err: UnsafeMutablePointer<CChar>?
            guard sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK else {
                let msg = err.map { String(cString: $0) } ?? "unknown"
                sqlite3_free(err)
                throw SQLError.exec(sql, msg)
            }
        }
    }

    /// Runs `body` with a prepared statement bound via `bind(index1based, stmt)`.
    public func query<T>(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil,
                         row: (OpaquePointer) throws -> T) throws -> [T] {
        try queue.sync {
            var maybeStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &maybeStmt, nil) == SQLITE_OK,
                  let stmt = maybeStmt else {
                throw SQLError.prepare(sql, String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }
            bind?(stmt)
            var out: [T] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                out.append(try row(stmt))
            }
            return out
        }
    }

    public func run(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil) throws {
        _ = try query(sql, bind: bind) { (_: OpaquePointer) -> Bool in false }
    }

    public func lastInsertRowID() -> Int64 { queue.sync { sqlite3_last_insert_rowid(db) } }

    // Binding helpers
    public static func bindText(_ stmt: OpaquePointer, _ i: Int32, _ s: String) {
        sqlite3_bind_text(stmt, i, s, -1, SQLITE_TRANSIENT)
    }
    public static func bindInt(_ stmt: OpaquePointer, _ i: Int32, _ v: Int64) {
        sqlite3_bind_int64(stmt, i, v)
    }
    public static func bindDouble(_ stmt: OpaquePointer, _ i: Int32, _ v: Double) {
        sqlite3_bind_double(stmt, i, v)
    }
}

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
