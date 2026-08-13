# Hive M4 — Page Versions, Diffs, Research Trails, and Hybrid Retrieval

> **Date:** 2026-08-11
> **Status:** planning canon; no implementation is implied by this document
> **Parent plan:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Dependencies:** M0 storage/migration/recovery; M1 explicit capture; M2 source/Brief credibility; M3 candidate-only WISP
> **Primary code owners:** `Sources/HiveCore/Honeycomb/HoneycombStore.swift`, `Sources/HiveCore/Honeycomb/SourceAndClaim.swift`, `Sources/HiveCore/Browser/HotMemoryStore.swift`, `Sources/HiveCore/AI/Search/ResearchRecorder.swift`, `Sources/Hive/BrowserState+Brief.swift`, `Sources/Hive/BrowserState+Tabs.swift`, `Sources/Hive/KnowledgePanel.swift`
> **Non-dependencies:** model training, screenshots, VLM capture, promise detection, remote memory, MCP, SQLCipher, autonomous promotion
>
> M4 turns explicitly retained browser material into three trustworthy capabilities:
>
> ```text
> retained source versions → deterministic what-changed evidence
> retained source nodes + typed navigation events → research trails
> admitted source/claim/note records → lexical + semantic retrieval
> ```
>
> The browser remains useful with Swarm and memory disabled. M4 never treats a page, model output, candidate wisp, or navigation event as authority by itself.

---

## 0. Decision summary

### 0.1 M4 is four ordered slices, not one feature blob

| Slice | Produces | Depends on | Blocks |
|---|---|---|---|
| M4-A Source version identity | Immutable retained versions and provenance | M0–M3 | all later M4 work |
| M4-B Deterministic diff | Reproducible block/text changes and evidence spans | M4-A | What Changed UI |
| M4-C Research trails | Bounded `opens` edges over retained Sources | M4-A, M1 capture | Trails/brief assembly |
| M4-D Hybrid retrieval | Admission-safe FTS + embedding + RRF retrieval | M4-A, M0/M3 deletion gates | semantic memory queries |

Do not implement M4-D first because vector rows without immutable source identity and deletion/rebuild semantics create an unrecoverable second memory authority. Do not let M4-C turn ordinary browsing into automatic durable capture.

### 0.2 Existing truth versus proposed contract

**Verified/current:** Honeycomb has typed nodes/edges, standalone FTS5, revisions, content hashes, deletion/export APIs, and Source/Claim/EvidenceSpan wrappers. ResearchRecorder persists Sources, Briefs, Claims, and source links. HotMemory is scoped and admission-aware at the session layer. The current retrieval path is lexical FTS5 plus hot-memory scoring; no vector table, page-version chain, deterministic diff, temporal query API, or `opens` edge exists.

**Planned/M4:** source-version tables, diff artifacts, vector storage/rebuild, validity-window queries, one `opens` relation, bounded trail queries, and hybrid retrieval. Source prose that says these exist must remain labeled planned until implementation and fresh tests pass.

### 0.3 Non-negotiable invariants

1. A displayed change must be reproducible from two retained versions and their extractor/configuration identities.
2. A displayed citation must resolve to a retained Source node and, when a claim span is shown, to retained source text offsets or an explicit unavailable-evidence warning.
3. Candidate wisps, private records, audit-incomplete captures, unknown-scope records, and deleted records are denied before lexical/vector ranking—not filtered after prompt assembly.
4. A navigation event does not create a Source, Capture, version, vector, or durable edge when the destination has not been explicitly retained or promoted.
5. A new claim/preference version supersedes rather than mutates the prior fact; current-state queries suppress superseded/expired records, while as-of queries may retrieve them.
6. Embedding failure degrades to an honest lexical path with a visible diagnostic; it never fabricates a vector or silently changes the model/dimension.
7. Deletion removes derived indexes and M4 artifacts according to the cascade below. No UI says “forgotten” while a deleted record remains queryable through a vector, diff, trail, or cache.
8. Ordering is deterministic: every tie breaks by immutable ID after score, timestamp, and rank fields.

