//
//  BrowserState+Setup.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Themes
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Setup

@MainActor
extension BrowserState {


    // MARK: - Themes

    func setAccentColor(hex: String) {
        browserAccentColorHex = hex
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).replacingOccurrences(of: "#", with: "")
        HiveBrand.accentHex = cleaned
        scheduleAutosave()
    }


    nonisolated static func normalizedUserDefinedCommands(_ commands: [UserDefinedCommand]) -> [UserDefinedCommand] {
        var seenIDs = Set<String>()
        var seenTitles = Set<String>()
        return commands.filter { command in
            let titleKey = command.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard command.isValidWebURL,
                  !seenIDs.contains(command.id),
                  !seenTitles.contains(titleKey),
                  seenIDs.count < 100 else {
                return false
            }
            seenIDs.insert(command.id)
            seenTitles.insert(titleKey)
            return true
        }
    }


    func addUserDefinedCommand(_ command: UserDefinedCommand) -> Bool {
        guard command.isValidWebURL,
              userDefinedCommands.count < 100,
              !userDefinedCommands.contains(where: {
                  $0.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    == command.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
              }) else {
            return false
        }
        userDefinedCommands.append(command)
        return true
    }


    func removeUserDefinedCommand(id: String) {
        userDefinedCommands.removeAll { $0.id == id }
    }


    func updateUserDefinedCommand(_ command: UserDefinedCommand) -> Bool {
        guard command.isValidWebURL,
              let index = userDefinedCommands.firstIndex(where: { $0.id == command.id }) else {
            return false
        }
        userDefinedCommands[index] = command
        return true
    }


    func togglePinTab(id: String) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        tab.isPinned.toggle()
        if tab.isPinned { tab.isEssential = false }
        scheduleAutosave()
    }


    func toggleEssentialTab(id: String) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        tab.isEssential.toggle()
        if tab.isEssential { tab.isPinned = false }
        scheduleAutosave()
    }


    func deleteBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        scheduleAutosave()
    }


    func addBookmark(_ bookmark: Bookmark) {
        bookmarks.append(bookmark)
        scheduleAutosave()
    }


    /// Adds or removes the active page's bookmark. Returns true if the page
    /// is bookmarked afterwards (used by the web chrome star state).
    @discardableResult
    func toggleBookmarkCurrentPage() -> Bool {
        guard let url = activeModel?.url,
              url.absoluteString != Self.webChromeStartURL.absoluteString,
              url.absoluteString != "about:blank"
        else { return false }
        if let existing = bookmarks.first(where: { $0.urlString == url.absoluteString }) {
            deleteBookmark(id: existing.id)
            return false
        }
        addBookmark(Bookmark(title: activeModel?.title ?? url.host ?? "Bookmark", url: url))
        return true
    }


    /// Merges external bookmarks and history through one state-owned import
    /// boundary. Every import surface therefore shares URL privacy, dedup,
    /// ordering, caps, persistence, and honest counts.
    @discardableResult
    func mergeImportedData(
        bookmarks importedBookmarks: [ImportedBookmark],
        history importedHistory: [ImportedHistoryEntry]
    ) -> (bookmarks: Int, history: Int, skipped: Int) {
        let bookmarkDecision = BookmarkImportPolicy.merge(
            existingURLs: Set(bookmarks.map(\.urlString)),
            candidates: importedBookmarks
        )
        for imported in bookmarkDecision.entries {
            addBookmark(Bookmark(title: imported.title, urlString: imported.url.absoluteString))
        }

        let historyDecision = BrowserImportMergePolicy.mergeHistory(
            existing: historyItems.map {
                BrowserImportMergePolicy.ExistingHistoryEntry(url: $0.url, visitedAt: $0.visitedAt)
            },
            candidates: importedHistory
        )
        if !historyDecision.retainedImported.isEmpty {
            historyItems.append(contentsOf: historyDecision.retainedImported.map {
                HistoryItem(title: $0.title, url: $0.url, visitedAt: $0.visitDate)
            })
            historyItems.sort {
                if $0.visitedAt != $1.visitedAt { return $0.visitedAt < $1.visitedAt }
                return $0.url.absoluteString < $1.url.absoluteString
            }
            if historyItems.count > 1_000 {
                historyItems.removeFirst(historyItems.count - 1_000)
            }
            scheduleAutosave()
            broadcastWebChromeState()
        }
        return (
            bookmarkDecision.entries.count,
            historyDecision.retainedImported.count,
            bookmarkDecision.skippedCount + historyDecision.skippedCount
        )
    }


    @discardableResult
    func mergeImportedHistory(_ candidates: [ImportedHistoryEntry]) -> (imported: Int, skipped: Int) {
        let result = mergeImportedData(bookmarks: [], history: candidates)
        return (result.history, result.skipped)
    }


    /// Starts durable handoff setup after browser state initialization without
    /// blocking CEF/SwiftUI launch. Recovery is explicit and asynchronous: it
    /// repairs only records already staged by an earlier approved handoff.
    /// Private browsing and automatic page capture are intentionally unrelated
    /// to this lifecycle task.
    func startResearchHandoffRecovery() {
        guard researchHandoffStatus == .notStarted else { return }
        researchHandoffRecoveryTask?.cancel()
        guard let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            researchHandoffStatus = .unavailable("Application Support is unavailable")
            return
        }

        let handoffDirectory = supportDirectory
            .appendingPathComponent("Hive", isDirectory: true)
            .appendingPathComponent("ResearchHandoff", isDirectory: true)
        let registryPath = handoffDirectory.appendingPathComponent("retention.sqlite3").path
        let journalPath = handoffDirectory.appendingPathComponent("recovery.sqlite3").path
        let honeycomb = self.honeycomb
        let ledger = self.eventLedger
        researchHandoffStatus = .starting

        // The supervisor opens SQLite and Keychain synchronously inside its
        // async initializer. Keep that work off the main actor; the result is
        // returned to this @MainActor state only after recovery is complete.
        researchHandoffRecoveryTask = Task { @MainActor [weak self] in
            do {
                let (supervisor, results) = try await Task.detached(priority: .utility) {
                    try Task.checkCancellation()
                    let supervisor = try await ResearchHandoffSupervisor(
                        honeycomb: honeycomb,
                        ledger: ledger,
                        registryPath: registryPath,
                        journalPath: journalPath
                    )
                    let results = try await supervisor.reconcilePending()
                    return (supervisor, results)
                }.value
                guard !Task.isCancelled, let self else { return }
                self.researchHandoffSupervisor = supervisor
                let repairedCount = results.reduce(into: 0) { count, result in
                    if case .repaired = result.outcome { count += 1 }
                }
                self.researchHandoffStatus = .recoveryReady(repairedCount: repairedCount)
            } catch {
                guard let self else { return }
                // A missing Keychain entitlement or a corrupt handoff store
                // must not prevent the browser from opening. Keep the failure
                // observable for diagnostics while leaving Browse/Remember
                // available through their existing local paths.
                self.researchHandoffStatus = .unavailable(String(describing: error))
            }
        }
    }


    /// Cancels background recovery when the browser state is being torn down.
    /// This is intentionally separate from private-browsing toggles: private
    /// mode changes the capture policy, while this controls service lifetime.
    func stopResearchHandoffRecovery() {
        researchHandoffRecoveryTask?.cancel()
        researchHandoffRecoveryTask = nil
        researchHandoffSupervisor = nil
        if researchHandoffStatus == .starting {
            researchHandoffStatus = .notStarted
        }
    }


    /// One-time migration of legacy plaintext secrets into Keychain.
    /// AGENTS.md §9.2 rule 7: credentials never live in UserDefaults.
    func migrateLegacySecrets() {
        // Safe Browsing API key previously stored in UserDefaults plaintext.
        if let legacyKey = UserDefaults.standard.string(forKey: "HiveSafeBrowsingKey"),
           !legacyKey.isEmpty {
            if KeychainSecretStore.read(key: GoogleSafeBrowsingClient.apiKeyAccount) == nil {
                KeychainSecretStore.save(key: GoogleSafeBrowsingClient.apiKeyAccount, value: legacyKey)
            }
            UserDefaults.standard.removeObject(forKey: "HiveSafeBrowsingKey")
        }
    }


    static func normalizeSessionData(_ saved: SessionData) -> (session: SessionData?, repairs: [TabOrganizationNormalizer.RepairReason]) {
        var firstProfiles: [String: CodableProfile] = [:]
        var profileOrder: [String] = []
        for profile in saved.profiles {
            let id = profile.id.uuidString
            if firstProfiles[id] == nil {
                firstProfiles[id] = profile
                profileOrder.append(id)
            }
        }

        var firstWorkspaces: [String: CodableWorkspace] = [:]
        var workspaceOrder: [String] = []
        for workspace in saved.workspaces {
            let id = workspace.id.uuidString
            if firstWorkspaces[id] == nil {
                firstWorkspaces[id] = workspace
                workspaceOrder.append(id)
            }
        }

        var firstGroups: [String: CodableTabGroup] = [:]
        var groupOrder: [String] = []
        for group in saved.tabGroups {
            let id = group.id.uuidString
            if firstGroups[id] == nil {
                firstGroups[id] = group
                groupOrder.append(id)
            }
        }

        // Dictionary construction must not use uniqueKeysWithValues here:
        // duplicate tab IDs are exactly one of the corrupt/stale inputs the
        // normalizer is responsible for repairing.
        var firstTabs: [String: CodableTabInfo] = [:]
        for tab in saved.tabInfos where firstTabs[tab.id] == nil {
            firstTabs[tab.id] = tab
        }

        let result = TabOrganizationNormalizer.normalize(.init(
            profiles: profileOrder.compactMap { firstProfiles[$0] }.map {
                .init(id: $0.id.uuidString)
            },
            workspaces: workspaceOrder.compactMap { firstWorkspaces[$0] }.map {
                .init(id: $0.id.uuidString, profileID: $0.profileID.uuidString)
            },
            groups: groupOrder.compactMap { firstGroups[$0] }.map {
                .init(id: $0.id.uuidString, workspaceID: $0.workspaceID.uuidString)
            },
            tabs: saved.tabInfos.map {
                .init(
                    id: $0.id,
                    workspaceID: $0.workspaceID.uuidString,
                    profileID: $0.profileID.uuidString,
                    groupID: $0.groupID?.uuidString,
                    isPinned: $0.isPinned,
                    isEssential: $0.isEssential,
                    isPrivate: $0.isPrivate == true,
                    urlString: $0.urlString,
                    savedURLString: $0.savedURLString,
                    isHibernated: $0.isHibernated == true
                )
            },
            activeProfileID: saved.currentProfileID.uuidString,
            activeWorkspaceID: saved.currentWorkspaceID.uuidString,
            activeTabID: saved.activeTabID,
            splitSecondaryTabID: saved.splitSecondaryTabID
        ))

        guard let activeProfileID = result.snapshot.activeProfileID,
              let activeWorkspaceID = result.snapshot.activeWorkspaceID,
              let activeProfileUUID = UUID(uuidString: activeProfileID),
              let activeWorkspaceUUID = UUID(uuidString: activeWorkspaceID) else {
            return (nil, result.repairReasons)
        }

        let normalizedProfiles = result.snapshot.profiles.compactMap { profile in
            firstProfiles[profile.id].flatMap { original in
                CodableProfile(
                    id: original.id,
                    name: original.name,
                    iconName: original.iconName,
                    colorHex: original.colorHex
                )
            }
        }
        let normalizedWorkspaces = result.snapshot.workspaces.compactMap { workspace in
            firstWorkspaces[workspace.id].flatMap { original in
                CodableWorkspace(
                    id: original.id,
                    name: original.name,
                    colorHex: original.colorHex,
                    iconName: original.iconName,
                    profileID: original.profileID
                )
            }
        }
        let normalizedGroups = result.snapshot.groups.compactMap { group in
            firstGroups[group.id].map { original in
                CodableTabGroup(
                    id: original.id,
                    name: original.name,
                    colorHex: original.colorHex,
                    workspaceID: original.workspaceID,
                    isCollapsed: original.isCollapsed
                )
            }
        }
        let normalizedTabs = result.snapshot.tabs.compactMap { tab -> CodableTabInfo? in
            guard let original = firstTabs[tab.id],
                  let workspaceID = UUID(uuidString: tab.workspaceID),
                  let profileID = UUID(uuidString: tab.profileID) else { return nil }
            return CodableTabInfo(
                id: tab.id,
                urlString: original.urlString,
                workspaceID: workspaceID,
                profileID: profileID,
                groupID: tab.groupID.flatMap(UUID.init(uuidString:)),
                isPinned: tab.isPinned,
                isEssential: tab.isEssential,
                isPrivate: false,
                isHibernated: tab.isHibernated,
                savedURLString: tab.savedURLString
            )
        }

        var normalizedSession = saved
        normalizedSession.profiles = normalizedProfiles
        normalizedSession.workspaces = normalizedWorkspaces
        normalizedSession.tabGroups = normalizedGroups
        normalizedSession.tabInfos = normalizedTabs
        normalizedSession.currentProfileID = activeProfileUUID
        normalizedSession.currentWorkspaceID = activeWorkspaceUUID
        normalizedSession.activeTabID = result.snapshot.activeTabID
        normalizedSession.splitSecondaryTabID = result.snapshot.splitSecondaryTabID
        return (normalizedSession, result.repairReasons)
    }


    func setupDefaults() {
        isRestoringSession = true
        defer { isRestoringSession = false }
        // Restore saved session or create defaults. Any corrupt-file recovery is
        // surfaced honestly through the recovery banner (never a silent reset).
        let (loaded, recoveryNotice) = Self.loadSession()
        sessionWasRestoredFromDisk = loaded != nil
        restoredSessionPriorCleanExit = loaded?.isCleanExit
        if let recoveryNotice { sessionRecoveryNotice = recoveryNotice }
        guard let loaded, !loaded.workspaces.isEmpty else {
            createDefaultProfiles()
            bookmarks = Bookmark.defaults
            bindHotMemoryToCurrentWorkspace()
            return
        }

        // Durable session data is user-owned input: normalize organization
        // references before any CEF model is created. This repairs stale
        // workspace/profile/group links and removes private or duplicate tabs
        // without allowing a malformed record to widen its scope.
        let normalized = Self.normalizeSessionData(loaded)
        sessionRepairReasons = normalized.repairs
        guard let saved = normalized.session,
              !saved.profiles.isEmpty,
              !saved.workspaces.isEmpty else {
            createDefaultProfiles()
            bookmarks = Bookmark.defaults
            bindHotMemoryToCurrentWorkspace()
            return
        }
        // Restore from persisted session.
        sessionSnapshotSequence = saved.snapshotSequence
        let chromePreferences = BrowserChromePreferences(
            layout: saved.layout,
            showBookmarksBar: saved.showBookmarksBar,
            isCompactMode: saved.isCompactMode,
            isMemorySaverEnabled: saved.isMemorySaverEnabled,
            openBriefOnNewTab: saved.openBriefOnNewTab
        ).normalized
        layout = TabLayout(rawValue: chromePreferences.layout) ?? .vertical
        isCompactMode = chromePreferences.isCompactMode
        showBookmarksBar = chromePreferences.showBookmarksBar
        isMemorySaverEnabled = chromePreferences.isMemorySaverEnabled
        openBriefOnNewTab = chromePreferences.openBriefOnNewTab
        browserAccentColorHex = saved.accentColorHex
            searchEngine = SearchEngine(rawValue: saved.searchEngine) ?? .google
            // Restore the user's model preference — it was persisted but never
            // read back, silently resetting to auto on every launch.
            preferredModelProvider = saved.preferredModelProvider
            // Restore split view (AGENTS.md P1: splits are a saved workspace).
            splitSecondaryTabID = saved.splitSecondaryTabID
            splitRatio = saved.splitRatio
            splitOrientation = SplitOrientation(rawValue: saved.splitOrientation) ?? .sideBySide
            bookmarks = saved.bookmarks
            // Migrate old plaintext passwords to Keychain (one-time upgrade path)
            KeychainPasswordStore.migrateFromLegacyJSON()
            // Load passwords from Keychain (not session JSON — secure hardware-backed storage)
            savedPasswords = KeychainPasswordStore.allPasswords()
            profiles = saved.profiles.map { Profile(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex) }
            currentProfileID = saved.currentProfileID
            workspaces = saved.workspaces.map { Workspace(id: $0.id, name: $0.name, colorHex: $0.colorHex, iconName: $0.iconName, profileID: $0.profileID) }
            currentWorkspaceID = saved.currentWorkspaceID
            tabGroups = saved.tabGroups.map {
                TabGroup(id: $0.id, name: $0.name, colorHex: $0.colorHex,
                         workspaceID: $0.workspaceID, isCollapsed: $0.isCollapsed)
            }
            historyItems = saved.history
            userDefinedCommands = saved.userDefinedCommands
            // Restored rows are terminal history only; DownloadItem decoding
            // clears CEF identity/controller state so the UI cannot offer
            // pause/resume against a dead process-local object.
            downloads = saved.downloads
            tabZoomLevels = saved.tabZoomLevels
            installedExtensions = saved.installedExtensions

        // Pure restore-decision contract (documented cross-browser mechanics):
        // transient blank tabs never restore, background durable tabs come back
        // as cold stubs (lazy) even if they were live at save time, and
        // pinned/essential + the previously active tab load eagerly. The loop
        // below never widens this scope; saved index order is preserved by
        // filtering, never by MRU.
        let restorePlan = SessionRestorePolicy.plan(
            from: saved.tabInfos.map { info in
                let hasSavedURL = !(info.urlString ?? "").isEmpty || !(info.savedURLString ?? "").isEmpty
                return SessionRestorePolicy.TabInput(
                    id: info.id,
                    isPrivate: info.isPrivate == true,
                    isTransient: !hasSavedURL,
                    isPinned: info.isPinned,
                    isEssential: info.isEssential,
                    wasActive: saved.activeTabID == info.id
                )
            },
            priorCleanExit: saved.isCleanExit
        )

        for ti in saved.tabInfos {
            let url = ti.urlString.flatMap { URL(string: $0) }
            let savedURL = ti.savedURLString.flatMap { URL(string: $0) } ?? url
            // Background durable tabs restore as cold stubs (lazy) even when
            // they were live at save time, matching Chromium/Firefox lazy
            // restore. The live model is intentionally blank while hibernated;
            // its durable destination lives in `savedURL`.
            let restoresLazily = restorePlan.lazyIDs.contains(ti.id)
            let isHibernated = (ti.isHibernated == true || restoresLazily) && savedURL != nil
            // Private tabs are intentionally never serialized. This guard is
            // defensive for forward-compatible or hand-edited session files.
            guard ti.isPrivate != true else { continue }
            // The pure policy excludes transient blank tabs; the loop never
            // widens that scope for hand-edited or forward-compatible files.
            guard !restorePlan.excludedIDs.contains(ti.id) else { continue }
            // Keep background cold tabs URL-less until selection wakes them.
            // The live model is intentionally blank while hibernated; its
            // durable destination lives in `savedURL`.
            let tab = Tab(
                url: isHibernated ? nil : url,
                workspaceID: ti.workspaceID,
                profileID: ti.profileID,
                groupID: ti.groupID,
                isPinned: ti.isPinned,
                isEssential: ti.isEssential,
                profile: cefProfile(for: ti.workspaceID)
            )
            tab.savedURL = savedURL
            tab.isHibernated = isHibernated
            tabs.append(tab)
            wireTabHooks(tab)
        }
        let restoredActiveTabID = saved.activeTabID
        activeTabID = restoredActiveTabID.flatMap { id in
            tabs.contains(where: { $0.id == id }) ? id : nil
        } ?? tabs.first?.id
        // Wake only the frontmost cold tab at launch. Background hibernated
        // tabs remain renderer-free until the user selects them.
        if let activeID = activeTabID,
           let active = tabs.first(where: { $0.id == activeID }),
           active.isHibernated {
            wakeTab(active)
        }
        // Normalize a session that was saved with the active tab inside a
        // collapsed group. The current page must be visible on first render;
        // the pure helper keeps this invariant aligned with toggle behavior.
        for index in tabGroups.indices {
            let memberTabIDs = Set(tabs.compactMap { tab in
                tab.groupID == tabGroups[index].id ? tab.id : nil
            })
            tabGroups[index].isCollapsed = HibernationAdapter.restoredCollapseState(
                isCollapsed: tabGroups[index].isCollapsed,
                memberTabIDs: memberTabIDs,
                activeTabID: activeTabID
            )
        }
        // A split can only reference a restored tab — drop dangling references.
        if let splitID = splitSecondaryTabID, !tabs.contains(where: { $0.id == splitID }) {
            splitSecondaryTabID = nil
        }
        if tabs.isEmpty { newTab() }
        bindHotMemoryToCurrentWorkspace()
    }


    /// Binds hot memory to the current workspace after session restore or
    /// first-launch defaults. Workspace-tagged entries (pages, captures) are
    /// dormant until their space activates, so without this bind the restored
    /// workspace's own memory would be invisible until the first space switch.
    func bindHotMemoryToCurrentWorkspace() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.hotMemory.setActiveScope(self.activeContextScope)
        }
    }


    func createDefaultProfiles() {
        // Chrome-like: single Default profile, single workspace, no pre-made tab groups.
        // Profiles, workspaces, and tab groups are created by the user as needed.
        let defaultProfile = Profile(name: "Default", iconName: "person.fill", colorHex: "#F97316")
        profiles = [defaultProfile]
        currentProfileID = defaultProfile.id

        let defaultWorkspace = Workspace(name: "Default", colorHex: "#F97316", iconName: "briefcase.fill", profileID: defaultProfile.id)
        workspaces = [defaultWorkspace]
        currentWorkspaceID = defaultWorkspace.id

        tabGroups = []
        newTab()
    }
}
