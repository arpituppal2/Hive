import Foundation
import SwiftUI
import HiveCore
import HiveDesignSystem
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if os(macOS)
import AppKit
#endif

public enum HivePrimarySurface: String, CaseIterable, Identifiable, Sendable {
    case rawInputs = "Field"
    case wiki = "The Colony"
    case graph = "The Hive"
    case swarm = "Swarm"

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .rawInputs:
            return "Field"
        case .wiki, .graph, .swarm:
            return rawValue
        }
    }
}

public struct HiveChatEntry: Identifiable, Hashable, Sendable {
    public enum Speaker: String, Hashable, Sendable {
        case user
        case hive
    }

    public var id: UUID
    public var speaker: Speaker
    public var text: String
    public var citations: [SourcePresentationModel]
    public var note: String?

    public init(id: UUID = UUID(), speaker: Speaker, text: String, citations: [SourcePresentationModel] = [], note: String? = nil) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.citations = citations
        self.note = note
    }
}

public struct ProcessingResultSummary: Identifiable, Hashable, Sendable {
    public struct LearnedNode: Identifiable, Hashable, Sendable {
        public var id: String
        public var title: String
        public var x: Double
        public var y: Double
    }

    public struct ColonyChange: Identifiable, Hashable, Sendable {
        public var id: String
        public var title: String
        public var newClaimCount: Int
    }

    public struct SkippedFact: Identifiable, Hashable, Sendable {
        public var id = UUID()
        public var text: String
        public var reason: String
    }

    public var id = UUID()
    public var sourceID: String?
    public var sourceName: String
    public var learned: [LearnedNode]
    public var colonyChanges: [ColonyChange]
    public var skipped: [SkippedFact]

    public var learnedCount: Int {
        learned.count + colonyChanges.reduce(0) { $0 + max(0, $1.newClaimCount) }
    }
}

public struct RawSourcePreview: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var kindLabel: String
    public var localPath: String?
    public var text: String

    public init(id: String, title: String, kindLabel: String, localPath: String?, text: String) {
        self.id = id
        self.title = title
        self.kindLabel = kindLabel
        self.localPath = localPath
        self.text = text
    }
}

private struct HiveAppStoreSnapshot: Sendable {
    var sources: [SourceRecord]
    var claims: [ClaimRecord]
    var wikiPages: [WikiPageRecord]
    var currentOrganismState: HiveOrganismState
    var visibility: DerivedMemoryVisibility
    var sourcePresentations: [SourcePresentationModel]
    var rawSourcePresentations: [SourcePresentationModel]
    var stagedItems: [SourceRecord]
    var processedItems: [SourceRecord]
    var stagedSourcePresentations: [SourcePresentationModel]
    var processedSourcePresentations: [SourcePresentationModel]
    var rawInputClusters: [RawInputCellCluster]
    var graph: HiveGraphSnapshot
}

public enum HiveSwarmReferenceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case field
    case colony
    case hive

    public var displayTitle: String {
        switch self {
        case .field:
            return "Field"
        case .colony:
            return "Colony"
        case .hive:
            return "Hive"
        }
    }

    public var symbolName: HiveSymbolName {
        switch self {
        case .field:
            return .rawInputs
        case .colony:
            return .wiki
        case .hive:
            return .hiveGraph
        }
    }
}

public struct HiveSwarmReference: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: HiveSwarmReferenceKind
    public var title: String
    public var detail: String

    public init(id: String, kind: HiveSwarmReferenceKind, title: String, detail: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

public enum HiveSwarmMessageSpeaker: String, Codable, Hashable, Sendable {
    case user
    case swarm
}

public struct HiveSwarmMessage: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var speaker: HiveSwarmMessageSpeaker
    public var text: String
    public var createdAt: Date
    public var citations: [HiveSwarmReference]
    public var note: String?

    public init(
        id: UUID = UUID(),
        speaker: HiveSwarmMessageSpeaker,
        text: String,
        createdAt: Date = Date(),
        citations: [HiveSwarmReference] = [],
        note: String? = nil
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.createdAt = createdAt
        self.citations = citations
        self.note = note
    }
}

public struct HiveSwarmThread: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var messages: [HiveSwarmMessage]

    public init(
        id: UUID = UUID(),
        title: String = "New Chat",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [HiveSwarmMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

public enum HiveSwarmPlugin: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case field
    case colony
    case hive
    case web
    case automations

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .field:
            return "Field"
        case .colony:
            return "Colony"
        case .hive:
            return "Hive"
        case .web:
            return "Links"
        case .automations:
            return "Actions"
        }
    }

    public var subtitle: String {
        switch self {
        case .field:
            return "Add notes and approved captures."
        case .colony:
            return "Search maintained pages."
        case .hive:
            return "Find and connect cells."
        case .web:
            return "Turn approved URLs into Field sources."
        case .automations:
            return "Run review, re-index, and filing actions."
        }
    }

    public var symbolName: HiveSymbolName {
        switch self {
        case .field:
            return .rawInputs
        case .colony:
            return .wiki
        case .hive:
            return .hiveGraph
        case .web:
            return .webLink
        case .automations:
            return .runMaintenance
        }
    }
}

public enum HiveLiveAssistantAction: Equatable, Sendable {
    case captureCurrentPage(command: String, followUpQuestion: String?)
    case addInformation(String)
    case ask(String)
    case searchHive(String)
    case reorganizeTopic(String)
    case defineAutomation(String)
    case defineSkill(String)

    public var statusText: String {
        switch self {
        case .captureCurrentPage(_, let followUpQuestion):
            return followUpQuestion == nil ? "Capturing screen context." : "Capturing screen context for Ask."
        case .addInformation:
            return "Adding to Field."
        case .ask:
            return "Thinking with The Colony."
        case .searchHive:
            return "Searching The Hive."
        case .reorganizeTopic(let topic):
            return "Reorganizing \(topic)."
        case .defineAutomation:
            return "Setting up automation."
        case .defineSkill:
            return "Creating Hive skill."
        }
    }
}

public enum HiveLiveAssistantRouter {
    public static func route(_ rawPrompt: String) -> HiveLiveAssistantAction? {
        let prompt = normalizedPrompt(rawPrompt)
        guard !prompt.isEmpty else { return nil }
        let lower = prompt.lowercased()

        if let command = SwarmPartnerCommandRouter().route(prompt) {
            switch command {
            case .reorganizeTopic(let topic):
                return .reorganizeTopic(topic)
            case .defineAutomation(let request):
                return .defineAutomation(request)
            case .defineSkill(let request):
                return .defineSkill(request)
            }
        }

        if containsAny(lower, terms: captureTerms) {
            let followUp = looksLikeQuestion(lower) || containsAny(lower, terms: screenQuestionTerms) ? prompt : nil
            return .captureCurrentPage(command: prompt, followUpQuestion: followUp)
        }

        if containsAny(lower, terms: hiveSearchPrefixes) {
            return .searchHive(searchPayload(from: prompt, lowercased: lower))
        }

        if shouldAddToMemory(lower) {
            return .addInformation(prompt)
        }

        return .ask(prompt)
    }

    public static func normalizedPrompt(_ rawPrompt: String) -> String {
        var prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        for wakePhrase in wakePhrases {
            if prompt.lowercased().hasPrefix(wakePhrase) {
                prompt = String(prompt.dropFirst(wakePhrase.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " ,.:;-").union(.whitespacesAndNewlines))
                break
            }
        }
        return prompt
    }

    private static let wakePhrases = [
        "hello hive",
        "hey hive"
    ]

    private static let captureTerms = [
        "take a screenshot",
        "screenshot",
        "screen shot",
        "screen capture",
        "capture current",
        "capture this",
        "current page",
        "this page",
        "webpage",
        "web page",
        "rip the page",
        "rip this page",
        "rip current page",
        "save this page",
        "screen context"
    ]

    private static let screenQuestionTerms = [
        "what is on my screen",
        "what's on my screen",
        "what am i looking at",
        "explain this screen",
        "explain this page",
        "summarize this page",
        "summarize the page",
        "using screen context"
    ]

    private static let hiveSearchPrefixes = [
        "find in hive",
        "find in the hive",
        "search hive",
        "search the hive",
        "show in hive",
        "show in the hive"
    ]

    private static func containsAny(_ value: String, terms: [String]) -> Bool {
        terms.contains { value.contains($0) }
    }

    private static func looksLikeQuestion(_ lower: String) -> Bool {
        lower.contains("?")
            || lower.hasPrefix("what ")
            || lower.hasPrefix("why ")
            || lower.hasPrefix("how ")
            || lower.hasPrefix("who ")
            || lower.hasPrefix("where ")
            || lower.hasPrefix("when ")
            || lower.hasPrefix("explain ")
            || lower.hasPrefix("summarize ")
            || lower.hasPrefix("tell me ")
    }

    private static func shouldAddToMemory(_ lower: String) -> Bool {
        let feedPrefixes = [
            "remember ",
            "note:",
            "note ",
            "add this",
            "add to hive",
            "save this",
            "i am ",
            "i'm ",
            "im ",
            "i have ",
            "i want ",
            "i need ",
            "my ",
            "for me,"
        ]
        return !lower.contains("?") && feedPrefixes.contains { lower.hasPrefix($0) }
    }

    private static func searchPayload(from prompt: String, lowercased lower: String) -> String {
        for prefix in hiveSearchPrefixes where lower.hasPrefix(prefix) {
            let index = prompt.index(prompt.startIndex, offsetBy: min(prefix.count, prompt.count))
            let payload = prompt[index...].trimmingCharacters(in: CharacterSet(charactersIn: " ,.:;-").union(.whitespacesAndNewlines))
            if !payload.isEmpty { return payload }
        }
        return prompt
    }
}

@MainActor
public final class HiveAppModel: ObservableObject {
    @Published public var selectedSurface: HivePrimarySurface = .graph {
        didSet { publishCloudAppState() }
    }
    @Published public var sources: [SourceRecord] = []
    @Published public var claims: [ClaimRecord] = []
    @Published public var wikiPages: [WikiPageRecord] = []
    @Published public var graph: HiveGraphSnapshot = HiveGraphSnapshot(nodes: [], edges: [])
    @Published public private(set) var sourcePresentations: [SourcePresentationModel] = []
    @Published public private(set) var rawSourcePresentations: [SourcePresentationModel] = []
    @Published public private(set) var stagedItems: [SourceRecord] = []
    @Published public private(set) var processedItems: [SourceRecord] = []
    @Published public private(set) var stagedSourcePresentations: [SourcePresentationModel] = []
    @Published public private(set) var processedSourcePresentations: [SourcePresentationModel] = []
    @Published public private(set) var rawInputClusters: [RawInputCellCluster] = []
    @Published public private(set) var visibleGraphNodes: [GraphNodeRecord] = []
    @Published public private(set) var graphAnimationList: GraphChangeAnimationList = .empty
    @Published public private(set) var currentOrganismState: HiveOrganismState = .resting
    @Published public var selectedSourceID: String?
    @Published public var selectedClaimID: String?
    @Published public var selectedNodeID: String? {
        didSet { publishCloudAppState() }
    }
    @Published public var selectedPageID: String? {
        didSet { publishCloudAppState() }
    }
    @Published public var commandPaletteVisible = false
    @Published public var chatVisible = false
    @Published public var settingsVisible = false
    @Published public var graphSearchVisible = false
    @Published public var graphSearchText = ""
    @Published public var graphReindexRequestID: UUID?
    @Published public var commandText = ""
    @Published public var chatText = ""
    @Published public var liveVisible = false
    @Published public var liveText = ""
    @Published public var liveStatusText = "Ready"
    @Published public var liveSpokenText = ""
    @Published public var liveSpokenSequence = 0
    @Published public var chatEntries: [HiveChatEntry] = []
    @Published public private(set) var chatStatusText = "Local memory"
    @Published public var swarmThreads: [HiveSwarmThread] = []
    @Published public var activeSwarmThreadID: UUID?
    @Published public var swarmDraft = ""
    @Published public var swarmDraftAttachments: [SwarmDraftAttachment] = []
    @Published public var swarmEnabledPlugins: Set<HiveSwarmPlugin> = [.field, .colony, .hive, .web, .automations]
    @Published public var errorText: String?
    @Published public var isWorking = false
    @Published public var sourcePluginStatusText = ""
    @Published public private(set) var learningSettings = HiveLearningSettingsStore.load()
    @Published public var rawSourcesAuditVisible = false
    @Published public var sourcePreview: RawSourcePreview?
    @Published public var processingResult: ProcessingResultSummary?
    @Published public private(set) var authenticatedAccount = HiveAccountStore.load()
    @Published public private(set) var appleAccount = HiveAppleAccountStore.load()
    @Published public private(set) var temporaryGuestAccessEnabled = HiveGuestAccessStore.isEnabled()
    @Published public var firstLoginDataChoicePrompt: HiveFirstLoginDataChoicePrompt?

    public let paths: HivePaths
    public let store: HiveStore
    private let controlPlane: ControlPlane
    private let ingestionEngine: IngestionCoordinator
    private let knowledgeLoop: KnowledgeLoop
    private let cloudAppStateSync = HiveCloudAppStateSync()
    private let chatAnswerEngine = ChatAnswerEngine()
    private let foundationOrchestrator: HiveFoundationModelsOrchestrator
    private let swarmAttachmentPipeline = SwarmAttachmentPipeline()
    private let swarmContextRetriever = SwarmColonyContextRetriever()
    private let swarmContextCompactor = SwarmContextCompactor()
    private let swarmContextPromptBuilder = SwarmContextPromptBuilder()
    private let wikiOperationEngine = WikiOperationEngine()
    private var lastAnswerForFiling: (query: String, answer: CitedAnswer)?
    private var shouldSpeakNextChatAnswer = false
    private var cachedVisibility: DerivedMemoryVisibility = .allowAll
    private var hasLoadedGraphSnapshot = false
    private var settledUploadProcessingTask: Task<Void, Never>?
    private var scheduledStagedProcessingDeadline: Date?
    private var swarmDraftSessionID = UUID()
    private var swarmAttachmentRefreshTask: Task<Void, Never>?
    private var quickSwarmLastDismissedAt: Date?
    private var appleCredentialRevocationObserver: NSObjectProtocol?
    private let knowledgeMutationQueue = DispatchQueue(label: "local.hive.knowledge-mutations", qos: .userInitiated)

    public nonisolated static let uploadSettleDelaySeconds: TimeInterval = 5 * 60
    public nonisolated static let quickSwarmWarmSessionSeconds: TimeInterval = 10 * 60
    public nonisolated static let swarmSurfaceThreadLimit = 60
    public nonisolated static let swarmSurfaceMessageLimit = 80
    public nonisolated static let swarmSurfaceExpandedMessageLimit = 240
    public nonisolated static let swarmSurfaceMessageCharacterLimit = 2_800

