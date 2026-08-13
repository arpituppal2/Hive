# Hive Memory + AI Sidecar + Browser Credibility — Mega-Plan Design

> **Canonical status:** active
> **Date:** 2026-08-11
> **Supersedes:** none (new workstreams)
> **Builds on:** `docs/superpowers/specs/2026-08-11-ux-overhaul-design.md` (completed), Honeycomb/EventLedger substrate (code-present, tested)
> **Dependencies:** The completed UX overhaul (dual-mode chrome, tokens). HoneycombStore, EventLedgerStore, SourceAndClaim, BriefStore, ProjectStore, TaskStore all exist in HiveCore and are already wired into the app.

---

## 0. Executive Summary

Three sequential phases that together deliver the product thesis — *a browser that
remembers and acts on your work*:

1. **Phase A — Hive Memory (the moat):** browser-native ambient intelligence. DOM-level
   capture into Honeycomb, what-changed page diffs, promise catching, research trails,
   nightly digest, MCP server, privacy-by-construction. This is the compounding advantage:
   standalone memory apps (Rewisp, Deep24, Rewind) capture at the OS level with OCR —
   lossy, permission-heavy, blind to structure. Hive IS the browser: DOM access, cross-tab
   topology, origin-level permissions. Nobody else can do this.
2. **Phase B — Comet-class AI Sidecar:** polish the existing Gemini panel into a first-class
   Sidecar: @-mention tabs, progressive step disclosure, citation hardening, permission
   previews. Turns the existing research pipeline into a user-visible, trustworthy surface.
3. **Phase C — Browser credibility finish:** Little Arc mini-windows, auto-archiving tabs,
   no-op command cleanup, onboarding/import polish. Makes Hive a complete daily driver.

Order matters: Memory is the strategic asset, Sidecar makes it *visible and trustworthy*,
Browser credibility makes the whole thing *retainable*. Each phase ships as its own commits
with tests.

---

## 1. Audit Findings (fresh, 2026-08-11)

### 1.1 What exists and is wired (do NOT rebuild)

| Asset | Location | State |
| --- | --- | --- |
| HoneycombStore (typed nodes/edges, FTS5, migrations) | `Sources/HiveCore/Honeycomb/HoneycombStore.swift` (1,013 ln) | code-present, tests in `HiveCoreTests.swift` |
| EventLedgerStore (append-only trust ledger) | `Sources/HiveCore/EventLedger/EventLedgerStore.swift` (783 ln) | code-present |
| SourceAndClaim (source→claim provenance) | `Sources/HiveCore/Honeycomb/SourceAndClaim.swift` (693 ln) | code-present |
| BriefStore / ProjectStore / TaskStore / SheetStore | `Sources/HiveCore/Honeycomb/` | code-present |
| Search providers (Tavily, Vane) + SourceFetcher + ClaimExtractor + CitationFormatter | `Sources/HiveCore/AI/Search/` | real, not mocks |
| ResearchWorker client + Swarm research sessions | `Sources/HiveCore/AI/Search/ResearchWorkerClient.swift` | code-present |
| KnowledgePanel, ProjectsPanel, BriefCapture, Morning Brief | `Sources/Hive/` | wired in app |
| Command palette, split view, boosts, hibernation, reader, PIP, downloads, password manager, sync | `Sources/Hive/` | code-present, verified |
| Dual-mode chrome (Chrome M3 horizontal + Zen vertical) | UX overhaul | complete 2026-08-11 |

### 1.2 Gaps (what this plan builds)

| Capability | Reference product | Hive today |
| --- | --- | --- |
| Ambient DOM capture (wisps) | Rewisp (OCR screen text) | absent |
| What-changed page diffs | Rewisp | absent |
| Promise catching | Rewisp | absent |
| Research trails (tab topology graph) | nobody (browser-native edge) | absent |
| Nightly digest with approval loop | Rewisp | Morning Brief exists, no wisp/approval loop |
| MCP server for agents | Rewisp | absent |
| @-mention tabs in AI input | Comet Sidecar | absent |
| Progressive step disclosure | Comet Sidecar | absent |
| Citation hardening (resolve to stored sources) | Comet | parsed labels only |
| Permission previews for agent actions | Comet hard boundaries | approval panel exists, no preview rendering |
| Little Arc mini-windows | Arc | comment-only |
| Auto-archiving tabs | Arc | hibernation only |
| No-op command palette actions | — | several |
| Onboarding/import polish | — | partial |

---

## 2. Phase A — Hive Memory (browser-native ambient intelligence)

### 2.1 Vision

Every page you visit leaves a **wisp**: structured text + links + metadata captured from the
DOM (never OCR, never screenshots) into Honeycomb as a typed `Source` node. Hive then reasons
over wisps locally — what changed, what you promised, what you're researching — and surfaces
it through the browser, the nightly digest, and MCP to your other agents. Everything local,
reduction-first, origin-level permissions.

### 2.2 Capture pipeline (DOM, not OCR)

