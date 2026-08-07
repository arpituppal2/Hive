import Foundation

/// Privacy-safe, local-only evidence that a browser session was read and written.
/// This intentionally contains lifecycle facts only: it never carries URLs,
/// titles, page content, private-tab data, credentials, or model output.
public struct HiveSessionEvidence: Sendable, Codable, Equatable {
    public let restoredFromDisk: Bool
    public let priorCleanExit: Bool?
    public let snapshotSequence: UInt64
    public let durableTabCount: Int
    public let writeSucceeded: Bool

    public init(
        restoredFromDisk: Bool,
        priorCleanExit: Bool?,
        snapshotSequence: UInt64,
        durableTabCount: Int,
        writeSucceeded: Bool
    ) {
        self.restoredFromDisk = restoredFromDisk
        self.priorCleanExit = priorCleanExit
        self.snapshotSequence = snapshotSequence
        self.durableTabCount = max(0, durableTabCount)
        self.writeSucceeded = writeSucceeded
    }

    /// Stable single-line output consumed only by the opt-in local smoke
    /// harness. The marker is evidence, not a product telemetry event.
    public func markerLine() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payload = (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "HIVE_SESSION_EVIDENCE \(payload)"
    }
}
