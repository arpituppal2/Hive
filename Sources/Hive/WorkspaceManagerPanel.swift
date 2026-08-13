import SwiftUI

// MARK: - WorkspacePalette

/// The canonical workspace color set. Deliberately wider than the tab-group
/// palette: workspace badges sit in the sidebar rail where adjacent hues need
/// more separation. Brand amber leads, then a spread across hue.
enum WorkspacePalette {
    static let colors: [String] = [
        "#F97316", "#F5A623", "#22C55E", "#10B981", "#14B8A6",
        "#3B82F6", "#6366F1", "#8B5CF6", "#EC4899", "#E11D48"
    ]

    static let icons: [String] = [
        "circle.fill", "square.fill", "triangle.fill", "star.fill",
        "heart.fill", "bolt.fill", "leaf.fill", "flame.fill",
        "cloud.fill", "moon.fill", "sun.max.fill", "sparkles",
        "briefcase.fill", "graduationcap.fill", "music.note", "gamecontroller.fill",
        "cart.fill", "newspaper.fill", "film.fill", "suit.heart.fill"
    ]

    /// Human-readable label for a palette hex.
    static func name(for hex: String) -> String {
        switch hex.lowercased() {
        case "#f97316": return "Brand"
        case "#f5a623": return "Amber"
        case "#22c55e": return "Green"
        case "#10b981": return "Emerald"
        case "#14b8a6": return "Teal"
        case "#3b82f6": return "Blue"
        case "#6366f1": return "Indigo"
        case "#8b5cf6": return "Purple"
        case "#ec4899": return "Pink"
        case "#e11d48": return "Red"
        default: return "Custom"
        }
    }
}

// MARK: - WorkspaceManagerPanel

/// Arc/Safari-class workspace manager sheet: switch, rename, recolor,
/// reorder, create, and delete the current profile's workspaces — the one
/// surface that previously only existed as scattered context menus.
struct WorkspaceManagerPanel: View {
    @Environment(BrowserState.self) private var state
    @State private var query: String = ""
    @State private var renameTargetID: UUID?
    @State private var renameText: String = ""
    @State private var showNewWorkspaceField: Bool = false
    @State private var newWorkspaceName: String = ""
    @State private var pendingDelete: BrowserState.Workspace?

    private var profileWorkspaces: [BrowserState.Workspace] {
        state.workspacesForCurrentProfile
    }

