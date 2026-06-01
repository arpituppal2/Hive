import Foundation
import SQLite3

public enum HiveStoreError: Error, LocalizedError, Sendable {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
    case decodeFailed(String)
    case missingRecord(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let message): "SQLite open failed: \(message)"
        case .prepareFailed(let message): "SQLite prepare failed: \(message)"
        case .stepFailed(let message): "SQLite step failed: \(message)"
        case .bindFailed(let message): "SQLite bind failed: \(message)"
        case .decodeFailed(let message): "SQLite decode failed: \(message)"
        case .missingRecord(let message): "Missing record: \(message)"
        }
    }
}

private enum SQLiteValue {
    case text(String)
    case int(Int64)
    case double(Double)
    case null
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class HiveStore: @unchecked Sendable {
    public let databaseURL: URL
    private var db: OpaquePointer?
    private let lock = NSRecursiveLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(databaseURL.path, &db, flags, nil) != SQLITE_OK {
            throw HiveStoreError.openFailed(lastErrorMessage)
        }
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    public func migrate() throws {
        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA foreign_keys=ON")
        try execute("PRAGMA busy_timeout=5000")

        try execute("""
        CREATE TABLE IF NOT EXISTS sources (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            title TEXT NOT NULL,
            imported_at REAL NOT NULL,
            retention_expires_at REAL NOT NULL,
            pinned INTEGER NOT NULL,
            privacy_label TEXT NOT NULL,
            deletion_state TEXT NOT NULL,
            status TEXT NOT NULL,
            sha256 TEXT NOT NULL,
            uri TEXT NOT NULL,
            json TEXT NOT NULL
        )
        """)
        try execute("CREATE INDEX IF NOT EXISTS idx_sources_retention ON sources(retention_expires_at, pinned, deletion_state)")
        try execute("CREATE INDEX IF NOT EXISTS idx_sources_status ON sources(status)")
        try execute("CREATE INDEX IF NOT EXISTS idx_sources_sha ON sources(sha256)")

        try createJSONTable("raw_blobs")
        try execute("CREATE INDEX IF NOT EXISTS idx_raw_blobs_source ON raw_blobs(source_id)")
        try createJSONTable("extraction_jobs")
        try execute("CREATE INDEX IF NOT EXISTS idx_jobs_status ON extraction_jobs(status, updated_at)")
        try execute("CREATE INDEX IF NOT EXISTS idx_jobs_source ON extraction_jobs(source_id)")
        try createJSONTable("artifacts")
        try execute("CREATE INDEX IF NOT EXISTS idx_artifacts_source ON artifacts(source_id)")
        try createJSONTable("chunks")
        try execute("CREATE INDEX IF NOT EXISTS idx_chunks_source ON chunks(source_id)")
        try createJSONTable("claims")
        try execute("CREATE INDEX IF NOT EXISTS idx_claims_status ON claims(status)")
        try createJSONTable("entities")
        try createJSONTable("relationships")
        try createJSONTable("wiki_pages")
        try createJSONTable("feedback")
        try createJSONTable("audit_log")

        try execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS chunk_fts USING fts5(
            chunk_id UNINDEXED,
            source_id UNINDEXED,
            text
        )
        """)
    }

    private func createJSONTable(_ name: String) throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS \(name) (
            id TEXT PRIMARY KEY,
            source_id TEXT,
            status TEXT,
            updated_at REAL NOT NULL,
            json TEXT NOT NULL
        )
        """)
    }

    public func saveSource(_ source: SourceRecord) throws {
        let json = try encode(source)
        try execute(
            """
            INSERT INTO sources (
                id, kind, title, imported_at, retention_expires_at, pinned,
                privacy_label, deletion_state, status, sha256, uri, json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                kind=excluded.kind,
                title=excluded.title,
                imported_at=excluded.imported_at,
                retention_expires_at=excluded.retention_expires_at,
                pinned=excluded.pinned,
                privacy_label=excluded.privacy_label,
                deletion_state=excluded.deletion_state,
                status=excluded.status,
                sha256=excluded.sha256,
                uri=excluded.uri,
                json=excluded.json
            """,
            [
                .text(source.id),
                .text(source.kind.rawValue),
                .text(source.title),
                .double(source.importedAt.timeIntervalSince1970),
                .double(source.retentionExpiresAt.timeIntervalSince1970),
                .int(source.pinned ? 1 : 0),
                .text(source.privacyLabel.rawValue),
                .text(source.deletionState.rawValue),
                .text(source.status.rawValue),
                .text(source.sha256),
                .text(source.uri),
                .text(json)
            ]
        )
    }

    public func fetchSources(includeForgotten: Bool = false) throws -> [SourceRecord] {
        let sql = includeForgotten
            ? "SELECT json FROM sources ORDER BY imported_at DESC"
            : "SELECT json FROM sources WHERE deletion_state != ? ORDER BY imported_at DESC"
        let values: [SQLiteValue] = includeForgotten ? [] : [.text(DeletionState.fullForgotten.rawValue)]
        return try fetchJSON(sql, values)
    }

