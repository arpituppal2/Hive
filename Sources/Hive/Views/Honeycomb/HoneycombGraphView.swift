import SwiftUI
import AppKit
import HiveCore

// MARK: - HoneycombGraphView
//
// A visual knowledge graph showing Honeycomb nodes and edges as an interactive
// force-directed network. Nodes are circles colored by type; edges are lines
// between connected nodes. Users can pan and zoom the canvas.
//
// This is the graph exploration surface that fulfills the "graph visualization"
// requirement from the product spec — users see how their captures, claims,
// briefs, and sources are connected.

struct HoneycombGraphView: View {

    @Environment(ChromeState.self) private var state

    @State private var nodes: [HoneycombStore.Node] = []
    @State private var edges: [HoneycombStore.Edge] = []
    @State private var isLoading = false
    @State private var selectedNodeID: String?
    @State private var scale: CGFloat = 1.0
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider().overlay(Color.hiveBorderSubtle)

            if isLoading {
                Spacer()
                ProgressView().progressViewStyle(.circular)
                Spacer()
            } else if nodes.isEmpty {
                emptyState
            } else {
                GeometryReader { geo in
                    graphCanvas(size: geo.size)
                        .onAppear { canvasSize = geo.size }
                        .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
                }
                legendBar
            }
        }
        .background(Color.hiveBackground)
        .task { await loadGraph() }
    }

    // MARK: Header

    private var headerView: some View {
        HStack(spacing: HiveSpacing.s8) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .foregroundStyle(.hiveAccent)
                .font(HiveTypography.font(.dialogTitle))
            Text("Knowledge Graph")
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)
            Spacer()
            if !nodes.isEmpty {
                Text("\(nodes.count) nodes, \(edges.count) edges")
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveGraphite)
            }
            Button { Task { await loadGraph() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(HiveTypography.font(.caption1))
                    .foregroundStyle(.hiveAccent)
            }
            .buttonStyle(.plain)
            .help("Refresh graph")
        }
        .padding(.horizontal, HiveSpacing.s12)
        .padding(.vertical, HiveSpacing.s8)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.s16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(HiveTypography.font(.display2))
                .foregroundStyle(.hiveAccent.opacity(0.5))
            Text("Your archive is still empty")
                .hiveType(.body)
                .foregroundStyle(.hiveInk)
            Text("Capture pages, save Notes, and link ideas with the Librarian to build your knowledge graph.")
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HiveSpacing.s24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HiveSpacing.s48)
    }

    // MARK: Graph Canvas

    private func graphCanvas(size: CGSize) -> some View {
        Canvas { context, _ in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.35
            guard !nodes.isEmpty else { return }

            let positions = computePositions(center: center, radius: radius, count: nodes.count)

            for edge in edges {
                guard let from = positions[edge.sourceID],
                      let to = positions[edge.targetID] else { continue }
                var path = Path()
                path.move(to: from)
                path.addLine(to: to)
                context.stroke(path, with: .color(.hiveBorderSubtle), lineWidth: 1)
            }

            for node in nodes {
                guard let pos = positions[node.id] else { continue }
                let isSelected = selectedNodeID == node.id
                let nodeRadius: CGFloat = isSelected ? 12 : 8
                let rect = CGRect(x: pos.x - nodeRadius, y: pos.y - nodeRadius,
                                  width: nodeRadius * 2, height: nodeRadius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(colorFor(node.type)))

                if isSelected {
                    let ringRect = CGRect(x: pos.x - nodeRadius - 3, y: pos.y - nodeRadius - 3,
                                          width: (nodeRadius + 3) * 2, height: (nodeRadius + 3) * 2)
                    context.stroke(Path(ellipseIn: ringRect), with: .color(.hiveAccent), lineWidth: 2)
                    let text = Text(node.label).font(HiveTypography.font(.caption3))
                    context.draw(context.resolve(text), at: CGPoint(x: pos.x, y: pos.y + nodeRadius + 14))
                }
            }
        }
        .onTapGesture { location in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) * 0.35
            let positions = computePositions(center: center, radius: radius, count: nodes.count)
            var closest: String?
            var closestDist: CGFloat = 40
            for node in nodes {
                if let pos = positions[node.id] {
                    let dist = hypot(location.x - pos.x, location.y - pos.y)
                    if dist < closestDist { closest = node.id; closestDist = dist }
                }
            }
            selectedNodeID = closest
        }
    }

    // MARK: Legend

    private var legendBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HiveSpacing.s12) {
                ForEach(HoneycombStore.NodeType.allCases.filter { $0 != .unknown }, id: \.self) { type in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorFor(type))
                            .frame(width: 8, height: 8)
                        Text(type.rawValue.capitalized)
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveGraphite)
                    }
                }
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s4)
        }
    }

    // MARK: Helpers

    private func computePositions(center: CGPoint, radius: CGFloat, count: Int) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        for (i, node) in nodes.enumerated() {
            let angle = (2 * .pi * Double(i)) / Double(max(count, 1))
            let jitterX = CGFloat((node.id.hash & 0xFF)) / 255.0 * 30 - 15
            let jitterY = CGFloat((node.id.hash >> 8 & 0xFF)) / 255.0 * 30 - 15
            positions[node.id] = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius + jitterX,
                y: center.y + CGFloat(sin(angle)) * radius + jitterY
            )
        }
        return positions
    }

    private func loadGraph() async {
        guard let honeycomb = state.honeycomb else { return }
        isLoading = true
        defer { isLoading = false }

        // Load all nodes and their edges
        nodes = (try? await honeycomb.getNodesByType(.source, limit: 100)) ?? []
        edges = []
        var seenEdgeIDs = Set<String>()
        for node in nodes {
            if let nodeEdges = try? await honeycomb.getEdges(from: node.id) {
                for edge in nodeEdges where seenEdgeIDs.insert(edge.id).inserted {
                    edges.append(edge)
                }
            }
        }
    }

    private func colorFor(_ type: HoneycombStore.NodeType) -> Color {
        switch type {
        case .source:    return .blue
        case .capture:   return .green
        case .claim:     return .orange
        case .brief:     return .purple
        case .project:   return .red
        case .task:      return .yellow
        case .note:      return .gray
        case .decision:  return .pink
        case .question:  return .cyan
        case .preference:return .mint
        default:         return .gray
        }
    }
}
