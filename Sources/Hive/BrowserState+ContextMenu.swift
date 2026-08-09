//
//  BrowserState+ContextMenu.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Native context menu (Chrome / Edge / Safari parity)
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + ContextMenu

@MainActor
extension BrowserState {


    /// Builds a fully custom right-click menu. Context-sensitive: link, image,
    /// selection, and editable-field variants, always ending with the Hive
    /// differentiator (Ask Hive about this page). Standard CEF items use their
    /// built-in IDs so CEF executes them; app actions use the user range.
    func buildContextMenu(_ menu: CefMenuModel, params: CefContextMenuParams) {
        menu.clear()

        menu.addItem(commandID: CefContextMenuCommand.reload.rawValue, title: "Reload")
        menu.addSeparator()

        if params.isEditable {
            menu.addItem(commandID: CefContextMenuCommand.undo.rawValue, title: "Undo")
            menu.addItem(commandID: CefContextMenuCommand.redo.rawValue, title: "Redo")
            menu.addSeparator()
            menu.addItem(commandID: CefContextMenuCommand.cut.rawValue, title: "Cut")
            menu.addItem(commandID: CefContextMenuCommand.copy.rawValue, title: "Copy")
            menu.addItem(commandID: CefContextMenuCommand.paste.rawValue, title: "Paste")
            menu.addItem(commandID: CefContextMenuCommand.selectAll.rawValue, title: "Select All")
            menu.addSeparator()
        }

        if httpOnlyURL(params.linkURL) != nil {
            menu.addItem(commandID: HiveContextMenuAction.openLinkInNewTab.rawValue, title: "Open Link in New Tab")
            menu.addItem(commandID: HiveContextMenuAction.openLinkInSplit.rawValue, title: "Open Link in Split View")
            menu.addItem(commandID: HiveContextMenuAction.copyLinkAddress.rawValue, title: "Copy Link Address")
            menu.addSeparator()
        }

        if params.mediaType == .image, httpOnlyURL(params.sourceURL) != nil {
            menu.addItem(commandID: HiveContextMenuAction.openImageInNewTab.rawValue, title: "Open Image in New Tab")
            menu.addItem(commandID: HiveContextMenuAction.copyImageAddress.rawValue, title: "Copy Image Address")
            menu.addItem(commandID: HiveContextMenuAction.saveImageAs.rawValue, title: "Save Image As…")
            menu.addSeparator()
        }

        // Selection actions only on non-editable nodes — in an editable field
        // the editing block above already covers Copy.
        let selection = params.selectionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !params.isEditable, !selection.isEmpty {
            menu.addItem(commandID: CefContextMenuCommand.copy.rawValue, title: "Copy")
            menu.addItem(commandID: HiveContextMenuAction.searchSelection.rawValue,
                         title: "Search \"\(truncatedSelection(selection))\" with \(searchEngine.rawValue)")
            menu.addItem(commandID: HiveContextMenuAction.askHiveSelection.rawValue, title: "Ask Hive about selection")
            menu.addSeparator()
        }

        // The Hive differentiator: every page menu ends with Ask Hive.
        menu.addItem(commandID: HiveContextMenuAction.askHivePage.rawValue, title: "Ask Hive about this page")
    }


