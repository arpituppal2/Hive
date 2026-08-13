# M41 — Evidence Challenge, Correction & Exchange Closure Execution Plan

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M41 Evidence Challenge, Correction & Exchange Closure
> **Depends on:** M0–M6 storage/provenance/recovery; M10–M17 browser/context/action/worker boundaries; M25 engine/update ownership; M26 ownership/policy; M27 sync/device/epoch state; M28 Flow authority; M29 context governance; M31 portability/extensibility; M32 release receipts/distribution/recovery; M33 operations/vulnerability response/trust feedback; M34 TrustSnapshot/control plane; M35 evidence/policy lifecycle governance; M36 reproducible evidence/recovery rehearsal; M37 user-visible change/deprecation/support horizon; M38 offline evidence traceability/audit package; M39 evidence package lifecycle/human disposition; M40 consent-bound evidence exchange/recipient review.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities:** M31 correction/omission/import semantics; M33 operational trust-feedback and case boundaries; M35 lifecycle/tombstones/deletion; M37 notice/re-review continuity; M38 package/provenance/traceability validation; M39 lifecycle/disposition/review invalidation; M40 consent/recipient/receipt limits; EventLedger/Honeycomb as existing authorities; NIST audit/accountability concepts; W3C Data Integrity challenge/domain/replay concepts without importing a credential system; OWASP untrusted-content rules; W3C WCAG status/error/confirmation guidance; Apple Keychain/file lifecycle; SQLite transaction/history constraints; SLSA/in-toto provenance scope limits.
>
> M41 defines what happens after a consent-bound package is reviewed and a participant disputes, corrects, retracts, or closes an exchange. A challenge records a bounded question or objection; a correction appends a new owner-scoped state referencing the prior state; deletion/tombstoning remains governed by the existing lifecycle owner; closure records the exchange disposition without declaring truth, trust, legal finality, or universal erasure. M41 is a projection and coordination contract, not a second ledger or dispute service.

## 0. Decision summary

The smallest safe M41 architecture is:

```text
M40 exchange + recipient receipt/review
  → bounded challenge or feedback submission
    → owner/provenance classification: inquiry | contradiction | correction-request |
       source-correction | withdrawal | security-concern | unable-to-verify
      → existing authority response or explicit unavailable state
        → append-only correction/review/closure reference
          → stale/re-review propagation to affected package/exchange records
            → user-visible sharing history and browser-first fallback
```

| Slice | User value | Hard boundary |
|---|---|---|
| **C1 — Challenge intake** | A recipient can say exactly what is disputed and why | A challenge is an untrusted request, not an authority change or truth claim |
| **C2 — Correction lineage** | Corrections preserve the original state and show the replacement relationship | Only the existing owner can change canonical evidence; M41 appends references and does not rewrite history |
| **C3 — Response/re-review** | Sender and recipient can see whether a challenge is open, answered, stale, blocked, or unavailable | No automatic acceptance, correction, deletion, or escalation occurs from a model or package |
| **C4 — Exchange closure** | Users can explicitly close, defer, withdraw, or leave an exchange unresolved | Closure means workflow disposition only; it is not proof of truth, safety, consent, or incident resolution |
| **C5 — History/fallback** | Sharing and challenge history remain inspectable without a network or specialized viewer | History is a projection over existing authorities, not a second exchange ledger |

M41 does **not** claim a neutral arbiter, verified human identity, legal dispute resolution, non-repudiation, cryptographic attestation, universal correction propagation, universal deletion, or correctness merely because an exchange is closed.

## 1. Current truth and authority boundaries

### 1.1 Existing surfaces

