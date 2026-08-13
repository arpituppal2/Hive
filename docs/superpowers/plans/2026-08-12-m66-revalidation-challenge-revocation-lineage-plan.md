# Hive M66 — Revalidation Challenge, Revocation Lineage & Independent Review

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M66 Revalidation Challenge, Revocation Lineage & Independent Review
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m65-admission-freshness-expiry-revalidation-plan.md`
> **Related plans:** M50–M65 storage-authority chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent exclusions:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and other unadmitted writers
> **Current disposition:** `BLOCKED`; M66 cannot issue implementation `GO`; no status promotion is permitted
>
> Current disposition: BLOCKED. M66 cannot issue implementation GO; no store access is permitted; no status promotion is permitted.
>
> M66 performs no runtime evidence work and does not edit Swift. HOLD, SPLIT, and TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted. M66 cannot issue status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M66 defines how a future reviewer independently challenges an M65 revalidation, records revocation and supersession without rewriting history, and propagates invalidation to dependent claims and handoffs. It does not execute a challenge, access real stores, authorize M52, issue M53 evidence, or promote any capability status.

## 0. Decision summary

**Decision: retain `BLOCKED` until any future M65 revalidation has an independent challenge packet, explicit reviewer separation, append-only revocation lineage, dependency-bounded invalidation, and a fail-closed result. M66 itself never authorizes execution or status change.**

M66 separates:

- **Challenge** — a bounded attempt to find omissions, contradictions, stale premises, unauthorized scope, reviewer conflicts, and claim inflation.
- **Revocation** — explicit invalidation of a prior decision before its nominal expiry because a binding premise no longer holds.
- **Supersession** — replacement by a newer source-bound record while preserving the predecessor.
- **Lineage** — immutable references connecting prior decisions, challenges, revocations, supersessions, dependent claims, and corrective actions.
- **Propagation** — marking every dependent claim within the declared dependency graph as stale, revoked, superseded, or blocked when its premise is invalidated.
- **Independent review** — review by a party that did not author the challenged revalidation or own the claim being challenged.
- **Runtime verification** — fresh source/build/test/runtime/recovery/browser evidence required by M53.

A signature, digest, reviewer approval, clean static replay, or valid timestamp may bind a declared record; none proves that the challenged premise was complete, that hidden dependencies were absent, or that runtime behavior is safe.

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

M66 forbids:

- execution authorization, runtime/store access, or status promotion; no status promotion is permitted;
- a coordinator database, second ledger, shadow store, dependency database, revocation authority; no semantic authority is permitted;
- mutating or deleting prior M65/M64/M63 records to conceal an unfavorable result;
- treating a reviewer signature, owner acknowledgement, digest, timestamp, or mirror copy as runtime proof;
- raw SQLite handles, prepared statements, file descriptors, arbitrary SQL, raw databases, private content, credentials, cookies, private URLs, prompts, screenshots as sole proof, model/network payloads, or unbounded logs in challenge packets;
- model, network, connector, OS, telemetry, permission, sync, credential, or training expansion.

## 2. Challenge packet envelope

A future M66 challenge must bind:

```text
m66_challenge_id
m65_revalidation_reference
m64_handoff_reference
m63_replay_reference
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
revalidation_policy_identity
challenged_premise_ids
challenge_scope
challenge_methods
challenge_queries
challenge_exclusions
inputs_reviewed
owner_identity
revalidation_author
independent_reviewer
reviewer_independence_basis
reviewer_conflicts
freshness_result
contradiction_ids
revocation_candidates
supersession_candidates
dependent_claim_ids
redaction_result
rollback_reference
next_smallest_action
current_disposition
limitations
```

The packet must be local, bounded, redacted, deterministic to compare, and safe to quarantine. It may not contain raw databases, full SQL, private user content, secrets, credentials, cookies, screenshots as sole proof, arbitrary absolute paths, model/network payloads, or unbounded logs.

## 3. Independence and challenge scope

### 3.1 Separation requirements

The independent reviewer must not be:

- the sole author of the M65 revalidation;
- the owner of the challenged implementation or runtime claim;
- the person who can unilaterally waive the challenged boundary;
- a substituted identity whose independence cannot be explained within the packet.

The packet must state the reviewer’s independence basis and any conflict, recusal, delegation, or unavailable-reviewer limitation. A reviewer who is independent of authorship but controls the same unchecked authority is not automatically independent for that claim.

A `none` high-severity review result means only that the bounded packet has no unresolved critical review findings. It does not mean runtime-safe, complete, approved, or verified.

### 3.2 Required challenge passes

The reviewer must perform bounded passes over:

1. **Lineage** — prior M65 record, M64 package, M63 replay, source/environment identity, and predecessor references.
2. **Freshness** — validity class, expiry, clock assumption, changed premises, and evidence-generation identity.
3. **Scope** — participant set, authority, changed-path allowlist, exclusions, target, and claim scope.
4. **Completeness** — declared inputs, dependency references, mirror copies, owner rows, reviewer rows, and search/tool limitations.
5. **Contradiction** — conflicting source, environment, owner, reviewer, replay, policy, or runtime-adjacent findings.
6. **Revocation** — whether an invalid premise requires `REVOKED`, `EXPIRED`, `SUPERSEDED`, or `BLOCKED`.
7. **Propagation** — whether every dependent handoff, readiness label, claim, and M53 request is identified and invalidated.
8. **Privacy/fallback** — redaction, private/offline/accessibility/manual browser continuity, and no context widening after failure.
9. **Rollback** — preservation of prior records, gap history, dirty work, limitations, and quarantine behavior.

A failed search tool, unavailable source, missing environment, unreadable artifact, or unknown dependency is an evidence limitation, not a clean result.

## 4. Revocation and supersession lineage

A future lineage must be append-only. Each event references its predecessor and records its effect:

```text
lineage_event_id
predecessor_id
subject_id
subject_kind = revalidation | handoff | admission | replay | claim | m53_request | mirror
lineage_event_kind = challenged | revoked | expired | superseded | reopened | narrowed | restored_for_review
source_revision
evidence_generation
reason_code
reason_scope
affected_claim_ids
affected_dependent_ids
issuer
independent_reviewer
captured_at
limitations
next_smallest_action
```

Allowed transitions are bounded:

```text
CURRENT → EXPIRING → EXPIRED
CURRENT → REVOKED
CURRENT → SUPERSEDED
CURRENT → BLOCKED
EXPIRED | REVOKED | SUPERSEDED → REOPENED_FOR_REVIEW
REOPENED_FOR_REVIEW → CURRENT only through a new M65 revalidation and independent M66 challenge
```

A prior record is never edited into a different state. A mirror or derived packet cannot erase, replace, or silently downgrade a revocation. `RESTORED_FOR_REVIEW` means only that a new review may begin; it does not restore admission or runtime authority.

Revocation reason codes must be explicit, such as:

```text
SOURCE_CHANGED
ENVIRONMENT_CHANGED
AUTHORITY_CHANGED
PATH_SCOPE_EXPANDED
CLAIM_SCOPE_CHANGED
EVIDENCE_CONTRADICTED
EVIDENCE_EXPIRED
OWNER_WITHDRAWN
REVIEW_CONFLICT
REPLAY_GENERATION_CHANGED
INVENTORY_INCOMPLETE
PRIVACY_FAILURE
ROLLBACK_REQUIRED
SUPERSEDED_BY_NEW_RECORD
UNKNOWN_DEPENDENCY
```

## 5. Dependency-bounded invalidation propagation

A future challenge must declare a dependency graph over recorded references, not infer dependencies from filenames or favorable text. At minimum it must distinguish:

```text
supports
derived-from
requires
mirrors
supersedes
invalidates
```

When a subject is revoked, expired, superseded, or blocked:

1. mark the subject with the exact reason and scope;
2. traverse every declared `requires`, `derived-from`, `supports`, and `mirrors` dependent within the challenge envelope;
3. mark dependent claims `STALE_DEPENDENCY`, `REVOKED_DEPENDENCY`, `SUPERSEDED_DEPENDENCY`, or `BLOCKED_DEPENDENCY` as appropriate;
4. invalidate dependent `TARGET_READY_FOR_REVIEW` labels and M53 handoff requests;
5. preserve unaffected claims only when their independent evidence and dependency scope are explicit;
6. record any unlisted or unknown dependency as `UNKNOWN_DEPENDENCY` and fail closed;
7. append the propagation result and first blocker without deleting prior states.

Propagation must not claim universal impact beyond the declared graph. A graph with missing edges is incomplete; a zero-dependent result is valid only with a bounded inventory method and limitation.

A mirror copy is not an independent authority. Mirror disagreement is a contradiction or `MIRROR_DIVERGENCE` finding, not an invitation to choose the most favorable copy.

## 6. Challenge findings and fail-closed precedence

M66 applies this precedence from strongest blocker to weakest positive signal:

```text
unauthorized scope/authority/path expansion
  > reviewer conflict or failed independence
    > source/target/environment identity mismatch
      > explicit contradiction or revocation trigger
        > unknown/unlisted dependency or mirror divergence
          > M65 replay/rule/schema generation mismatch
            > expired/stale/inventory_incomplete evidence
              > unresolved writer, lifecycle, privacy, fallback, or rollback risk
                > bounded HOLD fact
                  > synthetic SPLIT opportunity
                    > structural challenge completeness
