import Foundation

// MARK: - SiteSearchKeyword
//
// A Chrome-style omnibox keyword: typing `kw query` (e.g. `yt kittens`)
// searches that site's URL template instead of the default engine. The
// template uses the same `{query}` placeholder as custom search engines.

public struct SiteSearchKeyword: Sendable, Equatable {
    /// The short keyword the user types first (e.g. "yt", "w", "gh").
    public let keyword: String
    /// Display name for the site (e.g. "YouTube").
    public let name: String
    /// URL template with a literal `{query}` placeholder.
    public let template: String

    public init(keyword: String, name: String, template: String) {
        self.keyword = keyword
        self.name = name
        self.template = template
    }
}

// MARK: - SiteSearchKeywordPolicy
//
// Pure rules for keyword-prefixed omnibox input. Deterministic and
// unit-testable without any browser state.

public enum SiteSearchKeywordPolicy {

    /// Normalizes a user-typed keyword: trimmed, lowercased, no spaces.
    /// Returns nil when the result is unusable (empty, or contains spaces —
    /// a space would break the `keyword query` parsing).
    public static func normalizedKeyword(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        return trimmed
    }

    /// True when the input begins with a recognized keyword followed by a
    /// space (Chrome's `keyword query` form). A bare keyword with no query is
    /// NOT a keyword search — the user is probably typing the site's name.
    public static func keywordQuery(from raw: String, keywords: [SiteSearchKeyword]) -> (keyword: SiteSearchKeyword, query: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(" ") else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[1].isEmpty else { return nil }
        let first = String(parts[0]).lowercased()
        guard let match = keywords.first(where: { $0.keyword.lowercased() == first }) else { return nil }
        return (match, String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Builds the search URL for a keyword query, percent-encoding the query
    /// exactly like the shared search-URL builder (spaces → +).
    public static func searchURL(for query: String, keyword: SiteSearchKeyword) -> URL? {
        let encoded = query.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowedAllowed
        ) ?? query
        let urlString = keyword.template.replacingOccurrences(of: "{query}", with: encoded)
        return URL(string: urlString)
    }

    /// True when the template is usable: contains the `{query}` placeholder
    /// and parses as a URL when the placeholder is substituted.
    public static func isValidTemplate(_ template: String) -> Bool {
        guard template.contains("{query}") else { return false }
        let probe = template.replacingOccurrences(of: "{query}", with: "test")
        guard let url = URL(string: probe), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
