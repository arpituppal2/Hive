import Foundation

/// Pure matching + injection-script building for site Boosts (Arc parity).
/// Deterministic and free of browser types so the contract is testable from
/// HiveCore. Injection is CSS-only via an idempotent `<style>` element — the
/// script never reads page content or touches scripts.
public enum BoostMatcher: Sendable {

    /// Whether a boost's host pattern applies to a URL's host.
    /// - "example.com" matches only that exact host.
    /// - ".example.com" matches the domain and any subdomain.
    /// Matching is case-insensitive; the pattern's whitespace is trimmed.
    public static func matches(boostHost: String, url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        let pattern = boostHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !pattern.isEmpty else { return false }
        if pattern.hasPrefix(".") {
            let domain = String(pattern.dropFirst())
            guard !domain.isEmpty else { return false }
            return host == domain || host.hasSuffix("." + domain)
        }
        return host == pattern
    }

    /// Builds the JS that installs a boost's CSS into the document. Returns
    /// nil for disabled or empty boosts — callers inject nothing.
    ///
    /// The script is idempotent: it removes any previous stylesheet carrying
    /// this boost's id, then installs a fresh one, so SPA navigations and
    /// re-injection never stack styles.
    ///
    /// Injection is CSP-safe: the primary path uses a constructable
    /// stylesheet via `CSSStyleSheet.replaceSync()` + `document.adoptedStyleSheets`,
    /// which is NOT subject to a page's `style-src` policy (strict sites like
    /// GitHub would silently drop a dynamically-inserted `<style>` element).
    /// A classic `<style>` element is only the fallback for contexts where
    /// constructable stylesheets are unavailable. Caveat: `replaceSync`
    /// rejects `@import` rules, so boost CSS containing `@import` takes the
    /// fallback path (where it works) — keep the fallback, it is load-bearing.
    public static func injectScript(boost: Boost) -> String? {
        guard boost.isEnabled, boost.hasUsableCSS else { return nil }
        let cssEscaped = boost.css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "</", with: "<\\/")
            .unicodeScalars.map { scalar -> String in
                // U+2028/U+2029 terminate JS string literals — escape them.
                switch scalar.value {
                case 0x2028: return "\\u2028"
                case 0x2029: return "\\u2029"
                default: return String(scalar)
                }
            }
            .joined()
        let elementID = "hive-boost-\(boost.id.uuidString)"
        return """
        (function(){
          var id = "\(elementID)";
          try {
            if (typeof CSSStyleSheet === "function" && document.adoptedStyleSheets) {
              var css = new CSSStyleSheet();
              css.replaceSync("\(cssEscaped)");
              css.__hiveBoostID = id;
              var sheets = Array.prototype.slice.call(document.adoptedStyleSheets);
              sheets = sheets.filter(function(s){ return !s.__hiveBoostID || s.__hiveBoostID !== id; });
              sheets.push(css);
              document.adoptedStyleSheets = sheets;
              return;
            }
          } catch (e) {}
          var old = document.getElementById(id);
          if (old) { old.remove(); }
          var el = document.createElement("style");
          el.id = id;
          el.textContent = "\(cssEscaped)";
          (document.head || document.documentElement).appendChild(el);
        })();
        """
    }
}
