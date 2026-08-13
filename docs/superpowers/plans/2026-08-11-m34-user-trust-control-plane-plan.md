# M34 — User Trust & Control Plane Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M34 User Trust & Control Plane
> **Depends on:** M0–M6 storage/provenance/recovery; M10–M15 browser, memory, and command surfaces; M16 worker/Permission Center; M18/M21 suppression and notification policy; M19/M23 connectors; M25 engine/update ownership; M26 tenant/policy ownership; M27 encrypted sync and device/membership authority; M28 Flow authority; M29 context governance; M30 agenda/notification coordination; M31 portability/extensibility; M32 release receipts/channels; M33 operational intake and trust feedback.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities:** Apple TCC/protected-resource, Keychain, CloudKit account/device, privacy-manifest, App Sandbox, and Accessibility documentation; Sparkle publishing/security; GitHub release/advisory documentation; W3C accessibility guidance; current Hive M0–M33 authorities.
>
> M34 makes trust inspectable in one user-facing control surface. It projects capability grants, system permission state, consent history, data lifecycle, provenance, model/provider disclosure, connector/device identity, release channel, and evidence status from their existing owners. It does not create a second authority or imply that a polished Trust Center proves security, privacy compliance, accessibility conformance, or universal deletion.

## 0. Decision summary

The smallest safe M34 architecture is:

```text
existing authorities
  ├─ Permission Center / TCC probes / Worker grants
  ├─ EventLedger consent and action evidence
  ├─ Honeycomb + lifecycle/deletion receipts
  ├─ M26 ownership/policy and M27 membership/device/epoch state
  ├─ Keychain / connector / sync identity state
  ├─ M31 export/import receipts
  ├─ M32 release receipts/update channel state
  └─ M33 trust cases and operational receipts
        ↓
  typed TrustSnapshot + per-item evidence/status/limitations
        ↓
  user-facing Trust Center / disclosure / revoke-reset flows
        ↓
  native owner executes; Trust Center only coordinates and explains
```

| Slice | User value | Hard boundary |
|---|---|---|
| **T1 — Capability and consent inventory** | See what Hive can access, why, scope, current state, and how to revoke it | TCC and native owners remain authoritative; the view never fabricates permission state |
| **T2 — Data lifecycle control** | Inspect what is retained, where it lives, what can be exported/deleted, and what is pending | A projection coordinates existing stores and receipts; it does not promise universal erasure |
| **T3 — Evidence and disclosure** | Understand how a feature, model, connector, release, or claim is supported | Evidence status is explicit: verified, code-present, planned, blocked, unavailable, or limited |
| **T4 — Identity, device, and channel state** | Avoid account/device mix-ups and understand stable/beta/local update behavior | CloudKit, Keychain, M26/M27, and M32 own identity/channel facts; Trust Center cannot switch identity or bypass signing |
| **T5 — Revoke/reset and browser-first degradation** | Stop optional capabilities and recover safely without losing ordinary browsing | Reset is typed, scoped, resumable, and confirmation-bound; private/offline/locked/denied states remain useful |

M34 does **not** claim TCC database access, universal permission introspection, automatic permission granting, legal/privacy certification, SOC 2/ISO compliance, universal remote deletion, account recovery, enterprise administration, a second audit/consent store, or a complete security guarantee.

## 1. Current truth and reusable authorities

### 1.1 Existing surfaces

| Surface | Current truth | M34 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| `PermissionPromptView` / site permission policies | User-facing browser/site permission prompts and durable per-site decisions exist | Project browser and Worker permission state into one inventory | A remembered site decision is not macOS TCC authorization |
| M16 Permission Center | Worker capability/grant and TCC disclosure contract is planned | Project grant, system-state, scope, purpose, expiry, and revoke action | Hive cannot grant Accessibility, Screen Recording, or Apple Events itself |
| `EventLedgerStore` | Append-only local evidence authority | Link consent, revoke, reset, disclosure, and TrustSnapshot receipts | Trust Center is not a second ledger or mutable source of truth |
| Honeycomb/lifecycle/M0–M6 | Memory/source/provenance/deletion/export boundaries exist or are planned | Show retained classes, generations, derived stores, and request receipts | A row count or UI badge does not prove deletion from every copy |
| M26 ownership/policy | Tenant/profile/workspace and policy admission boundaries | Explain scope and policy provenance | Trust Center cannot infer tenant from email, Apple ID, host, or network |
| M27 sync | Membership/device/epoch/revocation contract is planned | Show device/session/epoch state and stale/revoked status | Current personal sync is not collaboration or complete device identity |
| Keychain/connectors | Credential and connector ownership is distributed across native stores | Show account shell, scope, last sync, and credential status without secrets | Never display, export, or model-process secret material |
| M31 portability | Quarantine-first export/import and declarative manifest receipts | Link export/import, omission, conflict, and deletion-generation status | An archive is not authority and cannot silently restore credentials |
| M32 release | Exact artifact/release/signing/update evidence contract | Show channel, version, receipt status, update limitations, and rollback status | Stable/beta labels cannot imply notarization or distribution proof |
| M33 trust operations | Typed cases, privacy receipts, support packets, and minimal local health contract | Link user-facing cases, limitations, and communication receipts | A published policy or local case row is not proof of operational readiness |
| Settings/privacy surfaces | Browser privacy and forget/delete controls exist in multiple surfaces | Provide coherent navigation and status summaries | Do not duplicate destructive behavior or hide the owning control |

