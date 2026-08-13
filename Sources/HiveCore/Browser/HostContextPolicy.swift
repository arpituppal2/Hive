import Foundation

/// A local, origin-scoped decision controlling whether Swarm may read a web page.
///
/// This model deliberately stores no path, query, fragment, credentials, page
/// text, screenshot, cookie, history, or model output. Private browsing is an
/// unconditional deny at resolution time and cannot be overridden by `.allow`.
public struct HostContextPolicy: Sendable, Codable, Equatable {
    public enum Decision: String, CaseIterable, Codable, Sendable {
        case `default`
        case allow
        case block
    }

    public enum EffectiveState: String, CaseIterable, Codable, Sendable {
        case `default`
        case allowed
        case blocked
        case privateBrowsing
        case unavailable
    }

    public init(decisions: [String: Decision] = [:]) {
        self.decisions = Self.canonicalDecisions(decisions)
    }

    /// The only persisted data: canonical origins and non-default decisions.
    public private(set) var decisions: [String: Decision]

    private enum CodingKeys: String, CodingKey {
        case decisions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decodeIfPresent([String: Decision].self, forKey: .decisions) ?? [:]
        self.init(decisions: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(decisions, forKey: .decisions)
    }

    private static func canonicalDecisions(_ raw: [String: Decision]) -> [String: Decision] {
        raw.reduce(into: [:]) { result, entry in
            guard let origin = canonicalOrigin(for: URL(string: entry.key)),
                  entry.value != .default else { return }
            result[origin] = entry.value
        }
    }

    public func decision(for url: URL?) -> Decision {
        guard let origin = Self.canonicalOrigin(for: url) else { return .default }
        return decisions[origin] ?? .default
    }

    public func setting(_ decision: Decision, for url: URL?) -> HostContextPolicy? {
        guard let origin = Self.canonicalOrigin(for: url) else { return nil }
        var updated = decisions
        if decision == .default {
            updated.removeValue(forKey: origin)
        } else {
            updated[origin] = decision
        }
        return HostContextPolicy(decisions: updated)
    }

    public func effectiveState(
        for url: URL?,
        isPrivateBrowsing: Bool,
        sessionAllowsPageContext: Bool
    ) -> EffectiveState {
        guard let url, Self.canonicalOrigin(for: url) != nil else { return .unavailable }
        guard !isPrivateBrowsing else { return .privateBrowsing }
        guard sessionAllowsPageContext else { return .blocked }
        switch decision(for: url) {
        case .default: return .default
        case .allow: return .allowed
        case .block: return .blocked
        }
    }

    public func shouldAdmitPage(
        url: URL?,
        isPrivateBrowsing: Bool,
        sessionAllowsPageContext: Bool
    ) -> Bool {
        switch effectiveState(
            for: url,
            isPrivateBrowsing: isPrivateBrowsing,
            sessionAllowsPageContext: sessionAllowsPageContext
        ) {
        case .default, .allowed:
            return true
        case .blocked, .privateBrowsing, .unavailable:
            return false
        }
    }

    /// Canonical `scheme://host[:non-default-port]` for a web origin.
    /// Credentials and all URL content below the authority are rejected or
    /// discarded; callers can never persist a path/query/fragment by mistake.
    public static func canonicalOrigin(for url: URL?) -> String? {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty,
              url.user == nil,
              url.password == nil else { return nil }

        let normalizedHost = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !normalizedHost.isEmpty else { return nil }

        let defaultPort = scheme == "http" ? 80 : 443
        let port = url.port.flatMap { $0 == defaultPort ? nil : $0 }
        var components = URLComponents()
        components.scheme = scheme
        components.host = normalizedHost
        components.port = port
        return components.string
    }
}
