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

    func closePrivacyReport() { isPrivacyReportOpen = false }


    // MARK: - Passwords

    func savePassword(username: String, password: String, site: String) {
        let item = SavedPassword(username: username, password: password, site: site)
        savedPasswords.append(item)
        KeychainPasswordStore.save(username: username, password: password, site: site)
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
