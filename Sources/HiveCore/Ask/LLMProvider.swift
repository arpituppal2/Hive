import Foundation

// MARK: - LLM provider abstraction
//
// W1 AI-stack decision: out-of-process serving. The app talks OpenAI-compatible
// HTTP to a lazily-spawned local server (llama-server / mlx_lm.server). Lazy load,
// unload = kill process, model crash ≠ browser crash. Mock provider keeps the whole
// ask pipeline testable without weights (and drives golden-set plumbing tests).

public struct ChatMessage: Sendable, Equatable {
    public enum Role: String, Sendable { case system, user, assistant }
    public var role: Role
    public var content: String
    public init(_ role: Role, _ content: String) { self.role = role; self.content = content }
}

public struct LLMStreamEvent: Sendable {
    public enum Kind: Sendable { case delta(String), finished }
    public var kind: Kind
    public init(_ kind: Kind) { self.kind = kind }
}

public protocol LLMProvider: Sendable {
    var label: String { get }   // honest labeling: "mock", "http:qwen3-4b", …
    /// Streams deltas; `finished` terminates. Throws on transport/generation errors.
    func stream(messages: [ChatMessage], temperature: Double, maxTokens: Int) async throws -> AsyncThrowingStream<LLMStreamEvent, Error>
}

/// Deterministic mock for tests + no-weights runs. Labeled, never silent.
public struct MockLLM: LLMProvider {
    public let label = "mock"
    public let scriptedAnswer: String?
    public let refuseFlavor: String?

    /// - scriptedAnswer: emitted in chunks; may contain `[1]`-style citation markers.
    /// - refuseFlavor: if non-nil the mock refuses instead of answering.
    public init(scriptedAnswer: String? = nil, refuseFlavor: String? = nil) {
        self.scriptedAnswer = scriptedAnswer
        self.refuseFlavor = refuseFlavor
    }

    public func stream(messages: [ChatMessage], temperature: Double, maxTokens: Int) async throws -> AsyncThrowingStream<LLMStreamEvent, Error> {
        let answer = scriptedAnswer ?? Self.groundlessAnswer(from: messages)
        return AsyncThrowingStream(LLMStreamEvent.self) { continuation in
            Task {
                // Verifier prompts get a one-word deterministic reply.
                if messages.first?.content.lowercased().hasPrefix("support-checker.") == true {
                    continuation.yield(LLMStreamEvent(.delta("yes")))
                    continuation.yield(LLMStreamEvent(.finished))
                    continuation.finish()
                    return
                }
                if let flavor = refuseFlavor {
                    continuation.yield(LLMStreamEvent(.delta("__REFUSE__:\(flavor)")))
                    continuation.yield(LLMStreamEvent(.finished))
                    continuation.finish()
                    return
                }
                for chunk in answer.split(separator: " ", omittingEmptySubsequences: false) {
                    continuation.yield(LLMStreamEvent(.delta(String(chunk) + " ")))
                    try? await Task.sleep(nanoseconds: 2_000_000)
                }
                continuation.yield(LLMStreamEvent(.finished))
                continuation.finish()
            }
        }
    }

    /// Extracts the first span block content so mock answers actually cite it.
    static func groundlessAnswer(from messages: [ChatMessage]) -> String {
        let joined = messages.map(\.content).joined(separator: "\n")
        if let range = joined.range(of: "[[SPAN:1]]") {
            let tail = String(joined[range.upperBound...])
            let end = tail.range(of: "[[/SPAN") ?? tail.endIndex..<tail.endIndex
            let spanText = String(tail[..<end.lowerBound]).prefix(220)
            return "Based on what you've captured: \(spanText) [1]"
        }
        return "__REFUSE__:no-support"
    }
}

/// OpenAI-compatible streaming client (POST /v1/chat/completions, SSE).
public struct HTTPLLM: LLMProvider {
    public let label: String
    private let endpoint: URL
    private let model: String

    public init(endpoint: URL, model: String, label: String) {
        self.endpoint = endpoint
        self.model = model
        self.label = label
    }

    public func stream(messages: [ChatMessage], temperature: Double, maxTokens: Int) async throws -> AsyncThrowingStream<LLMStreamEvent, Error> {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 300
        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": true,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 300
        cfg.timeoutIntervalForResource = 600
        let session = URLSession(configuration: cfg)
        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw HTTPErr("no http response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HTTPErr("server \(http.statusCode)")
        }

        return AsyncThrowingStream(LLMStreamEvent.self) { continuation in
            let task = Task.detached {
                do {
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let obj = try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                              let choices = obj["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String, !content.isEmpty else { continue }
                        continuation.yield(LLMStreamEvent(.delta(content)))
                    }
                    continuation.yield(LLMStreamEvent(.finished))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private struct HTTPErr: Error, CustomStringConvertible {
        let m: String
        init(_ m: String) { self.m = m }
        var description: String { "llm transport: \(m)" }
    }
}
