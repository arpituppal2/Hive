import Foundation

// MARK: - HotMemory: the running "hot" context surface

/// `HotMemoryStore` maintains a running set of "hot" Honeycomb nodes — things the
/// user has recently browsed, captured, or answered questions about. It provides
/// relevance-ranked context for queries instead of blindly shoveling raw page text
/// or entire Honeycomb search results into the context window.
///
/// ## What "hot" means
/// A node is hot when it was accessed, created, or explicitly tagged within a recent
/// time window (~15 minutes by default). Hotness decays over time and is boosted by
/// repeated access. The intent is the same as Dia's Memory: "automatically surface
/// relevant prior context without the user having to repeat themselves."
///
/// ## Relevance scoring
/// Every node in the hot set carries a composite score (0.0–1.0) derived from:
/// 1. **Recency** — how recently was this node accessed? (exponential decay, half-life 5 min)
/// 2. **Frequency** — how many times has this node been accessed in this session?
/// 3. **Explicit weight** — did the user/scribe assign a high confidence? (Honeycomb edge weight)
/// 4. **Project scope** — is this node in the same project as the current workspace?
///
/// ## Context assembly
/// When Swarm asks for context, `HotMemoryStore.assembleContext(for:)` returns:
/// - The top-K highest-scoring nodes (default 10, capped to token budget)
/// - Current page context (always included if available)
/// - Active project nodes (if the current workspace has an associated project)
///
/// ## Integration with the agent mix
/// - **Orchestrator** calls `assembleContext(for:)` before dispatching
/// - **Librarian** stores extracted entities/claims back via `didAccessNode`
/// - **MemoryCompressor** periodically prunes stale nodes and re-scores
/// - **RetrievalRanker** re-ranks nodes before they enter the prompt
///
/// This is the runtime counterpart to HoneycombStore (durable); HotMemoryStore is
/// in-memory, fast (<1ms), and scoped to the current session.
public actor HotMemoryStore {

    // MARK: - Public types

    /// A scored entry in the hot set.
    ///
    /// The entry is self-contained: it carries its own `label` and a truncated
    /// `content` snippet, so the assembled context renders REAL memory even when
    /// the Honeycomb graph is unavailable or the node was never persisted. This
    /// is what lets the AI "know what's relevant" — the memory carries its own
    /// meaning instead of an opaque UUID the caller must resolve.
    public struct HotEntry: Sendable, Codable, Identifiable {
        public let id: String              // Honeycomb node ID
        public var score: Double           // 0.0–1.0, composite relevance
        public var accessCount: Int        // how many times accessed this session
        public var lastAccessedAt: Date    // most recent access time
        public var addedAt: Date           // when this entry first entered the hot set
        public var sourceHint: String      // e.g. "browsed", "captured", "asked", "explicit"
        /// Human-readable label (page title, extracted entity, response tag).
        /// Populated at access time so context assembly never needs to resolve IDs.
        public var label: String?
        /// Short content snippet (truncated page text / extracted entity claim).
        public var content: String?
        /// The browser workspace this entry belongs to (nil = global memory,
        /// visible in every workspace — preferences and AI responses). Entries
        /// tagged to a workspace are visible only while that workspace is
        /// active, so memory never leaks across spaces.
        public var workspaceID: String?
        /// Project ownership narrows retrieval inside a workspace. A project-
        /// scoped request never guesses an entry's project from a Honeycomb
        /// edge; the provenance must travel with the hot entry.
        public var projectID: String?
        /// Profile ownership is separate from workspace ownership. A workspace
        /// normally implies a profile, but keeping both lets the broker reject
        /// malformed cross-profile entries instead of guessing.
        public var profileID: String?
        /// Private-derived entries are never admitted to ordinary context.
        public var isPrivate: Bool
        /// Explicitly classified global memory (for example a user preference
        /// or durable assistant answer). Missing scope metadata is not global.
        public var isGlobal: Bool

        public init(id: String, score: Double = 0.5, accessCount: Int = 1,
                    lastAccessedAt: Date = Date(), addedAt: Date = Date(),
                    sourceHint: String = "browsed",
                    label: String? = nil, content: String? = nil,
                    workspaceID: String? = nil, projectID: String? = nil,
                    profileID: String? = nil,
                    isPrivate: Bool = false, isGlobal: Bool = false) {
            self.id = id
            self.score = score
            self.accessCount = accessCount
            self.lastAccessedAt = lastAccessedAt
            self.addedAt = addedAt
            self.sourceHint = sourceHint
            self.label = label
            self.content = content
            self.workspaceID = workspaceID
            self.projectID = projectID
            self.profileID = profileID
            self.isPrivate = isPrivate
            self.isGlobal = isGlobal
        }

        // Forward-compatible Codable: label/content were added after the first
        // persisted format, so old entries decode with nil without breaking.
        private enum CodingKeys: String, CodingKey {
            case id, score, accessCount, lastAccessedAt, addedAt, sourceHint,
                 label, content, workspaceID, projectID, profileID, isPrivate, isGlobal
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            score = try c.decodeIfPresent(Double.self, forKey: .score) ?? 0.5
            accessCount = try c.decodeIfPresent(Int.self, forKey: .accessCount) ?? 1
            lastAccessedAt = try c.decodeIfPresent(Date.self, forKey: .lastAccessedAt) ?? Date()
            addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
            sourceHint = try c.decodeIfPresent(String.self, forKey: .sourceHint) ?? "browsed"
            label = try c.decodeIfPresent(String.self, forKey: .label)
            content = try c.decodeIfPresent(String.self, forKey: .content)
            workspaceID = try c.decodeIfPresent(String.self, forKey: .workspaceID)
            projectID = try c.decodeIfPresent(String.self, forKey: .projectID)
            profileID = try c.decodeIfPresent(String.self, forKey: .profileID)
            isPrivate = try c.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
            isGlobal = try c.decodeIfPresent(Bool.self, forKey: .isGlobal) ?? false
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(score, forKey: .score)
            try c.encode(accessCount, forKey: .accessCount)
            try c.encode(lastAccessedAt, forKey: .lastAccessedAt)
            try c.encode(addedAt, forKey: .addedAt)
            try c.encode(sourceHint, forKey: .sourceHint)
            try c.encodeIfPresent(label, forKey: .label)
            try c.encodeIfPresent(content, forKey: .content)
            try c.encodeIfPresent(workspaceID, forKey: .workspaceID)
            try c.encodeIfPresent(projectID, forKey: .projectID)
            try c.encodeIfPresent(profileID, forKey: .profileID)
            try c.encode(isPrivate, forKey: .isPrivate)
            try c.encode(isGlobal, forKey: .isGlobal)
        }
    }

    /// The assembled context for a Swarm query.
    public struct AssembledContext: Sendable {
        /// Top-K hottest nodes (scored, deduplicated, capped to token budget).
        public let hotNodes: [String]  // ordered by relevance, highest first
        /// Current page text (if available, truncated to budget).
        public let currentPage: PageContext?
        /// Active project summary (if workspace has one).
        public var projectNodes: [HoneycombStore.Node]
        /// Query-relevant user preferences. These are advisory signals, not hard filters.
        public let preferences: [PreferenceMemory]
        /// Total estimated token count (for budget tracking).
        public let estimatedTokens: Int

        public init(hotNodes: [String] = [], currentPage: PageContext? = nil,
                    projectNodes: [HoneycombStore.Node] = [],
                    preferences: [PreferenceMemory] = [],
                    estimatedTokens: Int = 0) {
            self.hotNodes = hotNodes
            self.currentPage = currentPage
            self.projectNodes = projectNodes
            self.preferences = preferences
            self.estimatedTokens = estimatedTokens
        }
    }

    // MARK: - Configuration

    /// Hot window: entries older than this without a refresh are evicted.
    public let hotWindow: TimeInterval
    /// Maximum entries in the hot set.
    public let maxHotEntries: Int
    /// Token budget for assembled context (in estimated tokens, ~4 chars/token).
    public let tokenBudget: Int
    /// Relevance decay half-life (seconds). Score halves every half-life.
    public let decayHalfLife: TimeInterval
    /// Minimum score threshold: entries below this are auto-evicted during pruning.
    /// Prevents noise from accumulating in the hot set (Perplexity/Dia-grade filter).
    public let minScoreThreshold: Double
    /// Grace period after a project switch: old-project hot entries younger than
    /// this survive eviction (the user may still be reading them); older entries
    /// are dropped so memory can't leak across projects.
    public let projectSwitchGracePeriod: TimeInterval
    /// Optional disk location for the hot-memory working set. When set, the
    /// store persists its hot entries, the forgotten set (durable privacy
    /// intent), and the active project binding so memory survives restarts.
    /// The current page context is intentionally never persisted — it is
    /// ephemeral by design.
    public let persistenceURL: URL?

    // MARK: - State

    private var hotEntries: [String: HotEntry] = [:]
    private var currentPageContext: PageContext? = nil
    /// The hot-memory node ID of the current page, if any. When the user
    /// forgets this node, the page context is cleared too — otherwise the
    /// "[Current page]" block would keep reaching the AI after the strip
    /// shows the page as untracked.
    private var currentPageNodeID: String? = nil
    private var activeProjectID: String? = nil
    /// The workspace whose tagged hot entries are visible (nil = global-only
    /// mode: workspace-tagged memory stays dormant until its space activates).
    private var activeWorkspaceID: String? = nil
    private var activeProfileID: String? = nil
    private var activeScope: ContextScope = .browserDefault
    /// Monotonically changes whenever the browser scope changes. Async context
    /// assembly captures it before graph I/O and refuses to return a snapshot
    /// assembled under an obsolete profile/workspace.
    private var scopeRevision: UInt64 = 0
    /// Node IDs the user has explicitly forgotten this session. `didAccessNode`
    /// refuses to re-add these, so "Forget this context" actually sticks — a
    /// page warm-up or tab switch can't silently resurrect forgotten memory.
    private var forgottenNodeIDs: Set<String> = []
    private let honeycomb: HoneycombStore?
    /// Debounced save task — mutations schedule a write ~1s later so bursty
    /// access (tab switches, captures) doesn't write to disk per event.
    private var saveTask: Task<Void, Never>?

    // MARK: - Init

    public init(honeycomb: HoneycombStore? = nil,
                hotWindow: TimeInterval = 900,       // 15 minutes
                maxHotEntries: Int = 50,
                tokenBudget: Int = 3000,              // ~3k tokens, Dia-parity
                decayHalfLife: TimeInterval = 300,    // 5 minutes
                minScoreThreshold: Double = 0.05,     // below this = noise
                projectSwitchGracePeriod: TimeInterval = 60,
                persistenceURL: URL? = nil) {
        self.honeycomb = honeycomb
        self.hotWindow = hotWindow
        self.maxHotEntries = maxHotEntries
        self.tokenBudget = tokenBudget
        self.decayHalfLife = decayHalfLife
        self.minScoreThreshold = minScoreThreshold
        self.projectSwitchGracePeriod = projectSwitchGracePeriod
        self.persistenceURL = persistenceURL
        if let snapshot = Self.loadSnapshot(from: persistenceURL) {
            // uniquingKeysWith makes load crash-proof: a hand-edited or
            // externally modified snapshot with duplicate IDs degrades to
            // first-wins (keeps the first occurrence, drops later ones)
            // instead of trapping in the actor's init.
            hotEntries = Dictionary(snapshot.entries.map { ($0.id, $0) },
                                    uniquingKeysWith: { first, _ in first })
            forgottenNodeIDs = Set(snapshot.forgotten)
            activeProjectID = snapshot.activeProjectID
            activeWorkspaceID = snapshot.activeWorkspaceID
            activeProfileID = snapshot.activeProfileID
            activeScope = snapshot.scope ?? ContextScope(
                profileID: snapshot.activeProfileID,
                workspaceID: snapshot.activeWorkspaceID,
                projectID: snapshot.activeProjectID
            )
        }
    }

    /// Default persistence location: `~/Library/Application Support/Hive/hot-memory.json`.
    /// The app layer passes this in; nil keeps the store purely in-memory
    /// (backward-compatible default for tests and callers that opt out).
    public static var defaultPersistenceURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("Hive", isDirectory: true)
                   .appendingPathComponent("hot-memory.json")
    }

    // MARK: - Public API

    /// Records that a Honeycomb node was accessed (browsed, captured, queried, or
    /// explicitly tagged). This bumps its score, increments access count, and
    /// updates its last-accessed timestamp. If the node isn't yet in the hot set
    /// and we're under capacity, it's added.
    /// Records that a Honeycomb node was accessed (browsed, captured, queried, or
    /// explicitly tagged). This bumps its score, increments access count, and
    /// updates its last-accessed timestamp. If the node isn't yet in the hot set
    /// and we're under capacity, it's added.
    ///
    /// - Parameters:
    ///   - label: human-readable label (page title / entity name). Stored on the
    ///     entry so context assembly can render it without a graph lookup.
    ///   - content: short content snippet (truncated page text / claim). Carried
    ///     inline so the AI sees the memory's substance, never an opaque ID.
    public func didAccessNode(id: String, sourceHint: String = "browsed",
                              label: String? = nil, content: String? = nil,
                              workspaceID: String? = nil, projectID: String? = nil,
                              profileID: String? = nil,
                              isPrivate: Bool = false) {
        recordAccess(id: id, sourceHint: sourceHint, label: label, content: content,
                     workspaceID: workspaceID, projectID: projectID, profileID: profileID,
                     isPrivate: isPrivate, isGlobal: false)
    }

    /// Records explicitly global memory. This separate API prevents ordinary
    /// page/capture callers from accidentally turning missing scope metadata
    /// into cross-profile memory. Only trusted typed stores should call it.
    public func didAccessGlobalNode(id: String, sourceHint: String,
                                    label: String? = nil, content: String? = nil) {            recordAccess(id: id, sourceHint: sourceHint, label: label, content: content,
                     workspaceID: nil, projectID: nil, profileID: nil,
                     isPrivate: false, isGlobal: true)
    }

    private func recordAccess(id: String, sourceHint: String,
                              label: String?, content: String?,
                              workspaceID: String?, projectID: String?, profileID: String?,
                              isPrivate: Bool, isGlobal: Bool) {
        // A forgotten node stays forgotten: the user explicitly told the AI to
        // not see it, so passive re-access (warm-up, tab switch) must not
        // resurrect it. Undo with `unforgetNode(id:)`.
        guard !forgottenNodeIDs.contains(id) else { return }
        // Private-derived entries may be retained only when the active scope
        // explicitly opts in. They remain excluded by default at admission and
        // are never reclassified as global.
        guard !isPrivate || activeScope.includesPrivateContent else { return }
        let now = Date()
        if var entry = hotEntries[id] {
            entry.accessCount += 1
            entry.lastAccessedAt = now
            entry.sourceHint = sourceHint
            if let label { entry.label = label }
            if let content { entry.content = content }
            if workspaceID != nil { entry.workspaceID = workspaceID }
            if projectID != nil { entry.projectID = projectID }
            if profileID != nil { entry.profileID = profileID }
            entry.isPrivate = isPrivate
            // Global classification is immutable after admission. A later
            // scoped access can enrich the entry but cannot widen its reach.
            entry.isGlobal = entry.isGlobal || isGlobal
            entry.score = computeScore(entry, now: now)
            hotEntries[id] = entry
        } else {
            if hotEntries.count >= maxHotEntries { evictColdest() }
            let entry = HotEntry(id: id, score: 0.6, accessCount: 1,
                                 lastAccessedAt: now, addedAt: now,
                                 sourceHint: sourceHint,                    label: label, content: content,
                    workspaceID: workspaceID, projectID: projectID, profileID: profileID,
                    isPrivate: isPrivate, isGlobal: isGlobal)
            hotEntries[id] = entry
        }
        scheduleSave()
    }


    /// Sets the current page context. Always included in assembled context.
    public func setCurrentPage(_ context: PageContext?) {
        setCurrentPage(context, nodeID: nil)
    }

    /// Sets the current page context together with its hot-memory node ID.
    /// Forgetting that node clears the page context too, so a forgotten page
    /// can't keep leaking into prompts via the "[Current page]" block.
    public func setCurrentPage(_ context: PageContext?, nodeID: String?) {
        guard let context else {
            currentPageContext = nil
            currentPageNodeID = nil
            return
        }
        // Apply the bound scope at acceptance time, not only during later
        // assembly. A blocked/private page must never sit in the transient
        // current-page slot waiting for a different caller to filter it.
        guard activeScope.admits(page: context),
              BrowserContextPolicy.scopePage(
                  context,
                  manifest: BrowserContextManifest(
                      includesPrivateContent: activeScope.includesPrivateContent
                  )
              ) != nil else {
            currentPageContext = nil
            currentPageNodeID = nil
            return
        }
        currentPageContext = context
        currentPageNodeID = nodeID
    }

    /// Sets the active project ID. Project-scoped nodes get a relevance boost.
    /// When the project changes, hot entries from the old project that have no
    /// recency overlap are evicted — prevents cross-project context leakage.
    /// Async: the eviction completes before this returns, so a context assembly
    /// immediately after a switch can never leak the previous project's nodes.
    public func setActiveProject(_ projectID: String?) async {
        let oldProject = activeProjectID
        activeProjectID = projectID
        activeScope = ContextScope(profileID: activeProfileID,
                                   workspaceID: activeWorkspaceID,
                                   projectID: projectID)
        scopeRevision &+= 1
        // Evict entries from the old project that aren't relevant to the new one.
        // This is the key guard against "randomly bringing parts of memory that
        // don't belong there" — Dia/Comet both isolate context per workspace.
        if let old = oldProject, projectID != old, let hc = honeycomb {
            let oldNodes = (try? await hc.getProjectNodes(projectID: old, limit: 50)) ?? []
            let oldIDs = Set(oldNodes.map { $0.id })
            let now = Date()
            for id in oldIDs {
                // Only evict if the node hasn't been accessed recently (within
                // the grace period — the user may have just switched projects
                // but still has relevant context open).
                if let entry = hotEntries[id] {
                    let age = now.timeIntervalSince(entry.lastAccessedAt)
                    if age > projectSwitchGracePeriod {
                        hotEntries.removeValue(forKey: id)
                    }
                }
            }
        }
        scheduleSave()
    }

    /// Binds hot memory to a workspace. Assembly, the scope strip, and the
    /// knowledge panel then show only that workspace's tagged entries plus
    /// global (untagged) memory; entries from other workspaces stay dormant in
    /// the set (they reappear when their space activates) and are pruned only
    /// by the normal recency decay. This is the "memory must not leak across
    /// spaces" boundary — the browser shell calls it on every space switch.
    public func setActiveWorkspace(_ workspaceID: String?) async {
        activeWorkspaceID = workspaceID
        activeScope = ContextScope(
            profileID: activeProfileID,
            workspaceID: workspaceID,
            projectID: activeProjectID
        )
        scopeRevision &+= 1
        scheduleSave()
    }

    /// Binds the complete browser scope in one operation. This is the preferred
    /// boundary for new callers; the older project/workspace setters remain for
    /// compatibility with existing shell code.
    public func setActiveScope(_ scope: ContextScope) async {
        activeScope = scope
        activeProfileID = scope.profileID
        activeWorkspaceID = scope.workspaceID
        activeProjectID = scope.projectID
        scopeRevision &+= 1
        scheduleSave()
    }

    public func currentScope() -> ContextScope {
        activeScope
    }

    /// Returns the IDs of hot entries in the current context scope, along with
    /// their scores and honest labels — used by the context-scope strip in the
    /// Gemini panel. Labels resolve to the node's real Honeycomb label when
    /// available, so a `page-` node shows its page title, never a generic
    /// "Current page" (there can be many page nodes in the hot set).
    public func currentContextScope() async -> [(id: String, score: Double, label: String)] {
        pruneAndRescore()
        let sorted = workspaceScopedEntries().sorted(by: { $0.score > $1.score }).prefix(15)
        let ids = sorted.map { $0.id }
        // Single batched lookup (one actor hop) instead of N sequential queries.
        var resolved: [String: String] = [:]
        if let hc = honeycomb, let nodes = try? await hc.getNodes(ids: ids) {
            for node in nodes where !node.label.isEmpty {
                resolved[node.id] = node.label
            }
        }
        return sorted.map { entry in
            let label: String
            // The entry's own label (set at access time) is the most accurate
            // — it carries the page title / entity name directly. The Honeycomb
            // lookup below is only a fallback for legacy entries.
            if let own = entry.label, !own.isEmpty {
                label = own
            } else if let real = resolved[entry.id] {
                label = real
            } else if entry.id.hasPrefix("page-") {
                label = "Page"
            } else if entry.id.hasPrefix("response-") {
                label = "AI response"
            } else if entry.id.hasPrefix("librarian-") {
                label = "Extracted entity"
            } else {
                label = String(entry.id.suffix(12))
            }
            return (entry.id, entry.score, label)
        }
    }

    /// Removes a node from the hot set and blocks it from re-entering for the
    /// rest of the session — the "forget this context" action from the context
    /// scope strip. Returns true if the entry existed and was removed; false
    /// means it wasn't currently hot, but the block is still recorded (a later
    /// access can't silently resurrect it). Reversed by `unforgetNode(id:)`.
    @discardableResult
    public func forgetNode(id: String) -> Bool {
        forgottenNodeIDs.insert(id)
        let removed = hotEntries.removeValue(forKey: id) != nil
        // Forgetting the current page's node must stop the page context from
        // reaching the AI entirely — otherwise the strip says "untracked"
        // while the "[Current page]" block still flows into every prompt.
        if id == currentPageNodeID {
            currentPageContext = nil
            currentPageNodeID = nil
        }
        scheduleSave()
        return removed
    }

    /// Undoes a forget: the node may re-enter the hot set the next time it is
    /// accessed. Returns true if it was previously forgotten. Note: if the
    /// forgotten node was the current page, its page context was cleared by
    /// `forgetNode` and is re-established on the next navigation.
    @discardableResult
    public func unforgetNode(id: String) -> Bool {
        guard forgottenNodeIDs.remove(id) != nil else { return false }
        scheduleSave()
        return true
    }

    /// The node IDs the user has explicitly forgotten this session — used by
    /// the context strip's "Restore" affordance.
    public func forgottenNodeIDList() -> [String] {
        Array(forgottenNodeIDs)
    }

    /// Removes a durable node from the hot set without adding it to the user's
    /// forget list. Used when a preference is superseded: the old value must stop
    /// being retrieved, but a later explicit re-selection may legitimately add it.
    public func removeNode(id: String) {
        hotEntries.removeValue(forKey: id)
        if id == currentPageNodeID {
            currentPageContext = nil
            currentPageNodeID = nil
        }
        scheduleSave()
    }

    /// Assembles the relevance-ranked context for a query. Returns the top-K
    /// hottest nodes plus the current page, capped to the token budget.
    ///
    /// - Parameter query: optional search query to further filter/bias the hot set.
    /// - Returns: `AssembledContext` ready for injection into the system prompt.
    public func assembleContext(for query: String? = nil) async -> AssembledContext {
        try? Task.checkCancellation()
        pruneAndRescore()
        let capturedScope = activeScope
        let capturedRevision = scopeRevision
        // Page-only mode must not query, rank, or touch durable hot memory at
        // all. Omitting the IDs later would still expose timing and retrieval
        // side effects to a scope that explicitly excluded saved context.
        let scored: [HotEntry] = capturedScope.includesHotMemory
            ? await scoredEntries(boost: query, scope: capturedScope)
            : []

        var remainingTokens = max(tokenBudget, 0)
        var projectNodes: [HoneycombStore.Node] = []
        var hotNodeIDs: [String] = []
        // Enforce privacy at assembly time. Callers cannot accidentally forward
        // a private page merely because they bypass the formatter.
        let permittedPage = currentPageContext.flatMap { page -> PageContext? in
            guard activeScope.admits(page: page),
                  BrowserContextPolicy.scopePage(
                    page,
                    manifest: BrowserContextManifest(
                        includesPrivateContent: capturedScope.includesPrivateContent
                    )
                  ) != nil else { return nil }
            return page
        }

        // Always include the permitted current page (≈500 tokens budgeted).
        if permittedPage != nil { remainingTokens = max(0, remainingTokens - 500) }

        // Fetch project nodes if active.
        if capturedScope.includesProjectNodes, let projectID = capturedScope.projectID, let hc = honeycomb {
            if let nodes = try? await hc.getProjectNodes(projectID: projectID, limit: 10) {
                projectNodes = nodes
                remainingTokens -= nodes.count * 100
            }
        }

        // Preferences are selected by taxonomy relevance before prompt assembly;
        // unrelated global preferences never enter this request.
        let preferences = capturedScope.includesPreferences
            ? await PreferenceMemoryBridge.relevantPreferences(
                for: query ?? "", from: honeycomb, scope: capturedScope
            )
            : []
        remainingTokens = max(0, remainingTokens - preferences.count * 45)

        // Fill remaining budget with hot nodes only when the user-selected
        // scope allows the durable working set. Page-only mode remains useful
        // without silently widening into memory.
        if capturedScope.includesHotMemory {
            for entry in scored {
                let estimatedTokens = 80 // average Honeycomb node label ≈ 320 chars = 80 tokens
                if remainingTokens < estimatedTokens { break }
                hotNodeIDs.append(entry.id)
                remainingTokens -= estimatedTokens
            }
        }

        // Graph and preference lookups above suspend this actor. If the
        // browser switched profile/workspace meanwhile, never return a mixed
        // snapshot assembled under the old scope.
        guard scopeRevision == capturedRevision else {
            return AssembledContext()
        }

        return AssembledContext(
            hotNodes: hotNodeIDs,
            currentPage: permittedPage,
            projectNodes: projectNodes,
            preferences: preferences,
            estimatedTokens: max(0, max(tokenBudget, 0) - remainingTokens)
        )
    }

    /// Returns the current hot entries, sorted by score (highest first).
    /// Useful for diagnostics and the "daily memory" surface.
    public func currentHotEntries() -> [HotEntry] {
        guard !Task.isCancelled else { return [] }
        pruneAndRescore()
        return workspaceScopedEntries().sorted(by: { $0.score > $1.score })
    }

    /// Periodic maintenance: evict stale entries, decay scores, and re-compress.
    /// Called automatically before context assembly; may also be called on a timer.
    ///
    /// Three-pass eviction:
    /// 1. Time-based: entries not accessed within the hot window are removed.
    /// 2. Score floor: entries below `minScoreThreshold` are removed (noise filter).
    /// 3. Re-score remaining entries with decay.
    public func pruneAndRescore() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-hotWindow)

        // Pass 1: Evict entries that haven't been accessed within the hot window.
        hotEntries = hotEntries.filter { $0.value.lastAccessedAt > cutoff }

        // Pass 2: Re-score and evict below score floor.
        guard !Task.isCancelled else { return }
        hotEntries = hotEntries.mapValues { entry in
            var mutable = entry
            mutable.score = computeScore(mutable, now: now)
            return mutable
        }.filter { $0.value.score >= minScoreThreshold }
    }

    /// Clears all hot entries (e.g., on workspace switch or private browsing exit).
    /// Also clears the active project binding and the forgotten set so the new
    /// workspace starts fresh. The persisted snapshot is deleted too — cleared
    /// memory must not resurrect on the next launch.
    public func clear() {
        saveTask?.cancel()
        hotEntries.removeAll()
        currentPageContext = nil
        currentPageNodeID = nil
        activeProjectID = nil
        activeWorkspaceID = nil
        activeProfileID = nil
        activeScope = .browserDefault
        scopeRevision &+= 1
        forgottenNodeIDs.removeAll()
        if let url = persistenceURL {
            try? FileManager.default.removeItem(at: url)
        }
    }



    // MARK: - Persistence

    /// Snapshot of everything that survives a restart: the hot entries, the
    /// forgotten set (durable privacy intent), and the active project binding.
    /// The current page context is ephemeral and intentionally excluded.
    private struct Snapshot: Codable, Sendable {
        let entries: [HotEntry]
        let forgotten: [String]
        let activeProjectID: String?
        let activeWorkspaceID: String?
        let activeProfileID: String?
        /// Optional keeps old hot-memory snapshots decodable while preserving
        /// selected tabs and inclusion/privacy flags for new snapshots.
        let scope: ContextScope?
    }

    /// The currently bound project ID (nil if none). Restored from disk on
    /// init when persistence is enabled. Useful for workspace bindings.
    public func activeProjectBinding() -> String? {
        activeProjectID
    }

    /// The workspace whose tagged hot memory is currently visible (nil =
    /// global-only mode). Bound by the browser shell on space switches and
    /// restored from the persisted snapshot.
    public func activeWorkspaceBinding() -> String? {
        activeWorkspaceID
    }

    /// Writes the working set to disk immediately (atomic). Public so the app
    /// can flush on quit; internally scheduled automatically after mutations.
    public func saveNow() {
        guard let url = persistenceURL else { return }
        let snapshot = Snapshot(
            entries: Array(hotEntries.values),
            forgotten: forgottenNodeIDs.sorted(),
            activeProjectID: activeProjectID,
            activeWorkspaceID: activeWorkspaceID,
            activeProfileID: activeProfileID,
            scope: activeScope
        )
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            // Best-effort: hot memory is a regenerable cache; a failed write
            // must never crash browsing.
        }
    }

    /// Debounced save: bursty access (tab switches, captures) coalesces into
    /// one disk write ~1s after the last mutation.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            await self.saveNow()
        }
    }

    /// Loads the snapshot from disk — pure file I/O with no actor state, so it
    /// is safe to call from the nonisolated init (the same pattern as the
    /// `localDB`/nonisolated helpers in HoneycombStore and EventLedgerStore).
    /// Missing files return nil. A corrupt file is left untouched on disk
    /// (recovery data is never silently destroyed); the store starts empty —
    /// hot memory rebuilds itself from Honeycomb and browsing, so a corrupt
    /// cache is regenerable.
    private nonisolated static func loadSnapshot(from url: URL?) -> Snapshot? {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(Snapshot.self, from: data)
    }

    // MARK: - Private

    /// Composite relevance score for a single entry.
    private func computeScore(_ entry: HotEntry, now: Date) -> Double {
        // 1. Recency: exponential decay from last access time
        let ageSeconds = now.timeIntervalSince(entry.lastAccessedAt)
        let recencyScore = pow(0.5, ageSeconds / decayHalfLife)

        // 2. Frequency: logarithmic bonus (capped at 5 accesses ≈ +0.15)
        let frequencyBoost = min(log2(Double(entry.accessCount + 1)) * 0.05, 0.15)

        // 3. Source hint bonus: explicit user tags are worth more than passive browses
        let sourceBoost: Double = {
            switch entry.sourceHint {
            case "explicit": return 0.10
            case "asked":    return 0.05
            case "captured": return 0.05
            default:         return 0.0
            }
        }()

        // 4. Clamp to [0, 1]
        var score = recencyScore + frequencyBoost + sourceBoost
        score = min(score, 1.0)
        score = max(score, 0.0)
        return score
    }

    /// Returns entries sorted by score, optionally boosted by FTS5 search results.
    /// Uses Honeycomb's FTS5 index to find semantically similar nodes, then
    /// boosts matching hot entries. Falls back to a word-overlap heuristic when
    /// Honeycomb is unavailable (better than the old sourceHint substring match).
    /// Returns entries sorted by relevance, with a **hard query gate**: when a
    /// query is present, entries that match it outrank ALL merely-recent entries
    /// regardless of raw hotness — this is the concrete answer to "don't
    /// randomly bring parts of memory that don't belong there." Non-matching
    /// entries are capped at the top few so hot-but-irrelevant memory can
    /// anchor the response without drowning out the actual match.
    ///
    /// Primary matching: Honeycomb FTS5 (BM25). Fallback: word-overlap against
    /// the entry's own label + ID — self-contained, works without the graph.
    private func scoredEntries(boost query: String?, scope: ContextScope) async -> [HotEntry] {
        var entries = workspaceScopedEntries(scope: scope)
        guard let query, !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return entries.sorted(by: { $0.score > $1.score })
        }

        var matchingIDs: Set<String> = []
        if let hc = honeycomb {
            // Primary path: FTS5 + BM25 ranking through Honeycomb
            if let matchingNodes = try? await hc.search(query: query, limit: 20) {
                matchingIDs = Set(matchingNodes.map { $0.id })
                for i in 0..<entries.count {
                    if matchingIDs.contains(entries[i].id) {
                        entries[i].score = min(entries[i].score + 0.15, 1.0)
                    }
                }
            }
        } else {
            // Fallback: word-overlap against the entry's own label (set at
            // access time) plus its ID — better than raw ID substring matching.
            let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
            for i in 0..<entries.count {
                let entry = entries[i]
                let text = [entry.label ?? "", entry.id]
                    .joined(separator: " ")
                    .lowercased()
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                let idWords = Set(text.split(separator: " ").map(String.init))
                let overlap = queryWords.intersection(idWords).count
                if overlap > 0 {
                    entries[i].score = min(entries[i].score + Double(overlap) * 0.05, 1.0)
                    matchingIDs.insert(entries[i].id)
                }
            }
        }

        // Hard gate: matches first (score-ordered), then a small anchor of
        // non-matching recency (so the model still knows what was just viewed).
        let matched = entries.filter { matchingIDs.contains($0.id) }
            .sorted(by: { $0.score > $1.score })
        let unmatched = entries.filter { !matchingIDs.contains($0.id) }
            .sorted(by: { $0.score > $1.score })
            .prefix(3)
        return matched + Array(unmatched)
    }

    /// Hot entries visible in the active workspace: global entries (no
    /// workspace tag) plus entries tagged to the active workspace. When no
    /// workspace is active, workspace-tagged entries stay dormant — memory can
    /// never surface outside the space it belongs to.
    private func workspaceScopedEntries(scope: ContextScope? = nil) -> [HotEntry] {
        let scope = scope ?? activeScope
        return hotEntries.values.filter { entry in
            scope.admits(
                profileID: entry.profileID,
                workspaceID: entry.workspaceID,
                projectID: entry.projectID,
                isPrivate: entry.isPrivate,
                isGlobal: entry.isGlobal
            )
        }
    }

    /// Evicts the entry with the lowest score.
    private func evictColdest() {
        guard let coldest = hotEntries.values.min(by: { $0.score < $1.score }) else { return }
        hotEntries.removeValue(forKey: coldest.id)
    }
}

