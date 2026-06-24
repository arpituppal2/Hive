import Foundation

/// Prompt 1 Step 1 audit pass expressed as pure logic over node/source metadata.
///
/// Given the nodes currently in the graph, the files detected on disk now, and
/// the snapshot of files from the previous index, the auditor decides which
/// nodes are stale, which files must be reprocessed, and which can be left
/// untouched. No DB/IO is performed — the plan is computed purely from inputs.

/// A node together with the hash of the source file it was derived from.
public struct ReindexNodeAudit: Hashable, Sendable {
    public var nodeID: String
    public var sourceFileHash: String

    public init(nodeID: String, sourceFileHash: String) {
        self.nodeID = nodeID
        self.sourceFileHash = sourceFileHash
    }
}

/// Metadata snapshot of a source file used to detect changes (mtime + size).
public struct ReindexFileState: Hashable, Sendable {
    public var fileHash: String
    public var modifiedAt: Date
    public var fileSize: Int64

    public init(fileHash: String, modifiedAt: Date, fileSize: Int64) {
        self.fileHash = fileHash
        self.modifiedAt = modifiedAt
        self.fileSize = fileSize
    }
}

/// The computed audit plan: stale nodes to remove, files to reprocess, and files
/// that may be left untouched.
public struct ReindexAuditPlan: Codable, Hashable, Sendable {
    public var staleNodeIDs: [String]
    public var reprocessFileHashes: [String]
    public var untouchedFileHashes: [String]

    public init(
        staleNodeIDs: [String] = [],
        reprocessFileHashes: [String] = [],
        untouchedFileHashes: [String] = []
    ) {
        self.staleNodeIDs = staleNodeIDs
        self.reprocessFileHashes = reprocessFileHashes
        self.untouchedFileHashes = untouchedFileHashes
    }
}

/// Pure auditor that produces a deterministic `ReindexAuditPlan`.
public struct ReindexAuditor: Sendable {
    public init() {}

    /// Computes the reindex audit plan.
    ///
    /// - A node is stale when its `sourceFileHash` is no longer present among
    ///   `currentFiles` (its source no longer exists).
    /// - A file present in both current and previous snapshots is reprocessed
    ///   when its modification time *or* size differs (mtime + size, not mtime
    ///   alone); otherwise it is left untouched (not re-embedded).
    /// - A file present in current but not previous is new and is reprocessed.
    /// - Output arrays are sorted for deterministic results.
    public func plan(
        existingNodes: [ReindexNodeAudit],
        currentFiles: [String: ReindexFileState],
        previousFiles: [String: ReindexFileState]
    ) -> ReindexAuditPlan {
        var staleNodeIDs: [String] = []
        for node in existingNodes where currentFiles[node.sourceFileHash] == nil {
            staleNodeIDs.append(node.nodeID)
        }

        var reprocessFileHashes: [String] = []
        var untouchedFileHashes: [String] = []

        for (fileHash, current) in currentFiles {
            guard let previous = previousFiles[fileHash] else {
                // Present now but absent previously → new file → reprocess.
                reprocessFileHashes.append(fileHash)
                continue
            }

            if current.modifiedAt != previous.modifiedAt || current.fileSize != previous.fileSize {
                reprocessFileHashes.append(fileHash)
            } else {
                untouchedFileHashes.append(fileHash)
            }
        }

        return ReindexAuditPlan(
            staleNodeIDs: staleNodeIDs.sorted(),
            reprocessFileHashes: reprocessFileHashes.sorted(),
            untouchedFileHashes: untouchedFileHashes.sorted()
        )
    }

    /// The four named reindex progress phases, in order.
    public func progressPhases() -> [String] {
        ["Auditing existing nodes", "Extracting claims", "Deduplicating", "Rebuilding graph"]
    }

    /// Formats the summary log line emitted at the end of a reindex run.
    public func reindexLogLine(
        filesProcessed: Int,
        claimsExtracted: Int,
        duplicatesCollapsed: Int,
        staleNodesRemoved: Int,
        now: Date = Date()
    ) -> String {
        let stamp = Self.timestampFormatter.string(from: now)
        return "## [\(stamp)] reindex | \(filesProcessed) files processed, \(claimsExtracted) claims extracted, \(duplicatesCollapsed) duplicates collapsed, \(staleNodesRemoved) stale nodes removed"
    }

    /// Stable `yyyy-MM-dd HH:mm` formatter (POSIX, gregorian) for log lines.
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
