//
//  BrowserState+Archive.swift
//  Hive
//
//  §7 Auto-Archive: cold tabs (14-day default, per AutoArchivePolicy) are
//  moved off the live tab strip into a durable "Recently Archived" shelf
//  (ArchivedTab records, capped by TabArchiveShelfPolicy). Restoring a record
//  reopens the tab and removes it from the shelf; the pass is gated by
//  Settings → Performance → Auto Archive. The shelf is local-only — like
//  boosts, reading list, pinned apps, and passwords it stays outside the
//  encrypted-sync boundary — but each archived tab is tombstoned as a tab so
//  peers converge on its removal from the live set.
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit

// MARK: - BrowserState + Archive

@MainActor
extension BrowserState {

    // ── Pass ────────────────────────────────────────────────────────────

    /// Runs one auto-archive pass: evaluates the live tab set against
    /// ``AutoArchivePolicy`` and moves every cold candidate onto the shelf.
    /// Idempotent and safe to call repeatedly (the policy only ever flags
    /// still-live, still-cold tabs).
    @discardableResult
    func runAutoArchivePass(threshold: TimeInterval = AutoArchivePolicy.defaultThreshold) -> Int {
        let inputs = tabs.map { tab in
            AutoArchivePolicy.TabInput(
                id: tab.id,
                url: archiveURL(for: tab),
                lastVisitedAt: tab.lastAccessed,
                isPinned: tab.isPinned,
                isEssential: tab.isEssential,
                isPrivate: tab.isPrivate
            )
        }
        let candidates = AutoArchivePolicy.evaluate(
            tabs: inputs,
            activeTabID: activeTabID,
            collapsedGroupTabIDs: collapsedGroupTabIDs,
            now: Date(),
            threshold: threshold
        )
        guard !candidates.isEmpty else { return 0 }
        var archivedCount = 0
        // Newest-archived first on the shelf; older records fall off the cap.
        var shelf = archivedTabs
        // Snapshot the targets first — removeTabForArchive mutates `tabs`, so
        // iterating the live array while removing from it would be fragile.
        let targets = tabs.filter { candidates.contains($0.id) }
        for tab in targets {
            guard let record = archiveRecord(for: tab) else { continue }
            shelf.insert(record, at: 0)
            removeTabForArchive(id: tab.id)
            archivedCount += 1
        }
        archivedTabs = TabArchiveShelfPolicy.applyCap(shelf)
        if archivedCount > 0 {
            scheduleAutosave()
            broadcastWebChromeState()
        }
        return archivedCount
    }

    /// The URL worth restoring from the shelf. Internal chrome routes
    /// (hive://, about:) and blank tabs are never archived — a nil here makes
    /// the policy skip them before any record is created.
    private func archiveURL(for tab: Tab) -> URL? {
        guard let url = tab.model.url ?? tab.savedURL,
              !Self.isInternalWebChromeURL(url),
              url.absoluteString != "about:blank",
              url.absoluteString != "about:newtab"
        else { return nil }
        return url
    }

    private func archiveRecord(for tab: Tab) -> ArchivedTab? {
        guard let url = archiveURL(for: tab) else { return nil }
        let title = tab.model.title.isEmpty
            ? (url.host ?? "Archived tab")
            : tab.model.title
        return ArchivedTab(
            id: tab.id,
            title: title,
            url: url,
            faviconURL: tab.model.faviconURL,
            sourceSpaceID: tab.workspaceID.uuidString,
            sourceGroupID: tab.groupID?.uuidString,
            archivedAt: Date(),
            lastVisitedAt: tab.lastAccessed,
            isPrivate: tab.isPrivate
        )
    }

    /// Removes an archived tab from the live set with the same cleanup
    /// `closeTab` performs — navigation attempts, observation tasks, pooled
    /// preview, permission prompts, autofill/password chips, media tracking,
    /// and a sync tombstone — WITHOUT pushing it onto the ⌘⇧T reopen stack
    /// (the archive shelf is its restore path) and WITHOUT closing the window
    /// when it was the last tab (archiving leaves the browser usable).
    private func removeTabForArchive(id: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        if navigationHealthNotice?.tabID == id { navigationHealthNotice = nil }
        navigationAttempts.invalidate(tabID: id)
        tabObservationTasks["navigation-\(id)"]?.cancel()
        let removed = tabs.remove(at: index)
        if activeTabID == id {
            let newIndex = min(index, max(tabs.count - 1, 0))
            activeTabID = tabs[safe: newIndex]?.id
        }
        if !removed.isPrivate {
            // Archive removes the tab from the live set like a close — but the
            // record itself stays local-only (never pushed as a sync payload).
            enqueueSyncTombstone(kind: .tab, recordID: removed.id)
        }
        mutedTabIDs.remove(removed.id)
        tabZoomLevels[removed.id] = nil
        mruTabIDs.removeAll { $0 == id }
        invalidatePreview(for: id)
        dropPendingPermissionPrompts(forTabID: id)
        dropAutofillSuggestion(forTabID: id)
        dropPasswordCaptureOffer(forTabID: id)
        mediaPlayingTabIDs.remove(id)
        mediaVideoPlayingTabIDs.remove(id)
        if miniPlayerTabID == id { miniPlayerTabID = nil }

        // The active tab is always policy-exempt, so archiving normally leaves
        // at least one tab. Defend the same "browser always has a tab"
        // invariant closeTab enforces for the activeTabID == nil edge.
        if tabs.isEmpty { newTab() }
    }

    // ── Shelf actions ───────────────────────────────────────────────────

    /// Reopens an archived tab in its original workspace (falling back to the
    /// current one), removes the record from the shelf, and activates the tab.
    func restoreArchivedTab(id: String) {
        guard let index = archivedTabs.firstIndex(where: { $0.id == id }),
              let record = archivedTabs[safe: index],
              let url = record.url else { return }
        archivedTabs.remove(at: index)
        let workspaceID = record.sourceSpaceID.flatMap(UUID.init) ?? currentWorkspaceID
        let profileID = workspaces.first(where: { $0.id == workspaceID })?.profileID ?? currentProfileID
        let tab = Tab(
            id: record.id,
            url: url,
            workspaceID: workspaceID,
            profileID: profileID,
            groupID: record.sourceGroupID.flatMap(UUID.init)
        )
        markInternalTabIfNeeded(tab)
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.springQuick) {
            tabs.append(tab)
            activeTabID = tab.id
        }
        wireTabHooks(tab)
        Task { @MainActor [weak self] in
            await self?.pushTabToCloud(tab)
        }
        if isArchivePanelOpen { isArchivePanelOpen = false }
        scheduleAutosave()
        broadcastWebChromeState()
    }

    /// Permanently deletes an archived-tab record (no restore).
    func removeArchivedTab(id: String) {
        archivedTabs.removeAll { $0.id == id }
    }

    // ── Timer ───────────────────────────────────────────────────────────

    /// Periodic auto-archive pass, gated by `enableAutoArchive`. Runs on a
    /// generous cadence (every 10 minutes) — unlike hibernation (60s), the
    /// 14-day threshold means a per-minute pass would be pure churn.
    func startArchiveTimer() {
        archiveTask?.cancel()
        archiveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                // A short first delay lets session restore settle before the
                // first evaluation (restored tabs carry their saved
                // lastAccessed); thereafter the pass runs every 10 minutes.
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                if self.enableAutoArchive {
                    _ = self.runAutoArchivePass()
                }
                try? await Task.sleep(for: .seconds(600))
            }
        }
    }
}
