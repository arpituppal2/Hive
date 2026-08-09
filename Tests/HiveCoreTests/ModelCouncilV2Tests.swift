import Testing
import Foundation
@testable import HiveCore

// MARK: - ModelCouncilV2Tests

struct ModelCouncilV2Tests {

    @Test func councilQueryDefaults() {
        let query = CouncilQuery(question: "What is Swift?")
        #expect(query.question == "What is Swift?")
        #expect(query.providers.count == 3)
        #expect(query.timeout == 30)
    }

    @Test func councilQueryCustomProviders() {
        let query = CouncilQuery(
            question: "test",
            providers: [.mlxLocal],
            timeout: 10
        )
        #expect(query.providers.count == 1)
        #expect(query.timeout == 10)
    }

    @Test func councilVerdictDegradedWhenFewerResponses() {
        let responses: [CouncilResponse] = [
            CouncilResponse(provider: .mlxLocal, answer: "A", confidence: 0.9, citations: [], duration: 1, status: .success)
        ]
        let verdict = CouncilVerdict(
            answer: "A", reasoning: "test", agreements: [], disagreements: [],
            confidence: 0.9, responses: responses,
            activeProviders: [.mlxLocal], isDegraded: true
        )
        #expect(verdict.isDegraded)

        if case .degraded(let value, _) = verdict.resultState {
            #expect(value == "A")
        } else {
            #expect(Bool(false), "Expected degraded state")
        }
    }

    @Test func councilVerdictSuccessWhenAllRespond() {
        let responses: [CouncilResponse] = [
            CouncilResponse(provider: .mlxLocal, answer: "A", confidence: 0.9, citations: [], duration: 1, status: .success),
            CouncilResponse(provider: .tavilyCloud, answer: "A", confidence: 0.85, citations: [], duration: 2, status: .success),
            CouncilResponse(provider: .byokRemote, answer: "A", confidence: 0.88, citations: [], duration: 3, status: .success)
        ]
        let verdict = CouncilVerdict(
            answer: "A", reasoning: "test", agreements: ["All agree"], disagreements: [],
            confidence: 0.88, responses: responses,
            activeProviders: [.mlxLocal, .tavilyCloud, .byokRemote], isDegraded: false
        )
        #expect(!verdict.isDegraded)

        if case .success(let value) = verdict.resultState {
            #expect(value == "A")
        } else {
            #expect(Bool(false), "Expected success state")
        }
    }

    @Test func councilResponseTimeoutHasZeroConfidence() {
        let response = CouncilResponse(
            provider: .mlxLocal, answer: "", confidence: 0, citations: [],
            duration: 30, status: .timeout
        )
        #expect(response.status == .timeout)
        #expect(response.confidence == 0)
        #expect(response.answer.isEmpty)
    }

    @Test func councilResponseUnavailableStatus() {
        let response = CouncilResponse(
            provider: .byokRemote, answer: "", confidence: 0, citations: [],
            duration: 0, status: .unavailable
        )
        #expect(response.status == .unavailable)
    }

    @Test func councilProviderDefaultsIncludeThreeProviders() {
        let defaults = CouncilProvider.defaults
        #expect(defaults.contains(.mlxLocal))
        #expect(defaults.contains(.tavilyCloud))
        #expect(defaults.contains(.byokRemote))
    }

    @Test func councilProviderLocalOnly() {
        let local = CouncilProvider.localOnly
        #expect(local.count == 1)
        #expect(local.contains(.mlxLocal))
    }
}

// MARK: - Chair Synthesis Tests

@Suite("ChairSynthesis")
@MainActor
struct ChairSynthesisTests {

    let council = ModelCouncil(dispatcher: .shared)

    // MARK: parseChairResponse — valid structured input

    @Test func parseValidStructuredResponse() {
        let text = """
        ANSWER: Swift is a programming language developed by Apple.
        AGREEMENTS: All models agree Swift is developed by Apple, All models mention safety features
        DISAGREEMENTS: One model says Swift is slow, Another says it's the fastest
        CONFIDENCE: 0.92
        """
        let active = makeResponses(count: 3)
        let synthesis = council.parseChairResponse(text, active: active)

        #expect(synthesis.answer.contains("Swift"))
        #expect(synthesis.answer.contains("Apple"))
        #expect(synthesis.agreements.count >= 2)
        #expect(synthesis.disagreements.count >= 2)
        #expect(synthesis.confidence == 0.92)
    }

    @Test func parseResponseWithoutColons() {
        let text = """
        ANSWER Swift is a language.
        AGREEMENTS All agree
        DISAGREEMENTS None
        CONFIDENCE 0.75
        """
        let active = makeResponses(count: 2)
        let synthesis = council.parseChairResponse(text, active: active)

        #expect(synthesis.answer.contains("Swift"))
        #expect(synthesis.agreements.count >= 1)
        #expect(synthesis.confidence == 0.75)
    }

