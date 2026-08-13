//
//  BrowserState+Autofill.swift
//  Hive
//
//  Saved-credential autofill (Chrome/Safari parity): a JS probe injected on
//  http/https pages detects a username+password form and reports it over the
//  console bridge; the native side matches saved credentials by host and
//  surfaces a "Use saved password?" chip. Filling is ALWAYS an explicit user
//  click — never automatic — and never runs in private tabs.
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit

// MARK: - AutofillSuggestion

/// A detected login form with the saved credentials available for it.
struct AutofillSuggestion: Identifiable {
    let id = UUID()
    /// The page host the credential was matched against.
    let host: String
    /// The probe-assigned id of the detected form (`data-hive-autofill-id`).
    let formID: String
    /// The tab whose page hosts the form (fill targets its model).
    let tabID: String
    /// Saved credentials whose site matches the host, in save order.
    let matches: [SavedPassword]
}

// MARK: - BrowserState + Autofill

@MainActor
extension BrowserState {

    /// JS probe injected on http/https pages (never private tabs). Detects a
    /// password input with a nearby username field, stamps the form with a
    /// stable `data-hive-autofill-id`, and reports `HIVE_AUTOFILL|<id>|<username>`
    /// (username URI-encoded). Installs `window.__hiveFillAutofill(id, username,
    /// password)` so the native side can fill the exact form on an explicit
    /// user click. Self-guarding; re-injection per navigation is safe.
    static let autofillProbeScript = """
    (function(){
      if (window.__hiveAutofillProbeInstalled) return;
      window.__hiveAutofillProbeInstalled = true;
      var nextID = 0;
      function usernameInputOf(form, pw){
        var inputs = form.querySelectorAll ? Array.prototype.slice.call(form.querySelectorAll('input')) : [];
        for (var i = 0; i < inputs.length; i++){
          var el = inputs[i];
          if (el === pw) continue;
          var t = (el.type || 'text').toLowerCase();
          if (t === 'text' || t === 'email' || t === 'tel') return el;
        }
        return null;
      }
      function report(pw){
        pw = pw || document.querySelector('input[type="password"]');
        if (!pw) return;
        var form = pw.form || pw.parentElement || document.body;
        if (!form) return;
        var user = usernameInputOf(form, pw);
        if (!user) return;
        var id = form.getAttribute('data-hive-autofill-id');
        if (!id) { id = 'f' + (++nextID); form.setAttribute('data-hive-autofill-id', id); }
        console.log('HIVE_AUTOFILL|' + id + '|' + encodeURIComponent(user.value || ''));
      }
      window.__hiveFillAutofill = function(id, username, password){
        var form = document.querySelector('[data-hive-autofill-id="' + id + '"]');
        if (!form) return false;
        var pw = form.querySelector('input[type="password"]');
        if (!pw) return false;
        var user = usernameInputOf(form, pw);
        if (user){
          user.value = username;
          user.dispatchEvent(new Event('input', {bubbles:true}));
          user.dispatchEvent(new Event('change', {bubbles:true}));
        }
        pw.value = password;
        pw.dispatchEvent(new Event('input', {bubbles:true}));
        pw.dispatchEvent(new Event('change', {bubbles:true}));
        return true;
      };
      setTimeout(function(){ report(); }, 700);
      document.addEventListener('focusin', function(e){
        var t = e.target;
        if (t && t.tagName === 'INPUT' && (t.type || '').toLowerCase() === 'password') report(t);
      }, true);
      // --- Password save/update capture (Chrome parity) ---
      // Reports just-submitted credentials so the native side can offer to
      // save a new account or update a changed password. Fires on form
      // submit (capture phase — values are read before any navigation) and
      // on Enter inside a password field (covers JS-intercepted logins).
      // Each form remembers its last reported pair, so an identical retry
      // never double-offers while a corrected retry does; a fresh page is a
      // fresh JS context, so the map resets naturally on navigation.
      var lastCapture = {};
      var lastCapturePass = {};
      function captureId(form){
        var id = form.getAttribute('data-hive-autofill-id');
        if (!id) { id = 'c' + (++nextID); form.setAttribute('data-hive-autofill-id', id); }
        return id;
      }
      function reportCapture(form){
        if (!form || !form.querySelectorAll) return;
        var pw = form.querySelector('input[type="password"]');
        if (!pw) return;
        var user = usernameInputOf(form, pw);
        if (!user) return;
        var username = user.value || '';
        var password = pw.value || '';
        if (!username || !password) return;
        var key = captureId(form);
        if (lastCapture[key] === username && lastCapturePass[key] === password) return;
        lastCapture[key] = username;
        lastCapturePass[key] = password;
        console.log('HIVE_PASSWORD_CAPTURE|' + encodeURIComponent(username) + '|' + encodeURIComponent(password));
      }
      document.addEventListener('submit', function(e){
        var t = e.target;
        if (t && t.tagName === 'FORM') reportCapture(t);
      }, true);
      document.addEventListener('keydown', function(e){
        if (e.key !== 'Enter') return;
        var t = e.target;
        if (t && t.tagName === 'INPUT' && (t.type || '').toLowerCase() === 'password'){
          reportCapture(t.form || t.parentElement || document.body);
        }
      }, true);
    })();
    """

