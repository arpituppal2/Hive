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
    /// P2.6 Proactive Briefing: regenerate the daily brief from Honeycomb
    /// memory on the calendar-day rollover and refresh open brief tabs. On by
    /// default; disabling keeps the brief static per-serve.
    public var enableProactiveBriefing: Bool
    /// P2.6 Proactive Briefing calendar half: opt-in calendar-aware looking
    /// ahead. Default off — EventKit permission is requested only when the
    /// user enables it in Settings, keeping the brief's event text explicit.
    public var includeCalendarInBrief: Bool

    public init(
        layout: String = Self.defaultLayout,
        showBookmarksBar: Bool = false,
        isCompactMode: Bool = false,
        isMemorySaverEnabled: Bool = true,
        openBriefOnNewTab: Bool = true,
        enableProactiveBriefing: Bool = true,
        includeCalendarInBrief: Bool = false
    ) {
        self.layout = layout
        self.showBookmarksBar = showBookmarksBar
        self.isCompactMode = isCompactMode
        self.isMemorySaverEnabled = isMemorySaverEnabled
        self.openBriefOnNewTab = openBriefOnNewTab
        self.enableProactiveBriefing = enableProactiveBriefing
        self.includeCalendarInBrief = includeCalendarInBrief
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
            openBriefOnNewTab: openBriefOnNewTab,
            enableProactiveBriefing: enableProactiveBriefing,
            includeCalendarInBrief: includeCalendarInBrief
        )
    }

    private enum CodingKeys: String, CodingKey {
        case layout
        case showBookmarksBar
        case isCompactMode
        case isMemorySaverEnabled
        case openBriefOnNewTab
        case enableProactiveBriefing
        case includeCalendarInBrief
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layout = try container.decodeIfPresent(String.self, forKey: .layout) ?? Self.defaultLayout
        showBookmarksBar = try container.decodeIfPresent(Bool.self, forKey: .showBookmarksBar) ?? false
        isCompactMode = try container.decodeIfPresent(Bool.self, forKey: .isCompactMode) ?? false
        isMemorySaverEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMemorySaverEnabled) ?? true
        openBriefOnNewTab = try container.decodeIfPresent(Bool.self, forKey: .openBriefOnNewTab) ?? true
        enableProactiveBriefing = try container.decodeIfPresent(Bool.self, forKey: .enableProactiveBriefing) ?? true
        includeCalendarInBrief = try container.decodeIfPresent(Bool.self, forKey: .includeCalendarInBrief) ?? false
    }
}
