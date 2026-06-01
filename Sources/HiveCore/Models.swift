import Foundation

public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case pdf
    case attachment
    case browserHistory
    case browserBookmark
    case image
    case video
    case audio
    case text
    case folder
    case screenshot
    case clipboardExport
    case calendarExport
    case taskExport
    case genericFile
}

public enum RecordStatus: String, Codable, CaseIterable, Sendable {
    case discovered
    case queued
    case extracting
    case extracted
    case needsReview
    case failed
    case deleted
}

public enum PrivacyLabel: String, Codable, CaseIterable, Sendable {
    case normal
    case privateSource
    case sensitive
    case cloudBlocked
}

public enum DeletionState: String, Codable, CaseIterable, Sendable {
    case active
    case archived
    case rawExpired
    case rawDeleted
    case derivedRetracted
    case fullForgotten
}

public enum JobStage: String, Codable, CaseIterable, Sendable {
    case ingest
    case detectType
    case extractText
    case ocr
    case transcribe
    case chunk
    case embed
    case detectEntities
    case extractClaims
    case updateGraph
    case updateWiki
}

public enum JobStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case succeeded
    case retrying
    case failed
    case cancelled
}

public enum ClaimStatus: String, Codable, CaseIterable, Sendable {
    case active
    case suspect
    case userCorrected
    case contradicted
    case retracted
}

public enum FeedbackAction: String, Codable, CaseIterable, Sendable {
    case approve
    case deny
    case edit
    case delete
    case merge
    case split
    case incidental
    case matters
    case askLater
    case forget
}

public enum GraphNodeKind: String, Codable, CaseIterable, Sendable {
    case source
    case claim
    case entity
    case event
    case task
    case project
    case habit
    case topic
    case insight
}

public enum MemoryNodeLayer: String, Codable, CaseIterable, Sendable {
    case detail
    case connector
    case importantTrait
    case definingTrait
}

public enum MemoryImportanceTier: String, Codable, CaseIterable, Sendable {
    case canonical
    case active
    case supporting
    case review
    case incidental
    case stale
    case retracted

    public var isVisibleDerivedMemory: Bool {
        switch self {
        case .canonical, .active, .supporting:
            return true
        case .review, .incidental, .stale, .retracted:
            return false
        }
    }
}

public enum TemporalMemoryKind: String, Codable, CaseIterable, Sendable {
    case current
    case historical
    case deadline
    case recurring
    case oneOff
    case stale
    case unknown
}

public struct TemporalMemoryState: Codable, Hashable, Sendable {
    public var kind: TemporalMemoryKind
    public var observedAt: Date?
    public var eventDate: Date?
    public var validFrom: Date?
    public var validUntil: Date?
    public var lastSeenAt: Date?
    public var lastConfirmedAt: Date?
    public var recurrence: String?
    public var stalenessPolicy: String

    public init(
        kind: TemporalMemoryKind = .unknown,
        observedAt: Date? = nil,
        eventDate: Date? = nil,
        validFrom: Date? = nil,
        validUntil: Date? = nil,
        lastSeenAt: Date? = nil,
        lastConfirmedAt: Date? = nil,
        recurrence: String? = nil,
        stalenessPolicy: String = "retain-until-user-or-self-healing-changes"
    ) {
        self.kind = kind
        self.observedAt = observedAt
        self.eventDate = eventDate
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.lastSeenAt = lastSeenAt
        self.lastConfirmedAt = lastConfirmedAt
        self.recurrence = recurrence
        self.stalenessPolicy = stalenessPolicy
    }
}

public enum RelationshipPredicate: String, Codable, CaseIterable, Sendable {
    case mentions
    case supports
    case contradicts
    case related
    case partOf
    case causedBy
    case temporal
    case duplicates
    case sourceOf
    case markovTransition
    case markovLoop
    case hamiltonianPath
    case concludes
}

public enum WikiPageKind: String, Codable, CaseIterable, Sendable {
    case overview
    case index
    case log
    case source
    case topic
    case person
    case project
    case action
    case question
    case contradiction
    case synthesis
    case lintReport
    case answer
}

