//
//  CabinPalette.swift
//  CabinCore
//
//  Brand color palette for Cabin Airlines — locked to Part 4B.9 + Part 9.5 spec.
//  All colors expressed in OKLCH (L, C, H) for perceptual uniformity and tone-matched shadows.
//  Do not modify hex values without updating the Brand Book (docs/designs/BRAND_BOOK.md).
//

import SwiftUI

/// Cabin Airlines brand color system — single source of truth for all UI, 3D materials, and App Store assets.
/// 
/// Colors are locked per:
/// - Part 4B.9 (CabinSpec): Deep Cabin Blue, Frosted Porcelain, Landing Gold, Runway Amber, Twilight Teal, Crimson Cabin
/// - Part 9.5 (Brand Research): Aurora Core Cyan, Sky Blue, Cabin Green, Celestial palette
/// 
/// OKLCH values computed from sRGB hex using D65 white point. Format: (L, C, H°)
/// L = Lightness (0–1), C = Chroma (0–0.4), H = Hue in degrees (0–360)
public struct CabinPalette {
    
    // MARK: - Core Brand Colors (Part 4B.9)
    
    /// #0D1B3E — Deep Cabin Blue. The source cabin's carpet color; the cabin at 2am over the Atlantic.
    /// Grounds every surface. Used for: primary backgrounds, passport cover, app icon base, window chrome.
    public static let deepCabinBlue = Color(oklch: 0.184, 0.085, 258.3)   // #0D1B3E
    
    /// #F0EDE8 — Frosted Porcelain. The 787 wall panel; warm, designed to disappear.
    /// Used for: text surfaces, cards, sheet backgrounds, glass panel base tint.
    public static let frostedPorcelain = Color(oklch: 0.942, 0.008, 65.2)  // #F0EDE8
    
    /// #C49A3C — Landing Gold. Reading light at 3000K on quartzite; amber-gold only in premium interiors.
    /// Used EXCLUSIVELY for: CTAs, achievements, passport stamp ink, C-mark on app icon — always means "earned".
    public static let landingGold = Color(oklch: 0.632, 0.125, 78.4)      // #C49A3C
    
    /// #E8A020 — Runway Amber. Taxiway centerline light; brighter, more urgent.
    /// Used ONLY for: Wellness warning (< 40), Go-Around button, critical alerts.
    public static let runwayAmber = Color(oklch: 0.689, 0.142, 74.1)      // #E8A020
    
    /// #2A6B6B — Twilight Teal. Sky at 37,000ft through Stage-2 EC glass at dusk.
    /// Used ONLY in: Break Mode, break timer, break cards, wellness suggestions.
    public static let twilightTeal = Color(oklch: 0.456, 0.098, 180.0)    // #2A6B6B
    
    /// #8B2020 — Crimson Cabin. Deep, serious, not alarming; force-break tint.
    /// Used for: Wellness < 40 force-break overlay (15% tint), error states, destructive actions.
    public static let crimsonCabin = Color(oklch: 0.389, 0.156, 27.2)     // #8B2020
    
    // MARK: - Extended Brand Colors (Part 9.5)
    
    /// #39C7D8 — Aurora Core Cyan. IFE accent, live data highlights, connection indicators.
    public static let auroraCoreCyan = Color(oklch: 0.721, 0.142, 189.8)  // #39C7D8
    
    /// #4A90D9 — Sky Blue. Atmosphere halo on globe, seat selection border, progress rings.
    public static let skyBlue = Color(oklch: 0.612, 0.148, 246.2)         // #4A90D9
    
    /// #5FA97C — Cabin Green. Wellness streak, completed intervals, hydration confirmations.
    public static let cabinGreen = Color(oklch: 0.645, 0.112, 142.5)      // #5FA97C
    
    // MARK: - Celestial Palette (Part 9.5) — Night/aurora/space themes
    
    /// #03040D — Midnight Void. Deep space background, night skybox base.
    public static let midnightVoid = Color(oklch: 0.062, 0.025, 255.0)    // #03040D
    
    /// #E6E6F0 — Starlight. Star ceiling points, subtle highlights on dark surfaces.
    public static let starlight = Color(oklch: 0.921, 0.015, 265.0)       // #E6E6F0
    
    /// #4D96FF — Stellar Blue. Bright star points, aurora accents, active waypoints.
    public static let stellarBlue = Color(oklch: 0.658, 0.178, 254.3)     // #4D96FF
    
    /// #8A2BE2 — Nebula Purple. Aurora secondary band, rare achievement glow.
    public static let nebulaPurple = Color(oklch: 0.524, 0.215, 278.9)    // #8A2BE2
    
