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

    @Test func dataSchemeIsBlocked() {
        let notice = NavigationBlockNotice(scheme: "data")
        #expect(notice.scheme == "data")
        #expect(notice.title == "Navigation blocked")
        #expect(notice.detail.contains("data:"))
    }

    @Test func blobSchemeIsBlocked() {
        let notice = NavigationBlockNotice(scheme: "blob")
        #expect(notice.scheme == "blob")
        #expect(notice.detail.contains("blob:"))
    }

    @Test func noticeEquality() {
        let a = NavigationBlockNotice(scheme: "javascript")
        let b = NavigationBlockNotice(scheme: "  JavaScript  ")
        #expect(a == b)
    }

    @Test func emptySchemeStillHasSafeFallbackMessage() {
        let notice = NavigationBlockNotice(scheme: " \n ")

        #expect(notice.scheme.isEmpty)
        #expect(notice.detail.contains("URL type is not supported"))
        #expect(notice.accessibilityLabel.contains("Nothing") == false)
    }
}
