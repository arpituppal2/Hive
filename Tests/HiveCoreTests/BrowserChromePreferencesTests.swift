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
    }
}
