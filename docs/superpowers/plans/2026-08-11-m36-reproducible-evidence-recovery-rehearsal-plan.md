# M36 — Reproducible Evidence & Recovery Rehearsal Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M36 Reproducible Evidence & Recovery Rehearsal
> **Depends on:** M0–M6 storage/provenance/recovery; M10–M17 browser/context/action/worker boundaries; M25 engine/update ownership; M26 ownership/policy; M27 sync/device/epoch state; M28 Flow authority; M29 context governance; M31 portability/extensibility; M32 release receipts/distribution/recovery; M33 operations; M34 TrustSnapshot/control plane; M35 evidence/policy lifecycle governance.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities:** Apple signing/platform security/recovery documentation; SQLite transaction, backup, WAL, and integrity documentation; Sparkle update/security documentation; SLSA/in-toto provenance concepts; NIST SSDF/CISA response guidance; W3C privacy/accessibility principles; current Hive M0–M35 authority contracts.
>
> M36 turns the evidence contracts into a reproducibility and rehearsal boundary. It defines deterministic evidence inputs, replayable claim/snapshot generation, migration and restore drills, artifact/dependency identity, recovery receipts, and user-visible loss/limitation communication. M36 does not claim that a rehearsal is production proof, that a hash is trust, that a restore recovers opaque renderer state, or that a local evidence bundle is a compliance certification.

## 0. Decision summary

The smallest safe M36 architecture is:

```text
frozen synthetic inputs + exact build/policy/schema identities
  → deterministic replay manifest
    → evidence / TrustSnapshot / lifecycle reconstruction
      → injected migration, corruption, update, and restore failure
        → recovery receipt with loss/limitation classification
          → M34 disclosure + M33 operational case reference
            → browser-first continuation or explicit hold/block
```

| Slice | User value | Hard boundary |
|---|---|---|
| **R1 — Replayable evidence** | Reproduce what Hive claimed from frozen inputs | Replay proves the specified inputs and outputs match; it does not prove all real-world behavior |
| **R2 — Migration/restore rehearsal** | Find recovery failures before users encounter them | Rehearsal uses disposable profiles and synthetic data; it never mutates production state |
| **R3 — Artifact/provenance binding** | Know exactly which build/dependency/policy produced evidence | Provenance identifies inputs; it does not grant trust or replace signing/notarization |
| **R4 — Recovery receipt** | Explain what survived, what was lost, and what needs action | Opaque renderer/provider state is reported as unavailable, not fabricated as restored |
| **R5 — Operational handoff** | Turn rehearsal failures into actionable, bounded cases | M33 coordinates; M32/M35/native owners execute fixes and lifecycle changes |

M36 does **not** claim production disaster recovery, zero data loss, cryptographic attestation, SLSA certification, legal/compliance certification, universal backup restoration, physical erasure, automatic repair, remote telemetry, cross-tenant federation, or a new evidence ledger/store.

## 1. Current truth and reusable authorities

### 1.1 Existing surfaces

| Surface | Current truth | M36 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| M0 storage/recovery | Migration, backup, WAL, integrity, and persistence boundaries are documented or code-present in parts | Rehearsal inputs, corruption/failure cases, restore receipts | A documented recovery path is not fresh rehearsal evidence |
| M25 engine plan | Canonical browser state versus opaque renderer state and rollback boundaries are defined | Engine/update recovery scenarios and loss classification | Renderer rollback cannot claim opaque state recovery without conversion evidence |
| M31 portability | Scoped export, quarantine-first import, omission/loss reports, and deletion generations | Replay bundle transport and recovery comparison | Export is not a backup and cannot silently restore secrets |
| M32 release receipt | Artifact identity, nested components, signing, update, rollback, browser, performance, privacy, and accessibility evidence schema | Bind evidence to exact artifact/build/channel/receipt | Historical CI or ad-hoc bundle is not fresh release evidence |
| M33 operations | Trust cases, incident communication, redacted diagnostics, and post-incident review | Handoff of failed rehearsals and user-facing limitations | A rehearsal failure is not automatically a production incident |
| M34 TrustSnapshot | Projection of capabilities, lifecycle, identity, release, evidence, and limitations | Replay and compare snapshots | Snapshot comparison cannot authorize actions |
| M35 lifecycle | Version envelopes, expiry, consent continuity, rotation, quarantine, and tombstones | Migration/rotation/replay semantics | Lifecycle metadata does not prove data recovery |
| EventLedger | Append-only evidence authority | Record replay/rehearsal references and outcome summaries | M36 cannot create a second ledger or copy sensitive payloads |
| Honeycomb/lifecycle stores | Canonical content and deletion authorities | Synthetic restore/derived-index comparison | M36 cannot heuristically delete user content |
| CI/release workflows | Scripts and workflows exist with local/external evidence limits | Rehearsal metadata and artifact identity input | Workflow YAML is not proof that a run actually happened |

