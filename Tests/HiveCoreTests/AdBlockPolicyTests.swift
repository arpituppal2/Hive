import Testing
import Foundation
@testable import HiveCore

// MARK: - AdBlockPolicyTests
//
// Locks the two wire formats the app target ships to the browser: the CDP
// Network.setBlockedURLs pattern list and the cosmetic-hide injection script.

@Suite("AdBlockPolicy")
struct AdBlockPolicyTests {

    @Test("cdpURLPatterns emits bare + subdomain patterns per host")
    func patternCoverage() {
        let patterns = AdBlockPolicy.cdpURLPatterns(for: ["doubleclick.net", "tracker.example"])
        #expect(patterns.contains("*://*.doubleclick.net/*"))
        #expect(patterns.contains("*://doubleclick.net/*"))
        #expect(patterns.contains("*://*.tracker.example/*"))
        #expect(patterns.contains("*://tracker.example/*"))
        #expect(patterns.count == 4)
    }

    @Test("cdpURLPatterns lowercases hosts and drops empty entries")
    func patternNormalization() {
        let patterns = AdBlockPolicy.cdpURLPatterns(for: ["  DoubleClick.Net ", "", "  ", "ads.example"])
        #expect(patterns.contains("*://*.doubleclick.net/*"))
        #expect(patterns.contains("*://ads.example/*"))
        #expect(!patterns.contains { $0.hasSuffix("//*/") })
        #expect(patterns.count == 4)
    }

    @Test("cdpURLPatterns returns empty for empty input")
    func patternEmpty() {
        #expect(AdBlockPolicy.cdpURLPatterns(for: []).isEmpty)
    }

    @Test("cosmeticHideScript returns nil when there is nothing to hide")
    func cosmeticNilForEmpty() {
        #expect(AdBlockPolicy.cosmeticHideScript(selectors: []) == nil)
        #expect(AdBlockPolicy.cosmeticHideScript(selectors: ["  "]) == nil)
    }

    @Test("cosmeticHideScript joins selectors and self-guards")
    func cosmeticScriptShape() {
        let script = AdBlockPolicy.cosmeticHideScript(selectors: [".ad-banner", "#sponsored"])
        #expect(script != nil)
        #expect(script!.contains("__hiveAdBlockCosmeticInstalled"))
        #expect(script!.contains(".ad-banner, #sponsored { display: none !important; }"))
        #expect(script!.contains("hive-adblock-cosmetic"))
    }

    @Test("cosmeticHideScript escapes quotes in selectors")
    func cosmeticEscaping() {
        let script = AdBlockPolicy.cosmeticHideScript(selectors: [".a[b=\"x\"]"])
        #expect(script != nil)
        // The selector's quotes are backslash-escaped for the JS string.
        #expect(script!.contains(".a[b=\\\"x\\\"]"))
        // The raw (unescaped) selector form must not appear.
        #expect(!script!.contains(".a[b=\"x\"]"))
    }
}
