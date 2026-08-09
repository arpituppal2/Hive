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
        for entry in domains {
            let host = entry
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !host.isEmpty else { continue }
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
    private static func jsEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// Subdomain-aware network-layer blocking decision. Returns true when
    /// `host` is a blocked domain or any subdomain of one
    /// (`ad.doubleclick.net` blocks for `doubleclick.net`). Lowercases both
    /// sides; trims and drops empty entries; a leading-dot suffix guard keeps
    /// `notdoubleclick.net` from colliding with `doubleclick.net`. Pure and
    /// lock-free — safe to call from the browser's IO thread.
    public static func shouldBlockNetworkHost<S: Sequence>(_ host: String?, domains: S) -> Bool
        where S.Element == String {
        guard let host else { return false }
        let lowered = host.lowercased()
        for entry in domains {
            let domain = entry
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !domain.isEmpty else { continue }
            if lowered == domain || lowered.hasSuffix("." + domain) { return true }
        }
        return false
    }
}
