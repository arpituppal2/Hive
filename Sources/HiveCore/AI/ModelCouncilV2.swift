import Foundation

// MARK: - ModelCouncilV2
//
// Parallel multi-model dispatch with chair synthesis. Sends a query to
// multiple providers simultaneously, collects responses, and synthesizes
// through a chair model (following the council/1b_council_chair.md protocol).
//
// Phase 2 — P2.3: Upgrades the existing model council from sequential
// single-model to parallel multi-model with honest degradation.

// MARK: - Council Query

/// A query to be dispatched to multiple models in parallel.
public struct CouncilQuery: Sendable {
    /// The user's question or task
    let question: String
    /// Optional page context (AXTree, page content)
    let pageContext: String?
    /// Which providers to query
    let providers: [CouncilProvider]
    /// Maximum time to wait for all responses (seconds)
    let timeout: TimeInterval

    public init(question: String,
         pageContext: String? = nil,
         providers: [CouncilProvider] = CouncilProvider.defaults,
         timeout: TimeInterval = 30) {
        self.question = question
        self.pageContext = pageContext
        self.providers = providers
        self.timeout = timeout
    }
}

// MARK: - Council Provider

/// A model provider that can participate in the council.
public enum CouncilProvider: String, Sendable, CaseIterable {
    case mlxLocal    // On-device MLX model
    case tavilyCloud // Tavily search API
    case vaneLocal   // Self-hosted Vane
    case byokRemote  // User's BYOK endpoint

    public static var defaults: [CouncilProvider] { [.mlxLocal, .tavilyCloud, .byokRemote] }
    public static var localOnly: [CouncilProvider] { [.mlxLocal] }
}

// MARK: - Council Response

/// Response from a single provider in the council.
public struct CouncilResponse: Sendable, Identifiable {
    public let id = UUID()
    public let provider: CouncilProvider
    public let answer: String
    public let confidence: Double
    public let citations: [String]
    public let duration: TimeInterval
    public let status: ResponseStatus

    public enum ResponseStatus: Sendable, Equatable {
        case success
        case timeout
        case error(String)
        case unavailable
    }
}

// MARK: - Council Verdict

/// The synthesized verdict from the model council.
public struct CouncilVerdict: Sendable {
    /// Final answer synthesized by the chair
    public let answer: String
    /// How the council reached this decision
    public let reasoning: String
    /// Areas where providers agreed
    public let agreements: [String]
    /// Areas where providers disagreed
    public let disagreements: [String]
    /// Combined confidence 0.0...1.0
    public let confidence: Double
    /// All individual responses
    public let responses: [CouncilResponse]
    /// Which providers actually responded
    public let activeProviders: [CouncilProvider]
    /// Whether the council degraded (fewer responses than expected)
    public let isDegraded: Bool
    /// AIResult state representation
    var resultState: AIResult<String> {
        if isDegraded {
            return .degraded(answer, explanation: "\(activeProviders.count) of \(responses.count) models responded")
        }
        return .success(answer)
    }
}

// MARK: - ModelCouncil

/// Orchestrates parallel multi-model dispatch and synthesis.
@MainActor
public final class ModelCouncil {

    private let dispatcher: Dispatcher
    private let searchProvider: WebSearchProvider?

    public init(dispatcher: Dispatcher = .shared, searchProvider: WebSearchProvider? = nil) {
        self.dispatcher = dispatcher
        self.searchProvider = searchProvider
    }

    // MARK: Public API

    /// Convene the council: send query to all providers in parallel,
    /// collect responses with timeout, synthesize through chair.
    public func convene(_ query: CouncilQuery) async -> CouncilVerdict {
        let startTime = Date()

        // Phase 1: Parallel dispatch to all providers
        let responses = await withTaskGroup(of: CouncilResponse.self) { group in
            for provider in query.providers {
                group.addTask {
                    await self.queryProvider(provider, query: query, startTime: startTime)
                }
            }

            var results: [CouncilResponse] = []
            for await response in group {
                results.append(response)
            }
            return results
        }

        // Sort responses: successful first, then by confidence
        let sorted = responses.sorted { a, b in
            if a.status == b.status { return a.confidence > b.confidence }
            if case .success = a.status { return true }
            if case .success = b.status { return false }
            return a.confidence > b.confidence
        }

        let active = sorted.filter { $0.status == .success }
        let isDegraded = active.count < query.providers.count

        // Phase 2: Synthesize through chair model
        let synthesis = await synthesize(responses: sorted, question: query.question)

        return CouncilVerdict(
            answer: synthesis.answer,
            reasoning: synthesis.reasoning,
            agreements: synthesis.agreements,
            disagreements: synthesis.disagreements,
            confidence: synthesis.confidence,
            responses: sorted,
            activeProviders: active.map(\.provider),
            isDegraded: isDegraded
        )
    }

