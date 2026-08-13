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

    @Test("cdpURLPatterns normalizes dotted hosts and removes duplicates")
    func patternDottedHostNormalization() {
        let patterns = AdBlockPolicy.cdpURLPatterns(for: [
            ".DoubleClick.Net.", "doubleclick.net", "ads.example/", "*.bad.example",
            "query.example?x=1", "fragment.example#section", "slash\\\\example"
        ])
        #expect(patterns == [
            "*://*.doubleclick.net/*",
            "*://doubleclick.net/*"
        ])
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

    @Test("cosmeticHideScript escapes control characters and line separators")
    func cosmeticControlCharacterEscaping() {
        let script = AdBlockPolicy.cosmeticHideScript(selectors: [".ad\rbanner", ".test\u{2028}selector", ".para\u{2029}graph"])
        #expect(script != nil)
        #expect(script!.contains("\\r"))
        #expect(script!.contains("\\u2028"))
        #expect(script!.contains("\\u2029"))
        #expect(!script!.contains("\r"))
        #expect(!script!.contains("\u{2028}"))
        #expect(!script!.contains("\u{2029}"))
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

    // MARK: Network-layer host matcher (CefResourceFilter predicate)

    @Test("network host matcher blocks exact host and subdomains")
    func hostMatcherExactAndSubdomain() {
        let domains = ["doubleclick.net", "google-analytics.com"]
        #expect(AdBlockPolicy.shouldBlockNetworkHost("doubleclick.net", domains: domains))
        #expect(AdBlockPolicy.shouldBlockNetworkHost("securepubads.g.doubleclick.net", domains: domains))
        #expect(AdBlockPolicy.shouldBlockNetworkHost("www.google-analytics.com", domains: domains))
        #expect(!AdBlockPolicy.shouldBlockNetworkHost("example.com", domains: domains))
        // Leading-dot guard: a same-suffix non-subdomain host must not match.
        #expect(!AdBlockPolicy.shouldBlockNetworkHost("notdoubleclick.net", domains: domains))
    }

    @Test("network host matcher handles nil, empty, and case variants")
    func hostMatcherEdgeCases() {
        let domains = ["DoubleClick.Net", "  ", "ads.example"]
        #expect(AdBlockPolicy.shouldBlockNetworkHost("doubleclick.net", domains: domains))
        #expect(AdBlockPolicy.shouldBlockNetworkHost("cdn.ads.example", domains: domains))
        #expect(!AdBlockPolicy.shouldBlockNetworkHost(nil, domains: domains))
        #expect(!AdBlockPolicy.shouldBlockNetworkHost("", domains: domains))
    }

    @Test("network host matcher normalizes DNS root dots and rejects malformed domains")
    func hostMatcherNormalizesAndRejectsMalformedDomains() {
        let domains = [".doubleclick.net.", "ads.example/"]
        #expect(AdBlockPolicy.shouldBlockNetworkHost("secure.doubleclick.net.", domains: domains))
        #expect(!AdBlockPolicy.shouldBlockNetworkHost("ads.example", domains: domains))
        #expect(!AdBlockPolicy.shouldBlockNetworkHost("doubleclick.net/path", domains: domains))
    }

    @Test("network host matcher accepts a Set input")
    func hostMatcherSetInput() {
        let set: Set<String> = ["tracker.example"]
        #expect(AdBlockPolicy.shouldBlockNetworkHost("tracker.example", domains: set))
        #expect(AdBlockPolicy.shouldBlockNetworkHost("a.b.tracker.example", domains: set))
        #expect(!AdBlockPolicy.shouldBlockNetworkHost("tracker.example.evil.com", domains: set))
    }
}
