import Foundation

// MARK: - ResearchRecorder

/// Bridges a completed web research result into Honeycomb: persists each
/// source as a durable `.source` node (deduped by URL via `sha256(url)`),
/// then saves the cited answer as a `.brief` linked to those sources through
/// `references` edges.
///
/// This closes the SWARM-002 gap: research citations now resolve to retained
/// source objects (AGENTS.md §7.3 step 8), and the EventLedger can record
/// REAL node IDs instead of synthetic `source-<uuid>` strings that pointed at
/// nothing. The brief is the reproducible artifact — reopen it to inspect the
/// exact sources a cited answer was grounded in.
public struct ResearchRecorder: Sendable {

    private let honeycomb: HoneycombStore

    public init(honeycomb: HoneycombStore) {
        self.honeycomb = honeycomb
    }

    /// Outcome of persisting a research result.
    public struct Recording: Sendable, Equatable {
        /// Real Honeycomb node IDs for each persisted source (deduped by URL
        /// or content hash).
        public let sourceIDs: [String]
        /// The brief node ID (nil when there were no sources to ground it).
        public let briefID: String?
        /// How many sources were already known (deduped out as duplicates).
        public let duplicatedCount: Int
        /// How many sources were actually fetched/extracted (vs metadata-only).
        /// Lets the UI report honest grounding depth: a brief whose sources
        /// are mostly metadata-only has thin claim-span evidence.
        public let enrichedCount: Int
        /// Honeycomb node IDs of the Claims extracted from the answer's
        /// citations against the enriched source texts (§7.3 step 5).
        public let claimIDs: [String]
        /// How many citation markers could not be grounded to stored text
        /// (missing fetch or below the overlap threshold). Honest limitation
        /// reporting (§7.3 step 7).
        public let unmatchedCitationCount: Int
        /// Non-nil when sources/briefs were persisted but a later claim or
        /// evidence-edge write failed. IDs remain available so the caller can
        /// record the partial durable result instead of losing provenance.
        public let persistenceError: String?
    }

