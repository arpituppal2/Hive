# THE HIVE BROWSER — DEFINITIVE MASTER SPECIFICATION
## Canonical Build Doc v2.0 — Full From-Scratch Handoff

> **Status:** ACTIVE MASTER DOC. Supersedes all prior drafts (including any referencing "Queen" or "Bees").
> **Product Name:** The Hive Browser (always the full name on first reference; "Hive" thereafter)
> **Internal Assistant Brand:** Swarm (lives inside Hive, the way Perplexity lives inside Comet)
> **Subagent Unit Name:** Cells (never "Bees" — cheapens the product)
> **Current Codebase Reality (2026-07-24):** UI scaffold on legacy WKWebView. Nothing below the UI layer is production-real. Treat as 0% unless explicitly marked otherwise below.
> **Mandate:** v1.0.0 must independently be capable of taking 1% of browser market share on release day. Every subsequent minor version takes another 1%. No "eventually" features in v1 — modularity means invisible-until-needed, not incomplete.

---

## 0. AI HANDOFF PROTOCOL (READ FIRST, EVERY SESSION)

Any AI agent (Claude Code, Codex, Cursor, Antigravity, Aider, or successor) picking up this document must:

1. **Read the Current State Ledger (Section 1.3) before writing any code.** It is the single source of truth for what exists. Update it after every merged change.
2. **Never assume prior work is correct.** Verify against the actual repo, not against this document's aspirational descriptions.
3. **Never silently downgrade scope.** If a requirement seems too large for one session, split it into the smallest shippable vertical slice and log the remainder in Section 14 (Continuation Ledger), not by deleting the requirement.
4. **Follow the phase order in Section 12** unless the Current State Ledger shows a phase is already complete — then skip to the next incomplete phase.
5. **Treat this document as living.** When you complete work, edit Section 1.3 status percentages and Section 14 with a dated entry describing exactly what changed, what file paths were touched, and what remains.
6. **No cloud dependency may be load-bearing for core product function.** BYOK / NVIDIA NIM / remote frontier models are acceleration paths for the *user*, not requirements for Hive to function.
7. **Security is not optional scope.** Any Cell capable of writing to disk, executing shell, or performing OS actions must go through the gates defined in Section 8 from day one of that feature's existence — not retrofitted later.

---

## 1. IDENTITY, NAMING CANON, AND CURRENT STATE

### 1.1 Naming Canon (final — do not deviate)

| Old / Wrong Term | Correct Term | Notes |
|---|---|---|
| "Queen" | **Swarm** | Swarm is the top-level orchestrator brand and the user-facing assistant identity. There is no separate "Queen" concept. |
| "Bees" | **Cells** | Subagent unit. Ties to Honeycomb (a honeycomb is made of cells). Also doubles as UI vocabulary: "12 Cells active," "Cell paused," "Cell log." |
| "Two apps" (Hive + Swarm as separate products) | **One app** | The Hive Browser is the single shipped product. Swarm is the intelligence layer inside it, exactly as Perplexity is a mode inside Comet, not a separate install. |
| "Honeycomb" | Unchanged | The graph database/memory substrate. Correct as-is — it's the structure Cells operate within. |
| "Librarian / Author / Auditor" | Unchanged | Correct as background maintenance agent names — these read as competent, not cute. |

### 1.2 Product Philosophy (binding design law)

Hive is a **base with attachments**, not a control panel. A brand-new user opens Hive and sees a browser — full stop. Nothing about Swarm, Cells, Honeycomb, or graph visualization is visible unless the user has taken an action that implies they want it. This is not a settings toggle; it's an architectural requirement: **every advanced subsystem must be capable of running fully dormant with zero UI footprint and zero measurable performance cost when unused.**

Every unlocked capability must produce a felt sense of "this is absurdly fast and it just worked" — the dopamine requirement is a performance and latency requirement, not just a UX one. Concretely: no Swarm-initiated action may present a spinner for longer than 800ms before showing incremental progress; no Cell may run silently without an observable trace in Hive Viz if the user opens it.

### 1.3 CURRENT STATE LEDGER (source of truth — update on every session)

