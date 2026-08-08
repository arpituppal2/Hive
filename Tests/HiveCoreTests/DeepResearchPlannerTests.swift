import Testing
import Foundation
@testable import HiveCore

// MARK: - DeepResearchPlannerTests

struct DeepResearchPlannerTests {

    @Test func researchPlanHasSubQueries() {
        let plan = ResearchPlan(
            question: "What is Swift?",
            subQueries: [
                ResearchQuery(query: "Swift language history", aspect: "History", priority: 1),
                ResearchQuery(query: "Swift features", aspect: "Features", priority: 1),
                ResearchQuery(query: "Swift adoption", aspect: "Adoption", priority: 2)
            ],
            sourcesPerQuery: 5,
            maxSources: 15,
            refineResults: true
        )
        #expect(plan.subQueries.count == 3)
        #expect(plan.refineResults)
        #expect(plan.maxSources == 15)
    }

    @Test func researchBriefRendersMarkdown() {
        let sources = [ResearchSource(
            url: URL(string: "https://example.com")!,
            title: "Example",
            snippet: "Test",
            fullText: nil,
            relevance: 0.9,
            sourceQueryID: UUID()
        )]
        let finding = ResearchFinding(
            claim: "Swift is a programming language.",
            citations: sources,
            confidence: 0.85,
            aspect: "Overview"
        )
        let brief = ResearchBrief(
            question: "What is Swift?",
            tableOfContents: ["Overview"],
            findings: [finding],
            sources: sources,
            unusedSources: [],
            duration: 3.5,
            wasRefined: false
        )

        let md = brief.toMarkdown()
        #expect(md.contains("What is Swift?"))
        #expect(md.contains("Swift is a programming language"))
        #expect(md.contains("example.com"))
    }

    @Test func researchSourceRelevanceSorted() {
        let s1 = ResearchSource(url: URL(string: "https://a.com")!, title: "A", snippet: "", fullText: nil, relevance: 0.7, sourceQueryID: UUID())
        let s2 = ResearchSource(url: URL(string: "https://b.com")!, title: "B", snippet: "", fullText: nil, relevance: 0.95, sourceQueryID: UUID())
        let s3 = ResearchSource(url: URL(string: "https://c.com")!, title: "C", snippet: "", fullText: nil, relevance: 0.5, sourceQueryID: UUID())

        let sorted = [s1, s2, s3].sorted { $0.relevance > $1.relevance }
        #expect(sorted[0].title == "B")
        #expect(sorted[1].title == "A")
        #expect(sorted[2].title == "C")
    }

    @Test func researchStepProgressIncreases() {
        let steps: [ResearchStep] = [
            .planning,
            .searching(completedQueries: 1, totalQueries: 3),
            .searching(completedQueries: 3, totalQueries: 3),
            .reading(completedSources: 5, totalSources: 10),
            .reading(completedSources: 10, totalSources: 10),
            .synthesizing,
            .refining,
            .complete(ResearchBrief(question: "", tableOfContents: [], findings: [], sources: [], unusedSources: [], duration: 0, wasRefined: false))
        ]

        var lastProgress = 0.0
        for step in steps {
            #expect(step.progress >= lastProgress)
            lastProgress = step.progress
        }
        #expect(steps.last!.progress == 1.0)
    }

    @Test func researchQueryPriorityDefaults() {
        let high = ResearchQuery(query: "test", aspect: "Critical", priority: 1)
        let medium = ResearchQuery(query: "test", aspect: "Important", priority: 2)
        let low = ResearchQuery(query: "test", aspect: "Supplementary", priority: 3)

        #expect(high.priority < medium.priority)
        #expect(medium.priority < low.priority)
    }
}
