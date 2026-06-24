import Foundation

/// A single, version-stamped database migration.
///
/// Migrations are append-only: once a version ships its `sql` must never change,
/// otherwise the recorded checksum in `schema_migrations` will no longer match.
public struct HiveSchemaMigration: Sendable, Hashable {
    public let version: Int
    public let description: String
    public let sql: String

    public init(version: Int, description: String, sql: String) {
        self.version = version
        self.description = description
        self.sql = sql
    }
}

/// Declarative reference of the canonical Hive database schema (Prompt 8).
///
/// This type is intentionally self-contained: it does **not** touch the live
/// `HiveStore` SQLite layer. It exists as a spec + migration model that can be
/// wired into a future canonical store without disturbing the working code.
/// All SQL here is plain text and carries no Swift escapes.
public enum HiveCanonicalSchema {
    /// The current canonical schema version.
    public static let currentVersion = 8

    /// The full canonical schema as a single SQL script.
    ///
    /// Includes connection pragmas and `CREATE TABLE IF NOT EXISTS` / index /
    /// trigger statements for every canonical table. Because every statement is
    /// idempotent (`IF NOT EXISTS`), this script is safe to run against a fresh
    /// database to bootstrap it directly to `currentVersion`.
    public static let createStatements: String = """
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;
    PRAGMA synchronous = NORMAL;
    PRAGMA cache_size = -32000;
    PRAGMA temp_store = MEMORY;
    PRAGMA mmap_size = 268435456;

    CREATE TABLE IF NOT EXISTS pending_sources (
        id TEXT PRIMARY KEY,
        raw_input TEXT NOT NULL,
        input_type TEXT NOT NULL DEFAULT 'unknown'
            CHECK (input_type IN ('googleDriveURL', 'webURL', 'localPath', 'downloadsFilename', 'unknown')),
        required_plugin TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'queued'
            CHECK (status IN ('queued', 'resolving', 'ready', 'failed', 'imported')),
        detail TEXT,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_pending_sources_status
        ON pending_sources (status, created_at);

    CREATE TABLE IF NOT EXISTS hive_nodes (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL
            CHECK (kind IN ('entity', 'claim', 'article', 'source', 'topic')),
        label TEXT NOT NULL,
        layer TEXT NOT NULL DEFAULT 'field'
            CHECK (layer IN ('field', 'colony', 'swarm')),
        salience REAL NOT NULL DEFAULT 0
            CHECK (salience >= 0 AND salience <= 1),
        confidence REAL NOT NULL DEFAULT 0
            CHECK (confidence >= 0 AND confidence <= 1),
        state TEXT NOT NULL DEFAULT 'active'
            CHECK (state IN ('active', 'dormant', 'retired')),
        payload_json TEXT NOT NULL DEFAULT '{}',
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_hive_nodes_kind
        ON hive_nodes (kind, state);
    CREATE INDEX IF NOT EXISTS idx_hive_nodes_layer
        ON hive_nodes (layer, salience DESC);

    CREATE TABLE IF NOT EXISTS hive_edges (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        target_id TEXT NOT NULL,
        relation TEXT NOT NULL,
        weight REAL NOT NULL DEFAULT 1
            CHECK (weight >= 0),
        state TEXT NOT NULL DEFAULT 'active'
            CHECK (state IN ('active', 'retired')),
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL,
        FOREIGN KEY (source_id) REFERENCES hive_nodes (id) ON DELETE CASCADE,
        FOREIGN KEY (target_id) REFERENCES hive_nodes (id) ON DELETE CASCADE
    );
    CREATE INDEX IF NOT EXISTS idx_hive_edges_source
        ON hive_edges (source_id, relation);
    CREATE INDEX IF NOT EXISTS idx_hive_edges_target
        ON hive_edges (target_id, relation);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_hive_edges_unique
        ON hive_edges (source_id, target_id, relation);

    CREATE TABLE IF NOT EXISTS colony_articles (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        slug TEXT NOT NULL UNIQUE,
        body_markdown TEXT NOT NULL DEFAULT '',
        summary TEXT,
        tags_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'draft'
            CHECK (status IN ('draft', 'published', 'archived')),
        revision INTEGER NOT NULL DEFAULT 1
            CHECK (revision >= 1),
        saturation INTEGER NOT NULL DEFAULT 0
            CHECK (saturation >= 0),
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_colony_articles_status
        ON colony_articles (status, updated_at DESC);

    CREATE VIRTUAL TABLE IF NOT EXISTS colony_fts USING fts5(
        title,
        body,
        tags,
        content='colony_articles',
        content_rowid='rowid'
    );

    CREATE TRIGGER IF NOT EXISTS colony_fts_ai AFTER INSERT ON colony_articles BEGIN
        INSERT INTO colony_fts (rowid, title, body, tags)
        VALUES (new.rowid, new.title, new.body_markdown, new.tags_json);
    END;
    CREATE TRIGGER IF NOT EXISTS colony_fts_ad AFTER DELETE ON colony_articles BEGIN
        INSERT INTO colony_fts (colony_fts, rowid, title, body, tags)
        VALUES ('delete', old.rowid, old.title, old.body_markdown, old.tags_json);
    END;
    CREATE TRIGGER IF NOT EXISTS colony_fts_au AFTER UPDATE ON colony_articles BEGIN
        INSERT INTO colony_fts (colony_fts, rowid, title, body, tags)
        VALUES ('delete', old.rowid, old.title, old.body_markdown, old.tags_json);
        INSERT INTO colony_fts (rowid, title, body, tags)
        VALUES (new.rowid, new.title, new.body_markdown, new.tags_json);
    END;

    CREATE TABLE IF NOT EXISTS swarm_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT 'New session',
        mode TEXT NOT NULL DEFAULT 'local'
            CHECK (mode IN ('local', 'cloud', 'hybrid')),
        state TEXT NOT NULL DEFAULT 'active'
            CHECK (state IN ('active', 'archived')),
        message_count INTEGER NOT NULL DEFAULT 0
            CHECK (message_count >= 0),
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_swarm_sessions_updated
        ON swarm_sessions (state, updated_at DESC);

    CREATE TABLE IF NOT EXISTS swarm_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL
            CHECK (role IN ('user', 'assistant', 'system', 'tool')),
        content TEXT NOT NULL,
        token_count INTEGER NOT NULL DEFAULT 0
            CHECK (token_count >= 0),
        sequence INTEGER NOT NULL DEFAULT 0,
        created_at REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES swarm_sessions (id) ON DELETE CASCADE
    );
    CREATE INDEX IF NOT EXISTS idx_swarm_messages_session
        ON swarm_messages (session_id, sequence);

    CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        description TEXT NOT NULL,
        checksum TEXT NOT NULL,
        applied_at REAL NOT NULL
    );

    CREATE TABLE IF NOT EXISTS app_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at REAL NOT NULL DEFAULT 0
    );
    """

