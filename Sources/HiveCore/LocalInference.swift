import Foundation

#if canImport(HuggingFace) && canImport(MLXHuggingFace) && canImport(MLXLLM) && canImport(MLXLMCommon) && canImport(Tokenizers) && !os(watchOS)
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
#endif

public enum InferenceJobKind: String, Codable, CaseIterable, Sendable {
    case summarizeRawSource
    case synthesizeMemory
    case maintainWiki
    case answerChat
}

public enum InferenceJobPriority: String, Codable, CaseIterable, Sendable {
    case background
    case normal
    case userInitiated
}

public struct LocalInferenceJob: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: InferenceJobKind
    public var sourceID: String?
    public var prompt: String
    public var priority: InferenceJobPriority
    public var createdAt: Date
    public var manual: Bool

    public init(
        id: String = UUID().uuidString,
        kind: InferenceJobKind,
        sourceID: String? = nil,
        prompt: String,
        priority: InferenceJobPriority = .normal,
        createdAt: Date = Date(),
        manual: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.sourceID = sourceID
        self.prompt = prompt
        self.priority = priority
        self.createdAt = createdAt
        self.manual = manual
    }
}

public struct InferenceResourceBudget: Hashable, Sendable {
    public var maxResidentMemoryBytes: UInt64
    public var unloadAfterIdleSeconds: TimeInterval
    public var allowsBackgroundLoad: Bool
    public var maxQueuedJobsPerCycle: Int

    public init(
        maxResidentMemoryBytes: UInt64 = 8 * 1_073_741_824,
        unloadAfterIdleSeconds: TimeInterval = 90,
        allowsBackgroundLoad: Bool = true,
        maxQueuedJobsPerCycle: Int = 3
    ) {
        self.maxResidentMemoryBytes = maxResidentMemoryBytes
        self.unloadAfterIdleSeconds = unloadAfterIdleSeconds
        self.allowsBackgroundLoad = allowsBackgroundLoad
        self.maxQueuedJobsPerCycle = maxQueuedJobsPerCycle
    }

    public static func baseM4Background() -> InferenceResourceBudget {
        InferenceResourceBudget(
            maxResidentMemoryBytes: 6 * 1_073_741_824,
            unloadAfterIdleSeconds: 45,
            allowsBackgroundLoad: true,
            maxQueuedJobsPerCycle: 2
        )
    }
}

public struct MLXModelProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var displayName: String
    public var huggingFaceID: String
    public var task: String
    public var quantization: String
    public var estimatedResidentMemoryBytes: UInt64
    public var backgroundEligible: Bool

    public init(
        id: String,
        displayName: String,
        huggingFaceID: String,
        task: String = "chat",
        quantization: String = "4bit",
        estimatedResidentMemoryBytes: UInt64,
        backgroundEligible: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.huggingFaceID = huggingFaceID
        self.task = task
        self.quantization = quantization
        self.estimatedResidentMemoryBytes = estimatedResidentMemoryBytes
        self.backgroundEligible = backgroundEligible
    }

    public static let qwen3_4B_4bit = MLXModelProfile(
        id: "mlx-qwen3-4b-4bit",
        displayName: "Qwen3 4B 4-bit",
        huggingFaceID: "mlx-community/Qwen3-4B-4bit",
        estimatedResidentMemoryBytes: 5 * 1_073_741_824,
        backgroundEligible: true
    )

    public static let qwen2_5_7B_4bit = MLXModelProfile(
        id: "mlx-qwen2-5-7b-4bit",
        displayName: "Qwen2.5 7B Instruct 4-bit",
        huggingFaceID: "mlx-community/Qwen2.5-7B-Instruct-4bit",
        estimatedResidentMemoryBytes: 8 * 1_073_741_824,
        backgroundEligible: false
    )

    public static let llama3_8B_4bit = MLXModelProfile(
        id: "mlx-llama3-8b-4bit",
        displayName: "Llama 3 8B Instruct 4-bit",
        huggingFaceID: "mlx-community/Meta-Llama-3-8B-Instruct-4bit",
        estimatedResidentMemoryBytes: 8 * 1_073_741_824,
        backgroundEligible: false
    )

    public static let defaults: [MLXModelProfile] = [
        .qwen3_4B_4bit,
        .qwen2_5_7B_4bit,
        .llama3_8B_4bit
    ]

    public var isGGUFCompatibilityPath: Bool {
        let lower = huggingFaceID.lowercased()
        return lower.hasSuffix(".gguf") || lower.contains(".gguf#") || lower.contains(".gguf?")
    }
}

