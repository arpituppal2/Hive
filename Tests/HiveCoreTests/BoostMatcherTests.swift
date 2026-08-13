import Foundation
import Testing
@testable import HiveCore

@Suite("BoostMatcher")
struct BoostMatcherTests {

    private func boost(_ host: String, _ css: String = "body { color: red; }", enabled: Bool = true) -> Boost {
        Boost(host: host, name: "T", css: css, isEnabled: enabled)
    }

    // MARK: - Matching

    @Test func exactHostMatchesOnlyItself() {
        #expect(BoostMatcher.matches(boostHost: "example.com", url: URL(string: "https://example.com/")))
        #expect(!BoostMatcher.matches(boostHost: "example.com", url: URL(string: "https://www.example.com/")))
        #expect(!BoostMatcher.matches(boostHost: "example.com", url: URL(string: "https://other.com/")))
        #expect(!BoostMatcher.matches(boostHost: "example.com", url: URL(string: "https://example.org/")))
    }

    @Test func leadingDotMatchesDomainAndSubdomains() {
        #expect(BoostMatcher.matches(boostHost: ".example.com", url: URL(string: "https://example.com/")))
        #expect(BoostMatcher.matches(boostHost: ".example.com", url: URL(string: "https://www.example.com/")))
        #expect(BoostMatcher.matches(boostHost: ".example.com", url: URL(string: "https://a.b.example.com/")))
        #expect(!BoostMatcher.matches(boostHost: ".example.com", url: URL(string: "https://example.org/")))
        #expect(!BoostMatcher.matches(boostHost: ".example.com", url: URL(string: "https://notexample.com/")))
    }

    @Test func matchingIsCaseInsensitiveAndTrimmed() {
        #expect(BoostMatcher.matches(boostHost: "  Example.COM ", url: URL(string: "https://EXAMPLE.com/")))
        #expect(!BoostMatcher.matches(boostHost: "   ", url: URL(string: "https://example.com/")))
        #expect(!BoostMatcher.matches(boostHost: "example.com", url: nil))
        #expect(!BoostMatcher.matches(boostHost: "example.com", url: URL(string: "hive://brief")))
    }

    @Test func hostValidationRejectsJunk() {
        #expect(Boost(host: "example.com").hasValidHost)
        #expect(Boost(host: ".example.com").hasValidHost)
        #expect(Boost(host: "").hasValidHost == false)
        #expect(Boost(host: "example.com:8080").hasValidHost == false)
        #expect(Boost(host: "https://example.com").hasValidHost == false)
        #expect(Boost(host: "exa mple.com").hasValidHost == false)
    }

    // MARK: - Injection script

    @Test func disabledBoostProducesNoScript() {
        #expect(BoostMatcher.injectScript(boost: boost("example.com", enabled: false)) == nil)
    }

    @Test func emptyCSSProducesNoScript() {
        #expect(BoostMatcher.injectScript(boost: boost("example.com", "   \n ")) == nil)
    }

    @Test func scriptCarriesUniqueStableElementID() {
        let b = boost("example.com")
        let script = BoostMatcher.injectScript(boost: b)!
        #expect(script.contains("hive-boost-\(b.id.uuidString)"))
        // The classic `<style>` element remains as the fallback path.
        #expect(script.contains("document.createElement(\"style\")"))
    }

    @Test func scriptPrefersCSPsafeConstructableStylesheets() {
        // Strict `style-src` pages (GitHub etc.) silently drop a dynamically
        // inserted `<style>` element; constructable stylesheets bypass the
        // page's CSP entirely, so they must be the primary injection path.
        let b = boost("example.com")
        let script = BoostMatcher.injectScript(boost: b)!
        #expect(script.contains("document.adoptedStyleSheets"))
        #expect(script.contains("new CSSStyleSheet()"))
        #expect(script.contains("replaceSync"))
        #expect(script.contains("__hiveBoostID"))
        // Idempotency: an existing sheet with the same boost id is removed.
        #expect(script.contains("s.__hiveBoostID !== id"))
    }

    @Test func scriptEscapesQuotesNewlinesBackslashesAndScriptBreakers() {
        let b = boost("example.com", "body { content: \"a\\b\"; }\n/* </script> */")
        let script = BoostMatcher.injectScript(boost: b)!
        #expect(!script.contains("</script>"))
        #expect(script.contains("<\\/script>"))
        #expect(script.contains("a\\\\b"))
        #expect(script.contains("\\n"))
    }

    @Test func scriptEscapesJSLineSeparators() {
        let b = boost("example.com", "a\u{2028}b\u{2029}c")
        let script = BoostMatcher.injectScript(boost: b)!
        #expect(script.contains("\\u2028"))
        #expect(script.contains("\\u2029"))
    }

    @Test func boostCodableRoundTrips() throws {
        let original = Boost(host: ".Example.com", name: "Dark news", css: "body { background: #000; }", isEnabled: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Boost.self, from: data)
        #expect(decoded == original)
        #expect(decoded.host == ".example.com")
    }
}