public struct SourceRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: SourceKind
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
    public var privacyLabel: PrivacyLabel
    public var status: RecordStatus
    public var deletionState: DeletionState

    public init(
        id: String = UUID().uuidString,
        kind: SourceKind,
        connector: String = "manual",
        uri: String,
        title: String,
        mimeType: String,
        sizeBytes: Int64,
        sha256: String,
        importedAt: Date = Date(),
        observedAt: Date = Date(),
        retentionExpiresAt: Date,
        pinned: Bool = false,
        privacyLabel: PrivacyLabel = .normal,
        status: RecordStatus = .queued,
        deletionState: DeletionState = .active
    ) {
        self.id = id
        self.kind = kind
        self.connector = connector
        self.uri = uri
        self.title = title
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.importedAt = importedAt
        self.observedAt = observedAt
        self.retentionExpiresAt = retentionExpiresAt
        self.pinned = pinned
        self.privacyLabel = privacyLabel
        self.status = status
        self.deletionState = deletionState
    }
}

public struct RawBlobRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var sourceID: String
    public var contentAddress: String
    public var localPath: String
    public var mimeType: String
    public var sizeBytes: Int64
    public var sha256: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        sourceID: String,
        contentAddress: String,
        localPath: String,
        mimeType: String,
        sizeBytes: Int64,
        sha256: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.contentAddress = contentAddress
        self.localPath = localPath
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.createdAt = createdAt
    }
}

public struct ExtractionJobRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var sourceID: String
    public var stage: JobStage
    public var status: JobStatus
    public var attempts: Int
    public var nextRetryAt: Date?
    public var errorCategory: String?
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        sourceID: String,
        stage: JobStage,
        status: JobStatus = .queued,
        attempts: Int = 0,
        nextRetryAt: Date? = nil,
        errorCategory: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.stage = stage
        self.status = status
        self.attempts = attempts
        self.nextRetryAt = nextRetryAt
        self.errorCategory = errorCategory
        self.updatedAt = updatedAt
    }
}

public struct ArtifactRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var sourceID: String
    public var artifactType: String
    public var localPath: String?
    public var inlineText: String?
    public var modelID: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        sourceID: String,
        artifactType: String,
        localPath: String? = nil,
        inlineText: String? = nil,
        modelID: String = "deterministic-local",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.artifactType = artifactType
        self.localPath = localPath
        self.inlineText = inlineText
        self.modelID = modelID
        self.createdAt = createdAt
    }
}

public struct ChunkRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var sourceID: String
    public var artifactID: String
    public var text: String
    public var locationLabel: String
    public var language: String
    public var embeddingRef: String?
    public var extractionConfidence: Double

    public init(
        id: String = UUID().uuidString,
        sourceID: String,
        artifactID: String,
        text: String,
        locationLabel: String,
        language: String = "und",
        embeddingRef: String? = nil,
        extractionConfidence: Double = 0.7
    ) {
        self.id = id
        self.sourceID = sourceID
        self.artifactID = artifactID
        self.text = text
        self.locationLabel = locationLabel
        self.language = language
        self.embeddingRef = embeddingRef
        self.extractionConfidence = extractionConfidence
    }
}

public struct ClaimRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var statement: String
    public var claimType: String
    public var subjectEntityID: String?
    public var sourceRefs: [String]
    public var sourceSpanRefs: [String]
    public var confidence: Double
    public var uncertaintyReason: String
    public var contradictionGroupID: String?
    public var status: ClaimStatus
    public var createdBy: String
    public var createdAt: Date
    public var correctionLineage: [String]
    public var relevanceTier: MemoryImportanceTier?
    public var relevanceScore: Double?
    public var relevanceReason: String?
    public var temporalState: TemporalMemoryState?
    public var canonicalTargetID: String?

    public init(
        id: String = UUID().uuidString,
        statement: String,
        claimType: String = "observation",
        subjectEntityID: String? = nil,
        sourceRefs: [String],
        sourceSpanRefs: [String] = [],
        confidence: Double,
        uncertaintyReason: String,
        contradictionGroupID: String? = nil,
        status: ClaimStatus = .active,
        createdBy: String = "deterministic-local",
        createdAt: Date = Date(),
        correctionLineage: [String] = [],
        relevanceTier: MemoryImportanceTier? = nil,
        relevanceScore: Double? = nil,
        relevanceReason: String? = nil,
        temporalState: TemporalMemoryState? = nil,
        canonicalTargetID: String? = nil
    ) {
        self.id = id
        self.statement = statement
        self.claimType = claimType
        self.subjectEntityID = subjectEntityID
        self.sourceRefs = sourceRefs
        self.sourceSpanRefs = sourceSpanRefs
        self.confidence = confidence
        self.uncertaintyReason = uncertaintyReason
        self.contradictionGroupID = contradictionGroupID
        self.status = status
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.correctionLineage = correctionLineage
        self.relevanceTier = relevanceTier
        self.relevanceScore = relevanceScore
        self.relevanceReason = relevanceReason
        self.temporalState = temporalState
        self.canonicalTargetID = canonicalTargetID
    }
}

