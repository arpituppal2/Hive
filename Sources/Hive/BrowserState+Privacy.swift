//
//  BrowserState+Privacy.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Private Browsing (Safari / Zen) | - Privacy Report (Safari) | - Passwords | - Safe Browsing | - Translate
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Privacy

@MainActor
extension BrowserState {


    // MARK: - Private Browsing (Safari / Zen)
    /// True only when the active live tab is private. Privacy is a tab identity,
    /// not a mutable window-wide mode: switching back to a normal tab restores
    /// the normal profile and context contract without relabeling either tab.
    var isPrivateBrowsing: Bool {
        activeTab?.isPrivate ?? false
    }


    /// Creates an ephemeral private tab. The tab owns its privacy boundary;
    /// callers must not toggle a global flag because doing so can leave a
    /// normal tab backed by an incognito label (or vice versa).
    @discardableResult
    func newPrivateTab() -> Tab {
        newTab(isPrivate: true)
    }


    func openPrivacyReport() { isPrivacyReportOpen = true }


    // MARK: - Clear Browsing Data (Chrome parity)

    /// Clears the selected categories through the same boundaries as every
    /// other mutation: history removal stages sync tombstones per item, the
    /// session is autosaved, and cookies/cache go through the live CDP target
    /// (browser-wide in CDP, so one call covers every workspace). Returns the
    /// human-readable outcome for the panel and a transient toast. Honest
    /// scope: the time range applies to date-stamped history only — download
    /// history (no per-item dates), cookies, and cache clear in full.
    func clearBrowsingData(
        history: Bool,
        downloads: Bool,
        cookies: Bool,
        cache: Bool,
        range: ClearBrowsingDataPolicy.TimeRange
    ) -> String {
        var cleared: [String] = []

        if history {
            let cutoff = range.cutoff()
            let removed = historyItems.filter {
                ClearBrowsingDataPolicy.isInRange($0.visitedAt, cutoff: cutoff)
            }
            let decision = HistoryClearPolicy.decision(itemCount: removed.count)
            if decision.shouldPersist {
                let removedIDs = Set(removed.map(\.id))
                historyItems.removeAll { removedIDs.contains($0.id) }
                for id in removedIDs {
                    enqueueSyncTombstone(kind: .history, recordID: id.uuidString)
                }
                cleared.append("\(removedIDs.count) history item\(removedIDs.count == 1 ? "" : "s")")
            }
        }

        if downloads {
            // Terminal records only — an in-flight transfer's context must
            // never be dropped from the live list mid-download. `self.`
            // disambiguates the array from the Bool parameter.
            let removed = self.downloads.filter { $0.isComplete || $0.isCanceled || $0.isInterrupted }
            if !removed.isEmpty {
                let ids = Set(removed.map(\.id))
                self.downloads.removeAll { ids.contains($0.id) }
                cleared.append("\(ids.count) download\(ids.count == 1 ? "" : "s")")
            }
        }

        if cookies || cache {
            // CDP is wired to the active tab; Network.* clear calls are
            // browser-global. Best-effort with honest feedback — a web page
            // must be live for the bridge to exist.
            let wantsCookies = cookies
            let wantsCache = cache
            if canUseWebPageActions, activeModel?.browser != nil {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    do {
                        if wantsCookies { try await self.cdpClient.clearBrowserCookies() }
                        if wantsCache { try await self.cdpClient.clearBrowserCache() }
                    } catch {
                        // Never claim success: the toast said cookies/cache were
                        // cleared, so a failure must correct that claim.
                        self.appNotice = "\(self.appNotice ?? "Cleared"); cookies/cache failed — try again with a web page open"
                    }
                }
                if wantsCookies { cleared.append("cookies via live page") }
                if wantsCache { cleared.append("cache via live page") }
            } else {
                if wantsCookies { cleared.append("cookies (page required — skipped)") }
                if wantsCache { cleared.append("cache (page required — skipped)") }
            }
        }

