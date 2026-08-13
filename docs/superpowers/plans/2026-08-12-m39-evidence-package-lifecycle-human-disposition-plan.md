# M39 — Evidence Package Lifecycle & Human Disposition Execution Plan

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M39 Evidence Package Lifecycle & Human Disposition
> **Depends on:** M0–M6 storage/provenance/recovery; M10–M17 browser/context/action/worker boundaries; M25 engine/update ownership; M26 ownership/policy; M27 sync/device/epoch state; M28 Flow authority; M29 context governance; M31 portability/extensibility; M32 release receipts/distribution/recovery; M33 operations; M34 TrustSnapshot/control plane; M35 evidence/policy lifecycle governance; M36 reproducible evidence/recovery rehearsal; M37 user-visible change/deprecation/support horizon; M38 offline evidence traceability/audit package.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities:** M31 export/import and omission semantics; M35 expiry, rotation, quarantine, tombstone, and deletion boundaries; M38 package/redaction/validation contracts; M32 release/update identity; Apple Keychain, App Sandbox, and file-access lifecycle documentation; SQLite deletion/WAL/backup constraints; OWASP untrusted-file and path-traversal guidance; W3C WCAG status/error/accessibility guidance; NIST/CISA lifecycle and revocation concepts.
>
> M39 governs what happens after an `OfflineAuditPackage` is created or received: how it becomes stale or revoked, how local retention and deletion are disclosed, how a package is reopened or imported for review without becoming authority, how a reviewer records a bounded disposition, and how inaccessible or untrusted viewer states degrade. M39 is a lifecycle and human-review contract over M31–M38. It is not a second evidence store, policy engine, deletion service, trust root, support system, compliance program, or automatic remediation loop.

## 0. Decision summary

The smallest safe M39 architecture is:

```text
M38 package + owner/lifecycle references
  → lifecycle evaluation: current | stale | expired | revoked | superseded | quarantined
    → explicit reopen/import review with scope and redaction inspection
      → human disposition: retain | delete-local | quarantine | re-export | escalate | unable-to-verify
        → owner-scoped receipt and M34/M37 limitation projection
          → browser-first continuation when package tooling is absent or blocked
```

| Slice | User value | Hard boundary |
|---|---|---|
| **L1 — Package lifecycle** | Users know whether an evidence package is current, stale, expired, revoked, or superseded | M39 evaluates owner-supplied state; it cannot invent expiry or revoke upstream authority |
| **L2 — Retention and deletion** | Users understand what local deletion does and does not erase | Local deletion is scoped and observable; it is not universal erasure or a legal retention decision |
| **L3 — Reopen/import review** | Received packages can be inspected safely before becoming part of a local review | Import is quarantine-first and inert; package content cannot mutate Hive or grant authority |
| **L4 — Human disposition** | Findings have an explicit next state instead of disappearing into “valid” | Disposition is a review record, not a release, policy, incident, or trust decision |
| **L5 — Viewer trust and fallback** | Review remains understandable when the viewer, key, file access, or accessibility path is unavailable | Viewer availability never upgrades evidence state; plain output remains bounded and inert |

M39 does **not** claim secure deletion from ordinary file removal, universal revocation of copied packages, legal hold applicability, cryptographic erasure unless an existing owner actually supplies that capability and evidence, automatic expiry enforcement, package authenticity from a filename/hash alone, or product readiness from a completed review. A package review is not a capability grant.

## 1. Current truth and authority boundaries

### 1.1 Existing surfaces

