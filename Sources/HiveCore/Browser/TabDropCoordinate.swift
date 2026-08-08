import Foundation

/// Pure coordinate policy for tab insertion targets.
///
/// SwiftUI's `DropInfo.location` is local to the target view and may be just
/// outside its bounds during an edge drag. Clamp finite coordinates to the
/// rendered target width, choose `before` strictly before the midpoint, and
/// choose `after` at the midpoint or later. Invalid dimensions fail closed.
public enum TabDropCoordinate {
    public static func insertionEdge(
        x: CGFloat,
        targetWidth: CGFloat
    ) -> TabInsertionPlanner.Edge? {
        guard x.isFinite, targetWidth.isFinite, targetWidth > 0 else { return nil }
        let clampedX = min(max(x, 0), targetWidth)
        return clampedX < targetWidth / 2 ? .before : .after
    }
}
