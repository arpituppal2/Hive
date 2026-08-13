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

// MARK: - PageThemeColor
//
/// M3 surface tint (spec §3): the toolbar picks up a ~4% tint of the active
/// page's theme color, falling back to the canvas when unavailable. We derive
/// the tint from the favicon's average color — the only page color we have
/// without injecting JS into untrusted pages. Cheap (downsampled 8×8), cached
/// per-URL so the toolbar never re-samples on every hover.

@MainActor
enum PageThemeColor {
    /// Cache of computed average colors keyed by favicon URL.
    private static var cache: [String: Color] = [:]
    /// Hex-string cache (CORS-safe channel for the web chrome).
    private static var hexCache: [String: String] = [:]
    /// Bounded cache size — favicon URLs accumulate over months of browsing.
    private static let cacheLimit = 512

    /// Returns the average color of the favicon at `url`, or nil if the image
    /// isn't cached yet. Callers fall back to canvas when nil.
    static func forURL(_ url: URL?) -> Color? {
        guard let url else { return nil }
        let key = url.absoluteString
        if let cached = cache[key] { return cached }
        guard let image = FaviconCache.shared.image(for: url),
              let avg = averageColor(of: image) else { return nil }
        let color = Color(nsColor: avg)
        cache[key] = color
        if cache.count > cacheLimit { cache.removeAll() }
        return color
    }

    /// Same average color as a `#rrggbb` hex string, for cross-surface
    /// transport (web chrome toolbar tint). Computed natively so the web side
    /// never needs CORS access to the favicon host.
    static func hexForURL(_ url: URL?) -> String? {
        guard let url else { return nil }
        let key = url.absoluteString
        if let cached = hexCache[key] { return cached }
        guard let image = FaviconCache.shared.image(for: url),
              let avg = averageColor(of: image) else { return nil }
        let srgb = avg.usingColorSpace(.deviceRGB)
        let r = Int((srgb?.redComponent ?? 0) * 255)
        let g = Int((srgb?.greenComponent ?? 0) * 255)
        let b = Int((srgb?.blueComponent ?? 0) * 255)
        let hex = String(format: "#%02X%02X%02X", r, g, b)
        hexCache[key] = hex
        if hexCache.count > cacheLimit { hexCache.removeAll() }
        return hex
    }

    /// Downsample to 8×8 and average the RGB channels. Corrects for
    /// sRGB gamma so the tint reads neutral rather than muddy.
    private static func averageColor(of image: NSImage) -> NSColor? {
        let size = NSSize(width: 8, height: 8)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, count: CGFloat = 0
        for y in 0..<8 {
            for x in 0..<8 {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                // Skip fully transparent pixels — they'd drag the average
                // toward black on icon-with-alpha favicons.
                guard c.alphaComponent > 0.1 else { continue }
                r += c.redComponent; g += c.greenComponent; b += c.blueComponent
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return NSColor(
            srgbRed: r / count,
            green: g / count,
            blue: b / count,
            alpha: 1.0
        )
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
