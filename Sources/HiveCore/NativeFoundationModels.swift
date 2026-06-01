import Foundation
import SwiftData

public struct ConfidenceScore: Codable, Hashable, Sendable, Comparable {
    public var value: Double

    public init(_ value: Double) {
        self.value = min(1, max(0, value))
    }

    public static func < (lhs: ConfidenceScore, rhs: ConfidenceScore) -> Bool {
        lhs.value < rhs.value
    }
}

public enum ProcessingState: String, Codable, CaseIterable, Sendable {
    case discovered
    case queued
    case processing
    case synthesized
    case needsReview
    case failed
    case deleted

    public init(recordStatus: RecordStatus) {
        switch recordStatus {
        case .discovered: self = .discovered
        case .queued: self = .queued
        case .extracting, .extracted: self = recordStatus == .extracting ? .processing : .synthesized
        case .needsReview: self = .needsReview
        case .failed: self = .failed
        case .deleted: self = .deleted
        }
    }

    public var recordStatus: RecordStatus {
        switch self {
        case .discovered: return .discovered
        case .queued: return .queued
        case .processing: return .extracting
        case .synthesized: return .extracted
        case .needsReview: return .needsReview
        case .failed: return .failed
        case .deleted: return .deleted
        }
    }
}

public enum ConnectionType: String, Codable, CaseIterable, Sendable {
    case mentions
    case supports
    case contradicts
    case related
    case partOf
    case causedBy
    case temporal
    case duplicates
    case concludes

    public init(predicate: RelationshipPredicate) {
        switch predicate {
        case .mentions: self = .mentions
        case .supports, .sourceOf: self = .supports
        case .contradicts: self = .contradicts
        case .partOf: self = .partOf
        case .causedBy: self = .causedBy
        case .temporal: self = .temporal
        case .duplicates: self = .duplicates
        case .concludes: self = .concludes
        case .related, .markovTransition, .markovLoop, .hamiltonianPath: self = .related
        }
    }

    public var predicate: RelationshipPredicate {
        switch self {
        case .mentions: return .mentions
        case .supports: return .supports
        case .contradicts: return .contradicts
        case .related: return .related
        case .partOf: return .partOf
        case .causedBy: return .causedBy
        case .temporal: return .temporal
        case .duplicates: return .duplicates
        case .concludes: return .concludes
        }
    }
}

@Model
public final class RawSource {
    public var recordID: String
    public var title: String
    public var sourceKindRawValue: String
    public var originalURI: String
    public var localURI: String?
    public var markdownBody: String?
    public var extractedTextRef: String?
    public var importedAt: Date
    public var updatedAt: Date
    public var processingStateRawValue: String
    public var contentHash: String
    public var confidence: Double
    public var summary: String
    public var auditLogJSON: String

    public var id: String { recordID }
    public var sourceKind: SourceKind { SourceKind(rawValue: sourceKindRawValue) ?? .genericFile }
    public var processingState: ProcessingState { ProcessingState(rawValue: processingStateRawValue) ?? .queued }
    public var auditLog: [String] { Self.decode(auditLogJSON) }

    public init(
        recordID: String = UUID().uuidString,
        title: String,
        sourceKind: SourceKind,
        originalURI: String,
        localURI: String? = nil,
        markdownBody: String? = nil,
        extractedTextRef: String? = nil,
        importedAt: Date = Date(),
        updatedAt: Date = Date(),
        processingState: ProcessingState = .queued,
        contentHash: String,
        confidence: Double = 1,
        summary: String = "",
        auditLog: [String] = []
    ) {
        self.recordID = recordID
        self.title = title
        self.sourceKindRawValue = sourceKind.rawValue
        self.originalURI = originalURI
        self.localURI = localURI
        self.markdownBody = markdownBody
        self.extractedTextRef = extractedTextRef
        self.importedAt = importedAt
        self.updatedAt = updatedAt
        self.processingStateRawValue = processingState.rawValue
        self.contentHash = contentHash
        self.confidence = ConfidenceScore(confidence).value
        self.summary = summary
        self.auditLogJSON = Self.encode(auditLog)
    }

