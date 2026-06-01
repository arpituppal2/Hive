import SwiftUI
import HiveCore
import HiveDesignSystem
import HiveMetalRenderer
#if os(macOS)
import AppKit
#endif

public enum HiveGraphGeometry {
    public static let hexScale: CGFloat = 0.6
    public static let coordinateDilation: Double = 2
    public static let nodeAxisOverflowRatio: Double = 1.2
    public static let axisViewportMarginRatio: CGFloat = 0.01
    public static let scrollViewportMarginRatio: CGFloat = 0.5
    public static let maximumOutZoomScale: CGFloat = 1
    public static let maximumInZoomScale: CGFloat = 4
    public static let minimumHexSeparationPadding: CGFloat = 5
    public static let hexCollisionResolutionPasses = 24

    public static func baseHexSize(for layer: MemoryNodeLayer) -> CGFloat {
        switch layer {
        case .detail:
            return 24
        case .connector:
            return 34
        case .importantTrait:
            return 48
        case .definingTrait:
            return 62
        }
    }

    public static func hexSize(for node: GraphNodeRecord, selected: Bool) -> CGFloat {
        baseHexSize(for: node.memoryLayer) * hexScale * (selected ? 1.4 : 1)
    }

    public static func renderedSemanticExtent(_ semanticExtent: Double) -> Double {
        semanticExtent * nodeAxisOverflowRatio
    }
}

public struct HiveGraphRenderPolicy: Hashable {
    public var viewportMargin: CGFloat
    public var clusterNodeLimit: Int
    public var detailNodeLimit: Int
    public var idleEdgeLimit: Int
    public var focusedEdgeLimit: Int

    public init(
        viewportMargin: CGFloat = HiveInteractionPolicy.graphViewportMargin,
        clusterNodeLimit: Int = HiveInteractionPolicy.graphClusterNodeLimit,
        detailNodeLimit: Int = HiveInteractionPolicy.graphDetailNodeLimit,
        idleEdgeLimit: Int = HiveInteractionPolicy.graphIdleEdgeLimit,
        focusedEdgeLimit: Int = HiveInteractionPolicy.graphFocusedEdgeLimit
    ) {
        self.viewportMargin = viewportMargin
        self.clusterNodeLimit = clusterNodeLimit
        self.detailNodeLimit = detailNodeLimit
        self.idleEdgeLimit = idleEdgeLimit
        self.focusedEdgeLimit = focusedEdgeLimit
    }

    public func nodeLimit(for zoomLevel: HiveSemanticZoomLevel) -> Int {
        switch zoomLevel {
        case .colony:
            return max(72, clusterNodeLimit * 3 / 4)
        case .cluster:
            return max(clusterNodeLimit, detailNodeLimit / 2)
        case .detail:
            return detailNodeLimit
        }
    }

    public func edgeLimit(selected: Bool) -> Int {
        selected ? focusedEdgeLimit : idleEdgeLimit
    }

    public func contains(_ point: CGPoint, in viewport: CGSize) -> Bool {
        point.x >= -viewportMargin
            && point.y >= -viewportMargin
            && point.x <= viewport.width + viewportMargin
            && point.y <= viewport.height + viewportMargin
    }
}

public struct HiveGraphRenderSnapshot: Hashable {
    public var zoomLevel: HiveSemanticZoomLevel
    public var renderedNodeCount: Int
    public var renderedEdgeCount: Int
    public var selectedNodeID: String?
    public var culledNodeCount: Int
    public var culledEdgeCount: Int

    public init(
        zoomLevel: HiveSemanticZoomLevel,
        renderedNodeCount: Int,
        renderedEdgeCount: Int,
        selectedNodeID: String?,
        culledNodeCount: Int,
        culledEdgeCount: Int
    ) {
        self.zoomLevel = zoomLevel
        self.renderedNodeCount = renderedNodeCount
        self.renderedEdgeCount = renderedEdgeCount
        self.selectedNodeID = selectedNodeID
        self.culledNodeCount = culledNodeCount
        self.culledEdgeCount = culledEdgeCount
    }
}

private enum GraphInstrumentSection: String, CaseIterable {
    case filters = "Filters"
    case groups = "Groups"
    case display = "Display"
}

private enum GraphLayoutPreset: String, CaseIterable {
    case compact
    case balanced
    case spacious

    var label: String {
        switch self {
        case .compact: return "Compact"
        case .balanced: return "Balanced"
        case .spacious: return "Spacious"
        }
    }

    var spreadMultiplier: Double {
        switch self {
        case .compact: return 0.86
        case .balanced: return 1
        case .spacious: return 1.18
        }
    }
}

public struct HiveGraphSurface: View {
    public var graph: HiveGraphSnapshot
    public var changeAnimationList: GraphChangeAnimationList
    public var selectedNodeID: String?
    public var searchText: String
    public var searchVisible: Bool
    public var onSelectNode: (String?) -> Void
    public var onOpenWiki: (String) -> Void
    public var onSearchChange: (String) -> Void
    public var onNodeFeedback: (FeedbackAction, String) -> Void
    public var onConfirmPlacement: (String, Double, Double) -> Void
    public var onAskNode: (String) -> Void
    public var onReindex: (GraphReindexPlan) -> Void
    public var onImportDocuments: () -> Void
    public var externalReindexRequestID: UUID?
    private let displayNodes: [GraphNodeRecord]
    private let displayNodeIDs: Set<String>
    private let displayEdges: [GraphEdgeRecord]
    private let nodeMap: [String: GraphNodeRecord]
    private let connectionMap: [String: Set<String>]
    private let domainMap: [String: LifeDomain]

    @State private var scale: CGFloat = 0.82
    @State private var offset: CGSize = .zero
    @State private var hoveredNodeID: String?
    @State private var hoveredNodePoint: CGPoint?
    @State private var hoverAnimationStartedAt: Date?
    @State private var searchDraft = ""
    @State private var knownNodeIDs: Set<String> = []
    @State private var newlyFormedNodeIDs: Set<String> = []
    @State private var edgeRevealTrigger = 0
    @State private var settledOffset: CGSize = .zero
    @State private var zoomGestureStartScale: CGFloat?
    @State private var zoomGestureStartOffset: CGSize?
    @State private var instrumentSearchVisible = false
    @State private var graphInstrumentSection: GraphInstrumentSection = .filters
    @State private var trackpadPanVelocity: CGSize = .zero
    @State private var lastTrackpadPanTimestamp: TimeInterval?
    @State private var lastTrackpadMomentumTimestamp: TimeInterval = 0
    @State private var trackpadPanInertiaGeneration = 0
    @State private var trackpadPanRenderGeneration = 0
    @State private var isTrackpadPanning = false
    @State private var currentViewportSize: CGSize = .zero
    @State private var hasAppliedInitialAxisFit = false
    @State private var isReindexing = false
    @State private var reindexPlan = GraphReindexPlan(steps: [])
    @State private var reindexStepIndex = 0
    @State private var reindexCompletedStepCount = 0
    @State private var nextReindexStepIndex = 0
    @State private var activeReindexJobs: [GraphReindexJob] = []
    @State private var completedReindexTargets: [String: GraphReindexStep] = [:]
    @State private var reindexSyntheticNodes: [GraphReindexSyntheticNode] = []
    @State private var reindexBounceTrigger = 0
    @State private var reindexStatusText = ""
    @State private var reindexPlacementStatusText = "Placing memories"
    @State private var reindexPhase: GraphReindexPhase = .idle
    @State private var reindexPairAuditTotal = 0
    @State private var reindexPairAuditProgress = 0
    @State private var reindexAuditPairs: [GraphReindexAuditPair] = []
    @State private var reindexAcceptedAuditEdges: [GraphEdgeRecord] = []
    @State private var reindexAuditStartedAt = Date()
    @State private var reindexSizingStartedAt = Date()
    @State private var reindexRequestID = UUID()
    @State private var handledExternalReindexRequestID: UUID?
    @State private var lastHoverUpdateTime: TimeInterval = 0
    @State private var lastHoverUpdatePoint: CGPoint?
    @State private var hoverTimelineActive = false
    @State private var hoverTimelineGeneration = 0
    @AppStorage("Hive.Graph.showTopicNodes") private var graphShowTopicNodes = true
    @AppStorage("Hive.Graph.showOrphanNodes") private var graphShowOrphanNodes = true
    @AppStorage("Hive.Graph.colorByGroups") private var graphColorByGroups = true
    @AppStorage("Hive.Graph.showEdgeArrows") private var graphShowEdgeArrows = false
    @AppStorage("Hive.Graph.nodeScale") private var graphNodeScale = 1.0
    @AppStorage("Hive.Graph.linkScale") private var graphLinkScale = 1.0
    @AppStorage("Hive.Graph.labelFadeThreshold") private var graphLabelFadeThreshold = 0.58
    @AppStorage("Hive.Graph.layoutPreset") private var graphLayoutPresetRaw = GraphLayoutPreset.balanced.rawValue
    @AppStorage("Hive.Graph.domainFilter") private var graphDomainFilterRaw = ""
    private let renderPolicy = HiveGraphRenderPolicy()
    @FocusState private var graphSearchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    public init(
        graph: HiveGraphSnapshot,
        changeAnimationList: GraphChangeAnimationList = .empty,
        selectedNodeID: String?,
        searchText: String,
        searchVisible: Bool,
        onSelectNode: @escaping (String?) -> Void,
        onOpenWiki: @escaping (String) -> Void,
        onSearchChange: @escaping (String) -> Void,
        onNodeFeedback: @escaping (FeedbackAction, String) -> Void = { _, _ in },
        onConfirmPlacement: @escaping (String, Double, Double) -> Void = { _, _, _ in },
        onAskNode: @escaping (String) -> Void = { _ in },
        onReindex: @escaping (GraphReindexPlan) -> Void = { _ in },
        onImportDocuments: @escaping () -> Void = {},
        externalReindexRequestID: UUID? = nil
    ) {
        let visibleNodes = graph.nodes.filter(\.isUserVisibleGraphNode)
        let visibleNodeIDs = Set(visibleNodes.map(\.id))
        let visibleEdges = graph.edges.filter {
            visibleNodeIDs.contains($0.fromID)
                && visibleNodeIDs.contains($0.toID)
                && GraphRelationshipPolicy.isVisibleConnection($0)
        }
        var connections: [String: Set<String>] = [:]
        for edge in visibleEdges {
            connections[edge.fromID, default: []].insert(edge.toID)
            connections[edge.toID, default: []].insert(edge.fromID)
        }
        self.graph = graph
        self.changeAnimationList = changeAnimationList
        self.selectedNodeID = selectedNodeID
        self.searchText = searchText
        self.searchVisible = searchVisible
        self.onSelectNode = onSelectNode
        self.onOpenWiki = onOpenWiki
        self.onSearchChange = onSearchChange
        self.onNodeFeedback = onNodeFeedback
        self.onConfirmPlacement = onConfirmPlacement
        self.onAskNode = onAskNode
        self.onReindex = onReindex
        self.onImportDocuments = onImportDocuments
        self.externalReindexRequestID = externalReindexRequestID
        self.displayNodes = visibleNodes
        self.displayNodeIDs = visibleNodeIDs
        self.displayEdges = visibleEdges
        self.nodeMap = Dictionary(uniqueKeysWithValues: visibleNodes.map { ($0.id, $0) })
        self.connectionMap = connections
        self.domainMap = Dictionary(uniqueKeysWithValues: visibleNodes.map { ($0.id, GraphLifeDomainClassifier.domain(for: $0)) })
    }

