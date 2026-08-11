//
//  BrowserState+Boosts.swift
//  Hive
//
//  Arc-style site Boosts: user-authored CSS injected per host. The pure
//  matching/injection contract lives in HiveCore (BoostMatcher); this
//  extension owns the boost list lifecycle and the injection call site.
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Boosts

@MainActor
extension BrowserState {

    /// Enabled boosts whose host pattern matches the given URL, in creation
    /// order. Used at load-completion to inject and by the UI to preview.
    func boosts(for url: URL?) -> [Boost] {
        boosts.filter { $0.isEnabled && BoostMatcher.matches(boostHost: $0.host, url: url) }
    }


    /// Injects every matching boost's CSS into a freshly-loaded page. Called
    /// alongside `applyCosmeticAdBlock` on load completion; each script is
    /// idempotent, so re-injection across navigations never stacks styles.
    /// Boost CSS is user-authored, so an invalid host silently matches nothing
    /// and no script is injected. Web-chrome pages (hive://) never receive
    /// boosts regardless of call site.
    func applyBoosts(on model: CefWebViewModel, url: URL) {
        guard httpOnlyURL(url) != nil else { return }
        let scripts = boosts(for: url).compactMap { BoostMatcher.injectScript(boost: $0) }
        for script in scripts {
            model.executeJavaScript(script)
        }
    }


    /// Adds a boost after validating host pattern and CSS content. Returns
    /// the created boost, or nil when the input is unusable (surfaced by the
    /// editor as an inline error). Arc allows one boost per site — adding a
    /// boost for a host that already has one edits the existing boost in
    /// place (re-enabling it) instead of stacking a second, since the matcher
    /// composes all matches.
    @discardableResult
    func addBoost(host: String, name: String, css: String) -> Boost? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = Boost(host: host, name: trimmedName.isEmpty ? host : trimmedName, css: css)
        guard candidate.hasValidHost, candidate.hasUsableCSS else { return nil }
        if let index = boosts.firstIndex(where: { $0.host == candidate.host }) {
            boosts[index].name = candidate.name
            boosts[index].css = candidate.css
            boosts[index].isEnabled = true
            return boosts[index]
        }
        boosts.append(candidate)
        return candidate
    }


    /// Updates an existing boost in place (editor save path). No-op when the
    /// edit makes the boost unusable.
    func updateBoost(_ boost: Boost) {
        guard let index = boosts.firstIndex(where: { $0.id == boost.id }),
              boost.hasValidHost, boost.hasUsableCSS else { return }
        boosts[index] = boost
    }


    func deleteBoost(id: UUID) {
        boosts.removeAll { $0.id == id }
    }


    func toggleBoostEnabled(id: UUID) {
        guard let index = boosts.firstIndex(where: { $0.id == id }) else { return }
        boosts[index].isEnabled.toggle()
        // Re-apply the active page so the toggle takes effect without a
        // reload (boosts are pure CSS — remove-then-inject is safe live).
        // Never in private browsing: user-authored site styles stay out of
        // private tabs entirely (see applyBoosts call-site guards).
        if let url = activeModel?.url, httpOnlyURL(url) != nil, activeTab?.isPrivate != true {
            applyBoosts(on: activeModel!, url: url)
        }
    }
}
