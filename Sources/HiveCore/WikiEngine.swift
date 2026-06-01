import Foundation

public struct WikiSection: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var claimRefs: [String]
    public var sourceRefs: [String]

    public init(id: String, title: String, body: String, claimRefs: [String], sourceRefs: [String]) {
        self.id = id
        self.title = title
        self.body = body
        self.claimRefs = claimRefs
        self.sourceRefs = sourceRefs
    }
}

public struct ContradictionRecord: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var claimIDs: [String]
    public var reason: String

    public init(id: String = UUID().uuidString, title: String, claimIDs: [String], reason: String) {
        self.id = id
        self.title = title
        self.claimIDs = claimIDs
        self.reason = reason
    }
}

public struct WikiEngine: Sendable {
    public init() {}

    public func rebuildOverview(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        relationships: [RelationshipRecord],
        feedback: [FeedbackRecord] = []
    ) -> WikiPageRecord {
        let activeSources = sources.filter { $0.deletionState != .fullForgotten }
        let activeClaims = claims.filter { $0.status != .retracted }
        let reviewOnlySourceIDs = Set(activeSources.filter { source in
            source.kind == .browserHistory || source.privacyLabel == .cloudBlocked || source.status == .needsReview
        }.map(\.id))
        let reviewOnlyClaims = activeClaims.filter { claim in
            claim.claimType == "browser-observation" || claim.sourceRefs.contains { reviewOnlySourceIDs.contains($0) }
        }
        let primaryClaims = activeClaims.filter { claim in
            claim.claimType != "graph-insight" && !reviewOnlyClaims.contains(where: { $0.id == claim.id })
        }
        let durableClaims = activeClaims.filter { claim in
            claim.claimType != "browser-observation" && !claim.sourceRefs.contains { reviewOnlySourceIDs.contains($0) }
        }
        let primaryEntities = entities.filter { entity in
            !entity.sourceRefs.contains { reviewOnlySourceIDs.contains($0) }
        }
        let insightClaims = activeClaims.filter { $0.claimType == "graph-insight" }
        let contradictions = detectContradictions(claims: durableClaims)
        let reviewQueue = ReviewQueueBuilder().build(claims: durableClaims, sources: activeSources, feedback: feedback)

        var markdown: [String] = []
        markdown.append("# Overview")
        markdown.append("")
        markdown.append("Updated \(Self.shortDate(Date())).")
        markdown.append("")
        markdown.append("## Claims")
        if primaryClaims.isEmpty {
            markdown.append("No confirmed claims yet.")
        } else {
            for claim in primaryClaims.prefix(12) {
                markdown.append("- \(confidenceLabel(claim.confidence)): \(claim.statement)")
            }
        }

        markdown.append("")
        markdown.append("## Topics")
        if primaryEntities.isEmpty {
            markdown.append("No topics yet.")
        } else {
            for entity in primaryEntities.prefix(12) {
                let title = SourcePresentationModel.cleanTitle(entity.name)
                markdown.append("- \(title.isEmpty ? entity.name.trimmingCharacters(in: .whitespacesAndNewlines) : title) · \(entity.entityType)")
            }
        }

        markdown.append("")
        if !insightClaims.isEmpty {
            markdown.append("## Connections")
            for claim in insightClaims.prefix(8) {
                markdown.append("- \(confidenceLabel(claim.confidence)): \(claim.statement)")
            }
            markdown.append("")
        }

        markdown.append("## Open questions")
        if reviewQueue.isEmpty {
            markdown.append("Nothing needs confirmation right now.")
        } else if reviewQueue.count == 1 {
            markdown.append("- 1 item needs confirmation.")
        } else {
            markdown.append("- \(reviewQueue.count) items need confirmation.")
        }

        markdown.append("")
        markdown.append("## Contradictions")
        if contradictions.isEmpty {
            markdown.append("No contradictions detected.")
        } else {
            for contradiction in contradictions.prefix(8) {
                markdown.append("- \(contradiction.title): \(contradiction.reason)")
            }
        }
        return WikiPageRecord(
            title: "Overview",
            markdown: markdown.joined(separator: "\n"),
            sourceRefs: activeSources.map(\.id),
            claimRefs: activeClaims.map(\.id)
        )
    }

    public func detectContradictions(claims: [ClaimRecord]) -> [ContradictionRecord] {
        let active = claims.filter { $0.status != .retracted }
        let grouped = Dictionary(grouping: active) { normalizedSubject($0.statement) }
        var contradictions: [ContradictionRecord] = []
        for (subject, group) in grouped where group.count > 1 {
            let hasNegation = group.contains { containsNegation($0.statement) }
            let hasPositive = group.contains { !containsNegation($0.statement) }
            let dateTokens = Set(group.flatMap { extractYearTokens($0.statement) })
            if hasNegation && hasPositive {
                contradictions.append(ContradictionRecord(
                    title: subject,
                    claimIDs: group.map(\.id),
                    reason: "Similar claims include both positive and negative wording."
                ))
            } else if dateTokens.count > 1 {
                contradictions.append(ContradictionRecord(
                    title: subject,
                    claimIDs: group.map(\.id),
                    reason: "Similar claims reference different years: \(dateTokens.sorted().joined(separator: ", "))."
                ))
            }
        }
        return contradictions
    }

    public func applyFeedback(_ feedback: FeedbackRecord, claims: [ClaimRecord]) -> [ClaimRecord] {
        claims.map { claim in
            guard feedback.targetType == "claim", feedback.targetID == claim.id else { return claim }
            var updated = claim
            switch feedback.action {
            case .approve:
                updated.status = .active
                updated.confidence = min(1, max(updated.confidence, 0.85))
                updated.uncertaintyReason = "Approved by user."
            case .deny, .delete:
                updated.status = .retracted
                updated.uncertaintyReason = feedback.note.isEmpty ? "Denied by user." : feedback.note
            case .incidental:
                updated.status = .suspect
                updated.confidence = min(updated.confidence, 0.25)
                updated.uncertaintyReason = "Marked incidental by user."
            case .matters:
                updated.confidence = min(1, max(updated.confidence, 0.75))
                updated.uncertaintyReason = "Marked important by user."
            case .askLater:
                updated.status = .suspect
                updated.uncertaintyReason = "User asked Hive to revisit later."
            case .edit, .merge, .split, .forget:
                updated.status = .userCorrected
                updated.uncertaintyReason = feedback.note.isEmpty ? "Changed by user feedback." : feedback.note
            }
            updated.correctionLineage.append(feedback.id)
            return updated
        }
    }

    private func normalizedSubject(_ statement: String) -> String {
        let words = statement
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
            .prefix(5)
        return words.joined(separator: " ")
    }

    private func containsNegation(_ statement: String) -> Bool {
        let lower = statement.lowercased()
        return [" not ", " never ", " no longer ", " cannot ", " can't ", " won't "].contains { lower.contains($0) }
    }

