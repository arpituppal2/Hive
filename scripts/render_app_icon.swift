#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("Sources/HiveApp/Resources/AppIcon", isDirectory: true)
let package = output.appendingPathComponent("Hive.icon", isDirectory: true)
let assets = package.appendingPathComponent("Assets", isDirectory: true)
let iconset = output.appendingPathComponent("Hive.iconset", isDirectory: true)
let previews = output.appendingPathComponent("IconComposerPreviews", isDirectory: true)
let ictool = URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool")
let figmaSource = root.appendingPathComponent("Design/Figma/HiveGlassStackLogo", isDirectory: true)
let figmaExports = figmaSource.appendingPathComponent("IconComposerExports", isDirectory: true)
let figmaLayerExports = figmaSource.appendingPathComponent("FigmaLayerExports", isDirectory: true)

struct IconSpec {
    let filename: String
    let pixels: Int
}

struct HexCell {
    let id: String
    let center: CGPoint
    let radius: CGFloat
    let warmth: CGFloat
    let depth: CGFloat

    var isOuter: Bool {
        id == "hex-back-large"
    }
}

enum IconAppearance: String, CaseIterable {
    case normal
    case dark
    case lightTinted = "light-tinted"
    case darkTinted = "dark-tinted"
    case lightClear = "light-clear"
    case darkClear = "dark-clear"

    var previewFilename: String { "Preview-\(rawValue).png" }

    var rendition: String {
        switch self {
        case .normal: return "Default"
        case .dark: return "Dark"
        case .lightTinted: return "TintedLight"
        case .darkTinted: return "TintedDark"
        case .lightClear: return "ClearLight"
        case .darkClear: return "ClearDark"
        }
    }

    var tintStrength: String? {
        switch self {
        case .lightTinted: return "0.70"
        case .darkTinted: return "0.82"
        default: return nil
        }
    }

    var backgroundStops: [(UInt32, CGFloat)] {
        switch self {
        case .normal:
            return [(0xFFF0BC, 1), (0xF2B44C, 1), (0xA8611C, 1), (0x2B1204, 1)]
        case .dark:
            return [(0xB06B22, 1), (0x4B2408, 1), (0x140702, 1), (0x010100, 1)]
        case .lightTinted:
            return [(0xFFF2C8, 1), (0xEBA748, 1), (0x7D4819, 1), (0x160803, 1)]
        case .darkTinted:
            return [(0x9C601F, 1), (0x341705, 1), (0x0A0301, 1), (0x000000, 1)]
        case .lightClear:
            return [(0xFFF8E2, 0.82), (0xF4C267, 0.64), (0xB46B25, 0.48), (0xFFFFFF, 0.08)]
        case .darkClear:
            return [(0x593211, 0.86), (0x211006, 0.72), (0x080301, 0.56), (0x000000, 0.28)]
        }
    }

    var glassOpacity: CGFloat {
        switch self {
        case .dark, .darkTinted, .darkClear: return 0.9
        case .lightClear: return 0.72
        default: return 0.82
        }
    }

    var emberOpacity: CGFloat {
        switch self {
        case .dark, .darkTinted, .darkClear: return 0.96
        case .lightClear: return 0.72
        default: return 0.9
        }
    }
}

let specs = [
    IconSpec(filename: "icon_16x16.png", pixels: 16),
    IconSpec(filename: "icon_16x16@2x.png", pixels: 32),
    IconSpec(filename: "icon_32x32.png", pixels: 32),
    IconSpec(filename: "icon_32x32@2x.png", pixels: 64),
    IconSpec(filename: "icon_128x128.png", pixels: 128),
    IconSpec(filename: "icon_128x128@2x.png", pixels: 256),
    IconSpec(filename: "icon_256x256.png", pixels: 256),
    IconSpec(filename: "icon_256x256@2x.png", pixels: 512),
    IconSpec(filename: "icon_512x512.png", pixels: 512),
    IconSpec(filename: "icon_512x512@2x.png", pixels: 1024)
]

let iconComposerForegroundLayerNames = [
    "large-glass-hex",
    "medium-glass-hex",
    "small-glass-hex"
]

let layerNames = iconComposerForegroundLayerNames

let stackedCellCount = 3
let glassLayerNames = [
    "05-glass-large-hex",
    "06-glass-medium-hex",
    "07-glass-small-hex"
]
let refractionLayerNames = [
    "08-refraction-large-hex",
    "09-refraction-medium-hex",
    "10-refraction-small-hex"
]
let reflectionLayerNames = [
    "11-reflection-large-hex",
    "12-reflection-medium-hex",
    "13-reflection-small-hex"
]

let figmaLayerNames =
[
    "01-bg-base-honey",
    "02-bg-top-reflection-field",
    "03-bg-depth-vignette",
    "04-bg-ember-glow"
] + glassLayerNames + refractionLayerNames + reflectionLayerNames

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func gradient(_ colors: [CGColor], locations: [CGFloat], colorSpace: CGColorSpace) -> CGGradient {
    CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)!
}

func renderPNG(pixels: Int, draw: (CGContext, CGRect, CGColorSpace) -> Void) throws -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    let bounds = CGRect(x: 0, y: 0, width: pixels, height: pixels)
    context.clear(bounds)
    draw(context, bounds, colorSpace)

    guard let cgImage = context.makeImage() else {
        throw CocoaError(.fileWriteUnknown)
    }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data as Data
}

