# Hive M48 — Active-Set Activation & Recovery Readiness

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M48 Active-Set Activation & Recovery Readiness
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Product contract:** `docs/superpowers/plans/2026-08-11-m0-storage-migration-recovery-spec.md`
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m47-m0-runtime-execution-plan.md`
> **Related readiness:** `docs/superpowers/plans/2026-08-12-m46-storage-migration-recovery-implementation-readiness-plan.md`
> **Next consumer:** an explicitly approved M0 runtime implementation pass; M45 remains blocked behind M0 evidence
> **Primary code seams:** existing storage/recovery owner, `Sources/HiveCore/Honeycomb/HoneycombStore.swift`, `Sources/HiveCore/EventLedger/EventLedgerStore.swift`, `Sources/HiveCore/AI/Search/HandoffRecoveryJournal.swift`, current Application Support/path helpers, browser persistence/recovery owner, and relevant HiveCore/browser tests
> **Research anchors:** SQLite Online Backup API, SQLite WAL/checkpoint/transaction/locking behavior, SQLite connection close/backup lifecycle, Apple Application Support/App Sandbox/FileManager replacement, Swift actor isolation/cooperative cancellation
> **Non-dependencies:** WISP candidate runtime, M5 lifecycle runtime, M45 capture, M2 import/Brief, ambient capture, models/training, sync, connectors, OS automation, cloud backup, new services, compliance certification, and release work
>
> M48 narrows M47’s activation section into a file-and-generation protocol that can be reviewed before Swift implementation. It is documentation-only and does not implement an active-set pointer, create a new authority, claim filesystem crash durability, or promote any capability to `verified`; it does not prove power-loss durability, crash consistency, semantic completeness, or `verified`.

## 0. Decision summary

M48 is the smallest safe next planning boundary after M47. M47 defines the runtime sequence and evidence gates, but a multi-database restore cannot be made safe by saying “swap the files atomically.” The current Honeycomb/EventLedger pair is the only M48 runtime slice; planned WISP and M5 lifecycle participants remain blocked. This slice needs a precise, owner-bound protocol for staged manifests, generation identity, handle closure, publication, startup selection, quarantine, deletion continuity, and evidence limitations.

| Candidate | Why not selected now | M48 decision |
|---|---|---|
| **Active-set activation/recovery readiness** | M47 requires a crash-safe complete-pair selection protocol but leaves filesystem mechanics and generation lifecycle to implementation | **Selected** |
| Immediate M0 Swift implementation | Would turn an underspecified multi-file activation boundary into runtime behavior | Defer until M48 is accepted and M47’s implementation order is explicitly approved |
| M45 explicit capture | Depends on M0 migration, attempt identity, recovery, deletion, and persistence evidence | Blocked behind M0 |
| M2 import/Brief | Adds durable writes and report state before storage recovery is proven | Defer |
| WISP/M5 lifecycle participants | Not present as current runtime stores; adding them would widen M0 authority and fixture scope | Explicitly blocked/deferred |
| New storage coordinator/service | Would create a second authority before current owner boundaries are implemented | Rejected |

M48 has one narrow product claim:

```text
A future M0 runtime must select one complete, validated Honeycomb/EventLedger
store pair after restart; it must never select a mixed generation or silently
replace an unreadable store with an empty one.
```

That is a design/readiness contract, not a guarantee that the current product already does this. It does not prove power-loss durability, crash consistency, semantic completeness, or `verified`. The plan itself is not `verified`; it is documentation-only.

## 1. Scope and authority boundary

### 1.1 Current runtime participant set

M48 covers only the durable stores currently established as M0 runtime participants:

1. Honeycomb knowledge store.
2. EventLedger append-only evidence store.

The planned WISP candidate store and planned M5 lifecycle store remain outside M48 runtime scope. They are not silently treated as absent-and-safe, and they are not allowed to inherit M48 evidence. Before either joins a future M0 implementation, it must be registered in the M0 participant set and included in the same active-set manifest, generation, backup, restore, deletion, recovery, browser-fallback, and evidence contract.

A Honeycomb/EventLedger-only M48 or M47 result cannot promote the broader M0 contract to `verified` while planned participants remain unresolved.

### 1.2 Existing owners

M48 creates no new authority: it does not create a new storage authority, new pointer database, new backup service, or new coordinator service. The future implementation owner must bind each artifact to existing ownership:

| Artifact or decision | Owner boundary | M48 rule |
|---|---|---|
| Honeycomb database content | `HoneycombStore` | Holds nodes, edges, revisions, FTS authority, and logical deletion materialization |
| Event evidence | `EventLedgerStore` | Holds append-only consequential events and deletion evidence |
| Cross-store repair gaps | Existing `HandoffRecoveryJournal` contract | Reuse exact attempt/node/event identity; no second repair ledger |
| Browser-session recovery | Existing browser persistence/recovery owner | Session snapshots are not memory/audit snapshots |
| Application Support/container path | Existing application lifecycle/path owner | No hard-coded user path or user-visible raw path leakage |
| Active-set selection record | **No current owner is evidenced in the live source audit.** M48-A must name and obtain explicit approval from an existing storage/recovery owner before runtime work; until then implementation is blocked | One canonical record contains selected store identities only; it is not a knowledge or evidence authority. M48 does not permit an unnamed future owner or new service/database to claim this role |
| Deletion continuity | Honeycomb logical-deletion owner plus EventLedger evidence owner | Higher deletion generation wins; wall-clock time alone never resolves conflicts |
| User-visible state | Browser persistence/recovery presentation owner | `healthy`, `recovering`, `degraded`, and `blocked` remain distinct |

The active-set record is an activation index over existing stores, not a third database of product objects. It must not contain memory nodes, page text, audit payloads, credentials, model prompts, or mutable business state. Because no current active-set owner is evidenced, M48-A is an explicit implementation blocker: the future runtime cannot proceed until an existing owner is named, approved, and shown to have lifecycle authority. Choosing a new pointer database, service, or shadow owner fails M48.

### 1.3 Explicit non-goals

M48 does not:

- edit Swift, tests, Package.swift, entitlements, or runtime configuration;
- add or execute a pointer/manifest implementation;
- add a new SQLite database, ledger, backup service, coordinator service, or migration authority;
- claim that `rename`, `replaceItem`, `fsync`, APFS, WAL, or Online Backup alone proves crash durability;
- make Honeycomb and EventLedger a distributed transaction;
- add WISP, M5, M45, M2, model, network, sync, connector, or OS-automation work;
- claim cryptographic erasure, forensic deletion, disaster-recovery RPO/RTO, legal compliance, or production readiness;
- claim that a valid manifest proves the contents are semantically complete;
- claim that a restored pair has no loss beyond the recorded snapshot boundary;
- run local builds, tests, training, downloads, installs, or release actions during this planning pass.

## 2. Current truth and unresolved questions

The live source audit remains stronger than historical plan claims:

- Honeycomb and EventLedger each open and close their own system SQLite connection.
- Their current open paths request WAL and foreign keys but do not uniformly expose actual pragma results as typed diagnostics.
- Their migration functions and versions are store-local; no implemented shared active-set protocol exists.
- `HandoffRecoveryJournal` provides a stronger existing pattern for redacted repair records and idempotent recovery identity, but it is not an active-set manifest owner by itself.
- Browser session persistence has rolling backup/quarantine vocabulary, but it is not evidence that the knowledge/audit pair has crash-safe activation.
- No current source evidence proves a complete staged Honeycomb/EventLedger pair can be selected after an interrupted publication.
- No current source evidence proves that an older snapshot cannot resurrect a later logical deletion.
- No current source evidence proves actual directory durability behavior for the target macOS filesystem and deployment configuration.

M48 treats all of these as `planned`, `blocked`, or `code-present`, never `verified`.

### 2.1 Required M48-A source freeze

Before any future implementation edits, the owner must identify and record:

1. The exact type/function that owns the active-set record.
2. The exact Application Support/container directory used for the record and staged stores.
3. Whether the record lives in the same directory as the databases or a separately managed container path.
4. How current store handles are closed and how outstanding prepared statements, transactions, and backup handles are detected.
5. Whether any direct writer can operate while activation is in progress.
6. Which existing recovery journal records can be pending at activation time.
7. The current Honeycomb deletion-generation/tombstone schema or the explicit M0 migration gap if absent.
8. The current EventLedger deletion event identity and evidence fields or the explicit M0 migration gap if absent.
9. The actual macOS/system SQLite version and target filesystem/deployment environment.
10. The source revision, environment, evidence scope, owner, and limitations for every answer.

An unanswered question is a readiness blocker. The implementation owner must not substitute a guessed path, guessed filesystem guarantee, or guessed owner.

## 3. M48-A — Artifact model and generation state machine

M48 defines the minimum artifacts needed to select a complete pair without copying product data into a new authority.

### 3.1 Artifact classes

```text
ActiveSetRecord
  points to one complete ActiveSetGeneration

