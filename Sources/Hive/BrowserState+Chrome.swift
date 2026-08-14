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


    /// The chrome dimension when no panel is open (spec §4):
    /// sidebar = 240pt (HiveDesign.Zen.sidebarWidth).
    /// strip = 58pt: the strip chrome is the WEB chrome shell, which stacks
    /// its toolbar row above the tab region (flex-direction: column), so its
    /// intrinsic height (~58pt) exceeds the 34pt native tab geometry.
    var chromeDefaultDimension: CGFloat {
        chromeMode == .sidebar
            ? HiveDesign.Zen.sidebarWidth
            : 58
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
        endPeek()
        isTabGridOpen = false
        isTabSearchOpen = overlayState.tabSearchPresented
    }


    func closeTabSearch() {
        isTabSearchOpen = false
    }


    func openWorkspaceManager() {
        isWorkspaceManagerPanelOpen = true
    }


    func openProfileManager() {
        isProfileManagerPanelOpen = true
    }


    func openTabGroupManager() {
        isTabGroupManagerPanelOpen = true
    }


    func openSearchEngineManager() {
        isSearchEngineManagerPanelOpen = true
    }


    func openKeyboardShortcuts() {
        isKeyboardShortcutsPanelOpen = true
    }


    func openMemorySaver() {
        isMemorySaverPanelOpen = true
    }


    func openTabGrid() {
        let overlayState = OverlayPresentationPolicy.openingTabSearch()
        isCommandPaletteOpen = overlayState.commandPalettePresented
        endPeek()
        isTabSearchOpen = false
        isTabGridOpen = overlayState.tabSearchPresented
    }


    func closeTabGrid() {
        isTabGridOpen = false
    }


    /// Selects a tab from the tab-search or tab-grid overlay, switching
    /// workspace first if the target lives in another space — Chrome's tab
    /// search spans windows, Hive's spans spaces.
    func selectTabFromSearch(id: String) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        closeTabSearch()
        closeTabGrid()
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
        // Remember the zoom level for this site (Chrome parity).
        if let host = Self.hostForZoom(tab.model.url) {
            var levels = siteZoomLevels
            if percent == 100 {
                levels.removeValue(forKey: host)
            } else {
                levels[host] = percent
            }
            siteZoomLevels = levels
        }
        scheduleAutosave()
    }


    /// Applies the remembered per-site zoom when a page finishes loading.
    /// Called from the navigation observation completion path.
    func applySiteZoom(for url: URL, tabID: String) {
        guard let host = Self.hostForZoom(url),
              let percent = siteZoomLevels[host],
              percent != 100,
              let tab = tabs.first(where: { $0.id == tabID })
        else { return }
        // Only apply if the tab doesn't have a more recent per-tab override.
        if tabZoomLevels[tabID] == nil || tabZoomLevels[tabID] == 0 {
            let level = log2(percent / 100)
            tabZoomLevels[tabID] = level
            tab.model.browser?.zoomLevel = level
        }
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

    /// Esc-exits-fullscreen (Chrome/Safari convention): no-ops when the window
    /// isn't actually fullscreen, so callers can fire it unconditionally.
    func exitFullscreenIfNeeded() {
        guard let window = NSApp.keyWindow, window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
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
        if url.isEmpty || url == "about:blank" || Self.isInternalWebChromeURL(activeModel?.url) { return "" }
        return url
    }


    /// The window titlebar / Mission Control / Window-menu label. Follows the
    /// Chrome/Safari convention: the active page's title, the host when the
    /// page has no title, and "New Tab" for the start page. This is a pure
    /// computed projection so every tab/navigation change re-titles the window
    /// through SwiftUI observation with no imperative window plumbing.
    var windowTitle: String {
        if let url = activeModel?.url?.absoluteString,
           url.isEmpty || url == "about:blank" || Self.isInternalWebChromeURL(activeModel?.url) {
            return "New Tab"
        }
        if let tab = activeTab {
            if let custom = tab.customTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
               !custom.isEmpty { return custom }
            let title = tab.model.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }
            if let host = tab.model.url?.host, !host.isEmpty { return host }
        }
        return "Hive"
    }


    /// Snapshot of start-page data for the web chrome (top sites, recent
    /// history, spaces). Shared by the hive.getStartData bridge function and
    /// the hive.stateChanged broadcast.
    func webChromeStartData(privateStart: Bool = false, chromeShell: Bool = true) -> WebChromeStartData {
        // Ask for more than the visible cap so user-removed hosts are replaced
        // by the next-most-visited sites (Chrome NTP behavior).
        let hidden = hiddenTopSiteHosts
        let top = Array(topDomainsFromHistory(limit: 16).filter { !hidden.contains($0.host) }.prefix(8))
        let topSites = top.map {
            WebChromeTopSite(host: $0.host, url: $0.url.absoluteString, faviconURL: $0.faviconURL?.absoluteString)
        }
        let recent = historyItems.suffix(6).reversed().map { item -> WebChromeRecentItem in
            WebChromeRecentItem(
                title: item.title,
                url: item.url.absoluteString,
                host: item.url.host ?? "",
                faviconURL: item.faviconURL?.absoluteString,
                timeLabel: item.visitedAt.formatted(.relative(presentation: .named)),
                dayLabel: Self.historyDayLabel(for: item.visitedAt),
                historyID: item.id.uuidString
            )
        }
        // Recently closed non-private tabs, newest first (Chrome NTP parity).
        // closedTabs is oldest→newest and already excludes private tabs, so
        // reverse it and skip blank/internal pages that have nothing to reopen.
        let recentlyClosed = closedTabs.reversed().compactMap { tab -> WebChromeRecentItem? in
            guard let url = tab.model.url, url.absoluteString != "about:blank",
                  !Self.isInternalWebChromeURL(url) else { return nil }
            return WebChromeRecentItem(
                title: tab.customTitle ?? tab.model.title ?? "Untitled",
                url: url.absoluteString,
                host: url.host ?? "",
                faviconURL: tab.model.faviconURL?.absoluteString,
                timeLabel: "Recently closed",
                dayLabel: nil,
                historyID: nil
            )
        }
        // Saved reading-list articles, newest first (Chrome/Safari parity).
        let readingListItems = readingList.reversed().map { entry -> WebChromeReadingListItem in
            WebChromeReadingListItem(
                id: entry.id,
                title: entry.title,
                url: entry.url.absoluteString,
                host: entry.url.host ?? ""
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
                title: tab.customTitle ?? tab.model.title ?? (url == nil ? "New Tab" : "Untitled"),
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
                          !Self.isInternalWebChromeURL(url),
                          u != "about:blank"
                    else { return false }
                    return bookmarks.contains(where: { $0.urlString == u })
                }(),
                isReaderMode: isReaderMode && tab.id == activeTabID,
                zoomPercent: tab.id == activeTabID ? activeZoomPercent : nil,
                isMuted: isTabMuted(tab.id),
                isMediaPlaying: mediaPlayingTabIDs.contains(tab.id),
                backHistory: {
                    let entries = tabNavBack[tab.id] ?? []
                    return entries.isEmpty ? nil : entries.prefix(12).map {
                        WebChromeNavEntry(title: $0.title, url: $0.url.absoluteString)
                    }
                }(),
                forwardHistory: {
                    let entries = tabNavForward[tab.id] ?? []
                    return entries.isEmpty ? nil : entries.prefix(12).map {
                        WebChromeNavEntry(title: $0.title, url: $0.url.absoluteString)
                    }
                }()
            )
        }
        let history = historyItems.suffix(40).reversed().map { item -> WebChromeRecentItem in
            WebChromeRecentItem(
                title: item.title,
                url: item.url.absoluteString,
                host: item.url.host ?? "",
                faviconURL: item.faviconURL?.absoluteString,
                timeLabel: item.visitedAt.formatted(.relative(presentation: .named)),
                dayLabel: Self.historyDayLabel(for: item.visitedAt),
                historyID: item.id.uuidString
            )
        }
        // Folders are structural, not navigable pages — the web chrome's
        // bookmark picker only lists content bookmarks (folder navigation
        // lives in the native manager).
        let bookmarkItems = bookmarks
            .filter { !$0.isFolder }
            .map { bm -> WebChromeBookmark in
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
            else if dl.controlState.state == .paused { stateName = "paused" }
            else if dl.progress > 0 { stateName = "inProgress" }
            else { stateName = "pending" }
            return WebChromeDownload(
                id: dl.id.uuidString,
                name: dl.suggestedName,
                url: dl.url.absoluteString,
                state: stateName,
                progress: dl.progress,
                hasDestination: dl.isComplete && !dl.isCanceled && !dl.isInterrupted
                    && dl.destinationURL != nil
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

        let snapshot = WebChromeStartData(
            topSites: topSites,
            recent: recent,
            recentlyClosed: recentlyClosed,
            readingList: readingListItems,
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
            searchEngine: searchEngine.rawValue,
            httpsOnlyEnabled: isHTTPSOnlyEnabled,
            adBlockEnabled: isAdBlockEnabled,
            memorySaverEnabled: isMemorySaverEnabled,
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
            lastQuery: lastQuery.isEmpty ? nil : lastQuery,
            syncDiagnostic: syncDiagnostic,
            pageTintHex: PageThemeColor.hexForURL(activeModel?.faviconURL)
        )
        if chromeShell { return snapshot }
        return privateStart
            ? snapshot.redactedForPrivateStart()
            : snapshot.redactedForNormalStart()
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

    /// Hosts the user removed from the new-tab top-sites grid (Chrome NTP
    /// "Remove" behavior). UserDefaults-backed so removal survives restarts;
    /// clearing the key restores the defaults.
    var hiddenTopSiteHosts: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "HiveHiddenTopSiteHosts") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "HiveHiddenTopSiteHosts") }
    }

    /// Permanently hides a host from the top-sites grid. No-op on empty input.
    func hideTopSite(host: String) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        var hidden = hiddenTopSiteHosts
        hidden.insert(trimmed)
        hiddenTopSiteHosts = hidden
    }

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
        // The registry advertises this command as "Mute / Unmute Site"; route
        // it to the durable per-site mute so the slash command matches its
        // title now that site mute is real (per-tab mute stays on the tab
        // speaker and tab context menus).
        case .muteTab: if let tab = activeTab { toggleSiteMute(for: tab) }
        case .toggleDownloads: isDownloadsPanelOpen = true
        case .showHistory: isHistoryPanelOpen = true
        case .showBookmarks: openBookmarksManager()
        case .cleanTabs: openCleanTabs()
        case .openArchive: isArchivePanelOpen = true
        case .showBoosts: isBoostsPanelOpen = true
        case .toggleSwarm: toggleGeminiPanel()
        default: break
        }
    }


    /// Chrome-history-style day bucket shared by the start page "recent" and
    /// the web-chrome History panel: Today, Yesterday, This Week, or Older.
    /// Matches the native HistoryPanel grouping so both surfaces read alike.
    static func historyDayLabel(for date: Date) -> String? {
        let cal = Calendar.current
        let now = Date()
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if cal.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return "This Week" }
        return "Older"
    }

    /// Suggestions for a start page whose bridge cannot safely identify a
    /// browser/frame. Normal starts receive only normal-profile records;
    /// private starts receive a generic search fallback and never query the
    /// shared tabs, history, or bookmarks collections.
    func webChromeSuggestions(for query: String, privateStart: Bool) -> [OmniboxSuggestion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return [] }
        // A site keyword (`yt kittens`) resolves to that site's search —
        // keyword search is explicit user intent, safe for private starts.
        if let keywordMatch = SiteSearchKeywordPolicy.keywordQuery(from: query, keywords: siteSearchKeywords()),
           let url = SiteSearchKeywordPolicy.searchURL(for: keywordMatch.query, keyword: keywordMatch.keyword) {
            return [OmniboxSuggestion(
                text: "Search \"\(keywordMatch.query)\" on \(keywordMatch.keyword.name)",
                url: url,
                kind: .search
            )]
        }
        let searchEngineName = searchEngineDisplayName
        let fallback = OmniboxSuggestion(
            text: "Search \"\(q)\" on \(searchEngineName)",
            url: searchURL(for: q),
            kind: .search
        )
        if privateStart { return [fallback] }

        var results: [OmniboxSuggestion] = []
        for tab in tabs where !tab.isPrivate && results.count < 3 {
            if tab.id == activeTabID { continue }
            let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "") : tab.model.title
            let urlString = tab.model.url?.absoluteString ?? ""
            if title.lowercased().contains(q) || urlString.lowercased().contains(q) {
                var suggestion = OmniboxSuggestion(text: title, url: tab.model.url, kind: .tab)
                suggestion.tabID = tab.id
                results.append(suggestion)
            }
        }
        for item in historyItems.reversed() where results.count < 5 {
            if item.title.lowercased().contains(q) || item.url.absoluteString.lowercased().contains(q) {
                results.append(OmniboxSuggestion(text: item.title, url: item.url, kind: .history))
            }
        }
        for bookmark in bookmarks where results.count < 8 {
            // Folders are structural containers, never navigation targets.
            guard !bookmark.isFolder else { continue }
            let lower = bookmark.title.lowercased() + bookmark.urlString.lowercased()
            if lower.contains(q) && !results.contains(where: { $0.url?.absoluteString == bookmark.urlString }) {
                results.append(OmniboxSuggestion(text: bookmark.title, url: bookmark.url, kind: .bookmark))
            }
        }
        return results.isEmpty ? [fallback] : results
    }


    /// Chrome-style site keywords (`yt kittens` → YouTube search). Shared by
    /// the address-bar resolution and the suggestion surface so the keyword
    /// list never drifts.
    func siteSearchKeywords() -> [SiteSearchKeyword] {
        customSearchEngines.compactMap { engine -> SiteSearchKeyword? in
            guard let keyword = engine.keyword,
                  let normalized = SiteSearchKeywordPolicy.normalizedKeyword(keyword)
            else { return nil }
            return SiteSearchKeyword(keyword: normalized, name: engine.name, template: engine.template)
        }
    }


    func omniboxSuggestions(for query: String) -> [OmniboxSuggestion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Chrome-style site keywords first: typing `yt ` + a query proposes
        // the site search at the top of the list so the Enter key takes it.
        if let keywordMatch = SiteSearchKeywordPolicy.keywordQuery(from: query, keywords: siteSearchKeywords()),
           let url = SiteSearchKeywordPolicy.searchURL(for: keywordMatch.query, keyword: keywordMatch.keyword) {
            return [OmniboxSuggestion(
                text: "Search \"\(keywordMatch.query)\" on \(keywordMatch.keyword.name)",
                url: url,
                kind: .search
            )]
        }
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

        // Bookmark matches (folders are containers, never navigation targets)
        for b in bookmarks where results.count < 8 {
            guard !b.isFolder else { continue }
            let lower = b.title.lowercased() + b.urlString.lowercased()
            if lower.contains(q) && !results.contains(where: { $0.url?.absoluteString == b.urlString }) {
                results.append(OmniboxSuggestion(text: b.title, url: b.url, kind: .bookmark))
            }
        }

        // Search suggestion fallback
        let searchEngineName = searchEngineDisplayName
        if results.isEmpty {
            results.append(OmniboxSuggestion(
                text: "Search \"\(q)\" on \(searchEngineName)",
                url: searchURL(for: q),
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
        // Keep the last query so ⌘F/⌘G reopen with the previous search
        // (Chrome behavior) instead of a blank field.
        findMatchText = nil
    }

    func closeFindBar() {
        isFindBarOpen = false
        // Keep findQuery so ⌘G still has a query to run; the highlights are
        // cleared by FindBar.onDisappear. Cancel a pending counter walk so a
        // programmatic close can't let it fire into a hidden bar.
        findMatchText = nil
        findCountDebounceTask?.cancel()
        findCountDebounceTask = nil
    }

    /// Find-in-page entry shared by the Find bar (typing) and the ⌘F path.
    func findInPage(_ query: String) {
        findQuery = query
        guard !query.isEmpty, let model = activeModel else { return }
        // The selection jump is cheap and instant; the counter's full-page
        // text walk is debounced so fast typing on long pages stays smooth.
        model.executeJavaScript(Self.buildFindJumpJS(query, forward: true, caseSensitive: findMatchCaseSensitive))
        scheduleFindCount(query)
    }

    /// ⌘G — next match. Reopens the bar with the last query when closed.
    func findNextInPage() {
        if !isFindBarOpen { openFindBar() }
        guard !findQuery.isEmpty, let model = activeModel else { return }
        model.executeJavaScript(Self.buildFindJumpJS(findQuery, forward: true, caseSensitive: findMatchCaseSensitive))
        model.executeJavaScript(Self.buildFindCountJS(findQuery, caseSensitive: findMatchCaseSensitive))
    }

    /// ⇧⌘G — previous match. Reopens the bar with the last query when closed.
    func findPreviousInPage() {
        if !isFindBarOpen { openFindBar() }
        guard !findQuery.isEmpty, let model = activeModel else { return }
        model.executeJavaScript(Self.buildFindJumpJS(findQuery, forward: false, caseSensitive: findMatchCaseSensitive))
        model.executeJavaScript(Self.buildFindCountJS(findQuery, caseSensitive: findMatchCaseSensitive))
    }

    /// Flips the Aa "Match case" toggle (Chrome find-bar parity) and
    /// immediately re-runs the current find so the toggle has visible effect.
    /// The pending debounced count is cancelled — this toggle already counts
    /// synchronously, so a stale walk ~120ms later would be a duplicate.
    func toggleFindCaseSensitivity() {
        findMatchCaseSensitive.toggle()
        findCountDebounceTask?.cancel()
        findCountDebounceTask = nil
        guard !findQuery.isEmpty, let model = activeModel else { return }
        model.executeJavaScript(Self.buildFindJumpJS(findQuery, forward: true, caseSensitive: findMatchCaseSensitive))
        model.executeJavaScript(Self.buildFindCountJS(findQuery, caseSensitive: findMatchCaseSensitive))
    }

    func clearFindHighlights() {
        // Clear the counter unconditionally so a teardown with no active
        // model can't leave a stale "3/12" behind.
        findMatchText = nil
        findCountDebounceTask?.cancel()
        findCountDebounceTask = nil
        guard let model = activeModel else { return }
        model.executeJavaScript("window.getSelection().removeAllRanges()")
    }

    /// Debounces the match-counter walk while the user is typing; the next
    /// explicit ⌘G/⇧⌘G counts immediately via its own call. Internal so the
    /// web-chrome surface can reuse the same debounced count.
    func scheduleFindCount(_ query: String) {
        findCountDebounceTask?.cancel()
        findCountDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard let self, !Task.isCancelled else { return }
            self.activeModel?.executeJavaScript(Self.buildFindCountJS(query, caseSensitive: self.findMatchCaseSensitive))
        }
    }

    /// Find-in-page selection jump (`window.find`). Cheap and immediate;
    /// never walks the page. `forward` maps to the `backwards` parameter:
    /// `window.find(text, caseSensitive, backwards, wrapAround, wholeWord, searchInFrames, showDialog)`.
    static func buildFindJumpJS(_ query: String, forward: Bool, caseSensitive: Bool) -> String {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "window.find(\"\(escaped)\", \(caseSensitive), \(!forward), true, false, true, false)"
    }

    /// Match counter walk: reports `HIVE_FIND|<current>|<total>` so the find
    /// bar can show "3/12" like Chrome/Safari. Walks text nodes once and
    /// resolves "current" from the selection's anchor — window.find selects
    /// the matched text, so the anchor offset is exactly the match start.
    /// Escaping: the query is escaped once for the JS string literal; the
    /// RegExp is built at runtime from that string so no double-escaping is
    /// needed on the Swift side. Known v1 limits: matches split across
    /// element boundaries are under-counted, and text inside form fields is
    /// excluded (matching Chrome's find UI, which also skips them).
    static func buildFindCountJS(_ query: String, caseSensitive: Bool) -> String {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        (function(){
          var q = "\(escaped)";
          try {
            var re = new RegExp(q.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'), '\(caseSensitive ? "g" : "gi")');
            var total = 0, seen = 0, current = 0;
            var sel = window.getSelection();
            var anchorNode = sel ? sel.anchorNode : null;
            var anchorOffset = sel ? sel.anchorOffset : 0;
            var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
              acceptNode: function(n){
                var t = n.nodeValue || '';
                if (!t.trim()) return NodeFilter.FILTER_REJECT;
                var p = n.parentElement;
                if (!p) return NodeFilter.FILTER_REJECT;
                var tag = p.tagName;
                if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'TEXTAREA' || tag === 'INPUT' || p.isContentEditable) return NodeFilter.FILTER_REJECT;
                return NodeFilter.FILTER_ACCEPT;
              }
            });
            var node;
            while (node = walker.nextNode()) {
              var t = node.nodeValue || '';
              var m;
              while ((m = re.exec(t))) {
                total++;
                if (node === anchorNode) {
                  if (m.index < anchorOffset) seen++;
                  else if (m.index === anchorOffset) current = seen + 1;
                }
                if (re.lastIndex === m.index) re.lastIndex++;
              }
            }
            if (current === 0 && total > 0) current = Math.min(seen + 1, total);
            console.log('HIVE_FIND|' + current + '|' + total);
          } catch (e) {
            console.log('HIVE_FIND|0|0');
          }
        })();
        """
    }

    /// Word-count report from the injected reader JS. Only the active model's
    /// reports are honored, and only while reader mode is actually active — a
    /// stale report from a page that was closed or exited can't leak a number
    /// into the next article.
    func handleReaderWordCountConsoleMessage(_ message: String, from model: CefWebViewModel) {
        guard model === activeModel, isReaderMode else { return }
        let parts = message.split(separator: "|").map(String.init)
        guard parts.count == 2, let count = Int(parts[1]), count >= 0 else { return }
        readerWordCount = count
    }


    /// Find-counter report from the page's find JS. Only the active model's
    /// reports are honored — background tabs never update the find bar.
    func handleFindConsoleMessage(_ message: String, from model: CefWebViewModel) {
        guard model === activeModel else { return }
        let parts = message.split(separator: "|").map(String.init)
        guard parts.count == 3,
              let current = Int(parts[1]),
              let total = Int(parts[2])
        else { return }
        if total == 0 {
            findMatchText = "No matches"
        } else {
            findMatchText = "\(min(max(current, 1), total))/\(total)"
        }
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
