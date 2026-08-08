import Foundation

// MARK: - Hive Color Tokens
//
// The canonical color values for The Hive Browser. Defined in HiveCore (Foundation-only,
// no SwiftUI) so they are fully testable and usable by any target. SwiftUI Color mapping
// lives in the Hive target (`HivePalette.swift`).
//
// Source of truth: SPEC.md §2 "Color System". Anti-slop rules (SPEC §2.5):
//   - Never pure black (#000000) — the canvas is a deep, warm mahogany #1A1512.
//   - Never pure white (#FFFFFF) for dark-mode text — use candlelight cream #F0EBE2.
//   - Accent is honey gold (#D8A43D) — a single lamplight accent. No blue/purple/sparkle.

/// Semantic color tokens for Hive. The `rawValue` is the **case name** (not the hex) so
/// it stays unique even when two semantically-distinct tokens share a hex across modes —
/// e.g. dark-mode `background` and light-mode `inkLight` are both `#171716` per SPEC §2.2/§2.3.
/// That identity is correct (same physical color, different context) and is preserved here.
public enum HiveColorToken: String, Sendable, Codable, CaseIterable {

    // MARK: Dark mode (primary canvas) — SPEC §2.2
    case ink              // primary text (warm near-white)
    case graphite         // secondary text
    case paper            // primary background
    case mist             // tertiary text, subtle fills
    case accent           // warm amber — interactive elements only (Brand: #F5A623)
    case background       // window background (warm near-black)
    case surface          // card / panel backgrounds
    case surfaceElevated  // floating panels, popovers
    case swarmAccent      // Swarm-specific violet (#7B5EA7) — appears only when Swarm is active

    // MARK: Light mode — SPEC §2.3
    case inkLight         // primary text (light) — same #171716 as dark `background`
    case backgroundLight  // window background (light)
    case surfaceLight     // cards / panels (light)
    case accentLight      // amber for light mode (Brand: #FFB84D)
    case swarmAccentLight // Swarm violet for light mode (#9B7FC7)

    // MARK: Custom accent colors — SPEC §23.2
    case gold
    case ruby
    case emerald
    case sapphire
    case amethyst
    case rose
    case sky
    case coral
    case jade
    case lavender
    case sunset
    case steel
    case mint

    /// The canonical hex string including leading `#` (SPEC §2.2/§2.3).
    public var hex: String {
        switch self {
        case .ink:             return "#F0EBE2"
        case .graphite:        return "#B8B0A0"
        case .paper:           return "#2A221D"
        case .mist:            return "#4D443D"
        case .accent:          return "#FFB84D"  // Brand: Hive Amber (dark mode)
        case .background:      return "#1A1512"
        case .surface:         return "#241E19"
        case .surfaceElevated: return "#322A23"
        case .swarmAccent:     return "#9B7FC7"  // Brand: Swarm Violet (dark mode)
        case .inkLight:        return "#1A1512"
        case .backgroundLight: return "#F7F2E9"
        case .surfaceLight:    return "#FFFDF8"
        case .accentLight:     return "#9A5A00"  // Brand: Hive Amber (light mode) — deep amber, AA on warm paper
        case .swarmAccentLight:return "#7B5EA7"  // Brand: Swarm Violet (light mode)
        case .gold:            return "#D4AF37"
        case .ruby:            return "#E0115F"
        case .emerald:         return "#50C878"
        case .sapphire:        return "#0F52BA"
        case .amethyst:        return "#9966CC"
        case .rose:            return "#FF007F"
        case .sky:             return "#87CEEB"
        case .coral:           return "#FF7F50"
        case .jade:            return "#00A86B"
        case .lavender:        return "#B57EDC"
        case .sunset:          return "#F4A460"
        case .steel:           return "#4682B4"
        case .mint:            return "#98FF98"
        }
    }

    /// The hex string without the leading `#` (6 hex digits, RGB).
    public var hexDigits: String {
        hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    }

    /// RGB components as 0...1 Doubles. Returns black on malformed input (never throws).
    public var rgb: (r: Double, g: Double, b: Double) {
        var int: UInt64 = 0
        Scanner(string: hexDigits).scanHexInt64(&int)
        return (Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0)
    }

    /// True for the canonical (non-light-variant) tokens that must never be pure black/white.
    public var isDarkModeSolid: Bool {
        switch self {
        case .ink, .graphite, .paper, .mist, .accent, .background, .surface, .surfaceElevated,
             .swarmAccent,
             .gold, .ruby, .emerald, .sapphire, .amethyst, .rose, .sky, .coral, .jade, .lavender,
             .sunset, .steel, .mint:
            return true
        default:
            return false
        }
    }
}

// MARK: - Alpha-composed tokens
//
// SPEC §2.2 defines some tokens as a base color at an opacity (e.g. `border = white @ 12%`).
// These are encoded as a base + alpha rather than a single hex so the SwiftUI mapping can
// composite against any backdrop. Kept here (Foundatation-only) for symmetry.

public struct HiveAlphaToken: Sendable, Equatable {
    public let base: HiveColorToken   // the base color
    public let opacity: Double        // 0...1

    /// SPEC §2.2 — primary divider. White @ 12%.
    public static let border       = HiveAlphaToken(base: .ink, opacity: 0.12)
    /// SPEC §2.2 — subtle border variant.
    public static let borderSubtle = HiveAlphaToken(base: .ink, opacity: 0.06)
    /// SPEC §2.2 — glass material tint. White @ 6%.
    public static let glass        = HiveAlphaToken(base: .ink, opacity: 0.06)
    /// SPEC §2.2 — active/focused glass tint. Accent @ 12%.
    public static let glassTinted  = HiveAlphaToken(base: .accent, opacity: 0.12)

    /// All named alpha tokens (for completeness checks in tests).
    public static let all: [HiveAlphaToken] = [.border, .borderSubtle, .glass, .glassTinted]
}

// MARK: - Anti-slop invariants (enforced in tests)

public extension HiveColorToken {
    /// Pure black and pure white are explicitly forbidden (SPEC §2.5).
    static let forbidden = ["#000000", "#FFFFFF", "#000", "#FFF"]

    /// true iff this token's hex is neither pure black nor pure white.
    var isNotPureBlackOrWhite: Bool {
        !Self.forbidden.contains(where: { $0.uppercased() == hex.uppercased() })
    }
}
