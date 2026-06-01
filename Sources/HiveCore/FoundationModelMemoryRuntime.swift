import Foundation

public enum FoundationModelMemoryAvailability: String, Codable, CaseIterable, Sendable {
    case available
    case frameworkUnavailable
    case osUnavailable
    case modelUnavailable
    case appleIntelligenceDisabled
    case deviceNotEligible
    case modelNotReady
    case unsupportedLanguageOrLocale

    public var usesDeterministicFallback: Bool {
        self != .available
    }
}

public enum FoundationModelMemoryMode: String, Codable, CaseIterable, Sendable {
    case deterministicFallbackOnly
    case foundationWhenAvailable
}

public actor FoundationModelMemoryRuntime {
    public var mode: FoundationModelMemoryMode
    private let fallbackRuntime: MemoryCompilerRuntime
    private let orchestrator: HiveFoundationModelsOrchestrator

    public init(
        mode: FoundationModelMemoryMode = .foundationWhenAvailable,
        fallbackRuntime: MemoryCompilerRuntime = MemoryCompilerRuntime(profile: .deterministicRules)
    ) {
        self.mode = mode
        self.fallbackRuntime = fallbackRuntime
        self.orchestrator = HiveFoundationModelsOrchestrator(mode: mode)
    }

    public func availability() -> FoundationModelMemoryAvailability {
        HiveFoundationModelsOrchestrator.currentAvailability(mode: mode)
    }

    public func compile(
        source: SourceRecord,
        extractedClaims: [ClaimRecord],
        existingClaims: [ClaimRecord],
        existingEntities: [EntityRecord],
        feedback: [FeedbackRecord] = [],
        storeStateHash: String? = nil,
        now: Date = Date()
    ) async -> MemoryCompilerDecisionEnvelope {
        let fallback = fallbackRuntime.compile(
            source: source,
            extractedClaims: extractedClaims,
            existingClaims: existingClaims,
            existingEntities: existingEntities,
            feedback: feedback,
            storeStateHash: storeStateHash,
            now: now
        )
        return await orchestrator.compileMemory(
            source: source,
            extractedClaims: extractedClaims,
            existingClaims: existingClaims,
            existingEntities: existingEntities,
            feedback: feedback,
            fallback: fallback,
            now: now
        )
    }

}
