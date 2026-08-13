# M27 Collaboration & Encrypted Sync — Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; no implementation in this document
> **Depends on:** M0–M6 storage/provenance/lifecycle/MCP/encryption contracts; M10–M25 browser, action, connector, enterprise, and renderer contracts; especially M26 tenant/policy/ownership/audit/deletion semantics.
> **Sibling boundary:** M26 defines enterprise ownership and policy for one local user/device or one assigned tenant context. M27 adds explicit shared workspaces and multi-device/team membership. It does not revise M26 into a collaboration authority.
> **Primary sources:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`, `2026-08-11-m26-enterprise-memory-layer-plan.md`, `2026-08-11-m6-mcp-encryption-decision-plan.md`, `2026-08-11-m19-connectors-v1-plan.md`, `2026-08-11-m25-engine-sovereignty-plan.md`, `AGENTS.md`, `docs/DECISIONS.md`.

## 0. Decision summary

M27 adds a bounded shared-workspace contract over the existing local Honeycomb graph and encrypted sync primitives. **Current single-user sync is not collaboration.** The plan does not claim that the current single-user AES key, private CloudKit database, LWW resolver, or encrypted outbox already supports team collaboration.

The recommended first collaboration substrate is an **encrypted append-only operation log with deterministic materialization and explicit conflict forks**, not a general-purpose CRDT:

```text
explicit share/membership authority
  → device identity + epoch-scoped group key
    → signed, encrypted operation log
      → deterministic Lamport/device ordering
        → materialized local Honeycomb revision
          → conflict fork when semantic merge is unsafe
            → audit/deletion/revocation evidence