---

## 1. M4-A — Immutable source-version identity

### 1.1 Version identity

A Source is the durable logical resource. A SourceVersion is one retained observation of that resource. A later observation never overwrites the prior version.

Proposed schema, implemented through a versioned Honeycomb migration after M0:

```text
honeycomb_source_versions(
  version_id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL REFERENCES honeycomb_nodes(id) ON DELETE CASCADE,
  observed_url TEXT NOT NULL,
  canonical_url TEXT NOT NULL,
  title TEXT,
  extractor_id TEXT NOT NULL,
  extractor_version TEXT NOT NULL,
  normalization_version TEXT NOT NULL,
  raw_text_hash TEXT NOT NULL,
  normalized_text_hash TEXT NOT NULL,
  content_class TEXT NOT NULL,
  privacy_class TEXT NOT NULL,
  captured_at TEXT NOT NULL,
  body_text TEXT,
  body_size INTEGER NOT NULL,
  previous_version_id TEXT REFERENCES honeycomb_source_versions(version_id),
  retention_state TEXT NOT NULL,
  created_at TEXT NOT NULL
)
```

Required indexes: `(source_id, captured_at)`, `(canonical_url, captured_at)`, `normalized_text_hash`, and `previous_version_id`. A unique constraint prevents the same `(source_id, normalized_text_hash, extractor_id, normalization_version)` from producing duplicate versions. The body is optional because M1 metadata-only Sources cannot be upgraded into fabricated readable content; a version without body text is valid metadata but cannot produce a content diff or evidence span.

The implementation may store large bodies in a separate local content table or bounded blob reference, but the public contract remains one immutable version identity. It must not duplicate an entire body into multiple metadata fields.

### 1.2 URL and normalization provenance

Store both `observed_url` and `canonical_url`:

- `observed_url` is the exact URL presented by the browser/fetch boundary.
- `canonical_url` is produced by one standards-based canonicalizer and is used only for grouping/deduplication.
- The canonicalizer must explicitly define host case normalization, default ports, dot segments, fragment handling, and meaningful query parameters. It must never discard query parameters merely because they look tracking-like without an allow/deny rule.
- A redirect chain remains provenance (`requestedURL`, final observed URL, redirect count); canonicalization is not permission to hide redirects.
- Invalid/unknown URL normalization fails closed for version linking. The record may remain a metadata-only diagnostic, but it cannot silently merge with another Source.

The normalized text hash is computed after a named, deterministic normalization pipeline: Unicode normalization, line-ending normalization, whitespace policy, and extractor-defined boilerplate removal. Hash inputs include the extractor and normalization versions so a future parser change creates a new comparable version rather than rewriting history.

### 1.3 Version creation state machine

```text
received
  → validated
      ├─ private/unknown-policy → rejected
      ├─ candidate-only → candidate store; no M4 version
      ├─ metadata-only → retained version without body
      └─ retained-body
            → normalized
            → deduplicated-or-inserted
            → linked-to-previous-version
```

A version is inserted only after M0 admission, M1/M3 privacy policy, and scope checks succeed. If the body is too large, malformed, or extraction is uncertain, retain bounded metadata with `content_class = metadata_only` or reject according to policy; never truncate a body and label it complete. Every retained version records its reason and extraction state.

### 1.4 M4-A acceptance gates

- Same canonical page and same extractor/normalization identity deduplicates without losing the original observed URL.
- Same URL with changed normalized text creates a new immutable version linked to the prior version.
- A title-only or boilerplate-only change is classified deterministically and does not produce a substantive change unless the configured policy says title changes are user-visible.
- Legacy M1 metadata-only Sources remain readable and are explicitly marked as lacking diff evidence.
- Private, unknown-policy, candidate, audit-incomplete, and out-of-scope records create no SourceVersion.
- Restart/rebuild produces the same version IDs, ordering, and chain links from the same retained inputs.

---

## 2. M4-B — Deterministic What Changed

### 2.1 Input contract

