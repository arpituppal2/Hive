# Hive M50 — StorageActivationCoordinator Architecture Decision

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; architecture decision approved, implementation deferred
> **Roadmap label:** M50 StorageActivationCoordinator Architecture Decision
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m49-active-set-authority-block-decision-plan.md`
> **Related contracts:** M0 storage/recovery, M46 readiness, M47 runtime execution, M48 active-set activation, M49 authority block
> **Primary source seams:** `HoneycombStore`, `EventLedgerStore`, `HandoffRecoveryJournal`, browser session persistence/recovery, Application Support/path ownership, and current persistence/recovery tests
> **Next planning boundary:** M51 bounded coordinator implementation readiness; no runtime implementation is authorized by M50
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M50 resolves the M49 owner block by approving one narrowly bounded new semantic owner: `StorageActivationCoordinator`. It owns only the selection and publication metadata for the current Honeycomb/EventLedger active set. It does not own product data, either database's schema, EventLedger evidence, Honeycomb knowledge/deletion, browser sessions, permissions, migrations, or model context. M50 is an architecture decision, not an implementation or verification claim.

## 0. Decision summary

**Decision: approve a bounded `StorageActivationCoordinator`; implementation deferred to M51.**

M49 correctly rejected silently promoting Honeycomb, EventLedger, HandoffRecoveryJournal, browser-session persistence, or path/lifecycle code into a cross-store selector. M50 makes the required separate architecture decision explicitly instead of letting an owner emerge accidentally through a helper, singleton, manifest parser, or UI callback.

| Option | Disposition | Reason |
|---|---|---|
| Extend `HoneycombStore` | Rejected | Would make the knowledge store a hidden control plane over EventLedger and browser startup selection. |
| Extend `EventLedgerStore` | Rejected | Would violate append-only evidence semantics by making mutable activation state an ordinary ledger authority. |
| Repurpose `HandoffRecoveryJournal` | Rejected | Would turn redacted repair-gap evidence into a startup selector and change its lifecycle/replay contract. |
| Use browser session persistence or path/lifecycle owner | Rejected as semantic owner | These provide adjacent mechanics/UI/path containment, not cross-store memory/audit authority. |
| **Add `StorageActivationCoordinator`** | **Approved as architecture; implementation deferred** | A dedicated bounded owner can select one complete pair without changing either store's domain authority, provided its scope is fixed below. |
| Remain blocked indefinitely | Not selected | M50 is the explicit architecture decision required to resolve M49 without hiding a new authority. |

M50 does not authorize Swift edits or runtime status changes. M51 must independently translate this decision into a bounded implementation-readiness plan and must stop if the actual source, platform, or ownership constraints contradict it.

## 1. Binding architecture contract

### 1.1 Authority ownership

`StorageActivationCoordinator` owns exactly:

- the canonical active-set metadata record;
- staged-generation lifecycle (`PREPARED`, `COMMITTED`, `SUPERSEDED`, `QUARANTINED`);
- selection of one complete Honeycomb/EventLedger pair at startup;
- publication preconditions and handle-closure coordination;
- cross-store identity matching and generation checks;
- deletion-generation reconciliation before publication;
- bounded activation/recovery evidence and failure classification;
- browser-first degraded-state projection for unavailable memory/audit storage.

It must not own:

- Honeycomb nodes, edges, FTS, revisions, source content, or logical-deletion materialization;
- EventLedger events, event IDs, append-only evidence, or retention semantics;
- migrations or schema versions, which remain store-owned;
- browser tabs, windows, session snapshots, or private-mode policy;
- model routing, prompts, context selection, or tool permissions;
- raw page text, browsing history, secrets, cookies, credentials, prompts, screenshots, or arbitrary user paths;
- a second ledger, SQLite database, backup service, telemetry system, or policy engine.

Honeycomb and EventLedger remain separate authorities. The coordinator is an activation control plane over their bounded identities, not a distributed transaction manager and not a replacement memory/audit store.

### 1.2 Participant boundary

The only M50/M51 runtime participant set is:

```text
{Honeycomb, EventLedger}
```

WISP candidate storage and M5 lifecycle storage remain planned, blocked, and unregistered. They cannot inherit M50 authority or evidence. Before either joins a future M0 implementation, it requires its own participant registration and an expanded active-set, generation, backup, restore, deletion, recovery, browser-fallback, and evidence decision.

### 1.3 Canonical metadata record

M50 approves exactly one canonical metadata record owned by the coordinator. It may be a bounded file or another explicitly reviewed non-database representation within the application-controlled container. M50 does not choose the serialization or filesystem primitive; M51 must document and validate that choice.

The record may contain only bounded metadata:

```text
ActiveSetRecord {
  format_version
  generation: strictly_increasing_integer
  state: PREPARED | COMMITTED | SUPERSEDED | QUARANTINED
  snapshot_id
  honeycomb_identity
  event_ledger_identity
  honeycomb_schema_version
  event_ledger_schema_version
  manifest_hash
  deletion_generation_floor
  source_revision
  environment
  evidence_scope
  limitation
}
```

The record must not contain product objects, page text, event payloads, user credentials, model prompts, private URLs, cookies, screenshots, arbitrary absolute paths, or unbounded diagnostics. Paths, if any are needed internally, are owner-resolved and never user-visible evidence fields.

The record is not a source of truth for store contents. It can say which pair and generation are eligible for selection; each store remains authoritative for its own contents and health.

## 2. Lifecycle and state contract

### 2.1 Candidate publication order

M51 must implement and evidence this order without treating it as already live:

```text
stage Honeycomb and EventLedger through their own validated mechanisms
  → validate schema, health, identities, and deletion continuity
  → write one bounded PREPARED(N+1) record
  → stop/admit no affected writers through approved store/coordinator boundary
  → close and verify all owned statements, transactions, backups, and connections
  → perform the chosen same-container publication operation
  → publish COMMITTED(N+1) only as one complete canonical record
  → reopen both stores from that generation
  → validate both identities and all required checks
  → mark prior generation SUPERSEDED only after new generation validates
