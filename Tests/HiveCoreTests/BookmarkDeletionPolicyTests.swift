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

    @Test("deleting the only bookmark returns empty array")
    func deletingLastBookmark() {
        let only = Bookmark(id: "only", title: "Only", url: URL(string: "https://only.example"))
        let result = BookmarkDeletionPolicy.deleting(bookmarkID: "only", from: [only])
        #expect(result.isEmpty)
    }

    @Test("deleting from empty list is safe")
    func deletingFromEmpty() {
        let result = BookmarkDeletionPolicy.deleting(bookmarkID: "any", from: [])
        #expect(result.isEmpty)
    }

    @Test("deleting a leaf preserves sibling order")
    func preservesOrder() {
        let a = Bookmark(id: "a", title: "A", url: URL(string: "https://a.example"))
        let b = Bookmark(id: "b", title: "B", url: URL(string: "https://b.example"))
        let c = Bookmark(id: "c", title: "C", url: URL(string: "https://c.example"))
        let result = BookmarkDeletionPolicy.deleting(bookmarkID: "b", from: [a, b, c])
        #expect(result.map(\.id) == ["a", "c"])
    }

    @Test("deleting a deeply nested leaf removes only that leaf")
    func deepNestingDeletesOnlyTarget() {
        let root = Bookmark(id: "root", title: "Root", isFolder: true)
        let child = Bookmark(id: "child", title: "Child", isFolder: true, parentID: "root")
        let grandchild = Bookmark(id: "gc", title: "Grandchild", url: URL(string: "https://gc.example"), parentID: "child")
        let sibling = Bookmark(id: "sib", title: "Sibling", url: URL(string: "https://sib.example"), parentID: "child")
        let result = BookmarkDeletionPolicy.deleting(bookmarkID: "gc", from: [root, child, grandchild, sibling])
        #expect(result.map(\.id).sorted() == ["child", "root", "sib"])
    }

@Test func bookmarkHostStripsWWW() {
        let bm = Bookmark(title: "Test", url: URL(string: "https://www.example.com")!)
        #expect(bm.host == "example.com")
    }

@Test func deletingNonExistentIDReturnsSameList() {
        let bm = Bookmark(title: "A", url: URL(string: "https://a.com")!)
        let result = BookmarkDeletionPolicy.deleting(bookmarkID: "nonexistent", from: [bm])
        #expect(result.count == 1)
    }
}
