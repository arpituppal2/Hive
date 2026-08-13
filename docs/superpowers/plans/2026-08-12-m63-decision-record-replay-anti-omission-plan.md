# Hive M63 — Decision-Record Replay & Anti-Omission

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; implementation remains BLOCKED
> **Roadmap label:** M63 Decision-Record Replay & Anti-Omission
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m62-bounded-readiness-decision-record-plan.md`
> **Related plans:** M50–M62 storage-authority chain
> **Production participants:** `{Honeycomb, EventLedger}` only
> **Adjacent exclusions:** `HandoffRecoveryJournal`, `SessionFileStore`, browser/session persistence, and other unadmitted writers
> **Current disposition:** `BLOCKED`; M63 cannot issue implementation `GO` or status promotion
>
> Current disposition: BLOCKED. M63 cannot issue implementation GO or status promotion.
>
> M63 performs no runtime evidence work and does not edit Swift. HOLD, SPLIT, and TARGET_READY_FOR_REVIEW authorize no code or store access. M63 cannot issue status promotion.
> **Non-dependencies:** WISP, M5 lifecycle, M45 capture, M2 import/Brief, models/training, sync, connectors, OS automation, cloud backup, release, compliance, and distribution work
>
> M63 defines how a future reviewer replays the M62 decision record, verifies declared aggregation and precedence, detects tampering or omission within the recorded packet, and reports the limits of that replay. It does not run the replay, complete M62, open real stores, authorize a synthetic pilot, authorize M52, or promote any capability status.

## 0. Decision summary

**Decision: retain `BLOCKED` until any future replay is bound to one immutable decision record, complete declared input manifest, deterministic comparator, and explicit omission limitations.**

Replay is a bounded assurance tool, not runtime proof. It can show that a recorded aggregation produces the same decision when given the same recorded inputs and rules. It cannot prove that unrecorded inputs did not exist, that the capture boundary observed every writer, that a runtime environment was safe, or that an omitted event was never generated.

M63 distinguishes:

- **Replayability** — the recorded decision can be recomputed from declared inputs.
- **Integrity** — recorded artifacts have not changed after their declared capture point.
- **Completeness** — the capture policy and boundary provide evidence that required inputs were enumerated.
- **Omission resistance** — independent manifests, expected row counts, source/path inventories, and challenge queries make missing records detectable within the stated boundary.
- **Runtime verification** — fresh source/build/test/runtime/recovery/browser evidence required by M53.

A digest, signature, Merkle/hash chain, manifest, green replay, or matching decision proves only the bounded property it actually covers. No replay result establishes universal runtime correctness, power-loss durability, secure deletion, cross-store atomicity, or production readiness.

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

M63 forbids:

- implementation or runtime authorization;
- raw SQLite handles, prepared statements, file descriptors, arbitrary SQL, raw databases, private content, credentials, cookies, private URLs, prompts, screenshots as sole proof, model/network payloads, or unbounded logs in replay artifacts;
- model, network, connector, OS, telemetry, permission, sync, credential, or training expansion;
- status promotion from replay or documentation evidence alone.

## 2. Replay envelope

A replay manifest must bind:

```text
m63_replay_id
m62_decision_reference
m61_challenge_reference
m60_packet_reference
m59_review_reference
source_revision
working_tree_identity
working_tree_state
environment_identity
rule_set_identity
schema_version
input_manifest_identity
input_count
input_order
input_digests
expected_decision
expected_gap_counts
expected_disposition
replay_method
comparator_version
captured_at
freshness_rule
owner
independent_reviewer
limitations
```

The replay envelope must be local, bounded, redacted, deterministic to compare, and safe to quarantine. It must not contain raw databases, full SQL, private user content, secrets, credentials, cookies, screenshots as sole proof, arbitrary absolute paths, model/network payloads, or unbounded logs.

## 3. Declared input manifest

The manifest must enumerate every input that M62 claims to aggregate:

```text
input_id
input_kind = M59 | M60 | M61 | source_identity | environment | owner | reviewer | gap | evidence | limitation
source_path_or_bounded_reference
source_revision
artifact_identity
digest
sequence_index
claim_scope
participant_scope
required_or_optional
redaction_state
freshness_state
inclusion_reason
exclusion_reason_or_not_applicable
```

An exclusion is not an omission when it is explicitly enumerated, justified, source-bound, and visible to the reviewer. An unlisted input cannot be treated as absent merely because the replay manifest lacks it.

### 3.1 Anti-omission checks

A future replay review must compare:

1. M62’s referenced input IDs against the manifest.
2. M60 open/reopened/closed gap IDs against the decision record.
3. M61 challenge findings against recorded contradictions and freshness results.
4. Owner matrix rows against owner dispositions and acknowledgements.
5. Required participant/path categories against inventory rows.
6. Declared counts against actual manifest rows.
7. Rule-set version against the comparator and expected decision.
8. Exclusions against explicit reasons and bounded search limitations.

A hash protects a declared item; it does not prove that an undeclared item was impossible. Total omission detection requires an independent expected-set or capture-boundary proof and remains limited to that boundary.

## 4. Deterministic replay and comparator

The comparator must be conceptually pure and bounded:

```text
replay(inputs, rule_set, precedence) -> decision_record_projection
compare(replayed_projection, expected_projection) -> match | mismatch | incomplete | unknown
```

A replay must report:

```text
replay_status = match | mismatch | incomplete | unknown
input_manifest_match
rule_set_match
source_scope_match
gap_count_match
disposition_match
precedence_trace
omitted_or_unexpected_inputs
stale_inputs
contradictory_inputs
limitation
next_smallest_action
```

- `match` means the same recorded inputs and rules produce the same bounded projection.
- `mismatch` means the decision, counts, precedence trace, or input identity differs; affected claims are `BLOCKED`.
- `incomplete` means a required input, manifest, comparator, environment, or method is missing; no completeness claim is allowed.
- `unknown` means the result cannot be classified safely; disposition remains `BLOCKED`.

Replay must preserve first-blocker precedence and must not “repair” a mismatch by choosing the favorable output.

## 5. Integrity, completeness, and omission limits

| Property | Replay may establish | Replay cannot establish |
|---|---|---|
| Digest/hash match | Declared bytes or bounded artifacts were unchanged after capture | Clean origin, complete capture, or runtime truth |
| Signature/owner acknowledgement | Artifact binding or governance responsibility | Semantic correctness or unobserved-path absence |
| Append-only history | Recorded entries were not reordered/deleted within the chain boundary | Events never submitted to the chain |
| Manifest equality | Declared expected and actual sets agree | That the expected set was complete in the real world |
| Deterministic replay | Same recorded projection under same rules | Hidden environmental state, races, kernel/filesystem behavior |
| Static source replay | Same static analysis output under same source/rules | Dynamic dispatch, SQLite locking, resource ownership, runtime recovery |
| Synthetic replay | Modelled state-machine behavior | Real databases, user data, power loss, browser UX, production safety |

The reviewer must state the trusted capture boundary and the silent-drop/omission limitation explicitly. “Replay passed” is never shorthand for “all events happened” or “runtime was safe.”

## 6. M62 replay decision mapping

### `BLOCKED` — current default

Use `BLOCKED` when the manifest is incomplete, input identity conflicts, a digest mismatches, a required gap is unlisted, a comparator/rule set differs, a replay is `mismatch`/`incomplete`/`unknown`, a search failure is treated as clean, or any authority/privacy/fallback boundary is violated. M63 cannot issue implementation `GO`.

### `HOLD`

Use `HOLD` only when one bounded replay input or comparator fact is missing, no contradiction is proven, the collection action is named, and no readiness claim is made. HOLD authorizes no code, store access, pilot, or status promotion.

### `SPLIT`

Use `SPLIT` only for separately approved synthetic comparator/codec/manifest/state-machine work. Synthetic SPLIT cannot open real databases, inspect user data, detect unobserved runtime events, establish runtime recovery, or promote M52/M53/status.

### `TARGET_READY_FOR_REVIEW`

Use this only when the replay manifest, comparator identity, declared input set, anti-omission checks, precedence trace, limitations, and independent review are structurally complete within one source/environment/claim envelope. It is structural documentation readiness only; it is not implementation-approved and is not runtime-ready.

### `GO`

M63 cannot issue implementation `GO`. A future decision requires separate M62 approval, exact paths/owners, fresh M53 evidence, rollback, and one source revision/environment/evidence scope.

## 7. Replay failure and rollback

If replay fails or becomes incomplete:

- retain the original decision record and manifest;
- record the mismatch/omission/staleness without rewriting history;
- reopen dependent gaps and invalidate dependent positive readiness claims;
- quarantine derived replay artifacts;
- preserve the dirty worktree and prior limitations;
- return to `BLOCKED` or bounded `HOLD` according to the first applicable blocker;
- name one smallest corrective action.

No destructive git cleanup is permitted. A replay artifact cannot overwrite or replace the authoritative Honeycomb/EventLedger data.

## 8. Browser, privacy, and fallback boundaries

- Navigation, tabs, private browsing, offline use, accessibility, and manual work remain usable when storage or replay artifacts are unavailable.
- Storage/replay failure cannot widen model/network context or trigger model, network, connector, OS, telemetry, permission, or sync actions.
- Corrupt or incomplete decision records cannot silently initialize an empty replacement and claim success.
- Replay artifacts exclude private content, credentials, cookies, page text, raw databases, screenshots as sole proof, and unbounded logs.

## 9. M53 handoff

M63 may produce only a bounded future M53 request:

```text
m53_claim_scope
m53_evidence_owner
source_revision
working_tree_identity
environment_identity
replay_status
manifest_identity
closed_gap_ids
reopened_gap_ids
explicitly_blocked_gap_ids
required_runtime_tiers
browser_manual_path_scope
privacy_redaction_receipt
independent_review_receipt
next_smallest_action
```

M53 remains the runtime evidence boundary. Replay cannot substitute for M53 source/diff, build/focused tests, deterministic faults, restart/recovery, manual clean-profile browser, or independent review.

## 10. M63 gates

| Gate | Requirement |
|---|---|
| M63-A | M62 scope, participants, exclusions, and current BLOCK are reproduced. |
| M63-B | Production participants remain exactly `{Honeycomb, EventLedger}`. |
| M63-C | HandoffRecoveryJournal and SessionFileStore remain excluded unless separately admitted. |
| M63-D | WISP/M5 remain blocked and unregistered. |
| M63-E | No coordinator database, second ledger, product-data authority, or new semantic authority is proposed. |
| M63-F | Replay envelope binds source, worktree, environment, rule set, schema, manifest, and claim scope. |
| M63-G | Declared input manifest enumerates required and explicit excluded inputs. |
| M63-H | Anti-omission checks compare inputs, gaps, owners, participants, counts, rules, and exclusions. |
| M63-I | Replay comparator reports match, mismatch, incomplete, or unknown without silent repair. |
| M63-J | First-blocker precedence is preserved during replay. |
| M63-K | Digest/signature/append-only/manifest limitations are explicit. |
| M63-L | Replay cannot claim unobserved event completeness or runtime safety. |
| M63-M | Search/tool failures remain `inventory_incomplete`, not clean inputs. |
| M63-N | Stale, mixed, conflicting, or mismatched inputs force BLOCKED and gap reopening. |
| M63-O | Synthetic SPLIT cannot access real databases/user data or prove recovery. |
| M63-P | TARGET_READY_FOR_REVIEW is structural documentation readiness only, not implementation-approved or runtime-ready. |
| M63-Q | M63 cannot issue implementation GO or status promotion. |
| M63-R | HOLD/SPLIT/TARGET_READY_FOR_REVIEW authorize no code or store access. |
| M63-S | Replay failure preserves original records, reopens dependencies, and quarantines derivatives. |
| M63-T | Browser/private/offline/accessibility/manual fallback remains explicit. |
| M63-U | Storage/replay failure cannot widen model/network/OS context. |
| M63-V | Replay artifacts are local, bounded, redacted, deterministic to compare, and quarantine-safe. |
| M63-W | M53 handoff binds one future source revision, environment, replay status, claim, and evidence scope. |
| M63-X | Independent review confirms anti-omission limits and no readiness/status inflation. |

## 11. Honest limits and primary references

M63 does not execute replay, complete M62, close real runtime gaps, implement lifecycle protocols, verify writer barriers, run SQLite recovery, prove migration/deletion continuity, validate browser startup, establish crash consistency, prove power-loss durability, prove secure/forensic deletion, prove cross-store atomicity, certify compliance, or establish production/ship readiness.

Primary references:

- [SLSA v1.0 build levels](https://slsa.dev/spec/v1.0/levels)
- [NIST SP 800-53 Rev. 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)
- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [SQLite result codes](https://www.sqlite.org/rescode.html)
- [Swift Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Apple Signing and Verifying](https://developer.apple.com/documentation/security/signing-and-verifying)
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)

These sources establish platform, library, provenance, audit, replay, and omission limits. M63’s replay envelope, manifest, comparator states, anti-omission checks, dispositions, gates, fallback, rollback, and no-status-promotion rules are Hive governance decisions.

**M63 is complete as a planning artifact when its replay envelope, declared input manifest, anti-omission checks, deterministic comparator, integrity/completeness limits, disposition mapping, M53 handoff, 24 gates (M63-A through M63-X), rollback rules, and independent review are structurally validated.**