| Subsystem | Target | Status | Reality |
|---|---|---|---|
| Renderer Engine | Chromium via CEF, Swift/C++ interop | **0%** | Running WKWebView. Full tear-out required. |
| DOM Execution | CDP (Chrome DevTools Protocol) | **0%** | Does not exist. |
| Knowledge Graph | Honeycomb, SQLite, tiered shards, 50M node ceiling | **0%** | Flat JSON MemoryStore in HiveCore/Memory. No schema, no graph. |
| Vector Embeddings | Local MLX embedding subsystem | **0%** | Does not exist. |
| Orchestrator (Swarm core) | Distilled local small model | **10%** | HiveCore/AI/Dispatcher scaffolded but returns mocked/simulated responses. No real inference. |
| Concurrency / ACID | Single-Writer GraphWriter Actor + WAL | **0%** | No DB exists to have concurrency issues yet. |
| Background Agents | Librarian (nightly), Author (daily), Auditor (weekly/on-demand) | **0%** | Designed on paper only. No running Task loops. |
| Native OS Action Bus | XPC-isolated, capability-gated | **15%** | HiveCore/OS/ComputerUse has naive AppleScript/shell exec. No XPC isolation, no permission gating. |
| Chameleon UI | Native SwiftUI shell, dynamic profile swap | **20%** | Top/vertical tab layouts exist in HiveBrowser/Views. No dynamic behavioral profile switching. |
| Code Workspace / CodeRunner | Sandboxed exec + dedicated coder model | **10%** | CodeRunner.swift runs naive zsh, no sandbox, no model attached. |
| Hive Viz | Real-time Metal/Canvas graph observer | **0%** | Does not exist. |

**Rule: no PR, commit, or "phase complete" claim is valid unless this table is updated in the same change.**

---

## 2. SYSTEM ARCHITECTURE & REPOSITORY STRUCTURE

### 2.1 Directory Structure (target — build toward this, refactor incrementally, never leave the repo in a state that doesn't compile)

```text
Hive/
├── Package.swift                        # SPM: HiveCore, HiveBrowser, HiveKit(shared types) targets
├── Sources/
│   ├── HiveKit/                         # Shared types/protocols, zero heavy deps, imported by both targets
│   │   ├── Models/                      # Codable structs: Node, Edge, CellTask, MutationEnvelope, etc.
│   │   └── Protocols/                   # OSToolProtocol, MemoryReaderProtocol, ModelRouterProtocol
│   ├── HiveCore/                        # The Agentic OS & Database — no UI code lives here
│   │   ├── Swarm/
│   │   │   ├── Orchestrator.swift       # Intent parsing, routing, task decomposition
│   │   │   ├── CellManager.swift        # Spawns/pools/kills Cells, enforces concurrency limits
│   │   │   ├── CellTypes/               # SearchCell, ComputerCell, DeepResearchCell, LearnCell, BrowserControlCell, CodeCell
│   │   │   ├── Librarian.swift          # Nightly entity resolution, dedup, compaction
│   │   │   ├── Author.swift             # Daily synthesis, brief generation
│   │   │   └── Auditor.swift            # Weekly/on-demand contradiction resolution, HITL prompts
│   │   ├── AI/
│   │   │   ├── ModelRouter.swift        # Decides local vs BYOK vs NIM per task
│   │   │   ├── LocalInference/          # MLX runtime wrappers per model role
│   │   │   ├── RemoteProviders/         # NVIDIA NIM, DeepSeek, Kimi, user BYOK adapters
│   │   │   └── Distillation/            # Training/fine-tune/quantization pipeline scripts (offline tooling, not shipped binary)
│   │   ├── Embeddings/
│   │   │   ├── EmbeddingService.swift   # Batches, prioritizes, dispatches to MLX
│   │   │   └── ANNIndex/                # sqlite-vec integration + manifest mapping
│   │   ├── Honeycomb/
│   │   │   ├── Schema/                  # nodes.sql, edges.sql, journal.sql, manifest.sql
│   │   │   ├── GraphWriter.swift        # The single-writer actor — ALL commits go through here
│   │   │   ├── ShardManager.swift       # Hot/warm/cold tiering, domain+TTL partitioning
│   │   │   └── QueryEngine.swift        # Staged query: graph-local -> vector -> hydrate
│   │   ├── Tools/
│   │   │   ├── OSActionBus/             # Capability-gated native tool registry (Section 8)
│   │   │   ├── CDPBridge/               # Swift <-> Chrome DevTools Protocol client
│   │   │   └── CodeWorkspace/           # Sandboxed exec, repo awareness, CodeCell integration
│   │   └── Security/
│   │       ├── SanitizationProxy.swift  # Strips executable/instructional content from ingested pages before Cells see it
│   │       ├── XPCServices/             # Isolated privilege-separated helper processes
│   │       ├── KillSwitch.swift         # Per-Cell and global stop/resume state machine
│   │       └── Checkpoint.swift         # Time-machine rollback via journal snapshots
│   ├── HiveBrowser/                     # The Chromium Shell & Native UI
│   │   ├── App/                         # Lifecycle, window management, menu bar
│   │   ├── Renderer/                    # CEF Swift/C++ wrapper, NSView hosting
│   │   ├── Chameleon/                   # Behavioral profile engine (Section 9)
│   │   └── Views/
│   │       ├── Omnibar/
│   │       ├── Sidebar/                 # Vertical tab mode
│   │       ├── TopTabs/                 # Horizontal tab mode
│   │       ├── HiveViz/                 # Metal/Canvas graph view
│   │       ├── SwarmPanel/              # Swarm chat/task surface, archived like chat history
│   │       └── Settings/
└── Tests/
    ├── HiveCoreTests/
    └── HiveBrowserTests/
```

