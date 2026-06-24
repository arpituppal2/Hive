import Foundation

#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import FoundationModels
#endif

public enum HiveFoundationTask: String, Codable, CaseIterable, Sendable {
    case answerChat
    case summarizeSource
    case extractClaims
    case extractEntities
    case planColonyPatch
    case writeColonyPage
    case rankWikiPages
    case summarizeOnlineSource
    case classifyGraphCoordinate
    case planGraphReindex
    case reviewAxisVocabulary
    case recommendAction
    case fileAnswer
}

public struct HiveFoundationTaskAvailability: Codable, Hashable, Sendable {
    public var task: HiveFoundationTask
    public var foundationAvailability: FoundationModelMemoryAvailability
    public var userFacingStatus: String
    public var usesDeterministicFallback: Bool

    public init(
        task: HiveFoundationTask,
        foundationAvailability: FoundationModelMemoryAvailability,
        userFacingStatus: String? = nil
    ) {
        self.task = task
        self.foundationAvailability = foundationAvailability
        self.userFacingStatus = userFacingStatus ?? Self.statusLabel(for: foundationAvailability)
        self.usesDeterministicFallback = foundationAvailability.usesDeterministicFallback
    }

    private static func statusLabel(for availability: FoundationModelMemoryAvailability) -> String {
        switch availability {
        case .available:
            return "Local AI"
        case .appleIntelligenceDisabled, .deviceNotEligible, .modelNotReady,
             .unsupportedLanguageOrLocale, .osUnavailable, .frameworkUnavailable, .modelUnavailable:
            return "Indexed Wiki"
        }
    }
}

public struct HiveFoundationTaskResult<Proposal: Sendable>: Sendable {
    public var task: HiveFoundationTask
    public var availability: HiveFoundationTaskAvailability
    public var proposal: Proposal
    public var usedFoundationModels: Bool
    public var fallbackReason: String?

    public init(
        task: HiveFoundationTask,
        availability: HiveFoundationTaskAvailability,
        proposal: Proposal,
        usedFoundationModels: Bool,
        fallbackReason: String? = nil
    ) {
        self.task = task
        self.availability = availability
        self.proposal = proposal
        self.usedFoundationModels = usedFoundationModels
        self.fallbackReason = fallbackReason
    }
}

public struct HiveChatAnswerProposal: Codable, Hashable, Sendable {
    public var answer: String
    public var sourceIDs: [String]
    public var attribution: String
    public var certainty: String
    public var correctionOptions: [String]
    public var requiresUserReview: Bool

    public init(
        answer: String,
        sourceIDs: [String],
        attribution: String,
        certainty: String,
        correctionOptions: [String],
        requiresUserReview: Bool = false
    ) {
        self.answer = answer
        self.sourceIDs = stableUnique(sourceIDs)
        self.attribution = attribution
        self.certainty = certainty
        self.correctionOptions = stableUnique(correctionOptions)
        self.requiresUserReview = requiresUserReview
    }

    public func citedAnswer(fallback: CitedAnswer, fallbackReason: String? = nil) -> CitedAnswer {
        let allowed = Set(sourceIDs)
        let citations = allowed.isEmpty
            ? fallback.citations
            : fallback.citations.filter { allowed.contains($0.id) }
        let uncertainty = fallbackReason ?? (attribution.isEmpty ? "Local AI" : attribution)
        return CitedAnswer(
            answer: answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback.answer : answer,
            citations: citations.isEmpty ? fallback.citations : citations,
            uncertainty: uncertainty,
            suggestedActions: stableUnique(correctionOptions + fallback.suggestedActions)
        )
    }
}

public struct FoundationClaimProposal: Codable, Hashable, Sendable {
    public var statement: String
    public var sourceIDs: [String]
    public var confidenceLanguage: String

    public init(statement: String, sourceIDs: [String], confidenceLanguage: String) {
        self.statement = statement
        self.sourceIDs = stableUnique(sourceIDs)
        self.confidenceLanguage = confidenceLanguage
    }
}

public struct FoundationEntityProposal: Codable, Hashable, Sendable {
    public var name: String
    public var kind: String
    public var sourceIDs: [String]

    public init(name: String, kind: String, sourceIDs: [String]) {
        self.name = name
        self.kind = kind
        self.sourceIDs = stableUnique(sourceIDs)
    }
}

public struct ClaimExtractionProposal: Codable, Hashable, Sendable {
    public var sourceID: String
    public var claims: [FoundationClaimProposal]
    public var requiresUserReview: Bool

    public init(sourceID: String, claims: [FoundationClaimProposal], requiresUserReview: Bool = true) {
        self.sourceID = sourceID
        self.claims = claims.map {
            FoundationClaimProposal(
                statement: $0.statement,
                sourceIDs: $0.sourceIDs.filter { $0 == sourceID },
                confidenceLanguage: $0.confidenceLanguage
            )
        }
        self.requiresUserReview = requiresUserReview
    }
}

public struct EntityExtractionProposal: Codable, Hashable, Sendable {
    public var sourceID: String
    public var entities: [FoundationEntityProposal]
    public var requiresUserReview: Bool

    public init(sourceID: String, entities: [FoundationEntityProposal], requiresUserReview: Bool = true) {
        self.sourceID = sourceID
        self.entities = entities.map {
            FoundationEntityProposal(
                name: $0.name,
                kind: $0.kind,
                sourceIDs: $0.sourceIDs.filter { $0 == sourceID }
            )
        }
        self.requiresUserReview = requiresUserReview
    }
}

public struct OnlineSourceSummaryProposal: Codable, Hashable, Sendable {
    public var sourceID: String
    public var url: String
    public var title: String
    public var summary: String
    public var keyIdeas: [String]
    public var sourceIDs: [String]
    public var requiresUserReview: Bool

    public init(
        sourceID: String,
        url: String,
        title: String,
        summary: String,
        keyIdeas: [String],
        sourceIDs: [String],
        requiresUserReview: Bool = true
    ) {
        self.sourceID = sourceID
        self.url = url
        self.title = title
        self.summary = summary
        self.keyIdeas = stableUnique(keyIdeas)
        self.sourceIDs = stableUnique(sourceIDs.filter { $0 == sourceID })
        self.requiresUserReview = requiresUserReview
    }
}

public struct SourceIngestProposal: Codable, Hashable, Sendable {
    public var sourceID: String
    public var summary: String
    public var claims: [FoundationClaimProposal]
    public var entities: [FoundationEntityProposal]
    public var contradictions: [String]
    public var privacySensitivity: String
    public var graphCandidates: [GraphCoordinateProposal]
    public var decisionKind: MemoryCompilationDecisionKind
    public var targetID: String?
    public var proposedStatement: String?
    public var confidence: Double
    public var requiresUserReview: Bool

    public init(
        sourceID: String,
        summary: String,
        claims: [FoundationClaimProposal],
        entities: [FoundationEntityProposal],
        contradictions: [String] = [],
        privacySensitivity: String = "normal",
        graphCandidates: [GraphCoordinateProposal] = [],
        decisionKind: MemoryCompilationDecisionKind,
        targetID: String? = nil,
        proposedStatement: String? = nil,
        confidence: Double,
        requiresUserReview: Bool = true
    ) {
        self.sourceID = sourceID
        self.summary = summary
        self.claims = claims
        self.entities = entities
        self.contradictions = stableUnique(contradictions)
        self.privacySensitivity = privacySensitivity
        self.graphCandidates = graphCandidates
        self.decisionKind = decisionKind
        self.targetID = targetID
        self.proposedStatement = proposedStatement
        self.confidence = ConfidenceScore(confidence).value
        self.requiresUserReview = requiresUserReview || !contradictions.isEmpty
    }

    public func memoryDecision(fallback: MemoryCompilationDecision) -> MemoryCompilationDecision {
        MemoryCompilationDecision(
            kind: decisionKind,
            confidence: ConfidenceScore(confidence).value,
            reason: summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback.reason : summary,
            targetID: targetID ?? fallback.targetID,
            proposedStatement: proposedStatement?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? proposedStatement
                : fallback.proposedStatement
        )
    }
}

public struct FoundationColonyPatchOperation: Codable, Hashable, Sendable {
    public var kind: WikiPatchOperationKind
    public var pageID: String
    public var markdown: String
    public var sectionTitle: String?
    public var targetPageID: String?

    public init(
        kind: WikiPatchOperationKind,
        pageID: String,
        markdown: String = "",
        sectionTitle: String? = nil,
        targetPageID: String? = nil
    ) {
        self.kind = kind
        self.pageID = pageID
        self.markdown = markdown
        self.sectionTitle = sectionTitle
        self.targetPageID = targetPageID
    }
}