    public init() {
        do {
            let paths = try HivePaths.applicationSupport()
            try paths.createDirectories()
            let store = try HiveStore(databaseURL: paths.database)
            self.paths = paths
            self.store = store
            self.controlPlane = ControlPlane(store: store, paths: paths)
            self.ingestionEngine = IngestionCoordinator(paths: paths, store: store)
            self.knowledgeLoop = KnowledgeLoop(store: store, paths: paths)
            self.foundationOrchestrator = HiveFoundationModelsOrchestrator()
            refreshFromStore()
            refreshChatStatusTextAsync()
            restoreCloudAppStateIfNeeded()
            restoreSwarmState()
            installAppleCredentialRevocationObserver()
            validateAppleCredentialState()
        } catch {
            let fallback = HivePaths(root: FileManager.default.temporaryDirectory.appendingPathComponent("Hive", isDirectory: true))
            self.paths = fallback
            self.store = try! HiveStore(databaseURL: fallback.database)
            self.controlPlane = ControlPlane(store: store, paths: fallback)
            self.ingestionEngine = IngestionCoordinator(paths: fallback, store: store)
            self.knowledgeLoop = KnowledgeLoop(store: store, paths: fallback)
            self.foundationOrchestrator = HiveFoundationModelsOrchestrator()
            self.errorText = error.localizedDescription
            refreshChatStatusTextAsync()
            restoreSwarmState()
            installAppleCredentialRevocationObserver()
            validateAppleCredentialState()
        }
    }

    private func restoreCloudAppStateIfNeeded() {
        guard let snapshot = cloudAppStateSync.load() else { return }
        if let surface = HivePrimarySurface(rawValue: snapshot.selectedSurface) {
            selectedSurface = surface
        }
        if let selectedPageID = snapshot.selectedPageID,
           wikiPages.contains(where: { $0.id == selectedPageID }) {
            self.selectedPageID = selectedPageID
        }
        if let selectedNodeID = snapshot.selectedNodeID,
           graph.nodes.contains(where: { $0.id == selectedNodeID }) {
            self.selectedNodeID = selectedNodeID
        }
    }

    private func publishCloudAppState() {
        let snapshot = HiveCloudAppStateSnapshot(
            selectedSurface: selectedSurface.rawValue,
            selectedPageID: selectedPageID,
            selectedNodeID: selectedNodeID
        )
        cloudAppStateSync.publish(snapshot)
    }

    public var organismState: HiveOrganismState {
        if isWorking { return .foraging }
        return currentOrganismState
    }

    public var isAppleAuthenticated: Bool {
        guard HiveAppleAccountPolicy.requiresSignInBeforeUse else { return true }
        return authenticatedAccount != nil || appleAccount != nil || temporaryGuestAccessEnabled
    }

    @discardableResult
    public func refreshAppleAuthentication() -> Bool {
        authenticatedAccount = HiveAccountStore.load()
        appleAccount = HiveAppleAccountStore.load()
        temporaryGuestAccessEnabled = HiveGuestAccessStore.isEnabled()
        if !isAppleAuthenticated {
            lockUnauthenticatedSurfaces()
        }
        return isAppleAuthenticated
    }

