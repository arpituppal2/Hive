# M38 — Offline Evidence Traceability & Audit Package Execution Plan

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M38 Offline Evidence Traceability & Audit Package
> **Depends on:** M0–M6 storage/provenance/recovery; M10–M17 browser/context/action/worker boundaries; M25 engine/update ownership; M26 ownership/policy; M27 sync/device/epoch state; M28 Flow authority; M29 context governance; M31 portability/extensibility; M32 release receipts/distribution/recovery; M33 operations; M34 TrustSnapshot/control plane; M35 evidence/policy lifecycle governance; M36 reproducible evidence/recovery rehearsal; M37 user-visible change/deprecation/support horizon.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities:** M31 portability and omission semantics; M32 release receipts and artifact identity; M33 operational references; M34 TrustSnapshot projection; M35 lifecycle/tombstone rules; M36 replay/recovery receipts; M37 notice/review semantics; Apple signing and update documentation; SQLite integrity/backup constraints; SLSA/in-toto provenance concepts; W3C accessibility and privacy principles.
>
> M38 defines an offline, deterministic, redacted evidence package that lets a user or reviewer inspect the trace from release evidence through operational, trust, lifecycle, recovery, and change-notice projections. The package is a bounded export/projection, not a new ledger, provenance authority, compliance system, remote service, or proof that the underlying capability works. Existing authorities remain authoritative; M38 reports missing, stale, tombstoned, unavailable, and synthetic evidence without filling gaps.

## 0. Decision summary

The smallest safe M38 architecture is:

```text
existing M32–M37 authority records
  → owner-scoped projection and deterministic redaction
    → immutable package manifest with exact source references
      → offline structural/hash/signature-verification checks where evidence exists
        → broken-chain, stale, tombstone, and limitation report
          → local accessible viewer or plain-text fallback
```

| Slice | User value | Hard boundary |
|---|---|---|
| **A1 — Evidence package envelope** | Inspect one bounded chain of existing evidence offline | The package mirrors owner records; it cannot create authority or rewrite them |
| **A2 — Deterministic redaction/export** | Share evidence without leaking memory, credentials, or private context | Redaction is allowlisted and omission-aware; it is not a guarantee against every external copy |
| **A3 — Traceability validation** | Find missing, stale, revoked, or contradictory links | Validation reports facts about the package; it does not certify the product or repair records |
| **A4 — Integrity and provenance checks** | Detect changed bytes and identify source/build inputs | Hashes and verification of supplied signatures are not attestation, notarization, or trust |
| **A5 — Offline inspection** | Read the result without network access or a running Hive process | Viewer is a local presentation surface, not a new persistence or telemetry authority |

M38 does **not** claim legal/compliance certification, SLSA or in-toto conformance, Apple trust, notarization, universal cryptographic attestation, production readiness, security clearance, accessibility conformance, disaster recovery, or complete export of user data. A valid package is not a capability grant, release proof, or recovery guarantee; it means only that the declared package inputs passed the declared offline checks.

## 1. Current truth and authority boundaries

### 1.1 Existing surfaces

| Surface | Current truth | M38 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| M31 portability | Scoped manifests, omission reports, conflict review, quarantine-first import, and deletion semantics are defined | Evidence-only package envelope and omission vocabulary | M38 is not a second general export format and is not a backup |
| M32 release receipts | Artifact/build/channel/signing/update/recovery evidence is owned there | Exact receipt references and artifact identity | A package cannot manufacture a release receipt or replace signing evidence |
| M33 operations | Cases, advisories, incident communication, and follow-up references are owned there | Redacted typed case references and closure state | M38 cannot submit, triage, close, or disclose a case |
| M34 TrustSnapshot | User-facing projection of capability, lifecycle, identity, release, evidence, and limitations | Snapshot projection with freshness and limitation status | Snapshot data cannot grant permission or establish trust |
| M35 lifecycle | Generations, expiry, rotation, quarantine, tombstones, and deletion references are defined | Preserve tombstones and stale references without reviving content | A tombstone is not proof of physical erasure everywhere |
| M36 rehearsal | Replay manifests, recovery receipts, provenance inputs, and bounded handoffs are defined | Include exact rehearsal identity and synthetic/production classification | Synthetic rehearsal is never silently represented as production evidence |
| M37 notices | Change notices, reviews, support/deprecation states, and provenance links are defined | Link notice/review/generation continuity | A displayed notice or acknowledgement is not a grant or release proof |
| Browser-first shell | Navigation, tabs, private mode, and local inspection are the acquisition wedge | Plain-text/static fallback remains readable without Swarm | Broken validation/viewer must not block ordinary browsing |

