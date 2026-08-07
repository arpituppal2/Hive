import SwiftUI
import HiveCore

// MARK: - PaletteSection

enum PaletteSection: String, CaseIterable, Identifiable, Sendable {
    case topHits = "Top Hits"
    case quickActions = "Quick Actions"
    case openTabs = "Open Tabs"
    case commands = "Commands"
    case bookmarks = "Bookmarks"
    case history = "History"
    case spaces = "Spaces"
    case fallback = "Actions"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topHits: return "Top Hits"
        case .quickActions: return "Quick Actions"
        case .openTabs: return "Open Tabs"
        case .commands: return "Commands"
        case .bookmarks: return "Bookmarks"
        case .history: return "History"
        case .spaces: return "Spaces"
        case .fallback: return "Actions"
        }
    }

    var sortOrder: Int {
        switch self {
        case .topHits: return 0
        case .quickActions: return 1
        case .openTabs: return 2
        case .commands: return 3
        case .bookmarks: return 4
        case .history: return 5
        case .spaces: return 6
        case .fallback: return 7
        }
    }
}

// MARK: - FallbackKind

enum FallbackKind {
    case openURL(URL)
    case searchWeb(String)
    case askSwarm(String)
    case searchHistory(String)
}

// MARK: - PaletteResult

enum PaletteResult: Identifiable {
    case command(CommandDefinition)
    case tab(BrowserTab)
    case history(BrowsingHistoryEntry)
    case bookmark(Bookmark)
    case space(Space)
    case fallback(FallbackKind, title: String, subtitle: String, iconName: String)

    var id: String {
        switch self {
        case .command(let cmd): return "cmd-\(cmd.id.rawValue)"
        case .tab(let tab):     return "tab-\(tab.id)"
        case .history(let h):   return "hist-\(h.id)"
        case .bookmark(let b):  return "bmk-\(b.id)"
        case .space(let s):     return "space-\(s.id)"
        case .fallback(let kind, _, _, _):
            switch kind {
            case .openURL:       return "fallback-url"
            case .searchWeb:     return "fallback-web"
            case .askSwarm:      return "fallback-swarm"
            case .searchHistory: return "fallback-history"
            }
        }
    }

    var title: String {
        switch self {
        case .command(let cmd): return cmd.title
        case .tab(let tab):     return tab.title.isEmpty ? (tab.url?.host ?? "Untitled") : tab.title
        case .history(let h):   return h.title.isEmpty ? h.host : h.title
        case .bookmark(let b):  return b.title
        case .space(let s):     return s.name
        case .fallback(_, let title, _, _): return title
        }
    }

    var subtitle: String {
        switch self {
        case .command(let cmd): return cmd.category.rawValue.capitalized
        case .tab(let tab):     return tab.url?.host ?? "Open Tab"
        case .history(let h):   return h.host
        case .bookmark(let b):  return b.host
        case .space:            return "Workspace"
        case .fallback(_, _, let subtitle, _): return subtitle
        }
    }

    var section: PaletteSection {
        switch self {
        case .command:  return .commands
        case .tab:      return .openTabs
        case .history:  return .history
        case .bookmark: return .bookmarks
        case .space:    return .spaces
        case .fallback: return .fallback
        }
    }

    var badge: String? {
        switch self {
        case .command:  return nil
        case .tab:      return "Tab"
        case .history:  return "History"
        case .bookmark: return "Bookmark"
        case .space:    return "Space"
        case .fallback: return nil
        }
    }

    var iconName: String {
        switch self {
        case .command(let cmd): return iconForCommand(cmd)
        case .tab:              return "globe"
        case .history:          return "clock.arrow.circlepath"
        case .bookmark:         return "book.bookmark"
        case .space(let s):     return s.iconName
        case .fallback(_, _, _, let icon): return icon
        }
    }

    var shortcut: KeyboardShortcutDescriptor? {
        switch self {
        case .command(let cmd): return cmd.shortcut
        default: return nil
        }
    }

    /// Stable action identifier used for frecency/usage tracking.
    var actionID: String { id }
}

// MARK: - Command icon mapping

func iconForCommand(_ cmd: CommandDefinition) -> String {
    switch cmd.id {
    case .newTab, .newPrivateTab:       return "plus.square"
    case .closeTab, .closeOtherTabs:    return "xmark.square"
    case .duplicateTab:                  return "doc.on.doc"
    case .pinTab:                       return "pin"
    case .muteTab:                       return "speaker.slash"
    case .nextTab, .previousTab:        return "arrow.left.arrow.right"
    case .newSpace, .nextSpace, .previousSpace, .deleteSpace:
        return "square.stack.3d.up"
    case .toggleLayout:                  return "rectangle.split.2x1"
    case .toggleTabOverview:             return "rectangle.grid.1x2"
    case .focusOmnibar:                  return "magnifyingglass"
    case .reload:                         return "arrow.clockwise"
    case .back:                           return "arrow.uturn.backward"
    case .forward:                        return "arrow.uturn.forward"
    case .capturePage:                    return "doc.text.magnifyingglass"
    case .toggleReaderMode:               return "doc.text"
    case .toggleDownloads:                return "arrow.down.circle"
    case .showHistory:                    return "clock.arrow.circlepath"
    case .showBookmarks, .toggleBookmarkBar:
        return "book.bookmark"
    case .showSettings:                   return "gear"
    case .printPage:                      return "printer"
    case .toggleSwarm:                    return "bubble.left"
    case .openArchive:                    return "archivebox"
    case .newJournal:                     return "doc.badge.plus"
    }
}