    public var body: some View {
        HiveMetalScene(grainOpacity: 0) {
            GeometryReader { proxy in
                let inspectorWidth = min(500, max(400, proxy.size.width * 0.38))
                let inspectorHeight = max(420, proxy.size.height - 116)
                let instrumentWidth = min(344, max(304, proxy.size.width * 0.2))
                let instrumentControlWidth = min(188, max(164, proxy.size.width * 0.13))
                let instrumentTopPadding: CGFloat = 0
                let instrumentLeftPadding: CGFloat = 0
                let searchTopPadding = instrumentTopPadding + HiveHIGPolicy.minimumGraphAccessibilityTarget + HiveSpacing.sm
                ZStack {
                    graphCanvas(in: proxy.size)
                    graphInstrument(in: proxy.size)
                        .frame(
                            width: instrumentControlWidth,
                            height: HiveHIGPolicy.minimumGraphAccessibilityTarget
                        )
                        .padding(.leading, instrumentLeftPadding)
                        .padding(.top, instrumentTopPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .zIndex(12)
                    if effectiveSearchVisible {
                        searchField
                            .frame(width: instrumentWidth)
                            .padding(.leading, instrumentLeftPadding)
                            .padding(.top, searchTopPadding)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .zIndex(11)
                    }
                    if let hoveredNode {
                        GraphHoverPlaque(
                            node: hoveredNode,
                            domain: domain(for: hoveredNode),
                            relatedEntries: connectedNodes(to: hoveredNode).prefixArray(3)
                        )
                            .frame(width: 260)
                            .position(hoverPlaquePosition(for: hoveredNode, in: proxy.size))
                            .transition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))
                            .zIndex(20)
                    }
                    if let selectedNode {
                        GraphExplainPanel(
                            node: selectedNode,
                            domain: domain(for: selectedNode),
                            connected: connectedNodes(to: selectedNode),
                            onOpenWiki: { onOpenWiki(selectedNode.id) },
                            onAsk: { question in
                                onAskNode("For \(GraphPresentationModel(node: selectedNode).title): \(question)")
                            },
                            onMarkImportant: { onNodeFeedback(.matters, selectedNode.id) },
                            onMarkIncidental: { onNodeFeedback(.incidental, selectedNode.id) },
                            onConfirmPlacement: { x, y in onConfirmPlacement(selectedNode.id, x, y) },
                            onSelectConnected: { onSelectNode($0) },
                            onClose: { onSelectNode(nil) }
                        )
                            .frame(width: inspectorWidth, height: inspectorHeight)
                            .position(
                                x: proxy.size.width - inspectorWidth / 2 - 24,
                                y: 86 + inspectorHeight / 2
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                    if isReindexing {
                        GraphReindexStatusLine(
                            text: reindexStatusText,
                            step: reindexDisplayStep,
                            total: reindexDisplayTotal
                        )
                        .frame(width: min(300, max(238, proxy.size.width * 0.22)))
                        .padding(.trailing, HiveSpacing.lg)
                        .padding(.bottom, 76)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(13)
                    }
#if os(macOS)
                    GraphTrackpadPanMonitor { event in
                        handleTrackpadPan(event, viewport: proxy.size)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)
                    .zIndex(4)
#endif
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged {
                            let proposed = CGSize(width: settledOffset.width + $0.translation.width, height: settledOffset.height + $0.translation.height)
                            offset = clampedGraphOffset(proposed, in: proxy.size, scale: scale)
                        }
                        .onEnded { _ in settledOffset = clampedGraphOffset(offset, in: proxy.size, scale: scale) }
                )
                .simultaneousGesture(
                    MagnifyGesture(minimumScaleDelta: 0)
                        .onChanged { value in
                            applyZoom(
                                magnification: value.magnification,
                                anchor: CGPoint(x: value.startAnchor.x * proxy.size.width, y: value.startAnchor.y * proxy.size.height),
                                viewport: proxy.size
                            )
                        }
                        .onEnded { _ in
                            settledOffset = offset
                            zoomGestureStartScale = nil
                            zoomGestureStartOffset = nil
                        }
                )
                .onTapGesture {
                    onSelectNode(nil)
                }
                .onAppear {
                    currentViewportSize = proxy.size
                    applyInitialAxisFitIfNeeded(in: proxy.size)
                    knownNodeIDs = currentNodeIDSet
                    newlyFormedNodeIDs = Set(visibleNodes.prefix(72).map(\.id))
                    edgeRevealTrigger += 1
                    clearFormationMarks()
                    handleExternalReindexRequestIfNeeded()
                }
                .onChange(of: proxy.size) { _, size in
                    currentViewportSize = size
                    applyCenteredViewport(in: size)
                    settledOffset = offset
                }
                .onChange(of: graphAutoCenterSignature) { _, _ in
                    withAnimation(HiveMotion.panel) {
                        applyCenteredViewport(in: proxy.size)
                    }
                }
                .onChange(of: currentNodeIDSet) { _, ids in
                    let inserted = ids.subtracting(knownNodeIDs)
                    knownNodeIDs = ids
                    guard !inserted.isEmpty else { return }
                    withAnimation(HiveMotion.panel) {
                        newlyFormedNodeIDs = inserted
                        offset = personalCenterOffset(in: proxy.size, scale: scale)
                        settledOffset = offset
                    }
                    edgeRevealTrigger += 1
                    clearFormationMarks()
                }
                .onChange(of: externalReindexRequestID) { _, _ in
                    handleExternalReindexRequestIfNeeded()
                }
                .animation(HiveMotion.panel, value: selectedNodeID)
            }
        }
    }

    private func graphCanvas(in size: CGSize) -> some View {
        let cache = graphDisplayCache
        return TimelineView(.animation(
            minimumInterval: 1.0 / Double(HiveInteractionPolicy.graphPreferredFramesPerSecond),
            paused: !isReindexing && changeAnimationList.isEmpty && !hoverTimelineActive
        )) { timeline in
            let rendered = renderItems(in: size, cache: cache, at: timeline.date)
            ZStack {
                GraphAtmosphereLayer(nodes: rendered.nodes, edges: rendered.edges)
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
                GraphRenderLayer(nodes: rendered.nodes, edges: rendered.edges, reindexEdges: rendered.reindexEdges)
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
                ForEach(reindexSyntheticNodes) { syntheticNode in
                    GraphReindexSyntheticHoneycomb(node: syntheticNode, trigger: reindexBounceTrigger)
                        .position(syntheticNode.center)
                        .transition(.scale(scale: 0.72).combined(with: .opacity))
                        .zIndex(14)
                }
                graphHitOverlay(nodes: rendered.hitNodes)
            }
            .contentShape(Rectangle())
            .modifier(GraphContinuousHoverModifier(
                onActive: { point in
                    updateHover(at: point, in: size, cache: cache)
                },
                onEnded: {
                    clearHover()
                }
            ))
        }
    }

    private func graphHitOverlay(nodes: [GraphRenderNodeItem]) -> some View {
        ForEach(nodes) { item in
            Rectangle()
                .fill(Color.clear)
                .frame(
                    width: HiveHIGPolicy.minimumGraphAccessibilityTarget,
                    height: HiveHIGPolicy.minimumGraphAccessibilityTarget
                )
                .contentShape(Rectangle())
                .position(item.center)
                .onTapGesture {
                    onSelectNode(item.id)
                }
                .onTapGesture(count: 2) {
                    onOpenWiki(item.id)
                }
                .onLongPressGesture {
                    onSelectNode(item.id)
                }
                .contextMenu {
                    Button {
                        searchDraft = item.title
                        onSearchChange(item.title)
                        instrumentSearchVisible = true
                    } label: {
                        GraphMenuLabel("Search related", symbol: .search)
                    }
                    Button {
                        onSelectNode(item.id)
                    } label: {
                        GraphMenuLabel("Focus path", symbol: .recenter)
                    }
                    Button {
                        onOpenWiki(item.id)
                    } label: {
                        GraphMenuLabel("Open in Colony", symbol: .openWiki)
                    }
                    Button {
                        startReindex()
                    } label: {
                        GraphMenuLabel("Re-index", symbol: .runMaintenance)
                    }
                    Divider()
                    Button {
                        onNodeFeedback(.approve, item.id)
                    } label: {
                        GraphMenuLabel("Mark important", symbol: .markImportant)
                    }
                    Button {
                        onNodeFeedback(.incidental, item.id)
                    } label: {
                        GraphMenuLabel("Mark incidental", symbol: .markIncidental)
                    }
                    Button(role: .destructive) {
                        onNodeFeedback(.delete, item.id)
                    } label: {
                        GraphMenuLabel("Forget", symbol: .forget)
                    }
                }
                .onHover { hovering in
                    if hovering {
                        enterHover(nodeID: item.id, at: item.center)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item.title.isEmpty ? "Hive cell" : item.title)
                .accessibilityValue(graphAccessibilityValue(for: item.id))
                .accessibilityHint("Selects this Hive cell. Double-click opens its Colony article.")
                .accessibilityAddTraits(.isButton)
        }
    }

    private func graphAccessibilityValue(for nodeID: String) -> String {
        guard let node = nodeMap[nodeID] else { return "" }
        let domain = domain(for: node).label
        let connections = connectedIDs(to: nodeID).count
        return connections == 1 ? "\(domain), 1 connection" : "\(domain), \(connections) connections"
    }

    private var hoverFocusModel: GraphHoverFocusModel? {
        guard let hoveredNodeID else { return nil }
        return graphFocusModel(for: hoveredNodeID)
    }

    private func graphFocusModel(for rootID: String) -> GraphHoverFocusModel {
        var firstNodeIDs = Set<String>()
        var secondNodeIDs = Set<String>()
        var firstEdgeIDs = Set<String>()
        var secondEdgeIDs = Set<String>()

        for edge in displayEdges where GraphRelationshipPolicy.isVisibleConnection(edge) {
            if edge.fromID == rootID {
                firstNodeIDs.insert(edge.toID)
                firstEdgeIDs.insert(edge.id)
            } else if edge.toID == rootID {
                firstNodeIDs.insert(edge.fromID)
                firstEdgeIDs.insert(edge.id)
            }
        }

        for edge in displayEdges where GraphRelationshipPolicy.isVisibleConnection(edge) && !firstEdgeIDs.contains(edge.id) {
            if firstNodeIDs.contains(edge.fromID),
               edge.toID != rootID,
               !firstNodeIDs.contains(edge.toID) {
                secondNodeIDs.insert(edge.toID)
                secondEdgeIDs.insert(edge.id)
            } else if firstNodeIDs.contains(edge.toID),
                      edge.fromID != rootID,
                      !firstNodeIDs.contains(edge.fromID) {
                secondNodeIDs.insert(edge.fromID)
                secondEdgeIDs.insert(edge.id)
            }
        }

        return GraphHoverFocusModel(
            rootID: rootID,
            firstNodeIDs: firstNodeIDs,
            secondNodeIDs: secondNodeIDs.subtracting([rootID]).subtracting(firstNodeIDs),
            firstEdgeIDs: firstEdgeIDs,
            secondEdgeIDs: secondEdgeIDs
        )
    }

    private func hoverNodeOpacity(base: Double, nodeID: String, focus: GraphHoverFocusModel, at date: Date) -> Double {
        let fadeProgress = hoverRevealProgress(delay: 0, duration: GraphHoverTiming.dimDuration, at: date)
        let target: Double
        switch focus.nodeTier(for: nodeID) {
        case 0:
            target = 1
        case 1:
            let reveal = hoverRevealProgress(delay: GraphHoverTiming.firstNodeDelay, duration: GraphHoverTiming.firstNodeDuration, at: date)
            target = 0.10 + (0.50 - 0.10) * reveal
        case 2:
            let reveal = hoverRevealProgress(delay: GraphHoverTiming.secondNodeDelay, duration: GraphHoverTiming.secondNodeDuration, at: date)
            target = 0.08 + (0.25 - 0.08) * reveal
        default:
            target = 0.08
        }
        return base + (target - base) * fadeProgress
    }

    private func hoverEdgeOpacity(tier: Int, at date: Date) -> Double {
        switch tier {
        case 1:
            return 0.67 * hoverRevealProgress(delay: GraphHoverTiming.firstEdgeDelay, duration: GraphHoverTiming.firstEdgeDuration, at: date)
        case 2:
            return 0.33 * hoverRevealProgress(delay: GraphHoverTiming.secondEdgeDelay, duration: GraphHoverTiming.secondEdgeDuration, at: date)
        default:
            return 0
        }
    }

    private func hoverEdgeRevealProgress(tier: Int, at date: Date) -> CGFloat {
        switch tier {
        case 1:
            return CGFloat(hoverRevealProgress(delay: GraphHoverTiming.firstEdgeDelay, duration: GraphHoverTiming.firstEdgeDuration, at: date))
        case 2:
            return CGFloat(hoverRevealProgress(delay: GraphHoverTiming.secondEdgeDelay, duration: GraphHoverTiming.secondEdgeDuration, at: date))
        default:
            return 0
        }
    }

    private func hoverRevealProgress(delay: TimeInterval, duration: TimeInterval, at date: Date) -> Double {
        guard duration > 0 else { return 1 }
        let start = hoverAnimationStartedAt ?? date
        let raw = min(1, max(0, (date.timeIntervalSince(start) - delay) / duration))
        return raw * raw * (3 - 2 * raw)
    }

    @ViewBuilder
    private func graphInstrument(in size: CGSize) -> some View {
        GraphInstrumentMenu(
            title: "Hive",
            symbol: .hiveGraph,
            active: effectiveSearchVisible || selectedNodeID != nil || isReindexing
        ) {
            Button {
                onImportDocuments()
            } label: {
                GraphMenuLabel("Import to Field…", symbol: .importAction)
            }
            Divider()
            Button {
                withAnimation(HiveMotion.panel) {
                    instrumentSearchVisible.toggle()
                }
            } label: {
                GraphMenuLabel("Search The Hive", symbol: .search)
            }
            Button {
                recenter()
            } label: {
                GraphMenuLabel("Center", symbol: .recenter)
            }
            Button {
                zoomBy(1.18, in: size)
            } label: {
                GraphMenuLabel("Zoom in", symbol: .zoomIn)
            }
            .disabled(scale >= HiveGraphGeometry.maximumInZoomScale - 0.01)
            Button {
                zoomBy(1 / 1.18, in: size)
            } label: {
                GraphMenuLabel("Zoom out", symbol: .zoomOut)
            }
            .disabled(scale <= minimumGraphScale(for: size) + 0.01)
            Button {
                startReindex()
            } label: {
                GraphMenuLabel(isReindexing ? "Re-indexing" : "Re-index", symbol: .runMaintenance)
            }
            .disabled(isReindexing || visibleNodes.isEmpty)
            Divider()
            Menu {
                Toggle(isOn: $graphShowTopicNodes) {
                    GraphMenuLabel("Show topic cells", symbol: .hiveGraph)
                }
                Toggle(isOn: $graphShowOrphanNodes) {
                    GraphMenuLabel("Show orphans", symbol: .inspect)
                }
                Divider()
                GraphMenuMetricLabel(title: "\(visibleNodes.count) nodes", detail: "\(visibleEdges.count) links")
            } label: {
                GraphMenuLabel("Filters", symbol: .filter)
            }
            Menu {
                Toggle(isOn: $graphColorByGroups) {
                    GraphMenuLabel("Domain colors", symbol: .hiveGraph)
                }
                Divider()
                Button {
                    graphDomainFilterRaw = ""
                } label: {
                    GraphMenuLabel("All groups", symbol: .hiveGraph)
                }
                ForEach(graphDomainCounts, id: \.domain) { item in
                    Button {
                        graphDomainFilterRaw = selectedDomainFilter == item.domain ? "" : item.domain.rawValue
                    } label: {
                        GraphMenuMetricLabel(title: item.domain.label, detail: "\(item.count)")
                    }
                }
            } label: {
                GraphMenuLabel("Groups", symbol: .hiveGraph)
            }
            Menu {
                Toggle(isOn: $graphShowEdgeArrows) {
                    GraphMenuLabel("Show arrows", symbol: .recenter)
                }
                Picker("Layout", selection: $graphLayoutPresetRaw) {
                    ForEach(GraphLayoutPreset.allCases, id: \.self) { preset in
                        Text(preset.label).tag(preset.rawValue)
                    }
                }
                Divider()
                Button {
                    graphLabelFadeThreshold = max(0.35, graphLabelFadeThreshold - 0.05)
                } label: {
                    GraphMenuLabel("Show more labels", symbol: .inspect)
                }
                Button {
                    graphLabelFadeThreshold = min(0.9, graphLabelFadeThreshold + 0.05)
                } label: {
                    GraphMenuLabel("Fade labels sooner", symbol: .inspect)
                }
                Button {
                    graphNodeScale = min(1.35, graphNodeScale + 0.05)
                } label: {
                    GraphMenuLabel("Larger hexes", symbol: .hiveGraph)
                }
                Button {
                    graphNodeScale = max(0.75, graphNodeScale - 0.05)
                } label: {
                    GraphMenuLabel("Smaller hexes", symbol: .hiveGraph)
                }
                Button {
                    graphLinkScale = min(1.6, graphLinkScale + 0.05)
                } label: {
                    GraphMenuLabel("Thicker links", symbol: .merge)
                }
                Button {
                    graphLinkScale = max(0.7, graphLinkScale - 0.05)
                } label: {
                    GraphMenuLabel("Thinner links", symbol: .merge)
                }
            } label: {
                GraphMenuLabel("Display", symbol: .settings)
            }
        }
        .animation(HiveMotion.panel, value: selectedNodeID)
        .animation(HiveMotion.panel, value: effectiveSearchVisible)
    }

    @ViewBuilder
    private var graphInstrumentSectionContent: some View {
        switch graphInstrumentSection {
        case .filters:
            graphFilterControls
        case .groups:
            graphGroupControls
        case .display:
            graphDisplayControls
        }
    }

    private var graphFilterControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            GraphToggleRow(
                title: "Topics",
                detail: "Show topic/tag cells",
                symbol: .hiveGraph,
                isOn: graphShowTopicNodes
            ) {
                graphShowTopicNodes.toggle()
            }
            GraphToggleRow(
                title: "Orphans",
                detail: "Show notes without links",
                symbol: .inspect,
                isOn: graphShowOrphanNodes
            ) {
                graphShowOrphanNodes.toggle()
            }
            GraphMetricLine(
                title: "\(visibleNodes.count) nodes",
                detail: "\(visibleEdges.count) links visible"
            )
        }
    }

