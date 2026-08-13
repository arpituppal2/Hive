# M43 — Evidence Lineage Discovery & Notification Continuity Execution Plan

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M43 Evidence Lineage Discovery & Notification Continuity
> **Depends on:** M0–M6 storage/provenance/recovery; M10–M17 browser/context/action/worker boundaries; M25 engine/update ownership; M26 ownership/policy; M27 sync/device/epoch state; M28 Flow authority; M29 context governance; M31 portability/extensibility; M32 release receipts/distribution/recovery; M33 operations/vulnerability response/trust feedback; M34 TrustSnapshot/control plane; M35 evidence/policy lifecycle governance; M36 reproducible evidence/recovery rehearsal; M37 user-visible change/deprecation/support horizon; M38 offline evidence traceability/audit package; M39 evidence package lifecycle/human disposition; M40 consent-bound evidence exchange/recipient review; M41 evidence challenge/correction/exchange closure; M42 post-closure re-export/history lifecycle.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities:** M31 portability/omission/quarantine; M35 lifecycle/generation/tombstones; M37 notice/review/re-review semantics; M38 package/traceability; M39 disposition/viewer states; M40 recipient/receipt/copy limits; M41 verified correction/response/closure/history; M42 re-export/tombstone/conflict/compaction; M33 trust feedback and operational boundaries; EventLedger/Honeycomb as existing authorities; Apple UserNotifications and file-sharing limits; W3C WCAG status/error/confirmation guidance; NIST audit/change/accountability concepts; OWASP untrusted notice/content handling; SQLite history/index constraints; SLSA/in-toto provenance/supersession limits.
>
> M43 defines local discovery of evidence lineage across M40–M42 exchanges and the creation of inert, scope-bound continuity notices when a corrected, superseded, revoked, or otherwise changed package may require re-review. A notice can be inspected, exported through an explicit user action, acknowledged locally, deferred, or marked unavailable. It cannot transmit itself, prove delivery, grant consent, mutate a source, or create a hidden recipient-tracking registry.

## 0. Decision summary

The smallest safe M43 architecture is:

```text
M41/M42 verified lineage + local sharing history
  → bounded affected-exchange discovery
    → user-visible continuity notice with exact scope/revision/owner state
      → local review/defer/acknowledge/re-review decision
        → optional explicit user-chosen export/handoff of the notice
          → bounded local compaction and browser-first fallback
```

| Slice | User value | Hard boundary |
|---|---|---|
| **N1 — Lineage discovery** | Find which local exchanges and packages are affected by a verified change | Discovery searches local retained references; it does not infer recipients or scan unmanaged copies |
| **N2 — Continuity notice** | Explain that a prior package may be stale, superseded, revoked, or corrected | A notice is a projection, not delivery, truth certification, or a new authority |
| **N3 — Re-review continuity** | Preserve the relationship between notice, prior review, current package, and next action | Acknowledgement means local review only; it never grants consent or proves receipt |
| **N4 — Notification limits** | Make offline, denied, missing, and transport-unavailable states honest | No remote push, recipient tracking, or guaranteed delivery is introduced |
| **N5 — Bounded history** | Keep lineage and review useful without retaining raw content forever | Compaction is owner-scoped and must preserve required lineage/tombstones/limitations |

M43 does **not** claim remote notification, recipient discovery outside retained local references, delivery/read receipts, universal correction propagation, guaranteed re-review, automatic re-export, hidden recipient analytics, or production readiness.

## 1. Current truth and authority boundaries

### 1.1 Existing surfaces

M43 is an M37-owned notice/review projection. It does not create a parallel notice authority, notice store, recipient registry, or delivery ledger.

