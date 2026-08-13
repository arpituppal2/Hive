# Hive M67 — Revocation Propagation Reconciliation & Recovery

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M67 Revocation Propagation Reconciliation & Recovery
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m66-revalidation-challenge-revocation-lineage-plan.md`
> **Related plans:** M50–M66 storage-authority chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent exclusions:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and other unadmitted writers
> **Current disposition:** `BLOCKED`; M67 cannot issue implementation `GO`; no status promotion is permitted
>
> Current disposition: BLOCKED. M67 cannot issue implementation GO; no store access is permitted; no status promotion is permitted.
>
> M67 performs no runtime evidence work and does not edit Swift. HOLD, SPLIT, and TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted. M67 cannot issue status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M67 defines how a future reviewer reconciles M66 revocation and invalidation propagation over a declared bounded dependency graph, distinguishes convergence from incomplete or divergent state, and recovers a reviewable record without treating restoration as runtime readiness. It does not execute reconciliation, access real stores, authorize M52, issue M53 evidence, or promote any capability status.

## 0. Decision summary

**Decision: retain `BLOCKED` until any future propagation reconciliation is bound to an explicit graph inventory boundary, idempotent method, complete result state, append-only lineage, and fail-closed handling of unknown edges. M67 itself never authorizes execution or status change.**

M67 separates:

- **Propagation** — marking declared dependent claims, handoffs, mirrors, and evidence projections after a premise is invalidated.
- **Reconciliation** — comparing declared lineage state, dependent state, and recorded propagation results within one bounded graph envelope.
- **Recovery** — returning records to a known reviewable state while preserving prior history and limitations.
- **Restoration** — reintroducing a prior artifact or state for review; restoration is not proof of correctness, runtime safety, or admission.
- **Convergence** — all declared nodes and edges agree within the declared graph boundary.
- **Completeness** — evidence that the declared graph boundary itself enumerated the required nodes and edges; reconciliation cannot prove unobserved dependencies.
- **Runtime verification** — fresh source/build/test/runtime/recovery/browser evidence required by M53.

A converged result proves only bounded agreement of declared records. It cannot prove that an undeclared dependency, implicit side effect, external writer, mirror, or runtime event did not exist.

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

M67 forbids:

- execution authorization, runtime/store access, or status promotion; no status promotion is permitted;
- a coordinator database, second ledger, dependency database, revocation authority, shadow store, or semantic authority; no semantic authority is permitted;
- using reconciliation as a new source of truth or using restoration to erase revocation lineage;
- raw SQLite handles, prepared statements, file descriptors, arbitrary SQL, raw databases, private content, credentials, cookies, private URLs, prompts, screenshots as sole proof, model/network payloads, or unbounded logs in reconciliation packets;
- model, network, connector, OS, telemetry, permission, sync, credential, or training expansion.

## 2. Reconciliation envelope

A future M67 reconciliation must bind:

```text
m67_reconciliation_id
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
graph_schema_version
graph_inventory_identity
graph_node_count
graph_edge_count
node_digests
edge_digests
root_subject_ids
revocation_event_ids
expected_dependent_ids
observed_dependent_ids
unknown_dependency_ids
mirror_identity_set
reconciliation_method
reconciliation_generation
idempotence_result
first_blocker
current_state
limitations
next_smallest_action
```

The packet must be local, bounded, redacted, deterministic to compare, and safe to quarantine. It may not contain raw databases, full SQL, private user content, secrets, credentials, cookies, screenshots as sole proof, arbitrary absolute paths, model/network payloads, or unbounded logs.

## 3. Declared graph boundary

A future reviewer must declare the exact graph boundary before reconciliation:

```text
node_kind = lineage_event | revalidation | handoff | admission | replay | claim | m53_request | mirror | limitation
edge_kind = supports | derived-from | requires | mirrors | supersedes | invalidates | propagated-to
```

The graph inventory must state:

- root subjects and why they are in scope;
- expected node and edge classes;
- inclusion and exclusion rules;
- source, environment, participant, path, and claim scope;
- search/tool limitations and unavailable sources;
- how implicit, dynamic, external, and adjacent dependencies are bounded;
- expected counts or an independent expected-set method;
- what a zero-dependent result means and cannot mean.

A graph filename, mirror list, digest, or clean search result cannot establish graph completeness. An unavailable search tool is `inventory_incomplete`, not an empty graph. An unlisted edge is not absent; it is `UNKNOWN_DEPENDENCY` until bounded.

## 4. Reconciliation states

A future reconciliation must emit exactly one primary state:

| State | Meaning | Admission consequence |
|---|---|---|
| `CONVERGED` | All declared nodes/edges and propagation results agree within the declared boundary; idempotence passes. | Documentation state only; no runtime or admission authorization. |
| `INCOMPLETE` | Required node, edge, mirror, count, source, method, or boundary proof is missing. | `BLOCKED`; reopen affected M66 claims. |
| `DIVERGENT` | Declared records disagree in identity, state, digest, generation, propagation, or mirror content. | `BLOCKED`; preserve all versions and require reconciliation. |
| `UNKNOWN` | The result cannot safely distinguish convergence from incompleteness or divergence. | `BLOCKED`; no favorable inference. |
| `REVOKED` | A root premise is explicitly invalidated and dependent state is not valid for current use. | `BLOCKED`; retain revocation lineage and propagate dependent invalidation. |

`CONVERGED` never means complete in the real world, verified, runtime-safe, restored, admitted, or approved. `REVOKED` is distinct from `DIVERGENT`; a revoked record may be internally consistent while still unusable.

`CURRENT` is not a seventh reconciliation state. It is a downstream documentation label that may remain only when the prerequisite M65/M66 record is current and M67 is `CONVERGED` within the same declared boundary. `CURRENT` does not mean `TARGET_READY_FOR_REVIEW`, implementation-approved, runtime-ready, or safe to access real stores. If the prerequisite is stale, revoked, divergent, incomplete, or unknown, the downstream label is invalidated.

## 5. Idempotent reconciliation procedure

A future reconciliation must be a new append-only record:

1. Identify the M66 root event and exact claim scope.
2. Freeze the declared source, worktree, target, environment, authority, path, and graph boundary.
3. Load only bounded lineage, dependency, mirror, and claim references allowed by the envelope.
4. Reconcile node identities, edge identities, generations, digests, state transitions, and propagation results.
5. Mark missing nodes/edges as `INCOMPLETE` or `UNKNOWN_DEPENDENCY`; never infer absence.
6. Mark conflicting identities, generations, or states as `DIVERGENT`.
7. Propagate root `REVOKED`, `EXPIRED`, `SUPERSEDED`, or `BLOCKED` state through declared `requires`, `derived-from`, `supports`, `mirrors`, and `propagated-to` edges.
8. Repeat the same bounded reconciliation without new inputs and compare the result; a changed result is `UNKNOWN` or `DIVERGENT`.
9. Preserve unaffected claims only when their independent evidence and dependency boundary are explicit.
10. Emit one state, first blocker, affected IDs, limitation, and next smallest action.
11. Obtain independent review of the reconciliation record.

Idempotence means repeated reconciliation of the same declared inputs produces the same bounded projection. It does not prove absence of concurrent external writers or hidden side effects outside the envelope.

## 6. Propagation and dependency reconciliation

When a root subject is `REVOKED`, `EXPIRED`, `SUPERSEDED`, `DIVERGENT`, `INCOMPLETE`, or `UNKNOWN`:

1. retain the root state and reason;
2. traverse every declared dependent edge within the graph boundary;
3. mark dependent claims and handoffs `STALE_DEPENDENCY`, `REVOKED_DEPENDENCY`, `SUPERSEDED_DEPENDENCY`, `DIVERGENT_DEPENDENCY`, `INCOMPLETE_DEPENDENCY`, or `UNKNOWN_DEPENDENCY`;
4. invalidate dependent `TARGET_READY_FOR_REVIEW` labels and M53 handoff requests;
5. preserve unaffected nodes only with explicit independent evidence and boundaries;
6. record missing or unlisted edges as unknown, not clean;
7. append the propagation result without deleting prior states.

A zero-dependent result is admissible only when the expected set and graph boundary are independently supported. Otherwise it is `INCOMPLETE` or `UNKNOWN`.

Mirror disagreement is `DIVERGENT`; a mirror cannot override canonical lineage. A restored artifact is a candidate for review, not a current authority.

## 7. Recovery, rollback, and restoration limits

### 7.1 Safe recovery

A future recovery record may:

- preserve the last known bounded reconciliation state;
- quarantine divergent, revoked, malformed, or incomplete derived artifacts;
- restore a reviewable prior record without deleting newer revocation events;
- re-run bounded reconciliation from an immutable declared input set;
- return to `BLOCKED` or `REOPENED_FOR_REVIEW`.

### 7.2 Prohibited inference

M67 cannot claim that:

- backup or snapshot restoration was transactionally consistent;
- restoration proves source/runtime correctness;
- a converged graph is complete outside its inventory boundary;
- an idempotent replay proves absence of concurrent writers or hidden side effects;
- a restored `CURRENT` projection is implementation-approved, runtime-ready, or safe to access real stores.

No destructive git cleanup is permitted. Dirty worktrees, prior lineage, revocation reasons, limitations, and gap history remain preserved.

## 8. Fail-closed precedence

M67 applies this precedence from strongest blocker to weakest positive signal:

```text
unauthorized scope/authority/path expansion
  > source/target/environment identity mismatch
    > root revocation or explicit invalidation
      > divergent identity/generation/digest/mirror state
        > unknown or unlisted dependency/edge
          > incomplete graph boundary/count/method
            > non-idempotent reconciliation result
              > stale/expired/inventory_incomplete input
                > unresolved writer, lifecycle, privacy, fallback, or rollback risk
                  > bounded HOLD fact
                    > synthetic SPLIT opportunity
                      > CONVERGED bounded state
