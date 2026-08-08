import Foundation

// MARK: - BrowserCommand
//
/// A finite, typed catalog of every command the browser command palette can execute.
/// Keeping the actions as an enum (rather than open closures) makes the palette
/// testable, serializable, and auditable — every command has a stable identity.
public enum BrowserCommand: String, Sendable, Codable, CaseIterable, Identifiable {
    case newTab
    case newPrivateTab
    case closeTab
    case closeOtherTabs
    case duplicateTab
    case pinTab
    case muteTab
    case nextTab
    case previousTab
    case nextSpace
    case previousSpace
    case newSpace
    case deleteSpace
    case toggleLayout
    case toggleTabOverview
    case focusOmnibar
    case reload
    case back
    case forward
    case capturePage
    case toggleReaderMode
    case toggleDownloads
    case showHistory
    case showBookmarks
    case toggleBookmarkBar
    case showSettings
    case printPage
    case toggleSwarm
    case openArchive
    case newJournal

    public var id: String { rawValue }
}

// MARK: - CommandCategory

public enum CommandCategory: String, Sendable, Codable, CaseIterable {
    case tab, space, navigation, view, tools
}

// MARK: - KeyboardShortcutDescriptor

/// A cross-platform shortcut descriptor. The macOS app layer maps this to SwiftUI
/// `.keyboardShortcut` or `KeyEquivalent`; the core stays UI-framework-agnostic.
public struct KeyboardShortcutDescriptor: Sendable, Codable, Equatable {
    public let key: String
    public let modifiers: [ShortcutModifier]

    public init(key: String, modifiers: [ShortcutModifier] = []) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Convenience: ⌘K
    public static var commandK: KeyboardShortcutDescriptor { .init(key: "k", modifiers: [.command]) }
}

public enum ShortcutModifier: String, Sendable, Codable, CaseIterable {
    case command, shift, option, control
}

// MARK: - CommandDefinition

public struct CommandDefinition: Sendable, Codable, Identifiable, Equatable {
    public let id: BrowserCommand
    public let title: String
    public let keywords: [String]
    public let category: CommandCategory
    public let shortcut: KeyboardShortcutDescriptor?
    /// Short, explicit forms exposed by the browser omnibox as `/alias`.
    /// Empty means the command remains available to the command palette but is
    /// not surfaced as an omnibox command.
    public let slashAliases: [String]

    public init(id: BrowserCommand,
                title: String,
                keywords: [String] = [],
                category: CommandCategory,
                shortcut: KeyboardShortcutDescriptor? = nil,
                slashAliases: [String] = []) {
        self.id = id
        self.title = title
        self.keywords = keywords
        self.category = category
        self.shortcut = shortcut
        self.slashAliases = slashAliases
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, keywords, category, shortcut, slashAliases
    }

    /// Old persisted command definitions predate slash aliases. Treat a
    /// missing field as the empty list so decoding remains source-compatible.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(BrowserCommand.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.keywords = try container.decode([String].self, forKey: .keywords)
        self.category = try container.decode(CommandCategory.self, forKey: .category)
        self.shortcut = try container.decodeIfPresent(KeyboardShortcutDescriptor.self, forKey: .shortcut)
        self.slashAliases = try container.decodeIfPresent([String].self, forKey: .slashAliases) ?? []
    }
}

// MARK: - CommandRegistry

public struct CommandRegistry: Sendable, Equatable {
    private let definitions: [BrowserCommand: CommandDefinition]
    /// Normalized aliases with exactly one owner. Collisions are deliberately
    /// excluded so a slash command can never dispatch by incidental ordering.
    private let uniqueSlashAliasOwners: [String: BrowserCommand]

    public init(definitions: [CommandDefinition] = CommandRegistry.defaultCommands) {
        self.definitions = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        var owners: [String: BrowserCommand] = [:]
        var collisions: Set<String> = []
        for definition in definitions {
            for alias in definition.slashAliases {
                let normalized = alias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !normalized.isEmpty else { continue }
                if owners[normalized] != nil {
                    collisions.insert(normalized)
                } else {
                    owners[normalized] = definition.id
                }
            }
        }
        for collision in collisions {
            owners.removeValue(forKey: collision)
        }
        self.uniqueSlashAliasOwners = owners
    }

    public var allCommands: [CommandDefinition] {
        definitions.values.sorted { $0.title < $1.title }
    }

    public func definition(for id: BrowserCommand) -> CommandDefinition? {
        definitions[id]
    }

    /// Resolves one exact, normalized slash alias without exposing the
    /// registry's storage to a UI target.
    public func definition(forSlashAlias alias: String) -> CommandDefinition? {
        let normalized = alias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        guard let owner = uniqueSlashAliasOwners[normalized] else { return nil }
        return definitions[owner]
    }

    /// Returns the first unambiguous alias for a command, in declaration order.
    /// This is the display/selection form used by the omnibox.
    public func slashAlias(for id: BrowserCommand) -> String? {
        guard let definition = definitions[id] else { return nil }
        return definition.slashAliases.first { alias in
            let normalized = alias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !normalized.isEmpty && uniqueSlashAliasOwners[normalized] == id
        }
    }

    /// Returns only commands intentionally exposed through the omnibox, with
    /// substring matching across title, ID, keywords, and slash aliases.
    public func slashCommands(matching query: String = "") -> [CommandDefinition] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCommands.filter { definition in
            guard slashAlias(for: definition.id) != nil else { return false }
            guard !normalized.isEmpty else { return true }
            let searchable = ([definition.title, definition.id.rawValue]
                + definition.keywords + definition.slashAliases)
                .joined(separator: " ")
                .lowercased()
            return searchable.contains(normalized)
        }
    }

    /// Fuzzy-ish search over title + keywords + raw id. Lowercased, substring match.
    public func search(query: String) -> [CommandDefinition] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allCommands }
        return allCommands.filter { cmd in
            cmd.title.lowercased().contains(q)
            || cmd.keywords.contains { $0.lowercased().contains(q) }
            || cmd.id.rawValue.lowercased().contains(q)
        }
    }
}

