import Foundation

// MARK: - AutoArchivePolicy
//
// The §7 policy table as a pure function: given all open tabs, pinned/active guard sets,
// and the current time + threshold, returns the set of tab IDs that should be auto-archived.
//
// Precedence (from the design doc):
//   • Pinned tabs → never
//   • Active tab → never
//   • Tabs in an unfolded group the user is actively using → never (the group keeps them "warm")
//   • url == nil (new tab / start page) → skip
//   • lastVisitedAt within the threshold → skip (still warm)
//   • Else → archive candidate
//
// The caller is responsible for: hibernating the tab (capture interactionState), creating
// an ArchivedTab record, creating a Honeycomb node, removing the tab from its space/group,
// and clearing the tab model from ChromeState.

public enum AutoArchivePolicy {

    /// Number of seconds in the default threshold (14 days).
    public static let defaultThreshold: TimeInterval = 14 * 86_400

    /// Evaluates which tabs should be auto-archived. Returns the set of tab IDs.
    /// - Parameters:
    ///   - tabs: All live BrowserTabs.
    ///   - pinnedTabIDs: Tabs marked pinned (never archived).
    ///   - activeTabID: The frontmost tab (never archived).
    ///   - foldedGroupTabIDs: Tabs belonging to currently-folded groups (group is inactive).
    ///   - now: The current date.
    ///   - threshold: How long since lastVisit before a tab is "cold". Default 14 days.
    /// - Returns: The set of tab IDs to archive.
    public static func evaluate(
        tabs: [BrowserTab],
        pinnedTabIDs: Set<String> = [],
        activeTabID: String? = nil,
        foldedGroupTabIDs: Set<String> = [],
        now: Date = Date(),
        threshold: TimeInterval = defaultThreshold
    ) -> Set<String> {
        var candidates = Set<String>()
        for tab in tabs {
            // Private tabs are ephemeral by contract: they must never enter
            // the durable Recently Archived shelf, even when they are cold.
            guard !tab.isPrivate else { continue }
            guard !pinnedTabIDs.contains(tab.id) else { continue }
            guard tab.id != activeTabID else { continue }
            guard tab.url != nil else { continue }
            guard !foldedGroupTabIDs.contains(tab.id) else { continue }
            guard now.timeIntervalSince(tab.lastVisitedAt) >= threshold else { continue }
            candidates.insert(tab.id)
        }
        return candidates
    }
}