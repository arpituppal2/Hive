# M44 — Governance Traceability & Implementation Readiness Execution Plan

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M44 Governance Traceability & Implementation Readiness
> **Depends on:** M0–M6 storage/provenance/recovery; M10–M17 browser/context/action/worker boundaries; M25 engine/update ownership; M26 ownership/policy; M27 sync/device/epoch state; M28 Flow authority; M29 context governance; M30 personal work loop; M31 portability/extensibility; M32 release receipts/distribution/recovery; M33 operations/vulnerability response/trust feedback; M34 TrustSnapshot/control plane; M35 evidence/policy lifecycle; M36 reproducible recovery; M37 notices/review; M38 offline evidence packages; M39 package disposition; M40 consent-bound exchange; M41 correction/closure/history; M42 re-export/history lifecycle; M43 lineage/notification continuity.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary research anchors:** NIST SP 800-218 SSDF; OWASP ASVS/SAMM; SLSA/in-toto provenance boundaries; SQLite transaction/backup documentation; W3C WCAG status/error guidance; Apple signing/notification/file-access boundaries.
>
> M44 is the deliberate pause between abstract governance and runtime implementation. It does not add another product capability. It turns existing M31–M43 contracts into an implementation handoff that names the owner, schema, state machine, fixture, evidence, and fallback for each behavior. A planning matrix, source file, mock, or green documentation check is not runtime evidence.

## 0. Decision summary

The smallest safe M44 architecture is:

```text
M31–M43 existing contracts
  → canonical requirement inventory
    → owner/schema/state/fallback traceability
      → deterministic fixture and evidence mapping
        → implementation sequencing and readiness decision
          → runtime work only after explicit handoff
```

| Slice | User value | Hard boundary |
|---|---|---|
| **R1 — Requirement synthesis** | One searchable inventory prevents duplicated or contradictory contracts | M44 restates and links existing authority; it does not invent a new policy layer |
| **R2 — Authority ownership** | Every field/action has one owner and a projection rule | No parallel ledger, source, notice, consent, identity, lifecycle, or analytics authority |
| **R3 — Execution state** | Runtime implementers know valid states, transitions, errors, and fallbacks | A state table is not an implementation or proof that the state is wired |
| **R4 — Evidence mapping** | Each requirement has a fixture, evidence type, and honest status | A fixture definition is not a passing test; no capability becomes verified |
| **R5 — Handoff** | Runtime work can begin in the smallest safe order | No Swift/Rust/UI/runtime edits, model training, installs, or release changes in M44 |

M44 does **not** claim that M31–M43 are implemented, that the browser is release-ready, that the governance contracts are legally compliant, or that planning artifacts prove runtime behavior.

## 1. Current truth and readiness boundary

### 1.1 Current implementation classification

The source tree contains browser/core/AI foundations and existing storage/runtime surfaces, while M31–M43 advanced portability, operations, lifecycle, exchange, correction, re-export, notice, and lineage contracts remain planning-heavy. Exact source truth and fresh tests outrank this plan. M44 therefore records one of these statuses for each requirement:

```text
absent              no source owner or contract implementation located
planned             contract exists but no implementation evidence
code_present        source symbol exists; behavior is not proven end to end
blocked             implementation/evidence cannot proceed due to dependency or environment
runtime_candidate   smallest bounded implementation slice is specified and ready to schedule
verified            fresh build + relevant tests + user-observable runtime evidence passed
```

`verified` is never assigned by M44’s document checks. A mock, type, prompt, fixture, screenshot, historical count, or successful plan validation remains non-runtime evidence.

### 1.2 Existing authority rule

M44 is a traceability projection over existing authorities and creates no new authority. M44 can never be a canonical owner, and every `AuthorityBinding.canonical_owner` must resolve outside M44, its mirrors, fixtures, models, and planning documents:

