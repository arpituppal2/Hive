import Foundation

#if canImport(QuartzCore)
import QuartzCore

/// Shared Emil-Kowalski-style easing curves for Hive's motion design.
///
/// These mirror the timing functions called out in the design prompt. Control
/// points for `CAMediaTimingFunction` are `Float`, so the literals below are
/// `Float`-typed.
public enum HiveEasing {
    /// Decelerating curve with a strong, confident settle — the default for
    /// elements arriving on screen.
    public static let strongEaseOut = CAMediaTimingFunction(
        controlPoints: 0.23, 1.0, 0.32, 1.0
    )

    /// Symmetric ease that accelerates then decelerates hard — used for
    /// transitions that both enter and exit within a single gesture.
    public static let strongEaseInOut = CAMediaTimingFunction(
        controlPoints: 0.77, 0.0, 0.175, 1.0
    )

    /// Drawer / sheet presentation curve.
    public static let drawer = CAMediaTimingFunction(
        controlPoints: 0.32, 0.72, 0.0, 1.0
    )

    /// Sharp, crisp exit for dismissals.
    public static let crispExit = CAMediaTimingFunction(
        controlPoints: 0.4, 0.0, 1.0, 1.0
    )
}

/// Reduced-motion-aware duration constants, expressed as `CFTimeInterval`
/// seconds for direct use with `CAAnimation` / Core Animation.
public enum HiveMotionTiming {
    /// Near-instant feedback (e.g. button press tint).
    public static let microDuration: CFTimeInterval = 0.08

    /// Fast affordance changes.
    public static let fastDuration: CFTimeInterval = 0.12

    /// Standard transition duration.
    public static let standardDuration: CFTimeInterval = 0.20

    /// Larger expand / reveal transitions.
    public static let expandDuration: CFTimeInterval = 0.28
}

#endif
