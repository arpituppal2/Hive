import Foundation
import HiveCore
import SQLite3
import SwiftData
import XCTest

final class HiveCoreTests: XCTestCase {
    func testSwarmPartnerCommandRouterRecognizesActionablePartnerRequests() throws {
        let router = SwarmPartnerCommandRouter()

        XCTAssertEqual(router.route("reorganize everything to do with UCLA math"), .reorganizeTopic("UCLA math"))
        XCTAssertEqual(router.route("have Hive send me a briefing every morning"), .defineAutomation("have Hive send me a briefing every morning"))
        XCTAssertEqual(router.route("teach Hive to review client call transcripts"), .defineSkill("teach Hive to review client call transcripts"))
    }

    func testSwarmRequestRouterChoosesOnlineMemoryContextAndDirectAnswerPaths() throws {
        let router = SwarmRequestRouter()

        let online = router.decide(SwarmRequestRoutingInput(
            prompt: "Look online for the latest Foundation Models docs",
            webPluginEnabled: true
        ))
        XCTAssertEqual(online.intent, .lookOnline)
        XCTAssertTrue(online.shouldUseOnlineSource)
        XCTAssertTrue(online.shouldAskForApprovedURL)

        let approvedLink = router.decide(SwarmRequestRoutingInput(
            prompt: "Summarize https://developer.apple.com/documentation/foundationmodels",
            webPluginEnabled: true
        ))
        XCTAssertEqual(approvedLink.intent, .lookOnline)
        XCTAssertFalse(approvedLink.shouldAskForApprovedURL)

        let memory = router.decide(SwarmRequestRoutingInput(
            prompt: "Remember I am taking a distributed systems course",
            hasAttachments: false
        ))
        XCTAssertEqual(memory.intent, .incorporateInformation)
        XCTAssertTrue(memory.shouldWriteToMemory)

        let attached = router.decide(SwarmRequestRoutingInput(
            prompt: "Use the attached context.",
            hasAttachments: true
        ))
        XCTAssertEqual(attached.intent, .incorporateInformation)

        let contextual = router.decide(SwarmRequestRoutingInput(
            prompt: "What does my resume say about React?",
            hasExplicitReferences: true,
            colonyChunkCount: 2
        ))
        XCTAssertEqual(contextual.intent, .answerFromContext)
        XCTAssertTrue(contextual.shouldUseColonyContext)

        let direct = router.decide(SwarmRequestRoutingInput(prompt: "What is binary search?"))
        XCTAssertEqual(direct.intent, .answerDirectly)
        XCTAssertFalse(direct.shouldUseOnlineSource)
    }

    func testSwarmKnowledgeOrganizerCreatesHubWithoutDeletingSourcePages() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = makeSource(id: "course-source", title: "Course Planning.md", now: now)
        let matchingPage = WikiPageRecord(
            id: "course-page",
            title: "Course Notes",
            markdown: "# Course Notes\n\nUCLA math course planning and proof-writing workflow.",
            sourceRefs: [source.id],
            claimRefs: ["course-claim"],
            updatedAt: now,
            kind: .topic,
            summary: "Course planning details."
        )
        let unrelatedPage = WikiPageRecord(
            id: "garden-page",
            title: "Garden Notes",
            markdown: "# Garden Notes\n\nIrrigation schedule.",
            sourceRefs: [],
            claimRefs: [],
            updatedAt: now,
            kind: .topic,
            summary: "Garden details."
        )
        let claim = ClaimRecord(
            id: "course-claim",
            statement: "UCLA math course planning depends on weekly proof-writing practice.",
            subjectEntityID: "ucla-math",
            sourceRefs: [source.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture"
        )

        let result = SwarmKnowledgeOrganizer().reorganize(
            topic: "UCLA math",
            pages: [matchingPage, unrelatedPage],
            claims: [claim],
            now: now
        )

        XCTAssertEqual(result.page.kind, WikiPageKind.synthesis)
        XCTAssertTrue(result.page.markdown.contains("[[Course Notes]]"))
        XCTAssertTrue(result.page.markdown.contains("weekly proof-writing practice"))
        XCTAssertFalse(result.page.markdown.contains("[[Garden Notes]]"))
        XCTAssertEqual(result.matchedPageTitles, ["Course Notes"])
        XCTAssertEqual(result.matchedClaimCount, 1)
        XCTAssertEqual(result.auditEvent.eventType, "swarm.reorganizedTopic")
    }

    func testAutomationCatalogIncludesDailyBriefingAndKnowledgeWorkflows() throws {
        let kinds = Set(HiveAutomationCatalog.templates.map(\.id))

        XCTAssertTrue(kinds.isSuperset(of: [
            .morningBriefing,
            .callTranscript,
            .personalKnowledgeBase,
            .researchWiki,
            .bookCompanion,
            .businessWiki,
            .competitiveAnalysis,
            .clientKnowledgeVault,
            .courseNotes,
            .custom
        ]))
        XCTAssertTrue(HiveAutomationSettings().morningBriefingEnabled)
        XCTAssertEqual(HiveAutomationCatalog.defaultEnabledKinds, [.morningBriefing])
        XCTAssertEqual(Set(HiveAutomationCatalog.templates.filter(\.defaultEnabled).map(\.id)), [.morningBriefing])
        XCTAssertEqual(HiveAutomationSettings().enabledKinds, [.morningBriefing])
        XCTAssertEqual(HiveAutomationCatalog.template(for: .callTranscript).scheduleRole, .sourceDriven)
        XCTAssertFalse(HiveAutomationCatalog.template(for: .callTranscript).defaultEnabled)
        XCTAssertTrue(HiveAutomationCatalog.template(for: .custom).requiresInput)
    }

