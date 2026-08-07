import SwiftUI

// MARK: - HiveNoiseTexture
//
// Brand Guidelines v1.0 — Noise & Grain:
// "A single unified noise texture sits at 2.5% opacity on Layer 1 and 2 surfaces in
// light mode, 1.8% in dark mode. Grain size: 0.8pt. Monochromatic (white) — blends
// with system vibrancy. Subtle. If a user can see the grain, it's too heavy.
// This is the only texture in the system. Hive is not maximalist."
//
// Implementation: a lightweight Core Image noise generator rendered as a repeating
// pattern image. Cached in a static Image so it's generated once per launch.

public enum HiveNoiseTexture {

    /// Generates a monochromatic noise image at the specified size.
    /// The grain is white noise at the brand-specified opacity, sized so that
    /// individual grain dots are approximately 0.8pt at 2x.
    /// Cached in a static after first generation.
    nonisolated(unsafe) private static var cachedNoise: CGImage?

    /// Returns a noise image that tiles seamlessly. White monochromatic noise
    /// that blends with system vibrancy per brand spec.
    public static func noiseImage(scale: CGFloat = 2.0) -> CGImage {
        if let cached = cachedNoise { return cached }

        // Grain at 0.8pt visual size at 2x retina = 1.6px → 2px grain dots.
        // Use a 128×128 tile for good repeating coverage.
        let width = 128
        let height = 128
        let grainPixels = max(1, Int(0.8 * scale))

        guard let space = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2) else {
            return blankImage(width: width, height: height)
        }

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return blankImage(width: width, height: height)
        }

        // Fill with zeroes (transparent in monochrome).
        ctx.setFillColor(gray: 0, alpha: 0)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Paint grain dots. Each grain is a small white square.
        // Use a deterministic pseudo-random sequence so the texture is
        // consistent across launches.
        var seed: UInt32 = 42
        let grainCount = width * height / 16  // ~1,024 dots

        for _ in 0..<grainCount {
            seed = (seed &* 1103515245 &+ 12345) & 0x7FFFFFFF
            let px = Int(seed % UInt32(width - grainPixels))
            seed = (seed &* 1103515245 &+ 12345) & 0x7FFFFFFF
            let py = Int(seed % UInt32(height - grainPixels))
            seed = (seed &* 1103515245 &+ 12345) & 0x7FFFFFFF
            // Random brightness: most grains are very faint (12–35),
            // a few are slightly brighter (up to 60) for organic feel.
            let brightness = UInt8(12 + (seed % 48))
            ctx.setFillColor(gray: CGFloat(brightness) / 255.0, alpha: 1.0)
            ctx.fill(CGRect(x: px, y: py, width: grainPixels, height: grainPixels))
        }

        let result = ctx.makeImage() ?? blankImage(width: width, height: height) ?? ctx.makeImage()!
        cachedNoise = result
        return result
    }

    private static func blankImage(width: Int, height: Int) -> CGImage {
        let space = CGColorSpaceCreateDeviceGray()
        // Context creation on a fresh bitmap always succeeds; force-unwrap is safe.
        let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        return ctx.makeImage()!
    }
}

// MARK: - HiveNoiseModifier

/// Applies the brand noise/grain texture over the view at the correct opacity.
/// Brand spec: 2.5% in light mode, 1.8% in dark mode. Grain size: 0.8pt.
/// Only for Layer 1 and Layer 2 surfaces. Subtle — if user can see it, it's too heavy.
struct HiveNoiseModifier: ViewModifier {

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) { noiseOverlay }
    }

    @ViewBuilder
    private var noiseOverlay: some View {
        Image(decorative: HiveNoiseTexture.noiseImage(), scale: 2.0)
            .resizable(resizingMode: .tile)
            .opacity(scheme == .dark ? 0.018 : 0.025)
            .allowsHitTesting(false)
            .blendMode(.plusLighter)
            .drawingGroup(opaque: false)
    }
}

extension View {
    /// Applies the Hive noise/grain texture overlay. Brand spec: only for Layer 1
    /// (passiveChrome) and Layer 2 (activeOverlay) surfaces.
    func hiveNoise() -> some View {
        modifier(HiveNoiseModifier())
    }
}

// MARK: - Noise-enabled layer helper
//
// `includesNoise` is defined in HiveSurfaceMaterial.swift on `HiveSurfaceLayer`.
// This file only provides the noise texture + overlay modifier.
