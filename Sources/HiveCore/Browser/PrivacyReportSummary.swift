import Foundation

// MARK: - PrivacyReportSummary

/// Measured content-blocking totals for the current in-memory tab set.
///
/// This is deliberately a value type with no persistence or telemetry behavior.
/// The browser currently records only a flat blocked-request count per tab, so
/// this model refuses to manufacture category attribution. Private tabs are
/// excluded at aggregation time because their browsing state is ephemeral.
public struct PrivacyReportSummary: Sendable, Equatable {
    public struct SiteCount: Sendable, Equatable, Identifiable {
        public let host: String
        public let count: Int

        public var id: String { host }

        public init(host: String, count: Int) {
            self.host = host
            self.count = count
        }
    }

    public let totalBlocked: Int
    public let topSites: [SiteCount]
    public let measuredTabCount: Int
    public let measuredSiteCount: Int

    init(totalBlocked: Int,
         topSites: [SiteCount],
         measuredTabCount: Int,
         measuredSiteCount: Int) {
        self.totalBlocked = max(0, totalBlocked)
        self.topSites = topSites
        self.measuredTabCount = max(0, measuredTabCount)
        self.measuredSiteCount = max(0, measuredSiteCount)
    }

    /// Aggregates only current, non-private tabs. Counts are clamped at zero
    /// so malformed or stale state cannot produce a negative report.
    public init(tabs: [BrowserTab], topSiteLimit: Int = 20) {
        let limit = max(0, topSiteLimit)
        var total = 0
        var sites: [String: Int] = [:]
        var measuredHosts = Set<String>()
        var measuredTabs = 0

        for tab in tabs where !tab.isPrivate {
            guard let host = Self.normalizedHost(for: tab.url) else { continue }
            measuredTabs += 1
            measuredHosts.insert(host)
            let count = max(0, tab.blockedCount)
            total += count
            guard count > 0 else { continue }
            sites[host, default: 0] += count
        }

        let sortedSites = sites
            .map { SiteCount(host: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.host < $1.host
            }

        self.totalBlocked = total
        self.topSites = Array(sortedSites.prefix(limit))
        self.measuredTabCount = measuredTabs
        self.measuredSiteCount = measuredHosts.count
    }

    private static func normalizedHost(for url: URL?) -> String? {
        guard let host = url?.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty else { return nil }
        let lowercased = host.lowercased()
        if lowercased.hasPrefix("www.") {
            let stripped = String(lowercased.dropFirst(4))
            return stripped.isEmpty ? nil : stripped
        }
        return lowercased
    }
}
