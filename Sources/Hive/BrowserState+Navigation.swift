//
//  BrowserState+Navigation.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Navigation | - Tab hooks (downloads, history backfill)
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Navigation

@MainActor
extension BrowserState {


    // MARK: - Navigation

    /// Opens a URL the model suggested. The click is the consent, so this
    /// navigates immediately — but the navigation is still recorded to the
    /// ledger: a model-suggested action must leave provenance even when the
    /// flow is frictionless (no second approval dialog for a user click).
    func openSuggestedURL(_ url: URL) {
        navigateToURL(url)
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.recordAuditEvent(EventLedgerStore.LedgerEvent(
                id: UUID().uuidString,
                timestamp: Date(),
                actor: "user",
                intent: "Open model-suggested URL",
                actionKind: .browserNavigate,
                actionPreview: url.absoluteString,
                trustLevel: .t3,
                policyDecision: .allowed,
                consentState: .approved,
                contextIDs: [],
                environment: "swift-6",
                result: .success
            ))
        }
    }


    /// Starts a tab-scoped navigation generation and cancels the previous
    /// completion observer. Every load-starting path must use this boundary so
    /// an older CEF callback cannot publish state after a newer navigation.
    @discardableResult
    func beginNavigationAttempt(for tab: Tab) -> UUID {
        let attemptID = navigationAttempts.issue(for: tab.id)
        tabObservationTasks["navigation-\(tab.id)"]?.cancel()
        if navigationHealthNotice?.tabID == tab.id {
            navigationHealthNotice = nil
        }
        return attemptID
    }


    func armNavigationObservation(
        for tab: Tab,
        attemptID: UUID,
        entryID: UUID? = nil,
        url: URL? = nil
    ) {
        observeLoadCompletion(
            entryID: entryID,
            url: url ?? tab.model.url,
            tabID: tab.id,
            attemptID: attemptID,
            model: tab.model
        )
    }


    func navigateToURL(_ url: URL) {
        guard let tab = activeTab else { return }
        let navigationAttemptID = beginNavigationAttempt(for: tab)

        // A valid navigation supersedes transient feedback from an earlier
        // rejected address-bar submission, regardless of which browser surface
        // initiated this load.
        dismissNavigationBlockNotice()
        if let id = activeTabID {
            // The active tab's page changed — its pooled preview is stale.
            invalidatePreview(for: id)
        }
        tab.model.load(url)
        // Web-chrome internal pages (hive://) are chrome, not content: no
        // history entry, no safe-browsing/translate lookups, no hot-memory
        // warm-up — a start page must never pollute the user's history.
        guard url.scheme != "hive" else { return }
        checkSafeBrowsing(url)
        checkTranslate(url)
        // Track URL in browsing history immediately; title will be backfilled
        // when the page finishes loading via observeLoadCompletion.
        guard url.absoluteString != "about:blank" else { return }
        let initialTitle = url.host ?? url.absoluteString
        let entry = HistoryItem(title: initialTitle, url: url, visitedAt: Date(), faviconURL: activeModel?.faviconURL)
        if !isPrivateBrowsing {
            historyItems.append(entry)
            if historyItems.count > 1000 { historyItems.removeFirst(100) }
            scheduleAutosave()
        }

        // Quiet background warm-up: track this page in hot memory at navigate
        // time, NOT just when the user asks. The second brain is warm before
        // it's needed — transparent when you don't need it, omniscient when
        // you do. Skipped in private browsing (memory must never persist
        // from private content).
        if !isPrivateBrowsing {
            let nodeID = pageNodeID(for: url.absoluteString)
            let expectedModel = tab.model
            let expectedTabID = tab.id
            Task { @MainActor [weak self] in
                guard let self,
                      self.activeTabID == expectedTabID,
                      self.navigationAttempts.isCurrent(tabID: expectedTabID, attemptID: navigationAttemptID),
                      let currentTab = self.tabs.first(where: { $0.id == expectedTabID }),
                      currentTab.model === expectedModel else { return }
                await self.hotMemory.didAccessNode(id: nodeID, sourceHint: "browsed",
                                                   label: url.host ?? url.absoluteString,
                                                   workspaceID: self.currentWorkspaceID.uuidString,
                                                       profileID: self.currentProfileID.uuidString)
                guard self.activeTabID == expectedTabID,
                      self.navigationAttempts.isCurrent(tabID: expectedTabID, attemptID: navigationAttemptID),
                      let currentTab = self.tabs.first(where: { $0.id == expectedTabID }),
                      currentTab.model === expectedModel else { return }
                if let ctx = self.buildPageContext() {
                    await self.hotMemory.setCurrentPage(ctx, nodeID: nodeID)
                }
            }
        }

        // Backfill real title when the page loads — capture the model
        // reference so we keep watching the right browser even after tab switches.
        armNavigationObservation(
            for: tab,
            attemptID: navigationAttemptID,
            entryID: entry.id,
            url: url
        )
    }


    /// Resolves omnibar input through HiveCore's single navigation policy.
    /// Unsafe explicit schemes are rejected rather than being sent to a search
    /// provider or passed directly to Chromium.
    func navigateToAddress(_ text: String) {
        let engine = SearchEngineKind.resolve(searchEngine.rawValue)
        switch OmnibarInput.resolve(text, engine: engine) {
        case .empty:
            return
        case .navigate(let url), .search(let url):
            navigateToURL(url)
        case .blocked(let scheme):
            // Never coerce a blocked scheme into a remote search or a
            // privileged Chromium load. Feedback stays local to the browser
            // chrome and expires automatically.
            showNavigationBlockNotice(for: scheme)
            return
        }
    }


    func goBack() {
        guard let tab = activeTab, !tab.isHibernated else { return }
        let attemptID = beginNavigationAttempt(for: tab)
        let previousURL = tab.model.url
        tab.model.goBack()
        armNavigationObservation(for: tab, attemptID: attemptID, url: previousURL)
    }


    func goForward() {
        guard let tab = activeTab, !tab.isHibernated else { return }
        let attemptID = beginNavigationAttempt(for: tab)
        let previousURL = tab.model.url
        tab.model.goForward()
        armNavigationObservation(for: tab, attemptID: attemptID, url: previousURL)
    }


    /// Reloads a specific tab through the same generation boundary used by
    /// address-bar navigation. Context-menu reloads must not bypass the guard.
    func reloadTab(id: String) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        if tab.isHibernated {
            wakeTab(tab)
            return
        }
        let attemptID = beginNavigationAttempt(for: tab)
        let currentURL = tab.model.url
        tab.model.reload()
        armNavigationObservation(for: tab, attemptID: attemptID, url: currentURL)
    }


    func reload() {
        guard let activeTabID else { return }
        reloadTab(id: activeTabID)
    }

    func stop() { activeModel?.stopLoading() }

    /// CefKit currently exposes immutable download snapshots rather than a
    /// supported pause/resume/cancel controller. Active downloads therefore
    /// remain observational; terminal state is reconciled from native progress
    /// callbacks and only the source-reopen path is offered after interruption.

    /// Removes all recorded browsing history and persists the mutation through
    /// the browser state's session boundary. Keeping this operation here avoids
    /// UI surfaces mutating the persisted session projection directly.
    @discardableResult
    func clearBrowsingHistory() -> Int {
        let decision = HistoryClearPolicy.decision(itemCount: historyItems.count)
        guard decision.shouldPersist else { return 0 }
        historyItems.removeAll(keepingCapacity: false)
        scheduleAutosave()
        return decision.removedCount
    }


    /// Removes one terminal download from the durable history list. Active
    /// transfers are never removable through a history action; their lifecycle
    /// remains owned by the CEF download callbacks.
    @discardableResult
    func removeDownloadFromHistory(id: UUID) -> Bool {
        guard let index = downloads.firstIndex(where: { $0.id == id }),
              DownloadHistoryPolicy.shouldRemoveFromHistory(
                  id: downloads[index].id,
                  requestedID: id,
                  isComplete: downloads[index].isComplete,
                  isCanceled: downloads[index].isCanceled,
                  isInterrupted: downloads[index].isInterrupted
              ) else { return false }
        downloads.remove(at: index)
        scheduleAutosave()
        return true
    }


    /// Clears only finished download history (completed, canceled, or
    /// interrupted) and persists the mutation once. Returning the count keeps
    /// the operation observable for future audit/UI feedback without exposing
    /// the browser's process-local controllers.
    @discardableResult    func clearFinishedDownloads() -> Int {
        let before = downloads.count
        downloads.removeAll {
            DownloadHistoryPolicy.isTerminal(
                isComplete: $0.isComplete,
                isCanceled: $0.isCanceled,
                isInterrupted: $0.isInterrupted
            )
        }
        let removed = before - downloads.count
        if removed > 0 {
            scheduleAutosave()
        }
        return removed
    }


    /// Opens the sanitized source URL for a terminal download in a new tab.
    ///
    /// This is deliberately not called `retryDownload`: persisted download rows
    /// have no live CEF controller, and the history URL intentionally omits
    /// query, fragment, and credential components. Opening the retained source
    /// gives the user a truthful recovery path without claiming resumability or
    /// silently navigating the current page.
    func openDownloadSource(id: UUID) {
        guard let download = downloads.first(where: { $0.id == id }),
              download.isInterrupted,
              let scheme = download.url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              download.url.host != nil else { return }

        // Re-apply the history sanitizer at the action boundary. A download
        // can interrupt before the session writer runs, so an in-memory row
        // must not be trusted merely because persisted rows are sanitized.
        let safeURL = TerminalDownloadRecord(
            id: download.id,
            suggestedName: download.suggestedName,
            url: download.url,
            progress: download.progress,
            isInterrupted: true
        ).url
        guard let safeScheme = safeURL.scheme?.lowercased(),
              safeScheme == "http" || safeScheme == "https",
              safeURL.host != nil else { return }
        newTab(url: safeURL, activate: true)
    }


    /// Wires CEF download hooks and history-title observation on a tab.
    func wireTabHooks(_ tab: Tab) {
        let model = tab.model
        let tabID = tab.id

        // --- Download hooks ---
        model.onDownloadDecision = { [weak self] cefDownload, suggestedName in
            guard let self else { return .deny }
            var item = DownloadItem(
                suggestedName: suggestedName,
                url: cefDownload.url ?? URL(string: "about:blank")!,
                originatingTabID: tabID
            )
            item.cefID = cefDownload.id
            self.downloads.append(item)
            return .allow(destination: nil)
        }

        model.onDownloadProgress = { [weak self] cefDownload in
            guard let self,
                  let idx = self.downloads.firstIndex(where: { $0.cefID == cefDownload.id })
            else { return }
            var d = self.downloads[idx]
            if cefDownload.totalBytes > 0 {
                // CEF reports transport counters, not a UI-safe fraction. A
                // late/out-of-order callback can briefly exceed the total or
                // produce a negative value; never let that escape into the
                // progress bar or persisted terminal history.
                let fraction = Double(cefDownload.receivedBytes) / Double(cefDownload.totalBytes)
                d.progress = min(max(fraction, 0), 1)
            }
            // A user cancellation wins over a late CEF update. Do not turn a
            // canceled row back into a completed row, and never expose a
            // process-local controller after a terminal transition.
            let wasExplicitlyCanceled = d.isCanceled
            d.isComplete = (wasExplicitlyCanceled || d.isInterrupted) ? false : cefDownload.isComplete
            if wasExplicitlyCanceled {
                // A user cancellation wins over every late CEF update.
                d.isCanceled = true
                d.isInterrupted = false
            } else if cefDownload.isCanceled && !cefDownload.isComplete {
                // CefSwift currently combines `is_canceled` and
                // `is_interrupted`. Without an explicit user gesture, retain
                // the honest coarse state rather than calling it "Canceled".
                d.isCanceled = false
                d.isInterrupted = true
            } else {
                d.isCanceled = false
                d.isInterrupted = false
            }
            d.destinationURL = cefDownload.fullPath ?? d.destinationURL
            if d.isComplete || d.isCanceled || d.isInterrupted {
                // Terminal state is fully represented by the native snapshot;
                // there is no process-local control state to reconcile.
            }
            self.downloads[idx] = d
            // Persist terminal history promptly. In-flight rows remain
            // ephemeral and are never written as resumable downloads.
            if d.isComplete || d.isCanceled || d.isInterrupted {
                self.scheduleAutosave()
            }
        }

        // --- Link-hover peek bridge ---
        // The page's injected probe reports hovered links via console messages
        // (`HIVE_LINK_PEEK|<url>|<x>|<y>` / `HIVE_LINK_CLEAR`). Gate strictly
        // on the visible page's model so background pages can't drive the UI.
        model.onConsoleMessage = { [weak self, weak model] message in
            guard let self, let model else { return }
            // Media messages come from ANY tab (a background tab's playback
            // state matters — that's what drives the auto mini-player); link
            // messages are visibility-gated by handlePageConsoleMessage via
            // peekPaneFrame (active tab OR split-secondary pane only).
            if message.hasPrefix("HIVE_MEDIA") {
                self.handleMediaConsoleMessage(message, from: model)
            } else if message.hasPrefix("HIVE_PIP") {
                self.handlePiPConsoleMessage(message, from: model)
            } else {
                self.handlePageConsoleMessage(message, from: model)
            }
        }

        // --- Native context menu (Chrome parity) ---
        // Rebuilds the default menu with page/link/image/selection actions.
        // Standard command IDs (reload, copy, paste, …) are left for CEF's
        // built-in execution (returning false from the command handler);
        // app-defined actions use the user command range (26500+).
        model.onConfigureContextMenu = { [weak self] menu, params in
            guard let self else { return }
            self.buildContextMenu(menu, params: params)
        }
        model.onContextMenuCommand = { [weak self] commandID, params in
            guard let self else { return false }
            if CefMenuCommandRange.isUserCommand(commandID) {
                self.handleContextMenuCommand(commandID, params: params)
                return true
            }
            // Standard CEF commands (reload, copy, paste, select all, …) —
            // let CEF execute its built-in behavior.
            return false
        }

        // Arm both page probes (link-hover + media-state) for THIS model's
        // first committed load. Every navigation re-arms via
        // observeLoadCompletion (fresh JS context each time); this covers the
        // paths that never call navigateToURL — waking a hibernated tab,
        // split/duplicate — so peeks and the mini-player work the moment a
        // tab becomes visible again.
        armPageProbes(on: model, tabID: tabID)

        // --- CDP / Agentic browsing bridge ---
        // When this tab's CEF browser is created (lazily by CefWebView),
        // wire it to the CDP client so the AI can drive the page via
        // the DevTools protocol. Re-wired on every browser attach so
        // hibernation cycles (tab → sleep → wake → new browser) stay
        // connected without manual intervention.
        model.onBrowserAttached = { [weak self] browser in
            guard let self else { return }
            // Only wire if this tab is the active one — background tabs
            // don't need CDP access.
            if self.activeTabID == tabID {
                self.wireCDP(to: browser)
            }
        }
        // If the browser is already attached (e.g. this tab is being
        // duplicated from a live tab), wire CDP immediately.
        if let browser = model.browser, activeTabID == tabID {
            wireCDP(to: browser)
        }
    }
}
