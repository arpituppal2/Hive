import Foundation

// MARK: - Session Restoration Models
//
// Codable models for persisting browser session state to disk for crash recovery
// and session restore on app restart. Handles tab-level and window-level state.
//
// SPEC §26 — Session Restore & Crash Recovery
// - webViewWebContentProcessDidTerminate → reload tab
// - Tab state persisted to ~/Library/Application Support/Hive/Sessions/
// - Debounced auto-save (1s) + immediate save on app termination
// - Crash loop detection (3+ crashes in 5 min → exclude from auto-restore)

// MARK: - Tab State

/// Serializable state for a single browser tab.
public struct TabState: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var url: URL?
    public var title: String
    public var scrollPosition: Double
    public var isPinned: Bool
    public var isMuted: Bool
    public var groupID: UUID?
    public var lastAccessed: Date
    /// Opaque WebKit interaction state blob (back/forward list, scroll position, form data).
    public var interactionState: Data?

    public init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String = "",
        scrollPosition: Double = 0.0,
        isPinned: Bool = false,
        isMuted: Bool = false,
        groupID: UUID? = nil,
        lastAccessed: Date = Date(),
        interactionState: Data? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.scrollPosition = scrollPosition
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.groupID = groupID
        self.lastAccessed = lastAccessed
        self.interactionState = interactionState
    }
}

// MARK: - Window State

/// Serializable state for a single browser window with all its tabs.
public struct WindowSessionState: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var tabs: [TabState]
    public var selectedTabID: UUID?
    public var windowFrame: CGRect?

    public init(
        id: UUID = UUID(),
        tabs: [TabState] = [],
        selectedTabID: UUID? = nil,
        windowFrame: CGRect? = nil
    ) {
        self.id = id
        self.tabs = tabs
        self.selectedTabID = selectedTabID
        self.windowFrame = windowFrame
    }
}

// MARK: - Root Session

/// The root session container — one file on disk representing all open windows and tabs.
public struct SessionState: Codable, Equatable, Sendable {
    public var version: Int
    public var windows: [WindowSessionState]
    public var activeWindowID: UUID?
    public var timestamp: Date

    public init(
        version: Int = 2,
        windows: [WindowSessionState] = [],
        activeWindowID: UUID? = nil,
        timestamp: Date = Date()
    ) {
        self.version = version
        self.windows = windows
        self.activeWindowID = activeWindowID
        self.timestamp = timestamp
    }
}

// MARK: - Crash Counter

/// Lightweight crash tracking per tab for circuit breaker logic.
/// Persisted as a JSON dictionary: [tabID: CrashRecord].
public struct CrashRecord: Codable, Sendable {
    public let count: Int
    public let firstCrash: Date
    public let lastCrash: Date

    public init(count: Int, firstCrash: Date, lastCrash: Date) {
        self.count = count
        self.firstCrash = firstCrash
        self.lastCrash = lastCrash
    }

    /// Returns true if this record exceeds the crash loop threshold
    /// (3+ crashes within 5 minutes).
    public var isCrashLoop: Bool {
        count >= 3 && lastCrash.timeIntervalSince(firstCrash) < 300
    }

    /// Returns the next record for a crash observed at `date`.
    ///
    /// The circuit breaker is a fixed five-minute burst, not a sliding window
    /// measured from the most recent crash. A tab that crashes once every four
    /// minutes must not accumulate an ever-growing count and eventually look
    /// like a crash loop. Reset the burst when its first-to-current span has
    /// expired; this also makes the boundary deterministic in tests.
    public func recorded(at date: Date) -> CrashRecord {
        let elapsed = date.timeIntervalSince(firstCrash)
        guard elapsed >= 0, elapsed < 300 else {
            return CrashRecord(count: 1, firstCrash: date, lastCrash: date)
        }
        return CrashRecord(count: count + 1, firstCrash: firstCrash, lastCrash: date)
    }

    /// Returns a new record with the counter incremented at the current time.
    public func incremented() -> CrashRecord {
        recorded(at: Date())
    }
}