public struct LocalSummaryNode: Codable, Hashable, Sendable {
    public var title: String
    public var kind: String
    public var confidence: Double

    public init(title: String, kind: String = "topic", confidence: Double = 0.7) {
        self.title = title
        self.kind = kind
        self.confidence = ConfidenceScore(confidence).value
    }
}

public struct LocalSummaryConnection: Codable, Hashable, Sendable {
    public var sourceTitle: String
    public var targetTitle: String
    public var type: ConnectionType
    public var confidence: Double

    public init(sourceTitle: String, targetTitle: String, type: ConnectionType = .related, confidence: Double = 0.65) {
        self.sourceTitle = sourceTitle
        self.targetTitle = targetTitle
        self.type = type
        self.confidence = ConfidenceScore(confidence).value
    }
}

public struct LocalSummaryJSON: Codable, Hashable, Sendable {
    public var summary: String
    public var keyFacts: [String]
    public var suggestedNodes: [LocalSummaryNode]
    public var suggestedConnections: [LocalSummaryConnection]
    public var confidence: Double
    public var modelID: String
    public var generatedAt: Date

    public init(
        summary: String,
        keyFacts: [String] = [],
        suggestedNodes: [LocalSummaryNode] = [],
        suggestedConnections: [LocalSummaryConnection] = [],
        confidence: Double = 0.7,
        modelID: String,
        generatedAt: Date = Date()
    ) {
        self.summary = summary
        self.keyFacts = keyFacts
        self.suggestedNodes = suggestedNodes
        self.suggestedConnections = suggestedConnections
        self.confidence = ConfidenceScore(confidence).value
        self.modelID = modelID
        self.generatedAt = generatedAt
    }
}

private struct RawSourceSummaryInput: Hashable, Sendable {
    var recordID: String
    var title: String
    var sourceKindRawValue: String
    var summary: String
    var markdown: String
}

public struct LocalInferenceResult: Codable, Hashable, Sendable {
    public var jobID: String
    public var modelID: String
    public var json: String
    public var createdAt: Date

    public init(jobID: String, modelID: String, json: String, createdAt: Date = Date()) {
        self.jobID = jobID
        self.modelID = modelID
        self.json = json
        self.createdAt = createdAt
    }
}

public enum MLXExecutionMode: String, Codable, Sendable {
    case mlx
    case deterministicMock
}

public enum LocalAIEngineError: Error, LocalizedError, Equatable {
    case ggufUnsupported(String)
    case pausedByRuntimePolicy(String)
    case invalidSummaryJSON(String)

    public var errorDescription: String? {
        switch self {
        case .ggufUnsupported(let model):
            return "GGUF model loading is not supported by Hive's MLX Swift production path yet: \(model)"
        case .pausedByRuntimePolicy(let reason):
            return reason
        case .invalidSummaryJSON(let detail):
            return "Local model returned invalid summary JSON: \(detail)"
        }
    }
}

