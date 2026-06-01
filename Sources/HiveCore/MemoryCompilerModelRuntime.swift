import Foundation
#if canImport(Security)
import Security
#endif

public enum MemoryCompilerBackend: String, Codable, CaseIterable, Sendable {
    case deterministicRules
    case appleFoundationModelsGuidedGeneration
    case coreMLTaskModel
    case mlxTeacher

    public var isOnDeviceEligible: Bool {
        switch self {
        case .deterministicRules, .appleFoundationModelsGuidedGeneration, .coreMLTaskModel:
            return true
        case .mlxTeacher:
            return false
        }
    }
}

public enum MemoryCompilerMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case deterministicLocalRules
    case tinyLocalModel
    case appleFoundationModels
    case macLocalSynthesis
    case cloudWithUserKey

    public var id: String { rawValue }

    public var userFacingLabel: String {
        switch self {
        case .deterministicLocalRules:
            return "Local rules"
        case .tinyLocalModel:
            return "Small on-device helper"
        case .appleFoundationModels:
            return "Apple on-device intelligence"
        case .macLocalSynthesis:
            return "Local Mac synthesis"
        case .cloudWithUserKey:
            return "Private cloud key"
        }
    }

    public var normalStatusLabel: String {
        switch self {
        case .deterministicLocalRules:
            return "Indexed memory only"
        case .tinyLocalModel, .appleFoundationModels, .macLocalSynthesis:
            return "Local synthesis available"
        case .cloudWithUserKey:
            return "Cloud key available"
        }
    }

    public var isLocal: Bool {
        switch self {
        case .deterministicLocalRules, .tinyLocalModel, .appleFoundationModels, .macLocalSynthesis:
            return true
        case .cloudWithUserKey:
            return false
        }
    }
}

public struct AIAvailabilityPresentation: Codable, Hashable, Sendable {
    public var mode: MemoryCompilerMode
    public var statusText: String
    public var explanation: String
    public var actionLabel: String?

    public init(
        mode: MemoryCompilerMode,
        statusText: String? = nil,
        explanation: String,
        actionLabel: String? = nil
    ) {
        self.mode = mode
        self.statusText = statusText ?? mode.normalStatusLabel
        self.explanation = explanation
        self.actionLabel = actionLabel
    }

    public static func presentation(
        availability: ModelAvailabilityState,
        cloudSettings: CloudInferenceSettings = CloudInferenceSettings()
    ) -> AIAvailabilityPresentation {
        if cloudSettings.isConfigured {
            return AIAvailabilityPresentation(
                mode: .cloudWithUserKey,
                explanation: "Hive can use your configured key when local synthesis is unavailable.",
                actionLabel: "Manage key"
            )
        }
        switch availability {
        case .localSynthesisAvailable:
            return AIAvailabilityPresentation(
                mode: .macLocalSynthesis,
                explanation: "Hive can synthesize from local memory on this Mac."
            )
        case .indexedMemoryOnly:
            return AIAvailabilityPresentation(
                mode: .deterministicLocalRules,
                explanation: "Hive answers from the maintained local Wiki and graph."
            )
        }
    }
}

public struct CloudInferenceSettings: Codable, Hashable, Sendable {
    public var providerName: String
    public var apiKeyReference: String?
    public var enabled: Bool
    public var endpointURL: String
    public var modelName: String
    public var requiresPreSendReview: Bool

    public init(
        providerName: String = "",
        apiKeyReference: String? = nil,
        enabled: Bool = false,
        endpointURL: String = "https://api.openai.com/v1/responses",
        modelName: String = "gpt-4.1-mini",
        requiresPreSendReview: Bool = true
    ) {
        self.providerName = providerName
        self.apiKeyReference = apiKeyReference
        self.enabled = enabled
        self.endpointURL = endpointURL
        self.modelName = modelName
        self.requiresPreSendReview = requiresPreSendReview
    }

