import Foundation
import Testing
@testable import HiveCore

@Suite("BrowserChromePreferences")
struct BrowserChromePreferencesTests {
    @Test func defaultsUseVerticalLayoutAndHiddenBookmarkBar() {
        let preferences = BrowserChromePreferences()
        #expect(preferences.layout == "Vertical")
        #expect(preferences.showBookmarksBar == false)
        #expect(preferences.isCompactMode == false)
        #expect(preferences.isMemorySaverEnabled)
        #expect(preferences.openBriefOnNewTab, "Approved taste decision: the Morning Brief is the default new-tab destination.")
        #expect(preferences.normalized == preferences)
    }

    @Test func validValuesRoundTripThroughCodable() throws {
        let original = BrowserChromePreferences(
            layout: "Horizontal",
            showBookmarksBar: true,
            isCompactMode: true,
            isMemorySaverEnabled: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserChromePreferences.self, from: data)
        #expect(decoded == original)
    }

    @Test func unknownLayoutNormalizesToSafeDefault() {
        let preferences = BrowserChromePreferences(layout: "Diagonal", showBookmarksBar: true, isCompactMode: true)
        #expect(preferences.normalized.layout == "Vertical")
        #expect(preferences.normalized.showBookmarksBar)
        #expect(preferences.normalized.isCompactMode)
        #expect(preferences.normalized.isMemorySaverEnabled)
    }

    @Test func missingLegacyKeysUseSafeDefaults() throws {
        let data = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(BrowserChromePreferences.self, from: data)
        #expect(decoded == BrowserChromePreferences())
        #expect(decoded.isMemorySaverEnabled)
        #expect(decoded.openBriefOnNewTab)
    }

    @Test func newTabDefaultCanRoundTripAsFalse() throws {
        let original = BrowserChromePreferences(openBriefOnNewTab: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserChromePreferences.self, from: data)
        #expect(decoded.openBriefOnNewTab == false)
        #expect(decoded.normalized.openBriefOnNewTab == false)
    }

@Test func memorySaverDisabledRoundTrips() throws {
        let original = BrowserChromePreferences(isMemorySaverEnabled: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserChromePreferences.self, from: data)
        #expect(decoded.isMemorySaverEnabled == false)
    }

    @Test func calendarInBriefDefaultsOffAndRoundTrips() throws {
        // P2.6 calendar half is opt-in: fresh installs never request EventKit.
        #expect(BrowserChromePreferences().includeCalendarInBrief == false)
        let legacy = try JSONDecoder().decode(BrowserChromePreferences.self, from: Data("{}".utf8))
        #expect(legacy.includeCalendarInBrief == false)
        let original = BrowserChromePreferences(includeCalendarInBrief: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserChromePreferences.self, from: data)
        #expect(decoded.includeCalendarInBrief)
        #expect(decoded.normalized.includeCalendarInBrief)
    }

    @Test func layoutNormalizationIsIdempotent() {
        let prefs = BrowserChromePreferences(layout: "Diagonal")
        let normalized = prefs.normalized
        #expect(normalized.normalized == normalized)
    }

    @Test func splitOrientationToggleFlips() {
        #expect(SplitOrientation.horizontal.toggled == .vertical)
        #expect(SplitOrientation.vertical.toggled == .horizontal)
    }

@Test func browserPresetIncludesTabPosition() {
        let preset = BrowserPreset(tabPosition: .vertical, tabDensity: .standard, defaultSearchEngine: "google", showBookmarkBar: false, contentBlockerEnabled: true)
        #expect(preset.tabPosition == .vertical)
    }

@Test func tabDensitiesAreNonEmpty() {
        #expect(!TabDensity.allCases.isEmpty)
    }
}
