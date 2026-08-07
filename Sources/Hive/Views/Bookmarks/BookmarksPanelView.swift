import SwiftUI
import AppKit
import HiveCore

// MARK: - BookmarksPanelView
//
// Bookmarks panel overlay (⌘B). Mirrors the HistoryView overlay pattern: a centered,
// searchable, material-backed panel. Bookmarks are rendered as a recursive tree with
// DisclosureGroup for folders and a flat list during search.

struct BookmarksPanelView: View {

    @Environment(ChromeState.self) private var state

    @State private var searchText = ""

    // New-folder dialog
    @State private var newFolderName = ""
    @State private var isShowingNewFolderDialog = false
    @State private var newFolderParentID: String? = nil
    @State private var newFolderParentTitle: String = ""

    // Rename dialog
    @State private var isShowingRenameDialog = false
    @State private var renameTarget: Bookmark? = nil
    @State private var renameTitle = ""

    // Delete confirmation
    @State private var isShowingDeleteConfirmation = false
    @State private var deleteTarget: Bookmark? = nil
    @State private var deleteTargetDescendantCount = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.hiveBorderSubtle)
            if visibleNodes.isEmpty && searchText.isEmpty {
                emptyState
            } else if visibleNodes.isEmpty {
                emptySearch
            } else {
                bookmarkList
            }
        }
        .frame(width: 420, height: 560)
        .background(Color.hiveBackground)
        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r12))
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
                .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .onChange(of: isShowingNewFolderDialog) { _, isShowing in
            if !isShowing { newFolderName = ""; newFolderParentID = nil; newFolderParentTitle = "" }
        }
        .onChange(of: isShowingRenameDialog) { _, isShowing in
            if !isShowing { renameTarget = nil; renameTitle = "" }
        }
        .onChange(of: isShowingDeleteConfirmation) { _, isShowing in
            if !isShowing { deleteTarget = nil; deleteTargetDescendantCount = 0 }
        }
        .onKeyPress(.escape) {
            // Let alerts handle their own Escape dismissal; don't close the panel
            // while a dialog is presented.
            if isShowingNewFolderDialog || isShowingRenameDialog || isShowingDeleteConfirmation {
                return .ignored
            }
            state.toggleBookmarksPanel()
            return .handled
        }
        .alert(newFolderAlertTitle, isPresented: $isShowingNewFolderDialog) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) { newFolderName = "" }
            Button("Create") {
                state.createBookmarkFolder(name: newFolderName, parentID: newFolderParentID)
                newFolderName = ""
            }
            .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            if !newFolderParentTitle.isEmpty {
                Text("Create a new folder inside \"\(newFolderParentTitle)\".")
            } else {
                Text("Create a new bookmark folder at the root level.")
            }
        }
        .alert("Rename", isPresented: $isShowingRenameDialog) {
            TextField("Name", text: $renameTitle)
            Button("Cancel", role: .cancel) {
                renameTarget = nil
                renameTitle = ""
            }
            Button("Save") {
                if let target = renameTarget {
                    state.renameBookmark(id: target.id, to: renameTitle)
                }
                renameTarget = nil
                renameTitle = ""
            }
            .disabled(renameTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Enter a new name for this bookmark or folder.")
        }
        .alert("Delete Bookmark?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let id = deleteTarget?.id { state.deleteBookmark(id: id) }
                deleteTarget = nil
            }
        } message: {
            if let target = deleteTarget {
                if deleteTargetDescendantCount > 0 {
                    let itemText = deleteTargetDescendantCount == 1 ? "1 item" : "\(deleteTargetDescendantCount) items"
                    Text("Delete \"\(target.title)\" and \(itemText) inside?")
                } else {
                    Text("Delete \"\(target.title)\"?")
                }
            }
        }
    }

    // MARK: Computed

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var newFolderAlertTitle: String {
        if !newFolderParentTitle.isEmpty {
            return "New Folder in \(newFolderParentTitle)"
        }
        return "New Folder"
    }

    /// Root-level nodes to display. Searching returns a flat list of leaf bookmarks
    /// that match the query; folders are not included in search results to avoid showing
    /// non-matching children.
    private var visibleNodes: [BookmarkNode] {
        if query.isEmpty {
            return state.rootBookmarks.map { BookmarkNode(item: $0) }
        } else {
            return state.prefs.bookmarks
                .filter { !$0.isFolder && matches($0, query: query) }
                .map { BookmarkNode(item: $0) }
        }
    }

    private func matches(_ bookmark: Bookmark, query: String) -> Bool {
        bookmark.title.lowercased().contains(query)
        || (bookmark.url?.absoluteString.lowercased().contains(query) ?? false)
    }

    private func presentRename(_ bookmark: Bookmark) {
        renameTarget = bookmark
        renameTitle = bookmark.title
        isShowingRenameDialog = true
    }

    private func presentDelete(_ bookmark: Bookmark) {
        deleteTarget = bookmark
        deleteTargetDescendantCount = bookmark.isFolder ? state.descendantCount(of: bookmark.id) : 0
        isShowingDeleteConfirmation = true
    }

    private func presentNewFolderInside(_ bookmark: Bookmark) {
        newFolderParentID = bookmark.id
        newFolderParentTitle = bookmark.title
        isShowingNewFolderDialog = true
    }

    /// Handles a bookmark drop from `.dropDestination`. Validates that the payload is a
    /// bookmark id, routes the move through `ChromeState`, and auto-expands the target
    /// folder so the user sees the result. Returns `true` only when the move succeeds.
    private func handleDrop(of items: [String], targetID: String?, dropOnFolder: Bool) -> Bool {
        guard let sourceID = items.first,
              state.prefs.bookmarks.contains(where: { $0.id == sourceID }) else { return false }
        let moved = state.moveBookmark(sourceID: sourceID, targetID: targetID, dropOnFolder: dropOnFolder)
        // Auto-expand the folder a bookmark was dropped into so the user sees the result.
        if moved, dropOnFolder, let folderID = targetID {
            newFolderParentID = folderID
        }
        return moved
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.bookmark")
                .font(HiveTypography.font(.panelTitle))
                .foregroundStyle(.hiveGraphite)
            Text("Bookmarks")
                .hiveType(.body)
                .foregroundStyle(.hiveInk)
            Spacer()
            Button {
                newFolderParentID = nil
                newFolderParentTitle = ""
                isShowingNewFolderDialog = true
            } label: {
                Image(systemName: "folder.badge.plus")
                    .font(HiveTypography.font(.bodyMedium))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("New Folder")
            Button {
                state.toggleBookmarksPanel()
            } label: {
                Image(systemName: "xmark")
                    .font(HiveTypography.font(.captionMedium))
                    .foregroundStyle(.hiveGraphite)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Empty states

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "book.bookmark")
                .font(HiveTypography.font(.display3))
                .foregroundStyle(.hiveMist)
            Text("No bookmarks yet")
                .hiveType(.body)
                .foregroundStyle(.hiveGraphite)
            Text("Press ⌘D on any page to save it here.")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveMist)
            Spacer()
        }
    }

    private var emptySearch: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No results for \"\(searchText)\"")
                .hiveType(.body)
                .foregroundStyle(.hiveGraphite)
            Spacer()
        }
    }

    // MARK: Bookmark list

    private var bookmarkList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(HiveTypography.font(.caption1))
                    .foregroundStyle(.hiveGraphite)
                TextField("Search bookmarks", text: $searchText)
                    .textFieldStyle(.plain)
                    .hiveType(.body)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: HiveRadius.r6).fill(Color.hiveSurface.opacity(0.5)))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleNodes) { node in
                        BookmarkTreeNodeView(node: node, depth: 0,
                                             newFolderParentID: newFolderParentID,
                                             onRename: presentRename,
                                             onDelete: presentDelete,
                                             onNewFolderInside: presentNewFolderInside,
                                             onDrop: handleDrop)
                    }
                }
                .padding(.horizontal, 12)
            }
            .dropDestination(for: String.self) { items, _ in
                handleDrop(of: items, targetID: nil, dropOnFolder: false)
            }
        }
    }
}