    func handleContextMenuCommand(_ commandID: Int, params: CefContextMenuParams) {
        guard let action = HiveContextMenuAction(rawValue: commandID) else { return }
        switch action {
        case .openLinkInNewTab:
            if let link = httpOnlyURL(params.linkURL) { newTab(url: link, activate: false) }
        case .openLinkInSplit:
            if let link = httpOnlyURL(params.linkURL) {
                let tab = newTab(url: link, activate: false)
                splitActiveTab(with: tab.id)
            }
        case .copyLinkAddress:
            if let link = params.linkURL { copyToPasteboard(link.absoluteString) }
        case .openImageInNewTab:
            if let source = httpOnlyURL(params.sourceURL) { newTab(url: source, activate: false) }
        case .copyImageAddress:
            if let source = params.sourceURL { copyToPasteboard(source.absoluteString) }
        case .saveImageAs:
            if let source = httpOnlyURL(params.sourceURL) { saveImageAs(url: source) }
        case .searchSelection:
            let q = params.selectionText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty,
                  let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: searchEngine.searchURL + encoded)
            else { return }
            newTab(url: url, activate: false)
        case .askHiveSelection:
            let q = params.selectionText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return }
            askHive(q)
        case .askHivePage:
            askHive("Tell me about \(activeModel?.title ?? "this page")")
        }
    }


    /// http/https only — chrome pages and data: links never route to a new tab.
    func httpOnlyURL(_ url: URL?) -> URL? {
        guard let url, let scheme = url.scheme?.lowercased() else { return nil }
        return (scheme == "http" || scheme == "https") ? url : nil
    }


    func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }


    /// Saves an image to disk: fetches the bytes, shows an NSSavePanel, writes
    /// the file, and surfaces a completed item in the Downloads panel.
    /// CefKit exposes no startDownload, so this is the honest route.
    func saveImageAs(url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                let panel = NSSavePanel()
                panel.nameFieldStringValue = url.lastPathComponent.isEmpty ? "image" : url.lastPathComponent
                panel.message = "Save image from \(url.host ?? "the web")"
                guard panel.runModal() == .OK, let destination = panel.url else { return }
                try data.write(to: destination)
                var item = DownloadItem(suggestedName: destination.lastPathComponent, url: url)
                item.isComplete = true
                item.destinationURL = destination
                self.downloads.append(item)
                self.scheduleAutosave()
            } catch {
                // Quiet honest failure — the fetch or write failed. No toast
                // infra in HiveChromium; the image simply doesn't save.
                NSLog("[HiveContextMenu] Save image failed: \(error.localizedDescription)")
            }
        }
    }


    func truncatedSelection(_ s: String, limit: Int = 24) -> String {
        s.count <= limit ? s : String(s.prefix(limit)) + "…"
    }


    /// Opens the Gemini panel with a prompt (used by context-menu actions).
    func askHive(_ prompt: String) {
        geminiMessages.append(GeminiMessage(role: .user, text: prompt))
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isGeminiPanelOpen = true
        }
        generateOrchestratedResponse(role: .summarizer, intent: prompt, maxTokens: 256)
    }


    /// Polls a model until its first committed load finishes, then injects
    /// both page probes (link-hover + media-state). Runs for every tab (new,
    /// duplicate, split, woken) so peeks and the mini-player work on
    /// hibernated tabs the moment they wake — paths that never go through
    /// navigateToURL. The probes self-guard, so re-injection across
    /// navigations is safe (each navigation is a fresh JS context).
    func armPageProbes(on model: CefWebViewModel, tabID: String) {
        let key = "probe-\(tabID)"
        tabObservationTasks[key]?.cancel()
        tabObservationTasks[key] = Task { @MainActor [weak self, weak model] in
            try? await Task.sleep(for: .milliseconds(300))
            for _ in 0..<60 { // poll up to 30 seconds for the first commit
                guard let self, !Task.isCancelled, let model else {
                    self?.tabObservationTasks.removeValue(forKey: key)
                    return
                }
                if !model.isLoading {
                    let scheme = model.url?.scheme?.lowercased()
                    if scheme == "http" || scheme == "https" {
                        model.executeJavaScript(Self.linkPeekProbeScript)
                        model.executeJavaScript(Self.mediaStateProbeScript)
                    }
                    // The browser is attached now — re-apply this tab's
                    // persisted zoom (wake/duplicate/split paths never go
                    // through selectTab).
                    if let tab = self.tabs.first(where: { $0.id == tabID }) {
                        self.applyStoredZoom(for: tab)
                    }
                    self.tabObservationTasks.removeValue(forKey: key)
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
            self?.tabObservationTasks.removeValue(forKey: key)
        }
    }


    /// Best-effort polls a specific browser model for title updates after
    /// navigation. Completion is accepted only after this observer samples
    /// `isLoading == true` and then `false`; an engine callback is still needed
    /// for deterministic short-load coverage. Captures the model reference
    /// directly so tab switches cannot redirect the poll to another tab.
    func observeLoadCompletion(
        entryID: UUID?,
        url: URL?,
        tabID: String,
        attemptID: UUID,
        model: CefWebViewModel
    ) {
        let key = "navigation-\(tabID)"
        tabObservationTasks[key]?.cancel()
        tabObservationTasks[key] = Task { @MainActor [weak self, weak model] in
            try? await Task.sleep(for: .milliseconds(500))
            var loadObservation = NavigationLoadObservation()
            var healthObservation = NavigationHealthObservation()
            for _ in 0..<60 { // poll up to 30 seconds
                guard let self, !Task.isCancelled,
                      let model else {
                    self?.tabObservationTasks.removeValue(forKey: key)
                    return
                }
                guard self.navigationAttempts.isCurrent(tabID: tabID, attemptID: attemptID),
                      let currentTab = self.tabs.first(where: { $0.id == tabID }),
                      currentTab.model === model else {
                    self.tabObservationTasks.removeValue(forKey: key)
                    return
                }
                let currentlyLoading = model.isLoading
                let didComplete = loadObservation.observe(isLoading: currentlyLoading)
                _ = healthObservation.observe(isLoading: currentlyLoading)
                guard !didComplete else {
                    // Page finished loading — backfill title, and drop any
                    // pooled peek preview of this tab: the page changed
                    // (chrome-initiated or redirect), so a stale preview
                    // would misrepresent the tab. The preview model's own
                    // loads never touch tab hooks, so no feedback loop.
                    self.invalidatePreview(for: tabID)
                    // Re-inject the link-hover probe: every navigation creates
                    // a fresh JS context, so the probe must be re-armed. Only
                    // real http(s) pages (never chrome/blank pages).
                    let completedURL = model.url ?? url
                    if let completedURL,
                       (completedURL.scheme?.lowercased() == "http" || completedURL.scheme?.lowercased() == "https") {
                        model.executeJavaScript(Self.linkPeekProbeScript)
                        model.executeJavaScript(Self.mediaStateProbeScript)
                    }
                    // Zoom is sticky per tab across navigations (Chrome-like).
                    self.applyStoredZoom(for: currentTab)
                    let title = model.title
                    if let entryID,
                       let completedURL,
                       !title.isEmpty,
                       let idx = self.historyItems.lastIndex(where: { $0.id == entryID }) {
                        let currentFavicon = self.historyItems[idx].faviconURL ?? model.faviconURL
                        self.historyItems[idx] = HistoryItem(id: entryID, title: title, url: completedURL, visitedAt: self.historyItems[idx].visitedAt, faviconURL: currentFavicon)
                        self.scheduleAutosave()
                    }
                    // Hot-memory title backfill: the warm-up at navigate time
                    // stamped url.host as a placeholder label (the real title
                    // wasn't known yet). Now that the page finished loading,
                    // enrich the hot entry so context assembly shows "Swift 6
                    // Concurrency Guide", not "example.com". The node ID
                    // convention matches the warm-up sites (page-<hash>);
                    // didAccessNode enriches the existing entry in place.
                    let sourceTab = self.tabs.first(where: { $0.model === model })
                    if let completedURL,
                       sourceTab?.isPrivate != true,
                       !title.isEmpty {
                        let nodeID = pageNodeID(for: completedURL.absoluteString)
                        await self.hotMemory.didAccessNode(id: nodeID, sourceHint: "browsed",
                                                           label: title,
                                                           workspaceID: sourceTab?.workspaceID.uuidString ?? self.currentWorkspaceID.uuidString,
                                                       profileID: sourceTab?.profileID.uuidString ?? self.currentProfileID.uuidString)
                    }
                    self.tabObservationTasks.removeValue(forKey: key)
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard !Task.isCancelled,
                  self?.navigationAttempts.isCurrent(tabID: tabID, attemptID: attemptID) == true,
                  let self,
                  let currentTab = self.tabs.first(where: { $0.id == tabID }),
                  currentTab.model === model,
                  !currentTab.isPrivate,
                  let liveModel = model,
                  let stalledURL = url ?? liveModel.url else {
                self?.tabObservationTasks.removeValue(forKey: key)
                return
            }
            if healthObservation.timeOut() {
                self.navigationHealthNotice = NavigationHealthNotice(tabID: tabID, url: stalledURL)
            }
            self.tabObservationTasks.removeValue(forKey: key)
        }
    }

    func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            if !self.saveSession() {
                self.reportSessionPersistenceFailure()
            }
        }
    }


    /// Saves session immediately, flushes hot memory to disk, and quits.
    /// Called from Cmd+Q. Async so the hot-memory flush completes before
    /// termination — otherwise the last seconds of memory would be lost.
    func saveNowAndQuit() async {
        autosaveTask?.cancel()
        if !saveSession(isCleanExit: true) {
            reportSessionPersistenceFailure()
        }
        await hotMemory.saveNow()
        NSApp.terminate(nil)
    }
}