### 2.2 Rendering Engine Migration (Phase 0 — blocking everything else)

WKWebView must be fully torn out. This is not incremental — Chameleon behavior, CDP-based Cells, and network interception are structurally impossible on WKWebView (Apple does not expose CDP-equivalent depth). Build order:

1. Vendor/build CEF for macOS arm64 (Apple Silicon first, Intel is not a launch requirement).
2. Write the Swift/C++ interop bridge (`CEFHost`) exposing a single `NSView`-hosted browser instance.
3. Confirm baseline parity: page load, navigation, back/forward, find-in-page, zoom, print, view-source — before any Swarm work begins.
4. Expose CDP over the existing CEF connection to `CDPBridge` in HiveCore/Tools.
5. Only after steps 1–4 pass manual QA does any other phase begin.

---

## 3. HONEYCOMB KNOWLEDGE GRAPH (FULL SPEC)

### 3.1 Storage Architecture — Tiered Sharding + Decoupled Vector Index

Single monolithic SQLite file is explicitly rejected. Architecture:

- **Hot tier:** in-memory SQLite (or `PRAGMA journal_mode=MEMORY` attached DB) for active-session nodes/edges, flushed to cold storage on a rolling basis.
- **Cold tier:** multiple SQLite files sharded by **domain + temperature/TTL** (not domain alone — this avoids pathological shard growth). Example: `shard_code_hot.sqlite`, `shard_personal_cold.sqlite`.
- **Vector tier:** `sqlite-vec` extension for the embedding ANN index, kept separate from the primary graph tables, quantized (int8 or binary quantization) once a node ages out of hot tier.
- **Manifest:** a lightweight `manifest.sqlite` mapping node ID → shard file, embedding location, TTL class, promotion state.

Target: 50M nodes max ceiling, but disk footprint must stay bounded via aggressive quantization and TTL-based pruning/archival — never unbounded growth. Practical target: keep total Honeycomb footprint under ~2GB at 1M active nodes through quantized embeddings (binary/int8) and cold-tier compression.

### 3.2 Core Schema

```sql
-- nodes.sql
CREATE TABLE nodes (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,            -- 'entity','fact','page','task','preference','event'
    content TEXT,
    embedding_ref TEXT,            -- pointer into ANN index, not inline BLOB for hot rows
    provenance TEXT,               -- source URI, capturing Cell ID, timestamp
    confidence REAL DEFAULT 1.0,
    ttl_class TEXT DEFAULT 'warm', -- 'hot','warm','cold','archived'
    shard_id TEXT,
    created_at INTEGER,
    updated_at INTEGER,
    superseded_by TEXT             -- versioning: points to newer node if this fact was revised
);

-- edges.sql
CREATE TABLE edges (
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    relation TEXT NOT NULL,
    weight REAL DEFAULT 1.0,
    created_at INTEGER,
    PRIMARY KEY (source_id, target_id, relation)
);

-- journal.sql  (time-machine / rollback substrate)
CREATE TABLE journal (
    tx_id TEXT PRIMARY KEY,
    cell_id TEXT,
    action_type TEXT,              -- 'upsert_node','upsert_edge','delete','merge'
    snapshot BLOB,                 -- pre-image for rollback
    committed_at INTEGER
);

-- manifest.sql
CREATE TABLE manifest (
    node_id TEXT PRIMARY KEY,
    shard_file TEXT,
    embedding_index TEXT,
    ttl_class TEXT,
    promoted_at INTEGER
);
```

