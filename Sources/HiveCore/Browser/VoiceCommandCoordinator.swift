import Foundation
import Observation

// MARK: - Voice command routing

/// The user-visible kind of work a spoken request represents. This is a route,
/// not permission: action routes still go through the existing policy and
/// approval ladder before anything consequential can run.
public enum VoiceRoute: String, Sendable, Codable, CaseIterable {
    case genericQuestion
    case pageQuestion
    case research
    case organize
    case browse
    case action
    case clarification
    case unsupported
}

/// Context explicitly supplied by the browser shell for one voice turn.
/// Voice routing never silently broadens this scope.
public struct VoiceCommandContext: Sendable, Equatable {
    public let hasActivePage: Bool
    public let hasResearchProvider: Bool
    public let workspaceName: String?

    public init(hasActivePage: Bool = false,
                hasResearchProvider: Bool = false,
                workspaceName: String? = nil) {
        self.hasActivePage = hasActivePage
        self.hasResearchProvider = hasResearchProvider
        self.workspaceName = workspaceName
    }
}

/// A typed, auditable route decision. Models may propose one of these, but the
/// policy engine remains the authority for capability and confirmation.
public struct VoiceRouteDecision: Sendable, Equatable, Codable {
    public let route: VoiceRoute
    public let confidence: Double
    public let reason: String
    public let missingFields: [String]
    public let clarificationPrompt: String?
    public let requiresConfirmation: Bool

    public init(route: VoiceRoute,
                confidence: Double,
                reason: String,
                missingFields: [String] = [],
                clarificationPrompt: String? = nil,
                requiresConfirmation: Bool = false) {
        self.route = route
        self.confidence = min(max(confidence, 0), 1)
        self.reason = reason
        self.missingFields = missingFields
        self.clarificationPrompt = clarificationPrompt
        self.requiresConfirmation = requiresConfirmation
    }

    public var needsClarification: Bool {
        route == .clarification || clarificationPrompt != nil || !missingFields.isEmpty
    }
}

/// The result returned by the browser shell after a route executes.
public struct VoiceExecutionResult: Sendable, Equatable {
    public let text: String
    public let providerLabel: String
    public let shouldSpeak: Bool

    public init(text: String, providerLabel: String = "local", shouldSpeak: Bool = true) {
        self.text = text
        self.providerLabel = providerLabel
        self.shouldSpeak = shouldSpeak
    }
}

public enum VoiceCommandOutcome: Sendable, Equatable {
    case clarification(prompt: String, decision: VoiceRouteDecision)
    case executed(result: VoiceExecutionResult, decision: VoiceRouteDecision)
    case unsupported(message: String, decision: VoiceRouteDecision)
    case failed(message: String, decision: VoiceRouteDecision?)
    case cancelled
}

public enum VoiceCommandState: String, Sendable, Codable, CaseIterable {
    case idle
    case listening
    case transcribing
    case classifying
    case clarifying
    case executing
    case speaking
    case completed
    case unsupported
    case failed
    case cancelled
}

// MARK: - Deterministic first-pass classifier

/// A conservative local classifier for obvious voice requests. It is designed
/// to be the always-available front door: no weights, network, or model claim.
/// A future model classifier can replace this behind the same decision contract,
/// but it must preserve the same clarification and action invariants.
public struct DeterministicVoiceRouteClassifier: Sendable {
    public init() {}

