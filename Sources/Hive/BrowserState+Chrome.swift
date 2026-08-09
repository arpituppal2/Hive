//
//  BrowserState+Chrome.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: Web chrome shell (the UI in web content) | - Compact Mode (Zen-style chrome auto-hide) | - Floating URL Bar | - Tab Search (Chrome / Edge / Safari parity) | - Page Zoom (Chrome / Edge / Safari parity) | - Fullscreen (Safari / Chrome parity) | - Print (Chrome / Edge / Safari parity) | - Web Chrome (hive://) | - Layout | - Top Domains | - Omnibox Suggestions | - Address bar | - Command palette | - Find in page | - Split View
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Chrome

@MainActor
extension BrowserState {


    /// The chrome dimension when no panel is open (sidebar: 270pt;
    /// strip: 58pt).
    var chromeDefaultDimension: CGFloat {
        chromeMode == .sidebar ? 270 : 58
    }


    func setChromePanel(_ panel: String?) {
        isChromePanelOpen = panel
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.springQuick) {
            if let panel {
                // Grow the chrome to make room for the panel; the web UI
                // renders the toolbar on top and the panel below (strip) or
                // beside (sidebar) it. Clamped so the content area never
                // disappears.
                chromeDimension = chromeMode == .sidebar
                    ? min(max(chromeDimension, 420), 560)
                    : min(max(chromeDimension, 420), 560)
            } else {
                chromeDimension = chromeDefaultDimension
            }
        }
    }


    func toggleCompactMode() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isCompactMode.toggle()
        }
    }


    func showFloatingURLBar(prefill: String = "", opensNewTab: Bool = false) {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isFloatingURLBarVisible = true
            floatingURLBarText = prefill
            floatingURLBarOpensNewTab = opensNewTab
            addressFocusTrigger += 1
        }
    }


    func hideFloatingURLBar() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.springQuick) {
            isFloatingURLBarVisible = false
            floatingURLBarText = ""
            floatingURLBarOpensNewTab = false
        }
    }


    func openTabSearch() {
        // The two search surfaces are mutually exclusive — opening one
        // dismisses the other (they both dim the whole window).
        let overlayState = OverlayPresentationPolicy.openingTabSearch()
        isCommandPaletteOpen = overlayState.commandPalettePresented
        // Dismiss any live peek: TabPeekOverlay renders above this overlay's
        // dim backdrop (later in the chain), so a peek card would float over
        // the search — same reasoning as switchWorkspace's endPeek().
        endPeek()
        isTabSearchOpen = overlayState.tabSearchPresented
    }


    func closeTabSearch() {
        isTabSearchOpen = false
    }


    /// Selects a tab from the tab-search overlay, switching workspace first if
    /// the target lives in another space — Chrome's tab search spans windows,
    /// Hive's spans spaces.
    func selectTabFromSearch(id: String) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        closeTabSearch()
        if tab.workspaceID != currentWorkspaceID {
            switchWorkspace(to: tab.workspaceID)
        }
        selectTab(id: id)
    }


    /// The live zoom percent of the active tab. Prefers the browser's own
    /// level — pinch-zoom (CefMetalHostView) and the keyboard then share one
    /// source of truth — and falls back to the persisted level when the
    /// browser isn't attached yet (hibernated/waking tab).
    var activeZoomPercent: Int {
        guard let tab = activeTab else { return 100 }
        let level = tab.model.browser?.zoomLevel ?? (tabZoomLevels[tab.id] ?? 0)
        return max(10, min(500, Int((pow(2.0, level) * 100).rounded())))
    }


    func zoomIn() { adjustZoom(by: +1) }


    func zoomOut() { adjustZoom(by: -1) }


    func resetZoom() { setZoom(percent: 100, tabID: activeTabID) }


    func adjustZoom(by step: Int) {
        guard let tab = activeTab else { return }
        let current = Double(activeZoomPercent)
        if step > 0, let next = Self.zoomLadder.first(where: { $0 > current + 0.5 }) {
            setZoom(percent: next, tabID: tab.id)
        } else if step < 0, let prev = Self.zoomLadder.last(where: { $0 < current - 0.5 }) {
            setZoom(percent: prev, tabID: tab.id)
        }
    }


    func setZoom(percent: Double, tabID: String?) {
        guard let tabID, let tab = tabs.first(where: { $0.id == tabID }) else { return }
        let level = log2(percent / 100)
        tabZoomLevels[tabID] = level
        tab.model.browser?.zoomLevel = level
        scheduleAutosave()
    }


    /// Re-applies a tab's persisted zoom when its browser is attached. No-op
    /// until the browser exists (the CEF browser attaches async after wake).
    ///
    /// Persisted-level-wins semantics: a keyboard zoom is stored and restored
    /// on revisit (Chrome-like). A trackpad pinch writes only the live
    /// browser level (CEF has no zoom-changed callback to store from), so a
    /// pinch after a keyboard zoom is dropped when the tab is revisited — the
    /// stored keyboard level re-applies. The keyboard continues from the live
    /// level while the tab is on screen (activeZoomPercent reads the browser),
    /// so pinch + keyboard never fight during a session.
    func applyStoredZoom(for tab: Tab) {
        guard let level = tabZoomLevels[tab.id], let browser = tab.model.browser else { return }
        browser.zoomLevel = level
    }


    // MARK: - Fullscreen (Safari / Chrome parity)

    func toggleFullscreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }


    // MARK: - Print (Chrome / Edge / Safari parity)

    /// Prints the active page. CefKit exposes no print API (verified by grep),
    /// so the honest route is the page's own `window.print()` — CEF intercepts
    /// it and shows its native print dialog. Works on any page, no extra
    /// plumbing, no fake print surface.
    func printCurrentPage() {
        activeModel?.executeJavaScript("window.print();")
    }


    /// The text shown in the address bar. The web start page renders as an
    /// empty field — a raw `hive://start` would be chrome noise, not a URL.
    var addressDisplayString: String {
        guard let url = activeModel?.url?.absoluteString else { return "" }
        if url.isEmpty || url == "about:blank" || url == Self.webChromeStartURL.absoluteString { return "" }
        return url
    }


    /// The window titlebar / Mission Control / Window-menu label. Follows the
    /// Chrome/Safari convention: the active page's title, the host when the
    /// page has no title, and "New Tab" for the start page. This is a pure
    /// computed projection so every tab/navigation change re-titles the window
    /// through SwiftUI observation with no imperative window plumbing.
    var windowTitle: String {
        if let url = activeModel?.url?.absoluteString,
           url.isEmpty || url == "about:blank" || url == Self.webChromeStartURL.absoluteString {
            return "New Tab"
        }
        if let tab = activeTab {
            let title = tab.model.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }
            if let host = tab.model.url?.host, !host.isEmpty { return host }
        }
        return "Hive"
    }


    /// Snapshot of start-page data for the web chrome (top sites, recent
    /// history, spaces). Shared by the hive.getStartData bridge function and
    /// the hive.stateChanged broadcast.
    func webChromeStartData() -> WebChromeStartData {
        let top = topDomainsFromHistory(limit: 8)
        let topSites = top.map {
            WebChromeTopSite(host: $0.host, url: $0.url.absoluteString, faviconURL: $0.faviconURL?.absoluteString)
        }
        let recent = historyItems.suffix(6).reversed().map { item -> WebChromeRecentItem in
            WebChromeRecentItem(
                title: item.title,
                url: item.url.absoluteString,
                host: item.url.host ?? "",
                faviconURL: item.faviconURL?.absoluteString,
                timeLabel: item.visitedAt.formatted(.relative(presentation: .named))
            )
        }
        let spaces = workspacesForCurrentProfile.map { ws -> WebChromeSpace in
            WebChromeSpace(
                id: ws.id.uuidString,
                name: ws.name,
                colorHex: ws.colorHex,
                tabCount: tabs.filter { $0.workspaceID == ws.id }.count
            )
        }
        let chromeTabs = tabs.map { tab -> WebChromeTab in
            let url = tab.model.url
            return WebChromeTab(
                id: tab.id,
                title: tab.model.title ?? (url == nil ? "New Tab" : "Untitled"),
                url: url?.absoluteString,
                host: url?.host,
                faviconURL: tab.model.faviconURL?.absoluteString,
                isPinned: tab.isPinned,
                isEssential: tab.isEssential,
                isPrivate: tab.isPrivate,
                isHibernated: tab.isHibernated,
                canGoBack: tab.model.canGoBack,
                canGoForward: tab.model.canGoForward,
                isLoading: tab.model.isLoading,
                workspaceID: tab.workspaceID.uuidString,
                groupID: tab.groupID?.uuidString,
                isBookmarked: {
                    guard let u = url?.absoluteString,
                          u != Self.webChromeStartURL.absoluteString,
                          u != "about:blank"
                    else { return false }
                    return bookmarks.contains(where: { $0.urlString == u })
                }()
            )
        }
        let history = historyItems.suffix(40).reversed().map { item -> WebChromeRecentItem in
            WebChromeRecentItem(
                title: item.title,
                url: item.url.absoluteString,
                host: item.url.host ?? "",
                faviconURL: item.faviconURL?.absoluteString,
                timeLabel: item.visitedAt.formatted(.relative(presentation: .named))
            )
        }
        let bookmarkItems = bookmarks.map { bm -> WebChromeBookmark in
            WebChromeBookmark(
                id: bm.id.uuidString,
                title: bm.title,
                url: bm.url.absoluteString,
                faviconURL: bm.faviconURL?.absoluteString
            )
        }
        let downloadItems = downloads.suffix(12).reversed().map { dl -> WebChromeDownload in
            let stateName: String
            if dl.isComplete { stateName = "completed" }
            else if dl.isCanceled { stateName = "cancelled" }
            else if dl.isInterrupted { stateName = "failed" }
            else if dl.progress > 0 { stateName = "inProgress" }
            else { stateName = "pending" }
            return WebChromeDownload(
                id: dl.id.uuidString,
                name: dl.suggestedName,
                url: dl.url.absoluteString,
                state: stateName,
                progress: dl.progress
            )
        }

        // Tab groups belonging to the current workspace — the web chrome uses
        // these to render collapsible group headers in the tab list.
        let chromeGroups = groupsForCurrentWorkspace.map { group -> WebChromeTabGroup in
            WebChromeTabGroup(
                id: group.id.uuidString,
                name: group.name,
                colorHex: group.colorHex,
                tabIDs: tabs.filter { $0.groupID == group.id && $0.workspaceID == currentWorkspaceID }.map(\.id),
                isCollapsed: group.isCollapsed
            )
        }
        let councilDTO: WebChromeCouncilVerdict?
        if let v = latestCouncilVerdict {
            councilDTO = WebChromeCouncilVerdict(
                answer: v.answer,
                reasoning: v.reasoning,
                agreements: v.agreements,
                disagreements: v.disagreements,
                confidence: v.confidence,
                activeProviders: v.activeProviders.map { $0.rawValue },
                isDegraded: v.isDegraded,
                responses: v.responses.map { r in
                    WebChromeCouncilResponse(
                        provider: r.provider.rawValue,
                        answer: r.answer,
                        confidence: r.confidence,
                        durationMS: Int(r.duration * 1000),
                        status: r.status == .success ? "success" : "timeout"
                    )
                }
            )
        } else {
            councilDTO = nil
        }

        let researchDTO: WebChromeDeepResearchStep?
        if let step = deepResearchStep {
            researchDTO = WebChromeDeepResearchStep(
                label: step.label,
                progress: step.progress,
                isComplete: { if case .complete = step { return true }; return false }()
            )
        } else {
            researchDTO = nil
        }

        return WebChromeStartData(
            topSites: topSites,
            recent: recent,
            spaces: spaces,
            accentHex: browserAccentColorHex,
            tabs: chromeTabs,
            activeTabID: activeTabID,
            layout: layout == .vertical ? "vertical" : "horizontal",
            isPrivateBrowsing: isPrivateBrowsing,
            isSplitActive: isSplitViewActive,
            isChromePanelOpen: isChromePanelOpen,
            chromeMode: chromeMode == .sidebar ? "sidebar" : "strip",
            chromeDimension: Double(chromeDimension),
            tabGroups: chromeGroups,
            history: history,
            bookmarks: bookmarkItems,
            downloads: downloadItems,
            councilVerdict: councilDTO,
            isCouncilConvening: isCouncilConvening,
            councilLiveResponses: councilLiveResponses.map { r in WebChromeCouncilResponse(provider: r.provider.rawValue, answer: r.answer, confidence: r.confidence, durationMS: Int(r.duration * 1000), status: r.status == .success ? "success" : "timeout") },
            deepResearchStep: researchDTO,
            agentTask: agentTask,
            councilError: councilError,
            agentError: agentError,
            lastQuery: lastQuery.isEmpty ? nil : lastQuery
        )
    }


    // MARK: - Layout

    func toggleLayout() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            layout = (layout == .horizontal) ? .vertical : .horizontal
        }
    }


    func setLayout(_ value: TabLayout) {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            layout = value
        }
    }


    // MARK: - Top Domains

    /// Aggregates browsing history by domain, returning the most-frequently-visited
    /// sites sorted by visit count. Used by the new tab page and floating URL bar.
    func topDomainsFromHistory(limit: Int) -> [(host: String, url: URL, faviconURL: URL?)] {
        var counts: [String: (count: Int, url: URL, faviconURL: URL?)] = [:]
        for item in historyItems {
            guard let host = item.url.host else { continue }
            let cleanHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            if let existing = counts[cleanHost] {
                // Prefer newer favicon over older one
                counts[cleanHost] = (existing.count + 1, existing.url, item.faviconURL ?? existing.faviconURL)
            } else {
                counts[cleanHost] = (1, item.url, item.faviconURL)
            }
        }
        return counts
            .sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .map { ($0.key, $0.value.url, $0.value.faviconURL) }
    }


    /// Resolves an exact slash command through the core registry. The browser
    /// owns execution, while the registry owns which aliases are discoverable.
    /// Unknown slash input remains ordinary address/search text; `//` is
    /// explicitly left alone for URL paths.
    func omniboxCommand(for input: String) -> BrowserCommand? {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.hasPrefix("/"), !normalized.hasPrefix("//") else { return nil }
        let token = String(normalized.dropFirst())
        guard !token.isEmpty else { return nil }
        return Self.omniboxCommandRegistry.definition(forSlashAlias: token)?.id
    }


    /// Executes only commands from the typed slash catalog. This remains a
    /// direct dispatch to existing browser actions; the omnibox adds discovery,
    /// not a second command implementation.
    func executeOmniboxCommand(_ command: BrowserCommand) {
        switch command {
        case .newTab: showFloatingURLBar(opensNewTab: true)
        case .newPrivateTab: newPrivateTab()
        case .closeTab: closeActiveTab()
        case .reload: reload()
        case .back: goBack()
        case .forward: goForward()
        case .toggleLayout: toggleLayout()
        case .toggleTabOverview: openTabSearch()
        case .focusOmnibar: focusAddressBar()
        case .toggleReaderMode: toggleReaderMode()
        case .toggleDownloads: isDownloadsPanelOpen = true
        case .showHistory: isHistoryPanelOpen = true
        case .showBookmarks: openBookmarksManager()
        case .toggleSwarm: toggleGeminiPanel()
        default: break
        }
    }


    func omniboxSuggestions(for query: String) -> [OmniboxSuggestion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.hasPrefix("/") && !q.hasPrefix("//") {
            let commandQuery = String(q.dropFirst()).trimmingCharacters(in: .whitespaces)
            return Self.omniboxCommandRegistry.slashCommands(matching: commandQuery)
                .prefix(8)
                .compactMap { definition in
                    guard let alias = Self.omniboxCommandRegistry.slashAlias(for: definition.id) else { return nil }
                    return OmniboxSuggestion(
                        text: "/\(alias)",
                        url: nil,
                        kind: .command,
                        command: definition.id
                    )
                }
        }
        guard q.count >= 2 else { return [] }
        var results: [OmniboxSuggestion] = []

        // Open tab matches (Chrome/Arc-style tab switching from omnibox)
        for tab in tabs where results.count < 3 {
            if tab.id == activeTabID { continue }
            let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "") : tab.model.title
            let urlStr = tab.model.url?.absoluteString ?? ""
            if title.lowercased().contains(q) || urlStr.lowercased().contains(q) {
                var s = OmniboxSuggestion(
                    text: title,
                    url: tab.model.url,
                    kind: .tab
                )
                s.tabID = tab.id
                results.append(s)
            }
        }

        // History matches (most recent first)
        for item in historyItems.reversed() where results.count < 5 {
            if item.title.lowercased().contains(q) || item.url.absoluteString.lowercased().contains(q) {
                results.append(OmniboxSuggestion(text: item.title, url: item.url, kind: .history))
            }
        }

        // Bookmark matches
        for b in bookmarks where results.count < 8 {
            let lower = b.title.lowercased() + b.urlString.lowercased()
            if lower.contains(q) && !results.contains(where: { $0.url?.absoluteString == b.urlString }) {
                results.append(OmniboxSuggestion(text: b.title, url: b.url, kind: .bookmark))
            }
        }

        // Search suggestion fallback
        if results.isEmpty {
            results.append(OmniboxSuggestion(
                text: "Search \"\(q)\" on \(searchEngine.rawValue)",
                url: URL(string: "\(searchEngine.searchURL)\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"),
                kind: .search
            ))
        }
        return results
    }


    // MARK: - Address bar

    func focusAddressBar() {
        addressFocusTrigger += 1
    }



    // MARK: - Command palette

    func openCommandPalette() {
        // Command Palette and Tab Search both own a full-window dimming layer.
        // Keep them mutually exclusive regardless of whether the palette was
        // opened from a shortcut, menu item, or the web-chrome bridge.
        let overlayState = OverlayPresentationPolicy.openingCommandPalette()
        isTabSearchOpen = overlayState.tabSearchPresented
        endPeek()
        isCommandPaletteOpen = overlayState.commandPalettePresented
        commandPaletteQuery = ""
    }


    func closeCommandPalette() {
        isCommandPaletteOpen = false
        commandPaletteQuery = ""
    }


    // MARK: - Find in page

    func openFindBar() {
        isFindBarOpen = true
        findQuery = ""
    }


    func closeFindBar() {
        isFindBarOpen = false
        findQuery = ""
    }


    var splitSecondaryTab: Tab? {
        guard let id = splitSecondaryTabID else { return nil }
        return tabs.first { $0.id == id }
    }


    var isSplitViewActive: Bool {
        guard let secondary = splitSecondaryTab,
              let active = activeTab,
              active.id != secondary.id else { return false }
        return true
    }


    func splitActiveTab(with id: String, orientation: SplitOrientation = .sideBySide) {
        guard id != activeTabID else { return }
        // Wake hibernated tabs before splitting — a sleeping tab's browser was
        // closed, so rendering it in the split pane would show a dead surface.
        if let tab = tabs.first(where: { $0.id == id }), tab.isHibernated {
            wakeTab(tab)
        }
        splitSecondaryTabID = id
        splitRatio = 0.5
        splitOrientation = orientation
        scheduleAutosave()
    }


    func setSplitOrientation(_ orientation: SplitOrientation) {
        splitOrientation = orientation
        scheduleAutosave()
    }


    func unsplit() {
        splitSecondaryTabID = nil
        scheduleAutosave()
    }


    func toggleSplitWithActiveTab(id: String, orientation: SplitOrientation = .sideBySide) {
        // Unsplit only when the same tab AND orientation are active — so
        // pressing ⌃⌥H while split side-by-side re-orients instead of
        // unsplitting (Zen parity: each split hotkey forces its layout).
        if splitSecondaryTabID == id && splitOrientation == orientation {
            splitSecondaryTabID = nil
        } else {
            splitSecondaryTabID = id
            splitOrientation = orientation
        }
        scheduleAutosave()
    }


    /// Splits the active tab with the next visible tab in order (wrapping),
    /// or toggles the split off if already split with that tab. Backs the
    /// Zen-style ⌃⌥V / ⌃⌥H split shortcuts.
    func splitWithNextTab(orientation: SplitOrientation) {
        let visible = visibleTabs
        guard let activeIdx = visible.firstIndex(where: { $0.id == activeTabID }), visible.count > 1 else { return }
        let next = visible[(activeIdx + 1) % visible.count]
        toggleSplitWithActiveTab(id: next.id, orientation: orientation)
    }


    /// Clamps and sets the split divider position from a drag gesture.
    func setSplitRatio(_ value: Double) {
        splitRatio = min(max(value, 0.1), 0.9)
    }
}