public actor MLXModelManager {
    public private(set) var loadedProfile: MLXModelProfile?
    public private(set) var lastUsedAt: Date?
    public let availableProfiles: [MLXModelProfile]
    public let executionMode: MLXExecutionMode
    #if canImport(HuggingFace) && canImport(MLXHuggingFace) && canImport(MLXLLM) && canImport(MLXLMCommon) && canImport(Tokenizers) && !os(watchOS)
    private var loadedContainer: ModelContainer?
    #endif

    public init(
        availableProfiles: [MLXModelProfile] = MLXModelProfile.defaults,
        executionMode: MLXExecutionMode = .mlx
    ) {
        self.availableProfiles = availableProfiles
        self.executionMode = executionMode
    }

    public func selectProfile(for job: LocalInferenceJob, budget: InferenceResourceBudget) -> MLXModelProfile {
        if job.manual {
            return availableProfiles
                .filter { $0.estimatedResidentMemoryBytes <= budget.maxResidentMemoryBytes }
                .sorted { $0.estimatedResidentMemoryBytes > $1.estimatedResidentMemoryBytes }
                .first ?? .qwen3_4B_4bit
        }
        return availableProfiles
            .filter { $0.backgroundEligible && $0.estimatedResidentMemoryBytes <= budget.maxResidentMemoryBytes }
            .sorted { $0.estimatedResidentMemoryBytes < $1.estimatedResidentMemoryBytes }
            .first ?? .qwen3_4B_4bit
    }

    public func load(profile: MLXModelProfile) async throws {
        if profile.isGGUFCompatibilityPath {
            throw LocalAIEngineError.ggufUnsupported(profile.huggingFaceID)
        }
        guard executionMode == .mlx else {
            loadedProfile = profile
            lastUsedAt = Date()
            return
        }
        #if canImport(HuggingFace) && canImport(MLXHuggingFace) && canImport(MLXLLM) && canImport(MLXLMCommon) && canImport(Tokenizers) && !os(watchOS)
        if loadedProfile?.id == profile.id, loadedContainer != nil {
            lastUsedAt = Date()
            return
        }
        loadedContainer = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: profile.huggingFaceID)
        )

        loadedProfile = profile
        lastUsedAt = Date()
        #else
        loadedProfile = profile
        lastUsedAt = Date()
        #endif
    }

    public func unloadIfIdle(now: Date = Date(), budget: InferenceResourceBudget) {
        guard let lastUsedAt else { return }
        if now.timeIntervalSince(lastUsedAt) >= budget.unloadAfterIdleSeconds {
            #if canImport(HuggingFace) && canImport(MLXHuggingFace) && canImport(MLXLLM) && canImport(MLXLMCommon) && canImport(Tokenizers) && !os(watchOS)
            loadedContainer = nil
            #endif
            loadedProfile = nil
        }
    }

    public func run(job: LocalInferenceJob, budget: InferenceResourceBudget) async throws -> LocalInferenceResult {
        let profile = selectProfile(for: job, budget: budget)
        try await load(profile: profile)
        lastUsedAt = Date()
        #if canImport(HuggingFace) && canImport(MLXHuggingFace) && canImport(MLXLLM) && canImport(MLXLMCommon) && canImport(Tokenizers) && !os(watchOS)
        if executionMode == .mlx {
            guard let loadedContainer else {
                throw CocoaError(.featureUnsupported, userInfo: [
                    NSLocalizedDescriptionKey: "MLX model container was not loaded."
                ])
            }
            let session = ChatSession(
                loadedContainer,
                instructions: """
                You are Hive's local memory compiler. Return compact JSON only. Do not include markdown or prose outside JSON.
                """,
                generateParameters: GenerateParameters(
                    maxTokens: 420,
                    temperature: 0,
                    topP: 1
                )
            )
            let response = try await session.respond(to: job.prompt)
            return LocalInferenceResult(jobID: job.id, modelID: profile.id, json: response)
        }
        #endif
        let escapedPrompt = job.prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        if job.kind == .answerChat {
            let answer = "Local synthesis refined the indexed memory answer."
            return LocalInferenceResult(
                jobID: job.id,
                modelID: profile.id,
                json: "{\"answer\":\"\(answer)\"}"
            )
        }
        let summary = LocalSummaryJSON(
            summary: String(escapedPrompt.prefix(240)),
            keyFacts: [String(escapedPrompt.prefix(96))].filter { !$0.isEmpty },
            suggestedNodes: [LocalSummaryNode(title: job.sourceID ?? "Field item", kind: "source", confidence: 0.72)],
            suggestedConnections: [],
            confidence: 0.72,
            modelID: profile.id
        )
        let payloadData = try JSONEncoder.hiveSummary.encode(summary)
        let payload = String(decoding: payloadData, as: UTF8.self)
        return LocalInferenceResult(jobID: job.id, modelID: profile.id, json: payload)
    }
}