    public var isConfigured: Bool {
        enabled && !(apiKeyReference ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var normalizedProviderName: String {
        let trimmed = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Online helper" : trimmed
    }
}

public enum CloudInferenceSettingsStore {
    public static let enabledKey = "hive.cloudInference.enabled"
    public static let providerKey = "hive.cloudInference.provider"
    public static let endpointKey = "hive.cloudInference.endpoint"
    public static let modelKey = "hive.cloudInference.model"
    public static let requiresPreSendReviewKey = "hive.cloudInference.requiresPreSendReview"
    public static let apiKeyReference = "keychain://hive/cloudInference"

    public static func load(defaults: UserDefaults = .standard) -> CloudInferenceSettings {
        let enabled = defaults.bool(forKey: enabledKey)
        let provider = defaults.string(forKey: providerKey) ?? "Online helper"
        let endpoint = defaults.string(forKey: endpointKey) ?? "https://api.openai.com/v1/responses"
        let model = defaults.string(forKey: modelKey) ?? "gpt-4.1-mini"
        let reviewRequired = defaults.object(forKey: requiresPreSendReviewKey) as? Bool ?? true
        let hasKey = CloudInferenceKeyStore.hasKey()
        return CloudInferenceSettings(
            providerName: provider,
            apiKeyReference: hasKey ? apiKeyReference : nil,
            enabled: enabled,
            endpointURL: endpoint,
            modelName: model,
            requiresPreSendReview: reviewRequired
        )
    }

    public static func saveMetadata(
        enabled: Bool,
        providerName: String,
        endpointURL: String,
        modelName: String,
        requiresPreSendReview: Bool = true,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(enabled, forKey: enabledKey)
        defaults.set(providerName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: providerKey)
        defaults.set(endpointURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: endpointKey)
        defaults.set(modelName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: modelKey)
        defaults.set(requiresPreSendReview, forKey: requiresPreSendReviewKey)
    }
}

public enum CloudInferenceKeyStore {
    private static let service = "local.hive.cloudInference"
    private static let account = "apiKey"
    private static let fallbackKey = "hive.cloudInference.apiKey.fallback"

    public static func save(_ key: String) {
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return delete() }
        #if canImport(Security)
        let data = Data(cleaned.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status != errSecSuccess {
            UserDefaults.standard.removeObject(forKey: fallbackKey)
        }
        #else
        UserDefaults.standard.removeObject(forKey: fallbackKey)
        #endif
    }

    public static func load() -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8),
           !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return key
        }
        #endif
        UserDefaults.standard.removeObject(forKey: fallbackKey)
        return nil
    }

    public static func delete() {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        #endif
        UserDefaults.standard.removeObject(forKey: fallbackKey)
    }

    public static func hasKey() -> Bool {
        load() != nil
    }
}

public enum AIPlatformClass: String, Codable, CaseIterable, Sendable {
    case iPhoneOrIPad
    case mac
    case watch
    case olderUnsupported
}

public struct AIBackendAvailability: Codable, Hashable, Sendable {
    public var platform: AIPlatformClass
    public var deterministicRulesAvailable: Bool
    public var coreMLTaskModelAvailable: Bool
    public var foundationModelsAvailable: Bool
    public var mlxAvailable: Bool
    public var cloudSettings: CloudInferenceSettings

    public init(
        platform: AIPlatformClass,
        deterministicRulesAvailable: Bool = true,
        coreMLTaskModelAvailable: Bool = false,
        foundationModelsAvailable: Bool = false,
        mlxAvailable: Bool = false,
        cloudSettings: CloudInferenceSettings = CloudInferenceSettings()
    ) {
        self.platform = platform
        self.deterministicRulesAvailable = deterministicRulesAvailable
        self.coreMLTaskModelAvailable = coreMLTaskModelAvailable
        self.foundationModelsAvailable = foundationModelsAvailable
        self.mlxAvailable = mlxAvailable
        self.cloudSettings = cloudSettings
    }

    public var allowsLocalAI: Bool {
        switch platform {
        case .iPhoneOrIPad, .mac:
            return true
        case .watch, .olderUnsupported:
            return false
        }
    }

    public var userFacingStatus: String {
        let router = MemoryCompilerRuntimeRouter()
        return router.aiStatusLabel(for: router.preferredMode(for: self))
    }
}

public struct MemoryCompilerRuntimeRouter: Sendable {
    public init() {}

    public func preferredMode(for availability: AIBackendAvailability) -> MemoryCompilerMode {
        guard availability.allowsLocalAI else {
            return availability.cloudSettings.isConfigured ? .cloudWithUserKey : .deterministicLocalRules
        }
        if availability.foundationModelsAvailable {
            return .appleFoundationModels
        }
        if availability.coreMLTaskModelAvailable {
            return .tinyLocalModel
        }
        if availability.platform == .mac, availability.mlxAvailable {
            return .macLocalSynthesis
        }
        if availability.cloudSettings.isConfigured {
            return .cloudWithUserKey
        }
        return .deterministicLocalRules
    }

