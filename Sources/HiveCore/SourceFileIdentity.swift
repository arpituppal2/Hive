import Foundation

/// Prompt 1 Step 2 source attribution identity.
///
/// Identifies a source file by a stable SHA256 fingerprint derived from its
/// path, modification time, and size. Two identities for the same file are
/// considered unchanged when their modification time *and* size match
/// (mtime + size, not mtime alone).
public struct SourceFileIdentity: Codable, Hashable, Sendable {
    public var filePath: String
    public var modifiedAt: Date
    public var fileSize: Int64
    public var sourceFileID: String

    public init(filePath: String, modifiedAt: Date, fileSize: Int64) {
        self.filePath = filePath
        self.modifiedAt = modifiedAt
        self.fileSize = fileSize

        let fingerprint = "\(filePath)|\(modifiedAt.timeIntervalSince1970)|\(fileSize)"
        let data = Data(fingerprint.utf8)
        self.sourceFileID = Hashing.sha256(data: data)
    }

    /// Builds an identity for the file at `url` by reading its content
    /// modification date and size. Missing values fall back to sensible
    /// defaults (epoch for the date, `0` for the size).
    public static func make(
        forFileAt url: URL,
        fileManager: FileManager = .default
    ) throws -> SourceFileIdentity {
        _ = fileManager
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modifiedAt = values.contentModificationDate ?? Date(timeIntervalSince1970: 0)
        let fileSize = Int64(values.fileSize ?? 0)
        return SourceFileIdentity(filePath: url.path, modifiedAt: modifiedAt, fileSize: fileSize)
    }

    /// Returns `true` when `a` and `b` represent the same file content per the
    /// mtime + size policy.
    public static func isUnchanged(_ a: SourceFileIdentity, comparedTo b: SourceFileIdentity) -> Bool {
        a.modifiedAt == b.modifiedAt && a.fileSize == b.fileSize
    }
}
