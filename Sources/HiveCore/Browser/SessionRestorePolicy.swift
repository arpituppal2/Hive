import Foundation

/// Pure decision contract for what survives and how it is restored after a
/// browser quit or crash.
///
/// The mechanics below are sourced from documented cross-browser behavior
/// (primary-source research recorded in AGENTS.md; no proprietary code):
/// - Private tabs are never restored: private browsing writes zero session
///   footprint in Chrome, Safari, Firefox, Edge, Brave, and Arc.
/// - Transient blank tabs (no committed or saved URL) are not restored:
///   Chromium session files skip empty entries, so a crashed session never
///   resurrects a strip of blank stubs.
/// - Restored order preserves the saved tab index, never MRU: session files
///   serialize by positional index in every major browser.
/// - Pinned/essential tabs and the previously active tab restore eagerly;
///   remaining durable background tabs restore lazily (cold stub) so a large
///   session never thrashes CPU/memory at launch (Chromium intelligent lazy
///   loading; Firefox `restore_on_demand`).
/// - A recovery prompt is shown only after a crash (no clean exit) when there
///   is durable content to restore.
public enum SessionRestorePolicy {
    /// One tab's relevant lifecycle facts at restore-decision time.
    public struct TabInput: Sendable, Equatable, Identifiable {
        public let id: String
        /// Private/incognito tabs are never restored, regardless of other flags.
        public let isPrivate: Bool
        /// A tab with no committed or saved URL (blank new tab). Never restored.
        public let isTransient: Bool
        public let isPinned: Bool
        public let isEssential: Bool
        /// The tab that was active before quit/crash. Restored eagerly.
        public let wasActive: Bool

        public init(
            id: String,
            isPrivate: Bool = false,
            isTransient: Bool = false,
            isPinned: Bool = false,
            isEssential: Bool = false,
            wasActive: Bool = false
        ) {
            self.id = id
            self.isPrivate = isPrivate
            self.isTransient = isTransient
            self.isPinned = isPinned
            self.isEssential = isEssential
            self.wasActive = wasActive
        }
    }

    /// The deterministic outcome of a restore decision.
    public struct RestorePlan: Sendable, Equatable {
        /// Restored immediately (pinned/essential + previously active tab),
        /// preserving saved tab index order.
        public let eagerIDs: [String]
        /// Restored on demand as cold stubs, preserving saved tab index order.
        public let lazyIDs: [String]
        /// Never restored (private or transient).
        public let excludedIDs: [String]
        /// True only after a crash (no clean exit) with durable content to
        /// restore; drives the recovery banner, never a modal decision.
        public let showRecoveryPrompt: Bool

        public var restoresNothing: Bool {
            eagerIDs.isEmpty && lazyIDs.isEmpty
        }
    }

    /// Computes the restore plan from an ordered, caller-supplied tab list.
    ///
    /// - Parameters:
    ///   - inputs: The saved tabs in saved index order.
    ///   - priorCleanExit: `true` after a clean quit, `false` after a crash,
    ///     `nil` when there is no usable prior session evidence.
    ///   - allowLazyRestore: When false every durable tab restores eagerly.
    public static func plan(
        from inputs: [TabInput],
        priorCleanExit: Bool?,
        allowLazyRestore: Bool = true
    ) -> RestorePlan {
        // Normalize: drop empty IDs and keep the first occurrence of each ID.
        var seen = Set<String>()
        let normalized = inputs.filter { !$0.id.isEmpty && seen.insert($0.id).inserted }

        // Exclusion is absolute: private is a privacy boundary, transient is
        // never worth resurrecting.
        let excludedIDs = normalized
            .filter { $0.isPrivate || $0.isTransient }
            .map(\.id)

        let durable = normalized.filter { !$0.isPrivate && !$0.isTransient }

        // First durable tab flagged as previously active wins; the rest are
        // ordinary background tabs. Ordering below always follows saved index.
        let activeID = durable.first(where: \.wasActive)?.id

        let eager = durable.filter { tab in
            tab.isPinned || tab.isEssential || tab.id == activeID
        }
        let eagerIDs = eager.map(\.id)

        let lazyIDs: [String]
        if allowLazyRestore {
            lazyIDs = durable.filter { !eagerIDs.contains($0.id) }.map(\.id)
        } else {
            lazyIDs = []
        }

        // When lazy restore is disabled, the remaining durable tabs move into
        // the eager set, still in saved index order.
        let finalEagerIDs = allowLazyRestore
            ? eagerIDs
            : durable.map(\.id)

        let showRecoveryPrompt = priorCleanExit == false && !durable.isEmpty

        return RestorePlan(
            eagerIDs: finalEagerIDs,
            lazyIDs: lazyIDs,
            excludedIDs: excludedIDs,
            showRecoveryPrompt: showRecoveryPrompt
        )
    }
}