    /// Routes `HIVE_AUTOFILL|<formID>|<encodedUsername>` from the console
    /// bridge. Gated on a visible page (active tab or split pane), a
    /// non-private tab, an http/https page, and saved credentials whose site
    /// matches the host. Repeated reports for the same host+form are ignored
    /// while a chip is already showing.
    func handleAutofillConsoleMessage(_ message: String, from model: CefWebViewModel) {
        guard peekPaneFrame(for: model) != nil,
              let tab = tabs.first(where: { $0.model === model }),
              !tab.isPrivate else { return }
        guard message.hasPrefix("HIVE_AUTOFILL|") else { return }
        let parts = message.split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count == 3, !parts[1].isEmpty else { return }
        let formID = parts[1]
        // The prefilled username ranks its matching credential first (Chrome
        // lists the currently-typed account at the top of the suggestion).
        let typedUsername = parts[2].removingPercentEncoding ?? ""
        guard let host = model.url?.host, !host.isEmpty,
              model.url?.scheme == "http" || model.url?.scheme == "https"
        else { return }
        // The user dismissed this host this session — don't nag again.
        if dismissedAutofillHosts.contains(host) { return }
        if let existing = pendingAutofillSuggestion,
           existing.tabID == tab.id && existing.host == host && existing.formID == formID {
            return
        }

        let candidates = savedPasswords.map { AutofillCandidate(site: $0.site, username: $0.username) }
        let matched = AutofillMatcher.matches(forHost: host, candidates: candidates)
        guard !matched.isEmpty else { return }
        // Map back to full credentials, deduping by id so two matched sites
        // sharing a username (e.g. example.com + login.example.com, both
        // "alice") never produce duplicate rows in the chip menu.
        var seenIDs = Set<UUID>()
        let credentials = matched.compactMap { candidate -> SavedPassword? in
            guard let item = savedPasswords.first(where: { $0.username == candidate.username }),
                  seenIDs.insert(item.id).inserted else { return nil }
            return item
        }
        guard !credentials.isEmpty else { return }
        let ordered = credentials.sorted { a, b in
            let aPreferred = !typedUsername.isEmpty && a.username == typedUsername
            let bPreferred = !typedUsername.isEmpty && b.username == typedUsername
            return aPreferred && !bPreferred
        }

        pendingAutofillSuggestion = AutofillSuggestion(
            host: host,
            formID: formID,
            tabID: tab.id,
            matches: ordered
        )
    }

    /// Fills the detected form with the chosen credential and dismisses the
    /// chip. The click is the consent — the password is only ever written
    /// into the page by this explicit user action.
    func fillAutofill(suggestion: AutofillSuggestion, credential: SavedPassword) {
        defer { pendingAutofillSuggestion = nil }
        guard let tab = tabs.first(where: { $0.id == suggestion.tabID }),
              !tab.isHibernated else { return }
        tab.model.executeJavaScript("""
        (function(){
          var fn = window.__hiveFillAutofill;
          if (typeof fn !== 'function') return;
          fn("\(Self.jsStringLiteral(suggestion.formID))", "\(Self.jsStringLiteral(credential.username))", "\(Self.jsStringLiteral(credential.password))");
        })();
        """)
    }

    /// Escapes a value for a double-quoted JavaScript string literal — the
    /// only context where saved credentials cross into the page. Backslash,
    /// quote, newline, carriage return, tab, and the JS line separators
    /// U+2028/U+2029 are all escaped so a stored value can never break the
    /// injected script (silent no-op or syntax error) or smuggle code.
    static func jsStringLiteral(_ value: String) -> String {
        var out = ""
        out.reserveCapacity(value.count + 8)
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{2028}": out += "\\u2028"
            case "\u{2029}": out += "\\u2029"
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Dismisses the chip and remembers the host for the session so an
    /// unchanged page doesn't re-nag on the next focus.
    func dismissAutofillSuggestion() {
        if let suggestion = pendingAutofillSuggestion {
            dismissedAutofillHosts.insert(suggestion.host)
        }
        pendingAutofillSuggestion = nil
    }

    /// Drops any autofill chip belonging to a tab (closed tab, navigation).
    func dropAutofillSuggestion(forTabID tabID: String) {
        if pendingAutofillSuggestion?.tabID == tabID {
            pendingAutofillSuggestion = nil
        }
    }
}
