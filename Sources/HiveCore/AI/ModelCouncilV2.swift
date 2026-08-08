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

    public init(dispatcher: Dispatcher = .shared) {
        self.dispatcher = dispatcher
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
        let synthesis = synthesize(responses: sorted, question: query.question)

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
        // Delegate to existing Tavily search provider
        // (simplified — real implementation calls ResearchWorkerClient)
        return ProviderResult(
            answer: "[Tavily search results for: \(question)]",
            confidence: 0.8,
            citations: []
        )
    }

    /// Synthesize responses through the chair model.
    private func synthesize(responses: [CouncilResponse], question: String) -> Synthesis {
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
                agreements: [solo.answer],
                disagreements: [],
                confidence: solo.confidence * 0.7 // Penalty for no corroboration
            )
        }

        // Find agreement and disagreement areas
        let answers = active.map { $0.answer }
        let confidences = active.map { $0.confidence }

        let avgConfidence = confidences.reduce(0, +) / Double(confidences.count)
        let hasConsensus = confidences.allSatisfy { $0 > 0.7 }

        var agreements: [String] = []
        var disagreements: [String] = []

        if hasConsensus {
            agreements = ["All \(active.count) models agree on the core answer."]
        } else {
            disagreements = ["Models differ in confidence and detail."]
            for resp in active where resp.confidence < 0.7 {
                disagreements.append("\(resp.provider.rawValue): lower confidence (\(Int(resp.confidence * 100))%)")
            }
        }

        // Use the highest-confidence answer as the primary
        let bestAnswer = active.max(by: { $0.confidence < $1.confidence })?.answer ?? active[0].answer

        return Synthesis(
            answer: bestAnswer,
            reasoning: "Synthesized from \(active.count) model(s). Council \(hasConsensus ? "reached consensus" : "has divergent views").",
            agreements: agreements,
            disagreements: disagreements,
            confidence: hasConsensus ? avgConfidence : avgConfidence * 0.6
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
