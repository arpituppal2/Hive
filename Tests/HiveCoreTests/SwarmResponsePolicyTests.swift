import Testing
@testable import HiveCore

@Suite("SwarmResponsePolicy")
struct SwarmResponsePolicyTests {
    @Test("cancellation drops the response instead of mutating the UI")
    func cancellationDrops() {
        #expect(
            SwarmResponsePolicy.resolution(
                responseIsCurrent: true,
                taskIsCancelled: true,
                transitionIsCurrent: true
            ) == .drop
        )
    }

    @Test("superseded browser context becomes an explicit context change")
    func staleContextIsExplicit() {
        #expect(
            SwarmResponsePolicy.resolution(
                responseIsCurrent: true,
                taskIsCancelled: false,
                transitionIsCurrent: false
            ) == .contextChanged
        )
    }

    @Test("current response is eligible for application")
    func currentResponseApplies() {
        #expect(
            SwarmResponsePolicy.resolution(
                responseIsCurrent: true,
                taskIsCancelled: false,
                transitionIsCurrent: true
            ) == .apply
        )
    }

    @Test("diagnostics preserve provider, context, timing, and page provenance")
    func diagnosticsPreserveEvidence() {
        let generated = GenerateResult(
            role: .summarizer,
            provider: .mock,
            text: "Answer",
            latencyMS: 42,
            tokensGenerated: 2,
            modelLabel: "mock-model"
        )
        let orchestration = OrchestrationResult(
            text: generated.text,
            provider: generated.provider,
            modelLabel: generated.modelLabel,
            contextNodeCount: 3,
            contextSummary: "3 scoped nodes",
            rankerProvider: "rule-ranker",
            durationMS: 42
        )
        let diagnostics = SwarmResponsePolicy.diagnostics(
            for: orchestration,
            pageSummary: "page title redacted",
            pageTitle: "Example",
            pageHost: "example.com"
        )

        #expect(diagnostics.providerLabel == "mock")
        #expect(diagnostics.contextNodeCount == 3)
        #expect(diagnostics.contextSummary.contains("3 scoped nodes"))
        #expect(diagnostics.contextSummary.contains("page title redacted"))
        #expect(diagnostics.rankerProvider == "rule-ranker")
        #expect(diagnostics.durationMS == 42)
        #expect(diagnostics.pageTitle == "Example")
        #expect(diagnostics.pageHost == "example.com")
    }
}
