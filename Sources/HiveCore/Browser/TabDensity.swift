import Foundation

// MARK: - TabDensity
//
// Horizontal tab pill density (SPEC §8.1). The enum case is persisted as a preference
// and lives here in HiveCore (pure, no SwiftUI). The concrete pt dimensions (pillHeight,
// minWidth, etc.) are a Hive-target extension on this enum — see HiveSpacing.swift.

public enum TabDensity: String, Sendable, Codable, CaseIterable {
    /// 28pt tab height — buys ~2× horizontal tab count vs standard.
    case compact
    /// 36pt tab height — the default.
    case standard
    /// 44pt tab height — breathable, fewer tabs.
    case spacious

    public var displayName: String { rawValue.capitalized }
}
