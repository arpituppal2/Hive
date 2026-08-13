# Hive Memory + AI Sidecar + Browser Credibility — Implementation Plan

> **Date:** 2026-08-11
> **Spec:** `docs/superpowers/specs/2026-08-11-hive-memory-megaphase-design.md`
> **Status:** historical product-scope plan; execution ordering is superseded by `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md` and detailed M0–M4 contracts.
> **Baseline:** `main @ 84d53695` — UX overhaul complete, build green, tests green (except pre-existing MLX metallib env failure)

---

## 0. Ground Rules

- **Use the existing substrate.** HoneycombStore, EventLedgerStore, SourceAndClaim,
  SourceFetcher, ClaimExtractor, NLEmbedding, and the approval panel already exist. No
  rebuilding — extend.
- **HiveCore stays dependency-free.** Network/Keychain injected via closures (existing
  pattern). Capture probe JS lives in the app layer (`Sources/Hive/`), store logic in
  HiveCore.
- **Privacy by construction.** Private tabs never captured. Kill-list origins never
  captured. PII stripped pre-store. Every capture/approval/promise event → EventLedger.
- **Tests with every task.** HiveCoreTests pattern; fixtures over mocks.
- **No AI slop.** Honest labels; everything user-visible is real or clearly labeled.

---

## Phase A — Hive Memory (historical product scope; do not bypass execution-v2 gates)

> A1–A6 below preserve the desired product surface. They are not an implementation order. M0 storage/recovery → M1 explicit capture → M2 import/Brief → M3 candidate-only WISP → M4 source versions/diffs/trails/hybrid retrieval is the current dependency order. The detailed M4 contract is `docs/superpowers/plans/2026-08-11-m4-diffs-trails-hybrid-retrieval-plan.md`.

### A1. Wisp capture pipeline

**Files (new):**
- `Sources/HiveCore/Memory/WispStore.swift` — actor wrapping HoneycombStore for wisps:
  - `recordWisp(source: Source, privacy: PrivacyClass)` → dedupe via
    `findSource(byContentHash:)`, insert, link capture event
  - `wisps(for url: String, since: Date)` → ordered capture chain for diffs
  - `recentWisps(limit:)`, `deleteWisps(since: Date)` (purge)
  - kill-list + PII backstop helpers (pure functions: `PrivacyPolicy.isKillListed(origin)`,
    `PIIScanner.redact(_:)` with Luhn)
- `Sources/Hive/WispCaptureProbe.swift` — the injected JS probe (self-guarding, idempotent,
  reuses reader-mode selector extraction). Returns: title, canonical URL, meta description,
  main-content text, `a[href]` sample, touched form fields, `<time>` values, content hash.

**Files (edited):**
- `Sources/Hive/BrowserState+Knowledge.swift` — capture call site: on load-commit +
  settle-after-scroll + tab-switch (rate-limited, private/private-mode guard, kill-list
  guard, capture_enabled flag, per-origin opt-out).
- `Sources/Hive/BrowserState+Setup.swift` — `captureEnabled` default ON (normal profile),
  OFF (private). Persisted.
- `Sources/Hive/EventLedger` wiring — `record(capture)` event.

**Acceptance:** probe returns structured text for a fixture page; two loads of same URL
dedupe to one Source; kill-list origin yields zero rows; PII regex strips card/SSN before
store; EventLedger has a capture event per row; private tab produces no row.

### A2. What-changed diffs + retrieval

**Files (new):**
- `Sources/HiveCore/Memory/PageDiff.swift` — DOM-aware diff:
  - `diff(previous: String, current: String) -> [PageChange]` — tokenize via reader-mode
    selectors, ignore boilerplate, report added/removed/modified + moved numbers
  - `PageChange { kind, text, numberDelta? }`
- `Sources/HiveCore/Memory/HybridRetriever.swift` — FTS5 BM25 (HoneycombStore.search) +
  NLEmbedding cosine (exists), Reciprocal Rank Fusion, recency decay
  `score × e^(−λ·ageDays)`; λ tunable.

**Files (edited):**
- `Sources/Hive/BrowserState+Knowledge.swift` — `whatChanged(url:since:)` → diff chain →
  KnowledgePanel result model.
- `Sources/Hive/KnowledgePanel.swift` — "What changed" query UI + sparkline chip for
  repeated numbers.

