import Foundation

/// Shared failure for work that outlives the browser context that authorized it.
public enum ContextTransitionError: Error, Equatable, Sendable {
    case staleTransition(expectedAtLeast: UInt64, received: UInt64)
}

/// Synchronous invalidation signal shared across the MainActor browser shell
/// and the actor-isolated context coordinator. The lock is intentionally tiny:
/// it stores only a monotonic generation, never user data.
public final class ContextTransitionToken: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    public init() {}

    @discardableResult
    public func advance() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        return generation
    }

    public func announce(_ value: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        if value > generation { generation = value }
    }

    public func isCurrent(_ value: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == value
    }

    public func current() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }
}
