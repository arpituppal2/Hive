import Foundation

/// Thread-safe global hook for canceling subresource loads before they hit
/// the network (adblock at the request layer).
///
/// CEF invokes `get_resource_request_handler` on the browser-process **IO
/// thread** before each resource load, so the predicate installed here runs
/// off the main actor. It must therefore be fast (it runs once per resource on
/// every page) and must never hop back to the main thread.
///
/// The predicate is installed once during app setup (before any browser
/// exists); reads take the lock for correctness — an uncontended NSLock is on
/// the order of tens of nanoseconds, negligible next to the network I/O it
/// gates. When the predicate returns true, the browser client hands CEF a
/// resource handler whose `on_before_resource_load` returns `RV_CANCEL`,
/// dropping the request before it is made.
public final class CefResourceFilter: @unchecked Sendable {

    /// The process-wide filter instance consulted by every browser.
    public static let shared = CefResourceFilter()

    /// An immutable policy snapshot. `shouldBlock` runs on the IO thread.
    public struct Snapshot: Sendable {
        /// Returns true when `url` should be canceled before loading.
        public let shouldBlock: @Sendable (URL) -> Bool

        public init(shouldBlock: @escaping @Sendable (URL) -> Bool) {
            self.shouldBlock = shouldBlock
        }
    }

    private let lock = NSLock()
    private var snapshot = Snapshot { _ in false }

    /// Installs the blocking predicate, replacing any prior snapshot.
    public func install(_ snapshot: Snapshot) {
        lock.lock(); defer { lock.unlock() }
        self.snapshot = snapshot
    }

    /// Returns true when `url` should be canceled. Called from the
    /// browser-process IO thread; safe to call from any thread.
    public func shouldBlock(url: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return snapshot.shouldBlock(url)
    }
}
