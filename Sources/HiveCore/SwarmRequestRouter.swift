import Foundation

public enum SwarmRequestIntent: String, Codable, Hashable, Sendable {
    case answerDirectly
    case answerFromContext
    case lookOnline
    case incorporateInformation
}

public struct SwarmRequestRoutingInput: Codable, Hashable, Sendable {
    public var prompt: String
    public var hasAttachments: Bool
    public var hasExplicitReferences: Bool
    public var colonyChunkCount: Int
    public var webPluginEnabled: Bool

    public init(
        prompt: String,
        hasAttachments: Bool = false,
        hasExplicitReferences: Bool = false,
        colonyChunkCount: Int = 0,
        webPluginEnabled: Bool = false
    ) {
        self.prompt = prompt
        self.hasAttachments = hasAttachments
        self.hasExplicitReferences = hasExplicitReferences
        self.colonyChunkCount = colonyChunkCount
        self.webPluginEnabled = webPluginEnabled
    }
}

public struct SwarmRequestDecision: Codable, Hashable, Sendable {
    public var intent: SwarmRequestIntent
    public var reason: String
    public var shouldUseColonyContext: Bool
    public var shouldUseOnlineSource: Bool
    public var shouldWriteToMemory: Bool
    public var shouldAskForApprovedURL: Bool

    public init(
        intent: SwarmRequestIntent,
        reason: String,
        shouldUseColonyContext: Bool,
        shouldUseOnlineSource: Bool,
        shouldWriteToMemory: Bool,
        shouldAskForApprovedURL: Bool
    ) {
        self.intent = intent
        self.reason = reason
        self.shouldUseColonyContext = shouldUseColonyContext
        self.shouldUseOnlineSource = shouldUseOnlineSource
        self.shouldWriteToMemory = shouldWriteToMemory
        self.shouldAskForApprovedURL = shouldAskForApprovedURL
    }
}

public struct SwarmRequestRouter: Sendable {
    public init() {}

    public func decide(_ input: SwarmRequestRoutingInput) -> SwarmRequestDecision {
        let prompt = input.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = prompt.lowercased()
        let looksLikeQuestion = Self.looksLikeQuestion(lower)
        let hasContext = input.hasAttachments || input.hasExplicitReferences || input.colonyChunkCount > 0
        let hasURL = Self.containsApprovedURL(lower)

        if input.webPluginEnabled && (hasURL || Self.containsAny(lower, terms: Self.onlineTerms)) {
            return SwarmRequestDecision(
                intent: .lookOnline,
                reason: hasURL ? "The prompt includes an approved web link." : "The prompt asks for current or outside information.",
                shouldUseColonyContext: hasContext || input.colonyChunkCount > 0,
                shouldUseOnlineSource: true,
                shouldWriteToMemory: false,
                shouldAskForApprovedURL: !hasURL
            )
        }

        if input.hasAttachments && !looksLikeQuestion {
            return SwarmRequestDecision(
                intent: .incorporateInformation,
                reason: "The turn contains attachments without an answer request.",
                shouldUseColonyContext: false,
                shouldUseOnlineSource: false,
                shouldWriteToMemory: true,
                shouldAskForApprovedURL: false
            )
        }

        if Self.containsAny(lower, terms: Self.incorporationTerms), !looksLikeQuestion || Self.isMemoryRequest(lower) {
            return SwarmRequestDecision(
                intent: .incorporateInformation,
                reason: "The user is giving Swarm information to keep.",
                shouldUseColonyContext: false,
                shouldUseOnlineSource: false,
                shouldWriteToMemory: true,
                shouldAskForApprovedURL: false
            )
        }

        if hasContext {
            return SwarmRequestDecision(
                intent: .answerFromContext,
                reason: "The prompt has active attachments, @ references, or high-relevance Colony context.",
                shouldUseColonyContext: true,
                shouldUseOnlineSource: false,
                shouldWriteToMemory: false,
                shouldAskForApprovedURL: false
            )
        }

        return SwarmRequestDecision(
            intent: .answerDirectly,
            reason: "No outside source or durable-memory instruction was detected.",
            shouldUseColonyContext: false,
            shouldUseOnlineSource: false,
            shouldWriteToMemory: false,
            shouldAskForApprovedURL: false
        )
    }

    private static let onlineTerms = [
        "look online", "search online", "search the web", "check the web", "check online",
        "internet", "latest", "current", "today", "news", "pricing", "recent",
        "website", "web site", "online source", "outside source", "external source",
        "documentation", "docs page", "release notes", "compare vendors"
    ]

    private static let incorporationTerms = [
        "remember", "add this", "add to hive", "add to field", "save this", "save to colony",
        "incorporate", "learn this", "file this", "keep this", "track this", "for later",
        "update the colony", "put this in the colony", "new information", "new info"
    ]

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
            || lower.hasPrefix("can you explain ")
            || lower.hasPrefix("can you summarize ")
    }

    private static func isMemoryRequest(_ lower: String) -> Bool {
        lower.hasPrefix("remember ")
            || lower.hasPrefix("note ")
            || lower.hasPrefix("note:")
            || lower.hasPrefix("save this")
            || lower.hasPrefix("add this")
            || lower.hasPrefix("incorporate this")
    }

    private static func containsApprovedURL(_ lower: String) -> Bool {
        lower.contains("https://") || lower.contains("http://")
    }

    private static func containsAny(_ value: String, terms: [String]) -> Bool {
        terms.contains { value.contains($0) }
    }
}
