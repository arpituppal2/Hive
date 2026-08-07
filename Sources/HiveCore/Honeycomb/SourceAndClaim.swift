import Foundation

// MARK: - Source: a canonical web resource in the knowledge graph

/// A typed wrapper around `HoneycombStore.NodeType.source`. Every Source
/// represents a web resource that was fetched, extracted, and stored in
/// Honeycomb for citation and research.
///
/// Per AGENTS.md §7.1: "canonical URL, capture method, content hash,
/// author/date when known, retrieval timestamp, license/robots status."
public struct Source: Sendable, Codable, Identifiable, Equatable {
    public let id: String             // Honeycomb node ID
    public let url: String            // canonical URL
    public let title: String?         // page title
    public let captureMethod: String  // "browser-capture", "swarm-research", "user-import"
    public let contentHash: String?   // SHA-256 for deduplication
    public let author: String?
    public let publishedDate: String? // ISO8601 when known from page metadata
    public let retrievalTimestamp: Date
    public let license: String?
    public let robotsStatus: String?  // "allowed", "disallowed", "unknown"
    public let qualityScore: Double?  // 0.0–1.0 source credibility per AGENTS.md §7.3
    /// Search-result snippet at capture time — the evidence the synthesizer
    /// actually saw, preserved even when full-page fetch fails (§7.3 step 2).
    public let snippet: String?
    /// Full extracted page text when the fetch/extract pipeline succeeded
    /// (SWARM-002 SourceFetcher). The substrate claim-span extraction reads
    /// from (§7.3 step 5) — without it, EvidenceSpans have nothing to point at.
    public let extractedText: String?
    /// Which extractor produced `extractedText` ("sourcefetcher-1").
    public let extractorVersion: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let provenance: String
    /// The URL the fetch began with, when a redirect chain was followed.
    /// `url` remains the final URL stored for this Source.
    public let requestedURL: String?
    public let redirectCount: Int
    /// HTTP facts preserved from a research-boundary fetch.
    public let httpStatus: Int?
    public let contentType: String?
    public let bodySize: Int?
    /// Exact decimal wire timestamp retained alongside the Foundation Date so
    /// cross-language handoffs do not lose precision during conversion.
    public let retrievedAtUnixMS: String?
    public let expiresAtUnixMS: String?
    /// Lifecycle metadata preserved from the transport handoff. Enforcement
    /// belongs to the application/Honeycomb layer, not this value type.
    public let retentionClass: String?
    public let deletionScope: String?
    public let extractionState: String?
    public let citationReady: Bool

    // MARK: - Init

    public init(
        id: String = UUID().uuidString,
        url: String,
        title: String? = nil,
        captureMethod: String = "swarm-research",
        contentHash: String? = nil,
        author: String? = nil,
        publishedDate: String? = nil,
        retrievalTimestamp: Date = Date(),
        license: String? = nil,
        robotsStatus: String? = nil,
        qualityScore: Double? = nil,
        snippet: String? = nil,
        extractedText: String? = nil,
        extractorVersion: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        provenance: String = "swarm-research",
        requestedURL: String? = nil,
        redirectCount: Int = 0,
        httpStatus: Int? = nil,
        contentType: String? = nil,
        bodySize: Int? = nil,
        retrievedAtUnixMS: String? = nil,
        expiresAtUnixMS: String? = nil,
        retentionClass: String? = nil,
        deletionScope: String? = nil,
        extractionState: String? = nil,
        citationReady: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.captureMethod = captureMethod
        self.contentHash = contentHash
        self.author = author
        self.publishedDate = publishedDate
        self.retrievalTimestamp = retrievalTimestamp
        self.license = license
        self.robotsStatus = robotsStatus
        self.qualityScore = qualityScore.map { min(max($0, 0.0), 1.0) }
        self.snippet = snippet
        self.extractedText = extractedText
        self.extractorVersion = extractorVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provenance = provenance
        self.requestedURL = requestedURL
        self.redirectCount = max(0, redirectCount)
        self.httpStatus = httpStatus
        self.contentType = contentType
        self.bodySize = bodySize
        self.retrievedAtUnixMS = retrievedAtUnixMS
        self.expiresAtUnixMS = expiresAtUnixMS
        self.retentionClass = retentionClass
        self.deletionScope = deletionScope
        self.extractionState = extractionState
        self.citationReady = citationReady
    }

