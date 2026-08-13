# M40 — Consent-Bound Evidence Exchange & Recipient Review Execution Plan

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M40 Consent-Bound Evidence Exchange & Recipient Review
> **Depends on:** M0–M6 storage/provenance/recovery; M10–M17 browser/context/action/worker boundaries; M25 engine/update ownership; M26 ownership/policy; M27 sync/device/epoch state; M28 Flow authority; M29 context governance; M31 portability/extensibility; M32 release receipts/distribution/recovery; M33 operations; M34 TrustSnapshot/control plane; M35 evidence/policy lifecycle governance; M36 reproducible evidence/recovery rehearsal; M37 user-visible change/deprecation/support horizon; M38 offline evidence traceability/audit package; M39 evidence package lifecycle/human disposition.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities:** M31 export/import/quarantine/omission semantics; M38 package, redaction, validation, and traceability contracts; M39 package lifecycle, deletion, review, and viewer boundaries; M27 membership/key/package lessons without importing collaboration authority; Apple App Sandbox, file sharing, Keychain, and signing guidance; OWASP untrusted input and data-sharing guidance; W3C WCAG status/confirmation guidance; NIST/CISA access-control and lifecycle concepts; SLSA/in-toto provenance distinctions; SQLite consistent export constraints.
>
> M40 defines a consent-bound, transport-neutral exchange of a redacted M38 package with one stated recipient for isolated review. It names what the sender approved, which recipient/scope/version was intended, what the recipient actually received or imported, and what remains unknown. It does not create federation, a shared tenant, a remote revocation service, a collaboration authority, or a guarantee that a recipient’s unmanaged copy can be deleted after delivery.

## 0. Decision summary

The smallest safe M40 architecture is:

```text
M38 package + M39 lifecycle/review state
  → explicit sender share consent and scope preview
    → recipient/validator/redaction/schema negotiation
      → bounded package handoff through a user-chosen transport
        → recipient quarantine/import/review
          → offline receipt or explicit unavailable state
            → sender reconciliation without universal revocation claims
```

| Slice | User value | Hard boundary |
|---|---|---|
| **X1 — Share consent** | User sees exactly what is being shared, with whom, and why | Consent is per exchange/scope; it is not a permanent grant or transport permission |
| **X2 — Recipient and scope binding** | The package is intended for a named recipient/profile/scope | A label or email-like string is not proof of recipient identity; unverified identity remains explicit |
| **X3 — Version negotiation** | Sender and recipient avoid silently exchanging unreadable or unsafe packages | Negotiation reveals only bounded capabilities and does not widen evidence scope |
| **X4 — Offline receipt** | Sender knows whether delivery/import/review occurred | A receipt is evidence of a bounded recipient claim, not proof of truth, deletion, or trust |
| **X5 — Isolated recipient review** | Recipient can inspect without joining Hive collaboration or mutating local authority | Recipient review is independent and quarantine-first; no federation or shared authority is created |

M40 does **not** claim secure delivery, verified human identity, universal recipient revocation, remote erasure, non-repudiation, legal/compliance sharing, cryptographic attestation, collaboration, or a successful review merely because a file was sent or opened.

## 1. Current truth and authority boundaries

### 1.1 Existing surfaces

| Surface | Current truth | M40 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| M31 portability | Scoped export/import, omission reports, quarantine-first handling, and conflict review are defined | Transport-neutral package handoff and recipient import boundary | M40 cannot become a second archive or transport authority |
| M38 package | Redacted package, owner projections, validation findings, and plain fallback are defined | Exchange payload and validator profile references | A valid package does not authenticate a recipient or prove delivery |
| M39 lifecycle/review | Expiry/revocation/deletion limits, review invalidation, and disposition states are defined | Sender lifecycle state, recipient review, and receipt limitations | Sender revocation cannot erase copied recipient data |
| M27 collaboration/key packages | Shared membership, device, epoch, and key-package concepts are planned | Security lessons and explicit separation from collaboration | M40 does not create shared workspaces, membership, epochs, or CRDT operations |
| M33 operations | Support, incident, privacy, and deletion receipts are owned there | Bounded escalation reference if a share problem needs review | M40 cannot submit, close, or triage a case |
| M34 TrustSnapshot | Projection of capability, identity, lifecycle, release, and evidence state | Show share/review limitations | Snapshot cannot authorize exchange |
| EventLedger | Append-only local evidence authority | Bounded consent/share/receipt references where owner permits | M40 cannot create a duplicate exchange ledger |
| Keychain/App Sandbox | Platform controls keys, protected resources, and file access | Report denied/locked/unsupported state | No bypass or assumption that a path/identity is trusted |
| Browser shell | Navigation, tabs, private mode, and local inspection remain the wedge | Share failure and offline fallback | Exchange tooling cannot block ordinary browsing |

