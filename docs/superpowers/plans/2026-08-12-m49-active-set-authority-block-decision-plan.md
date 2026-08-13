# Hive M49 — Active-Set Authority Resolution & Block Decision

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; explicit implementation block
> **Roadmap label:** M49 Active-Set Authority Resolution & Block Decision
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m48-active-set-activation-recovery-readiness-plan.md`
> **Related contracts:** M0 storage/recovery, M46 readiness, M47 runtime execution, M48 active-set activation
> **Primary source seams:** `HoneycombStore`, `EventLedgerStore`, `HandoffRecoveryJournal`, browser session persistence/recovery, application lifecycle/path ownership, and their current tests
> **Non-dependencies:** all Swift/runtime implementation, M0 execution, M45 capture, M2 import/Brief, WISP, M5 lifecycle, models/training, sync, connectors, OS automation, cloud backup, and release work
>
> M49 exists because M48 found a real architecture blocker: no current source owner is evidenced for the one canonical active-set record that would select a complete Honeycomb/EventLedger pair. M49 formalizes the block. It does not choose a new owner, add a pointer database, or authorize implementation.

## 0. Decision summary

**Decision: blocked.** M0 runtime implementation, M47 execution, M48 activation implementation, and M45 explicit-capture runtime remain blocked until an existing owner is evidenced and explicitly approved—or a separate architecture decision explicitly changes the no-new-authority boundary.

The current source contains adjacent owners, but not a demonstrated owner for cross-store active-set selection:

| Candidate | What it currently owns | Why it cannot be promoted by M49 |
|---|---|---|
| `HoneycombStore` | Knowledge nodes, edges, revisions, FTS, logical deletion | Does not own EventLedger lifecycle or the browser startup selection of a pair; embedding active-set state would widen Honeycomb authority without evidence |
| `EventLedgerStore` | Append-only consequential evidence and idempotent events | Cannot own mutable activation selection without violating append-only semantics or becoming a new authority over Honeycomb |
| `HandoffRecoveryJournal` | Redacted cross-store repair gaps and retry identity | Is a repair-gap ledger, not a published active-set authority; repurposing it would change its contract and lifecycle |
| Browser session persistence/recovery | Browser-session snapshots, restore/quarantine UI, user-visible recovery state | Does not own Honeycomb/EventLedger semantics; session recovery is not memory/audit recovery |
| Application lifecycle/path owner | App Sandbox/Application Support path resolution and startup wiring | Can contain and launch existing owners but does not own cross-store selection semantics |
| New coordinator/pointer database/service | Could theoretically arbitrate both stores | Explicitly prohibited by M48 without a separate approved architecture decision |

M49 does not claim that these candidates can never evolve. It records that none is currently evidenced as a lawful owner under the accepted constraints. This documentation-only plan does not establish semantic authority. It does not establish cross-store atomicity, crash consistency, or power-loss durability. M49 is not verified; any earlier plan language that presumes an existing active-set owner is provisional and is superseded by this explicit block until the owner packet is approved.

## 1. Binding architecture rules

These rules are inherited from M0/M46/M47/M48 and are not relaxed by this plan:

1. Honeycomb and EventLedger remain separate authorities and are not a distributed transaction.
2. The current M49 runtime participant set is exactly Honeycomb + EventLedger.
3. WISP candidate and M5 lifecycle stores remain planned/blocked and cannot be pulled into this decision.
4. There is one canonical active-set record only if an existing approved owner can own it; M49 does not create that record.
5. A valid hash, SQLite backup, file replacement API, actor, manifest, or test fixture does not independently create authority or prove crash durability.
6. The browser remains usable without memory/audit storage: navigation, tabs, private browsing, ordinary rendering, keyboard, accessibility, offline, locked, denied, and manual fallback cannot be sacrificed to unblock storage.
7. Logical deletion is owned by Honeycomb and deletion evidence by EventLedger; no older snapshot may resurrect a later deletion.
8. No source, page, model, manifest, or user content may grant activation authority.
9. No status may move to `verified` from source presence, mocks, fixtures, planning validation, or a successful platform API call.

## 2. M49-A — Live owner audit

This is a documentation-only source audit. It must be based on the actual checkout and record:

1. Every initializer and lifecycle boundary for Honeycomb/EventLedger.
2. Every current direct writer and reader of each store.
3. The owner of each actor, SQLite handle, prepared statement, transaction, backup operation, and close path.
4. The exact `HandoffRecoveryJournal` record lifecycle and whether it can safely represent activation metadata without changing its purpose.
5. The exact browser-session persistence/recovery owner and its boundary from memory/audit stores.
6. Application Support/container path resolution and startup wiring.
7. Existing manifest, snapshot, atomic replacement, generation, or recovery metadata types, if any.
8. Existing tests proving or disproving multi-store selection, interrupted publication, and restart behavior.
9. Current deletion-generation/tombstone and EventLedger deletion-evidence fields, or the explicit M0 schema gap.
10. Source revision, environment, evidence scope, owner, observed state, and limitation for every finding.

The audit must not infer authority from filename, proximity, a singleton, a closure, a UI callback, a test helper, or a plan paragraph.

### M49-A required result

The result must be one of:

```text
existing_owner_evidenced(owner_id, scope, lifecycle, evidence)
no_existing_owner_evidenced(block_reason, candidates, evidence)
source_conflict(blocked_reason, conflicting_sources, required_decision)
```

The current expected result is `no_existing_owner_evidenced`.

## 3. M49-B — Ownership decision rubric

An existing owner can be accepted only if all conditions pass:

| Criterion | Required proof | Failure consequence |
|---|---|---|
| Existing source owner | Concrete current symbol and lifecycle authority | `blocked` |
| Both-store scope | Explicit authority over Honeycomb and EventLedger selection, not only one store | `blocked` |
| Single-record lifecycle | Can own PREPARED/COMMITTED generation state without a second authority | `blocked` |
| Handle/publication coordination | Can prevent writers, prove close, and coordinate startup selection | `blocked` |
| Deletion continuity | Can consume Honeycomb tombstones and EventLedger deletion evidence without rewriting either | `blocked` |
| Recovery ownership | Can classify incomplete/mixed generations and preserve prior complete state | `blocked` |
| Privacy boundary | Stores only bounded IDs/metadata, never raw product content or secrets | `blocked` |
| Browser-first fallback | Its failure cannot disable ordinary browsing/private mode | `blocked` |
| Evidence authority | Can bind source revision/environment/scope/limitation/owner without becoming telemetry | `blocked` |
| No-new-authority rule | Does not require a third DB, ledger, coordinator, or shadow service | `blocked` |

Passing only path containment, SQLite access, or UI presentation is insufficient. A candidate that meets some but not all criteria remains unapproved.

## 4. M49-C — Candidate disposition

### 4.1 Honeycomb disposition

Keep Honeycomb as the authority for knowledge content, FTS, revisions, and logical deletion materialization. Do not add active-set selection semantics to it during M49. A future proposal to extend Honeycomb must be a separate architecture decision that proves it can coordinate EventLedger without making the knowledge store a hidden control plane.

### 4.2 EventLedger disposition

Keep EventLedger append-only. Do not store mutable active-set state or publication pointers as ordinary events and call that an activation authority. A future proposal must preserve append-only evidence while naming a separate existing owner for selection.

### 4.3 HandoffRecoveryJournal disposition

Keep `HandoffRecoveryJournal` limited to redacted repair gaps and exact operation identity. Do not repurpose repair records as the canonical startup selector. A future proposal must prove that any extension preserves repair semantics, retention, deletion, and no-replay guarantees without creating a second ledger.

### 4.4 Browser-session disposition

Keep browser session persistence focused on browser tabs/windows/session recovery. Do not use session snapshots as memory/audit snapshots or allow memory-store corruption to overwrite session state.

### 4.5 Application lifecycle/path disposition

Keep application lifecycle/path ownership responsible for container-safe path resolution and startup wiring. It may be a candidate coordinator only if live source proves it has the necessary cross-store lifecycle authority; path access alone is not authority.

### 4.6 New-owner disposition

M49 rejects a new coordinator, pointer database, manifest database, backup service, or shadow authority. Such a change requires a separate approved architecture decision that explicitly revisits M0/M48’s no-new-authority rule, data lifecycle, deletion, privacy, recovery, and browser-first contracts. M49 cannot silently make that change.

## 5. M49-D — Formal block and unblock contract

### 5.1 Blocked now

Until `existing_owner_evidenced(...)` is produced and explicitly approved:

- no Swift edits for active-set/M0 runtime;
- no active-set record implementation;
- no pointer/manifest database or service;
- no M0 status promotion;
- no M45 capture runtime;
- no WISP/M5 runtime participant registration;
- no claims of crash-safe restore, power-loss durability, or complete recovery.

The browser-first fallback remains the only permitted product behavior if memory/audit storage is unavailable: ordinary browsing continues; durable memory/audit actions remain disabled or honestly typed.

### 5.2 To unblock later

A future approval packet must include:

```text
owner_id
owner_scope
current_source_symbol
lifecycle_boundary
participant_set = {Honeycomb, EventLedger}
active_record_location_policy
PREPARED/COMMITTED state owner
handle/statement/backup close authority
delete-generation reconciliation authority
startup selection authority
quarantine/cleanup authority
browser fallback authority
source_revision
environment
evidence_scope
owner approval
known limitations
```

The packet must also identify whether any requirement forces a new authority. If yes, M49 remains blocked and a separate architecture decision is required.

## 6. M49-E — Deterministic evidence matrix

All evidence is synthetic/local and excludes page text, real browsing history, private URLs, credentials, cookies, prompts, screenshots, arbitrary paths, and full database contents.

| IDs | Audit family | Required assertion |
|---|---|---|
| M49-01–04 | owner inventory | exact Honeycomb/EventLedger/Journaling/session/path symbols and lifecycle boundaries are listed |
| M49-05–08 | candidate rejection | each adjacent candidate fails or passes the ownership rubric with concrete evidence |
| M49-09–12 | authority boundary | no second ledger/database/coordinator, no cross-store event masquerading as selector, no session/memory conflation, no plan-text authority |
| M49-13–16 | lifecycle | handle/statement/backup/close/startup ownership is either evidenced or blocked; current deletion evidence is mapped |
| M49-17–20 | privacy/fallback | bounded metadata only, no raw content, browser/private/offline/locked/denied/accessibility/manual fallback preserved |
| M49-21–24 | disposition/unblock | formal blocked result, source conflict result, hypothetical existing-owner packet, and separate-architecture-required result are distinct |

Fixture definitions are not runtime proof. Each finding binds `trace_id`, `source_revision`, `environment`, `evidence_scope`, owner, timestamp, limitation, and observed result.

## 7. Fourteen M49 gates

| Gate | Requirement |
|---|---|
| M49-A | Live source inventory identifies all relevant storage, recovery, path, lifecycle, and startup owners. |
| M49-B | Current participant set is exactly Honeycomb/EventLedger; WISP/M5 remain blocked and unregistered. |
| M49-C | Every candidate owner is evaluated against the complete ownership rubric, not filename proximity or path access. |
| M49-D | Honeycomb remains knowledge/deletion authority; EventLedger remains append-only evidence authority. |
| M49-E | HandoffRecoveryJournal remains a repair-gap authority and is not silently promoted to active-set selection. |
| M49-F | Browser session persistence remains separate from memory/audit storage and recovery. |
| M49-G | Application lifecycle/path ownership is distinguished from semantic active-set authority. |
| M49-H | No current owner is accepted without concrete source symbol, lifecycle scope, and evidence. |
| M49-I | No new pointer database, coordinator service, ledger, backup service, or shadow authority is introduced. |
| M49-J | PREPARED/COMMITTED ownership, handle closure, startup selection, quarantine, deletion continuity, and browser fallback remain blocked if owner proof is absent. |
| M49-K | Formal blocked status prevents M0/M47/M48 implementation and M45 runtime work. |
| M49-L | All findings are redacted, local, bounded, and bound to source revision/environment/scope/limitation/owner. |
| M49-M | Unblock packet specifies owner, scope, participant set, lifecycle, evidence, approval, and known limitations. |
| M49-N | Independent review confirms no authority inflation or status overclaim; a separate architecture decision is required for any new authority. |

## 8. Stop conditions

Stop as `blocked` and do not implement if:

- no existing owner is evidenced;
- a candidate owns only one store or only path/UI state;
- EventLedger append-only semantics would be violated;
- HandoffRecoveryJournal would be repurposed as a startup selector;
- browser session state would become a memory/audit authority;
- a new pointer database, coordinator, ledger, backup service, or shadow authority is proposed without a separate decision;
- planned WISP/M5/M45/M2 scope is pulled into the current participant set;
- ownership is inferred from a plan, test helper, singleton, closure, or successful API call;
- raw content, secrets, private data, or arbitrary paths enter the audit record;
- browser-first, private, offline, locked, denied, accessibility, or manual fallback is weakened;
- source conflicts remain unresolved;
- fixtures, mocks, source presence, or plan validation are treated as runtime proof.

## 9. Explicit deferrals and honest limits

M49 does not implement or verify:

- Swift runtime changes, M0 execution, M47 implementation, M48 activation, or M45 capture;
- WISP candidate/M5 lifecycle participants, M2 import/Brief, browser credibility, models, training, research, MCP, sync, connectors, or OS automation;
- any new pointer database, coordinator, ledger, backup service, or authority;
- filesystem crash consistency, power-loss durability, cryptographic/forensic deletion, disaster-recovery RPO/RTO, compliance, production readiness, or ship readiness;
- distributed transactions, exactly-once effects, or universal rollback.

**M49 is complete as a documentation-only block decision when its candidate audit, complete ownership rubric, formal block/unblock contract, 24 evidence mappings, 14 gates, redaction/privacy boundary, and separate-architecture escalation rule are structurally validated and independently reviewed.**

## 10. Primary references and claim limits

- [SQLite Online Backup API](https://www.sqlite.org/backup.html) — backup lifecycle does not assign application ownership.
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html) — handle/statement lifecycle boundaries.
- [SQLite WAL](https://www.sqlite.org/wal.html) — concurrency and checkpoint limits.
- [SQLite transactions](https://www.sqlite.org/lang_transaction.html) — writer and transaction semantics.
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox) — container access boundary, not semantic authority.
- [Apple Application Support guidance](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/WhereToPutFiles/WhereToPutFiles.html) — persistent app-data placement.
- [Apple FileManager replacement](https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:)) — replacement API does not assign ownership or prove power-loss durability.
- [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) — actor isolation does not choose product authority.

These references establish platform/library boundaries. M49’s owner rubric, candidate dispositions, blocked status, unblock packet, browser fallback, fixture matrix, and evidence gates are Hive-specific contracts. They do not claim that planning evidence is runtime verification.