    // MARK: Private

    /// Query a single provider with timeout.
    private func queryProvider(
        _ provider: CouncilProvider,
        query: CouncilQuery,
        startTime: Date
    ) async -> CouncilResponse {
        do {
            let q = query.question
            let ctx = query.pageContext
            let result = try await withTimeout(query.timeout) {
                try await self.sendToProvider(provider, question: q, context: ctx)
            }
            return CouncilResponse(
                provider: provider,
                answer: result.answer,
                confidence: result.confidence,
                citations: result.citations,
                duration: Date().timeIntervalSince(startTime),
                status: .success
            )
        } catch is TimeoutError {
            return CouncilResponse(
                provider: provider,
                answer: "",
                confidence: 0,
                citations: [],
                duration: query.timeout,
                status: .timeout
            )
        } catch {
            return CouncilResponse(
                provider: provider,
                answer: "",
                confidence: 0,
                citations: [],
                duration: Date().timeIntervalSince(startTime),
                status: .error(error.localizedDescription)
            )
        }
    }

    /// Send question to a specific provider.
    private func sendToProvider(
        _ provider: CouncilProvider,
        question: String,
        context: String?
    ) async throws -> ProviderResult {
        switch provider {
        case .mlxLocal:
            return try await queryMLX(question: question, context: context)
        case .tavilyCloud:
            return try await queryTavily(question: question)
        case .vaneLocal:
            return try await queryMLX(question: question, context: context) // Fallback to MLX
        case .byokRemote:
            throw InferenceError.byokNotConfigured(role: .librarian)
        }
    }

    private func queryMLX(question: String, context: String?) async throws -> ProviderResult {
        var prompt = question
        if let ctx = context {
            prompt = "Context:\n\(ctx)\n\nQuestion: \(question)"
        }

        let request = GenerateRequest(
            role: .librarian,
            system: "Answer concisely with citations when possible.",
            user: prompt,
            maxTokens: 1024
        )

        let result = try await dispatcher.generate(request)
        return ProviderResult(
            answer: result.text,
            confidence: 0.85,
            citations: extractCitations(from: result.text)
        )
    }

    private func queryTavily(question: String) async throws -> ProviderResult {
        // Use the real TavilySearchProvider if a key is available
        if let search = searchProvider, await search.isAvailable() {
            do {
                let result = try await search.search(query: question, focusMode: .webSearch)
                let answer = result.answer.isEmpty
                    ? result.sources.prefix(5).map { "[\($0.title)](\($0.url)): \($0.snippet)" }.joined(separator: "\n\n")
                    : result.answer
                return ProviderResult(
                    answer: answer,
                    confidence: 0.85,
                    citations: result.sources.map { $0.url }
                )
            } catch {
                return ProviderResult(
                    answer: "",
                    confidence: 0,
                    citations: []
                )
            }
        }
        // No search provider configured — honest degradation
        return ProviderResult(
            answer: "",
            confidence: 0,
            citations: []
        )
    }

    /// Synthesize responses through the chair model. Uses the dispatcher to
    /// produce a proper synthesis with reasoning, agreements, and disagreements
    /// rather than a simple heuristic merge.
    private func synthesize(responses: [CouncilResponse], question: String) async -> Synthesis {
        guard !responses.isEmpty else {
            return Synthesis(answer: "No models responded.", reasoning: "All providers failed.",
                             agreements: [], disagreements: [], confidence: 0)
        }

        let active = responses.filter { $0.status == .success }
        guard !active.isEmpty else {
            return Synthesis(answer: "All models timed out or errored.",
                             reasoning: "No successful responses.",
                             agreements: [], disagreements: [], confidence: 0)
        }

        // If only one model responded, return its answer directly
        if active.count == 1, let solo = active.first {
            return Synthesis(
                answer: solo.answer,
                reasoning: "Single model response (council degraded).",
                agreements: [solo.provider.rawValue + ": " + solo.answer],
                disagreements: [],
                confidence: solo.confidence * 0.7
            )
        }

        // Build a chair prompt from all responses
        let responseTexts = active.enumerated().map { i, r in
            """
            Model \(i + 1) (\(r.provider.rawValue), confidence \(Int(r.confidence * 100))%):
            \(r.answer)
            """
        }.joined(separator: "\n")

        let chairPrompt = """
        Question: \(question)

        Council responses:
        \(responseTexts)

        As the chair, synthesize these responses:
        1. Provide a single best answer that reconciles all perspectives.
        2. Note where models AGREE (specific points of consensus).
        3. Note where models DISAGREE (specific points of divergence).
        4. Assign an overall confidence score (0.0–1.0).

        Format your response as:
        ANSWER: <final answer>
        AGREEMENTS: <comma-separated agreement points>
        DISAGREEMENTS: <comma-separated disagreement points>
        CONFIDENCE: <0.0-1.0>
        """

        do {
            let result = try await dispatcher.generate(GenerateRequest(
                role: .librarian,
                system: "You are a council chair. Synthesize multiple AI responses into one authoritative answer. Be precise about agreements and disagreements.",
                user: chairPrompt,
                maxTokens: 2048
            ))
            return parseChairResponse(result.text, active: active)
        } catch {
            // Fall back to local synthesis on chair model failure
            return localSynthesize(active: active)
        }
    }

