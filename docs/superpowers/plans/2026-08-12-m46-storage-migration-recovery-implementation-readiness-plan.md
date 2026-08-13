# M46 — Storage, Migration, Backup & Recovery Implementation Readiness

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M46 Storage, Migration, Backup & Recovery Implementation Readiness
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m45-explicit-capture-implementation-readiness-plan.md`
> **Product dependency:** `docs/superpowers/plans/2026-08-11-m0-storage-migration-recovery-spec.md`
> **Primary code seams:** `Sources/HiveCore/Honeycomb/HoneycombStore.swift`, `Sources/HiveCore/EventLedger/EventLedgerStore.swift`, `Sources/HiveCore/AI/Search/HandoffRecoveryJournal.swift`, `Sources/Hive/Browser/BrowserSessionStore.swift` or its current owner, `Sources/Hive/BrowserState.swift`, `Tests/HiveCoreTests/PersistenceHealthTests.swift`, `Tests/HiveCoreTests/MemoryLifecycleTests.swift`, and the current Honeycomb/EventLedger/persistence test suites
> **Dependencies:** M0 contract, existing Honeycomb/EventLedger/HotMemory authorities, M44 evidence identity, M45 explicit-capture handoff
> **Research anchors:** SQLite transactions/WAL/foreign keys/PRAGMA `user_version`/`quick_check`/`integrity_check`/Online Backup API; Apple Application Support/App Sandbox/file replacement; Swift actor isolation and cooperative cancellation; existing HandoffRecoveryJournal/session-backup patterns
> **Non-dependencies:** model training, WISP/ambient capture, import, Brief generation, vectors, MCP, sync, connectors, OS automation, new databases, remote services, compliance certification, and release actions
>
> M46 is the bounded documentation handoff required before M45 can become runtime work. It does not claim that storage is healthy, backed up, recoverable, or production-ready; `handoff-ready` is not implemented or verified. It turns the existing M0 contract and current code seams into an owner-contained implementation/evidence boundary.

## 0. Decision summary

M0 storage/migration/recovery readiness is the correct next planning slice because M45 explicitly depends on it, and because a durable capture cannot honestly promise persistence, retry, deletion, or recovery while migration rollback, integrity checks, backup validation, and corruption behavior remain unproven.

| Candidate next slice | Why it is not first | M46 decision |
|---|---|---|
| **M0 storage/migration/recovery readiness** | Direct dependency of M45; existing SQLite owners and recovery patterns exist but are not unified or fully evidenced | **Selected** |
| M45 capture runtime | Depends on M0 capture-attempt schema, recovery, and persistence truth | Keep handoff-ready; do not implement yet |
| M2 import/Brief | Adds more writes and report state before storage failure semantics are proven | Defer |
| M15 browser credibility | Broad browser surface and not the direct blocker for memory persistence | Continue as separate roadmap work |
| New model/runtime work | Irrelevant to storage trust and would increase resource/privacy scope | Explicitly excluded |

M46 covers five work packages:

```text
A authority/source reconciliation
  → B connection, migration, and integrity contract
    → C snapshot/restore and corruption quarantine boundary
      → D cross-store crash recovery and browser-first degradation
        → E bounded implementation handoff and evidence decision
