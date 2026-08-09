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
        url?.host == "start" && url?.query == "chrome=1"
    }


    // MARK: Sync helpers (internal mutation for CloudKit extension)
    func syncAppendTab(_ tab: Tab) { tabs.append(tab) }

    func syncAppendBookmark(_ bookmark: Bookmark) { bookmarks.append(bookmark) }

    func syncAppendHistoryItem(_ item: HistoryItem) { historyItems.append(item) }
}