```

The first applicable blocker controls the result.

- A converged mirror cannot override a canonical revocation.
- A backup cannot override a divergent generation.
- A clean-looking graph cannot override unknown edges.
- A `CURRENT` or `RESTORED_FOR_REVIEW` result cannot become `GO` through reconciliation.
- A synthetic state-machine result cannot satisfy a real-store or runtime claim.

## 9. Dispositions

### `BLOCKED` — current default

Use `BLOCKED` for any unauthorized scope, root revocation, divergence, unknown dependency, incomplete graph boundary, non-idempotent result, stale input, missing owner/reviewer, privacy failure, fallback failure, rollback failure, or unsupported claim. M67 cannot issue implementation `GO`.

### `HOLD`

Use `HOLD` only when exactly one bounded reconciliation fact remains, no contradiction or revocation is proven, the owner and collection method are named, and no admission claim is made. HOLD authorizes no code; no store access, pilot, or status promotion is permitted.

### `SPLIT`

Use `SPLIT` only for separately approved synthetic graph, codec, manifest, idempotence, or state-machine work. Synthetic SPLIT cannot access real stores, user data, runtime environments, or establish production recovery.

### `TARGET_READY_FOR_REVIEW`

Use this only when the bounded reconciliation packet is structurally complete, its graph boundary and limitations are explicit, idempotence is demonstrated within the envelope, independent review is complete, and no hard blocker remains. It is structural documentation readiness only; it is not implementation-approved and is not runtime-ready.

### `GO`

M67 cannot issue implementation `GO`. A future decision must separately authorize exact paths, commands, owners, environment, rollback, and M53 evidence collection. No M67 result changes capability status.

## 10. Result and lineage record

A future reviewer must emit one bounded record:

```text
m67_reconciliation_id
m66_root_reference
reconciliation_state = CONVERGED | INCOMPLETE | DIVERGENT | UNKNOWN | REVOKED
reconciliation_result = BLOCKED | HOLD | SPLIT | TARGET_READY_FOR_REVIEW
first_blocker
expected_node_count
observed_node_count
expected_edge_count
observed_edge_count
unknown_dependency_ids
blocked_edge_ids
divergent_node_ids
divergent_edge_ids
invalidated_claim_ids
invalidated_handoff_ids
m53_handoff_reference
idempotence_result
recovery_state
rollback_reference
exact_allowlist
exact_exclusions
next_smallest_action
limitations
independent_reviewer
```

The record must preserve all failed, unknown, divergent, revoked, and incomplete findings. It cannot collapse them into “reconciled” or delete prior states.

## 11. Browser, privacy, and fallback

- Navigation, tabs, private browsing, offline use, accessibility, and manual work remain usable when reconciliation or lineage records are unavailable.
- Storage/reconciliation failure cannot widen model/network context or trigger model, network, connector, OS, telemetry, permission, or sync actions.
- Corrupt, divergent, revoked, or incomplete records cannot silently initialize an empty replacement and claim current state.
- Reconciliation packets exclude private content, credentials, cookies, page text, raw databases, screenshots as sole proof, and unbounded logs.
- Failed reconciliation preserves prior records, append-only gap history, dirty worktree, limitations, and quarantine reasons.

## 12. M53 handoff

M67 may produce only a bounded future M53 request:

```text
m53_claim_scope
m53_evidence_owner
source_revision
working_tree_identity
environment_identity
reconciliation_state
reconciliation_result
idempotence_result
unknown_dependency_ids
blocked_edge_ids
invalidated_claim_ids
invalidated_handoff_ids
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

