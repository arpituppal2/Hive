import Foundation
import SwiftData

@Model
public final class HiveRawSourceModel {
    public var recordID: String
    public var kindRawValue: String
    public var connector: String
    public var uri: String
    public var title: String
    public var mimeType: String
    public var sizeBytes: Int64
    public var sha256: String
    public var importedAt: Date
    public var observedAt: Date
    public var retentionExpiresAt: Date
    public var pinned: Bool
    public var privacyLabelRawValue: String
    public var statusRawValue: String
    public var deletionStateRawValue: String

    public init(record: SourceRecord) {
        self.recordID = record.id
        self.kindRawValue = record.kind.rawValue
        self.connector = record.connector
        self.uri = record.uri
        self.title = record.title
        self.mimeType = record.mimeType
        self.sizeBytes = record.sizeBytes
        self.sha256 = record.sha256
        self.importedAt = record.importedAt
        self.observedAt = record.observedAt
        self.retentionExpiresAt = record.retentionExpiresAt
        self.pinned = record.pinned
        self.privacyLabelRawValue = record.privacyLabel.rawValue
        self.statusRawValue = record.status.rawValue
        self.deletionStateRawValue = record.deletionState.rawValue
    }

    public func record() -> SourceRecord {
        SourceRecord(
            id: recordID,
            kind: SourceKind(rawValue: kindRawValue) ?? .genericFile,
            connector: connector,
            uri: uri,
            title: title,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            sha256: sha256,
            importedAt: importedAt,
            observedAt: observedAt,
            retentionExpiresAt: retentionExpiresAt,
            pinned: pinned,
            privacyLabel: PrivacyLabel(rawValue: privacyLabelRawValue) ?? .normal,
            status: RecordStatus(rawValue: statusRawValue) ?? .queued,
            deletionState: DeletionState(rawValue: deletionStateRawValue) ?? .active
        )
    }
}

@Model
public final class HiveRawBlobModel {
    public var recordID: String
    public var sourceID: String
    public var contentAddress: String
    public var localPath: String
    public var mimeType: String
    public var sizeBytes: Int64
    public var sha256: String
    public var createdAt: Date

    public init(record: RawBlobRecord) {
        self.recordID = record.id
        self.sourceID = record.sourceID
        self.contentAddress = record.contentAddress
        self.localPath = record.localPath
        self.mimeType = record.mimeType
        self.sizeBytes = record.sizeBytes
        self.sha256 = record.sha256
        self.createdAt = record.createdAt
    }

    public func record() -> RawBlobRecord {
        RawBlobRecord(
            id: recordID,
            sourceID: sourceID,
            contentAddress: contentAddress,
            localPath: localPath,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            sha256: sha256,
            createdAt: createdAt
        )
    }
}

@Model
public final class HiveExtractionJobModel {
    public var recordID: String
    public var sourceID: String
    public var stageRawValue: String
    public var statusRawValue: String
    public var attempts: Int
    public var nextRetryAt: Date?
    public var errorCategory: String?
    public var updatedAt: Date

    public init(record: ExtractionJobRecord) {
        self.recordID = record.id
        self.sourceID = record.sourceID
        self.stageRawValue = record.stage.rawValue
        self.statusRawValue = record.status.rawValue
        self.attempts = record.attempts
        self.nextRetryAt = record.nextRetryAt
        self.errorCategory = record.errorCategory
        self.updatedAt = record.updatedAt
    }

    public func record() -> ExtractionJobRecord {
        ExtractionJobRecord(
            id: recordID,
            sourceID: sourceID,
            stage: JobStage(rawValue: stageRawValue) ?? .ingest,
            status: JobStatus(rawValue: statusRawValue) ?? .queued,
            attempts: attempts,
            nextRetryAt: nextRetryAt,
            errorCategory: errorCategory,
            updatedAt: updatedAt
        )
    }
}

@Model
public final class HiveChunkModel {
    public var recordID: String
    public var sourceID: String
    public var artifactID: String
    public var text: String
    public var locationLabel: String
    public var language: String
    public var embeddingRef: String?
    public var extractionConfidence: Double

    public init(record: ChunkRecord) {
        self.recordID = record.id
        self.sourceID = record.sourceID
        self.artifactID = record.artifactID
        self.text = record.text
        self.locationLabel = record.locationLabel
        self.language = record.language
        self.embeddingRef = record.embeddingRef
        self.extractionConfidence = record.extractionConfidence
    }

    public func record() -> ChunkRecord {
        ChunkRecord(
            id: recordID,
            sourceID: sourceID,
            artifactID: artifactID,
            text: text,
            locationLabel: locationLabel,
            language: language,
            embeddingRef: embeddingRef,
            extractionConfidence: extractionConfidence
        )
    }
}