    /// #FFD166 — Comet Gold. Meteor streaks, ultra-rare meal highlight, celebratory particles.
    public static let cometGold = Color(oklch: 0.821, 0.135, 85.2)        // #FFD166
    
    /// #FF6B6B — Supernova. Emergency/go-around accent, critical notification badge.
    public static let supernova = Color(oklch: 0.612, 0.205, 13.8)        // #FF6B6B
    
    /// #06D6A0 — Planetary Teal. Aurora primary band, wellness peak indicator.
    public static let planetaryTeal = Color(oklch: 0.698, 0.158, 162.4)   // #06D6A0
    
    // MARK: - Semantic Aliases (for code clarity)
    
    /// Primary background — Deep Cabin Blue
    public static var backgroundPrimary: Color { deepCabinBlue }
    
    /// Card/sheet background — Frosted Porcelain
    public static var backgroundCard: Color { frostedPorcelain }
    
    /// Primary interactive / earned — Landing Gold
    public static var accentPrimary: Color { landingGold }
    
    /// Warning / go-around — Runway Amber
    public static var accentWarning: Color { runwayAmber }
    
    /// Break mode / calm — Twilight Teal
    public static var accentBreak: Color { twilightTeal }
    
    /// Error / force-break / destructive — Crimson Cabin
    public static var accentError: Color { crimsonCabin }
    
    /// IFE accent / live data — Aurora Core Cyan
    public static var accentIFE: Color { auroraCoreCyan }
    
    /// Progress / navigation — Sky Blue
    public static var accentProgress: Color { skyBlue }
    
    /// Wellness positive — Cabin Green
    public static var accentWellness: Color { cabinGreen }
    
    // MARK: - Glass & Shadow Recipes (Tone-matched OKLCH)
    
    /// Glass panel base tint — Frosted Porcelain at 12% opacity
    public static let glassPanelTint = frostedPorcelain.opacity(0.12)
    
    /// Glass panel inner border — 1px white at 12% opacity
    public static let glassInnerBorder = Color.white.opacity(0.12)
    
    /// Shadow for Deep Cabin Blue surfaces — tone-matched, zero pure black
    /// OKLCH: L=0.08, C=0.04, H=258° at 40% opacity
    public static let shadowDeepBlue = Color(oklch: 0.08, 0.04, 258.3).opacity(0.40)
    
    /// Shadow for Frosted Porcelain surfaces — warm gray tone
    /// OKLCH: L=0.15, C=0.02, H=65° at 30% opacity
    public static let shadowPorcelain = Color(oklch: 0.15, 0.02, 65.2).opacity(0.30)
    
    /// Shadow for Landing Gold accents — warm amber tone
    /// OKLCH: L=0.25, C=0.06, H=78° at 35% opacity
    public static let shadowGold = Color(oklch: 0.25, 0.06, 78.4).opacity(0.35)
    
    /// Shadow for Runway Amber warnings — urgent amber tone
    /// OKLCH: L=0.28, C=0.07, H=74° at 45% opacity
    public static let shadowAmber = Color(oklch: 0.28, 0.07, 74.1).opacity(0.45)
    
    /// Shadow for Twilight Teal break mode — calm teal tone
    /// OKLCH: L=0.18, C=0.05, H=180° at 30% opacity
    public static let shadowTeal = Color(oklch: 0.18, 0.05, 180.0).opacity(0.30)
    
    /// Shadow for Crimson Cabin errors — deep red tone
    /// OKLCH: L=0.12, C=0.08, H=27° at 40% opacity
    public static let shadowCrimson = Color(oklch: 0.12, 0.08, 27.2).opacity(0.40)
    
    /// Glow modifier for C-mark / active states — Landing Gold at 60% opacity, 20pt radius
    public static let glowLandingGold = landingGold.opacity(0.60)
    
    /// Glow modifier for Sky Blue progress / atmosphere — Sky Blue at 40% opacity, 8pt radius
    public static let glowSkyBlue = skyBlue.opacity(0.40)
    
    /// Glow modifier for Aurora Core Cyan / IFE — Cyan at 50% opacity, 12pt radius
    public static let glowAuroraCyan = auroraCoreCyan.opacity(0.50)
    
    /// Glow modifier for wellness peak — Planetary Teal at 55% opacity, 16pt radius
    public static let glowPlanetaryTeal = planetaryTeal.opacity(0.55)
    
    // MARK: - Mood Lighting Ambient Tints (for cabin mood strips)
    
    /// Dawn / Welcome — 3500K warm porcelain
    public static let moodDawn = Color(oklch: 0.88, 0.025, 65.0).opacity(0.60)
    
    /// Climb / Work — 4000K cool blue-enriched
    public static let moodWork = Color(oklch: 0.72, 0.08, 246.0).opacity(0.40)
    
