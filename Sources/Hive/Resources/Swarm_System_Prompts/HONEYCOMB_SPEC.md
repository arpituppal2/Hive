# HONEYCOMB_SPEC — The Durable Knowledge Substrate (Data Model Canon)

> **Canonical status:** active
> **Created:** 2026-08-11
> **Read this before:** any schema migration, retrieval feature, memory-phase implementation, or graph UI
> **Code ground truth:** `Sources/HiveCore/Honeycomb/HoneycombStore.swift` (actor, nodes/edges/FTS5/revisions), `SourceAndClaim.swift` (Source/Claim/EvidenceSpan), `BriefStore.swift`, `ProjectStore.swift`, `TaskStore.swift`, `SheetStore.swift`, `HoneycombCategory.swift`
> **Companion to:** `MEMORY_ARCHITECTURE_SPEC.md` (conversation/life memory + verbosity), `ROUTING_SPEC.md` (scopes/latency), `VISION_SPEC.md` (multimodal capture)
> **Grounded in:** 2024–2026 memory-system research — LoCoMo/LongMemEval/BEAM benchmarks, Mem0/Zep-Graphiti/Letta/Cognee patterns; the proven architecture is hybrid BM25+vector+RRF+rerank+recency over an add-only ledger with bi-temporal invalidation (see `RESEARCH/competitive-megadossier.md` §32)

## 0. The Thesis

**Honeycomb is the substrate, not a feature.** Every absorbed job (capture, reading, research, projects, tasks, promises, sheets, media) is a typed node in one graph; every relationship is a typed edge; every change is revisioned; every deletion cascades. The flat JSON MemoryStore and the Markdown WikiStore are transitional — Honeycomb is the migration target (DEC-009), and this spec is the contract.

**Three non-negotiables:**
1. **Parameterized SQL only.** No string-built SQL anywhere (existing invariant — keep it).
2. **Append-only with revisions.** Facts are never destroyed in place; new nodes supersede old ones (`supersedes` edge); revisions preserve the audit trail.
3. **Delete-by-scope.** Every node type has defined cascade semantics; deletion removes from local disk, indexes, model queues, and logs.

## 1. The Node Model (existing, verified)

From `HoneycombStore.swift:28` — `Node` is Sendable/Codable/Identifiable/Equatable with: `id`, `label`, `type`, `metadata` (JSONValue), `contentHash`, `createdAt`, `updatedAt`, `provenance`.

### 1.1 NodeType (existing — `HoneycombStore.swift:58`)

| Type | Meaning | Required metadata keys |
|---|---|---|
| `source` | canonical URL + retrieval metadata | `url`, `title`, `retrievedAt`, `contentHash`, `extractorVersion` |
| `capture` | extracted page text / selection | `content`, `selection?`, `captureMethod` (dom/vision/manual), `privacyClass` |
| `claim` | asserted fact with evidence spans | `text`, `confidence`, `evidenceSpans`, `freshness` |
| `artifact` | generated file, diff, table, image | `kind`, `contentRef`, `derivedFromRefs` |
| `project` | container for related work | `title`, `purpose`, `lifecycle` |
| `task` | actionable item with state | `title`, `state`, `dueDate?`, `sourceLink?` |
| `brief` | synthesized research output | `content`, `summary`, `scope` |
| `decision` | recorded choice with rationale | `content`, `rationale`, `options[]` |
| `question` | open question awaiting resolution | `content`, `status` |
| `preference` | explicit user rule | `content`, `scope`, `expiry?` |
| `note` | freeform user annotation | `content` |
| `unknown` | fallback | — |

### 1.2 EdgeRelation (existing — `HoneycombStore.swift:119`)

`supports`, `contradicts`, `belongsTo`, `derivedFrom`, `references`, `dependsOn`, `supersedes`, `annotates`, `nextAction`, `answers`, `questions` — typed, `CaseIterable` (tests lock the set).

### 1.3 Storage (existing)

- `honeycomb_nodes`, `honeycomb_edges`, `honeycomb_revisions` tables, versioned append-only migrations (`HoneycombStore.swift:188–240`).
- `honeycomb_fts` — standalone FTS5 virtual table (BM25 via `search(query:)` at `:639`).
- Dedupe: `findNode(type:contentHash:)` (`:541`); source dedupe: `findSource(byContentHash:)` / `findSource(byURL:)` (`SourceAndClaim.swift:437/451`).
- Revision history: `getRevisions(nodeID:)` (`:446`).
- Cascade: `deleteNode`, `deleteByProvenance`, `deleteOlderThan` (`:466/:730/:757`).