```
CEF page loads → injected capture probe (self-guarding, idempotent)
  → reads: document.title, canonical URL, meta description, main-content text
    (reader-mode selector reuse), all a[href] (same probe family as link-hover),
    form fields touched, <time> elements, table contents
  → digest (SHA-256 content hash) → dedupe against Honeycomb Source content hashes
  → store Source node (canonical URL, capture method=dom, content hash, retrieval ts,
    origin-level permission verdict, privacy class)
  → optional: user-approved page → extract claims (ClaimExtractor reuse)
```

Constraints (from AGENTS.md §9 hard rules):
- Private tabs never captured. Kill-list origins (banking, messaging, password managers)
  never captured — origin-level, not app-level (browser-native advantage).
- PII backstop: card numbers, SSNs stripped before store (regex + Luhn, same as Rewisp).
- Capture cadence: on load-commit + settle-after-scroll + tab-switch, rate-limited.
- `capture_enabled` default ON for normal profile, OFF for private. Per-origin opt-out.
- Every capture logged to EventLedger (capture event, scope, privacy class).

### 2.3 What-changed diffs

- Revisit detection: same canonical URL, later timestamp → diff against last Source content.
- DOM-aware diff (not line-diff): ignore ads/boilerplate via reader-mode selector reuse;
  stable text tokens; report added/removed/modified lines + moved numbers.
- "What changed since Tuesday?" → retrieval: Honeycomb Sources for URL in time window →
  diff chain → render added/removed/moved with per-item `Source` provenance.
- Numbers-over-time: repeated numeric tokens (weight, grade, price) → sparkline extraction.

### 2.4 Promise catching

- Scope: only surfaces where the user writes (Gmail/Outlook/Slack web compose, form textareas)
  — never AI chats, ads, or random pages (Rewisp's lesson).
- Detection: rule + tiny local classifier (100m intent-router family). Reject questions,
  negations, hedges, marketing-speak. Extract deadline ("by EOD", "Friday", explicit date).
- Lifecycle: candidate → user confirms once → reminder on due day (single banner) → done
  when follow-up detected or user dismisses. Task node in Honeycomb with source link.
- False positives cost one dismissal, never a bad reminder.

### 2.5 Research trails

- When Tab B is created from a link in Tab A → record edge `TabA --opens--> TabB`.
- Session clustering: contiguous tabs sharing a project/topic (existing ProjectStore +
  intent-router tags) → "Investigation" group.
- A capture-to-brief loop: wisps in an investigation → `buildBriefJSON` (exists) →
  Brief node citing only stored Sources.
- UI: KnowledgePanel "Trails" tab — graph of the active investigation with source chips.

### 2.6 Nightly digest (upgrade Morning Brief)

- Existing Morning Brief payload gains: today's wisps summary, unfinished threads (tasks
  aging in days), learned-facts proposals.
- Approval loop: every learned fact is a proposal in Honeycomb; user approves/denies/edits;
  approval feeds the forgetting-curve weight (Rewisp memory.md pattern, but typed objects).
- Runs at configurable time (default 21:00), one local model call, nothing leaves device.

### 2.7 Forgetting curve & retrieval

- Retrieval = Honeycomb FTS5 (BM25) + embedding cosine (NLEmbedding exists, dim 512),
  fused via Reciprocal Rank Fusion; score × recency decay (λ tuned).
- Facts looked up N times get pinned (retention class `pinned`); items near the
  "forgetting cliff" get a rescue mention in the digest (spaced repetition on screen history).

### 2.8 MCP server (agents can query Hive memory)

- Read-only stdio MCP server (`hive-memory`), same token-gated local API pattern as the
  web-chrome bridge. Tools: `search_memory`, `get_promises`, `what_changed(url, since)`,
  `get_sources(project)`. Localhost-bound, read-only, never spends subscriptions.
- Claude Desktop / Claude Code / Cursor point at it. Documented in a follow-up README.

### 2.9 Privacy architecture (reduction-first)

- No screenshots ever written; DOM text only (even lighter than Rewisp).
- Origin-level kill list + per-origin opt-out stored in Honeycomb `Preference` nodes.
- SQLCipher at rest (Keychain key) with FTS5 kept working (page-level encryption — Rewisp's
  conclusion). Key custody: automatic unlock on session; Touch ID gating is a stretch goal.
- Forget buttons: "last 10 minutes" purge (rows + vectors + linked episodes).
- Default 6-month retention, importance-based pruning, nightly consolidation into summaries
  (DB gets leaner and higher-signal over time).
- Everything local; remote models only when user asks with explicit scope.

### 2.10 Phase A exit criteria

- Capture pipeline stores wisps with dedupe + privacy class; EventLedger records each capture.
- "What changed" answers with per-item provenance on a fixture pair of pages.
- Promise lifecycle: catch → confirm → remind → done, with no marketing-speak catches.
- Research trail graph renders in KnowledgePanel; capture-to-brief cites stored sources only.
- Nightly digest produces proposals; approve/deny updates weights.
- MCP server answers 4 queries from Claude Code locally.
- Tests: dedupe, kill-list, PII strip, diff noise-filter, promise classifier, RRF recency,
  purge, SQLCipher round-trip.

---

## 3. Phase B — Comet-class AI Sidecar

### 3.1 @-mention tabs

