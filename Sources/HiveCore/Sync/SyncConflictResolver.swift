import CryptoKit
import Foundation

// MARK: - SyncConflictResolver
//
// P3.4 deterministic convergence: given a local payload and the remote
// payload for the same record, pick the single winning state both devices
// will agree on without further coordination.
//
// Ordering (all deterministic):
//   1. Revision — higher wins (tombstones carry bumped revisions, so a
//      delete always beats the stale snapshot it deletes).
//   2. updatedAt — advisory tie-break for mixed-version peers.
//   3. deviceID — final deterministic tie-break (stable per-install id,
//      lexicographic comparison).

public struct SyncConflictResolver: Sendable {

    public init() {}

    /// Compares two payloads for the same record. Returns the winner.
    public func resolve(local: SyncPayload, remote: SyncPayload) -> SyncPayload {
        precondition(
            local.recordID == remote.recordID && local.kind == remote.kind,
            "resolver only compares payloads for the same record kind and ID"
        )
        if local.revision != remote.revision {
            return local.revision > remote.revision ? local : remote
        }
        // A saturated terminal revision cannot advance further. Preserve the
        // deletion boundary so a max-revision tombstone cannot be resurrected
        // by a same-revision live payload with a skewed clock.
        if local.revision == .max && local.deleted != remote.deleted {
            return local.deleted ? local : remote
        }
        if local.updatedAt != remote.updatedAt {
            return local.updatedAt > remote.updatedAt ? local : remote
        }
        // Equal revisions and timestamps: deterministic device tie-break.
        if local.deviceID != remote.deviceID {
            return local.deviceID > remote.deviceID ? local : remote
        }
        // Same device can still produce divergent payloads after a crash or
        // retry. Compare canonical payload digests so both peers converge.
        return digest(local) >= digest(remote) ? local : remote
    }

    /// True when the incoming payload is strictly newer than the local one —
    /// the condition under which a pull should apply the remote state.
    public func shouldApply(remote: SyncPayload, overLocal local: SyncPayload?) -> Bool {
        guard let local else { return true }
        let winner = resolve(local: local, remote: remote)
        // Apply only when the remote is the strict winner. If local wins,
        // the remote must not overwrite it; if both are identical this is a
        // no-op pull.
        return isIdentical(remote, winner) && !isIdentical(remote, local)
    }

    private func digest(_ payload: SyncPayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Strict equality helper used by `shouldApply` so a no-op pull never
    /// bumps anything.
    private func isIdentical(_ a: SyncPayload, _ b: SyncPayload) -> Bool {
        a.kind == b.kind
            && a.recordID == b.recordID
            && a.revision == b.revision
            && a.updatedAt == b.updatedAt
            && a.deviceID == b.deviceID
            && a.deleted == b.deleted
            && a.url == b.url
            && a.title == b.title
            && a.visitedAt == b.visitedAt
    }
}
