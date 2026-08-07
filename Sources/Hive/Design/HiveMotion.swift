import SwiftUI

// MARK: - Hive Motion System
//
// The canonical motion presets for The Hive Browser. Source of truth: SPEC.md §5.
//
// Philosophy (SPEC §5.1): motion is functional first. Every animation communicates a
// spatial relationship, state change, or feedback. Decorative animation only for
// micro-delight (< 200ms). Critically damped springs (≥ 0.78) — never bouncy.
//
// Rules (SPEC §5.5):
//   1. Entrance > exit speed (enter fast, exit deliberate).
//   2. Chrome never drops below 60fps.
//   3. Stagger = 20ms/item, max 200ms total (cap 10 items).
//   4. Tab switch = instant content swap + 200ms title fade.
//   5. Sidebar toggle = 300ms spring (expand/collapse).
//   6. Reduced motion (SPEC §5.4): all springs → linear(0.12), no scale, no stagger.

public struct HiveSpring: Sendable, Equatable {
    public let response: Double
    public let damping: Double

    public init(response: Double, damping: Double) {
        self.response = response
        self.damping = damping
    }

    /// The SwiftUI Animation, honoring reduced-motion.
    public var animation: Animation {
        reduceMotion
            ? .linear(duration: 0.12)
            : .spring(response: response, dampingFraction: damping)
    }

    // Brand Guidelines v1.0 — Motion & Animation
    // Physics, not easing curves. Spring animations throughout.
    //
    // NOTE (2026-07-29): damping was 0.72–0.75 across the chrome presets, which
    // SAT BELOW SPEC §29 anti-slop rule-9 ("No bouncy springs, damping ≥ 0.78")
    // and made chrome feel bouncy/clunky ("doesn't feel like a browser"
    // feedback). Reconciled to SPEC §5's canonical values (expand=0.78,
    // collapse≈0.88, hover micro crisp). Still springs (alive, not aggressive)
    // — no rubber-band wobble. See PITCH/browser-feel-fixes.md fix #4.
    public static let standard = HiveSpring(response: 0.40, damping: 0.82) // most UI transitions
    public static let micro     = HiveSpring(response: 0.25, damping: 0.85) // hover, focus, toggles (quick)
    public static let enter     = HiveSpring(response: 0.42, damping: 0.82) // popover/sheet entrance (deliberate)
    public static let exit      = HiveSpring(response: 0.25, damping: 0.85) // view exits (faster than enter)
    public static let expand    = HiveSpring(response: 0.45, damping: 0.80) // panel expand, sidebar
    public static let collapse  = HiveSpring(response: 0.35, damping: 0.88) // panel collapse

    public static let all: [HiveSpring] = [.standard, .micro, .enter, .exit, .expand, .collapse]
}

public struct HiveDuration: Sendable, Equatable {
    public let seconds: Double
    public let label: String  // brand name for the duration

    public init(_ seconds: Double, label: String) {
        self.seconds = seconds
        self.label = label
    }

    public var value: Animation {
        reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: seconds)
    }

    // Brand Guidelines v1.0 — Timing Tokens
    // Instant: 0.1s — micro-responses (button press)
    // Quick:   0.2s — chrome hide, tab close
    // Standard: 0.35s — chrome reveal, sheet present
    // Deliberate: 0.5s — onboarding, Swarm surface entrance
    public static let instant    = HiveDuration(0.10, label: "Instant")
    public static let quick      = HiveDuration(0.20, label: "Quick")
    public static let standard   = HiveDuration(0.35, label: "Standard")
    public static let deliberate = HiveDuration(0.50, label: "Deliberate")
}

/// True if the user has Reduce Motion enabled (SPEC §5.4).
public var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
}

// MARK: - Stagger helpers (SPEC §5.5 rule 3)

public extension Double {
    /// Stagger delay for the item at `index` in a list: 20ms/item, capped at 200ms total
    /// (so index ≥ 10 collapses to 0.2s). Returns 0 when reduced motion is on.
    static func hiveStagger(for index: Int) -> Double {
        guard !reduceMotion else { return 0 }
        return min(0.2, Double(index) * 0.02)
    }
}

// MARK: - Animation accessors (named for intent, honoring reduced motion)

public extension Animation {
    /// Most UI transitions (SPEC standard).
    static var hiveStandard: Animation { HiveSpring.standard.animation }

    /// Hover / focus / toggles (SPEC micro).
    static var hiveMicro: Animation { HiveSpring.micro.animation }

    /// Popover / sheet / panel entrance (SPEC enter). Enter ≥ exit speed.
    static var hiveEnter: Animation { HiveSpring.enter.animation }

    /// View exit (SPEC exit) — deliberate but faster than enter.
    static var hiveExit: Animation { HiveSpring.exit.animation }

    /// Panel expand / sidebar reveal / split creation (SPEC expand).
    static var hiveExpand: Animation { HiveSpring.expand.animation }

    /// Panel collapse / sidebar hide (SPEC collapse).
    static var hiveCollapse: Animation { HiveSpring.collapse.animation }

    /// Title cross-fade on tab switch (SPEC §5.5 rule 4) — 200ms, reduced-motion aware.
    static var hiveTabTitleCrossfade: Animation {
        reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: 0.20)
    }

    /// Close-button fade in on tab hover (SPEC §8.1) — 120ms.
    static var hiveCloseButtonFade: Animation {
        reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: 0.12)
    }
}
