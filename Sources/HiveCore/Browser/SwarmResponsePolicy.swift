import Foundation

/// Pure lifecycle decision for an advisory response after an async boundary.
public enum SwarmResponseResolution: Sendable, Equatable {
    case apply
    case contextChanged
    case drop
}

/// Provider/context diagnostics that do not depend on a browser UI target.
public struct SwarmResponseDiagnostics: Sendable, Equatable {
    public let contextNodeCount: Int
    public let contextSummary: String
    public let rankerProvider: String?
    public let providerLabel: String
    public let durationMS: Int
    public let pageTitle: String?
    public let pageHost: String?

    public init(
        contextNodeCount: Int,
        contextSummary: String,
        rankerProvider: String?,
        providerLabel: String,
        durationMS: Int,
        pageTitle: String?,
        pageHost: String?
    ) {
        self.contextNodeCount = contextNodeCount
        self.contextSummary = contextSummary
        self.rankerProvider = rankerProvider
        self.providerLabel = providerLabel
        self.durationMS = durationMS
        self.pageTitle = pageTitle
        self.pageHost = pageHost
    }
}

public enum SwarmResponsePolicy {
    /// Cancellation or a superseded response drops silently. A live response
    /// with a stale browser transition gets an explicit context-change result.
    public static func resolution(
        responseIsCurrent: Bool,
        taskIsCancelled: Bool,
        transitionIsCurrent: Bool
    ) -> SwarmResponseResolution {
        guard responseIsCurrent, !taskIsCancelled else { return .drop }
        guard transitionIsCurrent else { return .contextChanged }
        return .apply
    }

    public static func diagnostics(
        for result: OrchestrationResult,
        pageSummary: String?,
        pageTitle: String?,
        pageHost: String?
    ) -> SwarmResponseDiagnostics {
        var summary = result.contextSummary
        if let pageSummary, !pageSummary.isEmpty {
            summary += "\n" + pageSummary
        }
        return SwarmResponseDiagnostics(
            contextNodeCount: result.contextNodeCount,
            contextSummary: summary,
            rankerProvider: result.rankerProvider,
            providerLabel: result.provider.rawValue,
            durationMS: result.durationMS,
            pageTitle: pageTitle,
            pageHost: pageHost
        )
    }
}
