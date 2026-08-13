# Hive M0 — Storage, Migration, Backup, and Recovery Harness

> **Date:** 2026-08-11
> **Status:** planning canon; no implementation in this document
> **Parent plan:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Primary code:** `Sources/HiveCore/Honeycomb/HoneycombStore.swift`, `Sources/HiveCore/EventLedger/EventLedgerStore.swift`
> **Related code:** `Sources/HiveCore/AI/Search/HandoffRecoveryJournal.swift`, `Sources/HiveCore/AI/Search/RetentionCapability.swift`, `Tests/HiveCoreTests/PersistenceHealthTests.swift`, `Tests/HiveCoreTests/MemoryLifecycleTests.swift`
> **Next participant:** M5's planned `Application Support/Hive/m5-lifecycle.sqlite3` lifecycle store, whose schema and adapters are defined by `docs/superpowers/plans/2026-08-11-m5-digest-promises-forgetting-retention-plan.md` and must be registered here before M5 implementation.
> **Purpose:** Make schema evolution, backup, corruption handling, and degraded browser behavior explicit before adding new memory ingress.

---

## 0. Why M0 exists

Hive's memory layer has two durable SQLite authorities already: Honeycomb stores knowledge objects and EventLedger stores consequential evidence. They are actor-isolated and independently durable, but they are not one distributed transaction. A crash can occur between a Honeycomb write and its ledger event; a migration can fail between schema work and version advancement; a WAL database can be copied incorrectly; and a corrupted store must not silently become a new empty store.

M0 does not add wisps, vectors, new edges, promises, MCP, remote sync, or model training. It establishes the storage behaviors those features are allowed to depend on. The M5 lifecycle store is a planned participant contract only: M0 defines how it joins the coordinator, snapshot, health, migration, and recovery boundary; M5 defines its tables and lifecycle semantics.

### M0 decision

The storage layer must expose a typed health/recovery state rather than only `open succeeded` or `open threw`:

```text
healthy
recovering(snapshot: URL?, quarantined: URL?, reason: RecoveryReason)
degradedEphemeral(reason: DegradedReason)
blocked(reason: StorageFailure)
```

The browser may continue ordinary navigation when memory storage is blocked. It must not claim that a capture, import report, brief save, audit event, or deletion completed durably when the required store is unavailable.

---

## 1. Current audited truth

### 1.1 Honeycomb

`HoneycombStore` currently:

- uses system `SQLite3` behind a Swift actor;
- reports `isEphemeral` for `:memory:` paths;
- requests `PRAGMA journal_mode=WAL` and `PRAGMA foreign_keys=ON` at open;
- reads `PRAGMA user_version` and currently migrates schema versions 1 and 2;
- creates typed node/edge/revision tables and a standalone FTS5 table;
- wraps the v2 legacy-provenance cleanup in a transaction;
- wraps node update + revision + FTS replacement in a transaction;
- has deduplication, deletion, export, and persistence-health coverage.

The following are **not yet M0 contracts**:

- migration DDL and version advancement are not one shared transaction harness across every version;
- pragma execution results are not surfaced as typed startup failures;
- no shared `quick_check`/`integrity_check` health API is established;
- no Online Backup API snapshot/restore contract exists;
- no SQLite corruption quarantine/recovery state exists for Honeycomb;
- FTS consistency is tested through behavior but not through a dedicated rebuild/check fixture;
- `deleteByProvenance` and `deleteOlderThan` use carefully escaped raw SQL for a subquery despite the project invariant preferring parameterized SQL; M0 must resolve or explicitly constrain this exception.

### 1.2 EventLedger

`EventLedgerStore` currently:

- uses system `SQLite3` behind a Swift actor;
- reports `isEphemeral` for `:memory:` paths;
- requests WAL and foreign keys at open;
- has schema version 1 with append-only event rows and query indexes;
- supports idempotent `recordIfAbsent` and retention deletion;
- has broad event/query/consent test coverage.

The following are **not yet M0 contracts**:

- Honeycomb and EventLedger do not share a migration/health/backup abstraction;
- the initial EventLedger migration is not governed by the same failure-injection harness;
- there is no documented integrity-check cadence or recovery state;
- there is no unified snapshot identity tying a Honeycomb backup to an EventLedger backup;
- cross-store recovery relies on higher-level mechanisms such as `HandoffRecoveryJournal`, not a distributed transaction.

