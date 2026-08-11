import Foundation

// MARK: - BrowserSession restore integrity

/// Non-sensitive summary of semantic repairs made to a decoded session.
/// Counts describe shape changes only; URLs, titles, IDs, and private content
/// never leave the session payload through this report.
public struct BrowserSessionRepairReport: Sendable, Equatable {
    public let removedPrivateTabs: Int
    public let removedDanglingTabReferences: Int
    public let removedDuplicateTabReferences: Int
    public let repairedActiveReferences: Int

    public init(
        removedPrivateTabs: Int = 0,
        removedDanglingTabReferences: Int = 0,
        removedDuplicateTabReferences: Int = 0,
        repairedActiveReferences: Int = 0
    ) {
        self.removedPrivateTabs = removedPrivateTabs
        self.removedDanglingTabReferences = removedDanglingTabReferences
        self.removedDuplicateTabReferences = removedDuplicateTabReferences
        self.repairedActiveReferences = repairedActiveReferences
    }

    public var didRepair: Bool {
        removedPrivateTabs > 0 ||
        removedDanglingTabReferences > 0 ||
        removedDuplicateTabReferences > 0 ||
        repairedActiveReferences > 0
    }
}

public struct BrowserSessionNormalization: Sendable, Equatable {
    public let session: BrowserSession
    public let report: BrowserSessionRepairReport

    public init(session: BrowserSession, report: BrowserSessionRepairReport) {
        self.session = session
        self.report = report
    }
}

public extension BrowserSession {
    /// Returns a restore-safe session and a non-sensitive repair summary.
    var normalizedForRestore: BrowserSessionNormalization {
        var report = BrowserSessionRepairReport()
        let normalizedWindows = windows.map { window in
            let normalization = window.normalizedForRestore
            report = report + normalization.report
            return normalization.window
        }
        let filteredArchived = archivedTabs.filter { !$0.isPrivate }
        if filteredArchived.count != archivedTabs.count {
            report = report + BrowserSessionRepairReport(removedPrivateTabs: archivedTabs.count - filteredArchived.count)
        }
        return BrowserSessionNormalization(
            session: BrowserSession(
                windows: normalizedWindows,
                savedAt: savedAt,
                archivedTabs: filteredArchived,
                snapshotSequence: snapshotSequence,
                isCleanExit: isCleanExit,
                schemaVersion: schemaVersion
            ),
            report: report
        )
    }
}

private struct WindowNormalization {
    let window: BrowserSessionWindow
    let report: BrowserSessionRepairReport
}

private extension BrowserSessionWindow {
    var normalizedForRestore: WindowNormalization {
        var report = BrowserSessionRepairReport()
        let persistedTabs = tabs.filter { !$0.isPrivate }
        if persistedTabs.count != tabs.count {
            report = report + BrowserSessionRepairReport(removedPrivateTabs: tabs.count - persistedTabs.count)
        }
        let validTabIDs = Set(persistedTabs.map(\.id))

        let normalizedSpaces = spaces.map { space in
            var normalized = space
            let filteredSpaceIDs = space.tabIDs.filter(validTabIDs.contains)
            let uniqueSpaceIDs = orderedUnique(filteredSpaceIDs)
            report = report + BrowserSessionRepairReport(
                removedDanglingTabReferences: space.tabIDs.count - filteredSpaceIDs.count,
                removedDuplicateTabReferences: filteredSpaceIDs.count - uniqueSpaceIDs.count
            )
            normalized.tabIDs = uniqueSpaceIDs

            normalized.groups = space.groups.map { group in
                var normalizedGroup = group
                // A group belongs to this space; a tab that exists in the
                // session but belongs to another space must not be restored
                // into this group's UI.
                let filteredGroupIDs = group.tabIDs.filter(uniqueSpaceIDs.contains)
                let uniqueGroupIDs = orderedUnique(filteredGroupIDs)
                report = report + BrowserSessionRepairReport(
                    removedDanglingTabReferences: group.tabIDs.count - filteredGroupIDs.count,
                    removedDuplicateTabReferences: filteredGroupIDs.count - uniqueGroupIDs.count
                )
                normalizedGroup.tabIDs = uniqueGroupIDs
                if let lastActive = group.lastActiveTabID,
                   !uniqueGroupIDs.contains(lastActive) {
                    normalizedGroup.lastActiveTabID = uniqueGroupIDs.first
                    report = report + BrowserSessionRepairReport(repairedActiveReferences: 1)
                }
                return normalizedGroup
            }
            if let active = space.activeTabID, !uniqueSpaceIDs.contains(active) {
                normalized.activeTabID = uniqueSpaceIDs.first
                report = report + BrowserSessionRepairReport(repairedActiveReferences: 1)
            }
            return normalized
        }

        let validSpaceIDs = Set(normalizedSpaces.map(\.id))
        var normalizedActiveSpaceID = activeSpaceID
        if let activeSpaceID, !validSpaceIDs.contains(activeSpaceID) {
            normalizedActiveSpaceID = normalizedSpaces.first?.id
            report = report + BrowserSessionRepairReport(repairedActiveReferences: 1)
        } else if normalizedActiveSpaceID == nil, let firstSpaceID = normalizedSpaces.first?.id {
            normalizedActiveSpaceID = firstSpaceID
            report = report + BrowserSessionRepairReport(repairedActiveReferences: 1)
        }

        let activeSpaceTabs = normalizedSpaces.first(where: { $0.id == normalizedActiveSpaceID })?.tabIDs ?? []
        var normalizedActiveTabID = activeTabID
        if let activeTabID,
           !(validTabIDs.contains(activeTabID) && activeSpaceTabs.contains(activeTabID)) {
            normalizedActiveTabID = activeSpaceTabs.first
            report = report + BrowserSessionRepairReport(repairedActiveReferences: 1)
        } else if normalizedActiveTabID == nil {
            normalizedActiveTabID = activeSpaceTabs.first
                ?? normalizedSpaces.first(where: { $0.id == normalizedActiveSpaceID })?.activeTabID
                ?? persistedTabs.first?.id
            if normalizedActiveTabID != nil {
                report = report + BrowserSessionRepairReport(repairedActiveReferences: 1)
            }
        }

        return WindowNormalization(
            window: BrowserSessionWindow(
                spaces: normalizedSpaces,
                tabs: persistedTabs,
                activeSpaceID: normalizedActiveSpaceID,
                activeTabID: normalizedActiveTabID,
                layout: layout,
                density: density
            ),
            report: report
        )
    }
}

private func orderedUnique(_ ids: [String]) -> [String] {
    var seen = Set<String>()
    return ids.filter { seen.insert($0).inserted }
}

private func + (lhs: BrowserSessionRepairReport, rhs: BrowserSessionRepairReport) -> BrowserSessionRepairReport {
    BrowserSessionRepairReport(
        removedPrivateTabs: lhs.removedPrivateTabs + rhs.removedPrivateTabs,
        removedDanglingTabReferences: lhs.removedDanglingTabReferences + rhs.removedDanglingTabReferences,
        removedDuplicateTabReferences: lhs.removedDuplicateTabReferences + rhs.removedDuplicateTabReferences,
        repairedActiveReferences: lhs.repairedActiveReferences + rhs.repairedActiveReferences
    )
}