**Current implementation classification:** Hive has planning contracts for scoped export/import, offline packages, package lifecycle, human disposition, and existing consent/event boundaries, but no verified exchange envelope, recipient binding, version negotiation, share-consent receipt, or recipient-review receipt. M40 remains planning-only until fresh implementation and runtime evidence exist.

### 1.2 Authority matrix

| Concern | Existing authority | M40 rule |
|---|---|---|
| What may be exported | M31/M38/M39 owner scopes | Share only a package already allowed for export; no scope widening during exchange |
| Source evidence truth | M32–M37 owners | Recipient receives a projection/reference, not new source authority |
| Sender package lifecycle | M39 | Exchange cannot revive expired/revoked/superseded content |
| Recipient import/review | Recipient-local M31/M38/M39-compatible boundary | Review is independent and quarantine-first |
| Consent/event evidence | EventLedger and existing consent owners | Record explicit local consent/reference; not a new grant database |
| Identity/key/file access | Apple platform and existing Keychain/worker authorities | Unknown/denied/locked identity remains unknown/denied/locked |
| Operational escalation | M33 | Share failure may reference a case; it cannot auto-submit or close |
| Trust projection | M34 | Project exchange state and limitations only |
| Viewer/validation | M38/M39 | Preserve validator/lifecycle profiles; never rewrite results |
| Browser fallback | Browser/session owner | No exchange dependency may block ordinary browsing or private mode |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A versioned `ConsentBoundExchange` envelope identifying exchange ID, sender scope, intended recipient reference, package ID/hash, package lifecycle state, validator/redaction profile, schema/capability requirements, purpose, data classes, transport-neutral handoff state, and limitations.
2. Explicit sender consent states: previewed, approved, denied, expired, revoked-before-handoff, handed-off, and unable-to-verify. Consent is bound to exact package hash/revision, recipient reference, scope, purpose, and exchange expiry where supplied.
3. Recipient reference semantics distinguishing verified local identity, stated-but-unverified recipient, profile mismatch, missing recipient, and ambiguous recipient. A displayed name or address cannot silently establish identity.
4. Bounded `SchemaNegotiation` for package schema, validator profile, redaction profile, maximum size, supported lifecycle states, and receipt capabilities. Negotiation reveals metadata only and cannot request raw memory, credentials, private scope, or a weaker security boundary.
5. User-chosen transport neutrality: a local file, approved share sheet, removable media, or another explicitly selected path may carry the package; M40 does not implement or endorse a remote transport.
6. Recipient quarantine-first import and review with M38 validation and M39 lifecycle/disposition states. Recipient acceptance-for-review does not make content current, trusted, or authoritative.
7. `RecipientReceipt` states for received, quarantined, validator-run, opened, inspected, accepted-for-review, rejected, deleted-local, unable-to-verify, and not-received. Each state is bounded to what the recipient actually attests.
8. Sender reconciliation showing sent/handed-off/receipt-unavailable/receipt-stale/recipient-revoked-local/recipient-copy-limit states. A sender-side revocation can stop future local handoff but cannot guarantee destruction of an unmanaged recipient copy.
9. Explicit deletion and retention disclosure for sender package, recipient-local package, transport copy, backups, removable media, and external copies. No universal erasure claim.
10. Review invalidation when package hash, lifecycle state, recipient scope, schema/validator/redaction profile, or exchange consent changes.
11. Accessible consent, warning, negotiation, receipt, and unavailable states: keyboard, VoiceOver, large text, contrast, reduced motion, focus/error status, and color-independent meaning.
12. Browser-first fallback for offline mode, private profile, locked Keychain, denied file access, no transport, unsupported schema, missing recipient, unavailable viewer, and M40-disabled mode.
13. Synthetic adversarial fixtures for consent spoofing, recipient spoofing, recipient confusion, replayed receipts, schema downgrade, redaction widening, malicious transport paths, prompt injection, secret inclusion, and deletion overclaim.
14. Minimal local metadata only: exchange identity, scoped consent/review/receipt state, hashes/revisions, bounded recipient reference, data-class summary, limitations, and owner references; no raw package content is required in the exchange ledger.

