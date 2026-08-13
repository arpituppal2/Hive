# Hive M69 — Evidence Receipt Challenge, Dispute Resolution & Re-review

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M69 Evidence Receipt Challenge, Dispute Resolution & Re-review
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m68-reconciliation-evidence-receipt-independent-replay-plan.md`
> **Related plans:** M50–M68 storage-authority and evidence chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent exclusions:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and other unadmitted writers
> **Current disposition:** `BLOCKED`; M69 cannot issue implementation `GO`; no status promotion is permitted
>
> M69 performs no runtime evidence work and does not edit Swift. HOLD, SPLIT, and TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted. M69 cannot issue status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M69 defines how a future reviewer challenges an M68 receipt or replay result, classifies bounded disagreement, preserves dispute lineage, reopens a claim without rewriting history, and emits a limited future M53 request. It does not execute a challenge, access real stores, adjudicate source truth, authorize M52, issue M53 evidence, or promote any capability status.

## 0. Decision summary

**Decision: retain `BLOCKED` until any future M68 receipt has a bounded challenge packet, an independent reviewer, explicit dispute classification, source-bound evidence, append-only lineage, and a fail-closed disposition. M69 itself never authorizes execution or status change.**

M69 distinguishes four dispute classes:

- **Receipt-structure challenge** — the envelope, schema, identity, count, digest, redaction, freshness, or declared boundary is malformed, missing, contradictory, or out of scope.
- **Replay-comparator disagreement** — an independent replay produces `REPLAY_MISMATCH`, `REPLAY_INCOMPLETE`, or `REPLAY_UNKNOWN`, or the expected and replayed projections differ.
- **Provenance/freshness dispute** — an M65/M66/M67 premise, source, environment, reviewer, lineage generation, revocation state, or validity window changed or cannot be re-established.
- **Source/claim dispute** — bounded evidence conflicts about the actual source, artifact, implementation claim, or safety-relevant interpretation. M69 records this dispute; it does not decide semantic truth.

A challenge can establish that a declared packet requires review, that two bounded projections disagree, or that a prerequisite is stale or invalid. It cannot prove that an unobserved dependency is absent, that a source is safe, that a signed record is truthful, or that runtime behavior is verified.

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

M69 forbids:

- execution authorization, runtime/store access, or status promotion; no status promotion is permitted;
- a coordinator database, second ledger, dependency database, revocation authority, dispute service, shadow store, or semantic authority; no semantic authority is permitted;
- model adjudication, majority voting, popularity, owner preference, or automated text generation as a substitute for bounded evidence;
- deleting, rewriting, or silently superseding an M68 receipt, replay result, prior dispute, revocation, or limitation;
- raw SQLite handles, prepared statements, arbitrary SQL, raw databases, private content, credentials, cookies, private URLs, prompts, screenshots as sole proof, model/network payloads, or unbounded logs in dispute packets;
- model, network, connector, OS, telemetry, permission, sync, credential, or training expansion.

## 2. Challenge eligibility and packet envelope

A future challenge may be raised only by a participant or reviewer who can provide a bounded, source-bound reason and an exact scope. The packet must state the challenger identity or `challenger_unavailable`, the challenged M68 subject, the requested scope, the evidence method, and the limitation.

A future M69 challenge packet must bind:

```text
m69_challenge_id
m68_receipt_reference
m68_replay_reference
m67_reconciliation_reference
m66_challenge_reference
m65_revalidation_reference
source_revision
working_tree_identity
working_tree_state
target_identity
environment_identity
participant_set
authority_boundary
claim_scope
changed_path_allowlist
excluded_paths
challenge_class
challenger_identity
challenger_basis
challenged_subject_ids
challenged_field_paths
challenge_method_version
inputs_reviewed
expected_projection
observed_projection
contradiction_ids
freshness_result
revocation_state
supersession_reference
reviewer_identity
reviewer_independence_basis
reviewer_conflicts
redaction_result
lineage_generation
prior_disposition
current_disposition
rollback_reference
next_smallest_action
limitations
```

The packet must be local, bounded, redacted, deterministic to compare, and safe to quarantine. It must not contain raw stores, full SQL, private user content, secrets, credentials, cookies, arbitrary absolute paths, model/network payloads, or unbounded logs.

A challenge is not accepted merely because it is plausible, urgent, model-generated, repeated, or signed. A challenge is rejected only for a documented scope/evidence defect; rejection does not prove the challenged M68 subject correct.

## 3. Challenge classes and required handling

| Challenge class | Minimum bounded question | Required handling | What it cannot establish |
|---|---|---|---|
| `RECEIPT_STRUCTURE` | Are the declared envelope, identities, counts, digests, schema, redaction, freshness, and graph boundary internally coherent? | Recheck fields; missing/contradictory fields fail closed. | Completeness or source/runtime correctness. |
| `REPLAY_COMPARATOR` | Does an independent bounded replay produce the declared M68 projection? | Compare method, inputs, boundary, generation, counts, edges, digests, state, and idempotence. | That the original runner or source was trustworthy. |
| `PROVENANCE_FRESHNESS` | Do M65/M66/M67 source, environment, reviewer, lineage, revocation, and validity premises still hold? | Invalidate, expire, supersede, or reopen affected claims as applicable. | That an unchallenged premise is globally true. |
| `SOURCE_CLAIM` | Do retained bounded sources conflict about the claimed artifact, implementation, or safety interpretation? | Preserve both positions; mark `DISPUTED`; require owner-scoped review or M53 evidence. | Semantic adjudication, majority truth, or runtime safety. |

A failed search/tool call, unavailable source, unreadable artifact, unknown dependency, or missing environment is a limitation and may produce `CHALLENGE_ACCEPTED` or `DISPUTED`; it is never a clean result.

## 4. Reviewer independence and no semantic adjudication

The reviewer must not be the sole author of the challenged M68 receipt, the owner of the challenged claim, or a person who can unilaterally waive the challenged boundary. The packet records independence basis, conflicts, recusal, delegation, and unavailable-reviewer limitations.

Independence is claim-scoped. A reviewer independent of authorship but controlling the same unchecked authority is not automatically independent for an authority or source claim. A `none` high-severity review result means only that the bounded packet has no unresolved critical review finding; it does not mean correct, complete, safe, verified, approved, or ready to ship.

Models, scripts, hashes, signatures, and councils may organize or compare bounded evidence, but they cannot adjudicate source truth or grant authority. There is no majority truth: multiple agreeing reviewers cannot override an explicit mismatch, unknown dependency, revoked premise, or missing boundary.

## 5. Challenge procedure

A future challenge proceeds as an append-only sequence:

1. Bind the M68 receipt/replay subject, source revision, target, environment, authority, path scope, and claim scope.
2. Classify the challenge before inspecting favorable outcomes.
3. Freeze the bounded evidence set and record unavailable inputs and search/tool limitations.
4. Recheck M68 receipt validity, replay state, graph boundary, omission limits, freshness, lineage, and redaction.
5. Compare the challenger’s observation with the declared M68 projection without silently repairing either side.
6. Identify the first applicable blocker using the precedence in §8.
7. Propagate invalidation or stale state through declared dependent edges only; unlisted edges remain `UNKNOWN_DEPENDENCY`.
8. Obtain independent review separate from the challenger and original M68 author where the claim requires it.
9. Emit one disposition, affected IDs, exact limitations, and next smallest action.
10. If new evidence arrives, append a re-review or supersession event; never rewrite the challenged record.

A challenge result must remain bounded to its declared subject and cannot silently broaden the claim scope.

## 6. Append-only dispute lineage

Each future dispute event references its predecessor and records its effect:

```text
m69_lineage_event_id
predecessor_id
subject_id
subject_kind = receipt | replay | reconciliation | revalidation | handoff | claim | m53_request | mirror
lineage_event_kind = challenged | accepted | rejected | disputed | reopened | resolved_for_review | superseded | revoked | expired | narrowed
challenge_class
source_revision
evidence_generation
reason_code
reason_scope
affected_claim_ids
affected_handoff_ids
challenger
reviewer
captured_at
limitations
next_smallest_action
```

Allowed transitions are bounded:

```text
M68_RESULT → CHALLENGE_ACCEPTED
M68_RESULT → CHALLENGE_REJECTED
M68_RESULT → DISPUTED
CHALLENGE_ACCEPTED → DISPUTED | REOPENED_FOR_REVIEW | RESOLVED_FOR_REVIEW
DISPUTED → REOPENED_FOR_REVIEW | SUPERSEDED | REVOKED | BLOCKED
REOPENED_FOR_REVIEW → RESOLVED_FOR_REVIEW | DISPUTED | REVOKED | BLOCKED
RESOLVED_FOR_REVIEW → SUPERSEDED | REOPENED_FOR_REVIEW
```

`CHALLENGE_REJECTED` means only that this packet failed the challenge-entry contract; it does not make the M68 result verified. `RESOLVED_FOR_REVIEW` means the bounded dispute has a recorded response and independent review; it does not establish runtime truth or implementation approval.

Prior M68, M67, M66, and M65 records remain immutable. A supersession adds a new record and explicit predecessor; it never erases an unfavorable result or narrows history without recording the reason and scope.

## 7. Dispositions and result states

M69 must emit one primary dispute state and one bounded readiness result:

| State | Meaning | Consequence |
|---|---|---|
| `CHALLENGE_ACCEPTED` | Entry contract is satisfied and the bounded subject requires review. | Affected subject remains `BLOCKED` pending disposition. |
| `CHALLENGE_REJECTED` | Packet is out of scope, unbounded, malformed, or lacks the required evidence basis. | The challenged subject is not thereby verified; the rejection and limitation remain recorded. |
| `DISPUTED` | Conflicting bounded evidence remains unresolved, or the challenge exposes an unclassified mismatch. | Fail closed; invalidate dependent readiness labels and M53 requests. |
| `REOPENED_FOR_REVIEW` | New bounded evidence permits a fresh review without reopening old history. | No runtime or admission authority; re-review is pending. |
| `RESOLVED_FOR_REVIEW` | The bounded dispute has a documented response, independent review, and no unresolved challenge within scope. | Structural review state only; M53 and runtime evidence remain required. |

`RUNTIME_VERIFIED` is unavailable in M69. `TARGET_READY_FOR_REVIEW` is documentation readiness only and may not be emitted while a hard dispute, unknown dependency, stale premise, or unresolved reviewer conflict remains. `GO` is unavailable.

## 8. Fail-closed precedence

M69 applies this precedence from strongest blocker to weakest positive signal:

```text
unauthorized scope/authority/path expansion
  > reviewer conflict or failed independence
    > upstream revocation, supersession, or identity mismatch
      > receipt-structure mismatch or invalid boundary
        > replay mismatch, incompleteness, or unknown result
          > source/claim contradiction or unknown dependency
            > stale/expired/inventory_incomplete evidence
              > unresolved privacy, fallback, rollback, or writer limitation
                > bounded challenge rejection with explicit limitation
                  > bounded RESOLVED_FOR_REVIEW state
