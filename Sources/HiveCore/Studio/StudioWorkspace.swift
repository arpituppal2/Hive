import Foundation

// MARK: - OutputBuffer

/// Lock-guarded output accumulator for the check runner's pipe drain. Marked
/// `@unchecked Sendable` because every access is serialized by the lock — the
/// documented strict-concurrency exception (the @Sendable readabilityHandler
/// must capture it), not a hiding of a data race.
private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    func snapshot() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

// MARK: - StudioWorkspace

/// A bounded, user-selected project workspace for the code studio
/// (STUDIO-001/002). All file and command access is confined to `rootURL` —
/// absolute paths, `..` traversal, and symlink escapes are rejected. Writes
/// are always backed up so any change can be rolled back, and check commands
/// run with a minimal environment, the workspace as cwd, and a hard timeout.
///
/// This is the deterministic half of the demo spine's step 6 ("open a local
/// repository, ask Swarm to make a small approved change, inspect the diff,
/// run the project check in a bounded workspace"). The model proposes; this
/// workspace confines, diffs, applies, and rolls back.
public actor StudioWorkspace {

    // MARK: - Errors

    public enum StudioError: LocalizedError, Sendable {
        case missingRoot
        case outsideWorkspace(String)
        case unreadable(String)
        case unwritable(String)
        case commandTimedOut(String)
        /// Carries the collected output so a failing check shows WHY it failed
        /// (demo-spine step 6: "run the project check and see the result").
        case commandFailed(String, Int32, output: String)

        public var errorDescription: String? {
            switch self {
            case .missingRoot:
                return "No project folder selected."
            case .outsideWorkspace(let path):
                return "Path is outside the selected project folder: \(path)"
            case .unreadable(let path):
                return "Could not read: \(path)"
            case .unwritable(let path):
                return "Could not write: \(path)"
            case .commandTimedOut(let command):
                return "Check command timed out: \(command)"
            case .commandFailed(let command, let status, _):
                return "Check command failed (\(status)): \(command)"
            }
        }
    }

    // MARK: - Types

    /// A record of one applied edit. `backupPath` is non-nil for edits to
    /// pre-existing files (the original is preserved for rollback); nil means
    /// the file was created by the edit, so rollback deletes it.
    public struct FileEdit: Sendable, Equatable {
        public let relativePath: String
        public let originalContent: String
        public let newContent: String
        public let backupPath: String?

        public init(
            relativePath: String,
            originalContent: String,
            newContent: String,
            backupPath: String?
        ) {
            self.relativePath = relativePath
            self.originalContent = originalContent
            self.newContent = newContent
            self.backupPath = backupPath
        }
    }

    // MARK: - State

    public private(set) var rootURL: URL?

    public init(rootURL: URL? = nil) {
        self.rootURL = rootURL?.standardizedFileURL
    }

    public func selectRoot(_ url: URL) {
        rootURL = url.standardizedFileURL
    }

    public func clearRoot() {
        rootURL = nil
    }

    // MARK: - Containment

    /// True iff `url` (after standardization and symlink resolution) is inside
    /// the selected root. The single guard all file access passes through.
    public func contains(_ url: URL) -> Bool {
        guard let rootURL else { return false }
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let target = url.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = root.path
        let targetPath = target.path
        return targetPath == rootPath || targetPath.hasPrefix(rootPath + "/")
    }

    /// Resolves a user-supplied relative path against the root, rejecting
    /// absolute paths and any result that escapes the workspace.
    public func resolvedURL(for relativePath: String) throws -> URL {
        guard let rootURL else { throw StudioError.missingRoot }
        let cleaned = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw StudioError.unreadable(relativePath) }
        // Everything is relative to the root — absolute and home paths are out.
        guard !cleaned.hasPrefix("/"), !cleaned.hasPrefix("~") else {
            throw StudioError.outsideWorkspace(relativePath)
        }
        // Standardization collapses "a/../b" before containment is checked.
        let candidate = rootURL.appendingPathComponent(cleaned).standardizedFileURL
        guard contains(candidate) else { throw StudioError.outsideWorkspace(relativePath) }
        return candidate
    }

    /// The path of a file URL relative to the workspace root, or nil if the
    /// URL is outside the workspace.
    public func relativePath(for url: URL) -> String? {
        guard contains(url) else { return nil }
        let root = rootURL?.standardizedFileURL.path ?? ""
        let target = url.standardizedFileURL.path
        guard target.hasPrefix(root + "/") else { return nil }
        return String(target.dropFirst(root.count + 1))
    }

    // MARK: - Read

    public func readFile(_ relativePath: String) throws -> String {
        let url = try resolvedURL(for: relativePath)
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw StudioError.unreadable(relativePath)
        }
    }

    // MARK: - Write / Rollback

    /// Applies an edit with an automatic backup. Never silently overwrites a
    /// pre-existing file without preserving its original content.
    public func applyEdit(_ relativePath: String, newContent: String) throws -> FileEdit {
        let url = try resolvedURL(for: relativePath)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            throw StudioError.unwritable(relativePath)
        }
        let original = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

        let backupPath: String?
        if FileManager.default.fileExists(atPath: url.path) {
            backupPath = url.path + ".hivebak"
            // Clear any stale backup from a previous crashed edit.
            try? FileManager.default.removeItem(atPath: backupPath!)
            do {
                try FileManager.default.copyItem(atPath: url.path, toPath: backupPath!)
            } catch {
                throw StudioError.unwritable(relativePath)
            }
        } else {
            backupPath = nil
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try newContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw StudioError.unwritable(relativePath)
        }

        return FileEdit(
            relativePath: relativePath,
            originalContent: original,
            newContent: newContent,
            backupPath: backupPath
        )
    }

    /// Restores a file to its state before `edit` was applied. For edits to
    /// pre-existing files this restores the backup; for created files it
    /// deletes them.
    public func rollback(_ edit: FileEdit) throws {
        let url = try resolvedURL(for: edit.relativePath)
        if let backupPath = edit.backupPath {
            try? FileManager.default.removeItem(at: url)
            do {
                try FileManager.default.moveItem(atPath: backupPath, toPath: url.path)
            } catch {
                throw StudioError.unwritable(edit.relativePath)
            }
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Diff

    /// A readable unified diff between two contents for one file. Uses the
    /// first/last-difference window (with no context lines) — honest and
    /// deterministic: exactly the lines that change, prefixed `-`/`+`, with a
    /// standard `@@` hunk header. Returns "No changes." when identical.
    public static func unifiedDiff(original: String, new: String, path: String) -> String {
        let oldLines = original.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")

        var first = 0
        let shared = min(oldLines.count, newLines.count)
        while first < shared, oldLines[first] == newLines[first] { first += 1 }

        var lastOld = oldLines.count - 1
        var lastNew = newLines.count - 1
        while lastOld >= first, lastNew >= first, oldLines[lastOld] == newLines[lastNew] {
            lastOld -= 1
            lastNew -= 1
        }

        guard !(lastOld < first && lastNew < first) else { return "No changes." }

        var out = "--- a/\(path)\n"
        out += "+++ b/\(path)\n"
        out += "@@ -\(first + 1),\(max(lastOld - first + 1, 0)) +\(first + 1),\(max(lastNew - first + 1, 0)) @@\n"
        if lastOld >= first {
            for line in oldLines[first...lastOld] { out += "-" + line + "\n" }
        }
        if lastNew >= first {
            for line in newLines[first...lastNew] { out += "+" + line + "\n" }
        }
        return out
    }

    // MARK: - Bounded Check Runner

    /// Runs a check command (e.g. `swift test` or `npm test`) with the
    /// workspace as cwd, a minimal PATH, no inherited environment (no secrets
    /// leak into the child), and a hard timeout. The command is a fixed string
    /// from the producer — never constructed from model or page text.
    public func runCheck(command: String, timeout: TimeInterval = 60) throws -> String {
        guard let rootURL else { throw StudioError.missingRoot }
        let process = Process()
        process.currentDirectoryURL = rootURL
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": NSHomeDirectory()
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw StudioError.commandFailed(command, -1, output: "")
        }

        // Drain the pipe on a background queue via readabilityHandler so the
        // main path only polls isRunning + deadline — a blocking read here
        // would defeat the timeout for silent commands (e.g. `sleep 5`). The
        // buffer is lock-guarded and Sendable, so the @Sendable handler can
        // capture it under strict concurrency.
        let handle = pipe.fileHandleForReading
        let buffer = OutputBuffer()
        handle.readabilityHandler = { h in
            let data = h.availableData
            if !data.isEmpty { buffer.append(data) }
        }
        defer { handle.readabilityHandler = nil }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() > deadline {
                process.terminate()
                process.waitUntilExit()
                throw StudioError.commandTimedOut(command)
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        // Final synchronous drain: at EOF availableData returns immediately,
        // so this cannot block the deadline path — it only closes the
        // async-tail race where the last handler invocation lags process exit.
        let tail = handle.availableData
        if !tail.isEmpty { buffer.append(tail) }

        let output = String(data: buffer.snapshot(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw StudioError.commandFailed(command, process.terminationStatus, output: output)
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Git-native Rollback

    /// Restores a single file to its last committed state using `git restore`.
    /// Returns the restored content, or throws if git is unavailable, the repo
    /// is not clean enough, or the restore fails. Prefer this over the backup
    /// rollback when `.git` exists — it's the stronger contract.
    public func gitRestore(file relativePath: String) throws -> String {
        guard let rootURL else { throw StudioError.missingRoot }
        // Validate containment before shelling out.
        _ = try resolvedURL(for: relativePath)

        let process = Process()
        process.currentDirectoryURL = rootURL
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["restore", relativePath]
        process.environment = [
            "PATH": "/usr/bin:/bin",
            "HOME": NSHomeDirectory()
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw StudioError.unwritable(relativePath)
        }
        // Bounded wait with a 30s timeout — git restore on a single file is
        // normally sub-second, but network mounts or credential prompts can
        // hang indefinitely. The deadline prevents an actor freeze.
        let deadline = Date().addingTimeInterval(30)
        while process.isRunning {
            if Date() > deadline {
                process.terminate()
                process.waitUntilExit()
                throw StudioError.commandTimedOut("git restore \(relativePath)")
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard process.terminationStatus == 0 else {
            let errData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? "unknown error"
            throw StudioError.commandFailed("git restore \(relativePath)", process.terminationStatus, output: errStr)
        }
        return try readFile(relativePath)
    }

    // MARK: - Repo Detection

    public func isGitRepository() -> Bool {
        guard let rootURL else { return false }
        return FileManager.default.fileExists(
            atPath: rootURL.appendingPathComponent(".git").path
        )
    }
}
