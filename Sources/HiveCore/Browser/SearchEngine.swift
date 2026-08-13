import Foundation

// MARK: - SearchEngine
//
// Pure URL-construction logic for the omnibar. No network lives here — the omnibar takes the
// user's raw query, decides whether it's a URL or a search, and returns a `URL` to load.
// Keeping this in HiveCore (Foundation-only) means the resolution rules are unit-testable
// without WebView or SwiftUI, and the same logic drives the omnibar, the start-page search
// field, and tab-reopen.
//
// Default engine is Google, matching the product's Chromium/Chrome migration path. Users can choose another engine in Settings.
// Hive never auto-sends keystrokes to a remote suggest endpoint — address-bar suggestions
// are local (history/bookmarks) only (AGENTS.md §9 privacy: no remote suggest, no telemetry).
// This也是一种 "instantly usable" + privacy promise: typing works offline, no phoning home.

public enum SearchEngineKind: String, Sendable, Codable, CaseIterable {
    case duckduckgo
    case brave
    case google
    case startpage
    case ecosia
    case bing

    /// Human name shown in Settings + the "search with" hint.
    public var displayName: String {
        switch self {
        case .duckduckgo: return "DuckDuckGo"
        case .brave:      return "Brave Search"
        case .google:     return "Google"
        case .startpage:  return "Startpage"
        case .ecosia:      return "Ecosia"
        case .bing:        return "Bing"
        }
    }

    /// Search URL template with a literal `{query}` placeholder (percent-encoded by the
    /// caller via `SearchEngine.searchURL(for:)`).
    public var searchTemplate: String {
        switch self {
        case .duckduckgo: return "https://duckduckgo.com/?q={query}"
        case .brave:      return "https://search.brave.com/search?q={query}"
        case .google:     return "https://www.google.com/search?q={query}"
        case .startpage: return "https://www.startpage.com/sp/search?query={query}"
        case .ecosia:    return "https://www.ecosia.org/search?q={query}"
        case .bing:      return "https://www.bing.com/search?q={query}"
        }
    }

    /// Resolver for the persistent-pref stored string → kind (ChromeUserPrefs holds the
    /// display name; this maps it back to the case). Defaults to Google on unknown.
    public static func resolve(_ name: String) -> SearchEngineKind {
        SearchEngineKind.allCases.first { $0.displayName == name } ?? .google
    }
}

// MARK: - Omnibar query resolution

/// The typed result of interpreting omnibar input.
///
/// Keeping blocked input distinct from a search prevents dangerous schemes
/// from being silently sent to a search provider, while the browser target can
/// make one navigation decision from this value.
public enum OmnibarResolution: Sendable, Equatable {
    case empty
    case navigate(URL)
    case search(URL)
    case blocked(scheme: String)
}

public enum OmnibarInput {

    /// Classifies raw omnibar input without performing network or browser work.
    public static func resolve(_ raw: String, engine: SearchEngineKind = .google) -> OmnibarResolution {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        if let parsed = URL(string: trimmed), let rawScheme = parsed.scheme {
            let scheme = rawScheme.lowercased()
            if isAllowedDirectNavigation(parsed, scheme: scheme) {
                return .navigate(parsed)
            }
        }

        // Foundation parses `localhost:8080` as scheme="localhost". Check
        // host-shaped input before treating an explicit unknown scheme as
        // blocked so local development addresses remain usable.
        if looksLikeHost(trimmed), let url = URL(string: "https://" + trimmed) {
            return .navigate(url)
        }

        if let parsed = URL(string: trimmed), let rawScheme = parsed.scheme,
           trimmed.contains(":") {
            return .blocked(scheme: rawScheme.lowercased())
        }
        guard let search = SearchEngine.searchURL(for: trimmed, engine: engine) else {
            return .empty
        }
        return .search(search)
    }