`PageDiff` accepts two retained `SourceVersion` values for the same canonical URL and compatible extractor/normalization contracts. It does not inspect the live DOM, run a model, fetch the network, or infer changes from screenshots.

The normalized body is segmented into deterministic blocks before diffing. A block contains:

```text
anchor: optional extractor-provided stable key (stable DOM id/data key when present); never a model-generated identity
structural_key: heading path + sibling ordinal, useful within one version but not sufficient across moves
content_hash: deterministic hash of normalized block text
heading_path: [string]
text: string
start_offset: Int
end_offset: Int
number_tokens: [{raw, normalized, locale?}]
```

The matcher is deterministic and uses only exact, auditable rules:

1. Match unique compatible `anchor` values across versions.
2. For still-unmatched blocks, match unique `content_hash` values independent of position. An unchanged moved block is therefore recognized as moved.
3. For still-unmatched blocks, match a unique equal `structural_key` only when the block remains at the same ordinal position within the same heading path. This recognizes a modification in place while refusing to guess when surrounding structure moved.
4. Everything else remains unmatched. There is no fuzzy similarity fallback, threshold tuning, or model judgment. This deliberately reports a changed-and-moved block as removed+added unless an anchor proves continuity.

A matched block with the same `content_hash` at a new position is `moved`; a matched anchor or same-position structural key with a changed `content_hash` is `modified`; unmatched content is `added` or `removed`. No block identity is inferred from model output, and a structural key alone may never justify a move claim. Every change references `before_version_id`, `after_version_id`, block IDs, offsets, and hashes.

### 2.2 Noise and false-positive policy

Boilerplate suppression is an extractor responsibility, not a post-hoc model guess. The fixture set must include navigation, cookie banners, rotating timestamps, ads, comment counts, footers, repeated headers, and actual article changes. The policy records extractor and selector versions in the diff result.

A diff may expose:

```text
added | removed | modified | moved | numberChanged | metadataChanged
```

`numberChanged` is a derived annotation over an underlying textual modification. It must preserve raw tokens, normalized numeric value where parsing is unambiguous, locale/units when known, and an `ambiguous` flag when separators or dates make interpretation unsafe. No arithmetic claim is emitted for an ambiguous number.

### 2.3 Diff artifact contract

A completed diff is a derived artifact, not a new Source and not a replacement for either version:

```text
PageDiffResult {
  diffID: String
  canonicalURL: String
  beforeVersionID: String
  afterVersionID: String
  extractorID: String
  normalizationVersion: String
  changes: [PageChange]
  substantiveChangeCount: Int
  generatedAt: Date
  status: complete | metadata_only | unavailable | invalid_pair
}
```

Persist the result in a dedicated derived table or an `.artifact` node with a dedicated `kind = page_diff`; choose one authority during implementation and reject a second copy. The artifact is reproducible: if the algorithm version changes, create a new diff version rather than mutating the old result.

### 2.4 What Changed query semantics

`whatChanged(canonicalURL:since:until:)`:

1. Resolves only retained, eligible SourceVersions.
2. Orders versions by captured time, then immutable version ID.
3. Compares adjacent compatible versions; gaps and metadata-only versions are visible.
4. Returns evidence spans linked to the exact after-version text.
5. Says “insufficient retained text” when a version lacks body content; never fills the gap from a current fetch without an explicit user action.
6. Excludes private, candidate, deleted, and denied records before diffing.

The Knowledge UI must show “changed,” “unchanged,” and “not enough retained text” as different states. It must show the time range and version IDs in an inspectable detail view.

### 2.5 M4-B acceptance gates

- Fixture v1/v2 with navigation noise and one changed number yields only the substantive added/removed/modified change plus a safe numeric annotation.
- A moved unchanged block is `moved`, not removed+added, when the deterministic anchor/content-hash matcher proves it; changed-and-moved content without an anchor remains removed+added by policy.
- Re-running the diff is byte-for-byte/equivalent-structure deterministic.
- A parser-version change never silently compares incompatible normalization contracts.
- Deleted or private versions produce no diff; a missing body produces an honest unavailable result.
- Every rendered change can be opened to its retained source version and bounded evidence span.