**Current implementation classification:** Hive has distributed portability, release, evidence, lifecycle, trust, recovery, notice, and accessibility primitives, but no verified unified offline evidence package, deterministic package validator, redaction manifest, or chain-integrity report. M38 remains planning-only until fresh implementation and runtime evidence exist.

### 1.2 Single-authority matrix

| Concern | Existing authority | M38 role |
|---|---|---|
| Canonical event/action evidence | EventLedger | Reference by scoped ID; never copy raw secrets or become a second ledger |
| Canonical memory/content | Honeycomb and lifecycle owners | Exclude by default; package only explicitly authorized evidence projections |
| Artifact/build/update identity | M32 and M25/UpdateManager owners | Bind exact receipt/artifact references; preserve unavailable state |
| Operations/incidents | M33 | Carry bounded case/advisory references and status supplied by M33 |
| Trust presentation | M34 | Include snapshot revision/status as a projection, not authorization |
| Lifecycle/generation/tombstone | M35 | Preserve generation and tombstone semantics; never resurrect content |
| Rehearsal/recovery | M36 | Include replay/recovery receipt and synthetic/production classification |
| Notice/review/support | M37 | Include notice/review references and stale/re-review state |
| Export/omission | M31 | Own package transport, scope, omission, and quarantine semantics |
| Offline viewer | Local presentation owner | Render package only; no network, mutation, or hidden collection |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A versioned `OfflineAuditPackage` envelope containing package identity, schema version, creation context, scope, redaction profile, source references, contained projections, omission report, and validation expectations.
2. An allowlisted evidence projection for M32 release receipts, M33 operational references, M34 TrustSnapshots, M35 lifecycle/tombstone references, M36 replay/recovery receipts, and M37 change notices/reviews.
3. Exact source IDs, generations, revision IDs, hashes, timestamps where authoritative, and explicit `unknown`, `stale`, `unavailable`, `synthetic`, `tombstoned`, and `redacted` states.
4. Deterministic package ordering, canonical serialization, bounded size/count rules, content hashing, and a manifest that records the redaction/omission profile used.
5. Offline validation of package structure, schema compatibility, required references, hash consistency, signature verification when an existing signature and verification material are supplied, and chain continuity.
6. Traceability results that distinguish complete, partial, broken, stale, revoked, quarantined, tombstoned, synthetic-only, redacted, and unavailable evidence.
7. Redaction rules that exclude credentials, private keys, Keychain values, tokens, raw personal memory, page text, prompts, screenshots, connector bodies, support packet contents, and arbitrary local paths unless an existing owner explicitly permits a bounded identifier.
8. Broken-link and contradiction reports for missing M32 receipts, stale M35 generations, M36 recovery mismatches, M37 reviews tied to deleted capabilities, revoked device references, and M33 cases without supplied closure evidence.
9. A local-only static inspection surface with a plain-text/JSON fallback that works without network, Hive runtime, or remote service. Any viewer must treat package content as untrusted data and render it inertly.
10. Accessibility semantics for the package result: keyboard access, focus order, VoiceOver-equivalent labels, large text, contrast, reduced motion, and color-independent statuses.
11. Explicit distinction between synthetic rehearsal evidence, local development evidence, historical evidence, unavailable/manual evidence, and current release evidence.
12. Deterministic adversarial fixtures for package poisoning, path traversal, XSS-like payloads, secret inclusion, stale links, signature mismatch, schema downgrade, and false-success language.

