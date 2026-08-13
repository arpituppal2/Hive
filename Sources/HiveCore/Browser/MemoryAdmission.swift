import Foundation

// MARK: - Memory admission

/// Describes whether a memory item is merely a session candidate or an item
/// explicitly admitted to durable memory. Model/page-derived content defaults to
/// `.candidate`; only a trusted user-authored or explicitly promoted path may
/// create `.durable` content.
public enum MemoryAdmission: String, Codable, Sendable, Equatable {
    case candidate
    case durable

    public var isDurable: Bool { self == .durable }
}

/// Shared policy boundary for memory ingress. Keeping this decision as a small,
/// platform-independent type prevents model output from silently acquiring the
/// same durability as an explicit user capture.
public enum MemoryAdmissionPolicy {
    /// Librarian/model extraction is always a candidate until a future
    /// confirmation or promotion flow calls a trusted durable API.
    public static func modelExtraction(isPrivate: Bool) -> MemoryAdmission? {
        isPrivate ? nil : .candidate
    }

    /// A direct user-authored capture is eligible for durable storage only when
    /// it is not private. The graph write remains the caller's responsibility.
    public static func userAuthoredCapture(isPrivate: Bool) -> MemoryAdmission? {
        isPrivate ? nil : .durable
    }
}
