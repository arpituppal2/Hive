import Foundation

public struct MemoryRelevanceDecision: Codable, Hashable, Sendable {
    public var tier: MemoryImportanceTier
    public var score: Double
    public var temporalState: TemporalMemoryState
    public var reason: String
    public var canonicalTargetID: String?
    public var suppressFromGraph: Bool
    public var suppressFromWiki: Bool
    public var suppressFromChat: Bool

    public init(
        tier: MemoryImportanceTier,
        score: Double,
        temporalState: TemporalMemoryState,
        reason: String,
        canonicalTargetID: String? = nil,
        suppressFromGraph: Bool? = nil,
        suppressFromWiki: Bool? = nil,
        suppressFromChat: Bool? = nil
    ) {
        self.tier = tier
        self.score = min(1, max(0, score))
        self.temporalState = temporalState
        self.reason = reason
        self.canonicalTargetID = canonicalTargetID
        self.suppressFromGraph = suppressFromGraph ?? !tier.isVisibleDerivedMemory
        self.suppressFromWiki = suppressFromWiki ?? !tier.isVisibleDerivedMemory
        self.suppressFromChat = suppressFromChat ?? !tier.isVisibleDerivedMemory
    }
}

public struct DerivedMemoryVisibility: Sendable {
    public var restrictsVisibility: Bool
    public var claimDecisions: [String: MemoryRelevanceDecision]
    public var entityDecisions: [String: MemoryRelevanceDecision]

    public init(
        restrictsVisibility: Bool = true,
        claimDecisions: [String: MemoryRelevanceDecision] = [:],
        entityDecisions: [String: MemoryRelevanceDecision] = [:]
    ) {
        self.restrictsVisibility = restrictsVisibility
        self.claimDecisions = claimDecisions
        self.entityDecisions = entityDecisions
    }

    public static let allowAll = DerivedMemoryVisibility(restrictsVisibility: false)

    public var suppressedGraphClaimIDs: Set<String> {
        Set(claimDecisions.compactMap { id, decision in
            decision.suppressFromGraph ? id : nil
        })
    }

    public func shouldShowClaim(_ claim: ClaimRecord) -> Bool {
        guard restrictsVisibility else { return true }
        return claimDecisions[claim.id]?.suppressFromGraph == false
    }

    public func shouldCompileClaim(_ claim: ClaimRecord) -> Bool {
        guard restrictsVisibility else { return true }
        return claimDecisions[claim.id]?.suppressFromWiki == false
    }

    public func shouldAnswerFromClaim(_ claim: ClaimRecord) -> Bool {
        guard restrictsVisibility else { return true }
        return claimDecisions[claim.id]?.suppressFromChat == false
    }

    public func shouldShowEntity(_ entity: EntityRecord) -> Bool {
        guard restrictsVisibility else { return true }
        return entityDecisions[entity.id]?.suppressFromGraph == false
    }

    public func shouldCompileEntity(_ entity: EntityRecord) -> Bool {
        guard restrictsVisibility else { return true }
        return entityDecisions[entity.id]?.suppressFromWiki == false
    }
}

public struct MemoryRelevanceResult: Sendable {
    public var updatedClaims: [ClaimRecord]
    public var updatedEntities: [EntityRecord]
    public var visibility: DerivedMemoryVisibility
    public var auditEvents: [AuditEventRecord]

    public init(
        updatedClaims: [ClaimRecord] = [],
        updatedEntities: [EntityRecord] = [],
        visibility: DerivedMemoryVisibility = .allowAll,
        auditEvents: [AuditEventRecord] = []
    ) {
        self.updatedClaims = updatedClaims
        self.updatedEntities = updatedEntities
        self.visibility = visibility
        self.auditEvents = auditEvents
    }

    public var didChange: Bool {
        !updatedClaims.isEmpty || !updatedEntities.isEmpty || !auditEvents.isEmpty
    }
}

public struct MemoryRelevanceEngine: Sendable {
    public init() {}

