import Foundation

/// Privacy-safe display data for the context contract shown before a Swarm
/// request is sent. It contains only inclusion categories and counts; it never
/// exposes context contents, URLs, or identifiers.
public struct ContextScopeSummary: Sendable, Equatable {
    public struct Row: Sendable, Equatable, Identifiable {
        public let label: String
        public let detail: String
        public let isIncluded: Bool

        public var id: String { label }

        public init(label: String, detail: String, isIncluded: Bool) {
            self.label = label
            self.detail = detail
            self.isIncluded = isIncluded
        }
    }

    public let title: String
    public let detail: String
    public let privacyDetail: String
    public let explicitTabCount: Int
    public let rows: [Row]

    public init(
        scope: ContextScope,
        explicitTabCount: Int = 0,
        isPrivateBrowsing: Bool
    ) {
        let safeTabCount = max(0, explicitTabCount)
        self.explicitTabCount = safeTabCount

        if isPrivateBrowsing {
            title = "Private browsing"
            detail = "Context unavailable"
            privacyDetail = "Private content stays out of Swarm context"
        } else if scope.pageVisibility == .blocked {
            title = "Page context blocked"
            detail = "Current page excluded by site policy"
            privacyDetail = "Current page content will not be sent to Swarm"
        } else if scope.pageVisibility == .privateBrowsing {
            title = "Private page context"
            detail = "Current page excluded"
            privacyDetail = "Private content stays out of Swarm context"
        } else if scope.pageVisibility == .unavailable {
            title = "Page context unavailable"
            detail = "Current page excluded"
            privacyDetail = "This page cannot be shared with Swarm"
        } else if scope.includesHotMemory || scope.includesProjectNodes || scope.includesPreferences {
            title = "Workspace"
            detail = scope.includesCurrentPage
                ? "Current page + scoped memory"
                : "Scoped memory only"
            privacyDetail = "Only this workspace's approved context"
        } else if scope.includesCurrentPage {
            title = "Page only"
            detail = "Current page"
            privacyDetail = "No saved memory or project knowledge"
        } else {
            title = "No page context"
            detail = "Nothing will be sent from the browser"
            privacyDetail = "Context is disabled for this request"
        }

        rows = [
            Row(
                label: "Current page",
                detail: {
                    switch scope.pageVisibility {
                    case .blocked: return "Blocked by site policy"
                    case .privateBrowsing: return "Excluded — private content"
                    case .unavailable: return "Excluded — unavailable"
                    case .default, .allowed:
                        return scope.includesCurrentPage ? "Available to this request" : "Excluded"
                    }
                }(),
                isIncluded: scope.includesCurrentPage && (scope.pageVisibility == .default || scope.pageVisibility == .allowed)
            ),
            Row(
                label: "Scoped memory",
                detail: scope.includesHotMemory ? "Workspace-scoped" : "Excluded",
                isIncluded: scope.includesHotMemory
            ),
            Row(
                label: "Project knowledge",
                detail: scope.includesProjectNodes ? "Approved project nodes" : "Excluded",
                isIncluded: scope.includesProjectNodes
            ),
            Row(
                label: "Preferences",
                detail: scope.includesPreferences ? "Workspace-scoped" : "Excluded",
                isIncluded: scope.includesPreferences
            )
        ]
    }
}