### 3.3 Concurrency Model — Single-Writer GraphWriter Actor

- Cells never write directly to SQLite. They read freely (WAL mode gives lock-free concurrent reads) and maintain **provisional in-memory subgraphs**.
- All authoritative mutations are submitted as `MutationEnvelope` objects to `GraphWriter`, a Swift `actor`.
- `GraphWriter` batches, validates, deduplicates, orders, and commits in short explicit transactions — never one-row-per-commit.
- SQLite runs in WAL mode permanently. Busy-timeout/retry exists only as a safety net, never as the primary coordination mechanism.
- Every commit writes a `journal` row first (pre-image), enabling rollback to any prior tx_id — this is the Time-Machine mechanism referenced in Section 8.4.

### 3.4 Query Path (staged, never a raw scan)

1. Resolve candidate neighborhood from graph-local traversal (manifest + hot shard).
2. Run similarity search only against the ANN index for the narrowed candidate set.
3. Hydrate final result set from the correct shard(s).
4. Cache the resulting ego-graph/ranking for the session.

---

## 4. MODEL STACK (concrete decisions — binding unless superseded by benchmark evidence)

No prior model artifacts are assumed to exist. Everything below must be built, downloaded, distilled, or fine-tuned by whichever AI picks up this phase, using NVIDIA NIM for teacher-model access where distillation is required.

| Role | Model Choice | Size | Source / Method | Rationale |
|---|---|---|---|---|
| **Swarm Orchestrator** | Custom distilled transformer | 100–150M params, quantized <100MB | Distill from Qwen3.6-27B (Apache 2.0, via NVIDIA NIM) as teacher on a synthetic dataset of intent→routing decisions specific to Hive's tool schema | Needs to be small enough to stay pinned in memory with near-zero latency; a general LLM is wrong-shaped for pure routing/classification |
| **Reasoner** | Qwen3 4B (or Phi-4-mini as fallback) | ~4B, MLX-quantized 4-bit | Download via NVIDIA NIM / Hugging Face, run via MLX | Handles multi-step local reasoning too complex for the orchestrator but not worth a cloud round-trip |
| **Coder Cell model** | Qwen3-Coder-Next (80B total / 3B active MoE) or Qwen3.6-27B dense if RAM allows | Quantized GGUF/MLX | Apache 2.0, open-weight, benchmarked ~70.6% SWE-bench Verified, competitive Terminal-Bench scores | Best available open-weight coding-agent model as of mid-2026; MoE sparsity keeps it usable on 16GB+ Macs |
| **Local Embeddings** | nomic-embed-text-v2 | 137M, MIT | Via MLX | Best throughput-to-quality ratio for local Mac embedding at scale; bge-m3 (568M) as a heavier fallback for higher recall if hardware allows |
| **Remote / BYOK tier** | User's existing NVIDIA NIM, DeepSeek, Kimi, Claude/Cursor/Codex/Antigravity accounts | N/A | User-supplied keys, routed through `RemoteProviders` | Never load-bearing for core function — pure acceleration/fallback for tasks exceeding local capability |

**Distillation pipeline (build from scratch):** synthetic task generation → teacher model labeling via NIM → student architecture training script → INT4/INT8 quantization → MLX conversion → eval harness against a held-out routing-accuracy benchmark (target: match or exceed the 98%+ success rate referenced informally in prior notes, treated here as a real target, not marketing).

---

## 5. SWARM ORCHESTRATION & THE AUTONOMOUS AGENT LINEUP

Cells are only one execution primitive. The full autonomous lineup Swarm must support at v1.0.0:

| Capability | Description |
|---|---|
| **Search** | Local + web search, ranked and deduplicated against Honeycomb before returning results |
| **Computer** (Computer Use) | OS-level control via the Native Action Bus (Section 8) — replaces Perplexity Personal Computer / Codex computer-use |
| **Deep Research** | Multi-step, multi-source synthesis with citation tracking, writes structured findings into Honeycomb |
| **Learn Step-by-Step** | Guided, incremental tutoring/walkthrough mode — decomposes a goal into checkpointed steps the user can follow along with |
| **Control Browser** | Direct CDP-driven Cell action inside Hive's own tabs — clicking, filling, navigating, extracting |
| **Code** | Repository-aware Cell using the Coder model, sandboxed execution, git-aware |
| **Cells (general)** | Long-running, resumable, observable background workers spawned for any of the above; visible and steerable in Hive Viz |

