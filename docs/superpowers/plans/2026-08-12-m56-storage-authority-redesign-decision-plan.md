# Hive M56 — Production Storage-Authority Redesign Decision

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; runtime remains BLOCKED by default
> **Roadmap label:** M56 Production Storage-Authority Redesign Decision
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m55-storage-activation-coordinator-hold-resolution-api-boundary-plan.md`
> **Related plans:** M50 architecture decision, M51 implementation readiness, M52 runtime implementation, M53 evidence review, M54 preflight
> **Participant set:** `{Honeycomb, EventLedger}` only
> **Target architecture:** store-owned, actor-isolated lifecycle protocols with typed participant adapters
> **Default disposition:** `BLOCKED` for M52 runtime and production adapters; target architecture is planning-selected, not implementation-approved
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M56 resolves the architectural question exposed by M55. It does not edit Swift, alter existing stores, add protocol conformances, run the M55 synthetic pilot, authorize M52, or promote any capability status.

## 0. Decision summary

**Default decision: keep the production runtime `BLOCKED`. Select Option C as the target architecture for a future implementation decision, but do not authorize implementation in M56.**

M55 established that the current Honeycomb/EventLedger public APIs cannot satisfy the M52 participant contract. The missing behavior is not safely recoverable by a wrapper in the M52 allowlist because the stores own private SQLite connections, migrations, deletion semantics, and direct writers. M56 therefore evaluates architecture rather than pretending an adapter can manufacture authority.

| Option | Summary | M56 disposition |
|---|---|---|
| A — Extend existing stores | Add explicit store-owned lifecycle APIs to Honeycomb/EventLedger while preserving each store’s authority | Candidate only; requires a new implementation plan and exact changed-path approval |
| B — Shared storage owner | Introduce a centralized owner or helper that coordinates both stores | Rejected as the default; high risk of a second authority, writer bypass, handle leakage, or coordinator database |
| C — Store-owned lifecycle protocols | Make each store actor own its lifecycle and expose typed, Sendable participant operations; coordinator consumes those operations without owning SQLite | **Planning-selected target**; no implementation authorized |
| D — Keep blocked | Defer all active-set/runtime work until a lawful owner and lifecycle contract exist | **Required current disposition** |

Option C is not a claim that the current code already has the contract. It is a design direction that must survive a later implementation plan, path review, migration review, and M53 evidence review.

## 1. Binding scope and non-negotiables

### 1.1 Participants and authority

The only intended production participants remain exactly:

```text
{Honeycomb, EventLedger}
```

Honeycomb remains authoritative for knowledge objects, schema/migrations, logical deletion, provenance, and retrieval data. EventLedger remains authoritative for append-only evidence events, consent/action history, and ledger deletion semantics. A coordinator may own only one bounded active-set metadata record and its publication state; it may not become a product-data authority.

M56 forbids:

- a coordinator SQLite database;
- a second ledger or append-only evidence store;
- a product-data cache or shadow copy;
- migration ownership outside the store that owns the schema;
- deletion truth outside the store that owns the deleted object/event;
- raw `OpaquePointer`, `sqlite3 *`, prepared statement, file descriptor, or connection transfer across actor/protocol boundaries;
- model, network, connector, OS, telemetry, credential, or browser-permission scope;
- WISP/M5 registration or implicit participant expansion;
- a silent change to private-mode, offline, accessibility, or manual browser fallback.

### 1.2 Current M55 block remains binding

Until a later implementation decision proves the required public contract, the following are blocked:

- M52 real-store runtime implementation;
- production Honeycomb/EventLedger participant conformance;
- active-set publication or startup selection;
- writer-barrier integration;
- real snapshot/backup/restore or close/reopen coordination;
- M53 runtime evidence collection for an unapproved implementation;
- any status promotion to `code-present` or `verified` for this coordinator/runtime slice.

A synthetic SPLIT pilot remains separately approvable under M55, but M56 does not authorize it and synthetic evidence cannot promote M52, M53, or any capability status.

## 2. Platform facts and claim limits

The following are platform/library constraints to be respected, not Hive-specific proof of correctness:

1. SQLite WAL supports concurrent readers with a single writer; writer admission must therefore be explicit and bounded rather than inferred from actor syntax.
2. SQLite backup, checkpoint, statement finalization, and connection close have resource-ordering requirements. A file path or copied WAL file is not by itself a consistent snapshot contract.
3. A `sqlite3 *` connection and prepared statements have ownership and lifetime rules. They must remain inside the store-owned execution boundary; a protocol must not expose the raw handle as a convenience.
4. Swift access control prevents an external wrapper from observing another file’s private state. `@testable` does not make private state production-accessible.
5. Swift actors provide isolation but do not automatically prevent reentrancy, direct calls through another path, or semantic writer bypass. The contract must cover all durable writer entry points.
6. Application Support and sandbox path APIs identify locations and permissions; they do not alone prove crash consistency, durability, or cross-file atomicity.

These facts do not dictate whether Hive chooses A, B, C, or D. The M56 governance decision is Hive-specific: preserve store authority, avoid hidden authorities, and require evidence before unblocking runtime work.

## 3. Option evaluation

### 3.1 Option A — Extend existing stores

Under A, HoneycombStore and EventLedgerStore remain the lifecycle owners and gain explicit public or package-visible operations for:

```text
stable identity
health/integrity diagnostics
schema/version observation
writer admission and barrier state
backup/snapshot
checkpoint/close/reopen
logical deletion floor/generation
cancellation and failure recovery
```

**Advantages:** minimal conceptual owner count; existing schema/migration code stays near its store; direct writers can be audited at the source.

**Risks:** broad changes to legacy stores; accidental public exposure of raw SQLite state; reentrant actor calls; incomplete inventory of direct writers; migration and deletion semantics may remain implicit.

**Required proof:** every changed symbol is store-owned, every durable writer routes through the barrier, every resource closes in the store actor, and no coordinator gains product-data authority. M56 does not approve those edits.

### 3.2 Option B — Shared storage owner

Under B, a shared actor/helper or separate worker owns coordination for both stores.

**Advantages:** central visibility of active-set transitions and shared lifecycle sequencing; potentially simpler startup orchestration.

**Risks:** the owner can become a second storage authority; existing direct writers may bypass it; raw handles may be moved or duplicated; a “metadata” database or ledger may be added to compensate; actor hops can deadlock or create reentrancy gaps; browser startup becomes coupled to storage coordination.

**M56 disposition:** not the default. B is acceptable only if a future decision proves that the owner is a pure coordinator, never stores product data/events, never owns schema/deletion truth, never receives raw handles, and can account for every writer and failure path.

### 3.3 Option C — Store-owned lifecycle protocols

Under C, each store retains its own SQLite actor and exposes a typed lifecycle surface. A future coordinator consumes those surfaces without accessing connection internals:

```text
HoneycombStore ── typed lifecycle participant ──┐
                                                ├── future activation coordinator
