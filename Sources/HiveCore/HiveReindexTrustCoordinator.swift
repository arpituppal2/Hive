import Foundation

public struct TopicDominanceWarning: Codable, Hashable, Sendable {
    public var topic: String
    public var claimCount: Int
    public var totalClaims: Int
    public var ratio: Double

    public init(topic: String, claimCount: Int, totalClaims: Int, ratio: Double) {
        self.topic = topic
        self.claimCount = claimCount
        self.totalClaims = totalClaims
        self.ratio = ratio
    }
}

public struct HiveReindexTrustReport: Codable, Hashable, Sendable {
    public var filesProcessed: Int
    public var claimsExtracted: Int
    public var duplicatesCollapsed: Int
    public var staleSourcesMarked: Int
    public var changedSourcesQueued: Int
    public var ignoredConcurrentRequest: Bool
    public var topicDominance: TopicDominanceWarning?

    public init(
        filesProcessed: Int = 0,
        claimsExtracted: Int = 0,
        duplicatesCollapsed: Int = 0,
        staleSourcesMarked: Int = 0,
        changedSourcesQueued: Int = 0,
        ignoredConcurrentRequest: Bool = false,
        topicDominance: TopicDominanceWarning? = nil
    ) {
        self.filesProcessed = filesProcessed
        self.claimsExtracted = claimsExtracted
        self.duplicatesCollapsed = duplicatesCollapsed
        self.staleSourcesMarked = staleSourcesMarked
        self.changedSourcesQueued = changedSourcesQueued
        self.ignoredConcurrentRequest = ignoredConcurrentRequest
        self.topicDominance = topicDominance
    }
}

public final class HiveReindexTrustCoordinator: @unchecked Sendable {
    private let store: HiveStore
    private let ingestion: IngestionCoordinator
    private let knowledgeLoop: KnowledgeLoop
    private let paths: HivePaths
    private let fileManager: FileManager

    public init(
        store: HiveStore,
        ingestion: IngestionCoordinator,
        knowledgeLoop: KnowledgeLoop,
        paths: HivePaths,
        fileManager: FileManager = .default
    ) {
        self.store = store
        self.ingestion = ingestion
        self.knowledgeLoop = knowledgeLoop
        self.paths = paths
        self.fileManager = fileManager
    }

    public func run() throws -> HiveReindexTrustReport {
        try paths.createDirectories()
        var report = HiveReindexTrustReport()
        try store.inTransaction {
            let audit = try auditAndQueueSourcesForReindex()
            report.staleSourcesMarked = audit.staleMarked
            report.changedSourcesQueued = audit.changedQueued
        }

        // Process queued work outside the transaction; extraction is long-running.
        try ingestion.processPending(limit: 1_000)

        try store.inTransaction {
            report.duplicatesCollapsed = try deduplicateClaims()
            report.filesProcessed = try store.fetchSources().count
            report.claimsExtracted = try store.fetchClaims().count
            _ = try knowledgeLoop.updateDerivedKnowledge()
            report.topicDominance = try computeTopicDominanceWarning()
            try appendReindexLog(report: report)
        }
        return report
    }

    private func appendReindexLog(report: HiveReindexTrustReport) throws {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let stamp = formatter.string(from: Date())
        let line = "## [\(stamp)] reindex | \(report.filesProcessed) files processed, \(report.claimsExtracted) claims extracted, \(report.duplicatesCollapsed) duplicates collapsed, \(report.staleSourcesMarked) stale nodes removed\n"
        let logURL = paths.vaultWiki.appendingPathComponent("log.md")
        if fileManager.fileExists(atPath: logURL.path) {
            let existing = (try? String(contentsOf: logURL)) ?? ""
            try (existing + "\n" + line).write(to: logURL, atomically: true, encoding: .utf8)
        } else {
            try line.write(to: logURL, atomically: true, encoding: .utf8)
        }
        try store.appendAudit(AuditEventRecord(
            eventType: "reindex.trustCoordinator",
            targetType: "reindex",
            targetID: "trusted",
            detail: line.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
    }

    private func auditAndQueueSourcesForReindex() throws -> (staleMarked: Int, changedQueued: Int) {
        let sources = try store.fetchSources()
        var staleMarked = 0
        var changedQueued = 0
        for var source in sources where source.deletionState == .active {
            guard source.uri.hasPrefix("/") else { continue }
            let sourceURL = URL(fileURLWithPath: source.uri)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
                source.deletionState = .derivedRetracted
                source.status = .failed
                source.observedAt = Date()
                try store.saveSource(source)
                staleMarked += 1
                continue
            }
            guard !isDirectory.boolValue else { continue }
            let data = try Data(contentsOf: sourceURL)
            let currentSHA = Hashing.sha256(data: data)
            if currentSHA != source.sha256 {
                try store.clearExtractionProductsKeepingRaw(sourceID: source.id)
                source.sha256 = currentSHA
                source.sizeBytes = Int64(data.count)
                source.status = .queued
                source.observedAt = Date()
                try store.saveSource(source)
                try store.saveJob(ExtractionJobRecord(sourceID: source.id, stage: .extractText))
                changedQueued += 1
            }
        }
        return (staleMarked, changedQueued)
    }

    private func deduplicateClaims() throws -> Int {
        let claims = try store.fetchClaims(includeRetracted: false)
        var canonicalByStatement: [String: ClaimRecord] = [:]
        var duplicateCount = 0
        for claim in claims.sorted(by: { $0.createdAt < $1.createdAt }) {
            let key = Self.normalizedClaimKey(claim.statement)
            guard !key.isEmpty else { continue }
            if var canonical = canonicalByStatement[key] {
                canonical.sourceRefs = Array(Set(canonical.sourceRefs + claim.sourceRefs)).sorted()
                canonical.confidence = max(canonical.confidence, claim.confidence)
                canonical.correctionLineage = Array(Set(canonical.correctionLineage + claim.correctionLineage)).sorted()
                try store.saveClaim(canonical)
                try store.deleteClaim(id: claim.id)
                duplicateCount += 1
            } else {
                canonicalByStatement[key] = claim
            }
        }
        return duplicateCount
    }

    private func computeTopicDominanceWarning() throws -> TopicDominanceWarning? {
        let claims = try store.fetchClaims(includeRetracted: false)
        return Self.topicDominanceWarning(for: claims)
    }

    public static func normalizedClaimKey(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public static func primaryTopic(from statement: String) -> String {
        let terms = normalizedClaimKey(statement)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 4 }
        return terms.first ?? ""
    }

    public static func topicDominanceWarning(
        for claims: [ClaimRecord],
        threshold: Double = 0.15
    ) -> TopicDominanceWarning? {
        guard !claims.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for claim in claims {
            let topic = primaryTopic(from: claim.statement)
            guard !topic.isEmpty else { continue }
            counts[topic, default: 0] += 1
        }
        guard let best = counts.max(by: { $0.value < $1.value }) else { return nil }
        let ratio = Double(best.value) / Double(claims.count)
        guard ratio >= threshold else { return nil }
        return TopicDominanceWarning(
            topic: best.key,
            claimCount: best.value,
            totalClaims: claims.count,
            ratio: ratio
        )
    }
}