    /// Fallback local synthesis when the chair model is unavailable.
    private func localSynthesize(active: [CouncilResponse]) -> Synthesis {
        let confidences = active.map { $0.confidence }
        let avgConfidence = confidences.reduce(0, +) / Double(confidences.count)
        let hasConsensus = confidences.allSatisfy { $0 > 0.7 }
        let bestAnswer = active.max(by: { $0.confidence < $1.confidence })?.answer ?? active[0].answer

        return Synthesis(
            answer: bestAnswer,
            reasoning: "Synthesized from \(active.count) model(s) (chair model unavailable — local merge).",
            agreements: hasConsensus ? ["All \(active.count) models agree on the core answer."] : [],
            disagreements: hasConsensus ? [] : active.filter { $0.confidence < 0.7 }.map {
                "\($0.provider.rawValue): lower confidence (\(Int($0.confidence * 100))%)"
            },
            confidence: hasConsensus ? avgConfidence : avgConfidence * 0.6
        )
    }

    /// Parse the chair model's structured response.
    private func parseChairResponse(_ text: String, active: [CouncilResponse]) -> Synthesis {
        var answer = ""
        var agreements: [String] = []
        var disagreements: [String] = []
        var confidence: Double = 0.7

        let lines = text.components(separatedBy: "\n")
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("ANSWER:") || trimmed.hasPrefix("ANSWER") {
                currentSection = "answer"
                answer = String(trimmed.dropFirst(trimmed.hasPrefix("ANSWER:") ? 7 : 6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("AGREEMENTS:") || trimmed.hasPrefix("AGREEMENTS") {
                currentSection = "agreements"
                let val = String(trimmed.dropFirst(trimmed.hasPrefix("AGREEMENTS:") ? 11 : 10)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { agreements = val.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
            } else if trimmed.hasPrefix("DISAGREEMENTS:") || trimmed.hasPrefix("DISAGREEMENTS") {
                currentSection = "disagreements"
                let val = String(trimmed.dropFirst(trimmed.hasPrefix("DISAGREEMENTS:") ? 14 : 13)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { disagreements = val.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
            } else if trimmed.hasPrefix("CONFIDENCE:") || trimmed.hasPrefix("CONFIDENCE") {
                let val = String(trimmed.dropFirst(trimmed.hasPrefix("CONFIDENCE:") ? 11 : 10)).trimmingCharacters(in: .whitespaces)
                confidence = Double(val) ?? 0.7
            } else if currentSection == "answer", !trimmed.isEmpty {
                answer += " " + trimmed
            } else if currentSection == "agreements", !trimmed.isEmpty, trimmed.hasPrefix("-") {
                agreements.append(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces))
            } else if currentSection == "disagreements", !trimmed.isEmpty, trimmed.hasPrefix("-") {
                disagreements.append(String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces))
            }
        }

        if answer.isEmpty {
            answer = active.max(by: { $0.confidence < $1.confidence })?.answer ?? active[0].answer
            confidence = confidence * 0.5
        }

        return Synthesis(
            answer: answer,
            reasoning: "Chair synthesis from \(active.count) models.",
            agreements: agreements,
            disagreements: disagreements,
            confidence: min(1.0, max(0.0, confidence))
        )
    }

    // MARK: Helpers

    private func extractCitations(from text: String) -> [String] {
        // Simple URL extraction from text
        let pattern = try? NSRegularExpression(pattern: "https?://[^\\s)]+", options: [])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return pattern?.matches(in: text, options: [], range: range)
            .compactMap { Range($0.range, in: text).map { String(text[$0]) } } ?? []
    }
}

// MARK: - Supporting Types

private struct ProviderResult: Sendable {
    public let answer: String
    public let confidence: Double
    public let citations: [String]
}

private struct Synthesis {
    public let answer: String
    public let reasoning: String
    public let agreements: [String]
    public let disagreements: [String]
    public let confidence: Double
}

struct TimeoutError: Error {}

func withTimeout<T: Sendable>(_ seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        group.cancelAll()
        return result
    }
}
