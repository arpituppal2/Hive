import Foundation

/// Pure deletion policy for the bookmark tree.
///
/// Keeping descendant discovery separate from the UI/state owner makes the
/// destructive behavior deterministic and testable without constructing the
/// browser window. A missing ID is a safe no-op.
public enum BookmarkDeletionPolicy {
    /// Returns bookmarks with `bookmarkID` and every descendant removed.
    public static func deleting(bookmarkID: String, from bookmarks: [Bookmark]) -> [Bookmark] {
        guard bookmarks.contains(where: { $0.id == bookmarkID }) else {
            return bookmarks
        }

        var removedIDs: Set<String> = [bookmarkID]
        var changed = true
        while changed {
            changed = false
            for bookmark in bookmarks where bookmark.parentID.map(removedIDs.contains) == true {
                if removedIDs.insert(bookmark.id).inserted {
                    changed = true
                }
            }
        }
        return bookmarks.filter { !removedIDs.contains($0.id) }
    }
}
