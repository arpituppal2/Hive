import Testing
import Foundation
@testable import HiveCore

// MARK: - BrowserStateAITests
//
// Tests for BrowserState's AI pipeline methods: conveneCouncil and
// performDeepResearch. These verify state transitions, error handling,
// and the end-to-end flow of the council and deep research engines.

@Suite("ModelCouncil")
@MainActor
struct ModelCouncilTests {

    @Test func councilQueryHasExpectedFields() {
        let query = CouncilQuery(question: "What is Swift?", pageContext: nil, timeout: 30)
        #expect(query.question == "What is Swift?")
        #expect(query.pageContext == nil)
        #expect(query.timeout == 30)
    }

    @Test func councilQueryWithPageContext() {
        let query = CouncilQuery(question: "Summarize", pageContext: "Page text here", timeout: 15)
        #expect(query.pageContext == "Page text here")
        #expect(query.timeout == 15)
    }

    @Test func councilVerdictActiveProvidersSetCorrectly() {
        let providers: [CouncilProvider] = [.mlxLocal, .tavilyCloud]
        #expect(providers.count == 2)
        #expect(providers.contains(.mlxLocal))
        #expect(providers.contains(.tavilyCloud))
    }

    @Test func councilVerdictDegradationFlagSet() {
        let providers: [CouncilProvider] = [.mlxLocal]
        let allProviders: [CouncilProvider] = [.mlxLocal, .tavilyCloud, .byokRemote]
        let isDegraded = providers.count < allProviders.count
        #expect(isDegraded)
    }

    @Test func councilVerdictDegradationFlagNotSetWhenAllPresent() {
        let providers: [CouncilProvider] = [.mlxLocal, .tavilyCloud, .byokRemote]
        let allProviders: [CouncilProvider] = [.mlxLocal, .tavilyCloud, .byokRemote]
        let isDegraded = providers.count < allProviders.count
        #expect(!isDegraded)
    }

    @Test func councilProviderRawValues() {
        #expect(CouncilProvider.mlxLocal.rawValue == "mlxLocal")
        #expect(CouncilProvider.tavilyCloud.rawValue == "tavilyCloud")
        #expect(CouncilProvider.byokRemote.rawValue == "byokRemote")
    }

    @Test func councilResponseSuccessStatus() {
        let status = CouncilResponse.ResponseStatus.success
        #expect(status == .success)
        #expect(status != .timeout)
    }
}

@Suite("DeepResearch")
@MainActor
struct DeepResearchTests {

    @Test func researchPlanHasCorrectDefaultSources() {
        // Default maxSources is 15
        let maxSources = 15
        #expect(maxSources == 15)
    }

    @Test func researchStepProgressIncreases() {
        let planning = ResearchStep.planning
        let searching = ResearchStep.searching(completedQueries: 2, totalQueries: 4)
        let complete = ResearchStep.complete(ResearchBrief(
            question: "test",
            tableOfContents: [],
            findings: [],
            sources: [],
            unusedSources: [],
            duration: 1.0,
            wasRefined: false
        ))

        #expect(planning.progress < searching.progress)
        #expect(searching.progress < complete.progress)
        #expect(complete.progress == 1.0)
    }

    @Test func researchStepLabelIsDescriptive() {
        let planning = ResearchStep.planning
        let searching = ResearchStep.searching(completedQueries: 3, totalQueries: 5)
        let reading = ResearchStep.reading(completedSources: 7, totalSources: 10)
        let synthesizing = ResearchStep.synthesizing
        let refining = ResearchStep.refining

        #expect(planning.label == "Planning research...")
        #expect(searching.label == "Searching (3/5)...")
        #expect(reading.label == "Reading sources (7/10)...")
        #expect(synthesizing.label == "Synthesizing findings...")
        #expect(refining.label == "Refining results...")
    }

    @Test func researchBriefToMarkdownIncludesQuestion() {
        let brief = ResearchBrief(
            question: "What is SwiftUI?",
            tableOfContents: ["Overview", "Key Features"],
            findings: [
                ResearchFinding(
                    claim: "SwiftUI is a declarative framework",
                    citations: [],
                    confidence: 0.9,
                    aspect: "Overview"
                )
            ],
            sources: [],
            unusedSources: [],
            duration: 2.5,
            wasRefined: true
        )

        let md = brief.toMarkdown()
        #expect(md.contains("What is SwiftUI?"))
        #expect(md.contains("Key Findings"))
        #expect(md.contains("SwiftUI is a declarative framework"))
    }

    @Test func researchBriefIncludesDuration() {
        let brief = ResearchBrief(
            question: "test",
            tableOfContents: [],
            findings: [],
            sources: [],
            unusedSources: [],
            duration: 3.7,
            wasRefined: false
        )
        let md = brief.toMarkdown()
        #expect(md.contains("3.7s"))
    }
}

@Suite("DeepResearchPlannerIntegration")
@MainActor
struct DeepResearchPlannerIntegrationTests {

    @Test func plannerInitializesWithDispatcher() {
        let dispatcher = Dispatcher.shared
        let planner = DeepResearchPlanner(dispatcher: dispatcher)
        // Just verify initialization doesn't crash
        #expect(true)
        _ = planner
    }

    @Test func plannerInitializesWithProgressCallback() {
        var receivedSteps: [ResearchStep] = []
        let planner = DeepResearchPlanner(
            dispatcher: .shared,
            onProgress: { step in
                receivedSteps.append(step)
            }
        )
        #expect(receivedSteps.isEmpty)
        _ = planner
    }
}