public struct HiveFoundationCommandContext: Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var defaultEnabled: Bool
    public var requiresInput: Bool
    public var inputPrompt: String?

    public init(
        id: String,
        title: String,
        defaultEnabled: Bool = true,
        requiresInput: Bool = false,
        inputPrompt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.defaultEnabled = defaultEnabled
        self.requiresInput = requiresInput
        self.inputPrompt = inputPrompt
    }
}

public struct ColonyPatchProposal: Codable, Hashable, Sendable {
    public var reason: String
    public var touchedPageIDs: [String]
    public var sourceIDs: [String]
    public var operations: [FoundationColonyPatchOperation]
    public var confidenceLanguage: String
    public var requiresUserReview: Bool

    public init(
        reason: String,
        touchedPageIDs: [String],
        sourceIDs: [String],
        operations: [FoundationColonyPatchOperation],
        confidenceLanguage: String = "proposal",
        requiresUserReview: Bool = true
    ) {
        self.reason = reason
        self.touchedPageIDs = stableUnique(touchedPageIDs)
        self.sourceIDs = stableUnique(sourceIDs)
        self.operations = operations
        self.confidenceLanguage = confidenceLanguage
        self.requiresUserReview = requiresUserReview
    }

    public func wikiPatchProposal(fallback: WikiPatchProposal? = nil, pages: [WikiPageRecord] = []) -> WikiPatchProposal {
        let pageMap = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0) })
        let beforeHashes = Dictionary(uniqueKeysWithValues: touchedPageIDs.compactMap { id -> (String, String)? in
            guard let page = pageMap[id] else { return nil }
            return (id, Hashing.sha256(data: Data(page.markdown.utf8)))
        })
        let patchOperations = operations.map { operation in
            WikiPatchOperation(
                kind: operation.kind,
                pageID: operation.pageID,
                targetPageID: operation.targetPageID,
                sectionTitle: operation.sectionTitle,
                markdown: operation.markdown
            )
        }
        return WikiPatchProposal(
            reason: reason.isEmpty ? (fallback?.reason ?? "Review The Colony with local AI.") : reason,
            touchedPageIDs: touchedPageIDs.isEmpty ? (fallback?.touchedPageIDs ?? []) : touchedPageIDs,
            beforeHashes: beforeHashes.isEmpty ? (fallback?.beforeHashes ?? [:]) : beforeHashes,
            operations: patchOperations.isEmpty ? (fallback?.operations ?? []) : patchOperations,
            confidenceLanguage: confidenceLanguage,
            requiresUserReview: requiresUserReview
        )
    }
}

public struct GraphCoordinateProposal: Codable, Hashable, Sendable {
    public var nodeID: String
    public var x: Double
    public var y: Double
    public var label: String
    public var rationale: String
    public var sourceIDs: [String]
    public var confidenceLanguage: String

    public init(
        nodeID: String,
        x: Double,
        y: Double,
        label: String,
        rationale: String,
        sourceIDs: [String],
        confidenceLanguage: String = "proposal"
    ) {
        self.nodeID = nodeID
        self.x = min(1, max(-1, x))
        self.y = min(1, max(-1, y))
        self.label = label
        self.rationale = rationale
        self.sourceIDs = stableUnique(sourceIDs)
        self.confidenceLanguage = confidenceLanguage
    }
}

public struct GraphReindexProposal: Codable, Hashable, Sendable {
    public var steps: [GraphReindexStep]
    public var rationale: String
    public var sourceIDs: [String]
    public var requiresUserReview: Bool

    public init(
        steps: [GraphReindexStep],
        rationale: String,
        sourceIDs: [String],
        requiresUserReview: Bool = false
    ) {
        self.steps = steps
        self.rationale = rationale
        self.sourceIDs = stableUnique(sourceIDs)
        self.requiresUserReview = requiresUserReview
    }

    public var plan: GraphReindexPlan {
        GraphReindexPlan(steps: steps)
    }
}

public struct AxisVocabularyReview: Codable, Hashable, Sendable {
    public var isApproved: Bool
    public var message: String
    public var suggestedTop: String?
    public var suggestedBottom: String?
    public var suggestedRight: String?
    public var suggestedLeft: String?

    public init(
        isApproved: Bool,
        message: String,
        suggestedTop: String? = nil,
        suggestedBottom: String? = nil,
        suggestedRight: String? = nil,
        suggestedLeft: String? = nil
    ) {
        self.isApproved = isApproved
        self.message = message
        self.suggestedTop = suggestedTop
        self.suggestedBottom = suggestedBottom
        self.suggestedRight = suggestedRight
        self.suggestedLeft = suggestedLeft
    }

    public var graphReview: GraphAxisVocabularyReview {
        GraphAxisVocabularyReview(isApproved: isApproved, message: message)
    }
}

public struct RecommendedActionProposal: Codable, Hashable, Sendable {
    public var commandID: String
    public var title: String
    public var reason: String
    public var requiredInputPrompt: String?
    public var isEnabled: Bool
    public var sourceIDs: [String]

    public init(
        commandID: String,
        title: String,
        reason: String,
        requiredInputPrompt: String? = nil,
        isEnabled: Bool,
        sourceIDs: [String] = []
    ) {
        self.commandID = commandID
        self.title = title
        self.reason = reason
        self.requiredInputPrompt = requiredInputPrompt
        self.isEnabled = isEnabled
        self.sourceIDs = stableUnique(sourceIDs)
    }
}

public struct HiveFoundationToolContext: Sendable {
    public var wikiPages: [WikiPageRecord]
    public var sources: [SourceRecord]
    public var graphNodes: [GraphNodeRecord]
    public var graphEdges: [GraphEdgeRecord]
    public var approvedWebText: [String: String]

    public init(
        wikiPages: [WikiPageRecord] = [],
        sources: [SourceRecord] = [],
        graphNodes: [GraphNodeRecord] = [],
        graphEdges: [GraphEdgeRecord] = [],
        approvedWebText: [String: String] = [:]
    ) {
        self.wikiPages = wikiPages
        self.sources = sources
        self.graphNodes = graphNodes
        self.graphEdges = graphEdges
        self.approvedWebText = approvedWebText
    }
}

public struct HiveFoundationContextBudget: Codable, Hashable, Sendable {
    public var maxPromptCharacters: Int
    public var maxPageCharacters: Int
    public var maxRawCharacters: Int
    public var maxPages: Int
    public var maxClaims: Int

    public init(
        maxPromptCharacters: Int = 10_000,
        maxPageCharacters: Int = 1_000,
        maxRawCharacters: Int = 5_000,
        maxPages: Int = 5,
        maxClaims: Int = 10
    ) {
        self.maxPromptCharacters = max(2_000, maxPromptCharacters)
        self.maxPageCharacters = max(300, maxPageCharacters)
        self.maxRawCharacters = max(1_000, maxRawCharacters)
        self.maxPages = max(1, maxPages)
        self.maxClaims = max(1, maxClaims)
    }

    public func trimPrompt(_ value: String) -> String {
        trimmed(value, limit: maxPromptCharacters)
    }

    public func trimPage(_ value: String) -> String {
        trimmed(value, limit: maxPageCharacters)
    }

    public func trimRaw(_ value: String) -> String {
        trimmed(value, limit: maxRawCharacters)
    }

    private func trimmed(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        let head = value.prefix(limit / 2)
        let tail = value.suffix(limit / 3)
        return "\(head)\n\n[Context condensed by Hive.]\n\n\(tail)"
    }
}

