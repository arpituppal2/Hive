import Foundation

/// Pure admission and metadata policy for tab context attached to an advisory
/// Swarm turn. Explicit @tab references are user intent, not permission.
public enum SwarmResponseContextPolicy {
    /// Returns true only when a referenced tab belongs to the same active
    /// profile/workspace and neither side is private. The browser state supplies
    /// identifiers; this type deliberately knows nothing about UI objects/CEF.
    public static func allowsReferencedTab(
        tabProfileID: String,
        tabWorkspaceID: String,
        currentProfileID: String,
        currentWorkspaceID: String,
        isPrivateBrowsing: Bool,
        tabIsPrivate: Bool,
        pageVisibility: HostContextPolicy.EffectiveState = .allowed
    ) -> Bool {
        guard !isPrivateBrowsing, !tabIsPrivate else { return false }
        guard pageVisibility == .default || pageVisibility == .allowed else { return false }
        guard tabProfileID == currentProfileID else { return false }
        guard tabWorkspaceID == currentWorkspaceID else { return false }
        return true
    }

    /// Returns a page title suitable for model metadata. Titles are web input,
    /// not trusted labels: they may contain prompt-injection text or copied
    /// secrets. Keep them short and apply the same credential redaction used by
    /// page context before they are appended to an advisory prompt.
    public static func redactedTitleString(_ rawTitle: String, maxCharacters: Int = 160) -> String {
        guard maxCharacters > 0 else { return "untitled" }
        let (redacted, _) = ContextRedactor.redactSecrets(rawTitle)
        let (bounded, _) = ContextRedactor.truncate(redacted, to: maxCharacters)
        // ContextRedactor keeps an explanatory elision marker and therefore
        // intentionally permits a small amount of overhead. Tab metadata has
        // a stricter contract: keep the final prompt field at or below its
        // declared budget even when the marker itself must be shortened.
        let strictlyBounded = String(bounded.prefix(maxCharacters))
        let trimmed = strictlyBounded.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "untitled" : trimmed
    }

    /// Returns a URL suitable for model metadata. Query strings and fragments
    /// frequently contain tokens, email addresses, document IDs, or tracking
    /// values, so they are omitted. Userinfo is also omitted rather than
    /// relying on callers to remember that a URL can contain credentials.
    ///
    /// The result intentionally preserves only scheme, host, and optional port.
    /// Paths can contain document IDs or other private identifiers, so they are
    /// omitted too. If the input is malformed, no URL is emitted.
    public static func redactedURLString(_ rawURL: String) -> String? {
        guard let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host,
              !host.isEmpty else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = url.port
        return components.string
    }
}
