import Foundation

/// Pure guard for encrypted sync outbox uploads.
///
/// An upload may be delayed across an async CloudKit suspension. The snapshot
/// is safe to send only while it is still the exact value in the local ledger;
/// callers should fetch the latest value and retry when this returns false.
public enum SyncOutboxPolicy {
    /// Returns false when the ledger no longer contains the snapshot, has a
    /// newer/different payload for the same record, or the payload is a
    /// Hive-owned internal tab that must never leave the local browser.
    public static func shouldUpload(
        snapshot: SyncPayload,
        current: SyncPayload?,
        knownInternalTabIDs: Set<String> = []
    ) -> Bool {
        guard !isInternalWebChromePayload(snapshot, knownInternalTabIDs: knownInternalTabIDs) else { return false }
        return snapshot == current
    }

    /// Legacy outbox entries can predate the browser-state admission guard.
    /// They must be purged before a flush rather than uploaded or counted as a
    /// retry failure.
    public static func isInternalWebChromePayload(
        _ payload: SyncPayload,
        knownInternalTabIDs: Set<String> = []
    ) -> Bool {
        guard payload.kind == .tab else { return false }
        if knownInternalTabIDs.contains(payload.recordID) { return true }
        guard let value = payload.url,
              let url = URL(string: value),
              url.scheme?.lowercased() == "hive"
        else { return false }
        return ["start", "brief", "polar"].contains(url.host?.lowercased() ?? "")
    }

    /// Returns false when the remote payload wins conflict resolution. A
    /// stale retry must remain in the outbox until the next pull resolves it;
    /// fetching a newer server change tag alone must never authorize overwrite.
    public static func shouldUpload(local: SyncPayload, remote: SyncPayload?) -> Bool {
        guard let remote else { return true }
        return SyncConflictResolver().resolve(local: local, remote: remote) == local
    }

    /// A successful flush may clear a transient retry diagnostic only when no
    /// newer upload failure was recorded while that flush was suspended.
    public static func shouldClearFailureDiagnostic(
        startingFailureEpoch: UInt64,
        currentFailureEpoch: UInt64,
        diagnostic: String?
    ) -> Bool {
        startingFailureEpoch == currentFailureEpoch
            && diagnostic?.hasPrefix("Encrypted sync outbox retained") == true
    }

    /// Rejects malformed remote content before it can enter the local ledger
    /// or count as conflict resolution.
    public static func isLocallyApplicable(_ payload: SyncPayload) -> Bool {
        guard !payload.recordID.isEmpty else { return false }
        switch payload.kind {
        case .tab:
            return payload.isTombstone || validURL(payload.url)
        case .bookmark, .history:
            guard UUID(uuidString: payload.recordID) != nil else { return false }
            return payload.isTombstone || validURL(payload.url)
        }
    }

    private static func validURL(_ value: String?) -> Bool {
        guard let value,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased() else { return false }
        if scheme == "http" || scheme == "https" { return true }
        // Hive start/brief pages are durable browser tabs, but arbitrary
        // custom schemes must never enter the synced URL surface.
        return scheme == "hive" && (host == "start" || host == "brief")
    }

    /// Returns true only when a pull applied a strict remote winner. An
    /// identical payload is a successful no-op, not conflict resolution.
    public static func didApplyRemotePayload(remote: SyncPayload, local: SyncPayload?) -> Bool {
        guard let local else { return true }
        return SyncConflictResolver().shouldApply(remote: remote, overLocal: local)
    }

    /// A conflict diagnostic is cleared only after a successful pull applies
    /// every record that raised it. Unrelated remote wins must not hide any
    /// remaining conflict.
    public static func shouldClearConflictDiagnostic(
        conflictRecordKeys: Set<String>,
        appliedRecordKeys: Set<String>,
        diagnostic: String?
    ) -> Bool {
        !conflictRecordKeys.isEmpty
            && conflictRecordKeys.isSubset(of: appliedRecordKeys)
            && diagnostic?.hasPrefix("Encrypted sync conflict pending pull") == true
    }
}
