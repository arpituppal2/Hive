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
    // Chrome uses native macOS materials for depth and integration.
    // Arc and Safari both blur the chrome so the content takes center stage.
    // CEF compositing cost is minimal — native materials are GPU-accelerated.

    enum Material {
        /// Toolbar: native thin material over the canvas tint
        static let toolbar: Color = Surface.canvas
        static let toolbarMaterial: SwiftUI.Material = .ultraThinMaterial

        /// Tab rail: native material for depth
        static let sidebar: Color = Surface.canvas
        static let sidebarMaterial: SwiftUI.Material = .ultraThinMaterial

        /// Elevated floating panels / popovers
        static let panel: Color = Surface.level1

        /// Sheets and modal overlays
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
    //   sm: 6px (buttons, inputs, list rows)
    //   md: 8px (tabs, toolbar controls)
    //   lg: 10px (address bar, cards)
    //   xl: 12px (panels, sheets, popovers)
    //   pill: 9999px (status pills, toggle tabs)
    //
    // Modern browsers (Arc, Chrome M3, Safari) use rounded organic shapes.
    // Sharp industrial edges read as dated in 2026.
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let pill: CGFloat = .infinity
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
        /// Horizontal tab pill height — Chrome kTabHeight: 34px
        static let horizontalHeight: CGFloat = Chrome.tabHeight

        /// Essential/pinned tab height (horizontal) — same as tab height
        static let essentialHeight: CGFloat = Chrome.tabHeight

        /// Vertical tab row height — kVerticalTabHeight: 30px
        static let verticalRowHeight: CGFloat = Zen.tabHeight

        /// Vertical sidebar: default width — Arc/Zen parity: 240px
        static let verticalDefaultWidth: CGFloat = Zen.sidebarWidth

        /// Vertical sidebar: collapsed (icon rail) — Zen --zen-toolbox-max-width: 74px
        static let verticalCollapsedWidth: CGFloat = Zen.compactRail

        /// Vertical sidebar: maximum width
        static let verticalMaxWidth: CGFloat = Zen.sidebarMax

        /// Tab max width before shrinking — Chrome parity: 240px
        static let maxWidth: CGFloat = 240

        /// Unified tab corner radius — Arc 8-10px, Chrome M3 8px, Zen 8px
        static let radius: CGFloat = Radius.md

        /// Tab-to-tab horizontal padding
        static let horizontalPadding: CGFloat = 12
    }

    // MARK: - Side Panel Geometry (spec §3)
    //
    // Right-side panels: 320px wide, level1 surface, 12px radius,
    // 44px header, spring slide-in.

    enum Panel {
        /// Standard right-side panel width — spec §3: 320px
        static let width: CGFloat = 320
        /// Panel corner radius — spec §3: 12px (Radius.xl)
        static let radius: CGFloat = Radius.xl
        /// Panel header height — spec §3: 44px
        static let headerHeight: CGFloat = 44
        /// Panel internal horizontal padding — 16px (Space.md)
        static let padding: CGFloat = Space.md
    }

    // MARK: - Elevation (source: Brave Leo + Polar)
    //
    // Cards/panels use the surface ladder — NO drop shadow.
    // Elevated (menus, popovers): Brave Leo's two-layer recipe + inner top
    // highlight. Overlay (sheets): Polar's heavy shadow.

    enum Elevation {
        /// Menus, popovers, dropdowns — Brave Leo `custom-shadow` values.
        static func elevatedOn<V: View>(_ view: V) -> some View {
            view
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
                .shadow(color: .white.opacity(0.32), radius: 0.5, x: 0, y: 1)
        }

        /// Sheets, modals — Polar `--shadow-overlay`.
        static func overlayOn<V: View>(_ view: V) -> some View {
            view.shadow(color: .black.opacity(0.55), radius: 48, x: 0, y: 16)
        }
    }

    // MARK: - Chrome Mode Geometry (source: Chromium layout_constants.cc)
    //
    // Horizontal tabs. Every value is a Chromium source constant.

    enum Chrome {
        static let tabHeight: CGFloat = 34            // kTabHeight
        static let stripPadding: CGFloat = 6          // kTabStripPadding
        static let closeButton: CGFloat = 14          // kTabCloseButtonSize
        static let preTitlePadding: CGFloat = 8       // kTabPreTitlePadding
        static let postTitlePadding: CGFloat = 4      // kTabAfterTitlePadding
        static let omniboxHeight: CGFloat = 34        // kLocationBarHeight
        static let omniboxChildRadius: CGFloat = 12   // kLocationBarChildCornerRadius
        static let omniboxIconSize: CGFloat = 16      // kLocationBarIconSize
        static let omniboxSpacing: CGFloat = 4        // kLocationBarChildInternalSpacing
        static let toolbarElementPadding: CGFloat = 4 // kToolbarElementPadding
        static let toolbarIconMargin: CGFloat = 2     // kToolbarIconDefaultMargin
        static let locationBarMargin: CGFloat = 9     // kLocationBarMargin
        static let toolbarRadius: CGFloat = 8         // kToolbarCornerRadius
        static let dividerWidth: CGFloat = 2          // kToolbarDividerWidth
        static let dividerSpacing: CGFloat = 9        // kToolbarDividerSpacing
        static let hoverWhite: Double = 0.08          // Chromium hover fill
        /// M3 surface tint: ~4% of the active page's theme color (spec §3).
        static let tintAlpha: Double = 0.04
    }

    // MARK: - Zen Mode Geometry (source: Chromium vertical-tabs + Zen browser)

    enum Zen {
        static let sidebarWidth: CGFloat = 240       // existing Hive
        static let sidebarMax: CGFloat = 360         // existing Hive
        static let compactRail: CGFloat = 74         // Zen --zen-toolbox-max-width
        static let tabHeight: CGFloat = 30           // Chromium kVerticalTabHeight
        static let pinnedHeight: CGFloat = 32        // kVerticalTabPinnedHeight
        static let tabMinWidth: CGFloat = 32         // kVerticalTabMinWidth
        static let stripHPadding: CGFloat = 12       // kVerticalTabStripHorizontalPadding
        static let stripVPadding: CGFloat = 12       // kVerticalTabStripUncollapsedVerticalPadding
        static let tabRadius: CGFloat = 8            // kVerticalTabCornerRadius
        static let newTabButton: CGFloat = 32        // kVerticalTabStripNewTabButtonSize
        static let collapseButton: CGFloat = 32      // kVerticalTabStripCollapseButtonSize
        static let toolbarHeight: CGFloat = 37       // Zen --zen-toolbar-height
        static let floatGap: CGFloat = 10            // Zen --zen-compact-float
        static let floatDuration: Double = 0.25      // Zen --zen-compact-mode-time
        static let omniboxRadius: CGFloat = 50       // Zen zen-omnibox.css (pill)
        static let omniboxHeight: CGFloat = 28       // Zen zen-omnibox.css
        static let hoverWhite: Double = 0.10         // Zen --zen-toolbar-element-bg-hover
        static let activeTabScale: CGFloat = 0.985   // Zen --zen-active-tab-scale
        static let contentRadius: CGFloat = 8        // Chromium kToolbarCornerRadius
        static let canvasHex: String = "#1b1b1b"     // Zen --zen-main-browser-background
        static let essentialsTile: CGFloat = 64      // Arc-style essentials
        static let spaceRailHeight: CGFloat = 48     // Arc-style space switcher
    }

    // MARK: - Address Bar (source: Chromium layout_constants.cc)
    //
    // 34px height, 12px child radius, 16px icons, 4px internal spacing.
    // Values delegate to Chrome geometry so the omnibox and the horizontal
    // tab strip can never drift apart.

    enum AddressBar {
        /// Address bar height — kLocationBarHeight: 34px
        static let height: CGFloat = Chrome.omniboxHeight

        /// Address bar corner radius — kLocationBarChildCornerRadius: 12px
        static let radius: CGFloat = Chrome.omniboxChildRadius

        /// Internal horizontal padding — kLocationBarChildInternalSpacing: 4px
        static let horizontalPadding: CGFloat = Space.xxs

        /// Focus ring radius — matches the pill
        static let focusRingRadius: CGFloat = Chrome.omniboxChildRadius

        /// Icon size inside the omnibox — kLocationBarIconSize: 16px
        static let iconSize: CGFloat = Chrome.omniboxIconSize
    }

    // MARK: - Animation Presets
    //
    // Full spring system — from micro-interactions to page transitions.
    // Every curve is tuned for the native macOS feel: responsive, physical,
    // never floaty. The reduced-motion variants collapse to zero-duration
    // opacity fades.

    enum Animation {
        // ── Springs ──────────────────────────────────────────────

        /// Snap: no overshoot. Buttons, toggles, selection changes.
        /// response=0.22 damping=0.95 — settles in ~0.18s.
        static let snap: SwiftUI.Animation = .spring(
            response: 0.22, dampingFraction: 0.95
        )

        /// Standard spring for UI transitions (tabs, panels).
        /// response=0.30 damping=0.85 — settles in ~0.28s.
        static let spring: SwiftUI.Animation = .spring(
            response: 0.30, dampingFraction: 0.85
        )

        /// Bouncy: playful overshoot. Empty states, success checkmarks,
        /// confetti reveals. response=0.45 damping=0.65 — settles in ~0.42s.
        static let bouncy: SwiftUI.Animation = .spring(
            response: 0.45, dampingFraction: 0.65
        )

        /// Smooth: gentle deceleration. Crossfades, content swaps.
        /// response=0.35 damping=0.90 — settles in ~0.32s.
        static let smooth: SwiftUI.Animation = .spring(
            response: 0.35, dampingFraction: 0.90
        )

        /// Quick spring for hover/press feedback.
        /// response=0.18 damping=0.80 — settles in ~0.15s.
        static let springQuick: SwiftUI.Animation = .spring(
            response: 0.18, dampingFraction: 0.80
        )

        /// Entrance: deliberate rise + settle. Overlays appearing.
        /// response=0.40 damping=0.82 — settles in ~0.38s.
        static let entrance: SwiftUI.Animation = .spring(
            response: 0.40, dampingFraction: 0.82
        )

        /// Exit: swift fade-out. Overlays dismissing.
        /// response=0.22 damping=0.95 — settles in ~0.18s.
        static let exit: SwiftUI.Animation = .spring(
            response: 0.22, dampingFraction: 0.95
        )

        // ── Eases ────────────────────────────────────────────────

        /// Smooth ease for opacity/scale transitions.
        static let ease: SwiftUI.Animation = .easeOut(duration: 0.20)

        /// Quick ease for micro-interactions.
        static let easeQuick: SwiftUI.Animation = .easeOut(duration: 0.12)

        /// Deliberate ease for large content swaps.
        static let easeSlow: SwiftUI.Animation = .easeOut(duration: 0.35)

        // ── Durations (for withAnimation closures) ───────────────

        /// 80ms — hover feedback, icon swaps
        static let durInstant: Double = 0.08
        /// 120ms — button press, toggle flip
        static let durQuick: Double = 0.12
        /// 180ms — selection change, highlight shift
        static let durFast: Double = 0.18
        /// 250ms — panel open, overlay appear
        static let durStandard: Double = 0.25
        /// 350ms — page transition, workspace switch
        static let durSlow: Double = 0.35
        /// 500ms — entrance choreography, hero reveal
        static let durEntrance: Double = 0.50

        // ── Reduced-motion variants ──────────────────────────────

        /// Returns .none if reduceMotion is true, otherwise the given animation.
        static func respecting(_ reduceMotion: Bool, _ animation: SwiftUI.Animation = .easeOut(duration: 0.01)) -> SwiftUI.Animation? {
            reduceMotion ? nil : animation
        }

        /// Returns a zero-duration animation for reduced motion.
        static func reducedOr(_ reduceMotion: Bool, _ animation: SwiftUI.Animation) -> SwiftUI.Animation {
            reduceMotion ? .easeOut(duration: 0.01) : animation
        }
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

    // MARK: - Entrance Animations

    /// Slide up + fade entrance — for message bubbles, list rows, cards.
    /// Stagger is applied per-element via the index parameter.
    /// Uses a private @State wrapper to avoid the UUID()-per-render trap.
    func hiveEntrance(
        index: Int = 0,
        baseDelay: Double = 0.05,
        from offset: CGFloat = 12
    ) -> some View {
        HiveEntranceWrapper(content: self, index: index, baseDelay: baseDelay, offset: offset)
    }

    /// Scale bounce entrance — for modals, overlays, dialogs.
    func hiveScaleEntrance(reduceMotion: Bool = false) -> some View {
        self.transition(
            reduceMotion
                ? .opacity
                : .scale(scale: 0.95).combined(with: .opacity)
        )
    }

    /// Slide from trailing edge — for side panels.
    func hiveTrailingEntrance(reduceMotion: Bool = false) -> some View {
        self.transition(
            reduceMotion
                ? .opacity
                : .move(edge: .trailing).combined(with: .opacity)
        )
    }

    /// Slide from top edge — for banners, floating bars.
    func hiveTopEntrance(reduceMotion: Bool = false) -> some View {
        self.transition(
            reduceMotion
                ? .opacity
                : .move(edge: .top).combined(with: .opacity)
        )
    }

    /// Slide from bottom edge — for chips, mini-player.
    func hiveBottomEntrance(reduceMotion: Bool = false) -> some View {
        self.transition(
            reduceMotion
                ? .opacity
                : .move(edge: .bottom).combined(with: .opacity)
        )
    }

    /// Fade entrance — for content swaps.
    func hiveFadeEntrance(reduceMotion: Bool = false) -> some View {
        self.transition(.opacity)
    }
}

// MARK: - Entrance Animation Wrapper

/// Wraps content to animate its entrance with a stable appear token.
/// Avoids the `UUID()`-per-body-evaluation trap by using a @State ID
/// that's created once when the view is inserted and never changes.
private struct HiveEntranceWrapper<Content: View>: View {
    let content: Content
    let index: Int
    let baseDelay: Double
    let offset: CGFloat

    @State private var appearID = UUID()
    @State private var hasAnimated = false

    var body: some View {
        content
            .opacity(hasAnimated ? 1 : 0)
            .offset(y: hasAnimated ? 0 : offset)
            .onAppear {
                guard !hasAnimated else { return }
                withAnimation(HiveDesign.Animation.entrance.delay(baseDelay * Double(index))) {
                    hasAnimated = true
                }
            }
    }
}
