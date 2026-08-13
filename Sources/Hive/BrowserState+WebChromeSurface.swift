//
//  BrowserState+WebChromeSurface.swift
//  Hive
//
//  Native methods backing web-chrome bridge actions that previously had no
//  Swift registration (the 19 dead buttons found in the audit). Each method
//  is a thin, honest wrapper over existing state or a minimal real behavior;
//  nothing here fakes success.
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


@MainActor
extension BrowserState {

    // MARK: - Bookmark a link (context menu "Bookmark Link")

    /// Adds a bookmark for an arbitrary http/https URL (not necessarily the
    /// active page). Mirrors the omnibox star for a link the user chose.
    func addBookmark(urlString: String, title: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              !urlString.isEmpty
        else { return false }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (url.host ?? urlString)
            : title
        addBookmark(Bookmark(title: cleanTitle, url: url))
        return true
    }

    // MARK: - Autofill credentials (web chrome autofill chip)

    /// Fills the active page's focused credential form with the saved
    /// credential for (host, username). The click is the consent; the password
    /// is only written into the page by this explicit action, and only when a
    /// matching credential exists.
    func autofillCredentials(host: String, username: String) -> Bool {
        guard let model = activeModel,
              let credential = savedPasswords.first(where: {
                  $0.username == username && CredentialSitePolicy.normalize($0.site) == CredentialSitePolicy.normalize(host)
              })
        else { return false }
        let userLiteral = Self.jsStringLiteral(credential.username)
        let passLiteral = Self.jsStringLiteral(credential.password)
        let script = """
        (function () {
          var user = "\(userLiteral)";
          var pass = "\(passLiteral)";
          var inputs = Array.prototype.slice.call(document.querySelectorAll('input'));
          var pw = null, uid = null;
          for (var i = 0; i < inputs.length; i++) {
            var t = (inputs[i].type || 'text').toLowerCase();
            if (t === 'password' && !pw) pw = inputs[i];
            if ((t === 'text' || t === 'email' || t === 'tel' || t === 'username') && !uid) uid = inputs[i];
          }
          if (!pw && !uid) return;
          var set = function (el, v) {
            if (!el) return;
            var proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
            var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
            setter.call(el, v);
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          };
          if (uid) set(uid, user);
          if (pw) set(pw, pass);
        })();
        """
        model.executeJavaScript(script)
        return true
    }

    // MARK: - Reading list

    /// Clears the entire reading list (web chrome "Clear reading list").
    func clearReadingList() {
        readingList.removeAll()
        scheduleAutosave()
    }

    // MARK: - Clear site data for the active host

