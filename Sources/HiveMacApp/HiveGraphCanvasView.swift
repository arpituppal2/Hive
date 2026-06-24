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
    public var onSelectNode: ((String?) -> Void)?

    private var nodeRects: [String: CGRect] = [:]
    private var labelRects: [CGRect] = []
    private let baseNodeRadius: CGFloat = 13

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
        NSColor.clear.setFill()
        dirtyRect.fill()

        labelRects.removeAll(keepingCapacity: true)
        nodeRects.removeAll(keepingCapacity: true)
        drawEdges()
        drawNodes()
    }

    public override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if let match = nodeRects.first(where: { $0.value.contains(location) })?.key {
            onSelectNode?(match)
        } else {
            onSelectNode?(nil)
        }
    }

    private func drawEdges() {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setLineWidth(1)
        context.setStrokeColor(NSColor(calibratedWhite: 0.72, alpha: 0.28).cgColor)
        let nodeByID = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
        for edge in graph.edges {
            guard let from = nodeByID[edge.fromID], let to = nodeByID[edge.toID] else { continue }
            let start = canvasPoint(for: from)
            let end = canvasPoint(for: to)
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawNodes() {
        let orderedNodes = graph.nodes.sorted { $0.createdAt < $1.createdAt }
        for node in orderedNodes {
            let center = canvasPoint(for: node)
            let radius = node.id == selectedNodeID ? baseNodeRadius * 1.22 : baseNodeRadius
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            nodeRects[node.id] = rect
            let fillColor = node.id == selectedNodeID
                ? NSColor(calibratedRed: 0.98, green: 0.73, blue: 0.36, alpha: 0.95)
                : NSColor(calibratedWhite: 0.88, alpha: 0.82)
            fillColor.setFill()
            NSBezierPath(ovalIn: rect).fill()
            NSColor(calibratedWhite: 0.16, alpha: 0.46).setStroke()
            NSBezierPath(ovalIn: rect).stroke()
            drawLabel(for: node.title, at: CGPoint(x: center.x + radius + 6, y: center.y + radius))
        }
    }

    private func drawLabel(for title: String, at point: CGPoint) {
        let text = NSString(string: title)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 0.85)
        ]
        let size = text.size(withAttributes: attributes)
        var rect = CGRect(origin: point, size: size)
        rect.origin.y -= size.height / 2
        if labelRects.contains(where: { $0.intersects(rect.insetBy(dx: -6, dy: -3)) }) {
            return
        }
        labelRects.append(rect)
        text.draw(in: rect, withAttributes: attributes)
    }

    private func canvasPoint(for node: GraphNodeRecord) -> CGPoint {
        let width = max(bounds.width, 1_800)
        let height = max(bounds.height, 1_200)
        let center = CGPoint(x: width / 2, y: height / 2)
        let spread: CGFloat = 240
        return CGPoint(
            x: center.x + CGFloat(node.x) * spread * zoomScale,
            y: center.y + CGFloat(node.y) * spread * zoomScale
        )
    }
}