    public func evaluate(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        feedback: [FeedbackRecord] = [],
        now: Date = Date()
    ) -> MemoryRelevanceResult {
        let sourcesByID = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
        let claimsByEntity = Dictionary(grouping: claims) { $0.subjectEntityID ?? "" }
        var claimDecisions: [String: MemoryRelevanceDecision] = [:]
        var entityDecisions: [String: MemoryRelevanceDecision] = [:]
        var updatedClaims: [ClaimRecord] = []
        var updatedEntities: [EntityRecord] = []
        var auditEvents: [AuditEventRecord] = []

        for claim in claims {
            let decision = score(
                claim: claim,
                entity: claim.subjectEntityID.flatMap { id in entities.first { $0.id == id } },
                sources: claim.sourceRefs.compactMap { sourcesByID[$0] },
                feedback: feedback,
                now: now
            )
            claimDecisions[claim.id] = decision
            var copy = claim
            apply(decision, to: &copy)
            if copy != claim {
                updatedClaims.append(copy)
                auditEvents.append(auditEvent(for: decision, targetType: "claim", targetID: claim.id, sourceRefs: claim.sourceRefs, now: now))
            }
        }

        for entity in entities {
            let supportingClaims = claimsByEntity[entity.id] ?? claims.filter {
                entityReference(entity.name, appearsIn: $0.statement)
            }
            let decision = score(
                entity: entity,
                supportingClaims: supportingClaims,
                sources: entity.sourceRefs.compactMap { sourcesByID[$0] },
                feedback: feedback,
                now: now
            )
            entityDecisions[entity.id] = decision
            var copy = entity
            apply(decision, to: &copy)
            if copy != entity {
                updatedEntities.append(copy)
                auditEvents.append(auditEvent(for: decision, targetType: "entity", targetID: entity.id, sourceRefs: entity.sourceRefs, now: now))
            }
        }

        return MemoryRelevanceResult(
            updatedClaims: stableUnique(updatedClaims),
            updatedEntities: stableUnique(updatedEntities),
            visibility: DerivedMemoryVisibility(claimDecisions: claimDecisions, entityDecisions: entityDecisions),
            auditEvents: auditEvents
        )
    }