### 1.3 Existing recovery patterns to reuse

- `HandoffRecoveryJournal` is an existing durable write-ahead record for gaps between Honeycomb, EventLedger, candidate operations, and lifecycle transitions. It redacts page prose, hashes payloads, uses `BEGIN IMMEDIATE`, and leaves repairable records after a crash.
- Browser session persistence has rolling backup, quarantine of corrupt files, and explicit restored/corrupt outcomes. M0 should use the same user-facing vocabulary for SQLite stores, while using SQLite's Online Backup API for database snapshots.
- `PersistenceHealthTests` proves ephemeral-versus-file-backed disclosure and invalid-path failure. It does not yet prove migration rollback, database corruption, integrity checks, WAL sidecar recovery, or backup restore.

---

## 2. Storage contract

### 2.1 Open sequence

Every durable SQLite store must follow this ordered sequence:

1. Open with an explicit read/write mode and a bounded busy timeout.
2. Configure and verify connection-local pragmas before any schema work:
   - `foreign_keys=ON`;
   - WAL policy for file-backed stores;
   - synchronous policy documented and tested;
   - busy timeout appropriate to the actor's write behavior.
3. Read and validate `user_version`.
4. Run the migration harness.
5. Run a startup health check:
   - `PRAGMA quick_check` for routine startup;
   - full `PRAGMA integrity_check` only on a scheduled/deep path or after a failed quick check.
6. Verify required tables/indexes/FTS objects exist for the resulting version.
7. Publish `healthy` only after all checks pass.

A pragma failure is not cosmetic. The store must either fail closed or enter a typed degraded state; it must not continue while silently assuming foreign-key enforcement or WAL.

### 2.2 Connection-local rules

SQLite connection settings are not global application settings. Every newly opened connection must configure them. WAL allows readers alongside a writer but does not create multi-writer concurrency: there remains one writer at a time.

The store must expose a diagnostic snapshot without secrets:

```text
StorageDiagnostics {
  store: honeycomb | eventLedger | wispCandidates | m5Lifecycle
  schemaVersion: Int
  journalMode: delete | wal | other
  foreignKeysEnabled: Bool
  synchronousMode: Int?
  quickCheck: ok | failed(reason)
  lastIntegrityCheckAt: Date?
  pendingRecoveryRecords: Int
  snapshotID: String?
}
```

No raw filesystem path, database content, URL, credential, or page text belongs in the default diagnostics payload.

### 2.3 Migration transaction contract

Each schema version is a named, sequential migration:

```text
migrate(from: N, to: N+1)
  BEGIN IMMEDIATE or BEGIN TRANSACTION
  schema DDL
  data transformation
  invariant checks
  PRAGMA user_version = N+1
  COMMIT
```

Rules:

- `user_version` advances only after all schema/data/invariant work succeeds.
- Any thrown migration error rolls back the version and all changes from that step.
- A migration must be rerunnable or must fail with a deterministic “already applied” state.
- Unsupported future versions block the store; they must never be downgraded automatically.
- Migration code must not depend on the model, network, browser page, or user interaction.
- Migration logs record version, duration, result, and redacted error class only.
- A migration failure preserves the original database and creates a recoverable startup state.

SQLite's schema DDL is transactional, but the supported SQLite version's specific `ALTER TABLE` capabilities must be respected. The harness must test the actual macOS SQLite version used by Hive, not a different development SQLite.

### 2.4 Capture-attempt audit contract

M0 provides the attempt-level authority consumed by M1. Audit status belongs to a capture attempt, not to the page node: reusing a complete node in a later capture must not let a failed later audit downgrade the node's earlier complete provenance.

The transactional schema migration adds:

```text
honeycomb_capture_attempts(
  attempt_id TEXT PRIMARY KEY,
  node_id TEXT NOT NULL REFERENCES honeycomb_nodes(id) ON DELETE CASCADE,
  event_id TEXT NOT NULL UNIQUE,
  result_kind TEXT NOT NULL,
  audit_status TEXT NOT NULL DEFAULT 'unknown_legacy',
  scope_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  reconciled_at TEXT
)
```

