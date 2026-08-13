# Hive M54 — StorageActivationCoordinator Execution Approval & Preflight

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; default decision HOLD; no M52 execution authorized
> **Roadmap label:** M54 StorageActivationCoordinator Execution Approval & Preflight
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m53-storage-activation-coordinator-runtime-evidence-review-plan.md`
> **Implementation plan:** `docs/superpowers/plans/2026-08-12-m52-storage-activation-coordinator-runtime-implementation-plan.md`
> **Architecture decision:** `docs/superpowers/plans/2026-08-12-m50-storage-activation-coordinator-architecture-decision-plan.md`
> **Readiness contract:** `docs/superpowers/plans/2026-08-12-m51-storage-activation-coordinator-implementation-readiness-plan.md`
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Participant set:** `{Honeycomb, EventLedger}` only
> **Next boundary:** explicit M54 disposition, then separately approved M52 execution only if GO; M53 review remains required afterward
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M54 is a preflight and change-control decision. It freezes the exact checkout, paths, targets, owners, platform assumptions, and rollback rules before any M52 Swift edit. It does not execute M52. It does not create the approval packet. It does not change source, run commands, or promote status.

## 0. Decision summary

**Default decision: HOLD.**

The current worktree is dirty, the existing Honeycomb/EventLedger stores use raw SQLite ownership, and no exact public-symbol mapping has yet shown that the M52 `StoreParticipant` adapter can satisfy its barrier/identity/health/deletion/closure contract without touching files explicitly outside the M52 allowlist. M54 therefore does not authorize execution by default.

M54 defines four possible dispositions:

```text
GO     → all preflight gates pass; separately approve exact M52 packet
HOLD   → evidence is missing but no contradiction is proven; gather the smallest missing packet
BLOCK  → M52 allowlist cannot satisfy the adapter or safety contract; reopen architecture/scope
SPLIT  → authorize only a narrower adapter/codec pilot, with no publication/coordinator/browser integration
```

A M54 `GO` is not runtime verification and does not promote any capability. M53 remains the required evidence-review boundary after an approved M52 execution.

## 1. Binding scope and non-negotiables

### 1.1 Participant and authority boundary

The only participants remain:

```text
{Honeycomb, EventLedger}
```

The coordinator may own one bounded activation metadata record and its selection/publication lifecycle. It may not own:

- a coordinator SQLite database;
- a second ledger or append-only evidence store;
- any product-data authority or product-data store;
- product objects, raw database rows, FTS data, model context, prompts, page text, credentials, cookies, screenshots, or unbounded paths;
- migrations, deletion truth, browser sessions, permissions, connectors, sync, telemetry, network, or OS actions;
- WISP/M5 registration or scope;
- raw `OpaquePointer`/SQLite-handle transfer across the adapter boundary; no raw `OpaquePointer`/SQLite-handle transfer is permitted.

Honeycomb remains the authority for knowledge contents and logical deletion. EventLedger remains the authority for append-only evidence and deletion events. M54 may inspect their public APIs; it may not silently reassign their authority.

### 1.2 M52 allowlist remains binding

The initial M52 allowlist is exactly:

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

M54 may not authorize changes to `HoneycombStore.swift`.

M54 may not authorize changes to `EventLedgerStore.swift`.

M54 may not authorize changes to `HandoffRecoveryJournal.swift`.

M54 may not authorize changes to browser persistence/UI.

M54 may not authorize changes to `Package.swift`.

M54 may not authorize changes to entitlements or unrelated tests. Any required expansion creates a new M52 revision and returns M54 to HOLD/BLOCK.

## 2. Preflight approval packet

A future M54 disposition must be recorded in one bounded packet containing:

```text
m54_packet_id
m54_decision = GO | HOLD | BLOCK | SPLIT
source_revision
working_tree_identity
working_tree_state
changed_path_allowlist
package_name
source_targets = [HiveCore]
test_targets = [HiveCoreTests]
participant_set = {Honeycomb, EventLedger}
macos_version
swift_toolchain
sqlite_runtime_version
sandbox/container_path_evidence
entitlement_evidence
store_public_symbol_map
store_resource_ownership_map
direct_writer_map
startup_path_map
rollback_owner
implementation_owner
review_owner
m53_owner
stop_conditions_accepted
missing_evidence
known_limitations
next_smallest_action
```

The packet must be local, bounded, redacted, and traceable. It must not contain raw databases, credentials, private URLs, page content, prompts, cookies, screenshots as sole proof, or unbounded logs. A packet field is not evidence until it binds an observation, source revision, environment, owner, limitation, and artifact/command identity.

## 3. GO / HOLD / BLOCK / SPLIT rubric

### 3.1 GO

M54 may return `GO` only when all of these are true:

- the execution checkout is isolated and bound to one exact source revision;
- unrelated pre-existing user work is preserved and not mixed into the execution baseline;
- the M52 changed-path allowlist is exact and mechanically checked;
- Package.swift already contains the required `HiveCore` and `HiveCoreTests` target membership, or a separately approved manifest change exists;
- no entitlement or sandbox expansion is needed for the initial slice;
- public existing store APIs map one-to-one to the typed participant contract for identity, health, deletion floor, barrier, snapshot, close, and reopen;
- the mapping does not require private SQLite access or edits to excluded store files;
- every direct durable writer is mapped to the barrier or the result is BLOCK;
- rollback owner, implementation owner, independent reviewer, and M53 owner are named;
- stop conditions and browser-first fallback are accepted;
- no WISP/M5 or unrelated product scope is present;
- M52 approval packet is complete and separately signed/acknowledged.

`GO` means “M52 may begin within the exact allowlist.” It does not mean “M52 is implemented,” “M53 passed,” or “verified.”

### 3.2 HOLD

Return `HOLD` when the preflight has not disproved safety, but any required fact is missing, including:

- dirty-tree isolation or exact source revision;
- exact public symbol mapping for a store participant;
- target membership or test-command confirmation;
- sandbox/container path evidence;
- owner/rollback/reviewer identity;
- direct-writer inventory;
- test environment or SQLite runtime identity;
- M52/M53 packet linkage;
- bounded evidence or limitation text.

HOLD must name the smallest missing evidence item and must not be treated as permission to start coding.

### 3.3 BLOCK

Return `BLOCK` when evidence proves that the initial M52 allowlist cannot safely implement the contract, including:

- an adapter requires editing an excluded store/browser/Package.swift/entitlement file;
- an adapter requires private SQLite handle access or raw-handle transfer;
- a direct writer cannot be enclosed by the proposed barrier;
- a required store identity, deletion floor, backup/close, or reopen operation does not exist at an approved public boundary;
- the implementation would need a coordinator database, second ledger, product-data cache, or new semantic authority;
- sandbox/path assumptions contradict the allowed container;
- WISP/M5 or another unapproved participant is required.

BLOCK requires a new architecture/implementation decision. It must not be “fixed” by weakening the M52 contract or editing unrelated files.

### 3.4 SPLIT

Return `SPLIT` only if a narrower pilot can produce useful evidence without publication, startup integration, store mutation, or browser/UI changes. A valid pilot may cover:

- bounded metadata value/codec tests;
- injected filesystem containment/publication tests over synthetic artifacts;
- adapter protocol type-checking against fake participants;
- deterministic state-machine tests with no real stores.

A SPLIT pilot cannot claim store integration, recovery, browser behavior, or `verified`; it still requires a new explicit execution approval naming its smaller allowlist.

## 4. Preflight work packages

### M54-A — Checkout and path freeze

Record `git status --short`, exact revision/tree identity, all modified/untracked paths, the execution baseline, and the approved allowlist. The current dirty worktree must not be mislabeled clean. If execution requires a clean tree, create an isolated worktree or obtain explicit owner disposition; do not reset, clean, checkout, or discard user work.

### M54-B — SwiftPM target and command freeze

Confirm from `Package.swift`:

- `HiveCore` is the production target containing Activation code;
- `HiveCoreTests` is the test target with the required dependency;
- no target/plugin/resource change is required for the initial allowlist;
- the exact future commands are recorded, such as `swift build` and `swift test --filter Activation`;
- any unavailable filter or test target is classified HOLD, not silently substituted.

M54 does not authorize a Package.swift edit.

### M54-C — Store public-API and resource-ownership map

For each Honeycomb/EventLedger capability, record:

```text
identity → exact public symbol
health → exact public symbol
schema version → exact public symbol
 deletion floor → exact public symbol or BLOCK