    public func score(
        claim: ClaimRecord? = nil,
        entity: EntityRecord? = nil,
        sources: [SourceRecord],
        feedback: [FeedbackRecord],
        now: Date = Date()
    ) -> MemoryRelevanceDecision {
        let text = [claim?.statement, entity?.name, entity?.aliases.joined(separator: " ")]
            .compactMap { $0 }
            .joined(separator: " ")
        let sourceText = sources.map { "\($0.title) \($0.uri) \($0.connector)" }.joined(separator: " ")
        let combined = "\(text) \(sourceText)"
        let temporal = temporalState(for: claim, entity: entity, sources: sources, text: combined, now: now)

        if claim?.status == .retracted {
            return decision(.retracted, score: 0, temporal: temporal, reason: "Retracted memories are not visible derived knowledge.", targetID: entity?.id)
        }

        var score = 0.0
        var reasons: [String] = []
        let lower = combined.lowercased()
        let statement = claim?.statement ?? entity?.name ?? ""
        let hasUserPredicate = containsUserPredicate(statement) || containsUserPredicate(combined)
        let sourceOnly = isSourceOnly(text: statement, sources: sources)
        let bareConcept = isBareConcept(statement)
        let userAuthored = isUserAuthored(claim)
        let explicitSeed = isExplicitSeed(claim: claim, entity: entity, sources: sources)
        let durable = containsAny(lower, durableIdentityTerms)
        let activeProject = containsAny(lower, activeProjectTerms)
        let browserOnly = !sources.isEmpty && sources.allSatisfy { $0.kind == .browserHistory || $0.kind == .browserBookmark }
        let inferredUserContext = activeProject && !browserOnly && !sourceOnly
        let recurring = temporal.kind == .recurring
        let currentContext = [.current, .deadline].contains(temporal.kind)
        let repeatedEvidence = independentEvidenceCount(sources: sources, claim: claim, entity: entity) >= 2
        let canonicalEntity = entity?.entityType == "user-context" || claim?.claimType == "user-context-consolidation"

        if userAuthored {
            score += 1.0
            reasons.append("user-authored or user-corrected")
        }
        if explicitSeed {
            score += 0.85
            reasons.append("explicit user-provided seed")
        }
        if durable && hasUserPredicate {
            score += 0.55
            reasons.append("durable user identity, preference, constraint, or goal")
        }
        if activeProject && (hasUserPredicate || !sources.allSatisfy({ $0.kind == .browserHistory || $0.kind == .browserBookmark })) {
            score += 0.55
            reasons.append("active project or workflow")
        }
        if recurring || repeatedEvidence {
            score += 0.40
            reasons.append(recurring ? "recurring context" : "repeated evidence")
        }
        if currentContext {
            score += 0.35
            reasons.append("current time-sensitive context")
        }
        if canonicalEntity {
            score += 0.25
            reasons.append("canonical self-healed user context")
        }
        if let confidence = claim?.confidence ?? entity?.confidence, confidence >= 0.78, hasUserPredicate {
            score += 0.20
            reasons.append("settled high-confidence user statement")
        }

        if isAuthOrNavigation(combined), !userAuthored, !explicitSeed {
            score -= 0.80
            reasons.append("auth, login, navigation, or source-only page")
        }
        if bareConcept && !userAuthored && !explicitSeed && !hasStrongBareConceptSupport(entity: entity, claim: claim, combined: combined) {
            score -= 0.70
            reasons.append("bare noun without a useful predicate about the user")
        }
        if (MemoryCompiler.isRawLinkLike(statement) || sourceOnly), !userAuthored, !explicitSeed {
            score -= 0.60
            reasons.append("domain, link, file, or title-only memory")
        }
        if isSinglePassiveBrowserMention(sources: sources, claim: claim, entity: entity) {
            score -= 0.45
            reasons.append("single passive browser mention")
        }
        if temporal.kind == .stale {
            score -= 0.35
            reasons.append("stale one-off trail without recurrence")
        }

        score = min(1, max(0, score))
        let tier = tierFor(
            score: score,
            temporal: temporal,
            userAuthored: userAuthored,
            explicitSeed: explicitSeed,
            canonicalEntity: canonicalEntity,
            hasUserPredicate: hasUserPredicate || inferredUserContext,
            bareConcept: bareConcept,
            sourceOnly: sourceOnly
        )
        let reason = reasons.isEmpty ? "No strong user-centered relevance signal." : reasons.joined(separator: "; ")
        return decision(tier, score: score, temporal: temporal, reason: reason, targetID: claim?.subjectEntityID ?? entity?.id)
    }

    public func score(
        entity: EntityRecord,
        supportingClaims: [ClaimRecord],
        sources: [SourceRecord],
        feedback: [FeedbackRecord],
        now: Date = Date()
    ) -> MemoryRelevanceDecision {
        let syntheticClaim = supportingClaims
            .filter { $0.status != .retracted }
            .sorted {
                if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
                return $0.createdAt > $1.createdAt
            }
            .first
        let sourceText = sources.map { "\($0.title) \($0.uri) \($0.connector)" }.joined(separator: " ")
        let combined = "\(entity.name) \(entity.aliases.joined(separator: " ")) \(syntheticClaim?.statement ?? "") \(sourceText)"
        let lower = combined.lowercased()
        let browserOnly = !sources.isEmpty && sources.allSatisfy { $0.kind == .browserHistory || $0.kind == .browserBookmark }
        let seedBacked = isExplicitSeed(claim: syntheticClaim, entity: entity, sources: sources)
        let usefulNonBrowserEntity = !browserOnly && (containsAny(lower, activeProjectTerms) || containsAny(lower, durableIdentityTerms))
        if MemoryQualityPolicy.shouldSuppressContextlessEntity(entity, supportingClaims: supportingClaims),
           entity.entityType != "user-context",
           !seedBacked {
            return MemoryRelevanceDecision(
                tier: .incidental,
                score: 0.18,
                temporalState: temporalState(for: nil, entity: entity, sources: sources, text: entity.name, now: now),
                reason: "Contextless tool or framework name has no useful predicate about the user.",
                canonicalTargetID: entity.id
            )
        }
        if isBareConcept(entity.name),
           entity.entityType != "user-context",
           (browserOnly || (!seedBacked && !usefulNonBrowserEntity)) {
            return MemoryRelevanceDecision(
                tier: .incidental,
                score: 0.24,
                temporalState: temporalState(for: nil, entity: entity, sources: sources, text: entity.name, now: now),
                reason: "Bare entity has no useful synthesized statement about the user.",
                canonicalTargetID: entity.id
            )
        }
        let decision = score(claim: syntheticClaim, entity: entity, sources: sources, feedback: feedback, now: now)
        if decision.tier.isVisibleDerivedMemory || syntheticClaim != nil {
            return decision
        }
        return decision
    }

