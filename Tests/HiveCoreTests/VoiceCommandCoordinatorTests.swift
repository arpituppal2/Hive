import Foundation
import Testing
@testable import HiveCore

@Suite("VoiceCommandCoordinator")
struct VoiceCommandCoordinatorTests {
    @Test func explicitPreferenceRoutesToOrganize() {
        let classifier = DeterministicVoiceRouteClassifier()
        let decision = classifier.classify(
            "I'm vegetarian",
            context: VoiceCommandContext()
        )

        #expect(decision.route == .organize)
        #expect(decision.confidence > 0.9)
        #expect(!decision.requiresConfirmation)
    }

    @Test func researchWithoutProviderIsUnsupportedWithoutLooping() async {
        let classifier = DeterministicVoiceRouteClassifier()
        let decision = classifier.classify(
            "Research the best local bookstores",
            context: VoiceCommandContext(hasResearchProvider: false)
        )

        #expect(decision.route == .unsupported)
        #expect(decision.clarificationPrompt?.contains("not configured") == true)

        let coordinator = await MainActor.run { VoiceCommandCoordinator() }
        let outcome = await coordinator.submit("Research the best local bookstores", context: VoiceCommandContext()) { _, _ in
            Issue.record("Unsupported research must not invoke an executor")
            return VoiceExecutionResult(text: "bad", providerLabel: "test")
        }
        guard case .unsupported = outcome else {
            Issue.record("Expected a terminal unsupported outcome, not a clarification loop")
            return
        }
    }

    @Test func unsupportedActionDoesNotRequestConfirmation() {
        let classifier = DeterministicVoiceRouteClassifier()
        let decision = classifier.classify(
            "Send an email to Alex",
            context: VoiceCommandContext()
        )
        #expect(decision.route == .unsupported)
        #expect(decision.requiresConfirmation == false)
    }

    @Test func pageQuestionWithoutPageDoesNotWidenScope() {
        let classifier = DeterministicVoiceRouteClassifier()
        let decision = classifier.classify(
            "What does this page say?",
            context: VoiceCommandContext(hasActivePage: false)
        )

        #expect(decision.route == .clarification)
        #expect(decision.missingFields.contains("active page"))
    }

    @Test func actionRequiresExplicitConfirmationBeforeExecutorRuns() async {
        let coordinator = await MainActor.run { VoiceCommandCoordinator() }
        await MainActor.run { coordinator.beginListening() }

        let first = await coordinator.submit(
            "Run the project tests now",
            context: VoiceCommandContext()
        ) { _, _ in
            VoiceExecutionResult(text: "Executed", providerLabel: "test")
        }

        guard case .clarification(_, let decision) = first else {
            Issue.record("Expected a confirmation clarification")
            return
        }
        #expect(decision.requiresConfirmation)

        let unconfirmed = await coordinator.submit(
            "yes maybe",
            context: VoiceCommandContext()
        ) { _, _ in
            Issue.record("Executor must not run for an ambiguous confirmation")
            return VoiceExecutionResult(text: "Executed", providerLabel: "test")
        }
        guard case .clarification = unconfirmed else {
            Issue.record("Expected the confirmation gate to remain open")
            return
        }

        let confirmed = await coordinator.submit(
            "confirm",
            context: VoiceCommandContext()
        ) { _, command in
            #expect(command.contains("Run the project tests now"))
            return VoiceExecutionResult(text: "Approval queued", providerLabel: "test")
        }
        guard case .executed(let result, _) = confirmed else {
            Issue.record("Expected confirmed action to execute")
            return
        }
        #expect(result.text == "Approval queued")
    }

    @Test func cancellationClearsPendingConfirmation() async {
        let coordinator = await MainActor.run { VoiceCommandCoordinator() }
        let first = await coordinator.submit("Run the project tests now", context: VoiceCommandContext()) { _, _ in
            Issue.record("Confirmation request should not execute")
            return VoiceExecutionResult(text: "bad", providerLabel: "test")
        }
        guard case .clarification = first else {
            Issue.record("Expected a confirmation state")
            return
        }
        let cancelled = await coordinator.submit("cancel", context: VoiceCommandContext()) { _, _ in
            Issue.record("Cancelled command must not execute")
            return VoiceExecutionResult(text: "bad", providerLabel: "test")
        }
        guard case .cancelled = cancelled else {
            Issue.record("Expected cancellation")
            return
        }
        #expect(await coordinator.pendingDecision == nil)
    }

    @Test func mixedPreferenceAndRecommendationKeepsWorkRoute() {
        let decision = DeterministicVoiceRouteClassifier().classify(
            "I'm vegetarian, recommend restaurants nearby",
            context: VoiceCommandContext()
        )
        #expect(decision.route == .genericQuestion)
        #expect(decision.reason.contains("durable preference"))
    }

    @Test func clarificationAttemptsAreBounded() async {
        let coordinator = await MainActor.run { VoiceCommandCoordinator() }
        let first = await coordinator.submit("do it", context: VoiceCommandContext()) { _, _ in
            Issue.record("An ambiguous request must not execute")
            return VoiceExecutionResult(text: "bad", providerLabel: "test")
        }
        guard case .clarification = first else {
            Issue.record("Expected an initial clarification")
            return
        }

        for _ in 0..<2 {
            let followUp = await coordinator.submit("Still unclear", context: VoiceCommandContext()) { _, _ in
                Issue.record("Clarification attempts must not execute")
                return VoiceExecutionResult(text: "bad", providerLabel: "test")
            }
            guard case .clarification = followUp else {
                Issue.record("Expected the coordinator to keep the bounded clarification loop open")
                return
            }
        }

        let terminal = await coordinator.submit("Still unclear", context: VoiceCommandContext()) { _, _ in
            Issue.record("The bounded clarification failure must not execute")
            return VoiceExecutionResult(text: "bad", providerLabel: "test")
        }
        guard case .unsupported(let message, _) = terminal else {
            Issue.record("Expected a terminal unsupported outcome after the clarification cap")
            return
        }
        #expect(message.contains("enough detail"))
        #expect(await coordinator.pendingDecision == nil)
    }

    @Test func cancellingRejectsLateExecutorResult() async {
        let coordinator = await MainActor.run { VoiceCommandCoordinator() }
        await MainActor.run { coordinator.beginListening() }

        let task = Task { @MainActor in
            await coordinator.submit(
                "What is the weather?",
                context: VoiceCommandContext()
            ) { _, _ in
                try? await Task.sleep(for: .milliseconds(80))
                return VoiceExecutionResult(text: "Late result", providerLabel: "test")
            }
        }

        try? await Task.sleep(for: .milliseconds(10))
        await MainActor.run { coordinator.cancel() }
        let outcome = await task.value

        guard case .cancelled = outcome else {
            Issue.record("A result from the cancelled generation must be discarded")
            return
        }
    }
}
