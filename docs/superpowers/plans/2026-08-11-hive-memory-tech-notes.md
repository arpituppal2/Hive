# Hive Memory Mega-Plan — Technical Addendum (de-risked decisions)

> **Date:** 2026-08-11
> **Companion to:** `docs/superpowers/plans/2026-08-11-hive-memory-megaphase.md`
> **Status:** audit + research addendum; historical A1–A6 task labels remain for product scope only. For implementation ordering and current M4 behavior, `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md` and `docs/superpowers/plans/2026-08-11-m4-diffs-trails-hybrid-retrieval-plan.md` take precedence.

This addendum resolves the open technical questions so execution has zero unknowns. Every claim here was verified against the actual codebase (2026-08-11) or sourced from primary documentation.

---

## 1. Capture probe — reuse the proven injection pattern

**Verified pattern in code:** `BrowserState.swift` already ships two self-guarding, idempotent
JS probes that report via the console bridge:

```js
(function(){
  if (window.__hiveMediaProbeInstalled) return;   // self-guard
  window.__hiveMediaProbeInstalled = true;
  ... console.log('HIVE_MEDIA|' + kind);          // bridge channel
})();
```

(`mediaStateProbeScript` ~line 236; `linkPeekProbeScript` ~line 262.)

**Decision (A1):** the wisp probe follows the identical contract:
- Guard: `window.__hiveWispProbeInstalled`
- Report: `console.log('HIVE_WISP|' + JSON.stringify(payload))` — single message per capture
  batch, rate-limited by the native side
- Payload: `{ url, title, metaDescription, contentHash, mainText, linksSample[],
  touchedForms, timeValues[] }` (bounded: mainText ≤ 24KB, links ≤ 50, timeValues ≤ 20)
- Extraction reuses the **reader-mode selector set already in `readerModeJS()`
  (`BrowserState+Reader.swift:62`)** for boilerplate removal, plus positive selectors
  (`article`, `main`, `[role=main]`, `.post-content`, `.entry-content`) per Mozilla
  Readability scoring (research §Readability).

**Why console-bridge (not fetch):** zero new bridge plumbing; the native side already
parses `HIVE_*` console prefixes for media/link-peek. CORS-safe by construction.

## 2. Storage — build on the verified Honeycomb schema

**Verified:** `HoneycombStore.swift` is raw `SQLite3` (no GRDB), FTS5 virtual table
`honeycomb_fts` (line 229), typed nodes with `NodeType` (`.source/.capture/.claim/
.project/.task/.brief/.preference/.note` — lines 58-71), typed edges with `EdgeRelation`
(`belongsTo/derivedFrom/references/nextAction/annotates` — lines 119-131), dedupe via
`findNode(type:contentHash:)` (line 541), `search(query:limit:)` BM25 (line 639).

**Decisions (historical A-labels; execute only behind M0–M3 gates):**
- **A1 dedupe:** `WispStore.recordWisp` → `findSource(byContentHash:)` (SourceAndClaim
  line 451) then `createSource` (line 423). Content hash = SHA-256 of normalized mainText
  (normalize: collapse whitespace, strip trailing punctuation).
