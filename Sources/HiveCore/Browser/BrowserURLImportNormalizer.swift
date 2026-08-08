import Foundation

/// Canonical URL rules shared by browser bookmark and history imports.
/// External profile data is untrusted, so only navigable HTTP(S) URLs are admitted.
enum BrowserURLImportNormalizer {
    static func normalizedURL(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host != nil else { return nil }
        components.scheme = scheme
        components.host = components.host?.lowercased()
        components.user = nil
        components.password = nil
        components.fragment = nil
        if components.port == (scheme == "https" ? 443 : 80) {
            components.port = nil
        }
        if components.path == "/" {
            components.path = ""
        }
        return components.url
    }

    static func canonicalKey(_ url: URL) -> String? {
        normalizedURL(url)?.absoluteString
    }

    static func canonicalKey(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return canonicalKey(url)
    }
}
