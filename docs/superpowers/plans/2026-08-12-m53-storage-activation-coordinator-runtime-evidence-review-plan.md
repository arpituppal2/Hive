# Hive M53 — StorageActivationCoordinator Runtime Evidence Review

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation or status promotion authorized
> **Roadmap label:** M53 StorageActivationCoordinator Runtime Evidence Review
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m52-storage-activation-coordinator-runtime-implementation-plan.md`
> **Architecture decision:** `docs/superpowers/plans/2026-08-12-m50-storage-activation-coordinator-architecture-decision-plan.md`
> **Readiness contract:** `docs/superpowers/plans/2026-08-12-m51-storage-activation-coordinator-implementation-readiness-plan.md`
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Participant set:** `{Honeycomb, EventLedger}` only
> **Next boundary:** separately approved M52 execution, then M53 evidence collection/review; this document does not execute either
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M53 defines how a future M52 implementation is reviewed and how capability status may or may not be promoted. It does not create runtime code, tests, fixtures, evidence, UI, databases, ledgers, or release artifacts.

## 0. Decision summary

**Decision: require a tiered, source-bound evidence review before any status promotion.**

M52 can produce implementation artifacts only after separate approval. M53 then evaluates those artifacts using independent evidence tiers:

```text
source/diff audit
  → fresh build and focused tests
    → deterministic integration/fault evidence
      → restart/recovery harness
        → manual clean-profile browser path
          → independent review and status decision
