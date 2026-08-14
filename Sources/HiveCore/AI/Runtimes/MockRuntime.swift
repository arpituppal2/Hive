import Foundation

/// Honest mock: returns deterministic, labelled-not-real responses. Provider
/// is `.mock`, so `isRealInference == false` — nothing downstream can mistake
/// this for a thinking model. This is the no-weights fallback per AGENTS §6.5.
public struct MockRuntime: ModelRuntime, StreamingModelRuntime {
    public let roles: Set<ModelRole>

    public init(roles: Set<ModelRole> = Set(ModelRole.allCases)) {
        self.roles = roles.intersection(MockRuntime.supportedRoles)
    }

    public static let supportedRoles: Set<ModelRole> = Set(ModelRole.allCases)

    public func isAvailable() async -> Bool { true }

    public func generate(_ request: GenerateRequest) async throws -> GenerateResult {
        let entry = ModelManifest.entries[request.role]
        let label = entry?.baseModel ?? request.role.displayLabel
        // Deterministic canned response, clearly marked as not-real.
        let body = mockBody(for: request.role, user: request.user)
        // Small artificial delay to exercise async paths without lying.
        try await Task.sleep(nanoseconds: 8_000_000)
        return GenerateResult(
            role: request.role, provider: .mock, text: body,
            latencyMS: 8, tokensGenerated: body.split(separator: " ").count,
            modelLabel: label)
    }

    /// Streaming variant for chat surfaces. Yields word-sized chunks with a tiny
    /// delay so the UI can exercise its streaming path even when no real model
    /// is loaded. The final chunk is the complete text.
    public func generateStream(_ request: GenerateRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let body = self.mockBody(for: request.role, user: request.user)
            let words = body.split(separator: " ").map(String.init)
            let task = Task {
                do {
                    for word in words {
                        try Task.checkCancellation()
                        continuation.yield(word + " ")
                        try await Task.sleep(nanoseconds: 5_000_000)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    // Consumer cancellation is a normal terminal state, not
                    // a provider failure and not a reason to keep the task alive.
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func mockBody(for role: ModelRole, user: String) -> String {
        let prompt = user.count > 64 ? String(user.prefix(64)) + "…" : user
        switch role {
        case .actionGuard:
            return "ALLOW"          // never actually consulted — action guard is rule-based
        case .intentClassifier:
            return "{\"route\":\"search\",\"reason\":\"mock\"}"
        case .spamDetector:
            return "{\"spam\":false,\"reason\":\"mock\"}"
        case .urgencyDetector:
            return "{\"urgency\":\"normal\"}"
        case .linkScorer:
            return "[{\"url\":\"_\",\"score\":0.5}]"
        case .pageQa:
            return "{\"answer\":\"mock — no real model loaded\",\"answer_type\":\"page_does_not_say\",\"basis\":[],\"page_claim_unverified\":false,\"confidence\":0.0,\"status\":\"complete\"}"
        case .orchestrator, .planner:
            return "MOCK PLAN — no real local model loaded yet. User asked: \(prompt)"
        case .librarian:
            return "MOCK EXTRACTION — no real local model loaded yet."
        case .summarizer, .memoryCompressor:
            return "MOCK SUMMARY — no real local model loaded yet."
        case .retrievalRanker:
            return "MOCK RANK"
        case .titleGenerator:
            return "Mock title"
        case .auditor:
            return "MOCK AUDIT — no contradiction detected (mock)"
        case .researchGatherer:
            return "{\"candidates\":[],\"reason\":\"mock — no real local model loaded yet\"}"
        case .deepReasoner, .researchSynthesizer:
            return "MOCK REASONING — no real local model loaded yet."
        case .coder:
            return "MOCK CODE — no real local model loaded yet."
        case .embedder, .byokFrontier, .appleFMF:
            return "MOCK"
        }
    }
}