    public func fetchSource(id: String) throws -> SourceRecord? {
        let records: [SourceRecord] = try fetchJSON("SELECT json FROM sources WHERE id = ?", [.text(id)])
        return records.first
    }

    public func fetchSources(uri: String) throws -> [SourceRecord] {
        try fetchJSON("SELECT json FROM sources WHERE uri = ? ORDER BY imported_at DESC", [.text(uri)])
    }

    public func setSourcePinned(id: String, pinned: Bool) throws {
        guard var source = try fetchSource(id: id) else {
            throw HiveStoreError.missingRecord("source \(id)")
        }
        source.pinned = pinned
        try saveSource(source)
        try appendAudit(AuditEventRecord(
            eventType: pinned ? "source.pinned" : "source.unpinned",
            targetType: "source",
            targetID: id
        ))
    }

    public func markSourceStatus(id: String, status: RecordStatus) throws {
        guard var source = try fetchSource(id: id) else {
            throw HiveStoreError.missingRecord("source \(id)")
        }
        source.status = status
        try saveSource(source)
    }

    public func saveRawBlob(_ blob: RawBlobRecord) throws {
        try upsertJSON(table: "raw_blobs", id: blob.id, sourceID: blob.sourceID, status: nil, updatedAt: blob.createdAt, blob)
    }

    public func fetchRawBlobs(sourceID: String? = nil) throws -> [RawBlobRecord] {
        if let sourceID {
            return try fetchJSON("SELECT json FROM raw_blobs WHERE source_id = ?", [.text(sourceID)])
        }
        return try fetchJSON("SELECT json FROM raw_blobs ORDER BY updated_at DESC", [])
    }

    public func deleteRawBlobRecords(sourceID: String) throws {
        try execute("DELETE FROM raw_blobs WHERE source_id = ?", [.text(sourceID)])
    }

    public func saveJob(_ job: ExtractionJobRecord) throws {
        try upsertJSON(
            table: "extraction_jobs",
            id: job.id,
            sourceID: job.sourceID,
            status: job.status.rawValue,
            updatedAt: job.updatedAt,
            job
        )
    }

    public func fetchJobs(status: JobStatus? = nil) throws -> [ExtractionJobRecord] {
        if let status {
            return try fetchJSON(
                "SELECT json FROM extraction_jobs WHERE status = ? ORDER BY updated_at ASC",
                [.text(status.rawValue)]
            )
        }
        return try fetchJSON("SELECT json FROM extraction_jobs ORDER BY updated_at DESC", [])
    }

    public func saveArtifact(_ artifact: ArtifactRecord) throws {
        try upsertJSON(table: "artifacts", id: artifact.id, sourceID: artifact.sourceID, status: nil, updatedAt: artifact.createdAt, artifact)
    }

    public func fetchArtifacts(sourceID: String? = nil) throws -> [ArtifactRecord] {
        if let sourceID {
            return try fetchJSON("SELECT json FROM artifacts WHERE source_id = ?", [.text(sourceID)])
        }
        return try fetchJSON("SELECT json FROM artifacts ORDER BY updated_at DESC", [])
    }

    public func saveChunk(_ chunk: ChunkRecord) throws {
        try upsertJSON(table: "chunks", id: chunk.id, sourceID: chunk.sourceID, status: nil, updatedAt: Date(), chunk)
        try execute("DELETE FROM chunk_fts WHERE chunk_id = ?", [.text(chunk.id)])
        try execute(
            "INSERT INTO chunk_fts(chunk_id, source_id, text) VALUES (?, ?, ?)",
            [.text(chunk.id), .text(chunk.sourceID), .text(chunk.text)]
        )
    }

    public func fetchChunks(sourceID: String? = nil) throws -> [ChunkRecord] {
        if let sourceID {
            return try fetchJSON("SELECT json FROM chunks WHERE source_id = ?", [.text(sourceID)])
        }
        return try fetchJSON("SELECT json FROM chunks ORDER BY updated_at DESC", [])
    }

    public func searchChunks(_ query: String, limit: Int = 20) throws -> [ChunkRecord] {
        let sanitizedLimit = max(1, min(limit, 100))
        let ids = try fetchTextColumn(
            "SELECT chunk_id FROM chunk_fts WHERE chunk_fts MATCH ? LIMIT \(sanitizedLimit)",
            [.text(query)]
        )
        guard !ids.isEmpty else { return [] }
        return try ids.compactMap { id in
            let records: [ChunkRecord] = try fetchJSON("SELECT json FROM chunks WHERE id = ?", [.text(id)])
            return records.first
        }
    }

    @discardableResult
    public func scrubRawExtractedText(sourceID: String) throws -> (artifactCount: Int, chunkCount: Int) {
        let artifacts = try fetchArtifacts(sourceID: sourceID)
        for var artifact in artifacts {
            artifact.localPath = nil
            artifact.inlineText = nil
            try saveArtifact(artifact)
        }

        let chunks = try fetchChunks(sourceID: sourceID)
        for var chunk in chunks {
            chunk.text = "[Raw text removed; provenance capsule retained for \(chunk.locationLabel).]"
            chunk.embeddingRef = nil
            try upsertJSON(table: "chunks", id: chunk.id, sourceID: chunk.sourceID, status: nil, updatedAt: Date(), chunk)
        }
        try execute("DELETE FROM chunk_fts WHERE source_id = ?", [.text(sourceID)])
        return (artifacts.count, chunks.count)
    }