    private func tierFor(
        score: Double,
        temporal: TemporalMemoryState,
        userAuthored: Bool,
        explicitSeed: Bool,
        canonicalEntity: Bool,
        hasUserPredicate: Bool,
        bareConcept: Bool,
        sourceOnly: Bool
    ) -> MemoryImportanceTier {
        if temporal.kind == .stale, !userAuthored, !explicitSeed, !canonicalEntity {
            return .stale
        }
        if userAuthored || explicitSeed || canonicalEntity, score >= 0.80 {
            return .canonical
        }
        if score >= 0.80, hasUserPredicate, !sourceOnly {
            return .active
        }
        if score >= 0.55, hasUserPredicate, !bareConcept, !sourceOnly {
            return .supporting
        }
        if score >= 0.55 {
            return .review
        }
        return temporal.kind == .stale ? .stale : .incidental
    }

    private func decision(
        _ tier: MemoryImportanceTier,
        score: Double,
        temporal: TemporalMemoryState,
        reason: String,
        targetID: String?
    ) -> MemoryRelevanceDecision {
        MemoryRelevanceDecision(
            tier: tier,
            score: score,
            temporalState: temporal,
            reason: reason,
            canonicalTargetID: targetID
        )
    }

    private func apply(_ decision: MemoryRelevanceDecision, to claim: inout ClaimRecord) {
        claim.relevanceTier = decision.tier
        claim.relevanceScore = decision.score
        claim.relevanceReason = decision.reason
        claim.temporalState = decision.temporalState
        claim.canonicalTargetID = decision.canonicalTargetID
    }

    private func apply(_ decision: MemoryRelevanceDecision, to entity: inout EntityRecord) {
        entity.relevanceTier = decision.tier
        entity.relevanceScore = decision.score
        entity.relevanceReason = decision.reason
        entity.temporalState = decision.temporalState
        entity.canonicalTargetID = decision.canonicalTargetID
    }

    private func temporalState(
        for claim: ClaimRecord?,
        entity: EntityRecord?,
        sources: [SourceRecord],
        text: String,
        now: Date
    ) -> TemporalMemoryState {
        let observed = ([claim?.createdAt, entity?.createdAt] + sources.map(\.observedAt)).compactMap { $0 }.min()
        let lastSeen = ([claim?.createdAt, entity?.createdAt] + sources.map(\.observedAt)).compactMap { $0 }.max()
        let lower = text.lowercased()
        let sourceOnlyBrowser = !sources.isEmpty && sources.allSatisfy { $0.kind == .browserHistory || $0.kind == .browserBookmark }
        let age = lastSeen.map { now.timeIntervalSince($0) } ?? 0

        let kind: TemporalMemoryKind
        let recurrence: String?
        let stalenessPolicy: String
        if containsAny(lower, deadlineTerms) {
            kind = .deadline
            recurrence = nil
            stalenessPolicy = "active-until-deadline-or-user-correction"
        } else if containsAny(lower, recurringTerms) {
            kind = .recurring
            recurrence = "recurring"
            stalenessPolicy = "retain-while-reinforced-or-user-corrected"
        } else if containsAny(lower, currentTerms) {
            kind = .current
            recurrence = nil
            stalenessPolicy = "retain-while-current-or-user-corrected"
        } else if sourceOnlyBrowser && age > 48 * 3_600 {
            kind = .stale
            recurrence = nil
            stalenessPolicy = "hide-from-derived-surfaces-after-48-hours-without-recurrence"
        } else if sourceOnlyBrowser {
            kind = .oneOff
            recurrence = nil
            stalenessPolicy = "needs-recurrence-or-user-confirmation-to-promote"
        } else if containsYear(lower) {
            kind = .historical
            recurrence = nil
            stalenessPolicy = "historical-record-unless-contradicted"
        } else {
            kind = .unknown
            recurrence = nil
            stalenessPolicy = "retain-until-user-or-self-healing-changes"
        }

        return TemporalMemoryState(
            kind: kind,
            observedAt: observed,
            eventDate: nil,
            validFrom: kind == .current || kind == .recurring ? observed : nil,
            validUntil: nil,
            lastSeenAt: lastSeen,
            lastConfirmedAt: isUserAuthored(claim) ? claim?.createdAt : nil,
            recurrence: recurrence,
            stalenessPolicy: stalenessPolicy
        )
    }