@Model
public final class HiveClaimModel {
    public var recordID: String
    public var statement: String
    public var claimType: String
    public var subjectEntityID: String?
    public var sourceRefsJSON: String
    public var sourceSpanRefsJSON: String
    public var confidence: Double
    public var uncertaintyReason: String
    public var contradictionGroupID: String?
    public var statusRawValue: String
    public var createdBy: String
    public var createdAt: Date
    public var correctionLineageJSON: String

    public init(record: ClaimRecord) {
        self.recordID = record.id
        self.statement = record.statement
        self.claimType = record.claimType
        self.subjectEntityID = record.subjectEntityID
        self.sourceRefsJSON = Self.encode(record.sourceRefs)
        self.sourceSpanRefsJSON = Self.encode(record.sourceSpanRefs)
        self.confidence = record.confidence
        self.uncertaintyReason = record.uncertaintyReason
        self.contradictionGroupID = record.contradictionGroupID
        self.statusRawValue = record.status.rawValue
        self.createdBy = record.createdBy
        self.createdAt = record.createdAt
        self.correctionLineageJSON = Self.encode(record.correctionLineage)
    }

    public func record() -> ClaimRecord {
        ClaimRecord(
            id: recordID,
            statement: statement,
            claimType: claimType,
            subjectEntityID: subjectEntityID,
            sourceRefs: Self.decode(sourceRefsJSON),
            sourceSpanRefs: Self.decode(sourceSpanRefsJSON),
            confidence: confidence,
            uncertaintyReason: uncertaintyReason,
            contradictionGroupID: contradictionGroupID,
            status: ClaimStatus(rawValue: statusRawValue) ?? .active,
            createdBy: createdBy,
            createdAt: createdAt,
            correctionLineage: Self.decode(correctionLineageJSON)
        )
    }
}

@Model
public final class HiveEntityModel {
    public var recordID: String
    public var name: String
    public var entityType: String
    public var aliasesJSON: String
    public var sourceRefsJSON: String
    public var confidence: Double
    public var createdAt: Date

    public init(record: EntityRecord) {
        self.recordID = record.id
        self.name = record.name
        self.entityType = record.entityType
        self.aliasesJSON = Self.encode(record.aliases)
        self.sourceRefsJSON = Self.encode(record.sourceRefs)
        self.confidence = record.confidence
        self.createdAt = record.createdAt
    }

    public func record() -> EntityRecord {
        EntityRecord(
            id: recordID,
            name: name,
            entityType: entityType,
            aliases: Self.decode(aliasesJSON),
            sourceRefs: Self.decode(sourceRefsJSON),
            confidence: confidence,
            createdAt: createdAt
        )
    }
}

@Model
public final class HiveConnectionModel {
    public var recordID: String
    public var subjectID: String
    public var predicateRawValue: String
    public var relationshipObjectID: String
    public var strength: Double
    public var confidence: Double
    public var evidenceCount: Int
    public var recency: Date
    public var sourceSpanRefsJSON: String
    public var negativeFeedbackCount: Int
    public var lastRecomputedAt: Date

    public init(record: RelationshipRecord) {
        self.recordID = record.id
        self.subjectID = record.subjectID
        self.predicateRawValue = record.predicate.rawValue
        self.relationshipObjectID = record.objectID
        self.strength = record.strength
        self.confidence = record.confidence
        self.evidenceCount = record.evidenceCount
        self.recency = record.recency
        self.sourceSpanRefsJSON = Self.encode(record.sourceSpanRefs)
        self.negativeFeedbackCount = record.negativeFeedbackCount
        self.lastRecomputedAt = record.lastRecomputedAt
    }

    public func record() -> RelationshipRecord {
        RelationshipRecord(
            id: recordID,
            subjectID: subjectID,
            predicate: RelationshipPredicate(rawValue: predicateRawValue) ?? .related,
            objectID: relationshipObjectID,
            strength: strength,
            confidence: confidence,
            evidenceCount: evidenceCount,
            recency: recency,
            sourceSpanRefs: Self.decode(sourceSpanRefsJSON),
            negativeFeedbackCount: negativeFeedbackCount,
            lastRecomputedAt: lastRecomputedAt
        )
    }
}

@Model
public final class HiveWikiArticleModel {
    public var recordID: String
    public var title: String
    public var markdown: String
    public var sourceRefsJSON: String
    public var claimRefsJSON: String
    public var updatedAt: Date
    public var slug: String
    public var kindRawValue: String
    public var summary: String
    public var frontmatterJSON: String
    public var outboundLinksJSON: String
    public var inboundLinksJSON: String
    public var filePath: String?
    public var revision: Int

    public init(record: WikiPageRecord) {
        self.recordID = record.id
        self.title = record.title
        self.markdown = record.markdown
        self.sourceRefsJSON = Self.encode(record.sourceRefs)
        self.claimRefsJSON = Self.encode(record.claimRefs)
        self.updatedAt = record.updatedAt
        self.slug = record.slug
        self.kindRawValue = record.kind.rawValue
        self.summary = record.summary
        self.frontmatterJSON = Self.encodeDictionary(record.frontmatter)
        self.outboundLinksJSON = Self.encode(record.outboundLinks)
        self.inboundLinksJSON = Self.encode(record.inboundLinks)
        self.filePath = record.filePath
        self.revision = record.revision
    }

