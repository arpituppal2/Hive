import Foundation

// MARK: - Vane API wire models

/// Provider model returned by `GET /api/providers`.
private struct VaneProvider: Decodable, Sendable {
    let id: String
    let name: String?
    let chatModels: [VaneModel]
    let embeddingModels: [VaneModel]
}

/// A model entry inside a provider.
private struct VaneModel: Decodable, Sendable {
    let name: String?
    let key: String
}

private struct VaneProvidersResponse: Decodable, Sendable {
    let providers: [VaneProvider]
}

/// A single message in Vane's `history` array.
private struct VaneHistoryMessage: Encodable, Sendable {
    let role: String
    let content: String
}

/// Request body for `POST /api/search`.
private struct VaneSearchRequest: Encodable, Sendable {
    let chatModel: VaneModelRef
    let embeddingModel: VaneModelRef
    let optimizationMode: String
    let sources: [String]
    let query: String
    let history: [VaneHistoryMessage]
    let stream: Bool
    let systemInstructions: String
}

private struct VaneModelRef: Encodable, Sendable {
    let providerId: String
    let key: String
}

private struct VaneModelSelection: Sendable {
    let chat: VaneModelRef
    let embedding: VaneModelRef
}

/// Non-streaming response shape for `POST /api/search`.
private struct VaneSearchResponse: Decodable, Sendable {
    let message: String
    let sources: [VaneSourceWire]
}

/// A source as it appears on the wire (both streaming and non-streaming).
private struct VaneSourceWire: Decodable, Sendable {
    let content: String?
    let metadata: VaneSourceMetadata?

    struct VaneSourceMetadata: Decodable, Sendable {
        let title: String?
        let url: String?
    }

    func toWebSearchSource(id: String) -> WebSearchSource {
        WebSearchSource(
            id: id,
            title: metadata?.title ?? "Untitled source",
            url: metadata?.url ?? "",
            snippet: content
        )
    }
}

// MARK: - Stream events

/// Internal stream event representation. Kept internal (not private) so tests can exercise
/// the parser through `@testable import HiveCore`.
internal enum VaneStreamEvent: Equatable {
    case sources([WebSearchSource])
    case answer(String)
    case error(String)
    case end
    case unknown
}

// MARK: - Vane search provider

