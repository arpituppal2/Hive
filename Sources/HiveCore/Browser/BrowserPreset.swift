import Foundation

// MARK: - BrowserPreset
//
// A preset of Hive settings that mirrors the source browser's defaults, so users feel
// instantly at home when importing. When a user picks a browser to import from, Hive
// applies the matching preset automatically — layout, density, search engine, bookmark
// bar state, and content blocker — before importing any data. The user can override any
// setting afterward in Settings or during onboarding's layout step.
//
// The goal is zero-friction migration: someone coming from Arc should see vertical tabs
// by default, someone from Chrome should see compact top tabs with Google search, and
// someone from Safari should see a clean top-strip layout with standard density.

public struct BrowserPreset: Sendable, Equatable {
    /// The tab position that feels most natural for users of this browser.
    public let tabPosition: TabPosition
    /// Tab pill density matching the source browser's visual density.
    public let tabDensity: TabDensity
    /// Default search engine that matches the source browser's default.
    public let defaultSearchEngine: String
    /// Whether to show the bookmark bar (matching the source browser's default).
    public let showBookmarkBar: Bool
    /// Whether content blocking is enabled by default.
    public let contentBlockerEnabled: Bool

    public init(tabPosition: TabPosition,
                tabDensity: TabDensity,
                defaultSearchEngine: String,
                showBookmarkBar: Bool,
                contentBlockerEnabled: Bool = true) {
        self.tabPosition = tabPosition
        self.tabDensity = tabDensity
        self.defaultSearchEngine = defaultSearchEngine
        self.showBookmarkBar = showBookmarkBar
        self.contentBlockerEnabled = contentBlockerEnabled
    }

    // MARK: - Per-browser presets
    //
    // Each preset is designed to match the source browser's out-of-box defaults as closely
    // as possible. Arc users get vertical tabs (Arc's signature); Chrome/Edge users get
    // compact top tabs; Safari/Firefox/Brave users get standard top tabs.

    /// Safari: top tabs, standard density, Google search (Safari ships with Google),
    /// no bookmark bar.
    public static let safari = BrowserPreset(
        tabPosition: .top,
        tabDensity: .standard,
        defaultSearchEngine: "Google",
        showBookmarkBar: false
    )

    /// Chrome: top tabs, compact density (many tabs visible at once), Google search,
    /// bookmark bar visible (Chrome shows it by default).
    public static let chrome = BrowserPreset(
        tabPosition: .top,
        tabDensity: .compact,
        defaultSearchEngine: "Google",
        showBookmarkBar: true
    )

    /// Firefox: top tabs, standard density, Google search (Firefox ships with Google),
    /// no bookmark bar.
    public static let firefox = BrowserPreset(
        tabPosition: .top,
        tabDensity: .standard,
        defaultSearchEngine: "Google",
        showBookmarkBar: false
    )

    /// Edge: top tabs, compact density (Chromium-based, many tabs), Bing search
    /// (Edge ships with Bing, which Hive now supports), no bookmark bar.
    public static let edge = BrowserPreset(
        tabPosition: .top,
        tabDensity: .compact,
        defaultSearchEngine: "Bing",
        showBookmarkBar: false
    )

    /// Brave: top tabs, standard density, Brave Search (Brave's own engine),
    /// no bookmark bar, content blocking on (Brave users expect it).
    public static let brave = BrowserPreset(
        tabPosition: .top,
        tabDensity: .standard,
        defaultSearchEngine: "Brave Search",
        showBookmarkBar: false
    )

    /// Arc: vertical tabs (Arc's signature format), compact density,
    /// Google search (Arc ships with Google), no bookmark bar.
    public static let arc = BrowserPreset(
        tabPosition: .vertical,
        tabDensity: .compact,
        defaultSearchEngine: "Google",
        showBookmarkBar: false
    )

    /// Returns the matching preset for a given browser import id, or nil for unknown browsers.
    public static func preset(for browserID: String) -> BrowserPreset? {
        switch browserID {
        case "safari":  return .safari
        case "chrome":  return .chrome
        case "firefox": return .firefox
        case "edge":    return .edge
        case "brave":   return .brave
        case "arc":     return .arc
        default:        return nil
        }
    }

    /// Human-readable label for the preset, shown in the onboarding confirmation.
    /// e.g. "Arc-style vertical tabs" or "Chrome-style compact layout"
    public func displayLabel(for browserName: String) -> String {
        let positionLabel: String = {
            switch tabPosition {
            case .vertical: return "vertical tabs"
            case .top:      return "top tabs"
            }
        }()
        let densityLabel: String = {
            switch tabDensity {
            case .compact:  return "compact"
            case .standard: return "standard"
            case .spacious: return "spacious"
            }
        }()
        return "\(browserName)-style \(densityLabel) \(positionLabel)"
    }
}
