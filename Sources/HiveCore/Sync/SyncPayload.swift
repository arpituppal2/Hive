import Foundation

// MARK: - SyncPayload
//
// P3.4 end-to-end encrypted sync: the unit of synchronization. Every
// CloudKit record body is a single opaque `payload` field holding the
// AES-GCM ciphertext of one of these. URLs and titles never appear as
// CloudKit fields — the cloud only ever sees an envelope.
//
// Tombstones make deletes propagate: a record removed locally is replaced
// by a `tombstone` payload with a fresh revision instead of being hard-
// deleted, so other devices converge on the delete rather than resurrecting
// the record from a stale snapshot.

public struct SyncPayload: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case kind, recordID, revision, updatedAt, deviceID, url, title, visitedAt, deleted, parentID, isFolder
    }

    /// Which browser surface this record belongs to (tab, bookmark, history).
    public enum Kind: String, Codable, Sendable, Equatable, CaseIterable {
        case tab
        case bookmark
        case history
    }

    public var kind: Kind
    /// Stable record identifier (tab id / bookmark UUID / history UUID).
    public var recordID: String
    /// Monotonic per-record revision. Bumped on every mutation, including
    /// tombstoning. The resolver compares revision-then-updatedAt.
    public var revision: UInt64
    /// Client wall-clock of the last mutation. Advisory (clients may drift);
    /// the revision is authoritative for ordering.
    public var updatedAt: Date
    /// Device that wrote this revision (stable per-install id). Used as the
    /// deterministic tie-break when revision and timestamp are equal.
    public var deviceID: String

    // Content fields. Nil on a tombstone, but nil content alone is not the
    // tombstone marker: a valid record may legitimately have no title.
    public var url: String?
    public var title: String?
    public var visitedAt: Date?
    /// Bookmark-only: the parent folder's record id, or nil for a root item.
    /// Absent in envelopes written before bookmark folders shipped (nil).
    public var parentID: String?
    /// Bookmark-only: true for a folder (no url). Absent in older envelopes
    /// (false — a content bookmark).
    public var isFolder: Bool
    /// Explicit deletion marker so empty records cannot be mistaken for deletes.
    public var deleted: Bool

    /// True when this payload represents a deletion.
    public var isTombstone: Bool { deleted }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        recordID = try container.decode(String.self, forKey: .recordID)
        revision = try container.decode(UInt64.self, forKey: .revision)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deviceID = try container.decode(String.self, forKey: .deviceID)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        visitedAt = try container.decodeIfPresent(Date.self, forKey: .visitedAt)
        // Bookmark folders shipped after the first envelope format; older
        // envelopes are root-level content bookmarks.
        parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
        isFolder = try container.decodeIfPresent(Bool.self, forKey: .isFolder) ?? false
        // Envelopes created before the explicit marker shipped are content
        // records, not deletes. This keeps the v1 envelope backward compatible.
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
    }

    public init(
        kind: Kind,
        recordID: String,
        revision: UInt64,
        updatedAt: Date = Date(),
        deviceID: String,
        url: String? = nil,
        title: String? = nil,
        visitedAt: Date? = nil,
        parentID: String? = nil,
        isFolder: Bool = false,
        deleted: Bool = false
    ) {
        self.kind = kind
        self.recordID = recordID
        self.revision = revision
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.url = url
        self.title = title
        self.visitedAt = visitedAt
        self.parentID = parentID
        self.isFolder = isFolder
        self.deleted = deleted
    }

    /// Returns a payload for the same record with the revision bumped.
    /// Saturation prevents a malformed max-revision payload from crashing the
    /// browser on the next local mutation. Explicit revisions are clamped so
    /// this helper cannot create a stale payload by accident.
    public func bumped(revision newRevision: UInt64? = nil) -> SyncPayload {
        SyncPayload(
            kind: kind,
            recordID: recordID,
            revision: max(revision, newRevision ?? nextRevision),
            updatedAt: Date(),
            deviceID: deviceID,
            url: url,
            title: title,
            visitedAt: visitedAt,
            parentID: parentID,
            isFolder: isFolder,
            deleted: deleted
        )
    }

    /// A tombstone for this record at a fresh revision — how deletes travel.
    public func tombstone() -> SyncPayload {
        SyncPayload(
            kind: kind,
            recordID: recordID,
            revision: nextRevision,
            updatedAt: Date(),
            deviceID: deviceID,
            deleted: true
        )
    }

    /// Advances monotonically without trapping at UInt64.max. A maxed record
    /// remains at the terminal revision and is still protected by its
    /// timestamp/device tie-breakers.
    private var nextRevision: UInt64 {
        revision == .max ? .max : revision + 1
    }
}
