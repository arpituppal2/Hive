# Hive M58 — Storage-Authority Inventory & Implementation-Approval Packet

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M58 Storage-Authority Inventory & Readiness
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m57-storage-authority-implementation-readiness-contract-plan.md`
> **Related plans:** M50–M57 storage-authority chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent writers to map, not admit:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and any other durable writer
> **Current disposition:** `BLOCKED`; M58 cannot issue implementation `GO` or status promotion.

Current disposition: `BLOCKED`. M58 cannot issue `GO` for implementation or status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M58 turns M57’s readiness requirements into a source- and call-site-bound inventory packet. It does not edit Swift, run inventory-dependent implementation, open real stores, authorize a synthetic pilot, authorize M52, or promote any capability status.

## 0. Decision summary

**Decision: keep implementation `BLOCKED` until the inventory packet is complete, independently reviewed, and followed by a separate implementation approval.**

The current audit identifies many direct mutation paths and adjacent durable writers. A declaration list is insufficient: M58 must bind each symbol to its owner, target, isolation boundary, call sites, dynamic/indirect risk, lifecycle behavior, and evidence requirement. All direct and indirect writer risks must be classified. The packet must distinguish production participants from adjacent writers rather than silently expanding the coordinator’s participant set.

`HandoffRecoveryJournal` and `SessionFileStore` are therefore **mapped adjacent writers, not production participants** in M58. Their relationship to any future activation lifecycle requires a separate architecture decision; they cannot be included by implication.

## 1. Binding scope

### 1.1 Production authority

The only production participants remain exactly:

```text
{Honeycomb, EventLedger}
```

- Honeycomb owns knowledge schema, migrations, nodes/edges, provenance, retrieval data, and logical deletion.
- EventLedger owns append-only evidence events, event schema/migrations, consent/action history, and ledger deletion semantics.
- A future coordinator may project one bounded activation metadata record, but it may not own product data, schema, migrations, deletion truth, events, or a second ledger.

### 1.2 Adjacent writer inventory

M58 must inventory, classify, and explain—but does not admit—these adjacent persistence surfaces:

```text
HandoffRecoveryJournal
SessionFileStore
BrowserState persistence
Research handoff adapters/supervisors
BeeQueue or other EventLedger callers
BrowserState/AI/Brief/Approval callers
```

An adjacent writer may be classified as `outside_scope`, `requires_new_decision`, `read_only_observer`, or `production_participant_candidate`. No candidate classification authorizes participation.

### 1.3 Forbidden expansion

M58 forbids:

- a coordinator database, second ledger, product-data cache, or shadow store;
- raw `OpaquePointer`, `sqlite3 *`, prepared statements, file descriptors, or arbitrary SQL across boundaries;
- migration/deletion/schema authority outside the owning store;
- WISP/M5 registration or new participants;
- model, network, connector, OS, telemetry, credential, or permission expansion;
- changes to private-mode, offline, accessibility, manual, or browser-first fallback;
- implementation, runtime recovery, production, power-loss, crash-consistency, cross-store atomicity, secure-deletion, compliance, or ship claims from the packet alone.

## 2. Required inventory dimensions

Every inventory row must contain:

```text
inventory_id
source_path
symbol_or_query
source_revision
target/module
access_level
actor/isolation boundary
resource owner
schema/migration owner
write/read classification
call_site_path
call_site_symbol
indirect/dynamic dispatch risk
inputs and outputs
private/user-data risk
lifecycle operation
required evidence tier
scope classification
known limitation
reviewer
```

A row without an exact path/symbol or bounded search query is incomplete. A static search result is an inventory lead, not proof that all dynamic/closure/reflection/C-API paths are covered.

## 3. Store and writer inventory contract

### 3.1 Honeycomb

Required source and call-site inventory includes:

```text
Sources/HiveCore/Honeycomb/HoneycombStore.swift
insertNode, updateNode, deleteNode
insertEdge, deleteEdge
deleteByProvenance, deleteOlderThan, purgeLegacyLibrarianExtraction
schema migration and user_version paths
WAL/foreign-key/transaction paths
open/close/backup/checkpoint paths
all callers through BrowserState, Brief, capture, wiki, project, task, sheet, and retrieval surfaces
```

The inventory must identify all direct and indirect durable writers, not only the public method declarations. Every direct and indirect durable writer must be classified.

### 3.2 EventLedger

Required source and call-site inventory includes:

```text
Sources/HiveCore/EventLedger/EventLedgerStore.swift
record, recordIfAbsent
deleteByProvenance, deleteOlderThan, deleteAll
schema migration and user_version paths
WAL/transaction/close paths
all callers through BrowserState, AI, Brief, Approval, TrustedTurnGateway, BeeQueue, consent, action, and recovery flows
```

Append-only semantics do not automatically constitute a writer barrier. Every durable record path must be classified.

### 3.3 HandoffRecoveryJournal

Required source and call-site inventory includes:

```text
Sources/HiveCore/AI/Search/HandoffRecoveryJournal.swift
append, replace, remove, pending, count
ResearchHandoffAdapter
ResearchHandoffSupervisor
schema/hash migration, WAL, synchronous, busy-timeout, and close paths
```

M58 classifies this as `adjacent_writer_outside_scope` unless a new architecture decision explicitly admits it. It must not be silently included in `{Honeycomb, EventLedger}` or used to justify a third ledger.

### 3.4 SessionFileStore and browser persistence

Required source and call-site inventory includes:

```text
Sources/HiveCore/Browser/SessionFileStore.swift
Sources/Hive/BrowserState+Persistence.swift
load/save/recovery/quarantine/backup paths
startup, clean-exit, unclean-exit, and corruption handling
```

Session persistence remains a browser authority, not a Honeycomb/EventLedger participant. It must be mapped for fallback and exclusion. M58 does not change startup or session behavior.

## 4. Call-site and indirect-writer methodology

The packet must use multiple bounded methods:

1. Declaration inventory: exact store methods and C-API seams.
2. Direct call-site inventory: every statically resolved caller.
3. Import/target inventory: all modules importing the owning target.
4. Closure/task/delegate inventory: writes invoked indirectly from asynchronous work.
5. String/selector/config inventory: dynamic or generated symbol risks where applicable.
6. Test fixture inventory: tests that write `:memory:`, temporary files, or real Application Support paths.
7. Negative search log: exact queries, searched roots, excluded roots, and limitations.

A search tool failure must be recorded as `inventory_incomplete`, not treated as no matches. A green static check does not establish runtime writer exclusion.

## 5. Access, target, and authority packet

M58 must bind:

```text
Package.swift revision
HiveCore target membership
Hive target membership
HiveCoreTests test-only access
public/package/internal/private/fileprivate declarations
actor and nonisolated(unsafe) declarations
Sendable/unchecked Sendable surfaces
C-API imports and raw-pointer ownership
resource paths and sandbox/container assumptions
```

Swift access control and SwiftPM target membership establish compile-time visibility and build-graph facts. They do not prove runtime file isolation, semantic writer barriers, SQLite safety, or absence of dynamic call paths.

## 6. SQLite lifecycle matrix

For each production store and adjacent writer, the packet must record:

| Operation | Honeycomb | EventLedger | Handoff/Session | Evidence required |
|---|---|---|---|---|
| open/create | exact owner/symbol | exact owner/symbol | exact owner/symbol or N/A | source + focused runtime |
| schema/migration | store-owned path | store-owned path | owner-specific path | interrupted migration |
| WAL/SHM | pragma/artifact handling | pragma/artifact handling | owner-specific | concurrent lifecycle |
| writer admission | all writers mapped | all writers mapped | exclusion/fallback | semantic barrier |
| checkpoint/backup | exact operation | exact operation | N/A/owner-specific | active-write snapshot |
| statement close | owner/resource path | owner/resource path | owner/resource path | resource cleanup |
| connection close/reopen | actor lifecycle | actor lifecycle | file lifecycle | restart/recovery |
| deletion generation | floor/tombstone owner | event/deletion owner | session/quarantine owner | non-resurrection |

`N/A` must be justified by ownership evidence; it cannot mean “not searched.”

## 7. Implementation-approval packet

A future approval packet must contain:

```text
m58_packet_id
source_revision
working_tree_identity
working_tree_state
m57_packet_reference
m56_target_reference
participant_set
adjacent_writer_classifications
source_symbol_inventory
call_site_inventory
dynamic_risk_inventory
access_target_packet
sqlite_lifecycle_matrix
writer_barrier_map
migration_schema_map
delete_generation_map
changed_path_allowlist
excluded_path_list
synthetic_split_allowlist
real_store_allowlist
browser_fallback_map
privacy_redaction_rules
implementation_owner
rollback_owner
independent_reviewer
m53_owner
missing_evidence
known_limitations
next_smallest_action
owner_acknowledgement
```

The packet must be bounded and redacted. It may not contain raw databases, page text, private URLs, credentials, cookies, screenshots as sole proof, absolute user paths, model/network payloads, or unbounded logs.

## 8. Disposition rubric

### `BLOCKED` — current default

Use `BLOCKED` when any production writer, adjacent writer classification, owner, lifecycle resource, changed path, or evidence limitation is missing or contradictory. M58 cannot issue `GO`.

### `HOLD`

Use `HOLD` when the inventory is not contradicted but one bounded packet fact is missing. HOLD authorizes no code, store access, pilot, or status promotion. HOLD and SPLIT authorize no code or store access.

### `SPLIT`

Use `SPLIT` only for separately approved synthetic inventory/codec/fake-participant/state-machine work. It cannot open real databases, inspect real user data, establish runtime recovery, or promote M52/M53/status.

### `TARGET_READY_FOR_REVIEW`

Use this only when the packet is complete enough for owner review of a future implementation plan. It does not mean implementation-approved, code-present, or verified.

### `GO`

M58 cannot issue implementation `GO`. A later decision may do so only after exact owners, writers, paths, target boundaries, lifecycle evidence, rollback, and M53 handoff are approved independently.

## 9. Browser, privacy, and rollback boundaries

- Ordinary navigation, tabs, private browsing, offline use, accessibility, and manual fallback remain usable if storage is unavailable.
- Storage failure cannot widen model/network context or trigger model, network, connector, OS, or telemetry actions.
- Private content, credentials, cookies, page text, screenshots, and raw database contents are excluded from packets.
- Corrupt or unavailable storage cannot silently initialize an empty replacement and claim success.
- Rollback is non-destructive: preserve the dirty worktree, quarantine disposable artifacts, record the limitation, and return to `BLOCKED`/`HOLD`.
- No destructive git cleanup is permitted.

## 10. M58 gates

| Gate | Requirement |
|---|---|
| M58-A | M57 current BLOCK and M56 Option C target are reproduced. |
| M58-B | `{Honeycomb, EventLedger}` is the exact production participant set. |
| M58-C | HandoffRecoveryJournal is mapped as adjacent/out-of-scope unless separately admitted. |
| M58-D | SessionFileStore/browser persistence is mapped as browser authority/exclusion. |
| M58-E | Honeycomb declarations, writers, C-API, and callers are inventoried. |
| M58-F | EventLedger declarations, writers, C-API, and callers are inventoried. |
| M58-G | All direct and indirect writer risks are classified. |
| M58-H | Source revision, target, access-control, and actor boundaries are bound. |
| M58-I | SwiftPM target/test-only boundaries are recorded. |
| M58-J | SQLite lifecycle matrix covers open/migrate/WAL/backup/close/reopen/delete. |
| M58-K | Every writer has barrier coverage or an explicit BLOCK classification. |
| M58-L | Adjacent writer exclusions cannot silently become participants. |
| M58-M | Synthetic and real-store allowlists are separate. |
| M58-N | Evidence packet is bounded, redacted, source-bound, and limitation-bound. |
| M58-O | Browser/private/offline/accessibility/manual fallback is explicit. |
| M58-P | Storage failure cannot widen model/network context. |
| M58-Q | No coordinator database, second ledger, product-data authority, or new participant is proposed. |
| M58-R | Migration/deletion/recovery/rollback limits are recorded. |
| M58-S | M53 handoff binds one future source revision and evidence scope. |
| M58-T | Current disposition remains BLOCKED; M58 cannot issue GO. |
| M58-U | HOLD/SPLIT/TARGET_READY_FOR_REVIEW do not authorize implementation or status promotion. |
| M58-V | Negative search results include method, roots, and limitations. |
| M58-W | Search/tool failures are classified inventory-incomplete. |
| M58-X | Independent review is required before any future runtime claim. |

## 11. Honest limits and primary references

M58 does not implement or verify lifecycle protocols, writer barriers, backup/restore, close/reopen, migrations, deletion continuity, active-set publication, browser startup, crash recovery, power-loss durability, cross-store atomicity, secure deletion, production readiness, compliance, or ship readiness.

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

These references establish platform/library limits. M58’s inventories, classifications, packet, dispositions, gates, and no-status-promotion rules are Hive governance decisions.

**M58 is complete as a planning artifact when the source/call-site inventory, adjacent-writer classification, authority packet, SQLite matrix, implementation packet, 24 gates (M58-A through M58-X), rollback rules, M53 handoff, and independent review are structurally validated.**