    public func classify(_ rawText: String, context: VoiceCommandContext) -> VoiceRouteDecision {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        guard !text.isEmpty else {
            return clarification("What would you like Hive to do?", missing: ["request"])
        }

        if isAmbiguousCommand(lower) {
            return clarification(
                "What should I act on, and what result do you want?",
                missing: ["target", "desired result"]
            )
        }

        let hasPreference = !PreferenceExtractor.extract(from: text).isEmpty
        if hasPreference && isResearch(lower) {
            // The preference is persisted as a side effect by the browser shell,
            // while the primary route remains research. One utterance can both
            // teach Hive and request work.
        } else if hasPreference && isRecommendation(lower) {
            return VoiceRouteDecision(
                route: .genericQuestion, confidence: 0.94,
                reason: "The request contains a durable preference plus a recommendation request; save the preference and answer the request."
            )
        } else if hasPreference {
            return VoiceRouteDecision(
                route: .organize, confidence: 0.99,
                reason: "The request contains an explicit first-person preference that can be filed into Hive memory."
            )
        }

        if isResearch(lower) {
            guard researchQuery(from: text) != nil else {
                return clarification("What would you like me to research?", missing: ["research query"])
            }
            guard context.hasResearchProvider else {
                return unsupported("Web research is not configured yet. I won't pretend to have searched the web. You can configure a research provider or ask me a question about the current browser context.")
            }
            return VoiceRouteDecision(
                route: .research, confidence: 0.98,
                reason: "The request explicitly asks for sources, investigation, or comparison."
            )
        }

        if isOrganize(lower) {
            guard hasOrganizeContent(lower) else {
                return clarification(
                    "What should I save or organize, and where should it go?",
                    missing: ["content", "destination"]
                )
            }
            return VoiceRouteDecision(
                route: .organize, confidence: 0.96,
                reason: "The request asks Hive to save, remember, note, or organize information."
            )
        }

        if isAction(lower) {
            guard hasActionTarget(lower) else {
                return clarification(
                    "Which item should I act on? I won't make a consequential change until you confirm the target.",
                    missing: ["action target"]
                )
            }
            guard isSupportedAction(lower) else {
                return unsupported("I understand the request, but Hive does not have a safe typed tool for that action yet. I won't pretend it ran. I can answer questions, research with a configured provider, or run an approved project check.")
            }
            return VoiceRouteDecision(
                route: .action, confidence: 0.93,
                reason: "The request contains a consequential action verb.",
                requiresConfirmation: true
            )
        }

        if isBrowse(lower) {
            return VoiceRouteDecision(
                route: .browse, confidence: 0.96,
                reason: "The request asks to open, navigate, or search the web.",
                requiresConfirmation: true
            )
        }

        if isPageQuestion(lower) {
            guard context.hasActivePage else {
                return clarification(
                    "Which page should I use for that question? There isn't an active page in scope.",
                    missing: ["active page"]
                )
            }
            return VoiceRouteDecision(
                route: .pageQuestion, confidence: 0.97,
                reason: "The request explicitly refers to the current page or tab."
            )
        }

        if isQuestion(lower) {
            return VoiceRouteDecision(
                route: .genericQuestion, confidence: 0.86,
                reason: "The request is phrased as a general question without an action target."
            )
        }

        // Short imperative language is unsafe to guess at. A longer neutral
        // sentence can still be answered as a generic request by the
        // orchestrator, while a terse fragment gets one focused question.
        if text.split(whereSeparator: { $0.isWhitespace }).count < 3 {
            return clarification("Could you say what outcome you want?", missing: ["desired result"])
        }

        return VoiceRouteDecision(
            route: .genericQuestion, confidence: 0.62,
            reason: "No specialized route matched; treating the request as advisory, not executable."
        )
    }

    private func clarification(_ prompt: String, missing: [String]) -> VoiceRouteDecision {
        VoiceRouteDecision(
            route: .clarification,
            confidence: 0.99,
            reason: "Required information is missing or the request is ambiguous.",
            missingFields: missing,
            clarificationPrompt: prompt
        )
    }

    private func unsupported(_ message: String) -> VoiceRouteDecision {
        VoiceRouteDecision(
            route: .unsupported,
            confidence: 1,
            reason: "The requested capability is unavailable or not safely configured.",
            clarificationPrompt: message
        )
    }


    private func isResearch(_ text: String) -> Bool {
        ["research", "find sources", "look up", "investigate", "compare", "deep dive", "what are the latest"]
            .contains(where: text.contains)
    }

    private func isOrganize(_ text: String) -> Bool {
        ["remember", "save this", "make a note", "take a note", "add this to", "organize this", "file this"]
            .contains(where: text.contains)
    }

    private func isAction(_ text: String) -> Bool {
        ["send ", "delete ", "remove ", "run ", "apply ", "write ", "change ", "book ",
         "purchase ", "buy ", "post ", "email ", "move ", "rename ", "close "]
            .contains(where: text.contains)
    }