M53 remains the runtime evidence boundary. M67 reconciliation/recovery evidence cannot substitute for M53 source/diff, build/focused tests, deterministic faults, restart/recovery, manual clean-profile browser, or independent review.

## 13. M67 gates

| Gate | Requirement |
|---|---|
| M67-A | M66 lineage, M65 revalidation, M64 handoff, M63 replay, and current BLOCK are referenced. |
| M67-B | Production participants remain exactly `{Honeycomb, EventLedger}`. |
| M67-C | HandoffRecoveryJournal and SessionFileStore remain excluded unless separately admitted. |
| M67-D | WISP/M5 remain blocked and unregistered. |
| M67-E | No coordinator database, second ledger, dependency database, revocation authority, or semantic authority is proposed. |
| M67-F | Reconciliation envelope binds one source, worktree, target, environment, authority, claim, and path scope. |
| M67-G | Graph boundary declares node/edge kinds, roots, expected sets/counts, exclusions, and limitations. |
| M67-H | States `CONVERGED`, `INCOMPLETE`, `DIVERGENT`, `UNKNOWN`, and `REVOKED` are distinct. |
| M67-I | Reconciliation is idempotent over the same bounded input set. |
| M67-J | Unknown dependencies, unlisted edges, and missing graph bounds fail closed. |
| M67-K | Mirror divergence and generation/digest conflict force `DIVERGENT`/`BLOCKED`. |
| M67-L | Revocation/expiry/supersession propagation reaches all declared dependent claims and handoffs. |
| M67-M | Zero-dependent results require an independently supported expected set and boundary. |
| M67-N | Prior records, gap history, dirty work, limitations, and revocation lineage are never deleted. |
| M67-O | Restoration/recovery bounds do not imply transactional consistency or runtime readiness. |
| M67-P | First-blocker precedence is explicit and applied. |
| M67-Q | `CONVERGED` and downstream `CURRENT` remain bounded documentation states; `TARGET_READY_FOR_REVIEW` is structural documentation readiness only. |
| M67-R | M67 cannot issue implementation GO or status promotion. |
| M67-S | HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. |
| M67-T | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M67-U | Storage/reconciliation failure cannot widen model/network/OS context. |
| M67-V | Artifacts are local, bounded, redacted, deterministic, and quarantine-safe. |
| M67-W | M53 handoff binds one future source, environment, reconciliation state, and evidence scope. |
| M67-X | Independent review confirms no propagation, recovery, authority, or status-inflation blocker before any readiness label. |

