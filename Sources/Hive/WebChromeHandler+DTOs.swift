//
//  WebChromeHandler+DTOs.swift
//  Hive
//
//  Carved out of WebChromeHandler.swift by scripts/split_webchrome_handler.py.
//  Pure file split — the JS<->Swift bridge request/response payload types.
//

import Foundation
import AppKit
import CefKit
import HiveCore


// MARK: - Bridge DTOs
//
// JSON payloads exchanged with the web chrome. All Sendable + Codable so the
// typed CefBridge.register<Input, Output> overload applies. Every request
// carries the session `token` — validated before any side effect.

struct WebChromeToken: Codable, Sendable {
    let token: String
}

/// Initial state request for a per-tab start page. `privateStart` is optional
/// on decode so older embedded pages remain compatible during upgrades.
struct WebChromeStartRequest: Codable, Sendable {
    let token: String
    let privateStart: Bool
    let chromeShell: Bool

    init(token: String, privateStart: Bool = false, chromeShell: Bool = false) {
        self.token = token
        self.privateStart = privateStart
        self.chromeShell = chromeShell
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        privateStart = try container.decodeIfPresent(Bool.self, forKey: .privateStart) ?? false
        chromeShell = try container.decodeIfPresent(Bool.self, forKey: .chromeShell) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case token, privateStart, chromeShell
    }
}

struct WebChromeTopSite: Codable, Sendable {
    let host: String
    let url: String
    let faviconURL: String?
}

struct WebChromeRecentItem: Codable, Sendable {
    let title: String
    let url: String
    let host: String
    let faviconURL: String?
    let timeLabel: String
    /// Chrome-history-style day bucket: "Today", "Yesterday", or a localized
    /// date (e.g. "Aug 8, 2026"). Optional so legacy fixtures decode as
    /// ungrouped (single flat list).
    let dayLabel: String?
    /// Durable history-entry id, used by per-item delete. Optional so legacy
    /// fixtures decode (rows without it simply skip the Delete action).
    let historyID: String?
}

struct WebChromeSpace: Codable, Sendable {
    let id: String
    let name: String
    let colorHex: String
    let tabCount: Int
}

struct WebChromeStartData: Codable, Sendable {
    let topSites: [WebChromeTopSite]
    let recent: [WebChromeRecentItem]
    let spaces: [WebChromeSpace]
    let accentHex: String
    // Full browser state for the web chrome shell (hive://start?chrome=1).
    let tabs: [WebChromeTab]
    let activeTabID: String?
    let layout: String
    let isPrivateBrowsing: Bool
    let isSplitActive: Bool
    let isChromePanelOpen: String?
    let chromeMode: String
    let chromeDimension: Double
    /// Current default search engine display name (Settings panel selector).
    let searchEngine: String
    /// HTTPS-Only mode state (Settings panel toggle, mirrors the native
    /// Privacy row; UserDefaults-backed).
    let httpsOnlyEnabled: Bool
    /// Network-level ad/tracker blocking (EasyList engine). Mirrors the native
    /// Privacy toggle; web chrome Settings exposes the same switch.
    let adBlockEnabled: Bool
    /// Free memory from inactive tabs (Chrome Memory Saver parity). Mirrors
    /// the native Performance toggle.
    let memorySaverEnabled: Bool
    let tabGroups: [WebChromeTabGroup]
    let history: [WebChromeRecentItem]
    let bookmarks: [WebChromeBookmark]
    let downloads: [WebChromeDownload]
    // AI state surfaced to the web chrome shell
    let councilVerdict: WebChromeCouncilVerdict?
    let isCouncilConvening: Bool
    let councilLiveResponses: [WebChromeCouncilResponse]
    let deepResearchStep: WebChromeDeepResearchStep?
    let agentTask: WebChromeAgentTask?
    let councilError: String?
    let agentError: String?
    let lastQuery: String?
    /// Non-sensitive sync lifecycle diagnostic for the browser chrome only.
    /// Never includes URLs, titles, ciphertext, or key material.
    let syncDiagnostic: String?
    /// M3 surface tint (spec §3): average color of the active page's favicon,
    /// computed natively (CORS-safe) and supplied to the web chrome toolbar.
    /// nil/empty = fall back to canvas. Never sent to private start pages.
    let pageTintHex: String?