/// A `WebSearchProvider` backed by a self-hosted Vane (formerly Perplexica)
/// instance. Vane is MIT-licensed and exposes a streaming search API.
///
/// The provider discovers the default chat and embedding models from `/api/providers`
/// so the user only needs to supply a base URL. It then calls `POST /api/search`
/// with the exact request shape Vane expects and parses the newline-delimited JSON
/// stream (`init`, `sources`, `response`, `done`).
public actor VaneSearchProvider: WebSearchProvider {

    public let displayName = "Vane"

    private let baseURL: URL
    private let urlSession: URLSession
    private let decoder = JSONDecoder()

    /// Creates a provider pointing at a Vane instance.
    /// - Parameter baseURL: e.g. `http://localhost:3000`.
    public init(baseURL: URL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    /// Checks reachability by asking Vane for its provider roster.
    public func isAvailable() async -> Bool {
        do {
            let providers = try await fetchProviders()
            return providers.contains { provider in
                !provider.chatModels.isEmpty && !provider.embeddingModels.isEmpty
            }
        } catch {
            return false
        }
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
        let models = try await resolveDefaultModels()
        let request = try buildRequest(query: query, focusMode: focusMode, models: models, stream: true)
        return try await performStream(request: request, onUpdate: onUpdate)
    }

    // MARK: - Discovery

    private func fetchProviders() async throws -> [VaneProvider] {
        let url = try Self.endpointURL(baseURL: baseURL, path: "api/providers")
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WebSearchError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let envelope = try decoder.decode(VaneProvidersResponse.self, from: data)
        return envelope.providers
    }

    /// Picks the first available chat model and first available embedding model from the
    /// provider roster. Vane requires both to be explicitly supplied in every search request.
    private func resolveDefaultModels() async throws -> VaneModelSelection {
        let providers = try await fetchProviders()
        guard let chatProvider = providers.first(where: { !$0.chatModels.isEmpty }),
              let chatModel = chatProvider.chatModels.first,
              let embeddingProvider = providers.first(where: { !$0.embeddingModels.isEmpty }),
              let embeddingModel = embeddingProvider.embeddingModels.first else {
            throw WebSearchError.unexpectedResponse
        }
        return VaneModelSelection(
            chat: VaneModelRef(providerId: chatProvider.id, key: chatModel.key),
            embedding: VaneModelRef(providerId: embeddingProvider.id, key: embeddingModel.key)
        )
    }

    // MARK: - Request building

    private func buildRequest(
        query: String,
        focusMode: WebSearchFocusMode,
        models: VaneModelSelection,
        stream: Bool
    ) throws -> URLRequest {
        let endpoint = try Self.endpointURL(baseURL: baseURL, path: "api/search")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120

        let body = VaneSearchRequest(
            chatModel: models.chat,
            embeddingModel: models.embedding,
            optimizationMode: "balanced",
            sources: sources(for: focusMode),
            query: query,
            history: [],
            stream: stream,
            systemInstructions: ""
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// Builds a Vane endpoint without allowing Foundation's relative-URL
    /// resolution to discard the final component of a base path. For example,
    /// `http://localhost:3000/v1` must resolve to `/v1/api/search`, not
    /// `/api/search`. Query strings, fragments, credentials, and non-HTTP
    /// schemes are not part of a service endpoint and fail closed.
    internal static func endpointURL(baseURL: URL, path: String) throws -> URL {
        // Keep this an allowlist, not a shape check. Relative URL resolution
        // treats dot segments and repeated separators specially, so accepting
        // any two-component path would make this boundary fragile if a future
        // caller ever passed user-controlled endpoint text.
        guard path == "api/providers" || path == "api/search",
              let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            throw WebSearchError.invalidBaseURL
        }

        // Compose the complete path directly instead of feeding the endpoint
        // through URL(string:relativeTo:). A configured `/v1` base therefore
        // stays `/v1/api/search`, and no `..` or separator normalization can
        // escape the configured service path.
        let basePath = components.percentEncodedPath
        let normalizedEncodedPath = basePath.lowercased()
        let baseSegments = components.path.split(separator: "/", omittingEmptySubsequences: true)
        guard !basePath.contains("//"),
              !normalizedEncodedPath.contains("%2f"),
              !normalizedEncodedPath.contains("%2e"),
              !baseSegments.contains("."),
              !baseSegments.contains("..") else {
            throw WebSearchError.invalidBaseURL
        }

        var endpointComponents = components
        let trimmedBasePath = basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        endpointComponents.percentEncodedPath = trimmedBasePath.isEmpty
            ? "/\(path)"
            : "/\(trimmedBasePath)/\(path)"
        guard let endpoint = endpointComponents.url else {
            throw WebSearchError.invalidBaseURL
        }
        return endpoint
    }

    /// Maps Hive's UI focus modes to the `sources` array Vane understands.
    /// Allowed Vane source values are: web, academic, discussions.
    private func sources(for focusMode: WebSearchFocusMode) -> [String] {
        switch focusMode {
        case .webSearch, .writingAssistant, .wolframAlpha, .youtubeSearch:
            return ["web"]
        case .academicSearch:
            return ["academic"]
        case .redditSearch:
            return ["discussions"]
        }
    }

    // MARK: - Streaming

    /// Vane streams newline-delimited JSON events. We read line-by-line using
    /// `URLSession.AsyncBytes.lines` and tolerate both raw JSON lines and
    /// SSE-wrapped (`data: ...`) lines. Each non-empty line is parsed independently.
    private func performStream(
        request: URLRequest,
        onUpdate: @escaping @MainActor (WebSearchStreamEvent) async -> Void
    ) async throws -> WebSearchResult {
        var result = WebSearchResult()

        let (bytes, response) = try await urlSession.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebSearchError.unexpectedResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw WebSearchError.httpStatus(httpResponse.statusCode)
        }

        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Some proxies wrap each JSON event as `data: {...}`. Strip that prefix.
            let payload: String
            if trimmed.hasPrefix("data:") {
                payload = trimmed.dropFirst("data:".count)
                    .trimmingCharacters(in: .whitespaces)
            } else {
                payload = trimmed
            }
            guard let data = payload.data(using: .utf8) else { continue }

            let event = VaneSearchProvider.parseStreamEvent(data)
            switch event {
            case .sources(let sources):
                result.sources = sources
                await onUpdate(.sources(sources))

            case .answer(let chunk):
                result.answer.append(chunk)
                await onUpdate(.answerChunk(chunk))

            case .error(let message):
                await onUpdate(.error(message))

            case .end:
                return result

            case .unknown:
                break
            }
        }

        return result
    }

    // MARK: - Parsing

    /// Parses a single newline-delimited JSON line from Vane's stream. Exposed internally
    /// so the test target can verify parsing without standing up a full HTTP server.
    internal static func parseStreamEvent(_ data: Data) -> VaneStreamEvent {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else {
            return .unknown
        }

        switch type {
        case "init":
            return .unknown

        case "sources":
            let sources = parseSources(object["data"])
            return .sources(sources)

        case "response":
            let chunk = (object["data"] as? String) ?? ""
            return .answer(chunk)

        case "done", "end":
            return .end

        case "error":
            let message = (object["data"] as? String)
                ?? (object["message"] as? String)
                ?? "Unknown Vane error"
            return .error(message)

        default:
            return .unknown
        }
    }

    private static func parseSources(_ value: Any?) -> [WebSearchSource] {
        guard let array = value as? [[String: Any]] else { return [] }
        return array.enumerated().compactMap { index, dict in
            guard let metadata = dict["metadata"] as? [String: Any] else { return nil }
            let title = metadata["title"] as? String
            let url = metadata["url"] as? String
            let content = dict["content"] as? String
            return WebSearchSource(
                id: "source-\(index + 1)",
                title: title ?? "Untitled source",
                url: url ?? "",
                snippet: content
            )
        }
    }
}

// MARK: - Errors

public enum WebSearchError: Error, Equatable {
    case invalidBaseURL
    case unexpectedResponse
    case httpStatus(Int)
    case malformedPayload
}
