import SwiftUI

// MARK: - HiveDesign
//
// Premium design token system for The Hive Browser.
// Informed by calm, low-chrome browsers, but intentionally uses Hive's warm
// editorial palette instead of default macOS translucency or AI-purple chrome.
//
// Principles:
//   1. Surface ladder > drop shadows (2-4% luminosity steps)
//   2. Neutral colors for 95% of pixels; accent only for focus/active/CTA
//   3. Opaque Hive surfaces for chrome; materials are reserved for system sheets
//   4. 4px grid spacing system
//   5. Unified radius scale (4/8/12/16/pill)
//   6. Typography with intentional tracking and weight

enum HiveDesign {

    // MARK: - Surface Ladder
    //
    // Each step is ~2.5% lighter than the last. No drop shadows needed
    // — depth comes from luminosity, not pseudo-3D effects.

    enum Surface {
        /// Deepest base: warm mahogany. NEVER pure #000.
        static let canvas: Color    = .hiveCanvas

        /// Cards, panels, sidebar items
        static let level1: Color    = .hiveSurface1

        /// Hovered surfaces, featured items
        static let level2: Color    = .hiveSurface2

        /// Active/pressed, selection highlights
        static let level3: Color    = .hiveSurface3

        /// 1px borders between surfaces
        static let hairline: Color  = .hiveHairline
    }

    // MARK: - Semantic Surfaces
    //
    // Chrome is intentionally opaque. Native materials are useful for system
    // sheets, but translucent toolbar/sidebar chrome makes the browser inherit
    // macOS instead of feeling like Hive and can amplify CEF compositing cost.

    enum Material {
        /// Opaque toolbar canvas
        static let toolbar: Color = Surface.canvas

        /// Opaque tab rail canvas
        static let sidebar: Color = Surface.canvas

        /// Elevated floating panels / popovers
        static let panel: Color = Surface.level1

        /// Opaque sheets and modal overlays
        static let sheet: Color = Surface.level2
    }

    // MARK: - Accent
    //
    // Warm honey #F97316. Used <5% of the time:

    //   - Active tab indicator / focus ring
    //   - Primary CTA
    //   - Selected state backgrounds (muted 6-12% opacity)
    //   - Brand mark

    enum Accent {
        static let primary: Color       = .hiveAccent
        static let muted: Color         = .hiveAccent.opacity(0.12)
        static let hover: Color         = .hiveAccent.opacity(0.18)
        static let glow: Color          = .hiveAccent.opacity(0.06)
    }

    // MARK: - Text
    //
    // Hierarchy: primary (92% white) → secondary (55%) → tertiary (35%)

    enum Text {
        static let primary: Color   = .hiveTextPrimary
        static let secondary: Color = .hiveTextSecondary
        static let tertiary: Color  = .hiveTextTertiary
    }

    // MARK: - State Colors

    enum State {
        static let success: Color = .hiveSuccess
        static let warning: Color = .hiveWarning
        static let danger: Color  = .hiveDanger
    }

