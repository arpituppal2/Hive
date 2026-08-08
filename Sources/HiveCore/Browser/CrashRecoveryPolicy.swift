import Foundation

/// The browser's response to a renderer/tab crash signal.
///
/// This is deliberately independent from CEF/WKWebView delegate APIs. A
/// renderer adapter can feed it a `CrashRecord` when the platform exposes a
/// termination event; until then, the policy remains a deterministic seam and
/// does not pretend that crashes are observable in every renderer target.
public enum CrashRecoveryDecision: Sendable, Equatable {
    /// The tab may be reloaded automatically once.
    case retryAutomatically
    /// Automatic reload must stop; show recovery controls to the user.
    case showRecovery(retryAllowed: Bool)
}

/// Pure policy for preventing crash loops from becoming an infinite reload
/// loop. The existing threshold is three crashes inside five minutes.
public struct CrashRecoveryPolicy: Sendable, Equatable {
    public let automaticRetryLimit: Int
    /// Bounded delays, in seconds, for automatic retry attempts. The first
    /// retry waits 500ms, then 1.5s, then 3s; later attempts remain capped at
    /// 3s. The browser adapter owns the actual sleep/reload operation.
    public let automaticRetryBackoff: [TimeInterval]

    public static let defaultAutomaticRetryBackoff: [TimeInterval] = [0.5, 1.5, 3.0]
    public static let maximumAutomaticRetryDelay: TimeInterval = 3.0

    public init(
        automaticRetryLimit: Int = 1,
        automaticRetryBackoff: [TimeInterval] = CrashRecoveryPolicy.defaultAutomaticRetryBackoff
    ) {
        self.automaticRetryLimit = max(0, automaticRetryLimit)
        let sanitized = automaticRetryBackoff.map { delay in
            guard delay.isFinite else { return Self.maximumAutomaticRetryDelay }
            return min(max(0, delay), Self.maximumAutomaticRetryDelay)
        }
        self.automaticRetryBackoff = sanitized.isEmpty
            ? Self.defaultAutomaticRetryBackoff
            : sanitized
    }

    /// Returns the bounded delay for a one-based automatic retry number.
    /// Attempts beyond the configured schedule use its final delay.
    public func delay(forAutomaticRetryNumber attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let index = min(attempt - 1, automaticRetryBackoff.count - 1)
        return automaticRetryBackoff[index]
    }

    public func decision(for crash: CrashRecord, automaticRetriesUsed: Int = 0) -> CrashRecoveryDecision {
        guard crash.isCrashLoop else {
            return automaticRetriesUsed < automaticRetryLimit
                ? .retryAutomatically
                : .showRecovery(retryAllowed: true)
        }

        return .showRecovery(retryAllowed: true)
    }
}