| Surface | Current truth | M43 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| M37 notices/review | Change notices, acknowledgement, generation binding, stale/re-review semantics, and browser fallback are defined | Notice vocabulary and review invalidation | M43 cannot create a second notice authority or mark a notice delivered |
| M40 exchange | Intended recipient, scope, consent, handoff, receipt, and copy limits are defined | Prior exchange and local receipt references | A recipient reference is not a live contact or delivery channel |
| M41 correction/closure | Verified owner responses/corrections/closures and history references are defined | Affected lineage and re-review trigger | Participant state cannot create an affected recipient set |
| M42 re-export/history | New export identity, predecessor binding, tombstones, compaction, and conflict projection are defined | Current/superseding package relation and local history lifecycle | M43 cannot auto-re-export or alter M42 history |
| M33 operations | Trust feedback, privacy, security, accessibility, and case boundaries are defined | Optional bounded escalation reference | M43 cannot submit, notify, or close an operational case |
| EventLedger | Append-only local consequential-event authority | Record bounded notice/review references where owner permits | M43 cannot create a recipient/notice ledger |
| Honeycomb/source owner | Canonical source/claim/revision authority | Resolve exact owner lineage | M43 cannot infer or change source truth |
| Apple notifications/files | Platform notification authorization and file/share boundaries | Report local notification availability and explicit export | Platform delivery is not a proof of human reading or recipient receipt |
| Browser shell | Navigation, tabs, private mode, local inspection remain the wedge | Notice/history fallback | M43 cannot block ordinary browsing |

**Current implementation classification:** M37 defines a general change-notice contract and M40–M42 define exchange, correction, closure, re-export, and history contracts, but no verified affected-lineage discovery, continuity-notice envelope, local notice acknowledgement bound to exchange/review, or notification-limitation matrix exists. M43 remains planning-only until fresh implementation and runtime evidence exist.

### 1.2 Authority matrix

| Concern | Existing authority | M43 rule |
|---|---|---|
| Notice schema/review | M37 | Reuse M37 notice/review semantics; do not create a second notice store |
| Affected lineage | M41/M42 verified references and local history | Resolve exact retained IDs/generations; unknown remains unknown |
| Canonical source/change | Honeycomb/source owner | Notice may reference owner state; cannot create it |
| Export/handoff | M31/M40/M42 | User explicitly exports a notice/package; M43 never chooses transport |
| Local event evidence | EventLedger | Store bounded notice/review references under existing authority |
| Notification delivery | Apple/local platform and user-selected transport | Report requested/queued/local-presented/unavailable; never infer reading |
| Recipient identity | M40 stated/verified semantics | Do not discover or infer a current recipient from old metadata |
| Retention/compaction | M35/M39/M42 | Preserve lineage and review invalidation references; compact only within owner scope |
| Privacy | M29/M33/M35/M40/M42 | No hidden recipient graph, raw content, or engagement telemetry |
| Browser fallback | Browser/session owner | Navigation, tabs, private mode, and inspection continue without M43 |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A versioned `LineageDiscovery` projection resolving local retained exchange/package/history entries affected by a verified M41/M42 correction, supersession, revocation, expiry, privacy redaction, or validator/redaction change.
2. Exact matching inputs: predecessor package/revision, correction/response/closure reference, owner generation, re-export binding, lifecycle state, recipient reference as originally recorded, and local retention availability.
3. Discovery results distinguishing affected-local, possibly-affected, stale-reference, owner-unavailable, recipient-unknown, unmanaged-copy-unknown, and no-retained-match. Discovery never claims a complete recipient set.
4. An M37-owned `ContinuityNotice` projection containing the M37 notice ID/owner reference and revision, triggering owner/reference state, affected local exchange/history IDs, exact package/revision scope, required action, limitations, provenance, expiration/review bound, and explicit non-delivery language. M43 does not create a parallel notice authority or notice store.
5. Notice actions: view, inspect-lineage, acknowledge-local, defer, dismiss-if-allowed, request-re-review, export-notice, re-export-package-through-M42, escalate-owner, and unable-to-verify. No action silently sends or changes canonical state.
6. A `NoticeReviewBinding` bound to notice revision, affected scope, owner generation, package/revision, local exchange/history entry, user action, and next action. Old acknowledgement becomes stale when any binding changes.
7. Notification state semantics distinguishing not-requested, local-queued, local-presented, export-ready, user-handed-off, delivery-unknown, recipient-read-unknown, unavailable, denied, expired, withdrawn, and stale. Local presentation is not human receipt. Delivery state is bound to the exact M37 notice revision, affected scope, and owner generation.
8. Explicit transport neutrality: local notification and user-selected export/share are separate categories with separate consent, retention, cancellation, and failure states. M43 does not implement push, email, relay, cloud inbox, or recipient synchronization.
9. Privacy bounds prohibiting inference of current recipient identity, contact lookup, address-book enrichment, hidden recipient graph construction, raw package content in notice text, secret/credential/page-text inclusion, and engagement tracking.
10. Lineage compaction rules preserving predecessor/current package references, owner generations, re-review invalidation, tombstones, deletion receipts, notice revision, and unresolved/unavailable limitations; compaction cannot make an affected state look unaffected.
11. Accessible notice/review/fallback behavior: keyboard, VoiceOver, large text, contrast, reduced motion, status announcements, text error identification, confirmation for consequential local actions, and color-independent state meaning.
12. Browser-first fallback for offline, private profile, locked Keychain, denied notification/file access, absent viewer, unavailable owner, missing history, unavailable local event authority, and M43-disabled mode.
13. Synthetic adversarial fixtures for notice spoofing, correction laundering, recipient inference, prompt injection, stale acknowledgement, replayed notice, scope widening, secret inclusion, delivery overclaim, and hidden telemetry.
14. Minimal local metadata only: IDs, exact hashes/revisions, owner references, typed notice/review/delivery states, bounded redacted summaries, limitations, and next actions. Raw page text, screenshots, prompts, credentials, private memory, connector bodies, and contact data are not required.

