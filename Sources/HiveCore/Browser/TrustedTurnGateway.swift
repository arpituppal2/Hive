import Foundation

// MARK: - Trusted turn gateway

/// The context surface selected for one Swarm turn. This is a user-visible
/// scope, not a prompt convention: the browser shell must still provide only
/// the data admitted by the scope when it executes the turn.
public enum TrustedTurnScope: String, Codable, Sendable, Equatable, CaseIterable {
    case pageOnly
    case workspace
    case selectedTabs
    case web

    public var diagnosticLabel: String {
        switch self {
        case .pageOnly: return "Page only"
        case .workspace: return "Workspace"
        case .selectedTabs: return "Selected tabs"
        case .web: return "Web research"
        }
    }

    fileprivate var includesPage: Bool {
        switch self {
        case .pageOnly, .workspace, .selectedTabs: return true
        case .web: return false
        }
    }

    fileprivate var includesMemory: Bool {
        self == .workspace
    }
}

/// Metadata and user-authored text for one turn. `pageText` is intentionally
/// opaque to the gateway: only the browser executor may use it after applying
/// BrowserContextPolicy. It is never used for classification or memory writes.
public struct TrustedTurnRequest: Sendable, Equatable {
    public let text: String
    public let scope: TrustedTurnScope
    public let pageText: String?
    public let isPrivate: Bool
    public let aiContextAllowed: Bool
    public let hasActivePage: Bool
    public let hasResearchProvider: Bool

    public init(
        text: String,
        scope: TrustedTurnScope,
        pageText: String? = nil,
        isPrivate: Bool = false,
        aiContextAllowed: Bool = true,
        hasActivePage: Bool = true,
        hasResearchProvider: Bool = false
    ) {
        self.text = text
        self.scope = scope
        self.pageText = pageText
        self.isPrivate = isPrivate
        self.aiContextAllowed = aiContextAllowed
        self.hasActivePage = hasActivePage
        self.hasResearchProvider = hasResearchProvider
    }
}

/// The only scope facts rendered by the gateway UI. It contains no page text,
/// history, screenshots, credentials, or model output.
public struct TrustedTurnScopeDescriptor: Sendable, Equatable {
    public let scope: TrustedTurnScope
    public let label: String
    public let includesPage: Bool
    public let includesMemory: Bool
    public let includesWeb: Bool

    public init(scope: TrustedTurnScope,
                isPrivate: Bool = false,
                aiContextAllowed: Bool = true,
                hasActivePage: Bool = true) {
        self.scope = scope
        self.label = scope.diagnosticLabel
        self.includesPage = scope.includesPage && hasActivePage && !isPrivate && aiContextAllowed
        self.includesMemory = scope.includesMemory && !isPrivate
        self.includesWeb = scope == .web
    }
}

/// Provider-labelled output returned by a typed browser-shell executor.
public struct TrustedTurnExecution: Sendable, Equatable {
    public let text: String
    public let providerLabel: String
    public let shouldSpeak: Bool

    public init(text: String, providerLabel: String = "local", shouldSpeak: Bool = true) {
        self.text = text
        self.providerLabel = providerLabel
        self.shouldSpeak = shouldSpeak
    }
}

public enum TrustedTurnOutcome: Sendable, Equatable {
    case clarification(prompt: String, decision: VoiceRouteDecision, scope: TrustedTurnScopeDescriptor)
    case executed(result: TrustedTurnExecution, decision: VoiceRouteDecision, scope: TrustedTurnScopeDescriptor)
    case queued(message: String, decision: VoiceRouteDecision, scope: TrustedTurnScopeDescriptor)
    case unsupported(message: String, decision: VoiceRouteDecision, scope: TrustedTurnScopeDescriptor)
    case failed(message: String, decision: VoiceRouteDecision?, scope: TrustedTurnScopeDescriptor)
    case cancelled(scope: TrustedTurnScopeDescriptor)
}

private struct TrustedTurnAuditUnavailable: LocalizedError {
    var errorDescription: String? {
        "Hive could not record the approval decision, so the action was not run."
    }
}

