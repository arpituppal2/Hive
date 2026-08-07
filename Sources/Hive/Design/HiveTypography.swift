import SwiftUI

// MARK: - Hive Typography
//
// The canonical type scale for The Hive Browser. Source of truth: SPEC.md §3.
//
// Rules (SPEC §3.3):
//   - System fonts only — SF Pro (Text ≤19pt, Display ≥20pt), SF Mono for code/content,
//     SF Pro Rounded for brand display (Bold only). No custom fonts.
//   - Chrome text uses SF Pro Rounded (chromeTitle / chromeButton / chromeLabel).
//   - Negative tracking for body text (tighter reading rhythm).
//   - Zero/positive tracking for chrome (legibility at small sizes).
//   - Line height = font size × 1.2–1.4. Follow exact values.
//   - Never hardcode sizes — always go through HiveTypography.

public enum HiveTypography {
    public enum Role: String, Sendable {
        // Chrome (SF Pro Rounded)
        case brandTitle        // 34pt Bold Rounded — onboarding hero
        case brandSubtitle     // 15pt Semibold Rounded — onboarding/hero subtitles
        case chromeTitle       // 13pt Semibold Rounded — tab titles
        case chromeButton      // 13pt Medium Rounded — toolbar buttons
        case chromeLabel       // 11pt Medium Rounded — status labels
        case chromeTabClose     // 9pt Bold — tab close button

        // Text (SF Pro Text)
        case body              // 17pt Regular — body text
        case bodySmall         // 13pt Regular — secondary body
        case bodyMedium        // 13pt Medium — emphasized secondary body
        case caption1          // 12pt Regular — labels, badges
        case caption1Medium    // 12pt Medium — emphasized labels
        case caption2          // 11pt Regular — timestamps, meta
        case captionMedium     // 11pt Medium — emphasized meta
        case caption3          // 10pt Regular — dense labels
        case caption3Medium    // 10pt Medium — dense emphasized labels
        case caption3Semibold  // 10pt Semibold — dense section headers
        case caption3Bold      // 10pt Bold — dense strong labels
        case micro             // 9pt Regular — tiny metadata
        case microMedium       // 9pt Medium — emphasized tiny metadata
        case microBold         // 9pt Bold — strong tiny labels
        case microTiny         // 8pt Regular — badges, keycaps
        case microTinyMedium   // 8pt Medium — emphasized badges

        // Display (SF Pro Display)
        case display1          // 48pt Light — start page hero
        case display2          // 40pt Light — panel heroes
        case display3          // 32pt Thin — decorative displays
        case dialogTitle       // 16pt Medium — panel/sheet titles
        case sectionTitle      // 16pt Semibold — section headers
        case panelTitle        // 14pt Medium — panel titles
        case panelTitleRegular // 14pt Regular — panel secondary titles
        case featureTitle      // 24pt Regular — feature headings

        // Code (SF Mono)
        case monoCaption       // 11pt Regular Mono — URLs, code
    }

    /// The resolved SwiftUI Font for a given role, including weight, design, and rounded
    /// variant. Dynamic Type is honored via `.system(...)` with the base size.
    public static func font(_ role: Role) -> Font {
        switch role {
        // Chrome — SF Pro (Brand Guidelines v1.0: SF Pro Text for chrome labels)
        case .brandTitle:
            return .system(size: 34, weight: .semibold, design: .default)  // Brand: SF Pro Display 34pt Semibold
        case .brandSubtitle:
            return .system(size: 15, weight: .semibold, design: .rounded)  // Brand: SF Pro Rounded 15pt Semibold
        case .chromeTitle:
            return .system(size: 13, weight: .medium, design: .default)  // Brand: 13pt Medium, tracking +5
        case .chromeButton:
            return .system(size: 13, weight: .regular, design: .default) // Brand: 13pt Regular
        case .chromeLabel:
            return .system(size: 11, weight: .regular, design: .default) // Brand: 11pt Regular, tracking +0.5
        case .chromeTabClose:
            return .system(size: 9, weight: .bold)

        // Text — SF Pro Text (default design)
        case .body:
            return .system(size: 17, weight: .regular)
        case .bodySmall:
            return .system(size: 13, weight: .regular)
        case .bodyMedium:
            return .system(size: 13, weight: .medium)
        case .caption1:
            return .system(size: 12, weight: .regular)
        case .caption1Medium:
            return .system(size: 12, weight: .medium)
        case .caption2:
            return .system(size: 11, weight: .regular)
        case .captionMedium:
            return .system(size: 11, weight: .medium)
        case .caption3:
            return .system(size: 10, weight: .regular)
        case .caption3Medium:
            return .system(size: 10, weight: .medium)
        case .caption3Semibold:
            return .system(size: 10, weight: .semibold)
        case .caption3Bold:
            return .system(size: 10, weight: .bold)
        case .micro:
            return .system(size: 9, weight: .regular)
        case .microMedium:
            return .system(size: 9, weight: .medium)
        case .microBold:
            return .system(size: 9, weight: .bold)
        case .microTiny:
            return .system(size: 8, weight: .regular)
        case .microTinyMedium:
            return .system(size: 8, weight: .medium)

        // Display — SF Pro Display
        case .display1:
            return .system(size: 48, weight: .light, design: .default)
        case .display2:
            return .system(size: 40, weight: .light, design: .default)
        case .display3:
            return .system(size: 32, weight: .thin, design: .default)
        case .dialogTitle:
            return .system(size: 16, weight: .medium)
        case .sectionTitle:
            return .system(size: 16, weight: .semibold)
        case .panelTitle:
            return .system(size: 14, weight: .medium)
        case .panelTitleRegular:
            return .system(size: 14, weight: .regular)
        case .featureTitle:
            return .system(size: 24, weight: .regular)

        // Code — SF Mono
        case .monoCaption:
            return .system(size: 11, weight: .regular, design: .monospaced)
        }
    }

