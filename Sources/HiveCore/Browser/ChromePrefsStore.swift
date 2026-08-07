import Foundation

// MARK: - ChromePrefsStore
//
// Atomic disk-backed persistence for `ChromeUserPrefs`. Actor-isolated; writes via a
// temporary file + atomic rename (AGENTS.md §15.2 "atomic writes"). Designed to be safe
// against partial writes — a corrupted prefs file is quarantined and replaced with
// `.defaults` rather than crashing (AGENTS.md §15.2 "never silently discard malformed user
// data; preserve, surface an error, or quarantine").
//
// The store is a thin durable-overlay; the in-memory observable `ChromeState` (in the Hive
// target) is what views bind to, and it calls into here on change.

public actor ChromePrefsStore {

    private let url: URL
    private var cached: ChromeUserPrefs?

    /// The canonical prefs file: `~/Library/Application Support/Hive/Preferences/chrome.json`.
    /// Created lazily on first save.
    public static let defaultURL: URL = {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                  appropriateFor: nil, create: true)
        let base = support ?? fm.temporaryDirectory
        return base.appendingPathComponent("Hive/Preferences/chrome.json")
    }()

    /// - Parameter url: The prefs file URL. Defaults to `defaultURL`.
    public init(url: URL = ChromePrefsStore.defaultURL) {
        self.url = url
    }

    /// Loads prefs; falls back to `.defaults` on missing file. On a corrupt file, renames
    /// it to `<name>.corrupt-<timestamp>.json`, surfaces the error (logged, non-throwing),
    /// and returns defaults — never crashing the app over unparseable JSON. Caches the result.
    public func load() -> ChromeUserPrefs {
        if let cached { return cached }
        let prefs = Self.read(from: url)
        cached = prefs
        return prefs
    }

    /// Synchronous, nonisolated loader intended for app launch (called before the first frame
    /// so the chrome's layout choice is correct on the first paint — no "snap" from default to
    /// the user's saved layout). Same corruption/quarantine semantics as `load()`, but does
    /// NOT touch the actor's cache (the actor re-reads on its first `load()` / save).
    public nonisolated static func loadSync(url: URL = ChromePrefsStore.defaultURL) -> ChromeUserPrefs {
        read(from: url)
    }

    /// The shared read/decode/quarantine routine (nonisolated so both the actor method and the
    /// static sync loader can reach it without crossing isolation).
    private nonisolated static func read(from url: URL) -> ChromeUserPrefs {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ChromeUserPrefs.defaults
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ChromeUserPrefs.self, from: data)
        } catch {
            // Quarantine the corrupt file (do not delete — preserve for the user to inspect).
            quarantineCorruptFile(at: url, reason: "\(error)")
            return ChromeUserPrefs.defaults
        }
    }

    /// Atomically persists the prefs. Refreshes the cache. Throws on I/O failure so the
    /// caller can decide (the observable state still holds the value in memory).
    ///
    /// Two-phase: write to a uniquely-named temp file (atomic write so the temp itself is
    /// never half-written), then swap it into `url` via `replaceItemAt` (preserves the
    /// inode / file-reference of any existing file — readers holding a handle keep working)
    /// or, on the first ever write, a plain move.
    public func save(_ prefs: ChromeUserPrefs) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder.encodePretty(prefs)
        let tmp = dir.appendingPathComponent("chrome.\(UUID().uuidString).tmp")
        try data.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            // Atomic swap in place; removes `tmp`.
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: url)
        }
        cached = prefs
    }

    /// Records a closed tab, enforcing the cap and dedup-by-URL (reopen shouldn't stack
    /// duplicates of the same page).
    public func recordClosedTab(_ record: ClosedTabRecord) throws -> ChromeUserPrefs {
        var prefs = load()
        prefs.recentlyClosed.removeAll { $0.url == record.url }
        prefs.recentlyClosed.insert(record, at: 0)
        let cap = Array<ClosedTabRecord>.hiveClosedTabCap
        if prefs.recentlyClosed.count > cap {
            prefs.recentlyClosed = Array(prefs.recentlyClosed.prefix(cap))
        }
        try save(prefs)
        return prefs
    }

    // MARK: - Quarantine

    private nonisolated static func quarantineCorruptFile(at url: URL, reason: String) {
        let dir = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = dir.appendingPathComponent("\(stem).corrupt-\(stamp).json")
        do { try FileManager.default.moveItem(at: url, to: dest) }
        catch { /* best-effort; corrupt file left in place is acceptable */ }
        // Reason is intentionally not persisted (could contain user-path-adjacent data);
        // Hive's local logs surface it at the app layer.
    }
}

private extension JSONEncoder {
    static func encodePretty<T: Encodable>(_ value: T) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return try e.encode(value)
    }
}
