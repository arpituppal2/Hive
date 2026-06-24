import Foundation

/// A single piece of retrieved web context with its source attribution.
public struct WebSearchResult: Codable, Hashable, Sendable {
    /// The snippet of text retrieved from the source.
    public var text: String
    /// The URL the snippet was retrieved from.
    public var sourceURL: String

    public init(text: String, sourceURL: String) {
        self.text = text
        self.sourceURL = sourceURL
    }
}

/// A lightweight web retrieval pipeline backed by the DuckDuckGo Instant Answer
/// API. The engine decomposes a query into concise sub-queries, fetches each
/// concurrently, and renders the aggregated results into an injectable context
/// block. It depends only on Foundation/URLSession.
public struct WebRetrievalEngine: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Words removed during decomposition because they carry little search signal.
    private static let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "for",
        "with", "is", "are", "was", "were", "be", "been", "being", "do", "does",
        "did", "can", "could", "would", "should", "will", "shall", "about",
        "please", "tell", "me", "what", "whats", "who", "whos", "how", "when",
        "where", "why", "which", "this", "that", "these", "those", "at", "by",
        "from", "as", "it", "its"
    ]

    /// First-person pronouns stripped during decomposition.
    private static let firstPersonPronouns: Set<String> = [
        "i", "i'm", "im", "my", "mine", "me", "we", "we're", "were", "our",
        "ours", "us"
    ]

    /// Deterministically decomposes a query into 1–3 concise sub-queries.
    ///
    /// The query is split on sentence/clause boundaries, stripped of stopwords
    /// and first-person pronouns, trimmed to 3–7 words, and de-duplicated. If
    /// the original query is already short (<= 7 words) the trimmed query is
    /// returned unchanged. This function never touches disk.
    public func decompose(query: String, maxSubQueries: Int = 3) -> [String] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let wordCount = trimmedQuery.split(whereSeparator: { $0.isWhitespace }).count
        if wordCount <= 7 {
            return [trimmedQuery]
        }

        let limit = max(1, min(maxSubQueries, 3))

        // Split into candidate clauses on common delimiters.
        let clauseSeparators = CharacterSet(charactersIn: ".?!;,\n")
        let rawClauses = trimmedQuery
            .components(separatedBy: clauseSeparators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let clauses = rawClauses.isEmpty ? [trimmedQuery] : rawClauses

        var subQueries: [String] = []
        for clause in clauses {
            let condensed = Self.condense(clause)
            guard !condensed.isEmpty else { continue }
            if !subQueries.contains(condensed) {
                subQueries.append(condensed)
            }
            if subQueries.count >= limit { break }
        }

        // Fallback: if condensing produced nothing useful, take the leading
        // keywords from the full query.
        if subQueries.isEmpty {
            let condensed = Self.condense(trimmedQuery)
            if !condensed.isEmpty {
                subQueries.append(condensed)
            } else {
                subQueries.append(trimmedQuery)
            }
        }

        return subQueries
    }

    /// Reduces a clause to a concise 3–7 keyword phrase.
    private static func condense(_ clause: String) -> String {
        let tokens = clause
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        var keywords: [String] = []
        for token in tokens {
            if Self.firstPersonPronouns.contains(token) { continue }
            if Self.stopwords.contains(token) { continue }
            keywords.append(token)
            if keywords.count >= 7 { break }
        }

        // Guarantee at least a couple of keywords when possible by falling back
        // to non-pronoun tokens if stopword filtering was too aggressive.
        if keywords.count < 3 {
            for token in tokens where !Self.firstPersonPronouns.contains(token) {
                if !keywords.contains(token) {
                    keywords.append(token)
                }
                if keywords.count >= 7 { break }
            }
        }

        return keywords.prefix(7).joined(separator: " ")
    }

    /// Performs a single DuckDuckGo Instant Answer lookup for a sub-query.
    public func search(subQuery: String) async throws -> [WebSearchResult] {
        let trimmed = subQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=?+")
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed
        let urlString = "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(InstantAnswerResponse.self, from: data)

        if let abstract = response.AbstractText,
           !abstract.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [WebSearchResult(text: abstract, sourceURL: response.AbstractURL ?? "")]
        }

        let related = response.RelatedTopics ?? []
        var results: [WebSearchResult] = []
        for topic in related {
            // Some related topics are disambiguation groups containing nested
            // topics; flatten those before extracting text.
            let candidates: [RelatedTopic]
            if let nested = topic.Topics, !nested.isEmpty {
                candidates = nested
            } else {
                candidates = [topic]
            }
            for candidate in candidates {
                guard let text = candidate.Text,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }
                results.append(WebSearchResult(text: text, sourceURL: candidate.FirstURL ?? ""))
                if results.count >= 3 { break }
            }
            if results.count >= 3 { break }
        }

        return Array(results.prefix(3))
    }

    /// Retrieves web context for a query by decomposing it and fetching all
    /// sub-queries concurrently. Each sub-query that throws or exceeds
    /// `perRequestTimeout` contributes no results. This method never throws and
    /// returns an empty array on total failure.
    public func retrieve(for query: String, perRequestTimeout: TimeInterval = 2.5) async -> [WebSearchResult] {
        let subQueries = decompose(query: query)
        guard !subQueries.isEmpty else { return [] }

        var aggregated: [WebSearchResult] = []
        await withTaskGroup(of: [WebSearchResult].self) { group in
            for subQuery in subQueries {
                group.addTask {
                    await self.searchSafely(subQuery: subQuery, timeout: perRequestTimeout)
                }
            }
            for await partial in group {
                aggregated.append(contentsOf: partial)
            }
        }

        // De-duplicate by source URL while preserving first-seen order.
        var seen: Set<String> = []
        var deduped: [WebSearchResult] = []
        for result in aggregated {
            if seen.insert(result.sourceURL).inserted {
                deduped.append(result)
            }
        }
        return deduped
    }

    /// Wraps `search` so that any error or timeout resolves to an empty result.
    private func searchSafely(subQuery: String, timeout: TimeInterval) async -> [WebSearchResult] {
        do {
            return try await withThrowingTaskGroup(of: [WebSearchResult].self) { group in
                group.addTask {
                    try await self.search(subQuery: subQuery)
                }
                group.addTask {
                    let nanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanoseconds)
                    throw WebRetrievalError.timedOut
                }
                // Take the first task to finish (either results or the timeout).
                let result = try await group.next() ?? []
                group.cancelAll()
                return result
            }
        } catch {
            return []
        }
    }

    /// Renders results into the spec's injection format.
    public func contextBlocks(from results: [WebSearchResult]) -> String {
        results
            .map { "[WEB: \($0.sourceURL)]\n\($0.text)\n[/WEB]" }
            .joined(separator: "\n\n")
    }

    private enum WebRetrievalError: Error {
        case timedOut
    }

    // MARK: - DuckDuckGo response model

    private struct InstantAnswerResponse: Decodable {
        var AbstractText: String?
        var AbstractURL: String?
        var RelatedTopics: [RelatedTopic]?
    }

    private struct RelatedTopic: Decodable {
        var Text: String?
        var FirstURL: String?
        var Topics: [RelatedTopic]?
    }
}