    private func extractYearTokens(_ statement: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\b(19|20)\d{2}\b"#) else { return [] }
        let range = NSRange(statement.startIndex..<statement.endIndex, in: statement)
        return regex.matches(in: statement, range: range).compactMap { match in
            guard let range = Range(match.range, in: statement) else { return nil }
            return String(statement[range])
        }
    }

    private func confidenceLabel(_ confidence: Double) -> String {
        switch confidence {
        case 0.8...: return "knows"
        case 0.70..<0.8: return "suspects"
        default: return "needs confirmation"
        }
    }

    private func sourceKindLabel(_ kind: SourceKind) -> String {
        switch kind {
        case .pdf:
            return "PDF"
        case .browserHistory:
            return "browser history"
        case .browserBookmark:
            return "bookmark"
        case .clipboardExport:
            return "clipboard export"
        case .calendarExport:
            return "calendar export"
        case .taskExport:
            return "task export"
        case .genericFile:
            return "file"
        default:
            return kind.rawValue
        }
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

public struct WikiLintFinding: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var severity: String

    public init(id: String = UUID().uuidString, title: String, detail: String, severity: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
    }
}

public struct WikiLintEngine: Sendable {
    public init() {}

    public func findings(
        pages: [WikiPageRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord] = [],
        contradictions: [ContradictionRecord],
        reviewQueue: [ReviewQueueItem]
    ) -> [WikiLintFinding] {
        var findings: [WikiLintFinding] = []
        let indexedPageIDs: Set<String> = ["index", "log", "overview", "lint-report"]
        let generatedTopicPages = pages.filter { [.topic, .person, .project].contains($0.kind) }
        let articlePages = pages.filter(\.isUserVisibleArticle)
        let pageTitles = Set(articlePages.map { $0.title.lowercased() })
        let pageSlugs = Set(articlePages.map(\.slug))
        for page in generatedTopicPages where !MemoryQualityPolicy.isGeneratedArticleSubstantial(page) {
            findings.append(WikiLintFinding(
                title: "Thin article: \(page.title)",
                detail: "Generated Colony articles need at least \(MemoryQualityPolicy.minimumStandaloneArticleClaimCount) grounded claims before they become standalone pages.",
                severity: "high"
            ))
        }
        for page in articlePages where !indexedPageIDs.contains(page.id) && page.inboundLinks.isEmpty {
            findings.append(WikiLintFinding(
                title: "Orphan page: \(page.title)",
                detail: "No maintained wiki page links to this page yet.",
                severity: "medium"
            ))
        }
        for page in articlePages {
            for target in articlePages where target.id != page.id {
                let mentionsTitle = page.markdown.localizedCaseInsensitiveContains(target.title)
                let alreadyLinked = page.outboundLinks.contains { $0.localizedCaseInsensitiveCompare(target.title) == .orderedSame }
                if mentionsTitle && !alreadyLinked {
                    findings.append(WikiLintFinding(
                        title: "Missing cross-reference: \(page.title) → \(target.title)",
                        detail: "\(page.title) mentions \(target.title) but does not link it as a wiki relation.",
                        severity: "low"
                    ))
                }
            }
        }
        for contradiction in contradictions {
            findings.append(WikiLintFinding(
                title: "Contradiction: \(contradiction.title)",
                detail: contradiction.reason,
                severity: "high"
            ))
        }
        for claim in claims where claim.status != .retracted && (claim.relevanceTier == .stale || claim.temporalState?.kind == .stale) {
            findings.append(WikiLintFinding(
                title: "Stale claim",
                detail: claim.statement,
                severity: "medium"
            ))
        }
        for claim in claims where claim.status == .suspect || claim.confidence < ReviewQueueBuilder.approvalThreshold {
            findings.append(WikiLintFinding(
                title: "Weak claim needs review",
                detail: claim.statement,
                severity: "medium"
            ))
        }
        for entity in entities where entity.confidence >= 0.72 && !WikiPageRecord.shouldSuppressStandaloneGeneratedArticleTitle(entity.name) {
            let slug = WikiPageRecord.slugify(entity.name)
            let hasPage = pageSlugs.contains(slug) || pageTitles.contains(entity.name.lowercased())
            let hasClaimMention = claims.contains { $0.statement.localizedCaseInsensitiveContains(entity.name) }
            if hasClaimMention && !hasPage {
                findings.append(WikiLintFinding(
                    title: "Missing article: \(entity.name)",
                    detail: "\(entity.name) appears in maintained claims but does not have its own compiled page.",
                    severity: "medium"
                ))
            }
        }
        for item in reviewQueue.prefix(10) {
            findings.append(WikiLintFinding(
                title: "Open question: \(item.title)",
                detail: item.detail.isEmpty ? item.reason : "\(item.detail) \(item.reason)",
                severity: item.priority >= 80 ? "high" : "medium"
            ))
            findings.append(WikiLintFinding(
                title: "Research gap: \(item.title)",
                detail: "A targeted source or user answer could seal this open question.",
                severity: item.priority >= 80 ? "high" : "low"
            ))
        }
        return findings
    }

    public func reportPage(findings: [WikiLintFinding], previous: WikiPageRecord?) -> WikiPageRecord {
        var body: [String] = [
            "# Wiki Health",
            "",
            "Hive checks the maintained wiki for contradictions, stale claims, orphan pages, missing cross-references, missing concept pages, data gaps, weak provenance, and unanswered questions.",
            ""
        ]
        if findings.isEmpty {
            body.append("No concrete issues found.")
        } else {
            body.append("## Findings")
            for finding in findings {
                body.append("- **\(finding.severity)** · \(finding.title): \(finding.detail)")
            }
        }
        return WikiCompiler.makePage(
            id: "lint-report",
            title: "Wiki Health",
            kind: .lintReport,
            summary: findings.isEmpty ? "No concrete wiki health issues found." : "\(findings.count) wiki health findings.",
            body: body.joined(separator: "\n"),
            sourceRefs: [],
            claimRefs: [],
            previous: previous
        )
    }
}

public struct WikiCompiler: Sendable {
    private let wikiEngine = WikiEngine()
    private let lintEngine = WikiLintEngine()

    public init() {}