    private func isBrowse(_ text: String) -> Bool {
        ["open ", "go to ", "navigate to ", "search the web", "search for ", "find me "]
            .contains(where: text.hasPrefix)
    }

    private func isPageQuestion(_ text: String) -> Bool {
        ["this page", "this tab", "current page", "current tab", "on this page", "on this tab"]
            .contains(where: text.contains)
    }

    private func isQuestion(_ text: String) -> Bool {
        text.hasSuffix("?") || ["what ", "why ", "how ", "when ", "where ", "who ", "can you ", "could you "]
            .contains(where: text.hasPrefix)
    }

    private func isRecommendation(_ text: String) -> Bool {
        ["recommend ", "recommendations", "suggest ", "where should i", "find a restaurant", "restaurants"]
            .contains(where: text.contains)
    }

    private func isAmbiguousCommand(_ text: String) -> Bool {
        ["do it", "handle it", "take care of it", "fix it", "send that", "save that", "open that"]
            .contains { text == $0 || text.hasPrefix($0 + " ") }
    }

    private func hasOrganizeContent(_ text: String) -> Bool {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        return words.count >= 4 || text.contains(":")
    }

    private func hasActionTarget(_ text: String) -> Bool {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        return words.count >= 3
    }

    private func isSupportedAction(_ text: String) -> Bool {
        text.contains("run ") || text.contains("test ") || text.hasSuffix("tests")
    }

    private func researchQuery(from text: String) -> String? {
        let prefixes = ["/research ", "research ", "look up ", "investigate ", "find sources for "]
        for prefix in prefixes where text.lowercased().hasPrefix(prefix) {
            let query = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return query.isEmpty ? nil : query
        }
        return text.split(whereSeparator: { $0.isWhitespace }).count >= 3 ? text : nil
    }
}

// MARK: - Coordinator

/// Main-actor finite-state coordinator for hands-free commands. It owns only
/// routing and lifecycle; the browser shell owns context, execution, policy,
/// and UI. A new command cancels the previous execution and stale results are
/// rejected by a generation token.
@MainActor
@Observable
public final class VoiceCommandCoordinator {
    public typealias Executor = (VoiceRouteDecision, String) async throws -> VoiceExecutionResult
    public typealias Classifier = (String, VoiceCommandContext) -> VoiceRouteDecision

    public private(set) var state: VoiceCommandState = .idle
    public private(set) var pendingDecision: VoiceRouteDecision?

    private let classifier: Classifier
    private var generation: UInt64 = 0
    /// The original command is retained while a clarification or confirmation
    /// is pending. A short answer such as "yes" must never be reclassified as
    /// an unrelated command.
    private var pendingCommandText: String?
    private var clarificationAttempts: Int = 0
    private let maximumClarificationAttempts = 3

    public init(classifier: @escaping Classifier = { text, context in
        SwarmIntentRouter().route(text, context: context).decision
    }) {
        self.classifier = classifier
    }

    public func beginListening() {
        generation &+= 1
        state = .listening
        pendingDecision = nil
        pendingCommandText = nil
        clarificationAttempts = 0
    }

    public func markTranscribing() {
        guard state == .listening else { return }
        state = .transcribing
    }

    public func cancel() {
        generation &+= 1
        pendingDecision = nil
        pendingCommandText = nil
        clarificationAttempts = 0
        state = .cancelled
    }

    public func reset() {
        pendingDecision = nil
        pendingCommandText = nil
        clarificationAttempts = 0
        state = .idle
    }

    public func finishSpeaking() {
        state = .completed
    }

    public func submit(_ rawText: String,
                      context: VoiceCommandContext,
                      execute: @escaping Executor) async -> VoiceCommandOutcome {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            state = .failed
            return .failed(message: "I didn't hear a request.", decision: nil)
        }

        // Cancellation is always safe and must work while clarification or
        // confirmation is pending. It is handled before classification so the
        // word "cancel" can never be appended to an old command and executed.
        if isExplicitCancellation(text) {
            cancel()
            return .cancelled
        }

