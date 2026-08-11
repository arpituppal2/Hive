import Foundation
import Testing
@testable import HiveCore

@Suite("BookmarkFolderPolicy")
struct BookmarkFolderPolicyTests {

    private let work = UUID()
    private let personal = UUID()
    private let deep = UUID()
    private let deepest = UUID()
    private let pageA = UUID()
    private let pageB = UUID()

    /// work → [pageA, deep → [deepest]]
    /// personal → [pageB]
    private var tree: [BookmarkFolderNode] {
        [
            BookmarkFolderNode(id: work, parentID: nil),
            BookmarkFolderNode(id: personal, parentID: nil),
            BookmarkFolderNode(id: pageA, parentID: work),
            BookmarkFolderNode(id: deep, parentID: work),
            BookmarkFolderNode(id: deepest, parentID: deep),
            BookmarkFolderNode(id: pageB, parentID: personal)
        ]
    }

    @Test func rootNodesExcludesEverythingNested() {
        let roots = BookmarkFolderPolicy.rootNodes(in: tree)
        #expect(Set(roots.map(\.id)) == [work, personal])
    }

    @Test func childrenOfFolder() {
        let children = BookmarkFolderPolicy.children(of: work, in: tree)
        #expect(Set(children.map(\.id)) == [pageA, deep])
    }

    @Test func childrenOfRoot() {
        let children = BookmarkFolderPolicy.children(of: nil, in: tree)
        #expect(Set(children.map(\.id)) == [work, personal])
    }

    @Test func descendantIDsAreRecursive() {
        let ids = BookmarkFolderPolicy.descendantIDs(of: work, in: tree)
        #expect(ids == [pageA, deep, deepest])
        #expect(!ids.contains(work))
        #expect(!ids.contains(pageB))
    }

    @Test func descendantIDsOfLeafAreEmpty() {
        #expect(BookmarkFolderPolicy.descendantIDs(of: pageA, in: tree).isEmpty)
    }

    @Test func moveToRootIsAlwaysAllowed() {
        #expect(BookmarkFolderPolicy.canMove(nodeID: pageA, toParent: nil, in: tree))
    }

    @Test func moveIntoNewFolderIsAllowed() {
        let newFolder = UUID()
        var extended = tree
        extended.append(BookmarkFolderNode(id: newFolder, parentID: nil))
        #expect(BookmarkFolderPolicy.canMove(nodeID: pageA, toParent: newFolder, in: extended))
    }

    @Test func selfParentIsRejected() {
        #expect(!BookmarkFolderPolicy.canMove(nodeID: work, toParent: work, in: tree))
    }

    @Test func movingIntoOwnDescendantIsRejected() {
        // `work` cannot move under `deep` — deep is a descendant of work.
        #expect(!BookmarkFolderPolicy.canMove(nodeID: work, toParent: deep, in: tree))
        // Nor under `deepest`.
        #expect(!BookmarkFolderPolicy.canMove(nodeID: work, toParent: deepest, in: tree))
    }

    @Test func movingIntoUnrelatedFolderIsAllowed() {
        // `work` (and its whole subtree) can move under `personal`.
        #expect(BookmarkFolderPolicy.canMove(nodeID: work, toParent: personal, in: tree))
        // A leaf can move into any folder.
        #expect(BookmarkFolderPolicy.canMove(nodeID: pageA, toParent: personal, in: tree))
    }

    @Test func normalizedFolderNameTrimsAndFallsBack() {
        #expect(BookmarkFolderPolicy.normalizedFolderName("   Work  ") == "Work")
        #expect(BookmarkFolderPolicy.normalizedFolderName("   ") == "New Folder")
        #expect(BookmarkFolderPolicy.normalizedFolderName("") == "New Folder")
        #expect(BookmarkFolderPolicy.normalizedFolderName("", fallback: "Untitled") == "Untitled")
    }

    @Test func normalizedFolderNameCapsLength() {
        let long = String(repeating: "x", count: 300)
        #expect(BookmarkFolderPolicy.normalizedFolderName(long).count == 120)
    }

    @Test func folderTreeSurvivesRoundTripThroughPayloadFields() {
        // A folder payload round-trips through the SyncPayload codec with its
        // identity fields intact (parentID/isFolder are the sync contract).
        let payload = SyncPayload(
            kind: .bookmark,
            recordID: work.uuidString,
            revision: 3,
            deviceID: "device-a",
            title: "Work",
            parentID: nil,
            isFolder: true
        )
        let data = try! JSONEncoder().encode(payload)
        let decoded = try! JSONDecoder().decode(SyncPayload.self, from: data)
        #expect(decoded.isFolder == true)
        #expect(decoded.parentID == nil)
        #expect(decoded.kind == .bookmark)
        #expect(decoded.recordID == work.uuidString)
    }

    @Test func legacyBookmarkEnvelopeDecodesAsRootContent() {
        // An envelope written BEFORE folder fields shipped must decode as a
        // root-level content bookmark (isFolder=false, parentID=nil).
        let legacyJSON = """
        {"kind":"bookmark","recordID":"\(pageA.uuidString)","revision":1,
         "updatedAt":1.0,"deviceID":"device-a","url":"https://example.com/a",
         "title":"A"}
        """
        let decoded = try! JSONDecoder().decode(SyncPayload.self, from: Data(legacyJSON.utf8))
        #expect(decoded.isFolder == false)
        #expect(decoded.parentID == nil)
        #expect(decoded.url == "https://example.com/a")
    }
}
