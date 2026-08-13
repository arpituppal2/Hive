# M37 — User-Visible Change, Deprecation & Support Horizon Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M37 User-Visible Change, Deprecation & Support Horizon
> **Depends on:** M0–M6 storage/provenance/recovery; M10–M17 browser/context/action/worker boundaries; M25 engine/update ownership; M26 ownership/policy; M27 sync/device/epoch state; M28 Flow authority; M29 context governance; M31 portability/extensibility; M32 release receipts/distribution/recovery; M33 operations; M34 TrustSnapshot/control plane; M35 evidence/policy lifecycle governance; M36 reproducible evidence/recovery rehearsal.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities:** Apple Human Interface Guidelines for alerts, notifications, progress, and accessibility; Sparkle publishing, compatibility, channels, informational updates, phased rollout, and release-notes documentation; CISA/NIST secure product lifecycle guidance; W3C accessibility and user-control principles; current Hive M0–M36 authority contracts.
>
> M37 defines how Hive communicates product, policy, schema, capability, engine, connector, model, and support changes to users without silently widening authority or implying readiness that evidence does not support. It defines typed change notices, acknowledgement and re-review semantics, compatibility/deprecation/support states, maintenance ownership, update/recovery limitation disclosure, provenance links, and browser-first fallback. M37 is a presentation and lifecycle contract over existing release, policy, trust, operations, and recovery authorities—not a second release feed, policy engine, support system, telemetry service, entitlement authority, or compliance program.

## 0. Decision summary

The smallest safe M37 architecture is:

```text
existing M32 release receipt / M35 generation / M36 recovery evidence
  → typed change classification and compatibility inspection
    → user-visible notice with provenance, impact, scope, and next action
      → acknowledgement or re-review state bound to the affected generation
        → M34 TrustSnapshot limitation/capability projection
          → browser-first continuation, hold, or explicit unavailable state
```

| Slice | User value | Hard boundary |
|---|---|---|
| **C1 — Change notice** | Users understand what changed and why it matters | Notice content comes from an existing owner; it cannot invent release or policy facts |
| **C2 — Re-review and acknowledgement** | Authority-changing changes do not silently inherit old consent | Acknowledgement records understanding/review; it is not a grant and cannot bypass current approval |
| **C3 — Compatibility and deprecation** | Unsupported or migration-required states are visible before failure | Compatibility is evaluated by the owning release/schema/policy authority; M37 only presents the result |
| **C4 — Support horizon** | Users know who owns a capability, its review date, and its limits | A horizon is a planning disclosure, not an SLA, warranty, or security certification |
| **C5 — Recovery and browser-first communication** | Failed updates and unavailable features have a truthful path forward | Ordinary navigation, tabs, private mode, and local inspection remain usable whenever safe |

M37 does **not** claim guaranteed support, a security warranty, legal compliance, automatic migration, forced updates, remote reporting, universal rollback, or that an acknowledgement grants consent to a new capability. It does not make a stale release note authoritative merely because it is displayed.

## 1. Current truth and reusable authorities

### 1.1 Existing surfaces

| Surface | Current truth | M37 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| M32 release receipt/distribution | Artifact, channel, update, rollback, signing, accessibility, and release evidence fields are planned/owned there | Exact artifact/channel/receipt identity and release limitation links | A version string or appcast entry alone is not proof of a valid release |
| M33 operations | Trust cases, incident communication, redacted diagnostics, and post-release follow-up are owned there | Incident/deprecation notice references and operational owner links | M37 cannot close or triage an operational case |
| M34 TrustSnapshot | Capability, lifecycle, identity, release, evidence, and limitation state are projected for user disclosure | Render current capability/support/review status | Snapshot presentation cannot grant authority or alter policy |
| M35 lifecycle | Generation, expiry, migration, rotation, quarantine, and tombstone semantics are defined | Bind re-review to affected policy/schema/generation identity | Historical acknowledgement is not an active grant after scope changes |
| M36 rehearsal | Replay, recovery, provenance, and limitation receipts are defined | Show whether a migration/update/recovery claim is fresh, partial, blocked, or unavailable | A successful rehearsal is not production readiness or a guarantee |
| M25 engine/update ownership | Renderer/engine/update boundaries and rollback limitations are defined | Explain engine compatibility and opaque-state limits | M37 cannot promise cross-engine state restoration |
| M31 portability | Export/import manifests, omission reports, conflict review, and quarantine-first handling are defined | Link migration guidance and scoped export/recovery actions | An export is not a backup or universal migration |
| Command Center / settings | Typed commands and settings are existing or planned surfaces | Provide a local notice inbox and direct navigation to affected settings | Do not add a second command or notification authority |
| Browser shell | Navigation, tabs, private mode, and local inspection are the acquisition wedge | Degrade notices without blocking ordinary browsing | A broken advanced module must not make the browser unusable |