    /// Decide what the user meant by `raw` and return the URL to load.
    ///
    /// Resolution rules (the switcher's mental model — Chrome/Safari parity):
    ///   1. Empty → nil (the start page handles it).
    ///   2. Looks like a URL (has a scheme, or is a bare host with a dot and no spaces) →
    ///      normalize to a full http(s) URL.
    ///   3. Otherwise → search with the given engine.
    ///
    /// "Looks like a URL" is deliberately conservative: a bare `apple.com` is a URL, but
    /// `apple macbook` (a space) is a search. `localhost:8080` and `127.0.0.1` are URLs.
    /// Scheme-prefixed inputs are honored only when their scheme is explicitly
    /// allowed by `navigableSchemes`; unsafe schemes are returned as `.blocked`.
    public static func resolveURL(for raw: String, engine: SearchEngineKind = .google) -> URL? {
        switch resolve(raw, engine: engine) {
        case .navigate(let url), .search(let url): return url
        case .empty, .blocked: return nil
        }
    }

    /// Schemes Hive can load directly from the omnibar. Local files, script/data
    /// URLs, and blob URLs are not address-bar capabilities; page-triggered
    /// resource handling is a separate, scoped engine concern.
    public static let navigableSchemes: Set<String> = [
        "http", "https", "about", "hive"
    ]

    /// The only internal routes that the omnibar may address directly. CEF
    /// pages can still use other app-owned routes through their dedicated
    /// bridge; accepting arbitrary `hive:` hosts from text input would widen
    /// the privileged surface accidentally.
    private static let allowedHiveHosts: Set<String> = [
        "start", "go-back", "proceed", "safe-browsing"
    ]

    private static func isAllowedDirectNavigation(_ url: URL, scheme: String) -> Bool {
        switch scheme {
        case "http", "https":
            return url.host != nil && url.user == nil && url.password == nil
        case "about":
            return url.absoluteString.lowercased() == "about:blank"
        case "hive":
            guard let host = url.host?.lowercased(), allowedHiveHosts.contains(host) else {
                return false
            }
            return url.user == nil && url.password == nil
        default:
            return false
        }
    }

    /// True if `s` should be treated as a web address, not a search query.
    public static func looksLikeHost(_ s: String) -> Bool {
        // Spaces → search query, never a host.
        if s.contains(" ") { return false }
        // localhost / loopback (no dot needed).
        let lower = s.lowercased()
        if lower == "localhost" || lower.hasPrefix("localhost:") { return true }
        if lower.hasPrefix("127.") || lower.hasPrefix("10.") ||
           lower.hasPrefix("192.168.") || lower.hasPrefix("169.254.") { return true }
        if lower.hasPrefix("[") && lower.contains("::") { return true } // IPv6 literal
        // Must contain a dot to look like a domain; reject single-word searches.
        guard s.contains(".") else { return false }
        // Trailing slash / path is fine. Reject obvious non-hosts (e.g. "3.14") by requiring
        // at least one alphabetic label segment — pure-numeric like "192.168.0.1" is caught
        // above; "3.14" has no alpha and isn't a domain.
        let hostPart = s.split(separator: "/").first ?? Substring(s)
        let labels = hostPart.split(separator: ":").first ?? hostPart   // strip port
        if let firstLabel = labels.split(separator: ".").first {
            return firstLabel.contains { $0.isLetter }
        }
        return false
    }
}

// MARK: - Search URL builder

public enum SearchEngine {

    /// Builds a search URL for a query + engine. Percent-encodes the query. The placeholder
    /// is replaced after encoding so `+`/`&` in the query can't corrupt the template.
    public static func searchURL(for query: String, engine: SearchEngineKind = .google) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Allow + as a literal space substitute + standard reserved encoding.
        let encoded = trimmed.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowedAllowed) ?? trimmed
        let urlString = engine.searchTemplate.replacingOccurrences(of: "{query}", with: encoded)
        return URL(string: urlString)
    }
}

// MARK: - Percent-encoding helper
//
// `.urlQueryAllowed` is too permissive (leaves `&` `=` unencoded, breaking query parsing
// for searches containing those chars). We allow alphanumerics + a safe subset, encode `+`
// as `%2B` (so it isn't read as space), and spaces as `+` — matching DuckDuckGo's idiom.

extension CharacterSet {
    /// Allowed unencoded inside a search query: alphanumeric, a few safe symbols, space (→ +).
    /// Internal (not private) so keyword search templates encode identically.
    static let urlQueryAllowedAllowed: CharacterSet = {
        var cs = CharacterSet.alphanumerics
        cs.insert(charactersIn: "-._~")        // unreserved per RFC 3986
        // Spaces get encoded separately; everything else goes percent-encoded.
        return cs
    }()
}
