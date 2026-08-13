import Foundation

// MARK: - AutofillMatcher
//
// Pure host-matching for saved-credential autofill. Chrome-style rule: a
// credential is offered on any host in the same registrable-domain family —
// a credential saved for "example.com" is offered on "login.example.com"
// and a credential saved for "accounts.example.com" is offered on
// "example.com". Without a public-suffix list, the family is approximated
// by "one domain is the other or a suffix of it"; sibling subdomains
// ("login.example.com" vs "gist.example.com") deliberately do NOT match.

/// The site+username surface the matcher needs. The password itself never
/// participates in matching and stays in the app layer.
public struct AutofillCandidate: Sendable, Equatable, Hashable {
    /// The normalized site the credential was saved for.
    public let site: String
    /// The username (or email) of the saved credential.
    public let username: String

    public init(site: String, username: String) {
        self.site = site
        self.username = username
    }
}

public enum AutofillMatcher {

    /// Returns the candidates whose saved site matches `host` under the
    /// Chrome-style rule above, preserving input order.
    public static func matches(
        forHost host: String,
        candidates: [AutofillCandidate]
    ) -> [AutofillCandidate] {
        let normalized = SitePermissionPolicy.normalizedHost(host)
        guard !normalized.isEmpty else { return [] }
        return candidates.filter { candidate in
            let site = SitePermissionPolicy.normalizedHost(candidate.site)
            guard !site.isEmpty else { return false }
            if site == normalized { return true }
            // Same registrable-domain family (either direction).
            return normalized.hasSuffix("." + site) || site.hasSuffix("." + normalized)
        }
    }
}