## 2. The Claim & Source Contract (existing, verified)

From `SourceAndClaim.swift`:
- `Source` (`:11`) → `toNode()` (`:164`): url, title, retrieval timestamp, content hash, extractor version, license/robots status when known.
- `Claim` (`:263`) → `toNode()` (`:301`): text, confidence, `EvidenceSpan` (`:357` — quote/span references into the source).
- `linkClaimToSource` (`:497`) creates the `supports` edge; `getSourcesForClaim` / `getClaimsForSource` (`:522/:536`).
- Contradiction ledger: `markContradiction` (`:552`), `getContradictingClaims` (`:576`).
- Freshness: `updateClaimFreshness(claimID:freshness:)` (`:588`).
- Correction (not destruction): `correctClaim` (`:628`) — supersedes the old claim, preserves revision.

**The citation invariant:** a rendered citation is valid **iff** it resolves through `getSourcesForClaim(claimID:)` to a stored Source node. No citation may be synthesized from model prose (AGENTS.md §11.1; enforced by B3 citation hardening).

## 3. Brief / Project / Task / Sheet contracts (existing, verified)

- `BriefStore`: create/search/update/delete + `linkBriefToSource` → `derivedFrom` + `exportMarkdown` (`:17–114`).
- `ProjectStore`: lifecycle model, `addTaskToProject`, `getProjectTasks`, `exportProject` (`:11–106`).
- `TaskStore`: `getActionInbox` (`:46`), state machine (`completeTask`), `linkSourceToTask`, `addDependency` → `dependsOn` (`:13–152`).
- `SheetStore`: typed tables (P3); rows carry `source` provenance (SHEET-001).

**The demo chain (from the YC demo spine) is fully expressible in this model:** sources → claims (via `supports`) → brief (via `derivedFrom` + `linkBriefToSource`) → project (`belongsTo`) → decisions/questions → tasks (`nextAction`) → code run (artifact via `derivedFrom`, `dependsOn`).

## 4. Extension Contracts (what later milestones add — the deltas)

> **Execution precedence:** `docs/superpowers/plans/2026-08-11-m4-diffs-trails-hybrid-retrieval-plan.md` is the detailed M4 contract. The older Phase A wording below is product scope, not permission to bypass M0/M1/M2/M3 gates. M4 uses a dedicated SourceVersion/diff contract, one approved `opens` edge, admission-before-ranking, and versioned vector generations. It does not add a Honeycomb `.wisp` node or treat candidates as durable memory.

### 4.1 Vector search (M4-D — the missing half of hybrid retrieval)
Current `search` is FTS5-only. The MEMORY_ARCHITECTURE_SPEC §3 contract requires BM25 + embeddings + recency with RRF fusion. The older single-vector-per-node sketch is superseded by the versioned-generation contract in `docs/superpowers/plans/2026-08-11-m4-diffs-trails-hybrid-retrieval-plan.md` §4.2. Implementers must use that contract, not this historical shorthand.

At minimum, the M4 vector authority records:

```
honeycomb_vectors(
  vector_id, owner_kind, owner_id, source_version_id?,
  model_id, model_revision, dimension, encoding, values,
  input_hash, created_at,
  UNIQUE(owner_kind, owner_id, model_id, model_revision, input_hash)
)
```

Vector generations are validated, rebuildable, deletion-aware, and promoted only after coverage/integrity checks. A failed generation leaves the prior active generation intact. If no compatible active generation exists, retrieval falls back honestly to FTS5-only.

Retrieval pipeline (implemented behind `searchHybrid(query:limit:)`):
1. FTS5 BM25 top-K (existing).
2. Compatible active-generation vector top-K (new; brute-force at personal scale is an implementation choice, not a product guarantee).
3. **RRF fusion** of the two rank lists.
4. Admission, temporal validity, recency policy, and deterministic tie-breaking.
5. Optional local rerank over a bounded top-K only after measured evidence and an explicit model/runtime contract.

### 4.2 Temporal validity (the anti-staleness contract)
`Claim` and `Preference` nodes gain optional `validFrom`/`validUntil` in metadata (bi-temporal: also keep `createdAt`/`supersedes`). Rules:
- A new fact NEVER edits an old one — it creates a node and a `supersedes` edge (already supported: `supersedes` relation + `correctClaim`).
- Retrieval weights validity: `validUntil < now` ⇒ decayed; `supersedes` target ⇒ suppressed unless explicitly requested ("what did we believe in March?").
- Contradiction detection (existing `markContradiction`) stays retrieval-time, not write-time — matching the proven add-only pattern.

