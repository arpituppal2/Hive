# Hive M60 — Owner Evidence Packet & Gap-Register Disposition

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M60 Owner Evidence Packet & Gap-Register Disposition
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m59-storage-authority-inventory-evidence-review-plan.md`
> **Related plans:** M50–M59 storage-authority chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent exclusions:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and other unadmitted writers
> **Current disposition:** `BLOCKED`; M60 cannot issue implementation `GO` or status promotion
>
> Current disposition: BLOCKED. M60 cannot issue implementation GO or status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M60 defines how the M59 review packet is completed owner by owner and how missing, contradictory, stale, or unproven evidence is tracked in a bounded gap register. It does not run the inventory, edit Swift, open real stores, authorize a synthetic pilot, authorize M52, or promote any capability status.

## 0. Decision summary

**Decision: keep M60 BLOCKED until every required packet row has an accountable owner, bounded evidence reference, limitation, disposition, and acknowledgement—and until all hard gaps are closed or explicitly remain BLOCKED.**

M60 separates four things that must not be conflated:

1. **Observation** — what a source, command, fixture, or runtime pass actually showed.
2. **Evidence binding** — which source revision, worktree, environment, command, artifact, and scope the observation belongs to.
3. **Owner acknowledgement** — who accepts responsibility for the row, limitation, fallback, and next action.
4. **Verification** — a separately approved proof that the bounded behavior works under the stated runtime conditions.

Owner acknowledgement is not verification. A hash, signature, or packet identity protects evidence binding from its capture point onward; it does not prove clean origin, runtime correctness, or absence of unobserved paths. M60 cannot convert an acknowledged gap into a pass.

## 1. Binding scope and authority

The production participant set remains exactly:

```text
{Honeycomb, EventLedger}
```

- Honeycomb remains authoritative for knowledge schema, migrations, nodes/edges, provenance, retrieval data, and logical deletion.
- EventLedger remains authoritative for append-only evidence events, event schema/migrations, consent/action history, and ledger deletion semantics.
- `HandoffRecoveryJournal` and `SessionFileStore` remain adjacent writers, excluded from production participation unless a new architecture decision explicitly admits them.
- A future coordinator may project one bounded activation metadata record only; it may not own product data, a schema, migrations, deletion truth, events, a second ledger, or a database.

M60 forbids:

- a coordinator database, second ledger, shadow store, or product-data cache;
- raw SQLite handles, prepared statements, file descriptors, arbitrary SQL, raw page text, prompts, credentials, cookies, private URLs, or model/network payloads in the packet;
- WISP/M5 or any new participant;
- model, network, connector, OS, telemetry, permission, sync, or credential expansion;
- runtime, production, crash-consistency, power-loss, secure-deletion, cross-store atomicity, compliance, or ship claims from the packet or acknowledgement alone.

## 2. M60 packet envelope

A single bounded packet must identify the complete review scope:

```text
m60_packet_id
m59_packet_reference
source_revision
working_tree_identity
working_tree_state
packet_created_at
packet_schema_version
participant_set
adjacent_writer_classifications
claim_scope
owner_matrix
inventory_snapshot_reference
evidence_item_index
gap_register_reference
disposition_history
redaction_policy
rollback_owner
independent_reviewer
M53_evidence_owner
next_smallest_action
```

The packet must be local, bounded, redacted, deterministic to compare, and safe to quarantine. It must not embed raw databases, full SQL, private user content, screenshots as sole proof, absolute user paths, secrets, cookies, credentials, unbounded logs, or an opaque “all clear” assertion.

### 2.1 Evidence item schema

Every evidence item must bind:

```text
evidence_id
packet_id
source_revision
working_tree_identity
environment_identity
owner
reviewer
observation_kind = source | target | compile | runtime | dynamic | manual | synthetic
command_or_method
changed_paths
participant_scope
artifact_or_fixture_id
captured_at
content_digest_or_bounded_identity
observed_result
limitation
freshness_expiry_or_not_applicable
redaction_result
related_gap_ids
claim_level = lead | bounded_fact | runtime_fact | user_observable_fact
```

An item with no command/method, source revision, owner, limitation, or bounded identity is incomplete. A screenshot, green build, mock, fixture, API return code, or owner statement is not sufficient by itself for a stronger claim level.

## 3. Owner-by-owner responsibility matrix

The packet must contain one row for each required responsibility:

| Owner row | Required responsibility | Minimum evidence | Hard gap if absent |
|---|---|---|---|
| `storage_owner` | Cross-store scope, lifecycle boundary, and resource ownership | M59 packet review plus exact authority map | BLOCKED |
| `Honeycomb_owner` | Honeycomb identity/schema/migration/writers/deletion/close evidence | Store-bound inventory and limitation rows | BLOCKED |
| `EventLedger_owner` | Event identity/schema/migration/writers/deletion/close evidence | Store-bound inventory and limitation rows | BLOCKED |
| `adjacent_writer_owner_or_exclusion_owner` | Handoff/session/browser writer exclusion and fallback | Exclusion classification with source/call-site evidence | BLOCKED |
| `implementation_owner` | Exact future changed-path and target scope | Allowlist/excluded-path map; no authorization | HOLD/BLOCKED |
| `rollback_owner` | Non-destructive rollback, quarantine, prior-state preservation | Rollback procedure and stop conditions | BLOCKED |
| `independent_reviewer` | Contradiction, redaction, claim-limit, and status review | Review receipt and critical-issue result | BLOCKED |
| `M53_evidence_owner` | Future runtime evidence scope and handoff | M53-linked claim/receipt map | BLOCKED |

Each owner must acknowledge only the rows within their authority. No owner may acknowledge another owner’s resource, schema, deletion, privacy, or runtime obligation by implication.

## 4. Gap register

The gap register is append-only for dispositions and bounded in content. It tracks absence or contradiction; it is not a task list that silently turns open gaps into “done.”

### 4.1 Gap row schema

```text
gap_id
packet_id
opened_at
opened_by
category = owner | source | writer | dynamic | target | access | sqlite | migration | deletion | recovery | privacy | fallback | rollback | scope | provenance
affected_participant
affected_path_or_symbol
statement_of_gap
discovery_method
related_evidence_ids
severity = hard_block | bounded_hold | synthetic_split_candidate | informational
required_owner
required_evidence
risk_if_unresolved
current_disposition = BLOCKED | HOLD | SPLIT | TARGET_READY_FOR_REVIEW | CLOSED
closure_evidence_ids
closed_at
closed_by
owner_acknowledgement
reviewer_disposition
next_smallest_action
```

### 4.2 Gap lifecycle

A gap follows this monotonic lifecycle:

```text
OPEN → CLASSIFIED → EVIDENCE_REQUESTED →
  BLOCKED | HOLD | SPLIT | TARGET_READY_FOR_REVIEW →
  CLOSED only after bounded closure evidence and independent review
