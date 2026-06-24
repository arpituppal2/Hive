import XCTest
import Foundation
import SwiftUI
import HiveCore
import HiveDesignSystem
import HiveMetalRenderer
import HiveUI
import HiveWidgets
import HiveMobileApp
import HiveWatchApp

final class HiveRebuildTests: XCTestCase {
    func testStatusTranslationUsesOrganismLanguage() {
        XCTAssertEqual(SourcePresentationModel.status(for: .queued), .resting)
        XCTAssertEqual(SourcePresentationModel.status(for: .extracting), .digesting)
        XCTAssertEqual(SourcePresentationModel.status(for: .needsReview), .synthesizing)
        XCTAssertEqual(SourcePresentationModel.status(for: .failed), .confused)
        XCTAssertEqual(SourcePresentationModel.status(for: .extracted), .understood)
    }

    func testConfidenceLanguageNeverEmitsPercentages() throws {
        for value in stride(from: 0.0, through: 1.0, by: 0.05) {
            let phrase = SourcePresentationModel.confidenceLanguage(value)
            XCTAssertFalse(phrase.contains("%"))
            XCTAssertFalse(phrase.localizedCaseInsensitiveContains("confidence"))
        }
        XCTAssertFalse(HiveStatusTranslator.confidencePhrase(0.82, evidenceCount: 3).contains("%"))
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let reviewQueue = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/ReviewQueue.swift"))
        let graph = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))
        XCTAssertFalse(reviewQueue.contains("% sure"))
        XCTAssertFalse(reviewQueue.contains("below 70%"))
        XCTAssertFalse(graph.contains("timeWindow * 100"))
        XCTAssertFalse(graph.contains("@State private var timeWindow"))
        XCTAssertFalse(graph.contains("graphTimeCutoff"))
        XCTAssertFalse(graph.contains("runTimelapse()"))
        XCTAssertFalse(graph.contains("timeScrubber"))
        XCTAssertFalse(graph.contains("Hive time window"))
    }

    func testSourcePresentationStripsTechnicalFilenames() {
        let source = SourceRecord(
            kind: .genericFile,
            uri: "file:///tmp/safari-history-2026-05-24.db",
            title: "safari-history-2026-05-24.db",
            mimeType: "application/octet-stream",
            sizeBytes: 1,
            sha256: "hash",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        let presented = SourcePresentationModel(source: source)
        XCTAssertFalse(presented.title.contains("."))
        XCTAssertFalse(presented.title.localizedCaseInsensitiveContains("json"))
        XCTAssertFalse(presented.title.localizedCaseInsensitiveContains("sqlite"))

        let quickThought = SourceRecord(
            kind: .text,
            uri: "local://thought",
            title: "Quick Thought 2026 05 26 18.23.09",
            mimeType: "text/plain",
            sizeBytes: 1,
            sha256: "hash-2",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        XCTAssertEqual(SourcePresentationModel(source: quickThought).title, "Quick thought")

        let urlSource = SourceRecord(
            kind: .browserHistory,
            uri: "https://www.example.com/path?q=1",
            title: "https://www.example.com/path?q=1",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "hash-3",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        XCTAssertEqual(SourcePresentationModel(source: urlSource).title, "Browsing trail")

        let bareDomainSource = SourceRecord(
            kind: .browserHistory,
            uri: "local://browser-capture",
            title: "accounts.google.com",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "hash-3b",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        XCTAssertEqual(SourcePresentationModel(source: bareDomainSource).title, "Browsing trail")

        let seedSource = SourceRecord(
            kind: .text,
            uri: "local://memory-seed",
            title: "Hive Memory Seed",
            mimeType: "text/plain",
            sizeBytes: 1,
            sha256: "hash-4",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        XCTAssertEqual(SourcePresentationModel(source: seedSource).title, "Captured memory seed")

        let boundarySeed = SourceRecord(
            kind: .text,
            connector: "local-memory-seed",
            uri: "hive-seed://personal-memory-boundary-reset/v1",
            title: "Hive Memory Seed",
            mimeType: "application/json",
            sizeBytes: 1,
            sha256: "hash-5",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        XCTAssertEqual(SourcePresentationModel(source: boundarySeed).title, "Memory boundary reset")

        let startQuestionsSeed = SourceRecord(
            kind: .text,
            uri: "/tmp/hive-start-questions.json",
            title: "AI Memory Seed - hive-start-questions.json",
            mimeType: "application/json",
            sizeBytes: 1,
            sha256: "hash-6",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        XCTAssertEqual(SourcePresentationModel(source: startQuestionsSeed).title, "Hive start questions")

        let understoodSource = SourceRecord(
            kind: .text,
            uri: "local://understood",
            title: "Useful local source",
            mimeType: "text/plain",
            sizeBytes: 1,
            sha256: "hash-understood",
            retentionExpiresAt: Date().addingTimeInterval(86_400),
            status: .extracted
        )
        XCTAssertEqual(SourcePresentationModel(source: understoodSource).summary, "")

        let attachment = SourceRecord(
            kind: .pdf,
            uri: "/Users/example/Desktop/Board deck.pdf",
            title: "Board deck.pdf",
            mimeType: "application/pdf",
            sizeBytes: 1_048_576,
            sha256: "hash-attachment",
            retentionExpiresAt: Date().addingTimeInterval(86_400),
            status: .extracted
        )
        let rawBlob = RawBlobRecord(
            sourceID: attachment.id,
            contentAddress: "stored-attachment.pdf",
            localPath: "/Users/example/Library/Application Support/Hive/raw/stored-attachment.pdf",
            mimeType: attachment.mimeType,
            sizeBytes: attachment.sizeBytes,
            sha256: attachment.sha256
        )
        let attachmentPresentation = SourcePresentationModel(
            source: attachment,
            rawBlob: rawBlob,
            artifactPreviewText: "Executive summary for the uploaded board deck."
        )
        XCTAssertEqual(attachmentPresentation.attachmentPreview?.displayName, "Board deck.pdf")
        XCTAssertEqual(attachmentPresentation.attachmentPreview?.kindLabel, "Document")
        XCTAssertEqual(attachmentPresentation.attachmentPreview?.localPath, rawBlob.localPath)
        XCTAssertEqual(attachmentPresentation.attachmentPreview?.extractedSnippet, "Executive summary for the uploaded board deck.")
        XCTAssertTrue(attachmentPresentation.summary.contains("Document"))
    }

    func testBrowserPresentationUsesDigestedSourceLanguage() {
        let driveSearch = SourceRecord(
            kind: .browserHistory,
            uri: "https://drive.google.com/drive/search?q=cabin",
            title: "Search results - Google Drive",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "browser-title-1",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        XCTAssertEqual(SourcePresentationModel(source: driveSearch).title, "Drive search")

        let componentResearch = SourceRecord(
            kind: .browserHistory,
            uri: "https://21st.dev/components/animated-tabs",
            title: "Animated Tabs | Community Components | 21st.dev",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "browser-title-2",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        XCTAssertEqual(SourcePresentationModel(source: componentResearch).title, "Tab interaction reference")
        XCTAssertFalse(SourcePresentationModel(source: componentResearch).isDefaultVisibleRawInput)

        let googleSignIn = SourceRecord(
            kind: .browserHistory,
            uri: "https://accounts.google.com/v3/signin/identifier",
            title: "Sign in - Google Accounts",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "browser-title-auth",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        let signInPresentation = SourcePresentationModel(source: googleSignIn)
        XCTAssertEqual(signInPresentation.title, "Google sign-in")
        XCTAssertFalse(signInPresentation.isDefaultVisibleRawInput)

        let brev = SourceRecord(
            kind: .browserHistory,
            uri: "https://brev.dev/settings/billing",
            title: "Organization Billing | Brev.dev",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "browser-title-3",
            retentionExpiresAt: Date().addingTimeInterval(86_400)
        )
        XCTAssertEqual(SourcePresentationModel(source: brev).title, "Brev billing")
        XCTAssertTrue(SourcePresentationModel(source: brev).isDefaultVisibleRawInput)
    }

    func testRawInputClustersCollapseRepeatedBrowserTrailsOnly() {
        let now = Date()
        let lamtA = SourceRecord(
            kind: .browserHistory,
            uri: "browser-history://a",
            title: "LAMT 2026",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "lamt-a",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let lamtB = SourceRecord(
            kind: .browserHistory,
            uri: "browser-history://b",
            title: "LAMT 2026",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "lamt-b",
            observedAt: now.addingTimeInterval(-60),
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let thoughtA = SourceRecord(
            kind: .text,
            uri: "local://thought-a",
            title: "Quick Thought 2026 05 26 18.23.09",
            mimeType: "text/plain",
            sizeBytes: 1,
            sha256: "thought-a",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let thoughtB = SourceRecord(
            kind: .text,
            uri: "local://thought-b",
            title: "Quick Thought 2026 05 26 18.24.09",
            mimeType: "text/plain",
            sizeBytes: 1,
            sha256: "thought-b",
            observedAt: now.addingTimeInterval(-120),
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )

        let clusters = RawInputCellCluster.clusters(from: [lamtA, lamtB, thoughtA, thoughtB].map { SourcePresentationModel(source: $0, now: now) })

        XCTAssertEqual(clusters.count, 3)
        XCTAssertEqual(clusters.first?.primary.title, "LAMT 2026")
        XCTAssertEqual(clusters.first?.count, 2)
        XCTAssertEqual(clusters.filter { $0.primary.title == "Quick thought" }.count, 2)
    }

    func testRawInputSemanticClustersCollapseMacFundingResearch() throws {
        let now = Date()
        let apple = SourceRecord(
            kind: .browserHistory,
            uri: "https://www.apple.com/mac-studio/",
            title: "Apple Mac Studio M3 Ultra 512GB Memory",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "apple-mac-studio",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let refurbished = SourceRecord(
            kind: .browserHistory,
            uri: "https://www.ebay.com/sch/i.html?_nkw=m3+ultra+mac+studio+512gb",
            title: "Refurbished Mac Studio M3 Ultra 512GB",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "ebay-mac-studio",
            observedAt: now.addingTimeInterval(-60),
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let grant = SourceRecord(
            kind: .browserHistory,
            uri: "https://example.org/grants/apply",
            title: "Grant application for hardware funding",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "grant-application",
            observedAt: now.addingTimeInterval(-120),
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let scholarship = SourceRecord(
            kind: .browserHistory,
            uri: "https://docs.google.com/document/scholarship",
            title: "Scholarship application blank",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "scholarship-application",
            observedAt: now.addingTimeInterval(-180),
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )

        let clusters = RawInputSemanticClusterer().clusters(from: [apple, refurbished, grant, scholarship].map { SourcePresentationModel(source: $0, now: now) })

        let macCluster = try XCTUnwrap(clusters.first { $0.title == "Mac Studio funding research" })
        let fundingCluster = try XCTUnwrap(clusters.first { $0.title == "Grant and scholarship applications" })
        XCTAssertEqual(macCluster.count, 2)
        XCTAssertEqual(fundingCluster.count, 2)
        XCTAssertTrue(clusters.allSatisfy { !$0.title.localizedCaseInsensitiveContains("Amazon.com") })
    }

    func testChatFallbackUsesIndexedMemoryWithoutRawSourceDump() {
        let now = Date()
        let browser = SourceRecord(
            kind: .browserHistory,
            uri: "https://www.amazon.com/example-m3-ultra",
            title: "Amazon.com: M3 Ultra Mac Studio 512GB",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "chat-browser",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let claim = ClaimRecord(
            id: "claim-mac-funding",
            statement: "The user is an Apple/Mac user researching grant and scholarship funding to buy a more powerful Mac, preferably an M3 Ultra Mac Studio with 512GB RAM.",
            claimType: "user-context-consolidation",
            sourceRefs: [browser.id],
            confidence: 1.0,
            uncertaintyReason: "Fixture",
            createdAt: now
        )

        let answer = ChatAnswerEngine().answer(
            query: "what mac am i trying to buy",
            sources: [browser],
            claims: [claim],
            wikiPages: [],
            modelAvailability: .indexedMemoryOnly
        )

        XCTAssertTrue(answer.answer.contains("M3 Ultra Mac Studio"))
        XCTAssertFalse(answer.answer.contains("%"))
        XCTAssertFalse(answer.answer.localizedCaseInsensitiveContains("Amazon.com"))
        XCTAssertEqual(answer.uncertainty, "Indexed memory only")
        XCTAssertTrue(answer.citations.isEmpty)
    }

    func testChatFallbackConsultsWikiIndexMetadataBeforePageBody() {
        let page = WikiPageRecord(
            id: "project-funding",
            title: "Mac Studio Funding",
            markdown: "# Mac Studio Funding\n\nThis article body intentionally omits the search term.",
            sourceRefs: [],
            claimRefs: [],
            kind: .project,
            summary: "Grant and scholarship path for a more powerful Apple workstation.",
            frontmatter: ["tags": "hardware, grants"]
        )

        let answer = ChatAnswerEngine().answer(
            query: "scholarship workstation",
            sources: [],
            claims: [],
            wikiPages: [page],
            modelAvailability: .indexedMemoryOnly
        )

        XCTAssertTrue(answer.answer.contains("Mac Studio Funding"))
        XCTAssertTrue(answer.answer.contains("index points there first"))
    }

    func testChatFallbackUsesFlowerFieldSourceHintsWhenColonyIsThin() {
        let now = Date()
        let resume = SourceRecord(
            id: "source-resume",
            kind: .pdf,
            connector: "upload",
            uri: "hive://source/source-resume",
            title: "Resume May 2026.pdf",
            mimeType: "application/pdf",
            sizeBytes: 10_000,
            sha256: "resume",
            importedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )

        let answer = ChatAnswerEngine().answer(
            query: "what should i change in my resume",
            sources: [resume],
            claims: [],
            wikiPages: [],
            modelAvailability: .indexedMemoryOnly
        )

        XCTAssertTrue(answer.answer.contains("Field has related source material"))
        XCTAssertTrue(answer.answer.contains("Resume May 2026"))
        XCTAssertEqual(answer.citations, [resume])
        XCTAssertEqual(answer.uncertainty, "Field evidence needs review")
    }

    func testMemoryRelevanceSuppressesBarePythonAndAllowsUserCenteredPythonClaim() throws {
        let now = Date()
        let browser = SourceRecord(
            kind: .browserHistory,
            uri: "https://example.com/python",
            title: "Python",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "python-browser",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let barePython = EntityRecord(
            id: "entity-python",
            name: "Python",
            entityType: "topic",
            sourceRefs: [browser.id],
            confidence: 0.9,
            createdAt: now
        )
        let usefulPython = ClaimRecord(
            id: "claim-python-workflow",
            statement: "The user uses Python for quant and model workflows.",
            claimType: "memory-seed-confirmed",
            sourceRefs: [],
            confidence: 0.96,
            uncertaintyReason: "Fixture",
            createdBy: "ai-memory-seed",
            createdAt: now
        )

        let relevance = MemoryRelevanceEngine().evaluate(
            sources: [browser],
            claims: [usefulPython],
            entities: [barePython],
            now: now
        )
        let graph = GraphEngine().buildGraph(
            sources: [browser],
            claims: [usefulPython],
            entities: [barePython],
            relationships: [],
            visibility: relevance.visibility
        )

        XCTAssertEqual(relevance.visibility.entityDecisions["entity-python"]?.tier, .incidental)
        XCTAssertFalse(graph.nodes.contains { $0.id == "entity-python" || $0.title == "Python" })
        XCTAssertTrue(graph.nodes.contains { $0.id == "claim-python-workflow" })
    }

    func testMemoryRelevanceSuppressesContextlessUnrealEngineButKeepsUserClaim() throws {
        let now = Date()
        let source = SourceRecord(
            kind: .genericFile,
            uri: "hive://source/game-dev-notes",
            title: "Game Dev Notes",
            mimeType: "text/plain",
            sizeBytes: 1,
            sha256: "unreal-notes",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let bareUnreal = EntityRecord(
            id: "entity-unreal",
            name: "Unreal Engine",
            entityType: "topic",
            sourceRefs: [source.id],
            confidence: 0.9,
            createdAt: now
        )
        let usefulUnreal = ClaimRecord(
            id: "claim-unreal-project",
            statement: "The user built an Unreal Engine project prototype for interactive level design.",
            claimType: "source-observation",
            subjectEntityID: bareUnreal.id,
            sourceRefs: [source.id],
            confidence: 0.92,
            uncertaintyReason: "Fixture",
            createdAt: now
        )

        let bareRelevance = MemoryRelevanceEngine().evaluate(
            sources: [source],
            claims: [],
            entities: [bareUnreal],
            now: now
        )
        XCTAssertEqual(bareRelevance.visibility.entityDecisions["entity-unreal"]?.tier, .incidental)

        let usefulRelevance = MemoryRelevanceEngine().evaluate(
            sources: [source],
            claims: [usefulUnreal],
            entities: [bareUnreal],
            now: now
        )
        let graph = GraphEngine().buildGraph(
            sources: [source],
            claims: [usefulUnreal],
            entities: [bareUnreal],
            relationships: [],
            visibility: usefulRelevance.visibility
        )
        XCTAssertFalse(graph.nodes.contains { $0.id == "entity-unreal" && $0.title == "Unreal Engine" })
        XCTAssertTrue(graph.nodes.contains { $0.id == "claim-unreal-project" })
    }

    func testMemoryRelevanceSuppressesBareUconsultingUnlessUserCentered() throws {
        let now = Date()
        let source = SourceRecord(
            kind: .browserHistory,
            uri: "https://uconsulting.example",
            title: "Uconsulting",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "uconsulting",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let bare = EntityRecord(id: "entity-uconsulting", name: "Uconsulting", entityType: "topic", sourceRefs: [source.id], confidence: 0.88, createdAt: now)
        let centered = ClaimRecord(
            id: "claim-uconsulting",
            statement: "The user is targeting UConsulting at UCLA as part of their consulting career goals.",
            claimType: "user-context-consolidation",
            subjectEntityID: "entity-uconsulting-goal",
            sourceRefs: [source.id],
            confidence: 0.96,
            uncertaintyReason: "Fixture",
            createdBy: "deterministic-self-healing",
            createdAt: now
        )
        let canonical = EntityRecord(id: "entity-uconsulting-goal", name: "UConsulting Goal", entityType: "user-context", aliases: ["Uconsulting"], sourceRefs: [source.id], confidence: 0.96, createdAt: now)

        let relevance = MemoryRelevanceEngine().evaluate(sources: [source], claims: [centered], entities: [bare, canonical], now: now)
        let graph = GraphEngine().buildGraph(sources: [source], claims: [centered], entities: [bare, canonical], relationships: [], visibility: relevance.visibility)

        XCTAssertFalse(graph.nodes.contains { $0.id == "entity-uconsulting" || $0.title == "Uconsulting" })
        XCTAssertTrue(graph.nodes.contains { $0.id == "entity-uconsulting-goal" && $0.title == "UConsulting Goal" })
    }

    func testMemoryRelevanceMarksOldOneOffBrowserTrailStale() {
        let now = Date()
        let old = now.addingTimeInterval(-21 * 86_400)
        let source = SourceRecord(
            kind: .browserHistory,
            uri: "https://example.com/random-search",
            title: "Random search result",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "old-browser",
            observedAt: old,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let claim = ClaimRecord(
            id: "claim-old-browser",
            statement: "Random search result",
            claimType: "observation",
            sourceRefs: [source.id],
            confidence: 0.82,
            uncertaintyReason: "Fixture",
            createdAt: old
        )

        let relevance = MemoryRelevanceEngine().evaluate(sources: [source], claims: [claim], entities: [], now: now)

        XCTAssertEqual(relevance.visibility.claimDecisions[claim.id]?.tier, .stale)
        XCTAssertFalse(relevance.visibility.shouldShowClaim(claim))
    }

    func testRawInputDefaultVisibilityHidesAuthAndStaleOneOffButKeepsSemanticClusters() {
        let now = Date()
        let signIn = SourceRecord(
            kind: .browserHistory,
            uri: "https://accounts.google.com/v3/signin/identifier",
            title: "Sign in - Google Accounts",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "signin",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let oldSearch = SourceRecord(
            kind: .browserHistory,
            uri: "https://example.com/old",
            title: "Old random page",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "old-random",
            observedAt: now.addingTimeInterval(-30 * 86_400),
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let mac = SourceRecord(
            kind: .browserHistory,
            uri: "https://www.apple.com/mac-studio/",
            title: "Apple Mac Studio M3 Ultra 512GB Memory",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "mac",
            observedAt: now.addingTimeInterval(-30 * 86_400),
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )

        let visible = RawInputSemanticClusterer.defaultVisibleSourceIDs(
            sources: [signIn, oldSearch, mac],
            claims: [],
            visibility: .allowAll,
            now: now
        )

        XCTAssertFalse(visible.contains(signIn.id))
        XCTAssertFalse(visible.contains(oldSearch.id))
        XCTAssertTrue(visible.contains(mac.id))
    }

    func testChatUsesRelevanceBeforeTokenOverlap() {
        let now = Date()
        let rawBrowser = SourceRecord(
            kind: .browserHistory,
            uri: "https://www.amazon.com/example-macbook",
            title: "Amazon.com: MacBook",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "amazon-macbook",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let incidental = ClaimRecord(
            id: "claim-raw-macbook",
            statement: "MacBook",
            claimType: "observation",
            sourceRefs: [rawBrowser.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let canonical = ClaimRecord(
            id: "claim-mac-funding-canonical",
            statement: "The user is an Apple/Mac user researching grant and scholarship funding to buy a more powerful Mac, preferably an M3 Ultra Mac Studio with 512GB RAM.",
            claimType: "user-context-consolidation",
            sourceRefs: [rawBrowser.id],
            confidence: 1,
            uncertaintyReason: "Fixture",
            createdBy: "user-instruction",
            createdAt: now
        )
        let relevance = MemoryRelevanceEngine().evaluate(sources: [rawBrowser], claims: [incidental, canonical], entities: [], now: now)
        let answer = ChatAnswerEngine().answer(
            query: "MacBook",
            sources: [rawBrowser],
            claims: [incidental, canonical],
            wikiPages: [],
            modelAvailability: .indexedMemoryOnly,
            visibility: relevance.visibility
        )

        XCTAssertTrue(answer.answer.contains("M3 Ultra Mac Studio"))
        XCTAssertFalse(answer.answer.contains("Amazon.com"))
        XCTAssertFalse(answer.answer.contains("MacBook. MacBook."))
    }

    func testMemoryCompilerRuntimeProducesStableProposalEnvelope() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = SourceRecord(
            kind: .text,
            uri: "local://yc-demo",
            title: "YC demo import",
            mimeType: "text/plain",
            sizeBytes: 1,
            sha256: "yc-demo",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let claim = ClaimRecord(
            id: "claim-yc-demo",
            statement: "The user wants Hive to be Obsidian on drugs with deterministic local AI synthesis.",
            claimType: "memory-seed-confirmed",
            sourceRefs: [source.id],
            confidence: 0.96,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let runtime = MemoryCompilerRuntime(profile: .deterministicRules)

        let first = runtime.compile(
            source: source,
            extractedClaims: [claim],
            existingClaims: [],
            existingEntities: [],
            now: now
        )
        let second = runtime.compile(
            source: source,
            extractedClaims: [claim],
            existingClaims: [],
            existingEntities: [],
            now: now.addingTimeInterval(50)
        )

        XCTAssertEqual(first.decision.kind, .createMemory)
        XCTAssertEqual(first.stableDecisionID, second.stableDecisionID)
        XCTAssertEqual(first.promptHash, second.promptHash)
        XCTAssertEqual(first.mutationPolicy, "model-output-is-proposal-only")
        XCTAssertTrue(first.profile.backend.isOnDeviceEligible)
    }

    func testTrainingDataExporterBuildsLocalJSONLExamples() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = SourceRecord(
            kind: .text,
            uri: "local://training",
            title: "Training source",
            mimeType: "text/plain",
            sizeBytes: 1,
            sha256: "training-source",
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let claim = ClaimRecord(
            id: "claim-training",
            statement: "The user treats Wiki edits as canonical truth.",
            claimType: "user-context-consolidation",
            subjectEntityID: "entity-wiki-truth",
            sourceRefs: [source.id],
            confidence: 1,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let page = WikiPageRecord(
            id: "wiki-truth",
            title: "Wiki Truth",
            markdown: "# Wiki Truth\n\nThe user treats Wiki edits as canonical truth.",
            sourceRefs: [source.id],
            claimRefs: [claim.id],
            kind: .topic
        )

        let examples = DistillationDatasetBuilder().buildExamples(sources: [source], claims: [claim], wikiPages: [page])
        let jsonl = try TrainingDataExporter().examplesJSONL(examples)

        XCTAssertEqual(examples.count, 1)
        XCTAssertEqual(examples.first?.privacyScope, "local-only")
        XCTAssertEqual(examples.first?.expectedDecision.kind, .mergeIntoExisting)
        XCTAssertTrue(jsonl.contains("\"privacyScope\":\"local-only\""))
        XCTAssertTrue(jsonl.contains("claim-training"))
        XCTAssertFalse(jsonl.localizedCaseInsensitiveContains("cloud"))
    }

    func testLocalAIEngineChatUsesModelFreeFallback() async {
        let now = Date()
        let claim = ClaimRecord(
            id: "claim-local-ai",
            statement: "Hive answers from indexed local memory when no local model is installed.",
            claimType: "memory-seed-confirmed",
            sourceRefs: [],
            confidence: 0.98,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let engine = LocalAIEngine(manager: MLXModelManager(executionMode: .deterministicMock))
        let answer = await engine.answerChat(
            query: "what happens when no model is installed",
            sources: [],
            claims: [claim],
            wikiPages: [],
            modelAvailability: .indexedMemoryOnly
        )

        XCTAssertTrue(answer.answer.localizedCaseInsensitiveContains("indexed local memory"))
        XCTAssertEqual(answer.uncertainty, "Indexed memory only")
        XCTAssertFalse(answer.answer.contains("%"))
    }

    func testLocalAIEngineCanRouteChatToLocalSynthesisWhenAvailable() async {
        let now = Date()
        let claim = ClaimRecord(
            id: "claim-local-synthesis",
            statement: "Hive can use an installed local synthesis model without giving it mutation authority.",
            claimType: "memory-seed-confirmed",
            sourceRefs: [],
            confidence: 0.98,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let engine = LocalAIEngine(
            manager: MLXModelManager(executionMode: .deterministicMock),
            profileProvider: {
                RuntimeProfile(
                    chipName: "MacBookPro18,1",
                    physicalMemoryBytes: 16 * 1_073_741_824,
                    processorCount: 10,
                    thermalState: .nominal,
                    powerState: .unknown,
                    lowPowerModeEnabled: false,
                    foregroundUserActive: false
                )
            }
        )

        let answer = await engine.answerChat(
            query: "can hive use local synthesis",
            sources: [],
            claims: [claim],
            wikiPages: [],
            modelAvailability: .localSynthesisAvailable
        )

        XCTAssertEqual(answer.answer, "Local synthesis refined the indexed memory answer.")
        XCTAssertEqual(answer.uncertainty, "Local synthesis available")
        XCTAssertFalse(answer.answer.contains("%"))
    }

    func testWikiArticlePresentationHidesControlMarkdown() {
        let markdown = """
        ---
        id: "overview"
        kind: "overview"
        slug: "overview"
        ---
        # UCLA Student

        ## Claims
        - The user is a UCLA mathematics student.
        - [[Cabin]] — project
        - web signal: 6 sessions and 57 pages

        ## Connections
        - A -> B forms a recurrent local loop.
        """
        let body = WikiPresentationModel.articleBody(from: markdown)
        XCTAssertTrue(body.contains("UCLA Student"))
        XCTAssertTrue(body.contains("The user is a UCLA mathematics student."))
        XCTAssertTrue(body.contains("Cabin"))
        XCTAssertFalse(body.contains("---"))
        XCTAssertFalse(body.contains("id:"))
        XCTAssertFalse(body.contains("[["))
        XCTAssertFalse(body.localizedCaseInsensitiveContains("web signal"))
        XCTAssertFalse(body.localizedCaseInsensitiveContains("Connections"))
    }

    func testWikiArticlePresentationDoesNotInventPlaceholderBody() {
        let markdown = """
        ---
        id: "empty"
        kind: "topic"
        slug: "empty"
        ---
        """
        XCTAssertEqual(WikiPresentationModel.articleBody(from: markdown), "")
    }

    func testWikiArticleConsolidatorMergesSelectedArticlesIntoOneCanonicalPage() throws {
        let now = Date(timeIntervalSince1970: 100)
        let primary = WikiPageRecord(
            id: "entity-hive",
            title: "Hive",
            markdown: """
            # Hive

            Hive is the user's local-first AI memory app.

            ## Known Information
            - The user wants Hive to keep Field sources separate from memory.
            """,
            sourceRefs: ["source-a"],
            claimRefs: ["claim-a"],
            updatedAt: Date(timeIntervalSince1970: 10),
            kind: .project,
            summary: "Hive is the user's memory product."
        )
        let duplicate = WikiPageRecord(
            id: "entity-hive-app",
            title: "Hive App",
            markdown: """
            # Hive App

            The user wants Hive to consolidate duplicate Colony articles.

            ## Related Concepts
            - [[Hive]]
            """,
            sourceRefs: ["source-b"],
            claimRefs: ["claim-b"],
            updatedAt: Date(timeIntervalSince1970: 20),
            kind: .project,
            summary: "Duplicate page."
        )

        let result = try XCTUnwrap(WikiArticleConsolidator().consolidate(
            pages: [primary, duplicate],
            selectedPageIDs: [primary.id, duplicate.id],
            primaryPageID: primary.id,
            now: now
        ))

        XCTAssertEqual(result.page.id, primary.id)
        XCTAssertEqual(result.removedPageIDs, [duplicate.id])
        XCTAssertEqual(Set(result.page.sourceRefs), ["source-a", "source-b"])
        XCTAssertEqual(Set(result.page.claimRefs), ["claim-a", "claim-b"])
        XCTAssertEqual(result.page.frontmatter[UserWikiEditPolicy.authorityKey], UserWikiEditPolicy.authorityValue)
        XCTAssertTrue(result.page.markdown.contains("The user wants Hive to consolidate duplicate Colony articles."))
        XCTAssertFalse(result.page.markdown.localizedCaseInsensitiveContains("raw input"))
        XCTAssertEqual(result.auditEvent.eventType, "wiki.articlesConsolidated")
    }

    func testWikiVisibleClaimsExcludeBrowserAndGraphDiagnostics() {
        let browser = ClaimRecord(statement: "Hive found a browser signal around web signal: 6 sessions", claimType: "browser-observation", sourceRefs: [], confidence: 0.5, uncertaintyReason: "Fixture")
        let graph = ClaimRecord(statement: "A forms a recurrent local loop with B", claimType: "graph-insight", sourceRefs: [], confidence: 0.8, uncertaintyReason: "Fixture")
        let memory = ClaimRecord(statement: "The user studies mathematics at UCLA.", claimType: "memory-seed-confirmed", sourceRefs: [], confidence: 0.95, uncertaintyReason: "Fixture")

        XCTAssertFalse(browser.isUserVisibleWikiClaim)
        XCTAssertFalse(graph.isUserVisibleWikiClaim)
        XCTAssertTrue(memory.isUserVisibleWikiClaim)
    }

    func testWikiArticleListExcludesBareLowInformationHardwarePages() {
        let bare = WikiPageRecord(title: "Macbook", markdown: "# Macbook", sourceRefs: [], claimRefs: [], kind: .topic)
        let useful = WikiPageRecord(title: "M4 MacBook Pro", markdown: "# M4 MacBook Pro", sourceRefs: [], claimRefs: [], kind: .topic)
        let unreal = WikiPageRecord(title: "Unreal Engine", markdown: "# Unreal Engine\n\nUnreal Engine.", sourceRefs: ["source-unreal"], claimRefs: ["claim-unreal"], kind: .topic)
        let thin = WikiPageRecord(id: "entity-thin", title: "Thin Article", markdown: "# Thin Article\n\nOne useful sentence.", sourceRefs: ["source-thin"], claimRefs: ["claim-thin"], kind: .topic)
        let blankBattery = WikiPageRecord(
            id: "topic-battery-health",
            title: "Battery Health",
            markdown: "# Battery Health\n",
            sourceRefs: ["source-battery"],
            claimRefs: [],
            kind: .topic
        )

        XCTAssertFalse(bare.isUserVisibleArticle)
        XCTAssertFalse(useful.isUserVisibleArticle)
        XCTAssertFalse(unreal.isUserVisibleArticle)
        XCTAssertFalse(thin.isUserVisibleArticle)
        XCTAssertFalse(blankBattery.isUserVisibleArticle)
        XCTAssertTrue(blankBattery.isDiscardableBlankGeneratedArticle)
    }

    func testWikiCompilerDoesNotPromoteContextlessToolIntoStandaloneArticle() {
        let now = Date()
        let source = SourceRecord(
            id: "source-project",
            kind: .genericFile,
            connector: "upload",
            uri: "hive://source/source-project",
            title: "Project notes",
            mimeType: "text/plain",
            sizeBytes: 10,
            sha256: "source-project",
            importedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let entity = EntityRecord(
            id: "entity-project",
            name: "Unreal Engine",
            entityType: "topic",
            sourceRefs: [source.id],
            confidence: 0.92,
            createdAt: now
        )
        let firstClaim = ClaimRecord(
            id: "claim-project-one",
            statement: "Unreal Engine appears in the source notes.",
            claimType: "source-observation",
            subjectEntityID: entity.id,
            sourceRefs: [source.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let compiler = WikiCompiler()

        let oneClaimPages = compiler.compile(
            sources: [source],
            claims: [firstClaim],
            entities: [entity],
            relationships: [],
            feedback: [],
            auditEvents: []
        )
        XCTAssertFalse(oneClaimPages.contains { $0.title == "Unreal Engine" && $0.isUserVisibleArticle })

        let secondClaim = ClaimRecord(
            id: "claim-project-two",
            statement: "The user built an Unreal Engine project prototype for interactive level design.",
            claimType: "source-observation",
            subjectEntityID: entity.id,
            sourceRefs: [source.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let twoClaimPages = compiler.compile(
            sources: [source],
            claims: [firstClaim, secondClaim],
            entities: [entity],
            relationships: [],
            feedback: [],
            auditEvents: []
        )
        XCTAssertFalse(twoClaimPages.contains { $0.title == "Unreal Engine" && $0.isUserVisibleArticle })
        XCTAssertTrue(twoClaimPages.contains { $0.title == "Overview" })
    }

    func testWikiCompilerDoesNotCreateEntityPageFromSharedSourceAlone() {
        let now = Date()
        let source = SourceRecord(
            id: "source-resume",
            kind: .pdf,
            connector: "upload",
            uri: "hive://source/source-resume",
            title: "Resume.pdf",
            mimeType: "application/pdf",
            sizeBytes: 10,
            sha256: "source-resume",
            importedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let entity = EntityRecord(
            id: "entity-los-angeles",
            name: "Los Angeles",
            entityType: "topic",
            sourceRefs: [source.id],
            confidence: 0.95,
            createdAt: now
        )
        let claims = [
            ClaimRecord(
                id: "claim-cabin",
                statement: "The user built Cabin as a 3D rendering app with Metal shader development.",
                claimType: "source-observation",
                sourceRefs: [source.id],
                confidence: 0.9,
                uncertaintyReason: "Fixture",
                createdAt: now
            ),
            ClaimRecord(
                id: "claim-ucla",
                statement: "The user studies mathematics at UCLA and completed relevant software engineering coursework.",
                claimType: "source-observation",
                sourceRefs: [source.id],
                confidence: 0.9,
                uncertaintyReason: "Fixture",
                createdAt: now
            )
        ]

        let pages = WikiCompiler().compile(
            sources: [source],
            claims: claims,
            entities: [entity],
            relationships: [],
            feedback: [],
            auditEvents: []
        )

        XCTAssertFalse(pages.contains { $0.title == "Los Angeles" && $0.isUserVisibleArticle })
        XCTAssertTrue(pages.contains { $0.title == "Overview" })
    }

    func testWikiCompilerDropsOldPollutedGeneratedArticles() {
        let now = Date()
        let source = SourceRecord(
            id: "source-mac",
            kind: .text,
            connector: "upload",
            uri: "hive://source/source-mac",
            title: "Mac funding notes",
            mimeType: "text/plain",
            sizeBytes: 10,
            sha256: "source-mac",
            importedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let macClaim = ClaimRecord(
            id: "claim-mac",
            statement: "The user is an Apple/Mac user researching grant and scholarship funding to buy a more powerful Mac.",
            claimType: "source-observation",
            sourceRefs: [source.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        var polluted = WikiPageRecord(
            id: "entity-prose",
            title: "PROSE",
            markdown: """
            ---
            id: "entity-prose"
            kind: "topic"
            slug: "prose"
            editAuthority: "user"
            ---
            # PROSE

            PROSE is a topic in the user's local knowledge base. The user is an Apple/Mac user researching grant and scholarship funding to buy a more powerful Mac.

            ## Known Information
            - The user is an Apple/Mac user researching grant and scholarship funding to buy a more powerful Mac.
            """,
            sourceRefs: [source.id],
            claimRefs: [macClaim.id],
            kind: .topic,
            summary: "The user is an Apple/Mac user researching Mac funding."
        )
        polluted.frontmatter[UserWikiEditPolicy.authorityKey] = UserWikiEditPolicy.authorityValue

        let pages = WikiCompiler().compile(
            sources: [source],
            claims: [macClaim],
            entities: [],
            relationships: [],
            feedback: [],
            auditEvents: [],
            previousPages: [polluted]
        )

        XCTAssertFalse(pages.contains { $0.title == "PROSE" })
    }

    func testWikiCompilerRewritesPollutedArticleWhenRealClaimsAppear() {
        let now = Date()
        let source = SourceRecord(
            id: "source-prose",
            kind: .text,
            connector: "upload",
            uri: "hive://source/source-prose",
            title: "Prose notes",
            mimeType: "text/plain",
            sizeBytes: 10,
            sha256: "source-prose",
            importedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let entity = EntityRecord(
            id: "entity-prose",
            name: "PROSE",
            entityType: "project",
            sourceRefs: [source.id],
            confidence: 0.95,
            createdAt: now
        )
        let claims = [
            ClaimRecord(
                id: "claim-prose-one",
                statement: "The user built PROSE as a writing-focused project for structured long-form work.",
                claimType: "source-observation",
                sourceRefs: [source.id],
                confidence: 0.9,
                uncertaintyReason: "Fixture",
                createdAt: now
            ),
            ClaimRecord(
                id: "claim-prose-two",
                statement: "PROSE belongs in the user's creative writing and productivity portfolio.",
                claimType: "source-observation",
                sourceRefs: [source.id],
                confidence: 0.9,
                uncertaintyReason: "Fixture",
                createdAt: now
            )
        ]
        var polluted = WikiPageRecord(
            id: "entity-prose",
            title: "PROSE",
            markdown: """
            # PROSE

            PROSE is a topic in the user's local knowledge base. The user is an Apple/Mac user researching grant and scholarship funding to buy a more powerful Mac.

            ## Known Information
            - The user is an Apple/Mac user researching grant and scholarship funding to buy a more powerful Mac.
            """,
            sourceRefs: [source.id],
            claimRefs: ["claim-mac"],
            kind: .topic,
            summary: "The user is an Apple/Mac user researching Mac funding."
        )
        polluted.frontmatter[UserWikiEditPolicy.authorityKey] = UserWikiEditPolicy.authorityValue

        let pages = WikiCompiler().compile(
            sources: [source],
            claims: claims,
            entities: [entity],
            relationships: [],
            feedback: [],
            auditEvents: [],
            previousPages: [polluted]
        )
        let prose = try? XCTUnwrap(pages.first { $0.title == "PROSE" && $0.isUserVisibleArticle })

        XCTAssertNotNil(prose)
        XCTAssertTrue(prose?.markdown.contains("writing-focused project") == true)
        XCTAssertTrue(prose?.markdown.contains("## Claims") == true)
        XCTAssertFalse(prose?.markdown.localizedCaseInsensitiveContains("local knowledge base") == true)
        XCTAssertFalse(prose?.markdown.localizedCaseInsensitiveContains("Known Information") == true)
        XCTAssertFalse(prose?.markdown.localizedCaseInsensitiveContains("Mac user researching grant") == true)
    }

    func testWikiCompilerStillCreatesDirectGroundedArticle() {
        let now = Date()
        let source = SourceRecord(
            id: "source-project",
            kind: .text,
            connector: "upload",
            uri: "hive://source/source-project",
            title: "Project notes",
            mimeType: "text/plain",
            sizeBytes: 10,
            sha256: "source-project",
            importedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let entity = EntityRecord(
            id: "entity-cabin",
            name: "Cabin Rendering App",
            entityType: "project",
            sourceRefs: [source.id],
            confidence: 0.95,
            createdAt: now
        )
        let claims = [
            ClaimRecord(
                id: "claim-cabin-one",
                statement: "The user built the Cabin Rendering App with Metal shader development.",
                claimType: "source-observation",
                sourceRefs: [source.id],
                confidence: 0.9,
                uncertaintyReason: "Fixture",
                createdAt: now
            ),
            ClaimRecord(
                id: "claim-cabin-two",
                statement: "The Cabin Rendering App is part of the user's software engineering portfolio.",
                claimType: "source-observation",
                sourceRefs: [source.id],
                confidence: 0.9,
                uncertaintyReason: "Fixture",
                createdAt: now
            )
        ]

        let pages = WikiCompiler().compile(
            sources: [source],
            claims: claims,
            entities: [entity],
            relationships: [],
            feedback: [],
            auditEvents: []
        )

        let article = pages.first { $0.title == "Cabin Rendering App" && $0.isUserVisibleArticle }
        XCTAssertNotNil(article)
        XCTAssertTrue(article?.markdown.contains("## Claims") == true)
        XCTAssertFalse(article?.markdown.localizedCaseInsensitiveContains("local knowledge base") == true)
        XCTAssertFalse(article?.markdown.localizedCaseInsensitiveContains("Known Information") == true)
    }

    func testWikiCompilerUsesGroundedClaimSourcesInsteadOfBroadEntitySources() throws {
        let now = Date()
        let claimSource = SourceRecord(
            id: "source-claim",
            kind: .text,
            connector: "upload",
            uri: "hive://source/source-claim",
            title: "Project notes",
            mimeType: "text/plain",
            sizeBytes: 10,
            sha256: "source-claim",
            importedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let incidentalEntitySource = SourceRecord(
            id: "source-incidental-browser",
            kind: .text,
            connector: "upload",
            uri: "hive://source/source-incidental-browser",
            title: "Incidental entity metadata",
            mimeType: "text/plain",
            sizeBytes: 10,
            sha256: "source-incidental-browser",
            importedAt: now.addingTimeInterval(-3_600),
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let entity = EntityRecord(
            id: "entity-prose",
            name: "PROSE",
            entityType: "project",
            sourceRefs: [claimSource.id, incidentalEntitySource.id],
            confidence: 0.95,
            createdAt: now
        )
        let claims = [
            ClaimRecord(
                id: "claim-prose-one",
                statement: "Arpit Uppal built PROSE as a full-stack problem repository platform.",
                claimType: "source-observation",
                subjectEntityID: entity.id,
                sourceRefs: [claimSource.id],
                confidence: 0.92,
                uncertaintyReason: "Fixture",
                createdAt: now
            ),
            ClaimRecord(
                id: "claim-prose-two",
                statement: "PROSE uses Next.js, PostgreSQL, and Vercel for tournament workflows.",
                claimType: "source-observation",
                subjectEntityID: entity.id,
                sourceRefs: [claimSource.id],
                confidence: 0.91,
                uncertaintyReason: "Fixture",
                createdAt: now
            )
        ]

        let pages = WikiCompiler().compile(
            sources: [claimSource, incidentalEntitySource],
            claims: claims,
            entities: [entity],
            relationships: [],
            feedback: [],
            auditEvents: []
        )
        let article = try XCTUnwrap(pages.first { $0.title == "PROSE" && $0.isUserVisibleArticle })

        XCTAssertEqual(article.sourceRefs, [claimSource.id])
        XCTAssertFalse(article.sourceRefs.contains(incidentalEntitySource.id))
    }

    func testWikiCompilerCleansGeneratedArticleTitlesBeforeWritingIndex() throws {
        let now = Date()
        let source = SourceRecord(
            id: "source-founder",
            kind: .text,
            connector: "upload",
            uri: "hive://source/source-founder",
            title: "Founder notes",
            mimeType: "text/plain",
            sizeBytes: 10,
            sha256: "source-founder",
            importedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let entity = EntityRecord(
            id: "entity-founder",
            name: "Arpit Uppal\nFounder",
            entityType: "person",
            sourceRefs: [source.id],
            confidence: 0.95,
            createdAt: now
        )
        let claims = [
            ClaimRecord(
                id: "claim-founder-one",
                statement: "Arpit Uppal founded a competition platform used by tournament teams.",
                claimType: "source-observation",
                subjectEntityID: entity.id,
                sourceRefs: [source.id],
                confidence: 0.93,
                uncertaintyReason: "Fixture",
                createdAt: now
            ),
            ClaimRecord(
                id: "claim-founder-two",
                statement: "Arpit Uppal leads product and engineering work for PROSE.",
                claimType: "source-observation",
                subjectEntityID: entity.id,
                sourceRefs: [source.id],
                confidence: 0.91,
                uncertaintyReason: "Fixture",
                createdAt: now
            )
        ]

        let pages = WikiCompiler().compile(
            sources: [source],
            claims: claims,
            entities: [entity],
            relationships: [],
            feedback: [],
            auditEvents: []
        )
        let article = try XCTUnwrap(pages.first { $0.title == "Arpit Uppal Founder" && $0.isUserVisibleArticle })
        let index = try XCTUnwrap(pages.first { $0.kind == .index })
        let overview = try XCTUnwrap(pages.first { $0.kind == .overview })
        let synthesis = try XCTUnwrap(pages.first { $0.kind == .synthesis })

        XCTAssertFalse(article.title.contains("\n"))
        XCTAssertFalse(article.markdown.contains("\nFounder]]"))
        XCTAssertTrue(index.markdown.contains("[[Arpit Uppal Founder]]"))
        XCTAssertFalse(index.markdown.contains("[[Arpit Uppal\nFounder]]"))
        XCTAssertTrue(overview.markdown.contains("[[Arpit Uppal Founder]]"))
        XCTAssertFalse(overview.markdown.contains("[[Arpit Uppal\nFounder]]"))
        XCTAssertTrue(synthesis.markdown.contains("[[Arpit Uppal Founder]]"))
        XCTAssertFalse(synthesis.markdown.contains("[[Arpit Uppal\nFounder]]"))
    }

    func testWikiCompilerKeepsControlPageMetadataFocusedOnDisplayedClaims() throws {
        let now = Date()
        let sources = (0..<30).map { index in
            SourceRecord(
                id: "source-\(index)",
                kind: .text,
                connector: "upload",
                uri: "hive://source/source-\(index)",
                title: "Source \(index)",
                mimeType: "text/plain",
                sizeBytes: 10,
                sha256: "source-\(index)",
                importedAt: now,
                retentionExpiresAt: now.addingTimeInterval(86_400)
            )
        }
        let claims = sources.enumerated().map { index, source in
            ClaimRecord(
                id: "claim-\(index)",
                statement: "Arpit built project \(index) with measurable engineering outcomes.",
                claimType: "source-observation",
                sourceRefs: [source.id],
                confidence: 0.9,
                uncertaintyReason: "Fixture",
                createdAt: now.addingTimeInterval(Double(index))
            )
        }

        let pages = WikiCompiler().compile(
            sources: sources,
            claims: claims,
            entities: [],
            relationships: [],
            feedback: [],
            auditEvents: []
        )
        let overview = try XCTUnwrap(pages.first { $0.kind == .overview })
        let synthesis = try XCTUnwrap(pages.first { $0.kind == .synthesis })

        XCTAssertLessThanOrEqual(overview.sourceRefs.count, 12)
        XCTAssertLessThanOrEqual(overview.claimRefs.count, 20)
        XCTAssertLessThanOrEqual(synthesis.sourceRefs.count, 12)
        XCTAssertLessThanOrEqual(synthesis.claimRefs.count, 12)
        XCTAssertFalse(overview.markdown.localizedCaseInsensitiveContains("internal overview"))
        XCTAssertFalse(overview.markdown.localizedCaseInsensitiveContains("private encyclopedia"))
    }

    func testExpandedFieldExtractionScansPastNormalLimit() {
        let now = Date()
        let source = SourceRecord(
            id: "source-long",
            kind: .text,
            connector: "upload",
            uri: "hive://source/source-long",
            title: "Long project dump.txt",
            mimeType: "text/plain",
            sizeBytes: 10,
            sha256: "source-long",
            importedAt: now,
            retentionExpiresAt: now.addingTimeInterval(86_400)
        )
        let projectNames = [
            "Atlas", "Beacon", "Cabin", "Delta", "Ember", "Forge", "Graph", "Harbor", "Ion", "Juniper",
            "Keystone", "Ledger", "Matrix", "Nimbus", "Orbit", "Prism", "Quartz", "Relay", "Summit", "Vector"
        ]
        let chunks = projectNames.enumerated().map { index, projectName in
            ChunkRecord(
                id: "chunk-\(index)",
                sourceID: source.id,
                artifactID: "artifact",
                text: "The user built \(projectName) with Swift engineering, data systems, testing, and measurable performance improvements.",
                locationLabel: "chunk \(index + 1)",
                extractionConfidence: 0.8
            )
        }
        let extractor = DeterministicKnowledgeExtractor()

        let normal = extractor.claims(from: chunks, source: source, depth: .normal)
        let expanded = extractor.claims(from: chunks, source: source, depth: .expanded)

        XCTAssertEqual(normal.count, 8)
        XCTAssertGreaterThan(expanded.count, normal.count)
        XCTAssertLessThanOrEqual(expanded.count, SourceExtractionDepth.expanded.claimLimit)
    }

    func testColonyShowsOpenQuestionsButDoesNotTreatThemAsArticles() {
        let question = WikiPageRecord(
            id: "open-questions",
            title: "Open Questions",
            markdown: "# Open Questions\n\n## Confirm the source\n- Reason: low confidence",
            sourceRefs: [],
            claimRefs: [],
            kind: .question,
            summary: "Hive needs one decision."
        )
        let article = WikiPageRecord(
            id: "topic-hive",
            title: "Hive",
            markdown: "# Hive\n\nMaintained article.",
            sourceRefs: ["source-a"],
            claimRefs: ["claim-a"],
            kind: .topic,
            summary: "Maintained article."
        )

        XCTAssertTrue(question.isVisibleInColony)
        XCTAssertFalse(question.isUserVisibleArticle)
        XCTAssertFalse(question.isColonySelectionEligible)
        XCTAssertTrue(article.isVisibleInColony)
        XCTAssertTrue(article.isColonySelectionEligible)
    }

    func testGraphPresentationExcludesSourceAndInsightDiagnostics() {
        let sourceNode = GraphNodeRecord(id: "source", title: "example.com", kind: .source, confidence: 0.8, sourceRefs: [])
        let insightNode = GraphNodeRecord(id: "insight", title: "A forms a recurrent local loop", kind: .insight, confidence: 0.8, sourceRefs: [])
        let memoryNode = GraphNodeRecord(id: "memory", title: "UCLA Student", kind: .topic, confidence: 0.95, sourceRefs: [])
        let bareHardwareNode = GraphNodeRecord(id: "bare-hardware", title: "Macbook", kind: .entity, confidence: 0.8, sourceRefs: [])
        let bareHardwareTopic = GraphNodeRecord(id: "bare-hardware-topic", title: "MacBook", kind: .topic, confidence: 0.8, sourceRefs: [])
        let specificHardwareNode = GraphNodeRecord(id: "specific-hardware", title: "M4 MacBook Pro", kind: .entity, confidence: 0.9, sourceRefs: [])
        let bareExperienceNode = GraphNodeRecord(id: "bare-experience", title: "Experience", kind: .topic, confidence: 0.8, sourceRefs: [])

        XCTAssertFalse(sourceNode.isUserVisibleGraphNode)
        XCTAssertFalse(insightNode.isUserVisibleGraphNode)
        XCTAssertTrue(memoryNode.isUserVisibleGraphNode)
        XCTAssertFalse(bareHardwareNode.isUserVisibleGraphNode)
        XCTAssertFalse(bareHardwareTopic.isUserVisibleGraphNode)
        XCTAssertFalse(specificHardwareNode.isUserVisibleGraphNode)
        XCTAssertFalse(bareExperienceNode.isUserVisibleGraphNode)
    }

    func testHiveGraphHexGeometryUsesExpandedScaleAndDilatedCoordinates() {
        let detailNode = GraphNodeRecord(id: "detail", title: "Latex Preference", kind: .topic, confidence: 0.8, sourceRefs: [], memoryLayer: .detail)
        let connectorNode = GraphNodeRecord(id: "connector", title: "CS31", kind: .topic, confidence: 0.8, sourceRefs: [], memoryLayer: .connector)
        let importantNode = GraphNodeRecord(id: "important", title: "UCLA Student", kind: .topic, confidence: 0.8, sourceRefs: [], memoryLayer: .importantTrait)
        let definingNode = GraphNodeRecord(id: "defining", title: "Mathematics", kind: .topic, confidence: 0.8, sourceRefs: [], memoryLayer: .definingTrait)

        XCTAssertEqual(HiveGraphGeometry.hexScale, 0.6, accuracy: 0.0001)
        XCTAssertEqual(HiveGraphGeometry.coordinateDilation, 2, accuracy: 0.0001)
        XCTAssertEqual(HiveGraphGeometry.nodeAxisOverflowRatio, 1.2, accuracy: 0.0001)
        XCTAssertEqual(HiveGraphGeometry.scrollViewportMarginRatio, 0.5, accuracy: 0.0001)
        XCTAssertEqual(HiveGraphGeometry.maximumOutZoomScale, 1, accuracy: 0.0001)
        XCTAssertEqual(HiveGraphGeometry.maximumInZoomScale, 4, accuracy: 0.0001)
        XCTAssertEqual(HiveGraphGeometry.hexSize(for: detailNode, selected: false), 14.4, accuracy: 0.0001)
        XCTAssertEqual(HiveGraphGeometry.hexSize(for: connectorNode, selected: false), 20.4, accuracy: 0.0001)
        XCTAssertEqual(HiveGraphGeometry.hexSize(for: importantNode, selected: false), 28.8, accuracy: 0.0001)
        XCTAssertEqual(HiveGraphGeometry.hexSize(for: definingNode, selected: false), 37.2, accuracy: 0.0001)
        XCTAssertEqual(HiveGraphGeometry.hexSize(for: importantNode, selected: true), 40.32, accuracy: 0.0001)
    }

    func testHiveGraphConstellationRenderingUsesPlainSingleHexNodes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let graphSurface = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))

        XCTAssertTrue(graphSurface.contains("private enum HiveGraphVisualStyle"))
        XCTAssertFalse(graphSurface.contains("static let honeycombStride"))
        XCTAssertFalse(graphSurface.contains("drawHoneycombTexture(bounds: bounds, in: &context)"))
        XCTAssertFalse(graphSurface.contains("warmBand"))
        XCTAssertFalse(graphSurface.contains("HexagonShape().path(in: glowRect)"))
        XCTAssertFalse(graphSurface.contains("HexagonShape().path(in: coreRect)"))
        XCTAssertFalse(graphSurface.contains("let isHub = node.layer == .definingTrait || node.layer == .importantTrait"))
        XCTAssertFalse(graphSurface.contains("let coreSize"))
        XCTAssertFalse(graphSurface.contains("let highlightSize"))
        XCTAssertTrue(graphSurface.contains("context.fill(path, with: .color(node.fill.opacity(node.opacity)))"))
        XCTAssertTrue(graphSurface.contains("labeledNodes(from: nodes)"))
        XCTAssertTrue(graphSurface.contains("node.memoryLayer == .definingTrait"))
        XCTAssertTrue(graphSurface.contains("return (domain ?? self.domain(for: node)).graphColor"))
        XCTAssertTrue(graphSurface.contains("return max(72, clusterNodeLimit * 3 / 4)"))
        XCTAssertFalse(graphSurface.contains("ColonyCluster("))
        XCTAssertFalse(graphSurface.contains("let cellCount = min(42, max(10, cluster.count / 2 + 8))"))
        XCTAssertTrue(graphSurface.contains("GraphRenderLayer(nodes: rendered.nodes, edges: rendered.edges, reindexEdges: rendered.reindexEdges)"))
        XCTAssertFalse(graphSurface.contains("style: StrokeStyle(lineWidth: 0.8, lineCap: .butt, dash: [3, 8])"))
        XCTAssertFalse(graphSurface.contains("let softFill = HexagonShape().path"))
        XCTAssertFalse(graphSurface.contains("ringOpacity"))
        XCTAssertFalse(graphSurface.contains("let ring = HexagonShape().path"))
        XCTAssertFalse(graphSurface.contains("Path(ellipseIn:"))
        XCTAssertFalse(graphSurface.contains("Circle()"))
        XCTAssertFalse(graphSurface.contains("Ellipse("))
        XCTAssertFalse(graphSurface.contains("lineCap: .round"))
        XCTAssertFalse(graphSurface.contains("CGPoint(x: 420 + cos(angle) * 230"))
        XCTAssertFalse(graphSurface.contains("cluster.radius * 0.42 * HiveGraphGeometry.hexScale"))
        XCTAssertFalse(graphSurface.contains("Path(ellipseIn: centerGlow)"))
        XCTAssertFalse(graphSurface.contains("Path(ellipseIn: lowerGlow)"))
        XCTAssertFalse(graphSurface.contains("Path(ellipseIn: coreRect)"))
    }

    func testHiveGraphLineRenderersOnlyUseStraightSegments() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let graphSurface = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))
        let metalRenderer = try String(contentsOf: root.appendingPathComponent("Sources/HiveMetalRenderer/HiveMetalRenderer.swift"))
        let rendererBodies = [graphSurface, metalRenderer]

        for body in rendererBodies {
            XCTAssertFalse(body.contains("addQuadCurve"))
            XCTAssertFalse(body.contains("addCurve"))
            XCTAssertFalse(body.contains("quadraticPoint"))
            XCTAssertFalse(body.contains("Bezier"))
        }
        XCTAssertTrue(graphSurface.contains("path.addLine(to: litTo)"))
        XCTAssertTrue(metalRenderer.contains("path.addLine(to: end)"))
        XCTAssertTrue(metalRenderer.contains("path.addLine(to: point)"))
    }

    func testPaletteIsRestrictedToHiveColors() {
        let expected: Set<String> = [
            "#0B0A08", "#14110E", "#1D1A15", "#252017", "#D8A21A", "#E8B334",
            "#A97812", "#D4A017", "#9DB87A", "#8A8580", "#A69B8E", "#665C50",
            "#F0EAE0", "#B2A79A", "#C0392B"
        ]
        XCTAssertEqual(Set(HiveColorToken.allCases.map(\.rawValue)), expected)
        XCTAssertFalse(HiveColorToken.allCases.map(\.rawValue).contains("#1B1205"))
        XCTAssertFalse(HiveColorToken.allCases.map(\.rawValue).contains("#241805"))
        XCTAssertFalse(HiveColorToken.allCases.map(\.rawValue).contains("#EAD3A6"))
        XCTAssertEqual(HiveColorToken.backgroundDeep.lightRawValue, "#D7AF55")
        XCTAssertEqual(HiveColorToken.backgroundMid.lightRawValue, "#E4C16B")
        XCTAssertEqual(HiveColorToken.cellSurface.lightRawValue, "#F0D88E")
        XCTAssertEqual(HiveColorToken.raisedSurface.lightRawValue, "#C08E28")
        XCTAssertFalse(HiveColorToken.allCases.map(\.lightRawValue).contains("#F5EDD6"))
        XCTAssertFalse(HiveColorToken.allCases.map(\.lightRawValue).contains("#FAF4E4"))
    }

    func testAdaptivePaletteKeepsSmallTextReadable() {
        let darkSurfaces: [HiveColorToken] = [.backgroundDeep, .backgroundMid, .cellSurface, .raisedSurface]
        let darkForegrounds: [HiveColorToken] = [.nectarText, .nectarMuted, .scaffoldGray]
        for surface in darkSurfaces {
            for foreground in darkForegrounds {
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(foreground.rawValue, surface.rawValue),
                    4.5,
                    "\(foreground.rawValue) on \(surface.rawValue)"
                )
            }
        }

        let lightSurfaces: [HiveColorToken] = [.backgroundDeep, .backgroundMid, .cellSurface, .raisedSurface]
        let lightForegrounds: [HiveColorToken] = [.nectarText, .nectarMuted]
        for surface in lightSurfaces {
            for foreground in lightForegrounds {
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(foreground.lightRawValue, surface.lightRawValue),
                    4.5,
                    "\(foreground.lightRawValue) on \(surface.lightRawValue)"
                )
            }
        }
    }

    func testPrimaryPalettePairsMeetAAAWhereHiveControlsText() {
        let textTokens: [HiveColorToken] = [.nectarText, .nectarMuted, .scaffoldGray]
        let surfaces: [HiveColorToken] = [.backgroundDeep, .backgroundMid, .cellSurface, .raisedSurface]

        for surface in surfaces {
            for foreground in textTokens {
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(foreground.rawValue, surface.rawValue),
                    4.5,
                    "dark \(foreground.rawValue) on \(surface.rawValue)"
                )
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(foreground.lightRawValue, surface.lightRawValue),
                    4.5,
                    "light \(foreground.lightRawValue) on \(surface.lightRawValue)"
                )
            }
        }
    }

    func testAmbientGradientsUseDedicatedReadableHoneyColors() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let design = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveDesignSystem.swift"))
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let appleNative = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveAppleNative.swift"))
        let rawInputs = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/RawInputsSurface.swift"))

        XCTAssertTrue(design.contains("public enum HiveAmbientPalette"))
        XCTAssertTrue(macRoot.contains("HiveAmbientPalette.honeyHighlight"))
        XCTAssertTrue(appleNative.contains("var solidFill: Color"))
        XCTAssertTrue(rawInputs.contains("HiveAmbientPalette.honeyAmber"))
        XCTAssertFalse(macRoot.contains("HiveColorToken.waxAmberBright.color.opacity(colorScheme"))
        XCTAssertFalse(appleNative.contains("HiveColorToken.nectarText.color.opacity(colorScheme == .dark ? 0.16 : 0.28)"))
    }

    func testBundledTypographyIdentityIsExplicit() {
        XCTAssertEqual(HiveFontRegistrar.bundledFontCount, 4)
        XCTAssertEqual(HiveFontName.nectarBody, "Newsreader16pt-Regular")
        XCTAssertEqual(HiveTypography.registerCount, 2)
        XCTAssertFalse(HiveTypography.usesCondensedChrome)
        XCTAssertFalse(HiveTypography.usesLightChromeWeights)
        XCTAssertEqual(HiveIdentity.voice, "A private AI memory vault that writes and rewrites itself under your control.")
        XCTAssertEqual(HiveIdentity.visualNorthStar, "Honey-warm local memory: Field raw files, The Colony articles, and The Hive graph.")
        XCTAssertEqual(HiveIdentity.interactionNorthStar, "every movement explains where knowledge came from or what changed")
    }

    func testHumanInterfaceGuidelinesPolicyIsEncoded() {
        XCTAssertEqual(
            Set(HiveHIGPrinciple.allCases),
            [.hierarchy, .harmony, .consistency, .accessibility, .materialRestraint, .platformConvention, .userControl]
        )
        for principle in HiveHIGPrinciple.allCases {
            XCTAssertFalse(principle.implementationRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        XCTAssertTrue(HiveHIGPolicy.humanInterfaceGuidelinesURL.hasPrefix("https://developer.apple.com/design/human-interface-guidelines"))
        XCTAssertTrue(HiveHIGPolicy.materialsGuidelinesURL.contains("materials"))
        XCTAssertTrue(HiveHIGPolicy.accessibilityGuidelinesURL.contains("accessibility"))
        XCTAssertTrue(HiveHIGPolicy.sfSymbolsGuidelinesURL.contains("sf-symbols"))
        XCTAssertTrue(HiveHIGPolicy.buttonsGuidelinesURL.contains("buttons"))
        XCTAssertTrue(HiveHIGPolicy.toolbarsGuidelinesURL.contains("toolbars"))
        XCTAssertTrue(HiveHIGPolicy.searchGuidelinesURL.contains("search-fields"))
        XCTAssertTrue(HiveHIGPolicy.motionGuidelinesURL.contains("motion"))
        XCTAssertTrue(HiveHIGPolicy.onboardingGuidelinesURL.contains("onboarding"))
        XCTAssertTrue(HiveHIGPolicy.writingGuidelinesURL.contains("writing"))
        XCTAssertTrue(HiveHIGPolicy.offeringHelpGuidelinesURL.contains("offering-help"))
        XCTAssertTrue(HiveHIGPolicy.settingsGuidelinesURL.contains("settings"))

        XCTAssertTrue(HiveHIGPolicy.usesSharedSymbolWrapper)
        XCTAssertFalse(HiveHIGPolicy.usesSharedGlassWrapper)
        XCTAssertTrue(HiveHIGPolicy.usesSharedSolidSurfaceWrapper)
        XCTAssertTrue(HiveHIGPolicy.modelOutputIsProposalOnly)
        XCTAssertGreaterThanOrEqual(HiveHIGPolicy.minimumMacTextSize, 15)
        XCTAssertGreaterThanOrEqual(HiveHIGPolicy.minimumMacControlTarget, 40)
        XCTAssertGreaterThanOrEqual(HiveHIGPolicy.minimumTouchControlTarget, 44)
        XCTAssertGreaterThanOrEqual(HiveHIGPolicy.minimumGraphAccessibilityTarget, 44)

        for role in [HiveSurfaceLayerRole.button, .navigation, .toolbar, .search, .commandPalette, .chatSheet, .inspector, .popover, .modal] {
            XCTAssertFalse(HiveHIGPolicy.liquidGlassAllowed(in: role), "\(role.rawValue) should use solid Hive surfaces")
        }
        for role in [HiveSurfaceLayerRole.rawInputList, .wikiProse, .graphCanvas, .contentRow, .settingsRow] {
            XCTAssertFalse(HiveHIGPolicy.liquidGlassAllowed(in: role), "\(role.rawValue) should remain a content layer")
        }
    }

    func testAppleInputDocumentShortcutPolicyIsEncoded() {
        XCTAssertEqual(HiveInputPolicy.sourceDocument, "APPLE INPUT DOC")
        XCTAssertTrue(HiveInputPolicy.followsCoreInputRules)
        XCTAssertTrue(HiveInputPolicy.supportsFullKeyboardAccess)
        XCTAssertTrue(HiveInputPolicy.respectsStandardKeyboardShortcuts)
        XCTAssertTrue(HiveInputPolicy.customShortcutsAreForFrequentCommands)
        XCTAssertTrue(HiveInputPolicy.customDefaultsAvoidControlAsPrimaryModifier)
        XCTAssertTrue(HiveInputPolicy.customDefaultsAvoidSystemReservedCombos)
        XCTAssertEqual(HiveInputPolicy.normalizedShortcut("Command Option A"), "option command a")
        let parsed = HiveKeyboardShortcut.parse("⌘ ⌥ a")
        XCTAssertEqual(parsed?.storageValue, "Option Command A")
        XCTAssertEqual(parsed?.modifiers, Set([HiveShortcutModifier.command, .option]))
        XCTAssertEqual(parsed?.key, "A")

        for command in HiveCommand.allCases {
            XCTAssertTrue(
                HiveInputPolicy.defaultShortcutIsCompliant(commandID: command.id, shortcut: command.defaultShortcut),
                "\(command.rawValue) default shortcut \(command.defaultShortcut) conflicts with Apple input guidance"
            )
        }
        XCTAssertFalse(HiveInputPolicy.defaultShortcutIsCompliant(commandID: "chat", shortcut: "Command Shift A"))
        XCTAssertFalse(HiveInputPolicy.defaultShortcutIsCompliant(commandID: "fileAnswer", shortcut: "Command Shift S"))
        XCTAssertFalse(HiveInputPolicy.defaultShortcutIsCompliant(commandID: "downloadAttachments", shortcut: "Control Shift D"))
    }

    func testSolidPreviewSurfaceButtonsAreCentralizedAndAppliedToControls() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let design = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveDesignSystem.swift"))
        let appleNative = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveAppleNative.swift"))
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let overlays = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))
        let rawInputs = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/RawInputsSurface.swift"))
        let wiki = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/WikiSurface.swift"))
        let graph = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))

        XCTAssertTrue(design.contains("case button"))
        XCTAssertTrue(design.contains("case .button, .navigation, .toolbar, .search"))
        XCTAssertTrue(appleNative.contains("public struct HiveGlassButtonStyle: ButtonStyle"))
        XCTAssertGreaterThanOrEqual(appleNative.components(separatedBy: "HiveLiquidGlassSurface(placement: .button)").count - 1, 2)
        XCTAssertFalse(appleNative.contains(".fill(.ultraThinMaterial)"))
        XCTAssertFalse(appleNative.contains(".glassEffect"))
        XCTAssertFalse(appleNative.contains("GlassEffectContainer"))
        XCTAssertFalse(appleNative.contains(".thinMaterial"))
        XCTAssertFalse(appleNative.contains("blur(radius"))
        XCTAssertTrue(appleNative.contains("solidSurfaceBody(policy: policy)"))
        XCTAssertTrue(appleNative.contains("var solidFill: Color"))

        XCTAssertTrue(macRoot.contains(".buttonStyle(HiveControlPressStyle())"))
        XCTAssertFalse(macRoot.contains(".buttonStyle(HiveGlassButtonStyle(active: model.selectedSurface == surface, compact: true))"))
        XCTAssertTrue(overlays.contains(".modifier(HiveGlassShell(level: .commandPalette))"))
        XCTAssertTrue(overlays.contains(".buttonStyle(HiveGlassButtonStyle(active: true))"))
        XCTAssertTrue(rawInputs.contains(".buttonStyle(HiveGlassButtonStyle(active: isWorking))"))
        XCTAssertTrue(wiki.contains(".buttonStyle(HiveGlassButtonStyle(active: hovering))"))
        XCTAssertTrue(graph.contains(".buttonStyle(HiveControlPressStyle())"))
        XCTAssertFalse(graph.contains(".buttonStyle(HiveGlassButtonStyle(active: active))"))

        for source in [appleNative, macRoot, overlays, rawInputs, wiki, graph] {
            XCTAssertFalse(source.contains(".buttonStyle(.bordered"))
            XCTAssertFalse(source.contains(".buttonStyle(.borderedProminent"))
            XCTAssertFalse(source.contains(".buttonStyle(.borderless"))
        }
    }

    func testAppleDesignDocumentPolicyIsEncodedAndApplied() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let design = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveDesignSystem.swift"))
        let appleNative = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveAppleNative.swift"))
        let rawInputs = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/RawInputsSurface.swift"))
        let graph = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))
        let overlays = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))

        XCTAssertEqual(HiveDesignDocumentPolicy.sourceDocument, "APPLE DESIGN DOC")
        XCTAssertTrue(HiveDesignDocumentPolicy.followsCoreDesignRules)
        XCTAssertTrue(HiveDesignDocumentPolicy.toolbarRowIsCompliant(textButtonCount: 2, glyphButtonCount: 1))
        XCTAssertFalse(HiveDesignDocumentPolicy.toolbarRowIsCompliant(textButtonCount: 3, glyphButtonCount: 1))
        XCTAssertTrue(HiveDesignDocumentPolicy.fontSizeIsReadable(15))
        XCTAssertFalse(HiveDesignDocumentPolicy.fontSizeIsReadable(14))
        XCTAssertTrue(HiveDesignDocumentPolicy.fontSizeIsReadable(12, isDecorativeOrBadge: true))

        XCTAssertTrue(design.contains("public enum HiveDesignDocumentPolicy"))
        XCTAssertTrue(design.contains("solidHoneyObsidianSurfacesOnly"))
        XCTAssertTrue(design.contains("typographyUsesTwoRegisters"))
        XCTAssertTrue(design.contains("typographyUsesSystemForControls"))
        XCTAssertTrue(design.contains("typographyUsesSerifOnlyForAuthoredMemory"))
        XCTAssertTrue(design.contains("maximumTextButtonsInToolbarRow = 2"))
        XCTAssertFalse(macRoot.contains("HiveToolbarIconButton(.importAction, title: \"Add Sources...\""))
        XCTAssertFalse(macRoot.contains("HiveToolbarIconButton(.command, title: \"Commands\", accessibilityLabel: \"Open Command Palette\""))
        XCTAssertFalse(macRoot.contains("HiveToolbarIconButton(.chat, title: \"Ask\""))
        XCTAssertFalse(macRoot.contains("private var shouldShowFloatingAskButton: Bool"))
        XCTAssertFalse(macRoot.contains("floatingAskButton"))
        XCTAssertTrue(macRoot.contains("private var chatSidePanel: some View"))
        XCTAssertFalse(macRoot.contains("HiveToolbarIconButton(.command, title: \"Commands…\""))
        XCTAssertTrue(appleNative.contains(".font(HiveTypography.chromeSearch)"))
        XCTAssertTrue(rawInputs.contains(".font(HiveTypography.memoryEditor)"))
        XCTAssertTrue(graph.contains(".font(HiveTypography.chromeSearch)"))
        XCTAssertTrue(overlays.contains(".font(HiveTypography.chromeAction)"))
        XCTAssertTrue(macRoot.contains(".font(HiveTypography.sidebarItem(selected: selected))"))
        XCTAssertFalse(appleNative.contains(".font(.custom("))
        XCTAssertFalse(appleNative.contains("nectarBodyLight"))
        XCTAssertFalse(appleNative.contains("nectarDisplay"))
        for body in [rawInputs, graph, overlays, macRoot] {
            XCTAssertFalse(body.contains(".font(.custom("))
            XCTAssertFalse(body.contains(".font(.system(size:"))
            XCTAssertFalse(body.contains(".font(.body"))
            XCTAssertFalse(body.contains(".font(.callout"))
            XCTAssertFalse(body.contains(".font(.headline"))
            XCTAssertFalse(body.contains(".font(.title"))
            XCTAssertFalse(body.contains(".font(.footnote"))
            XCTAssertFalse(body.contains(".width(.condensed)"))
            XCTAssertFalse(body.contains("nectarBodyLight"))
            XCTAssertFalse(body.contains("nectarDisplay"))
        }
    }

    func testAppleNativeSymbolCatalogIsApprovedAndAccessible() {
        let approved: Set<String> = [
            "archivebox.fill", "arrow.clockwise", "arrow.counterclockwise", "arrow.down.doc",
            "arrow.triangle.2.circlepath", "arrow.triangle.merge", "apple.logo", "bolt.fill",
            "books.vertical.fill", "book.fill",
            "bubble.left.and.bubble.right.fill", "camera.viewfinder", "checkmark.circle",
            "checkmark.circle.fill", "chevron.down", "circle", "circle.fill", "clock", "clock.badge",
            "cloud", "command", "control", "doc.on.doc", "doc.text.magnifyingglass",
            "ellipsis.circle", "exclamationmark.triangle", "eye.fill",
            "externaldrive.fill", "gearshape.fill", "hexagon", "hexagon.fill", "info.circle.fill",
            "internaldrive", "keyboard", "leaf.fill", "line.3.horizontal.decrease.circle",
            "link", "macwindow.on.rectangle", "magnifyingglass", "magnifyingglass.circle", "mic.fill", "minus.circle",
            "minus.magnifyingglass",
            "option", "paperclip", "paperplane.fill", "pencil.and.outline", "person.crop.circle.badge.checkmark", "plus.circle.fill",
            "plus.magnifyingglass",
            "rectangle.on.rectangle.angled", "rectangle.portrait.and.arrow.right", "scope", "shift", "sidebar.left",
            "slider.horizontal.3", "sparkles", "speaker.wave.2", "square.and.arrow.down.fill",
            "square.and.pencil", "star.fill", "star.slash", "trash.fill",
            "waveform.circle.fill", "xmark.circle.fill"
        ]
        XCTAssertEqual(Set(HiveSymbolName.allCases.map(\.rawValue)), approved)
        for symbol in HiveSymbolName.allCases {
            XCTAssertFalse(symbol.accessibilityTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        XCTAssertEqual(HiveSymbolName.sourceStatus(.resting), .status)
        XCTAssertEqual(HiveSymbolName.sourceStatus(.foraging), .runMaintenance)
        XCTAssertEqual(HiveSymbolName.sourceStatus(.digesting), .indexedOnly)
        XCTAssertEqual(HiveSymbolName.sourceStatus(.synthesizing), .synthesizing)
        XCTAssertEqual(HiveSymbolName.sourceStatus(.confused), .conflict)
        XCTAssertEqual(HiveSymbolName.sourceStatus(.understood), .confirmed)
    }

    func testSymbolMotionDeclaresReducedMotionCompliance() {
        for motion in HiveSymbolMotion.allCases {
            XCTAssertTrue(motion.respectsReducedMotion)
        }
    }

    func testAppleSpeechInputIsWiredIntoAskSurfaces() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let speechInput = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveSpeechInputController.swift"))
        let appleNative = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveAppleNative.swift"))
        let overlays = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))
        let rawInputs = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/RawInputsSurface.swift"))
        let buildScript = try String(contentsOf: root.appendingPathComponent("scripts/build_app.sh"))

        XCTAssertTrue(speechInput.contains("AVAudioEngine()"))
        XCTAssertTrue(speechInput.contains("SFSpeechAudioBufferRecognitionRequest()"))
        XCTAssertTrue(speechInput.contains("SFSpeechRecognizer.requestAuthorization"))
        XCTAssertTrue(speechInput.contains("AVCaptureDevice.requestAccess(for: .audio)"))
        XCTAssertTrue(speechInput.contains("request.shouldReportPartialResults = true"))
        XCTAssertTrue(speechInput.contains("recognizer.supportsOnDeviceRecognition"))
        XCTAssertTrue(speechInput.contains("request.requiresOnDeviceRecognition = true"))
        XCTAssertTrue(speechInput.contains("AVSpeechSynthesizer"))
        XCTAssertTrue(speechInput.contains("HiveSpeechOutputController"))
        XCTAssertTrue(speechInput.contains("public final class SwarmVoiceManager"))
        XCTAssertTrue(speechInput.contains("getHighQualityVoices() -> [AVSpeechSynthesisVoice]"))
        XCTAssertTrue(speechInput.contains("voice.quality == .enhanced"))
        XCTAssertTrue(speechInput.contains("voice.quality == .premium"))
        XCTAssertTrue(speechInput.contains("localizedCaseInsensitiveContains(\"personal\")"))
        XCTAssertTrue(speechInput.contains("private static let sharedSynthesizer = AVSpeechSynthesizer()"))
        XCTAssertTrue(speechInput.contains("synthesizer.stopSpeaking(at: .immediate)"))
        XCTAssertTrue(speechInput.contains("appendStreamingToken"))
        XCTAssertTrue(speechInput.contains("speakStreamingResponse<Tokens: AsyncSequence>"))
        XCTAssertTrue(speechInput.contains("finishStreamingResponse"))
        XCTAssertTrue(speechInput.contains("utterance.rate = 0.52"))
        XCTAssertTrue(speechInput.contains("AVSpeechSynthesisVoice(identifier: identifier)"))
        XCTAssertTrue(speechInput.contains("@State private var isHovered = false"))
        XCTAssertTrue(speechInput.contains(".onHover { hovering in"))
        XCTAssertTrue(speechInput.contains(".scaleEffect(reduceMotion ? 1 : (isHovered ? 1.045 : 1))"))
        XCTAssertTrue(speechInput.contains("Use keyboard dictation for this field."))
        XCTAssertTrue(appleNative.contains("@StateObject private var speechInput = HiveSpeechInputController()"))
        XCTAssertTrue(appleNative.contains(".scaleEffect(reduceMotion ? 1 : (isHovered ? 1.045 : 1))"))
        XCTAssertTrue(appleNative.contains("HiveSpeechInputButton(speechInput: speechInput, text: $draft, compact: true)"))
        XCTAssertTrue(overlays.contains("@StateObject private var speechInput = HiveSpeechInputController()"))
        XCTAssertTrue(overlays.contains("HiveSpeechInputButton(speechInput: speechInput, text: $text, compact: true)"))
        XCTAssertTrue(overlays.contains("public struct HiveLiveAssistantOverlay"))
        XCTAssertTrue(overlays.contains("Hello Hive, ask, capture, or remember"))
        XCTAssertTrue(overlays.contains("HiveSpeechInputButton(speechInput: speechInput, text: $text, compact: true)"))
        XCTAssertTrue(overlays.contains("onStartRecording:"))
        XCTAssertTrue(overlays.contains("speechOutput.interruptForUserSpeech()"))
        XCTAssertTrue(overlays.contains("speechOutput.speakSwarmResponse("))
        XCTAssertTrue(overlays.contains("@AppStorage(SwarmVoiceSettingsStore.selectedVoiceIdentifierKey)"))
        XCTAssertTrue(overlays.contains("Section(\"Swarm Live\")"))
        XCTAssertTrue(overlays.contains("Picker(\"Voice\""))
        XCTAssertTrue(rawInputs.contains("HiveVoiceNoteRecorder"))
        XCTAssertTrue(buildScript.contains("NSMicrophoneUsageDescription"))
        XCTAssertTrue(buildScript.contains("NSSpeechRecognitionUsageDescription"))
        XCTAssertTrue(buildScript.contains("press a mic button to dictate into Ask"))
    }

    func testHiveLiveAssistantRoutesSpeechScreenAndNotesIntoBackend() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appModel = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveAppModel.swift"))
        let overlays = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let app = try String(contentsOf: root.appendingPathComponent("Sources/HiveApp/HiveApp.swift"))

        XCTAssertTrue(appModel.contains("@Published public var liveVisible = false"))
        XCTAssertTrue(appModel.contains("@Published public var liveText = \"\""))
        XCTAssertTrue(appModel.contains("@Published public var liveSpokenText = \"\""))
        XCTAssertTrue(appModel.contains("publishLiveSpokenAnswer"))
        XCTAssertTrue(appModel.contains("public enum HiveLiveAssistantRouter"))
        XCTAssertTrue(appModel.contains("\"hello hive\""))
        XCTAssertTrue(appModel.contains("case captureCurrentPage(command: String, followUpQuestion: String?)"))
        XCTAssertTrue(appModel.contains("captureCurrentPage(command: command, followUpQuestion: followUpQuestion)"))
        XCTAssertTrue(appModel.contains("shouldFetchCurrentPageText(command: command, pageURL: capture.pageURL)"))
        XCTAssertTrue(appModel.contains("HiveStartupSourcePluginBackend().execute"))
        XCTAssertTrue(appModel.contains("ingestText(text)"))
        XCTAssertTrue(appModel.contains("ask(question)"))
        XCTAssertTrue(appModel.contains("graphSearchVisible = true"))
        XCTAssertTrue(overlays.contains("case idle"))
        XCTAssertTrue(overlays.contains("case listening"))
        XCTAssertTrue(overlays.contains("case thinking"))
        XCTAssertTrue(overlays.contains("HiveSymbolButton(.screenshot"))
        XCTAssertTrue(overlays.contains("HiveSymbolButton(.speak"))
        XCTAssertTrue(overlays.contains("HiveSpeechOutputController"))
        XCTAssertTrue(overlays.contains(".onChange(of: spokenSequence)"))
        XCTAssertTrue(macRoot.contains("HiveLiveAssistantOverlay("))
        XCTAssertTrue(macRoot.contains("spokenText: model.liveSpokenText"))
        XCTAssertTrue(app.contains("model.openLiveAssistant()"))
        XCTAssertTrue(app.contains("Button(\"Hive Live\")"))
        XCTAssertTrue(app.contains(".keyboardShortcut(shortcutKey(for: .live), modifiers: shortcutModifiers(for: .live))"))
        XCTAssertTrue(app.contains("HiveLiveHotKeyController"))
        XCTAssertTrue(app.contains("HiveLiveHotKeyBootstrap"))
        XCTAssertTrue(app.contains("RegisterEventHotKey"))
        XCTAssertTrue(app.contains("HiveCommandShortcutStore.shortcut(for: .live)"))
    }

    func testFigmaBoardDocumentsHIGConstraints() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let board = try String(contentsOf: root.appendingPathComponent("Design/Figma/HiveAppleNativeLiquidGlassBoard.md"))
        for required in [
            "Hierarchy",
            "Harmony",
            "Consistency",
            "Accessibility",
            "Material restraint",
            "Solid honey and obsidian surfaces replace translucent app chrome",
            "HiveLiquidGlassSurface compatibility wrapper renders solid surfaces",
            "HiveSymbol",
            "13 construction layers",
            "one centered point-up glass hex repeated at 100%, 75%, and 50%"
        ] {
            XCTAssertTrue(board.contains(required), "Figma board is missing \(required)")
        }
    }

    func testGeneratedAppIconAssetsExist() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let iconRoot = root.appendingPathComponent("Sources/HiveApp/Resources/AppIcon")
        let iconDocument = iconRoot.appendingPathComponent("Hive.icon")
        let figmaRoot = root.appendingPathComponent("Design/Figma/HiveGlassStackLogo")
        let previewRoot = iconRoot.appendingPathComponent("IconComposerPreviews")
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconDocument.appendingPathComponent("icon.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconRoot.appendingPathComponent("IconComposerSpec.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: figmaRoot.appendingPathComponent("HiveGlassStackLogo.figma-source.svg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: figmaRoot.appendingPathComponent("IconComposerLayerMap.json").path))
        let foregroundLayers = [
            "large-glass-hex", "medium-glass-hex", "small-glass-hex"
        ]
        for layerName in foregroundLayers {
            XCTAssertTrue(FileManager.default.fileExists(atPath: iconDocument.appendingPathComponent("Assets/\(layerName).png").path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: figmaRoot.appendingPathComponent("IconComposerExports/\(layerName).png").path))
        }
        let layerMapData = try? Data(contentsOf: figmaRoot.appendingPathComponent("IconComposerLayerMap.json"))
        let layerMap = layerMapData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let figmaLayers = layerMap?["figmaLayers"] as? [String] ?? []
        XCTAssertEqual(layerMap?["figmaLayerCount"] as? Int, 13)
        XCTAssertEqual(layerMap?["physicalForegroundLayerCount"] as? Int, 3)
        XCTAssertEqual(layerMap?["iconComposerForegroundGroupCount"] as? Int, 3)
        XCTAssertEqual(layerMap?["stackedHexCellCount"] as? Int, 3)
        XCTAssertEqual(layerMap?["hexCellCount"] as? Int, 3)
        XCTAssertEqual(layerMap?["hexScaleRatios"] as? [Double], [1.0, 0.75, 0.5])
        XCTAssertEqual(layerMap?["allHexCenters"] as? [[Int]], [[512, 512], [512, 512], [512, 512]])
        XCTAssertEqual(layerMap?["hasShadows"] as? Bool, false)
        XCTAssertEqual(layerMap?["hasSixAppearanceExports"] as? Bool, true)
        XCTAssertEqual(layerMap?["sfSymbolBaseline"] as? String, "hexagon.fill")
        XCTAssertEqual(figmaLayers.count, 13)
        for layerName in figmaLayers {
            XCTAssertTrue(FileManager.default.fileExists(atPath: figmaRoot.appendingPathComponent("FigmaLayerExports/\(layerName).png").path))
        }
        for previewName in [
            "Preview-normal.png", "Preview-dark.png", "Preview-light-tinted.png",
            "Preview-dark-tinted.png", "Preview-light-clear.png", "Preview-dark-clear.png"
        ] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: previewRoot.appendingPathComponent(previewName).path))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconRoot.appendingPathComponent("Hive.icns").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconRoot.appendingPathComponent("Hive.iconset/icon_512x512@2x.png").path))
        let report = HiveIconAssetValidator.validate(appIconRoot: iconRoot)
        XCTAssertTrue(report.isValid, report.problems.joined(separator: "\n"))
        XCTAssertEqual(report.groupCount, 3)
        XCTAssertEqual(report.layerCount, 3)
        let layerMapText = try? String(contentsOf: figmaRoot.appendingPathComponent("IconComposerLayerMap.json"))
        XCTAssertTrue(layerMapText?.contains("\"figmaLayerCount\": 13") == true)
        XCTAssertTrue(layerMapText?.contains("\"physicalForegroundLayerCount\": 3") == true)
        XCTAssertTrue(layerMapText?.contains("\"stackedHexCellCount\": 3") == true)
        XCTAssertTrue(layerMapText?.contains("\"hexCellCount\": 3") == true)
        XCTAssertTrue(layerMapText?.contains("\"hexScaleRatios\": [1.0, 0.75, 0.5]") == true)
        XCTAssertTrue(layerMapText?.contains("\"allHexCenters\": [[512, 512], [512, 512], [512, 512]]") == true)
        XCTAssertTrue(layerMapText?.contains("\"hasShadows\": false") == true)
        XCTAssertTrue(layerMapText?.contains("SF Symbols hexagon.fill proportions") == true)
        XCTAssertTrue(layerMapText?.contains("one centered point-up glass hex repeated three times") == true)
        let svg = try? String(contentsOf: figmaRoot.appendingPathComponent("HiveGlassStackLogo.figma-source.svg"))
        XCTAssertEqual(svg?.components(separatedBy: "data-hex-cell-mask=\"true\"").count ?? 0, 4)
        XCTAssertTrue(svg?.contains("\"sfSymbolBaseline\":\"hexagon.fill\"") == true)
        XCTAssertTrue(svg?.contains("13-reflection-small-hex") == true)
        XCTAssertTrue(svg?.contains("\"hasShadows\":false") == true)
        XCTAssertFalse(svg?.contains("shadow") == true)
    }

    func testAppIconGeneratorRejectsLegacyLineBasedDirections() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let script = try String(contentsOf: root.appendingPathComponent("scripts/render_app_icon.swift"))
        let iconRoot = root.appendingPathComponent("Sources/HiveApp/Resources/AppIcon/Hive.icon")
        let manifest = try String(contentsOf: root.appendingPathComponent("Sources/HiveApp/Resources/AppIcon/IconComposerSpec.json"))
        let iconJSON = try String(contentsOf: iconRoot.appendingPathComponent("icon.json"))

        for banned in ["Hive Memory Bloom", "capsule", "blob-only", "frosted-lens", "hexPath", "roundedDiamondPath", "strokePath", "addLine", "inner-refraction", "hex-outline"] {
            XCTAssertFalse(script.contains(banned), "icon generator still contains \(banned)")
            XCTAssertFalse(manifest.contains(banned), "icon manifest still contains \(banned)")
            XCTAssertFalse(iconJSON.contains(banned), "native icon document still contains \(banned)")
        }
        XCTAssertTrue(manifest.contains("dark-clear"))
        XCTAssertTrue(manifest.contains("Hive Glass Stack"))
        XCTAssertTrue(manifest.contains("\"previewExportSource\": \"Icon Composer ictool\""))
        XCTAssertTrue(manifest.contains("\"physicalForegroundLayerCount\": 3"))
        XCTAssertTrue(manifest.contains("\"iconComposerForegroundGroupCount\": 3"))
        XCTAssertTrue(manifest.contains("\"stackedHexCellCount\": 3"))
        XCTAssertTrue(manifest.contains("\"hexCellCount\": 3"))
        XCTAssertTrue(manifest.contains("\"hexScaleRatios\": [1.0, 0.75, 0.5]"))
        XCTAssertTrue(manifest.contains("\"sfSymbolBaseline\": \"hexagon.fill\""))
        XCTAssertTrue(manifest.contains("Figma foreground hex assets"))
        XCTAssertTrue(manifest.contains("\"physicalForegroundGroups\": 3"))
        XCTAssertTrue(manifest.contains("\"hasShadows\": false"))
        XCTAssertFalse(iconJSON.contains("\"shadow\""))
        XCTAssertFalse(FileManager.default.fileExists(atPath: iconRoot.appendingPathComponent("Layers/frosted-lens.png").path))
    }

    func testAppIntentRoutesCoverCoreSystemActions() {
        XCTAssertEqual(
            Set(HiveIntentRoute.allCases),
            [
                .requiresLogin,
                .quickCapture,
                .feedHive,
                .importEvidence,
                .askHive,
                .openWiki,
                .showGraph,
                .consolidateArticles,
                .captureCurrentPage,
                .downloadAttachments,
                .summarizeRecentInputs,
                .runMemoryMaintenance,
                .toggleMenuBar
            ]
        )

        XCTAssertTrue(HiveAppShortcutCatalog.respectsSystemShortcutLimit)
        XCTAssertTrue(HiveAppShortcutCatalog.routesAreUnique)
        XCTAssertEqual(HiveAppShortcutCatalog.orderedShortcuts.first?.route, .feedHive)
        XCTAssertEqual(HiveAppShortcutCatalog.shortcuts.count, 10)
        XCTAssertTrue(HiveAppShortcutCatalog.allPhrasesIncludeAppName)
        XCTAssertTrue(HiveAppShortcutCatalog.allDialoguesSupportAudioOnlyUse)
        XCTAssertTrue(HiveAppShortcutCatalog.allSymbolsAreDeclaredInDesignSystem)
        XCTAssertNil(HiveAppShortcutCatalog.descriptor(for: .toggleMenuBar))
        XCTAssertNil(HiveAppShortcutCatalog.descriptor(for: .importEvidence))
    }

    func testAppleEfficiencySystemSurfacesFollowDocumentPolicy() {
        XCTAssertTrue(HiveSystemControlCatalog.containsOnlyGlanceableControls)
        XCTAssertTrue(HiveSystemControlCatalog.allSensitiveControlsAreProtected)
        XCTAssertEqual(Set(HiveSystemControlCatalog.controls.map(\.kind)), Set(HiveSystemControlKind.allCases))
        XCTAssertTrue(HiveSystemControlCatalog.controls.allSatisfy(\.usesSymbolAnimationForStateChange))
        XCTAssertTrue(HiveSystemControlCatalog.controls.allSatisfy(\.hidesSensitiveContentWhenLocked))

        XCTAssertTrue(HiveLiveActivityCatalog.allActivitiesAreBoundedAndGlanceable)
        XCTAssertTrue(HiveLiveActivityCatalog.activities.allSatisfy { $0.maximumDurationHours <= 8 })
        XCTAssertTrue(HiveLiveActivityCatalog.activities.allSatisfy { $0.lockScreenMinimumMargin >= 14 })
        XCTAssertTrue(HiveLiveActivityCatalog.activities.allSatisfy { $0.maximumCustomActions <= 4 })

        let notifications = HiveSystemExperiencePolicy.notifications
        XCTAssertTrue(notifications.followsEfficiencyGuidance)
        XCTAssertLessThanOrEqual(notifications.maximumCustomActions, 4)
    }

    func testWidgetsAndComplicationsFollowEfficiencyGuidance() {
        XCTAssertTrue(HiveWidgetDesignPolicy.usesSystemFontAndSFSymbols)
        XCTAssertTrue(HiveWidgetDesignPolicy.marginsAreConcentricWithContainer)
        XCTAssertTrue(HiveWidgetDesignPolicy.avoidsAppLikeLayouts)
        XCTAssertTrue(HiveWidgetDesignPolicy.supportsRealisticPreviews)
        XCTAssertTrue(HiveWidgetDesignPolicy.supportsAlwaysOnLowLuminanceContrast)
        XCTAssertTrue(HiveWidgetDesignPolicy.neverUsesColorAsOnlySignal)
        XCTAssertTrue(HiveWidgetDesignPolicy.keepsComplexityInsideMainApp)
        XCTAssertTrue(HiveWidgetDesignPolicy.descriptionIsValid("See what Hive recently learned."))
        XCTAssertFalse(HiveWidgetDesignPolicy.descriptionIsValid("This widget shows recent memories."))
        XCTAssertEqual(HiveWidgetDesignPolicy.maximumInteractiveTargets(for: .accessoryInline), 1)

        let widget = HiveWidgetSnapshot(
            family: .small,
            stateText: "Ready",
            memoryCount: 4,
            claimTitles: ["One", "Two", "Three", "Four"],
            description: "Open recent memory",
            interactiveTargetCount: 1
        )
        XCTAssertEqual(widget.claimTitles.count, 3)
        XCTAssertTrue(widget.isGlanceable)
        XCTAssertTrue(widget.supportsRequiredAppearances)
        XCTAssertTrue(widget.redactsPrivateContentWhenLocked)
        XCTAssertEqual(Set(HiveWidgetAppearance.allCases), [.fullColor, .clear, .tinted, .accented, .vibrant, .lowLight])

        XCTAssertTrue(HiveWatchComplicationCatalog.supportsAllCoreFamilies)
        XCTAssertTrue(HiveWatchComplicationCatalog.deepLinksAreDistinct)
        XCTAssertTrue(HiveWatchComplicationCatalog.alwaysOnSafe)
    }

    func testIPadPackagingDesignAndInputGuidanceAreReady() throws {
        XCTAssertTrue(HiveIPadDesignPolicy.defaultPolicy.followsIPadGuidance)
        XCTAssertEqual(HiveIPadDesignPolicy.defaultPolicy.supportedInputModes, Set(HiveIPadInputMode.allCases))
        XCTAssertTrue(HiveIPadPackagingManifest.current.isReadyForIPadPackaging)
        XCTAssertFalse(HiveIPadPackagingManifest.current.requiresFullScreen)
        XCTAssertTrue(HiveIPadPackagingManifest.current.supportedDeviceFamilies.contains("iPad"))
        XCTAssertTrue(HiveIPadPackagingManifest.current.supportedInterfaceOrientations.isSuperset(of: [
            "portrait",
            "portraitUpsideDown",
            "landscapeLeft",
            "landscapeRight"
        ]))

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: root.appendingPathComponent("Package.swift"))
        let mobileSupport = try String(contentsOf: root.appendingPathComponent("Sources/HiveMobileApp/HiveMobileSupport.swift"))
        let widgetSupport = try String(contentsOf: root.appendingPathComponent("Sources/HiveWidgets/HiveWidgetSupport.swift"))
        let packaging = try String(contentsOf: root.appendingPathComponent("Sources/HiveMobileApp/Resources/HiveIPadPackaging.json"))
        let plist = try String(contentsOf: root.appendingPathComponent("Sources/HiveMobileApp/Resources/MobileAppInfo.plist"))

        XCTAssertTrue(package.contains(".iOS(.v17)"))
        XCTAssertTrue(package.contains("name: \"HiveMobileApp\""))
        XCTAssertTrue(package.contains(".process(\"Resources\")"))
        XCTAssertTrue(mobileSupport.contains("public struct HiveIPadRootView"))
        XCTAssertTrue(mobileSupport.contains("NavigationSplitView"))
        XCTAssertTrue(mobileSupport.contains("@Environment(\\.horizontalSizeClass)"))
        XCTAssertTrue(mobileSupport.contains("@Environment(\\.dynamicTypeSize)"))
        XCTAssertTrue(mobileSupport.contains(".onDrop(of: [UTType.fileURL.identifier, UTType.text.identifier]"))
        XCTAssertTrue(mobileSupport.contains(".keyboardShortcut(\"f\", modifiers: [.command])"))
        XCTAssertTrue(mobileSupport.contains("public struct HiveIPadPencilCanvas"))
        XCTAssertTrue(mobileSupport.contains("PKCanvasView"))
        XCTAssertTrue(widgetSupport.contains(".systemExtraLarge"))
        XCTAssertTrue(packaging.contains("\"requiresFullScreen\": false"))
        XCTAssertTrue(packaging.contains("\"supportsStageManager\": true"))
        XCTAssertTrue(packaging.contains("\"applePencil\""))
        XCTAssertTrue(packaging.contains("\"dragAndDrop\""))
        XCTAssertTrue(plist.contains("<key>UIDeviceFamily</key>"))
        XCTAssertTrue(plist.contains("<integer>2</integer>"))
        XCTAssertTrue(plist.contains("<key>UIRequiresFullScreen</key>"))
        XCTAssertTrue(plist.contains("<false/>"))
        XCTAssertTrue(plist.contains("<key>UIApplicationSupportsIndirectInputEvents</key>"))
    }

    func testIPhonePackagingDesignAndSystemIntegrationAreReady() throws {
        XCTAssertTrue(HiveIPhoneDesignPolicy.defaultPolicy.followsIPhoneGuidance)
        XCTAssertEqual(HiveIPhoneDesignPolicy.defaultPolicy.supportedInputModes, Set(HiveIPhoneInputMode.allCases))
        XCTAssertTrue(HiveIPhonePackagingManifest.current.isReadyForIPhonePackaging)
        XCTAssertFalse(HiveIPhonePackagingManifest.current.requiresFullScreen)
        XCTAssertTrue(HiveIPhonePackagingManifest.current.supportedDeviceFamilies.contains("iPhone"))
        XCTAssertTrue(HiveIPhonePackagingManifest.current.supportedInterfaceOrientations.isSuperset(of: [
            "portrait",
            "landscapeLeft",
            "landscapeRight"
        ]))

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: root.appendingPathComponent("Package.swift"))
        let mobileSupport = try String(contentsOf: root.appendingPathComponent("Sources/HiveMobileApp/HiveMobileSupport.swift"))
        let appIntents = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/HiveAppIntents.swift"))
        let packaging = try String(contentsOf: root.appendingPathComponent("Sources/HiveMobileApp/Resources/HiveIPhonePackaging.json"))
        let plist = try String(contentsOf: root.appendingPathComponent("Sources/HiveMobileApp/Resources/MobileAppInfo.plist"))

        XCTAssertTrue(package.contains(".iOS(.v17)"))
        XCTAssertTrue(mobileSupport.contains("public struct HiveIPhoneRootView"))
        XCTAssertTrue(mobileSupport.contains("NavigationStack"))
        XCTAssertTrue(mobileSupport.contains("@Environment(\\.dynamicTypeSize)"))
        XCTAssertTrue(mobileSupport.contains("@Environment(\\.verticalSizeClass)"))
        XCTAssertTrue(mobileSupport.contains(".safeAreaInset(edge: .bottom)"))
        XCTAssertTrue(mobileSupport.contains(".swipeActions(edge: .trailing"))
        XCTAssertTrue(mobileSupport.contains(".refreshable"))
        XCTAssertTrue(mobileSupport.contains(".onDrop(of: [UTType.fileURL.identifier, UTType.text.identifier]"))
        XCTAssertTrue(mobileSupport.contains("public struct HiveIPhoneActivityView"))
        XCTAssertTrue(mobileSupport.contains("UIActivityViewController"))
        XCTAssertTrue(mobileSupport.contains("public struct HiveIPhoneMotionCapabilityProbe"))
        XCTAssertTrue(mobileSupport.contains("CMMotionManager"))
        XCTAssertTrue(appIntents.contains("public struct HiveShortcutsProvider: AppShortcutsProvider"))
        XCTAssertTrue(appIntents.contains("AppShortcut("))
        XCTAssertTrue(packaging.contains("\"platform\": \"iOS\""))
        XCTAssertTrue(packaging.contains("\"homeScreenQuickActions\""))
        XCTAssertTrue(packaging.contains("\"spotlight\""))
        XCTAssertTrue(packaging.contains("\"shortcuts\""))
        XCTAssertTrue(packaging.contains("\"activityViews\""))
        XCTAssertTrue(packaging.contains("\"motionSensors\""))
        XCTAssertTrue(packaging.contains("\"primaryActionPlacement\": \"bottomReachZone\""))
        XCTAssertTrue(plist.contains("<integer>1</integer>"))
        XCTAssertTrue(plist.contains("<key>UISupportedInterfaceOrientations</key>"))
        XCTAssertTrue(plist.contains("UIInterfaceOrientationLandscapeRight"))
        XCTAssertTrue(plist.contains("<key>UIApplicationShortcutItems</key>"))
        XCTAssertTrue(plist.contains("UIApplicationShortcutItemIconSymbolName"))
        XCTAssertTrue(plist.contains("<key>NSMotionUsageDescription</key>"))
        XCTAssertTrue(plist.contains("<key>UIApplicationSupportsIndirectInputEvents</key>"))
    }

    func testAppleWatchPackagingCrownNavigationAndComplicationsAreReady() throws {
        let crownPolicy = HiveWatchCrownInteractionPolicy.watchOS10Default
        XCTAssertTrue(crownPolicy.followsWatchOSNavigationGuidance)
        XCTAssertLessThan(crownPolicy.animationDuration(turnsPerSecond: 6), crownPolicy.animationDuration(turnsPerSecond: 0))
        XCTAssertEqual(crownPolicy.normalizedInspectionValue(rawValue: 14, itemCount: 4), 3)
        XCTAssertTrue(crownPolicy.crownPressesAreSystemReserved)

        XCTAssertTrue(HiveWatchNavigationCatalog.followsWatchHierarchyGuidance)
        XCTAssertTrue(HiveWatchNavigationCatalog.screens.allSatisfy(\.usesCrownForVerticalNavigation))
        XCTAssertTrue(HiveWatchNavigationCatalog.screens.allSatisfy(\.supportsTouchFallback))
        XCTAssertTrue(HiveWatchQuickActionCatalog.supportsVoiceCapture)
        XCTAssertTrue(HiveWatchQuickActionCatalog.keepsActionsShort)
        XCTAssertTrue(HiveWatchQuickActionCatalog.followsWatchDictationGuidance)

        let snapshot = HiveWatchSnapshot(
            memoryCount: 12,
            stateText: "Add a source",
            recentClaims: [
                "Work",
                "The user is applying to YC with Hive",
                "Captured memory"
            ],
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(snapshot.recentClaims, ["The user is applying to YC with Hive"])
        XCTAssertTrue(snapshot.isGlanceable)

        let entry = HiveWatchComplicationTimelineEntry(
            date: Date(timeIntervalSince1970: 120),
            family: .rectangular,
            snapshot: snapshot
        )
        XCTAssertEqual(HiveWatchComplicationTimelinePolicy.maximumRefreshWindowMinutes, 5)
        XCTAssertEqual(entry.refreshAfter.timeIntervalSince(entry.date), 300)
        XCTAssertTrue(HiveWatchComplicationTimelinePolicy.isFresh(entry, now: Date(timeIntervalSince1970: 240)))
        XCTAssertTrue(HiveWatchComplicationCatalog.descriptors.allSatisfy { $0.timelineRefreshWindowMinutes <= 5 })

        let manifest = HiveWatchPackagingManifest.current
        XCTAssertTrue(manifest.isReadyForWatchPackaging)
        XCTAssertFalse(manifest.localAIAvailableOnWatch)
        XCTAssertFalse(AIBackendAvailability(platform: .watch).allowsLocalAI)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let package = try String(contentsOf: root.appendingPathComponent("Package.swift"))
        XCTAssertTrue(package.contains(".watchOS(.v10)"))
        XCTAssertTrue(package.contains("condition: .when(platforms: [.macOS])"))
        XCTAssertTrue(package.contains("name: \"HiveWatchApp\""))
        XCTAssertTrue(package.contains(".process(\"Resources\")"))

        let buildScript = try String(contentsOf: root.appendingPathComponent("scripts/build_app.sh"))
        XCTAssertTrue(buildScript.contains("swift build -c \"$CONFIGURATION\" --target HiveWatchApp"))

        let watchSupport = try String(contentsOf: root.appendingPathComponent("Sources/HiveWatchApp/HiveWatchSupport.swift"))
        XCTAssertTrue(watchSupport.contains(".tabViewStyle(.verticalPage)"))
        XCTAssertTrue(watchSupport.contains(".digitalCrownRotation("))
        XCTAssertTrue(watchSupport.contains("isHapticFeedbackEnabled: true"))
        XCTAssertTrue(watchSupport.contains("WKInterfaceDevice.current().play(.click)"))
        XCTAssertTrue(watchSupport.contains("usesSystemDictationForTextFields"))
        XCTAssertTrue(watchSupport.contains("customSpeechRecognitionRunsOnCompanion"))
        XCTAssertTrue(watchSupport.contains("avoidsLocalSpeechRecognizerDependency"))

        let resourceRoot = root.appendingPathComponent("Sources/HiveWatchApp/Resources", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resourceRoot.appendingPathComponent("HiveWatchPackaging.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: resourceRoot.appendingPathComponent("WatchAppInfo.plist").path))
        let packaging = try String(contentsOf: resourceRoot.appendingPathComponent("HiveWatchPackaging.json"))
        XCTAssertTrue(packaging.contains("\"primaryInput\": \"digitalCrown\""))
        XCTAssertTrue(packaging.contains("\"maximumRefreshWindowMinutes\": 5"))
        XCTAssertTrue(packaging.contains("\"localAIAvailableOnWatch\": false"))
    }

    func testLayoutGlassGraphAndAIPoliciesAreCentralized() throws {
        XCTAssertEqual(HiveLayoutMetrics.sidebarWidth, 180)
        XCTAssertEqual(HiveLayoutMetrics.sourceInspectorWidth, 360)
        XCTAssertEqual(HiveLayoutMetrics.smallCornerRadius, 6)
        XCTAssertEqual(HiveLayoutMetrics.controlCornerRadius, 6)
        XCTAssertEqual(HiveLayoutMetrics.rowCornerRadius, 10)
        XCTAssertEqual(HiveLayoutMetrics.surfaceCornerRadius, 14)
        XCTAssertEqual(HiveLayoutMetrics.prominentSurfaceCornerRadius, 20)
        XCTAssertGreaterThanOrEqual(HiveReadableSurface.wikiArticle.horizontalPadding, 48)
        XCTAssertFalse(HiveReadableSurface.wikiArticle.usesGlass)
        XCTAssertFalse(HiveReadableSurface.inspector.usesGlass)
        XCTAssertEqual(HiveGlassPlacement.button.cornerRadius, HiveLayoutMetrics.controlCornerRadius)
        XCTAssertEqual(HiveGlassPlacement.toolbar.cornerRadius, HiveLayoutMetrics.rowCornerRadius)
        XCTAssertEqual(HiveGlassPlacement.inspector.cornerRadius, HiveLayoutMetrics.prominentSurfaceCornerRadius)

        let glass = HiveGlassPolicy(
            placement: .toolbar,
            reduceTransparency: false,
            reduceMotion: false,
            colorSchemeContrast: .standard
        )
        XCTAssertFalse(glass.usesSystemGlass)
        XCTAssertFalse(glass.usesInteractiveGlass)
        XCTAssertEqual(HiveAtmospherePolicy.targetMood, "cozy but powerful")
        XCTAssertTrue(HiveAtmospherePolicy.followsCozyPowerRules)
        XCTAssertTrue(HiveAtmospherePolicy.usesBurnishedHoneyLightMode)
        XCTAssertTrue(HiveAtmospherePolicy.surfacesUseWarmDepth)
        XCTAssertTrue(HiveAtmospherePolicy.controlsFeelWeightyNotLoud)
        let accessibleFallback = HiveGlassPolicy(
            placement: .toolbar,
            reduceTransparency: true,
            reduceMotion: false,
            colorSchemeContrast: .standard
        )
        XCTAssertFalse(accessibleFallback.usesSystemGlass)

        let graphPolicy = HiveGraphRenderPolicy()
        XCTAssertGreaterThanOrEqual(HiveInteractionPolicy.graphMinimumFramesPerSecond, 60)
        XCTAssertGreaterThanOrEqual(HiveInteractionPolicy.graphPreferredFramesPerSecond, 120)
        XCTAssertGreaterThan(graphPolicy.nodeLimit(for: .detail), graphPolicy.nodeLimit(for: .cluster))
        XCTAssertGreaterThan(graphPolicy.nodeLimit(for: .cluster), graphPolicy.nodeLimit(for: .colony))
        XCTAssertLessThanOrEqual(graphPolicy.nodeLimit(for: .detail), 180)
        XCTAssertGreaterThanOrEqual(HiveGraphGeometry.hexCollisionResolutionPasses, 20)
        XCTAssertEqual(graphPolicy.edgeLimit(selected: true), graphPolicy.edgeLimit(selected: false))
        XCTAssertGreaterThanOrEqual(graphPolicy.edgeLimit(selected: false), 512)
        XCTAssertTrue(graphPolicy.contains(CGPoint(x: 20, y: 20), in: CGSize(width: 100, height: 100)))
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let graphSurface = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))
        XCTAssertTrue(graphSurface.contains("GraphTrackpadPanMonitor"))
        XCTAssertTrue(graphSurface.contains("GraphAtmosphereLayer(nodes: rendered.nodes, edges: rendered.edges)"))
        XCTAssertTrue(graphSurface.contains("drawNode(node, in: &context)"))
        XCTAssertTrue(graphSurface.contains("HiveGraphVisualStyle.activeEdgeOpacityMultiplier"))
        XCTAssertTrue(graphSurface.contains("HiveGraphVisualStyle.inactiveEdgeOpacityMultiplier"))
        XCTAssertTrue(graphSurface.contains("edge.fullPath"))
        XCTAssertTrue(graphSurface.contains("edge.highlightOpacity"))
        XCTAssertTrue(graphSurface.contains("minimumHexSeparationPadding"))
        XCTAssertTrue(graphSurface.contains("separatedGraphNodes(candidateNodes)"))
        XCTAssertTrue(graphSurface.contains("deterministicSeparationVector"))
        XCTAssertFalse(graphSurface.contains(".prefixArray(renderPolicy.edgeLimit"))
        XCTAssertFalse(graphSurface.contains("let visibleIDs = Set(nodes.map(\\.id))"))
        XCTAssertFalse(graphSurface.contains("visibleIDs.contains(edge.fromID)"))
        XCTAssertTrue(graphSurface.contains("let from = positions[edge.fromID]"))
        guard
            let firstEdgeDraw = graphSurface.range(of: "for edge in edges {"),
            let firstNodeDraw = graphSurface.range(of: "for node in nodes where !node.selected")
        else {
            XCTFail("Graph render layer must draw connectors before hexes.")
            return
        }
        XCTAssertLessThan(firstEdgeDraw.lowerBound, firstNodeDraw.lowerBound)
        XCTAssertTrue(graphSurface.contains(".frame(width: proxy.size.width, height: proxy.size.height)"))
        XCTAssertTrue(graphSurface.contains("addLocalMonitorForEvents(matching: .scrollWheel)"))
        XCTAssertTrue(graphSurface.contains("height: -event.scrollingDeltaY * multiplier"))
        XCTAssertFalse(graphSurface.contains("height: event.scrollingDeltaY * multiplier"))
        XCTAssertFalse(graphSurface.contains("&& !isTrackpadPanning"))
        XCTAssertTrue(graphSurface.contains("applyTrackpadPanInertia"))
        XCTAssertTrue(graphSurface.contains("limitedTrackpadInertiaDisplacement"))
        let appleNative = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveAppleNative.swift"))
        XCTAssertTrue(appleNative.contains("surfaceWarmthOpacity"))
        XCTAssertTrue(appleNative.contains("warmUnderglowOpacity"))
        XCTAssertTrue(appleNative.contains("warmSurfaceGradient"))
        XCTAssertTrue(appleNative.contains("amberSurfaceDepth"))
        let renderer = try String(contentsOf: root.appendingPathComponent("Sources/HiveMetalRenderer/HiveMetalRenderer.swift"))
        XCTAssertFalse(renderer.contains("1.0 / 24.0"))
        XCTAssertTrue(renderer.contains("Double(HiveInteractionPolicy.graphMinimumFramesPerSecond)"))
        let snapshot = HiveGraphRenderSnapshot(
            zoomLevel: .detail,
            renderedNodeCount: 12,
            renderedEdgeCount: 20,
            selectedNodeID: "node",
            culledNodeCount: 3,
            culledEdgeCount: 8
        )
        XCTAssertEqual(snapshot.selectedNodeID, "node")
        XCTAssertEqual(snapshot.culledEdgeCount, 8)

        XCTAssertEqual(MemoryCompilerMode.deterministicLocalRules.normalStatusLabel, "Indexed memory only")
        XCTAssertTrue(MemoryCompilerMode.appleFoundationModels.isLocal)
        let indexed = AIAvailabilityPresentation.presentation(availability: .indexedMemoryOnly)
        XCTAssertEqual(indexed.mode, .deterministicLocalRules)
        XCTAssertEqual(indexed.statusText, "Indexed memory only")
        let cloud = AIAvailabilityPresentation.presentation(
            availability: .indexedMemoryOnly,
            cloudSettings: CloudInferenceSettings(providerName: "User key", apiKeyReference: "keychain://hive", enabled: true)
        )
        XCTAssertEqual(cloud.mode, .cloudWithUserKey)
    }

    func testCornerSystemAndOnlineAskIntegrationAreApplied() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settings = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))
        let appModel = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveAppModel.swift"))
        let cloudEngine = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/CloudChatAnswerEngine.swift"))
        let foundationChat = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/FoundationModelChatRuntime.swift"))
        let foundationOrchestrator = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/HiveFoundationModelsOrchestrator.swift"))
        let runtime = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/MemoryCompilerModelRuntime.swift"))
        let graph = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))
        let designNative = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveAppleNative.swift"))

        XCTAssertTrue(settings.contains("Section(\"Ask\")"))
        XCTAssertTrue(settings.contains("Use online Ask when local memory is not enough"))
        XCTAssertTrue(settings.contains("LabeledContent(\"API key\")"))
        XCTAssertTrue(settings.contains("SecureField(\"Paste key\""))
        XCTAssertTrue(settings.contains("CloudInferenceKeyStore.save"))
        XCTAssertTrue(settings.contains("CloudInferenceSettingsStore.saveMetadata"))
        XCTAssertTrue(appModel.contains("FoundationModelChatRuntime.currentAvailability() == .available"))
        XCTAssertTrue(appModel.contains("private let foundationOrchestrator: HiveFoundationModelsOrchestrator"))
        XCTAssertTrue(appModel.contains("foundationOrchestrator.answerChat"))
        XCTAssertTrue(appModel.contains("Synthesizing from The Colony on this Mac."))
        XCTAssertTrue(appModel.contains("Checking The Colony and outside sources with your online helper."))
        XCTAssertTrue(appModel.contains("Checking outside sources without sharing Colony context."))
        XCTAssertTrue(appModel.contains("OnlineAskContextSharingMode.questionOnly"))
        XCTAssertTrue(appModel.contains("onlineAskContextChunks(query: query, localAnswer: localAnswer)"))
        XCTAssertTrue(appModel.contains("chunks: relevantChunks"))
        XCTAssertTrue(appModel.contains("CloudChatAnswerEngine().answer"))
        XCTAssertTrue(foundationChat.contains("HiveFoundationModelsOrchestrator"))
        XCTAssertTrue(foundationChat.contains("orchestrator.answerChat"))
        XCTAssertTrue(foundationOrchestrator.contains("import FoundationModels"))
        XCTAssertTrue(foundationOrchestrator.contains("public actor HiveFoundationModelsOrchestrator"))
        XCTAssertTrue(foundationOrchestrator.contains("public enum HiveFoundationTask"))
        XCTAssertTrue(foundationOrchestrator.contains("case answerChat"))
        XCTAssertTrue(foundationOrchestrator.contains("case summarizeSource"))
        XCTAssertTrue(foundationOrchestrator.contains("case planColonyPatch"))
        XCTAssertTrue(foundationOrchestrator.contains("case classifyGraphCoordinate"))
        XCTAssertTrue(foundationOrchestrator.contains("case planGraphReindex"))
        XCTAssertTrue(foundationOrchestrator.contains("case recommendAction"))
        XCTAssertTrue(foundationOrchestrator.contains("public func summarizeOnlineSource("))
        XCTAssertTrue(foundationOrchestrator.contains("public func extractClaims("))
        XCTAssertTrue(foundationOrchestrator.contains("public func extractEntities("))
        XCTAssertTrue(foundationOrchestrator.contains("SystemLanguageModel.default"))
        XCTAssertTrue(foundationOrchestrator.contains("supportsLocale(Locale.current)"))
        XCTAssertTrue(foundationOrchestrator.contains("LanguageModelSession("))
        XCTAssertTrue(foundationOrchestrator.contains("tools: ["))
        XCTAssertTrue(foundationOrchestrator.contains("SearchColonyPagesTool"))
        XCTAssertTrue(foundationOrchestrator.contains("GetColonyPagesTool"))
        XCTAssertTrue(foundationOrchestrator.contains("GetBacklinksTool"))
        XCTAssertTrue(foundationOrchestrator.contains("GetGraphNeighborhoodTool"))
        XCTAssertTrue(foundationOrchestrator.contains("SearchFlowerFieldMetadataTool"))
        XCTAssertTrue(foundationOrchestrator.contains("FetchApprovedWebPageTool"))
        XCTAssertTrue(foundationOrchestrator.contains("ExtractApprovedWebTextTool"))
        XCTAssertTrue(foundationOrchestrator.contains("@Generable(description: \"A concise Hive answer grounded in local Colony context\")"))
        XCTAssertTrue(foundationOrchestrator.contains("@Generable(description: \"Claim extraction proposal for one immutable source\")"))
        XCTAssertTrue(foundationOrchestrator.contains("@Generable(description: \"Entity extraction proposal for one immutable source\")"))
        XCTAssertTrue(foundationOrchestrator.contains("@Generable(description: \"Summary proposal for one approved online source capture\")"))
        XCTAssertTrue(foundationOrchestrator.contains("generating: GeneratedHiveChatAnswerProposal.self"))
        XCTAssertTrue(foundationOrchestrator.contains("generating: GeneratedClaimExtractionProposal.self"))
        XCTAssertTrue(foundationOrchestrator.contains("generating: GeneratedEntityExtractionProposal.self"))
        XCTAssertTrue(foundationOrchestrator.contains("generating: GeneratedOnlineSourceSummaryProposal.self"))
        XCTAssertTrue(foundationOrchestrator.contains("URLSafetyPolicy().isAllowed(url)"))
        XCTAssertTrue(foundationOrchestrator.contains("LanguageModelSession.GenerationError.exceededContextWindowSize"))
        XCTAssertTrue(foundationOrchestrator.contains("LanguageModelSession.GenerationError.unsupportedLanguageOrLocale"))
        XCTAssertFalse(foundationOrchestrator.contains("JSONDecoder()"))
        XCTAssertTrue(cloudEngine.contains("OnlineAskContextSharingMode"))
        XCTAssertTrue(cloudEngine.contains("body[\"tools\"] = [[\"type\": \"web_search\"]]"))
        XCTAssertTrue(cloudEngine.contains("\"tools\": [[\"type\": \"web_search_preview\"]]"))
        XCTAssertTrue(cloudEngine.contains("Field excerpts:"))
        XCTAssertTrue(cloudEngine.contains("Use outside knowledge and web search when Hive context is missing, stale, or too thin."))
        XCTAssertTrue(cloudEngine.contains("Clearly distinguish local Hive memory from outside information."))
        XCTAssertTrue(cloudEngine.contains("Do not mention model names, raw filenames, percentages, or backend implementation details."))
        XCTAssertTrue(cloudEngine.contains("Online helper unavailable; answered from local memory."))
        XCTAssertTrue(runtime.contains("public enum CloudInferenceSettingsStore"))
        XCTAssertTrue(runtime.contains("public enum CloudInferenceKeyStore"))
        XCTAssertTrue(graph.contains("GraphInstrumentMenu("))
        XCTAssertTrue(graph.contains("title: \"Hive\""))
        XCTAssertFalse(graph.contains("title: \"Hive actions\""))
        XCTAssertTrue(graph.contains("let instrumentControlWidth"))
        XCTAssertTrue(graph.contains("let instrumentTopPadding: CGFloat = 0"))
        XCTAssertTrue(graph.contains("let instrumentLeftPadding: CGFloat = 0"))
        XCTAssertTrue(graph.contains("let searchTopPadding = instrumentTopPadding + HiveHIGPolicy.minimumGraphAccessibilityTarget + HiveSpacing.sm"))
        XCTAssertTrue(graph.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)"))
        XCTAssertFalse(graph.contains(".position(x: instrumentX, y: instrumentY)"))
        XCTAssertFalse(graph.contains(".position(x: proxy.size.width / 2, y: 108)"))

        for body in [settings, graph, designNative] {
            XCTAssertFalse(body.contains("cornerRadius: 26"))
            XCTAssertFalse(body.contains("cornerRadius: 22"))
            XCTAssertFalse(body.contains("cornerRadius: 14"))
            XCTAssertFalse(body.contains("cornerRadius: 10"))
            XCTAssertTrue(body.contains("HiveLayoutMetrics."))
        }

        let suite = UserDefaults(suiteName: "HiveRebuildTests.CloudInference")!
        suite.removePersistentDomain(forName: "HiveRebuildTests.CloudInference")
        CloudInferenceSettingsStore.saveMetadata(
            enabled: true,
            providerName: "OpenAI",
            endpointURL: "https://api.openai.com/v1/responses",
            modelName: "gpt-4.1-mini",
            defaults: suite
        )
        let loaded = CloudInferenceSettingsStore.load(defaults: suite)
        XCTAssertTrue(loaded.enabled)
        XCTAssertEqual(loaded.providerName, "OpenAI")
        XCTAssertEqual(loaded.endpointURL, "https://api.openai.com/v1/responses")
        XCTAssertEqual(loaded.modelName, "gpt-4.1-mini")
    }

    func testMachineLearningExperiencePolicyFollowsAppleGuidance() {
        let compiler = HiveMLFeatureCatalog.memoryCompiler
        XCTAssertEqual(compiler.criticality, .complementary)
        XCTAssertEqual(compiler.dataSensitivity, .privatePersonal)
        XCTAssertEqual(compiler.interactionStyle, .proactive)
        XCTAssertEqual(compiler.resultVisibility, .visible)
        XCTAssertTrue(compiler.requiresAttribution)
        XCTAssertTrue(compiler.requiresCorrection)
        XCTAssertTrue(compiler.requiresFeedbackControl)
        XCTAssertTrue(compiler.shouldPersistFeedbackImmediately)
        XCTAssertFalse(compiler.shouldPresentProactively(confidence: 0.62))
        XCTAssertTrue(compiler.shouldPresentProactively(confidence: 0.72))
        XCTAssertTrue(compiler.followsAppleAIMLGuidance)

        let chat = HiveMLFeatureCatalog.chat
        XCTAssertEqual(chat.interactionStyle, .reactive)
        XCTAssertTrue(chat.shouldPresentProactively(confidence: 0.52))
        XCTAssertFalse(chat.shouldPersistFeedbackImmediately)

        let confidence = HiveMLPresentationPolicy.confidenceCategory(0.91)
        XCTAssertEqual(confidence, "sealed")
        XCTAssertFalse(confidence.contains("%"))

        let attribution = HiveMLPresentationPolicy.attribution(
            evidenceCount: 3,
            context: "The Colony"
        )
        XCTAssertEqual(attribution, "Based on 3 local evidence trails in The Colony.")
        XCTAssertFalse(attribution.localizedCaseInsensitiveContains("love"))
        XCTAssertFalse(attribution.localizedCaseInsensitiveContains("because you"))

        let limitation = HiveMLPresentationPolicy.limitation(for: .indexedMemoryOnly)
        XCTAssertTrue(limitation.contains("The Colony"))
        XCTAssertFalse(limitation.localizedCaseInsensitiveContains("qwen"))
        XCTAssertFalse(limitation.localizedCaseInsensitiveContains("llama"))

        XCTAssertEqual(
            HiveMLUserControlAction.defaultVisibleActions.map(\.label),
            ["Why is this here?", "This is right", "This is wrong", "This was incidental", "Ask me later"]
        )
        XCTAssertTrue(HiveMLUserControlAction.defaultVisibleActions.allSatisfy(\.isVoluntary))
        XCTAssertTrue(HiveMLUserControlAction.defaultVisibleActions.allSatisfy { action in
            !action.consequence.isEmpty
                && !action.consequence.localizedCaseInsensitiveContains("dislike")
                && !action.consequence.localizedCaseInsensitiveContains("like this")
        })
        XCTAssertTrue(HiveMLFeatureCatalog.all.allSatisfy { $0.followsAppleAIMLGuidance })
        XCTAssertTrue(HiveMLFeatureCatalog.all.allSatisfy { $0.requiresNonAIFallback })
        XCTAssertTrue(HiveMLFeatureCatalog.all.allSatisfy { $0.requiresSourceGrounding })
        XCTAssertTrue(HiveMLFeatureCatalog.all.allSatisfy { $0.requiresContextLimitFallback })
        XCTAssertEqual(
            HiveMLPresentationPolicy.recoverySuggestions(forLowConfidence: true),
            ["Add evidence", "Edit The Colony", "Ask a narrower question"]
        )
    }

    func testSignInWithAppleAccountPolicyAndSettingsSurface() throws {
        XCTAssertTrue(HiveAppleAccountPolicy.followsSignInWithAppleGuidance)
        XCTAssertTrue(HiveAppleAccountPolicy.signInIsRequired)
        XCTAssertFalse(HiveAppleAccountPolicy.signInIsOptional)
        XCTAssertFalse(HiveAppleAccountPolicy.delayedUntilSettings)
        XCTAssertTrue(HiveAppleAccountPolicy.requiresSignInBeforeUse)
        XCTAssertTrue(HiveAppleAccountPolicy.blocksUnauthenticatedAppAccess)
        XCTAssertTrue(HiveAppleAccountPolicy.temporaryGuestAccessIsEnabled)
        XCTAssertTrue(HiveAppleAccountPolicy.usesSystemProvidedButton)
        XCTAssertFalse(HiveAppleAccountPolicy.asksForPassword)
        XCTAssertTrue(HiveWatchAccountAccessPolicy.defaultPolicy.followsSignInGuidance)

        let suiteName = "HiveAppleAccountStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let account = HiveAppleAccount(
            appleUserID: "001122.apple-user",
            displayName: "Ari",
            email: "relay@privaterelay.appleid.com",
            authorizedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        HiveAppleAccountStore.save(account, defaults: defaults)
        XCTAssertEqual(HiveAppleAccountStore.load(defaults: defaults), account)
        XCTAssertEqual(HiveAccountStore.load(defaults: defaults)?.provider, .apple)
        XCTAssertEqual(account.statusLabel, "Using Sign in with Apple")
        XCTAssertTrue(account.usesPrivateRelay)
        HiveAppleAccountStore.clear(defaults: defaults)
        XCTAssertNil(HiveAppleAccountStore.load(defaults: defaults))
        XCTAssertTrue(
            HiveAppleCredentialStateResolver.resolve(storedAccount: account, validationResult: .authorized).isAuthenticated
        )
        XCTAssertTrue(
            HiveAppleCredentialStateResolver.resolve(storedAccount: account, validationResult: .transferred).isAuthenticated
        )
        XCTAssertEqual(
            HiveAppleCredentialStateResolver.resolve(storedAccount: account, validationResult: .revoked),
            .locked(reason: "Apple revoked this Hive sign-in. Sign in again to continue.", shouldClearStoredAccount: true)
        )
        XCTAssertEqual(
            HiveAppleCredentialStateResolver.resolve(storedAccount: account, validationResult: .notFound),
            .locked(reason: "Apple no longer recognizes this Hive sign-in. Sign in again to continue.", shouldClearStoredAccount: true)
        )
        XCTAssertEqual(
            HiveAppleCredentialStateResolver.resolve(storedAccount: account, validationResult: .failed("offline")),
            .locked(reason: "Hive could not verify this Apple Account. Sign in again to continue.", shouldClearStoredAccount: true)
        )
        let longRelayAccount = HiveAppleAccount(
            appleUserID: "long-user",
            displayName: nil,
            email: "very-long-private-relay-address-for-layout-verification@privaterelay.appleid.com",
            authorizedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        HiveAppleAccountStore.save(longRelayAccount, defaults: defaults)
        XCTAssertEqual(HiveAppleAccountStore.load(defaults: defaults)?.displayLabel, longRelayAccount.email)
        HiveAppleAccountStore.clear(defaults: defaults)
        XCTAssertNil(HiveAppleAccountStore.load(defaults: defaults))
        XCTAssertFalse(HiveGuestAccessStore.isEnabled(defaults: defaults))
        HiveGuestAccessStore.enable(defaults: defaults)
        XCTAssertTrue(HiveGuestAccessStore.isEnabled(defaults: defaults))
        HiveGuestAccessStore.clear(defaults: defaults)
        XCTAssertFalse(HiveGuestAccessStore.isEnabled(defaults: defaults))
        let googleAccount = HiveGoogleAccount(
            googleUserID: "google-user",
            displayName: "Ari Google",
            email: "ari@example.com",
            authorizedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        HiveGoogleAccountStore.save(googleAccount, defaults: defaults)
        XCTAssertEqual(HiveAccountStore.load(defaults: defaults)?.provider, .google)
        XCTAssertEqual(HiveGoogleAccountStore.load(defaults: defaults), googleAccount)
        XCTAssertTrue(HiveFirstLoginDataChoiceStore.needsChoice(for: googleAccount.authenticatedAccount, defaults: defaults))
        HiveFirstLoginDataChoiceStore.save(.swarmMerge, for: googleAccount.authenticatedAccount, defaults: defaults)
        XCTAssertFalse(HiveFirstLoginDataChoiceStore.needsChoice(for: googleAccount.authenticatedAccount, defaults: defaults))
        XCTAssertEqual(HiveFirstLoginDataChoiceStore.load(for: googleAccount.authenticatedAccount, defaults: defaults), .swarmMerge)
        XCTAssertEqual(HiveCloudSyncSettingsStore.load(defaults: defaults).mode, .iCloud)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settings = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))
        let accountSurface = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveAppleAccountSurface.swift"))
        let coreAccount = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/AppleAccount.swift"))
        let symbols = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveAppleNative.swift"))
        let appModel = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveAppModel.swift"))
        let appRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveApp/HiveApp.swift"))
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let appIntents = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/HiveAppIntents.swift"))
        let buildScript = try String(contentsOf: root.appendingPathComponent("scripts/build_app.sh"))
        let appleSignInPreflight = try String(contentsOf: root.appendingPathComponent("scripts/apple_signin_preflight.sh"))
        let googleSignInPreflight = try String(contentsOf: root.appendingPathComponent("scripts/google_signin_preflight.sh"))
        let acceptanceScript = try String(contentsOf: root.appendingPathComponent("scripts/acceptance.sh"))
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"))

        XCTAssertTrue(settings.contains("Section(\"Account\")"))
        XCTAssertTrue(settings.contains("HiveAppleAccountSection(onAccountChanged: onAppleAccountChanged)"))
        XCTAssertTrue(accountSurface.contains("SignInWithAppleButton(.continue)"))
        XCTAssertTrue(accountSurface.contains("request.requestedScopes = [.fullName, .email]"))
        XCTAssertTrue(accountSurface.contains(".signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)"))
        XCTAssertTrue(accountSurface.contains("public struct HiveAppleLoginGate"))
        XCTAssertTrue(accountSurface.contains("HiveAppleAccountSection(centered: true)"))
        XCTAssertTrue(accountSurface.contains("HiveAuthenticationPreview"))
        XCTAssertTrue(accountSurface.contains("Interactive Hive preview after sign-in"))
        XCTAssertTrue(accountSurface.contains("selectedSurface: PreviewSurface"))
        XCTAssertTrue(accountSurface.contains("previewNavButton"))
        XCTAssertTrue(accountSurface.contains("previewSampleRow"))
        XCTAssertTrue(accountSurface.contains("withAnimation(HiveMotion.panel)"))
        XCTAssertTrue(accountSurface.contains(".onHover"))
        XCTAssertTrue(accountSurface.contains("landingPhase"))
        XCTAssertTrue(accountSurface.contains("HivePreviewLandingModifier"))
        XCTAssertTrue(accountSurface.contains(".interpolatingSpring(mass: 1.0, stiffness: 360, damping: 44"))
        XCTAssertTrue(accountSurface.contains(".delay(Double(index) * 0.045)"))
        XCTAssertTrue(accountSurface.contains("Text(\"HIVE\")"))
        XCTAssertTrue(accountSurface.contains("Continue as Guest"))
        XCTAssertTrue(accountSurface.contains("onContinueAsGuest"))
        XCTAssertTrue(accountSurface.contains("Diagnostics"))
        XCTAssertTrue(accountSurface.contains("currentBuildHasAppleSignInEntitlement"))
        XCTAssertTrue(accountSurface.contains("currentBuildHasAppleTeamIdentifier"))
        XCTAssertTrue(accountSurface.contains("SecTaskCopyValueForEntitlement"))
        XCTAssertTrue(accountSurface.contains("SecCodeCopySigningInformation"))
        XCTAssertTrue(accountSurface.contains("getCredentialState(forUserID: account.appleUserID)"))
        XCTAssertTrue(accountSurface.contains("HiveAppleCredentialStateResolver.resolve"))
        XCTAssertTrue(accountSurface.contains("Continue with Apple"))
        XCTAssertTrue(accountSurface.contains("Continue with Google"))
        XCTAssertTrue(accountSurface.contains("ASWebAuthenticationSession"))
        XCTAssertTrue(accountSurface.contains("https://accounts.google.com/o/oauth2/v2/auth"))
        XCTAssertTrue(accountSurface.contains("https://oauth2.googleapis.com/token"))
        XCTAssertTrue(accountSurface.contains("HiveFirstLoginDataChoiceSheet"))
        XCTAssertTrue(accountSurface.contains("Apple-signed build required"))
        XCTAssertTrue(accountSurface.contains("signInReadinessFailure"))
        XCTAssertTrue(accountSurface.contains("Using Sign in with Apple"))
        XCTAssertTrue(accountSurface.contains("Sign in with Apple or Google is required before Hive can open your Field, Colony, Hive graph, or Swarm."))
        XCTAssertTrue(accountSurface.contains("Install an Apple-signed Hive build with Apple Account signing enabled."))
        XCTAssertTrue(accountSurface.contains("Install an Apple-signed Hive build with a TeamIdentifier."))
        XCTAssertTrue(accountSurface.contains("HiveSymbolButton(.signOut, title: \"Sign Out\""))
        XCTAssertTrue(accountSurface.contains("HiveAppleAccountStore.clear()"))
        XCTAssertTrue(accountSurface.contains(".lineLimit(HiveAppleAccountPolicy.accountIdentifierLineLimit)"))
        XCTAssertTrue(accountSurface.contains(".truncationMode(.middle)"))
        XCTAssertTrue(accountSurface.contains(".layoutPriority(1)"))
        XCTAssertTrue(coreAccount.contains("public enum HiveAccountProvider"))
        XCTAssertTrue(coreAccount.contains("public enum HiveFirstLoginDataChoice"))
        XCTAssertTrue(coreAccount.contains("public enum HiveGuestAccessStore"))
        XCTAssertTrue(coreAccount.contains("public enum HiveGoogleAccountStore"))
        XCTAssertTrue(coreAccount.contains("hive.temporaryGuestAccess"))
        XCTAssertTrue(appModel.contains("public func continueAsGuestForNow()"))
        XCTAssertTrue(appModel.contains("authenticatedAccount != nil || appleAccount != nil || temporaryGuestAccessEnabled"))
        XCTAssertTrue(appModel.contains("firstLoginDataChoicePrompt"))
        XCTAssertTrue(appModel.contains("resolveFirstLoginDataChoice"))
        XCTAssertTrue(appRoot.contains("model.continueAsGuestForNow()"))
        XCTAssertTrue(macRoot.contains("model.continueAsGuestForNow()"))
        XCTAssertTrue(appIntents.contains("HiveAccountStore.load(defaults: defaults) == nil"))
        XCTAssertTrue(appIntents.contains("!HiveGuestAccessStore.isEnabled(defaults: defaults)"))
        XCTAssertTrue(coreAccount.contains("privaterelay.appleid.com"))
        XCTAssertFalse(accountSurface.localizedCaseInsensitiveContains("password"))
        XCTAssertTrue(coreAccount.contains("storageKey = \"hive.appleAccount\""))
        XCTAssertTrue(symbols.contains("case appleAccount = \"apple.logo\""))
        XCTAssertTrue(symbols.contains("case googleAccount = \"person.crop.circle.badge.checkmark\""))
        XCTAssertTrue(symbols.contains("case signOut = \"rectangle.portrait.and.arrow.right\""))
        XCTAssertTrue(buildScript.contains("com.apple.developer.applesignin"))
        XCTAssertTrue(buildScript.contains("--entitlements \"$CONTENTS/Hive.entitlements\""))
        XCTAssertTrue(buildScript.contains("Refusing to package a broken login build."))
        XCTAssertTrue(buildScript.contains("HIVE_BUNDLE_IDENTIFIER"))
        XCTAssertTrue(buildScript.contains("HIVE_DEVELOPMENT_TEAM"))
        XCTAssertTrue(buildScript.contains("HIVE_CODESIGN_IDENTITY"))
        XCTAssertTrue(buildScript.contains("HIVE_ALLOW_UNSIGNED_LOCKED_BUILD"))
        XCTAssertTrue(buildScript.contains("HIVE_GOOGLE_CLIENT_ID"))
        XCTAssertTrue(buildScript.contains("HIVE_GOOGLE_REVERSED_CLIENT_ID"))
        XCTAssertTrue(buildScript.contains("GIDClientID"))
        XCTAssertTrue(buildScript.contains("CFBundleURLSchemes"))
        XCTAssertTrue(buildScript.contains("Hive.app Info.plist is missing GIDClientID for Google sign-in."))
        XCTAssertTrue(buildScript.contains("Hive.app Info.plist is missing HiveGoogleReversedClientID for Google sign-in."))
        XCTAssertTrue(buildScript.contains("Hive.app Info.plist is missing the Google callback URL scheme."))
        XCTAssertTrue(buildScript.contains("Missing: ${missing[*]}"))
        XCTAssertTrue(buildScript.contains("temporary guest access is enabled for local UI testing"))
        XCTAssertTrue(buildScript.contains("TeamIdentifier="))
        XCTAssertTrue(appleSignInPreflight.contains("Hive Sign in with Apple preflight failed"))
        XCTAssertTrue(appleSignInPreflight.contains("Apple Development or Developer ID Application"))
        XCTAssertTrue(appleSignInPreflight.contains("TeamIdentifier=not set"))
        XCTAssertTrue(appleSignInPreflight.contains("com.apple.developer.applesignin"))
        XCTAssertTrue(googleSignInPreflight.contains("Hive Sign in with Google preflight failed"))
        XCTAssertTrue(googleSignInPreflight.contains("HIVE_GOOGLE_CLIENT_ID"))
        XCTAssertTrue(googleSignInPreflight.contains("HIVE_GOOGLE_REVERSED_CLIENT_ID"))
        XCTAssertTrue(googleSignInPreflight.contains("Google callback URL scheme"))
        XCTAssertTrue(acceptanceScript.contains("scripts/apple_signin_preflight.sh"))
        XCTAssertTrue(acceptanceScript.contains("scripts/google_signin_preflight.sh"))
        XCTAssertTrue(readme.contains("scripts/apple_signin_preflight.sh"))
        XCTAssertTrue(readme.contains("scripts/google_signin_preflight.sh"))
        XCTAssertFalse(buildScript.contains("HIVE_FORCE_APPLE_SIGNIN_ENTITLEMENT"))
        XCTAssertFalse(buildScript.contains("HIVE_ALLOW_ADHOC_APPLE_SIGNIN_BUILD"))
        XCTAssertFalse(buildScript.contains("|| \"$FORCE_APPLE_SIGNIN_ENTITLEMENT\" == \"1\""))
    }

    func testICloudContinuityPolicyAndSettingsSurface() throws {
        XCTAssertTrue(HiveCloudSyncPolicy.default.followsICloudGuidance)
        XCTAssertTrue(HiveCloudSyncPolicy.default.offersOneWholeVaultChoice)
        XCTAssertTrue(HiveCloudSyncPolicy.default.avoidsPerDocumentStorageChoices)
        XCTAssertTrue(HiveCloudSyncPolicy.default.storesOnlyUserCreatedContent)
        XCTAssertTrue(HiveCloudSyncPolicy.default.excludesRegenerableContent.contains("Models"))
        XCTAssertTrue(HiveCloudSyncPolicy.default.warnsBeforeDeletingEverywhere)
        XCTAssertTrue(HiveCloudSyncPolicy.default.includesCloudContentInSearch)
        XCTAssertTrue(HiveCloudContentPlan().respectsICloudStorage)
        XCTAssertTrue(HiveMobileCloudContinuityPolicy.defaultPolicy.followsICloudGuidance)
        XCTAssertTrue(HiveWatchCloudContinuityPolicy.defaultPolicy.followsICloudGuidance)

        let suiteName = "HiveCloudSyncSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        HiveCloudSyncSettingsStore.save(HiveCloudSyncSettings(mode: .iCloud), defaults: defaults)
        XCTAssertEqual(HiveCloudSyncSettingsStore.load(defaults: defaults).mode, .iCloud)
        XCTAssertTrue(defaults.bool(forKey: HiveCloudSyncSettingsStore.firstChoiceMadeKey))
        HiveCloudSyncSettingsStore.reset(defaults: defaults)
        XCTAssertEqual(HiveCloudSyncSettingsStore.load(defaults: defaults).mode, .localOnly)

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settings = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))
        let cloud = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/HiveCloudSync.swift"))
        let store = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/Store.swift"))
        let appModel = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveAppModel.swift"))
        let buildScript = try String(contentsOf: root.appendingPathComponent("scripts/build_app.sh"))

        XCTAssertTrue(settings.contains("Section(\"iCloud\")"))
        XCTAssertTrue(settings.contains("Toggle(\"Use iCloud for Hive\""))
        XCTAssertTrue(settings.contains("Field, The Colony, The Hive map, and app state"))
        XCTAssertTrue(settings.contains("Models and temporary work stay on this device."))
        XCTAssertTrue(settings.contains("HiveCloudContentPlan().deletionWarning"))
        XCTAssertFalse(settings.contains("Which documents"))
        XCTAssertFalse(settings.contains("per-document"))
        XCTAssertTrue(cloud.contains("fileManager.url(forUbiquityContainerIdentifier: policy.defaultContainerIdentifier)"))
        XCTAssertTrue(cloud.contains("NSUbiquitousKeyValueStore"))
        XCTAssertTrue(cloud.contains("Deleting synced Hive content removes it from iCloud and every device."))
        XCTAssertTrue(store.contains("HiveCloudSyncLocator.preferredRootURL()"))
        XCTAssertTrue(appModel.contains("restoreCloudAppStateIfNeeded()"))
        XCTAssertTrue(appModel.contains("publishCloudAppState()"))
        XCTAssertTrue(buildScript.contains("com.apple.developer.icloud-container-identifiers"))
        XCTAssertTrue(buildScript.contains("com.apple.developer.icloud-services"))
        XCTAssertTrue(buildScript.contains("CloudDocuments"))
        XCTAssertTrue(buildScript.contains("com.apple.developer.ubiquity-kvstore-identifier"))
    }

    func testFoundationModelMemoryRuntimeFallsBackDeterministicallyWhenRequested() async {
        let source = SourceRecord(
            id: "source",
            kind: .text,
            connector: "manual",
            uri: "hive://manual",
            title: "Manual note",
            mimeType: "text/plain",
            sizeBytes: 12,
            sha256: "hash",
            importedAt: Date(timeIntervalSince1970: 0),
            observedAt: Date(timeIntervalSince1970: 0),
            retentionExpiresAt: Date(timeIntervalSince1970: 100),
            pinned: false,
            privacyLabel: .normal,
            status: .extracted,
            deletionState: .active
        )
        let claim = ClaimRecord(
            id: "claim",
            statement: "The user wants Hive to use solid honey and obsidian controls.",
            claimType: "preference",
            subjectEntityID: nil,
            sourceRefs: ["source"],
            confidence: 0.9,
            uncertaintyReason: "",
            status: .active,
            createdBy: "user",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let runtime = FoundationModelMemoryRuntime(mode: .deterministicFallbackOnly)
        let envelope = await runtime.compile(
            source: source,
            extractedClaims: [claim],
            existingClaims: [],
            existingEntities: [],
            now: Date(timeIntervalSince1970: 1)
        )
        XCTAssertEqual(envelope.profile.backend.rawValue, MemoryCompilerBackend.deterministicRules.rawValue)
        XCTAssertEqual(envelope.mutationPolicy, "model-output-is-proposal-only")
        XCTAssertFalse(envelope.stableDecisionID.isEmpty)
    }

    func testFoundationModelChatRuntimeFallsBackWithoutAppleIntelligence() async {
        let fallback = CitedAnswer(
            answer: "Based on The Colony, Hive knows this topic is only partially covered.",
            citations: [],
            uncertainty: "Indexed memory only",
            suggestedActions: ["Open The Colony"]
        )
        let runtime = FoundationModelChatRuntime(configuration: FoundationModelChatRuntimeConfiguration(mode: .deterministicFallbackOnly))
        let answer = await runtime.answer(
            query: "What should I do next?",
            localAnswer: fallback,
            claims: [],
            wikiPages: []
        )
        XCTAssertEqual(answer.answer, fallback.answer)
        XCTAssertTrue(answer.uncertainty.contains("The Colony"))
        XCTAssertTrue(answer.suggestedActions.contains("Ask a narrower question"))
        XCTAssertTrue(answer.suggestedActions.contains("Open The Colony"))
    }

    func testLifeDomainClassifierMapsCoreUserAreas() {
        let classifier = GraphLifeDomainClassifier()
        XCTAssertEqual(classifier.domain(for: GraphNodeRecord(id: "ucla", title: "UCLA Student", kind: .topic, confidence: 1, sourceRefs: [])), .education)
        XCTAssertEqual(classifier.domain(for: GraphNodeRecord(id: "cabin", title: "Cabin app startup", kind: .project, confidence: 1, sourceRefs: [])), .projects)
        XCTAssertEqual(classifier.domain(for: GraphNodeRecord(id: "gpu", title: "A6000 GPU workflow", kind: .topic, confidence: 1, sourceRefs: [])), .hardware)
        XCTAssertEqual(classifier.domain(for: GraphNodeRecord(id: "grant", title: "Grant funding preference", kind: .topic, confidence: 1, sourceRefs: [])), .finance)
        XCTAssertEqual(classifier.domain(for: GraphNodeRecord(id: "health", title: "Creatine and body weight", kind: .topic, confidence: 1, sourceRefs: [])), .health)
        XCTAssertEqual(classifier.domain(for: GraphNodeRecord(id: "family", title: "Avni sister AP plan", kind: .topic, confidence: 1, sourceRefs: [])), .family)
        XCTAssertEqual(classifier.domain(for: GraphNodeRecord(id: "prefs", title: "LaTeX response preference", kind: .topic, confidence: 1, sourceRefs: [])), .identity)
    }

    func testGraphSelectionModelHighlightsOnlyDirectNeighbors() {
        let edges = [
            GraphEdgeRecord(id: "ab", fromID: "a", toID: "b", predicate: .related, strength: 1, confidence: 1, evidenceCount: 1),
            GraphEdgeRecord(id: "ac", fromID: "a", toID: "c", predicate: .related, strength: 1, confidence: 1, evidenceCount: 1),
            GraphEdgeRecord(id: "de", fromID: "d", toID: "e", predicate: .related, strength: 1, confidence: 1, evidenceCount: 1)
        ]
        let selection = GraphSelectionModel(selectedID: "a", nodeIDs: ["a", "b", "c", "d", "e"], edges: edges)

        XCTAssertEqual(selection.firstOrderIDs, ["b", "c"])
        XCTAssertEqual(selection.activeEdgeIDs, ["ab", "ac"])
        XCTAssertEqual(selection.dimmedIDs, ["d", "e"])
        XCTAssertTrue(selection.isFocused(nodeID: "a"))
        XCTAssertTrue(selection.isFocused(nodeID: "b"))
        XCTAssertFalse(selection.isFocused(nodeID: "d"))
    }

    func testWeakGraphRelationshipsAreInvisibleAndDoNotSelectNeighbors() {
        let edges = [
            GraphEdgeRecord(id: "weak", fromID: "a", toID: "b", predicate: .related, strength: 0.29, confidence: 1, evidenceCount: 1),
            GraphEdgeRecord(id: "threshold", fromID: "a", toID: "c", predicate: .related, strength: 0.30, confidence: 1, evidenceCount: 1),
            GraphEdgeRecord(id: "strong", fromID: "a", toID: "d", predicate: .related, strength: 0.82, confidence: 1, evidenceCount: 1)
        ]
        let selection = GraphSelectionModel(selectedID: "a", nodeIDs: ["a", "b", "c", "d"], edges: edges)

        XCTAssertEqual(GraphRelationshipPolicy.visibleOpacity(forStrength: 0.29), 0)
        XCTAssertEqual(GraphRelationshipPolicy.visibleOpacity(forStrength: 0.30), 0.30, accuracy: 0.0001)
        XCTAssertEqual(GraphRelationshipPolicy.visibleOpacity(forStrength: 0.50), 0.50, accuracy: 0.0001)
        XCTAssertEqual(GraphRelationshipPolicy.visibleOpacity(forStrength: 0.82), 0.82, accuracy: 0.0001)
        XCTAssertEqual(GraphRelationshipPolicy.visibleOpacity(forStrength: 1.20), 1, accuracy: 0.0001)
        XCTAssertFalse(GraphRelationshipPolicy.isBackgroundRenderableConnection(edges[1]))
        XCTAssertFalse(GraphRelationshipPolicy.isBackgroundRenderableConnection(edges[2]))
        XCTAssertTrue(GraphRelationshipPolicy.isBackgroundRenderableConnection(
            GraphEdgeRecord(id: "specific-strong", fromID: "a", toID: "d", predicate: .supports, strength: 0.84, confidence: 0.82, evidenceCount: 2)
        ))
        XCTAssertFalse(GraphRelationshipPolicy.isBackgroundRenderableConnection(
            GraphEdgeRecord(id: "audit-a-b", fromID: "a", toID: "b", predicate: .related, strength: 0.92, confidence: 0.91, evidenceCount: 4)
        ))
        XCTAssertFalse(GraphRelationshipPolicy.isBackgroundRenderableConnection(
            GraphEdgeRecord(id: "markov-a-b", fromID: "a", toID: "b", predicate: .markovTransition, strength: 0.96, confidence: 0.95, evidenceCount: 5)
        ))
        XCTAssertEqual(selection.firstOrderIDs, ["c", "d"])
        XCTAssertEqual(selection.activeEdgeIDs, ["threshold", "strong"])
        XCTAssertEqual(selection.dimmedIDs, ["b"])
    }

    func testGraphCoordinateClassifierUsesMeaningAxes() {
        let classifier = GraphCoordinateClassifier()
        let professionalAnalytical = GraphNodeRecord(
            id: "uconsulting",
            title: "The user is targeting UConsulting at UCLA for professional consulting work.",
            kind: .claim,
            confidence: 1,
            sourceRefs: []
        )
        let personalCreative = GraphNodeRecord(
            id: "journal-design",
            title: "The user writes personal design ideas and creative reflections.",
            kind: .claim,
            confidence: 1,
            sourceRefs: []
        )

        let topRight = classifier.coordinate(for: professionalAnalytical)
        let bottomLeft = classifier.coordinate(for: personalCreative)
        let topRightUnit = classifier.unitCoordinate(for: professionalAnalytical)
        let bottomLeftUnit = classifier.unitCoordinate(for: personalCreative)

        XCTAssertGreaterThan(topRight.x, 0)
        XCTAssertGreaterThan(topRight.y, 0)
        XCTAssertLessThan(bottomLeft.x, 0)
        XCTAssertLessThan(bottomLeft.y, 0)
        XCTAssertGreaterThan(topRightUnit.x, 0.7)
        XCTAssertGreaterThan(topRightUnit.y, 0.7)
        XCTAssertLessThan(bottomLeftUnit.x, -0.7)
        XCTAssertLessThan(bottomLeftUnit.y, -0.7)
        XCTAssertEqual(classifier.unitCoordinate(for: professionalAnalytical).x, classifier.classify(professionalAnalytical).analyticalCreative)
        XCTAssertEqual(classifier.unitCoordinate(for: professionalAnalytical).y, classifier.classify(professionalAnalytical).professionalPersonal)
        XCTAssertEqual(classifier.classify(professionalAnalytical).reason, GraphAxisVocabulary.default.semanticSummary)
        XCTAssertEqual(GraphSemanticAxes.professionalLabel, "Professional")
        XCTAssertEqual(GraphSemanticAxes.analyticalLabel, "Analytical")

        let ageNoise = GraphNodeRecord(id: "age", title: "The user is 19 years old.", kind: .claim, confidence: 1, sourceRefs: [])
        let lamtDirector = GraphNodeRecord(id: "lamt", title: "The user served as LAMT tournament director.", kind: .claim, confidence: 1, sourceRefs: [])
        let cabinRenderer = GraphNodeRecord(id: "cabin", title: "The user built a Cabin 3D rendering app.", kind: .project, confidence: 1, sourceRefs: [])
        let metalShader = GraphNodeRecord(id: "metal", title: "The user does Metal shader development.", kind: .claim, confidence: 1, sourceRefs: [])

        let ageCoordinate = classifier.unitCoordinate(for: ageNoise)
        let lamtCoordinate = classifier.unitCoordinate(for: lamtDirector)
        let cabinCoordinate = classifier.unitCoordinate(for: cabinRenderer)
        let metalCoordinate = classifier.unitCoordinate(for: metalShader)

        XCTAssertEqual(ageCoordinate.x, 0, accuracy: 0.0001)
        XCTAssertLessThan(ageCoordinate.y, 0)
        XCTAssertLessThan(lamtCoordinate.x, 0)
        XCTAssertGreaterThan(lamtCoordinate.y, 0.4)
        XCTAssertGreaterThan(cabinCoordinate.x, 0.55)
        XCTAssertGreaterThan(cabinCoordinate.y, 0.55)
        XCTAssertGreaterThan(metalCoordinate.x, 0.7)
        XCTAssertGreaterThan(metalCoordinate.y, 0.55)
        XCTAssertTrue(GraphAxisVocabulary.default.review.isApproved)
        XCTAssertFalse(GraphAxisVocabulary(top: "Work", bottom: "Work stuff", right: "Analytical", left: "Creative").review.isApproved)
    }

    func testGraphReindexPlanMergesStrongRelationshipsAtUnitCoordinates() {
        let primary = GraphNodeRecord(
            id: "mac-funding",
            title: "The user is researching Mac Studio grant funding for professional project work.",
            kind: .claim,
            confidence: 0.96,
            sourceRefs: ["source-a"],
            memoryLayer: .importantTrait
        )
        let duplicate = GraphNodeRecord(
            id: "mac-shopping",
            title: "The user compares Apple hardware shopping options for a Mac Studio.",
            kind: .claim,
            confidence: 0.88,
            sourceRefs: ["source-b"],
            memoryLayer: .connector
        )
        let personal = GraphNodeRecord(
            id: "design-journal",
            title: "The user keeps personal creative design notes.",
            kind: .claim,
            confidence: 0.72,
            sourceRefs: ["source-c"],
            memoryLayer: .detail
        )
        let graphNodes = [primary, duplicate, personal]
        let graphEdges = [
            GraphEdgeRecord(
                id: "merge",
                fromID: primary.id,
                toID: duplicate.id,
                predicate: .duplicates,
                strength: 0.84,
                confidence: 0.91,
                evidenceCount: 3
            )
        ]
        let plan = GraphReindexPlan.make(
            nodes: graphNodes,
            edges: graphEdges,
            maxSteps: 6
        )

        let mergedStep = plan.steps.first { $0.nodeID == primary.id }
        XCTAssertNotNil(mergedStep)
        XCTAssertEqual(mergedStep?.mergedWithNodeID, duplicate.id)
        XCTAssertEqual(mergedStep?.operation, .consolidate)
        XCTAssertGreaterThan(mergedStep?.mergedSizeMultiplier ?? 0, 1)
        XCTAssertTrue(plan.steps.allSatisfy { (-1...1).contains($0.unitX) && (-1...1).contains($0.unitY) })
        XCTAssertEqual(plan.steps.flatMap { Array($0.affectedNodeIDs) }.filter { $0 == duplicate.id }.count, 1)
        let applied = plan.applying(to: HiveGraphSnapshot(nodes: graphNodes, edges: graphEdges))
        XCTAssertTrue(applied.nodes.contains { $0.id == primary.id })
        XCTAssertFalse(applied.nodes.contains { $0.id == duplicate.id })
        XCTAssertFalse(applied.edges.contains { $0.fromID == duplicate.id || $0.toID == duplicate.id })
        let personalStep = plan.steps.first { $0.nodeID == personal.id }
        let semanticTarget = GraphCoordinateClassifier().unitCoordinate(for: personal)
        let expectedPersonalX = min(0.86, max(-0.86, semanticTarget.x))
        let expectedPersonalY = min(0.86, max(-0.86, semanticTarget.y))
        XCTAssertNotNil(personalStep)
        XCTAssertEqual(personalStep?.unitX ?? .nan, expectedPersonalX, accuracy: 0.001)
        XCTAssertEqual(personalStep?.unitY ?? .nan, expectedPersonalY, accuracy: 0.001)
    }

    func testGraphReindexIgnoresCurrentCoordinatesAndDoesNotCompoundExtremes() {
        let semanticNode = GraphNodeRecord(
            id: "ucla-consulting",
            title: "The user is preparing professional analytical consulting research at UCLA.",
            kind: .claim,
            confidence: 0.9,
            sourceRefs: ["source-a"],
            x: -GraphSemanticAxes.horizontalNodeRange,
            y: -GraphSemanticAxes.verticalNodeRange,
            memoryLayer: .importantTrait
        )
        var oppositeCurrentCoordinate = semanticNode
        oppositeCurrentCoordinate.x = GraphSemanticAxes.horizontalNodeRange
        oppositeCurrentCoordinate.y = GraphSemanticAxes.verticalNodeRange

        let leftPlan = GraphReindexPlan.make(nodes: [semanticNode], edges: [], maxSteps: 1)
        let rightPlan = GraphReindexPlan.make(nodes: [oppositeCurrentCoordinate], edges: [], maxSteps: 1)
        let leftStep = leftPlan.steps.first
        let rightStep = rightPlan.steps.first

        XCTAssertEqual(leftStep?.unitX ?? .nan, rightStep?.unitX ?? .nan, accuracy: 0.0001)
        XCTAssertEqual(leftStep?.unitY ?? .nan, rightStep?.unitY ?? .nan, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(abs(leftStep?.unitX ?? 1), 0.86)
        XCTAssertLessThanOrEqual(abs(leftStep?.unitY ?? 1), 0.86)

        let firstApplied = leftPlan.applying(to: HiveGraphSnapshot(nodes: [semanticNode], edges: []))
        let secondPlan = GraphReindexPlan.make(nodes: firstApplied.nodes, edges: firstApplied.edges, maxSteps: 1)
        XCTAssertEqual(leftStep?.unitX ?? .nan, secondPlan.steps.first?.unitX ?? .nan, accuracy: 0.0001)
        XCTAssertEqual(leftStep?.unitY ?? .nan, secondPlan.steps.first?.unitY ?? .nan, accuracy: 0.0001)

        let researchNode = GraphNodeRecord(
            id: "metal-research",
            title: "The user is researching Metal shader debugging for a professional rendering tool.",
            kind: .claim,
            confidence: 0.82,
            sourceRefs: ["source-b"],
            x: GraphSemanticAxes.horizontalNodeRange,
            y: -GraphSemanticAxes.verticalNodeRange,
            memoryLayer: .connector
        )
        var oppositeResearchNode = researchNode
        oppositeResearchNode.x = -GraphSemanticAxes.horizontalNodeRange
        oppositeResearchNode.y = GraphSemanticAxes.verticalNodeRange
        let limitedLeftPlan = GraphReindexPlan.make(nodes: [semanticNode, researchNode], edges: [], maxSteps: 1)
        let limitedRightPlan = GraphReindexPlan.make(nodes: [oppositeCurrentCoordinate, oppositeResearchNode], edges: [], maxSteps: 1)
        let limitedLeft = limitedLeftPlan.applying(to: HiveGraphSnapshot(nodes: [semanticNode, researchNode], edges: []))
        let limitedRight = limitedRightPlan.applying(to: HiveGraphSnapshot(nodes: [oppositeCurrentCoordinate, oppositeResearchNode], edges: []))
        let leftCoordinates = Dictionary(uniqueKeysWithValues: limitedLeft.nodes.map { ($0.id, ($0.x, $0.y)) })
        let rightCoordinates = Dictionary(uniqueKeysWithValues: limitedRight.nodes.map { ($0.id, ($0.x, $0.y)) })
        XCTAssertEqual(leftCoordinates[semanticNode.id]?.0 ?? .nan, rightCoordinates[semanticNode.id]?.0 ?? .nan, accuracy: 0.0001)
        XCTAssertEqual(leftCoordinates[semanticNode.id]?.1 ?? .nan, rightCoordinates[semanticNode.id]?.1 ?? .nan, accuracy: 0.0001)
        XCTAssertEqual(leftCoordinates[researchNode.id]?.0 ?? .nan, rightCoordinates[researchNode.id]?.0 ?? .nan, accuracy: 0.0001)
        XCTAssertEqual(leftCoordinates[researchNode.id]?.1 ?? .nan, rightCoordinates[researchNode.id]?.1 ?? .nan, accuracy: 0.0001)

        let junkNode = GraphNodeRecord(
            id: "experience",
            title: "Experience",
            kind: .topic,
            confidence: 0.64,
            sourceRefs: ["source-junk"],
            x: -GraphSemanticAxes.horizontalNodeRange,
            y: GraphSemanticAxes.verticalNodeRange
        )
        var oppositeJunkNode = junkNode
        oppositeJunkNode.x = GraphSemanticAxes.horizontalNodeRange
        oppositeJunkNode.y = -GraphSemanticAxes.verticalNodeRange
        let junkLeftStep = GraphReindexPlan.make(nodes: [junkNode], edges: [], maxSteps: 0).steps.first
        let junkRightStep = GraphReindexPlan.make(nodes: [oppositeJunkNode], edges: [], maxSteps: 0).steps.first
        XCTAssertEqual(junkLeftStep?.operation, .delete)
        XCTAssertEqual(junkLeftStep?.unitX ?? .nan, 0, accuracy: 0.0001)
        XCTAssertEqual(junkLeftStep?.unitY ?? .nan, 0, accuracy: 0.0001)
        XCTAssertEqual(junkLeftStep?.unitX ?? .nan, junkRightStep?.unitX ?? .nan, accuracy: 0.0001)
        XCTAssertEqual(junkLeftStep?.unitY ?? .nan, junkRightStep?.unitY ?? .nan, accuracy: 0.0001)
    }

    func testGraphReindexDeletesJunkNodesDeconflictsCoordinatesAndAuditsPairs() {
        let junk = GraphNodeRecord(
            id: "experience",
            title: "Experience",
            kind: .topic,
            confidence: 0.64,
            sourceRefs: ["source-junk"],
            x: 0,
            y: 0
        )
        let blankBatteryTopic = GraphNodeRecord(
            id: "battery-health",
            title: "Battery Health",
            kind: .topic,
            confidence: 0.76,
            sourceRefs: ["source-battery"],
            x: 0,
            y: 0
        )
        let capturedAtMetadata = GraphNodeRecord(
            id: "captured-at-metadata",
            title: "captured_at: \"2026 05 31T23:41:38Z\"",
            kind: .source,
            confidence: 0.66,
            sourceRefs: ["source-capture"],
            x: 0,
            y: 0
        )
        let pluginMetadata = GraphNodeRecord(
            id: "enabled-source-plugins",
            title: "enabled source plugins: \"Google Drive, Links and web pages, Uploads\"",
            kind: .insight,
            confidence: 0.66,
            sourceRefs: ["source-plugins"],
            x: 0,
            y: 0
        )
        let appUsageMetadata = GraphNodeRecord(
            id: "activity-monitor-usage",
            title: "app | running=no | lastUsed=2026 05 29T00:00:00Z | uses=19",
            kind: .topic,
            confidence: 0.66,
            sourceRefs: ["source-apps"],
            x: 0,
            y: 0
        )
        let enabledFragment = GraphNodeRecord(
            id: "enabled-fragment",
            title: "Enabled",
            kind: .topic,
            confidence: 0.66,
            sourceRefs: ["source-enabled"],
            x: 0,
            y: 0
        )
        let bareLocation = GraphNodeRecord(
            id: "los-angeles",
            title: "Los Angeles",
            kind: .topic,
            confidence: 0.72,
            sourceRefs: ["source-location"],
            x: GraphSemanticAxes.horizontalNodeRange,
            y: -GraphSemanticAxes.verticalNodeRange
        )
        let valley = GraphNodeRecord(
            id: "valley-link",
            title: "Valley Link sustainability traffic planning",
            kind: .topic,
            confidence: 0.91,
            sourceRefs: ["source-a"],
            x: 0,
            y: 0,
            memoryLayer: .importantTrait,
            semanticColorKey: "sustainability"
        )
        let reuse = GraphNodeRecord(
            id: "reuse-traffic",
            title: "Valley Link campus traffic sustainability reuse",
            kind: .topic,
            confidence: 0.87,
            sourceRefs: ["source-b"],
            x: 0,
            y: 0,
            memoryLayer: .connector,
            semanticColorKey: "sustainability"
        )
        let unrelated = GraphNodeRecord(
            id: "essay-design",
            title: "Personal creative essay design notes",
            kind: .topic,
            confidence: 0.72,
            sourceRefs: ["source-c"],
            x: 0,
            y: 0
        )

        let plan = GraphReindexPlan.make(
            nodes: [junk, blankBatteryTopic, capturedAtMetadata, pluginMetadata, appUsageMetadata, enabledFragment, bareLocation, valley, reuse, unrelated],
            edges: [],
            maxSteps: 10
        )

        XCTAssertEqual(plan.steps.first { $0.nodeID == junk.id }?.operation, .delete)
        XCTAssertEqual(plan.steps.first { $0.nodeID == blankBatteryTopic.id }?.operation, .delete)
        XCTAssertEqual(plan.steps.first { $0.nodeID == capturedAtMetadata.id }?.operation, .delete)
        XCTAssertEqual(plan.steps.first { $0.nodeID == pluginMetadata.id }?.operation, .delete)
        XCTAssertEqual(plan.steps.first { $0.nodeID == appUsageMetadata.id }?.operation, .delete)
        XCTAssertEqual(plan.steps.first { $0.nodeID == enabledFragment.id }?.operation, .delete)
        XCTAssertEqual(plan.steps.first { $0.nodeID == bareLocation.id }?.operation, .delete)
        XCTAssertTrue(MemoryQualityPolicy.isLowInformationStandaloneTitle("Los Angeles"))
        XCTAssertTrue(plan.steps.allSatisfy { (-1...1).contains($0.unitX) && (-1...1).contains($0.unitY) })
        let animatedCoordinateBuckets = plan.steps
            .filter { $0.operation != .delete }
            .map { "\(Int(($0.unitX * 10_000).rounded()))::\(Int(($0.unitY * 10_000).rounded()))" }
        XCTAssertEqual(Set(animatedCoordinateBuckets).count, animatedCoordinateBuckets.count)

        let applied = plan.applying(to: HiveGraphSnapshot(nodes: [junk, blankBatteryTopic, capturedAtMetadata, pluginMetadata, appUsageMetadata, enabledFragment, bareLocation, valley, reuse, unrelated], edges: []))
        XCTAssertFalse(applied.nodes.contains { $0.id == junk.id })
        XCTAssertFalse(applied.nodes.contains { $0.id == blankBatteryTopic.id })
        XCTAssertFalse(applied.nodes.contains { $0.id == capturedAtMetadata.id })
        XCTAssertFalse(applied.nodes.contains { $0.id == pluginMetadata.id })
        XCTAssertFalse(applied.nodes.contains { $0.id == appUsageMetadata.id })
        XCTAssertFalse(applied.nodes.contains { $0.id == enabledFragment.id })
        XCTAssertFalse(applied.nodes.contains { $0.id == bareLocation.id })
        let finalCoordinateBuckets = applied.nodes
            .map { "\(Int(($0.x * 100).rounded()))::\(Int(($0.y * 100).rounded()))" }
        XCTAssertEqual(Set(finalCoordinateBuckets).count, finalCoordinateBuckets.count)
        XCTAssertTrue(applied.edges.contains { edge in
            edge.predicate == .related
                && Set([edge.fromID, edge.toID]) == Set([valley.id, reuse.id])
                && GraphRelationshipPolicy.isVisibleConnection(edge)
        })
    }

    func testGraphReindexAlwaysDeletesJunkOutsideMovementBudget() {
        let sourceMetadata = GraphNodeRecord(
            id: "source-metadata",
            title: "captured_at: \"2026 05 31T23:41:38Z\"",
            kind: .source,
            confidence: 0.7,
            sourceRefs: ["source-a"]
        )
        let insightMetadata = GraphNodeRecord(
            id: "insight-metadata",
            title: "enabled source plugins: \"Google Drive, Links and web pages, Uploads\"",
            kind: .insight,
            confidence: 0.7,
            sourceRefs: ["source-b"]
        )
        let appMetadata = GraphNodeRecord(
            id: "app-metadata",
            title: "app | running=no | lastUsed=2026 05 29T00:00:00Z | uses=19",
            kind: .topic,
            confidence: 0.7,
            sourceRefs: ["source-c"]
        )
        let systemMetadata = GraphNodeRecord(
            id: "system-metadata",
            title: "System",
            kind: .topic,
            confidence: 0.7,
            sourceRefs: ["source-system"]
        )
        let useful = GraphNodeRecord(
            id: "useful",
            title: "The user builds Metal shader rendering tools for a Cabin 3D app.",
            kind: .claim,
            confidence: 0.9,
            sourceRefs: ["source-d"]
        )

        let plan = GraphReindexPlan.make(
            nodes: [sourceMetadata, insightMetadata, appMetadata, systemMetadata, useful],
            edges: [],
            maxSteps: 1
        )
        let deleteIDs = Set(plan.steps.filter { $0.operation == .delete }.map(\.nodeID))
        let moveSteps = plan.steps.filter { $0.operation != .delete }

        XCTAssertEqual(deleteIDs, [sourceMetadata.id, insightMetadata.id, appMetadata.id, systemMetadata.id])
        XCTAssertEqual(moveSteps.count, 1)
        XCTAssertTrue(MemoryQualityPolicy.isLowInformationStandaloneTitle("captured_at: \"2026 05 31T23:41:38Z\""))
        XCTAssertTrue(MemoryQualityPolicy.isLowInformationStandaloneTitle("enabled_source_plugins: \"Google Drive, Links and web pages, Uploads\""))
        XCTAssertTrue(MemoryQualityPolicy.isLowInformationStandaloneTitle("System"))

        let applied = plan.applying(to: HiveGraphSnapshot(nodes: [sourceMetadata, insightMetadata, appMetadata, systemMetadata, useful], edges: []))
        XCTAssertEqual(applied.nodes.map(\.id), [useful.id])
    }

    func testGraphReindexDoesNotSaturateGenericProjectNodesIntoTopBand() {
        let nodes = (0..<12).map { index in
            GraphNodeRecord(
                id: "project-workflow-\(index)",
                title: "Project workflow note \(index) about app implementation detail and local tools",
                kind: .topic,
                confidence: 0.74,
                sourceRefs: ["source-\(index)"],
                x: index.isMultiple(of: 2) ? -GraphSemanticAxes.horizontalNodeRange : GraphSemanticAxes.horizontalNodeRange,
                y: index.isMultiple(of: 3) ? -GraphSemanticAxes.verticalNodeRange : GraphSemanticAxes.verticalNodeRange,
                memoryLayer: .connector
            )
        }

        let plan = GraphReindexPlan.make(nodes: nodes, edges: [], maxSteps: nodes.count)
        let movedSteps = plan.steps.filter { $0.operation != .delete }
        let saturatedTopBandCount = movedSteps.filter { $0.unitY > 0.78 }.count

        XCTAssertEqual(movedSteps.count, nodes.count)
        XCTAssertLessThanOrEqual(saturatedTopBandCount, 2)
        XCTAssertGreaterThanOrEqual(movedSteps.filter { abs($0.unitY) < 0.7 }.count, 9)
    }

    func testRepeatedGraphReindexReplacesGeneratedAuditEdgesWithoutEdgeSoup() {
        let nodes = (0..<10).map { index in
            GraphNodeRecord(
                id: "valley-sustainability-\(index)",
                title: "Valley Link sustainability traffic planning segment \(index)",
                kind: .topic,
                confidence: 0.82,
                sourceRefs: ["source-\(index)"],
                x: 0,
                y: 0,
                memoryLayer: .connector,
                semanticColorKey: "sustainability"
            )
        }

        let firstPlan = GraphReindexPlan.make(nodes: nodes, edges: [], maxSteps: nodes.count)
        let firstApplied = firstPlan.applying(to: HiveGraphSnapshot(nodes: nodes, edges: []))
        let secondPlan = GraphReindexPlan.make(nodes: firstApplied.nodes, edges: firstApplied.edges, maxSteps: nodes.count)
        let secondApplied = secondPlan.applying(to: firstApplied)
        let auditEdges = secondApplied.edges.filter { $0.id.hasPrefix("audit-") }
        let auditDegree = auditEdges.reduce(into: [String: Int]()) { result, edge in
            result[edge.fromID, default: 0] += 1
            result[edge.toID, default: 0] += 1
        }

        XCTAssertLessThanOrEqual(auditEdges.count, nodes.count * 2)
        XCTAssertLessThanOrEqual(auditDegree.values.max() ?? 0, 4)
        XCTAssertEqual(Set(auditEdges.map(\.id)).count, auditEdges.count)
    }

    func testGraphChangeAnimationListDiffsUsefulChangesForFifteenSecondPlayback() {
        let stableBefore = GraphNodeRecord(
            id: "hive-build",
            title: "The user is building Hive as a local memory graph.",
            kind: .claim,
            confidence: 0.95,
            sourceRefs: ["source-a"],
            x: -30,
            y: 20,
            memoryLayer: .importantTrait
        )
        let stableAfter = GraphNodeRecord(
            id: "hive-build",
            title: "The user is building Hive as a local memory graph.",
            kind: .claim,
            confidence: 0.96,
            sourceRefs: ["source-a"],
            x: 120,
            y: -90,
            memoryLayer: .importantTrait
        )
        let removedForMerge = GraphNodeRecord(
            id: "mac-shopping-old",
            title: "The user compared Mac Studio shopping paths for funding.",
            kind: .claim,
            confidence: 0.8,
            sourceRefs: ["source-b"],
            x: 250,
            y: -120,
            memoryLayer: .connector
        )
        let mergeTarget = GraphNodeRecord(
            id: "mac-funding",
            title: "The user is researching grants and scholarships for a Mac Studio.",
            kind: .claim,
            confidence: 0.92,
            sourceRefs: ["source-b"],
            x: 280,
            y: -140,
            memoryLayer: .importantTrait
        )
        let inserted = GraphNodeRecord(
            id: "ucla-coursework",
            title: "The user is tracking current UCLA coursework.",
            kind: .claim,
            confidence: 0.88,
            sourceRefs: ["source-c"],
            x: 90,
            y: -180,
            memoryLayer: .connector
        )
        let deleted = GraphNodeRecord(
            id: "old-one-off",
            title: "The user kept an outdated one-off trail for later review.",
            kind: .claim,
            confidence: 0.64,
            sourceRefs: ["source-d"],
            x: -180,
            y: 120,
            memoryLayer: .detail
        )
        let generic = GraphNodeRecord(
            id: "generic-work",
            title: "Work",
            kind: .topic,
            confidence: 1,
            sourceRefs: [],
            x: 0,
            y: 0
        )
        let previous = HiveGraphSnapshot(nodes: [stableBefore, removedForMerge, deleted, generic], edges: [])
        let current = HiveGraphSnapshot(nodes: [stableAfter, mergeTarget, inserted], edges: [
            GraphEdgeRecord(
                id: "new-relationship",
                fromID: stableAfter.id,
                toID: inserted.id,
                predicate: .related,
                strength: 0.66,
                confidence: 0.8,
                evidenceCount: 2
            )
        ])

        let list = GraphChangeAnimationList.make(previous: previous, current: current, now: Date(timeIntervalSince1970: 100))
        let kinds = Set(list.events.map(\.kind))

        XCTAssertEqual(GraphChangeAnimationList.playbackDuration, 15)
        XCTAssertTrue(kinds.contains(.movement))
        XCTAssertTrue(kinds.contains(.combination))
        XCTAssertTrue(kinds.contains(.insertion))
        XCTAssertTrue(kinds.contains(.deletion))
        XCTAssertTrue(kinds.contains(.connectionInsertion))
        XCTAssertTrue(list.events.allSatisfy { $0.startOffset + $0.duration <= GraphChangeAnimationList.playbackDuration + 0.0001 })
        XCTAssertTrue(list.events.allSatisfy { $0.duration <= 2.4 + 0.0001 })
        XCTAssertTrue(list.events.contains { $0.curve == .bounce })
        XCTAssertTrue(list.events.contains { $0.curve == .spring })
        XCTAssertTrue(list.events.contains { $0.curve == .sine })
        XCTAssertFalse(list.events.flatMap { Array($0.affectedNodeIDs) }.contains(generic.id))
        XCTAssertFalse(GraphChangeAnimationList.isUsefulAnimationTitle("Work"))
        XCTAssertFalse(GraphChangeAnimationList.isUsefulAnimationTitle("Captured memory"))
        XCTAssertTrue(GraphChangeAnimationList.isUsefulAnimationTitle("The user is building Hive as a local memory graph."))
    }

    func testGraphPersonalCenterUsesWeightedHoneycombAverage() {
        let defining = GraphNodeRecord(
            id: "identity",
            title: "The user is a UCLA student building Hive.",
            kind: .claim,
            confidence: 1,
            sourceRefs: [],
            x: 100,
            y: -80,
            memoryLayer: .definingTrait
        )
        let detail = GraphNodeRecord(
            id: "detail",
            title: "The user saved one incidental browser trail.",
            kind: .claim,
            confidence: 0.2,
            sourceRefs: [],
            x: -400,
            y: 240,
            memoryLayer: .detail
        )

        let center = GraphPersonalCenter.weightedCenter(for: [defining, detail])
        let normalizedDefining = GraphPersonalCenter.normalizedCoordinate(for: defining, center: center)

        XCTAssertGreaterThan(center.x, 60)
        XCTAssertLessThan(center.y, -40)
        XCTAssertLessThan(abs(normalizedDefining.x), abs(detail.x - center.x))
        XCTAssertGreaterThan(GraphPersonalCenter.weight(for: defining), GraphPersonalCenter.weight(for: detail))
    }

    func testGraphDoesNotShowGenericCategoryHoneycombs() {
        XCTAssertFalse(GraphNodeRecord(id: "work", title: "Work", kind: .topic, confidence: 1, sourceRefs: []).isUserVisibleGraphNode)
        XCTAssertFalse(GraphNodeRecord(id: "background", title: "Background", kind: .topic, confidence: 1, sourceRefs: []).isUserVisibleGraphNode)
        XCTAssertFalse(GraphNodeRecord(id: "python", title: "Python", kind: .topic, confidence: 1, sourceRefs: []).isUserVisibleGraphNode)
        XCTAssertFalse(GraphNodeRecord(id: "unreal", title: "Unreal Engine", kind: .topic, confidence: 1, sourceRefs: ["source-unreal"]).isUserVisibleGraphNode)
        XCTAssertFalse(GraphNodeRecord(id: "experience", title: "Experience", kind: .topic, confidence: 1, sourceRefs: []).isUserVisibleGraphNode)
        XCTAssertFalse(GraphNodeRecord(id: "battery-health", title: "Battery Health", kind: .topic, confidence: 1, sourceRefs: ["battery-source"]).isUserVisibleGraphNode)
        XCTAssertTrue(GraphNodeRecord(
            id: "python-use",
            title: "The user uses Python for quant and model workflows.",
            kind: .claim,
            confidence: 1,
            sourceRefs: []
        ).isUserVisibleGraphNode)
        XCTAssertTrue(GraphNodeRecord(
            id: "unreal-use",
            title: "The user built a level prototype in Unreal Engine.",
            kind: .claim,
            confidence: 1,
            sourceRefs: ["source-unreal"]
        ).isUserVisibleGraphNode)
    }

    func testRuntimePolicyBlocksBackgroundInferenceOnNonNominalThermalState() {
        let policy = RuntimePolicy()
        let fair = RuntimeProfile(
            chipName: "MacBookPro",
            physicalMemoryBytes: 16 * 1_073_741_824,
            processorCount: 10,
            thermalState: .fair,
            powerState: .pluggedIn,
            lowPowerModeEnabled: false,
            foregroundUserActive: false
        )
        let decision = policy.decision(for: .summarization, profile: fair, manual: false, computeMode: .background)
        XCTAssertFalse(decision.allowed)

        let manual = policy.decision(for: .summarization, profile: fair, manual: true, computeMode: .balanced)
        XCTAssertTrue(manual.allowed)
    }

    func testRuntimePolicyBlocksLowBatteryBackgroundInference() {
        let policy = RuntimePolicy()
        let profile = RuntimeProfile(
            chipName: "MacBookPro",
            physicalMemoryBytes: 16 * 1_073_741_824,
            processorCount: 10,
            thermalState: .nominal,
            powerState: .battery,
            batteryChargeFraction: 0.24,
            lowPowerModeEnabled: false,
            foregroundUserActive: false
        )
        let decision = policy.decision(for: .embedding, profile: profile, manual: false, computeMode: .background)
        XCTAssertFalse(decision.allowed)
    }

    func testRendererResourcesAndPathMath() {
        XCTAssertEqual(Set(HiveShaderResource.allCases.map(\.rawValue)), [
            "amber_cell.metal",
            "neural_path.metal",
            "grain_noise.metal",
            "frosted_amber_preview.metal",
            "wax_pour.metal",
            "cracked_wax.metal"
        ])
        let material = NeuralPathMaterial(baseWeight: 10, confidence: 0.5)
        XCTAssertEqual(material.thickness(at: 0), 4, accuracy: 0.0001)
        XCTAssertEqual(material.thickness(at: 0.5), 4.9, accuracy: 0.0001)
        XCTAssertEqual(material.thickness(at: 1), 4, accuracy: 0.0001)
        XCTAssertTrue(material.isDashed)
    }

    func testGraphSearchSurfaceUsesHIGSearchGuidance() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let graphSurface = root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift")
        let body = try String(contentsOf: graphSurface)

        XCTAssertTrue(body.contains("Find people, projects, or memories"))
        XCTAssertTrue(body.contains("Suggestions"))
        XCTAssertTrue(body.contains("matching memories"))
        XCTAssertTrue(body.contains("searchSuggestions"))
        XCTAssertTrue(body.contains("searchResultSummary"))
        XCTAssertTrue(body.contains("submitGraphSearch()"))
        XCTAssertFalse(body.contains("@State private var graphControlsMinimized"))
        XCTAssertTrue(body.contains("private enum GraphInstrumentSection"))
        XCTAssertTrue(body.contains("case filters = \"Filters\""))
        XCTAssertTrue(body.contains("case groups = \"Groups\""))
        XCTAssertTrue(body.contains("case display = \"Display\""))
        XCTAssertTrue(body.contains("@AppStorage(\"Hive.Graph.showTopicNodes\")"))
        XCTAssertTrue(body.contains("@AppStorage(\"Hive.Graph.showOrphanNodes\")"))
        XCTAssertTrue(body.contains("@AppStorage(\"Hive.Graph.colorByGroups\")"))
        XCTAssertTrue(body.contains("@AppStorage(\"Hive.Graph.showEdgeArrows\")"))
        XCTAssertTrue(body.contains("title: \"Hive\""))
        XCTAssertTrue(body.contains("Opens Hive actions as a vertical menu."))
        XCTAssertTrue(body.contains("HiveSymbol(.disclosure"))
        XCTAssertTrue(body.contains("let instrumentControlWidth"))
        XCTAssertTrue(body.contains("GraphMenuLabel(\"Search The Hive\""))
        XCTAssertTrue(body.contains("GraphMenuLabel(\"Center\""))
        XCTAssertTrue(body.contains("GraphMenuLabel(\"Filters\""))
        XCTAssertTrue(body.contains("GraphMenuLabel(\"Groups\""))
        XCTAssertTrue(body.contains("GraphMenuLabel(\"Display\""))
        XCTAssertTrue(body.contains("graphFilterControls"))
        XCTAssertTrue(body.contains("graphGroupControls"))
        XCTAssertTrue(body.contains("graphDisplayControls"))
        XCTAssertTrue(body.contains("GraphCompactSlider(title: \"Nodes\""))
        XCTAssertTrue(body.contains("GraphCompactSlider(title: \"Links\""))
        XCTAssertFalse(body.contains("runTimelapse()"))
        XCTAssertTrue(body.contains("graphLayoutPreset.spreadMultiplier"))
        XCTAssertFalse(body.contains("HiveText(\"Hive\", role: .scaffoldAction)"))
        XCTAssertTrue(body.contains("HiveSymbolButton(.send, title: \"Ask\""))
        XCTAssertTrue(body.contains("graphSearchTopMatches(for: query)"))
        XCTAssertTrue(body.contains("searchScore(_ node: GraphNodeRecord, query: String)"))
        XCTAssertFalse(body.contains("bottomPill"))
        XCTAssertFalse(body.contains("zoomLevel.label"))
        XCTAssertFalse(body.contains("return \"Areas\""))
    }

    func testGraphSemanticAxesRemainModelOnlyAndDailyCoordinateRefreshIsEncoded() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let graphSurface = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))
        let graphSemantics = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/GraphPresentationSemantics.swift"))
        let wikiEngine = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/WikiEngine.swift"))

        XCTAssertFalse(graphSurface.contains("GraphAxisOverlay("))
        XCTAssertFalse(graphSurface.contains("struct GraphAxisOverlay"))
        XCTAssertFalse(graphSurface.contains("professionalLabel: currentAxisVocabulary.top"))
        XCTAssertFalse(graphSurface.contains("personalLabel: currentAxisVocabulary.bottom"))
        XCTAssertFalse(graphSurface.contains("analyticalLabel: currentAxisVocabulary.right"))
        XCTAssertFalse(graphSurface.contains("creativeLabel: currentAxisVocabulary.left"))
        XCTAssertTrue(graphSurface.contains("minimumGraphScale(for: viewport)"))
        XCTAssertTrue(graphSurface.contains("graphAutoCenterSignature"))
        XCTAssertTrue(graphSurface.contains("applyCenteredViewport(in: proxy.size)"))
        XCTAssertTrue(graphSurface.contains("axisScreenScale(in: size)"))
        XCTAssertTrue(graphSurface.contains("HiveGraphGeometry.axisViewportMarginRatio"))
        XCTAssertTrue(graphSurface.contains("HiveGraphGeometry.scrollViewportMarginRatio"))
        XCTAssertTrue(graphSurface.contains("HiveGraphGeometry.renderedSemanticExtent(GraphSemanticAxes.horizontalExtent)"))
        XCTAssertTrue(graphSurface.contains("HiveGraphGeometry.renderedSemanticExtent(GraphSemanticAxes.verticalExtent)"))
        XCTAssertTrue(graphSurface.contains("clampedGraphOffset(_ proposed: CGSize, in viewport: CGSize, scale proposedScale: CGFloat)"))
        XCTAssertTrue(graphSurface.contains("graphOffsetRange("))
        XCTAssertTrue(graphSurface.contains("offset = clampedGraphOffset(proposedOffset, in: viewport, scale: newScale)"))
        XCTAssertTrue(graphSurface.contains("settledOffset = clampedGraphOffset(offset, in: proxy.size, scale: scale)"))
        XCTAssertTrue(graphSurface.contains("applyInitialAxisFitIfNeeded(in: proxy.size)"))
        XCTAssertFalse(graphSurface.contains("style: StrokeStyle(lineWidth: 1.2, lineCap: .butt)"))
        XCTAssertFalse(graphSurface.contains("for point in [professional, personal, analytical, creative]"))
        XCTAssertTrue(graphSemantics.contains("Up is professional, down is personal; right is analytical, left is creative."))
        XCTAssertTrue(wikiEngine.contains("graph.coordinatesUpdated"))
        XCTAssertTrue(wikiEngine.contains("GraphSemanticAxes.semanticSummary"))
    }

    func testGraphOmitsYouAnchorAndKeepsOverviewFit() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let graphSurface = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))
        let graphSemantics = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/GraphPresentationSemantics.swift"))

        XCTAssertTrue(graphSemantics.contains("public enum GraphPersonalCenter"))
        XCTAssertTrue(graphSemantics.contains("weightedCenter(for nodes: [GraphNodeRecord])"))
        XCTAssertFalse(graphSurface.contains("GraphYouAnchorHoneycomb"))
        XCTAssertFalse(graphSurface.contains("Text(\"YOU\")"))
        XCTAssertFalse(graphSurface.contains("You, weighted center of The Hive"))
        XCTAssertFalse(graphSurface.contains("HiveGraphGeometry.userAnchorSize"))
        XCTAssertTrue(graphSurface.contains("private var graphCenterAnchor"))
        XCTAssertTrue(graphSurface.contains("personalCenterOffset(in: viewport, scale: scale)"))
        XCTAssertTrue(graphSurface.contains("offset = personalCenterOffset(in: proxy.size, scale: scale)"))
        XCTAssertFalse(graphSurface.contains("offset = .zero\n                        settledOffset = .zero"))
        XCTAssertTrue(graphSurface.contains("HiveGraphGeometry.coordinateDilation"))
        XCTAssertTrue(graphSurface.contains("displayCoordinate(for: GraphSemanticCoordinate(x: node.x, y: node.y))"))
        XCTAssertFalse(graphSurface.contains("GraphPersonalCenter.normalizedCoordinate(for: node, center: graphCenterAnchor)"))
        XCTAssertTrue(graphSurface.contains("private var graphContentBounds"))
        XCTAssertTrue(graphSurface.contains("let bounds = graphContentBounds"))
    }

    func testHiveReindexControlAndAnimationAreEncoded() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let graphSurface = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))
        let graphSemantics = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/GraphPresentationSemantics.swift"))
        let graphChangeAnimation = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/GraphChangeAnimation.swift"))
        let foundationOrchestrator = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/HiveFoundationModelsOrchestrator.swift"))
        let localInference = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/LocalInference.swift"))
        let appModel = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveAppModel.swift"))
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))

        XCTAssertTrue(graphSemantics.contains("public struct GraphReindexPlan"))
        XCTAssertTrue(graphSemantics.contains("public enum GraphReindexOperation"))
        XCTAssertTrue(graphChangeAnimation.contains("public struct GraphChangeAnimationList"))
        XCTAssertTrue(graphChangeAnimation.contains("public static let playbackDuration: TimeInterval = 15"))
        XCTAssertTrue(graphChangeAnimation.contains("case insertion"))
        XCTAssertTrue(graphChangeAnimation.contains("case deletion"))
        XCTAssertTrue(graphChangeAnimation.contains("case movement"))
        XCTAssertTrue(graphChangeAnimation.contains("case combination"))
        XCTAssertTrue(graphChangeAnimation.contains("case split"))
        XCTAssertTrue(graphChangeAnimation.contains("case sine"))
        XCTAssertTrue(graphChangeAnimation.contains("case spring"))
        XCTAssertTrue(graphChangeAnimation.contains("case bounce"))
        XCTAssertTrue(graphChangeAnimation.contains("isUsefulAnimationTitle"))
        XCTAssertTrue(graphSemantics.contains("public func unitCoordinate(for node: GraphNodeRecord)"))
        XCTAssertTrue(graphSemantics.contains("semanticReindexUnit(for: node"))
        XCTAssertTrue(graphSemantics.contains("reindexMaximumSemanticComponent"))
        XCTAssertTrue(graphSemantics.contains("reindexPriority(for: node"))
        XCTAssertTrue(graphSemantics.contains("mergedSizeMultiplier"))
        XCTAssertTrue(graphSurface.contains("changeAnimationList: GraphChangeAnimationList = .empty"))
        XCTAssertTrue(graphSurface.contains("graphChangeGhostNodes"))
        XCTAssertTrue(graphSurface.contains("edgeRevealMultiplier"))
        XCTAssertTrue(graphSurface.contains("nodeChangeScale"))
        XCTAssertTrue(graphSurface.contains("GraphMenuLabel(isReindexing ? \"Re-indexing\" : \"Re-index\""))
        XCTAssertTrue(graphSurface.contains(".disabled(isReindexing || visibleNodes.isEmpty)"))
        XCTAssertTrue(graphSurface.contains("Planning with Apple Intelligence"))
        XCTAssertTrue(graphSurface.contains("GraphReindexPlan.makeWithFoundationModelsResult("))
        XCTAssertFalse(graphSurface.contains("let plan = GraphReindexPlan.make(nodes: nodes, edges: edges"))
        XCTAssertTrue(graphSurface.contains("static let maximumConcurrentJobs = 4"))
        XCTAssertTrue(graphSurface.contains("GraphReindexJob.maximumConcurrentJobs"))
        XCTAssertTrue(graphSurface.contains("activeReindexJobs"))
        XCTAssertTrue(graphSurface.contains("reindexCompletedStepCount"))
        XCTAssertTrue(graphSurface.contains("GraphReindexAuditPair"))
        XCTAssertTrue(graphSurface.contains("GraphReindexOverlayEdgeItem"))
        XCTAssertTrue(graphSurface.contains("configureReindexAudit(application: application)"))
        XCTAssertTrue(graphSurface.contains("reindexOverlayEdges(positions: positions, in: size, at: date)"))
        XCTAssertTrue(graphSurface.contains("reindexAcceptedAuditEdges"))
        XCTAssertTrue(graphSurface.contains("Testing connections"))
        XCTAssertTrue(graphSurface.contains("Making connections"))
        XCTAssertTrue(graphSurface.contains("reindexPairAuditChunkSize"))
        XCTAssertTrue(graphSurface.contains("TimelineView(.animation"))
        XCTAssertTrue(graphSurface.contains("progress(at date: Date)"))
        XCTAssertTrue(graphSurface.contains("reindexDuration(for: step"))
        XCTAssertTrue(graphSurface.contains("reindexDuration(for: step, index: nextIndex, in: currentViewportSize)"))
        XCTAssertTrue(graphSurface.contains("reindexAnimatedPoint("))
        XCTAssertTrue(graphSurface.contains("reindexStartPoint(for: step"))
        XCTAssertTrue(graphSurface.contains("fillReindexSlots()"))
        XCTAssertTrue(graphSurface.contains("reindexTargetPoint(for: step"))
        XCTAssertTrue(graphSurface.contains("case planning"))
        XCTAssertTrue(graphSurface.contains("GraphReindexSyntheticHoneycomb"))
        XCTAssertTrue(graphSurface.contains("reindexSyntheticNodes"))
        XCTAssertTrue(graphSurface.contains("GraphReindexStatusLine("))
        XCTAssertFalse(graphSurface.contains("GraphViewportControls("))
        XCTAssertTrue(graphSurface.contains("GraphMenuLabel(\"Zoom in\", symbol: .zoomIn)"))
        XCTAssertTrue(graphSurface.contains("GraphMenuLabel(\"Zoom out\", symbol: .zoomOut)"))
        XCTAssertTrue(graphSurface.contains("GraphMenuLabel(\"Center\", symbol: .recenter)"))
        XCTAssertTrue(graphSurface.contains("GraphRenderLayer(nodes: rendered.nodes, edges: rendered.edges, reindexEdges: rendered.reindexEdges)"))
        XCTAssertTrue(graphSurface.contains("for edge in reindexEdges"))
        XCTAssertTrue(graphSurface.contains("for node in nodes where !node.selected"))
        XCTAssertTrue(graphSurface.contains("onReindex(reindexPlan)"))
        XCTAssertFalse(graphSurface.contains("Focus Path"))
        XCTAssertFalse(graphSurface.contains("title: selectedNodeID == nil ? \"Focus\""))
        XCTAssertTrue(appModel.contains("@Published public private(set) var graphAnimationList: GraphChangeAnimationList = .empty"))
        XCTAssertTrue(appModel.contains("GraphChangeAnimationList.make(previous: previousGraph, current: nextGraph)"))
        XCTAssertTrue(appModel.contains("GraphChangeAnimationList.playbackDuration + 0.35"))
        XCTAssertTrue(appModel.contains("public func reindexHive(plan: GraphReindexPlan"))
        XCTAssertTrue(appModel.contains("plan.applyingWithAudit(to: snapshot)"))
        XCTAssertTrue(appModel.contains("applyGraphSnapshot(nextGraph, animateChangeList: false)"))
        XCTAssertFalse(foundationOrchestrator.contains("Deterministic fallback steps:"))
        XCTAssertFalse(foundationOrchestrator.contains("current coordinates"))
        XCTAssertTrue(foundationOrchestrator.contains("@Guide(description: \"Fresh x-axis target"))
        XCTAssertTrue(foundationOrchestrator.contains("@Guide(description: \"Fresh y-axis target"))
        XCTAssertTrue(foundationOrchestrator.contains("Ignore every existing graph coordinate"))
        XCTAssertTrue(foundationOrchestrator.contains("Do not copy a fixed spatial pattern"))
        XCTAssertGreaterThanOrEqual(foundationOrchestrator.components(separatedBy: "ExtractionQualityRules.systemPrompt").count - 1, 4)
        XCTAssertTrue(localInference.contains("ExtractionQualityRules.systemPrompt"))
        XCTAssertTrue(localInference.contains("Suggested nodes must be atomic, sourced, and user-relevant."))
        XCTAssertTrue(foundationOrchestrator.contains("Every generated claim/entity must cite the source ID"))
        XCTAssertTrue(macRoot.contains("changeAnimationList: model.graphAnimationList"))
        XCTAssertTrue(macRoot.contains("onReindex: { plan in model.reindexHive(plan: plan) }"))
    }

    func testGraphSelectionAndHoverExposePlainFeedback() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let graphSurface = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))
        let overlays = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))

        XCTAssertFalse(graphSurface.contains("selectedConnectionSummary(for: selectedNode)"))
        XCTAssertTrue(graphSurface.contains("relatedEntries: connectedNodes(to: hoveredNode).prefixArray(3)"))
        XCTAssertTrue(graphSurface.contains("enterHover(nodeID: item.id, at: item.center)"))
        XCTAssertTrue(graphSurface.contains("GraphContinuousHoverModifier"))
        XCTAssertTrue(graphSurface.contains("selectedID: hoveredNodeID ?? selectedNodeID"))
        XCTAssertTrue(graphSurface.contains("private struct GraphHoverFocusModel"))
        XCTAssertTrue(graphSurface.contains("firstNodeIDs"))
        XCTAssertTrue(graphSurface.contains("secondNodeIDs"))
        XCTAssertTrue(graphSurface.contains("return 0.67 * hoverRevealProgress"))
        XCTAssertTrue(graphSurface.contains("return 0.33 * hoverRevealProgress"))
        XCTAssertTrue(graphSurface.contains("static let dimDuration: TimeInterval = 1.65"))
        XCTAssertTrue(graphSurface.contains("hoverEdgeRevealProgress(tier: $0, at: date)"))
        XCTAssertTrue(graphSurface.contains("revealStart: hoverEdgePath.flatMap { positions[$0.startNodeID] }"))
        XCTAssertTrue(graphSurface.contains("revealEnd: hoverEdgePath.flatMap { positions[$0.endNodeID] }"))
        XCTAssertTrue(graphSurface.contains("edge.litPath"))
        XCTAssertTrue(graphSurface.contains("func edgePath(for edge: GraphEdgeRecord) -> GraphHoverEdgePath?"))
        XCTAssertTrue(graphSurface.contains("target = 0.10 + (0.50 - 0.10) * reveal"))
        XCTAssertTrue(graphSurface.contains("target = 0.08 + (0.25 - 0.08) * reveal"))
        XCTAssertFalse(graphSurface.contains("GraphHoverAura(color: domain(for: hoveredNode).graphColor"))
        XCTAssertFalse(graphSurface.contains("HiveFocusRipple("))
        XCTAssertFalse(graphSurface.contains("selectionRippleTrigger"))
        XCTAssertFalse(graphSurface.contains(".repeatForever(autoreverses: true)"))
        XCTAssertTrue(graphSurface.contains("updateHover(at: point, in: size, cache: cache)"))
        XCTAssertTrue(graphSurface.contains("let hitRadius = max(HiveHIGPolicy.minimumGraphAccessibilityTarget / 2"))
        XCTAssertTrue(graphSurface.contains("guard hoveredNodeID == nodeID else { return }"))
        XCTAssertTrue(graphSurface.contains("hoveredNodePoint ?? position(for: node.id, in: size)"))
        XCTAssertTrue(graphSurface.contains("Related Colony entries"))
        XCTAssertTrue(graphSurface.contains("private var importantConnections"))
        XCTAssertTrue(graphSurface.contains("graphEntryImportanceSort"))
        XCTAssertFalse(graphSurface.contains("nearby memories in this part of the user's life"))
        XCTAssertFalse(graphSurface.contains("private var whyItMatters"))
        XCTAssertFalse(graphSurface.contains("Hive keeps this as a"))
        XCTAssertFalse(graphSurface.contains("WaxSparkline"))
        XCTAssertFalse(graphSurface.contains("Connected cells"))
        XCTAssertFalse(graphSurface.contains("return trace"))
        XCTAssertFalse(graphSurface.contains("sourceTraceText"))
        XCTAssertTrue(overlays.contains("private let items: [HiveAccessibilityGraphItem]"))
        XCTAssertTrue(overlays.contains(".accessibilityLabel(item.label)"))
        XCTAssertTrue(overlays.contains(".accessibilityValue(item.value)"))
        XCTAssertTrue(overlays.contains("Selects this memory and opens its details."))
    }

    func testSelectionSurfacesDefaultToAskAboutThis() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let rawInputs = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/RawInputsSurface.swift"))
        let wiki = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/WikiSurface.swift"))
        let graph = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))

        XCTAssertTrue(macRoot.contains("Ask about this Field item"))
        XCTAssertTrue(rawInputs.contains(".contentShape(Rectangle())"))
        XCTAssertTrue(rawInputs.contains("@State private var sourceSearchText = \"\""))
        XCTAssertTrue(rawInputs.contains("Titles, topics, or summaries"))
        XCTAssertTrue(rawInputs.contains("Recent Field"))
        XCTAssertFalse(rawInputs.contains("Feed the Hive"))
        XCTAssertFalse(rawInputs.contains("Add a note, speak, attach files, or drop anything onto this field."))
        XCTAssertTrue(rawInputs.contains("TextEditor(text: $feedDraft)"))
        XCTAssertTrue(rawInputs.contains("Tell Hive..."))
        XCTAssertTrue(rawInputs.contains("HiveSymbol(\n                        .voiceNote"))
        XCTAssertTrue(rawInputs.contains("HiveSymbol(.attach, size: 16)"))
        XCTAssertTrue(rawInputs.contains("title: nil"))
        XCTAssertTrue(rawInputs.contains("HiveSymbol(\n                        .send"))
        XCTAssertFalse(rawInputs.contains("feedComposerOpen"))
        XCTAssertTrue(rawInputs.contains("FeedPulseOverlay"))
        XCTAssertTrue(rawInputs.contains("onSubmitText"))
        XCTAssertTrue(rawInputs.contains("Add to Field…"))
        XCTAssertFalse(rawInputs.contains("Add Raw Sources"))
        XCTAssertTrue(rawInputs.contains("Search Field"))
        XCTAssertTrue(rawInputs.contains("Start with anything"))
        XCTAssertTrue(rawInputs.contains("No matching Field items"))
        XCTAssertTrue(rawInputs.contains("ProgressView()"))
        XCTAssertTrue(rawInputs.contains("Extract more information"))
        XCTAssertTrue(rawInputs.contains("accessibilityValue(selected ? \"Selected\" : \"Not selected\")"))
        XCTAssertTrue(rawInputs.contains("Opens Field details and an ask box."))
        XCTAssertFalse(rawInputs.contains("HiveText(\"Inspect\", role: .scaffoldAction)"))
        XCTAssertFalse(rawInputs.contains("HiveText(\"Selected\", role: .scaffoldLabel)"))
        XCTAssertTrue(rawInputs.contains(".help(title)"))
        XCTAssertTrue(rawInputs.contains(".help(rowSummary ?? \"No summary yet\")"))
        XCTAssertTrue(wiki.contains("Ask about this article"))
        XCTAssertTrue(wiki.contains("Ask about this fact"))
        XCTAssertTrue(wiki.contains("Ask for a simpler explanation or next step"))
        XCTAssertTrue(wiki.contains("Ask why this is here or what supports it"))
        XCTAssertFalse(wiki.contains("The Colony is AI-maintained"))
        XCTAssertTrue(wiki.contains("HiveActionButton(\"Save\", symbol: .confirmed)"))
        XCTAssertTrue(wiki.contains("HiveActionButton(\"Cancel\", symbol: .close)"))
        XCTAssertTrue(wiki.contains("Correction saved"))
        XCTAssertFalse(wiki.contains("Open Questions appears here when Hive needs a decision."))
        XCTAssertTrue(wiki.contains("isVisibleInColony"))
        XCTAssertTrue(wiki.contains("colonySelectionToolbar"))
        XCTAssertTrue(wiki.contains("Merge into"))
        XCTAssertTrue(wiki.contains("Deletes selected Colony pages"))
        XCTAssertTrue(wiki.contains(".alert("))
        XCTAssertFalse(wiki.contains("Text(markedForConsolidation ? \"Selected\" : \"Select\")"))
        XCTAssertTrue(wiki.contains("markedForConsolidation ? .select : .unselected"))
        XCTAssertTrue(wiki.contains("if !openQuestionClaims.isEmpty"))
        XCTAssertTrue(wiki.contains("if !conflictClaims.isEmpty"))
        XCTAssertTrue(wiki.contains("if !strongClaims.isEmpty"))
        XCTAssertTrue(wiki.contains(".help(cleanTitle)"))
        XCTAssertTrue(wiki.contains(".help(cleanSummary)"))
        XCTAssertFalse(wiki.contains("HiveWaxRail(active: selected || markedForConsolidation)"))
        XCTAssertTrue(wiki.contains(".keyboardShortcut(\"s\", modifiers: [.command])"))
        XCTAssertFalse(wiki.contains("Etching changes"))
        XCTAssertFalse(wiki.contains("Sealed locally"))
        XCTAssertTrue(graph.contains("Ask about this memory"))
        XCTAssertTrue(graph.contains("Ask why it matters or what connects"))
        XCTAssertTrue(graph.contains("Related Colony entries"))
        XCTAssertFalse(graph.contains("private var layerLabel"))
        XCTAssertFalse(graph.contains("Read the map by interaction"))
        XCTAssertFalse(graph.contains("Hover a cell to identify it. Click for details."))
        XCTAssertFalse(graph.contains("HiveText(\"Time\", role: .scaffoldMicro)"))
        XCTAssertTrue(graph.contains("graphPreferredFramesPerSecond"))
        XCTAssertTrue(graph.contains("hoverHitNodes(in: size, cache: cache"))
        XCTAssertTrue(graph.contains("lastHoverUpdateTime"))
        XCTAssertFalse(macRoot.contains("AGENTS.md"))
        XCTAssertFalse(wiki.contains("AGENTS.md"))
        XCTAssertFalse(graph.contains("AGENTS.md"))
    }

    func testColonyArticleSelectionMergeAndDeleteUseBackendFlow() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let wiki = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/WikiSurface.swift"))
        let appModel = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveAppModel.swift"))
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let wikiEngine = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/WikiEngine.swift"))

        XCTAssertTrue(wiki.contains("public var onDeleteArticles: ([String]) -> Void"))
        XCTAssertTrue(wiki.contains("@State private var pendingDeleteArticleIDs: Set<String> = []"))
        XCTAssertTrue(wiki.contains("@State private var deleteConfirmationVisible = false"))
        XCTAssertTrue(wiki.contains("canConsolidateSelection"))
        XCTAssertTrue(wiki.contains("requestDeleteArticles(selectedArticleIDs)"))
        XCTAssertTrue(wiki.contains("requestDeleteArticles([page.id])"))
        XCTAssertTrue(wiki.contains("private func deletePendingArticles()"))
        XCTAssertTrue(wiki.contains("onDeleteArticles(Array(ids))"))
        XCTAssertTrue(wiki.contains("This removes only the selected Colony article pages. Field sources stay untouched."))
        XCTAssertTrue(wiki.contains("WikiMenuLabel(\"Delete article\", symbol: .forget)"))
        XCTAssertTrue(macRoot.contains("onDeleteArticles: { pageIDs in model.deleteWikiArticles(pageIDs: pageIDs) }"))
        XCTAssertTrue(appModel.contains("public func deleteWikiArticles(pageIDs: [String])"))
        XCTAssertTrue(appModel.contains("try vault.removePageFile(page)"))
        XCTAssertTrue(appModel.contains("try store.saveFeedback(FeedbackRecord("))
        XCTAssertTrue(appModel.contains("eventType: pages.count == 1 ? \"wiki.articleDeleted\" : \"wiki.articlesDeleted\""))
        XCTAssertTrue(wikiEngine.contains("let deletedWikiPageIDs = Set(feedback.filter"))
        XCTAssertTrue(wikiEngine.contains("page.isUserVisibleArticle && deletedWikiPageIDs.contains(page.id)"))
    }

    func testSwarmSurfaceIsFourthTabAndUsesBackendFlows() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appModel = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveAppModel.swift"))
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let swarm = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/SwarmSurface.swift"))
        let contextEngine = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/SwarmContextEngine.swift"))
        let app = try String(contentsOf: root.appendingPathComponent("Sources/HiveApp/HiveApp.swift"))

        XCTAssertTrue(appModel.contains("case swarm = \"Swarm\""))
        XCTAssertTrue(appModel.contains("public var activeSwarmThread: HiveSwarmThread?"))
        XCTAssertTrue(appModel.contains("public func startNewSwarmThread()"))
        XCTAssertTrue(appModel.contains("public func openSwarmThread(_ id: UUID)"))
        XCTAssertTrue(appModel.contains("public func deleteSwarmThread(_ id: UUID)"))
        XCTAssertTrue(appModel.contains("public func toggleSwarmPlugin(_ plugin: HiveSwarmPlugin)"))
        XCTAssertTrue(appModel.contains("public func swarmMentionSuggestions(limit: Int = 8)"))
        XCTAssertTrue(appModel.contains("swarmSurfaceThreadLimit"))
        XCTAssertTrue(appModel.contains("swarmSurfaceMessageLimit"))
        XCTAssertTrue(appModel.contains("visibleSwarmThreadsForSurface"))
        XCTAssertTrue(appModel.contains("activeSwarmMessagesForDisplay"))
        XCTAssertTrue(appModel.contains("displaySafeSwarmMessage"))
        XCTAssertTrue(appModel.contains("public var swarmDraftAttachments: [SwarmDraftAttachment]"))
        XCTAssertTrue(appModel.contains("public func addSwarmAttachmentURLs(_ urls: [URL])"))
        XCTAssertTrue(appModel.contains("public func removeSwarmAttachment(_ attachmentID: UUID)"))
        XCTAssertTrue(appModel.contains("public func sendSwarmMessage()"))
        XCTAssertTrue(appModel.contains("swarmAttachmentPipeline.commitCompleted(forDraft: draftID)"))
        XCTAssertTrue(appModel.contains("SwarmRequestRouter().decide"))
        XCTAssertTrue(appModel.contains("incorporateSwarmInformation"))
        XCTAssertTrue(appModel.contains("shouldUseOnlineAsk"))
        XCTAssertTrue(appModel.contains("foundationAvailable && !effectiveDecision.shouldUseOnlineSource"))
        XCTAssertTrue(appModel.contains("allowWebSearch: effectiveDecision.shouldUseOnlineSource"))
        XCTAssertTrue(appModel.contains("private static func swarmPendingText"))
        XCTAssertTrue(appModel.contains("swarmContextRetriever.retrieve("))
        XCTAssertTrue(appModel.contains("swarmContextCompactor.compactIfNeeded("))
        XCTAssertTrue(appModel.contains("quickSwarmWarmSessionSeconds"))
        XCTAssertTrue(appModel.contains("prepareQuickSwarmPopup"))
        XCTAssertTrue(appModel.contains("markQuickSwarmPopupDismissed"))
        XCTAssertTrue(appModel.contains("openCurrentSwarmConversationInHive"))
        XCTAssertTrue(appModel.contains("configureStartupSourcePlugins(request)"))
        XCTAssertTrue(appModel.contains("captureCurrentPage(command: command, followUpQuestion: followUpQuestion)"))
        XCTAssertTrue(appModel.contains("ingestText(text)"))
        XCTAssertTrue(appModel.contains("foundationOrchestrator.answerChat"))
        XCTAssertTrue(appModel.contains("CloudChatAnswerEngine().answer"))
        XCTAssertTrue(appModel.contains("chatAnswerEngine.answer("))

        XCTAssertTrue(macRoot.contains("case .swarm:"))
        XCTAssertTrue(macRoot.contains("SwarmSurface("))
        XCTAssertTrue(macRoot.contains("model.selectedSurface != .swarm"))

        XCTAssertTrue(swarm.contains("HiveText(\"Swarm\""))
        XCTAssertFalse(swarm.contains("HiveMetalScene {"))
        XCTAssertTrue(swarm.contains("ForEach(model.visibleSwarmThreadsForSurface)"))
        XCTAssertTrue(swarm.contains("activeSwarmMessagesForDisplay(limit: messageDisplayLimit)"))
        XCTAssertTrue(swarm.contains("SwarmPreservedHistoryRow"))
        XCTAssertFalse(swarm.contains("model.activeSwarmThread?.messages ?? []"))
        XCTAssertTrue(swarm.contains("model.startNewSwarmThread()"))
        XCTAssertTrue(swarm.contains("model.deleteSwarmThread(thread.id)"))
        XCTAssertTrue(swarm.contains("model.swarmMentionSuggestions()"))
        XCTAssertTrue(swarm.contains("model.insertSwarmMention(reference)"))
        XCTAssertTrue(swarm.contains("model.swarmDraftAttachments"))
        XCTAssertTrue(swarm.contains(".onDrop(of: [UTType.fileURL.identifier]"))
        XCTAssertTrue(swarm.contains("model.addSwarmAttachmentURLs([url])"))
        XCTAssertTrue(swarm.contains("model.removeSwarmAttachment(attachment.id)"))
        XCTAssertTrue(swarm.contains("ForEach(HiveSwarmPlugin.allCases)"))
        XCTAssertTrue(swarm.contains("model.toggleSwarmPlugin(plugin)"))
        XCTAssertTrue(swarm.contains("model.sendSwarmMessage()"))
        XCTAssertTrue(swarm.contains("model.captureCurrentPage(command: \"Capture the current page for Swarm.\")"))
        XCTAssertTrue(swarm.contains("onCommand(.reviewMemory)"))
        XCTAssertTrue(swarm.contains("model.requestHiveReindex()"))
        XCTAssertTrue(swarm.contains("onCommand(.fileAnswer)"))
        XCTAssertTrue(swarm.contains("public struct SwarmQuickChatSurface"))
        XCTAssertTrue(swarm.contains("HiveSpeechInputController"))
        XCTAssertTrue(swarm.contains("HiveSpeechOutputController"))
        XCTAssertTrue(swarm.contains("SwarmVoiceSettingsStore.selectedVoiceIdentifier()"))
        XCTAssertTrue(swarm.contains("model.prepareQuickSwarmPopup()"))
        XCTAssertTrue(swarm.contains("model.startNewSwarmThread()"))
        XCTAssertTrue(swarm.contains("model.openSwarmThread(thread.id)"))
        XCTAssertTrue(swarm.contains("model.addSwarmAttachmentURLs([url])"))
        XCTAssertTrue(swarm.contains("model.removeSwarmAttachment(attachment.id)"))
        XCTAssertTrue(swarm.contains("model.sendSwarmMessage()"))
        XCTAssertTrue(swarm.contains("onOpenHive"))

        XCTAssertTrue(contextEngine.contains("public actor SwarmAttachmentPipeline"))
        XCTAssertTrue(contextEngine.contains("public func remove(attachmentID: UUID, fromDraft draftID: UUID)"))
        XCTAssertTrue(contextEngine.contains("public func commitCompleted(forDraft draftID: UUID)"))
        XCTAssertTrue(contextEngine.contains("public struct SwarmColonyContextRetriever"))
        XCTAssertTrue(contextEngine.contains("public struct SwarmContextCompactor"))
        XCTAssertTrue(contextEngine.contains("public struct SwarmModelProfileRegistry"))
        XCTAssertTrue(contextEngine.contains("routingDecision: SwarmRequestDecision? = nil"))

        XCTAssertTrue(app.contains("SwarmQuickChatWindowController"))
        XCTAssertTrue(app.contains("SwarmQuickChatHotKeyController"))
        XCTAssertTrue(app.contains("SwarmQuickChatBootstrap"))
        XCTAssertTrue(app.contains("bothOptionKeysPressed"))
        XCTAssertTrue(app.contains("kVK_Option"))
        XCTAssertTrue(app.contains("kVK_RightOption"))
        XCTAssertTrue(app.contains("NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged"))
        XCTAssertTrue(app.contains("SwarmQuickChatSurface("))
        XCTAssertTrue(app.contains("openCurrentSwarmConversationInHive()"))
        XCTAssertTrue(app.contains("quickChatWindow.show()"))
    }

    func testOnboardingAndSettingsFollowCurrentHIGPass() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let app = try String(contentsOf: root.appendingPathComponent("Sources/HiveApp/HiveApp.swift"))
        let design = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveDesignSystem.swift"))
        let appleNative = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveAppleNative.swift"))
        let settings = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))
        let appModel = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveAppModel.swift"))
        let rawInputs = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/RawInputsSurface.swift"))
        let wiki = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/WikiSurface.swift"))
        let sourcePlugins = try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/HiveStartupSourcePlugins.swift"))

        XCTAssertTrue(macRoot.contains("Connect what Hive may read"))
        XCTAssertTrue(macRoot.contains("Hive gets more useful as you add more real sources"))
        XCTAssertTrue(macRoot.contains("HiveStartupSourcePluginSetup("))
        XCTAssertTrue(macRoot.contains("model.configureStartupSourcePlugins(sourcePluginRequest)"))
        XCTAssertTrue(macRoot.contains("Add something messy"))
        XCTAssertTrue(macRoot.contains("Fill the Field with real material you already have"))
        XCTAssertTrue(macRoot.contains("Do not rename it. Do not clean it up."))
        XCTAssertFalse(macRoot.contains("You can skip"))
        XCTAssertTrue(macRoot.contains("Ask in context"))
        XCTAssertTrue(macRoot.contains("Add to the Field. Read The Colony. Open The Hive."))
        XCTAssertTrue(macRoot.contains("onPreviewStep"))
        XCTAssertTrue(macRoot.contains("model.selectedSourceID = model.sourcePresentations.first?.id"))
        XCTAssertTrue(macRoot.contains("Show Field"))
        XCTAssertTrue(macRoot.contains("Show The Colony"))
        XCTAssertTrue(macRoot.contains("Show ask box"))
        XCTAssertTrue(macRoot.contains("Show The Hive"))
        XCTAssertTrue(macRoot.contains("Optional. Replay this anytime from Help > Hive Tutorial."))
        XCTAssertTrue(macRoot.contains(".onChange(of: step)"))
        XCTAssertTrue(macRoot.contains("hive.appOpenCount"))
        XCTAssertTrue(macRoot.contains("hive.dailyUseTips.lastShownOpen"))
        XCTAssertTrue(macRoot.contains("HiveDailyUseTipsOverlay("))
        XCTAssertTrue(macRoot.contains("Use Hive every day"))
        XCTAssertTrue(macRoot.contains("Ingest new sources"))
        XCTAssertTrue(macRoot.contains("Ask The Colony"))
        XCTAssertTrue(macRoot.contains("Run a health check"))
        XCTAssertTrue(macRoot.contains("What do you recommend?"))
        XCTAssertTrue(macRoot.contains("I just added a source to Field"))
        XCTAssertTrue(macRoot.contains("Review The Colony. Find contradictions between pages"))
        XCTAssertFalse(macRoot.contains("Three folders. One maintained memory."))
        XCTAssertTrue(macRoot.contains("@AppStorage(\"hive.sidebarVisible\") private var sidebarVisible = true"))
        XCTAssertFalse(macRoot.contains("NavigationSplitView(columnVisibility: splitVisibilityBinding)"))
        XCTAssertFalse(macRoot.contains("NavigationSplitView(columnVisibility: sidebarColumnVisibility)"))
        XCTAssertTrue(macRoot.contains("private var detailShell: some View"))
        XCTAssertTrue(macRoot.contains("HStack(spacing: 0)"))
        XCTAssertTrue(macRoot.contains("private var nativeSidebar: some View"))
        XCTAssertTrue(macRoot.contains("VStack(alignment: .leading, spacing: 4)"))
        XCTAssertTrue(macRoot.contains("HiveSidebarRow("))
        XCTAssertTrue(macRoot.contains("HiveLiquidGlassSurface(placement: .navigation)"))
        XCTAssertFalse(macRoot.contains("ToolbarItemGroup(placement: .primaryAction)"))
        XCTAssertTrue(macRoot.contains("HiveToolbarIconButton("))
        XCTAssertFalse(macRoot.contains("HiveLiquidGlassSurface(placement: .toolbar)"))
        XCTAssertFalse(macRoot.contains("HiveLiquidGlassSurface(placement: .popover)"))
        XCTAssertFalse(macRoot.contains(".navigationTitle(model.selectedSurface.displayTitle)"))
        XCTAssertFalse(macRoot.contains(".toolbarTitleDisplayMode(.inline)"))
        XCTAssertFalse(macRoot.contains("private var splitVisibilityBinding: Binding<NavigationSplitViewVisibility>"))
        XCTAssertFalse(macRoot.contains("private var sidebarColumnVisibility: Binding<NavigationSplitViewVisibility>"))
        XCTAssertFalse(macRoot.contains("HiveToolbarIconButton(.importAction, title: \"Add Sources...\""))
        XCTAssertFalse(macRoot.contains("HiveToolbarIconButton(.command, title: \"Commands\", accessibilityLabel: \"Open Command Palette\""))
        XCTAssertFalse(macRoot.contains("HiveToolbarIconButton(.chat, title: \"Ask\""))
        XCTAssertTrue(macRoot.contains("private var chatSidePanel: some View"))
        XCTAssertFalse(macRoot.contains("if shouldShowFloatingAskButton {"))
        XCTAssertFalse(macRoot.contains("&& model.selectedSurface != .graph"))
        XCTAssertFalse(macRoot.contains("floatingAskButton"))
        XCTAssertTrue(macRoot.contains("HiveWindowChromeConfigurator(colorScheme: colorScheme)"))
        XCTAssertTrue(macRoot.contains("window.styleMask.insert(.fullSizeContentView)"))
        XCTAssertTrue(macRoot.contains("window.titleVisibility = .hidden"))
        XCTAssertTrue(macRoot.contains("window.titlebarAppearsTransparent = true"))
        XCTAssertTrue(macRoot.contains("HiveToolbarIconButton(.sidebar, accessibilityLabel: \"Collapse Navigator\", active: true)"))
        XCTAssertTrue(macRoot.contains("HiveToolbarIconButton(.sidebar, accessibilityLabel: \"Show Navigator\", active: true)"))
        XCTAssertTrue(macRoot.contains("setSidebarVisible(false)"))
        XCTAssertTrue(macRoot.contains("setSidebarVisible(true)"))
        XCTAssertFalse(macRoot.contains("HiveToolbarIconButton(.settings, title: \"Settings…\""))
        XCTAssertFalse(macRoot.contains(".toolbar(removing: .sidebarToggle)"))
        XCTAssertFalse(macRoot.contains("HiveToolbarIconButton(\n                            .sidebar"))
        XCTAssertFalse(macRoot.contains("sidebarToggleAccessibilityLabel"))
        XCTAssertFalse(macRoot.contains("\"Hide Sidebar\""))
        XCTAssertFalse(macRoot.contains("\"Show Sidebar\""))
        XCTAssertFalse(macRoot.contains("private func sidebarButton"))
        XCTAssertFalse(macRoot.contains("private var topControls"))
        XCTAssertFalse(macRoot.contains("sidebarStatusText"))
        XCTAssertFalse(macRoot.contains("\"Local ·"))
        XCTAssertFalse(macRoot.contains("Hive is local"))
        XCTAssertFalse(macRoot.contains("@State private var menuBarExtraVisible: Bool"))
        XCTAssertFalse(macRoot.contains("private var menuBarExtraVisibleBinding: Binding<Bool>"))
        XCTAssertFalse(macRoot.contains("You can bring this icon back from Settings > Menu Bar or the Hive menu."))
        XCTAssertTrue(macRoot.contains(".frame(width: 176)"))
        XCTAssertFalse(macRoot.contains("MenuBarMetricStrip("))
        XCTAssertFalse(macRoot.contains("MenuBarSourceRow("))
        XCTAssertTrue(macRoot.contains("MenuBarActionRow(symbol: .importAction, title: \"Import Docs\""))
        XCTAssertTrue(macRoot.contains("MenuBarActionRow(symbol: .settings, title: \"Settings\""))
        XCTAssertTrue(macRoot.contains("MenuBarActionRow(symbol: .signOut, title: \"Quit Hive\""))
        XCTAssertFalse(macRoot.contains("MenuBarActionRow(symbol: .settings, title: \"Open Settings\""))
        XCTAssertFalse(macRoot.contains("MenuBarActionRow(symbol: .download"))
        XCTAssertFalse(macRoot.contains("MenuBarActionRow(symbol: .runMaintenance"))
        XCTAssertFalse(macRoot.contains("quickCaptureSection"))
        XCTAssertFalse(macRoot.contains("Hide Menu Bar Icon"))
        XCTAssertFalse(macRoot.contains("onHideMenuBarIcon"))
        XCTAssertTrue(macRoot.contains("HiveGrainLayer().allowsHitTesting(false).opacity(0.025)"))
        XCTAssertTrue(macRoot.contains("UserDefaults.standard.set(value, forKey: \"hive.sidebarVisible\")"))
        XCTAssertTrue(app.contains("private final class HiveAppPreferences"))
        XCTAssertTrue(app.contains("@StateObject private var preferences = HiveAppPreferences()"))
        XCTAssertTrue(app.contains(".windowStyle(.hiddenTitleBar)"))
        XCTAssertTrue(app.contains(".defaultSize(width: 1180, height: 760)"))
        XCTAssertFalse(app.contains(".frame(minWidth: 960, minHeight: 640)"))
        XCTAssertTrue(app.contains("func setMenuBarExtraVisible(_ visible: Bool)"))
        XCTAssertFalse(app.contains("@AppStorage(\"hive.sidebarVisible\")"))
        XCTAssertTrue(app.contains("@AppStorage(\"hive.menuBarExtraVisible\")"))
        XCTAssertTrue(app.contains("CommandGroup(after: .sidebar)"))
        XCTAssertTrue(app.contains("preferences.sidebarVisible ? \"Hide Navigator\" : \"Show Navigator\""))
        XCTAssertFalse(app.contains("\"Hide Sidebar\""))
        XCTAssertFalse(app.contains("\"Show Sidebar\""))
        XCTAssertFalse(app.contains("preferences.menuBarExtraVisible ? \"Hide Menu Bar Icon\" : \"Show Menu Bar Icon\""))
        XCTAssertTrue(app.contains("@NSApplicationDelegateAdaptor(HiveAppLifecycleDelegate.self)"))
        XCTAssertTrue(app.contains("func applicationShouldTerminate(_ sender: NSApplication)"))
        XCTAssertTrue(app.contains(".terminateNow"))
        XCTAssertTrue(app.contains("Button(\"Quit Hive\")"))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"q\", modifiers: [.command])"))
        XCTAssertFalse(app.contains("HiveMacWindowPresenter.hideInteractiveWindowsKeepingMenuBar()"))
        XCTAssertFalse(app.contains("Button(\"Close Hive Window\")"))
        XCTAssertFalse(app.contains("Button(\"Quit Hive Completely\")"))
        XCTAssertFalse(app.contains("terminateCancel"))
        XCTAssertTrue(app.contains("MenuBarExtra("))
        XCTAssertTrue(app.contains("HiveMenuBarIcon()"))
        XCTAssertTrue(appleNative.contains("rendering: .monochrome(.white)"))
        XCTAssertFalse(app.contains("systemImage:"))
        XCTAssertTrue(app.contains("preferences.setMenuBarExtraVisible($0)"))
        XCTAssertFalse(macRoot.contains("@AppStorage(\"hive.menuBarExtraVisible\")"))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"s\", modifiers: [.command, .option])"))
        XCTAssertTrue(app.contains("CommandGroup(replacing: .appSettings)"))
        XCTAssertTrue(app.contains("private func openSettingsPanel()"))
        XCTAssertTrue(app.contains(".keyboardShortcut(shortcutKey(for: .settings), modifiers: shortcutModifiers(for: .settings))"))
        XCTAssertTrue(app.contains("CommandMenu(\"Memory\")"))
        XCTAssertFalse(app.contains("CommandMenu(\"Hive\")"))
        XCTAssertTrue(app.contains("Button(\"Command Palette…\")"))
        XCTAssertTrue(app.contains("Button(\"Ask Hive\")"))
        XCTAssertTrue(app.contains("Button(\"Add to Field…\")"))
        XCTAssertTrue(app.contains("Button(\"Search The Hive…\")"))
        XCTAssertTrue(app.contains("Button(\"Settings…\")"))
        XCTAssertTrue(app.contains("shortcutRevision += 1"))
        XCTAssertTrue(app.contains(".keyboardShortcut(shortcutKey(for: .addSources), modifiers: shortcutModifiers(for: .addSources))"))
        XCTAssertTrue(app.contains(".keyboardShortcut(shortcutKey(for: .chat), modifiers: shortcutModifiers(for: .chat))"))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"e\", modifiers: [.command, .shift])"))
        XCTAssertFalse(app.contains(".keyboardShortcut(\"s\", modifiers: [.control, .shift])"))
        XCTAssertTrue(app.contains(".keyboardShortcut(shortcutKey(for: .settings), modifiers: shortcutModifiers(for: .settings))"))
        XCTAssertTrue(app.contains("private static func parseShortcut(_ shortcut: String)"))
        XCTAssertTrue(app.contains("model.chatVisible = true"))
        XCTAssertTrue(macRoot.contains("private func handleCommand(_ command: HiveCommand)"))
        XCTAssertTrue(macRoot.contains("if command == .addSources"))
        XCTAssertFalse(macRoot.contains(".keyboardShortcut(\"s\", modifiers: [.command, .option])"))
        XCTAssertTrue(design.contains("listsAndTablesGuidelinesURL"))
        XCTAssertTrue(design.contains("dragAndDropGuidelinesURL"))
        XCTAssertTrue(design.contains("colorGuidelinesURL"))
        XCTAssertTrue(design.contains("textViewsGuidelinesURL"))
        XCTAssertTrue(design.contains("feedbackGuidelinesURL"))
        XCTAssertTrue(design.contains("public enum HiveComponentPolicy"))
        XCTAssertTrue(design.contains("public enum HivePatternPolicy"))
        XCTAssertTrue(design.contains("settingsAvoidToolbarButtons"))
        XCTAssertTrue(design.contains("settingsTitleNamesAppWhenSinglePane"))
        XCTAssertTrue(design.contains("minimumButtonHitRegion"))
        XCTAssertTrue(design.contains("maximumToolbarGroups"))
        XCTAssertTrue(design.contains("labelSatisfiesEllipsisRule"))
        XCTAssertTrue(appleNative.contains("var shadowRadius: CGFloat"))
        XCTAssertTrue(appleNative.contains("var solidFill: Color"))
        XCTAssertTrue(macRoot.contains("private var chatSidePanel"))
        XCTAssertTrue(macRoot.contains("if model.chatVisible && model.selectedSurface != .swarm {"))
        XCTAssertFalse(macRoot.contains("private var settingsMainSurface"))
        XCTAssertFalse(macRoot.contains("private var activeMainSurface"))
        XCTAssertTrue(app.contains("Settings {"))
        XCTAssertTrue(app.contains("HiveSettingsWindowContent()"))
        XCTAssertTrue(macRoot.contains("HiveSidebarRow"))
        XCTAssertFalse(macRoot.contains("ZStack(alignment: .trailing) {\n                RawInputsSurface"))
        XCTAssertTrue(macRoot.contains("HStack(spacing: 0) {\n                RawInputsSurface"))
        XCTAssertFalse(wiki.contains(".modifier(HiveGlassShell(level: .navigation))"))
        XCTAssertTrue(settings.contains("Set defaults once. Day-to-day work stays in Field, The Colony, and The Hive."))
        XCTAssertTrue(settings.contains("Text(\"Hive Settings\")"))
        XCTAssertFalse(settings.contains("Text(\"Settings\")"))
        XCTAssertTrue(settings.contains("Form {"))
        XCTAssertTrue(settings.contains("HiveSettingsSegmentedControl"))
        XCTAssertFalse(settings.contains(".background(HiveColorToken.backgroundMid.color.opacity(0.36))"))
        XCTAssertFalse(settings.contains("SettingsBlock(title:"))
        XCTAssertFalse(settings.contains("private struct HiveToggle"))
        XCTAssertFalse(settings.contains("Button(\"Close\""))
        XCTAssertFalse(settings.contains("Text(\"Close\""))
        XCTAssertTrue(settings.contains("HiveSymbolButton(.close, title: nil, compact: true, action: onDismiss)"))
        XCTAssertTrue(settings.contains("Show Hive in the menu bar"))
        XCTAssertTrue(settings.contains("Show quick capture"))
        XCTAssertFalse(settings.contains("Show recent Field items"))
        XCTAssertTrue(settings.contains("MenuBarPreview(enabled: menuBarExtraVisible)"))
        XCTAssertFalse(settings.contains("Hive > Show Menu Bar Icon"))
        XCTAssertTrue(settings.contains("Menu bar controls stay focused on capture, Live, and opening Hive."))
        XCTAssertTrue(settings.contains("Section(\"Ask\")"))
        XCTAssertTrue(settings.contains("Use online Ask when local memory is not enough"))
        XCTAssertTrue(settings.contains("LabeledContent(\"Helper name\")"))
        XCTAssertTrue(settings.contains("LabeledContent(\"API key\")"))
        XCTAssertFalse(settings.contains("Section(\"Online Ask Details\")"))
        XCTAssertFalse(settings.contains("LabeledContent(\"Endpoint\")"))
        XCTAssertFalse(settings.contains("LabeledContent(\"Answer model\")"))
        XCTAssertFalse(settings.contains("DisclosureGroup(isExpanded: $advancedOpen)"))
        XCTAssertFalse(settings.contains("@State private var advancedOpen"))
        XCTAssertTrue(settings.contains("Section(\"Learning\")"))
        XCTAssertEqual(HiveLayoutMetrics.settingsWindowIdealWidth, 1_360)
        XCTAssertEqual(HiveLayoutMetrics.settingsWindowIdealHeight, 684)
        XCTAssertTrue(app.contains("idealWidth: HiveLayoutMetrics.settingsWindowIdealWidth"))
        XCTAssertTrue(macRoot.contains("idealWidth: HiveLayoutMetrics.settingsWindowIdealWidth"))
        XCTAssertTrue(settings.contains("Section(\"Automations\")"))
        XCTAssertTrue(settings.contains("Toggle(\"Morning Briefing\""))
        XCTAssertTrue(settings.contains("Text(\"Create Automation\")"))
        XCTAssertTrue(settings.contains("TextField(\"Frequency\""))
        XCTAssertTrue(settings.contains("TextField(\"Preferred time\""))
        XCTAssertTrue(settings.contains("TextField(\"Duration or stop rule\""))
        XCTAssertFalse(settings.contains("Design Custom Automation"))
        XCTAssertFalse(settings.contains("AutomationTemplateSummaryRow"))
        XCTAssertFalse(settings.contains("Review and consolidate Hive every day"))
        XCTAssertFalse(settings.contains("ForEach(HiveAutomationCatalog.templates.filter"))
        XCTAssertTrue(macRoot.contains("Text(\"Create Automation\")"))
        XCTAssertFalse(macRoot.contains("Design Custom Automation"))
        XCTAssertTrue(settings.contains("Section(\"Field\")"))
        XCTAssertTrue(settings.contains("Section(\"Source Plugins\")"))
        XCTAssertTrue(settings.contains("Choose the source, then add it to Field."))
        XCTAssertFalse(settings.contains("The more real sources you add, the better Hive can connect ideas"))
        XCTAssertFalse(settings.contains("cleanup is Hive's job"))
        XCTAssertFalse(settings.contains("Save Source Plugins"))
        XCTAssertTrue(settings.contains("Button(\"Add to Field\")"))
        XCTAssertTrue(settings.contains("Button(\"Choose Files...\")"))
        XCTAssertTrue(settings.contains("Button(\"Choose Browser History...\")"))
        XCTAssertTrue(settings.contains("sourcePluginRequest.canRunWithoutPicker"))
        XCTAssertTrue(settings.contains("sourcePluginStatusText"))
        XCTAssertTrue(settings.contains("onChooseSourcePluginFiles(request)"))
        XCTAssertTrue(settings.contains("onChooseBrowserHistory(request)"))
        XCTAssertTrue(settings.contains("HiveStartupSourcePluginSetup("))
        XCTAssertTrue(settings.contains("Section(\"iCloud\")"))
        XCTAssertTrue(settings.contains("Section(\"Privacy\")"))
        XCTAssertTrue(settings.contains("Section(\"Appearance\")"))
        XCTAssertFalse(settings.contains("Section(\"Command Shortcuts\")"))
        XCTAssertFalse(settings.contains("Section(\"Files and Links\")"))
        XCTAssertFalse(settings.contains("Section(\"Colony Tools\")"))
        XCTAssertFalse(settings.contains("Section(\"Hive Axes\")"))
        XCTAssertTrue(settings.contains("Section(\"Advanced\")"))
        XCTAssertTrue(settings.contains("DisclosureGroup(\"Shortcuts, tools, and axes\""))
        XCTAssertTrue(settings.contains("GraphAxisVocabulary(top: axisTop, bottom: axisBottom, right: axisRight, left: axisLeft).review"))
        XCTAssertTrue(settings.contains("Text(\"Top\")"))
        XCTAssertTrue(settings.contains("TextField(GraphAxisVocabulary.default.top, text: $axisTop)"))
        XCTAssertTrue(settings.contains("TextField(GraphAxisVocabulary.default.bottom, text: $axisBottom)"))
        XCTAssertTrue(settings.contains("Text(\"Bottom\")"))
        XCTAssertTrue(settings.contains("Text(\"Left\")"))
        XCTAssertTrue(settings.contains("TextField(GraphAxisVocabulary.default.left, text: $axisLeft)"))
        XCTAssertTrue(settings.contains("TextField(GraphAxisVocabulary.default.right, text: $axisRight)"))
        XCTAssertTrue(settings.contains("Text(\"Right\")"))
        XCTAssertTrue(settings.contains("Button(\"Confirm and Re-Index\")"))
        XCTAssertTrue(settings.contains("confirmAxesAndReindex()"))
        XCTAssertTrue(settings.contains("onConfirmAxesAndReindex(vocabulary)"))
        XCTAssertTrue(settings.contains("Reset Hive Axes"))
        XCTAssertFalse(settings.contains("Hive applies them only when the pair reads as a real polarity."))
        XCTAssertTrue(settings.contains("SettingsCommandActionRow("))
        XCTAssertFalse(settings.contains("These rows call Hive's real command router"))
        XCTAssertTrue(settings.contains("LabeledContent(\"AI status\""))
        XCTAssertTrue(settings.contains("Toggle(\"Learn from browser captures\""))
        XCTAssertTrue(settings.contains("LabeledContent(\"Raw source files\")"))
        XCTAssertTrue(settings.contains("HiveRawSourceRetention.fixedRawFileRetention.label"))
        XCTAssertFalse(settings.contains("title: \"Keep Field sources\""))
        XCTAssertTrue(settings.contains("HiveSettingsSegmentedControl(\n                        title: \"Appearance\""))
        XCTAssertTrue(settings.contains("CommandShortcutEditorRow("))
        XCTAssertTrue(settings.contains("TextField(\"Key\", text: $draftKey)"))
        XCTAssertTrue(settings.contains("ShortcutModifierToggle("))
        XCTAssertTrue(settings.contains("HiveKeyboardShortcut.parse"))
        XCTAssertTrue(settings.contains("ShortcutVisualToken.tokens(from: value)"))
        XCTAssertTrue(settings.contains("HiveShortcutModifier.appleDisplayOrder"))
        XCTAssertTrue(settings.contains("fallbackTokens(from: value)"))
        XCTAssertTrue(settings.contains("modifierSymbol(for: piece)"))
        XCTAssertTrue(settings.contains("kind: .symbol($0.symbolName, $0.title)"))
        XCTAssertFalse(settings.contains("return [ShortcutVisualToken(id: \"raw-\\(value)\", kind: .text(value))]"))
        XCTAssertTrue(settings.contains("HiveSymbol(.shortcutRecord"))
        XCTAssertTrue(settings.contains("HiveSymbol(.shortcutReset"))
        XCTAssertTrue(settings.contains("learningSettings: Binding<HiveLearningSettings>"))
        XCTAssertTrue(settings.contains("Slider(value: connectionAggressionBinding"))
        XCTAssertTrue(settings.contains("Text(\"Update The Hive\")"))
        XCTAssertTrue(settings.contains("onCommand(.reviewMemory)"))
        XCTAssertFalse(settings.contains("Saved to Hive"))
        XCTAssertFalse(settings.contains("backend relationship thresholds"))
        XCTAssertTrue(settings.contains("Toggle(\"Learn from browser captures\", isOn: learnsFromBrowserCapturesBinding)"))
        XCTAssertFalse(settings.contains("@AppStorage(HiveLearningSettingsStore.rawSourceRetentionKey)"))
        XCTAssertFalse(settings.contains("@AppStorage(HiveLearningSettingsStore.connectionAggressionKey)"))
        XCTAssertFalse(settings.contains("@State private var browserEnabled"))
        XCTAssertFalse(settings.contains("@State private var retention"))
        XCTAssertTrue(settings.contains("Button(\"Replay Tutorial\""))
        XCTAssertTrue(settings.contains("@State private var advancedSettingsVisible = false"))
        XCTAssertTrue(settings.contains("DisclosureGroup(\"Shortcuts, tools, and axes\""))
        XCTAssertFalse(settings.contains("Section(\"Advanced Storage\")"))
        XCTAssertFalse(settings.contains("Local paths, exports, and audit history live here"))
        XCTAssertFalse(settings.contains("Section(\"Stats\")"))
        XCTAssertFalse(settings.contains("Stored locally"))
        XCTAssertTrue(settings.contains("Ask Hive or add a note"))
        XCTAssertTrue(settings.contains("Remember I am working on..."))
        XCTAssertTrue(settings.contains("What do you recommend?"))
        XCTAssertTrue(appModel.contains("@Published public var chatVisible = false"))
        XCTAssertTrue(appModel.contains("shouldAddChatInputToMemory"))
        XCTAssertTrue(rawInputs.contains("HiveSymbol(\n                        .voiceNote"))
        XCTAssertTrue(rawInputs.contains("HiveVoiceNoteRecorder"))
        XCTAssertTrue(settings.contains("Ask from local memory"))
        XCTAssertTrue(settings.contains("What changed recently?"))
        XCTAssertFalse(settings.contains("Creates a Marp markdown deck"))
        XCTAssertFalse(settings.contains("frontmatter tables"))
        XCTAssertTrue(settings.contains("Build a presentation from the current article."))
        XCTAssertFalse(settings.contains("Optional Search Backend"))
        XCTAssertFalse(settings.contains("qmd query --json"))
        XCTAssertTrue(settings.contains("Search actions..."))
        XCTAssertFalse(settings.contains("CommandPreview"))
        XCTAssertFalse(settings.contains(".frame(width: 760)"))
        XCTAssertFalse(settings.contains("Search actions like add, ask, find, read, or settings"))
        XCTAssertTrue(settings.contains("TextField(\"Search actions...\""))
        XCTAssertTrue(settings.contains("ShortcutBadge(availability.shortcut)"))
        XCTAssertTrue(settings.contains("This command needs more context."))
        XCTAssertTrue(appModel.contains("case addSources = \"Add to Field…\""))
        XCTAssertTrue(appModel.contains("case findMemory = \"Find in The Hive…\""))
        XCTAssertTrue(appModel.contains("case graph = \"Open The Hive\""))
        XCTAssertTrue(appModel.contains("case rawSources = \"Open Field\""))
        XCTAssertTrue(appModel.contains("case reviewMemory = \"Review Field\""))
        XCTAssertTrue(appModel.contains("case downloadAttachments = \"Save Article Images Offline\""))
        XCTAssertTrue(appModel.contains("case createSlideDeck = \"Create Slide Deck\""))
        XCTAssertTrue(appModel.contains("createSlideDeckFromSelectedWikiPage()"))
        XCTAssertTrue(appModel.contains("WikiMarpDeckExporter().exportDeck"))
        XCTAssertTrue(appModel.contains("case settings = \"Open Settings…\""))
        XCTAssertTrue(appModel.contains("return \"Option Shift Command H\""))
        XCTAssertTrue(appModel.contains("return \"Option Command A\""))
        XCTAssertTrue(appModel.contains("return \"Option Command L\""))
        XCTAssertTrue(appModel.contains("return \"Shift Command D\""))
        XCTAssertTrue(appModel.contains("return \"Option Command P\""))
        XCTAssertTrue(appModel.contains("public static let appleDisplayOrder"))
        XCTAssertFalse(appModel.contains("return \"Command Shift S\""))
        XCTAssertFalse(appModel.contains("Control Shift D"))
        XCTAssertTrue(appModel.contains("public func commandAvailability(for command: HiveCommand)"))
        XCTAssertTrue(appModel.contains("public var defaultShortcut: String"))
        XCTAssertTrue(appModel.contains("public enum HiveCommandShortcutStore"))
        XCTAssertTrue(appModel.contains("public nonisolated static let uploadSettleDelaySeconds: TimeInterval = 5 * 60"))
        XCTAssertTrue(appModel.contains("try ingestionEngine.ingest(urls: urls, processImmediately: false)"))
        XCTAssertTrue(appModel.contains("scheduleSettledUploadProcessing()"))
        XCTAssertTrue(appModel.contains("public func processSettledUploadBatch()"))
        XCTAssertTrue(appModel.contains("public func configureStartupSourcePlugins("))
        XCTAssertTrue(appModel.contains("@Published public var sourcePluginStatusText"))
        XCTAssertTrue(appModel.contains("HiveStartupSourcePluginBackend().execute"))
        XCTAssertTrue(appModel.contains("uploadedURLs: uploadedURLs"))
        XCTAssertTrue(appModel.contains("browserHistoryURLs: browserHistoryURLs"))
        XCTAssertTrue(appModel.contains("execution.userMessage"))
        XCTAssertTrue(appModel.contains("@Published public var graphReindexRequestID: UUID?"))
        XCTAssertTrue(appModel.contains("public func requestHiveReindex()"))
        XCTAssertTrue(macRoot.contains("externalReindexRequestID: model.graphReindexRequestID"))
        XCTAssertTrue(sourcePlugins.contains("case googleDrive"))
        XCTAssertTrue(sourcePlugins.contains("case browserHistory"))
        XCTAssertTrue(sourcePlugins.contains("case webPages"))
        XCTAssertTrue(sourcePlugins.contains("case uploads"))
        XCTAssertTrue(sourcePlugins.contains("case localDisk"))
        XCTAssertTrue(sourcePlugins.contains("case downloadsFolder"))
        XCTAssertTrue(sourcePlugins.contains("Google Drive"))
        XCTAssertTrue(sourcePlugins.contains("pasteLocationPlaceholder"))
        XCTAssertTrue(sourcePlugins.contains("promptPlaceholder"))
        XCTAssertTrue(sourcePlugins.contains("drive.google.com"))
        XCTAssertTrue(sourcePlugins.contains("public struct HiveStartupSourcePluginBackend"))
        XCTAssertTrue(sourcePlugins.contains("startup-web-page"))
        XCTAssertTrue(sourcePlugins.contains("BrowserHistoryImporter"))
        XCTAssertTrue(sourcePlugins.contains("browserHistoryURLs: [URL] = []"))
        XCTAssertTrue(sourcePlugins.contains("browserProfiles(fromExplicitURLs: browserHistoryURLs"))
        XCTAssertTrue(sourcePlugins.contains("processImmediately: Bool = true"))
        XCTAssertTrue(sourcePlugins.contains("learningSettings: HiveLearningSettings = HiveLearningSettingsStore.load()"))
        XCTAssertTrue(sourcePlugins.contains("learningSettings.allows(sourcePlugin:"))
        XCTAssertTrue(sourcePlugins.contains("Privacy settings blocked"))
        XCTAssertTrue(try String(contentsOf: root.appendingPathComponent("Sources/HiveCore/Ingestion.swift")).contains("learningSettingsProvider().rawSourceRetention"))
        XCTAssertTrue(appleNative.contains("case shortcutOption = \"option\""))
        XCTAssertTrue(appleNative.contains("case shortcutShift = \"shift\""))
        XCTAssertTrue(appleNative.contains("case shortcutControl = \"control\""))
        XCTAssertTrue(appleNative.contains("case shortcutReset = \"arrow.counterclockwise\""))
        XCTAssertFalse(appModel.contains("public var glyph: String"))
        XCTAssertFalse(appModel.contains("case settings = \"Behavior\""))
        XCTAssertFalse(appModel.contains("Download Wiki Attachments"))
        XCTAssertFalse(appModel.contains("Enter the spatial memory field"))
        XCTAssertFalse(appModel.contains("formed article layer"))
        XCTAssertTrue(appModel.contains("@Published public private(set) var sourcePresentations"))
        XCTAssertTrue(appModel.contains("@Published public private(set) var stagedItems"))
        XCTAssertTrue(appModel.contains("@Published public private(set) var processedItems"))
        XCTAssertTrue(appModel.contains("@Published public private(set) var stagedSourcePresentations"))
        XCTAssertTrue(appModel.contains("@Published public private(set) var processedSourcePresentations"))
        XCTAssertTrue(appModel.contains("@Published public private(set) var rawInputClusters"))
        XCTAssertTrue(appModel.contains("@Published public private(set) var currentOrganismState"))
        XCTAssertTrue(appModel.contains("private var cachedVisibility"))
        XCTAssertTrue(appModel.contains("currentOrganismState: HiveStatusTranslator.globalState(sources: sources)"))
        XCTAssertTrue(appModel.contains("let sourcePresentations = activeSources"))
        XCTAssertTrue(appModel.contains("sourcePresentations = snapshot.sourcePresentations"))
        XCTAssertTrue(appModel.contains("stagedItems: sources.filter { $0.status == .queued }"))
        XCTAssertTrue(appModel.contains("processedItems: sources.filter { $0.status == .extracted }"))
        XCTAssertTrue(appModel.contains("stagedSourcePresentations: allSourcePresentations.filter(\\.isStaged)"))
        XCTAssertTrue(appModel.contains("processedSourcePresentations: allSourcePresentations.filter { !$0.isStaged && !$0.isProcessing }"))
        XCTAssertTrue(appModel.contains("rawInputClusters: rawInputClusters"))
        XCTAssertTrue(appModel.contains("schedulePendingStagedSourceProcessingIfNeeded()"))
        XCTAssertTrue(rawInputs.contains("public var clusters: [RawInputCellCluster]"))
        XCTAssertFalse(rawInputs.contains("@State private var cachedClusters"))
        XCTAssertFalse(rawInputs.contains("Task.detached(priority: .utility)"))
        XCTAssertFalse(rawInputs.contains("RawInputCellCluster.clusters(from: sources)"))
        XCTAssertFalse(macRoot.contains("\"Close Settings\""))
        XCTAssertFalse(macRoot.contains("\"Close Chat\""))
        XCTAssertFalse(settings.contains("pathsDescription"))
        XCTAssertFalse(settings.contains("statsDescription"))
    }

    func testMotionSystemUsesWarmSharedCurves() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let design = try String(contentsOf: root.appendingPathComponent("Sources/HiveDesignSystem/HiveDesignSystem.swift"))
        let overlays = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))
        let rawInputs = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/RawInputsSurface.swift"))
        let graph = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveGraphSurface.swift"))
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))

        XCTAssertTrue(design.contains("public static let welcome"))
        XCTAssertTrue(design.contains("public static let reveal"))
        XCTAssertTrue(design.contains("public static let hoverLift = Animation.spring(response: 0.34, dampingFraction: 1.18"))
        XCTAssertTrue(design.contains("public static let sidebarSelection = Animation.spring(response: 0.42, dampingFraction: 1.14"))
        XCTAssertTrue(design.contains("public static let sidebarPageScroll = Animation.spring(response: 0.56, dampingFraction: 1.08"))
        XCTAssertTrue(design.contains("public static let breathing"))
        XCTAssertTrue(design.contains("public static let drift"))
        XCTAssertTrue(design.contains("public static let scrub"))
        XCTAssertTrue(overlays.contains("withAnimation(HiveMotion.breathing)"))
        XCTAssertTrue(overlays.contains("withAnimation(HiveMotion.welcome)"))
        XCTAssertTrue(rawInputs.contains(".animation(HiveMotion.reveal, value: token)"))
        XCTAssertTrue(rawInputs.contains(".animation(HiveMotion.control, value: active)"))
        XCTAssertTrue(graph.contains("withAnimation(HiveMotion.drift)"))
        XCTAssertFalse(graph.contains("withAnimation(HiveMotion.scrub)"))
        XCTAssertTrue(graph.contains("newlyFormed ? HiveMotion.welcome : HiveMotion.reveal"))
        XCTAssertTrue(macRoot.contains("@Namespace private var sidebarSelectionNamespace"))
        XCTAssertTrue(macRoot.contains("surfaceScrollDirection.transition"))
        XCTAssertTrue(macRoot.contains(".animation(HiveMotion.sidebarPageScroll, value: model.selectedSurface)"))
        XCTAssertTrue(macRoot.contains(".matchedGeometryEffect("))
        XCTAssertTrue(macRoot.contains("withAnimation(previousSurface == surface ? HiveMotion.focus : HiveMotion.sidebarPageScroll)"))
        XCTAssertTrue(macRoot.contains(".animation(HiveMotion.reveal, value: model.selectedSourceID)"))
        XCTAssertFalse(overlays.contains(".easeInOut(duration: 0.9)"))
        XCTAssertFalse(overlays.contains(".easeInOut(duration: 0.32)"))
        XCTAssertFalse(rawInputs.contains(".easeOut(duration: 0.42)"))
        XCTAssertFalse(rawInputs.contains(".easeInOut(duration: 0.18)"))
        XCTAssertFalse(graph.contains(".easeOut(duration:"))
        XCTAssertFalse(graph.contains(".linear(duration:"))
        XCTAssertFalse(macRoot.contains(".spring(response: 0.36"))
    }

    func testAppleComponentsDocumentPolicyIsEncoded() {
        XCTAssertEqual(HiveComponentPolicy.sourceDocument, "APPLE COMPONENTS DOC")
        XCTAssertTrue(HiveComponentPolicy.followsCoreComponentRules)
        XCTAssertEqual(HiveHIGPolicy.minimumMacControlTarget, 44)
        XCTAssertGreaterThanOrEqual(HiveComponentPolicy.minimumButtonHitRegion, 44)
        XCTAssertLessThanOrEqual(HiveComponentPolicy.maximumProminentButtonsPerView, 2)
        XCTAssertLessThanOrEqual(HiveComponentPolicy.maximumToolbarGroups, 3)
        XCTAssertLessThanOrEqual(HiveComponentPolicy.maximumContextMenuGroups, 3)
        XCTAssertLessThanOrEqual(HiveComponentPolicy.maximumWideSegments, 7)
        XCTAssertLessThanOrEqual(HiveComponentPolicy.maximumPhoneSegments, 5)
        XCTAssertEqual(HiveComponentPolicy.menuBarExtraHeight, 24)
        XCTAssertTrue(HiveComponentPolicy.labelSatisfiesEllipsisRule("Add to Field…", opensFurtherInput: true))
        XCTAssertFalse(HiveComponentPolicy.labelSatisfiesEllipsisRule("Add to Field", opensFurtherInput: true))
        XCTAssertTrue(HiveComponentPolicy.labelSatisfiesEllipsisRule("Search…", opensFurtherInput: true))
        XCTAssertTrue(HiveComponentPolicy.labelSatisfiesEllipsisRule("Ask Hive", opensFurtherInput: false))
        XCTAssertTrue(HiveComponentPolicy.searchPlaceholderIsSpecific("Actions like add, ask, find, read, or settings"))
        XCTAssertFalse(HiveComponentPolicy.searchPlaceholderIsSpecific("Search"))
        XCTAssertFalse(HiveComponentPolicy.searchPlaceholderIsSpecific("Search actions"))
        XCTAssertTrue(HiveComponentPolicy.buttonLabelStartsWithVerb("Add to Field…"))
        XCTAssertTrue(HiveComponentPolicy.buttonLabelStartsWithVerb("Open Settings…"))
    }

    func testMacOSDesignGuidanceIsEncodedAndApplied() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let app = try String(contentsOf: root.appendingPathComponent("Sources/HiveApp/HiveApp.swift"))
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let settings = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))

        XCTAssertEqual(HiveMacOSDesignPolicy.sourceDocument, "APPLE DESIGN DOC - Designing for macOS")
        XCTAssertTrue(HiveMacOSDesignPolicy.followsCoreMacOSRules)
        XCTAssertTrue(app.contains("WindowGroup {"))
        XCTAssertTrue(app.contains(".windowStyle(.hiddenTitleBar)"))
        XCTAssertTrue(app.contains(".defaultSize(width: 1180, height: 760)"))
        XCTAssertTrue(app.contains(".windowResizability(.automatic)"))
        XCTAssertFalse(app.contains(".windowResizability(.contentSize)"))
        XCTAssertFalse(app.contains(".windowResizability(.contentMinSize)"))
        XCTAssertTrue(app.contains("CommandMenu(\"Memory\")"))
        XCTAssertTrue(app.contains("CommandGroup(replacing: .appSettings)"))
        XCTAssertTrue(app.contains("CommandGroup(replacing: .appTermination)"))
        XCTAssertTrue(app.contains("Button(\"Quit Hive\")"))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"q\", modifiers: [.command])"))
        XCTAssertTrue(app.contains(".terminateNow"))
        XCTAssertFalse(app.contains("terminateCancel"))
        XCTAssertTrue(app.contains("MenuBarExtra("))
        XCTAssertTrue(app.contains(".keyboardShortcut(shortcutKey(for: .chat), modifiers: shortcutModifiers(for: .chat))"))
        XCTAssertTrue(app.contains(".keyboardShortcut(shortcutKey(for: .settings), modifiers: shortcutModifiers(for: .settings))"))
        XCTAssertTrue(app.contains("Settings {"))
        XCTAssertFalse(macRoot.contains("NavigationSplitView(columnVisibility: sidebarColumnVisibility)"))
        XCTAssertTrue(macRoot.contains("private var detailShell: some View"))
        XCTAssertFalse(macRoot.contains(".navigationSplitViewStyle(.balanced)"))
        XCTAssertTrue(macRoot.contains("@AppStorage(\"hive.sidebarVisible\")"))
        XCTAssertTrue(settings.contains("HiveSettingsSegmentedControl(\n                        title: \"Appearance\""))
        XCTAssertTrue(settings.contains("CommandShortcutEditorRow("))
        XCTAssertTrue(settings.contains("Picker(\"Voice\", selection: $selectedSwarmVoiceIdentifier)"))
        XCTAssertTrue(settings.contains("Toggle(\"Show Hive in the menu bar\""))
    }

    func testApplePatternsDocumentPolicyIsEncodedAndApplied() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let macRoot = try String(contentsOf: root.appendingPathComponent("Sources/HiveMacApp/HiveMacRootView.swift"))
        let app = try String(contentsOf: root.appendingPathComponent("Sources/HiveApp/HiveApp.swift"))
        let rawInputs = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/RawInputsSurface.swift"))
        let settings = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveOverlaySurfaces.swift"))
        let appModel = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/HiveAppModel.swift"))
        let wiki = try String(contentsOf: root.appendingPathComponent("Sources/HiveUI/WikiSurface.swift"))

        XCTAssertEqual(HivePatternPolicy.sourceDocument, "APPLE PATTERNS DOC")
        XCTAssertTrue(HivePatternPolicy.followsCorePatternRules)
        XCTAssertTrue(HivePatternPolicy.settingsTitleNamesAppWhenSinglePane)
        XCTAssertTrue(HivePatternPolicy.disabledCommandReasonsCanWrap)
        XCTAssertTrue(HivePatternPolicy.primaryContentLoadsWithoutAuxiliaryPanels)
        XCTAssertTrue(HivePatternPolicy.auxiliaryPanelsOpenAfterUserIntent)
        XCTAssertTrue(HivePatternPolicy.settingsPlacementIsCompliant(
            hasToolbarSettingsButton: macRoot.contains("HiveToolbarIconButton(.settings, title: \"Settings…\""),
            hasAppSettingsCommand: app.contains("CommandGroup(replacing: .appSettings)"),
            usesCommandComma: app.contains(".keyboardShortcut(shortcutKey(for: .settings), modifiers: shortcutModifiers(for: .settings))")
        ))
        XCTAssertTrue(HivePatternPolicy.tooltipIsCompliant("Show Field"))
        XCTAssertTrue(HivePatternPolicy.tooltipIsCompliant("Open Settings"))
        XCTAssertFalse(HivePatternPolicy.tooltipIsCompliant("Settings"))
        XCTAssertFalse(HivePatternPolicy.tooltipIsCompliant(String(repeating: "Explain ", count: 14)))

        XCTAssertTrue(app.contains("CommandGroup(replacing: .appSettings)"))
        XCTAssertTrue(app.contains(".keyboardShortcut(shortcutKey(for: .settings), modifiers: shortcutModifiers(for: .settings))"))
        XCTAssertFalse(macRoot.contains("HiveToolbarIconButton(.settings, title: \"Settings…\""))
        XCTAssertTrue(macRoot.contains(".help(\"Show \\(surface.displayTitle)\""))
        XCTAssertTrue(rawInputs.contains(".onDrop(of: [.fileURL, .text]"))
        XCTAssertTrue(rawInputs.contains("TextEditor(text: $feedDraft)"))
        XCTAssertTrue(rawInputs.contains("active: voiceRecorder.isRecording || voiceRecorder.isTranscribing"))
        XCTAssertTrue(rawInputs.contains("SourceAttachmentPreviewArtwork"))
        XCTAssertTrue(rawInputs.contains("preview.displayName"))
        XCTAssertTrue(appModel.contains("store.fetchRawBlobs()"))
        XCTAssertTrue(settings.contains("HiveSettingsSegmentedControl"))
        XCTAssertFalse(settings.contains("Section(\"Command Shortcuts\")"))
        XCTAssertTrue(settings.contains("DisclosureGroup(\"Shortcuts, tools, and axes\""))
        XCTAssertTrue(settings.contains("This command needs more context."))
        XCTAssertFalse(settings.contains(".lineLimit(2)"))
        XCTAssertTrue(settings.contains("Button(\"Replay Tutorial\""))
        XCTAssertTrue(wiki.contains("Consolidate articles"))
        XCTAssertTrue(appModel.contains("@Published public var chatVisible = false"))
        XCTAssertFalse(settings.contains("AGENTS.md"))
        XCTAssertFalse(macRoot.contains("\"Settings\" : \"Settings\""))
    }

    func testStaticUILanguageGate() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let targets = [
            "Sources/HiveApp",
            "Sources/HiveMacApp",
            "Sources/HiveUI",
            "Sources/HiveDesignSystem",
            "Sources/HiveMetalRenderer",
            "Sources/HiveMobileApp",
            "Sources/HiveWatchApp",
            "Sources/HiveWidgets"
        ]
        let bannedSubstrings = [
            "NSVisualEffectView",
            "UIVisualEffectView",
            "Color.blue",
            "Color.purple",
            "Color.teal",
            ".blue",
            ".purple",
            ".teal",
            "Qwen",
            "Llama",
            "AGENTS.md",
            "queue depth",
            "pipeline stage"
        ]
        let visibleExtensionPattern = try NSRegularExpression(pattern: #""[^"]*\.(json|pdf|db|sqlite)[^"]*""#, options: [.caseInsensitive])
        let percentPattern = try NSRegularExpression(pattern: #"[0-9]+%\s*(confidence|sure)"#, options: [.caseInsensitive])

        for target in targets {
            let url = root.appendingPathComponent(target, isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { continue }
            for case let fileURL as URL in enumerator where ["swift", "metal"].contains(fileURL.pathExtension) {
                let body = try String(contentsOf: fileURL)
                for banned in bannedSubstrings {
                    XCTAssertFalse(body.contains(banned), "\(fileURL.path) contains \(banned)")
                }
                let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
                let isAppleNativeWrapper = relativePath == "Sources/HiveDesignSystem/HiveAppleNative.swift"
                if !isAppleNativeWrapper {
                    XCTAssertFalse(body.contains("Image(systemName:"), "\(fileURL.path) uses raw SF Symbols outside HiveSymbol")
                    XCTAssertFalse(body.contains("systemImage:"), "\(fileURL.path) uses raw SF Symbols outside HiveSymbol")
                    XCTAssertFalse(body.contains(".regularMaterial"), "\(fileURL.path) uses translucent material")
                    XCTAssertFalse(body.contains(".ultraThinMaterial"), "\(fileURL.path) uses translucent material")
                    XCTAssertFalse(body.contains(".glassEffect"), "\(fileURL.path) uses translucent glass")
                }
                let isAppChrome = relativePath.hasPrefix("Sources/HiveApp")
                    || relativePath.hasPrefix("Sources/HiveMacApp")
                    || relativePath.hasPrefix("Sources/HiveUI")
                if isAppChrome, relativePath != "Sources/HiveUI/HiveGraphSurface.swift" {
                    XCTAssertFalse(body.contains("HiveHexIcon"), "\(fileURL.path) uses hex iconography outside the Hive graph")
                    XCTAssertFalse(body.contains("HexagonShape("), "\(fileURL.path) uses hex geometry outside the Hive graph")
                    XCTAssertFalse(body.contains("Circle()"), "\(fileURL.path) uses a custom status dot instead of an SF Symbol")
                }
                if relativePath == "Sources/HiveUI/WikiSurface.swift" {
                    XCTAssertFalse(body.contains("HiveSymbolName?"), "HiveActionButton must require an approved SF Symbol")
                    XCTAssertFalse(body.contains("symbol: HiveSymbolName? = nil"), "HiveActionButton cannot be label-only")
                }
                if relativePath == "Sources/HiveUI/HiveGraphSurface.swift" {
                    XCTAssertFalse(body.contains("NeuralPathView"), "Hive graph should use straight edges, not decorative path renderers")
                    XCTAssertTrue(body.contains("addLine"), "Hive graph edge renderer should use straight line segments")
                }
                let range = NSRange(body.startIndex..<body.endIndex, in: body)
                XCTAssertNil(visibleExtensionPattern.firstMatch(in: body, range: range), "\(fileURL.path) exposes a technical file extension")
                XCTAssertNil(percentPattern.firstMatch(in: body, range: range), "\(fileURL.path) exposes a numeric certainty phrase")
            }
        }
    }

    func testHiveMacAppContainsOnlyCanonicalSources() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let macAppDirectory = root.appendingPathComponent("Sources/HiveMacApp", isDirectory: true)
        let swiftFiles = try FileManager.default.contentsOfDirectory(at: macAppDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .map(\.lastPathComponent)
            .sorted()
        XCTAssertEqual(
            swiftFiles,
            [
                "HiveAppKitGraphSurface.swift",
                "HiveGraphCanvasView.swift",
                "HiveMacRootView.swift",
                "HiveMacWindowPresenter.swift"
            ],
            "HiveMacApp must not contain local-only files such as HiveAppModel.swift or HivePrompt10AppKit.swift"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources/HiveUI/HiveAppModel.swift").path),
            "HiveAppModel must live in HiveUI"
        )
    }

    func testDeepAuditRunsAppleHIGGateAndSafePackagingPath() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let deepAudit = try String(contentsOf: root.appendingPathComponent("scripts/deep_audit.sh"))
        let acceptance = try String(contentsOf: root.appendingPathComponent("scripts/acceptance.sh"))
        let staticAudit = try String(contentsOf: root.appendingPathComponent("scripts/apple_hig_static_audit.py"))

        XCTAssertTrue(deepAudit.contains("swift test"))
        XCTAssertTrue(deepAudit.contains("swift test --filter \"$suite_name\""))
        XCTAssertTrue(deepAudit.contains("run_swift_suite \"HiveCoreTests\""))
        XCTAssertTrue(deepAudit.contains("run_swift_suite \"HiveRebuildTests\""))
        XCTAssertTrue(deepAudit.contains("HIVE_DISABLE_LIVE_PERSONAL_CONTEXT=1"))
        XCTAssertTrue(deepAudit.contains("CoreData|AddressBook|NSXPC|Unable to connect to server"))
        XCTAssertTrue(deepAudit.contains("python3 scripts/apple_hig_static_audit.py"))
        XCTAssertTrue(deepAudit.contains("HIVE_BUNDLE_IDENTIFIER"))
        XCTAssertTrue(deepAudit.contains("HIVE_DEVELOPMENT_TEAM"))
        XCTAssertTrue(deepAudit.contains("HIVE_CODESIGN_IDENTITY"))
        XCTAssertTrue(deepAudit.contains("HIVE_ALLOW_UNSIGNED_LOCKED_BUILD=1 scripts/build_app.sh"))
        XCTAssertTrue(acceptance.contains("swift test --filter \"$suite_name\""))
        XCTAssertTrue(acceptance.contains("run_swift_suite \"HiveCoreTests\""))
        XCTAssertTrue(acceptance.contains("run_swift_suite \"HiveRebuildTests\""))
        XCTAssertTrue(acceptance.contains("HIVE_ALLOW_UNSIGNED_LOCKED_BUILD=1 scripts/build_app.sh release"))
        XCTAssertTrue(acceptance.contains("scripts/apple_signin_preflight.sh"))
        XCTAssertTrue(staticAudit.contains("APPLE DESIGN DOC.pdf"))
        XCTAssertTrue(staticAudit.contains("APPLE COMPONENTS DOC.pdf"))
        XCTAssertTrue(staticAudit.contains("APPLE EFFICIENCY DOC.pdf"))
        XCTAssertTrue(staticAudit.contains("APPLE INPUT DOC.pdf"))
        XCTAssertTrue(staticAudit.contains("APPLE PATTERNS DOC.pdf"))
        XCTAssertTrue(staticAudit.contains("APPLE_DOC_REQUIRED_TERMS"))
        XCTAssertTrue(staticAudit.contains("Designing for macOS"))
        XCTAssertTrue(staticAudit.contains("Designing for iPadOS"))
        XCTAssertTrue(staticAudit.contains("App Shortcuts"))
        XCTAssertTrue(staticAudit.contains("Apple Pencil"))
        XCTAssertTrue(staticAudit.contains("File management"))
        XCTAssertTrue(staticAudit.contains("SystemLanguageModel.default"))
        XCTAssertTrue(staticAudit.contains("@Generable"))
        XCTAssertTrue(staticAudit.contains("getCredentialState"))
        XCTAssertTrue(staticAudit.contains("ASWebAuthenticationSession"))
        XCTAssertTrue(staticAudit.contains("SFSpeechRecognizer"))
        XCTAssertTrue(staticAudit.contains("Color\\.(white|gray|black)"))
        XCTAssertTrue(staticAudit.contains("Color\\.(red|orange|yellow|green|blue|purple|teal|pink|indigo|mint|cyan|brown)"))
        XCTAssertTrue(staticAudit.contains("Image\\s*\\(\\s*systemName:|systemImage:"))
        XCTAssertTrue(staticAudit.contains("capture_kind"))
        XCTAssertTrue(staticAudit.contains("Apple Intelligence"))
    }
}

private func contrastRatio(_ first: String, _ second: String) -> Double {
    let firstLuminance = relativeLuminance(first)
    let secondLuminance = relativeLuminance(second)
    let lighter = max(firstLuminance, secondLuminance)
    let darker = min(firstLuminance, secondLuminance)
    return (lighter + 0.05) / (darker + 0.05)
}

private func relativeLuminance(_ hex: String) -> Double {
    let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    let value = UInt64(cleaned, radix: 16) ?? 0
    let channels = [
        Double((value >> 16) & 0xff) / 255.0,
        Double((value >> 8) & 0xff) / 255.0,
        Double(value & 0xff) / 255.0
    ].map { channel in
        channel <= 0.03928
            ? channel / 12.92
            : pow((channel + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
}