ActiveSetGeneration
  immutable selection metadata for one Honeycomb/EventLedger pair

StoreArtifact
  staged or active Honeycomb/EventLedger SQLite payload

Manifest
  immutable description of a candidate pair and its validation evidence

QuarantineRecord
  redacted lifecycle metadata for rejected/incomplete artifacts
```

The implementation must decide whether these records are represented as files, an existing recovery-owned record, or another existing owner boundary. M48 does not authorize a new database to hold them.

### 3.2 Required fields

The exact serialization may differ, but the semantics are fixed:

```text
ActiveSetGeneration {
  generation: strictly_increasing_integer
  snapshot_id: stable_identifier
  created_at: timestamp
  source_revision: string
  environment: string
  evidence_scope: string
  honeycomb_identity: stable_artifact_identity
  event_ledger_identity: stable_artifact_identity
  honeycomb_schema_version: integer
  event_ledger_schema_version: integer
  manifest_hash: hash
  activation_state: staged | validated | published | superseded | quarantined
  logical_consistency: verified | requires_reconciliation
  deletion_generation_floor: integer_or_unknown
}
```

Artifact identity must not be only a path or timestamp. It must be stable enough to detect a mixed pair. The identity can include a content hash, immutable artifact ID, schema/version metadata, or an owner-defined combination, but the implementation must document what is actually verified and what remains unknown.

`created_at` is explanatory metadata, not a conflict-resolution authority. Generation order and deletion-generation rules must not be replaced by wall-clock comparison.

### 3.3 State transitions

```text
candidate
  → staged
  → validated
  → publishable
  → published
  → superseded
  → quarantined
