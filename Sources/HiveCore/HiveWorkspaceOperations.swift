import Foundation
import SQLite3

public struct HiveWorkspaceResetResult: Sendable {
    public var backupURL: URL?
    public var removedItemCount: Int
    public var integrityStatus: String
}

public enum HiveWorkspaceOperations {
    public static func exportAllData(
        store: HiveStore,
        paths: HivePaths,
        to parentDirectory: URL,
        now: Date = Date()
    ) throws -> URL {
        let exportRoot = try HiveExporter().exportSnapshot(store: store, to: parentDirectory, now: now)
        let vaultCopy = exportRoot.appendingPathComponent("vault", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultCopy, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: paths.vault.path) {
            try FileManager.default.copyItem(at: paths.vault, to: vaultCopy.appendingPathComponent("Colony", isDirectory: true))
        }
        if FileManager.default.fileExists(atPath: paths.rawStore.path) {
            try FileManager.default.copyItem(at: paths.rawStore, to: exportRoot.appendingPathComponent("raw", isDirectory: true))
        }
        try store.appendAudit(AuditEventRecord(
            eventType: "workspace.exported",
            targetType: "workspace",
            targetID: "all",
            detail: "Exported Hive workspace to \(exportRoot.lastPathComponent)."
        ))
        return exportRoot
    }

    public static func backupDatabase(at databaseURL: URL, now: Date = Date()) throws -> URL {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HHmmss'Z'"
        let stamp = formatter.string(from: now)
        let backupURL = databaseURL.deletingLastPathComponent()
            .appendingPathComponent("Hive.sqlite.corrupted-\(stamp)")
        if FileManager.default.fileExists(atPath: databaseURL.path) {
            try FileManager.default.copyItem(at: databaseURL, to: backupURL)
        }
        return backupURL
    }

    public static func resetWorkspace(
        root: URL,
        databaseURL: URL,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> HiveWorkspaceResetResult {
        let backupURL = try backupDatabase(at: databaseURL, now: now)
        var removed = 0
        let children = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for child in children {
            try fileManager.removeItem(at: child)
            removed += 1
        }
        let integrityStatus = fileManager.fileExists(atPath: databaseURL.path) ? "partial" : "ok"
        return HiveWorkspaceResetResult(
            backupURL: backupURL,
            removedItemCount: removed,
            integrityStatus: integrityStatus
        )
    }

    public static func runIntegrityCheck(store: HiveStore) throws -> String {
        let result: String = try store.withConnection { db in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, "PRAGMA quick_check", -1, &statement, nil) == SQLITE_OK else {
                return "error"
            }
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let cString = sqlite3_column_text(statement, 0) else {
                return "error"
            }
            return String(cString: cString)
        }
        return result.lowercased() == "ok" ? "✓ ok" : result
    }
}