### 2.2 Explicit non-goals

- Remote notification service, APNs/push implementation, email/relay/inbox integration, address-book/contact lookup, recipient discovery, or cross-device acknowledgement synchronization.
- Automatic re-export, automatic correction propagation, automatic recipient notification, automatic source mutation, or model-selected affected recipients.
- A second notice, recipient, delivery, acknowledgement, EventLedger, Honeycomb, provenance, policy, retention, or analytics store.
- Claiming that local presentation, export, handoff, platform notification, or receipt proves delivery, reading, identity, consent, correction adoption, or re-review.
- Universal correction propagation or recall of packages/copies in transport systems, backups, email, cloud storage, removable media, screenshots, or other devices.
- Engagement scoring, notification optimization, behavioral profiling, hidden tracking, or contact enrichment.
- Legal/compliance notification, guaranteed response/re-review SLA, public advisory feed, neutral arbitration, or incident closure.
- Arbitrary notice HTML/JavaScript execution, shell/tool invocation, URL fetching, model-controlled transport, or untrusted notice-driven action.
- Runtime implementation, UI implementation, notification entitlements, transport configuration, signing-key changes, model training, telemetry, credentials, release configuration, or Swift source edits in this planning milestone.

## 3. Lineage and notice contracts

### 3.1 `LineageDiscovery`

```text
LineageDiscovery {
  discovery_id: stable UUID
  schema_version: semantic version
  trigger_ref: verified M41 correction/response/closure or M42 binding/lifecycle ref
  trigger_verification: verified_against_owner | stated_unverified | stale |
                       conflicting | unavailable | unknown
  predecessor_refs: exact local package/exchange/history IDs or empty
  current_refs: exact local package/exchange/history IDs or empty
  owner_generations: exact map or unknown
  affected_local_state: affected | possibly_affected | no_retained_match |
                        stale_reference | owner_unavailable | recipient_unknown |
                        unmanaged_copy_unknown | quarantined | unavailable
  match_basis: exact_revision | supersession_ref | owner_generation |
               lifecycle_state | correction_ref | bounded_projection | none
  recipient_scope: original bounded reference or unknown
  complete_recipient_set: never_claimed
  generated_at: authoritative Date or null
  retention_state: retained | compacted | tombstoned | deleted_local | unknown
  limitations: bounded list
  next_action: inspect | review | re_export | export_notice | obtain_owner_state |
               unable_to_verify | none
}
```

Discovery can only resolve retained local references and exact owner-supplied relations. It cannot infer that an old recipient still has a copy, discover an address, query a remote service, or claim that no unmanaged recipient exists. `possibly_affected`, `recipient_unknown`, and `unmanaged_copy_unknown` are first-class outcomes.

### 3.2 `ContinuityNotice` — M37-owned projection