| Surface | Current truth | M39 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| M31 portability | Export/import scope, omission reports, quarantine-first handling, conflict review, and deletion limits are defined | Package open/import transport and owner-scoped deletion | M39 cannot become a second general archive/import authority |
| M35 lifecycle | Expiry, generations, rotation, quarantine, tombstones, and cleanup boundaries are defined | Evaluate package references against owner lifecycle state | A package-local timestamp cannot revoke an upstream capability |
| M38 package | Deterministic redaction, validation result, chain findings, and inert/plain fallback are defined | Lifecycle metadata, reopen review, and disposition reference | A valid package is not automatically current or trusted |
| M32 release/update | Artifact/channel/signing/update/rollback evidence is owned there | Show whether referenced release evidence is current or historical | M39 cannot re-sign, update, rollback, or alter release state |
| M33 operations | Trust cases, support packets, incidents, and deletion/retention receipts are owned there | Link bounded operational review/escalation references | Disposition cannot close, submit, or triage a case |
| M34 TrustSnapshot | User-facing projection of capability/lifecycle/identity/release/evidence state | Project package limitations and review status | Projection cannot authorize retention or deletion |
| M37 notices/reviews | Change notices and review/re-review semantics are defined | Explain package lifecycle changes and required re-review | Viewing a package does not acknowledge a product notice |
| EventLedger | Append-only event authority for consequential local events | Record bounded package-open/review/disposition references where owner permits | M39 cannot create a duplicate audit ledger |
| Keychain/App Sandbox/filesystem | Access and key lifecycle are platform-bound and permissioned | Report locked/missing/denied file/key state | M39 cannot bypass TCC, Keychain, sandbox, or copied-file limitations |
| Browser shell | Navigation, tabs, private mode, and local inspection are the acquisition wedge | Keep browser usable with package tools disabled | Evidence tooling cannot block ordinary browsing |

**Current implementation classification:** M38 is planning-only and no verified package lifecycle, expiry evaluator, quarantine import flow, disposition receipt, package deletion boundary, or viewer trust policy exists. M39 remains planning-only until fresh implementation and runtime evidence exist.

### 1.2 Authority matrix

| Concern | Existing authority | M39 rule |
|---|---|---|
| Package transport/export scope | M31 | Use M31 scope, omission, quarantine, and conflict semantics |
| Source evidence truth | M32–M37 owners | Re-check owner generation/state; never promote package text |
| Lifecycle/expiry/revocation | M35 and source owner | Require authoritative state or report unknown; no local invention |
| Local file/key access | Apple platform/Keychain and existing Hive owner | Denial/lock is an explicit unavailable state, never a bypass trigger |
| Consequential review event | EventLedger | Record only bounded local reference after review action, not raw package contents |
| Incident/support escalation | M33 | Link or request bounded human review; M39 cannot close or send |
| Trust projection | M34 | Project lifecycle/disposition limitations; never authorize |
| User-facing change/review | M37 | Display re-review requirement; package open is not notice acknowledgement |
| Package serialization/validation | M38 | Preserve validator profile and result; M39 cannot rewrite a result to green |
| Browser fallback | Browser/session owner | Ordinary browsing remains usable when all M39 surfaces fail |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A versioned `PackageLifecycle` record containing package ID, source/profile scope, owner-generation references, lifecycle state, authoritative state references, last evaluation result, and bounded limitations.
2. Typed lifecycle states: current, current-with-limitations, stale, expired, revoked, superseded, quarantined, deleted-local, unavailable, unknown, synthetic-only, and not-applicable.
3. Explicit distinction between owner revocation, package expiry, local deletion, source tombstoning, key unavailability, viewer failure, and inability to verify. None may silently stand in for another.
4. Retention metadata naming local retention intent, expiry source, deletion scope, external-copy limitation, backup limitation, and whether a user decision is still required. No invented legal retention period or owner policy.
5. Quarantine-first reopen/import flow: package bytes are treated as untrusted; extraction is bounded; paths cannot escape an allowed destination; content is inert; package data cannot write to Hive stores, invoke tools, alter policy, or become current evidence.
6. Pre-review inspection showing package origin/profile, schema/validator versions, redaction and omission report, synthetic/historical state, required references, signature-scope result, lifecycle state, and limitations before any disposition.
7. A `PackageReview` record distinguishing opened, inspected, accepted-for-review, rejected, deferred, retained, deleted-local, quarantined, re-export-requested, escalated, and unable-to-verify.
8. Human disposition rules requiring explicit scope, reviewer intent, package lifecycle state, known limitations, next action, and owner references. Disposition does not change source truth or create a grant.
9. Reopen/review invalidation when package contents, validator profile, owner generation, revocation/expiry state, redaction profile, or scope changes.
10. Local deletion semantics that report package-file deletion, local index deletion, key deletion where an existing owner controls the key, backup/external-copy limits, and remaining references separately.
11. Viewer trust states for missing viewer, blocked script, unsupported format, unavailable key, denied file permission, failed integrity check, and accessibility/manual review unavailable. Plain JSON/text remains the fallback.
12. Browser-first behavior for offline mode, private profile, locked Keychain, denied file access, missing owner reference, M38-disabled mode, and package deletion/unavailability.
13. Local-only bounded review metadata and deletion/retention semantics; no package-content upload, engagement scoring, hidden analytics, or remote viewer telemetry.
14. Synthetic adversarial fixtures for expiry spoofing, revocation spoofing, stale-cache revival, package poisoning, path traversal, XSS-like payloads, secret inclusion, deletion overclaim, and reviewer coercion.

