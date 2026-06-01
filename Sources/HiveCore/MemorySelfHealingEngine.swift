import Foundation

public struct MemorySelfHealingResult: Sendable {
    public var updatedClaims: [ClaimRecord]
    public var updatedEntities: [EntityRecord]
    public var retractedClaimIDs: Set<String>
    public var entityRemapIDs: [String: String]
    public var suppressedGraphClaimIDs: Set<String>
    public var feedbackRecords: [FeedbackRecord]
    public var auditEvents: [AuditEventRecord]

    public init(
        updatedClaims: [ClaimRecord] = [],
        updatedEntities: [EntityRecord] = [],
        retractedClaimIDs: Set<String> = [],
        entityRemapIDs: [String: String] = [:],
        suppressedGraphClaimIDs: Set<String> = [],
        feedbackRecords: [FeedbackRecord] = [],
        auditEvents: [AuditEventRecord] = []
    ) {
        self.updatedClaims = updatedClaims
        self.updatedEntities = updatedEntities
        self.retractedClaimIDs = retractedClaimIDs
        self.entityRemapIDs = entityRemapIDs
        self.suppressedGraphClaimIDs = suppressedGraphClaimIDs
        self.feedbackRecords = feedbackRecords
        self.auditEvents = auditEvents
    }

    public var didChange: Bool {
        !updatedClaims.isEmpty
            || !updatedEntities.isEmpty
            || !retractedClaimIDs.isEmpty
            || !entityRemapIDs.isEmpty
            || !feedbackRecords.isEmpty
            || !auditEvents.isEmpty
    }
}

public struct MemorySelfHealingEngine: Sendable {
    public init() {}

    public func heal(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        relationships _: [RelationshipRecord] = [],
        feedback: [FeedbackRecord] = [],
        now: Date = Date()
    ) -> MemorySelfHealingResult {
        var result = MemorySelfHealingResult()
        let entityConsolidation = consolidateEntities(entities, now: now)
        var workingEntities = entityConsolidation.entities
        result.entityRemapIDs = entityConsolidation.remap
        result.updatedEntities.append(contentsOf: entityConsolidation.updatedEntities)
        result.auditEvents.append(contentsOf: entityConsolidation.auditEvents)

        var remappedClaims: [ClaimRecord] = []
        var workingClaims = claims.map { claim -> ClaimRecord in
            guard let oldID = claim.subjectEntityID, let newID = entityConsolidation.remap[oldID] else { return claim }
            var updated = claim
            updated.subjectEntityID = newID
            updated.correctionLineage.append("self-heal:entity-remap:\(oldID)")
            remappedClaims.append(updated)
            return updated
        }
        result.updatedClaims.append(contentsOf: remappedClaims)

        let bundleConsolidation = consolidateMemoryBundles(
            sources: sources,
            claims: workingClaims,
            entities: workingEntities,
            now: now
        )
        if bundleConsolidation.didChange {
            workingClaims = mergeClaims(workingClaims, with: bundleConsolidation.updatedClaims)
            workingEntities = mergeEntities(workingEntities, with: bundleConsolidation.updatedEntities)
            result.updatedClaims.append(contentsOf: bundleConsolidation.updatedClaims)
            result.updatedEntities.append(contentsOf: bundleConsolidation.updatedEntities)
            result.entityRemapIDs.merge(bundleConsolidation.entityRemapIDs) { current, _ in current }
            result.suppressedGraphClaimIDs.formUnion(bundleConsolidation.suppressedGraphClaimIDs)
            result.auditEvents.append(contentsOf: bundleConsolidation.auditEvents)
        }

        let reassignment = reassignAndFoldClaims(
            claims: workingClaims,
            entities: workingEntities,
            now: now
        )
        workingClaims = reassignment.claims
        workingEntities = reassignment.entities
        result.updatedClaims.append(contentsOf: reassignment.updatedClaims)
        result.updatedEntities.append(contentsOf: reassignment.updatedEntities)
        result.suppressedGraphClaimIDs.formUnion(reassignment.suppressedClaimIDs)
        result.auditEvents.append(contentsOf: reassignment.auditEvents)

        let contradictionHealing = healContradictions(
            claims: workingClaims,
            existingFeedback: feedback,
            now: now
        )
        result.updatedClaims.append(contentsOf: contradictionHealing.updatedClaims)
        result.retractedClaimIDs.formUnion(contradictionHealing.retractedClaimIDs)
        result.feedbackRecords.append(contentsOf: contradictionHealing.feedbackRecords)
        result.auditEvents.append(contentsOf: contradictionHealing.auditEvents)

        result.updatedClaims = stableUniqueClaims(result.updatedClaims)
        result.updatedEntities = stableUniqueEntities(result.updatedEntities)
        if result.didChange {
            result.auditEvents.append(AuditEventRecord(
                id: "memory-self-healed-\(Self.shortHash(result.fingerprint))",
                eventType: "memory.selfHealed",
                targetType: "memory",
                targetID: "canonical-memory",
                timestamp: now,
                detail: "Self-healed \(result.updatedClaims.count) claims, \(result.updatedEntities.count) entities, \(result.entityRemapIDs.count) entity remaps, and \(result.retractedClaimIDs.count) retractions."
            ))
        }
        return result
    }

