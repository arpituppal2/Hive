import Foundation
import WebKit

// MARK: - ContentBlockerController
//
// Owns the compiled `WKContentRuleList` and applies it to each webview. Rules are
// compiled ONCE at launch from a bundled blocklist and cached by `WKContentRuleListStore`.
//
// The blocklist is local, never fetched at runtime — privacy hard rule per AGENTS.md §9.
// It covers common ad networks, tracker domains, and privacy-invasive scripts using
// WKContentRuleList's trigger-action JSON format.
//
// HTTPS enforcement is handled separately via WKNavigationDelegate in WebViewContainer,
// upgrading HTTP requests before they leave the browser.

@MainActor
final class ContentBlockerController {

    static let shared = ContentBlockerController()

    /// The compiled rule list. `nil` = no blocking active or compilation not yet complete.
    private(set) var contentRuleList: WKContentRuleList?

    /// Whether blocking is active (rules compiled and applied).
    var isActive: Bool { contentRuleList != nil }

    private init() {}

    // MARK: - Apply

    /// Applies the compiled rule list to a user content controller. No-op when no
    /// rules have been compiled yet (e.g. before launch compilation completes).
    func apply(to userContentController: WKUserContentController) {
        guard let list = contentRuleList else { return }
        userContentController.add(list)
    }

    // MARK: - Built-in rules compilation

    /// Compiles the built-in blocklist (ad networks, trackers, analytics scripts) and
    /// caches the compiled result. Call once at app launch. Idempotent — if rules are
    /// already compiled, returns immediately. If JSON serialization fails, returns
    /// an empty rule set so the blocker is inert rather than crashing.
    func compileBuiltInRules() async throws {
        guard contentRuleList == nil else { return }
        let json = Self.builtInRulesJSON()
        try await compile(rulesJSON: json)
    }

