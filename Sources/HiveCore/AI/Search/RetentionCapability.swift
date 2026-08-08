import CryptoKit
import Foundation
import SQLite3

// MARK: - Durable retention capability

/// A narrowly scoped approval issued by the application approval controller.
///
/// This value is Codable so the same contract can later cross the local worker
/// protocol. A signed capability authenticates its claims to the injected
/// authority; it does not authenticate the current worker transport or its
/// process identity. Future IPC must authenticate the issuing process before
/// treating a capability as an authority-bearing message.
public struct RetentionCapability: Codable, Equatable, Sendable {
    public let nonce: String
    /// Stable identity of the approval issuer. This is signed as part of the capability.
    public let issuerID: String
    /// Base64 HMAC-SHA256 over the canonical capability claims. Nil means legacy/unsigned.
    public let signature: String?
    /// Version of the issuer key used to sign this capability.
    public let keyVersion: Int?
    public let action: String
    public let retentionClass: String
    public let deletionScope: String
    public let sourceContentHash: String
    public let projectID: String?
    public let provenance: String
    public let issuedAt: Date
    public let expiresAt: Date

    public init(
        nonce: String = UUID().uuidString,
        issuerID: String = "legacy-unverified",
        signature: String? = nil,
        keyVersion: Int? = nil,
        action: String = "research_source.persist",
        retentionClass: String,
        deletionScope: String,
        sourceContentHash: String,
        projectID: String?,
        provenance: String,
        issuedAt: Date = Date(),
        expiresAt: Date
    ) {
        self.nonce = nonce
        self.issuerID = issuerID
        self.signature = signature
        self.keyVersion = keyVersion
        self.action = action
        self.retentionClass = retentionClass
        self.deletionScope = deletionScope
        self.sourceContentHash = sourceContentHash
        self.projectID = projectID
        self.provenance = provenance
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }

    private enum CodingKeys: String, CodingKey {
        case nonce, issuerID, signature, keyVersion, action, retentionClass, deletionScope
        case sourceContentHash, projectID, provenance, issuedAt, expiresAt
    }

    /// Older journal records did not carry issuer metadata. Decode them as
    /// explicitly unverified so callers can fail closed instead of silently
    /// treating a legacy capability as authenticated.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nonce = try container.decode(String.self, forKey: .nonce)
        issuerID = try container.decodeIfPresent(String.self, forKey: .issuerID) ?? "legacy-unverified"
        signature = try container.decodeIfPresent(String.self, forKey: .signature)
        keyVersion = try container.decodeIfPresent(Int.self, forKey: .keyVersion)
        action = try container.decode(String.self, forKey: .action)
        retentionClass = try container.decode(String.self, forKey: .retentionClass)
        deletionScope = try container.decode(String.self, forKey: .deletionScope)
        sourceContentHash = try container.decode(String.self, forKey: .sourceContentHash)
        projectID = try container.decodeIfPresent(String.self, forKey: .projectID)
        provenance = try container.decode(String.self, forKey: .provenance)
        issuedAt = try container.decode(Date.self, forKey: .issuedAt)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
    }

    /// Basic shape validation independent of a requested payload.
    public func validate(at now: Date = Date()) throws {
        guard !nonce.isEmpty, nonce.utf8.count <= 128,
              !nonce.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
            throw RetentionCapabilityError.invalid("nonce is empty, too long, or contains controls")
        }
        guard !issuerID.isEmpty, issuerID.utf8.count <= 256,
              !issuerID.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
            throw RetentionCapabilityError.invalid("issuer ID is empty, too long, or contains controls")
        }
        guard action == "research_source.persist" else {
            throw RetentionCapabilityError.invalid("capability action is not research_source.persist")
        }
        guard !retentionClass.isEmpty, retentionClass.utf8.count <= 32 else {
            throw RetentionCapabilityError.invalid("retention class is empty or too long")
        }
        guard ["this_source", "provenance", "project"].contains(deletionScope) else {
            throw RetentionCapabilityError.invalid("deletion scope is not supported")
        }
        guard sourceContentHash.count == 64,
              sourceContentHash == sourceContentHash.lowercased(),
              sourceContentHash.allSatisfy(\.isHexDigit) else {
            throw RetentionCapabilityError.invalid("source content hash must be lowercase SHA-256")
        }
        guard !provenance.isEmpty, provenance.utf8.count <= 256 else {
            throw RetentionCapabilityError.invalid("provenance is empty or too long")
        }
        guard issuedAt <= now else {
            throw RetentionCapabilityError.invalid("capability was issued in the future")
        }
        guard expiresAt > issuedAt else {
            throw RetentionCapabilityError.invalid("capability expiry must be after issuance")
        }
        guard expiresAt > now else {
            throw RetentionCapabilityError.expired
        }
    }
}

