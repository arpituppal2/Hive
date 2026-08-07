import Foundation
import Testing
@testable import HiveCore

@Suite("TabOrganizationNormalizer")
struct TabOrganizationNormalizerTests {
    private let profile = "profile-a"
    private let otherProfile = "profile-b"
    private let workspace = "workspace-a"
    private let otherWorkspace = "workspace-b"
    private let group = "group-a"

    private func snapshot(
        profiles: [TabOrganizationNormalizer.Profile] = [],
        workspaces: [TabOrganizationNormalizer.Workspace] = [],
        groups: [TabOrganizationNormalizer.Group] = [],
        tabs: [TabOrganizationNormalizer.Tab] = [],
        activeProfileID: String? = nil,
        activeWorkspaceID: String? = nil,
        activeTabID: String? = nil,
        splitSecondaryTabID: String? = nil
    ) -> TabOrganizationNormalizer.Snapshot {
        TabOrganizationNormalizer.Snapshot(
            profiles: profiles,
            workspaces: workspaces,
            groups: groups,
            tabs: tabs,
            activeProfileID: activeProfileID,
            activeWorkspaceID: activeWorkspaceID,
            activeTabID: activeTabID,
            splitSecondaryTabID: splitSecondaryTabID
        )
    }

    private func tab(
        _ id: String,
        workspaceID: String = "workspace-a",
        profileID: String = "profile-a",
        groupID: String? = nil,
        pinned: Bool = false,
        essential: Bool = false,
        isPrivate: Bool = false,
        urlString: String? = nil,
        savedURLString: String? = nil,
        isHibernated: Bool = false
    ) -> TabOrganizationNormalizer.Tab {
        TabOrganizationNormalizer.Tab(
            id: id,
            workspaceID: workspaceID,
            profileID: profileID,
            groupID: groupID,
            isPinned: pinned,
            isEssential: essential,
            isPrivate: isPrivate,
            urlString: urlString,
            savedURLString: savedURLString,
            isHibernated: isHibernated
        )
    }

    private var baseProfiles: [TabOrganizationNormalizer.Profile] {
        [.init(id: profile), .init(id: otherProfile)]
    }

    private var baseWorkspaces: [TabOrganizationNormalizer.Workspace] {
        [.init(id: workspace, profileID: profile), .init(id: otherWorkspace, profileID: otherProfile)]
    }

    @Test func preservesOrderWithinStableSemanticZones() {
        let result = TabOrganizationNormalizer.normalize(snapshot(
            profiles: [.init(id: profile)],
            workspaces: [.init(id: workspace, profileID: profile)],
            tabs: [
                tab("normal", urlString: "https://example.com", savedURLString: "https://example.com", isHibernated: true),
                tab("pinned", pinned: true),
                tab("essential", essential: true),
                tab("normal-2")
            ],
            activeProfileID: profile,
            activeWorkspaceID: workspace,
            activeTabID: "normal"
        ))

        #expect(result.snapshot.tabs.map(\.id) == ["essential", "pinned", "normal", "normal-2"])
        #expect(result.snapshot.tabs[2].urlString == "https://example.com")
        #expect(result.snapshot.tabs[2].savedURLString == "https://example.com")
        #expect(result.snapshot.tabs[2].isHibernated)
        #expect(result.repairReasons.isEmpty)
    }

    @Test func preservesWorkspaceBlockOrderWhileNormalizingEachWorkspace() {
        let result = TabOrganizationNormalizer.normalize(snapshot(
            profiles: baseProfiles,
            workspaces: baseWorkspaces,
            tabs: [
                tab("a-normal"),
                tab("b-pinned", workspaceID: otherWorkspace, profileID: otherProfile, pinned: true),
                tab("a-essential", essential: true),
                tab("b-normal", workspaceID: otherWorkspace, profileID: otherProfile)
            ],
            activeProfileID: profile,
            activeWorkspaceID: workspace,
            activeTabID: "a-normal"
        ))

        #expect(result.snapshot.tabs.map(\.id) == ["a-essential", "a-normal", "b-pinned", "b-normal"])
    }

