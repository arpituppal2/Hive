//
//  BrowserState+Persistence.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Session persistence
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Persistence

@MainActor
extension BrowserState {


    // MARK: - Session persistence

    /// Durable session persistence with the same atomic-write + rolling-backup +
    /// corrupt-quarantine contract as HiveCore's BrowserSessionStore: a crash or
    /// truncated write can never silently wipe the user's workspace/tab layout.
    /// The backup is written before each swap, so the last good session is always
    /// recoverable ("restore last session"), never silently lost.
    static func sessionFileStore() -> SessionFileStore<SessionData> {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Hive", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return SessionFileStore(
            url: dir.appendingPathComponent("session.json"),
            prevURL: dir.appendingPathComponent("session.prev.json")
        )
    }


    static func sessionURL() -> URL {
        sessionFileStore().url
    }


    func dismissSessionRepairNotice() {
        sessionRepairNoticeDismissed = true
    }


    /// Loads the persisted session plus recovery metadata. `.restored`/`.none`
    /// carry no notice; `.corrupt` always carries one, whether or not a backup
    /// could be recovered — the user is never silently reset.
    static func loadSession() -> (session: SessionData?, notice: SessionRecoveryNotice?) {
        switch sessionFileStore().load() {
        case .restored(let session):
            let notice = session.isCleanExit
                ? nil
                : SessionRecoveryNotice(recoveredFromBackup: false, quarantineURL: nil, uncleanExit: true)
            return (session, notice)
        case .none: return (nil, nil)
        case .corrupt(let quarantineURL, let recovered):
            return (
                recovered,
                SessionRecoveryNotice(
                    recoveredFromBackup: recovered != nil,
                    quarantineURL: quarantineURL,
                    uncleanExit: recovered?.isCleanExit == false
                )
            )
        }
    }


    @discardableResult
    func saveSession(isCleanExit cleanExit: Bool = false) -> Bool {
        let nextSnapshotSequence = sessionSnapshotSequence &+ 1
        // Private tabs never enter the durable projection. Derive every
        // cross-reference from the same non-private set so an active private
        // tab cannot leave a dangling selection or zoom record behind.
        let persistedTabs = tabs.filter { !$0.isPrivate }
        let persistedTabIDs = Set(persistedTabs.map(\.id))
        let persistedActiveTabID = activeTabID.flatMap { persistedTabIDs.contains($0) ? $0 : nil }
            ?? persistedTabs.first?.id
        let persistedSplitSecondaryTabID = splitSecondaryTabID.flatMap {
            persistedTabIDs.contains($0) ? $0 : nil
        }
        let persistedZoomLevels = tabZoomLevels.filter { persistedTabIDs.contains($0.key) }

        let chromePreferences = BrowserChromePreferences(
            layout: layout.rawValue,
            showBookmarksBar: showBookmarksBar
        ).normalized
        let sd = SessionData(
            layout: chromePreferences.layout,
            isCompactMode: isCompactMode,
            showBookmarksBar: chromePreferences.showBookmarksBar,
            isMemorySaverEnabled: isMemorySaverEnabled,
            accentColorHex: browserAccentColorHex,
            searchEngine: searchEngine.rawValue,
            preferredModelProvider: preferredModelProvider,
            splitSecondaryTabID: persistedSplitSecondaryTabID,
            splitRatio: splitRatio,
            splitOrientation: splitOrientation.rawValue,
            activeTabID: persistedActiveTabID,
            currentProfileID: currentProfileID,
            currentWorkspaceID: currentWorkspaceID,
            profiles: profiles.map { CodableProfile(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex) },
            workspaces: workspaces.map { CodableWorkspace(id: $0.id, name: $0.name, colorHex: $0.colorHex, iconName: $0.iconName, profileID: $0.profileID) },
            tabGroups: tabGroups.map {
                CodableTabGroup(id: $0.id, name: $0.name, colorHex: $0.colorHex,
                                workspaceID: $0.workspaceID, isCollapsed: $0.isCollapsed)
            },
            tabInfos: persistedTabs.map {
                let effectiveURL = $0.isHibernated ? $0.savedURL : $0.model.url
                return CodableTabInfo(
                    id: $0.id,
                    urlString: effectiveURL?.absoluteString,
                    workspaceID: $0.workspaceID,
                    profileID: $0.profileID,
                    groupID: $0.groupID,
                    isPinned: $0.isPinned,
                    isEssential: $0.isEssential,
                    isPrivate: nil,
                    isHibernated: $0.isHibernated ? true : nil,
                    savedURLString: $0.isHibernated ? $0.savedURL?.absoluteString : nil
                )
            },
            bookmarks: bookmarks,
            history: historyItems,
            downloads: downloads.filter { $0.isComplete || $0.isCanceled || $0.isInterrupted },
            userDefinedCommands: userDefinedCommands,
            tabZoomLevels: persistedZoomLevels,
            installedExtensions: installedExtensions,
            snapshotSequence: nextSnapshotSequence,
            isCleanExit: cleanExit,
            schemaVersion: 1
        )
        // Atomic temp-then-swap write through the shared store; the prior good
        // session remains in place until the replacement is ready, so a failed
        // write cannot erase the only durable copy.
        let didWrite = Self.sessionFileStore().write(sd)
        if didWrite {
            sessionSnapshotSequence = nextSnapshotSequence
        }
        return didWrite
    }
}