```text
ContinuityNotice {
  m37_notice_id: exact M37 notice ID or unavailable
  m37_owner_ref: exact M37 authority/reference or unavailable
  notice_id: stable local projection UUID
  notice_revision: exact M37/projection revision/hash
  trigger_ref: exact verified owner/M41/M42 reference or unavailable
  trigger_verification: verified_against_owner | stated_unverified | stale |
                         conflicting | unavailable | unknown
  notice_kind: corrected | superseded | revoked | expired | redacted |
               validator_changed | scope_changed | re_review_required | unavailable
  affected_local_refs: exact discovery/exchange/history IDs or empty
  package_scope: exact package/revision scope or unknown
  affected_owner_generation: exact generation or unknown
  required_action: inspect | re_review | fresh_consent | re_export |
                   obtain_owner_state | acknowledge_only | none | unavailable
  action_authority: informational_only | verified_owner_action | unavailable
  data_classes: allowlisted category summary
  content_policy: metadata_only | redacted_summary | no_content
  delivery_state: not_requested | local_queued | local_presented |
                  export_ready | user_handed_off | delivery_unknown |
                  recipient_read_unknown | unavailable | denied | expired |
                  withdrawn | stale
  acknowledgement_state: not_requested | acknowledged_local | deferred |
                         dismissed_allowed | stale | unavailable
  expires_at: authoritative Date or null
  limitations: bounded list
  next_action: inspect | review | re_export | export_notice | escalate_owner |
               unable_to_verify | none
}
```

A notice describes a bounded change or limitation. It is an M37-owned projection, not a parallel notice authority. It does not assert that a recipient saw it, owns the current package, accepted the correction, or completed re-review. Notice text is inert untrusted data and cannot choose a transport, invoke a tool, widen scope, or mark itself acknowledged. If `trigger_verification` is not `verified_against_owner`, `action_authority` must be `informational_only` and `required_action` is limited to `inspect`, `acknowledge_only`, `none`, or `unavailable`; `re_review`, `fresh_consent`, `re_export`, and other blocking/authority-affecting actions require verified owner authority.

### 3.3 `NoticeReviewBinding`

```text
NoticeReviewBinding {
  review_id: stable UUID
  notice_id: UUID
  notice_revision: exact revision/hash
  affected_refs: exact local references
  package_revision: exact hash/revision or unknown
  owner_generation: exact generation or unknown
  scope: typed local/profile/workspace scope
  state: viewed | acknowledged_local | deferred | dismissed_allowed |
         stale | re_review_required | blocked | unavailable
  user_action: inspect | acknowledge | defer | dismiss | re_review |
               export_notice | request_owner_state | none
  acknowledged_at: Date or null
  delivery_not_proven: true
  recipient_read_not_proven: true
  next_action: none | inspect | re_review | fresh_consent | obtain_owner_state |
               export_notice | unable_to_verify
  limitations: bounded list
}
```

A local acknowledgement means the user reviewed the displayed notice and next action. It is not consent to a new capability, proof of delivery to a recipient, evidence that a correction was adopted, or re-review completion. Any notice revision, affected scope, package revision, owner generation, required action, or authoritative limitation change makes the binding stale.

### 3.4 Notification and transport boundary

```text
ContinuityDeliveryReceipt {
  receipt_id: stable UUID
  notice_id: UUID
  m37_notice_id: exact M37 notice ID or unavailable
  notice_revision: exact notice/projection revision/hash
  affected_scope_hash: exact bounded affected-reference hash or unknown
  owner_generation: exact generation or unknown
  idempotency_key: stable local key
  replay_state: first_seen | duplicate_same_bytes | conflicting_bytes | stale | quarantined
  transport_kind: local_notification | local_file | share_sheet | user_selected_other |
                  none | unknown
  authorization_state: authorized | denied | unavailable | not_requested | unknown
  local_state: queued | presented | exported | handed_off | failed | cancelled | unknown
  recipient_ref: original bounded reference or null
  delivery_state: delivery_unknown | recipient_read_unknown | unavailable | not_applicable
  created_at: Date or null
  external_copy_limits: bounded list
  limitations: bounded list
}
```

`ContinuityDeliveryReceipt` is a local/platform observation or user handoff record bound to one exact notice revision, affected scope, owner generation, and idempotency key. Duplicate identical bytes are idempotent; conflicting or stale receipts are quarantined and cannot attach to a newer notice. It never proves a remote recipient read the notice. `local_notification` and `user_selected_other` remain separate consent categories, and an old M40 consent cannot authorize either one; fresh-consent is required for a new transport or export.

## 4. Operating rules

### 4.1 Affected-lineage discovery

Discovery begins from an exact verified M41/M42 trigger or an explicit user-selected local history entry. It evaluates predecessor/current revisions, owner generations, lifecycle/tombstone state, validator/redaction profile, local retention, and direct references. It does not scrape contacts, infer current recipients, scan external locations, or search unmanaged copies. Missing local history yields `no_retained_match`, `recipient_unknown`, `unmanaged_copy_unknown`, or `unavailable`, never “no one is affected.”

