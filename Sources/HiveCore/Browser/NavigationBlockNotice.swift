import Foundation

/// User-facing explanation for an omnibox navigation that was rejected before
/// it reached the browser engine. Keeping this in HiveCore makes the policy's
/// feedback deterministic and testable without SwiftUI or CEF.
public struct NavigationBlockNotice: Equatable, Sendable {
    public let scheme: String

    public init(scheme: String) {
        self.scheme = scheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public var title: String {
        "Navigation blocked"
    }

    public var detail: String {
        if scheme.isEmpty {
            return "Hive did not load this address because its URL type is not supported here."
        }
        return "Hive blocked \(scheme): links from the address bar. Nothing was loaded."
    }

    public var accessibilityLabel: String {
        if scheme.isEmpty {
            return "Navigation blocked. Hive did not load this address because its URL type is not supported here."
        }
        return "Navigation blocked. Hive blocked \(scheme): links from the address bar. Nothing was loaded."
    }
}