**Current implementation classification:** Hive has distributed release, update, policy, trust, operations, recovery, and accessibility primitives, but no verified unified change-notice envelope, generation-bound acknowledgement/re-review state, support-horizon matrix, deprecation UX contract, or user-facing compatibility explanation. M37 remains planning-only until fresh implementation and runtime evidence exist.

### 1.2 Authority table

| Concern | Single authority | M37 rule |
|---|---|---|
| Artifact/version/channel identity | M32 release/update owner | Display exact identity and evidence status; do not infer from display text |
| Policy/context generation | M26/M29/M35 owners | Require re-review when generation, scope, or data class changes |
| Consent/grant | M10/M16/M17/EventLedger owners | A notice acknowledgement never substitutes for typed consent or TCC state |
| Schema/migration compatibility | M0/M35 storage/lifecycle owners | Display supported, migration-required, blocked, quarantined, and unknown states |
| Engine/renderer capability | M25/browser owner | Disclose opaque-state and engine limitations without claiming conversion |
| Incident/security response | M33 operations owner | Link bounded case/advisory references; do not invent severity or remediation |
| Recovery evidence | M36 rehearsal/recovery owner | Show receipt freshness and limitations; no green claim from missing evidence |
| Trust projection | M34 TrustSnapshot owner | Project state only; never authorize an action |
| User acknowledgement | M37 local presentation/receipt seam | Record reviewed scope/generation and timestamp; not a new authority or grant |
| Accessibility/status communication | Native UI/accessibility owner | Preserve status/action/limitation semantics across VoiceOver, keyboard, large text, contrast, and reduced motion |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A versioned `ChangeNotice` envelope naming source authority, change ID, artifact/policy/schema/generation identity, classification, affected capability, data scope, user impact, effective state, evidence freshness, provenance links, and next action.
2. Typed classifications for informational, behavior change, capability change, permission/scope change, migration required, deprecation, unsupported, security/incident, recovery limitation, and unavailable.
3. A deterministic impact vocabulary: no user action, review recommended, re-review required, export first, migrate, update, restore/retry, reauthorize, disable capability, or contact support.
4. Acknowledgement/review records bound to notice ID, authority generation, affected scope, and user-visible revision. An old acknowledgement becomes stale when the authority identity, scope, generation, or required action changes.
5. Explicit distinction between viewed, acknowledged, deferred, dismissed, re-review-required, blocked, unavailable, and not-applicable. Dismissal cannot hide a blocking migration or safety notice.
6. Compatibility state presentation for supported, supported-with-limitations, migration-required, incompatible, deprecated, unsupported, quarantined, blocked, unknown, and not-tested states.
7. A support-horizon record naming capability owner, current support state, last evidence review, next planned review, minimum supported app/OS/engine/schema state, known limitations, and escalation path where one actually exists.
8. Deprecation flow with announcement, effective date when authoritative, replacement/export guidance, grace state, end-of-support state, and recovery limitation. Dates must not be invented when the owner has not supplied them.
9. Release/update communication that distinguishes release notes, informational updates, critical updates, phased availability, local install state, download/verification failure, rollback availability, and manual recovery.
10. Provenance links to exact M32 receipt, M33 case/advisory, M35 lifecycle generation, and M36 recovery/replay receipt where available. Missing links remain visibly missing.
11. Browser-first fallback for offline mode, stale/invalid notice data, disabled Swarm, unavailable model/provider, private profile, locked Keychain, missing iCloud, denied Worker permissions, failed update, and absent accessibility/manual evidence.
12. Accessible status and error communication: keyboard reachability, focus restoration, VoiceOver labels/actions, large-text layout, contrast independent of color, reduced-motion behavior, and concise actionable recovery copy.
13. Local-only notice history and deletion/retention semantics within the existing owner scope; no remote behavioral analytics or engagement scoring.
14. Synthetic adversarial fixtures for notice poisoning, stale provenance, false urgency, hidden scope expansion, fake support dates, prompt injection, secret inclusion, and dismissal abuse.