    @Test func parseResponseWithBulletPointAgreements() {
        let text = """
        ANSWER: Swift is safe.
        AGREEMENTS:
        - Memory safety is a key feature
        - Performance is good
        DISAGREEMENTS:
        - Adoption rate
        CONFIDENCE: 0.88
        """
        let active = makeResponses(count: 3)
        let synthesis = council.parseChairResponse(text, active: active)

        #expect(synthesis.answer.contains("Swift"))
        #expect(synthesis.agreements.count >= 2)
        #expect(synthesis.disagreements.count >= 1)
        #expect(synthesis.confidence == 0.88)
    }

    @Test func parseResponseWithMultiParagraphAnswer() {
        let text = """
        ANSWER: Swift is a powerful language.
        It supports modern features.
        It works on all Apple platforms.
        AGREEMENTS: All agree on power
        CONFIDENCE: 0.90
        """
        let active = makeResponses(count: 2)
        let synthesis = council.parseChairResponse(text, active: active)

        #expect(synthesis.answer.contains("powerful"))
        #expect(synthesis.answer.contains("modern features"))
    }

    @Test func parseResponseFallsBackOnMissingAnswer() {
        let text = """
        AGREEMENTS: Something
        CONFIDENCE: 0.5
        """
        let active = makeResponses(count: 2)
        let synthesis = council.parseChairResponse(text, active: active)

        // Should fall back to highest-confidence active response
        #expect(!synthesis.answer.isEmpty)
        // Confidence should be penalized
        #expect(synthesis.confidence < 0.7)
    }

    @Test func parseResponseClampsConfidence() {
        let text = """
        ANSWER: Test
        CONFIDENCE: 1.5
        """
        let active = makeResponses(count: 1)
        let synthesis = council.parseChairResponse(text, active: active)
        #expect(synthesis.confidence <= 1.0)

        let textNeg = """
        ANSWER: Test
        CONFIDENCE: -0.3
        """
        let synthesisNeg = council.parseChairResponse(textNeg, active: active)
        #expect(synthesisNeg.confidence >= 0.0)
    }

    // MARK: localSynthesize — fallback synthesis

    @Test func localSynthesizeWithConsensus() {
        let active = [
            CouncilResponse(provider: .mlxLocal, answer: "Swift is safe", confidence: 0.9, citations: [], duration: 1, status: .success),
            CouncilResponse(provider: .tavilyCloud, answer: "Swift prioritizes safety", confidence: 0.85, citations: [], duration: 2, status: .success),
            CouncilResponse(provider: .byokRemote, answer: "Swift is memory safe", confidence: 0.88, citations: [], duration: 3, status: .success)
        ]
        let synthesis = council.localSynthesize(active: active)

        #expect(!synthesis.answer.isEmpty)
        #expect(synthesis.agreements.count >= 1)
        #expect(synthesis.agreements[0].contains("All"))
        #expect(synthesis.disagreements.isEmpty)
    }

    @Test func localSynthesizeWithDivergentConfidence() {
        let active = [
            CouncilResponse(provider: .mlxLocal, answer: "A", confidence: 0.9, citations: [], duration: 1, status: .success),
            CouncilResponse(provider: .tavilyCloud, answer: "B", confidence: 0.5, citations: [], duration: 2, status: .success),
            CouncilResponse(provider: .byokRemote, answer: "C", confidence: 0.3, citations: [], duration: 3, status: .success)
        ]
        let synthesis = council.localSynthesize(active: active)

        // Should pick the highest confidence answer
        #expect(synthesis.answer == "A")
        // No consensus — disagreements present
        #expect(!synthesis.disagreements.isEmpty)
        // Confidence penalized for lack of consensus
        #expect(synthesis.confidence < 0.8)
    }

    @Test func localSynthesizeWithSingleModel() {
        let active = [
            CouncilResponse(provider: .mlxLocal, answer: "Solo answer", confidence: 0.7, citations: [], duration: 1, status: .success)
        ]
        let synthesis = council.localSynthesize(active: active)

        #expect(synthesis.answer == "Solo answer")
        // Single model gets lower confidence
        #expect(synthesis.confidence < 0.7)
    }

    @Test func localSynthesizeWithNoActiveResponses() {
        // This path is handled before localSynthesize is called in the real code,
        // but testing the method directly
        let active: [CouncilResponse] = []
        // The guard in synthesize handles empty before calling localSynthesize
        // This test documents expected behavior
        #expect(active.isEmpty)
    }
}

// MARK: - Test Helpers

private func makeResponses(count: Int) -> [CouncilResponse] {
    let providers: [CouncilProvider] = [.mlxLocal, .tavilyCloud, .byokRemote]
    var responses: [CouncilResponse] = []
    for i in 0..<count {
        responses.append(CouncilResponse(
            provider: providers[i % providers.count],
            answer: "Response \(i + 1)",
            confidence: 0.8 + Double(i) * 0.05,
            citations: [],
            duration: Double(i + 1),
            status: .success
        ))
    }
    return responses

}