**Current implementation classification:** Hive has distributed permission, privacy, sync, Keychain, release, EventLedger, and operational primitives. It lacks a verified unified Trust Center projection, evidence-status model, per-capability disclosure contract, cross-store lifecycle summary, account/device/channel reconciliation view, typed reset/revoke coordinator, and browser-first degradation proof. No M34 claim may be marked verified from a settings screen, static copy, permission label, or receipt link alone.

### 1.2 Authority table

| Concern | Single authority | M34 rule |
|---|---|---|
| macOS permission state | TCC/native capability probes and system UI | Show `granted`, `denied`, `restricted`, `unknown`, `unavailable`, or `requires_system_settings`; never infer from prior consent |
| Hive capability grant | M16 grant/worker authority | Display exact capability, target scope, purpose, generation, expiry, and revoke path |
| User consent evidence | EventLedger + owning consent contract | Project immutable references; do not rewrite history to make consent appear current |
| Memory/data lifecycle | Honeycomb and each M0–M31 data owner | Aggregate only from typed owner receipts; distinguish local, derived, sync, backup, and external states |
| Ownership/policy | M26/M27/M29 authorities | Intersect scope before display and redact inaccessible metadata |
| Account/device identity | CloudKit/Keychain/M27 device and membership authorities | Show opaque stable identifiers or safe labels; never invent account identity or device trust |
| Release/channel | M32 receipt, UpdateManager/Sparkle policy | Show exact state and limitations; no unsigned channel or rollback bypass |
| Evidence/claim status | M32/M33 receipts plus source authority | Every claim has owner, timestamp, evidence refs, status, and limitation |
| Reset/revoke execution | Native owner coordinator | Trust Center requests typed operations and reports actual result; it does not execute arbitrary destructive work |
| Accessibility | Native/UI tests plus manual assistive-technology evidence | Expose unavailable/manual states instead of converting them to pass |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A typed `TrustSnapshot` projection with schema version, captured-at time, source authority references, scope, freshness, and per-item status.
2. Capability rows for browser/site permissions, Worker grants, connectors, model/provider access, screen/Accessibility/Apple Events capability, network/update access, and optional Swarm features.
3. Per-capability disclosure: what is accessed, why, scope, retention, whether data can leave the device, which authority owns the decision, current state, last change, and revoke/reset path.
4. Consent history that distinguishes proposed, disclosed, approved, denied, withdrawn, expired, revoked, unavailable, and unknown; history is inspectable but not editable.
5. Data lifecycle summaries over existing authorities: retained object classes, local stores, derived indexes, sync/outbox, export artifacts, pending deletion, retention/expiry, and external-copy limitations.
6. Provenance/evidence disclosure for release, model/provider, connector, memory/source, action, and operational claims, with explicit freshness and limitations.
7. Account/device/session identity reconciliation: local profile, CloudKit account state, connector account shells, M27 membership/device/epoch state, Keychain availability, and stale/revoked transitions.
8. Release-channel semantics: stable, beta/preview, local/developer, unavailable, blocked, and rollback/hold states; show exact artifact/build/receipt status without implying distribution.
9. Typed user actions: open System Settings, revoke/pause/reset a capability, forget a selected data scope, cancel a pending operation, inspect a receipt, export eligible metadata, and return to browser.
10. A scoped “reset optional Hive access” path that enumerates affected grants/stores/queued operations before approval and reports partial/blocked results without deleting canonical browser state by surprise.
11. Offline, private, locked, revoked, no-iCloud, no-Keychain, denied-TCC, unavailable-manual-accessibility, and Swarm-disabled views that remain truthful and usable.
12. Synthetic fixture, accessibility, prompt-injection, stale-generation, account-switch, channel, deletion, and scope-isolation coverage tied to M0–M33 evidence.