| Surface | Current truth | M41 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| M33 operations/trust feedback | Operational intake, vulnerability, support, privacy, accessibility, and case boundaries are defined | Reference an existing case or bounded escalation state | M41 cannot create, submit, triage, or close an operational case |
| M35 lifecycle | Owner-controlled generations, tombstones, expiry, revocation, and deletion semantics | Re-check lifecycle state after challenge/correction | A challenge cannot revoke or delete canonical content |
| M37 notices/reviews | User-visible change notices, acknowledgement, re-review, compatibility, and support states | Mark affected review/exchange state stale or re-review-required | Acknowledgement is not a correction or closure |
| M38 package | Redaction, source references, validation, traceability, and inert fallback | Bind challenge to exact package/revision/finding | A package cannot correct its own evidence or select an authority |
| M39 lifecycle/disposition | Package state, quarantine, deletion limits, review invalidation, and human disposition | Apply package lifecycle and stale-review rules | Disposition cannot rewrite source truth or certify a dispute |
| M40 exchange | Sender consent, recipient binding, negotiation, receipts, and copy limits | Bind feedback to exact exchange, recipient scope, and receipt | Receipt does not prove identity, truth, delivery, or closure |
| EventLedger | Append-only local event authority | Store bounded challenge/response/closure references where owner permits | M41 cannot create a second challenge or exchange ledger |
| Honeycomb/source owners | Canonical memory, source, claim, artifact, and relationship truth | Link to owner correction or contradiction state | M41 cannot promote recipient text into canonical truth |
| Browser shell | Navigation, tabs, private mode, and local inspection remain the wedge | Show history/feedback failure without blocking browsing | M41 cannot require Swarm, network, or a live reviewer |

**Current implementation classification:** Hive has planning contracts for operations/trust feedback, provenance, lifecycle, notices, offline packages, package review, and consent-bound exchange, but no verified post-exchange challenge envelope, correction lineage contract, response/re-review propagation, closure disposition, or user-visible sharing-history projection. M41 remains planning-only until fresh implementation and runtime evidence exist.

### 1.2 Authority matrix

| Concern | Existing authority | M41 rule |
|---|---|---|
| What was exchanged | M40 `ConsentBoundExchange` and `RecipientReceipt` | Reference exact package hash/revision, scope, recipient, and receipt |
| Canonical source/claim truth | Honeycomb/source owner and M31/M35 rules | Challenge may reference; only owner may correct, tombstone, or delete |
| Operational/security case | M33 | M41 may point to an existing case or request human escalation; it cannot auto-submit/close |
| Package validation | M38 | Preserve findings; a challenge cannot rewrite validator output |
| Package lifecycle/review | M39 | Challenge/correction can invalidate local review; lifecycle owner supplies current state |
| Change/re-review | M37 | Changed scope/generation/authority causes visible re-review; no silent acceptance |
| Local consequential evidence | EventLedger | Append bounded IDs/references under its existing schema and retention rules |
| User memory/knowledge | Honeycomb | No recipient statement becomes durable memory without the owner’s admission path |
| Identity/permission | Apple platform and existing permission authorities | Unknown identity or denied permission remains unknown/denied |
| Browser fallback | Browser/session owner | Challenge, history, or closure failure never blocks browsing/private mode |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A versioned `EvidenceChallenge` envelope bound to exchange ID, package ID/revision, source/claim/projection reference, recipient scope, challenge kind, user-authored statement, evidence pointers, requested outcome, and limitations.
2. Challenge kinds that remain distinct: inquiry, contradiction, correction-request, source-correction, stale-evidence, withdrawal, security-concern, privacy-concern, scope-error, and unable-to-verify.
3. Explicit challenge states: drafted, previewed, submitted-local, acknowledged-local, needs-information, under-owner-review, answered, rejected, superseded, withdrawn, stale, blocked, and unable-to-verify.
4. A `CorrectionLineage` contract distinguishing original state, proposed correction, owner-confirmed correction, owner-rejected correction, tombstone/deletion state, supersession, and unresolved disagreement.
5. Append-only before/after references where an existing authority supplies them; M41 never mutates the original record or fabricates a corrected value from model output.
6. Response semantics distinguishing factual owner response, recipient response, unavailable authority, conflicting responses, no response, and local-only observation. Silence never means acceptance.
7. Re-review propagation: package, receipt, review, and exchange states become stale or re-review-required when referenced hash, source generation, lifecycle, redaction/validator profile, or correction lineage changes.
8. Explicit exchange closure states: open, answered, accepted-by-recipient, rejected-by-recipient, corrected, withdrawn, expired, revoked-before-handoff, closed-unresolved, unable-to-verify, and reopened.
9. Closure rules requiring an explicit user action, exact scope, current exchange state, unresolved limitations, next action, and whether closure is local-only or owner-backed.
10. User-visible sharing history projection showing package/revision, recipient reference, consent generation, handoff/receipt state, challenge/correction/response/closure state, stale/re-review markers, and copy/deletion limitations without raw content.
11. Challenge/response/closure replay and conflict handling: duplicate IDs are idempotent only when bytes match; conflicting bytes remain quarantined and do not silently replace state.
12. Accessible challenge, response, correction, and closure flows with text error identification, status announcements, confirmation for consequential local actions, keyboard/VoiceOver/large text/contrast/reduced-motion support, and color-independent states.
13. Browser-first fallback for offline, private profile, locked Keychain, denied file access, unavailable owner, absent recipient, unsupported schema, missing history viewer, and M41-disabled mode.
14. Synthetic adversarial fixtures for prompt injection, fabricated owner response, spoofed owner-backed closure, correction laundering, scope widening, stale-response replay, recipient spoofing, secret inclusion, malicious paths, and closure overclaim.
15. Minimal local metadata only: IDs, exact hashes/revisions, typed challenge/response/closure states, bounded statements or redacted summaries, owner references, timestamps where authoritative, and limitations. Raw page text, prompts, screenshots, credentials, and private memory are not required.