### 2.2 Explicit non-goals

- A second release feed, appcast, update manager, policy engine, consent authority, support/ticketing system, telemetry pipeline, notification scheduler, or trust score.
- Silent capability enrollment, automatic permission grants, automatic policy acceptance, automatic migration, forced updates, or model-selected user decisions.
- Claiming Apple notarization, cryptographic attestation, security certification, legal compliance, guaranteed uptime, guaranteed response time, or guaranteed support.
- Inventing owners, dates, replacement products, severity, compatibility, recovery outcomes, or remediation steps when the authoritative source is absent.
- Sending notice history, browsing content, private memory, credentials, support packets, or behavioral data to remote services by default.
- Making a dismissal equivalent to deletion, revocation, consent, migration completion, incident resolution, or support acceptance.
- Universal cross-engine/renderer state conversion, restoration of provider-managed data, or recovery beyond M32/M35/M36 owner evidence.
- Blocking ordinary navigation, tab management, private browsing, local memory inspection, or Swarm-off mode because an advanced capability is deprecated or unavailable.
- Enterprise MDM/federation, multi-tenant policy distribution, public compliance dashboards, or cross-device acknowledgement synchronization.
- Runtime implementation, UI implementation, release configuration, update-feed changes, or changing any Swift source in this planning milestone.

## 3. Change notice and lifecycle contracts

### 3.1 `ChangeNotice`

```text
ChangeNotice {
  notice_id: stable UUID
  schema_version: semantic version
  authority: release | policy | schema | engine | connector | model | operations | recovery
  authority_ref: exact owner reference
  authority_generation: exact generation or null when not applicable
  change_kind: informational | behavior | capability | permission | migration |
               deprecation | unsupported | security | recovery | unavailable
  affected_scope: browser | workspace | project | source | connector | worker | model | profile
  affected_capability: stable capability ID
  artifact_ref: exact artifact/build/channel identity or null
  evidence_ref: M32/M33/M35/M36 reference or explicit unavailable
  status: published | scheduled | effective | grace | blocked | expired | superseded
  user_impact: concise structured impact
  required_action: none | review | re_review | export | migrate | update | restore |
                  reauthorize | disable | contact_support | unavailable
  effective_at: authoritative Date or null
  support_state: supported | limited | deprecated | unsupported | unknown
  replacement_ref: authoritative reference or null
  limitations: bounded list
  accessibility_summary: concise equivalent status/action text
  published_at: authoritative Date or null when not supplied
  supersedes: notice ID or null
}
```

Notice text is untrusted input until validated against the owning authority. Page text, connector records, model output, imported release notes, and user-authored snippets cannot create a notice, change its required action, widen its scope, or mark it acknowledged. A notice with missing authority or provenance may be displayed as an unverified informational item only; it cannot be treated as a blocking or security directive.

### 3.2 Review and acknowledgement

```text
NoticeReview {
  review_id: stable UUID
  notice_id: UUID
  reviewed_revision: exact rendered revision
  authority_generation: exact generation or null
  affected_scope: typed scope
  state: viewed | acknowledged | deferred | dismissed | stale | re_review_required |
         blocked | unavailable | not_applicable
  user_action: none | open_details | export | migrate | update | restore | reauthorize | disable
  created_at: Date
  superseded_by: review ID or null
}
```

`acknowledged` means the user reviewed the stated impact and next action. It never means “permission granted,” “policy accepted,” “risk removed,” “migration complete,” or “support guaranteed.” A review is stale when the notice revision, authority generation, affected scope, required action, or authoritative limitation changes. Security, migration, integrity, and capability-scope notices cannot be permanently suppressed by dismissal; they remain discoverable and reappear when stale or effective.

### 3.3 Support horizon

```text
SupportHorizon {
  capability_id: stable ID
  owner_ref: authoritative owner or explicitly unknown
  support_state: active | limited | deprecated | unsupported | blocked | unknown
  minimum_app_version: exact value or null
  minimum_os_version: exact value or null
  minimum_engine_version: exact value or null
  minimum_schema_generation: exact value or null
  last_reviewed_at: authoritative Date or null
  next_review_at: authoritative Date or null
  deprecation_effective_at: authoritative Date or null
  replacement_ref: authoritative reference or null
  known_limitations: bounded list
  escalation_ref: authoritative reference or null
}
```