```

The first applicable blocker controls the result.

- A challenge rejection cannot override an upstream revocation.
- A replay convergence cannot override a receipt mismatch or unknown dependency.
- A signed, hashed, or model-supported claim cannot override a source contradiction.
- Reviewer agreement cannot create semantic authority or runtime proof.
- A resolved documentation dispute cannot become `GO` through repeated review, signatures, votes, or checklist accumulation.

## 9. Result and lineage record

A future reviewer must emit one bounded record:

```text
m69_challenge_id
m68_subject_reference
challenge_class
challenge_state = CHALLENGE_ACCEPTED | CHALLENGE_REJECTED | DISPUTED | REOPENED_FOR_REVIEW | RESOLVED_FOR_REVIEW
readiness_result = BLOCKED | HOLD | SPLIT | TARGET_READY_FOR_REVIEW
verification_state = NOT_AVAILABLE_IN_M69
first_blocker
finding_ids
contradiction_ids
unknown_dependency_ids
invalidated_claim_ids
invalidated_handoff_ids
revocation_event_ids
supersession_event_ids
reopened_subject_ids
source_revision
environment_identity
lineage_reference
reviewer_identity
reviewer_independence_basis
M53_handoff_reference
exact_allowlist
exact_exclusions
rollback_reference
next_smallest_action
limitations
```

The record must preserve accepted, rejected, disputed, reopened, resolved, unknown, revoked, and superseded findings. It cannot collapse them into “review passed,” delete old receipts, or infer truth from silence.

## 10. Browser, privacy, fallback, and rollback

- Navigation, tabs, private browsing, offline use, accessibility, and manual work remain usable when a challenge or dispute packet is unavailable.
- Storage/dispute failure cannot widen model/network context or trigger model, network, connector, OS, telemetry, permission, or sync actions.
- Corrupt, disputed, revoked, stale, or incomplete artifacts cannot silently initialize an empty replacement and claim current state.
- Challenge artifacts exclude private content, credentials, cookies, page text, raw databases, screenshots as sole proof, and unbounded logs.
- Failed review preserves prior receipts, append-only lineage, gap history, dirty worktree, limitations, and quarantine reasons; derived artifacts may be quarantined but history is not destructively cleaned.
- No destructive git cleanup is permitted.

## 11. M53 handoff

M69 may produce only a bounded future M53 request:

```text
m53_claim_scope
m53_evidence_owner
source_revision
working_tree_identity
environment_identity
m68_subject_reference
challenge_class
challenge_state
readiness_result
verification_state = NOT_AVAILABLE_IN_M69
first_blocker
invalidated_claim_ids
invalidated_handoff_ids
unknown_dependency_ids
required_runtime_tiers
exact_future_allowlist
open_or_reopened_gap_ids
explicitly_blocked_gap_ids
browser_manual_path_scope
privacy_redaction_receipt
rollback_reference
independent_review_receipt
next_smallest_action
limitations
```

M53 remains the runtime evidence boundary. M69 dispute/re-review evidence cannot substitute for M53 source/diff, build/focused tests, deterministic faults, restart/recovery, manual clean-profile browser, or independent review.

## 12. M69 gates

| Gate | Requirement |
|---|---|
| M69-A | M68 receipt/replay, M67 reconciliation, M66 lineage/challenge, M65 freshness, M64 handoff, and M63 replay are referenced. |
| M69-B | Production participants remain exactly `{Honeycomb, EventLedger}`. |
| M69-C | HandoffRecoveryJournal and SessionFileStore remain excluded unless separately admitted. |
| M69-D | WISP/M5 remain blocked and unregistered. |
| M69-E | No coordinator database, second ledger, dependency database, dispute service, revocation authority, or semantic authority is proposed. |
| M69-F | Receipt-structure, replay-comparator, provenance/freshness, and source/claim disputes are distinct. |
| M69-G | Challenge eligibility, exact scope, challenger basis, and bounded evidence requirements are explicit. |
| M69-H | Reviewer independence, conflicts, recusal, and unavailable-reviewer limits are explicit. |
| M69-I | Models, scripts, signatures, and councils cannot adjudicate semantic truth or grant authority. |
| M69-J | No majority/consensus result overrides an explicit mismatch, unknown dependency, revocation, or missing boundary. |
| M69-K | Challenge artifacts are local, bounded, redacted, deterministic, and quarantine-safe. |
| M69-L | Prior M68/M67/M66/M65 records and dispute history are append-only and never rewritten or deleted. |
| M69-M | Allowed challenge/dispute/reopen/supersession transitions are explicit. |
| M69-N | `CHALLENGE_ACCEPTED`, `CHALLENGE_REJECTED`, `DISPUTED`, `REOPENED_FOR_REVIEW`, and `RESOLVED_FOR_REVIEW` are distinct. |
| M69-O | Unresolved conflict, unknown dependency, stale premise, or reviewer failure remains `BLOCKED`. |
| M69-P | First-blocker precedence is explicit and applied. |
| M69-Q | `RUNTIME_VERIFIED` is unavailable in M69; `TARGET_READY_FOR_REVIEW` is structural only; M69 cannot issue GO or status promotion. |
| M69-R | HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. |
| M69-S | Reopening/resolution does not erase history, restore runtime authority, or prove source/claim correctness. |
| M69-T | M53 handoff binds one future source, environment, challenge state, and evidence scope. |
| M69-U | Browser, private, offline, accessibility, and manual fallback remain explicit. |
| M69-V | Storage/dispute failure cannot widen model, network, telemetry, connector, permission, or OS context. |
| M69-W | Rollback preserves receipts, lineage, limitations, gap history, dirty worktree, and quarantine reasons without destructive cleanup. |
| M69-X | Independent review confirms no dispute, omission, authority, provenance, or status-inflation blocker before any structural readiness label. |

## 13. Honest limits and primary references

M69 does not adjudicate semantic source truth, execute replay, access real stores, implement a dispute service, establish universal dependency discovery, prove complete capture, guarantee reviewer honesty, prove cryptographic key custody, establish trusted time, close runtime gaps, run M68 replay, implement lifecycle protocols, verify writer barriers, run SQLite recovery, prove migration/deletion continuity, validate browser startup, establish crash consistency, prove power-loss durability, prove secure/forensic deletion, prove cross-store atomicity, certify compliance, or establish production/ship readiness.

Primary references:

- [SLSA Verification Summary Attestation](https://slsa.dev/verification_summary)
- [SLSA Build Provenance](https://slsa.dev/spec/v1.2/build-provenance)
- [SLSA Requirements](https://slsa.dev/spec/v1.2/requirements)
- [in-toto](https://in-toto.io/)
- [Sigstore Logging Overview](https://docs.sigstore.dev/logging/overview/)
- [NIST SSDF](https://csrc.nist.gov/projects/ssdf)
- [NIST SP 800-161 Rev. 1](https://csrc.nist.gov/pubs/sp/800/161/r1/final)
- [Apple Signing and Verifying](https://developer.apple.com/documentation/security/signing-and-verifying)
- [Apple Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

These sources establish provenance, transparency, review, integrity, and runtime-proof limits. M69’s challenge classes, reviewer rules, append-only dispute lineage, dispositions, fail-closed precedence, gates, fallback, rollback, and no-status-promotion rules are Hive governance decisions.

**M69 is complete as a planning artifact when its challenge envelope, dispute classes, independent-review rules, append-only lineage, disposition mapping, M53 handoff, 24 gates (M69-A through M69-X), rollback rules, fallback, and independent review are structurally validated.**
