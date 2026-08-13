# Hive M65 — Admission Decision Freshness, Expiry & Revalidation

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M65 Admission Decision Freshness, Expiry & Revalidation
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m64-bounded-execution-handoff-admission-plan.md`
> **Related plans:** M50–M64 storage-authority chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent exclusions:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and other unadmitted writers
> **Current disposition:** `BLOCKED`; M65 cannot issue implementation `GO`; no status promotion is permitted
>
> Current disposition: BLOCKED. M65 cannot issue implementation GO; no store access is permitted; no status promotion is permitted.
>
> M65 performs no runtime evidence work and does not edit Swift. HOLD, SPLIT, and TARGET_READY_FOR_REVIEW authorize no code; no store access is permitted. M65 cannot issue status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M65 defines when a future M64 handoff/admission record is fresh enough to be reconsidered, when it must expire or be revoked, and how a reviewer revalidates it without treating time, signatures, hashes, or prior approval as runtime proof. It does not execute revalidation, access real stores, authorize M52, issue M53 evidence, or promote any capability status.

## 0. Decision summary

**Decision: retain `BLOCKED` until any future admission decision has an explicit freshness envelope, claim-bound validity rule, invalidation triggers, revocation state, revalidation owner, and fail-closed result. M65 itself never authorizes execution or status change.**

Freshness is not a timestamp alone. A decision is current only within the intersection of:

1. the exact source revision and working-tree identity;
2. the exact target, environment, toolchain, and SQLite/runtime envelope claimed;
3. the exact participant set, authority boundary, changed-path allowlist, and claim scope;
4. the exact evidence/replay/rule-set generation;
5. the declared freshness policy and validity window; and
6. the absence of revocation, contradiction, withdrawal, scope expansion, or superseding evidence.

A decision that is inside its time window but bound to a changed source, changed environment, changed authority, withdrawn owner, new contradiction, or different claim is stale or invalid. A decision with no explicit validity policy is not permanently valid; it is `BLOCKED` until its freshness rule is supplied.

M65 distinguishes:

- **Freshness** — whether required evidence remains within its declared, claim-specific validity envelope.
- **Expiry** — a planned end of validity after which the decision cannot be used without revalidation.
- **Revocation** — an explicit invalidation before expiry because a binding premise no longer holds.
- **Supersession** — replacement by a newer source-bound decision without deleting the prior record.
- **Revalidation** — a bounded check that the original decision’s premises and limitations still hold.
- **Runtime verification** — fresh source/build/test/runtime/recovery/browser evidence required by M53.

M65 does not invent universal TTLs. The owner must justify each freshness class and its validity window; where the owner cannot justify it, the result remains `BLOCKED`.

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

M65 forbids:

- execution authorization, runtime/store access, or status promotion; no status promotion is permitted;
- a coordinator database, second ledger, shadow store, product-data cache, revocation authority, or new semantic authority;
- treating a clock, signature, digest, owner acknowledgement, static review, or previous `TARGET_READY_FOR_REVIEW` as runtime proof;
- raw SQLite handles, prepared statements, file descriptors, arbitrary SQL, raw databases, private content, credentials, cookies, private URLs, prompts, screenshots as sole proof, model/network payloads, or unbounded logs in freshness packets;
- model, network, connector, OS, telemetry, permission, sync, credential, or training expansion.

## 2. Freshness envelope

A future M65 record must bind:

```text
m65_revalidation_id
m64_handoff_reference
m64_admission_result_reference
m63_replay_reference
source_revision
working_tree_identity
working_tree_state
target_identity
environment_identity
os_version
swift_toolchain
sqlite_runtime_version
participant_set
authority_boundary
claim_scope
changed_path_allowlist
excluded_paths
rule_set_identity
schema_version
evidence_generation
captured_at
freshness_policy_id
freshness_class
valid_from
valid_until
last_revalidated_at
revalidation_owner
independent_reviewer
revocation_state
supersession_reference
stale_inputs
contradiction_ids
withdrawn_owner_ids
next_smallest_action
current_disposition
limitations
```

The packet must be local, bounded, redacted, deterministic to compare, and safe to quarantine. It may not contain raw databases, full SQL, private user content, secrets, credentials, cookies, screenshots as sole proof, arbitrary absolute paths, model/network payloads, or unbounded logs.

`valid_until` is not sufficient by itself. The reviewer must compare every identity and premise in the envelope and record the freshness method and limitation.

## 3. Freshness classes and validity policy

A future owner must choose a named freshness class for each claim:

| Class | Intended use | Required validity rule |
|---|---|---|
| `revision_bound` | Source, diff, path, authority, or static-plan claims | Invalid as soon as source revision, dirty-tree identity, allowlist, or authority premise changes. |
| `environment_bound` | Build, test, toolchain, OS, SQLite, or platform claims | Invalid when any claimed environment identity changes or cannot be re-established. |
| `evidence_window` | Runtime-adjacent observations or manual paths | Requires owner-justified `valid_until`, exact scope, and revalidation before use after expiry. |
| `policy_bound` | Rules, schemas, privacy, or admission policy claims | Invalid when the governing rule/schema/policy generation changes or is revoked. |
| `owner_bound` | Responsibility and acknowledgement claims | Invalid on withdrawal, role change, conflict, unavailable owner, or scope change. |
| `superseded` | Older decisions replaced by a newer record | Never active for new admission; retained for lineage and audit. |

No class may silently fall back to an indefinite window. If a claim spans multiple classes, the earliest invalid or expired component controls the result.

A freshness policy must state:

```text
policy_id
claim_categories
freshness_class
validity_window_or_event_rule
clock_assumption
source/environment bindings
revalidation method
owner
independent reviewer
expiry action
revocation triggers
limitations
```

Time-based validity must use an explicit clock assumption and must not imply trusted time, secure timestamping, or runtime behavior that was not observed. Event-based invalidation is mandatory for identity, scope, authority, contradiction, and owner-withdrawal changes even when `valid_until` has not passed.

## 4. Invalidation and revocation triggers

A future reviewer must mark the prior decision `REVOKED`, `EXPIRED`, `SUPERSEDED`, or `BLOCKED` when any applicable trigger occurs:

### 4.1 Identity and scope triggers

- source revision, working-tree state, target, package, environment, toolchain, OS, or SQLite runtime differs;
- changed-path allowlist expands, an excluded path changes, or a participant/authority boundary changes;
- claim scope, browser path scope, evidence tier, limitation, or required runtime tier changes;
- WISP/M5 or any adjacent writer is introduced without a new architecture decision;
- a coordinator database, second ledger, product-data authority, or forbidden capability appears.

### 4.2 Evidence and policy triggers

- `valid_until` passes or the clock/clock source cannot be trusted within the declared policy;
- a required evidence item is missing, stale, contradictory, mixed-revision, `unknown`, or `inventory_incomplete`;
- M63 replay changes from `match`, or its rule set/schema/comparator generation changes;
- M53 evidence requirements, policy, schema, privacy boundary, or status vocabulary changes;
- a new finding contradicts a premise or exposes a previously unobserved writer/lifecycle path;
- a required search/inventory tool is unavailable and completeness depends on it.

### 4.3 Responsibility and integrity triggers

- an owner withdraws, changes role, becomes unavailable, or disputes the bounded acknowledgement;
- independent review scope changes, a critical review finding reopens, or the reviewer’s independence is compromised;
- a digest/signature/manifest no longer matches, or provenance is incomplete;
- a derived artifact is modified outside the recorded chain;
- the decision is superseded by a newer source-bound result.

A trigger invalidates only claims within its declared dependency scope, but the dependent admission result must return to `BLOCKED` until a new bounded decision is recorded. No trigger may be silently downgraded to a warning because the package is near expiry.

## 5. Revalidation procedure

A future revalidation must be a new append-only record, not an edit to the prior decision:

1. Identify the prior M64 package and exact claim scope.
2. Re-establish source, worktree, target, environment, participant, authority, and allowlist identities.
3. Recompute freshness classes and validity windows using the declared policy.
4. Check revocation, supersession, owner withdrawal, contradiction, stale evidence, and inventory/search status.
5. Reconcile M63 replay/rule/schema generation and M53 required evidence tiers.
6. Re-run only the bounded checks required by changed or expiring premises; do not imply untouched runtime proof.
7. Record all unchanged assumptions and their limitations explicitly.
8. Obtain an independent review of the revalidation record, not merely the prior decision.
9. Emit one fail-closed disposition and one next smallest action.

Revalidation must never “refresh the timestamp” while leaving a changed premise unexamined. A new source revision, changed environment, changed authority, changed claim, or changed path requires a new handoff/admission decision, not a lightweight revalidation.

Required revalidation result:

```text
revalidation_result = CURRENT | EXPIRING | EXPIRED | REVOKED | SUPERSEDED | BLOCKED | UNKNOWN
prior_claim_scope
checked_premises
unchanged_premises
changed_premises
expired_inputs
revoked_inputs
superseding_record
freshness_policy_result
m63_replay_result
m53_evidence_gap_result
owner_result
independent_review_result
first_blocker
current_disposition
next_smallest_action
limitations
```

`CURRENT` means only that the declared documentation premises remain current within scope. It does not mean verified, runtime-safe, production-ready, or approved for execution.

## 6. Fail-closed precedence

M65 applies this precedence from strongest blocker to weakest positive signal:

```text
unauthorized scope/authority/path expansion
  > source/target/environment identity mismatch
    > explicit revocation or supersession
      > M63 replay/rule/schema mismatch
        > contradiction, withdrawn owner, or compromised review independence
          > expired required evidence or missing validity policy
            > stale/mixed/unknown/inventory_incomplete input
              > unresolved writer, lifecycle, privacy, fallback, or rollback risk
                > bounded HOLD fact
                  > synthetic SPLIT opportunity
                    > CURRENT documentation state