    private var graphGroupControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            GraphToggleRow(
                title: "Domain colors",
                detail: "Color notes by Hive group",
                symbol: .hiveGraph,
                isOn: graphColorByGroups
            ) {
                graphColorByGroups.toggle()
            }
            let counts = graphDomainCounts
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 7)], alignment: .leading, spacing: 7) {
                GraphDomainChip(
                    title: "All",
                    count: graphFilterCandidateNodes.count,
                    color: HiveColorToken.waxAmber.color,
                    active: selectedDomainFilter == nil
                ) {
                    graphDomainFilterRaw = ""
                }
                ForEach(counts, id: \.domain) { item in
                    GraphDomainChip(
                        title: item.domain.label,
                        count: item.count,
                        color: item.domain.graphColor,
                        active: selectedDomainFilter == item.domain
                    ) {
                        graphDomainFilterRaw = selectedDomainFilter == item.domain ? "" : item.domain.rawValue
                    }
                }
            }
        }
    }

    private var graphDisplayControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            GraphToggleRow(
                title: "Arrows",
                detail: "Show link direction on strong paths",
                symbol: .recenter,
                isOn: graphShowEdgeArrows
            ) {
                graphShowEdgeArrows.toggle()
            }
            GraphCompactSlider(title: "Text", value: $graphLabelFadeThreshold, range: 0.35...0.9)
            GraphCompactSlider(title: "Nodes", value: $graphNodeScale, range: 0.75...1.35)
            GraphCompactSlider(title: "Links", value: $graphLinkScale, range: 0.7...1.6)
            HStack(spacing: 7) {
                ForEach(GraphLayoutPreset.allCases, id: \.self) { preset in
                    GraphSmallChip(
                        title: preset.label,
                        active: graphLayoutPreset == preset
                    ) {
                        graphLayoutPresetRaw = preset.rawValue
                        recenter()
                    }
                }
            }
        }
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                HiveSymbol(.search, size: 15, active: !searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .frame(width: 22)
                TextField("Find people, projects, or memories", text: $searchDraft)
                    .textFieldStyle(.plain)
                    .font(HiveTypography.chromeSearch)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .focused($graphSearchFocused)
                    .onSubmit {
                        submitGraphSearch()
                    }
                if !searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HiveSymbolButton(.close, title: "Clear search", compact: true) {
                        searchDraft = ""
                        onSearchChange("")
                        graphSearchFocused = true
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    HiveSymbolButton(.send, title: "Ask", active: true, motion: .bounce, motionValue: searchDraft.count, compact: true) {
                        submitGraphSearch()
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            if searchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 7) {
                    HiveText("Suggestions", role: .scaffoldLabel)
                        .foregroundStyle(HiveColorToken.scaffoldGray.color)
                    ForEach(searchSuggestions, id: \.id) { node in
                        Button {
                            let title = GraphPresentationModel(node: node).title
                            searchDraft = title
                            onSearchChange(title)
                            graphSearchFocused = true
                        } label: {
                            HiveText(GraphPresentationModel(node: node).title, role: .scaffoldBody)
                                .lineLimit(1)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                                .background(HiveColorToken.raisedSurface.color.opacity(0.56))
                                .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.smallCornerRadius, style: .continuous))
                        }
                        .buttonStyle(HiveControlPressStyle())
                        .help("Search for \(GraphPresentationModel(node: node).title)")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HiveText(searchResultSummary, role: .scaffoldLabel)
                    .foregroundStyle(HiveColorToken.scaffoldGray.color)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
        }
        .padding(.vertical, 9)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .modifier(HiveGlassShell(level: .search))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search The Hive")
        .onAppear {
            searchDraft = searchText
            graphSearchFocused = true
        }
        .onChange(of: searchText) { _, value in
            if searchDraft != value {
                searchDraft = value
            }
        }
        .onChange(of: searchDraft) { _, value in
            if searchText != value {
                onSearchChange(value)
            }
        }
        .animation(HiveMotion.focus, value: searchDraft.isEmpty)
    }

    private var selectedNode: GraphNodeRecord? {
        selectedNodeID.flatMap { id in displayNodes.first { $0.id == id } }
    }

    private var hoveredNode: GraphNodeRecord? {
        hoveredNodeID.flatMap { id in displayNodes.first { $0.id == id } }
    }

    private var effectiveSearchVisible: Bool {
        searchVisible || instrumentSearchVisible || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var reindexDisplayStep: Int {
        switch reindexPhase {
        case .idle, .planning:
            return 0
        case .placingNodes:
            return min(reindexCompletedStepCount, max(reindexPlan.steps.count, 1))
        case .auditingPairs:
            return min(reindexPairAuditProgress, reindexDisplayTotal)
        case .sizingNodes:
            return reindexDisplayTotal
        }
    }

    private var reindexDisplayTotal: Int {
        switch reindexPhase {
        case .idle, .planning:
            return 1
        case .placingNodes:
            return max(reindexPlan.steps.count, 1)
        case .auditingPairs:
            return max(reindexPairAuditTotal, 1)
        case .sizingNodes:
            return max(reindexPairAuditTotal, reindexPlan.steps.count, 1)
        }
    }

    private var selectedDomainFilter: LifeDomain? {
        LifeDomain(rawValue: graphDomainFilterRaw)
    }

    private var graphLayoutPreset: GraphLayoutPreset {
        GraphLayoutPreset(rawValue: graphLayoutPresetRaw) ?? .balanced
    }

    private var searchSuggestions: [GraphNodeRecord] {
        graphFilterCandidateNodes
            .sorted { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return GraphPresentationModel(node: lhs).title < GraphPresentationModel(node: rhs).title
                }
                return lhs.confidence > rhs.confidence
            }
            .reduce(into: [GraphNodeRecord]()) { partial, node in
                guard partial.count < 3 else { return }
                let title = GraphPresentationModel(node: node).title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard title.count > 2, !partial.contains(where: { GraphPresentationModel(node: $0).title == title }) else { return }
                partial.append(node)
            }
    }

    private var searchResultSummary: String {
        let query = searchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return "Search suggestions from your Hive" }
        let count = graphSearchTopMatches(for: query).count
        return count == 1 ? "1 matching memory" : "\(count) matching memories"
    }

    private var graphDisplayCache: GraphDisplayCache {
        let selection = GraphSelectionModel(
            selectedID: hoveredNodeID ?? selectedNodeID,
            nodeIDs: displayNodeIDs,
            edges: displayEdges
        )
        let visibleNodes = visibleNodes(from: displayNodes, nodeMap: nodeMap)
        let visibleNodeIDs = Set(visibleNodes.map(\.id))
        let visibleEdges = displayEdges
            .filter { visibleNodeIDs.contains($0.fromID) && visibleNodeIDs.contains($0.toID) }
            .filter { shouldRenderEdge($0, selection: selection) }
        return GraphDisplayCache(
            displayNodes: displayNodes,
            displayEdges: displayEdges,
            nodeMap: nodeMap,
            selection: selection,
            visibleNodes: visibleNodes,
            visibleEdges: visibleEdges,
            nodeTitles: Dictionary(uniqueKeysWithValues: visibleNodes.map { node in
                (node.id, GraphPresentationModel(node: node).title)
            })
        )
    }

    private var currentNodeIDSet: Set<String> {
        displayNodeIDs
    }

    private var selectionModel: GraphSelectionModel {
        GraphSelectionModel(
            selectedID: hoveredNodeID ?? selectedNodeID,
            nodeIDs: displayNodeIDs,
            edges: displayEdges
        )
    }

    private var visibleNodes: [GraphNodeRecord] {
        visibleNodes(from: displayNodes, nodeMap: nodeMap)
    }

    private var graphFilterCandidateNodes: [GraphNodeRecord] {
        displayNodes.filter { passesGraphNodeFilters($0) }
    }

    private var graphDomainCounts: [(domain: LifeDomain, count: Int)] {
        let nodes = displayNodes.filter { node in
            if !graphShowTopicNodes && node.kind == .topic { return false }
            if !graphShowOrphanNodes && connectedIDs(to: node.id).isEmpty { return false }
            return true
        }
        let counts = Dictionary(grouping: nodes, by: { domain(for: $0) })
            .map { (domain: $0.key, count: $0.value.count) }
        return counts.sorted {
            if $0.count == $1.count { return $0.domain.label < $1.domain.label }
            return $0.count > $1.count
        }
    }

    private var graphContentBounds: CGRect {
        let fallbackMinX = -HiveGraphGeometry.renderedSemanticExtent(GraphSemanticAxes.horizontalExtent) - GraphSemanticAxes.overviewPadding
        let fallbackMaxX = HiveGraphGeometry.renderedSemanticExtent(GraphSemanticAxes.horizontalExtent) + GraphSemanticAxes.overviewPadding
        let fallbackMinY = -HiveGraphGeometry.renderedSemanticExtent(GraphSemanticAxes.verticalExtent) - GraphSemanticAxes.overviewPadding
        let fallbackMaxY = HiveGraphGeometry.renderedSemanticExtent(GraphSemanticAxes.verticalExtent) + GraphSemanticAxes.overviewPadding
        guard let firstNode = displayNodes.first else {
            return CGRect(
                x: CGFloat(fallbackMinX),
                y: CGFloat(fallbackMinY),
                width: CGFloat(max(1, fallbackMaxX - fallbackMinX)),
                height: CGFloat(max(1, fallbackMaxY - fallbackMinY))
            )
        }
        let firstCoordinate = displayCoordinate(for: GraphSemanticCoordinate(x: firstNode.x, y: firstNode.y))
        let firstRadius = Double(nodeSize(firstNode)) * 0.5 + GraphSemanticAxes.overviewPadding
        var minX = firstCoordinate.x - firstRadius
        var maxX = firstCoordinate.x + firstRadius
        var minY = firstCoordinate.y - firstRadius
        var maxY = firstCoordinate.y + firstRadius
        for node in displayNodes {
            let coordinate = displayCoordinate(for: GraphSemanticCoordinate(x: node.x, y: node.y))
            let radius = Double(nodeSize(node)) * 0.5 + GraphSemanticAxes.overviewPadding
            minX = min(minX, coordinate.x - radius)
            maxX = max(maxX, coordinate.x + radius)
            minY = min(minY, coordinate.y - radius)
            maxY = max(maxY, coordinate.y + radius)
        }
        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(max(1, maxX - minX)),
            height: CGFloat(max(1, maxY - minY))
        )
    }

    private func visibleNodes(from displayNodes: [GraphNodeRecord], nodeMap: [String: GraphNodeRecord]) -> [GraphNodeRecord] {
        let limit = renderPolicy.nodeLimit(for: zoomLevel)
        let filteredNodes = displayNodes.filter { passesGraphNodeFilters($0) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return Array(filteredNodes.prefix(limit))
        }

        let matches = graphSearchTopMatches(for: query)
        let matchIDs = Set(matches.map(\.id))
        let contextIDs = Set(matches.flatMap { connectedIDs(to: $0.id) })
        let context = filteredNodes.filter { contextIDs.contains($0.id) && !matchIDs.contains($0.id) }
        return Array((matches + context).prefix(limit))
    }

    private var visibleEdges: [GraphEdgeRecord] {
        let ids = Set(visibleNodes.map(\.id))
        let selection = selectionModel
        return displayEdges
            .filter { ids.contains($0.fromID) && ids.contains($0.toID) }
            .filter { shouldRenderEdge($0, selection: selection) }
    }

    private func passesGraphNodeFilters(_ node: GraphNodeRecord) -> Bool {
        if !graphShowTopicNodes && node.kind == .topic { return false }
        if !graphShowOrphanNodes && connectedIDs(to: node.id).isEmpty { return false }
        if let selectedDomainFilter, domain(for: node) != selectedDomainFilter { return false }
        return true
    }

    private var zoomLevel: HiveSemanticZoomLevel {
        if scale < 0.4 { return .colony }
        if scale <= 1.2 { return .cluster }
        return .detail
    }

    private var graphAutoCenterSignature: String {
        let viewportInputs = [
            graphLayoutPresetRaw,
            graphShowTopicNodes.description,
            graphShowOrphanNodes.description,
            graphDomainFilterRaw,
            String((graphNodeScale * 100).rounded() / 100)
        ].joined(separator: ":")
        let nodeSignature = displayNodes
            .sorted { $0.id < $1.id }
            .map { node in
                let x = (node.x * 100).rounded() / 100
                let y = (node.y * 100).rounded() / 100
                return "\(node.id):\(x):\(y)"
            }
            .joined(separator: "|")
        return "\(viewportInputs)|\(nodeSignature)"
    }

    private func position(for nodeID: String, in size: CGSize) -> CGPoint {
        guard let node = nodeMap[nodeID] else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        return position(for: node, in: size)
    }

    private func position(for node: GraphNodeRecord, in size: CGSize) -> CGPoint {
        let micro = micromotion(for: node)
        let coordinate = displayCoordinate(for: GraphSemanticCoordinate(x: node.x, y: node.y))
        let point = axisPoint(x: coordinate.x, y: coordinate.y, in: size)
        return CGPoint(x: point.x + micro.x, y: point.y + micro.y)
    }

    private func renderPosition(for node: GraphNodeRecord, base: CGPoint, in size: CGSize, at date: Date) -> CGPoint {
        if let job = activeReindexJobs.first(where: { $0.step.affectedNodeIDs.contains(node.id) }) {
            let target = reindexTargetPoint(for: job.step, in: size)
            let progress = job.progress(at: date)
            return reindexAnimatedPoint(
                nodeID: node.id,
                from: base,
                to: target,
                progress: progress
            )
        }
        if let event = changeAnimationList.event(forNodeID: node.id, at: date),
           event.node?.id == node.id,
           event.kind == .insertion || event.kind == .split || event.kind == .movement,
           let from = event.from,
           let to = event.to {
            let fromPoint = graphPoint(for: from, in: size)
            let toPoint = graphPoint(for: to, in: size)
            return interpolate(from: fromPoint, to: toPoint, progress: CGFloat(event.easedProgress(elapsed: changeAnimationList.elapsed(at: date))))
        }
        guard isReindexing, let completedStep = completedReindexTargets[node.id] else {
            return base
        }
        let target = reindexTargetPoint(for: completedStep, in: size)
        return CGPoint(
            x: target.x,
            y: target.y
        )
    }

    private func progressForActiveReindex(nodeID: String, at date: Date) -> CGFloat {
        activeReindexJobs
            .filter { $0.step.affectedNodeIDs.contains(nodeID) }
            .map { $0.progress(at: date) }
            .max() ?? 0
    }

    private func reindexTargetPoint(for step: GraphReindexStep, in size: CGSize) -> CGPoint {
        graphPoint(
            x: step.unitX * GraphSemanticAxes.horizontalNodeRange,
            y: step.unitY * GraphSemanticAxes.verticalNodeRange,
            in: size
        )
    }

    private func graphPoint(x: Double, y: Double, in size: CGSize) -> CGPoint {
        let coordinate = displayCoordinate(for: GraphSemanticCoordinate(x: x, y: y))
        return axisPoint(x: coordinate.x, y: coordinate.y, in: size)
    }

    private func graphPoint(for coordinate: GraphSemanticCoordinate, in size: CGSize) -> CGPoint {
        graphPoint(x: coordinate.x, y: coordinate.y, in: size)
    }

    private func displayCoordinate(for coordinate: GraphSemanticCoordinate) -> GraphSemanticCoordinate {
        let horizontalLimit = HiveGraphGeometry.renderedSemanticExtent(GraphSemanticAxes.horizontalExtent)
        let verticalLimit = HiveGraphGeometry.renderedSemanticExtent(GraphSemanticAxes.verticalExtent)
        let spread = graphLayoutPreset.spreadMultiplier
        return GraphSemanticCoordinate(
            x: min(horizontalLimit, max(-horizontalLimit, coordinate.x * HiveGraphGeometry.coordinateDilation * HiveGraphGeometry.nodeAxisOverflowRatio * spread)),
            y: min(verticalLimit, max(-verticalLimit, coordinate.y * HiveGraphGeometry.coordinateDilation * HiveGraphGeometry.nodeAxisOverflowRatio * spread))
        )
    }

    private func interpolate(from: CGPoint, to: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: from.x + (to.x - from.x) * progress,
            y: from.y + (to.y - from.y) * progress
        )
    }

    private func axisPoint(x: Double, y: Double, in size: CGSize) -> CGPoint {
        let axisScale = axisScreenScale(in: size)
        return CGPoint(
            x: size.width / 2 + CGFloat(x) * axisScale.width * scale + offset.width,
            y: size.height / 2 - CGFloat(y) * axisScale.height * scale + offset.height
        )
    }

    private func axisScreenScale(in size: CGSize) -> CGSize {
        let marginX = size.width * HiveGraphGeometry.axisViewportMarginRatio
        let marginY = size.height * HiveGraphGeometry.axisViewportMarginRatio
        let usableWidth = max(1, size.width - marginX * 2)
        let usableHeight = max(1, size.height - marginY * 2)
        return CGSize(
            width: usableWidth / CGFloat(GraphSemanticAxes.horizontalExtent * 2),
            height: usableHeight / CGFloat(GraphSemanticAxes.verticalExtent * 2)
        )
    }

    private func hoverPlaquePosition(for node: GraphNodeRecord, in size: CGSize) -> CGPoint {
        let origin = hoveredNodePoint ?? position(for: node.id, in: size)
        return CGPoint(
            x: min(size.width - 150, max(150, origin.x + 18)),
            y: min(size.height - 98, max(82, origin.y - 78))
        )
    }

    private func enterHover(nodeID: String, at point: CGPoint) {
        hoveredNodePoint = point
        guard hoveredNodeID != nodeID else { return }
        hoverTimelineGeneration += 1
        let generation = hoverTimelineGeneration
        hoverAnimationStartedAt = Date()
        hoverTimelineActive = true
        withAnimation(HiveMotion.control) {
            hoveredNodeID = nodeID
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + GraphHoverTiming.totalPlaybackDuration) {
            guard hoverTimelineGeneration == generation, hoveredNodeID == nodeID else { return }
            hoverTimelineActive = false
        }
    }

    private func updateHover(at point: CGPoint, in size: CGSize, cache: GraphDisplayCache) {
        let now = Date.timeIntervalSinceReferenceDate
        if let lastHoverUpdatePoint,
           now - lastHoverUpdateTime < HiveInteractionPolicy.graphHoverUpdateInterval,
           sqrt(squaredDistance(from: lastHoverUpdatePoint, to: point)) < HiveInteractionPolicy.graphHoverMinimumPointDelta {
            return
        }
        lastHoverUpdateTime = now
        lastHoverUpdatePoint = point
        let candidates = hoverHitNodes(in: size, cache: cache, at: Date())
        guard let nearest = candidates.min(by: {
            squaredDistance(from: $0.center, to: point) < squaredDistance(from: $1.center, to: point)
        }) else {
            clearHover()
            return
        }
        let distance = sqrt(squaredDistance(from: nearest.center, to: point))
        let hitRadius = max(HiveHIGPolicy.minimumGraphAccessibilityTarget / 2, nearest.size / 2 + 18)
        if distance <= hitRadius {
            enterHover(nodeID: nearest.id, at: point)
        } else {
            clearHover()
        }
    }

    private func hoverHitNodes(in size: CGSize, cache: GraphDisplayCache, at date: Date) -> [GraphRenderNodeItem] {
        let hitNodes: [GraphRenderNodeItem] = cache.visibleNodes.compactMap { node -> GraphRenderNodeItem? in
            let center = renderPosition(
                for: node,
                base: position(for: node, in: size),
                in: size,
                at: date
            )
            guard renderPolicy.contains(center, in: size) else { return nil }
            return GraphRenderNodeItem(
                id: node.id,
                title: cache.nodeTitles[node.id] ?? node.title,
                center: center,
                size: nodeSize(node),
                layer: node.memoryLayer,
                domain: domain(for: node),
                fill: graphFillColor(for: node),
                border: graphBorderColor(for: node, selected: false, focused: false, hovered: false),
                opacity: 1,
                borderWidth: 1,
                dashedBorder: node.confidence < 0.5,
                selected: false,
                dimmed: false,
                showsLabel: false
            )
        }
        return hitNodes
    }

    private func clearHover() {
        guard hoveredNodeID != nil || hoveredNodePoint != nil else { return }
        lastHoverUpdatePoint = nil
        hoverTimelineGeneration += 1
        hoverTimelineActive = false
        hoverAnimationStartedAt = nil
        withAnimation(HiveMotion.control) {
            hoveredNodeID = nil
            hoveredNodePoint = nil
        }
    }

    private func leaveHover(nodeID: String) {
        guard hoveredNodeID == nodeID else { return }
        clearHover()
    }

    private func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private func nodeSize(_ node: GraphNodeRecord) -> CGFloat {
        let count = connectedIDs(to: node.id).count
        let base: CGFloat
        switch count {
        case 0...2:
            base = 20
        case 3...5:
            base = 28
        case 6...10:
            base = 36
        default:
            base = 44
        }
        let confidenceScale: CGFloat
        switch node.confidence {
        case 0.8...:
            confidenceScale = 1
        case 0.5..<0.8:
            confidenceScale = 0.86
        default:
            confidenceScale = 0.68
        }
        return max(12, base * confidenceScale * CGFloat(graphNodeScale) * (node.id == selectedNodeID ? 1.18 : 1))
    }

    private func isDimmed(_ node: GraphNodeRecord) -> Bool {
        isDimmed(node, selection: selectionModel)
    }

    private func isDimmed(_ node: GraphNodeRecord, selection: GraphSelectionModel) -> Bool {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return !searchMatches(node)
        }
        return selection.dimmedIDs.contains(node.id)
    }

    private func searchMatches(_ node: GraphNodeRecord) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return false }
        return searchScore(node, query: query) > 0
    }

    private func graphSearchTopMatches(for query: String) -> [GraphNodeRecord] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return [] }
        return graphFilterCandidateNodes
            .map { node in (node, searchScore(node, query: cleanedQuery)) }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return GraphPresentationModel(node: lhs.0).title < GraphPresentationModel(node: rhs.0).title
                }
                return lhs.1 > rhs.1
            }
            .map(\.0)
    }

    private func searchScore(_ node: GraphNodeRecord, query: String) -> Double {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return 0 }
        let title = GraphPresentationModel(node: node).title.lowercased()
        let searchable = searchableText(for: node)
        let tokens = searchTokens(for: normalizedQuery)
        var score = 0.0
        if title == normalizedQuery { score += 10 }
        if title.contains(normalizedQuery) { score += 5 }
        if searchable.contains(normalizedQuery) { score += 3 }
        for token in tokens {
            if title.split(separator: " ").contains(where: { $0 == token }) {
                score += 1.4
            } else if title.contains(token) {
                score += 0.8
            } else if searchable.contains(token) {
                score += 0.45
            }
        }
        let neighborMatched = connectedIDs(to: node.id).contains { id in
            guard let neighbor = nodeMap[id] else { return false }
            return searchableText(for: neighbor).contains(normalizedQuery)
                || tokens.contains { searchableText(for: neighbor).contains($0) }
        }
        if neighborMatched { score += 0.35 }
        return score
    }

    private func searchableText(for node: GraphNodeRecord) -> String {
        [
            GraphPresentationModel(node: node).title,
            node.kind.rawValue,
            node.memoryLayer.rawValue,
            domain(for: node).label
        ]
            .joined(separator: " ")
            .lowercased()
    }

    private func searchTokens(for value: String) -> [String] {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
    }

    private func submitGraphSearch() {
        let query = searchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            graphSearchFocused = false
            return
        }
        onSearchChange(query)
        let relatedTopics = graphSearchTopMatches(for: query)
            .prefix(5)
            .map { GraphPresentationModel(node: $0).title }
        let topicList = relatedTopics.isEmpty
            ? "No visible Hive topics matched directly."
            : relatedTopics.joined(separator: "; ")
        onAskNode("Search The Hive for: \(query). Use these related Hive topics first: \(topicList)")
        graphSearchFocused = false
    }

    private func isStatementLike(_ title: String) -> Bool {
        let cleaned = SourcePresentationModel.cleanTitle(title)
        let lower = cleaned.lowercased()
        return cleaned.count > 48
            || lower.hasPrefix("the user ")
            || lower.hasPrefix("user ")
            || lower.hasPrefix("the user's ")
    }

    private func edgeOpacity(_ edge: GraphEdgeRecord) -> Double {
        edgeOpacity(edge, nodeMap: nodeMap, selection: selectionModel)
    }

    private func edgeOpacity(_ edge: GraphEdgeRecord, nodeMap: [String: GraphNodeRecord], selection: GraphSelectionModel) -> Double {
        let relationshipOpacity = GraphRelationshipPolicy.visibleOpacity(forStrength: edge.strength)
        guard relationshipOpacity > 0 else { return 0 }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return searchMatches(nodeMap[edge.fromID] ?? GraphNodeRecord(id: "", title: "", kind: .topic, confidence: 0, sourceRefs: []))
                || searchMatches(nodeMap[edge.toID] ?? GraphNodeRecord(id: "", title: "", kind: .topic, confidence: 0, sourceRefs: []))
                ? min(1, relationshipOpacity + 0.18)
                : min(0.16, relationshipOpacity * 0.18 + 0.035)
        }
        let baseline = min(0.28, relationshipOpacity * 0.22 + 0.05)
        guard selectedNodeID != nil || hoveredNodeID != nil else { return baseline }
        return selection.activeEdgeIDs.contains(edge.id) ? max(baseline, min(0.38, relationshipOpacity * 0.36)) : baseline
    }

    private func edgeHighlightOpacity(_ edge: GraphEdgeRecord, selection: GraphSelectionModel, at date: Date) -> Double {
        if let tier = hoverFocusModel?.edgeTier(for: edge.id) {
            return hoverEdgeOpacity(tier: tier, at: date)
        }
        if selection.activeEdgeIDs.contains(edge.id) {
            return min(0.72, GraphRelationshipPolicy.visibleOpacity(forStrength: edge.strength) + 0.08)
        }
        return 0
    }

    private func shouldRenderEdge(_ edge: GraphEdgeRecord, selection: GraphSelectionModel) -> Bool {
        guard GraphRelationshipPolicy.isVisibleConnection(edge) else { return false }
        return true
    }

    private func edgeMatchesSearch(_ edge: GraphEdgeRecord) -> Bool {
        guard let from = nodeMap[edge.fromID], let to = nodeMap[edge.toID] else { return false }
        return searchMatches(from) || searchMatches(to)
    }

    private func edgeIsActive(_ edge: GraphEdgeRecord) -> Bool {
        edgeIsActive(edge, selection: selectionModel)
    }

    private func edgeIsActive(_ edge: GraphEdgeRecord, selection: GraphSelectionModel) -> Bool {
        if newlyFormedNodeIDs.contains(edge.fromID) || newlyFormedNodeIDs.contains(edge.toID) {
            return true
        }
        if hoverFocusModel?.edgeTier(for: edge.id) != nil {
            return true
        }
        return selection.activeEdgeIDs.contains(edge.id)
    }

    private func edgeLineWidth(_ edge: GraphEdgeRecord) -> CGFloat {
        edgeLineWidth(edge, selection: selectionModel)
    }

    private func edgeLineWidth(_ edge: GraphEdgeRecord, selection: GraphSelectionModel) -> CGFloat {
        if let tier = hoverFocusModel?.edgeTier(for: edge.id) {
            let tierBase = tier == 1 ? 1.45 : 0.95
            return (tierBase + edge.strength * 1.35) * CGFloat(graphLinkScale)
        }
        let base = selection.activeEdgeIDs.contains(edge.id) ? 1.3 + edge.strength * 1.7 : 0.32 + edge.strength * 0.64
        return base * CGFloat(graphLinkScale)
    }

    private func edgeColor(_ edge: GraphEdgeRecord) -> Color {
        edgeColor(edge, nodeMap: nodeMap, selection: selectionModel)
    }

    private func edgeColor(_ edge: GraphEdgeRecord, nodeMap: [String: GraphNodeRecord], selection: GraphSelectionModel) -> Color {
        if hoverFocusModel?.edgeTier(for: edge.id) != nil {
            return HiveColorToken.waxAmberBright.color.opacity(0.94)
        }
        if selection.activeEdgeIDs.contains(edge.id) {
            return HiveColorToken.waxAmberBright.color.opacity(0.94)
        }
        if let from = nodeMap[edge.fromID], let to = nodeMap[edge.toID] {
            let fromDomain = domain(for: from)
            let toDomain = domain(for: to)
            if fromDomain == toDomain, fromDomain != .background {
                return fromDomain.graphColor.opacity(edge.strength >= 0.78 ? 0.72 : 0.48)
            }
        }
        return edge.strength >= 0.78
            ? HiveColorToken.waxAmberDeep.color.opacity(0.58)
            : HiveColorToken.scaffoldFaint.color.opacity(0.46)
    }

    private func applyZoom(magnification: CGFloat, anchor: CGPoint, viewport: CGSize) {
        let startScale = zoomGestureStartScale ?? scale
        let startOffset = zoomGestureStartOffset ?? offset
        if zoomGestureStartScale == nil {
            zoomGestureStartScale = scale
            zoomGestureStartOffset = offset
        }

        let newScale = min(HiveGraphGeometry.maximumInZoomScale, max(minimumGraphScale(for: viewport), startScale * magnification))
        let center = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        let worldX = (anchor.x - center.x - startOffset.width) / max(startScale, 0.001)
        let worldY = (anchor.y - center.y - startOffset.height) / max(startScale, 0.001)
        scale = newScale
        let proposedOffset = CGSize(
            width: anchor.x - center.x - worldX * newScale,
            height: anchor.y - center.y - worldY * newScale
        )
        offset = clampedGraphOffset(proposedOffset, in: viewport, scale: newScale)
    }

    private func handleTrackpadPan(_ event: GraphTrackpadPanEvent, viewport: CGSize) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        let delta = event.delta
        if abs(delta.width) > 0.01 || abs(delta.height) > 0.01 {
            markTrackpadPanActive()
            let proposed = CGSize(width: offset.width + delta.width, height: offset.height + delta.height)
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                offset = clampedGraphOffset(proposed, in: viewport, scale: scale)
                settledOffset = offset
            }
            updateTrackpadVelocity(delta: delta, timestamp: event.timestamp, isMomentum: event.isMomentum)
        }
        if event.isMomentum {
            lastTrackpadMomentumTimestamp = event.timestamp
        }
        if event.ended {
            if event.isMomentum {
                trackpadPanVelocity = .zero
                settledOffset = offset
            } else {
                scheduleTrackpadPanInertia(viewport: viewport)
            }
            lastTrackpadPanTimestamp = nil
        }
    }

    private func updateTrackpadVelocity(delta: CGSize, timestamp: TimeInterval, isMomentum: Bool) {
        guard !isMomentum else { return }
        defer { lastTrackpadPanTimestamp = timestamp }
        guard let last = lastTrackpadPanTimestamp else {
            trackpadPanVelocity = delta
            return
        }
        let elapsed = max(1.0 / 120.0, min(0.08, timestamp - last))
        let instant = CGSize(width: delta.width / elapsed, height: delta.height / elapsed)
        trackpadPanVelocity = CGSize(
            width: trackpadPanVelocity.width * 0.42 + instant.width * 0.58,
            height: trackpadPanVelocity.height * 0.42 + instant.height * 0.58
        )
    }

    private func scheduleTrackpadPanInertia(viewport: CGSize) {
        let velocity = trackpadPanVelocity
        guard hypot(velocity.width, velocity.height) > 60 else {
            trackpadPanVelocity = .zero
            settledOffset = offset
            return
        }
        trackpadPanInertiaGeneration += 1
        let generation = trackpadPanInertiaGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) {
            guard generation == trackpadPanInertiaGeneration else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastTrackpadMomentumTimestamp > 0.08 else { return }
            applyTrackpadPanInertia(velocity: velocity, viewport: viewport)
        }
    }

    private func applyTrackpadPanInertia(velocity: CGSize, viewport: CGSize) {
        let projected = limitedTrackpadInertiaDisplacement(
            CGSize(width: velocity.width * 0.15, height: velocity.height * 0.15)
        )
        let target = clampedGraphOffset(
            CGSize(width: offset.width + projected.width, height: offset.height + projected.height),
            in: viewport,
            scale: scale
        )
        markTrackpadPanActive(for: 0.56)
        withAnimation(HiveMotion.drift) {
            offset = target
            settledOffset = target
        }
        trackpadPanVelocity = .zero
    }

    private func markTrackpadPanActive(for duration: TimeInterval = 0.18) {
        trackpadPanRenderGeneration += 1
        let generation = trackpadPanRenderGeneration
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            isTrackpadPanning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard generation == trackpadPanRenderGeneration else { return }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                isTrackpadPanning = false
            }
        }
    }

    private func limitedTrackpadInertiaDisplacement(_ displacement: CGSize) -> CGSize {
        let length = hypot(displacement.width, displacement.height)
        let maximum: CGFloat = 150
        guard length > maximum, length > 0 else { return displacement }
        let factor = maximum / length
        return CGSize(width: displacement.width * factor, height: displacement.height * factor)
    }

    private func clearFormationMarks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            newlyFormedNodeIDs = []
        }
    }

    private func startReindex() {
        guard !isReindexing else { return }
        clearHover()
        let nodes = graph.nodes
        let nodeIDs = Set(nodes.map(\.id))
        let edges = graph.edges.filter { nodeIDs.contains($0.fromID) && nodeIDs.contains($0.toID) }
        let snapshot = graph
        let requestID = UUID()
        reindexRequestID = requestID
        reindexPlan = GraphReindexPlan(steps: [])
        reindexStepIndex = 0
        reindexCompletedStepCount = 0
        nextReindexStepIndex = 0
        activeReindexJobs = []
        completedReindexTargets = [:]
        reindexSyntheticNodes = []
        reindexAuditPairs = []
        reindexAcceptedAuditEdges = []
        reindexPhase = .planning
        reindexPairAuditTotal = 0
        reindexPairAuditProgress = 0
        reindexPlacementStatusText = "Placing memories"
        reindexStatusText = "Planning with Apple Intelligence"
        withAnimation(HiveMotion.panel) {
            isReindexing = true
        }
        let maxStepCount = max(nodes.count, 1)
        Task.detached(priority: .userInitiated) {
            let planningResult = await GraphReindexPlan.makeWithFoundationModelsResult(
                nodes: nodes,
                edges: edges,
                maxSteps: maxStepCount
            )
            let plan = planningResult.plan
            let application = plan.applyingWithAudit(to: snapshot)
            await MainActor.run {
                guard reindexRequestID == requestID else { return }
                let statusText = planningResult.usedFoundationModels
                    ? "Placing Apple Intelligence plan"
                    : "Placing indexed Hive plan"
                beginReindex(with: plan, application: application, statusText: statusText)
            }
        }
    }

    private func handleExternalReindexRequestIfNeeded() {
        guard let externalReindexRequestID,
              handledExternalReindexRequestID != externalReindexRequestID else {
            return
        }
        handledExternalReindexRequestID = externalReindexRequestID
        startReindex()
    }

    private func beginReindex(
        with plan: GraphReindexPlan,
        application: GraphReindexApplication,
        statusText: String = "Placing memories"
    ) {
        guard !plan.steps.isEmpty else {
            onReindex(plan)
            clearReindexState()
            return
        }
        reindexPlan = plan
        reindexStepIndex = 0
        reindexCompletedStepCount = 0
        nextReindexStepIndex = 0
        activeReindexJobs = []
        completedReindexTargets = [:]
        reindexSyntheticNodes = []
        reindexPhase = .placingNodes
        configureReindexAudit(application: application)
        reindexPairAuditProgress = 0
        reindexPlacementStatusText = statusText
        reindexStatusText = statusText
        fillReindexSlots()
    }

    private func fillReindexSlots() {
        guard isReindexing, reindexPhase == .placingNodes else { return }
        guard nextReindexStepIndex < reindexPlan.steps.count else {
            updateReindexStatus()
            return
        }

        var jobs = activeReindexJobs
        var nextIndex = nextReindexStepIndex
        let openSlots = max(0, GraphReindexJob.maximumConcurrentJobs - jobs.count)
        guard openSlots > 0 else {
            updateReindexStatus()
            return
        }

        for _ in 0..<openSlots where nextIndex < reindexPlan.steps.count {
            let step = reindexPlan.steps[nextIndex]
            let job = GraphReindexJob(
                step: step,
                planIndex: nextIndex,
                slot: nextIndex % GraphReindexJob.maximumConcurrentJobs,
                startedAt: Date(),
                duration: reindexDuration(for: step, index: nextIndex, in: currentViewportSize)
            )
            jobs.append(job)
            scheduleReindexCompletion(for: job)
            nextIndex += 1
        }
        activeReindexJobs = jobs
        nextReindexStepIndex = nextIndex
        updateReindexStatus()
    }

    private func scheduleReindexCompletion(for job: GraphReindexJob) {
        DispatchQueue.main.asyncAfter(deadline: .now() + job.duration) {
            completeReindexJob(id: job.id)
        }
    }

    private func completeReindexJob(id: String) {
        guard isReindexing,
              reindexPhase == .placingNodes,
              let job = activeReindexJobs.first(where: { $0.id == id }) else { return }
        activeReindexJobs.removeAll { $0.id == id }
        for nodeID in job.step.affectedNodeIDs {
            completedReindexTargets[nodeID] = job.step
        }
        reindexCompletedStepCount = min(reindexPlan.steps.count, reindexCompletedStepCount + 1)
        reindexStepIndex = reindexCompletedStepCount
        updateReindexStatus()

        fillReindexSlots()
        if nextReindexStepIndex >= reindexPlan.steps.count && activeReindexJobs.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                guard isReindexing, reindexPhase == .placingNodes, activeReindexJobs.isEmpty else { return }
                beginReindexPairAudit()
            }
        }
    }

    private func updateReindexStatus() {
        guard reindexPhase == .placingNodes else { return }
        reindexStepIndex = min(reindexPlan.steps.count, reindexCompletedStepCount)
        reindexStatusText = reindexPlacementStatusText
    }

    private func reindexDuration(for step: GraphReindexStep, index: Int, in viewport: CGSize) -> TimeInterval {
        let size = viewport.width > 0 && viewport.height > 0 ? viewport : CGSize(width: 1_200, height: 820)
        let from = reindexStartPoint(for: step, in: size)
        let to = reindexTargetPoint(for: step, in: size)
        let distance = hypot(to.x - from.x, to.y - from.y)
        let scale = max(1, min(size.width, size.height))
        let movementComponent = min(0.7, Double(distance / scale) * 0.95)
        let operationComponent: TimeInterval
        switch step.operation {
        case .consolidate:
            operationComponent = 1.05
        case .split:
            operationComponent = 1.15
        case .delete:
            operationComponent = 0.48
        case .create:
            operationComponent = 0.92
        case .edgeCheck:
            operationComponent = 0.36
        case .reconnect:
            operationComponent = 0.62
        case .move:
            operationComponent = 0.42
        }
        return 0.2 + movementComponent * 0.42 + operationComponent * 0.28
    }

    private func finishReindex() {
        beginReindexPairAudit()
    }

    private func beginReindexPairAudit() {
        guard isReindexing else { return }
        reindexPhase = .auditingPairs
        reindexStatusText = "Testing connections"
        reindexAuditStartedAt = Date()
        reindexPairAuditProgress = 0
        reindexStepIndex = 0
        reindexCompletedStepCount = 0
        if reindexPairAuditTotal <= 0 {
            beginReindexSizing()
        } else {
            advanceReindexPairAudit(requestID: reindexRequestID)
        }
    }

    private func advanceReindexPairAudit(requestID: UUID) {
        guard isReindexing, reindexPhase == .auditingPairs, requestID == reindexRequestID else { return }
        let remaining = reindexPairAuditTotal - reindexPairAuditProgress
        guard remaining > 0 else {
            beginReindexSizing()
            return
        }
        reindexPairAuditProgress += min(remaining, reindexPairAuditChunkSize)
        reindexStepIndex = reindexPairAuditProgress
        reindexCompletedStepCount = reindexPairAuditProgress
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.018) {
            advanceReindexPairAudit(requestID: requestID)
        }
    }

    private func beginReindexSizing() {
        guard isReindexing else { return }
        reindexPhase = .sizingNodes
        reindexSizingStartedAt = Date()
        withAnimation(HiveMotion.panel) {
            activeReindexJobs = []
            reindexSyntheticNodes = []
        }
        reindexStatusText = reindexAcceptedAuditEdges.isEmpty ? "Sizing by connections" : "Making connections"
        onReindex(reindexPlan)
        let hold = min(1.1, max(0.42, 0.36 + Double(reindexAcceptedAuditEdges.count) * 0.012))
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
            clearReindexState()
        }
    }

    private func clearReindexState() {
        withAnimation(HiveMotion.panel) {
            isReindexing = false
            reindexPhase = .idle
            activeReindexJobs = []
            completedReindexTargets = [:]
            reindexSyntheticNodes = []
            reindexPairAuditTotal = 0
            reindexPairAuditProgress = 0
            reindexAuditPairs = []
            reindexAcceptedAuditEdges = []
            reindexPlacementStatusText = "Placing memories"
            reindexStepIndex = 0
            reindexCompletedStepCount = 0
            nextReindexStepIndex = 0
        }
    }

    private func showReindexSyntheticNode(for step: GraphReindexStep) {
        guard currentViewportSize.width > 0, let primary = nodeMap[step.nodeID] else { return }
        let merged = step.mergedWithNodeID.flatMap { nodeMap[$0] }
        let center = reindexTargetPoint(for: step, in: currentViewportSize)
        let baseSize = max(nodeSize(primary), merged.map { nodeSize($0) } ?? 0)
        let domain = domain(for: primary)
        reindexSyntheticNodes.append(GraphReindexSyntheticNode(
            id: step.id,
            center: center,
            size: max(12, baseSize * CGFloat(step.mergedSizeMultiplier)),
            fill: graphFillColor(for: primary, domain: domain),
            border: HiveColorToken.waxAmber.color
        ))
        reindexBounceTrigger += 1
    }

    private var reindexPairAuditChunkSize: Int {
        max(GraphReindexJob.maximumConcurrentJobs, max(1, reindexPairAuditTotal / 160))
    }

    private func configureReindexAudit(application: GraphReindexApplication) {
        let existingEdgeIDs = Set(graph.edges.map(\.id))
        reindexAcceptedAuditEdges = application.snapshot.edges.filter { edge in
            edge.id.hasPrefix("audit-") && !existingEdgeIDs.contains(edge.id)
        }
        let acceptedPairKeys = Set(reindexAcceptedAuditEdges.map { graphPairKey($0.fromID, $0.toID) })
        let auditNodeIDs = application.snapshot.nodes
            .filter(\.isUserVisibleGraphNode)
            .map(\.id)
            .sorted()
        var pairs: [GraphReindexAuditPair] = []
        for leftIndex in auditNodeIDs.indices {
            let nextIndex = auditNodeIDs.index(after: leftIndex)
            guard nextIndex < auditNodeIDs.endIndex else { continue }
            for rightIndex in nextIndex..<auditNodeIDs.endIndex {
                let fromID = auditNodeIDs[leftIndex]
                let toID = auditNodeIDs[rightIndex]
                pairs.append(GraphReindexAuditPair(
                    index: pairs.count,
                    fromID: fromID,
                    toID: toID,
                    accepted: acceptedPairKeys.contains(graphPairKey(fromID, toID))
                ))
            }
        }
        reindexAuditPairs = pairs
        reindexPairAuditTotal = pairs.count
    }

    private func graphPairKey(_ firstID: String, _ secondID: String) -> String {
        firstID < secondID ? "\(firstID)::\(secondID)" : "\(secondID)::\(firstID)"
    }

    private func reindexStartPoint(for step: GraphReindexStep, in size: CGSize) -> CGPoint {
        let points = step.affectedNodeIDs.compactMap { nodeID -> CGPoint? in
            guard let node = nodeMap[nodeID] else { return nil }
            return position(for: node, in: size)
        }
        guard !points.isEmpty else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        let total = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        return CGPoint(x: total.x / CGFloat(points.count), y: total.y / CGFloat(points.count))
    }

    private func reindexAnimatedPoint(nodeID: String, from: CGPoint, to: CGPoint, progress: CGFloat) -> CGPoint {
        interpolate(from: from, to: to, progress: progress)
    }

    private func recenter() {
        withAnimation(HiveMotion.panel) {
            applyCenteredViewport(in: currentViewportSize)
        }
    }

    private func applyCenteredViewport(in viewport: CGSize) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        scale = minimumGraphScale(for: viewport)
        offset = personalCenterOffset(in: viewport, scale: scale)
        settledOffset = offset
    }

    private func zoomBy(_ factor: CGFloat, in viewport: CGSize) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        let minimumScale = minimumGraphScale(for: viewport)
        let nextScale = min(HiveGraphGeometry.maximumInZoomScale, max(minimumScale, scale * factor))
        withAnimation(HiveMotion.panel) {
            scale = nextScale
            offset = clampedGraphOffset(offset, in: viewport, scale: nextScale)
            settledOffset = offset
        }
    }

    private func clampedGraphOffset(_ proposed: CGSize, in viewport: CGSize, scale proposedScale: CGFloat) -> CGSize {
        guard viewport.width > 0, viewport.height > 0 else { return .zero }
        let bounds = graphContentBounds
        let horizontal = graphOffsetRange(
            viewportLength: viewport.width,
            semanticLower: Double(bounds.minX),
            semanticUpper: Double(bounds.maxX),
            screenScale: axisScreenScale(in: viewport).width,
            scale: proposedScale,
            invertedAxis: false
        )
        let vertical = graphOffsetRange(
            viewportLength: viewport.height,
            semanticLower: Double(bounds.minY),
            semanticUpper: Double(bounds.maxY),
            screenScale: axisScreenScale(in: viewport).height,
            scale: proposedScale,
            invertedAxis: true
        )
        return CGSize(
            width: min(horizontal.upperBound, max(horizontal.lowerBound, proposed.width)),
            height: min(vertical.upperBound, max(vertical.lowerBound, proposed.height))
        )
    }

    private func graphOffsetRange(
        viewportLength: CGFloat,
        semanticLower: Double,
        semanticUpper: Double,
        screenScale: CGFloat,
        scale proposedScale: CGFloat,
        invertedAxis: Bool
    ) -> ClosedRange<CGFloat> {
        let margin = viewportLength * HiveGraphGeometry.scrollViewportMarginRatio
        let halfViewport = viewportLength / 2
        let scaledLower = CGFloat(semanticLower) * screenScale * proposedScale
        let scaledUpper = CGFloat(semanticUpper) * screenScale * proposedScale
        let lower: CGFloat
        let upper: CGFloat
        if invertedAxis {
            lower = viewportLength - margin - halfViewport + scaledLower
            upper = margin - halfViewport + scaledUpper
        } else {
            lower = viewportLength - margin - halfViewport - scaledUpper
            upper = margin - halfViewport - scaledLower
        }
        guard lower <= upper else { return 0...0 }
        return lower...upper
    }

    private func minimumGraphScale(for viewport: CGSize) -> CGFloat {
        guard viewport.width > 0, viewport.height > 0 else { return HiveGraphGeometry.maximumOutZoomScale }
        let bounds = graphContentBounds
        let axisScale = axisScreenScale(in: viewport)
        let marginX = viewport.width * HiveGraphGeometry.axisViewportMarginRatio
        let marginY = viewport.height * HiveGraphGeometry.axisViewportMarginRatio
        let requiredWidth = max(1, bounds.width * axisScale.width)
        let requiredHeight = max(1, bounds.height * axisScale.height)
        let fitScale = min(
            max(1, viewport.width - marginX * 2) / requiredWidth,
            max(1, viewport.height - marginY * 2) / requiredHeight
        )
        return min(HiveGraphGeometry.maximumOutZoomScale, max(0.22, fitScale))
    }

    private func clampScaleToAxisFloor(in viewport: CGSize) {
        let minimumScale = minimumGraphScale(for: viewport)
        guard scale < minimumScale else { return }
        scale = minimumScale
    }

    private func applyInitialAxisFitIfNeeded(in viewport: CGSize) {
        guard !hasAppliedInitialAxisFit else {
            clampScaleToAxisFloor(in: viewport)
            return
        }
        applyCenteredViewport(in: viewport)
        hasAppliedInitialAxisFit = true
    }

    private var graphCenterAnchor: GraphSemanticCoordinate {
        let bounds = graphContentBounds
        return GraphSemanticCoordinate(x: Double(bounds.midX), y: Double(bounds.midY))
    }

    private func personalCenterOffset(in viewport: CGSize, scale proposedScale: CGFloat) -> CGSize {
        guard viewport.width > 0, viewport.height > 0 else { return .zero }
        let center = graphCenterAnchor
        let screenScale = axisScreenScale(in: viewport)
        let proposed = CGSize(
            width: -CGFloat(center.x) * screenScale.width * proposedScale,
            height: CGFloat(center.y) * screenScale.height * proposedScale
        )
        return clampedGraphOffset(proposed, in: viewport, scale: proposedScale)
    }

    private func connectedIDs(to id: String) -> Set<String> {
        connectionMap[id] ?? []
    }

    private func connectedNodes(to node: GraphNodeRecord) -> [GraphNodeRecord] {
        let ids = connectedIDs(to: node.id)
        return displayNodes.filter { ids.contains($0.id) }.prefixArray(8)
    }

    private func micromotion(for node: GraphNodeRecord) -> CGPoint {
        .zero
    }

    private func domain(for node: GraphNodeRecord) -> LifeDomain {
        domainMap[node.id] ?? GraphLifeDomainClassifier.domain(for: node)
    }

    private func graphFillColor(for node: GraphNodeRecord, domain: LifeDomain? = nil) -> Color {
        if node.memoryLayer == .detail && node.confidence < 0.48 {
            return HiveColorToken.scaffoldFaint.color
        }
        guard graphColorByGroups else { return HiveColorToken.waxAmber.color }
        return (domain ?? self.domain(for: node)).graphColor
    }

    private func graphBorderColor(for node: GraphNodeRecord, selected: Bool, focused: Bool, hovered: Bool) -> Color {
        if selected || focused || hovered {
            return HiveColorToken.waxAmberBright.color
        }
        if node.memoryLayer == .detail && node.confidence < 0.48 {
            return HiveColorToken.scaffoldFaint.color.opacity(0.54)
        }
        return graphFillColor(for: node).opacity(node.memoryLayer == .detail ? 0.58 : 0.78)
    }

    private func shouldShowGraphLabel(for node: GraphNodeRecord, selected: Bool, hovered: Bool) -> Bool {
        if selected || hovered || searchMatches(node) { return true }
        if node.memoryLayer == .definingTrait { return node.confidence >= graphLabelFadeThreshold }
        if zoomLevel == .detail && node.memoryLayer == .importantTrait {
            return node.confidence >= max(0.42, graphLabelFadeThreshold - 0.08)
        }
        return false
    }

    private func renderItems(in size: CGSize, cache: GraphDisplayCache, at date: Date = Date()) -> GraphRenderedItems {
        var positions: [String: CGPoint] = [:]
        var candidateNodes: [GraphRenderNodeItem] = []
        let activeReindexIDs = Set(activeReindexJobs.flatMap(\.step.affectedNodeIDs))
        let completedReindexIDs = Set(completedReindexTargets.keys)
        let movingReindexIDs = activeReindexIDs.union(completedReindexIDs)
        let elapsedChangeTime = changeAnimationList.elapsed(at: date)
        let hoverFocus = hoverFocusModel
        for node in cache.visibleNodes {
            let baseCenter = position(for: node, in: size)
            let center = renderPosition(for: node, base: baseCenter, in: size, at: date)
            positions[node.id] = center
            guard renderPolicy.contains(center, in: size) else { continue }
            let selected = node.id == selectedNodeID
            let focused = cache.selection.isFocused(nodeID: node.id)
            let hovered = node.id == hoveredNodeID
            let dimmed = isDimmed(node, selection: cache.selection)
            let domain = domain(for: node)
            let reindexActive = activeReindexIDs.contains(node.id)
            let reindexKnown = completedReindexIDs.contains(node.id)
            let reindexDimmed = isReindexing && reindexPhase != .planning && !reindexActive && !reindexKnown
            let changeEvent = changeAnimationList.event(forNodeID: node.id, at: date)
            let changeProgress = changeEvent.map { CGFloat($0.easedProgress(elapsed: elapsedChangeTime)) } ?? 1
            let changeOpacity = nodeChangeOpacity(event: changeEvent, nodeID: node.id, progress: changeProgress)
            let changeScale = nodeChangeScale(event: changeEvent, nodeID: node.id, progress: changeProgress)
            let hoverTier = hoverFocus?.nodeTier(for: node.id)
            let confidenceOpacity: Double
            switch node.confidence {
            case 0.8...:
                confidenceOpacity = 1
            case 0.5..<0.8:
                confidenceOpacity = 0.8
            default:
                confidenceOpacity = 0.5
            }
            let baseOpacity = (dimmed || reindexDimmed ? 0.28 : (focused || reindexActive ? 0.96 : 0.76)) * confidenceOpacity
            let visibleOpacity = hoverFocus.map {
                hoverNodeOpacity(base: baseOpacity * changeOpacity, nodeID: node.id, focus: $0, at: date)
            } ?? (baseOpacity * changeOpacity)
            let renderDimmed = hoverFocus != nil
                ? hoverTier == nil
                : (dimmed || reindexDimmed)
            let baseBorderWidth: CGFloat = selected || reindexActive ? 1.8 : (focused || hovered ? 1.2 : 0.7)
            candidateNodes.append(GraphRenderNodeItem(
                id: node.id,
                title: cache.nodeTitles[node.id] ?? node.title,
                center: center,
                size: nodeSize(node) * changeScale,
                layer: node.memoryLayer,
                domain: domain,
                fill: graphFillColor(for: node, domain: domain),
                border: graphBorderColor(
                    for: node,
                    selected: selected || reindexActive || changeEvent != nil,
                    focused: focused,
                    hovered: hovered
                ),
                opacity: visibleOpacity,
                borderWidth: changeEvent != nil ? max(baseBorderWidth, 1.4) : baseBorderWidth,
                dashedBorder: node.confidence < 0.5,
                selected: selected || hovered || reindexActive || changeEvent?.kind == .combination,
                dimmed: renderDimmed,
                showsLabel: shouldShowGraphLabel(for: node, selected: selected, hovered: hovered)
            ))
        }
        let ghostNodes = graphChangeGhostNodes(in: size, at: date)
        let allNodes = separatedGraphNodes(separatedGraphNodes(candidateNodes) + ghostNodes)
        let regularNodes = allNodes.filter { !$0.id.hasPrefix("ghost-") }
        for node in regularNodes {
            positions[node.id] = node.center
        }
        let nodeRadii = Dictionary(uniqueKeysWithValues: regularNodes.map { node in
            (node.id, collisionRadius(for: node))
        })
        let edges = cache.visibleEdges.compactMap { edge -> GraphRenderEdgeItem? in
            guard
                let from = positions[edge.fromID],
                let to = positions[edge.toID]
            else { return nil }
            let touchesActiveReindex = movingReindexIDs.contains(edge.fromID) || movingReindexIDs.contains(edge.toID)
            let baseOpacity = edgeOpacity(edge, nodeMap: cache.nodeMap, selection: cache.selection)
            let hoverEdgePath = hoverFocus?.edgePath(for: edge)
            let hoverEdgeTier = hoverEdgePath?.tier
            let highlightOpacity = max(
                edgeHighlightOpacity(edge, selection: cache.selection, at: date),
                touchesActiveReindex ? min(0.38, GraphRelationshipPolicy.visibleOpacity(forStrength: edge.strength) + 0.08) : 0
            )
            let active = touchesActiveReindex || cache.selection.activeEdgeIDs.contains(edge.id) || highlightOpacity > 0
            let displayedOpacity: Double
            if isReindexing {
                switch reindexPhase {
                case .planning:
                    displayedOpacity = baseOpacity
                case .placingNodes:
                    displayedOpacity = touchesActiveReindex ? max(baseOpacity, 0.16) : max(baseOpacity, 0.08)
                case .auditingPairs:
                    displayedOpacity = max(baseOpacity, 0.08)
                case .sizingNodes:
                    displayedOpacity = baseOpacity
                case .idle:
                    displayedOpacity = baseOpacity
                }
            } else {
                displayedOpacity = baseOpacity
            }
            let reveal = changeAnimationList.edgeRevealMultiplier(edgeID: edge.id, fromID: edge.fromID, toID: edge.toID, at: date)
            return GraphRenderEdgeItem(
                id: edge.id,
                from: from,
                to: to,
                color: edgeColor(edge, nodeMap: cache.nodeMap, selection: cache.selection),
                width: edgeLineWidth(edge, selection: cache.selection),
                fromRadius: nodeRadii[edge.fromID] ?? 0,
                toRadius: nodeRadii[edge.toID] ?? 0,
                opacity: displayedOpacity * reveal,
                highlightOpacity: highlightOpacity * reveal,
                dashed: edge.confidence < 0.58,
                active: active,
                revealStart: hoverEdgePath.flatMap { positions[$0.startNodeID] },
                revealEnd: hoverEdgePath.flatMap { positions[$0.endNodeID] },
                revealStartRadius: hoverEdgePath.flatMap { nodeRadii[$0.startNodeID] },
                revealEndRadius: hoverEdgePath.flatMap { nodeRadii[$0.endNodeID] },
                revealProgress: hoverEdgeTier.map { hoverEdgeRevealProgress(tier: $0, at: date) } ?? 1,
                showsArrow: graphShowEdgeArrows && (active || edge.strength >= 0.78)
            )
        }
        let reindexEdges = reindexOverlayEdges(positions: positions, in: size, at: date)
        return GraphRenderedItems(nodes: allNodes, edges: edges, reindexEdges: reindexEdges, hitNodes: regularNodes)
    }

    private func reindexOverlayEdges(
        positions: [String: CGPoint],
        in size: CGSize,
        at date: Date
    ) -> [GraphReindexOverlayEdgeItem] {
        guard isReindexing else { return [] }
        let nodeRadii = Dictionary(uniqueKeysWithValues: visibleNodes.map { node in
            let selected = node.id == selectedNodeID || node.id == hoveredNodeID
            return (node.id, nodeSize(node) * (selected ? 1.06 : 1) / 2)
        })
        switch reindexPhase {
        case .placingNodes:
            return activeReindexJobs.flatMap { job in
                let progress = job.progress(at: date)
                return job.step.affectedNodeIDs.compactMap { nodeID -> GraphReindexOverlayEdgeItem? in
                    guard let to = positions[nodeID] else { return nil }
                    let from = reindexStartPoint(for: job.step, in: size)
                    return GraphReindexOverlayEdgeItem(
                        id: "move-\(job.id)-\(nodeID)",
                        from: from,
                        to: to,
                        color: HiveColorToken.waxAmberBright.color,
                        opacity: 0.16 + Double(progress) * 0.28,
                        width: 1.4,
                        fromRadius: 0,
                        toRadius: nodeRadii[nodeID] ?? 0,
                        progress: max(0.08, progress),
                        dashed: true
                    )
                }
            }
        case .auditingPairs:
            let cursor = reindexPairAuditProgress
            let chunk = max(1, reindexPairAuditChunkSize)
            let lower = max(0, cursor - chunk * 8)
            let upper = min(reindexAuditPairs.count, cursor + chunk * 2)
            guard lower < upper else { return [] }
            let pulse = CGFloat((date.timeIntervalSince(reindexAuditStartedAt).truncatingRemainder(dividingBy: 0.32)) / 0.32)
            return reindexAuditPairs[lower..<upper].compactMap { pair -> GraphReindexOverlayEdgeItem? in
                guard let from = positions[pair.fromID], let to = positions[pair.toID] else { return nil }
                let isCurrent = pair.index >= max(0, cursor - chunk) && pair.index < cursor + chunk
                let isTested = pair.index < cursor
                let distanceFromCursor = max(0, cursor - pair.index)
                let fade = max(0.12, 1 - Double(distanceFromCursor) / Double(chunk * 8 + 1))
                let acceptedOpacity = pair.accepted ? 0.66 : 0.24
                let color = pair.accepted ? HiveColorToken.waxAmberBright.color : HiveColorToken.nectarMuted.color
                return GraphReindexOverlayEdgeItem(
                    id: pair.id,
                    from: from,
                    to: to,
                    color: color,
                    opacity: (isCurrent ? acceptedOpacity : (isTested ? acceptedOpacity * 0.62 : 0.14)) * fade,
                    width: pair.accepted ? 1.9 : 1.0,
                    fromRadius: nodeRadii[pair.fromID] ?? 0,
                    toRadius: nodeRadii[pair.toID] ?? 0,
                    progress: isCurrent ? max(0.12, pulse) : (isTested ? 1 : 0.18),
                    dashed: !pair.accepted
                )
            }
        case .sizingNodes:
            let elapsed = date.timeIntervalSince(reindexSizingStartedAt)
            return reindexAcceptedAuditEdges.enumerated().compactMap { index, edge -> GraphReindexOverlayEdgeItem? in
                guard let from = positions[edge.fromID], let to = positions[edge.toID] else { return nil }
                let progress = min(1, max(0.06, CGFloat((elapsed - Double(index) * 0.035) / 0.42)))
                return GraphReindexOverlayEdgeItem(
                    id: "accepted-\(edge.id)",
                    from: from,
                    to: to,
                    color: HiveColorToken.waxAmberBright.color,
                    opacity: 0.72,
                    width: 2.1,
                    fromRadius: nodeRadii[edge.fromID] ?? 0,
                    toRadius: nodeRadii[edge.toID] ?? 0,
                    progress: progress,
                    dashed: false
                )
            }
        case .idle, .planning:
            return []
        }
    }

    private func separatedGraphNodes(_ nodes: [GraphRenderNodeItem]) -> [GraphRenderNodeItem] {
        guard nodes.count > 1 else { return nodes }
        var adjusted = nodes
        for _ in 0..<HiveGraphGeometry.hexCollisionResolutionPasses {
            var moved = false
            for firstIndex in adjusted.indices {
                let nextIndex = adjusted.index(after: firstIndex)
                guard nextIndex < adjusted.endIndex else { continue }
                for secondIndex in nextIndex..<adjusted.endIndex {
                    var first = adjusted[firstIndex]
                    var second = adjusted[secondIndex]
                    let minimumDistance = collisionRadius(for: first)
                        + collisionRadius(for: second)
                        + HiveGraphGeometry.minimumHexSeparationPadding
                    let delta = CGPoint(
                        x: second.center.x - first.center.x,
                        y: second.center.y - first.center.y
                    )
                    let distance = hypot(delta.x, delta.y)
                    guard distance < minimumDistance else { continue }
                    let unit: CGPoint
                    if distance > 0.001 {
                        unit = CGPoint(x: delta.x / distance, y: delta.y / distance)
                    } else {
                        unit = deterministicSeparationVector(first.id, second.id)
                    }
                    let displacement = (minimumDistance - max(distance, 0.001)) / 2
                    first.center.x -= unit.x * displacement
                    first.center.y -= unit.y * displacement
                    second.center.x += unit.x * displacement
                    second.center.y += unit.y * displacement
                    adjusted[firstIndex] = first
                    adjusted[secondIndex] = second
                    moved = true
                }
            }
            if !moved { break }
        }
        return adjusted
    }

    private func collisionRadius(for node: GraphRenderNodeItem) -> CGFloat {
        (node.selected ? node.size * 1.06 : node.size) / 2
    }

    private func deterministicSeparationVector(_ firstID: String, _ secondID: String) -> CGPoint {
        let combined = firstID < secondID ? "\(firstID)|\(secondID)" : "\(secondID)|\(firstID)"
        var hash: UInt64 = 14_695_981_039_346_656_037
        for scalar in combined.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash = hash &* 1_099_511_628_211
        }
        let angle = Double(hash % 360) * .pi / 180
        return CGPoint(x: cos(angle), y: sin(angle))
    }

    private func nodeChangeOpacity(event: GraphChangeAnimationEvent?, nodeID: String, progress: CGFloat) -> Double {
        guard let event else { return 1 }
        switch event.kind {
        case .insertion, .split:
            return Double(min(1, max(0, progress)))
        case .combination where event.targetNode?.id == nodeID:
            return 1
        case .movement:
            return 1
        case .deletion, .connectionInsertion, .connectionDeletion, .combination:
            return 1
        }
    }

    private func nodeChangeScale(event: GraphChangeAnimationEvent?, nodeID: String, progress: CGFloat) -> CGFloat {
        guard let event else { return 1 }
        switch event.kind {
        case .insertion, .split:
            return max(0.18, 0.22 + progress * 0.94)
        case .combination where event.targetNode?.id == nodeID:
            return 1 + sin(progress * .pi) * 0.18
        case .movement:
            return 1 + sin(progress * .pi) * 0.06
        case .deletion, .connectionInsertion, .connectionDeletion, .combination:
            return 1
        }
    }

    private func graphChangeGhostNodes(in size: CGSize, at date: Date) -> [GraphRenderNodeItem] {
        let elapsed = changeAnimationList.elapsed(at: date)
        return changeAnimationList.events.compactMap { event -> GraphRenderNodeItem? in
            guard
                event.kind == .deletion || event.kind == .combination,
                let node = event.node,
                let from = event.from,
                let to = event.to
            else { return nil }
            let raw = CGFloat(event.rawProgress(elapsed: elapsed))
            guard raw < 1 else { return nil }
            let progress = CGFloat(event.easedProgress(elapsed: elapsed))
            let center = interpolate(
                from: graphPoint(for: from, in: size),
                to: graphPoint(for: to, in: size),
                progress: progress
            )
            guard renderPolicy.contains(center, in: size) else { return nil }
            let domain = GraphLifeDomainClassifier.domain(for: node)
            let fade = max(0, 1 - raw)
            let scale = event.kind == .combination ? 1 + progress * 0.22 : max(0.08, 1 - progress * 0.72)
            return GraphRenderNodeItem(
                id: "ghost-\(event.id)",
                title: GraphPresentationModel(node: node).title,
                center: center,
                size: nodeSize(node) * scale,
                layer: node.memoryLayer,
                domain: domain,
                fill: graphFillColor(for: node, domain: domain),
                border: HiveColorToken.waxAmber.color,
                opacity: Double(fade) * 0.72,
                borderWidth: 1.2,
                dashedBorder: node.confidence < 0.5,
                selected: event.kind == .combination,
                dimmed: false,
                showsLabel: event.kind == .combination
            )
        }
    }

    private func renderSnapshot(in size: CGSize, cache: GraphDisplayCache) -> HiveGraphRenderSnapshot {
        let rendered = renderItems(in: size, cache: cache)
        return HiveGraphRenderSnapshot(
            zoomLevel: zoomLevel,
            renderedNodeCount: rendered.nodes.count,
            renderedEdgeCount: rendered.edges.count,
            selectedNodeID: selectedNodeID,
            culledNodeCount: max(0, cache.visibleNodes.count - rendered.nodes.count),
            culledEdgeCount: max(0, cache.visibleEdges.count - rendered.edges.count)
        )
    }
}

