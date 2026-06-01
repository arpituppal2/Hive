import Foundation

public enum WikiVaultGitState: String, Sendable {
    case unavailable
    case initialized
    case clean
    case committed
}

public struct WikiVaultGitManager: @unchecked Sendable {
    public var vaultURL: URL
    public var fileManager: FileManager

    public init(vaultURL: URL, fileManager: FileManager = .default) {
        self.vaultURL = vaultURL
        self.fileManager = fileManager
    }

    @discardableResult
    public func ensureRepository() -> WikiVaultGitState {
        guard gitExists() else { return .unavailable }
        do {
            try fileManager.createDirectory(at: vaultURL, withIntermediateDirectories: true)
            if !fileManager.fileExists(atPath: vaultURL.appendingPathComponent(".git").path) {
                _ = runGit(["init", "-b", "main"])
                _ = runGit(["config", "user.name", "Hive"])
                _ = runGit(["config", "user.email", "hive@local.invalid"])
                try writeGitIgnoreIfNeeded()
                return .initialized
            }
            try writeGitIgnoreIfNeeded()
            return .clean
        } catch {
            return .unavailable
        }
    }

    @discardableResult
    public func commitIfNeeded(message: String = "Hive wiki maintenance") -> WikiVaultGitState {
        let state = ensureRepository()
        guard state != .unavailable else { return .unavailable }
        _ = runGit(["add", "AGENTS.md", "Colony", "flower-field/assets", ".gitignore"])
        let status = runGit(["status", "--porcelain"])
        guard !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .clean }
        _ = runGit(["commit", "-m", message])
        return .committed
    }

    private func writeGitIgnoreIfNeeded() throws {
        let url = vaultURL.appendingPathComponent(".gitignore")
        let requiredLines = [
            "flower-field/*",
            "!flower-field/assets/",
            "!flower-field/assets/**",
            "raw-sources/",
            "raw/",
            ".DS_Store",
            "*.tmp"
        ]
        guard fileManager.fileExists(atPath: url.path) else {
            try """
        flower-field/*
        !flower-field/assets/
        !flower-field/assets/**
        raw-sources/
        raw/
        .DS_Store
        *.tmp
        """.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        var existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var changed = false
        for line in requiredLines where !existing.components(separatedBy: .newlines).contains(line) {
            if !existing.hasSuffix("\n"), !existing.isEmpty {
                existing.append("\n")
            }
            existing.append(line)
            existing.append("\n")
            changed = true
        }
        if changed {
            try existing.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func gitExists() -> Bool {
        #if os(macOS)
        fileManager.isExecutableFile(atPath: "/usr/bin/git")
        #else
        false
        #endif
    }

    @discardableResult
    private func runGit(_ arguments: [String]) -> String {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.currentDirectoryURL = vaultURL
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        } catch {
            return ""
        }
        #else
        _ = arguments
        return ""
        #endif
    }
}
