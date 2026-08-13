# M35 — Evidence & Policy Lifecycle Governance Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M35 Evidence & Policy Lifecycle Governance
> **Depends on:** M0–M6 storage/provenance/recovery; M10–M17 context, action, worker, and permission boundaries; M19/M23 connector lifecycle; M25 engine/update ownership; M26 ownership/policy; M27 membership/device/epoch state; M28 Flow authority; M29 context/personalization governance; M30 agenda/notification coordination; M31 portability/extensibility; M32 release receipts; M33 operations; M34 TrustSnapshot/control plane.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities:** Apple Keychain and CloudKit identity/state documentation; Apple signing/update/security guidance; SQLite migration/recovery constraints; SLSA provenance concepts; CISA/NIST lifecycle and vulnerability-response guidance; W3C privacy/accessibility principles; current Hive M0–M34 authority contracts.
>
> M35 governs the lifecycle of evidence and policy references after M34 makes them visible. It defines how TrustSnapshots, EvidenceClaims, consent/grant mappings, policy generations, key/device references, and operational receipts are versioned, expired, rotated, migrated, quarantined, and tombstoned without silently reviving authority or breaking the browser. M35 is a coordination and schema contract over existing owners—not a new policy engine, ledger, telemetry service, identity system, or garbage collector that can delete arbitrary user data.

## 0. Decision summary

The smallest safe M35 architecture is:

```text
existing owner schemas and receipts
  → version/compatibility inspection
    → migration / expiry / rotation decision
      → quarantine or tombstone with reason and generation
        → owner-specific apply + EventLedger evidence
          → rebuilt M34 TrustSnapshot with freshness/limitation state
            → browser-first fallback if any authority is unavailable
```

| Slice | User value | Hard boundary |
|---|---|---|
| **L1 — Evidence schema lifecycle** | Trust disclosures survive app evolution without becoming false | M35 migrates read models and references; it cannot promote old evidence to current truth |
| **L2 — Policy generation lifecycle** | Old policy and context rules expire safely | Expiry is fail-closed for authority, not permissive fallback or silent deletion |
| **L3 — Consent/grant continuity** | Existing user choices remain understandable across updates | A historical consent is not an active grant; scope/generation changes require revalidation |
| **L4 — Identity/key rotation** | Device, Keychain, sync, and release references rotate without stale authority | Native owners control keys/identity; M35 quarantines rather than inventing continuity |
| **L5 — Evidence retention/tombstones** | Stale evidence stops misleading users while receipts remain explainable | Cleanup is bounded and owner-approved; no arbitrary Honeycomb/EventLedger deletion |

M35 does **not** claim cryptographic attestation, universal policy enforcement, automatic key recovery, legal retention compliance, secure physical erasure, blockchain immutability, remote deletion, enterprise federation, MDM enforcement, or complete migration of opaque renderer/provider state.

## 1. Current truth and reusable authorities

### 1.1 Existing surfaces

| Surface | Current truth | M35 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| M34 `TrustSnapshot` | Planned read model with schema version, freshness, authority refs, capabilities, lifecycle, identity, release, and evidence | Version compatibility, rebuild, stale/partial classification | Snapshot is not a durable authority or permission cache |
| M34 `EvidenceClaim` | Planned claim status/owner/evidence/freshness/limitations contract | Expiry/review/tombstone transitions | `verified` is not permanent and cannot survive missing evidence as current truth |
| M16 grants/Permission Center | Planned capability grants with target scope, purpose, generation, expiry, and revoke | Consent/grant continuity and revalidation | Prior approval cannot override current TCC/policy state |
| EventLedger | Append-only evidence authority | Link migration, expiry, rotation, quarantine, and tombstone events | M35 must not rewrite or duplicate the ledger |
| M26/M29 policy/context | Ownership, policy admission, explicit preferences, inferred signals, context packets | Policy generation compatibility and fail-closed expiry | An old preference/context packet cannot widen current scope |
| M27 membership/device/epoch | Planned shared identity, epoch rotation, revocation, and late-device quarantine | Key/device reference transitions and stale-generation denial | Current personal sync is not proof of multi-device collaboration |
| M31 archives/manifests | Quarantine-first portability and declarative projections | Invalidate stale exports/manifests after deletion/policy generation changes | Archives are not live authority and cannot restore secrets |
| M32 release receipts | Exact artifact, signing, update, recovery, browser, privacy, and accessibility evidence | Bind migrations/policy changes to exact build/receipt | A release receipt cannot attest to a future runtime state |
| M33 operational cases | Typed trust intake, reports, support packets, privacy receipts, and learning aggregates | Preserve case references and limitations during expiry/tombstone | Closed/expired case is not proof that a vulnerability never existed |
| M34 Trust Center | Planned projection and typed revoke/reset/export actions | Show lifecycle transitions, blocked migration, and user action needed | A UI status cannot make an unsafe migration safe |
| Honeycomb/lifecycle stores | Canonical content and lifecycle owners | Apply typed evidence/tombstone references only through owners | No global garbage collector may delete user memory by heuristic |