    private enum CodingKeys: String, CodingKey {
        case id, url, title, captureMethod, contentHash, author, publishedDate
        case retrievalTimestamp, license, robotsStatus, qualityScore, snippet
        case extractedText, extractorVersion, createdAt, updatedAt, provenance
        case requestedURL, redirectCount, httpStatus, contentType, bodySize
        case retrievedAtUnixMS, expiresAtUnixMS, retentionClass, deletionScope
        case extractionState, citationReady
    }

    /// Decodes older Source JSON without requiring the handoff metadata added
    /// for research transport. Existing persisted sources remain readable.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString,
            url: try c.decode(String.self, forKey: .url),
            title: try c.decodeIfPresent(String.self, forKey: .title),
            captureMethod: try c.decodeIfPresent(String.self, forKey: .captureMethod) ?? "swarm-research",
            contentHash: try c.decodeIfPresent(String.self, forKey: .contentHash),
            author: try c.decodeIfPresent(String.self, forKey: .author),
            publishedDate: try c.decodeIfPresent(String.self, forKey: .publishedDate),
            retrievalTimestamp: try c.decodeIfPresent(Date.self, forKey: .retrievalTimestamp) ?? Date(),
            license: try c.decodeIfPresent(String.self, forKey: .license),
            robotsStatus: try c.decodeIfPresent(String.self, forKey: .robotsStatus),
            qualityScore: try c.decodeIfPresent(Double.self, forKey: .qualityScore),
            snippet: try c.decodeIfPresent(String.self, forKey: .snippet),
            extractedText: try c.decodeIfPresent(String.self, forKey: .extractedText),
            extractorVersion: try c.decodeIfPresent(String.self, forKey: .extractorVersion),
            createdAt: try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(),
            updatedAt: try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(),
            provenance: try c.decodeIfPresent(String.self, forKey: .provenance) ?? "swarm-research",
            requestedURL: try c.decodeIfPresent(String.self, forKey: .requestedURL),
            redirectCount: try c.decodeIfPresent(Int.self, forKey: .redirectCount) ?? 0,
            httpStatus: try c.decodeIfPresent(Int.self, forKey: .httpStatus),
            contentType: try c.decodeIfPresent(String.self, forKey: .contentType),
            bodySize: try c.decodeIfPresent(Int.self, forKey: .bodySize),
            retrievedAtUnixMS: try c.decodeIfPresent(String.self, forKey: .retrievedAtUnixMS),
            expiresAtUnixMS: try c.decodeIfPresent(String.self, forKey: .expiresAtUnixMS),
            retentionClass: try c.decodeIfPresent(String.self, forKey: .retentionClass),
            deletionScope: try c.decodeIfPresent(String.self, forKey: .deletionScope),
            extractionState: try c.decodeIfPresent(String.self, forKey: .extractionState),
            citationReady: try c.decodeIfPresent(Bool.self, forKey: .citationReady) ?? false
        )
    }

    // MARK: - Conversion

    /// Converts this Source into a Honeycomb Node for storage.
    public func toNode() -> HoneycombStore.Node {
        // Content hash is the canonical dedup key: URL + retrieval time
        let dedupHash: String?
        if let ch = contentHash {
            dedupHash = ch
        } else {
            dedupHash = HoneycombStore.sha256(url)
        }

        var meta: [String: JSONValue] = [
            "url": .string(url),
            "captureMethod": .string(captureMethod),
            "retrievalTimestamp": .string(ISO8601DateFormatter().string(from: retrievalTimestamp)),
            "redirectCount": .int(redirectCount),
            "citationReady": .bool(citationReady)
        ]
        if let requestedURL { meta["requestedURL"] = .string(requestedURL) }
        if let httpStatus { meta["httpStatus"] = .int(httpStatus) }
        if let contentType { meta["contentType"] = .string(contentType) }
        if let bodySize { meta["bodySize"] = .int(bodySize) }
        if let retrievedAtUnixMS { meta["retrievedAtUnixMS"] = .string(retrievedAtUnixMS) }
        if let expiresAtUnixMS { meta["expiresAtUnixMS"] = .string(expiresAtUnixMS) }
        if let retentionClass { meta["retentionClass"] = .string(retentionClass) }
        if let deletionScope { meta["deletionScope"] = .string(deletionScope) }
        if let extractionState { meta["extractionState"] = .string(extractionState) }
        if let title { meta["title"] = .string(title) }
        if let author { meta["author"] = .string(author) }
        if let publishedDate { meta["publishedDate"] = .string(publishedDate) }
        if let license { meta["license"] = .string(license) }
        if let robotsStatus { meta["robotsStatus"] = .string(robotsStatus) }
        if let qs = qualityScore { meta["qualityScore"] = .double(qs) }
        if let snippet { meta["snippet"] = .string(snippet) }
        if let extractedText { meta["extractedText"] = .string(extractedText) }
        if let extractorVersion { meta["extractorVersion"] = .string(extractorVersion) }

        return HoneycombStore.Node(
            id: id,
            type: .source,
            label: title ?? url,
            metadata: .object(meta),
            contentHash: dedupHash,
            createdAt: createdAt,
            updatedAt: updatedAt,
            provenance: provenance
        )
    }

    /// Creates a Source from a Honeycomb Node. Returns nil if the node is
    /// not a `.source` type.
    public static func from(_ node: HoneycombStore.Node) -> Source? {
        guard node.type == .source else { return nil }
        let m = node.metadata
        let url: String
        if case .object(let dict) = m, case .string(let u) = dict["url"] {
            url = u
        } else {
            url = node.label  // fallback: use label as URL
        }
        return Source(
            id: node.id,
            url: url,
            title: extractString(m, key: "title"),
            captureMethod: extractString(m, key: "captureMethod") ?? "unknown",
            contentHash: node.contentHash,
            author: extractString(m, key: "author"),
            publishedDate: extractString(m, key: "publishedDate"),
            retrievalTimestamp: parseISO8601(extractString(m, key: "retrievalTimestamp")) ?? node.createdAt,
            license: extractString(m, key: "license"),
            robotsStatus: extractString(m, key: "robotsStatus"),
            qualityScore: extractDouble(m, key: "qualityScore"),
            snippet: extractString(m, key: "snippet"),
            extractedText: extractString(m, key: "extractedText"),
            extractorVersion: extractString(m, key: "extractorVersion"),
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            provenance: node.provenance,
            requestedURL: extractString(m, key: "requestedURL"),
            redirectCount: extractInt(m, key: "redirectCount") ?? 0,
            httpStatus: extractInt(m, key: "httpStatus"),
            contentType: extractString(m, key: "contentType"),
            bodySize: extractInt(m, key: "bodySize"),
            retrievedAtUnixMS: extractString(m, key: "retrievedAtUnixMS"),
            expiresAtUnixMS: extractString(m, key: "expiresAtUnixMS"),
            retentionClass: extractString(m, key: "retentionClass"),
            deletionScope: extractString(m, key: "deletionScope"),
            extractionState: extractString(m, key: "extractionState"),
            citationReady: extractBool(m, key: "citationReady") ?? false
        )
    }
}