## 14. Honest limits and primary references

M67 does not execute reconciliation, open real stores, implement a dependency graph, establish universal dependency discovery, prove complete mirror capture, guarantee eventual convergence, perform transactional restoration, run M66 propagation, close real runtime gaps, implement lifecycle protocols, verify writer barriers, run SQLite recovery, prove migration/deletion continuity, validate browser startup, establish crash consistency, prove power-loss durability, prove secure/forensic deletion, prove cross-store atomicity, certify compliance, or establish production/ship readiness.

Primary references:

- [NIST SSDF](https://csrc.nist.gov/projects/ssdf)
- [NIST SP 800-53 Rev. 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)
- [NIST SP 800-161 Rev. 1](https://csrc.nist.gov/pubs/sp/800/161/r1/final)
- [SLSA Build Provenance](https://slsa.dev/spec/v1.2/build-provenance)
- [SLSA Requirements](https://slsa.dev/spec/v1.2/requirements)
- [Apple Signing and Verifying](https://developer.apple.com/documentation/security/signing-and-verifying)
- [Apple Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [Swift Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

These sources establish provenance, graph, append-only, reconciliation, recovery, and runtime-proof limits. M67’s bounded graph envelope, reconciliation states, idempotence rules, propagation, recovery/rollback limits, dispositions, gates, fallback, and no-status-promotion rules are Hive governance decisions.

**M67 is complete as a planning artifact when its reconciliation envelope, explicit graph boundary, state mapping, idempotence procedure, propagation rules, recovery/rollback limits, disposition mapping, M53 handoff, 24 gates (M67-A through M67-X), and independent review are structurally validated.**
