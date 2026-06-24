import SwiftUI
import AppKit
import HiveCore

@MainActor
private final class HiveGraphScrollView: NSScrollView {
    var onMagnifyChanged: ((CGFloat) -> Void)?

    override func magnify(with event: NSEvent) {
        let current = magnification
        let proposed = current * (1 + event.magnification)
        let clamped = min(max(proposed, minMagnification), maxMagnification)
        let location = convert(event.locationInWindow, from: nil)
        let contentPoint = contentView.convert(location, from: self)
        setMagnification(clamped, centeredAt: contentPoint)
        onMagnifyChanged?(clamped)
    }
}

public struct HiveAppKitGraphSurface: NSViewRepresentable {
    public var graph: HiveGraphSnapshot
    public var selectedNodeID: String?
    public var zoomScale: CGFloat
    public var contentOffset: CGPoint
    public var onSelectNode: (String?) -> Void
    public var onZoomChanged: (CGFloat) -> Void

    public init(
        graph: HiveGraphSnapshot,
        selectedNodeID: String?,
        zoomScale: CGFloat = 1,
        contentOffset: CGPoint = .zero,
        onSelectNode: @escaping (String?) -> Void = { _ in },
        onZoomChanged: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.graph = graph
        self.selectedNodeID = selectedNodeID
        self.zoomScale = zoomScale
        self.contentOffset = contentOffset
        self.onSelectNode = onSelectNode
        self.onZoomChanged = onZoomChanged
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = HiveGraphScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 6
        scrollView.onMagnifyChanged = onZoomChanged
        let canvas = HiveGraphCanvasView(frame: NSRect(x: 0, y: 0, width: 2800, height: 1800))
        canvas.onSelectNode = onSelectNode
        scrollView.documentView = canvas
        context.coordinator.canvasView = canvas
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let canvas = context.coordinator.canvasView ?? scrollView.documentView as? HiveGraphCanvasView else { return }
        context.coordinator.canvasView = canvas
        canvas.graph = graph
        canvas.selectedNodeID = selectedNodeID
        canvas.zoomScale = zoomScale
        canvas.contentOffset = contentOffset
        canvas.onSelectNode = onSelectNode
        if abs(scrollView.magnification - zoomScale) > 0.0001 {
            scrollView.magnification = zoomScale
        }
        if let clip = scrollView.contentView as NSClipView? {
            clip.scroll(to: contentOffset)
            scrollView.reflectScrolledClipView(clip)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator {
        fileprivate var canvasView: HiveGraphCanvasView?
    }
}