**Current implementation classification:** Hive has distributed recovery, release, lifecycle, provenance, and diagnostic primitives, but no verified single replay manifest, deterministic evidence comparator, disposable migration/restore rehearsal contract, exact loss taxonomy, or M32/M33 handoff receipt. M36 remains planning-only until fresh implementation and runtime evidence exist.

### 1.2 Authority table

| Concern | Single authority | M36 rule |
|---|---|---|
| Canonical browser state | Browser/session owner | Compare URL/profile/private/workspace/tab metadata; do not infer renderer restoration |
| Durable memory/content | Honeycomb/lifecycle owner | Rehearse only synthetic scopes and use owner deletion semantics |
| Append-only evidence | EventLedger | Record bounded rehearsal references, not raw fixtures/secrets |
| Release identity | M32/M25/UpdateManager/Sparkle owner | Bind exact artifact/build/channel/receipt; no mutable tag-only identity |
| Policy/lifecycle state | M35 owner contracts | Replay generation/expiry/quarantine decisions deterministically |
| Trust presentation | M34 TrustSnapshot | Compare current versus reconstructed state with freshness/limitation |
| Operational handoff | M33 TrustCase | Create a typed synthetic case reference when a gate fails; do not auto-remediate |
| Archive/import | M31 authority | Use disposable, scoped, omission-aware bundles; never restore credentials implicitly |
| Accessibility evidence | Native/UI harness plus manual review | Rehearsal may mark manual/unavailable, never silently pass |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A versioned `ReplayManifest` naming synthetic inputs, exact schema/policy/build identities, fixture IDs, environment class, deterministic seed, redaction profile, and expected outputs.
2. Deterministic replay of M34 TrustSnapshot, M35 LifecycleEnvelope, M32 receipt projections, and bounded M33 operational references from frozen inputs.
3. Evidence comparison with canonicalized ordering, hash/identity checks, allowed nondeterminism declarations, and explicit mismatch categories.
4. Disposable-profile migration rehearsals across supported schema versions, unsupported/future versions, downgrade attempts, partial migrations, and interrupted writes.
5. Restore/recovery rehearsals for corrupt snapshots, WAL/journal states, missing derived indexes, stale sync/outbox, revoked devices, account changes, failed updates, renderer termination, and partial deletion.
6. Artifact/dependency/policy provenance manifest binding source revision, dependency identity, build parameters, generated evidence, and exact M32 receipt references without asserting attestation.
7. Recovery receipt semantics: restored, partially restored, blocked, quarantined, unavailable, lost-canonical-state, and opaque-state-unavailable.
8. M33 operational handoff for rehearsal failures with bounded redacted references and M34 user-visible limitation copy.
9. Rehearsal cadence/ownership metadata and support-horizon/deprecation review fields without claiming that a scheduled rehearsal ran when no evidence exists.
10. Browser-first continuation for failed rehearsal, unavailable model/provider, offline state, private profile, locked Keychain, missing iCloud, disabled Swarm, and absent accessibility harness.
11. Accessibility/manual evidence for replay and recovery receipts, including keyboard, VoiceOver, large text, contrast, reduced motion, and error focus recovery.
12. Synthetic adversarial fixtures for prompt injection, manifest poisoning, path traversal, secret inclusion, stale claims, and false success.

### 2.2 Explicit non-goals

- A second EventLedger, evidence database, telemetry pipeline, backup service, disaster-recovery service, policy engine, or artifact registry.
- Running against production profiles, real credentials, real Keychain items, personal memory, real support packets, production update feeds, or live external accounts.
- Automatic repair, automatic rollback, self-modifying migration, model-selected recovery, or deletion of user data based on replay mismatch.
- Claiming that hashes, manifests, SBOMs, SLSA/in-toto-shaped records, or local signatures are cryptographic attestation or Apple trust.
- Universal restore of opaque CEF/renderer/provider/model state, full cross-engine state conversion, or recovery from external/provider-managed copies Hive cannot control.
- Remote evidence upload, browsing-content collection, hidden analytics, cross-app surveillance, model training, or engagement optimization.
- Legal retention/deletion/compliance certification, SOC 2/ISO certification, regulator evidence, or guaranteed recovery percentage.
- Forced updates, silent channel changes, downgrade around M32, or release signing/notarization outside existing authorities.
- Treating a green replay as proof of production readiness, security, accessibility conformance, or no future incidents.
- Requiring M36 for normal navigation, tabs, private browsing, local memory inspection, or Swarm-off browser use.

