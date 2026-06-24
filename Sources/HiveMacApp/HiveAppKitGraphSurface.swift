import SwiftUI
import AppKit
import HiveCore

public struct HiveAppKitGraphSurface: NSViewRepresentable {
    public var graph: HiveGraphSnapshot
    public var selectedNodeID: String?
    public var zoomScale: CGFloat
    public var contentOffset: CGPoint

    public init(
        graph: HiveGraphSnapshot,
        selectedNodeID: String?,
        zoomScale: CGFloat = 1,
        contentOffset: CGPoint = .zero
    ) {
        self.graph = graph
        self.selectedNodeID = selectedNodeID
        self.zoomScale = zoomScale
        self.contentOffset = contentOffset
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 6
        let canvas = HiveGraphCanvasView(frame: NSRect(x: 0, y: 0, width: 2800, height: 1800))
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
        scrollView.magnification = zoomScale
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
