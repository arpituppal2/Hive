import Foundation

// MARK: - BrowserSessionStore
//
// Atomic disk-backed persistence for the restorable session (`BrowserSession`). Mirrors
// `ChromePrefsStore`'s actor + two-phase atomic write + corrupt-file-quarantine contract
// (AGENTS.md §15.2), extended with two things the session specifically needs:
//
//   1. A 2-second *debounced* save (§9 — "on every mutation, debounced 2s") so serializing on
//      every progress tick doesn't thrash the disk. The debounce lives in the actor: callers
//      hand over a fresh Sendable snapshot; the actor coalesces, writing only after 2s of
//      quiet. `flush` writes immediately (for app termination).
//   2. A rolling backup (`session.prev.json`). Before each successful write, the prior good
//      `session.json` is stashed as the backup. So if the current file is ever unreadable, we
//      quarantine it AND can offer the last known-good session ("Restore last session") — the
//      crash-only contract's recovery path, never a silent loss.
//
// The store is a thin durable-overlay; the live `ChromeState` (Hive target) is what views bind
// to and it calls into here.

public actor BrowserSessionStore {

    private let url: URL
    private let prevURL: URL
    private var debounceTask: Task<Void, Never>?
    private let debounceNs: UInt64

    /// Canonical session file: `~/Library/Application Support/Hive/session.json`.
    public static let defaultURL: URL = {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                  appropriateFor: nil, create: true)
        let base = support ?? fm.temporaryDirectory
        return base.appendingPathComponent("Hive/session.json")
    }()

    /// Rolling last-known-good backup, sibling to the session file.
    public static let defaultPrevURL: URL =
        defaultURL.deletingLastPathComponent().appendingPathComponent("session.prev.json")

    /// - Parameters:
    ///   - url: session file URL (defaults to `defaultURL`).
    ///   - prevURL: backup file URL (defaults to `defaultPrevURL`).
    ///   - debounceSeconds: quiet window before a scheduled write fires (§9: 2s default).
    public init(url: URL = BrowserSessionStore.defaultURL,
                prevURL: URL = BrowserSessionStore.defaultPrevURL,
                debounceSeconds: Double = 2.0) {
        self.url = url
        self.prevURL = prevURL
        self.debounceNs = UInt64(max(0, debounceSeconds) * 1_000_000_000)
    }

    // MARK: - Save (debounced coalescing)

    /// Schedules a coalesced write: keeps only the most recent `session`, writing after
    /// `debounceSeconds` of quiet. Each call cancels any pending write and resets the timer,
    /// so a burst of mutations produces exactly one disk write, ~2s after the last mutation.
    public func scheduleSave(_ session: BrowserSession) {
        debounceTask?.cancel()
        let snapshot = session
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: debounceNs)
            if Task.isCancelled { return }
            Self.writeSync(
                snapshot,
                to: url,
                prevBackupTo: prevURL
            )
        }
    }

    /// Immediate, non-debounced write — for app termination, where we cannot wait for the
    /// debounce. Cancels any pending coalesced write first.
    public func flush(_ session: BrowserSession) async {
        debounceTask?.cancel()
        Self.writeSync(session, to: url, prevBackupTo: prevURL)
    }

    /// Synchronous, nonisolated immediate write — the app-termination path. `applicationWillTerminate`
    /// cannot `await` an actor call (the process may exit first), so the SwiftUI `.onReceive` for
    /// `NSApplication.willTerminateNotification` calls this directly: it builds no `Task`, hops no
    /// isolation, and writes synchronously via the shared `writeSync`. `url`/`prevURL` are `let`
    /// (nonisolated-safe on an actor), so this is safe to reach from the main-actor notification
    /// handler. A pending debounced write would lapse with the process — harmless given atomic
    /// temp-file-then-swap writes (last writer wins, both consistent).
    public nonisolated func flushSync(_ session: BrowserSession) {
        Self.writeSync(session, to: url, prevBackupTo: prevURL)
    }

    // MARK: - Load

    /// Loads the session. A valid file returns `.restored` with a non-sensitive repair report;
    /// absent data returns `.none`; unreadable data returns `.corrupt` after quarantine with the
    /// rolling backup and its repair report offered as recovery. Actor-isolated cache-free: a
    /// fresh read each call is correct for the launch-time loader; save re-reads nothing.
    public func load() -> SessionLoadResult { Self.read(from: url, prev: prevURL) }

    /// Synchronous, nonisolated launch-time loader (mirrors `ChromePrefsStore.loadSync`),
    /// called before the first frame so restored tabs/spaces paint immediately — no "snap" from
    /// a fresh window to the restored session. Applies the same privacy/reference normalizer and
    /// corrupt/quarantine + backup-recovery semantics; does not touch the actor's state.
    public nonisolated static func loadSync(url: URL = BrowserSessionStore.defaultURL,
                                            prevURL: URL = BrowserSessionStore.defaultPrevURL
    ) -> SessionLoadResult {
        Self.read(from: url, prev: prevURL)
    }

    // MARK: - Disk I/O (nonisolated; safe to call from actor methods, the static sync loader,
    //              and the synchronous app-termination flush path)

    private nonisolated static func read(from url: URL, prev: URL) -> SessionLoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            guard let recovered = recoverBackup(from: prev) else { return .none }
            repairMain(with: recovered.session, to: url)
            return .corrupt(
                quarantineURL: nil,
                recovered: recovered.session,
                repair: recovered.report
            )
        }
        do {
            let data = try Data(contentsOf: url)
            let normalization = try JSONDecoder.hiveSession.decode(BrowserSession.self, from: data).normalizedForRestore
            return .restored(normalization.session, repair: normalization.report)
        } catch {
            // Corrupt — quarantine the unreadable file (never delete; preserve for the user to
            // inspect/recover), then offer the rolling backup as recovery if it parses.
            let quarantine = quarantineCorruptFile(at: url, reason: "\(error)")
            let recovered = recoverBackup(from: prev)
            if let recovered {
                repairMain(with: recovered.session, to: url)
            }
            let repair = recovered?.report ?? BrowserSessionRepairReport()
            return .corrupt(quarantineURL: quarantine, recovered: recovered?.session, repair: repair)
        }
    }

    /// Tries to decode the rolling backup; returns nil if it's missing or also unreadable.
    private nonisolated static func recoverBackup(from prev: URL) -> BrowserSessionNormalization? {
        guard FileManager.default.fileExists(atPath: prev.path) else { return nil }
        do {
            let data = try Data(contentsOf: prev)
            return try JSONDecoder.hiveSession.decode(BrowserSession.self, from: data).normalizedForRestore
        } catch {
            return nil
        }
    }

    private nonisolated static func repairMain(with session: BrowserSession, to url: URL) {
        let dir = url.deletingLastPathComponent()
        let tmp = dir.appendingPathComponent("session-repair.\(UUID().uuidString).tmp")
        do {
            let data = try JSONEncoder.hiveSession.encode(session.sanitizedForPersistence)
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

    /// synchronous atomic write with backup rotation, the single implementation shared by the
    /// debounced async path, `flush`, and the app-termination sync path. Two-phase: write to a
    /// uniquely-named temp file (atomic, so the temp is never half-written), then swap into
    /// `url`. Before the swap, the existing good `url` (if any) is moved to `prev` so it
    /// becomes the last-known-good backup.
    public nonisolated static func writeSync(_ session: BrowserSession, to url: URL,
                                             prevBackupTo prev: URL) {
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch { return }

        let data: Data
        do {
            data = try JSONEncoder.hiveSession.encode(session.sanitizedForPersistence)
        } catch { return }

        let tmp = dir.appendingPathComponent("session.\(UUID().uuidString).tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                let backupTmp = dir.appendingPathComponent("session-prev.\(UUID().uuidString).tmp")
                do {
                    try FileManager.default.copyItem(at: url, to: backupTmp)
                    if FileManager.default.fileExists(atPath: prev.path) {
                        _ = try FileManager.default.replaceItemAt(prev, withItemAt: backupTmp)
                    } else {
                        try FileManager.default.moveItem(at: backupTmp, to: prev)
                    }
                } catch {
                    try? FileManager.default.removeItem(at: backupTmp)
                }
            }
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: tmp)
        }
    }

    // MARK: - Quarantine (mirrors ChromePrefsStore — never delete, never silently discard)

    private nonisolated static func quarantineCorruptFile(at url: URL, reason: String) -> URL? {
        let dir = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = dir.appendingPathComponent("\(stem).corrupt-\(stamp)-\(UUID().uuidString).json")
        do { try FileManager.default.moveItem(at: url, to: dest); return dest }
        catch { return nil }   // best-effort; corrupt file left in place is acceptable
    }
}

// MARK: - Session JSON coders
//
// Stable, pretty-printed, sorted-key encoding (matches ChromePrefsStore's encodePretty) so
// session.json diffs sanely and dates are ISO-8601. Decoding uses the same ISO-8601 strategy so
// the store's own writes round-trip exactly. The session types' custom `init(from:)` use
// `decodeIfPresent` for forward-compat with older schemas.

private extension JSONEncoder {
    /// Returns a fresh coder for each operation. JSONEncoder is mutable and
    /// Foundation does not guarantee that one instance can be used concurrently
    /// by the actor's sync flush path and parallel launch/test readers.
    static var hiveSession: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    /// Returns a fresh coder for each operation. Sharing a mutable decoder across
    /// concurrent test/runtime loads can produce nondeterministic decode failures.
    static var hiveSession: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