    private func auditEvent(
        for decision: MemoryRelevanceDecision,
        targetType: String,
        targetID: String,
        sourceRefs: [String],
        now: Date
    ) -> AuditEventRecord {
        let eventType: String
        switch decision.tier {
        case .canonical, .active, .supporting:
            eventType = decision.tier == .canonical ? "memory.promotedAsCanonical" : "memory.relevanceScored"
        case .review:
            eventType = "memory.needsRelevanceReview"
        case .stale:
            eventType = "memory.markedStale"
        case .incidental:
            eventType = "memory.suppressedAsIncidental"
        case .retracted:
            eventType = "memory.relevanceScored"
        }
        return AuditEventRecord(
            id: "memory-relevance-\(Self.shortHash("\(targetType)|\(targetID)|\(decision.tier.rawValue)|\(decision.reason)"))",
            eventType: eventType,
            targetType: targetType,
            targetID: targetID,
            sourceRefs: sourceRefs,
            timestamp: now,
            detail: "\(decision.tier.rawValue): \(decision.reason)"
        )
    }

    private func isUserAuthored(_ claim: ClaimRecord?) -> Bool {
        guard let claim else { return false }
        return claim.createdBy == "user"
            || claim.createdBy == "user-wiki-edit"
            || claim.status == .userCorrected
            || claim.claimType == "user-authored-wiki"
    }

    private func isExplicitSeed(claim: ClaimRecord?, entity: EntityRecord?, sources: [SourceRecord]) -> Bool {
        let claimSeed = claim.map {
            $0.createdBy == "ai-memory-seed"
                || $0.createdBy == "user-instruction"
                || $0.claimType.contains("memory-seed")
                || $0.claimType == "user-context-consolidation"
        } ?? false
        let entitySeed = entity.map { $0.entityType == "user-context" && $0.confidence >= 0.9 } ?? false
        let sourceSeed = sources.contains {
            $0.connector == "local-memory-seed"
                || $0.connector == "ai-memory-import"
                || $0.uri.contains("hive-seed://")
        }
        return claimSeed || entitySeed || sourceSeed
    }

    private func containsUserPredicate(_ text: String) -> Bool {
        MemoryQualityPolicy.containsUserPredicate(text)
    }

    private func isBareConcept(_ text: String) -> Bool {
        let normalizedTokens = tokens(text)
        guard normalizedTokens.count <= 2 else { return false }
        let lower = normalizedTokens.joined(separator: " ")
        if lower.contains("student") || lower.contains("goal") || lower.contains("preference") {
            return false
        }
        return true
    }

    private func hasStrongBareConceptSupport(entity: EntityRecord?, claim: ClaimRecord?, combined: String) -> Bool {
        if entity?.entityType == "user-context" { return true }
        if claim?.claimType == "user-context-consolidation" { return true }
        return containsUserPredicate(combined)
            && containsAny(combined.lowercased(), durableIdentityTerms + activeProjectTerms)
    }