### 2.2 Explicit non-goals

- A second EventLedger, Honeycomb store, release registry, provenance authority, support database, policy engine, or compliance database.
- Exporting full browsing history, memory, screenshots, prompts, credentials, Keychain values, private profile contents, connector bodies, or arbitrary files.
- Remote upload, cloud synchronization, analytics, engagement measurement, contact tracking, or hidden network calls by the exporter or viewer.
- Automatic repair, migration, rollback, permission grant, policy acceptance, notice acknowledgement, incident closure, or deletion caused by validation output.
- Calling hashes, manifests, SBOM-shaped records, local signatures, or package validation cryptographic attestation, Apple trust, notarization, or security certification.
- Claiming SLSA/in-toto compliance merely because fields resemble provenance concepts; any supplied signature is verified only within the exact stated verification scope.
- Treating package validity as proof of application security, accessibility conformance, legal compliance, production availability, incident absence, or recovery success beyond referenced receipts.
- Universal cross-engine renderer conversion, provider-managed data recovery, physical erasure, or restoration of data Hive never controlled.
- Enterprise federation, multi-tenant audit sharing, public compliance dashboards, or cross-device acknowledgement synchronization.
- Runtime implementation, UI implementation, release-feed changes, signing-key changes, or changes to Swift source in this planning milestone.

## 3. Package contracts

### 3.1 `OfflineAuditPackage`

```text
OfflineAuditPackage {
  package_id: stable UUID
  schema_version: semantic version
  package_kind: evidence_traceability
  created_at: authoritative Date or null
  source_profile: local | synthetic | release | historical | mixed | unknown
  scope: typed bounded scope
  redaction_profile: exact allowlist/omission profile ID
  source_refs: ordered typed owner references
  projection_refs: ordered typed projection IDs
  contained_hashes: canonical hash map
  signature_refs: supplied verification references or empty
  omission_report: typed omission entries
  tombstone_refs: typed non-content references
  validation_profile: exact validator profile ID
  package_limitations: bounded list
  viewer_requirements: static/plain-text capabilities
}
```

The package is a projection and transport envelope. It cannot make a missing source current, convert a tombstone into content, alter a generation, or assert that a referenced receipt exists merely because a string looks like an ID. Imported package fields, page text, connector content, model output, and user-authored labels are untrusted data and cannot change the validator profile, expected hashes, scope, or required status.

### 3.2 Evidence projection

Every included item carries:

```text
EvidenceProjection {
  projection_id: stable ID
  owner: M32 | M33 | M34 | M35 | M36 | M37
  owner_ref: exact reference or unavailable
  owner_generation: exact generation or null
  revision: exact revision or unknown
  state: current | historical | stale | revoked | quarantined | tombstoned |
         synthetic | redacted | unavailable | unknown
  content_hash: hash of included projection or unavailable
  source_hash: hash supplied by owner or unavailable
  included_fields: allowlisted field IDs
  omitted_fields: typed reasons
  limitations: bounded list
}
```

A package may report a reference to content without including the content. It must never imply that an omitted field was absent, approved, deleted everywhere, or restored. A `tombstoned` item remains a non-content lifecycle reference.

### 3.3 Offline validation result

```text
OfflineValidationResult {
  package_id: UUID
  validator_profile: exact ID/version
  structural_state: valid | invalid | unsupported | unknown
  integrity_state: matched | mismatched | not_available | unknown
  signature_state: verified | invalid | not_supplied | unsupported | unknown
  traceability_state: complete | partial | broken | stale | revoked |
                       quarantined | synthetic_only | redacted | unavailable | unknown
  findings: ordered typed findings
  omitted_scope: typed list
  limitations: bounded list
  user_action: none | review | obtain_receipt | re_export | quarantine | unavailable
}
```