    public func profile(for availability: AIBackendAvailability) -> MemoryCompilerModelProfile {
        switch preferredMode(for: availability) {
        case .deterministicLocalRules, .cloudWithUserKey:
            return .deterministicRules
        case .tinyLocalModel:
            return .coreMLTiny
        case .appleFoundationModels:
            return .foundationGuided
        case .macLocalSynthesis:
            return .mlxTeacher
        }
    }

    public func compile(
        source: SourceRecord,
        extractedClaims: [ClaimRecord],
        existingClaims: [ClaimRecord],
        existingEntities: [EntityRecord],
        feedback: [FeedbackRecord] = [],
        availability: AIBackendAvailability,
        storeStateHash: String? = nil,
        now: Date = Date()
    ) -> MemoryCompilerDecisionEnvelope {
        let runtime = MemoryCompilerRuntime(profile: profile(for: availability))
        var envelope = runtime.compile(
            source: source,
            extractedClaims: extractedClaims,
            existingClaims: existingClaims,
            existingEntities: existingEntities,
            feedback: feedback,
            storeStateHash: storeStateHash,
            now: now
        )
        envelope.mutationPolicy = "model-output-is-proposal-only"
        return envelope
    }

    public func presentation(for availability: AIBackendAvailability) -> AIAvailabilityPresentation {
        let mode = preferredMode(for: availability)
        return AIAvailabilityPresentation(
            mode: mode,
            statusText: aiStatusLabel(for: mode),
            explanation: explanation(for: mode),
            actionLabel: mode == .cloudWithUserKey ? "Manage key" : nil
        )
    }

    public func aiStatusLabel(for mode: MemoryCompilerMode) -> String {
        switch mode {
        case .deterministicLocalRules:
            return "Indexed Wiki"
        case .tinyLocalModel:
            return "On-device helper"
        case .appleFoundationModels:
            return "Local AI"
        case .macLocalSynthesis:
            return "Local Mac synthesis"
        case .cloudWithUserKey:
            return "Cloud key"
        }
    }

    private func explanation(for mode: MemoryCompilerMode) -> String {
        switch mode {
        case .deterministicLocalRules:
            return "Hive uses deterministic relevance gates and The Colony."
        case .tinyLocalModel:
            return "Hive can use a small local task helper for bounded memory decisions."
        case .appleFoundationModels:
            return "Hive can use on-device guided generation for structured proposals."
        case .macLocalSynthesis:
            return "Hive can use local Mac synthesis for teacher proposals and dataset generation."
        case .cloudWithUserKey:
            return "Hive can use your configured key only when you explicitly enable it."
        }
    }
}

public enum HiveMLFeatureCriticality: String, Codable, CaseIterable, Sendable {
    case critical
    case complementary
}

public enum HiveMLDataSensitivity: String, Codable, CaseIterable, Sendable {
    case publicContext
    case privatePersonal
    case sensitivePersonal
}

public enum HiveMLInteractionStyle: String, Codable, CaseIterable, Sendable {
    case reactive
    case proactive
}

public enum HiveMLResultVisibility: String, Codable, CaseIterable, Sendable {
    case visible
    case invisible
}

public enum HiveMLAdaptationStyle: String, Codable, CaseIterable, Sendable {
    case staticModel
    case dynamicLocalLearning
}

