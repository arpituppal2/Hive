import Testing
@testable import HiveCore

@Suite("SwarmResearchPresentation")
struct SwarmResearchPresentationTests {
    @Test func runningEmptyStateIsLoadingAndNotTerminal() {
        let presentation = SwarmResearchState().presentation

        #expect(presentation.phase == .running)
        #expect(presentation.content.isEmpty)
        #expect(presentation.sources.isEmpty)
        #expect(presentation.isLoading)
        #expect(!presentation.isTerminal)
    }

    @Test func runningAnswerPreservesContentAndStopsLoading() {
        var state = SwarmResearchState()
        state.apply(.answerChunk("Partial answer"))

        let presentation = state.presentation

        #expect(presentation.content == "Partial answer")
        #expect(!presentation.isLoading)
        #expect(!presentation.isTerminal)
    }

    @Test func completedStateUsesRenderedContentAndSources() {
        var state = SwarmResearchState()
        let source = WebSearchSource(title: "Docs", url: "https://example.com/docs")
        state.apply(.answerChunk("Answer"))
        state.complete(with: WebSearchResult(answer: "ignored duplicate", sources: [source]))

        let presentation = state.presentation

        #expect(presentation.phase == .completed)
        #expect(presentation.content == "Answer")
        #expect(presentation.sources == [source])
        #expect(!presentation.isLoading)
        #expect(presentation.isTerminal)
    }

    @Test func cancelledStateKeepsPartialAnswerAndExplainsStop() {
        var state = SwarmResearchState()
        state.apply(.answerChunk("Partial"))
        state.cancel()

        let presentation = state.presentation

        #expect(presentation.phase == .cancelled)
        #expect(presentation.content.contains("Partial"))
        #expect(presentation.content.contains("stopped"))
        #expect(presentation.isTerminal)
    }

    @Test func failedEmptyStateHasHonestFallback() {
        var state = SwarmResearchState()
        state.fail()

        let presentation = state.presentation

        #expect(presentation.phase == .failed)
        #expect(presentation.content == "Couldn't complete web search.")
        #expect(presentation.isTerminal)
    }

    @Test func sourceIdentityRemainsValidatedByReducer() {
        var state = SwarmResearchState()
        let valid = WebSearchSource(title: "Valid", url: "https://example.com")
        let invalid = WebSearchSource(title: "Invalid", url: "javascript:alert(1)")
        state.apply(.sources([valid, invalid]))

        #expect(state.presentation.sources == [valid])
    }
}
