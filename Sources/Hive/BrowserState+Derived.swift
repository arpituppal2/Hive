//
//  BrowserState+Derived.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Derived
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Derived

@MainActor
extension BrowserState {


    // MARK: - Derived

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabID }
    }


    var pinnedTabs: [Tab] { tabs.filter { $0.isPinned && !$0.isEssential && $0.workspaceID == currentWorkspaceID } }

    var essentialTabs: [Tab] { tabs.filter { $0.isEssential && $0.workspaceID == currentWorkspaceID } }

    var iconTabs: [Tab] { tabs.filter { ($0.isPinned || $0.isEssential) && $0.workspaceID == currentWorkspaceID } }

    var unpinnedTabs: [Tab] { tabs.filter { !$0.isPinned && !$0.isEssential && $0.workspaceID == currentWorkspaceID } }


    /// All visible tabs in display order: pinned/essential first, then unpinned.
    /// Used for Cmd+1-9 keyboard shortcuts to match Chrome's left-to-right indexing.
    var visibleTabs: [Tab] { iconTabs + unpinnedTabs }


    /// The tab projection eligible for explicit keyboard/accessibility
    /// traversal. Group collapse is a visibility decision, so collapsed
    /// members are excluded before the pure HiveCore navigator sees them.
    var focusableVisibleTabs: [Tab] {
        let collapsedIDs = collapsedGroupTabIDs
        return visibleTabs.filter { !collapsedIDs.contains($0.id) }
    }


    /// Selects the adjacent tab in the current visible projection. The pure
    /// navigator computes only a stable-ID destination; selection remains the
    /// single lifecycle authority so hibernation wake, group expansion,
    /// renderer activation, memory context, and autosave stay centralized.
    func selectAdjacentVisibleTab(from focusedID: String? = nil, direction: TabFocusDirection) {
        let ids = focusableVisibleTabs.map(\.id)
        guard let destination = TabFocusNavigator.destination(
            in: ids,
            focusedID: focusedID ?? activeTabID,
            direction: direction
        ) else { return }
        selectTab(id: destination)
    }


    var activeModel: CefWebViewModel? { activeTab?.model }


    var isCurrentPageBookmarked: Bool {
        guard let urlString = activeModel?.url?.absoluteString, !urlString.isEmpty, urlString != "about:blank" else { return false }
        if urlString == BrowserState.webChromeStartURL.absoluteString { return false }
        return bookmarks.contains(where: { $0.urlString == urlString })
    }


    var canGoBack: Bool { activeModel?.canGoBack ?? false }

    var canGoForward: Bool { activeModel?.canGoForward ?? false }

    var isLoading: Bool { activeModel?.isLoading ?? false }

    var loadingProgress: Double { activeModel?.estimatedProgress ?? 0 }


    /// True when the active tab has no real URL (nil or about:blank).
    /// Used to show the native new-tab page overlay instead of a blank Chromium surface.
    var isNewTab: Bool {
        guard let url = activeModel?.url?.absoluteString else { return true }
        return url.isEmpty || url == "about:blank"
    }


    /// True when the active renderer is a hosted HTTP(S) page. Standard page
    /// commands remain available in private tabs; privacy is enforced by the
    /// context and persistence boundaries rather than by hiding browser tools.
    var canUseWebPageActions: Bool {
        BrowserPageActionPolicy.canUseWebPageActions(for: activeModel?.url)
    }
}