    public convenience init(record: SourceRecord, markdownBody: String? = nil, extractedTextRef: String? = nil, summary: String = "", confidence: Double = 1, auditLog: [String] = []) {
        self.init(
            recordID: record.id,
            title: record.title,
            sourceKind: record.kind,
            originalURI: record.uri,
            localURI: nil,
            markdownBody: markdownBody,
            extractedTextRef: extractedTextRef,
            importedAt: record.importedAt,
            updatedAt: record.observedAt,
            processingState: ProcessingState(recordStatus: record.status),
            contentHash: record.sha256,
            confidence: confidence,
            summary: summary,
            auditLog: auditLog
        )
    }

    public func sourceRecord(retentionExpiresAt: Date = Date().addingTimeInterval(60 * 60 * 24 * 365), privacyLabel: PrivacyLabel = .normal, pinned: Bool = false, deletionState: DeletionState = .active) -> SourceRecord {
        SourceRecord(
            id: recordID,
            kind: sourceKind,
            connector: "swiftdata",
            uri: originalURI,
            title: title,
            mimeType: "text/markdown",
            sizeBytes: Int64(markdownBody?.utf8.count ?? 0),
            sha256: contentHash,
            importedAt: importedAt,
            observedAt: updatedAt,
            retentionExpiresAt: retentionExpiresAt,
            pinned: pinned,
            privacyLabel: privacyLabel,
            status: processingState.recordStatus,
            deletionState: deletionState
        )
    }
}

@Model
public final class WikiNode {
    public var recordID: String
    public var title: String
    public var slug: String
    public var editableMarkdown: String
    public var summary: String
    public var nodeKindRawValue: String
    public var aliasesJSON: String
    public var tagsJSON: String
    public var confidence: Double
    public var userAuthored: Bool
    public var lastSynthesizedAt: Date?
    public var graphX: Double
    public var graphY: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var auditLogJSON: String

    public var id: String { recordID }
    public var kind: WikiPageKind { WikiPageKind(rawValue: nodeKindRawValue) ?? .topic }
    public var aliases: [String] { Self.decode(aliasesJSON) }
    public var tags: [String] { Self.decode(tagsJSON) }
    public var auditLog: [String] { Self.decode(auditLogJSON) }

    public init(
        recordID: String = UUID().uuidString,
        title: String,
        slug: String? = nil,
        editableMarkdown: String,
        summary: String = "",
        kind: WikiPageKind = .topic,
        aliases: [String] = [],
        tags: [String] = [],
        confidence: Double = 0.75,
        userAuthored: Bool = false,
        lastSynthesizedAt: Date? = nil,
        graphX: Double = 0,
        graphY: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        auditLog: [String] = []
    ) {
        self.recordID = recordID
        self.title = title
        self.slug = slug ?? WikiPageRecord.slugify(title.isEmpty ? recordID : title)
        self.editableMarkdown = editableMarkdown
        self.summary = summary
        self.nodeKindRawValue = kind.rawValue
        self.aliasesJSON = Self.encode(aliases)
        self.tagsJSON = Self.encode(tags)
        self.confidence = ConfidenceScore(confidence).value
        self.userAuthored = userAuthored
        self.lastSynthesizedAt = lastSynthesizedAt
        self.graphX = graphX
        self.graphY = graphY
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.auditLogJSON = Self.encode(auditLog)
    }

    public convenience init(record: WikiPageRecord, graphX: Double = 0, graphY: Double = 0, userAuthored: Bool = false, confidence: Double = 0.85, auditLog: [String] = []) {
        self.init(
            recordID: record.id,
            title: record.title,
            slug: record.slug,
            editableMarkdown: record.markdown,
            summary: record.summary,
            kind: record.kind,
            aliases: record.outboundLinks,
            tags: Array(record.frontmatter.keys).sorted(),
            confidence: confidence,
            userAuthored: userAuthored || record.frontmatter["authored_by"] == "user",
            lastSynthesizedAt: record.updatedAt,
            graphX: graphX,
            graphY: graphY,
            createdAt: record.updatedAt,
            updatedAt: record.updatedAt,
            auditLog: auditLog
        )
    }