### 2.2 Explicit non-goals

- A second dispute, feedback, exchange, provenance, EventLedger, Honeycomb, ticketing, policy, or closure database.
- Automatic correction, deletion, tombstoning, retraction, source mutation, memory admission, package replacement, or lifecycle change.
- Model-decided truth, model-decided dispute outcome, model-authored owner response presented as fact, or automatic escalation to a person/service.
- A neutral arbiter, voting system, legal evidence process, regulatory complaint channel, SLA, guaranteed response, non-repudiation, or compliance certification.
- Universal propagation of corrections to copies already exported, downloaded, emailed, synced, backed up, printed, screen-captured, or stored on another device.
- Universal revocation or erasure of recipient copies; M40 copy limitations remain authoritative.
- Treating a signed/hash-linked challenge, response, or closure as proof of human identity, truth, intent, or legal finality.
- Treating `closed`, `answered`, `accepted-by-recipient`, or `corrected` as proof that the underlying claim is true or the incident is resolved.
- Remote services, network transport, collaboration workspaces, public issue tracking, or cross-device challenge synchronization.
- Automatic user notifications, engagement scoring, behavioral profiling, hidden analytics, or remote model context expansion.
- Runtime implementation, UI implementation, transport configuration, signing-key changes, model training, telemetry, or Swift source edits in this planning milestone.

## 3. Challenge, correction, and closure contracts

### 3.1 `EvidenceChallenge`

```text
EvidenceChallenge {
  challenge_id: stable UUID
  schema_version: semantic version
  exchange_id: M40 exchange ID or unavailable
  package_id: UUID or unavailable
  package_revision: exact hash/revision or unknown
  source_ref: exact owner source/claim/projection ref or unavailable
  recipient_scope: exact scope or unknown
  challenge_kind: inquiry | contradiction | correction_request | source_correction |
                  stale_evidence | withdrawal | security_concern | privacy_concern |
                  scope_error | unable_to_verify
  statement: bounded user-authored text or redacted summary
  evidence_refs: exact bounded references or empty
  requested_outcome: explain | verify | correct_owner_record | re_export |
                     withdraw_local | escalate_owner | unable_to_verify
  consent_generation: exact M40 generation or unknown
  state: drafted | previewed | submitted_local | acknowledged_local |
         needs_information | under_owner_review | answered | rejected |
         superseded | withdrawn | stale | blocked | unable_to_verify
  owner_ref: exact existing authority or null
  created_at: Date or null
  superseded_by: challenge ID or null
  limitations: bounded list
}
```