    private var filteredWorkspaces: [BrowserState.Workspace] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return profileWorkspaces }
        return profileWorkspaces.filter { workspace in
            workspace.name.lowercased().contains(q)
        }
    }

    private func tabCount(for workspace: BrowserState.Workspace) -> Int {
        state.tabs.filter { $0.workspaceID == workspace.id }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if filteredWorkspaces.isEmpty {
                emptyState
            } else {
                workspaceList
            }
            Divider()
            footer
        }
        .background(HiveDesign.Material.panel)
        .frame(width: 460, height: 460)
        .alert("Rename Workspace", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Workspace name", text: $renameText)
            Button("Rename") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
        .alert("Delete Workspace?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let workspace = pendingDelete {
                    state.deleteWorkspace(id: workspace.id)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let workspace = pendingDelete {
                Text("Move \(tabCount(for: workspace)) tab\(tabCount(for: workspace) == 1 ? "" : "s") to the current workspace and remove \(workspace.name)? Its cookies and site data are deleted.")
            } else {
                Text("")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up")
                .font(HiveDesign.Typography.panelTitleMedium)
                .foregroundStyle(.secondary)

            TextField("Filter workspaces...", text: $query)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.subHeading)

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if showNewWorkspaceField {
                TextField("New workspace name", text: $newWorkspaceName)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.smallLabelMedium)
                    .frame(width: 120)
                    .onSubmit { commitNewWorkspace() }
            }

            Button(action: {
                if showNewWorkspaceField {
                    commitNewWorkspace()
                } else {
                    showNewWorkspaceField = true
                    newWorkspaceName = ""
                }
            }) {
                Label("New Workspace", systemImage: "plus")
                    .font(HiveDesign.Typography.smallLabelBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(HiveDesign.Accent.primary)
                    .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Create a new workspace")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - List

    private var workspaceList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(Array(filteredWorkspaces.enumerated()), id: \.element.id) { index, workspace in
                    WorkspaceManagerRow(
                        workspace: workspace,
                        isActive: state.currentWorkspaceID == workspace.id,
                        tabCount: tabCount(for: workspace),
                        isFirst: index == 0,
                        isLast: index == filteredWorkspaces.count - 1,
                        onSelect: { state.switchWorkspace(to: workspace.id) },
                        onRename: {
                            renameTargetID = workspace.id
                            renameText = workspace.name
                        },
                        onRecolor: { hex in state.setWorkspaceColor(id: workspace.id, colorHex: hex) },
                        onMoveUp: {
                            state.moveWorkspace(id: workspace.id, direction: -1)
                        },
                        onMoveDown: {
                            state.moveWorkspace(id: workspace.id, direction: 1)
                        },
                        onDelete: {
                            pendingDelete = workspace
                        }
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
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No matching workspaces")
                .font(HiveDesign.Typography.bodyMedium)
                .foregroundStyle(.secondary)
            Text("Try a different name, or create a new one")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(filteredWorkspaces.count) workspace\(filteredWorkspaces.count == 1 ? "" : "s")")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Click a row to switch")
                .font(HiveDesign.Typography.buttonCaption)
                .foregroundStyle(.tertiary)
            Button("Done") { state.isWorkspaceManagerPanelOpen = false }
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
            state.renameWorkspace(id: id, name: name)
        }
        renameTargetID = nil
    }

    private func commitNewWorkspace() {
        let name = newWorkspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let paletteIndex = state.workspacesForCurrentProfile.count
        let color = WorkspacePalette.colors[paletteIndex % WorkspacePalette.colors.count]
        let icon = WorkspacePalette.icons[paletteIndex % WorkspacePalette.icons.count]
        _ = state.addWorkspace(name: name.isEmpty ? "New Workspace" : name, colorHex: color, iconName: icon)
        showNewWorkspaceField = false
        newWorkspaceName = ""
    }
}

// MARK: - WorkspaceManagerRow

private struct WorkspaceManagerRow: View {
    let workspace: BrowserState.Workspace
    let isActive: Bool
    let tabCount: Int
    let isFirst: Bool
    let isLast: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onRecolor: (String) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Badge
            ZStack {
                Circle()
                    .fill(workspace.swiftUIColor)
                    .frame(width: 30, height: 30)
                Image(systemName: workspace.iconName)
                    .font(HiveDesign.Typography.smallLabelBold)
                    .foregroundStyle(.white)
            }
            .shadow(color: isActive ? workspace.swiftUIColor.opacity(0.35) : .clear, radius: 3, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(workspace.name)
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(isActive ? .primary : HiveDesign.Text.secondary)
                    if isActive {
                        Text("ACTIVE")
                            .font(HiveDesign.Typography.microTinyBold)
                            .foregroundStyle(HiveDesign.Accent.primary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(HiveDesign.Accent.muted)
                            .clipShape(Capsule())
                    }
                }
                Text("\(tabCount) tab\(tabCount == 1 ? "" : "s")")
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isHovered || isActive {
                // Recolor menu
                Menu {
                    ForEach(WorkspacePalette.colors, id: \.self) { hex in
                        Button {
                            onRecolor(hex)
                        } label: {
                            Label {
                                Text(WorkspacePalette.name(for: hex))
                            } icon: {
                                Image(systemName: workspace.colorHex.lowercased() == hex.lowercased()
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
                .help("Workspace color")

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
                .help("Delete workspace")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .fill(isActive ? HiveDesign.Accent.muted : (isHovered ? HiveDesign.Surface.level1 : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .stroke(isActive ? HiveDesign.Accent.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }
}
