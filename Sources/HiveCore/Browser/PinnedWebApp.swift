import Foundation

// MARK: - PinnedWebApp
//
// A lightweight model for a web app pinned to the sidebar — Sidekick/Arc-style.
// Each pinned app is a persistent, isolated web view that loads on click and
// stays warm in the background. Unlike bookmarks (static URL records), a
// PinnedWebApp carries its own browsing session and can show unread badges.
//
// Persisted in the session store alongside bookmarks and history so pinned apps
// survive restart. The actual WKWebView instances are managed by ChromeState's
// app webview pool, not by this model.

public struct PinnedWebApp: Sendable, Codable, Identifiable, Equatable {
    /// Stable UUID.
    public let id: String
    /// Human-readable label (e.g. "Gmail", "Slack").
    public var name: String
    /// The app's home URL (e.g. "https://mail.google.com").
    public var url: URL
    /// Favicon URL for the app's icon in the sidebar rail.
    public var faviconURL: URL?
    /// SF Symbol name override when no favicon is available.
    public var fallbackIcon: String
    /// Hex color for the app icon background (e.g. "#EA4335" for Google).
    public var accentColor: String
    /// Whether the app's webview is currently loaded (warm) or suspended.
    public var isLoaded: Bool
    /// Unread count badge (polled via JS injection, 0 = no badge).
    public var unreadCount: Int
    /// Display order in the sidebar (lower = higher).
    public var sortOrder: Int
    /// When the app was pinned.
    public let createdAt: Date
    /// The last time the app was activated (for sort-by-use).
    public var lastUsedAt: Date?

    public init(id: String = UUID().uuidString,
                name: String,
                url: URL,
                faviconURL: URL? = nil,
                fallbackIcon: String = "globe",
                accentColor: String = "accent",
                isLoaded: Bool = false,
                unreadCount: Int = 0,
                sortOrder: Int = 0,
                createdAt: Date = Date(),
                lastUsedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.faviconURL = faviconURL
        self.fallbackIcon = fallbackIcon
        self.accentColor = accentColor
        self.isLoaded = isLoaded
        self.unreadCount = unreadCount
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    /// The display host for the app (without "www." prefix).
    public var host: String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }
}
