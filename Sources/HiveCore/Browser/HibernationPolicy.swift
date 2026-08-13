import Foundation

// MARK: - HibernationPolicy
//
// The §8 trigger table, as a pure function. Given a snapshot of the live state + the set of
// tabs currently playing audio + "now", it returns the tab IDs that should hibernate NOW.
//
// Why pure + in HiveCore: the policy is the load-bearing decision ("which tabs may I hibernate
// without violating the trust contract?") and must be exhaustively testable without a WKWebView,
// a timer, or the UI. The Hive-target `HibernationController` owns the timer + the audio set +
// the WKWebView interactionState capture/restore; it asks this policy each tick what to
// hibernate, then performs it. Keeping the decision separate from the mechanism means the
// rules can never drift from the spec silently — a test fails if they do.
//
// Precedence (§8 table), highest first — a tab matched by an earlier rule is decided by it:
//   1. Pinned tab                    → NEVER   (the always-alive contract)
//   2. Active tab                    → NEVER   (frontmost stays responsive)
//   3. Tab with audio or download    → DEFER   (until activity ends; mute ≠ hibernate)
//   4. Tab inside a FOLDED group     → NOW     (fold is explicit "I don't need these now")
//   5. Unpinned bg tab, ACTIVE space → after bgActiveSpaceSec   (default 15 min)
//   6. Any other tab (inactive space)→ after inactiveSpaceSec  (default 5 min)
//
// "Background" for rule 5 means "not the active tab" — already excluded by rule 2, so rule 5
// applies to every other unpinned tab in the active space that has been quiet for the threshold.
// Tabs with no reading audio signal (the common case until audio detection is wired) are
// hibernated on schedule by rules 5/6; the `audioPlayingTabIDs` set starts empty.

public enum HibernationPolicy {

    /// Per-condition quiet windows. Tunable from Settings later (§8); defaults match the spec.
    public struct Thresholds: Sendable, Equatable {
        /// Unpinned background tab in the ACTIVE space (the one a user is looking at) hibernates
        /// after this many seconds idle. Default 15 min.
        public var bgActiveSpaceSec: TimeInterval = 900
        /// Any non-pinned, non-active tab in an INACTIVE space hibernates after this many seconds.
        /// Inactive spaces are colder — the user isn't looking at them. Default 5 min.
        public var inactiveSpaceSec: TimeInterval = 300

        public init(bgActiveSpaceSec: TimeInterval = 900, inactiveSpaceSec: TimeInterval = 300) {
            self.bgActiveSpaceSec = bgActiveSpaceSec
            self.inactiveSpaceSec = inactiveSpaceSec
        }
        public static let defaults = Thresholds()
    }

    /// Returns whether a tab must stay alive because it has live media or a non-terminal
    /// download. This shared predicate is used by both the pure policy and CEF runtime so
    /// the high-risk "do not interrupt active work" rule cannot drift between targets.
    public static func shouldDefer(tabID: String,
                                   audioPlayingTabIDs: Set<String>,
                                   activeDownloadTabIDs: Set<String>,
                                   recentlyAudibleTabIDs: Set<String> = []) -> Bool {
        // A tab that was audible within the grace window is still protected
        // (Chrome protects recently-audible tabs; Edge defers them). The set is
        // owned by the caller, which tracks the window; empty by default so the
        // shared predicate never changes behavior for existing callers.
        audioPlayingTabIDs.contains(tabID)
            || activeDownloadTabIDs.contains(tabID)
            || recentlyAudibleTabIDs.contains(tabID)
    }

    /// Returns the IDs of tabs that should hibernate at `now`, per the §8 precedence table.
    /// - Parameters:
    ///   - tabs: every open tab (the union set across spaces).
    ///   - spaces: every space (used for active-space membership + folded-group membership).
    ///   - activeTabID: the frontmost tab (rule 2 — never hibernate).
    ///   - activeSpaceID: the space whose tab list is currently visible (rules 5 vs 6).
    ///   - audioPlayingTabIDs: tabs currently producing audio (rule 3 — defer). Owned by the
    ///     controller; empty until audio detection is wired.
    ///   - activeDownloadTabIDs: tabs with a non-terminal download. Paused downloads remain
    ///     active because destroying their browser can break the transfer's resumability.
    ///   - now: the evaluation instant. Compared against each tab's `lastVisitedAt`.
    ///   - thresholds: the quiet windows (§8).
    public static func evaluate(tabs: [BrowserTab],
                                spaces: [Space],
                                activeTabID: String?,
                                activeSpaceID: String?,
                                audioPlayingTabIDs: Set<String> = [],
                                activeDownloadTabIDs: Set<String> = [],
                                now: Date,
                                thresholds: Thresholds = .defaults) -> Set<String> {
        var hibernate: Set<String> = []
        // Index folded-group membership once: tabID → true if it sits inside any folded group
        // in its owning space. A folded group is explicit rest; its tabs hibernate immediately
        // (rule 4) unless an earlier rule protects them (pinned/active — which can't be inside a
        // folded group in practice, but we check rules in order to be safe).
        var foldedMember: [String: Bool] = [:]
        for space in spaces {
            for g in space.groups where g.isFolded {
                for tid in g.tabIDs { foldedMember[tid] = true }
            }
        }
        for tab in tabs {
            // Rule 1 — pinned tabs are always-alive.
            if tab.isPinned { continue }
            // Rule 2 — the frontmost tab stays responsive.
            if tab.id == activeTabID { continue }
            // A tab with no URL has nothing to hibernate (start page / brand-new tab).
            guard tab.url != nil else { continue }
            // Rule 3 — live media or download → defer until activity ends. A paused download
            // remains live: hibernating its browser can sever the transfer before it resumes.
            if shouldDefer(tabID: tab.id,
                           audioPlayingTabIDs: audioPlayingTabIDs,
                           activeDownloadTabIDs: activeDownloadTabIDs) { continue }
            // Rule 4 — inside a folded group → hibernate now (the explicit "rest these" gesture).
            if foldedMember[tab.id] == true {
                hibernate.insert(tab.id)
                continue
            }
            // Rules 5/6 — age-based, gated by whether the tab's space is the frontmost one.
            let inActiveSpace = (tab.spaceID != nil && tab.spaceID == activeSpaceID)
            let threshold = inActiveSpace ? thresholds.bgActiveSpaceSec : thresholds.inactiveSpaceSec
            let idle = now.timeIntervalSince(tab.lastVisitedAt)
            if idle >= threshold {
                hibernate.insert(tab.id)
            }
        }
        return hibernate
    }
}