    public func compile(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        relationships: [RelationshipRecord],
        feedback: [FeedbackRecord],
        auditEvents: [AuditEventRecord],
        previousPages: [WikiPageRecord] = [],
        visibility: DerivedMemoryVisibility = .allowAll
    ) -> [WikiPageRecord] {
        let previousByID = Dictionary(uniqueKeysWithValues: previousPages.map { ($0.id, $0) })
        let activeSources = sources.filter { $0.deletionState != .fullForgotten }
        let allActiveClaims = claims.filter { $0.status != .retracted }
        let activeClaims = allActiveClaims.filter { visibility.shouldCompileClaim($0) || $0.claimType == "graph-insight" }
        let reviewCandidateClaims = allActiveClaims.filter { claim in
            visibility.shouldCompileClaim(claim)
                || visibility.claimDecisions[claim.id]?.tier == .review
                || claim.confidence < ReviewQueueBuilder.approvalThreshold
        }
        let userMeaningfulSourceIDs = userMeaningfulSourceIDs(claims: activeClaims, feedback: feedback)
        let reviewOnlySourceIDs = Set(activeSources.filter { source in
            isReviewOnlySource(source, userMeaningfulSourceIDs: userMeaningfulSourceIDs)
        }.map(\.id))
        let durableClaims = activeClaims.filter { claim in
            !isReviewOnlyClaim(claim, reviewOnlySourceIDs: reviewOnlySourceIDs)
                && !MemoryCompiler.isRawLinkLike(claim.statement)
        }
        let reviewClaims = reviewCandidateClaims.filter { claim in
            !isReviewOnlyClaim(claim, reviewOnlySourceIDs: reviewOnlySourceIDs)
                && !MemoryCompiler.isRawLinkLike(claim.statement)
        }
        let reviewQueue = ReviewQueueBuilder().build(claims: reviewClaims, sources: activeSources, feedback: feedback)
        let contradictions = wikiEngine.detectContradictions(claims: durableClaims)
        let meaningfulSources = activeSources.filter { !reviewOnlySourceIDs.contains($0.id) }
        let currentClaimsByID = Dictionary(uniqueKeysWithValues: activeClaims.map { ($0.id, $0) })
        let meaningfulEntities = entities.filter { entity in
            visibility.shouldCompileEntity(entity)
                && (!entity.sourceRefs.contains { reviewOnlySourceIDs.contains($0) } || isPromotedUserContextEntity(entity))
                && !MemoryCompiler.isRawLinkLike(entity.name)
        }

        var pages: [WikiPageRecord] = []
        pages.append(overviewPage(
            sources: activeSources,
            claims: activeClaims,
            entities: meaningfulEntities,
            contradictions: contradictions,
            reviewQueue: reviewQueue,
            userMeaningfulSourceIDs: userMeaningfulSourceIDs,
            previous: previousByID["overview"]
        ))
        pages.append(contentsOf: entityPages(entities: meaningfulEntities, claims: durableClaims, sources: meaningfulSources, previousByID: previousByID))
        pages.append(synthesisPage(claims: durableClaims, entities: meaningfulEntities, previous: previousByID["synthesis-main"]))
        if !reviewQueue.isEmpty {
            pages.append(openQuestionsPage(reviewQueue: reviewQueue, claims: durableClaims, sources: activeSources, previous: previousByID["open-questions"]))
        }
        if !contradictions.isEmpty {
            pages.append(contradictionsPage(contradictions: contradictions, claims: durableClaims, previous: previousByID["contradictions"]))
        }
        pages.append(contentsOf: previousPages.filter { $0.kind == .answer })
        let generatedPageIDs = Set(pages.map(\.id))
        pages.append(contentsOf: previousPages.filter { page in
            UserWikiEditPolicy.isUserAuthored(page)
                && !generatedPageIDs.contains(page.id)
                && !isCrossContaminatedGeneratedArticle(page, currentClaimsByID: currentClaimsByID)
                && ![WikiPageKind.index, .log, .lintReport, .source, .answer, .question, .contradiction, .synthesis].contains(page.kind)
        })
        pages.removeAll(where: \.isDiscardableBlankGeneratedArticle)
        pages.removeAll { page in
            [.topic, .person, .project].contains(page.kind)
                && !MemoryQualityPolicy.isGeneratedArticleSubstantial(page)
        }
        if pages.filter(\.isUserVisibleArticle).isEmpty {
            pages.append(contentsOf: starterWikiPages(previousByID: previousByID))
        }

        pages = applyLinks(to: pages)
        var lintPage = lintEngine.reportPage(
            findings: lintEngine.findings(pages: pages, claims: activeClaims, entities: meaningfulEntities, contradictions: contradictions, reviewQueue: reviewQueue),
            previous: previousByID["lint-report"]
        )
        lintPage.sourceRefs = Array(Set(activeClaims.flatMap(\.sourceRefs))).sorted()
        lintPage.claimRefs = activeClaims.map(\.id).sorted()
        pages.append(lintPage)
        pages = applyLinks(to: pages)
        pages.append(indexPage(pages: pages, previous: previousByID["index"]))
        pages.append(logPage(auditEvents: auditEvents, previous: previousByID["log"]))
        return applyLinks(to: pages).sorted { left, right in
            if left.kind == right.kind { return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending }
            return pageKindRank(left.kind) < pageKindRank(right.kind)
        }
    }

    public static func makePage(
        id: String,
        title: String,
        kind: WikiPageKind,
        summary: String,
        body: String,
        sourceRefs: [String],
        claimRefs: [String],
        previous: WikiPageRecord?
    ) -> WikiPageRecord {
        let slug = WikiPageRecord.slugify(title)
        let frontmatter = [
            "id": id,
            "kind": kind.rawValue,
            "slug": slug
        ]
        let markdown = frontmatterBlock(frontmatter) + body.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        if let previous, UserWikiEditPolicy.isUserAuthored(previous) {
            var preserved = previous
            preserved.title = previous.title.isEmpty ? title : previous.title
            preserved.kind = kind
            preserved.slug = WikiPageRecord.slugify(preserved.title)
            preserved.summary = previous.summary.isEmpty ? summary : previous.summary
            preserved.sourceRefs = Array(Set(previous.sourceRefs + sourceRefs)).sorted()
            preserved.claimRefs = Array(Set(previous.claimRefs + claimRefs)).sorted()
            preserved.frontmatter["id"] = id
            preserved.frontmatter["kind"] = kind.rawValue
            preserved.frontmatter["slug"] = preserved.slug
            preserved.frontmatter[UserWikiEditPolicy.authorityKey] = UserWikiEditPolicy.authorityValue
            return preserved
        }
        let revision = previous.map { normalized($0.markdown) == normalized(markdown) ? $0.revision : $0.revision + 1 } ?? 1
        return WikiPageRecord(
            id: id,
            title: title,
            markdown: markdown,
            sourceRefs: Array(Set(sourceRefs)).sorted(),
            claimRefs: Array(Set(claimRefs)).sorted(),
            slug: slug,
            kind: kind,
            summary: summary,
            frontmatter: frontmatter,
            revision: revision
        )
    }

    private func userMeaningfulSourceIDs(claims: [ClaimRecord], feedback: [FeedbackRecord]) -> Set<String> {
        let claimByID = Dictionary(uniqueKeysWithValues: claims.map { ($0.id, $0) })
        let meaningfulClaimIDs = Set(feedback.compactMap { record -> String? in
            guard record.targetType == "claim",
                  [.approve, .matters].contains(record.action) else {
                return nil
            }
            return record.targetID
        })
        return Set(meaningfulClaimIDs.compactMap { claimByID[$0] }.flatMap(\.sourceRefs))
    }

