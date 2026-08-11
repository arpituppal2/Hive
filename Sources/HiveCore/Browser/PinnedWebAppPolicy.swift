import Foundation

// MARK: - PinnedWebAppPolicy
//
// Pure rules for the pinned web-app sidebar (Arc/Sidekick-style). Apps are
// one-per-site quick launchers: pinning a URL that's already an app refreshes
// that app in place (name/favicon update, position preserved), exactly like
// Arc's "Add to Favorites". The list is capped (`hivePinnedWebAppsCap`) and
// sorted by `sortOrder` so the app rail stays lean and deterministic.

public enum PinnedWebAppPolicy {

    /// Maximum pinned apps retained. Oldest pinned apps drop on overflow.
    /// Same order of magnitude as the reading-list cap to keep session files
    /// lean.
    public static let hivePinnedWebAppsCap = 24

    /// The identity URL used for dedupe: http/https only, host case-folded,
    /// "www." stripped, fragment dropped. The stored `PinnedWebApp.url` keeps
    /// the user's actual URL (query/path intact) so the app opens exactly the
    /// page they pinned.
    public static func normalizedAppURL(_ url: URL?) -> URL? {
        guard let url else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        guard var host = url.host?.lowercased() else { return nil }
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        // Preserve a non-default port so localhost:8080 and localhost are
        // distinct apps instead of colliding on identity.
        if let port = url.port { components.port = port }
        components.path = url.path
        // No query, no fragment: identity is the app's site+path.
        return components.url
    }

    /// Two app URLs are the same app when their normalized identities match.
    public static func isSameApp(_ lhs: URL, _ rhs: URL) -> Bool {
        normalizedAppURL(lhs) == normalizedAppURL(rhs)
    }

    /// A user-typed app name: trimmed, capped at 60 chars, falling back to the
    /// host so an empty name can never create a blank rail entry.
    public static func normalizedAppName(_ name: String, url: URL?, fallback: String = "App") -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.prefix(60))
        }
        if let host = url?.host?.replacingOccurrences(of: "www.", with: ""), !host.isEmpty {
            return String(host.prefix(60))
        }
        return fallback
    }

    /// Adds a pinned app. A brand-new app is prepended (Arc behavior: the app
    /// you just pinned is the one you want first); re-pinning an existing app
    /// refreshes its name/favicon in place and keeps its id/createdAt/
    /// sortOrder. The result is always capped.
    public static func upsert(
        existing: [PinnedWebApp],
        url: URL,
        name: String,
        faviconURL: URL?,
        fallbackIcon: String = "globe",
        accentColor: String = "accent",
        cap: Int = hivePinnedWebAppsCap
    ) -> [PinnedWebApp] {
        guard normalizedAppURL(url) != nil else { return existing }
        let cleanedName = normalizedAppName(name, url: url)
        if let index = existing.firstIndex(where: { normalizedAppURL($0.url) == normalizedAppURL(url) }) {
            var updated = existing
            updated[index].name = cleanedName
            updated[index].faviconURL = faviconURL
            // Refresh the stored URL too (Arc re-pinning): the user pinned a
            // deeper/fresher page of the same app, so it should open there.
            updated[index].url = url
            return applyCap(updated, cap: cap)
        }
        var updated = existing
        // New apps get a distinct lowest sortOrder (the panel displays
        // sortedForRail, not this array) so the app you just pinned is
        // actually first in the rail — even before any manual reorder has
        // normalized existing sortOrders.
        let lowestExisting = existing.map(\.sortOrder).min() ?? 0
        updated.insert(
            PinnedWebApp(
                name: cleanedName,
                url: url,
                faviconURL: faviconURL,
                fallbackIcon: fallbackIcon,
                accentColor: accentColor,
                sortOrder: lowestExisting - 1
            ),
            at: 0
        )
        return applyCap(updated, cap: cap)
    }

    public static func applyCap(_ apps: [PinnedWebApp], cap: Int = hivePinnedWebAppsCap) -> [PinnedWebApp] {
        guard cap > 0, apps.count > cap else { return apps }
        return Array(apps.prefix(cap))
    }

    /// The app rail order: sortOrder ascending (stable for equal values so the
    /// array order the user sees in the panel is preserved).
    public static func sortedForRail(_ apps: [PinnedWebApp]) -> [PinnedWebApp] {
        apps.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.createdAt < $1.createdAt
        }
    }

    /// Whether a URL is already pinned as an app.
    public static func isPinned(_ apps: [PinnedWebApp], url: URL?) -> Bool {
        guard let url else { return false }
        return apps.contains { normalizedAppURL($0.url) == normalizedAppURL(url) }
    }
}
