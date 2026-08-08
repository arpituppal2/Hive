import Foundation

// MARK: - SessionFileStore
//
// Generic disk-backed persistence for a single Codable session payload, using the
// same durability contract as `BrowserSessionStore` (AGENTS.md §15.2 and the
// crash-only recovery rule: never silently start fresh over an unreadable session):
//
//   1. Atomic two-phase writes: encode to a uniquely-named temp file, then swap it
//      into place. A crash mid-write can never leave a half-written session.json.
//   2. Rolling backup (`<name>.prev.json`): before each successful write, the prior
//      good `session.json` is stashed as the backup. If the current file is ever
//      unreadable, we quarantine it (move aside, never delete) AND can offer the
//      last known-good session ("restore last session") — a recovery path, never a
//      silent loss.
//
// The store is intentionally generic over `T: Codable` so the Chromium shell's
// private `SessionData` and any future payload can use one tested implementation
// instead of duplicating write/rotate/quarantine logic. `T` is a pure value type
// on disk; the store itself performs no encoding policy beyond the caller's
// encoder/decoder (JSONEncoder/JSONDecoder by default).

/// Outcome of a `SessionFileStore.load()` call.
public enum SessionFileLoadResult<T: Codable & Sendable>: Sendable {
    /// A valid payload was decoded from the main file.
    case restored(T)
    /// No session file exists — a fresh start is correct; nothing to surface.
    case none
    /// The main file was present but unreadable. `quarantineURL` is where the
    /// corrupt copy was moved (so the user can inspect/recover it); `recovered`
    /// is the last known-good payload from the rolling backup, if one exists.
    case corrupt(quarantineURL: URL?, recovered: T?)
}

public struct SessionFileStore<T: Codable & Sendable>: Sendable {

    /// Main session file.
    public let url: URL
    /// Rolling last-known-good backup, sibling to the main file.
    public let prevURL: URL

    public init(url: URL, prevURL: URL? = nil) {
        self.url = url
        self.prevURL = prevURL ?? url.deletingLastPathComponent()
            .appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".prev.json")
    }

    // MARK: - Write

    /// Synchronous atomic write with backup rotation. Two-phase: encode to a
    /// uniquely-named temp file (never half-written), stage a copy of the
    /// existing primary as the backup, then replace the primary. The old
    /// primary is never moved away before the new snapshot is ready, so a
    /// failed replacement cannot erase the only good copy. All failures are
    /// best-effort — the in-memory state remains authoritative.
    ///
    /// - Parameters:
    ///   - payload: the value to persist.
    ///   - encoder: encoder to use; defaults to a fresh `JSONEncoder`.
    @discardableResult
    public func write(_ payload: T, encoder: JSONEncoder = JSONEncoder()) -> Bool {
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch { return false }

        let data: Data
        do {
            data = try encoder.encode(payload)
        } catch { return false } // encode failure leaves the existing main file untouched

        let tmp = dir.appendingPathComponent("session.\(UUID().uuidString).tmp")
        do {
            try data.write(to: tmp, options: .atomic)

            // Preserve the prior primary without moving it out of the way.
            // If staging the backup fails, keep the existing backup and still
            // retain the valid primary until the new snapshot is ready to swap.
            if FileManager.default.fileExists(atPath: url.path) {
                let backupTmp = dir.appendingPathComponent("session-prev.\(UUID().uuidString).tmp")
                do {
                    try FileManager.default.copyItem(at: url, to: backupTmp)
                    if FileManager.default.fileExists(atPath: prevURL.path) {
                        _ = try FileManager.default.replaceItemAt(prevURL, withItemAt: backupTmp)
                    } else {
                        try FileManager.default.moveItem(at: backupTmp, to: prevURL)
                    }
                } catch {
                    try? FileManager.default.removeItem(at: backupTmp)
                    // A stale backup is safer than destroying the only good
                    // primary. The primary swap below remains independent.
                }
            }

            // Replace the primary only after the complete new snapshot exists.
            // Until this succeeds, the previous primary remains readable.
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: url)
            }
            return true
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            return false
        }
    }

    // MARK: - Load

    /// Loads the payload. Returns `.restored` on a valid file, `.corrupt` if it
    /// is unreadable (the corrupt file is quarantined, never deleted, and the
    /// rolling backup is offered as recovery — the main file is then repaired
    /// from the recovered payload so recovery survives a crash before the next
    /// save), and `.corrupt` again when the main file is absent but a backup
    /// survives (interrupted rotate/swap). `.none` only when no session data
    /// exists at all — a genuine fresh start.
    ///
    /// - Parameters:
    ///   - decoder: decoder to use; defaults to a fresh `JSONDecoder`.
    public func load(decoder: JSONDecoder = JSONDecoder()) -> SessionFileLoadResult<T> {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let payload = try decoder.decode(T.self, from: data)
                return .restored(payload)
            } catch {
                let quarantine = Self.quarantineCorruptFile(at: url)
                let recovered = decodeBackup(decoder: decoder)
                // Self-repair: make the recovered state durable even if the
                // app quits before the next save.
                if let recovered { repairMain(with: recovered) }
                return .corrupt(quarantineURL: quarantine, recovered: recovered)
            }
        }
        // Main file absent. A surviving backup means the write was interrupted
        // between rotate and swap — recover instead of silently starting fresh
        // (crash-only recovery rule, AGENTS.md §15.2).
        if let recovered = decodeBackup(decoder: decoder) {
            repairMain(with: recovered)
            return .corrupt(quarantineURL: nil, recovered: recovered)
        }
        return .none
    }

    // MARK: - Backup recovery helpers

    private func decodeBackup(decoder: JSONDecoder) -> T? {
        guard let prevData = try? Data(contentsOf: prevURL) else { return nil }
        return try? decoder.decode(T.self, from: prevData)
    }

    /// Atomically rewrites the main file from the recovered payload (the
    /// `.atomic` option writes to a temp and renames, so a crash mid-repair
    /// can never leave a half-written main file). The backup is left in place.
    private func repairMain(with payload: T, encoder: JSONEncoder = JSONEncoder()) {
        guard let data = try? encoder.encode(payload) else { return }
        let dir = url.deletingLastPathComponent()
        let tmp = dir.appendingPathComponent("session-repair.\(UUID().uuidString).tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: tmp)
        }
    }

    // MARK: - Quarantine (never delete, never silently discard)

    private static func quarantineCorruptFile(at url: URL) -> URL? {
        let dir = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let stamp = Int(Date().timeIntervalSince1970)
        // UUID suffix avoids same-second name collisions on repeated corrupt
        // loads (crash-loop, tests) so the second quarantine cannot fail.
        let dest = dir.appendingPathComponent("\(stem).corrupt-\(stamp)-\(UUID().uuidString.prefix(4)).json")
        do {
            try FileManager.default.moveItem(at: url, to: dest)
            return dest
        } catch {
            return nil // best-effort; corrupt file left in place is acceptable
        }
    }
}