A missing owner, date, or escalation path is rendered as unknown—not filled with a product assumption. `next_review_at` schedules internal review intent only; it is not a promised support deadline. A support horizon is a transparency record, not a warranty or SLA.

## 4. Compatibility, deprecation, and recovery communication

### 4.1 Compatibility decision presentation

Compatibility evaluation follows the owning authority’s result:

```text
identity → authority generation → schema/OS/engine/capability constraints →
policy/consent continuity → evidence freshness → user action → browser-first fallback
```

M37 renders the result as one of:

- **Supported:** current evidence and constraints meet the declared contract.
- **Supported with limitations:** usable, but a named limitation or stale evidence remains.
- **Review required:** user must inspect a behavior or scope change before using the affected capability.
- **Migration required:** a typed owner migration is needed; old authority is not silently reused.
- **Deprecated:** still available within an authoritative grace state, with replacement/export guidance if supplied.
- **Unsupported:** owner says the capability/version is outside support; no invented workaround.
- **Blocked/quarantined:** integrity, identity, policy, or lifecycle failure prevents use.
- **Unknown/not tested:** evidence is absent or not applicable; no green claim.

The browser remains usable when a non-core capability is unsupported. If a core integrity or privacy boundary is affected, M37 shows an explicit hold with scope, reason, owner, evidence, and next review rather than silently continuing under a false state.

### 4.2 Deprecation sequence

A valid deprecation sequence is:

```text
published notice → user-visible impact → review/defer state → grace/limited state
  → effective deprecation when authoritative → export/replacement guidance
  → unsupported/blocked state only when owner evidence says so
```

No step may be skipped by a model, page, imported package, or stale local cache. If the owner supplies no effective date, the notice says “date not provided.” If no replacement exists, it says so. Export guidance must identify its scope and omissions; it is not a backup or a promise of round-trip restoration.

### 4.3 Update and recovery limitations

Update communication must distinguish:

| State | User-facing truth |
|---|---|
| Update available | An authoritative artifact is available; identity and compatibility remain visible |
| Informational update | User needs information or manual action; no automatic mutation is implied |
| Phased availability | Availability is limited by the owning release policy; no local assumption of eligibility |
| Downloading | Transfer is in progress; completion is not implied |
| Verification failed | Artifact was not accepted; do not offer “updated” success |
| Migration required | Update cannot complete the affected state without owner migration/review |
| Rolled back | Previous known-good state was restored only within the evidenced scope |
| Renderer/provider state unavailable | Canonical browser state may survive while opaque state is not claimed restored |
| Recovery blocked | User must review a bounded hold; ordinary browsing remains available where safe |
| Offline/stale | Local last-known information is labeled stale and cannot create new authority |

A release note, update banner, or successful process launch is not a recovery receipt. M36 receipts and M32 release evidence remain the source for recovery and artifact claims.

## 5. Work packages

### M37-A — Change notice envelope and provenance

Define `ChangeNotice`, authority references, change classifications, affected scopes, evidence freshness, provenance links, user impact, required action, status, and unverified/unknown handling. Reconcile it with M32 release receipts, M33 cases, M35 generations, M36 replay/recovery receipts, and M34 TrustSnapshot.

**Done when:** every notice is attributable to one existing authority or visibly unverified; notice content cannot alter policy, consent, permissions, release identity, or tool execution; stale/missing provenance is explicit.

### M37-B — Review, acknowledgement, and re-review continuity

Define `NoticeReview` states, generation/scope/revision binding, stale-review invalidation, deferral, dismissal, reappearance, deletion scope, and accessibility of review actions. Keep acknowledgement separate from consent, grant, migration completion, and incident resolution.

**Done when:** a changed authority generation or required action deterministically requires re-review; dismissal cannot suppress blocking/security/migration information; review history remains local, bounded, and deletable within its owner scope.

### M37-C — Compatibility, deprecation, and support horizon

Define compatibility/support states, minimum app/OS/engine/schema fields, authoritative dates, owner/escalation references, replacement/export guidance, grace/limited/unsupported transitions, and unknown/not-tested truth. No assumed owner, date, workaround, or SLA is permitted.