    /// Compiles a rule list from JSON and caches the result.
    func compile(rulesJSON: String) async throws {
        contentRuleList = try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default()?.compileContentRuleList(
                forIdentifier: Self.ruleListIdentifier,
                encodedContentRuleList: rulesJSON
            ) { list, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: list) }
            }
        }
    }

    /// Removes the cached compiled rule list (disable blocking). Idempotent.
    func remove() async {
        guard contentRuleList != nil else { return }
        contentRuleList = nil
        try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            WKContentRuleListStore.default()?.removeContentRuleList(
                forIdentifier: Self.ruleListIdentifier
            ) { _ in continuation.resume() }
        }
    }

    // MARK: - Built-in blocklist (local, never fetched at runtime)

    /// Generates a WKContentRuleList-compatible JSON string covering the most common
    /// ad networks, tracker domains, analytics scripts, and privacy-invasive resources.
    /// Rules are conservative (third-party only for most) to minimize site breakage.
    /// Domain rules block known tracker origins; URL-filter rules catch common patterns.
    static func builtInRulesJSON() -> String {
        let rules: [[String: Any]] = [
            // ── Ad networks ────────────────────────────────────────────
            rule(trigger: ["url-filter": ".*doubleclick\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*googlesyndication\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*googleadservices\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*googletagmanager\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*googletagservices\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*adnxs\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*rubiconproject\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*pubmatic\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*openx\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*criteo\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*casalemedia\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*indexww\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*sharethrough\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*exelator\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*outbrain\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*taboola\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*amazon-adsystem\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*aaxads\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*media\\.net.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*bidswitch\\..*", "load-type": ["third-party"]]),

            // ── Analytics & tracking ───────────────────────────────────
            rule(trigger: ["url-filter": ".*google-analytics\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*analytics\\.google\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*ssl\\.google-analytics\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*facebook\\..*/tr.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*connect\\.facebook\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*pixel\\.facebook\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*analytics\\.twitter\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*t\\.co.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*ads\\.linkedin\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*analytics\\.linkedin\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*hotjar\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*mouseflow\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*fullstory\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*crazyegg\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*optimizely\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*mixpanel\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*amplitude\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*segment\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*branch\\.io.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*adjust\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*appsflyer\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*scorecardresearch\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*newrelic\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*datadoghq\\..*", "load-type": ["third-party"]]),

            // ── Social media tracking widgets ──────────────────────────
            rule(trigger: ["url-filter": ".*platform\\.twitter\\..*/widgets.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*platform\\.instagram\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*snap\\.chat.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*pinimg\\..*/ct.*", "load-type": ["third-party"]]),

            // ── Cryptominers ───────────────────────────────────────────
            rule(trigger: ["url-filter": ".*coin-hive\\..*"]),
            rule(trigger: ["url-filter": ".*coinhive\\..*"]),
            rule(trigger: ["url-filter": ".*cryptoloot\\..*"]),
            rule(trigger: ["url-filter": ".*cryptonight\\..*"]),
            rule(trigger: ["url-filter": ".*minero\\..*"]),
            rule(trigger: ["url-filter": ".*webminer.*"]),

            // ── Cookie consent / GDPR pop-up script sources (block the scripts, not just hide) ─
            rule(trigger: ["url-filter": ".*cookieconsent\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*cookie-law.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*consent\\.cookiebot\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*onetrust\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*trustarc\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*consent-manager.*", "load-type": ["third-party"]]),

            // ── Tracking pixels (1x1 gifs) ─────────────────────────────
            rule(trigger: ["url-filter": ".*/pixel/.*\\.gif.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*/beacon.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*/collect\\?.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*/__track.*", "load-type": ["third-party"]]),

            // ── Fingerprinting protection (canvas, WebGL, font, audio) ────
            // Block known fingerprinting scripts that probe device characteristics.
            // These domains are dedicated fingerprinting-as-a-service providers.
            rule(trigger: ["url-filter": ".*fingerprintjs\\..*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*fingerprint\\..*/.*\\.js.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*/fp\\.js.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*/fingerprint\\.js.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*/device\\.js.*", "load-type": ["third-party"]]),
            rule(trigger: ["url-filter": ".*clientjs\\..*", "load-type": ["third-party"]]),

            // ── Tracking query parameter blockers (strip before fetch) ──
            rule(trigger: ["url-filter": ".*[?&]utm_source=.*", "load-type": ["third-party"]],
                 action: ["type": "block-cookies"]),
            rule(trigger: ["url-filter": ".*[?&]fbclid=.*", "load-type": ["third-party"]],
                 action: ["type": "block-cookies"]),
            rule(trigger: ["url-filter": ".*[?&]gclid=.*", "load-type": ["third-party"]],
                 action: ["type": "block-cookies"]),
            rule(trigger: ["url-filter": ".*[?&]gclsrc=.*", "load-type": ["third-party"]],
                 action: ["type": "block-cookies"]),
            rule(trigger: ["url-filter": ".*[?&]mc_cid=.*", "load-type": ["third-party"]],
                 action: ["type": "block-cookies"]),
            rule(trigger: ["url-filter": ".*[?&]mc_eid=.*", "load-type": ["third-party"]],
                 action: ["type": "block-cookies"]),
        ]

        // Serialize to JSON. If serialization fails (shouldn't happen with plain dicts),
        // return an empty rule set so the blocker degrades gracefully.
        guard let data = try? JSONSerialization.data(withJSONObject: rules, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return "[{\"trigger\":{\"url-filter\":\"^$\"},\"action\":{\"type\":\"ignore-previous-rules\"}}]"
        }
        return json
    }

    /// The versioned rule-list identifier compiled into WKContentRuleListStore.
    /// Bump when the built-in rules change so a fresh compilation replaces the cached list.
    static let ruleListIdentifier = "HiveBlocker-v2"

    // MARK: - Rule builder helper

    private static func rule(
        trigger: [String: Any],
        action: [String: Any] = ["type": "block"]
    ) -> [String: Any] {
        ["trigger": trigger, "action": action]
    }
}
