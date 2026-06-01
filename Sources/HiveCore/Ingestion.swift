import Foundation

public enum IngestionError: Error, LocalizedError, Sendable {
    case notAFile(URL)
    case copyFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .notAFile(let url): "Not a file: \(url.path)"
        case .copyFailed(let url): "Could not copy raw input: \(url.path)"
        }
    }
}

public final class IngestionCoordinator: @unchecked Sendable {
    private let paths: HivePaths
    private let store: HiveStore
    private let extractor: LocalExtractor
    private let chunker: TextChunker
    private let knowledgeExtractor: DeterministicKnowledgeExtractor
    private let fileManager: FileManager
    private let learningSettingsProvider: @Sendable () -> HiveLearningSettings

    public init(
        paths: HivePaths,
        store: HiveStore,
        extractor: LocalExtractor = LocalExtractor(),
        chunker: TextChunker = TextChunker(),
        knowledgeExtractor: DeterministicKnowledgeExtractor = DeterministicKnowledgeExtractor(),
        fileManager: FileManager = .default,
        learningSettingsProvider: @escaping @Sendable () -> HiveLearningSettings = { HiveLearningSettingsStore.load() }
    ) {
        self.paths = paths
        self.store = store
        self.extractor = extractor
        self.chunker = chunker
        self.knowledgeExtractor = knowledgeExtractor
        self.fileManager = fileManager
        self.learningSettingsProvider = learningSettingsProvider
    }

    @discardableResult
    public func ingest(
        urls: [URL],
        privacyLabel: PrivacyLabel = .normal,
        processImmediately: Bool = true
    ) throws -> [SourceRecord] {
        try paths.createDirectories()
        var imported: [SourceRecord] = []
        for url in urls {
            if directoryExists(url) {
                imported.append(contentsOf: try ingestDirectory(url, privacyLabel: privacyLabel, processImmediately: processImmediately))
            } else {
                imported.append(try ingestFile(url, privacyLabel: privacyLabel, processImmediately: processImmediately))
            }
        }
        return imported
    }

    @discardableResult
    public func ingestFile(
        _ url: URL,
        privacyLabel: PrivacyLabel = .normal,
        processImmediately: Bool = true
    ) throws -> SourceRecord {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw IngestionError.notAFile(url)
        }

        let data = try Data(contentsOf: url)
        let sha = Hashing.sha256(data: data)
        let ext = url.pathExtension.isEmpty ? "raw" : url.pathExtension
        let contentAddress = "\(sha).\(ext)"
        let rawURL = paths.rawStore.appendingPathComponent(contentAddress)
        if !fileManager.fileExists(atPath: rawURL.path) {
            do {
                try data.write(to: rawURL, options: [.atomic])
            } catch {
                throw IngestionError.copyFailed(url)
            }
        }