        let message = cleared.isEmpty ? "Nothing selected to clear" : "Cleared \(cleared.joined(separator: ", "))"
        // Only persist when something actually changed (the existing
        // clearBrowsingHistory convention).
        if !cleared.isEmpty { scheduleAutosave() }
        showAppNotice(message)
        return message
    }

    func closePrivacyReport() { isPrivacyReportOpen = false }


    // MARK: - Passwords

    /// Saves a credential, normalizing the site to its canonical host and
    /// updating an existing (site, username) pair instead of duplicating it
    /// (Chrome behavior). The in-memory row is only touched after the
    /// Keychain write succeeds, so the visible list can never diverge from
    /// the durable store (honest failure — a rejected write keeps the form
    /// open and shows nothing). Returns whether the Keychain write succeeded.
    @discardableResult
    func savePassword(username: String, password: String, site: String) -> Bool {
        let normalizedSite = CredentialSitePolicy.normalize(site)
        guard !username.isEmpty, !password.isEmpty, !normalizedSite.isEmpty else { return false }
        guard KeychainPasswordStore.save(username: username, password: password, site: normalizedSite) else {
            return false
        }
        if let index = savedPasswords.firstIndex(where: {
            $0.site == normalizedSite && $0.username == username
        }) {
            savedPasswords[index] = SavedPassword(
                id: savedPasswords[index].id,
                username: username,
                password: password,
                site: normalizedSite
            )
        } else {
            savedPasswords.append(SavedPassword(username: username, password: password, site: normalizedSite))
        }
        return true
    }


    /// Updates an existing credential in place, re-keying the Keychain entry
    /// when the site or username changed (the old account key is removed so a
    /// stale credential cannot linger). The in-memory row is only replaced
    /// after the Keychain write succeeds, so the visible list never diverges
    /// from the durable store. Returns whether the Keychain write succeeded.
    @discardableResult
    func updatePassword(id: UUID, username: String, password: String, site: String) -> Bool {
        guard let index = savedPasswords.firstIndex(where: { $0.id == id }) else { return false }
        let old = savedPasswords[index]
        let normalizedSite = CredentialSitePolicy.normalize(site)
        guard !username.isEmpty, !password.isEmpty, !normalizedSite.isEmpty else { return false }
        if old.site != normalizedSite || old.username != username {
            KeychainPasswordStore.delete(site: old.site, username: old.username)
        }
        guard KeychainPasswordStore.save(username: username, password: password, site: normalizedSite) else {
            return false
        }
        savedPasswords[index] = SavedPassword(
            id: old.id,
            username: username,
            password: password,
            site: normalizedSite
        )
        return true
    }


    /// One-time reconciliation of sites loaded from the Keychain. Rows saved
    /// before site normalization (or migrated from legacy JSON) keep raw site
    /// strings; this normalizes them in memory, re-keys the Keychain entry
    /// (delete old account key, save the normalized one), and merges rows
    /// that collapse to the same (site, username) — so the manager's dedupe
    /// and Chrome-style keys are consistent going forward. Called once after
    /// `allPasswords()` during session restore.
    func reconcileSavedPasswordSites() {
        var reconciled: [SavedPassword] = []
        for item in savedPasswords {
            let site = CredentialSitePolicy.normalize(item.site)
            // A value that still carries a scheme separator or port is not a
            // usable host (e.g. a bare "https://" or "host:8080" without a
            // scheme) — drop the row rather than keep a dead key.
            guard !site.isEmpty, !site.contains(":"), !site.contains("/") else { continue }
            if site != item.site {
                KeychainPasswordStore.delete(site: item.site, username: item.username)
                KeychainPasswordStore.save(username: item.username, password: item.password, site: site)
            }
            if !reconciled.contains(where: { $0.site == site && $0.username == item.username }) {
                reconciled.append(SavedPassword(
                    id: item.id,
                    username: item.username,
                    password: item.password,
                    site: site
                ))
            }
        }
        savedPasswords = reconciled
    }


    func deletePassword(id: UUID) {
        if let item = savedPasswords.first(where: { $0.id == id }) {
            KeychainPasswordStore.delete(site: item.site, username: item.username)
        }
        savedPasswords.removeAll { $0.id == id }
    }


    // MARK: - Safe Browsing

    func showSafeBrowsingWarning(for url: URL, reason: String = "Deceptive site ahead") {
        safeBrowsingWarning = SafeBrowsingWarning(url: url, reason: reason)
    }


    func dismissSafeBrowsingWarning() {
        safeBrowsingWarning = nil
    }


    // MARK: - Translate

    func showTranslateBar(sourceLanguage: String = "Detected", targetLanguage: String = "English") {
        translateBar = TranslateState(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
    }


    func dismissTranslateBar() {
        translateBar = nil
    }


    /// Translates the current page by opening it through Google Translate's proxy.
    /// Uses the detected source language from the translate bar, falling back to auto-detection.
    /// This matches how Chrome and Edge handle built-in translation for pages.
    func translateCurrentPage(targetLanguage: String = "en") {
        guard let url = activeModel?.url else { return }
        let source = translateBar.map { TranslateState.languageCode(for: $0.sourceLanguage) } ?? "auto"
        let encodedURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url.absoluteString
        let translateURL = "https://translate.google.com/translate?hl=\(targetLanguage)&sl=\(source)&tl=\(targetLanguage)&u=\(encodedURL)"
        dismissTranslateBar()
        if let translatedURL = URL(string: translateURL) {
            navigateToURL(translatedURL)
        }
    }


    func checkTranslate(_ url: URL) {
        let host = url.host ?? ""
        let tld = host.split(separator: ".").last.map(String.init) ?? ""
        if let lang = Self.translateTLDNames[tld] {
            showTranslateBar(sourceLanguage: lang, targetLanguage: "English")
        }
    }


    func checkSafeBrowsing(_ url: URL) {
        guard let host = url.host?.lowercased() else { return }
        // Real EasyList blocking — 1500 ad/tracker domains
        if EasyListBlocklist.domains.contains(host) {
            trackerBlockedCount += 1
        }
        // Skip Safe Browsing lookups in private mode — don't leak URL hashes
        guard !isPrivateBrowsing else { return }
        // Google Safe Browsing API v4 — real phishing/malware protection
        // Runs async in background so it never blocks page navigation
        let checkURL = url
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let threat = await GoogleSafeBrowsingClient.shared.check(url: checkURL) {
                self.showSafeBrowsingWarning(for: checkURL, reason: threat)
            }
        }
    }
}