/// The browser shell supplies route-specific behavior. The gateway owns the
/// trust boundary; this closure owns the capability implementation.
public typealias TrustedTurnExecutor = @Sendable (VoiceRouteDecision, TrustedTurnRequest) async throws -> TrustedTurnExecution

/// Shared text/voice-transcript front door for Swarm. It is MainActor-bound so
/// the browser UI and the existing MainActor VoiceCommandCoordinator share one
/// lifecycle, while Honeycomb/EventLedger remain actor-isolated dependencies.
@MainActor
public final class TrustedTurnGateway {
    private let router: SwarmIntentRouter
    private let coordinator: VoiceCommandCoordinator
    private let honeycomb: HoneycombStore?
    private let hotMemory: HotMemoryStore
    private let ledger: EventLedgerStore?
    private var pendingRequest: TrustedTurnRequest?

    public init(
        router: SwarmIntentRouter = .init(),
        coordinator: VoiceCommandCoordinator? = nil,
        honeycomb: HoneycombStore? = nil,
        hotMemory: HotMemoryStore = HotMemoryStore(),
        ledger: EventLedgerStore? = nil
    ) {
        self.router = router
        self.coordinator = coordinator ?? VoiceCommandCoordinator { text, context in
            router.route(text, context: context).decision
        }
        self.honeycomb = honeycomb
        self.hotMemory = hotMemory
        self.ledger = ledger
    }

    /// Submits one user-authored turn. The gateway never widens scope and never
    /// invokes the executor for clarification, unsupported, private, or empty
    /// requests. A confirmation/follow-up continues through the coordinator's
    /// existing bounded state machine.
    public func submit(
        _ request: TrustedTurnRequest,
        execute: @escaping TrustedTurnExecutor
    ) async -> TrustedTurnOutcome {
        let scope = TrustedTurnScopeDescriptor(
            scope: request.scope,
            isPrivate: request.isPrivate,
            aiContextAllowed: request.aiContextAllowed,
            hasActivePage: request.hasActivePage
        )
        let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            let outcome = TrustedTurnOutcome.failed(
                message: "I didn't hear a request.", decision: nil, scope: scope
            )
            _ = await record(outcome: outcome)
            return outcome
        }

        // A private page is never sent to a model through this front door. The
        // browser can still offer ordinary private browsing, but Swarm does not
        // inspect, persist, or infer from it.
        if request.isPrivate && request.scope != .web {
            let decision = VoiceRouteDecision(
                route: .unsupported,
                confidence: 1,
                reason: "Private browsing content is outside the Swarm context boundary.",
                clarificationPrompt: "This page is private, so Swarm did not inspect or retain its contents."
            )
            let outcome = TrustedTurnOutcome.unsupported(
                message: decision.clarificationPrompt!, decision: decision, scope: scope
            )
            _ = await record(outcome: outcome)
            pendingRequest = nil
            return outcome
        }

        // Page-only requests cannot silently downgrade to a title/URL-only model
        // request when the user asked about page content. Ask/deny explicitly.
        if request.scope == .pageOnly && !request.aiContextAllowed {
            let decision = VoiceRouteDecision(
                route: .unsupported,
                confidence: 1,
                reason: "The active tab has disabled AI context.",
                clarificationPrompt: "Swarm page access is off for this tab, so its contents were not inspected."
            )
            let outcome = TrustedTurnOutcome.unsupported(
                message: decision.clarificationPrompt!, decision: decision, scope: scope
            )
            _ = await record(outcome: outcome)
            pendingRequest = nil
            return outcome
        }

        let contextRequest = pendingRequest ?? request
        let context = VoiceCommandContext(
            hasActivePage: contextRequest.hasActivePage && !contextRequest.isPrivate && contextRequest.aiContextAllowed,
            hasResearchProvider: contextRequest.hasResearchProvider,
            workspaceName: nil
        )
        // Only the original user text reaches this extractor. Page text and
        // derived prompts are deliberately absent from this call. Persistence
        // happens only after the route is accepted below, so an unsupported or
        // cancelled turn cannot teach durable memory as a side effect.
        let candidates = router.preferenceCandidates(from: trimmed)