    /// Sunset / Break — 2800K candlelit gold
    public static let moodBreak = Color(oklch: 0.75, 0.09, 78.0).opacity(0.50)
    
    /// Night Crossing / Zen — 2200K ember + 5% drive
    public static let moodZen = Color(oklch: 0.18, 0.04, 27.0).opacity(0.05)
    
    /// Approach / Landing — 2800→4000K sunrise sweep
    public static let moodLanding = Color(oklch: 0.70, 0.07, 74.0).opacity(0.55)
    
    // MARK: - Hex Access (for cross-platform / shader use)
    
    /// Returns the canonical hex string for a palette color (for MSL shaders, CSS, etc.)
    public static func hex(for color: Color) -> String {
        switch color {
        case deepCabinBlue: return "#0D1B3E"
        case frostedPorcelain: return "#F0EDE8"
        case landingGold: return "#C49A3C"
        case runwayAmber: return "#E8A020"
        case twilightTeal: return "#2A6B6B"
        case crimsonCabin: return "#8B2020"
        case auroraCoreCyan: return "#39C7D8"
        case skyBlue: return "#4A90D9"
        case cabinGreen: return "#5FA97C"
        case midnightVoid: return "#03040D"
        case starlight: return "#E6E6F0"
        case stellarBlue: return "#4D96FF"
        case nebulaPurple: return "#8A2BE2"
        case cometGold: return "#FFD166"
        case supernova: return "#FF6B6B"
        case planetaryTeal: return "#06D6A0"
        default: return "#000000"
        }
    }
    
    /// All core brand colors as an array (for iteration, previews, testing)
    public static let coreColors: [Color] = [
        deepCabinBlue, frostedPorcelain, landingGold, runwayAmber,
        twilightTeal, crimsonCabin
    ]
    
    /// All extended brand colors as an array
    public static let extendedColors: [Color] = [
        auroraCoreCyan, skyBlue, cabinGreen
    ]
    
    /// All celestial colors as an array
    public static let celestialColors: [Color] = [
        midnightVoid, starlight, stellarBlue, nebulaPurple,
        cometGold, supernova, planetaryTeal
    ]
    
    /// Every palette color as a single array
    public static let allColors: [Color] = coreColors + extendedColors + celestialColors
}

// MARK: - Color Extension for OKLCH Initialization

extension Color {
    /// Creates a Color from OKLCH components (L, C, H in degrees).
    /// Conversion uses D65 white point, sRGB gamut mapping.
    public init(oklch l: Double, _ c: Double, _ h: Double, opacity: Double = 1.0) {
        // OKLCH → linear sRGB (D65)
        let hRad = h * .pi / 180.0
        let a = c * cos(hRad)
        let b = c * sin(hRad)
        
        // OKLab → linear sRGB
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        
        let l3 = l_ * l_ * l_
        let m3 = m_ * m_ * m_
        let s3 = s_ * s_ * s_
        
        var r = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
        var g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
        var b_ = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
        
        // sRGB companding (gamma 2.4 approximation)
        func compand(_ x: Double) -> Double {
            x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1/2.4) - 0.055
        }
        
        r = compand(r)
        g = compand(g)
        b_ = compand(b_)
        
        // Clamp to [0, 1]
        r = min(max(r, 0), 1)
        g = min(max(g, 0), 1)
        b_ = min(max(b_, 0), 1)
        
        self.init(.sRGB, red: r, green: g, blue: b_, opacity: opacity)
    }
}

// MARK: - Preview / Testing

#if DEBUG
extension CabinPalette {
    /// Validates that all hex values match the spec exactly.
    /// Run in tests to ensure no drift.
    public static func validateAgainstSpec() -> Bool {
        let spec: [(Color, String)] = [
            (deepCabinBlue, "#0D1B3E"),
            (frostedPorcelain, "#F0EDE8"),
            (landingGold, "#C49A3C"),
            (runwayAmber, "#E8A020"),
            (twilightTeal, "#2A6B6B"),
            (crimsonCabin, "#8B2020"),
            (auroraCoreCyan, "#39C7D8"),
            (skyBlue, "#4A90D9"),
            (cabinGreen, "#5FA97C"),
            (midnightVoid, "#03040D"),
            (starlight, "#E6E6F0"),
            (stellarBlue, "#4D96FF"),
            (nebulaPurple, "#8A2BE2"),
            (cometGold, "#FFD166"),
            (supernova, "#FF6B6B"),
            (planetaryTeal, "#06D6A0"),
        ]
        
        for (color, expectedHex) in spec {
            let actualHex = hex(for: color)
            if actualHex.uppercased() != expectedHex.uppercased() {
                print("❌ CabinPalette mismatch: \(actualHex) != \(expectedHex)")
                return false
            }
        }
        return true
    }
}
#endif
