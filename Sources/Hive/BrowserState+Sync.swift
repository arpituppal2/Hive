import CloudKit
import CryptoKit
import Foundation
import HiveCore

// MARK: - SyncManager (CloudKit lifecycle wrapper)
//
// Holds the CloudKitSyncEngine, the E2E sync key, and sync bookkeeping.
// Owned by BrowserState through an associated-object pattern so the
// extension adds no stored properties to the @Observable class. The engine
// is nil when CloudKit is unavailable; the key is nil when Keychain
// provisioning fails (sync silently degrades off).

@MainActor
final class SyncManager: Sendable {
    var engine: CloudKitSyncEngine?
    var syncKey: SymmetricKey?
    var hasCompletedInitialSync: Bool = false
    var syncDiagnostic: String?
    /// Monotonic marker preventing an older successful flush from clearing a
    /// retry diagnostic raised by a concurrent per-record upload.
    var syncUploadFailureEpoch: UInt64 = 0
    var pendingConflictRecordKeys = Set<String>()
    var hasPendingRemoteNotification = false

    /// Stable per-install device id used as the resolver tie-break.
    var deviceID: String {
        if let stored = UserDefaults.standard.string(forKey: "hive.sync.deviceID") {
            return stored
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: "hive.sync.deviceID")
        return fresh
    }

    /// Per-record revision table persisted across launches so a restart can
    /// never resurrect stale local state over newer remote revisions.
    private var revisionsKey = "hive.sync.revisions"
    private let payloadsKey = "hive.sync.payloads.v2"
    private let internalTabIDsKey = "hive.sync.internal-tab-ids.v1"
    private var ledgerKey: SymmetricKey?

    /// Durable local provenance for Hive-owned tab IDs. This lets the outbox
    /// recognize an old tombstone even though tombstones intentionally carry
    /// no URL.
    var internalTabIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: internalTabIDsKey) ?? [])
    }

    func markInternalTab(_ id: String) {
        var ids = internalTabIDs
        ids.insert(id)
        UserDefaults.standard.set(Array(ids).sorted(), forKey: internalTabIDsKey)
    }

    private var _payloads: [String: SyncPayload]?
    var payloads: [String: SyncPayload] {
        if let _payloads { return _payloads }
        guard let data = UserDefaults.standard.data(forKey: payloadsKey),
              let key = ledgerKey,
              let plaintext = try? SyncCipher().decryptData(data, with: key),
              let decoded = try? JSONDecoder().decode([String: SyncPayload].self, from: plaintext)
        else {
            _payloads = [:]
            return [:]
        }
        _payloads = decoded
        return decoded
    }

    /// Installs the synchronizable key before loading the encrypted local
    /// outbox. Any legacy plaintext v1 ledger is discarded rather than read
    /// or re-exposed; CloudKit migration handles the remote copy separately.
    func configureLedgerKey(_ key: SymmetricKey) {
        ledgerKey = key
        if _payloads == nil { _ = payloads }
        UserDefaults.standard.removeObject(forKey: "hive.sync.payloads.v1")
        persistPayloads()
    }

    private func ledgerID(kind: SyncPayload.Kind, recordID: String) -> String {
        "\(kind.rawValue):\(recordID)"
    }

    /// Namespaced ledger key for upload/retry coordination.
    func payloadKey(kind: SyncPayload.Kind, recordID: String) -> String {
        ledgerID(kind: kind, recordID: recordID)
    }

    func payload(for recordID: String, kind: SyncPayload.Kind? = nil) -> SyncPayload? {
        if let kind { return payloads[ledgerID(kind: kind, recordID: recordID)] }
        return payloads.values.first { $0.recordID == recordID }
    }

    /// Returns the persisted revision for one namespaced record. Callers must
    /// use this helper rather than reconstructing `kind:recordID` themselves;
    /// tab, bookmark, and history UUIDs are independent namespaces.
    func revision(for kind: SyncPayload.Kind, recordID: String) -> UInt64 {
        revisions[ledgerID(kind: kind, recordID: recordID)] ?? 0
    }

    func setPayload(_ payload: SyncPayload) {
        var table = payloads
        let key = ledgerID(kind: payload.kind, recordID: payload.recordID)
        table[key] = payload
        _payloads = table
        persistPayloads()
        setRevision(payload.revision, for: key)
    }

    func removePayload(for key: String) {
        var table = payloads
        guard table.removeValue(forKey: key) != nil else { return }
        _payloads = table
        persistPayloads()
    }

    func nextRevision(kind: SyncPayload.Kind, recordID: String) -> UInt64 {
        let key = ledgerID(kind: kind, recordID: recordID)
        let next = (revisions[key] ?? 0) + 1
        setRevision(next, for: key)
        return next
    }

    private func persistPayloads() {
        guard let ledgerKey, let table = _payloads,
              let plaintext = try? JSONEncoder().encode(table),
              let encrypted = try? SyncCipher().encryptData(plaintext, with: ledgerKey) else { return }
        UserDefaults.standard.set(encrypted, forKey: payloadsKey)
    }

    private var _revisions: [String: UInt64]?
    var revisions: [String: UInt64] {
        if let _revisions { return _revisions }
        let loaded = (UserDefaults.standard.dictionary(forKey: revisionsKey) as? [String: UInt64]) ?? [:]
        _revisions = loaded
        return loaded
    }

    func setRevision(_ revision: UInt64, for recordID: String) {
        var table = revisions
        table[recordID] = max(table[recordID] ?? 0, revision)
        _revisions = table
        UserDefaults.standard.set(table, forKey: revisionsKey)
    }

    var isAvailable: Bool { engine != nil && syncKey != nil }

    init() {}
}