    /// The line height (pt) for a role. SPEC §3.2 line-height values.
    public static func lineHeight(_ role: Role) -> CGFloat {
        switch role {
        case .brandTitle:      return 42
        case .brandSubtitle:    return 20
        case .chromeTitle:      return 18
        case .chromeButton:     return 18
        case .chromeLabel:      return 14
        case .chromeTabClose:    return 11
        case .body:             return 22
        case .bodySmall:        return 18
        case .bodyMedium:       return 18
        case .caption1:         return 16
        case .caption1Medium:   return 16
        case .caption2:         return 14
        case .captionMedium:    return 14
        case .caption3:         return 13
        case .caption3Medium:   return 13
        case .caption3Semibold: return 13
        case .caption3Bold:     return 13
        case .micro:            return 12
        case .microMedium:      return 12
        case .microBold:        return 12
        case .microTiny:        return 11
        case .microTinyMedium:  return 11
        case .display1:         return 56
        case .display2:         return 48
        case .display3:         return 38
        case .dialogTitle:      return 20
        case .sectionTitle:     return 20
        case .panelTitle:       return 18
        case .panelTitleRegular: return 18
        case .featureTitle:     return 30
        case .monoCaption:      return 14
        }
    }

    /// The tracking (letter-spacing, pt) for a role. Negative tracking for body,
    /// zero/positive for chrome (SPEC §3.2/§3.3).
    public static func tracking(_ role: Role) -> CGFloat {
        switch role {
        case .brandTitle:      return 0.37
        case .brandSubtitle:    return 0.0
        case .chromeTitle:      return 0.0
        case .chromeButton:     return 0.0
        case .chromeLabel:      return 0.5
        case .chromeTabClose:    return 0.0
        case .body:             return -0.41
        case .bodySmall:        return -0.08
        case .bodyMedium:       return -0.08
        case .caption1:         return -0.08
        case .caption1Medium:   return -0.08
        case .caption2:         return 0.0
        case .captionMedium:    return 0.0
        case .caption3:         return 0.0
        case .caption3Medium:   return 0.0
        case .caption3Semibold: return 0.0
        case .caption3Bold:     return 0.0
        case .micro:            return 0.0
        case .microMedium:      return 0.0
        case .microBold:        return 0.0
        case .microTiny:        return 0.0
        case .microTinyMedium:  return 0.0
        case .display1:         return 0.38
        case .display2:         return 0.38
        case .display3:         return 0.38
        case .dialogTitle:      return 0.0
        case .sectionTitle:     return 0.0
        case .panelTitle:       return 0.0
        case .panelTitleRegular: return 0.0
        case .featureTitle:     return 0.0
        case .monoCaption:      return 0.0
        }
    }

    /// Apply a role's font + tracking + line spacing to Text. Returns `some View` because
    /// `.lineSpacing` is a View modifier (not a Text modifier).
    public static func styled(_ text: Text, _ role: Role) -> some View {
        text
            .font(font(role))
            .tracking(tracking(role))
            .lineSpacing(lineHeight(role) - pointSize(role))
    }

    /// The nominal point size for a role (used to derive lineSpacing).
    public static func pointSize(_ role: Role) -> CGFloat {
        switch role {
        case .brandTitle:      return 34
        case .brandSubtitle:    return 15
        case .chromeTitle:      return 13
        case .chromeButton:     return 13
        case .chromeLabel:      return 11
        case .chromeTabClose:    return 9
        case .body:             return 17
        case .bodySmall:        return 13
        case .bodyMedium:       return 13
        case .caption1:         return 12
        case .caption1Medium:   return 12
        case .caption2:         return 11
        case .captionMedium:    return 11
        case .caption3:         return 10
        case .caption3Medium:   return 10
        case .caption3Semibold: return 10
        case .caption3Bold:     return 10
        case .micro:            return 9
        case .microMedium:      return 9
        case .microBold:        return 9
        case .microTiny:        return 8
        case .microTinyMedium:  return 8
        case .display1:         return 48
        case .display2:         return 40
        case .display3:         return 32
        case .dialogTitle:      return 16
        case .sectionTitle:     return 16
        case .panelTitle:       return 14
        case .panelTitleRegular: return 14
        case .featureTitle:     return 24
        case .monoCaption:      return 11
        }
    }
}

// MARK: - View helper

public extension View {
    /// Apply a Hive typography role's font + tracking + line spacing.
    func hiveType(_ role: HiveTypography.Role) -> some View {
        font(HiveTypography.font(role))
            .tracking(HiveTypography.tracking(role))
            .lineSpacing(HiveTypography.lineHeight(role) - HiveTypography.pointSize(role))
    }
}
