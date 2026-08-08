import Foundation

/// The axis of a split-view layout.
/// - `.horizontal`: panes arranged side-by-side (left↔right).
/// - `.vertical`: panes stacked top-to-bottom.
public enum SplitOrientation: String, Sendable, Codable, CaseIterable {
    case horizontal
    case vertical

    /// Returns the opposite orientation.
    public var toggled: SplitOrientation {
        self == .horizontal ? .vertical : .horizontal
    }
}
