import Foundation
import Testing
@testable import HiveCore

private actor TrustedTurnExecutionRecorder {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }

    func count() -> Int {
        values.count
    }
}

@MainActor
private final class TrustedTurnGatewayFixture {
    let honeycomb: HoneycombStore
    let ledger: EventLedgerStore
    let hotMemory: HotMemoryStore
    let gateway: TrustedTurnGateway
    let recorder: TrustedTurnExecutionRecorder
    let hasResearchProvider: Bool

    init(hasResearchProvider: Bool = true) throws {
        honeycomb = try HoneycombStore(path: ":memory:")
        ledger = try EventLedgerStore(path: ":memory:")
        hotMemory = HotMemoryStore(honeycomb: honeycomb)
        gateway = TrustedTurnGateway(
            honeycomb: honeycomb,
            hotMemory: hotMemory,
            ledger: ledger
        )
        recorder = TrustedTurnExecutionRecorder()
        self.hasResearchProvider = hasResearchProvider
    }

    var executor: TrustedTurnExecutor {
        let recorder: TrustedTurnExecutionRecorder = self.recorder
        return { decision, request in
            await recorder.append("\(decision.route.rawValue):\(request.text)")
            return TrustedTurnExecution(
                text: "Executed \(decision.route.rawValue)",
                providerLabel: "test"
            )
        }
    }

    func executionCount() async -> Int {
        await recorder.count()
    }

    func noExecutions() async -> Bool {
        await recorder.count() == 0
    }

    func request(_ text: String, scope: TrustedTurnScope = .workspace, isPrivate: Bool = false,
                 aiContextAllowed: Bool = true, hasActivePage: Bool = true) -> TrustedTurnRequest {
        TrustedTurnRequest(
            text: text,
            scope: scope,
            isPrivate: isPrivate,
            aiContextAllowed: aiContextAllowed,
            hasActivePage: hasActivePage,
            hasResearchProvider: hasResearchProvider
        )
    }
}

@Suite("TrustedTurnGateway")
struct TrustedTurnGatewayTests {
    @Test("routes a generic request without expanding its declared scope")
    @MainActor
    func genericRequestIsAdvisory() async throws {
        let fixture = try TrustedTurnGatewayFixture()
        let outcome = await fixture.gateway.submit(
            fixture.request("What is the capital of France?", scope: .pageOnly),
            execute: fixture.executor
        )

        guard case .executed(let result, let decision, let scope) = outcome else {
            Issue.record("Expected a generic request to execute")
            return
        }
        #expect(decision.route == .genericQuestion)
        #expect(scope.scope == .pageOnly)
        #expect(scope.includesMemory == false)
        #expect(result.providerLabel == "test")
        #expect(await fixture.executionCount() == 1)
    }

    @Test("research without a configured provider is honest and never executes")
    @MainActor
    func unavailableResearchDoesNotExecute() async throws {
        let fixture = try TrustedTurnGatewayFixture(hasResearchProvider: false)
        let outcome = await fixture.gateway.submit(
            fixture.request("Research the best local bookstores", scope: .web),
            execute: fixture.executor
        )

        guard case .unsupported(let message, let decision, let scope) = outcome else {
            Issue.record("Expected unsupported research")
            return
        }
        #expect(decision.route == .unsupported)
        #expect(message.contains("not configured"))
        #expect(scope.scope == .web)
        #expect(await fixture.noExecutions())
    }

    @Test("explicit preference is persisted, but derived page text cannot create preference")
    @MainActor
    func preferenceBoundaryUsesOriginalTextOnly() async throws {
        let fixture = try TrustedTurnGatewayFixture()
        _ = await fixture.gateway.submit(
            TrustedTurnRequest(
                text: "I'm vegetarian, recommend restaurants nearby",
                scope: .workspace,
                pageText: "The page says I'm vegan",
                hasResearchProvider: true
            ),
            execute: fixture.executor
        )

        #expect(try await fixture.honeycomb.countNodes(type: .preference) == 1)
        let nodes = try await fixture.honeycomb.getNodesByType(.preference)
        guard let preference = nodes.first,
              let typed = PreferenceMemory(node: preference) else {
            Issue.record("Expected one typed preference node")
            return
        }
        #expect(typed.value == "vegetarian")
        #expect(typed.evidence.contains("I'm vegetarian"))
        #expect(!typed.evidence.contains("vegan"))
    }

    @Test("action remains confirmation-gated")
    @MainActor
    func actionCannotExecuteBeforeConfirmation() async throws {
        let fixture = try TrustedTurnGatewayFixture()
        let first = await fixture.gateway.submit(
            fixture.request("Run the project tests now"),
            execute: fixture.executor
        )

        guard case .clarification(_, let decision, _) = first else {
            Issue.record("Expected confirmation clarification")
            return
        }
        #expect(decision.route == .action)
        #expect(decision.requiresConfirmation)
        #expect(await fixture.noExecutions())

        let confirmed = await fixture.gateway.submit(
            fixture.request("confirm"),
            execute: fixture.executor
        )
        guard case .queued(let message, _, _) = confirmed else {
            Issue.record("Expected explicit confirmation to queue the typed action")
            return
        }
        #expect(message == "Executed action")
        #expect(await fixture.executionCount() == 1)
        let approvalEvents = try await fixture.ledger
            .getEvents()
            .filter { $0.provenance == "trusted-turn-approval" }
        #expect(approvalEvents.count == 1)
        #expect(approvalEvents[0].policyDecision == EventLedgerStore.PolicyDecision.requiresConfirmation)
        #expect(approvalEvents[0].consentState == EventLedgerStore.ConsentState.approved)
        #expect(approvalEvents[0].result == EventLedgerStore.EventResult.partial)
    }