### 4.2 Notice preview and actions

Before any acknowledgement, export, or re-review action, the user sees:

```text
what changed or is unavailable
exact trigger and owner verification state
affected local exchanges/history entries
package/revision/scope/generation
what is omitted
required action and why
transport/delivery/read limitations
expiry and deletion limits
cancel/defer/inspect path
```

A notice cannot approve itself. A model, page, connector, imported package, old receipt, recipient message, or stale history entry cannot create a blocking notice, select a recipient, change required action, or mark acknowledgement complete.

### 4.3 Re-review continuity

If a verified change affects a locally retained package or review, M43 creates a `re_review_required` projection bound to the changed notice/package/generation. It does not automatically open a package, re-export, send a message, or alter a task/source. M37/M39/M42 remain authoritative for review, package lifecycle, and re-export state.

### 4.4 Offline and delivery limits

Offline mode can create a local notice, queue a local presentation, preserve a draft, or show unavailable. It cannot infer delivery or schedule an unbounded retry. Notification authorization denial yields an in-app/browser-first status surface; it does not repeatedly prompt. A platform “presented” callback is not recipient reading. A user-selected file/share handoff is explicit and remains transport-controlled by the user.

### 4.5 Retention and compaction

Notice and review metadata compact only under M35/M39/M42 retention/deletion authority. Compaction preserves notice revision, affected references, owner generation, stale/re-review state, tombstones, deletion receipts, delivery/read limitations, and next action. It cannot turn a missing affected-reference set into “no impact,” erase required lineage, or create a second recipient graph.

## 5. Work packages

### M43-A — Local lineage discovery and affected-reference mapping

Define `LineageDiscovery`, exact trigger verification, predecessor/current matching, owner-generation/lifecycle evaluation, retained-local scope, recipient-unknown/unmanaged-copy-unknown states, and no-contact-inference rules.

**Done when:** discovery resolves only exact retained local references; it never claims a complete affected recipient set or searches unmanaged copies.

### M43-B — Continuity notice and required-action semantics

Define the M37-owned `ContinuityNotice` projection, M37 owner/revision references, corrected/superseded/revoked/expired/redacted/validator/scope/re-review/unavailable kinds, metadata-only content policy, provenance, required action, verified-owner action authority, expiry, and inert rendering.

**Done when:** notice state is traceable to an exact M37 owner/projection and trigger/lifecycle state; unverified triggers are informational-only and cannot produce blocking actions; no notice can alter authority, select transport, or present as delivery/read proof.

### M43-C — Acknowledgement and re-review continuity

Define `NoticeReviewBinding`, stale invalidation, local acknowledgement/defer/dismiss rules, M37/M39/M42 re-review handoffs, explicit fresh-consent boundaries, and accessibility of status/action/confirmation flows.

**Done when:** acknowledgement means local review only; changed notice/scope/revision/generation/action invalidates it; no old consent or acknowledgement becomes a new grant.

### M43-D — Delivery limits and transport fallback

Define `ContinuityDeliveryReceipt`, exact M37 notice revision/scope/generation binding, idempotency/replay handling, local notification/share/export categories, authorization/denial/queued/presented/handoff/unavailable states, cancellation, no-unbounded-retry, no-recipient-read proof, and browser-first fallback.

**Done when:** every delivery state states what Hive observed and what it cannot know; stale/conflicting receipts cannot attach to a newer notice; no remote transport, recipient registry, or automatic notification exists.

### M43-E — Retention, compaction, privacy, and adversarial validation

Define bounded metadata retention/compaction, tombstone/lineage preservation, hidden-recipient-graph prohibition, secret/raw-content redaction, prompt-injection/path/script safety, offline/private/locked/denied/accessibility states, and M43-disabled browser behavior.

**Done when:** compaction never erases required re-review/lineage limits or creates “no impact” from missing data; untrusted notices remain inert; ordinary browsing remains usable.