---

## 3. M4-C — Typed research trails

### 3.1 One new edge, one meaning

Add exactly one new `HoneycombStore.EdgeRelation` case: `opens`. Do not add `referred`, `visited`, `related`, or freeform relation strings.

```text
Source(parent) --opens--> Source(child)
```

The edge metadata is bounded and non-authoritative:

```text
{
  "sessionID": "redacted-or-local-id",
  "workspaceID": "scope-id",
  "observedAt": "ISO-8601",
  "initiator": "user_click | user_command | approved_action",
  "observedURL": "...",
  "canonicalURL": "..."
}
```

No page prose, credentials, form values, or model output enters edge metadata. Private and unknown-policy navigation creates no durable edge.

### 3.2 Recording rule

`recordTabOpen(parent, child)` is a two-stage operation:

1. Record a redacted navigation fact in the EventLedger/recovery journal when the browser observes the event, if the applicable scope allows audit. This is not a Source or memory admission.
2. Create the `opens` edge only when both endpoints resolve to eligible retained Source nodes in the same permitted profile/workspace scope. If either endpoint is not retained, leave the fact unresolved; later explicit capture/promotion may reconcile it without replaying navigation authority.

The operation is idempotent by `(parentSourceID, childSourceID, sessionID, observedAtBucket)` plus a stable event identity. It never creates a Source merely to complete a graph edge.

### 3.3 Trail query and brief boundary

A trail query is deterministic and bounded:

- start from a retained Source or explicit user-selected tab/session;
- traverse only `opens`, with a maximum depth and node count;
- constrain by profile, workspace, session/time interval, and privacy policy;
- order by edge time, then source capture time, then immutable IDs;
- report breaks where an endpoint was not retained or was deleted;
- never cluster by model-generated topic labels in M4.

“Make brief” is an explicit user action. It consumes selected retained Sources/Claims, routes through the existing ResearchRecorder/Brief contract, and renders only citations that resolve. A trail itself never causes a brief, durable claim, task, or model context expansion.

### 3.4 M4-C acceptance gates

- Seeded retained A→B→C navigation creates exactly two typed `opens` edges and no freeform relation.
- A→private B, unknown-policy B, candidate-only B, or unretained B creates no durable edge and leaves an inspectable unresolved reason without private content.
- Replaying the same event is idempotent; different workspaces/profiles cannot cross-link.
- Deleting B removes incident edges and causes a visible trail break, not a fabricated replacement.
- Trail traversal is depth/node/time bounded and cancellation-aware.
- Explicit “Make brief” uses stored Source IDs and produces no unresolved citation silently.

---

## 4. M4-D — Hybrid retrieval with temporal validity

### 4.1 Admission-before-ranking pipeline

Every retrieval call follows this order:

```text
query + scope + asOf?
  → validate scope/privacy
  → select eligible durable records
  → lexical FTS5 top-K
  → vector top-K (if compatible index exists)
  → rank-list fusion
  → temporal validity/supersession filter
  → recency/importance tie weighting
  → deterministic ordering + token cap
  → provenance-bearing result set
```

`WispContextAdmission`, `MemoryRetrievalAdmission`, private policy, audit status, deletion/tombstone checks, profile/workspace scope, and M0 recovery state are applied before either ranking path. Candidates are not “retrieved and then hidden”; they are absent from both candidate lists.

### 4.2 Vector storage and rebuild

Add vectors only after M0 and M3 deletion gates pass:

```text
honeycomb_vectors(
  vector_id TEXT PRIMARY KEY,
  owner_kind TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  source_version_id TEXT,
  model_id TEXT NOT NULL,
  model_revision TEXT NOT NULL,
  dimension INTEGER NOT NULL,
  encoding TEXT NOT NULL,
  values BLOB NOT NULL,
  input_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(owner_kind, owner_id, model_id, model_revision, input_hash)
)
```

