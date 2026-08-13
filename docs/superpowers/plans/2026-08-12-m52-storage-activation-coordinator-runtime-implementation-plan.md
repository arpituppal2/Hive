# Hive M52 — StorageActivationCoordinator Runtime Implementation Plan

> **Date:** 2026-08-12
> **Status:** planning canon; implementation-approval plan; no runtime edits authorized in this planning pass
> **Roadmap label:** M52 StorageActivationCoordinator Runtime Implementation
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m51-storage-activation-coordinator-implementation-readiness-plan.md`
> **Architecture decision:** `docs/superpowers/plans/2026-08-12-m50-storage-activation-coordinator-architecture-decision-plan.md`
> **Related contracts:** M0 storage/recovery, M46 readiness, M47 runtime execution, M48 activation, M49 owner block
> **Participant set:** `{Honeycomb, EventLedger}` only
> **Next boundary:** separately approved execution of this exact allowlist, followed by M53 runtime evidence review
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M52 is the first plan that may authorize a narrowly bounded Swift implementation, but this document itself does not edit or authorize code. A later execution turn must explicitly approve M52, re-audit the checkout, confirm the allowlist, and stop on any changed-path expansion.

## 0. Decision summary

**Decision: prepare a separately approved, allowlisted runtime implementation; do not implement in this planning pass.**

M50 approved the architecture. M51 made the architecture implementation-ready. M52 turns that readiness contract into an executable sequence while preserving the hard boundary: the coordinator owns one bounded activation metadata record and selection lifecycle, while Honeycomb and EventLedger remain authoritative for their own contents, schemas, migrations, deletion semantics, and evidence.

Recommended sequence:

```text
A. Freeze adapters and ownership
  → B. Implement bounded record codec
    → C. Implement filesystem publication adapter
      → D. Implement coordinator actor/state machine
        → E. Integrate startup/degraded browser projection
          → F. Run deterministic fault-injection and evidence suite