```

The first applicable blocker controls the result.

- A newer mirror cannot override a conflicting canonical record without an append-only supersession event.
- A signature cannot override failed independence or an explicit revocation trigger.
- A complete-looking graph cannot prove dependencies that were never enumerated.
- A successful propagation calculation cannot prove runtime safety.
- `TARGET_READY_FOR_REVIEW` cannot survive an invalidated prerequisite and cannot become `GO` through review accumulation.

Required finding mapping:

| Finding | Required action |
|---|---|
| Proven authority/participant expansion | `BLOCKED`; stop; require a new architecture decision |
| Reviewer conflict or failed independence | `BLOCKED`; replace reviewer and reopen challenge |
| Changed source/environment/target/path/claim | `BLOCKED`; require new M64 admission decision |
| Contradiction or revocation trigger | Append revocation; invalidate dependent claims |
| Unknown or unlisted dependency | `BLOCKED`; record `UNKNOWN_DEPENDENCY` |
| Mirror divergence | `BLOCKED`; preserve both records and reconcile source identity |
| Expired/stale/incomplete evidence | `EXPIRED`/`BLOCKED`; reopen affected claims |
| Pure synthetic graph/codec/manifest opportunity | possible `SPLIT`, separately approved only |
| One bounded fact missing without contradiction | `HOLD`; no code or store access |
| Complete challenge with no hard finding | `TARGET_READY_FOR_REVIEW`, never `GO` |

## 7. Result and propagation record

A future reviewer must emit one bounded result:

```text
challenge_result = BLOCKED | HOLD | SPLIT | TARGET_READY_FOR_REVIEW
lineage_state = CURRENT | EXPIRING | EXPIRED | REVOKED | SUPERSEDED | REOPENED_FOR_REVIEW | UNKNOWN
first_blocker
finding_ids
revocation_event_ids
supersession_event_ids
reopened_claim_ids
invalidated_claim_ids
stale_dependency_ids
unknown_dependency_ids
mirror_divergence_ids
checked_premise_ids
unchanged_premise_ids
owner_actions
exact_allowlist
exact_exclusions
rollback_reference
M53_handoff_reference
next_smallest_action
limitations
independent_reviewer
```

The result must preserve all failed, unknown, conflicted, revoked, and reopened findings. It cannot collapse them into “review passed” or delete prior positive/negative states.

## 8. Browser, privacy, fallback, and rollback

- Navigation, tabs, private browsing, offline use, accessibility, and manual work remain usable when challenge or lineage records are unavailable.
- Storage/challenge failure cannot widen model/network context or trigger model, network, connector, OS, telemetry, permission, or sync actions.
- Corrupt, revoked, divergent, or incomplete records cannot silently initialize an empty replacement and claim current state.
- Challenge and lineage packets exclude private content, credentials, cookies, page text, raw databases, screenshots as sole proof, and unbounded logs.
- Failed challenge or propagation preserves prior records, append-only gap history, dirty worktree, limitations, and revocation reasons; derived artifacts are quarantined.
- No destructive git cleanup is permitted.

## 9. M53 handoff

M66 may produce only a bounded future M53 request:

```text
m53_claim_scope
m53_evidence_owner
source_revision
working_tree_identity
environment_identity
lineage_state
challenge_result
revocation_event_ids
invalidated_claim_ids
stale_dependency_ids
required_runtime_tiers
exact_future_allowlist
open_or_reopened_gap_ids
explicitly_blocked_gap_ids
browser_manual_path_scope
privacy_redaction_receipt
rollback_reference
independent_review_receipt
next_smallest_action
```

M53 remains the runtime evidence boundary. M66 challenge, lineage, and propagation evidence cannot substitute for M53 source/diff, build/focused tests, deterministic faults, restart/recovery, manual clean-profile browser, or independent review.

## 10. M66 gates

| Gate | Requirement |
|---|---|
| M66-A | M65 revalidation, M64 handoff, M63 replay, M62 decision, and M61 challenge are referenced. |
| M66-B | Production participants remain exactly `{Honeycomb, EventLedger}`. |
| M66-C | HandoffRecoveryJournal and SessionFileStore remain excluded unless separately admitted. |
| M66-D | WISP/M5 remain blocked and unregistered. |
| M66-E | No coordinator database, second ledger, dependency database, revocation authority, or new semantic authority is proposed. |
| M66-F | Challenge envelope binds source, worktree, target, environment, authority, claim, and allowlist scope. |
| M66-G | Reviewer independence basis, conflicts, recusal, and unavailable-reviewer limits are explicit. |
| M66-H | Challenge passes cover lineage, freshness, scope, completeness, contradiction, revocation, propagation, privacy/fallback, and rollback. |
| M66-I | Failed search/tool/source/environment checks remain limitations, not clean results. |
| M66-J | Revocation and supersession lineage is append-only with predecessor references and reason scope. |
| M66-K | Allowed lineage transitions are explicit; prior records cannot be rewritten. |
| M66-L | Dependency graph distinguishes supports, derived-from, requires, mirrors, supersedes, and invalidates. |
| M66-M | Invalidation propagates to all declared dependent claims and M53 handoffs. |
| M66-N | Unknown/unlisted dependencies and mirror divergence fail closed. |
| M66-O | First-blocker precedence is explicit and applied. |
| M66-P | `TARGET_READY_FOR_REVIEW` remains structural challenge readiness only, not implementation-approved or runtime-ready. |
| M66-Q | M66 cannot issue implementation GO or status promotion. |
| M66-R | HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. |
| M66-S | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M66-T | Storage/challenge failure cannot widen model/network/OS context. |
| M66-U | Revoked/expired/superseded records preserve lineage, limitations, gap history, and quarantine behavior. |
| M66-V | M53 handoff binds one future source revision, environment, challenge result, lineage state, and evidence scope. |
| M66-W | Exact allowlist, exclusions, invalidated claims, unknown dependencies, and next smallest action are present. |
| M66-X | Independent review confirms no review-independence, lineage, propagation, or status-inflation blocker before any readiness label. |

## 11. Honest limits and primary references

M66 does not execute a challenge, implement revocation, open real stores, build a dependency database, establish universal dependency discovery, prove complete mirror capture, run M65 revalidation, close real runtime gaps, implement lifecycle protocols, verify writer barriers, run SQLite recovery, prove migration/deletion continuity, validate browser startup, establish crash consistency, prove power-loss durability, prove secure/forensic deletion, prove cross-store atomicity, certify compliance, or establish production/ship readiness.

Primary references:

- [NIST SSDF](https://csrc.nist.gov/projects/ssdf)
- [NIST SP 800-53 Rev. 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)
- [SLSA Build Provenance](https://slsa.dev/spec/v1.2/build-provenance)
- [SLSA Requirements](https://slsa.dev/spec/v1.2/requirements)
- [Apple Signing and Verifying](https://developer.apple.com/documentation/security/signing-and-verifying)
- [Apple Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [Swift Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

These sources establish provenance, separation, review, invalidation, and runtime-proof limits. M66’s challenge envelope, reviewer independence, append-only lineage, dependency propagation, dispositions, gates, rollback, fallback, and no-status-promotion rules are Hive governance decisions.

**M66 is complete as a planning artifact when its challenge envelope, independent-review rules, append-only revocation/supersession lineage, dependency-bounded invalidation propagation, disposition mapping, M53 handoff, 24 gates (M66-A through M66-X), rollback rules, and independent review are structurally validated.**