A challenge is not a correction; it is an assertion or request from an untrusted participant. It cannot alter a source, package, permission, policy, model route, or lifecycle state. A page, imported package, model, or recipient message cannot submit or approve a challenge without an explicit user action.

### 3.2 `CorrectionLineage`

```text
CorrectionLineage {
  lineage_id: stable UUID
  original_ref: exact owner record/reference
  original_revision: exact hash/revision or unknown
  challenge_ref: EvidenceChallenge ID or null
  proposed_state: bounded projection or omitted
  owner_response: proposed | confirmed | rejected | unavailable | conflicting | unknown
  issuer_ref: exact owner identity/reference or unknown
  issuer_event_ref: exact authoritative owner event or unavailable
  response_revision: exact owner response revision/hash or unknown
  verification_state: verified_against_owner | stated_unverified | unavailable | conflicting | unknown
  corrected_ref: exact owner record/reference or null
  corrected_revision: exact hash/revision or null
  correction_kind: metadata | source | claim | scope | redaction | lifecycle |
                    supersession | tombstone | deletion | none
  before_after_refs: owner-supplied references or empty
  effective_generation: owner generation or unknown
  review_effect: unchanged | stale | re_review_required | unavailable
  external_copy_limits: bounded list
  limitations: bounded list
}
```

A proposed correction is not a correction. Only the existing source/lifecycle authority can confirm a canonical change, and `owner_response: confirmed` is permitted only when `issuer_ref`, `issuer_event_ref`, `response_revision`, and `verification_state: verified_against_owner` resolve against that existing authority. An `owner_ref` or participant-supplied label alone is never issuer authorization. Deletion, tombstoning, and supersession remain distinct from correction; M41 always distinguishes a correction from deletion. If the owner cannot verify a correction, the lineage remains proposed, conflicting, or unavailable rather than being promoted by M41.

### 3.3 `OwnerResponse`

```text
OwnerResponse {
  response_id: stable UUID
  target_ref: exact challenge/package/source/exchange reference
  issuer_ref: exact owner identity/reference or unknown
  issuer_event_ref: exact authoritative owner event or unavailable
  response_revision: exact owner response revision/hash or unknown
  verification_state: verified_against_owner | stated_unverified | unavailable |
                     conflicting | unknown
  response_kind: factual | correction_confirmed | correction_rejected |
                 lifecycle_update | request_information | unavailable
  effective_generation: owner generation or unknown
  supersedes: response ID or null
  limitations: bounded list
}
```

An `OwnerResponse` is owner-backed only when its issuer, authoritative event, response revision, and verification state resolve against the existing owner authority. A participant-supplied `owner_ref`, signature-like string, hash, model output, or displayed label is not authorization. Owner-backed responses are still scoped statements; they do not prove human identity beyond the declared authority, settle a dispute, or erase unmanaged copies.

### 3.4 `ExchangeClosure`

```text
ExchangeClosure {
  closure_id: stable UUID
  exchange_id: M40 exchange ID
  final_package_revision: exact hash/revision or unknown
  final_challenge_refs: ordered challenge IDs
  final_correction_refs: ordered lineage IDs
  state: open | answered | accepted_by_recipient | rejected_by_recipient |
         corrected | withdrawn | expired | revoked_before_handoff |
         closed_unresolved | unable_to_verify | reopened
  closure_scope: local_exchange | sender_local | recipient_local | owner_backed | unknown
  actor_ref: bounded stated/verified local reference or unknown
  issuer_ref: exact owner identity/reference or unknown
  issuer_event_ref: exact authoritative owner event or unavailable
  closure_revision: exact owner/local closure revision/hash or unknown
  verification_state: verified_against_owner | stated_unverified | unavailable |
                     conflicting | unknown
  reason: bounded structured reason
  unresolved_items: bounded list
  next_action: none | inspect | request_information | re_export | reopen |
               escalate_owner | unable_to_verify
  created_at: Date or null
  supersedes: closure ID or null
  limitations: bounded list
}
```