    private func starterWikiPages(previousByID: [String: WikiPageRecord]) -> [WikiPageRecord] {
        [
            ("starter-user-profile", "User Profile", "Hive has not learned enough about the user yet. Add Field sources, notes, or direct corrections and this page will become a real profile article."),
            ("starter-projects", "Projects", "Hive has not learned the user's active projects yet. Project evidence will be consolidated here before new project pages are created."),
            ("starter-preferences", "Preferences", "Hive has not learned stable user preferences yet. Preferences should come from repeated behavior, explicit edits, or trusted seed memory."),
            ("starter-education", "Education", "Hive has not learned enough about the user's education yet. Courses, schools, exams, and study context should update this page first."),
            ("starter-health", "Health", "Hive has not learned durable health context yet. Sensitive health memories stay local and require useful, user-centered meaning."),
            ("starter-money-tools", "Money and Tools", "Hive has not learned enough about funding, shopping, hardware, or workflow tools yet. Scattered product traces should consolidate into useful goals.")
        ].map { id, title, sentence in
            Self.makePage(
                id: id,
                title: title,
                kind: title == "Projects" ? .project : .topic,
                summary: "Not enough local memory yet.",
                body: """
                # \(title)

                \(sentence)
                """,
                sourceRefs: [],
                claimRefs: [],
                previous: previousByID[id]
            )
        }
    }

    private func isReviewOnlySource(_ source: SourceRecord, userMeaningfulSourceIDs: Set<String>) -> Bool {
        if userMeaningfulSourceIDs.contains(source.id), source.privacyLabel != .cloudBlocked {
            return false
        }
        return source.kind == .browserHistory
            || source.kind == .browserBookmark
            || source.privacyLabel == .cloudBlocked
            || source.status == .needsReview
    }

    private func isReviewOnlyClaim(_ claim: ClaimRecord, reviewOnlySourceIDs: Set<String>) -> Bool {
        if claim.claimType == "user-context-consolidation" || claim.createdBy == "user-instruction" {
            return false
        }
        return claim.claimType == "browser-observation"
            || claim.claimType == "browser-signal"
            || claim.claimType == "browser-session-intent"
            || claim.sourceRefs.contains { reviewOnlySourceIDs.contains($0) }
    }

    private func isPromotedUserContextEntity(_ entity: EntityRecord) -> Bool {
        entity.entityType == "user-context" && entity.confidence >= 0.9
    }

    private func overviewPage(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        contradictions: [ContradictionRecord],
        reviewQueue: [ReviewQueueItem],
        userMeaningfulSourceIDs: Set<String>,
        previous: WikiPageRecord?
    ) -> WikiPageRecord {
        let reviewOnlySourceIDs = Set(sources.filter { source in
            isReviewOnlySource(source, userMeaningfulSourceIDs: userMeaningfulSourceIDs)
        }.map(\.id))
        let primaryClaims = claims.filter { claim in
            claim.claimType != "graph-insight"
                && claim.confidence >= ReviewQueueBuilder.approvalThreshold
                && claim.claimType != "browser-observation"
                && !claim.sourceRefs.contains { reviewOnlySourceIDs.contains($0) }
        }
        let primaryEntities = entities.filter { entity in
            !entity.sourceRefs.contains { reviewOnlySourceIDs.contains($0) }
        }
        let insightClaims = claims.filter { $0.claimType == "graph-insight" }
        let displayedPrimaryClaims = Array(primaryClaims.prefix(12))
        let displayedInsightClaims = Array(insightClaims.prefix(8))
        let displayedClaimRefs = displayedPrimaryClaims.map(\.id) + displayedInsightClaims.map(\.id)
        let displayedSourceRefs = cappedSourceRefs((displayedPrimaryClaims + displayedInsightClaims).flatMap(\.sourceRefs))
        var body: [String] = [
            "# Overview",
            "",
            "Hive keeps the most useful current knowledge easy to scan, with unresolved questions separated from settled claims.",
            ""
        ]
        body.append("## Claims")
        if displayedPrimaryClaims.isEmpty {
            body.append("No confirmed claims yet.")
        } else {
            for claim in displayedPrimaryClaims {
                body.append("- \(articleSentence(claim.statement))")
            }
        }
        body.append("")
        body.append("## Topics")
        if primaryEntities.isEmpty {
            body.append("No topics yet.")
        } else {
            for entity in primaryEntities.prefix(12) {
                body.append("- [[\(articleTitle(for: entity))]] — \(entity.entityType)")
            }
        }
        if !displayedInsightClaims.isEmpty {
            body.append("")
            body.append("## Connections")
            for claim in displayedInsightClaims {
                body.append("- \(articleSentence(claim.statement))")
            }
        }
        body.append("")
        body.append("## Open questions")
        if reviewQueue.isEmpty {
            body.append("Nothing needs confirmation right now.")
        } else if reviewQueue.count == 1 {
            body.append("- 1 item needs confirmation.")
        } else {
            body.append("- \(reviewQueue.count) items need confirmation.")
        }
        body.append("")
        body.append("## Health")
        body.append(contradictions.isEmpty ? "No contradictions detected." : "\(contradictions.count) contradictions need review in [[Contradictions]].")
        return Self.makePage(
            id: "overview",
            title: "Overview",
            kind: .overview,
            summary: "Current high-level state of the local Hive wiki.",
            body: body.joined(separator: "\n"),
            sourceRefs: displayedSourceRefs,
            claimRefs: displayedClaimRefs,
            previous: previous
        )
    }