    @Test("confirmation keeps the original privacy scope across a follow-up")
    @MainActor
    func clarificationPreservesOriginalScope() async throws {
        let fixture = try TrustedTurnGatewayFixture()
        let first = await fixture.gateway.submit(
            TrustedTurnRequest(text: "Run", scope: .pageOnly, hasActivePage: true),
            execute: fixture.executor
        )
        guard case .clarification = first else {
            Issue.record("Expected an initial clarification")
            return
        }

        let second = await fixture.gateway.submit(
            TrustedTurnRequest(text: "project tests", scope: .web, hasActivePage: false),
            execute: fixture.executor
        )
        guard case .clarification = second else {
            Issue.record("Expected the clarified action to request confirmation")
            return
        }

        let confirmed = await fixture.gateway.submit(
            TrustedTurnRequest(text: "confirm", scope: .web, hasActivePage: false),
            execute: fixture.executor
        )
        guard case .queued(_, _, let scope) = confirmed else {
            Issue.record("Expected the clarified action to queue")
            return
        }
        #expect(scope.scope == .pageOnly)
        #expect(scope.includesPage)
        #expect(scope.includesWeb == false)
    }

    @Test("missing audit ledger prevents a consequential executor from running")
    @MainActor
    func missingApprovalLedgerFailsClosed() async throws {
        let gateway = TrustedTurnGateway()
        let recorder = TrustedTurnExecutionRecorder()
        let executor: TrustedTurnExecutor = { decision, _ in
            await recorder.append(decision.route.rawValue)
            return TrustedTurnExecution(text: "should not run", providerLabel: "test")
        }

        let first = await gateway.submit(
            TrustedTurnRequest(text: "Run the project tests now", scope: .workspace),
            execute: executor
        )
        guard case .clarification = first else {
            Issue.record("Expected confirmation clarification")
            return
        }
        let result = await gateway.submit(
            TrustedTurnRequest(text: "confirm", scope: .workspace),
            execute: executor
        )
        guard case .failed(let message, _, _) = result else {
            Issue.record("Expected audit failure before execution")
            return
        }
        #expect(message.contains("approval decision"))
        #expect(await recorder.count() == 0)
    }

    @Test("cancel clears a pending request and prevents a later confirmation")
    @MainActor
    func cancelClearsPendingAction() async throws {
        let fixture = try TrustedTurnGatewayFixture()
        let first = await fixture.gateway.submit(
            fixture.request("Run the project tests now"),
            execute: fixture.executor
        )
        guard case .clarification = first else {
            Issue.record("Expected confirmation clarification")
            return
        }
        fixture.gateway.cancel()
        let afterCancel = await fixture.gateway.submit(
            fixture.request("confirm"),
            execute: fixture.executor
        )
        guard case .clarification = afterCancel else {
            Issue.record("A post-cancel confirmation should not execute")
            return
        }
        #expect(await fixture.noExecutions())
    }

    @Test("private scope is denied before execution or persistence")
    @MainActor
    func privateRequestFailsClosed() async throws {
        let fixture = try TrustedTurnGatewayFixture()
        let outcome = await fixture.gateway.submit(
            fixture.request("Summarize this page", scope: .pageOnly, isPrivate: true),
            execute: fixture.executor
        )

        guard case .unsupported(let message, let decision, let scope) = outcome else {
            Issue.record("Expected private scope denial")
            return
        }
        #expect(decision.route == .unsupported)
        #expect(message.contains("private"))
        #expect(scope.includesPage == false)
        #expect(await fixture.noExecutions())
        #expect(try await fixture.honeycomb.countNodes(type: .preference) == 0)
    }

    @Test("AI-disabled page scope is denied instead of silently becoming title-only context")
    @MainActor
    func disabledPageFailsClosed() async throws {
        let fixture = try TrustedTurnGatewayFixture()
        let outcome = await fixture.gateway.submit(
            fixture.request("Summarize this page", scope: .pageOnly, aiContextAllowed: false),
            execute: fixture.executor
        )

        guard case .unsupported(_, let decision, let scope) = outcome else {
            Issue.record("Expected disabled page denial")
            return
        }
        #expect(decision.route == .unsupported)
        #expect(scope.includesPage == false)
        #expect(await fixture.noExecutions())
    }

    @Test("gateway records bounded route metadata without page body")
    @MainActor
    func auditRecordIsBounded() async throws {
        let fixture = try TrustedTurnGatewayFixture()
        _ = await fixture.gateway.submit(
            TrustedTurnRequest(
                text: "What does this page say?",
                scope: .pageOnly,
                pageText: "SECRET_PAGE_BODY",
                hasActivePage: true,
                hasResearchProvider: true
            ),
            execute: fixture.executor
        )

        let events = try await fixture.ledger.getEvents(byActor: "trusted-turn-gateway")
        #expect(events.count == 1)
        #expect(events[0].intent.contains("pageOnly"))
        #expect(events[0].intent.contains("SECRET_PAGE_BODY") == false)
        #expect(events[0].actionPreview?.contains("SECRET_PAGE_BODY") == false)
    }

@Test func trustedTurnRequestPreservesScope() {
        let req = TrustedTurnRequest(text: "test", scope: .workspace)
        #expect(req.scope == .workspace)
    }

@Test func allScopesHaveDiagnosticLabels() {
        for scope in TrustedTurnScope.allCases {
            #expect(!scope.diagnosticLabel.isEmpty)
        }
    }
}
