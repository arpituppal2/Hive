import Foundation

/// Clean Tabs — pure planner for one-click tab cleanup (Arc/Boost parity).
///
/// Analyzes a tab snapshot for (a) duplicate tabs — multiple tabs resolving
/// to the same normalized URL — and (b) stale tabs — real pages not touched
/// for a configurable number of days. Pinned and essential tabs are never
/// candidates for closure and are always preferred as a duplicate group's
/// keeper. Internal chrome (`hive://`), `about:` pages, and non-http(s)/file
/// URLs are UI, not content: they never enter either list. Pure and
/// deterministic so the contract is testable from HiveCore without CEF.
public enum TabCleanupPlanner: Sendable {

    public struct TabInput: Sendable, Equatable {
        public let id: String
        public let url: URL?
        public let title: String
        public let lastAccessed: Date
        public let isPinned: Bool
        public let isEssential: Bool
        public let isPrivate: Bool
        /// Surfaces renderer-lifetime state to the UI (the sheet labels cold
        /// tabs "sleeping"); it does not change planner eligibility — stale
        /// detection already keys off `lastAccessed`.
        public let isHibernated: Bool

        public init(
            id: String,
            url: URL?,
            title: String,
            lastAccessed: Date,
            isPinned: Bool,
            isEssential: Bool,
            isPrivate: Bool,
            isHibernated: Bool = false
        ) {
            self.id = id
            self.url = url
            self.title = title
            self.lastAccessed = lastAccessed
            self.isPinned = isPinned
            self.isEssential = isEssential
            self.isPrivate = isPrivate
            self.isHibernated = isHibernated
        }
    }

    /// One set of duplicate tabs: keep `keepID`, close every `closeID`.
    public struct DuplicateGroup: Sendable, Equatable {
        /// The normalized URL shared by every member.
        public let url: String
        public let keepID: String
        /// Oldest first — the UI shows them in the order they will close.
        public let closeIDs: [String]

        public init(url: String, keepID: String, closeIDs: [String]) {
            self.url = url
            self.keepID = keepID
            self.closeIDs = closeIDs
        }
    }

    public struct StaleTab: Sendable, Equatable {
        public let id: String
        public let lastAccessed: Date

        public init(id: String, lastAccessed: Date) {
            self.id = id
            self.lastAccessed = lastAccessed
        }
    }

    public struct Plan: Sendable, Equatable {
        public let duplicateGroups: [DuplicateGroup]
        public let staleTabs: [StaleTab]

        /// Every suggested close ID, de-duplicated across both lists and in
        /// stable order. A stale keeper is never double-counted.
        public var closeIDs: [String] {
            var seen = Set<String>()
            var ids: [String] = []
            for group in duplicateGroups {
                for id in group.closeIDs where !seen.contains(id) {
                    seen.insert(id)
                    ids.append(id)
                }
            }
            for stale in staleTabs where !seen.contains(stale.id) {
                seen.insert(stale.id)
                ids.append(stale.id)
            }
            return ids
        }

        public var isEmpty: Bool { duplicateGroups.isEmpty && staleTabs.isEmpty }

        public init(duplicateGroups: [DuplicateGroup], staleTabs: [StaleTab]) {
            self.duplicateGroups = duplicateGroups
            self.staleTabs = staleTabs
        }
    }

    /// Canonical key for duplicate grouping. Only http/https/file schemes
    /// qualify (internal chrome and about: pages are never content tabs);
    /// fragments are dropped, host casing and a trailing slash are
    /// normalized so `https://EXAMPLE.com/path#x` == `https://example.com/path`.
    public static func normalizedURLKey(_ url: URL?) -> String? {
        guard let url, let scheme = url.scheme?.lowercased() else { return nil }
        switch scheme {
        case "http", "https", "file": break
        default: return nil
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        // Well-known default ports are the same resource: a link clicked from
        // an email often carries :443 while the typed URL omits it.
        if let port = components?.port {
            let isDefaultPort = (scheme == "http" && port == 80) || (scheme == "https" && port == 443)
            if isDefaultPort { components?.port = nil }
        }
        var key = components?.string?.lowercased() ?? url.absoluteString.lowercased()
        let schemePrefixLength = scheme.count + 3 // "scheme://"
        while key.hasSuffix("/") && key.count > schemePrefixLength {
            key.removeLast()
        }
        return key
    }

    /// Groups duplicates across ALL tabs globally, not per-workspace — the
    /// Chrome "close duplicate tabs" contract. A page intentionally open in
    /// two workspaces is still surfaced so the user can decide; the sheet
    /// never closes anything without explicit per-tab selection.
    public static func plan(
        tabs: [TabInput],
        now: Date = Date(),
        staleAfterDays: Int = 30
    ) -> Plan {
        // Duplicates: group by normalized URL, keep pinned/essential (most
        // recent among keepers), close everything else.
        var groups: [String: [TabInput]] = [:]
        for tab in tabs where !tab.isPrivate {
            guard let key = normalizedURLKey(tab.url) else { continue }
            groups[key, default: []].append(tab)
        }

        var duplicateGroups: [DuplicateGroup] = []
        var closeIDs = Set<String>()
        for (key, members) in groups where members.count >= 2 {
            let keepers = members.filter { $0.isPinned || $0.isEssential }
            let keep: TabInput
            if keepers.isEmpty {
                keep = members.max { $0.lastAccessed < $1.lastAccessed }!
            } else {
                keep = keepers.max { $0.lastAccessed < $1.lastAccessed }!
            }
            // Pinned/essential tabs are never closed, even inside a duplicate
            // group — so an all-pinned duplicate group suggests nothing.
            let closers = members
                .filter { !$0.isPinned && !$0.isEssential }
                .filter { $0.id != keep.id }
                .sorted { $0.lastAccessed < $1.lastAccessed }
            guard !closers.isEmpty else { continue }
            duplicateGroups.append(DuplicateGroup(
                url: key,
                keepID: keep.id,
                closeIDs: closers.map(\.id)
            ))
            closeIDs.formUnion(closers.map(\.id))
        }

        // Stale: real content tabs untouched for the window, never pinned or
        // essential, and not already counted as a duplicate to close.
        let cutoff = now.addingTimeInterval(-TimeInterval(staleAfterDays) * 86_400)
        let stale = tabs
            .filter { !$0.isPrivate && !$0.isPinned && !$0.isEssential }
            .filter { normalizedURLKey($0.url) != nil }
            .filter { $0.lastAccessed < cutoff }
            .filter { !closeIDs.contains($0.id) }
            .sorted { $0.lastAccessed < $1.lastAccessed }
            .map { StaleTab(id: $0.id, lastAccessed: $0.lastAccessed) }

        return Plan(duplicateGroups: duplicateGroups, staleTabs: stale)
    }
}