    private func entityPages(
        entities: [EntityRecord],
        claims: [ClaimRecord],
        sources: [SourceRecord],
        previousByID: [String: WikiPageRecord]
    ) -> [WikiPageRecord] {
        let currentClaimsByID = Dictionary(uniqueKeysWithValues: claims.map { ($0.id, $0) })
        let sourcesByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        var usedPageIDs = Set<String>()
        return entities
            .sorted {
                if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .compactMap { entity in
            let entityClaims = claims.filter { claim in
                guard claim.claimType != "graph-insight" else { return false }
                return claim.subjectEntityID == entity.id
                    || entityReference(entity.name, appearsIn: claim.statement)
            }
            guard !entityClaims.isEmpty else { return nil }
            let previousTarget = articleTarget(for: entity, claims: entityClaims, previousByID: previousByID)
            let previous = previousTarget.flatMap { page in
                isCrossContaminatedGeneratedArticle(page, currentClaimsByID: currentClaimsByID) ? nil : page
            }
            if WikiPageRecord.shouldSuppressStandaloneGeneratedArticleTitle(entity.name),
               previous.map(UserWikiEditPolicy.isUserAuthored) != true {
                return nil
            }
            let articleSentences = uniqueArticleSentences(from: entityClaims)
            guard MemoryQualityPolicy.supportsStandaloneEntityArticle(
                entity: entity,
                claimSentences: articleSentences,
                previous: previous
            ) else {
                return nil
            }
            let pageID = previous?.id ?? "entity-\(entity.id)"
            guard !usedPageIDs.contains(pageID) else { return nil }
            usedPageIDs.insert(pageID)
            let title = articleTitle(for: entity)
            let related = relatedEntities(for: entity, claims: entityClaims, entities: entities)
            let articleSourceRefs = articleSourceRefs(for: entityClaims, sourcesByID: sourcesByID)
            let lead = articleLead(for: entity, claims: entityClaims)
            var body: [String] = [
                "# \(title)",
                "",
                lead,
                "",
                "## Claims"
            ]
            for sentence in articleSentences.prefix(12) {
                guard normalizedArticleSentence(sentence) != normalizedArticleSentence(lead) else { continue }
                body.append("- \(sentence)")
            }
            if !related.isEmpty {
                body.append("")
                body.append("## Related Concepts")
                for relatedEntity in related.prefix(8) {
                    body.append("- [[\(articleTitle(for: relatedEntity))]]")
                }
            }
            return Self.makePage(
                id: pageID,
                title: title,
                kind: pageKind(for: entity),
                summary: articleSummary(for: entity, claims: entityClaims),
                body: body.joined(separator: "\n"),
                sourceRefs: articleSourceRefs,
                claimRefs: entityClaims.map(\.id),
                previous: previous
            )
        }
    }

    private func entityReference(_ entityName: String, appearsIn statement: String) -> Bool {
        statement.localizedCaseInsensitiveContains(entityName)
            || WikiPageRecord.slugify(statement).contains(WikiPageRecord.slugify(entityName))
    }

    private func articleTarget(
        for entity: EntityRecord,
        claims: [ClaimRecord],
        previousByID: [String: WikiPageRecord]
    ) -> WikiPageRecord? {
        let articlePages = previousByID.values.filter {
            ![WikiPageKind.overview, .synthesis, .index, .log, .lintReport, .source, .answer, .question, .contradiction].contains($0.kind)
        }
        let exactSlug = WikiPageRecord.slugify(entity.name)
        if let exact = articlePages.first(where: { $0.slug == exactSlug || $0.title.localizedCaseInsensitiveCompare(entity.name) == .orderedSame }) {
            return exact
        }
        let scored = articlePages.map { page in
            (page: page, score: articleMergeScore(entity: entity, claims: claims, page: page))
        }
        return scored.filter { $0.score >= 0.62 }.max { $0.score < $1.score }?.page
    }

    private func articleMergeScore(entity: EntityRecord, claims: [ClaimRecord], page: WikiPageRecord) -> Double {
        let entityTokens = articleTokens(entity.name + " " + entity.aliases.joined(separator: " "))
        let pageTokens = articleTokens(page.title + " " + page.summary)
        let claimOverlap = Double(Set(page.claimRefs).intersection(Set(claims.map(\.id))).count) * 0.24
        let tokenOverlap: Double
        if entityTokens.isEmpty || pageTokens.isEmpty {
            tokenOverlap = 0
        } else {
            tokenOverlap = Double(entityTokens.intersection(pageTokens).count) / Double(max(entityTokens.count, pageTokens.count))
        }
        return min(1, claimOverlap + tokenOverlap)
    }

    private func articleTokens(_ text: String) -> Set<String> {
        Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !["user", "with", "from", "that", "this", "into", "their"].contains($0) })
    }

    private func isCrossContaminatedGeneratedArticle(
        _ page: WikiPageRecord,
        currentClaimsByID: [String: ClaimRecord]
    ) -> Bool {
        guard [.topic, .person, .project].contains(page.kind) else { return false }
        guard looksLikeGeneratedEntityArticle(page) else { return false }
        let titleTokens = articleTokens(page.title)
        guard !titleTokens.isEmpty else { return true }
        let scopedClaims = page.claimRefs.compactMap { currentClaimsByID[$0] }
        guard !scopedClaims.isEmpty else {
            return true
        }
        return scopedClaims.allSatisfy { claim in
            !claimRelatesToArticleTitle(claim.statement, title: page.title, titleTokens: titleTokens)
        }
    }

    private func looksLikeGeneratedEntityArticle(_ page: WikiPageRecord) -> Bool {
        let body = WikiPresentationModel.articleBody(from: page.markdown).lowercased()
        return body.contains(" is a topic in the user's local knowledge base")
            || body.contains(" is a project in the user's maintained body of work")
            || body.contains(" is a person represented in the user's local knowledge base")
            || body.contains("## known information")
            || body.contains("## claims")
    }

    private func claimRelatesToArticleTitle(_ statement: String, title: String, titleTokens: Set<String>) -> Bool {
        if statement.localizedCaseInsensitiveContains(title) { return true }
        let statementTokens = articleTokens(statement)
        return !statementTokens.intersection(titleTokens).isEmpty
    }

    private func articleLead(for entity: EntityRecord, claims: [ClaimRecord]) -> String {
        if let first = claims.sorted(by: { $0.confidence > $1.confidence }).first {
            return articleSentence(first.statement)
        }
        return "\(entity.name)."
    }

    private func articleTitle(for entity: EntityRecord) -> String {
        let cleaned = SourcePresentationModel.cleanTitle(entity.name)
        return cleaned.isEmpty ? entity.name.trimmingCharacters(in: .whitespacesAndNewlines) : cleaned
    }

    private func articleSummary(for entity: EntityRecord, claims: [ClaimRecord]) -> String {
        if let strongest = claims.sorted(by: { $0.confidence > $1.confidence }).first {
            return String(articleSentence(strongest.statement).prefix(150))
        }
        return "\(entity.name) article."
    }