// MARK: - BrowserState CloudKit sync extension

extension BrowserState {

    // ── Associated-object key (no stored properties in extensions) ──────

    private static var syncManagerKey: UInt8 = 0

    private var syncManager: SyncManager {
        if let existing = objc_getAssociatedObject(self, &Self.syncManagerKey) as? SyncManager {
            return existing
        }
        let manager = SyncManager()
        objc_setAssociatedObject(self, &Self.syncManagerKey, manager, .OBJC_ASSOCIATION_RETAIN)
        return manager
    }

    var syncEngine: CloudKitSyncEngine? { syncManager.engine }
    var isSyncAvailable: Bool { syncManager.isAvailable }
    var hasCompletedInitialSync: Bool { syncManager.hasCompletedInitialSync }
    var syncDiagnostic: String? { syncManager.syncDiagnostic }

    /// Records internal-route provenance synchronously at tab creation so a
    /// close before CloudKit setup cannot emit an anonymous tombstone.
    func markInternalTabIfNeeded(_ tab: Tab) {
        if Self.isInternalWebChromeURL(tab.model.url) || Self.isInternalWebChromeURL(tab.savedURL) {
            syncManager.markInternalTab(tab.id)
        }
    }

    // ── Ledger seeding ──────────────────────────────────────────────────

    /// Seeds the durable ledger from restored local state before the first
    /// remote pull. A missing ledger entry must not let a remote tombstone
    /// erase a local record without a comparable baseline.
    func seedLocalPayloads() {
        for tab in tabs where !tab.isPrivate {
            guard let url = tab.model.url else { continue }
            if Self.isInternalWebChromeURL(url) {
                syncManager.markInternalTab(tab.id)
                continue
            }
            guard syncManager.payload(for: tab.id, kind: .tab) == nil else { continue }
            syncManager.setPayload(SyncPayload(
                kind: .tab,
                recordID: tab.id,
                revision: syncManager.revision(for: .tab, recordID: tab.id),
                updatedAt: .distantPast,
                deviceID: syncManager.deviceID,
                url: url.absoluteString,
                title: tab.model.title
            ))
        }
        for bookmark in bookmarks {
            let id = bookmark.id.uuidString
            guard syncManager.payload(for: id, kind: .bookmark) == nil else { continue }
            syncManager.setPayload(SyncPayload(
                kind: .bookmark,
                recordID: id,
                revision: syncManager.revision(for: .bookmark, recordID: id),
                updatedAt: .distantPast,
                deviceID: syncManager.deviceID,
                url: bookmark.isFolder ? nil : bookmark.url.absoluteString,
                title: bookmark.title,
                parentID: bookmark.parentID?.uuidString,
                isFolder: bookmark.isFolder
            ))
        }
        for item in historyItems {
            let id = item.id.uuidString
            guard syncManager.payload(for: id, kind: .history) == nil else { continue }
            syncManager.setPayload(SyncPayload(
                kind: .history,
                recordID: id,
                revision: syncManager.revision(for: .history, recordID: id),
                updatedAt: .distantPast,
                deviceID: syncManager.deviceID,
                url: item.url.absoluteString,
                title: item.title,
                visitedAt: item.visitedAt
            ))
        }
    }