```

Invalid transitions are rejected:

- `staged → published` without manifest, schema, FK, quick-check, integrity/FTS, identity, and deletion-continuity validation;
- `quarantined → published` without a new explicit validation result and new generation;
- `superseded → published` without a new derived candidate generation;
- `published → mutated` in place;
- `requires_reconciliation → verified` without the missing reconciliation evidence;
- an incomplete or unknown generation becoming the startup active set.

Every transition is idempotent by generation and manifest identity. Repeating a transition cannot create a second active pair or rewrite the immutable manifest payload.

## 4. M48-B — Publication protocol

This section is a readiness contract for a future implementation. It intentionally does not assert that the listed filesystem operations alone guarantee durability.

### 4.1 Candidate preparation

The future runtime may prepare a candidate only after:

1. A bounded write barrier or equivalent existing owner mechanism prevents new affected writes.
2. All already-admitted writes settle or are explicitly classified in `HandoffRecoveryJournal`.
3. Both active databases are readable enough to capture.
4. Honeycomb and EventLedger snapshots are staged independently through validated SQLite Online Backup operations.
5. Each staged database is opened and checked using the M47 health contract.
6. The pair is checked for schema compatibility, active-set identity, last committed context identity, and deletion-generation continuity.
7. The immutable manifest is written in a staging location and given a candidate generation.
8. The manifest content and candidate artifacts are validated before they become publishable.

If either database cannot be staged or validated, the candidate remains rejected or `requires_reconciliation`; the previous active set remains selected.

### 4.2 Handle and statement closure

Activation must not begin while an affected database handle has an unfinished transaction, prepared statement, open backup handle, or unresolved writer.

The future implementation must:

- enumerate or otherwise prove completion of statements and backup sessions it owns;
- finalize statements and finish backup handles before closing database connections;
- distinguish a clean close from a close that returned `SQLITE_BUSY` or retained resources;
- prevent new writes during the close barrier;
- preserve the old active set if closure cannot be proven;
- record a redacted close/activation failure class without raw SQL or page content.

The implementation must not rely on a deferred close operation to hide leaked statements or unfinished backups. A close that cannot complete is a recovery state, not a successful activation precondition.

### 4.3 Publication sequence and crash boundary

The only acceptable conceptual sequence is:

```text
candidate generation fully staged
  → candidate manifest validated
  → one canonical active-set record prepared as PREPARED(N+1)
  → owned handles closed and closure verified
  → record and required directory-durability steps attempted
  → the same canonical record published as COMMITTED(N+1)
  → startup/open validation of both selected identities
  → old generation marked superseded only after new generation validates