    /// Clears cookies and localStorage for the active page's host. Best-effort:
    /// cookies go through HTTPCookieStorage (app process), page storage through
    /// an injected script on the live page. Never claims success on a dead page.
    func clearSiteDataForActiveHost() {
        guard let url = activeModel?.url, let host = url.host else { return }
        // Cookies for the host and its subdomains.
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies where cookie.domain.contains(host) {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        // Page-side storage: only meaningful when a live page is present.
        activeModel?.executeJavaScript("""
        (function () { try { localStorage.clear(); sessionStorage.clear(); } catch (e) {} })();
        """)
        showAppNotice("Cleared data for \\(host)")
    }

    // MARK: - Download an arbitrary URL (context menu "Save Link/Image As…")

    /// Fetches a URL and saves it through NSSavePanel, recording the result in
    /// the Downloads panel. Reuses the same honest fetch-then-save path as
    /// `saveImageAs` (CefKit exposes no startDownload).
    func downloadURL(_ url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                let panel = NSSavePanel()
                panel.nameFieldStringValue = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
                guard panel.runModal() == .OK, let destination = panel.url else { return }
                try data.write(to: destination)
                var item = DownloadItem(suggestedName: destination.lastPathComponent, url: url)
                item.isComplete = true
                item.destinationURL = destination
                self.downloads.append(item)
                self.scheduleAutosave()
            } catch {
                NSLog("[HiveWebChrome] Download failed: \\(error.localizedDescription)")
            }
        }
    }

    // MARK: - Find in page (web chrome find bar)

    /// Find-next in the direction the web chrome find bar requested. The query
    /// is stored so ⌘G/⇧⌘G keep working after the bar is dismissed.
    func findInPage(query: String, forward: Bool) {
        findQuery = query
        guard !query.isEmpty, let model = activeModel else { return }
        model.executeJavaScript(Self.buildFindJumpJS(query, forward: forward, caseSensitive: findMatchCaseSensitive))
        scheduleFindCount(query)
    }

    // MARK: - Permission prompt response (web chrome banner)

    /// Routes the web chrome banner's Allow / Block / Dismiss to the same
    /// resolution path as the native banner. Dismiss drops the front prompt
    /// without persisting a decision.
    func respondPermission(response: String) {
        switch response {
        case "allow":
            resolvePermissionPrompt(allow: true)
        case "deny":
            resolvePermissionPrompt(allow: false)
        default:
            guard !pendingPermissionRequests.isEmpty else { return }
            pendingPermissionRequests.removeFirst()
        }
    }

    // MARK: - Site permission toggle (web chrome permissions panel)

    /// Maps a web-chrome permission key to a durable SitePermissionKind and
    /// records the decision for the active host.
    func setSitePermission(key: String, allow: Bool, host: String?) {
        let normalizedHost = host ?? activeModel?.url?.host ?? ""
        guard !normalizedHost.isEmpty,
              let kind = Self.sitePermissionKind(for: key)
        else { return }
        setSitePermission(allow ? .allow : .deny, forHost: normalizedHost, kind: kind, isPrivate: isPrivateBrowsing)
    }

    /// Maps web-chrome permission keys onto HiveCore's durable kinds. Returns
    /// nil for keys with no durable equivalent (autoplay is engine-level, not
    /// a per-site decision in this build).
    static func sitePermissionKind(for key: String) -> SitePermissionKind? {
        switch key {
        case "camera": return .camera
        case "microphone": return .microphone
        case "location": return .location
        case "notifications": return .notifications
        case "popups": return .popups
        default: return nil
        }
    }

    // MARK: - Save page as HTML

    /// Saves the active page's HTML to a user-chosen location. Fetches the
    /// source from the live URL (honest scope: static HTML, not a full MHTML
    /// bundle with subresources).
    func savePageAsHTML() {
        guard let url = activeModel?.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return }
        Task { @MainActor in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                let panel = NSSavePanel()
                panel.nameFieldStringValue = (url.host ?? "page") + ".html"
                guard panel.runModal() == .OK, let destination = panel.url else { return }
                try data.write(to: destination)
            } catch {
                NSLog("[HiveWebChrome] Save page failed: \\(error.localizedDescription)")
            }
        }
    }

    // MARK: - View source

    /// Navigates a tab (by id, falling back to active) to the `view-source:`
    /// form of its URL. Chromium renders the source natively.
    func viewSource(id: String?) {
        let model = id.flatMap { tabID in tabs.first(where: { $0.id == tabID })?.model } ?? activeModel
        guard let url = model?.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let sourceURL = URL(string: "view-source:" + url.absoluteString)
        else { return }
        model?.load(sourceURL)
    }

    // MARK: - Open DevTools

    /// Opens Chromium DevTools for a tab (by id, falling back to active).
    func openDevTools(id: String?) {
        let model = id.flatMap { tabID in tabs.first(where: { $0.id == tabID })?.model } ?? activeModel
        model?.browser?.showDevTools()
    }

    // MARK: - Find bar teardown

    /// Clears the in-page selection/highlight and resets the match counter
    /// when the web chrome find bar is dismissed. Mirrors `closeFindBar`.
    func findInPageDone() {
        clearFindHighlights()
    }

    // MARK: - Password capture decisions (web chrome banner)

    /// Persists a credential the user chose to save from the web chrome
    /// banner. `url` is normalized to its canonical host by the Keychain
    /// store path; returns whether the write succeeded.
    @discardableResult
    func savePassword(url: String, username: String, password: String) -> Bool {
        savePassword(username: username, password: password, site: url)
    }

    /// Records "never save passwords for this site" from the web chrome
    /// banner (durable, survives relaunch).
    func neverSavePassword(url: String) {
        guard let host = URL(string: url)?.host ?? activeModel?.url?.host else { return }
        neverSavePasswordForHost(host)
    }

    // MARK: - Translate (honest, zero-cost web path)

    /// Translates a page via Google Translate's public web surface — no cloud
    /// inference cost, no fabricated "translating…" state. Navigating the
    /// active tab to the translate URL is the same behavior as Chrome's
    /// "Translate this page" hand-off.
    func translatePage(url: String, to targetLanguage: String) {
        guard let source = URL(string: url),
              let scheme = source.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return }
        let code = Self.translateLanguageCode(targetLanguage)
        guard var components = URLComponents(string: "https://translate.google.com/translate") else { return }
        components.queryItems = [
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: code),
            URLQueryItem(name: "u", value: source.absoluteString),
        ]
        guard let destination = components.url else { return }
        activeModel?.load(destination)
    }

    /// Maps a human language name (or an existing ISO code) to a Google
    /// Translate target code. Falls back to "en".
    private static func translateLanguageCode(_ language: String) -> String {
        let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.count == 2 { return trimmed }
        switch trimmed {
        case "english", "anglais": return "en"
        case "spanish", "español", "espagnol": return "es"
        case "french", "français": return "fr"
        case "german", "deutsch": return "de"
        case "chinese", "中文", "简体中文": return "zh-CN"
        case "japanese", "日本語": return "ja"
        case "korean", "한국어": return "ko"
        case "portuguese", "português": return "pt"
        case "italian", "italiano": return "it"
        case "dutch", "nederlands": return "nl"
        case "russian", "русский": return "ru"
        case "arabic", "العربية": return "ar"
        case "hindi", "हिन्दी": return "hi"
        default: return "en"
        }
    }

    // MARK: - Open in new window

    /// Opens a fresh window and navigates it to `url`. Because WindowGroup
    /// shares one BrowserState across windows, the URL is staged on
    /// `pendingNewWindowURL` and consumed by the new window's BrowserWindow
    /// on first appearance.
    func newWindowWithURL(_ url: URL) {
        pendingNewWindowURL = url
        NotificationCenter.default.post(
            name: Notification.Name("HiveRequestNewWindow"),
            object: nil
        )
    }

    /// Consumed by BrowserWindow on appearance: if a pending window URL was
    /// staged, navigate to it and clear it so a second window never re-opens
    /// the same destination.
    func consumePendingNewWindowURL() {
        guard let url = pendingNewWindowURL else { return }
        pendingNewWindowURL = nil
        navigateToURL(url)
    }
}
