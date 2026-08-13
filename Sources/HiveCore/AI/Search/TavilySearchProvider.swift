import Foundation

// MARK: - Tavily API wire models

/// Response shape for `POST https://api.tavily.com/search`.
private struct TavilySearchResponse: Decodable, Sendable {
    let answer: String?
    let query: String?
    let results: [TavilyResult]?
    let images: [TavilyImage]?
    let related_questions: [String]?
    let response_time: Double?

    struct TavilyResult: Decodable, Sendable {
        let title: String?
        let url: String?
        let content: String?
        let score: Double?
        let raw_content: String?
        let published_date: String?
    }

    struct TavilyImage: Decodable, Sendable {
        let url: String?
        let description: String?
    }
}

/// Request body for the Tavily Search API.
private struct TavilySearchRequest: Encodable, Sendable {
    let query: String
    let search_depth: String
    let include_answer: Bool
    let include_raw_content: Bool
    let max_results: Int
    let include_images: Bool
    let include_image_descriptions: Bool

    init(query: String, maxResults: Int = 10) {
        self.query = query
        self.search_depth = "advanced"
        self.include_answer = true
        self.include_raw_content = false
        self.max_results = maxResults
        self.include_images = false
        self.include_image_descriptions = false
    }
}

// MARK: - TavilySearchProvider

/// A `WebSearchProvider` backed by the Tavily Search API — purpose-built for
/// AI agents and RAG pipelines. Tavily offers a free tier (1,000 credits/month)
/// with built-in content extraction, making it an excellent always-available
/// cloud provider for the research pipeline.
///
/// API key is read from the `TAVILY_API_KEY` environment variable. The provider
/// reports unavailable when the key is missing, so the rest of the pipeline can
/// fall back to a self-hosted Vane instance or an honest mock.
public actor TavilySearchProvider: WebSearchProvider {

    public let displayName = "Tavily"

    private let apiKey: String
    private let urlSession: URLSession
    private let decoder: JSONDecoder

    private static let baseURL = URL(string: "https://api.tavily.com")!

    /// Creates a provider with an explicit API key. Prefer `init(envKey:)` for
    /// environment-variable configuration.
    public init(apiKey: String, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
    }

    /// Creates a provider that reads `TAVILY_API_KEY` from the process
    /// environment. Returns nil when the key is unavailable so callers can
    /// fall back to another provider.
    public init?(urlSession: URLSession = .shared) {
        guard let key = ProcessInfo.processInfo.environment["TAVILY_API_KEY"],
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        self.apiKey = key
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
    }

    public func isAvailable() async -> Bool {
        // A quick reachability check: query Tavily's health or just verify the
        // API key is non-empty. We avoid a round-trip here because each call
        // costs a credit on metered plans.
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func search(
        query: String,
        focusMode: WebSearchFocusMode = .webSearch
    ) async throws -> WebSearchResult {
        try await streamSearch(query: query, focusMode: focusMode) { _ in }
    }

    public func streamSearch(
        query: String,
        focusMode: WebSearchFocusMode = .webSearch,
        onUpdate: @escaping @MainActor (WebSearchStreamEvent) async -> Void
    ) async throws -> WebSearchResult {
        let request = try buildRequest(query: query, focusMode: focusMode)
        let (data, response) = try await urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw WebSearchError.unexpectedResponse
        }
        guard http.statusCode == 200 else {
            throw WebSearchError.httpStatus(http.statusCode)
        }

        let payload = try decoder.decode(TavilySearchResponse.self, from: data)
        let sources = payload.results?.enumerated().map { index, result in
            WebSearchSource(
                id: "tavily-\\(index + 1)",
                title: result.title ?? "Untitled source",
                url: result.url ?? "",
                date: result.published_date,
                snippet: result.content
            )
        } ?? []

        let answer = payload.answer ?? ""
        let related = payload.related_questions ?? []

        // Emit sources first so the UI can show citation cards before the
        // answer starts rendering.
        if !sources.isEmpty {
            await onUpdate(.sources(sources))
        }

        // Tavily returns a complete answer, not a stream. Emit it in one chunk
        // so the UI's streaming renderer handles it identically to Vane's
        // incremental chunks.
        if !answer.isEmpty {
            await onUpdate(.answerChunk(answer))
        }

        if !related.isEmpty {
            await onUpdate(.relatedQuestions(related))
        }

        return WebSearchResult(answer: answer, sources: sources, relatedQuestions: related)
    }

    // MARK: - Request building

    private func buildRequest(
        query: String,
        focusMode: WebSearchFocusMode
    ) throws -> URLRequest {
        let endpoint = Self.baseURL.appendingPathComponent("search")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \\(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body = TavilySearchRequest(query: query)
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
