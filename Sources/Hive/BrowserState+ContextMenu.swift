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
import UniformTypeIdentifiers


// MARK: - BrowserState + ContextMenu

@MainActor
extension BrowserState {


    /// Builds a fully custom right-click menu. Context-sensitive: link, image,
    /// selection, and editable-field variants, always ending with the Hive
    /// differentiator (Ask Hive about this page). Standard CEF items use their
    /// built-in IDs so CEF executes them; app actions use the user range.
    func buildContextMenu(_ menu: CefMenuModel, params: CefContextMenuParams) {
        menu.clear()

        // Chrome/Safari parity: navigation entries head the menu. CEF can't
        // gray items, so Back/Forward appear only when the active tab actually
        // has history — a dead Back entry would be worse than none.
        // Standard command IDs, so CEF executes the navigation itself.
        if activeModel?.canGoBack == true {
            menu.addItem(commandID: CefContextMenuCommand.back.rawValue, title: "Back")
        }
        if activeModel?.canGoForward == true {
            menu.addItem(commandID: CefContextMenuCommand.forward.rawValue, title: "Forward")
        }
        if activeModel?.canGoBack == true || activeModel?.canGoForward == true {
            menu.addSeparator()
        }

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
                         title: "Search \"\(truncatedSelection(selection))\" with \(searchEngineDisplayName)")
            menu.addItem(commandID: HiveContextMenuAction.askHiveSelection.rawValue, title: "Ask Hive about selection")
            menu.addSeparator()
        }

        // Arc-parity Boost: any real web page can get a site style.
        if httpOnlyURL(activeModel?.url) != nil {
            menu.addItem(commandID: HiveContextMenuAction.createBoostForPage.rawValue, title: "Boost This Site…")
            // Safari-parity Reading List: save the current page for later, or
            // remove it when it's already saved (menu reflects live state).
            // Private tabs never offer it — a private page leaves no durable
            // trace, so a dead menu item would be worse than none.
            if activeTab?.isPrivate != true {
                if isInReadingList(activeModel?.url) {
                    menu.addItem(commandID: HiveContextMenuAction.removeFromReadingList.rawValue, title: "Remove from Reading List")
                } else {
                    menu.addItem(commandID: HiveContextMenuAction.addToReadingList.rawValue, title: "Add to Reading List")
                }
                // Arc-parity Pinned Apps: pin the current page as a quick-launch
                // app, or unpin it when it's already pinned (state-aware menu).
                if isPinnedWebApp(activeModel?.url) {
                    menu.addItem(commandID: HiveContextMenuAction.removeFromPinnedApps.rawValue, title: "Remove from Pinned Apps")
                } else {
                    menu.addItem(commandID: HiveContextMenuAction.addToPinnedApps.rawValue, title: "Add to Pinned Apps")
                }
            }
        }

        // Chrome/Arc parity: capture the current page from any web context menu.
        if httpOnlyURL(activeModel?.url) != nil {
            menu.addItem(commandID: HiveContextMenuAction.capturePageScreenshot.rawValue, title: "Take Screenshot…")
            menu.addItem(commandID: HiveContextMenuAction.copyPageScreenshot.rawValue, title: "Copy Screenshot")
            // Chrome/Safari parity: full-page capture of the whole scrollable
            // document (Safari's "full page" screenshot).
            menu.addItem(commandID: HiveContextMenuAction.captureFullPageScreenshot.rawValue, title: "Capture Full Page…")
            menu.addItem(commandID: HiveContextMenuAction.copyFullPageScreenshot.rawValue, title: "Copy Full Page")
            menu.addItem(commandID: HiveContextMenuAction.copyPageURL.rawValue, title: "Copy Page URL")
        }
        // Arc parity: copy every open tab URL in this workspace.
        if httpOnlyURL(activeModel?.url) != nil, !tabs.isEmpty {
            menu.addItem(commandID: HiveContextMenuAction.copyAllTabURLs.rawValue,
                         title: "Copy All Tab URLs")
            menu.addItem(commandID: HiveContextMenuAction.copyAllTabsMarkdown.rawValue,
                         title: "Copy All Tabs as Markdown")
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
            guard !q.isEmpty, let url = searchURL(for: q)
            else { return }
            newTab(url: url, activate: false)
        case .askHiveSelection:
            let q = params.selectionText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return }
            askHive(q)
        case .askHivePage:
            askHive("Tell me about \(activeModel?.title ?? "this page")")
        case .createBoostForPage:
            guard let url = activeModel?.url, httpOnlyURL(url) != nil,
                  let host = url.host else { return }
            // Prefill the editor with this host; the Boosts sheet opens the
            // editor on appear when a pending host is set.
            pendingBoostHost = host
            isBoostsPanelOpen = true
        case .addToReadingList:
            _ = addCurrentPageToReadingList()
        case .removeFromReadingList:
            removeCurrentPageFromReadingList()
        case .addToPinnedApps:
            _ = addCurrentPageAsPinnedApp()
        case .removeFromPinnedApps:
            if let url = activeModel?.url {
                pinnedWebApps.removeAll { app in
                    PinnedWebAppPolicy.isSameApp(app.url, url)
                }
            }
        case .capturePageScreenshot:
            capturePageScreenshot()
        case .copyPageScreenshot:
            copyPageScreenshot()
        case .captureFullPageScreenshot:
            captureFullPageScreenshot()
        case .copyFullPageScreenshot:
            copyFullPageScreenshot()
        case .copyPageURL:
            copyPageURL()
        case .copyAllTabURLs:
            copyAllTabURLs()
        case .copyAllTabsMarkdown:
            copyAllTabsAsMarkdown()
        }
    }


    // MARK: - Page Screenshot (Chrome / Arc parity)

    /// Captures the current page through the CDP bridge and shows a Save
    /// panel. Uses the page title for the suggested filename (sanitized), and
    /// surfaces the saved file as a completed download. No-op on chrome/blank
    /// pages and when the CDP bridge isn't wired.
    func capturePageScreenshot() {
        guard screenshotReady() else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                // A short bound keeps a wedged CDP target from hanging the
                // interaction for the full 30s default.
                guard let data = try await self.cdpClient.captureScreenshot(timeout: .seconds(10)) else { return }
                guard !Task.isCancelled else { return }
                self.saveScreenshot(
                    data,
                    message: "Save a screenshot of \(self.activeModel?.url?.host ?? "this page")",
                    filename: self.screenshotFilename(from: self.activeModel?.title ?? self.activeModel?.url?.host ?? "page")
                )
            } catch {
                NSLog("[HiveScreenshot] Capture failed: \(error.localizedDescription)")
            }
        }
    }

    /// Captures the current page and copies the PNG to the pasteboard — the
    /// quick share/annotate path.
    func copyPageScreenshot() {
        guard screenshotReady() else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let data = try await self.cdpClient.captureScreenshot(timeout: .seconds(10)) else { return }
                guard !Task.isCancelled else { return }
                self.copyToPasteboard(data)
            } catch {
                NSLog("[HiveScreenshot] Copy failed: \(error.localizedDescription)")
            }
        }
    }

    /// Captures the whole scrollable page (not just the viewport) and shows a
    /// Save panel, sharing the viewport path's save/download behavior. Chrome
    /// "full page" / Safari full-page capture parity.
    func captureFullPageScreenshot() {
        guard screenshotReady() else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let data = try await self.cdpClient.captureFullPageScreenshot(timeout: .seconds(20)) else { return }
                guard !Task.isCancelled else { return }
                self.saveScreenshot(
                    data,
                    message: "Save a full-page screenshot of \(self.activeModel?.url?.host ?? "this page")",
                    filename: self.screenshotFilename(from: self.activeModel?.title ?? self.activeModel?.url?.host ?? "page", suffix: "-full")
                )
            } catch {
                NSLog("[HiveScreenshot] Full-page capture failed: \(error.localizedDescription)")
            }
        }
    }

    /// Copies the full-page capture to the pasteboard.
    func copyFullPageScreenshot() {
        guard screenshotReady() else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let data = try await self.cdpClient.captureFullPageScreenshot(timeout: .seconds(20)) else { return }
                guard !Task.isCancelled else { return }
                self.copyToPasteboard(data)
            } catch {
                NSLog("[HiveScreenshot] Full-page copy failed: \(error.localizedDescription)")
            }
        }
    }

    /// Copies PNG bytes to the general pasteboard.
    func copyToPasteboard(_ data: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(data, forType: .png)
    }

    /// Shared screenshot save path: NSSavePanel → write → completed Download
    /// item. The record's source URL is the page, not the local file —
    /// matching saveImageAs so the Downloads panel and persisted history show
    /// where the screenshot came from.
    private func saveScreenshot(_ data: Data, message: String, filename: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.png]
        panel.message = message
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try data.write(to: destination)
        } catch {
            NSLog("[HiveScreenshot] Save failed: \(error.localizedDescription)")
            return
        }
        var item = DownloadItem(
            suggestedName: destination.lastPathComponent,
            url: activeModel?.url ?? destination
        )
        item.isComplete = true
        item.destinationURL = destination
        downloads.append(item)
        scheduleAutosave()
    }

    /// True when a screenshot is actually possible: a real http(s) page with an
    /// attached browser that isn't hibernated. Prevents a 30s CDP timeout on a
    /// sleeping or unattached tab.
    private func screenshotReady() -> Bool {
        guard canUseWebPageActions,
              let tab = activeTab,
              !tab.isHibernated,
              tab.model.browser != nil,
              httpOnlyURL(tab.model.url) != nil
        else { return false }
        return true
    }

    /// Sanitizes a page title into a safe save-panel default: control
    /// characters stripped, path separators replaced, whitespace collapsed,
    /// and a length cap so a 300-char title never produces an unwieldy name.
    /// `suffix` (e.g. "-full") distinguishes full-page captures from viewport
    /// ones in the suggested filename.
    func screenshotFilename(from raw: String, suffix: String = "") -> String {
        let cleaned = raw
            .unicodeScalars
            .filter { $0.value >= 0x20 }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: "/", with: "-")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let capped = cleaned.count > 60 ? String(cleaned.prefix(60)).trimmingCharacters(in: .whitespaces) : cleaned
        return (capped.isEmpty ? "screenshot" : capped) + suffix + ".png"
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


    /// Copies the current page's http(s) URL to the pasteboard. No-op on
    /// chrome/blank pages — internal URLs are noise, not shareable links.
    func copyPageURL() {
        guard let url = activeModel?.url, httpOnlyURL(url) != nil else { return }
        copyToPasteboard(url.absoluteString)
    }


    /// Copies every open tab URL in the current workspace, one per line — the
    /// Arc "copy links" share path. Only real http(s) pages are included;
    /// internal chrome and blank pages are noise, not links, and private tabs
    /// never leave ephemeral state (their URLs stay off the shared clipboard).
    /// The workspace's copyable tabs: non-private tabs in the current
    /// workspace with a real http(s) page. Hibernated tabs contribute their
    /// wake URL (the blank live model would otherwise drop them). Shared by
    /// the URL and markdown copy variants so their exclusions never drift.
    private func workspaceCopyableTabs() -> [Tab] {
        tabs.filter { tab in
            guard tab.workspaceID == currentWorkspaceID, !tab.isPrivate,
                  let url = tab.model.url ?? tab.savedURL,
                  httpOnlyURL(url) != nil
            else { return false }
            return true
        }
    }

    func copyAllTabURLs() {
        let urls = workspaceCopyableTabs()
            .compactMap { $0.model.url ?? $0.savedURL }
            .map(\.absoluteString)
        guard !urls.isEmpty else { return }
        copyToPasteboard(urls.joined(separator: "\n"))
    }


    /// Copies the current workspace's tabs as a markdown link list
    /// (`[Title](<url>)` per line) — a ready-made outline for notes, docs,
    /// and handoffs. Same exclusions as `copyAllTabURLs` (private tabs,
    /// non-http pages); a custom tab name wins, else the page title, else the
    /// host. Labels collapse whitespace runs (page titles can contain
    /// newlines) and escape `[`/`]`; destinations are wrapped in angle
    /// brackets so URLs containing `)` or spaces stay valid markdown.
    func copyAllTabsAsMarkdown() {
        let lines = workspaceCopyableTabs().compactMap { tab -> String? in
            guard let url = tab.model.url ?? tab.savedURL else { return nil }
            let title = tab.customTitle ?? tab.model.title
            let collapsed = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            let label = collapsed.isEmpty ? (url.host ?? url.absoluteString) : collapsed
            let escaped = label
                .replacingOccurrences(of: "[", with: "\\[")
                .replacingOccurrences(of: "]", with: "\\]")
            return "[\(escaped)](<\(url.absoluteString)>)"
        }
        guard !lines.isEmpty else { return }
        copyToPasteboard(lines.joined(separator: "\n"))
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
                        // Autofill never runs in private tabs (the probe would
                        // be harmless on its own, but no probe, no fill path).
                        if self.tabs.first(where: { $0.id == tabID })?.isPrivate != true {
                            model.executeJavaScript(Self.autofillProbeScript)
                        }
                    }
                    // The browser is attached now — re-apply this tab's
                    // persisted zoom and mute (wake/duplicate/split paths
                    // never go through selectTab).
                    if let tab = self.tabs.first(where: { $0.id == tabID }) {
                        self.applyStoredZoom(for: tab)
                        self.applyStoredMute(for: tab)
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
                        self.applyCosmeticAdBlock(on: model, url: completedURL)
                        // User-authored site styles never reach private tabs
                        // (Chrome extensions don't inject into incognito).
                        if !currentTab.isPrivate {
                            // Login pages usually arrive via a redirect — this
                            // fresh JS context needs the autofill probe re-armed
                            // too (never in private tabs).
                            model.executeJavaScript(Self.autofillProbeScript)
                            self.applyBoosts(on: model, url: completedURL)
                        }
                    }
                    // Zoom and mute are sticky per tab across navigations
                    // (Chrome-like); re-apply both on the completing tab.
                    self.applyStoredZoom(for: currentTab)
                    self.applyStoredMute(for: currentTab)
                    let title = model.title
                    // Back/forward menu stack: record the committed page in the
                    // owning tab's entry list (never private tabs — their
                    // navigation must leave no trace in chrome surfaces).
                    if let completedURL,
                       currentTab.isPrivate == false,
                       completedURL.scheme?.lowercased() == "http" || completedURL.scheme?.lowercased() == "https" {
                        self.recordCommittedNavigation(for: tabID, url: completedURL, title: title)
                    }
                    // History entries are admitted at navigation start, but the
                    // CEF completion is delayed and focus can move meanwhile.
                    // Resolve privacy from the completing tab, never from the
                    // global active-tab projection, before touching durable state.
                    if let entryID,
                       let completedURL,
                       currentTab.isPrivate == false,
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