    @Test func dropsPrivateAndDuplicateTabsKeepingFirstOccurrence() {
        let result = TabOrganizationNormalizer.normalize(snapshot(
            profiles: [.init(id: profile)],
            workspaces: [.init(id: workspace, profileID: profile)],
            tabs: [tab("a"), tab("a", pinned: true), tab("private", isPrivate: true)],
            activeProfileID: profile,
            activeWorkspaceID: workspace,
            activeTabID: "private"
        ))

        #expect(result.snapshot.tabs.map(\.id) == ["a"])
        #expect(result.repairReasons.contains(.duplicateTab("a")))
        #expect(result.repairReasons.contains(.privateTabDropped("private")))
        #expect(result.snapshot.activeTabID == "a")
        #expect(result.repairReasons.contains(.activeTabRepaired))
    }

    @Test func repairsMissingScopesAndClearsInvalidGroups() {
        let result = TabOrganizationNormalizer.normalize(snapshot(
            profiles: [.init(id: profile)],
            workspaces: [.init(id: workspace, profileID: profile)],
            groups: [.init(id: group, workspaceID: otherWorkspace)],
            tabs: [tab("orphan", workspaceID: "missing", profileID: "missing", groupID: group)],
            activeProfileID: profile,
            activeWorkspaceID: workspace,
            activeTabID: "orphan"
        ))

        let repaired = result.snapshot.tabs.first
        #expect(repaired?.workspaceID == workspace)
        #expect(repaired?.profileID == profile)
        #expect(repaired?.groupID == nil)
        #expect(result.repairReasons.contains(.tabMovedToFallbackProfile("orphan")))
        #expect(result.repairReasons.contains(.tabMovedToFallbackWorkspace("orphan")))
        #expect(result.repairReasons.contains(.tabGroupCleared("orphan")))
        #expect(result.snapshot.groups.isEmpty)
    }

    @Test func rejectsWorkspaceAndProfileMismatchForExistingRecords() {
        let result = TabOrganizationNormalizer.normalize(snapshot(
            profiles: baseProfiles,
            workspaces: baseWorkspaces,
            tabs: [tab("foreign", workspaceID: otherWorkspace, profileID: profile)],
            activeProfileID: profile,
            activeWorkspaceID: workspace,
            activeTabID: "foreign"
        ))

        #expect(result.snapshot.tabs.first?.workspaceID == workspace)
        #expect(result.snapshot.tabs.first?.profileID == profile)
        #expect(result.repairReasons.contains(.tabMovedToFallbackWorkspace("foreign")))
    }

    @Test func repairsActiveAndClearsCrossWorkspaceSplit() {
        let result = TabOrganizationNormalizer.normalize(snapshot(
            profiles: baseProfiles,
            workspaces: baseWorkspaces,
            tabs: [tab("active"), tab("secondary", workspaceID: otherWorkspace, profileID: otherProfile)],
            activeProfileID: profile,
            activeWorkspaceID: workspace,
            activeTabID: "missing",
            splitSecondaryTabID: "secondary"
        ))

        #expect(result.snapshot.activeTabID == "active")
        #expect(result.snapshot.splitSecondaryTabID == nil)
        #expect(result.repairReasons.contains(.activeTabRepaired))
        #expect(result.repairReasons.contains(.splitSecondaryTabCleared))
    }

    @Test func repairsDuplicateProfilesAndGroupsDeterministically() {
        let result = TabOrganizationNormalizer.normalize(snapshot(
            profiles: [.init(id: profile), .init(id: profile)],
            workspaces: [.init(id: workspace, profileID: profile)],
            groups: [.init(id: group, workspaceID: workspace), .init(id: group, workspaceID: workspace)],
            tabs: [tab("a", groupID: group)],
            activeProfileID: profile,
            activeWorkspaceID: workspace,
            activeTabID: "a"
        ))

        #expect(result.snapshot.profiles.count == 1)
        #expect(result.snapshot.groups.count == 1)
        #expect(result.snapshot.tabs.first?.groupID == group)
        #expect(result.repairReasons.contains(.duplicateProfile(profile)))
        #expect(result.repairReasons.contains(.duplicateGroup(group)))
    }
}
