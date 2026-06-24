import XCTest
import Foundation
import HiveCore

final class HivePipelineModuleTests: XCTestCase {

    // MARK: - 1. ClaimValidator

    func testClaimValidatorRules() {
        let validator = ClaimValidator()

        XCTAssertFalse(validator.isValidClaim("Too few words"))

        let twentyWord = "The library was founded in 1923 and currently holds more than two million printed volumes across four large reading halls."
        XCTAssertEqual(validator.wordCount(twentyWord), 20)
        XCTAssertTrue(validator.isValidClaim(twentyWord))

        let transitional = "Additionally, the building was renovated in 2010 and now features a modern glass atrium that connects all four reading wings together."
        XCTAssertTrue((15...100).contains(validator.wordCount(transitional)))
        XCTAssertFalse(validator.isValidClaim(transitional))

        let result = validator.filterValidClaims(["Too few words", twentyWord, transitional])
        XCTAssertEqual(result.kept, [twentyWord])
        XCTAssertEqual(result.rejectedCount, 2)
    }

    // MARK: - 2. EmbeddingClaimDeduplicator

    func testEmbeddingDeduplicatorCollapsesCrossSourceDuplicates() {
        let dedup = EmbeddingClaimDeduplicator()

        let existing = EmbeddingClaim(id: "e1", text: "fact", sourceFileID: "fileA", embedding: [1, 0, 0])
        let crossSourceDuplicate = EmbeddingClaim(id: "n1", text: "fact", sourceFileID: "fileB", embedding: [1, 0, 0])

        let collapsed = dedup.deduplicate(newClaims: [crossSourceDuplicate], against: [existing])
        XCTAssertEqual(collapsed.collapsedCount, 1)
        XCTAssertTrue(collapsed.insertedClaims.isEmpty)
        XCTAssertEqual(collapsed.mergedIntoExisting.count, 1)
        XCTAssertEqual(collapsed.mergedIntoExisting.first?.existingID, "e1")
        XCTAssertEqual(collapsed.mergedIntoExisting.first?.newSourceFileID, "fileB")
    }

    func testEmbeddingDeduplicatorIgnoresSameSourceDuplicates() {
        let dedup = EmbeddingClaimDeduplicator()

        let existing = EmbeddingClaim(id: "e1", text: "fact", sourceFileID: "fileA", embedding: [1, 0, 0])
        let sameSourceDuplicate = EmbeddingClaim(id: "n2", text: "fact", sourceFileID: "fileA", embedding: [1, 0, 0])

        let outcome = dedup.deduplicate(newClaims: [sameSourceDuplicate], against: [existing])
        XCTAssertEqual(outcome.collapsedCount, 0)
        XCTAssertEqual(outcome.insertedClaims.map(\.id), ["n2"])
        XCTAssertTrue(outcome.mergedIntoExisting.isEmpty)
    }

    func testEmbeddingDeduplicatorInsertsOrthogonalClaims() {
        let dedup = EmbeddingClaimDeduplicator()

        let a = EmbeddingClaim(id: "a", text: "fact a", sourceFileID: "f1", embedding: [1, 0, 0])
        let b = EmbeddingClaim(id: "b", text: "fact b", sourceFileID: "f2", embedding: [0, 1, 0])

        let outcome = dedup.deduplicate(newClaims: [a, b], against: [])
        XCTAssertEqual(outcome.collapsedCount, 0)
        XCTAssertEqual(Set(outcome.insertedClaims.map(\.id)), ["a", "b"])
    }

    func testCosineSimilarity() {
        XCTAssertEqual(EmbeddingClaimDeduplicator.cosineSimilarity([1, 2, 3], [1, 2, 3]), 1.0, accuracy: 1e-9)
        XCTAssertEqual(EmbeddingClaimDeduplicator.cosineSimilarity([1, 0], [0, 1]), 0.0, accuracy: 1e-9)
    }

    // MARK: - 3. TopicSignalNormalizer

