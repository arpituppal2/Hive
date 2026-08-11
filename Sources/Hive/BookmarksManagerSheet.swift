import SwiftUI
import AppKit
import HiveCore
import UniformTypeIdentifiers

// MARK: - BookmarksManagerSheet
//
// Safari/Chrome-style bookmarks manager with search, favicons, import from
// other browsers, delete — and Chrome/Safari-parity FOLDERS. The tree is
// navigated by drilling into folder rows (breadcrumb path on top); search
// still scans the whole tree flat. Import is non-destructive — valid browser
// data is merged, duplicates are skipped, and unsafe URLs are ignored.

struct BookmarksManagerSheet: View {
    @Environment(BrowserState.self) private var state
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var showImportSheet: Bool = false
    @State private var importResultMessage: String? = nil
    @State private var exportError: String? = nil

    // Folder management dialogs
    @State private var showNewFolder: Bool = false
    @State private var newFolderDraft: String = ""
    @State private var renameTarget: Bookmark? = nil
    @State private var renameDraft: String = ""
    @State private var deleteFolderTarget: Bookmark? = nil

    private var currentFolderID: UUID? { state.bookmarksManagerFolderID }

    /// Items at the current navigation level (no search).
    private var scopedBookmarks: [Bookmark] {
        state.bookmarks(in: currentFolderID)
    }

    /// Search is flat across the whole tree; browsing is scoped.
    private var filteredBookmarks: [Bookmark] {
        guard !searchText.isEmpty else { return scopedBookmarks }
        let q = searchText.lowercased()
        return state.bookmarks.filter {
            $0.title.lowercased().contains(q) ||
            $0.urlString.lowercased().contains(q)
        }
    }

    /// The breadcrumb path from root down to the current folder (folders only).
    private var folderChain: [Bookmark] {
        var chain: [Bookmark] = []
        var cursor = currentFolderID
        var seen = Set<UUID>()
        while let id = cursor, seen.insert(id).inserted,
              let folder = state.bookmarks.first(where: { $0.id == id && $0.isFolder }) {
            chain.append(folder)
            cursor = folder.parentID
        }
        return chain.reversed()
    }

