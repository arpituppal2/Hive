# Hive M51 — StorageActivationCoordinator Implementation Readiness

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation not authorized
> **Roadmap label:** M51 StorageActivationCoordinator Implementation Readiness
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m50-storage-activation-coordinator-architecture-decision-plan.md`
> **Related contracts:** M0 storage/recovery, M46 readiness, M47 runtime execution, M48 activation, M49 owner block
> **Primary source seams:** `HoneycombStore`, `EventLedgerStore`, `HandoffRecoveryJournal`, `SessionFileStore`, browser persistence/recovery, Application Support/path resolution, and current persistence/recovery tests
> **Next consumer:** a separately approved coordinator runtime implementation pass after M51 gates pass
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M51 translates the M50 architecture decision into an implementation-ready contract. It defines the seams, injected boundaries, state machine, failure harness, fixtures, evidence, and browser fallback required before Swift edits. M51 does not create files, types, actors, tests, databases, ledgers, or runtime behavior.

## 0. Decision summary

**Decision: prepare, do not implement.** M50 approved a bounded `StorageActivationCoordinator` as the semantic owner for one activation metadata record over `{Honeycomb, EventLedger}`. M51 now specifies how a future runtime pass must be shaped and proven without allowing implementation to begin implicitly.

M51 selects the smallest safe implementation-readiness boundary:

```text
source freeze
  → explicit interfaces and ownership
    → bounded record codec/parser
      → coordinator actor and lifecycle seams
        → deterministic failure/recovery harness
          → browser-first handoff decision
```

A future runtime pass may proceed only after the M51 exit gate is accepted, the current checkout is re-audited, and a separate implementation approval names the exact changed paths. M51 itself produces documentation and evidence requirements only.

## 1. Binding constraints inherited from M50

### 1.1 Participant set

The only current participant set is:

```text
{Honeycomb, EventLedger}
```

WISP candidate storage and M5 lifecycle storage remain planned, blocked, and unregistered. They cannot enter M51 through a generic participant protocol, “future-proof” enum case, empty placeholder, or test-only registration. A future participant requires a new decision and the full active-set/recovery/deletion/evidence contract.

### 1.2 Coordinator scope

The future coordinator may own only:

- one canonical bounded active-set metadata record;
- generation state and publication selection for the current pair;
- coordination of approved writer/handle barriers;
- matching store identities and deletion-generation floors;
- startup selection, quarantine classification, and bounded activation evidence;
- browser-first degraded-state projection.

It may not own:

- Honeycomb or EventLedger contents, schemas, migrations, FTS, revisions, event rows, or deletion materialization;
- no coordinator database, no second ledger, no backup service, no raw product snapshot, no content cache, and no telemetry store;
- any new durable authority or product-data authority beyond the one bounded metadata record explicitly approved by M50;
- browser sessions, private-mode policy, permissions, model context, credentials, connectors, WISP, M5, or OS actions;
- semantic truth about either store beyond the typed health/identity results returned by that store.

### 1.3 Status honesty

M51 is not verified. A parser test, mock filesystem, passing fixture, successful `FileManager` call, SQLite backup result, or actor compilation does not prove power-loss durability, crash consistency, cross-store atomicity, production readiness, or ship readiness.

## 2. M51-A — Source freeze and explicit interfaces

Before any future Swift edit, produce a source-bound owner map from the actual checkout.

### 2.1 Required source inventory

Record exact symbols and call paths for:

1. Honeycomb open/close, migration, health, backup, deletion-generation, and direct-writer boundaries.
2. EventLedger open/close, migration, health, backup, deletion-evidence, idempotency, and direct-writer boundaries.
3. `HandoffRecoveryJournal` creation, append/update/clear, retry identity, and retention/deletion boundaries.
4. `SessionFileStore` and browser persistence atomic-write/quarantine behavior, explicitly marked as a reference pattern rather than coordinator authority.
5. Application Support/container path resolution and startup/lifecycle entry points.
6. Persistence-health and recovery UI/state projection paths.
7. Existing test fixtures, injected closures, mock stores, failure seams, and any process/restart harness.
8. All direct store writers that could bypass a future writer barrier.
9. Current macOS target, system SQLite version, sandbox/container configuration, and relevant entitlements.
10. Source revision, environment, evidence scope, owner, and limitation for every observation.

An unresolved direct writer, unknown startup path, or unowned close/backup operation blocks the readiness gate.

### 2.2 Required future interfaces

M51 specifies semantics, not names. The future runtime must provide equivalent boundaries:

```text
StorageActivationCoordinator : actor
  - inspectCurrentState()
  - prepareCandidate(snapshotInput)
  - publish(candidate)
  - selectStartupGeneration()
  - quarantine(generation, reason)
  - cancel()

