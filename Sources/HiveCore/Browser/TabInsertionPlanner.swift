import Foundation

/// Pure insertion semantics shared by browser chrome implementations.
///
/// The planner deliberately works with stable IDs rather than view or backing-array
/// indices. Browser chrome commonly presents filtered projections (workspace, pinned,
/// grouped, or ungrouped tabs); using a raw global index from one of those projections
/// can move the wrong tab. The caller supplies the current ordered projection and then
/// applies the returned IDs to its own state.
public enum TabInsertionPlanner {

    public struct Item: Sendable, Equatable {
        public let id: String
        public let workspaceID: UUID
        public let groupID: UUID?
        public let isPinned: Bool
        public let isEssential: Bool

        public init(
            id: String,
            workspaceID: UUID,
            groupID: UUID? = nil,
            isPinned: Bool = false,
            isEssential: Bool = false
        ) {
            self.id = id
            self.workspaceID = workspaceID
            self.groupID = groupID
            self.isPinned = isPinned
            self.isEssential = isEssential
        }
    }

    public enum Edge: String, Sendable, Equatable {
        case before
        case after
    }

    public struct DropTarget: Sendable, Equatable {
        public let tabID: String
        public let edge: Edge

        public init(tabID: String, edge: Edge) {
            self.tabID = tabID
            self.edge = edge
        }
    }

    /// Computes the ordered IDs after moving `movingID` before or after `target`.
    ///
    /// Returns nil for an invalid move. Invalid means the source/target is missing,
    /// belongs to another workspace, crosses a pinned/essential boundary, or crosses
    /// a group boundary. Group membership changes remain an explicit operation through
    /// the browser's "Move to Group" command; a reorder gesture must not silently
    /// change durable organization.
    public static func reordered(
        items: [Item],
        movingID: String,
        target: DropTarget,
        activeWorkspaceID: UUID
    ) -> [String]? {
        guard !items.isEmpty,
              let source = items.first(where: { $0.id == movingID }),
              let destination = items.first(where: { $0.id == target.tabID }),
              source.id != destination.id,
              source.workspaceID == activeWorkspaceID,
              destination.workspaceID == activeWorkspaceID,
              source.workspaceID == destination.workspaceID,
              source.isPinned == destination.isPinned,
              source.isEssential == destination.isEssential,
              source.groupID == destination.groupID,
              Set(items.map(\.id)).count == items.count
        else { return nil }

        var ids = items.map(\.id)
        guard let sourceIndex = ids.firstIndex(of: movingID) else { return nil }
        ids.remove(at: sourceIndex)
        guard let destinationIndex = ids.firstIndex(of: target.tabID) else { return nil }

        let insertionIndex = target.edge == .before ? destinationIndex : destinationIndex + 1
        ids.insert(movingID, at: insertionIndex)
        return ids
    }
}
