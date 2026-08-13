import Foundation

/// Pure keying for persistent per-site audio mute (Safari/Chrome "Mute Site").
///
/// A "site" is the registrable-style host: http/https only, lowercased, with a
/// leading `www.` stripped — the same convention the per-site zoom uses, so
/// both remember one domain regardless of how the user typed it. Non-http
/// pages (internal `hive://` chrome, `about:blank`, local files) never carry a
/// durable site key.
public enum SiteMutePolicy {

    /// Returns the durable host key for a URL, or nil when the URL is not an
    /// http(s) page. `https://WWW.GitHub.com/a` and `http://github.com/b`
    /// both key as `github.com`.
    public static func hostKey(for url: URL?) -> String? {
        guard let url,
              let host = url.host?.lowercased(),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        if host.hasPrefix("www.") { return String(host.dropFirst(4)) }
        return host
    }

    /// Whether a URL belongs to the given site key — used to find every open
    /// tab on a muted host when the mute is toggled.
    public static func matchesHost(_ url: URL?, host: String) -> Bool {
        hostKey(for: url) == host
    }
}