    /// Pre-seeded `app_state` keys and their default values.
    public static let seedAppState: [(key: String, value: String)] = [
        (key: "last_active_view", value: "field"),
        (key: "extraction_detail_level", value: "balanced"),
        (key: "reaudit_cooldown_seconds", value: "90"),
        (key: "saturation_threshold", value: "2"),
        (key: "tag_vocabulary_json", value: seedTagVocabularyJSON)
    ]

    /// Seed tag vocabulary used to bootstrap `app_state.tag_vocabulary_json`.
    public static let seedTagVocabularyJSON: String = """
    ["person","place","organization","project","concept","event","tool","preference","goal","relationship"]
    """

    // MARK: - Migrations

    private static let migration2SQL = """
    ALTER TABLE hive_edges ADD COLUMN weight REAL NOT NULL DEFAULT 1;
    CREATE UNIQUE INDEX IF NOT EXISTS idx_hive_edges_unique
        ON hive_edges (source_id, target_id, relation);
    """

    private static let migration3SQL = """
    CREATE VIRTUAL TABLE IF NOT EXISTS colony_fts USING fts5(
        title,
        body,
        tags,
        content='colony_articles',
        content_rowid='rowid'
    );

    CREATE TRIGGER IF NOT EXISTS colony_fts_ai AFTER INSERT ON colony_articles BEGIN
        INSERT INTO colony_fts (rowid, title, body, tags)
        VALUES (new.rowid, new.title, new.body_markdown, new.tags_json);
    END;
    CREATE TRIGGER IF NOT EXISTS colony_fts_ad AFTER DELETE ON colony_articles BEGIN
        INSERT INTO colony_fts (colony_fts, rowid, title, body, tags)
        VALUES ('delete', old.rowid, old.title, old.body_markdown, old.tags_json);
    END;
    CREATE TRIGGER IF NOT EXISTS colony_fts_au AFTER UPDATE ON colony_articles BEGIN
        INSERT INTO colony_fts (colony_fts, rowid, title, body, tags)
        VALUES ('delete', old.rowid, old.title, old.body_markdown, old.tags_json);
        INSERT INTO colony_fts (rowid, title, body, tags)
        VALUES (new.rowid, new.title, new.body_markdown, new.tags_json);
    END;
    """