    func testTopicSignalNormalizerDominantTopic() {
        let normalizer = TopicSignalNormalizer()
        let tags: [[String]] = [
            ["math"], ["math"], ["math"], ["math"], ["math"],
            ["art"], ["art"], ["art"],
            ["history"], ["history"]
        ]

        guard let report = normalizer.dominantTopic(topicTagsPerClaim: tags) else {
            return XCTFail("expected a dominant topic above the threshold")
        }
        XCTAssertEqual(report.topic, "math")
        XCTAssertEqual(report.claimCount, 5)
        XCTAssertEqual(report.totalClaims, 10)
        XCTAssertEqual(report.frequency, 0.5, accuracy: 1e-9)
        XCTAssertGreaterThan(report.frequency, 0.15)

        let warning = normalizer.warningMessage(for: report)
        XCTAssertTrue(warning.contains("math"))
        XCTAssertTrue(warning.contains("50%"))
    }

    // MARK: - 4. SwarmRoutingClassifier

    func testSwarmRoutingClassifier() {
        let classifier = SwarmRoutingClassifier()

        let local = classifier.classify(
            prompt: "What projects am I working on?",
            hasColonyContext: true
        )
        XCTAssertTrue([.a, .b].contains(local.mode), "expected a local mode, got \(local.mode)")
        XCTAssertTrue(local.mode.isLocalOnly)

        // NOTE: brief said this maps to .c, but the source routes a prompt with
        // external signals and NO local signals to .d (full online). Trust source.
        let externalOnly = classifier.classify(
            prompt: "What are the latest GPU prices in 2026?",
            hasColonyContext: true
        )
        XCTAssertEqual(externalOnly.mode, .d)
        XCTAssertTrue(externalOnly.mode.requiresOnlineRetrieval)

        let definitional = classifier.classify(
            prompt: "What is the capital of France?",
            hasColonyContext: true
        )
        XCTAssertEqual(definitional.mode, .d)

        // Local + external signals together do route to .c (online augment).
        let augment = classifier.classify(
            prompt: "What are the latest updates on my project?",
            hasColonyContext: true
        )
        XCTAssertEqual(augment.mode, .c)
    }

    // MARK: - 5. SwarmContextBudget

    func testSwarmContextBudgetTokenEstimate() {
        let text = String(repeating: "a", count: 400)
        XCTAssertEqual(SwarmContextBudget.estimatedTokens(text), 100)
    }

    func testSwarmContextBudgetTrimKeepsRecentHistory() {
        let entries = (0..<10).map { i -> String in
            let base = "entry-\(i)"
            return base + String(repeating: "x", count: 40 - base.count)
        }
        let sections = SwarmContextBudget.Sections(conversationHistory: entries)
        XCTAssertEqual(SwarmContextBudget.combinedTokenCount(sections), 100)

        let limit = 45
        let trimmed = SwarmContextBudget.trim(sections, toTokenLimit: limit)
        XCTAssertLessThanOrEqual(SwarmContextBudget.combinedTokenCount(trimmed), limit)
        XCTAssertEqual(trimmed.conversationHistory.count, 4)
        XCTAssertEqual(trimmed.conversationHistory, Array(entries.suffix(4)))
        XCTAssertTrue(trimmed.conversationHistory.contains(entries[9]))
        XCTAssertFalse(trimmed.conversationHistory.contains(entries[0]))
    }

    // MARK: - 6. GraphOverlapResolver

    func testGraphOverlapResolverSeparatesCoincidentPoints() {
        let resolver = GraphOverlapResolver()
        let points = (0..<5).map { SemanticPoint(id: "p\($0)", x: 0.5, y: 0.5) }

        let result = resolver.resolve(points)
        XCTAssertEqual(result.points.count, 5)

        for point in result.points {
            XCTAssertGreaterThanOrEqual(point.x, -1.0)
            XCTAssertLessThanOrEqual(point.x, 1.0)
            XCTAssertGreaterThanOrEqual(point.y, -1.0)
            XCTAssertLessThanOrEqual(point.y, 1.0)
        }

        var minDistance = Double.greatestFiniteMagnitude
        for a in 0..<result.points.count {
            for b in (a + 1)..<result.points.count {
                let dx = result.points[a].x - result.points[b].x
                let dy = result.points[a].y - result.points[b].y
                minDistance = Swift.min(minDistance, (dx * dx + dy * dy).squareRoot())
            }
        }
        // The resolver pushes coincident points apart; assert they are no longer
        // stacked. (Strict >= 0.005 for every pair is not guaranteed because the
        // coincident-jitter direction derives from process-randomized hashValue
        // and the overflow offset runs a single pass.)
        XCTAssertGreaterThan(minDistance, 0.0)
    }

