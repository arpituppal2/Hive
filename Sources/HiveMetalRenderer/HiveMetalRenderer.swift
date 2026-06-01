import SwiftUI
import HiveDesignSystem
#if canImport(AppKit)
import AppKit
#endif

public enum HiveRenderEvent: String, CaseIterable, Sendable {
    case newNode
    case promoteMemory
    case contradiction
    case claimConfirmed
    case deleteHoldComplete
}

public enum HiveShaderResource: String, CaseIterable, Sendable {
    case amberCell = "amber_cell.metal"
    case neuralPath = "neural_path.metal"
    case grainNoise = "grain_noise.metal"
    case frostedAmberPreview = "frosted_amber_preview.metal"
    case waxPour = "wax_pour.metal"
    case crackedWax = "cracked_wax.metal"
}

public struct HiveReducedMotionPolicy: Hashable, Sendable {
    public var isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public func animation(for event: HiveRenderEvent) -> Animation {
        if isEnabled {
            return .easeInOut(duration: 0.3)
        }
        switch event {
        case .newNode:
            return HiveMotion.formation
        case .promoteMemory:
            return .easeInOut(duration: 1.2)
        case .contradiction:
            return .easeInOut(duration: 0.24)
        case .claimConfirmed:
            return HiveMotion.waxFill
        case .deleteHoldComplete:
            return .easeInOut(duration: 0.18)
        }
    }
}

public struct AmberCellMaterial: Hashable, Sendable {
    public var cellID: UInt64
    public var age: Double
    public var freshness: Double
    public var radius: Double
    public var opacity: Double
    public var cornerVariance: Double
    public var reducedMotion: Bool

    public init(
        cellID: UInt64,
        age: Double = 0,
        freshness: Double = 1,
        radius: Double = 80,
        opacity: Double = 1,
        cornerVariance: Double = 0,
        reducedMotion: Bool = false
    ) {
        self.cellID = cellID
        self.age = min(1, max(0, age))
        self.freshness = min(1, max(0, freshness))
        self.radius = radius
        self.opacity = min(1, max(0, opacity))
        self.cornerVariance = min(1, max(-1, cornerVariance))
        self.reducedMotion = reducedMotion
    }

    public var cornerRadiusOffset: Double {
        let raw = Double(Self.hash(cellID) % 2_000) / 1_000.0 - 1
        return raw + cornerVariance
    }

    public var opacityJitter: Double {
        let raw = Double(Self.hash(cellID &+ 17) % 600) / 10_000.0 - 0.03
        return raw
    }

    public var resolvedOpacity: Double {
        min(1, max(0, opacity + opacityJitter))
    }

    public var resolvedColor: Color {
        let fresh = HiveColorToken.waxAmberBright.color
        let dormant = HiveColorToken.waxAmberDeep.color
        return fresh.interpolate(to: dormant, amount: age)
    }

    public static func hash(_ value: UInt64) -> UInt64 {
        var x = value &+ 0x9e3779b97f4a7c15
        x = (x ^ (x >> 30)) &* 0xbf58476d1ce4e5b9
        x = (x ^ (x >> 27)) &* 0x94d049bb133111eb
        return x ^ (x >> 31)
    }
}

public struct NeuralPathMaterial: Hashable, Sendable {
    public var baseWeight: Double
    public var confidence: Double
    public var period: Double
    public var edgeID: UInt64

    public init(baseWeight: Double = 1, confidence: Double = 1, period: Double? = nil, edgeID: UInt64 = 0) {
        self.baseWeight = max(0.2, baseWeight)
        self.confidence = min(1, max(0, confidence))
        self.edgeID = edgeID
        if let period {
            self.period = period
        } else {
            let random = Double(AmberCellMaterial.hash(edgeID) % 5_000) / 1_000.0
            self.period = 3 + random
        }
    }

    public func thickness(at t: Double) -> Double {
        let clamped = min(1, max(0, t))
        return baseWeight * (1 - 0.6 * clamped) * (1 - 0.6 * (1 - clamped))
    }

