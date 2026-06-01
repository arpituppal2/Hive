import Foundation
import HiveCore
import XCTest

final class SwarmContextEngineTests: XCTestCase {
    func testAttachmentPipelineRollsBackRemovedDraftAttachment() async throws {
        let draftID = UUID()
        let file = try makeTemporaryTextFile(name: "LongRunning.md", text: "This should never commit.")
        let pipeline = SwarmAttachmentPipeline { url, kind, attachmentID in
            try await Task.sleep(nanoseconds: 2_000_000_000)
            try Task.checkCancellation()
            return SwarmAttachmentExtractionResult(
                id: attachmentID,
                fileURL: url,
                displayName: url.lastPathComponent,
                kind: kind,
                extractedText: "cancelled",
                summary: "cancelled",
                chunks: ["cancelled"],
                tokenEstimate: 3,
                requiresModel: false,
                extractionNote: "fixture"
            )
        }

        let draft = await pipeline.enqueue(url: file, forDraft: draftID)
        let initialSnapshot = await pipeline.snapshot(forDraft: draftID)
        XCTAssertEqual(initialSnapshot.count, 1)

        await pipeline.remove(attachmentID: draft.id, fromDraft: draftID)

        let rolledBackSnapshot = await pipeline.snapshot(forDraft: draftID)
        let committedAfterRollback = await pipeline.commitCompleted(forDraft: draftID)
        XCTAssertTrue(rolledBackSnapshot.isEmpty)
        XCTAssertTrue(committedAfterRollback.isEmpty)
    }

    func testAttachmentPipelineCommitsCompletedExtraction() async throws {
        let draftID = UUID()
        let file = try makeTemporaryTextFile(name: "Resume.md", text: "Resume context with product design and machine learning.")
        let pipeline = SwarmAttachmentPipeline()

        await pipeline.enqueue(url: file, forDraft: draftID)
        let committed = await pipeline.commitCompleted(forDraft: draftID)

        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed[0].displayName, "Resume.md")
        XCTAssertTrue(committed[0].summary.localizedCaseInsensitiveContains("Resume context"))
        XCTAssertFalse(committed[0].chunks.isEmpty)
        let snapshotAfterCommit = await pipeline.snapshot(forDraft: draftID)
        XCTAssertTrue(snapshotAfterCommit.isEmpty)
    }

    func testSelectiveRetrievalShrinksColonyBudgetWhenAttachmentsAreLarge() {
        let profile = SwarmModelProfile(
            id: "test-small-window",
            displayName: "Test",
            maxContextTokens: 900,
            compactionTrigger: 0.8,
            recentTurnsToKeep: 2,
            preferredColonyChunks: 4,
            minimumRelevanceScore: 0.10,
            maximumAttachmentShare: 0.60
        )
        let page = WikiPageRecord(
            id: "resume",
            title: "Resume Leadership",
            markdown: String(repeating: "Resume leadership product design strategy internships portfolio. ", count: 32),
            sourceRefs: [],
            claimRefs: [],
            kind: .topic,
            summary: "Resume leadership and portfolio strategy."
        )
        let irrelevant = WikiPageRecord(
            id: "garden",
            title: "Garden Notes",
            markdown: "Tomatoes, herbs, and irrigation.",
            sourceRefs: [],
            claimRefs: [],
            kind: .topic,
            summary: "Gardening."
        )
        let smallAttachment = SwarmAttachmentExtractionResult(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/small.txt"),
            displayName: "small.txt",
            kind: .text,
            extractedText: "resume",
            summary: "Resume",
            chunks: ["Resume"],
            tokenEstimate: 10,
            requiresModel: false,
            extractionNote: "fixture"
        )
        let massiveAttachment = SwarmAttachmentExtractionResult(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/massive.txt"),
            displayName: "massive.txt",
            kind: .text,
            extractedText: "resume",
            summary: "Resume",
            chunks: [String(repeating: "Resume attachment budget pressure. ", count: 500)],
            tokenEstimate: 2_000,
            requiresModel: false,
            extractionNote: "fixture"
        )
        let retriever = SwarmColonyContextRetriever()

        let smallPlan = retriever.retrieve(
            prompt: "What should I improve in my resume leadership story?",
            attachments: [smallAttachment],
            pages: [page, irrelevant],
            profile: profile
        )
        let massivePlan = retriever.retrieve(
            prompt: "What should I improve in my resume leadership story?",
            attachments: [massiveAttachment],
            pages: [page, irrelevant],
            profile: profile
        )

        XCTAssertFalse(smallPlan.colonyChunks.isEmpty)
        XCTAssertLessThanOrEqual(massivePlan.colonyChunks.count, smallPlan.colonyChunks.count)
        XCTAssertGreaterThan(massivePlan.budget.attachmentTokens, smallPlan.budget.attachmentTokens)
        XCTAssertLessThan(massivePlan.budget.remainingTokens, smallPlan.budget.remainingTokens)
        XCTAssertFalse(smallPlan.colonyChunks.contains { $0.pageID == "garden" })
    }

    func testContextCompactorCreatesMemoryChunkAndPreservesRecentTurns() {
        let profile = SwarmModelProfile(
            id: "test-compact",
            displayName: "Test",
            maxContextTokens: 240,
            compactionTrigger: 0.50,
            recentTurnsToKeep: 2,
            preferredColonyChunks: 2,
            minimumRelevanceScore: 0.10
        )
        let messages = (0..<16).map { index in
            SwarmContextMessage(
                id: "m\(index)",
                role: index.isMultiple(of: 2) ? .user : .assistant,
                text: "Turn \(index) discussed source processing, rollback behavior, and context compaction preferences."
            )
        }
        let plan = SwarmContextPlan(
            modelProfile: profile,
            attachments: [],
            colonyChunks: [],
            budget: SwarmContextBudgetAllocation(
                totalAvailableTokens: profile.maxContextTokens,
                userPromptTokens: 20,
                attachmentTokens: 0,
                colonyTokens: 0,
                recentHistoryTokens: 0,
                remainingTokens: 220
            )
        )

        let result = SwarmContextCompactor().compactIfNeeded(messages: messages, plan: plan, profile: profile)

        XCTAssertTrue(result.didCompact)
        XCTAssertNotNil(result.memoryChunk)
        XCTAssertTrue(result.memoryChunk?.contains("Memory Chunk") == true)
        XCTAssertFalse(result.removedMessageIDs.isEmpty)
        XCTAssertFalse(result.removedMessageIDs.contains("m12"))
        XCTAssertFalse(result.removedMessageIDs.contains("m13"))
        XCTAssertFalse(result.removedMessageIDs.contains("m14"))
        XCTAssertFalse(result.removedMessageIDs.contains("m15"))
        XCTAssertLessThan(result.compactedMessages.count, messages.count + 1)
    }

    private func makeTemporaryTextFile(name: String, text: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HiveSwarmContextEngineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name)
        try text.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
