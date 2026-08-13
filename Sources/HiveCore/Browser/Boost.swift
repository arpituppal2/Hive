import Foundation

/// A site Boost (Arc parity): user-authored CSS applied to a host. Boosts are
/// pure CSS injected after page load — no JS, no network access, no page
/// content read. `host` is a hostname ("example.com") or a leading-dot
/// pattern (".example.com") that also matches subdomains.
public struct Boost: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    /// Hostname pattern: "example.com" matches exactly; ".example.com"
    /// matches the domain and its subdomains. Lowercased on entry.
    public var host: String
    public var name: String
    /// The user's CSS. Injected verbatim into a `<style>` element.
    public var css: String
    public var isEnabled: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        host: String,
        name: String = "",
        css: String = "",
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.name = name
        self.css = css
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    /// Whether the boost's host pattern is well-formed enough to match.
    public var hasValidHost: Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
        guard !body.isEmpty else { return false }
        // Hostnames: letters, digits, dots, hyphens; reject ports, paths, and spaces.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        return body.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Whether the boost has enough CSS to inject.
    public var hasUsableCSS: Bool {
        !css.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