All of the above are **archived like chat history** — every Swarm session/task has a persistent, revisitable record, resumable after app restart via the journal + checkpoint system.

### 5.1 Concurrency limits and Cell lifecycle

- `CellManager` enforces a hardware-aware concurrency ceiling (dynamically probed at launch, not hardcoded — must run acceptably on 8GB M1 Air and scale up on higher-end hardware).
- Every Cell has a lifecycle: `spawned → running → (paused|blocked|awaiting_help) → completed|failed|killed`.
- A Cell blocked on ambiguity may raise a `help_request` surfaced to Swarm's UI, not silently retry indefinitely.

---

## 6. BACKGROUND MAINTENANCE AGENTS

| Agent | Cadence | Responsibility |
|---|---|---|
| **Librarian** | Nightly (default 2AM, user-configurable) | Entity resolution, duplicate merging, shard compaction/rebalancing, TTL demotion |
| **Author** | Daily | Synthesizes the day's Honeycomb deltas into a structured brief; updates the lean "daily memory" surface fed to the orchestrator |
| **Auditor** | Weekly, or on-demand | Detects contradictions between nodes, resolves via confidence-weighted merge or raises a HITL prompt to the user; user corrections get maximum weight in future fine-tuning data |

**Conflict resolution policy:** default to confidence-weighted + recency-weighted auto-merge; escalate to user only when confidence delta is below a defined threshold. All resolutions are logged with provenance so Semantic Drift can be traced later.

**Versioning:** no node is ever hard-deleted by these agents. Superseding writes set `superseded_by` and demote the old node's `ttl_class`, preserving full history for rollback.

---

## 7. UI / UX: THE CHAMELEON RUNTIME

### 7.1 Behavioral profiles (not pixel clones — legally safer, still frictionless)

Hive ships with selectable browsing identities that map muscle memory, not visual skins:

| Profile | Tab layout default | Shortcut mapping baseline | Notes |
|---|---|---|---|
| Chrome-familiar | Horizontal top tabs | Chrome/Windows-style shortcuts adapted to macOS conventions | Default for most incoming switchers |
| Arc-familiar | Vertical sidebar tabs, Spaces-like grouping | Arc-style command bar behavior | For power users coming from Arc |
| Safari-familiar | Horizontal top tabs, compact chrome | macOS-native shortcut set | For default-Safari switchers |

Only two structural tab layouts exist: **horizontal** and **vertical**. Do not build more than these two — over-customization is explicitly rejected as a design trap (see Anti-Patterns, Section 10). Everything else (density, accent, Cell visibility) is a setting, not a new layout mode.

### 7.2 Modularity rule (binding)

Every feature beyond core browsing (Swarm panel, Hive Viz, Cells, Code Workspace, OS Action Bus) must be:
1. Fully inert (zero background cost) until first invoked.
2. Discoverable via a single consistent entry point (omnibar command or a dedicated but unobtrusive icon), never a forced onboarding tour.
3. Reversible — any unlocked module can be hidden again without data loss.

---

## 8. SECURITY MODEL

### 8.1 Prompt injection defense — Sanitization Proxy

All page content extracted by any Cell passes through `SanitizationProxy` before reaching any model context. It strips: hidden text, suspicious meta tags, off-screen/zero-opacity instructional text, and known injection patterns. Sanitized content is tagged as untrusted data in the model prompt structure — never concatenated as if it were a system instruction.

### 8.2 OS Action Bus (Native Action Bus)

- Strongly typed tool registry wrapping Accessibility APIs, CGEvent, AppleScript/Apple Events, and bounded shell execution.
- Every tool call runs through an XPC service for process isolation and crash containment.
- The orchestrator expresses intent only; the tool layer enforces argument validation, permission state checks, and policy allow-lists before execution.
- No Cell or model may ever receive raw, unrestricted shell or Quartz/window-server access.

### 8.3 Kill switches

- **Per-Cell kill:** stops one Cell immediately, preserves its last checkpoint, resumable on demand.
- **Global full-stop:** halts all Cells and background agents system-wide, preserves all in-flight state via the journal, resumable as a batch or individually.
- Both are reachable from a single always-available control (menu bar + omnibar command), not buried in settings.

### 8.4 Time-Machine rollback

Every graph mutation is journaled with a pre-image (Section 3.2). Rollback can target a specific `tx_id`, a specific Cell's entire session, or a full timestamp boundary ("undo everything since 3pm"). This is the concrete implementation of the "time-machine" concept referenced in earlier notes — not aspirational, required for v1.0.0.

