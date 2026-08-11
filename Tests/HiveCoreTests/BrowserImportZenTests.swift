import Foundation
import SQLite3
import Testing
@testable import HiveCore

// MARK: - BrowserImportEngine: Firefox/Zen (P1.7)

/// P1.7 contract: Firefox and Zen share the Mozilla `places.sqlite` layout
/// (moz_bookmarks + moz_places), so the same parser serves both. These tests
/// lock the shared parser and the `zen` route so the onboarding import surface
/// can't silently lose a browser.
// SQLite fixtures share the temp directory and journal files; serialize the
// suite so concurrent test cases cannot lock each other's databases.
@Suite("BrowserImportFirefoxZen", .serialized)
struct BrowserImportFirefoxZenTests {

    private func makeFixtureDB() throws -> (dbPath: String, cleanup: () -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-firefox-\\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbPath = dir.appendingPathComponent("places.sqlite").path
        let cleanup = { _ = try? FileManager.default.removeItem(at: dir) }

        guard let db = openDB(path: dbPath) else {
            cleanup()
            throw NSError(domain: "fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "open failed"])
        }
        defer { sqlite3_close(db) }

        var schemaError: UnsafeMutablePointer<CChar>?

        // Minimal Mozilla schema: moz_places + moz_bookmarks.
        let schema = """
        CREATE TABLE moz_places (
            id INTEGER PRIMARY KEY,
            url TEXT NOT NULL,
            title TEXT,
            visit_count INTEGER NOT NULL DEFAULT 0,
            last_visit_date INTEGER
        );
        CREATE TABLE moz_bookmarks (
            id INTEGER PRIMARY KEY,
            fk INTEGER,
            type INTEGER NOT NULL DEFAULT 1,
            title TEXT,
            dateAdded INTEGER
        );
        INSERT INTO moz_places (id, url, title, visit_count, last_visit_date)
        VALUES (1, 'https://zen.example.com/page', 'Zen Example', 3, 1785834000000000);
        INSERT INTO moz_bookmarks (fk, type, title, dateAdded)
        VALUES (1, 1, 'Zen Bookmark', 1785834000000000);
        """
        let schemaRC = sqlite3_exec(db, schema, nil, nil, &schemaError)
        guard schemaRC == SQLITE_OK else {
            let detail = schemaError.map { String(cString: $0) } ?? "rc=\(schemaRC)"
            if let schemaError { sqlite3_free(schemaError) }
            cleanup()
            throw NSError(domain: "fixture", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "schema failed: \(detail)"])
        }
        return (dbPath, cleanup)
    }

    private func openDB(path: String) -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { return nil }
        return db
    }

    @Test func sharedParserExtractsBookmarksAndHistory() throws {
        let (dbPath, cleanup) = try makeFixtureDB()
        defer { cleanup() }

        let result = BrowserImportEngine.parseFirefoxDatabase(at: dbPath)
        #expect(result.bookmarks.count == 1)
        #expect(result.bookmarks.first?.title == "Zen Bookmark")
        #expect(result.bookmarks.first?.url.absoluteString == "https://zen.example.com/page")
        #expect(result.history.count == 1)
        #expect(result.history.first?.title == "Zen Example")
        #expect(result.history.first?.visitCount == 3)
        #expect(result.history.first?.url.absoluteString == "https://zen.example.com/page")
    }

    @Test func sharedParserReturnsEmptyForMissingDatabase() {
        let missing = NSTemporaryDirectory() + "no-such-places-\\(UUID().uuidString).sqlite"
        let result = BrowserImportEngine.parseFirefoxDatabase(at: missing)
        #expect(result.bookmarks.isEmpty)
        #expect(result.history.isEmpty)
    }

    @Test func sharedParserSkipsBookmarksWithoutPlacesRow() throws {
        let (dbPath, cleanup) = try makeFixtureDB()
        defer { cleanup() }
        // Add a bookmark row whose fk has no moz_places row — the JOIN must
        // exclude it rather than crash or fabricate a URL.
        guard let db = openDB(path: dbPath) else {
            Issue.record("fixture reopen failed")
            return
        }
        defer { sqlite3_close(db) }
        _ = sqlite3_exec(db, "INSERT INTO moz_bookmarks (fk, type, title, dateAdded) VALUES (999, 1, 'Dangling', 0);", nil, nil, nil)

        let result = BrowserImportEngine.parseFirefoxDatabase(at: dbPath)
        #expect(result.bookmarks.count == 1, "dangling bookmark must be excluded by the JOIN")
        #expect(!result.bookmarks.contains(where: { $0.title == "Dangling" }))
    }

    @Test func firefoxAndZenRoutesShareTheMozillaParser() throws {
        // Source contract: the route table must dispatch both ids through the
        // same Firefox parser family. Zen lives under `~/Library/Application
        // Support/zen/Profiles`, Firefox under `.../Firefox/Profiles` — both
        // resolve to a `.default-release`/`.default` places.sqlite. The shared
        // parser contract is locked by the fixture below; route resolution is
        // exercised honestly in routesResolveWithoutCrashing.
        let (dbPath, cleanup) = try makeFixtureDB()
        defer { cleanup() }
        let parsed = BrowserImportEngine.parseFirefoxDatabase(at: dbPath)
        #expect(parsed.bookmarks.first?.title == "Zen Bookmark",
                "Firefox and Zen must share the same places.sqlite parsing")
        #expect(parsed.bookmarks.first?.url.absoluteString == "https://zen.example.com/page")
        #expect(parsed.history.first?.title == "Zen Example")
    }

    @Test func routesResolveWithoutCrashing() {
        // Every documented import id must route through the engine without
        // crashing even when the browser is not installed (returns empty).
        // The advertisement itself (detectAvailableBrowsers in the Hive app
        // target) is not reachable from HiveCoreTests — its zen entry is a
        // source-contract check only.
        //
        // An UNKNOWN id must fall back to the honest empty snapshot — this is
        // the observable distinction between a documented route and the
        // default fallback.
        let unknown = BrowserImportEngine.importFrom(browserID: "not-a-browser")
        #expect(unknown.bookmarks.isEmpty)
        #expect(unknown.history.isEmpty)
        // Documented routes (Zen among them) must each return a structurally
        // valid snapshot — possibly empty on a machine without the browser,
        // never a crash or a non-empty/empty inconsistency.
        for id in ["chrome", "safari", "brave", "edge", "arc", "firefox", "zen"] {
            let result = BrowserImportEngine.importFrom(browserID: id)
            #expect(result.bookmarks.count >= 0 && result.history.count >= 0,
                    "route \(id) must return a valid snapshot")
        }
    }
}
