import Foundation

/// Serializes browser scope transitions and Swarm requests.
///
/// Browser UI state is MainActor-isolated while HotMemory and Swarm are
/// independent actors. Calling `setActiveScope` from detached Tasks is not a
/// sufficient boundary: an old workspace-switch task can arrive after a newer
/// request and overwrite the active scope. This coordinator gives both paths a
/// single FIFO and a monotonic transition generation.
///
/// The coordinator is deliberately not a general-purpose agent runtime. It
/// owns only the browser-to-context handoff; policy, model routing, and action
/// approval remain in their existing components.
public actor ContextRequestCoordinator {
    private actor Generation {
        private var latest: UInt64 = 0

        func advance(to value: UInt64) {
            if value > latest { latest = value }
        }

        func isCurrent(_ value: UInt64) -> Bool {
            value == latest
        }

        func latestValue() -> UInt64 {
            latest
        }
    }

    private let hotMemory: HotMemoryStore
    private let orchestrator: SwarmOrchestrator
    private let transitionToken: ContextTransitionToken
    private let generation = Generation()
    private var tail: Task<Void, Never>?

    public init(
        hotMemory: HotMemoryStore,
        orchestrator: SwarmOrchestrator,
        transitionToken: ContextTransitionToken = ContextTransitionToken()
    ) {
        self.hotMemory = hotMemory
        self.orchestrator = orchestrator
        self.transitionToken = transitionToken
    }

    /// Announces a browser transition synchronously from the coordinator's
    /// actor boundary. This invalidates older requests before the caller
    /// enqueues the asynchronous HotMemory write.
    public func announceTransition(_ transitionID: UInt64) async {
        transitionToken.announce(transitionID)
        await generation.advance(to: transitionID)
    }

    /// Binds a browser transition. Older queued transitions are discarded when
    /// a newer generation has already been announced.
    public func bind(
        scope: ContextScope,
        transitionID: UInt64,
        clearCurrentPage: Bool = true
    ) async {
        transitionToken.announce(transitionID)
        await generation.advance(to: transitionID)

        let predecessor = tail
        let generation = self.generation
        let hotMemory = self.hotMemory
        let transitionToken = self.transitionToken
        let operation = Task { [predecessor, generation, hotMemory, transitionToken] in
            await predecessor?.value
            guard transitionToken.isCurrent(transitionID),
                  await generation.isCurrent(transitionID) else { return }
            if clearCurrentPage {
                await hotMemory.setCurrentPage(nil)
            }
            await hotMemory.setActiveScope(scope)
        }
        tail = Task { await operation.value }
        await operation.value
    }

    /// Runs one request under an explicit browser scope. Requests and binds
    /// share the same FIFO, so a transition cannot interleave with scope
    /// binding or context assembly. If a newer transition is announced while a
    /// request is running, the request fails closed instead of returning a
    /// result that the current browser scope can no longer justify.
    public func process(
        scope: ContextScope,
        transitionID: UInt64,
        intent: String,
        page: PageContext?,
        role: ModelRole = .orchestrator,
        preferredProvider: ProviderPreference = .auto,
        userIntent: String? = nil,
        beforeOrchestration: @Sendable @escaping () async -> Void = {},
        beforeResponseSideEffects: @Sendable @escaping () async -> Void = {}
    ) async throws -> OrchestrationResult {
        await generation.advance(to: transitionID)
        guard transitionToken.isCurrent(transitionID) else {
            throw ContextTransitionError.staleTransition(
                expectedAtLeast: transitionToken.current(),
                received: transitionID
            )
        }

        let predecessor = tail
        let generation = self.generation
        let hotMemory = self.hotMemory
        let orchestrator = self.orchestrator
        let transitionToken = self.transitionToken
        let operation = Task<OrchestrationResult, Error> { [predecessor, generation, hotMemory, orchestrator, transitionToken, beforeOrchestration, beforeResponseSideEffects] in
            await predecessor?.value
            guard transitionToken.isCurrent(transitionID),
                  await generation.isCurrent(transitionID) else {
                throw ContextTransitionError.staleTransition(
                    expectedAtLeast: max(await generation.latestValue(), transitionToken.current()),
                    received: transitionID
                )
            }

            await hotMemory.setActiveScope(scope)
            await beforeOrchestration()
            guard transitionToken.isCurrent(transitionID) else {
                throw ContextTransitionError.staleTransition(
                    expectedAtLeast: transitionToken.current(),
                    received: transitionID
                )
            }
            let result: OrchestrationResult
            do {
                result = try await orchestrator.process(
                    intent: intent,
                    page: page,
                    role: role,
                    preferredProvider: preferredProvider,
                    transitionIsCurrent: { transitionToken.isCurrent(transitionID) },
                    beforeResponseSideEffects: beforeResponseSideEffects,
                    userIntent: userIntent
                )
            } catch ContextTransitionError.staleTransition {
                // Normalize stale failures raised inside the pipeline with the
                // real generations owned by this boundary. Lower-level cells
                // need only a boolean guard; callers need actionable IDs.
                throw ContextTransitionError.staleTransition(
                    expectedAtLeast: max(await generation.latestValue(), transitionToken.current()),
                    received: transitionID
                )
            }

            guard transitionToken.isCurrent(transitionID),
                  await generation.isCurrent(transitionID) else {
                throw ContextTransitionError.staleTransition(
                    expectedAtLeast: max(await generation.latestValue(), transitionToken.current()),
                    received: transitionID
                )
            }
            return result
        }
        tail = Task { _ = try? await operation.value }
        return try await operation.value
    }

    /// Exposed for diagnostics and deterministic integration tests; it contains
    /// no user data, only the latest monotonic browser transition generation.
    public func latestTransitionID() async -> UInt64 {
        await generation.latestValue()
    }
}
