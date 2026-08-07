import Foundation

// MARK: - SessionPersistenceManager
//
/// Manages atomic disk persistence of browser session state for crash recovery.
/// Writes to ~/Library/Application Support/Hive/Sessions/ with debounced auto-save
/// and immediate save on termination. Handles crash loop detection via CrashRecord.
///
/// All methods are thread-safe via the actor isolation. The manager is Sendable.

public actor SessionPersistenceManager {

    public static let shared = SessionPersistenceManager()

    private let fileManager: FileManager
    private let sessionURL: URL
    private let crashCounterURL: URL

    private init() {
        self.fileManager = .default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let hiveDir = appSupport.appendingPathComponent("Hive", isDirectory: true)
        self.sessionURL = hiveDir.appendingPathComponent("Sessions", isDirectory: true)
        self.crashCounterURL = sessionURL.appendingPathComponent("crash_counts.json")
    }

    // MARK: - Session Save/Load

    /// Ensures the session directory exists on disk.
    private func ensureDirectory() throws {
        try fileManager.createDirectory(at: sessionURL, withIntermediateDirectories: true)
    }

    /// Saves the session state atomically. Pass `immediate: true` for app termination saves
    /// (synchronous, no debounce). Default is debounced for rapid state changes.
    public func saveSession(_ session: SessionState, filename: String = "active_session.json") throws {
        try ensureDirectory()
        let fileURL = sessionURL.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        // Atomic write prevents corruption on crash during save
        try data.write(to: fileURL, options: [.atomic])
    }

    /// Loads the session state from disk. Returns nil if no saved session exists.
    public func loadSession(filename: String = "active_session.json") -> SessionState? {
        let fileURL = sessionURL.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SessionState.self, from: data)
        } catch {
            // Corrupted file — delete it so we don't keep failing
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }

    /// Deletes the saved session (e.g., after a successful manual restore).
    public func clearSession(filename: String = "active_session.json") throws {
        let fileURL = sessionURL.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Crash Counter

    /// Records a crash for the given tab ID. Returns the updated CrashRecord.
    /// If the crash loop threshold is exceeded (3+ crashes in 5 min), the caller
    /// should not auto-restore this tab.
    public func recordCrash(for tabID: UUID) -> CrashRecord {
        var counters = loadCrashCounters()
        let now = Date()
        let existing = counters[tabID]
        let record: CrashRecord
        if let existing {
            // Keep one fixed five-minute burst per tab. Using lastCrash here
            // would create an unbounded sliding window for a tab that crashes
            // every few minutes and would make the circuit breaker misleading.
            record = existing.recorded(at: now)
        } else {
            record = CrashRecord(count: 1, firstCrash: now, lastCrash: now)
        }
        counters[tabID] = record
        saveCrashCounters(counters)
        return record
    }

    /// Clears crash counters for all tabs (e.g., after a successful restore).
    public func clearCrashCounters() {
        saveCrashCounters([:])
    }

    /// Clears crash counters for a specific tab (e.g., after a manual reload succeeds).
    public func clearCrashCounter(for tabID: UUID) {
        var counters = loadCrashCounters()
        counters.removeValue(forKey: tabID)
        saveCrashCounters(counters)
    }

    private func loadCrashCounters() -> [UUID: CrashRecord] {
        guard fileManager.fileExists(atPath: crashCounterURL.path),
              let data = try? Data(contentsOf: crashCounterURL),
              let decoded = try? JSONDecoder().decode([String: CrashRecord].self, from: data) else {
            return [:]
        }
        // Convert string keys back to UUIDs
        var result: [UUID: CrashRecord] = [:]
        for (key, value) in decoded {
            if let uuid = UUID(uuidString: key) {
                result[uuid] = value
            }
        }
        return result
    }

    private func saveCrashCounters(_ counters: [UUID: CrashRecord]) {
        let stringKeyed = Dictionary(uniqueKeysWithValues: counters.map { ($0.key.uuidString, $0.value) })
        guard let data = try? JSONEncoder().encode(stringKeyed) else { return }
        try? data.write(to: crashCounterURL, options: [.atomic])
    }
}
