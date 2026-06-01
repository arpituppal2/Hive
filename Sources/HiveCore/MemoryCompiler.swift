import Foundation

public enum MemorySensitivity: String, Codable, CaseIterable, Sendable {
    case normal
    case `private`
    case sensitive
}

public struct MemorySeedRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var observedAt: Date
    public var category: String
    public var statement: String
    public var confidence: Double
    public var sourceLabel: String
    public var sensitivity: MemorySensitivity
    public var relatedEntitySlugs: [String]
    public var relatedProjectSlugs: [String]
    public var memoryLayer: MemoryNodeLayer?
    public var semanticColorKey: String?

    enum CodingKeys: String, CodingKey {
        case id
        case observedAt
        case category
        case statement
        case confidence
        case sourceLabel
        case sensitivity
        case relatedEntitySlugs
        case relatedProjectSlugs
        case memoryLayer
        case semanticColorKey
    }

    public init(
        id: String,
        observedAt: Date,
        category: String,
        statement: String,
        confidence: Double,
        sourceLabel: String,
        sensitivity: MemorySensitivity = .normal,
        relatedEntitySlugs: [String] = [],
        relatedProjectSlugs: [String] = [],
        memoryLayer: MemoryNodeLayer? = nil,
        semanticColorKey: String? = nil
    ) {
        self.id = id
        self.observedAt = observedAt
        self.category = category
        self.statement = statement
        self.confidence = confidence
        self.sourceLabel = sourceLabel
        self.sensitivity = sensitivity
        self.relatedEntitySlugs = relatedEntitySlugs
        self.relatedProjectSlugs = relatedProjectSlugs
        self.memoryLayer = memoryLayer
        self.semanticColorKey = semanticColorKey
    }
}

public enum MemoryCompilationDecisionKind: String, Codable, CaseIterable, Sendable {
    case ignore
    case askClarifyingQuestion
    case mergeIntoExisting
    case createMemory
    case updateMemory
    case retractMemory
}

public struct MemoryCompilationDecision: Codable, Hashable, Sendable {
    public var kind: MemoryCompilationDecisionKind
    public var confidence: Double
    public var reason: String
    public var targetID: String?
    public var proposedStatement: String?

    public init(
        kind: MemoryCompilationDecisionKind,
        confidence: Double,
        reason: String,
        targetID: String? = nil,
        proposedStatement: String? = nil
    ) {
        self.kind = kind
        self.confidence = confidence
        self.reason = reason
        self.targetID = targetID
        self.proposedStatement = proposedStatement
    }
}

public struct MemoryCompiler: Sendable {
    public init() {}

    public func evaluate(
        source: SourceRecord,
        extractedClaims: [ClaimRecord],
        existingClaims: [ClaimRecord],
        existingEntities: [EntityRecord],
        feedback: [FeedbackRecord] = []
    ) -> MemoryCompilationDecision {
        if source.kind == .browserHistory || source.kind == .browserBookmark {
            return evaluateBrowserEvidence(source: source, extractedClaims: extractedClaims, feedback: feedback)
        }

        let candidate = extractedClaims
            .filter { $0.status != .retracted && !Self.isRawLinkLike($0.statement) }
            .sorted {
                if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
                return $0.createdAt > $1.createdAt
            }
            .first
        guard let candidate else {
            return MemoryCompilationDecision(
                kind: .ignore,
                confidence: 0.2,
                reason: "The source does not yet contain a synthesized user-relevant statement."
            )
        }

        let normalized = Self.normalizedMemoryKey(candidate.statement)
        if let existing = existingClaims.first(where: { Self.normalizedMemoryKey($0.statement) == normalized }) {
            return MemoryCompilationDecision(
                kind: .mergeIntoExisting,
                confidence: max(existing.confidence, candidate.confidence),
                reason: "The new evidence reinforces an existing memory instead of creating a duplicate node.",
                targetID: existing.id,
                proposedStatement: candidate.statement
            )
        }

        let matchedEntity = existingEntities.first { entity in
            candidate.statement.localizedCaseInsensitiveContains(entity.name)
        }
        return MemoryCompilationDecision(
            kind: matchedEntity == nil ? .createMemory : .updateMemory,
            confidence: candidate.confidence,
            reason: matchedEntity == nil
                ? "The source contains a concrete durable statement that is not just a link or file reference."
                : "The source appears to strengthen an existing memory cluster: \(matchedEntity?.name ?? "existing memory").",
            targetID: matchedEntity?.id,
            proposedStatement: candidate.statement
        )
    }

