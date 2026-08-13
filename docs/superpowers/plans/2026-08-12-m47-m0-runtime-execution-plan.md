# Hive M47 — M0 Storage Runtime Execution & Evidence Plan

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M47 M0 Storage Runtime Execution & Evidence
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Product contract:** `docs/superpowers/plans/2026-08-11-m0-storage-migration-recovery-spec.md`
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m46-storage-migration-recovery-implementation-readiness-plan.md`
> **Next consumer:** `docs/superpowers/plans/2026-08-12-m45-explicit-capture-implementation-readiness-plan.md`
> **Primary code seams:** `Sources/HiveCore/Honeycomb/HoneycombStore.swift`, `Sources/HiveCore/EventLedger/EventLedgerStore.swift`, `Sources/HiveCore/AI/Search/HandoffRecoveryJournal.swift`, the current browser persistence/recovery owner, and the matching HiveCore test suites
> **Research anchors:** SQLite Online Backup API, transactions/WAL/foreign keys/`user_version`/`quick_check`/`integrity_check`/`foreign_key_check`, Apple Application Support/App Sandbox/file replacement, Swift actors and cooperative cancellation
> **Non-dependencies:** M45 capture runtime, M2 import/Brief, ambient capture, page-body extraction, vectors, model routing/training, sync, connectors, OS automation, new databases, remote services, compliance certification, and release work
>
> M47 converts the M0/M46 contract into a bounded implementation sequence and evidence harness. It does not implement storage, claim that storage is healthy, or authorize M45 runtime work. Its active-set owner language is provisional and is superseded by M49’s explicit `no_existing_owner_evidenced` block until an approved owner packet exists. `handoff-ready` remains a planning label, not an implementation or verification result.

## 0. Decision summary

M47 is the smallest safe next planning boundary. M46 established the storage invariants and recovery gates; M47 now names the exact runtime seams, failure-injection contracts, fixture-to-test mapping, and evidence required before any M0 Swift implementation can begin. M45 remains blocked until the relevant M0 gates have fresh runtime evidence.

| Candidate | Why not selected now | M47 decision |
|---|---|---|
| **Bounded M0 runtime execution** | Direct prerequisite for M45; current SQLite owners exist but pragma, migration, backup, and recovery outcomes are not uniformly observable | **Selected** |
| M45 explicit-capture runtime | Would add durable writes before rollback, backup, deletion continuity, and browser fallback are proven | Defer behind M0 |
| M2 import/Brief | Bulk writes and report persistence increase failure surface before the storage boundary is real | Defer |
| M15 browser credibility | Important parallel product work, but not the smallest dependency-unblocking slice | Separate roadmap work |
| Broad storage coordinator redesign | Would expand authority and implementation scope before the existing stores have typed seams | Explicitly rejected for M47 |

M47 preserves the M0 order:

```text
A source/owner freeze
  → B typed connection diagnostics
    → C migration and integrity harness
      → D snapshot, restore, and quarantine harness
        → E cross-store recovery and deletion continuity
          → F browser-first evidence and handoff decision