### 4.3 Capture pipeline schema (A1 — planned wisp → source)
A capture writes **at most one Source + one Capture** per page visit (dedupe via `findSource(byContentHash:)`), plus optional Claims from extraction. EventLedger records `capture_created` with provenance. Private-mode captures are refused unless explicit opt-in (label `privacyClass: "private-opted-in"`).

The current `HoneycombStore.NodeType` enum has 11 production types listed in §1.1; `.wisp` is **not** one of them and M3 explicitly rejects adding it. Candidate rows live in the dedicated M0-integrated candidate store and are excluded from Honeycomb retrieval, FTS/vector indexes, export, Briefs, and trails until explicit promotion. A promoted candidate reuses the existing `source` contract through the M1 promotion path; it does not bypass source-version identity or audit admission. Any referrer relationship requires the separately approved `opens` EdgeRelation migration; call sites must not invent a relation string.

### 4.4 Research trails (M4-C — the planned `opens` edge)
Add one deliberate case to `EdgeRelation`: `opens` (tab A opened tab B). The enum is `CaseIterable` — the set-locking test must be updated in the same commit. Trail clustering queries `getEdges(from:relation:.opens)` transitively; an investigation becomes a project with `belongsTo` edges.

### 4.5 Delete cascade (M4/M5 boundary — the forget contract)
`deleteNode` must cascade by relation type:
- `derivedFrom` targets: children deleted (or orphaned with provenance, per policy).
- `supports` claims: claims remain but become `unverified` (their source is gone) — never silently deleted.
- `belongsTo` children of a deleted project: cascade to the action inbox or quarantine, with an EventLedger record.
- Full sweep: `deleteByProvenance` (one capture source wipes its derived nodes) + `deleteOlderThan` (retention pruning, 6-month default).

## 5. Retrieval Latency & Scope Budgets

Per ROUTING_SPEC §4 (scope determines assembly) + §3 (SLA):

| Scope | Retrieval path | Budget |
|---|---|---|
| single-shot | none (no memory retrieval) | — |
| session | fresh-tail (cached) + compacted summary | <50ms |
| project | project subgraph (`getProjectNodes` + neighbors depth 2) | <150ms |
| life | hybrid search (FTS5 + vectors + recency, capped) | <300ms + generation |

Assembled context must fit the Cell context budget (MODEL_SPEC §1.3); truncation carries provenance ("3 of 17 matches shown"), never silent.

## 6. Migration & Interop

- WikiStore (Markdown + backlinks) → Honeycomb: import as `note`/`source` nodes with `derivedFrom` edges to their origin files; backlinks become `references` edges. Lossless round-trip tests required (DATA-002).
- Flat JSON MemoryStore → Honeycomb: typed mapping with content-hash dedupe; rollback path retained for one release.
- Export: `exportMarkdown(node:)` + project/brief exporters already exist; a full-graph export (JSON/SQLite bundle) is the A6 MCP-read-only companion.

## 7. Eval Hooks (what must be tested)

- **Dedupe invariant:** re-capturing the same page produces zero new Source nodes (fixture).
- **Citation invariant:** every rendered citation resolves via `getSourcesForClaim` (fixture sweep — already partially in ClaimExtractorTests).
- **Hybrid beats single:** `searchHybrid` ≥ FTS5-only and ≥ vector-only on the local corpus (precision@10, recall@10, MRR) — new fixture suite.
- **Temporal correctness:** superseded facts don't surface for "current state" queries; do surface for as-of queries.
- **Cascade completeness:** deleting a Source leaves claims `unverified`, deletes derived artifacts, and logs every removal.
- **Edge-set lock:** adding `opens` updates the CaseIterable test in the same commit.
- **Private guard:** private captures are refused without opt-in; opted-in captures are labeled and deletable.

## 8. What This Means for Execution

Phase A1–A6 become schema-confined deltas, not greenfield:
- A1 = §4.3 pipeline over existing Source/Capture types
- A2 = §4.1 vectors + §4.2 validity
- A3 = promises as Task nodes with `nextAction` edges (existing types)
- A4 = §4.4 one new edge case + clustering queries
- A5 = digest = retrieval + reinforcement writes (§4.2, MEMORY_ARCHITECTURE_SPEC §2.3)
- A6 = §4.5 cascade + SQLCipher at rest + MCP read-only
Every delta is testable against the existing 1,912-test suite plus new fixtures.