    /// Removes normal-profile browsing data before a private start page is
    /// hydrated. Keep the same DTO so the JS renderer has one stable contract.
    func redactedForPrivateStart() -> WebChromeStartData {
        WebChromeStartData(
            topSites: [],
            recent: [],
            spaces: [],
            accentHex: accentHex,
            tabs: tabs.filter(\.isPrivate),
            activeTabID: activeTabID.flatMap { id in tabs.contains { $0.id == id && $0.isPrivate } ? id : nil },
            layout: layout,
            isPrivateBrowsing: true,
            isSplitActive: false,
            isChromePanelOpen: nil,
            chromeMode: chromeMode,
            chromeDimension: chromeDimension,
            searchEngine: searchEngine,
            httpsOnlyEnabled: httpsOnlyEnabled,
            adBlockEnabled: adBlockEnabled,
            memorySaverEnabled: memorySaverEnabled,
            tabGroups: [],
            history: [],
            bookmarks: [],
            downloads: [],
            councilVerdict: nil,
            isCouncilConvening: false,
            councilLiveResponses: [],
            deepResearchStep: nil,
            agentTask: nil,
            councilError: nil,
            agentError: nil,
            lastQuery: nil,
            syncDiagnostic: nil,
            pageTintHex: nil
        )
    }

    /// Normal per-tab start pages may show normal-profile suggestions, but
    /// never receive private-tab metadata from the shared BrowserState.
    func redactedForNormalStart() -> WebChromeStartData {
        let visibleTabIDs = Set(tabs.filter { !$0.isPrivate }.map(\.id))
        let visibleSpaces = spaces.map { space in
            WebChromeSpace(
                id: space.id,
                name: space.name,
                colorHex: space.colorHex,
                tabCount: tabs.filter { !$0.isPrivate && $0.workspaceID == space.id }.count
            )
        }
        let visibleGroups = tabGroups.map { group in
            WebChromeTabGroup(
                id: group.id,
                name: group.name,
                colorHex: group.colorHex,
                tabIDs: group.tabIDs.filter { visibleTabIDs.contains($0) },
                isCollapsed: group.isCollapsed
            )
        }
        return WebChromeStartData(
            topSites: topSites,
            recent: recent,
            spaces: visibleSpaces,
            accentHex: accentHex,
            tabs: tabs.filter { !$0.isPrivate },
            activeTabID: activeTabID.flatMap { id in tabs.contains { $0.id == id && !$0.isPrivate } ? id : nil },
            layout: layout,
            isPrivateBrowsing: false,
            isSplitActive: false,
            isChromePanelOpen: nil,
            chromeMode: chromeMode,
            chromeDimension: chromeDimension,
            searchEngine: searchEngine,
            httpsOnlyEnabled: httpsOnlyEnabled,
            adBlockEnabled: adBlockEnabled,
            memorySaverEnabled: memorySaverEnabled,
            tabGroups: visibleGroups,
            history: history,
            bookmarks: bookmarks,
            downloads: downloads,
            councilVerdict: councilVerdict,
            isCouncilConvening: isCouncilConvening,
            councilLiveResponses: councilLiveResponses,
            deepResearchStep: deepResearchStep,
            agentTask: agentTask,
            councilError: councilError,
            agentError: agentError,
            lastQuery: lastQuery,
            syncDiagnostic: syncDiagnostic,
            pageTintHex: pageTintHex
        )
    }
}

struct WebChromeCouncilVerdict: Codable, Sendable {
    let answer: String
    let reasoning: String
    let agreements: [String]
    let disagreements: [String]
    let confidence: Double
    let activeProviders: [String]
    let isDegraded: Bool
    let responses: [WebChromeCouncilResponse]
}

struct WebChromeCouncilResponse: Codable, Sendable {
    let provider: String
    let answer: String
    let confidence: Double
    let durationMS: Int
    let status: String
}

struct WebChromeDeepResearchStep: Codable, Sendable {
    let label: String
    let progress: Double
    let isComplete: Bool
}

struct WebChromeAgentTask: Codable, Sendable {
    let question: String
    let phase: String  // "idle", "council", "researching", "acting", "done"
    let stepLabel: String
    let stepProgress: Double
    let verdict: WebChromeCouncilVerdict?
    let research: WebChromeDeepResearchStep?
    let actions: [WebChromeAgentAction]
}

