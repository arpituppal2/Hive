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
        let tab = Tab(url: source.model.url, workspaceID: source.workspaceID, profileID: source.profileID, groupID: source.groupID, isPinned: source.isPinned, isEssential: source.isEssential, isPrivate: source.isPrivate, profile: profile)
        tabs.append(tab)
        activeTabID = tab.id
        wireTabHooks(tab)
        scheduleAutosave()
    }


    func closeOtherTabs(id: String) {
        let removedIDs = tabs.filter { $0.id != id && !$0.isPinned && !$0.isEssential }.map(\.id)
        tabs.removeAll { $0.id != id && !$0.isPinned && !$0.isEssential }
        removedIDs.forEach {
            navigationAttempts.invalidate(tabID: $0)
            tabObservationTasks["navigation-\($0)"]?.cancel()
            invalidatePreview(for: $0)
        }
        if let notice = navigationHealthNotice, removedIDs.contains(notice.tabID) {
            navigationHealthNotice = nil
        }
        activeTabID = id
        scheduleAutosave()
    }


    func closeTabsToRight(id: String) {
        guard let pivot = tabs.firstIndex(where: { $0.id == id }) else { return }
        let toClose = tabs.suffix(from: pivot + 1).filter { !$0.isPinned && !$0.isEssential }
        let removedIDs = toClose.map(\.id)
        tabs.removeAll { tab in toClose.contains(where: { $0.id == tab.id }) }
        removedIDs.forEach {
            navigationAttempts.invalidate(tabID: $0)
            tabObservationTasks["navigation-\($0)"]?.cancel()
            invalidatePreview(for: $0)
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
        swarmOrchestrator = SwarmOrchestrator(
            dispatcher: .shared, hotMemory: hotMemory, ledger: eventLedger,
            honeycomb: honeycomb
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
            resolvedURL = url
        } else if isPrivate {
            resolvedURL = Self.webChromeStartURL
        } else if openBriefOnNewTab {
            resolvedURL = Self.webChromeBriefURL
        } else {
            resolvedURL = Self.webChromeStartURL
        }
        let profile = isPrivate ? CefProfile.incognito() : cefProfile(for: workspaceID)
        let tab = Tab(url: resolvedURL, workspaceID: workspaceID, profileID: profileID, groupID: groupID, isPrivate: isPrivate, profile: profile)
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.springQuick) {
            tabs.append(tab)
            if activate {
                activeTabID = tab.id
            }
        }
        wireTabHooks(tab)
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
        }
        if closedTabs.count > 10 {
            let dropped = closedTabs.removeFirst()
            // The dropped tab can never be reopened — prune its zoom so dead
            // keys don't accumulate in the session file. Retained tabs keep
            // their zoom so ⌘⇧T restores it (Chrome restores zoom on reopen).
            tabZoomLevels[dropped.id] = nil
        }
        mruTabIDs.removeAll { $0 == id }
        // Drop the closed tab's pooled preview renderer (its browser is dead).
        invalidatePreview(for: id)
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
        // Re-apply the tab's persisted zoom (the browser may be freshly
        // attached after a hibernate wake).
        applyStoredZoom(for: tab)
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