### 2.2 Explicit non-goals

- A remote share service, relay, cloud inbox, federated audit network, collaboration workspace, tenant/membership authority, or shared operation log.
- A second consent, exchange, EventLedger, package, provenance, policy, trust, retention, or revocation database.
- Universal recipient identity verification, guaranteed secure delivery, non-repudiation, legal evidence admissibility, or cryptographic attestation.
- Universal revocation or deletion of copies already exported, downloaded, emailed, synced, backed up, screen-captured, printed, or stored on another device.
- Automatic transport selection, automatic sharing, silent consent inheritance, automatic recipient acceptance, model-selected recipient, or automatic escalation.
- Accepting downgrade to a weaker schema/redaction/validator/security profile merely to complete exchange; unsupported negotiation is an explicit hold.
- Sending raw browser history, memory, screenshots, page text, prompts, credentials, private profiles, connector bodies, or support packets by default.
- Arbitrary HTML/JavaScript/package execution, shell/tool invocation, network fetching, path traversal, or opening external links automatically.
- Cross-device acknowledgement synchronization, team administration, shared audit rooms, enterprise retention/legal hold, or multi-tenant review authority.
- Runtime implementation, UI implementation, transport configuration, signing-key changes, model training, telemetry, or Swift source edits in this planning milestone.

## 3. Exchange contracts

### 3.1 `ConsentBoundExchange`

```text
ConsentBoundExchange {
  exchange_id: stable UUID
  schema_version: semantic version
  sender_scope: typed local/profile/workspace scope
  intended_recipient: verified-local | stated-unverified | missing | ambiguous
  recipient_ref: bounded reference or null
  purpose: bounded user-authored purpose
  package_id: UUID
  package_revision: exact M38 hash/revision
  package_lifecycle: M39 state at consent
  validator_profile: exact M38 profile
  redaction_profile: exact M38 profile
  data_classes: allowlisted category/count summary
  schema_requirements: bounded capability set
  consent_state: previewed | approved | denied | expired | revoked_before_handoff |
                 handed_off | unable_to_verify
  consent_generation: stable local generation
  approved_at: Date or null
  expires_at: authoritative Date or null
  transport_state: not_selected | selected | handed_off | unavailable | unknown
  receipt_ref: RecipientReceipt ID or null
  acknowledgement_state: not_requested | unavailable | received | stale | conflicted
  external_copy_limits: bounded list
  limitations: bounded list
}
```

`approved` means the sender explicitly approved this exact package, scope, purpose, recipient reference, and profile. It is not a grant to the recipient, not permission to inspect canonical stores, and not consent to future packages. Changing any bound creates a new exchange or requires fresh review.

### 3.2 `SchemaNegotiation`

```text
SchemaNegotiation {
  negotiation_id: stable UUID
  exchange_id: UUID
  sender_schema: exact version
  recipient_schema: exact version or unavailable
  sender_validator: exact profile
  recipient_validator: exact profile or unavailable
  sender_redaction: exact profile
  recipient_redaction: exact profile or unavailable
  max_package_bytes: bounded value or unknown
  supported_states: allowlisted lifecycle/review states
  receipt_capabilities: allowlisted states
  result: match | compatible_with_limits | unsupported | unsafe_downgrade |
          recipient_unavailable | malformed | unknown
  limitations: bounded list
}
```

Negotiation is metadata-only. It cannot inspect or request omitted content. A compatible result does not mean the recipient is trusted or that review will succeed. Unknown security-critical fields, weaker redaction, unsupported validator profiles, and incompatible lifecycle semantics produce an explicit hold rather than a silent downgrade.

### 3.3 `RecipientReceipt`