```

The first applicable blocker controls the result.

- A valid timestamp cannot override a changed source or authority boundary.
- A signature cannot override revocation, contradiction, or owner withdrawal.
- A digest cannot prove runtime correctness or complete capture.
- A revalidation cannot repair a changed path; it must require a new admission decision.
- `CURRENT` cannot become `GO` by age, signatures, repeated replay, or accumulated checklist passes.

## 7. Dispositions

### `BLOCKED` — current default

Use `BLOCKED` when a required identity, policy, freshness observation, revocation state, owner, reviewer, evidence item, limitation, fallback, rollback, or runtime boundary is missing, changed, expired, contradictory, or unknown. M65 cannot issue implementation `GO`.

### `HOLD`

Use `HOLD` only when exactly one bounded freshness fact remains, no contradiction or revocation is proven, the owner and collection method are named, and no admission claim is made. HOLD authorizes no code; no store access, pilot, or status promotion is permitted.

### `SPLIT`

Use `SPLIT` only for separately approved synthetic freshness-policy, manifest, comparator, or state-machine work. Synthetic SPLIT cannot access real stores, user data, runtime environments, or establish evidence freshness for production claims.

### `TARGET_READY_FOR_REVIEW`

Use this only when the revalidation packet is structurally complete, all premises are source/environment-bound, required windows and event invalidators are explicit, independent review is complete, and no hard blocker remains. It is structural documentation readiness only; it is not implementation-approved and is not runtime-ready.

### `GO`

M65 cannot issue implementation `GO`. A future decision must separately authorize exact paths, commands, owners, environment, rollback, and M53 evidence collection. No M65 result changes capability status.

## 8. Result and lineage record

A future reviewer must emit one bounded record:

```text
m65_revalidation_id
prior_m64_reference
revalidation_result
admission_result = BLOCKED | HOLD | SPLIT | TARGET_READY_FOR_REVIEW
first_blocker
checklist_counts
failed_check_ids
unknown_check_ids
expired_input_ids
revoked_input_ids
superseded_by
changed_premise_ids
unchanged_premise_ids
required_owner_actions
exact_allowlist
exact_exclusions
rollback_reference
M53_handoff_reference
next_smallest_action
limitations
independent_reviewer
```

The prior decision remains immutable in the planning lineage. A revalidation can narrow, revoke, supersede, or block a claim; it cannot delete an unfavorable prior result or rewrite a stale record into a current one.

## 9. Browser, privacy, fallback, and rollback

- Navigation, tabs, private browsing, offline use, accessibility, and manual work remain usable when freshness or admission records are unavailable.
- Storage/revalidation failure cannot widen model/network context or trigger model, network, connector, OS, telemetry, permission, or sync actions.
- Corrupt, expired, revoked, or incomplete records cannot silently initialize an empty replacement and claim current state.
- Freshness packets exclude private content, credentials, cookies, page text, raw databases, screenshots as sole proof, and unbounded logs.
- Failed revalidation preserves the prior record, append-only gap history, dirty worktree, limitations, and revocation reason; derived artifacts are quarantined.
- A revoked or expired handoff cannot remain usable merely because browser functionality is available.
- No destructive git cleanup is permitted.

## 10. M53 handoff

M65 may produce only a bounded future M53 request:

```text
m53_claim_scope
m53_evidence_owner
source_revision
working_tree_identity
environment_identity
freshness_policy_id
freshness_class
valid_from
valid_until
revalidation_result
revoked_or_expired_input_ids
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

