import Foundation
import Testing
@testable import HiveCore

@Suite("ContextRequestCoordinator")
struct ContextRequestCoordinatorTests {
    private func makeCoordinator() throws -> (ContextRequestCoordinator, HotMemoryStore, ContextTransitionToken) {
        let honeycomb = try HoneycombStore(path: ":memory:")
        let hotMemory = HotMemoryStore(honeycomb: honeycomb)
        let ledger = try EventLedgerStore(path: ":memory:")
        let orchestrator = SwarmOrchestrator(
            dispatcher: .shared,
            hotMemory: hotMemory,
            ledger: ledger,
            honeycomb: honeycomb
        )
        let token = ContextTransitionToken()
        return (
            ContextRequestCoordinator(
                hotMemory: hotMemory,
                orchestrator: orchestrator,
                transitionToken: token
            ),
            hotMemory,
            token
        )
    }

    @Test("rapid transitions converge on newest scope")
    func rapidTransitionsConvergeOnNewestScope() async throws {
        let (coordinator, hotMemory, _) = try makeCoordinator()
        let old = ContextScope(profileID: "profile-a", workspaceID: "workspace-a")
        let newest = ContextScope(profileID: "profile-b", workspaceID: "workspace-b")

        // Announce both generations before binding. This models two rapid UI
        // transitions without making the assertion depend on task scheduling.
        await coordinator.announceTransition(1)
        await coordinator.bind(scope: old, transitionID: 1)
        await coordinator.announceTransition(2)
        await coordinator.bind(scope: newest, transitionID: 2)

        #expect(await coordinator.latestTransitionID() == 2)
        #expect(await hotMemory.currentScope() == newest)
    }

    @Test("obsolete request fails closed after a newer transition")
    func obsoleteRequestFailsClosedAfterNewerTransition() async throws {
        let (coordinator, hotMemory, _) = try makeCoordinator()
        let old = ContextScope(profileID: "profile-a", workspaceID: "workspace-a")
        let newest = ContextScope(profileID: "profile-b", workspaceID: "workspace-b")

        await coordinator.bind(scope: old, transitionID: 1)
        await coordinator.announceTransition(2)
        await coordinator.bind(scope: newest, transitionID: 2)

        await #expect(throws: ContextTransitionError.staleTransition(
            expectedAtLeast: 2,
            received: 1
        )) {
            try await coordinator.process(
                scope: old,
                transitionID: 1,
                intent: "answer this",
                page: nil
            )
        }

        #expect(await hotMemory.currentScope() == newest)
    }

    @Test("in-flight transition rejects before response side effects")
    func inFlightTransitionRejectsBeforeResponseSideEffects() async throws {
        let (coordinator, hotMemory, token) = try makeCoordinator()
        let scope = ContextScope(profileID: "profile-race", workspaceID: "workspace-race")
        token.announce(1)

        await #expect(throws: ContextTransitionError.staleTransition(
            expectedAtLeast: 2,
            received: 1
        )) {
            try await coordinator.process(
                scope: scope,
                transitionID: 1,
                intent: "summarize the current work",
                page: nil,
                beforeResponseSideEffects: {
                    token.announce(2)
                }
            )
        }

        #expect(await hotMemory.currentScope() == scope)
        #expect((await hotMemory.currentHotEntries()).isEmpty)
    }

    @Test("request binds its explicit scope before orchestration")
    func requestBindsItsExplicitScopeBeforeOrchestration() async throws {
        let (coordinator, hotMemory, token) = try makeCoordinator()
        let scope = ContextScope(profileID: "profile-request", workspaceID: "workspace-request")

        token.announce(7)

        // Mock inference is deterministic and does not need a real page or
        // network. The assertion that matters is the scope visible after the
        // request, not the provider's answer text.
        _ = try await coordinator.process(
            scope: scope,
            transitionID: 7,
            intent: "summarize the current work",
            page: nil
        )

        #expect(await hotMemory.currentScope() == scope)
        #expect(await coordinator.latestTransitionID() == 7)
    }

@Test func transitionErrorEquality() {
        let a = ContextTransitionError.staleTransition(expectedAtLeast: 1, received: 0)
        let b = ContextTransitionError.staleTransition(expectedAtLeast: 1, received: 0)
        #expect(a == b)
    }
}