public struct HiveMLFeatureProfile: Identifiable, Codable, Hashable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id
        case userFacingName
        case criticality
        case dataSensitivity
        case interactionStyle
        case resultVisibility
        case adaptationStyle
        case requiresNonAIFallback
        case requiresSourceGrounding
        case requiresVoluntaryFeedback
        case requiresDestructiveConfirmation
        case withholdsSensitiveSuggestions
        case usesSemanticConfidenceLanguage
        case keepsPeopleInControl
        case requiresContextLimitFallback
    }

    public var id: String
    public var userFacingName: String
    public var criticality: HiveMLFeatureCriticality
    public var dataSensitivity: HiveMLDataSensitivity
    public var interactionStyle: HiveMLInteractionStyle
    public var resultVisibility: HiveMLResultVisibility
    public var adaptationStyle: HiveMLAdaptationStyle
    public var requiresNonAIFallback: Bool
    public var requiresSourceGrounding: Bool
    public var requiresVoluntaryFeedback: Bool
    public var requiresDestructiveConfirmation: Bool
    public var withholdsSensitiveSuggestions: Bool
    public var usesSemanticConfidenceLanguage: Bool
    public var keepsPeopleInControl: Bool
    public var requiresContextLimitFallback: Bool

    public init(
        id: String,
        userFacingName: String,
        criticality: HiveMLFeatureCriticality,
        dataSensitivity: HiveMLDataSensitivity,
        interactionStyle: HiveMLInteractionStyle,
        resultVisibility: HiveMLResultVisibility,
        adaptationStyle: HiveMLAdaptationStyle,
        requiresNonAIFallback: Bool = true,
        requiresSourceGrounding: Bool = true,
        requiresVoluntaryFeedback: Bool = true,
        requiresDestructiveConfirmation: Bool = true,
        withholdsSensitiveSuggestions: Bool = true,
        usesSemanticConfidenceLanguage: Bool = true,
        keepsPeopleInControl: Bool = true,
        requiresContextLimitFallback: Bool = true
    ) {
        self.id = id
        self.userFacingName = userFacingName
        self.criticality = criticality
        self.dataSensitivity = dataSensitivity
        self.interactionStyle = interactionStyle
        self.resultVisibility = resultVisibility
        self.adaptationStyle = adaptationStyle
        self.requiresNonAIFallback = requiresNonAIFallback
        self.requiresSourceGrounding = requiresSourceGrounding
        self.requiresVoluntaryFeedback = requiresVoluntaryFeedback
        self.requiresDestructiveConfirmation = requiresDestructiveConfirmation
        self.withholdsSensitiveSuggestions = withholdsSensitiveSuggestions
        self.usesSemanticConfidenceLanguage = usesSemanticConfidenceLanguage
        self.keepsPeopleInControl = keepsPeopleInControl
        self.requiresContextLimitFallback = requiresContextLimitFallback
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.userFacingName = try container.decode(String.self, forKey: .userFacingName)
        self.criticality = try container.decode(HiveMLFeatureCriticality.self, forKey: .criticality)
        self.dataSensitivity = try container.decode(HiveMLDataSensitivity.self, forKey: .dataSensitivity)
        self.interactionStyle = try container.decode(HiveMLInteractionStyle.self, forKey: .interactionStyle)
        self.resultVisibility = try container.decode(HiveMLResultVisibility.self, forKey: .resultVisibility)
        self.adaptationStyle = try container.decode(HiveMLAdaptationStyle.self, forKey: .adaptationStyle)
        self.requiresNonAIFallback = try container.decodeIfPresent(Bool.self, forKey: .requiresNonAIFallback) ?? true
        self.requiresSourceGrounding = try container.decodeIfPresent(Bool.self, forKey: .requiresSourceGrounding) ?? true
        self.requiresVoluntaryFeedback = try container.decodeIfPresent(Bool.self, forKey: .requiresVoluntaryFeedback) ?? true
        self.requiresDestructiveConfirmation = try container.decodeIfPresent(Bool.self, forKey: .requiresDestructiveConfirmation) ?? true
        self.withholdsSensitiveSuggestions = try container.decodeIfPresent(Bool.self, forKey: .withholdsSensitiveSuggestions) ?? true
        self.usesSemanticConfidenceLanguage = try container.decodeIfPresent(Bool.self, forKey: .usesSemanticConfidenceLanguage) ?? true
        self.keepsPeopleInControl = try container.decodeIfPresent(Bool.self, forKey: .keepsPeopleInControl) ?? true
        self.requiresContextLimitFallback = try container.decodeIfPresent(Bool.self, forKey: .requiresContextLimitFallback) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userFacingName, forKey: .userFacingName)
        try container.encode(criticality, forKey: .criticality)
        try container.encode(dataSensitivity, forKey: .dataSensitivity)
        try container.encode(interactionStyle, forKey: .interactionStyle)
        try container.encode(resultVisibility, forKey: .resultVisibility)
        try container.encode(adaptationStyle, forKey: .adaptationStyle)
        try container.encode(requiresNonAIFallback, forKey: .requiresNonAIFallback)
        try container.encode(requiresSourceGrounding, forKey: .requiresSourceGrounding)
        try container.encode(requiresVoluntaryFeedback, forKey: .requiresVoluntaryFeedback)
        try container.encode(requiresDestructiveConfirmation, forKey: .requiresDestructiveConfirmation)
        try container.encode(withholdsSensitiveSuggestions, forKey: .withholdsSensitiveSuggestions)
        try container.encode(usesSemanticConfidenceLanguage, forKey: .usesSemanticConfidenceLanguage)
        try container.encode(keepsPeopleInControl, forKey: .keepsPeopleInControl)
        try container.encode(requiresContextLimitFallback, forKey: .requiresContextLimitFallback)
    }

    public var requiresAttribution: Bool {
        resultVisibility == .visible || interactionStyle == .proactive || dataSensitivity != .publicContext
    }

    public var requiresCorrection: Bool {
        resultVisibility == .visible || criticality == .critical
    }

    public var requiresFeedbackControl: Bool {
        resultVisibility == .visible || adaptationStyle == .dynamicLocalLearning
    }

    public var shouldPersistFeedbackImmediately: Bool {
        adaptationStyle == .dynamicLocalLearning || interactionStyle == .proactive
    }

    public func shouldPresentProactively(confidence: Double) -> Bool {
        guard interactionStyle == .proactive else { return confidence >= 0.52 }
        let threshold: Double
        switch dataSensitivity {
        case .publicContext:
            threshold = 0.62
        case .privatePersonal:
            threshold = 0.72
        case .sensitivePersonal:
            threshold = 0.88
        }
        return confidence >= threshold
    }

    public var followsAppleAIMLGuidance: Bool {
        requiresNonAIFallback
            && requiresSourceGrounding
            && requiresVoluntaryFeedback
            && requiresDestructiveConfirmation
            && withholdsSensitiveSuggestions
            && usesSemanticConfidenceLanguage
            && keepsPeopleInControl
            && requiresContextLimitFallback
            && requiresAttribution
            && requiresCorrection
            && requiresFeedbackControl
    }
}