public struct EntityRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var entityType: String
    public var aliases: [String]
    public var sourceRefs: [String]
    public var confidence: Double
    public var createdAt: Date
    public var relevanceTier: MemoryImportanceTier?
    public var relevanceScore: Double?
    public var relevanceReason: String?
    public var temporalState: TemporalMemoryState?
    public var canonicalTargetID: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        entityType: String = "topic",
        aliases: [String] = [],
        sourceRefs: [String],
        confidence: Double = 0.55,
        createdAt: Date = Date(),
        relevanceTier: MemoryImportanceTier? = nil,
        relevanceScore: Double? = nil,
        relevanceReason: String? = nil,
        temporalState: TemporalMemoryState? = nil,
        canonicalTargetID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.entityType = entityType
        self.aliases = aliases
        self.sourceRefs = sourceRefs
        self.confidence = confidence
        self.createdAt = createdAt
        self.relevanceTier = relevanceTier
        self.relevanceScore = relevanceScore
        self.relevanceReason = relevanceReason
        self.temporalState = temporalState
        self.canonicalTargetID = canonicalTargetID
    }
}

public struct RelationshipRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var subjectID: String
    public var predicate: RelationshipPredicate
    public var objectID: String
    public var strength: Double
    public var confidence: Double
    public var evidenceCount: Int
    public var recency: Date
    public var sourceSpanRefs: [String]
    public var negativeFeedbackCount: Int
    public var lastRecomputedAt: Date

    public init(
        id: String = UUID().uuidString,
        subjectID: String,
        predicate: RelationshipPredicate,
        objectID: String,
        strength: Double,
        confidence: Double,
        evidenceCount: Int,
        recency: Date = Date(),
        sourceSpanRefs: [String] = [],
        negativeFeedbackCount: Int = 0,
        lastRecomputedAt: Date = Date()
    ) {
        self.id = id
        self.subjectID = subjectID
        self.predicate = predicate
        self.objectID = objectID
        self.strength = strength
        self.confidence = confidence
        self.evidenceCount = evidenceCount
        self.recency = recency
        self.sourceSpanRefs = sourceSpanRefs
        self.negativeFeedbackCount = negativeFeedbackCount
        self.lastRecomputedAt = lastRecomputedAt
    }
}

