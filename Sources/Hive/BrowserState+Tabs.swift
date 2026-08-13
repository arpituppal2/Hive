//
//  BrowserState+Tabs.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Tab management
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Tabs

@MainActor
extension BrowserState {


    // MARK: - Tab management

    func duplicateTab(id: String) {
        guard let source = tabs.first(where: { $0.id == id }) else { return }
        let profile = source.isPrivate ? CefProfile.incognito() : cefProfile(for: source.workspaceID)
        let effectiveURL = source.model.url ?? source.savedURL
        // Duplicating a cold tab should produce a live copy, just like the
        // browser's normal duplicate-tab gesture. Use the durable wake URL so
        // hibernated internal routes retain their destination and provenance.
        let tab = Tab(
            url: effectiveURL,
            workspaceID: source.workspaceID,
            profileID: source.profileID,
            groupID: source.groupID,
            isPinned: source.isPinned,
            isEssential: source.isEssential,
            isPrivate: source.isPrivate,
            profile: profile,
            customTitle: source.customTitle
        )
        markInternalTabIfNeeded(tab)
        tabs.append(tab)
        activeTabID = tab.id
        wireTabHooks(tab)
        scheduleAutosave()
    }


    func closeOtherTabs(id: String) {
        let removedIDs = tabs.filter { $0.id != id && !$0.isPinned && !$0.isEssential && !$0.isPrivate }.map(\.id)
        tabs.removeAll { $0.id != id && !$0.isPinned && !$0.isEssential && !$0.isPrivate }
        removedIDs.forEach {
            navigationAttempts.invalidate(tabID: $0)
            tabObservationTasks["navigation-\($0)"]?.cancel()
            invalidatePreview(for: $0)
            dropPendingPermissionPrompts(forTabID: $0)
            enqueueSyncTombstone(kind: .tab, recordID: $0)
        }
        if let notice = navigationHealthNotice, removedIDs.contains(notice.tabID) {
            navigationHealthNotice = nil
        }
        activeTabID = id
        scheduleAutosave()
    }


    func closeTabsToRight(id: String) {
        guard let pivot = tabs.firstIndex(where: { $0.id == id }) else { return }
        let toClose = tabs.suffix(from: pivot + 1).filter { !$0.isPinned && !$0.isEssential && !$0.isPrivate }
        let removedIDs = toClose.map(\.id)
        tabs.removeAll { tab in
            !tab.isPrivate && toClose.contains(where: { $0.id == tab.id })
        }
        removedIDs.forEach {
            navigationAttempts.invalidate(tabID: $0)
            tabObservationTasks["navigation-\($0)"]?.cancel()
            invalidatePreview(for: $0)
            dropPendingPermissionPrompts(forTabID: $0)
            enqueueSyncTombstone(kind: .tab, recordID: $0)
        }
        if let notice = navigationHealthNotice, removedIDs.contains(notice.tabID) {
            navigationHealthNotice = nil
        }
        scheduleAutosave()
    }


    @discardableResult
    /// Initializes AI components (swarm orchestrator, model council, context
    /// coordinator). Called from BrowserWindow.onAppear after the shell renders.
    /// Idempotent — subsequent calls are no-ops.
    func setupAI() {
        guard swarmOrchestrator == nil else { return }
        // Load the Swarm Cell system prompts from the resource bundle. When
        // present this wires the retrieval-ranker and librarian steps (both
        // no-op when `prompts` is nil); when absent the orchestrator degrades
        // gracefully to bare role-based generation.
        let promptLoader = Bundle.module.resourceURL.map { CellPromptLoader(promptsDir: $0) }
        swarmOrchestrator = SwarmOrchestrator(
            dispatcher: .shared, hotMemory: hotMemory, ledger: eventLedger,
            prompts: promptLoader
        )
        let tavilyKey = self.tavilyAPIKey
        let searchProvider: WebSearchProvider? = tavilyKey.isEmpty ? nil : TavilySearchProvider(apiKey: tavilyKey)
        let vaneURL = self.vaneBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let vaneProvider: WebSearchProvider? = vaneURL.isEmpty ? nil : VaneSearchProvider(baseURL: URL(string: vaneURL) ?? URL(string: "http://localhost:3000")!)
        modelCouncil = ModelCouncil(dispatcher: .shared, searchProvider: searchProvider, vaneProvider: vaneProvider)
        restoreCouncilVerdict()
        if let swarmOrchestrator {
            contextRequestCoordinator = ContextRequestCoordinator(
                hotMemory: hotMemory,
                orchestrator: swarmOrchestrator
            )
        }
    }


