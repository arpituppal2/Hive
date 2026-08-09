import CloudKit
import Foundation

// MARK: - CloudKit Sync Engine (v1.0 foundation)
//
// Cross-device sync for tabs, bookmarks, and history via CloudKit private database.
// Last-write-wins conflict resolution with client-side timestamps.
//
// Usage:
//   let engine = CloudKitSyncEngine()
//   engine.setupSubscription()
//   engine.saveTab(tab)  // auto-syncs to other devices
//   engine.fetchTabs { tabs in ... }

public actor CloudKitSyncEngine {
    public enum RecordType: String, Sendable {
        case tab = "BrowserTab"
        case bookmark = "Bookmark"
        case historyItem = "HistoryItem"
    }

    private let container: CKContainer
    private let database: CKDatabase
    private var isSubscribed = false

    public init(containerIdentifier: String? = nil) {
        if let id = containerIdentifier {
            self.container = CKContainer(identifier: id)
        } else {
            self.container = CKContainer.default()
        }
        self.database = container.privateCloudDatabase
    }

    // MARK: - Subscription

    public func setupSubscription() async throws {
        guard !isSubscribed else { return }
        let subscriptionID = "hive-private-db-changes"
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        _ = try await database.save(subscription)
        isSubscribed = true
    }

    // MARK: - Tab sync

    public func saveTab(id: String, url: String, title: String, updatedAt: Date = Date()) async throws {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: RecordType.tab.rawValue, recordID: recordID)
        record["url"] = url as CKRecordValue
        record["title"] = title as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        _ = try await database.save(record)
    }

    public func fetchTabs(since: Date? = nil) async throws -> [CKRecord] {
        let query = CKQuery(recordType: RecordType.tab.rawValue, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        let (results, _) = try await database.records(matching: query, resultsLimit: 500)
        return results.compactMap { try? $0.1.get() }
    }

    public func deleteTab(id: String) async throws {
        let recordID = CKRecord.ID(recordName: id)
        try await database.deleteRecord(withID: recordID)
    }

    // MARK: - Bookmark sync

    public func saveBookmark(id: String, url: String, title: String, updatedAt: Date = Date()) async throws {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: RecordType.bookmark.rawValue, recordID: recordID)
        record["url"] = url as CKRecordValue
        record["title"] = title as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        _ = try await database.save(record)
    }

    public func fetchBookmarks() async throws -> [CKRecord] {
        let query = CKQuery(recordType: RecordType.bookmark.rawValue, predicate: NSPredicate(value: true))
        let (results, _) = try await database.records(matching: query, resultsLimit: 1000)
        return results.compactMap { try? $0.1.get() }
    }

    // MARK: - History sync

    public func saveHistoryItem(id: String, url: String, title: String, visitedAt: Date) async throws {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: RecordType.historyItem.rawValue, recordID: recordID)
        record["url"] = url as CKRecordValue
        record["title"] = title as CKRecordValue
        record["visitedAt"] = visitedAt as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.save(record)
    }

    public func fetchHistory(since: Date? = nil) async throws -> [CKRecord] {
        let predicate: NSPredicate
        if let since = since {
            predicate = NSPredicate(format: "visitedAt >= %@", since as NSDate)
        } else {
            predicate = NSPredicate(value: true)
        }
        let query = CKQuery(recordType: RecordType.historyItem.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "visitedAt", ascending: false)]
        let (results, _) = try await database.records(matching: query, resultsLimit: 500)
        return results.compactMap { try? $0.1.get() }
    }

    // MARK: - Conflict resolution (Last-Write-Wins)

    public func saveWithConflictResolution(_ record: CKRecord, localUpdatedAt: Date) async throws -> CKRecord {
        do {
            return try await database.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            guard let serverRecord = error.serverRecord else { throw error }
            let serverTimestamp = (serverRecord["updatedAt"] as? Date) ?? .distantPast
            if localUpdatedAt > serverTimestamp {
                serverRecord["url"] = record["url"]
                serverRecord["title"] = record["title"]
                serverRecord["updatedAt"] = localUpdatedAt as CKRecordValue
                return try await database.save(serverRecord)
            } else {
                return serverRecord
            }
        }
    }

    // MARK: - Account status

    public func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
}
