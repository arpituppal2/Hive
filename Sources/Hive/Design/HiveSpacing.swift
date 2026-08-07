import SwiftUI

// MARK: - Hive Spacing & Grid
//
// The canonical spacing + radii + component dimensions for The Hive Browser.
// Source of truth: SPEC.md §4. All spacing is multiples of 4pt (the 4pt base grid).

public enum HiveSpacing {
    public static let s4: CGFloat  = 4   // tight internal padding (tab close button)
    public static let s8: CGFloat  = 8   // standard internal padding
    public static let s12: CGFloat = 12  // card/section padding
    public static let s16: CGFloat = 16  // standard section gap
    public static let s24: CGFloat = 24  // sidebar section padding
    public static let s32: CGFloat = 32
    public static let s48: CGFloat = 48  // page margins
    public static let s64: CGFloat = 64  // hero spacing

    /// All spacing values, ascending — every one must be a multiple of 4.
    public static let all: [CGFloat] = [s4, s8, s12, s16, s24, s32, s48, s64]
}

// Chrome/Brave/Zen verbatim radii (2026). Chrome uses 8px unified for tabs;
// Arc/Zen use 8px for sidebar tab rows. Chrome address bar: 4px (machined).
public enum HiveRadius {
    public static let r2: CGFloat  = 2   // micro: badges, LEDs
    public static let r3: CGFloat  = 3   // shortcut badges, intent chips
    public static let r4: CGFloat  = 4   // Chrome address bar: machined 4px
    public static let r6: CGFloat  = 6   // buttons, inputs, popover inner
    public static let r8: CGFloat  = 8   // Chrome/Brave/Zen tab pills (unified)
    public static let r12: CGFloat = 12  // popovers, floating panels
    public static let r16: CGFloat = 16  // sheets, large panels
}

// MARK: - Component dimensions (SPEC §4.4)

public enum HiveDimension {
    // Tab bar — Chrome/Brave/Zen verbatim (2026). Chrome source: 34px pill height,
    // 8px unified radius, 240px max width, 2px gap. Brave vertical: 32-36px row,
    // 48/240 px collapsed/expanded. Zen (Arc-model): 34px row, 48/240 sidebar.
    public static let tabPillHCompact: CGFloat  = 28   // compact density height
    public static let tabPillHStandard: CGFloat  = 34   // Chrome verbatim: 34px
    public static let tabPillHSpacious: CGFloat = 40    // relaxed (Chrome hybrid: 40px)
    public static let tabPillMinW: CGFloat       = 60
    public static let tabPillMaxW: CGFloat       = 240  // Chrome verbatim: 240px
    public static let tabPillPinnedW: CGFloat    = 48   // favicon only (Chrome/Brave parity)
    public static let verticalTabRowH: CGFloat    = 34  // Zen/Arc verbatim: 34px row
    public static let verticalCollapsedW: CGFloat = 48  // Arc/Zen parity: 48px favicon rail
    public static let verticalExpandedW: CGFloat  = 240 // Arc verbatim: 240px
    public static let verticalMinW: CGFloat       = 48
    public static let verticalMaxW: CGFloat       = 360 // Arc max: 360px

    // Omnibar — Chrome verbatim: 34px bar, 26px input
    public static let omnibarH: CGFloat          = 34
    public static let omnibarInputH: CGFloat      = 26

    // Sidebar
    public static let sidebarMinW: CGFloat        = 200
    public static let sidebarMaxW: CGFloat        = 400
    public static let sidebarDefaultW: CGFloat   = 260

    // Hit targets
    public static let toolbarButton: CGFloat      = 26  // 26×26 hit target
    public static let closeButtonHit: CGFloat     = 16  // 16×16 close button hit
    public static let closeButtonIcon: CGFloat    = 9   // 9×9 visual icon
    public static let favicon: CGFloat            = 16  // 16×16 favicon in pill
    public static let faviconVertical: CGFloat   = 20  // 20×20 favicon in collapsed rail
    public static let faviconStartPage: CGFloat   = 32  // 32×32 on start page
    public static let suggestionIconSize: CGFloat = 20 // 20×20 icon container in omnibar suggestions

    // Scrollbar
    public static let scrollbarW: CGFloat         = 6   // 6pt (8pt on hover)

    // Drag preview (SPEC §8.1)
    public static let tabDragPreviewW: CGFloat    = 120
    public static let tabDragPreviewH: CGFloat    = 32
    public static let tabDropIndicatorW: CGFloat  = 2   // 2pt accent line
}

// MARK: - TabDensity dimensions (SPEC §8.1)
//
// The pure `TabDensity` enum (identity + persistence) lives in HiveCore so preferences
// can round-trip without SwiftUI. The concrete pt values are a Hive extension here, since
// they are render-only and need `CGFloat` (CoreGraphics via SwiftUI).

import HiveCore

public extension TabDensity {
    /// Tab pill height for this density.
    var pillHeight: CGFloat {
        switch self {
        case .compact:  return HiveDimension.tabPillHCompact
        case .standard: return HiveDimension.tabPillHStandard
        case .spacious: return HiveDimension.tabPillHSpacious
        }
    }

    /// Tab pill minimum width.
    var minWidth: CGFloat {
        switch self {
        case .compact:  return 60
        case .standard: return 72   // Chrome verbatim: tighter min
        case .spacious: return 88
        }
    }

    /// Tab pill maximum width.
    var maxWidth: CGFloat {
        switch self {
        case .compact:  return 180
        case .standard: return 240  // Chrome verbatim: 240px
        case .spacious: return 260
        }
    }

    /// Tab gap between pills.
    var gap: CGFloat {
        switch self {
        case .compact:  return 2
        case .standard: return 2    // Chrome verbatim: 2px gap
        case .spacious: return 4
        }
    }

    /// Tab pill corner radius — unified 8px (Chrome/Brave/Zen verbatim).
    var cornerRadius: CGFloat {
        HiveRadius.r8
    }
}