EventLedgerStore ─ typed lifecycle participant ─┘
```

A typed participant operation may return bounded identity, health, schema, generation, barrier, snapshot-result, close-result, and recovery state. It may not return a connection or arbitrary SQL authority.

**Advantages:** store-owned schema/deletion/resource truth; actor isolation remains local; lifecycle behavior can be tested at the public seam; direct writers are audited where they originate.

**Risks:** requires real changes to existing stores; protocol design can hide gaps if it is merely naming methods; two stores may have legitimately different recovery/deletion semantics; cross-store coordination remains best-effort and must not be marketed as atomic.

**M56 disposition:** planning-selected target, pending a new implementation plan and explicit path approval.

### 3.4 Option D — Keep blocked

Under D, no runtime work starts. Documentation can refine the contract and audit sources, but no active-set pointer, startup integration, real participant adapter, or store lifecycle change is added.

**M56 disposition:** required current state until the Option C contract is designed, reviewed, approved, implemented, and evidenced.

## 4. Target contract for a future decision

This section is a design target, not an implementation authorization. A future plan must define typed equivalents of these capabilities without exposing raw SQLite resources:

```text
StoreIdentity
  stable store kind, instance identity, path classification, generation

StoreHealth
  open/closed/degraded, integrity result, last error class, freshness

StoreSchema
  owner-defined schema version, migration state, compatibility result

WriterAdmission
  closed/opening/open/blocked/draining, barrier generation, active writer count

StoreSnapshot
  bounded snapshot identity, schema version, source generation, close/backup result

