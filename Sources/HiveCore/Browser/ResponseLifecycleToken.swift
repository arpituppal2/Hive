import Foundation

/// Synchronous invalidation token for visible assistant responses.
///
/// Browser context transitions use `ContextTransitionToken`; this token is a
/// separate lane for response supersession. Starting a newer request or
/// stopping generation invalidates older work even when an underlying provider
/// does not promptly observe Swift task cancellation. It stores no user data.
public final class ResponseLifecycleToken: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    public init() {}

    /// Invalidates any previous response and returns the new request ID.
    @discardableResult
    public func begin() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        return generation
    }

    /// Invalidates the current response without creating a replacement.
    @discardableResult
    public func cancel() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        return generation
    }

    public func isCurrent(_ requestID: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == requestID
    }

    public func current() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }
}