### 2.2 Explicit non-goals

- A second package database, evidence ledger, provenance authority, policy engine, trust root, revocation service, retention scheduler, ticketing system, or compliance archive.
- Automatic expiry deletion, automatic revocation, automatic quarantine release, automatic repair, automatic migration, model-selected disposition, or silent source-state mutation.
- Claiming that a local package deletion erases copies in backups, email, cloud storage, screenshots, file sync, removable media, or another reviewer’s device.
- Claiming cryptographic erasure, secure media sanitization, legal hold, regulatory retention, or compliance certification without an existing authoritative implementation and fresh evidence.
- Accepting a package because its filename, path, displayed owner, hash, or embedded text looks trustworthy; supplied signatures remain scoped checks under M38.
- Treating viewer execution, package opening, human acceptance-for-review, or a passing validator as consent, release approval, incident closure, current policy, or capability grant.
- Sending packages or review metadata to remote services by default; no network-required lifecycle path is part of M39.
- Full archive browsing, arbitrary file import, shell/tool execution, arbitrary HTML/JavaScript execution, or opening package URLs automatically.
- Cross-device review synchronization, shared audit rooms, enterprise retention/legal hold, or multi-tenant disposition authority.
- Runtime implementation, UI implementation, release configuration, signing-key changes, model training, telemetry, or changes to Swift source in this planning milestone.

## 3. Lifecycle and review contracts

### 3.1 `PackageLifecycle`

```text
PackageLifecycle {
  package_id: stable UUID
  lifecycle_schema: semantic version
  scope: typed local/profile/workspace scope
  source_profile: local | synthetic | release | historical | mixed | unknown
  owner_refs: exact M32–M37 references or unavailable
  owner_generations: exact generation map or unknown
  state: current | limited | stale | expired | revoked | superseded |
         quarantined | deleted_local | unavailable | unknown | synthetic_only | not_applicable
  state_source: authoritative owner | M35 | M38 validator | local file state | unknown
  evaluated_at: authoritative Date or null
  expires_at: authoritative Date or null
  revocation_ref: exact reference or null
  superseded_by: package ID or null
  retention_ref: owner policy or unknown
  deletion_scope: package_file | local_index | local_key | source_reference | none | unknown
  external_copy_limits: bounded list
  limitations: bounded list
  next_action: none | inspect | re_export | obtain_receipt | quarantine | delete_local |
               escalate | unavailable
}
```

A local clock, filename, embedded text, or model output cannot establish `expired`, `revoked`, `current`, or `superseded` without the declared source authority. If no authority is available, the state is `unknown` or `stale`, not current and not automatically deleted.

### 3.2 `PackageReview`

```text
PackageReview {
  review_id: stable UUID
  package_id: UUID
  package_revision: exact package hash/revision
  lifecycle_state_at_review: typed state
  validator_profile: exact M38 profile
  redaction_profile: exact M38 profile
  scope_reviewed: typed scope
  state: opened | inspected | accepted_for_review | rejected | deferred |
         retained | deleted_local | quarantined | re_export_requested |
         escalated | unable_to_verify
  disposition_reason: bounded structured reason
  owner_refs: exact references or unavailable
  user_action: none | view_findings | retain | delete_local | quarantine |
               re_export | escalate | close_review
  created_at: Date
  superseded_by: review ID or null
  limitations: bounded list
}
```

