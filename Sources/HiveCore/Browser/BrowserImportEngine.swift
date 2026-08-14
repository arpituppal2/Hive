import Foundation
import SQLite3

// MARK: - BrowserImportEngine
//
// Parses bookmarks and history from external browser profile directories.
// Supports Safari (Bookmarks.plist), Chrome/Chromium-based browsers (JSON Bookmarks),
// and Firefox/Zen (places.sqlite via system SQLite3).
//
// All parsing is read-only — we extract what we can, skip what we can't, and report
// honest counts. The caller is responsible for merging results into the session store.

public struct BrowserImportEngine {

    // MARK: - Safari (Bookmarks.plist)

    /// Parses Safari's `~/Library/Safari/Bookmarks.plist`.
    /// The plist is a tree of dictionaries; bookmark leaves have a `URIDictionary` key
    /// with a `title` string. Returns (bookmarkCount, historyCount) — Safari history
    /// lives in `~/Library/Safari/History.db` (separate file, not parsed yet).
    public static func parseSafariBookmarks(at plistPath: String) -> (bookmarks: [ImportedBookmark], history: [ImportedHistoryEntry]) {
        guard FileManager.default.fileExists(atPath: plistPath),
              let plist = NSDictionary(contentsOfFile: plistPath) else {
            return ([], [])
        }
        var bookmarks: [ImportedBookmark] = []
        extractSafariBookmarks(from: plist, into: &bookmarks)
        return (bookmarks, [])
    }

    private static func extractSafariBookmarks(from dict: NSDictionary, into bookmarks: inout [ImportedBookmark]) {
        guard let children = dict["Children"] as? [NSDictionary] else {
            // Leaf: attempt to extract a bookmark entry.
            if let uriDict = dict["URIDictionary"] as? NSDictionary,
               let urlString = dict["URLString"] as? String,
               let url = URL(string: urlString) {
                let title = (uriDict["title"] as? String) ?? url.host ?? "Untitled"
                bookmarks.append(ImportedBookmark(title: title, url: url))
            }
            return
        }
        for child in children {
            extractSafariBookmarks(from: child, into: &bookmarks)
        }
    }

    // MARK: - Chrome / Chromium (JSON Bookmarks)