| Concern | Canonical owner | M44 may record | M44 must not create |
|---|---|---|---|
| Durable knowledge/source/claim | Honeycomb/source owners | exact owner/type/revision link | second graph or source store |
| Consequential event evidence | EventLedger | event kind/reference requirement | second ledger or mutable truth |
| Capture/memory admission | M0–M5 admission/lifecycle owners | admission predicate and fixture | silent context widening |
| Consent/permissions/trust | M6/M16/M26/M34/M40 owners | grant/revoke/expiry references | new consent or trust authority |
| Policy/lifecycle/tombstone | M35/M39/M42 owners | state and generation dependency | automatic deletion or universal erasure |
| Change notice/re-review | M37/M43 projection | owner notice/revision binding | parallel notice store |
| Exchange/correction/closure | M40/M41 owners | exact reference and state relation | dispute service or consensus |
| Export/import | M31/M40/M42 owners | manifest/omission/quarantine evidence | arbitrary plugin or transport |
| Release/update/recovery | M25/M32/M33/M36 owners | release/evidence dependency | ship claim from documentation |
| Browser/session/private fallback | browser/session owner | unavailable/denied/degraded path | blocking navigation |

If two contracts appear to own the same field or transition, M44 records a conflict and routes it to the existing authority owner. It does not resolve the conflict by inventing a new authority.

## 2. Product boundary and non-goals

### 2.1 In scope

1. A versioned `RequirementTrace` projection with stable requirement ID, source authority, owner, dependency, user journey, schema/state reference, fixture IDs, evidence type, status, limitation, and next action.
2. A versioned `AuthorityBinding` mapping each durable object, projection, action, consent, event, and fallback to exactly one canonical owner plus zero or more read-only references.
3. A `RuntimeReadiness` record distinguishing contract-ready, implementation-ready, environment-blocked, evidence-blocked, runtime-candidate, and verified; every status includes an evidence requirement and cannot be self-promoted by a model or document check.
4. A state/transition/error/fallback matrix for the smallest M31–M43 implementation slices, including unavailable, denied, stale, conflicting, quarantined, private, locked, offline, manual, and browser-first behavior.
5. A fixture ownership matrix mapping each deterministic fixture to the owning module, synthetic input, expected state, evidence artifact, privacy class, and cleanup scope. Fixtures remain synthetic and contain no credentials, real browsing history, private memory, or production recipient data.
6. An evidence chain mapping requirement → fixture → observed result → artifact/reference → reviewer/authority → remaining limitation. A missing artifact is `unavailable` or `blocked`, never a passing result.
7. A dependency-ordered runtime handoff that identifies the first safe implementation slice, prerequisites, stop conditions, rollback/deletion implications, and when a future implementation milestone may begin.
8. Cross-mirror synchronization so condensed canon preserves authority ownership, non-runtime status, browser-first fallback, and evidence limits.
9. Adversarial checks for authority laundering, status inflation, fixture/result confusion, stale references, duplicate IDs, schema bloat, raw-content leakage, prompt injection, and planning claims presented as shipped behavior.

### 2.2 Explicit non-goals

- Any Swift, Rust, JavaScript, UI, database, model, training, dependency, build, test, installation, signing, telemetry, credential, network, or release change.
- A new EventLedger, Honeycomb, consent, policy, source, notice, recipient, delivery, identity, lifecycle, analytics, or evidence authority.
- Automatic migration, deletion, correction, re-export, notification, source mutation, model-selected status, or document-triggered tool execution.
- Claiming NIST SSDF, OWASP ASVS/SAMM, SLSA, WCAG, Apple notarization, privacy, legal, or security compliance from a planning matrix.
- Treating source presence, mock output, a fixture definition, screenshot, prompt, test specification, or green Markdown validation as runtime evidence.
- Replacing accessibility/manual review with an automated score; manual/unavailable assistive-technology evidence remains explicit.
- Remote service, cloud dashboard, recipient registry, marketplace, issue tracker, or engagement telemetry.
- Expanding the M31–M43 scope or adding new abstract governance concepts merely to fill a matrix.

## 3. Readiness contracts

### 3.1 `RequirementTrace`