    private static let migration4SQL = """
    CREATE TABLE IF NOT EXISTS swarm_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT 'New session',
        mode TEXT NOT NULL DEFAULT 'local'
            CHECK (mode IN ('local', 'cloud', 'hybrid')),
        state TEXT NOT NULL DEFAULT 'active'
            CHECK (state IN ('active', 'archived')),
        message_count INTEGER NOT NULL DEFAULT 0
            CHECK (message_count >= 0),
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_swarm_sessions_updated
        ON swarm_sessions (state, updated_at DESC);

    CREATE TABLE IF NOT EXISTS swarm_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL
            CHECK (role IN ('user', 'assistant', 'system', 'tool')),
        content TEXT NOT NULL,
        token_count INTEGER NOT NULL DEFAULT 0
            CHECK (token_count >= 0),
        sequence INTEGER NOT NULL DEFAULT 0,
        created_at REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES swarm_sessions (id) ON DELETE CASCADE
    );
    CREATE INDEX IF NOT EXISTS idx_swarm_messages_session
        ON swarm_messages (session_id, sequence);
    """

    private static let migration5SQL = """
    CREATE TABLE IF NOT EXISTS app_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at REAL NOT NULL DEFAULT 0
    );
    """

    private static let migration6SQL = """
    ALTER TABLE pending_sources ADD COLUMN required_plugin TEXT NOT NULL DEFAULT '';
    CREATE INDEX IF NOT EXISTS idx_pending_sources_status
        ON pending_sources (status, created_at);
    """

    private static let migration7SQL = """
    ALTER TABLE colony_articles ADD COLUMN saturation INTEGER NOT NULL DEFAULT 0;
    CREATE INDEX IF NOT EXISTS idx_colony_articles_status
        ON colony_articles (status, updated_at DESC);
    """

    private static let migration8SQL = """
    ALTER TABLE hive_nodes ADD COLUMN state TEXT NOT NULL DEFAULT 'active';
    CREATE INDEX IF NOT EXISTS idx_hive_nodes_kind
        ON hive_nodes (kind, state);
    """

    /// The ordered list of migrations from version 1 through `currentVersion`.
    ///
    /// Version 1 bootstraps the full canonical schema; versions 2–8 represent the
    /// historical evolution applied to databases created before each feature
    /// landed. Each `sql` is a valid standalone script.
    public static let migrations: [HiveSchemaMigration] = [
        HiveSchemaMigration(
            version: 1,
            description: "Initial schema",
            sql: createStatements
        ),
        HiveSchemaMigration(
            version: 2,
            description: "Add hive_edges weight column and unique relation index",
            sql: migration2SQL
        ),
        HiveSchemaMigration(
            version: 3,
            description: "Add colony_fts FTS5 table and sync triggers",
            sql: migration3SQL
        ),
        HiveSchemaMigration(
            version: 4,
            description: "Add swarm_sessions and swarm_messages tables",
            sql: migration4SQL
        ),
        HiveSchemaMigration(
            version: 5,
            description: "Add app_state key/value table",
            sql: migration5SQL
        ),
        HiveSchemaMigration(
            version: 6,
            description: "Add pending_sources.required_plugin column",
            sql: migration6SQL
        ),
        HiveSchemaMigration(
            version: 7,
            description: "Add colony_articles.saturation column",
            sql: migration7SQL
        ),
        HiveSchemaMigration(
            version: 8,
            description: "Add hive_nodes.state column and lifecycle index",
            sql: migration8SQL
        )
    ]

    // MARK: - Checksums

    /// SHA256 hex digest of an arbitrary string, delegating to HiveCore's
    /// shared `Hashing` helper (which uses CryptoKit's `SHA256` under the hood).
    public static func sha256Hex(of string: String) -> String {
        Hashing.sha256(data: Data(string.utf8))
    }

    /// Stable checksum recorded in `schema_migrations` for a migration's SQL.
    public static func checksum(_ migration: HiveSchemaMigration) -> String {
        Hashing.sha256(data: Data(migration.sql.utf8))
    }
}

/// Reference data describing the Prompt 8 Part 4 query performance contracts.
///
/// Each entry pairs a named query with the maximum acceptable latency in
/// milliseconds. Intended for use by tests and runtime telemetry, not as a
/// runtime enforcement mechanism.
public enum HiveQueryContract {
    public static let contracts: [(query: String, maxMilliseconds: Int)] = [
        (query: "Load session list", maxMilliseconds: 20),
        (query: "Colony list", maxMilliseconds: 15),
        (query: "FTS search", maxMilliseconds: 10),
        (query: "graph nodes", maxMilliseconds: 25),
        (query: "edges for node", maxMilliseconds: 5),
        (query: "BM25 retrieval", maxMilliseconds: 30),
        (query: "insert node", maxMilliseconds: 8),
        (query: "batch 50 nodes", maxMilliseconds: 80),
        (query: "retirement update", maxMilliseconds: 3),
        (query: "app_state read", maxMilliseconds: 1)
    ]
}
