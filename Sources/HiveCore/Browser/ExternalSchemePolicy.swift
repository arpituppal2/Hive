import Foundation

/// Pure policy for Chrome's external-scheme handoff.
///
/// When a page links to `mailto:` or `tel:` (or `sms:`), the browser must not
/// try to render it — Chromium would show an error page for an unknown scheme
/// and a blank crash-prone load for a handled one. The default app (Mail,
/// FaceTime, Messages) should own it instead, exactly like Safari and Chrome.
///
/// CEF 148 exposes `on_before_browse` (via the browser-delegate navigation
/// policy), so the app can cancel these navigations and call `NSWorkspace`
/// before the load starts. This policy classifies a URL deterministically so
/// the decision is testable without any AppKit involvement.
public enum ExternalSchemePolicy {

    /// The three schemes handed to the OS. Kept explicit and minimal: schemes
    /// we don't recognize stay in the browser (a future handler can extend
    /// this list); `http(s)`, `hive:`, `about:`, and `javascript:` never reach
    /// a handoff path because they are already handled before this policy runs.
    public static let handoffSchemes: Set<String> = ["mailto", "tel", "sms"]

    /// Whether `url` must be handed to the OS rather than loaded in the
    /// browser. Requires a non-empty scheme in the handoff set — a bare
    /// `mailto:` with no recipient is still handed off (the default app shows
    /// its own empty-compose state, matching Chrome).
    public static func shouldHandOff(_ url: URL?) -> Bool {
        guard let url, let scheme = url.scheme?.lowercased() else { return false }
        return handoffSchemes.contains(scheme)
    }

    /// Convenience for callers that carry a raw string (bridge input,
    /// status-bar text). Empty or malformed input is never handed off.
    public static func shouldHandOff(string: String) -> Bool {
        shouldHandOff(URL(string: string))
    }
}