/// The approval authority used by the Swift supervisor. The key is injected
/// deliberately: production should obtain it from Keychain/Secure Enclave,
/// while tests can use an ephemeral key. This type does not claim to
/// authenticate the Rust process or the current NDJSON transport.
public struct RetentionCapabilityAuthority: Sendable {
    public let issuerID: String
    public let keyVersion: Int
    private let key: SymmetricKey

    public init(key: SymmetricKey, issuerID: String, keyVersion: Int = 1) throws {
        guard keyVersion > 0 else {
            throw RetentionCapabilityError.invalid("key version must be positive")
        }
        guard !issuerID.isEmpty, issuerID.utf8.count <= 256,
              !issuerID.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
            throw RetentionCapabilityError.invalid("issuer ID is empty, too long, or contains controls")
        }
        self.key = key
        self.issuerID = issuerID
        self.keyVersion = keyVersion
    }

    /// Test/development convenience only. New capabilities are always versioned.
    public static func random(issuerID: String = "hive-approval-controller") throws -> Self {
        try Self(key: SymmetricKey(size: .bits256), issuerID: issuerID, keyVersion: 1)
    }

    /// Signs an already-shaped capability, binding every authorization claim
    /// including nonce, issuer, project, provenance, and expiry.
    public func issue(_ capability: RetentionCapability) throws -> RetentionCapability {
        guard capability.issuerID == issuerID else {
            throw RetentionCapabilityError.issuerMismatch
        }
        guard capability.keyVersion == nil || capability.keyVersion == keyVersion else {
            throw RetentionCapabilityError.keyVersionMismatch
        }
        let versioned = RetentionCapability(
            nonce: capability.nonce,
            issuerID: capability.issuerID,
            signature: nil,
            keyVersion: keyVersion,
            action: capability.action,
            retentionClass: capability.retentionClass,
            deletionScope: capability.deletionScope,
            sourceContentHash: capability.sourceContentHash,
            projectID: capability.projectID,
            provenance: capability.provenance,
            issuedAt: capability.issuedAt,
            expiresAt: capability.expiresAt
        )
        try versioned.validate()
        let signature = try Self.signature(for: versioned, key: key)
        return RetentionCapability(
            nonce: versioned.nonce,
            issuerID: versioned.issuerID,
            signature: signature,
            keyVersion: versioned.keyVersion,
            action: capability.action,
            retentionClass: capability.retentionClass,
            deletionScope: capability.deletionScope,
            sourceContentHash: capability.sourceContentHash,
            projectID: capability.projectID,
            provenance: capability.provenance,
            issuedAt: capability.issuedAt,
            expiresAt: capability.expiresAt
        )
    }

    /// Verifies issuer identity and signature before a capability is consumed.
    public func verify(_ capability: RetentionCapability, at now: Date = Date()) throws {
        try capability.validate(at: now)
        guard capability.issuerID == issuerID else {
            throw RetentionCapabilityError.issuerMismatch
        }
        guard capability.keyVersion == keyVersion else {
            throw RetentionCapabilityError.keyVersionMismatch
        }
        guard let encoded = capability.signature,
              let supplied = Data(base64Encoded: encoded),
              supplied.count == 32 else {
            throw RetentionCapabilityError.signatureMissing
        }
        let claimsData = try Self.claimsData(for: capability)
        guard HMAC<SHA256>.isValidAuthenticationCode(
            supplied,
            authenticating: claimsData,
            using: key
        ) else {
            throw RetentionCapabilityError.signatureInvalid
        }
    }

    private static func signature(for capability: RetentionCapability, key: SymmetricKey) throws -> String {
        let claimsData = try claimsData(for: capability)
        return Data(HMAC<SHA256>.authenticationCode(for: claimsData, using: key)).base64EncodedString()
    }

    private static func claimsData(for capability: RetentionCapability) throws -> Data {
        guard let keyVersion = capability.keyVersion, keyVersion > 0 else {
            throw RetentionCapabilityError.keyVersionMismatch
        }
        let claims = SigningClaims(
            nonce: capability.nonce,
            issuerID: capability.issuerID,
            keyVersion: keyVersion,
            action: capability.action,
            retentionClass: capability.retentionClass,
            deletionScope: capability.deletionScope,
            sourceContentHash: capability.sourceContentHash,
            projectID: capability.projectID,
            provenance: capability.provenance,
            issuedAtMS: Self.milliseconds(capability.issuedAt),
            expiresAtMS: Self.milliseconds(capability.expiresAt)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(claims)
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    private struct SigningClaims: Codable, Sendable {
        let nonce: String
        let issuerID: String
        let keyVersion: Int
        let action: String
        let retentionClass: String
        let deletionScope: String
        let sourceContentHash: String
        let projectID: String?
        let provenance: String
        let issuedAtMS: Int64
        let expiresAtMS: Int64
    }
}

public enum RetentionCapabilityError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalid(String)
    case issuerMismatch
    case keyVersionMismatch
    case signatureMissing
    case bindingConflict
    case signatureInvalid
    case expired
    case replayed
    case storage(String)

    public var description: String {
        switch self {
        case .invalid(let message): return "invalid retention capability: \(message)"
        case .issuerMismatch: return "retention capability issuer does not match the approval authority"
        case .keyVersionMismatch: return "retention capability key version does not match the approval authority"
        case .signatureMissing: return "retention capability has no approval signature"
        case .bindingConflict: return "retention capability is bound to a different recovery event"
        case .signatureInvalid: return "retention capability approval signature is invalid"
        case .expired: return "retention capability has expired"
        case .replayed: return "retention capability has already been consumed"
        case .storage(let message): return "retention capability storage failed: \(message)"
        }
    }
}