**Current implementation classification:** M0–M34 define many lifecycle concepts, but there is no verified cross-authority schema compatibility registry, evidence expiry/review coordinator, consent/grant migration contract, policy-generation transition protocol, key/device reference rotation receipt, or bounded orphan/tombstone policy. M35 claims must remain planned until implementation and fresh evidence exist.

### 1.2 Authority table

| Concern | Single authority | M35 rule |
|---|---|---|
| Durable content | Honeycomb and its lifecycle owner | Evidence references may be tombstoned; content deletion follows its own contract |
| Append-only history | EventLedger | M35 appends lifecycle evidence; it never rewrites or garbage-collects ledger rows directly |
| Permission/grant truth | M16/native TCC/worker owner | Historical consent cannot authorize current activity |
| Policy/context admission | M26/M29/M30/M28 owners | Old generations fail closed or require explicit reapproval |
| Sync/device/member keys | M27/CloudKit/Keychain owners | Rotation/revocation state is observed and referenced, not invented |
| Release/update truth | M32/M25/UpdateManager/Sparkle owner | Migration compatibility binds to exact build/channel/receipt |
| Export/import | M31 authority | Generation-invalidated archives are quarantined and never silently applied |
| Trust presentation | M34 TrustSnapshot projection | Rebuild from current owner state; stale results cannot authorize actions |
| Cleanup/tombstones | Each owning store | M35 coordinates typed requests and retention, never universal deletion |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A versioned compatibility envelope for TrustSnapshot, TrustCapability, EvidenceClaim, LifecycleSummary, IdentitySummary, ReleaseSummary, and TrustActionPreview references.
2. Schema migration rules for additive, rename, narrowing, unknown-field, unsupported-version, and downgrade cases; every result is explicit and receipt-backed.
3. Evidence freshness/review/expiry states that distinguish current, stale, superseded, unavailable, blocked, quarantined, tombstoned, and historical evidence.
4. Policy-generation transitions for M26/M29/M30/M28 scope, context, notification, and Flow references; old generations cannot silently grant current authority.
5. Consent/grant continuity mapping that separates historical disclosure/approval from current active grant and forces revalidation on scope, target, identity, policy, TCC, worker, or generation changes.
6. Key/device/identity reference rotation contracts for Keychain, M27 membership/device/epoch, CloudKit account change, M32 release/update identity, and connector account shells without exposing secrets.
7. Quarantine and tombstone records with reason, owner, generation, source reference, dependent projections, retry/repair state, retention boundary, and user-visible limitation.
8. Stale archive/manifest/context/proposal invalidation through M31/M29/M30 authorities; invalidated artifacts cannot be applied as current authority.
9. Bounded orphan detection and cleanup requests over evidence references, not heuristic deletion of Honeycomb content or arbitrary EventLedger rows.
10. Browser-first failure behavior for incompatible schemas, expired policies, unavailable keys, account switches, revoked devices, corrupt evidence, and failed cleanup.
11. Synthetic migration, downgrade, expiry, revocation, rotation, injection, deletion, accessibility, and recovery fixtures tied to M0–M34 receipts.
12. A user-visible M34 disclosure path for “what changed,” “what is stale,” “what needs approval,” “what was quarantined,” and “what cannot be recovered.”

### 2.2 Explicit non-goals