`verified` in `signature_state` means only that the supplied signature was checked against the supplied artifact bytes, algorithm, key identity, and declared scope. It does not mean the key is trusted, the app is notarized, the artifact is safe, or the chain is complete. A validator must report `unknown` rather than infer trust from a passing hash.

## 4. Redaction, privacy, and chain rules

### 4.1 Default-deny package contents

The default package contains identifiers, states, generations, bounded timestamps, hashes, owner references, evidence status, omission reasons, and limitations. It excludes raw user content and secrets. A field is eligible only when its owner marks it exportable for this exact scope. Identifiers are not permission to open the source store or follow arbitrary paths.

The exporter must reject or omit:

- passwords, tokens, private keys, Keychain values, cookies, session material, and raw credentials;
- raw page text, screenshots, OCR, prompts, model context, private-memory content, and connector bodies;
- arbitrary absolute paths, shell commands, environment secrets, account identifiers not required for the bounded reference, and support packet contents;
- private-window state and profiles unless the owner supplies an explicit synthetic/non-content reference;
- viewer code or package data that attempts to execute, fetch, navigate, import, or mutate outside the package scope.

The omission report must name the field class and reason without echoing the secret. Redaction is not a promise that a recipient cannot infer anything from every surrounding identifier; the package must minimize scope and state this limitation.

### 4.2 Traceability chain

The validator follows only an allowlisted graph:

```text
M37 notice/review
  → M35 authority generation
    → M34 TrustSnapshot projection
      → M36 replay/recovery receipt
        → M32 artifact/release receipt
          → M33 operational reference where applicable
```

M31 owns packaging, not the truth of any node. Missing, stale, revoked, tombstoned, quarantined, synthetic, or unavailable links remain explicit. A chain with one unresolved required link is `partial`, `broken`, or `unknown` according to the declared validator profile; it never becomes complete through heuristic matching.

### 4.3 Viewer safety

The offline viewer treats every package field as inert data. It does not interpret package strings as HTML, JavaScript, CSS, URLs, commands, or file paths. External links are displayed as text unless the user explicitly chooses an allowed local action; the default viewer has no network capability. If the static viewer cannot load, the package remains inspectable through canonical JSON/plain text. Viewer success is not package validation success.

## 5. Work packages

### M38-A — Offline package envelope and owner projection

Define `OfflineAuditPackage`, `EvidenceProjection`, schema/version compatibility, owner references, scope, redaction profile, omission report, tombstone representation, package limits, and deterministic serialization over M32–M37 projections.

**Done when:** every included field maps to one existing owner; missing/unknown/tombstoned/synthetic states survive export; the package cannot mutate or replace its sources; no raw secrets or personal content enter the default fixture corpus.

### M38-B — Deterministic redaction and privacy boundary

Define default-deny field classes, exportability decisions, omission reasons, secret/path/prompt-injection handling, private-profile rules, bounded identifiers, package size limits, and non-network export behavior. Reconcile with M6 encryption, M19 roots, M27 device state, M31 portability, and M35 deletion/tombstones.

**Done when:** forbidden values are rejected or omitted before package persistence; omission is visible without echoing secrets; private, locked, revoked, and deleted scopes cannot be silently included or revived.

### M38-C — Offline integrity, provenance, and traceability validation

Define canonical serialization, hash coverage, supplied-signature verification, schema compatibility, reference-chain checks, stale/revoked/quarantined/tombstoned states, and mismatch categories. Explicitly separate integrity checks from trust, notarization, attestation, and compliance claims.

**Done when:** changed bytes, altered references, unsupported schemas, missing receipts, stale generations, and invalid supplied signatures produce bounded findings; a passing hash or signature check never becomes a product-security claim.

### M38-D — Accessible local inspection and plain fallback

Define a static/local viewer contract and plain JSON/text fallback with inert rendering, no network, no mutation, bounded package size, keyboard/focus behavior, VoiceOver text, large-text/contrast support, reduced-motion behavior, and explicit validation limitations.

