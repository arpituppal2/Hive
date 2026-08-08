import SwiftUI

// MARK: - TabGroupPalette

/// The canonical tab-group color set, shared by the New Group default cycling,
/// the recolor submenu, and the group swatches. Six distinct hues — brand amber
/// leads, then green/red/pink/teal/purple so adjacent groups never collide.
enum TabGroupPalette {
    static let colors: [String] = [
        "#F5A623", "#22C55E", "#E11D48", "#EC4899", "#14B8A6", "#8B5CF6"
    ]

    /// Human-readable label for a palette hex (Chrome uses named color chips).
    static func name(for hex: String) -> String {
        switch hex.lowercased() {
        case "#f5a623": return "Amber"
        case "#22c55e": return "Green"
        case "#e11d48": return "Red"
        case "#ec4899": return "Pink"
        case "#14b8a6": return "Teal"
        case "#8b5cf6": return "Purple"
        default: return "Custom"
        }
    }
}

// MARK: - TabGroupColorMenu
//
// Shared recolor submenu used by both the per-tab group section and the
// group-header actions menu. Renders the palette with a checkmark on the
// group's current color so the two surfaces can never drift apart.

struct TabGroupColorMenu: View {
    let group: BrowserState.TabGroup
    @Environment(BrowserState.self) private var state

    var body: some View {
        Menu {
            ForEach(TabGroupPalette.colors, id: \.self) { hex in
                Button {
                    state.setTabGroupColor(id: group.id, colorHex: hex)
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
            Label("Group Color", systemImage: "paintpalette")
        }
    }
}

// MARK: - TabGroupMenuSection
//
// Reusable context-menu section for tab-group management, Chrome-class:
//   • New Group… (auto-named, cycles the palette)
//   • when the tab is already grouped: recolor submenu (checkmark on current),
//     collapse/expand, remove from group, delete group
//   • Move to Group submenu (existing groups in this workspace)

struct TabGroupMenuSection: View {
    let tab: BrowserState.Tab
    @Environment(BrowserState.self) private var state

    var body: some View {
        Button("New Group...") {
            let name = "Group \(state.groupsForCurrentWorkspace.count + 1)"
            let color = TabGroupPalette.colors[state.groupsForCurrentWorkspace.count % TabGroupPalette.colors.count]
            let group = state.createTabGroup(name: name, colorHex: color)
            state.moveTabToGroup(tabID: tab.id, groupID: group.id)
        }

        if let currentGroup = state.groupForTab(tab) {
            Divider()
            Button("Rename Group…") {
                state.beginRenamingGroup(currentGroup.id)
            }
            TabGroupColorMenu(group: currentGroup)

            Button(currentGroup.isCollapsed ? "Expand Group" : "Collapse Group") {
                state.toggleTabGroup(id: currentGroup.id)
            }

            Divider()

            Button("Remove from \"\(currentGroup.name)\"") {
                state.moveTabToGroup(tabID: tab.id, groupID: nil)
            }

            Button("Delete Group", role: .destructive) {
                state.deleteTabGroup(id: currentGroup.id)
            }
        }

        let groups = state.groupsForCurrentWorkspace.filter { $0.id != tab.groupID }
        if !groups.isEmpty {
            Divider()
            Menu("Move to Group") {
                ForEach(groups) { group in
                    Button {
                        state.moveTabToGroup(tabID: tab.id, groupID: group.id)
                    } label: {
                        Label {
                            Text(group.name)
                        } icon: {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(group.swiftUIColor)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - TabGroupActionsMenu
//
// Group-level context menu used on the group headers in both chrome layouts:
// recolor, collapse/expand, and delete the whole group. Delete ungroups member
// tabs — it never closes them.

struct TabGroupActionsMenu: View {
    let group: BrowserState.TabGroup
    @Environment(BrowserState.self) private var state

    var body: some View {
        Button("Rename Group…") {
            state.beginRenamingGroup(group.id)
        }
        TabGroupColorMenu(group: group)

        Button(group.isCollapsed ? "Expand Group" : "Collapse Group") {
            state.toggleTabGroup(id: group.id)
        }

        Divider()

        Button("Delete Group", role: .destructive) {
            state.deleteTabGroup(id: group.id)
        }
    }
}