### 2.2 Explicit non-goals

- A second permission, consent, EventLedger, identity, device, sync, data-lifecycle, telemetry, ticket, or policy database.
- Direct reads or writes of internal TCC databases; automatic granting, simulated granting, or “green” status inferred from a previous prompt.
- A universal account system, password/identity provider, enterprise admin console, fleet-management plane, SSO directory, or account-recovery service.
- Displaying, exporting, syncing, embedding, or sending Keychain secrets, tokens, cookies, credentials, raw private memory, page content, prompts, screenshots, or arbitrary paths.
- Universal deletion from OS caches, backups, CloudKit/provider-managed copies, already exported archives, external support systems, or third-party model providers.
- Legal compliance certification, privacy seal, SOC 2/ISO assertion, regulator workflow, or legal advice.
- A trust score, security score, privacy score, “safe” badge, or single green indicator that collapses unknown/blocked/unavailable evidence.
- Automatic channel switching, unsigned updates, rollback outside M32, silent beta enrollment, or a marketplace for arbitrary extensions/code.
- Model-selected revocation, permission changes, identity changes, deletion scopes, or evidence status; models may summarize frozen allowed data only as advisory text.
- A dashboard-first launch or a requirement that users inspect the Trust Center before ordinary browsing works.

## 3. TrustSnapshot and disclosure contracts

### 3.1 `TrustSnapshot` envelope

```text
TrustSnapshot {
  snapshot_id: stable UUID
  schema_version: semantic version
  captured_at: Date
  freshness: fresh | stale | partial | unavailable
  viewer_scope: local/profile/workspace/tenant
  authority_refs: typed immutable references
  capabilities: [TrustCapability]
  data_lifecycle: [LifecycleSummary]
  identity: IdentitySummary
  release: ReleaseSummary
  evidence: [EvidenceClaim]
  pending_operations: [OperationSummary]
  limitations: [TypedLimitation]
}
```

The snapshot is a read model, not a new durable authority. It must be rebuildable from current owners and must never cache a privileged state beyond its declared freshness. A stale snapshot is labeled stale; it cannot authorize a tool, restore a grant, or approve a deletion.

### 3.2 `TrustCapability`

```text
TrustCapability {
  capability_id: stable typed ID
  kind: browser_site | worker | accessibility | screen_recording | apple_events |
        connector | model_remote | model_local | network | update | swarm | memory
  owner_authority: typed authority ID
  state: proposed | disclosed | approved | denied | active | paused | withdrawn |
         expired | revoked | unavailable | restricted | unknown | blocked
  target_scope: profile/workspace/tenant/host/app/window/root/account or none
  purpose: bounded human-readable purpose
  data_classes: allowlisted labels only
  retention: local policy reference or none
  egress: local_only | user_opt_in | provider_scoped | unavailable | unknown
  generation: revocation/policy/identity generation
  evidence_refs: immutable receipt IDs
  actions: typed available actions
  limitation: optional typed explanation
}
```

A capability row may say “Hive can request this” without saying “the system granted this.” Browser site permissions, Worker grants, and macOS TCC services are separate rows even when the user sees them together.

### 3.3 Evidence claims

```text
EvidenceClaim {
  claim_id: stable ID
  subject: release/model/provider/connector/memory/action/policy
  statement: bounded factual statement
  status: verified | code_present | planned | blocked | unavailable | limited | stale
  owner_authority: typed ID
  observed_at: Date
  evidence_refs: receipt/source/test/manual IDs
  expires_or_review_at: Date?
  limitations: bounded strings
}
```

The Trust Center renders claims; it does not promote `code_present`, `planned`, or `blocked` into `verified`. “Local model available” must identify actual runtime/provider behavior; “encrypted sync” must identify the exact scope and evidence; “private” must state what is and is not retained.

## 4. Data lifecycle, identity, and release contracts

### 4.1 Lifecycle summary

Every summary names:

```text
object class → owning store → scope → retention → derived stores → sync/outbox →
export artifacts → deletion generation → current state → external-copy limitation
```

The UI must distinguish `not_collected`, `local_active`, `local_expired`, `delete_requested`, `delete_pending`, `deleted_local`, `awaiting_sync`, `blocked`, `failed`, `unknown_legacy`, and `external_copy_uncontrolled`. A total count, database filename, or successful button press cannot stand in for the lifecycle state.