**Done when:** supported, limited, review-required, migration-required, deprecated, unsupported, quarantined, blocked, unknown, and not-tested states are distinguishable; deprecation never silently widens or removes authority; browser-first behavior is defined for every non-core state.

### M37-D — Update, recovery, and limitation communication

Define user-facing copy and state transitions for available, informational, phased, downloading, verification-failed, migration-required, rolled-back, renderer/provider-unavailable, recovery-blocked, and stale/offline updates. Bind claims to M32/M36 evidence and show exact scope of recovery or loss.

**Done when:** no banner or process launch implies a completed update/recovery; opaque renderer/provider state is disclosed as unavailable when unproven; failed advanced updates leave ordinary browsing usable whenever safe.

### M37-E — Accessibility, browser-first fallback, and validation

Define keyboard/focus, VoiceOver, large-text, contrast, reduced-motion, concise-copy, offline/private/locked/Swarm-disabled, missing-permission, and stale-notice behavior. Add deterministic adversarial fixtures and an evidence matrix for manual/unavailable states.

**Done when:** all notice states expose equivalent status, impact, action, limitation, and provenance without color or motion dependence; missing UI/runtime/accessibility evidence is visible; navigation, tabs, private mode, and local inspection remain usable with M37 disabled.

## 6. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M37-01 | Empty notice envelope | Rejected with missing-authority receipt |
| M37-02 | Current release notice with M32 receipt | Accepted with exact artifact/channel provenance |
| M37-03 | Notice missing authority | Unverified informational only; cannot block or grant |
| M37-04 | Notice missing evidence reference | Limitation visible; no green security/recovery claim |
| M37-05 | Page text pretending to be a notice | Ignored as untrusted content |
| M37-06 | Model proposes urgent migration | Advisory only; owner evidence required |
| M37-07 | Connector record changes required action | Rejected; no authority widening |
| M37-08 | Unknown change kind | Quarantined/unknown; no silent default |
| M37-09 | Behavior-change notice | Review state and affected scope visible |
| M37-10 | Capability-scope change | Re-review required; no inherited grant |
| M37-11 | Policy generation increments | Prior review stale; new review required |
| M37-12 | Notice revision changes limitation | Prior acknowledgement stale |
| M37-13 | Acknowledgement without consent | Review recorded; capability remains ungranted |
| M37-14 | Dismissed migration notice | Reappears; cannot be permanently suppressed |
| M37-15 | Deferred informational notice | Deferred state visible and bounded |
| M37-16 | Security notice dismissal | Remains discoverable; no false cleared state |
| M37-17 | Scope changes from workspace to global | Re-review required; old review not reused |
| M37-18 | Review for another profile | Rejected as wrong scope |
| M37-19 | Deleted notice history | Owner-scoped history removed; authority unaffected |
| M37-20 | Review record tampered | Stale/invalid; current authority wins |
| M37-21 | Supported compatibility | Supported state with evidence reference |
| M37-22 | Supported with limitation | Limitation and next review visible |
| M37-23 | Migration required | Migration action and browser fallback visible |
| M37-24 | Incompatible OS | Unsupported/blocked state; no invented workaround |
| M37-25 | Deprecated with authoritative date | Grace state and effective date shown |
| M37-26 | Deprecated without date | “Date not provided”; no invented deadline |
| M37-27 | Unsupported without replacement | Unsupported state; no fake alternative |
| M37-28 | Unknown compatibility | Unknown/not-tested; no green claim |
| M37-29 | Quarantined package/policy | Blocked with owner/evidence reference |
| M37-30 | Missing support owner | Owner unknown; no implied SLA |
| M37-31 | Missing next review date | Review date unknown; no invented cadence |
| M37-32 | Export guidance with omissions | Scope/omissions visible; not called backup |
| M37-33 | Replacement reference unavailable | No replacement claim; supported limitation shown |
| M37-34 | Update available | Exact identity and compatibility visible |
| M37-35 | Informational/manual update | No automatic mutation implied |
| M37-36 | Phased rollout | Local eligibility not assumed |
| M37-37 | Download in progress | No completed-update state |
| M37-38 | Verification failure | Artifact rejected; retry/recovery action visible |
| M37-39 | Migration failure during update | Affected scope held; ordinary browsing remains usable |
| M37-40 | Rollback with M36 receipt | Only evidenced canonical scope called restored |
| M37-41 | Renderer state unavailable | URL/tab truth separated from opaque state |
| M37-42 | Provider/model unavailable | Swarm fallback labeled; browser remains usable |
| M37-43 | Offline stale notice | Stale timestamp visible; cannot create new authority |
| M37-44 | Locked Keychain | Secret-dependent capability unavailable; no bypass |
| M37-45 | Permission denied | Capability unavailable; denial remains a valid state |
| M37-46 | VoiceOver notice flow | Status, impact, action, and limitation announced |
| M37-47 | Large text/high contrast | No clipping or color-only meaning |
| M37-48 | Reduced motion | Notice/recovery works without animation dependency |
| M37-49 | M37 disabled | Navigation, tabs, private mode, local inspection remain usable |
| M37-50 | Final change review | Authority, scope, generation, impact, action, evidence, limitation, and owner present |

