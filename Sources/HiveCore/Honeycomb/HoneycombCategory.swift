import Foundation

// MARK: - HoneycombCategory: the conceptual facet axis

/// What a Honeycomb node is *about* — the conceptual category.
///
/// This is the **second dimension** of Hive's node identity, deliberately
/// kept distinct from `HoneycombStore.NodeType` (the *structural* type, which
/// governs edge semantics: source / claim / decision / preference …).
///
/// Why two dimensions instead of one:
///   - Perplexity (Notes/Brain) flattens memory into a single category list
///     (Work, Health, Finance, People … ~40 buckets on one md file). A node
///     can only live in one bucket, so "a decision about a person's health
///     project" forces you to pick. The category axis collapses into policy.
///   - Hive keeps them orthogonal: `NodeType` says HOW a node behaves in the
///     graph (it's a `claim` with evidence spans, or a `decision` with
///     rationale); `HoneycombCategory` says WHAT it concerns (Health, People,
///     Projects). A node carries both, so filtering "all claims about my
///     health" is a clean `(type=.claim) AND (category=.health)` intersection
///     — not a guess. Combined with typed edges (`supports`, `contradicts` …)
///     this is Type × Category × Relations: strictly richer than Perplexity's
///     1D buckets, and it is the substrate the graph view renders.
///
/// Storage: the category is written into the node's `metadata` under the
/// `"category"` key — no schema migration required, purely additive. Query
/// helpers (`getNodesByCategory`, `nodesByCategory`) scan via existing indexes
/// and intersect with `NodeType` where useful.
///
/// The vocabulary below is a superset of Perplexity's public facet list,
/// reordered into a stable taxonomy:
///   • Identity      — who the user is / holds (Bio, Accounts, License)
///   • People        — relationships, contacts, org
///   • World         — places, time, travel, events
///   • Resources     — money, things, tools (Finance, Shopping, Hardware, Tools)
///   • Work          — what the user does (Projects, Workstreams, Achievements)
///   • Knowledge     — what the user knows / learns (Concepts, Skills, Education)
///   • Life          — body, routine, taste (Health, Routine, Food, Interests)
///   • Intent        — what the user wants / decides (Goals, Preferences, Decisions)
///   • System        — Hive's own operational nodes (Swarm runs, captures)
public enum HoneycombCategory: String, Sendable, Codable, CaseIterable {

    // --- Identity ---
    case bio             // about the user themselves
    case accounts        // logged-in services / credentials (refs only)
    case license         // entitlement / plan state

    // --- People ---
    case people          // individuals, contacts, organizations
    case relationships   // how people connect (social + familial)

    // --- World ---
    case location        // places, geo
    case travel          // trips / movement
    case events          // dated occurrences (calendar-shaped)
    case time            // scheduling / temporal facts

    // --- Resources ---
    case finance         // money / assets / spending
    case shopping        // purchase intent / comparison
    case hardware        // devices / physical things
    case tools           // software / services / MCP integrations
    case food            // recipes, dietary facts, places to eat

    // --- Work ---
    case projects        // containers of related work
    case workstreams     // active flows of work
    case work            // job / role context
    case achievements    // milestones / outcomes

    // --- Knowledge ---
    case concepts        // ideas / definitions / mental models
    case entities        // named things in the world (not people)
    case skills          // abilities / competencies
    case education       // learning / courses / study
    case research        // synthesis / investigation output

    // --- Life ---
    case health          // body / medical / wellbeing
    case routine         // habits / recurring actions
    case interests       // hobbies / preferences-for-topics
    case entertainment   // media / leisure
    case communication   // messages / threads / correspondence

    // --- Intent ---
    case goals           // outcomes the user is pursuing
    case preferences     // explicit user rules / config
    case decisions       // recorded choices + rationale
    case safety          // trust / security / permissions
    case productivity    // process / efficiency

    // --- System (Hive-internal) ---
    case notes           // freeform annotations
    case social          // community / public-facing
    case swarm           // Swarm runs / Cell outputs / AI provenance
    case captures        // raw browser captures awaiting structure
    case other           // uncategorized — explicit fallback

    /// Stable grouped ordering for UI facets (the view lists these; the
    /// "All" / zero-filter root is represented by the caller passing nil).
    public static var grouped: [(label: String, categories: [HoneycombCategory])] {
        [
            ("Identity",     [.bio, .accounts, .license]),
            ("People",        [.people, .relationships]),
            ("World",         [.location, .travel, .events, .time]),
            ("Resources",    [.finance, .shopping, .hardware, .tools, .food]),
            ("Work",         [.projects, .workstreams, .work, .achievements]),
            ("Knowledge",    [.concepts, .entities, .skills, .education, .research]),
            ("Life",          [.health, .routine, .interests, .entertainment, .communication]),
            ("Intent",       [.goals, .preferences, .decisions, .safety, .productivity]),
            ("System",      [.notes, .social, .swarm, .captures, .other]),
        ]
    }

