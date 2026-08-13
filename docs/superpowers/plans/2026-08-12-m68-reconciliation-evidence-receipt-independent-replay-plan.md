# Hive M68 — Reconciliation Evidence Receipt & Independent Replay

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M68 Reconciliation Evidence Receipt & Independent Replay
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m67-revocation-propagation-reconciliation-recovery-plan.md`
> **Related plans:** M50–M67 storage-authority chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent exclusions:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and other unadmitted writers
> **Current disposition:** `BLOCKED`; M68 cannot issue implementation `GO`; no status promotion is permitted
>
> Current disposition: BLOCKED. M68 cannot issue implementation GO; no store access is permitted; no status promotion is permitted.
>
> M68 performs no runtime evidence work and does not edit Swift. HOLD, SPLIT, and TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted. M68 cannot issue status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M68 defines a bounded evidence receipt for M67 reconciliation and the method by which an independent reviewer can replay that receipt. It distinguishes structural receipt validity from replay convergence and runtime verification. It does not execute replay, access real stores, authorize M52, issue M53 evidence, or promote any capability status.

## 0. Decision summary

**Decision: retain `BLOCKED` until a future M67 result is represented by a complete, fresh, source-bound receipt and an independent bounded replay that agrees with the declared reconciliation projection. M68 itself never authorizes execution or status change.**

M68 distinguishes:

- **`RECEIPT_VALID`** — the declared receipt is structurally intact, bounded, lineage-bound, redacted, and internally consistent.
- **`REPLAY_CONVERGED`** — an independent replay of the same declared receipt inputs produces the same bounded graph/reconciliation projection.
- **`RUNTIME_VERIFIED`** — excluded from M68; requires fresh M53 source/build/test/runtime/recovery/browser evidence.
- **Completeness** — whether the declared receipt boundary actually enumerates all required inputs; M68 cannot prove unobserved dependencies.
- **Freshness** — whether upstream M65/M66/M67 premises remain within their claim-bound validity envelope.
- **Independent replay** — a separate bounded reconstruction or comparator, not a second source of truth.

`REPLAY_CONVERGED` proves only bounded agreement under the declared receipt, method, graph boundary, and environment. It does not prove source correctness, graph completeness outside the boundary, runtime safety, transactional recovery, absence of concurrent writers, or production readiness.

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

M68 forbids:

- execution authorization, runtime/store access, or status promotion; no status promotion is permitted;
- a coordinator database, second ledger, dependency database, revocation authority, shadow store, replay authority, or semantic authority; no semantic authority is permitted;
- treating an independent replay as a second canonical store or allowing replay to rewrite the M67 record;
- raw SQLite handles, prepared statements, file descriptors, arbitrary SQL, raw databases, private content, credentials, cookies, private URLs, prompts, screenshots as sole proof, model/network payloads, or unbounded logs in receipts;
- model, network, connector, OS, telemetry, permission, sync, credential, or training expansion.

## 2. Receipt envelope

A future M68 receipt must bind:

```text
m68_receipt_id
m67_reconciliation_reference
m66_challenge_reference
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
lineage_generation
reconciliation_generation
graph_schema_version
graph_inventory_identity
graph_node_count
graph_edge_count
node_digests
edge_digests
root_subject_ids
expected_dependent_ids
observed_dependent_ids
unknown_dependency_ids
blocked_edge_ids
mirror_identity_set
receipt_schema_version
receipt_method_version
receipt_freshness_policy
valid_from
valid_until
upstream_revocation_state
upstream_supersession_reference
receipt_state
replay_state
redaction_result
independent_reviewer
next_smallest_action
limitations
```

The receipt must be local, bounded, redacted, deterministic to compare, and safe to quarantine. It may not contain raw databases, full SQL, private user content, secrets, credentials, cookies, screenshots as sole proof, arbitrary absolute paths, model/network payloads, or unbounded logs.

A receipt is a projection over existing authorities, not a new authority. It may reference bounded identifiers and digests; it must not silently expand the graph or claim that a missing identifier was absent in the real world.

## 3. Receipt validity and freshness

A receipt may be `RECEIPT_VALID` only when:

- all required envelope fields are present;
- M65 freshness policy, valid window, and upstream revocation/supersession state are current within scope;
- M66 lineage predecessor and reviewer independence references resolve;
- M67 reconciliation source, graph generation, graph boundary, node/edge counts, and state resolve;
- changed-path, participant, authority, target, environment, and claim identities match;
- receipt digests and schema/method versions match the declared artifacts;
- privacy/redaction, limitation, and fallback fields are complete;
- no `UNKNOWN`, `DIVERGENT`, `INCOMPLETE`, `REVOKED`, `EXPIRED`, `inventory_incomplete`, or contradictory prerequisite remains unaccounted for.

Receipt validity is not replay convergence. A structurally valid receipt can still produce `REPLAY_MISMATCH`, `REPLAY_INCOMPLETE`, `REPLAY_UNKNOWN`, or `BLOCKED` when replayed.

A receipt becomes stale or invalid when any upstream M65/M66/M67 premise changes, expires, is revoked, is superseded, contradicts the receipt, or cannot be re-established. Timestamp renewal cannot repair a changed source, graph, authority, claim, or environment.

## 4. Independent replay contract

A future replay must be independently authored or independently reviewed and must use only the receipt’s declared bounded inputs:

```text
replay(receipt, method_version, declared_inputs, graph_boundary)
  -> reconciliation_projection
