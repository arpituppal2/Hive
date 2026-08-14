import Foundation

/// Lightweight snapshot of a tab's extracted page content. Used across Swarm,
/// capture, and context assembly so answers can be grounded in actual page text.
public struct PageContext: Sendable {
    public let tabID: String
    public let url: URL?
    public let title: String
    public let text: String
    /// Private-window provenance travels with the snapshot so downstream context
    /// assembly cannot accidentally treat private content as ordinary page text.
    public let privateBrowsing: Bool
    /// Per-tab user consent for Swarm page inspection. False means the page can
    /// still be browsed and manually captured, but not sent to model context.
    public let aiContextAllowed: Bool
    public init(tabID: String, url: URL?, title: String, text: String,
                privateBrowsing: Bool = false, aiContextAllowed: Bool = true) {
        self.tabID = tabID
        self.url = url
        self.title = title
        self.text = text
        self.privateBrowsing = privateBrowsing
        self.aiContextAllowed = aiContextAllowed
    }
}