```

No single tier is sufficient. A green build does not prove persistence. A passing mock filesystem does not prove filesystem behavior. A restart harness does not prove physical power-loss durability. A successful file-replacement API call does not prove cross-store atomicity. A manual browser path does not prove internal database correctness. A capability becomes `verified` only when all required tiers for its claim pass under one source revision, environment, evidence scope, and explicit owner approval.

## 1. Binding boundaries

### 1.1 Scope

M53 reviews only the M52 initial slice:

```text
{Honeycomb, EventLedger}
+ new Activation source files
+ new Activation test files
+ any separately approved allowlist extension
```

WISP/M5 remain planned, blocked, and unregistered. M53 cannot promote them, infer their readiness, or treat a two-store result as broader M0 verification.

### 1.2 Status vocabulary

Use the repository’s existing labels exactly:

| Status | M53 meaning |
|---|---|
| `planned` | Contract named but no implementation/evidence packet. |
| `scaffold` | Some code or test surface exists, but required runtime dependency/evidence is absent. |
| `code-present` | Implementation exists, but the required evidence stack has not passed. |
| `blocked` | Review cannot proceed because a required owner, environment, path, permission, or evidence tier is unavailable. |
| `verified` | Fresh source audit, relevant build/tests, required integration/fault/restart evidence, user-observable path, independent review, and owner approval all pass for the exact bounded claim. |

`verified` is never inferred from source presence, mock success, fixture definitions, API return codes, screenshots, historical counts, or plan validation.

### 1.3 Authority limits

M53 must reject any implementation/evidence packet that introduces:

- a coordinator database, second ledger, product-data authority, raw store snapshot, model context, credentials, cookies, private URLs, screenshots, or unbounded paths;
- raw SQLite-handle transfer across the coordinator boundary;
- WISP/M5 registration or scope;
- a new startup, permission, network, sync, connector, telemetry, or OS authority;
- evidence that claims power-loss durability, filesystem crash consistency, cross-database atomicity, secure deletion, compliance, production readiness, or ship readiness without separate target-specific proof.

Honeycomb remains authoritative for knowledge contents and logical deletion. EventLedger remains authoritative for append-only evidence. M53 reviews their typed participant results; it does not merge their authorities.

## 2. Evidence envelope and chain of custody

Every M53 evidence item must bind:

```text
trace_id
source_revision
working_tree_identity
environment
os_version
swift_toolchain
sqlite_runtime_version
test_or_runtime_command
changed_paths
participant_set
evidence_scope
owner
observed_state
limitation
artifact_hash_or_fixture_id
```

The packet must record whether the item is synthetic, integration, manual, or release evidence. Evidence must be local, bounded, redacted, and free of raw page text, browsing history, private URLs, credentials, cookies, prompts, screenshots, full database dumps, full SQL, arbitrary absolute paths, model output, and unbounded logs.

A reviewer must reject a packet when evidence items come from mixed source revisions, undocumented environments, changed working trees, unknown test commands, or an unbounded scope. If a test requires a fixture or mock, the packet must name the exact limitation and must not label that result production evidence.

## 3. Six evidence tiers

### 3.1 Tier A — Source and diff audit

Confirm:

- exact source revision and dirty-tree state;
- changed paths equal the approved M52 allowlist;
- no existing store/browser/Package.swift/entitlement file changed without approval;
- no raw `OpaquePointer` crosses the coordinator boundary;
- no coordinator database, second ledger, product-data record, or forbidden participant exists;
- every direct durable writer is either inside the approved barrier or the result is `blocked`;
- error/result/evidence types are bounded and redacted;
- M52 stop conditions are represented in code/tests.

A source audit can establish scope and static contract adherence. It cannot establish runtime behavior or durability.

### 3.2 Tier B — Fresh build and focused tests

Run, on the exact audited revision:

```text
swift build
swift test --filter Activation
```

If the target has no filterable Activation suite, record the exact replacement command and why. The packet must include compiler/toolchain, platform, warnings, test count, failures, skipped tests, and duration.

Required test families:

- metadata golden codec/rejection;
- filesystem containment/publication/quarantine;
- actor state/reentrancy/cancellation;
- participant identity/schema/health/deletion-floor checks;
- resource closure and typed busy/locked/close outcomes;
- startup selection and prior-generation fallback;
- privacy/redaction and forbidden-scope rejection.

A focused test suite establishes executed test behavior on the test environment. It cannot establish physical power-loss guarantees, all filesystem implementations, or full browser UX.

### 3.3 Tier C — Integration and deterministic fault evidence

Run the M52 adapters against disposable local stores and an injected filesystem/fault harness. Cover:

1. successful PREPARED → reopen/revalidate → COMMITTED flow;
2. codec malformed/oversized/hash/identity rejection;
3. path escape, permission, write, flush, replace, quarantine, and interruption failure;
4. `SQLITE_BUSY`, `SQLITE_LOCKED`, incomplete backup, statement-finalize, transaction, and close failure;
5. barrier timeout, direct-writer bypass, cancellation, duplicate operation, and stale-generation resume;
6. deletion-floor mismatch and no-resurrection projection;
7. no-prior-generation blocked/degraded state;
8. redacted bounded evidence and no model/network widening.

Every injected failure must preserve the prior complete generation where available, release resources exactly once, reject mixed/PREPARED selection, and keep the browser fallback contract intact.

Fault injection establishes modeled failure handling. It cannot establish kernel-level power loss, arbitrary hardware failure, or every third-party filesystem behavior.

### 3.4 Tier D — Restart and recovery harness

Use disposable synthetic stores/artifacts and a deterministic process-boundary harness to test:

- valid committed generation selection;
- missing, truncated, malformed, unsupported, hash-mismatched, quarantined, and interrupted metadata;
- mixed-generation Honeycomb/EventLedger rejection;
- prior-generation fallback;
- no complete generation → blocked/degraded state;
- WAL-aware store reopen and participant identity revalidation;
- deletion-generation continuity after restart;
- no empty durable-store initialization after corruption;
- repeat startup selection is idempotent.

The packet must state that a simulated restart is not a physical power-loss proof. If a process-kill experiment is run, record it separately as exploratory evidence with OS/filesystem/tool limitations; never convert it into a universal durability claim.

### 3.5 Tier E — Manual clean-profile browser path

On a clean profile and the target macOS build, perform a user-observable path:

1. Launch with valid committed metadata and confirm ordinary browser startup.
2. Navigate, switch tabs, use private browsing, and perform manual browser work.
3. Inject or stage a coordinator/storage failure before startup or during activation.
4. Confirm browsing, tabs, rendering, keyboard, accessibility, offline/manual work remain usable.
5. Confirm memory/audit-dependent operations show typed unavailable/degraded/blocked state.
6. Confirm no in-memory success is presented as durable.
7. Confirm no model/network call is triggered by storage failure.
8. Confirm bounded retry/export/limitation status is understandable.
9. Restore a valid generation and confirm the UI does not claim recovery before revalidation.

Manual evidence must identify exact steps, observed result, limitations, and whether the result was recorded through accessibility/UI automation or human observation. A screenshot alone is not proof of internal state.

### 3.6 Tier F — Independent review and owner decision

A reviewer who did not author the implementation packet must inspect:

- source/diff audit;
- all evidence envelopes and source-revision consistency;
- failures, skips, flaky tests, and unsupported claims;
- changed-path and authority boundaries;
- browser-first fallback;
- privacy/redaction;
- rollback and unresolved limitations.

The owner must then issue one explicit result:

```text
verified_for_bounded_claim
code_present_evidence_incomplete
blocked_missing_required_evidence
rejected_scope_or_authority_violation
```

The result must name the exact capability claim. “M53 passed” without a bounded claim is invalid.

## 4. Status-promotion rules

### 4.1 Eligible bounded claim

A claim can be promoted to `verified` only if:

- Tier A passes with no unauthorized changed paths;
- Tier B passes on the same source revision;
- all required Tier C cases pass or are explicitly marked not applicable by an owner with evidence;
- Tier D passes for the claimed recovery behavior;
- Tier E passes for the claimed user-observable browser behavior;
- Tier F independent review is `none` for high-severity issues;
- owner approval names the exact claim, source revision, environment, and limitation;
- no M52 stop condition is present;
- M53 evidence itself is not being used to claim more than the bounded M52 slice.

### 4.2 Claims that remain blocked

Even a fully passing M53 packet cannot promote:

- power-loss durability or filesystem crash consistency;
- cross-database atomicity or distributed transactions;
- secure/forensic deletion;
- WISP/M5/M45/M2 readiness;
- production, compliance, release, or ship status;
- browser-wide quality beyond the tested path;
- any file/path/participant outside the approved M52 slice.

### 4.3 Failure and rollback

If any required tier fails:

- status remains `code-present`, `scaffold`, or `blocked` as appropriate;
- the failing evidence item is retained with bounded limitation text;
- candidate metadata is quarantined and prior complete generation preserved where applicable;
- barriers/resources are verified released;
- no status is promoted because other tiers passed;
- a follow-up plan names one smallest corrective boundary.

If an authority or changed-path violation is found, classify the result `rejected_scope_or_authority_violation`, stop execution, and require a new architecture/approval decision before further edits.

## 5. Evidence matrix

All fixtures are synthetic, local, bounded, disposable, and free of user data. Fixture mappings are requirements, not evidence that the runtime exists.

| IDs | Evidence family | Required result |
|---|---|---|
| M53-01–05 | source/diff | exact revision, dirty tree, allowlist, raw-handle scan, forbidden-authority scan |
| M53-06–10 | build/tests | fresh build, focused suite, warning/failure/skip accounting, codec/actor/privacy tests |
| M53-11–15 | publication faults | path containment, staged write, replace, quarantine, prior-generation preservation |
| M53-16–20 | SQLite/participant faults | busy/locked/close/backup/transaction/identity/schema/deletion-floor handling |
| M53-21–25 | actor/recovery faults | cancellation, stale await, duplicate operation, mixed generation, no-prior-generation |
| M53-26–30 | restart harness | valid selection, malformed/prepared rejection, fallback, idempotent reopen, no empty-store replacement |
| M53-31–35 | privacy/fallback | redaction, no model/network widening, private/offline/locked/denied/manual/accessibility paths |
| M53-36–40 | manual browser | clean-profile launch, navigation/tabs, storage failure, typed degraded state, recovery disclosure |
| M53-41–45 | review/decision | independent review, owner approval, exact bounded claim, limitations, status result |

## 6. M53 gates

| Gate | Requirement |
|---|---|
| M53-A | Exact source revision, environment, working-tree state, and approved M52 allowlist are recorded. |
| M53-B | No unauthorized existing-store, browser, Package.swift, entitlement, participant, or authority change exists. |
| M53-C | No coordinator database, second ledger, product-data authority, raw content, secrets, or raw SQLite-handle transfer exists. |
| M53-D | Fresh build and focused Activation tests pass on the audited revision, with skips/warnings accounted for. |
| M53-E | Codec and metadata rejection evidence passes. |
| M53-F | Filesystem containment/publication/quarantine evidence passes within documented platform limits. |
| M53-G | SQLite busy/locked/backup/close/transaction evidence fails closed. |
| M53-H | Participant identity/schema/health/deletion-floor evidence matches. |
| M53-I | Writer barrier, cancellation, duplicate-operation, and stale-generation evidence passes. |
| M53-J | No mixed or PREPARED generation is selectable. |
| M53-K | Restart/recovery harness passes valid selection, fallback, quarantine, and no-prior-generation behavior. |
| M53-L | Deletion continuity prevents snapshot resurrection in tested projections. |
| M53-M | Browser/private/offline/locked/denied/accessibility/manual fallback remains usable. |
| M53-N | Storage failure does not widen model/network context. |
| M53-O | Manual clean-profile path is user-observable and reproducible. |
| M53-P | Evidence is redacted, bounded, trace-bound, limitation-bound, and source-revision consistent. |
| M53-Q | Independent high-severity review is clear or all critical issues are resolved. |
| M53-R | Owner issues one exact bounded status result. |
| M53-S | Failed evidence preserves prior generation, quarantines candidates, and releases resources. |
| M53-T | Power-loss, crash-consistency, cross-database atomicity, production, compliance, and ship claims remain explicitly blocked. |
| M53-U | WISP/M5/M45/M2 scope remains blocked and unpromoted. |
| M53-V | Any changed-path expansion reopens M52 rather than being accepted in review. |
| M53-W | M53 result is appended to the evidence/hand-off record with next smallest action. |

## 7. Required review packet

A future M53 review cannot start without:

```text
m52_approval_packet
source_revision
changed_paths
participant_set
build_receipt
focused_test_receipt
fault_injection_receipt
restart_harness_receipt
manual_browser_receipt
privacy_redaction_receipt
independent_review_receipt
owner_status_decision
known_limitations
next_smallest_action
```

The packet must identify the exact bounded claim and the exact statuses that remain blocked. It must not include raw databases, secrets, private content, screenshots as sole proof, or unbounded logs.

## 8. Explicit deferrals and honest limits

M53 does not implement, execute, or verify:

- the M52 coordinator runtime itself;
- physical power-loss durability, universal filesystem crash consistency, secure deletion, disaster recovery, distributed transactions, compliance, production readiness, or ship readiness;
- WISP/M5/M45/M2, models/training, sync, connectors, OS automation, cloud backup, release, or browser-wide quality;
- any capability outside the exact M52 allowlist and `{Honeycomb, EventLedger}` participant set.

**M53 is complete as a planning artifact when its six evidence tiers, 45 evidence mappings, 23 gates, status-promotion rules, rollback policy, required packet, and independent review criteria are structurally validated.**

## 9. Primary references and claim limits

- [SQLite WAL](https://www.sqlite.org/wal.html) — WAL sidecars, checkpointing, single-writer behavior, and limitations.
- [SQLite Online Backup API](https://www.sqlite.org/backup.html) — consistent snapshot mechanics and limits.
- [SQLite `sqlite3_backup_finish`](https://www.sqlite.org/c3ref/backup_finish.html) — cleanup and prior-error behavior.
- [SQLite `sqlite3_close`](https://www.sqlite.org/c3ref/close.html) — unfinished statements/backup handles and `SQLITE_BUSY`.
- [SQLite result codes](https://www.sqlite.org/rescode.html) — typed failure classification.
- [Apple FileManager replacement](https://developer.apple.com/documentation/foundation/filemanager/replaceitem(at:withitemat:backupitemname:options:resultingitemurl:)) — item-level replacement limits.
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox) — container and entitlement limits.
- [Apple XCTest](https://developer.apple.com/documentation/xctest) — UI/user-observable automation boundaries.
- [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) — actor isolation/reentrancy.
- [Swift Task cancellation](https://developer.apple.com/documentation/swift/task/iscancelled) — cooperative cancellation.

These references establish platform/library limits. M53’s evidence tiers, source-revision envelope, status vocabulary, bounded claims, browser-first path, rollback rules, and gates are Hive-specific governance contracts. They require a separately approved M52 execution and fresh evidence before any status changes.