`accepted_for_review` means only that the user chose to inspect the package under the displayed scope and limitations. It is not evidence acceptance, policy consent, release approval, incident closure, or a trust decision. A review becomes stale when the package hash, lifecycle state, owner generation, validator/redaction profile, or scope changes.

### 3.3 Deletion and retention receipt

```text
PackageDeletionReceipt {
  receipt_id: stable UUID
  package_id: UUID
  requested_scope: package_file | local_index | local_key | source_reference | all_local
  completed_scope: typed list
  pending_scope: typed list
  blocked_scope: typed list
  external_copy_limits: bounded list
  backup_limits: bounded list
  key_state: not_applicable | destroyed_by_owner | unavailable | unchanged | unknown
  remaining_reference_state: none | local_tombstone | owner_reference | unknown
  created_at: Date
  next_action: none | retry | review | contact_owner | unavailable
}
```

A delete button cannot report `all_local` complete when file access, key access, dependent indexes, or owner deletion evidence is missing. Local deletion and source deletion remain separate. A package tombstone preserves only the minimum lifecycle reference needed to explain why content is unavailable.

## 4. Reopen/import and viewer trust

### 4.1 Quarantine-first flow

```text
select package
  → identify bytes and bounded destination
    → reject path traversal/unsupported size/type
      → quarantine immutable copy
        → run M38 structural/redaction/integrity/traceability validation
          → show lifecycle, omissions, owner refs, and limitations
            → explicit inspect/review/disposition decision
```

No package field can select its own extraction destination, request a network fetch, invoke a command, load executable content, alter expected hashes, or mark itself current. A failed cleanup leaves the quarantine scope blocked until an explicit cleanup receipt exists.

### 4.2 Viewer states

The viewer must expose distinct states for missing viewer, format unsupported, integrity mismatch, signature not supplied, key unavailable, file permission denied, package expired/revoked, lifecycle unknown, validation unavailable, accessibility/manual review unavailable, and plain fallback. The viewer cannot transform `unknown` into `valid`, and a functioning viewer cannot transform `valid` into `trusted`.

Untrusted package strings are rendered as inert text. The static viewer must not interpret them as markup, scripts, commands, paths, or navigation targets. If a browser-based viewer is used, the plan must define a network-denied/local-only resource model and a plain JSON/text path that remains usable when scripting is disabled or unavailable.

### 4.3 Human disposition

A reviewer may retain locally, delete local copies, quarantine, request a fresh export, escalate to an existing owner, or mark unable-to-verify. Each option shows scope, consequences, external-copy limitations, and whether the action changes only the local review record or also invokes an existing owner-controlled operation. M39 never turns a reviewer’s disposition into an upstream policy or release state.

## 5. Work packages

### M39-A — Package lifecycle and authoritative state evaluation

Define `PackageLifecycle`, owner-generation lookup, current/stale/expired/revoked/superseded/quarantined/deleted/unavailable states, authoritative versus local state, clock-skew/unknown handling, and M38 validator continuity.

**Done when:** a package cannot become current from local text, filename, timestamp, or model output; missing owner state is explicit; stale, expired, revoked, and superseded states remain distinct.

### M39-B — Retention, deletion, and external-copy limits

Define retention intent, local package/index/key deletion scope, owner-scoped source deletion, backup/external-copy limitations, tombstone behavior, blocked/pending receipts, and no-universal-erasure copy. Reconcile with M31, M33, M35, M6 encryption, Keychain, SQLite/WAL, and M38 omissions.

**Done when:** every deletion result separates completed, pending, blocked, and unknown scope; no local operation claims to erase unmanaged copies; deletion of a package cannot delete canonical source evidence without its owner’s path.

### M39-C — Quarantine-first reopen/import review

Define bounded package selection, file/type/size/path checks, immutable quarantine, cleanup/retry, M38 validation-before-review, private/synthetic scope handling, and no-write/no-network/no-tool guarantees.

**Done when:** malicious or malformed package content is inert and quarantined; paths cannot escape the selected boundary; import cannot alter Hive stores, grant authority, execute content, or silently join a review scope.

