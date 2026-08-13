# Hive M59 — Storage-Authority Inventory Evidence Review & Disposition

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M59 Storage-Authority Inventory Evidence Review
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m58-storage-authority-inventory-readiness-plan.md`
> **Related plans:** M50–M58 storage-authority chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent exclusions:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and other unadmitted writers
> **Current disposition:** `BLOCKED`; M59 cannot issue implementation `GO` or status promotion
>
> Current disposition: BLOCKED. M59 cannot issue implementation GO or status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M59 defines how a future M58 inventory packet is checked for completeness and dispositioned. It does not run the inventory, edit Swift, open real stores, authorize a pilot, authorize M52, or promote any capability status.

## 0. Decision summary

**Decision: retain `BLOCKED` until the inventory packet passes all evidence tiers, receives independent review, and has explicit owner disposition.**

A static declaration or grep result can establish known source facts, but it cannot prove runtime writer exclusion, dynamic dispatch coverage, escaping task/delegate behavior, SQLite resource safety, or recovery. M59 therefore separates evidence into tiers and requires every unproven semantic claim to remain `BLOCKED`, `HOLD`, or explicitly limited.

## 1. Binding scope

The production participant set remains exactly:

```text
{Honeycomb, EventLedger}
```

`HandoffRecoveryJournal` and `SessionFileStore` remain mapped adjacent writers, excluded from production participation unless a new architecture decision admits them. M59 must review their exclusion and fallback evidence; it must not silently convert them into participants.

M59 forbids:

- a coordinator database, second ledger, product-data cache, or shadow store;
- raw SQLite handles, prepared statements, file descriptors, or arbitrary SQL across boundaries;
- migration/schema/deletion authority outside the owning store;
- WISP/M5 or any new participant;
- model/network/connector/OS/telemetry/credential/permission expansion;
- runtime, production, crash-consistency, power-loss, secure-deletion, cross-store atomicity, compliance, or ship claims from inventory evidence alone.

## 2. Review packet

A future M59 review packet must bind:

```text
m59_packet_id
source_revision
working_tree_identity
m58_packet_reference
participant_set
adjacent_writer_classifications
inventory_row_count
source_symbol_inventory
call_site_inventory
direct_writer_inventory
indirect_dynamic_risk_inventory
search_query_log
search_failure_log
swiftpm_target_packet
access_control_packet
sqlite_lifecycle_matrix
runtime_evidence_scope
owner_map
reviewer_map
missing_evidence
known_limitations
disposition
next_smallest_action
owner_acknowledgement
```

The packet must be bounded and redacted. It may not contain raw databases, page text, private URLs, credentials, cookies, screenshots as sole proof, absolute user paths, model/network payloads, or unbounded logs.

## 3. Evidence tiers and limits

### Tier 1 — Source and symbol evidence

Can establish exact declarations, access levels, actor annotations, C-API references, known migration/WAL/close symbols, and statically visible call sites. It cannot establish runtime reachability, dynamic dispatch outcomes, closure/task/delegate execution, or semantic writer ordering.

Required artifacts:

- source revision and dirty-tree record;
- exact source/symbol/query rows;
- direct call-site list;
- negative search method, roots, exclusions, and limitations;
- `inventory_incomplete` when a search tool fails.

### Tier 2 — Target and compile evidence

Can establish SwiftPM target membership, dependency graph, access-control compilation, actor/Sendable diagnostics, and test-only versus production visibility. It cannot prove runtime file isolation, SQLite locking, semantic writer barriers, or dynamic resource ownership.

Required artifacts:

- parsed `Package.swift` target map;
- strict-concurrency diagnostics review;
- public/package/internal/private/fileprivate map;
- `Sendable`/unchecked-`Sendable` map;
- test-only access explicitly separated from production access.

### Tier 3 — Store-local SQLite evidence

Requires a separately approved runtime evidence pass. It must cover, per production store:

- open/create and owner identity;
- schema/version and interrupted migration behavior;
- WAL/SHM/checkpoint and bounded busy handling;
- active-write backup/snapshot behavior;
- statement finalization and close/reopen;
- deletion generations/floors/tombstones and restore non-resurrection;
- cancellation, incomplete, blocked, unavailable, and unknown outcomes.

Tier 3 can establish only the tested behavior under the stated environment and workload. It cannot establish universal power-loss durability or cross-store atomicity.

### Tier 4 — Dynamic and asynchronous writer coverage

Requires explicit coverage for:

- protocol and generic dispatch;
- closures, `Task`, detached work, delegates, notifications, and callbacks;
- actor reentrancy and cancellation;
- C-API or plugin/resource paths;
- multiple instances/processes opening the same database;
- indirect EventLedger callers and adjacent writers.

A static inventory lead is not Tier 4 evidence. Missing dynamic coverage is `BLOCKED` or `HOLD`, never an inferred pass.

### Tier 5 — Independent review and owner disposition

Requires an independent reviewer to check the packet, contradictions, exclusions, redaction, and claim limits. The storage owner and rollback owner must acknowledge the exact disposition. M59 owner approval is not runtime verification and cannot replace M53.

## 4. Completeness rules

An inventory is complete only when:

1. Every production declaration has an owner, target, access level, actor/resource boundary, and lifecycle row.
2. Every direct durable writer has a call-site row or an explicit bounded negative result.
3. Every indirect/dynamic risk has a classification and evidence requirement.
4. Every adjacent writer has an exclusion, fallback, or separate-decision classification.
5. Every SQLite lifecycle operation has an owner and evidence tier.
6. Every search/tool failure is recorded as `inventory_incomplete`.
7. Every `N/A` has an ownership justification.
8. Packet source revision and worktree identity are consistent across rows.
9. No row relies only on comments, mocks, protocol names, screenshots, or inferred behavior.
10. Missing evidence is visible and dispositioned; it is never silently treated as a pass.

A green static validator proves packet structure only. It does not prove runtime correctness or implementation readiness.

## 5. Gap and contradiction handling

| Finding | Required disposition |
|---|---|
| Missing source/symbol owner | `BLOCKED` |
| Missing direct writer call site | `BLOCKED` or bounded `HOLD` with named search limitation |
| Dynamic/async path unresolved | `BLOCKED` for writer approval; `HOLD` only for documentation follow-up |
| Search tool unavailable | `inventory_incomplete`; no completeness claim |
| Target/access mismatch | `BLOCKED` |
| SQLite lifecycle untested | `BLOCKED` for runtime approval |
| Adjacent writer unclassified | `BLOCKED` |
| Redaction or privacy failure | `BLOCKED` |
| Contradictory source revisions | `BLOCKED` |
| Pure codec/fake-participant opportunity | possible `SPLIT`, separate approval only |
| Packet complete but no runtime evidence | `TARGET_READY_FOR_REVIEW`, never `GO` |

## 6. Disposition rubric

### `BLOCKED` — current default

Use `BLOCKED` when a required owner, writer, lifecycle operation, dynamic path, adjacent exclusion, evidence tier, or source revision is missing or contradictory. M59 cannot issue implementation `GO`.

### `HOLD`

Use `HOLD` only when the packet is not contradicted but one bounded fact remains to be collected. HOLD authorizes no code, store access, pilot, or status promotion.

### `SPLIT`

Use `SPLIT` only for separately approved synthetic packet validation, pure codecs, fake participants, deterministic state machines, or bounded search-fixture work. Synthetic SPLIT cannot open real databases, inspect real user data, establish runtime recovery, or promote M52/M53/status.

### `TARGET_READY_FOR_REVIEW`

Use this only when the packet is structurally complete and independently reviewed enough for a separate implementation-plan review. It does not mean implementation-approved, code-present, or verified.

### `GO`

M59 cannot issue implementation `GO`. A future decision may do so only after M58 packet completion, required runtime evidence, exact path/owner approval, rollback, and M53 handoff.

## 7. Owner approval and handoff

A valid owner packet names:

```text
storage_owner
Honeycomb_owner
EventLedger_owner
adjacent_writer_owner_or_exclusion_owner
implementation_owner
rollback_owner
independent_reviewer
M53_evidence_owner
```

Each owner acknowledges scope, missing evidence, privacy limits, fallback behavior, and the exact disposition. No owner acknowledgement can waive a hard `BLOCKED` condition or turn synthetic evidence into runtime evidence.

M53 remains the required future runtime review: source/diff, build/focused tests, deterministic faults, restart/recovery, manual clean-profile browser, independent review, and exact status decision bound to one source revision/environment/evidence scope.

## 8. Browser, privacy, and rollback boundaries

- Navigation, tabs, private browsing, offline use, accessibility, and manual fallback remain usable when storage is unavailable.
- Storage failure cannot widen model/network context or trigger model, network, connector, OS, or telemetry actions.
- Corrupt storage cannot silently initialize an empty replacement and claim success.
- Packets exclude private content, credentials, cookies, page text, screenshots, raw databases, and unbounded logs.
- Rollback is non-destructive: preserve the dirty worktree, quarantine disposable artifacts, record the limitation, and return to `BLOCKED`/`HOLD`.
- No destructive git cleanup is permitted.

## 9. M59 gates

| Gate | Requirement |
|---|---|
| M59-A | M58 packet scope, participants, and adjacent exclusions are reproduced. |
| M59-B | Current disposition is BLOCKED; M59 cannot issue GO or status promotion. |
| M59-C | Tier 1 source/symbol/call-site evidence is defined. |
| M59-D | Tier 2 SwiftPM/access/actor/Sendable evidence is defined. |
| M59-E | Tier 3 SQLite runtime evidence limits are defined. |
| M59-F | Tier 4 dynamic/async writer coverage is defined. |
| M59-G | Tier 5 independent review and owner disposition are defined. |
| M59-H | Every direct durable writer requires a row or bounded negative result. |
| M59-I | Every indirect/dynamic writer risk is classified. |
| M59-J | Closure/task/delegate/callback paths are explicit. |
| M59-K | Search failures are `inventory_incomplete`, not passes. |
| M59-L | Adjacent writers remain excluded unless a new decision admits them. |
| M59-M | SQLite lifecycle evidence is store-owned and per-store. |
| M59-N | Missing runtime evidence blocks implementation approval. |
| M59-O | Packet source revision and worktree identity are consistent. |
| M59-P | Packet is bounded, redacted, and limitation-bound. |
| M59-Q | BLOCK/HOLD/SPLIT/TARGET_READY_FOR_REVIEW/GO semantics are explicit. |
| M59-R | HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. |
| M59-S | No coordinator database, second ledger, product-data authority, or new participant is proposed. |
| M59-T | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M59-U | Storage failure cannot widen model/network context. |
| M59-V | Owner, rollback, reviewer, and M53 owners are named. |
| M59-W | M53 handoff binds one future source revision and evidence scope. |
| M59-X | Independent review confirms evidence limits and no status inflation. |

## 10. Honest limits and primary references

M59 does not implement or verify lifecycle protocols, writer barriers, backup/restore, close/reopen, migrations, deletion continuity, active-set publication, browser startup, crash recovery, power-loss durability, cross-store atomicity, secure deletion, production readiness, compliance, or ship readiness.

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

These sources establish platform/library limits. M59’s evidence tiers, completeness rules, dispositions, gates, owner packet, and no-status-promotion rules are Hive governance decisions.

**M59 is complete as a planning artifact when the five evidence tiers, completeness rules, gap dispositions, owner packet, 24 gates (M59-A through M59-X), browser/privacy/rollback boundaries, M53 handoff, and independent review are structurally validated.**