```

M47 introduces no second database, backup service, ledger, migration authority, storage epoch authority, repair journal, telemetry system, or policy engine. The current runtime slice is limited to the active Honeycomb and EventLedger stores. The planned WISP candidate and M5 lifecycle stores named by the broader M0 contract are **not runtime participants in M47**; their M0 gates remain `blocked`/deferred until each store is implemented, registered in M0, and covered by the same manifest, recovery, deletion, and evidence contract. M0 and M45 cannot be labeled `verified` from the two-store M47 slice while those planned participants remain unresolved; the two-store result cannot promote the broader M0 participant contract. Existing owners remain canonical:

- Honeycomb owns knowledge nodes, edges, revisions, FTS, and logical deletion tombstones introduced by the M0 migration.
- EventLedger owns append-only consequential evidence, including deletion evidence.
- `HandoffRecoveryJournal` owns the existing redacted repair-gap records where its current contract applies.
- Browser persistence owns browser-session snapshots and browser recovery presentation.
- Any future cross-store barrier must be implemented through these owners and must not become a parallel source of truth.

## 1. Implementation truth and preflight

The current stores are **code-present, not M0-verified**.

The live audit found:

- `HoneycombStore` and `EventLedgerStore` open system SQLite connections and request WAL and foreign keys, but their current open paths do not publish typed evidence for the actual journal mode, foreign-key state, synchronous mode, busy policy, or pragma failures.
- Both stores read `PRAGMA user_version` and contain versioned migration code, but they do not yet share a failure-injection harness proving that schema/data/version changes roll back together for every supported version.
- Honeycomb owns FTS as a derived table, but no single runtime contract yet exposes quick-check, deep integrity, foreign-key check, FTS consistency, and rebuild results as a typed health state.
- `HandoffRecoveryJournal` already demonstrates stronger bounded behavior, including WAL, full synchronous mode, busy timeout, explicit migration transactions, and redacted repair records; M47 reuses its authority and vocabulary rather than creating another journal.
- No verified SQLite Online Backup API snapshot/restore path is established for the active Honeycomb and EventLedger databases.
- Browser session backup/quarantine behavior is a related fallback pattern, not proof of the memory stores’ SQLite recovery behavior.

These observations are planning evidence only. They do not reclassify any feature as `verified`.

### 1.1 Mandatory preflight before code edits

The future implementation owner must, in the current checkout:

1. Run `git status --short` and preserve all unrelated work.
2. Read repository instructions and the current M0/M45/M46 plans.
3. Confirm exact source paths, initializers, actor ownership, deinitialization/close behavior, migration versions, and test suites.
4. Identify the actual macOS system SQLite version and compile/runtime feature availability used by the target.
5. Confirm Application Support/container path policy and all `:memory:` test-store behavior.
6. Confirm the active browser persistence/recovery owner and the user-visible fallback seam.
7. Confirm the M0 participant list is only the stores already present in code plus the explicitly planned participant contracts; do not register a new runtime store during M47.
8. Record `source_revision`, `environment`, `evidence_scope`, observed status, limitation, and owner for the preflight.

If source and plan disagree, preserve `blocked`/`unresolved`, update the plan evidence, and do not resolve the disagreement by assuming the plan is newer.

## 2. M47-A — Source and authority freeze

Before changing runtime code, create an owner map from actual symbols, not filenames alone.

| Concern | Required owner check | Forbidden M47 shortcut |
|---|---|---|
| Connection open/close | Current store actor and SQLite handle lifecycle | A process-global SQLite singleton |
| Migration | The store that owns its schema and `user_version` | A generic migration database or external schema authority |
| FTS | Honeycomb node rows as authority; FTS as derived index | Treating an empty FTS table as an empty store |
| Audit evidence | EventLedger append-only APIs | A second mutable capture/audit ledger |
| Repair gaps | Existing `HandoffRecoveryJournal` | New recovery journal or unlogged retry queue |
| Browser fallback | Current browser state/persistence owner | Making storage failure disable navigation or private mode |
| Logical deletion | Honeycomb tombstone/revision extension plus EventLedger evidence | Restoring from old snapshots by timestamp or absence |

The source freeze must also identify every current direct writer. Any writer that bypasses the future typed storage boundary becomes an implementation blocker and a negative architecture fixture; it must not be silently left outside the contract.

**M47-A exit evidence:** a checked-in owner/source inventory, actual participant list, current schema-version table, current SQLite/runtime environment record, and a list of unresolved source conflicts. This is not runtime proof of health.

## 3. M47-B — Typed connection diagnostics and fail-closed open

Implement only within existing store boundaries. The exact type names may follow local conventions, but the semantics are fixed:

```text
StorageDiagnostics {
  store
  schemaVersion
  journalMode
  foreignKeysEnabled
  synchronousMode
  busyPolicy
  quickCheck
  foreignKeyCheck
  integrityState
  ftsState
  recoveryState
  snapshotID?
}
```

The open sequence is:

```text
open explicit connection
  → configure connection-local policy
  → verify actual journal mode, FK state, synchronous mode, and busy policy
  → read user_version
  → migrate sequentially
  → verify required schema/FTS objects
  → run bounded quick_check + foreign_key_check
  → publish typed healthy/degraded/recovering/blocked state