### M39-D — Human disposition and review invalidation

Define `PackageReview`, accepted-for-review versus trusted/current distinctions, retain/delete/quarantine/re-export/escalate/unable-to-verify choices, stale-review invalidation, bounded local review metadata, and accessibility of status/error/action flows.

**Done when:** every disposition states what it changes and does not change; package hash, lifecycle, owner generation, validator profile, redaction profile, or scope changes invalidate old review; no reviewer action closes an incident or grants a capability.

### M39-E — Viewer trust, fallback, and browser-first validation

Define unavailable viewer/key/file-access/manual/accessibility states, inert rendering, network-denied/local-only requirements, plain JSON/text fallback, offline/private/locked/denied behavior, and final browser-first validation.

**Done when:** review remains understandable without the viewer, network, key, permission, or accessibility harness; `unknown` and `unavailable` remain visible; navigation, tabs, private mode, and local inspection remain usable with M39 disabled.

## 6. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M39-01 | Current package with authoritative owner refs | Current only within declared scope |
| M39-02 | Package with no owner refs | Unknown/quarantined; no current claim |
| M39-03 | Local timestamp in the past | Does not establish expiry |
| M39-04 | Authoritative expiry reached | Expired state; action visible |
| M39-05 | Expiry date missing | Unknown/stale; no automatic deletion |
| M39-06 | Revocation reference supplied | Revoked state with exact reference |
| M39-07 | Revocation text in package body | Ignored as untrusted |
| M39-08 | Revocation source unavailable | Unknown/stale; no permissive current state |
| M39-09 | Superseding package reference | Superseded state; replacement not auto-opened |
| M39-10 | Stale owner generation | Stale/re-review required |
| M39-11 | Clock moves backward | Unknown/stale guard; no premature or delayed trust claim |
| M39-12 | Clock moves forward | Local time alone cannot revoke authority |
| M39-13 | Mixed synthetic/production package | Mixed classification remains visible |
| M39-14 | M38 validator profile changes | Existing review stale |
| M39-15 | Redaction profile changes | Existing review stale; re-inspection required |
| M39-16 | Package hash changes | Existing review invalidated |
| M39-17 | Scope changes profile to workspace | Existing review invalidated |
| M39-18 | Viewer says “trusted” | Rejected unless owner evidence supports exact claim |
| M39-19 | Valid package opened | Opened only; no acceptance or grant |
| M39-20 | Accepted for review | Review recorded; source truth unchanged |
| M39-21 | Rejected package | Quarantine retained; no source mutation |
| M39-22 | Deferred review | Deferred state visible and bounded |
| M39-23 | Retain locally | Local intent recorded; no external retention claim |
| M39-24 | Delete package file | File scope reported separately |
| M39-25 | Delete local index only | Package file remains and is disclosed |
| M39-26 | Key unavailable during deletion | Key scope blocked/unknown; no complete claim |
| M39-27 | Dependent index deletion fails | Partial receipt; retry visible |
| M39-28 | Backup copy remains | External/backup limitation visible |
| M39-29 | Cloud/file-sync copy remains | No universal erasure claim |
| M39-30 | Owner source deletion requested | M39 cannot execute without owner path |
| M39-31 | Tombstone after local deletion | Non-content reference remains bounded |
| M39-32 | Quarantine package with `../` path | Rejected before extraction |
| M39-33 | Oversized archive | Rejected/bounded; no partial silent import |
| M39-34 | Unsupported type | Quarantined/unavailable |
| M39-35 | Archive symlink escape | Rejected; destination unchanged |
| M39-36 | HTML/script payload | Inert text; no execution |
| M39-37 | Package requests network | Blocked; offline review remains |
| M39-38 | Package requests shell/tool action | Ignored as untrusted |
| M39-39 | Package contains credential-shaped data | Omitted/rejected without echo |
| M39-40 | Private profile package | Excluded or synthetic-only |
| M39-41 | Locked Keychain | Unavailable; no bypass |
| M39-42 | Denied file permission | Unavailable; no path escape |
| M39-43 | Viewer missing | Plain JSON/text fallback |
| M39-44 | Viewer script disabled | Plain fallback remains understandable |
| M39-45 | Accessibility harness unavailable | Manual/unavailable state visible |
| M39-46 | VoiceOver review | Status/action/limitation announced |
| M39-47 | Large text/high contrast | No clipping or color-only status |
| M39-48 | Reduced motion | Review and deletion remain usable |
| M39-49 | M39 disabled | Navigation, tabs, private mode, local inspection remain usable |
| M39-50 | Final disposition review | Scope, lifecycle, limitations, action, owner refs, and receipt state present |

