import SwiftUI
import HiveCore

// MARK: - BookmarkBarButton
//
// One favicon button in the bookmark bar with a Chrome-class hover wash behind the
// favicon (the previous implementation rendered static buttons with no feedback).
// Right-click menu (open / edit / delete) comes from the parent via the same
// ChromeState rename path.

private struct BookmarkBarButton: View {
    let bookmark: Bookmark
    let onEdit: () -> Void
    @Environment(ChromeState.self) private var state
    @State private var isHovered = false

    var body: some View {
        Button {
            state.newTab(url: bookmark.url)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: HiveRadius.r4)
                    .fill(Color.hiveSurface.opacity(isHovered ? 0.55 : 0))
                    .frame(width: 24, height: 24)
                if let fav = bookmark.faviconURL {
                    FaviconView(url: fav)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "bookmark.fill")
                        .font(HiveTypography.font(.caption3))
                        .foregroundStyle(.hiveGraphite)
                }
            }
            .frame(width: 24, height: 24)
            .animation(.hiveMicro, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(bookmark.title)
        .contextMenu {
            Button("Open in New Tab") { state.newTab(url: bookmark.url) }
            Button("Edit…") { onEdit() }
            Divider()
            Button("Delete", role: .destructive) {
                state.deleteBookmark(id: bookmark.id)
            }
        }
        .accessibilityLabel("Bookmark: \(bookmark.title)")
    }
}

// MARK: - BookmarkBarView
//
// A horizontal strip of favicon-only bookmark buttons rendered below the omnibar
// (horizontal layout) or as a collapsible row in vertical layout. Toggled via
// View > Show Bookmark Bar or Cmd+Shift+B. Each button opens the bookmark URL
// in a new tab on click. Right-click to edit or delete.
//
// Design: 32pt height, packed favicon buttons (24×24 favicons with rounded corners),
// subtle surface background. Empty state shows a faint hint to bookmark pages.

struct BookmarkBarView: View {

    @Environment(ChromeState.self) private var state

    /// Bookmark being renamed via the context-menu "Edit…" action. Non-nil presents the
    /// rename sheet. Mirrors `BookmarksPanelView`'s rename affordance so both bookmark
    /// surfaces (bar + panel) edit through the same `ChromeState.renameBookmark` path.
    @State private var renameTarget: Bookmark?
    @State private var renameTitle: String = ""

    var body: some View {
        // Extracted so `.sheet` resolves against a concrete opaque `some View`
        // rather than a bare `if/else` `_ConditionalContent` — attaching a generic
        // `sheet(item:)` directly to a conditional content fails overload
        // resolution in this compiler ("cannot be resolved without a contextual
        // type"). Mirrors the receiver shape that compiles in `BriefBrowserView`.
        bookmarkContent
            .sheet(item: $renameTarget) { target in
                VStack(spacing: HiveSpacing.s12) {
                    Text("Edit Bookmark")
                        .hiveType(.body)
                        .fontWeight(.semibold)
                    TextField("Name", text: $renameTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitRename(target) }
                    HStack {
                        Button("Cancel", role: .cancel) { renameTarget = nil }
                        Spacer()
                        Button("Save") { commitRename(target) }
                            .buttonStyle(.borderedProminent)
                            .disabled(renameTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()
                .frame(width: 320)
            }
    }

    @ViewBuilder
    private var bookmarkContent: some View {
        let bookmarks = state.rootBookmarks.filter { !$0.isFolder }
        if bookmarks.isEmpty {
            emptyHint
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(bookmarks) { bookmark in
                        BookmarkBarButton(
                            bookmark: bookmark,
                            onEdit: {
                                renameTitle = bookmark.title
                                renameTarget = bookmark
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 32)
            .background(Color.hiveSurface.opacity(0.3))
        }
    }

    private var emptyHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "bookmark")
                .font(HiveTypography.font(.caption3))
                .foregroundStyle(.hiveMist)
            Text("Bookmark pages with ⌘D — they'll appear here")
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
        }
        .frame(height: 28)
        .frame(maxWidth: .infinity)
    }

    /// Persists the rename via the shared `ChromeState.renameBookmark` path.
    private func commitRename(_ target: Bookmark) {
        let trimmed = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.renameBookmark(id: target.id, to: trimmed)
        renameTarget = nil
        renameTitle = ""
    }
}
