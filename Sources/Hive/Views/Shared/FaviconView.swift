import SwiftUI

// MARK: - FaviconView
//
// Loads and displays a favicon by URL. Uses SwiftUI's `AsyncImage` (system URLSession, no
// external deps) backed by a shared `URLCache` sized for favicons (small payloads, kept
// hot). Falls back to a globe glyph on failure, a faded placeholder while loading.
//
// Privacy: this is the one place Hive makes a *content-initiated* network fetch (the page's
// own favicon host). It runs only for a page the user navigated to, exactly like the page
// request itself, and never reports anything to Hive. No telemetry, no remote suggest.

struct FaviconView: View {
    let url: URL
    @Environment(\.colorScheme) private var scheme

    /// Shared favicon cache: small, memory-pinned. Reused across the whole app (the OS
    /// URLSession uses this cache transparently for AsyncImage).
    private static let cache: URLCache = {
        let mem = 4 * 1024 * 1024      // 4 MB memory (favicons are tiny)
        let disk = 16 * 1024 * 1024   // 16 MB disk
        return URLCache(memoryCapacity: mem, diskCapacity: disk, diskPath: "hive-favicons")
    }()

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Image(systemName: "globe")
                    .font(HiveTypography.font(.caption2))
                    .foregroundStyle(.hiveGraphite)
            case .success(let image):
                image
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            case .failure:
                Image(systemName: "globe")
                    .font(HiveTypography.font(.caption2))
                    .foregroundStyle(.hiveMist)
            @unknown default:
                Image(systemName: "globe")
                    .font(HiveTypography.font(.caption2))
                    .foregroundStyle(.hiveGraphite)
            }
        }
        .task {
            // Point the default session cache at our favicon-tuned cache so favicons are
            // pinned across sessions, not evicted by the general cache.
            URLCache.shared = Self.cache
        }
    }
}
