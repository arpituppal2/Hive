import Testing
@testable import HiveCore

@Suite("SwarmResponseContract")
struct SwarmResponseContractTests {
    @Test("text and voice adapters preserve the same user intent and tab scope")
    func textAndVoiceInputsStayEquivalent() {
        let intent = "What are the key points?"
        let tabs: Set<String> = ["tab-a", "tab-b"]
        let text = SwarmResponseRequest.text(
            intent: intent,
            explicitTabIDs: tabs
        )
        let voice = SwarmResponseRequest.voice(
            route: .genericQuestion,
            intent: intent,
            explicitTabIDs: tabs
        )

        #expect(text.intent == voice.intent)
        #expect(text.explicitTabIDs == voice.explicitTabIDs)
        #expect(text.route == .genericQuestion)
        #expect(voice.route == .genericQuestion)
        #expect(text.role == .summarizer)
        #expect(voice.role == .summarizer)
    }

    @Test("page questions select the page QA role without widening scope")
    func pageQuestionsUsePageRole() {
        let request = SwarmResponseRequest.voice(
            route: .pageQuestion,
            intent: "What does this page explain?",
            explicitTabIDs: ["active-tab"]
        )

        #expect(request.route == .pageQuestion)
        #expect(request.role == .pageQa)
        #expect(request.explicitTabIDs == ["active-tab"])
    }

    @Test("contract contains only user input and explicit tab references")
    func contractContainsOnlyUserInputAndExplicitReferences() {
        let request = SwarmResponseRequest.text(
            intent: "Remember this preference",
            maxTokens: 256,
            explicitTabIDs: ["tab-a"]
        )

        #expect(request.intent == "Remember this preference")
        #expect(request.explicitTabIDs == ["tab-a"])
        #expect(request.maxTokens == 256)
    }

    @Test("route set remains limited to advisory question paths")
    func routesRemainNarrow() {
        #expect(SwarmResponseRoute.allCases == [.genericQuestion, .pageQuestion])
    }
}
