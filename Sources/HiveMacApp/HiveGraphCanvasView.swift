import AppKit
import HiveCore

@MainActor
public final class HiveGraphCanvasView: NSView {
    public var graph: HiveGraphSnapshot = .empty {
        didSet { needsDisplay = true }
    }
    public var selectedNodeID: String? {
        didSet { needsDisplay = true }
    }
    public var zoomScale: CGFloat = 1 {
        didSet { needsDisplay = true }
    }
    public var contentOffset: CGPoint = .zero {
        didSet { needsDisplay = true }
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // AppKit migration scaffold: final node/edge drawing and hit-testing
        // will move here from the SwiftUI/Metal path.
        NSColor.clear.setFill()
        dirtyRect.fill()
    }
}