```text
RequirementTrace {
  requirement_id: stable M44-scoped ID
  source_refs: exact M31–M43 plan/spec references
  authority_owner: one canonical owner ID
  projection_refs: zero or more read-only consumers
  user_journey: bounded journey ID or null
  schema_refs: exact contract/schema IDs
  state_refs: exact state/transition matrix IDs
  fixture_refs: exact synthetic fixture IDs
  evidence_kind: source_review | fixture_result | unit_test | integration_test |
                 ui_test | manual_accessibility | runtime_smoke | release_receipt |
                 unavailable | blocked
  source_revision: exact commit/tag/content hash or unavailable
  environment: exact toolchain/OS/profile/permission state or unavailable
  evidence_scope: exact fixture/profile/workspace/data scope or unavailable
  status: absent | planned | code_present | blocked | runtime_candidate | verified
  limitation: required when status is not verified
  reviewer_ref: explicit reviewer/authority or unavailable
  observed_at: authoritative time or null
  next_action: reconcile_owner | define_fixture | implement_slice |
               obtain_environment | run_evidence | document_limitation | none
}
```

A `RequirementTrace` is a planning/evidence projection. It cannot grant permission, mark a feature verified, mutate a source, or replace EventLedger evidence. `source_revision`, `environment`, and `evidence_scope` are required evidence dimensions; missing or stale values force `unavailable` or `blocked`. `verified` requires fresh build evidence, relevant test evidence, and user-observable runtime evidence from the owning implementation milestone, all bound to the same source revision/environment/scope and explicit owner review. M44’s document-only validation cannot produce that status.

### 3.2 `AuthorityBinding`

```text
AuthorityBinding {
  binding_id: stable UUID
  subject_kind: source | claim | capture | event | consent | policy | notice |
                exchange | correction | closure | export | package | task | fallback
  subject_ref: exact owner-scoped ID or unavailable
  canonical_owner: exactly one authority ID
  owner_revision: exact revision/generation or unknown
  projection_refs: bounded read-only references
  allowed_reads: typed list
  forbidden_writes: typed list
  stale_when: bounded generation/hash/scope/lifecycle predicates
  conflict_state: none | duplicate_owner | contradictory_owner |
                 unresolved | unavailable
  status: resolved | unresolved | blocked | unavailable
  next_action: inspect_owner | reconcile | quarantine | none
}
```

`canonical_owner` must resolve to an existing authority and must never be M44, a mirror, a fixture, a model, or a planning document. A binding with `duplicate_owner` or `contradictory_owner` cannot be silently resolved by a model, planner, fixture, or mirror. M44 records the conflict and fails closed for authority-affecting actions.

### 3.3 `RuntimeReadiness`

```text
RuntimeReadiness {
  readiness_id: stable UUID
  requirement_refs: exact RequirementTrace IDs
  owner_refs: exact AuthorityBinding IDs
  dependency_refs: exact milestone/source IDs
  implementation_scope: one bounded slice
  preconditions: typed list
  stop_conditions: typed list
  rollback_or_delete_scope: typed list
  evidence_required: typed list
  status: contract_only | handoff_ready | environment_blocked |
          evidence_blocked | runtime_candidate | verified
  status_basis: exact artifact/test/runtime reference or unavailable
  source_revision: exact commit/tag/content hash or unavailable
  environment: exact toolchain/OS/profile/permission state or unavailable
  evidence_scope: exact fixture/profile/workspace/data scope or unavailable
  fresh_build_ref: exact fresh build evidence or unavailable
  relevant_test_ref: exact relevant test evidence or unavailable
  runtime_observation_ref: exact user-observable runtime evidence or unavailable
  limitations: bounded list
  approved_by: explicit human/authority or unavailable
  next_action: none | reconcile | implement | validate | hold
}
```

`handoff_ready` means only that a bounded implementation task has sufficient documented inputs. It does not mean implemented, tested, shipped, safe, or verified. `runtime_candidate` requires a future implementation owner, exact scope, and explicit preconditions; M44 cannot set it based on prose alone. `verified` is fail-closed: it requires non-null `fresh_build_ref`, `relevant_test_ref`, and `runtime_observation_ref`, matching non-unavailable source revision/environment/evidence scope, and explicit owner approval. Any missing, stale, conflicting, or mismatched field forces `evidence_blocked`, `environment_blocked`, or `hold`.

## 4. Operating rules

### 4.1 Requirement synthesis

Every requirement must have one stable ID, one source authority, one owner, one bounded user journey or explicit non-user-facing classification, one state/error/fallback reference, one fixture or an honest reason no fixture applies, and one evidence kind. Duplicate prose is linked, not copied into a competing authority. Conflicting requirements remain visible and unresolved until the existing owner decides.

