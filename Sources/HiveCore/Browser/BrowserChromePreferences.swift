import Foundation

/// The small persisted preference projection shared by browser shells.
///
/// The Chromium shell stores these values in its larger session envelope, but
/// keeping their defaults and forward-compatible normalization here makes the
/// contract testable without starting CEF. Unknown layout values fail closed
/// to the vertical context-first layout.
public struct BrowserChromePreferences: Codable, Equatable, Sendable {
    public static let defaultLayout = "Vertical"

    public var layout: String
    public var showBookmarksBar: Bool
    public var isCompactMode: Bool
    public var isMemorySaverEnabled: Bool
    /// Approved taste decision (autoplan): the Morning Brief is the default
    /// new-tab destination; the hand-drawn start page remains one toggle away.
    public var openBriefOnNewTab: Bool

    public init(
        layout: String = Self.defaultLayout,
        showBookmarksBar: Bool = false,
        isCompactMode: Bool = false,
        isMemorySaverEnabled: Bool = true,
        openBriefOnNewTab: Bool = true
    ) {
        self.layout = layout
        self.showBookmarksBar = showBookmarksBar
        self.isCompactMode = isCompactMode
        self.isMemorySaverEnabled = isMemorySaverEnabled
        self.openBriefOnNewTab = openBriefOnNewTab
    }

    public var normalizedLayout: String {
        layout == "Horizontal" || layout == "Vertical" ? layout : Self.defaultLayout
    }

    public var normalized: BrowserChromePreferences {
        BrowserChromePreferences(
            layout: normalizedLayout,
            showBookmarksBar: showBookmarksBar,
            isCompactMode: isCompactMode,
            isMemorySaverEnabled: isMemorySaverEnabled,
            openBriefOnNewTab: openBriefOnNewTab
        )
    }

    private enum CodingKeys: String, CodingKey {
        case layout
        case showBookmarksBar
        case isCompactMode
        case isMemorySaverEnabled
        case openBriefOnNewTab
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layout = try container.decodeIfPresent(String.self, forKey: .layout) ?? Self.defaultLayout
        showBookmarksBar = try container.decodeIfPresent(Bool.self, forKey: .showBookmarksBar) ?? false
        isCompactMode = try container.decodeIfPresent(Bool.self, forKey: .isCompactMode) ?? false
        isMemorySaverEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMemorySaverEnabled) ?? true
        openBriefOnNewTab = try container.decodeIfPresent(Bool.self, forKey: .openBriefOnNewTab) ?? true
    }
}