// MARK: - Claim: an asserted fact with evidence

/// A typed wrapper around `HoneycombStore.NodeType.claim`. Every Claim
/// represents a fact asserted by Swarm research, backed by evidence spans
/// into stored Sources.
///
/// Per AGENTS.md §7.1: "text, confidence, evidence spans, freshness,
/// contradiction state."
public struct Claim: Sendable, Codable, Identifiable, Equatable {
    public let id: String
    public let text: String             // the asserted fact
    public let confidence: Double        // 0.0–1.0
    public let evidenceSpans: [EvidenceSpan]
    public let freshness: Freshness
    public let contradictionState: ContradictionState
    public let createdAt: Date
    public let updatedAt: Date
    public let provenance: String

    // MARK: - Init

    public init(
        id: String = UUID().uuidString,
        text: String,
        confidence: Double = 1.0,
        evidenceSpans: [EvidenceSpan] = [],
        freshness: Freshness = .current,
        contradictionState: ContradictionState = .uncontested,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        provenance: String = "swarm-research"
    ) {
        self.id = id
        self.text = text
        self.confidence = min(max(confidence, 0.0), 1.0)
        self.evidenceSpans = evidenceSpans
        self.freshness = freshness
        self.contradictionState = contradictionState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provenance = provenance
    }

