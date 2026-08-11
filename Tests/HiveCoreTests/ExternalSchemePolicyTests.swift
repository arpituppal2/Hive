import Foundation
import Testing
@testable import HiveCore

struct ExternalSchemePolicyTests {

    @Test("mailto links hand off to the OS")
    func mailtoHandsOff() {
        #expect(ExternalSchemePolicy.shouldHandOff(URL(string: "mailto:alice@example.com")))
        #expect(ExternalSchemePolicy.shouldHandOff(URL(string: "mailto:?to=a@b.com&subject=Hi")))
    }

    @Test("tel links hand off to the OS")
    func telHandsOff() {
        #expect(ExternalSchemePolicy.shouldHandOff(URL(string: "tel:+1-555-0100")))
        #expect(ExternalSchemePolicy.shouldHandOff(URL(string: "tel:5550100")))
    }

    @Test("sms links hand off to the OS")
    func smsHandsOff() {
        #expect(ExternalSchemePolicy.shouldHandOff(URL(string: "sms:+15550100")))
    }

    @Test("scheme matching is case-insensitive")
    func schemeCaseInsensitive() {
        #expect(ExternalSchemePolicy.shouldHandOff(URL(string: "MAILTO:alice@example.com")))
        #expect(ExternalSchemePolicy.shouldHandOff(URL(string: "Tel:5550100")))
    }

    @Test("web and internal schemes never hand off")
    func webSchemesStayInBrowser() {
        #expect(!ExternalSchemePolicy.shouldHandOff(URL(string: "https://example.com")))
        #expect(!ExternalSchemePolicy.shouldHandOff(URL(string: "http://example.com")))
        #expect(!ExternalSchemePolicy.shouldHandOff(URL(string: "hive://start")))
        #expect(!ExternalSchemePolicy.shouldHandOff(URL(string: "about:blank")))
    }

    @Test("dangerous or unknown schemes never hand off")
    func dangerousSchemesStayBlockedOrInBrowser() {
        #expect(!ExternalSchemePolicy.shouldHandOff(URL(string: "javascript:alert(1)")))
        #expect(!ExternalSchemePolicy.shouldHandOff(URL(string: "data:text/html,hi")))
        #expect(!ExternalSchemePolicy.shouldHandOff(URL(string: "file:///etc/passwd")))
        #expect(!ExternalSchemePolicy.shouldHandOff(URL(string: "app://custom-thing")))
    }

    @Test("malformed or empty input never hands off")
    func malformedNeverHandsOff() {
        #expect(!ExternalSchemePolicy.shouldHandOff(nil))
        #expect(!ExternalSchemePolicy.shouldHandOff(string: ""))
        #expect(!ExternalSchemePolicy.shouldHandOff(string: "not a url"))
    }

    @Test("bare scheme without a target still hands off (Chrome parity)")
    func bareSchemeHandsOff() {
        #expect(ExternalSchemePolicy.shouldHandOff(URL(string: "mailto:")))
        #expect(ExternalSchemePolicy.shouldHandOff(URL(string: "tel:")))
    }
}