- A second policy engine, consent ledger, EventLedger, identity store, device registry, telemetry pipeline, garbage collector, or remote compliance database.
- Automatic permission grants, automatic consent renewal, silent policy widening, permissive fallback after incompatible state, or model-selected migration authority.
- Direct TCC database reads/writes, Keychain secret export, private-key recovery, CloudKit account impersonation, device trust invention, or identity federation.
- Universal migration of opaque renderer state, provider-specific model state, third-party connector state, or arbitrary plugin/Flow runtime state.
- Automatic deletion of user memory, raw Honeycomb content, backups, external exports, provider-managed copies, or audit history based only on age or missing references.
- Cryptographic attestation, SBOM/SLSA certification, blockchain ledger, legal retention/deletion compliance, SOC 2/ISO certification, or security guarantee.
- Remote telemetry, behavioral tracking, engagement optimization, hidden evidence collection, or training models on lifecycle/incident data.
- Background network migration, forced update, silent channel switching, downgrade around M32, or release signing outside existing authorities.
- Treating a tombstone as proof that every derived or external copy is physically erased.
- A dashboard-first experience or a requirement that M35 be enabled for navigation, tabs, private browsing, or local memory inspection.

## 3. Lifecycle contracts

### 3.1 Compatibility envelope

```text
LifecycleEnvelope {
  object_kind: trust_snapshot | capability | evidence_claim | lifecycle_summary |
                identity_summary | release_summary | action_preview | policy_ref |
                consent_ref | grant_ref | key_ref | archive_ref | case_ref
  schema_version: semantic version
  producer: typed owner/build identity
  created_at: Date
  source_generation: stable generation
  policy_generation: stable generation
  evidence_refs: immutable references
  payload_hash: content hash
  compatibility: current | additive | needs_migration | unsupported | downgraded |
                stale | quarantined | tombstoned | unavailable
  migration_state: not_needed | proposed | approved | applying | applied | blocked | failed
  limitation: bounded explanation
}
```

Unknown fields may be preserved as opaque data only when the owner’s contract permits it. Unknown semantics never become active authority. A downgrade or unsupported producer is quarantined, not coerced into the newest or oldest interpretation.

### 3.2 Evidence lifecycle

```text
current → review_due → stale → superseded | unavailable | blocked
                                  ↘ quarantined → tombstoned
```

`current` requires the referenced build/policy/source/receipt to remain available and within its review horizon. `stale` can be shown as historical context but cannot authorize an action or claim present capability. `superseded` points to a replacement claim without deleting the original evidence. `tombstoned` preserves a minimal reason/reference receipt while withholding the original content according to the owner’s deletion rules.

### 3.3 Policy and consent lifecycle

```text
policy generation N
  → disclosed change
    → user review or bounded compatibility decision
      → generation N+1 active
        → generation N expired/revoked
```

A policy change is not a user consent. If a change widens data scope, target scope, egress, retention, privilege, or automation behavior, the old consent cannot be silently reused. Narrowing or bug-fix changes may be compatible only when the owning policy contract says so and the user-visible receipt explains the classification.

Historical approval is retained as evidence of what happened; active authority requires current state, current generation, current identity, and current system permission.

### 3.4 Key/device/reference rotation

Rotation changes references and generations, not secret values in the Trust Center:

```text
old identity/key/device reference
  → rotation announced
    → new reference admitted
      → dependent state revalidated or quarantined
        → old reference revoked/expired
          → receipt and user-visible limitation
```

A missing key, locked Keychain, CloudKit account change, M27 epoch mismatch, or revoked device is not repaired by copying old authority forward. The safe result is unavailable/quarantined plus a bounded recovery path.

## 4. Work packages

### M35-A — Compatibility registry and migration envelope

Define owner-scoped schema identities, semantic versions, producer/build identity, payload hashes, supported migration directions, unknown-field rules, downgrade handling, and deterministic migration receipts for M34 read models and referenced M0–M34 objects.

**Done when:** synthetic additive, rename, narrowing, unknown-version, malformed, and downgrade fixtures produce deterministic current/needs-migration/unsupported/quarantined states; no migration grants authority or silently discards fields.

### M35-B — Evidence review, expiry, and tombstones

Define evidence freshness/review horizons, supersession links, unavailable/blocked states, tombstone metadata, retention ownership, and M34 rendering. Preserve minimal explainability without retaining deleted content or treating stale evidence as current.

**Done when:** expired, superseded, deleted-source, missing-receipt, and review-unavailable claims render honestly; tombstoning does not imply universal physical deletion; action authorization never uses stale or tombstoned claims.