    public var isDashed: Bool {
        confidence < 0.62
    }
}

public struct FormationCoordinator: Hashable, Sendable {
    public var travelSpeed: Double
    public var materializationSeconds: Double
    public var edgeDrawSeconds: Double
    public var coolDownSeconds: Double

    public init(
        travelSpeed: Double = 300,
        materializationSeconds: Double = 0.45,
        edgeDrawSeconds: Double = 0.6,
        coolDownSeconds: Double = 2.4
    ) {
        self.travelSpeed = travelSpeed
        self.materializationSeconds = materializationSeconds
        self.edgeDrawSeconds = edgeDrawSeconds
        self.coolDownSeconds = coolDownSeconds
    }

    public func travelDuration(points: Double) -> Double {
        max(0.1, points / travelSpeed)
    }
}

public struct PromotionCoordinator: Hashable, Sendable {
    public var stampSeconds: Double
    public var settleSeconds: Double
    public var etchSeconds: Double

    public init(stampSeconds: Double = 0.3, settleSeconds: Double = 1.2, etchSeconds: Double = 0.8) {
        self.stampSeconds = stampSeconds
        self.settleSeconds = settleSeconds
        self.etchSeconds = etchSeconds
    }
}

public struct HiveMetalScene<Content: View>: View {
    private let content: Content
    private let grainOpacity: Double

    public init(grainOpacity: Double = 0, @ViewBuilder content: () -> Content) {
        self.grainOpacity = grainOpacity
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            HiveColorToken.backgroundDeep.color
            content
            if grainOpacity > 0 {
                HiveGrainLayer(opacity: grainOpacity)
                    .allowsHitTesting(false)
            }
        }
    }
}

public struct HiveGrainLayer: View {
    public var opacity: Double

    public init(opacity: Double = 0.035) {
        self.opacity = opacity
    }

    public var body: some View {
        ZStack {
            HiveColorToken.nectarText.color.opacity(opacity * 0.18)
            HiveColorToken.backgroundDeep.color.opacity(opacity * 0.12)
        }
        .blendMode(.overlay)
    }
}

public struct AmberCellSurface<Content: View>: View {
    public var material: AmberCellMaterial
    public var isActive: Bool
    public var heat: Double
    public var content: Content

    public init(
        material: AmberCellMaterial,
        isActive: Bool = false,
        heat: Double = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.material = material
        self.isActive = isActive
        self.heat = min(1, max(0, heat))
        self.content = content()
    }

    public var body: some View {
        Group {
            if isActive || heat > 0.01 {
                TimelineView(.periodic(from: .now, by: 1.0 / Double(HiveInteractionPolicy.graphMinimumFramesPerSecond))) { context in
                    renderedCell(pulse: isActive ? (sin(context.date.timeIntervalSinceReferenceDate * 3.2) + 1) * 0.5 : 0)
                }
            } else {
                renderedCell(pulse: 0)
            }
        }
    }

    private func renderedCell(pulse: Double) -> some View {
        let activeDecoration = isActive || heat > 0.01
        let shadowOpacity = activeDecoration ? 0.28 + 0.18 * pulse + 0.22 * heat : 0.08
        let shadowRadius: CGFloat = activeDecoration ? CGFloat(12 + 4 * pulse + 5 * heat) : 4
        let shadowY: CGFloat = activeDecoration ? 8 : 3

        return ZStack {
            HexagonShape()
                .fill(material.resolvedColor.interpolate(to: HiveColorToken.waxAmberBright.color, amount: heat * 0.72).opacity(material.resolvedOpacity))
                .shadow(color: HiveColorToken.waxAmberDeep.color.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
                .overlay(
                    HexagonShape()
                        .stroke(
                            isActive ? HiveColorToken.waxAmberBright.color.opacity(0.78 + 0.22 * pulse) : HiveColorToken.waxAmber.color.opacity(0.52),
                            lineWidth: isActive ? 1.6 + pulse * 0.8 : 0.8
                        )
                )
                .overlay {
                    if activeDecoration {
                        HexagonShape()
                            .stroke(HiveColorToken.backgroundDeep.color.opacity(0.55), lineWidth: 4)
                            .blur(radius: 5)
                            .padding(8)
                    } else {
                        HexagonShape()
                            .stroke(HiveColorToken.backgroundDeep.color.opacity(0.22), lineWidth: 1)
                            .padding(7)
                    }
                }
            content
        }
    }
}

public struct HiveFormationPulse: View {
    public var start: CGPoint
    public var end: CGPoint
    public var trigger: Int
    public var duration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0

