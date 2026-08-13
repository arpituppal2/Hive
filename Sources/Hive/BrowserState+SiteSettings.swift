//
//  BrowserState+SiteSettings.swift
//  Hive
//
//  Per-site Settings hub (Chrome chrome://settings/content/all parity): one
//  place to review every host with a remembered decision — zoom, mute,
//  HTTPS-Only exception, or permission grant. Host-first variants of the
//  existing zoom/mute actions so the hub can operate without a live tab.
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Site Settings

@MainActor
extension BrowserState {

    /// All hosts with remembered site decisions, for the Site Settings hub.
    func siteSettingsEntries() -> [SiteSettingsEntry] {
        SiteSettingsIndex.build(
            zoomLevels: siteZoomLevels,
            mutedHosts: siteMutedHosts,
            httpsExceptions: httpsOnlyExceptions,
            permissions: sitePermissions
        )
    }

    /// Opens the Site Settings hub, optionally focused on one host (used by
    /// the Site Security popover so a page's settings are one click away).
    func openSiteSettings(focusHost: String? = nil) {
        siteSettingsFocusHost = focusHost
        isSiteSettingsPanelOpen = true
    }

    /// Host-first zoom set (Site Settings hub). Writes the durable per-site
    /// level and applies it to every open tab on the host — hibernated tabs
    /// included, via their saved wake URL; cold tabs pick it up at attach
    /// (`applySiteZoom`). 100% removes the remembered level.
    func setSiteZoom(forHost host: String, percent: Double) {
        var levels = siteZoomLevels
        if percent == 100 {
            levels.removeValue(forKey: host)
        } else {
            levels[host] = percent
        }
        siteZoomLevels = levels
        let level = log2(max(10, min(500, percent)) / 100)
        for tab in tabs where Self.hostForZoom(tab.model.url ?? tab.savedURL) == host {
            tabZoomLevels[tab.id] = level
            tab.model.browser?.zoomLevel = level
        }
        siteSettingsRevision += 1
        scheduleAutosave()
    }

    /// Resets the remembered zoom for a host to 100%.
    func resetSiteZoom(forHost host: String) {
        setSiteZoom(forHost: host, percent: 100)
    }

    /// Host-first toggle of the durable per-site mute. Shared implementation
    /// behind `toggleSiteMute(for:)` — the hub toggles by key, the context
    /// menu by tab. Muting mutes every open tab on the host; unmuting
    /// releases exactly the mutes this site mute created (per-tab mutes the
    /// user set independently survive, Chrome's layered mute model).
    func toggleSiteMute(host: String) {
        var hosts = siteMutedHosts
        if hosts.contains(host) {
            hosts.remove(host)
            siteMutedHosts = hosts
            // Only release the mutes this site mute applied. Iterate a copy
            // since we mutate the set in the loop.
            for id in Array(siteMutedTabIDs) {
                siteMutedTabIDs.remove(id)
                guard let t = tabs.first(where: { $0.id == id }) else { continue }
                mutedTabIDs.remove(id)
                t.model.browser?.isAudioMuted = false
            }
        } else {
            hosts.insert(host)
            siteMutedHosts = hosts
            for t in tabs where SiteMutePolicy.matchesHost(t.model.url ?? t.savedURL, host: host) {
                mutedTabIDs.insert(t.id)
                siteMutedTabIDs.insert(t.id)
                t.model.browser?.isAudioMuted = true
            }
        }
        siteSettingsRevision += 1
    }

    /// Toggles a host's HTTPS-Only exception ("Allow HTTP" from the hub).
    /// Exempting a host also dismisses any live plaintext warning for it.
    func toggleHTTPSException(forHost host: String) {
        var exceptions = httpsOnlyExceptions
        if exceptions.contains(host) {
            exceptions.remove(host)
        } else {
            exceptions.insert(host)
        }
        httpsOnlyExceptions = exceptions
        // Compare through the shared host key so a www-prefixed page's notice
        // (raw url.host) still matches the www-stripped exception key.
        if let notice = httpsOnlyNotice, SiteMutePolicy.hostKey(for: notice.url) == host {
            httpsOnlyNotice = nil
        }
        siteSettingsRevision += 1
    }

    /// Resets every remembered decision for a host: zoom, mute, HTTPS-Only
    /// exception, and all permission grants. Live tabs on the host return to
    /// default zoom and unmute; nothing else is touched.
    func resetAllSiteSettings(forHost host: String) {
        resetSiteZoom(forHost: host)
        if siteMutedHosts.contains(host) { toggleSiteMute(host: host) }
        if httpsOnlyExceptions.contains(host) { toggleHTTPSException(forHost: host) }
        resetSitePermissions(forHost: host)
    }

    /// Deletes the site's browsing history (with sync tombstones) and its
    /// cookies (via the live page's CDP session, best-effort). Browser cache
    /// is browser-global in CDP and cannot be scoped per site — the sheet's
    /// confirmation says so rather than pretending otherwise. Site settings
    /// (zoom/mute/permissions) are untouched; use ``resetAllSiteSettings`` for
    /// those. Feedback reuses the app-wide clear-data toast.
    func deleteSiteData(forHost host: String) {
        let removedIDs = historyItems
            .filter { SiteDataPolicy.hostMatches($0.url, host: host) }
            .map(\.id)
        if !removedIDs.isEmpty {
            historyItems.removeAll { SiteDataPolicy.hostMatches($0.url, host: host) }
            for id in removedIDs {
                enqueueSyncTombstone(kind: .history, recordID: id.uuidString)
            }
            scheduleAutosave()
        }

        // Whether a cookie removal will actually be attempted — the toast must
        // never claim a deletion that won't happen.
        let willAttemptCookies = canUseWebPageActions && activeModel?.browser != nil

        var message: String
        if removedIDs.isEmpty && !willAttemptCookies {
            message = "No data found for \(host)"
        } else if removedIDs.isEmpty {
            message = "Deleted cookies for \(host)"
        } else if willAttemptCookies {
            message = "Deleted \(removedIDs.count) history entr\(removedIDs.count == 1 ? "y" : "ies") and cookies for \(host)"
        } else {
            message = "Deleted \(removedIDs.count) history entr\(removedIDs.count == 1 ? "y" : "ies") for \(host) (cookies skipped — no page open)"
        }

        // Cookies are scoped per domain through the live page. A failed CDP
        // call must not claim success — correct the toast, but only while it
        // is still the one this action wrote (a newer notice — Clear Browsing
        // Data, another site delete, or the auto-clear — must never be
        // clobbered by a stale failure).
        if willAttemptCookies {
            let hostCopy = host
            let originalMessage = message
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let cookies = try? await self.cdpClient.networkCookies() else {
                    if self.appNotice == originalMessage {
                        self.appNotice = "\(originalMessage); cookies failed — try again with a web page open"
                    }
                    return
                }
                let matching = cookies.filter { cookie in
                    guard let domain = cookie["domain"] as? String,
                          let name = cookie["name"] as? String,
                          !name.isEmpty
                    else { return false }
                    return SiteDataPolicy.cookieDomainMatches(domain, host: hostCopy)
                }
                for cookie in matching {
                    guard let domain = cookie["domain"] as? String,
                          let name = cookie["name"] as? String,
                          let path = cookie["path"] as? String else { continue }
                    // Pass each cookie's own path — a hardcoded "/" would leave
                    // path-scoped cookies behind.
                    try? await self.cdpClient.deleteCookie(name: name, domain: domain, path: path)
                }
            }
        }

        siteSettingsRevision += 1
        showAppNotice(message)
    }
}
