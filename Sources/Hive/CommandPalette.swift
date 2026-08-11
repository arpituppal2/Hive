import SwiftUI
import HiveCore

// MARK: - CommandPaletteOverlay
//
// A Raycast/Arc-style command palette triggered by ⌘K. It lists browser commands and
// filters them as the user types.

struct CommandPaletteOverlay: View {
    @Environment(BrowserState.self) private var state
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isFocused: Bool

    private var filteredCommands: [PaletteCommand] {
        PaletteCommand.allCommands(in: state).filter { command in
            query.isEmpty
            || command.title.localizedCaseInsensitiveContains(query)
            || command.subtitle?.localizedCaseInsensitiveContains(query) == true
            || command.keywords.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    private func clampSelection() {
        let count = filteredCommands.count
        selectedIndex = count == 0 ? 0 : min(selectedIndex, count - 1)
    }

    var body: some View {
        ZStack {
            HiveDesign.Surface.canvas.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture { state.closeCommandPalette() }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search commands...", text: $query)
                        .textFieldStyle(.plain)
                        .font(HiveDesign.Typography.subHeading)
                        .focused($isFocused)
                        .onSubmit {
                            let commands = filteredCommands
                            if selectedIndex >= 0 && selectedIndex < commands.count {
                                execute(commands[selectedIndex])
                            }
                        }
                        .onChange(of: query) { _, _ in
                            selectedIndex = 0
                        }
                        .onChange(of: filteredCommands.count) { _, _ in
                            // The list can shrink for many reasons while the
                            // palette stays open (tab close/reorder, workspace
                            // or profile switch, split state, page availability,
                            // edited custom commands). Keep the selection valid.
                            clampSelection()
                        }
                        .onKeyPress(.escape) { state.closeCommandPalette(); return .handled }
                        .onKeyPress(.upArrow) {
                            let count = filteredCommands.count
                            if count > 0 {
                                selectedIndex = (selectedIndex - 1 + count) % count
                            }
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            let count = filteredCommands.count
                            if count > 0 {
                                selectedIndex = (selectedIndex + 1) % count
                            }
                            return .handled
                        }

                    if !query.isEmpty {
                        Button(action: { query = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filteredCommands.isEmpty {
                            VStack(spacing: HiveDesign.Space.sm) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: HiveDesign.Icon.xl))
                                    .foregroundStyle(.tertiary)
                                Text("No matching commands")
                                    .font(HiveDesign.Typography.body)
                                    .foregroundStyle(.secondary)
                                Text("Try a different search — commands, tabs, and workspaces all appear here.")
                                    .font(HiveDesign.Typography.caption)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HiveDesign.Space.xxl)
                        } else {
                            ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                                CommandRow(command: command, isSelected: index == selectedIndex) { execute(command) }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 320)

                Divider()

                HStack {
                    Text(filteredCommands.isEmpty ? "No results" : "\(filteredCommands.count) commands")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(HiveDesign.Material.panel)
            .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 6)
            .frame(maxWidth: 560)
            .padding(.horizontal, 40)
            .onAppear { isFocused = true }
        }
    }

    private func execute(_ command: PaletteCommand) {
        state.closeCommandPalette()
        command.action(state)
    }
}

// MARK: - CommandRow

struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: command.icon)
                    .font(HiveDesign.Typography.panelTitle)
                    .foregroundStyle(isSelected ? HiveDesign.Accent.primary : HiveDesign.Text.secondary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(.primary)

                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(HiveDesign.Typography.smallLabel)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let shortcut = command.shortcut {
                    Text(shortcut)
                        .font(HiveDesign.Typography.smallLabelMedium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? HiveDesign.Accent.muted : (isHovered ? HiveDesign.Surface.level1 : Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - PaletteCommand

@MainActor
struct PaletteCommand: Identifiable {
    /// Stable across SwiftUI body evaluations. UUID-backed command identity
    /// caused rows and keyboard selection to churn whenever browser state
    /// changed while the palette remained open.
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let keywords: [String]
    let shortcut: String?
    let action: (BrowserState) -> Void

    init(
        id: String? = nil,
        title: String,
        subtitle: String?,
        icon: String,
        keywords: [String],
        shortcut: String?,
        action: @escaping (BrowserState) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.keywords = keywords
        self.shortcut = shortcut
        self.action = action
        self.id = id ?? [title, subtitle ?? ""].joined(separator: "|")
    }

    static func allCommands(in state: BrowserState) -> [PaletteCommand] {
        var commands: [PaletteCommand] = [
            PaletteCommand(title: "New Tab", subtitle: "Open a new tab", icon: "plus", keywords: ["new", "tab"], shortcut: "⌘T") { state in
                state.showFloatingURLBar(opensNewTab: true)
            },
            PaletteCommand(title: "Close Tab", subtitle: "Close the active tab", icon: "xmark", keywords: ["close", "tab"], shortcut: "⌘W") { state in
                state.closeActiveTab()
            },
            PaletteCommand(title: "Reopen Closed Tab", subtitle: "Restore the last closed tab", icon: "arrow.uturn.backward", keywords: ["reopen", "undo"], shortcut: "⇧⌘T") { state in
                state.reopenLastClosed()
            },
            PaletteCommand(title: "Reload", subtitle: "Reload the current page", icon: "arrow.clockwise", keywords: ["reload", "refresh"], shortcut: "⌘R") { state in
                state.reload()
            },
            PaletteCommand(title: "Toggle Layout", subtitle: "Switch between horizontal and vertical tabs", icon: "rectangle.split.2x1", keywords: ["layout", "vertical", "horizontal"], shortcut: "⇧⌘L") { state in
                state.toggleLayout()
            },
            PaletteCommand(title: "Focus Address Bar", subtitle: "Jump to the address bar", icon: "link", keywords: ["address", "url", "omnibox"], shortcut: "⌘L") { state in
                state.focusAddressBar()
            },
            PaletteCommand(title: "Toggle Compact Mode", subtitle: "Hide chrome; hover edges to reveal", icon: "rectangle.compress.vertical", keywords: ["compact", "zen", "chrome", "hide", "fullscreen"], shortcut: "⌥⇧⌘L") { state in
                state.toggleCompactMode()
            },
            PaletteCommand(title: "Search Tabs", subtitle: "Jump to any open tab across spaces", icon: "square.on.square", keywords: ["tabs", "search", "switch", "jump", "spaces"], shortcut: "⇧⌘A") { state in
                state.openTabSearch()
            },
            PaletteCommand(title: "Tab Overview", subtitle: "Visual grid of all open tabs", icon: "square.grid.2x2", keywords: ["tabs", "overview", "grid", "visual", "all", "spaces", "workspace"], shortcut: nil) { state in
                state.openTabGrid()
            },
            PaletteCommand(title: "Group Similar Tabs", subtitle: "Auto-group open tabs by site", icon: "square.stack.3d.up.fill", keywords: ["group", "tabs", "similar", "organize", "domain", "site"], shortcut: nil) { state in
                state.groupSimilarTabs()
            },
            PaletteCommand(title: "Fullscreen", subtitle: "Enter or exit full screen", icon: "arrow.up.left.and.arrow.down.right", keywords: ["fullscreen", "full", "screen"], shortcut: "⌃⌘F") { state in
                state.toggleFullscreen()
            },
            PaletteCommand(title: "New Private Tab", subtitle: "Open an ephemeral tab with no history or saved context", icon: "theatermasks", keywords: ["private", "incognito", "new", "tab"], shortcut: "⇧⌘N") { state in
                state.newPrivateTab()
            },
        ]

        // Page-only actions are omitted on Hive/internal and blank surfaces;
        // showing a button that can only no-op makes the palette feel unreliable.
        if state.canUseWebPageActions {
            commands.append(contentsOf: [
                PaletteCommand(title: "Find in Page", subtitle: "Search the current page", icon: "magnifyingglass", keywords: ["find", "search", "page"], shortcut: "⌘F") { state in
                    state.openFindBar()
                },
                PaletteCommand(title: "Zoom In", subtitle: "Zoom into the current page", icon: "plus.magnifyingglass", keywords: ["zoom", "in", "bigger"], shortcut: "⌘+") { state in
                    state.zoomIn()
                },
                PaletteCommand(title: "Zoom Out", subtitle: "Zoom out of the current page", icon: "minus.magnifyingglass", keywords: ["zoom", "out", "smaller"], shortcut: "⌘−") { state in
                    state.zoomOut()
                },
                PaletteCommand(title: "Actual Size", subtitle: "Reset zoom to 100%", icon: "1.magnifyingglass", keywords: ["zoom", "reset", "actual", "100"], shortcut: "⌘0") { state in
                    state.resetZoom()
                },
                PaletteCommand(title: "Print", subtitle: "Print the current page", icon: "printer", keywords: ["print", "printer", "paper"], shortcut: "⌘P") { state in
                    state.printCurrentPage()
                },
                PaletteCommand(title: "Reader Mode", subtitle: "Read the page distraction-free", icon: "book", keywords: ["reader", "read", "article"], shortcut: nil) { state in
                    state.toggleReaderMode()
                },
                PaletteCommand(title: "Take Screenshot…", subtitle: "Save the current page as a PNG", icon: "camera.viewfinder", keywords: ["screenshot", "capture", "png", "image", "save"], shortcut: nil) { state in
                    state.capturePageScreenshot()
                },
                PaletteCommand(title: "Copy Screenshot", subtitle: "Copy the current page to the clipboard", icon: "doc.on.clipboard", keywords: ["screenshot", "copy", "capture", "clipboard", "image"], shortcut: nil) { state in
                    state.copyPageScreenshot()
                },
                PaletteCommand(title: "Capture Full Page…", subtitle: "Save the whole scrollable page as a tall PNG", icon: "rectangle.stack.fill", keywords: ["screenshot", "full", "page", "long", "capture", "png", "save"], shortcut: nil) { state in
                    state.captureFullPageScreenshot()
                },
                PaletteCommand(title: "Copy Full Page", subtitle: "Copy the whole page to the clipboard", icon: "rectangle.on.rectangle", keywords: ["screenshot", "full", "page", "copy", "capture", "long"], shortcut: nil) { state in
                    state.copyFullPageScreenshot()
                },
                PaletteCommand(title: "Rename Active Tab…", subtitle: "Give the current tab a custom name", icon: "pencil", keywords: ["rename", "tab", "name", "label", "title"], shortcut: nil) { state in
                    if let tab = state.activeTab {
                        state.presentTabRename(tab)
                    }
                },
                PaletteCommand(title: "Copy Page URL", subtitle: "Copy the current page's address", icon: "link", keywords: ["copy", "url", "address", "link"], shortcut: nil) { state in
                    state.copyPageURL()
                },
                PaletteCommand(title: "Copy All Tab URLs", subtitle: "Copy every open tab URL in this workspace", icon: "doc.on.doc", keywords: ["copy", "url", "links", "tabs", "workspace"], shortcut: nil) { state in
                    state.copyAllTabURLs()
                },
                PaletteCommand(title: "Copy All Tabs as Markdown", subtitle: "Copy every tab as a markdown link list", icon: "text.quote", keywords: ["copy", "markdown", "links", "tabs", "notes", "workspace"], shortcut: nil) { state in
                    state.copyAllTabsAsMarkdown()
                },
            ])
        }

        // Surface panels (Chrome/Safari parity in the launcher)
        let panels: [(title: String, subtitle: String, icon: String, keywords: [String], shortcut: String?, open: (BrowserState) -> Void)] = [
            ("Downloads", "View and manage downloads", "arrow.down.circle", ["download", "files"], nil, { $0.isDownloadsPanelOpen = true }),
            ("History", "Browse your browsing history", "clock.arrow.circlepath", ["history"], nil, { $0.isHistoryPanelOpen = true }),
            ("Bookmarks Manager", "Organize saved bookmarks", "bookmark", ["bookmark", "bookmarks"], "⌥⌘B", { $0.openBookmarksManager() }),
            ("Bookmark All Tabs", "Save every open tab in a new folder", "bookmark.fill", ["bookmark", "all", "tabs", "folder", "save"], "⇧⌘D", { $0.bookmarkAllTabs() }),
            ("Reading List", "Articles saved for later", "book.closed", ["reading", "read", "later", "save", "articles"], nil, { $0.isReadingListPanelOpen = true }),
            ("Pinned Apps", "Manage quick-launch web apps", "square.grid.2x2.fill", ["pinned", "apps", "app", "rail", "favorites"], nil, { $0.isPinnedAppsPanelOpen = true }),
            ("Archive", "Recently archived cold tabs", "archivebox", ["archive", "archived", "cold", "old", "shelf", "recently"], nil, { $0.isArchivePanelOpen = true }),
            ("Workspaces", "Manage workspaces", "square.stack.3d.up", ["workspaces", "workspace", "spaces", "manage", "switch"], nil, { $0.openWorkspaceManager() }),
            ("Profiles", "Manage browsing profiles", "person.circle", ["profiles", "profile", "person", "browsing", "manage"], nil, { $0.openProfileManager() }),
            ("Tab Groups", "Manage tab groups in this workspace", "folder", ["tab", "groups", "group", "folder", "manage"], nil, { $0.openTabGroupManager() }),
            ("Search Engines", "Manage search engines", "magnifyingglass.circle", ["search", "engine", "engines", "manage", "custom"], nil, { $0.openSearchEngineManager() }),
            ("Keyboard Shortcuts", "See all shortcuts", "keyboard", ["shortcuts", "keyboard", "keys", "help"], nil, { $0.openKeyboardShortcuts() }),
            ("Memory Saver", "Sleep and wake tabs to save memory", "leaf", ["memory", "saver", "sleep", "wake", "tabs", "performance", "hibernate"], nil, { $0.openMemorySaver() }),
            ("Task Manager", "Live per-process memory and CPU", "chart.bar.fill", ["task", "manager", "process", "memory", "cpu", "performance"], "⇧⎋", { $0.openTaskManager() }),
            ("Passwords", "View saved passwords", "key", ["password", "passwords", "login"], nil, { $0.isPasswordsManagerOpen = true }),
            ("Privacy Report", "Trackers blocked and protections", "checkmark.shield", ["privacy", "tracker", "shield", "report"], nil, { $0.openPrivacyReport() }),
            ("Safety Check…", "Review passwords, Safe Browsing, and updates", "checkmark.shield.fill", ["safety", "check", "security", "passwords", "audit", "updates", "shield", "extensions"], nil, { $0.isSafetyCheckPanelOpen = true }),
            ("Clear Browsing Data…", "Remove history, downloads, cookies, and cache", "trash", ["clear", "browsing", "data", "history", "cookies", "cache", "delete"], nil, { $0.isClearDataPanelOpen = true }),
            ("Site Settings", "Review per-site zoom, mute, and permissions", "globe.americas", ["site", "sites", "per-site", "zoom", "mute", "permissions", "settings"], nil, { $0.openSiteSettings() }),
            ("Ask Hive", "Open the AI assistant panel", "sparkles", ["ai", "ask", "assistant", "hive", "gemini", "chat"], nil, { $0.toggleGeminiPanel() }),
            ("Knowledge", "Open your Honeycomb memory", "hexagon", ["knowledge", "memory", "honeycomb", "graph"], nil, { $0.toggleKnowledgePanel() }),
            ("Studio", "Open the code workspace", "chevron.left.forwardslash.chevron.right", ["studio", "code", "repo", "project", "diff", "edit"], nil, { $0.toggleStudioPanel() }),
            ("Sheets", "Open Hive Sheets spreadsheets", "tablecells", ["sheet", "sheets", "spreadsheet", "excel", "csv", "table", "data"], nil, { $0.toggleSheetsPanel() }),
        ]
        for panel in panels {
            commands.append(
                PaletteCommand(
                    title: panel.title,
                    subtitle: panel.subtitle,
                    icon: panel.icon,
                    keywords: panel.keywords,
                    shortcut: panel.shortcut
                ) { state in
                    panel.open(state)
                }
            )
        }

        // Split view (Arc parity) — dynamic: adds an entry per candidate tab,
        // capped to keep the palette scannable. Hibernated tabs are excluded
        // (waking them just to peek at the list would waste memory).
        let splitCandidates = state.unpinnedTabs
            .filter { $0.id != state.activeTabID && !$0.isHibernated }
            .prefix(8)
        for tab in splitCandidates {
            let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "tab") : tab.model.title
            commands.append(
                PaletteCommand(
                    id: "split-\(tab.id)",
                    title: "Split with \"\(title)\"",
                    subtitle: "View the active tab and this tab side by side",
                    icon: "rectangle.split.2x1",
                    keywords: ["split", "side", "by", "side", title.lowercased()],
                    shortcut: nil
                ) { _ in
                    state.splitActiveTab(with: tab.id)
                }
            )
        }

        if state.isSplitViewActive {
            commands.append(
                PaletteCommand(
                    title: "Unsplit",
                    subtitle: "Return to a single tab view",
                    icon: "rectangle.split.2x1.fill",
                    keywords: ["split", "unsplit", "single"],
                    shortcut: nil
                ) { _ in
                    state.unsplit()
                }
            )
        }

        // AI Skills (Dia-style slash commands)
        for skill in SkillRunner.allSkills {
            commands.append(
                PaletteCommand(
                    id: "skill-\(skill.command)",
                    title: "\(skill.command) — \(skill.title)",
                    subtitle: skill.description,
                    icon: skill.icon,
                    keywords: [skill.command, skill.title.lowercased(), "skill", "ai"],
                    shortcut: nil
                ) { _ in
                    SkillRunner.run(skill.command, in: state)
                }
            )
        }

        // Profile switcher
        for profile in state.profiles {
            commands.append(
                PaletteCommand(
                    id: "profile-\(profile.id.uuidString)",
                    title: "Switch Profile to \(profile.name)",
                    subtitle: "Use the \(profile.name) browsing context",
                    icon: profile.iconName,
                    keywords: ["profile", profile.name.lowercased()],
                    shortcut: nil
                ) { _ in
                    state.switchProfile(to: profile.id)
                }
            )
        }

        // User-defined commands. Invalid persisted entries are filtered at the
        // session boundary and again here so the palette never exposes a dead
        // navigation action.
        for cmd in state.userDefinedCommands where cmd.isValidWebURL {
            commands.append(
                PaletteCommand(
                    id: "custom-\(cmd.id)",
                    title: cmd.title,
                    subtitle: cmd.url,
                    icon: cmd.icon,
                    keywords: ["custom"] + cmd.keywords,
                    shortcut: nil
                ) { state in
                    guard cmd.isValidWebURL, let url = URL(string: cmd.url) else { return }
                    state.newTab(url: url)
                }
            )
        }

        // Workspace switcher (only show workspaces in current profile)
        for workspace in state.workspacesForCurrentProfile where workspace.profileID == state.currentProfileID {
            commands.append(
                PaletteCommand(
                    id: "workspace-\(workspace.id.uuidString)",
                    title: "Switch Workspace to \(workspace.name)",
                    subtitle: "Move to the \(workspace.name) workspace",
                    icon: workspace.iconName,
                    keywords: ["workspace", workspace.name.lowercased()],
                    shortcut: nil
                ) { _ in
                    state.switchWorkspace(to: workspace.id)
                }
            )
        }

        return commands
    }
}

