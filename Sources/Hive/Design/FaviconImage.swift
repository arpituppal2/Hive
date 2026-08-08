import SwiftUI
import AppKit
import CryptoKit

// MARK: - FaviconCache
//
/// Two-tier favicon cache: fast in-memory NSCache (200 items, 8 MB) backed by
/// persistent disk storage so favicons survive app restarts. On cache miss,
/// checks disk before falling through to network. On set, writes to disk
/// asynchronously.
@MainActor
final class FaviconCache {
    static let shared = FaviconCache()
    private let cache = NSCache<NSURL, NSImage>()
    private let diskDir: URL
    private let queue = DispatchQueue(label: "com.hive.favicon-cache", qos: .utility)

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 8 * 1024 * 1024 // 8 MB

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskDir = caches.appendingPathComponent("Hive/Favicons", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    func image(for url: URL) -> NSImage? {
        // 1. Memory cache
        if let img = cache.object(forKey: url as NSURL) { return img }
        // 2. Disk cache
        if let img = loadFromDisk(url: url) {
            let cost = img.tiffRepresentation?.count ?? 0
            cache.setObject(img, forKey: url as NSURL, cost: cost)
            return img
        }
        return nil
    }

    func setImage(_ image: NSImage, for url: URL) {
        let cost = image.tiffRepresentation?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
        // Persist to disk in background
        let diskURL = diskFileURL(for: url)
        queue.async {
            if let tiff = image.tiffRepresentation {
                try? tiff.write(to: diskURL, options: .atomic)
            }
        }
    }

    // MARK: - Disk I/O

    private func diskFileURL(for url: URL) -> URL {
        let hash = url.absoluteString.data(using: .utf8).map { data in
            var hasher = SHA256()
            hasher.update(data: data)
            return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
        } ?? url.lastPathComponent
        return diskDir.appendingPathComponent(hash).appendingPathExtension("tiff")
    }

    private func loadFromDisk(url: URL) -> NSImage? {
        let fileURL = diskFileURL(for: url)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return NSImage(data: data)
    }
}

// MARK: - FaviconImage
//
/// Shared favicon rendering for tab strips, history, bookmarks, and Continue Browsing.
/// Uses an in-memory cache to avoid redundant network fetches. Falls back to a globe
/// glyph when no favicon is available.

struct FaviconImage: View {
    let url: URL?
    @State private var loadedImage: NSImage?
    @State private var loadFailed: Bool = false

    var body: some View {
        if let url {
            Group {
                if let image = cachedImage(for: url) ?? loadedImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else if loadFailed {
                    fallback
                } else {
                    fallback
                        .task(id: url) { await loadFavicon(from: url) }
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Image(systemName: "globe")
            .font(HiveDesign.Typography.captionSemiBold)
            .foregroundStyle(.secondary)
    }

    private func cachedImage(for url: URL) -> NSImage? {
        FaviconCache.shared.image(for: url)
    }

    private func loadFavicon(from url: URL) async {
        // Check cache again — another view may have loaded and cached it.
        if let cached = FaviconCache.shared.image(for: url) {
            loadedImage = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = NSImage(data: data) else {
                loadFailed = true
                return
            }
            FaviconCache.shared.setImage(image, for: url)
            loadedImage = image
        } catch {
            loadFailed = true
        }
    }
}
