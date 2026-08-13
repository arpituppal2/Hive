import Foundation

/// Repairs the durable organization relationships that browser chrome presents
/// as workspaces, groups, pinned zones, and active/split tabs.
///
/// This type is deliberately independent of CEF and SwiftUI. Session data is
/// user-owned input and may be stale after a crash, an interrupted migration,
/// or an older schema. The normalizer either repairs a record deterministically
/// or drops it when retaining it would create an invalid browser scope.
public enum TabOrganizationNormalizer {
    public struct Profile: Sendable, Equatable {
        public let id: String

        public init(id: String) {
            self.id = id
        }
    }

    public struct Workspace: Sendable, Equatable {
        public let id: String
        public let profileID: String

        public init(id: String, profileID: String) {
            self.id = id
            self.profileID = profileID
        }
    }

    public struct Group: Sendable, Equatable {
        public let id: String
        public let workspaceID: String

        public init(id: String, workspaceID: String) {
            self.id = id
            self.workspaceID = workspaceID
        }
    }

    public struct Tab: Sendable, Equatable {
        public let id: String
        public let workspaceID: String
        public let profileID: String
        public let groupID: String?
        public let isPinned: Bool
        public let isEssential: Bool
        public let isPrivate: Bool
        public let urlString: String?
        public let savedURLString: String?
        public let isHibernated: Bool

        public init(
            id: String,
            workspaceID: String,
            profileID: String,
            groupID: String? = nil,
            isPinned: Bool = false,
            isEssential: Bool = false,
            isPrivate: Bool = false,
            urlString: String? = nil,
            savedURLString: String? = nil,
            isHibernated: Bool = false
        ) {
            self.id = id
            self.workspaceID = workspaceID
            self.profileID = profileID
            self.groupID = groupID
            self.isPinned = isPinned
            self.isEssential = isEssential
            self.isPrivate = isPrivate
            self.urlString = urlString
            self.savedURLString = savedURLString
            self.isHibernated = isHibernated
        }
    }

    public struct Snapshot: Sendable, Equatable {
        public var profiles: [Profile]
        public var workspaces: [Workspace]
        public var groups: [Group]
        public var tabs: [Tab]
        public var activeProfileID: String?
        public var activeWorkspaceID: String?
        public var activeTabID: String?
        public var splitSecondaryTabID: String?

        public init(
            profiles: [Profile] = [],
            workspaces: [Workspace] = [],
            groups: [Group] = [],
            tabs: [Tab] = [],
            activeProfileID: String? = nil,
            activeWorkspaceID: String? = nil,
            activeTabID: String? = nil,
            splitSecondaryTabID: String? = nil
        ) {
            self.profiles = profiles
            self.workspaces = workspaces
            self.groups = groups
            self.tabs = tabs
            self.activeProfileID = activeProfileID
            self.activeWorkspaceID = activeWorkspaceID
            self.activeTabID = activeTabID
            self.splitSecondaryTabID = splitSecondaryTabID
        }
    }

    public enum RepairReason: Sendable, Equatable {
        case duplicateProfile(String)
        case duplicateWorkspace(String)
        case duplicateGroup(String)
        case duplicateTab(String)
        case privateTabDropped(String)
        case invalidGroupDropped(String)
        case tabMovedToFallbackProfile(String)
        case tabMovedToFallbackWorkspace(String)
        case tabDroppedWithoutValidScope(String)
        case tabGroupCleared(String)
        case activeProfileRepaired
        case activeWorkspaceRepaired
        case activeTabRepaired
        case splitSecondaryTabCleared
    }

    public struct Result: Sendable, Equatable {
        public let snapshot: Snapshot
        public let repairReasons: [RepairReason]

        public init(snapshot: Snapshot, repairReasons: [RepairReason]) {
            self.snapshot = snapshot
            self.repairReasons = repairReasons
        }
    }

