import Foundation

// MARK: - BrowserSession persistence projection

public extension BrowserSession {
    /// Returns the durable projection of a live session.
    ///
    /// Private tabs are deliberately omitted, not merely marked. The projection
    /// also repairs every tab-ID reference owned by spaces and groups, plus the
    /// window's active IDs, so recovery cannot resurrect private content or
    /// point at a tab that was removed. The live session is never mutated.
    var sanitizedForPersistence: BrowserSession {
        BrowserSession(
            windows: windows.map(\.sanitizedForPersistence),
            savedAt: savedAt,
            // Archived records contain URLs and titles too; private records
            // must not survive through the Recently Archived shelf.
            archivedTabs: archivedTabs.filter { !$0.isPrivate },
            snapshotSequence: snapshotSequence,
            isCleanExit: isCleanExit,
            schemaVersion: schemaVersion
        )
    }
}

public extension BrowserSessionWindow {
    /// Removes private tabs and repairs all references into the remaining tab
    /// set. This is intentionally pure so it can be tested independently of
    /// disk I/O and browser UI state.
    var sanitizedForPersistence: BrowserSessionWindow {
        let persistedTabs = tabs.filter { !$0.isPrivate }
        let persistedTabIDs = Set(persistedTabs.map(\.id))

        let persistedSpaces = spaces.map { space in
            var sanitized = space
            sanitized.tabIDs = space.tabIDs.filter { persistedTabIDs.contains($0) }
            sanitized.activeTabID = space.activeTabID.flatMap {
                persistedTabIDs.contains($0) ? $0 : sanitized.tabIDs.first
            }
            sanitized.groups = space.groups.map { group in
                var sanitizedGroup = group
                sanitizedGroup.tabIDs = group.tabIDs.filter { persistedTabIDs.contains($0) }
                sanitizedGroup.lastActiveTabID = group.lastActiveTabID.flatMap {
                    sanitizedGroup.tabIDs.contains($0) ? $0 : sanitizedGroup.tabIDs.first
                }
                return sanitizedGroup
            }
            return sanitized
        }

        let persistedSpaceIDs = Set(persistedSpaces.map(\.id))
        let activeSpaceID = activeSpaceID.flatMap {
            persistedSpaceIDs.contains($0) ? $0 : persistedSpaces.first?.id
        }
        let activeTabID = activeTabID.flatMap {
            persistedTabIDs.contains($0) ? $0 : nil
        } ?? activeSpaceID.flatMap { spaceID in
            persistedSpaces.first(where: { $0.id == spaceID })?.activeTabID
        } ?? persistedTabs.first?.id

        return BrowserSessionWindow(
            spaces: persistedSpaces,
            tabs: persistedTabs,
            activeSpaceID: activeSpaceID,
            activeTabID: activeTabID,
            layout: layout,
            density: density
        )
    }
}