    private func relatedEntities(for entity: EntityRecord, claims: [ClaimRecord], entities: [EntityRecord]) -> [EntityRecord] {
        let claimText = claims.map(\.statement).joined(separator: " ")
        return entities.filter { candidate in
            candidate.id != entity.id
                && !WikiPageRecord.shouldSuppressStandaloneGeneratedArticleTitle(candidate.name)
                && entityReference(candidate.name, appearsIn: claimText)
        }
        .sorted {
            if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func articleSentence(_ statement: String) -> String {
        var cleaned = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("knows:") {
            cleaned = String(cleaned.dropFirst("knows:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
            cleaned += "."
        }
        return cleaned
    }

    private func normalizedArticleSentence(_ statement: String) -> String {
        articleSentence(statement)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func articleSourceRefs(
        for claims: [ClaimRecord],
        sourcesByID: [String: SourceRecord]
    ) -> [String] {
        let ranked = claims
            .flatMap(\.sourceRefs)
            .reduce(into: [String: Int]()) { counts, id in
                counts[id, default: 0] += 1
            }
            .map { id, count in
                (id: id, count: count, source: sourcesByID[id])
            }
            .sorted { left, right in
                if left.count != right.count { return left.count > right.count }
                let leftDate = left.source?.importedAt ?? .distantPast
                let rightDate = right.source?.importedAt ?? .distantPast
                if leftDate != rightDate { return leftDate > rightDate }
                return left.id < right.id
            }
        return ranked.prefix(24).map(\.id)
    }

    private func uniqueArticleSentences(from claims: [ClaimRecord]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for claim in claims.sorted(by: { left, right in
            if left.confidence != right.confidence { return left.confidence > right.confidence }
            return left.createdAt > right.createdAt
        }) {
            let sentence = articleSentence(claim.statement)
            let key = sentence
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard seen.insert(key).inserted else { continue }
            output.append(sentence)
        }
        return output
    }

    private func synthesisPage(claims: [ClaimRecord], entities: [EntityRecord], previous: WikiPageRecord?) -> WikiPageRecord {
        let strongest = claims.filter { $0.claimType != "graph-insight" }.sorted { $0.confidence > $1.confidence }.prefix(12)
        let strongestClaims = Array(strongest)
        var body: [String] = [
            "# Synthesis",
            "",
            "This is Hive's concise read on the strongest maintained knowledge.",
            "",
            "## Strongest Claims"
        ]
        if strongestClaims.isEmpty {
            body.append("No strong claims yet.")
        } else {
            for claim in strongestClaims {
                body.append("- \(confidenceLabel(claim.confidence)): \(claim.statement)")
            }
        }
        body.append("")
        body.append("## Active Topics")
        if entities.isEmpty {
            body.append("No active topics yet.")
        } else {
            for entity in entities
                .filter({ !WikiPageRecord.shouldSuppressStandaloneGeneratedArticleTitle($0.name) })
                .sorted(by: { $0.confidence > $1.confidence })
                .prefix(12) {
                body.append("- [[\(articleTitle(for: entity))]]")
            }
        }
        return Self.makePage(
            id: "synthesis-main",
            title: "Synthesis",
            kind: .synthesis,
            summary: "The strongest current synthesis across the local Hive wiki.",
            body: body.joined(separator: "\n"),
            sourceRefs: cappedSourceRefs(strongestClaims.flatMap(\.sourceRefs)),
            claimRefs: strongestClaims.map(\.id),
            previous: previous
        )
    }

    private func cappedSourceRefs(_ refs: [String], limit: Int = 24) -> [String] {
        Array(Array(Set(refs)).sorted().prefix(limit))
    }

    private func openQuestionsPage(
        reviewQueue: [ReviewQueueItem],
        claims: [ClaimRecord],
        sources: [SourceRecord],
        previous: WikiPageRecord?
    ) -> WikiPageRecord {
        var body: [String] = ["# Open Questions", "", "Hive asks only when understood wiki content is below the confidence threshold.", ""]
        for item in reviewQueue {
            body.append("## \(item.title)")
            if !item.detail.isEmpty { body.append(item.detail) }
            body.append("- Reason: \(item.reason)")
            body.append("")
        }
        return Self.makePage(
            id: "open-questions",
            title: "Open Questions",
            kind: .question,
            summary: "\(reviewQueue.count) items need confirmation.",
            body: body.joined(separator: "\n"),
            sourceRefs: Array(Set(reviewQueue.flatMap(\.sourceRefs))),
            claimRefs: reviewQueue.map(\.targetID),
            previous: previous
        )
    }

    private func contradictionsPage(contradictions: [ContradictionRecord], claims: [ClaimRecord], previous: WikiPageRecord?) -> WikiPageRecord {
        let claimsByID = Dictionary(uniqueKeysWithValues: claims.map { ($0.id, $0) })
        var body: [String] = ["# Contradictions", "", "Hive keeps conflicting claims visible until they are corrected or resolved.", ""]
        for contradiction in contradictions {
            body.append("## \(contradiction.title)")
            body.append(contradiction.reason)
            for id in contradiction.claimIDs {
                if let claim = claimsByID[id] {
                    body.append("- \(claim.statement)")
                }
            }
            body.append("")
        }
        return Self.makePage(
            id: "contradictions",
            title: "Contradictions",
            kind: .contradiction,
            summary: "\(contradictions.count) contradiction groups need review.",
            body: body.joined(separator: "\n"),
            sourceRefs: Array(Set(contradictions.compactMap { $0.claimIDs.first }.compactMap { claimsByID[$0]?.sourceRefs }.flatMap { $0 })),
            claimRefs: contradictions.flatMap(\.claimIDs),
            previous: previous
        )
    }

    private func indexPage(pages: [WikiPageRecord], previous: WikiPageRecord?) -> WikiPageRecord {
        let controlKinds: Set<WikiPageKind> = [.overview, .lintReport, .question, .contradiction, .synthesis, .answer]
        let visiblePages = pages.filter { page in
            ![WikiPageKind.index, .log, .source].contains(page.kind)
                && (page.isUserVisibleArticle || controlKinds.contains(page.kind))
        }
        var body: [String] = [
            "# Index",
            "",
            "Content-oriented catalog of the maintained Hive wiki. Read this first to choose which articles to inspect before answering a query.",
            ""
        ]
        for kind in WikiPageKind.allCases where ![.index, .log, .source].contains(kind) {
            let group = visiblePages.filter { $0.kind == kind }
            guard !group.isEmpty else { continue }
            body.append("## \(sectionTitle(for: kind))")
            for page in group.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }) {
                body.append("- [[\(page.title)]] — \(indexSummary(for: page))")
            }
            body.append("")
        }
        return Self.makePage(
            id: "index",
            title: "Index",
            kind: .index,
            summary: "\(visiblePages.count) maintained Colony articles.",
            body: body.joined(separator: "\n"),
            sourceRefs: Array(Set(visiblePages.flatMap(\.sourceRefs))),
            claimRefs: Array(Set(visiblePages.flatMap(\.claimRefs))),
            previous: previous
        )
    }

    private func logPage(auditEvents: [AuditEventRecord], previous: WikiPageRecord?) -> WikiPageRecord {
        let events = auditEvents.sorted { $0.timestamp < $1.timestamp }.suffix(240)
        var body: [String] = [
            "# Log",
            "",
            #"Append-style chronological record of Hive maintenance. Parse with `grep "^## \[" log.md | tail -5` to see the latest five entries."#,
            ""
        ]
        if events.isEmpty {
            body.append("No events yet.")
        } else {
            for event in events {
                body.append("## [\(Self.logDate(event.timestamp))] \(logOperation(for: event)) | \(logTarget(for: event))")
                body.append("- Event: \(event.eventType)")
                if !event.detail.isEmpty {
                    body.append("- Detail: \(event.detail)")
                }
                body.append("")
            }
        }
        return Self.makePage(
            id: "log",
            title: "Log",
            kind: .log,
            summary: "\(events.count) recent maintenance events.",
            body: body.joined(separator: "\n"),
            sourceRefs: Array(Set(events.flatMap(\.sourceRefs))),
            claimRefs: [],
            previous: previous
        )
    }

    private func indexSummary(for page: WikiPageRecord) -> String {
        let summary = page.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let readableSummary = summary.isEmpty ? "No summary yet." : summary
        var metadata: [String] = ["updated \(Self.indexDate(page.updatedAt))"]
        if !page.sourceRefs.isEmpty {
            metadata.append("\(page.sourceRefs.count) sources")
        }
        if !page.claimRefs.isEmpty {
            metadata.append("\(page.claimRefs.count) claims")
        }
        if let tags = page.frontmatter["tags"], !tags.isEmpty {
            metadata.append("tags \(tags)")
        }
        return "\(readableSummary) (\(metadata.joined(separator: " · ")))"
    }

    private func logOperation(for event: AuditEventRecord) -> String {
        if event.eventType.hasPrefix("source.") {
            return "ingest"
        }
        if event.eventType.hasPrefix("wiki.answer") || event.eventType.localizedCaseInsensitiveContains("query") {
            return "query"
        }
        if event.eventType.localizedCaseInsensitiveContains("lint") || event.targetID == "lint-report" {
            return "lint"
        }
        if event.eventType.hasPrefix("wiki.") {
            return "wiki"
        }
        if event.eventType.hasPrefix("memory.") || event.eventType == "knowledge.updated" {
            return "maintenance"
        }
        return event.eventType.components(separatedBy: ".").first ?? event.eventType
    }

    private func logTarget(for event: AuditEventRecord) -> String {
        let target = event.targetID.isEmpty ? event.targetType : "\(event.targetType):\(event.targetID)"
        return SourcePresentationModel.cleanTitle(target)
    }

    private func applyLinks(to pages: [WikiPageRecord]) -> [WikiPageRecord] {
        var titleToID: [String: String] = [:]
        for page in pages {
            titleToID[page.title.lowercased(), default: page.id] = titleToID[page.title.lowercased()] ?? page.id
        }
        var updated = pages.map { page -> WikiPageRecord in
            var copy = page
            copy.outboundLinks = Self.wikilinks(in: page.markdown)
            return copy
        }
        let inbound = updated.reduce(into: [String: [String]]()) { result, page in
            for link in page.outboundLinks {
                guard let targetID = titleToID[link.lowercased()], targetID != page.id else { continue }
                result[targetID, default: []].append(page.id)
            }
        }
        for index in updated.indices {
            updated[index].inboundLinks = Array(Set(inbound[updated[index].id] ?? [])).sorted()
        }
        return updated
    }

    private func sourceKindVisible(_ kind: SourceKind) -> String {
        kind.rawValue.replacingOccurrences(of: "browserHistory", with: "browser history")
    }

    private func summaryForSource(_ source: SourceRecord, claims: [ClaimRecord]) -> String {
        if let strongest = claims.sorted(by: { $0.confidence > $1.confidence }).first {
            return strongest.statement
        }
        return "\(source.title) is a \(sourceKindVisible(source.kind)) source awaiting stronger extracted knowledge."
    }

    private func pageKind(for entity: EntityRecord) -> WikiPageKind {
        switch entity.entityType.lowercased() {
        case "person":
            return .person
        case "project":
            return .project
        case "task", "action":
            return .action
        case "question":
            return .question
        default:
            return .topic
        }
    }

    private func pageKindRank(_ kind: WikiPageKind) -> Int {
        switch kind {
        case .overview: 0
        case .index: 1
        case .synthesis: 2
        case .topic, .person, .project, .action, .question: 3
        case .contradiction: 5
        case .lintReport: 6
        case .answer: 7
        case .source: 8
        case .log: 8
        }
    }

    private func sectionTitle(for kind: WikiPageKind) -> String {
        switch kind {
        case .lintReport:
            return "Health"
        default:
            return kind.rawValue
                .replacingOccurrences(of: "Report", with: " Report")
                .capitalized
        }
    }

    private func article(for word: String) -> String {
        guard let first = word.lowercased().first else { return "a" }
        return ["a", "e", "i", "o", "u"].contains(first) ? "an" : "a"
    }

    private func confidenceLabel(_ confidence: Double) -> String {
        switch confidence {
        case 0.8...:
            return "knows"
        case 0.70..<0.8:
            return "suspects"
        default:
            return "needs confirmation"
        }
    }

    private static func frontmatterBlock(_ values: [String: String]) -> String {
        var lines = ["---"]
        for key in values.keys.sorted() {
            let value = values[key, default: ""].replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("\(key): \"\(value)\"")
        }
        lines.append("---")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func normalized(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func wikilinks(in markdown: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\[\[([^\]]+)\]\]"#) else { return [] }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        return regex.matches(in: markdown, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: markdown) else { return nil }
            return String(markdown[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func logDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private static func indexDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

public final class KnowledgeLoop: @unchecked Sendable {
    private let store: HiveStore
    private let compiler: WikiCompiler
    private let graphEngine: GraphEngine
    private let paths: HivePaths?
    private let learningSettingsProvider: @Sendable () -> HiveLearningSettings

    public init(
        store: HiveStore,
        paths: HivePaths? = nil,
        compiler: WikiCompiler = WikiCompiler(),
        graphEngine: GraphEngine = GraphEngine(),
        learningSettingsProvider: @escaping @Sendable () -> HiveLearningSettings = { HiveLearningSettingsStore.load() }
    ) {
        self.store = store
        self.paths = paths
        self.compiler = compiler
        self.graphEngine = graphEngine
        self.learningSettingsProvider = learningSettingsProvider
    }

    @discardableResult
    public func updateDerivedKnowledge() throws -> HiveGraphSnapshot {
        let sources = try store.fetchSources()
        let aiMemorySourceIDs = Set(sources.filter {
            $0.connector == "ai-memory-import"
                || $0.title.localizedCaseInsensitiveContains("AI Memory Seed")
                || $0.title.localizedCaseInsensitiveContains("# HIVE MEMORY SEED")
        }.map(\.id))
        if !aiMemorySourceIDs.isEmpty {
            _ = try store.deleteAutogeneratedDerivedDataForMemoryImports(sourceIDs: aiMemorySourceIDs)
        }
        let fetchedClaims = try store.fetchClaims()
        for insight in fetchedClaims where insight.claimType == "graph-insight" {
            try store.deleteClaim(id: insight.id)
        }
        let mergedClaimCount = try store.dedupeClaims()
        var claims = try store.fetchClaims().filter { $0.claimType != "graph-insight" }
        let mergedEntityCount = try store.dedupeEntities()
        var entities = try store.fetchEntities().filter { EntitySignalPolicy.isMeaningfulName($0.name) }
        var feedback = try store.fetchFeedback()
        var auditEvents = try store.fetchAuditEvents()
        var previousPages = try store.fetchWikiPages()
        if let paths {
            let vault = WikiVaultManager(paths: paths)
            if try applyExternalUserWikiEdits(vault: vault, previousPages: previousPages, existingClaims: claims, existingFeedback: feedback) {
                for insight in try store.fetchClaims(includeRetracted: true) where insight.claimType == "graph-insight" {
                    try store.deleteClaim(id: insight.id)
                }
                _ = try store.dedupeClaims()
                _ = try store.dedupeEntities()
                claims = try store.fetchClaims().filter { $0.claimType != "graph-insight" }
                entities = try store.fetchEntities().filter { EntitySignalPolicy.isMeaningfulName($0.name) }
                feedback = try store.fetchFeedback()
                auditEvents = try store.fetchAuditEvents()
                previousPages = try store.fetchWikiPages()
            }
        }

        let selfHealing = MemorySelfHealingEngine().heal(
            sources: sources,
            claims: claims,
            entities: entities,
            feedback: feedback
        )
        if selfHealing.didChange {
            for entity in selfHealing.updatedEntities {
                try store.saveEntity(entity)
            }
            for claim in selfHealing.updatedClaims {
                try store.saveClaim(claim)
            }
            for oldEntityID in selfHealing.entityRemapIDs.keys {
                try store.deleteEntity(id: oldEntityID)
            }
            for feedbackRecord in selfHealing.feedbackRecords {
                try store.saveFeedback(feedbackRecord)
            }
            for auditEvent in selfHealing.auditEvents {
                try store.appendAudit(auditEvent)
            }
            claims = try store.fetchClaims().filter { $0.claimType != "graph-insight" }
            entities = try store.fetchEntities().filter { EntitySignalPolicy.isMeaningfulName($0.name) }
            feedback = try store.fetchFeedback()
            auditEvents = try store.fetchAuditEvents()
            previousPages = try store.fetchWikiPages()
        }

        let relevance = MemoryRelevanceEngine().evaluate(
            sources: sources,
            claims: claims,
            entities: entities,
            feedback: feedback
        )
        if relevance.didChange {
            for entity in relevance.updatedEntities {
                try store.saveEntity(entity)
            }
            for claim in relevance.updatedClaims {
                try store.saveClaim(claim)
            }
            for auditEvent in relevance.auditEvents {
                try store.appendAudit(auditEvent)
            }
            claims = try store.fetchClaims().filter { $0.claimType != "graph-insight" }
            entities = try store.fetchEntities().filter { EntitySignalPolicy.isMeaningfulName($0.name) }
            auditEvents = try store.fetchAuditEvents()
            previousPages = try store.fetchWikiPages()
        }
        let visibility = relevance.visibility

        try store.clearRelationships()
        var relationships: [RelationshipRecord] = []
        let learningSettings = learningSettingsProvider()

        let newRelationships = graphEngine.deriveRelationships(
            sources: sources,
            claims: claims,
            entities: entities,
            existing: relationships,
            visibility: visibility,
            learningSettings: learningSettings
        )
        for relationship in newRelationships {
            try store.saveRelationship(relationship)
        }
        relationships.append(contentsOf: newRelationships)

        let insightClaims = MarkovGraphAnalyzer().deriveInsightClaims(
            sources: sources,
            claims: claims.filter { $0.claimType != "supporting-detail" },
            entities: entities,
            relationships: relationships
        )
        for claim in insightClaims {
            try store.saveClaim(claim)
        }
        claims.append(contentsOf: insightClaims)

        var pages = compiler.compile(
            sources: sources,
            claims: claims,
            entities: entities,
            relationships: relationships,
            feedback: feedback,
            auditEvents: auditEvents,
            previousPages: previousPages,
            visibility: visibility
        )
        let deletedWikiPageIDs = Set(feedback.filter {
            $0.targetType == "wikiPage" && ($0.action == .delete || $0.action == .forget)
        }.map(\.targetID))
        if !deletedWikiPageIDs.isEmpty {
            pages.removeAll { page in
                page.isUserVisibleArticle && deletedWikiPageIDs.contains(page.id)
            }
        }
        if let paths {
            let vault = WikiVaultManager(paths: paths)
            pages = vault.pagesWithFilePaths(pages)
            try vault.writeVault(pages: pages)
        }
        try store.pruneWikiPages(keeping: Set(pages.map(\.id)))
        for page in pages {
            try store.saveWikiPage(page)
        }
        let graphSnapshot = graphEngine.buildGraph(
            sources: sources,
            claims: claims,
            entities: entities,
            relationships: relationships,
            suppressedClaimIDs: selfHealing.suppressedGraphClaimIDs.union(visibility.suppressedGraphClaimIDs),
            visibility: visibility
        )
        let suppressedDecisionCount = visibility.claimDecisions.values.filter { !$0.tier.isVisibleDerivedMemory }.count
            + visibility.entityDecisions.values.filter { !$0.tier.isVisibleDerivedMemory }.count
        let substantialArticleCount = pages.filter(\.isUserVisibleArticle).count
        try store.appendAudit(AuditEventRecord(
            eventType: "knowledge.selfChecked",
            targetType: "memory",
            targetID: "quality",
            sourceRefs: Array(Set(pages.flatMap(\.sourceRefs))).sorted(),
            detail: "Hive quality-checked derived knowledge, suppressed \(suppressedDecisionCount) low-signal memories, kept \(substantialArticleCount) substantial Colony articles, and requires user-specific evidence before promoting bare tools or technologies."
        ))
        try store.appendAudit(AuditEventRecord(
            eventType: "graph.coordinatesUpdated",
            targetType: "graph",
            targetID: "semanticAxes",
            sourceRefs: [],
            detail: "The Hive coordinates were refreshed with the local semantic classifier. \(GraphSemanticAxes.semanticSummary)"
        ))
        try store.appendAudit(AuditEventRecord(
            eventType: "knowledge.updated",
            targetType: "wiki",
            targetID: "wiki",
            sourceRefs: Array(Set(pages.flatMap(\.sourceRefs))).sorted(),
            detail: mergedClaimCount + mergedEntityCount > 0
                ? "Claims, relationships, graph, and wiki were refreshed after merging \(mergedClaimCount) duplicate claims and \(mergedEntityCount) duplicate entities."
                : "Claims, relationships, graph, and wiki were refreshed."
        ))
        return graphSnapshot
    }

    private func applyExternalUserWikiEdits(
        vault: WikiVaultManager,
        previousPages: [WikiPageRecord],
        existingClaims: [ClaimRecord],
        existingFeedback: [FeedbackRecord]
    ) throws -> Bool {
        var applied = false
        let pagesByID = Dictionary(uniqueKeysWithValues: previousPages.map { ($0.id, $0) })
        for edit in try vault.detectExternalEdits(pages: previousPages) {
            guard let page = pagesByID[edit.pageID] else { continue }
            let disk = (try? String(contentsOf: URL(fileURLWithPath: edit.filePath), encoding: .utf8)) ?? ""
            let compilation = UserWikiEditPolicy().compile(
                page: page,
                editedMarkdown: disk,
                existingClaims: existingClaims,
                existingFeedback: existingFeedback,
                now: edit.detectedAt
            )
            for claim in compilation.claimsToSave {
                try store.saveClaim(claim)
            }
            for feedback in compilation.feedbackToSave {
                try store.saveFeedback(feedback)
            }
            try store.saveWikiPage(compilation.page)
            for audit in compilation.auditEvents {
                try store.appendAudit(audit)
            }
            try store.appendAudit(AuditEventRecord(
                eventType: "wiki.externalEditApplied",
                targetType: "wikiPage",
                targetID: edit.pageID,
                actor: "user",
                detail: edit.filePath
            ))
            applied = true
        }
        return applied
    }
}