```

Required runtime rules:

- `PRAGMA foreign_keys=ON` is set and read back on every new connection; a failed or disabled result cannot support cascade claims.
- WAL is requested only where appropriate for a file-backed local store; the returned journal mode is recorded. WAL is single-writer concurrency, not multi-writer atomicity and not cross-store atomicity.
- Synchronous policy is explicit and observable. M47 must not infer durability from WAL.
- Busy handling is bounded and typed. `SQLITE_BUSY`/`SQLITE_LOCKED` is never converted into an empty store, cache miss, or durable success.
- Routine `quick_check` and `foreign_key_check` remain bounded startup/health operations; deep `integrity_check` is a separately invoked recovery/maintenance operation.
- Diagnostics redact raw database content, page text, secrets, cookies, credentials, prompts, and arbitrary filesystem paths.
- Cancellation is checked between bounded migration/check/backup steps and cannot publish `healthy` before final checks complete.

**M47-B exit evidence:** connection-level tests for file-backed and `:memory:` stores, pragma failure injection, actual returned values, busy/locked classification, redaction, and state publication. No test may pass solely because a requested pragma string was executed.

## 4. M47-C — Transactional migration and integrity/FTS harness

### 4.1 Migration algorithm

Each store retains schema ownership and uses named sequential migrations:

```text
migrate(N → N+1)
  BEGIN IMMEDIATE or documented equivalent
  DDL/data transformation
  required-schema and invariant checks
  set user_version = N+1
  COMMIT
```

The harness must prove:

- `user_version` advances only after commit;
- failure before/after DDL or during data transformation rolls back schema, data, indexes, FTS, and version together;
- retrying a failed migration is deterministic and idempotent;
- unsupported future versions block without downgrade or reset;
- migration never invokes model, network, page, connector, or OS automation code;
- cancellation cannot leave a store labeled healthy.

M47 does not permit a generic “catch and reopen empty” recovery path.

### 4.2 Integrity and FTS

The future runtime must expose separate results for:

- `quick_check`;
- `foreign_key_check`;
- deep `integrity_check`;
- required schema-object verification;
- Honeycomb FTS consistency and rebuild.

FTS rebuild derives from authoritative Honeycomb rows and preserves node IDs, provenance, deletion state, and eligibility. If FTS is unavailable, search-dependent memory features are blocked or degraded while navigation, tabs, ordinary rendering, and private browsing remain usable.

**M47-C exit evidence:** migration fixtures for every supported store/version; injected DDL/data/check failures; future-version fixture; quick/deep/FK distinction; missing/mismatched FTS fixture; deterministic retry; and proof that no empty replacement occurred.

## 5. M47-D — Snapshot, restore, and quarantine harness

### 5.0 Crash-safe active-set activation

Separate SQLite files cannot be made one distributed transaction by swapping each file independently. M47 therefore requires an explicit active-set protocol for the current Honeycomb/EventLedger pair:

```text
write staged manifest with candidate store identities + hashes
  → fsync manifest and its parent directory where supported
  → close all active store handles
  → atomically publish one active-set pointer/manifest generation
  → reopen stores only from the published active set
  → verify both identities and deletion generations
  → on startup, recover the newest complete active-set generation; quarantine incomplete generations
