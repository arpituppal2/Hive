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
        // A fresh navigation attempt supersedes any prior load failure or
        // certificate error — the outcome re-reports via didFailLoad,
        // didEncounterCertificateError, or the successful commit.
        tabLoadErrors[tab.id] = nil
        tabCertificateErrors[tab.id] = nil
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


    /// Home button (Safari/Chrome parity): navigate the active tab to the
    /// home destination — the Morning Brief or hand-drawn start page per the
    /// openBriefOnNewTab preference, matching what a new tab would open.
    /// Private tabs always land on the start page: the brief is derived from
    /// browsing data and must never leak into a private tab.
    func goHome() {
        guard let tab = activeTab else { return }
        if tab.isPrivate {
            navigateToURL(URL(string: "\(Self.webChromeStartURL.absoluteString)?private=1")!)
        } else {
            navigateToURL(openBriefOnNewTab ? Self.webChromeBriefURL : Self.webChromeStartURL)
        }
    }

    func navigateToURL(_ requestedURL: URL) {
        guard let tab = activeTab else { return }
        // HTTPS-Only: upgrade plaintext navigations at the app-controlled entry
        // points (omnibox, floating bar, chrome-opened links). In-page link
        // clicks bypass this funnel (CEF exposes no before-browse hook), so a
        // page that still lands on http surfaces the warning banner instead.
        let effectiveURL = HTTPSOnlyPolicy.upgraded(
            requestedURL,
            enabled: isHTTPSOnlyEnabled,
            exceptions: httpsOnlyExceptions
        ) ?? requestedURL
        let navigationAttemptID = beginNavigationAttempt(for: tab)
        // Capture privacy from the tab that owns this navigation. The active-tab
        // projection can change before delayed CEF callbacks or child tasks run;
        // durable history/sync admission must never follow focus changes.
        let navigationTabIsPrivate = tab.isPrivate

        // A valid navigation supersedes transient feedback from an earlier
        // rejected address-bar submission, regardless of which browser surface
        // initiated this load.
        dismissNavigationBlockNotice()
        if let id = activeTabID {
            // The active tab's page changed — its pooled preview is stale.
            invalidatePreview(for: id)
        }
        tab.model.load(effectiveURL)
        // Web-chrome internal pages (hive://) are chrome, not content: no
        // history entry, no safe-browsing/translate lookups, no hot-memory
        // warm-up — a start page must never pollute the user's history.
        guard effectiveURL.scheme != "hive" else { return }
        checkSafeBrowsing(effectiveURL)
        checkTranslate(effectiveURL)
        // Track URL in browsing history immediately; title will be backfilled
        // when the page finishes loading via observeLoadCompletion.
        guard effectiveURL.absoluteString != "about:blank" else { return }
        let initialTitle = effectiveURL.host ?? effectiveURL.absoluteString
        let entry = HistoryItem(title: initialTitle, url: effectiveURL, visitedAt: Date(), faviconURL: tab.model.faviconURL)
        if !navigationTabIsPrivate {
            historyItems.append(entry)
            Task { @MainActor [weak self, weak tab] in
                guard let self, let tab, !tab.isPrivate else { return }
                await self.pushHistoryToCloud(entry)
            }
            if historyItems.count > 1000 { historyItems.removeFirst(100) }
            scheduleAutosave()
        }

        // Quiet background warm-up: track this page in hot memory at navigate
        // time, NOT just when the user asks. The second brain is warm before
        // it's needed — transparent when you don't need it, omniscient when
        // you do. Skipped in private browsing (memory must never persist
        // from private content).
        if !navigationTabIsPrivate {
            let nodeID = pageNodeID(for: effectiveURL.absoluteString)
            let expectedModel = tab.model
            let expectedTabID = tab.id
            Task { @MainActor [weak self] in
                guard let self,
                      self.activeTabID == expectedTabID,
                      self.navigationAttempts.isCurrent(tabID: expectedTabID, attemptID: navigationAttemptID),
                      let currentTab = self.tabs.first(where: { $0.id == expectedTabID }),
                      currentTab.model === expectedModel else { return }
                await self.hotMemory.didAccessNode(id: nodeID, sourceHint: "browsed",
                                                   label: effectiveURL.host ?? effectiveURL.absoluteString,
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
            url: effectiveURL
        )
    }


    /// Resolves omnibar input through HiveCore's single navigation policy.
    /// Unsafe explicit schemes are rejected rather than being sent to a search
    /// provider or passed directly to Chromium.
    func navigateToAddress(_ text: String) {
        // Chrome-style site keywords first: `yt kittens` searches YouTube via
        // its stored keyword, before the generic engine sees the text. The
        // shared siteSearchKeywords() helper keeps resolution and suggestions
        // on one list.
        if let keywordMatch = SiteSearchKeywordPolicy.keywordQuery(from: text, keywords: siteSearchKeywords()),
           let url = SiteSearchKeywordPolicy.searchURL(for: keywordMatch.query, keyword: keywordMatch.keyword) {
            navigateToURL(url)
            return
        }
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


    // MARK: - HTTPS-Only warning lifecycle

    /// Recomputes the HTTPS-Only banner for a tab after its URL changed or it
    /// became active. Only the active tab's warning renders; the banner tracks
    /// tab switches so the user always sees the current page's state. A nil
    /// URL (hibernated tab's blank model) clears the banner.
    func updateHTTPSOnlyNotice(for url: URL?, tabID: String) {
        guard tabID == activeTabID else { return }
        guard let url else {
            httpsOnlyNotice = nil
            return
        }
        if HTTPSOnlyPolicy.shouldWarn(
            for: url,
            enabled: isHTTPSOnlyEnabled,
            exceptions: httpsOnlyExceptions
        ) {
            if httpsOnlyNotice?.url != url {
                httpsOnlyNotice = HTTPSOnlyNotice(host: url.host ?? url.absoluteString, url: url)
            }
        } else {
            httpsOnlyNotice = nil
        }
    }

    /// Dismisses the banner (re-appears on the next plaintext load of the
    /// host while the mode is on — use "Load anyway" to persist).
    func dismissHTTPSOnlyNotice() {
        httpsOnlyNotice = nil
    }

    /// "Load anyway": remembers the host as an HTTPS-Only exception and
    /// dismisses. The host stays allowed on http until the user clears it.
    func allowPlaintextForCurrentHost() {
        defer { httpsOnlyNotice = nil }
        guard let notice = httpsOnlyNotice,
              let host = SiteMutePolicy.hostKey(for: notice.url) else { return }
        var exceptions = httpsOnlyExceptions
        exceptions.insert(host)
        httpsOnlyExceptions = exceptions
    }

    /// "Use HTTPS": navigates the active tab to the https version of the
    /// warned page.
    func useHTTPSNow() {
        guard let notice = httpsOnlyNotice else { return }
        httpsOnlyNotice = nil
        if let upgraded = HTTPSOnlyPolicy.upgraded(
            notice.url,
            enabled: true,
            exceptions: []
        ) {
            navigateToURL(upgraded)
        }
    }


    func goBack() {
        guard let tab = activeTab, !tab.isHibernated, tab.model.canGoBack else { return }
        // Move the top back entry to the forward stack before navigating so
        // the commit path (which would otherwise push it again) stays clean.
        if var back = tabNavBack[tab.id], let entry = back.first {
            back.removeFirst()
            tabNavBack[tab.id] = back.isEmpty ? nil : back
            var forward = tabNavForward[tab.id] ?? []
            forward.insert(entry, at: 0)
            tabNavForward[tab.id] = forward
        }
        let attemptID = beginNavigationAttempt(for: tab)
        let previousURL = tab.model.url
        tab.model.goBack()
        armNavigationObservation(for: tab, attemptID: attemptID, url: previousURL)
    }


    func goForward() {
        guard let tab = activeTab, !tab.isHibernated, tab.model.canGoForward else { return }
        // Mirror of goBack: the nearest forward entry becomes the new top of
        // the back stack once the load commits.
        if var forward = tabNavForward[tab.id], let entry = forward.first {
            forward.removeFirst()
            tabNavForward[tab.id] = forward.isEmpty ? nil : forward
            var back = tabNavBack[tab.id] ?? []
            back.insert(entry, at: 0)
            tabNavBack[tab.id] = back
        }
        let attemptID = beginNavigationAttempt(for: tab)
        let previousURL = tab.model.url
        tab.model.goForward()
        armNavigationObservation(for: tab, attemptID: attemptID, url: previousURL)
    }


    /// Records a committed navigation in the per-tab back stack. Called from
    /// the load-completion observation; CEF 148 exposes no entry-enumeration
    /// API, so committed loads are the source of truth for the back/forward
    /// menus. Newest first; a reload of the same URL is a no-op; any forward
    /// branch is discarded (a fresh navigation truncates forward, like every
    /// browser).
    func recordCommittedNavigation(for tabID: String, url: URL, title: String) {
        let absolute = url.absoluteString
        var back = tabNavBack[tabID] ?? []
        if back.first?.url.absoluteString == absolute { return }
        let label = title.isEmpty ? (url.host ?? absolute) : title
        back.insert(TabNavigationEntry(url: url, title: label), at: 0)
        if back.count > 30 { back.removeLast() }
        tabNavBack[tabID] = back
        tabNavForward[tabID] = nil
    }


    /// Loads a URL picked from the back/forward menu in the active tab
    /// (Chrome/Safari convention: jumping to a previous entry).
    ///
    /// Documented tradeoff: CEF 148 exposes only the singular visible-entry
    /// getter (no entry enumeration or `goToIndex`), so the jump is a fresh
    /// `load`, not a stack index move. Our tracked forward stack truncates
    /// like Chrome's, but CEF's internal history still holds the pre-jump
    /// entries — a later native back (⌘[ / the button) can land on pages the
    /// menu no longer lists. Accepted for this CEF version.
    func navigateFromHistoryMenu(to url: URL) {
        navigateToURL(url)
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

    /// Hard reload of the active tab, bypassing caches (⌥⌘R). Shares the same
    /// generation boundary as a plain reload so failed attempts are observed
    /// and reconciled identically.
    func reloadIgnoringCache() {
        guard let tab = activeTab, !tab.isHibernated else { return }
        let attemptID = beginNavigationAttempt(for: tab)
        let currentURL = tab.model.url
        tab.model.reloadIgnoringCache()
        armNavigationObservation(for: tab, attemptID: attemptID, url: currentURL)
    }

    func stop() { activeModel?.stopLoading() }

    // MARK: - Download control (Chrome / Safari / Arc parity)

    /// Pauses an active download through its live CEF controller. The state
    /// machine guards the action (only `.active` may pause); the next native
    /// snapshot reconciles the outcome.
    func pauseDownload(id: UUID) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }),
              let control = downloads[idx].downloadControl,
              downloads[idx].controlState.requestPause() != nil
        else { return }
        control.pause()
        armControlTimeout(id: id)
    }

    /// Resumes a paused download through its live CEF controller.
    func resumeDownload(id: UUID) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }),
              let control = downloads[idx].downloadControl,
              downloads[idx].controlState.requestResume() != nil
        else { return }
        control.resume()
        armControlTimeout(id: id)
    }

    /// Cancels an active download. The explicit user gesture is recorded on
    /// the row immediately so a late CEF update cannot turn the canceled row
    /// back into a completed one (the progress handler honors that flag).
    func cancelDownload(id: UUID) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }),
              let control = downloads[idx].downloadControl,
              !downloads[idx].isComplete
        else { return }
        downloads[idx].isCanceled = true
        control.cancel()
        downloadControlTimeouts[id]?.cancel()
        downloadControlTimeouts[id] = nil
    }

    private func armControlTimeout(id: UUID) {
        downloadControlTimeouts[id]?.cancel()
        downloadControlTimeouts[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled else { return }
            guard let idx = self.downloads.firstIndex(where: { $0.id == id }) else { return }
            // A request with no native confirmation within the bounded window
            // returns to the last actionable baseline — the user can try again.
            self.downloads[idx].controlState.timeoutPendingRequest()
            self.downloadControlTimeouts[id] = nil
        }
    }

    /// Removes all recorded browsing history and persists the mutation through
    /// the browser state's session boundary. Keeping this operation here avoids
    /// UI surfaces mutating the persisted session projection directly.
    @discardableResult
    func clearBrowsingHistory() -> Int {
        let decision = HistoryClearPolicy.decision(itemCount: historyItems.count)
        guard decision.shouldPersist else { return 0 }
        let removedIDs = historyItems.map(\.id)
        historyItems.removeAll(keepingCapacity: false)
        for id in removedIDs {
            enqueueSyncTombstone(kind: .history, recordID: id.uuidString)
        }
        scheduleAutosave()
        return decision.removedCount
    }


    /// Removes a single history entry (Chrome's per-item delete). The removal
    /// stages one sync tombstone keyed exactly like `clearBrowsingHistory` so
    /// peers converge on the delete without a full clear.
    func deleteHistoryItem(id: UUID) {
        guard let index = historyItems.firstIndex(where: { $0.id == id }) else { return }
        historyItems.remove(at: index)
        enqueueSyncTombstone(kind: .history, recordID: id.uuidString)
        scheduleAutosave()
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

    /// Removes a single download row from the list (Chrome's "Remove from
    /// list"). In-flight downloads stay — the user can cancel them via the
    /// row controls instead; removing them from view while they're still
    /// writing would hide a live operation.
    func removeDownload(id: UUID) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }),
              DownloadHistoryPolicy.isTerminal(
                  isComplete: downloads[idx].isComplete,
                  isCanceled: downloads[idx].isCanceled,
                  isInterrupted: downloads[idx].isInterrupted
              )
        else { return }
        downloads.remove(at: idx)
        scheduleAutosave()
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
        // Failed main-frame load: surface a branded error banner with the
        // failed URL and a Retry action (the CEF error page still renders in
        // the content area; the banner is the native reinforcement). Private
        // tabs report too — the failure itself is not browsing data.
        // Capture only the id, never the tab: the closure is stored ON the
        // tab's model, so capturing the tab (which holds the model strongly)
        // would create a model→closure→model cycle that leaks closed tabs.
        // Mirror the download-closure pattern of resolving through self.tabs.
        let tabID = tab.id
        tab.model.onLoadError = { [weak self] code, text, failedURL in
            guard let self,
                  let resolvedTab = self.tabs.first(where: { $0.id == tabID })
            else { return }
            guard let url = failedURL ?? resolvedTab.model.url else { return }
            self.tabLoadErrors[tabID] = LoadErrorNotice(
                tabID: tabID,
                code: code,
                text: text.isEmpty ? "Network error" : text,
                url: url
            )
            self.broadcastWebChromeState()
        }
        // Certificate failures: record them for the security popover and
        // cancel the load (CEF shows its own error page) unless the user has
        // already accepted this host this session — then allow it. Resolves
        // through self.tabs like the download closures to avoid a retain cycle.
        tab.model.onCertificateError = { [weak self] url, code in
            guard let self,
                  let resolvedTab = self.tabs.first(where: { $0.id == tabID })
            else { return false }
            guard let url = url ?? resolvedTab.model.url, let host = url.host else { return false }
            if self.certificateBypassHosts.contains(host.lowercased()) {
                return true
            }
            self.tabCertificateErrors[tabID] = CertificateErrorNotice(
                tabID: tabID,
                code: code,
                url: url
            )
            self.broadcastWebChromeState()
            return false
        }
        let model = tab.model

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

        model.onDownloadProgress = { [weak self] cefDownload, control in
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
            let wasComplete = d.isComplete
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
            // Chrome parity: announce a download the moment it completes,
            // even when Hive is backgrounded or the Downloads panel is closed.
            // Guarded on the false→true transition so repeated late callbacks
            // (or a row that was canceled then re-flagged) never re-post, and
            // on the user preference toggle.
            if d.isComplete && !wasComplete && self.downloadNotificationsEnabled {
                // Chrome behavior: banner only when Hive is backgrounded — the
                // in-app Downloads indicator is the feedback when the app is
                // frontmost. The dock bounce is the OS-level signal that needs
                // no notification permission and is likewise background-only.
                if !NSApplication.shared.isActive {
                    DockTileProgress.bounce()
                    DownloadNotifier.postCompletion(
                        fileName: d.suggestedName,
                        downloadID: d.id,
                        destinationURL: d.destinationURL
                    )
                }
            }
            d.destinationURL = cefDownload.fullPath ?? d.destinationURL
            // Live controller + pause/resume reconciliation: refresh the
            // stored handle and settle the request state machine against the
            // snapshot's paused bit (the UI already ran requestPause/
            // requestResume before invoking the CEF control). A pending
            // request is settled only by a native bit that CONFIRMS it — an
            // intermediate snapshot generated before CEF applied the command
            // must not silently drop the in-flight request (the machine's
            // bounded timeout remains the fallback).
            d.downloadControl = control
            switch d.controlState.state {
            case .pauseRequested where cefDownload.isPaused,
                 .resumeRequested where !cefDownload.isPaused,
                 .active, .paused:
                d.controlState.reconcile(nativeIsPaused: cefDownload.isPaused)
            default:
                break  // stale intermediate snapshot; stay pending
            }
            if d.isComplete || d.isCanceled || d.isInterrupted {
                // Terminal state is fully represented by the native snapshot;
                // the process-local controller is invalid from here on.
                d.controlState.resetToActive()
                d.downloadControl = nil
                self.downloadControlTimeouts[d.id]?.cancel()
                self.downloadControlTimeouts[d.id] = nil
            }
            self.downloads[idx] = d
            // Dock-tile progress (Safari/Chrome convention): the dock icon
            // shows the mean progress of the in-flight transfers and clears
            // when the last one reaches a terminal state. Recomputed from the
            // array so any terminal transition is reflected immediately.
            let inFlight = self.downloads.filter { !$0.isComplete && !$0.isCanceled && !$0.isInterrupted }
            DockTileProgress.update(
                fraction: inFlight.isEmpty
                    ? 0
                    : inFlight.reduce(0.0) { $0 + $1.progress } / Double(inFlight.count)
            )
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
            // peekPaneFrame (active tab OR split-secondary pane only);
            // autofill and password-capture reports are gated in their own
            // handlers (visible page + non-private tab + matching data).
            if message.hasPrefix("HIVE_MEDIA") {
                self.handleMediaConsoleMessage(message, from: model)
            } else if message.hasPrefix("HIVE_PIP") {
                self.handlePiPConsoleMessage(message, from: model)
            } else if message.hasPrefix("HIVE_AUTOFILL") {
                self.handleAutofillConsoleMessage(message, from: model)
            } else if message.hasPrefix("HIVE_PASSWORD_CAPTURE") {
                self.handlePasswordCaptureConsoleMessage(message, from: model)
            } else if message.hasPrefix("HIVE_FIND") {
                // Find-in-page match counter — active-tab gated inside.
                self.handleFindConsoleMessage(message, from: model)
            } else if message.hasPrefix("HIVE_READER_WORDS") {
                self.handleReaderWordCountConsoleMessage(message, from: model)
            } else {
                self.handlePageConsoleMessage(message, from: model)
            }
        }

        // --- External-scheme handoff (Chrome/Safari parity) ---
        // `mailto:`, `tel:`, and `sms:` links must open the default OS app, not
        // an error page. CEF's before-browse policy hook lets us cancel the
        // load and call NSWorkspace before the request is made. Private tabs
        // hand off identically — the URL leaves the browser either way, and
        // no browsing data is recorded for it.
        model.onNavigationPolicy = { [weak self] url, _, _ in
            guard ExternalSchemePolicy.shouldHandOff(url) else { return .allow }
            if let url {
                NSWorkspace.shared.open(url)
            }
            return .cancel
        }

        // --- Site permissions (Chrome parity) ---
        // Every CEF permission request routes through HiveCore's durable
        // per-site policy: stored grants auto-resolve, unresolved requests
        // surface as a banner prompt, benign classes (clipboard, storage
        // access) are granted quietly, and exotic classes are denied.
        // Private tabs always prompt and never persist their answers.
        let tabIsPrivate = tab.isPrivate
        // Pop-ups are governed by the stored per-site decision (not the CEF
        // permission prompt, which has no popup class). User-activated links
        // always open; script-created windows are suppressed when the site is
        // blocked. This is what makes the Site Security popover's "Pop-ups"
        // row a live control (SitePermissionPolicy.allowsNewWindow).
        model.onWindowOpen = { [weak self] request in
            guard let self else { return CefWindowOpenPolicy.defaultAction(for: request) }
            let host = request.targetURL?.host ?? ""
            let permission = self.permissionState(
                forHost: host,
                kind: .popups,
                isPrivate: tabIsPrivate
            )
            guard SitePermissionPolicy.allowsNewWindow(
                navigationType: request.userGesture ? .userActivatedLink : .scriptOrUnknown,
                permission: permission
            ) else {
                return .deny
            }
            return CefWindowOpenPolicy.defaultAction(for: request)
        }
        model.onPermissionPrompt = { [weak self] request, callback in
            guard let self else {
                callback.resolve(allow: false)
                return true
            }
            return self.handlePermissionRequest(
                request,
                callback: callback,
                tabID: tabID,
                isPrivate: tabIsPrivate
            )
        }
        // CEF dismisses a pending prompt when the page closes or navigates
        // away; drop the matching banner entry (its callback is released).
        model.onPermissionPromptDismissed = { [weak self] promptID in
            self?.dismissPermissionPrompt(promptID: promptID)
        }
        // Any main-frame navigation invalidates the page's pending requests
        // (media requests have no CEF dismissal notice, so the URL change is
        // the authoritative cleanup signal) and drops any autofill chip for
        // the page that just navigated away.
        model.onURLChanged = { [weak self] newURL in
            guard let self else { return }
            self.dropPendingPermissionPrompts(forTabID: tabID)
            self.dropAutofillSuggestion(forTabID: tabID)
            self.dropPasswordCaptureOffer(forTabID: tabID)
            // Apply per-site zoom when the page navigates to a known domain.
            if let url = newURL, url.scheme != "hive" {
                self.applySiteZoom(for: url, tabID: tabID)
            }
            // Re-apply a durable per-site mute when the page navigates onto a
            // muted host (Chrome/Safari "Mute Site" persistence).
            if let tab = self.tabs.first(where: { $0.id == tabID }) {
                self.applySiteMuteIfNeeded(for: tab)
            }
            // HTTPS-Only: surface a plaintext page via the warning banner (it
            // arrived through an in-page click we couldn't upgrade).
            if let url = newURL {
                self.updateHTTPSOnlyNotice(for: url, tabID: tabID)
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