### 4.2 Authority and projection discipline

A projection may read and render an owner’s state but cannot authorize, mutate, delete, re-export, notify, or promote itself. Model output, imported package text, browser content, fixture text, notice text, generated plan, or mirror summary is untrusted input and cannot choose an owner, grant a status, widen scope, invoke a tool, or mark evidence complete.

### 4.3 Status honesty

The status ladder is monotonic only with fresh evidence, not with time or document count. A failed, stale, missing, contradictory, or unavailable evidence artifact downgrades or blocks the requirement; no document may “pass by omission.” Historical claims are labeled historical. A plan can be complete while the feature remains absent or blocked.

### 4.4 State and fallback completeness

For every implementation slice, define normal, empty, malformed, stale, conflicting, denied, unavailable, offline, private, locked, cancellation, retry, deletion, restart, accessibility-manual, and browser-first states. If a dimension is genuinely not applicable, record an owner-approved `not_applicable` decision with exact scope and evidence; omission is not not-applicable. Unknown is not success; unavailable is not zero; browser degradation must preserve navigation, tabs, private mode, and local inspection.

### 4.5 Evidence chain and privacy

Evidence references synthetic bounded artifacts by default. No raw page text, screenshots, prompts, credentials, Keychain values, cookies, private memory, recipient data, absolute user paths, or engagement telemetry enters a trace. These are hard privacy exclusions, not merely preferred redactions. A release receipt, test result, or runtime observation must disclose its environment, source revision, scope, and limitations. M44 records references and summaries, not sensitive payloads.

### 4.6 Handoff and stop conditions

The first future runtime slice must be the smallest owner-contained capability with a clear browser-first fallback, deterministic fixture corpus, deletion/recovery semantics, and no dependency on unverified remote services. If any authority, schema, privacy, or evidence precondition is unresolved, the slice remains `hold` or `environment_blocked`. No implementation milestone may silently widen the scope to “finish the platform.”

## 5. Work packages

### M44-A — Requirement synthesis and canonical inventory

Create the stable M44 requirement inventory for M31–M43. Link each requirement to exact source paragraphs, current status, user journey, owner, dependency, schema/state references, and next action. Record duplicate/contradictory prose without creating a new authority.

**Done when:** every selected M31–M43 requirement has one trace ID, source owner, status, limitation, and next action; no entry claims implementation merely because a plan exists.

### M44-B — Authority binding and state ownership

Create the `AuthorityBinding` matrix for source, event, consent, policy, lifecycle, notice, exchange, correction, closure, export, package, task, and fallback subjects. Reconcile owner generations, stale predicates, read-only projections, forbidden writes, and duplicate/contradictory owner states.

**Done when:** every selected subject has exactly one canonical owner or an explicit unresolved/blocked state; no model, mirror, or projection can launder authority.

### M44-C — State, error, fallback, and browser-first matrix

Define normal/empty/malformed/stale/conflicted/denied/unavailable/offline/private/locked/cancelled/retry/deletion/restart/accessibility-manual/browser-first states for the first implementation slices. Bind each state to the existing M0–M43 owner and a user-visible limitation/next action.

**Done when:** unavailable, unknown, manual, and denied states are explicit; ordinary navigation, tabs, private mode, and local inspection remain usable when the feature or authority is disabled.

### M44-D — Fixture and evidence traceability

Map 50 deterministic synthetic fixtures across milestones to owners, synthetic input, expected state, evidence kind, privacy class, cleanup scope, and reviewer. Define evidence records that preserve source revision, environment, scope, observed result, limitations, and artifact identity without copying sensitive payloads.

**Done when:** every fixture has one owner and expected result; fixture definitions cannot be mistaken for passing results; missing/stale/conflicting evidence is blocked or unavailable rather than silently passed.

### M44-E — Runtime handoff and readiness decision

Define the dependency-ordered handoff to the first future implementation slice: owner, files/modules to inspect, bounded behavior, preconditions, stop conditions, rollback/delete scope, fixture subset, evidence required, and browser-first fallback. Close with an honest readiness decision for each selected slice: contract-only, handoff-ready, environment-blocked, evidence-blocked, or hold.