struct WebChromeAgentAction: Codable, Sendable {
    let tool: String
    let label: String
    let success: Bool
}

struct WebChromeBookmark: Codable, Sendable {
    let id: String
    let title: String
    let url: String
    let faviconURL: String?
}

struct WebChromeTabGroup: Codable, Sendable {
    let id: String
    let name: String
    let colorHex: String
    let tabIDs: [String]
    let isCollapsed: Bool
}

struct WebChromeDownload: Codable, Sendable {
    let id: String
    let name: String
    let url: String
    let state: String
    let progress: Double
    /// Whether the file exists on disk and can be revealed in Finder
    /// (completed non-canceled downloads only).
    let hasDestination: Bool
}

struct WebChromeSession: Codable, Sendable {
    let id: String
    let title: String
    let windowCount: Int
    let tabCount: Int
    let faviconURL: String?
    let startedAt: String
    let lastActiveAt: String
}

struct WebChromeSearchRequest: Codable, Sendable {
    let token: String
    let query: String
}

struct WebChromeTab: Codable, Sendable {
    let id: String
    let title: String
    let url: String?
    let host: String?
    let faviconURL: String?
    let isPinned: Bool
    let isEssential: Bool
    let isPrivate: Bool
    let isHibernated: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let isLoading: Bool
     let workspaceID: String
    let groupID: String?
    let isBookmarked: Bool
    /// Whether the active page is in Reader Mode (toolbar toggle state).
    let isReaderMode: Bool
    /// Active page zoom percentage (100 = default). Lets the web chrome show
    /// a live zoom indicator next to the address bar.
    let zoomPercent: Int?
    /// Renderer-level mute (CEF SetAudioMuted). Optional so legacy fixtures
    /// without the keys decode as unmuted.
    let isMuted: Bool?
    /// Whether the tab's renderer is currently producing audio.
    let isMediaPlaying: Bool?
    /// Committed navigation entries for the back-button long-press/right-click
    /// menu (Chrome/Safari convention). Newest first, capped at 12. Optional
    /// so legacy fixtures without the keys decode as absent.
    let backHistory: [WebChromeNavEntry]?
    /// Committed navigation entries for the forward-button menu, nearest first.
    let forwardHistory: [WebChromeNavEntry]?
}

struct WebChromeNavEntry: Codable, Sendable {
    let title: String
    let url: String
}

struct WebChromeLayoutRequest: Codable, Sendable {
    let token: String
    let mode: String
}

struct WebChromePanelRequest: Codable, Sendable {
    let token: String
    let panel: String
}

struct WebChromeSidecarStep: Codable, Sendable {
    let token: String
    let text: String
    let kind: String?
}

struct WebChromeSidecarChain: Codable, Sendable {
    let token: String
    let label: String
    let steps: [String]
    let kind: String?
}

struct WebChromeDimensionRequest: Codable, Sendable {
    let token: String
    let dimension: Double
}

struct WebChromeReorderRequest: Codable, Sendable {
    let token: String
    let from: String
    let to: Int
}

struct WebChromeURLRequest: Codable, Sendable {
    let token: String
    let url: String
}

/// Open-a-link-in-a-new-tab request (middle/⌘-click, drag-onto-tab-strip).
/// `activate` is optional and defaults to true (foreground) so legacy callers
/// that omit it keep foreground behavior.
struct WebChromeOpenTabRequest: Codable, Sendable {
    let token: String
    let url: String
    let activate: Bool?
}

struct WebChromeIDRequest: Codable, Sendable {
    let token: String
    let id: String
}

struct WebChromeGroupRequest: Codable, Sendable {
    let token: String
    let id: String
    let name: String
    let colorHex: String
}

struct WebChromeGroupColorRequest: Codable, Sendable {
    let token: String
    let id: String
    let colorHex: String
}

struct WebChromeMoveTabGroupRequest: Codable, Sendable {
    let token: String
    let tabID: String
    let groupID: String
}

// MARK: - Agent Tool Request Types (Astro-aligned CDP bridge)

struct WebChromeAgentNavigate: Codable, Sendable {
    let token: String
    let url: String
}

struct WebChromeAgentClick: Codable, Sendable {
    let token: String
    let ref: String?
    let selector: String?
}

struct WebChromeAgentFill: Codable, Sendable {
    let token: String
    let selector: String
    let value: String
}

