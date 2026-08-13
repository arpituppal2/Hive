import SwiftUI
import HiveCore

// MARK: - ArchivePanel
//
// §7 "Recently Archived" shelf. Records of auto-archived cold tabs, newest
// first; rows expose restore (reopens the tab and removes the record) and
// permanent delete via hover actions and a context menu. The header carries
// the Auto Archive toggle (Settings → Performance mirrors it).

struct ArchivePanel: View {
    @Environment(BrowserState.self) private var state
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    private var shelf: [ArchivedTab] { TabArchiveShelfPolicy.sortedForShelf(state.archivedTabs) }

    private var filteredRecords: [ArchivedTab] {
        guard !searchText.isEmpty else { return shelf }
        let q = searchText.lowercased()
        return shelf.filter {
            $0.title.lowercased().contains(q)
            || $0.url?.absoluteString.lowercased().contains(q) == true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "archivebox.fill")
                    .font(HiveDesign.Typography.dialogTitle)
                    .foregroundStyle(Color.hiveAccent)
                Text("Archive")
                    .font(HiveDesign.Typography.subHeadingBold)
                Spacer()
                Toggle("Auto Archive", isOn: Binding(
                    get: { state.enableAutoArchive },
                    set: { state.enableAutoArchive = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .help("Automatically move cold tabs (14+ days) to the archive")
                .accessibilityLabel("Auto archive cold tabs")
                Button(action: { state.isArchivePanelOpen = false }) {
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

            PanelSearchField(prompt: "Search archive", text: $searchText, isFocused: $isSearchFocused)

            Divider()

            // List
            if state.archivedTabs.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "archivebox")
                        .font(HiveDesign.Typography.heroDisplay)
                        .foregroundStyle(.tertiary)
                    Text("No archived tabs")
                        .font(HiveDesign.Typography.panelTitleMedium)
                    Text("Tabs untouched for 14+ days move here automatically. Restore them any time from this shelf.")
                        .font(HiveDesign.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                Spacer()
            } else if filteredRecords.isEmpty {
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
                        ForEach(filteredRecords) { record in
                            ArchivedTabRow(record: record)
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

// MARK: - ArchivedTabRow

private struct ArchivedTabRow: View {
    @Environment(BrowserState.self) private var state
    let record: ArchivedTab
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: { state.restoreArchivedTab(id: record.id) }) {
            HStack(spacing: 10) {
                Group {
                    if let faviconURL = record.faviconURL {
                        FaviconImage(url: faviconURL)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "archivebox")
                            .font(HiveDesign.Typography.bodyMedium)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(record.url?.host ?? "")
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("last seen \(record.lastVisitedAt.formatted(.relative(presentation: .named)))")
                            .font(HiveDesign.Typography.microLabel)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if isHovered {
                    Text("Archived \(record.archivedAt.formatted(.relative(presentation: .named)))")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(isHovered ? HiveDesign.Surface.level1 : Color.clear)
        }
        .buttonStyle(.plain)
        // Hover actions are overlay SIBLINGS of the row button (never nested
        // inside its label), so clicking one can never also fire "Restore".
        .overlay(alignment: .trailing) {
            if isHovered {
                HStack(spacing: 2) {
                    Button(action: { state.restoreArchivedTab(id: record.id) }) {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.hiveAccent)
                    }
                    .buttonStyle(.plain)
                    .help("Restore tab")

                    Button(action: { state.removeArchivedTab(id: record.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete permanently")
                }
                .padding(.trailing, 8)
            }
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Restore Tab") { state.restoreArchivedTab(id: record.id) }
            Divider()
            Button("Delete Permanently", role: .destructive) { state.removeArchivedTab(id: record.id) }
        }
        .accessibilityLabel("Archived tab \(record.title)")
        .accessibilityHint("Restores this tab and removes it from the archive")
    }
}
