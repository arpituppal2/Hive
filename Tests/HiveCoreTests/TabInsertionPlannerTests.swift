import Foundation
import Testing
@testable import HiveCore

@Suite("TabInsertionPlanner")
struct TabInsertionPlannerTests {
    private let workspace = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let otherWorkspace = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let researchGroup = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    private func item(
        _ id: String,
        workspaceID: UUID? = nil,
        groupID: UUID? = nil,
        pinned: Bool = false,
        essential: Bool = false
    ) -> TabInsertionPlanner.Item {
        TabInsertionPlanner.Item(
            id: id,
            workspaceID: workspaceID ?? workspace,
            groupID: groupID,
            isPinned: pinned,
            isEssential: essential
        )
    }

    @Test func movesBeforeAndAfterByStableID() {
        let items = [item("a"), item("b"), item("c")]
        #expect(TabInsertionPlanner.reordered(
            items: items,
            movingID: "c",
            target: .init(tabID: "a", edge: .before),
            activeWorkspaceID: workspace
        ) == ["c", "a", "b"])
        #expect(TabInsertionPlanner.reordered(
            items: items,
            movingID: "a",
            target: .init(tabID: "c", edge: .after),
            activeWorkspaceID: workspace
        ) == ["b", "c", "a"])
    }

    @Test func rejectsSelfAndMissingTargets() {
        let items = [item("a"), item("b")]
        #expect(TabInsertionPlanner.reordered(
            items: items,
            movingID: "a",
            target: .init(tabID: "a", edge: .before),
            activeWorkspaceID: workspace
        ) == nil)
        #expect(TabInsertionPlanner.reordered(
            items: items,
            movingID: "missing",
            target: .init(tabID: "a", edge: .before),
            activeWorkspaceID: workspace
        ) == nil)
    }

    @Test func rejectsCrossWorkspaceMoves() {
        let items = [item("a"), item("foreign", workspaceID: otherWorkspace)]
        #expect(TabInsertionPlanner.reordered(
            items: items,
            movingID: "a",
            target: .init(tabID: "foreign", edge: .after),
            activeWorkspaceID: workspace
        ) == nil)
        #expect(TabInsertionPlanner.reordered(
            items: items,
            movingID: "foreign",
            target: .init(tabID: "a", edge: .after),
            activeWorkspaceID: workspace
        ) == nil)
    }

    @Test func rejectsPinnedAndEssentialBoundaryCrossings() {
        let items = [item("pinned", pinned: true), item("normal")]
        #expect(TabInsertionPlanner.reordered(
            items: items,
            movingID: "normal",
            target: .init(tabID: "pinned", edge: .before),
            activeWorkspaceID: workspace
        ) == nil)

        let essentials = [item("essential", essential: true), item("normal")]
        #expect(TabInsertionPlanner.reordered(
            items: essentials,
            movingID: "normal",
            target: .init(tabID: "essential", edge: .after),
            activeWorkspaceID: workspace
        ) == nil)
    }

    @Test func rejectsImplicitGroupChanges() {
        let items = [item("research-a", groupID: researchGroup), item("ungrouped")]
        #expect(TabInsertionPlanner.reordered(
            items: items,
            movingID: "research-a",
            target: .init(tabID: "ungrouped", edge: .after),
            activeWorkspaceID: workspace
        ) == nil)
    }

    @Test func rejectsDuplicateIDs() {
        let items = [item("a"), item("a"), item("b")]
        #expect(TabInsertionPlanner.reordered(
            items: items,
            movingID: "b",
            target: .init(tabID: "a", edge: .before),
            activeWorkspaceID: workspace
        ) == nil)
    }

@Test func identicalWorkspacesAllowMove() {
        let items = [item("a"), item("b")]
        let result = TabInsertionPlanner.reordered(
            items: items, movingID: "b",
            target: .init(tabID: "a", edge: .before),
            activeWorkspaceID: workspace
        )
        #expect(result == ["b", "a"])
    }

    @Test func singleItemListCannotReorder() {
        let items = [item("only")]
        #expect(TabInsertionPlanner.reordered(
            items: items, movingID: "only",
            target: .init(tabID: "only", edge: .before),
            activeWorkspaceID: workspace
        ) == nil)
    }
}