```

There is one canonical active-set record, not a separate pointer plus manifest authority. `PREPARED` is never selectable. `COMMITTED` is selectable only when the record, generation, manifest hash, both store identities, and all required validation evidence agree. Publication is one replacement of that complete canonical record through the explicitly approved existing owner; the future implementation must name the exact Foundation/POSIX/owner-existing primitive and its platform limits before code is written.

Crash outcomes are fixed:

- Before the canonical record replacement begins: the prior `COMMITTED(N)` record remains selected.
- During replacement: startup rejects a missing, malformed, truncated, or non-`COMMITTED` record; it selects the newest previously complete committed generation, or enters `recovering`/`blocked` if none exists.
- After a valid `COMMITTED(N+1)` record is published but before reopening: startup validates both identities and all required checks; any failure quarantines N+1 and selects the prior complete generation where available.
- A process must never select Honeycomb from N+1 with EventLedger from N, or select a `PREPARED`/unknown generation.

The publication plan must explicitly record which object is replaced, which directory/container is affected, handle closure, parent-directory durability behavior, interrupted-publication handling, prior-generation lookup, incomplete-artifact quarantine, and what durability is and is not proven. M48 does not require or imply a universal `fsync` guarantee. A successful API return is not by itself evidence that a power-loss scenario was survived.

### 4.4 Startup selection

On every startup or recovery reopen, selection must:

1. Enumerate only owner-recognized active-set generations.
2. Reject malformed, incomplete, unknown-schema, hash-mismatched, or quarantined records.
3. Prefer the newest complete generation according to the monotonic generation contract, not the newest timestamp.
4. Validate that Honeycomb and EventLedger identities match the same generation.
5. Validate schema, connection, integrity, FTS, and deletion-continuity evidence according to M47.
6. Select the prior complete generation if the newest candidate is incomplete or invalid.
7. Enter `recovering`/`blocked` if no complete valid generation exists.
8. Never create an empty durable Honeycomb or EventLedger store as a startup substitute.
9. Keep ordinary browsing usable when the memory/audit pair is unavailable.

Startup must not select Honeycomb from generation N+1 and EventLedger from generation N, even if each file independently passes SQLite checks.

## 5. M48-C — Manifest integrity, validation, and evidence

### 5.1 Manifest validation order

A candidate manifest is publishable only after this order:

```text
parse bounded record
  → validate schema/version
  → validate required fields and canonical encoding
  → validate artifact identities and hashes
  → open staged databases
  → validate connection-local pragmas
  → validate user_version and required schema
  → quick_check + foreign_key_check
  → FTS consistency/rebuild result where applicable
  → deep integrity result when required by policy
  → validate cross-store IDs/epoch/barrier
  → reconcile deletion generations and EventLedger evidence
  → bind exact evidence record
  → mark validated/publishable
```

Malformed or oversized manifests are rejected before any path is opened. Paths are not accepted from untrusted manifest content without owner-controlled resolution and containment checks.

### 5.2 Hash and identity limits

Hashing a manifest or database artifact can detect changes relative to the hashed input. It does not prove:

- that the artifact came from an authorized source;
- that the database is semantically complete;
- that a prior deletion was included;
- that the filesystem survived power loss;
- that a remote or unmanaged copy was deleted;
- that the pair was one distributed transaction.

M48 requires these limitations to remain visible in evidence and user-facing recovery state where relevant.

### 5.3 Evidence envelope

Every candidate/publication/recovery result binds:

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
timestamp
```

