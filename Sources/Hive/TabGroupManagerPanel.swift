import SwiftUI

// MARK: - TabGroupManagerPanel

/// Arc/Chrome-class tab group manager sheet: see all groups in the current
/// workspace at a glance, rename, recolor, reorder, create, collapse/expand,
/// and delete. Previously only accessible via scattered context menus.
struct TabGroupManagerPanel: View {
    @Environment(BrowserState.self) private var state
    @State private var query: String = ""
    @State private var renameTargetID: UUID?
    @State private var renameText: String = ""
    @State private var showNewGroupField: Bool = false
    @State private var newGroupName: String = ""
    @State private var pendingDelete: BrowserState.TabGroup?

    private var groups: [BrowserState.TabGroup] {
        state.groupsForCurrentWorkspace
    }

    private var filteredGroups: [BrowserState.TabGroup] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return groups }
        return groups.filter { $0.name.lowercased().contains(q) }
    }

    private func tabCount(for group: BrowserState.TabGroup) -> Int {
        state.tabs.filter { $0.groupID == group.id }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if filteredGroups.isEmpty {
                emptyState
            } else {
                groupList
            }
            Divider()
            footer
        }
        .background(HiveDesign.Material.panel)
        .frame(width: 460, height: 380)
        .alert("Rename Group", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Group name", text: $renameText)
            Button("Rename") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
        .alert("Delete Group?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let group = pendingDelete {
                    state.deleteTabGroup(id: group.id)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let group = pendingDelete {
                let count = tabCount(for: group)
                Text("Delete \"" + group.name + "\"? Its " + String(count) + " tab" + (count == 1 ? "" : "s") + " will be ungrouped (not closed).")
            } else {
                Text("")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .font(HiveDesign.Typography.panelTitleMedium)
                .foregroundStyle(.secondary)

            TextField("Filter groups...", text: $query)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.subHeading)

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if showNewGroupField {
                TextField("Group name", text: $newGroupName)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.smallLabelMedium)
                    .frame(width: 120)
                    .onSubmit { commitNewGroup() }
            }

            Button(action: {
                if showNewGroupField {
                    commitNewGroup()
                } else {
                    showNewGroupField = true
                    newGroupName = ""
                }
            }) {
                Label("New Group", systemImage: "plus")
                    .font(HiveDesign.Typography.smallLabelBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(HiveDesign.Accent.primary)
                    .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Create a new tab group")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - List

    private var groupList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(Array(filteredGroups.enumerated()), id: \.element.id) { index, group in
                    TabGroupManagerRow(
                        group: group,
                        tabCount: tabCount(for: group),
                        isFirst: index == 0,
                        isLast: index == filteredGroups.count - 1,
                        onRename: {
                            renameTargetID = group.id
                            renameText = group.name
                        },
                        onRecolor: { hex in state.setTabGroupColor(id: group.id, colorHex: hex) },
                        onToggleCollapse: { state.toggleTabGroup(id: group.id) },
                        onMoveUp: { state.moveTabGroup(id: group.id, direction: -1) },
                        onMoveDown: { state.moveTabGroup(id: group.id, direction: 1) },
                        onDelete: { pendingDelete = group }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No tab groups")
                .font(HiveDesign.Typography.bodyMedium)
                .foregroundStyle(.secondary)
            Text("Group tabs by right-clicking and selecting \"New Group…\"")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Text(String(filteredGroups.count) + " group" + (filteredGroups.count == 1 ? "" : "s"))
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Groups are scoped to the current workspace")
                .font(HiveDesign.Typography.buttonCaption)
                .foregroundStyle(.tertiary)
            Button("Done") { state.isTabGroupManagerPanelOpen = false }
                .font(HiveDesign.Typography.smallLabelBold)
                .buttonStyle(.borderedProminent)
                .tint(HiveDesign.Accent.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func commitRename() {
        guard let id = renameTargetID else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            state.renameTabGroup(id: id, name: name)
        }
        renameTargetID = nil
    }

    private func commitNewGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let paletteIndex = groups.count
        let color = TabGroupPalette.colors[paletteIndex % TabGroupPalette.colors.count]
        state.createTabGroup(name: name.isEmpty ? "Group " + String(groups.count + 1) : name, colorHex: color)
        showNewGroupField = false
        newGroupName = ""
    }
}

// MARK: - TabGroupManagerRow

private struct TabGroupManagerRow: View {
    let group: BrowserState.TabGroup
    let tabCount: Int
    let isFirst: Bool
    let isLast: Bool
    let onRename: () -> Void
    let onRecolor: (String) -> Void
    let onToggleCollapse: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Color dot + collapse icon
            ZStack {
                Circle()
                    .fill(group.swiftUIColor)
                    .frame(width: 28, height: 28)
                Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                    .font(HiveDesign.Typography.microLabelBold)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(group.name)
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                Text(String(tabCount) + " tab" + (tabCount == 1 ? "" : "s") + (group.isCollapsed ? " · Collapsed" : ""))
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isHovered {
                // Collapse/expand
                Button(action: onToggleCollapse) {
                    Image(systemName: group.isCollapsed ? "chevron.down" : "chevron.up")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(group.isCollapsed ? "Expand group" : "Collapse group")

                // Recolor
                Menu {
                    ForEach(TabGroupPalette.colors, id: \.self) { hex in
                        Button {
                            onRecolor(hex)
                        } label: {
                            Label {
                                Text(TabGroupPalette.name(for: hex))
                            } icon: {
                                Image(systemName: group.colorHex.lowercased() == hex.lowercased()
                                      ? "checkmark.circle.fill" : "circle.fill")
                                    .foregroundStyle(Color(hex: hex) ?? .secondary)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .help("Group color")

                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(isFirst)
                .help("Move up")

                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(isLast)
                .help("Move down")

                Button(action: onRename) {
                    Image(systemName: "pencil")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Rename")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Delete group")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .fill(isHovered ? HiveDesign.Surface.level1 : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}