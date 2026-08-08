import Foundation

/// Direction for moving through an already-filtered tab projection.
public enum TabFocusDirection: Sendable {
    case previous
    case next
}

/// Pure keyboard/accessibility traversal policy for browser tab chrome.
///
/// The caller supplies the projection that is actually visible in the current
/// workspace/layout. This type never discovers tabs, crosses workspaces, or
/// expands collapsed groups; those are browser-state responsibilities.
public enum TabFocusNavigator {
    /// Returns the first occurrence of each non-empty ID, preserving order.
    /// Stable IDs are expected to be unique, but normalizing here makes the
    /// navigation contract deterministic and fail-safe if a malformed
    /// projection is supplied.
    public static func normalizedIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Finds the destination ID from a visible tab projection.
    ///
    /// If there is no focused ID, traversal starts at the leading or trailing
    /// visible tab for the requested direction. When `wraps` is true, moving
    /// past either boundary wraps to the opposite end; otherwise the result is
    /// nil at the boundary. An ID not present in the projection is treated as
    /// having no current focus, rather than allowing navigation to escape the
    /// supplied projection.
    public static func destination(
        in ids: [String],
        focusedID: String?,
        direction: TabFocusDirection,
        wraps: Bool = true
    ) -> String? {
        let orderedIDs = normalizedIDs(ids)
        guard !orderedIDs.isEmpty else { return nil }

        guard let focusedID, let currentIndex = orderedIDs.firstIndex(of: focusedID) else {
            return direction == .next ? orderedIDs.first : orderedIDs.last
        }

        switch direction {
        case .next:
            if currentIndex + 1 < orderedIDs.count {
                return orderedIDs[currentIndex + 1]
            }
            return wraps ? orderedIDs.first : nil
        case .previous:
            if currentIndex > 0 {
                return orderedIDs[currentIndex - 1]
            }
            return wraps ? orderedIDs.last : nil
        }
    }
}
