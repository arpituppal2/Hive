import HiveCore

// MARK: - ChromeState command execution
//
// Routes typed BrowserCommand IDs from the HiveCore command registry into the actual browser
// state mutations. This lives in the Hive app target because it depends on the live
// `ChromeState`; the registry itself (command metadata) is in HiveCore so it is testable.

extension ChromeState {

    /// Executes a command from the command palette/registry. No-op for commands that require
    /// state the browser does not currently have (e.g. no active tab).
    @MainActor func executeCommand(_ command: BrowserCommand) {
        switch command {
        case .newTab:
            newTab()

        case .newPrivateTab:
            newTab(isPrivate: true)

        case .closeTab:
            if let id = activeTabID { closeTab(id) }

        case .closeOtherTabs:
            if let id = activeTabID { closeOtherTabs(keeping: id) }

        case .duplicateTab:
            if let id = activeTabID { duplicateTab(id) }

        case .pinTab:
            if let id = activeTabID { togglePin(id) }

        case .muteTab:
            if let id = activeTabID { toggleMute(id) }

        case .nextTab:
            cycleTab(by: 1)

        case .previousTab:
            cycleTab(by: -1)

        case .newSpace:
            newSpace()

        case .deleteSpace:
            // Only delete the active space if it is not the last one.
            if spaces.count > 1 {
                deleteSpace(activeSpace.id)
            }

        case .nextSpace:
            cycleSpaces(forward: true)

        case .previousSpace:
            cycleSpaces(forward: false)

        case .toggleLayout:
            toggleLayout()

        case .toggleTabOverview:
            toggleTabOverview()

        case .focusOmnibar:
            focusOmnibar()

        case .reload:
            requestNav(.reload)

        case .back:
            requestNav(.back)

        case .forward:
            requestNav(.forward)

        case .capturePage:
            captureActivePage()

        case .toggleReaderMode:
            toggleReaderMode()

        case .toggleDownloads:
            toggleDownloadsPanel()

        case .showHistory:
            if !isHistoryPanelOpen { toggleHistoryPanel() }

        case .showBookmarks:
            if !isBookmarksPanelOpen { toggleBookmarksPanel() }

        case .toggleBookmarkBar:
            toggleBookmarkBar()

        case .showSettings:
            openSettings()

        case .printPage:
            printActiveTab()

        case .toggleSwarm:
            toggleSwarm()

        case .openArchive:
            // Opens a fresh start-page tab, which surfaces the Cold Archive section.
            newTab()

        case .newJournal:
            // Swarm drafts the journal; the user can refine and save it as a brief.
            openSwarmWithQuery("Draft a new journal entry from the current page.")
        }
    }
}