    func testAutomationSettingsNormalizesOldCatalogDefaultsToMorningOnly() throws {
        let suiteName = "HiveAutomationSettingsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set([
            HiveAutomationKind.morningBriefing.rawValue,
            HiveAutomationKind.callTranscript.rawValue,
            HiveAutomationKind.researchWiki.rawValue,
            HiveAutomationKind.businessWiki.rawValue
        ], forKey: HiveAutomationSettingsStore.enabledKindsKey)

        let loaded = HiveAutomationSettingsStore.load(defaults: defaults)

        XCTAssertEqual(loaded.enabledKinds, [.morningBriefing])
    }

    func testAutomationSettingsPreservesExplicitlyPausedMorningBriefing() throws {
        let suiteName = "HiveAutomationPauseTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set([], forKey: HiveAutomationSettingsStore.enabledKindsKey)

        let loaded = HiveAutomationSettingsStore.load(defaults: defaults)

        XCTAssertFalse(loaded.morningBriefingEnabled)
        XCTAssertTrue(loaded.enabledKinds.isEmpty)
    }

    func testMorningBriefingCreatesSwarmOnlyPageWithActionsAndNewSources() throws {
        let harness = try makeHarness()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = makeSource(id: "briefing-source", title: "New Downloaded Notes.txt", now: now.addingTimeInterval(-3_600))
        try harness.store.saveSource(source)
        let claim = ClaimRecord(
            id: "due-today",
            statement: "Send the client follow-up due today.",
            claimType: "action-item",
            sourceRefs: [source.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture",
            createdAt: now.addingTimeInterval(-3_600),
            temporalState: TemporalMemoryState(kind: .deadline, observedAt: now, eventDate: now)
        )
        try harness.store.saveClaim(claim)
        try harness.store.appendAudit(AuditEventRecord(
            eventType: "source.ingested",
            targetType: "source",
            targetID: source.id,
            sourceRefs: [source.id],
            timestamp: now.addingTimeInterval(-1_800),
            detail: "Imported New Downloaded Notes.txt"
        ))

        let page = try HiveAutomationOrchestrator(store: harness.store, paths: harness.paths).runMorningBriefing(now: now)

        XCTAssertEqual(page.kind, .answer)
        XCTAssertEqual(page.frontmatter["surface"], "swarm-chat-only")
        XCTAssertTrue(page.markdown.contains("Send the client follow-up due today."))
        XCTAssertTrue(page.markdown.contains("New Downloaded Notes.txt"))
        XCTAssertTrue(try harness.store.fetchWikiPages().contains { $0.id == page.id })
        XCTAssertTrue(FileManager.default.fileExists(atPath: WikiVaultManager(paths: harness.paths).fileURL(for: page).path))
    }

    func testCallTranscriptAutomationExtractsDecisionsActionsAndPages() throws {
        let harness = try makeHarness()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let source = makeSource(id: "call-1", title: "Client Sync Transcript", now: now)
        try harness.store.saveSource(source)
        let transcript = """
        We decided to ship the onboarding automation first.
        Action: Arpit will send the revised deck. Owner: Arpit. Deadline: Friday.
        We agreed to keep cloud processing opt-in.
        """

        let plan = try HiveAutomationOrchestrator(store: harness.store, paths: harness.paths)
            .processCallTranscript(source: source, transcriptText: transcript, now: now)

        XCTAssertEqual(plan.summaryBullets.count, 3)
        XCTAssertTrue(plan.decisions.contains { $0.localizedCaseInsensitiveContains("onboarding automation") })
        XCTAssertTrue(plan.actions.contains { $0.owner == "Arpit" && ($0.deadline?.localizedCaseInsensitiveContains("Friday") ?? false) })
        XCTAssertTrue(try harness.store.fetchClaims().contains { $0.claimType == "action-item" && $0.sourceRefs == [source.id] })
        let pages = try harness.store.fetchWikiPages()
        XCTAssertTrue(pages.contains { $0.id == "decision-log" && $0.markdown.contains("We agreed to keep cloud processing opt-in") })
        XCTAssertTrue(pages.contains { $0.id == "transcript-\(source.id)-topic" && $0.sourceRefs == [source.id] })
    }

    func testLargeTextbookSourceAsksIntentBeforeFloodingHive() throws {
        let text = String(repeating: "Chapter 1 textbook theorem exercise problem set lecture notes. ", count: 2_200)

        let review = HiveSourceIntentClassifier().review(
            title: "Linear Algebra Textbook.pdf",
            text: text,
            sourceKind: .pdf
        )

        XCTAssertEqual(review.intent, .courseNotes)
        XCTAssertTrue(review.shouldAskBeforePromotingToHive)
        XCTAssertTrue(review.retentionGuidance.localizedCaseInsensitiveContains("do not promote every textbook fact"))
    }

    func testManualIngestionCreatesProvenanceWikiAndGraph() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(
            in: harness.root,
            name: "ProjectAtlas.md",
            text: "Project Atlas met with Design Systems on Monday. Project Atlas needs source-linked research notes and graph review."
        )

        let imported = try harness.ingestion.ingest(urls: [file])
        XCTAssertEqual(imported.count, 1)

        let graph = try harness.loop.updateDerivedKnowledge()
        let sources = try harness.store.fetchSources()
        let chunks = try harness.store.fetchChunks()
        let claims = try harness.store.fetchClaims()
        let entities = try harness.store.fetchEntities()
        let pages = try harness.store.fetchWikiPages()

        XCTAssertEqual(sources.count, 1)
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertFalse(claims.isEmpty)
        XCTAssertTrue(claims.allSatisfy { $0.sourceRefs == [sources[0].id] })
        let extractedClaims = claims.filter { $0.claimType != "graph-insight" }
        XCTAssertTrue(extractedClaims.allSatisfy { !$0.sourceSpanRefs.isEmpty })
        XCTAssertTrue(extractedClaims.allSatisfy { claim in
            claim.sourceSpanRefs.allSatisfy { spanID in chunks.contains { $0.id == spanID } }
        })
        XCTAssertFalse(entities.isEmpty)
        XCTAssertEqual(pages.first?.id, "overview")
        XCTAssertFalse(graph.nodes.isEmpty)
        XCTAssertFalse(graph.edges.isEmpty)
    }

    func testDeterministicExtractorRejectsGenericQuestionWordsAsEntities() throws {
        let now = Date()
        let source = makeSource(id: "seed-prompt", title: "AI Memory Seed.md", now: now)
        let chunk = ChunkRecord(
            id: "seed-chunk",
            sourceID: source.id,
            artifactID: "artifact",
            text: """
            "question": "Is Hive an app you are building yourself, or a third-party product you are importing memory into?"
            Determines whether mate-tracker is a personal family tool or a client project.
            Avni and Locus are meaningful names.
            """,
            locationLabel: "fixture"
        )

        let names = DeterministicKnowledgeExtractor()
            .entities(from: [chunk], source: source)
            .map(\.name)

        XCTAssertFalse(names.contains("Is Hive"))
        XCTAssertFalse(names.contains("Determines"))
        XCTAssertFalse(names.contains("Are"))
        XCTAssertFalse(names.contains("Has"))
        XCTAssertTrue(names.contains("Avni"))
        XCTAssertTrue(names.contains("Locus"))
    }

    func testVaultBootstrapCreatesSchemaIndexAndLogPlaceholders() throws {
        let harness = try makeHarness()

        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.paths.vault.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.paths.vaultRawSources.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.paths.vaultWiki.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.paths.agentsFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.paths.vaultWiki.appendingPathComponent("index.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.paths.vaultWiki.appendingPathComponent("log.md").path))
        XCTAssertEqual(harness.paths.vaultRawSources.lastPathComponent, "flower-field")
        XCTAssertEqual(Array(harness.paths.vaultRawAssets.pathComponents.suffix(2)), ["flower-field", "assets"])
        XCTAssertEqual(harness.paths.vaultWiki.lastPathComponent, "Colony")

        let schema = try String(contentsOf: harness.paths.agentsFile, encoding: .utf8)
        XCTAssertTrue(schema.contains("Hive is an LLM Wiki"))
        XCTAssertTrue(schema.contains("This is not a RAG cache"))
        XCTAssertTrue(schema.contains("Field (`flower-field/`) is the immutable source-of-truth junk drawer"))
        XCTAssertTrue(schema.contains("The Colony (`Colony/`) is the persistent compiled wiki"))
        XCTAssertTrue(schema.contains("## Local AI Contract"))
        XCTAssertTrue(schema.contains("Behave like a disciplined local wiki maintainer, not a generic chatbot"))
        XCTAssertTrue(schema.contains("Model output is proposal-only"))
        XCTAssertTrue(schema.contains("Colony/index.md"))
        XCTAssertTrue(schema.contains("Colony/log.md"))
        XCTAssertTrue(schema.contains("Coordinates represent the selected semantic axes"))
        XCTAssertTrue(schema.contains("User corrections made through Hive are authoritative guidance"))
        XCTAssertFalse(schema.contains("`Colony/sources/`: source summaries"))
        XCTAssertTrue(schema.contains("This product replaces the Obsidian plus terminal-agent workflow"))
    }

    func testVaultSchemaMigratesExistingAgentsFileToCompiledWikiContract() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HiveSchema-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let paths = HivePaths(root: root.appendingPathComponent("Workspace", isDirectory: true))
        try FileManager.default.createDirectory(at: paths.vault, withIntermediateDirectories: true)
        try "# Hive Agents Schema\n\nOld schema.\n".write(to: paths.agentsFile, atomically: true, encoding: .utf8)

        try WikiVaultManager(paths: paths).ensureVault()

        let migrated = try String(contentsOf: paths.agentsFile, encoding: .utf8)
        XCTAssertTrue(migrated.contains("This is not a RAG cache"))
        XCTAssertTrue(migrated.contains("Hive is an LLM Wiki"))
        XCTAssertTrue(migrated.contains("## Local AI Contract"))
        XCTAssertTrue(migrated.contains("hive-query"))
        XCTAssertTrue(migrated.contains("flower-field/assets"))
    }

    func testVaultMigratesLegacyRawSourcesAssetsAndWikiFolders() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HiveLegacyVault-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let paths = HivePaths(root: root.appendingPathComponent("Workspace", isDirectory: true))
        let legacyRawSources = paths.vault.appendingPathComponent("raw-sources", isDirectory: true)
        let legacyRawAssets = paths.vault.appendingPathComponent("raw/assets", isDirectory: true)
        let legacyWiki = paths.vault.appendingPathComponent("wiki", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyRawSources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyRawAssets, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyWiki, withIntermediateDirectories: true)
        try "legacy source".write(to: legacyRawSources.appendingPathComponent("source.txt"), atomically: true, encoding: .utf8)
        try "legacy asset".write(to: legacyRawAssets.appendingPathComponent("image.md"), atomically: true, encoding: .utf8)
        try "# Legacy".write(to: legacyWiki.appendingPathComponent("overview.md"), atomically: true, encoding: .utf8)

        try WikiVaultManager(paths: paths).ensureVault()

        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.vaultRawSources.appendingPathComponent("source.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.vaultRawAssets.appendingPathComponent("image.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.vaultWiki.appendingPathComponent("overview.md").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyRawSources.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyRawAssets.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.vault.appendingPathComponent("raw", isDirectory: true).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyWiki.path))
    }

    func testIngestMirrorsRawSourceAndCompilesIndexLogWithoutSourcePages() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(
            in: harness.root,
            name: "client-notes.txt",
            text: "Client Alpha needs a searchable competitive intel vault for market research and project memory."
        )
        let source = try harness.ingestion.ingest(urls: [file])[0]
        _ = try harness.loop.updateDerivedKnowledge()

        let mirrorURL = WikiVaultManager(paths: harness.paths).rawMirrorURL(for: source)
        XCTAssertTrue(FileManager.default.fileExists(atPath: mirrorURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.paths.vaultWiki.appendingPathComponent("index.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.paths.vaultWiki.appendingPathComponent("log.md").path))
        XCTAssertTrue(try harness.store.fetchWikiPages().filter { $0.kind == .source }.isEmpty)

        let index = try String(contentsOf: harness.paths.vaultWiki.appendingPathComponent("index.md"), encoding: .utf8)
        let log = try String(contentsOf: harness.paths.vaultWiki.appendingPathComponent("log.md"), encoding: .utf8)
        XCTAssertFalse(index.contains("[[Source - client-notes.txt]]"))
        XCTAssertTrue(index.contains("updated "))
        XCTAssertTrue(index.contains("sources") || index.contains("claims"))
        XCTAssertTrue(log.contains("## ["))
        XCTAssertTrue(log.contains("] ingest | source:"))
        XCTAssertTrue(log.contains("source.ingested"))
    }

    func testExternalWikiEditsBecomeAuthoritativeUserClaims() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(in: harness.root, name: "external-edit.txt", text: "External Edit Source should produce a wiki page.")
        _ = try harness.ingestion.ingest(urls: [file])
        _ = try harness.loop.updateDerivedKnowledge()

        let overview = try XCTUnwrap(try harness.store.fetchWikiPages().first { $0.id == "overview" })
        let overviewPath = try XCTUnwrap(overview.filePath)
        let overviewURL = overviewPath.isEmpty
            ? harness.paths.vaultWiki.appendingPathComponent("overview.md")
            : URL(fileURLWithPath: overviewPath)
        try "# Overview\n\nManual external edit that should become canonical user knowledge.\n".write(to: overviewURL, atomically: true, encoding: .utf8)

        _ = try harness.loop.updateDerivedKnowledge()

        let feedback = try harness.store.fetchFeedback()
        XCTAssertFalse(feedback.contains {
            $0.targetType == "wikiPage" && $0.targetID == "overview" && $0.action == .askLater
        })
        let claims = try harness.store.fetchClaims()
        XCTAssertTrue(claims.contains {
            $0.createdBy == "user-wiki-edit"
                && $0.confidence == 1.0
                && $0.statement == "Manual external edit that should become canonical user knowledge."
        })
        XCTAssertTrue(try harness.store.fetchAuditEvents().contains { $0.eventType == "wiki.externalEditApplied" })
    }

    func testDeletedColonyArticleStaysDeletedAcrossKnowledgeRefresh() throws {
        let harness = try makeHarness()
        let now = Date()
        let source = makeSource(id: "delete-candidate-source", title: "Delete Candidate Source", now: now)
        let claim = ClaimRecord(
            id: "claim-delete-candidate",
            statement: "The user owns Delete Candidate, a project that should be removable from The Colony.",
            claimType: "source-observation",
            subjectEntityID: "delete-candidate",
            sourceRefs: [source.id],
            confidence: 0.92,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let secondClaim = ClaimRecord(
            id: "claim-delete-candidate-scope",
            statement: "The user uses Delete Candidate to verify backend deletion testing for Colony articles.",
            claimType: "source-observation",
            subjectEntityID: "delete-candidate",
            sourceRefs: [source.id],
            confidence: 0.92,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let entity = EntityRecord(
            id: "delete-candidate",
            name: "Delete Candidate",
            entityType: "project",
            sourceRefs: [source.id],
            confidence: 0.94,
            createdAt: now
        )
        try harness.store.saveSource(source)
        try harness.store.saveClaim(claim)
        try harness.store.saveClaim(secondClaim)
        try harness.store.saveEntity(entity)

        _ = try harness.loop.updateDerivedKnowledge()
        let page = try XCTUnwrap(try harness.store.fetchWikiPages().first {
            $0.isUserVisibleArticle && $0.title == "Delete Candidate"
        })
        let pagePath = try XCTUnwrap(page.filePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pagePath))

        try harness.store.saveFeedback(FeedbackRecord(
            targetType: "wikiPage",
            targetID: page.id,
            action: .delete,
            note: "Deleted from The Colony by user."
        ))

        _ = try harness.loop.updateDerivedKnowledge()

        XCTAssertFalse(try harness.store.fetchWikiPages().contains { $0.id == page.id })
        XCTAssertFalse(FileManager.default.fileExists(atPath: pagePath))
        XCTAssertTrue(try harness.store.fetchSources().contains { $0.id == source.id })
        XCTAssertTrue(try harness.store.fetchClaims().contains { $0.id == claim.id })
    }

    func testFullForgetRemovesVaultRawMirrorAndGeneratedWikiText() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(
            in: harness.root,
            name: "forget-vault.txt",
            text: "Vault Forget Source contains sensitive agency client margin notes."
        )
        let source = try harness.ingestion.ingest(urls: [file])[0]
        _ = try harness.loop.updateDerivedKnowledge()
        let mirrorURL = WikiVaultManager(paths: harness.paths).rawMirrorURL(for: source)
        XCTAssertTrue(FileManager.default.fileExists(atPath: mirrorURL.path))

        try harness.controlPlane.fullForgetSource(id: source.id)
        _ = try harness.loop.updateDerivedKnowledge()

        XCTAssertFalse(FileManager.default.fileExists(atPath: mirrorURL.path))
        let vaultText = try combinedFileText(under: harness.paths.vault)
        XCTAssertFalse(vaultText.contains("Vault Forget Source"))
        XCTAssertFalse(vaultText.contains("sensitive agency client margin notes"))
    }

    func testRawRetentionExpiryDeletesBlobButPreservesDerivedClaim() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(in: harness.root, name: "retention.txt", text: "Retention Source has a useful claim that should remain after raw expiry.")
        let source = try harness.ingestion.ingest(urls: [file])[0]
        let rawPath = try XCTUnwrap(try harness.store.fetchRawBlobs(sourceID: source.id).first?.localPath)

        var expired = try XCTUnwrap(try harness.store.fetchSource(id: source.id))
        expired.retentionExpiresAt = Date().addingTimeInterval(-60)
        try harness.store.saveSource(expired)

        let purged = try harness.controlPlane.purgeExpiredRawInputs()
        let updated = try XCTUnwrap(try harness.store.fetchSource(id: source.id))
        let claims = try harness.store.fetchClaims()

        XCTAssertEqual(purged, 1)
        XCTAssertEqual(updated.deletionState, .rawExpired)
        XCTAssertFalse(FileManager.default.fileExists(atPath: rawPath))
        XCTAssertTrue(try harness.store.fetchRawBlobs(sourceID: source.id).isEmpty)
        XCTAssertFalse(claims.isEmpty)
        XCTAssertTrue(claims.allSatisfy { $0.status != .retracted })
    }

    func testManualRawDeleteRemovesRawBlobRowsButPreservesDerivedArtifacts() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(in: harness.root, name: "raw-delete.txt", text: "Raw Delete Source keeps derived claims after raw removal.")
        let source = try harness.ingestion.ingest(urls: [file])[0]
        let rawPath = try XCTUnwrap(try harness.store.fetchRawBlobs(sourceID: source.id).first?.localPath)
        XCTAssertFalse(try harness.store.fetchArtifacts(sourceID: source.id).isEmpty)
        XCTAssertFalse(try harness.store.searchChunks("Delete").isEmpty)

        try harness.controlPlane.deleteRawOnly(sourceID: source.id)

        let updated = try XCTUnwrap(try harness.store.fetchSource(id: source.id))
        XCTAssertEqual(updated.deletionState, .rawDeleted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: rawPath))
        XCTAssertTrue(try harness.store.fetchRawBlobs(sourceID: source.id).isEmpty)
        let artifacts = try harness.store.fetchArtifacts(sourceID: source.id)
        XCTAssertFalse(artifacts.isEmpty)
        XCTAssertTrue(artifacts.allSatisfy { $0.inlineText == nil && $0.localPath == nil })
        let chunks = try harness.store.fetchChunks(sourceID: source.id)
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(chunks.allSatisfy { !$0.text.contains("Raw Delete Source") })
        XCTAssertTrue(try harness.store.searchChunks("Delete").isEmpty)
        XCTAssertFalse(try harness.store.fetchClaims().isEmpty)
    }

    func testExportWritesMarkdownAndStructuredDataWithoutRawBlobs() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(in: harness.root, name: "export.txt", text: "Export Source needs a portable local data snapshot.")
        let source = try harness.ingestion.ingest(urls: [file])[0]
        let rawPath = try XCTUnwrap(try harness.store.fetchRawBlobs(sourceID: source.id).first?.localPath)
        _ = try harness.loop.updateDerivedKnowledge()

        let exportRoot = harness.root.appendingPathComponent("Exports", isDirectory: true)
        let exportURL = try HiveExporter().exportSnapshot(store: harness.store, to: exportRoot, now: Date(timeIntervalSince1970: 0))

        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.appendingPathComponent("wiki/Overview.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.appendingPathComponent("data/sources.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.appendingPathComponent("data/claims.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.appendingPathComponent("data/audit.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportURL.appendingPathComponent((rawPath as NSString).lastPathComponent).path))

        let manifestData = try Data(contentsOf: exportURL.appendingPathComponent("data/manifest.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ExportManifest.self, from: manifestData)
        XCTAssertEqual(manifest.sourceCount, 1)
        XCTAssertTrue(manifest.note.contains("Raw blobs"))
    }

    func testExportAfterFullForgetExcludesForgottenSourceAndRetractedClaims() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(
            in: harness.root,
            name: "forget-export.txt",
            text: "Forget Export Source has private claim text that must disappear from portable export."
        )
        let source = try harness.ingestion.ingest(urls: [file])[0]
        _ = try harness.loop.updateDerivedKnowledge()

        try harness.controlPlane.fullForgetSource(id: source.id)

        let exportURL = try HiveExporter().exportSnapshot(
            store: harness.store,
            to: harness.root.appendingPathComponent("Exports", isDirectory: true),
            now: Date(timeIntervalSince1970: 0)
        )
        let exportedText = try combinedFileText(under: exportURL)

        XCTAssertFalse(exportedText.contains("Forget Export Source"))
        XCTAssertFalse(exportedText.contains("private claim text"))
        XCTAssertFalse(exportedText.contains(source.id))
    }

    func testPinnedSourceSurvivesRetentionExpiry() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(in: harness.root, name: "pinned.txt", text: "Pinned Source remains available after the retention window.")
        let source = try harness.ingestion.ingest(urls: [file])[0]
        try harness.store.setSourcePinned(id: source.id, pinned: true)
        var expired = try XCTUnwrap(try harness.store.fetchSource(id: source.id))
        expired.retentionExpiresAt = Date().addingTimeInterval(-60)
        try harness.store.saveSource(expired)

        let purged = try harness.controlPlane.purgeExpiredRawInputs()
        let updated = try XCTUnwrap(try harness.store.fetchSource(id: source.id))

        XCTAssertEqual(purged, 0)
        XCTAssertEqual(updated.deletionState, .active)
        XCTAssertTrue(updated.pinned)
    }

    func testFullForgetRetractsClaimsAndRemovesArtifacts() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(in: harness.root, name: "forget.txt", text: "Forget Source has a claim that should be retracted during full forget.")
        let source = try harness.ingestion.ingest(urls: [file])[0]
        XCTAssertFalse(try harness.store.fetchClaims().isEmpty)

        try harness.controlPlane.fullForgetSource(id: source.id)

        let updated = try XCTUnwrap(try harness.store.fetchSource(id: source.id))
        let claims = try harness.store.fetchClaims(includeRetracted: true)
        let chunks = try harness.store.fetchChunks(sourceID: source.id)
        let artifacts = try harness.store.fetchArtifacts(sourceID: source.id)
        let entities = try harness.store.fetchEntities().filter { $0.sourceRefs.contains(source.id) }

        XCTAssertEqual(updated.deletionState, .fullForgotten)
        XCTAssertTrue(claims.allSatisfy { $0.status == .retracted })
        XCTAssertTrue(chunks.isEmpty)
        XCTAssertTrue(artifacts.isEmpty)
        XCTAssertTrue(entities.isEmpty)
    }

    func testFullForgetScrubsPrivateTextFromLocalStore() throws {
        let harness = try makeHarness()
        let secret = "ZephyrForgetToken"
        let file = try makeTextFile(
            in: harness.root,
            name: "zephyr-forget-token.txt",
            text: "\(secret) appears in a source claim and must not survive full forget."
        )
        let source = try harness.ingestion.ingest(urls: [file])[0]
        let claim = try XCTUnwrap(try harness.store.fetchClaims().first)
        try harness.store.saveWikiPage(WikiPageRecord(
            title: "Secret overview",
            markdown: "Wiki still mentions \(secret)",
            sourceRefs: [source.id],
            claimRefs: [claim.id]
        ))
        try harness.store.saveFeedback(FeedbackRecord(
            targetType: "claim",
            targetID: claim.id,
            action: .askLater,
            note: "Feedback mentions \(secret)"
        ))
        try harness.store.appendAudit(AuditEventRecord(
            eventType: "fixture.secret",
            targetType: "source",
            targetID: source.id,
            sourceRefs: [source.id],
            detail: "Audit mentions \(secret)"
        ))

        try harness.controlPlane.fullForgetSource(id: source.id)

        let forgottenSource = try XCTUnwrap(try harness.store.fetchSource(id: source.id))
        XCTAssertEqual(forgottenSource.title, "Forgotten source")
        XCTAssertFalse(forgottenSource.uri.contains("zephyr-forget-token"))
        XCTAssertFalse(try harness.store.fetchClaims(includeRetracted: true).contains { $0.statement.contains(secret) })
        XCTAssertFalse(try harness.store.fetchWikiPages().contains { $0.markdown.contains(secret) })
        XCTAssertFalse(try harness.store.fetchFeedback().contains { $0.note.contains(secret) })
        XCTAssertFalse(try harness.store.fetchAuditEvents().contains { $0.detail.contains(secret) })
        XCTAssertFalse(try combinedStoreText(databaseURL: harness.paths.database).contains(secret))
    }

    func testFullForgetRemovesMultiSourceEntitiesAndRelationships() throws {
        let harness = try makeHarness()
        let now = Date()
        let forgotten = makeSource(id: "forgotten-source", title: "Forgotten source", now: now)
        let retained = makeSource(id: "retained-source", title: "Retained source", now: now)
        try harness.store.saveSource(forgotten)
        try harness.store.saveSource(retained)
        let chunk = ChunkRecord(
            id: "forgotten-chunk",
            sourceID: forgotten.id,
            artifactID: "artifact",
            text: "Forgotten evidence",
            locationLabel: "fixture"
        )
        try harness.store.saveChunk(chunk)
        let sharedEntity = EntityRecord(
            id: "shared-entity",
            name: "Shared Sensitive Topic",
            entityType: "topic",
            sourceRefs: [retained.id, forgotten.id],
            confidence: 0.7
        )
        try harness.store.saveEntity(sharedEntity)
        let claim = ClaimRecord(
            id: "multi-source-claim",
            statement: "Multi-source claim includes forgotten evidence",
            sourceRefs: [retained.id, forgotten.id],
            sourceSpanRefs: [chunk.id],
            confidence: 0.7,
            uncertaintyReason: "Fixture"
        )
        try harness.store.saveClaim(claim)
        try harness.store.saveRelationship(RelationshipRecord(
            id: "relationship-by-entity",
            subjectID: sharedEntity.id,
            predicate: .supports,
            objectID: claim.id,
            strength: 0.7,
            confidence: 0.7,
            evidenceCount: 1,
            sourceSpanRefs: [chunk.id]
        ))

        try harness.controlPlane.fullForgetSource(id: forgotten.id)

        XCTAssertEqual(try harness.store.fetchSource(id: retained.id)?.deletionState, .active)
        XCTAssertEqual(try harness.store.fetchClaim(id: claim.id)?.status, .retracted)
        XCTAssertFalse(try harness.store.fetchEntities().contains { $0.id == sharedEntity.id })
        XCTAssertFalse(try harness.store.fetchRelationships().contains { $0.id == "relationship-by-entity" })
        XCTAssertTrue(try harness.store.fetchChunks(sourceID: forgotten.id).isEmpty)
    }

    func testFullForgetSourcesByKindOnlyTargetsBrowserHistory() throws {
        let harness = try makeHarness()
        let now = Date()
        var browserSource = makeSource(id: "browser-source", title: "Browser source", now: now)
        browserSource.kind = .browserHistory
        browserSource.connector = "browser"
        browserSource.privacyLabel = .cloudBlocked
        let textSource = makeSource(id: "text-source", title: "Text source", now: now)
        try harness.store.saveSource(browserSource)
        try harness.store.saveSource(textSource)
        try harness.store.saveClaim(ClaimRecord(
            id: "browser-claim",
            statement: "Browser-only claim should be forgotten",
            sourceRefs: [browserSource.id],
            confidence: 0.2,
            uncertaintyReason: "Fixture"
        ))
        try harness.store.saveClaim(ClaimRecord(
            id: "text-claim",
            statement: "Text claim should remain",
            sourceRefs: [textSource.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture"
        ))

        let count = try harness.controlPlane.fullForgetSources(kinds: [.browserHistory, .browserBookmark])

        XCTAssertEqual(count, 1)
        XCTAssertEqual(try harness.store.fetchSource(id: browserSource.id)?.deletionState, .fullForgotten)
        XCTAssertEqual(try harness.store.fetchSource(id: textSource.id)?.deletionState, .active)
        XCTAssertEqual(try harness.store.fetchClaim(id: "browser-claim")?.status, .retracted)
        XCTAssertEqual(try harness.store.fetchClaim(id: "text-claim")?.status, .active)
    }

    func testURLSafetyPolicyBlocksPrivateTargetsAndAllowsPublicHTTPS() throws {
        let policy = URLSafetyPolicy()
        XCTAssertEqual(policy.evaluate(URL(string: "http://localhost:3000")!), .blocked("Local hosts are private."))
        XCTAssertEqual(policy.evaluate(URL(string: "https://192.168.1.10/path")!), .blocked("Private, loopback, link-local, multicast, and metadata IPs are blocked."))
        XCTAssertEqual(policy.evaluate(URL(string: "https://127.0.0.1.nip.io/path")!), .blocked("Private, loopback, link-local, multicast, and metadata IPs are blocked."))
        XCTAssertEqual(policy.evaluate(URL(string: "https://2130706433/path")!), .blocked("Private, loopback, link-local, multicast, and metadata IPs are blocked."))
        XCTAssertEqual(policy.evaluate(URL(string: "https://0x7f000001/path")!), .blocked("Private, loopback, link-local, multicast, and metadata IPs are blocked."))
        XCTAssertEqual(policy.evaluate(URL(string: "https://[::ffff:127.0.0.1]/path")!), .blocked("Private, loopback, link-local, multicast, and metadata IPs are blocked."))
        XCTAssertEqual(policy.evaluate(URL(string: "file:///tmp/source.txt")!), .blocked("Only HTTP and HTTPS URLs are allowed."))
        XCTAssertTrue(policy.isAllowed(URL(string: "https://example.com/research")!))
    }

    func testBrowserHistoryNeedsEngagementBeforeIntent() throws {
        let scorer = BrowserEngagementScorer()
        let passive = scorer.score(BrowserVisitSignal(
            url: URL(string: "https://example.com/scroll")!,
            title: "Example",
            durationSeconds: 12,
            repeatCount: 1
        ))
        let saved = scorer.score(BrowserVisitSignal(
            url: URL(string: "https://example.com/paper")!,
            title: "Paper",
            durationSeconds: 240,
            repeatCount: 3,
            bookmarked: true,
            activeInteractionCount: 5
        ))

        XCTAssertEqual(passive.intent, .incidental)
        XCTAssertTrue(passive.reason.contains("not treated as preference"))
        XCTAssertEqual(saved.intent, .intentional)
        XCTAssertGreaterThan(saved.score, passive.score)
    }

    func testYouTubeShortsStayIncidentalWithoutNinetyFivePercentEngagement() throws {
        let scorer = BrowserEngagementScorer()
        let casualShort = scorer.score(BrowserVisitSignal(
            url: URL(string: "https://www.youtube.com/shorts/example")!,
            title: "Short",
            durationSeconds: 240,
            repeatCount: 3,
            activeInteractionCount: 5
        ))
        let explicitlySavedShort = scorer.score(BrowserVisitSignal(
            url: URL(string: "https://www.youtube.com/shorts/important")!,
            title: "Saved Short",
            durationSeconds: 300,
            repeatCount: 5,
            bookmarked: true,
            downloaded: true,
            shared: true,
            activeInteractionCount: 8
        ))

        XCTAssertEqual(casualShort.intent, .incidental)
        XCTAssertLessThan(casualShort.score, 0.95)
        XCTAssertTrue(casualShort.reason.contains("95%"))
        XCTAssertEqual(explicitlySavedShort.intent, .intentional)
        XCTAssertGreaterThanOrEqual(explicitlySavedShort.score, 0.95)
    }

    func testRuntimePolicyDefersHeavyBackgroundWorkWhileUserIsActive() throws {
        let profile = RuntimeProfile(
            chipName: "MacBookPro",
            physicalMemoryBytes: 16 * 1_073_741_824,
            processorCount: 10,
            thermalState: .nominal,
            powerState: .unknown,
            lowPowerModeEnabled: false,
            foregroundUserActive: true
        )
        let policy = RuntimePolicy()
        let background = policy.decision(for: .summarization, profile: profile, manual: false)
        let manual = policy.decision(for: .summarization, profile: profile, manual: true)

        XCTAssertFalse(background.allowed)
        XCTAssertTrue(background.reason.contains("User is active"))
        XCTAssertTrue(manual.allowed)
        XCTAssertEqual(manual.selectedModelID, "mlx-qwen2-5-7b-4bit")
    }

    func testFeedbackMutatesClaimConfidenceStatusAndLineage() throws {
        let harness = try makeHarness()
        let source = makeSource(id: "feedback-source", title: "Feedback source", now: Date())
        try harness.store.saveSource(source)
        let claim = ClaimRecord(
            id: "feedback-claim",
            statement: "Feedback claim should respond to user controls",
            sourceRefs: [source.id],
            confidence: 0.4,
            uncertaintyReason: "Fixture"
        )
        try harness.store.saveClaim(claim)

        let matters = FeedbackRecord(targetType: "claim", targetID: claim.id, action: .matters)
        try harness.controlPlane.applyFeedback(matters)
        var updated = try XCTUnwrap(try harness.store.fetchClaim(id: claim.id))
        XCTAssertEqual(updated.status, .active)
        XCTAssertGreaterThanOrEqual(updated.confidence, 0.76)
        XCTAssertTrue(updated.correctionLineage.contains(matters.id))

        let incidental = FeedbackRecord(targetType: "claim", targetID: claim.id, action: .incidental)
        try harness.controlPlane.applyFeedback(incidental)
        updated = try XCTUnwrap(try harness.store.fetchClaim(id: claim.id))
        XCTAssertEqual(updated.status, .suspect)
        XCTAssertLessThanOrEqual(updated.confidence, 0.22)
        XCTAssertTrue(updated.uncertaintyReason.contains("incidental"))

        let denied = FeedbackRecord(targetType: "claim", targetID: claim.id, action: .deny)
        try harness.controlPlane.applyFeedback(denied)
        updated = try XCTUnwrap(try harness.store.fetchClaim(id: claim.id))
        XCTAssertEqual(updated.status, .retracted)
    }

    func testGraphNodeFeedbackPersistsForNonClaimControls() throws {
        let harness = try makeHarness()
        let feedback = FeedbackRecord(targetType: "graphNode", targetID: "topic-node", action: .matters, note: "Pinned from graph inspector")

        try harness.controlPlane.applyFeedback(feedback)

        let records = try harness.store.fetchFeedback()
        let audits = try harness.store.fetchAuditEvents()
        XCTAssertTrue(records.contains { $0.targetType == "graphNode" && $0.targetID == "topic-node" && $0.action == .matters })
        XCTAssertTrue(audits.contains { $0.eventType == "feedback.matters" && $0.targetType == "graphNode" })
    }

    func testMergeSplitFeedbackPersistsWithoutUnsafeMutation() throws {
        let harness = try makeHarness()
        let source = makeSource(id: "merge-source", title: "Merge source", now: Date())
        let claim = ClaimRecord(
            id: "merge-claim",
            statement: "Merge candidate should wait for review",
            sourceRefs: [source.id],
            confidence: 0.6,
            uncertaintyReason: "Fixture"
        )
        try harness.store.saveSource(source)
        try harness.store.saveClaim(claim)

        try harness.controlPlane.applyFeedback(FeedbackRecord(targetType: "claim", targetID: claim.id, action: .merge))
        try harness.controlPlane.applyFeedback(FeedbackRecord(targetType: "claim", targetID: claim.id, action: .split))

        let updated = try XCTUnwrap(try harness.store.fetchClaim(id: claim.id))
        let feedback = try harness.store.fetchFeedback()
        XCTAssertEqual(updated.status, .active)
        XCTAssertTrue(feedback.contains { $0.targetID == claim.id && $0.action == .merge })
        XCTAssertTrue(feedback.contains { $0.targetID == claim.id && $0.action == .split })
    }

    func testReviewQueueAsksOnlyForLowConfidenceUnderstoodClaims() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let source = makeSource(id: "review-source", title: "Review source", now: now)
        let conflict = ClaimRecord(
            id: "review-conflict",
            statement: "Project Atlas moved from Monday to Tuesday",
            sourceRefs: [source.id],
            confidence: 0.68,
            uncertaintyReason: "Conflicting dates",
            contradictionGroupID: "atlas-date",
            status: .contradicted,
            createdAt: now
        )
        let lowConfidence = ClaimRecord(
            id: "review-low",
            statement: "Low confidence memory needs a human decision",
            sourceRefs: [source.id],
            confidence: 0.32,
            uncertaintyReason: "Single weak source",
            status: .suspect,
            createdAt: now.addingTimeInterval(10)
        )
        let feedback = [
            FeedbackRecord(
                id: "review-merge-feedback",
                targetType: "claim",
                targetID: lowConfidence.id,
                action: .merge,
                timestamp: now.addingTimeInterval(20)
            ),
            FeedbackRecord(
                id: "review-later-feedback",
                targetType: "claim",
                targetID: conflict.id,
                action: .askLater,
                timestamp: now.addingTimeInterval(30)
            )
        ]

        let queue = ReviewQueueBuilder().build(
            claims: [lowConfidence, conflict],
            sources: [source],
            feedback: feedback,
            now: now
        )

        XCTAssertEqual(queue.count, 2)
        XCTAssertTrue(queue.allSatisfy { $0.targetType == .claim })
        XCTAssertTrue(queue.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty && !$0.reason.isEmpty })
        XCTAssertTrue(queue.contains { $0.targetID == conflict.id && $0.title == "Project Atlas moved from Monday to Tuesday" })
        XCTAssertTrue(queue.contains { $0.targetID == conflict.id && $0.detail == "Resolve which version should stay in the wiki." })
        XCTAssertTrue(queue.contains { $0.targetID == lowConfidence.id && $0.title == "Low confidence memory needs a human decision" })
        XCTAssertTrue(queue.contains { $0.targetID == lowConfidence.id && $0.detail == "Add this understood detail to the wiki?" })
        XCTAssertTrue(queue.contains { $0.targetID == lowConfidence.id && $0.action == .merge })
        XCTAssertTrue(queue.contains { $0.targetID == conflict.id && $0.action == .askLater })
        XCTAssertTrue(queue.contains { $0.targetID == lowConfidence.id })
    }

    func testReviewQueueDoesNotTurnPassiveBrowserHistoryIntoConfirmationWork() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let browser = SourceRecord(
            id: "review-browser-source",
            kind: .browserHistory,
            connector: "browser-history-snapshot",
            uri: "browser-history://Safari/Default",
            title: "Safari Default history",
            mimeType: "text/plain",
            sizeBytes: 100,
            sha256: "review-browser-source",
            importedAt: now,
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(14 * 86_400),
            privacyLabel: .cloudBlocked,
            status: .extracted
        )
        let incidental = ClaimRecord(
            id: "review-browser-claim",
            statement: "INCIDENTAL: Perplexity Computer Artifacts — perplexity.ai — Browser appearance alone is incidental and is not treated as preference.",
            sourceRefs: [browser.id],
            confidence: 0.41,
            uncertaintyReason: "Browser evidence may be incidental.",
            status: .suspect,
            createdAt: now
        )
        let highConfidenceBrowser = ClaimRecord(
            id: "review-browser-high-confidence",
            statement: "Browser bookmark is backed by stronger engagement",
            sourceRefs: [browser.id],
            confidence: 0.73,
            uncertaintyReason: "Bookmarked and revisited.",
            status: .active,
            createdAt: now
        )
        let retracted = ClaimRecord(
            id: "review-retracted-claim",
            statement: "Retracted claim should not appear",
            sourceRefs: [browser.id],
            confidence: 0.2,
            uncertaintyReason: "No longer valid",
            status: .retracted,
            createdAt: now
        )

        let queue = ReviewQueueBuilder().build(claims: [incidental, highConfidenceBrowser, retracted], sources: [browser], feedback: [])
        XCTAssertFalse(queue.contains { $0.targetID == incidental.id })
        XCTAssertFalse(queue.contains { $0.targetID == highConfidenceBrowser.id })
        XCTAssertFalse(queue.contains { $0.targetID == retracted.id })
    }

    func testReviewQueueTreatsUserMarkedIncidentalAsResolved() throws {
        let harness = try makeHarness()
        let now = Date(timeIntervalSince1970: 2_500)
        let source = makeSource(id: "resolved-incidental-source", title: "Resolved incidental source", now: now)
        let claim = ClaimRecord(
            id: "resolved-incidental-claim",
            statement: "INCIDENTAL browser observation has already been reviewed",
            sourceRefs: [source.id],
            confidence: 0.33,
            uncertaintyReason: "Browser evidence may be incidental.",
            status: .suspect,
            createdAt: now
        )
        try harness.store.saveSource(source)
        try harness.store.saveClaim(claim)

        try harness.controlPlane.applyFeedback(FeedbackRecord(
            id: "resolved-incidental-feedback",
            targetType: "claim",
            targetID: claim.id,
            action: .incidental,
            timestamp: now.addingTimeInterval(5)
        ))

        let queue = ReviewQueueBuilder().build(
            claims: try harness.store.fetchClaims(),
            sources: try harness.store.fetchSources(),
            feedback: try harness.store.fetchFeedback()
        )

        XCTAssertFalse(queue.contains { $0.targetID == claim.id })
    }

    func testReviewQueueTreatsApproveAndMattersAsResolved() throws {
        let harness = try makeHarness()
        let now = Date(timeIntervalSince1970: 2_700)
        let source = makeSource(id: "resolved-review-source", title: "Resolved review source", now: now)
        let approveClaim = ClaimRecord(
            id: "resolved-approve-claim",
            statement: "Approved review item should leave the queue",
            sourceRefs: [source.id],
            confidence: 0.36,
            uncertaintyReason: "Fixture",
            status: .suspect,
            createdAt: now
        )
        let mattersClaim = ClaimRecord(
            id: "resolved-matters-claim",
            statement: "Important review item should leave the queue",
            sourceRefs: [source.id],
            confidence: 0.38,
            uncertaintyReason: "Fixture",
            status: .suspect,
            createdAt: now.addingTimeInterval(1)
        )
        try harness.store.saveSource(source)
        try harness.store.saveClaim(approveClaim)
        try harness.store.saveClaim(mattersClaim)
        try harness.controlPlane.applyFeedback(FeedbackRecord(
            targetType: "claim",
            targetID: approveClaim.id,
            action: .approve,
            timestamp: now.addingTimeInterval(10)
        ))
        try harness.controlPlane.applyFeedback(FeedbackRecord(
            targetType: "claim",
            targetID: mattersClaim.id,
            action: .matters,
            timestamp: now.addingTimeInterval(11)
        ))

        let queue = ReviewQueueBuilder().build(
            claims: try harness.store.fetchClaims(),
            sources: try harness.store.fetchSources(),
            feedback: try harness.store.fetchFeedback()
        )

        XCTAssertFalse(queue.contains { $0.targetID == approveClaim.id })
        XCTAssertFalse(queue.contains { $0.targetID == mattersClaim.id })
    }

    func testAIMemoryImportPromptRequiresEvidenceAndImportableMarkdown() throws {
        let prompt = AIMemoryImportPrompt.markdown
        XCTAssertTrue(prompt.contains("# HIVE MEMORY SEED"))
        XCTAssertTrue(prompt.contains("Your job is NOT to write a conversational summary."))
        XCTAssertTrue(prompt.contains("Do not invent"))
        XCTAssertTrue(prompt.contains("\"confidence\": 0.0"))
        XCTAssertTrue(prompt.contains("Refused Inferences"))
        XCTAssertTrue(prompt.contains("IMPORTANT FOR HIVE INGESTION"))
    }

    func testAIMemorySeedParserReadsStructuredSeedSections() throws {
        let markdown = """
        # HIVE MEMORY SEED

        ## 1. Canonical Profile
        ```json
        {"identity":{"name":"Ari","role_or_roles":["builder"],"locations":[],"organizations":[],"high_confidence_descriptors":["local-first"]},"preferences":[{"claim":"User prefers local-first software.","confidence":0.92,"evidence_quote":"local-first"}],"constraints":[]}
        ```

        ## 2. Entities
        ```json
        [{"id":"hive","name":"Hive","type":"project","description":"Second brain app","confidence":0.94,"aliases":[],"evidence_quote":"Hive"}]
        ```

        ## 3. Confirmed Claims
        ```json
        [{"id":"building_hive","subject":"hive","predicate":"is","object":"being built as a second brain","confidence":0.91,"why_it_matters":"Core project memory","evidence_quote":"building Hive"}]
        ```

        ## 4. Unresolved Claims
        ```json
        [{"id":"business_model","claim":"Hive may become SaaS.","confidence":0.72,"why_uncertain":"Future plan","best_followup_question":"Is SaaS still the goal?","evidence_quote":"eventually SaaS"}]
        ```

        ## 5. Refused Inferences
        ```json
        [{"id":"sensitive","possible_inference":"Infer private health status","reason_to_refuse":"Sensitive and unsupported","evidence_quote":"health"}]
        ```

        ## 6. Projects
        ```json
        [{"id":"hive","name":"Hive","status":"active","summary":"Second brain app","goals":["compound knowledge"],"stack_or_tools":["SwiftUI"],"related_entities":["swiftui"],"confidence":0.96,"evidence_quote":"Hive"}]
        ```

        ## 7. Source Clusters
        ```json
        [{"id":"ux","label":"Hive UX","summary":"Design requirements","primary_entities":["hive"],"primary_projects":["hive"],"signal_level":"high","why_this_cluster_matters":"Defines first memory web"}]
        ```

        ## 8. Relationship Edges
        ```json
        [{"source":"hive","target":"swiftui","relationship":"uses","confidence":0.88,"evidence_quote":"SwiftUI"}]
        ```

        ## 9. Wiki Starters
        ```json
        [{"title":"Hive","type":"project","starter_summary":"Hive is an active second brain project.","linked_entities":["hive"],"open_questions":["What is the first beta scope?"]}]
        ```

        ## 10. One-Question Priorities
        ```json
        [{"question":"What should Hive remember first?","unlocks":"Initial graph scope"}]
        ```
        """

        let seed = try XCTUnwrap(AIMemorySeedParser().parse(markdown))
        XCTAssertEqual(seed.canonicalProfile?.identity.name, "Ari")
        XCTAssertEqual(seed.entities.first?.id, "hive")
        XCTAssertEqual(seed.confirmedClaims.first?.confidence, 0.91)
        XCTAssertEqual(seed.unresolvedClaims.first?.confidence, 0.72)
        XCTAssertEqual(seed.refusedInferences.first?.reasonToRefuse, "Sensitive and unsupported")
        XCTAssertEqual(seed.projects.first?.stackOrTools, ["SwiftUI"])
        XCTAssertEqual(seed.sourceClusters.first?.signalLevel, "high")
        XCTAssertEqual(seed.relationshipEdges.first?.relationship, "uses")
        XCTAssertEqual(seed.wikiStarters.first?.title, "Hive")
        XCTAssertEqual(seed.oneQuestionPriorities.first?.question, "What should Hive remember first?")
    }

    func testAIMemorySeedParserAcceptsStandaloneQuestionPriorityJSON() throws {
        let payload = """
        [
          {
            "question": "Is Hive an app you are building yourself, or a third-party product you are importing memory into?",
            "unlocks": "Determines whether Hive is a project node in the graph or the graph itself."
          }
        ]
        """

        let seed = try XCTUnwrap(AIMemorySeedParser().parse(payload))
        XCTAssertEqual(seed.oneQuestionPriorities.count, 1)
        XCTAssertEqual(seed.oneQuestionPriorities[0].question, "Is Hive an app you are building yourself, or a third-party product you are importing memory into?")
        XCTAssertTrue(seed.entities.isEmpty)
        XCTAssertTrue(seed.confirmedClaims.isEmpty)
    }

    func testGraphBuildExcludesSourceNodesAndBareLinkMemory() throws {
        let now = Date()
        var browser = makeSource(id: "browser-source", title: "github.com", now: now)
        browser.kind = .browserHistory
        browser.connector = "browser-history-entry"
        let seedSource = makeSource(id: "seed-source", title: "Hive Memory Seed", now: now)
        let durableClaim = ClaimRecord(
            id: "durable-claim",
            statement: "The user wants Hive to contain thoughts rather than links.",
            claimType: "memory-seed-confirmed",
            sourceRefs: [seedSource.id],
            confidence: 0.96,
            uncertaintyReason: "Fixture"
        )
        let linkClaim = ClaimRecord(
            id: "link-claim",
            statement: "https://github.com/example",
            claimType: "browser-signal",
            sourceRefs: [browser.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture"
        )
        let durableEntity = EntityRecord(
            id: "entity-preferences",
            name: "Preferences",
            entityType: "topic",
            sourceRefs: [seedSource.id],
            confidence: 0.96
        )
        let linkEntity = EntityRecord(
            id: "entity-domain",
            name: "github.com",
            entityType: "topic",
            sourceRefs: [browser.id],
            confidence: 0.96
        )

        let graph = GraphEngine().buildGraph(
            sources: [browser, seedSource],
            claims: [durableClaim, linkClaim],
            entities: [durableEntity, linkEntity],
            relationships: []
        )

        XCTAssertFalse(graph.nodes.contains { $0.kind == .source })
        XCTAssertFalse(graph.nodes.contains { $0.title.localizedCaseInsensitiveContains("github.com") })
        XCTAssertTrue(graph.nodes.contains { $0.id == durableClaim.id })
        XCTAssertTrue(graph.nodes.contains { $0.id == durableEntity.id })
    }

    func testGraphBuildAssignsPersonalityMemoryLayers() throws {
        let source = makeSource(id: "memory-source", title: "Memory Seed", now: Date())
        let claims = [
            ClaimRecord(
                id: "latex-detail",
                statement: "The user prefers LaTeX homework solutions with only single-dollar math delimiters.",
                claimType: "memory-seed-confirmed",
                sourceRefs: [source.id],
                confidence: 0.93,
                uncertaintyReason: "Fixture"
            ),
            ClaimRecord(
                id: "ucla-important",
                statement: "The user is at UCLA studying mathematics.",
                claimType: "memory-seed-confirmed",
                sourceRefs: [source.id],
                confidence: 0.96,
                uncertaintyReason: "Fixture"
            ),
            ClaimRecord(
                id: "iq-defining",
                statement: "The user has certified IQ 164 and is an Indian male.",
                claimType: "memory-seed-confirmed",
                sourceRefs: [source.id],
                confidence: 0.98,
                uncertaintyReason: "Fixture"
            )
        ]
        let entity = EntityRecord(
            id: "current-classes",
            name: "Current Classes",
            entityType: "topic",
            sourceRefs: [source.id],
            confidence: 0.86
        )

        let graph = GraphEngine().buildGraph(
            sources: [source],
            claims: claims,
            entities: [entity],
            relationships: []
        )
        let layers = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0.memoryLayer) })

        XCTAssertEqual(layers["latex-detail"], .detail)
        XCTAssertEqual(layers["ucla-important"], .importantTrait)
        XCTAssertEqual(layers["iq-defining"], .definingTrait)
        XCTAssertEqual(layers["current-classes"], .connector)
    }

    func testGraphNodeRecordDecodesLegacyPayloadWithDefaultLayer() throws {
        let payload = Data("""
        {
          "id": "legacy-node",
          "title": "Legacy memory",
          "kind": "claim",
          "confidence": 0.8,
          "sourceRefs": [],
          "x": 0,
          "y": 0
        }
        """.utf8)

        let node = try JSONDecoder().decode(GraphNodeRecord.self, from: payload)

        XCTAssertEqual(node.memoryLayer, .detail)
        XCTAssertNil(node.semanticColorKey)
        XCTAssertNil(node.memoryLayerOverrideSource)
    }

    func testWikiArticlesHideRawInputProvenanceFromMarkdown() throws {
        let source = makeSource(id: "article-source", title: "github.com", now: Date())
        let claim = ClaimRecord(
            id: "hive-claim",
            statement: "Hive is a local-first second brain app that turns rough notes into durable user knowledge.",
            claimType: "memory-seed-confirmed",
            subjectEntityID: "hive-entity",
            sourceRefs: [source.id],
            confidence: 0.96,
            uncertaintyReason: "Fixture"
        )
        let entity = EntityRecord(
            id: "hive-entity",
            name: "Hive",
            entityType: "project",
            sourceRefs: [source.id],
            confidence: 0.96
        )

        let pages = WikiCompiler().compile(
            sources: [source],
            claims: [claim],
            entities: [entity],
            relationships: [],
            feedback: [],
            auditEvents: []
        )
        let article = try XCTUnwrap(pages.first { $0.title == "Hive" })
        let lowerMarkdown = article.markdown.lowercased()

        XCTAssertTrue(article.sourceRefs.contains(source.id))
        XCTAssertTrue(article.claimRefs.contains(claim.id))
        XCTAssertTrue(article.markdown.contains("# Hive"))
        XCTAssertTrue(article.markdown.contains("## Claims"))
        XCTAssertFalse(article.markdown.contains("local knowledge base"))
        XCTAssertFalse(lowerMarkdown.contains("raw inputs"))
        XCTAssertFalse(lowerMarkdown.contains("evidence capsules"))
        XCTAssertFalse(lowerMarkdown.contains("provenance"))
        XCTAssertFalse(lowerMarkdown.contains("source_count"))
        XCTAssertFalse(lowerMarkdown.contains("claim_count"))
        XCTAssertFalse(lowerMarkdown.contains("github.com"))
        XCTAssertFalse(lowerMarkdown.contains("http://"))
        XCTAssertFalse(lowerMarkdown.contains("https://"))
    }

    func testWikiCompilerPrefersMergingIntoExistingArticle() throws {
        let source = makeSource(id: "article-source", title: "Article seed", now: Date())
        let previous = WikiPageRecord(
            id: "existing-hive-page",
            title: "Hive",
            markdown: "# Hive\n\nHive is an existing article.\n",
            sourceRefs: [],
            claimRefs: ["old-claim"],
            kind: .project,
            summary: "Existing Hive article.",
            revision: 1
        )
        let claim = ClaimRecord(
            id: "new-hive-claim",
            statement: "Hive is the user's local-first memory system.",
            claimType: "memory-seed-confirmed",
            subjectEntityID: "hive-entity",
            sourceRefs: [source.id],
            confidence: 0.94,
            uncertaintyReason: "Fixture"
        )
        let entity = EntityRecord(
            id: "hive-entity",
            name: "Hive",
            entityType: "project",
            sourceRefs: [source.id],
            confidence: 0.94
        )

        let pages = WikiCompiler().compile(
            sources: [source],
            claims: [claim],
            entities: [entity],
            relationships: [],
            feedback: [],
            auditEvents: [],
            previousPages: [previous]
        )
        let article = try XCTUnwrap(pages.first { $0.id == previous.id })

        XCTAssertEqual(article.title, "Hive")
        XCTAssertTrue(article.claimRefs.contains(claim.id))
        XCTAssertFalse(pages.contains { $0.id == "entity-hive-entity" })
        XCTAssertGreaterThan(article.revision, previous.revision)
    }

    func testWikiCompilerSuppressesStandaloneBareHardwareTopicPages() throws {
        let source = makeSource(id: "battery-source", title: "Mac charging note", now: Date())
        let claim = ClaimRecord(
            id: "battery-claim",
            statement: "The user uses AlDente to cap MacBook charge and is concerned about battery health and cycle count.",
            claimType: "memory-seed-confirmed",
            subjectEntityID: "aldente",
            sourceRefs: [source.id],
            confidence: 0.94,
            uncertaintyReason: "Fixture"
        )
        let aldente = EntityRecord(
            id: "aldente",
            name: "AlDente",
            entityType: "topic",
            sourceRefs: [source.id],
            confidence: 0.95
        )
        let battery = EntityRecord(
            id: "battery-health",
            name: "Battery Health",
            entityType: "topic",
            sourceRefs: [source.id],
            confidence: 0.9
        )

        let pages = WikiCompiler().compile(
            sources: [source],
            claims: [claim],
            entities: [aldente, battery],
            relationships: [],
            feedback: [],
            auditEvents: []
        )
        let article = try XCTUnwrap(pages.first { $0.title == "AlDente" })
        let index = try XCTUnwrap(pages.first { $0.kind == .index })

        XCTAssertTrue(article.claimRefs.contains(claim.id))
        XCTAssertFalse(pages.contains { $0.title == "Battery Health" })
        XCTAssertFalse(index.markdown.contains("[[Battery Health]]"))
    }

    func testWikiCompilerRenamesGeneratedArticleToCanonicalEntityTitle() throws {
        let source = makeSource(id: "ucla-source", title: "UCLA seed", now: Date())
        let previous = WikiPageRecord(
            id: "entity-ucla",
            title: "UCLA",
            markdown: "# UCLA\n\nUCLA is an existing generated article.\n",
            sourceRefs: [source.id],
            claimRefs: ["claim-ucla"],
            kind: .topic,
            summary: "Existing generated article.",
            revision: 1
        )
        let claim = ClaimRecord(
            id: "claim-ucla",
            statement: "The user is a student at UCLA.",
            claimType: "supporting-detail",
            subjectEntityID: "ucla",
            sourceRefs: [source.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture"
        )
        let entity = EntityRecord(
            id: "ucla",
            name: "UCLA Student",
            entityType: "topic",
            aliases: ["UCLA"],
            sourceRefs: [source.id],
            confidence: 0.98
        )

        let pages = WikiCompiler().compile(
            sources: [source],
            claims: [claim],
            entities: [entity],
            relationships: [],
            feedback: [],
            auditEvents: [],
            previousPages: [previous]
        )
        let article = try XCTUnwrap(pages.first { $0.id == previous.id })

        XCTAssertEqual(article.title, "UCLA Student")
        XCTAssertTrue(article.markdown.contains("# UCLA Student"))
        XCTAssertTrue(article.claimRefs.contains(claim.id))
    }

    func testMemorySeedImporterCreatesCategoryHubsAndConfirmedClaims() throws {
        let harness = try makeHarness()
        let source = makeSource(id: "memory-seed-source", title: "Hive Memory Seed", now: Date())
        try harness.store.saveSource(source)
        let records = [
            MemorySeedRecord(
                id: "pref-one",
                observedAt: Date(timeIntervalSince1970: 1_000),
                category: "Preferences",
                statement: "The user prefers concise implementation updates.",
                confidence: 0.94,
                sourceLabel: "Fixture",
                relatedProjectSlugs: ["hive"]
            ),
            MemorySeedRecord(
                id: "pref-two",
                observedAt: Date(timeIntervalSince1970: 2_000),
                category: "Preferences",
                statement: "The user wants Hive to avoid source-link nodes.",
                confidence: 0.97,
                sourceLabel: "Fixture",
                relatedProjectSlugs: ["hive"]
            )
        ]

        _ = try MemorySeedImporter(store: harness.store).persist(records: records, source: source)
        let graph = try harness.loop.updateDerivedKnowledge()
        let claims = try harness.store.fetchClaims()
        let pages = try harness.store.fetchWikiPages()

        XCTAssertEqual(claims.filter { $0.claimType == "memory-seed-confirmed" }.count, 2)
        XCTAssertTrue(try harness.store.fetchEntities().contains { $0.name == "Preferences" })
        XCTAssertTrue(graph.edges.contains { $0.fromID == "memory-seed-entity-preferences" && $0.predicate == .supports })
        XCTAssertFalse(pages.contains { $0.kind == .source || $0.title.hasPrefix("Source - ") })
        let hivePage = try XCTUnwrap(pages.first { $0.title == "Hive" })
        XCTAssertLessThan(hivePage.claimRefs.count, claims.count)
    }

    func testMemorySeedWikiSkipsLooseZeroClaimTopicPages() throws {
        let harness = try makeHarness()
        let source = makeSource(id: "memory-seed-source", title: "Hive Memory Seed", now: Date())
        try harness.store.saveSource(source)
        let records = [
            MemorySeedRecord(
                id: "local-computer",
                observedAt: Date(timeIntervalSince1970: 1_000),
                category: "Projects",
                statement: "The user wants local-computer browser automation scripts to use Google Chrome for testing.",
                confidence: 0.94,
                sourceLabel: "Fixture",
                relatedProjectSlugs: ["local-computer"]
            ),
            MemorySeedRecord(
                id: "loose-build-topic",
                observedAt: Date(timeIntervalSince1970: 2_000),
                category: "Projects",
                statement: "The user is having trouble getting Cabin to build the 3D and 2D portions properly.",
                confidence: 0.95,
                sourceLabel: "Fixture",
                relatedEntitySlugs: ["2d-build", "3d-build"]
            )
        ]

        _ = try MemorySeedImporter(store: harness.store).persist(records: records, source: source)
        _ = try harness.loop.updateDerivedKnowledge()
        let pages = try harness.store.fetchWikiPages()

        let localComputerPage = try XCTUnwrap(pages.first { $0.title == "Local Computer" })
        XCTAssertEqual(localComputerPage.claimRefs.count, 1)
        XCTAssertFalse(pages.contains { $0.title == "2d Build" || $0.title == "3d Build" })
        XCTAssertFalse(pages.contains { $0.summary.contains("0 linked claims") })
    }

    func testDerivedMemoryResetPreservesRawSources() throws {
        let harness = try makeHarness()
        let source = makeSource(id: "raw-source", title: "Raw input", now: Date())
        try harness.store.saveSource(source)
        try harness.store.saveRawBlob(RawBlobRecord(
            sourceID: source.id,
            contentAddress: "blob",
            localPath: "/tmp/blob",
            mimeType: "text/plain",
            sizeBytes: 4,
            sha256: "blob"
        ))
        try harness.store.saveClaim(ClaimRecord(id: "claim", statement: "Derived memory", sourceRefs: [source.id], confidence: 0.9, uncertaintyReason: "Fixture"))
        try harness.store.saveEntity(EntityRecord(id: "entity", name: "Derived Entity", sourceRefs: [source.id], confidence: 0.9))
        try harness.store.saveWikiPage(WikiPageRecord(id: "page", title: "Derived Page", markdown: "Derived", sourceRefs: [source.id], claimRefs: ["claim"]))

        _ = try harness.store.resetDerivedMemoryKeepingRawSources(reason: "Fixture")

        XCTAssertEqual(try harness.store.fetchSources().map(\.id), [source.id])
        XCTAssertEqual(try harness.store.fetchRawBlobs(sourceID: source.id).count, 1)
        XCTAssertTrue(try harness.store.fetchClaims(includeRetracted: true).isEmpty)
        XCTAssertTrue(try harness.store.fetchEntities().isEmpty)
        XCTAssertTrue(try harness.store.fetchWikiPages().isEmpty)
    }

    func testMemoryCompilerKeepsBrowserHistoryRawUntilSynthesis() throws {
        var source = makeSource(id: "shorts-source", title: "YouTube Shorts", now: Date())
        source.kind = .browserHistory
        source.uri = "browser-history://Chrome/Default/youtube.com/shorts/example"
        let claim = ClaimRecord(
            id: "shorts-claim",
            statement: "YouTube Shorts browsing appeared.",
            claimType: "browser-observation",
            sourceRefs: [source.id],
            confidence: 0.94,
            uncertaintyReason: "Fixture"
        )

        let decision = MemoryCompiler().evaluate(
            source: source,
            extractedClaims: [claim],
            existingClaims: [],
            existingEntities: []
        )

        XCTAssertEqual(decision.kind, .ignore)
        XCTAssertTrue(decision.reason.contains("95%"))
    }

    func testWikiOverviewUsesReviewQueueForOpenQuestions() throws {
        let harness = try makeHarness()
        let now = Date(timeIntervalSince1970: 3_000)
        let source = makeSource(id: "wiki-review-source", title: "Wiki review source", now: now)
        let claim = ClaimRecord(
            id: "wiki-review-claim",
            statement: "Wiki review claim should be revisited",
            sourceRefs: [source.id],
            confidence: 0.62,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        try harness.store.saveSource(source)
        try harness.store.saveClaim(claim)
        try harness.store.saveFeedback(FeedbackRecord(
            id: "wiki-review-feedback",
            targetType: "claim",
            targetID: claim.id,
            action: .askLater,
            timestamp: now.addingTimeInterval(20)
        ))

        _ = try harness.loop.updateDerivedKnowledge()
        let overview = try XCTUnwrap(try harness.store.fetchWikiPages().first)

        XCTAssertTrue(overview.markdown.contains("## Open questions\n- 1 item needs confirmation."))
    }

    func testSaveClaimMergesCanonicalDuplicateStatements() throws {
        let harness = try makeHarness()
        let now = Date()
        try harness.store.saveClaim(ClaimRecord(
            id: "claim-atlas-one",
            statement: "Project Atlas connects Markov graph analysis",
            claimType: "source-observation",
            sourceRefs: ["source-a"],
            sourceSpanRefs: ["span-a"],
            confidence: 0.48,
            uncertaintyReason: "Fixture",
            createdAt: now
        ))
        try harness.store.saveClaim(ClaimRecord(
            id: "claim-atlas-two",
            statement: "Project Atlas connects Markov graph analysis.",
            claimType: "source-observation",
            sourceRefs: ["source-b"],
            sourceSpanRefs: ["span-b"],
            confidence: 0.74,
            uncertaintyReason: "Better fixture",
            createdAt: now.addingTimeInterval(30)
        ))

        let claims = try harness.store.fetchClaims()
        let merged = try XCTUnwrap(claims.first)

        XCTAssertEqual(claims.count, 1)
        XCTAssertEqual(merged.id, "claim-atlas-one")
        XCTAssertEqual(Set(merged.sourceRefs), Set(["source-a", "source-b"]))
        XCTAssertEqual(Set(merged.sourceSpanRefs), Set(["span-a", "span-b"]))
        XCTAssertEqual(merged.confidence, 0.74)
        XCTAssertEqual(merged.uncertaintyReason, "Better fixture")
        XCTAssertTrue(merged.correctionLineage.contains("claim-atlas-two"))
    }

    func testDedupeClaimsMergesLegacyDuplicates() throws {
        let harness = try makeHarness()
        let now = Date()
        try insertClaimBypassingStoreMerge(ClaimRecord(
            id: "legacy-claim-one",
            statement: "Hive keeps a source-linked claim",
            claimType: "source-observation",
            sourceRefs: ["source-a"],
            sourceSpanRefs: ["span-a"],
            confidence: 0.5,
            uncertaintyReason: "Fixture",
            createdAt: now
        ), databaseURL: harness.paths.database)
        try insertClaimBypassingStoreMerge(ClaimRecord(
            id: "legacy-claim-two",
            statement: "Hive keeps a source linked claim",
            claimType: "source-observation",
            sourceRefs: ["source-b"],
            sourceSpanRefs: ["span-b"],
            confidence: 0.8,
            uncertaintyReason: "Fixture",
            createdAt: now.addingTimeInterval(30)
        ), databaseURL: harness.paths.database)

        let removed = try harness.store.dedupeClaims()
        let claims = try harness.store.fetchClaims()
        let merged = try XCTUnwrap(claims.first)

        XCTAssertEqual(removed, 1)
        XCTAssertEqual(claims.count, 1)
        XCTAssertEqual(merged.id, "legacy-claim-one")
        XCTAssertEqual(Set(merged.sourceRefs), Set(["source-a", "source-b"]))
        XCTAssertEqual(Set(merged.sourceSpanRefs), Set(["span-a", "span-b"]))
        XCTAssertEqual(merged.confidence, 0.8)
    }

    func testClaimCorrectionCreatesReplacementWithLineage() throws {
        let harness = try makeHarness()
        let source = makeSource(id: "correction-source", title: "Correction source", now: Date())
        try harness.store.saveSource(source)
        let original = ClaimRecord(
            id: "original-claim",
            statement: "Original claim needs correction",
            sourceRefs: [source.id],
            sourceSpanRefs: ["span-1"],
            confidence: 0.42,
            uncertaintyReason: "Fixture"
        )
        try harness.store.saveClaim(original)

        let replacement = try harness.controlPlane.replaceClaimWithCorrection(
            id: original.id,
            statement: "Corrected claim is user supplied"
        )

        let updatedOriginal = try XCTUnwrap(try harness.store.fetchClaim(id: original.id))
        let claims = try harness.store.fetchClaims(includeRetracted: true)
        XCTAssertEqual(updatedOriginal.status, .retracted)
        XCTAssertEqual(replacement.status, .userCorrected)
        XCTAssertEqual(replacement.createdBy, "user")
        XCTAssertEqual(replacement.sourceRefs, original.sourceRefs)
        XCTAssertEqual(replacement.sourceSpanRefs, original.sourceSpanRefs)
        XCTAssertTrue(replacement.correctionLineage.contains(original.id))
        XCTAssertTrue(claims.contains { $0.id == replacement.id })
        XCTAssertTrue(try harness.store.fetchFeedback().contains { $0.action == .edit && $0.targetID == original.id })
    }

    func testMaximumComputeSelectsStrongerModelAndMoreWorkers() throws {
        let profile = RuntimeProfile(
            chipName: "MacStudio",
            physicalMemoryBytes: 32 * 1_073_741_824,
            processorCount: 12,
            thermalState: .nominal,
            powerState: .pluggedIn,
            lowPowerModeEnabled: false,
            foregroundUserActive: true
        )
        let policy = RuntimePolicy()
        let decision = policy.decision(for: .summarization, profile: profile, manual: false, computeMode: .maximum)

        XCTAssertTrue(decision.allowed)
        XCTAssertEqual(decision.selectedModelID, "mlx-qwen2-5-7b-4bit")
        XCTAssertEqual(decision.maxConcurrentJobs, 11)
        XCTAssertTrue(decision.reason.contains("Maximum local compute"))
    }

    func testModelCatalogDetectsDroppedLocalModelFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HiveModelCatalog-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        try Data().write(to: root.appendingPathComponent("mlx-qwen3-4b-4bit.safetensors"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("mlx-qwen3-embedding-0.6b", isDirectory: true), withIntermediateDirectories: true)

        let catalog = ModelCatalog().resolvingInstalledModels(in: root)

        XCTAssertTrue(catalog.capabilities.first { $0.id == "mlx-qwen3-4b-4bit" }?.installed == true)
        XCTAssertTrue(catalog.capabilities.first { $0.id == "mlx-qwen3-embedding-0.6b" }?.installed == true)
        XCTAssertFalse(catalog.capabilities.first { $0.id == "mlx-qwen2-5-7b-4bit" }?.installed == true)
    }

    func testDailySchedulerRunsMissedMidnightOnNextWake() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let scheduler = DailyScheduler(calendar: calendar)
        let formatter = ISO8601DateFormatter()
        let lastRun = formatter.date(from: "2026-05-24T00:00:05Z")!
        let now = formatter.date(from: "2026-05-25T09:15:00Z")!

        XCTAssertTrue(scheduler.shouldRunMissedSchedule(lastRun: lastRun, now: now))
        XCTAssertEqual(scheduler.nextRun(after: now), formatter.date(from: "2026-05-26T00:00:00Z")!)
    }

    func testHiveMaintenanceScheduleDefaultsToNightlyMidnightAndCanChangeHour() throws {
        let suiteName = "HiveMaintenanceScheduleTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let defaultSchedule = HiveMaintenanceSchedule.load(defaults: defaults)
        XCTAssertTrue(defaultSchedule.enabled)
        XCTAssertEqual(defaultSchedule.hour, 0)
        XCTAssertEqual(defaultSchedule.minute, 0)

        HiveMaintenanceSchedule(enabled: true, hour: 2, minute: 0).save(defaults: defaults)
        let changed = HiveMaintenanceSchedule.load(defaults: defaults)
        XCTAssertEqual(changed.hour, 2)
        XCTAssertTrue(changed.shouldRun(lastRun: nil, now: Date(timeIntervalSince1970: 1_000)))
    }

    func testBackgroundWorkerMonitorReadsLaunchAgentAndLogs() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HiveWorkerMonitor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let helper = "/Applications/Hive.app/Contents/Library/Helpers/HiveDaemon"
        let launchAgents = root.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let logs = root.appendingPathComponent("Library/Logs/Hive", isDirectory: true)
        try FileManager.default.createDirectory(at: launchAgents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>com.hive.daemon</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(helper)</string>
          </array>
        </dict>
        </plist>
        """.write(to: launchAgents.appendingPathComponent("com.hive.daemon.plist"), atomically: true, encoding: .utf8)
        try "older\nHiveDaemon complete: purged=0 nodes=9 edges=49\n".write(to: logs.appendingPathComponent("daemon.out.log"), atomically: true, encoding: .utf8)
        try "\n".write(to: logs.appendingPathComponent("daemon.err.log"), atomically: true, encoding: .utf8)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let status = BackgroundWorkerMonitor(scheduler: DailyScheduler(calendar: calendar), homeDirectory: root)
            .status(helperPath: helper, now: ISO8601DateFormatter().date(from: "2026-05-25T18:00:00Z")!)

        XCTAssertTrue(status.isInstalled)
        XCTAssertTrue(status.plistTargetsCurrentHelper)
        XCTAssertEqual(status.installState, "Installed")
        XCTAssertEqual(status.lastOutputLine, "HiveDaemon complete: purged=0 nodes=9 edges=49")
        XCTAssertNil(status.lastErrorLine)
    }

    func testMarkovAnalysisCreatesLoopsHamiltonianPathsAndStructuredEdges() throws {
        let fixture = makeMarkovFixture()
        let analyzer = MarkovGraphAnalyzer()
        let analysis = analyzer.analyze(sources: fixture.sources, claims: fixture.claims, entities: fixture.entities)

        XCTAssertFalse(analysis.transitions.isEmpty)
        let outgoing = Dictionary(grouping: analysis.transitions) { $0.fromID }
        for transitions in outgoing.values {
            XCTAssertEqual(transitions.map(\.probability).reduce(0, +), 1, accuracy: 0.0001)
        }
        XCTAssertFalse(analysis.loops.isEmpty)
        XCTAssertFalse(analysis.hamiltonianPaths.isEmpty)
        XCTAssertFalse(analysis.stationaryScores.isEmpty)

        let relationships = GraphEngine().deriveRelationships(
            sources: fixture.sources,
            claims: fixture.claims,
            entities: fixture.entities,
            existing: []
        )
        XCTAssertTrue(relationships.contains { $0.predicate == .markovTransition })
        XCTAssertTrue(relationships.contains { $0.predicate == .markovLoop })
        XCTAssertTrue(relationships.contains { $0.predicate == .hamiltonianPath })

        let insights = analyzer.deriveInsightClaims(
            sources: fixture.sources,
            claims: fixture.claims,
            entities: fixture.entities,
            relationships: relationships
        )
        XCTAssertFalse(insights.isEmpty)
        XCTAssertTrue(insights.allSatisfy { $0.claimType == "graph-insight" })
        XCTAssertTrue(insights.contains { $0.statement.contains("loop") || $0.statement.contains("bridge") || $0.statement.contains("centrality") })
    }

    func testMarkovAnalysisDetectsLongerLocalLoops() throws {
        let claims = [
            ClaimRecord(id: "claim-ab", statement: "Aurora stabilizes Boreal", sourceRefs: ["source-a", "source-b"], confidence: 0.86, uncertaintyReason: "Fixture"),
            ClaimRecord(id: "claim-bc", statement: "Boreal calibrates Cobalt", sourceRefs: ["source-b", "source-c"], confidence: 0.86, uncertaintyReason: "Fixture"),
            ClaimRecord(id: "claim-cd", statement: "Cobalt sequences Dorian", sourceRefs: ["source-c", "source-d"], confidence: 0.86, uncertaintyReason: "Fixture"),
            ClaimRecord(id: "claim-da", statement: "Dorian refreshes Aurora", sourceRefs: ["source-d", "source-a"], confidence: 0.86, uncertaintyReason: "Fixture")
        ]

        let analysis = MarkovGraphAnalyzer().analyze(sources: [], claims: claims, entities: [])

        XCTAssertTrue(analysis.loops.contains { $0.nodeIDs.count >= 4 })
        XCTAssertTrue(analysis.loops.contains { $0.reason.contains("4-node Markov loop") })
    }

    func testHamiltonianFallbackDoesNotCreateDisconnectedPathEdges() throws {
        let claims = [
            ClaimRecord(id: "center", statement: "Nexus anchor", sourceRefs: ["a", "b", "c", "d"], confidence: 0.9, uncertaintyReason: "Fixture"),
            ClaimRecord(id: "leaf-a", statement: "Aurora item", sourceRefs: ["a"], confidence: 0.9, uncertaintyReason: "Fixture"),
            ClaimRecord(id: "leaf-b", statement: "Boreal item", sourceRefs: ["b"], confidence: 0.9, uncertaintyReason: "Fixture"),
            ClaimRecord(id: "leaf-c", statement: "Cobalt item", sourceRefs: ["c"], confidence: 0.9, uncertaintyReason: "Fixture"),
            ClaimRecord(id: "leaf-d", statement: "Dorian item", sourceRefs: ["d"], confidence: 0.9, uncertaintyReason: "Fixture")
        ]

        let relationships = GraphEngine().deriveRelationships(sources: [], claims: claims, entities: [], existing: [])
        let semanticKeys = relationships.map { "\($0.subjectID)|\($0.predicate.rawValue)|\($0.objectID)" }

        XCTAssertFalse(relationships.contains { $0.predicate == .hamiltonianPath })
        XCTAssertEqual(semanticKeys.count, Set(semanticKeys).count)
    }

    func testGraphFilterRepositionsScopedResults() throws {
        let graph = HiveGraphSnapshot(
            nodes: [
                GraphNodeRecord(id: "a", title: "Markov Alpha", kind: .topic, confidence: 0.8, sourceRefs: [], x: 10_000, y: 10_000),
                GraphNodeRecord(id: "b", title: "Markov Beta", kind: .topic, confidence: 0.8, sourceRefs: [], x: 10_200, y: 10_200),
                GraphNodeRecord(id: "c", title: "Other", kind: .topic, confidence: 0.8, sourceRefs: [], x: -10_000, y: -10_000)
            ],
            edges: [
                GraphEdgeRecord(fromID: "a", toID: "b", predicate: .related, strength: 0.8, confidence: 0.8, evidenceCount: 1)
            ]
        )

        let filtered = GraphEngine().filter(graph, using: GraphFilter(query: "Markov"))
        XCTAssertEqual(filtered.nodes.count, 2)
        XCTAssertEqual(filtered.edges.count, 1)
        XCTAssertTrue(filtered.nodes.allSatisfy { abs($0.x) < 1_000 && abs($0.y) < 1_000 })
    }

    func testGraphSearchIncludesOneHopContext() throws {
        let graph = HiveGraphSnapshot(
            nodes: [
                GraphNodeRecord(id: "match", title: "Markov Alpha", kind: .topic, confidence: 0.8, sourceRefs: []),
                GraphNodeRecord(id: "neighbor", title: "Design Neighbor", kind: .topic, confidence: 0.8, sourceRefs: []),
                GraphNodeRecord(id: "far", title: "Far Node", kind: .topic, confidence: 0.8, sourceRefs: [])
            ],
            edges: [
                GraphEdgeRecord(fromID: "match", toID: "neighbor", predicate: .related, strength: 0.7, confidence: 0.8, evidenceCount: 1),
                GraphEdgeRecord(fromID: "neighbor", toID: "far", predicate: .related, strength: 0.7, confidence: 0.8, evidenceCount: 1)
            ]
        )

        let filtered = GraphEngine().filter(graph, using: GraphFilter(query: "Markov"))

        XCTAssertEqual(Set(filtered.nodes.map(\.id)), Set(["match", "neighbor"]))
        XCTAssertEqual(filtered.edges.count, 1)
    }

    func testGraphFilterCapsVisibleNodesAndPreservesQueryMatch() throws {
        var nodes = [
            GraphNodeRecord(id: "hub", title: "Central Project", kind: .project, confidence: 0.9, sourceRefs: []),
            GraphNodeRecord(id: "needle", title: "Needle Topic", kind: .topic, confidence: 0.4, sourceRefs: [])
        ]
        nodes.append(contentsOf: (0..<20).map { index in
            GraphNodeRecord(id: "leaf-\(index)", title: "Leaf \(index)", kind: .claim, confidence: 0.7, sourceRefs: [])
        })
        var edges = (0..<20).map { index in
            GraphEdgeRecord(fromID: "hub", toID: "leaf-\(index)", predicate: .related, strength: 0.7, confidence: 0.7, evidenceCount: 1)
        }
        edges.append(GraphEdgeRecord(fromID: "needle", toID: "leaf-0", predicate: .related, strength: 0.7, confidence: 0.7, evidenceCount: 1))
        let graph = HiveGraphSnapshot(nodes: nodes, edges: edges)

        let capped = GraphEngine().filter(graph, using: GraphFilter(maxVisibleNodes: 5))
        let searched = GraphEngine().filter(graph, using: GraphFilter(query: "Needle", maxVisibleNodes: 1))

        XCTAssertLessThanOrEqual(capped.nodes.count, 5)
        XCTAssertTrue(capped.nodes.contains { $0.id == "hub" })
        XCTAssertEqual(searched.nodes.map(\.id), ["needle"])
    }

    func testGraphFilterAppliesDateBounds() throws {
        let old = Date(timeIntervalSince1970: 100)
        let current = Date(timeIntervalSince1970: 1_000)
        let graph = HiveGraphSnapshot(
            nodes: [
                GraphNodeRecord(id: "old", title: "Old", kind: .source, confidence: 0.8, sourceRefs: [], timestamp: old),
                GraphNodeRecord(id: "current", title: "Current", kind: .source, confidence: 0.8, sourceRefs: [], timestamp: current),
                GraphNodeRecord(id: "undated", title: "Undated", kind: .source, confidence: 0.8, sourceRefs: [])
            ],
            edges: [
                GraphEdgeRecord(fromID: "old", toID: "current", predicate: .related, strength: 0.7, confidence: 0.8, evidenceCount: 1),
                GraphEdgeRecord(fromID: "current", toID: "undated", predicate: .related, strength: 0.7, confidence: 0.8, evidenceCount: 1)
            ]
        )

        let filtered = GraphEngine().filter(graph, using: GraphFilter(startDate: Date(timeIntervalSince1970: 900)))

        XCTAssertEqual(filtered.nodes.map(\.id), ["current"])
        XCTAssertTrue(filtered.edges.isEmpty)
    }

    func testLargeGraphUsesBoundedFiniteLayout() throws {
        let nodes = (0..<1_000).map { index in
            GraphNodeRecord(
                id: "node-\(index)",
                title: "Node \(index)",
                kind: index % 7 == 0 ? .project : .claim,
                confidence: 0.8,
                sourceRefs: []
            )
        }
        let edges = (0..<2_000).map { index in
            GraphEdgeRecord(
                fromID: "node-\(index % 1_000)",
                toID: "node-\((index * 37 + 11) % 1_000)",
                predicate: .related,
                strength: 0.55,
                confidence: 0.75,
                evidenceCount: 1
            )
        }

        let positioned = GraphEngine().positioned(nodes: nodes, edges: edges)

        XCTAssertEqual(positioned.count, nodes.count)
        XCTAssertTrue(positioned.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        XCTAssertGreaterThan(Set(positioned.map { "\(Int($0.x))|\(Int($0.y))" }).count, 900)
    }

    func testTopicWebExpandsSeedThroughTwoHopContext() throws {
        let graph = HiveGraphSnapshot(
            nodes: [
                GraphNodeRecord(id: "seed", title: "Project Atlas", kind: .project, confidence: 0.8, sourceRefs: []),
                GraphNodeRecord(id: "claim", title: "Delivery depends on local graph evidence", kind: .claim, confidence: 0.8, sourceRefs: []),
                GraphNodeRecord(id: "source", title: "Research note", kind: .source, confidence: 0.8, sourceRefs: []),
                GraphNodeRecord(id: "far", title: "Unrelated", kind: .topic, confidence: 0.8, sourceRefs: [])
            ],
            edges: [
                GraphEdgeRecord(fromID: "seed", toID: "claim", predicate: .supports, strength: 0.8, confidence: 0.8, evidenceCount: 1),
                GraphEdgeRecord(fromID: "claim", toID: "source", predicate: .sourceOf, strength: 0.8, confidence: 0.8, evidenceCount: 1),
                GraphEdgeRecord(fromID: "source", toID: "far", predicate: .related, strength: 0.8, confidence: 0.8, evidenceCount: 1)
            ]
        )

        let scoped = GraphEngine().topicWeb(graph, seed: "Atlas", depth: 2)

        XCTAssertEqual(Set(scoped.nodes.map(\.id)), Set(["seed", "claim", "source"]))
        XCTAssertEqual(scoped.edges.count, 2)
    }

    func testTopicWebAppliesDateBounds() throws {
        let old = Date(timeIntervalSince1970: 100)
        let current = Date(timeIntervalSince1970: 1_000)
        let graph = HiveGraphSnapshot(
            nodes: [
                GraphNodeRecord(id: "old-seed", title: "Project Atlas", kind: .project, confidence: 0.8, sourceRefs: [], timestamp: old),
                GraphNodeRecord(id: "current-seed", title: "Project Atlas", kind: .project, confidence: 0.8, sourceRefs: [], timestamp: current),
                GraphNodeRecord(id: "current-claim", title: "Atlas has current evidence", kind: .claim, confidence: 0.8, sourceRefs: [], timestamp: current)
            ],
            edges: [
                GraphEdgeRecord(fromID: "old-seed", toID: "current-claim", predicate: .supports, strength: 0.8, confidence: 0.8, evidenceCount: 1),
                GraphEdgeRecord(fromID: "current-seed", toID: "current-claim", predicate: .supports, strength: 0.8, confidence: 0.8, evidenceCount: 1)
            ]
        )

        let scoped = GraphEngine().topicWeb(graph, seed: "Atlas", startDate: Date(timeIntervalSince1970: 900), depth: 1)

        XCTAssertEqual(Set(scoped.nodes.map(\.id)), Set(["current-seed", "current-claim"]))
        XCTAssertEqual(scoped.edges.count, 1)
    }

    func testExtractedTopicEntitiesBecomeTopicNodesAndFilterable() throws {
        let source = makeSource(id: "topic-source", title: "Topic source", now: Date())
        let entity = EntityRecord(
            id: "topic-entity",
            name: "Knowledge Graphs",
            entityType: "topic",
            sourceRefs: [source.id],
            confidence: 0.7
        )

        let graph = GraphEngine().buildGraph(sources: [source], claims: [], entities: [entity], relationships: [])
        let filtered = GraphEngine().filter(graph, using: GraphFilter(kinds: [.topic]))

        XCTAssertTrue(graph.nodes.contains { $0.id == entity.id && $0.kind == .topic })
        XCTAssertEqual(filtered.nodes.map(\.id), [entity.id])
    }

    func testSubjectEntityCreatesMemoryEdgeWithoutSourceNodes() throws {
        let now = Date()
        let sourceA = makeSource(id: "source-a", title: "Source A", now: now)
        let sourceB = makeSource(id: "source-b", title: "Source B", now: now)
        let entity = EntityRecord(
            id: "entity-shared",
            name: "Shared Topic",
            entityType: "topic",
            sourceRefs: [sourceA.id, sourceB.id],
            confidence: 0.75
        )
        let claim = ClaimRecord(
            id: "claim-shared",
            statement: "Shared Topic is a durable memory cluster.",
            claimType: "memory-seed-confirmed",
            subjectEntityID: entity.id,
            sourceRefs: [sourceA.id, sourceB.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture"
        )

        let relationships = GraphEngine().deriveRelationships(
            sources: [sourceA, sourceB],
            claims: [claim],
            entities: [entity],
            existing: []
        )

        XCTAssertFalse(relationships.contains { $0.subjectID == sourceA.id || $0.subjectID == sourceB.id })
        XCTAssertTrue(relationships.contains { $0.subjectID == entity.id && $0.objectID == claim.id && $0.predicate == .supports })
    }

    func testSaveEntityMergesCanonicalDuplicateNames() throws {
        let harness = try makeHarness()
        let now = Date()
        try harness.store.saveEntity(EntityRecord(
            id: "entity-project-atlas",
            name: "Project Atlas",
            entityType: "project",
            aliases: [],
            sourceRefs: ["source-a"],
            confidence: 0.55,
            createdAt: now
        ))
        try harness.store.saveEntity(EntityRecord(
            id: "entity-project-atlas-duplicate",
            name: "project-atlas",
            entityType: "project",
            aliases: ["Atlas"],
            sourceRefs: ["source-b"],
            confidence: 0.82,
            createdAt: now.addingTimeInterval(60)
        ))

        let entities = try harness.store.fetchEntities()
        let merged = try XCTUnwrap(entities.first)

        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(merged.id, "entity-project-atlas")
        XCTAssertEqual(Set(merged.sourceRefs), Set(["source-a", "source-b"]))
        XCTAssertEqual(merged.confidence, 0.82)
        XCTAssertTrue(merged.aliases.contains("Atlas"))
        XCTAssertTrue(merged.aliases.contains("project-atlas"))
    }

    func testDedupeEntitiesMergesLegacyDuplicates() throws {
        let harness = try makeHarness()
        let now = Date()
        try insertEntityBypassingStoreMerge(EntityRecord(
            id: "legacy-hive-one",
            name: "Hive",
            entityType: "topic",
            sourceRefs: ["source-a"],
            confidence: 0.5,
            createdAt: now
        ), databaseURL: harness.paths.database)
        try insertEntityBypassingStoreMerge(EntityRecord(
            id: "legacy-hive-two",
            name: "hive",
            entityType: "topic",
            sourceRefs: ["source-b"],
            confidence: 0.72,
            createdAt: now.addingTimeInterval(30)
        ), databaseURL: harness.paths.database)

        let removed = try harness.store.dedupeEntities()
        let entities = try harness.store.fetchEntities()
        let merged = try XCTUnwrap(entities.first)

        XCTAssertEqual(removed, 1)
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(merged.id, "legacy-hive-one")
        XCTAssertEqual(Set(merged.sourceRefs), Set(["source-a", "source-b"]))
        XCTAssertEqual(merged.confidence, 0.72)
    }

    func testSelfHealingFoldsUCLAStudentClaimIntoCanonicalGraphNode() throws {
        let harness = try makeHarness()
        let now = Date()
        let source = makeSource(id: "ucla-source", title: "UCLA memory", now: now)
        try harness.store.saveSource(source)
        try harness.store.saveEntity(EntityRecord(
            id: "entity-bio",
            name: "Bio",
            entityType: "topic",
            sourceRefs: [source.id],
            confidence: 0.7,
            createdAt: now
        ))
        try harness.store.saveEntity(EntityRecord(
            id: "entity-ucla",
            name: "UCLA",
            entityType: "topic",
            sourceRefs: [source.id],
            confidence: 0.9,
            createdAt: now.addingTimeInterval(1)
        ))
        try harness.store.saveClaim(ClaimRecord(
            id: "claim-ucla-student",
            statement: "The user is a student at UCLA.",
            claimType: "memory-seed-confirmed",
            subjectEntityID: "entity-bio",
            sourceRefs: [source.id],
            confidence: 0.98,
            uncertaintyReason: "Fixture",
            createdAt: now.addingTimeInterval(2)
        ))

        let graph = try harness.loop.updateDerivedKnowledge()
        let claims = try harness.store.fetchClaims()
        let entities = try harness.store.fetchEntities()
        let pages = try harness.store.fetchWikiPages()
        let healedClaim = try XCTUnwrap(claims.first { $0.id == "claim-ucla-student" })
        let healedEntity = try XCTUnwrap(entities.first { $0.id == "entity-ucla" })

        XCTAssertEqual(healedClaim.subjectEntityID, "entity-ucla")
        XCTAssertEqual(healedClaim.claimType, "supporting-detail")
        XCTAssertEqual(healedClaim.status, .active)
        XCTAssertEqual(healedEntity.name, "UCLA Student")
        XCTAssertTrue(healedEntity.aliases.contains("UCLA"))
        XCTAssertTrue(graph.nodes.contains { $0.id == "entity-ucla" && $0.title == "UCLA Student" })
        XCTAssertFalse(graph.nodes.contains { $0.id == "claim-ucla-student" })
        XCTAssertTrue(pages.contains { $0.title == "UCLA Student" && $0.claimRefs.contains("claim-ucla-student") })
    }

    func testSelfHealingConsolidatesMacHardwareAndFundingEvidence() throws {
        let harness = try makeHarness()
        let now = Date()
        let appleSource = SourceRecord(
            id: "source-apple-mac",
            kind: .browserHistory,
            connector: "browser-history",
            uri: "https://www.apple.com/mac-studio/",
            title: "Apple Mac Studio M3 Ultra 512GB Memory",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "source-apple-mac",
            importedAt: now,
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(14 * 86_400),
            privacyLabel: .cloudBlocked,
            status: .extracted
        )
        let grantSource = SourceRecord(
            id: "source-grants",
            kind: .browserHistory,
            connector: "browser-history",
            uri: "https://example.org/grants",
            title: "Grant and scholarship application funding",
            mimeType: "text/html",
            sizeBytes: 1,
            sha256: "source-grants",
            importedAt: now,
            observedAt: now.addingTimeInterval(-60),
            retentionExpiresAt: now.addingTimeInterval(14 * 86_400),
            privacyLabel: .cloudBlocked,
            status: .extracted
        )
        try harness.store.saveSource(appleSource)
        try harness.store.saveSource(grantSource)
        try harness.store.saveEntity(EntityRecord(
            id: "entity-macbook",
            name: "MacBook",
            entityType: "topic",
            sourceRefs: [appleSource.id],
            confidence: 0.76,
            createdAt: now
        ))
        try harness.store.saveEntity(EntityRecord(
            id: "entity-mac-studio",
            name: "Mac Studio",
            entityType: "topic",
            sourceRefs: [appleSource.id],
            confidence: 0.82,
            createdAt: now.addingTimeInterval(1)
        ))
        try harness.store.saveClaim(ClaimRecord(
            id: "claim-hardware-need",
            statement: "The user wants to buy an M3 Ultra Mac Studio with 512GB RAM from an authorized reseller or used discount source.",
            claimType: "memory-seed-confirmed",
            sourceRefs: [appleSource.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture",
            createdAt: now.addingTimeInterval(2)
        ))
        try harness.store.saveClaim(ClaimRecord(
            id: "claim-grant-need",
            statement: "The user has zero money to spend and prefers grant funding in hard cash rather than discounts.",
            claimType: "memory-seed-confirmed",
            sourceRefs: [grantSource.id],
            confidence: 0.94,
            uncertaintyReason: "Fixture",
            createdAt: now.addingTimeInterval(3)
        ))

        let graph = try harness.loop.updateDerivedKnowledge()
        let claims = try harness.store.fetchClaims()
        let entities = try harness.store.fetchEntities()
        let pages = try harness.store.fetchWikiPages()

        let canonicalClaim = try XCTUnwrap(claims.first { $0.id == "claim-mac-studio-funding-goal" })
        let canonicalEntity = try XCTUnwrap(entities.first { $0.id == "entity-mac-studio-funding-goal" })
        XCTAssertEqual(canonicalClaim.subjectEntityID, canonicalEntity.id)
        XCTAssertTrue(canonicalClaim.statement.contains("M3 Ultra Mac Studio with 512GB RAM"))
        XCTAssertTrue(canonicalClaim.statement.contains("local AI and development work"))
        XCTAssertFalse(canonicalClaim.statement.contains("Apple/Mac user"))
        XCTAssertEqual(canonicalEntity.name, "Mac Studio Funding Goal")
        XCTAssertFalse(entities.contains { $0.id == "entity-macbook" })
        XCTAssertFalse(entities.contains { $0.id == "entity-mac-studio" })
        XCTAssertTrue(graph.nodes.contains { $0.id == canonicalEntity.id && $0.title == "Mac Studio Funding Goal" })
        XCTAssertFalse(graph.nodes.contains { $0.title == "MacBook" || $0.title == "Mac Studio" })
        XCTAssertTrue(pages.contains { $0.title == "Mac Studio Funding Goal" && $0.claimRefs.contains(canonicalClaim.id) })
    }

    func testSelfHealingAuthoritativeUserClaimRetractsContradiction() throws {
        let now = Date()
        let source = makeSource(id: "latex-source", title: "LaTeX memory", now: now)
        let entity = EntityRecord(id: "entity-latex", name: "LaTeX", entityType: "topic", sourceRefs: [source.id], confidence: 0.85)
        let weak = ClaimRecord(
            id: "claim-weak-latex",
            statement: "The user does not prefer single dollar LaTeX formatting.",
            claimType: "memory-seed-confirmed",
            subjectEntityID: entity.id,
            sourceRefs: [source.id],
            confidence: 0.58,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let authoritative = ClaimRecord(
            id: "claim-user-latex",
            statement: "The user prefers single dollar LaTeX formatting.",
            claimType: "user-authored-wiki",
            subjectEntityID: entity.id,
            sourceRefs: [],
            confidence: 1.0,
            uncertaintyReason: "User correction for a Colony article; treated as canonical guidance.",
            status: .userCorrected,
            createdBy: "user-wiki-edit",
            createdAt: now.addingTimeInterval(1)
        )

        let result = MemorySelfHealingEngine().heal(
            sources: [source],
            claims: [weak, authoritative],
            entities: [entity],
            feedback: [],
            now: now.addingTimeInterval(2)
        )
        let retracted = try XCTUnwrap(result.updatedClaims.first { $0.id == weak.id })

        XCTAssertEqual(retracted.status, .retracted)
        XCTAssertTrue(result.retractedClaimIDs.contains(weak.id))
        XCTAssertTrue(result.auditEvents.contains { $0.eventType == "memory.contradictionAutoResolved" })
    }

    func testSelfHealingAmbiguousContradictionsAskUser() throws {
        let now = Date()
        let source = makeSource(id: "cabin-source", title: "Cabin memory", now: now)
        let entity = EntityRecord(id: "entity-cabin", name: "Cabin", entityType: "project", sourceRefs: [source.id], confidence: 0.9)
        let realityKit = ClaimRecord(
            id: "claim-cabin-realitykit",
            statement: "The user wants Cabin to use RealityKit for cabin rendering.",
            claimType: "memory-seed-confirmed",
            subjectEntityID: entity.id,
            sourceRefs: [source.id],
            confidence: 0.82,
            uncertaintyReason: "Fixture",
            createdAt: now
        )
        let blender = ClaimRecord(
            id: "claim-cabin-blender",
            statement: "The user wants Cabin to use Blender for cabin rendering.",
            claimType: "memory-seed-confirmed",
            subjectEntityID: entity.id,
            sourceRefs: [source.id],
            confidence: 0.81,
            uncertaintyReason: "Fixture",
            createdAt: now.addingTimeInterval(1)
        )

        let result = MemorySelfHealingEngine().heal(
            sources: [source],
            claims: [realityKit, blender],
            entities: [entity],
            feedback: [],
            now: now.addingTimeInterval(2)
        )

        XCTAssertTrue(result.updatedClaims.contains { $0.id == realityKit.id && $0.status == .suspect })
        XCTAssertTrue(result.updatedClaims.contains { $0.id == blender.id && $0.status == .suspect })
        XCTAssertEqual(result.feedbackRecords.filter { $0.action == .askLater }.count, 2)
        XCTAssertTrue(result.auditEvents.contains { $0.eventType == "memory.contradictionNeedsUser" })
    }

    func testSelfHealingRemapsAcronymEntityReferences() throws {
        let now = Date()
        let source = makeSource(id: "school-source", title: "School memory", now: now)
        let ucla = EntityRecord(id: "entity-ucla", name: "UCLA", entityType: "topic", sourceRefs: [source.id], confidence: 0.86, createdAt: now)
        let expanded = EntityRecord(
            id: "entity-expanded-ucla",
            name: "University of California Los Angeles",
            entityType: "topic",
            sourceRefs: [source.id],
            confidence: 0.8,
            createdAt: now.addingTimeInterval(1)
        )
        let claim = ClaimRecord(
            id: "claim-expanded-ucla",
            statement: "The user studies at University of California Los Angeles.",
            claimType: "memory-seed-confirmed",
            subjectEntityID: expanded.id,
            sourceRefs: [source.id],
            confidence: 0.9,
            uncertaintyReason: "Fixture",
            createdAt: now.addingTimeInterval(2)
        )

        let result = MemorySelfHealingEngine().heal(
            sources: [source],
            claims: [claim],
            entities: [ucla, expanded],
            feedback: [],
            now: now.addingTimeInterval(3)
        )
        let updatedClaim = try XCTUnwrap(result.updatedClaims.first { $0.id == claim.id })
        let updatedEntity = try XCTUnwrap(result.updatedEntities.first { $0.id == ucla.id })

        XCTAssertEqual(result.entityRemapIDs[expanded.id], ucla.id)
        XCTAssertEqual(updatedClaim.subjectEntityID, ucla.id)
        XCTAssertTrue(updatedEntity.aliases.contains("University of California Los Angeles"))
    }

    func testGraphPrivacyFilterRemovesReviewOnlyBrowserNodes() throws {
        let now = Date()
        let browser = SourceRecord(
            id: "browser-source",
            kind: .browserHistory,
            connector: "browser",
            uri: "browser-history://Arc/Default",
            title: "Arc Default history",
            mimeType: "text/plain",
            sizeBytes: 1,
            sha256: "browser",
            importedAt: now,
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(14 * 86_400),
            privacyLabel: .cloudBlocked,
            status: .extracted
        )
        let durable = makeSource(id: "durable-source", title: "Project Atlas", now: now)
        let graph = HiveGraphSnapshot(
            nodes: [
                GraphNodeRecord(id: browser.id, title: browser.title, kind: .source, confidence: 0.8, sourceRefs: [browser.id]),
                GraphNodeRecord(id: "browser-claim", title: "INCIDENTAL: Browser page appeared", kind: .claim, confidence: 0.35, sourceRefs: [browser.id]),
                GraphNodeRecord(id: durable.id, title: durable.title, kind: .source, confidence: 0.8, sourceRefs: [durable.id]),
                GraphNodeRecord(id: "durable-claim", title: "Project Atlas has durable context", kind: .claim, confidence: 0.85, sourceRefs: [durable.id])
            ],
            edges: [
                GraphEdgeRecord(fromID: browser.id, toID: "browser-claim", predicate: .sourceOf, strength: 0.8, confidence: 0.8, evidenceCount: 1, sourceRefs: [browser.id]),
                GraphEdgeRecord(fromID: durable.id, toID: "durable-claim", predicate: .sourceOf, strength: 0.8, confidence: 0.8, evidenceCount: 1, sourceRefs: [durable.id])
            ]
        )

        let filtered = GraphPrivacyFilter().removingReviewOnlyNodes(graph, sources: [browser, durable])

        XCTAssertEqual(Set(filtered.nodes.map(\.id)), Set([durable.id, "durable-claim"]))
        XCTAssertEqual(filtered.edges.count, 1)
        XCTAssertEqual(filtered.edges.first?.fromID, durable.id)
    }

    func testGraphEvidenceFilterHidesProcessEdgesAndWeakAutoTopics() throws {
        let now = Date()
        let source = GraphNodeRecord(
            id: "source",
            title: "Personal note.md",
            kind: .source,
            confidence: 0.8,
            sourceRefs: ["source"],
            timestamp: now
        )
        let claim = GraphNodeRecord(
            id: "claim",
            title: "Personal note includes a concrete memory",
            kind: .claim,
            confidence: 0.72,
            sourceRefs: ["source"],
            timestamp: now
        )
        let weakTopic = GraphNodeRecord(
            id: "weak-topic",
            title: "Random Extracted Topic",
            kind: .topic,
            confidence: 0.55,
            sourceRefs: ["source"],
            timestamp: now
        )
        let insight = GraphNodeRecord(
            id: "insight",
            title: "Algorithmic path insight",
            kind: .insight,
            confidence: 0.6,
            sourceRefs: ["source"],
            timestamp: now
        )
        let graph = HiveGraphSnapshot(
            nodes: [source, claim, weakTopic, insight],
            edges: [
                GraphEdgeRecord(fromID: "source", toID: "claim", predicate: .sourceOf, strength: 0.7, confidence: 0.72, evidenceCount: 1),
                GraphEdgeRecord(fromID: "weak-topic", toID: "claim", predicate: .supports, strength: 0.45, confidence: 0.55, evidenceCount: 1),
                GraphEdgeRecord(fromID: "weak-topic", toID: "insight", predicate: .markovTransition, strength: 0.8, confidence: 0.8, evidenceCount: 1),
                GraphEdgeRecord(fromID: "weak-topic", toID: "weak-topic", predicate: .related, strength: 0.8, confidence: 0.8, evidenceCount: 1)
            ]
        )

        let filtered = GraphEvidenceFilter().keepingPersonalEvidence(graph)

        XCTAssertEqual(Set(filtered.nodes.map(\.id)), Set(["claim"]))
        XCTAssertTrue(filtered.edges.isEmpty)
    }

    func testKnowledgeLoopPersistsMarkovInsightsIntoWiki() throws {
        let harness = try makeHarness()
        let fixture = makeMarkovFixture()
        for source in fixture.sources {
            try harness.store.saveSource(source)
        }
        for claim in fixture.claims {
            try harness.store.saveClaim(claim)
        }
        for entity in fixture.entities {
            try harness.store.saveEntity(entity)
        }

        let graph = try harness.loop.updateDerivedKnowledge()
        let claims = try harness.store.fetchClaims()
        let pages = try harness.store.fetchWikiPages()

        XCTAssertTrue(claims.contains { $0.claimType == "graph-insight" })
        XCTAssertTrue(graph.nodes.contains { $0.kind == .insight })
        XCTAssertTrue(pages.first?.markdown.contains("## Connections") == true)
        XCTAssertFalse(pages.first?.markdown.contains("Markov graph insights") == true)
    }

    func testKnowledgeLoopIsIdempotentForUnchangedInputs() throws {
        let harness = try makeHarness()
        let fixture = makeMarkovFixture()
        for source in fixture.sources {
            try harness.store.saveSource(source)
        }
        for claim in fixture.claims {
            try harness.store.saveClaim(claim)
        }
        for entity in fixture.entities {
            try harness.store.saveEntity(entity)
        }

        _ = try harness.loop.updateDerivedKnowledge()
        let firstRelationshipCount = try harness.store.fetchRelationships().count
        let firstClaimCount = try harness.store.fetchClaims().count

        _ = try harness.loop.updateDerivedKnowledge()
        XCTAssertEqual(try harness.store.fetchRelationships().count, firstRelationshipCount)
        XCTAssertEqual(try harness.store.fetchClaims().count, firstClaimCount)
    }

    func testKnowledgeLoopDoesNotPromoteReviewOnlyBrowserHistoryToInsights() throws {
        let harness = try makeHarness()
        let now = Date()
        let browser = SourceRecord(
            id: "browser-review",
            kind: .browserHistory,
            connector: "browser-history-snapshot",
            uri: "browser-history://Arc/Default",
            title: "Arc Default history",
            mimeType: "text/plain",
            sizeBytes: 100,
            sha256: "browser-review",
            importedAt: now,
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(14 * 86_400),
            privacyLabel: .cloudBlocked,
            status: .needsReview
        )
        try harness.store.saveSource(browser)
        try harness.store.saveClaim(ClaimRecord(
            id: "browser-claim",
            statement: "INCIDENTAL: Example research page — example.com — Browser appearance alone is incidental and is not treated as preference.",
            claimType: "browser-observation",
            sourceRefs: [browser.id],
            confidence: 0.35,
            uncertaintyReason: "Browser evidence is not a preference signal without engagement feedback."
        ))
        try harness.store.saveEntity(EntityRecord(
            id: "browser-entity",
            name: "Example Research",
            entityType: "topic",
            sourceRefs: [browser.id],
            confidence: 0.5
        ))
        try harness.store.saveClaim(ClaimRecord(
            id: "stale-browser-insight",
            statement: "Arc Default history is a high-centrality memory node.",
            claimType: "graph-insight",
            sourceRefs: [browser.id],
            confidence: 0.7,
            uncertaintyReason: "stale"
        ))

        _ = try harness.loop.updateDerivedKnowledge()
        let claims = try harness.store.fetchClaims()
        let markdown = try XCTUnwrap(try harness.store.fetchWikiPages().first?.markdown)
        XCTAssertFalse(claims.contains { $0.id == "stale-browser-insight" })
        XCTAssertFalse(claims.contains { $0.claimType == "graph-insight" && $0.sourceRefs.contains(browser.id) })
        XCTAssertTrue(markdown.contains("No confirmed claims yet."))
        XCTAssertTrue(markdown.contains("## Open questions\nNothing needs confirmation right now."))
        XCTAssertFalse(markdown.contains("Graph health"))
        XCTAssertFalse(markdown.contains("## Topics\n- Example Research"))
    }

    func testBrowserHistoryImporterRequiresConsentAndSanitizesCapsules() throws {
        let harness = try makeHarness()
        let history = try makeChromiumHistoryFixture(in: harness.root)
        let profile = BrowserProfile(browserName: "TestBrowser", profileName: "Default", historyURL: history)
        let importer = BrowserHistoryImporter(paths: harness.paths, store: harness.store)
        XCTAssertFalse(profile.id.contains(history.path))

        let withoutConsent = try importer.importProfiles([profile], consent: [:])
        XCTAssertTrue(withoutConsent.isEmpty)
        XCTAssertTrue(try harness.store.fetchSources().isEmpty)
        XCTAssertFalse(try harness.store.fetchAuditEvents().contains { event in
            event.targetID.contains(history.path) || event.detail.contains(history.path)
        })

        let consent = BrowserProfileConsent(
            profileID: profile.id,
            importMode: .reviewOnly,
            includeTitles: true,
            stripQueryAndFragment: true,
            domainBlocklist: ["blocked.example"],
            grantedAt: Date()
        )
        let imported = try importer.importProfiles([profile], consent: [profile.id: consent], maxEntriesPerProfile: 10)
        XCTAssertEqual(imported.count, 2)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: harness.paths.snapshots.path).isEmpty)

        let sources = try harness.store.fetchSources()
        XCTAssertEqual(sources.count, 2)
        XCTAssertTrue(sources.allSatisfy { $0.connector == "browser-history-entry" })
        XCTAssertTrue(sources.allSatisfy { $0.uri.hasPrefix("browser-history://TestBrowser/Default/") })
        XCTAssertTrue(sources.contains { $0.title == "Good Page" })
        XCTAssertTrue(sources.contains { $0.title == "Good Page Two" })
        let source = try XCTUnwrap(sources.first { $0.title == "Good Page" })
        XCTAssertEqual(source.privacyLabel, .cloudBlocked)
        XCTAssertEqual(source.status, .extracted)
        XCTAssertTrue(source.uri.hasPrefix("browser-history://"))
        let artifact = try XCTUnwrap(try harness.store.fetchArtifacts(sourceID: source.id).first)
        let text = try XCTUnwrap(artifact.inlineText)
        XCTAssertTrue(text.contains("Good Page — example.com"))
        XCTAssertFalse(text.contains("https://example.com/path"))
        XCTAssertFalse(text.contains("secret=1"))
        XCTAssertFalse(text.contains("#frag"))
        XCTAssertFalse(text.contains("localhost"))
        XCTAssertFalse(text.contains("blocked.example"))
        let claims = try harness.store.fetchClaims()
        XCTAssertTrue(claims.contains { $0.statement.contains("Good Page — example.com") })
        XCTAssertFalse(claims.contains { $0.statement == "com — Browser appearance alone is incidental and is not treated as preference" })
        XCTAssertTrue(try harness.store.fetchEntities().isEmpty)

        let repeated = try importer.importProfiles([profile], consent: [profile.id: consent], maxEntriesPerProfile: 10)
        XCTAssertEqual(repeated.count, 2)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: harness.paths.snapshots.path).isEmpty)
        XCTAssertEqual(try harness.store.fetchSources().count, 2)
        XCTAssertEqual(try harness.store.fetchArtifacts(sourceID: source.id).count, 1)
    }

    func testBrowserSnapshotFallbackDoesNotCollideWithPartialBackupFile() throws {
        let harness = try makeHarness()
        let source = harness.root.appendingPathComponent("History")
        try Data("not sqlite".utf8).write(to: source)

        XCTAssertThrowsError(try BrowserSnapshotService().makeSafeSQLiteSnapshot(sourceURL: source, destinationDirectory: harness.paths.snapshots)) { error in
            XCTAssertTrue(String(describing: error).contains("quickCheckFailed"))
        }
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: harness.paths.snapshots.path)) ?? []
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testBrowserSnapshotFallbackFailsClosedWhenWALSidecarExists() throws {
        let harness = try makeHarness()
        let source = harness.root.appendingPathComponent("History")
        try Data("not sqlite".utf8).write(to: source)
        try Data("uncheckpointed".utf8).write(to: URL(fileURLWithPath: source.path + "-wal"))

        XCTAssertThrowsError(try BrowserSnapshotService().makeSafeSQLiteSnapshot(sourceURL: source, destinationDirectory: harness.paths.snapshots)) { error in
            XCTAssertTrue(String(describing: error).contains("requiresSQLiteBackup"))
        }
    }

    @MainActor
    func testSwiftDataMigrationPreservesCanonicalMemoryRecords() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(
            in: harness.root,
            name: "swiftdata-migration.txt",
            text: "SwiftData Migration Source says Hive should keep Field evidence separate from authored Colony memory."
        )
        _ = try harness.ingestion.ingest(urls: [file])
        let graph = try harness.loop.updateDerivedKnowledge()

        let swiftDataStore = try SwiftDataHiveDataStore(storeURL: harness.paths.swiftDataStore)
        let summary = try swiftDataStore.migrateOnce(from: harness.store, graph: graph)

        XCTAssertEqual(summary.sourceCount, 1)
        XCTAssertGreaterThan(summary.claimCount, 0)
        XCTAssertGreaterThan(summary.entityCount, 0)
        XCTAssertGreaterThan(summary.wikiArticleCount, 0)
        XCTAssertEqual(try swiftDataStore.fetchSources().count, 1)
        XCTAssertEqual(try swiftDataStore.fetchClaims(includeRetracted: true).count, summary.claimCount)
        XCTAssertFalse(try swiftDataStore.fetchWikiPages().contains { $0.kind == .source })
    }

    @MainActor
    func testCanonicalSwiftDataModelsRoundTripAndAdaptRecords() throws {
        let harness = try makeHarness()
        let store = try SwiftDataHiveDataStore(storeURL: harness.paths.swiftDataStore)
        let sourceRecord = makeSource(id: "native-source", title: "Native Source", now: Date())
        let rawSource = RawSource(
            record: sourceRecord,
            markdownBody: "# Native Source\n\nThe user prefers synthesized memory.",
            summary: "Synthesized memory source.",
            confidence: 0.94,
            auditLog: ["created for test"]
        )
        let wikiPage = WikiPageRecord(
            id: "native-node",
            title: "Native Node",
            markdown: "# Native Node\n\nA synthesized memory page.",
            sourceRefs: [sourceRecord.id],
            claimRefs: [],
            kind: .topic,
            summary: "A synthesized memory page.",
            frontmatter: ["authored_by": "user"]
        )
        let wikiNode = WikiNode(record: wikiPage, graphX: 12, graphY: -8, confidence: 0.91)
        let relationship = RelationshipRecord(
            id: "native-connection",
            subjectID: wikiNode.recordID,
            predicate: .supports,
            objectID: "other-node",
            strength: 0.8,
            confidence: 0.88,
            evidenceCount: 2
        )
        let connection = Connection(record: relationship, auditLog: ["connected for test"])

        store.context.insert(rawSource)
        store.context.insert(wikiNode)
        store.context.insert(connection)
        try store.context.save()

        XCTAssertEqual(try store.fetchNativeRawSources().first?.sourceRecord().id, sourceRecord.id)
        XCTAssertEqual(try store.fetchNativeWikiNodes().first?.wikiPageRecord().id, wikiPage.id)
        XCTAssertEqual(try store.fetchNativeConnections().first?.relationshipRecord().predicate, .supports)
        XCTAssertEqual(try store.fetchNativeRawSources().first?.auditLog, ["created for test"])

        rawSource.summary = "Updated summary."
        rawSource.updatedAt = Date()
        try store.context.save()
        XCTAssertEqual(try store.fetchNativeRawSources().first?.summary, "Updated summary.")

        store.context.delete(connection)
        try store.context.save()
        XCTAssertTrue(try store.fetchNativeConnections().isEmpty)
    }

    func testLocalAIEngineSummarizesRawSourceWithMockMLXPath() async throws {
        let rawSource = RawSource(
            recordID: "raw-ai",
            title: "AI Source",
            sourceKind: .text,
            originalURI: "local://ai-source",
            markdownBody: "# AI Source\n\nHive should summarize this into JSON.",
            processingState: .queued,
            contentHash: "hash-ai",
            confidence: 0.9,
            summary: "Fallback"
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

        let summary = try await engine.summarize(rawSource: rawSource, markdown: rawSource.markdownBody ?? "")
        XCTAssertEqual(summary.modelID, MLXModelProfile.qwen3_4B_4bit.id)
        XCTAssertFalse(summary.summary.isEmpty)
        XCTAssertFalse(summary.keyFacts.isEmpty)
        XCTAssertEqual(summary.suggestedNodes.first?.title, rawSource.recordID)
    }

    func testMLXManagerRejectsGGUFCompatibilityPath() async throws {
        let manager = MLXModelManager(availableProfiles: [
            MLXModelProfile(
                id: "local-gguf",
                displayName: "Local GGUF",
                huggingFaceID: "/tmp/model.gguf",
                estimatedResidentMemoryBytes: 1_073_741_824,
                backgroundEligible: true
            )
        ])
        let job = LocalInferenceJob(kind: .summarizeRawSource, prompt: "Summarize")

        do {
            _ = try await manager.run(job: job, budget: .baseM4Background())
            XCTFail("Expected GGUF compatibility path to fail clearly.")
        } catch let error as LocalAIEngineError {
            XCTAssertEqual(error, .ggufUnsupported("/tmp/model.gguf"))
        }
    }

    func testWikiLinkParserPreservesInternalLinks() {
        let segments = WikiLinkParser().parse("The user studies [[UCLA Student|at UCLA]] and builds [[Cabin]].")
        XCTAssertEqual(segments, [
            .text("The user studies "),
            .wikiLink(label: "at UCLA", target: "UCLA Student"),
            .text(" and builds "),
            .wikiLink(label: "Cabin", target: "Cabin"),
            .text(".")
        ])
    }

    func testLocalInferenceQueueDefersBackgroundWorkUntilIdle() async throws {
        let queue = LocalInferenceQueue(manager: MLXModelManager(executionMode: .deterministicMock))
        await queue.enqueue(LocalInferenceJob(
            kind: .summarizeRawSource,
            sourceID: "source-1",
            prompt: "Summarize this Markdown into memory JSON.",
            priority: .background
        ))

        let activeProfile = RuntimeProfile(
            chipName: "MacBookPro18,1",
            physicalMemoryBytes: 16 * 1_073_741_824,
            processorCount: 10,
            thermalState: .nominal,
            powerState: .unknown,
            lowPowerModeEnabled: false,
            foregroundUserActive: true
        )
        let deferred = try await queue.runReadyJobs(profile: activeProfile)
        XCTAssertTrue(deferred.isEmpty)
        let deferredPendingCount = await queue.pendingCount()
        XCTAssertEqual(deferredPendingCount, 1)

        let idleProfile = RuntimeProfile(
            chipName: "MacBookPro18,1",
            physicalMemoryBytes: 16 * 1_073_741_824,
            processorCount: 10,
            thermalState: .nominal,
            powerState: .unknown,
            lowPowerModeEnabled: false,
            foregroundUserActive: false
        )
        let results = try await queue.runReadyJobs(profile: idleProfile)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.modelID, MLXModelProfile.qwen3_4B_4bit.id)
        let completedPendingCount = await queue.pendingCount()
        XCTAssertEqual(completedPendingCount, 0)
    }

    func testSemanticZoomKeepsStableNodeMembershipWhileChangingDetail() throws {
        let source = makeSource(id: "zoom-source", title: "Zoom source", now: Date())
        let claims = [
            ClaimRecord(id: "detail", statement: "The user prefers tight LaTeX formatting.", sourceRefs: [source.id], confidence: 0.92, uncertaintyReason: "Fixture"),
            ClaimRecord(id: "important", statement: "The user is at UCLA studying mathematics.", sourceRefs: [source.id], confidence: 0.96, uncertaintyReason: "Fixture"),
            ClaimRecord(id: "defining", statement: "The user has certified IQ 164.", sourceRefs: [source.id], confidence: 0.98, uncertaintyReason: "Fixture")
        ]
        let graph = GraphEngine().buildGraph(sources: [source], claims: claims, entities: [], relationships: [])
        let far = GraphRenderSnapshot.build(graph: graph, scale: 0.48, motionPolicy: LivingGraphMotionPolicy(reduceMotion: true))
        let near = GraphRenderSnapshot.build(graph: graph, scale: 2.0, motionPolicy: LivingGraphMotionPolicy(reduceMotion: true))

        XCTAssertEqual(far.zoomLevel, .constellation)
        XCTAssertEqual(near.zoomLevel, .node)
        XCTAssertFalse(far.clusters.isEmpty)
        XCTAssertEqual(far.nodes.count, near.nodes.count)
        XCTAssertEqual(far.nodes.count, graph.nodes.count)
        XCTAssertEqual(near.nodes.count, graph.nodes.count)
        XCTAssertLessThanOrEqual(far.nodes.filter(\.labelVisible).count, near.nodes.filter(\.labelVisible).count)
        XCTAssertTrue(near.nodes.contains { $0.id == "defining" && $0.radius >= 14 })
    }

    func testWikiFrontmatterQueryBuildsDynamicTables() throws {
        let project = WikiPageRecord(
            id: "project-hive",
            title: "Hive",
            markdown: "# Hive",
            sourceRefs: ["source-a", "source-b"],
            claimRefs: ["claim-a"],
            updatedAt: Date(timeIntervalSince1970: 200),
            kind: .project,
            frontmatter: ["tags": "active, yc", "status": "current"]
        )
        let stale = WikiPageRecord(
            id: "project-old",
            title: "Old Project",
            markdown: "# Old Project",
            sourceRefs: [],
            claimRefs: [],
            updatedAt: Date(timeIntervalSince1970: 100),
            kind: .project,
            frontmatter: ["tags": "archive"]
        )
        let query = WikiFrontmatterQueryEngine().parse("""
        kind: project
        tags: active
        columns: title, kind, sourceCount, tags
        sort: updated desc
        """)

        let table = WikiFrontmatterQueryEngine().renderTable(pages: [stale, project], query: query)

        XCTAssertTrue(table.contains("| Title | Kind | Field | Tags |"))
        XCTAssertTrue(table.contains("| Hive | project | 2 | active, yc |"))
        XCTAssertFalse(table.contains("Old Project"))
    }

    func testWikiQueryBlocksRenderFromFrontmatter() throws {
        let page = WikiPageRecord(
            id: "query-page",
            title: "Project Index",
            markdown: """
            # Project Index

            ```hive-query
            kind: project
            tags: yc
            columns: title, claimCount
            ```
            """,
            sourceRefs: [],
            claimRefs: [],
            kind: .project,
            frontmatter: ["tags": "index"]
        )
        let match = WikiPageRecord(
            id: "project-hive",
            title: "Hive",
            markdown: "# Hive",
            sourceRefs: [],
            claimRefs: ["claim-a", "claim-b"],
            kind: .project,
            frontmatter: ["tags": "yc"]
        )

        let body = WikiPresentationModel(page: page, allPages: [page, match]).body

        XCTAssertTrue(body.contains("| Hive | 2 |"))
        XCTAssertFalse(body.contains("```hive-query"))
    }

    func testDataviewStyleBlocksRenderFromFrontmatter() throws {
        let page = WikiPageRecord(
            id: "query-page",
            title: "Active Projects",
            markdown: """
            # Active Projects

            ```dataview
            TABLE title, sourceCount, tags
            FROM #yc
            WHERE kind = project
            SORT updated DESC
            LIMIT 5
            ```
            """,
            sourceRefs: [],
            claimRefs: [],
            kind: .project,
            frontmatter: ["tags": "index"]
        )
        let match = WikiPageRecord(
            id: "project-hive",
            title: "Hive",
            markdown: "# Hive",
            sourceRefs: ["source-a"],
            claimRefs: [],
            updatedAt: Date(timeIntervalSince1970: 100),
            kind: .project,
            frontmatter: ["tags": "yc"]
        )
        let miss = WikiPageRecord(
            id: "person-yc",
            title: "YC Contact",
            markdown: "# YC Contact",
            sourceRefs: [],
            claimRefs: [],
            kind: .person,
            frontmatter: ["tags": "yc"]
        )

        let body = WikiPresentationModel(page: page, allPages: [page, match, miss]).body

        XCTAssertTrue(body.contains("| Hive | 1 | yc |"))
        XCTAssertFalse(body.contains("YC Contact"))
        XCTAssertFalse(body.contains("```dataview"))
    }

    func testWikiAttachmentDownloaderRewritesRemoteImagesToLocalAssets() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HiveAttachment-\(UUID().uuidString)", isDirectory: true)
        let assets = root.appendingPathComponent("flower-field/assets", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let markdown = "A clipped article image: ![diagram](https://example.com/assets/diagram.png)"
        let result = try WikiAttachmentDownloader().downloadAttachments(
            in: markdown,
            assetsDirectory: assets,
            dataLoader: { _ in Data([0x89, 0x50, 0x4E, 0x47]) }
        )

        XCTAssertEqual(result.downloadedFiles.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.downloadedFiles[0].path))
        XCTAssertTrue(result.markdown.contains("](flower-field/assets/diagram-"))
        XCTAssertFalse(result.markdown.contains("https://example.com"))
    }

    func testWikiOperationFilesAnswerAsDurableArticleWithoutSourceDump() throws {
        let source = SourceRecord(
            id: "source-secret",
            kind: .text,
            uri: "/tmp/raw/private-source.md",
            title: "private-source.md",
            mimeType: "text/markdown",
            sizeBytes: 12,
            sha256: "abc",
            retentionExpiresAt: Date(timeIntervalSince1970: 1_000)
        )
        let related = WikiPageRecord(
            id: "project-hive",
            title: "Hive",
            markdown: "# Hive\n\nA private AI memory vault.",
            sourceRefs: [],
            claimRefs: [],
            kind: .project,
            summary: "A private AI memory vault."
        )
        let answer = CitedAnswer(
            answer: "Hive should file useful comparisons back into the maintained wiki.",
            citations: [source],
            uncertainty: "Indexed memory only",
            suggestedActions: ["Open The Colony"]
        )

        let result = WikiOperationEngine().archiveAnswerPage(
            query: "How should Hive handle useful answers?",
            answer: answer,
            relatedPages: [related],
            previousPages: [],
            now: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(result.page.kind, .answer)
        XCTAssertTrue(result.page.sourceRefs.contains("source-secret"))
        XCTAssertEqual(result.page.frontmatter["source_count"], "1")
        XCTAssertTrue(result.page.markdown.contains("[[Hive]]"))
        XCTAssertTrue(result.page.markdown.contains("## Question"))
        XCTAssertFalse(result.page.markdown.contains("private-source.md"))
        XCTAssertEqual(result.auditEvent.eventType, "wiki.answerFiled")
    }

    func testStartupSourcePluginsPrioritizeDriveAndParseExplicitLocations() throws {
        let suiteName = "HiveStartupSourcePluginTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HiveStartupPlugins-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let file = root.appendingPathComponent("brief.md")
        try "Drive export".write(to: file, atomically: true, encoding: .utf8)

        let request = HiveStartupSourcePluginRequest(
            selections: HiveStartupSourcePluginCatalog.defaultSelections,
            pasteLocation: file.path,
            prompt: "Pull the important project facts into existing Colony articles."
        )
        HiveStartupSourcePluginCatalog.persist(request, defaults: defaults)
        let loaded = HiveStartupSourcePluginCatalog.load(defaults: defaults)

        XCTAssertEqual(HiveStartupSourcePluginCatalog.orderedKinds.first, .googleDrive)
        XCTAssertTrue(HiveStartupSourcePluginCatalog.enabledTitles(in: loaded).contains("Google Drive"))
        XCTAssertEqual(HiveStartupSourcePluginCatalog.importableLocalURLs(from: loaded), [])
        XCTAssertTrue(HiveStartupSourcePluginCatalog.startupMarkdown(for: loaded)?.contains("Google Drive") == true)
        XCTAssertTrue(HiveStartupSourcePluginCatalog.isGoogleDriveLocation("https://drive.google.com/drive/folders/example"))

        let localDiskRequest = HiveStartupSourcePluginRequest(
            selections: HiveStartupSourcePluginCatalog.orderedKinds.map {
                HiveStartupSourcePluginSelection(kind: $0, isEnabled: $0 == .localDisk)
            },
            pasteLocation: file.path,
            prompt: "Use this brief as durable Field evidence."
        )
        XCTAssertEqual(HiveStartupSourcePluginCatalog.importableLocalURLs(from: localDiskRequest), [file])

        let harness = try makeHarness()
        let result = try HiveStartupSourcePluginBackend().execute(
            request: localDiskRequest,
            paths: harness.paths,
            store: harness.store,
            ingestionEngine: harness.ingestion
        )
        let sources = try harness.store.fetchSources(includeForgotten: true)
        XCTAssertEqual(result.importedLocalCount, 1)
        XCTAssertEqual(result.requestCount, 1)
        XCTAssertTrue(sources.contains { $0.connector == "startup-local-disk" })
        XCTAssertTrue(sources.contains { $0.connector == "startup-source-plugins" })
    }

    func testStartupSourcePluginsRejectUnsafeWebURLsAndSaveRequestOnly() throws {
        let request = HiveStartupSourcePluginRequest(
            selections: HiveStartupSourcePluginCatalog.orderedKinds.map {
                HiveStartupSourcePluginSelection(kind: $0, isEnabled: $0 == .webPages)
            },
            pasteLocation: "http://127.0.0.1/private",
            prompt: ""
        )

        let harness = try makeHarness()
        let result = try HiveStartupSourcePluginBackend().execute(
            request: request,
            paths: harness.paths,
            store: harness.store,
            ingestionEngine: harness.ingestion
        )
        let sources = try harness.store.fetchSources(includeForgotten: true)

        XCTAssertEqual(result.capturedWebCount, 0)
        XCTAssertEqual(result.requestCount, 1)
        XCTAssertFalse(sources.contains { $0.connector == "startup-web-page" })
        XCTAssertTrue(sources.contains { $0.connector == "startup-source-plugins" })
    }

    func testStartupSourcePluginsImportExplicitUploadsThroughBackend() throws {
        let uploadRoot = FileManager.default.temporaryDirectory.appendingPathComponent("HiveStartupUploads-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: uploadRoot, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: uploadRoot)
        }
        let upload = uploadRoot.appendingPathComponent("meeting-notes.md")
        try "Important uploaded notes for Hive.".write(to: upload, atomically: true, encoding: .utf8)
        let request = HiveStartupSourcePluginRequest(
            selections: HiveStartupSourcePluginCatalog.orderedKinds.map {
                HiveStartupSourcePluginSelection(kind: $0, isEnabled: $0 == .uploads)
            },
            pasteLocation: "",
            prompt: ""
        )

        let harness = try makeHarness()
        let result = try HiveStartupSourcePluginBackend().execute(
            request: request,
            uploadedURLs: [upload],
            paths: harness.paths,
            store: harness.store,
            ingestionEngine: harness.ingestion
        )
        let sources = try harness.store.fetchSources(includeForgotten: true)

        XCTAssertEqual(result.importedLocalCount, 1)
        XCTAssertEqual(result.requestCount, 0)
        XCTAssertTrue(sources.contains { $0.connector == "startup-uploads" })
        XCTAssertTrue(HiveStartupSourcePluginCatalog.sanitizedRequest(request).hasUploadIntent)
    }

    func testStartupSourcePluginsImportExplicitBrowserBookmarksThroughBackend() throws {
        let profileRoot = FileManager.default.temporaryDirectory.appendingPathComponent("HiveStartupBookmarks-\(UUID().uuidString)", isDirectory: true)
        let profile = profileRoot.appendingPathComponent("Default", isDirectory: true)
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: profileRoot)
        }
        let bookmarks = profile.appendingPathComponent("Bookmarks")
        let bookmarkJSON = """
        {
          "roots": {
            "bookmark_bar": {
              "type": "folder",
              "children": [
                {
                  "type": "url",
                  "name": "Foundation Models",
                  "url": "https://developer.apple.com/documentation/foundationmodels/?private=1",
                  "date_added": "13393440000000000"
                }
              ]
            }
          }
        }
        """
        try bookmarkJSON.write(to: bookmarks, atomically: true, encoding: .utf8)
        let request = HiveStartupSourcePluginRequest(
            selections: HiveStartupSourcePluginCatalog.orderedKinds.map {
                HiveStartupSourcePluginSelection(kind: $0, isEnabled: $0 == .browserHistory)
            },
            pasteLocation: "",
            prompt: ""
        )

        let harness = try makeHarness()
        let result = try HiveStartupSourcePluginBackend().execute(
            request: request,
            browserHistoryURLs: [bookmarks],
            paths: harness.paths,
            store: harness.store,
            ingestionEngine: harness.ingestion
        )
        let sources = try harness.store.fetchSources(includeForgotten: true)

        XCTAssertEqual(result.importedBrowserBookmarkCount, 1)
        XCTAssertTrue(result.summary.contains("browser bookmark"))
        let bookmarkSource = try XCTUnwrap(sources.first { $0.connector == "browser-bookmark-entry" })
        XCTAssertEqual(bookmarkSource.kind, .browserBookmark)
        XCTAssertEqual(bookmarkSource.privacyLabel, .cloudBlocked)
        XCTAssertFalse(bookmarkSource.uri.contains("private=1"))
    }

    func testAppUsageSnapshotImporterStoresCloudBlockedMetadataOnly() throws {
        let harness = try makeHarness()
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = AppUsageSnapshot(
            capturedAt: capturedAt,
            sourceName: "Computer Use app list",
            entries: [
                AppUsageSnapshotEntry(
                    appName: "Codex",
                    bundleIdentifier: "com.openai.codex",
                    path: "/Applications/Codex.app",
                    isRunning: true,
                    lastUsed: capturedAt,
                    useCount: 12
                ),
                AppUsageSnapshotEntry(
                    appName: "Hive",
                    bundleIdentifier: "local.hive.desktop",
                    path: "/Users/example/Applications/Hive.app",
                    isRunning: true,
                    lastUsed: capturedAt,
                    useCount: 3
                )
            ]
        )

        let importer = AppUsageSnapshotImporter(paths: harness.paths, store: harness.store)
        let source = try XCTUnwrap(importer.importSnapshot(snapshot))
        let artifacts = try harness.store.fetchArtifacts(sourceID: source.id)
        let artifactText = try XCTUnwrap(artifacts.first?.inlineText)

        XCTAssertEqual(source.kind, .taskExport)
        XCTAssertEqual(source.connector, "app-usage-snapshot")
        XCTAssertEqual(source.privacyLabel, .cloudBlocked)
        XCTAssertEqual(source.status, .extracted)
        XCTAssertTrue(artifactText.contains("APP: Codex"))
        XCTAssertTrue(artifactText.contains("bundle=com.openai.codex"))
        XCTAssertTrue(artifactText.contains("Privacy: app identity and usage metadata only"))
        XCTAssertFalse(artifactText.localizedCaseInsensitiveContains("message body"))

        let duplicate = try XCTUnwrap(importer.importSnapshot(snapshot))
        let sources = try harness.store.fetchSources(includeForgotten: true).filter { $0.connector == "app-usage-snapshot" }
        XCTAssertEqual(duplicate.id, source.id)
        XCTAssertEqual(sources.count, 1)
    }

    func testPersonalDataDiscoverySuppressesLiveAppSnapshotDuringTests() {
        let snapshot = PersonalDataDiscovery().currentAppUsageSnapshot(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(snapshot.sourceName, "Running Mac apps")
        XCTAssertTrue(snapshot.entries.isEmpty)
    }

    func testStartupSourcePluginsExposeAppUsageAsBackendRunnableIntent() {
        let request = HiveStartupSourcePluginRequest(
            selections: HiveStartupSourcePluginCatalog.orderedKinds.map {
                HiveStartupSourcePluginSelection(kind: $0, isEnabled: $0 == .appUsage)
            }
        )

        XCTAssertTrue(HiveStartupSourcePluginCatalog.orderedKinds.contains(.appUsage))
        XCTAssertTrue(request.canRunWithoutPicker)
        XCTAssertTrue(request.hasAppUsageIntent)
    }

    func testLearningSettingsPersistAndGateSourcePlugins() throws {
        let suiteName = "HiveLearningSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = HiveLearningSettings(
            connectionAggression: 1.2,
            sensitiveTopics: "  private topic  ",
            learnsFromBrowserCaptures: false,
            learnsFromFiles: false,
            learnsFromCalendar: true
        )
        HiveLearningSettingsStore.save(settings, defaults: defaults)
        let loaded = HiveLearningSettingsStore.load(defaults: defaults)

        XCTAssertEqual(loaded.connectionAggression, 1)
        XCTAssertEqual(loaded.sensitiveTopics, "private topic")
        XCTAssertFalse(loaded.learnsFromBrowserCaptures)
        XCTAssertFalse(loaded.learnsFromFiles)
        XCTAssertTrue(loaded.learnsFromCalendar)
        XCTAssertEqual(loaded.rawSourceRetention, .fortyEightHours)
        XCTAssertFalse(loaded.allows(sourcePlugin: .localDisk))
        XCTAssertFalse(loaded.allows(sourcePlugin: .browserHistory))
        XCTAssertTrue(loaded.allows(sourcePlugin: .webPages))
        XCTAssertGreaterThan(
            HiveLearningSettings(connectionAggression: 0).markovTransitionMinimumProbability,
            HiveLearningSettings(connectionAggression: 1).markovTransitionMinimumProbability
        )
        XCTAssertGreaterThan(
            HiveLearningSettings(connectionAggression: 1).maximumMarkovLoopCount,
            HiveLearningSettings(connectionAggression: 0).maximumMarkovLoopCount
        )

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HiveLearningGate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let file = root.appendingPathComponent("blocked.md")
        try "This should not import when file learning is off.".write(to: file, atomically: true, encoding: .utf8)
        let request = HiveStartupSourcePluginRequest(
            selections: HiveStartupSourcePluginCatalog.orderedKinds.map {
                HiveStartupSourcePluginSelection(kind: $0, isEnabled: $0 == .localDisk)
            },
            pasteLocation: file.path,
            prompt: "Use this."
        )

        let harness = try makeHarness()
        let result = try HiveStartupSourcePluginBackend().execute(
            request: request,
            paths: harness.paths,
            store: harness.store,
            ingestionEngine: harness.ingestion,
            learningSettings: loaded
        )

        XCTAssertEqual(result.importedLocalCount, 0)
        XCTAssertEqual(result.requestCount, 0)
        XCTAssertTrue(result.auditDetails.contains { $0.contains("Privacy settings blocked Local disk") })
    }

    func testConnectionAggressionControlsDerivedRelationshipBackend() throws {
        let source = SourceRecord(
            id: "source-resume",
            kind: .text,
            uri: "memory://resume",
            title: "Resume",
            mimeType: "text/plain",
            sizeBytes: 128,
            sha256: "resume",
            retentionExpiresAt: Date().addingTimeInterval(48 * 3_600),
            status: .extracted
        )
        let entity = EntityRecord(
            id: "entity-react",
            name: "React",
            entityType: "skill",
            sourceRefs: [source.id],
            confidence: 0.85
        )
        let claim = ClaimRecord(
            id: "claim-react-typescript",
            statement: "React development with TypeScript",
            claimType: "skill",
            sourceRefs: [source.id],
            sourceSpanRefs: ["resume:12"],
            confidence: 0.82,
            uncertaintyReason: ""
        )

        let cautious = GraphEngine().deriveRelationships(
            sources: [source],
            claims: [claim],
            entities: [entity],
            existing: [],
            learningSettings: HiveLearningSettings(connectionAggression: 0)
        )
        let aggressive = GraphEngine().deriveRelationships(
            sources: [source],
            claims: [claim],
            entities: [entity],
            existing: [],
            learningSettings: HiveLearningSettings(connectionAggression: 1)
        )

        XCTAssertFalse(cautious.contains { $0.subjectID == entity.id && $0.objectID == claim.id && $0.predicate == .supports })
        let aggressiveSupport = try XCTUnwrap(aggressive.first { $0.subjectID == entity.id && $0.objectID == claim.id && $0.predicate == .supports })
        XCTAssertEqual(aggressiveSupport.evidenceCount, 1)
        XCTAssertGreaterThan(aggressiveSupport.strength, 0.35)
    }

    func testIngestionUsesFixedRawSourceRetention() throws {
        let harness = try makeHarness(
            learningSettingsProvider: {
                HiveLearningSettings(rawSourceRetention: .fortyEightHours)
            }
        )
        let file = try makeTextFile(in: harness.root, name: "fixed-retention.md", text: "Retention follows Hive's fixed raw-file window.")
        let before = Date()
        let source = try harness.ingestion.ingestFile(file)
        let interval = source.retentionExpiresAt.timeIntervalSince(before)

        XCTAssertGreaterThan(interval, 47.5 * 3_600)
        XCTAssertLessThan(interval, 48.5 * 3_600)
    }

    func testIngestionCanQueueFilesUntilUploadBatchSettles() throws {
        let harness = try makeHarness()
        let file = try makeTextFile(in: harness.root, name: "queued-upload.md", text: "Queued upload should wait before extraction.")

        let source = try harness.ingestion.ingestFile(file, processImmediately: false)
        XCTAssertEqual(source.status, .queued)
        XCTAssertTrue(try harness.store.fetchArtifacts(sourceID: source.id).isEmpty)

        try harness.ingestion.processPending(limit: 10)
        let processed = try XCTUnwrap(try harness.store.fetchSource(id: source.id))
        XCTAssertEqual(processed.status, .extracted)
        XCTAssertFalse(try harness.store.fetchArtifacts(sourceID: source.id).isEmpty)
    }

    func testWikiSearchToolPlansQMDCollectionAndMCPCommands() throws {
        let wikiURL = URL(fileURLWithPath: "/tmp/Hive/Vault/Colony", isDirectory: true)
        let plan = WikiSearchEngine().qmdCommandPlan(vaultWikiURL: wikiURL)

        XCTAssertEqual(plan.collectionName, "hive-wiki")
        XCTAssertEqual(plan.addCollection, ["qmd", "collection", "add", "/tmp/Hive/Vault/Colony", "--name", "hive-wiki", "--mask", "**/*.md"])
        XCTAssertEqual(plan.addContext, ["qmd", "context", "add", "qmd://hive-wiki", "Hive Colony: maintained wiki articles, answer pages, frontmatter, backlinks, and daily audit history."])
        XCTAssertEqual(plan.updateIndex, ["qmd", "update"])
        XCTAssertEqual(plan.embedIndex, ["qmd", "embed"])
        XCTAssertEqual(plan.keywordSearchPrefix, ["qmd", "search"])
        XCTAssertEqual(plan.vectorSearchPrefix, ["qmd", "vsearch"])
        XCTAssertEqual(plan.queryPrefix, ["qmd", "query"])
        XCTAssertEqual(plan.hybridSearchPrefix, ["qmd", "query"])
        XCTAssertEqual(plan.getDocumentPrefix, ["qmd", "get"])
        XCTAssertEqual(plan.multiGetDocumentPrefix, ["qmd", "multi-get"])
        XCTAssertEqual(plan.status, ["qmd", "status"])
        XCTAssertEqual(plan.mcpServer, ["qmd", "mcp"])
        XCTAssertEqual(plan.mcpHTTPServer, ["qmd", "mcp", "--http"])
        XCTAssertEqual(plan.mcpHTTPDaemon, ["qmd", "mcp", "--http", "--daemon"])
        XCTAssertEqual(plan.mcpStop, ["qmd", "mcp", "stop"])
        XCTAssertEqual(plan.httpHealthURL, "http://localhost:8181/health")
        XCTAssertEqual(plan.httpMCPURL, "http://localhost:8181/mcp")
    }

    func testWikiSearchFallsBackToIndexMetadataAndParsesQMDHits() throws {
        let page = WikiPageRecord(
            id: "project-hive",
            title: "Hive Memory Compiler",
            markdown: "# Hive Memory Compiler\n\nCompiled wiki maintenance.",
            sourceRefs: [],
            claimRefs: [],
            kind: .project,
            summary: "Deterministic tool that maintains the wiki and graph.",
            frontmatter: ["tags": "memex, maintenance"]
        )

        let fallback = WikiSearchEngine().search(query: "memex maintenance", pages: [page], limit: 3)
        XCTAssertEqual(fallback.first?.pageID, "project-hive")
        XCTAssertEqual(fallback.first?.backend, .indexFallback)
        XCTAssertTrue(fallback.first?.snippet.localizedCaseInsensitiveContains("wiki") == true)

        let qmdOutput = "1. qmd://hive-wiki/projects/hive-memory-compiler.md: Compiled wiki maintenance"
        let qmdHits = WikiSearchEngine().search(query: "compiler", pages: [page], limit: 3, qmdOutput: qmdOutput)
        XCTAssertEqual(qmdHits.first?.pageID, "project-hive")
        XCTAssertEqual(qmdHits.first?.backend, .qmdCLI)

        let qmdJSON = """
        {"results":[{"title":"Hive Memory Compiler","displayPath":"projects/hive-memory-compiler.md","docid":"#a1b2c3","snippet":"Compiled wiki maintenance","score":0.82,"context":"Hive Colony"}]}
        """
        let jsonHits = QMDWikiSearchTool().parseJSONSearchOutput(qmdJSON, pages: [page], limit: 3)
        XCTAssertEqual(jsonHits.first?.pageID, "project-hive")
        XCTAssertEqual(jsonHits.first?.score, 0.82)
    }

    func testWikiMarpDeckExporterCreatesDeckFromColonyPages() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HiveMarp-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let page = WikiPageRecord(
            id: "project-hive",
            title: "Hive Wiki Tools",
            markdown: """
            # Hive Wiki Tools

            Hive searches The Colony before reading raw evidence.
            Hive can save useful answers back as maintained pages.
            """,
            sourceRefs: ["source-a"],
            claimRefs: ["claim-a"],
            updatedAt: Date(timeIntervalSince1970: 200),
            kind: .project,
            summary: "Hive maintains a compiled wiki with search, backlinks, and tools.",
            frontmatter: ["tags": "wiki, tools"]
        )

        let export = try WikiMarpDeckExporter().exportDeck(
            title: "Hive Wiki Tools",
            pages: [page],
            now: Date(timeIntervalSince1970: 200),
            destinationDirectory: root
        )

        XCTAssertEqual(export.page.frontmatter["format"], "marp")
        XCTAssertEqual(export.page.frontmatter["marp"], "true")
        XCTAssertTrue(export.page.markdown.contains("marp: true"))
        XCTAssertTrue(export.page.markdown.contains("## Hive Wiki Tools"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: export.fileURL!.path))
        XCTAssertEqual(export.auditEvent.eventType, "wiki.marpDeckCreated")
    }

    func testWikiSearchRouterDefaultsToNativeIndexAndUsesQMDOnlyWhenRequested() throws {
        let page = WikiPageRecord(
            id: "project-hive",
            title: "Hive Memory Compiler",
            markdown: "# Hive Memory Compiler\n\nThis page covers local compiled wiki search and maintenance.",
            sourceRefs: [],
            claimRefs: ["claim-hive"],
            kind: .project,
            summary: "Maintains The Colony before answering questions.",
            frontmatter: ["tags": "wiki, maintenance, local"],
            outboundLinks: ["Cabin"]
        )
        let router = WikiSearchRouter()
        let automatic = router.searchWiki(
            query: "Colony answering",
            pages: [page],
            limit: 3,
            mode: .automatic,
            qmdOutput: "1. qmd://hive-wiki/project-hive.md: should not win"
        )
        XCTAssertEqual(automatic.first?.pageID, "project-hive")
        XCTAssertEqual(automatic.first?.backend, .nativeIndex)
        XCTAssertTrue(automatic.first?.matchedFields.contains("summary") == true)

        let qmdJSON = #"{"results":[{"path":"project-hive","snippet":"Compiled Wiki qmd hit","score":9.5}]}"#
        let optional = router.searchWiki(
            query: "compiler",
            pages: [page],
            limit: 3,
            mode: .qmdOptional,
            qmdOutput: qmdJSON
        )
        XCTAssertEqual(optional.first?.backend, .qmdCLI)
        XCTAssertEqual(optional.first?.snippet, "Compiled Wiki qmd hit")
    }

    func testHiveWikiToolboxRetrievesRelationshipsAndProposesReversibleMaintenance() throws {
        let hive = WikiPageRecord(
            id: "hive",
            title: "Hive",
            markdown: "# Hive\n\nHive links to [[Cabin]] and local memory.",
            sourceRefs: [],
            claimRefs: ["claim-shared"],
            kind: .project,
            summary: "Compiled memory app.",
            outboundLinks: ["Cabin"]
        )
        let cabin = WikiPageRecord(
            id: "cabin",
            title: "Cabin",
            markdown: "# Cabin\n\nCabin links back to [[Hive]].",
            sourceRefs: [],
            claimRefs: ["claim-shared"],
            kind: .project,
            summary: "Cabin project.",
            outboundLinks: ["Hive"],
            inboundLinks: ["Hive"]
        )
        let toolbox = HiveWikiToolbox(pages: [hive, cabin])

        XCTAssertEqual(toolbox.getWikiPage(pageIDOrPath: "hive")?.title, "Hive")
        XCTAssertEqual(toolbox.relatedPages(pageID: "hive").first?.id, "cabin")
        XCTAssertEqual(toolbox.backlinks(pageID: "hive").first?.id, "cabin")

        let proposal = toolbox.proposeWikiPatch(reason: "nightly audit", touchedPageIDs: ["hive", "cabin"])
        XCTAssertTrue(proposal.requiresUserReview)
        XCTAssertEqual(Set(proposal.touchedPageIDs), Set(["hive", "cabin"]))
        XCTAssertTrue(proposal.operations.allSatisfy { $0.kind == .updateFrontmatter })
        XCTAssertEqual(proposal.beforeHashes.count, 2)
    }

    func testWikiMaintenanceOrchestratorCreatesProposalOnlyPatchEnvelope() throws {
        let page = WikiPageRecord(
            id: "hive",
            title: "Hive",
            markdown: "# Hive\n\nCompiled memory.",
            sourceRefs: [],
            claimRefs: [],
            kind: .project,
            summary: ""
        )
        let toolbox = HiveWikiToolbox(pages: [page])
        let envelope = WikiMaintenanceOrchestrator().runDryRun(
            toolbox: toolbox,
            scope: .nightlyAudit,
            now: Date(timeIntervalSince1970: 1_800)
        )
        XCTAssertEqual(envelope.mutationPolicy, "wiki-maintenance-output-is-proposal-only")
        XCTAssertTrue(envelope.isValidProposal)
        XCTAssertTrue(envelope.proposal.operations.contains { $0.kind == .appendLogEntry })
        XCTAssertTrue(envelope.proposal.requiresUserReview)
    }

    func testMemoryCompilerRuntimeRouterUsesAppleFirstLadderWithoutInvokingUnsupportedBackends() throws {
        let router = MemoryCompilerRuntimeRouter()
        XCTAssertEqual(router.preferredMode(for: AIBackendAvailability(platform: .iPhoneOrIPad, coreMLTaskModelAvailable: true, foundationModelsAvailable: true)), .appleFoundationModels)
        XCTAssertEqual(router.preferredMode(for: AIBackendAvailability(platform: .iPhoneOrIPad, foundationModelsAvailable: true)), .appleFoundationModels)
        XCTAssertEqual(router.preferredMode(for: AIBackendAvailability(platform: .mac, mlxAvailable: true)), .macLocalSynthesis)
        XCTAssertEqual(router.preferredMode(for: AIBackendAvailability(platform: .iPhoneOrIPad, mlxAvailable: true)), .deterministicLocalRules)
        XCTAssertEqual(router.preferredMode(for: AIBackendAvailability(platform: .olderUnsupported, coreMLTaskModelAvailable: true, foundationModelsAvailable: true)), .deterministicLocalRules)
        XCTAssertEqual(
            router.preferredMode(for: AIBackendAvailability(
                platform: .olderUnsupported,
                cloudSettings: CloudInferenceSettings(providerName: "User key", apiKeyReference: "keychain://hive", enabled: true)
            )),
            .cloudWithUserKey
        )
        XCTAssertEqual(router.aiStatusLabel(for: .deterministicLocalRules), "Indexed Wiki")
        XCTAssertEqual(router.aiStatusLabel(for: .tinyLocalModel), "On-device helper")
        XCTAssertEqual(router.aiStatusLabel(for: .appleFoundationModels), "Local AI")
        XCTAssertEqual(AIBackendAvailability(platform: .iPhoneOrIPad).userFacingStatus, "Indexed Wiki")

        let source = SourceRecord(
            id: "source",
            kind: .text,
            connector: "manual",
            uri: "hive://manual",
            title: "Manual thought",
            mimeType: "text/plain",
            sizeBytes: 10,
            sha256: "hash",
            importedAt: Date(timeIntervalSince1970: 0),
            observedAt: Date(timeIntervalSince1970: 0),
            retentionExpiresAt: Date(timeIntervalSince1970: 10),
            pinned: false,
            privacyLabel: .normal,
            status: .extracted,
            deletionState: .active
        )
        let envelope = router.compile(
            source: source,
            extractedClaims: [],
            existingClaims: [],
            existingEntities: [],
            availability: AIBackendAvailability(platform: .iPhoneOrIPad, coreMLTaskModelAvailable: true),
            now: Date(timeIntervalSince1970: 1)
        )
        XCTAssertEqual(envelope.profile.backend, .coreMLTaskModel)
        XCTAssertEqual(envelope.mutationPolicy, "model-output-is-proposal-only")
    }

    func testFoundationModelFallbackContractsClampCoordinatesAndRejectUnsafeWebContext() async throws {
        XCTAssertEqual(
            HiveFoundationModelsOrchestrator.currentAvailability(mode: .deterministicFallbackOnly),
            .frameworkUnavailable
        )

        let coordinate = GraphCoordinateProposal(
            nodeID: "node",
            x: 2.4,
            y: -4.1,
            label: "Node",
            rationale: "Fixture",
            sourceIDs: ["source"]
        )
        XCTAssertEqual(coordinate.x, 1)
        XCTAssertEqual(coordinate.y, -1)

        let node = GraphNodeRecord(
            id: "node",
            title: "Analytical professional project",
            kind: .topic,
            confidence: 0.8,
            sourceRefs: ["source"]
        )
        let snapshot = HiveGraphSnapshot(nodes: [node], edges: [])
        let plan = GraphReindexPlan(steps: [
            GraphReindexStep(id: "move-node", nodeID: "node", unitX: 2, unitY: -2)
        ])
        let moved = plan.applying(to: snapshot)
        XCTAssertEqual(moved.nodes.first?.x, GraphSemanticAxes.horizontalNodeRange)
        XCTAssertEqual(moved.nodes.first?.y, -GraphSemanticAxes.verticalNodeRange)

        let unsafe = await HiveFoundationModelsOrchestrator(mode: .deterministicFallbackOnly).summarizeOnlineSource(
            sourceID: "source",
            url: URL(string: "http://127.0.0.1/private")!,
            capturedText: "Private material"
        )
        XCTAssertFalse(unsafe.usedFoundationModels)
        XCTAssertEqual(unsafe.proposal.sourceIDs, ["source"])
        XCTAssertEqual(unsafe.fallbackReason, "Unsafe or unapproved URL rejected before local AI.")
    }

    func testWikiMaintenancePlannerCreatesBookkeepingTasks() throws {
        let hive = WikiPageRecord(
            id: "hive",
            title: "Hive",
            markdown: "# Hive\n\nCabin should be linked from here.",
            sourceRefs: [],
            claimRefs: [],
            kind: .project,
            summary: ""
        )
        let cabin = WikiPageRecord(
            id: "cabin",
            title: "Cabin",
            markdown: "# Cabin",
            sourceRefs: [],
            claimRefs: [],
            kind: .project,
            summary: "Cabin project."
        )
        let lint = WikiLintFinding(
            title: "Missing cross-reference: Hive → Cabin",
            detail: "Hive mentions Cabin but does not link it as a wiki relation.",
            severity: "low"
        )
        let contradiction = ContradictionRecord(
            title: "Mac funding",
            claimIDs: ["a", "b"],
            reason: "Claims disagree about current target hardware."
        )

        let tasks = WikiMaintenancePlanner().plan(
            touchedPages: [hive],
            allPages: [hive, cabin],
            lintFindings: [lint],
            contradictions: [contradiction],
            operation: "ingest",
            target: "source:Grant Article"
        )

        XCTAssertTrue(tasks.contains { $0.kind == .updateIndex && $0.pageID == "index" })
        XCTAssertTrue(tasks.contains { $0.kind == .appendLog && $0.detail.contains(#"grep "^## \[" log.md | tail -5"#) })
        XCTAssertTrue(tasks.contains { $0.kind == .refreshSummary && $0.pageID == "hive" })
        XCTAssertTrue(tasks.contains { $0.kind == .addCrossReference && $0.pageID == "hive" })
        XCTAssertTrue(tasks.contains { $0.kind == .reviewContradiction && $0.title.contains("Mac funding") })
    }

    func testWikiLintFindsStaleClaimsMissingCrossReferencesAndResearchGaps() throws {
        let hive = WikiPageRecord(
            id: "hive",
            title: "Hive",
            markdown: "# Hive\n\nCabin should be linked from here.",
            sourceRefs: [],
            claimRefs: [],
            kind: .project,
            summary: "Hive project."
        )
        let cabin = WikiPageRecord(
            id: "cabin",
            title: "Cabin",
            markdown: "# Cabin",
            sourceRefs: [],
            claimRefs: [],
            kind: .project,
            summary: "Cabin project."
        )
        let staleClaim = ClaimRecord(
            id: "stale",
            statement: "The user previously researched Unwritten Concept.",
            sourceRefs: [],
            confidence: 0.92,
            uncertaintyReason: "Fixture",
            relevanceTier: .stale,
            temporalState: TemporalMemoryState(kind: .stale)
        )
        let batteryClaim = ClaimRecord(
            id: "battery",
            statement: "The user mentioned Battery Health while discussing AlDente charging limits.",
            sourceRefs: [],
            confidence: 0.92,
            uncertaintyReason: "Fixture"
        )
        let entity = EntityRecord(
            id: "unwritten",
            name: "Unwritten Concept",
            sourceRefs: [],
            confidence: 0.9
        )
        let batteryEntity = EntityRecord(
            id: "battery",
            name: "Battery Health",
            sourceRefs: [],
            confidence: 0.9
        )
        let review = ReviewQueueItem(
            id: "review",
            targetType: .claim,
            targetID: "stale",
            title: "Clarify Unwritten Concept",
            reason: "Missing confirmation.",
            priority: 90,
            createdAt: Date(timeIntervalSince1970: 100)
        )

        let findings = WikiLintEngine().findings(
            pages: [hive, cabin],
            claims: [staleClaim, batteryClaim],
            entities: [entity, batteryEntity],
            contradictions: [],
            reviewQueue: [review]
        )

        XCTAssertTrue(findings.contains { $0.title.contains("Missing cross-reference") && $0.detail.contains("Cabin") })
        XCTAssertTrue(findings.contains { $0.title == "Stale claim" })
        XCTAssertTrue(findings.contains { $0.title.contains("Missing article: Unwritten Concept") })
        XCTAssertFalse(findings.contains { $0.title.contains("Missing article: Battery Health") })
        XCTAssertTrue(findings.contains { $0.title.contains("Research gap") })
    }

    func testVaultInitializesGitRepoAndAssetDirectory() throws {
        let harness = try makeHarness()

        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.paths.vaultRawAssets.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: harness.paths.vault.appendingPathComponent(".git").path))
        let gitIgnore = try String(contentsOf: harness.paths.vault.appendingPathComponent(".gitignore"), encoding: .utf8)
        XCTAssertTrue(gitIgnore.contains("flower-field/*"))
        XCTAssertTrue(gitIgnore.contains("!flower-field/assets/**"))
    }

    private func makeHarness(
        learningSettingsProvider: @escaping @Sendable () -> HiveLearningSettings = { HiveLearningSettings.defaultValue }
    ) throws -> Harness {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HiveTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        let paths = HivePaths(root: root.appendingPathComponent("Workspace", isDirectory: true))
        try paths.createDirectories()
        let store = try HiveStore(databaseURL: paths.database)
        let ingestion = IngestionCoordinator(
            paths: paths,
            store: store,
            learningSettingsProvider: learningSettingsProvider
        )
        let loop = KnowledgeLoop(store: store, paths: paths, learningSettingsProvider: learningSettingsProvider)
        let controlPlane = ControlPlane(store: store, paths: paths)
        return Harness(root: root, paths: paths, store: store, ingestion: ingestion, loop: loop, controlPlane: controlPlane)
    }

    private func makeTextFile(in root: URL, name: String, text: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func combinedFileText(under root: URL) throws -> String {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var combined = ""
        while let url = enumerator?.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            combined += (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            combined += "\n"
        }
        return combined
    }

    private func combinedStoreText(databaseURL: URL) throws -> String {
        let urls = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm")
        ]
        return urls.reduce(into: "") { combined, url in
            guard let data = try? Data(contentsOf: url) else { return }
            combined += String(decoding: data, as: UTF8.self)
        }
    }

    private func insertEntityBypassingStoreMerge(_ entity: EntityRecord, databaseURL: URL) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil), SQLITE_OK)
        defer { sqlite3_close(db) }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(entity), as: UTF8.self)

        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "INSERT INTO entities(id, source_id, status, updated_at, json) VALUES (?, ?, NULL, ?, ?)", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, entity.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, entity.sourceRefs.first ?? "", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_double(statement, 3, entity.createdAt.timeIntervalSince1970)
        sqlite3_bind_text(statement, 4, json, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
    }

    private func insertClaimBypassingStoreMerge(_ claim: ClaimRecord, databaseURL: URL) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil), SQLITE_OK)
        defer { sqlite3_close(db) }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(claim), as: UTF8.self)

        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "INSERT INTO claims(id, source_id, status, updated_at, json) VALUES (?, ?, ?, ?, ?)", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, claim.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, claim.sourceRefs.first ?? "", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 3, claim.status.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_double(statement, 4, claim.createdAt.timeIntervalSince1970)
        sqlite3_bind_text(statement, 5, json, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
    }

    private func makeChromiumHistoryFixture(in root: URL) throws -> URL {
        let url = root.appendingPathComponent("History.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE urls(url TEXT, title TEXT, visit_count INTEGER, last_visit_time INTEGER)", nil, nil, nil), SQLITE_OK)
        let rows = [
            ("https://example.com/path?secret=1#frag", "Good Page", 4),
            ("https://example.org/second?secret=2#frag", "Good Page Two", 3),
            ("http://localhost:3000/private", "Local Page", 5),
            ("https://blocked.example/topic", "Blocked Page", 7)
        ]
        for row in rows {
            var statement: OpaquePointer?
            XCTAssertEqual(sqlite3_prepare_v2(db, "INSERT INTO urls(url, title, visit_count, last_visit_time) VALUES (?, ?, ?, ?)", -1, &statement, nil), SQLITE_OK)
            sqlite3_bind_text(statement, 1, row.0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, row.1, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int(statement, 3, Int32(row.2))
            sqlite3_bind_int64(statement, 4, 13_000_000_000_000_000)
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
            sqlite3_finalize(statement)
        }
        return url
    }

    private func makeMarkovFixture() -> MarkovFixture {
        let now = Date()
        let sources = [
            makeSource(id: "source-alpha", title: "Alpha research note", now: now),
            makeSource(id: "source-beta", title: "Beta design note", now: now.addingTimeInterval(60)),
            makeSource(id: "source-gamma", title: "Gamma review note", now: now.addingTimeInterval(120))
        ]
        let claims = [
            ClaimRecord(
                id: "claim-alpha-beta",
                statement: "Alpha research creates a dependency on Beta design evidence",
                sourceRefs: ["source-alpha", "source-beta"],
                confidence: 0.82,
                uncertaintyReason: "Fixture"
            ),
            ClaimRecord(
                id: "claim-beta-gamma",
                statement: "Beta design evidence creates a dependency on Gamma review",
                sourceRefs: ["source-beta", "source-gamma"],
                confidence: 0.81,
                uncertaintyReason: "Fixture"
            ),
            ClaimRecord(
                id: "claim-gamma-alpha",
                statement: "Gamma review creates a dependency on Alpha research",
                sourceRefs: ["source-gamma", "source-alpha"],
                confidence: 0.8,
                uncertaintyReason: "Fixture"
            ),
            ClaimRecord(
                id: "claim-atlas-path",
                statement: "Atlas delivery connects Alpha research Beta design and Gamma review into one path",
                sourceRefs: ["source-alpha", "source-beta", "source-gamma"],
                confidence: 0.78,
                uncertaintyReason: "Fixture"
            )
        ]
        let entities = [
            EntityRecord(id: "entity-alpha", name: "Alpha Research", entityType: "topic", sourceRefs: ["source-alpha", "source-gamma"], confidence: 0.78),
            EntityRecord(id: "entity-beta", name: "Beta Design", entityType: "topic", sourceRefs: ["source-alpha", "source-beta"], confidence: 0.77),
            EntityRecord(id: "entity-gamma", name: "Gamma Review", entityType: "topic", sourceRefs: ["source-beta", "source-gamma"], confidence: 0.76)
        ]
        return MarkovFixture(sources: sources, claims: claims, entities: entities)
    }

    private func makeSource(id: String, title: String, now: Date) -> SourceRecord {
        SourceRecord(
            id: id,
            kind: .text,
            uri: "/tmp/\(id).txt",
            title: title,
            mimeType: "text/plain",
            sizeBytes: 128,
            sha256: id,
            importedAt: now,
            observedAt: now,
            retentionExpiresAt: now.addingTimeInterval(14 * 86_400),
            status: .extracted
        )
    }
}

private struct Harness {
    var root: URL
    var paths: HivePaths
    var store: HiveStore
    var ingestion: IngestionCoordinator
    var loop: KnowledgeLoop
    var controlPlane: ControlPlane
}

private struct MarkovFixture {
    var sources: [SourceRecord]
    var claims: [ClaimRecord]
    var entities: [EntityRecord]
}
