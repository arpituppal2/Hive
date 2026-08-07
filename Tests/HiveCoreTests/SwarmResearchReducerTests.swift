import Testing
@testable import HiveCore

@Suite("SwarmResearchReducer")
struct SwarmResearchReducerTests {
    @Test func accumulatesSourcesChunksNoticesAndRelatedQuestions() {
        var state = SwarmResearchState()
        let source = WebSearchSource(id: "one", title: "One", url: "HTTPS://Example.com/page")
        state.apply(.sources([source]))
        state.apply(.answerChunk("A "))
        state.apply(.answerChunk("result."))
        state.apply(.error("Rate limited briefly"))
        state.apply(.relatedQuestions(["What next?", "What next?", " "]))

        #expect(state.phase == .running)
        #expect(state.answer == "A result.")
        #expect(state.sources == [source])
        #expect(state.providerNotices == ["Rate limited briefly"])
        #expect(state.relatedQuestions == ["What next?"])
        #expect(state.renderedText.contains("A result."))
        #expect(state.renderedText.contains("[Provider notice: Rate limited briefly]"))
        #expect(state.renderedText.contains("**Related**"))
    }

    @Test func deduplicatesSourcesByCanonicalURLAndPreservesFirstOrder() {
        var state = SwarmResearchState()
        let first = WebSearchSource(id: "first", title: "First", url: "https://EXAMPLE.com/a")
        let duplicate = WebSearchSource(id: "duplicate", title: "Duplicate", url: " HTTPS://example.COM/a ")
        let caseSensitivePath = WebSearchSource(id: "case", title: "Case", url: "https://example.com/A")
        let second = WebSearchSource(id: "second", title: "Second", url: "https://example.com/b")

        state.apply(.sources([first, duplicate, caseSensitivePath]))
        state.apply(.sources([second, first]))

        #expect(state.sources.map(\.id) == ["first", "case", "second"])
    }

    @Test func ignoresInvalidSourceURLsForDurableCitationState() {
        var state = SwarmResearchState()
        state.apply(.sources([
            WebSearchSource(id: "invalid", title: "Invalid", url: "not a URL"),
            WebSearchSource(id: "valid", title: "Valid", url: "https://example.com")
        ]))

        #expect(state.sources.map(\.id) == ["valid"])
    }

    @Test func completionUsesFinalResultOnlyToFillMissingFields() {
        var state = SwarmResearchState()
        let source = WebSearchSource(id: "one", title: "One", url: "https://example.com")
        state.apply(.answerChunk("Streamed answer"))
        state.complete(with: WebSearchResult(
            answer: "Duplicate final answer",
            sources: [source],
            relatedQuestions: ["Follow up?"]
        ))

        #expect(state.phase == .completed)
        #expect(state.answer == "Streamed answer")
        #expect(state.sources == [source])
        #expect(state.relatedQuestions == ["Follow up?"])
    }

    @Test func terminalStateIgnoresLateProviderEvents() {
        var state = SwarmResearchState()
        state.complete(with: WebSearchResult(answer: "Done"))
        state.apply(.answerChunk(" late"))
        state.apply(.error("late failure"))
        state.cancel()
        state.fail("late failure")

        #expect(state.phase == .completed)
        #expect(state.answer == "Done")
        #expect(state.providerNotices.isEmpty)
    }

    @Test func cancellationAndFailureAreDistinctTerminalStates() {
        var cancelled = SwarmResearchState()
        cancelled.cancel()
        cancelled.apply(.answerChunk("late"))

        var failed = SwarmResearchState()
        failed.fail("network unavailable")

        #expect(cancelled.phase == .cancelled)
        #expect(cancelled.answer.isEmpty)
        #expect(failed.phase == .failed)
        #expect(failed.providerNotices == ["network unavailable"])
    }
}