---

## 9. HIVE VIZ

Real-time Metal/Canvas view rendering the live Honeycomb graph, visually referencing an Obsidian vault graph view: dark canvas, small node particles, thin low-contrast edges, brighter highlighted links on selection, smooth inertial pan/zoom, local ego-graph expansion on focus. Active Cells are rendered as visibly moving/pulsing agents on the graph so the user can watch work happen — this is the primary "efficiency dopamine" surface of the product and must be present, even minimally, in v1.0.0.

---

## 10. ANTI-PATTERNS (explicitly rejected)

- Monolithic single SQLite file for the graph at scale.
- Cells writing directly to the graph without going through GraphWriter.
- Any model given raw shell/Quartz access.
- Browser chrome built as a privileged web shell (HTML/CSS/JS) instead of native SwiftUI/AppKit.
- More than two structural tab layouts.
- Forced onboarding that exposes Swarm/Cells/Honeycomb before the user asks for them.
- Treating remote/cloud models as load-bearing for core function.
- Silent Cell retries with no observability or escalation path.

---

## 11. VERSIONED ROADMAP (market-share framing)

| Version | Deliverable bar | Market-share goal |
|---|---|---|
| **1.0.0** | Full CEF/CDP tear-out complete. Honeycomb live with GraphWriter + WAL. Local embedding pipeline running. Swarm orchestrator (real, not mocked) routing to at least Search, Control Browser, and Code Cells. Chameleon horizontal/vertical + Chrome/Arc/Safari profiles. Native OS Action Bus with XPC gating and dual kill switches. Hive Viz functional (even minimal). Librarian/Author running as real scheduled tasks. | 1% |
| **1.1** | Deep Research + Learn Step-by-Step Cells. Auditor live with HITL. Distilled orchestrator model replacing any remaining placeholder logic. | +1% |
| **1.2** | Full Computer Use parity/superiority vs Perplexity Personal Computer and Codex computer-use, sub-5s step latency target. | +1% |
| **1.3+** | Continued Cell-type expansion, model quality improvements via Auditor feedback loop, scale-testing toward the 50M node ceiling. | +1% per release |

No version ships with a subsystem in the Current State Ledger below "real and functional" for the features that version claims.

---

## 12. BUILD PHASE ORDER (do not skip)

1. **Phase 0:** CEF/CDP tear-out (Section 2.2). Blocking. Nothing else starts until this passes manual QA.
2. **Phase 1:** Honeycomb schema + GraphWriter actor + WAL, replacing the flat JSON MemoryStore entirely.
3. **Phase 2:** Local embedding subsystem + ANN index wiring.
4. **Phase 3:** Swarm orchestrator — real inference (distilled model or interim off-the-shelf small model while distillation completes in parallel).
5. **Phase 4:** Cell types: Search, Control Browser, Code (minimum for 1.0.0 per Section 11).
6. **Phase 5:** OS Action Bus with XPC isolation + kill switches + Sanitization Proxy.
7. **Phase 6:** Chameleon profile engine + horizontal/vertical tab modes.
8. **Phase 7:** Librarian + Author scheduled tasks running for real.
9. **Phase 8:** Hive Viz minimal viable render.
10. **Phase 9:** v1.0.0 QA pass against Section 11's bar. Ship.

---

## 13. GLOSSARY

- **Hive:** The full product (The Hive Browser).
- **Swarm:** The orchestration/intelligence layer inside Hive.
- **Cell:** A spawned subagent/worker unit (never "Bee").
- **Honeycomb:** The graph-based memory/knowledge substrate.
- **GraphWriter:** The single-writer actor enforcing ACID on Honeycomb.
- **Librarian / Author / Auditor:** Nightly/daily/weekly maintenance agents.
- **Chameleon:** The behavioral tab/shortcut profile system.
- **Hive Viz:** The real-time graph visualization surface.

---

## 14. CONTINUATION LEDGER (append-only, dated entries — every AI session must add one)

```
[2026-07-24] Master spec v2.0 authored. Renamed Queen->Swarm, Bees->Cells.
             No code changes made this session. Current State Ledger (Section 1.3)
             reflects audited repo status as of this date. Next AI: start Phase 0.
[2026-07-26] /office-hours research session. Appending Sections 15-22:
             full competitive autopsy, Hive wedge, edge cases, animations,
             rendering, subagents, headless, and consumer destruction plan.
```