    /// Parses Chrome's `~/Library/Application Support/Google/Chrome/Default/Bookmarks`
    /// (or any Chromium-based browser's equivalent). The file is a JSON tree with
    /// `roots.bookmark_bar`, `roots.other`, and `roots.synced` children.
    /// Each node has a `type` key: `"url"` for bookmarks, `"folder"` for folders.
    public static func parseChromiumBookmarks(at jsonPath: String) -> (bookmarks: [ImportedBookmark], history: [ImportedHistoryEntry]) {
        guard FileManager.default.fileExists(atPath: jsonPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roots = root["roots"] as? [String: Any] else {
            return ([], [])
        }
        var bookmarks: [ImportedBookmark] = []
        for key in ["bookmark_bar", "other", "synced"] {
            if let folder = roots[key] as? [String: Any] {
                extractChromiumBookmarks(from: folder, into: &bookmarks)
            }
        }
        return (bookmarks, [])
    }

    private static func extractChromiumBookmarks(from node: [String: Any], into bookmarks: inout [ImportedBookmark]) {
        let type = node["type"] as? String ?? ""
        if type == "url",
           let urlString = node["url"] as? String,
           let url = URL(string: urlString) {
            let title = (node["name"] as? String) ?? url.host ?? "Untitled"
            bookmarks.append(ImportedBookmark(title: title, url: url))
        }
        if let children = node["children"] as? [[String: Any]] {
            for child in children {
                extractChromiumBookmarks(from: child, into: &bookmarks)
            }
        }
    }

    // MARK: - Chromium History (SQLite)

    /// Parses Chromium's `History` SQLite database (`~/Library/Application Support/.../Default/History`).
    /// Returns recent history entries with visit count and last-visit date.
    public static func parseChromiumHistory(at dbPath: String) -> [ImportedHistoryEntry] {
        guard let (db, tempURL) = openSQLiteReadOnlyCopy(at: dbPath) else { return [] }
        defer {
            sqlite3_close(db)
            try? FileManager.default.removeItem(at: tempURL)
        }

        return queryChromiumHistory(db: db)
    }

    private static func queryChromiumHistory(db: OpaquePointer) -> [ImportedHistoryEntry] {
        let sql = """
            SELECT url, title, visit_count, last_visit_time
            FROM urls
            WHERE url IS NOT NULL AND last_visit_time IS NOT NULL
            ORDER BY last_visit_time DESC
            LIMIT 10000
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }

        var results: [ImportedHistoryEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let urlPtr = sqlite3_column_text(stmt, 0) else { continue }
            let urlStr = String(cString: urlPtr)
            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
            let visitCount = sqlite3_column_int(stmt, 2)
            let lastVisitTime = sqlite3_column_int64(stmt, 3)
            guard let url = URL(string: urlStr) else { continue }
            // Chromium stores last_visit_time as microseconds since 1601-01-01 (Windows file time).
            let secondsSince1970 = (Double(lastVisitTime) / 1_000_000.0) - 11_644_473_600.0
            let visitDate = Date(timeIntervalSince1970: secondsSince1970)
            results.append(ImportedHistoryEntry(
                url: url,
                title: title ?? url.host ?? "",
                visitDate: visitDate,
                visitCount: Int(visitCount)
            ))
        }
        return results
    }

    // MARK: - Safari History (History.db)

    /// Parses Safari's `~/Library/Safari/History.db` SQLite database, returning recent history
    /// entries with their visit counts. Bookmarks are read separately from `Bookmarks.plist`.
    public static func parseSafariHistory(at dbPath: String) -> [ImportedHistoryEntry] {
        guard let (db, tempURL) = openSQLiteReadOnlyCopy(at: dbPath) else { return [] }
        defer {
            sqlite3_close(db)
            try? FileManager.default.removeItem(at: tempURL)
        }

        return querySafariHistory(db: db)
    }

    private static func querySafariHistory(db: OpaquePointer) -> [ImportedHistoryEntry] {
        // Safari stores visit_time as a CFAbsoluteTime (seconds since 2001-01-01 00:00:00 UTC).
        let sql = """
            SELECT hi.url, hi.title, hi.visit_count, hv.visit_time
            FROM history_visits hv
            JOIN history_items hi ON hv.history_item = hi.id
            WHERE hi.url IS NOT NULL AND hv.visit_time IS NOT NULL
            ORDER BY hv.visit_time DESC
            LIMIT 10000
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }

        var results: [ImportedHistoryEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let urlPtr = sqlite3_column_text(stmt, 0) else { continue }
            let urlStr = String(cString: urlPtr)
            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
            let visitCount = sqlite3_column_int(stmt, 2)
            let visitTime = sqlite3_column_double(stmt, 3)
            guard let url = URL(string: urlStr) else { continue }
            let visitDate = Date(timeIntervalSinceReferenceDate: visitTime)
            results.append(ImportedHistoryEntry(
                url: url,
                title: title ?? url.host ?? "",
                visitDate: visitDate,
                visitCount: Int(visitCount)
            ))
        }
        return results
    }

    // MARK: - Firefox (places.sqlite)

    /// Parses Firefox's `places.sqlite` database at the given path using system SQLite3.
    /// Extracts bookmarks from `moz_bookmarks` joined with `moz_places`, and history
    /// from `moz_places` directly. Returns both.
    public static func parseFirefoxDatabase(at dbPath: String) -> (bookmarks: [ImportedBookmark], history: [ImportedHistoryEntry]) {
        guard let (db, tempURL) = openSQLiteReadOnlyCopy(at: dbPath) else {
            return ([], [])
        }
        defer {
            sqlite3_close(db)
            try? FileManager.default.removeItem(at: tempURL)
        }

        let bookmarks = queryFirefoxBookmarks(db: db)
        let history = queryFirefoxHistory(db: db)
        return (bookmarks, history)
    }

    private static func queryFirefoxBookmarks(db: OpaquePointer) -> [ImportedBookmark] {
        let sql = """
            SELECT moz_places.url, moz_bookmarks.title
            FROM moz_bookmarks
            JOIN moz_places ON moz_bookmarks.fk = moz_places.id
            WHERE moz_bookmarks.type = 1 AND moz_places.url IS NOT NULL
            ORDER BY moz_bookmarks.dateAdded DESC
            LIMIT 5000
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var results: [ImportedBookmark] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let urlPtr = sqlite3_column_text(stmt, 0) else { continue }
            let urlStr = String(cString: urlPtr)
            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
            if let url = URL(string: urlStr) {
                results.append(ImportedBookmark(
                    title: title ?? url.host ?? "Untitled",
                    url: url
                ))
            }
        }
        return results
    }

    private static func queryFirefoxHistory(db: OpaquePointer) -> [ImportedHistoryEntry] {
        let sql = """
            SELECT url, title, visit_count, last_visit_date
            FROM moz_places
            WHERE url IS NOT NULL AND last_visit_date IS NOT NULL
            ORDER BY last_visit_date DESC
            LIMIT 10000
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var results: [ImportedHistoryEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let urlPtr = sqlite3_column_text(stmt, 0) else { continue }
            let urlStr = String(cString: urlPtr)
            let title = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
            let visitCount = sqlite3_column_int(stmt, 2)
            let lastVisitMicro = sqlite3_column_int64(stmt, 3)
            if let url = URL(string: urlStr) {
                // Firefox stores last_visit_date as microseconds since Unix epoch.
                let visitDate = Date(timeIntervalSince1970: Double(lastVisitMicro) / 1_000_000.0)
                results.append(ImportedHistoryEntry(
                    url: url,
                    title: title ?? url.host ?? "",
                    visitDate: visitDate,
                    visitCount: Int(visitCount)
                ))
            }
        }
        return results
    }