### 4.2 Identity and account changes

Identity rows distinguish local profile identity, CloudKit account status, connector account identity, M27 device/membership identity, Keychain access state, and session lock state. Account changes are asynchronous and may leave data temporarily stale or unavailable. On account/device change, cached remote-bound state is quarantined or marked stale until the owning authority reconciles it; Hive must not silently merge two identities or treat an opaque record ID as a verified human identity.

The user sees the exact next action: sign in, wait for reconciliation, reauthorize, unlock Keychain, revoke stale device, export local data, or continue offline. “Connected” is never inferred from a past successful sync.

### 4.3 Release channels

A channel row contains channel name, source/feed identity, current app/build/engine, exact M32 receipt reference, signature/authentication status, last checked time, update availability, rollback/hold state, and limitations. Stable, beta/preview, local/developer, unavailable, blocked, and stale are distinct. Channel choice is explicit and user-owned; a local/developer build cannot be presented as notarized distribution. If an update fails, Hive reports whether the app stayed on the old build, entered a hold, or needs manual recovery; it does not claim rollback succeeded without evidence.

## 5. User actions and safety contract

### 5.1 Revoke/pause/reset

All destructive or privilege-reducing actions use a typed preview:

```text
TrustActionPreview {
  action_id: stable UUID
  kind: revoke | pause | reset | forget | cancel | open_system_settings | export
  target_scope: exact typed scope
  affected_authorities: list
  expected_effects: list
  not_affected: list
  irreversible_or_limited: list
  current_generations: map
  requires_confirmation: bool
  approval_binding: hash/reference
}
```

Before applying, the native owner revalidates identity, policy, scope, generation, and current permission state. A stale preview is rejected and regenerated. The Trust Center cannot approve its own preview, and model output cannot supply authority fields.

### 5.2 Optional-access reset

“Reset optional Hive access” is a bounded coordinator over existing owners. It lists affected Worker grants, connector grants, remote-model consent, queued outbound packets, optional memory/context permissions, and local caches. It explicitly excludes canonical browser tabs/history/bookmarks unless separately selected and previewed. Each owner returns `applied`, `partial`, `blocked`, `failed`, `already_revoked`, or `unavailable`; the final receipt preserves the per-owner result. Reset never implies that macOS TCC was programmatically cleared or that external copies were erased.

### 5.3 Untrusted content

Page text, connector data, shared workspace objects, model output, support reports, release notes, and imported manifests are untrusted. They may be displayed as evidence or limitation text but cannot create a TrustCapability, alter a TrustSnapshot, change a channel, widen a lifecycle scope, or invoke reset/revoke. A model may summarize a frozen snapshot only as advisory output; native policy owns all actions.

## 6. Work packages

### M34-A — Authority map and TrustSnapshot

Define the typed snapshot, capability/evidence/lifecycle schemas, freshness states, authority references, viewer-scope intersection, redaction rules, and projection adapters over M16/M26/M27/M31/M32/M33. Reconcile browser/site permissions with OS Worker/TCC rows without merging their semantics.

**Done when:** a synthetic snapshot rebuilds deterministically from frozen authority fixtures; stale/partial/unavailable states survive restart; no snapshot field can authorize a privileged action or create a second store.

### M34-B — Capability, consent, and data-lifecycle disclosure

Define the user-facing Trust Center sections for capability inventory, consent history, retention/egress, derived stores, sync/outbox, deletion generations, pending operations, and external-copy limitations. Add typed links to the owning settings/action surface rather than duplicating destructive logic.

**Done when:** every displayed capability/data class names purpose, scope, owner, current state, freshness, retention/egress, and exact limitation; inaccessible scopes are omitted or redacted; no green “safe” score replaces evidence.

### M34-C — Identity/device/channel reconciliation

Define local profile, CloudKit account status, connector account shells, M27 device/membership/epoch state, Keychain lock/access state, and M32 stable/beta/local/blocked channel semantics. Specify account-switch quarantine, stale sync, revoked device, feed-authentication failure, and update/rollback handoffs.

**Done when:** synthetic identity/channel transitions cannot merge accounts, revive revoked grants, expose stale remote state as current, silently enroll in beta, or claim an unauthenticated/unsigned/unsupported update.

### M34-D — Typed revoke/reset/export actions

