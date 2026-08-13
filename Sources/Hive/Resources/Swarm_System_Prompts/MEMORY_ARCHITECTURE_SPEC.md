# MEMORY_ARCHITECTURE_SPEC — Conversation & Life Memory Canon

> **Canonical status:** active
> **Created:** 2026-08-11
> **Read this before:** building any conversation Cell, the Swarm chat model, Honeycomb retrieval, the nightly digest, or the MCP server
> **Companion to:** `ROUTING_SPEC.md` (scopes, tiers, latency), `MODEL_SPEC.md` (training), `00_INDEX.md` (roster), `docs/superpowers/plans/2026-08-11-m5-digest-promises-forgetting-retention-plan.md` (M5 execution authority)
> **Grounded in:** 2024–2026 memory-system research (LoCoMo/LongMemEval/BEAM benchmarks, Mem0/Zep/Graphiti/Letta patterns, Rewisp forgetting curves) — full synthesis in `RESEARCH/competitive-megadossier.md` §12/§32

## 0. The Thesis

**One memory, many views.** Conversation memory, project knowledge, research sources, and life memory all live in one durable substrate (Honeycomb + EventLedger). The assistant never *re-reads* what it already *knows* — it retrieves the minimal evidence needed, in the smallest context that answers.

**The verbosity law (research-backed):** users punish explicit meta-commentary ("I remember from your memory that…"). Memory must be **inwoven implicitly** — the response uses what it knows without announcing the mechanism. The memory *is* visible — in a settings drawer, a memory page, an approval loop — but the conversation itself never narrates it.

## 1. Conversation Memory (within a chat)

Four layers, per the proven local-first pattern (fresh tail → compaction → dreaming → graph):

```
┌────────────────────────────────────────────────────────────┐
│  1. FRESH TAIL    last N turns, VERBATIM (no loss)          │
│  2. COMPACTION    older turns → lossy summary, rewritten    │
│                    only when evicted from the tail          │
│  3. DREAMING      background consolidation (idle):          │
│                    turns → claims/decisions/promises →      │
│                    durable Honeycomb nodes with provenance  │
│  4. LIFE MEMORY   temporal knowledge graph, retrieved       │
│                    on demand (never pre-loaded wholesale)   │
└────────────────────────────────────────────────────────────┘
```

### 1.1 Fresh tail
- Keep the last N turns verbatim (N per Cell context budget; e.g., 1B conversation = 8–12 turns, 8B = up to 24).
- The tail is **prefix-cached** (ROUTING_SPEC §3.1) so continuation is near-instant.
- Nothing in the tail is ever summarized in-place — compaction only happens at eviction.

### 1.2 Compaction
- On eviction, older turns fold into a **hierarchical summary** (per-session, then per-topic), written as a Claim node with a pointer to the raw source (the conversation Source) — the raw transcript is never destroyed, only de-prioritized.
- **Anti-drift rule:** summaries are regenerated from raw turns, never from previous summaries. No summary-of-a-summary chains (the known compounding-distortion failure mode).
- Every compacted summary carries `generated_at` + freshness, so retrieval can prefer newer evidence.