M53 remains the runtime evidence boundary. M65 freshness/revalidation evidence cannot substitute for M53 source/diff, build/focused tests, deterministic faults, restart/recovery, manual clean-profile browser, or independent review.

## 11. M65 gates

| Gate | Requirement |
|---|---|
| M65-A | M64 handoff/admission, M63 replay, M62 decision, M61 challenge, M60 packet, and M59 review are referenced. |
| M65-B | Production participants remain exactly `{Honeycomb, EventLedger}`. |
| M65-C | HandoffRecoveryJournal and SessionFileStore remain excluded unless separately admitted. |
| M65-D | WISP/M5 remain blocked and unregistered. |
| M65-E | No coordinator database, second ledger, revocation authority, product-data authority, or new semantic authority is proposed. |
| M65-F | Freshness envelope binds one source, worktree, target, environment, authority, claim, and allowlist scope. |
| M65-G | Freshness class, validity rule, clock assumption, owner, reviewer, and limitations are explicit. |
| M65-H | No claim receives an indefinite validity window by omission. |
| M65-I | Identity, scope, authority, evidence, policy, owner, reviewer, contradiction, and supersession invalidators are enumerated. |
| M65-J | Expiry, revocation, supersession, and BLOCKED states remain distinct. |
| M65-K | Changed source, environment, target, path, participant, authority, claim, or policy requires new admission rather than timestamp refresh. |
| M65-L | M63 replay/rule/schema generation and M53 evidence requirements are checked during revalidation. |
| M65-M | Revalidation is append-only, source-bound, independently reviewed, and limitation-bound. |
| M65-N | Fail-closed precedence is explicit and first applicable blocker controls. |
| M65-O | Signatures, hashes, clocks, and prior approvals cannot establish runtime proof or override revocation. |
| M65-P | `CURRENT` and `TARGET_READY_FOR_REVIEW` are documentation states only, not implementation-approved or runtime-ready. |
| M65-Q | M65 cannot issue implementation GO or status promotion. |
| M65-R | HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. |
| M65-S | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M65-T | Storage/revalidation failure cannot widen model/network/OS context. |
| M65-U | Expired/revoked/superseded records preserve lineage, limitations, gap history, and quarantine behavior. |
| M65-V | M53 handoff binds one future source revision, environment, freshness policy, claim, and evidence scope. |
| M65-W | Exact allowlist, exclusions, changed premises, and next smallest action are present. |
| M65-X | Independent review confirms no freshness, authority, or status-inflation blocker before any readiness label. |

## 12. Honest limits and primary references

M65 does not execute revalidation, open real stores, implement expiry/revocation, establish trusted time, prove secure timestamps, run M63 replay, close real runtime gaps, implement lifecycle protocols, verify writer barriers, run SQLite recovery, prove migration/deletion continuity, validate browser startup, establish crash consistency, prove power-loss durability, prove secure/forensic deletion, prove cross-store atomicity, certify compliance, or establish production/ship readiness.

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

These sources establish provenance, change-control, security, platform, and runtime-proof limits. M65’s freshness classes, validity envelope, invalidation triggers, revalidation procedure, precedence, dispositions, gates, rollback, fallback, and no-status-promotion rules are Hive governance decisions.

**M65 is complete as a planning artifact when its freshness envelope, validity classes, invalidation/revocation triggers, append-only revalidation procedure, disposition mapping, M53 handoff, 24 gates (M65-A through M65-X), rollback rules, and independent review are structurally validated.**