compare(replayed_projection, expected_projection)
  -> REPLAY_CONVERGED | REPLAY_MISMATCH | REPLAY_INCOMPLETE | REPLAY_UNKNOWN
```

The replay must report:

```text
receipt_state
replay_state
source_identity_match
environment_identity_match
lineage_generation_match
graph_boundary_match
node_count_match
edge_count_match
digest_match
state_match
propagation_match
idempotence_match
omitted_or_unexpected_inputs
unknown_dependencies
blocked_edges
mirror_divergences
first_blocker
limitations
next_smallest_action
```

- `REPLAY_CONVERGED` means the same declared inputs and method produce the same bounded projection.
- `REPLAY_MISMATCH` means state, identity, digest, count, edge, propagation, or precedence differs; dependent claims are `BLOCKED` or `DIVERGENT`.
- `REPLAY_INCOMPLETE` means a required receipt field, input, method, graph boundary, or freshness premise is unavailable; no completeness claim is allowed.
- `REPLAY_UNKNOWN` means the result cannot safely be classified; disposition remains `BLOCKED`.

The replay cannot choose the favorable projection, silently repair mismatches, access canonical stores, or update the receipt. A replay is evidence about the receipt, not a new receipt authority.

## 5. Graph, omission, and convergence limits

M68 must preserve M67’s explicit graph boundary:

```text
node_kind = lineage_event | revalidation | handoff | admission | replay | claim | m53_request | mirror | limitation
edge_kind = supports | derived-from | requires | mirrors | supersedes | invalidates | propagated-to
```

The receipt must state roots, expected node/edge categories, counts, inclusion/exclusion rules, search/tool limitations, and the trusted capture boundary.

| Receipt/replay result | May establish | Cannot establish |
|---|---|---|
| `RECEIPT_VALID` | Declared receipt structure, lineage, redaction, and bounded identities are coherent | Runtime safety, semantic correctness, complete capture |
| `REPLAY_CONVERGED` | Same declared inputs produce same bounded reconciliation projection | Unrecorded dependencies, hidden writers, graph completeness, source correctness |
| Digest/signature match | Declared bytes/records were unchanged after capture | Clean origin, absence of omitted inputs, runtime truth |
| Count/edge agreement | Declared expected and observed sets agree | That the expected set was complete in the real world |
| Idempotent replay | Same bounded replay repeats consistently | Concurrent external writes, kernel/filesystem behavior, production recovery |

Search/tool failure is `inventory_incomplete`, not a clean empty result. An unlisted dependency is `UNKNOWN_DEPENDENCY`; a zero-dependent result is valid only when the expected set and boundary are independently supported.

## 6. Fail-closed replay precedence

M68 applies this precedence from strongest blocker to weakest positive signal:

```text
unauthorized scope/authority/path expansion
  > upstream M65/M66/M67 revocation, supersession, or identity mismatch
    > receipt schema/method/lineage mismatch
      > replay mismatch or mirror divergence
        > unknown dependency/unlisted edge/inventory_incomplete input
          > incomplete graph boundary/count/digest/propagation evidence
            > non-idempotent replay
              > stale/expired/contradictory receipt
                > bounded HOLD fact
                  > synthetic SPLIT opportunity
                    > REPLAY_CONVERGED bounded state