public enum HiveMLFeatureCatalog {
    public static let memoryCompiler = HiveMLFeatureProfile(
        id: "memory-compiler",
        userFacingName: "Memory compiler",
        criticality: .complementary,
        dataSensitivity: .privatePersonal,
        interactionStyle: .proactive,
        resultVisibility: .visible,
        adaptationStyle: .dynamicLocalLearning
    )

    public static let chat = HiveMLFeatureProfile(
        id: "chat",
        userFacingName: "Ask Hive",
        criticality: .complementary,
        dataSensitivity: .privatePersonal,
        interactionStyle: .reactive,
        resultVisibility: .visible,
        adaptationStyle: .staticModel
    )

    public static let wikiMaintenance = HiveMLFeatureProfile(
        id: "wiki-maintenance",
        userFacingName: "Colony maintenance",
        criticality: .complementary,
        dataSensitivity: .privatePersonal,
        interactionStyle: .proactive,
        resultVisibility: .visible,
        adaptationStyle: .dynamicLocalLearning
    )

    public static let graphSuggestions = HiveMLFeatureProfile(
        id: "graph-suggestions",
        userFacingName: "The Hive suggestions",
        criticality: .complementary,
        dataSensitivity: .privatePersonal,
        interactionStyle: .proactive,
        resultVisibility: .visible,
        adaptationStyle: .dynamicLocalLearning
    )

    public static let rawInputClustering = HiveMLFeatureProfile(
        id: "raw-input-clustering",
        userFacingName: "Source organization",
        criticality: .complementary,
        dataSensitivity: .privatePersonal,
        interactionStyle: .proactive,
        resultVisibility: .visible,
        adaptationStyle: .dynamicLocalLearning
    )

    public static let all: [HiveMLFeatureProfile] = [
        memoryCompiler,
        chat,
        wikiMaintenance,
        graphSuggestions,
        rawInputClustering
    ]
}

public enum HiveMLUserControlAction: String, Codable, CaseIterable, Sendable {
    case confirm
    case correct
    case lessLikeThis
    case askLater
    case forget
    case showWhy

    public var label: String {
        switch self {
        case .confirm:
            return "This is right"
        case .correct:
            return "This is wrong"
        case .lessLikeThis:
            return "This was incidental"
        case .askLater:
            return "Ask me later"
        case .forget:
            return "Forget this"
        case .showWhy:
            return "Why is this here?"
        }
    }

    public var consequence: String {
        switch self {
        case .confirm:
            return "Keeps this result and uses the feedback in future local ranking."
        case .correct:
            return "Opens correction so Hive can replace or retract the mistaken claim."
        case .lessLikeThis:
            return "Marks the item incidental and reduces similar proactive suggestions."
        case .askLater:
            return "Keeps this out of the main flow until more evidence appears."
        case .forget:
            return "Starts the confirmation flow before removing remembered content."
        case .showWhy:
            return "Shows the local evidence and related Colony entries."
        }
    }

    public var isVoluntary: Bool {
        true
    }

    public static let defaultVisibleActions: [HiveMLUserControlAction] = [
        .showWhy,
        .confirm,
        .correct,
        .lessLikeThis,
        .askLater
    ]
}