## 6. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M43-01 | Verified owner correction affects retained package | Affected-local discovery; re-review notice |
| M43-02 | Correction has unverified issuer/event | Informational-only/unavailable; no blocking action or affected truth claim |
| M43-03 | Superseding re-export references predecessor | Exact lineage match; notice scope visible |
| M43-04 | Revoked package with retained history | Revoked notice; no recipient-copy claim |
| M43-05 | Expired package with no owner state | Unknown/stale; not “no impact” |
| M43-06 | Validator profile changes | Re-review required |
| M43-07 | Redaction profile changes | Fresh review/consent required |
| M43-08 | Local history compacted | Retained references/tombstone visible; impact bounded |
| M43-09 | No retained local match | No-retained-match; unmanaged copies unknown |
| M43-10 | Recipient reference is old/unverified | Recipient-unknown; no contact inference |
| M43-11 | Old M40 consent present | Does not authorize notice transport or re-export |
| M43-12 | Notice preview exact scope | Trigger, owner state, refs, limits, action visible |
| M43-13 | Notice body contains prompt injection | Inert; no action/transport change |
| M43-14 | Notice contains credential-shaped text | Omitted/redacted; no echo |
| M43-15 | Notice missing provenance | Unverified informational-only; not a blocking directive |
| M43-16 | Unverified trigger requests re-export | Blocked; informational-only notice cannot require authority-affecting action |

| M43-17 | Notice revision changes required action | Prior review stale |
| M43-18 | Owner generation changes | Re-review required; acknowledgement stale |
| M43-19 | Affected package changes hash | Review/notice binding invalidated |
| M43-20 | Scope widens in notice | Blocked; fresh consent/review required |
| M43-21 | Notice expires | Expired/unavailable; no hidden completion |
| M43-22 | Local acknowledgement | Acknowledged-local only; no recipient-read proof |
| M43-23 | User defers notice | Deferred; remains discoverable |
| M43-24 | Allowed dismissal | Dismissed-allowed; blocking notice remains discoverable |
| M43-25 | Security/review notice dismissal | Cannot permanently suppress; reappears when stale/effective |
| M43-26 | Local notification denied | In-app/browser fallback; no repeat prompt loop |
| M43-27 | Local notification queued offline | Queued-local; delivery not inferred |
| M43-28 | Local notification presented | Local-presented; human reading not inferred |
| M43-29 | User exports notice file | Export-ready/handed-off only; transport limits visible |
| M43-30 | User-selected share path | Explicit handoff; no remote delivery claim |
| M43-31 | Notification cancelled | Cancelled; no acknowledgement claim |
| M43-32 | Recipient read requested | Recipient-read-unknown; no proof |
| M43-33 | Delivery retry requested offline | Bounded/manual retry; no unbounded scheduler |
| M43-34 | Notice transport payload contains raw package or requests address-book/contact lookup | Blocked/redacted/rejected; no raw export or recipient enrichment |
| M43-35 | Current recipient differs from old reference | Recipient-unknown; no automatic remap |
| M43-36 | History contains external-copy-only evidence | Unmanaged-copy-unknown; no affected-set completion |
| M43-37 | M42 tombstone lacks required lineage | Quarantined/unavailable; no “no impact” result |
| M43-38 | Compaction interrupts notice metadata | Partial/needs-reconcile; no false completion |
| M43-39 | Compaction removes stale review reference | Blocked; required lineage preservation fails |
| M43-40 | Compaction of unresolved recipient conflict | Conflict preserved; no consensus |
| M43-41 | Notice includes HTML/script | Inert text; no execution |
| M43-42 | Notice path traversal metadata | Rejected before use |
| M43-43 | Owner reference spoofed | Stated-unverified; no blocking action |
| M43-44 | Model proposes affected recipients | Advisory only; no recipient selection |
| M43-45 | Private profile notice | Excluded or explicit synthetic/non-content scope |
| M43-46 | Locked Keychain/file access denied | Unavailable/manual state; no bypass |
| M43-47 | VoiceOver/large text/high contrast | Status, refs, limits, and actions understandable |
| M43-48 | Reduced motion/offline | Static local notice/review usable |
| M43-49 | M43 disabled/history unavailable | Navigation, tabs, private mode, and inspection unaffected |
| M43-50 | Final continuity review | Trigger, lineage, affected-local limits, notice, review, delivery limits, retention, and next action present |