## 3. Replay and provenance contracts

### 3.1 `ReplayManifest`

```text
ReplayManifest {
  replay_id: stable UUID
  schema_version: semantic version
  fixture_set: immutable ordered IDs
  input_hashes: [content/metadata hashes]
  producer_build: exact app/engine/build/commit identity
  dependency_refs: pinned source/revision/license references
  policy_refs: M26–M35 generations
  deterministic_seed: bounded seed or none
  environment_class: synthetic/local disposable profile class
  redaction_profile: named omission policy
  expected_outputs: typed hashes/records/statuses
  allowed_nondeterminism: named fields only
  generated_at: Date
  evidence_refs: M32/M33/EventLedger references
}
```

A replay manifest is an evidence description, not an instruction from untrusted content. Fixture text, page text, imported manifests, model output, and release notes cannot change its fixture set, policy refs, expected outputs, or allowed nondeterminism. The runner uses a native allowlist and rejects unexpected fields.

### 3.2 Evidence comparison

Comparison proceeds in this order:

```text
identity → schema/policy compatibility → scope/redaction → canonicalization →
expected output/status → allowed nondeterminism → mismatch classification → receipt
```

Mismatch classes are `input_identity`, `schema_unsupported`, `policy_generation`, `scope_leak`, `secret_leak`, `ordering`, `nondeterministic_field`, `missing_output`, `unexpected_output`, `recovery_state`, `accessibility`, `environment`, or `unknown`. `unknown` blocks a green conclusion.

### 3.3 Artifact/dependency provenance

The manifest may record source revision, resolved dependency identity, build parameters, toolchain/environment class, artifact hash, notices/licenses, and generated evidence references. These identify what produced the artifact. They do not by themselves certify the builder, prove an artifact is safe, or replace M32 signature/notarization/Gatekeeper evidence. Mutable release tags are not sufficient identity when an immutable artifact/build reference is available.

## 4. Migration, restore, and recovery contract

### 4.1 Disposable rehearsal

Every rehearsal declares:

```text
profile = disposable synthetic profile
inputs = synthetic memory/browser/sync/policy fixtures
secrets = fake values only
network = denied, fixture-local, or explicitly bounded
external_accounts = absent or test doubles
cleanup = owner-approved disposable teardown
```

A rehearsal must be resumable and idempotent. Interruption produces a receipt with the last completed phase and remaining cleanup. A failed cleanup never authorizes reuse of the disposable profile.

### 4.2 Recovery receipt

```text
RecoveryReceipt {
  receipt_id: stable UUID
  replay_id: UUID
  trigger: migration | restore | corruption | update | renderer | sync | deletion | account
  canonical_state: preserved | changed | partial | lost | unknown
  derived_state: rebuilt | partial | stale | missing | unknown
  private_state: preserved | excluded | blocked | unknown
  opaque_renderer_state: preserved | unavailable | lost | not_tested
  evidence_state: complete | partial | blocked | quarantined
  user_action: none | retry | review | reauthorize | restore | export | contact_support
  limitations: bounded list
  owner_refs: typed authorities
  next_phase: typed non-executable state
}
```

“Restored” requires comparison against canonical fixture state. A successful process launch, a non-empty database, or a UI banner is not enough. If canonical tabs are preserved but scroll position or renderer state is unavailable, the receipt says so.

### 4.3 Hold/block semantics

A mismatch blocks only the affected evidence/release/recovery claim unless a hard privacy, integrity, or canonical-state failure requires a broader hold. Ordinary browsing remains available whenever safe. A hold receipt names owner, affected scope, evidence, user impact, workaround, and next review; it does not invent an SLA or silently clear the failure.

## 5. Work packages

### M36-A — Replay manifest and deterministic evidence comparator

Define `ReplayManifest`, fixture identity, canonicalization, allowed nondeterminism, mismatch classes, redaction profiles, native allowlists, and deterministic comparison for M32–M35 evidence projections.

**Done when:** synthetic replays produce stable outputs; injected ordering/time/environment differences are classified correctly; unknown mismatches never become green; no manifest field can authorize a tool or alter a policy.

### M36-B — Migration and restore rehearsal