        // Keep the original context for a confirmation/follow-up. The
        // coordinator intentionally receives only text and a typed decision;
        // the gateway supplies the immutable request when execution is allowed.
        let requestForExecution = contextRequest
        let executionScope = TrustedTurnScopeDescriptor(
            scope: requestForExecution.scope,
            isPrivate: requestForExecution.isPrivate,
            aiContextAllowed: requestForExecution.aiContextAllowed,
            hasActivePage: requestForExecution.hasActivePage
        )
        let approvalLedger = ledger
        let outcome = await coordinator.submit(trimmed, context: context) { decision, _ in
            // Consequential work is fail-closed on audit failure. The approval
            // event is written before the typed executor receives control; a
            // later result event is useful evidence but cannot substitute for
            // this pre-execution consent record.
            if decision.requiresConfirmation {
                guard await Self.recordApproval(
                    ledger: approvalLedger,
                    decision: decision,
                    scope: executionScope
                ) else {
                    throw TrustedTurnAuditUnavailable()
                }
            }
            let execution = try await execute(decision, requestForExecution)
            return VoiceExecutionResult(
                text: execution.text,
                providerLabel: execution.providerLabel,
                shouldSpeak: execution.shouldSpeak
            )
        }
        let mapped = map(outcome: outcome, scope: executionScope)

        switch mapped {
        case .clarification:
            // Clarification answers must not replace the original request's
            // privacy/context scope. Store the first request only.
            if pendingRequest == nil {
                pendingRequest = request
            }
        case .executed:

            if !candidates.isEmpty,
               requestForExecution.scope == .workspace,
               !requestForExecution.isPrivate,
               let honeycomb {
                // Preference persistence is owned by the gateway and happens
                // only after the coordinator has accepted the turn. The
                // original request is the only source of preference evidence.
                await PreferenceMemoryBridge.persist(candidates, in: honeycomb, hotMemory: hotMemory)
            }
            pendingRequest = nil
        case .queued, .unsupported, .failed, .cancelled:
            pendingRequest = nil
        }