    private func consolidateEntities(
        _ entities: [EntityRecord],
        now: Date
    ) -> (entities: [EntityRecord], updatedEntities: [EntityRecord], remap: [String: String], auditEvents: [AuditEventRecord]) {
        var canonical: [EntityRecord] = []
        var updatedEntities: [EntityRecord] = []
        var remap: [String: String] = [:]
        var audits: [AuditEventRecord] = []

        for entity in entities.sorted(by: entitySort) {
            if let index = canonical.firstIndex(where: { shouldMergeEntity($0, entity) }) {
                var keeper = canonical[index]
                keeper.aliases = stableUnion(keeper.aliases + entity.aliases + [entity.name])
                    .filter { normalizedName($0) != normalizedName(keeper.name) }
                keeper.sourceRefs = stableUnion(keeper.sourceRefs + entity.sourceRefs)
                keeper.confidence = max(keeper.confidence, entity.confidence)
                keeper.createdAt = min(keeper.createdAt, entity.createdAt)
                canonical[index] = keeper
                updatedEntities.append(keeper)
                remap[entity.id] = keeper.id
                audits.append(AuditEventRecord(
                    id: "memory-entity-consolidated-\(Self.shortHash(entity.id + keeper.id))",
                    eventType: "memory.entityConsolidated",
                    targetType: "entity",
                    targetID: keeper.id,
                    sourceRefs: keeper.sourceRefs,
                    timestamp: now,
                    detail: "Merged \(entity.name) into \(keeper.name)."
                ))
            } else {
                canonical.append(entity)
            }
        }

        return (canonical, updatedEntities, remap, audits)
    }

    private func consolidateMemoryBundles(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        now: Date
    ) -> MemorySelfHealingResult {
        var result = MemorySelfHealingResult()
        let activeSources = sources.filter { $0.deletionState == .active && $0.status != .deleted }
        let appleHardwareSources = activeSources.filter(isAppleMacHardwareEvidence)
        let fundingSources = activeSources.filter(isGrantOrScholarshipEvidence)
        let appleFundingClaims = claims.filter(isAppleMacFundingClaim)
        let appleFundingEntities = entities.filter(isFoldableAppleHardwareEntity)
        let hasAppleIntent = !appleHardwareSources.isEmpty
            || appleFundingClaims.contains { containsAny($0.statement.lowercased(), ["apple", "mac", "macbook", "mac studio"]) }
            || !appleFundingEntities.isEmpty
        let hasFundingIntent = !fundingSources.isEmpty
            || appleFundingClaims.contains { containsAny($0.statement.lowercased(), ["grant", "scholarship", "funding", "zero money", "cash"]) }
        if hasAppleIntent && hasFundingIntent {
            let canonicalEntityID = "entity-mac-studio-funding-goal"
            let canonicalClaimID = "claim-mac-studio-funding-goal"
            let canonicalStatement = "Arpit wants grant or scholarship funding for an M3 Ultra Mac Studio with 512GB RAM to support demanding local AI and development work."
            let sourceRefs = stableUnion(
                appleHardwareSources.map(\.id)
                    + fundingSources.map(\.id)
                    + appleFundingClaims.flatMap(\.sourceRefs)
                    + appleFundingEntities.flatMap(\.sourceRefs)
            )

            var canonicalEntity = entities.first { $0.id == canonicalEntityID }
                ?? EntityRecord(
                    id: canonicalEntityID,
                    name: "Mac Studio Funding Goal",
                    entityType: "user-context",
                    aliases: [],
                    sourceRefs: [],
                    confidence: 1.0,
                    createdAt: now
                )
            canonicalEntity.name = "Mac Studio Funding Goal"
            canonicalEntity.entityType = "user-context"
            canonicalEntity.aliases = stableUnion(canonicalEntity.aliases + [
                "Apple Hardware Funding",
                "Mac upgrade funding",
                "M3 Ultra Mac Studio",
                "512GB RAM Mac Studio",
                "Grant-funded Mac purchase"
            ])
            canonicalEntity.sourceRefs = stableUnion(canonicalEntity.sourceRefs + sourceRefs)
            canonicalEntity.confidence = 1.0
            result.updatedEntities.append(canonicalEntity)

            var canonicalClaim = claims.first { $0.id == canonicalClaimID || normalizedName($0.statement) == normalizedName(canonicalStatement) }
                ?? ClaimRecord(
                    id: canonicalClaimID,
                    statement: canonicalStatement,
                    claimType: "user-context-consolidation",
                    subjectEntityID: canonicalEntityID,
                    sourceRefs: sourceRefs,
                    confidence: 1.0,
                    uncertaintyReason: "Consolidated from repeated Apple hardware, grant, scholarship, and funding evidence.",
                    status: .active,
                    createdBy: "user-instruction",
                    createdAt: now
                )
            canonicalClaim.statement = canonicalStatement
            canonicalClaim.claimType = "user-context-consolidation"
            canonicalClaim.subjectEntityID = canonicalEntityID
            canonicalClaim.sourceRefs = stableUnion(canonicalClaim.sourceRefs + sourceRefs)
            canonicalClaim.confidence = 1.0
            canonicalClaim.status = .active
            canonicalClaim.createdBy = canonicalClaim.createdBy.isEmpty ? "user-instruction" : canonicalClaim.createdBy
            canonicalClaim.uncertaintyReason = "Consolidated from repeated Apple hardware, grant, scholarship, and funding evidence."
            result.updatedClaims.append(canonicalClaim)
            result.suppressedGraphClaimIDs.insert(canonicalClaim.id)

            for entity in appleFundingEntities where entity.id != canonicalEntityID {
                result.entityRemapIDs[entity.id] = canonicalEntityID
                canonicalEntity.aliases = stableUnion(canonicalEntity.aliases + [entity.name] + entity.aliases)
                canonicalEntity.sourceRefs = stableUnion(canonicalEntity.sourceRefs + entity.sourceRefs)
                result.auditEvents.append(AuditEventRecord(
                    id: "memory-entity-consolidated-\(Self.shortHash(entity.id + canonicalEntityID))",
                    eventType: "memory.entityConsolidated",
                    targetType: "entity",
                    targetID: canonicalEntityID,
                    sourceRefs: canonicalEntity.sourceRefs,
                    timestamp: now,
                    detail: "Merged \(entity.name) into Mac Studio Funding Goal."
                ))
            }
            result.updatedEntities.append(canonicalEntity)

            for var claim in appleFundingClaims where claim.id != canonicalClaim.id {
                var changed = false
                if claim.subjectEntityID != canonicalEntityID {
                    claim.subjectEntityID = canonicalEntityID
                    changed = true
                }
                if claim.claimType != "supporting-detail" {
                    claim.claimType = "supporting-detail"
                    changed = true
                }
                if changed {
                    claim.uncertaintyReason = appendSelfHealingNote(
                        to: claim.uncertaintyReason,
                        note: "Folded into Mac Studio Funding Goal by self-healing."
                    )
                    claim.correctionLineage.append("self-heal:bundle:\(canonicalEntityID)")
                    result.updatedClaims.append(claim)
                    result.suppressedGraphClaimIDs.insert(claim.id)
                    result.auditEvents.append(AuditEventRecord(
                        id: "memory-claim-folded-\(Self.shortHash(claim.id + canonicalEntityID))",
                        eventType: "memory.claimFoldedIntoEntity",
                        targetType: "claim",
                        targetID: claim.id,
                        sourceRefs: claim.sourceRefs,
                        timestamp: now,
                        detail: "Folded Apple/Mac funding detail into Mac Studio Funding Goal."
                    ))
                }
            }

            result.auditEvents.append(AuditEventRecord(
                id: "memory-bundle-mac-studio-funding-\(Self.shortHash(sourceRefs.joined(separator: ",")))",
                eventType: "memory.selfHealed",
                targetType: "entity",
                targetID: canonicalEntityID,
                sourceRefs: sourceRefs,
                timestamp: now,
                detail: "Consolidated Apple/Mac hardware and funding evidence into a canonical memory."
            ))
        }

        mergeKnownUserContextBundles(sources: activeSources, claims: claims, entities: entities, now: now, result: &result)
        return result
    }

