import Foundation

/// Pure availability rules for commands that operate on a loaded web page.
///
/// Internal Hive pages, blank/new-tab surfaces, missing URLs, and unsupported
/// schemes are not web-page targets. Private HTTP(S) pages remain eligible:
/// privacy controls the data boundary, not ordinary browser affordances.
public enum BrowserPageActionPolicy {
    /// Returns true only for an HTTP(S) URL with a host.
    public static func canUseWebPageActions(for url: URL?) -> Bool {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host,
              !host.isEmpty else {
            return false
        }
        return true
    }
}
