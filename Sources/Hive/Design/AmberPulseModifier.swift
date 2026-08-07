import SwiftUI

// MARK: - AmberPulseModifier
//
// Brand Guidelines v1.0: "Page load indicator: Amber pulse on the hexagon mark, not a
// progress bar." "Hive Amber — #F5A623 — the one brand color. Used with extreme restraint.
// Appears in: the hexagon mark, active tab indicator, Swarm 'thinking' pulse."
//
// This modifier creates a gentle breathing pulse on any view — intended for the hexagon
// brand mark during page loading, but reusable for any Amber-accent pulse moment.
//
// Physics (per brand §Motion):
//   - Spring: damping 0.75, response 0.4 (the standard Hive spring)
//   - Opacity range: 0.4 → 1.0 (never fully invisible so the indicator is always present)
//   - Scale range: 0.92 → 1.0 (subtle, alive, not aggressive)
//   - The scale peaks when opacity peaks (in-phase) for a natural "breathing" feel
//
// Reduce Motion: replaces the spring animation with a simple 0.35s ease-in-out crossfade.

struct AmberPulseModifier: ViewModifier {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 1.0 : 0.4)
            .scaleEffect(isPulsing ? 1.0 : 0.92)
            .animation(
                reduceMotion
                    ? .easeInOut(duration: 0.35).repeatForever(autoreverses: true)
                    // Use easeInOut for repeatForever to avoid spring energy accumulation.
                    // Brand-inspired tempo: 0.7s full cycle = Standard (0.35s reveal) × 2.
                    : .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - View extension

extension View {
    /// Applies the Amber pulse animation — the brand-consistent page-load indicator.
    /// Replaces loading bars. Use on the hexagon brand mark during any loading/thinking state.
    func amberPulse() -> some View {
        modifier(AmberPulseModifier())
    }
}
