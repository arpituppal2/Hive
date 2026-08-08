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