    private func mergeKnownUserContextBundles(
        sources: [SourceRecord],
        claims: [ClaimRecord],
        entities: [EntityRecord],
        now: Date,
        result: inout MemorySelfHealingResult
    ) {
        let bundles: [UserContextBundleRule] = [
            UserContextBundleRule(
                entityID: "entity-ucla-student",
                claimID: "claim-ucla-student-identity",
                title: "UCLA Student",
                statement: "The user is a UCLA mathematics student.",
                requiredAny: ["ucla"],
                requiredContextAny: ["student", "mathematics", "math", "course", "class", "studying", "gradescope"],
                aliases: ["UCLA", "UCLA mathematics", "UCLA coursework"],
                foldEntityAny: ["ucla"]
            ),
            UserContextBundleRule(
                entityID: "entity-uconsulting-goal",
                claimID: "claim-uconsulting-goal",
                title: "UConsulting Goal",
                statement: "The user is targeting UConsulting at UCLA as part of their consulting career goals.",
                requiredAny: ["uconsulting"],
                requiredContextAny: ["consulting", "career", "ucla", "apply", "target", "application"],
                aliases: ["UConsulting", "UCLA consulting"],
                foldEntityAny: ["uconsulting"]
            ),
            UserContextBundleRule(
                entityID: "entity-python-workflow",
                claimID: "claim-python-workflow",
                title: "Python Workflow",
                statement: "The user uses Python for technical workflows such as quant, model, automation, or data work.",
                requiredAny: ["python"],
                requiredContextAny: ["quant", "model", "automation", "data", "script", "workflow", "training", "stock"],
                aliases: ["Python", "Python automation"],
                foldEntityAny: ["python"]
            ),
            UserContextBundleRule(
                entityID: "entity-cabin-project",
                claimID: "claim-cabin-project",
                title: "Cabin Project",
                statement: "The user is actively building Cabin, a detailed aircraft-cabin project with demanding 3D and UI requirements.",
                requiredAny: ["cabin"],
                requiredContextAny: ["aircraft", "polaris", "3d", "brev", "blender", "cesium", "focusflight", "project"],
                aliases: ["Cabin", "CabinApp"],
                foldEntityAny: ["cabin"]
            ),
            UserContextBundleRule(
                entityID: "entity-hive-product",
                claimID: "claim-hive-product",
                title: "Hive",
                statement: "The user is building Hive as a local-first AI memory app with Field, The Colony, and The Hive surfaces.",
                requiredAny: ["hive"],
                requiredContextAny: ["memory", "wiki", "graph", "raw input", "second brain", "local-first", "ai"],
                aliases: ["Hive Product", "Hive graph", "Hive wiki"],
                foldEntityAny: ["hive"]
            ),
            UserContextBundleRule(
                entityID: "entity-lamt-work",
                claimID: "claim-lamt-work",
                title: "LAMT Work",
                statement: "The user works on the Los Angeles Math Tournament, including tournament operations, problem systems, and event design.",
                requiredAny: ["lamt", "los angeles math tournament"],
                requiredContextAny: ["tournament", "problem", "prose", "ucla", "event", "round"],
                aliases: ["LAMT", "Los Angeles Math Tournament", "LAMT-PROSE"],
                foldEntityAny: ["lamt"]
            ),
            UserContextBundleRule(
                entityID: "entity-brev-gpu-workflow",
                claimID: "claim-brev-gpu-workflow",
                title: "BREV GPU Workflow",
                statement: "The user uses BREV GPU instances for demanding local project workflows.",
                requiredAny: ["brev", "a6000", "gpu"],
                requiredContextAny: ["instance", "cuda", "render", "training", "workflow", "cabin", "compute"],
                aliases: ["BREV", "A6000", "GPU workflow"],
                foldEntityAny: ["brev", "a6000", "gpu"]
            )
        ]

        let evidenceText = normalizedName(
            sources.map { "\($0.title) \($0.uri) \($0.connector)" }.joined(separator: " ")
                + " "
                + claims.map(\.statement).joined(separator: " ")
                + " "
                + entities.flatMap { [$0.name] + $0.aliases }.joined(separator: " ")
        )

        for rule in bundles where rule.matches(evidenceText) {
            let sourceRefs = stableUnion(
                sources.filter { rule.matches(normalizedName("\($0.title) \($0.uri) \($0.connector)")) }.map(\.id)
                    + claims.filter { rule.matches(normalizedName($0.statement)) }.flatMap(\.sourceRefs)
                    + entities.filter { rule.matches(normalizedName(([$0.name] + $0.aliases).joined(separator: " "))) }.flatMap(\.sourceRefs)
            )
            guard !sourceRefs.isEmpty || claims.contains(where: { rule.matches(normalizedName($0.statement)) }) else { continue }

            let existingCanonical = entities.first { $0.id == rule.entityID || normalizedName($0.name) == normalizedName(rule.title) }
                ?? entities.first { rule.shouldFold($0) && $0.entityType != "topic" }
                ?? entities.first { rule.shouldFold($0) }
            let canonicalID = existingCanonical?.id ?? rule.entityID
            var canonicalEntity = existingCanonical
                ?? EntityRecord(
                    id: canonicalID,
                    name: rule.title,
                    entityType: "user-context",
                    aliases: [],
                    sourceRefs: [],
                    confidence: 0.96,
                    createdAt: now
                )
            canonicalEntity.name = rule.title
            canonicalEntity.entityType = "user-context"
            canonicalEntity.aliases = stableUnion(canonicalEntity.aliases + rule.aliases)
            canonicalEntity.sourceRefs = stableUnion(canonicalEntity.sourceRefs + sourceRefs)
            canonicalEntity.confidence = max(canonicalEntity.confidence, 0.96)
            result.updatedEntities.append(canonicalEntity)

            var canonicalClaim = claims.first { $0.id == rule.claimID || normalizedName($0.statement) == normalizedName(rule.statement) }
                ?? ClaimRecord(
                    id: rule.claimID,
                    statement: rule.statement,
                    claimType: "user-context-consolidation",
                    subjectEntityID: canonicalID,
                    sourceRefs: sourceRefs,
                    confidence: 0.96,
                    uncertaintyReason: "Consolidated by user-context bundle self-healing.",
                    status: .active,
                    createdBy: "deterministic-self-healing",
                    createdAt: now
                )
            canonicalClaim.statement = rule.statement
            canonicalClaim.claimType = "user-context-consolidation"
            canonicalClaim.subjectEntityID = canonicalID
            canonicalClaim.sourceRefs = stableUnion(canonicalClaim.sourceRefs + sourceRefs)
            canonicalClaim.confidence = max(canonicalClaim.confidence, 0.96)
            canonicalClaim.status = .active
            result.updatedClaims.append(canonicalClaim)
            result.suppressedGraphClaimIDs.insert(canonicalClaim.id)

            for entity in entities where entity.id != canonicalID && rule.shouldFold(entity) {
                result.entityRemapIDs[entity.id] = canonicalID
                result.auditEvents.append(AuditEventRecord(
                    id: "memory-entity-consolidated-\(Self.shortHash(entity.id + canonicalID))",
                    eventType: "memory.entityConsolidated",
                    targetType: "entity",
                    targetID: canonicalID,
                    sourceRefs: stableUnion(entity.sourceRefs + sourceRefs),
                    timestamp: now,
                    detail: "Merged low-information \(entity.name) into \(rule.title)."
                ))
            }

            result.auditEvents.append(AuditEventRecord(
                id: "memory-bundle-\(Self.shortHash(canonicalID + sourceRefs.joined(separator: ",")))",
                eventType: "memory.selfHealed",
                targetType: "entity",
                targetID: canonicalID,
                sourceRefs: sourceRefs,
                timestamp: now,
                detail: "Consolidated related evidence into \(rule.title)."
            ))
        }
    }

