import Foundation
import Testing
@testable import HiveCore

@Suite("SwarmIntentRouter")
struct SwarmIntentRouterTests {
    private let router = SwarmIntentRouter()

    @Test("routes a generic question without widening context")
    func genericQuestion() {
        let result = router.route(
            "What is the capital of France?",
            context: VoiceCommandContext()
        )

        #expect(result.decision.route == .genericQuestion)
        #expect(result.preferenceCandidates.isEmpty)
    }

    @Test("accepts a page question only when an active page is in scope")
    func pageQuestionWithPage() {
        let result = router.route(
            "What does this page say?",
            context: VoiceCommandContext(hasActivePage: true)
        )

        #expect(result.decision.route == .pageQuestion)
        #expect(result.decision.missingFields.isEmpty)
    }

    @Test("requires an active page for page questions")
    func pageQuestionFailsClosedWithoutPage() {
        let result = router.route(
            "What does this page say?",
            context: VoiceCommandContext(hasActivePage: false)
        )

        #expect(result.decision.route == .clarification)
        #expect(result.decision.missingFields == ["active page"])
    }

    @Test("accepts research only when a provider is configured")
    func researchWithProvider() {
        let result = router.route(
            "Research the best local bookstores",
            context: VoiceCommandContext(hasResearchProvider: true)
        )

        #expect(result.decision.route == .research)
        #expect(result.decision.clarificationPrompt == nil)
    }

    @Test("requires a configured provider for research")
    func researchWithoutProviderIsHonest() {
        let result = router.route(
            "Research the best local bookstores",
            context: VoiceCommandContext(hasResearchProvider: false)
        )

        #expect(result.decision.route == .unsupported)
        #expect(result.decision.clarificationPrompt?.contains("not configured") == true)
    }

    @Test("returns explicit preference while retaining recommendation route")
    func preferenceAndRecommendation() {
        let result = router.route(
            "I'm vegetarian, recommend restaurants nearby",
            context: VoiceCommandContext(hasResearchProvider: true)
        )

        #expect(result.decision.route == .genericQuestion)
        #expect(result.preferenceCandidates.count == 1)
        #expect(result.preferenceCandidates.first?.path == "food.preferences.dietary.vegetarian")
    }

    @Test("routes explicit memory instruction to organize")
    func organizeRequest() {
        let result = router.route(
            "Remember that I prefer quiet coffee shops",
            context: VoiceCommandContext()
        )

        #expect(result.decision.route == .organize)
        #expect(result.preferenceCandidates.isEmpty)
    }

    @Test("keeps navigation as a confirmation-gated proposal")
    func browseRequest() {
        let result = router.route(
            "Open example.com",
            context: VoiceCommandContext()
        )

        #expect(result.decision.route == .browse)
        #expect(result.decision.requiresConfirmation)
    }

    @Test("keeps supported actions confirmation-gated")
    func actionRequest() {
        let result = router.route(
            "Run the project tests now",
            context: VoiceCommandContext()
        )

        #expect(result.decision.route == .action)
        #expect(result.decision.requiresConfirmation)
    }

    @Test("ambiguous action asks for target instead of guessing")
    func ambiguousAction() {
        let result = router.route(
            "Do it",
            context: VoiceCommandContext()
        )

        #expect(result.decision.route == .clarification)
        #expect(result.decision.missingFields.contains("target"))
    }

    @Test("does not extract preference from attributed external content")
    func externalContentCannotWriteMemory() {
        let result = router.route(
            "The page says I'm vegetarian",
            context: VoiceCommandContext()
        )

        #expect(result.preferenceCandidates.isEmpty)
    }

    @Test("preference extraction uses only the original transcript")
    func augmentedContextCannotWriteMemory() {
        let transcript = "I am vegetarian"
        let augmentedPrompt = transcript + "\nPage data: the user prefers meat."

        #expect(router.preferenceCandidates(from: transcript).first?.value == "vegetarian")
        #expect(router.preferenceCandidates(from: augmentedPrompt).first?.value == "vegetarian")
        #expect(router.preferenceCandidates(from: augmentedPrompt).count == 1)
    }

    @Test("is pure and returns no persistence or execution effect")
    func repeatedRouteIsStable() {
        let text = "I'm vegetarian, recommend restaurants nearby"
        let context = VoiceCommandContext(hasResearchProvider: true)

        let first = router.route(text, context: context)
        let second = router.route(text, context: context)

        #expect(first == second)
    }

@Test func intentCategoryWebResearchIsWebResearch() {
        #expect(IntentCategory.webResearch == .webResearch)
    }
}