        _ = await record(outcome: mapped)
        return mapped
    }

    private func map(outcome: VoiceCommandOutcome, scope: TrustedTurnScopeDescriptor) -> TrustedTurnOutcome {
        switch outcome {
        case .clarification(let prompt, let decision):
            return .clarification(prompt: prompt, decision: decision, scope: scope)
        case .executed(let result, let decision) where decision.route == .action:
            return .queued(
                message: result.text,
                decision: decision,
                scope: scope
            )
        case .executed(let result, let decision):
            return .executed(
                result: TrustedTurnExecution(
                    text: result.text,
                    providerLabel: result.providerLabel,
                    shouldSpeak: result.shouldSpeak
                ),
                decision: decision,
                scope: scope
            )
        case .unsupported(let message, let decision):
            return .unsupported(message: message, decision: decision, scope: scope)
        case .failed(let message, let decision):
            return .failed(message: message, decision: decision, scope: scope)
        case .cancelled:
            return .cancelled(scope: scope)
        }
    }

    /// Records only bounded route metadata. The user's full text, page body,
    /// credentials, and generated answer are intentionally not written here.
    private func record(outcome: TrustedTurnOutcome) async -> Bool {
        guard let ledger else { return true }
        let route: VoiceRoute
        let decision: VoiceRouteDecision?
        let provider: String?
        let result: EventLedgerStore.EventResult
        let policy: EventLedgerStore.PolicyDecision
        let consent: EventLedgerStore.ConsentState
        let scope: TrustedTurnScopeDescriptor

        switch outcome {
        case .clarification(_, let value, let descriptor):
            route = value.route
            decision = value
            provider = nil
            result = .partial
            policy = value.requiresConfirmation ? .requiresConfirmation : .allowed
            consent = value.requiresConfirmation ? .pending : .auto
            scope = descriptor
        case .executed(let execution, let value, let descriptor):
            route = value.route
            decision = value
            provider = execution.providerLabel
            result = .success
            policy = value.requiresConfirmation ? .allowed : .allowed
            consent = value.requiresConfirmation ? .approved : .notRequired
            scope = descriptor
        case .queued(_, let value, let descriptor):
            route = value.route
            decision = value
            provider = nil
            result = .partial
            policy = .requiresConfirmation
            consent = .approved
            scope = descriptor
        case .unsupported(_, let value, let descriptor):
            route = value.route
            decision = value
            provider = nil
            result = .failure
            policy = .denied
            consent = .notRequired
            scope = descriptor
        case .failed(_, let value, let descriptor):
            route = value?.route ?? .unsupported
            decision = value
            provider = nil
            result = .failure
            policy = .denied
            consent = .notRequired
            scope = descriptor
        case .cancelled(let descriptor):
            route = .clarification
            decision = nil
            provider = nil
            result = .cancelled
            policy = .denied
            consent = .denied
            scope = descriptor
        }

        let summary = "route=\(route.rawValue); scope=\(scope.scope.rawValue); page=\(scope.includesPage); memory=\(scope.includesMemory); web=\(scope.includesWeb)"
        let event = EventLedgerStore.LedgerEvent(
            actor: "trusted-turn-gateway",
            intent: summary,
            actionKind: Self.actionKind(for: route),
            actionPreview: decision.map { "confidence=\(String(format: "%.2f", $0.confidence)); reason=\(String($0.reason.prefix(160)))" },
            trustLevel: Self.trustLevel(for: route),
            policyDecision: policy,
            consentState: consent,
            modelProvider: provider,
            modelRole: route == .genericQuestion ? ModelRole.orchestrator.rawValue : nil,
            outputSummary: provider.map { "provider=\($0)" },
            result: result,
            provenance: "trusted-turn"
        )
        do {
            _ = try await ledger.record(event)
            return true
        } catch {
            return false
        }
    }

    /// Writes the durable approval evidence required immediately before a
    /// consequential executor runs. This intentionally returns false when the
    /// ledger is unavailable; the caller must not execute in that case.
    private nonisolated static func recordApproval(
        ledger: EventLedgerStore?,
        decision: VoiceRouteDecision,
        scope: TrustedTurnScopeDescriptor
    ) async -> Bool {
        guard let ledger else { return false }
        let event = EventLedgerStore.LedgerEvent(
            actor: "trusted-turn-gateway",
            intent: "user-confirmed route=\(decision.route.rawValue); scope=\(scope.scope.rawValue)",
            actionKind: Self.actionKind(for: decision.route),
            actionPreview: "User confirmation received; typed policy and execution remain pending. confidence=\(String(format: "%.2f", decision.confidence)); reason=\(String(decision.reason.prefix(160)))",
            trustLevel: Self.trustLevel(for: decision.route),
            policyDecision: .requiresConfirmation,
            consentState: .approved,
            result: .partial,
            verificationResult: .unchecked,
            provenance: "trusted-turn-approval"
        )
        do {
            _ = try await ledger.record(event)
            return true
        } catch {
            return false
        }
    }

    public func cancel() {
        pendingRequest = nil
        coordinator.cancel()
    }

    public func reset() {
        pendingRequest = nil
        coordinator.reset()
    }

    private nonisolated static func actionKind(for route: VoiceRoute) -> EventLedgerStore.ActionKind {
        switch route {
        case .research: return .research
        case .browse: return .browserNavigate
        case .action: return .browserAction
        case .genericQuestion, .pageQuestion, .organize, .clarification, .unsupported:
            return .modelCall
        }
    }

    private nonisolated static func trustLevel(for route: VoiceRoute) -> EventLedgerStore.TrustLevel {
        switch route {
        case .action, .browse: return .t3
        case .genericQuestion, .pageQuestion, .research, .organize: return .t1
        case .clarification, .unsupported: return .t0
        }
    }
}
