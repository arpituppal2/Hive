# Hive M64 — Bounded Execution-Handoff & Admission Checklist

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M64 Bounded Execution-Handoff & Admission Checklist
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m63-decision-record-replay-anti-omission-plan.md`
> **Related plans:** M50–M63 storage-authority chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent exclusions:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and other unadmitted writers
> **Current disposition:** `BLOCKED`; M64 cannot issue implementation `GO`; no status promotion is permitted
>
> Current disposition: BLOCKED. M64 cannot issue implementation GO or status promotion.
>
> M64 performs no runtime evidence work and does not edit Swift. HOLD, SPLIT, and TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted. M64 cannot issue status promotion; no status promotion is permitted.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M64 defines the bounded handoff package and fail-closed admission checklist for a future separately approved execution decision. It does not admit execution, create an approval, edit Swift, open real stores, authorize a synthetic pilot, authorize M52, or promote any capability status.

## 0. Decision summary

**Decision: retain `BLOCKED` until a future handoff package is complete, source-bound, replay-consistent, independently reviewed, owner-acknowledged, rollback-defined, and free of unresolved hard gaps. M64 itself never authorizes execution.**

M64 separates:

- **Handoff** — transferring a bounded plan, evidence scope, owners, limitations, and next action to a future decision-maker.
- **Admission** — checking whether a package is eligible for a separately authorized execution decision.
- **Authorization** — an explicit future decision that may permit a named action; M64 cannot issue it.
- **Verification** — fresh source/build/test/runtime/recovery/browser evidence required by M53.

A complete handoff is not an approval. A signed or hashed package proves binding from capture onward, not runtime correctness, clean origin, complete observation, or absence of hidden writers. A passing checklist cannot waive a hard boundary.

## 1. Binding scope and authority

The production participant set remains exactly:

```text
{Honeycomb, EventLedger}
```

- Honeycomb remains authoritative for knowledge schema, migrations, nodes/edges, provenance, retrieval data, and logical deletion.
- EventLedger remains authoritative for append-only evidence events, event schema/migrations, consent/action history, and ledger deletion semantics.
- `HandoffRecoveryJournal` and `SessionFileStore` remain adjacent writers, excluded from production participation unless a new architecture decision explicitly admits them.
- WISP/M5 remain unregistered and blocked.
- A future coordinator may project one bounded activation metadata record only; it may not own product data, schema/migrations, deletion truth, events, a second ledger, or a database.

M64 forbids:

- execution authorization, runtime/store access, or status promotion; no status promotion is permitted;
- a coordinator database, second ledger, shadow store, product-data cache, or new semantic authority;
- raw SQLite handles, prepared statements, file descriptors, arbitrary SQL, raw databases, private content, credentials, cookies, private URLs, prompts, screenshots as sole proof, model/network payloads, or unbounded logs in the handoff;
- model, network, connector, OS, telemetry, permission, sync, credential, or training expansion.

## 2. Handoff package envelope

A future handoff package must bind:

```text
m64_handoff_id
m63_replay_reference
m62_decision_reference
m61_challenge_reference
m60_packet_reference
m59_review_reference
source_revision
working_tree_identity
working_tree_state
environment_identity
package_target_identity
claim_scope
participant_set
adjacent_writer_classifications
replay_status
manifest_identity
owner_dispositions
independent_review_result
open_gap_ids
reopened_gap_ids
explicitly_blocked_gap_ids
inventory_incomplete_findings
stale_evidence_findings
contradiction_findings
changed_path_classes
exact_future_allowlist
exact_excluded_paths
synthetic_split_allowlist
real_store_allowlist
browser_fallback_map
privacy_redaction_receipt
rollback_plan
implementation_owner
rollback_owner
independent_reviewer
M53_evidence_owner
next_smallest_action
current_disposition
handoff_limitations
```

The package must be local, bounded, redacted, deterministic to compare, and safe to quarantine. It may not contain raw databases, full SQL, private user content, secrets, credentials, cookies, screenshots as sole proof, arbitrary absolute paths, model/network payloads, or unbounded logs.

## 3. Admission checklist

A future admission review must check each item explicitly and record `pass`, `fail`, `blocked`, `hold`, `not_applicable_with_reason`, or `unknown`:

### 3.1 Identity and scope

- one source revision, worktree identity, target identity, environment envelope, and claim scope;
- exact `{Honeycomb, EventLedger}` participant set;
- explicit adjacent-writer exclusions;
- WISP/M5 absent and blocked;
- no coordinator database, second ledger, product-data authority, or scope expansion;
- exact future changed-path allowlist and exact excluded-path list;
- synthetic and real-store classes separated.

### 3.2 Evidence and replay

- M59/M60/M61/M62/M63 references resolve to one coherent chain;
- M63 replay is `match`, not `mismatch`, `incomplete`, or `unknown`;
- replay manifest and declared input counts match;
- no stale, mixed-revision, contradictory, or `inventory_incomplete` blocker remains;
- direct/indirect/dynamic writer and SQLite lifecycle risks are either evidenced or explicitly blocked;
- every positive claim has a limitation and evidence scope;
- no owner/reviewer signature is being used as runtime proof.

### 3.3 Owners and change control

- storage, Honeycomb, EventLedger, adjacent-writer/exclusion, implementation, rollback, independent-review, and M53 owners are named;
- each owner acknowledges only obligations within their authority;
- owner withdrawals/conflicts are represented;
- future commands, targets, platform, container, permissions, and rollback are named;
- any changed-path expansion returns the package to `BLOCKED` and requires a new decision;
- no handoff field is treated as authorization by implication.

### 3.4 Privacy, fallback, and recovery boundary

- navigation, tabs, private browsing, offline use, accessibility, and manual work remain usable if storage is unavailable;
- storage failure cannot widen model/network context or trigger model, network, connector, OS, telemetry, permission, or sync actions;
- corrupt storage cannot silently initialize an empty replacement and claim success;
- privacy/redaction is independently reviewed;
- rollback preserves prior decision records, gap history, dirty work, and limitations.

A missing checklist observation is not a pass. A tool failure is not a no-match result. `unknown` and `inventory_incomplete` are non-admitting outcomes.

## 4. Fail-closed admission precedence

M64 applies this precedence from strongest blocker to weakest positive signal:

```text
unauthorized scope/authority/path expansion
  > M63 replay mismatch/incomplete/unknown
    > contradiction or mixed source/environment identity
      > stale required evidence
        > missing owner or withdrawn/conflicting acknowledgement
          > inventory_incomplete/search failure
            > unresolved direct/indirect/dynamic writer or SQLite lifecycle risk
              > missing rollback/privacy/fallback field
                > bounded HOLD fact
                  > synthetic SPLIT opportunity
                    > structural readiness