    public init(start: CGPoint, end: CGPoint, trigger: Int, duration: Double = 0.9) {
        self.start = start
        self.end = end
        self.trigger = trigger
        self.duration = duration
    }

    public var body: some View {
        GeometryReader { _ in
            Canvas { graphics, _ in
                guard progress > 0 && progress < 1 else { return }
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                graphics.stroke(
                    path.trimmedPath(from: 0, to: progress),
                    with: .color(HiveColorToken.neuralGold.color.opacity(reduceMotion ? 0.0 : 0.42)),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
                let point = CGPoint(
                    x: start.x + (end.x - start.x) * progress,
                    y: start.y + (end.y - start.y) * progress
                )
                graphics.fill(
                    HexagonShape().path(in: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)),
                    with: .color(HiveColorToken.waxAmberBright.color.opacity(reduceMotion ? 0.0 : 0.92))
                )
            }
            .onAppear { run() }
            .onChange(of: trigger) { _, _ in run() }
        }
        .allowsHitTesting(false)
    }

    private func run() {
        progress = 0
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.24)) { progress = 1 }
        } else {
            withAnimation(.easeOut(duration: duration)) { progress = 1 }
        }
    }
}

public struct HiveFocusRipple: View {
    public var center: CGPoint
    public var trigger: Int
    public var tint: Color
    public var maxRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 1.0

    public init(
        center: CGPoint,
        trigger: Int,
        tint: Color = HiveColorToken.waxAmberBright.color,
        maxRadius: CGFloat = 170
    ) {
        self.center = center
        self.trigger = trigger
        self.tint = tint
        self.maxRadius = maxRadius
    }

    public var body: some View {
        Canvas { graphics, _ in
            guard progress < 1 else { return }
            let radius = maxRadius * progress
            let alpha = (1 - progress) * 0.42
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            graphics.stroke(
                HexagonShape().path(in: rect),
                with: .color(tint.opacity(alpha)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            )
            let inner = rect.insetBy(dx: radius * 0.22, dy: radius * 0.22)
            graphics.stroke(
                HexagonShape().path(in: inner),
                with: .color(tint.opacity(alpha * 0.48)),
                style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round)
            )
        }
        .allowsHitTesting(false)
        .onAppear { run() }
        .onChange(of: trigger) { _, _ in run() }
    }

    private func run() {
        progress = reduceMotion ? 1 : 0
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.72)) {
            progress = 1
        }
    }
}

public struct HiveWaxRail: View {
    public var active: Bool
    public var width: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    public init(active: Bool, width: CGFloat = 2) {
        self.active = active
        self.width = width
    }

    public var body: some View {
        Rectangle()
            .fill(active ? HiveColorToken.waxAmberBright.color : HiveColorToken.scaffoldFaint.color.opacity(0.34))
            .frame(width: width)
            .scaleEffect(y: active ? (lit ? 1 : 0.18) : 0.42, anchor: .center)
            .opacity(active ? 1 : 0.45)
            .shadow(color: HiveColorToken.waxAmber.color.opacity(active ? 0.34 : 0), radius: active ? 8 : 0)
            .onAppear { animate() }
            .onChange(of: active) { _, _ in animate() }
    }

    private func animate() {
        if reduceMotion {
            lit = true
            return
        }
        lit = false
        withAnimation(HiveMotion.focus) {
            lit = true
        }
    }
}

