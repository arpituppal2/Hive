import Foundation
import SQLite3

/// Capture store: captures + spans (FTS5) + bookmarks + session tabs + settings KV.
/// Plaintext SQLite by W1 decision (FileVault reliance, disclosed in tester docs);
/// keychain-encrypted DB is a fast-follow ticket, not shipped here.
public final class CaptureStore: @unchecked Sendable {
    private let db: SQLDB

    public init(path: String) throws {
        db = try SQLDB(path: path)
        try migrate()
    }

    private func migrate() throws {
        try db.exec("""
        CREATE TABLE IF NOT EXISTS captures(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          url TEXT NOT NULL,
          title TEXT NOT NULL,
          text TEXT NOT NULL,
          word_count INTEGER NOT NULL,
          confidence REAL NOT NULL,
          version INTEGER NOT NULL,
          content_hash TEXT NOT NULL,
          captured_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_captures_url ON captures(url);
        CREATE VIRTUAL TABLE IF NOT EXISTS spans_fts USING fts5(text);
        CREATE TABLE IF NOT EXISTS spans(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          span_id TEXT NOT NULL UNIQUE,
          capture_id INTEGER NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
          capture_version INTEGER NOT NULL,
          idx INTEGER NOT NULL,
          char_start INTEGER NOT NULL,
          char_end INTEGER NOT NULL,
          fts_rowid INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_spans_capture ON spans(capture_id);
        CREATE TABLE IF NOT EXISTS bookmarks(
          url TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          created_at REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS session_tabs(
          ord INTEGER PRIMARY KEY,
          id TEXT NOT NULL,
          url TEXT NOT NULL,
          title TEXT NOT NULL,
          pinned INTEGER NOT NULL DEFAULT 0,
          active INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS settings(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );
        """)
    }

    // MARK: Captures

    /// Insert a capture and its spans (FTS rowids map to spans rows) in one pass.
    @discardableResult
    public func storeCapture(url: String, title: String, rawText: String, confidence: Double) throws -> Capture {
        let normalized = Self.normalize(rawText)
        let version = (try latestVersion(url: url)) + 1
        let now = Date().timeIntervalSince1970
        let words = normalized.split(whereSeparator: \.isWhitespace).count
        try db.run("INSERT INTO captures(url,title,text,word_count,confidence,version,content_hash,captured_at) VALUES(?,?,?,?,?,?,?,?);") { stmt in
            SQLDB.bindText(stmt, 1, url); SQLDB.bindText(stmt, 2, title)
            SQLDB.bindText(stmt, 3, normalized); SQLDB.bindInt(stmt, 4, Int64(words))
            SQLDB.bindDouble(stmt, 5, confidence); SQLDB.bindInt(stmt, 6, Int64(version))
            SQLDB.bindText(stmt, 7, Self.contentHash(normalized)); SQLDB.bindDouble(stmt, 8, now)
        }
        let id = db.lastInsertRowID()
        let spans = SpanSplitter.spans(in: normalized, captureId: id, version: version)
        for span in spans {
            var ftsRow: Int64 = 0
            try db.run("INSERT INTO spans_fts(text) VALUES(?);") { stmt in
                SQLDB.bindText(stmt, 1, span.text)
            }
            ftsRow = db.lastInsertRowID()
            try db.run("INSERT INTO spans(span_id,capture_id,capture_version,idx,char_start,char_end,fts_rowid) VALUES(?,?,?,?,?,?,?);") { stmt in
                SQLDB.bindText(stmt, 1, span.id); SQLDB.bindInt(stmt, 2, span.captureId)
                SQLDB.bindInt(stmt, 3, Int64(span.captureVersion)); SQLDB.bindInt(stmt, 4, Int64(span.idx))
                SQLDB.bindInt(stmt, 5, Int64(span.charStart)); SQLDB.bindInt(stmt, 6, Int64(span.charEnd))
                SQLDB.bindInt(stmt, 7, ftsRow)
            }
        }
        return Capture(id: id, url: url, title: title, text: normalized, wordCount: words,
                       confidence: confidence, version: version, capturedAt: Date(timeIntervalSince1970: now))
    }

    public func latestVersion(url: String) throws -> Int {
        try db.query("SELECT MAX(version) FROM captures WHERE url=?;", bind: { SQLDB.bindText($0, 1, url) }) { stmt -> Int in
            sqlite3_column_type(stmt, 0) == SQLITE_NULL ? 0 : Int(sqlite3_column_int64(stmt, 0))
        }.first ?? 0
    }