        let now = Date()
        let retention = learningSettingsProvider().rawSourceRetention
        let source = SourceRecord(
            kind: SourceTypeDetector.kind(for: url),
            uri: url.path,
            title: url.lastPathComponent,
            mimeType: SourceTypeDetector.mimeType(for: url),
            sizeBytes: Int64(data.count),
            sha256: sha,
            importedAt: now,
            observedAt: now,
            retentionExpiresAt: retention.expirationDate(from: now),
            privacyLabel: privacyLabel,
            status: .queued
        )
        try store.saveSource(source)
        try store.saveRawBlob(RawBlobRecord(
            sourceID: source.id,
            contentAddress: contentAddress,
            localPath: rawURL.path,
            mimeType: source.mimeType,
            sizeBytes: source.sizeBytes,
            sha256: sha
        ))
        _ = try WikiVaultManager(paths: paths, fileManager: fileManager).mirrorRawSource(source, rawURL: rawURL)
        try store.saveJob(ExtractionJobRecord(sourceID: source.id, stage: .extractText))
        try store.appendAudit(AuditEventRecord(eventType: "source.ingested", targetType: "source", targetID: source.id, sourceRefs: [source.id], detail: source.title))
        if processImmediately {
            try processSource(source, rawURL: rawURL)
        }
        return source
    }

    public func processPending(limit: Int = 25) throws {
        let jobs = try store.fetchJobs(status: .queued).prefix(limit)
        for job in jobs {
            guard let source = try store.fetchSource(id: job.sourceID),
                  source.deletionState == .active,
                  source.status == .queued,
                  let raw = try store.fetchRawBlobs(sourceID: source.id).first else {
                continue
            }
            try processSource(source, rawURL: URL(fileURLWithPath: raw.localPath), existingJob: job)
        }
    }

    public func process(sourceID: String) throws {
        guard let source = try store.fetchSource(id: sourceID),
              source.deletionState == .active,
              source.status == .queued || source.status == .failed,
              let raw = try store.fetchRawBlobs(sourceID: sourceID).first else {
            return
        }
        let job = try store.fetchJobs(status: .queued).first { $0.sourceID == sourceID }
            ?? ExtractionJobRecord(sourceID: sourceID, stage: .extractText)
        try processSource(source, rawURL: URL(fileURLWithPath: raw.localPath), existingJob: job)
    }

    public func reprocess(sourceID: String, depth: SourceExtractionDepth = .normal) throws {
        guard var source = try store.fetchSource(id: sourceID),
              source.deletionState == .active,
              let raw = try store.fetchRawBlobs(sourceID: sourceID).first else {
            return
        }
        try store.clearExtractionProductsKeepingRaw(sourceID: sourceID)
        source.status = .queued
        source.observedAt = Date()
        try store.saveSource(source)
        try store.saveJob(ExtractionJobRecord(sourceID: sourceID, stage: .extractText))
        try processSource(source, rawURL: URL(fileURLWithPath: raw.localPath), depth: depth)
    }

    private func ingestDirectory(_ url: URL, privacyLabel: PrivacyLabel, processImmediately: Bool) throws -> [SourceRecord] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys) else {
            return []
        }
        var records: [SourceRecord] = []
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                records.append(try ingestFile(fileURL, privacyLabel: privacyLabel, processImmediately: processImmediately))
            }
        }
        return records
    }

    private func processSource(
        _ source: SourceRecord,
        rawURL: URL,
        existingJob: ExtractionJobRecord? = nil,
        depth: SourceExtractionDepth = .normal
    ) throws {
        guard let current = try store.fetchSource(id: source.id),
              current.deletionState == .active,
              current.status != .deleted else {
            return
        }
        let source = current
        var job = existingJob ?? ExtractionJobRecord(sourceID: source.id, stage: .extractText)
        job.status = .running
        job.attempts += 1
        job.updatedAt = Date()
        try store.saveJob(job)
        try store.markSourceStatus(id: source.id, status: .extracting)

        do {
            let extracted = try extractor.extract(from: rawURL, kind: source.kind)
            let artifact = ArtifactRecord(
                sourceID: source.id,
                artifactType: extracted.artifactType,
                inlineText: extracted.text,
                modelID: extracted.requiresModel
                    ? "deterministic-local:metadata:\(depth.rawValue)"
                    : "deterministic-local:\(depth.rawValue)"
            )
            try store.saveArtifact(artifact)

            let activeChunker = depth == .normal ? chunker : depth.chunker
            let chunks = activeChunker.chunks(for: extracted.text).enumerated().map { index, text in
                ChunkRecord(
                    sourceID: source.id,
                    artifactID: artifact.id,
                    text: text,
                    locationLabel: "chunk \(index + 1)",
                    extractionConfidence: extracted.confidence
                )
            }
            for chunk in chunks {
                try store.saveChunk(chunk)
            }

            let claims = knowledgeExtractor.claims(from: chunks, source: source, depth: depth)
            for claim in claims {
                try store.saveClaim(claim)
            }

            let entities = knowledgeExtractor.entities(from: chunks, source: source, depth: depth)
            for entity in entities {
                try store.saveEntity(entity)
            }

            job.status = .succeeded
            job.updatedAt = Date()
            try store.saveJob(job)
            try store.markSourceStatus(id: source.id, status: extracted.requiresModel ? .needsReview : .extracted)
            try store.appendAudit(AuditEventRecord(
                eventType: "source.extracted",
                targetType: "source",
                targetID: source.id,
                modelID: artifact.modelID,
                sourceRefs: [source.id],
                detail: depth == .expanded
                    ? "\(extracted.note) Expanded extraction scanned more chunks and promoted only grounded high-signal claims."
                    : extracted.note
            ))
        } catch {
            job.status = job.attempts >= 3 ? .failed : .retrying
            job.errorCategory = String(describing: error)
            job.nextRetryAt = Calendar.current.date(byAdding: .minute, value: min(60, job.attempts * 5), to: Date())
            job.updatedAt = Date()
            try store.saveJob(job)
            try store.markSourceStatus(id: source.id, status: .failed)
            try store.appendAudit(AuditEventRecord(
                eventType: "source.extractionFailed",
                targetType: "source",
                targetID: source.id,
                sourceRefs: [source.id],
                detail: String(describing: error)
            ))
        }
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