    public func saveClaim(_ claim: ClaimRecord) throws {
        if shouldMergeClaim(claim),
           var existing = try fetchClaims().first(where: { candidate in
               candidate.id != claim.id && claimCanonicalKey(candidate) == claimCanonicalKey(claim)
           }) {
            existing = mergedClaim(existing, with: claim)
            try upsertClaimDirect(existing)
            try execute("DELETE FROM claims WHERE id = ?", [.text(claim.id)])
            return
        }
        try upsertClaimDirect(claim)
    }

    public func fetchClaims(includeRetracted: Bool = false) throws -> [ClaimRecord] {
        if includeRetracted {
            return try fetchJSON("SELECT json FROM claims ORDER BY updated_at DESC", [])
        }
        return try fetchJSON(
            "SELECT json FROM claims WHERE status != ? ORDER BY updated_at DESC",
            [.text(ClaimStatus.retracted.rawValue)]
        )
    }

    public func fetchClaim(id: String, includeRetracted: Bool = true) throws -> ClaimRecord? {
        let records: [ClaimRecord] = try fetchJSON("SELECT json FROM claims WHERE id = ?", [.text(id)])
        guard let claim = records.first else { return nil }
        if !includeRetracted && claim.status == .retracted { return nil }
        return claim
    }

    @discardableResult
    public func dedupeClaims() throws -> Int {
        let claims = try fetchClaims()
            .filter(shouldMergeClaim)
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id < $1.id
            }
        var canonical: [String: ClaimRecord] = [:]
        var removed = 0

