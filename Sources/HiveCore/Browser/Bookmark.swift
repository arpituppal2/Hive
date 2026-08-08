import Foundation

// MARK: - Bookmark
//
// A single bookmark record. Persisted in ChromeUserPrefs alongside history and prefs.
// Supports folders (via parentID) for nested bookmark organization. A nil parentID
// means the bookmark is a root-level item. Folders have `url == nil` and `isFolder == true`.

public struct Bookmark: Sendable, Codable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var url: URL?
    public var isFolder: Bool
    public var parentID: String?
    public var createdAt: Date
    public var faviconURL: URL?

    public init(id: String = UUID().uuidString,
                title: String,
                url: URL? = nil,
                isFolder: Bool = false,
                parentID: String? = nil,
                createdAt: Date = Date(),
                faviconURL: URL? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.isFolder = isFolder
        self.parentID = parentID
        self.createdAt = createdAt
        self.faviconURL = faviconURL
    }

    public var host: String {
        url?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }
}