Define disposable-profile rehearsal phases for schema migration, downgrade/future versions, interrupted writes, backup/restore, WAL/journal states, missing derived indexes, stale outbox, revoked device, account change, and partial deletion. Include resumability, idempotency, cleanup, and exact phase receipts.

**Done when:** synthetic failures produce deterministic partial/blocked/quarantined outcomes; production profiles and real accounts are never touched; a rehearsal never claims more recovery than the canonical fixture proves.

### M36-C — Artifact, dependency, and policy provenance binding

Define immutable artifact/build/dependency/policy identity fields, notice/license references, toolchain/environment class, and exact M32 receipt linkage. Distinguish identity/provenance from cryptographic attestation, notarization, signature verification, and security claims.

**Done when:** two artifacts or policy generations cannot share an ambiguous evidence identity; mutable tags, missing dependencies, changed build parameters, and absent M32 receipts produce limited/blocked evidence.

### M36-D — Recovery receipts and operational handoff

Define canonical/derived/private/opaque/evidence recovery states, user-action semantics, affected-scope holds, M33 synthetic TrustCase handoff, M34 limitation rendering, and no-false-success copy for update/renderer/storage failures.

**Done when:** each rehearsal outcome says what survived, what is missing, what is untested, who owns the next action, and whether ordinary browsing continues; no model or page content can close a hold.

### M36-E — Accessibility, cadence, and browser-first validation

Define rehearsal ownership/cadence metadata, support/deprecation review fields, accessible receipts, manual/unavailable harness states, offline/private/locked/Swarm-disabled behavior, and final evidence review. A cadence record must never claim a run without a receipt.

**Done when:** keyboard/VoiceOver/large-text/contrast/reduced-motion/error-focus paths are evidenced or explicitly unavailable; failed or disabled M36 leaves navigation, tabs, private mode, and local memory inspection usable.

## 6. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M36-01 | Empty replay manifest | Rejected with missing-field receipt |
| M36-02 | Current manifest | Accepted; deterministic identity |
| M36-03 | Fixture order changed | Canonical order or explicit mismatch |
| M36-04 | Input hash changed | Input-identity mismatch; no green replay |
| M36-05 | Unsupported replay schema | Quarantined; no forced decode |
| M36-06 | Unknown manifest field | Preserved/omitted per contract; no authority change |
| M36-07 | Prompt-injected expected output | Rejected as untrusted fixture content |
| M36-08 | Secret in fixture | Redacted/rejected before persistence |
| M36-09 | Allowed time nondeterminism | Accepted only for named field |
| M36-10 | Unnamed nondeterminism | Unknown mismatch; blocks green result |
| M36-11 | TrustSnapshot replay | Output/status matches frozen authority inputs |
| M36-12 | LifecycleEnvelope replay | Generation/compatibility state matches |
| M36-13 | M32 receipt replay | Exact artifact/build reference required |
| M36-14 | M33 case reference replay | Bounded reference; no case content copied |
| M36-15 | M34 limitation replay | Same limitation/freshness state |
| M36-16 | Additive schema migration | Applied with source/target receipt |
| M36-17 | Rename migration | Applied deterministically |
| M36-18 | Narrowing migration | Limitation visible; no silent loss |
| M36-19 | Future schema version | Quarantined/unsupported |
| M36-20 | Downgrade attempt | Rejected; no permissive decode |
| M36-21 | Interrupted migration | Resumable phase receipt; no false completion |
| M36-22 | Corrupt database snapshot | Previous/known-good path or blocked restore |
| M36-23 | WAL/journal mismatch | Integrity failure; no raw-copy success claim |
| M36-24 | Missing derived index | Partial restore; rebuild/unavailable stated |
| M36-25 | Corrupt FTS projection | Rebuild/blocked state; no silent search success |
| M36-26 | Stale sync outbox | Pending/stale; no acknowledged claim |
| M36-27 | Revoked device restore | Old operations quarantined |
| M36-28 | CloudKit account switch | Remote state quarantined/stale |
| M36-29 | Locked Keychain | Unavailable; no secret recovery claim |
| M36-30 | Partial deletion restore | Deleted/pending/external limits distinct |
| M36-31 | Renderer termination | Canonical URL/tab state compared; opaque state status explicit |
| M36-32 | Engine rollback | Release receipt and canonical-state comparison required |
| M36-33 | Failed update | Old-build/hold/manual-recovery state explicit |
| M36-34 | Private profile rehearsal | Private data excluded or synthetic-only |
| M36-35 | Artifact dependency changed | Provenance mismatch; evidence limited |
| M36-36 | Mutable release tag | Insufficient identity without immutable artifact reference |
| M36-37 | Missing notice/license | Release evidence blocked/limited |
| M36-38 | Policy generation changed | Rebuild or migration receipt required |
| M36-39 | Evidence expired during replay | Stale/review-needed state; no current claim |
| M36-40 | Tombstoned evidence | Reason/reference only; content withheld |
| M36-41 | Recovery receipt mismatch | Unknown mismatch; M33 handoff required |
| M36-42 | Rehearsal cleanup interrupted | Disposable scope remains blocked until cleanup receipt |
| M36-43 | Model proposes repair | Advisory only; owner approval required |
| M36-44 | Page instructs replay runner | Ignored as untrusted content |
| M36-45 | VoiceOver recovery receipt | Status/action/limitation reachable and understandable |
| M36-46 | Large text/high contrast | No clipped or color-only recovery state |
| M36-47 | Reduced motion/error focus | Recovery remains usable without motion dependency |
| M36-48 | Offline rehearsal | Local fixture path or explicit unavailable state |
| M36-49 | M36 disabled | Browser/private mode/local memory remain usable |
| M36-50 | Final rehearsal review | Inputs, identity, result, limitation, owner, and next action present |