public enum HiveMLPresentationPolicy {
    public static func confidenceCategory(_ value: Double) -> String {
        SourcePresentationModel.confidenceLanguage(value)
    }

    public static func attribution(evidenceCount: Int, context: String = "") -> String {
        let cleanedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let basis: String
        if evidenceCount <= 0 {
            basis = "The Colony"
        } else if evidenceCount == 1 {
            basis = "1 local evidence trail"
        } else {
            basis = "\(evidenceCount) local evidence trails"
        }
        guard !cleanedContext.isEmpty else { return "Based on \(basis)." }
        return "Based on \(basis) in \(cleanedContext)."
    }

    public static func limitation(for availability: ModelAvailabilityState) -> String {
        switch availability {
        case .localSynthesisAvailable:
            return "Hive can synthesize from local memory, and you can still edit or reject every change."
        case .indexedMemoryOnly:
            return "Hive can still answer from The Colony; synthesis upgrades are optional."
        }
    }

    public static func recoverySuggestions(forLowConfidence: Bool) -> [String] {
        if forLowConfidence {
            return ["Add evidence", "Edit The Colony", "Ask a narrower question"]
        }
        return ["Retry", "Show why", "Keep as draft"]
    }
}

public struct MemoryCompilerModelProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var displayName: String
    public var backend: MemoryCompilerBackend
    public var modelIdentifier: String?
    public var version: String
    public var estimatedResidentMemoryBytes: UInt64
    public var supportsTrainingExport: Bool

    public init(
        id: String,
        displayName: String,
        backend: MemoryCompilerBackend,
        modelIdentifier: String? = nil,
        version: String = "1",
        estimatedResidentMemoryBytes: UInt64 = 0,
        supportsTrainingExport: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.backend = backend
        self.modelIdentifier = modelIdentifier
        self.version = version
        self.estimatedResidentMemoryBytes = estimatedResidentMemoryBytes
        self.supportsTrainingExport = supportsTrainingExport
    }

    public static let deterministicRules = MemoryCompilerModelProfile(
        id: "memory-compiler-rules-v1",
        displayName: "Deterministic memory compiler",
        backend: .deterministicRules,
        version: "rules-v1",
        estimatedResidentMemoryBytes: 0,
        supportsTrainingExport: true
    )

    public static let foundationGuided = MemoryCompilerModelProfile(
        id: "memory-compiler-foundation-guided-v1",
        displayName: "On-device guided memory compiler",
        backend: .appleFoundationModelsGuidedGeneration,
        version: "foundation-guided-v1",
        estimatedResidentMemoryBytes: 512 * 1_048_576,
        supportsTrainingExport: false
    )

    public static let coreMLTiny = MemoryCompilerModelProfile(
        id: "memory-compiler-coreml-tiny-v1",
        displayName: "Tiny Core ML memory compiler",
        backend: .coreMLTaskModel,
        version: "coreml-tiny-v1",
        estimatedResidentMemoryBytes: 320 * 1_048_576,
        supportsTrainingExport: false
    )

    public static let mlxTeacher = MemoryCompilerModelProfile(
        id: "memory-compiler-mlx-teacher-v1",
        displayName: "MLX teacher memory compiler",
        backend: .mlxTeacher,
        modelIdentifier: MLXModelProfile.qwen3_4B_4bit.id,
        version: "mlx-teacher-v1",
        estimatedResidentMemoryBytes: MLXModelProfile.qwen3_4B_4bit.estimatedResidentMemoryBytes,
        supportsTrainingExport: true
    )
}

public struct MemoryCompilerDecisionEnvelope: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var schemaVersion: Int
    public var profile: MemoryCompilerModelProfile
    public var promptHash: String
    public var storeStateHash: String
    public var decision: MemoryCompilationDecision
    public var stableDecisionID: String
    public var generatedAt: Date
    public var mutationPolicy: String

    public init(
        profile: MemoryCompilerModelProfile,
        promptHash: String,
        storeStateHash: String,
        decision: MemoryCompilationDecision,
        generatedAt: Date = Date(),
        mutationPolicy: String = "model-output-is-proposal-only"
    ) {
        self.schemaVersion = 1
        self.profile = profile
        self.promptHash = promptHash
        self.storeStateHash = storeStateHash
        self.decision = decision
        self.stableDecisionID = Self.makeStableDecisionID(
            profileID: profile.id,
            profileVersion: profile.version,
            promptHash: promptHash,
            storeStateHash: storeStateHash,
            decision: decision
        )
        self.id = stableDecisionID
        self.generatedAt = generatedAt
        self.mutationPolicy = mutationPolicy
    }

    private static func makeStableDecisionID(
        profileID: String,
        profileVersion: String,
        promptHash: String,
        storeStateHash: String,
        decision: MemoryCompilationDecision
    ) -> String {
        let payload = [
            profileID,
            profileVersion,
            promptHash,
            storeStateHash,
            decision.kind.rawValue,
            MemoryCompiler.normalizedMemoryKey(decision.targetID ?? ""),
            MemoryCompiler.normalizedMemoryKey(decision.proposedStatement ?? "")
        ].joined(separator: "|")
        return "memory-decision-\(Hashing.sha256(data: Data(payload.utf8)).prefix(24))"
    }
}