```

The active-set pointer/manifest is a small activation record for the existing stores, not a new data authority or ledger. **M49 supersedes the provisional owner assumption in this section:** the live source currently evidences no approved existing owner for cross-store active-set selection, so M0 runtime implementation is blocked until an `existing_owner_evidenced(...)` packet is produced and explicitly approved. Only after that approval may an existing storage/recovery owner own the record; M47 itself does not name or create one. The record may contain only selected store identities, a strictly increasing generation, manifest hash, and activation state. Activation is committed only by publishing one complete generation after all handles are closed and the manifest plus parent-directory durability behavior has been exercised on the actual filesystem; the runtime never independently swaps Honeycomb and EventLedger paths. If publication is interrupted, startup selects the newest complete generation whose manifest and store identities validate, retains the prior complete generation when available, and otherwise enters `recovering`/`blocked`; it never chooses a mixed pair or initializes an empty store. Stale/incomplete generations are quarantined or retained for bounded diagnosis according to the explicitly approved owner. This protocol establishes a proposed active-set selection contract, not cross-store atomic commit, semantic authority, crash consistency, power-loss durability, or `verified` behavior.

### 5.1 Snapshot boundary

M47 implements only a bounded local staging contract through existing stores. A snapshot manifest may coordinate store identities and a logical write barrier, but it must state that separate SQLite authorities are not a distributed transaction.

For the current M0 implementation slice, the owner must first support the active Honeycomb and EventLedger stores. A planned WISP candidate or M5 lifecycle participant cannot be silently added to or omitted from a future M0 claim: before it joins, it must be registered in M0 and included in the same active-set manifest, fixture, deletion, recovery, and evidence contract. Until then, its M0 gates remain deferred/blocked.

The manifest must bind:

```text
snapshot_id
snapshot_epoch_or_barrier
created_at
source_revision
store identities
schema versions
health diagnostics
last committed context IDs
manifest hash
logical consistency: verified | requires_reconciliation
```

Any missing, unhealthy, unvalidated, or identity-mismatched participant yields `requires_reconciliation`; automatic restore is forbidden.

### 5.2 Backup mechanism

Prefer SQLite Online Backup API staging (`sqlite3_backup_init`, bounded `sqlite3_backup_step`, `sqlite3_backup_finish`) for active databases. Validate the destination before it is eligible for restore. A raw copy of only the main database file is not accepted as a WAL backup because sidecar state can be required.

If a closed-file copy is ever considered, the owner must prove closure, define WAL/sidecar handling, validate the copy, and record its limits. M47 must not call an unvalidated copy crash-consistent or transactional.

Backup cancellation/interruption must leave incomplete staging ineligible for activation. Backup errors preserve the source and classify the staged artifact, rather than replacing the source with an empty or partial file.

### 5.3 Restore and deletion continuity

The restore sequence is:

```text
stop affected durable writers
  → pre-restore snapshot when readable
  → stage snapshot
  → schema/FK/quick/integrity/FTS checks
  → manifest/identity validation
  → apply newer Honeycomb deletion generations and matching EventLedger evidence
  → explicit activation decision
  → publish one complete active-set pointer/manifest generation
  → reopen/startup checks
```

Honeycomb owns the logical deletion tombstone/revision materialization introduced by the M0 migration, including monotonic store-local deletion generation and exact target/scope identity. EventLedger owns the append-only deletion evidence chain. FTS/HotMemory/retrieval are derived and must suppress deleted identities after tombstone commit.

Before activation, the owner must compare staged tombstone generations with the newest available active deletion evidence and preserve the higher generation. Wall-clock timestamps alone cannot resolve deletion conflicts. If active deletion evidence is unavailable or inconsistent, restore is `requires_reconciliation`/`blocked` and cannot publish `healthy` or `verified`. An older snapshot must never resurrect a later user deletion.

The current active database is never overwritten as the only recovery copy. Original corrupt/unhealthy files remain quarantined. Partial restore is not full success. Ephemeral fallback is explicit and session-only; it is never automatic after corruption or migration failure.

**M47-D exit evidence:** successful and interrupted Online Backup staging, manifest mismatch, WAL/sidecar limitation, corrupt-file quarantine, pre-restore preservation, activation interruption, partial restore, explicit ephemeral-choice boundary, and deletion-after-snapshot non-resurrection fixtures.

## 6. M47-E — Cross-store recovery and browser-first fallback

Use the existing recovery journal and EventLedger idempotency API. For a durable operation:

```text
validate typed operation/scope
  → append redacted recovery record
  → Honeycomb write or reuse
  → EventLedger recordIfAbsent
  → mark attempt/recovery complete
  → clear recovery record only after both identities are confirmed
