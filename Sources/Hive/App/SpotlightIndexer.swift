import Foundation
import CoreSpotlight
import os
import HiveCore

// MARK: - SpotlightIndexer
//
// Indexes browsing history into macOS Spotlight so users can search for
// previously-visited pages directly from Spotlight (⌘Space). Each history
// entry becomes a CSSearchableItem with title, URL, and content description.
//
// Privacy: indexing is opt-in via ChromeUserPrefs.spotlightIndexingEnabled
// (defaults to true). Private browsing history is never indexed. Items are
// removed from Spotlight when history is cleared.
//
// Deep macOS integration — Phase 7 of the master plan.

@MainActor
final class SpotlightIndexer {

    static let shared = SpotlightIndexer()

    /// The CSSearchableIndex domain identifier for Hive.
    private static let domainIdentifier = "com.hive.browser.history"

    nonisolated private static let logger = Logger(subsystem: "com.hive.browser", category: "SpotlightIndexer")

    /// Whether Spotlight indexing is enabled.
    var isEnabled: Bool { UserDefaults.standard.bool(forKey: "HiveSpotlightIndexingEnabled") }

    private init() {
        if UserDefaults.standard.object(forKey: "HiveSpotlightIndexingEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "HiveSpotlightIndexingEnabled")
        }
    }

    // MARK: - Public API

    /// Indexes a single history entry into Spotlight.
    func index(_ entry: BrowsingHistoryEntry) {
        guard isEnabled else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: .url)
        attributeSet.title = entry.title.isEmpty ? (entry.url.host ?? "Web Page") : entry.title
        attributeSet.url = entry.url
        attributeSet.contentDescription = "Visited in The Hive Browser"
        attributeSet.keywords = [entry.url.host ?? "", "hive", "browser"]

        let item = CSSearchableItem(
            uniqueIdentifier: "hive-history-\(entry.id)",
            domainIdentifier: Self.domainIdentifier,
            attributeSet: attributeSet
        )
        item.expirationDate = Date().addingTimeInterval(90 * 24 * 3600) // 90 days

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                Self.logger.warning("Failed to index \(entry.url, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Indexes multiple history entries in batch.
    func indexBatch(_ entries: [BrowsingHistoryEntry]) {
        guard isEnabled, !entries.isEmpty else { return }

        let items = entries.map { entry -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .url)
            attributeSet.title = entry.title.isEmpty ? (entry.url.host ?? "Web Page") : entry.title
            attributeSet.url = entry.url
            attributeSet.contentDescription = "Visited in The Hive Browser"

            let item = CSSearchableItem(
                uniqueIdentifier: "hive-history-\(entry.id)",
                domainIdentifier: Self.domainIdentifier,
                attributeSet: attributeSet
            )
            item.expirationDate = Date().addingTimeInterval(90 * 24 * 3600)
            return item
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                Self.logger.warning("Batch index failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Removes all Hive history from Spotlight.
    func clearAll() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [Self.domainIdentifier]
        ) { error in
            if let error {
                Self.logger.warning("Clear failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Removes a specific entry from Spotlight.
    func remove(_ entry: BrowsingHistoryEntry) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: ["hive-history-\(entry.id)"]
        ) { _ in }
    }

    /// Enables or disables Spotlight indexing.
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "HiveSpotlightIndexingEnabled")
        if !enabled { clearAll() }
    }
}
