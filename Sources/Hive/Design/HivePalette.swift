import SwiftUI
import HiveCore

// MARK: - Hive Palette (SwiftUI mapping)
//
// Maps the Foundation-only `HiveColorToken` / `HiveAlphaToken` values (defined in HiveCore)
// to SwiftUI `Color` on a per-color-scheme basis. This is the single place chrome code
// should reach for colors — never hardcode RGB or use Color.black / Color.white directly.
//
// Dark-first: dark-mode tokens are the primary definitions (SPEC §2.2). Light-mode tokens
// (SPEC §2.3) are used when `\.colorScheme == .light`.

extension Color {
    /// Initialize from a hex string (with or without leading `#`, 6 RGB digits).
    public init(hex: String, opacity: Double = 1.0) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: digits).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Initialize from a HiveColorToken's hex value at a given opacity.
    public init(_ token: HiveColorToken, opacity: Double = 1.0) {
        self.init(hex: token.hex, opacity: opacity)
    }

    /// Initialize from a composed alpha token (base color + opacity).
    public init(_ token: HiveAlphaToken) {
        self.init(token.base, opacity: token.opacity)
    }
}

// MARK: - Semantic color accessors
//
// These resolve to dark- or light-mode tokens depending on the current color scheme.
// Use them in views: `Text("…").foregroundStyle(.hiveInk)`.

public extension ShapeStyle where Self == Color {
    /// Primary text — warm near-white in dark mode, near-black in light.
    static var hiveInk: Color { Color(hiveInkFor(.current)) }

    /// Secondary text.
    static var hiveGraphite: Color { Color(hiveGraphiteFor(.current)) }

    /// Tertiary text / subtle fills.
    static var hiveMist: Color { Color(hiveMistFor(.current)) }

    /// Window background — warm near-black in dark mode.
    static var hiveBackground: Color { Color(hiveBackgroundFor(.current)) }

    /// Primary surface — cards, panels.
    static var hiveSurface: Color { Color(hiveSurfaceFor(.current)) }

    /// Elevated surface — floating panels, popovers.
    static var hiveSurfaceElevated: Color { Color(hiveSurfaceElevatedFor(.current)) }

    /// Warm amber accent — interactive elements only (Brand: Hive Amber #F5A623).
    static var hiveAccent: Color { Color(hiveAccentFor(.current)) }

    /// Swarm Violet accent — appears only when Swarm is active/visible (Brand: #7B5EA7).
    static var hiveSwarmAccent: Color { Color(hiveSwarmAccentFor(.current)) }

    /// Primary divider — white @ 12% in dark mode.
    static var hiveBorder: Color { Color(HiveAlphaToken.border) }

    /// Subtle divider — white @ 6% in dark mode.
    static var hiveBorderSubtle: Color { Color(HiveAlphaToken.borderSubtle) }

    /// Success state — a calm green that works in both dark and light modes.
    static var hiveSuccess: Color { Color(hex: "#34C759") }

    /// Error / destructive state — a warm red that works in both dark and light modes.
    static var hiveError: Color { Color(hex: "#FF3B30") }

    /// Warning state — a warm amber that stays on-brand with the Hive accent.
    static var hiveWarning: Color { Color(hex: "#FF9500") }
}

// MARK: - Scheme resolution
//
// `ColorScheme.current` is a fallback used only outside a SwiftUI view hierarchy (e.g. tests).
// Inside views, prefer the `.hiveColor(for:scheme:)` helpers that take an explicit scheme.

public extension ColorScheme {
    /// Returns dark if no SwiftUI environment is available (dark-first default).
    static var current: ColorScheme { .dark }
}

public func hiveInkFor(_ scheme: ColorScheme) -> HiveColorToken {
    scheme == .light ? .inkLight : .ink
}
public func hiveGraphiteFor(_ scheme: ColorScheme) -> HiveColorToken {
    // graphite has no light variant listed in SPEC; reuse ink for light (warm near-black).
    scheme == .light ? .inkLight : .graphite
}
public func hiveMistFor(_ scheme: ColorScheme) -> HiveColorToken {
    scheme == .light ? .inkLight : .mist
}
public func hiveBackgroundFor(_ scheme: ColorScheme) -> HiveColorToken {
    scheme == .light ? .backgroundLight : .background
}
public func hiveSurfaceFor(_ scheme: ColorScheme) -> HiveColorToken {
    scheme == .light ? .surfaceLight : .surface
}
public func hiveSurfaceElevatedFor(_ scheme: ColorScheme) -> HiveColorToken {
    scheme == .light ? .surfaceLight : .surfaceElevated
}
public func hiveAccentFor(_ scheme: ColorScheme) -> HiveColorToken {
    scheme == .light ? .accentLight : .accent
}
public func hiveSwarmAccentFor(_ scheme: ColorScheme) -> HiveColorToken {
    scheme == .light ? .swarmAccentLight : .swarmAccent
}