private struct GraphRenderedItems {
    var nodes: [GraphRenderNodeItem]
    var edges: [GraphRenderEdgeItem]
    var reindexEdges: [GraphReindexOverlayEdgeItem]
    var hitNodes: [GraphRenderNodeItem]
}

private struct GraphTrackpadPanEvent {
    var delta: CGSize
    var timestamp: TimeInterval
    var isMomentum: Bool
    var ended: Bool
}

#if os(macOS)
private struct GraphTrackpadPanMonitor: NSViewRepresentable {
    var onPan: (GraphTrackpadPanEvent) -> Void

    func makeNSView(context: Context) -> GraphTrackpadPanNSView {
        let view = GraphTrackpadPanNSView()
        view.onPan = onPan
        return view
    }

    func updateNSView(_ nsView: GraphTrackpadPanNSView, context: Context) {
        nsView.onPan = onPan
    }

    final class GraphTrackpadPanNSView: NSView {
        var onPan: ((GraphTrackpadPanEvent) -> Void)?
        nonisolated(unsafe) private var monitor: Any?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = false
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                    self.monitor = nil
                }
            } else {
                installMonitorIfNeeded()
            }
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, self.shouldHandle(event) else { return event }
                self.handle(event)
                return nil
            }
        }

        private func shouldHandle(_ event: NSEvent) -> Bool {
            guard let window, event.window === window else { return false }
            let location = convert(event.locationInWindow, from: nil)
            return bounds.contains(location)
        }

        private func handle(_ event: NSEvent) {
            let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
            let delta = CGSize(
                width: event.scrollingDeltaX * multiplier,
                height: -event.scrollingDeltaY * multiplier
            )
            let phaseEnded = event.phase.contains(.ended) || event.phase.contains(.cancelled)
            let momentumEnded = event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled)
            onPan?(
                GraphTrackpadPanEvent(
                    delta: delta,
                    timestamp: event.timestamp,
                    isMomentum: event.momentumPhase != [],
                    ended: phaseEnded || momentumEnded
                )
            )
        }
    }
}
#endif