### M35-C — Policy-generation and consent/grant continuity

Define compatibility classes for M26/M29/M30/M28 policy generations and map historical EventLedger consent/disclosure to current M16 grants and native permission state. Require explicit reapproval for widened scope, egress, retention, target, identity, or privilege; fail closed on ambiguity.

**Done when:** synthetic scope widening, target replacement, policy change, TCC change, worker replacement, and expired grant fixtures cannot silently renew authority or leak private context; narrow compatible changes remain inspectable.

### M35-D — Identity/key/device rotation and quarantine

Define reference-only rotation receipts for Keychain, CloudKit account changes, M27 membership/device/epoch, connector accounts, and M32 release/update identity. Quarantine stale or revoked dependent state and provide bounded recovery/export paths without secret exposure.

**Done when:** old generations, revoked devices, account switches, locked Keychain, missing keys, replayed rotations, and partial acknowledgements produce typed quarantine/blocked states; no stale authority is revived.

### M35-E — Invalidated artifact cleanup and browser-first recovery

Coordinate M31 archive/manifest invalidation, M29/M30 context/proposal invalidation, M33 case/evidence references, and owner-specific tombstone/cleanup requests. Add deterministic orphan detection, retry/repair status, accessibility disclosure, and clean-profile browser fallback.

**Done when:** stale exports/proposals/contexts cannot apply, cleanup is bounded and owner-approved, partial failure remains visible, user memory is not heuristically deleted, and navigation/private browsing remain usable during total M35 unavailability.

## 5. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M35-01 | Current envelope | Accepted as current |
| M35-02 | Additive unknown field | Preserved or explicitly omitted per owner contract; no authority widening |
| M35-03 | Rename migration | Deterministic migration receipt with source/target versions |
| M35-04 | Narrowing migration | User-visible limitation; no silent data loss |
| M35-05 | Unsupported future version | Quarantined; no forced decode |
| M35-06 | Downgrade envelope | Rejected/quarantined; no downgrade-based authority |
| M35-07 | Malformed payload hash | Integrity failure; no apply |
| M35-08 | Producer identity mismatch | Blocked; owner revalidation required |
| M35-09 | Stale TrustSnapshot | Historical display only; no authorization |
| M35-10 | Evidence review due | Review-needed state; no false current claim |
| M35-11 | Evidence superseded | Replacement link visible; original remains historical |
| M35-12 | Evidence source deleted | Unavailable/tombstoned; no citation or action claim |
| M35-13 | Missing M32 receipt | Release claim blocked/limited |
| M35-14 | M33 case closed | Closed is visible; no claim of zero incident |
| M35-15 | Tombstone with deleted content | Minimal reason/reference only; content withheld |
| M35-16 | Tombstone dependent index | Pending/partial state; no complete deletion claim |
| M35-17 | Policy generation unchanged | Compatible reuse only with receipt |
| M35-18 | Policy scope widened | Reapproval required; old consent cannot authorize |
| M35-19 | Policy egress widened | Remote consent required; local path remains |
| M35-20 | Policy retention widened | Reapproval or blocked state |
| M35-21 | Policy target changed | Grant invalidated; target revalidation |
| M35-22 | Historical consent only | Disclosure history visible; no active grant implied |
| M35-23 | TCC state changed | Native state wins; Hive consent not substituted |
| M35-24 | Worker identity changed | Old grant rejected; fresh admission required |
| M35-25 | Worker generation expired | Expired/revoke state; no execution |
| M35-26 | Key reference rotated | Dependents revalidated or quarantined |
| M35-27 | Keychain locked | Unavailable/locked; no secret exposure |
| M35-28 | Keychain item missing | Recovery path; no fabricated key |
| M35-29 | CloudKit account changed | Remote-bound state quarantined/stale |
| M35-30 | M27 device revoked | Old device operations rejected |
| M35-31 | M27 epoch changed | Old epoch cannot authorize current state |
| M35-32 | Rotation replay | Duplicate idempotent receipt or integrity failure |
| M35-33 | Partial rotation acknowledgement | Pending/partial; no completion claim |
| M35-34 | Connector account replaced | No cross-account merge |
| M35-35 | M32 channel identity changed | Update/channel revalidation required |
| M35-36 | M31 archive invalidated | Quarantined; no silent import/apply |
| M35-37 | M31 manifest revoked | Projection removed/review required |
| M35-38 | M29 context packet stale | Excluded from model context |
| M35-39 | M30 proposal stale | Expired; cannot mutate task/notification |
| M35-40 | M33 evidence reference orphaned | Bounded repair request; no arbitrary deletion |
| M35-41 | Orphan points to private scope | Redacted/denied; no private resurrection |
| M35-42 | Orphan points to deleted source | Tombstone/limitation; content not recovered |
| M35-43 | Cleanup owner unavailable | Pending/blocked; browser unaffected |
| M35-44 | Cleanup retry after crash | Idempotent continuation; no duplicate deletion |
| M35-45 | Prompt-injected migration instruction | Ignored as untrusted content |
| M35-46 | Model proposes permissive migration | Advisory only; native owner decides |
| M35-47 | VoiceOver lifecycle notice | Status and next action accessible without color-only meaning |
| M35-48 | Large text/high contrast/reduced motion | Migration/quarantine/recovery remains usable |
| M35-49 | M35 unavailable | Browser/private mode/memory inspection remain usable |
| M35-50 | Final lifecycle review | Versions, owner, state, evidence, limitation, and next action present |