struct WebChromeAgentType: Codable, Sendable {
    let token: String
    let text: String?
    let key: String?
}

struct WebChromeAgentScroll: Codable, Sendable {
    let token: String
    let direction: String?
    let amount: Int?
}

struct WebChromeAgentWait: Codable, Sendable {
    let token: String
    let ms: Int?
}

struct WebChromeAgentQuery: Codable, Sendable {
    let token: String
    let query: String
    let format: String?
}

struct WebChromeAgentKeyRequest: Codable, Sendable {
    let token: String
    let key: String
}

struct WebChromeAgentEvaluate: Codable, Sendable {
    let token: String
    let expression: String
}

struct WebChromeAgentSnapshotResult: Codable, Sendable {
    let nodes: [WebChromeAXNode]
    let count: Int
}

struct WebChromeAXNode: Codable, Sendable {
    let ref: String
    let role: String
    let name: String?
    let value: String?
}

struct WebChromeAgentGrepResult: Codable, Sendable {
    let matches: [String]
}

struct WebChromeAgentScreenshotResult: Codable, Sendable {
    let base64: String
}

struct WebChromeAgentTabInfo: Codable, Sendable {
    let id: String
    let title: String
    let url: String
    let active: Bool
}

struct WebChromeAgentTabsResult: Codable, Sendable {
    let tabs: [WebChromeAgentTabInfo]
    let count: Int
}

struct WebChromeAgentNewTab: Codable, Sendable {
    let token: String
    let url: String
}

struct WebChromeAgentTabID: Codable, Sendable {
    let token: String
    let id: String
}

struct WebChromeBoolRequest: Codable, Sendable {
    let token: String
    let value: Bool
}

struct WebChromePrefRequest: Codable, Sendable {
    let token: String
    let key: String
    let value: Bool
}

struct WebChromeTextRequest: Codable, Sendable {
    let token: String
    let text: String
}

struct WebChromeWorkspaceRequest: Codable, Sendable {
    let token: String
    let name: String
    let colorHex: String?
    let iconName: String?
}

struct WebChromeAccentRequest: Codable, Sendable {
    let token: String
    let hex: String
}

struct WebChromeSuggestion: Codable, Sendable {
    let text: String
    let url: String?
    let kind: String
    let tabID: String?
}

struct WebChromeSuggestResponse: Codable, Sendable {
    let suggestions: [WebChromeSuggestion]
}

struct WebChromeActionRequest: Codable, Sendable {
    let token: String
    let action: String
}

// MARK: - Surface action request types (web-chrome context menu / find / auth)

/// "Bookmark Link" — arbitrary URL + optional display title.
struct WebChromeBookmarkRequest: Codable, Sendable {
    let token: String
    let url: String
    let title: String?
}

/// Autofill a saved credential into the active page's form.
struct WebChromeAutofillRequest: Codable, Sendable {
    let token: String
    let host: String
    let username: String
}

/// Find-in-page / find-next. `forward` is omitted by `hive.findInPage` and
/// defaults to true; `hive.findNext` always supplies it.
struct WebChromeFindRequest: Codable, Sendable {
    let token: String
    let query: String
    let forward: Bool?
}

/// Save-password decision from the web chrome banner.
struct WebChromeSavePasswordRequest: Codable, Sendable {
    let token: String
    let url: String
    let username: String
    let password: String
}

/// Permission-prompt response (allow / deny / dismiss) from the web banner.
struct WebChromePermissionResponseRequest: Codable, Sendable {
    let token: String
    let type: String?
    let response: String
}

/// Site-permission toggle from the web chrome permissions panel.
struct WebChromeSitePermissionRequest: Codable, Sendable {
    let token: String
    let permission: String
    let value: String
}

/// Translate-page hand-off (target language + source URL).
struct WebChromeTranslateRequest: Codable, Sendable {
    let token: String
    let url: String
    let to: String
}

/// Actions that optionally reference a specific tab id (openDevTools,
/// viewSource, savePage). `id` is nil when the caller omits it (active tab).
struct WebChromeOptionalIDRequest: Codable, Sendable {
    let token: String
    let id: String?
}

enum WebChromeBridgeError: Error, LocalizedError {
    case unauthorized
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Rejected bridge call: missing or invalid session token."
        case .invalidURL:   return "Rejected bridge call: URL scheme must be http or https."
        }
    }
}

