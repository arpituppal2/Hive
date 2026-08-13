//
//  BrowserState+PinnedApps.swift
//  Hive
//
//  Arc/Sidekick-style Pinned Web Apps. The HiveCore model (PinnedWebApp)
//  existed but was never wired; this extension owns the app behaviors:
//  pinning the current page (or any http/https URL), removing, renaming,
//  opening (new tab + last-used stamp), and rail reordering — all persisted
//  in the session envelope and capped by PinnedWebAppPolicy. Apps are never
//  added from private tabs (private browsing leaves no durable trace), and
//  remain outside the encrypted-sync boundary (local-only, like boosts,
//  reading list, and passwords) until added to the mutation boundary.
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit

// MARK: - BrowserState + Pinned Web Apps

@MainActor
extension BrowserState {

    /// Adds a real http/https URL as a pinned app. Re-pinning an already-pinned
    /// app refreshes its name/favicon in place (identity-normalized). Returns
    /// whether an entry actually landed (no-op for non-http URLs).
    @discardableResult
    func addPinnedWebApp(url: URL, name: String, faviconURL: URL? = nil) -> Bool {
        guard PinnedWebAppPolicy.normalizedAppURL(url) != nil else { return false }
        let updated = PinnedWebAppPolicy.upsert(
            existing: pinnedWebApps,
            url: url,
            name: name,
            faviconURL: faviconURL
        )
        guard updated != pinnedWebApps else { return false }
        pinnedWebApps = updated
        return true
    }

    /// Pins the current page as an app (context menu, panel). Never from a
    /// private tab or web-chrome/blank page.
    @discardableResult
    func addCurrentPageAsPinnedApp() -> Bool {
        guard activeTab?.isPrivate != true,
              let url = activeModel?.url,
              PinnedWebAppPolicy.normalizedAppURL(url) != nil else { return false }
        let title = activeModel?.title.isEmpty == false
            ? activeModel!.title
            : (url.host ?? url.absoluteString)
        return addPinnedWebApp(url: url, name: title, faviconURL: activeModel?.faviconURL)
    }

    /// Removes a pinned app entirely.
    func removePinnedWebApp(id: String) {
        pinnedWebApps.removeAll { $0.id == id }
    }

    /// Renames a pinned app (its identity and placement are untouched).
    func renamePinnedWebApp(id: String, to name: String) {
        guard let index = pinnedWebApps.firstIndex(where: { $0.id == id }) else { return }
        let cleaned = PinnedWebAppPolicy.normalizedAppName(name, url: pinnedWebApps[index].url)
        guard cleaned != pinnedWebApps[index].name else { return }
        pinnedWebApps[index].name = cleaned
    }

    /// Opens a pinned app in a new tab, stamping lastUsedAt (Arc behavior:
    /// opening an app is a use, which future sort-by-use can rank on).
    func openPinnedWebApp(id: String) {
        guard let app = pinnedWebApps.first(where: { $0.id == id }) else { return }
        if let index = pinnedWebApps.firstIndex(where: { $0.id == id }) {
            pinnedWebApps[index].lastUsedAt = Date()
        }
        isPinnedAppsPanelOpen = false
        newTab(url: app.url, activate: true)
    }

    /// Reorders the pinned-app rail by offset (-1 = toward the front, +1 =
    /// toward the back). Sort order is the rail's authoritative key, so the
    /// reorder rewrites sortOrder values to match the new position.
    func movePinnedWebApp(id: String, offset: Int) {
        var apps = PinnedWebAppPolicy.sortedForRail(pinnedWebApps)
        guard let from = apps.firstIndex(where: { $0.id == id }) else { return }
        let to = min(max(from + offset, 0), apps.count - 1)
        guard to != from else { return }
        let moved = apps.remove(at: from)
        apps.insert(moved, at: to)
        // Rewrite sortOrder so the reorder survives any array reshuffle.
        pinnedWebApps = apps.enumerated().map { index, app in
            var app = app
            app.sortOrder = index
            return app
        }
    }

    /// Whether the given URL is already pinned as an app (menu checkmark /
    /// panel state).
    func isPinnedWebApp(_ url: URL?) -> Bool {
        PinnedWebAppPolicy.isPinned(pinnedWebApps, url: url)
    }
}