/// Durable, actor-isolated nonce consumption for single-use capabilities.
///
/// A file-backed registry is required for production. `:memory:` is supported
/// only for isolated tests. The nonce table intentionally stores a reservation
/// as soon as it is accepted: a process crash burns the grant rather than
/// risking replay. The adapter may release a reservation only when Honeycomb
/// confirms that no source was written.
public actor RetentionCapabilityRegistry {
    private static let currentSchemaVersion: Int32 = 2
    private nonisolated(unsafe) var db: OpaquePointer?

    /// Opens a registry at `path`. Pass `:memory:` only for tests.
    public init(path: String) throws {
        var localDB: OpaquePointer?
        guard sqlite3_open(path, &localDB) == SQLITE_OK else {
            let message = localDB.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
            if let localDB { sqlite3_close(localDB) }
            throw RetentionCapabilityError.storage("open failed: \(message)")
        }
        self.db = localDB
        guard sqlite3_exec(localDB, "PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=5000;", nil, nil, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(localDB))
            sqlite3_close(localDB)
            throw RetentionCapabilityError.storage("pragma failed: \(message)")
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

    /// Atomically reserves a previously validated capability nonce. A unique
    /// primary key makes concurrent and post-restart reuse fail closed.
    public func reserve(_ nonce: String) throws {
        guard let db else {
            throw RetentionCapabilityError.storage("database is closed")
        }
        var statement: OpaquePointer?
        let sql = "INSERT INTO retention_capabilities (nonce, reserved_at) VALUES (?, ?);"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (nonce as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        let result = sqlite3_step(statement)
        if result == SQLITE_CONSTRAINT, Self.isNonceUniquenessViolation(on: db) {
            throw RetentionCapabilityError.replayed
        }
        guard result == SQLITE_DONE else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
    }

    /// Releases a reservation only when no durable source was written. This is
    /// intentionally not used after a ledger failure or process restart.
    public func release(_ nonce: String) throws {
        guard let db else {
            throw RetentionCapabilityError.storage("database is closed")
        }
        var statement: OpaquePointer?
        _ = try executeBinding(
            "DELETE FROM retention_capability_bindings WHERE nonce = ?;",
            values: [nonce],
            on: db
        )
        let sql = "DELETE FROM retention_capabilities WHERE nonce = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (nonce as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
    }

    /// Binds a reserved approval to the exact recovery journal and audit event.
    /// Repeating the same binding is idempotent; transplanting a nonce to a
    /// different journal/event is rejected.
    public func bind(_ nonce: String, journalID: String, eventID: String) throws {
        guard let db else {
            throw RetentionCapabilityError.storage("database is closed")
        }
        guard try isReserved(nonce) else {
            throw RetentionCapabilityError.bindingConflict
        }
        if let existing = try binding(for: nonce) {
            guard existing.journalID == journalID, existing.eventID == eventID else {
                throw RetentionCapabilityError.bindingConflict
            }
            return
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "INSERT INTO retention_capability_bindings (nonce, journal_id, event_id) VALUES (?, ?, ?);",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in [nonce, journalID, eventID].enumerated() {
            sqlite3_bind_text(
                statement,
                Int32(index + 1),
                (value as NSString).utf8String,
                -1,
                unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            )
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
    }

    /// Removes a binding only when the exact binding is supplied. This is used
    /// for pre-source failures; successful or ambiguous repairs keep it.
    public func unbind(_ nonce: String, journalID: String, eventID: String) throws {
        guard let db else {
            throw RetentionCapabilityError.storage("database is closed")
        }
        _ = try executeBinding(
            "DELETE FROM retention_capability_bindings WHERE nonce = ? AND journal_id = ? AND event_id = ?;",
            values: [nonce, journalID, eventID],
            on: db
        )
    }

    /// Returns whether this app-owned registry has already reserved a nonce.
    /// Reconciliation uses this as a membership check; it never reserves again,
    /// so a crash after reservation remains repairable without replaying consent.
    public func isReserved(_ nonce: String) throws -> Bool {
        guard let db else {
            throw RetentionCapabilityError.storage("database is closed")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "SELECT 1 FROM retention_capabilities WHERE nonce = ? LIMIT 1;",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(
            statement,
            1,
            (nonce as NSString).utf8String,
            -1,
            unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        )
        return sqlite3_step(statement) == SQLITE_ROW
    }

    public struct Binding: Sendable, Equatable {
        public let journalID: String
        public let eventID: String
    }

    public func binding(for nonce: String) throws -> Binding? {
        guard let db else {
            throw RetentionCapabilityError.storage("database is closed")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "SELECT journal_id, event_id FROM retention_capability_bindings WHERE nonce = ? LIMIT 1;",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (nonce as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let journal = sqlite3_column_text(statement, 0),
              let event = sqlite3_column_text(statement, 1) else {
            throw RetentionCapabilityError.storage("binding row contains null identity")
        }
        return Binding(journalID: String(cString: journal), eventID: String(cString: event))
    }

    public func consumedCount() throws -> Int {
        guard let db else {
            throw RetentionCapabilityError.storage("database is closed")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM retention_capabilities;", -1, &statement, nil) == SQLITE_OK else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private nonisolated static func runMigrations(on db: OpaquePointer?) throws {
        let version = try currentUserVersion(on: db)
        guard version <= currentSchemaVersion else {
            throw RetentionCapabilityError.storage("unsupported schema version \(version)")
        }
        if version < 1 {
            let schema = """
            BEGIN IMMEDIATE;
            CREATE TABLE IF NOT EXISTS retention_capabilities (
                nonce TEXT PRIMARY KEY NOT NULL,
                reserved_at REAL NOT NULL
            );
            PRAGMA user_version = 1;
            COMMIT;
            """
            guard sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK else {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw RetentionCapabilityError.storage("schema migration failed: \(lastError(on: db))")
            }
        }
        if version < 2 {
            let bindingSchema = """
            BEGIN IMMEDIATE;
            CREATE TABLE IF NOT EXISTS retention_capability_bindings (
                nonce TEXT PRIMARY KEY NOT NULL,
                journal_id TEXT NOT NULL,
                event_id TEXT NOT NULL
            );
            PRAGMA user_version = 2;
            COMMIT;
            """
            guard sqlite3_exec(db, bindingSchema, nil, nil, nil) == SQLITE_OK else {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw RetentionCapabilityError.storage("binding migration failed: \(lastError(on: db))")
            }
        }
    }

    private nonisolated func executeBinding(
        _ sql: String,
        values: [String],
        on db: OpaquePointer?
    ) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), (value as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw RetentionCapabilityError.storage(Self.lastError(on: db))
        }
        return Int(sqlite3_changes(db))
    }

    private nonisolated static func currentUserVersion(on db: OpaquePointer?) throws -> Int32 {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK else {
            throw RetentionCapabilityError.storage("user_version read failed: \(lastError(on: db))")
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw RetentionCapabilityError.storage("user_version read failed: \(lastError(on: db))")
        }
        return sqlite3_column_int(statement, 0)
    }

    /// SQLite's Darwin headers do not expose all extended constraint macros,
    /// but the documented extended result codes are stable: PRIMARY KEY=6 and
    /// UNIQUE=8 under the SQLITE_CONSTRAINT base code. The message check keeps
    /// this scoped to this table/column rather than treating every constraint
    /// failure as a replay.
    private nonisolated static func isNonceUniquenessViolation(on db: OpaquePointer?) -> Bool {
        let extended = sqlite3_extended_errcode(db)
        let primaryKey = SQLITE_CONSTRAINT | (6 << 8)
        let unique = SQLITE_CONSTRAINT | (8 << 8)
        guard extended == primaryKey || extended == unique else { return false }
        return lastError(on: db).contains("retention_capabilities.nonce")
    }

    private nonisolated static func lastError(on db: OpaquePointer?) -> String {
        guard let db else { return "unknown SQLite error" }
        return String(cString: sqlite3_errmsg(db))
    }
}