public struct WikiPageRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var markdown: String
    public var sourceRefs: [String]
    public var claimRefs: [String]
    public var updatedAt: Date
    public var slug: String
    public var kind: WikiPageKind
    public var summary: String
    public var frontmatter: [String: String]
    public var outboundLinks: [String]
    public var inboundLinks: [String]
    public var filePath: String?
    public var revision: Int

    public init(
        id: String = "overview",
        title: String,
        markdown: String,
        sourceRefs: [String],
        claimRefs: [String],
        updatedAt: Date = Date(),
        slug: String? = nil,
        kind: WikiPageKind = .overview,
        summary: String = "",
        frontmatter: [String: String] = [:],
        outboundLinks: [String] = [],
        inboundLinks: [String] = [],
        filePath: String? = nil,
        revision: Int = 1
    ) {
        self.id = id
        self.title = title
        self.markdown = markdown
        self.sourceRefs = sourceRefs
        self.claimRefs = claimRefs
        self.updatedAt = updatedAt
        self.slug = slug ?? WikiPageRecord.slugify(title.isEmpty ? id : title)
        self.kind = kind
        self.summary = summary
        self.frontmatter = frontmatter
        self.outboundLinks = outboundLinks
        self.inboundLinks = inboundLinks
        self.filePath = filePath
        self.revision = revision
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case markdown
        case sourceRefs
        case claimRefs
        case updatedAt
        case slug
        case kind
        case summary
        case frontmatter
        case outboundLinks
        case inboundLinks
        case filePath
        case revision
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        markdown = try container.decode(String.self, forKey: .markdown)
        sourceRefs = try container.decodeIfPresent([String].self, forKey: .sourceRefs) ?? []
        claimRefs = try container.decodeIfPresent([String].self, forKey: .claimRefs) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(timeIntervalSince1970: 0)
        slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? WikiPageRecord.slugify(title.isEmpty ? id : title)
        kind = try container.decodeIfPresent(WikiPageKind.self, forKey: .kind) ?? (id == "overview" ? .overview : .topic)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        frontmatter = try container.decodeIfPresent([String: String].self, forKey: .frontmatter) ?? [:]
        outboundLinks = try container.decodeIfPresent([String].self, forKey: .outboundLinks) ?? []
        inboundLinks = try container.decodeIfPresent([String].self, forKey: .inboundLinks) ?? []
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1
    }

    public static func slugify(_ value: String) -> String {
        let lowered = value.lowercased()
        let allowed = CharacterSet.alphanumerics
        var scalars: [Character] = []
        var previousDash = false
        for scalar in lowered.unicodeScalars {
            if allowed.contains(scalar) {
                scalars.append(Character(scalar))
                previousDash = false
            } else if !previousDash {
                scalars.append("-")
                previousDash = true
            }
        }
        let cleaned = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return cleaned.isEmpty ? "untitled" : String(cleaned.prefix(96))
    }
}

public struct FeedbackRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var targetType: String
    public var targetID: String
    public var action: FeedbackAction
    public var note: String
    public var timestamp: Date
    public var cascadePolicy: String
    public var resultingRevisionIDs: [String]

    public init(
        id: String = UUID().uuidString,
        targetType: String,
        targetID: String,
        action: FeedbackAction,
        note: String = "",
        timestamp: Date = Date(),
        cascadePolicy: String = "target-only",
        resultingRevisionIDs: [String] = []
    ) {
        self.id = id
        self.targetType = targetType
        self.targetID = targetID
        self.action = action
        self.note = note
        self.timestamp = timestamp
        self.cascadePolicy = cascadePolicy
        self.resultingRevisionIDs = resultingRevisionIDs
    }
}

public struct AuditEventRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var eventType: String
    public var targetType: String
    public var targetID: String
    public var actor: String
    public var modelID: String?
    public var promptConfigHash: String?
    public var sourceRefs: [String]
    public var timestamp: Date
    public var detail: String

    public init(
        id: String = UUID().uuidString,
        eventType: String,
        targetType: String,
        targetID: String,
        actor: String = "local-system",
        modelID: String? = nil,
        promptConfigHash: String? = nil,
        sourceRefs: [String] = [],
        timestamp: Date = Date(),
        detail: String = ""
    ) {
        self.id = id
        self.eventType = eventType
        self.targetType = targetType
        self.targetID = targetID
        self.actor = actor
        self.modelID = modelID
        self.promptConfigHash = promptConfigHash
        self.sourceRefs = sourceRefs
        self.timestamp = timestamp
        self.detail = detail
    }
}