- In the panel input, typing `@` surfaces open tabs (title + favicon + host chips, like the
  existing tabPill). Selected tabs attach their URL + captured wisp into the prompt context.
- Context scope preview: before submit, the panel shows exactly which tabs/pages/sources are
  in scope (and their privacy class). No silent context widening (AGENTS.md principle).

### 3.2 Progressive step disclosure

- The research/agent run renders steps as they execute: `checking sources`, `reading page`,
  `extracting claims`, `synthesizing` — driven by the existing Swarm research session state.
- Live source chips appear as sources are fetched; final citations link to stored Sources.
- Kill switch always visible; cancels the session and revokes active grants.

### 3.3 Citation hardening

- Replace label-parsing citations with resolved citations: every `[n]` in the response must
  resolve to a stored `Source` node (id, URL, title, retrieval ts, content hash). Response
  renderer verifies before rendering; unverifiable citations render as warnings.
- Same contract as AGENTS.md §11.1: discovered / read / cited source distinction shown.

### 3.4 Permission previews

- Agent-proposed browser actions (navigate, organize tabs, fill form) render a human-readable
  preview card before execution: what, where, scope, reversibility. Reuses the existing
  approval panel (`ActionApprovalView`) with typed preview renderers per action kind.

### 3.5 Phase B exit criteria

- @-mention attaches scope with visible chips; scope preview shown pre-submit.
- Step disclosure renders live research state; kill switch cancels + revokes.
- Citations resolve to Honeycomb Sources; fake citations render as warnings.
- Action preview card for at least: navigate, move-to-group, open-panel.

---

## 4. Phase C — Browser credibility finish

### 4.1 Little Arc mini-windows

- ⌘⇧N opens a floating, frameless, always-on-top mini window (separate `WindowGroup` +
  smaller frame). Loads a URL in its own CefWebViewModel, dismissed with ⌘W / Esc.
- Link-click handler option: "Open in Little Arc" in the context menu.
- Reuses the full capture/history stack; mini windows log to history.

### 4.2 Auto-archiving tabs

- Policy: tabs idle > 12h (unpinned, non-essential, not playing audio, not selected) are
  archived: state captured, tab moved to archive (existing ArchivePanel + SessionStore),
  memory freed. Reopen restores. Configurable threshold; opt-out per site.
- Different from hibernation: archiving *removes* from the strip (Zen-style clean slate),
  hibernation keeps it visible but sleeping.

### 4.3 No-op command cleanup

- Audit every `CommandRegistry` action; wire or remove. Same for web-chrome palette entries.
- Add the missing small features the user flagged (site permissions panel, site info popup,
  tab search, session restore, download shelf — already present; verify each has a path).

### 4.4 Onboarding / import polish

- First-run: choose look (Chrome-mode vs Zen-mode) → import from Chrome/Safari/Firefox/Edge/
  Brave/Arc (ImportManager exists; fixture tests exist) → honest migration report.
- Onboarding sheets use the new dual-mode chrome; no fake checkboxes.

### 4.5 Phase C exit criteria

- Mini window opens/dismisses, routes links, logs history.
- Auto-archive policy: tab removed after threshold, restorable, exclusions respected.
- Zero no-op palette commands.
- First-run journey complete on a clean profile.

---

## 5. Cross-cutting requirements (all phases)

- **Tests:** every behavior unit-tested (HiveCoreTests pattern). No feature ships without a
  fixture or assertion.
- **EventLedger:** capture, consent, promise, diff, digest, approval, and browser actions all
  append. Audit view in Settings.
- **Reduced motion:** new UI respects the existing contract.
- **Private mode:** no wisp, no promise, no digest content from private sessions. Ever.
- **No AI slop:** honest labels; mock providers labeled; nothing fake streams.

## 6. Phasing order

```
P0  Phase A1: capture pipeline (wisp → Honeycomb Source, dedupe, privacy) + tests
P0  Phase A2: what-changed diffs + retrieval (RRF + recency) + tests
P0  Phase A3: promise catching (rule + classifier) + reminder lifecycle + tests
P0  Phase A4: research trails + capture-to-brief + KnowledgePanel Trails tab
P0  Phase A5: nightly digest upgrade + approval loop + forgetting curve
P0  Phase A6: MCP server + SQLCipher at rest + forget/purge + retention pruning
P1  Phase B1: @-mention tabs + scope preview
P1  Phase B2: step disclosure + kill switch
P1  Phase B3: citation hardening (resolve-to-Source)
P1  Phase B4: permission preview cards
P2  Phase C1: Little Arc mini-windows
P2  Phase C2: auto-archiving tabs
P2  Phase C3: no-op command cleanup
P2  Phase C4: onboarding/import polish
```

Each letter ships as its own commit with build + tests green.

---

## 7. Definition of done (mega-plan)

- Phase A exit criteria (§2.10) met with fresh test evidence.
- Phase B exit criteria (§3.5) met with fresh test evidence.
- Phase C exit criteria (§4.5) met with fresh test evidence.
- `swift build` green; `swift test` green (except pre-existing MLX metallib env failure).
- AGENTS.md §18 handoff entry appended with evidence.