```

This choice preserves M4 source/revision provenance and M26 audit/lifecycle semantics while keeping the first shared object set small. A future CRDT may be evaluated for a specific high-churn object after measured contention and payload evidence; M27 does not smuggle CRDT semantics into every Honeycomb node.

M27 must preserve the browser-first rule:

- Browsing, private mode, local memory, and personal work remain useful when collaboration is disabled, offline, unshared, or locked.
- A shared workspace is opt-in and visibly scoped; a user never enters one merely because a link or connector mentions it.
- Shared content is untrusted data. It cannot alter membership, policy, key custody, model routing, permissions, or actions.
- Remote model access is separately governed by M26 policy and the shared workspace’s data class; collaboration does not widen model context.
- Every operation, conflict, membership change, key epoch, deletion, and sync result has a truthful local status.

## 1. Current truth and reusable authorities

### 1.1 Existing primitives

| Primitive | Current truth | M27 reuse | What it does not prove |
|---|---|---|---|
| `CloudKitSyncEngine` | Private-database sync for tabs/bookmarks/history; encrypted payload field; subscription hint; pull/flush cycles | Transport adapter and change notification hint | Shared database/zone membership, operation log, group access, token durability, or team tenancy |
| `SyncCipher` | Versioned AES-GCM envelope for one injected symmetric key | Payload AEAD pattern | Group key distribution, epoch revocation, key rotation, or per-object authorization |
| `SyncKeyStore` | One synchronizable Keychain 256-bit key (`e2e-key-v1`) | Personal multi-device key baseline only | Team key custody, device removal, recovery, or membership proof |
| `SyncPayload` | Tab/bookmark/history state with revision, timestamp, device ID, tombstone | Browser-object migration/reference | General shared graph operations, provenance links, Lamport clocks, or semantic merge |
| `SyncConflictResolver` | Deterministic revision → time → device ordering with tombstone protection | Baseline metadata convergence | Concurrent rich-text/graph merge, operation identity, fork inspection, or causal context |
| `SyncOutboxPolicy` | Encrypted durable outbox guard/retry/conflict diagnostics | M27 offline operation queue seam | Shared membership admission, epoch-key checks, operation dedupe, or server acknowledgement |
| `HoneycombStore`/M4 | Typed graph, revisions, FTS, source provenance, deletion | Shared materialization target | Multi-writer identity, cross-device revisions, membership, or shared-edge conflict policy |
| M26 policy/ownership/audit | Planned tenant/workspace/policy/lifecycle/exports | Non-negotiable shared admission and evidence boundary | Team invitations, shared key epochs, CRDT/op-log semantics |
| CloudKit private/shared databases | CloudKit offers separate personal/shared concepts and participant permissions | Candidate transport mapping | A guarantee that CloudKit account/zone identity equals Hive tenant identity or E2E team key custody |

### 1.2 Missing controls

- Stable installation/device identity with rotation and compromise status.
- Shared-workspace ID separate from local workspace/profile and M26 tenant identity.
- Membership authority, invitations, roles, acceptance, removal, expiry, and audit.
- Cryptographic proof that an operation’s author was a member in its declared epoch.
- Group epoch key distribution, rotation, revocation, recovery, and late-device quarantine.
- Shared operation identity, causal/ordering metadata, signatures, encrypted payload, and idempotent acknowledgment.
- Deterministic materialization from an operation prefix and explicit conflict forks.
- Per-object conflict policy: scalar LWW, set/edge add-remove, ordered collection, and manual fork.
- Shared-zone/CloudKit record mapping, change-token persistence, zone reset recovery, and payload sharding.
- Cross-device deletion, tombstone retention, key erasure status, and revoked-device behavior.
- Shared graph retrieval/admission, cache partitioning, export scope, and prompt-injection fencing.
- User-visible offline/stale/conflicted/invited/removed/locked states and accessible recovery flows.

## 2. Product boundary and non-goals

### 2.1 In scope

1. Explicit shared-workspace creation and invitation/acceptance.
2. Membership roles and cryptographically auditable role transitions.
3. Device registration, device removal, epoch rotation, and late-device quarantine.
4. Encrypted operation envelopes and bounded CloudKit shared/private transport mapping.
5. Deterministic operation ordering, idempotency, materialization, and conflict forks.
6. Shared Honeycomb objects/edges with M26 ownership, policy, provenance, and deletion metadata.
7. Offline-first local editing with visible pending/acknowledged/conflicted states.
8. Revocation, tombstone, retention, export, and recovery semantics.
9. Browser-first, accessibility, prompt-injection, and model-context boundaries.

### 2.2 Explicit non-goals

- Real-time cursor/presence, live co-editing, typing indicators, or video/voice collaboration.
- Full generic CRDT support, rich-text editor semantics, arbitrary plugin-defined merge functions, or unrestricted shared database tables.
- Anonymous sharing, public links, email-domain auto-membership, or invite-driven tenant inference.
- Administrator decryption backdoors, escrowed plaintext keys, or server-side content inspection.
- Shared password vaults, credentials, health/finance data, private browsing, or raw screenshots.
- Automatic sharing of personal captures, connectors, mail, calendar, files, or model context.
- Guaranteed erasure from offline/compromised devices, OS backups, screenshots, exported bundles, or external connectors.
- Collaboration as a prerequisite for ordinary browsing or personal Hive use.
- M27 implementation before M26 ownership/policy/audit/deletion semantics and M6 encryption evidence are approved.

## 3. Identity, membership, and authority

### 3.1 Identity layers

These IDs are distinct and must never be inferred from one another:

```json
{
  "tenant_id": "M26 administrative assignment",
  "shared_workspace_id": "opaque shared graph identity",
  "local_workspace_id": "local projection",
  "profile_id": "local browser profile",
  "device_id": "stable installation identity",
  "member_id": "stable shared-workspace member identity",
  "membership_epoch": 12
}
```

A shared workspace belongs to exactly one M26 tenant or is explicitly personal-owned. A local profile can project multiple shared workspaces, but a shared object cannot silently become personal or cross tenants by copying, summarization, or restore.

Device IDs are generated locally, non-secret, and bound to a registered signing public key. Device replacement is a new device identity, not an overwrite. A device identity has states `pending`, `active`, `suspended`, `revoked`, `expired`, and `quarantined`.

### 3.2 Roles and permissions

M27 v1 fixes four roles:

| Role | Membership | Read shared graph | Propose/write operations | Invite/remove | Rotate epoch | Delete shared workspace |
|---|---|---:|---:|---:|---:|---:|
| `owner` | required | yes | yes | yes | yes | yes, with typed confirmation |
| `manager` | required | yes | yes | yes, policy-bounded | request/owner approval | no |
| `editor` | required | yes | yes | no | no | no |
| `viewer` | required | yes | no | no | no | no |

Roles are workspace-local and do not override M26 tenant policy, M16/M17 permissions, M10 approval, or M6 read-only external boundaries. A connector or model cannot grant a role. Role transitions are signed operations, monotonic in membership epoch, and visible in the audit history.

### 3.3 Invitation and acceptance

An invitation is a typed, signed, expiring capability addressed to a specific member/device registration flow—not a bearer URL that grants access by opening it. It contains:

- shared workspace ID and tenant ID;
- inviter member ID and current membership epoch;
- invitee identity commitment or explicit user-mediated enrollment target;
- proposed role and policy/data-class summary;
- invitation ID, creation/expiry, one-time nonce, and signature;
- key-package reference, never a plaintext group key.

Acceptance requires explicit user action, local M26 policy admission, device key creation/registration, signature verification against a trusted workspace membership root, and an audit event. Unknown issuer, expired invite, tenant mismatch, reused nonce, or policy denial is rejected without revealing hidden workspace content.

## 4. Cryptographic sync contract

### 4.1 Threat model

Treat CloudKit records, notifications, shared content, membership metadata, operation payloads, device storage, and model output as untrusted or compromised inputs. M27 protects confidentiality/integrity in transit and at the CloudKit record boundary; it does not claim a compromised active device cannot read data already decrypted into memory or erase plaintext previously decrypted or copied before revocation.

### 4.2 Key hierarchy and epochs

M27 must not reuse the current single personal `e2e-key-v1` for a shared workspace. Each shared workspace has:

```text
workspace root / membership signing key
  → membership epoch key-encryption context
    → per-epoch symmetric content key
      → per-operation AEAD key/nonce derivation
