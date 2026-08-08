import Foundation

/// Pure front-door result shared by text and voice Swarm entry points.
///
/// This type deliberately does not execute a route, widen context, persist
/// memory, or grant a capability. The browser shell remains responsible for
/// passing the decision through `VoiceCommandCoordinator`, `ContextRequestCoordinator`,
/// `SwarmOrchestrator`, and the policy/approval layer.
public struct SwarmIntentRoute: Sendable, Equatable {
    public let decision: VoiceRouteDecision
    public let preferenceCandidates: [PreferenceCandidate]

    public init(decision: VoiceRouteDecision,
                preferenceCandidates: [PreferenceCandidate] = []) {
        self.decision = decision
        self.preferenceCandidates = preferenceCandidates
    }
}

/// Shared deterministic classifier for browser text and voice transcripts.
///
/// Preference extraction is intentionally limited to the original user text.
/// Callers must not pass page text, connector content, model output, or spoken
/// synthesis back into this API as if it were user intent.
public struct SwarmIntentRouter: Sendable {
    private let classifier: DeterministicVoiceRouteClassifier

    public init(classifier: DeterministicVoiceRouteClassifier = .init()) {
        self.classifier = classifier
    }

    public func route(_ userText: String,
                      context: VoiceCommandContext) -> SwarmIntentRoute {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let decision = classifier.classify(trimmed, context: context)
        let candidates = PreferenceExtractor.extract(from: trimmed)
        return SwarmIntentRoute(decision: decision, preferenceCandidates: candidates)
    }

    /// Extracts preference candidates from the original transcript only. Callers
    /// should pass this exact user-authored text, not a context-augmented prompt.
    public func preferenceCandidates(from userText: String) -> [PreferenceCandidate] {
        PreferenceExtractor.extract(from: userText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