## 7. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M39-A | Lifecycle authority | Current/stale/expired/revoked/superseded/quarantined/deleted/unavailable/unknown states map to owner or explicit local limit |
| M39-B | No local trust invention | Clock, filename, body text, viewer, model, or hash cannot create current/revoked authority |
| M39-C | Retention honesty | Retention intent, expiry source, deletion scope, backups, external copies, and unknowns are distinct |
| M39-D | Deletion receipt | Completed/pending/blocked/unknown scopes are explicit; no universal erasure claim |
| M39-E | Quarantine safety | Type/size/path/symlink/content boundaries reject unsafe package import before extraction/use |
| M39-F | No authority mutation | Opening/reviewing/importing cannot write policy, evidence, permissions, release, or canonical memory |
| M39-G | Review continuity | Package hash/scope/lifecycle/generation/validator/redaction changes stale old review |
| M39-H | Disposition honesty | Retain/delete/quarantine/re-export/escalate/unable-to-verify states describe exact local effect |
| M39-I | Viewer trust | Viewer availability does not upgrade evidence; inert rendering and network-denied behavior are defined |
| M39-J | Fallback | Plain JSON/text remains usable when viewer, key, file access, network, or script is unavailable |
| M39-K | Accessibility/privacy | Keyboard, VoiceOver, large text, contrast, reduced motion, offline/private/locked states remain equivalent |
| M39-L | Browser-first/no false readiness | M39 failure does not block browsing; review/disposition is not consent, certification, closure, or ship evidence |

## 8. Safety, privacy, and claim boundaries

M39 is a lifecycle and review boundary, not a reason to retain more. Package review metadata is limited to package identity/hash, scope, lifecycle state, validator/redaction profile, user disposition, bounded owner references, limitations, and receipt status. Raw package content, page text, prompts, credentials, private memory, connector bodies, screenshots, and engagement history are not required.

A package cannot revoke itself, extend its own expiry, establish its own trust root, choose its own retention, execute viewer code, request a tool, alter a source, close a case, or grant a capability. A reviewer’s acceptance-for-review is not acceptance of truth. A local delete is not universal erasure. An expired or revoked package is not proof that its copied contents disappeared. A plain-text fallback is not evidence validation.

`current`, `stale`, `expired`, `revoked`, `superseded`, `quarantined`, `deleted_local`, `unavailable`, `synthetic_only`, and `unknown` are truthful states, not failures to hide. M39 must never be described as secure deletion certification, legal retention compliance, cryptographic revocation, accessibility conformance, incident closure, or production readiness.

## 9. Execution order and handoff

Implement M39-A as documentation and fixture-contract reconciliation against M31, M35, and M38 before adding any evaluator. Implement M39-B with synthetic package files, fake keys, fake owner receipts, and disposable directories only; never use real credentials, Keychain items, private memory, production packages, or unmanaged backups. Implement M39-C with quarantine/path/type/size fixtures and no executable content. Implement M39-D with synthetic reviewer actions and stale-review transitions. Implement M39-E with network-denied, script-disabled, permission-denied, locked, private, and manual/unavailable states.

The next smallest safe action is **M39-A: publish the `PackageLifecycle`, `PackageReview`, and `PackageDeletionReceipt` contracts plus the owner-state/review-invalidation matrix, then reconcile them with M31 portability, M33 deletion/retention receipts, M35 lifecycle, M38 package/validator state, M34 TrustSnapshot, M37 notices, EventLedger, Keychain/file-access boundaries, and browser/session authorities**. Do not add automatic deletion, a revocation service, a second package database, remote upload, executable package content, or runtime implementation as part of M39 planning.