## 7. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M36-A | Replay authority | Versioned manifest and deterministic comparator with native allowlist |
| M36-B | Input identity | Fixture, build, dependency, policy, and artifact identity are immutable/bounded |
| M36-C | Mismatch truth | Unknown/order/scope/secret/recovery/accessibility mismatches are distinct |
| M36-D | Migration rehearsal | Additive/rename/narrow/future/downgrade/interrupted paths are deterministic |
| M36-E | Restore rehearsal | Backup/WAL/journal/index/sync/account/device/deletion failures remain explicit |
| M36-F | Artifact provenance | Source/dependency/build/policy identity binds to exact M32 receipt where required |
| M36-G | No attestation overclaim | Hash/provenance/manifest is not presented as Apple trust or cryptographic attestation |
| M36-H | Recovery receipt | Canonical/derived/private/opaque/evidence states and user action are explicit |
| M36-I | Operational handoff | Failed rehearsal produces bounded M33 reference, not automatic remediation |
| M36-J | Accessibility/unavailable | Keyboard/VoiceOver/large-text/contrast/reduced-motion/manual gaps visible |
| M36-K | Disposable/privacy | Synthetic profiles, fake secrets, no production accounts, no hidden telemetry |
| M36-L | Browser-first fallback | Navigation, tabs, private mode, and local inspection remain usable with M36 disabled |

## 8. Safety, privacy, and claim boundaries

M36 is a rehearsal boundary, not a reason to collect more. Replays use synthetic data, fake secrets, disposable profiles, and bounded fixture-local inputs. Raw page text, screenshots, prompts, credentials, tokens, private memory, arbitrary paths, and cross-app activity are not required. A mismatch is evidence about the rehearsal input and contract; it is not permission to inspect production state.

Evidence comparison is not authority. A replayed TrustSnapshot cannot grant a capability; a recovery receipt cannot delete data; a provenance manifest cannot sign an artifact; a model cannot choose a repair; and a page/import/report cannot modify expected outputs or close a hold. All consequential operations remain with M0–M35 owners and require their current scope, generation, and consent.

A “pass” means the frozen fixture met the declared comparator. It does not mean the real product is secure, accessible, compliant, recovered, or incident-free. “Partial,” “blocked,” “unavailable,” “not tested,” and “unknown” are valid outcomes and must remain visible to the user and release owner.

## 9. Execution order and handoff

Implement M36-A as documentation and fixture-contract reconciliation before adding a replay runner. Implement M36-B against disposable synthetic profiles and fake owner stores; never use production databases, real Keychain items, personal memory, real accounts, or production feeds. Implement M36-C using exact local artifact metadata and synthetic dependency records; do not claim SLSA/in-toto certification. Implement M36-D with fake failures and redacted receipts. Implement M36-E only after M32–M35 evidence references and browser-first degradation are exact and current.

The next smallest safe action is **M36-A: publish the replay manifest, deterministic comparator, recovery receipt, and evidence-to-owner matrix, then reconcile it with M0, M25, M31, M32, M33, M34, M35, EventLedger, Honeycomb, UpdateManager, and browser/session authorities**. Do not add a second evidence store, remote telemetry, automatic repair, production backup service, attestation infrastructure, or runtime implementation as part of M36 planning.