Define preview/approval/revalidation/receipt contracts for revoke, pause, reset, forget, cancel, open System Settings, and eligible metadata export. Coordinate existing owners; do not create a new executor. Preserve canonical browser state unless explicitly selected, and distinguish applied, partial, blocked, failed, and external-copy-limited outcomes.

**Done when:** stale previews, scope changes, locked Keychain, denied TCC, revoked membership, offline queues, and partial deletion all fail safely and leave ordinary browsing usable; no model or page content can issue a reset.

### M34-E — Evidence center, accessibility, and browser-first validation

Define claim rendering with source/freshness/status/limitations, disclosure copy, keyboard/VoiceOver/large-text/high-contrast/reduced-motion paths, offline/private/locked/Swarm-disabled fallbacks, and integrated M0–M33 evidence review. Add synthetic prompt-injection and evidence-poisoning fixtures.

**Done when:** a user can understand what Hive knows/can access/has sent/retains and what remains unknown, revoke an optional capability, inspect the receipt, and return to a useful browser without needing Swarm, network, iCloud, Keychain unlock, or a complete accessibility harness.

## 7. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M34-01 | Fresh local profile | TrustSnapshot is deterministic and mostly `not_collected`/`unavailable`, not falsely green |
| M34-02 | Snapshot stale | Stale banner; no action authorization from stale state |
| M34-03 | Partial authority unavailable | Partial snapshot identifies missing authority and continues browser use |
| M34-04 | Viewer scope narrowed | Cross-workspace/tenant rows omitted or redacted |
| M34-05 | Browser site permission allowed | Site grant shown separately from OS TCC |
| M34-06 | Browser site permission reset | Typed owner action; no claim that OS permission changed |
| M34-07 | Worker grant active | Capability, target, purpose, generation, expiry, and revoke path visible |
| M34-08 | Accessibility TCC denied | Denied/requires-System-Settings state; no fake in-app grant |
| M34-09 | Screen Recording unknown | Unknown/unavailable state; no screenshot permission inference |
| M34-10 | Apple Events restricted | Restricted state and exact next action; browser remains usable |
| M34-11 | Consent approved then revoked | History immutable; current state revoked |
| M34-12 | Consent history inaccessible | Redacted limitation; no reconstructed approval claim |
| M34-13 | Private profile | Private scope never appears in durable trust/lifecycle details beyond safe status |
| M34-14 | Memory class retained | Owner, scope, retention, derived stores, and egress are listed |
| M34-15 | Memory deletion pending | Pending generation and dependent stores visible; no deleted claim |
| M34-16 | Derived index missing | Partial lifecycle; rebuild/unavailable state explicit |
| M34-17 | External export exists | Local deletion distinguished from uncontrolled exported copy |
| M34-18 | Keychain locked | Credential state unavailable/locked; no secret exposure |
| M34-19 | Keychain item revoked | Revoked state; no automatic regrant or silent reauth |
| M34-20 | CloudKit no account | Offline/local state usable; no connected claim |
| M34-21 | CloudKit account changes | Remote-bound state quarantined/stale until reconciliation |
| M34-22 | CloudKit restricted | Restricted limitation and recovery path visible |
| M34-23 | Connector account mismatch | No merge; account identity mismatch is blocked |
| M34-24 | M27 revoked device | Device/member state revoked; stale operations denied |
| M34-25 | M27 epoch changed | Old generation cannot authorize current reads/actions |
| M34-26 | Late device/offline state | Quarantined/stale state; no false current sync |
| M34-27 | Stable channel | Exact build/feed/receipt/authentication status shown |
| M34-28 | Beta channel opt-in | Explicit channel consent; no silent enrollment |
| M34-29 | Local developer build | Clearly local/developer; no notarized-distribution claim |
| M34-30 | Feed authentication failure | Update blocked/held; old build state remains truthful |
| M34-31 | Rollback attempted | Result says applied, failed, or unavailable; no false recovery |
| M34-32 | M32 receipt absent | Release evidence blocked/limited, not verified |
| M34-33 | Model provider disclosure | Actual provider/availability/egress matches runtime evidence |
| M34-34 | Remote model consent denied | Local path remains; no hidden remote request |
| M34-35 | Connector egress | Provider/scope/purpose/last sync and consent are visible |
| M34-36 | Reset preview | Affected authorities and exclusions listed before approval |
| M34-37 | Reset stale preview | Revalidation rejects stale action and regenerates preview |
| M34-38 | Reset with locked Keychain | Partial/blocked receipt; no claim of credential deletion |
| M34-39 | Reset with denied TCC | Denial remains; open-System-Settings path only |
| M34-40 | Reset offline | Local revokes apply where possible; queued/external limits explicit |
| M34-41 | Forget selected memory scope | Exact scope/generation and dependent-store results shown |
| M34-42 | Cancel pending outbound packet | Submission stops if possible; remote receipt status disclosed |
| M34-43 | Export eligible metadata | Scoped, omission-aware export; no secrets or private content |
| M34-44 | Imported manifest injection | Manifest displayed/quarantined; cannot create capability or action |
| M34-45 | Page-injected trust instruction | Ignored as authority; page remains untrusted |
| M34-46 | Model-generated reset request | Advisory only; native confirmation required |
| M34-47 | VoiceOver Trust Center | All rows/actions/statuses exposed without color-only meaning |
| M34-48 | Large text/high contrast/reduced motion | Layout, focus, status, and action paths remain usable |
| M34-49 | Trust Center unavailable/disabled | Browser, private mode, and core memory remain usable |
| M34-50 | Final trust review | Every claim has owner/status/freshness/evidence/limitation and next action |

