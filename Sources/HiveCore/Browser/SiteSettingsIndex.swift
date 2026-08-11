import Foundation

// MARK: - SiteSettingsIndex
//
// Aggregates every remembered per-site decision — zoom, mute, HTTPS-Only
// exceptions, and permission grants — into one deterministic, sorted index
// for the "Site Settings" hub (Chrome's chrome://settings/content/all
// parity). Pure and testable; the app target owns the four stores and feeds
// them in.

/// One host with all of its remembered decisions.
public struct SiteSettingsEntry: Identifiable, Equatable, Sendable {
    public var id: String { host }
    /// The www-stripped, lowercase host key shared by all four stores.
    public let host: String
    /// Remembered zoom percent, or nil when the site uses the default.
    public let zoomPercent: Int?
    /// Whether the site is in the durable per-site mute set.
    public let isMuted: Bool
    /// Whether the host is exempted from HTTPS-Only upgrades.
    public let isHTTPSException: Bool
    /// Explicit (non-ask) permission decisions, newest first.
    public let permissions: [SitePermission]

    /// The durable permission kinds that have an explicit decision.
    public var decidedKinds: [SitePermissionKind] { permissions.map(\.kind) }

    /// Number of stored decisions (zoom, mute, exception, permissions).
    public var decisionCount: Int {
        (zoomPercent == nil ? 0 : 1) + (isMuted ? 1 : 0) + (isHTTPSException ? 1 : 0) + permissions.count
    }

    /// Short human summary for list rows: "125% · Muted · 2 permissions".
    public var summary: String {
        var parts: [String] = []
        if let zoomPercent { parts.append("\(zoomPercent)% zoom") }
        if isMuted { parts.append("Muted") }
        if isHTTPSException { parts.append("HTTP allowed") }
        let decided = permissions.count
        if decided == 1 {
            parts.append("1 permission")
        } else if decided > 1 {
            parts.append("\(decided) permissions")
        }
        return parts.isEmpty ? "Default settings" : parts.joined(separator: " · ")
    }
}

public enum SiteSettingsIndex {

    /// Merges the four per-site stores into one sorted index. A host appears
    /// if any store remembers a decision for it (zoom ≠ 100 counts; ask-state
    /// permissions do not). Hosts are sorted case-insensitively. An HTTPS
    /// exception is still listed while HTTPS-Only is off — the stored decision
    /// is inert until the mode is turned back on, and the hub says so.
    public static func build(
        zoomLevels: [String: Double],
        mutedHosts: Set<String>,
        httpsExceptions: Set<String>,
        permissions: [SitePermission]
    ) -> [SiteSettingsEntry] {
        var hosts = Set<String>()
        hosts.formUnion(zoomLevels.keys.filter { zoomLevels[$0] != 100 })
        hosts.formUnion(mutedHosts)
        hosts.formUnion(httpsExceptions)
        hosts.formUnion(permissions.filter { $0.state != .ask }.map(\.host))

        return hosts
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { host in
                SiteSettingsEntry(
                    host: host,
                    zoomPercent: zoomLevels[host].flatMap { $0 == 100 ? nil : Int($0.rounded()) },
                    isMuted: mutedHosts.contains(host),
                    isHTTPSException: httpsExceptions.contains(host),
                    permissions: permissions
                        .filter { $0.host == host && $0.state != .ask }
                        .sorted { $0.modifiedAt > $1.modifiedAt }
                )
            }
    }
}
