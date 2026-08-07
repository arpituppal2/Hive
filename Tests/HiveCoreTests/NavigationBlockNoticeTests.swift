import Testing
@testable import HiveCore

@Suite("NavigationBlockNotice")
struct NavigationBlockNoticeTests {
    @Test func normalizesSchemeAndExplainsNoLoad() {
        let notice = NavigationBlockNotice(scheme: "  JavaScript  ")

        #expect(notice.scheme == "javascript")
        #expect(notice.title == "Navigation blocked")
        #expect(notice.detail.contains("javascript:"))
        #expect(notice.detail.contains("Nothing was loaded"))
        #expect(notice.accessibilityLabel.contains("Navigation blocked"))
    }

    @Test func emptySchemeStillHasSafeFallbackMessage() {
        let notice = NavigationBlockNotice(scheme: " \n ")

        #expect(notice.scheme.isEmpty)
        #expect(notice.detail.contains("URL type is not supported"))
        #expect(notice.accessibilityLabel.contains("Nothing") == false)
    }
}