```

M46 adds no new database, migration authority, storage epoch authority, recovery journal, ledger, telemetry system, remote backup service, or governance layer. It does not make Honeycomb and EventLedger a distributed transaction. Existing owners remain canonical:

- Honeycomb owns knowledge nodes, edges, revisions, FTS, and logical deletion.
- EventLedger owns append-only consequential evidence.
- `HandoffRecoveryJournal` owns the existing redacted repair-gap record where its current contract applies.
- Browser session persistence owns browser-session snapshots, separate from knowledge/audit stores.
- M0’s future coordinator is a proposed owner contract to be implemented only through the existing storage boundary; M46 itself does not create it.

## 1. Current implementation truth

The current storage surface is **code-present, not M0-verified**.

### 1.1 Existing foundations

- `HoneycombStore` and `EventLedgerStore` are actor-isolated system-SQLite stores.
- Both request WAL and foreign-key enforcement at open and read `PRAGMA user_version` for migrations.
- Honeycomb has schema versions 1–2, typed nodes/edges/revisions, FTS5, deduplication, transactional node update/revision/FTS replacement, deletion, export, and persistence-health behavior.
- EventLedger has schema v1, append-only events, query indexes, retention deletion, and idempotent `recordIfAbsent`.
- `HandoffRecoveryJournal` already uses redacted recovery records and `BEGIN IMMEDIATE` patterns for selected cross-store gaps.
- Browser session persistence has a rolling previous snapshot, corruption/quarantine outcomes, and explicit restored/corrupt states; this is a reusable vocabulary, not proof that SQLite stores share the same recovery implementation.

### 1.2 Unverified or incomplete M0 foundations

- Every pragma is requested, but current code does not yet expose one typed, evidence-bearing result for pragma failure, actual journal mode, foreign-key state, busy behavior, and synchronous policy.
- Migration behavior is versioned, but one shared failure-injection harness does not yet prove rollback and `user_version` behavior for every store/version.
- There is no single current contract for routine `quick_check` versus deep `integrity_check` or FTS consistency/rebuild.
- There is no verified SQLite Online Backup API snapshot/restore path for the active databases.
- There is no verified corruption quarantine ladder that refuses silent empty-store replacement.
- Honeycomb and EventLedger have no atomically synchronized snapshot identity; a pair of independent database copies is not automatically a logically consistent restore point.
- M45’s `honeycomb_capture_attempts` schema and recovery identity remain dependent on this boundary.
- Existing tests prove primitives, but source presence, in-memory tests, session backups, or a green documentation check are not M0 runtime evidence.

These are **planned/blocked** until a future owner produces fresh evidence. M46 does not reclassify them.

## 2. M46-A — Authority and source reconciliation

Before implementation, the owner must audit the actual checkout and bind each operation to its current owner:

1. Confirm exact Honeycomb/EventLedger initializers, migration functions, connection lifecycle, actor isolation, and close behavior.
2. Confirm the actual current test filenames and suites; do not assume names from stale plans.
3. Confirm which code owns `HandoffRecoveryJournal`, browser session persistence, persistence-health flags, and user-visible recovery state.
4. Confirm whether the M0 `honeycomb_capture_attempts` schema exists. If absent, M45’s capture-attempt-dependent runtime work remains blocked.
5. Confirm whether any other SQLite store has joined the M0 participant set. M46 must not silently expand the set from current code or planned documents.
6. Confirm database path policy: Application Support/container storage, `:memory:` test stores, user-selected export locations, and security-scoped boundaries.
7. Record source revision, environment, evidence scope, observed status, owner, and limitation for every reconciliation item.

If two sources disagree, preserve `unresolved`/`blocked` and route the conflict to the owning implementation decision. M46 cannot become a second source of truth.

## 3. M46-B — Connection, migration, and integrity contract

The future implementation owner must make each opened durable SQLite connection observable and fail closed where required.

### 3.1 Open sequence

```text
open explicit read/write connection
  → configure connection-local pragmas
  → verify journal/foreign-key/synchronous/busy policy
  → read user_version
  → run sequential migration transaction(s)
  → verify required schema and FTS objects
  → routine quick_check
  → publish typed healthy/degraded/recovering/blocked state
