import Foundation

/// Thread-safe, user-data-free generation boundary for asynchronous navigation
/// callbacks. A browser engine may finish an older load after a newer navigation
/// has started; callers must validate the attempt before applying side effects.
///
/// Attempts are intentionally ephemeral. They are not persisted, logged, or
/// included in model context. The browser shell owns the tab lifecycle and must
/// invalidate an attempt when a tab closes, hibernates, or is replaced.
public final class NavigationAttemptRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var attempts: [String: UUID] = [:]

    public init() {}

    /// Issues a new attempt for a tab and invalidates every older callback for
    /// that tab. The returned ID is the only authority for that navigation.
    @discardableResult
    public func issue(for tabID: String) -> UUID {
        let attemptID = UUID()
        lock.lock()
        attempts[tabID] = attemptID
        lock.unlock()
        return attemptID
    }

    /// Returns true only when `attemptID` is the latest attempt for `tabID`.
    public func isCurrent(tabID: String, attemptID: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return attempts[tabID] == attemptID
    }

    /// Invalidates all callbacks for a tab. Safe to call repeatedly and after
    /// the tab has already been removed from the browser shell.
    public func invalidate(tabID: String) {
        lock.lock()
        attempts.removeValue(forKey: tabID)
        lock.unlock()
    }

    /// Removes the registry entry and returns whether an attempt existed.
    @discardableResult
    public func remove(tabID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return attempts.removeValue(forKey: tabID) != nil
    }
}