    func newTab(url: URL? = nil, groupID: UUID? = nil, activate: Bool = true, isPrivate: Bool = false) -> Tab {
        let workspaceID = currentWorkspaceID
        let profileID = currentWorkspace?.profileID ?? currentProfileID
        // Approved taste decision: new tabs open the Morning Brief by default;
        // the hand-drawn start page is one Settings toggle away. Private tabs
        // always land on the start page — the brief is derived from browsing
        // data and must never leak into a private window.
        let resolvedURL: URL
        if let url {
            // HTTPS-Only: upgrade plaintext destinations opened from the chrome
            // (links, omnibox-typed, floating-bar) just like active-tab loads.
            resolvedURL = HTTPSOnlyPolicy.upgraded(
                url,
                enabled: isHTTPSOnlyEnabled,
                exceptions: httpsOnlyExceptions
            ) ?? url
        } else if isPrivate {
            // The marker lets the start-page bridge request a redacted
            // snapshot even when a normal tab is active elsewhere.
            resolvedURL = URL(string: "\(Self.webChromeStartURL.absoluteString)?private=1")!
        } else if openBriefOnNewTab {
            resolvedURL = Self.webChromeBriefURL
        } else {
            resolvedURL = Self.webChromeStartURL
        }
        let profile = isPrivate ? CefProfile.incognito() : cefProfile(for: workspaceID)
        let tab = Tab(url: resolvedURL, workspaceID: workspaceID, profileID: profileID, groupID: groupID, isPrivate: isPrivate, profile: profile)
        markInternalTabIfNeeded(tab)
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.springQuick) {
            tabs.append(tab)
            if activate {
                activeTabID = tab.id
            }
        }
        wireTabHooks(tab)
        Task { @MainActor [weak self] in
            await self?.pushTabToCloud(tab)
        }
        scheduleAutosave()
        broadcastWebChromeState()
        return tab
    }


    func closeTab(id: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        if navigationHealthNotice?.tabID == id {
            navigationHealthNotice = nil
        }
        navigationAttempts.invalidate(tabID: id)
        tabObservationTasks["navigation-\(id)"]?.cancel()
        var removedTab: Tab!
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.springQuick) {
            removedTab = tabs.remove(at: index)
            if activeTabID == id {
                let newIndex = min(index, max(tabs.count - 1, 0))
                activeTabID = tabs[safe: newIndex]?.id
            }
        }

        if !removedTab.isPrivate {
            closedTabs.append(removedTab)
            enqueueSyncTombstone(kind: .tab, recordID: removedTab.id)
        } else {
            // A closed private tab can never be reopened — prune its mute so
            // no stale ID lingers in the session-scoped set (it never enters
            // the ⌘⇧T stack, so eviction pruning can't reach it).
            mutedTabIDs.remove(removedTab.id)
            siteMutedTabIDs.remove(removedTab.id)
        }
        if closedTabs.count > 10 {
            let dropped = closedTabs.removeFirst()
            // The dropped tab can never be reopened — prune its zoom and mute
            // so dead keys don't accumulate (zoom is session-file durable,
            // mute is session-scoped; neither should linger for a tab that
            // can never come back). Retained tabs keep both so ⌘⇧T restores
            // them (Chrome restores zoom and mute on reopen).
            tabZoomLevels[dropped.id] = nil
            mutedTabIDs.remove(dropped.id)
            siteMutedTabIDs.remove(dropped.id)
        }
        mruTabIDs.removeAll { $0 == id }
        // The tab's back/forward menus can never be shown again — drop its
        // navigation-entry stacks so closed tabs don't accumulate entries.
        tabNavBack[id] = nil
        tabNavForward[id] = nil
        // Drop the closed tab's pooled preview renderer (its browser is dead).
        invalidatePreview(for: id)
        // Release any permission prompt the page left unanswered, and drop
        // any autofill chip pointing at the closed tab.
        dropPendingPermissionPrompts(forTabID: id)
        dropAutofillSuggestion(forTabID: id)
        dropPasswordCaptureOffer(forTabID: id)
        // Clean up media tracking and the mini-player for the closed tab.
        mediaPlayingTabIDs.remove(id)
        mediaVideoPlayingTabIDs.remove(id)
        if miniPlayerTabID == id { miniPlayerTabID = nil }

        if tabs.isEmpty {
            newTab()
        }
        scheduleAutosave()
        broadcastWebChromeState()
    }


    func closeActiveTab() {
        guard let id = activeTabID else { return }
        closeTab(id: id)
    }


    func reopenLastClosed() {
        guard let tab = closedTabs.popLast() else { return }
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.springQuick) {
            tabs.append(tab)
            activeTabID = tab.id
        }
        scheduleAutosave()
    }


    func selectTab(id: String) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        // Wake hibernated tabs before selecting
        if tab.isHibernated {
            wakeTab(tab)
        }
        // Selecting a member of a collapsed group expands it first. This keeps
        // the tab list truthful: the selected tab is never hidden inside a
        // collapsed section.
        if let groupID = tab.groupID,
           let groupIndex = tabGroups.firstIndex(where: { $0.id == groupID }),
           tabGroups[groupIndex].isCollapsed {
            tabGroups[groupIndex].isCollapsed = false
            scheduleAutosave()
        }
        // Selecting a tab ends any active peek (the pill hover is gone).
        endPeek()
        // Arc-style auto mini-player: switching away from a tab whose page is
        // playing audio/video floats the player so playback stays one click
        // away. Switching BACK hides it (isMiniPlayerVisible is false for the
        // active tab).
        updateMiniPlayerAfterSwitch(from: activeTabID, to: id)
        activeTabID = id
        // Reader word count belongs to the previous page: the new tab either
        // has its own (reported on its own injection) or none, and a stale
        // count must never linger in the Reader bar.
        readerWordCount = nil
        // Re-apply the tab's persisted zoom and mute (the browser may be
        // freshly attached after a hibernate wake). A durable site mute also
        // re-applies here so a muted host stays muted across hibernation.
        applyStoredZoom(for: tab)
        applyStoredMute(for: tab)
        applySiteMuteIfNeeded(for: tab)
        // HTTPS-Only: the warning banner follows the active tab's current page
        // across switches. A hibernated tab's blank model clears the banner
        // (no page is being viewed).
        updateHTTPSOnlyNotice(for: tab.model.url ?? tab.savedURL, tabID: tab.id)
        // Keep hot memory's current page honest when switching tabs — the AI
        // must reference what the user is actually viewing, not the last
        // navigated page. Also bump the page node's hot score so revisiting
        // a tab counts as an access (parity with navigate-time warm-up).
        if !isPrivateBrowsing {
            Task { @MainActor [weak self] in
                guard let self, let ctx = self.buildPageContext() else { return }
                if let urlStr = ctx.url?.absoluteString, urlStr != "about:blank" {
                    let nodeID = pageNodeID(for: urlStr)
                    await self.hotMemory.setCurrentPage(ctx, nodeID: nodeID)
                    await self.hotMemory.didAccessNode(id: nodeID, sourceHint: "browsed",
                                                       label: ctx.title,
                                                       workspaceID: self.currentWorkspaceID.uuidString,
                                                       profileID: self.currentProfileID.uuidString)
                } else {
                    await self.hotMemory.setCurrentPage(ctx)
                }
            }
        }
        // Wire CDP if the tab's browser is already attached (common when
        // switching back to a tab whose browser stayed alive in the MRU
        // cache). If the browser isn't attached yet, onBrowserAttached
        // (set in wireTabHooks) will wire it when it becomes ready.
        if let browser = tab.model.browser {
            wireCDP(to: browser)
        }
        // A chip for any tab other than the newly active one must never
        // follow the user — its form is no longer the visible page (the
        // render gate also blocks it, but dropping keeps the state honest).
        if pendingAutofillSuggestion?.tabID != id {
            pendingAutofillSuggestion = nil
        }
        // Same rule for a pending password offer: it belongs to the tab we
        // just left, so it must not follow the user to the new tab.
        if pendingPasswordCaptureOffer?.tabID != id {
            pendingPasswordCaptureOffer = nil
        }
        broadcastWebChromeState()
    }


    /// Reorder: moves the tab with `id` to `newIndex` in the tabs array.
    /// Legacy callers use this for broad strip drops; new vertical-row drops
    /// should use `reorderTab(movingID:targetID:edge:)` so filtered workspace
    /// projections cannot leak a global array index into the mutation.
    func moveTab(id: String, to newIndex: Int) {
        guard let currentIndex = tabs.firstIndex(where: { $0.id == id }),
              tabs.indices.contains(newIndex) else { return }
        let tab = tabs.remove(at: currentIndex)
        let insertionIndex = newIndex > currentIndex ? newIndex - 1 : newIndex
        tabs.insert(tab, at: max(0, insertionIndex))
        scheduleAutosave()
    }


    /// Reorders one visible tab relative to another using stable IDs and an
    /// explicit before/after edge. The vertical chrome renders a filtered
    /// projection (workspace + group + pinned boundary), so this method builds
    /// that same projection before mutating the backing array. Invalid moves
    /// fail closed: no cross-workspace move, implicit group change, or pinned
    /// boundary crossing can happen through a reorder gesture.
    @discardableResult
    func reorderTab(
        movingID: String,
        targetID: String,
        edge: TabInsertionPlanner.Edge
    ) -> Bool {
        guard let moving = tabs.first(where: { $0.id == movingID }),
              tabs.contains(where: { $0.id == targetID }) else { return false }

        let projection = tabs.filter {
            $0.workspaceID == currentWorkspaceID &&
            $0.isPinned == moving.isPinned &&
            $0.isEssential == moving.isEssential &&
            $0.groupID == moving.groupID
        }
        let items = projection.map {
            TabInsertionPlanner.Item(
                id: $0.id,
                workspaceID: $0.workspaceID,
                groupID: $0.groupID,
                isPinned: $0.isPinned,
                isEssential: $0.isEssential
            )
        }
        guard let reorderedIDs = TabInsertionPlanner.reordered(
            items: items,
            movingID: movingID,
            target: .init(tabID: targetID, edge: edge),
            activeWorkspaceID: currentWorkspaceID
        ) else { return false }

        let reorderedTabsByID = Dictionary(uniqueKeysWithValues: projection.map { ($0.id, $0) })
        var nextProjectionIndex = 0
        tabs = tabs.map { tab in
            guard tab.workspaceID == currentWorkspaceID,
                  tab.isPinned == moving.isPinned,
                  tab.isEssential == moving.isEssential,
                  tab.groupID == moving.groupID else { return tab }
            defer { nextProjectionIndex += 1 }
            return reorderedTabsByID[reorderedIDs[nextProjectionIndex]] ?? tab
        }
        scheduleAutosave()
        return true
    }
}
