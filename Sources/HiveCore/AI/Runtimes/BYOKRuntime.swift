import Foundation

/// BYOK remote runtime. Real HTTP via URLSession (no extra dependency —
/// URLSession ships with Foundation). Posts to a LiteLLM-compatible
/// /chat/completions endpoint using a key held in Keychain (KeychainStore,
/// added next), referenced by alias — never pasted into config or source.
///
/// This is the *add-on*, never the baseline. The Dispatcher only routes here
/// when (a) the user has explicitly opted into BYOK for a role and (b) a key is
/// present. Otherwise it routes to local MLX / Apple FMF / honest Mock.
public struct BYOKRuntime: ModelRuntime, StreamingModelRuntime {

    /// Roles the BYOK runtime is allowed to serve. `byokFrontier` is the primary
    /// user-facing opt-in role; the other reasoning/coding roles may also be
    /// routed to BYOK when the user has explicitly enabled remote generation.
    public static let supportedRoles: Set<ModelRole> = [
        .byokFrontier, .deepReasoner, .researchSynthesizer, .coder, .planner, .orchestrator
    ]

    public struct Config: Sendable {
        /// LiteLLM-style base URL, e.g. "https://integrate.api.nvidia.com/v1".
        public let baseURL: URL
        /// Keychain alias resolving to the real API key. Never the key itself.
        public let apiKeyAlias: String
        /// Per-model model id to request from the gateway (e.g. "deepseek-v4-pro").
        public let modelID: String
        public let requestsPerMinute: Int
        public init(baseURL: URL, apiKeyAlias: String, modelID: String,
                    requestsPerMinute: Int = 35) {
            self.baseURL = baseURL; self.apiKeyAlias = apiKeyAlias
            self.modelID = modelID; self.requestsPerMinute = requestsPerMinute
        }
    }

    public let roles: Set<ModelRole>
    public let config: Config?
    /// Injected key resolver — production wires this to KeychainStore so no key
    /// ever lives in HiveCore. Tests inject a closure.
    public let keyResolver: @Sendable (String) async -> String?
    /// Injectable transport keeps production on URLSession while making stream
    /// behavior deterministic and cancellation-testable without a live service.
    /// The closure returns already-framed lines, matching URLSession.AsyncBytes.lines.
    public typealias StreamTransport = @Sendable (
        URLRequest
    ) async throws -> (AsyncThrowingStream<String, Error>, HTTPURLResponse)

    private let urlSession: URLSession
    private let streamTransport: StreamTransport?

    public init(roles: Set<ModelRole> = BYOKRuntime.supportedRoles,
                config: Config?,
                keyResolver: @escaping @Sendable (String) async -> String?,
                urlSession: URLSession = .shared,
                streamTransport: StreamTransport? = nil) {
        self.roles = roles.intersection(BYOKRuntime.supportedRoles)
        self.config = config
        self.keyResolver = keyResolver
        self.urlSession = urlSession
        self.streamTransport = streamTransport
    }

    public func isAvailable() async -> Bool {
        guard let config else { return false }
        return await keyResolver(config.apiKeyAlias) != nil
    }

    public func generate(_ request: GenerateRequest) async throws -> GenerateResult {
        guard roles.contains(request.role) else {
            throw InferenceError.roleUnsupported(request.role)
        }
        guard let config else { throw InferenceError.byokNotConfigured(role: request.role) }
        guard let key = await keyResolver(config.apiKeyAlias) else {
            throw InferenceError.byokNotConfigured(role: request.role)
        }

        let req = try buildRequest(for: request, config: config, key: key, stream: false)
        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw InferenceError.generationFailed("BYOK HTTP \(code)")
        }
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        let text = decoded.choices.first?.message.content ?? ""