Evidence must contain typed result classes and bounded IDs, not raw page text, credentials, cookies, private URLs, model prompts, arbitrary absolute paths, or full database dumps.

A fixture result is not a runtime result. A runtime result from a test profile is not a clean-profile product result. A clean-profile result is not a power-loss guarantee.

## 6. M48-D — Quarantine and lifecycle

### 6.1 Quarantine triggers

A candidate or active-set generation enters quarantine when:

- its manifest cannot be parsed or exceeds bounded limits;
- its hash or artifact identity does not match;
- either staged database fails schema, FK, quick-check, integrity, or FTS requirements;
- the two artifacts belong to different generations or inconsistent snapshot IDs;
- deletion evidence is unavailable or cannot be reconciled;
- activation publication is interrupted or leaves an incomplete record;
- a close/handle barrier cannot be proven;
- the generation is unknown, unsupported, or superseded with unresolved references;
- a path is outside the owner-controlled container or fails containment checks.

Quarantine is not deletion. Original artifacts remain available for bounded diagnosis subject to the existing retention/deletion owner. Quarantine metadata is redacted and does not copy database contents.

### 6.2 Recovery ladder

```text
published generation N is healthy
  → candidate N+1 fails validation
  → quarantine N+1
  → keep N selected

published generation N is unreadable
  → diagnose read-only
  → validate newest complete prior generation
  → select prior generation if valid
  → otherwise recovering/blocked

publication interrupted
  → enumerate complete generations
  → reject incomplete/mixed candidates
  → select newest complete valid generation
  → quarantine incomplete publication artifacts

no complete generation
  → keep browser usable
  → pause affected durable memory/audit operations
  → offer explicit recovery/export path
  → refuse automatic empty durable initialization
```

“Recovered” means a complete selected generation passed the declared checks. “Partially recovered” means a bounded subset or one store is available and the affected boundary is visible. “Needs attention” means no verified selected pair exists. “Ephemeral” means explicit session-only use, never an automatic corruption response.

### 6.3 Cleanup rules

Stale candidate and quarantine artifacts must not be deleted by a heuristic that could remove the only recoverable copy. Cleanup requires:

- owner-defined retention and scope;
- generation/reference checks;
- no active recovery reference;
- no unresolved deletion/reconciliation evidence;
- idempotent behavior across restart;
- a bounded deletion receipt or explicit failure state.

M48 does not claim secure or forensic deletion of files.

## 7. M48-E — Deletion continuity and cross-store reconciliation

### 7.1 Non-resurrection contract

Honeycomb remains the owner of logical deletion materialization. EventLedger remains the owner of append-only deletion evidence. A deletion has:

```text
delete_generation
exact_target_identity
scope
 tombstone/reference identity
event identity
```

Before publication, the candidate pair must compare its deletion generations with the newest available active deletion evidence. It must apply every newer deletion to the candidate before selecting it. If the evidence cannot be found, matched, or verified, the candidate is `requires_reconciliation` and cannot publish.

Deletion conflict resolution uses generation/identity continuity, not wall-clock timestamps. Absence from an older snapshot is never evidence that a later deletion did not happen.

After publication, deleted identities must remain excluded from Honeycomb retrieval, FTS, HotMemory, exports, and user-visible Knowledge projections according to the existing deletion contract. The rule survives restart, retry, fallback, and selecting a prior complete generation.

### 7.2 Cross-store recovery matrix

| Honeycomb candidate | EventLedger candidate | Active-set record | Result | Required action |
|---|---|---|---|---|
| absent | absent | complete prior | no new pair | keep prior generation; classify candidate as not started |
| present | absent | complete prior | incomplete pair | quarantine candidate; keep prior generation |
| absent | present | complete prior | inconsistent pair | quarantine candidate; never invent Honeycomb |
| present | present | incomplete/missing | unpublished pair | validate only through a new complete generation |
| unknown/corrupt | any | any | ambiguous | stop activation/replay; preserve artifacts and enter recovery |
| present/present | complete matching | publishable | candidate pair | validate deletion continuity, publish one generation |