**Done when:** a future implementation agent can start one bounded slice without inventing authority or scope, while M44 itself remains documentation-only and no requirement is marked verified from planning evidence.

## 6. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M44-01 | Requirement has one exact source owner | Trace resolves owner and source reference |
| M44-02 | Requirement appears in two plans with same meaning | One canonical link; no duplicate authority |
| M44-03 | Requirement has contradictory owners | Unresolved/blocked; no silent choice |
| M44-04 | Requirement source is historical | Historical label; no current readiness claim |
| M44-05 | Requirement has no implementation owner | Planned/absent; next action define owner |
| M44-06 | Source symbol exists without behavior evidence | Code-present; not verified |
| M44-07 | Mock output exists without real provider | Planned/code-present; no runtime claim |
| M44-08 | Fixture is defined but not executed | Evidence unavailable; no pass |
| M44-09 | Test passes against stale source revision | Stale/blocked; no current evidence |
| M44-10 | Evidence artifact lacks environment | Unavailable; limitation visible |
| M44-11 | Evidence artifact lacks scope | Unavailable; no broad claim |
| M44-12 | Evidence references private content | Redacted/rejected; no raw payload |
| M44-13 | Evidence includes credential-shaped text | Omitted/quarantined; no echo |
| M44-14 | Model proposes owner assignment | Advisory only; no authority change |
| M44-15 | Imported manifest declares authority | Untrusted; native owner review required |
| M44-16 | Mirror summary drops a hard invariant | Mirror validation fails; detailed authority wins |
| M44-17 | Requirement status changed by document count | Rejected; evidence required |
| M44-18 | Failed test hidden by green summary | Blocked; failure remains visible |
| M44-19 | Historical release count used as current evidence | Historical/unavailable; no ship claim |
| M44-20 | Build evidence from different source revision | Stale; rerun required |
| M44-21 | Runtime slice has no deletion scope | Hold; no implementation handoff |
| M44-22 | Runtime slice has no restart behavior | Hold; recovery contract missing |
| M44-23 | Runtime slice has no private-profile behavior | Hold; privacy boundary missing |
| M44-24 | Runtime slice has no denied-permission state | Hold; fallback contract missing |
| M44-25 | Runtime slice has no accessibility/manual path | Hold/unavailable; manual review required |
| M44-26 | Runtime slice depends on unavailable model | Environment-blocked; honest fallback |
| M44-27 | Runtime slice depends on remote service | Hold unless separately approved; browser remains usable |
| M44-28 | Runtime slice adds a second ledger | Rejected; bind existing EventLedger |
| M44-29 | Runtime slice adds a second source store | Rejected; bind Honeycomb/source owner |
| M44-30 | Runtime slice mutates from projection text | Rejected; projection is read-only |
| M44-31 | Stale owner generation reaches action | Blocked; preflight revalidation required |
| M44-32 | Conflicting receipt reaches readiness | Quarantined/blocked; no status promotion |
| M44-33 | Untrusted notice contains tool instruction | Inert; no invocation |
| M44-34 | Prompt injection claims readiness | Advisory/untrusted; no promotion |
| M44-35 | Scope expands during handoff | Blocked; new plan required |
| M44-36 | Fixture contains real browsing history | Rejected; synthetic replacement required |
| M44-37 | Fixture contains absolute user path | Generalized/redacted |
| M44-38 | Fixture contains recipient/contact data | Rejected/redacted |
| M44-39 | Evidence artifact copied raw page text | Redacted/rejected; summary only |
| M44-40 | Offline authority unavailable | Browser-first/manual local state |
| M44-41 | Private profile selected | Excluded or synthetic non-content state |
| M44-42 | Keychain/file permission denied | Unavailable/manual; no bypass |
| M44-43 | User cancels handoff | Cancelled; no partial promotion |
| M44-44 | Restart occurs during readiness review | Resumable or explicitly incomplete; no false completion |
| M44-45 | Deletion requested for trace metadata | Scoped deletion; external copies disclosed |
| M44-46 | Reduced motion/VoiceOver/large text | State and next action understandable |
| M44-47 | Browser feature disabled | Navigation/tabs/private/local inspection unaffected |
| M44-48 | Required owner unavailable | Blocked/unavailable; no inferred owner |
| M44-49 | All evidence fresh and bounded | Handoff-ready only; verified remains blocked until required build/test/runtime refs and owner approval bind to the same revision/environment/scope |
| M44-50 | Final readiness review | Status, owner, scope, evidence, limitation, fallback, and next action present |

