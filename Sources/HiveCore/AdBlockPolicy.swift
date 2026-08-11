import Foundation

// MARK: - AdBlockPolicy
//
// Pure, dependency-free helpers for the ad-blocking surface so the policy can
// be unit-tested in HiveCore without booting CEF or loading the Rust dylib.
// The app target (AdblockEngine + BrowserState) applies these builders to the
// live browser; HiveCoreTests locks the wire formats.

public enum AdBlockPolicy {

    /// Converts plain hostnames into CDP `Network.setBlockedURLs` URL
    /// patterns. Each host yields two patterns — the bare host and any
    /// subdomain — across every scheme (`*://`). Empty entries are dropped;
    /// hosts are lowercased to match Chrome's URL normalization.
    ///
    /// Example: `["DoubleClick.Net"]` → `["*://*.doubleclick.net/*",
    /// "*://doubleclick.net/*"]`.
    public static func cdpURLPatterns<S: Sequence>(for domains: S) -> [String]
        where S.Element == String {
        var patterns: [String] = []
        var seen = Set<String>()
        for entry in domains {
            guard let host = normalizedHost(entry),
                  seen.insert(host).inserted else { continue }
            patterns.append("*://*.\(host)/*")
            patterns.append("*://\(host)/*")
        }
        return patterns
    }

    /// Builds a self-guarding, navigation-safe JS snippet that hides the given
    /// CSS selectors by injecting a `<style>` element. Returns nil when there
    /// is nothing to hide (callers then skip the injection entirely).
    ///
    /// The guard flag (`__hiveAdBlockCosmeticInstalled`) makes re-injection per
    /// navigation safe, matching the pattern used by the media/link probes.
    /// Selector text is escaped so a hostile selector can never break out of
    /// the injected script.
    public static func cosmeticHideScript(selectors: [String]) -> String? {
        let cleaned = selectors.map { jsEscaped($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }
        let joined = cleaned.joined(separator: ", ")
        return """
        (function(){
          if (window.__hiveAdBlockCosmeticInstalled) return;
          window.__hiveAdBlockCosmeticInstalled = true;
          var css = "\(joined) { display: none !important; }";
          var style = document.createElement('style');
          style.id = 'hive-adblock-cosmetic';
          style.textContent = css;
          (document.head || document.documentElement).appendChild(style);
        })();
        """
    }

    /// Escapes text for safe interpolation inside a double-quoted JS string.
    /// Normalizes a hostname without accepting a scheme, path, or embedded
    /// whitespace. Filter lists sometimes carry DNS-style leading/trailing
    /// dots; stripping those here keeps both CDP patterns and IO-thread host
    /// matching consistent. A trailing DNS root dot on the request host is
    /// normalized the same way.
    private static func normalizedHost(_ value: String) -> String? {
        let host = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let forbidden = CharacterSet.whitespacesAndNewlines
            .union(.controlCharacters)
            .union(CharacterSet(charactersIn: "/:*?#\\\\"))
        guard !host.isEmpty,
              host.unicodeScalars.allSatisfy({ !forbidden.contains($0) }) else { return nil }
        return host
    }

    private static func jsEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    /// Subdomain-aware network-layer blocking decision. Returns true when
    /// `host` is a blocked domain or any subdomain of one
    /// (`ad.doubleclick.net` blocks for `doubleclick.net`). Lowercases both
    /// sides; trims and drops empty entries; a leading-dot suffix guard keeps
    /// `notdoubleclick.net` from colliding with `doubleclick.net`. Pure and
    /// lock-free — safe to call from the browser's IO thread.
    public static func shouldBlockNetworkHost<S: Sequence>(_ host: String?, domains: S) -> Bool
        where S.Element == String {
        guard let rawHost = host, let host = normalizedHost(rawHost) else { return false }
        for entry in domains {
            guard let domain = normalizedHost(entry) else { continue }
            if host == domain || host.hasSuffix("." + domain) { return true }
        }
        return false
    }
}