Closure is a workflow disposition over the exchange. It does not certify the evidence, settle a dispute, prove identity, delete copies, close an M33 incident, accept a policy, or grant a capability. Any changed package, owner generation, correction lineage, recipient scope, or unresolved critical limitation requires reopening or a new closure review.

### 3.4 User-visible sharing history projection

```text
SharingHistoryEntry {
  exchange_id: UUID
  package_id: UUID or unavailable
  package_revision: hash/revision or unknown
  recipient_ref: bounded reference or unknown
  consent_generation: UUID or unknown
  handoff_state: M40 state
  receipt_state: M40 state
  challenge_state: typed summary
  correction_state: proposed | confirmed | rejected | conflicting | none | unknown
  response_refs: exact OwnerResponse IDs or unavailable
  closure_ref: exact ExchangeClosure ID or unavailable
  closure_verification_state: verified_against_owner | stated_unverified | unavailable | conflicting | unknown
  closure_issuer_event_revision: exact binding reference or unavailable
  closure_state: M41 state
  stale_state: current | stale | re_review_required | unavailable
  local_copy_state: retained | deleted_local | quarantined | unknown
  external_copy_limits: bounded list
  owner_refs: exact refs or unavailable
  limitations: bounded list
}
```

The history view is a projection, not a second ledger. It must never show omitted raw content merely to make a timeline look complete. `response_refs`, `closure_ref`, and `closure_verification_state` must resolve before history may display an owner-backed response or closure; a summary label cannot launder an unverified state. Missing, stale, conflicted, and unavailable entries remain visible with their limitation and next action.

## 4. Operating rules

### 4.1 Challenge intake and preview

Before a challenge is submitted locally, the user sees:

```text
exchange/package/source reference
exact revision or unknown state
recipient/sender scope
challenge kind and bounded statement
included evidence references and redactions
requested outcome
privacy and external-copy limits
whether an owner or external transport is unavailable
cancel/edit/submit actions
```

A challenge is blocked when its target is unknown, scope is widened, it contains credential-shaped data or private content, it requests arbitrary tool/network action, or the user has not explicitly approved the local submission. The challenge body is untrusted data and cannot alter routing, permission, or authority.

### 4.2 Response and correction

Responses are classified as owner-backed, participant-stated, local observation, unavailable, conflicting, or unknown. An owner-backed response requires the `OwnerResponse` issuer/event/revision binding with `verification_state: verified_against_owner`; an `owner_ref` alone is never sufficient. A response can add information or references but cannot become canonical merely because it is signed, hash-linked, generated by a model, or displayed by a trusted-looking viewer. Owner-backed corrections must reference the original revision and new effective generation; the original remains inspectable according to its lifecycle and privacy rules. An `owner_backed` closure requires the same verified binding; otherwise closure remains local, stated-unverified, conflicting, or unavailable.

M41 distinguishes:

- **Challenge:** a question, objection, or request.
- **Correction proposal:** a requested or suggested changed state.
- **Owner-confirmed correction:** an existing authority supplies the new state.
- **Tombstone/deletion:** lifecycle owner makes content unavailable; this is not proof that all copies disappeared.
- **Supersession:** a new revision replaces an older one for a declared scope.
- **Unresolved disagreement:** participants still differ or the owner is unavailable.

### 4.3 Stale and re-review propagation

A challenge, response, review, or closure becomes stale or re-review-required when any bound package hash, source revision, owner generation, lifecycle state, validator/redaction profile, recipient scope, consent generation, or correction lineage changes. M41 may project the stale state and required next action; it cannot silently recompute a new truth or auto-close the prior record.

### 4.4 Closure and reopening

