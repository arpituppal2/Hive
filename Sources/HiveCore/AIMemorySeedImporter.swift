import Foundation

public struct AIMemorySeedImportSummary: Sendable {
    public var entityCount: Int
    public var claimCount: Int
    public var pageCount: Int
}

public struct AIMemorySeedImporter: Sendable {
    private let store: HiveStore

    public init(store: HiveStore) {
        self.store = store
    }

    @discardableResult
    public func persist(seed: AIMemorySeed, source: SourceRecord) throws -> AIMemorySeedImportSummary {
        var slugToEntityID: [String: String] = [:]
        var savedClaimIDs: [String] = []
        var savedEntityCount = 0
        var savedPageCount = 0

        func canonicalSlug(_ value: String) -> String {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return WikiPageRecord.slugify(normalized.isEmpty ? UUID().uuidString : normalized)
        }

        func entityID(for slug: String) -> String {
            "seed-entity-\(canonicalSlug(slug))"
        }

        for entity in seed.entities where entity.confidence >= 0.60 {
            let slug = canonicalSlug(entity.id.isEmpty ? entity.name : entity.id)
            let id = entityID(for: slug)
            slugToEntityID[slug] = id
            try store.saveEntity(EntityRecord(
                id: id,
                name: entity.name.isEmpty ? slug : entity.name,
                entityType: entity.type.isEmpty ? "concept" : entity.type,
                aliases: entity.aliases,
                sourceRefs: [source.id],
                confidence: min(1, max(0.6, entity.confidence))
            ))
            savedEntityCount += 1
        }

        for project in seed.projects where project.confidence >= 0.60 {
            let slug = canonicalSlug(project.id.isEmpty ? project.name : project.id)
            let id = entityID(for: slug)
            slugToEntityID[slug] = id
            try store.saveEntity(EntityRecord(
                id: id,
                name: project.name.isEmpty ? slug : project.name,
                entityType: "project",
                aliases: [],
                sourceRefs: [source.id],
                confidence: min(1, max(0.6, project.confidence))
            ))
            savedEntityCount += 1
        }

        for cluster in seed.sourceClusters {
            let slug = canonicalSlug(cluster.id.isEmpty ? cluster.label : cluster.id)
            let id = entityID(for: slug)
            slugToEntityID[slug] = id
            try store.saveEntity(EntityRecord(
                id: id,
                name: cluster.label.isEmpty ? slug : cluster.label,
                entityType: "topic",
                aliases: [],
                sourceRefs: [source.id],
                confidence: cluster.signalLevel.lowercased() == "high" ? 0.86 : (cluster.signalLevel.lowercased() == "medium" ? 0.72 : 0.60)
            ))
            savedEntityCount += 1
        }

        if let profile = seed.canonicalProfile {
            let profileClaims = profile.preferences.map { ("preference", $0) } + profile.constraints.map { ("constraint", $0) }
            for (kind, item) in profileClaims {
                guard item.confidence >= 0.60, !item.claim.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let claim = ClaimRecord(
                    id: "seed-profile-\(kind)-\(canonicalSlug(item.claim))",
                    statement: item.claim,
                    claimType: item.confidence >= 0.80 ? "ai-memory-seed-confirmed" : "ai-memory-seed-unresolved",
                    sourceRefs: [source.id],
                    confidence: min(1, item.confidence),
                    uncertaintyReason: item.evidenceQuote.isEmpty ? "Imported from AI Memory Seed." : "Evidence: \(item.evidenceQuote)",
                    status: item.confidence >= 0.80 ? .active : .suspect,
                    createdBy: "ai-memory-seed"
                )
                try store.saveClaim(claim)
                savedClaimIDs.append(claim.id)
            }
        }

        for item in seed.confirmedClaims where item.confidence >= 0.60 {
            let subjectSlug = canonicalSlug(item.subject)
            let statement = [item.subject, item.predicate, item.object]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard !statement.isEmpty else { continue }
            let claim = ClaimRecord(
                id: "seed-claim-\(canonicalSlug(item.id.isEmpty ? statement : item.id))",
                statement: statement,
                claimType: item.confidence >= 0.80 ? "ai-memory-seed-confirmed" : "ai-memory-seed-unresolved",
                subjectEntityID: slugToEntityID[subjectSlug],
                sourceRefs: [source.id],
                confidence: min(1, item.confidence),
                uncertaintyReason: item.confidence >= 0.80
                    ? "Confirmed by imported AI Memory Seed. \(item.whyItMatters)"
                    : "Imported as plausible memory seed; needs user confirmation.",
                status: item.confidence >= 0.80 ? .active : .suspect,
                createdBy: "ai-memory-seed"
            )
            try store.saveClaim(claim)
            savedClaimIDs.append(claim.id)
        }

        for item in seed.unresolvedClaims where item.confidence >= 0.60 {
            let claim = ClaimRecord(
                id: "seed-unresolved-\(canonicalSlug(item.id.isEmpty ? item.claim : item.id))",
                statement: item.claim,
                claimType: "ai-memory-seed-unresolved",
                sourceRefs: [source.id],
                confidence: min(0.79, max(0.60, item.confidence)),
                uncertaintyReason: [item.whyUncertain, item.bestFollowupQuestion].filter { !$0.isEmpty }.joined(separator: " Follow-up: "),
                status: .suspect,
                createdBy: "ai-memory-seed"
            )
            try store.saveClaim(claim)
            savedClaimIDs.append(claim.id)
        }

        for item in seed.refusedInferences {
            guard !item.possibleInference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let claim = ClaimRecord(
                id: "seed-refused-\(canonicalSlug(item.id.isEmpty ? item.possibleInference : item.id))",
                statement: "Refused inference: \(item.possibleInference)",
                claimType: "ai-memory-seed-refused",
                sourceRefs: [source.id],
                confidence: 0.88,
                uncertaintyReason: item.reasonToRefuse,
                status: .active,
                createdBy: "ai-memory-seed"
            )
            try store.saveClaim(claim)
            savedClaimIDs.append(claim.id)
        }

        for item in seed.oneQuestionPriorities {
            guard !item.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let claim = ClaimRecord(
                id: "seed-question-\(canonicalSlug(item.question))",
                statement: item.question,
                claimType: "ai-memory-seed-question",
                sourceRefs: [source.id],
                confidence: 0.66,
                uncertaintyReason: item.unlocks,
                status: .suspect,
                createdBy: "ai-memory-seed"
            )
            try store.saveClaim(claim)
            savedClaimIDs.append(claim.id)
        }

        for edge in seed.relationshipEdges {
            let sourceID = slugToEntityID[canonicalSlug(edge.source)] ?? entityID(for: edge.source)
            let targetID = slugToEntityID[canonicalSlug(edge.target)] ?? entityID(for: edge.target)
            try store.saveRelationship(RelationshipRecord(
                id: "seed-edge-\(canonicalSlug(edge.source))-\(canonicalSlug(edge.target))-\(canonicalSlug(edge.relationship))",
                subjectID: sourceID,
                predicate: .related,
                objectID: targetID,
                strength: min(1, max(0.2, edge.confidence)),
                confidence: min(1, max(0.2, edge.confidence)),
                evidenceCount: 1,
                sourceSpanRefs: [source.id]
            ))
        }

        for starter in seed.wikiStarters {
            let title = starter.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let page = WikiCompiler.makePage(
                id: "seed-wiki-\(canonicalSlug(title))",
                title: title,
                kind: wikiKind(forSeedStarterType: starter.type),
                summary: starter.starterSummary,
                body: seedWikiBody(starter),
                sourceRefs: [source.id],
                claimRefs: savedClaimIDs,
                previous: nil
            )
            try store.saveWikiPage(page)
            savedPageCount += 1
        }

        try store.appendAudit(AuditEventRecord(
            eventType: "aiMemorySeed.imported",
            targetType: "source",
            targetID: source.id,
            sourceRefs: [source.id],
            detail: "Imported AI Memory Seed with \(seed.entities.count) entities, \(seed.confirmedClaims.count) confirmed claims, \(seed.unresolvedClaims.count) unresolved claims, \(seed.oneQuestionPriorities.count) priority questions, and \(seed.refusedInferences.count) refused inferences."
        ))

        return AIMemorySeedImportSummary(entityCount: savedEntityCount, claimCount: savedClaimIDs.count, pageCount: savedPageCount)
    }

    private func wikiKind(forSeedStarterType type: String) -> WikiPageKind {
        switch type.lowercased() {
        case "project": .project
        case "person": .person
        case "preference", "workflow", "topic": .topic
        default: .topic
        }
    }

    private func seedWikiBody(_ starter: AIMemoryWikiStarter) -> String {
        var lines = ["# \(starter.title)", "", starter.starterSummary]
        if !starter.linkedEntities.isEmpty {
            lines.append("")
            lines.append("## Linked entities")
            lines.append(contentsOf: starter.linkedEntities.map { "- \($0)" })
        }
        if !starter.openQuestions.isEmpty {
            lines.append("")
            lines.append("## Open questions")
            lines.append(contentsOf: starter.openQuestions.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }
}
