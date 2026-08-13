# Hive Memory Wedge — Execution Plan v2

> **Date:** 2026-08-11
> **Status:** planning canon; no implementation in this document
> **Supersedes:** the task ordering in `2026-08-11-hive-memory-megaphase.md` only. It does not delete or invalidate that plan's product scope.
> **Primary specs:** `HONEYCOMB_SPEC.md`, `WISP_CAPTURE_SPEC.md`, `IMPORT_MIGRATION_SPEC.md`, `MORNING_BRIEF_SPEC.md`, `MEMORY_ARCHITECTURE_SPEC.md`, `ROUTING_SPEC.md`, `2026-08-11-m0-storage-migration-recovery-spec.md`, `2026-08-11-m1-explicit-capture-spec.md`, `2026-08-11-m2a-import-resilience-plan.md`, `2026-08-11-m2b-brief-credibility-plan.md`, `2026-08-11-m3-candidate-wisp-plan.md`, `2026-08-11-m4-diffs-trails-hybrid-retrieval-plan.md`, `2026-08-11-m5-digest-promises-forgetting-retention-plan.md`, `2026-08-11-m6-mcp-encryption-decision-plan.md`, `2026-08-11-m10-sidecar-b1-b4-plan.md`
> **Code truth:** current source and fresh tests outrank prior plan claims. Current code has Honeycomb v2, EventLedger v1, HotMemory, manual page/note capture, browser import parsers/merge policies, and a deterministic Morning Brief. Automatic wisp ingestion, import reports, Brief resume/provenance fields, vectors, temporal validity, and MCP are planned—not verified.

---

## 0. The decision

The original mega-plan began at automatic DOM capture. That is too early. Ambient capture multiplies the cost of every unresolved storage, deletion, privacy, scope, and audit mistake. Execution v2 starts with the smallest trusted loop and moves automatic capture behind it.

**Milestone naming note:** the M0–M6 labels in this document are execution gates for this plan. Existing product specs may retain historical phase labels such as “M2” for the wisp product capability; those labels do not override this dependency ordering.

```text
storage invariants
  → explicit capture with durable provenance
    → honest import reports + useful zero-history brief
      → candidate-only wisp capture
        → diffs/trails/hybrid retrieval
          → digest/forgetting
            → MCP + encryption decision gate
```

### Browser-first rule

At every milestone, disabling Swarm and memory must leave a useful browser. No memory task may block navigation, tabs, import, private browsing, or the zero-history start page. Any persistence failure must degrade visibly and fail closed for durable writes—not silently disable ordinary browsing.

### No ambient authority rule

Automatic capture can create a **candidate** only. It cannot create durable memory, widen model context, grant a permission, or trigger a consequential action. Promotion is a separate user-visible operation with provenance and deletion semantics.

---

## 1. Current verified baseline

### 1.1 Storage

- `HoneycombStore` (`Sources/HiveCore/Honeycomb/HoneycombStore.swift`; covered by `PersistenceHealthTests`, `MemoryLifecycleTests`, and Honeycomb suites): SQLite actor, schema versions 1–2, WAL requested, foreign keys enabled on its connection, typed nodes/edges, FTS5, revisions, dedup, delete-by-provenance, delete-older-than, Markdown export.
- `EventLedgerStore` (`Sources/HiveCore/EventLedger/EventLedgerStore.swift`; covered by EventLedger/consent and handoff suites): SQLite actor, schema v1, append-only event rows, idempotent `recordIfAbsent`, query APIs by event dimensions, retention deletion.
- `HotMemoryStore` and `MemoryAdmission` (`Sources/HiveCore/Browser/HotMemoryStore.swift`, `MemoryAdmission.swift`; covered by `HotMemoryAdmissionTests` and `SwarmMemoryAdmissionTests`): bounded in-memory/session surface with explicit scope/profile/workspace guards, forgotten-node blocking, and durable-versus-candidate admission.
- `MemoryAdmissionPolicy`: user-authored non-private capture is eligible for `.durable`; model extraction is `.candidate`; private content is rejected. This is an audited code baseline, not an assertion that the planned wisp pipeline exists.

### 1.2 User-visible flows

- `captureCurrentPage()` and `captureNote(_:)` (`Sources/Hive/BrowserState+Brief.swift`; page-capture and lifecycle tests): durable user-authored capture, fail-closed persistence, Honeycomb dedup, HotMemory warm, EventLedger capture event, `memoryRevision` update.
- `BrowserImportEngine` (`Sources/HiveCore/Browser/BrowserImportEngine.swift`) and `BrowserState.mergeImportedData` (`Sources/Hive/BrowserState+Setup.swift`): local parsers for Safari/Chrome/Edge/Brave/Arc/Firefox/Zen bookmark/history data, with sanitation and merge policies; source-level reports remain planned.
- `buildBriefJSON()` + `ProactiveBriefPlanner` (`Sources/Hive/BrowserState+Brief.swift`, `Sources/HiveCore/Browser/ProactiveBriefPlanner.swift`; `MorningBriefContractTests`, planner tests): deterministic, escaped payload; open non-private tabs/history/memory/calendar opt-in; honest empty-state fallbacks.

### 1.3 Planned and absent

- `.wisp` candidate storage and `HIVE_WISP` ingestion.
- Import source reports, source-specific retry, persisted report history.
- Versioned Brief resume/provenance/dismissal payload.
- Honeycomb vectors, temporal validity, wisp migration, `opens` edge.
- Formal retention/consolidation implementation, MCP server, SQLCipher.

---

## 2. Workstream ownership map

| Workstream | Code owner | Product spec | Primary tests |
|---|---|---|---|
| Storage/migrations | `Sources/HiveCore/Honeycomb/HoneycombStore.swift`, `EventLedgerStore.swift` | HONEYCOMB §4; `2026-08-11-m0-storage-migration-recovery-spec.md`; this plan M0 | migration, rollback, FTS, FK, backup, integrity, recovery, persistence-health suites |
| Explicit capture | `BrowserState+Brief.swift`, `HotMemoryStore.swift` | WISP §1/§3; this plan M1 | PageCapture, MemoryAdmission, MemoryLifecycle, EventLedger |
| Import resilience | `BrowserImportEngine.swift`, `BrowserImport.swift`, `OnboardingSheet.swift`, `BrowserState+Setup.swift` | IMPORT_MIGRATION_SPEC | browser fixture, merge, report, cancellation tests |
| Brief contract | `BrowserState+Brief.swift`, `ProactiveBriefPlanner.swift`, WebChrome brief assets | MORNING_BRIEF_SPEC | MorningBriefContract, planner, payload/schema tests |
| Candidate wisps | new HiveCore candidate store + app probe | WISP §2–§7 | probe fixture, candidate admission, privacy, retention tests |
| Retrieval/diffs/trails | new HiveCore memory modules + KnowledgePanel | HONEYCOMB §4; prior mega-plan A2/A4 | diff, RRF, temporal, edge, citation tests |
| Digest/forgetting | new HiveCore digest/retention modules + Brief UI | MEMORY §3–§5; WISP §4–§5 | approval, decay, purge, no-private-leak tests |
| MCP/encryption | new local adapter + app lifecycle/settings | prior mega-plan A6; this plan M6 gate | protocol, token, deletion, backup/restore, security tests |

No workstream may bypass the shared stores or create a second memory authority.

---

## 3. Milestones and exact gates

## M0 — Storage invariants and migration harness

**Detailed contract:** `docs/superpowers/plans/2026-08-11-m0-storage-migration-recovery-spec.md`.

**Goal:** make future memory writes safe to evolve before adding any new ingress.

### Work

1. Add a single migration harness contract for Honeycomb and EventLedger:
   - sequential version checks;
   - each version runs in a transaction; SQLite schema DDL participates in transactions, subject to the supported SQLite version's ALTER TABLE capabilities;
   - user version advances only after successful completion;
   - failed migration leaves the prior version and a recoverable error;
   - migration tests run against a fresh DB and fixtures at every prior version.
