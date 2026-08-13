//
//  BrowserState+PasswordCapture.swift
//  Hive
//
//  Password save/update capture (Chrome parity): the autofill probe reports
//  just-submitted login credentials over the console bridge; this side
//  classifies them against saved credentials (PasswordCapturePolicy) and
//  surfaces a "Save password?" / "Update password?" chip. The credential is
//  held transiently in memory ONLY while the chip is showing — never logged,
//  never persisted, and only ever written to the Keychain by an explicit
//  user click on Save/Update.
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit

// MARK: - PasswordCaptureOffer

/// A just-submitted credential awaiting a Save/Update decision.
struct PasswordCaptureOffer: Identifiable {
    let id = UUID()
    /// The page host the credential belongs to (used for the Keychain site
    /// and for the durable never-save list).
    let host: String
    /// The tab whose page submitted the form.
    let tabID: String
    /// The submitted username (already trimmed by the policy).
    let username: String
    /// The submitted password — held only while the chip is visible.
    let password: String
    /// What the policy decided: save a new account or update an existing one.
    let kind: PasswordCapturePolicy.OfferKind
}

// MARK: - BrowserState + Password Capture

@MainActor
extension BrowserState {

    /// UserDefaults key for the durable "never save passwords for this host"
    /// list. Reading it on every capture is cheap (submit events are rare).
    static let neverSavePasswordHostsKey = "HiveNeverSavePasswordHosts"

    /// Hosts the user has told us never to offer saving for: the durable
    /// list plus anything dismissed this session.
    var neverSavePasswordHosts: Set<String> {
        var hosts = sessionNeverSavePasswordHosts
        for host in UserDefaults.standard.stringArray(forKey: Self.neverSavePasswordHostsKey) ?? [] {
            hosts.insert(host)
        }
        return hosts
    }

    /// Routes `HIVE_PASSWORD_CAPTURE|<username>|<password>` from the console
    /// bridge. Gated on a visible page (active tab or split pane), a
    /// non-private tab, an http/https page, a host the user hasn't excluded,
    /// and a non-trivial policy decision. A repeated report for the same tab
    /// and host while an offer is already showing is ignored.
    func handlePasswordCaptureConsoleMessage(_ message: String, from model: CefWebViewModel) {
        guard peekPaneFrame(for: model) != nil,
              let tab = tabs.first(where: { $0.model === model }),
              !tab.isPrivate else { return }
        guard message.hasPrefix("HIVE_PASSWORD_CAPTURE|") else { return }
        let parts = message.split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { return }
        let username = parts[1].removingPercentEncoding ?? ""
        let password = parts[2].removingPercentEncoding ?? ""
        guard !username.isEmpty, !password.isEmpty else { return }
        guard let host = model.url?.host, !host.isEmpty,
              model.url?.scheme == "http" || model.url?.scheme == "https"
        else { return }
        // The user said "never" for this host (this session or durably).
        if neverSavePasswordHosts.contains(host) { return }
        // A chip is already asking about this host — don't stack offers.
        if let existing = pendingPasswordCaptureOffer,
           existing.tabID == tab.id && existing.host == host {
            return
        }

        let stored = savedPasswords.map {
            PasswordCapturePolicy.StoredCredential(
                id: $0.id,
                site: $0.site,
                username: $0.username,
                password: $0.password
            )
        }
        let kind = PasswordCapturePolicy.decide(
            stored: stored,
            submittedUsername: username,
            submittedPassword: password,
            host: host
        )
        switch kind {
        case .none:
            return
        case .save, .update:
            pendingPasswordCaptureOffer = PasswordCaptureOffer(
                host: host,
                tabID: tab.id,
                username: username,
                password: password,
                kind: kind
            )
        }
    }

    /// Persists the offered credential — the explicit Save/Update click is
    /// the consent, and the Keychain write is the only durable destination
    /// of the password.
    func acceptPasswordCaptureOffer() {
        guard let offer = pendingPasswordCaptureOffer else { return }
        pendingPasswordCaptureOffer = nil
        switch offer.kind {
        case .save:
            _ = savePassword(username: offer.username, password: offer.password, site: offer.host)
        case .update(let existingID):
            // Keep the credential's ORIGINAL site (Chrome behavior): a login
            // on `example.com` updating a credential stored for
            // `mail.example.com` must not silently re-home it to the
            // submission host — only the password (and username) change.
            let originalSite = savedPasswords.first(where: { $0.id == existingID })?.site ?? offer.host
            _ = updatePassword(id: existingID, username: offer.username, password: offer.password, site: originalSite)
        case .none:
            break
        }
    }

    /// Records the host durably (survives relaunch) and for the session, then
    /// clears the offer. Chrome's "Never for this site".
    func neverSavePasswordForHost(_ host: String) {
        sessionNeverSavePasswordHosts.insert(host)
        var durable = UserDefaults.standard.stringArray(forKey: Self.neverSavePasswordHostsKey) ?? []
        if !durable.contains(host) {
            durable.append(host)
            UserDefaults.standard.set(durable, forKey: Self.neverSavePasswordHostsKey)
        }
        pendingPasswordCaptureOffer = nil
    }

    /// Dismisses the offer without saving or recording anything ("Not now").
    func dismissPasswordCaptureOffer() {
        pendingPasswordCaptureOffer = nil
    }

    /// Drops any capture offer belonging to a tab (closed tab, navigation).
    func dropPasswordCaptureOffer(forTabID tabID: String) {
        if pendingPasswordCaptureOffer?.tabID == tabID {
            pendingPasswordCaptureOffer = nil
        }
    }
}