    /// Human label for facets (PascalCase → spaced). Matches the Perplexity
    /// vocabulary the user already expects, so transfer is frictionless.
    public var facetLabel: String {
        switch self {
        case .bio:             return "Bio"
        case .accounts:        return "Accounts"
        case .license:         return "License"
        case .people:          return "People"
        case .relationships:   return "Relationships"
        case .location:        return "Location"
        case .travel:          return "Travel"
        case .events:          return "Events"
        case .time:            return "Time"
        case .finance:         return "Finance"
        case .shopping:        return "Shopping"
        case .hardware:        return "Hardware"
        case .tools:           return "Tools"
        case .food:            return "Food"
        case .projects:        return "Projects"
        case .workstreams:     return "Workstreams"
        case .work:            return "Work"
        case .achievements:   return "Achievements"
        case .concepts:        return "Concepts"
        case .entities:        return "Entities"
        case .skills:          return "Skills"
        case .education:       return "Education"
        case .research:        return "Research"
        case .health:          return "Health"
        case .routine:         return "Routine"
        case .interests:       return "Interests"
        case .entertainment:   return "Entertainment"
        case .communication:   return "Communication"
        case .goals:           return "Goals"
        case .preferences:     return "Preferences"
        case .decisions:       return "Decisions"
        case .safety:          return "Safety"
        case .productivity:    return "Productivity"
        case .notes:           return "Notes"
        case .social:          return "Social"
        case .swarm:           return "Swarm"
        case .captures:        return "Captures"
        case .other:           return "Other"
        }
    }
}

// MARK: - Category on a node

extension HoneycombStore.Node {
    /// The conceptual category of this node, read from `metadata["category"]`.
    /// `.other` when unset or unrecognized — never crashes, never blocks writes.
    public var category: HoneycombCategory {
        guard case .object(let dict) = metadata,
              case .string(let raw) = dict["category"] else {
            return .other
        }
        return HoneycombCategory(rawValue: raw) ?? .other
    }

    /// Returns a copy of this node with the category set in its metadata.
    /// Non-mutating — the store owns persistence; callers insert the result.
    public func setting(category: HoneycombCategory) -> HoneycombStore.Node {
        var meta: [String: JSONValue] = (extractObject(metadata) )
        meta["category"] = .string(category.rawValue)
        return HoneycombStore.Node(
            id: id, type: type, label: label, metadata: .object(meta),
            contentHash: contentHash, createdAt: createdAt,
            updatedAt: Date(), provenance: provenance)
    }

    private func extractObject(_ v: JSONValue) -> [String: JSONValue] {
        if case .object(let d) = v { return d }
        return [:]
    }
}

// MARK: - HoneycombStore category queries (additive, no schema change)

extension HoneycombStore {

    /// Returns the category facet for a node (convenience over `Node.category`).
    public func category(of nodeID: String) throws -> HoneycombCategory {
        guard let node = try getNode(id: nodeID) else { return .other }
        return node.category
    }

    /// All nodes matching a conceptual category, newest first. Category lives in
    /// metadata, so this reads recent nodes per type via the public API and
    /// filters on the already-parsed `category` — no private SQL types touched,
    /// no re-encoding. A metadata-category index is the documented scale-up path.
    public func getNodesByCategory(_ category: HoneycombCategory,
                                   limit: Int = 200) throws -> [HoneycombStore.Node] {
        try Task.checkCancellation()
        var seen = Set<String>()
        var out: [HoneycombStore.Node] = []
        // Pull recent nodes per structural type (created_at DESC) and keep the
        // ones in this category, deduped. The per-type scan is indexed; the
        // category filter is in-memory. Order falls out of created_at sorting.
        for type in HoneycombStore.NodeType.allCases where type != .unknown {
            guard out.count < limit else { break }
            let more = try getNodesByType(type, limit: max(limit * 8, 1024))
            for n in more where n.category == category && !seen.contains(n.id) {
                out.append(n); seen.insert(n.id)
                if out.count >= limit { break }
            }
        }
        return out.sorted { $0.createdAt > $1.createdAt }.prefix(limit).map { $0 }
    }

    /// Intersection: a structural type AND a conceptual category — the query the
    /// graph view's filter chips drive (e.g. all `.claim` nodes in `.health`).
    /// The 2D lattice query Perplexity's 1D buckets cannot express.
    public func getNodes(type: HoneycombStore.NodeType,
                         category: HoneycombCategory,
                         limit: Int = 200) throws -> [HoneycombStore.Node] {
        try Task.checkCancellation()
        return try getNodesByType(type, limit: max(limit * 8, 1024))
            .filter { $0.category == category }
            .prefix(limit)
            .map { $0 }
    }

    /// Per-category counts — powers the facet sidebar ("Health 12 · Projects 7 …").
    /// Returns only categories with ≥1 node, sorted by count desc. Best-effort:
    /// samples the most recent N nodes per type; a metadata index makes this O(1).
    public func nodeCountsByCategory(sample perType: Int = 512) throws -> [(category: HoneycombCategory, count: Int)] {
        var counts: [HoneycombCategory: Int] = [:]
        for type in HoneycombStore.NodeType.allCases where type != .unknown {
            for node in try getNodesByType(type, limit: perType) {
                counts[node.category, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
}