### 1.3 Dreaming (background consolidation)
- During idle (battery-aware, thermal-aware, never during active typing), a consolidation pass may prepare **proposals** from recent turns:
  - **Decisions** → proposed Project decision nodes
  - **Promises/commitments** → `PromiseCandidate` records with exact evidence spans and bounded date resolution
  - **Preferences** → proposed Preference records — **only after the approval loop** (facts wait for approval before they're kept)
  - **Entities** → proposed People/Project/Technology relations with temporal validity windows
- Dreaming never writes a durable Task, Claim, Preference, or other user-memory object directly from model/parser output. Promotion requires the M5 approval contract and, for durable capture, the M1 audit boundary.
- Dreaming is idempotent: re-running on the same turns produces no duplicate proposals (stable source/evidence identity).
- The ledger records each consolidation attempt without raw private content; unavailable evidence or storage yields a visible incomplete state.

### 1.4 Conversation scope routing
Per ROUTING_SPEC §4: single-shot / session / project / life. Scope decides how much of this layer enters context. A project-scoped chat assembles project memory (sources, claims, decisions, tasks) + fresh tail; a life-scoped query assembles hybrid retrieval results instead.

## 2. Life Memory (the Honeycomb graph)

### 2.1 Object model (per AGENTS.md §7.1)
Source → Capture → Claim → Artifact → Project/Task/Flow/Action — typed nodes + typed directed edges (`belongsTo`, `derivedFrom`, `references`, `nextAction`, `opens` for research trails), each with creation/update time, provenance, retention, and delete semantics. Already built and tested (`HoneycombStore`, `SourceAndClaim`).

### 2.2 Temporal validity (the anti-staleness rule; M4-D execution contract)
Every Claim/Preference node carries a **validity window** (start, end-optional). Facts are *true until changed* — the change creates a new node, never an in-place edit (revision history is append-only). Retrieval weights by:
1. Relevance (hybrid score)
2. Freshness (validity window vs now)
3. Recency (decay — old content must be *clearly* relevant to surface)
4. Reinforcement (user asked about it / approved it → boosted, exempted from expiry)

### 2.3 Reinforcement & forgetting (M5 execution contract)
- **Decay:** unpinned eligible durable nodes may become retrieval-ineligible after the configured default window; decay is not physical deletion.
- **Pin/approve:** explicit user approval or pin is the strongest retention signal and is visible/reversible.
- **Rescue:** a failed search may create a bounded review suggestion for an eligible durable object; it cannot promote a candidate or override privacy/deletion state.
- **Dismiss:** suppresses a digest item and records a bounded negative signal; it does not delete the source.
- **Forget/delete:** uses the M5 scoped cascade across source versions, FTS, vectors, diffs, edges, digest state, caches, and eligible derived records. The ledger retains only minimal deletion evidence permitted by policy.
- The local score may learn from approved signals, but explicit user decisions outrank it and no black-box score may silently change factual content or authority.

## 3. Hybrid Retrieval (the recall contract; M4-D execution contract)

Never pure vector search (terminology mismatch) and never pure keyword (no meaning). The proven fusion:

```
score = w1 · BM25(FTS5) + w2 · cosine(NLEmbedding/embedder) + w3 · recency_decay
        then optional local rerank (cross-encoder-class) for top-20
```

- **BM25/FTS5** handles exact IDs, code, names, numbers (zero semantic drift).
- **Embeddings** (Apple NLEmbedding v1, nomic MLX embedder upgrade path) handle meaning and typo-tolerance.
- **Recency** keeps old content from polluting unless clearly relevant.
- **RRF-style fusion** with a locked corpus and measured thresholds. Do not claim a universal recall lift; M4 reports exact-token, conceptual, temporal, as-of, and mixed-query results against lexical/vector baselines.
- Retrieval is **cancellation-aware and capped** — assemble only what fits the Cell budget (ROUTING_SPEC §4), with each retrieved node's provenance attached so citations resolve to real Source objects.

## 4. The Verbosity & Personalization Policy

Research consensus (2024–2026): users penalize fluff; brevity correlates with satisfaction for operational tasks; reasoning disclosure is wanted for high-stakes work and hidden for routine; memory meta-commentary is actively disliked.

| Rule | How |
|---|---|
| **V1 Implicit inweaving** | Use remembered context without announcing it. "Here's the Swift version" — not "since you're a Swift developer…". The delight is *being understood*, not *being processed*. |
| **V2 No memory narration** | NEVER: "I remember from your memory…", "as stored in your profile…", "recalling our previous conversation…". If the user asks *how* you know, show the memory page — don't narrate in chat. |
| **V3 Graceful confirmation for high-risk data** | For financial/medical/legal or irreversible actions: "Use your standard deployment stack?" — a light question, not a database dump. |
| **V4 Adaptive depth** | Operational/coding/quick-answer → concise, direct. Synthesis/research/creative → depth is welcome. Match the *job*, not the persona. |
| **V5 Collapsible reasoning** | Chain-of-thought-style disclosure lives behind a "thinking" disclosure (o-series/Claude extended-thinking pattern), auto-expanded for high-stakes work (code, math, planning), collapsed for routine. |
| **V6 Citation-first for research** | Research answers are structured, citation-first, journalistic (Perplexity lesson): claims resolve to Source objects; uncertainty is labeled; never generated source labels. |
| **V7 Progressive disclosure of memory** | The memory surface (settings drawer / memory page) is where users inspect, edit, approve, delete. The live chat stays clean. The digest is the daily approval loop. |

## 5. Privacy & Deletion Semantics

> **M5 authority:** `docs/superpowers/plans/2026-08-11-m5-digest-promises-forgetting-retention-plan.md` is the executable contract for PromiseCandidate staging, digest manifests, approval decisions, reinforcement, decay eligibility, and the crash-resumable 10-minute purge. The rules below are architectural invariants; where older wording suggests direct model-to-Task promotion or unconditional physical deletion, M5 supersedes it.

1. **Private-mode guard:** private browsing is non-persistent by default. Captures/scopes/memory from private content require explicit opt-in + clear label (AGENTS.md §9.2.9).
2. **Kill-list:** messages, password managers, banking, incognito → capture fully pauses (Rewisp's absolute kill-list, hardened).
3. **PII strip:** credential-shaped text (cards, SSNs) removed before storage or indexing.
4. **Retention:** 6-month default decay (importance-based), nightly consolidation, explicit purge (forget last 10 min / all).
5. **At-rest encryption:** FileVault-backed plain SQLite for A1–A5; SQLCipher at A6 behind the existing actor isolation (ADR-gated per `hive-memory-tech-notes.md`).
6. **Deletion cascade:** delete-by-scope API removes from local disk, indexes, model queues, and logs; the EventLedger records the deletion itself.
7. **MCP read-only:** any agent querying Hive memory (A6 MCP server) is read-only and token-gated — it can search and read promises, never modify.

## 6. Eval Hooks

- **Retrieval quality:** hybrid fusion beats BM25-only and vector-only on a local fixture corpus (precision@10, recall@10, MRR) — locked in `punch_up_tests.md`.
- **Compaction fidelity:** evicted-then-retrieved turns reproduce decisions/promises without contradiction (drift test over 3 regeneration cycles).
- **Dedupe:** dreaming re-run produces zero duplicate nodes (content-hash invariant).
- **Forgetting:** pinned nodes survive expiry; unpinned nodes decay; denied digest facts are removed and never resurface.
- **Verbosity:** output-length SLOs per scope (operational ≤ X tokens unless depth requested); zero occurrences of banned memory-narration phrasing in the eval corpus.
- **Privacy:** private-mode captures never persist; kill-list hosts never captured; PII patterns absent from storage (fixture-based).