## 6. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M35-A | Compatibility authority | Owner-scoped version envelopes and deterministic migration outcomes |
| M35-B | No silent downgrade | Unsupported/future/downgrade state quarantines without authority revival |
| M35-C | Evidence freshness | Current/stale/superseded/unavailable/blocked/tombstoned states are distinct |
| M35-D | Policy generation | Scope/egress/retention/target/privilege changes require correct reapproval |
| M35-E | Consent continuity | Historical consent is separate from active grant and native permission |
| M35-F | Identity/key rotation | Key/device/account/epoch references rotate or quarantine without secrets |
| M35-G | Revocation safety | Revoked/expired generations cannot authorize current actions |
| M35-H | Archive/context invalidation | Stale M31/M29/M30 artifacts cannot apply as current authority |
| M35-I | Tombstone/cleanup scope | Owner-approved, bounded, idempotent cleanup; no heuristic memory deletion |
| M35-J | Recovery truth | Crash, partial, offline, locked, unavailable, and blocked states are explicit |
| M35-K | Accessibility/unavailable truth | Keyboard/VoiceOver/large-text/contrast/reduced-motion/manual gaps visible |
| M35-L | Browser-first fallback | Navigation, tabs, private mode, and local inspection remain usable with M35 disabled |

## 7. Safety, privacy, and claim boundaries

M35 is a lifecycle boundary, not a reason to collect or retain more. Evidence and policy metadata must be minimized; raw page text, screenshots, prompts, secrets, tokens, private memory, arbitrary paths, and cross-app activity are not required for migration. If a migration cannot determine safety, it quarantines the object and explains the limitation.

Migrations are not permissions. A successfully decoded envelope cannot authorize a tool, restore a grant, widen context, select a model, change a release channel, or delete data. Model/page/import/connector content is untrusted and cannot choose a migration path or cleanup scope. Every consequential transition is owner-controlled, generation-bound, revalidated, and evidenced through existing EventLedger/lifecycle authorities.

Expiry is not erasure. Tombstoning is not physical deletion. Key rotation is not secret recovery. A release receipt is not a cryptographic attestation. A policy version is not proof that a user accepted it. M35 must render these distinctions directly in M34 and never collapse them into a green status.

## 8. Execution order and handoff

Implement M35-A as documentation and authority reconciliation before adding migration code. Freeze synthetic envelopes for current, additive, unsupported, downgraded, stale, private, revoked, locked, account-switched, and partially acknowledged states. Implement M35-B/C against fake owner stores and EventLedger fixtures. Implement M35-D with fake Keychain/CloudKit/M27/M32 references; never use real keys, accounts, personal memory, or production feeds. Implement M35-E only after owner-specific deletion and browser-first boundaries are referenced by exact evidence.

The next smallest safe action is **M35-A: publish the compatibility envelope and evidence/policy lifecycle matrix, then reconcile it with M16, M26, M27, M29, M31, M32, M33, M34, EventLedger, Keychain, CloudKit, and browser authorities**. Do not add a second policy engine, telemetry pipeline, remote compliance service, automatic key recovery, heuristic garbage collector, or runtime implementation as part of M35 planning.
