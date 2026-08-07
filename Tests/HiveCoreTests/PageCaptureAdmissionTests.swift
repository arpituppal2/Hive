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
}
