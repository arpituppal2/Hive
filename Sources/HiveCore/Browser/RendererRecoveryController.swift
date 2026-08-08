import Foundation

/// A tab-scoped recovery snapshot exposed to the browser shell.
///
/// The snapshot contains only bounded failure metadata and policy state. It is
/// safe to use for a recovery banner; it never carries page text, screenshots,
/// credentials, or model context.
public struct RendererRecoverySnapshot: Sendable, Equatable {
    public let tabID: String
    public let lastEvent: RendererFailureEvent
    public let crashRecord: CrashRecord
    public let automaticRetriesUsed: Int
    public let isRecoveryVisible: Bool

    public init(
        tabID: String,
        lastEvent: RendererFailureEvent,
        crashRecord: CrashRecord,
        automaticRetriesUsed: Int,
        isRecoveryVisible: Bool
    ) {
        self.tabID = tabID
        self.lastEvent = lastEvent
        self.crashRecord = crashRecord
        self.automaticRetriesUsed = automaticRetriesUsed
        self.isRecoveryVisible = isRecoveryVisible
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tabID == rhs.tabID &&
        lhs.lastEvent == rhs.lastEvent &&
        lhs.crashRecord.count == rhs.crashRecord.count &&
        lhs.crashRecord.firstCrash == rhs.crashRecord.firstCrash &&
        lhs.crashRecord.lastCrash == rhs.crashRecord.lastCrash &&
        lhs.automaticRetriesUsed == rhs.automaticRetriesUsed &&
        lhs.isRecoveryVisible == rhs.isRecoveryVisible
    }
}

/// Coordinates renderer-failure policy independently of CEF/WKWebView.
///
/// Engine adapters call `handleFailure(_:)` when their native termination
/// callback is available. The browser shell decides whether to actually reload
/// or render a recovery surface from the returned plan. Keeping the controller
/// engine-agnostic prevents a dependency wrapper from becoming an accidental
/// security or reliability boundary.
public actor RendererRecoveryController {
    private struct Entry: Sendable {
        var event: RendererFailureEvent
        var crashRecord: CrashRecord
        var plan: RendererRecoveryPlan
        var automaticRetriesUsed: Int
        var isRecoveryVisible: Bool
    }

    private let handler: any RendererFailureHandling
    private var entries: [String: Entry] = [:]

    public init(handler: any RendererFailureHandling = DefaultRendererFailureHandler()) {
        self.handler = handler
    }

    /// Records a failure and applies the crash-loop policy for that tab.
    ///
    /// The first failure may produce one automatic retry. Subsequent failures,
    /// or a burst classified as a crash loop, produce a recovery surface. The
    /// controller never performs a reload itself, so it cannot create an
    /// infinite reload loop or act on a stale browser object.
    @discardableResult
    public func handleFailure(_ event: RendererFailureEvent) -> RendererRecoveryPlan {
        let previous = entries[event.tabID]
        // Native adapters may surface the same termination more than once while
        // the browser/client tears down. Identical events are idempotent: do
        // not turn one renderer failure into multiple policy failures.
        if let previous, previous.event == event {
            return previous.plan
        }
        let crashRecord = previous.map {
            $0.crashRecord.recorded(at: event.occurredAt)
        } ?? CrashRecord(
            count: 1,
            firstCrash: event.occurredAt,
            lastCrash: event.occurredAt
        )
        // CrashRecord starts a fresh burst after the five-minute window. The
        // retry budget belongs to that same burst; retaining it across the
        // reset would make a healthy tab lose its one automatic retry forever.
        let burstReset: Bool = {
            guard let previous else { return false }
            let elapsed = event.occurredAt.timeIntervalSince(previous.crashRecord.firstCrash)
            // Keep this boundary identical to CrashRecord.recorded(at:): an
            // out-of-order event or one at/after five minutes starts a new
            // burst and therefore receives a fresh retry budget.
            return elapsed < 0 || elapsed >= 300
        }()
        let automaticRetriesUsed = burstReset ? 0 : (previous?.automaticRetriesUsed ?? 0)
        let plan = handler.classify(
            event,
            crashRecord: crashRecord,
            automaticRetriesUsed: automaticRetriesUsed
        )

        entries[event.tabID] = Entry(
            event: event,
            crashRecord: crashRecord,
            plan: plan,
            automaticRetriesUsed: plan.shouldReloadAutomatically
                ? automaticRetriesUsed + 1
                : automaticRetriesUsed,
            isRecoveryVisible: plan.requiresRecoverySurface
        )
        return plan
    }

    /// Begins an explicit user-requested retry from the recovery surface.
    /// Returns false when no recovery is pending. The browser shell owns the
    /// actual reload/recreation and must call `markRecovered` only after it has
    /// observed a healthy renderer/load completion.
    @discardableResult
    public func beginManualRetry(for tabID: String) -> Bool {
        guard var entry = entries[tabID], entry.isRecoveryVisible else { return false }
        entry.isRecoveryVisible = false
        entries[tabID] = entry
        return true
    }

    /// Clears all failure state after the browser shell has confirmed recovery.
    /// Returns whether a delayed adapter action still belongs to the current
    /// recovery plan. A false result means the tab recovered, was removed, was
    /// navigated, or received a newer failure; the adapter must drop the stale
    /// reload.
    public func isCurrentAttempt(tabID: String, attemptID: UUID) -> Bool {
        entries[tabID]?.plan.attemptID == attemptID
    }

    /// Invalidates a delayed automatic retry when the user navigates or the
    /// adapter replaces the browser instance without reporting a new failure.
    /// The failure record remains available for diagnostics/recovery UI, but
    /// the old attempt can no longer authorize a reload.
    public func invalidateAttempt(tabID: String) {
        guard var entry = entries[tabID] else { return }
        entry.plan = RendererRecoveryPlan(
            event: entry.event,
            decision: entry.plan.decision,
            retryAfter: 0
        )
        entries[tabID] = entry
    }

    public func markRecovered(tabID: String) {
        entries.removeValue(forKey: tabID)
    }

    /// Removes state for a closed tab so a later tab with a reused identifier
    /// cannot inherit an old renderer's crash history.
    public func remove(tabID: String) {
        entries.removeValue(forKey: tabID)
    }

    public func snapshot(for tabID: String) -> RendererRecoverySnapshot? {
        guard let entry = entries[tabID] else { return nil }
        return RendererRecoverySnapshot(
            tabID: tabID,
            lastEvent: entry.event,
            crashRecord: entry.crashRecord,
            automaticRetriesUsed: entry.automaticRetriesUsed,
            isRecoveryVisible: entry.isRecoveryVisible
        )
    }

    public func recoverySnapshots() -> [RendererRecoverySnapshot] {
        entries.keys.sorted().compactMap { snapshot(for: $0) }
    }
}