    public static func isRawLinkLike(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") {
            return true
        }
        if lower.contains("://") {
            return true
        }
        if lower.contains(" — browser appearance alone is incidental") {
            return true
        }
        let words = lower.split { !$0.isLetter && !$0.isNumber && $0 != "." && $0 != "-" }
        if words.count <= 2, words.contains(where: { looksLikeDomain(String($0)) }) {
            return true
        }
        return false
    }

    public static func normalizedMemoryKey(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func evaluateBrowserEvidence(
        source: SourceRecord,
        extractedClaims: [ClaimRecord],
        feedback: [FeedbackRecord]
    ) -> MemoryCompilationDecision {
        let explicitlyMarked = feedback.contains { record in
            (record.targetType == "source" && record.targetID == source.id && record.action == .matters)
                || (record.targetType == "browserCluster" && record.action == .matters && source.uri.contains(record.targetID))
        }
        let engagementConfidence = extractedClaims.map(\.confidence).max() ?? 0
        let lowerEvidence = ([source.title, source.uri] + extractedClaims.map(\.statement)).joined(separator: " ").lowercased()
        if lowerEvidence.contains("youtube.com/shorts") || lowerEvidence.contains("youtu.be/shorts") || lowerEvidence.contains("/shorts/") {
            guard explicitlyMarked || engagementConfidence >= 0.95 else {
                return MemoryCompilationDecision(
                    kind: .ignore,
                    confidence: engagementConfidence,
                    reason: "YouTube Shorts stay incidental unless engagement confidence is at least 95% or the user marks the session meaningful."
                )
            }
        }
        guard explicitlyMarked else {
            return MemoryCompilationDecision(
                kind: .ignore,
                confidence: engagementConfidence,
                reason: "Browser evidence is raw attention data. Hive needs recurrence plus user/project relevance before it becomes memory."
            )
        }
        return MemoryCompilationDecision(
            kind: .askClarifyingQuestion,
            confidence: max(0.7, engagementConfidence),
            reason: "The user marked this browsing cluster as meaningful, but Hive needs a synthesized statement before creating a memory."
        )
    }

    private static func looksLikeDomain(_ value: String) -> Bool {
        guard value.contains(".") else { return false }
        let parts = value.split(separator: ".")
        guard parts.count >= 2, let last = parts.last, (2...24).contains(last.count) else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
    }
}

public struct MemorySeedImportSummary: Sendable {
    public var recordCount: Int
    public var entityCount: Int
    public var claimCount: Int
}

public struct MemorySeedImporter: Sendable {
    private let store: HiveStore

    public init(store: HiveStore) {
        self.store = store
    }

    @discardableResult
    public func persist(records: [MemorySeedRecord], source: SourceRecord) throws -> MemorySeedImportSummary {
        var savedEntities = Set<String>()
        var savedClaims = 0

        for record in records {
            let categoryID = entityID(slug: record.category)
            try saveEntityIfNeeded(
                id: categoryID,
                name: record.category,
                type: "topic",
                source: source,
                confidence: 0.98,
                createdAt: record.observedAt,
                savedEntities: &savedEntities
            )

            for projectSlug in record.relatedProjectSlugs where shouldMaterializeRelatedSlug(projectSlug, in: record.statement) {
                try saveEntityIfNeeded(
                    id: entityID(slug: projectSlug),
                    name: title(from: projectSlug),
                    type: "project",
                    source: source,
                    confidence: 0.96,
                    createdAt: record.observedAt,
                    savedEntities: &savedEntities
                )
            }

            for entitySlug in record.relatedEntitySlugs where shouldMaterializeRelatedSlug(entitySlug, in: record.statement) {
                try saveEntityIfNeeded(
                    id: entityID(slug: entitySlug),
                    name: title(from: entitySlug),
                    type: "topic",
                    source: source,
                    confidence: 0.9,
                    createdAt: record.observedAt,
                    savedEntities: &savedEntities
                )
            }

            let claimID = "memory-seed-claim-\(WikiPageRecord.slugify(record.id))"
            let overrideDetails = memoryLayerDetails(for: record)
            try store.saveClaim(ClaimRecord(
                id: claimID,
                statement: record.statement,
                claimType: "memory-seed-confirmed",
                subjectEntityID: categoryID,
                sourceRefs: [source.id],
                confidence: min(1, max(0.8, record.confidence)),
                uncertaintyReason: "Imported from local Hive memory seed. Category: \(record.category). Source: \(record.sourceLabel). Sensitivity: \(record.sensitivity.rawValue).\(overrideDetails)",
                status: .active,
                createdBy: "local-memory-seed",
                createdAt: record.observedAt
            ))
            savedClaims += 1
        }

        try store.appendAudit(AuditEventRecord(
            eventType: "memorySeed.imported",
            targetType: "source",
            targetID: source.id,
            sourceRefs: [source.id],
            detail: "Imported \(records.count) local memory seed records into categorized Hive memory."
        ))

        return MemorySeedImportSummary(recordCount: records.count, entityCount: savedEntities.count, claimCount: savedClaims)
    }

    private func saveEntityIfNeeded(
        id: String,
        name: String,
        type: String,
        source: SourceRecord,
        confidence: Double,
        createdAt: Date,
        savedEntities: inout Set<String>
    ) throws {
        guard !savedEntities.contains(id) else { return }
        try store.saveEntity(EntityRecord(
            id: id,
            name: name,
            entityType: type,
            aliases: [],
            sourceRefs: [source.id],
            confidence: confidence,
            createdAt: createdAt
        ))
        savedEntities.insert(id)
    }

    private func memoryLayerDetails(for record: MemorySeedRecord) -> String {
        var details: [String] = []
        if let memoryLayer = record.memoryLayer {
            details.append(" Memory layer: \(memoryLayer.rawValue).")
        }
        if let semanticColorKey = record.semanticColorKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !semanticColorKey.isEmpty {
            details.append(" Semantic color: \(semanticColorKey).")
        }
        return details.joined()
    }

    private func entityID(slug: String) -> String {
        "memory-seed-entity-\(WikiPageRecord.slugify(slug))"
    }

    private func title(from slug: String) -> String {
        slug
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                if ["ai", "llm", "lamt", "ucla", "brev", "gpu", "ap", "amc", "aime"].contains(lower) {
                    return lower.uppercased()
                }
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }

    private func shouldMaterializeRelatedSlug(_ slug: String, in statement: String) -> Bool {
        let lowerStatement = statement.lowercased()
        let lowerSlug = slug.lowercased()
        let phrase = lowerSlug.replacingOccurrences(of: "-", with: " ")
        return lowerStatement.contains(lowerSlug)
            || lowerStatement.contains(phrase)
            || lowerStatement.contains(title(from: slug).lowercased())
    }
}