**Done when:** a user can inspect valid, partial, broken, redacted, synthetic, tombstoned, and unavailable packages without Hive runtime or network; viewer failure leaves the package readable through the fallback; no package content can execute as an instruction.

### M38-E — Chain review, operational handoff, and browser-first validation

Define human review of findings, M33 bounded references, M34 limitation presentation, M36 synthetic-vs-production labels, M37 notice continuity, deletion/retention scope, and browser-first behavior when export/validation/viewer is unavailable.

**Done when:** validation findings route to review rather than automatic repair or closure; the package states what it can/cannot establish; navigation, tabs, private mode, and local inspection remain usable with M38 disabled.

## 6. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M38-01 | Valid end-to-end M32–M37 package | Complete only when every required link and scope check passes |
| M38-02 | Empty package | Invalid with missing-envelope finding |
| M38-03 | Missing M32 release receipt | Partial/broken; no release claim |
| M38-04 | Missing M33 operational reference | Partial; absence explicit |
| M38-05 | M34 snapshot without evidence | Limited/unknown; no trust claim |
| M38-06 | M35 tombstoned projection | Tombstone shown; content not revived |
| M38-07 | M36 failed rehearsal receipt | Recovery limitation preserved |
| M38-08 | M37 stale acknowledgement | Re-review/stale finding |
| M38-09 | Orphaned notice | Broken traceability; no owner inference |
| M38-10 | Altered projection bytes | Integrity mismatch |
| M38-11 | Altered manifest hash | Integrity mismatch; no green result |
| M38-12 | Unsupported package schema | Unsupported/quarantined |
| M38-13 | Downgrade package schema | Rejected; no permissive decode |
| M38-14 | Unknown M35 generation | Unknown; no current-policy claim |
| M38-15 | Extraneous unknown field | Rejected or preserved as inert unknown per profile |
| M38-16 | Invalid supplied signature | Signature invalid; not attestation verdict |
| M38-17 | Signature not supplied | Not supplied; no trust inference |
| M38-18 | Signature algorithm unsupported | Unsupported; package remains inspectable |
| M38-19 | Valid supplied artifact signature | Verification result scoped to supplied bytes/key/scope |
| M38-20 | Hash matches but owner receipt absent | Integrity matched; traceability incomplete |
| M38-21 | Credential-shaped value | Rejected/omitted without echo |
| M38-22 | Private key or Keychain value | Rejected/omitted without echo |
| M38-23 | Raw page text | Rejected/omitted by default |
| M38-24 | Prompt injection in notice field | Rendered inert; cannot change validation |
| M38-25 | HTML/script payload in projection | Escaped/inert; no execution |
| M38-26 | Absolute path in field | Omitted or reduced to bounded identifier |
| M38-27 | Shell command in field | Inert text; never executed |
| M38-28 | Private profile reference | Excluded or synthetic-only |
| M38-29 | Locked Keychain scope | Unavailable; no secret recovery claim |
| M38-30 | Revoked device reference | Revoked/quarantined state preserved |
| M38-31 | Stale M36 receipt | Stale limitation; no current recovery claim |
| M38-32 | M37 notice tied to deleted capability | Tombstoned/unsupported continuity finding |
| M38-33 | Missing replacement reference | No replacement invented |
| M38-34 | M31 omission report | Omission scope retained; not called complete export |
| M38-35 | Mixed synthetic/production package | Mixed classification visible; no production-wide claim |
| M38-36 | Historical release receipt | Historical state labeled; not current release evidence |
| M38-37 | Contradictory owner generations | Broken chain; human review required |
| M38-38 | M34 limitation omitted from projection | Projection incomplete; no clean trust state |
| M38-39 | M33 case without closure evidence | Open/unknown; no incident-resolution claim |
| M38-40 | Partial M36 recovery | Canonical/derived/opaque states remain distinct |
| M38-41 | Large package over bound | Rejected/bounded failure; no partial silent success |
| M38-42 | Duplicate projection ID | Rejected or explicit deterministic conflict |
| M38-43 | Multiple profile packages collide | Scope collision flagged |
| M38-44 | Export attempts live mutation | Rejected; source state unchanged |
| M38-45 | Viewer network request attempt | Blocked/absent; package remains local |
| M38-46 | Viewer unavailable | Plain JSON/text fallback remains usable |
| M38-47 | Keyboard-only inspection | All status/action/limitation findings reachable |
| M38-48 | VoiceOver/large text/high contrast | Equivalent meaning without color or clipping |
| M38-49 | Reduced motion and M38 disabled | Static fallback works; browser remains usable |
| M38-50 | Final human traceability review | Scope, owners, links, omissions, findings, limits, and next action present |

