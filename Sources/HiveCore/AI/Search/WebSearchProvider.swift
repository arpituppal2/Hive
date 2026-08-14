import Foundation

// MARK: - Web search provider protocol

/// Abstract interface for real-time web research. Implementations may be
/// self-hosted (Vane/Perplexica), remote APIs (Perplexity), or a local-only
/// mock for tests.
///
/// The protocol is `Sendable` so the `Dispatcher` can resolve it safely under Swift 6.
public protocol WebSearchProvider: Sendable {
    /// Human-readable provider name shown in the Swarm UI.
    var displayName: String { get }

    /// Whether the provider can be used right now (configured, reachable, etc.)
    func isAvailable() async -> Bool

    /// Performs a search and returns the full result. Use for one-shot
    /// research or when the UI does not need incremental updates.
    func search(query: String, focusMode: WebSearchFocusMode) async throws -> WebSearchResult

    /// Streams a search: first an list of sources, then answer chunks.
    /// The callback receives partial results; the caller can render them
    /// incrementally. Returns the final synthesized result when complete.
    func streamSearch(
        query: String,
        focusMode: WebSearchFocusMode,
        onUpdate: @escaping @MainActor (WebSearchStreamEvent) async -> Void
    ) async throws -> WebSearchResult
}

// MARK: - Stream events

/// Events emitted during a streaming web search. The UI maps these to a
/// progressively revealed answer with citations.
public enum WebSearchStreamEvent: Sendable {
    /// The search found `sources`. This is usually emitted once near the start.
    case sources([WebSearchSource])

    /// A new chunk of the synthesized answer. May contain inline citation
    /// markers such as `[1]`.
    case answerChunk(String)

    /// Related questions suggested by the provider.
    case relatedQuestions([String])

    /// Provider reported an error but may continue.
    case error(String)
}
