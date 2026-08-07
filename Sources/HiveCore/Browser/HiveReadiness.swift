import Foundation

/// Bootstrap-only readiness state. This is not a claim that pages, models,
/// microphone permissions, or privileged actions are working.
public struct HiveReadinessReport: Sendable, Codable, Equatable {
    public let appInitialized: Bool
    public let browserShellReady: Bool
    public let message: String

    public init(
        appInitialized: Bool,
        browserShellReady: Bool,
        message: String
    ) {
        self.appInitialized = appInitialized
        self.browserShellReady = browserShellReady
        self.message = String(message.prefix(240))
    }

    public var isReady: Bool {
        appInitialized && browserShellReady
    }

    /// Stable, single-line output for a local smoke harness. JSONEncoder's
    /// sorted keys keep logs and CI comparisons deterministic.
    public func markerLine() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payload = (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "HIVE_READINESS_\(isReady ? "PASS" : "FAIL") \(payload)"
    }
}