Closure requires explicit user confirmation of the exact closure scope, unresolved items, owner/recipient limitations, local versus owner-backed status, external-copy limits, and next action. A closure may use `closure_scope: owner_backed` only when its issuer/event/revision and `verification_state: verified_against_owner` resolve against the existing authority; otherwise it remains local, stated-unverified, conflicting, or unavailable. `closed_unresolved` is a valid and often safer result than pretending agreement. Reopening creates a new closure revision or supersedes the old local disposition; it does not erase the historical closure.

### 4.5 Offline and browser-first behavior

When the owner, receipt, viewer, Keychain, file permission, or network is unavailable, M41 preserves a local draft or displays an explicit unavailable state. It never retries indefinitely, chooses a transport, or implies that queued local state was delivered. Users can continue navigation, tabs, private mode, and ordinary browser inspection with challenge/history/closure surfaces unavailable or disabled.

## 5. Work packages

### M41-A — Challenge intake and bounded feedback

Define `EvidenceChallenge`, challenge kinds/states, exact exchange/package/source binding, preview/redaction rules, explicit local submission, privacy limits, and untrusted-content fencing.

**Done when:** a challenge cannot widen scope, invoke tools, mutate authority, expose secrets, or be submitted without explicit local user action; challenge state and owner availability remain distinct.

### M41-B — Correction lineage and owner response

Define `CorrectionLineage`, before/after references, issuer/event/revision verification against the existing owner, proposed versus owner-confirmed correction, rejection/conflict/unavailable states, correction versus deletion/tombstone/supersession, and existing Honeycomb/M35 owner handoffs.

**Done when:** original state remains traceable; M41 never promotes a proposed or model-generated correction; only the existing owner can confirm canonical state.

### M41-C — Stale propagation and re-review continuity

Define invalidation across M38 package findings, M39 lifecycle/review, M40 consent/receipt, M37 notices, owner generations, validator/redaction profiles, and correction lineage. Define changed-byte, changed-scope, and unavailable-authority behavior.

**Done when:** stale/re-review-required states cannot look current; prior review/closure is preserved and the next required action is visible.

### M41-D — Exchange closure and user-visible sharing history

Define `ExchangeClosure`, closure scope/reasons, unresolved/answered/corrected/withdrawn/reopened states, explicit closure confirmation, history projection with direct `OwnerResponse`/`ExchangeClosure` references and verification state, bounded owner references, and no-second-ledger reconciliation with EventLedger.

**Done when:** closure is explicit, replay-safe, and honest about unresolved items; owner-backed closure requires verified issuer/event/revision binding; history shows consent, handoff, receipt, challenge, correction, stale, and closure state without becoming a new evidence authority.

### M41-E — Conflict, accessibility, privacy, and browser-first validation

Define duplicate/conflicting/replayed challenge and response handling, inert rendering, no-network/no-tool behavior, keyboard/VoiceOver/status/error/confirmation semantics, offline/private/locked/denied/manual states, and browser-first fallback.

**Done when:** malformed or adversarial feedback cannot mutate state; accessible local history remains understandable; ordinary browsing remains usable with M41 unavailable or disabled.

