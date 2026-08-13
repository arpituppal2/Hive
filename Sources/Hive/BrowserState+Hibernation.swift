//
//  BrowserState+Hibernation.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Tab Hibernation
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Hibernation

@MainActor
extension BrowserState {


    func startHibernationTimer() {
        hibernationTask?.cancel()
        hibernationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, !Task.isCancelled else { return }
                self.runHibernationPass()
            }
        }
    }


    func runHibernationPass() {
        guard isMemorySaverEnabled else { return }
        let now = Date()
        // Download ownership is intentionally runtime-only. Terminal history has
        // no tab association, and an in-flight paused download still needs its
        // browser context alive so a later resume is not silently broken.
        let activeDownloadTabIDs = Set(downloads.lazy
            .filter { !$0.isComplete && !$0.isCanceled && !$0.isInterrupted }
            .compactMap(\.originatingTabID))

        // Keep the decision in the pure adapter. The CEF-specific work below
        // only tears down the browser instances the adapter has approved.
        let candidates = tabs.compactMap { tab -> HibernationAdapter.TabCandidate? in
            guard !tab.isHibernated, tab.id != splitSecondaryTabID,
                  HibernationAdapter.shouldIncludeInCandidateSet(
                      tabID: tab.id,
                      isMRU: mruTabIDs.contains(tab.id),
                      collapsedGroupTabIDs: collapsedGroupTabIDs
                  ) else { return nil }
            let pageURL = HibernationAdapter.effectiveWakeURL(
                currentURL: tab.model.url,
                savedURL: tab.savedURL
            )
            let hasPage = pageURL != nil
            return HibernationAdapter.TabCandidate(
                id: tab.id,
                workspaceID: tab.workspaceID,
                isPinned: tab.isPinned,
                isEssential: tab.isEssential,
                hasPage: hasPage,
                lastAccessed: tab.lastAccessed,
                // Internal pages (hive://, about:, chrome:) never auto-hibernate;
                // the pure adapter decides via isProtectedScheme. Media-capture
                // and form-entry signals become live when CEF exposes them.
                urlScheme: pageURL?.scheme
            )
        }
        let approvedIDs = HibernationAdapter.evaluate(
            tabs: candidates,
            activeTabID: activeTabID,
            activeWorkspaceID: currentWorkspaceID,
            mediaPlayingTabIDs: mediaPlayingTabIDs,
            activeDownloadTabIDs: activeDownloadTabIDs,
            collapsedGroupTabIDs: collapsedGroupTabIDs,
            now: now
        )

        var didHibernate = false
        for tab in tabs where approvedIDs.contains(tab.id) {
            didHibernate = hibernateTab(tab) || didHibernate
        }
        // Hibernation changes the durable tab projection (`isHibernated` and
        // `savedURL`). Persist this lifecycle-critical transition immediately;
        // a debounced autosave could lose the cold-tab marker during a crash or
        // the forced-termination path used by the recovery smoke test.
        if didHibernate {
            if !saveSession() {
                // Latch the failure immediately so the browser cannot imply
                // that the cold-tab transition is durable. Keep the normal
                // debounced retry as a recovery path; the renderer is already
                // closed, so never discard that retry opportunity.
                reportSessionPersistenceFailure()
                scheduleAutosave()
            }
        }
    }


    /// Closes the CEF renderer for a tab, saving memory. The tab's URL is preserved for wake.
    /// `browser?.close()` triggers `browserDidClose` on the delegate, which calls `detach()` internally.
    /// Returns true only when this call changed the durable tab lifecycle state.
    @discardableResult
    func hibernateTab(_ tab: Tab) -> Bool {
        // Private tabs use an ephemeral profile and must never enter a
        // renderer-closing hibernation path that could preserve state for a
        // later wake or session projection.
        guard !tab.isPrivate, !tab.isHibernated else { return false }
        navigationAttempts.invalidate(tabID: tab.id)
        tabObservationTasks["navigation-\(tab.id)"]?.cancel()
        guard let wakeURL = HibernationAdapter.effectiveWakeURL(
            currentURL: tab.model.url,
            savedURL: tab.savedURL
        ) else {
            // Never convert a transiently blank renderer into a cold tab that
            // can only wake to about:blank. The candidate should normally have
            // been filtered earlier; this guard is defense in depth at the
            // destructive lifecycle boundary.
            return false
        }
        tab.savedURL = wakeURL
        tab.model.browser?.close()
        tab.isHibernated = true
        // The browser is closed — playback is gone. Drop media tracking and
        // any mini-player pointing at this tab so a dead card never lingers.
        mediaPlayingTabIDs.remove(tab.id)
        mediaVideoPlayingTabIDs.remove(tab.id)
        if miniPlayerTabID == tab.id { miniPlayerTabID = nil }
        return true
    }


    /// Re-creates the CEF renderer for a previously hibernated tab and re-wires hooks.
    func wakeTab(_ tab: Tab) {
        let url = tab.savedURL
        var opts = CefBrowserOptions()
        opts.profile = tab.isPrivate ? CefProfile.incognito() : cefProfile(for: tab.workspaceID)
        // Hibernation invalidated the previous generation. Issue a fresh
        // boundary for the newly-created model before its initial load starts.
        let attemptID = beginNavigationAttempt(for: tab)
        tab.model = CefWebViewModel(url: url, options: opts)
        tab.isHibernated = false
        tab.lastAccessed = Date()
        wireTabHooks(tab)
        armNavigationObservation(for: tab, attemptID: attemptID, url: url)
    }
}
