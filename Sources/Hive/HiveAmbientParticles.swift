import SwiftUI

// MARK: - ShimmerView
///
/// Animated gradient shimmer for loading skeletons. Use as an overlay
/// or background on placeholder rectangles during page load.

struct ShimmerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.0

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            GeometryReader { geo in
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.0), location: 0),
                        .init(color: .white.opacity(0.06), location: 0.5),
                        .init(color: .white.opacity(0.0), location: 1),
                    ]),
                    startPoint: UnitPoint(x: phase, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.5, y: 0.5)
                )
                .frame(width: geo.size.width * 2)
            }
            .task {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
        }
    }
}

// MARK: - Shimmer Modifier

extension View {
    /// Applies a shimmer loading animation as an overlay.
    /// Clip the view to a shape first for proper masking.
    func shimmering(active: Bool) -> some View {
        self.overlay(
            Group {
                if active {
                    ShimmerView()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        )
    }
}

// MARK: - PageLoadSkeleton
///
/// Placeholder skeleton shown in the content area while a page loads.
/// Mimics a real page layout with header, image, and paragraph bars.

struct PageLoadSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header bar
            RoundedRectangle(cornerRadius: 6)
                .fill(HiveDesign.Surface.level1)
                .frame(width: 220, height: 18)
                .shimmering(active: true)

            // Hero image placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(HiveDesign.Surface.level1)
                .frame(height: 200)
                .shimmering(active: true)

            // Paragraph lines
            ForEach(0..<6) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(HiveDesign.Surface.level1)
                    .frame(height: 12)
                    .frame(maxWidth: i == 3 ? 0.7 : 1.0, alignment: .leading)
                    .shimmering(active: true)
            }
        }
        .padding(40)
        .frame(maxWidth: 680)
    }
}
