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

    /// The minimal tab shape the app-facing overload needs. Mirrors the
    /// ``TabCleanupPlanner.TabInput`` convention: a pure snapshot with no
    /// model references, so the policy stays testable in HiveCore.
    public struct TabInput: Sendable, Equatable {
        public let id: String
        public let url: URL?
        public let lastVisitedAt: Date
        public let isPinned: Bool
        public let isEssential: Bool
        public let isPrivate: Bool

        public init(
            id: String,
            url: URL?,
            lastVisitedAt: Date,
            isPinned: Bool = false,
            isEssential: Bool = false,
            isPrivate: Bool = false
        ) {
            self.id = id
            self.url = url
            self.lastVisitedAt = lastVisitedAt
            self.isPinned = isPinned
            self.isEssential = isEssential
            self.isPrivate = isPrivate
        }
    }

    /// Evaluates which tabs should be auto-archived, from the app's own tab
    /// snapshot. Returns the set of tab IDs.
    /// - Parameters:
    ///   - tabs: All live tabs as pure inputs.
    ///   - activeTabID: The frontmost tab (never archived).
    ///   - collapsedGroupTabIDs: Tabs in collapsed/folded groups (group is
    ///     explicit rest — never archived even when cold).
    ///   - now: The current date.
    ///   - threshold: How long since lastVisit before a tab is "cold".
    ///     Default 14 days.
    /// - Returns: The set of tab IDs to archive.
    public static func evaluate(
        tabs: [TabInput],
        activeTabID: String? = nil,
        collapsedGroupTabIDs: Set<String> = [],
        now: Date = Date(),
        threshold: TimeInterval = defaultThreshold
    ) -> Set<String> {
        var candidates = Set<String>()
        for tab in tabs {
            // Private tabs are ephemeral by contract: they must never enter
            // the durable Recently Archived shelf, even when they are cold.
            guard !tab.isPrivate else { continue }
            // Pinned and essential tabs are user-affirmed keepers (Chrome
            // never archives a pinned tab; Arc never archives favorites).
            guard !tab.isPinned, !tab.isEssential else { continue }
            guard tab.id != activeTabID else { continue }
            // A collapsed group is explicit rest — never auto-archive its
            // members, even when they are cold.
            guard !collapsedGroupTabIDs.contains(tab.id) else { continue }
            // Internal chrome routes (hive://, about:) have no URL worth
            // restoring; a blank/new-tab has nothing to reopen.
            guard tab.url != nil else { continue }
            guard now.timeIntervalSince(tab.lastVisitedAt) >= threshold else { continue }
            candidates.insert(tab.id)
        }
        return candidates
    }

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
        evaluate(
            tabs: tabs.map { TabInput(
                id: $0.id,
                url: $0.url,
                lastVisitedAt: $0.lastVisitedAt,
                isPinned: pinnedTabIDs.contains($0.id),
                isPrivate: $0.isPrivate
            ) },
            activeTabID: activeTabID,
            collapsedGroupTabIDs: foldedGroupTabIDs,
            now: now,
            threshold: threshold
        )
    }
}

// MARK: - TabArchiveShelfPolicy
//
// Pure rules for the durable "Recently Archived" shelf. The shelf is newest-
// archived first; it is capped so the session file stays lean, and re-opening
// an archived tab removes its record (it's live again).

public enum TabArchiveShelfPolicy {

    /// Maximum archived-tab records retained. Oldest records drop on overflow.
    public static let hiveArchivedTabsCap = 100

    /// The shelf display order: newest-archived first (stable for equal
    /// timestamps via the record id).
    public static func sortedForShelf(_ records: [ArchivedTab]) -> [ArchivedTab] {
        records.sorted {
            if $0.archivedAt != $1.archivedAt { return $0.archivedAt > $1.archivedAt }
            return $0.id < $1.id
        }
    }

    public static func applyCap(_ records: [ArchivedTab], cap: Int = hiveArchivedTabsCap) -> [ArchivedTab] {
        guard cap > 0, records.count > cap else { return records }
        return Array(records.prefix(cap))
    }
}