public actor LocalAIEngine {
    private let manager: MLXModelManager
    private let policy: RuntimePolicy
    private let budget: InferenceResourceBudget
    private let profileProvider: @Sendable () -> RuntimeProfile

    public init(
        manager: MLXModelManager = MLXModelManager(),
        policy: RuntimePolicy = RuntimePolicy(),
        budget: InferenceResourceBudget = .baseM4Background(),
        profileProvider: @escaping @Sendable () -> RuntimeProfile = {
            RuntimeProfiler().currentProfile(foregroundUserActive: false)
        }
    ) {
        self.manager = manager
        self.policy = policy
        self.budget = budget
        self.profileProvider = profileProvider
    }

    public nonisolated func summarize(rawSource: RawSource, markdown: String) async throws -> LocalSummaryJSON {
        let input = RawSourceSummaryInput(
            recordID: rawSource.recordID,
            title: rawSource.title,
            sourceKindRawValue: rawSource.sourceKindRawValue,
            summary: rawSource.summary,
            markdown: markdown
        )
        return try await summarize(input: input)
    }

    public nonisolated func compileMemoryDecision(
        source: SourceRecord,
        extractedClaims: [ClaimRecord],
        existingClaims: [ClaimRecord],
        existingEntities: [EntityRecord],
        feedback: [FeedbackRecord] = [],
        modelProfile: MemoryCompilerModelProfile = .deterministicRules,
        now: Date = Date()
    ) async -> MemoryCompilerDecisionEnvelope {
        if modelProfile.backend == .appleFoundationModelsGuidedGeneration {
            let runtime = FoundationModelMemoryRuntime(mode: .foundationWhenAvailable)
            return await runtime.compile(
                source: source,
                extractedClaims: extractedClaims,
                existingClaims: existingClaims,
                existingEntities: existingEntities,
                feedback: feedback,
                now: now
            )
        }
        let runtime = MemoryCompilerRuntime(profile: modelProfile)
        return runtime.compile(
            source: source,
            extractedClaims: extractedClaims,
            existingClaims: existingClaims,
            existingEntities: existingEntities,
            feedback: feedback,
            now: now
        )
    }

    public func answerChat(
        query: String,
        sources: [SourceRecord],
        claims: [ClaimRecord],
        wikiPages: [WikiPageRecord],
        reviewQueue: [ReviewQueueItem] = [],
        modelAvailability: ModelAvailabilityState = .indexedMemoryOnly
    ) async -> CitedAnswer {
        let fallback = ChatAnswerEngine().answer(
            query: query,
            sources: sources,
            claims: claims,
            wikiPages: wikiPages,
            reviewQueue: reviewQueue,
            modelAvailability: modelAvailability
        )
        guard modelAvailability == .localSynthesisAvailable else {
            return fallback
        }

        let runtimeProfile = profileProvider()
        let decision = policy.decision(for: .summarization, profile: runtimeProfile, manual: true, computeMode: .balanced)
        guard decision.allowed else {
            return fallback
        }

        let prompt = Self.chatPrompt(query: query, fallback: fallback, claims: claims, wikiPages: wikiPages)
        let job = LocalInferenceJob(
            kind: .answerChat,
            prompt: prompt,
            priority: .userInitiated,
            manual: true
        )
        guard let result = try? await manager.run(job: job, budget: budget),
              let synthesized = Self.decodeChatAnswer(result.json) else {
            return fallback
        }
        return CitedAnswer(
            answer: synthesized,
            citations: fallback.citations,
            uncertainty: ModelAvailabilityState.localSynthesisAvailable.userVisibleLabel,
            suggestedActions: fallback.suggestedActions
        )
    }

    private func summarize(input: RawSourceSummaryInput) async throws -> LocalSummaryJSON {
        let profile = profileProvider()
        let decision = policy.decision(for: .summarization, profile: profile, manual: false, computeMode: .background)
        guard decision.allowed else {
            throw LocalAIEngineError.pausedByRuntimePolicy(decision.reason)
        }
        let prompt = Self.summaryPrompt(input: input)
        let job = LocalInferenceJob(
            kind: .summarizeRawSource,
            sourceID: input.recordID,
            prompt: prompt,
            priority: .background,
            manual: false
        )
        let result = try await manager.run(job: job, budget: budget)
        return try Self.decodeSummary(result.json, modelID: result.modelID, fallbackSummary: input.summary)
    }

    private static func summaryPrompt(input: RawSourceSummaryInput) -> String {
        """
        Return JSON with exactly these keys: summary, keyFacts, suggestedNodes, suggestedConnections, confidence, modelID, generatedAt.
        \(ExtractionQualityRules.systemPrompt)

        Existing Colony knowledge must be treated as the source of truth for deduplication and freshness.
        Suggested nodes must be atomic, sourced, and user-relevant. Do not create nodes for bare nouns, generic tools, demographic noise, or document boilerplate.

        RawSource title: \(input.title)
        RawSource kind: \(input.sourceKindRawValue)
        Markdown:
        \(input.markdown)
        """
    }

    private static func chatPrompt(query: String, fallback: CitedAnswer, claims: [ClaimRecord], wikiPages: [WikiPageRecord]) -> String {
        let claimContext = claims
            .filter { $0.status != .retracted }
            .sorted { $0.confidence > $1.confidence }
            .prefix(8)
            .map(\.statement)
            .joined(separator: "\n- ")
        let wikiContext = wikiPages
            .prefix(4)
            .map { "\($0.title): \($0.summary)" }
            .joined(separator: "\n")
        return """
        Return compact JSON only: {"answer":"..."}.
        Answer from Hive's local memory. Do not include source titles, model names, percentages, filenames, URLs, or markdown tables.
        Query: \(query)
        Deterministic fallback answer: \(fallback.answer)
        Claims:
        - \(claimContext)
        Wiki summaries:
        \(wikiContext)
        """
    }

    private static func decodeChatAnswer(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answer = object["answer"] as? String else {
            return nil
        }
        let cleaned = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              !cleaned.contains("%"),
              !cleaned.localizedCaseInsensitiveContains("http://"),
              !cleaned.localizedCaseInsensitiveContains("https://") else {
            return nil
        }
        return cleaned
    }

    private static func decodeSummary(_ json: String, modelID: String, fallbackSummary: String) throws -> LocalSummaryJSON {
        let data = Data(json.utf8)
        if let decoded = try? JSONDecoder.hiveSummary.decode(LocalSummaryJSON.self, from: data) {
            return decoded
        }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let summary = object["summary"] as? String ?? fallbackSummary
            let keyFacts = object["keyFacts"] as? [String] ?? object["key_facts"] as? [String] ?? []
            let confidence = object["confidence"] as? Double ?? 0.65
            return LocalSummaryJSON(
                summary: summary,
                keyFacts: keyFacts,
                confidence: confidence,
                modelID: object["modelID"] as? String ?? object["model"] as? String ?? modelID
            )
        }
        throw LocalAIEngineError.invalidSummaryJSON(String(json.prefix(160)))
    }
}