public actor HiveFoundationModelsOrchestrator {
    public var mode: FoundationModelMemoryMode
    public var budget: HiveFoundationContextBudget

    public init(
        mode: FoundationModelMemoryMode = .foundationWhenAvailable,
        budget: HiveFoundationContextBudget = HiveFoundationContextBudget()
    ) {
        self.mode = mode
        self.budget = budget
    }

    public static func currentAvailability(mode: FoundationModelMemoryMode = .foundationWhenAvailable) -> FoundationModelMemoryAvailability {
        guard mode == .foundationWhenAvailable else { return .frameworkUnavailable }
        if let override = FoundationModelMemoryAvailability.environmentOverride {
            return override
        }
        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.supportsLocale(Locale.current) else {
                return .unsupportedLanguageOrLocale
            }
            switch model.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .appleIntelligenceNotEnabled:
                    return .appleIntelligenceDisabled
                case .deviceNotEligible:
                    return .deviceNotEligible
                case .modelNotReady:
                    return .modelNotReady
                @unknown default:
                    return .modelUnavailable
                }
            @unknown default:
                return .modelUnavailable
            }
        }
        return .osUnavailable
        #else
        return .frameworkUnavailable
        #endif
    }

    public func availability(for task: HiveFoundationTask) -> HiveFoundationTaskAvailability {
        HiveFoundationTaskAvailability(task: task, foundationAvailability: Self.currentAvailability(mode: mode))
    }

    public func prewarm(task: HiveFoundationTask, promptPrefix: String? = nil) async {
        guard Self.currentAvailability(mode: mode) == .available else { return }
        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let session = makeSession(task: task, context: HiveFoundationToolContext())
            session.prewarm(promptPrefix: promptPrefix.map { Prompt($0) })
        }
        #endif
    }

    public func answerChat(
        query: String,
        localAnswer: CitedAnswer,
        claims: [ClaimRecord],
        wikiPages: [WikiPageRecord],
        visibility: DerivedMemoryVisibility = .allowAll
    ) async -> HiveFoundationTaskResult<HiveChatAnswerProposal> {
        let task: HiveFoundationTask = .answerChat
        let availability = availability(for: task)
        let fallback = fallbackChatProposal(localAnswer: localAnswer, reason: fallbackReason(for: availability.foundationAvailability))
        guard availability.foundationAvailability == .available else {
            return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallback.attribution)
        }

        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let selectedPages = rankedPages(query: query, pages: wikiPages)
            let selectedClaims = rankedClaims(query: query, claims: claims, visibility: visibility)
            let context = HiveFoundationToolContext(wikiPages: wikiPages, sources: localAnswer.citations)
            let prompt = chatPrompt(query: query, localAnswer: localAnswer, pages: selectedPages, claims: selectedClaims)
            do {
                let generated = try await generateChatProposal(prompt: prompt, task: task, context: context, retryOnContextError: true)
                let proposal = chatProposal(from: generated, fallback: fallback, allowedSourceIDs: Set(localAnswer.citations.map(\.id)))
                guard validateChatProposal(proposal) else {
                    return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallback.attribution)
                }
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: proposal, usedFoundationModels: true)
            } catch {
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: error))
            }
        }
        #endif

        return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallback.attribution)
    }

    public func compileMemory(
        source: SourceRecord,
        extractedClaims: [ClaimRecord],
        existingClaims: [ClaimRecord],
        existingEntities: [EntityRecord],
        feedback: [FeedbackRecord] = [],
        fallback: MemoryCompilerDecisionEnvelope,
        now: Date = Date()
    ) async -> MemoryCompilerDecisionEnvelope {
        let task: HiveFoundationTask = .summarizeSource
        let availability = availability(for: task)
        guard availability.foundationAvailability == .available else { return fallback }

        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let proposalResult = try await sourceIngestProposal(
                    source: source,
                    extractedClaims: extractedClaims,
                    existingClaims: existingClaims,
                    existingEntities: existingEntities,
                    fallback: fallback.decision
                )
                let decision = proposalResult.memoryDecision(fallback: fallback.decision)
                guard validatesSourceReferences(proposalResult.claims.flatMap(\.sourceIDs), allowed: [source.id]) else {
                    return fallback
                }
                return MemoryCompilerDecisionEnvelope(
                    profile: .foundationGuided,
                    promptHash: fallback.promptHash,
                    storeStateHash: fallback.storeStateHash,
                    decision: decision,
                    generatedAt: now,
                    mutationPolicy: "model-output-is-proposal-only"
                )
            } catch {
                return fallback
            }
        }
        #endif

        return fallback
    }

    public func extractClaims(
        source: SourceRecord,
        extractedClaims: [ClaimRecord]
    ) async -> HiveFoundationTaskResult<ClaimExtractionProposal> {
        let task: HiveFoundationTask = .extractClaims
        let availability = availability(for: task)
        let fallback = ClaimExtractionProposal(
            sourceID: source.id,
            claims: extractedClaims.map {
                FoundationClaimProposal(
                    statement: $0.statement,
                    sourceIDs: $0.sourceRefs.filter { $0 == source.id },
                    confidenceLanguage: SourcePresentationModel.confidenceLanguage($0.confidence)
                )
            },
            requiresUserReview: false
        )
        guard availability.foundationAvailability == .available else {
            return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
        }

        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let generated = try await generateClaimExtractionProposal(
                    prompt: claimExtractionPrompt(source: source, extractedClaims: extractedClaims),
                    task: task,
                    context: HiveFoundationToolContext(sources: [source])
                )
                let proposal = ClaimExtractionProposal(
                    sourceID: source.id,
                    claims: generated.claims.map {
                        FoundationClaimProposal(statement: $0.statement, sourceIDs: $0.sourceIDs, confidenceLanguage: $0.confidenceLanguage)
                    },
                    requiresUserReview: generated.requiresUserReview
                )
                guard validatesSourceReferences(proposal.claims.flatMap(\.sourceIDs), allowed: [source.id]) else {
                    return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: "Local AI proposed unsupported claim sources.")
                }
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: proposal, usedFoundationModels: true)
            } catch {
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: error))
            }
        }
        #endif

        return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
    }

    public func extractEntities(
        source: SourceRecord,
        existingEntities: [EntityRecord]
    ) async -> HiveFoundationTaskResult<EntityExtractionProposal> {
        let task: HiveFoundationTask = .extractEntities
        let availability = availability(for: task)
        let fallback = EntityExtractionProposal(
            sourceID: source.id,
            entities: existingEntities
                .filter { !$0.sourceRefs.isEmpty && $0.sourceRefs.contains(source.id) }
                .map { FoundationEntityProposal(name: $0.name, kind: $0.entityType, sourceIDs: $0.sourceRefs) },
            requiresUserReview: false
        )
        guard availability.foundationAvailability == .available else {
            return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
        }

        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let generated = try await generateEntityExtractionProposal(
                    prompt: entityExtractionPrompt(source: source, existingEntities: existingEntities),
                    task: task,
                    context: HiveFoundationToolContext(sources: [source])
                )
                let proposal = EntityExtractionProposal(
                    sourceID: source.id,
                    entities: generated.entities.map {
                        FoundationEntityProposal(name: $0.name, kind: $0.kind, sourceIDs: $0.sourceIDs)
                    },
                    requiresUserReview: generated.requiresUserReview
                )
                guard validatesSourceReferences(proposal.entities.flatMap(\.sourceIDs), allowed: [source.id]) else {
                    return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: "Local AI proposed unsupported entity sources.")
                }
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: proposal, usedFoundationModels: true)
            } catch {
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: error))
            }
        }
        #endif

        return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
    }

    public func summarizeOnlineSource(
        sourceID: String,
        url: URL,
        capturedText: String,
        userPrompt: String? = nil
    ) async -> HiveFoundationTaskResult<OnlineSourceSummaryProposal> {
        let task: HiveFoundationTask = .summarizeOnlineSource
        let availability = availability(for: task)
        let fallbackTitle = url.host(percentEncoded: false) ?? "Approved web source"
        let fallback = OnlineSourceSummaryProposal(
            sourceID: sourceID,
            url: url.absoluteString,
            title: fallbackTitle,
            summary: String(capturedText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600)),
            keyIdeas: [],
            sourceIDs: [sourceID],
            requiresUserReview: true
        )
        guard URLSafetyPolicy().isAllowed(url) else {
            return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: "Unsafe or unapproved URL rejected before local AI.")
        }
        guard availability.foundationAvailability == .available else {
            return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
        }

        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let generated = try await generateOnlineSourceSummary(
                    prompt: onlineSourcePrompt(sourceID: sourceID, url: url, capturedText: capturedText, userPrompt: userPrompt),
                    task: task,
                    context: HiveFoundationToolContext(approvedWebText: [url.absoluteString: capturedText])
                )
                let proposal = OnlineSourceSummaryProposal(
                    sourceID: sourceID,
                    url: url.absoluteString,
                    title: generated.title,
                    summary: generated.summary,
                    keyIdeas: generated.keyIdeas,
                    sourceIDs: generated.sourceIDs,
                    requiresUserReview: generated.requiresUserReview
                )
                guard proposal.sourceIDs == [sourceID] else {
                    return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: "Local AI proposed unsupported web source IDs.")
                }
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: proposal, usedFoundationModels: true)
            } catch {
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: error))
            }
        }
        #endif

        return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
    }

    public func planColonyPatch(
        reason: String,
        pages: [WikiPageRecord],
        tasks: [WikiMaintenanceTask],
        fallback: WikiPatchProposal
    ) async -> HiveFoundationTaskResult<ColonyPatchProposal> {
        let task: HiveFoundationTask = .planColonyPatch
        let availability = availability(for: task)
        let fallbackProposal = ColonyPatchProposal(
            reason: fallback.reason,
            touchedPageIDs: fallback.touchedPageIDs,
            sourceIDs: [],
            operations: fallback.operations.map {
                FoundationColonyPatchOperation(
                    kind: $0.kind,
                    pageID: $0.pageID,
                    markdown: $0.markdown,
                    sectionTitle: $0.sectionTitle,
                    targetPageID: $0.targetPageID
                )
            },
            confidenceLanguage: fallback.confidenceLanguage,
            requiresUserReview: fallback.requiresUserReview
        )
        guard availability.foundationAvailability == .available else {
            return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallbackProposal, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
        }

        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let generated = try await generateColonyPatchProposal(
                    prompt: colonyPatchPrompt(reason: reason, pages: pages, tasks: tasks),
                    task: task,
                    context: HiveFoundationToolContext(wikiPages: pages)
                )
                let proposal = colonyPatchProposal(from: generated, fallback: fallbackProposal, pages: pages)
                let allowedPageIDs = Set(pages.map(\.id) + ["index", "log", "wiki-health"])
                guard Set(proposal.touchedPageIDs).isSubset(of: allowedPageIDs),
                      proposal.operations.allSatisfy({ allowedPageIDs.contains($0.pageID) }) else {
                    return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallbackProposal, usedFoundationModels: false, fallbackReason: "Local AI proposed an unsupported Colony edit.")
                }
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: proposal, usedFoundationModels: true)
            } catch {
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallbackProposal, usedFoundationModels: false, fallbackReason: fallbackReason(for: error))
            }
        }
        #endif

        return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallbackProposal, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
    }

    public func classifyGraphCoordinate(
        node: GraphNodeRecord,
        axisVocabulary: GraphAxisVocabulary = .current()
    ) async -> HiveFoundationTaskResult<GraphCoordinateProposal> {
        let task: HiveFoundationTask = .classifyGraphCoordinate
        let availability = availability(for: task)
        let deterministic = GraphCoordinateClassifier(axisVocabulary: axisVocabulary).unitCoordinate(for: node)
        let fallback = GraphCoordinateProposal(
            nodeID: node.id,
            x: deterministic.x,
            y: deterministic.y,
            label: node.title,
            rationale: axisVocabulary.semanticSummary,
            sourceIDs: node.sourceRefs,
            confidenceLanguage: SourcePresentationModel.confidenceLanguage(node.confidence)
        )
        guard availability.foundationAvailability == .available else {
            return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
        }

        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let generated = try await generateGraphCoordinateProposal(
                    prompt: graphCoordinatePrompt(node: node, axisVocabulary: axisVocabulary),
                    task: task,
                    context: HiveFoundationToolContext(graphNodes: [node])
                )
                let proposal = GraphCoordinateProposal(
                    nodeID: node.id,
                    x: generated.x,
                    y: generated.y,
                    label: generated.label,
                    rationale: generated.rationale,
                    sourceIDs: node.sourceRefs,
                    confidenceLanguage: generated.confidenceLanguage
                )
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: proposal, usedFoundationModels: true)
            } catch {
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: error))
            }
        }
        #endif

        return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
    }

    public func planGraphReindex(
        nodes: [GraphNodeRecord],
        edges: [GraphEdgeRecord],
        maxSteps: Int = 28
    ) async -> HiveFoundationTaskResult<GraphReindexProposal> {
        let task: HiveFoundationTask = .planGraphReindex
        let availability = availability(for: task)
        let coordinateFreeNodes = GraphReindexPlan.coordinateFreeInputNodes(nodes)
        let deterministic = GraphReindexPlan.make(nodes: coordinateFreeNodes, edges: edges, maxSteps: maxSteps)
        let fallback = GraphReindexProposal(
            steps: deterministic.steps,
            rationale: "Deterministic graph re-index from node text, axis vocabulary, and visible relationships.",
            sourceIDs: stableUnique(coordinateFreeNodes.flatMap(\.sourceRefs))
        )
        guard availability.foundationAvailability == .available else {
            return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
        }

        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let generated = try await generateGraphReindexProposal(
                    prompt: graphReindexPrompt(nodes: coordinateFreeNodes, edges: edges, fallback: deterministic),
                    task: task,
                    context: HiveFoundationToolContext(graphNodes: coordinateFreeNodes, graphEdges: edges)
                )
                let validNodeIDs = Set(coordinateFreeNodes.map(\.id))
                let steps = generated.steps.compactMap { step -> GraphReindexStep? in
                    guard validNodeIDs.contains(step.nodeID) else { return nil }
                    if let merged = step.mergedWithNodeID, !validNodeIDs.contains(merged) { return nil }
                    return GraphReindexStep(
                        id: step.id.isEmpty ? "foundation-\(step.nodeID)" : step.id,
                        nodeID: step.nodeID,
                        unitX: step.unitX,
                        unitY: step.unitY,
                        mergedWithNodeID: step.mergedWithNodeID,
                        mergedTitle: step.mergedTitle,
                        mergedSizeMultiplier: step.mergedSizeMultiplier,
                        operation: graphReindexOperation(from: step.operation, hasMerge: step.mergedWithNodeID != nil)
                    )
                }
                guard !steps.isEmpty else {
                    return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: "Local AI did not produce valid graph movement.")
                }
                let proposal = GraphReindexProposal(
                    steps: Array(steps.prefix(maxSteps)),
                    rationale: generated.rationale,
                    sourceIDs: fallback.sourceIDs,
                    requiresUserReview: generated.requiresUserReview
                )
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: proposal, usedFoundationModels: true)
            } catch {
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: error))
            }
        }
        #endif

        return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
    }

    public func reviewAxisVocabulary(_ vocabulary: GraphAxisVocabulary) async -> HiveFoundationTaskResult<AxisVocabularyReview> {
        let task: HiveFoundationTask = .reviewAxisVocabulary
        let availability = availability(for: task)
        let local = vocabulary.review
        let fallback = AxisVocabularyReview(isApproved: local.isApproved, message: local.message)
        guard availability.foundationAvailability == .available else {
            return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
        }

        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let generated = try await generateAxisVocabularyReview(
                    prompt: """
                    Review whether these Hive graph axis word pairs are real polar opposites.
                    Top: \(vocabulary.top)
                    Bottom: \(vocabulary.bottom)
                    Right: \(vocabulary.right)
                    Left: \(vocabulary.left)
                    Approve only if each pair is clearly distinguishable for placing personal memories.
                    """,
                    task: task
                )
                let proposal = AxisVocabularyReview(
                    isApproved: generated.isApproved,
                    message: generated.message,
                    suggestedTop: generated.suggestedTop,
                    suggestedBottom: generated.suggestedBottom,
                    suggestedRight: generated.suggestedRight,
                    suggestedLeft: generated.suggestedLeft
                )
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: proposal, usedFoundationModels: true)
            } catch {
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: error))
            }
        }
        #endif

        return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
    }

    public func recommendAction(
        appStateSummary: String,
        commands: [HiveFoundationCommandContext]
    ) async -> HiveFoundationTaskResult<RecommendedActionProposal> {
        let task: HiveFoundationTask = .recommendAction
        let availability = availability(for: task)
        let firstEnabled = commands.first { $0.defaultEnabled } ?? HiveFoundationCommandContext(id: "chat", title: "Ask Hive", requiresInput: true, inputPrompt: "Ask from local memory")
        let fallback = RecommendedActionProposal(
            commandID: firstEnabled.id,
            title: firstEnabled.title,
            reason: firstEnabled.requiresInput ? "Open the input flow before running this command." : "This command is available from the current Hive state.",
            requiredInputPrompt: firstEnabled.requiresInput ? firstEnabled.inputPrompt : nil,
            isEnabled: !firstEnabled.requiresInput
        )
        guard availability.foundationAvailability == .available else {
            return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
        }

        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            do {
                let commandList = commands.map { "\($0.id): \($0.title); needs input: \($0.requiresInput)" }.joined(separator: "\n")
                let generated = try await generateRecommendedAction(
                    prompt: """
                    Current Hive state:
                    \(budget.trimPrompt(appStateSummary))

                    Available commands:
                    \(commandList)

                    Pick one bounded recommendation. If the command needs missing input, mark it disabled and name the input flow to open.
                    """,
                    task: task
                )
                let knownCommandIDs = Set(commands.map(\.id))
                guard knownCommandIDs.contains(generated.commandID) else {
                    return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: "Local AI recommended an unknown command.")
                }
                let proposal = RecommendedActionProposal(
                    commandID: generated.commandID,
                    title: generated.title,
                    reason: generated.reason,
                    requiredInputPrompt: generated.requiredInputPrompt,
                    isEnabled: generated.isEnabled,
                    sourceIDs: generated.sourceIDs
                )
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: proposal, usedFoundationModels: true)
            } catch {
                return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: error))
            }
        }
        #endif

        return HiveFoundationTaskResult(task: task, availability: availability, proposal: fallback, usedFoundationModels: false, fallbackReason: fallbackReason(for: availability.foundationAvailability))
    }

    public func rankWikiPages(query: String, pages: [WikiPageRecord], limit: Int = 8) async -> [WikiSearchResult] {
        WikiSearchRouter().searchWiki(query: query, pages: pages, limit: limit, mode: .automatic)
    }

    private func fallbackChatProposal(localAnswer: CitedAnswer, reason: String) -> HiveChatAnswerProposal {
        HiveChatAnswerProposal(
            answer: localAnswer.answer,
            sourceIDs: localAnswer.citations.map(\.id),
            attribution: reason,
            certainty: localAnswer.citations.isEmpty ? "missingLocalContext" : "partialLocalContext",
            correctionOptions: HiveMLPresentationPolicy.recoverySuggestions(forLowConfidence: localAnswer.citations.isEmpty),
            requiresUserReview: false
        )
    }

    private func fallbackReason(for availability: FoundationModelMemoryAvailability) -> String {
        switch availability {
        case .available:
            return "Local AI"
        case .appleIntelligenceDisabled:
            return "Local AI is off; Hive answered from The Colony."
        case .deviceNotEligible:
            return "This device does not support local AI; Hive answered from The Colony."
        case .modelNotReady:
            return "Local AI is still getting ready; Hive answered from The Colony."
        case .unsupportedLanguageOrLocale:
            return "Local AI does not support this language here yet; Hive answered from The Colony."
        case .osUnavailable:
            return "This OS cannot run local AI for Hive yet; Hive answered from The Colony."
        case .frameworkUnavailable:
            return "Local AI is not available in this build; Hive answered from The Colony."
        case .modelUnavailable:
            return "Local AI is unavailable; Hive answered from The Colony."
        }
    }

    private func fallbackReason(for error: Error) -> String {
        #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if case LanguageModelSession.GenerationError.exceededContextWindowSize = error {
                return "Local AI needed narrower context; Hive answered from The Colony."
            }
            if case LanguageModelSession.GenerationError.unsupportedLanguageOrLocale = error {
                return "Local AI does not support this language here yet; Hive answered from The Colony."
            }
        }
        #endif
        return "Local AI was unavailable for this task; Hive used deterministic local behavior."
    }

    private func rankedPages(query: String, pages: [WikiPageRecord]) -> [WikiPageRecord] {
        let hits = WikiSearchRouter().searchWiki(query: query, pages: pages, limit: budget.maxPages, mode: .automatic)
        let byID = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0) })
        let selected = hits.compactMap { byID[$0.pageID] }
        return selected.isEmpty ? Array(pages.filter(\.isUserVisibleArticle).prefix(budget.maxPages)) : selected
    }

    private func rankedClaims(query: String, claims: [ClaimRecord], visibility: DerivedMemoryVisibility) -> [ClaimRecord] {
        let terms = searchTokens(query)
        return claims
            .filter { $0.status != .retracted && visibility.shouldAnswerFromClaim($0) }
            .map { ($0, searchTokens($0.statement).intersection(terms).count) }
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 == $1.1 { return $0.0.confidence > $1.0.confidence }
                return $0.1 > $1.1
            }
            .prefix(budget.maxClaims)
            .map(\.0)
    }

    private func chatPrompt(query: String, localAnswer: CitedAnswer, pages: [WikiPageRecord], claims: [ClaimRecord]) -> String {
        let pageContext = pages.map { page in
            """
            Page ID: \(page.id)
            Title: \(SourcePresentationModel.cleanTitle(page.title))
            Summary: \(page.summary)
            Excerpt: \(budget.trimPage(page.markdown))
            """
        }.joined(separator: "\n\n")
        let claimContext = claims.map { "Claim source IDs: \($0.sourceRefs.joined(separator: ", ")); \($0.statement)" }.joined(separator: "\n")
        return budget.trimPrompt("""
        User question:
        \(query)

        Deterministic local draft:
        \(localAnswer.answer)

        Colony page context:
        \(pageContext.isEmpty ? "No matching Colony pages." : pageContext)

        Maintained claims:
        \(claimContext.isEmpty ? "No matching maintained claims." : claimContext)

        Constraints:
        - Answer only from The Colony, maintained claims, or the local draft.
        - Include only source IDs from the supplied local context.
        - If evidence is thin, say what Hive knows and what is missing.
        - Keep it concise.
        - Do not mention model names, implementation details, raw filenames, URLs, markdown syntax, or percentages.
        """)
    }

    private func colonyPatchPrompt(reason: String, pages: [WikiPageRecord], tasks: [WikiMaintenanceTask]) -> String {
        let pageContext = pages.prefix(budget.maxPages).map { page in
            "\(page.id): \(page.title)\nSummary: \(page.summary)\n\(budget.trimPage(page.markdown))"
        }.joined(separator: "\n\n")
        let taskContext = tasks.prefix(12).map { "\($0.kind.rawValue): \($0.title) - \($0.detail)" }.joined(separator: "\n")
        return budget.trimPrompt("""
        Plan a proposal-only Colony patch.
        Reason: \(reason)

        Maintenance tasks:
        \(taskContext)

        Candidate pages:
        \(pageContext)

        Use section-level reversible operations. Do not delete raw sources. Contradictions become review items.
        """)
    }

    private func claimExtractionPrompt(source: SourceRecord, extractedClaims: [ClaimRecord]) -> String {
        budget.trimPrompt("""
        Extract durable claims from one immutable Field source.
        Source ID: \(source.id)
        Source title: \(source.title)
        Source kind: \(source.kind.rawValue)

        Existing deterministic claim candidates:
        \(extractedClaims.prefix(budget.maxClaims).map { "- \($0.statement); sources: \($0.sourceRefs.joined(separator: ","))" }.joined(separator: "\n"))

        \(ExtractionQualityRules.systemPrompt)

        Return only claims grounded in source ID \(source.id). Do not create facts that are not supported by this source.
        """)
    }

    private func entityExtractionPrompt(source: SourceRecord, existingEntities: [EntityRecord]) -> String {
        budget.trimPrompt("""
        Extract durable entities or topics from one immutable Field source.
        Source ID: \(source.id)
        Source title: \(source.title)
        Source kind: \(source.kind.rawValue)

        Existing entity context:
        \(existingEntities.prefix(18).map { "- \($0.id): \($0.name); \($0.entityType)" }.joined(separator: "\n"))

        \(ExtractionQualityRules.systemPrompt)

        Return only entities grounded in source ID \(source.id). Prefer stable people, projects, organizations, ideas, and recurring topics.
        """)
    }

    private func onlineSourcePrompt(sourceID: String, url: URL, capturedText: String, userPrompt: String?) -> String {
        let resolvedPrompt = userPrompt.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? "Fold durable knowledge into existing Colony articles."
        budget.trimPrompt("""
        Summarize one user-approved online source capture.
        Source ID: \(sourceID)
        Approved URL: \(url.absoluteString)
        User prompt: \(resolvedPrompt)

        Captured text:
        \(budget.trimRaw(capturedText))

        \(ExtractionQualityRules.systemPrompt)

        Return a proposal only. Use source ID \(sourceID). Do not browse, crawl, or request other URLs.
        """)
    }

    private func graphCoordinatePrompt(node: GraphNodeRecord, axisVocabulary: GraphAxisVocabulary) -> String {
        budget.trimPrompt("""
        Place this Hive memory on semantic axes.
        \(axisVocabulary.semanticSummary)
        Node ID: \(node.id)
        Title: \(node.title)
        Kind: \(node.kind.rawValue)
        Layer: \(node.memoryLayer.rawValue)
        Source IDs: \(node.sourceRefs.joined(separator: ", "))
        Return x and y in the range -1 to 1.
        """)
    }

    private func graphReindexPrompt(nodes: [GraphNodeRecord], edges: [GraphEdgeRecord], fallback: GraphReindexPlan) -> String {
        let nodeLines = nodes.prefix(96).map { node in
            "\(node.id): \(node.title); kind \(node.kind.rawValue); layer \(node.memoryLayer.rawValue); confidence \(String(format: "%.2f", node.confidence)); sources \(node.sourceRefs.joined(separator: ","))"
        }.joined(separator: "\n")
        let edgeLines = edges.filter(GraphRelationshipPolicy.isVisibleConnection).prefix(80).map { "\($0.fromID) -> \($0.toID); \($0.predicate.rawValue); strength \($0.strength)" }.joined(separator: "\n")
        return budget.trimPrompt("""
        Plan a Hive re-index proposal. Ignore every existing graph coordinate; assign fresh x/y targets only from node meaning, axis vocabulary, source references, and visible relationships. Hive will animate only accepted final targets. Do not copy a fixed spatial pattern.
        Nodes:
        \(nodeLines)

        Visible edges:
        \(edgeLines)

        Deterministic fallback candidate count: \(fallback.steps.count)

        Keep coordinates in -1 to 1. Use operation move, reconnect, split, consolidate, delete, create, or edgeCheck. Consolidate only strong duplicate or closely related memories. Delete only if a graph node is clearly redundant and unsupported by source context. Treat edgeCheck as a pairwise relationship audit after node moves finish. Prefer 3 to 5 active notes per audit batch; some ambiguous or consolidating steps should be slower than simple moves.
        """)
    }

    private func graphReindexOperation(from generated: String?, hasMerge: Bool) -> GraphReindexOperation {
        guard let generated else { return hasMerge ? .consolidate : .move }
        let normalized = generated.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return GraphReindexOperation(rawValue: normalized) ?? (hasMerge ? .consolidate : .move)
    }

    private func searchTokens(_ text: String) -> Set<String> {
        let stopwords: Set<String> = ["about", "after", "alone", "and", "are", "because", "been", "claim", "from", "have", "history", "into", "local", "more", "not", "that", "the", "this", "with", "without", "what", "when", "where", "which", "would", "could", "should"]
        return Set(text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 && !stopwords.contains($0) })
    }

    private func validateChatProposal(_ proposal: HiveChatAnswerProposal) -> Bool {
        let cleaned = proposal.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count > 10
            && !cleaned.localizedCaseInsensitiveContains("http://")
            && !cleaned.localizedCaseInsensitiveContains("https://")
            && !cleaned.contains("%")
    }

    private func validatesSourceReferences(_ proposed: [String], allowed: [String]) -> Bool {
        let allowedSet = Set(allowed)
        return Set(proposed).isSubset(of: allowedSet)
    }

    #if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func makeSession(task: HiveFoundationTask, context: HiveFoundationToolContext) -> LanguageModelSession {
        LanguageModelSession(
            model: .default,
            tools: [
                SearchColonyPagesTool(pages: context.wikiPages, limit: budget.maxPages),
                GetColonyPagesTool(pages: context.wikiPages),
                GetBacklinksTool(pages: context.wikiPages),
                GetGraphNeighborhoodTool(nodes: context.graphNodes, edges: context.graphEdges),
                SearchFlowerFieldMetadataTool(sources: context.sources),
                FetchApprovedWebPageTool(approvedWebText: context.approvedWebText),
                ExtractApprovedWebTextTool(approvedWebText: context.approvedWebText)
            ],
            instructions: Instructions("""
            You are Hive's private on-device task engine for \(task.rawValue).
            Use only supplied context or read-only tools. Tools return context only and never mutate Field, The Colony, settings, or The Hive.
            Return the requested structured proposal. Every claim, edit, summary, graph move, or recommendation must be grounded in a supplied source ID, Colony page, graph node, or approved captured web context.
            Keep language restrained and useful. Do not expose implementation names in user-facing strings.
            """)
        )
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func generateChatProposal(
        prompt: String,
        task: HiveFoundationTask,
        context: HiveFoundationToolContext,
        retryOnContextError: Bool
    ) async throws -> GeneratedHiveChatAnswerProposal {
        let session = makeSession(task: task, context: context)
        do {
            let response = try await session.respond(
                to: Prompt(prompt),
                generating: GeneratedHiveChatAnswerProposal.self,
                includeSchemaInPrompt: true,
                options: GenerationOptions(temperature: 0.2)
            )
            return response.content
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize where retryOnContextError {
            let response = try await makeSession(task: task, context: context).respond(
                to: Prompt(budget.trimPrompt(prompt)),
                generating: GeneratedHiveChatAnswerProposal.self,
                includeSchemaInPrompt: true,
                options: GenerationOptions(temperature: 0.1)
            )
            return response.content
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func sourceIngestProposal(
        source: SourceRecord,
        extractedClaims: [ClaimRecord],
        existingClaims: [ClaimRecord],
        existingEntities: [EntityRecord],
        fallback: MemoryCompilationDecision
    ) async throws -> SourceIngestProposal {
        let prompt = budget.trimPrompt("""
        Build a proposal for one immutable Field source.
        Source ID: \(source.id)
        Source kind: \(source.kind.rawValue)
        Source title: \(source.title)

        Candidate claims:
        \(extractedClaims.prefix(budget.maxClaims).map { "- \($0.statement); sources: \($0.sourceRefs.joined(separator: ","))" }.joined(separator: "\n"))

        Existing claims:
        \(existingClaims.prefix(12).map { "- \($0.id): \($0.statement)" }.joined(separator: "\n"))

        Existing entities:
        \(existingEntities.prefix(12).map { "- \($0.id): \($0.name)" }.joined(separator: "\n"))

        Deterministic fallback:
        \(fallback.kind.rawValue); \(fallback.reason); target: \(fallback.targetID ?? "-"); statement: \(fallback.proposedStatement ?? "-")

        \(ExtractionQualityRules.systemPrompt)

        Return a proposal only. Every generated claim/entity must cite the source ID \(source.id). Do not mutate raw material.
        """)
        let response = try await makeSession(task: .summarizeSource, context: HiveFoundationToolContext(sources: [source])).respond(
            to: Prompt(prompt),
            generating: GeneratedSourceIngestProposal.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(temperature: 0.15)
        )
        return sourceIngestProposal(from: response.content, source: source, fallback: fallback)
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func generateColonyPatchProposal(
        prompt: String,
        task: HiveFoundationTask,
        context: HiveFoundationToolContext
    ) async throws -> GeneratedColonyPatchProposal {
        let response = try await makeSession(task: task, context: context).respond(
            to: Prompt(prompt),
            generating: GeneratedColonyPatchProposal.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(temperature: 0.15)
        )
        return response.content
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func generateClaimExtractionProposal(
        prompt: String,
        task: HiveFoundationTask,
        context: HiveFoundationToolContext
    ) async throws -> GeneratedClaimExtractionProposal {
        let response = try await makeSession(task: task, context: context).respond(
            to: Prompt(prompt),
            generating: GeneratedClaimExtractionProposal.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(temperature: 0.1)
        )
        return response.content
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func generateEntityExtractionProposal(
        prompt: String,
        task: HiveFoundationTask,
        context: HiveFoundationToolContext
    ) async throws -> GeneratedEntityExtractionProposal {
        let response = try await makeSession(task: task, context: context).respond(
            to: Prompt(prompt),
            generating: GeneratedEntityExtractionProposal.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(temperature: 0.1)
        )
        return response.content
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func generateOnlineSourceSummary(
        prompt: String,
        task: HiveFoundationTask,
        context: HiveFoundationToolContext
    ) async throws -> GeneratedOnlineSourceSummaryProposal {
        let response = try await makeSession(task: task, context: context).respond(
            to: Prompt(prompt),
            generating: GeneratedOnlineSourceSummaryProposal.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(temperature: 0.15)
        )
        return response.content
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func generateGraphCoordinateProposal(
        prompt: String,
        task: HiveFoundationTask,
        context: HiveFoundationToolContext
    ) async throws -> GeneratedGraphCoordinateProposal {
        let response = try await makeSession(task: task, context: context).respond(
            to: Prompt(prompt),
            generating: GeneratedGraphCoordinateProposal.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(temperature: 0.1)
        )
        return response.content
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func generateGraphReindexProposal(
        prompt: String,
        task: HiveFoundationTask,
        context: HiveFoundationToolContext
    ) async throws -> GeneratedGraphReindexProposal {
        let response = try await makeSession(task: task, context: context).respond(
            to: Prompt(prompt),
            generating: GeneratedGraphReindexProposal.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(temperature: 0.1)
        )
        return response.content
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func generateAxisVocabularyReview(prompt: String, task: HiveFoundationTask) async throws -> GeneratedAxisVocabularyReview {
        let response = try await makeSession(task: task, context: HiveFoundationToolContext()).respond(
            to: Prompt(prompt),
            generating: GeneratedAxisVocabularyReview.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(temperature: 0.1)
        )
        return response.content
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func generateRecommendedAction(prompt: String, task: HiveFoundationTask) async throws -> GeneratedRecommendedActionProposal {
        let response = try await makeSession(task: task, context: HiveFoundationToolContext()).respond(
            to: Prompt(prompt),
            generating: GeneratedRecommendedActionProposal.self,
            includeSchemaInPrompt: true,
            options: GenerationOptions(temperature: 0.1)
        )
        return response.content
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func chatProposal(
        from generated: GeneratedHiveChatAnswerProposal,
        fallback: HiveChatAnswerProposal,
        allowedSourceIDs: Set<String>
    ) -> HiveChatAnswerProposal {
        let sourceIDs = generated.sourceIDs.filter { allowedSourceIDs.contains($0) }
        return HiveChatAnswerProposal(
            answer: generated.answer,
            sourceIDs: sourceIDs.isEmpty ? fallback.sourceIDs : sourceIDs,
            attribution: generated.attribution.isEmpty ? "Local AI" : generated.attribution,
            certainty: generated.certainty.code,
            correctionOptions: stableUnique(generated.correctionOptions + ["File answer to The Colony", "Ask a narrower question"]),
            requiresUserReview: generated.requiresUserReview
        )
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func sourceIngestProposal(
        from generated: GeneratedSourceIngestProposal,
        source: SourceRecord,
        fallback: MemoryCompilationDecision
    ) -> SourceIngestProposal {
        let decisionKind = generated.decisionKind.memoryDecisionKind
        return SourceIngestProposal(
            sourceID: source.id,
            summary: generated.summary,
            claims: generated.claims.map {
                FoundationClaimProposal(statement: $0.statement, sourceIDs: $0.sourceIDs.filter { $0 == source.id }, confidenceLanguage: $0.confidenceLanguage)
            },
            entities: generated.entities.map {
                FoundationEntityProposal(name: $0.name, kind: $0.kind, sourceIDs: $0.sourceIDs.filter { $0 == source.id })
            },
            contradictions: generated.contradictions,
            privacySensitivity: generated.privacySensitivity.privacyLabel,
            graphCandidates: generated.graphCandidates.map {
                GraphCoordinateProposal(nodeID: $0.nodeID, x: $0.x, y: $0.y, label: $0.label, rationale: $0.rationale, sourceIDs: $0.sourceIDs.filter { $0 == source.id }, confidenceLanguage: $0.confidenceLanguage)
            },
            decisionKind: decisionKind,
            targetID: generated.targetID,
            proposedStatement: generated.proposedStatement,
            confidence: generated.confidence,
            requiresUserReview: generated.requiresUserReview
        )
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func colonyPatchProposal(
        from generated: GeneratedColonyPatchProposal,
        fallback: ColonyPatchProposal,
        pages: [WikiPageRecord]
    ) -> ColonyPatchProposal {
        let allowed = Set(pages.map(\.id) + ["index", "log", "wiki-health"])
        let operations = generated.operations.compactMap { operation -> FoundationColonyPatchOperation? in
            guard allowed.contains(operation.pageID) else { return nil }
            let kind = operation.kind.operationKind
            return FoundationColonyPatchOperation(
                kind: kind,
                pageID: operation.pageID,
                markdown: operation.markdown,
                sectionTitle: operation.sectionTitle,
                targetPageID: operation.targetPageID
            )
        }
        return ColonyPatchProposal(
            reason: generated.reason.isEmpty ? fallback.reason : generated.reason,
            touchedPageIDs: generated.touchedPageIDs.filter { allowed.contains($0) },
            sourceIDs: generated.sourceIDs,
            operations: operations.isEmpty ? fallback.operations : operations,
            confidenceLanguage: generated.confidenceLanguage,
            requiresUserReview: generated.requiresUserReview || fallback.requiresUserReview
        )
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable(description: "A concise Hive answer grounded in local Colony context")
    struct GeneratedHiveChatAnswerProposal {
        @Guide(description: "A concise answer grounded only in supplied local context")
        let answer: String
        @Guide(description: "Source IDs used from the supplied local context")
        let sourceIDs: [String]
        @Guide(description: "Short factual attribution, not a model explanation")
        let attribution: String
        let certainty: Certainty
        @Guide(description: "Three short correction or follow-up options", .count(3))
        let correctionOptions: [String]
        let requiresUserReview: Bool

        @Generable
        enum Certainty {
            case enoughLocalContext
            case partialLocalContext
            case missingLocalContext

            var code: String {
                switch self {
                case .enoughLocalContext: return "enoughLocalContext"
                case .partialLocalContext: return "partialLocalContext"
                case .missingLocalContext: return "missingLocalContext"
                }
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable(description: "A proposal for integrating one Field source")
    struct GeneratedSourceIngestProposal {
        let summary: String
        @Guide(description: "Claims grounded in the supplied source ID")
        let claims: [GeneratedClaimProposal]
        @Guide(description: "Entities or topics grounded in the supplied source ID")
        let entities: [GeneratedEntityProposal]
        let contradictions: [String]
        let privacySensitivity: GeneratedPrivacySensitivity
        let graphCandidates: [GeneratedGraphCoordinateProposal]
        let decisionKind: GeneratedMemoryDecisionKind
        let targetID: String?
        let proposedStatement: String?
        let confidence: Double
        let requiresUserReview: Bool

        @Generable
        enum GeneratedPrivacySensitivity {
            case normal
            case privateSource
            case sensitive
            case cloudBlocked

            var privacyLabel: String {
                switch self {
                case .normal: return "normal"
                case .privateSource: return "privateSource"
                case .sensitive: return "sensitive"
                case .cloudBlocked: return "cloudBlocked"
                }
            }
        }

        @Generable
        enum GeneratedMemoryDecisionKind {
            case ignore
            case askClarifyingQuestion
            case mergeIntoExisting
            case createMemory
            case updateMemory
            case retractMemory

            var memoryDecisionKind: MemoryCompilationDecisionKind {
                switch self {
                case .ignore: return .ignore
                case .askClarifyingQuestion: return .askClarifyingQuestion
                case .mergeIntoExisting: return .mergeIntoExisting
                case .createMemory: return .createMemory
                case .updateMemory: return .updateMemory
                case .retractMemory: return .retractMemory
                }
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable
    struct GeneratedClaimProposal {
        let statement: String
        let sourceIDs: [String]
        let confidenceLanguage: String
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable
    struct GeneratedEntityProposal {
        let name: String
        let kind: String
        let sourceIDs: [String]
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable(description: "Claim extraction proposal for one immutable source")
    struct GeneratedClaimExtractionProposal {
        let claims: [GeneratedClaimProposal]
        let requiresUserReview: Bool
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable(description: "Entity extraction proposal for one immutable source")
    struct GeneratedEntityExtractionProposal {
        let entities: [GeneratedEntityProposal]
        let requiresUserReview: Bool
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable(description: "Summary proposal for one approved online source capture")
    struct GeneratedOnlineSourceSummaryProposal {
        let title: String
        let summary: String
        @Guide(description: "Three to five durable ideas grounded in this captured source")
        let keyIdeas: [String]
        let sourceIDs: [String]
        let requiresUserReview: Bool
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable(description: "A proposal for section-level Colony maintenance")
    struct GeneratedColonyPatchProposal {
        let reason: String
        let touchedPageIDs: [String]
        let sourceIDs: [String]
        let operations: [GeneratedColonyPatchOperation]
        let confidenceLanguage: String
        let requiresUserReview: Bool
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable
    struct GeneratedColonyPatchOperation {
        let kind: GeneratedWikiPatchOperationKind
        let pageID: String
        let markdown: String
        let sectionTitle: String?
        let targetPageID: String?

        @Generable
        enum GeneratedWikiPatchOperationKind {
            case replaceSection
            case insertSection
            case mergePageIntoPage
            case addBacklink
            case updateFrontmatter
            case appendLogEntry
            case markReviewNeeded

            var operationKind: WikiPatchOperationKind {
                switch self {
                case .replaceSection: return .replaceSection
                case .insertSection: return .insertSection
                case .mergePageIntoPage: return .mergePageIntoPage
                case .addBacklink: return .addBacklink
                case .updateFrontmatter: return .updateFrontmatter
                case .appendLogEntry: return .appendLogEntry
                case .markReviewNeeded: return .markReviewNeeded
                }
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable(description: "Hive graph coordinate proposal")
    struct GeneratedGraphCoordinateProposal {
        let nodeID: String
        let x: Double
        let y: Double
        let label: String
        let rationale: String
        let sourceIDs: [String]
        let confidenceLanguage: String
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable(description: "Hive graph re-index proposal")
    struct GeneratedGraphReindexProposal {
        let steps: [GeneratedGraphReindexStep]
        let rationale: String
        let requiresUserReview: Bool
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable
    struct GeneratedGraphReindexStep {
        let id: String
        let nodeID: String
        @Guide(description: "Fresh x-axis target from -1.0 creative to 1.0 analytical. Never copy an existing graph coordinate.")
        let unitX: Double
        @Guide(description: "Fresh y-axis target from -1.0 personal to 1.0 professional. Never copy an existing graph coordinate.")
        let unitY: Double
        @Guide(description: "One of move, reconnect, split, consolidate, delete, create, or edgeCheck.")
        let operation: String?
        let mergedWithNodeID: String?
        let mergedTitle: String?
        let mergedSizeMultiplier: Double
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable(description: "Axis vocabulary polarity review")
    struct GeneratedAxisVocabularyReview {
        let isApproved: Bool
        let message: String
        let suggestedTop: String?
        let suggestedBottom: String?
        let suggestedRight: String?
        let suggestedLeft: String?
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    @Generable(description: "A bounded Hive command recommendation")
    struct GeneratedRecommendedActionProposal {
        let commandID: String
        let title: String
        let reason: String
        let requiredInputPrompt: String?
        let isEnabled: Bool
        let sourceIDs: [String]
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    struct SearchColonyPagesTool: Tool {
        let name = "searchColonyPages"
        let description = "Searches Hive's maintained Colony pages and returns concise page context."
        let pages: [WikiPageRecord]
        let limit: Int

        @Generable
        struct Arguments {
            let query: String
        }

        func call(arguments: Arguments) async throws -> String {
            let hits = WikiSearchRouter().searchWiki(query: arguments.query, pages: pages, limit: limit, mode: .automatic)
            guard !hits.isEmpty else { return "No matching Colony pages." }
            return hits.map { "\($0.pageID): \($0.title)\n\($0.summary)\n\($0.snippet)" }.joined(separator: "\n\n")
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    struct GetColonyPagesTool: Tool {
        let name = "getColonyPages"
        let description = "Gets concise content for known Colony page IDs."
        let pages: [WikiPageRecord]

        @Generable
        struct Arguments {
            let pageIDs: [String]
        }

        func call(arguments: Arguments) async throws -> String {
            let pageMap = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0) })
            return arguments.pageIDs.compactMap { id in
                pageMap[id].map { "\($0.id): \($0.title)\n\($0.summary)\n\(String($0.markdown.prefix(1_200)))" }
            }.joined(separator: "\n\n")
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    struct GetBacklinksTool: Tool {
        let name = "getBacklinks"
        let description = "Returns Colony pages that link to a page."
        let pages: [WikiPageRecord]

        @Generable
        struct Arguments {
            let pageID: String
        }

        func call(arguments: Arguments) async throws -> String {
            let toolbox = HiveWikiToolbox(pages: pages)
            let backlinks = toolbox.backlinks(pageID: arguments.pageID)
            guard !backlinks.isEmpty else { return "No backlinks." }
            return backlinks.map { "\($0.id): \($0.title) - \($0.summary)" }.joined(separator: "\n")
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    struct GetGraphNeighborhoodTool: Tool {
        let name = "getGraphNeighborhood"
        let description = "Returns direct Hive graph neighbors for a node."
        let nodes: [GraphNodeRecord]
        let edges: [GraphEdgeRecord]

        @Generable
        struct Arguments {
            let nodeID: String
        }

        func call(arguments: Arguments) async throws -> String {
            let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
            let lines = edges.filter(GraphRelationshipPolicy.isVisibleConnection).compactMap { edge -> String? in
                let otherID: String
                if edge.fromID == arguments.nodeID {
                    otherID = edge.toID
                } else if edge.toID == arguments.nodeID {
                    otherID = edge.fromID
                } else {
                    return nil
                }
                guard let other = nodeMap[otherID] else { return nil }
                return "\(other.id): \(other.title); \(edge.predicate.rawValue); strength \(edge.strength)"
            }
            return lines.isEmpty ? "No direct graph neighbors." : lines.joined(separator: "\n")
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    struct SearchFlowerFieldMetadataTool: Tool {
        let name = "searchFlowerFieldMetadata"
        let description = "Searches immutable Field source metadata."
        let sources: [SourceRecord]

        @Generable
        struct Arguments {
            let query: String
        }

        func call(arguments: Arguments) async throws -> String {
            let terms = Set(arguments.query.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 })
            let matches = sources.filter { source in
                let text = "\(source.title) \(source.kind.rawValue) \(source.connector)".lowercased()
                return terms.isEmpty || terms.contains { text.contains($0) }
            }.prefix(12)
            return matches.map { "\($0.id): \($0.title); \($0.kind.rawValue); \(SourcePresentationModel.relativeAge(from: $0.importedAt))" }.joined(separator: "\n")
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    struct FetchApprovedWebPageTool: Tool {
        let name = "fetchApprovedWebPage"
        let description = "Returns text for a user-approved web URL already captured by Hive."
        let approvedWebText: [String: String]

        @Generable
        struct Arguments {
            let url: String
        }

        func call(arguments: Arguments) async throws -> String {
            guard let url = URL(string: arguments.url), URLSafetyPolicy().isAllowed(url) else {
                return "URL is not approved for Hive web context."
            }
            return approvedWebText[arguments.url] ?? approvedWebText[url.absoluteString] ?? "No approved captured text for this URL."
        }
    }

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    struct ExtractApprovedWebTextTool: Tool {
        let name = "extractApprovedWebText"
        let description = "Extracts a concise excerpt from user-approved captured web text."
        let approvedWebText: [String: String]

        @Generable
        struct Arguments {
            let url: String
            let query: String
        }

        func call(arguments: Arguments) async throws -> String {
            guard let url = URL(string: arguments.url), URLSafetyPolicy().isAllowed(url) else {
                return "URL is not approved for Hive web context."
            }
            guard let text = approvedWebText[arguments.url] ?? approvedWebText[url.absoluteString], !text.isEmpty else {
                return "No approved captured text for this URL."
            }
            let terms = arguments.query.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 }
            let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            let matches = sentences.filter { sentence in
                let lower = sentence.lowercased()
                return terms.isEmpty || terms.contains { lower.contains($0) }
            }.prefix(5)
            let excerpt = matches.joined(separator: ". ")
            return excerpt.isEmpty ? String(text.prefix(1_200)) : excerpt
        }
    }
    #endif
}

private extension FoundationModelMemoryAvailability {
    static var environmentOverride: FoundationModelMemoryAvailability? {
        let raw = ProcessInfo.processInfo.environment["HIVE_FOUNDATION_MODELS_AVAILABILITY_OVERRIDE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let raw, !raw.isEmpty else { return nil }
        switch raw {
        case "available":
            return .available
        case "frameworkunavailable", "framework-unavailable", "framework_unavailable":
            return .frameworkUnavailable
        case "osunavailable", "os-unavailable", "os_unavailable":
            return .osUnavailable
        case "modelunavailable", "model-unavailable", "model_unavailable":
            return .modelUnavailable
        case "appleintelligencedisabled", "apple-intelligence-disabled", "apple_intelligence_disabled", "disabled":
            return .appleIntelligenceDisabled
        case "devicenoteligible", "device-not-eligible", "device_not_eligible":
            return .deviceNotEligible
        case "modelnotready", "model-not-ready", "model_not_ready", "not-ready":
            return .modelNotReady
        case "unsupportedlanguageorlocale", "unsupported-language-or-locale", "unsupported_language_or_locale", "unsupported-locale":
            return .unsupportedLanguageOrLocale
        default:
            return FoundationModelMemoryAvailability(rawValue: raw)
        }
    }
}

private func stableUnique(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for value in values {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, seen.insert(cleaned).inserted else { continue }
        result.append(cleaned)
    }
    return result
}