private struct GraphContinuousHoverModifier: ViewModifier {
    var onActive: (CGPoint) -> Void
    var onEnded: () -> Void

    func body(content: Content) -> some View {
        content.onContinuousHover { phase in
            switch phase {
            case .active(let point):
                onActive(point)
            case .ended:
                onEnded()
            }
        }
    }
}

private struct GraphRenderNodeItem: Identifiable {
    var id: String
    var title: String
    var center: CGPoint
    var size: CGFloat
    var layer: MemoryNodeLayer
    var domain: LifeDomain
    var fill: Color
    var border: Color
    var opacity: Double
    var borderWidth: CGFloat
    var dashedBorder: Bool
    var selected: Bool
    var dimmed: Bool
    var showsLabel: Bool
}

private struct GraphRenderEdgeItem: Identifiable {
    var id: String
    var from: CGPoint
    var to: CGPoint
    var color: Color
    var width: CGFloat
    var fromRadius: CGFloat
    var toRadius: CGFloat
    var opacity: Double
    var highlightOpacity: Double
    var dashed: Bool
    var active: Bool
    var revealStart: CGPoint?
    var revealEnd: CGPoint?
    var revealStartRadius: CGFloat?
    var revealEndRadius: CGFloat?
    var revealProgress: CGFloat
    var showsArrow: Bool