- **A2/M4-B diff:** `PageDiff` operates on the **stored SourceVersion text** (not live DOM) — diff
  previous Source vs current Source for the same canonical URL. Boilerplate noise already
  removed at capture, so line-diff + number-token pass is sufficient (research: Rewisp's
  text-block diffing; we're strictly better — DOM-clean input).
- **A4/M4-C trail edge:** add `case opens` to `EdgeRelation` (deliberate new case; the enum is
  `CaseIterable` and `tiersAreSelfConsistent`-style tests lock it). Tab B created from link
  in Tab A → `Edge(source: tabA.node, target: tabB.node, relation: .opens)`.
- **A2/M4-D hybrid retrieval:** `HybridRetriever` = `HoneycombStore.search` (BM25) +
  `SystemEmbeddingRuntime.embed` (verified: `EmbeddingRuntime.swift:20`, NLEmbedding,
  dim 512, zero-dep) → **Reciprocal Rank Fusion** with `k=60` + recency decay
  `score × e^(−λ·ageDays)`, λ default 0.01. (Research: RRF is the standard on-device
  fusion; 300-400-char chunks score ~2.3× better than 1.5KB chunks — capture stores
  heading-delimited chunks when mainText > 8KB.)

## 3. Encryption at rest — ADR-gated build decision

**Verified:** `Package.swift` has NO SQLite wrapper dependency (raw `import SQLite3`);
`HoneycombStore(path:)` opens with `sqlite3_open`. Research confirms SQLCipher supports
FTS5 (shadow tables encrypted at page level; key via Keychain `SecRandomCopyBytes` +
`PRAGMA cipher_memory_security=ON`; GRDB `prepareDatabase` pattern).

**Decision (A6):** encryption-at-rest is a **separate ADR** because it changes the
zero-external-dependency policy (AGENTS.md §15.1). Two candidates:

| Option | Deps | FTS5 | Verdict |
| --- | --- | --- | --- |
| **A. SQLCipher via SPM** | `SQLCipher` or `GRDB.swift`+SQLCipher | yes (page-level) | Recommended — battle-tested, Rewisp uses it; keep `HoneycombStore` abstraction, add a `SQLCipherHoneycombStore` conformance |
| **B. Keychain + FileVault reliance** | none | yes | Interim: rely on FileVault (system-wide) + Keychain-scoped db dir (0700). Rewisp's own admission: FileVault is the real backstop until app-level encryption |

**Recommended sequencing:** ship A1–A5 on plain SQLite (FileVault-backed, `chmod 0700` dir —
matches Rewisp's "reduction-first" lesson), land A6 with the ADR choosing SQLCipher. The
store API is already actor-isolated behind `HoneycombStore`, so swapping the backing is
contained. **Kill-list + PII reduction remain the first line of defense regardless.**

## 4. Promise classifier — hybrid rule + tiny local model

**Research:** commitment detection datasets are fragmented (email-to-task / conversation
corpora); no dominant open benchmark. Small classifiers + deadline NER work well when
scoped; the failure mode to kill is false positives (Rewisp: "rejects questions, negations,
hedges and marketing-speak"; "false positive costs one dismissal").

**Decision (A3):**
- **Scope gate first** (cheap, deterministic): only run the classifier on writing surfaces —
  Gmail/Outlook/Slack-web compose + `textarea` focus events. Never AI chats, ads, random
  pages. This alone eliminates most noise (Rewisp's exact lesson).
- **Rule layer** (deterministic, always-on): subject+verb-of-commitment lexicon
  (`will send`, `I'll`, `promise`, `owe`, `send you`, `follow up`, `get back`, `share`),
  deadline extraction (relative: `EOD`, `EOW`, `today`, `tomorrow`, `Friday`, `next week`,
  `in N days`; absolute: ISO + US dates), rejection rules (starts with question word,
  contains `?`, negation `won't/can't`, hedge `maybe/perhaps/probably`, marketing verbs).
- **100m classifier** (existing `intentClassifier`-family role contract, honest Mock until
  weights land): `{isPromise, deadline}` on the rule-layer candidates only.
- **Lifecycle:** candidate → one-tap confirm chip (bottomChipOverlays pattern) → Task node
  (`TaskStore`, source link) → single reminder on due day (notificationTray banner) → done
  when follow-up text matches the promise subject OR user dismisses.

## 5. MCP server — stdio JSON-RPC, exact protocol verified

**Research (sourced):** MCP = newline-delimited JSON-RPC 2.0 over stdio. Messages:
`initialize` → `{protocolVersion, capabilities, clientInfo}`; `tools/list` → tool array
with `inputSchema` (JSON Schema); `tools/call` → `{content:[{type:"text",text}], isError}`.
Claude Desktop registration: `~/Library/Application Support/Claude/claude_desktop_config.json`
→ `{"mcpServers":{"hive-memory":{"command":"<binary>","args":[]}}}`. Claude Code and Cursor
use the same stdio contract. **stdout is reserved for JSON-RPC; all logging → stderr.**

**Decision (A6):** `HiveMemoryMCP.swift` — a small standalone executable target
(`hive-memory`) linking HiveCore, reading `FileHandle.standardInput` line-by-line, serving:
`search_memory(q, limit)`, `get_promises()`, `what_changed(url, since)`,
`get_sources(projectID)`. Read-only; token-gated against the same Keychain-issued session
token family as the web-chrome bridge; localhost-only if a TCP variant is ever needed.
Documented in `Sources/Hive/Resources/hive-memory/README.md`.

## 6. Sidecar — verified state plumbing for step disclosure

**Verified:** `BrowserState.deepResearchStep: ResearchStep?` (BrowserState.swift:1601) is
already set to `.inProgress(phase)` during research runs (`BrowserState+Research.swift:116`)
and `.complete(brief)` at the end (line 144). The web chrome DTO already carries
`deepResearchStep` + `councilLiveResponses`.

**Decisions (B1–B4):**
- **B1 @-mention:** `GeminiSidePanel+Input.swift` — reuse existing `tabPill(_:)` (line 431);
  `BrowserState+AI.swift` — extend `submitGeminiQuery` with `attachments: [TabAttachment]`
  (URL + captured Source id). Scope preview = chips before submit; context redaction via
  existing `ContextRedactor` (HiveCore/AI).
- **B2 steps:** render `state.deepResearchStep` phases as the step list in
  `GeminiSidePanel+Messages.swift` (alongside the existing `verdictReveal`); kill button
  reuses the session-cancellation path in `BrowserState+Research.swift`.
- **B3 citations:** response renderer resolves each `[n]` to `Source` via
  `getSource(id:)` (SourceAndClaim:429) before drawing; unverifiable → warning chip.
  Distinguish discovered / read / cited via capture-state metadata.
- **B4 previews:** `ActionApprovalView` gains per-kind preview renderers
  (navigate / move-to-group / open-panel); both approve and deny call
  `EventLedgerStore.record` (verified: line 342).

## 7. Phase C — verified anchors

- **C1 Little Arc:** `HiveApp.swift:71` has `WindowGroup(id: "main")` — add
  `WindowGroup(id: "mini")` with a small frameless `MiniWindowView`; ⌘⇧N shortcut; dismiss
  ⌘W/Esc; own `CefWebViewModel`; history logging reuses `BrowserState+Navigation`.
- **C2 auto-archive:** extend `BrowserState+Hibernation.swift` policy (idle >12h, unpinned,
  non-essential, no audio, not selected → archive via existing `ArchivePanel` +
  `SessionStore`). Distinct from hibernation: archiving removes from the strip.
- **C3 no-op cleanup:** `Sources/HiveCore/Commands/CommandRegistry.swift` (verified: 30+
  cases, `newTab` → `toggleSwarm`). Audit each case for a reachable path; wire or remove.
  Same sweep on the web-chrome palette entries.
- **C4 onboarding:** `BrowserImport.swift` verified supporting Chrome/Safari/Brave/Edge/Arc/
  Firefox/Zen. First-run: look choice (Chrome-mode vs Zen-mode) → import → honest
  partial-import report.

## 8. Risk register

| Risk | Mitigation |
| --- | --- |
| SQLCipher dep change | ADR first; store abstraction contains the swap; FileVault interim |
| Promise false positives | Scope gate (writing surfaces only) + rule layer + one-tap confirm before any reminder |
| Wisp capture memory | 24KB cap, rate-limit, 6-month retention + nightly consolidation (DB stays lean — Rewisp pattern) |
| MCP binary distribution | Standalone executable target; documented config; read-only + token-gated |
| `EdgeRelation.opens` new case | Enum is CaseIterable — add + lock with a test, same as `sharedRepoGroupsCohort` pattern |
| NLEmbedding dimension drift | `SystemEmbeddingRuntime.dimensionality == 512` already asserted in tests |
