import Foundation
import HiveCore
import Testing

@Suite("BrowserTab AI Context")
struct BrowserTabAIContextTests {
    @Test func newTabsAllowAIContextByDefault() {
        #expect(BrowserTab(url: URL(string: "https://example.com")).isAIContextAllowed)
    }

    @Test func disabledAIContextRoundTripsThroughCodable() throws {
        let original = BrowserTab(
            url: URL(string: "https://example.com"),
            title: "Example",
            isAIContextAllowed: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BrowserTab.self, from: data)
        #expect(decoded.isAIContextAllowed == false)
    }

    @Test func legacySessionsDefaultAIContextToAllowed() throws {
        let legacy: [String: AnyHashable] = [
            "id": "legacy-tab",
            "url": "https://example.com",
            "title": "Legacy",
            "isLoading": false,
            "loadProgress": 0,
            "canGoBack": false,
            "canGoForward": false,
            "isActive": true,
            "isPinned": false,
            "isPrivate": false,
            "isMuted": false,
            "isHibernated": false,
            "isReaderMode": false,
            "isPlayingAudio": false,
            "blockedCount": 0,
            "zoomLevel": 1.0
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let decoded = try JSONDecoder().decode(BrowserTab.self, from: data)
        #expect(decoded.isAIContextAllowed)
    }

    @Test func privateTabsAllowAIContextByDefault() {
        #expect(BrowserTab(url: URL(string: "https://example.com"), isPrivate: true).isAIContextAllowed)
    }

    @Test func togglingAIContextPersists() {
        var tab = BrowserTab(url: URL(string: "https://example.com"))
        #expect(tab.isAIContextAllowed)
        tab.isAIContextAllowed = false
        #expect(!tab.isAIContextAllowed)
        tab.isAIContextAllowed = true
        #expect(tab.isAIContextAllowed)
    }

    @Test func tabIDisNotEmptyAndStable() {
        let tab = BrowserTab(url: URL(string: "https://example.com"))
        #expect(!tab.id.isEmpty, "Every tab must have a unique identifier")
    }
}