// MARK: - Convenience: Context assembly for Swarm prompts

extension HotMemoryStore {

    /// Formats an already-assembled context snapshot into a plain-text block
    /// suitable for inclusion in a Swarm system prompt. When
    /// `allowingHotNodeIDs` is non-nil, hot-memory nodes are restricted to that
    /// allow-list (intersected with the assembled set inside `formatContext` —
    /// an allow-list can never expand context, only narrow it). The current
    /// page, active-project nodes, and relevant preferences are always
    /// included. This is what the orchestrator's RetrievalRanker step consumes:
    /// the model picks the IDs it considers relevant, and this formatter
    /// renders ONLY those.
    ///
    /// Rendering from the caller's snapshot (not re-assembling) is deliberate:
    /// the ranker's allow-list is validated and applied against the EXACT set
    /// the model saw, so the decision counts always match the rendered context.
    public func prompt(for assembled: AssembledContext,
                       allowingHotNodeIDs allowed: [String]? = nil) async -> String {
        let hotIDs: [String] = allowed.map { list in
            // Render in the ranker's OWN most-relevant-first order — that is
            // the point of the RetrievalRanker step — intersected with the
            // assembled set for defense-in-depth (an allow-list can never
            // introduce a node the assembly did not offer). Deduplicated.
            let assembledSet = Set(assembled.hotNodes)
            var seen = Set<String>()
            return list.filter { assembledSet.contains($0) && seen.insert($0).inserted }
        } ?? assembled.hotNodes
        return await formatContext(assembled, hotNodeIDs: hotIDs)
    }