```text
RecipientReceipt {
  receipt_id: stable UUID
  exchange_id: UUID
  recipient_ref: stated bounded reference
  package_id: UUID
  package_revision: exact hash/revision or unknown
  received_state: not_received | received | quarantined | rejected | deleted_local |
                  unable_to_verify
  review_state: not_run | validator_run | opened | inspected | accepted_for_review |
                retained | re_export_requested | unable_to_verify
  lifecycle_state_at_review: M39 state or unknown
  validator_profile: exact profile or unknown
  redaction_profile: exact profile or unknown
  recipient_scope: typed scope or unknown
  created_at: Date or null
  sender_visibility: local_only | returned_receipt | unavailable
  external_copy_limits: bounded list
  limitations: bounded list
}
```

A receipt is a recipient statement or local observation bounded to the fields it contains. It is not proof of human identity, truthful review, package authenticity beyond M38 findings, deletion of other copies, incident closure, consent to future exchanges, or trust in the sender. A sender must show `receipt-stale`, `receipt-unavailable`, or `unable-to-verify` rather than infer success.

## 4. Consent, transport, revocation, and review rules

### 4.1 Consent preview

Before approval, the sender sees:

```text
recipient reference + verified/unverified state
package ID/hash and lifecycle state
purpose and exact scope
redaction profile and data-class summary
validator/schema requirements
transport selected by the user
retention/external-copy limitations
expiry/revocation limitations
next action and cancel path
```

A page, connector, imported package, model, or recipient message cannot request, modify, or approve sharing. Consent is denied on unknown critical scope, missing package lifecycle state, private/raw content, unsupported redaction, ambiguous recipient, or an unavailable deletion/retention disclosure.

### 4.2 Transport neutrality

M40 does not choose a network, upload service, email provider, or collaboration channel. A user may choose an explicitly supported local/share path; the exchange record states that Hive does not control the transport or recipient storage. Transport copies, mailboxes, removable media, backups, screenshots, and recipient exports are outside Hive’s deletion authority unless an existing owner provides exact evidence.

### 4.3 Revocation and deletion

Before handoff, `revoked_before_handoff` blocks delivery. After handoff, sender revocation prevents new sender-controlled handoffs and marks the local exchange state; it does not delete or disable a recipient’s unmanaged copy. Recipient deletion receipts report only the recipient’s stated/local scope and remain unverified unless an existing authority provides stronger evidence. A package lifecycle expiration may make future local review unavailable, but cannot retroactively erase a copied payload.

### 4.4 Recipient review

Recipient review begins in quarantine and runs M38 validation before M39 disposition. It remains isolated from the recipient’s canonical memory, policy, release, consent, and package stores until an existing owner-controlled explicit operation—not M40 exchange metadata—permits any scoped local promotion. The default is inspect-only; a reviewer’s acceptance-for-review is never a capability grant or truth certification.

## 5. Work packages

### M40-A — Share consent and recipient binding

Define `ConsentBoundExchange`, exact package/scope/purpose/profile binding, recipient verified/unverified/missing/ambiguous states, preview copy, denial/revocation-before-handoff, and local consent references without creating a second grant store.

**Done when:** sharing requires explicit user approval for one package and recipient scope; changed hash, lifecycle, redaction, validator, purpose, or recipient requires a new decision; no page/model/recipient content can approve or widen exchange.

### M40-B — Schema, validator, and capability negotiation

Define `SchemaNegotiation`, metadata-only negotiation, supported lifecycle/review states, redaction/validator profiles, size limits, receipt capabilities, safe compatibility, unsupported/unknown/unsafe-downgrade holds, and no-content disclosure.

**Done when:** sender and recipient cannot silently downgrade security-critical profiles or revive unsupported lifecycle states; negotiation never requests omitted data or widens scope.

### M40-C — Transport-neutral handoff and offline receipts

Define user-selected handoff states, `RecipientReceipt`, sender reconciliation, receipt freshness/absence, duplicate/replay/conflict handling, and plain JSON/text receipt fallback. No transport is selected or implemented by M40.

**Done when:** sent, handed-off, received, quarantined, reviewed, rejected, deleted-local, not-received, stale, and unable-to-verify states are distinct; a receipt cannot create a success or identity claim outside its fields.

### M40-D — Revocation, deletion, and copy limitations

Define pre-handoff revocation, post-handoff sender limits, recipient deletion receipts, transport/backup/external-copy disclosures, M39 lifecycle interaction, and no-universal-erasure copy. Reconcile with M31, M33, M35, M38, Keychain, and file-access boundaries.

