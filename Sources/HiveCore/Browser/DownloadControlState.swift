import Foundation

/// The UI-level truth for a download control request.
///
/// CEF's controller methods are fire-and-forget and its progress callback does
/// not expose an authoritative paused bit. The browser must therefore describe
/// a request as pending until a native callback can reconcile it, rather than
/// claiming that a transfer paused or resumed merely because a button was
/// clicked.
public enum DownloadControlState: String, Codable, Sendable, Equatable {
    case active
    case paused
    case pauseRequested
    case resumeRequested
}

public enum DownloadControlAction: String, Codable, Sendable, Equatable {
    case pause
    case resume
}

public struct DownloadControlTransition: Sendable, Equatable {
    public let state: DownloadControlState
    public let action: DownloadControlAction

    public init(state: DownloadControlState, action: DownloadControlAction) {
        self.state = state
        self.action = action
    }
}

/// Pure transition rules for pause/resume controls.
///
/// The native adapter calls `requestPause`/`requestResume` before invoking the
/// CEF controller. It then calls `reconcile(progressState:)` from the next
/// native update. A new request is allowed only after the prior request has
/// been reconciled, preventing double-clicks from issuing contradictory
/// fire-and-forget commands.
public struct DownloadControlStateMachine: Sendable, Equatable {
    public private(set) var state: DownloadControlState

    public init(state: DownloadControlState = .active) {
        self.state = state
    }

    public var canRequestPause: Bool { state == .active }
    public var canRequestResume: Bool { state == .paused }

    public mutating func requestPause() -> DownloadControlTransition? {
        guard canRequestPause else { return nil }
        state = .pauseRequested
        return DownloadControlTransition(state: state, action: .pause)
    }

    public mutating func requestResume() -> DownloadControlTransition? {
        guard canRequestResume else { return nil }
        state = .resumeRequested
        return DownloadControlTransition(state: state, action: .resume)
    }

    /// Reconciles the pending command with the native observation.
    ///
    /// `nativeIsPaused == nil` means the wrapper cannot currently report a
    /// paused state; keep a pending request visible rather than inventing a
    /// result. The caller may reset to `.active`/`.paused` only when it has a
    /// real engine signal.
    public mutating func reconcile(nativeIsPaused: Bool?) {
        guard let nativeIsPaused else { return }
        state = nativeIsPaused ? .paused : .active
    }

    /// Returns to the last actionable baseline when the wrapper does not
    /// report a native result within the adapter's bounded wait window.
    /// A timeout is deliberately not treated as success: the user can try
    /// again instead of being trapped behind a pending control forever.
    public mutating func timeoutPendingRequest() {
        switch state {
        case .pauseRequested: state = .active
        case .resumeRequested: state = .paused
        case .active, .paused: break
        }
    }

    /// Clears a stale request when the transfer reaches a terminal state or
    /// the browser process loses its controller. Terminal history cannot
    /// expose a pause/resume affordance.
    public mutating func resetToActive() {
        state = .active
    }
}
