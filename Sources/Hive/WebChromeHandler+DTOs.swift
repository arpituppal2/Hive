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