    // MARK: - Conversion

    /// Converts this Claim into a Honeycomb Node for storage.
    public func toNode() -> HoneycombStore.Node {
        var meta: [String: JSONValue] = [
            "text": .string(text),
            "confidence": .double(confidence),
            "freshness": .string(freshness.rawValue),
            "contradictionState": .string(contradictionState.rawValue)
        ]
        if !evidenceSpans.isEmpty {
            meta["evidenceSpans"] = .array(evidenceSpans.map { $0.toJSON() })
        }

        return HoneycombStore.Node(
            id: id,
            type: .claim,
            label: text,
            metadata: .object(meta),
            contentHash: HoneycombStore.sha256(text),  // dedup by claim text
            createdAt: createdAt,
            updatedAt: updatedAt,
            provenance: provenance
        )
    }

    /// Creates a Claim from a Honeycomb Node. Returns nil if the node is
    /// not a `.claim` type.
    public static func from(_ node: HoneycombStore.Node) -> Claim? {
        guard node.type == .claim else { return nil }
        let m = node.metadata
        let text = extractString(m, key: "text") ?? node.label
        let confidence = extractDouble(m, key: "confidence") ?? 1.0
        let spans: [EvidenceSpan]
        if case .object(let dict) = m, case .array(let arr) = dict["evidenceSpans"] {
            spans = arr.compactMap { EvidenceSpan.fromJSON($0) }
        } else {
            spans = []
        }
        return Claim(
            id: node.id,
            text: text,
            confidence: confidence,
            evidenceSpans: spans,
            freshness: Freshness(rawValue: extractString(m, key: "freshness") ?? "") ?? .current,
            contradictionState: ContradictionState(rawValue: extractString(m, key: "contradictionState") ?? "") ?? .uncontested,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            provenance: node.provenance
        )
    }
}

// MARK: - EvidenceSpan: a citation pointer into a Source

/// A character-precise reference into a stored Source. Links a Claim to
/// the exact text that supports it.
///
/// AGENTS.md §7.3: "Claim extraction with quote/span references."
public struct EvidenceSpan: Sendable, Codable, Equatable {
    public let sourceID: String      // Honeycomb node ID of the Source
    public let startOffset: Int      // character offset in the extracted text
    public let endOffset: Int        // exclusive end offset
    public let quote: String?        // the exact quoted text (optional, for display)

    public init(sourceID: String, startOffset: Int, endOffset: Int, quote: String? = nil) {
        self.sourceID = sourceID
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.quote = quote
    }