The planned public value is `HoneycombStore.CaptureAttempt: Sendable, Codable, Identifiable` with `attemptID`, `nodeID`, `eventID`, `resultKind`, `auditStatus`, `scope`, `createdAt`, and optional `reconciledAt`. The store exposes insert/update/get methods behind the actor; callers cannot mutate the row outside the store. The pending attempt row and the new-node insert (or reused-node attempt row) commit together before the EventLedger side effect. A recovery-journal record is written before that transaction and includes the same `attemptID`, `nodeID` when known, `eventID`, operation kind, and redacted scope. On restart, reconciliation restores the exact identifiers rather than generating a new attempt.

Allowed `audit_status` values are `unknown_legacy`, `pending`, `complete`, and `incomplete`. The adapter rejects unknown values. The migration creates no fabricated attempt rows for existing nodes; their absent attempt is treated as `unknown_legacy` and is excluded from model retrieval until a deterministic reconciliation pass proves a matching complete ledger event. A duplicate capture creates its own attempt row pointing to the reused node. Its failure affects only that attempt.

The exact event identity rule is:

```text
attempt_id = UUID created once at the beginning of one user invocation
node_id    = Honeycomb's returned new-or-reused ID
payload_version = "capture.v1"
event_id   = "capture/" + attempt_id + "/" + payload_version
```

Retries reuse the same attempt and event ID and call `EventLedgerStore.recordIfAbsent`; a separate user invocation gets a new attempt even when it reuses the same node. The attempt row changes `pending → complete` only after the matching event is durably present. A failed event write changes it to `incomplete`; reconciliation may later set it to `complete` with `reconciled_at`. No retry may alter the immutable event payload after an event exists.

The shared pure admission contract is:

```text
MemoryRetrievalAdmission.evaluate(
  node,
  captureAttempt?,
  admission,
  scope,
  isPrivate,
  isCandidate
) -> allowed | denied(reason)
```

Every model-retrieval path must use it with no bypass exception. Honeycomb model queries return only nodes with an eligible complete capture attempt; HotMemory entries carry the admitted attempt ID/status or perform an authoritative Honeycomb lookup before assembly; PageContextBroker evaluates it before returning a node; and the retrieval-ranker receives only admitted records. A missing/unknown attempt, candidate, private node, out-of-scope node, or pending/incomplete attempt is denied. A failed duplicate attempt never downgrades a previously complete node, but it cannot add a new HotMemory entry. “Trusted durable” describes provenance metadata only; it is not an alternate admission path.

This section is a planned M0 schema/runtime contract, not current code. Its migration, query indexes, deletion cascade, reconciliation behavior, and all four admission paths require tests before M0/M1 verification.

## 2.5 FTS contract

FTS is an index, not the authority. For every migration or restore:

- node rows remain authoritative;
- FTS rows must be rebuildable from node rows;
- a failed FTS rebuild blocks `healthy` only for search-dependent features, not ordinary browsing;
- `rebuild`/`reindex` behavior is versioned and tested;
- no feature may treat an empty FTS table as an empty Honeycomb database.

M0 must include a fixture that intentionally removes or damages FTS rows, detects the mismatch, rebuilds the index, and verifies search results without changing node identity or provenance.

---

## 3. Backup and restore contract

### 3.1 Snapshot unit

A recovery snapshot is a four-store manifest, not one file—and four independent SQLite backups are not automatically one logically synchronized point in time. Hive must create a short coordinator-owned write barrier/epoch around four-store capture. This is a **logical consistency marker, not a distributed transaction**: it bounds new writes and records the reconciliation point, but it cannot make four SQLite files commit atomically.

### 3.1.1 Barrier owner and writer admission

The planned owner is a single process-local `StorageEpochCoordinator` actor. It owns a write-admission gate shared by the Honeycomb adapter, EventLedger adapter, WISP candidate adapter, M5 lifecycle adapter, and `HandoffRecoveryJournal` adapter; no feature writes directly around the coordinator. The M5 lifecycle adapter is the sole authority for PromiseCandidate, LearnedFactProposal, DigestManifest/DigestItem, ApprovalRecord, Reinforcement, PurgeJournal, and PurgeStep rows; those rows must not be duplicated into Honeycomb or EventLedger. The coordinator exposes:

```text
beginEpoch() -> StorageEpoch  admitWrite(store: honeycomb | eventLedger | wispCandidates | m5Lifecycle | recoveryJournal, operation) -> permit
closeAdmissionAndFlush() -> FlushReport
classifyPendingJournalWork() -> [PendingRecoveryClassification]
resumeAdmission(epochID:) -> Void
```

Rules:

- Every durable write path obtains a permit before opening its transaction.
- `closeAdmissionAndFlush()` prevents new permits, waits for admitted operations to finish, and flushes or explicitly classifies every pending recovery-journal record.
- The coordinator records the last committed EventLedger event ID, Honeycomb node/revision marker, WISP candidate revision marker, and M5 lifecycle revision marker only after admitted operations settle.
- Snapshot capture occurs while admission is closed; reads remain allowed.
- Restore and recovery paths use the same gate, and admission resumes only after activation or an explicit recovery state is published.
- A writer that bypasses the coordinator is a test failure and an architecture violation, not a supported fast path.

This actor is a proposed M0 contract, not a current API.

```text
StorageEpoch {
  epochID: UUID
  openedAt: Date
  writesBlocked: Bool
  lastCommittedEventID: String?
  lastCommittedNodeRevision: String?
  lastCommittedCandidateRevision: String?
  lastCommittedM5LifecycleRevision: String?
}

HiveStorageSnapshot {
  snapshotID: UUID
  epochID: UUID
  createdAt: Date
  honeycomb: database snapshot
  eventLedger: database snapshot
  wispCandidates: database snapshot
  m5Lifecycle: database snapshot
  schemaVersions: { honeycomb: Int, eventLedger: Int, wispCandidates: Int, m5Lifecycle: Int }
  sourceHealth: { honeycomb: Diagnostics, eventLedger: Diagnostics, wispCandidates: Diagnostics, m5Lifecycle: Diagnostics }
  manifestHash: SHA256
  logicalConsistency: verified | requires_reconciliation
}
```

The coordinator must stop **all** durable memory/audit/candidate/lifecycle writers that can affect any of the four SQLite stores, flush or explicitly classify pending recovery-journal work, capture Honeycomb, EventLedger, the candidate store, and the M5 lifecycle store under the same epoch, and record the epoch plus last committed IDs in the manifest. Candidate operations use explicit recovery-journal kinds (`candidate_insert`, `candidate_replace`, `candidate_dismiss`, `candidate_promote`, `candidate_nuke`, `candidate_expire`) and carry only redacted IDs/scope metadata; M5 lifecycle operations use their stable lifecycle/purge IDs and step kinds. If the stores cannot be captured under one barrier, or if pending journal work cannot be classified, the result is a diagnostic four-store snapshot marked `requires_reconciliation`, never a complete restore point. A four-store snapshot with any missing or unhealthy participant is not usable for automatic restore. The manifest must state the consistency limit plainly: “coordinated snapshot; cross-store reconciliation still required.”

### 3.2 Snapshot mechanism

Prefer SQLite's Online Backup API (`sqlite3_backup_init`, `sqlite3_backup_step`, `sqlite3_backup_finish`) for active databases. It produces a consistent snapshot while the source remains usable. A raw copy of the main `.sqlite3` file is not the default backup mechanism, especially in WAL mode, because `-wal` and `-shm` sidecars affect the complete state.

If a filesystem copy is ever used for a closed database, the contract must document:

- how the database is confirmed closed;
- how WAL is checkpointed or included;
- how `-wal` and `-shm` are handled;
- how the copy is validated with `quick_check`/`integrity_check` before becoming restorable.

Do not call a raw file copy transactional or crash-consistent without evidence for the exact copy procedure.

### 3.3 Restore safety

Restore is never an in-place overwrite of the only live database:

1. Stop new memory/audit/candidate/lifecycle writes.
2. Create a pre-restore snapshot if the current stores are readable.
3. Restore each database into a staging location.
4. Run schema/version/foreign-key/FTS/integrity checks on staging.
5. Verify the four-store manifest, epoch identity, and snapshot identity.
6. Reconcile Honeycomb nodes, EventLedger context IDs, WISP candidate rows, M5 lifecycle IDs/journal steps, and revisions before activation.
7. Atomically replace the active database references only after all four stores pass and reconciliation marks the snapshot `verified`.
8. Reopen, run startup checks, and publish `healthy` or `recovering`.
9. Keep the pre-restore state and any failed staging snapshot available for diagnosis according to retention policy.

