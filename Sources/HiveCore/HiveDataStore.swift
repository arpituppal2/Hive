import Foundation
import SwiftData

public struct HiveDataMigrationSummary: Hashable, Sendable {
    public var sourceCount: Int
    public var rawBlobCount: Int
    public var jobCount: Int
    public var chunkCount: Int
    public var claimCount: Int
    public var entityCount: Int
    public var connectionCount: Int
    public var wikiArticleCount: Int
    public var feedbackCount: Int
    public var auditEventCount: Int
    public var graphLayoutCount: Int

    public init(
        sourceCount: Int = 0,
        rawBlobCount: Int = 0,
        jobCount: Int = 0,
        chunkCount: Int = 0,
        claimCount: Int = 0,
        entityCount: Int = 0,
        connectionCount: Int = 0,
        wikiArticleCount: Int = 0,
        feedbackCount: Int = 0,
        auditEventCount: Int = 0,
        graphLayoutCount: Int = 0
    ) {
        self.sourceCount = sourceCount
        self.rawBlobCount = rawBlobCount
        self.jobCount = jobCount
        self.chunkCount = chunkCount
        self.claimCount = claimCount
        self.entityCount = entityCount
        self.connectionCount = connectionCount
        self.wikiArticleCount = wikiArticleCount
        self.feedbackCount = feedbackCount
        self.auditEventCount = auditEventCount
        self.graphLayoutCount = graphLayoutCount
    }

    public var totalRecords: Int {
        sourceCount
            + rawBlobCount
            + jobCount
            + chunkCount
            + claimCount
            + entityCount
            + connectionCount
            + wikiArticleCount
            + feedbackCount
            + auditEventCount
            + graphLayoutCount
    }
}

public protocol HiveDataStoreProtocol: Sendable {
    func fetchSources() throws -> [SourceRecord]
    func fetchClaims(includeRetracted: Bool) throws -> [ClaimRecord]
    func fetchEntities() throws -> [EntityRecord]
    func fetchRelationships() throws -> [RelationshipRecord]
    func fetchWikiPages() throws -> [WikiPageRecord]
}

public final class SQLiteHiveDataStore: HiveDataStoreProtocol, @unchecked Sendable {
    private let store: HiveStore

    public init(store: HiveStore) {
        self.store = store
    }

    public func fetchSources() throws -> [SourceRecord] {
        try store.fetchSources()
    }

    public func fetchClaims(includeRetracted: Bool = false) throws -> [ClaimRecord] {
        try store.fetchClaims(includeRetracted: includeRetracted)
    }

    public func fetchEntities() throws -> [EntityRecord] {
        try store.fetchEntities()
    }

    public func fetchRelationships() throws -> [RelationshipRecord] {
        try store.fetchRelationships()
    }

    public func fetchWikiPages() throws -> [WikiPageRecord] {
        try store.fetchWikiPages()
    }
}

@MainActor
public final class SwiftDataHiveDataStore {
    public let container: ModelContainer
    public let context: ModelContext