## 7. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M38-A | Package authority | Every projection maps to one existing M32–M37 owner; M31 owns transport only |
| M38-B | Scope and redaction | Default-deny secrets/private content/raw memory; omission reasons are visible without echo |
| M38-C | Deterministic serialization | Ordering, schema, limits, and hash coverage are fixed and bounded |
| M38-D | Chain integrity | Missing, stale, revoked, quarantined, tombstoned, synthetic, and unavailable links are distinct |
| M38-E | Signature honesty | Supplied signature verification is scoped; no attestation, Apple trust, or safety claim |
| M38-F | Provenance honesty | Hashes/manifests identify inputs; they do not replace M32 signing/notarization evidence |
| M38-G | Schema safety | Unsupported, downgraded, malformed, and unknown fields cannot widen authority |
| M38-H | Viewer safety | Package data is inert; no network, command, path, mutation, or hidden collection |
| M38-I | Offline fallback | Plain JSON/text remains inspectable without Hive runtime or network |
| M38-J | Accessibility | Keyboard, VoiceOver, large text, contrast, reduced motion, and focus/error states are equivalent |
| M38-K | Operational handoff | Findings route to bounded review/M33 references; no automatic repair or closure |
| M38-L | Browser-first/no false readiness | M38 failure never blocks ordinary browsing; partial/unknown/unavailable never becomes complete or shipped |

## 8. Safety, privacy, and claim boundaries

M38 is a bounded evidence projection, not a reason to collect more. The default package contains only identifiers, states, generations, bounded timestamps, hashes, owner references, omission reasons, and limitations needed for traceability. It does not require screenshots, raw page text, prompts, credentials, private memory, connector bodies, or behavioral history.

A package cannot grant a capability, accept a policy, acknowledge a notice, close an incident, restore data, sign an artifact, or delete a source. A validator cannot repair a broken chain or ask a model to choose a truth. Imported package content, release notes, page text, connector records, and model output remain untrusted and cannot alter expected hashes, scope, validator profile, or required action.

A valid package proves only that the declared package passed the declared offline checks. It does not prove that Hive is secure, accessible, compliant, supported, recovered, notarized, incident-free, or ready to ship. `partial`, `broken`, `stale`, `revoked`, `quarantined`, `synthetic`, `redacted`, `unavailable`, and `unknown` are valid outcomes and must remain visible.

## 9. Execution order and handoff

Implement M38-A as documentation and fixture-contract reconciliation against M31–M37 before adding an exporter. Implement M38-B using synthetic records and fake secrets only; never package real memory, credentials, Keychain values, private profiles, or live support packets. Implement M38-C with fixture-local hashes and supplied test signatures only; do not create signing keys or make attestation claims. Implement M38-D with inert static/plain-text rendering and network-denied fixtures. Implement M38-E only after the authority matrix, omissions, tombstones, browser-first fallback, and M37 review continuity are exact.

The next smallest safe action is **M38-A: publish the `OfflineAuditPackage`, `EvidenceProjection`, redaction/omission, and validation-result contracts, then reconcile them with M31 portability, M32 release receipts, M33 operations, M34 TrustSnapshot, M35 lifecycle, M36 recovery receipts, M37 notices, EventLedger, and browser/session authorities**. Do not add a second ledger, remote upload path, compliance dashboard, signing-key workflow, automatic repair, or runtime implementation as part of M38 planning.
