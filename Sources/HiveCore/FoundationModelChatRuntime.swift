import Foundation

#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import FoundationModels
#endif

public struct FoundationModelChatRuntimeConfiguration: Hashable, Sendable {
    public var mode: FoundationModelMemoryMode
    public var maxContextPages: Int
    public var maxContextClaims: Int

    public init(
        mode: FoundationModelMemoryMode = .foundationWhenAvailable,
        maxContextPages: Int = 5,
        maxContextClaims: Int = 8
    ) {
        self.mode = mode
        self.maxContextPages = max(1, maxContextPages)
        self.maxContextClaims = max(1, maxContextClaims)
    }

    public var contextBudget: HiveFoundationContextBudget {
        HiveFoundationContextBudget(maxPages: maxContextPages, maxClaims: maxContextClaims)
    }
}

public actor FoundationModelChatRuntime {
    public let configuration: FoundationModelChatRuntimeConfiguration
    private let orchestrator: HiveFoundationModelsOrchestrator

    public init(configuration: FoundationModelChatRuntimeConfiguration = FoundationModelChatRuntimeConfiguration()) {
        self.configuration = configuration
        self.orchestrator = HiveFoundationModelsOrchestrator(
            mode: configuration.mode,
            budget: configuration.contextBudget
        )
    }

    public static func currentAvailability(mode: FoundationModelMemoryMode = .foundationWhenAvailable) -> FoundationModelMemoryAvailability {
        HiveFoundationModelsOrchestrator.currentAvailability(mode: mode)
    }

    public func availability() -> FoundationModelMemoryAvailability {
        Self.currentAvailability(mode: configuration.mode)
    }

    public func answer(
        query: String,
        localAnswer: CitedAnswer,
        claims: [ClaimRecord],
        wikiPages: [WikiPageRecord],
        visibility: DerivedMemoryVisibility = .allowAll
    ) async -> CitedAnswer {
        let result = await orchestrator.answerChat(
            query: query,
            localAnswer: localAnswer,
            claims: claims,
            wikiPages: wikiPages,
            visibility: visibility
        )
        return result.proposal.citedAnswer(fallback: localAnswer, fallbackReason: result.fallbackReason)
    }
}