    /// Normalizes a serialized browser snapshot deterministically.
    ///
    /// The first occurrence of a duplicate durable ID wins. Tab order is
    /// preserved within each semantic zone, then zones are stably arranged as
    /// essential, pinned non-essential, and ordinary. Invalid organization
    /// references are repaired to the nearest valid scope; tabs with no valid
    /// profile/workspace scope are dropped rather than retained with dangling
    /// references.
    public static func normalize(_ input: Snapshot) -> Result {
        var reasons: [RepairReason] = []

        let profiles = unique(input.profiles, id: \.id) { id in
            reasons.append(.duplicateProfile(id))
        }
        let profileIDs = Set(profiles.map(\.id))
        let profileByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        let workspaces = unique(input.workspaces, id: \.id) { id in
            reasons.append(.duplicateWorkspace(id))
        }.filter { profileIDs.contains($0.profileID) }
        let workspaceByID = Dictionary(uniqueKeysWithValues: workspaces.map { ($0.id, $0) })
        let workspacesByProfile = Dictionary(grouping: workspaces, by: \.profileID)

        let requestedProfile = input.activeProfileID.flatMap { profileByID[$0] }
        let fallbackProfile = requestedProfile ?? profiles.first
        if input.activeProfileID != fallbackProfile?.id {
            reasons.append(.activeProfileRepaired)
        }

        let requestedWorkspace = input.activeWorkspaceID.flatMap { workspaceByID[$0] }
        let activeWorkspace: Workspace? = {
            guard let requestedWorkspace else {
                return fallbackProfile.flatMap { workspacesByProfile[$0.id]?.first }
            }
            guard requestedWorkspace.profileID == fallbackProfile?.id else {
                return fallbackProfile.flatMap { workspacesByProfile[$0.id]?.first }
            }
            return requestedWorkspace
        }()
        if input.activeWorkspaceID != activeWorkspace?.id {
            reasons.append(.activeWorkspaceRepaired)
        }

        let groups = unique(input.groups, id: \.id) { id in
            reasons.append(.duplicateGroup(id))
        }.filter { group in
            guard let workspace = workspaceByID[group.workspaceID] else {
                reasons.append(.invalidGroupDropped(group.id))
                return false
            }
            guard profileIDs.contains(workspace.profileID) else {
                reasons.append(.invalidGroupDropped(group.id))
                return false
            }
            return true
        }
        let groupByID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })

        let uniqueTabs = unique(input.tabs, id: \.id) { id in
            reasons.append(.duplicateTab(id))
        }
        var repairedTabs: [Tab] = []
        repairedTabs.reserveCapacity(uniqueTabs.count)

        for original in uniqueTabs {
            guard !original.isPrivate else {
                reasons.append(.privateTabDropped(original.id))
                continue
            }

            guard !profiles.isEmpty, !workspaces.isEmpty else {
                reasons.append(.tabDroppedWithoutValidScope(original.id))
                continue
            }

            let profile: Profile
            if let existing = profileByID[original.profileID] {
                profile = existing
            } else if let fallbackProfile {
                profile = fallbackProfile
                reasons.append(.tabMovedToFallbackProfile(original.id))
            } else {
                reasons.append(.tabDroppedWithoutValidScope(original.id))
                continue
            }

            let workspace: Workspace?
            if let existing = workspaceByID[original.workspaceID], existing.profileID == profile.id {
                workspace = existing
            } else {
                workspace = workspacesByProfile[profile.id]?.first
                if workspace != nil {
                    reasons.append(.tabMovedToFallbackWorkspace(original.id))
                }
            }

            guard let workspace else {
                reasons.append(.tabDroppedWithoutValidScope(original.id))
                continue
            }

            let groupID: String?
            if let originalGroupID = original.groupID,
               let group = groupByID[originalGroupID],
               group.workspaceID == workspace.id {
                groupID = group.id
            } else if original.groupID != nil {
                groupID = nil
                reasons.append(.tabGroupCleared(original.id))
            } else {
                groupID = nil
            }

            repairedTabs.append(Tab(
                id: original.id,
                workspaceID: workspace.id,
                profileID: profile.id,
                groupID: groupID,
                isPinned: original.isPinned,
                isEssential: original.isEssential,
                isPrivate: false,
                urlString: original.urlString,
                savedURLString: original.savedURLString,
                isHibernated: original.isHibernated
            ))
        }

        // Preserve the serialized workspace block order, then stabilize the
        // semantic zones inside each workspace. The visible tab rail is scoped
        // to one workspace; a pinned tab in workspace B must not leapfrog an
        // ordinary tab in workspace A merely because it is pinned.
        var workspaceOrder: [String] = []
        var seenWorkspaceIDs = Set<String>()
        for tab in repairedTabs where seenWorkspaceIDs.insert(tab.workspaceID).inserted {
            workspaceOrder.append(tab.workspaceID)
        }
        let orderedTabs = workspaceOrder.flatMap { workspaceID in
            repairedTabs
                .enumerated()
                .filter { $0.element.workspaceID == workspaceID }
                .sorted { lhs, rhs in
                    let lhsZone = zone(for: lhs.element)
                    let rhsZone = zone(for: rhs.element)
                    if lhsZone != rhsZone { return lhsZone < rhsZone }
                    return lhs.offset < rhs.offset
                }
                .map(\.element)
        }
        let survivingIDs = Set(orderedTabs.map(\.id))

        let activeTabID: String?
        if let requested = input.activeTabID,
           survivingIDs.contains(requested),
           orderedTabs.first(where: { $0.id == requested })?.workspaceID == activeWorkspace?.id {
            activeTabID = requested
        } else {
            activeTabID = orderedTabs.first(where: { $0.workspaceID == activeWorkspace?.id })?.id
                ?? orderedTabs.first?.id
            if input.activeTabID != activeTabID {
                reasons.append(.activeTabRepaired)
            }
        }

        let splitSecondaryTabID: String?
        if let requested = input.splitSecondaryTabID,
           requested != activeTabID,
           survivingIDs.contains(requested),
           orderedTabs.first(where: { $0.id == requested })?.workspaceID == activeWorkspace?.id {
            splitSecondaryTabID = requested
        } else {
            splitSecondaryTabID = nil
            if input.splitSecondaryTabID != nil {
                reasons.append(.splitSecondaryTabCleared)
            }
        }

        return Result(
            snapshot: Snapshot(
                profiles: profiles,
                workspaces: workspaces,
                groups: groups,
                tabs: orderedTabs,
                activeProfileID: fallbackProfile?.id,
                activeWorkspaceID: activeWorkspace?.id,
                activeTabID: activeTabID,
                splitSecondaryTabID: splitSecondaryTabID
            ),
            repairReasons: reasons
        )
    }

    private static func zone(for tab: Tab) -> Int {
        if tab.isEssential { return 0 }
        if tab.isPinned { return 1 }
        return 2
    }

    private static func unique<Value, ID: Hashable>(
        _ values: [Value],
        id: (Value) -> ID,
        onDuplicate: (ID) -> Void
    ) -> [Value] {
        var seen = Set<ID>()
        return values.filter { value in
            let valueID = id(value)
            guard seen.insert(valueID).inserted else {
                onDuplicate(valueID)
                return false
            }
            return true
        }
    }
}