## 7. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M43-A | Exact lineage discovery | Discovery uses verified references/generations and retained local IDs; no inferred recipient set |
| M43-B | Affected-set honesty | No-retained-match, recipient-unknown, unmanaged-copy-unknown, stale, and unavailable remain distinct |
| M43-C | Notice authority | Notice maps to an existing owner/M41/M42 trigger; unverified text cannot create a blocking directive |
| M43-D | Required-action integrity | Inspect/re-review/fresh-consent/re-export actions are explicit and cannot be chosen by notice content/model |
| M43-E | Acknowledgement honesty | Local acknowledgement is not delivery, reading, consent, correction adoption, or completed re-review |
| M43-F | Stale invalidation | Notice revision, affected scope, package revision, owner generation, action, or limitation change makes old review stale; delivery receipts bind the same revision/scope/generation |
| M43-G | Transport neutrality | Local notification and user-selected export/share are separate; no remote service or recipient registry exists |
| M43-H | Delivery honesty | Queued/presented/exported/handoff states never imply recipient delivery or reading; stale/conflicting receipts are replay-safe and cannot attach to a newer notice |
| M43-I | Privacy boundary | No contact lookup, current-recipient inference, hidden graph, raw package, secret, or engagement telemetry |
| M43-J | Retention/compaction safety | Required lineage, tombstones, deletion receipts, stale/re-review limits, and next actions survive compaction |
| M43-K | Accessibility/offline/fallback | Status/errors/confirmation/private/locked/denied/offline/manual states remain understandable and local |
| M43-L | Browser-first/no false readiness | M43 failure does not block browsing; notice is not consent, delivery, certification, or ship evidence |

## 8. Safety, privacy, and claim boundaries

M43 is an M37-owned local lineage and continuity-notice projection, not a parallel notice authority or a reason to retain more content. Local metadata contains only notice/discovery/review/delivery IDs, exact hashes/revisions, owner references, lifecycle/generation state, bounded affected local references, data-class summaries, limitations, and next actions. Raw package contents, page text, screenshots, prompts, credentials, private memory, connector bodies, contact records, and unrestricted recipient messages are not required.

A notice cannot discover a recipient, select a transport, approve itself, widen scope, invoke a tool, or mark itself read. An unverified trigger can produce informational context only; it cannot create a blocking/re-export/re-review directive. Delivery receipts require exact notice revision, affected scope, owner generation, and idempotency/replay binding. A local notification cannot prove human reading. A platform presentation callback cannot prove recipient receipt. A user handoff cannot prove delivery. An old consent cannot authorize a new transport or export. Missing local lineage cannot become “no affected recipients.”

Correction, re-export, supersession, notice, acknowledgement, delivery, recipient reading, re-review, tombstone, deletion-local, and external-copy limitation are separate states. A verified change can require local re-review; it cannot guarantee that an unmanaged copy changed or that a recipient was notified. `recipient_unknown`, `unmanaged_copy_unknown`, `delivery_unknown`, `recipient_read_unknown`, `stale`, and `unable_to_verify` are truthful outcomes.

M43 must never be described as recipient notification, delivery guarantee, read receipt, universal correction propagation, contact discovery, compliance communication, legal notice, incident closure, accessibility conformance, or production readiness.

## 9. Execution order and handoff

Implement M43-A as documentation and fixture-contract reconciliation against M31, M35, M37, M40, M41, M42, EventLedger, Honeycomb/source owners, and browser/session authorities before adding any notice UI. Implement M43-B with synthetic owner triggers and inert notice payloads only. Implement M43-C with fake review/acknowledgement generations and no real consent. Implement M43-D with local notification/share fakes and no network client. Implement M43-E with synthetic compaction/tombstones and network-denied, script-disabled, private, locked, permission-denied, accessibility-manual, and browser-disabled states.

The next smallest safe action is **M43-A: publish the `LineageDiscovery`, `ContinuityNotice`, `NoticeReviewBinding`, and `ContinuityDeliveryReceipt` contracts plus the affected-reference, acknowledgement, transport, and retention matrices, then reconcile them with M31 portability, M33 operations, M35 lifecycle, M37 notices/re-review, M38 package validation, M39 disposition, M40 exchange/receipts, M41 verified correction/closure/history, M42 re-export/tombstones/compaction, EventLedger, Honeycomb/source owners, Apple notification/file boundaries, and browser/session authorities**. Do not add a remote notification service, contact lookup, automatic re-export, recipient registry, second ledger, delivery/read guarantee, or runtime implementation as part of M43 planning.
