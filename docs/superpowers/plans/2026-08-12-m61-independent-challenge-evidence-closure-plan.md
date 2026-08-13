# Hive M61 — Independent Challenge & Evidence-Closure Decision

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M61 Independent Challenge & Evidence-Closure Decision
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m60-owner-evidence-packet-gap-register-plan.md`
> **Related plans:** M50–M60 storage-authority chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent exclusions:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and other unadmitted writers
> **Current disposition:** `BLOCKED`; M61 cannot issue implementation `GO` or status promotion
>
> Current disposition: BLOCKED. M61 cannot issue implementation GO or status promotion.
>
> M61 performs no runtime evidence work and does not edit Swift. HOLD, SPLIT, and TARGET_READY_FOR_REVIEW authorize no code or store access. M61 cannot issue status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M61 defines how an independent reviewer challenges the M60 owner packet, tests its evidence-closure claims, reopens stale or contradicted gaps, and decides whether the documentation is structurally ready for a separate implementation-plan review. It does not run runtime evidence, edit Swift, open real stores, authorize a pilot, authorize M52, or promote any capability status.

## 0. Decision summary

**Decision: retain `BLOCKED` until an independent challenge finds no unresolved hard contradiction and every claimed closure is bound to fresh, bounded evidence.**

M61 separates:

1. **Evidence freshness** — whether an observation still applies to the exact source revision, worktree, environment, target, and claim scope.
2. **Reproducibility** — whether an independent reviewer can repeat the bounded method or inspect a stable artifact/fixture identity.
3. **Challenge** — an adversarial but scoped attempt to find omissions, contradictions, unauthorized scope, stale facts, privacy leaks, or inflated claims.
4. **Closure** — an evidence-backed resolution of one exact gap; closure is never deletion of a row or a change of wording.
5. **Readiness** — a documentation result that may qualify for a separate implementation-plan review, never implementation approval or verification.

A signature, digest, owner acknowledgement, static validator, green build, mock, fixture, or packet hash may support provenance or governance, but none proves runtime correctness, complete dynamic coverage, SQLite recovery, power-loss durability, secure deletion, or cross-store atomicity.

## 1. Binding scope and authority

The production participant set remains exactly:

```text
{Honeycomb, EventLedger}
```

- Honeycomb remains authoritative for knowledge schema, migrations, nodes/edges, provenance, retrieval data, and logical deletion.
- EventLedger remains authoritative for append-only evidence events, event schema/migrations, consent/action history, and ledger deletion semantics.
- `HandoffRecoveryJournal` and `SessionFileStore` remain mapped adjacent writers, excluded from production participation unless a new architecture decision explicitly admits them.
- WISP/M5 remain unregistered and blocked.
- A future coordinator may project one bounded activation metadata record only; it may not own product data, schema/migrations, deletion truth, events, a second ledger, or a database.

M61 forbids:

- implementation or runtime authorization;
- raw SQLite handles, prepared statements, file descriptors, arbitrary SQL, raw databases, private user content, credentials, cookies, private URLs, prompts, screenshots as sole proof, model/network payloads, or unbounded logs in the challenge packet;
- scope expansion to new stores, participants, models, network, connectors, OS actions, telemetry, permissions, sync, or training;
- status promotion from planning evidence alone.

## 2. Freshness and reproducibility envelope

Every challenged evidence item must bind:

```text
challenge_id
m60_packet_reference
evidence_id
source_revision
working_tree_identity
working_tree_state
environment_identity
macos_version
swift_toolchain
sqlite_runtime_version
package/target_identity
command_or_method
changed_paths
participant_scope
claim_scope
captured_at
freshness_rule
artifact_or_fixture_identity
content_digest_or_bounded_identity
owner
independent_reviewer
limitation
```

### 2.1 Freshness rules

Evidence is stale and must reopen affected gaps when:

- the source revision, approved changed-path set, target membership, or participant scope changes;
- the working tree changes in a relevant path or its baseline is no longer reproducible;
- the OS, Swift toolchain, SQLite runtime, filesystem/container, or test workload changes beyond the stated claim envelope;
- a dependency, entitlement, permission, schema, migration, or lifecycle contract changes;
- its declared expiry passes or the owner cannot explain why no expiry applies;
- a new direct, indirect, closure, task, delegate, notification, C-API, process, or adjacent-writer path is discovered;
- a reviewer or owner withdraws the evidence or identifies a contradiction.

A freshness timestamp is not a universal validity period. The packet must state the rule and limitation for each item.

### 2.2 Reproducibility rules

A reviewer may classify an item as reproducible only when the bounded method, inputs, environment, artifact/fixture identity, expected observation, and limitation are recorded. Reproducibility means the stated observation can be independently checked within its envelope; it does not prove all environments or unobserved runtime paths.

## 3. Independent challenge packet

The M61 challenge packet must be separate from, and reference, the M60 packet:

```text
m61_challenge_id
m60_packet_reference
source_revision
working_tree_identity
challenge_scope
challenge_queries
challenge_methods
challenge_exclusions
evidence_items_reviewed
gap_rows_reviewed
contradictions_found
freshness_findings
reproducibility_findings
privacy_redaction_result
unauthorized_scope_result
owner_conflicts
reviewer_conflicts
reopened_gap_ids
closure_candidates
current_disposition
independent_review_result
rollback_owner
M53_evidence_owner
next_smallest_action
```

The challenge packet must be local, bounded, redacted, deterministic to compare, and safe to quarantine. It must not include raw databases, private page text, credentials, cookies, private URLs, full SQL, screenshots as sole proof, arbitrary absolute paths, model/network payloads, or unbounded logs.

### 3.1 Required challenge passes

The independent reviewer must perform bounded passes over:

1. **Scope** — participant set, exclusions, changed paths, target membership, and forbidden authority.
2. **Owner** — whether each owner has the authority claimed and acknowledged only the relevant row.
3. **Source** — declarations, access, call sites, imports, target boundaries, and negative-search limitations.
4. **Writer** — direct, indirect, protocol/generic, closure/task/delegate, notification/callback, C-API, multi-instance/process, and adjacent-writer risks.
5. **Lifecycle** — open/migrate/WAL/SHM/checkpoint/backup/close/reopen/deletion/recovery ownership and evidence limits.
6. **Privacy/fallback** — packet redaction, private/offline/accessibility/manual browser continuity, and no context widening after storage failure.
7. **Claim** — whether every status, closure, and readiness phrase is no stronger than its evidence.
8. **Handoff** — whether future M53 claims, source revision, environment, and runtime tiers are explicitly bounded.

A failed search tool, unavailable source, missing runtime environment, or unreadable artifact is an evidence limitation, not a clean result.

## 4. Challenge findings and contradiction rules

| Finding | Required action |
|---|---|
| Proven authority or participant expansion | Immediate `BLOCKED`; stop; reopen architecture decision |
| Unauthorized changed path or target expansion | `BLOCKED`; reopen approval/allowlist |
| Contradictory source revisions or environments | `BLOCKED`; invalidate affected closures |
| Missing owner authority or conflicting owner acknowledgements | `BLOCKED` for affected responsibility |
| Missing direct/indirect/dynamic writer coverage | `BLOCKED` for writer approval |
| Unresolved SQLite lifecycle/resource claim | `BLOCKED` for runtime approval |
| Stale evidence within a claimed closure | Reopen gap; `BLOCKED` or `HOLD` by severity |
| Search/tool failure | `inventory_incomplete`; no completeness claim |
| Privacy/redaction failure | `BLOCKED`; quarantine packet |
| Pure synthetic/codec/state-machine opportunity | possible `SPLIT`, separate approval only |
| One bounded fact missing without contradiction | `HOLD`; no code or store access |
| Complete structural packet but runtime evidence absent | `TARGET_READY_FOR_REVIEW`, never `GO` |

A contradiction is not resolved by choosing the more convenient source, deleting a row, weakening the claim, or adding an owner signature. The affected gap and all dependent closure claims must be reopened.

## 5. Gap closure and reopening

### 5.1 Closure requirements

A gap may move to `CLOSED` only when all of the following are present:

- the exact gap statement remains unchanged and is traceable to its opening evidence;
- a bounded new observation or authoritative limitation addresses that statement;
- source revision, worktree, environment, participant, path, and claim scope are consistent;
- the required owner acknowledges the resolution and limitation within their authority;
- the independent reviewer checks the closure and finds no unresolved critical contradiction;
- related gap rows and dependent claims are updated without deleting history;
- the closure names what remains unproven and the next evidence boundary.

Closing a gap does not promote a capability. It only records that the exact gap was addressed within the stated envelope.

### 5.2 Reopening rules

A closed gap must reopen if:

- evidence expires or its freshness envelope changes;
- the source revision, environment, target, participant, path, schema, or dependency changes;
- a new writer, resource, dynamic dispatch path, adjacent writer, or privacy surface is found;
- an owner withdraws acknowledgement or loses authority;
- a reviewer identifies a contradiction, unsupported claim, redaction issue, or reproducibility failure;
- M53 runtime evidence disagrees with the planning closure;
- the closure depended on synthetic evidence that was later presented as runtime evidence.

Reopening is append-only. The old closure remains historical with its limitation; it must not be rewritten to appear never to have existed.

## 6. Owner and reviewer authority

### 6.1 Owner limits

Owners may:

- identify the resource, schema, lifecycle, browser, privacy, rollback, or evidence responsibility they actually own;
- acknowledge a bounded observation and its limitation;
- accept a next evidence action within their scope;
- withdraw or supersede their acknowledgement.

Owners may not self-approve missing runtime facts, waive a hard boundary, admit an adjacent writer, convert a synthetic result into runtime proof, or promote status by signature.

### 6.2 Independent reviewer limits

The independent reviewer must not be the sole author of the packet or the implementation claim being reviewed. The reviewer may:

- challenge methods, scope, freshness, reproducibility, redaction, contradictions, and claim strength;
- reopen gaps and classify evidence as insufficient;
- return `BLOCKED`, `HOLD`, `SPLIT`, or `TARGET_READY_FOR_REVIEW` under this contract;
- require a smaller next action.

The reviewer may not authorize runtime implementation, waive a raw-handle/authority boundary, or issue M53 verification. A “no critical issues” review is evidence about the reviewed packet, not proof of runtime correctness.

## 7. Dispositions

### `BLOCKED` — current default

Use `BLOCKED` for any hard contradiction, missing owner authority, stale required evidence, unresolved writer/lifecycle path, unauthorized scope, privacy failure, or unsupported claim. M61 cannot issue implementation `GO`.

### `HOLD`

Use `HOLD` only when one bounded fact remains, no contradiction is proven, and the next collection action is explicit. HOLD authorizes no code, store access, pilot, or status promotion.

### `SPLIT`

Use `SPLIT` only for separately approved synthetic packet checks, pure codecs, fake participants, deterministic state machines, or search fixtures. Synthetic SPLIT cannot open real databases, inspect user data, establish runtime recovery, or promote M52/M53/status.

### `TARGET_READY_FOR_REVIEW`

Use this only when the challenge packet is structurally complete, all hard gaps are either closed or explicitly excluded from the bounded target, freshness/reproducibility limits are visible, independent review is complete, and the next implementation plan can be reviewed separately. It does not mean implementation-approved, code-present, verified, or runtime-ready.

### `GO`

M61 cannot issue implementation `GO`. A future decision requires a separate approved implementation packet, fresh M53 runtime evidence, exact path/owner approval, rollback, and one source revision/environment/evidence scope.

## 8. Browser, privacy, and rollback boundaries

- Navigation, tabs, private browsing, offline use, accessibility, and manual work remain usable when storage is unavailable.
- Storage failure cannot widen model/network context or trigger model, network, connector, OS, telemetry, permission, or sync actions.
- Corrupt storage cannot silently initialize an empty replacement and claim success.
- Challenge artifacts exclude private content, credentials, cookies, page text, raw databases, screenshots as sole proof, and unbounded logs.
- Rollback is non-destructive: preserve the dirty worktree, quarantine disposable packets/artifacts, retain prior gap history, record limitations, and return to `BLOCKED`/`HOLD`.
- No destructive git cleanup is permitted.

## 9. M53 handoff

M61 may produce only a bounded request for future M53 runtime review:

```text
m53_claim_scope
m53_evidence_owner
source_revision
working_tree_identity
environment_identity
closed_gap_ids
reopened_gap_ids
explicitly_blocked_gap_ids
required_runtime_tiers
browser_manual_path_scope
privacy_redaction_receipt
independent_review_receipt
next_smallest_action
```

M53 remains the required runtime boundary. M61 challenge/closure evidence cannot substitute for M53 source/diff, build/focused tests, deterministic faults, restart/recovery, manual clean-profile browser, or independent review.

## 10. M61 gates

| Gate | Requirement |
|---|---|
| M61-A | M60 packet, scope, participants, exclusions, and current BLOCK are reproduced. |
| M61-B | Production participants remain exactly `{Honeycomb, EventLedger}`. |
| M61-C | HandoffRecoveryJournal and SessionFileStore remain excluded unless separately admitted. |
| M61-D | WISP/M5 remain blocked and unregistered. |
| M61-E | No coordinator database, second ledger, product-data authority, or new semantic authority is proposed. |
| M61-F | Freshness envelope binds source revision, worktree, environment, target, and claim scope. |
| M61-G | Reproducibility requires a bounded method, input, artifact/fixture, observation, and limitation. |
| M61-H | Challenge packet is local, bounded, redacted, and safe to quarantine. |
| M61-I | Scope, owner, source, writer, lifecycle, privacy, claim, and handoff challenge passes are explicit. |
| M61-J | Proven contradictions force `BLOCKED` and reopen dependent gaps. |
| M61-K | Stale evidence reopens affected closures. |
| M61-L | Search/tool failures are `inventory_incomplete`, not clean results. |
| M61-M | Gap closure requires bounded evidence, owner acknowledgement, and independent review. |
| M61-N | Gap history is append-only; no gap can be deleted to imply completion. |
| M61-O | New writers, paths, environments, dependencies, or withdrawn authority reopen gaps. |
| M61-P | Owner authority is limited to owned observations and limitations. |
| M61-Q | Reviewer authority is independent challenge and disposition, not runtime authorization. |
| M61-R | `TARGET_READY_FOR_REVIEW` means structural readiness only, never implementation approval. |
| M61-S | Synthetic `SPLIT` cannot open real databases, inspect user data, or prove recovery. |
| M61-T | `HOLD` authorizes no code or store access; `BLOCKED` remains the default. |
| M61-U | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M61-V | Storage failure cannot widen model/network/OS context. |
| M61-W | M53 handoff binds one future source revision, environment, claim, and evidence scope. |
| M61-X | Independent review finds no unresolved critical contradiction before any future readiness label. |

## 11. Honest limits and primary references

M61 does not complete M60’s packet, close real runtime gaps, implement lifecycle protocols, verify writer barriers, run SQLite recovery, prove migration/deletion continuity, validate browser startup, establish crash consistency, prove power-loss durability, prove secure/forensic deletion, prove cross-store atomicity, certify compliance, or establish production/ship readiness.

Primary references:

- [SLSA v1.0 build levels](https://slsa.dev/spec/v1.0/levels)
- [NIST SP 800-53 Rev. 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)
- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html)
- [SQLite result codes](https://www.sqlite.org/rescode.html)
- [Swift Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Apple Signing and Verifying](https://developer.apple.com/documentation/security/signing-and-verifying)
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)

These sources establish platform, library, provenance, audit, and change-control limits. M61’s challenge packet, freshness rules, closure/reopening lifecycle, dispositions, gates, fallback, rollback, and no-status-promotion rules are Hive governance decisions.

**M61 is complete as a planning artifact when its freshness/reproducibility envelope, independent challenge packet, contradiction rules, closure/reopening lifecycle, owner/reviewer authority limits, disposition rubric, M53 handoff, 24 gates (M61-A through M61-X), rollback rules, and independent review are structurally validated.**