```

`PREPARED` is never selectable. `COMMITTED` is selectable only when its generation, identities, manifest hash, schema versions, health evidence, and deletion floor agree with both stores. A publication failure preserves the prior complete generation where available and classifies the candidate as quarantined or blocked.

### 2.2 Startup selection

Startup must:

1. Read only coordinator-owned records within the approved application container.
2. Reject malformed, oversized, unsupported, hash-mismatched, `PREPARED`, and quarantined records.
3. Select the newest complete `COMMITTED` generation by monotonic generation, not wall-clock time.
4. Require matching Honeycomb and EventLedger identities from the same generation.
5. Validate store-local schema, connection, integrity, FTS, and deletion-continuity evidence.
6. Quarantine a newest invalid generation and fall back to the newest prior complete generation.
7. Enter `recovering`/`blocked` if no complete generation exists.
8. Never create an empty durable store as a corruption or startup substitute.
9. Keep navigation, tabs, private browsing, ordinary rendering, keyboard, accessibility, offline, locked, denied, and manual browsing fallback usable.

The coordinator must never independently choose Honeycomb from one generation and EventLedger from another.

### 2.3 Deletion continuity

Honeycomb remains the authority for logical deletion materialization. EventLedger remains the authority for append-only deletion evidence. Before a generation becomes `COMMITTED`, the coordinator must require evidence that the candidate pair includes every newer deletion generation known to the participating authorities.

Generation/identity continuity, not wall-clock timestamps, resolves deletion ordering. If deletion evidence is missing, ambiguous, or cannot be matched, publication is blocked or `requires_reconciliation`; it cannot be marked healthy or verified. An older snapshot must never resurrect a later deletion in retrieval, FTS, HotMemory, export, or user-visible Knowledge projections.

## 3. Safety and privacy boundaries

### 3.1 No new data authority

The coordinator is a new semantic owner, but not a new product-data authority. It is not a product-data authority. The following are explicitly forbidden:

- coordinator-owned SQLite storage;
- coordinator-owned EventLedger or second ledger/append-only ledger;
- coordinator-owned migrations for Honeycomb/EventLedger;
- coordinator-owned raw snapshots or product-content cache;
- coordinator-owned model context or prompt archive;
- coordinator-owned credentials, cookies, or Keychain values;
- coordinator-owned telemetry or engagement history;
- silent coordinator authority over WISP, M5, connectors, sync, or OS automation.

A bounded metadata file is allowed only because M50 explicitly approves it as the single activation record. There is no second ledger. Adding any additional durable authority requires a new architecture decision.

### 3.2 Browser-first fallback

Coordinator failure must not disable the browser. When no valid active pair exists:

- ordinary navigation, tabs, private windows, rendering, keyboard, accessibility, and offline browsing continue;
- durable memory/audit actions are disabled or typed as unavailable/degraded;
- no in-memory result is presented as durable success;
- no model/network call is triggered by storage failure;
- recovery UI shows bounded state and an explicit retry/export path without raw content or secrets;
- private, locked, denied, canceled, reduced-motion, and manual states remain understandable.

The browser must not infer that an empty memory result means the user has no memory.

### 3.3 Evidence and status honesty

Every future M51 result must bind:

```text
trace_id
source_revision
environment
sqlite_runtime_version
evidence_scope
active_set_generation
snapshot_id
manifest_hash
honeycomb_identity
event_ledger_identity
observed_state
limitation
owner
```

M50 is not verified. It does not prove semantic authority beyond this explicit architecture decision, cross-store atomicity, crash consistency, power-loss durability, secure deletion, compliance, production readiness, or ship readiness. M51 must not promote a status from planning, source presence, mocks, fixtures, or platform API success.

## 4. M50-A — Architecture decision evidence

The decision packet must record:

1. The M49 block and every rejected candidate.
2. The exact coordinator authority scope and prohibited scope.
3. The participant set `{Honeycomb, EventLedger}`.
4. The canonical record shape and bounded metadata policy.
5. The lifecycle, startup, deletion, quarantine, and fallback contracts.
6. The reason a file/metadata record is permitted while a coordinator database/ledger is forbidden.
7. The exact SQLite/Apple claims used and their limitations.
8. The source revision, environment, evidence scope, decision owner, and approval state.
9. The fact that M50 is architecture approval only and M51 remains required before runtime implementation.

Required result:

```text
architecture_approved(
  owner = StorageActivationCoordinator,
  participant_set = {Honeycomb, EventLedger},
  metadata_authority = one_bounded_active_set_record,
  implementation_status = blocked_until_M51
)
```

## 5. M50-B — Candidate and boundary review

M51 cannot proceed until the decision packet confirms:

| Boundary | Must remain true |
|---|---|
| Honeycomb | Knowledge/FTS/revision/logical-deletion authority only |
| EventLedger | Append-only evidence/deletion-event authority only |
| HandoffRecoveryJournal | Redacted repair-gap and retry identity only |
| Browser persistence | Browser-session recovery only |
| Application lifecycle/path | Container/path/startup mechanics, not product-data authority |
| Coordinator | One activation metadata record and selection lifecycle only |
| WISP/M5 | Planned/blocked/unregistered |

Any conflict reopens M49 and blocks M51.

## 6. M50-C — Deterministic evidence matrix

All evidence is synthetic, local, bounded, and excludes real browsing history, page content, private URLs, credentials, cookies, screenshots, prompts, secrets, arbitrary absolute paths, and full database contents.

| IDs | Evidence family | Required assertion |
|---|---|---|
| M50-01–04 | decision packet | M49 block, option comparison, explicit approval, M51 implementation block |
| M50-05–08 | authority scope | coordinator-only metadata authority, Honeycomb/EventLedger separation, no database/ledger, no WISP/M5 registration |
| M50-09–12 | record/lifecycle | bounded record shape, PREPARED/COMMITTED rules, monotonic generation, mixed-generation rejection |
| M50-13–16 | startup/recovery | malformed/oversized/quarantined rejection, prior-generation fallback, no-complete-generation blocked state, no empty-store initialization |
| M50-17–20 | deletion/privacy | deletion-generation continuity, no resurrection, no raw content/secrets, bounded path handling |
| M50-21–24 | fallback/handoff | browser-first degraded paths, evidence envelope, M51 handoff, separate-architecture escalation |

Fixture definitions are not runtime proof. Each evidence result binds `trace_id`, `source_revision`, `environment`, `evidence_scope`, owner, timestamp, limitation, and observed result.

## 7. Fourteen M50 gates

| Gate | Requirement |
|---|---|
| M50-A | M49’s no-owner block and all candidate dispositions are preserved in the decision packet. |
| M50-B | `StorageActivationCoordinator` is explicitly approved as the only new semantic owner, with exact scope and prohibited scope. |
| M50-C | Runtime participant set is exactly Honeycomb/EventLedger; WISP/M5 remain blocked and unregistered. |
| M50-D | Honeycomb remains knowledge/FTS/revision/logical-deletion authority. |
| M50-E | EventLedger remains append-only evidence/deletion-event authority. |
| M50-F | HandoffRecoveryJournal remains a repair-gap/retry-identity authority, not a selector. |
| M50-G | Browser persistence and application path/lifecycle owners remain separate adjacent boundaries. |
| M50-H | Exactly one bounded canonical activation metadata record is permitted; no coordinator database/ledger/service is permitted. |
| M50-I | PREPARED/COMMITTED state, monotonic generation, matching identities, startup selection, and quarantine are specified. |
| M50-J | Deletion-generation reconciliation prevents snapshot resurrection. |
| M50-K | Browser-first/private/offline/locked/denied/accessibility/manual fallback remains usable. |
| M50-L | Evidence is local, redacted, bounded, trace-bound, and explicit about limitations. |
| M50-M | M50 is architecture-only; M51 is required before Swift/runtime implementation or status promotion. |
| M50-N | Independent review confirms no authority inflation, scope leakage, or platform/API overclaim. |

## 8. Stop conditions

Keep M51 blocked and reopen M49 if:

- the coordinator gains product-data, event-ledger, migration, permission, model-context, telemetry, or WISP/M5 authority;
- more than one durable activation authority is introduced;
- a coordinator SQLite database, second ledger, shadow cache, or backup service is proposed;
- Honeycomb and EventLedger are treated as one distributed transaction;
- a mixed generation can be selected;
- deletion evidence is absent, ambiguous, or can be superseded by wall-clock time;
- malformed/unknown records are silently ignored or replaced with an empty store;
- raw content, secrets, private URLs, credentials, prompts, cookies, screenshots, or unbounded paths enter metadata/evidence;
- browser/private/offline/locked/denied/accessibility/manual fallback weakens;
- M50 planning evidence is treated as runtime verification;
- WISP/M5/M45/M2 scope is added without a new approved decision;
- the target filesystem/API behavior contradicts the chosen publication contract.

## 9. Explicit deferrals and honest limits

M50 does not implement or verify:

- Swift/runtime coordinator code, M51 implementation readiness, M0 execution, M47/M48 runtime, or M45 capture;
- WISP candidate/M5 lifecycle stores, M2 import/Brief, models/training, research, MCP, sync, connectors, OS automation, cloud backup, or release;
- filesystem crash consistency, power-loss durability, distributed transactions, secure/forensic deletion, disaster-recovery RPO/RTO, compliance, production readiness, or ship readiness;
- a serialization choice or claim that any particular Apple/SQLite primitive is sufficient without M51 target-specific evidence.

**M50 is complete as a documentation-only architecture decision when its option comparison, bounded coordinator contract, one-record rule, participant boundaries, lifecycle/deletion/fallback limits, 24 evidence mappings, 14 gates, and independent review are structurally validated.**

## 10. Primary references and claim limits

- [SQLite Online Backup API](https://www.sqlite.org/backup.html) — consistent database snapshot mechanics; does not assign cross-store semantic authority.
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html) — unfinished statement/backup handle behavior; does not select an application owner.
- [SQLite WAL](https://www.sqlite.org/wal.html) — single-writer and checkpoint behavior; does not make separate databases one transaction.
- [SQLite transactions](https://www.sqlite.org/lang_transaction.html) — per-database transaction boundaries.
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox) — container/access boundary; does not assign product semantics.
- [Apple Application Support](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/WhereToPutFiles/WhereToPutFiles.html) — persistent app-data placement.
- [Apple FileManager replacement](https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:)) — individual-item replacement; does not make multiple SQLite stores atomic.
- [Apple NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator) — cooperative file coordination; does not understand SQLite semantic transactions or assign domain authority.
- [Swift actors](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) — isolation building block; does not itself choose product ownership.

These references establish platform/library limits. M50’s coordinator scope, one-record rule, participant boundary, browser fallback, evidence matrix, and M51 implementation block are Hive-specific decisions. M50 does not claim runtime verification.
