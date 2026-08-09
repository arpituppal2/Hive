import CloudKit
import Foundation
import HiveCore

// MARK: - SyncManager (CloudKit lifecycle wrapper)
//
// Holds the CloudKitSyncEngine and sync bookkeeping. Owned by BrowserState
// through an associated-object pattern so the extension adds no stored
// properties to the @Observable class. The engine is nil when CloudKit is
// unavailable.

@MainActor
final class SyncManager: Sendable {
    var engine: CloudKitSyncEngine?
    var hasCompletedInitialSync: Bool = false

    var isAvailable: Bool { engine != nil }

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

    // ── Setup ───────────────────────────────────────────────────────────

    func setupSync() {
        guard syncManager.engine == nil else { return }
        let engine = CloudKitSyncEngine()
        syncManager.engine = engine
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let status = try await engine.accountStatus()
                guard status == .available else {
                    self.syncManager.engine = nil
                    return
                }
                try await engine.setupSubscription()
                await self.pullFromCloud()
                self.syncManager.hasCompletedInitialSync = true
            } catch {
                print("[Sync] setup failed: \(error.localizedDescription)")
                self.syncManager.engine = nil
            }
        }
    }

    // ── Push (local → CloudKit) ─────────────────────────────────────────

    func pushTabsToCloud() async {
        guard let engine = syncManager.engine else { return }
        for tab in tabs where !tab.isPrivate {
            let url = tab.model.url?.absoluteString ?? ""
            let title = tab.model.title
            try? await engine.saveTab(id: tab.id, url: url, title: title)
        }
    }

    func pushBookmarkToCloud(_ bookmark: Bookmark) async {
        guard let engine = syncManager.engine else { return }
        try? await engine.saveBookmark(
            id: bookmark.id.uuidString,
            url: bookmark.url.absoluteString,
            title: bookmark.title
        )
    }

    func pushHistoryToCloud(_ item: HistoryItem) async {
        guard let engine = syncManager.engine else { return }
        try? await engine.saveHistoryItem(
            id: item.id.uuidString,
            url: item.url.absoluteString,
            title: item.title,
            visitedAt: item.visitedAt
        )
    }

    // ── Pull (CloudKit → local) ─────────────────────────────────────────

    func pullFromCloud() async {
        guard let engine = syncManager.engine else { return }
        await pullTabsFromCloud(engine)
        await pullBookmarksFromCloud(engine)
        await pullHistoryFromCloud(engine)
    }

    private func pullTabsFromCloud(_ engine: CloudKitSyncEngine) async {
        guard let records = try? await engine.fetchTabs() else { return }
        let existingIDs = Set(tabs.map(\.id))
        for record in records {
            let tabID = record.recordID.recordName
            guard !existingIDs.contains(tabID) else { continue }
            let urlStr = record["url"] as? String ?? ""
            let url = URL(string: urlStr)
            let tab = Tab(
                id: tabID,
                url: url,
                workspaceID: currentWorkspaceID,
                profileID: currentProfileID
            )
            syncAppendTab(tab)
        }
    }

    private func pullBookmarksFromCloud(_ engine: CloudKitSyncEngine) async {
        guard let records = try? await engine.fetchBookmarks() else { return }
        let existingURLs = Set(bookmarks.map { $0.url.absoluteString.lowercased() })
        for record in records {
            guard let urlStr = record["url"] as? String,
                  let url = URL(string: urlStr),
                  !existingURLs.contains(urlStr.lowercased()) else { continue }
            let bookmark = Bookmark(
                id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
                title: record["title"] as? String ?? "",
                url: url
            )
            syncAppendBookmark(bookmark)
        }
    }

    private func pullHistoryFromCloud(_ engine: CloudKitSyncEngine) async {
        guard let records = try? await engine.fetchHistory() else { return }
        let existingURLs = Set(historyItems.map { $0.url.absoluteString.lowercased() })
        for record in records {
            guard let urlStr = record["url"] as? String,
                  let url = URL(string: urlStr),
                  !existingURLs.contains(urlStr.lowercased()) else { continue }
            let item = HistoryItem(
                id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
                title: record["title"] as? String ?? "",
                url: url,
                visitedAt: record["visitedAt"] as? Date ?? Date()
            )
            syncAppendHistoryItem(item)
        }
    }
}
