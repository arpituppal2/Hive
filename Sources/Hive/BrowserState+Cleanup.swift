//
//  BrowserState+Cleanup.swift
//  Hive
//
//  Clean Tabs (Arc/Boost parity): one-click review of duplicate and stale
//  tabs. The pure planning contract lives in HiveCore (TabCleanupPlanner);
//  this extension only maps the live tab snapshot onto it and routes the
//  user's selection through the normal closeTab path (sync tombstones, MRU
//  cleanup, preview invalidation, autosave, and the closed-tabs stack for
//  ⌘⇧T reopen).
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Cleanup

@MainActor
extension BrowserState {

    func openCleanTabs() {
        isCleanTabsPanelOpen = true
    }


    func closeCleanTabs() {
        isCleanTabsPanelOpen = false
    }


    /// The current tab-cleanup plan, computed from the live tab snapshot.
    /// Duplicate groups keep the most-recently-accessed member and never
    /// suggest closing pinned/essential tabs; stale tabs are untouched for
    /// 30+ days. Pure — safe to call on every sheet appearance.
    func currentCleanupPlan() -> TabCleanupPlanner.Plan {
        let inputs = tabs.map { tab in
            TabCleanupPlanner.TabInput(
                id: tab.id,
                url: tab.model.url ?? tab.savedURL,
                title: tab.model.title ?? tab.model.url?.host ?? "Untitled",
                lastAccessed: tab.lastAccessed,
                isPinned: tab.isPinned,
                isEssential: tab.isEssential,
                isPrivate: tab.isPrivate,
                isHibernated: tab.isHibernated
            )
        }
        return TabCleanupPlanner.plan(tabs: inputs)
    }


    /// Closes a set of tabs through the normal per-tab close path. Each call
    /// re-locates the tab by id, so a batch that partially overlaps a
    /// mid-loop change is still safe. The last tab close falls back to a
    /// fresh tab (the same invariant closeTab enforces).
    func closeTabs(withIDs ids: Set<String>) {
        let ordered = tabs.filter { ids.contains($0.id) }.map(\.id)
        for id in ordered {
            closeTab(id: id)
        }
        if isCleanTabsPanelOpen { isCleanTabsPanelOpen = false }
    }
}
