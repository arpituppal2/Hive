import Foundation

/// The explicit boundary for one Swarm context request.
///
/// A scope is data, not a prompt convention: it can be shown in diagnostics,
/// persisted in an audit record, and checked before context reaches a model.
/// A nil profile/workspace means "global-only mode". It does not mean that
/// workspace- or profile-tagged data is visible everywhere.
public struct ContextScope: Sendable, Codable, Equatable {
    public let profileID: String?
    public let workspaceID: String?
    public let projectID: String?
    public let allowedTabIDs: Set<String>
    public let includesCurrentPage: Bool
    public let includesHotMemory: Bool
    public let includesProjectNodes: Bool
    public let includesPreferences: Bool
    public let includesPrivateContent: Bool
    public let pageVisibility: HostContextPolicy.EffectiveState

    public init(
        profileID: String? = nil,
        workspaceID: String? = nil,
        projectID: String? = nil,
        allowedTabIDs: Set<String> = [],
        includesCurrentPage: Bool = true,
        includesHotMemory: Bool = true,
        includesProjectNodes: Bool = true,
        includesPreferences: Bool = true,
        includesPrivateContent: Bool = false,
        pageVisibility: HostContextPolicy.EffectiveState = .allowed
    ) {
        self.profileID = profileID
        self.workspaceID = workspaceID
        self.projectID = projectID
        self.allowedTabIDs = allowedTabIDs
        self.includesCurrentPage = includesCurrentPage
        self.includesHotMemory = includesHotMemory
        self.includesProjectNodes = includesProjectNodes
        self.includesPreferences = includesPreferences
        self.includesPrivateContent = includesPrivateContent
        self.pageVisibility = pageVisibility
    }

    private enum CodingKeys: String, CodingKey {
        case profileID, workspaceID, projectID, allowedTabIDs
        case includesCurrentPage, includesHotMemory, includesProjectNodes
        case includesPreferences, includesPrivateContent, pageVisibility
    }

    /// Keeps scopes persisted by older Hive versions valid: hot memory was
    /// implicitly included before this flag became explicit, and page context
    /// was admitted unless an older scope explicitly disabled it.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            profileID: try container.decodeIfPresent(String.self, forKey: .profileID),
            workspaceID: try container.decodeIfPresent(String.self, forKey: .workspaceID),
            projectID: try container.decodeIfPresent(String.self, forKey: .projectID),
            allowedTabIDs: try container.decodeIfPresent(Set<String>.self, forKey: .allowedTabIDs) ?? [],
            includesCurrentPage: try container.decodeIfPresent(Bool.self, forKey: .includesCurrentPage) ?? true,
            includesHotMemory: try container.decodeIfPresent(Bool.self, forKey: .includesHotMemory) ?? true,
            includesProjectNodes: try container.decodeIfPresent(Bool.self, forKey: .includesProjectNodes) ?? true,
            includesPreferences: try container.decodeIfPresent(Bool.self, forKey: .includesPreferences) ?? true,
            includesPrivateContent: try container.decodeIfPresent(Bool.self, forKey: .includesPrivateContent) ?? false,
            pageVisibility: try container.decodeIfPresent(HostContextPolicy.EffectiveState.self, forKey: .pageVisibility) ?? .allowed
        )
    }

    /// The safe browser default: current page + scoped hot memory, no private
    /// content, no implicit history or screenshot expansion.
    public static let browserDefault = ContextScope()

    /// Whether a page snapshot may enter this request.
    public func admits(page: PageContext) -> Bool {
        guard includesCurrentPage else { return false }
        guard pageVisibility == .default || pageVisibility == .allowed else { return false }
        guard !page.privateBrowsing || includesPrivateContent else { return false }
        guard allowedTabIDs.isEmpty || allowedTabIDs.contains(page.tabID) else { return false }
        return true
    }

    /// Whether a hot entry may enter this request.
    ///
    /// `isGlobal` is an explicit classification. It is required for untagged
    /// user-derived data while a profile/workspace is active; otherwise a
    /// missing tag would silently turn a page capture into cross-space memory.
    public func admits(
        profileID entryProfileID: String?,
        workspaceID entryWorkspaceID: String?,
        projectID entryProjectID: String? = nil,
        isPrivate: Bool,
        isGlobal: Bool = false
    ) -> Bool {
        guard !isPrivate || includesPrivateContent else { return false }
        if isGlobal {
            // Global is a provenance classification, not a permission bypass.
            // A tagged or private entry must never self-declare global scope.
            return entryProfileID == nil && entryWorkspaceID == nil && entryProjectID == nil && !isPrivate
        }

        // A scoped request must not admit an unscoped, non-global entry.
        if profileID != nil && entryProfileID == nil { return false }
        if workspaceID != nil && entryWorkspaceID == nil { return false }
        if projectID != nil && entryProjectID == nil { return false }

        // Global-only mode admits only global or genuinely unscoped legacy
        // entries. Tagged entries remain dormant until their scope activates.
        if profileID == nil && entryProfileID != nil { return false }
        if workspaceID == nil && entryWorkspaceID != nil { return false }
        // Project-tagged entries remain dormant until a matching project is
        // explicitly active. A workspace-wide request must not infer that a
        // project node belongs in its context merely because the workspace
        // matches.
        if projectID == nil && entryProjectID != nil { return false }

        if let requiredProfile = profileID,
           entryProfileID != requiredProfile {
            return false
        }
        if let requiredWorkspace = workspaceID,
           entryWorkspaceID != requiredWorkspace {
            return false
        }
        if let requiredProject = projectID,
           entryProjectID != requiredProject {
            return false
        }
        return true
    }

    /// Stable, human-readable diagnostics for the context-scope strip and
    /// ledger summaries. It intentionally contains identifiers, never content.
    public var diagnosticLabel: String {
        let profile = profileID ?? "global"
        let workspace = workspaceID ?? "global"
        let project = projectID ?? "none"
        let tabs = allowedTabIDs.isEmpty ? "active" : "\(allowedTabIDs.count) selected"
        let privacy = includesPrivateContent ? "private opt-in" : "private excluded"
        let page = pageVisibility == .blocked ? "page blocked" : "page visible"
        return "profile=\(profile), workspace=\(workspace), project=\(project), tabs=\(tabs), \(page), \(privacy)"
    }
}