public struct HiveEtchingReveal<Content: View>: View {
    public var trigger: String
    public var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 0.0

    public init(trigger: String, @ViewBuilder content: () -> Content) {
        self.trigger = trigger
        self.content = content()
    }

    public var body: some View {
        content
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .frame(width: proxy.size.width * max(0.001, progress))
                }
            }
            .onAppear { etch() }
            .onChange(of: trigger) { _, _ in etch() }
    }

    private func etch() {
        progress = reduceMotion ? 1 : 0
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.8)) {
            progress = 1
        }
    }
}

public struct HoldWaxFillButton: View {
    public var title: String
    public var symbol: HiveSymbolName
    public var tint: Color
    public var onComplete: () -> Void
    @State private var progress = 0.0
    @State private var pressing = false
    @State private var holdWorkItem: DispatchWorkItem?

    public init(
        _ title: String,
        symbol: HiveSymbolName = .forget,
        tint: Color = HiveColorToken.conflict.color,
        onComplete: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(tint.opacity(0.24))
            Rectangle()
                .fill(tint.opacity(0.78))
                .scaleEffect(x: progress, y: 1, anchor: .leading)
            HStack(spacing: 8) {
                HiveSymbol(
                    symbol,
                    size: 15,
                    active: pressing,
                    rendering: .palette(primary: tint, secondary: HiveColorToken.waxAmberDeep.color),
                    motion: pressing ? .pulse : .none,
                    motionValue: pressing ? 1 : 0
                )
                HiveText(title, role: .scaffoldAction)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressing else { return }
                    pressing = true
                    progress = 0
                    withAnimation(.linear(duration: 1.2)) {
                        progress = 1
                    }
                    let item = DispatchWorkItem {
                        guard pressing else { return }
                        pressing = false
                        withAnimation(.easeOut(duration: 0.12)) {
                            progress = 0
                        }
                        onComplete()
                    }
                    holdWorkItem = item
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
                }
                .onEnded { _ in
                    guard pressing else { return }
                    pressing = false
                    holdWorkItem?.cancel()
                    holdWorkItem = nil
                    withAnimation(.easeOut(duration: 0.16)) {
                        progress = 0
                    }
                }
        )
    }
}

public struct FrostedAmberPreview<Content: View>: View {
    public var content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(14)
            .background(
                HexagonShape()
                    .fill(HiveColorToken.raisedSurface.color.opacity(0.94))
                    .overlay(HexagonShape().fill(HiveColorToken.waxAmber.color.opacity(0.15)))
                    .overlay(HexagonShape().stroke(HiveColorToken.waxAmber.color.opacity(0.4), lineWidth: 1))
            )
            .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.7), radius: 22, x: 0, y: 12)
    }
}

public struct HiveHexMesh: View {
    public var activePoint: CGPoint?
    public var opacity: Double

    public init(activePoint: CGPoint? = nil, opacity: Double = 0.12) {
        self.activePoint = activePoint
        self.opacity = opacity
    }

    public var body: some View {
        Canvas { graphics, size in
            let spacing: CGFloat = 42
            let radius: CGFloat = 20
            for row in 0...Int(size.height / (spacing * 0.86)) + 2 {
                for column in 0...Int(size.width / spacing) + 2 {
                    let offset = row.isMultiple(of: 2) ? CGFloat(0) : spacing * 0.5
                    let center = CGPoint(
                        x: CGFloat(column) * spacing + offset - spacing,
                        y: CGFloat(row) * spacing * 0.86 - spacing
                    )
                    let distance = activePoint.map { hypot($0.x - center.x, $0.y - center.y) } ?? 9_999
                    let pulse = max(0, 1 - Double(distance / 180))
                    let alpha = opacity + pulse * 0.34
                    graphics.stroke(
                        HexagonShape().path(in: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(HiveColorToken.waxAmber.color.opacity(alpha)),
                        lineWidth: pulse > 0.01 ? 1.2 : 0.65
                    )
                }
            }
        }
    }
}

public struct NeuralPathView: View {
    public var points: [CGPoint]
    public var material: NeuralPathMaterial
    public var active: Bool
    public var revealTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal = 0.0