    public func validateAppleCredentialState() {
        guard HiveAppleAccountPolicy.requiresSignInBeforeUse else { return }
        let storedIdentity = HiveAccountStore.load()
        authenticatedAccount = storedIdentity
        appleAccount = HiveAppleAccountStore.load()
        temporaryGuestAccessEnabled = HiveGuestAccessStore.isEnabled()
        if let storedIdentity, storedIdentity.provider == .google {
            completeAuthenticatedSession(storedIdentity)
            return
        }
        let storedAccount = appleAccount ?? storedIdentity?.appleAccount
        guard let storedAccount else {
            if temporaryGuestAccessEnabled {
                errorText = nil
                return
            }
            applyAppleAuthenticationResolution(
                HiveAppleCredentialStateResolver.resolve(storedAccount: nil, validationResult: nil)
            )
            return
        }

        #if canImport(AuthenticationServices)
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: storedAccount.appleUserID) { state, error in
            let validationResult: HiveAppleCredentialValidationResult
            if let error {
                validationResult = .failed(error.localizedDescription)
            } else {
                switch state {
                case .authorized:
                    validationResult = .authorized
                case .revoked:
                    validationResult = .revoked
                case .notFound:
                    validationResult = .notFound
                case .transferred:
                    validationResult = .transferred
                @unknown default:
                    validationResult = .failed("Unknown Apple credential state.")
                }
            }
            Task { @MainActor in
                self.applyAppleAuthenticationResolution(
                    HiveAppleCredentialStateResolver.resolve(
                        storedAccount: storedAccount,
                        validationResult: validationResult
                    )
                )
            }
        }
        #else
        applyAppleAuthenticationResolution(
            HiveAppleCredentialStateResolver.resolve(
                storedAccount: storedAccount,
                validationResult: .failed("Sign in with Apple is unavailable on this platform.")
            )
        )
        #endif
    }

    public func signOutAppleAccount() {
        HiveAccountStore.clear()
        HiveAppleAccountStore.clear()
        HiveGoogleAccountStore.clear()
        HiveGuestAccessStore.clear()
        authenticatedAccount = nil
        appleAccount = nil
        temporaryGuestAccessEnabled = false
        firstLoginDataChoicePrompt = nil
        errorText = "Signed out of Hive."
        lockUnauthenticatedSurfaces()
    }

    public func continueAsGuestForNow() {
        guard HiveAppleAccountPolicy.temporaryGuestAccessIsEnabled else { return }
        HiveGuestAccessStore.enable()
        authenticatedAccount = nil
        appleAccount = nil
        temporaryGuestAccessEnabled = true
        firstLoginDataChoicePrompt = nil
        errorText = nil
    }

    @discardableResult
    private func requireAppleAuthentication() -> Bool {
        guard isAppleAuthenticated else {
            errorText = "Sign in to Hive before using Hive."
            lockUnauthenticatedSurfaces()
            return false
        }
        return true
    }

    private func lockUnauthenticatedSurfaces() {
        commandPaletteVisible = false
        chatVisible = false
        settingsVisible = false
        liveVisible = false
        isWorking = false
    }

    private func applyAppleAuthenticationResolution(_ resolution: HiveAppleAuthenticationResolution) {
        switch resolution {
        case .authenticated(let account):
            HiveAppleAccountStore.save(account)
            let identity = account.authenticatedAccount
            authenticatedAccount = identity
            appleAccount = account
            temporaryGuestAccessEnabled = false
            HiveGuestAccessStore.clear()
            completeAuthenticatedSession(identity)
        case .locked(let reason, let shouldClearStoredAccount):
            if HiveGuestAccessStore.isEnabled() {
                temporaryGuestAccessEnabled = true
                errorText = nil
                return
            }
            if shouldClearStoredAccount {
                HiveAppleAccountStore.clear()
            }
            authenticatedAccount = HiveAccountStore.load()
            appleAccount = nil
            temporaryGuestAccessEnabled = false
            errorText = reason
            lockUnauthenticatedSurfaces()
        }
    }

    private func completeAuthenticatedSession(_ account: HiveAuthenticatedAccount) {
        authenticatedAccount = account
        if account.provider == .apple {
            appleAccount = account.appleAccount
        } else {
            appleAccount = nil
        }
        temporaryGuestAccessEnabled = false
        HiveGuestAccessStore.clear()
        errorText = nil
        if HiveAppleAccountPolicy.requiresFirstLoginDataChoice,
           HiveFirstLoginDataChoiceStore.needsChoice(for: account) {
            firstLoginDataChoicePrompt = HiveFirstLoginDataChoicePrompt(account: account)
        }
    }

    public func resolveFirstLoginDataChoice(_ choice: HiveFirstLoginDataChoice) {
        guard let prompt = firstLoginDataChoicePrompt else { return }
        HiveFirstLoginDataChoiceStore.save(choice, for: prompt.account)
        authenticatedAccount = HiveAccountStore.load()
        if choice == .swarmMerge {
            sourcePluginStatusText = "Swarm will compare cloud and local Hive data before proposing changes."
        } else if choice == .cloud {
            sourcePluginStatusText = "Hive will use cloud data as the starting point on this device."
        } else {
            sourcePluginStatusText = "Hive will keep using the data already on this device."
        }
        firstLoginDataChoicePrompt = nil
    }

    private func installAppleCredentialRevocationObserver() {
        guard appleCredentialRevocationObserver == nil else { return }
        #if canImport(AuthenticationServices)
        appleCredentialRevocationObserver = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.authenticatedAccount?.provider == .apple || self?.appleAccount != nil else { return }
                self?.signOutAppleAccount()
                self?.errorText = "Apple revoked this Hive sign-in. Sign in again to continue."
            }
        }
        #endif
    }

    public var visibleSources: [SourceRecord] {
        sources.filter { source in
            source.deletionState == .active && source.status != .deleted
        }
    }

    public var selectedSource: SourceRecord? {
        selectedSourceID.flatMap { id in sources.first { $0.id == id } }
    }

    public var selectedClaim: ClaimRecord? {
        selectedClaimID.flatMap { id in claims.first { $0.id == id } }
    }

    public var selectedPage: WikiPageRecord? {
        if let selectedPageID, let page = wikiPages.first(where: { $0.id == selectedPageID && $0.isUserVisibleArticle }) {
            return page
        }
        return wikiPages.first(where: \.isUserVisibleArticle)
    }

    public var selectedNode: GraphNodeRecord? {
        selectedNodeID.flatMap { id in graph.nodes.first { $0.id == id } }
    }

    private func refreshChatStatusTextAsync() {
        let paths = paths
        DispatchQueue.global(qos: .utility).async {
            let statusText = Self.makeChatStatusText(paths: paths)
            DispatchQueue.main.async {
                self.chatStatusText = statusText
            }
        }
    }

    nonisolated private static func makeChatStatusText(paths: HivePaths) -> String {
        let cloudSettings = CloudInferenceSettingsStore.load()
        if cloudSettings.isConfigured {
            return MemoryCompilerRuntimeRouter().aiStatusLabel(for: .cloudWithUserKey)
        }
        if FoundationModelChatRuntime.currentAvailability() == .available {
            return MemoryCompilerRuntimeRouter().aiStatusLabel(for: .appleFoundationModels)
        }
        return AIAvailabilityPresentation.presentation(
            availability: ChatAnswerEngine.modelAvailability(modelsDirectory: paths.models),
            cloudSettings: cloudSettings
        ).statusText
    }

    public var activeSwarmThread: HiveSwarmThread? {
        guard let index = activeSwarmThreadIndex else { return nil }
        return swarmThreads[index]
    }

    public var activeSwarmThreadTitle: String {
        guard let index = activeSwarmThreadIndex else { return "New Chat" }
        let title = swarmThreads[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "New Chat" : title
    }

    public var activeSwarmLastMessageID: UUID? {
        guard let index = activeSwarmThreadIndex else { return nil }
        return swarmThreads[index].messages.last?.id
    }

    public var visibleSwarmThreadsForSurface: [HiveSwarmThread] {
        swarmThreads
            .prefix(Self.swarmSurfaceThreadLimit)
            .map(Self.displaySafeSwarmThread)
    }

    public var hiddenSwarmThreadCount: Int {
        max(0, swarmThreads.count - Self.swarmSurfaceThreadLimit)
    }

    public func activeSwarmMessagesForDisplay(limit requestedLimit: Int = HiveAppModel.swarmSurfaceMessageLimit) -> [HiveSwarmMessage] {
        guard let index = activeSwarmThreadIndex else { return [] }
        let limit = min(max(1, requestedLimit), Self.swarmSurfaceExpandedMessageLimit)
        return swarmThreads[index].messages
            .suffix(limit)
            .map(Self.displaySafeSwarmMessage)
    }

    public func hiddenActiveSwarmMessageCount(limit requestedLimit: Int = HiveAppModel.swarmSurfaceMessageLimit) -> Int {
        guard let index = activeSwarmThreadIndex else { return 0 }
        let limit = min(max(1, requestedLimit), Self.swarmSurfaceExpandedMessageLimit)
        return max(0, swarmThreads[index].messages.count - limit)
    }

    private var activeSwarmThreadIndex: Int? {
        if let activeSwarmThreadID,
           let index = swarmThreads.firstIndex(where: { $0.id == activeSwarmThreadID }) {
            return index
        }
        return swarmThreads.indices.first
    }

    public func startNewSwarmThread() {
        guard requireAppleAuthentication() else { return }
        let thread = HiveSwarmThread()
        swarmThreads.insert(thread, at: 0)
        activeSwarmThreadID = thread.id
        swarmDraft = ""
        quickSwarmLastDismissedAt = nil
        resetSwarmDraftSession(cancelCurrent: true)
        persistSwarmState()
    }

    public func openSwarmThread(_ id: UUID) {
        guard requireAppleAuthentication() else { return }
        guard swarmThreads.contains(where: { $0.id == id }) else { return }
        activeSwarmThreadID = id
        swarmDraft = ""
        quickSwarmLastDismissedAt = nil
        resetSwarmDraftSession(cancelCurrent: true)
        persistSwarmState()
    }

    public func deleteSwarmThread(_ id: UUID) {
        guard requireAppleAuthentication() else { return }
        swarmThreads.removeAll { $0.id == id }
        if swarmThreads.isEmpty {
            let thread = HiveSwarmThread()
            swarmThreads = [thread]
            activeSwarmThreadID = thread.id
        } else if activeSwarmThreadID == id {
            activeSwarmThreadID = swarmThreads.first?.id
        }
        resetSwarmDraftSession(cancelCurrent: true)
        persistSwarmState()
    }

    public func toggleSwarmPlugin(_ plugin: HiveSwarmPlugin) {
        guard requireAppleAuthentication() else { return }
        if swarmEnabledPlugins.contains(plugin) {
            swarmEnabledPlugins.remove(plugin)
        } else {
            swarmEnabledPlugins.insert(plugin)
        }
        persistSwarmState()
    }

    public func prepareQuickSwarmPopup(now: Date = Date(), warmSessionInterval: TimeInterval = HiveAppModel.quickSwarmWarmSessionSeconds) {
        guard requireAppleAuthentication() else { return }
        ensureActiveSwarmThread()
        if let dismissedAt = quickSwarmLastDismissedAt,
           now.timeIntervalSince(dismissedAt) >= warmSessionInterval,
           let activeThread = activeSwarmThread,
           !activeThread.messages.isEmpty,
           swarmDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           swarmDraftAttachments.isEmpty {
            startNewSwarmThread()
        }
        quickSwarmLastDismissedAt = nil
    }

    public func markQuickSwarmPopupDismissed(now: Date = Date()) {
        quickSwarmLastDismissedAt = now
    }

    public func openCurrentSwarmConversationInHive() {
        guard requireAppleAuthentication() else { return }
        prepareQuickSwarmPopup()
        selectedSurface = .swarm
        chatVisible = false
        commandPaletteVisible = false
        settingsVisible = false
        liveVisible = false
    }

    public func insertSwarmMention(_ reference: HiveSwarmReference) {
        let token = "@[\(reference.title)]"
        guard let atRange = swarmDraft.range(of: "@", options: .backwards) else {
            swarmDraft += swarmDraft.hasSuffix(" ") || swarmDraft.isEmpty ? token + " " : " \(token) "
            return
        }
        swarmDraft.replaceSubrange(atRange.lowerBound..<swarmDraft.endIndex, with: token + " ")
    }

    public func swarmMentionSuggestions(limit: Int = 8) -> [HiveSwarmReference] {
        let query = activeSwarmMentionQuery()
        let lowered = query.lowercased()
        var references: [HiveSwarmReference] = []

        if swarmEnabledPlugins.contains(.colony) {
            references += wikiPages
                .filter(\.isUserVisibleArticle)
                .map { page in
                    HiveSwarmReference(
                        id: "colony:\(page.id)",
                        kind: .colony,
                        title: SourcePresentationModel.cleanTitle(page.title),
                        detail: SourcePresentationModel.cleanTitle(page.summary)
                    )
                }
        }

        if swarmEnabledPlugins.contains(.field) {
            references += sourcePresentations.map { source in
                HiveSwarmReference(
                    id: "field:\(source.sourceID)",
                    kind: .field,
                    title: source.title,
                    detail: source.summary
                )
            }
        }

        if swarmEnabledPlugins.contains(.hive) {
            references += visibleGraphNodes.map { node in
                HiveSwarmReference(
                    id: "hive:\(node.id)",
                    kind: .hive,
                    title: SourcePresentationModel.cleanTitle(node.title),
                    detail: "\(node.kind.rawValue.capitalized) cell"
                )
            }
        }

        let filtered = references.filter { reference in
            guard !lowered.isEmpty else { return true }
            return reference.title.lowercased().contains(lowered) || reference.detail.lowercased().contains(lowered)
        }

        var seen = Set<String>()
        return filtered.filter { reference in
            let key = "\(reference.kind.rawValue):\(reference.title.lowercased())"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        .prefix(limit)
        .map { $0 }
    }

    public func addSwarmAttachmentURLs(_ urls: [URL]) {
        let accepted = urls.filter { $0.isFileURL }
        guard !accepted.isEmpty else { return }
        let draftID = swarmDraftSessionID
        for url in accepted {
            Task {
                _ = await swarmAttachmentPipeline.enqueue(url: url, forDraft: draftID)
                await refreshSwarmDraftAttachmentSnapshot(for: draftID)
                startSwarmAttachmentRefreshLoop(for: draftID)
            }
        }
    }

    public func removeSwarmAttachment(_ attachmentID: UUID) {
        let draftID = swarmDraftSessionID
        Task {
            await swarmAttachmentPipeline.remove(attachmentID: attachmentID, fromDraft: draftID)
            await refreshSwarmDraftAttachmentSnapshot(for: draftID)
        }
    }

    private func resetSwarmDraftSession(cancelCurrent: Bool) {
        let oldDraftID = swarmDraftSessionID
        swarmAttachmentRefreshTask?.cancel()
        swarmAttachmentRefreshTask = nil
        swarmDraftAttachments = []
        swarmDraftSessionID = UUID()
        if cancelCurrent {
            Task { await swarmAttachmentPipeline.cancelDraft(oldDraftID) }
        }
    }

    private func startSwarmAttachmentRefreshLoop(for draftID: UUID) {
        swarmAttachmentRefreshTask?.cancel()
        swarmAttachmentRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 350_000_000)
                await self?.refreshSwarmDraftAttachmentSnapshot(for: draftID)
                let snapshot = await self?.swarmAttachmentPipeline.snapshot(forDraft: draftID) ?? []
                if snapshot.allSatisfy({ $0.status != .extracting && $0.status != .queued }) {
                    break
                }
            }
        }
    }

    private func refreshSwarmDraftAttachmentSnapshot(for draftID: UUID) async {
        let snapshot = await swarmAttachmentPipeline.snapshot(forDraft: draftID)
        guard swarmDraftSessionID == draftID else { return }
        swarmDraftAttachments = snapshot
    }

    public func sendSwarmMessage() {
        guard requireAppleAuthentication() else { return }
        let prompt = HiveLiveAssistantRouter.normalizedPrompt(swarmDraft)
        let submittedAttachments = swarmDraftAttachments
        guard !prompt.isEmpty || !submittedAttachments.isEmpty else { return }
        ensureActiveSwarmThread()
        guard let threadID = activeSwarmThreadID else { return }
        let submittedPrompt = prompt.isEmpty ? "Use the attached context." : prompt
        let draftID = swarmDraftSessionID
        let references = resolvedSwarmReferences(in: submittedPrompt)
        let attachmentNames = submittedAttachments.map(\.displayName)
        let userText = attachmentNames.isEmpty
            ? submittedPrompt
            : "\(submittedPrompt)\n\nAttachments: \(attachmentNames.joined(separator: ", "))"
        appendSwarmMessage(
            threadID: threadID,
            speaker: .user,
            text: userText,
            citations: references
        )
        swarmDraft = ""
        resetSwarmDraftSession(cancelCurrent: false)

        Task {
            let committedAttachments = await swarmAttachmentPipeline.commitCompleted(forDraft: draftID)
            await handleCommittedSwarmMessage(
                prompt: submittedPrompt,
                references: references,
                threadID: threadID,
                attachments: committedAttachments
            )
        }
    }

    private func handleCommittedSwarmMessage(
        prompt: String,
        references: [HiveSwarmReference],
        threadID: UUID,
        attachments: [SwarmAttachmentExtractionResult]
    ) async {
        let earlyDecision = SwarmRequestRouter().decide(SwarmRequestRoutingInput(
            prompt: prompt,
            hasAttachments: !attachments.isEmpty,
            hasExplicitReferences: !references.isEmpty,
            colonyChunkCount: 0,
            webPluginEnabled: swarmEnabledPlugins.contains(.web)
        ))

        if swarmEnabledPlugins.contains(.web), let url = firstWebURL(in: prompt) {
            appendSwarmMessage(
                threadID: threadID,
                speaker: .swarm,
                text: "Saved the link to Field. Hive will read it before treating it as memory.",
                citations: references,
                note: "Field"
            )
            let request = HiveStartupSourcePluginRequest(
                selections: [HiveStartupSourcePluginSelection(kind: .webPages, isEnabled: true)],
                pasteLocation: url.absoluteString,
                prompt: prompt
            )
            configureStartupSourcePlugins(request)
            return
        }

        if earlyDecision.intent == .incorporateInformation {
            incorporateSwarmInformation(prompt, references: references, threadID: threadID, attachments: attachments)
            return
        }

        if earlyDecision.intent == .lookOnline,
           earlyDecision.shouldAskForApprovedURL,
           !CloudInferenceSettingsStore.load().isConfigured {
            appendSwarmMessage(
                threadID: threadID,
                speaker: .swarm,
                text: "That needs online information. Paste a link for Field to capture, or save a Cloud key for explicit online Ask. I will not browse or crawl without one of those.",
                citations: references,
                note: "Online source needed"
            )
            return
        }

        switch HiveLiveAssistantRouter.route(prompt) ?? .ask(prompt) {
        case .captureCurrentPage(let command, let followUpQuestion):
            appendSwarmMessage(
                threadID: threadID,
                speaker: .swarm,
                text: followUpQuestion == nil ? "Capturing the current page into Field." : "Capturing the current page, then answering with that context.",
                citations: references,
                note: "Capture"
            )
            selectedSurface = .rawInputs
            captureCurrentPage(command: command, followUpQuestion: followUpQuestion)
        case .addInformation(let text):
            appendSwarmMessage(
                threadID: threadID,
                speaker: .swarm,
                text: "Saved to Field. Hive is updating The Colony and The Hive from that note.",
                citations: references,
                note: "Field"
            )
            ingestText(text)
        case .searchHive(let query):
            selectedSurface = .graph
            graphSearchText = query
            graphSearchVisible = true
            appendSwarmMessage(
                threadID: threadID,
                speaker: .swarm,
                text: "Opened The Hive search for “\(query)”.",
                citations: references,
                note: "Hive"
            )
        case .reorganizeTopic(let topic):
            appendSwarmMessage(
                threadID: threadID,
                speaker: .swarm,
                text: "Reorganizing “\(topic)” across The Colony and The Hive.",
                citations: references,
                note: "Swarm"
            )
            reorganizeKnowledgeAround(topic: topic, threadID: threadID, references: references)
        case .defineAutomation(let request):
            createAutomationFromSwarm(request, threadID: threadID, references: references)
        case .defineSkill(let request):
            createSkillFromSwarm(request, threadID: threadID, references: references)
        case .ask(let question):
            answerSwarmQuestion(
                question,
                references: references,
                threadID: threadID,
                attachments: attachments,
                routingDecision: earlyDecision
            )
        }
    }

    private static let swarmThreadsKey = "hive.swarm.threads"
    private static let activeSwarmThreadKey = "hive.swarm.activeThreadID"
    private static let swarmPluginsKey = "hive.swarm.plugins"

    private func restoreSwarmState(defaults: UserDefaults = .standard) {
        let decoder = JSONDecoder()
        if let data = defaults.data(forKey: Self.swarmThreadsKey),
           let decoded = try? decoder.decode([HiveSwarmThread].self, from: data),
           !decoded.isEmpty {
            swarmThreads = decoded.sorted { $0.updatedAt > $1.updatedAt }
        }
        if let active = defaults.string(forKey: Self.activeSwarmThreadKey),
           let uuid = UUID(uuidString: active),
           swarmThreads.contains(where: { $0.id == uuid }) {
            activeSwarmThreadID = uuid
        } else {
            activeSwarmThreadID = swarmThreads.first?.id
        }
        if let data = defaults.data(forKey: Self.swarmPluginsKey),
           let decoded = try? decoder.decode([HiveSwarmPlugin].self, from: data),
           !decoded.isEmpty {
            swarmEnabledPlugins = Set(decoded)
        }
        ensureActiveSwarmThread()
    }

    private func persistSwarmState(defaults: UserDefaults = .standard) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(swarmThreads) {
            defaults.set(data, forKey: Self.swarmThreadsKey)
        }
        if let activeSwarmThreadID {
            defaults.set(activeSwarmThreadID.uuidString, forKey: Self.activeSwarmThreadKey)
        }
        if let data = try? encoder.encode(Array(swarmEnabledPlugins).sorted { $0.rawValue < $1.rawValue }) {
            defaults.set(data, forKey: Self.swarmPluginsKey)
        }
    }

    private func ensureActiveSwarmThread() {
        if let activeSwarmThreadID, swarmThreads.contains(where: { $0.id == activeSwarmThreadID }) {
            return
        }
        if let first = swarmThreads.first {
            activeSwarmThreadID = first.id
            return
        }
        let thread = HiveSwarmThread()
        swarmThreads = [thread]
        activeSwarmThreadID = thread.id
    }

    @discardableResult
    private func appendSwarmMessage(
        threadID: UUID,
        speaker: HiveSwarmMessageSpeaker,
        text: String,
        citations: [HiveSwarmReference] = [],
        note: String? = nil,
        id: UUID = UUID()
    ) -> UUID {
        let message = HiveSwarmMessage(id: id, speaker: speaker, text: text, citations: citations, note: note)
        mutateSwarmThread(threadID) { thread in
            thread.messages.append(message)
            thread.updatedAt = Date()
            if speaker == .user && (thread.title == "New Chat" || thread.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                thread.title = Self.swarmThreadTitle(for: text)
            }
        }
        return id
    }

    private func replaceSwarmMessage(threadID: UUID, messageID: UUID, with replacement: HiveSwarmMessage) {
        mutateSwarmThread(threadID) { thread in
            if let index = thread.messages.firstIndex(where: { $0.id == messageID }) {
                thread.messages[index] = replacement
            } else {
                thread.messages.append(replacement)
            }
            thread.updatedAt = Date()
        }
    }

    private func mutateSwarmThread(_ threadID: UUID, _ mutate: (inout HiveSwarmThread) -> Void) {
        guard let index = swarmThreads.firstIndex(where: { $0.id == threadID }) else { return }
        mutate(&swarmThreads[index])
        swarmThreads.sort { $0.updatedAt > $1.updatedAt }
        persistSwarmState()
    }

    private static func swarmThreadTitle(for text: String) -> String {
        let cleaned = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "New Chat"
        guard !cleaned.isEmpty else { return "New Chat" }
        return String(cleaned.prefix(54))
    }

    private static func displaySafeSwarmThread(_ thread: HiveSwarmThread) -> HiveSwarmThread {
        var copy = thread
        copy.messages = thread.messages.suffix(1).map(displaySafeSwarmMessage)
        return copy
    }

    private static func displaySafeSwarmMessage(_ message: HiveSwarmMessage) -> HiveSwarmMessage {
        var copy = message
        if copy.text.count > swarmSurfaceMessageCharacterLimit {
            let prefix = copy.text.prefix(swarmSurfaceMessageCharacterLimit)
            copy.text = "\(prefix)\n\nEarlier text is preserved in Swarm history."
        }
        if copy.citations.count > 8 {
            copy.citations = Array(copy.citations.prefix(8))
        }
        return copy
    }

    private func incorporateSwarmInformation(
        _ prompt: String,
        references: [HiveSwarmReference],
        threadID: UUID,
        attachments: [SwarmAttachmentExtractionResult]
    ) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentURLs = attachments.map(\.fileURL)
        if !attachmentURLs.isEmpty {
            ingest(urls: attachmentURLs)
        }
        if Self.shouldPersistSwarmPrompt(trimmed) {
            ingestText(trimmed)
        }
        let attachmentText = attachmentURLs.isEmpty
            ? ""
            : " \(attachmentURLs.count) attachment\(attachmentURLs.count == 1 ? "" : "s") will process with the settled Field batch."
        appendSwarmMessage(
            threadID: threadID,
            speaker: .swarm,
            text: "Added this to Field.\(attachmentText) I will only update The Colony and The Hive after the source passes the normal extraction checks.",
            citations: references,
            note: "Field"
        )
    }

    private static func shouldPersistSwarmPrompt(_ prompt: String) -> Bool {
        let lower = prompt.lowercased()
        guard !prompt.isEmpty else { return false }
        guard lower != "use the attached context." else { return false }
        guard lower != "use the attached context" else { return false }
        return true
    }

    private static func swarmPendingText(
        for decision: SwarmRequestDecision,
        hasAttachments: Bool,
        hasLocalEvidence: Bool
    ) -> String {
        switch decision.intent {
        case .lookOnline:
            return decision.shouldUseOnlineSource
                ? "Checking the approved online path."
                : "Checking whether online context is needed."
        case .answerFromContext:
            return hasAttachments
                ? "Reading attachments and local context."
                : "Reading local context."
        case .incorporateInformation:
            return "Adding this to Field."
        case .answerDirectly:
            return hasLocalEvidence ? "Checking local context first." : "Answering directly."
        }
    }

    private func answerSwarmQuestion(
        _ query: String,
        references: [HiveSwarmReference],
        threadID: UUID,
        attachments: [SwarmAttachmentExtractionResult] = [],
        routingDecision initialRoutingDecision: SwarmRequestDecision? = nil
    ) {
        var contextPlan = swarmContextPlan(for: query, references: references, attachments: attachments, threadID: threadID)
        let routingDecision = SwarmRequestRouter().decide(SwarmRequestRoutingInput(
            prompt: query,
            hasAttachments: !attachments.isEmpty,
            hasExplicitReferences: !references.isEmpty,
            colonyChunkCount: contextPlan.colonyChunks.count,
            webPluginEnabled: swarmEnabledPlugins.contains(.web)
        ))
        let compaction = swarmContextCompactor.compactIfNeeded(
            messages: swarmContextMessages(threadID: threadID),
            plan: contextPlan,
            profile: contextPlan.modelProfile
        )
        if compaction.didCompact {
            applySwarmCompaction(compaction, threadID: threadID)
            contextPlan.compactionMemory = compaction.memoryChunk
        }
        let effectiveDecision = initialRoutingDecision?.intent == .lookOnline ? initialRoutingDecision ?? routingDecision : routingDecision
        let effectiveQuery = swarmPrompt(
            query,
            references: references,
            contextPlan: contextPlan,
            threadID: threadID,
            routingDecision: effectiveDecision
        )
        let review = ReviewQueueBuilder().build(claims: claims, sources: sources, feedback: (try? store.fetchFeedback()) ?? [])
        let visibility = currentVisibility()
        var localAnswer = chatAnswerEngine.answer(
            query: effectiveQuery,
            sources: sources,
            claims: claims,
            wikiPages: wikiPages,
            reviewQueue: review,
            modelAvailability: ChatAnswerEngine.modelAvailability(modelsDirectory: paths.models),
            visibility: visibility
        )
        let localCitations = localAnswer.citations.map { source in
            HiveSwarmReference(
                id: "field:\(source.id)",
                kind: .field,
                title: SourcePresentationModel.naturalTitle(for: source),
                detail: "\(source.kind.rawValue.capitalized) source"
            )
        }
        localAnswer = contextualSwarmFallbackAnswer(
            query: query,
            localAnswer: localAnswer,
            contextPlan: contextPlan
        )
        let localHasEvidence = !localAnswer.citations.isEmpty || !contextPlan.colonyChunks.isEmpty || !contextPlan.attachments.isEmpty
        let pendingID = UUID()
        appendSwarmMessage(
            threadID: threadID,
            speaker: .swarm,
            text: Self.swarmPendingText(for: effectiveDecision, hasAttachments: !attachments.isEmpty, hasLocalEvidence: localHasEvidence),
            citations: references + localCitations,
            note: chatStatusText,
            id: pendingID
        )

        let cloudSettings = CloudInferenceSettingsStore.load()
        let foundationAvailable = FoundationModelChatRuntime.currentAvailability() == .available
        let shouldUseOnlineAsk = cloudSettings.isConfigured
            && (effectiveDecision.shouldUseOnlineSource || (!foundationAvailable && (localHasEvidence || effectiveDecision.intent == .answerDirectly || effectiveDecision.intent == .answerFromContext)))

        if foundationAvailable && !effectiveDecision.shouldUseOnlineSource {
            isWorking = true
            Task {
                let result = await foundationOrchestrator.answerChat(
                    query: effectiveQuery,
                    localAnswer: localAnswer,
                    claims: claims,
                    wikiPages: wikiPages,
                    visibility: visibility
                )
                let answer = result.proposal.citedAnswer(fallback: localAnswer, fallbackReason: result.fallbackReason)
                lastAnswerForFiling = (query: query, answer: answer)
                replaceSwarmMessage(
                    threadID: threadID,
                    messageID: pendingID,
                    with: swarmMessage(from: answer, id: pendingID, references: references, note: answer.uncertainty)
                )
                isWorking = false
            }
            return
        }

        if shouldUseOnlineAsk {
            let sharingMode = cloudSettings.requiresPreSendReview ? OnlineAskContextSharingMode.questionOnly : .localContextAllowed
            let relevantChunks = sharingMode == .localContextAllowed
                ? onlineAskContextChunks(query: effectiveQuery, localAnswer: localAnswer)
                : []
            isWorking = true
            Task {
                let answer = await CloudChatAnswerEngine().answer(
                    query: effectiveQuery,
                    localAnswer: localAnswer,
                    sources: sources,
                    chunks: relevantChunks,
                    claims: claims,
                    wikiPages: wikiPages,
                    visibility: visibility,
                    settings: cloudSettings,
                    sharingMode: sharingMode,
                    allowWebSearch: effectiveDecision.shouldUseOnlineSource
                )
                lastAnswerForFiling = (query: query, answer: answer)
                replaceSwarmMessage(
                    threadID: threadID,
                    messageID: pendingID,
                    with: swarmMessage(from: answer, id: pendingID, references: references, note: answer.uncertainty)
                )
                isWorking = false
            }
            return
        }

        lastAnswerForFiling = (query: query, answer: localAnswer)
        replaceSwarmMessage(
            threadID: threadID,
            messageID: pendingID,
            with: swarmMessage(from: localAnswer, id: pendingID, references: references, note: localAnswer.uncertainty)
        )
    }

    private func reorganizeKnowledgeAround(topic: String, threadID: UUID, references: [HiveSwarmReference]) {
        let normalizedTopic = SourcePresentationModel.cleanTitle(topic)
        guard !normalizedTopic.isEmpty else { return }
        isWorking = true
        DispatchQueue.global(qos: .userInitiated).async { [paths, store, knowledgeLoop] in
            let result = Result { () -> SwarmReorganizationResult in
                let organizer = SwarmKnowledgeOrganizer()
                let reorganization = organizer.reorganize(
                    topic: normalizedTopic,
                    pages: try store.fetchWikiPages(),
                    claims: try store.fetchClaims()
                )
                try store.saveWikiPage(reorganization.page)
                try store.appendAudit(reorganization.auditEvent)
                _ = try knowledgeLoop.updateDerivedKnowledge()
                try WikiVaultManager(paths: paths).writeVault(pages: store.fetchWikiPages())
                return reorganization
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let reorganization):
                    self.refreshFromStoreAsync {
                        self.selectedSurface = .wiki
                        self.selectedPageID = reorganization.page.id
                    }
                    self.appendSwarmMessage(
                        threadID: threadID,
                        speaker: .swarm,
                        text: """
                        Done. I created \(reorganization.page.title), linked \(reorganization.matchedPageTitles.count) related Colony page\(reorganization.matchedPageTitles.count == 1 ? "" : "s"), and reviewed \(reorganization.matchedClaimCount) durable claim\(reorganization.matchedClaimCount == 1 ? "" : "s").

                        I did not delete sources or merge pages automatically. This hub gives Swarm a concrete place to keep organizing future \(reorganization.topic) material.
                        """,
                        citations: references,
                        note: "Colony"
                    )
                case .failure(let error):
                    self.errorText = error.localizedDescription
                    self.appendSwarmMessage(
                        threadID: threadID,
                        speaker: .swarm,
                        text: "I could not reorganize \(normalizedTopic): \(error.localizedDescription)",
                        citations: references,
                        note: "Error"
                    )
                }
            }
        }
    }

    private func createAutomationFromSwarm(_ request: String, threadID: UUID, references: [HiveSwarmReference]) {
        let title = Self.partnerTitle(from: request, fallback: "Custom Automation")
        var settings = HiveAutomationSettingsStore.load()
        let definition = HiveCustomAutomationDefinition(
            title: title,
            goal: request,
            sources: "Swarm chat",
            cadence: Self.partnerCadence(from: request),
            output: "Swarm message, notification-ready summary, or Colony page"
        )
        settings.customAutomations.insert(definition, at: 0)
        HiveAutomationSettingsStore.save(settings)

        let sourceRequest = HiveStartupSourcePluginRequest(
            selections: [HiveStartupSourcePluginSelection(kind: .uploads, isEnabled: true)],
            pasteLocation: "",
            prompt: """
            Swarm automation request:
            \(request)

            Turn this into a local Hive automation. Identify the sources it should read, the cadence, the output surface, notification wording, and any missing permissions or user decisions needed before it can run safely.
            """
        )
        configureStartupSourcePlugins(sourceRequest)
        appendSwarmMessage(
            threadID: threadID,
            speaker: .swarm,
            text: "Saved “\(title)” as a custom automation draft and added its setup brief to Field so Hive can resolve the source, cadence, and notification details before it runs.",
            citations: references,
            note: "Automation"
        )
    }

    private func createSkillFromSwarm(_ request: String, threadID: UUID, references: [HiveSwarmReference]) {
        let title = Self.partnerTitle(from: request, fallback: "Custom Skill")
        let skill = HiveSkillDefinition(
            title: title,
            instruction: request,
            triggerPhrases: [String(request.prefix(80))]
        )
        HiveSkillDefinitionStore.add(skill)
        let sourceRequest = HiveStartupSourcePluginRequest(
            selections: [HiveStartupSourcePluginSelection(kind: .uploads, isEnabled: true)],
            pasteLocation: "",
            prompt: """
            Swarm skill request:
            \(request)

            Convert this into a reusable Hive skill. Define when Swarm should apply it, what sources it may read, what it should never mutate without confirmation, and how the result should be shown to the user.
            """
        )
        configureStartupSourcePlugins(sourceRequest)
        appendSwarmMessage(
            threadID: threadID,
            speaker: .swarm,
            text: "Created the local skill “\(title)” and added a setup brief to Field so Hive can refine the workflow against your Colony.",
            citations: references,
            note: "Skill"
        )
    }

    private static func partnerTitle(from request: String, fallback: String) -> String {
        let cleaned = SourcePresentationModel.cleanTitle(request)
            .replacingOccurrences(of: "Set Up Automation", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Create Automation", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Make An Automation", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Create A Skill", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Make A Skill", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Teach Hive To", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.:;-").union(.whitespacesAndNewlines))
        guard !cleaned.isEmpty else { return fallback }
        return String(cleaned.prefix(48))
    }

    private static func partnerCadence(from request: String) -> String {
        let lower = request.lowercased()
        if lower.contains("every morning") || lower.contains("daily") || lower.contains("each day") {
            return "Daily"
        }
        if lower.contains("weekly") || lower.contains("every week") {
            return "Weekly"
        }
        if lower.contains("when ") || lower.contains("whenever ") || lower.contains("notify me when") {
            return "Event-based"
        }
        return "On demand until scheduled"
    }

    private func swarmMessage(from answer: CitedAnswer, id: UUID, references: [HiveSwarmReference], note: String?) -> HiveSwarmMessage {
        let citations = answer.citations.map { source in
            HiveSwarmReference(
                id: "field:\(source.id)",
                kind: .field,
                title: SourcePresentationModel.naturalTitle(for: source),
                detail: "\(source.kind.rawValue.capitalized) source"
            )
        }
        return HiveSwarmMessage(
            id: id,
            speaker: .swarm,
            text: sanitizeAssistantAnswer(answer.answer),
            citations: references + citations,
            note: note
        )
    }

    private func swarmContextPlan(
        for query: String,
        references: [HiveSwarmReference],
        attachments: [SwarmAttachmentExtractionResult],
        threadID: UUID
    ) -> SwarmContextPlan {
        let profile = activeSwarmModelProfile()
        return swarmContextRetriever.retrieve(
            prompt: swarmPromptSeed(query, references: references),
            attachments: attachments,
            pages: wikiPages.filter(\.isUserVisibleArticle),
            recentHistory: swarmContextMessages(threadID: threadID),
            profile: profile
        )
    }

    private func activeSwarmModelProfile() -> SwarmModelProfile {
        if CloudInferenceSettingsStore.load().isConfigured {
            return SwarmModelProfileRegistry.cloud
        }
        if FoundationModelChatRuntime.currentAvailability() == .available {
            return SwarmModelProfileRegistry.appleIntelligence
        }
        return SwarmModelProfileRegistry.indexedWiki
    }

    private func swarmContextMessages(threadID: UUID) -> [SwarmContextMessage] {
        guard let thread = swarmThreads.first(where: { $0.id == threadID }) else { return [] }
        return thread.messages.map { message in
            let role: SwarmContextRole
            if message.note == "Memory" {
                role = .system
            } else {
                role = message.speaker == .user ? .user : .assistant
            }
            return SwarmContextMessage(id: message.id.uuidString, role: role, text: message.text)
        }
    }

    private func applySwarmCompaction(_ compaction: SwarmCompactionResult, threadID: UUID) {
        guard compaction.didCompact, let memoryChunk = compaction.memoryChunk else { return }
        let removeIDs = Set(compaction.removedMessageIDs.compactMap(UUID.init(uuidString:)))
        mutateSwarmThread(threadID) { thread in
            thread.messages.removeAll { removeIDs.contains($0.id) }
            if !thread.messages.contains(where: { $0.note == "Memory" && $0.text == memoryChunk }) {
                thread.messages.insert(HiveSwarmMessage(speaker: .swarm, text: memoryChunk, note: "Memory"), at: 0)
            }
        }
    }

    private func contextualSwarmFallbackAnswer(
        query: String,
        localAnswer: CitedAnswer,
        contextPlan: SwarmContextPlan
    ) -> CitedAnswer {
        guard localAnswer.uncertainty == ModelAvailabilityState.indexedMemoryOnly.userVisibleLabel,
              (!contextPlan.attachments.isEmpty || !contextPlan.colonyChunks.isEmpty)
        else {
            return localAnswer
        }
        var sections: [String] = []
        if !contextPlan.attachments.isEmpty {
            let attachmentSummary = contextPlan.attachments.prefix(3).map { attachment in
                "\(attachment.displayName): \(attachment.summary)"
            }.joined(separator: "\n")
            sections.append("I found relevant context in the active attachment set:\n\(attachmentSummary)")
        }
        if !contextPlan.colonyChunks.isEmpty {
            let colonySummary = contextPlan.colonyChunks.prefix(3).map { chunk in
                "\(SourcePresentationModel.cleanTitle(chunk.pageTitle)): \(String(chunk.text.prefix(220)))"
            }.joined(separator: "\n")
            sections.append("The most relevant Colony entries for “\(query)” are:\n\(colonySummary)")
        }
        return CitedAnswer(
            answer: sections.joined(separator: "\n\n"),
            citations: localAnswer.citations,
            uncertainty: "Context-managed local answer",
            suggestedActions: Self.stableUniqueStrings(localAnswer.suggestedActions + ["Ask follow-up", "Save Last Answer"])
        )
    }

    private static func stableUniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in values {
            let key = value.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(value)
        }
        return output
    }

    private func swarmPromptSeed(_ query: String, references: [HiveSwarmReference]) -> String {
        guard !references.isEmpty else { return query }
        let context = references.prefix(8).map { reference in
            "- \(reference.kind.displayTitle): \(reference.title) — \(reference.detail)"
        }.joined(separator: "\n")
        return """
        \(query)

        Swarm context selected with @ mentions:
        \(context)
        """
    }

    private func swarmPrompt(
        _ query: String,
        references: [HiveSwarmReference],
        contextPlan: SwarmContextPlan,
        threadID: UUID,
        routingDecision: SwarmRequestDecision? = nil
    ) -> String {
        let selectedReferences = references.prefix(8).map { reference in
            "- \(reference.kind.displayTitle): \(reference.title) — \(reference.detail)"
        }
        return swarmContextPromptBuilder.buildPrompt(
            userPrompt: query,
            selectedReferences: selectedReferences,
            plan: contextPlan,
            recentHistory: swarmContextMessages(threadID: threadID),
            routingDecision: routingDecision
        )
    }

    private func activeSwarmMentionQuery() -> String {
        guard let at = swarmDraft.range(of: "@", options: .backwards) else { return "" }
        let raw = String(swarmDraft[at.upperBound...])
        if raw.hasPrefix("[") { return "" }
        return raw
            .components(separatedBy: .whitespacesAndNewlines)
            .first?
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]")) ?? ""
    }

    private func resolvedSwarmReferences(in text: String) -> [HiveSwarmReference] {
        let titles = Self.bracketedMentionTitles(in: text)
        guard !titles.isEmpty else { return [] }
        let all = swarmMentionSuggestions(limit: 250)
        var seen = Set<String>()
        return titles.compactMap { title in
            guard let reference = all.first(where: { $0.title.caseInsensitiveCompare(title) == .orderedSame }) else { return nil }
            guard !seen.contains(reference.id) else { return nil }
            seen.insert(reference.id)
            return reference
        }
    }

    private static func bracketedMentionTitles(in text: String) -> [String] {
        var titles: [String] = []
        var searchStart = text.startIndex
        while let start = text.range(of: "@[", range: searchStart..<text.endIndex),
              let end = text.range(of: "]", range: start.upperBound..<text.endIndex) {
            let title = String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                titles.append(title)
            }
            searchStart = end.upperBound
        }
        return titles
    }

    private func firstWebURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector
            .matches(in: text, options: [], range: range)
            .compactMap(\.url)
            .first { url in
                guard let scheme = url.scheme?.lowercased() else { return false }
                return scheme == "http" || scheme == "https"
            }
    }

    public func refreshFromStore() {
        do {
            applyStoreSnapshot(try Self.makeStoreSnapshot(store: store))
        } catch {
            errorText = error.localizedDescription
        }
    }

    public func refreshKnowledge() {
        guard requireAppleAuthentication() else { return }
        isWorking = true
        knowledgeMutationQueue.async { [knowledgeLoop, store] in
            let result = Result {
                try knowledgeLoop.updateDerivedKnowledge()
                return try Self.makeStoreSnapshot(store: store)
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let snapshot):
                    self.applyStoreSnapshot(snapshot)
                case .failure(let error):
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    private func refreshFromStoreAsync(
        statusText: String? = nil,
        onSuccess: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        if let statusText {
            sourcePluginStatusText = statusText
        }
        DispatchQueue.global(qos: .userInitiated).async { [store] in
            let result = Result { try Self.makeStoreSnapshot(store: store) }
            DispatchQueue.main.async {
                switch result {
                case .success(let snapshot):
                    self.applyStoreSnapshot(snapshot)
                    onSuccess()
                case .failure(let error):
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    private func performKnowledgeMutation(
        statusText: String? = nil,
        work: @escaping @Sendable () throws -> Void,
        onSuccess: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        performKnowledgeMutationReturning(
            statusText: statusText,
            work: {
                try work()
                return ()
            },
            onSuccess: { _ in onSuccess() }
        )
    }

    private func performKnowledgeMutationReturning<Value: Sendable>(
        statusText: String? = nil,
        work: @escaping @Sendable () throws -> Value,
        onSuccess: @escaping @MainActor @Sendable (Value) -> Void = { _ in }
    ) {
        guard requireAppleAuthentication() else { return }
        isWorking = true
        if let statusText {
            sourcePluginStatusText = statusText
        }
        knowledgeMutationQueue.async { [knowledgeLoop, store] in
            let result = Result {
                let value = try work()
                try knowledgeLoop.updateDerivedKnowledge()
                let snapshot = try Self.makeStoreSnapshot(store: store)
                return (value, snapshot)
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let (value, snapshot)):
                    self.applyStoreSnapshot(snapshot)
                    onSuccess(value)
                case .failure(let error):
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    nonisolated private static func makeStoreSnapshot(store: HiveStore) throws -> HiveAppStoreSnapshot {
        let sources = try store.fetchSources()
        let claims = try store.fetchClaims()
        let wikiPages = try store.fetchWikiPages()
        let entities = try store.fetchEntities()
        let relationships = try store.fetchRelationships()
        let visibility = MemoryRelevanceEngine().evaluate(
            sources: sources,
            claims: claims,
            entities: entities,
            feedback: try store.fetchFeedback()
        ).visibility
        let activeSources = sources.filter { source in
            source.deletionState == .active && source.status != .deleted
        }
        let visibleSourceIDs = RawInputSemanticClusterer.defaultVisibleSourceIDs(
            sources: activeSources,
            claims: claims,
            visibility: visibility
        )
        let sourcePresentations = activeSources
            .filter { visibleSourceIDs.contains($0.id) }
            .map { sourcePresentation(for: $0, store: store) }
            .filter(\.isDefaultVisibleRawInput)
        let allSourcePresentations = activeSources.map { sourcePresentation(for: $0, store: store) }
        let rawInputClusters = RawInputCellCluster.clusters(from: sourcePresentations)
        let graph = GraphEngine().buildGraph(
            sources: sources,
            claims: claims,
            entities: entities,
            relationships: relationships,
            visibility: visibility
        )
        return HiveAppStoreSnapshot(
            sources: sources,
            claims: claims,
            wikiPages: wikiPages,
            currentOrganismState: HiveStatusTranslator.globalState(sources: sources),
            visibility: visibility,
            sourcePresentations: sourcePresentations,
            rawSourcePresentations: allSourcePresentations,
            stagedItems: sources.filter { $0.status == .queued },
            processedItems: sources.filter { $0.status == .extracted },
            stagedSourcePresentations: allSourcePresentations.filter(\.isStaged),
            processedSourcePresentations: allSourcePresentations.filter { !$0.isStaged && !$0.isProcessing },
            rawInputClusters: rawInputClusters,
            graph: graph
        )
    }

    private func applyStoreSnapshot(_ snapshot: HiveAppStoreSnapshot) {
        sources = snapshot.sources
        claims = snapshot.claims
        wikiPages = snapshot.wikiPages
        currentOrganismState = snapshot.currentOrganismState
        cachedVisibility = snapshot.visibility
        sourcePresentations = snapshot.sourcePresentations
        rawSourcePresentations = snapshot.rawSourcePresentations
        stagedItems = snapshot.stagedItems
        processedItems = snapshot.processedItems
        stagedSourcePresentations = snapshot.stagedSourcePresentations
        processedSourcePresentations = snapshot.processedSourcePresentations
        rawInputClusters = snapshot.rawInputClusters
        applyGraphSnapshot(snapshot.graph)
        if selectedPageID == nil || selectedPage == nil {
            selectedPageID = selectedPage?.id
        }
        schedulePendingStagedSourceProcessingIfNeeded()
    }

    public func runMorningBriefingNow() {
        guard requireAppleAuthentication() else { return }
        isWorking = true
        sourcePluginStatusText = "Preparing Morning Briefing..."
        DispatchQueue.global(qos: .background).async { [paths, ingestionEngine, knowledgeLoop, store] in
            let result = Result { () -> WikiPageRecord in
                let now = Date()
                let sourceRequest = HiveStartupSourcePluginCatalog.load()
                if sourceRequest.canRunWithoutPicker {
                    _ = try HiveStartupSourcePluginBackend().execute(
                        request: sourceRequest,
                        paths: paths,
                        store: store,
                        ingestionEngine: ingestionEngine,
                        now: now,
                        processImmediately: true
                    )
                }
                try ingestionEngine.processPending(limit: 250)
                _ = try knowledgeLoop.updateDerivedKnowledge()
                let page = try HiveAutomationOrchestrator(store: store, paths: paths).runMorningBriefing(now: now)
                HiveMaintenanceSchedule.makeSharedDefaults().set(now, forKey: HiveMaintenanceSchedule.lastRunKey)
                return page
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let page):
                    self.refreshFromStoreAsync {
                        self.selectedSurface = .swarm
                    }
                    self.sourcePluginStatusText = "Morning Briefing ready: \(page.title)"
                case .failure(let error):
                    self.errorText = error.localizedDescription
                    self.sourcePluginStatusText = "Morning Briefing needs attention."
                }
            }
        }
    }

    public func updateLearningSettings(_ settings: HiveLearningSettings) {
        let normalized = HiveLearningSettings(
            connectionAggression: settings.connectionAggression,
            sensitiveTopics: settings.sensitiveTopics,
            learnsFromBrowserCaptures: settings.learnsFromBrowserCaptures,
            learnsFromFiles: settings.learnsFromFiles,
            learnsFromCalendar: settings.learnsFromCalendar,
            rawSourceRetention: .fixedRawFileRetention
        )
        guard normalized != learningSettings else { return }
        learningSettings = normalized
        HiveLearningSettingsStore.save(normalized)
    }

    private func applyGraphSnapshot(_ nextGraph: HiveGraphSnapshot, animateChangeList: Bool = true) {
        let previousGraph = graph
        graph = nextGraph
        visibleGraphNodes = nextGraph.nodes.filter(\.isUserVisibleGraphNode)

        guard hasLoadedGraphSnapshot, animateChangeList else {
            hasLoadedGraphSnapshot = true
            graphAnimationList = .empty
            return
        }

        let list = GraphChangeAnimationList.make(previous: previousGraph, current: nextGraph)
        guard !list.isEmpty else {
            if !graphAnimationList.isActive(at: Date()) {
                graphAnimationList = .empty
            }
            return
        }

        graphAnimationList = list
        scheduleGraphAnimationListClear(id: list.id)
    }

    private func scheduleGraphAnimationListClear(id: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + GraphChangeAnimationList.playbackDuration + 0.35) { [weak self] in
            guard let self, self.graphAnimationList.id == id else { return }
            self.graphAnimationList = .empty
        }
    }

    public func reindexHive(plan: GraphReindexPlan = GraphReindexPlan(steps: [])) {
        guard requireAppleAuthentication() else { return }
        guard !plan.steps.isEmpty else {
            refreshKnowledge()
            return
        }
        let snapshot = graph
        isWorking = true
        DispatchQueue.global(qos: .userInitiated).async { [store] in
            let result = Result {
                let application = plan.applyingWithAudit(to: snapshot)
                try store.appendAudit(AuditEventRecord(
                    eventType: "graph.reindexed",
                    targetType: "graph",
                    targetID: "semanticAxes",
                    sourceRefs: [],
                    detail: "The Hive re-index placed \(plan.steps.count) graph movements, checked \(application.pairAuditPairCount) node pairs, and accepted \(application.acceptedPairAuditEdgeCount) generated connections. \(GraphSemanticAxes.semanticSummary)"
                ))
                return application.snapshot
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let nextGraph):
                    self.applyGraphSnapshot(nextGraph, animateChangeList: false)
                case .failure(let error):
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    public func requestHiveReindex() {
        guard requireAppleAuthentication() else { return }
        commandText = ""
        commandPaletteVisible = false
        chatVisible = false
        settingsVisible = false
        selectedSurface = .graph
        graphReindexRequestID = UUID()
    }

    public func ingest(urls: [URL]) {
        guard requireAppleAuthentication() else { return }
        guard !urls.isEmpty else { return }
        isWorking = true
        DispatchQueue.global(qos: .background).async { [ingestionEngine] in
            let result = Result {
                try ingestionEngine.ingest(urls: urls, processImmediately: false)
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success:
                    self.refreshFromStoreAsync {
                        self.scheduleSettledUploadProcessing()
                    }
                case .failure(let error):
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    public func ingestText(_ text: String) {
        guard requireAppleAuthentication() else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isWorking = true
        DispatchQueue.global(qos: .background).async { [paths, ingestionEngine, store] in
            let result = Result {
                try paths.createDirectories()
                let notesDirectory = paths.artifacts.appendingPathComponent("Feed Notes", isDirectory: true)
                try FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
                let now = Date()
                let title = Self.feedNoteTitle(for: trimmed)
                let nonce = UUID().uuidString.prefix(8)
                let fileURL = notesDirectory.appendingPathComponent("feed-\(Int(now.timeIntervalSince1970))-\(nonce).md")
                let markdown = "# \(title)\n\n\(trimmed)\n"
                try markdown.data(using: .utf8)?.write(to: fileURL, options: [.atomic])
                let records = try ingestionEngine.ingest(urls: [fileURL], processImmediately: false)
                for var record in records {
                    record.title = title
                    record.connector = "manual-feed"
                    record.uri = "local://feed/\(record.id)"
                    try store.saveSource(record)
                }
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success:
                    self.refreshFromStoreAsync {
                        self.scheduleSettledUploadProcessing()
                    }
                case .failure(let error):
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    public func configureStartupSourcePlugins(
        _ request: HiveStartupSourcePluginRequest,
        uploadedURLs: [URL] = [],
        browserHistoryURLs: [URL] = []
    ) {
        guard requireAppleAuthentication() else { return }
        let sanitized = HiveStartupSourcePluginCatalog.sanitizedRequest(request)
        HiveStartupSourcePluginCatalog.persist(sanitized)
        guard !sanitized.enabledSelections.isEmpty else {
            sourcePluginStatusText = "Choose at least one source."
            return
        }
        guard sanitized.canRunWithoutPicker || !uploadedURLs.isEmpty else {
            sourcePluginStatusText = "Paste a link or path, choose files, or enable browser history."
            return
        }

        isWorking = true
        sourcePluginStatusText = "Adding sources to Field..."
        DispatchQueue.global(qos: .background).async { [paths, ingestionEngine, store] in
            let result = Result {
                try HiveStartupSourcePluginBackend().execute(
                    request: sanitized,
                    uploadedURLs: uploadedURLs,
                    browserHistoryURLs: browserHistoryURLs,
                    paths: paths,
                    store: store,
                    ingestionEngine: ingestionEngine,
                    processImmediately: false
                )
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let execution):
                    self.refreshFromStoreAsync {
                        self.scheduleSettledUploadProcessing()
                        self.sourcePluginStatusText = execution.userMessage
                    }
                case .failure(let error):
                    self.errorText = error.localizedDescription
                    self.sourcePluginStatusText = "Source import failed."
                }
            }
        }
    }

    public func importBrowserHistory(from urls: [URL]) {
        guard requireAppleAuthentication() else { return }
        let request = HiveStartupSourcePluginRequest(
            selections: HiveStartupSourcePluginCatalog.orderedKinds.map {
                HiveStartupSourcePluginSelection(kind: $0, isEnabled: $0 == .browserHistory)
            },
            pasteLocation: "",
            prompt: ""
        )
        configureStartupSourcePlugins(request, browserHistoryURLs: urls)
    }

    private func scheduleSettledUploadProcessing() {
        sourcePluginStatusText = "Added to Field. Hive will read the batch after uploads settle."
        schedulePendingStagedSourceProcessingIfNeeded(forceReschedule: true)
    }

    private func schedulePendingStagedSourceProcessingIfNeeded(forceReschedule: Bool = false, now: Date = Date()) {
        let stagedSources = visibleSources.filter { $0.status == .queued }
        guard !stagedSources.isEmpty else {
            scheduledStagedProcessingDeadline = nil
            settledUploadProcessingTask?.cancel()
            settledUploadProcessingTask = nil
            return
        }
        guard !isWorking else { return }
        let newestStagedImport = stagedSources.map(\.importedAt).max() ?? now
        let deadline = newestStagedImport.addingTimeInterval(Self.uploadSettleDelaySeconds)
        if let scheduledStagedProcessingDeadline,
           abs(scheduledStagedProcessingDeadline.timeIntervalSince(deadline)) < 0.5,
           !forceReschedule {
            return
        }
        scheduledStagedProcessingDeadline = deadline
        settledUploadProcessingTask?.cancel()
        let delay = max(0, deadline.timeIntervalSince(now))
        settledUploadProcessingTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }
            await MainActor.run {
                self?.scheduledStagedProcessingDeadline = nil
                self?.processSettledUploadBatch()
            }
        }
    }

    private struct ProcessingSnapshot: Sendable {
        var sources: [SourceRecord]
        var claims: [ClaimRecord]
        var pages: [WikiPageRecord]
        var graph: HiveGraphSnapshot
    }

    nonisolated private static func processingSnapshot(store: HiveStore, graphEngine: GraphEngine = GraphEngine()) throws -> ProcessingSnapshot {
        let sources = try store.fetchSources()
        let claims = try store.fetchClaims()
        let entities = try store.fetchEntities()
        let relationships = try store.fetchRelationships()
        let graph = graphEngine.buildGraph(
            sources: sources,
            claims: claims,
            entities: entities,
            relationships: relationships
        )
        return ProcessingSnapshot(
            sources: sources,
            claims: claims,
            pages: try store.fetchWikiPages(),
            graph: graph
        )
    }

    nonisolated private static func processingSummary(
        sourceID: String?,
        sourceName: String,
        before: ProcessingSnapshot,
        after: ProcessingSnapshot
    ) -> ProcessingResultSummary {
        let beforeNodeIDs = Set(before.graph.nodes.map(\.id))
        let learned = after.graph.nodes
            .filter { !beforeNodeIDs.contains($0.id) }
            .prefix(16)
            .map { node in
                ProcessingResultSummary.LearnedNode(
                    id: node.id,
                    title: SourcePresentationModel.cleanTitle(node.title),
                    x: node.x / max(1, GraphSemanticAxes.horizontalNodeRange),
                    y: node.y / max(1, GraphSemanticAxes.verticalNodeRange)
                )
            }
        let beforeClaims = Set(before.claims.map(\.id))
        let beforePagesByID = Dictionary(uniqueKeysWithValues: before.pages.map { ($0.id, $0) })
        let colonyChanges = after.pages
            .filter(\.isUserVisibleArticle)
            .compactMap { page -> ProcessingResultSummary.ColonyChange? in
                let beforePage = beforePagesByID[page.id]
                let newClaimCount = page.claimRefs.filter { !beforeClaims.contains($0) }.count
                guard beforePage == nil || newClaimCount > 0 || beforePage?.revision != page.revision else { return nil }
                return ProcessingResultSummary.ColonyChange(
                    id: page.id,
                    title: SourcePresentationModel.cleanTitle(page.title),
                    newClaimCount: max(0, newClaimCount)
                )
            }
            .prefix(12)
        let skipped: [ProcessingResultSummary.SkippedFact]
        if learned.isEmpty && colonyChanges.isEmpty {
            skipped = [
                ProcessingResultSummary.SkippedFact(
                    text: "No durable new fact passed the extractor.",
                    reason: "Duplicate, generic, unsourced, or below the six-month usefulness threshold."
                )
            ]
        } else {
            skipped = [
                ProcessingResultSummary.SkippedFact(
                    text: "Low-signal document facts",
                    reason: "Generic document metadata, demographic noise, and duplicate claims were discarded."
                )
            ]
        }
        return ProcessingResultSummary(
            sourceID: sourceID,
            sourceName: sourceName,
            learned: Array(learned),
            colonyChanges: Array(colonyChanges),
            skipped: skipped
        )
    }

    public func processSettledUploadBatch() {
        guard requireAppleAuthentication() else { return }
        settledUploadProcessingTask?.cancel()
        settledUploadProcessingTask = nil
        scheduledStagedProcessingDeadline = nil
        isWorking = true
        sourcePluginStatusText = "Reading the settled Field batch..."
        DispatchQueue.global(qos: .background).async { [ingestionEngine, knowledgeLoop, store] in
            let result = Result {
                let before = try Self.processingSnapshot(store: store)
                try ingestionEngine.processPending(limit: 250)
                _ = try knowledgeLoop.updateDerivedKnowledge()
                let after = try Self.processingSnapshot(store: store)
                return Self.processingSummary(
                    sourceID: nil,
                    sourceName: "settled Field batch",
                    before: before,
                    after: after
                )
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let summary):
                    self.refreshFromStoreAsync {
                        self.processingResult = summary
                        self.sourcePluginStatusText = "Field batch added to memory."
                    }
                case .failure(let error):
                    self.errorText = error.localizedDescription
                    self.sourcePluginStatusText = "Batch processing needs attention."
                }
            }
        }
    }

    public func processSourceNow(sourceID: String) {
        guard requireAppleAuthentication() else { return }
        settledUploadProcessingTask?.cancel()
        settledUploadProcessingTask = nil
        scheduledStagedProcessingDeadline = nil
        guard let source = sources.first(where: { $0.id == sourceID }) else { return }
        isWorking = true
        sourcePluginStatusText = "Reading \(SourcePresentationModel.naturalTitle(for: source))..."
        DispatchQueue.global(qos: .background).async { [ingestionEngine, knowledgeLoop, store] in
            let result = Result {
                let before = try Self.processingSnapshot(store: store)
                try ingestionEngine.process(sourceID: sourceID)
                _ = try knowledgeLoop.updateDerivedKnowledge()
                let after = try Self.processingSnapshot(store: store)
                return Self.processingSummary(
                    sourceID: sourceID,
                    sourceName: SourcePresentationModel.naturalTitle(for: source),
                    before: before,
                    after: after
                )
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let summary):
                    self.refreshFromStoreAsync {
                        self.processingResult = summary
                        self.sourcePluginStatusText = "Source added to memory."
                    }
                case .failure(let error):
                    self.errorText = error.localizedDescription
                    self.sourcePluginStatusText = "Source processing needs attention."
                }
            }
        }
    }

    public func reprocessSource(sourceID: String) {
        runSourceExtraction(sourceID: sourceID, depth: .normal)
    }

    public func extractMoreFromSource(sourceID: String) {
        runSourceExtraction(sourceID: sourceID, depth: .expanded)
    }

    private func runSourceExtraction(sourceID: String, depth: SourceExtractionDepth) {
        guard requireAppleAuthentication() else { return }
        guard let source = sources.first(where: { $0.id == sourceID }) else { return }
        isWorking = true
        let sourceName = SourcePresentationModel.naturalTitle(for: source)
        let statusVerb = depth == .expanded ? "Extracting more from" : "Re-processing"
        sourcePluginStatusText = "\(statusVerb) \(sourceName)..."
        DispatchQueue.global(qos: .background).async { [ingestionEngine, knowledgeLoop, store] in
            let result = Result {
                let before = try Self.processingSnapshot(store: store)
                try ingestionEngine.reprocess(sourceID: sourceID, depth: depth)
                _ = try knowledgeLoop.updateDerivedKnowledge()
                let after = try Self.processingSnapshot(store: store)
                return Self.processingSummary(
                    sourceID: sourceID,
                    sourceName: sourceName,
                    before: before,
                    after: after
                )
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let summary):
                    self.refreshFromStoreAsync {
                        self.processingResult = summary
                        self.sourcePluginStatusText = depth == .expanded ? "Expanded extraction complete." : "Source re-processed."
                    }
                case .failure(let error):
                    self.errorText = error.localizedDescription
                    self.sourcePluginStatusText = depth == .expanded ? "Expanded extraction needs attention." : "Re-process needs attention."
                }
            }
        }
    }

    public func removeRawSource(sourceID: String) {
        if selectedSourceID == sourceID {
            selectedSourceID = nil
        }
        let store = store
        performKnowledgeMutation(statusText: "Removing source...") {
            guard let source = try store.fetchSource(id: sourceID) else { return }
            if source.status == .queued {
                try store.deleteStagedSource(id: sourceID)
            } else {
                try store.removeSourceAndFlagDerivedForReview(id: sourceID)
            }
        }
    }

    public func previewSource(sourceID: String) {
        guard requireAppleAuthentication() else { return }
        do {
            guard let source = try store.fetchSource(id: sourceID) else { return }
            let raw = try store.fetchRawBlobs().first { $0.sourceID == sourceID }
            let artifactText = try store.fetchArtifacts(sourceID: sourceID)
                .compactMap(\.inlineText)
                .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let rawText: String
            if let artifactText {
                rawText = artifactText
            } else if let raw, let text = try? String(contentsOf: URL(fileURLWithPath: raw.localPath), encoding: .utf8) {
                rawText = text
            } else {
                rawText = "Preview is not text-readable yet. Use Process now to extract local text or metadata."
            }
            sourcePreview = RawSourcePreview(
                id: source.id,
                title: SourcePresentationModel.naturalTitle(for: source),
                kindLabel: source.kind.rawValue,
                localPath: raw?.localPath,
                text: rawText
            )
        } catch {
            errorText = error.localizedDescription
        }
    }

    public func captureCurrentPage(command: String, followUpQuestion: String? = nil) {
        guard requireAppleAuthentication() else { return }
        #if os(macOS)
        isWorking = true
        liveStatusText = followUpQuestion == nil ? "Capturing screen context." : "Capturing screen context for Ask."
        DispatchQueue.global(qos: .userInitiated).async { [paths, ingestionEngine, store] in
            let result = Result {
                let capture = try PageScreenshotCapture().captureCurrentPage(command: command, paths: paths)
                var urls = [capture.markdownURL]
                if let imageURL = capture.imageURL {
                    urls.append(imageURL)
                }
                let records = try ingestionEngine.ingest(urls: urls, processImmediately: false)
                if Self.shouldFetchCurrentPageText(command: command, pageURL: capture.pageURL),
                   let pageURL = capture.pageURL {
                    let request = HiveStartupSourcePluginRequest(
                        selections: [
                            HiveStartupSourcePluginSelection(kind: .webPages, isEnabled: true)
                        ],
                        pasteLocation: pageURL.absoluteString,
                        prompt: command
                    )
                    try HiveStartupSourcePluginBackend().execute(
                        request: request,
                        paths: paths,
                        store: store,
                        ingestionEngine: ingestionEngine,
                        processImmediately: false
                    )
                }
                return records
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success:
                    self.refreshFromStoreAsync {
                        let trimmedQuestion = followUpQuestion?.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let trimmedQuestion, !trimmedQuestion.isEmpty {
                            self.chatVisible = true
                            self.chatText = trimmedQuestion
                            self.liveStatusText = "Captured screen context."
                            self.sendChat()
                        } else {
                            self.liveStatusText = "Captured screen context."
                        }
                        self.scheduleSettledUploadProcessing()
                    }
                case .failure(let error):
                    self.errorText = error.localizedDescription
                    self.liveStatusText = "Capture needs attention."
                }
            }
        }
        #endif
    }

    nonisolated private static func shouldFetchCurrentPageText(command: String, pageURL: URL?) -> Bool {
        guard pageURL != nil else { return false }
        let lower = command.lowercased()
        return lower.contains("rip")
            || lower.contains("webpage")
            || lower.contains("web page")
            || lower.contains("current page")
            || lower.contains("this page")
    }

    public func openLiveAssistant() {
        guard requireAppleAuthentication() else { return }
        commandText = ""
        commandPaletteVisible = false
        settingsVisible = false
        liveVisible = true
        liveStatusText = "Ready"
    }

    public func closeLiveAssistant() {
        liveVisible = false
        liveText = ""
        liveStatusText = "Ready"
    }

    public func submitLiveAssistantPrompt(_ rawPrompt: String? = nil) {
        guard requireAppleAuthentication() else { return }
        let prompt = HiveLiveAssistantRouter.normalizedPrompt(rawPrompt ?? liveText)
        guard let action = HiveLiveAssistantRouter.route(prompt) else {
            liveStatusText = "Ready"
            return
        }
        liveText = ""
        liveVisible = true
        liveStatusText = action.statusText

        switch action {
        case .captureCurrentPage(let command, let followUpQuestion):
            selectedSurface = .rawInputs
            shouldSpeakNextChatAnswer = followUpQuestion != nil
            captureCurrentPage(command: command, followUpQuestion: followUpQuestion)
        case .addInformation(let text):
            selectedSurface = .rawInputs
            ingestText(text)
        case .ask(let question):
            shouldSpeakNextChatAnswer = true
            ask(question)
        case .searchHive(let query):
            settingsVisible = false
            chatVisible = false
            selectedSurface = .graph
            graphSearchText = query
            graphSearchVisible = true
            liveStatusText = "Searching The Hive."
        case .reorganizeTopic(let topic):
            selectedSurface = .swarm
            ensureActiveSwarmThread()
            guard let threadID = activeSwarmThreadID else { return }
            appendSwarmMessage(threadID: threadID, speaker: .user, text: prompt)
            appendSwarmMessage(
                threadID: threadID,
                speaker: .swarm,
                text: "Reorganizing “\(topic)” across The Colony and The Hive.",
                note: "Swarm"
            )
            reorganizeKnowledgeAround(topic: topic, threadID: threadID, references: [])
        case .defineAutomation(let request):
            selectedSurface = .swarm
            ensureActiveSwarmThread()
            guard let threadID = activeSwarmThreadID else { return }
            appendSwarmMessage(threadID: threadID, speaker: .user, text: prompt)
            createAutomationFromSwarm(request, threadID: threadID, references: [])
        case .defineSkill(let request):
            selectedSurface = .swarm
            ensureActiveSwarmThread()
            guard let threadID = activeSwarmThreadID else { return }
            appendSwarmMessage(threadID: threadID, speaker: .user, text: prompt)
            createSkillFromSwarm(request, threadID: threadID, references: [])
        }
    }

    nonisolated private static func feedNoteTitle(for text: String) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Feed note"
        let cleaned = firstLine
            .trimmingCharacters(in: CharacterSet(charactersIn: "#*- ").union(.whitespacesAndNewlines))
        guard !cleaned.isEmpty else { return "Feed note" }
        return String(cleaned.prefix(72))
    }

    public func downloadAttachmentsForSelectedWikiPage() {
        guard requireAppleAuthentication() else { return }
        guard let page = selectedPage else { return }
        isWorking = true
        DispatchQueue.global(qos: .background).async { [store, paths] in
            let result = Result {
                let downloaded = try WikiAttachmentDownloader().downloadAttachments(
                    in: page.markdown,
                    assetsDirectory: paths.vaultRawAssets
                )
                guard downloaded.markdown != page.markdown else { return 0 }
                var updated = page
                updated.markdown = downloaded.markdown
                updated.updatedAt = Date()
                updated.revision += 1
                updated.frontmatter["attachment_folder"] = "flower-field/assets"
                updated.frontmatter["downloaded_attachment_count"] = String(downloaded.downloadedFiles.count)
                try store.saveWikiPage(updated)
                try store.appendAudit(AuditEventRecord(
                    eventType: "wiki.attachmentsDownloaded",
                    targetType: "wikiPage",
                    targetID: page.id,
                    sourceRefs: page.sourceRefs,
                    detail: "Saved \(downloaded.downloadedFiles.count) linked images locally so this article stays useful offline."
                ))
                _ = WikiVaultGitManager(vaultURL: paths.vault).commitIfNeeded(message: "Download wiki attachments")
                return downloaded.downloadedFiles.count
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success:
                    self.refreshFromStoreAsync()
                case .failure(let error):
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    public func createSlideDeckFromSelectedWikiPage() {
        guard requireAppleAuthentication() else { return }
        guard let page = selectedPage else { return }
        isWorking = true
        let related = HiveWikiToolbox(pages: wikiPages).relatedPages(pageID: page.id)
        let deckPages = [page] + Array(related.prefix(5))
        DispatchQueue.global(qos: .background).async { [store, paths] in
            let result = Result {
                let decksDirectory = paths.vaultWiki.appendingPathComponent("decks", isDirectory: true)
                let export = try WikiMarpDeckExporter().exportDeck(
                    title: page.title,
                    pages: deckPages,
                    destinationDirectory: decksDirectory
                )
                try store.saveWikiPage(export.page)
                try store.appendAudit(export.auditEvent)
                _ = WikiVaultGitManager(vaultURL: paths.vault).commitIfNeeded(message: "Create Colony slide deck")
                return export.page.id
            }
            DispatchQueue.main.async {
                self.isWorking = false
                switch result {
                case .success(let pageID):
                    self.refreshFromStoreAsync {
                        self.selectedPageID = pageID
                        self.selectedSurface = .wiki
                    }
                case .failure(let error):
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    public func applyClaimAction(_ action: FeedbackAction, claimID: String) {
        let controlPlane = controlPlane
        performKnowledgeMutation {
            try controlPlane.applyFeedback(FeedbackRecord(targetType: "claim", targetID: claimID, action: action))
        }
    }

    public func applyGraphNodeAction(_ action: FeedbackAction, nodeID: String) {
        let controlPlane = controlPlane
        performKnowledgeMutation {
            try controlPlane.applyFeedback(FeedbackRecord(
                targetType: "graphNode",
                targetID: nodeID,
                action: action,
                note: "Applied from graph preview."
            ))
        }
    }

    public func confirmGraphPlacement(nodeID: String, x: Double, y: Double) {
        guard requireAppleAuthentication() else { return }
        let clampedX = min(1, max(-1, x))
        let clampedY = min(1, max(-1, y))
        var next = graph
        if let index = next.nodes.firstIndex(where: { $0.id == nodeID }) {
            next.nodes[index].x = clampedX * GraphSemanticAxes.horizontalNodeRange
            next.nodes[index].y = clampedY * GraphSemanticAxes.verticalNodeRange
            next.nodes[index].confidence = max(next.nodes[index].confidence, 0.72)
            applyGraphSnapshot(next)
        }
        let store = store
        DispatchQueue.global(qos: .utility).async {
            let result = Result {
                try store.saveFeedback(FeedbackRecord(
                    targetType: "graphPlacement",
                    targetID: nodeID,
                    action: .edit,
                    note: String(format: "axis_x=%.4f axis_y=%.4f", clampedX, clampedY)
                ))
            }
            if case .failure(let error) = result {
                DispatchQueue.main.async {
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    public func forget(sourceID: String) {
        selectedSourceID = nil
        let controlPlane = controlPlane
        performKnowledgeMutation(statusText: "Forgetting source...") {
            try controlPlane.fullForgetSource(id: sourceID)
        }
    }

    public func archive(sourceID: String) {
        selectedSourceID = nil
        let store = store
        performKnowledgeMutation(statusText: "Archiving source...") {
            guard var source = try store.fetchSource(id: sourceID) else { return }
            source.deletionState = .archived
            try store.saveSource(source)
            try store.appendAudit(AuditEventRecord(
                eventType: "source.archived",
                targetType: "source",
                targetID: sourceID,
                sourceRefs: [sourceID],
                detail: "Source archived from the active intake surface."
            ))
        }
    }

    public func saveWiki(pageID: String, markdown: String) {
        let store = store
        performKnowledgeMutationReturning(statusText: "Saving Colony changes...") {
            guard let page = try store.fetchWikiPages().first(where: { $0.id == pageID }) else { return nil as String? }
            let compilation = UserWikiEditPolicy().compile(
                page: page,
                editedMarkdown: markdown,
                existingClaims: try store.fetchClaims(),
                existingFeedback: try store.fetchFeedback()
            )
            for claim in compilation.claimsToSave {
                try store.saveClaim(claim)
            }
            for feedback in compilation.feedbackToSave {
                try store.saveFeedback(feedback)
            }
            try store.saveWikiPage(compilation.page)
            for event in compilation.auditEvents {
                try store.appendAudit(event)
            }
            return compilation.page.id
        } onSuccess: { savedPageID in
            if let savedPageID {
                self.selectedPageID = savedPageID
            }
        }
    }

    public func consolidateWikiArticles(pageIDs: [String]) {
        let store = store
        let paths = paths
        let primaryPageID = selectedPageID
        performKnowledgeMutationReturning(statusText: "Merging Colony pages...") {
            let pages = try store.fetchWikiPages()
            guard let result = WikiArticleConsolidator().consolidate(
                pages: pages,
                selectedPageIDs: pageIDs,
                primaryPageID: primaryPageID
            ) else { return primaryPageID as String? }
            try store.saveWikiPage(result.page)
            let vault = WikiVaultManager(paths: paths)
            for page in pages where result.removedPageIDs.contains(page.id) {
                try vault.removePageFile(page)
                try store.saveFeedback(FeedbackRecord(
                    targetType: "wikiPage",
                    targetID: page.id,
                    action: .delete,
                    note: "Merged into \(result.page.title)."
                ))
            }
            try store.deleteWikiPages(ids: Set(result.removedPageIDs))
            try store.appendAudit(result.auditEvent)
            return result.page.id
        } onSuccess: { mergedPageID in
            if let mergedPageID {
                self.selectedPageID = mergedPageID
            }
        }
    }

    public func deleteWikiArticles(pageIDs: [String]) {
        let store = store
        let paths = paths
        let currentSelectedPageID = selectedPageID
        performKnowledgeMutationReturning(statusText: "Deleting Colony pages...") {
            let requestedIDs = Set(pageIDs)
            guard !requestedIDs.isEmpty else { return false }
            let pages = try store.fetchWikiPages().filter { requestedIDs.contains($0.id) && $0.isUserVisibleArticle }
            guard !pages.isEmpty else { return false }
            let deletedIDs = Set(pages.map(\.id))
            let vault = WikiVaultManager(paths: paths)
            for page in pages {
                try vault.removePageFile(page)
                try store.saveFeedback(FeedbackRecord(
                    targetType: "wikiPage",
                    targetID: page.id,
                    action: .delete,
                    note: "Deleted from The Colony by user."
                ))
            }
            try store.deleteWikiPages(ids: deletedIDs)
            try store.appendAudit(AuditEventRecord(
                eventType: pages.count == 1 ? "wiki.articleDeleted" : "wiki.articlesDeleted",
                targetType: "wikiPage",
                targetID: pages.count == 1 ? pages[0].id : "selected-pages",
                actor: "user",
                sourceRefs: Array(Set(pages.flatMap(\.sourceRefs))).sorted(),
                detail: "Deleted \(pages.count) selected Colony article page\(pages.count == 1 ? "" : "s"). Field sources were not deleted."
            ))
            return currentSelectedPageID.map { deletedIDs.contains($0) } ?? false
        } onSuccess: { didDeleteSelectedPage in
            if didDeleteSelectedPage {
                self.selectedPageID = nil
            }
        }
    }

    public func sendChat() {
        guard requireAppleAuthentication() else { return }
        let query = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        chatEntries.append(HiveChatEntry(speaker: .user, text: query))
        chatText = ""
        if shouldAddChatInputToMemory(query) {
            chatEntries.append(HiveChatEntry(
                speaker: .hive,
                text: "Added. Hive is updating The Colony and The Hive from this note.",
                citations: [],
                note: "Field"
            ))
            ingestText(query)
            return
        }
        let review = ReviewQueueBuilder().build(claims: claims, sources: sources, feedback: (try? store.fetchFeedback()) ?? [])
        let visibility = currentVisibility()
        let localAnswer = chatAnswerEngine.answer(
            query: query,
            sources: sources,
            claims: claims,
            wikiPages: wikiPages,
            reviewQueue: review,
            modelAvailability: ChatAnswerEngine.modelAvailability(modelsDirectory: paths.models),
            visibility: visibility
        )
        let cloudSettings = CloudInferenceSettingsStore.load()
        if cloudSettings.isConfigured {
            let sharingMode = cloudSettings.requiresPreSendReview ? OnlineAskContextSharingMode.questionOnly : .localContextAllowed
            let relevantChunks = sharingMode == .localContextAllowed
                ? onlineAskContextChunks(query: query, localAnswer: localAnswer)
                : []
            let pendingID = UUID()
            chatEntries.append(HiveChatEntry(
                id: pendingID,
                speaker: .hive,
                text: sharingMode == .questionOnly
                    ? "Checking outside sources without sharing Colony context."
                    : "Checking The Colony and outside sources with your online helper.",
                citations: sharingMode == .localContextAllowed ? localAnswer.citations.map { SourcePresentationModel(source: $0) } : [],
                note: cloudSettings.normalizedProviderName
            ))
            isWorking = true
            Task {
                let answer = await CloudChatAnswerEngine().answer(
                    query: query,
                    localAnswer: localAnswer,
                    sources: sources,
                    chunks: relevantChunks,
                    claims: claims,
                    wikiPages: wikiPages,
                    visibility: visibility,
                    settings: cloudSettings,
                    sharingMode: sharingMode
                )
                lastAnswerForFiling = (query: query, answer: answer)
                let entry = HiveChatEntry(
                    id: pendingID,
                    speaker: .hive,
                    text: sanitizeAssistantAnswer(answer.answer),
                    citations: answer.citations.map { SourcePresentationModel(source: $0) },
                    note: answer.uncertainty
                )
                if let index = chatEntries.firstIndex(where: { $0.id == pendingID }) {
                    chatEntries[index] = entry
                } else {
                    chatEntries.append(entry)
                }
                publishLiveSpokenAnswer(entry.text)
                isWorking = false
            }
            return
        }
        if FoundationModelChatRuntime.currentAvailability() == .available {
            let pendingID = UUID()
            chatEntries.append(HiveChatEntry(
                id: pendingID,
                speaker: .hive,
                text: "Synthesizing from The Colony on this Mac.",
                citations: localAnswer.citations.map { SourcePresentationModel(source: $0) },
                note: "Local AI"
            ))
            isWorking = true
            Task {
                let result = await foundationOrchestrator.answerChat(
                    query: query,
                    localAnswer: localAnswer,
                    claims: claims,
                    wikiPages: wikiPages,
                    visibility: visibility
                )
                let answer = result.proposal.citedAnswer(fallback: localAnswer, fallbackReason: result.fallbackReason)
                lastAnswerForFiling = (query: query, answer: answer)
                let entry = HiveChatEntry(
                    id: pendingID,
                    speaker: .hive,
                    text: sanitizeAssistantAnswer(answer.answer),
                    citations: answer.citations.map { SourcePresentationModel(source: $0) },
                    note: answer.uncertainty
                )
                if let index = chatEntries.firstIndex(where: { $0.id == pendingID }) {
                    chatEntries[index] = entry
                } else {
                    chatEntries.append(entry)
                }
                publishLiveSpokenAnswer(entry.text)
                isWorking = false
            }
            return
        }
        appendChatAnswer(query: query, answer: localAnswer)
    }

    private func onlineAskContextChunks(query: String, localAnswer: CitedAnswer) -> [ChunkRecord] {
        var chunksByID: [String: ChunkRecord] = [:]
        for source in localAnswer.citations.prefix(4) {
            let sourceChunks = (try? store.fetchChunks(sourceID: source.id)) ?? []
            for chunk in sourceChunks.prefix(4) {
                chunksByID[chunk.id] = chunk
            }
        }
        let queryChunks = (try? store.searchChunks(safeFTSQuery(from: query), limit: 8)) ?? []
        for chunk in queryChunks {
            chunksByID[chunk.id] = chunk
        }
        return Array(chunksByID.values).sorted {
            if $0.extractionConfidence != $1.extractionConfidence {
                return $0.extractionConfidence > $1.extractionConfidence
            }
            return $0.id < $1.id
        }
    }

    private func safeFTSQuery(from query: String) -> String {
        let stopwords: Set<String> = ["about", "after", "and", "are", "for", "from", "how", "should", "that", "the", "this", "what", "when", "where", "with", "your"]
        let terms = query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) }
            .prefix(6)
        return terms.isEmpty ? query : terms.joined(separator: " OR ")
    }

    private func appendChatAnswer(query: String, answer: CitedAnswer) {
        let safeAnswer = sanitizeAssistantAnswer(answer.answer)
        lastAnswerForFiling = (query: query, answer: answer)
        chatEntries.append(HiveChatEntry(
            speaker: .hive,
            text: safeAnswer,
            citations: answer.citations.map { SourcePresentationModel(source: $0) },
            note: answer.uncertainty
        ))
        publishLiveSpokenAnswer(safeAnswer)
    }

    private func publishLiveSpokenAnswer(_ answer: String) {
        guard shouldSpeakNextChatAnswer else { return }
        shouldSpeakNextChatAnswer = false
        let cleaned = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        liveStatusText = "Answered"
        liveSpokenText = cleaned
        liveSpokenSequence += 1
    }

    public func ask(_ question: String) {
        guard requireAppleAuthentication() else { return }
        chatText = question
        chatVisible = true
        sendChat()
    }

    private func shouldAddChatInputToMemory(_ query: String) -> Bool {
        let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.contains("?") else { return false }
        let feedPrefixes = [
            "remember ",
            "note:",
            "note ",
            "add this",
            "add to hive",
            "save this",
            "i am ",
            "i'm ",
            "im ",
            "i have ",
            "i want ",
            "i need ",
            "my ",
            "for me,"
        ]
        return feedPrefixes.contains { lower.hasPrefix($0) }
    }

    public func fileLastChatAnswerToWiki() {
        guard requireAppleAuthentication() else { return }
        guard let lastAnswerForFiling else { return }
        do {
            let result = wikiOperationEngine.archiveAnswerPage(
                query: lastAnswerForFiling.query,
                answer: lastAnswerForFiling.answer,
                relatedPages: wikiPages,
                previousPages: try store.fetchWikiPages()
            )
            try store.saveWikiPage(result.page)
            try store.appendAudit(result.auditEvent)
            _ = WikiVaultGitManager(vaultURL: paths.vault).commitIfNeeded(message: "File Hive answer")
            selectedPageID = result.page.id
            selectedSurface = .wiki
            refreshKnowledge()
        } catch {
            errorText = error.localizedDescription
        }
    }

    public func commandAvailability(for command: HiveCommand) -> HiveCommandAvailability {
        let shortcut = HiveCommandShortcutStore.shortcut(for: command)
        guard isAppleAuthenticated else {
            return HiveCommandAvailability(
                isEnabled: false,
                reason: "Sign in to Hive before using Hive.",
                shortcut: shortcut
            )
        }
        switch command {
        case .addSources, .live, .chat, .wiki, .graph, .rawSources, .settings:
            return HiveCommandAvailability(isEnabled: true, shortcut: shortcut)
        case .findMemory:
            return HiveCommandAvailability(
                isEnabled: !visibleGraphNodes.isEmpty,
                reason: visibleGraphNodes.isEmpty ? "Add Field items first so Hive has memories to search." : nil,
                shortcut: shortcut
            )
        case .reviewMemory:
            return HiveCommandAvailability(
                isEnabled: !isWorking,
                reason: isWorking ? "Hive is already reviewing Field." : nil,
                shortcut: shortcut
            )
        case .fileAnswer:
            return HiveCommandAvailability(
                isEnabled: lastAnswerForFiling != nil,
                reason: lastAnswerForFiling == nil ? "Ask Hive first, then save the answer if it is useful." : nil,
                shortcut: shortcut
            )
        case .downloadAttachments:
            return HiveCommandAvailability(
                isEnabled: selectedSurface == .wiki && selectedPage != nil,
                reason: selectedSurface == .wiki && selectedPage != nil ? nil : "Open a Colony article before saving its images.",
                shortcut: shortcut
            )
        case .createSlideDeck:
            return HiveCommandAvailability(
                isEnabled: selectedSurface == .wiki && selectedPage != nil,
                reason: selectedSurface == .wiki && selectedPage != nil ? nil : "Open a Colony article before creating a deck.",
                shortcut: shortcut
            )
        }
    }

    public func executeCommand(_ command: HiveCommand) {
        guard requireAppleAuthentication() else { return }
        guard commandAvailability(for: command).isEnabled else { return }
        commandText = ""
        commandPaletteVisible = false
        switch command {
        case .addSources:
            settingsVisible = false
            chatVisible = false
            selectedSurface = .rawInputs
        case .live:
            openLiveAssistant()
        case .rawSources:
            settingsVisible = false
            chatVisible = false
            selectedSurface = .rawInputs
        case .wiki:
            settingsVisible = false
            chatVisible = false
            selectedSurface = .wiki
        case .graph:
            settingsVisible = false
            chatVisible = false
            selectedSurface = .graph
        case .findMemory:
            settingsVisible = false
            chatVisible = false
            selectedSurface = .graph
            graphSearchVisible = true
        case .reviewMemory:
            refreshKnowledge()
        case .chat:
            settingsVisible = false
            chatVisible = true
        case .fileAnswer:
            fileLastChatAnswerToWiki()
        case .downloadAttachments:
            downloadAttachmentsForSelectedWikiPage()
        case .createSlideDeck:
            createSlideDeckFromSelectedWikiPage()
        case .settings:
            chatVisible = false
            settingsVisible = true
        }
    }

    public func openWiki(forGraphNodeID nodeID: String) {
        let node = graph.nodes.first { $0.id == nodeID }
        let nodeTitle = node.map { SourcePresentationModel.cleanTitle($0.title) } ?? ""
        let nodeSlug = WikiPageRecord.slugify(nodeTitle.isEmpty ? nodeID : nodeTitle)
        let candidates = [
            nodeID,
            "entity-\(nodeID)",
            "claim-\(nodeID)"
        ]
        if let page = wikiPages.first(where: { page in
            guard page.isUserVisibleArticle else { return false }
            return candidates.contains(page.id)
                || page.claimRefs.contains(nodeID)
                || page.slug == nodeSlug
                || SourcePresentationModel.cleanTitle(page.title).caseInsensitiveCompare(nodeTitle) == .orderedSame
        }) {
            selectedPageID = page.id
        } else {
            selectedPageID = selectedPage?.id
        }
        selectedSurface = .wiki
    }

    public func openGraph(pageID: String?, title: String?, claimID: String?) {
        let visibleNodes = graph.nodes.filter(\.isUserVisibleGraphNode)
        let visibleIDs = Set(visibleNodes.map(\.id))
        var targetID: String?

        if let claimID, visibleIDs.contains(claimID) {
            targetID = claimID
        }

        if targetID == nil, let claimID, let claim = claims.first(where: { $0.id == claimID }) {
            if let subjectEntityID = claim.subjectEntityID, visibleIDs.contains(subjectEntityID) {
                targetID = subjectEntityID
            } else {
                let statement = SourcePresentationModel.cleanTitle(claim.statement)
                targetID = visibleNodes.first { node in
                    SourcePresentationModel.cleanTitle(node.title).caseInsensitiveCompare(statement) == .orderedSame
                }?.id
            }
        }

        if targetID == nil, let pageID {
            if visibleIDs.contains(pageID) {
                targetID = pageID
            } else if pageID.hasPrefix("entity-") {
                let entityID = String(pageID.dropFirst("entity-".count))
                if visibleIDs.contains(entityID) {
                    targetID = entityID
                }
            } else if pageID.hasPrefix("claim-") {
                let localClaimID = String(pageID.dropFirst("claim-".count))
                if visibleIDs.contains(localClaimID) {
                    targetID = localClaimID
                }
            }

            if targetID == nil, let page = wikiPages.first(where: { $0.id == pageID }) {
                targetID = page.claimRefs.first(where: { visibleIDs.contains($0) })
                if targetID == nil {
                    targetID = matchGraphNode(title: page.title, in: visibleNodes)
                }
            }
        }

        if targetID == nil, let title {
            targetID = matchGraphNode(title: title, in: visibleNodes)
        }

        selectedNodeID = targetID ?? visibleNodes.first?.id
        graphSearchText = ""
        graphSearchVisible = false
        selectedSurface = .graph
    }

    private func matchGraphNode(title: String, in nodes: [GraphNodeRecord]) -> String? {
        let cleaned = SourcePresentationModel.cleanTitle(title)
        let slug = WikiPageRecord.slugify(cleaned)
        return nodes.first { node in
            let nodeTitle = SourcePresentationModel.cleanTitle(node.title)
            return nodeTitle.caseInsensitiveCompare(cleaned) == .orderedSame
                || WikiPageRecord.slugify(nodeTitle) == slug
        }?.id
    }

    private func sanitizeAssistantAnswer(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\([0-9]+% confidence; ([^)]+)\)"#, with: "($1)", options: .regularExpression)
            .replacingOccurrences(of: "confidence", with: "certainty", options: [.caseInsensitive])
    }

    private func currentVisibility() -> DerivedMemoryVisibility {
        cachedVisibility
    }

    private func buildSourcePresentations(visibility: DerivedMemoryVisibility) -> [SourcePresentationModel] {
        let activeSources = visibleSources
        let visibleSourceIDs = RawInputSemanticClusterer.defaultVisibleSourceIDs(
            sources: activeSources,
            claims: claims,
            visibility: visibility
        )
        return activeSources
            .filter { visibleSourceIDs.contains($0.id) }
            .map(sourcePresentation(for:))
            .filter(\.isDefaultVisibleRawInput)
    }

    private func buildAllSourcePresentations() -> [SourcePresentationModel] {
        visibleSources.map(sourcePresentation(for:))
    }

    private func sourcePresentation(for source: SourceRecord) -> SourcePresentationModel {
        Self.sourcePresentation(for: source, store: store)
    }

    nonisolated private static func sourcePresentation(for source: SourceRecord, store: HiveStore) -> SourcePresentationModel {
        let raw = (try? store.fetchRawBlobs(sourceID: source.id))?.first
        let text = (try? store.fetchArtifacts(sourceID: source.id))?
            .first { ($0.inlineText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }?
            .inlineText
        return SourcePresentationModel(source: source, rawBlob: raw, artifactPreviewText: text)
    }
}

public enum HiveCommand: String, CaseIterable, Identifiable, Sendable {
    case addSources = "Add to Field…"
    case live = "Hive Live"
    case chat = "Ask Hive"
    case findMemory = "Find in The Hive…"
    case wiki = "Open The Colony"
    case graph = "Open The Hive"
    case rawSources = "Open Field"
    case reviewMemory = "Review Field"
    case fileAnswer = "Save Last Answer"
    case downloadAttachments = "Save Article Images Offline"
    case createSlideDeck = "Create Slide Deck"
    case settings = "Open Settings…"

    public var id: String {
        switch self {
        case .addSources:
            return "addSources"
        case .live:
            return "live"
        case .chat:
            return "chat"
        case .findMemory:
            return "findMemory"
        case .wiki:
            return "wiki"
        case .graph:
            return "graph"
        case .rawSources:
            return "rawSources"
        case .reviewMemory:
            return "reviewMemory"
        case .fileAnswer:
            return "fileAnswer"
        case .downloadAttachments:
            return "downloadAttachments"
        case .createSlideDeck:
            return "createSlideDeck"
        case .settings:
            return "settings"
        }
    }

    public var description: String {
        switch self {
        case .addSources:
            return "Choose files, folders, screenshots, or notes for Field."
        case .live:
            return "Speak or type a request, capture the current screen, or add a note."
        case .chat:
            return "Ask a question using The Colony and The Hive."
        case .findMemory:
            return "Search The Hive for a person, project, goal, or idea."
        case .wiki:
            return "Open the organized articles Hive maintains in The Colony."
        case .graph:
            return "See how your important memories connect in The Hive."
        case .rawSources:
            return "Check the original material Hive keeps in Field."
        case .reviewMemory:
            return "Ask Hive to consolidate new Field items into The Colony and The Hive."
        case .fileAnswer:
            return "Keep the latest useful answer in The Colony."
        case .downloadAttachments:
            return "Keep images from the current article available locally."
        case .createSlideDeck:
            return "Create a slide deck from the current Colony article and related pages."
        case .settings:
            return "Change learning, privacy, menu bar, and appearance options."
        }
    }

    public var preview: String {
        switch self {
        case .addSources:
            return "Opens the Field picker. Add a document, folder, screenshot, or loose note; Hive keeps the original and learns from the useful parts."
        case .live:
            return "Opens a compact voice surface. Use it to ask, remember, search The Hive, or capture the current page into Field."
        case .chat:
            return "Opens the Ask sheet. Answers come from The Colony first, with local memory as the fallback."
        case .findMemory:
            return "Opens The Hive search so you can locate a specific memory, hover for context, and jump into its Colony article."
        case .wiki:
            return "Opens The Colony: organized articles, consolidated pages, and correction guidance that helps Hive rewrite mistakes."
        case .graph:
            return "Opens The Hive: the wordless map of useful memories. Hover to identify a cell, click to inspect, and follow connections."
        case .rawSources:
            return "Opens Field. Raw material stays here so The Colony and The Hive can stay clean."
        case .reviewMemory:
            return "Runs a local pass that folds weak fragments into stronger articles before creating anything new."
        case .fileAnswer:
            return "Turns the last useful answer into a maintained Colony article so the conversation does not disappear."
        case .downloadAttachments:
            return "Saves images referenced by the selected article so The Colony stays useful offline."
        case .createSlideDeck:
            return "Creates a presentation from the selected Colony article and its strongest related pages."
        case .settings:
            return "Opens the settings panel for learning rules, privacy, the menu bar, appearance, shortcuts, and local files."
        }
    }

    public var scope: String {
        switch self {
        case .addSources:
            return "ADD"
        case .live:
            return "LIVE"
        case .chat, .fileAnswer:
            return "ASK"
        case .findMemory:
            return "FIND"
        case .wiki:
            return "READ"
        case .graph:
            return "MAP"
        case .rawSources:
            return "SOURCES"
        case .reviewMemory:
            return "MAINTAIN"
        case .downloadAttachments:
            return "OFFLINE"
        case .createSlideDeck:
            return "CREATE"
        case .settings:
            return "SETTINGS"
        }
    }

    public var symbolName: HiveSymbolName {
        switch self {
        case .addSources:
            return .importAction
        case .live:
            return .liveAssistant
        case .chat:
            return .chat
        case .findMemory:
            return .search
        case .wiki:
            return .wiki
        case .graph:
            return .hiveGraph
        case .rawSources:
            return .rawInputs
        case .reviewMemory:
            return .synthesizing
        case .fileAnswer:
            return .quickCapture
        case .downloadAttachments:
            return .download
        case .createSlideDeck:
            return .presentation
        case .settings:
            return .settings
        }
    }

    public var defaultShortcut: String {
        switch self {
        case .addSources:
            return "Command O"
        case .live:
            return "Option Shift Command H"
        case .chat:
            return "Option Command A"
        case .findMemory:
            return "Command F"
        case .wiki:
            return "Command 2"
        case .graph:
            return "Command 3"
        case .rawSources:
            return "Command 1"
        case .reviewMemory:
            return "Shift Command R"
        case .fileAnswer:
            return "Option Command L"
        case .downloadAttachments:
            return "Shift Command D"
        case .createSlideDeck:
            return "Option Command P"
        case .settings:
            return "Command Comma"
        }
    }

    public var shortcutStorageKey: String {
        "hive.commandShortcut.\(id.replacingOccurrences(of: " ", with: "."))"
    }
}

public struct HiveCommandAvailability: Sendable, Equatable {
    public var isEnabled: Bool
    public var reason: String?
    public var shortcut: String

    public init(isEnabled: Bool, reason: String? = nil, shortcut: String) {
        self.isEnabled = isEnabled
        self.reason = reason
        self.shortcut = shortcut
    }

    public static func enabled(for command: HiveCommand) -> HiveCommandAvailability {
        HiveCommandAvailability(isEnabled: true, shortcut: HiveCommandShortcutStore.shortcut(for: command))
    }
}

public enum HiveShortcutModifier: String, CaseIterable, Codable, Hashable, Sendable {
    case command
    case option
    case shift
    case control

    public static let appleDisplayOrder: [HiveShortcutModifier] = [.control, .option, .shift, .command]

    public var title: String {
        switch self {
        case .command:
            return "Command"
        case .option:
            return "Option"
        case .shift:
            return "Shift"
        case .control:
            return "Control"
        }
    }

    public var symbolName: HiveSymbolName {
        switch self {
        case .command:
            return .command
        case .option:
            return .shortcutOption
        case .shift:
            return .shortcutShift
        case .control:
            return .shortcutControl
        }
    }

    fileprivate var storageName: String {
        switch self {
        case .command:
            return "Command"
        case .option:
            return "Option"
        case .shift:
            return "Shift"
        case .control:
            return "Control"
        }
    }

    fileprivate var searchTerms: [String] {
        switch self {
        case .command:
            return ["command", "cmd", "⌘"]
        case .option:
            return ["option", "alt", "⌥"]
        case .shift:
            return ["shift", "⇧"]
        case .control:
            return ["control", "ctrl", "⌃"]
        }
    }
}

public struct HiveKeyboardShortcut: Codable, Hashable, Sendable {
    public var modifiers: Set<HiveShortcutModifier>
    public var key: String

    public init(modifiers: Set<HiveShortcutModifier>, key: String) {
        self.modifiers = modifiers
        self.key = Self.normalizedKey(key)
    }

    public var isComplete: Bool {
        !modifiers.isEmpty && !key.isEmpty
    }

    public var storageValue: String {
        let modifierText = HiveShortcutModifier.appleDisplayOrder
            .filter { modifiers.contains($0) }
            .map(\.storageName)
        return (modifierText + [key]).joined(separator: " ")
    }

    public var accessibilityLabel: String {
        let modifierText = HiveShortcutModifier.appleDisplayOrder
            .filter { modifiers.contains($0) }
            .map(\.title)
        return (modifierText + [key]).joined(separator: " ")
    }

    public static func parse(_ value: String) -> HiveKeyboardShortcut? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        var modifiers = Set<HiveShortcutModifier>()
        var consumed = Set<String>()
        for modifier in HiveShortcutModifier.allCases {
            if modifier.searchTerms.contains(where: { lower.contains($0) }) {
                modifiers.insert(modifier)
                consumed.formUnion(modifier.searchTerms)
            }
        }

        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "+-"))
        let tokens = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        let key = tokens
            .last { !consumed.contains($0.lowercased()) }
            .map(Self.normalizedKey)

        guard let key, !key.isEmpty, !modifiers.isEmpty else { return nil }
        return HiveKeyboardShortcut(modifiers: modifiers, key: key)
    }

    public static func normalizedKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case ",":
            return "Comma"
        case " ":
            return "Space"
        case "esc":
            return "Escape"
        case "enter":
            return "Return"
        default:
            if trimmed.count == 1 {
                return trimmed.uppercased()
            }
            return String(trimmed.prefix(1)).uppercased() + String(trimmed.dropFirst())
        }
    }
}

public enum HiveCommandShortcutStore {
    public static func shortcut(for command: HiveCommand, defaults: UserDefaults = .standard) -> String {
        let stored = defaults.string(forKey: command.shortcutStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let stored,
              let shortcut = HiveKeyboardShortcut.parse(stored),
              shortcut.isComplete else {
            return command.defaultShortcut
        }
        return shortcut.storageValue
    }

    public static func setShortcut(_ value: String, for command: HiveCommand, defaults: UserDefaults = .standard) {
        guard let shortcut = HiveKeyboardShortcut.parse(value), shortcut.isComplete else {
            defaults.removeObject(forKey: command.shortcutStorageKey)
            return
        }
        let cleaned = shortcut.storageValue
        if cleaned == command.defaultShortcut {
            defaults.removeObject(forKey: command.shortcutStorageKey)
        } else {
            defaults.set(cleaned, forKey: command.shortcutStorageKey)
        }
    }

    public static func resetShortcut(for command: HiveCommand, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: command.shortcutStorageKey)
    }
}
