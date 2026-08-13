import SwiftUI
import HiveCore

// MARK: - ReadingListPanel
//
// Safari-parity Reading List sheet. Newest first; unread entries carry a dot;
// rows expose open (marks read), mark read/unread, edit note, and remove via
// hover actions and a context menu.

struct ReadingListPanel: View {
    @Environment(BrowserState.self) private var state
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredEntries: [ReadingListEntry] {
        let entries = state.readingList
        guard !searchText.isEmpty else { return entries }
        let q = searchText.lowercased()
        return entries.filter {
            $0.title.lowercased().contains(q)
            || $0.url.absoluteString.lowercased().contains(q)
            || ($0.note?.lowercased().contains(q) == true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "bookmark")
                    .font(HiveDesign.Typography.dialogTitle)
                    .foregroundStyle(Color.hiveAccent)
                Text("Reading List")
                    .font(HiveDesign.Typography.subHeadingBold)
                Spacer()
                Button(action: { state.isReadingListPanelOpen = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.bodyLarge)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            PanelSearchField(prompt: "Search reading list", text: $searchText, isFocused: $isSearchFocused)

            Divider()

            // List
            if state.readingList.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(HiveDesign.Typography.heroDisplay)
                        .foregroundStyle(.tertiary)
                    Text("No saved articles")
                        .font(HiveDesign.Typography.panelTitleMedium)
                    Text("Right-click any page and choose “Add to Reading List” to save it for later.")
                        .font(HiveDesign.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                Spacer()
            } else if filteredEntries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(HiveDesign.Typography.heroDisplay)
                        .foregroundStyle(.tertiary)
                    Text("No matches")
                        .font(HiveDesign.Typography.panelTitleMedium)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredEntries) { entry in
                            ReadingListRow(entry: entry)
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .frame(width: 420, height: 460)
        .background(HiveDesign.Material.panel)
    }
}

// MARK: - ReadingListRow

private struct ReadingListRow: View {
    @Environment(BrowserState.self) private var state
    let entry: ReadingListEntry
    @State private var isHovered: Bool = false
    @State private var isEditingNote: Bool = false

    var body: some View {
        Button(action: { state.openReadingListItem(id: entry.id) }) {
            HStack(spacing: 10) {
                Group {
                    if let faviconURL = entry.faviconURL {
                        FaviconImage(url: faviconURL)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "globe")
                            .font(HiveDesign.Typography.bodyMedium)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if !entry.isRead {
                            Circle()
                                .fill(Color.hiveAccent)
                                .frame(width: 6, height: 6)
                        }
                        Text(entry.title)
                            .font(HiveDesign.Typography.bodyMedium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        Text(entry.host)
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if entry.note != nil {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        if let viewed = entry.lastViewedAt {
                            Text(viewed, style: .relative)
                                .font(HiveDesign.Typography.microLabel)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(isHovered ? HiveDesign.Surface.level1 : Color.clear)
        }
        .buttonStyle(.plain)
        // Hover actions are overlay SIBLINGS of the row button (never nested
        // inside its label), so clicking one can never also fire "Open".
        .overlay(alignment: .trailing) {
            if isHovered {
                HStack(spacing: 2) {
                    Button(action: { state.toggleReadingListItemRead(id: entry.id) }) {
                        Image(systemName: entry.isRead ? "circle" : "checkmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(entry.isRead ? "Mark as unread" : "Mark as read")

                    Button(action: { isEditingNote = true }) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit note")

                    Button(action: { state.removeFromReadingList(id: entry.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                }
                .padding(.trailing, 8)
            }
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open") { state.openReadingListItem(id: entry.id) }
            Button(entry.isRead ? "Mark as Unread" : "Mark as Read") {
                state.toggleReadingListItemRead(id: entry.id)
            }
            Button("Edit Note…") { isEditingNote = true }
            Divider()
            Button("Remove", role: .destructive) { state.removeFromReadingList(id: entry.id) }
        }
        .popover(isPresented: $isEditingNote, arrowEdge: .trailing) {
            NotePopover(entry: entry)
                .padding(12)
        }
    }
}

// MARK: - NotePopover

private struct NotePopover: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let entry: ReadingListEntry
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(HiveDesign.Typography.smallLabelMedium)
                .foregroundStyle(.secondary)
            TextField("Optional note…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.body)
                .lineLimit(3...5)
                .onAppear { draft = entry.note ?? "" }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    state.updateReadingListItemNote(id: entry.id, note: draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.hiveAccent)
                .disabled(draft == (entry.note ?? ""))
            }
        }
        .frame(width: 240)
    }
}