    public func recentCaptures(limit: Int = 20) throws -> [Capture] {
        try db.query("SELECT id,url,title,text,word_count,confidence,version,captured_at FROM captures ORDER BY captured_at DESC LIMIT ?;",
                     bind: { SQLDB.bindInt($0, 1, Int64(limit)) }) { stmt in
            Capture(id: sqlite3_column_int64(stmt, 0),
                    url: String(cString: sqlite3_column_text(stmt, 1)),
                    title: String(cString: sqlite3_column_text(stmt, 2)),
                    text: String(cString: sqlite3_column_text(stmt, 3)),
                    wordCount: Int(sqlite3_column_int64(stmt, 4)),
                    confidence: sqlite3_column_double(stmt, 5),
                    version: Int(sqlite3_column_int64(stmt, 6)),
                    capturedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7)))
        }
    }

    public func capture(id: Int64) throws -> Capture? {
        try db.query("SELECT id,url,title,text,word_count,confidence,version,captured_at FROM captures WHERE id=?;",
                     bind: { SQLDB.bindInt($0, 1, id) }) { stmt in
            Capture(id: sqlite3_column_int64(stmt, 0),
                    url: String(cString: sqlite3_column_text(stmt, 1)),
                    title: String(cString: sqlite3_column_text(stmt, 2)),
                    text: String(cString: sqlite3_column_text(stmt, 3)),
                    wordCount: Int(sqlite3_column_int64(stmt, 4)),
                    confidence: sqlite3_column_double(stmt, 5),
                    version: Int(sqlite3_column_int64(stmt, 6)),
                    capturedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7)))
        }.first
    }

    public func captureCount() throws -> Int {
        try db.query("SELECT COUNT(*) FROM captures;") { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
    }

    // MARK: Spans + retrieval

    public struct ScoredSpan: Sendable, Equatable {
        public var span: Span
        public var score: Double
    }

    /// BM25 retrieval with τ relevance gate. Returns empty when nothing clears τ.
    public func retrieve(question: String, k: Int = 8, tau: Double) throws -> [ScoredSpan] {
        let queryText = Self.ftsQuery(from: question)
        guard !queryText.isEmpty else { return [] }
        let sql = """
        SELECT s.span_id,s.capture_id,s.capture_version,s.idx,s.char_start,s.char_end,
               bm25(spans_fts) AS score, c.version
        FROM spans_fts f
        JOIN spans s ON s.fts_rowid = f.rowid
        JOIN captures c ON c.id = s.capture_id AND c.version = s.capture_version
        WHERE spans_fts MATCH ?
        ORDER BY score
        LIMIT ?;
        """
        let rows: [(Span, Double)] = try db.query(sql, bind: {
            SQLDB.bindText($0, 1, queryText); SQLDB.bindInt($0, 2, Int64(k * 3))
        }) { stmt in
            let span = Span(id: String(cString: sqlite3_column_text(stmt, 0)),
                            captureId: sqlite3_column_int64(stmt, 1),
                            captureVersion: Int(sqlite3_column_int64(stmt, 2)),
                            idx: Int(sqlite3_column_int64(stmt, 3)),
                            text: "", charStart: Int(sqlite3_column_int64(stmt, 4)),
                            charEnd: Int(sqlite3_column_int64(stmt, 5)))
            return (span, sqlite3_column_double(stmt, 6))   // bm25 rank column
        }
        // Fill texts + keep only latest versions per capture, above τ, top-k.
        var seenVersions: [Int64: Int] = [:]
        var out: [ScoredSpan] = []
        for (spanId, rawScore) in rows {                    // bm25(): negative = better
            let score = -rawScore
            guard score >= tau else { break }               // ordered best-first; first miss ends window
            if let v = seenVersions[spanId.captureId], v != spanId.captureVersion { continue }
            seenVersions[spanId.captureId] = spanId.captureVersion
            guard let s = try self.span(spanId: spanId.id) else { continue }
            out.append(ScoredSpan(span: s, score: score))
            if out.count >= k { break }
        }
        return out
    }

    public func span(spanId: String) throws -> Span? {
        try db.query("SELECT span_id,capture_id,capture_version,idx,char_start,char_end FROM spans WHERE span_id=?;",
                     bind: { SQLDB.bindText($0, 1, spanId) }) { stmt in
            let cap = sqlite3_column_int64(stmt, 1)
            return Span(id: String(cString: sqlite3_column_text(stmt, 0)), captureId: cap,
                        captureVersion: Int(sqlite3_column_int64(stmt, 2)),
                        idx: Int(sqlite3_column_int64(stmt, 3)),
                        text: "", charStart: Int(sqlite3_column_int64(stmt, 4)),
                        charEnd: Int(sqlite3_column_int64(stmt, 5)))
        }.first.map { s in
            var s = s
            if let cap = try? capture(id: s.captureId) {
                let ns = cap.text as NSString
                let clampedStart = min(s.charStart, ns.length)
                let clampedEnd = min(s.charEnd, ns.length)
                if clampedEnd > clampedStart { s.text = ns.substring(with: NSRange(clampedStart..<clampedEnd)) }
            }
            return s
        }
    }

    public func allSpans() throws -> [Span] {
        try db.query("SELECT COUNT(*) FROM spans;") { _ in true }
        let ids = try db.query("SELECT span_id FROM spans;") { String(cString: sqlite3_column_text($0, 0)) }
        return try ids.compactMap { try span(spanId: $0) }
    }

    // MARK: Bookmarks

    public func addBookmark(url: String, title: String) throws -> Bookmark {
        try db.run("INSERT OR REPLACE INTO bookmarks(url,title,created_at) VALUES(?,?,?);") { stmt in
            SQLDB.bindText(stmt, 1, url); SQLDB.bindText(stmt, 2, title)
            SQLDB.bindDouble(stmt, 3, Date().timeIntervalSince1970)
        }
        return Bookmark(url: url, title: title, createdAt: Date())
    }

    public func removeBookmark(url: String) throws {
        try db.run("DELETE FROM bookmarks WHERE url=?;") { SQLDB.bindText($0, 1, url) }
    }

    public func bookmarks() throws -> [Bookmark] {
        try db.query("SELECT url,title,created_at FROM bookmarks ORDER BY created_at DESC;") { stmt in
            Bookmark(url: String(cString: sqlite3_column_text(stmt, 0)),
                     title: String(cString: sqlite3_column_text(stmt, 1)),
                     createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)))
        }
    }

    public func isBookmarked(url: String) throws -> Bool {
        try db.query("SELECT 1 FROM bookmarks WHERE url=?;", bind: { SQLDB.bindText($0, 1, url) }) { _ in true }.isEmpty == false
    }

    // MARK: Session tabs (crash-only contract)

    public func saveSession(tabs: [TabInfo]) throws {
        try db.exec("DELETE FROM session_tabs;")
        for (i, t) in tabs.enumerated() {
            try db.run("INSERT INTO session_tabs(ord,id,url,title,pinned,active) VALUES(?,?,?,?,?,?);") { stmt in
                SQLDB.bindInt(stmt, 1, Int64(i)); SQLDB.bindText(stmt, 2, t.id)
                SQLDB.bindText(stmt, 3, t.url); SQLDB.bindText(stmt, 4, t.title)
                SQLDB.bindInt(stmt, 5, t.pinned ? 1 : 0); SQLDB.bindInt(stmt, 6, t.active ? 1 : 0)
            }
        }
    }

    public func loadSession() throws -> [TabInfo] {
        try db.query("SELECT id,url,title,pinned,active FROM session_tabs ORDER BY ord;") { stmt in
            TabInfo(id: String(cString: sqlite3_column_text(stmt, 0)),
                    url: String(cString: sqlite3_column_text(stmt, 1)),
                    title: String(cString: sqlite3_column_text(stmt, 2)),
                    pinned: sqlite3_column_int64(stmt, 3) != 0,
                    active: sqlite3_column_int64(stmt, 4) != 0)
        }
    }

    // MARK: Settings KV

    public func setting(_ key: String) -> String? {
        (try? db.query("SELECT value FROM settings WHERE key=?;", bind: { SQLDB.bindText($0, 1, key) }) {
            String(cString: sqlite3_column_text($0, 0))
        }.first) ?? nil
    }

    public func setSetting(_ key: String, _ value: String) {
        try? db.run("INSERT OR REPLACE INTO settings(key,value) VALUES(?,?);") { stmt in
            SQLDB.bindText(stmt, 1, key); SQLDB.bindText(stmt, 2, value)
        }
    }

    // MARK: Helpers

    static func contentHash(_ s: String) -> String {
        let d = s.data(using: .utf8) ?? Data()
        var h: UInt64 = 1469598103934665603
        for b in d { h ^= UInt64(b); h = h &* 1099511628211 }
        return String(format: "%016llx", h)
    }

    static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func ftsQuery(from question: String) -> String {
        let tokens = question.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map { $0.lowercased() }
            .filter { !$0.isEmpty && $0.count > 1 && !Self.stopwords.contains($0) }
        return tokens.prefix(24).map { "\"\($0)\"" }.joined(separator: " OR ")
    }

    static let stopwords: Set<String> = ["the","a","an","is","are","was","were","be","to","of","and","or",
                                         "in","on","at","for","with","what","who","when","where","why","how",
                                         "does","do","did","this","that","it","its","as","by","from","about"]
}
