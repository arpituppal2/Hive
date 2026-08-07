import Foundation

// MARK: - PageCaptureAdmission

/// The decision made before extracted page content is allowed to enter any
/// browser capture pipeline. This policy is intentionally independent of
/// WebKit/CEF, Honeycomb, and model runtimes so every ingress can share it.
public enum PageCaptureAdmission: Sendable, Equatable {
    case allowed
    case deniedPrivateBrowsing

    public var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }

    public var userMessage: String {
        switch self {
        case .allowed:
            return "Page capture is allowed."
        case .deniedPrivateBrowsing:
            return "Private pages are not captured or added to Hive memory."
        }
    }

    public static func evaluate(isPrivate: Bool) -> PageCaptureAdmission {
        isPrivate ? .deniedPrivateBrowsing : .allowed
    }
}