    public func wikiPageRecord(sourceRefs: [String] = [], claimRefs: [String] = []) -> WikiPageRecord {
        WikiPageRecord(
            id: recordID,
            title: title,
            markdown: editableMarkdown,
            sourceRefs: sourceRefs,
            claimRefs: claimRefs,
            updatedAt: updatedAt,
            slug: slug,
            kind: kind,
            summary: summary,
            frontmatter: userAuthored ? ["authored_by": "user"] : [:],
            outboundLinks: aliases,
            inboundLinks: [],
            revision: 1
        )
    }
}

@Model
public final class Connection {
    public var recordID: String
    public var sourceNodeID: String
    public var targetNodeID: String
    public var typeRawValue: String
    public var strength: Double
    public var confidence: Double
    public var evidenceCount: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var auditLogJSON: String

    public var id: String { recordID }
    public var type: ConnectionType { ConnectionType(rawValue: typeRawValue) ?? .related }
    public var auditLog: [String] { Self.decode(auditLogJSON) }

    public init(
        recordID: String = UUID().uuidString,
        sourceNodeID: String,
        targetNodeID: String,
        type: ConnectionType = .related,
        strength: Double,
        confidence: Double,
        evidenceCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        auditLog: [String] = []
    ) {
        self.recordID = recordID
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.typeRawValue = type.rawValue
        self.strength = min(1, max(0, strength))
        self.confidence = ConfidenceScore(confidence).value
        self.evidenceCount = evidenceCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.auditLogJSON = Self.encode(auditLog)
    }

    public convenience init(record: RelationshipRecord, auditLog: [String] = []) {
        self.init(
            recordID: record.id,
            sourceNodeID: record.subjectID,
            targetNodeID: record.objectID,
            type: ConnectionType(predicate: record.predicate),
            strength: record.strength,
            confidence: record.confidence,
            evidenceCount: record.evidenceCount,
            createdAt: record.lastRecomputedAt,
            updatedAt: record.recency,
            auditLog: auditLog
        )
    }

    public func relationshipRecord(sourceSpanRefs: [String] = []) -> RelationshipRecord {
        RelationshipRecord(
            id: recordID,
            subjectID: sourceNodeID,
            predicate: type.predicate,
            objectID: targetNodeID,
            strength: strength,
            confidence: confidence,
            evidenceCount: evidenceCount,
            recency: updatedAt,
            sourceSpanRefs: sourceSpanRefs,
            lastRecomputedAt: updatedAt
        )
    }
}

public enum WikiInlineSegment: Hashable, Sendable {
    case text(String)
    case wikiLink(label: String, target: String)
}

public struct WikiLinkParser: Sendable {
    public init() {}

    public func parse(_ value: String) -> [WikiInlineSegment] {
        var segments: [WikiInlineSegment] = []
        var remainder = value[...]
        while let open = remainder.range(of: "[[") {
            if open.lowerBound > remainder.startIndex {
                segments.append(.text(String(remainder[remainder.startIndex..<open.lowerBound])))
            }
            guard let close = remainder[open.upperBound...].range(of: "]]") else {
                segments.append(.text(String(remainder[open.lowerBound...])))
                return mergeTextSegments(segments)
            }
            let raw = String(remainder[open.upperBound..<close.lowerBound])
            let parts = raw.split(separator: "|", maxSplits: 1).map(String.init)
            let target = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
            let label = (parts.count > 1 ? parts[1] : parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !target.isEmpty {
                segments.append(.wikiLink(label: label.isEmpty ? target : label, target: target))
            }
            remainder = remainder[close.upperBound...]
        }
        if !remainder.isEmpty {
            segments.append(.text(String(remainder)))
        }
        return mergeTextSegments(segments)
    }

    private func mergeTextSegments(_ segments: [WikiInlineSegment]) -> [WikiInlineSegment] {
        var merged: [WikiInlineSegment] = []
        for segment in segments {
            if case .text(let value) = segment,
               case .text(let previous) = merged.last {
                merged.removeLast()
                merged.append(.text(previous + value))
            } else {
                merged.append(segment)
            }
        }
        return merged
    }
}
