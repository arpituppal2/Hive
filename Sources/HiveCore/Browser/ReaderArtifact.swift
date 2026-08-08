import Foundation

// MARK: - ReaderArtifact
//
// A lightweight, Codable/Sendable record of an article extracted for Reader Mode.
// Stored per-tab by `ChromeState` and rendered by the Hive app's `ReaderModeView`.

public struct ReaderArtifact: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let url: URL?
    public let title: String
    public let byline: String
    public let contentHTML: String
    public let excerpt: String
    public let createdAt: Date

    public init(id: String = UUID().uuidString,
                url: URL?,
                title: String,
                byline: String = "",
                contentHTML: String,
                excerpt: String = "",
                createdAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.byline = byline
        self.contentHTML = contentHTML
        self.excerpt = excerpt
        self.createdAt = createdAt
    }
}