    private func isSourceOnly(text: String, sources: [SourceRecord]) -> Bool {
        let cleaned = SourcePresentationModel.cleanTitle(text)
        guard !cleaned.isEmpty else { return true }
        if MemoryCompiler.isRawLinkLike(cleaned) { return true }
        if sources.contains(where: { source in
            cleaned.caseInsensitiveCompare(SourcePresentationModel.cleanTitle(source.title)) == .orderedSame
                || cleaned.caseInsensitiveCompare(SourcePresentationModel.sourceName(for: source)) == .orderedSame
        }) {
            return !containsUserPredicate(cleaned)
        }
        return false
    }

    private func isAuthOrNavigation(_ text: String) -> Bool {
        let lower = text.lowercased()
        return containsAny(lower, [
            "accounts.google", "sign in", "signin", "login", "oauth", "consent",
            "drive.google.com/drive/home", "myactivity.google", "home page",
            "search results", "browser appearance alone is incidental"
        ])
    }

    private func isSinglePassiveBrowserMention(sources: [SourceRecord], claim: ClaimRecord?, entity: EntityRecord?) -> Bool {
        let refs = claim?.sourceRefs ?? entity?.sourceRefs ?? sources.map(\.id)
        guard refs.count <= 1, sources.count <= 1 else { return false }
        guard let source = sources.first else { return false }
        return (source.kind == .browserHistory || source.kind == .browserBookmark)
            && !(claim.map { containsUserPredicate($0.statement) } ?? false)
    }

    private func independentEvidenceCount(sources: [SourceRecord], claim: ClaimRecord?, entity: EntityRecord?) -> Int {
        let ids = Set((claim?.sourceRefs ?? []) + (entity?.sourceRefs ?? []) + sources.map(\.id))
        return ids.count
    }

    private func entityReference(_ entityName: String, appearsIn statement: String) -> Bool {
        let lowerStatement = statement.lowercased()
        let lowerEntity = entityName.lowercased()
        return lowerStatement.contains(lowerEntity)
            || WikiPageRecord.slugify(statement).contains(WikiPageRecord.slugify(entityName))
    }

    private func tokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 && !stopWords.contains($0) }
    }

    private func containsAny(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0) }
    }

    private func containsYear(_ text: String) -> Bool {
        (try? NSRegularExpression(pattern: #"\b(19|20)\d{2}\b"#))
            .map { regex in
                !regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)).isEmpty
            } ?? false
    }

    private func stableUnique(_ claims: [ClaimRecord]) -> [ClaimRecord] {
        var byID: [String: ClaimRecord] = [:]
        for claim in claims { byID[claim.id] = claim }
        return byID.values.sorted { $0.createdAt < $1.createdAt }
    }

    private func stableUnique(_ entities: [EntityRecord]) -> [EntityRecord] {
        var byID: [String: EntityRecord] = [:]
        for entity in entities { byID[entity.id] = entity }
        return byID.values.sorted { $0.createdAt < $1.createdAt }
    }

    private static func shortHash(_ value: String) -> String {
        String(Hashing.sha256(data: Data(value.utf8)).prefix(16))
    }

    private let durableIdentityTerms = [
        "preference", "prefers", "wants", "needs", "constraint", "identity", "student",
        "studies", "owns", "uses", "lives", "height", "weight", "male", "indian",
        "good at", "skill", "career", "goal", "grant", "scholarship", "funding"
    ]

    private let activeProjectTerms = [
        "project", "working on", "building", "app", "startup", "gpu", "quant",
        "model", "python", "course", "class", "current"
    ]

    private let recurringTerms = [
        "always", "often", "recurring", "daily", "weekly", "monthly", "uses", "prefers",
        "keeps", "constantly", "regularly", "workflow"
    ]

    private let currentTerms = [
        "current", "currently", "active", "working on", "building", "trying to",
        "wants", "needs", "applying", "targeting", "enrolled", "class", "course"
    ]

    private let deadlineTerms = [
        "deadline", "due", "scheduled", "final", "finals", "event", "meeting",
        "application", "apply by", "tomorrow", "today"
    ]

    private let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "that", "this", "into", "their",
        "user", "users", "has", "have", "had", "was", "were", "are", "is"
    ]
}