    /// Convenience: assembles a fresh context snapshot for `query` (or the
    /// current hot set when nil), then formats it via `prompt(for:)`. Prefer
    /// `prompt(for:)` in flows that already hold a snapshot (e.g. the
    /// orchestrator's ranker step) so the allow-list is validated against the
    /// exact assembled set.
    public func assembleContextPrompt(for query: String? = nil,
                                      allowingHotNodeIDs allowed: [String]? = nil) async -> String {
        let ctx = await assembleContext(for: query)
        return await prompt(for: ctx, allowingHotNodeIDs: allowed)
    }

    /// Builds a compact numbered listing of the assembled hot nodes for the
    /// retrieval-ranker Cell: `1. <id> — <label>`. Carries real IDs so the
    /// ranker can return an allow-list, and labels so it can judge relevance by
    /// substance rather than opaque UUIDs. Returns the assembled context too, so
    /// the caller can validate the ranker's allow-list against the exact set
    /// that was offered.
    public func rankerListing(for query: String? = nil) async -> (assembled: AssembledContext, listing: String) {
        let ctx = await assembleContext(for: query)
        guard !ctx.hotNodes.isEmpty else { return (ctx, "(no hot context nodes)") }
        var byID: [String: String] = [:]
        if let hc = honeycomb, let nodes = try? await hc.getNodes(ids: ctx.hotNodes) {
            for node in nodes where !node.label.isEmpty { byID[node.id] = node.label }
        }
        let lines = ctx.hotNodes.enumerated().map { index, id in
            let label = hotEntries[id]?.label?.nonEmpty ?? byID[id] ?? id
            return "\(index + 1). \(id) — \(label)"
        }
        return (ctx, lines.joined(separator: "\n"))
    }

