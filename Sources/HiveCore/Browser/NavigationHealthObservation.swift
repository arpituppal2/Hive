import Foundation

/// Best-effort state gate for deciding whether a navigation has stalled.
///
/// This value does not identify renderer crashes. It only records the polling
/// boundary available to the browser shell: a navigation may be observed as
/// loading, completed, or still unfinished when the watchdog window expires.
public struct NavigationHealthObservation: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case waitingForStart
        case loading
        case completed
        case timedOut
    }

    public private(set) var state: State = .waitingForStart

    public init() {}

    /// Records a sampled loading value and returns true only once, on the
    /// observed loading-to-idle transition for this navigation attempt.
    @discardableResult
    public mutating func observe(isLoading: Bool) -> Bool {
        switch state {
        case .waitingForStart:
            if isLoading {
                state = .loading
            }
            return false
        case .loading:
            guard !isLoading else { return false }
            state = .completed
            return true
        case .completed, .timedOut:
            return false
        }
    }

    /// Marks an observed loading navigation as timed out. A navigation that
    /// never sampled as loading may have completed between polling samples, so
    /// it fails closed without emitting a false stall notice.
    @discardableResult
    public mutating func timeOut() -> Bool {
        guard state == .loading else { return false }
        state = .timedOut
        return true
    }
}
