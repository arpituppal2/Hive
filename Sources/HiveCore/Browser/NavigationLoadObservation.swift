import Foundation

/// Best-effort state gate for polling a browser model's loading flag.
///
/// A callback consumer must not treat an already-idle model as proof that a
/// newly requested reload/back/forward navigation completed. The gate therefore
/// requires observing `isLoading == true` before accepting a later `false` as
/// completion. It deliberately does not claim to replace a native CEF
/// OnLoadStart/OnLoadEnd callback: a very short load can still occur entirely
/// between polling samples and must be handled by a future engine callback.
public struct NavigationLoadObservation: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case waitingForStart
        case loading
        case completed
    }

    public private(set) var state: State = .waitingForStart

    public init() {}

    /// Records one sampled loading value and returns true only once, on the
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
        case .completed:
            return false
        }
    }
}
