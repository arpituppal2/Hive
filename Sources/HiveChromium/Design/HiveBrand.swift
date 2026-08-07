import SwiftUI

// MARK: - HiveBrand
//
// Premium brand identity for The Hive Browser. Single accent used sparingly
// (<5% of pixels). Hive is warm, editorial, and unmistakably its own product —
// not a translucent Mac utility and not an AI-purple dashboard.
//
// Accent:  #F5A623  (Hive amber / lamplight)
// Canvas:  #1A1512  (warm mahogany — never pure #000)
//
// Rule: The accent appears ONLY on focus rings, active tab edges, primary CTAs,
// and brand marks. Surfaces stay quiet so the page remains the visual hero. Everything else is neutral.

enum HiveBrand {
    // ── Accent ────────────────────────────────────────────────
    static let accent       = Color(red: 0.96, green: 0.65, blue: 0.14)  // #F5A623
    static let accentDark   = Color(red: 0.78, green: 0.45, blue: 0.06)  // #C7740F
    static let accentMuted  = accent.opacity(0.12)
    static let accentHover  = accent.opacity(0.18)
    static let accentGlow   = accent.opacity(0.06)  // subtle background wash

    /// Deep amber for light mode — AA-compliant text contrast on warm paper
    /// (#9A5A00 on #F7F2E9 ≈ 4.9:1). Used by the adaptive `hiveAccent` in light
    /// appearance so amber foreground/icons never fall to ~1.9:1.
    static let accentLight  = Color(red: 0.60, green: 0.35, blue: 0.0)   // #9A5A00

    // ── Canvas / Surface Ladder (dark-mode-first, auto-adapts) ─
    // Dark: tinted near-blacks. Light: warm paper tones.
    static var canvas: Color {
        Color(light: Color(red: 0.97, green: 0.95, blue: 0.91),
              dark:  Color(red: 0.102, green: 0.082, blue: 0.071))
    }
    static var surface1: Color {
        Color(light: Color(red: 0.99, green: 0.98, blue: 0.95),
              dark:  Color(red: 0.141, green: 0.118, blue: 0.094))
    }
    static var surface2: Color {
        Color(light: Color(red: 0.94, green: 0.91, blue: 0.85),
              dark:  Color(red: 0.176, green: 0.145, blue: 0.116))
    }
    static var surface3: Color {
        Color(light: Color(red: 0.90, green: 0.86, blue: 0.78),
              dark:  Color(red: 0.216, green: 0.176, blue: 0.137))
    }

    // ── Hairlines (dark-mode-first) ───────────────────────────
    static var hairline: Color {
        Color(light: .black.opacity(0.08), dark: .white.opacity(0.08))
    }
    static var hairlineThick: Color {
        Color(light: .black.opacity(0.12), dark: .white.opacity(0.12))
    }

    // ── Text (dark-mode-first) ────────────────────────────────
    static var textPrimary: Color   { Color(light: .black.opacity(0.88), dark: .white.opacity(0.92)) }
    static var textSecondary: Color { Color(light: .black.opacity(0.55), dark: .white.opacity(0.55)) }
    static var textTertiary: Color  { Color(light: .black.opacity(0.35), dark: .white.opacity(0.35)) }
    static var textDisabled: Color  { Color(light: .black.opacity(0.18), dark: .white.opacity(0.18)) }

    // ── State ─────────────────────────────────────────────────
    static let success = Color(red: 0.20, green: 0.78, blue: 0.35)  // muted green
    static let warning = Color(red: 0.95, green: 0.65, blue: 0.15)  // amber
    static let danger  = Color(red: 0.90, green: 0.25, blue: 0.25)  // soft red
    static let info    = Color(red: 0.30, green: 0.55, blue: 0.95)  // soft blue

    // Global theme hook — mutating this rebuilds accent-dependent views.
    // All accesses are main-thread; nonisolated(unsafe) silences Swift 6.
    nonisolated(unsafe) static var accentHex: String = "F5A623"

