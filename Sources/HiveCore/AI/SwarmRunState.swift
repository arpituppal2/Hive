import Foundation

/// User-visible lifecycle for one Swarm request. This is deliberately separate
/// from provider state: a request can be running on a real provider or on the
/// honest mock fallback, and either can be cancelled or fail.
public enum SwarmRunState: String, Sendable, Codable, CaseIterable {
    case idle
    case running
    case stopping
    case completed
    case failed
    case cancelled

    /// Whether the request still owns background work that can be stopped.
    public var isActive: Bool {
        self == .running || self == .stopping
    }

    /// Compact copy for the browser's dense status strip.
    public var label: String {
        switch self {
        case .idle:      return "Ready"
        case .running:   return "Working"
        case .stopping:  return "Stopping"
        case .completed: return "Complete"
        case .failed:    return "Failed"
        case .cancelled: return "Stopped"
        }
    }

    public var systemImage: String {
        switch self {
        case .idle:      return "circle"
        case .running:   return "arrow.triangle.2.circlepath"
        case .stopping:  return "stop.circle"
        case .completed: return "checkmark.circle"
        case .failed:    return "exclamationmark.circle"
        case .cancelled: return "stop.circle"
        }
    }
}