func drawIconClip(_ context: CGContext, bounds: CGRect) {
    let radius = bounds.width * 0.205
    context.addPath(CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
}

func drawRadialField(
    _ context: CGContext,
    center: CGPoint,
    radius: CGFloat,
    xScale: CGFloat = 1,
    yScale: CGFloat = 1,
    colors: [CGColor],
    locations: [CGFloat],
    colorSpace: CGColorSpace
) {
    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    context.scaleBy(x: xScale, y: yScale)
    context.drawRadialGradient(
        gradient(colors, locations: locations, colorSpace: colorSpace),
        startCenter: .zero,
        startRadius: 0,
        endCenter: .zero,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
    context.restoreGState()
}

func normalized(_ point: CGPoint) -> CGPoint {
    let length = max(0.0001, sqrt(point.x * point.x + point.y * point.y))
    return CGPoint(x: point.x / length, y: point.y / length)
}

func hexVertices(center: CGPoint, radius: CGFloat) -> [CGPoint] {
    (0..<6).map { index in
        let angle = -.pi / 2 + CGFloat(index) * .pi / 3
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}

func roundedHexPath(center: CGPoint, radius: CGFloat, corner: CGFloat) -> CGPath {
    let vertices = hexVertices(center: center, radius: radius)
    let path = CGMutablePath()
    for index in vertices.indices {
        let vertex = vertices[index]
        let previous = vertices[(index + vertices.count - 1) % vertices.count]
        let next = vertices[(index + 1) % vertices.count]
        let previousDirection = normalized(CGPoint(x: previous.x - vertex.x, y: previous.y - vertex.y))
        let nextDirection = normalized(CGPoint(x: next.x - vertex.x, y: next.y - vertex.y))
        let start = CGPoint(x: vertex.x + previousDirection.x * corner, y: vertex.y + previousDirection.y * corner)
        let end = CGPoint(x: vertex.x + nextDirection.x * corner, y: vertex.y + nextDirection.y * corner)
        if index == 0 {
            path.move(to: start)
        } else {
            path.addCurve(to: start, control1: start, control2: start)
        }
        path.addQuadCurve(to: end, control: vertex)
    }
    path.closeSubpath()
    return path
}

func fillPolygon(_ context: CGContext, points: [CGPoint], color fillColor: CGColor) {
    guard let first = points.first else { return }
    context.beginPath()
    context.move(to: first)
    for point in points.dropFirst() {
        context.addCurve(to: point, control1: point, control2: point)
    }
    context.closePath()
    context.setFillColor(fillColor)
    context.fillPath()
}

func outerHexCell(in bounds: CGRect) -> HexCell {
    HexCell(
        id: "hex-back-large",
        center: CGPoint(x: bounds.midX, y: bounds.midY),
        radius: bounds.width * 0.345,
        warmth: 0.66,
        depth: 0.42
    )
}

func internalHexCells(in bounds: CGRect) -> [HexCell] {
    let outer = outerHexCell(in: bounds)
    return [
        HexCell(
            id: "hex-middle-front",
            center: outer.center,
            radius: outer.radius * 0.75,
            warmth: 0.8,
            depth: 0.7
        ),
        HexCell(
            id: "hex-small-front",
            center: outer.center,
            radius: outer.radius * 0.5,
            warmth: 0.94,
            depth: 0.9
        )
    ]
}

func hexCells(in bounds: CGRect) -> [HexCell] {
    [outerHexCell(in: bounds)] + internalHexCells(in: bounds)
}

func drawBackgroundBaseHoney(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    let stops = appearance.backgroundStops
    context.drawLinearGradient(
        gradient(stops.map { color($0.0, alpha: $0.1) }, locations: [0, 0.4, 0.76, 1], colorSpace: colorSpace),
        start: CGPoint(x: bounds.minX, y: bounds.minY),
        end: CGPoint(x: bounds.maxX, y: bounds.maxY),
        options: []
    )
}

func drawBackgroundTopReflectionField(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    drawRadialField(
        context,
        center: CGPoint(x: bounds.width * 0.24, y: bounds.height * 0.16),
        radius: bounds.width * 0.88,
        xScale: 1.28,
        yScale: 0.86,
        colors: [color(0xFFFFFF, alpha: appearance == .darkClear ? 0.14 : 0.42), color(0xFFF2C8, alpha: 0.08), color(0xFFFFFF, alpha: 0)],
        locations: [0, 0.42, 1],
        colorSpace: colorSpace
    )
    drawRadialField(
        context,
        center: CGPoint(x: bounds.width * 0.68, y: bounds.height * 0.14),
        radius: bounds.width * 0.48,
        xScale: 1.2,
        yScale: 0.34,
        colors: [color(0xFFFFFF, alpha: appearance == .darkClear ? 0.08 : 0.2), color(0xFFFFFF, alpha: 0)],
        locations: [0, 1],
        colorSpace: colorSpace
    )
}

func drawBackgroundDepthVignette(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    drawRadialField(
        context,
        center: CGPoint(x: bounds.width * 0.78, y: bounds.height * 0.8),
        radius: bounds.width * 0.76,
        xScale: 1.05,
        yScale: 1.12,
        colors: [color(0x2C1405, alpha: 0), color(0x2C1405, alpha: appearance == .normal ? 0.64 : 0.74)],
        locations: [0.28, 1],
        colorSpace: colorSpace
    )
}

func drawBackgroundEmberGlow(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    drawRadialField(
        context,
        center: CGPoint(x: bounds.midX, y: bounds.midY),
        radius: bounds.width * 0.56,
        xScale: 1.1,
        yScale: 0.98,
        colors: [
            color(0xFDAB43, alpha: appearance == .darkClear ? 0.22 : 0.3),
            color(0xC8841A, alpha: appearance == .lightClear ? 0.07 : 0.16),
            color(0xC8841A, alpha: 0)
        ],
        locations: [0, 0.48, 1],
        colorSpace: colorSpace
    )
}

func drawHoneyDepth(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    drawBackgroundBaseHoney(context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    drawBackgroundTopReflectionField(context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    drawBackgroundDepthVignette(context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    drawBackgroundEmberGlow(context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
}

func drawSingleGlassCell(_ context: CGContext, cell: HexCell, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    let path = roundedHexPath(center: cell.center, radius: cell.radius, corner: cell.radius * 0.115)
    context.saveGState()
    context.addPath(path)
    context.clip()

    let alpha = appearance.glassOpacity * (cell.isOuter ? 0.68 : 0.94 + cell.depth * 0.08)
    context.drawLinearGradient(
        gradient(
            [
                color(0xFFF8DE, alpha: alpha * (cell.isOuter ? 0.34 : 0.72)),
                color(0xF7C76A, alpha: alpha * (cell.isOuter ? 0.36 : 0.66)),
                color(0xC27D25, alpha: alpha * (cell.isOuter ? 0.32 : 0.56)),
                color(0x5A2A0A, alpha: alpha * (cell.isOuter ? 0.28 : 0.46))
            ],
            locations: [0, 0.34, 0.72, 1],
            colorSpace: colorSpace
        ),
        start: CGPoint(x: cell.center.x - cell.radius * 0.96, y: cell.center.y - cell.radius * 1.02),
        end: CGPoint(x: cell.center.x + cell.radius * 1.08, y: cell.center.y + cell.radius * 1.08),
        options: []
    )

    drawRadialField(
        context,
        center: CGPoint(x: cell.center.x - cell.radius * 0.46, y: cell.center.y - cell.radius * 0.48),
        radius: cell.radius * (cell.isOuter ? 0.86 : 0.98),
        xScale: 1.18,
        yScale: 0.64,
        colors: [color(0xFFFFFF, alpha: alpha * (cell.isOuter ? 0.16 : 0.34)), color(0xFFF2CE, alpha: alpha * 0.1), color(0xFFFFFF, alpha: 0)],
        locations: [0, 0.56, 1],
        colorSpace: colorSpace
    )

    drawRadialField(
        context,
        center: CGPoint(x: cell.center.x + cell.radius * 0.42, y: cell.center.y + cell.radius * 0.46),
        radius: cell.radius * 1.0,
        xScale: 1.02,
        yScale: 1.0,
        colors: [color(0x1D0D03, alpha: alpha * (cell.isOuter ? 0.22 : 0.34)), color(0x1D0D03, alpha: alpha * 0.1), color(0x1D0D03, alpha: 0)],
        locations: [0, 0.54, 1],
        colorSpace: colorSpace
    )

    drawRadialField(
        context,
        center: CGPoint(x: cell.center.x + cell.radius * 0.2, y: cell.center.y - cell.radius * 0.18),
        radius: cell.radius * 0.74,
        xScale: 0.9,
        yScale: 1.18,
        colors: [color(0xFFFFFF, alpha: alpha * (cell.isOuter ? 0.06 : 0.1)), color(0xFFFFFF, alpha: alpha * 0.02), color(0xFFFFFF, alpha: 0)],
        locations: [0, 0.48, 1],
        colorSpace: colorSpace
    )
    context.restoreGState()
}

func drawGlassHexCells(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    drawSingleGlassCell(context, cell: outerHexCell(in: bounds), bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    for cell in internalHexCells(in: bounds).sorted(by: { $0.center.y < $1.center.y }) {
        drawSingleGlassCell(context, cell: cell, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    }
}

func drawSingleCellEdgeRefraction(_ context: CGContext, cell: HexCell, colorSpace: CGColorSpace, appearance: IconAppearance) {
    let path = roundedHexPath(center: cell.center, radius: cell.radius, corner: cell.radius * 0.115)
    context.saveGState()
    context.addPath(path)
    context.clip()
    context.drawLinearGradient(
        gradient(
            [
                color(0xFFFFFF, alpha: appearance.glassOpacity * 0.08),
                color(0xFFF1C6, alpha: appearance.glassOpacity * 0.03),
                color(0x6A3510, alpha: appearance.glassOpacity * 0.05)
            ],
            locations: [0, 0.46, 1],
            colorSpace: colorSpace
        ),
        start: CGPoint(x: cell.center.x - cell.radius * 1.12, y: cell.center.y - cell.radius * 1.08),
        end: CGPoint(x: cell.center.x + cell.radius * 1.02, y: cell.center.y + cell.radius * 1.08),
        options: []
    )

    drawRadialField(
        context,
        center: CGPoint(x: cell.center.x - cell.radius * 0.36, y: cell.center.y - cell.radius * 0.48),
        radius: cell.radius * 0.56,
        xScale: 1.35,
        yScale: 0.52,
        colors: [color(0xFFFFFF, alpha: appearance.glassOpacity * 0.1), color(0xFFFFFF, alpha: 0)],
        locations: [0, 1],
        colorSpace: colorSpace
    )
    context.restoreGState()
}

func drawCellEdgeRefractions(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    for cell in hexCells(in: bounds) {
        drawSingleCellEdgeRefraction(context, cell: cell, colorSpace: colorSpace, appearance: appearance)
    }
}

func drawMemoryEmber(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    guard let centerCell = hexCells(in: bounds).last else { return }
    let path = roundedHexPath(center: centerCell.center, radius: centerCell.radius * 0.72, corner: centerCell.radius * 0.085)
    context.saveGState()
    context.addPath(path)
    context.clip()
    context.drawLinearGradient(
        gradient(
            [
                color(0xFFF8E0, alpha: appearance.emberOpacity * 0.82),
                color(0xFDAB43, alpha: appearance.emberOpacity * 0.72),
                color(0xA65B15, alpha: appearance.emberOpacity * 0.44)
            ],
            locations: [0, 0.48, 1],
            colorSpace: colorSpace
        ),
        start: CGPoint(x: centerCell.center.x - centerCell.radius * 0.5, y: centerCell.center.y - centerCell.radius * 0.55),
        end: CGPoint(x: centerCell.center.x + centerCell.radius * 0.5, y: centerCell.center.y + centerCell.radius * 0.5),
        options: []
    )
    drawRadialField(
        context,
        center: CGPoint(x: centerCell.center.x - centerCell.radius * 0.14, y: centerCell.center.y - centerCell.radius * 0.16),
        radius: centerCell.radius * 0.58,
        xScale: 0.86,
        yScale: 0.92,
        colors: [
            color(0xFFF7DE, alpha: appearance.emberOpacity * 0.95),
            color(0xFDAB43, alpha: appearance.emberOpacity * 0.36),
            color(0xC8841A, alpha: 0)
        ],
        locations: [0, 0.5, 1],
        colorSpace: colorSpace
    )
    context.restoreGState()
}

func drawSingleSpecularReflection(_ context: CGContext, cell: HexCell, colorSpace: CGColorSpace, appearance: IconAppearance) {
    let path = roundedHexPath(center: cell.center, radius: cell.radius, corner: cell.radius * 0.115)
    context.saveGState()
    context.addPath(path)
    context.clip()
    drawRadialField(
        context,
        center: CGPoint(x: cell.center.x - cell.radius * 0.28, y: cell.center.y - cell.radius * 0.42),
        radius: cell.radius * 0.4,
        xScale: 1.36,
        yScale: 0.58,
        colors: [color(0xFFFFFF, alpha: appearance.glassOpacity * 0.28), color(0xFFFFFF, alpha: appearance.glassOpacity * 0.04), color(0xFFFFFF, alpha: 0)],
        locations: [0, 0.5, 1],
        colorSpace: colorSpace
    )
    drawRadialField(
        context,
        center: CGPoint(x: cell.center.x + cell.radius * 0.34, y: cell.center.y - cell.radius * 0.1),
        radius: cell.radius * 0.28,
        xScale: 0.72,
        yScale: 1.18,
        colors: [color(0xFFF8E8, alpha: appearance.glassOpacity * 0.13), color(0xFFF8E8, alpha: 0)],
        locations: [0, 1],
        colorSpace: colorSpace
    )
    context.restoreGState()
}

func drawSpecularReflections(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    let cells = hexCells(in: bounds)
    for cell in cells {
        drawSingleSpecularReflection(context, cell: cell, colorSpace: colorSpace, appearance: appearance)
    }
}

func drawContactRefractionOverlap(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    let outer = outerHexCell(in: bounds)
    let path = roundedHexPath(center: outer.center, radius: outer.radius, corner: outer.radius * 0.115)
    context.saveGState()
    context.addPath(path)
    context.clip()
    drawRadialField(
        context,
        center: CGPoint(x: outer.center.x - outer.radius * 0.1, y: outer.center.y - outer.radius * 0.08),
        radius: outer.radius * 0.42,
        xScale: 1.05,
        yScale: 0.95,
        colors: [
            color(0xFFFFFF, alpha: appearance.glassOpacity * 0.08),
            color(0xFDAB43, alpha: appearance.glassOpacity * 0.035),
            color(0xFFFFFF, alpha: 0)
        ],
        locations: [0, 0.42, 1],
        colorSpace: colorSpace
    )
    context.restoreGState()
}

func drawFrontHaze(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    guard let largeCell = hexCells(in: bounds).first else { return }
    let path = roundedHexPath(center: largeCell.center, radius: largeCell.radius, corner: largeCell.radius * 0.115)
    context.saveGState()
    context.addPath(path)
    context.clip()
    drawRadialField(
        context,
        center: CGPoint(x: largeCell.center.x - largeCell.radius * 0.3, y: largeCell.center.y - largeCell.radius * 0.34),
        radius: bounds.width * 0.22,
        xScale: 1.12,
        yScale: 0.58,
        colors: [color(0xFFFFFF, alpha: appearance.glassOpacity * 0.045), color(0xFFFFFF, alpha: 0)],
        locations: [0, 1],
        colorSpace: colorSpace
    )
    context.restoreGState()
}

func drawLargeCellTopSheen(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    guard let largeCell = hexCells(in: bounds).first else { return }
    let path = roundedHexPath(center: largeCell.center, radius: largeCell.radius, corner: largeCell.radius * 0.115)
    context.saveGState()
    context.addPath(path)
    context.clip()
    drawRadialField(
        context,
        center: CGPoint(x: largeCell.center.x - largeCell.radius * 0.18, y: largeCell.center.y - largeCell.radius * 0.52),
        radius: largeCell.radius * 0.42,
        xScale: 1.48,
        yScale: 0.44,
        colors: [color(0xFFFFFF, alpha: appearance.glassOpacity * 0.16), color(0xFFFFFF, alpha: appearance.glassOpacity * 0.035), color(0xFFFFFF, alpha: 0)],
        locations: [0, 0.54, 1],
        colorSpace: colorSpace
    )
    context.restoreGState()
}

func drawMediumCellInnerGlow(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    guard let mediumCell = internalHexCells(in: bounds).first else { return }
    let path = roundedHexPath(center: mediumCell.center, radius: mediumCell.radius, corner: mediumCell.radius * 0.115)
    context.saveGState()
    context.addPath(path)
    context.clip()
    drawRadialField(
        context,
        center: CGPoint(x: mediumCell.center.x + mediumCell.radius * 0.04, y: mediumCell.center.y + mediumCell.radius * 0.04),
        radius: mediumCell.radius * 0.8,
        xScale: 0.98,
        yScale: 1.0,
        colors: [color(0xFDAB43, alpha: appearance.emberOpacity * 0.2), color(0xFFF2C8, alpha: appearance.glassOpacity * 0.08), color(0xFFFFFF, alpha: 0)],
        locations: [0, 0.44, 1],
        colorSpace: colorSpace
    )
    context.restoreGState()
}

func drawSmallCellHotCore(_ context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    guard let smallCell = hexCells(in: bounds).last else { return }
    let path = roundedHexPath(center: smallCell.center, radius: smallCell.radius * 0.68, corner: smallCell.radius * 0.08)
    context.saveGState()
    context.addPath(path)
    context.clip()
    drawRadialField(
        context,
        center: CGPoint(x: smallCell.center.x - smallCell.radius * 0.08, y: smallCell.center.y - smallCell.radius * 0.12),
        radius: smallCell.radius * 0.72,
        xScale: 0.92,
        yScale: 1.02,
        colors: [color(0xFFF8E2, alpha: appearance.emberOpacity * 0.94), color(0xFDAB43, alpha: appearance.emberOpacity * 0.46), color(0xC8841A, alpha: 0)],
        locations: [0, 0.48, 1],
        colorSpace: colorSpace
    )
    context.restoreGState()
}

func drawSingleHexForegroundAsset(_ context: CGContext, cell: HexCell, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    drawSingleGlassCell(context, cell: cell, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    drawSingleCellEdgeRefraction(context, cell: cell, colorSpace: colorSpace, appearance: appearance)
    drawSingleSpecularReflection(context, cell: cell, colorSpace: colorSpace, appearance: appearance)
}

func foregroundCell(named name: String, in bounds: CGRect) -> HexCell? {
    let cells = hexCells(in: bounds)
    switch name {
    case "large-glass-hex":
        return cells.first
    case "medium-glass-hex":
        return cells.dropFirst().first
    case "small-glass-hex":
        return cells.last
    default:
        return nil
    }
}

func drawLayer(_ name: String, context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    switch name {
    case let foregroundLayer where iconComposerForegroundLayerNames.contains(foregroundLayer):
        if let cell = foregroundCell(named: foregroundLayer, in: bounds) {
            drawSingleHexForegroundAsset(context, cell: cell, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
        }
    default:
        break
    }
}

func cellIndex(fromFigmaLayerName name: String) -> Int? {
    guard let suffix = name.split(separator: "-").last, let value = Int(suffix) else {
        return nil
    }
    return value - 1
}

func drawFigmaDetailLayer(_ name: String, context: CGContext, bounds: CGRect, colorSpace: CGColorSpace, appearance: IconAppearance) {
    let cells = hexCells(in: bounds)
    switch name {
    case "01-bg-base-honey":
        drawBackgroundBaseHoney(context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    case "02-bg-top-reflection-field":
        drawBackgroundTopReflectionField(context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    case "03-bg-depth-vignette":
        drawBackgroundDepthVignette(context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    case "04-bg-ember-glow":
        drawBackgroundEmberGlow(context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    case let glassLayer where glassLayerNames.contains(glassLayer):
        if let index = glassLayerNames.firstIndex(of: glassLayer), cells.indices.contains(index) {
            drawSingleGlassCell(context, cell: cells[index], bounds: bounds, colorSpace: colorSpace, appearance: appearance)
        }
    case let edgeLayer where refractionLayerNames.contains(edgeLayer):
        if let index = refractionLayerNames.firstIndex(of: edgeLayer), cells.indices.contains(index) {
            drawSingleCellEdgeRefraction(context, cell: cells[index], colorSpace: colorSpace, appearance: appearance)
        }
    case let reflectionLayer where reflectionLayerNames.contains(reflectionLayer):
        if let index = reflectionLayerNames.firstIndex(of: reflectionLayer), cells.indices.contains(index) {
            drawSingleSpecularReflection(context, cell: cells[index], colorSpace: colorSpace, appearance: appearance)
        }
    default:
        break
    }
}

func renderLayer(pixels: Int, layer: String, appearance: IconAppearance = .normal) throws -> Data {
    try renderPNG(pixels: pixels) { context, bounds, colorSpace in
        drawLayer(layer, context: context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    }
}

func renderFigmaDetailLayer(pixels: Int, layer: String, appearance: IconAppearance = .normal) throws -> Data {
    try renderPNG(pixels: pixels) { context, bounds, colorSpace in
        drawIconClip(context, bounds: bounds)
        drawFigmaDetailLayer(layer, context: context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
    }
}

func renderIcon(pixels: Int, appearance: IconAppearance = .normal) throws -> Data {
    try renderPNG(pixels: pixels) { context, bounds, colorSpace in
        drawIconClip(context, bounds: bounds)
        drawHoneyDepth(context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
        for layer in layerNames {
            drawLayer(layer, context: context, bounds: bounds, colorSpace: colorSpace, appearance: appearance)
        }
    }
}

func resetOutputDirectories() throws {
    for url in [package, iconset, previews, figmaSource] {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: figmaExports, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: figmaLayerExports, withIntermediateDirectories: true)
}

func svgPointList(for cell: HexCell) -> String {
    hexVertices(center: cell.center, radius: cell.radius)
        .map { "\(Int($0.x.rounded())),\(Int($0.y.rounded()))" }
        .joined(separator: " ")
}

func writeFigmaSourceDocument() throws {
    for layer in layerNames {
        let data = try renderLayer(pixels: 1024, layer: layer)
        try data.write(to: figmaExports.appendingPathComponent("\(layer).png"), options: .atomic)
    }
    for layer in figmaLayerNames {
        let data = try renderFigmaDetailLayer(pixels: 1024, layer: layer)
        try data.write(to: figmaLayerExports.appendingPathComponent("\(layer).png"), options: .atomic)
    }

    let cells = hexCells(in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let glassGroups = zip(glassLayerNames, cells).map { layerName, cell in
        return """
        <g id="\(layerName)">
          <polygon id="\(cell.id)-mask" data-hex-cell-mask="true" data-outer-hex="\(cell.isOuter)" points="\(svgPointList(for: cell))" fill="url(#cellGlass)" opacity="\(String(format: "%.2f", cell.isOuter ? 0.55 : 0.82 + cell.depth * 0.08))"/>
        </g>
        """
    }.joined(separator: "\n")
    let edgeRefractionGroups = zip(refractionLayerNames, cells).map { layerName, cell in
        let insetCell = HexCell(id: cell.id, center: cell.center, radius: cell.radius * 0.88, warmth: cell.warmth, depth: cell.depth)
        return """
        <g id="\(layerName)">
          <polygon id="\(cell.id)-edge-refraction" points="\(svgPointList(for: insetCell))" fill="url(#edgeRefraction)" opacity="\(cell.isOuter ? "0.05" : "0.10")"/>
        </g>
        """
    }.joined(separator: "\n")
    let reflectionGroups = zip(reflectionLayerNames, cells).map { layerName, cell in
        return """
        <g id="\(layerName)">
          <ellipse id="\(cell.id)-reflection" cx="\(Int((cell.center.x - cell.radius * 0.24).rounded()))" cy="\(Int((cell.center.y - cell.radius * 0.34).rounded()))" rx="\(Int((cell.radius * (cell.isOuter ? 0.32 : 0.46)).rounded()))" ry="\(Int((cell.radius * (cell.isOuter ? 0.18 : 0.28)).rounded()))" fill="#FFFFFF" fill-opacity="\(cell.isOuter ? "0.07" : "0.16")" filter="url(#softReflection)"/>
        </g>
        """
    }.joined(separator: "\n")
    let cellMaskJSON = cells.map { "        \"\($0.id)\"" }.joined(separator: ",\n")
    let detailLayerJSON = figmaLayerNames.map { "        \"\($0)\"" }.joined(separator: ",\n")
    let compositeLayerJSON = layerNames.map { "        \"IconComposerExports/\($0).png\"" }.joined(separator: ",\n")
    let constructionLayerJSON = figmaLayerNames.map { "        \"FigmaLayerExports/\($0).png\"" }.joined(separator: ",\n")

    let svg = """
    <svg width="1024" height="1024" viewBox="0 0 1024 1024" fill="none" xmlns="http://www.w3.org/2000/svg">
      <title>Hive Stacked Comb Figma Source</title>
      <desc>Figma-first source for the Hive app icon. The artwork uses SF Symbols-style point-up hexagon geometry: one centered filled glass hexagon repeated at 100%, 75%, and 50% scale, without cast effects.</desc>
      <metadata>{"concept":"Hive Glass Stack","sfSymbolBaseline":"hexagon.fill","figmaLayerCount":\(figmaLayerNames.count),"physicalForegroundLayerCount":3,"stackedHexCellCount":3,"hexCellCount":3,"hexScaleRatios":[1.0,0.75,0.5],"allHexCenters":[[512,512],[512,512],[512,512]],"hasShadows":false,"hasSixAppearanceExports":true,"hexCellMasks":[
        \(cellMaskJSON)
      ],"requiresReflectionArtwork":true}</metadata>
      <defs>
        <radialGradient id="honeyDepth" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(306 214) rotate(52) scale(854 884)">
          <stop stop-color="#FFE0A0"/>
          <stop offset="0.4" stop-color="#E79D33"/>
          <stop offset="0.76" stop-color="#7A4215"/>
          <stop offset="1" stop-color="#1A0B03"/>
        </radialGradient>
        <radialGradient id="topReflection" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(286 184) rotate(28) scale(640 480)">
          <stop stop-color="#FFFFFF" stop-opacity="0.34"/>
          <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
        </radialGradient>
        <radialGradient id="depthVignette" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(790 795) rotate(43) scale(620 690)">
          <stop offset="0.35" stop-color="#2C1405" stop-opacity="0"/>
          <stop offset="1" stop-color="#2C1405" stop-opacity="0.62"/>
        </radialGradient>
        <radialGradient id="backgroundEmber" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(512 512) scale(470)">
          <stop stop-color="#FDAB43" stop-opacity="0.24"/>
          <stop offset="0.5" stop-color="#C8841A" stop-opacity="0.12"/>
          <stop offset="1" stop-color="#C8841A" stop-opacity="0"/>
        </radialGradient>
        <linearGradient id="cellGlass" x1="260" y1="255" x2="752" y2="804" gradientUnits="userSpaceOnUse">
          <stop stop-color="#FFFFFF" stop-opacity="0.72"/>
          <stop offset="0.36" stop-color="#FFE3A4" stop-opacity="0.68"/>
          <stop offset="0.72" stop-color="#C78123" stop-opacity="0.58"/>
          <stop offset="1" stop-color="#5E2F0D" stop-opacity="0.48"/>
        </linearGradient>
        <linearGradient id="edgeRefraction" x1="300" y1="280" x2="730" y2="760" gradientUnits="userSpaceOnUse">
          <stop stop-color="#FFFFFF" stop-opacity="0.40"/>
          <stop offset="0.5" stop-color="#FFF1C6" stop-opacity="0.18"/>
          <stop offset="1" stop-color="#6A3510" stop-opacity="0.24"/>
        </linearGradient>
        <radialGradient id="ember" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(512 512) scale(122)">
          <stop stop-color="#FFF7DE"/>
          <stop offset="0.36" stop-color="#FDAB43" stop-opacity="0.9"/>
          <stop offset="0.72" stop-color="#C8841A" stop-opacity="0.42"/>
          <stop offset="1" stop-color="#C8841A" stop-opacity="0"/>
        </radialGradient>
        <filter id="softReflection" x="-40%" y="-40%" width="180%" height="180%" color-interpolation-filters="sRGB">
          <feGaussianBlur stdDeviation="18"/>
        </filter>
      </defs>
      <g id="01-bg-base-honey">
        <rect width="1024" height="1024" rx="226" fill="url(#honeyDepth)"/>
      </g>
      <g id="02-bg-top-reflection-field">
        <rect width="1024" height="1024" rx="226" fill="url(#topReflection)"/>
      </g>
      <g id="03-bg-depth-vignette">
        <rect width="1024" height="1024" rx="226" fill="url(#depthVignette)"/>
      </g>
      <g id="04-bg-ember-glow">
        <rect width="1024" height="1024" rx="226" fill="url(#backgroundEmber)"/>
      </g>
        \(glassGroups)
        \(edgeRefractionGroups)
        \(reflectionGroups)
    </svg>
    """
    try svg.write(to: figmaSource.appendingPathComponent("HiveGlassStackLogo.figma-source.svg"), atomically: true, encoding: .utf8)

    let layerMap = """
    {
      "product": "Hive",
      "concept": "Hive Glass Stack",
      "source": "Figma first: import HiveGlassStackLogo.figma-source.svg into Figma, keep the named construction layers editable, export three centered foreground hex assets for Icon Composer.",
      "sfSymbolBaseline": "hexagon.fill",
      "iconComposerInput": "../../Sources/HiveApp/Resources/AppIcon/Hive.icon",
      "figmaLayerCount": \(figmaLayerNames.count),
      "physicalForegroundLayerCount": 3,
      "iconComposerForegroundGroupCount": 3,
      "stackedHexCellCount": 3,
      "hexCellCount": 3,
      "hexScaleRatios": [1.0, 0.75, 0.5],
      "allHexCenters": [[512, 512], [512, 512], [512, 512]],
      "hasShadows": false,
      "hasSixAppearanceExports": true,
      "hexCellMasks": [
        \(cellMaskJSON)
      ],
      "iconComposerForegroundGroups": [
        "large-glass-hex",
        "medium-glass-hex",
        "small-glass-hex"
      ],
      "figmaLayers": [
        \(detailLayerJSON)
      ],
      "exportedPNGLayers": [
        \(compositeLayerJSON)
      ],
      "figmaConstructionPNGLayers": [
        \(constructionLayerJSON)
      ],
      "requiredMaterialSignals": [
        "one centered point-up glass hex repeated three times",
        "100 percent scale back hex",
        "75 percent scale middle hex",
        "50 percent scale front hex",
        "SF Symbols hexagon.fill proportions",
        "soft reflections",
        "edge refraction"
      ]
    }
    """
    try layerMap.write(to: figmaSource.appendingPathComponent("IconComposerLayerMap.json"), atomically: true, encoding: .utf8)
}

func writeIconComposerDocument() throws {
    for layer in layerNames {
        let data = try renderLayer(pixels: 1024, layer: layer)
        try data.write(to: assets.appendingPathComponent("\(layer).png"), options: .atomic)
    }

    let iconComposerGroupOrder = ["small-glass-hex", "medium-glass-hex", "large-glass-hex"]
    let groups = iconComposerGroupOrder.map { layer -> String in
        let translucency: String
        switch layer {
        case "small-glass-hex":
            translucency = "0.42"
        case "medium-glass-hex":
            translucency = "0.48"
        default:
            translucency = "0.54"
        }
        return """
    {
      "name" : "\(layer)",
      "layers" : [
        {
          "image-name" : "\(layer).png",
          "name" : "\(layer)"
        }
      ],
      "translucency" : {
        "enabled" : true,
        "value" : \(translucency)
      }
    }
    """
    }.joined(separator: ",\n")

    let iconJSON = """
    {
      "fill" : {
        "automatic-gradient" : "extended-srgb:0.95294,0.69804,0.29020,1.00000"
      },
      "groups" : [
    \(groups)
      ],
      "supported-platforms" : {
        "circles" : [
          "watchOS"
        ],
        "squares" : "shared"
      }
    }
    """
    try iconJSON.write(to: package.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)

    let manifest = """
    {
      "format": "com.apple.iconcomposer.icon",
      "generator": "scripts/render_app_icon.swift",
      "product": "Hive",
      "concept": "Hive Glass Stack: SF Symbols hexagon.fill proportions, one centered point-up glass hex repeated at 100%, 75%, and 50% scale with no shadows.",
      "figmaSource": "Design/Figma/HiveGlassStackLogo/HiveGlassStackLogo.figma-source.svg",
      "sourceOfTruth": "Figma foreground hex assets in Design/Figma/HiveGlassStackLogo/IconComposerExports, composed by Hive.icon/icon.json; app-facing previews, icns, and iconset are exported from Icon Composer through ictool.",
      "previewExportSource": "Icon Composer ictool",
      "sfSymbolBaseline": "hexagon.fill",
      "iconComposer": {
        "tool": "Icon Composer",
        "executable": "/Applications/Xcode.app/Contents/Applications/Icon Composer.app",
        "exporter": "ictool",
        "physicalForegroundGroups": 3
      },
      "figmaLayerCount": \(figmaLayerNames.count),
      "physicalForegroundLayerCount": 3,
      "iconComposerForegroundGroupCount": 3,
      "stackedHexCellCount": 3,
      "hexCellCount": 3,
      "hexScaleRatios": [1.0, 0.75, 0.5],
      "allHexCenters": [[512, 512], [512, 512], [512, 512]],
      "hasShadows": false,
      "hasSixAppearanceExports": true,
      "appearances": [
        "normal",
        "dark",
        "light-tinted",
        "dark-tinted",
        "light-clear",
        "dark-clear"
      ],
      "layers": [
        "large-glass-hex",
        "medium-glass-hex",
        "small-glass-hex"
      ]
    }
    """
    try manifest.write(to: output.appendingPathComponent("IconComposerSpec.json"), atomically: true, encoding: .utf8)
}

func exportIconComposerImage(appearance: IconAppearance, outputFile: URL, pixels: Int) throws {
    let allowFallback = ProcessInfo.processInfo.environment["HIVE_ICON_ALLOW_FALLBACK"] == "1"
    guard FileManager.default.fileExists(atPath: ictool.path) else {
        guard allowFallback else {
            throw CocoaError(.fileNoSuchFile)
        }
        try renderIcon(pixels: pixels, appearance: appearance).write(to: outputFile, options: .atomic)
        return
    }

    let process = Process()
    process.executableURL = ictool
    var arguments = [
        package.path,
        "--export-image",
        "--output-file", outputFile.path,
        "--platform", "iOS",
        "--rendition", appearance.rendition,
        "--width", "\(pixels)",
        "--height", "\(pixels)",
        "--scale", "1"
    ]
    if let tintStrength = appearance.tintStrength {
        arguments += ["--tint-color", "0.115", "--tint-strength", tintStrength]
    }
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        if allowFallback {
            try renderIcon(pixels: pixels, appearance: appearance).write(to: outputFile, options: .atomic)
            return
        }
        throw CocoaError(.fileWriteUnknown)
    }
}

func writePreviewsAndIconset() throws {
    for appearance in IconAppearance.allCases {
        let previewURL = previews.appendingPathComponent(appearance.previewFilename)
        try exportIconComposerImage(appearance: appearance, outputFile: previewURL, pixels: 1024)
    }
    try FileManager.default.copyItem(
        at: previews.appendingPathComponent(IconAppearance.normal.previewFilename),
        to: previews.appendingPathComponent("Preview.png")
    )

    for spec in specs {
        let outputURL = iconset.appendingPathComponent(spec.filename)
        try exportIconComposerImage(appearance: .normal, outputFile: outputURL, pixels: spec.pixels)
    }
}

func writeICNS() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconset.path, "-o", output.appendingPathComponent("Hive.icns").path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw CocoaError(.fileWriteUnknown)
    }
}

try resetOutputDirectories()
try writeFigmaSourceDocument()
try writeIconComposerDocument()
try writePreviewsAndIconset()
try writeICNS()

print(output.appendingPathComponent("Hive.icns").path)