    /// A darkened variant of the current accent for light-mode foreground use.
    /// Scales RGB toward 55% so accent text/icons keep AA contrast on warm paper
    /// regardless of the user-chosen accent hex.
    static func accentLightVariant() -> Color {
        guard let base = Color(hex: "#\(accentHex)") else { return accentLight }
        #if os(macOS)
        let ns = NSColor(base)
        #else
        let ns = UIColor(base)
        #endif
        guard let sRGB = ns.usingColorSpace(.sRGB) else { return accentLight }
        let factor: CGFloat = 0.55
        return Color(.sRGB,
                     red: sRGB.redComponent * factor,
                     green: sRGB.greenComponent * factor,
                     blue: sRGB.blueComponent * factor,
                     opacity: 1.0)
    }
}

// MARK: - Color Extensions

extension Color {
    // ── Brand ─────────────────────────────────────────────────
    /// Adaptive accent: the chosen accent (from `accentHex`) in dark mode, its
    /// darkened variant in light mode so accent text/icons keep AA contrast on
    /// warm paper. Never falls to the ~1.9:1 amber-on-paper of the raw brand hex.
    static var hiveAccent:    Color {
        Color(light: HiveBrand.accentLightVariant(),
              dark:  Color(hex: "#\(HiveBrand.accentHex)") ?? HiveBrand.accent)
    }
    static var hiveCanvas:    Color { HiveBrand.canvas }
    static var hiveSurface1:  Color { HiveBrand.surface1 }
    static var hiveSurface2:  Color { HiveBrand.surface2 }
    static var hiveSurface3:  Color { HiveBrand.surface3 }
    static var hiveHairline:  Color { HiveBrand.hairline }

    // ── Text ──────────────────────────────────────────────────
    static var hiveTextPrimary:   Color { HiveBrand.textPrimary }
    static var hiveTextSecondary: Color { HiveBrand.textSecondary }
    static var hiveTextTertiary:  Color { HiveBrand.textTertiary }

    // ── State ─────────────────────────────────────────────────
    static var hiveSuccess: Color { HiveBrand.success }
    static var hiveWarning: Color { HiveBrand.warning }
    static var hiveDanger:  Color { HiveBrand.danger }

    // ── Legacy aliases (used by existing views) ──────────────
    static var hiveBackground: Color { Color(NSColor.windowBackgroundColor) }
    static var hiveTabActive: Color   { HiveBrand.accentMuted }  // flat LED wash, not glow

    // ── Adaptive color by scheme ────────────────────────────
    init(light: Color, dark: Color) {
        #if os(macOS)
        self.init(NSColor(name: nil) { appearance in
            appearance.name == .darkAqua || appearance.name == .vibrantDark
                ? NSColor(dark)
                : NSColor(light)
        })
        #else
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #endif
    }

    // ── Hex Conversion ────────────────────────────────────────

    func toHex() -> String? {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        #else
        let uiColor = NSColor(self)
        #endif
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let converted = uiColor.usingColorSpace(.sRGB) ?? uiColor
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var hexNumber: UInt64 = 0
        guard Scanner(string: trimmed).scanHexInt64(&hexNumber) else { return nil }
        switch trimmed.count {
        case 3:
            let r = (hexNumber & 0xF00) >> 8
            let g = (hexNumber & 0x0F0) >> 4
            let b = hexNumber & 0x00F
            self.init(red: Double(r)/15, green: Double(g)/15, blue: Double(b)/15)
        case 6:
            let r = (hexNumber & 0xFF0000) >> 16
            let g = (hexNumber & 0x00FF00) >> 8
            let b = hexNumber & 0x0000FF
            self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
        case 8:
            let r = (hexNumber & 0xFF000000) >> 24
            let g = (hexNumber & 0x00FF0000) >> 16
            let b = (hexNumber & 0x0000FF00) >> 8
            self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
        default: return nil
        }
    }
}