```

A full vertical slice before ownership and codec checks is rejected. The coordinator actor must not be written first because that would encourage raw SQLite-handle transfer, implicit writer authority, or an accidental second durable store.

## 1. Binding constraints

### 1.1 Participant and authority boundary

The only runtime participants are:

```text
{Honeycomb, EventLedger}
```

The coordinator owns exactly one canonical bounded `ActiveSetRecord` and its publication/selection lifecycle. It is not a product-data authority, not a database authority, not a second ledger, not a backup service, not a migration owner, and not a distributed transaction manager.

Forbidden additions:

- coordinator-owned SQLite database;
- coordinator-owned second ledger or append-only evidence store;
- raw Honeycomb/EventLedger content, snapshots, FTS, event rows, prompts, page text, credentials, cookies, screenshots, or model context;
- WISP/M5 registration or scope;
- new global singleton authority, network path, connector, sync path, or OS action;
- direct access to raw SQLite pointers from the coordinator actor; no raw SQLite-handle transfer across the coordinator boundary;
- a changed-path expansion without a new approval.

### 1.2 Status and approval boundary

M52 planning is not runtime verification. Passing a plan validator, compiling a future actor, passing mock tests, or successfully replacing a file does not prove crash consistency, power-loss durability, multi-database atomicity, production readiness, or ship readiness.

Implementation may begin only when a separate approval records:

```text
m52_approved = true
source_revision = exact checkout revision
changed_paths = exact allowlist below
participant_set = {Honeycomb, EventLedger}
implementation_owner = named owner
rollback_owner = named owner
review_owner = named reviewer
stop_conditions = accepted
```

## 2. Exact changed-path allowlist

A future execution pass may change only these paths:

```text
Sources/HiveCore/Activation/ActivationMetadata.swift
Sources/HiveCore/Activation/ActivationMetadataCodec.swift
Sources/HiveCore/Activation/ActivationFileSystem.swift
Sources/HiveCore/Activation/StorageActivationCoordinator.swift
Sources/HiveCore/Activation/StoreParticipant.swift
Sources/HiveCore/Activation/ActivationEvidence.swift
Sources/HiveCore/Activation/ActivationErrors.swift
Tests/HiveCoreTests/Activation/ActivationMetadataTests.swift
Tests/HiveCoreTests/Activation/ActivationFileSystemTests.swift
Tests/HiveCoreTests/Activation/StorageActivationCoordinatorTests.swift
Tests/HiveCoreTests/Activation/ActivationFaultInjectionTests.swift
```

The execution pass may add the `Sources/HiveCore/Activation/` directory and `Tests/HiveCoreTests/Activation/` directory if absent. It may not modify `HoneycombStore.swift`.

It may not modify `EventLedgerStore.swift`.

It may not modify `HandoffRecoveryJournal.swift`.

It may not modify browser persistence or UI in the initial M52 slice.

It may not modify `Package.swift` in the initial M52 slice.

It may not modify entitlements or unrelated tests in the initial M52 slice.

If existing store APIs cannot satisfy the participant protocol without editing their source files, stop and open M52-A2 as a new decision. Do not smuggle conformance, lifecycle changes, or writer barriers into unrelated files. An extension in an allowlisted Activation file is permitted only if it calls already-public, already-tested store APIs and does not access private SQLite state.

## 3. Work packages

## 3.1 M52-A — Freeze adapters and ownership

### Goal

Bind the future coordinator to typed participant adapters without transferring raw SQLite handles or silently taking ownership of existing stores.

### Required implementation

- Define `StoreParticipant` with Sendable identity/health/deletion-floor snapshots and async barrier methods.
- Define an adapter boundary that accepts existing store instances only through public APIs.
- Define explicit ownership for every connection, prepared statement, backup, transaction, and close operation.
- Reject construction when a required direct writer is outside the barrier.
- Ensure Honeycomb and EventLedger remain separate adapters and separate authorities.
- Define idempotent barrier release and cancellation cleanup.

### Acceptance

- No coordinator method accepts `OpaquePointer`.
- No adapter claims ownership of a store’s private handle.
- No participant registration for WISP or M5 exists.
- A synthetic direct-writer bypass test fails closed.

## 3.2 M52-B — Implement bounded metadata and codec

### Goal

Implement the single activation record without creating product storage.

### Record

```text
ActiveSetRecord {
  format_version
  generation
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

### Required implementation

- Use a bounded canonical representation with deterministic bytes and a documented maximum size.
- Reject unknown authority-bearing fields, malformed encoding, oversized records, unsafe paths, raw content, secrets, prompts, cookies, private URLs, screenshots, and unbounded diagnostics.
- Make generation monotonic and state transitions explicit.
- Hash exactly the canonical bytes described by the record.
- Keep codec errors typed and redacted.
- Add golden fixtures for accepted and rejected records.

The codec must not encode Honeycomb nodes, EventLedger rows, database paths as authority, or any data that would make the coordinator a second product store.

## 3.3 M52-C — Implement filesystem publication adapter

### Goal

Stage, validate, publish, quarantine, and select the one canonical metadata record using an owner-contained application path.

### Required implementation

- Resolve the Application Support/container path through an injected filesystem dependency.
- Reject paths outside the approved container.
- Write bounded staged bytes, flush according to the documented platform contract, and publish within the same container/volume.
- Use one named publication primitive and record its platform limits; do not imply it proves power-loss durability.
- Preserve the prior complete record until the candidate validates.
- Quarantine malformed, unsupported, hash-mismatched, interrupted, or permission-denied artifacts.
- Return typed outcomes: `published`, `preservedPriorGeneration`, `quarantinedCandidate`, `blockedNoPriorGeneration`, `canceled`, `permissionDenied`, `ioFailure`, `unsupportedFilesystem`.

No filesystem adapter may open or copy a Honeycomb/EventLedger database. WAL sidecars are store-owned and are never treated as standalone database snapshots.

## 3.4 M52-D — Implement coordinator actor and state machine

### Goal

Serialize activation decisions while preserving actor reentrancy and store ownership.

### Required state machine

```text
idle
  → preparing
  → barriersAcquired
  → candidateValidated
  → preparedPublished
  → reopening
  → committed
  → superseded

failure at any phase → quarantined | blocked | canceled
```

`PREPARED` metadata is never startup-selectable. `COMMITTED` is selectable only after both participants reopen and return matching identities, schemas, health, and deletion floors.

### Required implementation

- Serialize one activation operation at a time by operation identity.
- Revalidate generation and operation identity after every `await` boundary.
- Acquire participant barriers before any candidate publication.
- Call only typed participant methods; never touch raw SQLite handles.
- Release barriers exactly once on success, cancellation, timeout, and every thrown error.
- Preserve the prior complete generation on candidate failure.
- Never select Honeycomb and EventLedger from different generations.
- Keep startup selection separate from candidate publication.
- Make cancellation cooperative and observable.

## 3.5 M52-E — Integrate startup and browser-first degraded projection

### Goal

Expose activation status without turning storage failure into browser failure.

### Required implementation

- Add only the smallest startup integration point needed to call coordinator selection.
- Keep navigation, tabs, private windows, ordinary rendering, keyboard, accessibility, offline browsing, and manual work available when activation fails.
- Mark memory/audit-dependent operations typed unavailable, degraded, or blocked.
- Never show in-memory state as durable success.
- Never invoke a model or network path because activation failed; there must be no model/network call caused by activation failure.
- Expose bounded retry/export/limitation status through the existing health projection if it can be reached without modifying unrelated UI files.

If the existing UI/startup seam requires a non-allowlisted Swift edit, stop before integration and open M52-E2 as a new approval rather than expanding M52 silently.

## 3.6 M52-F — Deterministic fault injection and evidence

### Goal

Prove the implementation’s typed failure behavior without claiming physical crash guarantees.

### Required injection points

- codec encode/decode/hash;
- path resolution and containment;
- staged file write/flush/replace/quarantine;
- barrier acquire/release/timeout;
- store health/identity/deletion floor;
- candidate validation;
- reopen and commit;
- cancellation at every `await` phase;
- evidence emission.

### Required outcomes

Every injected failure must preserve the prior complete generation where available, reject mixed/prepared generations, release all resources/barriers, avoid empty durable stores, prevent deletion regression/resurrection, return bounded redacted evidence, and keep ordinary browsing usable.

## 4. Runtime state and error contracts

### 4.1 Typed runtime result

```text
ActivationResult {
  operation_id
  observed_state
  active_generation
  selected_snapshot_id
  participant_identities
  limitation
  evidence_scope
}
```

A result is not `published` or `committed` merely because a file API returned success. It must include matching participant evidence and a successful reopen/revalidation step.

### 4.2 Typed hard failures

At minimum:

```text
participantUnavailable
writerBarrierTimeout
writerBypassDetected
staleOperation
staleGeneration
malformedMetadata
unsupportedFormat
oversizedMetadata
identityMismatch
schemaMismatch
deletionsNotReconciled
backupIncomplete
sqliteBusy
sqliteLocked
sqliteCloseBusy
publicationFailed
permissionDenied
quarantineFailed
canceled
noCompleteGeneration
```

Errors must not carry raw page content, secrets, prompts, cookies, private URLs, screenshots, full SQL, full paths, or full database diagnostics.

## 5. Failure, rollback, and stop conditions

The future execution pass must stop and leave the tree in a reviewable state if any condition occurs:

- an allowlisted file needs to open a coordinator SQLite database or create a second ledger;
- any coordinator record contains product objects, raw store data, model context, credentials, or unbounded paths;
- a direct durable writer bypasses the participant barrier;
- a raw SQLite handle crosses the coordinator/adapter boundary;
- a `PREPARED`, mixed-generation, hash-mismatched, stale, or quarantined record is selectable;
- `SQLITE_BUSY`, `SQLITE_LOCKED`, incomplete backup, `sqlite3_close` failure, cancellation, or permission denial is classified as success;
- a stale actor resumes after `await` without operation/generation revalidation;
- deletion continuity is missing or an old snapshot could resurrect a later deletion;
- a required startup/UI path is outside the allowlist;
- WISP/M5/M45/M2 scope is introduced;
- browser/private/offline/accessibility/manual fallback weakens;
- evidence claims power-loss durability, crash consistency, multi-database atomicity, production readiness, or ship readiness without target-specific proof.

Rollback means: quarantine any candidate artifact, preserve the prior complete metadata record, release barriers/resources, retain bounded evidence, and return a typed blocked/degraded result. Do not reset or discard unrelated user work.

## 6. Evidence and validation contract

### 6.1 Evidence envelope

Every runtime test result binds:

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

Evidence is synthetic/local/bounded and excludes raw content, secrets, full database dumps, private URLs, credentials, cookies, prompts, screenshots, arbitrary absolute paths, and unbounded logs.

### 6.2 Required test families

1. Metadata golden encode/decode/hash and all rejection classes.
2. Actor serialization, stale-await rejection, operation cancellation, and exactly-once barrier release.
3. Filesystem containment, same-container publication, interruption, quarantine, permission, and prior-record preservation.
4. Participant identity/schema/health/deletion-floor mismatch.
5. Backup/statement/transaction/connection closure through adapter-level fault doubles.
6. Startup committed selection, prepared/mixed/malformed/unsupported rejection, and no-prior-generation block.
7. Deletion-generation continuity and no-resurrection projections.
8. Browser-first degraded fallback with fatal coordinator injection.
9. Privacy/redaction and no model/network widening.
10. Adversarial direct-writer, second-ledger/database, WISP/M5 registration, and path-escape tests.

Tests are evidence of implemented test behavior, not proof of power-loss durability or production status.

## 7. Implementation handoff and approval packet

A later execution pass may start only with this packet:

```text
m52_approved = true
source_revision
changed_paths = exact allowlist
participant_set = {Honeycomb, EventLedger}
implementation_owner
rollback_owner
review_owner
codec_version_and_max_size
publication_primitive_and_platform_limits
participant_adapter_owner_map
writer_barrier_owner_map
failure_injection_map
browser_fallback_map
known_limitations
stop_conditions_accepted
```

Any additional Swift path, Package.swift change, entitlement change, schema migration, UI integration, or participant requires a new approval and a new plan revision.

## 8. Twenty-four M52 gates

| Gate | Requirement |
|---|---|
| M52-A | Separate approval records exact checkout, owner, allowlist, participant set, rollback owner, and stop conditions. |
| M52-B | Allowlisted adapters preserve Honeycomb/EventLedger ownership and never accept raw SQLite handles. |
| M52-C | No direct durable writer bypasses the participant barrier. |
| M52-D | Codec uses bounded canonical bytes, typed rejection, and exact hash input. |
| M52-E | Codec rejects unknown authority fields, raw content, secrets, unsafe paths, and oversized records. |
| M52-F | Filesystem path is injected, owner-contained, same-container, and platform-limited. |
| M52-G | Publication preserves prior complete generation and quarantines failed candidates. |
| M52-H | Coordinator actor serializes operations and rejects duplicate concurrent publication. |
| M52-I | Every await revalidates operation/generation identity. |
| M52-J | Participant handles/statements/backups/transactions remain participant-owned. |
| M52-K | Backup/close/busy/locked/cancellation outcomes fail closed. |
| M52-L | PREPARED is never selectable; COMMITTED requires reopen/revalidation. |
| M52-M | Mixed-generation and identity/schema mismatches are rejected. |
| M52-N | Deletion-generation continuity prevents resurrection. |
| M52-O | Startup quarantine and prior-generation fallback are deterministic. |
| M52-P | No-prior-generation state is blocked/degraded, never silently empty-success. |
| M52-Q | Browser/private/offline/accessibility/manual fallback remains usable. |
| M52-R | Storage failure does not widen model/network context. |
| M52-S | Fault injection covers I/O, permissions, close, backup, barrier, cancellation, and stale actor paths. |
| M52-T | Evidence is bounded, redacted, trace-bound, and limitation-bound. |
| M52-U | No coordinator database, second ledger, product-data authority, WISP, or M5 scope exists. |
| M52-V | Tests distinguish synthetic runtime evidence from production/power-loss claims. |
| M52-W | Independent review finds no authority inflation or changed-path expansion. |
| M52-X | Separate M53 runtime evidence review remains required before any capability status promotion. |

## 9. Explicit deferrals and honest limits

M52 does not claim:

- power-loss durability, filesystem crash consistency, secure deletion, disaster recovery, compliance, production readiness, or ship readiness;
- that SQLite WAL/main-file copying is a valid snapshot;
- that `FileManager.replaceItemAt`, POSIX rename, `NSFileCoordinator`, `fsync`, actors, mocks, or successful API returns independently prove the cross-store contract;
- that Honeycomb and EventLedger form a distributed transaction;
- that M52 runtime evidence verifies WISP, M5, M45, M2, sync, connectors, OS automation, models, training, or browser-wide product quality.

**M52 is complete as a planning artifact when the allowlist, six work packages, typed states/errors/results, rollback/stop conditions, evidence contract, 24 gates, and independent review are structurally validated.**

## 10. Primary references and claim limits

- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [SQLite `sqlite3_backup_step`](https://www.sqlite.org/c3ref/backup_step.html)
- [SQLite `sqlite3_backup_finish`](https://www.sqlite.org/c3ref/backup_finish.html)
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html)
- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite transactions](https://www.sqlite.org/lang_transaction.html)
- [SQLite busy timeout](https://www.sqlite.org/c3ref/busy_timeout.html)
- [Apple Application Support](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/WhereToPutFiles/WhereToPutFiles.html)
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Apple FileManager replacement](https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:))
- [Apple NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
- [Swift actors and concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift cancellation](https://developer.apple.com/documentation/swift/task/iscancelled)

These references establish platform/library limits. The changed-path allowlist, adapter ownership, codec, actor state machine, fallback, evidence, and gates are Hive-specific contracts requiring separate approval and fresh runtime evidence.