        return GenerateResult(
            role: request.role, provider: .byokRemote, text: text,
            latencyMS: 0, tokensGenerated: text.split(separator: " ").count,
            modelLabel: config.modelID)
    }

    /// Streams token deltas from a LiteLLM/OpenAI-compatible `/chat/completions`
    /// endpoint. Yields content chunks as they arrive; finishes when the stream
    /// ends or `[DONE]` is received.
    public func generateStream(_ request: GenerateRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard self.roles.contains(request.role) else {
                        throw InferenceError.roleUnsupported(request.role)
                    }
                    guard let config = self.config else {
                        throw InferenceError.byokNotConfigured(role: request.role)
                    }
                    guard let key = await self.keyResolver(config.apiKeyAlias) else {
                        throw InferenceError.byokNotConfigured(role: request.role)
                    }

                    let req = try self.buildRequest(for: request, config: config, key: key, stream: true)
                    if let streamTransport = self.streamTransport {
                        let (lines, response) = try await streamTransport(req)
                        guard (200..<300).contains(response.statusCode) else {
                            throw InferenceError.generationFailed("BYOK HTTP \(response.statusCode)")
                        }
                        var malformedFrames = 0
                        var sawValidFrame = false
                        streamLoop: for try await line in lines {
                            switch try Self.consumeSSELine(line, continuation: continuation) {
                            case .done:
                                break streamLoop
                            case .valid:
                                sawValidFrame = true
                            case .malformed:
                                malformedFrames += 1
                                if malformedFrames >= 3 {
                                    throw InferenceError.generationFailed("BYOK malformed SSE response")
                                }
                            case .ignored:
                                continue
                            }
                        }
                        if malformedFrames > 0 && !sawValidFrame {
                            throw InferenceError.generationFailed("BYOK malformed SSE response")
                        }
                        guard sawValidFrame else {
                            throw InferenceError.generationFailed("BYOK empty SSE response")
                        }
                    } else {
                        let (bytes, response) = try await self.urlSession.bytes(for: req)
                        guard let http = response as? HTTPURLResponse,
                              (200..<300).contains(http.statusCode) else {
                            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                            throw InferenceError.generationFailed("BYOK HTTP \(code)")
                        }
                        var malformedFrames = 0
                        var sawValidFrame = false
                        streamLoop: for try await line in bytes.lines {
                            switch try Self.consumeSSELine(line, continuation: continuation) {
                            case .done:
                                break streamLoop
                            case .valid:
                                sawValidFrame = true
                            case .malformed:
                                malformedFrames += 1
                                if malformedFrames >= 3 {
                                    throw InferenceError.generationFailed("BYOK malformed SSE response")
                                }
                            case .ignored:
                                continue
                            }
                        }
                        if malformedFrames > 0 && !sawValidFrame {
                            throw InferenceError.generationFailed("BYOK malformed SSE response")
                        }
                        guard sawValidFrame else {
                            throw InferenceError.generationFailed("BYOK empty SSE response")
                        }
                    }
                    continuation.finish()
                } catch {
                    // URLSession may surface cancellation as URLError(.cancelled)
                    // rather than CancellationError. Both are normal user stops,
                    // never provider failures.
                    if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private enum SSELineResult {
        case ignored
        case valid
        case done
        case malformed
    }

    private static func consumeSSELine(
        _ line: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) throws -> SSELineResult {
        try Task.checkCancellation()
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == ":" || !trimmed.hasPrefix("data: ") {
            return .ignored
        }
        let payload = String(trimmed.dropFirst("data: ".count))
        if payload == "[DONE]" { return .done }
        guard let data = payload.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
              !chunk.choices.isEmpty else {
            return .malformed
        }
        if let delta = chunk.choices.first?.delta.content, !delta.isEmpty {
            continuation.yield(delta)
        }
        return .valid
    }

    // MARK: - Request construction

    private func buildRequest(for request: GenerateRequest,
                             config: Config,
                             key: String,
                             stream: Bool) throws -> URLRequest {
        var req = URLRequest(url: config.baseURL.appendingPathComponent("chat/completions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        var messages: [[String: String]] = []
        if !request.system.isEmpty { messages.append(["role": "system", "content": request.system]) }
        messages.append(["role": "user", "content": request.user])

        let body: [String: Any] = [
            "model": config.modelID,
            "messages": messages,
            "temperature": request.temperature,
            "max_tokens": request.maxTokens,
            "stream": stream
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }
}

// MARK: - Response shapes

/// Minimal LiteLLM/OpenAI-compatible non-streaming response shape.
private struct ChatChoice: Decodable {
    struct Message: Decodable { let role: String; let content: String }
    let message: Message
}
private struct ChatCompletionResponse: Decodable {
    let choices: [ChatChoice]
}

/// Minimal LiteLLM/OpenAI-compatible streaming chunk shape.
private struct StreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}
