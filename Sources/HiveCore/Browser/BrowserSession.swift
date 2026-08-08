import Foundation

// MARK: - BrowserSession / BrowserSessionWindow
//
// The restorable session — the durable form of everything in `ChromeState` that a user trusts
// the browser not to lose on quit (hive-browser-base-design.md §9). It is deliberately a
// *projection* of ChromeState, not ChromeState itself: ChromeState is a live @Observable (non-
// Sendable, UI-bound); BrowserSession is Sendable + Codable so it can cross the actor boundary
// into `BrowserSessionStore` and round-trip through JSON on disk.
//
// Single-window today: `windows` carries exactly one `BrowserSessionWindow`. The array shape
// matches the §9 contract ("write the full session: windows[...]") and makes multi-window
// restore a later addition with zero schema change.
//
// Forward-compat by construction: every window field decodes with `decodeIfPresent` + a
// default, so a session.json written by an older Hive (missing a field added later) still
// loads. Schema eviction must be a deliberate, content-preserving act — never a silent loss.

public struct BrowserSession: Sendable, Codable, Equatable {
    /// The current on-disk session schema. Older payloads omit this field and
    /// decode as the current schema; newer payloads fail closed and use backup
    /// recovery rather than being silently interpreted as an empty session.
    public static let currentSchemaVersion = 1

    /// One entry per browser window. A single window today.
    public var windows: [BrowserSessionWindow]
    /// When the session was last persisted (audit/debug; not load-bearing for restore).
    public var savedAt: Date
    /// Auto-archived tab records (§7). Persisted so the "Recently Archived" tier survives
    /// restart and the user can restore a tab closed weeks ago. Capped in ChromeState.
    public var archivedTabs: [ArchivedTab]
    /// Monotonically increasing snapshot number. It is diagnostic and helps
    /// select/verify a backup; it never identifies a tab or exposes content.
    public var snapshotSequence: UInt64
    /// Whether the last durable write completed as part of an orderly quit.
    /// A false value means recovery should be treated as crash/unclean-exit
    /// recovery, not that the payload is invalid.
    public var isCleanExit: Bool
    /// Schema version encoded in this payload.
    public var schemaVersion: Int

    public init(windows: [BrowserSessionWindow] = [],
                savedAt: Date = Date(),
                archivedTabs: [ArchivedTab] = [],
                snapshotSequence: UInt64 = 0,
                isCleanExit: Bool = false,
                schemaVersion: Int = BrowserSession.currentSchemaVersion) {
        self.windows = windows
        self.savedAt = savedAt
        self.archivedTabs = archivedTabs
        self.snapshotSequence = snapshotSequence
        self.isCleanExit = isCleanExit
        self.schemaVersion = schemaVersion
    }

    private enum CodingKeys: String, CodingKey {
        case windows, savedAt, archivedTabs, snapshotSequence, isCleanExit, schemaVersion
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSchema = try c.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? BrowserSession.currentSchemaVersion
        guard decodedSchema <= BrowserSession.currentSchemaVersion,
              decodedSchema > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: c,
                debugDescription: "Unsupported browser session schema \(decodedSchema)"
            )
        }
        windows = try c.decodeIfPresent([BrowserSessionWindow].self, forKey: .windows) ?? []
        savedAt = try c.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        archivedTabs = try c.decodeIfPresent([ArchivedTab].self, forKey: .archivedTabs) ?? []
        snapshotSequence = try c.decodeIfPresent(UInt64.self, forKey: .snapshotSequence) ?? 0
        isCleanExit = try c.decodeIfPresent(Bool.self, forKey: .isCleanExit) ?? false
        schemaVersion = decodedSchema
    }
    // encode(to:) stays synthesized — writes every lifecycle field as well as
    // the session content. Private content is removed by the persistence
    // projection before this encoder is called.
}

public struct BrowserSessionWindow: Sendable, Codable, Equatable {
    /// Every space in this window (each carries its own tabIDs, groups, activeTabID).
    public var spaces: [Space]
    /// The union of every open tab across spaces (display order lives in each Space.tabIDs).
    public var tabs: [BrowserTab]
    /// The space that was frontmost (its tab list was visible). nil only if spaces empty.
    public var activeSpaceID: String?
    /// The tab that was frontmost. nil only if no tabs.
    public var activeTabID: String?
    /// Layout + density at last save, so the first frame after launch is already correct
    /// (no "snap" from the default layout to the user's saved one).
    public var layout: TabPosition
    public var density: TabDensity

    public init(spaces: [Space] = [],
                tabs: [BrowserTab] = [],
                activeSpaceID: String? = nil,
                activeTabID: String? = nil,
                layout: TabPosition = .vertical,
                density: TabDensity = .standard) {
        self.spaces = spaces
        self.tabs = tabs
        self.activeSpaceID = activeSpaceID
        self.activeTabID = activeTabID
        self.layout = layout
        self.density = density
    }

    private enum CodingKeys: String, CodingKey {
        case spaces, tabs, activeSpaceID, activeTabID, layout, density
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        spaces = try c.decodeIfPresent([Space].self, forKey: .spaces) ?? []
        tabs = try c.decodeIfPresent([BrowserTab].self, forKey: .tabs) ?? []
        activeSpaceID = try c.decodeIfPresent(String.self, forKey: .activeSpaceID)
        activeTabID = try c.decodeIfPresent(String.self, forKey: .activeTabID)
        layout = try c.decodeIfPresent(TabPosition.self, forKey: .layout) ?? .vertical
        density = try c.decodeIfPresent(TabDensity.self, forKey: .density) ?? .standard
    }
    // encode(to:) stays synthesized — writes every field keyed by CodingKeys (nil optionals
    // serialize as null; the decodeIfPresent above treats null + missing identically).
}

// MARK: - SessionLoadResult
//
// The launch-time outcomes the store distinguishes — so the app can honor the §9 crash-only
// contract: never silently start fresh over an unreadable session. Valid payloads are normalized
// for private-state and reference integrity; the report contains counts only, never session data.
// A corrupt current file is quarantined (never deleted), and a prior good write is offered as
// "Restore last session" recovery.

public enum SessionLoadResult: Sendable, Equatable {
    /// A valid session file was decoded. `repair` is non-sensitive metadata
    /// describing any semantic repairs applied before returning the payload.
    case restored(BrowserSession, repair: BrowserSessionRepairReport = BrowserSessionRepairReport())
    /// No session file exists — a fresh start is correct; nothing to surface.
    case none
    /// The session file was present but unreadable. `quarantineURL` is where the corrupt file
    /// was moved; `recovered` is the last known-good session from the rolling backup, if one
    /// exists. `repair` describes normalization applied to the recovered payload.
    case corrupt(quarantineURL: URL?, recovered: BrowserSession?, repair: BrowserSessionRepairReport = BrowserSessionRepairReport())
}
