//
//  BrowserState+Workspaces.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Profiles | - Workspaces | - Tab Groups | - Group rename (window-level alert)
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Workspaces

@MainActor
extension BrowserState {


    var currentProfile: Profile? {
        profiles.first { $0.id == currentProfileID }
    }


    /// Returns the CEF profile for a workspace, creating it lazily if needed.
    func cefProfile(for workspaceID: UUID) -> CefProfile {
        if let existing = workspaceProfiles[workspaceID] { return existing }
        let profile = CefProfile.persistent(name: workspaceID.uuidString)
        workspaceProfiles[workspaceID] = profile
        return profile
    }


    /// Removes a workspace's CEF profile and deletes its cookie jar from disk.
    /// Runs the disk cleanup async after a brief delay to let CEF release file locks.
    func deleteWorkspaceProfile(id: UUID) {
        workspaceProfiles.removeValue(forKey: id)
        let profileDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hive/Profiles/\(id.uuidString)")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            try? FileManager.default.removeItem(at: profileDir)
        }
    }


    /// Returns a CefProfile for the current browsing mode.
    /// Private browsing → in-memory (no persistence). Normal → per-workspace disk isolation.
    func profileForCurrentWorkspace() -> CefProfile {
        if isPrivateBrowsing { return CefProfile.incognito() }
        return cefProfile(for: currentWorkspaceID)
    }


    var currentWorkspace: Workspace? {
        workspaces.first { $0.id == currentWorkspaceID }
    }


    var workspacesForCurrentProfile: [Workspace] {
        workspaces.filter { $0.profileID == currentProfileID }
    }


    func switchWorkspace(to id: UUID) {
        // No mini-player trigger here — and deliberately so. A space switch
        // does NOT change activeTabID (the current page stays visible until
        // the user picks a tab in the new space), so any inline trigger would
        // either be dead (isMiniPlayerVisible requires id != activeTabID) or,
        // if "fixed" to request PiP, would pop an OS window over a tab the
        // user is still looking at. The cross-space float already happens
        // correctly when the user selects a tab in the new space: selectTab →
        // updateMiniPlayerAfterSwitch → video/audio branch.
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.springQuick) {
            currentWorkspaceID = id
        }
        // A peek belongs to the previous workspace's chrome — dismiss it, and
        // drop pooled previews whose tabs live elsewhere (privacy: content
        // from one space must never surface in another).
        endPeek()
        previewPool.removeAll { entry in
            guard let tab = tabs.first(where: { $0.id == entry.tabID }) else { return true }
            return tab.workspaceID != id
        }
        scheduleAutosave()
        // Announce the transition through the same FIFO used by requests. The
        // generation makes a delayed old binding harmless if a second switch
        // happens before this task reaches HotMemory.
        let transitionID = contextTransitionToken.advance()
        let scope = activeContextScope
        if let coordinator = contextRequestCoordinator {
            Task {
                await coordinator.announceTransition(transitionID)
                await coordinator.bind(scope: scope, transitionID: transitionID)
            }
        }
        broadcastWebChromeState()
    }


    func nextWorkspace() {
        let profileWorkspaces = workspacesForCurrentProfile
        guard let currentIndex = profileWorkspaces.firstIndex(where: { $0.id == currentWorkspaceID }) else { return }
        let nextIndex = (currentIndex + 1) % profileWorkspaces.count
        switchWorkspace(to: profileWorkspaces[nextIndex].id)
    }


    func previousWorkspace() {
        let profileWorkspaces = workspacesForCurrentProfile
        guard let currentIndex = profileWorkspaces.firstIndex(where: { $0.id == currentWorkspaceID }) else { return }
        let previousIndex = (currentIndex - 1 + profileWorkspaces.count) % profileWorkspaces.count
        switchWorkspace(to: profileWorkspaces[previousIndex].id)
    }


    // MARK: - Profiles

    func switchProfile(to id: UUID) {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.springQuick) {
            currentProfileID = id
            if let first = workspaces.first(where: { $0.profileID == id }) {
                currentWorkspaceID = first.id
            } else {
                let workspace = addWorkspace(name: "Default", colorHex: "#F97316", iconName: "briefcase.fill", profileID: id)
                currentWorkspaceID = workspace.id
            }
            if !tabs.contains(where: { $0.workspaceID == currentWorkspaceID }) {
                newTab()
            }
        }
        scheduleAutosave()
        // Profile switch lands on the profile's first workspace. Route the
        // binding through the transition coordinator so stale tasks cannot
        // restore the previous profile's scope after a rapid switch.
        let transitionID = contextTransitionToken.advance()
        let scope = activeContextScope
        if let coordinator = contextRequestCoordinator {
            Task {
                await coordinator.announceTransition(transitionID)
                await coordinator.bind(scope: scope, transitionID: transitionID)
            }
        }
    }


    func nextProfile() {
        guard let currentIndex = profiles.firstIndex(where: { $0.id == currentProfileID }) else { return }
        let nextIndex = (currentIndex + 1) % profiles.count
        switchProfile(to: profiles[nextIndex].id)
    }


    func previousProfile() {
        guard let currentIndex = profiles.firstIndex(where: { $0.id == currentProfileID }) else { return }
        let previousIndex = (currentIndex - 1 + profiles.count) % profiles.count
        switchProfile(to: profiles[previousIndex].id)
    }


    func addWorkspace(name: String, colorHex: String, iconName: String, profileID: UUID? = nil) -> Workspace {
        let targetProfileID = profileID ?? currentProfileID
        let workspace = Workspace(name: name, colorHex: colorHex, iconName: iconName, profileID: targetProfileID)
        workspaces.append(workspace)
        scheduleAutosave()
        return workspace
    }


    func deleteWorkspace(id: UUID) {
        guard workspaces.count > 1 else { return }
        deleteWorkspaceProfile(id: id)
        workspaces.removeAll { $0.id == id }
        if currentWorkspaceID == id, let first = workspaces.first(where: { $0.profileID == currentProfileID }) {
            currentWorkspaceID = first.id
        }
        tabs.forEach { if $0.workspaceID == id { $0.workspaceID = currentWorkspaceID } }
        scheduleAutosave()
    }


    var groupsForCurrentWorkspace: [TabGroup] {
        tabGroups.filter { $0.workspaceID == currentWorkspaceID }
    }


    func groupForTab(_ tab: Tab) -> TabGroup? {
        guard let groupID = tab.groupID else { return nil }
        return tabGroups.first { $0.id == groupID }
    }


    func tabGroupColor(_ tab: Tab) -> Color? {
        guard let group = groupForTab(tab) else { return nil }
        return group.swiftUIColor
    }


    /// IDs of tabs in explicitly collapsed groups. This is a projection of
    /// persisted UI state for the pure hibernation adapter; it does not close
    /// any CEF browser by itself.
    var collapsedGroupTabIDs: Set<String> {
        let collapsedIDs = Set(tabGroups.filter(\.isCollapsed).map(\.id))
        return Set(tabs.compactMap { tab in
            guard let groupID = tab.groupID, collapsedIDs.contains(groupID) else { return nil }
            return tab.id
        })
    }


    func toggleTabGroup(id: UUID) {
        guard let index = tabGroups.firstIndex(where: { $0.id == id }) else { return }
        // Never hide the page the user is currently viewing. The group can be
        // collapsed immediately after they select another tab, matching the
        // browser convention that an active member forces its group open.
        let memberTabIDs = Set(tabs.compactMap { tab in
            tab.groupID == id ? tab.id : nil
        })
        if !tabGroups[index].isCollapsed,
           !HibernationAdapter.canCollapseGroup(
               memberTabIDs: memberTabIDs,
               activeTabID: activeTabID
           ) {
            return
        }
        tabGroups[index].isCollapsed.toggle()
        scheduleAutosave()
        // A collapse is an explicit rest gesture. Evaluate immediately rather
        // than waiting for the periodic 60-second pass; Memory Saver and the
        // adapter's media/download/pinned/essential guards still decide what
        // may actually be torn down.
        if tabGroups[index].isCollapsed {
            runHibernationPass()
        }
    }


    @discardableResult
    func createTabGroup(name: String, colorHex: String) -> TabGroup {
        let group = TabGroup(name: name, colorHex: colorHex, workspaceID: currentWorkspaceID)
        tabGroups.append(group)
        scheduleAutosave()
        return group
    }


    func renameTabGroup(id: UUID, name: String) {
        guard let index = tabGroups.firstIndex(where: { $0.id == id }) else { return }
        tabGroups[index].name = name
        scheduleAutosave()
    }


    func setTabGroupColor(id: UUID, colorHex: String) {
        guard let index = tabGroups.firstIndex(where: { $0.id == id }),
              Color(hex: colorHex) != nil else { return }
        tabGroups[index].colorHex = colorHex
        scheduleAutosave()
    }


    /// Opens the rename alert for a group, seeding the text field with the
    /// current name. Called from the group context menus.
    func beginRenamingGroup(_ id: UUID) {
        guard let group = tabGroups.first(where: { $0.id == id }) else { return }
        renameGroupTargetID = id
        renameGroupText = group.name
    }


    /// Commits the rename from the alert's text field; empty input cancels.
    func commitGroupRename() {
        guard let id = renameGroupTargetID else { return }
        let name = renameGroupText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            renameTabGroup(id: id, name: name)
        }
        renameGroupTargetID = nil
        renameGroupText = ""
    }


    /// Closes the rename alert without committing.
    func cancelGroupRename() {
        renameGroupTargetID = nil
        renameGroupText = ""
    }


    func deleteTabGroup(id: UUID) {
        tabGroups.removeAll { $0.id == id }
        tabs.forEach { if $0.groupID == id { $0.groupID = nil } }
        scheduleAutosave()
    }


    func moveTabToGroup(tabID: String, groupID: UUID?) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        tab.groupID = groupID
        if let group = tabGroups.first(where: { $0.id == groupID }), tab.workspaceID != group.workspaceID {
            tab.workspaceID = group.workspaceID
            invalidatePreview(for: tabID)
        }
        scheduleAutosave()
    }


    /// Moves a tab to a different workspace (Zen DND workspace drop).
    func moveTabToWorkspace(tabID: String, workspaceID: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabID }),
              tab.workspaceID != workspaceID else { return }
        tab.workspaceID = workspaceID
        tab.groupID = nil  // ungroup when moving between workspaces
        invalidatePreview(for: tabID)
        scheduleAutosave()
    }
}
