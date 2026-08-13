# Hive M55 — StorageActivationCoordinator HOLD Resolution & API Boundary

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; full M52 slice BLOCKED; synthetic SPLIT pilot only by separate approval
> **Roadmap label:** M55 StorageActivationCoordinator HOLD Resolution & API Boundary
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m54-storage-activation-coordinator-execution-approval-preflight-plan.md`
> **Implementation plan:** `docs/superpowers/plans/2026-08-12-m52-storage-activation-coordinator-runtime-implementation-plan.md`
> **Evidence review:** `docs/superpowers/plans/2026-08-12-m53-storage-activation-coordinator-runtime-evidence-review-plan.md`
> **Architecture decision:** `docs/superpowers/plans/2026-08-12-m50-storage-activation-coordinator-architecture-decision-plan.md`
> **Participant set:** `{Honeycomb, EventLedger}` only
> **Next boundary:** new architecture/scope decision for production adapters, or separately approved synthetic SPLIT pilot
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M55 resolves M54’s default HOLD using a source-backed public-API audit. It does not edit Swift, add protocol conformances, run a pilot, weaken M52, or authorize the full coordinator runtime.

## 0. Decision summary

**Decision: BLOCK the full M52 runtime slice; retain only a possible synthetic SPLIT pilot.**

The current public APIs do not satisfy the M52 `StoreParticipant` contract without changing excluded store internals or introducing new authority surfaces:

| Required participant capability | Honeycomb/EventLedger current public evidence | M55 result |
|---|---|---|
| Stable store identity | Path is accepted by `init(path:)`; no explicit public store identity is exposed | BLOCK for production adapter |
| Health/integrity state | No public health or integrity-check method | BLOCK |
| Schema version | `PRAGMA user_version` and schema versions are private/internal | BLOCK |
| Deletion floor/watermark | Deletion methods exist, but no global deletion-generation floor exists | BLOCK |
| Writer admission/barrier | Direct public writers exist; no barrier or admission API exists | BLOCK |
| Snapshot/backup | No public SQLite Online Backup/snapshot API exists | BLOCK |
| Close/reopen | `deinit` owns close; no public close/reopen lifecycle exists | BLOCK |
| Direct-writer inventory closure | Public mutation methods remain callable outside a coordinator barrier | BLOCK |

M54’s `GO` condition is therefore not met. This is no longer merely missing evidence: the source audit demonstrates a contract mismatch. M55 classifies the full M52 slice as `BLOCKED` until a new architecture/implementation decision addresses the missing authority boundary.

A synthetic `SPLIT` pilot may be considered only for bounded metadata codec, injected filesystem, fake participant, state-machine, and fault-injection tests. It cannot touch real Honeycomb/EventLedger connections, claim store integration, alter startup, modify browser behavior, or promote any capability. The fault-injection test path is synthetic only and cannot establish runtime recovery.

## 1. Binding boundary

### 1.1 What is blocked

The following remain blocked:

- full M52 `GO`;
- production `StoreParticipant` conformance for Honeycomb/EventLedger;
- writer-barrier integration with current direct writers;
- real snapshot/backup/close/reopen coordination;
- active-set publication or startup selection;
- browser startup/degraded-state integration;
- M53 runtime evidence collection for M52;
- any status promotion to `code-present` or `verified` for the coordinator runtime.

### 1.2 What remains permitted by planning

Documentation-only work may continue to:

- compare new authority designs;
- inventory exact public/private store seams;
- define a new explicit store lifecycle contract;
- define a synthetic fake-participant test contract;
- prepare a revised M52/M56 plan;
- document browser-first fallback and privacy limits.

No source edit is implied by these permissions.

### 1.3 Participant and privacy boundary

The only intended participants remain `{Honeycomb, EventLedger}`. WISP/M5 remain planned, blocked, and unregistered.

No pilot or future design may introduce:

- a coordinator database or second ledger;
- product-data storage or raw store snapshots in coordinator metadata;
- raw page text, browsing history, private URLs, credentials, cookies, prompts, screenshots, model context, or unbounded paths;
- model/network widening caused by storage failure;
- a new participant without a new architecture decision.

## 2. Exact source-backed findings

### 2.1 HoneycombStore

Current public construction is path-based through `init(path:)`. The actor owns a private `OpaquePointer?` and closes it in `deinit`. Public CRUD and deletion methods include node/edge insert, update, delete, provenance deletion, age deletion, and legacy purge. Schema migration, user-version inspection, WAL setup, foreign-key setup, SQL execution, and the database handle remain internal/private.

No public API currently provides:

```text
store identity
health/integrity result
schema version
logical deletion floor
writer admission/barrier
snapshot/backup
close/reopen
```

A wrapper that cannot access those private resources cannot truthfully implement M52’s participant contract.

### 2.2 EventLedgerStore

Current public construction is path-based through `init(path:)`. The actor owns a private `OpaquePointer?` and closes it in `deinit`. Public APIs append and query events and expose retention/deletion operations. Schema migration, user-version inspection, WAL setup, SQL execution, and the database handle remain internal/private.

No public API currently provides:

```text
store identity
health/integrity result
schema version
logical deletion floor
writer admission/barrier
snapshot/backup
close/reopen
```

Append-only event semantics do not create a writer barrier. Public `record`/`recordIfAbsent` calls remain direct durable writers outside a coordinator-controlled admission boundary.

### 2.3 Consequence

A Swift extension in an allowlisted Activation file cannot witness private store state. A test-target extension cannot create a production conformance. A fake wrapper around only public CRUD methods cannot claim backup, close, deletion-floor, or writer-barrier semantics. Raw `OpaquePointer` transfer would violate M52/M54 boundaries and actor/resource ownership.

## 3. Disposition rubric

### 3.1 Full-slice BLOCK

The full M52 slice remains `BLOCKED` until a new decision provides all of the following without hidden authority inflation:

- explicit store identity contract;
- typed health/integrity contract;
- store-owned schema/version observation;
- deletion-generation floor contract;
- writer admission/barrier contract covering every direct durable writer;
- snapshot/backup contract with resource ownership;
- explicit close/reopen lifecycle;
- failure and cancellation semantics;
- public/package-visible boundaries that preserve actor and SQLite ownership;
- migration/deletion/recovery ownership that remains separate for Honeycomb/EventLedger.

The new decision must state whether the required boundary is an intentional extension of the stores, a dedicated owner/helper with explicit handle ownership, or a different architecture. It may not simply add protocol names around unavailable behavior.

### 3.2 Synthetic SPLIT pilot

A separate approval may authorize a pilot limited to:

```text
Sources/HiveCore/Activation/ActivationMetadata.swift
Sources/HiveCore/Activation/ActivationMetadataCodec.swift
Sources/HiveCore/Activation/ActivationFileSystem.swift
Sources/HiveCore/Activation/StorageActivationCoordinator.swift
Sources/HiveCore/Activation/StoreParticipant.swift
Sources/HiveCore/Activation/ActivationEvidence.swift
Sources/HiveCore/Activation/ActivationErrors.swift
Tests/HiveCoreTests/Activation/ActivationMetadataTests.swift
Tests/HiveCoreTests/Activation/ActivationFaultInjectionTests.swift
Tests/HiveCoreTests/Activation/ActivationFileSystemTests.swift
Tests/HiveCoreTests/Activation/StorageActivationCoordinatorTests.swift
```

The pilot uses only fake `StoreParticipant` implementations and synthetic bounded artifacts. It must not:

- construct or open Honeycomb/EventLedger databases;
- access `OpaquePointer`, SQLite3, private store state, or real Application Support data;
- modify Package.swift, entitlements, existing store files, browser files, or UI;
- publish a real active set or change startup selection;
- claim resource closure, real writer admission, backup, recovery, or browser behavior;
- emit a `GO`, `code-present`, or `verified` result for M52.

The pilot’s only valid output is synthetic contract evidence and a recommendation for the next architecture decision. Synthetic evidence cannot promote M52, M53, or any capability status; no pilot result may be labeled `code-present` or `verified`.

## 4. Required next architecture decision

Before full M52 can return from BLOCK, a new decision must compare at least these options:

| Option | Description | M55 disposition |
|---|---|---|
| Extend existing stores | Add explicit public/package APIs for identity, health, schema, deletion floor, writer barrier, backup, close/reopen, and recovery ownership | Requires new plan and exact changed paths |
| Dedicated storage owner | Introduce an explicit owner that owns SQLite resources and exposes typed participant APIs without a second product-data authority | Requires new architecture decision and migration strategy |
| Store-level snapshot protocol | Keep current stores but define a typed, store-owned snapshot/activation protocol with lifecycle barriers | Requires proof that direct writers are enclosed |
| Keep blocked | Do not add active-set runtime until storage boundaries are redesigned | Safe default if ownership remains ambiguous |
| Synthetic-only progress | Continue codec/filesystem/state-machine tests with fake participants | Permitted only by separate SPLIT approval |

The decision must reject any option that creates a coordinator database, second ledger, raw product cache, private-handle leak, silent migration authority, or unbounded global singleton.

## 5. M55 evidence and audit packet

A M55 packet must bind:

```text
m55_packet_id
source_revision
working_tree_identity
working_tree_state
m54_packet_reference
m52_allowlist
participant_set
honeycomb_public_api_map
event_ledger_public_api_map
private_resource_map
direct_writer_map
missing_contracts
block_reason
pilot_allowlist_if_split
architecture_options
privacy_limits
browser_fallback_limits
owner
reviewer
next_smallest_action
```

Each finding must cite an exact source path/symbol or a bounded negative result. Negative findings must say how the search was performed and what it cannot establish. No raw databases, private content, credentials, screenshots as sole evidence, or unbounded logs may enter the packet.

## 6. M55 stop and rollback rules

Stop planning or pilot preparation if:

- a fake pilot opens a real store or uses real user data;
- an allowlisted file imports or accesses private store state;
- an adapter accepts a raw `OpaquePointer`/SQLite handle;
- a protocol name is used to imply behavior not implemented by a public boundary;
- a new coordinator database, second ledger, product-data cache, or unapproved participant appears;
- Package.swift, entitlements, existing stores, browser persistence, or UI becomes necessary without a new decision;
- browser/private/offline/accessibility/manual fallback is weakened;
- model/network context widens after a storage failure;
- synthetic evidence is labeled as runtime or production evidence.

Rollback is non-destructive: preserve the dirty worktree, remove no user changes, quarantine disposable pilot artifacts, record the block, and return to planning-only HOLD/BLOCK.

## 7. M55 gates

| Gate | Requirement |
|---|---|
| M55-A | M54 default HOLD and exact M52 allowlist are reproduced. |
| M55-B | Honeycomb public API inventory is complete and source-bound. |
| M55-C | EventLedger public API inventory is complete and source-bound. |
| M55-D | Private SQLite/resource ownership is explicitly mapped. |
| M55-E | Identity/health/schema/deletion-floor gaps are recorded. |
| M55-F | Writer-barrier/direct-writer gap is recorded. |
| M55-G | Backup/close/reopen gap is recorded. |
| M55-H | Full M52 slice is classified BLOCKED with a concrete reason. |
| M55-I | A synthetic SPLIT pilot is separately bounded or explicitly declined. |
| M55-J | Pilot cannot access real stores, SQLite handles, user data, or browser state. |
| M55-K | No Package.swift, entitlement, existing-store, browser, or UI edit is implied. |
| M55-L | `{Honeycomb, EventLedger}` remains the only intended participant set. |
| M55-M | WISP/M5 remain blocked and unregistered. |
| M55-N | No coordinator database, second ledger, product-data authority, or raw-handle transfer exists. |
| M55-O | Privacy, redaction, and browser-first fallback limits remain explicit. |
| M55-P | M53 cannot start until a future M52 execution is actually approved and evidenced. |
| M55-Q | Architecture options for resolving the block are named and compared. |
| M55-R | Owner, reviewer, and next-smallest-action fields are present. |
| M55-S | Negative API findings include search method and limitation. |
| M55-T | Synthetic evidence cannot promote M52 or any capability status. |
| M55-U | Stop/rollback rules preserve unrelated user work. |
| M55-V | Independent review confirms BLOCK/SPLIT boundaries and no scope weakening. |

## 8. Explicit deferrals and honest limits

M55 does not implement, execute, or verify:

- any Activation Swift file;
- Honeycomb/EventLedger/HandoffRecoveryJournal changes;
- Package.swift, entitlements, browser persistence, UI, or startup changes;
- M52 runtime, M53 evidence review, WISP/M5/M45/M2, models/training, sync, connectors, OS automation, cloud backup, release, compliance, production, or ship readiness;
- SQLite backup/close/recovery, writer-barrier, cross-database atomicity, power-loss durability, or browser behavior.

**M55 is complete as a planning artifact when its source-backed API findings, full-slice BLOCK, synthetic SPLIT boundary, architecture options, packet, 22 gates (M55-A through M55-V), stop rules, and independent review are structurally validated.**

## 9. Primary references and claim limits

- [Swift Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
- [Swift Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [Swift Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/extensions/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift Package Manager](https://www.swift.org/documentation/package-manager/)
- [SQLite threading](https://www.sqlite.org/threadsafe.html)
- [SQLite Online Backup](https://www.sqlite.org/backup.html)
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html)
- [SQLite WAL](https://www.sqlite.org/wal.html)

These references establish language, package, and SQLite limits. M55’s source-backed BLOCK, synthetic SPLIT boundary, no-runtime rule, participant/privacy boundaries, packet, and gates are Hive-specific governance decisions.
