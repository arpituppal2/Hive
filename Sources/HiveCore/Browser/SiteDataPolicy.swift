import Foundation

// MARK: - SiteDataPolicy
//
// Pure matching rules for per-site data deletion ("Delete data for this
// site", Chrome's per-site content-settings removal). History entries are
// matched through the shared http(s) www-stripped host key so the hub's
// stored host keys (e.g. "github.com") line up exactly with the URLs the
// user visited. Cookie domains are matched separately — CDP reports them
// with their own convention (optional leading dot, subdomain-covering).

public enum SiteDataPolicy {

    /// Whether a history URL belongs to the given site. Uses the shared
    /// www-stripped host key, so `https://www.example.com/page` matches the
    /// key `example.com` — and only that registrable domain, never subdomains
    /// (gist.github.com stays outside a "github.com" deletion, matching how
    /// every other per-site store in the app is keyed). Non-http(s) URLs
    /// (hive://, file://, about:blank) never match.
    public static func hostMatches(_ url: URL?, host: String) -> Bool {
        guard let key = SiteMutePolicy.hostKey(for: url) else { return false }
        return key == host
    }

    /// Whether a cookie's `domain` (as reported by CDP's `Network.getCookies`)
    /// covers the given host. Handles the CDP conventions: an optional
    /// leading dot (".example.com" == "example.com"), exact host matches, and
    /// subdomain coverage (a ".example.com" cookie applies to
    /// "mail.example.com"). The suffix check is dot-delimited so
    /// "notexample.com" never matches "example.com". Empty domains (session
    /// cookies without one) never match.
    public static func cookieDomainMatches(_ cookieDomain: String, host: String) -> Bool {
        let domain = cookieDomain.hasPrefix(".") ? String(cookieDomain.dropFirst()) : cookieDomain
        let normalizedDomain = domain.lowercased()
        let normalizedHost = host.lowercased()
        guard !normalizedDomain.isEmpty, !normalizedHost.isEmpty else { return false }
        if normalizedDomain == normalizedHost { return true }
        return normalizedHost.hasSuffix(".\(normalizedDomain)")
    }
}
