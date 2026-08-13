import Foundation
import Testing
@testable import HiveCore

@Suite("ReaderStyle")
struct ReaderStyleTests {

    // MARK: - Scale

    @Test func defaultStyleIsSystemThemeAtBaseSize() {
        let style = ReaderStyle()
        #expect(style.fontScale == 1.0)
        #expect(style.theme == .auto)
        #expect(style.fontSizePoints == 19)
    }

    @Test func fontScaleIsClampedToLadderRange() {
        #expect(ReaderStyle(fontScale: 0.2).fontScale == ReaderStyle.fontScaleRange.lowerBound)
        #expect(ReaderStyle(fontScale: 9.0).fontScale == ReaderStyle.fontScaleRange.upperBound)
        #expect(ReaderStyle(fontScale: 1.3).fontScale == 1.3)
    }

    @Test func fontSizePointsRoundsFromBaseTimesScale() {
        #expect(ReaderStyle(fontScale: 1.0).fontSizePoints == 19)
        #expect(ReaderStyle(fontScale: 1.3).fontSizePoints == 25)   // 24.7 → 25
        #expect(ReaderStyle(fontScale: 0.8).fontSizePoints == 15)   // 15.2 → 15
    }

    // MARK: - Palettes

    @Test func explicitThemesHaveDistinctPalettes() {
        let light = ReaderTheme.light.palette
        let sepia = ReaderTheme.sepia.palette
        let dark = ReaderTheme.dark.palette
        #expect(light != sepia)
        #expect(sepia != dark)
        #expect(light != dark)
        // Auto renders from the light defaults + media override.
        #expect(ReaderTheme.auto.palette == light)
    }

    @Test func palettesAreHexStrings() {
        for theme in ReaderTheme.allCases {
            let p = theme.palette
            for value in [p.background, p.foreground, p.link] {
                #expect(value.hasPrefix("#"))
                #expect(value.count == 7)
            }
        }
    }

    // MARK: - CSS generation

    @Test func readerCSSBakesStyleDefaultsIntoRoot() {
        let style = ReaderStyle(fontScale: 1.2, theme: .sepia)
        let css = style.readerCSS()
        #expect(css.contains("--hive-r-bg: #f6efe3"))
        #expect(css.contains("--hive-r-fg: #3a3125"))
        #expect(css.contains("--hive-r-font: 23px"))  // 19 * 1.2 = 22.8 → 23
        #expect(css.contains("var(--hive-r-font, 19px)"))
        #expect(css.contains("prefers-color-scheme") == false, "explicit themes must not ship the auto dark override")
    }

    @Test func autoThemeIncludesDarkOverride() {
        let css = ReaderStyle().readerCSS()
        #expect(css.contains("prefers-color-scheme: dark"))
        #expect(css.contains("--hive-r-bg: #1a1a1c"))
    }

    @Test func updateScriptPinsExplicitThemeAndFont() {
        let script = ReaderStyle(fontScale: 1.1, theme: .dark).cssVariableUpdateScript()
        #expect(script.contains("--hive-r-bg','#1a1a1c'"))
        #expect(script.contains("--hive-r-fg','#e4e4e8'"))
        #expect(script.contains("--hive-r-font','21px"))
        #expect(!script.contains("removeProperty"))
    }

    @Test func updateScriptClearsColorsButKeepsFontForAuto() {
        // Auto must let the media override win for colors, but keep the font
        // var applied — it is baked from the entry-time style, so clearing it
        // would silently discard in-session A−/A+ adjustments.
        let script = ReaderStyle().cssVariableUpdateScript()
        #expect(script.contains("removeProperty"))
        #expect(script.contains("--hive-r-bg"))
        #expect(!script.contains("setProperty('--hive-r-bg'"))
        #expect(script.contains("setProperty('--hive-r-font','19px')"))
    }

    @Test func autoScriptAppliesCurrentFontScale() {
        let script = ReaderStyle(fontScale: 1.3, theme: .auto).cssVariableUpdateScript()
        #expect(script.contains("setProperty('--hive-r-font','25px')"))
        #expect(!script.contains("setProperty('--hive-r-bg'"))
        #expect(!script.contains("setProperty('--hive-r-fg'"))
    }

    // MARK: - Codable

    @Test func codableRoundTrips() throws {
        let original = ReaderStyle(fontScale: 1.3, theme: .sepia)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReaderStyle.self, from: data)
        #expect(decoded == original)
        #expect(decoded.theme == .sepia)
        #expect(decoded.fontScale == 1.3)
    }

    // MARK: - Font family (Safari serif/sans parity)

    @Test func defaultFontFamilyIsSerif() {
        #expect(ReaderStyle().fontFamily == .serif)
    }

    @Test func sansCSSUsesSansStack() {
        let css = ReaderStyle(fontFamily: .sans).readerCSS()
        #expect(css.contains("Helvetica Neue"))
        #expect(css.contains("sans-serif"))
        #expect(!css.contains("Georgia"))
        #expect(css.contains("--hive-r-font-family"))
    }

    @Test func serifCSSUsesSerifStack() {
        let css = ReaderStyle().readerCSS()
        #expect(css.contains("Georgia"))
        #expect(css.contains("serif"))
    }

    @Test func updateScriptAppliesFontFamily() {
        let script = ReaderStyle(fontFamily: .sans).cssVariableUpdateScript()
        #expect(script.contains("--hive-r-font-family"))
        #expect(script.contains("Helvetica Neue"))
    }

    @Test func codableRoundTripsFontFamily() throws {
        let original = ReaderStyle(fontScale: 1.2, theme: .dark, fontFamily: .sans)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReaderStyle.self, from: data)
        #expect(decoded == original)
        #expect(decoded.fontFamily == .sans)
    }

    @Test func allThemesAreTitledAndDistinct() {
        let titles = ReaderTheme.allCases.map(\.title)
        #expect(Set(titles).count == ReaderTheme.allCases.count)
        #expect(ReaderTheme.auto.title == "Auto")
        #expect(ReaderTheme.dark.title == "Dark")
    }
}