```

- `OPEN` means a possible omission or contradiction has been found.
- `CLASSIFIED` means category, affected owner/path, severity, and evidence requirement are explicit.
- `EVIDENCE_REQUESTED` names the smallest bounded collection action; it does not authorize implementation.
- `BLOCKED` means the missing/contradictory fact prevents the claimed review outcome.
- `HOLD` means one bounded fact remains and no contradiction is proven; HOLD authorizes no code or store access.
- `SPLIT` means separately approved synthetic/codec/state-machine work only; it cannot open real databases or establish runtime recovery.
- `TARGET_READY_FOR_REVIEW` means only that a future implementation plan may receive a separate review; it is not implementation approval or verification.
- `CLOSED` requires evidence that resolves the exact gap, source/owner/path consistency, limitation text, and independent review. Closing a gap never promotes a capability by itself.

A gap may be reopened if its evidence expires, the source revision changes, a new writer/path is discovered, an owner withdraws acknowledgement, or a contradiction appears. No gap may be deleted to make the packet appear complete.

## 5. Evidence and claim-strength rules

| Claim level | May establish | Cannot establish |
|---|---|---|
| `lead` | A search result, source hint, or review question | Completeness or runtime behavior |
| `bounded_fact` | A source/target/access/worktree fact under one revision | Dynamic reachability, SQLite safety, recovery |
| `runtime_fact` | Tested behavior under named environment/workload | Universal durability, all hardware/filesystems, power-loss safety |
| `user_observable_fact` | A manual/UI path observed under named profile/environment | Internal store correctness or browser-wide quality |

Static Swift/SwiftPM evidence can establish declarations, access, target membership, and compiler diagnostics. It cannot establish that every closure/task/delegate/dynamic path was exercised, that semantic writer barriers cover all callers, or that files are isolated at runtime.

SQLite runtime evidence can establish only tested behavior under the stated process, OS, SQLite version, workload, and fault harness. It cannot by itself establish universal power-loss durability, secure/forensic deletion, or cross-store atomicity.

Owner acknowledgement can establish governance responsibility and acceptance of a limitation. It cannot replace a build, focused test, dynamic writer pass, SQLite runtime pass, restart/recovery pass, or manual browser pass.

## 6. Review and disposition rubric

### `BLOCKED` — current default

Use `BLOCKED` when any hard owner, direct/indirect writer, dynamic path, lifecycle resource, authority boundary, privacy rule, source revision, or required evidence tier is missing or contradictory. M60 cannot issue implementation `GO`.

### `HOLD`

Use `HOLD` only when a bounded fact remains to be collected and no contradiction is proven. HOLD authorizes no code, store access, pilot, or status promotion.

### `SPLIT`

Use `SPLIT` only for separately approved synthetic packet validation, pure codecs, fake participants, deterministic state machines, or search fixtures. Synthetic SPLIT cannot open real databases, inspect real user data, establish runtime recovery, or promote M52/M53/status.

### `TARGET_READY_FOR_REVIEW`

Use this only when the owner packet and gap register are structurally complete enough for a separate implementation-plan review. It does not mean implementation-approved, code-present, or verified.

### `GO`

M60 cannot issue implementation `GO`. A future decision requires closed hard gaps, fresh M53 runtime evidence, exact path/owner approval, non-destructive rollback, and one source revision/environment/evidence scope. M60 cannot promote status.

## 7. Privacy, fallback, and rollback

- Navigation, tabs, private browsing, offline use, accessibility, and manual work remain usable when storage is unavailable.
- Storage failure cannot widen model/network context or trigger model, network, connector, OS, telemetry, or permission actions.
- Corrupt storage cannot silently initialize an empty replacement and claim success.
- Packet and gap artifacts exclude private content, credentials, cookies, page text, raw databases, screenshots as sole proof, and unbounded logs.
- Rollback is non-destructive: preserve the dirty worktree, quarantine disposable artifacts, retain the prior packet/gap history, record limitations, and return to `BLOCKED`/`HOLD`.
- No destructive git cleanup is permitted.

## 8. M53 handoff

M60 may produce only a bounded handoff request for future M53 review. That request must bind:

```text
m53_claim_scope
m53_evidence_owner
source_revision
working_tree_identity
environment_identity
closed_or_explicitly_blocked_gap_ids
required_runtime_tiers
browser_manual_path_scope
privacy_redaction_receipt
independent_review_receipt
next_smallest_action
```

M53 remains the required runtime evidence boundary. M60 owner acknowledgement or a structurally complete packet cannot substitute for M53 source/diff, build/focused tests, deterministic faults, restart/recovery, manual clean-profile browser, and independent review.

## 9. M60 gates

| Gate | Requirement |
|---|---|
| M60-A | M59 scope, participants, exclusions, and current BLOCK are reproduced. |
| M60-B | Current disposition is BLOCKED; M60 cannot issue GO or status promotion. |
| M60-C | Packet envelope binds source revision, worktree, environment, scope, and schema identity. |
| M60-D | Every evidence item has an owner, method, bounded identity, observation, limitation, and claim level. |
| M60-E | Owner matrix names storage, Honeycomb, EventLedger, adjacent-writer, implementation, rollback, reviewer, and M53 owners. |
| M60-F | Owners acknowledge only obligations within their authority. |
| M60-G | Gap register schema is append-only, bounded, and disposition-aware. |
| M60-H | Gap lifecycle prevents silent closure or deletion. |
| M60-I | Hard gaps, bounded holds, synthetic candidates, and informational gaps are distinguished. |
| M60-J | Static/source/build evidence is separated from dynamic and runtime evidence. |
| M60-K | SQLite evidence limits exclude universal durability, secure deletion, and cross-store atomicity claims. |
| M60-L | Direct, indirect, closure/task/delegate, and adjacent-writer risks remain explicit. |
| M60-M | `inventory_incomplete` and stale/contradictory evidence remain non-passing states. |
| M60-N | `{Honeycomb, EventLedger}` remains the only production participant set. |
| M60-O | HandoffRecoveryJournal and SessionFileStore remain excluded unless separately admitted. |
| M60-P | No coordinator database, second ledger, product-data authority, or new participant is proposed. |
| M60-Q | HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. |
| M60-R | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M60-S | Storage failure cannot widen model/network context. |
| M60-T | Packet artifacts are redacted, bounded, local, and safe to quarantine. |
| M60-U | Rollback preserves dirty work, packet history, and prior limitations non-destructively. |
| M60-V | M53 handoff binds one future source revision, environment, claim, and evidence scope. |
| M60-W | No owner acknowledgement is treated as runtime verification. |
| M60-X | Independent review is required before any future runtime claim or status decision. |

## 10. Honest limits and primary references

M60 does not complete the M59 inventory, close real runtime gaps, implement lifecycle protocols, verify writer barriers, run SQLite recovery, prove migration/deletion continuity, validate browser startup, establish crash consistency, prove power-loss durability, prove cross-store atomicity, establish secure deletion, certify compliance, or establish production/ship readiness.

Primary references:

- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html)
- [SQLite result codes](https://www.sqlite.org/rescode.html)
- [Swift Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift Package Manager](https://www.swift.org/documentation/package-manager/)
- [Apple XCTest](https://developer.apple.com/documentation/xctest)
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Apple FileManager replacement](https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:))

These sources establish platform/library limits. M60’s packet schema, owner matrix, gap lifecycle, dispositions, gates, redaction, fallback, rollback, and no-status-promotion rules are Hive governance decisions.

**M60 is complete as a planning artifact when its packet envelope, evidence-item schema, owner matrix, append-only gap lifecycle, claim-strength rules, disposition rubric, M53 handoff, 24 gates (M60-A through M60-X), rollback rules, and independent review are structurally validated.**