    var litFrom: CGPoint {
        litEndpoints.from
    }

    var litTo: CGPoint {
        litEndpoints.to
    }

    var litPath: Path {
        var path = Path()
        path.move(to: litFrom)
        path.addLine(to: litTo)
        return path
    }

    var fullPath: Path {
        var path = Path()
        let endpoints = GraphEdgeGeometry.trimmedLine(
            from: from,
            to: to,
            startInset: fromRadius + GraphEdgeGeometry.endpointGap + width * 0.5,
            endInset: toRadius + GraphEdgeGeometry.endpointGap + width * 0.5
        )
        path.move(to: endpoints.from)
        path.addLine(to: endpoints.to)
        return path
    }

    private var litEndpoints: (from: CGPoint, to: CGPoint) {
        let start = revealStart ?? from
        let end = revealEnd ?? to
        let endpoints = GraphEdgeGeometry.trimmedLine(
            from: start,
            to: end,
            startInset: (revealStartRadius ?? fromRadius) + GraphEdgeGeometry.endpointGap + width * 0.5,
            endInset: (revealEndRadius ?? toRadius) + GraphEdgeGeometry.endpointGap + width * 0.5
        )
        let progress = min(1, max(0, revealProgress))
        return (
            endpoints.from,
            CGPoint(
                x: endpoints.from.x + (endpoints.to.x - endpoints.from.x) * progress,
                y: endpoints.from.y + (endpoints.to.y - endpoints.from.y) * progress
            )
        )
    }
}

private struct GraphReindexAuditPair: Identifiable, Hashable {
    var index: Int
    var fromID: String
    var toID: String
    var accepted: Bool

    var id: String {
        "audit-pair-\(index)-\(fromID)-\(toID)"
    }
}

