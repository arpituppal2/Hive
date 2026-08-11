import Foundation

/// Pure policy for Chrome's "Always use secure connections" (HTTPS-Only) mode.
///
/// The browser has no CEF before-browse hook, so http→https upgrades can only
/// happen at the app-controlled navigation entry points (omnibox, floating
/// bar, chrome-opened links). Pages that still arrive over plaintext http —
/// usually in-page link clicks — surface a warning banner instead; this policy
/// decides both questions deterministically. Host exceptions use the shared
/// http(s) host-keying primitive, so the user's "allow plaintext" decisions
/// key exactly like per-site mute and zoom.
public enum HTTPSOnlyPolicy {

    /// Returns the https version of `url` when the mode is on, the URL is
    /// plaintext http, and its host is not excepted. Anything else returns
    /// nil, meaning "navigate as requested" (already-https, hive://, about:,
    /// excepted hosts).
    public static func upgraded(
        _ url: URL?,
        enabled: Bool,
        exceptions: Set<String>
    ) -> URL? {
        guard enabled,
              let url,
              url.scheme?.lowercased() == "http",
              let host = SiteMutePolicy.hostKey(for: url),
              !exceptions.contains(host)
        else { return nil }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "http"
        else { return nil }
        components.scheme = "https"
        return components.url
    }

    /// Whether a plaintext page should surface the HTTPS-Only warning banner:
    /// the mode is on, the page is http, and its host is not excepted. Computed
    /// from the scheme and exception set directly — a page is still plaintext
    /// (and must still warn) even when an upgrade URL can't be built for it.
    public static func shouldWarn(
        for url: URL?,
        enabled: Bool,
        exceptions: Set<String>
    ) -> Bool {
        guard enabled,
              let url,
              url.scheme?.lowercased() == "http",
              let host = SiteMutePolicy.hostKey(for: url),
              !exceptions.contains(host)
        else { return false }
        return true
    }
}
