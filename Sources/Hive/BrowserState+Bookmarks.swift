//
//  BrowserState+Bookmarks.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Bookmarks
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Bookmarks

@MainActor
extension BrowserState {


    // MARK: - Bookmarks

    func openBookmarksManager() {
        isBookmarksManagerOpen = true
    }


    func closeBookmarksManager() {
        isBookmarksManagerOpen = false
    }


    func toggleCurrentPageBookmark() {
        guard let urlString = activeModel?.url?.absoluteString, !urlString.isEmpty else { return }
        guard urlString != "about:blank" else { return }
        // The web start page is chrome, not a page — never bookmark it.
        guard urlString != Self.webChromeStartURL.absoluteString else { return }
        if let existing = bookmarks.firstIndex(where: { $0.urlString == urlString }) {
            bookmarks.remove(at: existing)
        } else {
            let title = activeModel?.title.isEmpty == false ? activeModel!.title : urlString
            bookmarks.append(Bookmark(title: title, urlString: urlString, faviconURL: activeModel?.faviconURL))
        }
        scheduleAutosave()
    }
}