        for claim in claims {
            let key = claimCanonicalKey(claim)
            if var keeper = canonical[key] {
                keeper = mergedClaim(keeper, with: claim)
                try upsertClaimDirect(keeper)
                try execute("DELETE FROM claims WHERE id = ?", [.text(claim.id)])
                removed += 1
            } else {
                canonical[key] = claim
            }
        }
        return removed
    }

    public func saveEntity(_ entity: EntityRecord) throws {
        if var existing = try fetchEntities().first(where: { candidate in
            candidate.id != entity.id && entityCanonicalKey(candidate) == entityCanonicalKey(entity)
        }) {
            existing = mergedEntity(existing, with: entity)
            try upsertEntityDirect(existing)
            try execute("DELETE FROM entities WHERE id = ?", [.text(entity.id)])
            return
        }
        try upsertEntityDirect(entity)
    }

    public func fetchEntities() throws -> [EntityRecord] {
        try fetchJSON("SELECT json FROM entities ORDER BY updated_at DESC", [])
    }

    public func deleteEntity(id: String) throws {
        try execute("DELETE FROM entities WHERE id = ?", [.text(id)])
    }

    @discardableResult
    public func deleteAutogeneratedDerivedDataForMemoryImport(sourceID: String) throws -> Int {
        try deleteAutogeneratedDerivedDataForMemoryImports(sourceIDs: [sourceID])
    }

    @discardableResult
    public func deleteAutogeneratedDerivedDataForMemoryImports(sourceIDs: Set<String>) throws -> Int {
        var removed = 0
        for claim in try fetchClaims(includeRetracted: true) where !claim.sourceRefs.isEmpty && Set(claim.sourceRefs).isSubset(of: sourceIDs) && claim.createdBy != "ai-memory-seed" {
            try deleteClaim(id: claim.id)
            removed += 1
        }
        for entity in try fetchEntities() where !entity.sourceRefs.isEmpty && Set(entity.sourceRefs).isSubset(of: sourceIDs) {
            try deleteEntity(id: entity.id)
            removed += 1
        }
        return removed
    }

    @discardableResult
    public func dedupeEntities() throws -> Int {
        let entities = try fetchEntities().sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id < $1.id
        }
        var canonical: [String: EntityRecord] = [:]
        var remappedIDs: [String: String] = [:]
        var removed = 0

        for entity in entities {
            let key = entityCanonicalKey(entity)
            if var keeper = canonical[key] {
                keeper = mergedEntity(keeper, with: entity)
                try upsertEntityDirect(keeper)
                try execute("DELETE FROM entities WHERE id = ?", [.text(entity.id)])
                remappedIDs[entity.id] = keeper.id
                canonical[key] = keeper
                removed += 1
            } else {
                canonical[key] = entity
            }
        }

        if !remappedIDs.isEmpty {
            try rewriteClaimEntityReferences(remappedIDs)
        }
        return removed
    }

    public func saveRelationship(_ relationship: RelationshipRecord) throws {
        try upsertJSON(table: "relationships", id: relationship.id, sourceID: relationship.sourceSpanRefs.first, status: nil, updatedAt: relationship.lastRecomputedAt, relationship)
    }

    public func fetchRelationships() throws -> [RelationshipRecord] {
        try fetchJSON("SELECT json FROM relationships ORDER BY updated_at DESC", [])
    }

    public func clearRelationships() throws {
        try execute("DELETE FROM relationships")
    }

    @discardableResult
    public func resetDerivedMemoryKeepingRawSources(reason: String) throws -> Int {
        let claimCount = try fetchClaims(includeRetracted: true).count
        let entityCount = try fetchEntities().count
        let relationshipCount = try fetchRelationships().count
        let wikiCount = try fetchWikiPages().count
        try execute("DELETE FROM claims")
        try execute("DELETE FROM entities")
        try execute("DELETE FROM relationships")
        try execute("DELETE FROM wiki_pages")
        try appendAudit(AuditEventRecord(
            eventType: "memoryBoundary.derivedReset",
            targetType: "memory",
            targetID: "derived",
            detail: "\(reason) Removed \(claimCount) claims, \(entityCount) entities, \(relationshipCount) relationships, and \(wikiCount) Colony articles while preserving Field files."
        ))
        return claimCount + entityCount + relationshipCount + wikiCount
    }

    @discardableResult
    public func deleteBrowserDomainDerivedMemoryRecords() throws -> Int {
        var removed = 0
        let browserSourceIDs = Set(try fetchSources(includeForgotten: true).filter {
            $0.kind == .browserHistory || $0.kind == .browserBookmark || $0.connector.contains("browser")
        }.map(\.id))

        for claim in try fetchClaims(includeRetracted: true) where
            claim.claimType == "browser-signal"
                || claim.claimType == "browser-session-intent"
                || claim.createdBy == "autonomous-browser-explorer"
                || claim.createdBy == "guided-browser-explorer"
                || MemoryCompiler.isRawLinkLike(claim.statement) {
            try deleteClaim(id: claim.id)
            removed += 1
        }

        for entity in try fetchEntities() where
            entity.id.hasPrefix("browser-signal-entity-")
                || MemoryCompiler.isRawLinkLike(entity.name)
                || entity.sourceRefs.contains(where: { browserSourceIDs.contains($0) }) {
            try deleteEntity(id: entity.id)
            removed += 1
        }

        for relationship in try fetchRelationships() where
            relationship.subjectID.hasPrefix("browser-signal-entity-")
                || relationship.objectID.hasPrefix("browser-signal-entity-")
                || relationship.sourceSpanRefs.contains(where: { browserSourceIDs.contains($0) }) {
            try execute("DELETE FROM relationships WHERE id = ?", [.text(relationship.id)])
            removed += 1
        }

        let sourcePageIDs = try fetchWikiPages().filter {
            $0.kind == .source
                || $0.title.localizedCaseInsensitiveContains("Source - ")
                || MemoryCompiler.isRawLinkLike($0.title)
        }.map(\.id)
        for pageID in sourcePageIDs {
            try execute("DELETE FROM wiki_pages WHERE id = ?", [.text(pageID)])
            removed += 1
        }

        if removed > 0 {
            try appendAudit(AuditEventRecord(
                eventType: "memoryBoundary.domainRecordsRemoved",
                targetType: "memory",
                targetID: "domain-derived",
                detail: "Removed \(removed) domain/link-derived memory records. Raw source evidence was preserved."
            ))
        }
        return removed
    }

    public func saveWikiPage(_ page: WikiPageRecord) throws {
        try upsertJSON(table: "wiki_pages", id: page.id, sourceID: page.sourceRefs.first, status: nil, updatedAt: page.updatedAt, page)
    }

    public func deleteWikiPages(ids: Set<String>) throws {
        guard !ids.isEmpty else { return }
        for id in ids {
            try execute("DELETE FROM wiki_pages WHERE id = ?", [.text(id)])
        }
    }

    public func fetchWikiPages() throws -> [WikiPageRecord] {
        try fetchJSON(
            """
            SELECT json FROM wiki_pages
            ORDER BY CASE id
                WHEN 'overview' THEN 0
                WHEN 'index' THEN 1
                WHEN 'synthesis-main' THEN 2
                WHEN 'lint-report' THEN 98
                WHEN 'log' THEN 99
                ELSE 20
            END, updated_at DESC
            """,
            []
        )
    }

    public func pruneWikiPages(keeping ids: Set<String>) throws {
        guard !ids.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        try execute(
            "DELETE FROM wiki_pages WHERE id NOT IN (\(placeholders))",
            ids.sorted().map { .text($0) }
        )
    }

    public func saveFeedback(_ feedback: FeedbackRecord) throws {
        try upsertJSON(table: "feedback", id: feedback.id, sourceID: nil, status: feedback.action.rawValue, updatedAt: feedback.timestamp, feedback)
        try appendAudit(AuditEventRecord(
            eventType: "feedback.\(feedback.action.rawValue)",
            targetType: feedback.targetType,
            targetID: feedback.targetID,
            detail: feedback.note
        ))
    }

    public func fetchFeedback() throws -> [FeedbackRecord] {
        try fetchJSON("SELECT json FROM feedback ORDER BY updated_at DESC", [])
    }

    public func appendAudit(_ event: AuditEventRecord) throws {
        try upsertJSON(table: "audit_log", id: event.id, sourceID: event.sourceRefs.first, status: event.eventType, updatedAt: event.timestamp, event)
    }

    public func fetchAuditEvents() throws -> [AuditEventRecord] {
        try fetchJSON("SELECT json FROM audit_log ORDER BY updated_at DESC", [])
    }

    @discardableResult
    public func scrubLegacyPrivacyAuditDetails() throws -> Int {
        let events = try fetchAuditEvents().filter { event in
            event.eventType == "browserHistory.imported" && event.detail.contains("Snapshot:")
        }
        for var event in events {
            let prefix = event.detail.components(separatedBy: "Snapshot:").first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                ?? "Imported sanitized browser observations."
            event.detail = "\(prefix). Browser database snapshot was transient and deleted."
            try appendAudit(event)
        }
        return events.count
    }

    @discardableResult
    public func purgeExpiredRawSources(now: Date = Date()) throws -> Int {
        let expired: [SourceRecord] = try fetchJSON(
            """
            SELECT json FROM sources
            WHERE pinned = 0
              AND retention_expires_at <= ?
              AND deletion_state = ?
            """,
            [.double(now.timeIntervalSince1970), .text(DeletionState.active.rawValue)]
        )
        for var source in expired {
            source.deletionState = .rawExpired
            source.status = .deleted
            try saveSource(source)
            try appendAudit(AuditEventRecord(
                eventType: "source.rawExpired",
                targetType: "source",
                targetID: source.id,
                sourceRefs: [source.id],
                detail: "Raw input expired after retention window; minimal provenance capsules remain."
            ))
        }
        return expired.count
    }

    public func retractClaim(id: String, reason: String) throws {
        let records: [ClaimRecord] = try fetchJSON("SELECT json FROM claims WHERE id = ?", [.text(id)])
        guard var claim = records.first else {
            throw HiveStoreError.missingRecord("claim \(id)")
        }
        claim.status = .retracted
        claim.uncertaintyReason = reason
        try saveClaim(claim)
        try appendAudit(AuditEventRecord(eventType: "claim.retracted", targetType: "claim", targetID: id, sourceRefs: claim.sourceRefs, detail: reason))
    }

    public func deleteClaim(id: String) throws {
        try execute("DELETE FROM claims WHERE id = ?", [.text(id)])
        let relationships = try fetchRelationships().filter { $0.subjectID == id || $0.objectID == id }
        for relationship in relationships {
            try execute("DELETE FROM relationships WHERE id = ?", [.text(relationship.id)])
        }
    }

    public func fullForgetSource(id: String) throws {
        guard var source = try fetchSource(id: id) else {
            throw HiveStoreError.missingRecord("source \(id)")
        }
        let claims = try fetchClaims(includeRetracted: true).filter { $0.sourceRefs.contains(id) }
        let chunks = try fetchChunks(sourceID: id)
        let entities = try fetchEntities().filter { $0.sourceRefs.contains(id) }
        let forgottenReferenceIDs = Set(
            [id]
                + claims.map(\.id)
                + chunks.map(\.id)
                + entities.map(\.id)
        )

        let tombstoneHash = Hashing.sha256(data: Data("forgotten-source:\(id)".utf8))
        source.connector = "forgotten"
        source.uri = "forgotten://\(tombstoneHash.prefix(24))"
        source.title = "Forgotten source"
        source.mimeType = "application/octet-stream"
        source.sizeBytes = 0
        source.sha256 = String(tombstoneHash)
        source.pinned = false
        source.privacyLabel = .privateSource
        source.deletionState = .fullForgotten
        source.status = .deleted
        try saveSource(source)

        for var claim in claims {
            claim.statement = "[Forgotten claim]"
            claim.claimType = "forgotten"
            claim.subjectEntityID = nil
            claim.sourceRefs = []
            claim.sourceSpanRefs = []
            claim.confidence = 0
            claim.uncertaintyReason = "Source was fully forgotten; claim text was removed."
            claim.contradictionGroupID = nil
            claim.status = .retracted
            claim.createdBy = "local-forget"
            claim.correctionLineage = []
            try saveClaim(claim)
        }

        try execute("DELETE FROM raw_blobs WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM artifacts WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM chunks WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM chunk_fts WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM extraction_jobs WHERE source_id = ?", [.text(id)])
        for entity in entities {
            try execute("DELETE FROM entities WHERE id = ?", [.text(entity.id)])
        }
        let relationships = try fetchRelationships().filter {
            forgottenReferenceIDs.contains($0.subjectID)
                || forgottenReferenceIDs.contains($0.objectID)
                || $0.sourceSpanRefs.contains { forgottenReferenceIDs.contains($0) }
        }
        for relationship in relationships {
            try execute("DELETE FROM relationships WHERE id = ?", [.text(relationship.id)])
        }
        try deleteWikiPagesReferencing(forgottenReferenceIDs)
        try deleteFeedbackReferencing(forgottenReferenceIDs)
        try deleteAuditEventsReferencing(forgottenReferenceIDs)

        try appendAudit(AuditEventRecord(
            eventType: "source.fullForget",
            targetType: "source",
            targetID: id,
            sourceRefs: [],
            detail: "Content and derived artifacts removed. Non-reversible tombstone retained."
        ))
        try compactAfterPrivacyDeletion()
    }

    public func replaceDerivedContent(sourceID: String) throws {
        let claims = try fetchClaims(includeRetracted: true).filter { $0.sourceRefs.contains(sourceID) }
        for claim in claims {
            try execute("DELETE FROM claims WHERE id = ?", [.text(claim.id)])
        }
        let entities = try fetchEntities().filter { $0.sourceRefs.contains(sourceID) }
        for entity in entities {
            try execute("DELETE FROM entities WHERE id = ?", [.text(entity.id)])
        }
        let relationships = try fetchRelationships().filter {
            $0.subjectID == sourceID || $0.objectID == sourceID || $0.sourceSpanRefs.contains(sourceID)
        }
        for relationship in relationships {
            try execute("DELETE FROM relationships WHERE id = ?", [.text(relationship.id)])
        }
        try execute("DELETE FROM raw_blobs WHERE source_id = ?", [.text(sourceID)])
        try execute("DELETE FROM artifacts WHERE source_id = ?", [.text(sourceID)])
        try execute("DELETE FROM chunks WHERE source_id = ?", [.text(sourceID)])
        try execute("DELETE FROM chunk_fts WHERE source_id = ?", [.text(sourceID)])
        try execute("DELETE FROM extraction_jobs WHERE source_id = ?", [.text(sourceID)])
    }

    public func clearExtractionProductsKeepingRaw(sourceID: String) throws {
        let claims = try fetchClaims(includeRetracted: true).filter { $0.sourceRefs.contains(sourceID) }
        for claim in claims {
            try execute("DELETE FROM claims WHERE id = ?", [.text(claim.id)])
        }
        let entities = try fetchEntities().filter { $0.sourceRefs.contains(sourceID) }
        for entity in entities {
            try execute("DELETE FROM entities WHERE id = ?", [.text(entity.id)])
        }
        let relationships = try fetchRelationships().filter {
            $0.subjectID == sourceID
                || $0.objectID == sourceID
                || $0.sourceSpanRefs.contains(sourceID)
                || $0.sourceSpanRefs.contains { id in claims.contains { $0.id == id } }
        }
        for relationship in relationships {
            try execute("DELETE FROM relationships WHERE id = ?", [.text(relationship.id)])
        }
        try execute("DELETE FROM artifacts WHERE source_id = ?", [.text(sourceID)])
        try execute("DELETE FROM chunks WHERE source_id = ?", [.text(sourceID)])
        try execute("DELETE FROM chunk_fts WHERE source_id = ?", [.text(sourceID)])
        try execute("DELETE FROM extraction_jobs WHERE source_id = ?", [.text(sourceID)])
    }

    public func deleteStagedSource(id: String) throws {
        try execute("DELETE FROM raw_blobs WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM artifacts WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM chunks WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM chunk_fts WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM extraction_jobs WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM sources WHERE id = ?", [.text(id)])
        try execute("DELETE FROM audit_log WHERE source_id = ?", [.text(id)])
    }

    public func removeSourceAndFlagDerivedForReview(id: String) throws {
        guard var source = try fetchSource(id: id) else {
            throw HiveStoreError.missingRecord("source \(id)")
        }
        let claims = try fetchClaims(includeRetracted: true).filter { $0.sourceRefs.contains(id) }
        for var claim in claims {
            let remainingSources = claim.sourceRefs.filter { $0 != id }
            if remainingSources.isEmpty {
                claim.status = .suspect
                claim.uncertaintyReason = "Original Field source was removed; this claim needs review before it can be trusted."
                claim.confidence = min(claim.confidence, 0.42)
            }
            claim.sourceRefs = remainingSources
            try saveClaim(claim)
        }

        let affectedClaimIDs = Set(claims.map(\.id))
        let pages = try fetchWikiPages().filter { page in
            page.sourceRefs.contains(id) || page.claimRefs.contains { affectedClaimIDs.contains($0) }
        }
        for var page in pages {
            page.sourceRefs.removeAll { $0 == id }
            page.frontmatter["needs_review"] = "true"
            page.frontmatter["review_reason"] = "A source used by this article was removed."
            page.updatedAt = Date()
            page.revision += 1
            try saveWikiPage(page)
        }

        try execute("DELETE FROM raw_blobs WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM artifacts WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM chunks WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM chunk_fts WHERE source_id = ?", [.text(id)])
        try execute("DELETE FROM extraction_jobs WHERE source_id = ?", [.text(id)])

        source.status = .deleted
        source.deletionState = .rawDeleted
        source.title = "Removed source"
        source.uri = "removed://\(id)"
        source.sizeBytes = 0
        try saveSource(source)
        try appendAudit(AuditEventRecord(
            eventType: "source.removedForReview",
            targetType: "source",
            targetID: id,
            sourceRefs: [],
            detail: "Removed raw source and marked \(claims.count) derived claims for review."
        ))
    }

    private func upsertJSON<T: Encodable>(
        table: String,
        id: String,
        sourceID: String?,
        status: String?,
        updatedAt: Date,
        _ value: T
    ) throws {
        try execute(
            """
            INSERT INTO \(table)(id, source_id, status, updated_at, json)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                source_id=excluded.source_id,
                status=excluded.status,
                updated_at=excluded.updated_at,
                json=excluded.json
            """,
            [
                .text(id),
                sourceID.map(SQLiteValue.text) ?? .null,
                status.map(SQLiteValue.text) ?? .null,
                .double(updatedAt.timeIntervalSince1970),
                .text(try encode(value))
            ]
        )
    }

    private func upsertClaimDirect(_ claim: ClaimRecord) throws {
        try upsertJSON(
            table: "claims",
            id: claim.id,
            sourceID: claim.sourceRefs.sorted().first,
            status: claim.status.rawValue,
            updatedAt: claim.createdAt,
            claim
        )
    }

    private func shouldMergeClaim(_ claim: ClaimRecord) -> Bool {
        claim.status == .active && claim.claimType != "graph-insight"
    }

    private func mergedClaim(_ existing: ClaimRecord, with incoming: ClaimRecord) -> ClaimRecord {
        var merged = existing
        merged.sourceRefs = Array(Set(existing.sourceRefs + incoming.sourceRefs)).sorted()
        merged.sourceSpanRefs = Array(Set(existing.sourceSpanRefs + incoming.sourceSpanRefs)).sorted()
        merged.confidence = max(existing.confidence, incoming.confidence)
        if incoming.confidence > existing.confidence {
            merged.uncertaintyReason = incoming.uncertaintyReason
        }
        if (incoming.relevanceScore ?? -1) > (existing.relevanceScore ?? -1) {
            merged.relevanceTier = incoming.relevanceTier
            merged.relevanceScore = incoming.relevanceScore
            merged.relevanceReason = incoming.relevanceReason
            merged.temporalState = incoming.temporalState
            merged.canonicalTargetID = incoming.canonicalTargetID
        } else if existing.relevanceTier == nil {
            merged.relevanceTier = incoming.relevanceTier
            merged.relevanceScore = incoming.relevanceScore
            merged.relevanceReason = incoming.relevanceReason
            merged.temporalState = incoming.temporalState
            merged.canonicalTargetID = incoming.canonicalTargetID
        }
        merged.createdAt = min(existing.createdAt, incoming.createdAt)
        merged.correctionLineage = Array(Set(existing.correctionLineage + incoming.correctionLineage + [incoming.id]).subtracting([existing.id])).sorted()
        return merged
    }

    private func claimCanonicalKey(_ claim: ClaimRecord) -> String {
        "\(claim.claimType.lowercased())|\(normalizedClaimStatement(claim.statement))"
    }

    private func normalizedClaimStatement(_ statement: String) -> String {
        statement
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func upsertEntityDirect(_ entity: EntityRecord) throws {
        try upsertJSON(
            table: "entities",
            id: entity.id,
            sourceID: entity.sourceRefs.sorted().first,
            status: nil,
            updatedAt: entity.createdAt,
            entity
        )
    }

    private func mergedEntity(_ existing: EntityRecord, with incoming: EntityRecord) -> EntityRecord {
        var merged = existing
        merged.aliases = Array(Set(existing.aliases + incoming.aliases + [incoming.name]).subtracting([existing.name])).sorted()
        merged.sourceRefs = Array(Set(existing.sourceRefs + incoming.sourceRefs)).sorted()
        merged.confidence = max(existing.confidence, incoming.confidence)
        if (incoming.relevanceScore ?? -1) > (existing.relevanceScore ?? -1) {
            merged.relevanceTier = incoming.relevanceTier
            merged.relevanceScore = incoming.relevanceScore
            merged.relevanceReason = incoming.relevanceReason
            merged.temporalState = incoming.temporalState
            merged.canonicalTargetID = incoming.canonicalTargetID
        } else if existing.relevanceTier == nil {
            merged.relevanceTier = incoming.relevanceTier
            merged.relevanceScore = incoming.relevanceScore
            merged.relevanceReason = incoming.relevanceReason
            merged.temporalState = incoming.temporalState
            merged.canonicalTargetID = incoming.canonicalTargetID
        }
        merged.createdAt = min(existing.createdAt, incoming.createdAt)
        return merged
    }

    private func rewriteClaimEntityReferences(_ remappedIDs: [String: String]) throws {
        guard !remappedIDs.isEmpty else { return }
        let claims = try fetchClaims(includeRetracted: true)
        for var claim in claims {
            guard let oldID = claim.subjectEntityID, let newID = remappedIDs[oldID] else { continue }
            claim.subjectEntityID = newID
            try saveClaim(claim)
        }
    }

    private func entityCanonicalKey(_ entity: EntityRecord) -> String {
        "\(entity.entityType.lowercased())|\(normalizedEntityName(entity.name))"
    }

    private func normalizedEntityName(_ name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func deleteWikiPagesReferencing(_ ids: Set<String>) throws {
        let pages = try fetchWikiPages().filter { page in
            page.sourceRefs.contains { ids.contains($0) } || page.claimRefs.contains { ids.contains($0) }
        }
        for page in pages {
            try execute("DELETE FROM wiki_pages WHERE id = ?", [.text(page.id)])
        }
    }

    private func deleteFeedbackReferencing(_ ids: Set<String>) throws {
        let feedbackRecords = try fetchFeedback().filter { feedback in
            ids.contains(feedback.targetID) || feedback.resultingRevisionIDs.contains { ids.contains($0) }
        }
        for feedback in feedbackRecords {
            try execute("DELETE FROM feedback WHERE id = ?", [.text(feedback.id)])
        }
    }

    private func deleteAuditEventsReferencing(_ ids: Set<String>) throws {
        let events = try fetchAuditEvents().filter { event in
            ids.contains(event.targetID) || event.sourceRefs.contains { ids.contains($0) }
        }
        for event in events {
            try execute("DELETE FROM audit_log WHERE id = ?", [.text(event.id)])
        }
    }

    private func compactAfterPrivacyDeletion() throws {
        try execute("PRAGMA wal_checkpoint(TRUNCATE)")
        try execute("VACUUM")
        try execute("PRAGMA wal_checkpoint(TRUNCATE)")
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    private func decode<T: Decodable>(_ string: String, as type: T.Type = T.self) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw HiveStoreError.decodeFailed("Invalid UTF-8 JSON")
        }
        return try decoder.decode(T.self, from: data)
    }

    private func execute(_ sql: String, _ values: [SQLiteValue] = []) throws {
        lock.lock()
        defer { lock.unlock() }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HiveStoreError.prepareFailed(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind(values, to: statement)
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_DONE {
                break
            }
            if code == SQLITE_ROW {
                continue
            }
            throw HiveStoreError.stepFailed(lastErrorMessage)
        }
    }

    private func fetchJSON<T: Decodable>(_ sql: String, _ values: [SQLiteValue]) throws -> [T] {
        lock.lock()
        defer { lock.unlock() }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HiveStoreError.prepareFailed(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind(values, to: statement)
        var results: [T] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_ROW {
                guard let cString = sqlite3_column_text(statement, 0) else { continue }
                let json = String(cString: cString)
                results.append(try decode(json))
            } else if code == SQLITE_DONE {
                break
            } else {
                throw HiveStoreError.stepFailed(lastErrorMessage)
            }
        }
        return results
    }

    private func fetchTextColumn(_ sql: String, _ values: [SQLiteValue]) throws -> [String] {
        lock.lock()
        defer { lock.unlock() }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HiveStoreError.prepareFailed(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        try bind(values, to: statement)
        var results: [String] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_ROW {
                guard let cString = sqlite3_column_text(statement, 0) else { continue }
                results.append(String(cString: cString))
            } else if code == SQLITE_DONE {
                break
            } else {
                throw HiveStoreError.stepFailed(lastErrorMessage)
            }
        }
        return results
    }

    private func bind(_ values: [SQLiteValue], to statement: OpaquePointer?) throws {
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            let code: Int32
            switch value {
            case .text(let string):
                code = sqlite3_bind_text(statement, position, string, -1, sqliteTransient)
            case .int(let integer):
                code = sqlite3_bind_int64(statement, position, integer)
            case .double(let double):
                code = sqlite3_bind_double(statement, position, double)
            case .null:
                code = sqlite3_bind_null(statement, position)
            }
            guard code == SQLITE_OK else {
                throw HiveStoreError.bindFailed(lastErrorMessage)
            }
        }
    }

    private var lastErrorMessage: String {
        if let db, let message = sqlite3_errmsg(db) {
            return String(cString: message)
        }
        return "Unknown SQLite error"
    }
}