    private func isAppleMacHardwareEvidence(_ source: SourceRecord) -> Bool {
        guard source.deletionState == .active else { return false }
        let text = normalizedName("\(source.title) \(source.uri) \(source.connector)")
        let hasAppleHardware = containsAny(text, [
            "apple", "mac", "macbook", "macbook pro", "mac studio", "m3 ultra", "m4 max",
            "m5 max", "refurbished", "amazon", "ebay"
        ])
        let hasUpgradeOrShoppingSignal = containsAny(text, [
            "512gb", "512 gb", "128gb", "128 gb", "ram", "ultra", "studio", "buy",
            "deals", "products", "discount", "refurbished"
        ])
        return hasAppleHardware && hasUpgradeOrShoppingSignal
    }

    private func isGrantOrScholarshipEvidence(_ source: SourceRecord) -> Bool {
        guard source.deletionState == .active else { return false }
        let text = normalizedName("\(source.title) \(source.uri) \(source.connector)")
        return containsAny(text, [
            "grant", "grants", "scholarship", "scholarships", "funding", "application",
            "applications", "fellowship", "cash"
        ])
    }

    private func isAppleMacFundingClaim(_ claim: ClaimRecord) -> Bool {
        guard claim.status != .retracted else { return false }
        let text = claim.statement.lowercased()
        let hasAppleHardware = containsAny(text, [
            "apple", "mac", "macbook", "macbook pro", "mac studio", "m3 ultra",
            "m4 max", "m5 max", "hardware"
        ])
        let hasFundingOrPurchase = containsAny(text, [
            "grant", "scholarship", "funding", "zero money", "cash", "buy", "purchase",
            "reseller", "used", "discount", "refurbished", "512gb", "512 gb", "128gb", "128 gb"
        ])
        return hasAppleHardware || hasFundingOrPurchase && containsAny(text, ["hardware", "reseller", "ram", "mac"])
    }