        // A confirmation is a separate trust gate. It is intentionally handled
        // before classification: "confirm" is not a new user intent.
        if let pending = pendingDecision, pending.requiresConfirmation {
            guard isExplicitConfirmation(text) else {
                state = .clarifying
                return .clarification(
                    prompt: "This would be a consequential action. Say \"confirm\" to continue, or \"cancel\" to stop.",
                    decision: pending
                )
            }
            let commandText = pendingCommandText ?? text
            pendingDecision = nil
            pendingCommandText = nil
            clarificationAttempts = 0
            let commandGeneration = generation
            state = .executing
            do {
                let result = try await execute(pending, commandText)
                guard commandGeneration == generation else {
                    state = .cancelled
                    return .cancelled
                }
                state = result.shouldSpeak ? .speaking : .completed
                return .executed(result: result, decision: pending)
            } catch is CancellationError {
                state = .cancelled
                return .cancelled
            } catch {
                state = .failed
                return .failed(message: error.localizedDescription, decision: pending)
            }
        }

        let commandText: String
        if pendingDecision != nil {
            // Clarification answers are appended to the original request, not
            // interpreted as an unrelated command. This preserves the user's
            // target while allowing the classifier to see the missing detail.
            clarificationAttempts += 1
            commandText = "\(pendingCommandText ?? "") User clarification: \(text)"
        } else {
            clarificationAttempts = 0
            commandText = text
        }

        state = .classifying
        let decision = classifier(commandText, context)
        guard decision.confidence >= 0.60 || decision.needsClarification else {
            let fallback = VoiceRouteDecision(
                route: .clarification, confidence: 1,
                reason: commandText,
                missingFields: ["desired result"],
                clarificationPrompt: "What outcome do you want?"
            )
            pendingDecision = fallback
            state = .clarifying
            return .clarification(prompt: fallback.clarificationPrompt!, decision: fallback)
        }

        if decision.route == .unsupported {
            pendingDecision = nil
            pendingCommandText = nil
            clarificationAttempts = 0
            state = .unsupported
            return .unsupported(
                message: decision.clarificationPrompt ?? "That capability is unavailable.",
                decision: decision
            )
        }

        if decision.needsClarification {
            if clarificationAttempts >= maximumClarificationAttempts {
                let message = "I still don't have enough detail to do that safely. Please start a new voice request with the target and desired result."
                pendingDecision = nil
                pendingCommandText = nil
                clarificationAttempts = 0
                state = .unsupported
                return .unsupported(message: message, decision: decision)
            }
            pendingDecision = decision
            pendingCommandText = commandText
            state = .clarifying
            return .clarification(
                prompt: decision.clarificationPrompt ?? "What should I use as the target?",
                decision: decision
            )
        }

        if decision.requiresConfirmation {
            pendingDecision = decision
            pendingCommandText = commandText
            state = .clarifying
            return .clarification(
                prompt: "I can prepare that action, but I need your confirmation before it runs. Say \"confirm\" to continue.",
                decision: decision
            )
        }

        pendingDecision = nil
        pendingCommandText = nil
        clarificationAttempts = 0
        let commandGeneration = generation
        state = .executing
        do {
            let result = try await execute(decision, commandText)
            guard commandGeneration == generation else {
                state = .cancelled
                return .cancelled
            }
            state = result.shouldSpeak ? .speaking : .completed
            return .executed(result: result, decision: decision)
        } catch is CancellationError {
            state = .cancelled
            return .cancelled
        } catch {
            guard commandGeneration == generation else {
                state = .cancelled
                return .cancelled
            }
            state = .failed
            return .failed(message: error.localizedDescription, decision: decision)
        }
    }

    private func normalizedControlPhrase(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
    }

    private func isExplicitConfirmation(_ text: String) -> Bool {
        ["confirm", "confirmed", "yes, confirm", "go ahead", "do it"].contains(normalizedControlPhrase(text))
    }

    private func isExplicitCancellation(_ text: String) -> Bool {
        ["cancel", "stop", "never mind", "nevermind", "don't do that", "do not do that"]
            .contains(normalizedControlPhrase(text))
    }
}