```

The first applicable blocker controls the result.

- A complete package cannot override an unauthorized path.
- A signed package cannot override a replay mismatch.
- A passing static checklist cannot override missing runtime evidence.
- A synthetic result cannot satisfy a real-store admission row.
- A favorable owner acknowledgement cannot override an independent reviewer’s hard contradiction.
- `TARGET_READY_FOR_REVIEW` cannot become `GO` by accumulating signatures or checklist passes.

## 5. Dispositions

### `BLOCKED` — current default

Use `BLOCKED` when any hard scope, authority, replay, freshness, contradiction, owner, writer, lifecycle, privacy, fallback, rollback, or evidence condition is missing, unknown, or contradictory. M64 cannot issue implementation `GO`.

### `HOLD`

Use `HOLD` only when exactly one bounded fact remains, no contradiction is proven, the owner and collection method are named, and no admission claim is made. HOLD authorizes no code; no store access, pilot, or status promotion is permitted.

### `SPLIT`

Use `SPLIT` only for a separately approved synthetic handoff/checklist/codec/manifest/state-machine slice. Synthetic SPLIT cannot open real databases, inspect user data, establish runtime recovery, or promote M52/M53/status.

### `TARGET_READY_FOR_REVIEW`

Use this only when the package is structurally complete, replay-consistent, source/environment-bound, limitation-bound, independently reviewed, owner-acknowledged, and ready to be considered by a separate implementation decision. It is structural documentation readiness only; it is not implementation-approved and is not runtime-ready.

### `GO`

M64 cannot issue implementation `GO`. A future decision must separately authorize exact paths, commands, owners, environment, rollback, and M53 evidence collection. No M64 result changes capability status.

## 6. Admission result record

A future reviewer must emit one bounded result:

```text
admission_result = BLOCKED | HOLD | SPLIT | TARGET_READY_FOR_REVIEW
first_blocker
checklist_counts
failed_check_ids
unknown_check_ids
inventory_incomplete_check_ids
reopened_gap_ids
required_owner_actions
exact_allowlist
exact_exclusions
rollback_reference
M53_handoff_reference
next_smallest_action
limitations
independent_reviewer
```

The result must preserve every failed/unknown check and cannot collapse them into a generic “not ready.” A `TARGET_READY_FOR_REVIEW` result must list every condition that a future implementation decision still needs to revalidate.

## 7. Rollback and non-destructive handoff failure

If admission fails or the handoff becomes stale:

- retain the original package, manifests, replay result, and checklist;
- record the first blocker and all dependent failures;
- reopen affected M60/M61/M62/M63 gaps without deleting history;
- quarantine derived handoff artifacts;
- preserve the dirty worktree and prior limitations;
- return to `BLOCKED` or bounded `HOLD`;
- name one smallest corrective action.

No destructive git cleanup is permitted. Handoff artifacts cannot overwrite Honeycomb/EventLedger authority or create a fallback database.

## 8. M53 handoff

M64 may produce only a bounded request for future M53 review:

```text
m53_claim_scope
m53_evidence_owner
source_revision
working_tree_identity
environment_identity
exact_future_allowlist
required_runtime_tiers
replay_status
open_or_reopened_gap_ids
explicitly_blocked_gap_ids
browser_manual_path_scope
privacy_redaction_receipt
rollback_reference
independent_review_receipt
next_smallest_action
```

M53 remains the runtime evidence boundary. M64 handoff/admission evidence cannot substitute for M53 source/diff, build/focused tests, deterministic faults, restart/recovery, manual clean-profile browser, or independent review.

## 9. M64 gates

| Gate | Requirement |
|---|---|
| M64-A | M63 replay, M62 decision, M61 challenge, M60 packet, and M59 review are referenced. |
| M64-B | Production participants remain exactly `{Honeycomb, EventLedger}`. |
| M64-C | HandoffRecoveryJournal and SessionFileStore remain excluded unless separately admitted. |
| M64-D | WISP/M5 remain blocked and unregistered. |
| M64-E | No coordinator database, second ledger, product-data authority, or new semantic authority is proposed. |
| M64-F | Handoff envelope binds one source revision, worktree, environment, target, and claim scope. |
| M64-G | Exact future allowlist and excluded paths are enumerated. |
| M64-H | Synthetic and real-store path classes are separate. |
| M64-I | M63 replay is match and manifest/count/precedence results are consistent. |
| M64-J | Stale, contradictory, mixed, unknown, and `inventory_incomplete` inputs block admission. |
| M64-K | Direct/indirect/dynamic writer and SQLite lifecycle risks are explicit and non-passing when unresolved. |
| M64-L | Owner, reviewer, implementation, rollback, and M53 responsibilities are acknowledged within authority. |
| M64-M | Checklist records pass, fail, blocked, hold, not-applicable-with-reason, and unknown states. |
| M64-N | First-blocker precedence is explicit and fail-closed. |
| M64-O | `TARGET_READY_FOR_REVIEW` is structural documentation readiness only, not implementation-approved or runtime-ready. |
| M64-P | M64 cannot issue implementation GO or status promotion. |
| M64-Q | HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. |
| M64-R | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M64-S | Storage failure cannot widen model/network/OS context. |
| M64-T | Handoff artifacts are local, bounded, redacted, deterministic to compare, and quarantine-safe. |
| M64-U | Failed admission preserves package, replay, manifests, gap history, dirty work, and limitations. |
| M64-V | M53 handoff binds one future source revision, environment, exact allowlist, claim, and evidence scope. |
| M64-W | No handoff field or signature authorizes execution by implication. |
| M64-X | Independent review confirms no unresolved hard blocker before any future readiness label. |

## 10. Honest limits and primary references

M64 does not execute the handoff, authorize M52, run replay, complete M63, close real runtime gaps, implement lifecycle protocols, verify writer barriers, run SQLite recovery, prove migration/deletion continuity, validate browser startup, establish crash consistency, prove power-loss durability, prove secure/forensic deletion, prove cross-store atomicity, certify compliance, or establish production/ship readiness.

Primary references:

- [NIST SSDF](https://csrc.nist.gov/projects/ssdf)
- [SLSA Build Provenance](https://slsa.dev/spec/v1.2/build-provenance)
- [SQLite Quality Management Plan](https://sqlite.org/qmplan.html)
- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [Swift Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Apple Signing and Verifying](https://developer.apple.com/documentation/security/signing-and-verifying)
- [Apple Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)

These sources establish platform, library, provenance, change-control, and release-gate limits. M64’s handoff envelope, admission checklist, precedence, dispositions, gates, rollback, fallback, and no-status-promotion rules are Hive governance decisions.

**M64 is complete as a planning artifact when its handoff envelope, admission checklist, fail-closed precedence, disposition mapping, result record, M53 handoff, 24 gates (M64-A through M64-X), rollback rules, and independent review are structurally validated.**