## 8. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M34-A | Single-authority projection | TrustSnapshot references existing owners and creates no parallel store |
| M34-B | Capability disclosure | Permission/grant/TCC/site distinctions, scopes, purposes, and limitations are accurate |
| M34-C | Consent truth | Current state and immutable consent history are separated; stale/unknown states visible |
| M34-D | Lifecycle truth | Local, derived, sync, export, pending, deleted, blocked, and external-copy states are distinct |
| M34-E | Identity reconciliation | Profile/account/device/member/epoch states cannot merge or revive authority |
| M34-F | Channel truth | Stable/beta/local/blocked/update/rollback status binds to M32 evidence |
| M34-G | Typed actions | Revoke/reset/forget/cancel/export use preview, revalidation, approval, and receipts |
| M34-H | Secret and scope safety | Keychain values, tokens, private content, and inaccessible scopes never leak |
| M34-I | Untrusted-content fencing | Pages, connectors, imports, reports, and models cannot alter trust state or execute actions |
| M34-J | Accessibility and unavailable truth | Keyboard/VoiceOver/large-text/contrast/reduced-motion/manual gaps and unavailable services are explicit |
| M34-K | Browser-first degradation | Offline, private, locked, denied, revoked, no-iCloud, Swarm-disabled, and Trust-Center-disabled paths remain usable |
| M34-L | Evidence-backed claims | Every displayed claim has owner, status, freshness, evidence refs, limitation, and review/expiry semantics |

## 9. Safety, privacy, and claim boundaries

M34 is not a reason to collect more data. The Trust Center may disclose categories and states without ingesting page text, screenshots, keystrokes, prompts, secrets, or cross-app activity. A lifecycle summary must be computable from owner metadata and receipts; if it cannot be computed safely, it says unavailable or limited.

macOS owns TCC state and system prompts. Hive may probe supported capabilities, explain the state, and open System Settings; it must not parse or mutate private TCC databases or simulate a grant. CloudKit account/device state is OS/provider-managed and asynchronous; account changes require quarantine/reconciliation, not optimistic identity continuity. Keychain state may be locked or inaccessible; Trust Center shows that limitation without probing or exporting values. Sparkle channel/update claims require exact M32 evidence and authenticated state; a channel label is not a distribution certificate.

The user controls optional access. Reset and revoke are category-specific, previewed, revalidated, cancellable where possible, and receipt-backed. A model or external content can summarize frozen evidence but cannot decide capability state, identity, deletion scope, release channel, or authority. No single score or green badge replaces evidence.

## 10. Execution order and handoff

Implement M34-A as documentation and authority reconciliation before adding a new Trust Center UI or reset coordinator. Freeze representative snapshots for fresh, stale, partial, denied, private, locked, revoked, account-switched, and channel-blocked states. Implement M34-B/C against synthetic authority fixtures and opaque identifiers only. Implement M34-D with fake Keychain/TCC/CloudKit/UpdateManager owners; never use real credentials, personal memory, or production update feeds. Implement M34-E with accessibility harnesses where available and explicit unavailable/manual evidence where not.

The next smallest safe action is **M34-A: publish the TrustSnapshot/capability/evidence/lifecycle schemas and reconcile them with M16, M26, M27, M31, M32, M33, EventLedger, Keychain, CloudKit, and browser permission authorities**. Do not add a second persistence layer, TCC database reader, account system, enterprise admin plane, telemetry pipeline, support network client, or runtime implementation as part of M34 planning.
