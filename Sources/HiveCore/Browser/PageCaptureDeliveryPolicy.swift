import Foundation

/// The independent effects a delivered page capture may perform.
public struct PageCaptureDelivery: Equatable, Sendable {
    public let persistCapture: Bool
    public let fulfillContext: Bool
    public let launchAutoTriage: Bool

    public init(persistCapture: Bool, fulfillContext: Bool, launchAutoTriage: Bool) {
        self.persistCapture = persistCapture
        self.fulfillContext = fulfillContext
        self.launchAutoTriage = launchAutoTriage
    }
}

/// Pure policy for the `.captureReady` ingress after request identity is resolved.
///
/// This does not write Honeycomb, invoke a model, or mutate UI state. It makes
/// the browser trust contract explicit and testable before those side effects:
/// stale/private requests do nothing; manual captures may persist even when the
/// user has disabled Swarm inspection; Auto-Capture requires AI context consent.
public enum PageCaptureDeliveryPolicy {
    public static func decide(
        disposition: PageCaptureRequestDisposition,
        isPrivate: Bool,
        aiContextAllowed: Bool
    ) -> PageCaptureDelivery {
        guard disposition == .manual || disposition == .auto,
              !isPrivate else {
            return PageCaptureDelivery(persistCapture: false, fulfillContext: false, launchAutoTriage: false)
        }

        switch disposition {
        case .manual:
            return PageCaptureDelivery(
                persistCapture: true,
                fulfillContext: aiContextAllowed,
                launchAutoTriage: false
            )
        case .auto:
            guard aiContextAllowed else {
                return PageCaptureDelivery(persistCapture: false, fulfillContext: false, launchAutoTriage: false)
            }
            return PageCaptureDelivery(persistCapture: true, fulfillContext: true, launchAutoTriage: true)
        case .canceledAuto, .stale:
            return PageCaptureDelivery(persistCapture: false, fulfillContext: false, launchAutoTriage: false)
        }
    }
}
