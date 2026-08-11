import Foundation

// MARK: - BookmarkFolderNode
//
// The minimal shape the folder policy needs: a bookmark's id and its parent
// folder's id (nil = root). The app maps its richer Bookmark model onto this
// so every folder decision — scoping, descendant enumeration, and cycle-safe
// moves — stays pure and deterministic in HiveCore.

public struct BookmarkFolderNode: Sendable, Equatable {
    public let id: UUID
    public let parentID: UUID?

    public init(id: UUID, parentID: UUID?) {
        self.id = id
        self.parentID = parentID
    }
}

// MARK: - BookmarkFolderPolicy
//
// Pure rules for a nested bookmark tree (Chrome/Safari parity). The tree is
// represented as a flat array of nodes with optional parent links; a folder
// is just a node that other nodes point at.

public enum BookmarkFolderPolicy {

    /// The nodes that sit at the root of the tree (no parent).
    public static func rootNodes(in nodes: [BookmarkFolderNode]) -> [BookmarkFolderNode] {
        nodes.filter { $0.parentID == nil }
    }

    /// The direct children of `parentID` (nil = root children), preserving
    /// the array order.
    public static func children(of parentID: UUID?, in nodes: [BookmarkFolderNode]) -> [BookmarkFolderNode] {
        nodes.filter { $0.parentID == parentID }
    }

    /// Every descendant id of `nodeID` (children, grandchildren, …).
    /// Used to scope a folder deletion: deleting a folder removes its entire
    /// subtree, and every removed record must be tombstoned individually so
    /// remote devices converge instead of orphaning children.
    public static func descendantIDs(of nodeID: UUID, in nodes: [BookmarkFolderNode]) -> Set<UUID> {
        var result: Set<UUID> = []
        var frontier = children(of: nodeID, in: nodes).map(\.id)
        while let next = frontier.popLast() {
            guard result.insert(next).inserted else { continue }
            frontier.append(contentsOf: children(of: next, in: nodes).map(\.id))
        }
        return result
    }

    /// Whether `nodeID` can be moved under `newParentID` without creating a
    /// cycle. A node cannot become its own parent, and a folder cannot be
    /// moved into one of its own descendants (that would make the tree cyclic
    /// and break every descendant enumeration).
    public static func canMove(
        nodeID: UUID,
        toParent newParentID: UUID?,
        in nodes: [BookmarkFolderNode]
    ) -> Bool {
        guard let newParentID else { return true } // moving to the root is always safe
        guard newParentID != nodeID else { return false } // self-parent
        // A non-folder target is still rejected here defensively: only nodes
        // that appear as a parent of something (or could later) are treated
        // as folders, and a bookmark has no children.
        return !descendantIDs(of: nodeID, in: nodes).contains(newParentID)
    }

    /// Normalizes a user-typed folder name: trimmed, non-empty, capped.
    /// Falls back to "New Folder" so an empty name can never create a blank
    /// row in the tree.
    public static func normalizedFolderName(_ name: String, fallback: String = "New Folder") -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(120))
    }
}