    // MARK: - Spacing (4px base)
    //
    //   xxs:  4px    xs:  8px    sm: 12px    md: 16px
    //   lg:  20px    xl: 24px    xxl: 32px   section: 48px

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let section: CGFloat = 48
    }

    // MARK: - Corner Radius
    //
    //   xs: 4px (badges, chips)
    //   md: 8px (buttons, inputs, tabs, list rows)
    //   lg: 12px (cards, address bar)
    //   xl: 16px (large frames)
    //   pill: 9999px (status pills, toggle tabs)

    // Industrial scale: machined edges, no pillowy consumer curves.
    // 2px micro-radius for LEDs/badges, 4px for controls, 6px for cards,
    // 8px for large frames. Nothing on chrome exceeds 8px.
    enum Radius {
        /// 2px — badges, chips, LED indicators
        static let xs: CGFloat = 2
        /// 4px — buttons, inputs, tabs, list rows
        static let md: CGFloat = 4
        /// 6px — cards, address bar, popovers
        static let lg: CGFloat = 6
        /// 8px — large frames, sheets (chrome maximum)
        static let xl: CGFloat = 8
        static let pill: CGFloat = .infinity  // Apply via Capsule() or 9999px
    }

    // MARK: - Typography
    //
    // SF Pro system font with intentional weights and tracking.
    // Tab titles use 12px/500. Address bar uses 13px/400.
    // All negative tracking on large text for editorial density.

    enum Typography {
        // ── Font Sizes (CGFloat) ── for .system(size:) with custom weights
        /// 8px
        static let sizeXS: CGFloat = 8
        /// 10px
        static let sizeSM: CGFloat = 10
        /// 9px
        static let size2XS: CGFloat = 9
        /// 11px
        static let sizeMD: CGFloat = 11
        /// 12px
        static let sizeLG: CGFloat = 12
        /// 13px — body, address bar, menus
        static let sizeBody: CGFloat = 13
        /// 14px — panel titles
        static let sizeXL: CGFloat = 14
        /// 15px — sub-headings, large prompts
        static let sizeHeading2: CGFloat = 15
        /// 18px — dialog titles
        static let sizeHeading: CGFloat = 18

        // ── Font Presets ── for .font() when default weight is enough
        /// Tab titles: 12px medium
        static let tabTitle: Font = .system(size: sizeLG, weight: .medium, design: .default)
        /// Address bar text: 13px regular
        static let addressBar: Font = .system(size: sizeBody, weight: .regular, design: .default)
        /// Sidebar items: 12px regular
        static let sidebarItem: Font = .system(size: sizeLG, weight: .regular, design: .default)
        /// Menu items: 13px regular
        static let menuItem: Font = .system(size: sizeBody, weight: .regular, design: .default)
        /// Captions: 10px regular
        static let caption: Font = .system(size: sizeSM, weight: .regular, design: .default)
        /// Small labels: 11px regular
        static let smallLabel: Font = .system(size: sizeMD, weight: .regular, design: .default)
        /// Body text: 13px regular
        static let body: Font = .system(size: sizeBody, weight: .regular, design: .default)
        /// Section headers: 11px semibold
        static let sectionHeader: Font = .system(size: sizeMD, weight: .semibold, design: .default)
        /// Page headings: 18px semibold
        static let heading: Font = .system(size: sizeHeading, weight: .semibold, design: .default)
        /// Shortcut badges: 8px medium monospaced
        static let shortcutBadge: Font = .system(size: sizeXS, weight: .medium, design: .monospaced)
        /// Uppercase micro labels: 9px semibold — engraved front-panel silk-screen
        static let microLabel: Font = .system(size: 9, weight: .semibold, design: .default)
        /// Wide tracking for micro labels (~0.12em at 9px)
        static let microLabelTracking: CGFloat = 0.8
        /// Monospaced readouts: 11px medium — tabular counts, timestamps, specs
        static let monoReadout: Font = .system(size: 11, weight: .medium, design: .monospaced)
        /// Monospaced captions: 10px regular
        static let monoCaption: Font = .system(size: 10, weight: .regular, design: .monospaced)
        /// 14px semibold — panel titles, sheet headers
        static let panelTitle: Font = .system(size: sizeXL, weight: .semibold, design: .default)
        /// 15px regular — sub-headings, prompt labels
        static let subHeading: Font = .system(size: sizeHeading2, weight: .regular, design: .default)
        /// 9px regular — inline metadata, secondary micro-labels
        static let microLabelSecondary: Font = .system(size: size2XS, weight: .regular, design: .default)
        /// 9px bold — bold inline labels
        static let microLabelBold: Font = .system(size: size2XS, weight: .bold, design: .default)
        /// 10px medium — button captions, filter labels
        static let buttonCaption: Font = .system(size: sizeSM, weight: .medium, design: .default)
        /// 10px semibold — emphasized captions, filter headers
        static let captionSemiBold: Font = .system(size: sizeSM, weight: .semibold, design: .default)
        /// 11px bold — emphasized labels
        static let smallLabelBold: Font = .system(size: sizeMD, weight: .bold, design: .default)
        /// 13px semibold — emphasized body, menu items
        static let bodySemiBold: Font = .system(size: sizeBody, weight: .semibold, design: .default)
        /// 32px light — hero display, empty states
        static let heroDisplay: Font = .system(size: 32, weight: .light, design: .default)
        /// 9px regular monospaced — inline data, timestamps
        static let monoMicro: Font = .system(size: size2XS, weight: .regular, design: .monospaced)
        /// 9px medium monospaced — emphasized inline data
        static let monoMicroMedium: Font = .system(size: size2XS, weight: .medium, design: .monospaced)
        /// 9px semibold monospaced — emphasized inline data
        static let monoMicroEmph: Font = .system(size: size2XS, weight: .semibold, design: .monospaced)
        /// 8px medium monospaced — tiny labels
        static let monoTiny: Font = .system(size: sizeXS, weight: .medium, design: .monospaced)
        /// 12px bold — emphasized sidebar items
        static let sidebarItemBold: Font = .system(size: sizeLG, weight: .bold, design: .default)
        /// 9px medium — inline metadata
        static let microLabelMedium: Font = .system(size: size2XS, weight: .medium, design: .default)
        /// 12px medium monospaced — code labels
        static let monoMedium: Font = .system(size: sizeLG, weight: .regular, design: .monospaced)
        /// 12px medium — emphasized sidebar items
        static let sidebarItemMedium: Font = .system(size: sizeLG, weight: .medium, design: .default)
        /// 13px medium — emphasized body
        static let bodyMedium: Font = .system(size: sizeBody, weight: .medium, design: .default)
        /// 14px medium — panel titling
        static let panelTitleMedium: Font = .system(size: sizeXL, weight: .medium, design: .default)
        /// 11px medium — small labels, tooltips
        static let smallLabelMedium: Font = .system(size: sizeMD, weight: .medium, design: .default)
        /// 14px regular — large body, panel descriptions
        static let bodyLarge: Font = .system(size: sizeXL, weight: .regular, design: .default)
        /// 15px semibold — emphasized sub-headings
        static let subHeadingSemiBold: Font = .system(size: sizeHeading2, weight: .semibold, design: .default)
        /// 11px regular monospaced — code, command text
        static let monoSmall: Font = .system(size: sizeMD, weight: .regular, design: .monospaced)
        /// 12px semibold — emphasized sidebar items
        static let sidebarItemSemiBold: Font = .system(size: sizeLG, weight: .semibold, design: .default)
        /// 10px bold — emphasized captions
        static let captionBold: Font = .system(size: sizeSM, weight: .bold, design: .default)
        /// 15px bold — bold sub-headings
        static let subHeadingBold: Font = .system(size: sizeHeading2, weight: .bold, design: .default)
        /// 44px light — large hero display, welcome
        static let heroDisplayXL: Font = .system(size: 44, weight: .light, design: .default)
        /// 22px bold — feature headings
        static let headingXL: Font = .system(size: 22, weight: .bold, design: .default)
        /// 16px semibold — dialog titles
        static let dialogTitle: Font = .system(size: 16, weight: .semibold, design: .default)
        /// 8px regular — micro labels
        static let microTiny: Font = .system(size: sizeXS, weight: .regular, design: .default)
        /// 8px bold — emphasized micro labels
        static let microTinyBold: Font = .system(size: sizeXS, weight: .bold, design: .default)
        /// 16px bold — bold dialog titles
        static let dialogTitleBold: Font = .system(size: 16, weight: .bold, design: .default)
        /// 14px bold — bold panel titles
        static let panelTitleBold: Font = .system(size: sizeXL, weight: .bold, design: .default)
        /// 10px medium monospaced — emphasized mono captions
        static let monoCaptionMedium: Font = .system(size: sizeSM, weight: .medium, design: .monospaced)
        /// 10px bold monospaced — bold mono captions
        static let monoCaptionBold: Font = .system(size: sizeSM, weight: .bold, design: .monospaced)
        /// 15px medium — medium sub-headings
        static let subHeadingMedium: Font = .system(size: sizeHeading2, weight: .medium, design: .default)


    }

    // MARK: - Icon Sizes

    enum Icon {
        /// Tiny indicators, badge icons
        static let tiny: CGFloat = 8

        /// Small decorative icons
        static let small: CGFloat = 11

        /// Standard toolbar/button icons
        static let medium: CGFloat = 13

        /// Large feature icons
        static let large: CGFloat = 16

        /// Extra large, e.g. empty state illustrations
        static let xl: CGFloat = 24
    }

    // MARK: - Hit Targets
    //
    // Apple HIG: minimum 44pt for touch. For mouse-only Mac apps,
    // 24-28px is standard for toolbar buttons.

    enum HitTarget {
        /// Compact: tab close buttons, tiny controls — Chrome close btn: 16-20px
        static let compact: CGFloat = 20

        /// Standard: toolbar buttons, nav buttons — Chrome: 24-28px
        static let standard: CGFloat = 28

        /// Large: primary actions
        static let large: CGFloat = 34

        /// Apple HIG minimum for touch
        static let minimum: CGFloat = 44
    }

    // MARK: - Tab Dimensions
    //
    /// Horizontal tab pill: Chrome parity at 34px height.
    /// Vertical tab row: fits 34px in the sidebar.
    /// Radius unified at 8px (md).

    enum Tab {
        /// Horizontal tab pill height — Chrome source tree: 34px
        static let horizontalHeight: CGFloat = 34

        /// Essential/pinned tab height (horizontal) — same as tab height
        static let essentialHeight: CGFloat = 34

        /// Vertical tab row height
        static let verticalRowHeight: CGFloat = 34

        /// Vertical sidebar: default width — Arc/Zen parity: 220-240px
        static let verticalDefaultWidth: CGFloat = 240

        /// Vertical sidebar: collapsed (icons only) — Arc parity: 48px
        static let verticalCollapsedWidth: CGFloat = 48

        /// Vertical sidebar: maximum width
        static let verticalMaxWidth: CGFloat = 360

        /// Tab max width before shrinking — Chrome parity: 240px
        static let maxWidth: CGFloat = 240

        /// Unified tab corner radius — Chrome uses 8px
        static let radius: CGFloat = Radius.md  // 8px

        /// Tab-to-tab horizontal padding
        static let horizontalPadding: CGFloat = 12
    }

    // MARK: - Address Bar

    enum AddressBar {
        /// Address bar height — Chrome source tree: 34px
        static let height: CGFloat = 34

        /// Machined rectangle radius — industrial: 4px, never a pill.
        static let radius: CGFloat = Radius.md

        /// Internal horizontal padding
        static let horizontalPadding: CGFloat = Space.sm  // 12px

        /// Focus ring radius (matches the bar; crisp amber hairline, no glow)
        static let focusRingRadius: CGFloat = Radius.md
    }

    // MARK: - Animation Presets

    enum Animation {
        /// Standard spring for UI transitions (tabs, panels)
        static let spring: SwiftUI.Animation = .spring(
            response: 0.30,
            dampingFraction: 0.85
        )

        /// Quick spring for hover/press feedback
        static let springQuick: SwiftUI.Animation = .spring(
            response: 0.18,
            dampingFraction: 0.80
        )

        /// Smooth ease for opacity/scale transitions
        static let ease: SwiftUI.Animation = .easeOut(duration: 0.20)

        /// Quick ease for micro-interactions
        static let easeQuick: SwiftUI.Animation = .easeOut(duration: 0.12)
    }
}

// MARK: - View Modifiers

extension View {
    /// Standard interactive surface (e.g., card, panel row).
    func hiveSurface(radius: CGFloat = HiveDesign.Radius.md) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(HiveDesign.Surface.level1)
        )
    }

    /// Surface that responds to hover/active state with the surface ladder.
    func hiveInteractiveSurface(
        isActive: Bool = false,
        isHovered: Bool = false,
        radius: CGFloat = HiveDesign.Radius.md
    ) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    isActive ? HiveDesign.Accent.muted
                    : isHovered ? HiveDesign.Surface.level2
                    : HiveDesign.Surface.level1
                )
        )
    }

    /// Tab pill background — uses accent on active, surface ladder on hover.
    func hiveTabSurface(
        isActive: Bool = false,
        isHovered: Bool = false,
        radius: CGFloat = HiveDesign.Tab.radius
    ) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    // Flat LED-like state flip: muted amber wash, no glow.
                    isActive ? HiveDesign.Accent.muted
                    : isHovered ? HiveDesign.Surface.level2
                    : Color.clear
                )
        )
    }
}