M48 does not turn this matrix into a distributed transaction. It defines what may be selected and what must remain blocked.

## 8. M48-F — Browser-first and privacy boundary

When no complete active pair is available:

- navigation, tabs, switching, private browsing, ordinary rendering, keyboard paths, and zero-history use remain available;
- durable capture, audit, import reports, brief saves, deletion, and memory-dependent actions are disabled or clearly typed according to the affected store;
- no in-memory write is represented as durable success;
- no model or network is required for the fallback;
- private, locked, denied, offline, canceled, accessibility, reduced-motion, and manual states are understandable;
- recovery UI exposes bounded status and a retry/export path without raw content or secrets;
- the browser does not infer that an empty memory result means the user has no memories.

A corrupt or unavailable store must not widen context, bypass private-mode policy, or cause a model call. A page, manifest, database row, or model output cannot grant activation authority.

## 9. Deterministic fixture and evidence matrix

All fixtures are synthetic, local, bounded, and disposable. They contain no real browsing history, credentials, private URLs, page prose, screenshots, model prompts, cookies, or secret paths. Fixture definitions are not runtime results.

| IDs | Fixture family | Required assertion |
|---|---|---|
| M48-01–04 | source/owner/artifact model | owner freeze, current participant list, bounded manifest parse, malformed/oversized manifest rejection |
| M48-05–08 | generation lifecycle | monotonic generation, immutable manifest, invalid transition, duplicate transition idempotency |
| M48-09–12 | handle/publication barrier | unfinished statement/backup rejection, busy close, writer admission closure, interrupted publication |
| M48-13–16 | startup selection | newest complete generation, mixed-generation rejection, malformed record quarantine, no-complete-generation blocked state |
| M48-17–20 | manifest/filesystem | artifact identity mismatch, hash mismatch, containment failure, target filesystem durability limitation recorded |
| M48-21–24 | deletion/recovery/fallback | post-snapshot deletion non-resurrection, each cross-store matrix class, quarantine retention/cleanup boundary, browser-first unavailable/denied/offline fallback |

The M48-21–24 family contains subcases; each subcase must receive a distinct trace/evidence identity in the future harness. Four row labels are not permission to omit any matrix state.

## 10. Fourteen M48 gates

| Gate | Requirement |
|---|---|
| M48-A | Current Honeycomb/EventLedger participants, active-set owner, path owner, handle owner, deletion owners, and unresolved gaps are reconciled from live source. |
| M48-B | Active-set artifacts are bounded, owner-controlled, identity-bearing, and contain no product content or secret data. |
| M48-C | Generation state transitions are monotonic, immutable, idempotent, and reject incomplete/unknown/superseded publication. |
| M48-D | Publication defines one active-set object, handle closure, directory/path scope, interruption behavior, prior-generation selection, and filesystem durability limitations. |
| M48-E | Candidate manifests validate schema, identity, hashes, store health, schema versions, and cross-store consistency before publication. |
| M48-F | SQLite backup/close/checkpoint status handling rejects incomplete or busy/locked artifacts rather than treating them as valid snapshots. |
| M48-G | Startup chooses only the newest complete valid generation with matching Honeycomb/EventLedger identities. |
| M48-H | Mixed generations, malformed records, unsupported versions, unsafe paths, and interrupted publication are quarantined or blocked. |
| M48-I | No complete generation causes explicit recovery/degraded state and never automatic empty durable initialization. |
| M48-J | Honeycomb deletion generations plus EventLedger evidence prevent non-resurrection across candidate validation, restart, fallback, and recovery. |
| M48-K | Cross-store retry and repair preserve exact attempt/node/event identity through the existing recovery journal and idempotent ledger API. |
| M48-L | Cleanup is owner-bound, generation-aware, idempotent, and does not remove the only recoverable artifact; no secure-erasure claim is made. |
| M48-M | Browser-first, private, locked, denied, offline, canceled, accessibility, reduced-motion, and manual fallback states remain usable and redacted. |
| M48-N | All 24 fixture mappings and every subcase have evidence identity; fresh implementation evidence is required before M0/M45 status changes. |

