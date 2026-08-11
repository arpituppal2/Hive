//
//  BrowserState+Core.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - TabGroup | Sync helpers (internal mutation for CloudKit extension)
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Core

@MainActor
extension BrowserState {


    /// When the user has Reduce Motion enabled in macOS Accessibility settings,
    /// state mutations skip animation so the UI snaps instantly. Views use
    /// `@Environment(\.accessibilityReduceMotion)`, but the @Observable class
    /// can't access SwiftUI's environment — it reads the system setting directly.
    /// Callers still gate with `withAnimation(isReduceMotionEnabled ? nil : ...)`.
    var isReduceMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }


    /// Whether `url` belongs to the persistent web chrome shell.
    static func isWebChromeURL(_ url: URL?) -> Bool {
        url?.scheme?.lowercased() == "hive" &&
            url?.host?.lowercased() == "start" &&
            url?.query == "chrome=1"
    }

    /// Whether `url` is a Hive-owned internal web-chrome surface. These routes
    /// render browser UI, not user content: they must never enter history,
    /// bookmarks, page context, or cloud-sync projections as ordinary pages.
    static func isInternalWebChromeURL(_ url: URL?) -> Bool {
        guard url?.scheme?.lowercased() == "hive" else { return false }
        switch url?.host?.lowercased() {
        case "start", "brief", "polar": return true
        default: return false
        }
    }

    /// Whether `url` is a per-tab Hive start page. Private start pages carry
    /// an explicit marker so their initial bridge request can receive a
    /// redacted snapshot without relying on whichever tab is active globally.
    static func isWebChromeStartURL(_ url: URL?) -> Bool {
        guard url?.scheme?.lowercased() == "hive",
              url?.host?.lowercased() == "start"
        else { return false }
        return url?.query == nil || url?.query == "private=1"
    }


    // MARK: Sync helpers (internal mutation for CloudKit extension)
    func syncAppendTab(_ tab: Tab) { tabs.append(tab) }

    func syncRemoveTab(id: String) {
        tabs.removeAll { $0.id == id }
        dropPendingPermissionPrompts(forTabID: id)
        if activeTabID == id { activeTabID = tabs.first?.id }
        // Preserve the browser invariant that a window always has a durable
        // normal tab, even when a remote tombstone removes the last one. A
        // private tab may remain open, but it cannot satisfy this invariant.
        if !tabs.contains(where: { !$0.isPrivate }) { newTab() }
    }

    func syncAppendBookmark(_ bookmark: Bookmark) { bookmarks.append(bookmark) }

    func syncReplaceBookmark(_ bookmark: Bookmark) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index] = bookmark
        } else {
            bookmarks.append(bookmark)
        }
    }

    func syncRemoveBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
    }

    func syncAppendHistoryItem(_ item: HistoryItem) { historyItems.append(item) }

    func syncReplaceHistoryItem(_ item: HistoryItem) {
        if let index = historyItems.firstIndex(where: { $0.id == item.id }) {
            historyItems[index] = item
        } else {
            historyItems.append(item)
        }
    }

    func syncRemoveHistoryItem(id: UUID) {
        historyItems.removeAll { $0.id == id }
    }
}