writer barrier → exact public symbol or BLOCK
snapshot/backup → exact public symbol or BLOCK
close/reopen → exact public symbol or BLOCK
direct writers → complete inventory or BLOCK
```

Raw `OpaquePointer`, private methods, comments, inferred semantics, and source presence do not satisfy the map. If any required row is BLOCK, M54 cannot return GO for the full M52 slice.

### M54-D — Platform/path/entitlement preflight

Record target macOS, Swift toolchain, SQLite runtime, Application Support/container resolution, sandbox state, entitlements, and whether the new Activation files require any capability beyond the existing target. Confirm that metadata staging and publication remain within one owner-controlled container/volume. A path API returning a URL is not proof of write permission or durability.

### M54-E — Ownership, rollback, and browser fallback

Name implementation, rollback, reviewer, and M53 owners. Freeze stop conditions:

- unauthorized path change;
- excluded store file required;
- raw handle crossing boundary;
- direct writer bypass;
- coordinator database/second ledger/product data;
- forbidden participant/scope;
- privacy leak;
- browser/private/offline/accessibility/manual fallback regression;
- model/network widening after storage failure.

Rollback means stop, preserve unrelated work, quarantine any candidate artifact, release resources, and return to HOLD/BLOCK; it does not mean destructive git cleanup.

### M54-F — Decision packet and handoff

Produce one packet with the disposition, missing evidence, exact next action, M52 approval linkage, M53 review owner, and limitations. `GO` requires explicit owner acknowledgement; `HOLD`, `BLOCK`, and `SPLIT` require a smallest corrective plan.

## 5. Evidence limits

M54 may establish preflight readiness facts:

- target membership and command shape;
- exact path/allowlist membership;
- source/API symbol mapping;
- platform/environment identity;
- owner and rollback assignment;
- static absence of forbidden authority patterns.

M54 cannot establish:

- runtime implementation correctness;
- SQLite crash recovery or power-loss durability;
- cross-database atomicity;
- user-observable browser behavior;
- production/compliance/ship readiness;
- M53 evidence-tier completion.

M54 is a change-control gate, not a verification gate.

## 6. Review dispositions and handoff

| Disposition | Meaning | Next action |
|---|---|---|
| `GO` | Preflight facts and ownership are complete; exact M52 execution may begin | Execute only the allowlist, then collect M53 evidence |
| `HOLD` | Missing evidence, no proven contradiction | Gather one smallest missing packet item; do not edit |
| `BLOCK` | The allowlist or architecture cannot safely satisfy the contract | Reopen M50/M52; do not weaken boundaries |
| `SPLIT` | A narrower synthetic adapter/codec pilot is safe | New approval for smaller allowlist; no integration claims |

No disposition changes capability status. M53 remains the only status-review boundary for a future M52 result.

## 7. Twenty-four M54 gates

| Gate | Requirement |
|---|---|
| M54-A | Exact source revision, tree identity, dirty-tree state, and execution baseline are recorded. |
| M54-B | M52 allowlist is mechanically exact and no excluded path is required. |
| M54-C | Package targets `HiveCore` and `HiveCoreTests` are confirmed without manifest edits. |
| M54-D | Future build/test commands and filter behavior are recorded. |
| M54-E | macOS, Swift, SQLite, sandbox, container, and entitlement facts are recorded. |
| M54-F | Metadata path is owner-contained and same-container publication remains possible. |
| M54-G | Honeycomb public symbol map is complete or disposition is HOLD/BLOCK. |
| M54-H | EventLedger public symbol map is complete or disposition is HOLD/BLOCK. |
| M54-I | Identity/schema/health/deletion-floor/close/reopen ownership is explicit. |
| M54-J | Snapshot/backup and resource closure ownership is explicit or blocked. |
| M54-K | Direct durable writer inventory is complete and barrier coverage is shown. |
| M54-L | No raw SQLite handle, private API, or forbidden authority crosses the boundary. |
| M54-M | No coordinator database, second ledger, or product-data store is proposed. |
| M54-N | Participant set is exactly Honeycomb/EventLedger; WISP/M5 remain blocked. |
| M54-O | Implementation, rollback, independent-review, and M53 owners are named. |
| M54-P | Stop conditions and non-destructive rollback procedure are accepted. |
| M54-Q | Browser/private/offline/accessibility/manual fallback contract remains unchanged. |
| M54-R | Storage failure cannot widen model/network context. |
| M54-S | Evidence packet is bounded, redacted, source-bound, and limitation-bound. |
| M54-T | Missing evidence is classified HOLD, not silently treated as GO. |
| M54-U | Proven contract contradiction is classified BLOCK, not patched by scope weakening. |
| M54-V | Synthetic-only opportunity is classified SPLIT without integration overclaim. |
| M54-W | M54 decision is explicit and owner-acknowledged. |
| M54-X | M53 remains required after any M52 execution; no status is promoted by M54. |

## 8. Required M54 packet

```text
m54_packet_id
m54_decision
source_revision
working_tree_identity
working_tree_state
changed_path_allowlist
package_targets
future_commands
platform_identity
sqlite_identity
sandbox/container evidence
entitlement evidence
Honeycomb public symbol map
EventLedger public symbol map
direct writer map
resource ownership map
implementation_owner
rollback_owner
review_owner
m53_owner
stop_conditions
missing_evidence
known_limitations
next_smallest_action
owner_acknowledgement
```

The packet must not contain raw databases, secrets, private content, screenshots as sole evidence, or unbounded logs.

## 9. Explicit deferrals and honest limits

M54 does not implement, execute, or verify:

- M52 Activation Swift files;
- Honeycomb/EventLedger/HandoffRecoveryJournal/browser persistence/Package.swift/entitlement changes;
- M53 evidence collection or status promotion;
- WISP/M5/M45/M2, models/training, sync, connectors, OS automation, cloud backup, release, compliance, production readiness, or ship readiness;
- power-loss durability, filesystem crash consistency, distributed transactions, secure deletion, or universal rollback.

**M54 is complete as a planning artifact when its HOLD-default decision, GO/HOLD/BLOCK/SPLIT rubric, packet fields, six preflight work packages, 24 gates, non-destructive rollback, and independent review are structurally validated.**

## 10. Primary references and claim limits

- [Swift Package Manager target declaration](https://developer.apple.com/documentation/packagedescription/target)
- [Swift Package Manager test target](https://developer.apple.com/documentation/packagedescription/target/testtarget(name:dependencies:path:exclude:sources:resources:csettings:swiftsettings:linkerSettings:plugins:))
- [Swift.org Testing](https://swift.org/testing/)
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Apple Application Support](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/WhereToPutFiles/WhereToPutFiles.html)
- [SQLite threading](https://www.sqlite.org/threadsafe.html)
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html)
- [SQLite Online Backup](https://www.sqlite.org/backup.html)
- [Apple FileManager replacement](https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:))
- [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

These sources establish platform and library limits. M54’s HOLD default, packet, disposition rubric, allowlist, owner map, rollback rules, browser-first constraints, and 24 gates are Hive-specific governance contracts. They require explicit owner acknowledgement before any execution decision changes.