**Acceptance:** fixture pair (v1/v2 of a page with boilerplate + a changed number) yields
precise added/removed/modified + the number delta; RRF ranks a conceptual query above a
lexically-empty but semantically-close wisp; recency decay flips two equal-score results.

### A3. Promise catching

**Files (new):**
- `Sources/HiveCore/Memory/PromiseClassifier.swift` — rule + tiny model contract:
  - `classify(text) -> PromiseCandidate?` — rejects questions/negations/hedges/marketing;
    extracts deadline ("by EOD", "Friday", ISO date); scoped to writing surfaces
  - `PromiseCandidate { text, deadline, confidence, sourceURL }`
- `Sources/HiveCore/Memory/PromiseStore.swift` — Task-node-backed lifecycle:
  confirm → schedule → remind-once → done-on-followup | dismissed.

**Files (edited):**
- `Sources/Hive/WispCaptureProbe.swift` — only runs classifier when origin is a known
  writing surface (Gmail/Outlook/Slack web compose, textareas).
- `Sources/Hive/BrowserState+Knowledge.swift` — candidate → one-tap confirm chip
  (bottomChipOverlays pattern) → TaskStore insert with source link.
- Reminder: single banner on due day (notificationTray pattern), done/dismiss.

**Acceptance:** fixture corpus: "I'll send it Friday" → candidate; "maybe later" → rejected;
"Can you send X?" → rejected; deadline extraction across 5 phrasings; confirm → Task node →
banner on due day → follow-up text marks done.

### A4. Research trails + capture-to-brief

**Files (new):**
- `Sources/HiveCore/Memory/ResearchTrail.swift` — Tab-opened-from-link edges:
  - `recordTabOpen(parentTabID:childTabID:sourceURL:)` → Honeycomb Edge `opens`
  - `trail(for tabID:) -> [Source]` — cluster tabs sharing topic via intent-router tags
    + contiguous session; group into Project (ProjectStore) on threshold.
- `Sources/HiveCore/Memory/CaptureToBrief.swift` — wisps in investigation → existing
  `buildBriefJSON` path → Brief node citing only stored Sources.

**Files (edited):**
- `Sources/Hive/BrowserState+Tabs.swift` — `newTab(url:from:)` records the opens-edge.
- `Sources/Hive/KnowledgePanel.swift` — "Trails" tab: investigation graph (nodes = tabs/
  sources, edges = opens/cites) + "Make brief" button.

**Acceptance:** fixture navigation chain A→B→C produces two opens-edges; trail groups them;
capture-to-brief cites only stored Source ids; KnowledgePanel renders the graph.

### A5. Nightly digest upgrade + forgetting curve

**Files (new):**
- `Sources/HiveCore/Memory/NightlyDigest.swift` — builds digest payload: today's wisps
  summary, unfinished threads (aging tasks), learned-facts proposals (facts not yet
  approved). One local model call via existing Dispatcher; proposals stored as Honeycomb
  nodes with `pending` state.
- `Sources/HiveCore/Memory/ForgettingCurve.swift` — per-fact lookup counts; pin at N;
  rescue-mention near cliff; approval weights.

**Files (edited):**
- `Sources/Hive/BrowserState+Brief.swift` — Morning Brief gains digest sections + approval
  loop (approve/deny/edit per proposal; updates weights).
- `Sources/Hive/EventLedger` wiring — approval events.

**Acceptance:** digest includes today's wisps + aging tasks + proposals; approve/deny
persists and re-weights; a fact looked up 3× pins; a cliff-fact gets a rescue mention.

### A6. MCP server + at-rest encryption + purge/retention

**Files (new):**
- `Sources/HiveCore/Memory/HiveMemoryMCP.swift` — read-only stdio MCP server (localhost,
  token-gated like the web-chrome bridge): `search_memory`, `get_promises`,
  `what_changed(url, since)`, `get_sources(project)`.
- `Sources/Hive/Resources/hive-memory/README.md` — Claude Desktop / Claude Code / Cursor
  wiring instructions.
- `Sources/HiveCore/Memory/RetentionPolicy.swift` — importance-based 6-month retention +
  nightly consolidation into summaries; purge API (`deleteWisps(since:)` + vector/edge
  cascade + EventLedger).

**Files (edited):**
- `Sources/Hive/HiveApp.swift` — MCP server lifecycle (start on launch, stop on quit);
  Keychain-backed SQLCipher key (stretch: Touch ID gating).