ActivationMetadataCodec
  - encode(record) -> bounded bytes
  - decode(bytes) -> validated record or typed rejection
  - canonicalHash(bytes) -> stable digest

ActivationFileSystem
  - resolveContainerPath()
  - readMetadata()
  - stageMetadata(bytes)
  - publishMetadata(staged, destination)
  - quarantineArtifact()
  - removeAfterRetentionDecision()

StoreParticipant
  - identity()
  - health()
  - deletionFloor()
  - beginWriteBarrier()
  - stageValidatedSnapshot()
  - closeOwnedResources()
  - reopen(generation)

ActivationEvidenceSink
  - recordBounded(result)
```

These interfaces must be dependency-injected or otherwise replaceable in tests. The coordinator must not reach directly into global singletons, UI state, arbitrary paths, raw SQLite pointers, model output, or network code.

`ActivationEvidenceSink` is an evidence adapter over existing approved evidence ownership; it is not a new ledger. If the implementation requires a new durable evidence store, M51 fails and reopens M50.

### 2.3 Ownership and deadlock rules

- The coordinator actor serializes activation decisions, but it does not make non-Sendable SQLite handles freely transferable across actors.
- Store actors retain ownership of their own connections, statements, backups, transactions, and schema operations.
- The coordinator calls typed store methods; it never manipulates another actor’s raw handle.
- No store callback synchronously calls back into the coordinator while the coordinator holds a publication barrier.
- Every `await` boundary is treated as an actor-reentrancy point; state transitions use generation/operation identity checks after resumption. This explicit await boundary is a stale-state defense, not an implicit publication permission.
- Main-actor UI and blocking file-coordination APIs are not coupled synchronously; blocking work is isolated from the main actor and cancellation is explicit.
- A second concurrent activation is rejected or coalesced by operation identity; it never creates two publishable generations.

## 3. M51-B — Bounded record codec and validation

### 3.1 Recommended representation

M51 should evaluate and document a bounded canonical UTF-8 metadata representation in the same application-controlled container. A versioned JSON representation with deterministic key ordering is the default candidate because it is inspectable and does not require a coordinator database. The implementation must not assume `Codable` alone provides atomicity, canonical bytes, authorization, or durability.

If the target toolchain cannot provide stable canonical bytes, M51 must select another bounded representation and add byte-level golden fixtures. The decision must record codec version, maximum byte size, allowed fields, encoding rules, rejection behavior, and hash input.

M51 does not authorize a codec implementation; it authorizes only the decision and test contract.

### 3.2 Record invariants

A decoded record is publishable only if:

- format version is supported;
- all required fields are present and bounded;
- generation is strictly greater than the current committed generation;
- state transition is legal;
- snapshot and store identities are canonical and non-empty;
- schema versions are store-reported values, not model/user input;
- manifest hash matches the canonical bytes it describes;
- deletion floor is typed and reconciled;
- source revision/environment/evidence scope/limitation are bounded metadata;
- no unknown field can grant authority or alter policy;
- no path is accepted as an authority or opened without owner-controlled containment;
- raw content, secrets, prompts, cookies, private URLs, screenshots, and unbounded diagnostics are rejected.

### 3.3 Rejection classes

The codec must distinguish at least:

```text
unsupported_format
oversized_record
malformed_encoding
missing_required_field
unknown_or_unbounded_field
noncanonical_encoding
invalid_generation
invalid_state_transition
identity_mismatch
hash_mismatch
unsafe_path
privacy_violation
```

A parser rejection never becomes an empty durable store, a successful startup, or a broader fallback context.

## 4. M51-C — Lifecycle, writer barrier, and publication readiness

### 4.1 Required future sequence

The future runtime must implement and evidence this order:

```text
coordinator reserves operation_id and candidate generation
  → acquire bounded writer barrier through typed store APIs
  → stage Honeycomb and EventLedger using their own validated mechanisms
  → validate store health, identities, schemas, and deletion continuity
  → encode/hash bounded PREPARED record
  → close and verify owned statements, backups, transactions, and connections
  → publish one same-container metadata record through ActivationFileSystem
  → reopen both stores from the committed generation
  → revalidate identities and health
  → retain prior generation until new generation passes
  → emit bounded result and release barrier