## 7. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M37-A | Notice authority | Every blocking/actionable notice maps to one existing authority or is visibly unverified |
| M37-B | Provenance truth | Artifact/policy/schema/incident/recovery references are exact or explicitly unavailable |
| M37-C | Review continuity | Acknowledgement is bound to notice revision, scope, and generation; it is not consent |
| M37-D | Re-review invalidation | Changed scope/generation/action/limitation makes old review stale |
| M37-E | Dismissal safety | Blocking, migration, integrity, and security notices cannot be permanently hidden |
| M37-F | Compatibility states | Supported/limited/review/migrate/deprecated/unsupported/blocked/unknown/not-tested are distinct |
| M37-G | Support honesty | Owner, dates, replacement, escalation, and SLA gaps remain unknown rather than invented |
| M37-H | Deprecation flow | Announcement/grace/effective/unsupported states have scoped guidance and no silent mutation |
| M37-I | Update/recovery truth | Download, verification, rollback, renderer, provider, and offline states do not imply success |
| M37-J | Accessibility | Keyboard/VoiceOver/large-text/contrast/reduced-motion/error-focus states remain equivalent and visible |
| M37-K | Privacy/browser-first | No hidden telemetry or remote history; browser, tabs, private mode, and local inspection survive feature failure |
| M37-L | No false readiness | Planning, stale, missing, manual, unavailable, and not-tested evidence are never presented as shipped support |

## 8. Safety, privacy, and claim boundaries

M37 is a transparency boundary, not a reason to collect more. Notice and review records contain the minimum local metadata needed to explain a change: identity, scope, generation, status, action, provenance, limitation, and timestamps. They do not require screenshots, raw page text, prompts, credentials, private memory, support packets, cross-app activity, or behavioral engagement history.

A notice cannot grant a capability. An acknowledgement cannot grant consent. A support horizon cannot promise an SLA. A release note cannot prove signing or recovery. A compatibility label cannot override the owning schema, engine, policy, Keychain, TCC, EventLedger, or update authority. A model, page, connector, imported package, or stale cache cannot change required action, close a hold, mark a migration complete, or invent an owner/date.

“Supported” means only that the named authority supplied the current declared state and evidence. “Deprecated,” “unsupported,” “blocked,” “unknown,” “not tested,” and “unavailable” are valid outcomes. A clean notice presentation is not evidence that the underlying capability works. M37 must never be described as a legal, security, accessibility, or support certification.

## 9. Execution order and handoff

Implement M37-A as documentation and fixture-contract reconciliation against M32–M36 before adding a notice renderer. Implement M37-B with synthetic notice revisions, scopes, generations, and review records; never use real account consent or personal memory. Implement M37-C against explicit compatibility fixtures and owner-provided dates only. Implement M37-D with fake update, verification, migration, rollback, renderer, provider, and offline failures. Implement M37-E only after provenance, lifecycle, recovery, and browser-first fallback references are exact and current.

The next smallest safe action is **M37-A: publish the typed change-notice envelope, review/re-review contract, compatibility/support matrix, and evidence-to-owner map, then reconcile it with M32 release/update authorities, M33 operations, M34 TrustSnapshot, M35 lifecycle, M36 recovery receipts, M25 engine state, M31 portability, EventLedger, and browser/session authorities**. Do not add a second release feed, policy engine, support database, remote telemetry, automatic migration, forced update, or runtime implementation as part of M37 planning.