    /// Serialize to JSONValue for storage in node metadata.
    public func toJSON() -> JSONValue {
        var obj: [String: JSONValue] = [
            "sourceID": .string(sourceID),
            "startOffset": .int(startOffset),
            "endOffset": .int(endOffset)
        ]
        if let quote { obj["quote"] = .string(quote) }
        return .object(obj)
    }

    /// Deserialize from JSONValue.
    public static func fromJSON(_ value: JSONValue) -> EvidenceSpan? {
        guard case .object(let dict) = value,
              case .string(let sid) = dict["sourceID"],
              case .int(let start) = dict["startOffset"],
              case .int(let end) = dict["endOffset"]
        else { return nil }
        let q: String?
        if case .string(let quote) = dict["quote"] { q = quote } else { q = nil }
        return EvidenceSpan(sourceID: sid, startOffset: start, endOffset: end, quote: q)
    }
}

// MARK: - Freshness

/// Whether a Claim is still current, has been superseded by newer research,
/// or has gone stale due to age.
public enum Freshness: String, Sendable, Codable, CaseIterable {
    case current
    case stale
    case superseded
}

// MARK: - ContradictionState

/// Whether a Claim is uncontested, has been contradicted by another Claim,
/// or has been resolved (e.g. by user review).
public enum ContradictionState: String, Sendable, Codable, CaseIterable {
    case uncontested
    case contested
    case resolved
}

// MARK: - HoneycombStore extensions for Source + Claim operations

extension HoneycombStore {

    // MARK: - Source helpers

    /// Creates a Source node from a typed Source struct. Uses content-hash
    /// deduplication so fetching the same URL twice returns the same node.
    /// - Returns: the created or deduplicated Source.
    public func createSource(_ source: Source) throws -> Source {
        let node = try insertNode(source.toNode())
        return Source.from(node) ?? source
    }

    /// Retrieves a Source by node ID.
    public func getSource(id: String) throws -> Source? {
        guard let node = try getNode(id: id) else { return nil }
        return Source.from(node)
    }

    /// Finds a Source by its canonical URL. Returns nil if not found.
    /// This is a convenience — the URL is stored in node metadata, so we
    /// search all `.source` nodes and match by metadata.url.
    public func findSource(byURL url: String) throws -> Source? {
        let sources = try getNodesByType(.source, limit: 500)
        for node in sources {
            if case .object(let dict) = node.metadata,
               case .string(let nodeURL) = dict["url"],
               nodeURL == url {
                return Source.from(node)
            }
        }
        return nil
    }

    /// Finds a Source by its content hash, which is the stable identity used
    /// by handoff reconciliation after a crash or deduplicating insert.
    public func findSource(byContentHash hash: String) throws -> Source? {
        guard let node = try findNode(type: .source, contentHash: hash) else { return nil }
        return Source.from(node)
    }

    /// Returns all Sources, ordered by creation date descending.
    public func getAllSources(limit: Int = 100) throws -> [Source] {
        try getNodesByType(.source, limit: limit).compactMap { Source.from($0) }
    }

    // MARK: - Claim helpers

    /// Creates a Claim node from a typed Claim struct. Content-hash
    /// deduplication by claim text prevents duplicate claims.
    /// - Returns: the created or deduplicated Claim.
    public func createClaim(_ claim: Claim) throws -> Claim {
        let node = try insertNode(claim.toNode())
        return Claim.from(node) ?? claim
    }

    /// Retrieves a Claim by node ID.
    public func getClaim(id: String) throws -> Claim? {
        guard let node = try getNode(id: id) else { return nil }
        return Claim.from(node)
    }

    /// Returns all Claims, ordered by creation date descending.
    public func getAllClaims(limit: Int = 100) throws -> [Claim] {
        try getNodesByType(.claim, limit: limit).compactMap { Claim.from($0) }
    }

    /// Finds Claims by full-text search over claim text.
    public func searchClaims(query text: String, limit: Int = 20) throws -> [Claim] {
        try search(query: text, limit: limit)
            .filter { $0.type == .claim }
            .compactMap { Claim.from($0) }
    }