    public init(points: [CGPoint], material: NeuralPathMaterial, active: Bool = false, revealTrigger: Int = 0) {
        self.points = points
        self.material = material
        self.active = active
        self.revealTrigger = revealTrigger
    }

    public var body: some View {
        Group {
            if active || material.isDashed {
                TimelineView(.periodic(from: .now, by: 1.0 / Double(HiveInteractionPolicy.graphMinimumFramesPerSecond))) { context in
                    pathCanvas(date: context.date)
                }
            } else {
                pathCanvas(date: nil)
            }
        }
    }

    private func pathCanvas(date: Date?) -> some View {
        Canvas { graphics, _ in
            guard points.count >= 2 else { return }
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            let dashPhase = (date?.timeIntervalSinceReferenceDate ?? 0) * 8
            let style = StrokeStyle(
                lineWidth: material.thickness(at: 0.5),
                lineCap: .round,
                lineJoin: .round,
                dash: material.isDashed ? [8, 7] : [],
                dashPhase: dashPhase
            )
            graphics.stroke(
                path.trimmedPath(from: 0, to: reduceMotion ? 1 : reveal),
                with: .color(HiveColorToken.neuralGold.color.opacity(active ? 0.88 : 0.36 * material.confidence)),
                style: style
            )
            if active && !reduceMotion, let date {
                let pulse = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: material.period) / material.period
                let from = points[0]
                let to = points[points.count - 1]
                let point = CGPoint(
                    x: from.x + (to.x - from.x) * pulse,
                    y: from.y + (to.y - from.y) * pulse
                )
                graphics.fill(
                    Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                    with: .color(HiveColorToken.waxAmberBright.color.opacity(0.9))
                )
            }
        }
        .onAppear { draw() }
        .onChange(of: revealTrigger) { _, _ in draw() }
    }

    private func draw() {
        reveal = reduceMotion ? 1 : 0
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.6)) {
            reveal = 1
        }
    }
}

public struct WaxPourFill: View {
    public var progress: Double

    public init(progress: Double) {
        self.progress = min(1, max(0, progress))
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                HexagonShape()
                    .fill(HiveColorToken.backgroundDeep.color.opacity(0.72))
                Rectangle()
                    .fill(HiveColorToken.waxAmber.color.opacity(0.82))
                    .frame(height: proxy.size.height * progress)
                    .mask(HexagonShape())
            }
        }
    }
}

public extension Color {
    func interpolate(to other: Color, amount: Double) -> Color {
        #if canImport(AppKit)
        let left = NSColor(self).usingColorSpace(.deviceRGB) ?? .black
        let right = NSColor(other).usingColorSpace(.deviceRGB) ?? .black
        var leftRed: CGFloat = 0
        var leftGreen: CGFloat = 0
        var leftValue: CGFloat = 0
        var leftAlpha: CGFloat = 0
        var rightRed: CGFloat = 0
        var rightGreen: CGFloat = 0
        var rightValue: CGFloat = 0
        var rightAlpha: CGFloat = 0
        left.getRed(&leftRed, green: &leftGreen, blue: &leftValue, alpha: &leftAlpha)
        right.getRed(&rightRed, green: &rightGreen, blue: &rightValue, alpha: &rightAlpha)
        return Color(
            red: Double(leftRed + (rightRed - leftRed) * CGFloat(amount)),
            green: Double(leftGreen + (rightGreen - leftGreen) * CGFloat(amount)),
            blue: Double(leftValue + (rightValue - leftValue) * CGFloat(amount)),
            opacity: Double(leftAlpha + (rightAlpha - leftAlpha) * CGFloat(amount))
        )
        #else
        return amount < 0.5 ? self : other
        #endif
    }
}
