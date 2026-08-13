import AppKit

// MARK: - DockTileProgress
//
// macOS dock-tile download progress (Safari/Chrome convention): while any
// download is in flight the dock icon shows a slim progress bar at the
// bottom; the bar clears when the last transfer reaches a terminal state.
// The custom content view redraws the standard app icon every frame, so the
// dock identity is never lost — only the overlay changes.
//
// AppKit drawing must happen on the main thread; every entry point hops
// there internally, so the background download callbacks can call it safely.

/// A dock-tile-sized view that draws the app icon plus an optional progress
/// bar. Kept as a single persistent instance so repeated `display()` calls
/// only ever redraw — never reconstruct the icon.
final class DockDownloadProgressView: NSView {

    private var fraction: Double = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setProgress(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        guard clamped != fraction else { return }
        fraction = clamped
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // The dock tile's backing is square; draw the standard icon to fill it.
        // Guard against a missing icon (ad-hoc/CI builds): never paint a
        // permanently black tile once the custom content view is installed.
        guard let icon = NSApp.applicationIconImage else { return }
        icon.draw(in: bounds)

        guard fraction > 0 else { return }
        let track = NSRect(x: 8, y: 8, width: max(bounds.width - 16, 0), height: 6)
        NSColor.black.withAlphaComponent(0.28).setFill()
        NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
        let fill = NSRect(x: track.minX, y: track.minY,
                          width: track.width * CGFloat(fraction), height: track.height)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: fill, xRadius: 3, yRadius: 3).fill()
    }
}

enum DockTileProgress {

    /// Last fraction actually shown on the tile. Used to throttle redraws so
    /// the dock isn't repainted on every CEF progress callback (a handful of
    /// updates per second is plenty for a smooth bar).
    nonisolated(unsafe) private static var lastFraction: Double = -1

    /// Lazily created on the main thread; only ever touched there.
    nonisolated(unsafe) private static var progressView: DockDownloadProgressView?

    /// Updates the dock-tile progress bar. `fraction` is clamped to 0…1;
    /// passing 0 clears the bar back to the plain icon. Redraws are throttled
    /// to ~2% steps except at the exact 0/1 terminal boundaries.
    static func update(fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        let isTerminal = clamped == 0 || clamped == 1
        guard abs(clamped - lastFraction) >= 0.02 || isTerminal else { return }
        lastFraction = clamped
        DispatchQueue.main.async {
            let dock = NSApp.dockTile
            if progressView == nil {
                progressView = DockDownloadProgressView(
                    frame: NSRect(origin: .zero, size: dock.size))
            }
            progressView?.setProgress(clamped)
            dock.contentView = progressView
            dock.display()
        }
    }

    /// Bounces the dock icon once — the completion signal for a backgrounded
    /// app (Chrome/Safari parity; the in-app Downloads indicator is the
    /// feedback when the app is frontmost).
    static func bounce() {
        DispatchQueue.main.async {
            NSApp.requestUserAttention(.informationalRequest)
        }
    }
}