    /// Every folder a bookmark can be moved into, excluding itself and any
    /// folder inside its own subtree (cycle guard mirrored from the policy).
    private func moveDestinations(for item: Bookmark) -> [Bookmark] {
        let excluded = Set<UUID>([item.id]).union(
            BookmarkFolderPolicy.descendantIDs(of: item.id, in: state.folderNodes())
        )
        return state.bookmarks.filter { $0.isFolder && !excluded.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "bookmark.fill")
                    .font(HiveDesign.Typography.dialogTitle)
                    .foregroundStyle(Color.hiveAccent)

                Text("Bookmarks")
                    .font(HiveDesign.Typography.subHeadingBold)

                Spacer()

                // Folder creation lives beside import/export (Chrome parity).
                Button(action: { newFolderDraft = ""; showNewFolder = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(HiveDesign.Typography.buttonCaption)
                        Text("New Folder")
                            .font(HiveDesign.Typography.sidebarItemMedium)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Create bookmark folder")

                if !state.bookmarks.isEmpty {
                    Button(action: { showImportSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(HiveDesign.Typography.buttonCaption)
                            Text("Import")
                                .font(HiveDesign.Typography.sidebarItemMedium)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Import browser bookmarks")

                    Button(action: exportBookmarks) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(HiveDesign.Typography.buttonCaption)
                            Text("Export")
                                .font(HiveDesign.Typography.sidebarItemMedium)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Export bookmarks as HTML")
                }

                Text("\(filteredBookmarks.count) item\(filteredBookmarks.count == 1 ? "" : "s")")
                    .font(HiveDesign.Typography.smallLabelMedium)
                    .foregroundStyle(.secondary)

                Button("Done") { state.closeBookmarksManager() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color.hiveAccent)
                    .accessibilityLabel("Close bookmarks manager")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Breadcrumb navigation (folders only — hidden at root or in search).
            if searchText.isEmpty, !folderChain.isEmpty {
                HStack(spacing: 4) {
                    Button(action: { state.bookmarksManagerFolderID = nil }) {
                        Image(systemName: "folder")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(Color.hiveAccent)
                    }
                    .buttonStyle(.plain)
                    .help("Back to all bookmarks")

                    ForEach(Array(folderChain.enumerated()), id: \.element.id) { index, folder in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Button(action: { state.bookmarksManagerFolderID = folder.id }) {
                            Text(folder.title)
                                .font(HiveDesign.Typography.sidebarItemMedium)
                                .foregroundStyle(index == folderChain.count - 1 ? .primary : Color.hiveAccent)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                Divider()
            }

            // Import result banner
            if let msg = importResultMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(HiveDesign.Typography.sidebarItemMedium)
                    Spacer()
                    Button(action: { importResultMessage = nil }) {
                        Image(systemName: "xmark")
                            .font(HiveDesign.Typography.captionBold)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss import message")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.08))
            }

            PanelSearchField(prompt: "Search bookmarks", text: $searchText, isFocused: $isSearchFocused)

            // Content
            if state.bookmarks.isEmpty {
                emptyState
            } else if filteredBookmarks.isEmpty {
                noResults
            } else {
                List {
                    ForEach(filteredBookmarks) { bookmark in
                        if bookmark.isFolder {
                            FolderRow(
                                bookmark: bookmark,
                                moveDestinations: moveDestinations(for: bookmark),
                                open: { state.bookmarksManagerFolderID = bookmark.id },
                                onRename: { target in
                                    renameDraft = target.title
                                    renameTarget = target
                                },
                                onDelete: { target in deleteFolderTarget = target }
                            )
                        } else {
                            BookmarkRow(bookmark: bookmark, moveDestinations: moveDestinations(for: bookmark))
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            let item = filteredBookmarks[i]
                            if item.isFolder {
                                deleteFolderTarget = item
                            } else {
                                state.deleteBookmark(id: item.id)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(width: 580, height: 460)
        .background(HiveDesign.Material.panel)
        .onAppear { isSearchFocused = true }
        .sheet(isPresented: $showImportSheet) {
            ImportBrowserDataSheet(isPresented: $showImportSheet) { bookmarkCount, historyCount in
                let total = bookmarkCount + historyCount
                importResultMessage = "Imported \(bookmarkCount) bookmark\(bookmarkCount == 1 ? "" : "s") and \(historyCount) histor\(historyCount == 1 ? "y" : "ies") (\(total) item\(total == 1 ? "" : "s"))"
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    importResultMessage = nil
                }
            }
        }
        .alert("New Folder", isPresented: $showNewFolder) {
            TextField("Folder name", text: $newFolderDraft)
            Button("Create") {
                state.createBookmarkFolder(named: newFolderDraft, parentID: currentFolderID)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(currentFolderID == nil
                 ? "Create a folder at the top level."
                 : "Create a folder inside the current folder.")
        }
        .alert("Rename Folder", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Folder name", text: $renameDraft)
            Button("Rename") {
                if let target = renameTarget { state.renameBookmarkFolder(id: target.id, to: renameDraft) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Rename this folder.")
        }
        .alert("Delete Folder?", isPresented: Binding(
            get: { deleteFolderTarget != nil },
            set: { if !$0 { deleteFolderTarget = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let target = deleteFolderTarget { state.deleteBookmarkFolder(id: target.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleting “\(deleteFolderTarget?.title ?? "")” also deletes everything inside it. This can't be undone.")
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bookmark.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No bookmarks yet")
                .font(HiveDesign.Typography.subHeadingSemiBold)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text("Click the star in the address bar to save pages")
                    .font(HiveDesign.Typography.sidebarItem)
                    .foregroundStyle(.tertiary)
                Text("or import browser data")
                    .font(HiveDesign.Typography.sidebarItem)
                    .foregroundStyle(.tertiary)
            }

            Button(action: { showImportSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(HiveDesign.Typography.sidebarItemMedium)
                    Text("Import browser data")
                        .font(HiveDesign.Typography.bodyMedium)
                }
                .foregroundStyle(Color.hiveAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(HiveDesign.Surface.level2)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    /// Writes the bookmarks to a Netscape-format HTML file the user picks
    /// (Chrome/Safari/Arc parity — any browser can import it back).
    private func exportBookmarks() {
        let panel = NSSavePanel()
        panel.title = "Export Bookmarks"
        panel.nameFieldStringValue = "bookmarks.html"
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Folders export as their own line-items (URL-less rows) so the
        // structure survives a round-trip through another browser.
        let items = state.bookmarks.map {
            BookmarkHTMLExporter.Item(title: $0.title, urlString: $0.isFolder ? "" : $0.urlString)
        }
        let html = BookmarkHTMLExporter.export(items: items, title: "Hive Bookmarks")
        do {
            guard let data = html.data(using: .utf8) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try data.write(to: url, options: .atomic)
        } catch {
            // An explicit export action must never fail silently.
            exportError = "Couldn't write the bookmarks file: \(error.localizedDescription)"
        }
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No bookmarks matching \"\(searchText)\"")
                .font(HiveDesign.Typography.bodyLarge)
                .foregroundStyle(.secondary)
            Button("Clear search") { searchText = "" }
                .buttonStyle(.borderless)
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(Color.hiveAccent)
                .accessibilityLabel("Clear bookmark search")
            Spacer()
        }
    }
}

// MARK: - ImportBrowserDataSheet

/// Shows available browsers to import bookmarks and history from. Non-destructive —
/// valid data is merged and duplicates are skipped.
private struct ImportBrowserDataSheet: View {
    @Environment(BrowserState.self) private var state
    @Binding var isPresented: Bool
    let onImported: (Int, Int) -> Void

    @State private var importingBrowser: String? = nil
    @State private var browsers: [BrowserImport.AvailableBrowser] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import Browser Data")
                    .font(HiveDesign.Typography.subHeadingBold)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.borderless)
                    .font(HiveDesign.Typography.body)
                    .accessibilityLabel("Cancel import")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            if let importing = importingBrowser {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Importing from \(importing)...")
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 250)
            } else if browsers.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("No browsers with importable data found")
                        .font(HiveDesign.Typography.panelTitleMedium)
                        .foregroundStyle(.secondary)
                    Text("Supported: Chrome, Safari, Brave, Edge, Arc, Firefox, Zen — bookmarks and history")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: 250)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(browsers) { browser in
                            importBrowserRow(browser)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 400, height: 320)
        .background(HiveDesign.Material.panel)
        .onAppear { browsers = BrowserImport.detectAvailableBrowsers() }
    }

    private func importBrowserRow(_ browser: BrowserImport.AvailableBrowser) -> some View {
        Button(action: { performImport(browser) }) {
            HStack(spacing: 12) {
                Image(systemName: browser.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.hiveAccent)
                    .frame(width: 32, height: 32)
                    .background(HiveDesign.Surface.level2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(browser.name)
                        .font(HiveDesign.Typography.bodySemiBold)
                        .foregroundStyle(.primary)
                    Text("\(browser.bookmarkCount) bookmark\(browser.bookmarkCount == 1 ? "" : "s") · \(browser.historyCount) history")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(HiveDesign.Typography.captionBold)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func performImport(_ browser: BrowserImport.AvailableBrowser) {
        importingBrowser = browser.name
        Task { @MainActor in
            let counts = state.mergeImportedData(bookmarks: browser.bookmarks, history: browser.history)
            importingBrowser = nil
            isPresented = false
            onImported(counts.bookmarks, counts.history)
        }
    }
}

// MARK: - FolderRow

private struct FolderRow: View {
    let bookmark: Bookmark
    let moveDestinations: [Bookmark]
    let open: () -> Void
    let onRename: (Bookmark) -> Void
    let onDelete: (Bookmark) -> Void
    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(Color.hiveAccent)
                .frame(width: 20, height: 20)

            Text(bookmark.title)
                .font(HiveDesign.Typography.bodyMedium)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            if isHovered {
                Image(systemName: "chevron.right")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open Folder") { open() }
            Button("Rename…") { onRename(bookmark) }
            Menu("Move to Folder…") {
                moveMenuItems
            }
            Divider()
            Button("Delete Folder…", role: .destructive) { onDelete(bookmark) }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Folder \(bookmark.title)")
    }

    private var moveMenuItems: some View {
        Group {
            Button("Top level") { state.moveBookmark(id: bookmark.id, toFolderID: nil) }
            ForEach(moveDestinations) { folder in
                Button(folder.title) { state.moveBookmark(id: bookmark.id, toFolderID: folder.id) }
            }
        }
    }
}

// MARK: - BookmarkRow

private struct BookmarkRow: View {
    let bookmark: Bookmark
    let moveDestinations: [Bookmark]
    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            FaviconImage(url: bookmark.faviconURL)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title)
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(bookmark.urlString)
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 6) {
                    Button(action: { copyURL() }) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy URL")
                    .accessibilityLabel("Copy bookmark URL")

                    Button(action: { state.navigateToURL(bookmark.url) }) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(HiveDesign.Typography.sidebarItem)
                            .foregroundStyle(Color.hiveAccent)
                    }
                    .buttonStyle(.plain)
                    .help("Open in new tab")
                    .accessibilityLabel("Open bookmark in new tab")

                    Button(action: { editTarget = bookmark }) {
                        Image(systemName: "pencil")
                            .font(HiveDesign.Typography.sidebarItem)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit…")
                    .accessibilityLabel("Edit bookmark")
                }
            }
        }
        .padding(.vertical, 4)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open") { state.navigateToURL(bookmark.url) }
            Button("Copy URL") { copyURL() }
            Button("Edit…") { editTarget = bookmark }
            Menu("Move to Folder…") {
                Button("Top level") { state.moveBookmark(id: bookmark.id, toFolderID: nil) }
                ForEach(moveDestinations) { folder in
                    Button(folder.title) { state.moveBookmark(id: bookmark.id, toFolderID: folder.id) }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { state.deleteBookmark(id: bookmark.id) }
        }
        .sheet(item: $editTarget) { target in
            BookmarkEditSheet(bookmark: target) {
                editTarget = nil
            }
        }
    }

    @State private var copied: Bool = false
    @State private var editTarget: Bookmark? = nil

    private func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(bookmark.urlString, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}

/// Title + URL editor for a plain bookmark (Chrome/Safari manager parity).
private struct BookmarkEditSheet: View {
    let bookmark: Bookmark
    let onClose: () -> Void
    @Environment(BrowserState.self) private var state
    @State private var titleDraft: String = ""
    @State private var urlDraft: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Edit Bookmark")
                    .font(HiveDesign.Typography.subHeadingBold)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                TextField("Name", text: $titleDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($titleFocused)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("URL")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                TextField("URL", text: $urlDraft)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    state.updateBookmark(id: bookmark.id, title: titleDraft, urlString: urlDraft)
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          urlDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            titleDraft = bookmark.title
            urlDraft = bookmark.urlString
            titleFocused = true
        }
    }
}