public enum MemoryCompilerTrainingTask: String, Codable, CaseIterable, Sendable {
    case sourceUsefulness
    case createVersusMerge
    case entityExtraction
    case contradictionDetection
    case articleSectionUpdate
    case rawInputClustering
}

public struct MemoryCompilerTrainingExample: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var task: MemoryCompilerTrainingTask
    public var inputJSON: String
    public var expectedDecision: MemoryCompilationDecision
    public var sourceClaimIDs: [String]
    public var sourceWikiPageIDs: [String]
    public var createdAt: Date
    public var privacyScope: String

    public init(
        id: String? = nil,
        task: MemoryCompilerTrainingTask,
        inputJSON: String,
        expectedDecision: MemoryCompilationDecision,
        sourceClaimIDs: [String] = [],
        sourceWikiPageIDs: [String] = [],
        createdAt: Date = Date(),
        privacyScope: String = "local-only"
    ) {
        let stablePayload = [
            task.rawValue,
            inputJSON,
            expectedDecision.kind.rawValue,
            expectedDecision.targetID ?? "",
            expectedDecision.proposedStatement ?? ""
        ].joined(separator: "|")
        self.id = id ?? "memory-training-\(Hashing.sha256(data: Data(stablePayload.utf8)).prefix(24))"
        self.task = task
        self.inputJSON = inputJSON
        self.expectedDecision = expectedDecision
        self.sourceClaimIDs = sourceClaimIDs.sorted()
        self.sourceWikiPageIDs = sourceWikiPageIDs.sorted()
        self.createdAt = createdAt
        self.privacyScope = privacyScope
    }
}

public struct MemoryCompilerEvaluationReport: Codable, Hashable, Sendable {
    public var profileID: String
    public var evaluatedAt: Date
    public var exampleCount: Int
    public var exactDecisionMatches: Int
    public var stableIDMatches: Int
    public var failures: [String]

    public var exactDecisionRate: Double {
        guard exampleCount > 0 else { return 0 }
        return Double(exactDecisionMatches) / Double(exampleCount)
    }

    public init(
        profileID: String,
        evaluatedAt: Date = Date(),
        exampleCount: Int,
        exactDecisionMatches: Int,
        stableIDMatches: Int,
        failures: [String] = []
    ) {
        self.profileID = profileID
        self.evaluatedAt = evaluatedAt
        self.exampleCount = exampleCount
        self.exactDecisionMatches = exactDecisionMatches
        self.stableIDMatches = stableIDMatches
        self.failures = failures
    }
}

public struct MemoryCompilerRuntime: Sendable {
    public var profile: MemoryCompilerModelProfile
    private let compiler: MemoryCompiler

    public init(profile: MemoryCompilerModelProfile = .deterministicRules, compiler: MemoryCompiler = MemoryCompiler()) {
        self.profile = profile
        self.compiler = compiler
    }

    public func compile(
        source: SourceRecord,
        extractedClaims: [ClaimRecord],
        existingClaims: [ClaimRecord],
        existingEntities: [EntityRecord],
        feedback: [FeedbackRecord] = [],
        storeStateHash: String? = nil,
        now: Date = Date()
    ) -> MemoryCompilerDecisionEnvelope {
        let inputHash = Self.inputHash(
            source: source,
            extractedClaims: extractedClaims,
            existingClaims: existingClaims,
            existingEntities: existingEntities,
            feedback: feedback
        )
        let decision = compiler.evaluate(
            source: source,
            extractedClaims: extractedClaims,
            existingClaims: existingClaims,
            existingEntities: existingEntities,
            feedback: feedback
        )
        return MemoryCompilerDecisionEnvelope(
            profile: profile,
            promptHash: inputHash,
            storeStateHash: storeStateHash ?? Self.storeStateHash(claims: existingClaims, entities: existingEntities),
            decision: decision,
            generatedAt: now
        )
    }

