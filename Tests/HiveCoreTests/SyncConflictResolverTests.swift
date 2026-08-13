import Testing
import Foundation
@testable import HiveCore

struct SyncConflictResolverTests {
    private let resolver = SyncConflictResolver()
    private let olderDate = Date(timeIntervalSince1970: 100)
    private let newerDate = Date(timeIntervalSince1970: 200)

    private func payload(
        revision: UInt64,
        updatedAt: Date = Date(timeIntervalSince1970: 100),
        deviceID: String = "device-a",
        deleted: Bool = false,
        title: String? = "Saved"
    ) -> SyncPayload {
        SyncPayload(
            kind: .bookmark,
            recordID: "bookmark-1",
            revision: revision,
            updatedAt: updatedAt,
            deviceID: deviceID,
            url: deleted ? nil : "https://example.com",
            title: title,
            deleted: deleted
        )
    }

    @Test("higher revision wins even when its wall clock is older")
    func revisionIsAuthoritative() {
        let local = payload(revision: 4, updatedAt: newerDate)
        let remote = payload(revision: 5, updatedAt: olderDate, deviceID: "device-b")
        #expect(resolver.resolve(local: local, remote: remote) == remote)
        #expect(resolver.shouldApply(remote: remote, overLocal: local))
    }

    @Test("tombstone at a newer revision beats a stale live record")
    func tombstoneWins() {
        let live = payload(revision: 8)
        let deleted = payload(revision: 9, deleted: true)
        #expect(deleted.isTombstone)
        #expect(resolver.resolve(local: live, remote: deleted) == deleted)
        #expect(resolver.shouldApply(remote: deleted, overLocal: live))
    }

    @Test("a live record with no title is not a tombstone")
    func emptyContentIsNotDelete() {
        let empty = payload(revision: 2, title: nil)
        #expect(!empty.isTombstone)
        #expect(empty.url == "https://example.com")
    }

    @Test("local wins when its revision is newer")
    func localWins() {
        let local = payload(revision: 10)
        let remote = payload(revision: 9, deviceID: "device-z")
        #expect(resolver.resolve(local: local, remote: remote) == local)
        #expect(!resolver.shouldApply(remote: remote, overLocal: local))
    }

    @Test("equal revision uses timestamp as the first tie-break")
    func timestampTieBreak() {
        let local = payload(revision: 3, updatedAt: olderDate, deviceID: "z")
        let remote = payload(revision: 3, updatedAt: newerDate, deviceID: "a")
        #expect(resolver.resolve(local: local, remote: remote) == remote)
    }

    @Test("equal revision and timestamp uses deterministic device ID tie-break")
    func deviceTieBreak() {
        let local = payload(revision: 3, deviceID: "device-a")
        let remote = payload(revision: 3, deviceID: "device-b")
        #expect(resolver.resolve(local: local, remote: remote) == remote)
        #expect(resolver.resolve(local: remote, remote: local) == remote)
    }

    @Test("identical remote is a no-op")
    func identicalIsNoOp() {
        let local = payload(revision: 4)
        #expect(!resolver.shouldApply(remote: local, overLocal: local))
    }

    @Test("max revision saturates instead of trapping on mutation or deletion")
    func maxRevisionSaturates() {
        let maxed = payload(revision: .max)
        let bumped = maxed.bumped()
        let tombstone = maxed.tombstone()

        #expect(bumped.revision == .max)
        #expect(!bumped.deleted)
        #expect(tombstone.revision == .max)
        #expect(tombstone.deleted)
        #expect(maxed.bumped(revision: 1).revision == .max)
        #expect(maxed.bumped(revision: .max).revision == .max)
    }

    @Test("terminal tombstones cannot be resurrected by a skewed max-revision live record")
    func terminalTombstoneWinsAtMaxRevision() {
        let tombstone = payload(
            revision: .max,
            updatedAt: olderDate,
            deviceID: "device-a",
            deleted: true
        )
        let staleLive = payload(
            revision: .max,
            updatedAt: newerDate,
            deviceID: "device-z",
            deleted: false
        )

        #expect(resolver.resolve(local: tombstone, remote: staleLive) == tombstone)
        #expect(resolver.resolve(local: staleLive, remote: tombstone) == tombstone)
        #expect(!resolver.shouldApply(remote: staleLive, overLocal: tombstone))
    }

    @Test("tombstone helper bumps revision and marks deletion explicitly")
    func tombstoneHelper() {
        let live = payload(revision: 12)
        let tombstone = live.tombstone()
        #expect(tombstone.revision == 13)
        #expect(tombstone.isTombstone)
        #expect(tombstone.deleted)
        #expect(tombstone.recordID == live.recordID)
    }
}