private struct GraphReindexOverlayEdgeItem: Identifiable {
    var id: String
    var from: CGPoint
    var to: CGPoint
    var color: Color
    var opacity: Double
    var width: CGFloat
    var fromRadius: CGFloat
    var toRadius: CGFloat
    var progress: CGFloat
    var dashed: Bool

    var path: Path {
        var path = Path()
        let endpoints = GraphEdgeGeometry.trimmedLine(
            from: from,
            to: to,
            startInset: fromRadius + GraphEdgeGeometry.endpointGap + width * 0.5,
            endInset: toRadius + GraphEdgeGeometry.endpointGap + width * 0.5
        )
        path.move(to: endpoints.from)
        let boundedProgress = min(1, max(0, progress))
        let litTo = CGPoint(
            x: endpoints.from.x + (endpoints.to.x - endpoints.from.x) * boundedProgress,
            y: endpoints.from.y + (endpoints.to.y - endpoints.from.y) * boundedProgress
        )
        path.addLine(to: litTo)
        return path
    }
}

private enum GraphEdgeGeometry {
    static let endpointGap: CGFloat = 2.5

    static func trimmedLine(
        from start: CGPoint,
        to end: CGPoint,
        startInset: CGFloat,
        endInset: CGFloat
    ) -> (from: CGPoint, to: CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0.001 else { return (start, start) }
        let boundedStartInset = max(0, min(startInset, length / 2))
        let boundedEndInset = max(0, min(endInset, max(0, length - boundedStartInset)))
        guard boundedStartInset + boundedEndInset < length else {
            let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            return (midpoint, midpoint)
        }
        let unit = CGPoint(x: dx / length, y: dy / length)
        return (
            CGPoint(x: start.x + unit.x * boundedStartInset, y: start.y + unit.y * boundedStartInset),
            CGPoint(x: end.x - unit.x * boundedEndInset, y: end.y - unit.y * boundedEndInset)
        )
    }
}

private struct GraphReindexJob: Identifiable, Hashable {
    static let maximumConcurrentJobs = 4

    var step: GraphReindexStep
    var planIndex: Int
    var slot: Int
    var startedAt: Date
    var duration: TimeInterval

    var id: String {
        "\(step.id)-\(planIndex)"
    }

    func progress(at date: Date) -> CGFloat {
        guard duration > 0 else { return 1 }
        let raw = min(1, max(0, date.timeIntervalSince(startedAt) / duration))
        let eased = raw * raw * (3 - 2 * raw)
        return CGFloat(eased)
    }
}

private enum GraphReindexPhase: Hashable {
    case idle
    case planning
    case placingNodes
    case auditingPairs
    case sizingNodes
}

private struct GraphReindexSyntheticNode: Identifiable {
    var id: String
    var center: CGPoint
    var size: CGFloat
    var fill: Color
    var border: Color
}

private enum HiveGraphVisualStyle {
    static let backgroundFillOpacityDark: Double = 1
    static let backgroundFillOpacityLight: Double = 0.88
    static let inactiveEdgeOpacityMultiplier: Double = 0.54
    static let activeEdgeOpacityMultiplier: Double = 1.28
    static let detailCoreRatio: CGFloat = 0.34
    static let hubCoreRatio: CGFloat = 0.43
    static let labelHaloOpacity: Double = 0.18
    static let hubLabelLimit = 14
}

private struct GraphReindexSyntheticHoneycomb: View {
    var node: GraphReindexSyntheticNode
    var trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        HexagonShape()
            .fill(node.fill.opacity(0.88))
        .frame(width: node.size, height: node.size)
        .scaleEffect(visible ? 1 : 0.28)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false)
        .onAppear { animateIn() }
        .onChange(of: trigger) { _, _ in animateIn() }
        .accessibilityHidden(true)
    }

    private func animateIn() {
        guard !reduceMotion else {
            visible = true
            return
        }
        visible = false
        withAnimation(HiveMotion.formation) {
            visible = true
        }
    }
}

private struct GraphAtmosphereLayer: View {
    var nodes: [GraphRenderNodeItem]
    var edges: [GraphRenderEdgeItem]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            fillBackground(bounds: bounds, size: size, in: &context)

            for edge in edges where edge.active && edge.highlightOpacity > 0.2 {
                context.stroke(
                    edge.litPath,
                    with: .color(edge.color.opacity(edge.highlightOpacity * 0.12)),
                    style: StrokeStyle(lineWidth: edge.width + 7.0, lineCap: .butt)
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func fillBackground(bounds: CGRect, size: CGSize, in context: inout GraphicsContext) {
        var background = Path()
        background.addRect(bounds)
        let base = HiveColorToken.backgroundDeep.color.opacity(
            colorScheme == .dark
                ? HiveGraphVisualStyle.backgroundFillOpacityDark
                : HiveGraphVisualStyle.backgroundFillOpacityLight
        )
        let mid = HiveColorToken.backgroundMid.color.opacity(colorScheme == .dark ? 0.92 : 0.86)
        context.fill(
            background,
            with: .linearGradient(
                Gradient(colors: [base, mid, base]),
                startPoint: CGPoint(x: size.width * 0.14, y: 0),
                endPoint: CGPoint(x: size.width * 0.92, y: size.height)
            )
        )
    }
}

private struct GraphRenderLayer: View {
    var nodes: [GraphRenderNodeItem]
    var edges: [GraphRenderEdgeItem]
    var reindexEdges: [GraphReindexOverlayEdgeItem]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, _ in
            for edge in edges {
                context.stroke(
                    edge.fullPath,
                    with: .color(edge.color.opacity(edge.opacity * HiveGraphVisualStyle.inactiveEdgeOpacityMultiplier)),
                    style: StrokeStyle(lineWidth: max(0.45, edge.width * 0.72), lineCap: .butt, dash: edge.dashed ? [5, 5] : [])
                )
                if edge.highlightOpacity > 0.01 {
                    context.stroke(
                        edge.litPath,
                        with: .color(edge.color.opacity(min(1, edge.highlightOpacity * HiveGraphVisualStyle.activeEdgeOpacityMultiplier))),
                        style: StrokeStyle(lineWidth: edge.width, lineCap: .butt, dash: edge.dashed ? [5, 5] : [])
                    )
                }
                if edge.showsArrow && edge.highlightOpacity > 0.24 {
                    drawArrowhead(edge, in: &context)
                }
            }
            for edge in reindexEdges {
                context.stroke(
                    edge.path,
                    with: .color(edge.color.opacity(edge.opacity)),
                    style: StrokeStyle(lineWidth: edge.width, lineCap: .butt, dash: edge.dashed ? [4, 4] : [])
                )
            }
            for node in nodes where !node.selected {
                drawNode(node, in: &context)
            }
            for node in nodes where node.selected {
                drawNode(node, in: &context)
            }
            for node in labeledNodes(from: nodes) {
                drawLabel(for: node, in: &context)
            }
        }
    }

    private func labeledNodes(from nodes: [GraphRenderNodeItem]) -> [GraphRenderNodeItem] {
        Array(nodes
            .filter { $0.showsLabel && !$0.dimmed && $0.opacity > 0.32 }
            .sorted {
                if $0.selected != $1.selected { return $0.selected && !$1.selected }
                return $0.size > $1.size
            }
            .prefix(HiveGraphVisualStyle.hubLabelLimit))
    }

    private func drawNode(_ node: GraphRenderNodeItem, in context: inout GraphicsContext) {
        let size = node.selected ? node.size * 1.06 : node.size
        let rect = CGRect(
            x: node.center.x - size / 2,
            y: node.center.y - size / 2,
            width: size,
            height: size
        )
        let path = HexagonShape().path(in: rect)
        let maskColor = colorScheme == .dark
            ? HiveColorToken.backgroundDeep.color
            : HiveColorToken.backgroundMid.color
        context.fill(path, with: .color(maskColor))
        context.fill(path, with: .color(node.fill.opacity(node.opacity)))
    }

    private func drawArrowhead(_ edge: GraphRenderEdgeItem, in context: inout GraphicsContext) {
        let dx = edge.litTo.x - edge.litFrom.x
        let dy = edge.litTo.y - edge.litFrom.y
        let length = max(1, hypot(dx, dy))
        let unit = CGPoint(x: dx / length, y: dy / length)
        let normal = CGPoint(x: -unit.y, y: unit.x)
        let tip = CGPoint(
            x: edge.litTo.x - unit.x * 12,
            y: edge.litTo.y - unit.y * 12
        )
        let arrowLength: CGFloat = edge.active ? 9 : 7
        let arrowWidth: CGFloat = edge.active ? 4.2 : 3.2
        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(
            x: tip.x - unit.x * arrowLength + normal.x * arrowWidth,
            y: tip.y - unit.y * arrowLength + normal.y * arrowWidth
        ))
        arrow.addLine(to: CGPoint(
            x: tip.x - unit.x * arrowLength - normal.x * arrowWidth,
            y: tip.y - unit.y * arrowLength - normal.y * arrowWidth
        ))
        arrow.closeSubpath()
        context.fill(
            arrow,
            with: .color(edge.color.opacity(edge.active ? min(1, edge.highlightOpacity) : edge.opacity * 0.58))
        )
    }

    private func drawLabel(for node: GraphRenderNodeItem, in context: inout GraphicsContext) {
        let label = clippedLabel(node.title)
        guard !label.isEmpty else { return }
        let width = min(178, max(58, CGFloat(label.count) * 6.0 + 18))
        let height: CGFloat = 21
        let rect = CGRect(
            x: node.center.x - width / 2,
            y: node.center.y + node.size * 0.5 + 7,
            width: width,
            height: height
        )
        context.fill(
            RoundedRectangle(cornerRadius: HiveRadius.sm, style: .continuous).path(in: rect),
            with: .color(HiveColorToken.backgroundMid.color.opacity(node.selected ? 0.88 : 0.58))
        )
        context.stroke(
            RoundedRectangle(cornerRadius: HiveRadius.sm, style: .continuous).path(in: rect),
            with: .color(node.border.opacity(node.selected ? 0.42 : 0.16)),
            lineWidth: 0.6
        )
        context.draw(
            Text(label)
                .font(HiveTypography.hiveMeta)
                .tracking(0.2)
                .foregroundStyle(node.selected ? HiveColorToken.nectarText.color : HiveColorToken.nectarMuted.color),
            at: CGPoint(x: rect.midX, y: rect.midY),
            anchor: .center
        )
    }

    private func clippedLabel(_ title: String) -> String {
        let cleaned = SourcePresentationModel.cleanTitle(title)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 30 else { return cleaned }
        return String(cleaned.prefix(27)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

private struct GraphReindexStatusLine: View {
    var text: String
    var step: Int
    var total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                HiveSymbol(.runMaintenance, size: 14, active: true, motion: .pulse, motionValue: step)
                HiveText(text, role: .scaffoldBody)
                    .lineLimit(1)
                Spacer(minLength: 8)
                HiveText("\(step)/\(total)", role: .scaffoldMicro)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(HiveColorToken.scaffoldFaint.color.opacity(0.55))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(HiveColorToken.waxAmber.color.opacity(0.82))
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text), \(step) of \(total)")
    }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return min(1, max(0, CGFloat(step) / CGFloat(total)))
    }
}

private struct GraphControlGroup<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .labelStyle(.titleAndIcon)
    }
}

private struct GraphSectionTabs: View {
    @Binding var selection: GraphInstrumentSection

    var body: some View {
        HStack(spacing: 4) {
            ForEach(GraphInstrumentSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(HiveMotion.focus) {
                        selection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(HiveTypography.hiveMeta)
                        .foregroundStyle(selection == section ? HiveColorToken.nectarText.color : HiveColorToken.nectarMuted.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.sm, style: .continuous)
                                .fill(selection == section ? HiveColorToken.waxAmber.color.opacity(0.16) : Color.clear)
                        )
                }
                .buttonStyle(HiveControlPressStyle())
            }
        }
        .padding(3)
        .background(HiveColorToken.backgroundMid.color.opacity(0.72), in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))
    }
}

private struct GraphToggleRow: View {
    var title: String
    var detail: String
    var symbol: HiveSymbolName
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                HiveSymbol(symbol, size: 14, active: isOn)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(HiveTypography.hiveCaption)
                        .foregroundStyle(HiveColorToken.nectarText.color)
                    Text(detail)
                        .font(HiveTypography.hiveMeta)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(isOn ? "On" : "Off")
                    .font(HiveTypography.hiveMeta)
                    .foregroundStyle(isOn ? HiveColorToken.waxAmberBright.color : HiveColorToken.scaffoldGray.color)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 7)
                    .background(HiveColorToken.backgroundMid.color.opacity(0.74), in: Capsule())
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous)
                    .fill(isOn ? HiveColorToken.waxAmber.color.opacity(0.08) : HiveColorToken.backgroundMid.color.opacity(0.42))
            )
        }
        .buttonStyle(HiveControlPressStyle())
    }
}

private struct GraphMetricLine: View {
    var title: String
    var detail: String

    var body: some View {
        HStack {
            Text(title)
                .font(HiveTypography.hiveMeta)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
            Spacer()
            Text(detail)
                .font(HiveTypography.hiveMeta)
                .foregroundStyle(HiveColorToken.scaffoldGray.color)
        }
        .padding(.horizontal, 4)
    }
}

private struct GraphDomainChip: View {
    var title: String
    var count: Int
    var color: Color
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                HexagonShape()
                    .fill(color.opacity(active ? 0.95 : 0.54))
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(HiveTypography.hiveMeta)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(count)")
                    .font(HiveTypography.hiveMeta)
                    .foregroundStyle(HiveColorToken.scaffoldGray.color)
            }
            .foregroundStyle(active ? HiveColorToken.nectarText.color : HiveColorToken.nectarMuted.color)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.sm, style: .continuous)
                    .fill(active ? color.opacity(0.16) : HiveColorToken.backgroundMid.color.opacity(0.46))
            )
        }
        .buttonStyle(HiveControlPressStyle())
    }
}

private struct GraphSmallChip: View {
    var title: String
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HiveTypography.hiveMeta)
                .foregroundStyle(active ? HiveColorToken.nectarText.color : HiveColorToken.nectarMuted.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.sm, style: .continuous)
                        .fill(active ? HiveColorToken.waxAmber.color.opacity(0.16) : HiveColorToken.backgroundMid.color.opacity(0.46))
                )
        }
        .buttonStyle(HiveControlPressStyle())
    }
}

private struct GraphCompactSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(HiveTypography.hiveMeta)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(HiveTypography.hiveMeta)
                    .foregroundStyle(HiveColorToken.scaffoldGray.color)
            }
            Slider(value: $value, in: range)
                .tint(HiveColorToken.waxAmber.color)
        }
    }
}

private struct GraphInstrumentHexToggle: View {
    var accessibilityLabel: String
    var active: Bool
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HiveSymbol(
                .hiveGraph,
                size: 16,
                weight: .bold,
                active: active || isHovered,
                rendering: active || isHovered ? .primaryAction : .hierarchical
            )
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: HiveLayoutMetrics.smallCornerRadius, style: .continuous)
                    .fill(HiveColorToken.waxAmber.color.opacity(active || isHovered ? 0.22 : 0.1))
            )
            .contentShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.smallCornerRadius, style: .continuous))
        }
        .buttonStyle(HiveControlPressStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Toggles the Hive controls.")
        .help(accessibilityLabel)
        .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.045 : 1))
        .onHover { hovering in
            guard !reduceMotion else { return }
            withAnimation(HiveMotion.focus) { isHovered = hovering }
        }
    }
}

private struct GraphInstrumentButton: View {
    var title: String
    var symbol: HiveSymbolName
    var active: Bool
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .font(HiveTypography.chromeBodyEmphasized)
                    .lineLimit(1)
                    .minimumScaleFactor(0.92)
                    .fixedSize(horizontal: true, vertical: false)
            } icon: {
                HiveSymbol(symbol, size: 16, active: active || isHovered, motion: active ? .pulse : .none, motionValue: active ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 38)
            .background(
                RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous)
                    .fill(active ? HiveColorToken.waxAmber.color.opacity(isHovered ? 0.22 : 0.16) : HiveColorToken.nectarText.color.opacity(isHovered ? 0.07 : 0.0))
            )
            .contentShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous))
        }
        .controlSize(.regular)
        .buttonStyle(HiveControlPressStyle())
        .tint(active ? HiveColorToken.waxAmberBright.color : HiveColorToken.scaffoldGray.color)
        .accessibilityLabel(title)
        .accessibilityHint(HiveHIGPolicy.accessibilityHint(for: title))
        .animation(HiveMotion.focus, value: active)
        .onHover { hovering in
            guard !reduceMotion else { return }
            withAnimation(HiveMotion.focus) { isHovered = hovering }
        }
    }
}

public enum HiveSemanticZoomLevel: String, Sendable {
    case colony
    case cluster
    case detail
}

private struct GraphDisplayCache {
    var displayNodes: [GraphNodeRecord]
    var displayEdges: [GraphEdgeRecord]
    var nodeMap: [String: GraphNodeRecord]
    var selection: GraphSelectionModel
    var visibleNodes: [GraphNodeRecord]
    var visibleEdges: [GraphEdgeRecord]
    var nodeTitles: [String: String]
}