    // ── Tombstones ───────────────────────────────────────────────────────

    /// Publishes a delete marker instead of deleting the CloudKit record. The
    /// marker is retained in the local ledger until a future retention pass
    /// can prove every peer has observed it.
    func pushTombstone(kind: SyncPayload.Kind, recordID: String) async {
        if kind == .tab, syncManager.internalTabIDs.contains(recordID) {
            syncManager.removePayload(for: syncManager.payloadKey(kind: kind, recordID: recordID))
            return
        }
        let tombstone = SyncPayload(
            kind: kind,
            recordID: recordID,
            revision: syncManager.nextRevision(kind: kind, recordID: recordID),
            deviceID: syncManager.deviceID,
            deleted: true
        )
        // Persist before checking availability: offline deletes must remain in
        // the outbox and be flushed after the next successful setup.
        syncManager.setPayload(tombstone)
        guard let engine = syncManager.engine, let key = syncManager.syncKey else { return }
        if !(await uploadLatestPayloadToCloud(
            recordKey: syncManager.payloadKey(kind: kind, recordID: recordID),
            engine: engine,
            key: key
        )) {
            markSyncUploadFailure()
        }
    }

    /// Fire-and-forget deletion boundary used by synchronous UI mutations.
    func enqueueSyncTombstone(kind: SyncPayload.Kind, recordID: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.pushTombstone(kind: kind, recordID: recordID)
        }
    }

    // ── Setup ───────────────────────────────────────────────────────────

    func setupSync() {
        guard syncManager.engine == nil else { return }

        // CloudKit's default container is not safe to probe speculatively:
        // on a bundle without an iCloud container entitlement,
        // CKContainer.default() can raise a synchronous CKException before
        // accountStatus() has a chance to report an error. Sync is therefore
        // explicitly opt-in through the bundle configuration produced by the
        // release pipeline. Missing configuration is a supported local-only
        // mode, not a startup failure.
        guard let containerIdentifier = CloudKitConfiguration.configuredContainer() else {
            syncManager.syncDiagnostic = "CloudKit container is not configured or not entitled; sync remains local-only."
            syncState = .unavailable
            return
        }

        let engine = CloudKitSyncEngine(containerIdentifier: containerIdentifier)
        syncManager.engine = engine
        syncManager.syncDiagnostic = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            // E2E key: provisioned once in the Keychain. Sync stays off if
            // the Keychain is unavailable — never sync plaintext.
            guard let key = try? await SyncKeyStore().loadOrCreateKey() else {
                self.syncManager.syncDiagnostic = "Encrypted sync key is unavailable; sync remains local-only."
                self.syncState = .error("Encrypted sync key is unavailable")
                self.syncManager.engine = nil
                self.broadcastWebChromeState()
                return
            }
            self.syncManager.syncKey = key
            self.syncManager.configureLedgerKey(key)
            self.seedLocalPayloads()
            do {
                let status = try await engine.accountStatus()
                guard status == .available else {
                    self.syncManager.syncDiagnostic = "CloudKit account is unavailable; sync remains local-only."
                    self.syncState = .error("CloudKit account unavailable")
                    self.syncManager.engine = nil
                    self.broadcastWebChromeState()
                    return
                }
                try await engine.setupSubscription()
                do {
                    _ = try await engine.migrateLegacyPlaintextRecords(
                        key: key,
                        deviceID: syncManager.deviceID
                    )
                } catch {
                    self.syncManager.syncDiagnostic = "Encrypted sync migration is pending; existing records were not overwritten."
                    self.broadcastWebChromeState()
                }
                self.syncState = .syncing
                let initialPullSucceeded = await self.pullFromCloud()
                guard initialPullSucceeded else {
                    self.syncManager.hasPendingRemoteNotification = true
                    self.syncManager.syncDiagnostic = "Initial cloud sync could not complete; local browsing continues safely."
                    self.syncState = .error("Initial sync could not complete")
                    self.broadcastWebChromeState()
                    return
                }
                await self.flushPendingPayloads()
                self.syncManager.hasCompletedInitialSync = true
                self.syncState = .available
                self.lastSyncDate = Date()
                // A notification may have arrived while key/account setup was
                // in flight. The startup pull above is authoritative; replay
                // once more only if the latch was set before setup completed.
                let hadPendingNotification = self.syncManager.hasPendingRemoteNotification
                self.syncManager.hasPendingRemoteNotification = false
                if hadPendingNotification {
                    await self.handleRemoteSyncNotification()
                }
            } catch {
                self.syncManager.syncDiagnostic = "Cloud sync is unavailable; local browsing continues safely."
                self.syncState = .error("Cloud sync unavailable")
                self.syncManager.engine = nil
                self.broadcastWebChromeState()
            }
        }
    }

    // ── Push (local → CloudKit, encrypted) ──────────────────────────────

    /// Flushes the durable ledger after connectivity/key availability returns.
    /// This is the encrypted outbox for offline edits and tombstones. Failed
    /// writes remain staged and surface a non-sensitive retry diagnostic rather
    /// than disappearing behind `try?`.
    func flushPendingPayloads() async {
        guard let engine = syncManager.engine, let key = syncManager.syncKey else { return }
        let startingFailureEpoch = syncManager.syncUploadFailureEpoch
        var failedUploads = 0
        let recordKeys = Array(syncManager.payloads.keys)
        for recordKey in recordKeys {
            guard let payload = syncManager.payloads[recordKey] else { continue }
            if SyncOutboxPolicy.isInternalWebChromePayload(
                payload,
                knownInternalTabIDs: syncManager.internalTabIDs
            ) {
                // Purge stale internal-route entries left by older builds;
                // Hive-owned UI must never be uploaded or retained as a
                // perpetual retry diagnostic.
                syncManager.removePayload(for: recordKey)
                continue
            }
            if !(await uploadLatestPayloadToCloud(recordKey: recordKey, engine: engine, key: key)) {
                failedUploads += 1
            }
        }
        if failedUploads > 0 {
            markSyncUploadFailure(count: failedUploads)
        } else if SyncOutboxPolicy.shouldClearFailureDiagnostic(
            startingFailureEpoch: startingFailureEpoch,
            currentFailureEpoch: syncManager.syncUploadFailureEpoch,
            diagnostic: syncManager.syncDiagnostic
        ) {
            syncManager.syncDiagnostic = nil
            broadcastWebChromeState()
        }
    }

    /// Performs one encrypted upload without exposing CloudKit error details
    /// (which may contain account/container information). The payload was
    /// already persisted in the local encrypted ledger, so a failure is safe
    /// to retry on the next setup or remote-sync cycle.
    private enum UploadOutcome {
        case uploaded
        case failed
        case remoteConflict
    }

    private func uploadPayloadToCloud(
        _ payload: SyncPayload,
        engine: CloudKitSyncEngine,
        key: SymmetricKey
    ) async -> UploadOutcome {
        do {
            try await engine.saveEnvelope(payload, key: key)
            return .uploaded
        } catch is CloudKitSyncEngine.SaveConflict {
            return .remoteConflict
        } catch {
            return .failed
        }
    }

    /// Uploads the current ledger value and rechecks it after each suspension.
    /// A bounded loop prevents a hot record from making flush unbounded while
    /// ensuring a delayed old snapshot cannot overwrite a newer local edit.
    private func uploadLatestPayloadToCloud(
        recordKey: String,
        engine: CloudKitSyncEngine,
        key: SymmetricKey
    ) async -> Bool {
        for _ in 0..<3 {
            guard let snapshot = syncManager.payloads[recordKey] else { return true }
            guard SyncOutboxPolicy.shouldUpload(
                snapshot: snapshot,
                current: syncManager.payloads[recordKey],
                knownInternalTabIDs: syncManager.internalTabIDs
            ) else {
                continue
            }
            switch await uploadPayloadToCloud(snapshot, engine: engine, key: key) {
            case .failed:
                return false
            case .remoteConflict:
                syncManager.pendingConflictRecordKeys.insert(recordKey)
                syncManager.syncDiagnostic = "Encrypted sync conflict pending pull; local outbox retained."
                broadcastWebChromeState()
                return false
            case .uploaded:
                break
            }
            if SyncOutboxPolicy.shouldUpload(
                snapshot: snapshot,
                current: syncManager.payloads[recordKey],
                knownInternalTabIDs: syncManager.internalTabIDs
            ) {
                return true
            }
        }
        return false
    }

    private func markSyncUploadFailure(count: Int = 1) {
        let boundedCount = max(1, count)
        syncManager.syncUploadFailureEpoch &+= 1
        if syncManager.syncDiagnostic?.hasPrefix("Encrypted sync conflict pending pull") != true {
            syncManager.syncDiagnostic = "Encrypted sync outbox retained; \(boundedCount) upload(s) pending retry."
        }
        broadcastWebChromeState()
    }

    func pushTabsToCloud() async {
        for tab in tabs where !tab.isPrivate {
            await pushTabToCloud(tab)
        }
    }

    func pushTabToCloud(_ tab: Tab) async {
        guard !tab.isPrivate, let url = tab.model.url else { return }
        if Self.isInternalWebChromeURL(url) {
            syncManager.markInternalTab(tab.id)
            return
        }
        let payload = SyncPayload(
            kind: .tab,
            recordID: tab.id,
            revision: syncManager.nextRevision(kind: .tab, recordID: tab.id),
            deviceID: syncManager.deviceID,
            url: url.absoluteString,
            title: tab.model.title
        )
        syncManager.setPayload(payload)
        if let engine = syncManager.engine, let key = syncManager.syncKey,
           !(await uploadLatestPayloadToCloud(
               recordKey: syncManager.payloadKey(kind: .tab, recordID: tab.id),
               engine: engine,
               key: key
           )) {
            markSyncUploadFailure()
        }
    }

    func pushBookmarkToCloud(_ bookmark: Bookmark) async {
        let id = bookmark.id.uuidString
        let payload = SyncPayload(
            kind: .bookmark,
            recordID: id,
            revision: syncManager.nextRevision(kind: .bookmark, recordID: id),
            deviceID: syncManager.deviceID,
            url: bookmark.isFolder ? nil : bookmark.url.absoluteString,
            title: bookmark.title,
            parentID: bookmark.parentID?.uuidString,
            isFolder: bookmark.isFolder
        )
        syncManager.setPayload(payload)
        if let engine = syncManager.engine, let key = syncManager.syncKey,
           !(await uploadLatestPayloadToCloud(
               recordKey: syncManager.payloadKey(kind: .bookmark, recordID: id),
               engine: engine,
               key: key
           )) {
            markSyncUploadFailure()
        }
    }

    func pushHistoryToCloud(_ item: HistoryItem) async {
        let id = item.id.uuidString
        let payload = SyncPayload(
            kind: .history,
            recordID: id,
            revision: syncManager.nextRevision(kind: .history, recordID: id),
            deviceID: syncManager.deviceID,
            url: item.url.absoluteString,
            title: item.title,
            visitedAt: item.visitedAt
        )
        syncManager.setPayload(payload)
        if let engine = syncManager.engine, let key = syncManager.syncKey,
           !(await uploadLatestPayloadToCloud(
               recordKey: syncManager.payloadKey(kind: .history, recordID: id),
               engine: engine,
               key: key
           )) {
            markSyncUploadFailure()
        }
    }

    // ── Pull (CloudKit → local, decrypted + resolved) ───────────────────

    /// Handles a CloudKit database-subscription notification. Notifications
    /// are hints, not a complete change log: fetch the authoritative encrypted
    /// envelopes, then retry the durable outbox in the same serialized actor
    /// turn. Startup pull remains the fallback when APNs coalesces or drops a
    /// silent notification.
    func handleRemoteSyncNotification() async {
        guard syncManager.engine != nil, syncManager.syncKey != nil else {
            syncManager.hasPendingRemoteNotification = true
            return
        }
        syncState = .syncing
        let succeeded = await pullFromCloud()
        guard succeeded else {
            syncManager.hasPendingRemoteNotification = true
            return
        }
        await flushPendingPayloads()
        syncManager.hasPendingRemoteNotification = false
    }

    @discardableResult
    func pullFromCloud() async -> Bool {
        guard let engine = syncManager.engine, let key = syncManager.syncKey else {
            return false
        }
        syncState = .syncing
        let tabsResult = await pullTabsFromCloud(engine, key: key)
        let bookmarksResult = await pullBookmarksFromCloud(engine, key: key)
        let historyResult = await pullHistoryFromCloud(engine, key: key)
        let succeeded = tabsResult.succeeded && bookmarksResult.succeeded && historyResult.succeeded
        let appliedRecordKeys = tabsResult.appliedRecordKeys
            .union(bookmarksResult.appliedRecordKeys)
            .union(historyResult.appliedRecordKeys)
        syncState = succeeded ? .available : .error("Sync pull incomplete")
        if succeeded {
            lastSyncDate = Date()
            let pendingBeforePull = syncManager.pendingConflictRecordKeys
            let resolvedAllConflicts = SyncOutboxPolicy.shouldClearConflictDiagnostic(
                conflictRecordKeys: pendingBeforePull,
                appliedRecordKeys: appliedRecordKeys,
                diagnostic: syncManager.syncDiagnostic
            )
            syncManager.pendingConflictRecordKeys.subtract(appliedRecordKeys)
            if resolvedAllConflicts {
                syncManager.syncDiagnostic = nil
                broadcastWebChromeState()
            }
        }
        return succeeded
    }

    private func pullTabsFromCloud(_ engine: CloudKitSyncEngine, key: SymmetricKey) async -> (succeeded: Bool, appliedRecordKeys: Set<String>) {
        guard let report = try? await engine.fetchEnvelopeReport(kind: .tab, key: key) else { return (false, []) }
        var appliedRecordKeys = Set<String>()
        if report.rejectedCount > 0 { syncManager.syncDiagnostic = "Rejected \(report.rejectedCount) tab sync envelope(s)"; broadcastWebChromeState() }
        let payloads = report.payloads
        let resolver = SyncConflictResolver()
        for remote in payloads {
            // Private tabs are ephemeral and Hive-owned chrome routes are
            // local UI. Neither may be overwritten by a remote durable tab.
            if tabs.first(where: { $0.id == remote.recordID })?.isPrivate == true {
                continue
            }
            if SyncOutboxPolicy.isInternalWebChromePayload(
                remote,
                knownInternalTabIDs: syncManager.internalTabIDs
            ) {
                continue
            }
            guard SyncOutboxPolicy.isLocallyApplicable(remote) else { continue }
            let local = syncManager.payload(for: remote.recordID, kind: remote.kind)
            let winner = local.map { resolver.resolve(local: $0, remote: remote) } ?? remote
            guard winner == remote else { continue }
            guard SyncOutboxPolicy.didApplyRemotePayload(remote: remote, local: local) else { continue }
            syncManager.setPayload(remote)
            appliedRecordKeys.insert(syncManager.payloadKey(kind: remote.kind, recordID: remote.recordID))
            if remote.isTombstone {
                syncRemoveTab(id: remote.recordID)
                continue
            }
            if let existing = tabs.first(where: { $0.id == remote.recordID }) {
                if let urlString = remote.url, let url = URL(string: urlString), existing.model.url != url {
                    existing.savedURL = url
                    // A winning remote edit must become visible immediately.
                    // This uses the same model boundary as a local navigation;
                    // hibernated tabs will be rehydrated by the normal wake
                    // path before they are presented.
                    existing.model.load(url)
                }
            } else {
                let tab = Tab(
                    id: remote.recordID,
                    url: URL(string: remote.url ?? ""),
                    workspaceID: currentWorkspaceID,
                    profileID: currentProfileID
                )
                markInternalTabIfNeeded(tab)
                syncAppendTab(tab)
            }
        }
        return (true, appliedRecordKeys)
    }

    private func pullBookmarksFromCloud(_ engine: CloudKitSyncEngine, key: SymmetricKey) async -> (succeeded: Bool, appliedRecordKeys: Set<String>) {
        guard let report = try? await engine.fetchEnvelopeReport(kind: .bookmark, key: key) else { return (false, []) }
        var appliedRecordKeys = Set<String>()
        if report.rejectedCount > 0 { syncManager.syncDiagnostic = "Rejected \(report.rejectedCount) bookmark sync envelope(s)"; broadcastWebChromeState() }
        let payloads = report.payloads
        let resolver = SyncConflictResolver()
        for remote in payloads {
            guard SyncOutboxPolicy.isLocallyApplicable(remote) else { continue }
            let local = syncManager.payload(for: remote.recordID, kind: remote.kind)
            let winner = local.map { resolver.resolve(local: $0, remote: remote) } ?? remote
            guard winner == remote else { continue }
            guard SyncOutboxPolicy.didApplyRemotePayload(remote: remote, local: local) else { continue }
            syncManager.setPayload(remote)
            appliedRecordKeys.insert(syncManager.payloadKey(kind: remote.kind, recordID: remote.recordID))
            guard let id = UUID(uuidString: remote.recordID) else { continue }
            if remote.isTombstone {
                // A remote folder delete must also sweep its subtree: legacy
                // peers may not tombstone descendants individually, and local
                // deletes always tombstone them — either way, children of a
                // deleted folder must never survive as orphans. Capture the
                // local shape BEFORE removing the record (the tombstone
                // itself carries no isFolder).
                let deletedFolderChildren = (bookmarks.first(where: { $0.id == id })?.isFolder == true)
                    ? BookmarkFolderPolicy.descendantIDs(of: id, in: folderNodes())
                    : Set<UUID>()
                syncRemoveBookmark(id: id)
                for orphan in deletedFolderChildren {
                    bookmarks.removeAll { $0.id == orphan }
                    syncManager.setPayload(syncManager.payload(for: orphan.uuidString, kind: .bookmark)?.tombstone()
                        ?? SyncPayload(kind: .bookmark, recordID: orphan.uuidString,
                                       revision: syncManager.nextRevision(kind: .bookmark, recordID: orphan.uuidString),
                                       deviceID: syncManager.deviceID, deleted: true))
                }
                continue
            }
            if remote.isFolder {
                // A folder record: no url, carries title + placement.
                syncReplaceBookmark(Bookmark(
                    id: id,
                    title: remote.title ?? "Untitled Folder",
                    urlString: "",
                    isFolder: true,
                    parentID: remote.parentID.flatMap(UUID.init)
                ))
            } else if let urlString = remote.url, let url = URL(string: urlString) {
                syncReplaceBookmark(Bookmark(
                    id: id,
                    title: remote.title ?? "",
                    urlString: url.absoluteString,
                    parentID: remote.parentID.flatMap(UUID.init)
                ))
            }
        }
        return (true, appliedRecordKeys)
    }

    private func pullHistoryFromCloud(_ engine: CloudKitSyncEngine, key: SymmetricKey) async -> (succeeded: Bool, appliedRecordKeys: Set<String>) {
        guard let report = try? await engine.fetchEnvelopeReport(kind: .history, key: key) else { return (false, []) }
        var appliedRecordKeys = Set<String>()
        if report.rejectedCount > 0 { syncManager.syncDiagnostic = "Rejected \(report.rejectedCount) history sync envelope(s)"; broadcastWebChromeState() }
        let payloads = report.payloads
        let resolver = SyncConflictResolver()
        for remote in payloads {
            guard SyncOutboxPolicy.isLocallyApplicable(remote) else { continue }
            let local = syncManager.payload(for: remote.recordID, kind: remote.kind)
            let winner = local.map { resolver.resolve(local: $0, remote: remote) } ?? remote
            guard winner == remote else { continue }
            guard SyncOutboxPolicy.didApplyRemotePayload(remote: remote, local: local) else { continue }
            syncManager.setPayload(remote)
            appliedRecordKeys.insert(syncManager.payloadKey(kind: remote.kind, recordID: remote.recordID))
            guard let id = UUID(uuidString: remote.recordID) else { continue }
            if remote.isTombstone {
                syncRemoveHistoryItem(id: id)
            } else if let urlString = remote.url, let url = URL(string: urlString) {
                syncReplaceHistoryItem(HistoryItem(
                    id: id,
                    title: remote.title ?? "",
                    url: url,
                    visitedAt: remote.visitedAt ?? Date()
                ))
            }
        }
        return (true, appliedRecordKeys)
    }
}