    // MARK: - Source-Claim linking

    /// Links a Claim to a Source with a `derivedFrom` edge, marking the
    /// source as evidence for the claim. If the edge already exists, it is
    /// not duplicated.
    /// - Parameter weight: confidence weight (0.0–1.0), defaults to the claim's confidence.
    /// - Returns: the edge that was created or the existing one.
    @discardableResult
    public func linkClaimToSource(
        claimID: String,
        sourceID: String,
        weight: Double? = nil,
        relation: EdgeRelation = .derivedFrom
    ) throws -> Edge {
        if try edgeExists(from: claimID, to: sourceID, relation: relation) {
            // Return existing edge — don't duplicate
            let existing = try getEdges(from: claimID, relation: relation)
            if let found = existing.first(where: { $0.targetID == sourceID }) {
                return found
            }
        }
        let edge = Edge(
            sourceID: claimID,
            targetID: sourceID,
            relation: relation,
            weight: weight ?? 1.0,
            metadata: .object([:])
        )
        return try insertEdge(edge)
    }

    /// Returns all Sources that support a given Claim (via `derivedFrom` or
    /// `supports` edges).
    public func getSourcesForClaim(_ claimID: String) throws -> [Source] {
        var sources: [Source] = []
        for relation in [EdgeRelation.derivedFrom, .supports] {
            let edges = try getEdges(from: claimID, relation: relation)
            for edge in edges {
                if let source = try getSource(id: edge.targetID) {
                    sources.append(source)
                }
            }
        }
        return sources
    }

    /// Returns all Claims derived from a given Source.
    public func getClaimsForSource(_ sourceID: String) throws -> [Claim] {
        var claims: [Claim] = []
        for relation in [EdgeRelation.derivedFrom, .supports] {
            let edges = try getEdges(to: sourceID, relation: relation)
            for edge in edges {
                if let claim = try getClaim(id: edge.sourceID) {
                    claims.append(claim)
                }
            }
        }
        return claims
    }

    /// Marks two Claims as contradictory by creating a `contradicts` edge
    /// between them (bidirectional). Updates both Claims' `contradictionState`
    /// to `.contested` via metadata update.
    public func markContradiction(between claimA: String, and claimB: String) throws {
        // Create contradicts edge (A → B)
        if try !edgeExists(from: claimA, to: claimB, relation: .contradicts) {
            _ = try insertEdge(Edge(sourceID: claimA, targetID: claimB,
                                     relation: .contradicts, weight: 1.0))
        }
        // Update both claims to contested state
        if var a = try getClaim(id: claimA) {
            a = Claim(id: a.id, text: a.text, confidence: a.confidence,
                       evidenceSpans: a.evidenceSpans, freshness: a.freshness,
                       contradictionState: .contested,
                       createdAt: a.createdAt, provenance: a.provenance)
            _ = try updateNode(id: claimA, metadata: a.toNode().metadata)
        }
        if var b = try getClaim(id: claimB) {
            b = Claim(id: b.id, text: b.text, confidence: b.confidence,
                       evidenceSpans: b.evidenceSpans, freshness: b.freshness,
                       contradictionState: .contested,
                       createdAt: b.createdAt, provenance: b.provenance)
            _ = try updateNode(id: claimB, metadata: b.toNode().metadata)
        }
    }

    /// Returns all Claims that contradict a given Claim.
    public func getContradictingClaims(for claimID: String) throws -> [Claim] {
        let outgoing = try getEdges(from: claimID, relation: .contradicts)
        let incoming = try getEdges(to: claimID, relation: .contradicts)
        var claims: [Claim] = []
        for edge in outgoing + incoming {
            let otherID = edge.sourceID == claimID ? edge.targetID : edge.sourceID
            if let claim = try getClaim(id: otherID) { claims.append(claim) }
        }
        return claims
    }