The implementation must validate dimension, encoding, finite values, byte length, input hash, and model revision before insertion. A model change creates a new vector generation; it does not overwrite the prior generation until the new generation passes a rebuild/coverage check. Only one generation is active for a retrieval policy at a time.

Rebuild is deterministic from retained eligible text. It skips deleted/private/candidate/audit-incomplete records, reports missing body text, supports cancellation, and can resume by input hash. A failed rebuild leaves the prior active generation intact. If no compatible active generation exists, retrieval is lexical-only and the UI/diagnostics say so.

### 4.3 Fusion and ranking contract

Use Reciprocal Rank Fusion, not raw-score addition, because FTS/BM25 and cosine scores have incompatible scales:

```text
rrf(d) = Σ 1 / (k + rank_i(d))
```

M4 defaults to `k = 60`, records the value in the result metadata, and tunes only from the locked fixture corpus. Lexical and vector lists are independently deterministic, capped at a documented K (initially 50 each). A document absent from one list contributes zero from that list.

After fusion:

- apply temporal validity and supersession rules;
- apply a bounded recency prior only when the query/scope asks for current/recent information, or use it as a documented tie-break for neutral queries;
- preserve exact-token recall: a rare identifier/name/number match must not be erased by semantic similarity;
- cap output to the Cell/token budget and include `shownCount`, `candidateCount`, and provenance.

Do not claim a universal “90%+” lift. M4 reports metrics on Hive's fixed corpus and records query categories separately: exact token, conceptual paraphrase, temporal/current-state, as-of, and mixed research.

### 4.4 Temporal validity and supersession

Claims and Preferences gain optional, versioned metadata:

```text
valid_from: ISO-8601?
valid_until: ISO-8601?
validity_state: current | expired | unknown_legacy
supersedes_node_id: String?
```

A correction creates a new node and a typed `supersedes` edge. It does not edit the old fact into the new value. `current` retrieval excludes records whose validity ended before the query time and excludes superseded targets. `asOf(t)` includes a record only when its validity window covers `t`, with explicit handling for open-ended windows. `unknown_legacy` records remain inspectable and searchable only through an explicitly labeled legacy/archival path; they are not silently treated as current authority for a current-state answer.

Temporal predicates must be applied before final prompt assembly and citations must carry the selected validity state. If two current records conflict, return both with `contradictionState = contested`; do not pick a winner merely because one has a higher embedding score.

### 4.5 M4-D acceptance gates

- A conceptual query retrieves a semantically related fixture item that lexical-only misses, without reducing exact-identifier recall beyond the agreed tolerance.
- Hybrid, lexical-only, and vector-only metrics are reported on the same frozen corpus and query set. The minimum gate is hybrid MRR and recall@10 ≥ both baselines on conceptual/mixed queries, while exact-token recall@10 is no worse than 5% relative to lexical-only. Any failure blocks promotion of the hybrid default.
- Current-state queries suppress expired/superseded facts; `asOf` retrieves the historical fact and labels it historical.
- Rebuilding vectors from the same retained inputs yields the same input hashes, dimensions, active generation, and result ordering.
- Deleting a source/version removes its vectors and makes citations/trail edges unresolved or absent according to cascade policy; no vector-only ghost remains.
- Lexical-only fallback works when the embedder is unavailable, with honest diagnostics and no fake “semantic” label.
- Retrieval meets the existing scope budgets: session <50ms cached path, project <150ms, life/hybrid <300ms excluding generation, measured on the stated M1 8GB floor with warm/cold results reported separately.

---

## 5. Deletion, retention, and rebuild semantics

### 5.1 Cascade table

| Deleted object | Required result |
|---|---|
| SourceVersion | delete its body/index/vector/diff references; preserve a redacted deletion event; later diffs show a gap |
| Source | delete all versions, incident `opens` edges, source vectors, diff artifacts; claims remain but become unverified; briefs render unresolved-source warnings |
| PageDiff artifact | delete only the derived diff; source versions remain |
| Claim | delete claim vectors/edges; briefs referencing it show missing-claim state rather than invented text |
| Trail endpoint | remove incident `opens` edges; preserve a bounded unresolved-break marker only if policy permits |
| vector generation | remove vectors for that generation; active generation changes only through a validated promotion |

