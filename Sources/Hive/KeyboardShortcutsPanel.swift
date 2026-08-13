import SwiftUI

// MARK: - KeyboardShortcutsPanel
//
// Searchable reference of every keyboard shortcut in Hive, grouped by
// category. Pure display surface — the shortcuts themselves are registered
// in BrowserCommands (HiveApp.swift), so this panel is documentation that
// can never drift from the menu structure.

struct KeyboardShortcutsPanel: View {
    @Environment(BrowserState.self) private var state
    @State private var query: String = ""

    private var visibleSections: [(title: String, icon: String, rows: [ShortcutRow])] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ShortcutCatalog.sections.compactMap { section in
            let rows = section.rows.filter { row in
                guard !q.isEmpty else { return true }
                return row.action.lowercased().contains(q)
                    || row.shortcut.lowercased().contains(q)
                    || section.title.lowercased().contains(q)
            }
            guard !rows.isEmpty else { return nil }
            return (section.title, section.icon, rows)
        }
    }

    private var visibleShortcutCount: Int {
        visibleSections.reduce(0) { $0 + $1.rows.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(HiveDesign.Typography.panelTitleMedium)
                    .foregroundStyle(.secondary)

                TextField("Filter shortcuts...", text: $query)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.subHeading)

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("Done") { state.isKeyboardShortcutsPanelOpen = false }
                    .font(HiveDesign.Typography.smallLabelBold)
                    .buttonStyle(.borderedProminent)
                    .tint(HiveDesign.Accent.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if visibleSections.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(visibleSections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: section.icon)
                                        .font(HiveDesign.Typography.smallLabel)
                                        .foregroundStyle(Color.hiveAccent)
                                    Text(section.title)
                                        .font(HiveDesign.Typography.smallLabelBold)
                                        .foregroundStyle(Color.hiveAccent)
                                        .textCase(.uppercase)
                                }
                                .padding(.bottom, 2)

                                ForEach(section.rows) { row in
                                    ShortcutRowView(row: row)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }

            Divider()

            // Footer
            HStack(spacing: 12) {
                Text("\(visibleShortcutCount) shortcut\(visibleShortcutCount == 1 ? "" : "s")")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Shortcuts can't be remapped yet")
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(HiveDesign.Material.panel)
        .frame(width: 520, height: 480)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No matching shortcuts")
                .font(HiveDesign.Typography.bodyMedium)
                .foregroundStyle(.secondary)
            Text("Try a different action or key name")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }
}

// MARK: - ShortcutRowView

private struct ShortcutRowView: View {
    let row: ShortcutRow
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(row.action)
                .font(HiveDesign.Typography.bodyMedium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 12)
            HStack(spacing: 2) {
                ForEach(row.keyCaps, id: \.self) { cap in
                    KeyCapView(label: cap)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? HiveDesign.Surface.level1 : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

/// A single keycap chip (⌘, ⇧, K, …).
private struct KeyCapView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(HiveDesign.Text.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(HiveDesign.Surface.level2)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(HiveDesign.Surface.hairline, lineWidth: 1)
            )
    }
}

// MARK: - Catalog

/// A single documented shortcut.
private struct ShortcutRow: Identifiable, Sendable {
    let id = UUID()
    let action: String
    /// Pre-rendered keycap labels (e.g. ["⌘", "⇧", "K"]).
    let keyCaps: [String]
    var shortcut: String { keyCaps.joined() }
}

private struct ShortcutSection: Sendable {
    let title: String
    let icon: String
    let rows: [ShortcutRow]
}

private enum ShortcutCatalog {
    static let sections: [ShortcutSection] = [
        ShortcutSection(title: "Tabs & Windows", icon: "rectangle.stack", rows: [
            ShortcutRow(action: "New Tab", keyCaps: ["⌘", "T"]),
            ShortcutRow(action: "Close Tab", keyCaps: ["⌘", "W"]),
            ShortcutRow(action: "Reopen Closed Tab", keyCaps: ["⌘", "⇧", "T"]),
            ShortcutRow(action: "New Private Tab", keyCaps: ["⌘", "⇧", "N"]),
            ShortcutRow(action: "Switch to Tab 1–9", keyCaps: ["⌘", "1–9"]),
            ShortcutRow(action: "Search Tabs", keyCaps: ["⌘", "⇧", "A"]),
            ShortcutRow(action: "Bookmark All Tabs", keyCaps: ["⌘", "⇧", "D"]),
            ShortcutRow(action: "Task Manager", keyCaps: ["⇧", "⎋"]),
        ]),
        ShortcutSection(title: "Navigation", icon: "arrow.left.and.right", rows: [
            ShortcutRow(action: "Back", keyCaps: ["⌘", "["]),
            ShortcutRow(action: "Forward", keyCaps: ["⌘", "]"]),
            ShortcutRow(action: "Reload", keyCaps: ["⌘", "R"]),
            ShortcutRow(action: "Stop Loading", keyCaps: ["⌘", "."]),
            ShortcutRow(action: "Focus Address Bar", keyCaps: ["⌘", "L"]),
            ShortcutRow(action: "Find in Page", keyCaps: ["⌘", "F"]),
            ShortcutRow(action: "History", keyCaps: ["⌘", "Y"]),
            ShortcutRow(action: "Downloads", keyCaps: ["⌘", "⇧", "J"]),
        ]),
        ShortcutSection(title: "Zoom & View", icon: "plus.magnifyingglass", rows: [
            ShortcutRow(action: "Zoom In", keyCaps: ["⌘", "+"]),
            ShortcutRow(action: "Zoom Out", keyCaps: ["⌘", "−"]),
            ShortcutRow(action: "Actual Size", keyCaps: ["⌘", "0"]),
            ShortcutRow(action: "Toggle Tab Layout", keyCaps: ["⌘", "⇧", "L"]),
            ShortcutRow(action: "Toggle Compact Mode", keyCaps: ["⌘", "⇧", "⌥", "L"]),
            ShortcutRow(action: "Toggle Bookmarks Bar", keyCaps: ["⌘", "⇧", "B"]),
            ShortcutRow(action: "Full Screen", keyCaps: ["⌃", "⌘", "F"]),
            ShortcutRow(action: "Print", keyCaps: ["⌘", "P"]),
        ]),
        ShortcutSection(title: "Workspaces & Split View", icon: "rectangle.split.2x1", rows: [
            ShortcutRow(action: "Next Workspace", keyCaps: ["⌘", "⌥", "]"]),
            ShortcutRow(action: "Previous Workspace", keyCaps: ["⌘", "⌥", "["]),
            ShortcutRow(action: "Switch to Space 1–9", keyCaps: ["⌘", "⌥", "1–9"]),
            ShortcutRow(action: "Split Side by Side", keyCaps: ["⌃", "⌥", "V"]),
            ShortcutRow(action: "Split Top & Bottom", keyCaps: ["⌃", "⌥", "H"]),
            ShortcutRow(action: "Unsplit", keyCaps: ["⌃", "⌥", "U"]),
        ]),
        ShortcutSection(title: "Tools & AI", icon: "sparkles", rows: [
            ShortcutRow(action: "Command Palette", keyCaps: ["⌘", "K"]),
            ShortcutRow(action: "Bookmarks Manager", keyCaps: ["⌘", "⌥", "B"]),
            ShortcutRow(action: "Summarize Page", keyCaps: ["⌥", "S"]),
            ShortcutRow(action: "Voice Mode", keyCaps: ["⌥", "⇧", "V"]),
            ShortcutRow(action: "Quit Hive", keyCaps: ["⌘", "Q"]),
        ]),
    ]
}