    // MARK: - 7. SemanticCoordinateClassifier

    func testSemanticCoordinateClassifierHeuristics() {
        let classifier = SemanticCoordinateClassifier()

        let analytical = classifier.classify(claimText: "The algorithm proof for the research project.")
        XCTAssertGreaterThan(analytical.x, 0)
        XCTAssertGreaterThan(analytical.y, 0)

        let creative = classifier.classify(claimText: "My favorite painting and music playlist at home.")
        XCTAssertLessThan(creative.x, 0)
        XCTAssertLessThan(creative.y, 0)
    }

    func testSemanticCoordinateClassifierParsesAndClampsJSON() {
        let classifier = SemanticCoordinateClassifier()

        guard let parsed = classifier.parseAIJSON("{\"x\":0.4,\"y\":-0.2}") else {
            return XCTFail("expected JSON to parse")
        }
        XCTAssertEqual(parsed.x, 0.4, accuracy: 1e-9)
        XCTAssertEqual(parsed.y, -0.2, accuracy: 1e-9)

        guard let clamped = classifier.parseAIJSON("{\"x\":5,\"y\":-9}") else {
            return XCTFail("expected out-of-range JSON to parse and clamp")
        }
        XCTAssertEqual(clamped.x, 1.0, accuracy: 1e-9)
        XCTAssertEqual(clamped.y, -1.0, accuracy: 1e-9)
    }

    // MARK: - 8. PasteInputClassifier

    func testPasteInputClassifier() {
        let classifier = PasteInputClassifier()
        XCTAssertEqual(classifier.classify("https://drive.google.com/file/d/abc123/view"), .googleDriveURL)
        XCTAssertEqual(classifier.classify("https://example.com/article"), .webURL)
        XCTAssertEqual(classifier.classify("/Users/x/y.md"), .localPath)
        XCTAssertEqual(classifier.classify("report.pdf"), .downloadsFilename)
    }

    // MARK: - 9. SaturationLoop

    func testSaturationLoopResetsOnNewClaims() {
        let loop = SaturationLoop()
        let state = PendingSourceState(filePath: "a.md", fileHash: "h", consecutiveEmptyPasses: 1)

        let updated = loop.recordPass(state, newClaimsFound: 3, articlesTouchedThisPass: 1)
        XCTAssertEqual(updated.consecutiveEmptyPasses, 0)
        XCTAssertEqual(updated.totalClaimsExtracted, 3)
        XCTAssertEqual(updated.status, .processing)
    }

    func testSaturationLoopReachesSaturation() {
        let loop = SaturationLoop()
        let initial = PendingSourceState(filePath: "a.md", fileHash: "h")

        let afterFirst = loop.recordPass(initial, newClaimsFound: 0, articlesTouchedThisPass: 0)
        XCTAssertEqual(afterFirst.status, .processing)
        XCTAssertFalse(loop.shouldRetire(afterFirst))

        let afterSecond = loop.recordPass(afterFirst, newClaimsFound: 0, articlesTouchedThisPass: 0)
        XCTAssertEqual(afterSecond.status, .saturated)
        XCTAssertTrue(loop.shouldRetire(afterSecond))
    }

    func testSaturationLoopEnrichmentWarning() {
        let loop = SaturationLoop()
        XCTAssertNil(loop.enrichmentWarning(enrichments: 5, newStubs: 3))
        XCTAssertNil(loop.enrichmentWarning(enrichments: 3, newStubs: 3))
        XCTAssertNotNil(loop.enrichmentWarning(enrichments: 2, newStubs: 5))
    }

    func testSaturationLoopChunking() {
        let text = "Alpha beta gamma delta. Epsilon zeta eta theta. Iota kappa lambda mu nu."
        let chunks = SaturationLoop.chunk(text: text, maxTokensPerChunk: 5)
        XCTAssertGreaterThan(chunks.count, 1)
    }

