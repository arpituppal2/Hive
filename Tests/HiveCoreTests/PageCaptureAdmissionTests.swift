import Testing
@testable import HiveCore

@Suite("PageCaptureAdmission")
struct PageCaptureAdmissionTests {
    @Test func allowsNonPrivatePageCapture() {
        #expect(PageCaptureAdmission.evaluate(isPrivate: false) == .allowed)
        #expect(PageCaptureAdmission.evaluate(isPrivate: false).isAllowed)
    }

    @Test func deniesPrivatePageCapture() {
        let decision = PageCaptureAdmission.evaluate(isPrivate: true)
        #expect(decision == .deniedPrivateBrowsing)
        #expect(!decision.isAllowed)
        #expect(decision.userMessage.contains("not captured"))
    }

    @Test func allowedDecisionHasNonEmptyUserMessage() {
        let decision = PageCaptureAdmission.evaluate(isPrivate: false)
        #expect(!decision.userMessage.isEmpty, "allowed capture should confirm success")
    }

    @Test func deniedUserMessageIsNonEmpty() {
        let decision = PageCaptureAdmission.evaluate(isPrivate: true)
        #expect(!decision.userMessage.isEmpty)
    }

    @Test func isAllowedIsConsistentWithDecision() {
        let allowed = PageCaptureAdmission.evaluate(isPrivate: false)
        let denied = PageCaptureAdmission.evaluate(isPrivate: true)
        #expect(allowed.isAllowed)
        #expect(!denied.isAllowed)
    }

@Test func allowedStateIsNotDenied() {
        let decision = PageCaptureAdmission.evaluate(isPrivate: false)
        #expect(decision != .deniedPrivateBrowsing)
    }

    @Test func evaluateAlwaysReturnsDecision() {
        for priv in [true, false] {
            let d = PageCaptureAdmission.evaluate(isPrivate: priv)
            #expect(!d.userMessage.isEmpty)
        }
    }

@Test func browserCommandsIncludeNewTab() {
        #expect(BrowserCommand.allCases.contains(.newTab))
    }

    @Test func browserCommandCountIsReasonable() {
        #expect(BrowserCommand.allCases.count >= 20)
    }
}
