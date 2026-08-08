import Foundation

/// Pure decision contract for clearing the browser's durable history list.
///
/// The Chromium shell owns the actual mutation and autosave. This value-level
/// policy keeps the no-op and removed-count semantics testable without creating
/// a CEF-backed browser state in HiveCore tests.
public enum HistoryClearPolicy {
    public struct Decision: Sendable, Equatable {
        public let removedCount: Int

        public var shouldPersist: Bool {
            removedCount > 0
        }

        public init(removedCount: Int) {
            self.removedCount = max(0, removedCount)
        }
    }

    public static func decision(itemCount: Int) -> Decision {
        Decision(removedCount: itemCount)
    }
}