Logical deletion must reach FTS, vector rows, diff artifacts, graph edges, HotMemory, ranker caches, Brief-local caches, and any rebuild manifest. EventLedger retains only the minimum redacted audit metadata required by its retention policy; it must not become a shadow content store.

### 5.2 Rebuild and crash recovery

All M4 derived stores participate in M0's storage epoch, snapshot, recovery-journal, and quarantine protocol. A source-version write plus its FTS/vector/diff updates is one local transaction where they share a database; cross-store operations are journaled and idempotent. A failed index/vector/diff update never reports the derived feature as complete.

A rebuild is safe to interrupt: it writes a generation/job record, checkpoints by input hash, and promotes only after coverage, dimension, deletion, and integrity checks pass. Restart resumes or abandons a stale job deterministically. The prior active generation remains available until promotion.

### 5.3 Privacy and unknown-state denial

M4 must deny on unknown privacy, scope, retention, deletion, or recovery state. It is safer to return “not available” than to rank an item whose eligibility cannot be proved. This applies equally to FTS, vectors, trails, diffs, Brief assembly, and export.

---

## 6. Fixture and evaluation suite

### 6.1 Frozen corpus

Create a local, synthetic, non-sensitive fixture corpus with:

- 12 page-version chains: unchanged, boilerplate-only, added paragraph, removed paragraph, modified number, moved section, parser-version change, metadata-only, malformed, private, candidate-only, deleted.
- 8 trail sessions: linear A→B→C, branching, cross-workspace, private endpoint, unresolved endpoint, duplicate replay, deleted endpoint, cycles.
- 60 retrieval records across exact identifiers, names, numbers, paraphrases, stale/current claims, contradictory facts, and source/claim/brief relationships.
- At least 40 labeled queries across exact-token, conceptual, temporal/current, as-of, and mixed categories. Labels include relevant IDs, required evidence, forbidden IDs, and expected validity state.

Fixtures contain no real browsing history, credentials, raw personal URLs, or model prompts.

### 6.2 Required metrics

| Area | Metrics |
|---|---|
| Diff | substantive precision/recall, false-positive boilerplate rate, number-change precision, deterministic replay equality |
| Retrieval | recall@5/@10, precision@10, MRR, nDCG@10, exact-token recall, conceptual recall, latest-valid accuracy |
| Trails | edge precision, duplicate rate, cross-scope leak rate, bounded traversal time |
| Grounding | citation resolution rate, evidence-span resolution rate, unresolved-warning accuracy |
| Deletion | residual FTS/vector/diff/edge count, ghost-retrieval count, cache invalidation rate |
| Runtime | p50/p95 cold/warm latency, memory peak, cancellation completion, rebuild throughput |

### 6.3 Required adversarial cases

- Prompt-injection text inside a retained page must remain untrusted data and cannot create an edge, widen scope, or alter validity.
- A private URL/title must not appear in a diff, vector, trail, citation, export, or default diagnostic.
- A malformed/ambiguous number must not produce a false arithmetic delta.
- A deleted source must not be returned by FTS or vectors after restart.
- A stale superseded preference must not outrank the current preference for a current-state query.
- A vector dimension/model mismatch must fail closed and preserve the previous active generation.
- A cancelled traversal/rebuild must leave no partial active generation or phantom edge.

---

## 7. Implementation order and stop conditions

### Task D1 — SourceVersion schema and adapter

- Add the migration and typed adapter behind Honeycomb.
- Reconcile existing Source metadata without fabricating body versions.
- Add identity, URL, normalization, privacy, scope, retention, and deletion tests.

**Stop if:** M0 recovery/snapshot participation, URL provenance, or legacy metadata-only behavior is ambiguous.

### Task D2 — Deterministic PageDiff

