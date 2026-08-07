import SwiftUI
import AppKit

// MARK: - BrowserDataManagerSheet
//
// Safari/Chrome-style bookmarks manager with search, favicons, import from
// other browsers, and delete. Import is non-destructive — valid browser data
// is merged, duplicates are skipped, and unsafe URLs are ignored.

struct BookmarksManagerSheet: View {
    @Environment(ChromiumBrowserState.self) private var state
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var showImportSheet: Bool = false
    @State private var importResultMessage: String? = nil

    private var filteredBookmarks: [Bookmark] {
        guard !searchText.isEmpty else { return state.bookmarks }
        let q = searchText.lowercased()
        return state.bookmarks.filter {
            $0.title.lowercased().contains(q) ||
            $0.urlString.lowercased().contains(q)
        }
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

                // Import button — Safari/Chrome-style
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
                }

                Text("\(state.bookmarks.count) items")
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
                        BookmarkRow(bookmark: bookmark)
                    }
                    .onDelete { indexSet in
                        for i in indexSet { state.deleteBookmark(id: filteredBookmarks[i].id) }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(width: 560, height: 440)
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
    @Environment(ChromiumBrowserState.self) private var state
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
                    Text("Supported: Chrome, Safari, Brave, Edge, Arc, Firefox — bookmarks and history")
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

// MARK: - BookmarkRow

private struct BookmarkRow: View {
    let bookmark: Bookmark
    @Environment(ChromiumBrowserState.self) private var state
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
                }
            }
        }
        .padding(.vertical, 4)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open") { state.navigateToURL(bookmark.url) }
            Button("Copy URL") { copyURL() }
            Divider()
            Button("Delete", role: .destructive) { state.deleteBookmark(id: bookmark.id) }
        }
    }

    @State private var copied: Bool = false

    private func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(bookmark.urlString, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}