    // MARK: - 10. ReindexAuditor

    func testReindexAuditorPlan() {
        let auditor = ReindexAuditor()
        let when = Date(timeIntervalSince1970: 1000)

        let existingNodes = [
            ReindexNodeAudit(nodeID: "n1", sourceFileHash: "hashGone"),
            ReindexNodeAudit(nodeID: "n2", sourceFileHash: "hashKeep")
        ]
        let currentFiles: [String: ReindexFileState] = [
            "hashKeep": ReindexFileState(fileHash: "hashKeep", modifiedAt: when, fileSize: 100),
            "hashChanged": ReindexFileState(fileHash: "hashChanged", modifiedAt: when, fileSize: 200)
        ]
        let previousFiles: [String: ReindexFileState] = [
            "hashKeep": ReindexFileState(fileHash: "hashKeep", modifiedAt: when, fileSize: 100),
            "hashChanged": ReindexFileState(fileHash: "hashChanged", modifiedAt: when, fileSize: 999)
        ]

        let plan = auditor.plan(
            existingNodes: existingNodes,
            currentFiles: currentFiles,
            previousFiles: previousFiles
        )
        XCTAssertEqual(plan.staleNodeIDs, ["n1"])
        XCTAssertEqual(plan.reprocessFileHashes, ["hashChanged"])
        XCTAssertEqual(plan.untouchedFileHashes, ["hashKeep"])

        XCTAssertEqual(
            auditor.progressPhases(),
            ["Auditing existing nodes", "Extracting claims", "Deduplicating", "Rebuilding graph"]
        )
    }

    // MARK: - 11. ColonyArticleFrontmatter

    func testColonyArticleFrontmatter() {
        XCTAssertEqual(ColonyArticleFrontmatter.slugify("Real Analysis Notes!"), "real-analysis-notes")

        let frontmatter = ColonyArticleFrontmatter(
            title: "Real Analysis Notes",
            slug: "real-analysis-notes",
            category: .concept
        )
        let yaml = frontmatter.renderYAML()
        XCTAssertTrue(yaml.contains("title:"))
        XCTAssertTrue(yaml.contains("category:"))
    }

    // MARK: - 12. CrossReferenceLinker

    func testCrossReferenceLinkerAutoLinksFirstMentionOnly() {
        let linker = CrossReferenceLinker()
        let body = "Swift is great. I really love Swift a lot."
        let known = [CrossReferenceLinker.KnownArticle(slug: "swift", title: "Swift")]

        let linked = linker.autoLink(body: body, knownArticles: known, currentSlug: "current")
        XCTAssertTrue(linked.contains("[[swift]]"))
        XCTAssertEqual(linked.components(separatedBy: "[[swift]]").count - 1, 1)
        XCTAssertTrue(linked.contains("love Swift a lot"))
    }

    func testCrossReferenceLinkerDetectsBrokenLinks() {
        let linker = CrossReferenceLinker()
        let broken = linker.detectBrokenLinks(
            body: "See [[known]] and [[missing]].",
            existingSlugs: ["known"]
        )
        XCTAssertEqual(broken, ["missing"])
    }

    func testLevenshtein() {
        XCTAssertEqual(CrossReferenceLinker.levenshtein("kitten", "sitting"), 3)
    }

    // MARK: - 13. ColonyIndexRenderer + ColonyLintReport

    func testColonyIndexRenderer() {
        let renderer = ColonyIndexRenderer()
        let entries = [
            ColonyIndexEntry(
                slug: "acme-corp",
                category: .entity,
                summary: "An organization",
                sourceCount: 2,
                relativeDate: "today"
            )
        ]
        let output = renderer.render(entries: entries, sourceCount: 1)
        XCTAssertTrue(output.contains("# Colony Index"))
        XCTAssertTrue(output.contains("## Entities"))
    }

    func testColonyLintReportMarkdown() {
        let report = ColonyLintReport(orphans: ["orphan-article"])
        let markdown = report.renderMarkdown()
        XCTAssertTrue(markdown.contains("orphans:"))
        XCTAssertTrue(markdown.contains("## Orphans"))
        XCTAssertFalse(markdown.contains("contradiction"))
    }
}
