import Foundation

// MARK: - Space (workspace)
//
// An Arc/Zen-style workspace — a named group of tabs that shares an isolated browsing
// context. In vertical mode, tabs are listed under their Space; in horizontal mode the
// Space is the active workspace but tabs render flat across the top (SPEC §7.2).
//
// A Space owns its tab IDs (not the tab state itself — that lives per-tab in BrowserTab).
// Switching spaces swaps the visible tab set; per Arc, each space "remembers" which of its
// tabs was last active.

public struct Space: Sendable, Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public var name: String
    /// Accent tint hint (optional; defaults to hive amber). Stored as a HiveColorToken
    /// case name so it round-trips without Color. `.accent` is the default.
    public var accentTokenName: String
    /// SFSymbol icon name for the space (e.g. "briefcase.fill", "gamecontroller.fill").
    /// Defaults to a generic grid icon so every space has a visual avatar.
    public var iconName: String
    /// Tab IDs in display order (pinned first, then open). The model never duplicates.
    public var tabIDs: [String]
    /// The tab that was last active in this space (so switching back restores focus).
    public var activeTabID: String?
    /// Tab groups in this space (the "missing middle": Pinned → Tab → Group → Space). Tabs not
    /// in any group render under an implicit "Ungrouped" section. A group owns tab IDs, never
    /// tab state (that lives per-tab in BrowserTab). Empty by default; populated by slice 5's
    /// group UI. Persisted via the session schema from day one so slice 5 persistence is free.
    public var groups: [TabGroup] = []
    public let createdAt: Date

    public init(id: String = UUID().uuidString,
                name: String,
                accentTokenName: String = HiveColorToken.accent.rawValue,
                iconName: String = Space.defaultIconName,
                tabIDs: [String] = [],
                activeTabID: String? = nil,
                groups: [TabGroup] = [],
                createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.accentTokenName = accentTokenName
        self.iconName = iconName
        self.tabIDs = tabIDs
        self.activeTabID = activeTabID
        self.groups = groups
        self.createdAt = createdAt
    }

    // MARK: Forward-compatible Codable
    //
    // Synthesized Codable would require EVERY defaulted field to be present in JSON, so adding
    // a field (e.g. `groups`) would make an older `session.json` fail to decode → the whole
    // session restore falls through to `.corrupt`. That breaks the trust primitive (design doc
    // §9: an older-schema session must still load). So `id` + `name` stay required (identity +
    // label must round-trip), but every defaulted field decodes via `decodeIfPresent` → absent
    // or null keys fall back to the same defaults as the memberwise init. Encode stays
    // synthesized (writes all keys; null/empty optionals serialize as null/[]).
    private enum CodingKeys: String, CodingKey {
        case id, name, accentTokenName, iconName, tabIDs, activeTabID, groups, createdAt
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        accentTokenName = try c.decodeIfPresent(String.self, forKey: .accentTokenName)
            ?? HiveColorToken.accent.rawValue
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName)
            ?? Space.defaultIconName
        tabIDs = try c.decodeIfPresent([String].self, forKey: .tabIDs) ?? []
        activeTabID = try c.decodeIfPresent(String.self, forKey: .activeTabID)
        groups = try c.decodeIfPresent([TabGroup].self, forKey: .groups) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    /// The default SFSymbol name used when a space has no custom icon.
    public static let defaultIconName = "square.grid.2x2"

    /// The default space every window boots with ("Default" / pinned first).
    public static func defaultSpace() -> Space {
        Space(name: "Default")
    }

    /// True iff `tabID` belongs to this space.
    public func contains(tabID: String) -> Bool { tabIDs.contains(tabID) }

    /// Add a tab ID if not already present (idempotent), preserving order.
    public mutating func addTab(_ tabID: String) {
        guard !tabIDs.contains(tabID) else { return }
        tabIDs.append(tabID)
    }

    /// Remove a tab ID. Clears activeTabID if it pointed at the removed tab.
    public mutating func removeTab(_ tabID: String) {
        tabIDs.removeAll { $0 == tabID }
        if activeTabID == tabID { activeTabID = tabIDs.last }
    }

    /// Move a tab within this space so it **ends up at final index** `newIndex`.
    ///
    /// Final-position semantics: after `moveTab(id, to: p)`, `id` is at index `p` in
    /// `tabIDs` (clamped to `[0, count-1]`). This matches the drag-to-position mental model
    /// the SwiftUI reorder UI presents, and makes "move-to-front" (`to: 0`) and
    /// "move-to-end" (`to: count - 1`) lands exactly at the edges.
    ///
    /// Why no index correction is needed: removing `id` shrinks the array to size `n-1`, but
    /// inserting at position `clamped` (≤ `n-1`) in that array always lands the element at
    /// final index `clamped` regardless of where it was removed from. The earlier `-1`
    /// correction was an insert-before-semantics artifact and broke move-to-end.
    public mutating func moveTab(_ tabID: String, to newIndex: Int) {
        guard let oldIndex = tabIDs.firstIndex(of: tabID) else { return }
        guard !tabIDs.isEmpty else { return }
        let clamped = min(max(0, newIndex), tabIDs.count - 1)
        guard oldIndex != clamped else { return }
        tabIDs.remove(at: oldIndex)
        tabIDs.insert(tabID, at: clamped)
    }
}