// MARK: - Default command catalog

public extension CommandRegistry {
    static var defaultCommands: [CommandDefinition] { [
        .init(id: .newTab,        title: "New Tab",         keywords: ["tab", "new"],                 category: .tab, shortcut: .init(key: "t", modifiers: [.command]), slashAliases: ["new", "new tab"]),
        .init(id: .newPrivateTab, title: "New Private Tab", keywords: ["tab", "private", "incognito"],   category: .tab, shortcut: .init(key: "n", modifiers: [.command, .shift]), slashAliases: ["private", "private tab"]),
        .init(id: .closeTab,      title: "Close Tab",       keywords: ["tab", "close"],               category: .tab, slashAliases: ["close", "close tab"]),
        .init(id: .closeOtherTabs,title: "Close Other Tabs",keywords: ["tab", "close", "other"],        category: .tab),
        .init(id: .duplicateTab,  title: "Duplicate Tab",   keywords: ["tab", "duplicate", "clone"],    category: .tab),
        .init(id: .pinTab,        title: "Pin / Unpin Tab", keywords: ["tab", "pin"],                   category: .tab),
        .init(id: .muteTab,       title: "Mute / Unmute Site", keywords: ["tab", "mute", "site"],      category: .tab),
        .init(id: .nextTab,       title: "Next Tab",        keywords: ["tab", "next"],                category: .tab),
        .init(id: .previousTab,   title: "Previous Tab",    keywords: ["tab", "previous", "prev"],     category: .tab),
        .init(id: .newSpace,      title: "New Space",       keywords: ["space", "workspace", "new"],   category: .space),
        .init(id: .deleteSpace,   title: "Delete Space",      keywords: ["space", "workspace", "delete"],category: .space),
        .init(id: .nextSpace,     title: "Next Space",        keywords: ["space", "workspace", "next"], category: .space, shortcut: .init(key: "]", modifiers: [.command, .option])),
        .init(id: .previousSpace, title: "Previous Space",  keywords: ["space", "workspace", "previous"], category: .space, shortcut: .init(key: "[", modifiers: [.command, .option])),
        .init(id: .toggleLayout,  title: "Toggle Layout",   keywords: ["layout", "horizontal", "vertical"], category: .view, slashAliases: ["layout", "tab layout"]),
        .init(id: .toggleTabOverview, title: "Toggle Tab Overview", keywords: ["tab", "overview", "search"], category: .view, shortcut: .init(key: "o", modifiers: [.command, .shift]), slashAliases: ["tabs", "tab search", "search tabs"]),
        .init(id: .focusOmnibar,  title: "Focus Omnibar",   keywords: ["omnibar", "address", "focus", "url"], category: .navigation, shortcut: .init(key: "l", modifiers: [.command]), slashAliases: ["address", "omnibox", "focus"]),
        .init(id: .reload,        title: "Reload Page",       keywords: ["reload", "refresh", "page"],     category: .navigation, slashAliases: ["reload", "refresh"]),
        .init(id: .back,          title: "Go Back",           keywords: ["back", "navigation"],            category: .navigation, slashAliases: ["back"]),
        .init(id: .forward,       title: "Go Forward",        keywords: ["forward", "navigation"],       category: .navigation, slashAliases: ["forward"]),
        .init(id: .capturePage,   title: "Capture to Memory", keywords: ["capture", "honeycomb", "memory"], category: .tools),
        .init(id: .toggleReaderMode, title: "Toggle Reader Mode", keywords: ["reader", "reading", "article", "mode"], category: .tools, shortcut: .init(key: "r", modifiers: [.command, .shift]), slashAliases: ["reader", "reader mode"]),
        .init(id: .toggleDownloads, title: "Toggle Downloads", keywords: ["downloads", "files"], category: .tools, shortcut: .init(key: "j", modifiers: [.command, .shift]), slashAliases: ["downloads", "download"]),
        .init(id: .showHistory,   title: "Show History",      keywords: ["history", "browse"], category: .view, shortcut: .init(key: "y", modifiers: [.command]), slashAliases: ["history"]),
        .init(id: .showBookmarks, title: "Show Bookmarks",    keywords: ["bookmarks", "favorites"], category: .view, shortcut: .init(key: "b", modifiers: [.command, .option]), slashAliases: ["bookmarks", "bookmark"]),
        .init(id: .toggleBookmarkBar, title: "Toggle Bookmark Bar", keywords: ["bookmarks", "bar"], category: .view, shortcut: .init(key: "b", modifiers: [.command, .shift])),
        .init(id: .showSettings,  title: "Show Settings",     keywords: ["settings", "preferences"], category: .tools, shortcut: .init(key: ",", modifiers: [.command])),
        .init(id: .printPage,     title: "Print Page",        keywords: ["print", "pdf"], category: .tools, shortcut: .init(key: "p", modifiers: [.command])),
        .init(id: .toggleSwarm,   title: "Ask Swarm",         keywords: ["ai", "chat", "swarm", "intelligence"], category: .tools, slashAliases: ["swarm", "ask"]),
        .init(id: .openArchive,    title: "Open Archive",      keywords: ["archive", "cold", "home", "start"], category: .view),
        .init(id: .newJournal,     title: "Draft Journal",     keywords: ["journal", "brief", "note", "write"], category: .tools),
    ] }
}
