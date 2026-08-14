import Foundation

// MARK: - TabGroup (the missing middle — Pinned → Tab → Group → Space)
//
// A named, color-dotted, collapsible set of tabs within a Space (hive-browser-base-design.md
// §5). Hive previously had only Pinned → Tab → Space; every peer browser carries a mid-level
// grouping (Chrome tab groups, Vivaldi stacks, Safari Tab Groups, Sidebery folds), and the
// strongest finding from the tab-management research is that *folding a group should free RAM,
// not just pixels*. So `isFolded` is the hibernation trigger (§8 policy), and unfolding
// restores losslessly via `interactionState`.
//
// Like `Space`, a Group owns **tab IDs**, never tab state (that lives per-tab in BrowserTab).
// Tabs not in any group render under an implicit "Ungrouped" section in both layouts. A group
// remembers which of its tabs was last active so unfolding can restore focus.

public struct TabGroup: Sendable, Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public var name: String
    /// Accent tint dot, stored as a HiveColorToken case name so it round-trips without Color.
    /// Defaults to hive honey.
    public var colorDot: String
    /// Tab IDs in display order within this group. The model never duplicates.
    public var tabIDs: [String]
    /// Collapsed → the group's tabs hibernate (free RAM) + the chip shows a count, not titles.
    public var isFolded: Bool
    /// The tab that was last active in this group (so unfolding restores focus).
    public var lastActiveTabID: String?
    public let createdAt: Date

    public init(id: String = UUID().uuidString,
                name: String,
                colorDot: String = HiveColorToken.accent.rawValue,
                tabIDs: [String] = [],
                isFolded: Bool = false,
                lastActiveTabID: String? = nil,
                createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorDot = colorDot
        self.tabIDs = tabIDs
        self.isFolded = isFolded
        self.lastActiveTabID = lastActiveTabID
        self.createdAt = createdAt
    }
}
