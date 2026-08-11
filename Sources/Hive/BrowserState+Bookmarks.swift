//
//  BrowserState+Bookmarks.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//
//  Sections: - Bookmarks (incl. Chrome/Safari-parity folders)
//
//  The Bookmark model always carried folder fields (isFolder/parentID) but
//  they were dead: the manager was a flat list, the bar was flat, and the
//  sync payload dropped folder structure. This extension makes folders real —
//  create/rename/delete (deleting a folder removes its whole subtree and
//  tombstones every removed record so peers converge, never orphan), and
//  cycle-guarded moves — with every mutation flowing through the same
//  encrypted bookmark sync boundary as plain bookmarks.
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

    // MARK: - Manager surface

    func openBookmarksManager(folderID: UUID? = nil) {
        // Folder prefill lets the bookmark bar drill straight into a folder.
        if folderID != nil { bookmarksManagerFolderID = folderID }
        isBookmarksManagerOpen = true
    }

    func closeBookmarksManager() {
        bookmarksManagerFolderID = nil
        isBookmarksManagerOpen = false
    }

    // MARK: - Scope helpers

    /// The folder-scoped view of the tree: the direct children of `folderID`
    /// (nil = root). Search ignores scope (flat across the whole tree).
    func bookmarks(in folderID: UUID?) -> [Bookmark] {
        bookmarks.filter { $0.parentID == folderID }
    }

    /// The flat tree shape the folder policy operates on.
    func folderNodes() -> [BookmarkFolderNode] {
        bookmarks.map { BookmarkFolderNode(id: $0.id, parentID: $0.parentID) }
    }

    // MARK: - Folder mutations

    /// Creates a folder inside `parentID` (nil = root) and syncs it like any
    /// other bookmark record.
    @discardableResult
    func createBookmarkFolder(named name: String, parentID: UUID? = nil) -> Bookmark {
        let folder = Bookmark(
            folderID: UUID(),
            title: BookmarkFolderPolicy.normalizedFolderName(name),
            parentID: parentID
        )
        bookmarks.append(folder)
        enqueueBookmark(folder)
        scheduleAutosave()
        return folder
    }

    /// Renames a folder (its identity and placement are untouched).
    func renameBookmarkFolder(id: UUID, to name: String) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id && $0.isFolder }) else { return }
        let normalized = BookmarkFolderPolicy.normalizedFolderName(name)
        guard normalized != bookmarks[index].title else { return }
        bookmarks[index].title = normalized
        enqueueBookmark(bookmarks[index])
        scheduleAutosave()
    }

    /// Deletes a folder AND its entire subtree (Chrome behavior). Every
    /// removed record is tombstoned individually so remote devices converge
    /// on the delete instead of orphaning the folder's children.
    func deleteBookmarkFolder(id: UUID) {
        guard bookmarks.contains(where: { $0.id == id && $0.isFolder }) else { return }
        var removed = Set<UUID>([id])
        removed.formUnion(BookmarkFolderPolicy.descendantIDs(of: id, in: folderNodes()))
        for recordID in removed {
            bookmarks.removeAll { $0.id == recordID }
            enqueueSyncTombstone(kind: .bookmark, recordID: recordID.uuidString)
        }
        if bookmarksManagerFolderID == id { bookmarksManagerFolderID = nil }
        scheduleAutosave()
    }

    /// Moves a bookmark (or a whole folder subtree) under `folderID`
    /// (nil = root). Cycle-guarded: a folder can never become its own parent
    /// or be moved into one of its own descendants.
    func moveBookmark(id: UUID, toFolderID folderID: UUID?) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        guard BookmarkFolderPolicy.canMove(nodeID: id, toParent: folderID, in: folderNodes()) else { return }
        bookmarks[index].parentID = folderID
        enqueueBookmark(bookmarks[index])
        scheduleAutosave()
    }

    // MARK: - Plain bookmarks

    /// Chrome ⌘⇧D parity: saves every open tab in the current workspace into
    /// a new date-named folder. Excludes private tabs (ephemeral by design),
    /// internal chrome/blank pages, and duplicate URLs; the folder and every
    /// child flow through the same encrypted bookmark sync boundary as
    /// single-bookmark saves. Reports the outcome via the app-wide toast.
    @discardableResult
    func bookmarkAllTabs() -> Bookmark? {
        let tabsToSave = tabs.filter { tab in
            guard tab.workspaceID == currentWorkspaceID, !tab.isPrivate else { return false }
            // Live URL wins; hibernated tabs contribute their wake URL.
            let url = tab.model.url ?? tab.savedURL
            guard let url, BookmarkAllTabsPolicy.isEligibleURL(url.absoluteString) else { return false }
            return true
        }
        let entries = tabsToSave.compactMap { tab -> BookmarkAllTabsEntry? in
            guard let url = tab.model.url ?? tab.savedURL else { return nil }
            let title = tab.customTitle ?? tab.model.title
            let collapsed = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            let label = collapsed.isEmpty ? (url.host ?? url.absoluteString) : collapsed
            return BookmarkAllTabsEntry(title: label, urlString: url.absoluteString)
        }
        let unique = BookmarkAllTabsPolicy.deduplicated(entries)
        guard !unique.isEmpty else {
            showAppNotice("No bookmarkable tabs in this workspace")
            return nil
        }

        let folder = createBookmarkFolder(named: BookmarkAllTabsPolicy.folderName(on: Date()))
        for entry in unique {
            let bookmark = Bookmark(title: entry.title, urlString: entry.urlString, parentID: folder.id)
            bookmarks.append(bookmark)
            enqueueBookmark(bookmark)
        }
        scheduleAutosave()
        let count = unique.count
        showAppNotice("Bookmarked \(count) tab\(count == 1 ? "" : "s") in “\(folder.title)”")
        return folder
    }

    func toggleCurrentPageBookmark() {
        guard let urlString = activeModel?.url?.absoluteString, !urlString.isEmpty else { return }
        guard urlString != "about:blank" else { return }
        // Hive-owned web chrome is UI, not a page — never bookmark it.
        guard !Self.isInternalWebChromeURL(activeModel?.url) else { return }
        if let existing = bookmarks.firstIndex(where: { $0.urlString == urlString }) {
            let removedID = bookmarks[existing].id
            bookmarks.remove(at: existing)
            enqueueSyncTombstone(kind: .bookmark, recordID: removedID.uuidString)
        } else {
            let title = activeModel?.title.isEmpty == false ? activeModel!.title : urlString
            // Star-save lands in the folder currently being browsed (or root).
            bookmarks.append(Bookmark(
                title: title,
                urlString: urlString,
                faviconURL: activeModel?.faviconURL,
                parentID: bookmarksManagerFolderID
            ))
        }
        scheduleAutosave()
    }

    // MARK: - Sync boundary

    /// Fire-and-forget bookmark push through the encrypted sync boundary.
    /// Used by every folder mutation so folder structure propagates like any
    /// bookmark edit (the payload carries parentID/isFolder).
    func enqueueBookmark(_ bookmark: Bookmark) {
        Task { @MainActor [weak self] in
            await self?.pushBookmarkToCloud(bookmark)
        }
    }
}