public actor LocalInferenceQueue {
    private var pending: [LocalInferenceJob] = []
    private var completed: [LocalInferenceResult] = []
    private let manager: MLXModelManager
    private let policy: RuntimePolicy
    private let budget: InferenceResourceBudget

    public init(
        manager: MLXModelManager = MLXModelManager(),
        policy: RuntimePolicy = RuntimePolicy(),
        budget: InferenceResourceBudget = .baseM4Background()
    ) {
        self.manager = manager
        self.policy = policy
        self.budget = budget
    }

    public func enqueue(_ job: LocalInferenceJob) {
        pending.append(job)
        pending.sort { lhs, rhs in
            priorityRank(lhs.priority) > priorityRank(rhs.priority)
        }
    }

    public func pendingCount() -> Int {
        pending.count
    }

    public func completedResults() -> [LocalInferenceResult] {
        completed
    }

    public func runReadyJobs(profile: RuntimeProfile, now: Date = Date()) async throws -> [LocalInferenceResult] {
        guard !pending.isEmpty else { return [] }
        let manual = pending.contains { $0.manual || $0.priority == .userInitiated }
        let decision = policy.decision(for: .summarization, profile: profile, manual: manual, computeMode: manual ? .balanced : .background)
        guard decision.allowed, decision.memoryLimitBytes >= 512 * 1_048_576 else {
            await manager.unloadIfIdle(now: now, budget: budget)
            return []
        }
        let count = min(pending.count, budget.maxQueuedJobsPerCycle, decision.maxConcurrentJobs)
        let jobs = Array(pending.prefix(count))
        pending.removeFirst(count)
        var results: [LocalInferenceResult] = []
        for job in jobs {
            let result = try await manager.run(job: job, budget: budget)
            results.append(result)
        }
        completed.append(contentsOf: results)
        return results
    }

    private func priorityRank(_ priority: InferenceJobPriority) -> Int {
        switch priority {
        case .userInitiated: 3
        case .normal: 2
        case .background: 1
        }
    }
}

private extension JSONEncoder {
    static var hiveSummary: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var hiveSummary: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