public struct GraphNodeRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var kind: GraphNodeKind
    public var confidence: Double
    public var sourceRefs: [String]
    public var x: Double
    public var y: Double
    public var timestamp: Date?
    public var memoryLayer: MemoryNodeLayer
    public var semanticColorKey: String?
    public var memoryLayerOverrideSource: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case kind
        case confidence
        case sourceRefs
        case x
        case y
        case timestamp
        case memoryLayer
        case semanticColorKey
        case memoryLayerOverrideSource
    }

    public init(
        id: String,
        title: String,
        kind: GraphNodeKind,
        confidence: Double,
        sourceRefs: [String],
        x: Double = 0,
        y: Double = 0,
        timestamp: Date? = nil,
        memoryLayer: MemoryNodeLayer = .detail,
        semanticColorKey: String? = nil,
        memoryLayerOverrideSource: String? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.confidence = confidence
        self.sourceRefs = sourceRefs
        self.x = x
        self.y = y
        self.timestamp = timestamp
        self.memoryLayer = memoryLayer
        self.semanticColorKey = semanticColorKey
        self.memoryLayerOverrideSource = memoryLayerOverrideSource
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.kind = try container.decode(GraphNodeKind.self, forKey: .kind)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
        self.sourceRefs = try container.decode([String].self, forKey: .sourceRefs)
        self.x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 0
        self.y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 0
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
        self.memoryLayer = try container.decodeIfPresent(MemoryNodeLayer.self, forKey: .memoryLayer) ?? .detail
        self.semanticColorKey = try container.decodeIfPresent(String.self, forKey: .semanticColorKey)
        self.memoryLayerOverrideSource = try container.decodeIfPresent(String.self, forKey: .memoryLayerOverrideSource)
    }
}

public struct GraphEdgeRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var fromID: String
    public var toID: String
    public var predicate: RelationshipPredicate
    public var strength: Double
    public var confidence: Double
    public var evidenceCount: Int
    public var sourceRefs: [String]
    public var explanation: String

    public init(
        id: String = UUID().uuidString,
        fromID: String,
        toID: String,
        predicate: RelationshipPredicate,
        strength: Double,
        confidence: Double,
        evidenceCount: Int,
        sourceRefs: [String] = [],
        explanation: String = ""
    ) {
        self.id = id
        self.fromID = fromID
        self.toID = toID
        self.predicate = predicate
        self.strength = strength
        self.confidence = confidence
        self.evidenceCount = evidenceCount
        self.sourceRefs = sourceRefs
        self.explanation = explanation
    }
}

public struct HiveGraphSnapshot: Codable, Hashable, Sendable {
    public var nodes: [GraphNodeRecord]
    public var edges: [GraphEdgeRecord]

    public init(nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) {
        self.nodes = nodes
        self.edges = edges
    }
}

public struct RuntimeProfile: Codable, Hashable, Sendable {
    public enum ThermalState: String, Codable, Sendable {
        case nominal
        case fair
        case serious
        case critical
        case unknown
    }

    public enum PowerState: String, Codable, Sendable {
        case pluggedIn
        case battery
        case unknown
    }

    public var chipName: String
    public var physicalMemoryBytes: UInt64
    public var processorCount: Int
    public var thermalState: ThermalState
    public var powerState: PowerState
    public var batteryChargeFraction: Double?
    public var lowPowerModeEnabled: Bool
    public var foregroundUserActive: Bool

    public init(
        chipName: String,
        physicalMemoryBytes: UInt64,
        processorCount: Int,
        thermalState: ThermalState,
        powerState: PowerState,
        batteryChargeFraction: Double? = nil,
        lowPowerModeEnabled: Bool,
        foregroundUserActive: Bool
    ) {
        self.chipName = chipName
        self.physicalMemoryBytes = physicalMemoryBytes
        self.processorCount = processorCount
        self.thermalState = thermalState
        self.powerState = powerState
        self.batteryChargeFraction = batteryChargeFraction
        self.lowPowerModeEnabled = lowPowerModeEnabled
        self.foregroundUserActive = foregroundUserActive
    }
}

public struct ModelCapability: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var task: String
    public var modelName: String
    public var memoryTierGB: Int
    public var localOnly: Bool
    public var installed: Bool
    public var notes: String

    public init(
        id: String,
        task: String,
        modelName: String,
        memoryTierGB: Int,
        localOnly: Bool = true,
        installed: Bool = false,
        notes: String
    ) {
        self.id = id
        self.task = task
        self.modelName = modelName
        self.memoryTierGB = memoryTierGB
        self.localOnly = localOnly
        self.installed = installed
        self.notes = notes
    }
}
