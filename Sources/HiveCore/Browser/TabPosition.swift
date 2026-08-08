import Foundation

// MARK: - TabPosition
//
// Where the tab bar lives. **Exactly two layouts exist** — the user picks one, never both
// (owner directive + Master Spec §10 "no more than two structural layouts" + SPEC §7.1
// "only ONE tab bar and ONE address bar visible at any time"). There is intentionally no
// `.bottom` case (SPEC §7 describes a Mode C, but the Master Spec rejects >2 layouts;
// bottom tabs are out of scope for this build).

public enum TabPosition: String, Sendable, Codable, CaseIterable {
    /// Horizontal tabs across the top (Chrome/Safari style). Default for switchers.
    case top
    /// Vertical tabs in a left sidebar (Arc/Zen style).
    case vertical

    /// The *other* position — used by ⌘⇧L cycle and "switch layout" affordances.
    public var toggled: TabPosition { self == .top ? .vertical : .top }

    /// Human label for settings / onboarding previews.
    public var displayName: String {
        switch self {
        case .top:      return "Top Tabs"
        case .vertical: return "Vertical Tabs"
        }
    }
}
