import SwiftUI
import HiveCore

// MARK: - PinnedAppsPanel
//
// Arc/Sidekick-style Pinned Web Apps manager sheet. The rail is ordered by
// sortOrder; rows expose open (new tab + last-used), rename, rail reorder
// (move up/down), and remove via hover actions and a context menu. The
// current page can be pinned directly from the panel.

struct PinnedAppsPanel: View {
    @Environment(BrowserState.self) private var state
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var renameTarget: PinnedWebApp? = nil
    @State private var renameDraft: String = ""
    @State private var pinFeedback: String? = nil

    private var railApps: [PinnedWebApp] { PinnedWebAppPolicy.sortedForRail(state.pinnedWebApps) }

    private var filteredApps: [PinnedWebApp] {
        guard !searchText.isEmpty else { return railApps }
        let q = searchText.lowercased()
        return railApps.filter {
            $0.name.lowercased().contains(q)
            || $0.url.absoluteString.lowercased().contains(q)
            || $0.host.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(HiveDesign.Typography.dialogTitle)
                    .foregroundStyle(Color.hiveAccent)
                Text("Pinned Apps")
                    .font(HiveDesign.Typography.subHeadingBold)
                Spacer()
                Button(action: { pinCurrentPage() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(HiveDesign.Typography.buttonCaption)
                        Text("Pin Current Page")
                            .font(HiveDesign.Typography.sidebarItemMedium)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .disabled(!canPinCurrentPage)
                .help(canPinCurrentPage ? "Pin the current page as an app" : "No web page is available to pin")
                .accessibilityLabel("Pin current page as app")

                Button(action: { state.isPinnedAppsPanelOpen = false }) {
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

            if let feedback = pinFeedback {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.green)
                    Text(feedback)
                        .font(HiveDesign.Typography.sidebarItemMedium)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.08))
            }

            PanelSearchField(prompt: "Search pinned apps", text: $searchText, isFocused: $isSearchFocused)

            Divider()

            // List
            if state.pinnedWebApps.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .font(HiveDesign.Typography.heroDisplay)
                        .foregroundStyle(.tertiary)
                    Text("No pinned apps")
                        .font(HiveDesign.Typography.panelTitleMedium)
                    Text("Right-click any page and choose “Add to Pinned Apps” to keep it one click away.")
                        .font(HiveDesign.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                Spacer()
            } else if filteredApps.isEmpty {
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
                        ForEach(Array(filteredApps.enumerated()), id: \.element.id) { index, app in
                            PinnedAppRow(
                                app: app,
                                canMoveUp: index > 0,
                                canMoveDown: index < filteredApps.count - 1,
                                onRename: { renameDraft = app.name; renameTarget = app }
                            )
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .frame(width: 420, height: 460)
        .background(HiveDesign.Material.panel)
        .alert("Rename App", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("App name", text: $renameDraft)
            Button("Rename") {
                if let target = renameTarget {
                    state.renamePinnedWebApp(id: target.id, to: renameDraft)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Rename this pinned app.")
        }
    }

    private var canPinCurrentPage: Bool {
        state.activeTab?.isPrivate != true
            && PinnedWebAppPolicy.normalizedAppURL(state.activeModel?.url) != nil
    }

    private func pinCurrentPage() {
        guard let url = state.activeModel?.url,
              let host = url.host else { return }
        // Re-pinning an unchanged app is a no-op with no feedback — call it
        // out so the button never looks dead (Arc shows a toast either way).
        let alreadyPinned = state.isPinnedWebApp(url)
        let landed = state.addCurrentPageAsPinnedApp()
        if alreadyPinned && !landed {
            pinFeedback = "\(host) is already pinned"
        } else {
            pinFeedback = "Pinned \(host)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            pinFeedback = nil
        }
    }
}

// MARK: - PinnedAppRow

private struct PinnedAppRow: View {
    @Environment(BrowserState.self) private var state
    let app: PinnedWebApp
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onRename: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: { state.openPinnedWebApp(id: app.id) }) {
            HStack(spacing: 10) {
                appIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(app.host)
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let used = app.lastUsedAt {
                    Text(used, style: .relative)
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isHovered ? HiveDesign.Surface.level1 : Color.clear)
        }
        .buttonStyle(.plain)
        // Hover actions are overlay SIBLINGS of the row button (never nested
        // inside its label), so clicking one can never also fire "Open".
        .overlay(alignment: .trailing) {
            if isHovered {
                HStack(spacing: 2) {
                    Button(action: { state.movePinnedWebApp(id: app.id, offset: -1) }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveUp)
                    .help("Move up in rail")

                    Button(action: { state.movePinnedWebApp(id: app.id, offset: 1) }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveDown)
                    .help("Move down in rail")

                    Button(action: onRename) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Rename")

                    Button(action: { state.removePinnedWebApp(id: app.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
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
            Button("Open") { state.openPinnedWebApp(id: app.id) }
            Button("Rename…") { onRename() }
            Divider()
            Button("Move Up") { state.movePinnedWebApp(id: app.id, offset: -1) }
                .disabled(!canMoveUp)
            Button("Move Down") { state.movePinnedWebApp(id: app.id, offset: 1) }
                .disabled(!canMoveDown)
            Divider()
            Button("Remove", role: .destructive) { state.removePinnedWebApp(id: app.id) }
        }
    }

    private var appIcon: some View {
        Group {
            if let faviconURL = app.faviconURL {
                FaviconImage(url: faviconURL)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: app.fallbackIcon)
                    .font(HiveDesign.Typography.sidebarItem)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(app.accentColor == "accent" ? Color.hiveAccent : (Color(hex: app.accentColor) ?? Color.hiveAccent))
                    )
            }
        }
    }
}