```

For M45 capture attempts, preserve the UUID v4 generated at user intent, resolved Honeycomb node ID, and `capture/<attemptID>/v1` event identity across restart and retry. Do not replay consent or invent an event ID on retry.

Required state matrix:

| Honeycomb | EventLedger | Result | Recovery |
|---|---|---|---|
| absent | absent | not started | release only after absence is proven |
| present | absent | partial | retry idempotently with resolved node ID |
| absent | present | inconsistent | quarantine event; never invent node |
| present | present | complete | clear journal after identity checks |
| unknown/corrupt | any | ambiguous | stop replay and enter recovery |

Storage failure must preserve browser-first behavior: navigation, tabs, tab switching, private browsing, ordinary rendering, keyboard paths, and zero-history use remain available. Durable capture, audit, import reports, brief saves, and deletion are disabled or clearly classified by affected store. No in-memory result is presented as durable success. Offline, locked, denied, accessibility, reduced-motion, and manual fallback states remain understandable without a model or network.

**M47-E exit evidence:** each matrix row, restart/retry identity preservation, no duplicate ledger event, redacted recovery record, blocked-storage browser path, private/locked/denied/offline paths, and accessibility/manual review.

## 7. M47-F — Evidence, status, and handoff decision

M47 is not complete because fixtures pass. Every runtime claim must bind:

```text
source_revision
environment
platform/runtime SQLite version
evidence_scope
fixture or manual path
trace_id / snapshot_id where applicable
observed result
limitation
owner
```

Required evidence classes:

- **Migration:** actual SQLite version, prior/new schema, injected failure, `user_version`, schema/data/FTS state, and rollback result.
- **Connection:** actual pragma values, busy classification, diagnostics, and redaction result.
- **Backup/restore:** snapshot/barrier IDs, store identity, manifest hash, validation checks, activation state, quarantine state, and known consistency limits.
- **Recovery:** original/staging/quarantine identities, exact Honeycomb/EventLedger IDs, deletion-generation merge result, affected feature scope, and browser fallback.
- **Negative paths:** corrupt, unsupported, private, locked, denied, offline, canceled, and unavailable paths prove no false durable success and no silent empty reset.
- **User-observable runtime:** clean non-private profile, browser-first fallback, accessibility/manual interaction, and honest UI labels.

Status rules:

- Source presence, mocks, fixtures, or plan validation are not `verified`; they remain `planned`/`code-present`.
- `verified` requires fresh build, focused tests, relevant full tests, and user-observable runtime evidence from one identified source revision/environment/scope;
- a two-store M47 result cannot promote the broader four-store/planned-participant M0 contract to `verified`.
- M0 cannot be labeled `verified` until all relevant M0 gates pass; M45 remains blocked until its M0 dependencies pass.
- A failed or missing evidence class is `blocked`, not silently omitted.

## 8. Deterministic M47 fixture map

All fixtures are synthetic, local, bounded, and contain no real history, credentials, private URLs, page prose, screenshots, raw prompts, or secret paths. Fixture definitions are not results.

| IDs | Family | Required assertion |
|---|---|---|
| M47-01–04 | owner/open | current owner inventory, file-backed open, `:memory:` open, pragma/diagnostic failure is explicit |
| M47-05–08 | migration | failure before commit, failure after DDL, data-transform failure, future version blocks safely |
| M47-09–12 | integrity/FTS | quick/FK/deep distinction, integrity failure, missing FTS row, rebuild preserves authority |
| M47-13–16 | backup | Online Backup success, interruption, manifest mismatch, WAL/sidecar limitation rejects activation |
| M47-17–20 | restore/deletion | pre-restore preservation, quarantine, partial restore, post-snapshot deletion cannot be resurrected |
| M47-21–24 | recovery/fallback | M47-21 absent/absent, M47-22 present/absent, M47-23 absent/present, and M47-24 present/present plus an injected unknown/corrupt classification subcase; all preserve restart identity, blocked-storage browser behavior, and accessibility/manual fallback. The unknown/corrupt subcase is recorded separately in the harness, not omitted. |

There are 24 fixture mappings, not 24 runtime results. No fixture may use a green test or mock as a substitute for clean-profile runtime evidence.

## 9. Fourteen M47 gates

| Gate | Requirement |
|---|---|
| M47-A | Actual source owners, participant list, schema versions, test suites, runtime SQLite version, and environment are reconciled. |
| M47-B | Durable connections verify and report actual journal/FK/synchronous/busy behavior; failures are typed and fail closed where required. |
| M47-C | Sequential migration failure preserves schema/data/FTS and prior `user_version`; future versions block without reset. |
| M47-D | Quick check, foreign-key check, deep integrity check, schema verification, and FTS rebuild are distinct and bounded. |
| M47-E | FTS remains derived from Honeycomb authority and failure does not disable ordinary browsing. |
| M47-F | Active database staging uses validated Online Backup behavior or documents and rejects unsafe alternatives. |
| M47-G | Interrupted/incomplete staging cannot activate and the source remains recoverable. |
| M47-H | Manifest binds identity, schema, health, barrier/epoch, hash, and consistency limits; unresolved state blocks auto-restore. |
| M47-I | Restore stages and validates before activation, preserves the only active copy, quarantines corruption, and never silently creates an empty durable store. |
| M47-J | Honeycomb-owned deletion generations and EventLedger deletion evidence prevent non-resurrection across restore/restart. |
| M47-K | Cross-store partial operations preserve exact attempt/node/event identities and reconcile idempotently through existing owners. |
| M47-L | Browser navigation/tabs/private mode/ordinary rendering/keyboard/accessibility/offline/locked/denied/reduced-motion fallbacks remain usable. |
| M47-M | All 24 fixture mappings and evidence records bind source revision, environment, scope, result, limitation, and owner; fixtures are not proof by themselves. |
| M47-N | Fresh build/test and user-observable clean-profile evidence pass all relevant gates before M0 or M45 changes status. |

## 10. Implementation order and stop conditions

After explicit approval to implement, the only permitted order is:

1. Reconcile source owners and freeze the participant list.
2. Add typed connection diagnostics and failure-injection seams without changing ordinary browser behavior.
3. Add transactional migration, future-version, pragma, integrity, FK, and FTS fixtures.
4. Add validated Online Backup staging and manifest validation for the current participants.
5. Add restore staging, quarantine, deletion continuity, activation, and startup states.
6. Wire cross-store recovery to the existing `HandoffRecoveryJournal` and `recordIfAbsent` without new authority.
7. Add browser-visible degraded/recovering/blocked states and accessibility/manual fallbacks.
8. Run focused tests, then full build/test and clean-profile runtime evidence.
9. Update capability labels only from evidence satisfying M47-F and explicit owner approval.

Stop as `blocked` or `unavailable` if:

- a migration advances `user_version` before commit;
- actual pragma behavior is assumed rather than read back;
- a raw main-file copy is treated as a complete WAL snapshot;
- corrupt/unreadable storage is replaced with an empty durable store;
- partial restore is shown as complete;
- deletion continuity cannot be established or an older snapshot can resurrect a deletion;
- recovery invents a new attempt/event identity or replays consent;
- diagnostics contain raw content, secrets, credentials, private data, or arbitrary paths;
- storage failure disables browser-first fallback;
- fixtures, mocks, or source presence are treated as runtime proof;
- a second database, backup service, ledger, recovery journal, migration authority, or policy engine is introduced.

## 11. Explicit deferrals and honest limits

M47 does not implement or verify:

- M0 runtime code, M45 capture, M2 import/Brief, M15 browser feature work, or any other product slice;
- the planned WISP candidate or M5 lifecycle stores; their M0 participation, active-set inclusion, backup/restore, deletion continuity, and evidence gates remain deferred/blocked until separately implemented and registered;
- ambient capture, screenshots, OCR, page-body extraction, vectors, research, MCP, models, or training;
- cloud backup, sync, remote recovery, SQLCipher, connectors, OS automation, or telemetry;
- cryptographic erasure, forensic deletion, legal/compliance certification, disaster-recovery RPO/RTO, or production readiness;
- cross-store distributed transactions. The barrier/manifest is a logical consistency and reconciliation contract only.

**M47 is complete as a documentation-only execution plan when its six work packages, 24 fixture mappings, 14 gates, owner boundaries, evidence identity, deletion non-resurrection rule, browser-first fallback, and stop conditions are structurally validated and independently reviewed.**

## 12. Primary references and claims

- [SQLite transactions](https://www.sqlite.org/lang_transaction.html) — explicit transaction modes and single-writer behavior.
- [SQLite pragmas](https://www.sqlite.org/pragma.html) — `foreign_keys`, `user_version`, `quick_check`, `integrity_check`, `foreign_key_check`, and busy policy.
- [SQLite WAL](https://www.sqlite.org/wal.html) — WAL readers/writer and checkpoint behavior; not cross-store atomicity.
- [SQLite Online Backup API](https://www.sqlite.org/backup.html) — staged backup API for active databases.
- [SQLite backup C API](https://www.sqlite.org/c3ref/backup_finish.html) — lifecycle of backup initialization, stepping, and finish.
- [Apple File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/WhereToPutFiles/WhereToPutFiles.html) — Application Support placement.
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox) — sandbox storage/access boundary.
- [Apple FileManager replacement](https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:)) — Foundation replacement API; exact crash durability remains an implementation/evidence concern.
- [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) — actor isolation and cooperative cancellation model.

These sources establish platform behavior. M47’s typed state vocabulary, fixture matrix, cross-store identity rules, deletion-generation contract, browser copy, and evidence gates are Hive-specific contracts requiring implementation evidence before any capability label changes.
