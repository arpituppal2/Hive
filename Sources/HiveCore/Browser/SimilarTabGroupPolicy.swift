import Foundation

/// Pure planner for Arc-style "Group Similar Tabs": given the open tabs in a
/// workspace, suggest one tab group per domain (2+ tabs on the same host).
///
/// The policy knows nothing about tabs' existing groups, pinning, or privacy —
/// the caller filters candidates to what may be grouped and passes only ids
/// plus host keys. Grouping logic stays deterministic and unit-tested without
/// launching a browser.
public struct TabGroupCandidate: Sendable, Equatable {
    public let id: String
    /// Durable site key (http/https, www-stripped, lowercase); nil candidates
    /// (internal chrome, blank, local files) are never groupable.
    public let hostKey: String?

    public init(id: String, hostKey: String?) {
        self.id = id
        self.hostKey = hostKey
    }
}

/// A suggested group: one domain's tabs, ordered by tab order.
public struct SimilarTabGroup: Sendable, Equatable {
    public let hostKey: String
    /// Human-readable group name derived from the host.
    public let displayName: String
    public let tabIDs: [String]

    public init(hostKey: String, displayName: String, tabIDs: [String]) {
        self.hostKey = hostKey
        self.displayName = displayName
        self.tabIDs = tabIDs
    }
}

public enum SimilarTabGroupPolicy {

    /// The shared http(s) host-keying primitive (www-stripped, lowercased) —
    /// the same convention the per-site mute and zoom keying use, so a tab on
    /// `www.GitHub.com` and one on `github.com` group together.
    public static func hostKey(for url: URL?) -> String? {
        SiteMutePolicy.hostKey(for: url)
    }

    /// Suggests groups from candidates. Every host with at least two
    /// candidates becomes a group; singletons and key-less candidates are
    /// dropped. Results are ordered largest-first, then alphabetically, so the
    /// most prominent domains land first in the workspace.
    public static func suggestedGroups(candidates: [TabGroupCandidate]) -> [SimilarTabGroup] {
        var members: [String: [String]] = [:]
        for candidate in candidates {
            guard let hostKey = candidate.hostKey else { continue }
            members[hostKey, default: []].append(candidate.id)
        }
        let groups = members.compactMap { hostKey, tabIDs -> SimilarTabGroup? in
            guard tabIDs.count >= 2 else { return nil }
            return SimilarTabGroup(
                hostKey: hostKey,
                displayName: displayName(for: hostKey),
                tabIDs: tabIDs
            )
        }
        return groups.sorted {
            if $0.tabIDs.count != $1.tabIDs.count {
                return $0.tabIDs.count > $1.tabIDs.count
            }
            return $0.hostKey < $1.hostKey
        }
    }

    /// Turns a host key into a group label: the bare host with the first
    /// letter capitalized (`github.com` → `Github.com`), and a leading `www.`
    /// dropped (callers can rename freely afterward).
    public static func displayName(for hostKey: String) -> String {
        var host = hostKey
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
        guard let first = host.first else { return host }
        return String(first).uppercased() + host.dropFirst()
    }
}