```

Required rules:

- `PRAGMA foreign_keys = ON` is configured and verified per connection; it is not treated as a process-global setting.
- WAL is requested only for file-backed stores and the actual returned journal mode is recorded. WAL means concurrent readers with a single writer; it is not multi-writer concurrency and does not make separate stores atomic.
- Busy/locked behavior is bounded and typed. A timeout or busy policy is documented and tested; `SQLITE_BUSY` is not silently converted into a cache miss or empty database.
- Synchronous policy is explicit and evidenced; M46 does not assume a durability level from WAL alone.
- Routine `quick_check` and deeper `integrity_check` are distinct operations with distinct cost and user-facing implications.
- Required tables, indexes, foreign keys, and FTS objects are checked after migration before the store can publish `healthy`.
- Diagnostics contain store name, schema version, journal mode, FK state, check result, recovery state, snapshot ID, and redacted error class—not raw page text, credentials, cookies, prompts, or arbitrary paths.

### 3.2 Migration transaction

Every migration is sequential and named:

```text
migrate(N → N+1)
  BEGIN IMMEDIATE or documented equivalent
  schema DDL
  data transform
  invariant/FTS checks
  set PRAGMA user_version = N+1
  COMMIT
```

The future runtime must prove:

- `user_version` advances only after the complete migration commits;
- an error before commit leaves the prior schema/data/version intact;
- retrying a failed migration is deterministic and does not duplicate rows/indexes;
- unsupported future versions block without downgrade or destructive reset;
- migrations do not depend on models, network, current page, user input, or privileged OS access;
- cancellation is checked between bounded migration/verification steps and never leaves the database reported healthy without final checks.

SQLite DDL transaction behavior and supported macOS SQLite capabilities must be tested against the actual runtime SQLite library, not only a different development installation.

### 3.3 FTS authority

FTS is a rebuildable index, never the source of truth:

- Honeycomb node rows remain authoritative.
- A missing/mismatched FTS row is detected and reported.
- Rebuild derives only from eligible node rows and preserves node identity/provenance.
- An FTS failure blocks search-dependent memory features but does not shut down navigation, tabs, private browsing, or ordinary rendering.
- An empty FTS index is never interpreted as an empty Honeycomb database.

## 4. M46-C — Snapshot, restore, and corruption quarantine

M46 defines a bounded local recovery contract, not a cloud backup product.

### 4.1 Snapshot identity and consistency limits

Honeycomb and EventLedger remain separate SQLite authorities and are not a distributed transaction. A future snapshot coordinator may establish a short logical write barrier/epoch, flush admitted operations, capture both stores, and bind their manifest to schema versions, diagnostic states, and last committed IDs. That proves a coordinated snapshot boundary, not atomic cross-store commit.

A snapshot manifest must include:

```text
snapshot_id
snapshot_epoch
created_at
honeycomb_snapshot_identity
ledger_snapshot_identity
schema_versions
health_diagnostics
last_committed_context_ids
manifest_hash
logical_consistency: verified | requires_reconciliation
```

If either store cannot be captured, fails integrity checks, has unresolved pending recovery work, or cannot bind its identity to the epoch, the manifest is `requires_reconciliation` and automatic restore is forbidden.

### 4.2 Snapshot mechanism

Prefer SQLite’s Online Backup API for active databases. The future implementation must validate the completed staging database before activation. A raw copy of only the main `.sqlite3` file is not an accepted default in WAL mode because WAL/SHM sidecars can contain required state.

If a closed-file copy is ever used, the owner must prove the database is closed, define WAL checkpoint/sidecar handling, validate the copy, and record the limitation. M46 does not call an unvalidated file copy transactional or crash-consistent.

### 4.3 Restore ladder

```text
healthy
  → read-only diagnose
  → stage latest verified local snapshot
  → schema/version/FK/FTS/integrity validation
  → cross-store identity/recovery reconciliation
  → explicit activation decision
  → atomic reference replacement
  → reopen/startup checks
  → healthy | recovering | degraded | blocked