```

The first applicable blocker controls the result.

- A valid receipt cannot override an upstream revocation.
- A converged replay cannot override a receipt mismatch or unknown dependency.
- A signed receipt cannot establish runtime proof.
- `REPLAY_CONVERGED` cannot become `GO` by repeated replay, signatures, or checklist accumulation.
- `RUNTIME_VERIFIED` is unavailable to M68 and can only come from M53’s fresh evidence boundary.

## 7. Dispositions

### `BLOCKED` — current default

Use `BLOCKED` for any upstream invalidation, receipt mismatch, replay mismatch/incompleteness/unknown, unknown dependency, graph-boundary gap, stale evidence, missing reviewer independence, privacy failure, fallback failure, rollback failure, or unsupported claim. M68 cannot issue implementation `GO`.

### `HOLD`

Use `HOLD` only when exactly one bounded receipt/replay fact remains, no contradiction or revocation is proven, the owner and collection method are named, and no admission claim is made. HOLD authorizes no code; no store access, pilot, or status promotion is permitted.

### `SPLIT`

Use `SPLIT` only for separately approved synthetic receipt, comparator, codec, graph, or idempotence work. Synthetic SPLIT cannot access real stores, user data, runtime environments, or establish production verification.

### `TARGET_READY_FOR_REVIEW`

Use this only when the receipt is structurally valid, independent replay is `REPLAY_CONVERGED`, limitations and graph boundary are explicit, upstream lineage is current, independent review is complete, and no hard blocker remains. It is structural documentation readiness only; it is not implementation-approved and is not runtime-ready.

### `GO`

M68 cannot issue implementation `GO`. A future decision must separately authorize exact paths, commands, owners, environment, rollback, and M53 evidence collection. No M68 result changes capability status.

## 8. Result and lineage record

A future reviewer must emit one bounded record:

```text
m68_receipt_id
receipt_state = RECEIPT_VALID | RECEIPT_INVALID | RECEIPT_EXPIRED | RECEIPT_REVOKED | RECEIPT_SUPERSEDED | RECEIPT_UNKNOWN
replay_state = REPLAY_CONVERGED | REPLAY_MISMATCH | REPLAY_INCOMPLETE | REPLAY_UNKNOWN
verification_state = NOT_AVAILABLE_IN_M68
readiness_result = BLOCKED | HOLD | SPLIT | TARGET_READY_FOR_REVIEW
first_blocker
unknown_dependency_ids
blocked_edge_ids
mirror_divergence_ids
invalidated_claim_ids
invalidated_handoff_ids
source_revision
environment_identity
receipt_freshness
lineage_reference
M53_handoff_reference
exact_allowlist
exact_exclusions
next_smallest_action
limitations
independent_reviewer
```

`verification_state = NOT_AVAILABLE_IN_M68` is mandatory. `RUNTIME_VERIFIED` cannot be emitted by this milestone.

The prior M67 reconciliation and M65/M66 records remain immutable. M68 may invalidate or narrow a dependent claim, but cannot rewrite unfavorable prior states or turn a replay into a runtime result.

## 9. Browser, privacy, fallback, and rollback

- Navigation, tabs, private browsing, offline use, accessibility, and manual work remain usable when receipts or replay artifacts are unavailable.
- Storage/replay failure cannot widen model/network context or trigger model, network, connector, OS, telemetry, permission, or sync actions.
- Corrupt, stale, revoked, mismatched, or incomplete receipts cannot silently initialize an empty replacement and claim current state.
- Receipts/replay artifacts exclude private content, credentials, cookies, page text, raw databases, screenshots as sole proof, and unbounded logs.
- Failed replay preserves prior receipts, lineage, gap history, dirty worktree, limitations, and quarantine reasons; derived replay artifacts are discarded or quarantined without destructive history loss.
- No destructive git cleanup is permitted.

## 10. M53 handoff

M68 may produce only a bounded future M53 request:

```text
m53_claim_scope
m53_evidence_owner
source_revision
working_tree_identity
environment_identity
receipt_state
replay_state
verification_state = NOT_AVAILABLE_IN_M68
required_runtime_tiers
exact_future_allowlist
unknown_dependency_ids
blocked_edge_ids
invalidated_claim_ids
invalidated_handoff_ids
open_or_reopened_gap_ids
explicitly_blocked_gap_ids
browser_manual_path_scope
privacy_redaction_receipt
rollback_reference
independent_review_receipt
next_smallest_action
```

M53 remains the runtime evidence boundary. M68 receipt/replay evidence cannot substitute for M53 source/diff, build/focused tests, deterministic faults, restart/recovery, manual clean-profile browser, or independent review.

## 11. M68 gates

| Gate | Requirement |
|---|---|
| M68-A | M67 reconciliation, M66 lineage/challenge, M65 revalidation, M64 handoff, and M63 replay are referenced. |
| M68-B | Production participants remain exactly `{Honeycomb, EventLedger}`. |
| M68-C | HandoffRecoveryJournal and SessionFileStore remain excluded unless separately admitted. |
| M68-D | WISP/M5 remain blocked and unregistered. |
| M68-E | No coordinator database, second ledger, dependency database, revocation authority, replay authority, or semantic authority is proposed. |
| M68-F | Receipt envelope binds one source, worktree, target, environment, authority, claim, lineage, graph, and path scope. |
| M68-G | Receipt fields, schema/method versions, redaction, freshness, and limitations are complete. |
| M68-H | Receipt validity, replay convergence, and runtime verification are distinct states. |
| M68-I | Independent replay is bounded, deterministic to compare, and cannot rewrite the receipt or canonical record. |
| M68-J | Graph roots, node/edge kinds, counts, expected sets, exclusions, and capture limitations match M67. |
| M68-K | Omission limits state that receipt/replay cannot prove unrecorded dependency absence or real-world graph completeness. |
| M68-L | Replay states `REPLAY_CONVERGED`, `REPLAY_MISMATCH`, `REPLAY_INCOMPLETE`, and `REPLAY_UNKNOWN` are distinct. |
| M68-M | Upstream revocation, supersession, identity, schema, or freshness changes invalidate the receipt. |
| M68-N | Unknown dependencies, unlisted edges, mirror divergence, and `inventory_incomplete` inputs fail closed. |
| M68-O | First-blocker precedence is explicit and applied. |
| M68-P | `RUNTIME_VERIFIED` is unavailable in M68 and requires M53. |
| M68-Q | `TARGET_READY_FOR_REVIEW` remains structural documentation readiness only. |
| M68-R | M68 cannot issue implementation GO or status promotion. |
| M68-S | HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. |
| M68-T | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M68-U | Storage/replay failure cannot widen model/network/OS context. |
| M68-V | Receipt/replay artifacts are local, bounded, redacted, deterministic, and quarantine-safe. |
| M68-W | Prior M65/M66/M67 records and gap/lineage history are never rewritten or deleted. |
| M68-X | Independent review confirms no receipt, replay, omission, authority, or status-inflation blocker before any readiness label. |

## 12. Honest limits and primary references

M68 does not execute replay, create receipt infrastructure, access real stores, build a second authority, prove graph completeness, prove source correctness, guarantee deterministic behavior across environments, establish trusted time, implement revocation, close real runtime gaps, run M67 reconciliation, implement lifecycle protocols, verify writer barriers, run SQLite recovery, prove migration/deletion continuity, validate browser startup, establish crash consistency, prove power-loss durability, prove secure/forensic deletion, prove cross-store atomicity, certify compliance, or establish production/ship readiness.

Primary references:

- [NIST SSDF](https://csrc.nist.gov/projects/ssdf)
- [NIST SP 800-53 Rev. 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)
- [SLSA Build Provenance](https://slsa.dev/spec/v1.2/build-provenance)
- [SLSA Requirements](https://slsa.dev/spec/v1.2/requirements)
- [in-toto](https://in-toto.io/)
- [Apple Signing and Verifying](https://developer.apple.com/documentation/security/signing-and-verifying)
- [Apple Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [Swift Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

These sources establish provenance, replay, reproducibility, audit, integrity, and runtime-proof limits. M68’s receipt envelope, replay comparator, graph/omission boundaries, freshness/lineage rules, dispositions, gates, rollback, fallback, and no-status-promotion rules are Hive governance decisions.

**M68 is complete as a planning artifact when its receipt envelope, validity/replay states, independent replay method, graph/omission limits, fail-closed precedence, disposition mapping, M53 handoff, 24 gates (M68-A through M68-X), rollback rules, and independent review are structurally validated.**