    private func isFoldableAppleHardwareEntity(_ entity: EntityRecord) -> Bool {
        let text = normalizedName(([entity.name] + entity.aliases).joined(separator: " "))
        guard text != "mac studio funding goal" else { return false }
        let bareNames: Set<String> = [
            "macbook",
            "macbook pro",
            "m4 macbook",
            "m4 macbook pro",
            "m3 ultra mac studio",
            "mac studio",
            "buy mac",
            "buy mac apple",
            "refurbished mac",
            "refurbished macbook",
            "refurbished macbook pro",
            "apple mac studio",
            "amazon mac studio",
            "ebay mac studio"
        ]
        if bareNames.contains(text) { return true }
        return containsAny(text, ["refurbished mac", "amazon mac", "ebay mac", "buy mac", "mac studio"])
            && !containsAny(text, ["temperature", "thermal", "fan", "workload"])
    }

    private func containsAny(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0) }
    }

    private func mergeClaims(_ base: [ClaimRecord], with updates: [ClaimRecord]) -> [ClaimRecord] {
        var byID = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        for update in updates {
            byID[update.id] = update
        }
        return byID.values.sorted { $0.createdAt < $1.createdAt }
    }

    private func mergeEntities(_ base: [EntityRecord], with updates: [EntityRecord]) -> [EntityRecord] {
        var byID = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        for update in updates {
            byID[update.id] = update
        }
        return byID.values.sorted(by: entitySort)
    }

    private func reassignAndFoldClaims(
        claims: [ClaimRecord],
        entities: [EntityRecord],
        now: Date
    ) -> (
        claims: [ClaimRecord],
        entities: [EntityRecord],
        updatedClaims: [ClaimRecord],
        updatedEntities: [EntityRecord],
        suppressedClaimIDs: Set<String>,
        auditEvents: [AuditEventRecord]
    ) {
        var claimsByIndex = claims
        var entityByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        var updatedClaims: [ClaimRecord] = []
        var updatedEntities: [EntityRecord] = []
        var suppressed = Set<String>()
        var audits: [AuditEventRecord] = []

        for index in claimsByIndex.indices {
            var claim = claimsByIndex[index]
            guard claim.status != .retracted, claim.claimType != "graph-insight" else { continue }
            guard let match = bestEntityMatch(for: claim, entities: Array(entityByID.values)) else { continue }

            let currentSubject = claim.subjectEntityID.flatMap { entityByID[$0] }
            let currentScore = currentSubject.map { entityMatchScore(entity: $0, statement: claim.statement) } ?? 0
            let shouldReassign = claim.subjectEntityID == nil
                || isCategoryHub(currentSubject)
                || match.score >= currentScore + 0.16

            if shouldReassign, claim.subjectEntityID != match.entity.id {
                claim.subjectEntityID = match.entity.id
                claim.correctionLineage.append("self-heal:subject:\(match.entity.id)")
                updatedClaims.append(claim)
            }

            if shouldPromoteInstitutionIdentity(entity: match.entity, claim: claim) {
                var promoted = match.entity
                let baseName = institutionBaseName(promoted)
                let promotedName = "\(baseName) Student"
                if normalizedName(promoted.name) != normalizedName(promotedName) {
                    promoted.aliases = stableUnion(promoted.aliases + [promoted.name])
                    promoted.name = promotedName
                    promoted.confidence = max(promoted.confidence, claim.confidence)
                    entityByID[promoted.id] = promoted
                    updatedEntities.append(promoted)
                    audits.append(AuditEventRecord(
                        id: "memory-entity-promoted-\(Self.shortHash(promoted.id + claim.id))",
                        eventType: "memory.entityConsolidated",
                        targetType: "entity",
                        targetID: promoted.id,
                        sourceRefs: promoted.sourceRefs,
                        timestamp: now,
                        detail: "Promoted \(baseName) into \(promotedName) because the user's student identity claim is stronger than the bare institution node."
                    ))
                }
            }

            let canonicalEntity = claim.subjectEntityID.flatMap { entityByID[$0] } ?? match.entity
            if shouldFoldIntoEntity(claim: claim, entity: canonicalEntity) {
                var foldChanged = false
                if claim.status == .suspect,
                   claim.uncertaintyReason.localizedCaseInsensitiveContains("possible contradiction found by self-healing") {
                    claim.status = .active
                    claim.confidence = max(claim.confidence, 0.88)
                    claim.contradictionGroupID = nil
                    claim.uncertaintyReason = "Restored by self-healing after consolidation showed this is supporting detail, not a contradiction."
                    claim.correctionLineage.append("self-heal:restored-supporting-detail")
                    foldChanged = true
                }
                if claim.claimType != "supporting-detail" {
                    claim.claimType = "supporting-detail"
                    claim.uncertaintyReason = appendSelfHealingNote(
                        to: claim.uncertaintyReason,
                        note: "Folded into \(canonicalEntity.name) by self-healing; preserved as supporting Wiki memory."
                    )
                    claim.correctionLineage.append("self-heal:folded:\(canonicalEntity.id)")
                    updatedClaims.append(claim)
                    audits.append(AuditEventRecord(
                        id: "memory-claim-folded-\(Self.shortHash(claim.id + canonicalEntity.id))",
                        eventType: "memory.claimFoldedIntoEntity",
                        targetType: "claim",
                        targetID: claim.id,
                        sourceRefs: claim.sourceRefs,
                        timestamp: now,
                        detail: "Folded claim into \(canonicalEntity.name)."
                    ))
                    foldChanged = true
                }
                if foldChanged {
                    updatedClaims.append(claim)
                }
                suppressed.insert(claim.id)
            }

            claimsByIndex[index] = claim
        }

        return (
            claimsByIndex,
            entityByID.values.sorted(by: entitySort),
            stableUniqueClaims(updatedClaims),
            stableUniqueEntities(updatedEntities),
            suppressed,
            audits
        )
    }

    private func healContradictions(
        claims: [ClaimRecord],
        existingFeedback: [FeedbackRecord],
        now: Date
    ) -> (
        updatedClaims: [ClaimRecord],
        retractedClaimIDs: Set<String>,
        feedbackRecords: [FeedbackRecord],
        auditEvents: [AuditEventRecord]
    ) {
        let active = claims.filter { $0.status != .retracted && $0.claimType != "graph-insight" }
        let groups = Dictionary(grouping: active, by: contradictionBucket)
        let existingFeedbackKeys = Set(existingFeedback.map { "\($0.targetType)|\($0.targetID)|\($0.action.rawValue)" })
        var updatedClaims: [String: ClaimRecord] = [:]
        var retracted = Set<String>()
        var feedbackRecords: [FeedbackRecord] = []
        var audits: [AuditEventRecord] = []

        for (_, group) in groups where group.count > 1 && group.count <= 16 {
            for leftIndex in group.indices {
                for rightIndex in group.indices.dropFirst(leftIndex + 1) {
                    let left = updatedClaims[group[leftIndex].id] ?? group[leftIndex]
                    let right = updatedClaims[group[rightIndex].id] ?? group[rightIndex]
                    guard left.status != .retracted, right.status != .retracted else { continue }
                    let score = relationScore(left.statement, right.statement)
                    guard score >= 0.56 else { continue }
                    let deterministic = deterministicContradiction(left.statement, right.statement)
                    let groupID = "self-heal-contradiction-\(Self.shortHash(left.id + right.id))"

                    if deterministic, let winner = authoritativeWinner(left, right) {
                        let loser = winner.id == left.id ? right : left
                        var updatedLoser = loser
                        updatedLoser.status = .retracted
                        updatedLoser.confidence = min(updatedLoser.confidence, 0.25)
                        updatedLoser.contradictionGroupID = groupID
                        updatedLoser.uncertaintyReason = "Retracted by self-healing because \(winner.id) is higher-authority contradictory memory."
                        updatedLoser.correctionLineage.append("self-heal:contradiction:\(winner.id)")
                        updatedClaims[updatedLoser.id] = updatedLoser
                        retracted.insert(updatedLoser.id)
                        audits.append(AuditEventRecord(
                            id: "memory-contradiction-resolved-\(Self.shortHash(winner.id + loser.id))",
                            eventType: "memory.contradictionAutoResolved",
                            targetType: "claim",
                            targetID: updatedLoser.id,
                            sourceRefs: stableUnion(winner.sourceRefs + loser.sourceRefs),
                            timestamp: now,
                            detail: "Retracted lower-authority contradiction in favor of \(winner.id)."
                        ))
                    } else if deterministic || (score >= 0.70 && isAmbiguousConflict(left.statement, right.statement)) {
                        for claim in [left, right] where !isAuthoritative(claim) {
                            var suspect = claim
                            suspect.status = .suspect
                            suspect.confidence = min(suspect.confidence, 0.66)
                            suspect.contradictionGroupID = groupID
                            suspect.uncertaintyReason = "Possible contradiction found by self-healing; user confirmation needed."
                            suspect.correctionLineage.append("self-heal:needs-user")
                            updatedClaims[suspect.id] = suspect
                            let key = "claim|\(suspect.id)|\(FeedbackAction.askLater.rawValue)"
                            if !existingFeedbackKeys.contains(key) {
                                feedbackRecords.append(FeedbackRecord(
                                    id: "memory-contradiction-needs-user-\(Self.shortHash(groupID + suspect.id))",
                                    targetType: "claim",
                                    targetID: suspect.id,
                                    action: .askLater,
                                    note: "Self-healing found a possible contradiction involving: \(left.statement) / \(right.statement)",
                                    timestamp: now
                                ))
                            }
                        }
                        audits.append(AuditEventRecord(
                            id: "memory-contradiction-needs-user-\(Self.shortHash(left.id + right.id))",
                            eventType: "memory.contradictionNeedsUser",
                            targetType: "claim",
                            targetID: left.id,
                            sourceRefs: stableUnion(left.sourceRefs + right.sourceRefs),
                            timestamp: now,
                            detail: "Ambiguous contradiction needs user confirmation."
                        ))
                    }
                }
            }
        }

        return (
            Array(updatedClaims.values).sorted { $0.createdAt < $1.createdAt },
            retracted,
            feedbackRecords,
            audits
        )
    }

    private func shouldMergeEntity(_ left: EntityRecord, _ right: EntityRecord) -> Bool {
        guard left.id != right.id else { return true }
        let leftNames = Set(([left.name] + left.aliases).map(normalizedName).filter { !$0.isEmpty })
        let rightNames = Set(([right.name] + right.aliases).map(normalizedName).filter { !$0.isEmpty })
        if !leftNames.isDisjoint(with: rightNames) { return true }
        if acronymMatch(left, right) { return true }
        if normalizedName(left.entityType) == normalizedName(right.entityType) {
            let leftTokens = entityTokens(left.name)
            let rightTokens = entityTokens(right.name)
            let overlap = leftTokens.intersection(rightTokens)
            if min(leftTokens.count, rightTokens.count) >= 2,
               Double(overlap.count) / Double(min(leftTokens.count, rightTokens.count)) >= 0.86 {
                return true
            }
            if min(leftTokens.count, rightTokens.count) == 1,
               max(leftTokens.count, rightTokens.count) == 2,
               !overlap.isEmpty,
               leftTokens.union(rightTokens).contains(where: { ["project", "app", "system"].contains($0) }) {
                return true
            }
        }
        return false
    }

    private func bestEntityMatch(for claim: ClaimRecord, entities: [EntityRecord]) -> (entity: EntityRecord, score: Double)? {
        entities
            .map { ($0, entityMatchScore(entity: $0, statement: claim.statement)) }
            .filter { $0.1 >= 0.48 }
            .max {
                if $0.1 != $1.1 { return $0.1 < $1.1 }
                return $0.0.confidence < $1.0.confidence
            }
            .map { (entity: $0.0, score: $0.1) }
    }

    private func entityMatchScore(entity: EntityRecord, statement: String) -> Double {
        let lowerStatement = statement.lowercased()
        let names = stableUnion([entity.name] + entity.aliases)
        var best = 0.0
        for name in names {
            let lowerName = name.lowercased()
            let tokens = entityTokens(name)
            if !lowerName.isEmpty, lowerStatement.contains(lowerName) {
                best = max(best, min(1, 0.72 + Double(tokens.count) * 0.06))
            }
            if isAllCapsAcronym(name), containsToken(name.lowercased(), in: lowerStatement) {
                best = max(best, 0.86)
            }
            let claimTokens = semanticTokens(statement)
            let overlap = tokens.intersection(claimTokens)
            if !tokens.isEmpty {
                let coverage = Double(overlap.count) / Double(tokens.count)
                let precision = Double(overlap.count) / Double(max(1, claimTokens.count))
                best = max(best, min(1, coverage * 0.62 + precision * 0.28))
            }
        }
        return best
    }

    private func shouldPromoteInstitutionIdentity(entity: EntityRecord, claim: ClaimRecord) -> Bool {
        let base = institutionBaseName(entity).lowercased()
        let lower = claim.statement.lowercased()
        guard containsToken(base, in: lower) else { return false }
        return lower.contains("student at \(base)")
            || lower.contains("student,") && lower.contains(base)
            || lower.contains("attends \(base)")
            || lower.contains("studying") && lower.contains(base)
            || lower.contains("mathematics student") && lower.contains(base)
    }

    private func shouldFoldIntoEntity(claim: ClaimRecord, entity: EntityRecord) -> Bool {
        guard claim.status != .retracted, claim.claimType != "graph-insight" else { return false }
        if claim.claimType == "supporting-detail" { return true }
        let lower = claim.statement.lowercased()
        let entityScore = entityMatchScore(entity: entity, statement: claim.statement)
        guard entityScore >= 0.62 else { return false }
        if shouldPromoteInstitutionIdentity(entity: entity, claim: claim) { return true }
        if lower.hasPrefix("\(entity.name.lowercased()) is ") { return true }
        if lower.contains("the user is ") && lower.contains(entity.name.lowercased()) && wordCount(lower) <= 18 {
            return true
        }
        return false
    }

    private func authoritativeWinner(_ left: ClaimRecord, _ right: ClaimRecord) -> ClaimRecord? {
        let leftPriority = authorityPriority(left)
        let rightPriority = authorityPriority(right)
        if abs(leftPriority - rightPriority) >= 0.12 {
            return leftPriority > rightPriority ? left : right
        }
        return nil
    }

    private func authorityPriority(_ claim: ClaimRecord) -> Double {
        if isAuthoritative(claim) { return 1.0 }
        if claim.status == .userCorrected { return max(0.94, claim.confidence) }
        return claim.confidence
    }

    private func isAuthoritative(_ claim: ClaimRecord) -> Bool {
        claim.createdBy == "user-wiki-edit"
            || claim.claimType == "user-authored-wiki"
            || (claim.status == .userCorrected && claim.confidence >= 0.94)
    }

    private func deterministicContradiction(_ left: String, _ right: String) -> Bool {
        guard relationScore(left, right) >= 0.56 else { return false }
        if containsNegation(left) != containsNegation(right) { return true }
        if opposingPreference(left, right) { return true }
        let leftNumbers = numberTokens(left)
        let rightNumbers = numberTokens(right)
        if !leftNumbers.isEmpty, !rightNumbers.isEmpty, leftNumbers.isDisjoint(with: rightNumbers), relationScore(left, right) >= 0.70 {
            return true
        }
        return false
    }

    private func isAmbiguousConflict(_ left: String, _ right: String) -> Bool {
        let leftTokens = semanticTokens(left)
        let rightTokens = semanticTokens(right)
        guard !leftTokens.isEmpty, !rightTokens.isEmpty else { return false }
        if leftTokens.isSubset(of: rightTokens) || rightTokens.isSubset(of: leftTokens) {
            return false
        }
        let shared = leftTokens.intersection(rightTokens)
        let leftUnique = leftTokens.subtracting(shared)
        let rightUnique = rightTokens.subtracting(shared)
        guard !leftUnique.isEmpty, !rightUnique.isEmpty else { return false }
        let lowerLeft = left.lowercased()
        let lowerRight = right.lowercased()
        let actionOverlap = !shared.isDisjoint(with: ["want", "wants", "need", "needs", "prefer", "prefers", "use", "uses"])
            || (lowerLeft.contains(" use ") && lowerRight.contains(" use "))
            || (lowerLeft.contains(" prefer") && lowerRight.contains(" prefer"))
        return actionOverlap && relationScore(left, right) >= 0.70
    }

    private func contradictionBucket(_ claim: ClaimRecord) -> String {
        if let subject = claim.subjectEntityID, !subject.isEmpty { return "entity:\(subject)" }
        return semanticTokens(claim.statement).prefix(4).joined(separator: "-")
    }

    private func relationScore(_ left: String, _ right: String) -> Double {
        let leftTokens = semanticTokens(left)
        let rightTokens = semanticTokens(right)
        guard !leftTokens.isEmpty, !rightTokens.isEmpty else { return 0 }
        let overlap = leftTokens.intersection(rightTokens)
        let coverage = Double(overlap.count) / Double(min(leftTokens.count, rightTokens.count))
        let jaccard = Double(overlap.count) / Double(leftTokens.union(rightTokens).count)
        return min(1, coverage * 0.70 + jaccard * 0.30)
    }

    private func containsNegation(_ text: String) -> Bool {
        let lower = " \(text.lowercased()) "
        return [" not ", " never ", " no longer ", " cannot ", " can't ", " does not ", " doesn't ", " do not ", " don't ", " has no ", " without "].contains {
            lower.contains($0)
        }
    }

    private func opposingPreference(_ left: String, _ right: String) -> Bool {
        let leftLower = left.lowercased()
        let rightLower = right.lowercased()
        return (leftLower.contains("prefers") && (rightLower.contains("dislikes") || rightLower.contains("hates")))
            || (rightLower.contains("prefers") && (leftLower.contains("dislikes") || leftLower.contains("hates")))
            || (leftLower.contains("wants") && rightLower.contains("does not want"))
            || (rightLower.contains("wants") && leftLower.contains("does not want"))
    }

    private func isCategoryHub(_ entity: EntityRecord?) -> Bool {
        guard let entity else { return false }
        return categoryHubNames.contains(normalizedName(entity.name))
            || entity.id.contains("memory-seed-entity-") && categoryHubNames.contains(normalizedName(entity.name))
    }

    private func institutionBaseName(_ entity: EntityRecord) -> String {
        let studentSuffix = " Student"
        if entity.name.hasSuffix(studentSuffix) {
            return String(entity.name.dropLast(studentSuffix.count))
        }
        return entity.aliases.first(where: { isAllCapsAcronym($0) }) ?? entity.name
    }

    private func acronymMatch(_ left: EntityRecord, _ right: EntityRecord) -> Bool {
        let leftNames = [left.name] + left.aliases
        let rightNames = [right.name] + right.aliases
        for leftName in leftNames {
            for rightName in rightNames {
                if isAllCapsAcronym(leftName), acronym(for: rightName) == leftName.lowercased() { return true }
                if isAllCapsAcronym(rightName), acronym(for: leftName) == rightName.lowercased() { return true }
            }
        }
        return false
    }

    private func acronym(for value: String) -> String {
        value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { token in
                let lower = token.lowercased()
                return !token.isEmpty
                    && !token.allSatisfy(\.isNumber)
                    && !["of", "the", "and", "for", "at", "in"].contains(lower)
            }
            .compactMap { $0.first }
            .map { String($0).lowercased() }
            .joined()
    }

    private func isAllCapsAcronym(_ value: String) -> Bool {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count >= 2
            && cleaned.count <= 8
            && cleaned == cleaned.uppercased()
            && cleaned.rangeOfCharacter(from: .letters) != nil
    }

    private func containsToken(_ token: String, in text: String) -> Bool {
        semanticTokens(text).contains(normalizedName(token))
    }

    private func normalizedName(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func entityTokens(_ value: String) -> Set<String> {
        semanticTokens(value).filter { !["project", "app", "system", "topic"].contains($0) }
    }

    private func semanticTokens(_ value: String) -> Set<String> {
        Set(value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { token in
                token.count >= 3
                    && !stopWords.contains(token)
            })
    }

    private func numberTokens(_ text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: #"\b\d+(?:\.\d+)?\b"#) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return Set(regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        })
    }

    private func wordCount(_ text: String) -> Int {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.count
    }

    private func appendSelfHealingNote(to reason: String, note: String) -> String {
        guard !reason.localizedCaseInsensitiveContains(note) else { return reason }
        return reason.isEmpty ? note : "\(reason) \(note)"
    }

    private func entitySort(_ left: EntityRecord, _ right: EntityRecord) -> Bool {
        if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
        if left.confidence != right.confidence { return left.confidence > right.confidence }
        return left.id < right.id
    }

    private func stableUnion(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = normalizedName(trimmed)
            if seen.insert(key).inserted {
                output.append(trimmed)
            }
        }
        return output
    }

    private func stableUniqueClaims(_ claims: [ClaimRecord]) -> [ClaimRecord] {
        var byID: [String: ClaimRecord] = [:]
        for claim in claims {
            byID[claim.id] = claim
        }
        return byID.values.sorted { $0.createdAt < $1.createdAt }
    }

    private func stableUniqueEntities(_ entities: [EntityRecord]) -> [EntityRecord] {
        var byID: [String: EntityRecord] = [:]
        for entity in entities {
            byID[entity.id] = entity
        }
        return byID.values.sorted(by: entitySort)
    }

    private static func shortHash(_ value: String) -> String {
        String(Hashing.sha256(data: Data(value.utf8)).prefix(16))
    }

    private let stopWords: Set<String> = [
        "the", "user", "has", "have", "with", "from", "that", "this", "into", "their",
        "they", "them", "and", "for", "are", "was", "were", "will", "would", "should",
        "currently", "about", "because", "using", "uses"
    ]

    private let categoryHubNames: Set<String> = [
        "preferences", "skills", "finance", "shopping", "projects", "hardware", "experience",
        "tools", "health", "interests", "work", "bio", "family", "education", "learning",
        "routine", "social", "goals", "productivity", "relationships", "travel", "location",
        "food", "achievements"
    ]
}

private struct UserContextBundleRule: Sendable {
    var entityID: String
    var claimID: String
    var title: String
    var statement: String
    var requiredAny: [String]
    var requiredContextAny: [String]
    var aliases: [String]
    var foldEntityAny: [String]

    func matches(_ normalizedText: String) -> Bool {
        requiredAny.contains { normalizedText.contains($0) }
            && requiredContextAny.contains { normalizedText.contains($0) }
    }

    func shouldFold(_ entity: EntityRecord) -> Bool {
        let text = ([entity.name] + entity.aliases)
            .joined(separator: " ")
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return foldEntityAny.contains { text == $0 || text.contains($0) }
    }
}

private extension MemorySelfHealingResult {
    var fingerprint: String {
        [
            updatedClaims.map(\.id).sorted().joined(separator: ","),
            updatedEntities.map(\.id).sorted().joined(separator: ","),
            retractedClaimIDs.sorted().joined(separator: ","),
            entityRemapIDs.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ","),
            suppressedGraphClaimIDs.sorted().joined(separator: ","),
            feedbackRecords.map(\.id).sorted().joined(separator: ",")
        ].joined(separator: "|")
    }
}