## 11. Implementation handoff and stop conditions

M48 is planning-only. After explicit approval of a future runtime pass, the permitted order is:

1. Reconcile M48-A against the actual checkout and record source revision/environment.
2. Name and obtain explicit approval from an existing storage/recovery owner for the one canonical active-set record; **if no such owner is evidenced, stop as `blocked` and do not implement**. Do not create a new service or database.
3. Add bounded artifact/generation value types and parser tests without activating them.
4. Add deterministic handle-closure and publication-interruption seams.
5. Add manifest validation and startup selection tests using synthetic artifacts.
6. Add validated staged backup/restore behavior only through M47’s current-participant boundary.
7. Add deletion-generation reconciliation and cross-store identity preservation.
8. Add quarantine/cleanup states with no silent deletion.
9. Add browser-first degraded/recovery presentation.
10. Run focused tests, full build/test, clean-profile runtime, and the M47/M48 evidence review before any status change.

Stop as `blocked` or `unavailable` if:

- the active-set owner is unclear, unapproved, or a second authority is introduced;
- a manifest contains raw product content, secrets, or unbounded data;
- an active-set generation is mutable after publication;
- publication can select a mixed Honeycomb/EventLedger pair;
- unfinished statements, transactions, writers, or backup handles are ignored;
- `SQLITE_BUSY`, `SQLITE_LOCKED`, backup interruption, or close failure becomes success;
- a filesystem operation is described as crash-safe without target-specific evidence and limitations;
- a hash is treated as authorization, semantic completeness, or power-loss proof;
- an old snapshot can resurrect a later deletion;
- malformed or corrupt artifacts are silently replaced or deleted;
- no-complete-generation state initializes an empty durable store;
- WISP/M5/M45/M2 scope is pulled into the current two-store slice without a new approved plan;
- browser navigation, tabs, private mode, accessibility, offline, locked, denied, or manual fallback breaks;
- fixtures, mocks, source presence, or plan validation are treated as runtime proof.

## 12. Explicit deferrals and honest limits

M48 does not implement or verify:

- Swift runtime changes or M47/M0 execution;
- WISP candidate or M5 lifecycle stores, their schemas, or their participant registration;
- M45 explicit capture, M2 import/Brief, M15 browser credibility, models, training, research, MCP, or ambient capture;
- cloud backup, sync, remote recovery, SQLCipher, connectors, OS automation, or telemetry;
- power-loss durability, filesystem crash-consistency, cryptographic/forensic deletion, disaster-recovery RPO/RTO, compliance, or production readiness without target-specific evidence;
- distributed transactions, exactly-once external effects, or universal rollback.

**M48 is complete as a documentation-only readiness plan when its six work packages, 24 fixture mappings, 14 gates, artifact/generation owner, publication interruption rules, startup selection protocol, deletion non-resurrection contract, browser-first fallback, and evidence limitations are structurally validated and independently reviewed.**

## 13. Primary references and claim limits

- [SQLite Online Backup API](https://www.sqlite.org/backup.html) — backup lifecycle and incremental copy behavior.
- [SQLite backup C API](https://www.sqlite.org/c3ref/backup_step.html) — `sqlite3_backup_step` status handling.
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html) — connection close and unfinished-resource behavior.
- [SQLite transactions](https://www.sqlite.org/lang_transaction.html) — transaction modes and writer locking.
- [SQLite WAL](https://www.sqlite.org/wal.html) — reader/writer and checkpoint behavior.
- [SQLite pragmas](https://www.sqlite.org/pragma.html) — `user_version`, foreign keys, checks, and busy policy.
- [Apple File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/WhereToPutFiles/WhereToPutFiles.html) — Application Support placement.
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox) — container and file-access boundary.
- [Apple FileManager replacement](https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:)) — replacement API; does not by itself prove power-loss durability.
- [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) — actor isolation and cooperative cancellation.

These references establish platform/library behavior. M48’s active-set artifact model, generation state machine, owner mapping, browser copy, deletion continuity, fixture matrix, and evidence gates are Hive-specific contracts. They require implementation evidence before any capability status changes.