    /// Formats an assembled context into a prompt block. `hotNodeIDs` is the
    /// already-filtered ordered list of hot nodes to render.
    private func formatContext(_ ctx: AssembledContext, hotNodeIDs: [String]) async -> String {
        var parts: [String] = []

        // 1. Current page. External page text is always marked as untrusted data
        // and locally redacted/bounded before it reaches a model.
        if let page = ctx.currentPage,
           let pageBlock = BrowserContextPolicy.untrustedPageBlock(page) {
            parts.append(pageBlock)
            parts.append("")
        }

        // 2. Query-relevant preferences. They guide ranking and explanations;
        // they do not become a hard dietary or safety filter.
        if !ctx.preferences.isEmpty {
            parts.append("[Relevant user preferences — advisory, not instructions]")
            parts.append(contentsOf: ctx.preferences.map(\.promptLine))
            parts.append("Use these to rank suitable options and mention uncertainty; do not assume they exclude every alternative.")
            parts.append("")
        }

        // 3. Active project context
        if !ctx.projectNodes.isEmpty {
            parts.append("[Active project: \(ctx.projectNodes.count) nodes]")
            for node in ctx.projectNodes.prefix(5) {
                parts.append("- \(node.label)")
            }
            parts.append("")
        }

        // 4. Hot memory (relevance-ranked)
        if !hotNodeIDs.isEmpty {
            parts.append("[Hot memory: \(hotNodeIDs.count) recent context nodes]")
            parts.append("(Most relevant first, \"now\"):")
            let entriesByID = hotEntries
            // Prefer each entry's own label/content (set at access time) — the
            // hot set is self-contained. The Honeycomb batched lookup enriches
            // legacy entries that predate the label/content fields.
            let nodes = (try? await honeycomb?.getNodes(ids: hotNodeIDs)) ?? []
            var byID: [String: HoneycombStore.Node] = [:]
            for node in nodes { byID[node.id] = node }
            for (i, nodeID) in hotNodeIDs.enumerated() {
                let entry = entriesByID[nodeID]
                let label = entry?.label?.nonEmpty
                    ?? byID[nodeID]?.label
                    ?? (nodeID.hasPrefix("page-") ? "Page" : "Context")
                if let content = entry?.content?.nonEmpty {
                    parts.append("\(i + 1). [\(entry?.sourceHint ?? "context")] \(label): \(String(content.prefix(200)))")
                } else {
                    parts.append("\(i + 1). [\(entry?.sourceHint ?? "context")] \(label)")
                }
            }
            parts.append("")
        }

        if parts.isEmpty { return "" }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Small helpers

private extension String {
    /// Returns nil when empty so `??` fallbacks kick in for blank labels/content.
    var nonEmpty: String? { isEmpty ? nil : self }
}