## 7. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M44-A | Inventory completeness | Every selected M31–M43 requirement has stable ID, source owner, status, limitation, and next action |
| M44-B | Single authority ownership | Each subject has one canonical owner or explicit unresolved/blocked state |
| M44-C | Projection discipline | Projections cannot mutate, authorize, delete, re-export, notify, self-promote, or become the canonical owner |
| M44-D | Status honesty | `verified` requires fresh build, relevant test, and user-observable runtime references bound to the same source revision/environment/scope plus owner approval; planning/source/mock/fixture evidence alone cannot promote status |
| M44-E | State completeness | Normal, empty, malformed, stale, conflict, denied, unavailable, offline, private, locked, cancellation, retry, deletion, restart, manual, and browser-first states are mapped for every slice; only owner-approved evidence-backed `not_applicable` may omit a dimension |
| M44-F | Fixture ownership | All 50 synthetic fixtures have one owner, expected result, privacy class, and cleanup scope |
| M44-G | Evidence traceability | Evidence binds requirement, source revision, environment, scope, observed result, artifact, reviewer, and limitation |
| M44-H | Privacy boundary | No credentials, private memory, raw page text, screenshots, contact data, absolute paths, or engagement telemetry enter traces |
| M44-I | Dependency ordering | First runtime slice has explicit preconditions, stop conditions, rollback/delete scope, and browser-first fallback |
| M44-J | Conflict/replay safety | Stale, duplicate, conflicting, and replayed evidence cannot promote status or attach to a newer requirement |
| M44-K | Accessibility/degraded behavior | Offline, private, locked, denied, unavailable, manual, VoiceOver, large-text, contrast, and reduced-motion states remain understandable |
| M44-L | Handoff honesty | M44 remains documentation-only; handoff-ready is not implemented, shipped, safe, or verified; browsing remains usable |

## 8. Safety, privacy, and claim boundaries

M44 is a planning/evidence projection over existing authorities. It stores stable references, bounded summaries, statuses, limitations, owners, fixture IDs, and next actions—not raw user content. It cannot create or alter source truth, EventLedger events, consent, policy, notices, exchanges, corrections, packages, lifecycle state, or release artifacts.

NIST SSDF, OWASP ASVS/SAMM, SLSA/in-toto, W3C WCAG, Apple documentation, and SQLite documentation inform terminology and verification expectations; using their language does not establish compliance, certification, attestation, or secure release status. SLSA/provenance does not prove code quality or upstream dependency safety. SQLite backup consistency does not prevent application-level migration defects. Automated accessibility checks do not replace manual assistive-technology review.

A plan, matrix, prompt, source symbol, mock, fixture definition, historical count, screenshot, or green documentation validation is not runtime evidence. `verified` requires a future owner’s fresh build evidence, relevant test evidence, and user-observable runtime evidence with exact source revision, environment, evidence scope, artifact, reviewer, explicit owner approval, and limitations. Missing, stale, conflicting, denied, private, locked, offline, or unavailable evidence remains visible and cannot be converted into success by omission or model output.

M44 must never be described as implementation completion, compliance, security certification, supply-chain immunity, accessibility conformance, production readiness, or a release/ship decision.

## 9. Execution order and handoff

Implementing M44 itself is documentation-only: reconcile the selected M31–M43 requirement inventory, authority matrix, state/fallback matrix, fixture ownership matrix, evidence record schema, and readiness handoff. Use synthetic examples only. Do not inspect or modify user secrets, production profiles, credentials, real recipient data, or runtime files as part of M44 planning.

The next smallest safe action after M44 is **M44-A: freeze the selected requirement inventory and authority bindings, then choose one owner-contained runtime candidate whose preconditions, deletion/recovery behavior, synthetic fixtures, accessibility path, and browser-first fallback are all explicit**. Do not begin broad implementation, model training, remote-service integration, automatic mutation, or a new governance milestone until that handoff is reviewed.