StoreLifecycle
  open, quiesce, checkpoint/backup, close, reopen, recover, cancel

DeletionContinuity
  logical deletion generation/floor, tombstone/recovery state, rebuild requirement

ParticipantEvidence
  bounded operation identity, outcome, limitation, source revision, no raw data
```

The future protocol must satisfy all of these rules:

- all lifecycle operations execute within the store’s actor/resource owner;
- values crossing the boundary are immutable and `Sendable`;
- operation results are typed and bounded, not free-form SQL/errors containing user data;
- every direct durable writer is either admitted by the store barrier or listed as an intentional exception with proof;
- backup/restore never implies cross-database atomicity;
- close/reopen finalizes statements and releases connections before reporting success;
- migrations remain owned by each store and cannot be run by the coordinator;
- deletion generations survive restart and prevent deleted data from reappearing in activation/recovery views;
- cancellation leaves an explicit incomplete/unknown result rather than false success;
- browser startup can proceed without the coordinator and without widening model/network context.

## 5. Future implementation sequence

M56 does not execute this sequence. It defines the smallest future sequence that can be separately approved:

1. **Contract revision:** define typed store-owned lifecycle protocols and map every requirement to an owner.
2. **Writer inventory:** enumerate every public and internal durable writer in Honeycomb/EventLedger and classify barrier coverage.
3. **Store-local implementation:** add lifecycle behavior inside the owning store files or explicitly approved companion modules; no wrapper-only conformance.
4. **Resource proof:** test statement finalization, backup/restore, checkpoint, close/reopen, cancellation, and actor isolation inside each store owner.
5. **Deletion/migration proof:** test schema ownership, migration interruption, deletion floors, tombstones, and non-resurrection.
6. **Coordinator adapter:** consume typed participant results only; no raw handles, SQL, product rows, or second evidence store.
7. **Browser projection:** add degraded state only after storage behavior is evidenced; browsing/private/offline/accessibility/manual paths remain functional.
8. **M53 review:** collect source/diff, build/tests, deterministic faults, restart/recovery, manual browser, and independent review evidence for the exact implementation revision.

Any step requiring a path outside its approved allowlist returns the work to architecture review rather than silently expanding scope.

## 6. Migration and recovery requirements

A future implementation decision must specify:

- schema version ownership for Honeycomb and EventLedger separately;
- whether lifecycle additions are additive, migratory, or require a compatibility bridge;
- how old instances open when lifecycle metadata is absent or unknown;
- how interrupted migrations remain recoverable without initializing an empty replacement;
- how WAL/shm/backup artifacts are handled and quarantined;
- how close/reopen behaves across app lifecycle, lock, crash, cancellation, and storage failure;
- how deletion floors and tombstones prevent restored data from reappearing;
- how recovery results bind to the authoritative store and EventLedger evidence without creating a second ledger;
- how browser startup uses an unavailable/degraded projection without blocking navigation;
- how user content, URLs, credentials, private state, and raw database data are excluded from evidence packets.

No M56 document may claim power-loss durability, crash consistency, secure deletion, or cross-store atomicity before M53 evidence establishes the narrower tested behavior and its limits.

## 7. Evidence and decision packet

A future M56 implementation decision must bind one bounded packet:

```text
m56_packet_id
source_revision
working_tree_identity
m55_block_reference
option_selected
option_rejected_reasons
participant_set
store_authority_map
lifecycle_contract
writer_inventory
resource_ownership_map
migration_schema_map
delete_generation_map
browser_fallback_map
privacy_redaction_rules
changed_path_allowlist
implementation_owner
rollback_owner
review_owner
m53_owner
stop_conditions
known_limitations
next_smallest_action
owner_acknowledgement
```

A packet is not implementation evidence. It must not contain raw databases, private page text, credentials, cookies, screenshots as sole proof, absolute user paths, unbounded logs, or model/network payloads.

## 8. Decision rubric and dispositions

### `BLOCKED` — required default

Use `BLOCKED` when the contract cannot be satisfied by existing public APIs, when direct writers are not fully accounted for, when store/resource ownership is ambiguous, or when a proposed design creates a second authority. This is the current M56 disposition for runtime work.

### `HOLD`

Use `HOLD` for a future option review when evidence is incomplete but no contradiction is established. HOLD does not authorize code or a pilot. It must name one smallest missing fact.

### `TARGET_SELECTED`

Use `TARGET_SELECTED` only for planning: Option C is the preferred architecture direction. This label does not mean implemented, code-present, verified, or approved for execution.

### `GO`

M56 cannot issue `GO` for implementation. A future implementation decision may issue GO only after the typed contract, writer map, path allowlist, ownership, migration/recovery plan, rollback, and M53 handoff are separately approved.

### `SPLIT`

A future synthetic SPLIT may test pure codecs, fake participants, and deterministic state machines under M55’s boundary. It cannot test real store lifecycle, establish runtime recovery, or promote status.

## 9. Stop and rollback rules

Stop planning or future implementation preparation if:

- a protocol exposes or accepts `OpaquePointer`, `sqlite3 *`, prepared statements, file descriptors, or arbitrary SQL;
- any direct durable writer is omitted from the inventory or bypasses the barrier;
- the coordinator begins storing product rows, events, snapshots, or a second ledger;
- migration, deletion, or schema truth moves out of the owning store without an explicit new decision;
- a future adapter opens a real store before its owner contract is approved;
- cross-store atomicity, power-loss durability, secure deletion, or production readiness is implied from synthetic evidence;
- private, offline, accessibility, or manual browser fallback is weakened;
- storage failure widens model/network context or blocks ordinary navigation;
- WISP/M5 or another participant appears without a new architecture decision;
- dirty user work is reset, cleaned, overwritten, or discarded.

Rollback is non-destructive: stop, preserve the dirty worktree, quarantine disposable artifacts, record the decision, and return to `BLOCKED`/`HOLD`. Do not use destructive git cleanup.

## 10. M56 gates

| Gate | Requirement |
|---|---|
| M56-A | M55 full-slice BLOCK and synthetic SPLIT boundary are reproduced. |
| M56-B | `{Honeycomb, EventLedger}` is the exact participant set. |
| M56-C | Current private SQLite/resource ownership is source-bound. |
| M56-D | Existing direct durable writers are inventoried or the option remains BLOCKED. |
| M56-E | Options A–D are compared with risks and dispositions. |
| M56-F | Option C is marked planning-selected, not implementation-approved. |
| M56-G | Option D remains the required current default. |
| M56-H | Store-owned identity/health/schema contracts are defined as targets. |
| M56-I | Writer admission/barrier coverage is required for every writer. |
| M56-J | Backup/checkpoint/close/reopen ownership remains inside each store. |
| M56-K | Raw SQLite handles and SQL authority cannot cross boundaries. |
| M56-L | Migration and schema authority remain store-owned. |
| M56-M | Deletion floors/tombstones and non-resurrection are explicit. |
| M56-N | Actor isolation, Sendable results, reentrancy, and cancellation are explicit. |
| M56-O | Cross-store atomicity and power-loss claims remain blocked. |
| M56-P | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M56-Q | Storage failure cannot widen model/network context. |
| M56-R | No coordinator database, second ledger, or product-data authority is proposed. |
| M56-S | WISP/M5 remain blocked and unregistered. |
| M56-T | Migration/recovery/rollback requirements and limitations are recorded. |
| M56-U | Future implementation sequence has separate path/owner approval. |
| M56-V | Evidence packet fields and redaction limits are complete. |
| M56-W | M56 cannot issue implementation GO or status promotion. |
| M56-X | Synthetic evidence cannot establish real-store recovery or promote status. |
| M56-Y | Stop and non-destructive rollback rules preserve unrelated user work. |
| M56-Z | Independent review and M53 handoff are required before any future runtime claim. |

## 11. Honest limits and primary references

M56 does not implement or verify store lifecycle protocols, writer barriers, backup/restore, close/reopen, migrations, deletion continuity, active-set publication, browser startup, crash recovery, power-loss durability, cross-store atomicity, secure deletion, production readiness, compliance, or ship readiness.

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

These sources establish platform/library constraints. M56’s option dispositions, target architecture, BLOCK default, participant/authority boundaries, packet, gates, and no-status-promotion rules are Hive governance decisions.

**M56 is complete as a planning artifact when the architecture options, target contract, BLOCK default, future sequence, evidence packet, migration/recovery limits, 26 gates (M56-A through M56-Z), stop rules, and independent review are structurally validated.**