    /// Updates a Claim's freshness (e.g. marking it as stale or superseded).
    public func updateClaimFreshness(claimID: String, freshness: Freshness) throws -> Claim? {
        guard var claim = try getClaim(id: claimID) else { return nil }
        claim = Claim(id: claim.id, text: claim.text, confidence: claim.confidence,
                       evidenceSpans: claim.evidenceSpans, freshness: freshness,
                       contradictionState: claim.contradictionState,
                       createdAt: claim.createdAt, provenance: claim.provenance)
        guard let updated = try updateNode(id: claimID, metadata: claim.toNode().metadata) else {
            return nil
        }
        return Claim.from(updated)
    }

    // MARK: - Lifecycle: delete and correction (AGENTS.md §7.2)

    /// Deletes a Source and its graph edges. Edges cascade via the
    /// `ON DELETE CASCADE` foreign keys on honeycomb_edges, so all incident
    /// edges are removed with the node.
    /// - Returns: true if a source was deleted, false if the ID didn't exist
    ///   or wasn't a `.source` node (the typed wrapper never deletes other types).
    @discardableResult
    public func deleteSource(id: String) throws -> Bool {
        guard let node = try getNode(id: id), node.type == .source else { return false }
        try deleteNode(id: id)
        return true
    }

    /// Deletes a Claim and its graph edges (evidence links, contradictions).
    /// - Returns: true if a claim was deleted, false if the ID didn't exist
    ///   or wasn't a `.claim` node.
    @discardableResult
    public func deleteClaim(id: String) throws -> Bool {
        guard let node = try getNode(id: id), node.type == .claim else { return false }
        try deleteNode(id: id)
        return true
    }

    /// Corrects a Claim's text, confidence, or evidence spans. The previous
    /// label and metadata are preserved in the revision history (AGENTS.md §8.3)
    /// before the overwrite, so corrections are auditable and revertible.
    /// - Returns: the corrected Claim, or nil if the claim doesn't exist.
    public func correctClaim(
        claimID: String,
        text: String? = nil,
        confidence: Double? = nil,
        evidenceSpans: [EvidenceSpan]? = nil
    ) throws -> Claim? {
        guard let claim = try getClaim(id: claimID) else { return nil }
        let corrected = Claim(
            id: claim.id,
            text: text ?? claim.text,
            confidence: confidence ?? claim.confidence,
            evidenceSpans: evidenceSpans ?? claim.evidenceSpans,
            freshness: claim.freshness,
            contradictionState: claim.contradictionState,
            createdAt: claim.createdAt,
            updatedAt: Date(),
            provenance: claim.provenance
        )
        guard let updated = try updateNode(id: claimID, label: corrected.text,
                                           metadata: corrected.toNode().metadata) else {
            return nil
        }
        return Claim.from(updated)
    }
}

// MARK: - Private helpers

/// Extracts a string value from a JSONValue assumed to be an object.
private func extractString(_ value: JSONValue, key: String) -> String? {
    guard case .object(let dict) = value, case .string(let s) = dict[key] else {
        return nil
    }
    return s
}

/// Extracts a double value from a JSONValue assumed to be an object.
private func extractDouble(_ value: JSONValue, key: String) -> Double? {
    guard case .object(let dict) = value, case .double(let d) = dict[key] else {
        return nil
    }
    return d
}

private func extractInt(_ value: JSONValue, key: String) -> Int? {
    guard case .object(let dict) = value, case .int(let i) = dict[key] else {
        return nil
    }
    return i
}

private func extractBool(_ value: JSONValue, key: String) -> Bool? {
    guard case .object(let dict) = value, case .bool(let b) = dict[key] else {
        return nil
    }
    return b
}

/// Parses an ISO8601 string to Date. Returns nil on failure.
private func parseISO8601(_ string: String?) -> Date? {
    guard let string else { return nil }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: string)
}