- Implement block segmentation, sequence/token diff, move/number annotations, evidence spans, artifact persistence, and the What Changed query contract.
- Add fixture and replay tests before UI wiring.

**Stop if:** the result depends on live network/DOM state, a model, unversioned extractor behavior, or unverifiable body text.

### Task D3 — `opens` trail edge and bounded traversal

- Update the `EdgeRelation` CaseIterable lock in the same change.
- Implement retained-endpoint reconciliation, event idempotency, bounded traversal, scope/privacy checks, deletion breaks, and explicit Make Brief inputs.

**Stop if:** ordinary navigation creates durable memory, an unresolved endpoint causes synthetic nodes, or a trail crosses profile/workspace/private boundaries.

### Task D4 — Vector generation and hybrid retrieval

- Add vector generation metadata and an injectable local embedder path.
- Implement lexical/vector lists, RRF, temporal filter, recency policy, deterministic order, lexical-only fallback, cache/rebuild state, and metric suite.

**Stop if:** vector availability, model identity, dimension, deletion, or active-generation promotion cannot be proven.

### Task D5 — Knowledge UI and citation/trail integration

- Add What Changed and Trails views only after D1–D4 fixtures pass.
- Show unavailable/insufficient/deleted/legacy states distinctly.
- Reuse ResearchRecorder/CitationFormatter and resolve every displayed citation to stored IDs.

**Stop if:** UI implies a change, trail, semantic result, or citation that the substrate cannot reproduce.

### M4 exit gate

M4 is complete only when:

1. M0–M3 dependencies have fresh evidence.
2. Source-version identity is immutable, reproducible, scoped, and deletion-aware.
3. Diff fixtures meet the locked false-positive and evidence-span thresholds.
4. Trails use only the approved `opens` relation and do not create ambient durable memory.
5. Hybrid retrieval passes category-level baseline gates and temporal correctness tests.
6. Deletion/rebuild tests find zero FTS/vector/diff/edge ghosts after restart.
7. Knowledge UI and citations expose provenance and honest unavailable states.
8. Clean-profile browser use remains functional with memory/Swarm disabled.

No status changes to `verified` are allowed from source presence alone. Record exact build, test, fixture, latency, and clean-profile evidence in AGENTS.md §18 when implementation is later executed.

---

## 8. Research references

These references inform the contract; they do not replace Hive-specific tests:

- [SQLite FTS5 extension](https://sqlite.org/fts5.html) — FTS5 ranking, maintenance, and rebuild/integrity operations.
- [SQLite transactions](https://sqlite.org/lang_transaction.html) — transaction boundaries and serialized writers.
- [SQLite WAL](https://sqlite.org/wal.html) — reader/writer behavior and checkpoint constraints.
- [SQLite Online Backup API](https://sqlite.org/backup.html) — consistent active-database snapshots.
- [Mozilla Readability](https://github.com/mozilla/readability) — reader-oriented content extraction; Hive must pin/version its own extractor contract rather than assume webpage structure.
- [DOM Standard](https://dom.spec.whatwg.org/) — DOM structure and parsing semantics; M4 stores normalized extracted evidence rather than relying on a live DOM at query time.
- [Myers diff paper](http://www.xmailserver.org/diff2.pdf) — deterministic sequence-diff foundation; implementation may choose an equivalent algorithm with replay fixtures.
- [Reciprocal Rank Fusion, Cormack, Clarke, Buettcher](https://dl.acm.org/doi/10.1145/1571941.1572114) — rank-based fusion without incompatible raw-score calibration.
- [LongMemEval](https://arxiv.org/abs/2410.10813) — long-term conversational-memory evaluation patterns; Hive uses a smaller local, provenance-labeled corpus rather than treating the benchmark as a product guarantee.
- [SQLite pragma reference](https://sqlite.org/pragma.html) — integrity checks and connection-local settings.

External research establishes useful mechanisms and failure modes. It does not establish Hive's thresholds, privacy policy, retention, or product behavior; those remain locked by the contracts and fixtures above.