**Done when:** UI and receipts state exactly what sender/recipient/local operations can change; unmanaged copies remain an explicit limitation; expiration/revocation cannot claim retroactive erasure.

### M40-E — Isolated recipient review and browser-first validation

Define quarantine-first recipient review, M38/M39 validator/lifecycle continuity, no-write/no-tool/no-network behavior, accessible consent/receipt/error states, private/locked/denied/offline handling, and browser-first fallback.

**Done when:** recipient review cannot mutate canonical authority by default; review remains understandable without transport, viewer, key, permission, or network; navigation, tabs, private mode, and local inspection remain usable with M40 disabled.

## 6. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M40-01 | Explicit consent preview | Data classes, recipient, scope, purpose, profile, and limits visible |
| M40-02 | Consent denied | No handoff; local denial only |
| M40-03 | Consent expires before handoff | Handoff blocked |
| M40-04 | Consent revoked before handoff | Handoff blocked; no delivery claim |
| M40-05 | Package hash changes after approval | New consent required |
| M40-06 | Package lifecycle expires after preview | Approval blocked or re-review required |
| M40-07 | Recipient verified-local match | Bound to exact local recipient scope |
| M40-08 | Recipient stated-but-unverified | Explicit limitation; no identity claim |
| M40-09 | Recipient mismatch | Handoff blocked |
| M40-10 | Recipient missing/ambiguous | Handoff blocked; no silent default |
| M40-11 | Schema exact match | Negotiation match |
| M40-12 | Compatible schema with limits | Limits visible; no green trust claim |
| M40-13 | Unsupported schema | Explicit hold; no downgrade |
| M40-14 | Malformed negotiation | Rejected/quarantined |
| M40-15 | Security-critical unknown field | Fail closed; no permissive decode |
| M40-16 | Weaker redaction requested | Unsafe downgrade; blocked |
| M40-17 | Validator profile mismatch | Re-export/review required |
| M40-18 | Size limit exceeded | Handoff blocked or bounded failure |
| M40-19 | Receipt capability mismatch | Receipt unavailable/limited |
| M40-20 | Negotiation requests raw memory | Rejected as scope widening |
| M40-21 | User-selected local file handoff | Transport selected; Hive-control limits visible |
| M40-22 | No transport selected | No handoff; browser unaffected |
| M40-23 | Handoff completed locally | Handed-off only; delivery not inferred |
| M40-24 | Recipient receives package | Received statement scoped to receipt |
| M40-25 | Recipient quarantines package | Quarantined; no review success |
| M40-26 | Recipient validator runs | Validator result preserved; no trust upgrade |
| M40-27 | Recipient opens package | Opened only; no acceptance claim |
| M40-28 | Recipient accepts for review | Review state only; source truth unchanged |
| M40-29 | Recipient rejects package | Rejected receipt; no sender success claim |
| M40-30 | Receipt missing | Receipt-unavailable; no delivery inference |
| M40-31 | Receipt stale | Stale; sender re-review required |
| M40-32 | Receipt replayed | Duplicate/replay finding; no new state |
| M40-33 | Receipt package hash mismatch | Invalid receipt; no reconciliation |
| M40-34 | Recipient deletion-local receipt | Recipient-local claim only |
| M40-35 | Sender revokes before handoff | Blocked |
| M40-36 | Sender revokes after handoff | Future local handoff blocked; copy limit disclosed |
| M40-37 | Recipient ignores sender revocation | Expected unmanaged-copy limitation |
| M40-38 | Backup/transport copy remains | No universal erasure claim |
| M40-39 | Tombstone/expiry after handoff | Future local review limited; copied payload not erased claim |
| M40-40 | Private profile selected | Excluded unless explicit allowed synthetic/non-content scope |
| M40-41 | Locked Keychain | Consent/key path unavailable; no bypass |
| M40-42 | Denied file permission | Handoff unavailable; no path escape |
| M40-43 | Path traversal in transport metadata | Rejected before use |
| M40-44 | HTML/script in receipt | Inert rendering; no execution |
| M40-45 | Prompt injection in recipient message | Ignored as untrusted content |
| M40-46 | VoiceOver consent/receipt flow | Status, scope, action, limitation announced |
| M40-47 | Large text/high contrast | No clipping or color-only meaning |
| M40-48 | Reduced motion/offline | Static review and receipt fallback usable |
| M40-49 | M40 disabled | Navigation, tabs, private mode, local inspection remain usable |
| M40-50 | Final exchange review | Consent, recipient, scope, package, negotiation, receipt, limits, and next action present |