    public init(storeURL: URL) throws {
        let schema = Schema([
            RawSource.self,
            WikiNode.self,
            Connection.self,
            HiveRawSourceModel.self,
            HiveRawBlobModel.self,
            HiveExtractionJobModel.self,
            HiveChunkModel.self,
            HiveClaimModel.self,
            HiveEntityModel.self,
            HiveConnectionModel.self,
            HiveWikiArticleModel.self,
            HiveFeedbackModel.self,
            HiveAuditEventModel.self,
            HiveGraphLayoutModel.self,
            HiveInferenceJobModel.self
        ])
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    public func migrateOnce(from sqliteStore: HiveStore, graph: HiveGraphSnapshot? = nil) throws -> HiveDataMigrationSummary {
        if try !fetchSources().isEmpty {
            return HiveDataMigrationSummary(sourceCount: try fetchSources().count)
        }

        let sources = try sqliteStore.fetchSources(includeForgotten: true)
        let rawBlobs = try sources.flatMap { try sqliteStore.fetchRawBlobs(sourceID: $0.id) }
        let jobs = try sqliteStore.fetchJobs()
        let chunks = try sqliteStore.fetchChunks()
        let claims = try sqliteStore.fetchClaims(includeRetracted: true)
        let entities = try sqliteStore.fetchEntities()
        let relationships = try sqliteStore.fetchRelationships()
        let wikiPages = try sqliteStore.fetchWikiPages()
        let feedback = try sqliteStore.fetchFeedback()
        let auditEvents = try sqliteStore.fetchAuditEvents()
        let graphLayouts = (graph?.nodes ?? []).map {
            HiveGraphLayoutModel(nodeID: $0.id, x: $0.x, y: $0.y, clusterID: $0.semanticColorKey, updatedAt: $0.timestamp ?? Date())
        }

        sources.map(HiveRawSourceModel.init(record:)).forEach(context.insert)
        rawBlobs.map(HiveRawBlobModel.init(record:)).forEach(context.insert)
        jobs.map(HiveExtractionJobModel.init(record:)).forEach(context.insert)
        chunks.map(HiveChunkModel.init(record:)).forEach(context.insert)
        claims.map(HiveClaimModel.init(record:)).forEach(context.insert)
        entities.map(HiveEntityModel.init(record:)).forEach(context.insert)
        relationships.map(HiveConnectionModel.init(record:)).forEach(context.insert)
        wikiPages.map(HiveWikiArticleModel.init(record:)).forEach(context.insert)
        feedback.map(HiveFeedbackModel.init(record:)).forEach(context.insert)
        auditEvents.map(HiveAuditEventModel.init(record:)).forEach(context.insert)
        graphLayouts.forEach(context.insert)
        try context.save()

        return HiveDataMigrationSummary(
            sourceCount: sources.count,
            rawBlobCount: rawBlobs.count,
            jobCount: jobs.count,
            chunkCount: chunks.count,
            claimCount: claims.count,
            entityCount: entities.count,
            connectionCount: relationships.count,
            wikiArticleCount: wikiPages.count,
            feedbackCount: feedback.count,
            auditEventCount: auditEvents.count,
            graphLayoutCount: graphLayouts.count
        )
    }

    public func fetchSources() throws -> [SourceRecord] {
        try context.fetch(FetchDescriptor<HiveRawSourceModel>()).map { $0.record() }
    }

    public func fetchClaims(includeRetracted: Bool = false) throws -> [ClaimRecord] {
        let claims = try context.fetch(FetchDescriptor<HiveClaimModel>()).map { $0.record() }
        return includeRetracted ? claims : claims.filter { $0.status != .retracted }
    }

    public func fetchEntities() throws -> [EntityRecord] {
        try context.fetch(FetchDescriptor<HiveEntityModel>()).map { $0.record() }
    }

    public func fetchRelationships() throws -> [RelationshipRecord] {
        try context.fetch(FetchDescriptor<HiveConnectionModel>()).map { $0.record() }
    }

    public func fetchWikiPages() throws -> [WikiPageRecord] {
        try context.fetch(FetchDescriptor<HiveWikiArticleModel>()).map { $0.record() }
    }

    public func fetchGraphLayouts() throws -> [HiveGraphLayoutModel] {
        try context.fetch(FetchDescriptor<HiveGraphLayoutModel>())
    }

    public func fetchNativeRawSources() throws -> [RawSource] {
        try context.fetch(FetchDescriptor<RawSource>())
    }

    public func fetchNativeWikiNodes() throws -> [WikiNode] {
        try context.fetch(FetchDescriptor<WikiNode>())
    }

    public func fetchNativeConnections() throws -> [Connection] {
        try context.fetch(FetchDescriptor<Connection>())
    }
}
