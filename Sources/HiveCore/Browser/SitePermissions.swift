import Foundation

// MARK: - SitePermissions
//
// Tracks per-site permission grants (camera, microphone, location, notifications,
// popups, downloads). Persisted in ChromeUserPrefs alongside other durable prefs.
// By default all permissions require explicit user consent (prompt); once granted
// or denied, the choice is remembered per (host, permission) pair.

/// The set of permissions a site can request.
public enum SitePermissionKind: String, Sendable, Codable, CaseIterable {
    case camera
    case microphone
    case location
    case notifications
    case popups
    case automaticDownloads
}

/// The user's decision for a specific permission.
public enum SitePermissionState: String, Sendable, Codable, Equatable {
    /// The user hasn't been asked yet — we'll prompt.
    case ask
    /// The user explicitly granted this permission.
    case allow
    /// The user explicitly denied this permission.
    case deny
}

/// A single per-(host, kind) permission entry.
public struct SitePermission: Sendable, Codable, Identifiable, Equatable {
    public var id: String { "\(host):\(kind.rawValue)" }
    /// Normalized host (e.g. "www.example.com" with "www." stripped if needed).
    public let host: String
    /// The kind of permission.
    public let kind: SitePermissionKind
    /// Current decision.
    public var state: SitePermissionState
    /// When this entry was last modified.
    public var modifiedAt: Date

    public init(host: String, kind: SitePermissionKind, state: SitePermissionState = .ask, modifiedAt: Date = Date()) {
        self.host = host
        self.kind = kind
        self.state = state
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Permission query helpers

public extension Array where Element == SitePermission {
    /// Returns the effective state for a given (host, kind) pair. Defaults to `.ask`.
    func state(forHost host: String, kind: SitePermissionKind) -> SitePermissionState {
        first { $0.host == host && $0.kind == kind }?.state ?? .ask
    }

    /// Records or updates a permission decision.
    mutating func setPermission(host: String, kind: SitePermissionKind, state: SitePermissionState) {
        if let idx = firstIndex(where: { $0.host == host && $0.kind == kind }) {
            self[idx].state = state
            self[idx].modifiedAt = Date()
        } else {
            append(SitePermission(host: host, kind: kind, state: state))
        }
    }

    /// Removes all permissions for a given host (site data reset).
    mutating func removeAll(forHost host: String) {
        removeAll { $0.host == host }
    }
}