```

The sequence is a readiness contract, not current behavior.

### 4.2 Writer barrier semantics

The writer barrier must be explicit and bounded:

- new affected writes are rejected, queued, or classified with a typed reason;
- already-admitted writes either settle or receive a durable/retry identity through existing store/journal contracts;
- the barrier is scoped only to Honeycomb/EventLedger operations participating in this activation;
- browser navigation, tabs, private browsing, and unrelated local UI do not wait on a storage barrier;
- cancellation releases the barrier exactly once;
- timeout becomes `blocked`/`degraded`, never silent success;
- direct writers discovered in M51-A must be migrated into the boundary or remain a hard blocker.

### 4.3 SQLite resource closure

The future runtime must prove, not assume:

- every prepared statement it owns is finalized;
- every Online Backup handle reaches `sqlite3_backup_finish` exactly once;
- backup completion requires `SQLITE_DONE` (the `sqlitedone` terminal result), not merely a successful finish call;
- retryable `SQLITE_BUSY`/`SQLITE_LOCKED` is bounded and classified;
- fatal backup/I/O/read-only/memory errors abort the candidate and preserve the prior generation;
- `sqlite3_close` returning `SQLITE_BUSY` is a failed close barrier;
- transactions are committed or rolled back before publication;
- cancellation and early errors run cleanup paths;
- no raw SQLite handle crosses the coordinator actor boundary.

### 4.4 Publication readiness

M51 must name and test the exact publication operation in a later implementation pass. The candidate metadata staging file must be on the same volume and owner-controlled container as the destination: this is the required same-container publication boundary. `FileManager.replaceItemAt`, POSIX rename, `NSFileCoordinator`, `fsync`, and related APIs must be described with their actual platform limits; none alone proves power-loss durability or multi-database atomicity.

The publication adapter must expose typed outcomes:

```text
published
preserved_prior_generation
quarantined_candidate
blocked_no_prior_generation
canceled
permission_denied
io_failure
unsupported_filesystem
```

No operation may report `published` if the canonical record is malformed, `PREPARED`, mixed-generation, or not reopenable.

## 5. M51-D — Deterministic failure-injection and recovery harness

### 5.1 Injection model

The future test harness must inject failures through wrappers/protocols or a supported local test VFS. It must not rely on real power loss, arbitrary process killing, user data, or nondeterministic timing as the only evidence.

Required injection points:

1. metadata encode/decode/hash;
2. path resolution and containment;
3. temporary-file creation/write/flush;
4. parent-directory publication/replace;
5. backup init/step/finish;
6. statement prepare/finalize;
7. transaction begin/commit/rollback;
8. writer-barrier acquire/release/timeout;
9. store reopen/health/identity/deletion-floor;
10. cancellation at every awaitable lifecycle phase;
11. evidence emission and UI projection.

### 5.2 Required recovery outcomes

For every injected failure, assert:

- prior complete generation remains selectable where available;
- no mixed Honeycomb/EventLedger pair is selected;
- no `PREPARED` record is selected;
- incomplete artifacts are quarantined or retained for bounded diagnosis;
- no empty durable store is created;
- deletion generations cannot regress or resurrect deleted identities;
- writer barriers and backup/statement/connection resources are released;
- result state is typed and evidence is bounded/redacted;
- ordinary browsing remains usable.

### 5.3 Restart harness

The future harness must test startup selection from synthetic metadata/artifacts without claiming that a simulated restart proves a power-loss guarantee. It must cover missing, truncated, malformed, unsupported, hash-mismatched, quarantined, mixed-generation, and valid committed records, plus no-prior-generation recovery.

## 6. M51-E — Browser-first handoff and evidence

### 6.1 Degraded browser contract

When coordinator or storage activation is unavailable:

- navigation, tabs, tab switching, private windows, ordinary rendering, keyboard, accessibility, offline browsing, and manual work remain available;
- memory/audit-dependent writes are typed unavailable/degraded/blocked;
- no in-memory success is shown as durable;
- no model/network call is triggered by storage failure;
- recovery UI exposes bounded status, retry, export, and limitation text without raw content or secrets;
- an empty memory result is not presented as proof that no memory exists.

### 6.2 Evidence envelope

Every future runtime result must bind:

```text
trace_id
source_revision
environment
sqlite_runtime_version
evidence_scope
operation_id
active_set_generation
snapshot_id
manifest_hash
honeycomb_identity
event_ledger_identity
observed_state
limitation
owner
```

Evidence excludes page text, browsing history, private URLs, credentials, cookies, prompts, screenshots, raw SQL, full database dumps, arbitrary absolute paths, model outputs, and unbounded logs.

`source presence`, `fixture pass`, `mock filesystem`, `successful API return`, and `plan validation` are not `verified` evidence.

## 7. M51-F — Implementation handoff and stop conditions

M51 is complete only when the following handoff packet exists:

```text
source_revision
implementation_paths
interface_owner_map
participant_set = {Honeycomb, EventLedger}
codec_decision
record_schema_version
publication_primitive_and_limits
writer_barrier_contract
resource_closure_contract
failure_injection_map
fixture/evidence map
browser fallback map
known limitations
separate implementation approval
```

A future runtime pass remains blocked if:

- any direct store writer bypasses the barrier;
- coordinator state becomes a product-data authority or second ledger/database;
- the codec is unbounded, noncanonical, or accepts unknown authority-bearing fields;
- publication relies on a main-file-only WAL copy;
- `SQLITE_BUSY`, `SQLITE_LOCKED`, incomplete backup, close failure, cancellation, or permission denial becomes success;
- an `await` resumes into a stale generation without identity revalidation;
- a mixed generation or `PREPARED` record can be selected;
- deletion evidence is missing or an old snapshot can resurrect a later deletion;
- a failed activation disables browser/private/offline/accessibility/manual fallback;
- evidence contains raw content/secrets or claims power-loss/crash consistency without target-specific proof;
- WISP/M5/M45/M2 scope enters the current participant set without a new decision;
- M51 planning artifacts are treated as runtime verification.

## 8. Deterministic fixture and evidence matrix

All fixtures are synthetic, local, bounded, disposable, and free of real browsing history, page content, private URLs, credentials, cookies, prompts, screenshots, secrets, arbitrary absolute paths, and full database contents. Fixture definitions are not runtime results.

| IDs | Fixture family | Required assertion |
|---|---|---|
| M51-01–04 | source/interface freeze | exact owners, direct writers, startup paths, target SQLite/sandbox, and unresolved conflicts are recorded |
| M51-05–08 | codec/record | canonical encoding, malformed/oversized rejection, unknown-field rejection, hash/identity mismatch |
| M51-09–12 | actor/barrier | operation serialization, stale-generation rejection, writer admission/timeout, cancellation releases barrier |
| M51-13–16 | backup/closure | backup `DONE` requirement, busy/locked retry, fatal backup failure, statement/backup/connection closure |
| M51-17–20 | publication | same-container staging, replace/permission/I/O failure, interrupted publication, prior-generation preservation |
| M51-21–24 | startup | committed selection, prepared rejection, mixed-generation rejection, malformed/unsupported/quarantined handling |
| M51-25–28 | deletion/reconciliation | higher deletion floor, missing evidence block, no resurrection in derived projections, retry identity continuity |
| M51-29–32 | privacy/fallback | no raw metadata leakage, private/locked/denied/offline/accessibility/manual browser fallback, no model/network widening |
| M51-33–36 | evidence/handoff | deterministic evidence envelope, limitation binding, synthetic-versus-runtime distinction, M51 approval packet |
| M51-37–40 | adversarial/stop | direct-writer bypass, stale await resume, second authority/database proposal, WISP/M5 scope inflation |

Every fixture maps to a unique `trace_id`/evidence identity in the future harness. Forty mappings are requirements, not evidence that the runtime exists.

## 9. Fourteen M51 gates

| Gate | Requirement |
|---|---|
| M51-A | Source freeze identifies current owners, direct writers, lifecycle paths, tests, target environment, and unresolved conflicts. |
| M51-B | Future interfaces separate coordinator metadata authority from store content/schema/evidence authorities. |
| M51-C | Participant set is exactly Honeycomb/EventLedger; WISP/M5 remain blocked and unregistered. |
| M51-D | Codec and bounded record schema, canonical bytes, hash input, and rejection classes are decided. |
| M51-E | Unknown, oversized, malformed, unsafe, privacy-violating, and authority-bearing metadata is rejected. |
| M51-F | Coordinator actor/reentrancy, operation identity, cancellation, and stale-generation rules are explicit. |
| M51-G | Writer barrier is scoped, bounded, cancellation-safe, and covers every direct durable writer. |
| M51-H | Backup/statement/transaction/connection closure and status handling are typed and fail closed. |
| M51-I | Publication primitive, same-container staging, interruption outcomes, quarantine, and filesystem limitations are explicit. |
| M51-J | Startup selects only the newest complete committed matching generation and never an empty/mixed/prepared state. |
| M51-K | Deletion-generation continuity and EventLedger evidence prevent snapshot resurrection. |
| M51-L | Failure injection covers I/O, permissions, busy/locked, cancellation, close, backup, publication, restart, and stale-actor paths. |
| M51-M | Browser-first/private/offline/locked/denied/accessibility/manual fallback and redacted evidence are mapped. |
| M51-N | Independent review confirms M51 is readiness-only and a separate implementation approval remains required. |

## 10. Explicit deferrals and honest limits

M51 does not implement or verify:

- Swift coordinator code, metadata files, parser types, injected adapters, writer barriers, backup wrappers, or UI changes;
- M0/M47/M48 runtime, M45 capture, WISP/M5/M2, models/training, research, MCP, sync, connectors, OS automation, cloud backup, or release;
- power-loss durability, filesystem crash consistency, distributed transactions, secure/forensic deletion, disaster-recovery RPO/RTO, compliance, production readiness, or ship readiness;
- a claim that Codable, actors, WAL, Online Backup, FileManager replacement, NSFileCoordinator, fsync, or a mock VFS is sufficient without target-specific evidence.

**M51 is complete as a documentation-only implementation-readiness plan when its six work packages, 40 fixture mappings, 14 gates, explicit interfaces, codec/record contract, lifecycle/barrier/closure/publication sequence, failure-injection map, browser fallback, evidence envelope, and independent review are structurally validated.**

## 11. Primary references and claim limits

- [SQLite Online Backup API](https://www.sqlite.org/backup.html) — live consistent snapshot mechanics and limitations.
- [SQLite `sqlite3_backup_step`](https://www.sqlite.org/c3ref/backup_step.html) — `SQLITE_DONE`, retryable, and fatal outcomes.
- [SQLite `sqlite3_backup_finish`](https://www.sqlite.org/c3ref/backup_finish.html) — finish/cleanup and prior-error behavior.
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html) — unfinished statements/backup handles and `SQLITE_BUSY` behavior.
- [SQLite WAL](https://www.sqlite.org/wal.html) — readers, single writer, checkpoints, and sidecar limits.
- [SQLite transactions](https://www.sqlite.org/lang_transaction.html) — per-database transaction boundaries.
- [SQLite busy timeout](https://www.sqlite.org/c3ref/busy_timeout.html) — bounded lock waiting.
- [Apple Application Support](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/WhereToPutFiles/WhereToPutFiles.html) — persistent local-data placement.
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox) — container and entitlement boundary.
- [Apple FileManager replacement](https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:)) — item replacement and same-volume limits.
- [Apple NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator) — cooperative file coordination, not database semantics.
- [Swift actors and concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) — isolation, reentrancy, and cancellation constraints.

These references establish platform/library limits. M51’s interfaces, record schema, lifecycle, writer barrier, failure map, fixture matrix, browser fallback, and evidence gates are Hive-specific contracts. They require a separately approved implementation and fresh runtime evidence before any capability status changes.
