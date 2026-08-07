import HiveCore
import Testing

@Suite("Page Capture Delivery Policy")
struct PageCaptureDeliveryPolicyTests {
    @Test func manualCapturePersistsButRespectsSwarmConsent() {
        let allowed = PageCaptureDeliveryPolicy.decide(
            disposition: .manual,
            isPrivate: false,
            aiContextAllowed: true
        )
        let hidden = PageCaptureDeliveryPolicy.decide(
            disposition: .manual,
            isPrivate: false,
            aiContextAllowed: false
        )

        #expect(allowed == PageCaptureDelivery(persistCapture: true, fulfillContext: true, launchAutoTriage: false))
        #expect(hidden == PageCaptureDelivery(persistCapture: true, fulfillContext: false, launchAutoTriage: false))
    }

    @Test func autoCaptureRequiresSwarmConsent() {
        let allowed = PageCaptureDeliveryPolicy.decide(
            disposition: .auto,
            isPrivate: false,
            aiContextAllowed: true
        )
        let denied = PageCaptureDeliveryPolicy.decide(
            disposition: .auto,
            isPrivate: false,
            aiContextAllowed: false
        )

        #expect(allowed == PageCaptureDelivery(persistCapture: true, fulfillContext: true, launchAutoTriage: true))
        #expect(denied == PageCaptureDelivery(persistCapture: false, fulfillContext: false, launchAutoTriage: false))
    }

    @Test(arguments: [PageCaptureRequestDisposition.canceledAuto, .stale])
    func staleOrCanceledRequestsHaveNoEffects(_ disposition: PageCaptureRequestDisposition) {
        let result = PageCaptureDeliveryPolicy.decide(
            disposition: disposition,
            isPrivate: false,
            aiContextAllowed: true
        )
        #expect(result == PageCaptureDelivery(persistCapture: false, fulfillContext: false, launchAutoTriage: false))
    }

    @Test func privateContentHasNoEffectsRegardlessOfRequestKind() {
        for disposition in [PageCaptureRequestDisposition.manual, .auto] {
            let result = PageCaptureDeliveryPolicy.decide(
                disposition: disposition,
                isPrivate: true,
                aiContextAllowed: true
            )
            #expect(result == PageCaptureDelivery(persistCapture: false, fulfillContext: false, launchAutoTriage: false))
        }
    }
}
