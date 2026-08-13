# Hive M57 — Store-Owned Lifecycle Implementation-Readiness Contract

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; runtime remains BLOCKED
> **Roadmap label:** M57 Store-Owned Lifecycle Implementation Readiness
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m56-storage-authority-redesign-decision-plan.md`
> **Related plans:** M50 architecture decision, M51 readiness, M52 runtime implementation, M53 evidence review, M54 preflight, M55 API-boundary block
> **Participant set:** `{Honeycomb, EventLedger}` only
> **Target:** Option C store-owned, actor-isolated lifecycle protocols with typed participant adapters
> **Current disposition:** `BLOCKED`; M57 cannot issue implementation `GO`.

Current disposition: `BLOCKED`. M57 cannot issue `GO` for implementation or status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M57 converts M56’s planning-selected architecture into a bounded readiness contract. It does not edit Swift, add protocol conformances, open real stores, run a synthetic pilot, authorize M52, or promote any capability status.

## 0. Decision summary

**Decision: retain `BLOCKED` for production implementation.**

M56 Option C — store-owned lifecycle protocols — is the target architecture, but the repository still lacks the source, owner, writer, migration, resource, and evidence mapping required to approve a real implementation. M57 defines that mapping and the exact conditions under which a later decision may remain `BLOCKED`, become `HOLD`, authorize a synthetic `SPLIT`, or prepare a separately reviewed implementation `GO`.

M57 itself cannot issue `GO`. A future implementation approval must follow M57 and M53, use a newly approved changed-path allowlist, and bind one exact source revision, environment, owner set, rollback plan, and evidence scope.

## 1. Binding architecture and authority

### 1.1 Participants

The production participant set remains exactly:

```text
{Honeycomb, EventLedger}
```

Honeycomb owns knowledge schema, migrations, nodes/edges, provenance, retrieval data, and logical deletion. EventLedger owns append-only evidence events, consent/action history, event schema/migrations, and ledger deletion semantics. A future coordinator may project bounded activation metadata but may not become a product-data, schema, migration, deletion, or evidence authority.

### 1.2 Forbidden expansion

M57 must not authorize or imply:

- a coordinator SQLite database;
- a second ledger or append-only evidence store;
- product-data snapshots or shadow tables;
- raw `OpaquePointer`, `sqlite3 *`, prepared statements, file descriptors, or arbitrary SQL across an actor/protocol boundary;
- migration or deletion truth outside the owning store;
- WISP/M5 registration or any new participant;
- model, network, connector, OS, telemetry, credential, or permission expansion;
- private-mode, offline, accessibility, manual, or browser-first fallback changes;
- runtime recovery, production, power-loss, crash-consistency, cross-store atomicity, secure-deletion, compliance, or ship claims from planning or synthetic evidence.

### 1.3 M56/M55 status remains binding

The following remain blocked:

- M52 real-store runtime implementation;
- production Honeycomb/EventLedger participant conformance;
- active-set publication and startup selection;
- writer-barrier integration;
- real backup/restore/close/reopen coordination;
- M53 runtime evidence for an unapproved implementation;
- any promotion to `code-present` or `verified` for the coordinator/runtime slice.

A synthetic M55 SPLIT may be separately approved, but M57 does not authorize it. Synthetic evidence cannot promote M52, M53, or any capability status.

## 2. Readiness packet: required fields

A future M57 disposition must bind one bounded packet containing:

```text
m57_packet_id
source_revision
working_tree_identity
working_tree_state
m55_block_reference
m56_target_reference
participant_set
owner_map
source_symbol_map
changed_path_classes
package_target_map
public_boundary_map
private_resource_map
direct_writer_inventory
writer_barrier_map
schema_migration_map
delete_generation_map
backup_checkpoint_close_map
actor_sendable_cancellation_map
startup_browser_fallback_map
privacy_redaction_rules
synthetic_split_allowlist
future_implementation_allowlist
implementation_owner
rollback_owner
independent_reviewer
m53_owner
stop_conditions
known_limitations
next_smallest_action
owner_acknowledgement
```

The packet must contain bounded references, not raw databases, private page content, URLs, credentials, cookies, screenshots as sole evidence, absolute user paths, model/network payloads, or unbounded logs. Every negative finding must state the searched paths/symbols and what the search cannot establish.

## 3. Owner-by-owner source contract

Before implementation approval, the following map must be complete:

| Capability | Owning authority | Required source evidence | Readiness result if absent |
|---|---|---|---|
| Store identity | Honeycomb/EventLedger respectively | Exact initializer/type/symbol and stable identity semantics | BLOCK |
| Health/integrity | Owning store actor | Typed diagnostic result and bounded failure classes | BLOCK |
| Schema/version | Owning store | Store-owned version/migration observation | BLOCK |
| Writer admission | Each store | Complete direct-writer inventory and barrier coverage | BLOCK |
| Backup/snapshot | Each store | Store-owned backup/checkpoint resource lifecycle | BLOCK |
| Close/reopen | Each store | Actor-owned statement/connection closure and reopen state | BLOCK |
| Deletion continuity | Each store | Generation/floor/tombstone semantics and restart behavior | BLOCK |
| Recovery evidence | Store plus EventLedger | Typed result and append-only event reference without second ledger | BLOCK |
| Activation projection | Future coordinator | Bounded metadata only; no product-data authority | BLOCK if widened |
| Browser fallback | Browser owner | Existing unavailable/degraded/manual path remains usable | BLOCK if weakened |

Source presence, comments, protocol names, mocks, and inferred behavior do not satisfy a row.

## 4. Typed target contract

This is a readiness target, not an implementation approval. A future plan must define immutable, bounded, `Sendable` values equivalent to:

```text
StoreIdentity
StoreHealth
StoreSchema
WriterAdmission
StoreSnapshot
StoreLifecycle
DeletionContinuity
ParticipantEvidence
```

The future boundary must enforce:

- lifecycle operations execute within the owning store actor/resource boundary;
- no raw SQLite resource crosses the boundary; the typed boundary is a raw-handle-free lifecycle boundary;
- no arbitrary SQL or free-form user data appears in participant results;
- every direct durable writer is admitted, blocked during quiescence, or documented as a proved exception;
- actor isolation is accompanied by reentrancy and cancellation semantics;
- typed errors distinguish unavailable, degraded, blocked, cancelled, incomplete, and unknown outcomes;
- backup/checkpoint/close/reopen report resource completion only after statements and connections are finalized according to the store owner’s contract;
- migrations remain store-owned and cannot be executed by the coordinator;
- deletion generations prevent restored or stale data from reappearing;
- coordinator metadata cannot become a third database, second ledger, or product cache.

Swift actor isolation and `Sendable` are compile-time aids, not proof of semantic writer coverage, SQLite crash recovery, or multi-process file coordination. Those require explicit source inventory and runtime evidence in M53.

## 5. Changed-path classes

M57 defines classes for a future approval; it does not approve any class:

### Class A — Store-owner changes

Potentially includes the existing HoneycombStore and EventLedgerStore files or explicitly approved same-target companion files. Any change here requires a new architecture implementation decision because it changes production authority surfaces.

### Class B — Typed boundary/adapters

Potentially includes new lifecycle value types and coordinator adapters. Class B cannot satisfy missing behavior by itself and cannot access private store state.

### Class C — Synthetic-only tests

May include fake participants, metadata codecs, injected filesystem tests, deterministic state machines, and fault-injection tests. It must not open real databases, access SQLite handles, read Application Support user data, or alter startup/browser state. Synthetic SPLIT must not open real databases and cannot establish real-store lifecycle or runtime recovery.

### Class D — Browser projection

Potentially includes persistence-health/degraded-state UI and startup projection only after real store behavior has passed its own evidence gates. It cannot be included merely to make a plan appear user-visible.

A future approval must list exact paths, target membership, owner, and rollback for every class. “Activation directory” or “storage module” without exact paths is not an allowlist.

## 6. Evidence required before a future implementation `GO`

### 6.1 Static/source evidence

- exact source revision and dirty-tree disposition;
- all public/internal durable writer symbols inventoried;
- owner and actor/resource boundary for every lifecycle operation;
- target/package membership and access-control map;
- no raw handle or arbitrary SQL crossing the typed boundary;
- exact changed-path allowlist and excluded-path check.

### 6.2 Focused compile/test evidence

- Swift 6 strict-concurrency diagnostics reviewed;
- `Sendable` and actor-isolation boundaries compile without unsafe escape hatches;
- target-specific tests exercise typed lifecycle errors and cancellation;
- test-only access is not mistaken for production access;
- no build or test result is labeled runtime verification by itself.

### 6.3 Store-local SQLite evidence

Before a coordinator adapter is approved, each store owner must separately evidence. Required migration/recovery evidence includes WAL, shared-memory, checkpoint, backup handling; interrupted migrations; and deletion floor/tombstone continuity.

- WAL/single-writer behavior and bounded busy handling;
- checkpoint behavior under concurrent reads/writes;
- Online Backup API or an explicitly justified store-owned snapshot mechanism;
- statement finalization and connection close/reopen;
- migration transaction rollback and interrupted-migration recovery;
- schema/version compatibility and unknown-version refusal;
- deletion generation/floor and non-resurrection after restore/restart;
- cancellation and incomplete/unknown result handling.

### 6.4 Browser and privacy evidence

- browser navigation, tabs, private mode, offline mode, accessibility, and manual fallback work with storage activation unavailable;
- storage failure does not widen model/network context;
- evidence packets redact user content and credentials;
- no model, network, connector, or OS action is triggered by a storage failure;
- startup does not silently replace a corrupt store with an empty store.

### 6.5 M53 handoff evidence

A future implementation must hand off to M53 with one source revision, environment identity, evidence scope, independent review, and explicit owner decision. M53’s source/diff, build/test, fault, restart/recovery, manual browser, and independent-review tiers remain mandatory.

## 7. Disposition rubric

### `BLOCKED` — current and default

Use `BLOCKED` when any required owner, direct writer, lifecycle resource, migration/deletion authority, changed path, or evidence tier is missing or contradictory. This is the current M57 disposition.

### `HOLD`

Use `HOLD` only when the source contract is not contradicted but one bounded fact is missing. HOLD names the smallest missing packet item and does not authorize code, store access, or a pilot.

### `SPLIT`

Use `SPLIT` only for separately approved synthetic work: pure codecs, fake participants, injected filesystem behavior, deterministic state machines, and fault-injection tests. Synthetic SPLIT cannot establish real-store lifecycle, runtime recovery, browser behavior, or status promotion; a synthetic SPLIT cannot establish real-store lifecycle. It cannot establish runtime recovery.

### `TARGET_READY_FOR_REVIEW`

This label means the documentation packet is complete enough for a separate owner review of an implementation plan. It does not mean implementation-approved, code-present, or verified.

### `GO`

M57 cannot issue `GO`. A future decision may issue `GO` only after the exact owner/source/path contract, implementation plan, rollback, M53 linkage, and owner acknowledgement pass independently.

## 8. Migration, recovery, and rollback contract

A future implementation plan must define, separately for Honeycomb and EventLedger:

- schema ownership and migration version transitions;
- unknown-version and interrupted-migration behavior;
- WAL, shared-memory, checkpoint, backup, and quarantine artifact handling;
- close/reopen behavior across sleep, lock, crash, cancellation, and storage failure;
- deletion floor/tombstone continuity and restore non-resurrection;
- EventLedger evidence binding without a second ledger;
- recovery result states that distinguish applied, partial, blocked, unavailable, cancelled, and unknown;
- browser startup continuation with an explicit degraded/unavailable projection.

No plan may claim power-loss durability, crash consistency, secure deletion, or cross-store atomicity from this contract alone.

## 9. Stop and non-destructive rollback

Stop planning or future implementation preparation if:

- a new path is needed without an explicit path decision;
- a direct writer is omitted or bypasses the barrier;
- a raw SQLite handle, prepared statement, file descriptor, or arbitrary SQL crosses the boundary;
- the coordinator gains product data, events, a second ledger, or a database;
- migration/deletion/schema truth moves out of its owning store;
- private/offline/accessibility/manual/browser fallback is weakened;
- storage failure widens model/network context or blocks ordinary navigation;
- synthetic evidence is labeled runtime, recovery, `code-present`, or `verified`;
- unrelated dirty user work would be reset, cleaned, overwritten, or discarded.

Rollback means stop, preserve the dirty worktree, quarantine disposable artifacts, record the disposition and limitation, and return to `BLOCKED`/`HOLD`. Do not use destructive git cleanup.

## 10. M57 gates

| Gate | Requirement |
|---|---|
| M57-A | M56 target and current M55/M56 BLOCK are reproduced. |
| M57-B | Exact participant set is `{Honeycomb, EventLedger}`. |
| M57-C | Owner-by-owner authority map is complete or disposition remains BLOCKED. |
| M57-D | All direct durable writers are inventoried or disposition remains BLOCKED. |
| M57-E | Exact source symbol and access-control map exists. |
| M57-F | Exact changed-path classes and excluded paths are recorded. |
| M57-G | Package target membership and test-only boundaries are recorded. |
| M57-H | Typed lifecycle contract is bounded, Sendable, and raw-handle-free. |
| M57-I | Actor isolation, reentrancy, cancellation, and typed failure states are explicit. |
| M57-J | Writer admission/barrier coverage is required for every writer. |
| M57-K | Store-owned backup/checkpoint/close/reopen evidence is required. |
| M57-L | Store-owned schema/migration and unknown-version behavior is required. |
| M57-M | Deletion generations/tombstones and restore non-resurrection are required. |
| M57-N | Synthetic SPLIT allowlist is separated from any real-store allowlist. |
| M57-O | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M57-P | Storage failure cannot widen model/network context. |
| M57-Q | No coordinator database, second ledger, product-data authority, or new participant is proposed. |
| M57-R | Evidence packet fields and redaction limitations are complete. |
| M57-S | M53 evidence tiers and owner handoff are bound to one future source revision. |
| M57-T | Current disposition is BLOCKED; M57 cannot issue GO. |
| M57-U | HOLD and SPLIT meanings do not authorize implementation or status promotion. |
| M57-V | Migration/recovery/rollback limits are explicit and non-destructive. |
| M57-W | Platform facts are distinguished from Hive governance decisions. |
| M57-X | Independent review is required before any future runtime claim. |

## 11. Honest limits and references

M57 does not implement or verify lifecycle protocols, store barriers, backup/restore, close/reopen, migrations, deletion continuity, active-set publication, browser startup, crash recovery, power-loss durability, cross-store atomicity, secure deletion, production readiness, compliance, or ship readiness.

Primary references:

- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html)
- [SQLite threading modes](https://www.sqlite.org/threadsafe.html)
- [SQLite transactions](https://www.sqlite.org/lang_transaction.html)
- [Swift Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift Package Manager](https://www.swift.org/documentation/package-manager/)
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Apple Application Support](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/WhereToPutFiles/WhereToPutFiles.html)
- [Apple FileManager replacement](https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:))

These sources establish platform and library limits. M57’s readiness contract, current BLOCK, path/owner/evidence requirements, disposition rubric, gates, and no-status-promotion rules are Hive governance decisions.

**M57 is complete as a planning artifact when its owner/source/path contract, target lifecycle boundary, writer inventory requirement, migration/recovery evidence, disposition rubric, 24 gates (M57-A through M57-X), stop/rollback rules, M53 handoff, and independent review are structurally validated.**