- `Sources/Hive/SettingsView+Privacy.swift` — "Forget last 10 minutes", retention slider,
  kill-list editor.

**Acceptance:** MCP answers 4 queries from a CLI client; SQLCipher round-trip with FTS5
still searching; purge removes rows + vectors + linked episodes; retention prunes to limit.

---

## Phase B — Comet-class AI Sidecar

### B1. @-mention tabs + scope preview

- `Sources/Hive/GeminiSidePanel+Input.swift` — `@` autocomplete over open tabs (reuse
  `tabPill`), attach URL + wisp to prompt; scope chips render pre-submit with privacy class.
- `Sources/Hive/BrowserState+AI.swift` — `submitGeminiQuery(_:attachments:)` carrying
  explicit scope; no silent widening.
- **Acceptance:** type `@` → chips; select → attached; submit → scope preview shown; panel
  context includes only attached sources.

### B2. Step disclosure + kill switch

- `Sources/Hive/GeminiSidePanel+Messages.swift` — render `SwarmResearchSession` steps
  (`checking sources`, `reading page`, `extracting claims`, `synthesizing`) with live source
  chips; kill button cancels session + revokes grants (existing cancellation path).
- **Acceptance:** fixture run shows 4 steps sequentially; kill cancels + revokes; no ghost UI.

### B3. Citation hardening

- `Sources/Hive/GeminiSidePanel+Messages.swift` — every `[n]` resolves to a stored Source
  (id/URL/title/retrieval ts/hash) before render; unverifiable → warning chip.
- `Sources/HiveCore/AI/Search/CitationFormatter.swift` — add `resolvedCitations(sources:)`
  contract.
- **Acceptance:** response citing a real Source renders the chip; response citing a fake
  label renders a warning; discovered/read/cited distinction shown.

### B4. Permission preview cards

- `Sources/Hive/ActionApprovalView.swift` — typed preview renderers per action kind
  (navigate, move-to-group, open-panel): what/where/scope/reversibility.
- **Acceptance:** proposal renders a preview card; approve/deny both log to EventLedger.

---

## Phase C — Browser credibility finish

### C1. Little Arc mini-windows
- `Sources/Hive/HiveApp.swift` — new `WindowGroup("mini")`; `Sources/Hive/MiniWindowView.swift`
  — frameless always-on-top, ⌘⇧N, ⌘W/Esc dismiss, own CefWebViewModel, history logging.
- Context menu "Open in Little Arc" on links.
- **Acceptance:** opens/dismisses, loads URL, logs history, private-safe.

### C2. Auto-archiving tabs
- `Sources/Hive/BrowserState+Hibernation.swift` — archive policy (idle >12h, unpinned,
  non-essential, no audio, not selected); ArchivePanel restore.
- **Acceptance:** fixture tab archived at threshold, restorable, exclusions respected.

### C3. No-op command cleanup
- `Sources/Hive/CommandRegistry.swift` + web-chrome palette — audit every action; wire or
  remove.
- **Acceptance:** zero no-op palette commands; each command reaches a real path.

### C4. Onboarding/import polish
- `Sources/Hive/OnboardingSheet.swift` + `ImportManager.swift` — first-run look choice
  (Chrome/Zen), import flow with honest partial-import report.
- **Acceptance:** clean-profile journey complete; report shows omissions.

---

## Task Order & Dependency Graph

```
A1 (capture) → A2 (diff/retrieval) ─┐
            → A3 (promises) ────────┤→ A5 (digest) → A6 (MCP/encryption)
            → A4 (trails) ──────────┘
A6 ───────────────────────────────────────┐
B1 → B2 → B3 → B4 (all depend on A1/A2) ─┤ (no hard dep between A/B beyond memory)
C1, C2, C3, C4 (independent; C3 audits palette)
```

Parallelizable: A1/A2/A3/A4 (sequential A-chain), B1–B4 (after A1/A2), C1–C4 anytime.

---

## Verification Gates (after each letter)

1. `swift build` green.
2. `swift test` green for touched suites (pre-existing MLX metallib env failure excluded).
3. JS probe: `node -c` where applicable.
4. EventLedger audit rows present for the new surface.
5. Commit with a clear message; append evidence to AGENTS.md §18 at phase close.