## 6. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M41-01 | Challenge preview with exact package hash | Scope, revision, kind, statement, redaction, and limits visible |
| M41-02 | Challenge denied | No local submission; denial remains local |
| M41-03 | Challenge target unavailable | Unable-to-verify; no invented source |
| M41-04 | Inquiry challenge | Inquiry state; no correction claim |
| M41-05 | Contradiction challenge | Contradiction recorded; source unchanged |
| M41-06 | Correction request | Proposed correction only |
| M41-07 | Source-correction request | Owner review required |
| M41-08 | Stale-evidence challenge | Re-review requested; no current claim |
| M41-09 | Withdrawal challenge | Withdrawal request; no automatic deletion |
| M41-10 | Security concern | M33 reference/escalation option; no auto-submit |
| M41-11 | Privacy concern | Bounded local concern; no raw secret echo |
| M41-12 | Scope-error challenge | Scope mismatch; handoff/review hold |
| M41-13 | Challenge contains prompt injection | Content inert; no tool/model authority |
| M41-14 | Challenge contains credential-shaped data | Redacted/rejected; no echo |
| M41-15 | Challenge widens recipient scope | Blocked; new consent required |
| M41-16 | Duplicate challenge same bytes | Idempotent local observation |
| M41-17 | Duplicate challenge different bytes | Conflict/quarantine; no replacement |
| M41-18 | Replayed old challenge | Stale; no current-state mutation |
| M41-19 | Recipient spoofing in challenge | Identity remains unverified; no trust claim |
| M41-20 | Owner acknowledges locally | Acknowledged-local only |
| M41-21 | Owner response unavailable | Unavailable; no silence-as-acceptance |
| M41-22 | Participant response stated | Participant-stated; not canonical |
| M41-23 | Model-generated answer | Advisory/untrusted; not owner response |
| M41-24 | Owner confirms correction with verified issuer/event/revision | New owner revision linked to original |
| M41-25 | Owner label without authoritative event or owner rejects correction | Stated-unverified or rejected proposal; original remains governed |
| M41-26 | Conflicting or spoofed owner references/issuer events | Conflicting/unable-to-verify; no winner inference or confirmed correction |
| M41-27 | Correction changes metadata only | Metadata lineage; content unchanged |
| M41-28 | Correction changes source content | Owner revision required; old state retained per lifecycle |
| M41-29 | Correction is actually deletion | Tombstone/deletion state, not correction |
| M41-30 | Correction is supersession | Superseded state with exact replacement reference |
| M41-31 | Package hash changes | M38 review and M40 receipt stale |
| M41-32 | Owner generation changes | Re-review required |
| M41-33 | Lifecycle becomes revoked | Exchange/closure limitation visible; no copy erasure claim |
| M41-34 | Redaction profile changes | New review/consent required |
| M41-35 | Validator profile changes | Prior validation/review stale |
| M41-36 | Recipient scope changes | Existing challenge/closure invalidated |
| M41-37 | Consent generation changes | New exchange decision required |
| M41-38 | Closure while challenge open | Blocked or closed-unresolved with warning |
| M41-39 | Explicit answered closure | Local closure only; answer provenance visible |
| M41-40 | Explicit corrected closure | Owner correction reference required |
| M41-41 | Recipient rejects response | Rejected-by-recipient; disagreement remains |
| M41-42 | Recipient accepts response | Accepted-by-recipient; no truth certification |
| M41-43 | Exchange closed unresolved | Unresolved items and next action remain visible |
| M41-44 | Exchange withdrawn | Withdrawal state; copied-data limitation visible |
| M41-45 | Closed exchange reopened | New closure revision; prior closure preserved |
| M41-46 | Sharing history missing owner/response/closure reference | Missing/unavailable entry visible; no owner-backed display |
| M41-47 | Sharing history owner-backed label lacks verified binding | Stated-unverified; no owner-backed display |
| M41-48 | Sharing history contains raw secret | Omitted/redacted; no secret display |
| M41-49 | VoiceOver/large text/reduced motion or offline/private/disabled | Status, scope, errors, actions, draft/unavailable state, and browsing remain understandable |
| M41-50 | Final closure review | Exchange, consent, receipt, challenges, lineage, verified response/closure references, unresolved items, scope, limits, and next action present |