2. Verify and test per-connection invariants: execute `PRAGMA foreign_keys = ON` on every opened connection (SQLite does not enable it globally and it cannot be toggled mid-transaction), disclose WAL behavior and its single-writer limit, verify FTS row maintenance, parameterized values, and cancellation boundaries.
3. Define a local backup/restore contract before destructive migrations. Prefer SQLite's Online Backup API for a consistent snapshot while the database is active; if a filesystem copy is used, document WAL/shared-memory handling and the safe copy boundary. Do not claim a raw file copy is transactional.
4. Add a schema compatibility record to the planning docs after fresh evidence. Evidence: [SQLite transactions](https://www.sqlite.org/lang_transaction.html), [foreign keys](https://www.sqlite.org/foreignkeys.html#fk_enable), [WAL](https://www.sqlite.org/wal.html), and [Online Backup API](https://www.sqlite.org/backup.html).

### Stop conditions

- Do not add `.wisp`, vectors, `opens`, or retention tables until migration rollback and FTS/FK tests pass.
- Do not claim secure deletion from `FileManager.removeItem`; cryptographic erasure/SQLCipher requires a separate gate.

### Exit gate M0

Fresh DB, v1 fixture, v2 fixture, interrupted migration, rollback, FK cascade, FTS consistency, backup/restore, and persistence-health tests pass. Ordinary browsing remains unaffected if a store cannot open.

---

## M1 — Explicit capture vertical slice

**Detailed contract:** `docs/superpowers/plans/2026-08-11-m1-explicit-capture-spec.md`.

**Goal:** prove Browse → Remember → Search/inspect with no automatic capture and no model dependency.

### Work

1. Keep `captureCurrentPage()` as the trusted durable boundary; extract only shared pure policy/helpers if needed.
2. Make the result explicit: new capture, duplicate reused, private blocked, no usable page, persistence degraded, storage failure, or partial audit. Never show a generic success for an unknown state.
3. Ensure captured Source metadata has stable URL, host, capture method, timestamp, content hash, privacy class, and user-visible provenance. The current path is URL/title/host metadata, not a full readable article.
4. Ensure every admitted non-private durable capture attempt, including duplicate reuse, has one retry-idempotent EventLedger `.capture` event whose context ID resolves to the actual stored/reused node; private denials emit no event payload containing private URL/title, and partial Honeycomb/EventLedger outcomes remain visible and retryable.
5. When `aiContextAllowed == false`, persist manual capture to Knowledge but suppress HotMemory warming and any model context use.
6. Represent capture-attempt audit state as an enforced durable contract: M0 adds versioned `honeycomb_capture_attempts` rows with `audit_status` (`unknown_legacy | pending | complete | incomplete`), stable `capture/<attemptID>/v1` event identity, and the shared `MemoryRetrievalAdmission` predicate. It excludes absent/unknown, pending, and incomplete attempts from Honeycomb model retrieval, HotMemory, context-broker admission, and retrieval-ranker input until stable `recordIfAbsent` reconciliation succeeds; a failed duplicate attempt never downgrades a previously complete node. Private denials never emit a ledger payload containing their URL/title.
7. Add a direct knowledge-panel path to inspect, forget from context, export, and delete the captured source, with those scopes and audit status labeled distinctly.
8. Test normal/private/page-only/workspace scope combinations, duplicate auditing, stable retry identity, hostile metadata, and browser-disabled/persistence-degraded fallback.

### Exit gate M1

On a clean profile, a user can open a page, explicitly capture it, receive a truthful new/duplicate receipt that says URL/title/host metadata, find it in Honeycomb/Knowledge, inspect provenance and audit state, export it, forget it from context, delete durable memory, and confirm it no longer enters HotMemory context. With context disabled, manual capture persists to Knowledge but does not warm HotMemory. Audit-incomplete nodes are inspectable/exportable but excluded across model retrieval, HotMemory, context-broker admission, and ranker input until reconciliation. Private capture produces no durable write. Persistence failure leaves browsing usable and never shows success. No model, network, wisp probe, or remote service is needed.

---

## M2 — Import resilience and Brief credibility

**Goal:** remove the two largest first-hour retention failures: silent migration loss and an empty/creepy start page.

### M2A — Import resilience

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m2a-import-resilience-plan.md`.

1. Add versioned `ImportSourceSnapshot`, `ImportReport`, `ImportBatchContext`, and dedicated Application Support report persistence outside Honeycomb/session memory.
2. Preserve existing parsers and merge policies while exposing source-level availability: available, installed-but-empty, locked, unreadable, unsupported-profile, and not-installed.
3. Run each selected source independently with typed phase transitions, cancellation checkpoints, temporary-copy cleanup, stable batch identity, and source-specific retry lineage.
4. Reconcile accepted bookmark/history counts and reason buckets through `BrowserState.mergeImportedData`; never infer durable completion from parser counts alone.
5. Make onboarding/Settings copy match actual capability: bookmarks/history only, with partial success and report links.

**Detailed contract:** `Sources/Hive/Resources/Swarm_System_Prompts/IMPORT_MIGRATION_SPEC.md`.

### M2B — Brief credibility

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m2b-brief-credibility-plan.md`.

1. Add versioned `brief.v2` contracts and an allow-listed payload while preserving the existing placeholder transport.
2. Build deterministic resume selection from open tabs, reading list, and history with private/internal/invalid filtering, stable ordering, provenance, and an eight-item cap.
3. Store scoped Brief dismissals in a dedicated versioned local store; omission from payload is distinct from Honeycomb deletion or HotMemory forgetting.
4. Filter Honeycomb memory through a pure Brief eligibility boundary before the planner; exclude private, candidate, forgotten, audit-incomplete, out-of-scope, and unknown-legacy records.
5. Keep calendar opt-in/lazy/bounded/local-only and the zero-history page useful without memory, models, or network.

**Detailed contract:** `Sources/Hive/Resources/Swarm_System_Prompts/MORNING_BRIEF_SPEC.md`.

### Exit gate M2

On a clean profile, the user can skip import and still browse; inspect all seven source availability states; import a fixture with a partial source failure and receive independent source reports/retry; rerun import without duplicate records or local-edit loss; open a zero-data Brief with search/import/blank-workspace utility and no invented content; open a populated Brief with deterministic resume items and provenance labels; dismiss a card without deleting its source; and verify private tabs/history never enter the payload. M2 has no ambient capture, model-generated prose, network feed, password/extension/tab migration, or remote service dependency.

---

## M3 — Candidate-only wisp capture

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m3-candidate-wisp-plan.md`.

**Goal:** validate whether quiet browser-native memory is useful without creating unreviewed durable memory.

### Work

1. Use a dedicated schema-v1 candidate store at `Application Support/Hive/wisp-candidates.sqlite3`; do not add a Honeycomb `.wisp` node type in M3.
2. Register the candidate store as a first-class M0 storage participant: all writes pass through `StorageEpochCoordinator`, triple snapshots include Honeycomb/EventLedger/WISP candidate databases and schema versions, recovery-journal classification includes candidate operations, and corruption never initializes an empty replacement.
3. Implement durable promotion leases and restart reconciliation before exposing concurrent Save actions. A lease is native-owned, scope-bound, single-use, and cannot be completed without its unexpired owner token.
4. Inject the minimal self-guarding `HIVE_WISP` probe: start with `settled` only. Do not begin with page-body extraction, promise catching, or screenshot/VLM capture.
5. Route every privacy decision through one metadata-only `WispCapturePrivacyPolicy`; deny on unknown private state, host classification, password-form metadata, or scope.
6. Route candidate listing/assembly through one `WispContextAdmission` seam at HotMemory, PageContextBroker, Honeycomb retrieval, ranker, Brief, and export boundaries. Candidate UI is allowed; model-context admission is not.
7. Render a quiet candidate surface with Save / Not now / Never for this site. Candidate creation never promotes automatically.
8. Bound both active and lifecycle rows, retain canonical and observed URL provenance, and define tombstone cleanup/recovery before candidate nuke/forget/export.

### Exit gate M3

Fixture pages prove M0-integrated candidate storage/recovery, deterministic candidate creation, zero private/kill-list/unknown-policy candidates, bounded active and total storage, lease-safe explicit promotion only through M1, no candidate in default Swarm context or any shared retrieval boundary, visible observed/canonical provenance, and scope-bound deletion. Runtime evidence required on a clean profile.

---

## M4 — Diffs, research trails, and hybrid retrieval

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m4-diffs-trails-hybrid-retrieval-plan.md`.

**Goal:** turn explicitly retained pages into reproducible change evidence, bounded research trails, and admission-safe hybrid retrieval without making browsing itself an ambient memory write.

1. Execute M4-A source-version identity before any diff/vector/trail work: immutable observed/canonical URL provenance, extractor/normalization identity, content hashes, metadata-only compatibility, and deletion/rebuild semantics.
2. Execute M4-B deterministic `PageDiff` over retained versions only. Use versioned block/text normalization and fixture-driven boilerplate/noise filtering; no live-DOM inference, screenshots, network fetch, or model-generated changes.
3. Execute M4-C with exactly one new typed `opens` edge. Emit it only when both retained Source endpoints are eligible and scope-compatible; unresolved navigation never synthesizes a node or widens memory.
4. Execute M4-D only after M0/M3 deletion gates: versioned vector generations, dimension/model checks, FTS + vector candidate lists, RRF fusion, temporal validity/supersession, lexical-only fallback, deterministic ordering, and measured category-level baselines.
5. Add What Changed, Trails, and citation integration only after the substrate fixtures pass. UI must distinguish changed/unchanged/insufficient-retained-text/deleted/unavailable states.

### Stop conditions

- Do not add vectors or a new edge until M0/M3 recovery, deletion, and admission contracts are implemented and evidenced.
- Do not allow candidates, private/unknown-policy records, audit-incomplete captures, or deleted records into either lexical or vector ranking.
- Do not claim a universal retrieval lift; report frozen-corpus metrics by exact-token, conceptual, temporal, as-of, and mixed-query category.
- Do not claim a change or citation that cannot be reproduced from retained SourceVersion IDs and evidence spans.

### Exit gate M4

M4-A through M4-D fixtures pass; source-version identity is immutable and deletion-aware; v1/v2 diff precision and false-positive thresholds pass; A→B→C creates only two bounded `opens` edges; current/as-of temporal queries behave correctly; hybrid meets the locked baseline gates with honest lexical fallback; deletion/rebuild finds no FTS/vector/diff/edge ghosts after restart; citations resolve to retained Source nodes; and a clean-profile browser remains usable with memory/Swarm disabled.

---

## M5 — Digest, promises, forgetting, and retention

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m5-digest-promises-forgetting-retention-plan.md`.

**Goal:** make memory self-maintaining without making it self-authorizing.

### Work

1. Detect PromiseCandidates only on approved writing surfaces, preserving exact evidence spans and source-version identity. Candidate → explicit confirmation/edit → M1-compatible Task promotion; never parser/model → Task directly.
2. Assemble a versioned DigestManifest from a fixed local snapshot of real candidates, retained sources/versions, tasks, diffs/trails, and approved events. Render deterministic text first; a local model may phrase only the frozen manifest.
3. Add approve/deny/edit/snooze/withdraw for candidates and learned-fact proposals. Every durable decision is an idempotent EventLedger consent event with resumable per-item state.
4. Add bounded reinforcement and retention eligibility over typed objects in the authoritative M5 lifecycle store at `Application Support/Hive/m5-lifecycle.sqlite3`, registered as an M0 storage/recovery participant. Explicit approval/pin outranks local access signals; candidates remain review-only; decay excludes before ranking and never overrides explicit user retention.
5. Implement “Forget last 10 minutes” as a crash-resumable, journaled scope owned by the M5 lifecycle store and coordinated across candidates, durable source versions, diffs, vectors, edges, digest state, derived caches, and eligible ledger metadata; do not claim it erases OS-level forensic remnants without encryption/secure-delete evidence.
6. Make nightly consolidation idempotent and reproducible from retained input manifests. Missing evidence, unavailable stores, denied notifications, and unavailable models degrade visibly rather than inventing content.

### Stop conditions

- Do not run promise detection on unknown/private/kill-list/non-writing surfaces.
- Do not promote, remind, or mutate a task from a proposal without explicit user consent and durable audit evidence.
- Do not mark a purge complete while any dependent store or retrieval generation is unreconciled.
- Do not claim a background digest ran when the app was not scheduled/launched; next-launch assembly must disclose its actual cutoff.

### Exit gate M5

The frozen promise corpus meets its precision/false-positive/evidence-span gates; zero automatic promotion occurs under replay/adversarial fixtures; confirmation creates exactly one linked Task with truthful due-date state; digest manifests are bounded, reproducible, provenance-linked, private-safe, and resumable; approve/deny/edit is durable and audited; retention/forgetting is tested across all dependent stores and retrieval generations; rerunning consolidation produces no duplicate episodes; and restart after approval, consolidation, or purge leaves no deleted/private/unknown/audit-incomplete record retrievable.

---

## M6 — MCP and at-rest encryption decision gate

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m6-mcp-encryption-decision-plan.md`.

**Goal:** expose memory safely to local agents and decide encryption architecture from evidence rather than a slogan.

M6 is a read-only boundary, not a general agent host. It begins with a Hive-owned stdio adapter and a fixed allow-list of `search_memory`, `get_promises`, `what_changed`, and `get_sources`. Installation consent and connection/grant consent are separate. Every request uses a server-owned scope intersected with M0–M5 admission, retention, deletion, and redaction policy; caller-supplied scope cannot widen access. No write tools, arbitrary files/SQL, private-content access, remote clients, or ambient browser authority are included.

The M6 plan defines strict JSON-RPC/MCP framing, Keychain-backed versioned connection identity, consent/revocation state, bounded pagination tied to storage epochs, cancellation and stale-generation checks, minimal query audits, and explicit unavailable/deletion-pending states. Unix sockets and loopback HTTP are optional follow-on evaluations only; loopback must bind narrowly and enforce hostile-origin defenses.

The encryption work is an ADR, not a preselected implementation: measure plain SQLite + FileVault, SQLCipher/equivalent page-level encryption, and application-level/session-key encryption against FTS, WAL/temp leakage, startup/unlock, backup/restore, migrations, licensing, key custody, and deletion limits. `SyncCipher` and Keychain storage are not evidence that SQLite pages or backups are encrypted. If no candidate clears the gates, retain the current posture honestly with limitations disclosed.

### Exit gate M6

A clean-profile external local client can read only explicitly approved, provenance-preserving memory through the four fixed methods; every access is minimally auditable; scope widening, private/candidate/deleted leakage, stale cursors, arbitrary path access, and writes are rejected; revocation and restart work; M0 four-store restore/deletion generations are respected; and the encryption/backup posture has a reproducible ADR with selected/rejected options and unsupported claims stated.

---

## 4. Dependency graph

```text
M0 storage/migration harness
 ├── M1 explicit capture
 │    ├── M3 candidate-only wisps
 │    │    ├── M4-A source versions
 │    │    │    ├── M4-B deterministic diffs
 │    │    │    ├── M4-C typed trails
 │    │    │    └── M4-D hybrid retrieval
 │    │    │    └── M5 digest/forgetting/retention
 │    │    │         ├── M6 MCP + encryption ADR
 │    │         └── M10 Sidecar B1–B4
 │    └── M2 import resilience + Brief credibility
 └── M2 import/Brief may proceed in parallel once M0's persistence/report boundaries are stable
```

M2 does not depend on automatic wisps. M3 does not depend on a model. M6 cannot be pulled forward merely to make a demo look complete. M10 cannot be pulled forward until its M0–M6 context, provenance, deletion, and approval dependencies are evidenced.

---

## 5. Per-milestone verification protocol

For every milestone:

1. `git status --short` and inspect all modified/untracked files.
2. Run the smallest touched HiveCore test suite.
3. Run `swift build` and `swift test` when the baseline permits.
4. Run fixture/security tests: private content, prompt injection, PII, path traversal, malformed data, cancellation, deletion, and scope transitions as relevant.
5. Record exact output and remaining risk in AGENTS.md §18 before changing any capability label.
6. Do not mark a capability `verified` from source presence or a mock path.

### Browser runtime gate

At M1, M2, M3, M5, and M10 close, run a clean-profile manual path with memory/Swarm disabled and enabled. Verify navigation, tab switching, private mode, import, restart, deletion, and Brief rendering. Memory must remain an optional layer.

---

## 6. Explicitly deferred

- Password/extension/open-tab import beyond the current bookmark/history contract.
- Screenshot capture or all-day OS-level screen recording.
- Remote/cloud memory as a default.
- Model-generated autonomous promotion.
- Freeform Honeycomb edge names.
- SQLCipher implementation before the ADR and dependency decision.
- Broad connector gallery, collaboration, or suite modules.
- Training new local models as a prerequisite for the browser memory wedge.
- Ambient all-tabs Sidecar context, MCP write tools, arbitrary shell/file/desktop actions, and hidden browser automation before a separate approved milestone.

---

## 7. Definition of done

The memory wedge is **verified** only when M0–M5 have fresh build/test/runtime evidence, M6’s MCP/encryption gate has a documented decision, and M10’s Sidecar gates have fresh browser/runtime evidence. The browser remains credible with memory disabled, every retained object has provenance and deletion behavior, and no automatic path silently widens model context or user authority.

## M10 — Browser-native Sidecar B1–B4

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m10-sidecar-b1-b4-plan.md`.

**Goal:** make Swarm useful beside the page without granting it ambient authority.

M10 executes in the order B1 explicit tab/source attachments and scope preview → B3 citation resolution to retained Sources → B2 real step disclosure and infrastructure-level kill switch → B4 typed permission preview cards. It depends on the M0–M6 contracts and does not add ambient all-tabs capture, MCP writes, arbitrary shell/file/desktop actions, or hidden browser automation.

### Exit gate M10

A clean-profile user can attach exact tabs/sources, inspect the bounded scope before submission, receive only citations that resolve to retained provenance (or visible unverified states), observe real research phases, stop a session through native cancellation/revocation with stale output blocked, and approve/deny only typed actions with exact previews and durable EventLedger consent. Sidecar disabled, cancelled, blocked, or unavailable leaves ordinary browsing usable.

## M11 — Studio loop

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m11-studio-loop-plan.md`.

**Goal:** turn browser-native knowledge into one bounded, reviewable code change without granting Swarm unrestricted terminal or filesystem authority.

M11 executes in the order S1 workspace identity/access lifecycle → S2 baseline and untrusted repository instruction manifest → S3 outcome plan/draft/diff/approval binding → S4 bounded executor/verifier and native cancellation → S5 checkpoint/review/rollback/recovery. It depends on M0–M6 and M10, reuses the typed tool/policy/approval seams, and does not add unrestricted shell, network-enabled dependency installation, commits/pushes, credentials, desktop control, or autonomous background coding.

### Exit gate M11

On a clean profile, a user selects a project root, sees the exact workspace identity and dirty baseline, reviews bounded repository guidance as untrusted context, receives an outcome-oriented plan and exact diff, approves a typed action with durable EventLedger consent, sees a bounded check result, and can review or safely roll back without overwriting pre-existing work. Root/access failure, model/toolchain/ledger unavailability, cancellation, or rollback conflict remains truthful and leaves ordinary browsing usable.

## M12 — Command Center

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m12-command-center-plan.md`.

**Goal:** make browser, memory, workspace, and utility actions fast and reliable through one local typed command authority, without creating a noisy launcher or an unrestricted automation surface.

M12 executes in the order C1 typed command authority/migration → C2 explicit local query modes and bounded adapters → C3 action panels/previews/receipts/focus → C4 shortcut registry/conflicts/global-hotkey fallback → C5 validated quick links/inert snippets and clean-profile validation. It depends on M0–M6, M10, and M11, reuses their admission/approval/ledger boundaries, and does not add arbitrary scripts, remote telemetry, secret-bearing snippets, custom-scheme execution, or default global hotkeys.

### Exit gate M12

On a clean profile, `⌘K` opens a fast local Command Center whose visible results all map to typed executors with truthful availability and receipts; explicit modes find commands, tabs, sources, snippets, and links without leaking private context; action panels show valid secondary actions; shortcuts resolve deterministically; and validated quick links/inert snippets remain local, exportable, and deletable. Missing permissions, models, network, indexes, or global hotkeys degrade honestly while ordinary browsing remains usable.

## M13 — Projects & Tasks

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m13-projects-tasks-plan.md`.

**Goal:** turn retained Briefs and sources into explicit, source-linked Projects and Tasks with trustworthy lifecycle, dependencies, dates, inbox views, export, and deletion behavior.

M13 executes in the order P1 shared project/task graph → P2 Brief next-action proposals and explicit promotion → P3 lifecycle/action inbox/project views → P4 timezone-safe due dates and cycle-safe dependencies → P5 provenance/deletion/restore/export and clean-profile validation. It depends on M0–M6 and M10–M12, reuses Honeycomb, EventLedger, memory admission, Sidecar, Studio, and Command Center boundaries, and does not add recurrence, notifications, calendar sync, collaboration, or autonomous task mutation.

### Exit gate M13

On a clean profile, a user opens a retained Brief, reviews a bounded next-action proposal with source provenance, explicitly promotes it into a selected/new Project and Task, manages due date and dependencies, sees deterministic Action Inbox placement, completes the task, exports the project, and can archive/delete/restore it without losing or inventing evidence. Model/store/calendar/notification failures remain truthful and ordinary browsing stays usable.

## M14 — Sheets v1

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m14-sheets-v1-plan.md`.

**Goal:** make Hive Sheets a trustworthy local, source-backed data workspace with typed rows, a documented deterministic formula subset, safe CSV round-trips, reproducible queries, truthful charts, and reviewable agent proposals—not a full spreadsheet clone.

M14 executes in the order A canonical sheet schema/revisions → B deterministic formula engine → C CSV import/export/round-trip → D provenance, queries, and charts → E agent proposals and integrated validation. It depends on M0–M6 and M10–M13, reuses Honeycomb, EventLedger, M11 approval, M12 command, and M13 project boundaries, and explicitly defers macros, arbitrary formulas, external refresh, collaboration, notifications, and autonomous mutation.

### Exit gate M14

On a clean profile, a user creates or imports a bounded sheet, reviews typed schema and warnings, edits values, evaluates supported formulas, traces a row to retained source evidence, saves a reproducible query, exports and re-imports within the documented contract, and can delete/restore the sheet within the promised retention scope. Formula, CSV, chart, model, and source failures remain typed and truthful; browser-first use remains complete with AI and charts unavailable.

## M15 — Browser Credibility C1–C3

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m15-browser-credibility-plan.md`.

**Goal:** close three browser-native credibility gaps: Little Arc-style transient auxiliary windows, lifecycle-aware sleeping/hibernated/discarded/archived tab behavior, and removal of visible no-op commands.

M15 executes in the order C1 typed quick-window identity/lifecycle → C2 hibernation versus renderer discard → C3 crash-safe auto-archive/restore and typed command cleanup → integrated clean-profile validation. It depends on M0–M14, reuses session normalization, HibernationPolicy, AutoArchivePolicy, M11 approval, M12 command authority, and privacy/scope boundaries, and does not add extension parity, arbitrary protocol execution, cross-device archive sync, or autonomous browser actions.

### Exit gate M15

On a clean profile, a user opens a valid link in a transient quick window, closes or explicitly promotes it, returns after a simulated memory-pressure or crash event, sees truthful tab lifecycle state, restores an archived tab without duplication or private-data leakage, and finds no visible command that silently does nothing. AI, model, permission, and renderer failures remain recoverable and ordinary browsing remains usable.

## M16 — Personal Computer Worker & Permission Center

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m16-personal-computer-worker-plan.md`.

**Goal:** establish the signed Worker boundary, typed capability grants, truthful macOS permission disclosure, target-scoped observation, immediate stop/revoke, and auditable recovery before Hive attempts broad personal-computer actions.

M16 executes in the order A signed worker admission/capability manifest → B Permission Center and TCC state disclosure → C narrow target-scoped observation → D typed action ladder/approval binding → E integrated denial, stop, revoke, crash, and browser-first validation. It depends on M0–M15, reuses ResearchWorkerClient hardening, M6 local-agent boundaries, M10/M11 approval, M12 receipts, and EventLedger, and keeps M17 desktop observation/actions separately gated.

### Exit gate M16

On a clean profile, a user can inspect the Worker identity and capabilities, connect only after validation, grant one narrowly scoped capability, observe or perform one bounded approved operation, stop/revoke it, inspect redacted evidence, and continue browsing with all privileged permissions denied. No unsigned worker, freeform script, model-selected permission, unbounded screen capture, or unlogged privileged mutation is accepted.

## M17 — Desktop Observation & Typed Actions

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m17-desktop-observation-actions-plan.md`.

**Goal:** turn M16’s approved capability pipe into a narrow, target-bound observation/action loop with typed payloads, exact approval binding, immediate preflight revalidation, honest verification, and compensation/irreversibility labels.

M17 executes in the order A target identity/observation snapshots → B typed desktop action registry → C preview/approval/preflight revalidation → D bounded dispatch/verification/compensation → E adversarial and degraded validation. It depends on M0–M16, reuses M10/M11 approval, M12 receipts, M16 grants/revocation, EventLedger, and Studio rollback, and explicitly rejects freeform scripts, stale coordinates, universal rollback claims, and sensitive external mutations.

### Exit gate M17

On a clean profile, a user observes one approved target, reviews one typed action, approves it, passes immediate target/focus/permission revalidation, receives verified or explicitly unverified output, and can stop or revoke before completion. Stale elements, target changes, prompt injection, sensitive surfaces, ledger failures, worker crashes, and denied permissions fail closed without unintended external effects; ordinary browsing remains usable.

## M18 — Focus Sessions, Awake Leases & Wellness

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m18-focus-awake-wellness-plan.md`.

**Goal:** provide explicit task-linked Focus Sessions, bounded OS awake leases, battery/thermal/lock-aware yielding, and humane local reminders without surveillance or coercive productivity behavior.

M18 executes in the order A local FocusSession authority/recovery → B bounded awake lease adapter → C battery/thermal/presence policy → D optional humane reminders/wellness controls → E integrated browser-first validation. It depends on M0, M1, M13, M15, M16, and M17, stores only local minimum state, and explicitly defers health data, calendar/meeting connectors, app blocking, forced breaks, and cloud wellness analytics.

### Exit gate M18

On a clean profile, a user explicitly starts a task-linked session, reviews its duration/power/reminder policy, receives a bounded awake lease or an honest unavailable state, pauses/resumes/ends it, sees lease release on expiry/lock/thermal/battery events, and can snooze or disable reminders. No indefinite assertion, notification loop, wellness surveillance, or browser degradation is accepted.

## M19 — Connectors v1

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m19-connectors-v1-plan.md`.

**Goal:** add two read-only reference connectors—macOS Calendar and user-selected local filesystem roots—with explicit account/root identity, least-privilege admission, cursor-based synchronization, Honeycomb provenance, revocation, scoped deletion, and browser-first degraded behavior.

M19 executes in the order A connector/account/root authority → B Calendar read-only connector → C filesystem read-only connector → D sync/normalization/deletion → E integrated browser-first validation. It depends on M0, M1, M4, M6, M13, M15, M16, M17, and M18. Connector content remains untrusted context: it cannot widen permissions, issue tools, silently create tasks, or mutate external systems. OAuth cloud connectors, write-back, email, broad home-directory indexing, and a connector marketplace remain deferred.

### Exit gate M19

On a clean profile, a user explicitly grants a selected Calendar scope and filesystem root, sees honest authorization and stale/offline states, performs an idempotent incremental sync with bounded retry/backoff, inspects source/version provenance, revokes or disconnects either connector, and chooses the exact deletion scope. No content-driven admission, scope expansion, silent promotion, secret leakage, orphaned data, or browser degradation is accepted.

## M20 — Sheets UI

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m20-sheets-ui-plan.md`.

**Goal:** turn the M14 Sheets contract into a browser-native, revision-aware user surface: accessible grid editing, deterministic formula presentation, safe CSV flows, saved query/view projections, source provenance inspection, bounded charts with complete table fallbacks, and reviewable agent proposals.

M20 executes in the order A canonical grid projection/navigator → B typed editing/schema warnings/safe CSV → C views/formulas/provenance inspection → D query-backed charts/accessibility → E reviewable agent proposals/integrated validation. It depends on M0, M4, M10, M11, M12, M13, M14, and M19. The UI never becomes a second persistence authority: filters/sorts use stable IDs, charts reference saved queries and input revisions, and model output remains an inert approved patch. Macros, arbitrary formulas, external refresh, collaboration, workbook compatibility, and autonomous mutation remain deferred.

### Exit gate M20

On a clean profile, a user opens a small Honeycomb-backed sheet, navigates and edits it by keyboard, sees typed formula errors and source lineage, imports/exports CSV with explicit warnings/manifests, saves a reproducible view, renders a query-backed chart with a complete accessible table fallback, and reviews an agent proposal before any mutation. AI, charts, connectors, or Honeycomb degradation must not break ordinary browsing or leave a false-success state.

## M21 — Wellness Rhythms

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m21-wellness-rhythms-plan.md`.

**Goal:** add optional local wellness rhythms and gentle break suggestions around explicit Focus Sessions, with truthful notification handling, explicit presenting/meeting/dictation pause controls, and no surveillance or coercive productivity behavior.

M21 executes in the order A local rhythm profile/lifecycle → B explicit smart-pause controls → C reliable M18/session/notification suppression → D separately evaluated optional signal paths → E humane/browser-first validation. It depends on M0, M1, M5, M12, M13, M16, and M18. M18 remains authoritative for sessions, awake leases, power, thermal, lock, and sleep behavior; M21 never creates an implicit session, owns a lease, toggles system Focus, or infers another app’s meeting/dictation state. Health telemetry, screen/audio surveillance, forced breaks, app blocking, and remote wellness analytics remain deferred.

### Exit gate M21

On a clean profile, a user explicitly enables a local rhythm, starts an eligible M18 session, receives at most a gentle reminder through an authorized channel, declares presenting/meeting/dictation or snoozes/pauses/disables it, and sees reliable lock/sleep/power/notification suppression. Unknown context suppresses rather than interrupts, no wellness data leaves the device, and ordinary browsing is unchanged when M21 is disabled or unavailable.

## M22 — Menu-Bar Modes & Presets

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m22-menu-bar-presets-plan.md`.

**Goal:** add an optional macOS menu-bar companion and local contextual presets as a bounded projection over Hive’s existing Command Center, worker/permission, workspace, profile, Focus Session, and wellness authorities.

M22 executes in the order A typed preset/command projection → B optional status-item lifecycle → C preset editor/context evaluation → D login launch/permission/cleanup boundary → E integrated browser-first/accessibility validation. It depends on M0, M1, M12, M13, M16, M18, M21, and signing/distribution decisions. The menu bar never becomes a second command authority, privileged actions never bypass M16, presets never contain executable code/secrets/raw surveillance context, and login helpers remain separately consented and justified. Default browser mode remains unchanged with M22 disabled.

### Exit gate M22

On a clean profile, no menu-bar item or login prompt appears by default; after explicit opt-in, one status item projects typed M12 commands and approved local context, handles sleep/wake/display/session/relaunch changes without duplication, shows honest unavailable/permission states, respects M18/M21 suppression, and can be disabled/unregistered without browser degradation or silent re-enable.

## M23 — Mail + Calendar Modules

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m23-mail-calendar-modules-plan.md`.

**Goal:** add a local-first mail index and Calendar product module over explicit least-privilege read-only sources, with accessible triage, source provenance, offline truthfulness, and advisory task/draft proposals that cannot send or mutate without a later approval contract.

M23 executes in the order A account/schema/sync authority → B read-only local mail index → C M19-backed Calendar product module/NL proposals → D advisory triage/task proposals/future draft boundary → E integrated privacy/revocation/accessibility/browser-first validation. It depends on M0, M1, M4, M5, M6, M10, M11, M12, M13, M19, and M21. M19 remains connector plumbing and Calendar read-only authority; M23 adds product views/indexes without duplicating credentials or provenance. UIDVALIDITY, MIME bounds, Keychain-only credentials, prompt-injection fencing, no-send/no-mutation defaults, and scoped deletion are mandatory. Full write-back, send/reply, calendar mutation, broad OAuth, and autonomous communication remain deferred.

### Exit gate M23

On a clean profile, a user explicitly scopes a mail account/mailboxes and selected calendars, searches a local stale-labeled index, views accessible threads/events with source provenance, receives typed advisory triage/NL proposals, and sees no live send/mutation affordance unless separately approved. UIDVALIDITY/reset, MIME, revocation, deletion, offline, prompt-injection, and browser-first fixtures pass without cross-account leakage or false-success communication.

## M24 — Media + Audio Modules

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m24-media-audio-modules-plan.md`.

**Goal:** add a local-first media browser for user-selected roots, provenance-preserving transcript/subtitle ingestion, optional user-requested on-device transcription, timestamp-addressable search, accessible playback, and browser-first degraded behavior.

M24 executes in the order A media root/asset identity/bounded index → B playback/accessibility → C transcript/subtitle ingestion/provenance → D optional on-device transcription and M4 hybrid retrieval → E privacy/retention/accessibility/browser-first validation. It depends on M0, M1, M4, M6, M12, M13, and M19. M19 remains the selected-root/security-scoped access authority; M24 adds media identity and product views without duplicating file permissions or provenance. Media and transcript content remain untrusted data. No recording, passive listening, automatic podcast downloading, DRM circumvention, hidden network fallback, or autonomous promotion is included.

### Exit gate M24

On a clean profile, a user explicitly selects a local media file/root, sees bounded metadata and an honest playable/unavailable state, imports or generates a clearly labeled transcript, searches exact or semantic text with source/version/segment/time provenance, seeks to a result, and can forget the media scope with a resumable derived-data cascade. Unsupported codecs/locales/models, thermal/battery/lock pauses, malformed cues, deletion, prompt injection, accessibility, and browser-first fixtures pass without copying raw media into logs or silently sending it remotely.

## M25 — Engine Sovereignty Decision

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m25-engine-sovereignty-plan.md`.

**Goal:** reconcile the actual CEF/Chromium renderer baseline, establish an engine-neutral browser boundary, and make a reversible engine decision from measured compatibility, retention, extension demand, performance, security/update, distribution, and maintenance evidence.

M25 is not a greenfield CEF-versus-WKWebView choice: the current `Hive` target already embeds vendored CEF 148/Chromium 148, while `HiveWebKitSmoke` is an opt-in developer smoke target. M25 records that truth, measures the current baseline, evaluates only demand-justified candidates, keeps Ladybird-class engines research-only until maturity gates pass, and forbids unsupported Chrome-extension or Chrome Web Store claims. No engine switch, re-vendor, extension loader, or product rewrite is implied by this plan.

### Exit gate M25

The repository and runtime evidence agree on the current renderer; an engine-neutral capability/state boundary is documented; the frozen real-browser corpus has CEF baseline measurements; any candidate has typed compatibility, RSS/thermal/crash, signing/notarization/update, security-SLA, demand, and rollback evidence; extension reality is explicit; and a dated go/hold/exit decision leaves the current browser usable with the candidate disabled.

## M26 — Enterprise Memory Layer

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m26-enterprise-memory-layer-plan.md`.

**Goal:** define one tenant/workspace-aware object and policy model over Hive’s local-first memory, connectors, actions, sync, and audit authorities without turning planning language into a SOC 2, legal-hold, eDiscovery, or remote-deletion guarantee.

M26 executes in the order A tenant identity/policy admission → B canonical ownership and source portability → C tamper-evident audit/export verification → D retention, deletion, encryption, sync, and recovery → E enterprise surfaces and browser-first validation. It depends on M0–M6, M10–M25, M19, and M23, reuses existing Honeycomb/EventLedger/ContextScope/MemoryAdmission/Keychain/SyncCipher authorities, and does not create a second memory or permission authority. Tenant identity is never inferred from an Apple ID, email domain, CloudKit container, hostname, or network. Enterprise memory remains separate from personal memory; connector content remains untrusted; remote model access is policy-gated; offline state is explicit; M27 collaboration/shared graph/CRDT semantics remain deferred.

### Exit gate M26

Tenant/profile/workspace isolation is enforced before retrieval, serialization, model context, cache insertion, connector sync, export, and action dispatch; the canonical object envelope and derived-artifact deletion dependencies are mapped; audit exports are deterministic, cancellable, omission-aware, and independently verifiable or honestly marked unanchored/partial; retention and deletion-by-scope distinguish requested, blocked, queued, applied, awaiting-sync, failed, and verified; encryption/key custody claims match the M6 measured ADR; managed, unmanaged, offline, revoked, locked, and accessibility paths pass; and clean-profile browsing remains complete with enterprise services disabled. Hive claims evidence support, not SOC 2 certification, legal advice, eDiscovery, or guaranteed remote erasure.

## M27 — Collaboration & Encrypted Sync

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m27-collaboration-encrypted-sync-plan.md`.

**Goal:** add explicit shared workspaces and multi-device/team synchronization without misrepresenting Hive’s current single-user CloudKit sync as collaboration.

M27 executes in the order A shared workspace/membership authority → B device keys, epoch rotation, and encrypted operation envelopes → C deterministic operation log/materializers/conflict forks → D CloudKit shared transport and recovery → E shared graph/product surfaces and deletion. It depends on M26 tenant/policy/ownership/audit/deletion semantics and M6 encryption evidence, reuses existing private-database sync only for personal work, and keeps personal/private data, connectors, credentials, raw page bodies, and model context outside shared scope by default. M27 chooses an encrypted append-only operation log first; it does not add generic CRDT or real-time editor semantics, presence, anonymous links, or administrator decryption backdoors.

### Exit gate M27

Shared workspace/member/device identities are distinct from M26 tenant and local profile IDs; invitations, roles, device registration, epoch keys, revocation, and late-device quarantine are signed, replay-safe, policy-admitted, and audited; operation envelopes and materialized revisions are deterministic and rebuildable; safe metadata convergence is distinguished from visible conflict forks; CloudKit private/shared transport boundaries, change-token recovery, outbox acknowledgements, deletion, export, and backup status are honest; and offline, locked, revoked, conflicted, quarantined, and resync-required states remain accessible while clean-profile browsing and personal memory work with collaboration disabled. Current single-user sync is not marketed as team collaboration.

## M28 — Trustworthy Automation & Flow Runtime

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m28-flow-runtime-trustworthy-automation-plan.md`.

**Goal:** make reusable automation durable, typed, reviewable, and browser-first without turning Hive into an autonomous “do anything” agent.

M28 executes in the order A versioned Flow definition/publication → B durable run history/replay/recovery → C typed activity registry and bounded execution → D exact approval waits, manual/event triggers, and best-effort scheduling → E compensation/secrets/observability/integrated validation. It depends on M0–M27, reuses M10/M11/M12/M16/M17/M19/M23/M26/M27 authorities, and does not add dynamic model-authored graphs, unrestricted shell/desktop/browser scripting, autonomous external mutation, exactly-once side effects, universal rollback, or guaranteed execution during sleep/process absence.

### Exit gate M28

Published Flow revisions are immutable and scope/type/policy validated; model/page/connector/shared content cannot publish or alter executable definitions; run history is append-only, replayable, crash-recoverable, and secret-free; activities are typed, bounded, policy/approval/checkpoint admitted, verifiable, and honest about at-least-once/unknown effects; approval waits are exact and expiring; scheduling reconciles missed fires without inventing execution; stop/revoke, compensation, deletion/export, accessibility, private/offline/locked states, and browser-first degraded behavior pass the 50-fixture contract. A queue, timer, JSON prompt, closure callback, green mock, or retry loop alone is not trustworthy automation.

## M29 — Personalization, Memory Governance & Adaptive Context

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m29-personalization-memory-governance-plan.md`.

**Goal:** improve retrieval, presentation, and context budgeting through explicit preferences and narrowly bounded local signals without turning Hive into a hidden profile, surveillance system, or source of model authority.

M29 executes in the order A governance objects and preference authority → B admission, scope intersection, and signal lifecycle → C deterministic adaptive ranking and context packets → D model routing, privacy controls, and transparency → E evaluation, poisoning resistance, and integrated deletion. It depends on M0–M28, reuses Honeycomb/M0–M6 lifecycle, M10 context scope, M26 policy, M27 shared-scope, and M28 Flow authorities, and keeps durable memory, explicit preferences, and inferred local signals as separate stores with separate purpose, consent, retention, and deletion semantics. It does not add covert cross-application surveillance, sensitive-trait inference, remote profile embeddings, personal-data fine-tuning, personalized permissions, silent context widening, automatic durable promotion, or universal deletion claims.

### Exit gate M29

Durable memory, explicit preferences, inferred local signals, and context packets are typed, purpose-bound, scoped, inspectable, reversible, deletion-generation aware, and untrusted to model authority; ranking occurs only after M0–M6/M10/M26/M27 admission; private, sensitive, deleted, candidate, cross-tenant, and prompt-injected content is excluded; context budgets and provenance are visible; remote personalization is explicitly disclosed and consented; 50 deterministic fixtures, accessibility, cold-start, offline/locked/private, poisoning, deletion, and browser-first degraded paths pass. A preference JSON, ranking score, memory vector, proactive suggestion, or larger context window alone is not governed personalization.

## M30 — Personal Work Loop & Proactive Agenda

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m30-personal-work-loop-proactive-agenda-plan.md`.

**Goal:** coordinate explicit projects, tasks, objectives, governed context, and bounded reminders into a useful daily work loop without creating a second task store, scheduler, notification authority, or always-on agent.

M30 executes in the order A objective projection and task readiness → B deterministic AgendaManifest synthesis → C explicit proactive proposals and native acceptance → D notification consent/reconciliation → E frozen-manifest model boundary, fatigue evaluation, accessibility, and browser-first validation. It depends on M0–M29 and reuses M13 task truth, M18/M21 suppression, M22 projection, M23 read-only sources, M28 trigger/run authority, M29 context governance, M26/M27 scope, Honeycomb provenance, and EventLedger. It does not add hidden goal inference, passive surveillance, autonomous task mutation, notification coercion, guaranteed delivery/execution, or engagement optimization.

### Exit gate M30

Objectives are explicit and typed; task readiness and agenda sections are deterministic, bounded, provenance-linked, timezone-aware, and honest about stale/unknown/missed states; proposals are expiring, coalesced, dismissible, and routed through native authority; notification categories require explicit consent and distinguish scheduled/delivered/presented/acted; sleep/restart/offline/lock/quiet-hour states reconcile without invented execution or notification bursts; M29 admission and deletion generations hold; 50 deterministic fixtures plus accessibility and clean-profile browser-first paths pass. A task list, notification request, timer, model suggestion, or polished agenda UI alone is not a verified personal work loop.

## M31 — User-Controlled Extensibility & Data Portability

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m31-extensibility-data-portability-plan.md`.

**Goal:** give users an open, inspectable way to export and restore eligible Hive work and install declarative commands, presets, read-only MCP descriptions, and Flow templates without creating arbitrary plugin authority.

M31 executes in the order A deterministic export envelope/report → B import quarantine/migration/conflict review → C inert declarative manifests → D capability review/revocation/pinned-local distribution → E deletion, accessibility, security, and browser-first validation. It depends on M0–M30 and reuses M6 read-only grants, M12 commands, M22 presets, M25 renderer truth, M26/M27 scope, M28 Flow authority, M29 deletion/context, M30 proposal governance, Keychain, Honeycomb, and EventLedger. It does not add arbitrary code, remote marketplace updates, Chrome Web Store parity, secret export, silent import, signature-as-permission, or universal portability/deletion claims.

### Exit gate M31

Exports are deterministic, scoped, versioned, secret-free, omission-aware, and independently verifiable; imports remain quarantined until explicit review/apply with visible conflicts and no live writes or Keychain restoration; only typed command/preset/MCP-read/Flow-template manifests project into existing native registries; capabilities are visible, narrow, revocable, and revalidated at invocation; renderer extension availability is honestly exposed; deletion generations invalidate exports/imports/projections/templates/context/proposals; 50 deterministic fixtures plus accessibility, security, large-archive, private/locked/offline/revoked, and clean-profile browser-first paths pass. A JSON parser, export file, manifest signature, settings panel, or extension UI alone is not verified portability or extensibility.

## M32 — Ship-Ready Reliability, Distribution & Trust

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m32-ship-ready-reliability-distribution-trust-plan.md`.

**Goal:** turn the existing release scripts and local validation into an evidence-backed ship/hold/blocked decision without claiming that an ad-hoc artifact is distributable.

M32 executes in the order A evidence reconciliation/release receipt → B artifact, dependency, signing, and privacy inventory → C authenticated update, crash, renderer recovery, and disaster rehearsal → D clean-profile browser, performance, accessibility, and privacy evidence → E dated ship/hold/blocked handoff. It depends on M0–M31 and reuses M15 browser credibility, M25 engine truth, M27/M31 portability and recovery boundaries, existing CrashReporter/UpdateManager/release scripts, Apple signing/notarization, Sparkle security, and local evidence documents. It does not obtain credentials, add telemetry, replace the renderer, add Chrome Web Store parity, certify legal/privacy compliance, or call a local ad-hoc bundle distributable.

### Exit gate M32

The exact artifact/build/commit has a release receipt with fresh evidence status; nested components, hashes, entitlements, dependencies, notices, privacy/API review, and secrets are accounted for; Developer ID/notarization/Gatekeeper and Sparkle update states are verified or explicitly blocked; crash and renderer recovery are redacted, opt-in, and truthful; clean-profile browser, private mode, P0 journeys, performance, accessibility, offline, and Swarm-off behavior are evidenced or marked unavailable; update rollback preserves canonical state or discloses loss; and a dated ship/hold/blocked decision names owners, blockers, and risks. Scripts, CI YAML, historical counts, screenshots, or an ad-hoc launch alone are not ship evidence.

## M33 — Operations, Vulnerability Response & Trust Feedback

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m33-operations-vulnerability-response-trust-feedback-plan.md`.

**Goal:** define how Hive remains trustworthy after release through typed intake, coordinated vulnerability handling, redacted support evidence, privacy/accessibility feedback, and minimal local operational learning.

M33 executes in the order A trust intake/consent/case projection → B vulnerability disclosure/incident severity/communication → C redacted support packets/privacy-request receipts → D accessibility regression/operational learning → E post-incident review, M32 release binding, and browser-first validation. It depends on M0–M32 and reuses EventLedger, CrashReporter, UpdateManager, M25 engine/update ownership, M26/M27/M29 scope/lifecycle, M31 portability, and M32 release receipts. It does not add a second ticket, ledger, privacy, telemetry, or security-execution authority; it does not claim legal compliance, guaranteed SLAs, automatic remediation, passive surveillance, or remote browsing analytics.

### Exit gate M33

Trust cases have typed kind, scope, consent, lifecycle, owner, bounded evidence, deletion state, and next action; vulnerability reports have a disclosure/triage/coordination path with unknown severity handled safely; fixed claims bind to an exact M32 release receipt; support packets are previewed, redacted, optional, cancellable, and deletion-aware; privacy requests distinguish local applied state from external-copy limits; accessibility regressions preserve manual/unavailable truth; operational aggregates exclude page/query/form/private-memory/prompt/token/cross-app fields; category consent is separate; and offline, denied, private, locked, revoked, and M33-disabled browser paths remain usable. A contact form, crash parser, policy document, EventLedger row, or local aggregate alone is not verified post-release operations.

## M34 — User Trust & Control Plane

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m34-user-trust-control-plane-plan.md`.

**Goal:** make permissions, consent, data lifecycle, provenance, identity/device state, release channels, and evidence limitations inspectable in one user-facing control surface without creating a second authority.

M34 executes in the order A TrustSnapshot/authority map → B capability, consent, and lifecycle disclosure → C identity/device/channel reconciliation → D typed revoke/reset/export actions → E evidence center, accessibility, and browser-first validation. It depends on M0–M33 and reuses M16 Permission Center/TCC truth, EventLedger, Honeycomb/lifecycle, M26/M27 ownership and device state, Keychain/connectors, M31 portability, M32 release receipts, M33 trust cases, and browser permission policies. It does not add a second permission, consent, identity, device, sync, lifecycle, telemetry, ticket, or policy authority; it does not claim universal TCC introspection, account recovery, legal compliance, universal deletion, automatic granting, silent beta enrollment, or a trust score.

### Exit gate M34

A deterministic TrustSnapshot projects existing authority state with owner, scope, freshness, evidence, status, and limitation; browser/site permissions remain distinct from macOS TCC and Worker grants; local/derived/sync/export/pending/deleted/external-copy lifecycle states are distinct; account/device/epoch/channel transitions cannot merge identities or revive revoked authority; revoke/reset/forget/cancel/export actions use typed preview, revalidation, approval, and receipts; Keychain values and private content never leak; pages/imports/models cannot alter trust state; accessibility/manual/unavailable states remain explicit; and offline, private, locked, denied, revoked, no-iCloud, Swarm-disabled, and Trust-Center-disabled browser paths remain usable. A polished dashboard, permission label, receipt link, or green score alone is not verified user trust.

## M35 — Evidence & Policy Lifecycle Governance

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m35-evidence-policy-lifecycle-governance-plan.md`.

**Goal:** govern versioning, expiry, migration, consent continuity, identity/key rotation, quarantine, and tombstoning for evidence and policy references after M34 makes them visible.

M35 executes in the order A compatibility registry/migration envelope → B evidence review/expiry/tombstones → C policy-generation and consent/grant continuity → D identity/key/device rotation and quarantine → E invalidated artifact cleanup and browser-first recovery. It depends on M0–M34 and reuses EventLedger, M16 grants/TCC, M26/M27/M29/M30/M28 policy and scope owners, M31 portability, M32 release receipts, M33 operations, M34 TrustSnapshot, Keychain, CloudKit, and browser lifecycle authorities. It does not add a second policy, consent, identity, device, lifecycle, telemetry, garbage-collection, or compliance authority; it does not claim cryptographic attestation, automatic key recovery, universal deletion, legal retention, remote compliance, or opaque renderer/provider migration.

### Exit gate M35

Versioned envelopes produce deterministic current, additive, needs-migration, unsupported, downgraded, stale, quarantined, or tombstoned states; stale evidence cannot authorize current actions; policy scope/egress/retention/target/privilege changes require correct reapproval; historical consent is separate from active grant and native permission; key/device/account/epoch rotation cannot revive stale authority; invalidated archives, contexts, and proposals cannot apply as current authority; cleanup is owner-approved, bounded, idempotent, and non-heuristic; accessibility/manual/unavailable states remain visible; and navigation, tabs, private mode, and local inspection remain usable with M35 disabled. A migration script, tombstone row, schema version, or clean decode alone is not verified lifecycle governance.

## M36 — Reproducible Evidence & Recovery Rehearsal

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m36-reproducible-evidence-recovery-rehearsal-plan.md`.

**Goal:** make M32–M35 evidence replayable and recovery claims rehearseable from frozen synthetic inputs, exact identities, and explicit loss/limitation receipts.

M36 executes in the order A replay manifest/deterministic comparator → B disposable migration/restore rehearsal → C artifact/dependency/policy provenance binding → D recovery receipts and M33/M34 handoff → E accessibility, cadence, and browser-first validation. It depends on M0–M35 and reuses M25 engine state, M31 portability, M32 release receipts, M33 operations, M34 TrustSnapshot, M35 lifecycle, EventLedger, Honeycomb, UpdateManager, and browser/session authorities. It does not add a second evidence store, backup service, telemetry pipeline, attestation infrastructure, automatic repair/rollback, production-profile rehearsal, legal/compliance certification, or opaque renderer/provider migration.

### Exit gate M36

Frozen replay manifests produce deterministic evidence/snapshot/lifecycle outputs with declared nondeterminism and typed mismatch classes; disposable migration/restore/update/renderer/sync/account/deletion rehearsals produce exact phase and recovery receipts; artifact/dependency/policy identity binds to immutable references and exact M32 evidence where required without attestation overclaim; canonical, derived, private, opaque, evidence, partial, blocked, unavailable, and unknown recovery states are distinct; failed rehearsals hand off bounded M33 references and M34 limitations without automatic remediation; accessibility/manual/unavailable states remain visible; and navigation, tabs, private mode, and local memory remain usable with M36 disabled. A green replay, hash, manifest, successful launch, or historical CI run alone is not production recovery or ship evidence.

## M37 — User-Visible Change, Deprecation & Support Horizon

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m37-user-visible-change-deprecation-support-horizon-plan.md`.

**Goal:** communicate product, policy, schema, capability, engine, connector, model, recovery, and support changes with exact provenance, generation-bound review, honest compatibility/deprecation states, and browser-first fallback.

M37 executes in the order A change-notice envelope/provenance → B acknowledgement and re-review continuity → C compatibility/deprecation/support horizon → D update/recovery limitation communication → E accessibility and browser-first validation. It depends on M0–M36 and reuses M25 engine/update ownership, M31 portability, M32 release receipts, M33 operations, M34 TrustSnapshot, M35 lifecycle, M36 recovery receipts, EventLedger, and browser/session authorities. It does not add a second release feed, policy engine, consent authority, support database, telemetry pipeline, forced update, automatic migration, legal/compliance certification, or runtime implementation.

### Exit gate M37

Every actionable notice maps to one existing authority or is visibly unverified; artifact/policy/schema/incident/recovery provenance is exact or explicitly unavailable; review state is bound to notice revision, scope, and generation and never substitutes for consent; changed scope/generation/action/limitation invalidates old review; blocking/migration/integrity/security notices cannot be permanently dismissed; compatibility and support states distinguish supported, limited, review-required, migration-required, deprecated, unsupported, blocked, unknown, and not-tested; update/recovery/renderer/provider/offline states never imply success; accessibility/manual/unavailable states remain visible; and navigation, tabs, private mode, and local inspection remain usable with M37 disabled. A notice, acknowledgement, support horizon, release note, or clean presentation is not a capability grant, SLA, security certification, recovery proof, or ship claim.

## M38 — Offline Evidence Traceability & Audit Package

**Detailed execution plan:** `docs/superpowers/plans/2026-08-11-m38-offline-evidence-traceability-audit-package-plan.md`.

**Goal:** export and inspect a deterministic, redacted, offline trace of M32–M37 evidence without creating a second authority or implying certification.

M38 executes in the order A offline package envelope/owner projection → B deterministic redaction/privacy boundary → C integrity/provenance/traceability validation → D accessible local inspection/plain fallback → E chain review/operational handoff/browser-first validation. It depends on M0–M37 and reuses M31 portability, M32 release receipts, M33 operations, M34 TrustSnapshot, M35 lifecycle/tombstones, M36 recovery receipts, M37 notices/reviews, EventLedger, and browser/session authorities. It does not add a second ledger, evidence store, provenance authority, compliance system, remote upload, telemetry, automatic repair, signing-key workflow, or runtime implementation.

### Exit gate M38

Every package projection maps to one existing owner; default-deny redaction excludes secrets, private content, raw memory, prompts, and arbitrary paths; canonical serialization, bounded scope, schema/version checks, hashes, supplied-signature verification, and chain findings are deterministic; integrity is distinguished from trust, attestation, notarization, and compliance; missing, stale, revoked, quarantined, tombstoned, synthetic, redacted, partial, broken, and unavailable states remain explicit; the static/local viewer is inert and network-free with a plain JSON/text fallback; findings route to review rather than automatic repair; accessibility/manual/unavailable evidence stays visible; and navigation, tabs, private mode, and local inspection remain usable with M38 disabled. A valid package is not a capability grant, release proof, security certification, compliance result, recovery guarantee, or ship claim.

## M39 — Evidence Package Lifecycle & Human Disposition

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m39-evidence-package-lifecycle-human-disposition-plan.md`.

**Goal:** govern package expiry, revocation, retention, quarantine, reopening, deletion limits, and explicit human disposition without turning an offline evidence package into a second authority.

M39 executes in the order A package lifecycle/authoritative state evaluation → B retention/deletion/external-copy limits → C quarantine-first reopen/import review → D human disposition/review invalidation → E viewer trust/fallback/browser-first validation. It depends on M0–M38 and reuses M31 portability, M33 deletion/retention receipts, M35 lifecycle/tombstones, M38 package/validator state, M34 TrustSnapshot, M37 notices/reviews, EventLedger, Keychain/file-access boundaries, and browser/session authorities. It does not add a second package database, evidence ledger, revocation service, retention scheduler, trust root, remote upload, telemetry, automatic deletion/remediation, or runtime implementation.

### Exit gate M39

Current, limited, stale, expired, revoked, superseded, quarantined, deleted-local, unavailable, synthetic-only, and unknown package states map to owner evidence or explicit local limits; local clocks, filenames, body text, viewers, models, or hashes cannot invent authority; retention, deletion, backup, external-copy, key, and unknown scopes are distinct; package import is bounded and quarantine-first with no path escape, executable content, network, tool, policy, evidence, or canonical-memory mutation; package hash/scope/lifecycle/generation/validator/redaction changes invalidate old review; dispositions state exact local effects and never become consent, release approval, incident closure, or trust; inert viewer/plain JSON fallback remains available; accessibility/manual/unavailable states stay visible; and browsing remains usable with M39 disabled. M39 does not certify secure deletion, legal retention, cryptographic revocation, accessibility, production readiness, or shipping.

## M40 — Consent-Bound Evidence Exchange & Recipient Review

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m40-consent-bound-evidence-exchange-recipient-review-plan.md`.

**Goal:** define explicit, transport-neutral sharing of a redacted evidence package with one stated recipient, including scope binding, schema negotiation, offline receipts, recipient isolation, and honest copy/deletion limits.

M40 executes in the order A share consent/recipient binding → B schema/validator/capability negotiation → C transport-neutral handoff/offline receipts → D revocation/deletion/copy limitations → E isolated recipient review/browser-first validation. It depends on M0–M39 and reuses M31 portability, M33 operational/deletion receipts, M34 TrustSnapshot, M35 lifecycle/tombstones, M38 package/validator state, M39 review/disposition, EventLedger, Keychain/file-access boundaries, and browser/session authorities. It does not add a remote share service, federation, collaboration workspace, tenant/membership authority, second exchange ledger, universal revocation, automatic sharing/remediation, or runtime implementation.

### Exit gate M40

Sharing requires explicit approval for one package, scope, purpose, recipient reference, lifecycle state, validator, and redaction profile; verified, stated-unverified, missing, and ambiguous recipients remain distinct; metadata-only negotiation rejects unsupported or unsafe downgrades; transport is user-selected and transport/storage limits are visible; receipts are bounded statements that cannot establish identity, truth, deletion, or future consent; pre-handoff revocation blocks delivery while post-handoff revocation cannot erase unmanaged copies; recipient import/review is quarantine-first and cannot mutate canonical stores, policy, consent, release, or permissions by default; accessibility/offline/locked/denied/private/plain-fallback states remain visible; and browsing remains usable with M40 disabled. M40 is not secure delivery, verified identity, universal revocation, collaboration, certification, incident closure, or ship evidence.

## M41 — Evidence Challenge, Correction & Exchange Closure

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m41-evidence-challenge-correction-exchange-closure-plan.md`.

**Goal:** define append-only, owner-scoped challenge, correction-lineage, response/re-review, exchange-closure, and user-visible sharing-history semantics over M33 and M38–M40 without creating a second ledger, dispute service, automatic mutation path, or truth/certification claim.

M41 executes in the order A challenge intake/bounded feedback → B correction lineage/owner response → C stale propagation/re-review continuity → D exchange closure/sharing history → E conflict/accessibility/privacy/browser-first validation. It depends on M0–M40 and reuses M33 operations/trust feedback, M35 lifecycle/tombstones, M37 notice/re-review, M38 package validation, M39 lifecycle/disposition, M40 consent/receipts, EventLedger, Honeycomb/source owners, Keychain/file-access boundaries, and browser/session authorities. It does not add a second dispute/feedback/exchange ledger, automatic correction/deletion, model adjudication, universal propagation, remote transport, legal process, or runtime implementation.

### Exit gate M41

Challenges are exact-scope, explicitly user-submitted, inert, and unable to mutate authority; proposed, owner-confirmed, rejected, conflicting, unavailable, superseded, tombstoned, and deleted correction states remain distinct; original states remain traceable while corrections append owner references; owner-backed responses and closures require issuer/event/revision bindings verified against the existing authority, and an owner_ref alone is not authorization; hash/generation/lifecycle/scope/consent/validator/redaction/lineage changes force stale or re-review-required states; responses distinguish owner-backed, participant-stated, local, unavailable, conflicting, and unknown; closure is explicit workflow disposition rather than truth, trust, incident closure, consent, legal finality, or capability grant; sharing history is a projection over existing authorities rather than a second ledger; direct response/closure references and verified binding state are required before owner-backed history is displayed; replay/conflict/accessibility/privacy/offline/private/locked/denied states remain visible; and browsing remains usable with M41 disabled. M41 is not dispute adjudication, universal correction propagation, secure deletion, certification, or ship evidence.

## M42 — Post-Closure Re-Export Reconciliation & Sharing History Lifecycle

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m42-post-closure-reexport-history-lifecycle-plan.md`.

**Goal:** define how verified M41 corrections and closures can inform a new explicitly approved M31 export, and how local sharing-history metadata expires, tombstones, compacts, conflicts, or deletes without changing canonical sources or unmanaged copies.

M42 executes in the order A re-export binding/fresh consent → B history lifecycle/tombstones → C multi-recipient conflict projection → D copy/deletion/archival limits → E inert archive/accessibility/browser-first validation. It depends on M0–M41 and reuses M31 portability, M33 operations/deletion receipts, M35 lifecycle/tombstones, M37 re-review, M38 package validation, M39 disposition, M40 exchange/receipts, M41 verified correction/closure/history, EventLedger, Honeycomb/source owners, Keychain/file-access boundaries, and browser/session authorities. It does not add automatic re-export, remote notification, automatic correction propagation, a second ledger/history authority, consensus, universal deletion, legal retention, or runtime implementation.

### Exit gate M42

Every new export has a new identity, exact predecessor binding, verified owner correction/response/closure references where applicable, a visible diff, and fresh user consent; prior M40 consent cannot authorize a new export; proposed, stale, conflicting, unavailable, revoked, expired, superseded, privacy-redacted, quarantined, tombstoned, and deleted-local history states remain distinct; multi-recipient disagreement is projected locally without voting or majority truth; tombstones preserve required lineage without claiming physical erasure; compaction preserves conflicts, deletion receipts, stale/review limits, and next actions; archive content is inert and network/script/tool-free with a plain fallback; and browsing remains usable with M42 disabled. M42 is not automatic correction propagation, recipient recall, consensus, secure deletion, certification, or ship evidence.

## M43 — Evidence Lineage Discovery & Notification Continuity

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m43-evidence-lineage-discovery-notification-continuity-plan.md`.

**Goal:** define local affected-lineage discovery and inert continuity notices for corrected, superseded, revoked, expired, redacted, or otherwise changed evidence, with local acknowledgement/re-review semantics and honest transport/delivery limits.

M43 executes in the order A local lineage discovery/affected-reference mapping → B continuity notice/required-action semantics → C acknowledgement/re-review continuity → D delivery limits/transport fallback → E retention/compaction/privacy/adversarial validation. It depends on M0–M42 and reuses M31 portability, M35 lifecycle, M37 notice/re-review, M38 package traceability, M39 disposition, M40 exchange/receipts, M41 verified correction/closure/history, M42 re-export/tombstones/conflicts, M33 operations, EventLedger, Honeycomb/source owners, Apple notification/file boundaries, and browser/session authorities. `ContinuityNotice` remains an M37-owned projection, not a parallel notice authority; unverified triggers are informational-only and cannot create blocking/review/re-export actions; delivery receipts bind exact notice revision, affected scope, owner generation, and idempotency/replay state. It does not add a second notice/recipient/delivery ledger, contact lookup, remote notification service, automatic propagation/re-export, delivery/read guarantee, hidden telemetry, or runtime implementation.

### Exit gate M43

Affected-lineage discovery resolves only exact retained local references and never claims a complete recipient set; `recipient_unknown`, `unmanaged_copy_unknown`, `no_retained_match`, stale, conflicted, and unavailable states remain distinct; notices are M37-owned projections mapped to existing verified owner/M41/M42 triggers, while unverified triggers are informational-only and cannot create blocking/review/re-export actions; notices cannot choose transports, widen scope, invoke tools, or mark themselves read; local acknowledgement is not delivery, reading, consent, correction adoption, or completed re-review; notice/scope/package/generation/action/limitation changes stale old review; delivery receipts bind exact notice revision, affected scope, owner generation, and idempotency/replay state; local notification and user-selected export/share remain separate consent categories; queued/presented/handoff states never prove recipient delivery; no contact lookup, recipient registry, raw package, secret, or engagement telemetry is introduced; compaction preserves lineage/tombstones/review limits and cannot create “no impact” from missing data; status/error/confirmation/offline/private/locked/denied/manual states remain understandable; and browsing remains usable with M43 disabled. M43 is not recipient notification, delivery guarantee, read receipt, universal correction propagation, legal notice, certification, or ship evidence.

## M44 — Governance Traceability & Implementation Readiness

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m44-governance-traceability-implementation-readiness-plan.md`.

**Goal:** freeze M31–M43 into an implementation-ready traceability handoff: one requirement inventory, one authority owner per subject, explicit state/error/fallback semantics, fixture/evidence ownership, and a bounded first-runtime-slice decision.

M44 executes in the order A requirement synthesis/canonical inventory → B authority binding/state ownership → C state/error/fallback/browser-first matrix → D fixture/evidence traceability → E runtime handoff/readiness decision. It depends on M0–M43 and reuses Honeycomb/source owners, EventLedger, consent/policy/lifecycle authorities, M31–M43 projections, browser/session/private boundaries, and M25/M32/M36 release/recovery evidence. M44 adds no new authority, ledger, service, governance concept, runtime implementation, model training, or release action. M44 can never be a canonical owner; `handoff-ready` is not implemented, shipped, safe, or verified; only a future owner’s fresh build/test/runtime evidence bound to one source revision/environment/scope and explicit owner approval can establish `verified`.

### Exit gate M44

Every selected M31–M43 requirement has one stable trace ID, source authority, owner, status, limitation, fixture/evidence mapping, and next action; each subject has one canonical owner or explicit unresolved/blocked state; M44 cannot become an owner and projections cannot mutate or self-promote; `verified` requires fresh build evidence, relevant test evidence, and user-observable runtime evidence bound to one source revision/environment/evidence scope and explicit owner approval; every fallback dimension is mapped or has owner-approved evidence-backed `not_applicable`; stale/conflicting/missing/private/locked/offline/denied/manual/accessibility states remain visible; the first future runtime slice has preconditions, stop conditions, rollback/deletion scope, synthetic fixtures, and browser-first fallback; and ordinary navigation, tabs, private mode, and local inspection remain usable. M44 is not implementation completion, compliance, security certification, accessibility conformance, production readiness, or a ship decision.

## M45 — Explicit Capture Implementation Readiness

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m45-explicit-capture-implementation-readiness-plan.md`.

**Goal:** hand the M1 explicit page/note capture loop from the validated M44 traceability boundary to a future runtime owner without claiming implementation: typed new/duplicate/partial/degraded outcomes, metadata-only provenance, stable capture-attempt/audit identity, privacy/context/scope admission, inspect/export/forget/delete recovery, and browser-first fallback. The linked M45 plan is authoritative for the exact UUID v4 attempt generation, persistence-before-side-effects rule, `capture/<attemptID>/v1` event encoding, retry reuse, and conflicting-payload block semantics.

M45 selects explicit capture as the smallest first runtime slice after M44. It depends on M0 storage/migration/recovery and the M1 contract, reuses BrowserState capture views, HoneycombStore, EventLedgerStore, HotMemoryStore, MemoryAdmissionPolicy, and existing browser/private boundaries, and keeps M2 import/Brief, M15 browser credibility breadth, ambient/WISP capture, model routing/training, page-body extraction, screenshots, remote services, and new authorities out of scope. M45 is documentation-only; it adds no store, ledger, migration, governance layer, runtime implementation, model training, telemetry, compliance claim, or ship claim. There is no new authority, store, ledger, or governance layer in this handoff. `handoff-ready` is not implemented or verified; only a future owner’s fresh build/test/user-observable runtime evidence bound to one source revision/environment/evidence scope and explicit owner approval can establish a runtime capability as `verified`.

### Exit gate M45

The M1 owner inventory reconciles the actual checkout and marks missing `MemoryRetrievalAdmission`/capture-attempt seams honestly; five work packages, 50 synthetic fixtures, and 12 gates cover typed results, provenance, stable audit retry, Honeycomb/EventLedger partial failure, pending/incomplete/unknown exclusion, consent-aware HotMemory, private/offline/locked/denied/manual/accessibility/reduced-motion/browser-first fallback, inspect/export/forget/delete, and evidence identity; no fixture, mock, plan, source symbol, or green documentation check is runtime proof; and M45 remains a bounded documentation handoff rather than implementation completion, compliance/security/accessibility certification, production readiness, or a ship decision.

## M46 — Storage, Migration, Backup & Recovery Implementation Readiness

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m46-storage-migration-recovery-implementation-readiness-plan.md`.

**Goal:** hand M0 storage/migration/backup/recovery from the existing Honeycomb/EventLedger/session/recovery seams to a future implementation owner without claiming storage health: verified connection-local pragmas, migration rollback, FTS/integrity checks, validated snapshots, Honeycomb-owned deletion tombstones with EventLedger deletion evidence, corruption quarantine, deletion-generation/non-resurrection continuity, cross-store recovery identity, and browser-first degradation.

M46 is the direct prerequisite boundary for M45. It audits current code-present SQLite foundations and turns the M0 contract into five work packages, 24 synthetic fixtures, and 14 gates. It reuses HoneycombStore, EventLedgerStore, HandoffRecoveryJournal, and existing session persistence; it does not create a second ledger, database, backup service, storage authority, distributed transaction, runtime implementation, model training, telemetry, compliance claim, or ship claim. `handoff-ready` is not implemented or verified; only fresh build/test/user-observable recovery evidence bound to one source revision/environment/evidence scope and explicit owner approval can establish `verified`.

## M47 — M0 Storage Runtime Execution & Evidence

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m47-m0-runtime-execution-plan.md`.

**Goal:** convert the M0/M46 storage contract into a bounded runtime implementation sequence and deterministic evidence harness without implementing it in this planning pass.

M47 is documentation-only and preserves existing ownership: Honeycomb owns nodes, FTS, revisions, and logical deletion generations; EventLedger owns append-only evidence; HandoffRecoveryJournal owns redacted repair gaps; browser persistence owns browser-session recovery. Its current runtime slice is limited to active Honeycomb/EventLedger; planned WISP candidate and M5 lifecycle stores remain deferred/blocked M0 participants and cannot be omitted from a future full-M0 verification claim. It specifies source/owner freeze, typed connection diagnostics, transactional migration and integrity/FTS fixtures, validated Online Backup staging, and a **provisional** active-set pointer/manifest protocol for selecting a complete store pair. M49’s later live-source authority audit supersedes any assumption that existing storage/recovery state already owns that protocol: no runtime active-set implementation may proceed until an explicitly approved `existing_owner_evidenced(...)` packet exists. M47 adds no second database, backup service, ledger, migration authority, storage epoch authority, repair journal, model/training path, or release/compliance claim. M45 remains blocked until M0 runtime evidence passes and the M49 owner block is resolved.

### Exit gate M47

The detailed plan’s six work packages, 24 fixture mappings, and 14 gates are implemented only after explicit approval; each runtime result binds source revision, environment, SQLite runtime, evidence scope, owner, limitation, and trace/manifest identity where applicable; unsafe raw-file backup and silent empty-store replacement are rejected; Honeycomb deletion generations plus EventLedger evidence prevent restore resurrection; and browser navigation, tabs, private mode, ordinary rendering, keyboard, accessibility, offline, locked, denied, and reduced-motion fallback remain usable. Source presence, mocks, fixtures, or plan validation do not establish `verified`; fresh build/test and clean-profile runtime evidence are required.

## M48 — Active-Set Activation & Recovery Readiness

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m48-active-set-activation-recovery-readiness-plan.md`.

**Goal:** turn M47’s crash-safe activation requirement into a precise, owner-bound file/generation protocol before any M0 Swift implementation begins.

M48 is documentation-only and covers only the current Honeycomb/EventLedger pair. It defines bounded activation artifacts, monotonic generation and manifest identity, handle/statement/backup closure, one canonical PREPARED/COMMITTED active-set record, startup selection of the newest complete matching pair, fail-closed interrupted publication, quarantine of malformed/mixed/interrupted generations, deletion non-resurrection, and browser-first degraded recovery. No current active-set owner is evidenced yet; runtime work is blocked until an existing storage/recovery owner is named and explicitly approved. Planned WISP/M5 stores remain blocked until separately registered in M0 and covered by the same contract. M48 adds no pointer database, second authority, ledger, backup service, coordinator service, migration authority, model/training path, or release/compliance claim.

### Exit gate M48

A future runtime pass may proceed only after the existing owner, path/container, handle lifecycle, publication primitive, generation rules, interruption behavior, startup selection, filesystem durability limitations, deletion evidence, and planned-participant boundary are reconciled from live source. The 24 fixture mappings and 14 gates must cover malformed manifests, mixed generations, unfinished handles, interrupted publication, no-complete-generation recovery, deletion non-resurrection, quarantine cleanup, and browser-first/private/offline/denied/accessibility fallback. M48 itself remains planning-only; platform API success, hashes, fixtures, mocks, or source presence do not prove power-loss durability, crash consistency, semantic completeness, `verified`, compliance, or production readiness.

## M49 — Active-Set Authority Resolution & Block Decision

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m49-active-set-authority-block-decision-plan.md`.

**Goal:** resolve the M48 owner blocker without inventing a new authority, pointer database, coordinator, or service.

M49 is documentation-only and records an explicit `blocked` decision: the live source currently evidences adjacent owners—HoneycombStore, EventLedgerStore, HandoffRecoveryJournal, browser session persistence, and application lifecycle/path handling—but no lawful owner for cross-store Honeycomb/EventLedger active-set selection. M49 audits each candidate against existing-source ownership, both-store scope, PREPARED/COMMITTED lifecycle, handle/publication coordination, deletion continuity, privacy, browser-first fallback, evidence authority, and the no-new-authority rule. Until an `existing_owner_evidenced(...)` packet is produced and explicitly approved, M0/M47/M48 runtime work and M45 capture remain blocked. Planned WISP/M5 participants stay blocked; no Swift/runtime edits, builds, tests, training, installs, new database/ledger/coordinator, power-loss, compliance, or ship claim is implied.

### Exit gate M49

The detailed plan’s owner audit, complete decision rubric, candidate dispositions, formal block/unblock contract, 24 evidence mappings, 14 gates, redaction/privacy boundary, and separate-architecture escalation rule are structurally validated and independently reviewed. M49 itself remains planning-only; source presence, path access, SQLite/API behavior, hashes, fixtures, mocks, or plan validation do not establish semantic authority, cross-store atomicity, crash consistency, power-loss durability, `verified`, compliance, production readiness, or ship readiness.

## M50 — StorageActivationCoordinator Architecture Decision

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m50-storage-activation-coordinator-architecture-decision-plan.md`.

**Goal:** explicitly resolve M49’s no-owner block by approving one narrowly bounded activation owner without creating a product-data authority.

M50 is documentation-only architecture approval for a new `StorageActivationCoordinator`. It owns exactly one bounded active-set metadata record and the selection/publication lifecycle for the current `{Honeycomb, EventLedger}` pair. Honeycomb remains the knowledge/FTS/revision/deletion authority; EventLedger remains append-only evidence/deletion authority; HandoffRecoveryJournal remains repair-gap authority; browser persistence and application lifecycle/path code remain adjacent mechanics. The coordinator owns no product content, schema/migrations, events, credentials, model context, permissions, WISP/M5 scope, SQLite database, second ledger, backup service, telemetry, or policy engine. PREPARED/COMMITTED selection, generation/deletion continuity, startup recovery, privacy, and browser-first fallback are specified, but implementation is blocked until M51. No Swift/runtime edits, status promotion, crash-consistency, power-loss, compliance, production-readiness, or ship claim is implied.

## M54 — StorageActivationCoordinator Execution Approval & Preflight

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m54-storage-activation-coordinator-execution-approval-preflight-plan.md`.

**Goal:** decide whether the exact M52 allowlisted Swift pass may start. M54 is documentation-only with default `HOLD`: it freezes source revision/tree state, paths, SwiftPM targets, platform/container facts, public store symbol/resource ownership, direct writers, owners, rollback, and M53 linkage. `GO` requires every preflight gate and explicit owner acknowledgement; missing facts remain `HOLD`; a proven allowlist/API contradiction is `BLOCK`; a synthetic adapter/codec-only option is `SPLIT`. M54 does not execute M52, create approval artifacts, or promote status. Exactly `{Honeycomb, EventLedger}` participates; WISP/M5 remain blocked. No coordinator database, second ledger, product-data authority, raw-handle transfer, power-loss/crash-consistency/production/compliance/ship claim is implied.

## M55 — StorageActivationCoordinator HOLD Resolution & API Boundary

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m55-storage-activation-coordinator-hold-resolution-api-boundary-plan.md`.

**Decision:** the full M52 runtime slice is `BLOCKED`, not merely held: the source audit found no public Honeycomb/EventLedger identity, health, schema, deletion-floor, writer-barrier, snapshot/backup, or close/reopen contract, and direct durable writers remain outside a coordinator barrier. A synthetic `SPLIT` pilot may be separately approved only for bounded metadata/codec/filesystem/state-machine/fault-injection work with fake participants; its fault-injection path is synthetic only and cannot establish runtime recovery. It cannot open real stores, touch SQLite handles or user data, integrate startup/browser state, or promote M52/M53/status. Synthetic evidence cannot promote M52, M53, or any capability status. Exactly `{Honeycomb, EventLedger}` participates; WISP/M5 remain blocked. No coordinator database, second ledger, product-data authority, raw-handle transfer, runtime implementation, or production/power-loss/crash-consistency/compliance/ship claim is implied.

## M56 — Production Storage-Authority Redesign Decision

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m56-storage-authority-redesign-decision-plan.md`.

**Decision:** keep M52 production runtime and real-store adapters `BLOCKED` by default. Select store-owned, actor-isolated lifecycle protocols with typed participant adapters as the planning target, without authorizing implementation. Compare extending existing stores, a shared storage owner, store-owned lifecycle protocols, and continued blocking; preserve `{Honeycomb, EventLedger}`, store-owned schema/migration/deletion/resource authority, no raw SQLite handles, no coordinator database/second ledger/product-data authority, and no status promotion. A future implementation plan must prove writer admission for every direct durable writer, store-owned backup/checkpoint/close/reopen, migration/deletion continuity, Swift actor/Sendable/cancellation boundaries, browser-first fallback, and M53 evidence handoff. WISP/M5 remain blocked. No runtime, production, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M57 — Store-Owned Lifecycle Implementation Readiness

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m57-storage-authority-implementation-readiness-contract-plan.md`.

**Decision:** retain `BLOCKED` for production implementation and real-store adapters. M57 converts M56 Option C into an owner/source/path/evidence contract: exact Honeycomb/EventLedger authority map, complete direct-writer inventory, typed raw-handle-free lifecycle boundary, migration/deletion/recovery requirements, separate synthetic versus real-store path classes, browser/private/offline/accessibility fallback, bounded evidence packet, rollback, and M53 handoff. Current disposition is `BLOCKED`; M57 cannot issue `GO` for implementation or status promotion. M57 cannot issue implementation `GO`; `HOLD`, `SPLIT`, and `TARGET_READY_FOR_REVIEW` do not authorize implementation or status promotion. Exactly `{Honeycomb, EventLedger}` participates; WISP/M5 remain blocked. No Swift/runtime, production, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M58 — Storage-Authority Inventory & Readiness

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m58-storage-authority-inventory-readiness-plan.md`.

**Decision:** keep implementation `BLOCKED` until a complete source- and call-site-bound inventory packet is independently reviewed. Current disposition is `BLOCKED`; M58 cannot issue `GO` for implementation or status promotion. Inventory Honeycomb/EventLedger declarations, all direct and indirect durable writers, owners, targets, access/isolation boundaries, SQLite lifecycle, migrations, deletion, backup/close/reopen, and browser fallback. All direct and indirect writer risks must be classified. Map `HandoffRecoveryJournal` and `SessionFileStore` as adjacent writers excluded from the production participant set unless separately admitted by a new architecture decision. M58 cannot issue implementation `GO` or status promotion; `HOLD`, `SPLIT`, and `TARGET_READY_FOR_REVIEW` authorize no code or store access. Exactly `{Honeycomb, EventLedger}` participates; WISP/M5 remain blocked. No coordinator database, second ledger, product-data authority, raw handles, runtime, production, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M66 — Revalidation Challenge, Revocation Lineage & Independent Review

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m66-revalidation-challenge-revocation-lineage-plan.md`.

**Decision:** Current disposition: BLOCKED. M66 defines independent challenge of M65 revalidation, reviewer-separation rules, append-only revocation/supersession lineage, dependency-bounded invalidation propagation, fail-closed precedence, rollback, browser/privacy fallback, and M53 linkage. A signature, digest, timestamp, mirror, or clean replay cannot establish runtime proof or complete dependency capture. M66 performs no runtime evidence work and does not edit Swift; HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted; M66 cannot issue implementation GO; no status promotion is permitted. Exactly `{Honeycomb, EventLedger}` participates; HandoffRecoveryJournal and SessionFileStore remain adjacent exclusions; WISP/M5 remain blocked. No runtime, production, recovery, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M69 — Evidence Receipt Challenge, Dispute Resolution & Re-review

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m69-evidence-receipt-challenge-dispute-rereview-plan.md`.

**Decision:** Current disposition: BLOCKED. M69 defines bounded challenge classes for M68 receipts and replay results, independent review, append-only dispute lineage, fail-closed dispositions, re-review/supersession, browser/privacy fallback, and M53 linkage. M69 performs no runtime evidence work and does not edit Swift; HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted; M69 cannot issue implementation GO; no status promotion is permitted. Exactly `{Honeycomb, EventLedger}` participates; HandoffRecoveryJournal and SessionFileStore remain adjacent exclusions; WISP/M5 remain blocked. No coordinator database, second ledger, dependency database, dispute service, revocation authority, or semantic authority is implied; no runtime, production, recovery, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M68 — Reconciliation Evidence Receipt & Independent Replay

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m68-reconciliation-evidence-receipt-independent-replay-plan.md`.

**Decision:** Current disposition: BLOCKED. M68 defines a bounded evidence receipt for M67 reconciliation, independent replay, distinct RECEIPT_VALID/REPLAY_CONVERGED/RUNTIME_VERIFIED boundaries, graph and omission limits, upstream freshness/lineage invalidation, fail-closed precedence, rollback, browser/privacy fallback, and M53 linkage. `RUNTIME_VERIFIED` is unavailable in M68; replay convergence cannot prove graph completeness, source correctness, runtime safety, or production readiness. M68 performs no runtime evidence work and does not edit Swift; HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted; M68 cannot issue implementation GO; no status promotion is permitted. Exactly `{Honeycomb, EventLedger}` participates; HandoffRecoveryJournal and SessionFileStore remain adjacent exclusions; WISP/M5 remain blocked. No coordinator database, second ledger, dependency database, revocation authority, replay authority, or semantic authority is implied; no runtime, production, recovery, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M67 — Revocation Propagation Reconciliation & Recovery

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m67-revocation-propagation-reconciliation-recovery-plan.md`.

**Decision:** Current disposition: BLOCKED. M67 defines bounded reconciliation of M66 revocation propagation over an explicit dependency graph, distinct CONVERGED/INCOMPLETE/DIVERGENT/UNKNOWN/REVOKED states, idempotent replay, unknown-edge/mirror-divergence handling, append-only recovery, restoration limits, fail-closed precedence, rollback, browser/privacy fallback, and M53 linkage. A converged bounded graph is not proof of complete real-world dependencies, transactional restoration, runtime safety, or admission. M67 performs no runtime evidence work and does not edit Swift; HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted; M67 cannot issue implementation GO; no status promotion is permitted. Exactly `{Honeycomb, EventLedger}` participates; HandoffRecoveryJournal and SessionFileStore remain adjacent exclusions; WISP/M5 remain blocked. No coordinator database, second ledger, dependency database, revocation authority, or semantic authority is implied; no runtime, production, recovery, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M65 — Admission Decision Freshness, Expiry & Revalidation

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m65-admission-freshness-expiry-revalidation-plan.md`.

**Decision:** Current disposition: BLOCKED. M65 defines claim-bound freshness classes, validity/clock limits, expiry/revocation/supersession triggers, append-only revalidation, fail-closed precedence, rollback, browser/privacy fallback, and M53 linkage. Freshness is not a timestamp alone; changed source, environment, authority, claim, path, owner, reviewer, policy, replay generation, or contradiction requires blocking or a new admission decision. M65 performs no runtime evidence work and does not edit Swift; HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted; M65 cannot issue implementation GO; no status promotion is permitted. Exactly `{Honeycomb, EventLedger}` participates; HandoffRecoveryJournal and SessionFileStore remain adjacent exclusions; WISP/M5 remain blocked. No runtime, production, recovery, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M64 — Bounded Execution-Handoff & Admission Checklist

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m64-bounded-execution-handoff-admission-plan.md`.

**Decision:** Current disposition: BLOCKED. M64 defines a source-bound handoff envelope, exact future allowlist/exclusions, admission checklist, fail-closed precedence, owner/reviewer responsibilities, replay/gap/freshness inputs, rollback, and M53 linkage. M64 performs no runtime evidence work and does not edit Swift; HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted; M64 cannot issue implementation GO; no status promotion is permitted. Exactly `{Honeycomb, EventLedger}` participates; HandoffRecoveryJournal and SessionFileStore remain adjacent exclusions; WISP/M5 remain blocked. No coordinator database, second ledger, product-data authority, runtime, production, recovery, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M63 — Decision-Record Replay & Anti-Omission

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m63-decision-record-replay-anti-omission-plan.md`.

**Decision:** Current disposition: BLOCKED. M63 defines a bounded replay manifest, deterministic comparator, anti-omission checks, integrity/completeness limits, and replay failure handling over M62. Replay can reproduce a recorded decision but cannot prove complete capture or runtime safety. M63 performs no runtime evidence work and does not edit Swift; HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access; M63 cannot issue implementation GO or status promotion. Exactly `{Honeycomb, EventLedger}` participates; HandoffRecoveryJournal and SessionFileStore remain adjacent exclusions; WISP/M5 remain blocked. No coordinator database, second ledger, product-data authority, runtime, production, recovery, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M62 — Bounded Readiness Decision Record

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m62-bounded-readiness-decision-record-plan.md`.

**Decision:** Current disposition: BLOCKED. M62’s TARGET_READY_FOR_REVIEW is structural documentation readiness only; it is not implementation-approved and is not runtime-ready. M62 aggregates source-bound M59–M61 inputs using fail-closed precedence, freshness/conflict handling, explicit gap accounting, owner/reviewer limits, and structural TARGET_READY_FOR_REVIEW semantics. M62 performs no runtime evidence work and does not edit Swift; HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access; M62 cannot issue implementation GO or status promotion. Exactly `{Honeycomb, EventLedger}` participates; HandoffRecoveryJournal and SessionFileStore remain adjacent exclusions; WISP/M5 remain blocked. No coordinator database, second ledger, product-data authority, runtime, production, recovery, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M61 — Independent Challenge & Evidence-Closure Decision

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m61-independent-challenge-evidence-closure-plan.md`.

**Decision:** Current disposition: BLOCKED. M61 performs no runtime evidence work and does not edit Swift. HOLD, SPLIT, and TARGET_READY_FOR_REVIEW authorize no code or store access; M61 cannot issue status promotion. M61 defines freshness/reproducibility bounds, independent challenge passes, contradiction handling, append-only gap closure/reopening, owner/reviewer authority limits, and structural `TARGET_READY_FOR_REVIEW` over M60. It cannot issue implementation GO or status promotion. Exactly `{Honeycomb, EventLedger}` participates; HandoffRecoveryJournal and SessionFileStore remain adjacent exclusions; WISP/M5 remain blocked. HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. No coordinator database, second ledger, product-data authority, runtime, production, recovery, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M60 — Owner Evidence Packet & Gap-Register Disposition

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m60-owner-evidence-packet-gap-register-plan.md`.

**Decision:** Current disposition: BLOCKED. M60 defines owner-by-owner packet completion, evidence binding, claim-strength limits, and an append-only gap lifecycle over M59; it cannot issue implementation GO or status promotion. Owner acknowledgement is governance evidence, not runtime verification. Exactly `{Honeycomb, EventLedger}` participates; HandoffRecoveryJournal and SessionFileStore remain adjacent exclusions; WISP/M5 remain blocked. HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. No coordinator database, second ledger, product-data authority, runtime, production, recovery, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M59 — Storage-Authority Inventory Evidence Review

**Detailed plan:** `docs/superpowers/plans/2026-08-12-m59-storage-authority-inventory-evidence-review-plan.md`.

**Decision:** retain `BLOCKED` until the M58 inventory packet passes five evidence tiers. Current disposition: BLOCKED. M59 cannot issue implementation GO or status promotion. The following evidence tiers are required: source/symbol, target/compile, store-local SQLite runtime, dynamic/async writer coverage, and independent owner review. Static declarations and search results cannot prove runtime writer exclusion, dynamic dispatch, escaping task/delegate behavior, SQLite resource safety, or recovery. `HandoffRecoveryJournal` and `SessionFileStore` remain adjacent exclusions. M59 cannot issue implementation `GO` or status promotion; `HOLD`, `SPLIT`, and `TARGET_READY_FOR_REVIEW` authorize no code or store access. Exactly `{Honeycomb, EventLedger}` participates; WISP/M5 remain blocked. No coordinator database, second ledger, product-data authority, runtime, production, power-loss, crash-consistency, cross-store atomicity, compliance, or ship claim is implied.

## M53 — StorageActivationCoordinator Runtime Evidence Review

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m53-storage-activation-coordinator-runtime-evidence-review-plan.md`.

**Goal:** review any separately approved M52 execution through source/diff audit, fresh build/focused tests, deterministic integration/fault evidence, restart/recovery harness, manual clean-profile browser evidence, and independent owner review. M53 is documentation-only in this turn and does not execute M52, create evidence, or promote status. Exactly `{Honeycomb, EventLedger}` participates; WISP/M5 remain blocked. `verified` requires a single source revision/environment/evidence scope, all required tiers, independent review, and exact owner approval; green builds, mocks, fixtures, API success, screenshots, or plan validation are insufficient. Power-loss, crash-consistency, cross-database atomicity, production, compliance, and ship claims remain blocked.

## M52 — StorageActivationCoordinator Runtime Implementation

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m52-storage-activation-coordinator-runtime-implementation-plan.md`.

**Goal:** provide a separately approved, exact-allowlist runtime sequence for adapters/ownership → bounded codec → filesystem publication → coordinator actor → browser-first projection → deterministic fault injection. M52 may eventually authorize a narrowly bounded Swift pass, but this planning turn does not edit or authorize runtime code. The initial allowlist contains only new `Sources/HiveCore/Activation/` and `Tests/HiveCoreTests/Activation/` files; existing Honeycomb/EventLedger/HandoffRecoveryJournal/browser persistence files remain outside scope unless a new decision approves them. Exactly `{Honeycomb, EventLedger}` participates; WISP/M5 remain blocked. No coordinator database, second ledger, product-data authority, raw SQLite-handle transfer, model/network widening, power-loss/crash-consistency/production-readiness/ship claim is implied. M53 runtime evidence review remains required before status promotion.

### Exit gate M50

The detailed M50 decision packet’s option comparison, bounded coordinator scope, one-record rule, participant boundaries, lifecycle/deletion/fallback limits, 24 evidence mappings, 14 gates, and M51 implementation block are structurally validated and independently reviewed. M50 is not verified and does not establish cross-store atomicity, crash consistency, power-loss durability, secure deletion, compliance, production readiness, or ship readiness.

## M51 — StorageActivationCoordinator Implementation Readiness

**Detailed execution plan:** `docs/superpowers/plans/2026-08-12-m51-storage-activation-coordinator-implementation-readiness-plan.md`.

**Goal:** translate M50’s architecture decision into source-bound interfaces, codec/record rules, actor/barrier/closure/publication seams, deterministic failure fixtures, browser-first fallback, and a separately approved implementation handoff.

M51 is documentation-only and does not create or edit Swift code. It freezes the current Honeycomb/EventLedger writers and lifecycle seams; defines injected coordinator, metadata codec, filesystem, participant, and evidence interfaces; bounds the canonical record; specifies writer barriers, SQLite backup/statement/connection closure, publication and startup outcomes, cancellation/stale-generation handling, and deterministic failure injection. Its runtime participant set is exactly `{Honeycomb, EventLedger}`; WISP/M5 remain blocked. M51 defines 40 fixture mappings and 14 gates, but implementation remains blocked until the M51 handoff packet passes and a separate runtime approval names exact changed paths. No new coordinator database, second ledger, product-data authority, model context, power-loss, crash-consistency, compliance, production-readiness, or ship claim is implied.

### Exit gate M51

The detailed M51 plan’s six work packages, explicit interfaces, bounded codec/record contract, writer-barrier/resource-closure/publication sequence, failure-injection map, 40 fixture mappings, 14 gates, browser-first fallback, evidence envelope, and separate implementation-approval requirement are structurally validated and independently reviewed. M51 is not implementation or verification; source presence, parser/fixture/mock success, actor compilation, SQLite/API success, or plan validation do not prove runtime correctness, crash consistency, power-loss durability, `verified`, compliance, production readiness, or ship readiness.

### Exit gate M46

Actual storage owners, SQLite runtime, participant set, and test suites are reconciled; migration/user_version rollback, per-connection journal/FK/synchronous/busy diagnostics, quick/integrity/FTS checks, Online Backup staging, manifest/epoch limits, Honeycomb-owned deletion tombstones plus matching EventLedger deletion evidence, corruption quarantine, deletion-generation/non-resurrection continuity, partial cross-store recovery, and explicit non-empty ephemeral fallback are mapped to 24 synthetic fixtures and 14 gates; WAL and raw main-file copies are not treated as atomic or sufficient recovery; no unreadable store is silently replaced; ordinary navigation, tabs, private mode, and rendering remain usable; and M46 remains documentation-only rather than storage implementation, backup certification, disaster-recovery assurance, compliance/security/accessibility certification, production readiness, or a ship decision.

## Workflow status
