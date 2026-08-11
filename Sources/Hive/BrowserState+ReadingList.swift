//
//  BrowserState+ReadingList.swift
//  Hive
//
//  Safari-parity Reading List. The HiveCore model (ReadingListEntry) and cap
//  existed but were never wired; this extension owns the app behaviors:
//  saving the current page (or any http/https URL), removing, marking
//  read/unread, opening, and note editing — all persisted in the session
//  envelope and capped by ReadingListPolicy. Entries are never added from
//  private tabs (private browsing leaves no durable trace).
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit

// MARK: - BrowserState + Reading List

@MainActor
extension BrowserState {

    /// Adds a real http/https page to the reading list. Re-saving an already
    /// listed article updates its title/favicon and moves it to the top
    /// without duplicating it (ReadingListPolicy.upsert). Never adds from
    /// private tabs or chrome pages. Returns whether an entry landed.
    @discardableResult
    func addToReadingList(url: URL, title: String, faviconURL: URL? = nil) -> Bool {
        guard ReadingListPolicy.normalizedArticleURL(url) != nil else { return false }
        let updated = ReadingListPolicy.upsert(
            existing: readingList,
            url: url,
            title: title,
            faviconURL: faviconURL
        )
        // No change (e.g. the identical article is already at the front) is
        // not a save — return false and skip the pointless autosave.
        guard updated != readingList else { return false }
        readingList = updated
        return true
    }

    /// Adds the current page to the reading list (context menu, reader mode).
    @discardableResult
    func addCurrentPageToReadingList() -> Bool {
        guard let tab = activeTab, !tab.isPrivate,
              let url = tab.model.url,
              ReadingListPolicy.normalizedArticleURL(url) != nil
        else { return false }
        let title = tab.model.title.isEmpty ? url.absoluteString : tab.model.title
        return addToReadingList(url: url, title: title, faviconURL: tab.model.faviconURL)
    }

    /// Removes the current page from the reading list (context menu toggle).
    func removeCurrentPageFromReadingList() {
        guard let url = activeTab?.model.url,
              let normalized = ReadingListPolicy.normalizedArticleURL(url) else { return }
        readingList.removeAll { entry in
            ReadingListPolicy.normalizedArticleURL(entry.url) == normalized
        }
    }

    /// Whether the given URL is already on the reading list (menu checkmark /
    /// toggle state). Normalized so fragment/trailing-slash variants match.
    func isInReadingList(_ url: URL?) -> Bool {
        guard let normalized = url.flatMap(ReadingListPolicy.normalizedArticleURL) else { return false }
        return readingList.contains { entry in
            ReadingListPolicy.normalizedArticleURL(entry.url) == normalized
        }
    }

    /// Toggles the read state of an entry (Safari marks articles read when
    /// opened; the panel also allows manual toggling).
    func toggleReadingListItemRead(id: String) {
        guard let index = readingList.firstIndex(where: { $0.id == id }) else { return }
        readingList[index].isRead.toggle()
    }

    /// Opens a reading-list entry in the active tab, marking it read and
    /// recording lastViewedAt (Safari behavior: opening = reading).
    func openReadingListItem(id: String) {
        guard let entry = readingList.first(where: { $0.id == id }) else { return }
        if let index = readingList.firstIndex(where: { $0.id == id }) {
            readingList[index].isRead = true
            readingList[index].lastViewedAt = Date()
        }
        isReadingListPanelOpen = false
        navigateToURL(entry.url)
    }

    /// Replaces an entry's note (trimmed + capped by the policy).
    func updateReadingListItemNote(id: String, note: String) {
        guard let index = readingList.firstIndex(where: { $0.id == id }) else { return }
        let validated = ReadingListPolicy.validatedNote(note)
        readingList[index].note = validated.isEmpty ? nil : validated
    }

    /// Removes an entry entirely.
    func removeFromReadingList(id: String) {
        readingList.removeAll { $0.id == id }
    }
}