```

Restore never overwrites the only active database. Before activation, the owner creates a pre-restore snapshot when the current stores are readable, preserves the original corrupt/unhealthy files, validates staging, and records the activation result. A partial restore is not a successful full restore.

### 4.4 Deletion generations and tombstones

Restore must not resurrect a user deletion from an older snapshot. M46 binds this contract to existing owners rather than inventing a new authority:

- **HoneycombStore owns logical deletion materialization.** The M0 migration must add a Honeycomb-owned deletion-tombstone/revision table or equivalent schema extension in the same Honeycomb database, with a monotonic store-local `deletion_generation`, exact node/edge/attempt identity, deletion scope, deletion timestamp, and the owning deletion-event ID. This is an extension of Honeycomb’s existing logical-deletion authority, not a second database.
- **EventLedgerStore owns append-only deletion evidence.** The existing delete-intent/delete-complete evidence chain records the same generation, scope, target identity, and tombstone reference; EventLedger does not become mutable deletion state and Honeycomb does not rewrite ledger history.
- **HotMemory/FTS are derived projections.** They must remove or suppress deleted identities after the Honeycomb tombstone is committed and must never recreate them from an older snapshot.

Before a snapshot is eligible for restore, every logical deletion is bound to the next monotonic Honeycomb deletion generation, exact scope, node/edge/attempt identity, and durable EventLedger reference. During restore, the owner MUST compare the snapshot’s tombstone/deletion generations against the newest available active Honeycomb tombstones and EventLedger deletion evidence, reapply every newer deletion before activation, and preserve the higher generation on conflicts. The owner MUST never treat absence from an old snapshot as proof that a later deletion did not happen, and MUST NOT resolve a deletion conflict by wall-clock timestamp alone. If the active deletion evidence is unavailable, inconsistent, or cannot be matched to the snapshot identity, restore is `requires_reconciliation`/`blocked` and cannot publish `healthy` or `verified`.

After reconciliation, deleted nodes/edges/attempts are absent from FTS, HotMemory, default retrieval, export, and user-visible Knowledge projections according to the existing Honeycomb deletion contract. A deletion remains effective across restart, restore, retry, and partial cross-store recovery. Ordinary browsing may continue while affected memory remains blocked.

### 4.5 Corruption states

The product must distinguish:

- **Healthy:** required startup checks pass.
- **Recovering:** a verified snapshot or staged salvage is being evaluated; writes requiring the affected store are paused.
- **Partially recovered:** a bounded subset is restored, with missing/ambiguous records visible and affected features disabled.
- **Needs attention:** no verified snapshot or integrity result is available; browser use remains available while affected memory writes are paused.
- **Ephemeral fallback:** never automatic after corruption/migration failure; available only through an explicit recovery choice, clearly session-only, with durable capture/import/audit actions disabled.
- **Blocked:** unsupported schema, failed activation, unresolved integrity, or unsafe path/permission state prevents the store from opening.

Never initialize a new empty durable store over an unreadable or corrupt database. “No memories” and “memory store unavailable” are different states.

## 5. M46-D — Cross-store crash recovery and browser-first degradation

M46 consumes the existing `HandoffRecoveryJournal` pattern rather than creating a new repair ledger.

### 5.1 Durable operation sequence

```text
validate typed operation/scope
  → append redacted recovery record
  → Honeycomb write or reuse
  → EventLedger recordIfAbsent with resolved context ID
  → mark capture attempt/recovery complete
  → remove recovery record only after both durable results are confirmed
