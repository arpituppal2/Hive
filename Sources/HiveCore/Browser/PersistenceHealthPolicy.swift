import Foundation

/// Pure presentation and gating facts for the browser's durable stores.
///
/// A failure is sticky for the process that observed it: a later successful
/// write cannot prove that the earlier mutation was durably retained. The
/// Chromium shell owns the latching state; this value keeps the user-facing
/// message and combined degraded predicate deterministic and testable.
public struct PersistenceHealthPolicy: Sendable, Equatable {
    public let knowledgeDegraded: Bool
    public let auditDegraded: Bool
    public let sessionDegraded: Bool

    public init(knowledgeDegraded: Bool, auditDegraded: Bool, sessionDegraded: Bool) {
        self.knowledgeDegraded = knowledgeDegraded
        self.auditDegraded = auditDegraded
        self.sessionDegraded = sessionDegraded
    }

    public var isDegraded: Bool {
        knowledgeDegraded || auditDegraded || sessionDegraded
    }

    public var title: String {
        switch (knowledgeDegraded, auditDegraded, sessionDegraded) {
        case (true, true, true): return "Storage unavailable"
        case (true, true, false): return "Knowledge and audit storage unavailable"
        case (true, false, true): return "Knowledge and session storage unavailable"
        case (false, true, true): return "Audit and session storage unavailable"
        case (true, false, false): return "Knowledge storage unavailable"
        case (false, true, false): return "Audit storage unavailable"
        case (false, false, true): return "Session storage unavailable"
        case (false, false, false): return "Storage available"
        }
    }

    /// Applies the result of a browser-session write without clearing a prior
    /// failure. A successful later write cannot prove that an earlier mutation
    /// was retained, so the session failure remains latched for this process.
    public func afterSessionWrite(succeeded: Bool) -> PersistenceHealthPolicy {
        guard !succeeded else { return self }
        return PersistenceHealthPolicy(
            knowledgeDegraded: knowledgeDegraded,
            auditDegraded: auditDegraded,
            sessionDegraded: true
        )
    }

    public var detail: String {
        switch (knowledgeDegraded, auditDegraded, sessionDegraded) {
        case (true, true, true):
            return "Activity is kept only for this session. Captures, actions, and browser changes may not be saved until durable storage is available again."
        case (true, true, false):
            return "Captures and actions may not be saved until durable storage is available again."
        case (true, false, true):
            return "Knowledge edits and browser changes may not be saved until durable storage is available again."
        case (false, true, true):
            return "Actions and browser changes may not be saved until durable storage is available again."
        case (true, false, false):
            return "Captures and knowledge edits will not be saved until durable storage is available again."
        case (false, true, false):
            return "Actions cannot run without durable audit storage. Durable audit storage must be available again before actions can run."
        case (false, false, true):
            return "Browser changes may not survive a restart until durable session storage is available again."
        case (false, false, false):
            return "Durable storage is available."
        }
    }
}