A partial four-store restore is not a successful restore. If Honeycomb, EventLedger, the candidate store, or the M5 lifecycle store is missing/unhealthy, the app must enter recovery/degraded state and must not imply a complete knowledge, audit, candidate, digest, approval, or purge history. A restored four-store snapshot with unresolved epoch skew is `requires_reconciliation`, not `healthy`. Candidate or lifecycle recovery may be independently disabled only after the four-store snapshot is classified; ordinary browsing and unaffected explicit durable memory may continue according to the affected-store policy, but no candidate probe/write or M5 approval/purge write may resume while its participant is unresolved.

---

## 4. Corruption and recovery states

### 4.1 Detection

The store enters recovery when any of these occurs:

- SQLite returns `SQLITE_CORRUPT`, `SQLITE_NOTADB`, or an equivalent integrity failure;
- `quick_check` returns anything other than `ok`;
- required schema objects are missing after migration;
- FTS references nodes that do not exist or node rows lack expected FTS entries after a rebuild check;
- snapshot manifest or payload hashes do not match;
- migration fails and rollback cannot be proven.

### 4.2 Recovery ladder

```text
healthy
  → diagnose (read-only)
  → restore latest verified four-store snapshot
  → if no verified four-store snapshot: salvage reachable rows into new staged stores
  → label salvage partial/untrusted and reconcile nodes/events/revisions/FTS
  → require explicit recovery acceptance before activation
  → quarantine original; never delete evidence automatically
```

Salvage is best effort and must not be described as complete recovery. Salvaged rows retain a `salvaged` provenance/status and are not eligible to become `healthy` until cross-store reconciliation and integrity checks pass. Unmatched EventLedger events, missing revisions, and FTS rebuild gaps remain visible recovery findings. The original corrupt database is quarantined with a unique timestamp/ID. A second corruption in the same time window must receive a distinct quarantine name.

### 4.3 User-facing states

The browser surface must distinguish:

- **Recovered:** a verified four-store snapshot restored; show snapshot time and what may be missing since then.
- **Partially recovered:** one store or subset of records restored; disable affected memory, candidate, digest, approval, or purge actions according to the affected participant and show the boundary.
- **Needs attention:** no verified snapshot; browsing works, durable memory writes are paused; offer export/quarantine diagnostics.
- **Ephemeral fallback:** never automatic after corruption, migration failure, or open failure. It is available only through an explicit user/system recovery choice, carries a prominent session-only label, disables durable capture/import-report/brief-save/export/audit actions, and emits no durable-success event.

Never silently initialize a new empty Honeycomb or EventLedger database over a corrupt file. “No memories” and “memory store unavailable” are different product states.

---

## 5. Cross-store crash recovery

Honeycomb, EventLedger, the candidate store, and the M5 lifecycle store remain separate SQLite stores. M0 does not pretend they are a distributed transaction; the coordinator only provides a logical epoch and reconciliation boundary.

For a durable capture or promotion:

1. Validate the typed operation and scope.
2. Append a redacted recovery journal record before the first durable side effect.
3. Write Honeycomb and resolve any deduplicated node ID.
4. Append the idempotent EventLedger event with the resolved context ID.
5. Remove the recovery journal record only after both durable results are confirmed.
6. On restart, reconcile pending records without replaying user consent or duplicating nodes/events.

If Honeycomb succeeded and EventLedger is unavailable, the operation is `partial` and remains repairable; it is not reported as a clean success. If Honeycomb failed before a node was written, the journal may be released only after evidence proves no durable node exists. This follows the existing `HandoffRecoveryJournal` and `recordIfAbsent` patterns.

M0 must explicitly define the reconciliation matrix:

| Honeycomb | EventLedger | Candidate store | M5 lifecycle | Result | Recovery |
|---|---|---|---|---|
| absent | absent | absent | absent | not started | discard/release journal after validation |
| present | absent | absent | absent | partial | append event with resolved node ID |
| absent | present | absent | absent | inconsistent | quarantine event for auditor; do not invent node |
| present | present | present | present | present | complete for this operation | remove journal record; four-store consistency still requires epoch/reconciliation |
| any | any | corrupt/unknown | healthy/unknown | ambiguous | candidate/lifecycle state ambiguous | stop probe/lifecycle writes; preserve journals and affected DBs for recovery |
| unknown | unknown | unknown | unknown | unknown | ambiguous | stop replay; preserve journal and ask recovery path |

---

## 6. Failure-injection fixture matrix

M0 is not complete with only happy-path tests. The harness needs deterministic seams for failure injection; tests must not rely on killing the process randomly.

| ID | Injected failure | Required assertion |
|---|---|---|
| M0-1 | Fresh DB migration fails during table creation | `user_version` remains 0; no `healthy` state; original DB preserved |
| M0-2 | Migration fails after DDL but before version advance | transaction rolls back; prior schema is readable; retry is deterministic |
| M0-3 | Migration fails during data transform | no half-transformed rows; FTS and node counts unchanged |
| M0-4 | Future `user_version` | store blocks without downgrade or destructive reset |
| M0-5 | Foreign-key pragma fails/disabled | startup is blocked or degraded; cascade claims are not trusted |
| M0-6 | WAL setup/checkpoint fails | diagnostics disclose it; no false concurrency/backup claim |
| M0-7 | FTS row removed | mismatch detected; rebuild restores search; node authority unchanged |
| M0-8 | `quick_check` fails | read-only diagnosis/recovery state; no normal writes |
| M0-9 | Full integrity check fails | original DB quarantined; latest verified four-store snapshot offered |
| M0-10 | Online Backup API interrupted | incomplete staging snapshot is rejected and never activated |
| M0-11 | Four-store capture occurs without a shared write barrier/epoch | four-store snapshot is marked `requires_reconciliation`; automatic restore is blocked |
| M0-20 | Candidate writer bypasses `StorageEpochCoordinator.admitWrite(wispCandidates, ...)` | architecture test fails; candidate write is rejected |
| M0-21 | M5 lifecycle writer bypasses `StorageEpochCoordinator.admitWrite(m5Lifecycle, ...)` | architecture test fails; proposal/digest/purge write is rejected |
| M0-22 | Four-store manifest omits M5 lifecycle schema/revision or recovery state | snapshot is `requires_reconciliation`; automatic restore is blocked |
| M0-12 | Four-store snapshot manifest/hash mismatch | restore blocked; source snapshot preserved |
| M0-13 | Honeycomb write succeeds, ledger write fails | partial result + pending journal; retry is idempotent | 
| M0-19 | Duplicate capture reuses a complete node but its new audit fails | only the new attempt is incomplete; prior complete node provenance remains; no new HotMemory admission |

The fixture matrix contains **22 failure cases** (`M0-1` through `M0-22`). The acceptance table contains **14 gates** (`M0-A` through `M0-M`, including `M0-C1`); these are different counts.
| M0-14 | Ledger write succeeds, Honeycomb result is unknown | event quarantined for reconciliation; no fabricated node |
| M0-15 | Crash during four-store restore swap | old active stores or verified staged set remains recoverable; no empty reset |
| M0-16 | Two corrupt files quarantined within one second | unique quarantine names preserve both payloads |
| M0-17 | Store cannot open at launch | browser navigation/tabs remain usable; affected memory action is visibly disabled |
| M0-18 | Corrupt store requests automatic ephemeral fallback | fallback is refused; explicit recovery choice is required |

Every fixture records only typed status, IDs, counts, and error classes. It must not store page text, credentials, raw URLs, or model prompts.

---

## 7. Acceptance gates