```

For M45 capture attempts, the exact identity comes from the M45 contract: UUID v4 generated once at the user-action boundary, persisted before side effects, and event ID `capture/<attemptID>/v1`. M46 must preserve these identifiers during restart/recovery and must never replay consent or generate a new event for the same attempt.

Required partial matrix:

| Honeycomb | EventLedger | Result | Recovery |
|---|---|---|---|
| absent | absent | not started | release only after absence is proven |
| present | absent | partial | retry `recordIfAbsent` with resolved node ID |
| absent | present | inconsistent | quarantine event; never invent node |
| present | present | operation-complete | clear recovery record after identity checks |
| unknown/corrupt | any | ambiguous | preserve records; stop replay; enter recovery |

### 5.2 Browser-first degradation

When storage is blocked, recovering, or unavailable:

- navigation, tabs, tab switching, private browsing, ordinary page rendering, and zero-history start remain usable;
- durable capture, audit, import reports, brief saves, and deletion operations are disabled or labeled according to the affected owner;
- no in-memory write is presented as durable success;
- the UI provides bounded text status and a retry/recovery path where safe;
- diagnostics remain redacted and local;
- accessibility, keyboard, reduced-motion, offline, locked, denied, and manual fallback states remain understandable;
- no model, network, or remote service is required to render the browser fallback.

## 6. Deterministic fixture and evidence matrix

All fixtures are synthetic, local, bounded, and contain no real browsing history, credentials, private URLs, page prose, screenshots, raw prompts, or secret paths. Fixture definitions are not results. Each observed result binds `trace_id`, `source_revision`, `environment`, `evidence_scope`, `evidence_kind`, owner, timestamp, limitation, and exact output.

### 6.1 Twenty-four M46 fixtures

| IDs | Fixture family | Required assertion |
|---|---|---|
| M46-01–04 | open/diagnostics | healthy file-backed open, `:memory:` test open, FK/journal verification, and bounded busy/locked status are explicit |
| M46-05–08 | migration rollback | fresh migration, failure before commit, failure after DDL, and unsupported future version preserve the prior state or block safely |
| M46-09–12 | integrity/FTS | quick check success/failure, deep integrity failure, missing FTS row, and successful rebuild preserve node authority |
| M46-13–16 | snapshot/backup | active Online Backup snapshot, interrupted backup, manifest mismatch, and WAL/sidecar limitation reject unsafe activation |
| M46-17–20 | restore/quarantine/deletion | pre-restore preservation, corrupt-file quarantine, partial restore, explicit ephemeral-choice boundary, and Honeycomb tombstone/EventLedger deletion-evidence continuity avoid silent empty reset; a deletion after snapshot is not resurrected during restore |
| M46-21–24 | cross-store/browser fallback | Honeycomb-only partial, ledger-only inconsistency, restart recovery identity, and blocked-storage browser fallback preserve truth and ordinary browsing |

### 6.2 Evidence requirements

- **Migration evidence:** actual runtime SQLite version, source revision, environment, schema versions, injected failure, `user_version`, row/index/FTS state, and rollback result.
- **Snapshot evidence:** snapshot/epoch IDs, store identities, schema versions, health checks, manifest hash, WAL handling, activation decision, and limitations.
- **Recovery evidence:** original/quarantine/staging identity without raw filesystem paths in user-visible diagnostics, reconciliation result, affected feature scope, and browser fallback.
- **Negative evidence:** corruption, unsupported schema, private/locked/denied, and blocked-store paths prove absence of false durable success and absence of silent replacement.
- **Runtime evidence:** clean non-private profile, exact startup/failure/recovery path, source revision, environment, evidence scope, observed user-visible state, and accessibility/manual observations.

## 7. Fourteen M46 exit gates

| Gate | Requirement |
|---|---|
| M46-A | Actual SQLite owners, test suites, database paths, and M0 participants are reconciled without expanding authority by plan text. |
| M46-B | Every durable connection reports verified journal/FK/synchronous/busy policy and typed diagnostics. |
| M46-C | Sequential migrations atomically bind schema/data/invariant checks to `user_version`; failure preserves the prior version. |
| M46-D | Unsupported future versions block without downgrade, reset, or silent ephemeral replacement. |
| M46-E | Routine quick checks and deeper integrity checks are distinct, bounded, and user-state truthful. |
| M46-F | FTS mismatch is detected and rebuildable from Honeycomb node authority without changing provenance. |
| M46-G | Active database snapshots use a validated mechanism; raw main-file copy is not treated as sufficient WAL backup. |
| M46-H | Snapshot manifests bind store identities, schema versions, health, epoch, hashes, and logical-consistency limits; unresolved snapshots cannot auto-restore. |
| M46-I | Restore stages and validates before activation, preserves the only active copy, quarantines corrupt originals, and merges newer Honeycomb deletion tombstones plus matching EventLedger evidence before activation so an older snapshot cannot resurrect deleted nodes, edges, attempts, or audit effects. |
| M46-J | Cross-store partial operations preserve exact attempt/node/event IDs and reconcile idempotently through existing authorities. |
| M46-K | Corruption/migration/open failures never silently initialize an empty durable store; ephemeral fallback is explicit and session-only. |
| M46-L | Navigation, tabs, private mode, ordinary rendering, keyboard, accessibility, offline, locked, denied, and reduced-motion fallbacks remain usable. |
| M46-M | Twenty-four synthetic fixtures and evidence records bind revision, environment, scope, result, limitation, and owner; fixtures are not runtime proof. |
| M46-N | A future owner’s fresh build/test/user-observable runtime evidence passes all relevant gates before M0 or M45 is labeled `verified`. |

M46 itself is only a documentation handoff. It is not storage implementation, backup certification, disaster-recovery assurance, cryptographic erasure, compliance certification, accessibility conformance, production readiness, or a ship decision.

## 8. Bounded implementation handoff

After approval, the future owner may implement only this order:

1. Reconcile current source/test paths and freeze the actual participant list.
2. Add typed diagnostics and failure-injection seams without changing ordinary browser behavior.
3. Add migration rollback/future-version/pragma/integrity/FTS fixtures.
4. Add validated active-database snapshot staging and manifest checks using the existing owner boundary.
5. Add restore staging, quarantine, activation, and recovery states; never silently replace the only database.
6. Thread M45 capture-attempt identity through the existing recovery journal and EventLedger `recordIfAbsent` path.
7. Add browser-visible degraded/recovering/blocked states with accessible/manual fallbacks.
8. Run focused storage tests, then the full build/test suite and clean-profile runtime evidence.
9. Update capability labels only from fresh evidence bound to one source revision, environment, and evidence scope plus explicit owner approval.

### Preconditions

- Current source and test inventory is re-audited.
- The actual system SQLite runtime is identified.
- Application Support/container path policy is known.
- M45 remains unimplemented or blocked until its M0 dependencies pass.
- Synthetic failure injection is available without killing the developer machine or mutating production data.

### Stop conditions

Stop as `blocked` or `unavailable` when:

- a migration advances `user_version` before commit;
- a pragma/health check is assumed rather than verified;
- an unsafe main-file copy is treated as a complete WAL snapshot;
- an unreadable database is replaced with a new empty store;
- a partial cross-store restore is presented as complete;
- recovery generates a new attempt/event identity or replays consent;
- diagnostics contain raw page text, secrets, credentials, arbitrary paths, or private content;
- browser navigation/tabs/private mode/ordinary rendering are disabled by storage failure;
- fixtures, mocks, source presence, or a green document check are being used as runtime proof;
- a new backup service, ledger, store, or authority is introduced.

## 9. Explicit deferrals

- Runtime implementation and all Swift changes.
- M45 capture runtime until M0 gates pass.
- Ambient/WISP capture, screenshots, OCR, page-body extraction, vectors, research, import, Brief, model routing, and training.
- Cloud backup, sync, remote recovery, SQLCipher, connectors, OS automation, and external telemetry.
- Cryptographic/forensic deletion claims and legal/compliance certification. M46 does require logical deletion-generation continuity and non-resurrection across restore; it does not claim physical erasure.

**M46 is complete as a planning handoff only when its five work packages, 24 fixture mappings, 14 gates, canonical ownership, evidence identity, corruption/recovery boundaries, and browser-first fallback are structurally validated.**