    /// Persists a completed research result and returns the real node IDs for
    /// the ledger plus the brief ID for reopening.
    ///
    /// Sources are deduplicated by content hash when enrichment succeeded
    /// (re-fetching the same page reuses its node), otherwise by canonical
    /// URL — re-researching the same page reuses its existing Honeycomb node
    /// instead of duplicating it. The synthesized answer is stored as a
    /// `.brief` with `references` edges to every source it cites.
    ///
    /// - Parameter enrich: optional best-effort fetch/extract of each source's
    ///   page (the SWARM-002 SourceFetcher pipeline, injected so HiveCore stays
    ///   network-free). When it returns a result, the Source records
    ///   `contentHash`, `extractedText`, `extractorVersion`, and the extracted
    ///   title (falling back to the search title). When it throws or returns
    ///   nil, the source is recorded metadata-only — a single un-fetchable
    ///   page never fails the whole research (honest degradation, §7.3).
    /// - Parameter enrichLimit: cap on how many sources get enriched per
    ///   research run. Bounds the added latency (each fetch is a real page
    ///   load); sources beyond the cap are recorded metadata-only.
    public func record(
        query: String,
        result: WebSearchResult,
        provenance: String = "swarm-research",
        enrich: (@Sendable (String) async throws -> SourceFetcher.FetchResult?)? = nil,
        enrichLimit: Int = 6
    ) async throws -> Recording {
        var sourceIDs: [String] = []
        var duplicatedCount = 0
        var enrichedCount = 0
        // Collected during the loop by SOURCE INDEX, not URL. Search providers
        // can return the same URL more than once with different snippets or
        // citation positions; URL-keyed dictionaries would overwrite the first
        // occurrence and attach a later citation to the wrong evidence.
        var enrichedTextsByIndex: [String?] = Array(repeating: nil, count: result.sources.count)
        var sourceIDsByIndex: [String] = Array(repeating: "", count: result.sources.count)

        for (index, webSource) in result.sources.enumerated() {
            // Best-effort enrichment, capped by index. A failed fetch is
            // swallowed — the metadata-only path is the honest fallback.
            var fetched: SourceFetcher.FetchResult?
            if let enrich, index < enrichLimit {
                fetched = try? await enrich(webSource.url)
                if fetched != nil { enrichedCount += 1 }
            }

            let title: String
            if let fetched, let extractedTitle = fetched.title, !extractedTitle.isEmpty {
                title = extractedTitle
            } else {
                title = webSource.title
            }

            let source = Source(
                url: webSource.url,
                title: title,
                captureMethod: "swarm-research",
                // Content hash from the actual page when fetched — the dedup
                // key becomes content-addressed (same page → same node);
                // metadata-only sources dedup by sha256(url) via toNode's
                // fallback, matching pre-enrichment behavior.
                contentHash: fetched?.contentHash,
                publishedDate: webSource.date,
                retrievalTimestamp: Date(),
                snippet: webSource.snippet,
                extractedText: fetched?.text,
                extractorVersion: fetched != nil ? "sourcefetcher-1" : nil,
                provenance: provenance
                // qualityScore deliberately nil: snippet credibility is not
                // measured yet — "not assessed" is more honest than a guess.
            )
            // createSource dedups by content hash (or sha256(url) fallback):
            // a repeat research over the same URL/content returns the existing
            // node rather than inserting a new one.
            let persisted: Source
            do {
                persisted = try await honeycomb.createSource(source)
            } catch {
                // Preserve everything committed before this source failed.
                // The caller can log a partial recording with real IDs.
                return Recording(
                    sourceIDs: sourceIDs,
                    briefID: nil,
                    duplicatedCount: duplicatedCount,
                    enrichedCount: enrichedCount,
                    claimIDs: [],
                    unmatchedCitationCount: 0,
                    persistenceError: error.localizedDescription
                )
            }
            sourceIDsByIndex[index] = persisted.id
            if let fetched {
                enrichedTextsByIndex[index] = fetched.text
            }
            if persisted.id == source.id {
                sourceIDs.append(persisted.id)
            } else {
                // Dedup hit — the existing node's ID is the durable one.
                duplicatedCount += 1
                if !sourceIDs.contains(persisted.id) {
                    sourceIDs.append(persisted.id)
                }
            }
        }

        // Save the cited answer as a durable brief linked to its sources.
        // With no sources there is nothing to ground a brief on — record it as
        // no-brief rather than fabricating an uncited artifact.
        guard !sourceIDs.isEmpty else {
            return Recording(sourceIDs: [], briefID: nil, duplicatedCount: duplicatedCount,
                             enrichedCount: enrichedCount, claimIDs: [],
                             unmatchedCitationCount: 0, persistenceError: nil)
        }

        // The brief content is the FORMATTED answer (inline markers + citation
        // footer mapping [n] → URL), not the raw provider text — reopening the
        // brief must be self-contained, exactly per §7.3 "regenerate a brief
        // from retained inputs". CitationFormatter is deterministic, so this
        // matches what the UI renders.
        let formatted = CitationFormatter.format(answer: result.answer, sources: result.sources)
        let briefContent = formatted.footer.isEmpty
            ? formatted.answer
            : formatted.answer + "\n\n" + formatted.footer

        let brief: Brief
        do {
            brief = try await honeycomb.createBrief(Brief(
                title: query,
                content: briefContent,
                sourceIDs: sourceIDs,
                provenance: provenance
            ))
        } catch {
            // Sources are already durable; retain their IDs and report the
            // brief failure as partial rather than throwing away provenance.
            return Recording(
                sourceIDs: sourceIDs,
                briefID: nil,
                duplicatedCount: duplicatedCount,
                enrichedCount: enrichedCount,
                claimIDs: [],
                unmatchedCitationCount: 0,
                persistenceError: error.localizedDescription
            )
        }
        // §7.3 step 5: deterministic claim extraction with quote/span
        // references. Each [n] marker in the answer is matched against the
        // n-th source's extracted text; the verbatim best-matching source
        // sentence becomes a Claim with an EvidenceSpan into the stored text.
        // Citations that can't be grounded are counted and reported honestly.
        var claimIDs: [String] = []
        var persistenceError: String?
        let extraction = ClaimExtractor().extractClaims(
            answer: result.answer,
            sources: result.sources.indices.map { index in
                ClaimExtractor.SourceInput(
                    sourceID: sourceIDsByIndex[index],
                    extractedText: enrichedTextsByIndex[index]
                )
            },
            provenance: provenance
        )
        for claim in extraction.claims {
            do {
                let persisted = try await honeycomb.createClaim(claim)
                // Keep the Claim ID immediately. If edge linking fails, the
                // claim itself is still durable and must remain in the partial
                // Recording for audit/provenance inspection.
                if !claimIDs.contains(persisted.id) {
                    claimIDs.append(persisted.id)
                }
                if let span = claim.evidenceSpans.first, !span.sourceID.isEmpty {
                    // Do not swallow an evidence-edge failure: the caller
                    // records the already-rendered answer as a partial durable
                    // result, rather than claiming the citation was fully
                    // grounded.
                    try await honeycomb.linkClaimToSource(claimID: persisted.id, sourceID: span.sourceID)
                }
            } catch {
                persistenceError = error.localizedDescription
                break
            }
        }

        return Recording(
            sourceIDs: sourceIDs,
            briefID: brief.id,
            duplicatedCount: duplicatedCount,
            enrichedCount: enrichedCount,
            claimIDs: claimIDs,
            unmatchedCitationCount: extraction.unmatchedCitationIndices.count,
            persistenceError: persistenceError
        )
    }
}