```

v1 defaults:

- Ed25519 for membership/device/operation signatures (`m27-sign-v1`).
- X25519/Curve25519 key agreement for device key packages (`m27-kx-v1`).
- HKDF-SHA256 domain-separated derivation for epoch and operation keys (`m27-kdf-v1`).
- AES-256-GCM for operation payload AEAD (`m27-aead-v1`) with a fresh random 96-bit nonce per seal and associated data binding workspace, operation ID, epoch, author, object, and schema version.
- No key, nonce, plaintext operation body, or credential enters the default EventLedger, CloudKit fields, logs, or model prompt.

The exact Secure Enclave/Keychain storage class remains a measured M6/M27 decision because synchronizable Keychain material, device replacement, biometric lockout, and enterprise recovery have different trade-offs. No administrator receives a decryption backdoor by default.

### 4.3 Device key-package bootstrap

A device cannot receive a shared epoch key merely because it possesses a workspace ID or CloudKit account. The v1 key package is canonical JSON with exactly: `format: hive-m27-key-package.v1`, `workspace_id`, `tenant_id`, `recipient_member_id`, `recipient_device_id`, `recipient_signing_key_id`, `recipient_kx_public_key`, `epoch`, `epoch_key_ciphertext`, `package_id`, `package_sequence`, `not_before`, `not_after`, `issuer_member_id`, `issuer_device_id`, `issuer_signing_key_id`, `previous_package_hash`, and `signature`.

The issuer signs the package bytes excluding `signature` with Ed25519 `m27-key-package-v1`. The epoch key wire format is fixed: X25519 sender-ephemeral/recipient-static agreement; HKDF-SHA256 with salt equal to the 32-byte `previous_package_hash` or 32 zero bytes for the first package; and info equal to the UTF-8 bytes of `hive-m27-key-package-v1\\0` followed by canonical `hive-m27-kdf-info.v1` JSON with exactly `workspace_id`, `tenant_id`, `recipient_member_id`, `recipient_device_id`, `recipient_signing_key_id`, `epoch`, `package_id`, and `package_sequence` (sorted keys, NFC strings, integer epoch/sequence, no omitted fields). AES-256-GCM seals the 32-byte epoch key using a fresh random 96-bit nonce. `epoch_key_ciphertext` is the canonical concatenation `version-byte(1) || ephemeral_public_key(32) || nonce(12) || ciphertext(32) || tag(16)`, base64url-without-padding. AEAD associated data is the UTF-8 canonical `hive-m27-key-package-ad.v1` JSON containing the complete package header excluding `epoch_key_ciphertext` and `signature`: format, workspace/tenant IDs, recipient member/device/signing-key IDs, epoch, package ID/sequence, validity interval, issuer member/device/signing-key IDs, and previous-package hash. The recipient verifies the issuer’s active membership/device/signing key identified by `issuer_signing_key_id`, including its rotation/version validity, tenant/workspace binding, package sequence, validity interval, previous-package hash, and recipient key fingerprint before decrypting. A bootstrap package is accepted only when an owner-authorized membership transition or an already trusted active member authenticates it; the package cannot establish its own trust root.

Issuer signing-key rotation uses canonical `hive-m27-issuer-key-transition.v1` JSON with exactly `workspace_id`, `tenant_id`, `old_key_id`, `new_key_id`, `new_public_key`, `transition_sequence`, `not_before`, `not_after`, `reason`, and `signature`. The currently trusted old Ed25519 key signs the transition bytes excluding `signature`; the transition sequence is strictly monotonic per workspace; overlap permits both keys only within their declared validity windows; revocation wins over overlap; and rollback requires a higher-sequence transition signed by the currently trusted key. A verifier rejects unknown old keys, sequence rollback, duplicate key IDs, invalid intervals, tenant/workspace mismatch, revoked keys, or transitions not anchored to the current trust state.

Package IDs and `(workspace_id, recipient_device_id, epoch, package_sequence)` are stored durably before acceptance. Replayed, rolled-back, duplicate-with-different-bytes, expired, or superseded packages are rejected. Device replacement creates a new package sequence and device identity. If the owner is unavailable, no untrusted device may self-bootstrap; recovery requires a previously trusted active member or a separately approved recovery ceremony, and must never introduce an administrator plaintext key.

### 4.4 Epoch rotation and revocation

Membership removal, device compromise, owner rotation, key loss, or explicit user request increments `membership_epoch` and creates a signed epoch-transition operation. The new epoch key is distributed only to active members through authenticated key packages. Removed/revoked devices do not receive the new key.

An old device that submits an operation after revocation is rejected as `revoked_epoch` and quarantined. It cannot use an old key to create a valid operation in the new epoch. Historical old-epoch ciphertext remains governed by the retention/deletion contract; “revocation” prevents future access, but does not erase plaintext already decrypted or copied before removal. Revocation is not retroactive plaintext erasure.

Every epoch transition records old/new epoch, membership hash, key-package commitments, signer, reason class, and effective time. Rotation is resumable and must not publish a partially formed membership state as complete.

### 4.4 Operation envelope

The server/transport sees only the minimum routing metadata:

```json
{
  "format": "hive-m27-op.v1",
  "operation_id": "stable UUID",
  "workspace_id": "opaque",
  "tenant_id": "opaque or encrypted/omitted per policy",
  "epoch": 12,
  "author_member_id": "opaque",
  "author_device_id": "opaque",
  "lamport": 481,
  "parents": ["operation IDs, bounded and sorted"],
  "object_id": "opaque",
  "object_type": "typed enum",
  "ciphertext": "base64url",
  "nonce": "base64url",
  "signature": "base64url",
  "schema_version": 1
}
```

Routing metadata is still sensitive metadata. M27 must minimize it, apply M26 policy, and avoid placing human names, URLs, titles, raw graph labels, or content hashes in unencrypted fields unless a separately approved query requirement proves necessary.

The signed bytes are canonical `hive-json-c14n-v1` over the envelope excluding `signature`, with the signature domain `"hive-m27-op-v1" + NUL`. The signature binds operation ID, epoch, author/device identity, Lamport clock, sorted parents, object identity/type, ciphertext, nonce, and schema. Duplicate operation IDs with different bytes are a hard integrity failure.

### 4.5 Operation idempotency and ordering

Each operation has a stable operation ID generated by the native runtime, not a model. The local journal persists the operation before upload. A receiver transactionally persists the operation identity/dedupe record before materializing it.

Before decryption or materialization, the receiver validates and atomically claims the tuple `(workspace_id, epoch, author_device_id, operation_id, nonce)`. It also maintains a nonce index keyed by `(workspace_id, epoch, author_device_id, nonce)`. Reusing a nonce with a different operation ID, ciphertext, author, or epoch is a hard integrity failure and quarantines the workspace; replaying identical bytes for the same operation ID is an idempotent acknowledgement. A duplicate operation ID with different bytes is never materialized. Dedupe and nonce records survive restart, token reset, re-fetch, and restore reconciliation.

The deterministic total order is:

```text
(epoch ascending,
 lamport ascending,
 author_member_id lexicographic,
 author_device_id lexicographic,
 operation_id lexicographic)