    public func record() -> WikiPageRecord {
        WikiPageRecord(
            id: recordID,
            title: title,
            markdown: markdown,
            sourceRefs: Self.decode(sourceRefsJSON),
            claimRefs: Self.decode(claimRefsJSON),
            updatedAt: updatedAt,
            slug: slug,
            kind: WikiPageKind(rawValue: kindRawValue) ?? .topic,
            summary: summary,
            frontmatter: Self.decodeDictionary(frontmatterJSON),
            outboundLinks: Self.decode(outboundLinksJSON),
            inboundLinks: Self.decode(inboundLinksJSON),
            filePath: filePath,
            revision: revision
        )
    }
}

@Model
public final class HiveFeedbackModel {
    public var recordID: String
    public var targetType: String
    public var targetID: String
    public var actionRawValue: String
    public var note: String
    public var timestamp: Date
    public var cascadePolicy: String
    public var resultingRevisionIDsJSON: String

    public init(record: FeedbackRecord) {
        self.recordID = record.id
        self.targetType = record.targetType
        self.targetID = record.targetID
        self.actionRawValue = record.action.rawValue
        self.note = record.note
        self.timestamp = record.timestamp
        self.cascadePolicy = record.cascadePolicy
        self.resultingRevisionIDsJSON = Self.encode(record.resultingRevisionIDs)
    }

    public func record() -> FeedbackRecord {
        FeedbackRecord(
            id: recordID,
            targetType: targetType,
            targetID: targetID,
            action: FeedbackAction(rawValue: actionRawValue) ?? .askLater,
            note: note,
            timestamp: timestamp,
            cascadePolicy: cascadePolicy,
            resultingRevisionIDs: Self.decode(resultingRevisionIDsJSON)
        )
    }
}

@Model
public final class HiveAuditEventModel {
    public var recordID: String
    public var eventType: String
    public var targetType: String
    public var targetID: String
    public var actor: String
    public var modelID: String?
    public var promptConfigHash: String?
    public var sourceRefsJSON: String
    public var timestamp: Date
    public var detail: String

    public init(record: AuditEventRecord) {
        self.recordID = record.id
        self.eventType = record.eventType
        self.targetType = record.targetType
        self.targetID = record.targetID
        self.actor = record.actor
        self.modelID = record.modelID
        self.promptConfigHash = record.promptConfigHash
        self.sourceRefsJSON = Self.encode(record.sourceRefs)
        self.timestamp = record.timestamp
        self.detail = record.detail
    }

    public func record() -> AuditEventRecord {
        AuditEventRecord(
            id: recordID,
            eventType: eventType,
            targetType: targetType,
            targetID: targetID,
            actor: actor,
            modelID: modelID,
            promptConfigHash: promptConfigHash,
            sourceRefs: Self.decode(sourceRefsJSON),
            timestamp: timestamp,
            detail: detail
        )
    }
}

@Model
public final class HiveInferenceJobModel {
    public var recordID: String
    public var kindRawValue: String
    public var sourceID: String?
    public var prompt: String
    public var priorityRawValue: String
    public var createdAt: Date
    public var manual: Bool
    public var statusRawValue: String
    public var resultJSON: String?

    public init(job: LocalInferenceJob, status: JobStatus = .queued, resultJSON: String? = nil) {
        self.recordID = job.id
        self.kindRawValue = job.kind.rawValue
        self.sourceID = job.sourceID
        self.prompt = job.prompt
        self.priorityRawValue = job.priority.rawValue
        self.createdAt = job.createdAt
        self.manual = job.manual
        self.statusRawValue = status.rawValue
        self.resultJSON = resultJSON
    }

    public func job() -> LocalInferenceJob {
        LocalInferenceJob(
            id: recordID,
            kind: InferenceJobKind(rawValue: kindRawValue) ?? .summarizeRawSource,
            sourceID: sourceID,
            prompt: prompt,
            priority: InferenceJobPriority(rawValue: priorityRawValue) ?? .normal,
            createdAt: createdAt,
            manual: manual
        )
    }
}

@Model
public final class HiveGraphLayoutModel {
    public var recordID: String
    public var nodeID: String
    public var x: Double
    public var y: Double
    public var clusterID: String?
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, nodeID: String, x: Double, y: Double, clusterID: String? = nil, updatedAt: Date = Date()) {
        self.recordID = id
        self.nodeID = nodeID
        self.x = x
        self.y = y
        self.clusterID = clusterID
        self.updatedAt = updatedAt
    }
}

extension PersistentModel {
    static func encode(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    static func decode(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return values
    }

    static func encodeDictionary(_ values: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    static func decodeDictionary(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return values
    }
}