| Gate | Requirement | Evidence |
|---|---|---|
| M0-A | Honeycomb, EventLedger, WISP candidate, and planned M5 lifecycle stores expose the same typed health vocabulary, with `StorageEpochCoordinator` owning the shared write-admission gate | API/schema review + unit tests |
| M0-B | Every migration has a version fixture and rollback/failure fixture | fresh/v1/v2/future/failure test matrix |
| M0-C | Every opened connection verifies foreign keys and reports journal mode | connection diagnostics tests |
| M0-C1 | Four-store snapshots state their non-atomic boundary, include Honeycomb/EventLedger/WISP candidate/M5 lifecycle schema versions and hashes, and use a coordinator-owned epoch | manifest/reconciliation tests |
| M0-D | WAL single-writer behavior and checkpoint policy are documented | SQLite integration test + diagnostics |
| M0-E | Routine quick check and deep integrity check have distinct paths | health-policy tests |
| M0-F | FTS can be rebuilt from node authority | corruption/rebuild fixture |
| M0-G | Online Backup API creates a validated four-store snapshot including the candidate and M5 lifecycle stores | backup/restore integration test |
| M0-H | Restore never overwrites the only active database | staging + atomic activation fixture |
| M0-I | Corrupt stores are quarantined, not silently replaced | recovery tests preserving original bytes |
| M0-J | Cross-store partial writes, M5 lifecycle transitions, and purge-step commits are journaled and idempotently repairable | HandoffRecoveryJournal + M5 lifecycle integration fixture |
| M0-K | No durable success is shown when required persistence is unavailable | browser/persistence policy tests |
| M0-L | Ordinary browsing works with memory disabled or storage blocked | clean-profile runtime path |
| M0-M | Diagnostics contain no raw secrets, page text, or unscoped browsing content | redaction test sweep |

M0 is **verified** only when all 14 gates—M0-A through M0-M plus M0-C1—pass with fresh build/test evidence and a clean-profile browser run. Source presence is `code-present`, not `verified`. The fixture table currently contains 22 cases; adding a case requires updating this plan and the M0 progress entry.

---

## 8. Implementation order after approval

This is the only implementation order permitted by the parent execution plan:

1. Extract/shared-test the typed storage health vocabulary without changing user-facing behavior.
2. Introduce failure-injection seams around migration, pragma, integrity, and backup operations.
3. Build the migration fixture matrix against current Honeycomb v1/v2, EventLedger v1, and the planned M5 lifecycle schema; register the M5 store before any M5 implementation begins.
4. Add quick/integrity diagnostics and FTS consistency/rebuild tests.
5. Add the four-store Online Backup API snapshot/restore contract, including M5 lifecycle schema/revision and purge-journal reconciliation.
6. Add quarantine/recovery state and browser-visible persistence fallback.
7. Wire cross-store reconciliation to the existing recovery journal, including durable attemptID/nodeID/eventID restoration and retry through `recordIfAbsent`.
8. Run M0-A through M0-M; only then unblock M1/M2 implementation.

No Honeycomb `.wisp` node, vector table, `opens` edge, retention table, import report store, M5 lifecycle write path, or new automatic probe is permitted before this exit gate. The M3 candidate store and M5 lifecycle store are permitted only as planned M0 participants; their runtime writes are blocked until the four-store contract and exit gate are implemented and evidenced.

---

## 9. Evidence references

Authoritative references used for this plan:

- [SQLite transactions](https://www.sqlite.org/lang_transaction.html)
- [SQLite pragmas (`foreign_keys`, `user_version`, `quick_check`, `integrity_check`)](https://www.sqlite.org/pragma.html)
- [SQLite foreign-key enforcement](https://www.sqlite.org/foreignkeys.html#fk_enable)
- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [`sqlite3_wal_checkpoint_v2`](https://www.sqlite.org/c3ref/wal_checkpoint_v2.html)
- [Apple File System Programming Guide — where to put application files](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/WhereToPutFiles/WhereToPutFiles.html)
- [Apple `replaceItemAtURL`](https://developer.apple.com/documentation/foundation/nsurl/1418735-replaceitematurl)
- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

These sources establish platform behavior. The M0 state machine, epoch/barrier protocol, four-store snapshot manifest, fixture matrix, and product copy are Hive-specific proposed contracts and require implementation evidence before capability labels change.

### Verification command

The canonical inventory check is:

```sh
find Sources/Hive/Resources/Swarm_System_Prompts -type f -name '*.md' | wc -l
find Swarm_System_Prompts -type f -name '*.md' | wc -l
```

The first count is the packaged planning/spec tree; the second is the root source-prompt corpus. Planning documents under `docs/superpowers/` are intentionally outside both counts.