## 7. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M41-A | Challenge bounds | Challenge is exact-scope, user-submitted, inert, and cannot mutate authority |
| M41-B | Untrusted feedback | Page/package/recipient/model content cannot submit, approve, route, or resolve a challenge |
| M41-C | Correction lineage | Proposed, owner-confirmed, rejected, conflicting, unavailable, superseded, tombstoned, and deleted states remain distinct |
| M41-D | Append-only history | Original state is retained/referenced; correction and closure append rather than rewrite history |
| M41-E | Owner authority | Only an issuer/event/revision binding verified against the existing source/lifecycle owner can confirm canonical correction or deletion; an owner_ref alone is not authorization |
| M41-F | Response honesty | Owner-backed, participant-stated, local, unavailable, conflicting, and unknown responses are distinct; silence is not acceptance |
| M41-G | Re-review continuity | Hash, generation, lifecycle, scope, consent, validator, redaction, or lineage changes stale affected review/receipt/closure |
| M41-H | Closure honesty | Closure is explicit workflow disposition, not truth, trust, incident closure, consent, legal finality, or capability grant; owner_backed requires verified issuer/event/revision binding |
| M41-I | Replay/conflict safety | Duplicate same-byte records are idempotent; conflicting/replayed records are quarantined or stale and cannot replace state |
| M41-J | History authority | Sharing history is a projection over EventLedger/M38–M40; response_refs/closure_ref and verification state must resolve before owner-backed display, and history does not create a second ledger or evidence store |
| M41-K | Accessibility/privacy/fallback | Errors, statuses, confirmation, privacy limits, offline/locked/denied/private states remain understandable and local |
| M41-L | Browser-first/no false readiness | M41 failure does not block browsing; challenge/correction/closure is not certification, collaboration, or ship evidence |

## 8. Safety, privacy, and claim boundaries

M41 is a challenge and workflow-disposition boundary, not a reason to retain raw conversations. Local metadata contains only exchange/package/source IDs, exact revisions/hashes, typed states, bounded redacted statements or summaries, owner references, review/closure generations, limitations, and next actions. Raw page text, screenshots, prompts, credentials, private memory, connector bodies, and unrestricted recipient messages are not required.

A challenge cannot correct itself, a response cannot establish its own authority, a model cannot become an owner, and a closure cannot prove truth. Owner-confirmed state requires an issuer/event/revision binding verified against the existing owner authority; an `owner_ref` string is not authorization. A hash, signature, nonce, or domain-bound challenge may support a scoped integrity check but does not establish human identity, legal finality, correctness, or universal revocation. SLSA/in-toto concepts remain build/provenance concepts and do not settle semantic disputes about user evidence.

Correction, deletion, tombstoning, supersession, withdrawal, and external-copy limitation are separate states; M41 explicitly distinguishes correction from deletion. Owner-backed responses and closures require verified issuer/event/revision bindings; an owner_ref alone is not authorization. An owner-confirmed correction can make affected reviews stale; it cannot guarantee that already exported copies changed. A local closure cannot close an M33 incident or erase recipient data. `closed_unresolved` and `unable_to_verify` are truthful outcomes, not failures to hide.

M41 must never be described as neutral dispute resolution, legal evidence adjudication, verified human identity, cryptographic attestation, universal correction propagation, secure deletion, incident closure, accessibility conformance, compliance certification, or production readiness.

## 9. Execution order and handoff

Implement M41-A as documentation and fixture-contract reconciliation against M33, M38, M39, M40, EventLedger, and Honeycomb/source owners before adding any feedback UI. Implement M41-B with synthetic owner revisions, fake responses, and deterministic before/after references; never use production source content, credentials, private memory, or real recipient data. Implement M41-C with synthetic generation/hash/profile changes and stale transitions. Implement M41-D with local fake closure states and history projections, without creating a second ledger. Implement M41-E with network-denied, private, locked, permission-denied, script-disabled, accessibility-manual, and browser-disabled states.

The next smallest safe action is **M41-A: publish the `EvidenceChallenge`, `CorrectionLineage`, and `ExchangeClosure` contracts plus the challenge/response/closure state matrix, then reconcile them with M33 operations, M35 lifecycle, M37 re-review, M38 package validation, M39 lifecycle/disposition, M40 consent/receipts, EventLedger, Honeycomb/source owners, and browser/session authorities**. Do not add automatic correction/deletion, a dispute service, a second ledger, universal propagation, model adjudication, remote transport, or runtime implementation as part of M41 planning.