private struct GraphHoverFocusModel {
    var rootID: String
    var firstNodeIDs: Set<String>
    var secondNodeIDs: Set<String>
    var firstEdgeIDs: Set<String>
    var secondEdgeIDs: Set<String>

    func nodeTier(for nodeID: String) -> Int? {
        if nodeID == rootID { return 0 }
        if firstNodeIDs.contains(nodeID) { return 1 }
        if secondNodeIDs.contains(nodeID) { return 2 }
        return nil
    }

    func edgeTier(for edgeID: String) -> Int? {
        if firstEdgeIDs.contains(edgeID) { return 1 }
        if secondEdgeIDs.contains(edgeID) { return 2 }
        return nil
    }

    func edgePath(for edge: GraphEdgeRecord) -> GraphHoverEdgePath? {
        guard let tier = edgeTier(for: edge.id),
              let fromTier = nodeTier(for: edge.fromID),
              let toTier = nodeTier(for: edge.toID),
              abs(fromTier - toTier) == 1 else {
            return nil
        }
        let startNodeID = fromTier < toTier ? edge.fromID : edge.toID
        let endNodeID = fromTier < toTier ? edge.toID : edge.fromID
        return GraphHoverEdgePath(tier: tier, startNodeID: startNodeID, endNodeID: endNodeID)
    }
}

private struct GraphHoverEdgePath {
    var tier: Int
    var startNodeID: String
    var endNodeID: String
}

private enum GraphHoverTiming {
    static let dimDuration: TimeInterval = 1.65
    static let firstNodeDelay: TimeInterval = 0.42
    static let firstNodeDuration: TimeInterval = 0.98
    static let secondNodeDelay: TimeInterval = 1.2
    static let secondNodeDuration: TimeInterval = 1.12
    static let firstEdgeDelay: TimeInterval = 0.04
    static let firstEdgeDuration: TimeInterval = 1.12
    static let secondEdgeDelay: TimeInterval = 1.02
    static let secondEdgeDuration: TimeInterval = 1.18
    static let totalPlaybackDuration: TimeInterval = max(
        dimDuration,
        firstNodeDelay + firstNodeDuration,
        secondNodeDelay + secondNodeDuration,
        firstEdgeDelay + firstEdgeDuration,
        secondEdgeDelay + secondEdgeDuration
    ) + 0.25
}

private struct GraphNodeHex: View {
    var node: GraphNodeRecord
    var domain: LifeDomain
    var selected: Bool
    var focused: Bool
    var hovered: Bool
    var zoomLevel: HiveSemanticZoomLevel
    var searchMatched: Bool
    var dimmed: Bool
    var newlyFormed: Bool
    var formationGeneration: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var formed = true

    var body: some View {
        ZStack {
            HexagonShape()
                .fill(nodeFill.opacity(dimmed ? 0.3 : fillOpacity))
            if labelVisible {
                HiveText(GraphPresentationModel(node: node).title, role: .scaffoldLabel)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.55)
                    .lineLimit(2)
                    .padding(8)
                    .offset(y: labelOffset)
            }
        }
        .scaleEffect(formed ? 1 : 0.04)
        .scaleEffect(selected ? 1.06 : (hovered ? 1.04 : 1))
        .opacity(dimmed ? 0.36 : 1)
        .animation(HiveMotion.standard, value: dimmed)
        .animation(HiveMotion.focus, value: selected)
        .animation(HiveMotion.focus, value: hovered)
        .onAppear {
            if newlyFormed {
                runFormation()
            }
        }
        .onChange(of: formationGeneration) { _, _ in
            if newlyFormed {
                runFormation()
            }
        }
    }

    private var labelOffset: CGFloat {
        max(14, HiveGraphGeometry.hexSize(for: node, selected: selected) * 0.72 + 10)
    }

    private func runFormation() {
        guard !reduceMotion else {
            formed = true
            return
        }
        formed = false
        withAnimation(HiveMotion.formation) {
            formed = true
        }
    }

    private var labelVisible: Bool {
        searchMatched
    }

    private var nodeFill: Color {
        if isIncidental {
            return HiveColorToken.scaffoldFaint.color
        }
        if domain == .projects {
            return HiveColorToken.sealed.color
        }
        return HiveColorToken.waxAmber.color
    }

    private var fillOpacity: Double {
        if selected || isImportant { return 1 }
        if isIncidental { return 0.5 }
        return focused ? 0.92 : 0.7
    }

    private var isImportant: Bool {
        node.memoryLayer == .importantTrait || node.memoryLayer == .definingTrait
    }

    private var isIncidental: Bool {
        node.memoryLayer == .detail && node.confidence < 0.48
    }
}

private struct GraphToolbarIconButton: View {
    var title: String
    var symbol: HiveSymbolName
    var active: Bool
    var disabled: Bool
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    init(
        title: String,
        symbol: HiveSymbolName,
        active: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.active = active
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HiveSymbol(
                symbol,
                size: 15,
                active: active || isHovered,
                motion: active ? .pulse : .none,
                motionValue: active ? 1 : 0
            )
            .frame(width: 32, height: 32)
            .background(toolbarControlBackground)
            .contentShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(HiveControlPressStyle())
        .tint(active ? HiveColorToken.waxAmberBright.color : HiveColorToken.scaffoldGray.color)
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
        .accessibilityLabel(title)
        .accessibilityHint(HiveHIGPolicy.accessibilityHint(for: title))
        .help(title)
        .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.035 : 1))
        .animation(HiveMotion.focus, value: active)
        .onHover { hovering in
            guard !reduceMotion, !disabled else { return }
            withAnimation(HiveMotion.focus) { isHovered = hovering }
        }
    }

    private var toolbarControlBackground: some View {
        RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous)
            .fill(active ? HiveColorToken.waxAmber.color.opacity(isHovered ? 0.22 : 0.16) : HiveColorToken.nectarText.color.opacity(isHovered ? 0.07 : 0.0))
    }
}

private struct GraphMenuLabel: View {
    var title: String
    var symbol: HiveSymbolName

    init(_ title: String, symbol: HiveSymbolName) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: HiveSpacing.sm) {
            HiveSymbol(symbol, size: 14)
            Text(title)
        }
    }
}

private struct GraphMenuMetricLabel: View {
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: HiveSpacing.sm) {
            Text(title)
            Spacer(minLength: HiveSpacing.lg)
            Text(detail)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
        }
    }
}

private struct GraphInstrumentMenu<Content: View>: View {
    var title: String
    var symbol: HiveSymbolName
    var active: Bool
    var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    init(
        title: String,
        symbol: HiveSymbolName,
        active: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.active = active
        self.content = content
    }

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: HiveSpacing.sm) {
                HiveSymbol(symbol, size: 15, active: true, motion: active ? .pulse : .none, motionValue: active ? 1 : 0)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous)
                            .fill(HiveColorToken.waxAmber.color.opacity(active || isHovered ? 0.2 : 0.13))
                    )

                HiveText(title, role: .scaffoldAction)
                    .lineLimit(1)

                Spacer(minLength: HiveSpacing.xs)

                HiveSymbol(.disclosure, size: 10, active: active || isHovered)
                    .rotationEffect(.degrees(isHovered && !reduceMotion ? 2 : 0))
                    .opacity(active || isHovered ? 1 : 0.72)
            }
            .padding(.horizontal, HiveSpacing.sm)
            .frame(height: HiveHIGPolicy.minimumGraphAccessibilityTarget)
            .frame(maxWidth: .infinity, minHeight: HiveHIGPolicy.minimumGraphAccessibilityTarget)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous)
                    .fill(active ? HiveColorToken.waxAmber.color.opacity(isHovered ? 0.22 : 0.16) : HiveColorToken.raisedSurface.color.opacity(isHovered ? 0.94 : 0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous)
                    .stroke(HiveColorToken.waxAmber.color.opacity(isHovered || active ? 0.18 : 0.09), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(HiveControlPressStyle())
        .tint(HiveColorToken.waxAmberBright.color)
        .accessibilityLabel(title)
        .accessibilityHint("Opens Hive actions as a vertical menu.")
        .help(title)
        .shadow(color: HiveColorToken.backgroundDeep.color.opacity(isHovered ? 0.24 : 0.16), radius: isHovered ? 14 : 10, x: 0, y: isHovered ? 8 : 5)
        .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.012 : 1))
        .onHover { hovering in
            guard !reduceMotion else { return }
            withAnimation(HiveMotion.focus) { isHovered = hovering }
        }
    }
}

private struct GraphHoverPlaque: View {
    var node: GraphNodeRecord
    var domain: LifeDomain
    var relatedEntries: [GraphNodeRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HiveText(GraphPresentationModel(node: node).title, role: .nectarBody)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if relatedLabels.isEmpty {
                relatedChip(domain.label, color: domain.graphColor)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(relatedLabels, id: \.self) { label in
                        relatedChip(label, color: domain.graphColor)
                    }
                }
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(HiveColorToken.raisedSurface.color.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.2), radius: 12, x: 0, y: 8)
        .allowsHitTesting(false)
    }

    private var relatedLabels: [String] {
        relatedEntries
            .sorted(by: graphEntryImportanceSort)
            .map { GraphPresentationModel(node: $0).title }
            .filter { !$0.isEmpty }
            .prefixArray(3)
    }

    private func relatedChip(_ title: String, color: Color) -> some View {
        HiveText(title, role: .scaffoldLabel)
            .lineLimit(1)
            .padding(.vertical, 4)
            .padding(.horizontal, 7)
            .background(HiveColorToken.cellSurface.color.opacity(0.68), in: Capsule())
            .foregroundStyle(HiveColorToken.nectarText.color)
    }
}

private struct StraightGraphEdge: View {
    var from: CGPoint
    var to: CGPoint
    var color: Color
    var width: CGFloat
    var active: Bool
    var newlyFormed: Bool
    var revealTrigger: Int
    var confidence: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = true

    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .trim(from: 0, to: revealed ? 1 : 0)
        .stroke(color.opacity(active ? 0.95 : 0.62), style: StrokeStyle(lineWidth: width, lineCap: .butt, dash: confidence < 0.58 ? [5, 5] : []))
        .animation(reduceMotion ? nil : (newlyFormed ? HiveMotion.welcome : HiveMotion.reveal), value: revealed)
        .onAppear {
            if newlyFormed && !reduceMotion {
                revealed = false
                DispatchQueue.main.async {
                    revealed = true
                }
            }
        }
        .onChange(of: revealTrigger) { _, _ in
            guard newlyFormed && !reduceMotion else {
                revealed = true
                return
            }
            revealed = false
            DispatchQueue.main.async {
                revealed = true
            }
        }
    }
}

private struct GraphExplainPanel: View {
    var node: GraphNodeRecord
    var domain: LifeDomain
    var connected: [GraphNodeRecord]
    var onOpenWiki: () -> Void
    var onAsk: (String) -> Void
    var onMarkImportant: () -> Void
    var onMarkIncidental: () -> Void
    var onConfirmPlacement: (Double, Double) -> Void
    var onSelectConnected: (String) -> Void
    var onClose: () -> Void
    @State private var correctionX: Double = 0
    @State private var correctionY: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.lg) {
            HStack(alignment: .top) {
                Text(GraphPresentationModel(node: node).title)
                    .font(HiveTypography.hiveTitle)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .tracking(0)
                    .lineLimit(4)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Menu {
                    Button {
                        onOpenWiki()
                    } label: {
                        GraphMenuLabel("Open in Colony", symbol: .openWiki)
                    }
                    Button {
                        onMarkImportant()
                    } label: {
                        GraphMenuLabel("Mark important", symbol: .markImportant)
                    }
                    Button {
                        onMarkIncidental()
                    } label: {
                        GraphMenuLabel("Mark incidental", symbol: .markIncidental)
                    }
                } label: {
                    HiveSymbol(.ellipsis, size: 18, active: true)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Memory actions")
                }
                .buttonStyle(.plain)
                HiveSymbolButton(.close, title: nil, compact: true, action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            relatedChip(domain.label, color: domain.graphColor)
            HiveContextAskSurface(
                title: "Ask about this memory",
                placeholder: "Ask why it matters or what connects"
            ) { question in
                onAsk(question)
            }
            if node.confidence < 0.5 {
                placementCorrection
            }
            relatedColonyEntries
            Spacer(minLength: 0)
        }
        .padding(.top, HiveSpacing.xl)
        .padding(.horizontal, HiveSpacing.xl)
        .padding(.bottom, HiveSpacing.lg)
        .background(HiveColorToken.backgroundMid.color.opacity(0.96))
        .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.42), radius: 22, x: 0, y: 14)
        .onAppear(perform: syncCorrectionValues)
        .onChange(of: node.id) { _, _ in syncCorrectionValues() }
    }

    private var titleSize: CGFloat {
        let count = GraphPresentationModel(node: node).title.count
        if count > 110 { return 24 }
        if count > 72 { return 28 }
        return 34
    }

    private var relatedColonyEntries: some View {
        VStack(alignment: .leading, spacing: 10) {
            HiveText("Related Colony entries", role: .scaffoldLabel)
            if importantConnections.isEmpty {
                HiveText("No related Colony entry yet.", role: .nectarBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
            } else {
                VStack(spacing: HiveSpacing.sm) {
                    ForEach(importantConnections) { item in
                        let itemDomain = GraphLifeDomainClassifier.domain(for: item)
                        Button {
                            onSelectConnected(item.id)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HiveText(GraphPresentationModel(node: item).title, role: .nectarBody)
                                        .lineLimit(2)
                                    HiveText(itemDomain.label, role: .scaffoldLabel)
                                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(HiveColorToken.raisedSurface.color.opacity(0.52), in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var placementCorrection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            HStack(spacing: HiveSpacing.sm) {
                HiveSymbol(.showGraph, size: 14, active: true)
                HiveText("Confirm placement", role: .scaffoldLabel)
            }
            axisSlider("Creative", "Analytical", value: $correctionX)
            axisSlider("Personal", "Professional", value: $correctionY)
            HiveActionButton("Save placement", symbol: .confirmed) {
                onConfirmPlacement(correctionX, correctionY)
            }
        }
        .padding(HiveSpacing.md)
        .background(HiveColorToken.cellSurface.color.opacity(0.72), in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))
    }

    private func axisSlider(_ leading: String, _ trailing: String, value: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            Slider(value: value, in: -1...1)
                .tint(HiveColorToken.waxAmber.color)
            HStack {
                HiveText(leading, role: .scaffoldLabel)
                Spacer()
                HiveText(trailing, role: .scaffoldLabel)
            }
        }
    }

    private func syncCorrectionValues() {
        correctionX = min(1, max(-1, node.x / max(1, GraphSemanticAxes.horizontalNodeRange)))
        correctionY = min(1, max(-1, node.y / max(1, GraphSemanticAxes.verticalNodeRange)))
    }

    private var importantConnections: [GraphNodeRecord] {
        connected
            .sorted(by: graphEntryImportanceSort)
            .prefixArray(3)
    }

    private func relatedChip(_ title: String, color: Color) -> some View {
        HiveText(title, role: .scaffoldLabel)
            .lineLimit(1)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(HiveColorToken.raisedSurface.color.opacity(0.72), in: Capsule())
            .foregroundStyle(HiveColorToken.nectarText.color)
    }
}

private extension Array {
    func prefixArray(_ count: Int) -> [Element] {
        Array(prefix(count))
    }
}

private extension CGPoint {
    func divided(by divisor: CGFloat) -> CGPoint {
        guard divisor != 0 else { return self }
        return CGPoint(x: x / divisor, y: y / divisor)
    }
}

private func graphEntryImportanceSort(_ lhs: GraphNodeRecord, _ rhs: GraphNodeRecord) -> Bool {
    if graphEntryLayerRank(lhs.memoryLayer) != graphEntryLayerRank(rhs.memoryLayer) {
        return graphEntryLayerRank(lhs.memoryLayer) < graphEntryLayerRank(rhs.memoryLayer)
    }
    if lhs.confidence != rhs.confidence {
        return lhs.confidence > rhs.confidence
    }
    return GraphPresentationModel(node: lhs).title < GraphPresentationModel(node: rhs).title
}

private func graphEntryLayerRank(_ layer: MemoryNodeLayer) -> Int {
    switch layer {
    case .definingTrait:
        return 0
    case .importantTrait:
        return 1
    case .connector:
        return 2
    case .detail:
        return 3
    }
}

private extension LifeDomain {
    var graphColor: Color {
        switch self {
        case .education:
            return HiveColorToken.waxAmber.color.opacity(0.82)
        case .projects:
            return HiveColorToken.sealed.color
        case .hardware:
            return HiveColorToken.waxAmber.color.opacity(0.62)
        case .finance:
            return HiveColorToken.waxAmberBright.color.opacity(0.82)
        case .health:
            return HiveColorToken.waxAmber.color.opacity(0.7)
        case .family:
            return HiveColorToken.waxAmber.color.opacity(0.76)
        case .identity:
            return HiveColorToken.waxAmber.color.opacity(0.88)
        case .background:
            return HiveColorToken.scaffoldFaint.color.opacity(0.54)
        }
    }
}