## 7. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M40-A | Explicit consent | Share requires one visible, scoped user decision; no silent inheritance |
| M40-B | Recipient binding | Recipient identity is verified, stated-unverified, missing, or ambiguous; no invented identity |
| M40-C | Scope binding | Package hash, scope, purpose, lifecycle, validator, and redaction profiles are exact |
| M40-D | Negotiation safety | Schema/capability negotiation is metadata-only; unsupported/unsafe downgrade fails closed |
| M40-E | Transport neutrality | M40 does not choose or implement a remote transport |
| M40-F | Receipt bounds | Recipient receipts state only what was received/reviewed/deleted locally and remain limited/unverified where appropriate |
| M40-G | Replay/conflict safety | Duplicate, stale, mismatched, and replayed receipts cannot alter current exchange state |
| M40-H | Revocation honesty | Pre-handoff revocation blocks delivery; post-handoff revocation cannot erase unmanaged copies |
| M40-I | Deletion honesty | Sender, recipient, transport, backup, and external-copy scopes remain distinct |
| M40-J | Recipient isolation | Quarantine/review cannot mutate canonical stores, policy, consent, release, or permissions by default |
| M40-K | Accessibility/privacy/fallback | Consent, errors, receipts, offline/locked/denied/private states remain understandable and local |
| M40-L | Browser-first/no false readiness | M40 failure does not block browsing; exchange is not trust, certification, collaboration, or ship evidence |

## 8. Safety, privacy, and claim boundaries

M40 is a consent and review boundary, not a reason to collect more. Exchange metadata contains only package/exchange identity, exact revision/hash, bounded recipient reference, purpose, scope, data-class summary, profiles, consent state, transport state, receipt state, limitations, and owner references. Raw page text, memory, screenshots, prompts, credentials, private profile contents, connector bodies, and support packet contents are not required.

A recipient reference cannot establish its own identity. A package cannot approve its own sharing, widen its scope, request secrets, select transport, invoke a tool, or revoke itself. A sender consent record cannot grant recipient access to canonical stores. A receipt cannot prove human identity, truthful inspection, deletion of unmanaged copies, incident closure, future consent, or product trust. A signature or hash remains scoped under M38 and is not universal attestation.

After handoff, sender revocation can govern future sender-controlled actions only. It cannot guarantee deletion or disablement of unmanaged recipient copies in recipient storage, transport systems, backups, screenshots, printouts, or other devices. M40 must say this plainly at consent, receipt, and revocation points. `not_received`, `received`, `quarantined`, `reviewed`, `rejected`, `deleted_local`, `stale`, and `unable_to_verify` are valid states.

M40 must never be described as secure delivery certification, verified human identity, universal revocation, legal evidence exchange, cryptographic attestation, collaboration, accessibility conformance, incident closure, or production readiness.

## 9. Execution order and handoff

Implement M40-A as documentation and fixture-contract reconciliation against M31, M38, M39, EventLedger, and existing consent owners before adding any share UI. Implement M40-B with synthetic schemas/profiles and no raw content. Implement M40-C using local fake transports and synthetic receipts; no network client. Implement M40-D with fake revocation/deletion/backup-copy states. Implement M40-E with quarantine-first recipient fixtures and network-denied, private, locked, denied, script-disabled, and accessibility-manual states.

The next smallest safe action is **M40-A: publish the `ConsentBoundExchange`, `SchemaNegotiation`, and `RecipientReceipt` contracts plus the sender/recipient scope and receipt-limitation matrix, then reconcile them with M31 portability, M33 operational/deletion receipts, M34 TrustSnapshot, M35 lifecycle, M38 package/validator state, M39 review/disposition, EventLedger, Keychain/file-access boundaries, and browser/session authorities**. Do not add a remote transport, revocation service, second exchange ledger, universal recipient identity, automatic sharing, or runtime implementation as part of M40 planning.
