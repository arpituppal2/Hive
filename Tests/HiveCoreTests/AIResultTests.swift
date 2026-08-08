import Testing
import Foundation
@testable import HiveCore

// MARK: - AIResultTests

struct AIResultTests {

    @Test func loadingStateHasNoValue() {
        let result: AIResult<String> = .loading(progress: 0.5)
        #expect(result.value == nil)
        #expect(result.isInProgress)
        #expect(result.stateID == "loading")
    }

    @Test func partialStateHasValue() {
        let result: AIResult<String> = .partial("partial answer", remainingProviders: 2)
        #expect(result.value == "partial answer")
        #expect(result.isInProgress)
        #expect(result.stateID == "partial")
    }

    @Test func successStateHasValue() {
        let result: AIResult<String> = .success("complete")
        #expect(result.value == "complete")
        #expect(!result.isInProgress)
    }

    @Test func errorStateHasNoValue() {
        let error = AIError(title: "Test", message: "Failed", recoveryLabel: "Retry")
        let result: AIResult<String> = .error(error)
        #expect(result.value == nil)
        #expect(!result.isInProgress)
    }

    @Test func degradedStateHasValueAndExplanation() {
        let result: AIResult<String> = .degraded("answer", explanation: "2 of 3 models responded")
        #expect(result.value == "answer")
        #expect(!result.isInProgress)
    }

    @Test func emptyStateHasNoValue() {
        let result: AIResult<String> = .empty
        #expect(result.value == nil)
        #expect(!result.isInProgress)
    }

    @Test func aiErrorTimeoutHasCorrectFormat() {
        let error = AIError.timeout(provider: "MLX Local")
        #expect(error.title.contains("timed out"))
        #expect(!error.message.isEmpty)
    }

    @Test func aiErrorNetworkHasCorrectFormat() {
        let error = AIError.networkError(provider: "Tavily")
        #expect(error.title == "Network error")
        #expect(!error.message.isEmpty)
    }

    @Test func aiErrorNoResultsHasCorrectFormat() {
        let error = AIError.noResults(query: "test query")
        #expect(error.title == "No results found")
        #expect(error.message.contains("test query"))
    }
}