    // MARK: - SQLite helper

    /// Copies a live browser SQLite database to a temporary location and opens it read-only.
    /// Browsers keep a lock on their profile databases while running; copying avoids
    /// `SQLITE_BUSY` and prevents us from accidentally writing to the user's data.
    private static func openSQLiteReadOnlyCopy(at path: String) -> (db: OpaquePointer, tempURL: URL)? {
        let source = URL(fileURLWithPath: path)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-import-\(UUID().uuidString)", isDirectory: true)
        let tempURL = tempDir.appendingPathComponent(source.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: tempURL)
            try FileManager.default.copyItem(at: source, to: tempURL)
        } catch {
            return nil
        }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY
        guard sqlite3_open_v2(tempURL.path, &db, flags, nil) == SQLITE_OK, let db else {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
        return (db, tempURL)
    }

    // MARK: - Generic importer (route by browser id)

    /// Routes import by browser id, returning honest counts.
    public static func importFrom(browserID: String) -> (bookmarks: [ImportedBookmark], history: [ImportedHistoryEntry]) {
        let home = NSHomeDirectory()
        switch browserID {
        case "safari":
            let bookmarks = parseSafariBookmarks(at: "\(home)/Library/Safari/Bookmarks.plist").bookmarks
            let history = parseSafariHistory(at: "\(home)/Library/Safari/History.db")
            return (bookmarks, history)
        case "chrome":
            let profile = "\(home)/Library/Application Support/Google/Chrome/Default"
            let bookmarks = parseChromiumBookmarks(at: "\(profile)/Bookmarks").bookmarks
            let history = parseChromiumHistory(at: "\(profile)/History")
            return (bookmarks, history)
        case "firefox", "zen":
            // Firefox and Zen both use Mozilla-style profiles: a Profiles
            // directory of per-profile folders (`.default-release`/`.default`
            // suffixes) holding a `places.sqlite` bookmarks/history database.
            let appSupportName = browserID == "zen" ? "zen" : "Firefox"
            let profilesDir = "\(home)/Library/Application Support/\(appSupportName)/Profiles"
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: profilesDir),
               let profileDir = contents.first(where: { $0.hasSuffix(".default-release") || $0.hasSuffix(".default") }) {
                return parseFirefoxDatabase(at: "\(profilesDir)/\(profileDir)/places.sqlite")
            }
            return ([], [])
        case "edge":
            let profile = "\(home)/Library/Application Support/Microsoft Edge/Default"
            let bookmarks = parseChromiumBookmarks(at: "\(profile)/Bookmarks").bookmarks
            let history = parseChromiumHistory(at: "\(profile)/History")
            return (bookmarks, history)
        case "brave":
            let profile = "\(home)/Library/Application Support/BraveSoftware/Brave-Browser/Default"
            let bookmarks = parseChromiumBookmarks(at: "\(profile)/Bookmarks").bookmarks
            let history = parseChromiumHistory(at: "\(profile)/History")
            return (bookmarks, history)
        case "arc":
            let profile = "\(home)/Library/Application Support/Arc/User Data/Default"
            let bookmarks = parseChromiumBookmarks(at: "\(profile)/Bookmarks").bookmarks
            let history = parseChromiumHistory(at: "\(profile)/History")
            return (bookmarks, history)
        default:
            return ([], [])
        }
    }
}

// MARK: - Imported data types

/// A bookmark extracted from an external browser.
public struct ImportedBookmark: Sendable, Equatable {
    public let title: String
    public let url: URL

    public init(title: String, url: URL) {
        self.title = title
        self.url = url
    }
}

/// A history entry extracted from an external browser.
public struct ImportedHistoryEntry: Sendable, Equatable {
    public let url: URL
    public let title: String
    public let visitDate: Date
    public let visitCount: Int

    public init(url: URL, title: String, visitDate: Date, visitCount: Int = 0) {
        self.url = url
        self.title = title
        self.visitDate = visitDate
        self.visitCount = visitCount
    }
}