public struct HivePaths: Sendable {
    public var root: URL
    public var database: URL
    public var swiftDataStore: URL
    public var rawStore: URL
    public var artifacts: URL
    public var snapshots: URL
    public var models: URL
    public var vault: URL
    public var vaultRawSources: URL
    public var vaultRawAssets: URL
    public var vaultWiki: URL
    public var agentsFile: URL

    public init(root: URL) {
        self.root = root
        self.database = root.appendingPathComponent("Hive.sqlite")
        self.swiftDataStore = root.appendingPathComponent("Hive.store")
        self.rawStore = root.appendingPathComponent("Raw")
        self.artifacts = root.appendingPathComponent("Artifacts")
        self.snapshots = root.appendingPathComponent("Snapshots")
        self.models = root.appendingPathComponent("Models")
        self.vault = root.appendingPathComponent("Vault", isDirectory: true)
        self.vaultRawSources = vault.appendingPathComponent("flower-field", isDirectory: true)
        self.vaultRawAssets = vaultRawSources.appendingPathComponent("assets", isDirectory: true)
        self.vaultWiki = vault.appendingPathComponent("Colony", isDirectory: true)
        self.agentsFile = vault.appendingPathComponent("AGENTS.md")
    }

    public static func applicationSupport() throws -> HivePaths {
        if let iCloudRoot = HiveCloudSyncLocator.preferredRootURL() {
            return HivePaths(root: iCloudRoot)
        }
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return HivePaths(root: base.appendingPathComponent("Hive", isDirectory: true))
    }

    public func createDirectories() throws {
        for url in [root, rawStore, artifacts, snapshots, models, vault] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try WikiVaultManager(paths: self).ensureVault()
    }
}