```

Lamport clocks advance beyond every observed parent/remote clock. Parents are bounded; if causal ancestry is unavailable, the operation is marked `causal_gap` and cannot silently override a known concurrent edit.

Ordering is not semantic merge. It only makes replay reproducible. Materializers apply an object-type merge policy and create a visible conflict fork when the policy cannot safely merge.

## 5. Materialization and conflict protocol

### 5.1 Shared object classes v1

M27 begins with a narrow allow-list:

- project metadata and membership-linked project edges;
- task title/state/due-date metadata;
- source/brief references and typed graph edges;
- sheet metadata and row-level cells only after M14/M20 revision semantics pass;
- browser workspace organization metadata, never private tabs or raw page bodies.

Raw page captures, mail bodies, credentials, screenshots, private browsing, local filesystem contents, model prompts, and arbitrary binary assets remain local unless a separate data-class policy and explicit sharing flow is approved.

### 5.2 Merge policies

| Object component | v1 policy | Unsafe case |
|---|---|---|
| Scalar metadata | Deterministic LWW by operation order, preserving prior revision | Restricted field or equal semantic conflict requiring user review |
| Set membership/edge | Add/remove operations with observed-remove context | Concurrent add/remove without causal relation → visible conflict state |
| Task state | State-transition validator; invalid transition becomes proposal/fork | Concurrent completion/reopen or policy-blocked change |
| Ordered list | Stable element IDs plus move operations; deterministic tie-break | Same element moved/deleted concurrently → fork/restore choice |
| Sheet cell | Cell-level revision and typed value validation | Concurrent incompatible formulas/types → conflict cell, no silent overwrite |
| Source/brief text | No automatic prose merge in v1; immutable revisions + fork | Any concurrent content edit |
| Membership/policy/key | Authority-only signed transition, never ordinary object merge | Invalid signer/epoch/role → reject and audit |

Every conflict fork retains both valid inputs, parent operation IDs, object scope, reason code, and a user resolution path. The system never calls “last writer wins” a successful semantic merge for rich content.

### 5.3 Materialization invariants

- Replaying the same valid operation prefix produces byte-equivalent materialized state and revision IDs.
- A rejected, quarantined, revoked, malformed, or causally incomplete operation never mutates visible state.
- A tombstone dominates stale state within its declared object revision/epoch, but a later authorized restore is a new operation with explicit lineage.
- Materialized state is derived from the operation log and can be rebuilt; it is not a second authority.
- Every materialized revision references the operation IDs and M4/M26 provenance/lifecycle state that produced it.
- Search/FTS/vector indexes are rebuilt or excluded according to M26 deletion and policy generations; stale shared indexes never leak removed content.

## 6. CloudKit transport and recovery

### 6.1 Private versus shared database

M27 keeps two explicit transport modes:

- **Private database:** single-user multi-device sync for personal work, using the existing personal key path. It does not become a team space.
- **Shared database/zone:** opt-in shared-workspace transport mapped from an explicit workspace invitation and membership authority. CloudKit participant permission is necessary but not sufficient for Hive membership or content-key access.

A CloudKit record zone/container/account is never accepted as the Hive tenant identity. Shared zones contain opaque operation envelopes and minimal routing metadata. CloudKit notifications are hints; authoritative changes require persisted change tokens and recovery fetches.

### 6.2 Change tokens and durable sync state

Persist atomically with the local journal:

- database/zone identity and shared workspace ID;
- last accepted server change token and token generation;
- pending operation IDs and upload attempts;
- acknowledged operation IDs;
- epoch/key-package generation;
- quarantine reasons and conflict IDs;
- deletion/tombstone cursor and storage/retrieval generations.

A token invalidation, zone deletion, server database change gap, account change, or partial transaction moves the workspace to `resync_required`; it does not initialize an empty shared graph. Recovery fetches the authoritative operation prefix, validates signatures/epochs, rebuilds materialized state, and only then resumes uploads.

### 6.3 Batching and payload limits

Operations are bounded and chunked before CloudKit submission. M27 records the measured platform limit at implementation time rather than hard-coding a stale universal number. An operation exceeding the configured byte budget is rejected or moved to an explicitly approved asset path; it is never silently truncated or split without stable chunk identity and authenticated reassembly.

Batch writes are idempotent and retryable with exponential backoff/jitter. Server-record conflicts, rate limits, zone-busy, network loss, account changes, and partial responses retain local operations and produce typed status. A remote notification never clears an outbox without an acknowledged operation or verified idempotent server result.

### 6.4 Late devices and rollback

A device that has been offline beyond policy TTL, misses epoch transitions, presents an invalid change token, or restores an old local snapshot is quarantined. It may inspect only already-authorized local state according to M26 policy; it cannot upload, receive new epoch keys, or merge its stale state until re-enrollment/reconciliation succeeds.

Restore never rolls a shared workspace backward. The restored operation log is compared against the server prefix; missing local operations become pending only when their author/epoch/signature remains valid, and server operations are replayed before local writes resume.

## 7. Deletion, revocation, and retention

### 7.1 Shared deletion

A shared delete is an authenticated operation/tombstone with object ID, prior revision/parents, epoch, reason class, and retention policy. It is not hard deletion of a CloudKit record. Materializers hide the object only after the operation is valid and authorized; indexes/caches/derived artifacts follow M26’s deletion generations.

Workspace deletion is an owner-authorized lifecycle transition with a resumable cascade. It blocks new operations, writes tombstones/closure evidence, revokes future epoch keys, and reports local, CloudKit, backup, export, and offline-device status separately. It never claims to erase already copied plaintext or unmanaged backups.

### 7.2 Revoked members/devices

Revocation blocks future operation acceptance and key distribution. Existing local data is retained or purged according to M26 policy and user-visible scope. A revoked device’s late operations are rejected without revealing current shared content. Membership records and revocation events remain audit-governed; raw key material is never exported to the ledger.

### 7.3 Export and audit

Shared exports include workspace/member-role/epoch status, operation range, conflict/fork list, deletion-pending items, policy generation, and the M26 audit-integrity manifest. Content export requires a separate authorized scope. Exporting operation ciphertext without the required key is labeled opaque/incomplete, not a successful content backup.

M27 does not let collaboration bypass M26 tenant policy, retention floors, legal-hold-marker limitations, or independent verifier rules.

## 8. Context, models, connectors, and actions

- Shared graph content is untrusted and never becomes a system instruction.
- A shared operation cannot grant an M16/M17 capability, approve an M10/M11 action, change M26 policy, or select a remote model.
- Shared retrieval is scoped by tenant, shared-workspace membership, profile, policy, deletion generation, and model destination before ranking.
- Shared work may be used by a local model only after explicit context scope; remote inference requires both M26 policy and user-visible destination consent where required.
- M19/M23 connectors remain individually authorized. A shared workspace does not share Calendar, filesystem, mail, tokens, or connector roots by implication.
- Action proposals derived from shared content retain operation/source provenance and require the existing approval ladder.
- Prompt-injection fixtures cover malicious membership names, task text, source claims, operation payloads, conflict resolutions, and connector content.

## 9. Accessibility and browser-first behavior

### 9.1 Visible states

Every shared-workspace surface exposes a compact, accessible status for:

`local_only`, `invited`, `pending_acceptance`, `syncing`, `offline_pending`, `stale`, `conflicted`, `resync_required`, `key_locked`, `epoch_rotating`, `revoked`, `quarantined`, `deleted_pending`, `deleted`, and `available`.

A status includes scope, last successful sync, pending operation count, conflict count, key/epoch state, and the next safe action without exposing hidden member/content data.

### 9.2 Browser-first degradation

| Failure | Browser/personal work | Shared workspace |
|---|---|---|
| Collaboration disabled | Full | Hidden/absent, no prompt |
| Offline | Full | Local authorized edits queue with `offline_pending` |
| Key locked/unavailable | Full | Shared content locked; no plaintext fallback |
| Membership revoked | Full | Shared writes denied; local state labeled revoked |
| Resync required | Full | Shared view read-only/quarantined until rebuilt |
| CloudKit unavailable | Full | Local authorized state remains visible with stale status |
| Conflict | Full | Both revisions/fork and resolution action visible |
| Enterprise policy unavailable | Full personal browsing | High-risk shared operations denied per M26 |

No collaboration error may block navigation, private mode, local captures, or personal work.

### 9.3 Accessibility

Invitations, role changes, conflict forks, key lockouts, resync, and deletion statuses are keyboard reachable and VoiceOver-complete. Conflict resolution names both versions and the exact operation/time provenance; no color-only status. Reduced motion/transparency, dynamic type, and high contrast are honored. Destructive workspace deletion and member removal require typed confirmation with an accessible summary.

## 10. Work packages

### M27-A — Shared workspace and membership authority

Define shared-workspace identity, member/device records, roles, invitation acceptance, trust roots, signed transitions, policy intersection, and audit events. Reuse M26 authority; do not create a parallel tenant or permission system.

**Done when:** invitation/role/revocation fixtures pass; unknown/expired/replayed/mismatched invitations fail closed; personal and shared scopes remain separate; membership names/content cannot alter authority.

### M27-B — Device keys, epochs, and encrypted operation envelopes

Define device registration, signing/key-agreement packages, epoch key distribution/rotation, revocation, operation canonicalization, AEAD associated data, signatures, nonce rules, key storage, and recovery/lockout boundaries. Execute against M6 encryption evidence.

**Done when:** ciphertext contains no raw content; wrong key/nonce/epoch/signature/tenant/workspace fails; revoked and late devices cannot submit or receive new epoch keys; key rotation is resumable and audited.

### M27-C — Operation log, materializers, and conflicts

Implement the typed operation allow-list, Lamport/parent ordering, operation dedupe, deterministic replay, per-object merge policies, immutable revisions, visible conflict forks, and rebuild tests. Do not add a general CRDT until a separate object-specific evaluation passes.

**Done when:** replay is deterministic; duplicate/reordered/concurrent/causally incomplete operations have typed outcomes; no unsafe rich-content merge is hidden as LWW; materialized state is rebuildable from the log.

### M27-D — CloudKit shared transport and recovery

Map shared workspaces to explicit shared zones/participant permissions, persist tokens/journal atomically, handle zone/database resets, partial batches, rate limits, outbox acknowledgements, payload budgets, late devices, and quarantine. Keep personal private-database sync backward-compatible and separate.

**Done when:** offline edits converge or remain visible as conflicts; token loss never creates empty state; retries are idempotent; server/participant permission is not mistaken for Hive membership; browser remains usable during every transport failure.

### M27-E — Shared graph/product surfaces and deletion

Add opt-in shared workspace views, scope previews, conflict/fork resolution, membership/key status, export, deletion, accessibility, prompt-injection, M26 lifecycle, and browser-first validation. Do not add presence or real-time editor surfaces.

**Done when:** users can invite/accept/edit/review/revoke/delete within permitted scope, inspect provenance and conflicts, export honest state, and continue personal browsing with collaboration disabled or unavailable.

## 11. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M27-01 | Create shared workspace | Explicit opaque identity tied to one tenant/scope |
| M27-02 | Personal workspace opened | No shared membership or key inferred |
| M27-03 | Invitation valid | Visible acceptance required |
| M27-04 | Invitation expired | Rejected without content leak |
| M27-05 | Invitation replayed | One-time nonce rejected |
| M27-06 | Invitation tenant mismatch | Rejected |
| M27-07 | Unknown inviter key | Rejected |
| M27-08 | Role escalation by editor | Rejected and audited |
| M27-09 | Manager removes owner | Rejected by authority |
| M27-10 | Device registration | New signed device identity and package |
| M27-11 | Duplicate device registration | Idempotent or explicit replacement flow |
| M27-12 | Device revoked | Future operations denied |
| M27-13 | Epoch rotation | Active members receive new epoch, revoked member does not |
| M27-14 | Epoch rotation interruption | Resumable; no partial membership complete state |
| M27-15 | Late old-epoch operation | Rejected as revoked_epoch |
| M27-16 | Key unavailable | Shared content locked, no plaintext fallback |
| M27-17 | Wrong AEAD key | Decryption fails; no materialization |
| M27-18 | Nonce reuse/replay | Rejected by operation identity/nonce policy |
| M27-19 | Signature tamper | Rejected and audited |
| M27-20 | Tenant/workspace binding tamper | Rejected before decrypt/materialize |
| M27-21 | Duplicate operation same bytes | Idempotent acknowledgement |
| M27-22 | Duplicate operation different bytes | Integrity failure/quarantine |
| M27-23 | Lamport clock regression | Causal/ordering rejection or explicit gap |
| M27-24 | Concurrent scalar edits | Deterministic winner with retained revision lineage |
| M27-25 | Concurrent rich-text edits | Visible fork, no silent merge |
| M27-26 | Concurrent task transition | Validator rejects unsafe transition or creates proposal/fork |
| M27-27 | Concurrent edge add/remove | Observed-remove/fork status, no orphan authority |
| M27-28 | Concurrent sheet cell edits | Typed conflict cell with both values |
| M27-29 | Tombstone versus stale live state | Tombstone wins within valid revision/epoch |
| M27-30 | Authorized restore after delete | New operation with explicit lineage |
| M27-31 | Replay same operation prefix | Byte-equivalent materialized state |
| M27-32 | Missing parent operation | causal_gap; no silent override |
| M27-33 | Malformed operation object type | Rejected before materialization |
| M27-34 | Raw page body in shared operation | Denied by data-class policy |
| M27-35 | Shared prompt injection | Data only; no authority/action change |
| M27-36 | CloudKit participant read-only | Transport permission cannot create Hive editor role |
| M27-37 | Shared zone missing | resync_required; no empty replacement |
| M27-38 | Change token invalidated | Full verified prefix recovery |
| M27-39 | Partial upload response | Acked IDs clear only; others retained |
| M27-40 | Rate limited/zone busy | Backoff and visible pending state |
| M27-41 | Notification dropped | Next authoritative pull reconciles |
| M27-42 | Old restored local snapshot | Quarantine; no rollback of shared log |
| M27-43 | Shared workspace deletion | Authenticated closure/tombstones and status per scope |
| M27-44 | Offline deletion | Queued, not falsely verified remote deletion |
| M27-45 | Revoked device reconnects | No new keys; local state quarantined |
| M27-46 | Shared export without key | Opaque/incomplete, not content-success |
| M27-47 | Shared export scope widening | Denied by native membership/policy scope |
| M27-48 | Collaboration disabled | Personal browsing and memory remain complete |

## 12. Exit gates

| Gate | Requirement |
|---|---|
| M27-A | Shared workspace/member/device identities are distinct from M26 tenant/local profile IDs and have explicit lifecycle states. |
| M27-B | Invitation, role, device, epoch, revocation, and key transitions are signed, replay-safe, audited, and policy-admitted. |
| M27-C | Shared operation envelopes use fixed canonicalization, signature, AEAD, associated-data, nonce, epoch, and dedupe rules; no plaintext content enters routing fields/logs. |
| M27-D | Device/key custody and recovery have measured M6-compatible behavior; no administrator decryption backdoor is assumed. |
| M27-E | Operation replay/materialization is deterministic from a verified prefix; operation IDs, parents, Lamport order, and causal gaps are handled explicitly. |
| M27-F | Per-object merge policies distinguish safe metadata convergence from visible conflict forks; rich text/source prose never silently merges. |
| M27-G | Shared graph materialization preserves M4 revisions/provenance and M26 ownership/policy/deletion generations; it is rebuildable from operations. |
| M27-H | CloudKit private and shared transport modes remain separate; participant ACLs do not substitute for Hive membership; change tokens, zone resets, retries, and outbox acknowledgements are durable. |
| M27-I | Offline, stale, conflicted, key-locked, revoked, quarantined, and resync-required states are visible, accessible, resumable, and browser-first. |
| M27-J | Deletion, tombstones, revocation, late-device behavior, exports, backups, and external copies report honest scope-specific status. |
| M27-K | Shared content cannot widen context, permissions, policy, connector scopes, model destination, or action authority; prompt-injection fixtures pass. |
| M27-L | 48 fixtures pass; no presence/live editor/general CRDT scope is implied; documentation and product copy distinguish planned collaboration from current single-user sync. |

## 13. Evidence and research references

- Apple, [CloudKit sharing overview](https://developer.apple.com/documentation/cloudkit/sharing-cloudkit-data-with-other-icloud-users) — shared records/participant permissions are a transport/service boundary, not Hive’s complete membership authority.
- Apple, [CKShare.Participant](https://developer.apple.com/documentation/cloudkit/ckshare/participant) and [participant permission](https://developer.apple.com/documentation/cloudkit/ckshare/participantpermission) — explicit participant identity/permission states.
- Apple, [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine) — system sync coordinator with app-owned state persistence/recovery handling.
- Apple, [CloudKit syncing](https://developer.apple.com/documentation/cloudkit/synchronizing-cloudkit-records-with-cloudkit) — record-change and token-oriented sync contracts.
- Apple, [AES.GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm), [Curve25519](https://developer.apple.com/documentation/cryptokit/curve25519), and [CryptoKit](https://developer.apple.com/documentation/cryptokit) — AEAD, key agreement, and signing primitives; nonce/key custody remain app responsibilities.
- IETF, [RFC 9420 Message Layer Security](https://www.rfc-editor.org/rfc/rfc9420) — epoch-based authenticated group membership/key schedule concepts; M27 does not claim MLS implementation.
- IETF, [RFC 9162 Certificate Transparency v2](https://www.rfc-editor.org/rfc/rfc9162) — append-only integrity patterns reused by M26/M27 evidence, not a collaboration protocol.
- Automerge, [Automerge documentation](https://automerge.org/docs/) — CRDT synchronization model and trade-offs; M27 chooses an operation log first.
- Yjs, [Yjs documentation](https://docs.yjs.dev/) — shared-type CRDT model and provider separation; not adopted as a dependency by this plan.
- SQLite, [WAL](https://www.sqlite.org/wal.html) and [Online Backup API](https://www.sqlite.org/backup.html) — local journal/snapshot boundaries inherited from M0.

## 14. Implementation order and stop conditions

1. Re-read M26, M6, current sync sources/tests, and all call sites before any implementation.
2. Implement M27-A membership/device authority and fixtures before any shared CloudKit zone.
3. Implement M27-B key/epoch/envelope verifier before persisting shared content.
4. Implement M27-C operation log/materializer/conflict fixtures before team UI.
5. Implement M27-D transport/recovery against a deterministic fake CloudKit adapter before live service testing.
6. Implement M27-E surfaces and deletion/export only after A–D pass.

Stop immediately if:

- a shared workspace is inferred from a link, account, email domain, CloudKit zone, or network;
- current personal `e2e-key-v1` is reused for a team without an approved migration/key-scope decision;
- CloudKit participant permission is treated as complete Hive membership;
- a post-retrieval filter is used as the only shared isolation control;
- a revoked/late device can submit or receive new epoch keys;
- a rich-content conflict is silently overwritten or merged without a visible fork;
- a change-token failure initializes an empty shared database;
- collaboration blocks ordinary browsing or personal memory;
- a model/connector/shared content can mutate membership, policy, key custody, or permissions.

## 15. Definition of done

M27 is **verified** only when M27-A through M27-E have fresh build/test/runtime evidence, all 48 fixtures and 12 gates pass, independent envelope/operation verifiers reproduce signatures and materialized revisions, conflict forks are user-resolvable, revoked/late devices are quarantined, deletion/export status is honest across local/CloudKit/backup boundaries, and clean-profile browsing remains complete with collaboration disabled. Until then, M27 remains `planned` or `blocked` by exact missing evidence; current single-user CloudKit sync is not marketed as team collaboration.