// MARK: - BookmarkTreeNodeView

/// Recursive view for a single bookmark node. Extracted into its own struct so the opaque
/// return type does not reference itself.
private struct BookmarkTreeNodeView: View {

    @Environment(ChromeState.self) private var state
    @State private var isExpanded = true

    let node: BookmarkNode
    let depth: Int
    let newFolderParentID: String?
    let onRename: (Bookmark) -> Void
    let onDelete: (Bookmark) -> Void
    let onNewFolderInside: (Bookmark) -> Void
    let onDrop: ([String], String?, Bool) -> Bool

    private var bookmark: Bookmark { node.item }

    var body: some View {
        if bookmark.isFolder {
            folderContent
        } else {
            itemContent
        }
    }

    // MARK: Folder

    private var folderContent: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                let children = state.prefs.bookmarks.filter { $0.parentID == bookmark.id }
                ForEach(children.map { BookmarkNode(item: $0) }) { child in
                    BookmarkTreeNodeView(node: child, depth: depth + 1,
                                         newFolderParentID: newFolderParentID,
                                         onRename: onRename,
                                         onDelete: onDelete,
                                         onNewFolderInside: onNewFolderInside,
                                         onDrop: onDrop)
                }
            },
            label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(HiveTypography.font(.caption1))
                        .foregroundStyle(.hiveGraphite)
                        .frame(width: 20, height: 20)
                    Text(bookmark.title.isEmpty ? "Untitled Folder" : bookmark.title)
                        .hiveType(.chromeTitle)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .padding(.leading, CGFloat(depth) * 16)
                .draggable(bookmark.id)
                .contextMenu {
                    Button("Rename") { onRename(bookmark) }
                    Button("New Folder Inside") { onNewFolderInside(bookmark) }
                    Button("Delete", role: .destructive) { onDelete(bookmark) }
                }
            }
        )
        .onChange(of: newFolderParentID) { _, newValue in
            if newValue == bookmark.id { isExpanded = true }
        }
        .dropDestination(for: String.self) { items, _ in
            onDrop(items, bookmark.id, true)
        }
    }

    // MARK: Item

    private var itemContent: some View {
        Button {
            if let url = bookmark.url {
                state.newTab(url: url)
                state.toggleBookmarksPanel()
            }
        } label: {
            HStack(spacing: 10) {
                bookmarkIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(bookmark.title.isEmpty ? (bookmark.url?.host ?? "Untitled") : bookmark.title)
                        .hiveType(.chromeTitle)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let url = bookmark.url, let host = url.host {
                        Text(host)
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveGraphite)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .padding(.leading, CGFloat(depth) * 16)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename") { onRename(bookmark) }
            if let url = bookmark.url {
                Button("Open in New Tab") {
                    state.newTab(url: url)
                    state.toggleBookmarksPanel()
                }
                Button("Copy Address") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .URL)
                }
                Divider()
            }
            Button("Delete", role: .destructive) { onDelete(bookmark) }
        }
        .draggable(bookmark.id)
        .dropDestination(for: String.self) { items, _ in
            onDrop(items, bookmark.id, false)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var bookmarkIcon: some View {
        if let fav = bookmark.faviconURL {
            FaviconView(url: fav)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r4))
        } else {
            Image(systemName: "globe")
                .font(HiveTypography.font(.caption2))
                .foregroundStyle(.hiveGraphite)
                .frame(width: 20, height: 20)
        }
    }

    private var accessibilityLabel: String {
        if bookmark.isFolder { return "Folder: \(bookmark.title)" }
        return "Bookmark: \(bookmark.title)"
    }
}

// MARK: - BookmarkNode

private struct BookmarkNode: Identifiable {
    let id: String
    let item: Bookmark

    init(item: Bookmark) {
        self.id = item.id
        self.item = item
    }
}
