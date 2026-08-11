import Foundation

/// Reader-mode color themes (Safari parity). `.auto` follows the system
/// appearance via `prefers-color-scheme`; the explicit themes pin a palette.
public enum ReaderTheme: String, Codable, CaseIterable, Identifiable, Sendable, Equatable {
    case auto
    case light
    case sepia
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .sepia: return "Sepia"
        case .dark: return "Dark"
        }
    }

    /// Hex palette applied for explicit themes (auto resolves at render time
    /// through the light defaults + the dark `prefers-color-scheme` override).
    var palette: ReaderPalette {
        switch self {
        case .auto, .light:
            return ReaderPalette(background: "#faf9f7", foreground: "#1a1a1a", link: "#2563eb")
        case .sepia:
            return ReaderPalette(background: "#f6efe3", foreground: "#3a3125", link: "#8c5a2b")
        case .dark:
            return ReaderPalette(background: "#1a1a1c", foreground: "#e4e4e8", link: "#60a5fa")
        }
    }
}

/// The concrete colors a reader theme resolves to. Hex strings without `#`
/// prefix surprises: values are emitted verbatim into CSS custom properties.
public struct ReaderPalette: Equatable, Sendable {
    public let background: String
    public let foreground: String
    public let link: String

    public init(background: String, foreground: String, link: String) {
        self.background = background
        self.foreground = foreground
        self.link = link
    }
}

/// Reader-mode appearance: font scale × theme. Pure value type so the CSS/JS
/// it generates is unit-testable from HiveCore. The reader page renders from
/// CSS custom properties (``readerCSS()``), and ``cssVariableUpdateScript()``
/// live-updates them when the user changes the size or theme mid-read.
/// Reader font family (Safari's serif/sans control). Serif is the classic
/// article look; sans is the system UI face.
public enum ReaderFontFamily: String, Codable, CaseIterable, Sendable {
    case serif
    case sans

    /// CSS `font-family` stack for the reader body.
    var cssStack: String {
        switch self {
        case .serif: return "-apple-system, \"Georgia\", \"Times New Roman\", serif"
        case .sans: return "-apple-system, \"Helvetica Neue\", \"Segoe UI\", sans-serif"
        }
    }
}

public struct ReaderStyle: Codable, Equatable, Sendable {
    /// Base body size the scale multiplies.
    public static let baseFontSize: Double = 19
    /// The scale ladder the A−/A+ controls walk.
    public static let fontScaleRange: ClosedRange<Double> = 0.8...1.4
    public static let fontScaleStep: Double = 0.1

    /// 1.0 = the default 19pt body text; values are clamped to
    /// ``fontScaleRange`` on init.
    public var fontScale: Double
    public var theme: ReaderTheme
    public var fontFamily: ReaderFontFamily

    public init(fontScale: Double = 1.0, theme: ReaderTheme = .auto, fontFamily: ReaderFontFamily = .serif) {
        self.fontScale = Self.clampFontScale(fontScale)
        self.theme = theme
        self.fontFamily = fontFamily
    }

    public static func clampFontScale(_ value: Double) -> Double {
        min(max(value, fontScaleRange.lowerBound), fontScaleRange.upperBound)
    }

    /// Rounded body point size (e.g. 19 → 25 for scale 1.3).
    public var fontSizePoints: Int {
        Int((Self.baseFontSize * fontScale).rounded())
    }

    /// The dark `prefers-color-scheme` override baked into ``readerCSS()``
    /// when the theme is `.auto`.
    static var autoDarkOverrideCSS: String {
        """
        @media (prefers-color-scheme: dark) {
          :root {
            --hive-r-bg: #1a1a1c;
            --hive-r-fg: #e4e4e8;
            --hive-r-link: #60a5fa;
          }
        }
        """
    }

    /// The full reader-mode stylesheet with this style's values as the `:root`
    /// custom-property defaults, so the first paint already matches the saved
    /// appearance (no flash before the variable script runs).
    public func readerCSS() -> String {
        let palette = theme.palette
        let darkOverride = theme == .auto ? Self.autoDarkOverrideCSS : ""
        return """
        :root {
          --hive-r-bg: \(palette.background);
          --hive-r-fg: \(palette.foreground);
          --hive-r-link: \(palette.link);
          --hive-r-font: \(fontSizePoints)px;
          --hive-r-font-family: \(fontFamily.cssStack);
        }
        \(darkOverride)
        * { background: var(--hive-r-bg, #faf9f7) !important; color: var(--hive-r-fg, #1a1a1a) !important; }
        body { max-width: 720px !important; margin: 0 auto !important; padding: 48px 24px !important; }
        p, li, blockquote, pre, code, h1, h2, h3, h4, h5, h6 {
          font-family: var(--hive-r-font-family, serif) !important;
          font-size: var(--hive-r-font, 19px) !important;
          line-height: 1.7 !important;
        }
        h1 { font-size: calc(var(--hive-r-font, 19px) * 1.68) !important; font-weight: 700 !important; margin-top: 0 !important; }
        h2 { font-size: calc(var(--hive-r-font, 19px) * 1.26) !important; font-weight: 600 !important; margin-top: 36px !important; }
        h3 { font-size: calc(var(--hive-r-font, 19px) * 1.05) !important; font-weight: 600 !important; }
        img, video, svg, canvas { max-width: 100% !important; height: auto !important; }
        a { color: var(--hive-r-link, #2563eb) !important; text-decoration: underline !important; }
        pre, code { font-family: "SF Mono", monospace !important; font-size: 14px !important; }
        """
    }

    /// JS that live-updates an open reader page's CSS custom properties to
    /// this style. For `.auto` it clears only the color variables (so the
    /// baked `prefers-color-scheme` override wins) and RE-applies the font
    /// size — the font var is baked from the entry-time style, so clearing it
    /// too would silently discard in-session A−/A+ adjustments. Explicit
    /// themes pin the full palette.
    public func cssVariableUpdateScript() -> String {
        if theme == .auto {
            return "(function(){var r=document.documentElement;"
                + "['--hive-r-bg','--hive-r-fg','--hive-r-link'].forEach(function(k){r.style.removeProperty(k);});"
                + "r.style.setProperty('--hive-r-font','\(fontSizePoints)px');"
                + "r.style.setProperty('--hive-r-font-family','\(fontFamily.cssStack)');"
                + "})();"
        }
        let palette = theme.palette
        return "(function(){var r=document.documentElement;"
            + "r.style.setProperty('--hive-r-bg','\(palette.background)');"
            + "r.style.setProperty('--hive-r-fg','\(palette.foreground)');"
            + "r.style.setProperty('--hive-r-link','\(palette.link)');"
            + "r.style.setProperty('--hive-r-font','\(fontSizePoints)px');"
            + "r.style.setProperty('--hive-r-font-family','\(fontFamily.cssStack)');"
            + "})();"
    }
}
