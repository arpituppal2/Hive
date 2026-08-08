import Foundation
import Testing
@testable import HiveCore

@Suite("BookmarkDeletionPolicy")
struct BookmarkDeletionPolicyTests {
    @Test("deleting a leaf removes only that bookmark")
    func deletingLeaf() {
        let first = Bookmark(id: "first", title: "First", url: URL(string: "https://first.example"))
        let second = Bookmark(id: "second", title: "Second", url: URL(string: "https://second.example"))

        let result = BookmarkDeletionPolicy.deleting(bookmarkID: "first", from: [first, second])

        #expect(result.map(\.id) == ["second"])
    }

    @Test("deleting a folder removes all descendants at every depth")
    func deletingFolderRecursively() {
        let folder = Bookmark(id: "folder", title: "Folder", isFolder: true)
        let childFolder = Bookmark(id: "child-folder", title: "Child", isFolder: true, parentID: "folder")
        let leaf = Bookmark(id: "leaf", title: "Leaf", url: URL(string: "https://leaf.example"), parentID: "child-folder")
        let unrelated = Bookmark(id: "unrelated", title: "Unrelated", url: URL(string: "https://unrelated.example"))

        let result = BookmarkDeletionPolicy.deleting(
            bookmarkID: "folder",
            from: [folder, childFolder, leaf, unrelated]
        )

        #expect(result.map(\.id) == ["unrelated"])
    }

    @Test("missing bookmark IDs are safe no-ops")
    func missingID() {
        let bookmark = Bookmark(id: "known", title: "Known", url: URL(string: "https://known.example"))
        let result = BookmarkDeletionPolicy.deleting(bookmarkID: "missing", from: [bookmark])
        #expect(result == [bookmark])
    }

    @Test("cyclic child metadata cannot expand deletion forever")
    func cyclicMetadata() {
        let first = Bookmark(id: "first", title: "First", isFolder: true, parentID: "second")
        let second = Bookmark(id: "second", title: "Second", isFolder: true, parentID: "first")
        let unrelated = Bookmark(id: "unrelated", title: "Unrelated", url: URL(string: "https://unrelated.example"))

        let result = BookmarkDeletionPolicy.deleting(bookmarkID: "first", from: [first, second, unrelated])

        #expect(result.map(\.id) == ["unrelated"])
    }
}