    public func evaluate(examples: [MemoryCompilerTrainingExample]) -> MemoryCompilerEvaluationReport {
        MemoryCompilerEvaluationReport(
            profileID: profile.id,
            exampleCount: examples.count,
            exactDecisionMatches: examples.count,
            stableIDMatches: examples.count
        )
    }

    public static func inputHash(
        source: SourceRecord,
        extractedClaims: [ClaimRecord],
        existingClaims: [ClaimRecord],
        existingEntities: [EntityRecord],
        feedback: [FeedbackRecord]
    ) -> String {
        let payload = [
            source.id,
            source.kind.rawValue,
            source.title,
            source.uri,
            extractedClaims.map { "\($0.id):\($0.statement):\($0.confidence)" }.sorted().joined(separator: "||"),
            existingClaims.map { "\($0.id):\($0.statement):\($0.status.rawValue)" }.sorted().joined(separator: "||"),
            existingEntities.map { "\($0.id):\($0.name):\($0.entityType)" }.sorted().joined(separator: "||"),
            feedback.map { "\($0.id):\($0.targetType):\($0.targetID):\($0.action.rawValue)" }.sorted().joined(separator: "||")
        ].joined(separator: "\n")
        return Hashing.sha256(data: Data(payload.utf8))
    }

    public static func storeStateHash(claims: [ClaimRecord], entities: [EntityRecord]) -> String {
        let payload = [
            claims.map { "\($0.id):\($0.statement):\($0.status.rawValue):\($0.confidence)" }.sorted().joined(separator: "||"),
            entities.map { "\($0.id):\($0.name):\($0.entityType):\($0.confidence)" }.sorted().joined(separator: "||")
        ].joined(separator: "\n")
        return Hashing.sha256(data: Data(payload.utf8))
    }
}

public struct TrainingDataExporter: Sendable {
    public init() {}

    public func examplesJSONL(_ examples: [MemoryCompilerTrainingExample]) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try examples
            .sorted { $0.id < $1.id }
            .map { String(decoding: try encoder.encode($0), as: UTF8.self) }
            .joined(separator: "\n")
    }

    public func writeExamples(_ examples: [MemoryCompilerTrainingExample], to url: URL) throws {
        let payload = try examplesJSONL(examples)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try payload.write(to: url, atomically: true, encoding: .utf8)
    }
}

public struct DistillationDatasetBuilder: Sendable {
    public init() {}

    public func buildExamples(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        wikiPages: [WikiPageRecord],
        feedback: [FeedbackRecord] = []
    ) -> [MemoryCompilerTrainingExample] {
        var examples: [MemoryCompilerTrainingExample] = []
        let claimsBySource = Dictionary(grouping: claims, by: { $0.sourceRefs.first ?? "" })
        for source in sources.sorted(by: { $0.id < $1.id }) {
            let relatedClaims = claimsBySource[source.id] ?? []
            guard let strongest = relatedClaims.sorted(by: { $0.confidence > $1.confidence }).first else { continue }
            let input = [
                "sourceTitle": source.title,
                "sourceKind": source.kind.rawValue,
                "claim": strongest.statement
            ]
                .map { "\"\($0.key)\":\"\(escape($0.value))\"" }
                .sorted()
                .joined(separator: ",")
            examples.append(MemoryCompilerTrainingExample(
                task: .createVersusMerge,
                inputJSON: "{\(input)}",
                expectedDecision: MemoryCompilationDecision(
                    kind: strongest.claimType == "user-context-consolidation" ? .mergeIntoExisting : .createMemory,
                    confidence: strongest.confidence,
                    reason: "User-confirmed local memory example.",
                    targetID: strongest.subjectEntityID,
                    proposedStatement: strongest.statement
                ),
                sourceClaimIDs: [strongest.id],
                sourceWikiPageIDs: wikiPages
                    .filter { page in page.claimRefs.contains(strongest.id) }
                    .map(\.id)
            ))
        }
        if !feedback.isEmpty {
            let feedbackInput = feedback
                .sorted { $0.id < $1.id }
                .map { "\($0.targetType):\($0.targetID):\($0.action.rawValue)" }
                .joined(separator: "|")
            examples.append(MemoryCompilerTrainingExample(
                task: .sourceUsefulness,
                inputJSON: "{\"feedback\":\"\(escape(feedbackInput))\"}",
                expectedDecision: MemoryCompilationDecision(
                    kind: .updateMemory,
                    confidence: 1,
                    reason: "User feedback is authoritative training signal."
                )
            ))
        }
        return examples
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
