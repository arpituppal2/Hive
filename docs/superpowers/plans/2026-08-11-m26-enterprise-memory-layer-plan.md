# M26 Enterprise Memory Layer — Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; no implementation in this document
> **Depends on:** M0–M6 storage, provenance, lifecycle, MCP, and encryption decision contracts; M10 Sidecar; M11 Studio; M12 Command Center; M13 Projects & Tasks; M16 Worker boundary; M19 Connectors v1; M23 Mail + Calendar; M25 Engine Sovereignty.
> **Sibling boundary:** M27 is the later collaboration/sync milestone. M26 defines enterprise ownership, policy, audit, export, and lifecycle semantics for one local user/device or one explicitly assigned tenant context; it does not make Hive collaborative.
> **Primary sources:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`, `2026-08-11-m6-mcp-encryption-decision-plan.md`, `2026-08-11-m19-connectors-v1-plan.md`, `2026-08-11-m23-mail-calendar-modules-plan.md`, `2026-08-11-m25-engine-sovereignty-plan.md`, `AGENTS.md`, `docs/DECISIONS.md`.

## 0. Decision summary

M26 makes Hive enterprise-capable by defining an enforceable **tenant/workspace policy and evidence contract** over the existing Honeycomb, EventLedger, connector, sync, and memory-admission authorities. It does not claim that Hive is SOC 2 compliant, legally holds data, provides eDiscovery, or guarantees deletion while a device is offline. Those are organizational and deployment outcomes that require evidence beyond product code.

The smallest safe M26 shape is:

```text
managed tenant assignment + local policy snapshot
  → admission at every memory/connector/action boundary
    → one object model with tenant/workspace ownership
      → tamper-evident local audit events and verifiable export
        → retention/deletion-by-scope with explicit offline state
          → encrypted sync/backup decision from M6 evidence
            → browser-first enterprise degradation
```

M26 must preserve the local-first product property:

- A user can browse when no tenant policy, network, connector, cloud sync, or enterprise service is available.
- Enterprise memory never becomes an implicit model context merely because a device is enrolled.
- Administrative policy can restrict or require behavior, but cannot silently read private user content through the browser UI.
- A user-owned personal space and an enterprise-assigned space are distinct scopes with distinct retention, export, deletion, and remote-model rules.
- Every enterprise claim is labeled as `implemented`, `planned`, `best_effort_offline`, `requires_deployment_control`, or `not_supported`.

## 1. Current truth and reusable authorities

### 1.1 Existing primitives

The repository currently has useful building blocks, but they are not an enterprise layer:

| Primitive | Current truth | M26 use | What it does not prove |
|---|---|---|---|
| `HoneycombStore` | SQLite actor with typed nodes/edges, FTS, revisions, deduplication, provenance deletion, age deletion, and Markdown export | Canonical object graph and scoped retrieval authority | Tenant isolation, encrypted pages/WAL/backups, admin policy, legal hold, or enterprise export integrity |
| `EventLedgerStore` | Append-oriented local event store with parent event IDs, idempotent recording, dimension queries, and retention deletion | Local evidence source for consent, policy, sync, retrieval, deletion, and export events | Remote tamper resistance, tenant ownership, cryptographic inclusion proofs, or immutable deletion exceptions |
| `ContextScope` | Local profile/workspace scope fields | Input to tenant/workspace intersection | Enterprise identity or authorization authority |
| `MemoryAdmission` and related admission seams | Private/candidate/forgotten/scope checks exist in the memory path | Enterprise policy enforcement point input | Complete coverage of every future connector, cache, export, model, and sync path |
| `CloudKitSyncEngine` and `SyncCipher` | CloudKit sync path and opaque encrypted payload envelope exist | Candidate sync transport and envelope evidence | Tenant isolation, database/page encryption, backup deletion, or server-side enterprise controls |
| Keychain stores | Keychain-backed secrets/passwords/HMAC/sync key material exist in browser/core paths | Credential and key-reference custody | Encryption of SQLite files, WAL, temp files, backups, or a complete enterprise key lifecycle |
| M19 connectors | Planned read-only Calendar and selected filesystem authority | Reference connector scope/account/revocation model | Broad SaaS tenancy, admin policy, or background sync guarantees |
| M23 modules | Planned local-first read-only mail and Calendar product surface | Workday-class source examples and content boundaries | Send/mutate rights, shared mailboxes, legal hold, or enterprise retention |
| M25 engine contract | Renderer truth and engine-neutral boundary | Enterprise browser degradation and deployment matrix | Data governance or compliance evidence |

### 1.2 Missing controls M26 must define before implementation

- Stable tenant identity and assignment state separate from user/profile/workspace IDs.
- A policy snapshot with issuer, version, effective time, expiry, signature/status, and fail-closed fields.
- A deterministic ownership tuple for every durable object and derived artifact.
- Admission coverage for reads, writes, retrieval, model requests, connector sync, export, deletion, caches, and sync outbox.
- Administrative policy versus user ownership semantics, including the offline boundary.
- A tenant-scoped audit export format with integrity verification and redaction rules.
- Retention, deletion, revocation, backup, and recovery semantics that distinguish requested, accepted, applied, verified, and unavailable states.
- A measured encryption/key-custody decision that reuses M6 rather than calling Keychain or `SyncCipher` database encryption.
- Deployment evidence boundaries for MDM, signing, notarization, managed configuration, and incident response.
- A precise claim vocabulary so “SOC 2-track” cannot become a product warranty.

## 2. Product boundary and non-goals

### 2.1 In scope

1. One canonical local object model for Sources, SourceVersions, Claims, Briefs, Projects, Tasks, Sheets, Media, ConnectorAccounts, Actions, and audit events.
2. Tenant/workspace/profile ownership and policy intersection.
3. Enterprise-managed configuration with explicit offline behavior.
4. Read-only connector governance over M19/M23 authorities.
5. Tamper-evident local event evidence and independently verifiable export.
6. Retention and deletion-by-scope contracts across primary and derived stores.
7. Encryption and key-custody decision integration with M6.
8. Enterprise export, status, denial, recovery, and browser-first UX contracts.
9. Deterministic fixtures for isolation, leakage, policy, audit, deletion, recovery, and accessibility.

### 2.2 Explicit non-goals

- A SOC 2 report, certification, legal opinion, HIPAA/FINRA/SEC/PCI certification, or eDiscovery product.
- A hosted multi-tenant server, shared graph, CRDT collaboration, or team editing; those belong to M27 or a separately approved service.
- Real-time policy enforcement while a device is offline, powered off, compromised, or outside organizational management.
- A universal remote wipe guarantee for an unmanaged or offline device.
- Legal hold as a promise that prevents OS-level deletion, disk destruction, backups outside Hive, screenshots, or administrator actions outside Hive.
- Password-manager, health, financial, credential, or arbitrary home-directory ingestion.
- Connector-driven tool calls, model authority, task promotion, external mutation, or hidden context expansion.
- Treating a CloudKit private database or record zone as an enterprise tenant boundary without a separately proven account/organization authority.
- Treating FileVault, Keychain, or an opaque sync envelope as proof of app-level database encryption.
- Collaboration, shared ownership, invitation, comments, presence, or conflict-free replicated data types.

## 3. Authority model

### 3.1 Identity tuple

Every enterprise-scoped object and event must carry or resolve this tuple:

```json
{
  "tenant_id": "stable opaque identifier",
  "workspace_id": "stable opaque identifier",
  "profile_id": "stable local profile identifier",
  "device_id": "stable installation identifier",
  "owner_class": "personal | enterprise_assigned | system_derived",
  "scope_version": "monotonic policy/scope generation"
}
```

Identifiers are opaque, non-secret, non-model-generated, and never derived from email addresses, hostnames, file paths, or raw account tokens. A missing or ambiguous tuple is `unknown_scope`, not a default tenant.

`profile_id` and `workspace_id` remain local product concepts. `tenant_id` is an administrative assignment and must not be inferred from an Apple ID, browser profile, CloudKit container, email domain, or network location.

### 3.2 Authority precedence

| Decision | Authoritative owner | User can do | Admin/deployment can do | Offline behavior |
|---|---|---|---|---|
| Browser navigation/tabs | Hive browser state | Full ordinary browser use | Restrict only through an explicit managed-browser policy | Continue unless a policy explicitly blocks a feature |
| Memory admission | Local policy snapshot + M0–M6 admission | Capture/forget within allowed scope | Deny classes, force retention ceiling, restrict remote models/connectors | Use last valid policy; fail closed for unknown high-risk writes |
| Connector credentials/scopes | Connector authority + Keychain/M19/M23 | Grant/revoke own selected scope | Disable connector class or require managed account | Existing local data is labeled stale; no new sync when authority is unknown |
| Enterprise export | Local export authority + EventLedger | Export permitted personal/assigned scope | Require audit export policy and destination class | Queue only if policy permits; never claim delivery |
| Deletion | Lifecycle/deletion coordinator | Request deletion where allowed | Set retention floor/legal-hold marker where deployed | Record request; distinguish unapplied offline state |
| Model routing | Context broker + policy intersection | Opt into model/context scope | Restrict remote providers, model classes, and data classes | Local-only fallback or unavailable; never silently remote |
| Privileged action | M10/M11/M16/M17 approval/policy | Approve/deny visible action | Disable capability or require stronger grant | Deny when policy/grant cannot be revalidated |

No model output can create, alter, or approve tenant identity, policy, retention, deletion, legal hold, export authority, or key custody.

### 3.3 Policy snapshot contract

The managed policy snapshot is a signed/versioned document, not an arbitrary preference blob:

```json
{
  "policy_id": "opaque-id",
  "tenant_id": "opaque-id",
  "issuer": "managed-control-plane-identity",
  "version": 17,
  "issued_at": "RFC3339",
  "expires_at": "RFC3339",
  "status": "active | expired | revoked | invalid | unavailable",
  "data_classes": {
    "browser_metadata": "local | enterprise | denied",
    "captured_page_text": "local | enterprise | denied",
    "connector_content": "local | enterprise | denied",
    "model_remote": "allowed | approved_providers_only | denied"
  },
  "retention": {"max_days": 180, "audit_max_days": 365},
  "exports": {"allowed": true, "required_destination_class": "managed"},
  "connectors": {"calendar": "read_only", "filesystem": "selected_root_only"},
  "encryption_profile": "m6-decision-reference",
  "offline": {"max_age_hours": 72, "allow_durable_capture": true}
}
```

The implementation must validate signature/issuer, tenant match, version monotonicity, time bounds, supported schema, and policy revocation before admission. Unknown policy fields are ignored only when they are explicitly declared forward-compatible; unknown security fields deny the affected operation.

#### Policy trust bootstrap and rotation

A signed policy is not verifiable without an explicit trust root. M26 therefore requires a deployment-provided trust configuration containing:

- an allow-listed issuer identity and **Ed25519** signature algorithm/version `policy-sign-v1`;
- a bootstrap trust anchor provisioned through the signed app/managed configuration channel, never learned from the policy payload itself;
- key identifiers, validity windows, rotation rules, and revocation status;
- canonical policy bytes using UTF-8 JSON with sorted object keys, no insignificant whitespace, UTF-8 NFC strings, explicit `null` values where allowed, and RFC3339 UTC timestamps with a fixed fractional-second rule;
- bounded clock-skew handling and a monotonic policy-version rule;
- a safe transition rule for overlapping old/new signing keys; and
- a fail-closed result when the trust anchor, revocation state, or required clock evidence is unavailable for a high-risk operation.

The v1 key-transition payload is canonical JSON with `format: "hive-policy-key-transition.v1"`, `tenant_id`, `issuer`, `old_key_id`, `new_key_id`, `new_public_key`, `not_before`, `not_after`, `transition_sequence`, and `reason`. The currently trusted old Ed25519 key signs the transition bytes; the new key signs policies only at or after `not_before`; rollback is accepted only through another old-key-authenticated transition with a higher sequence. During overlap, either explicitly valid key may verify a policy, but revocation and validity windows win over overlap. A verifier rejects a transition with an unknown old key, sequence rollback, tenant/issuer mismatch, invalid time interval, duplicate key ID, or signature failure.

Trust-anchor installation, replacement, revocation, and failed verification are themselves redacted EventLedger events. Hive must not create an administrator backdoor or treat a CloudKit account, email domain, network, or tenant payload as a trust anchor. The independent policy verifier receives the canonical policy bytes, signature, issuer/key ID, trust configuration version, and verification time, and returns `valid`, `expired`, `revoked`, `invalid`, or `unavailable` with a non-secret reason code.

A stale policy does not automatically erase local memory. It changes what can happen next and exposes the exact stale reason. High-risk operations—remote model calls, connector sync, external export, privileged actions, and irreversible deletion—require a current policy unless an explicitly recorded emergency rule says otherwise.

## 4. Canonical object and ownership model

M26 does not create a parallel enterprise database. It adds required ownership, lifecycle, and policy dimensions to the existing canonical object graph.

### 4.1 Required common envelope

Every durable node, edge, revision, derived artifact, connector record, and export manifest has:

```json
{
  "object_id": "stable UUID",
  "object_type": "typed enum",
  "tenant_id": "opaque or null for personal-only",
  "workspace_id": "opaque",
  "profile_id": "opaque",
  "owner_class": "personal | enterprise_assigned | system_derived",
  "created_at": "RFC3339",
  "updated_at": "RFC3339",
  "provenance_ids": ["source/event/action IDs"],
  "retention_class": "user | enterprise | audit | derived",
  "deletion_state": "active | requested | pending | deleted | unavailable",
  "policy_version": 17,
  "content_class": "public | work | sensitive | restricted | private",
  "schema_version": 1
}
```

`tenant_id: null` means personal-only and cannot be implicitly attached to an enterprise workspace. Enterprise-derived objects must retain the source tenant and never become personal by copying or summarization.

### 4.2 Typed relations

Edges carry the ownership intersection of both endpoints plus an edge policy version. An edge is admissible only if both endpoints are visible to the requesting scope. A cross-scope relation is represented as an explicit, redacted reference or rejected; it is never silently widened.

Required relation families remain those defined by Honeycomb/M4: supports, derived-from, belongs-to, cites, creates, opens, depends-on, and supersedes. M26 adds ownership metadata and does not add freeform administrator-defined edge names.

### 4.3 Derived data rule

Embeddings, FTS rows, diffs, trails, briefs, task suggestions, chart results, transcript segments, caches, MCP pages, and export bundles are derived artifacts. Each records:

- source object IDs and source policy generation;
- derivation version and model/provider label, if any;
- tenant/workspace scope;
- deletion dependency set;
- rebuildability and whether raw source is required;
- remote-transfer status and destination, if allowed.

Deletion or policy revocation is incomplete while an eligible derived artifact remains retrievable. If physical destruction cannot be verified, the user sees `deletion_pending` or `deletion_unverified`, never `deleted`.

## 5. Admission and isolation contract

### 5.1 One intersection predicate

All enterprise-sensitive paths must call one shared conceptual predicate:

```text
admit(requester, object, operation, policy, lifecycle, connectorGrant)
  = identityMatch
  ∧ tenantMatch
  ∧ workspaceMatch
  ∧ profileMatch
  ∧ contentClassAllowed
  ∧ operationAllowed
  ∧ retentionStateAllows
  ∧ deletionStateAllows
  ∧ policyCurrentEnough
  ∧ connectorGrantIfNeeded
  ∧ modelDestinationAllowed
```

The predicate is evaluated before ranking, serialization, model prompt construction, export assembly, sync enqueue, cache insertion, or tool dispatch. Query filtering after retrieval is insufficient because it can leak counts, timing, snippets, or embeddings.

### 5.2 Isolation requirements

- Every query accepts a server/native-owned scope; caller-provided scope can only narrow it.
- Tenant IDs are compared by exact typed identity, never by display name or email domain.
- FTS/vector indexes are either physically partitioned or prove pre-ranking tenant admission; a post-ranking filter is not enough.
- Cache keys include tenant, workspace, profile, policy version, and retrieval generation.
- Sync outbox records include tenant and scope version; a queued mutation cannot be replayed under a different assignment.
- Exports include only an explicitly authorized scope and state their omissions.
- Connector content is untrusted data and cannot alter policy, permissions, routing, or actions.
- Prompt injection in work content is handled by the same M10/M19/M23 fencing rules as personal content.
- Counts, error messages, filenames, URL hosts, and timing must not reveal another tenant’s existence.

### 5.3 Model and remote boundary

Enterprise memory is not automatically eligible for remote inference. For every request, the UI and EventLedger receipt must identify:

- tenant/workspace scope;
- content classes and object IDs admitted;
- provider/model and actual inference status;
- local/remote destination;
- policy version and retention implication;
- redactions and omitted objects;
- whether the result is proposal-only or action-capable.

Unknown tenant policy, restricted content, private content, deleted content, audit-incomplete content, and connector secrets are denied. A local model may still be denied if the policy disallows model access entirely.

## 6. Audit evidence and export

### 6.1 Event classes

M26 extends—not replaces—the EventLedger event vocabulary. Consequential enterprise events include:

- tenant assignment, policy install/update/expiry/revocation;
- connector grant, refresh, scope change, sync checkpoint, stale/revoked state;
- object create/update/derive/read/export/delete/restore;
- model admission, provider route, remote-transfer decision, redaction;
- action proposal, approval, denial, execution, verification, rollback;
- retention evaluation, deletion request, dependent purge, backup status;
- encryption/key generation, rotation, unlock, failure, and recovery;
- audit export creation, signing, upload/acknowledgment, verification, failure.

Default events contain identifiers, hashes, classifications, outcomes, and summaries—not raw page text, secrets, credentials, full prompts, screenshots, or attachment bodies.

### 6.2 Tamper evidence without overclaim

The local ledger must support a versioned integrity mode selected by the M6 decision:

1. At minimum, each event stores a canonical payload hash, previous-event hash within its scope, event ID, sequence/generation, and schema version.
2. An export creates a manifest with scope, cutoff, event count, first/last sequence, root hash, policy version, and omitted/deletion-pending records.
3. A stronger Merkle-tree mode may provide inclusion/consistency proofs and signed tree heads when the implementation and key custody pass M26 fixtures.
4. If signing or remote anchoring is unavailable, the export says `locally_tamper_evident_unanchored`; it must not say “immutable,” “compliance-ready,” or “auditor-verified.”
5. Event deletion is governed by the retention class and legal/deployment policy. A deleted event leaves a redacted tombstone or verifiable omission record where the policy requires continuity; no raw secret is retained merely to prove deletion.

RFC 9162 is a useful model for append-only Merkle proofs, not a claim that Hive’s ledger is Certificate Transparency or automatically satisfies a SOC 2 audit.

### 6.3 Canonicalization and independent verification

The export verifier contract is executable only if the bytes being verified are deterministic. M26 fixes the following rules:

- Canonical serialization profile `hive-json-c14n-v1` is UTF-8 JSON with sorted object keys, no insignificant whitespace, UTF-8 NFC strings, explicit `null` values where the schema permits them, rejected duplicate object keys, RFC 8785-style shortest round-trippable JSON number formatting, JSON escaping limited to the canonical UTF-8 form, integer-only sequence fields, RFC3339 timestamps normalized to UTC with exactly three fractional digits, and base64url without padding for binary fields. Unsupported NaN, Infinity, negative zero, non-finite, or out-of-range numbers are rejected.
- M26 v1 fixes **SHA-256** as `H`, with raw bytes internally and base64url-without-padding at the JSON boundary. Domain separators are ASCII UTF-8 bytes followed by one NUL byte. Each event hash uses `H("hive-event-v1\\0" || canonical_event_bytes)`. The chain link uses `H("hive-chain-v1\\0" || previous_hash || event_hash || canonical_scope_generation_bytes)`, where `canonical_scope_generation_bytes` is exactly the unsigned big-endian 64-bit `scope_version`. The genesis schema is the canonical object with exactly these fields: `format: hive-audit-genesis.v1`, `tenant_id`, sorted `workspace_ids`, sorted `profile_ids`, `scope_version`, `schema_version`, `policy_version`, and `canonicalization: hive-json-c14n-v1`; absent scope lists are empty arrays, never omitted. Its hash is `H(\"hive-genesis-v1\" + one NUL byte + canonical_genesis_bytes)`, using the same SHA-256 function.
- Concurrent append branches are rejected unless they are reconciled into one ordered sequence with an explicit reconciliation event. Event IDs and sequence numbers are unique within the declared tenant/scope/generation; gaps, duplicates, reordering, scope changes, and generation changes fail verification.
- Merkle mode commits to the same canonical leaf bytes and fixes RFC 9162-style domain-separated SHA-256 leaves/nodes (`0x00 || leaf_bytes`, `0x01 || left_hash || right_hash`), declaring tree size, root hash, hash algorithm, leaf/node domain prefixes, and signed-tree-head key ID. Signed tree heads use Ed25519 `audit-sth-v1`; key rotation is represented by a signed transition record under the prior trusted key plus the new-key validity window. A verifier never silently substitutes a new key.
- An independent verifier accepts only the export bytes, declared verifier schema/canonicalization version, trust configuration, and explicitly supplied Ed25519 public keys. It returns `verified`, `partial`, or `failed` plus structured reasons for hash mismatch, signature failure, scope mismatch, unsupported version, omission, or incomplete export; it never needs raw secrets. Any future algorithm or canonicalization version is rejected as `unsupported_version` until a new verifier contract is explicitly approved.

These rules make “independently verifiable” a testable export property. They do not turn a local export into a remotely anchored or auditor-certified record.

### 6.4 Export envelope

The export format is deterministic, streamable, and independently checkable:

```json
{
  "format": "hive.enterprise-audit.v1",
  "tenant_id": "opaque-id",
  "scope": {"workspace_ids": ["..."], "profile_ids": ["..."]},
  "cutoff": "RFC3339",
  "policy_version": 17,
  "integrity": {
    "mode": "hash_chain | merkle_signed | unanchored",
    "event_count": 0,
    "first_sequence": 0,
    "last_sequence": 0,
    "root_hash": "base64url"
  },
  "records": [],
  "omissions": [],
  "verification": {"status": "verified | partial | failed"}
}
```

An export can include a separate object/provenance manifest for enterprise data portability, but audit evidence and content export remain distinct products with distinct permissions. Export cancellation is resumable; partial bundles are clearly marked and never presented as complete.

### 6.5 Evidence boundary

M26 records what Hive can produce for an auditor or customer security review:

- policy/configuration history;
- access/approval/deletion/sync evidence;
- test results and versioned build identity;
- key custody and encryption decision evidence;
- backup/restore and incident-recovery results;
- connector scope/revocation evidence;
- documented limitations and offline gaps.

SOC 2 control operation, management assertion, auditor independence, organizational access review, vendor management, incident response, and personnel controls remain outside the app. Product copy must say “supports evidence collection” or “SOC 2-track planning,” never “SOC 2 compliant” without an independently scoped report.

## 7. Retention, deletion, backup, and legal-hold boundary

### 7.1 Retention classes

| Class | Default owner | Policy floor/ceiling | User deletion | Admin control |
|---|---|---|---|---|
| `user` | personal workspace | user preference within local product limits | allowed and resumable | may disable enterprise export, not silently read content |
| `enterprise` | assigned tenant | managed ceiling and any declared floor | request/subject to policy | may require retention floor and export |
| `derived` | source owner | never outlives source policy without explicit exception | cascades from source | may force rebuild/purge |
| `audit` | tenant/deployment | separate audit retention | policy-governed/redacted tombstone | may require export/continuity |

A policy may require an enterprise retention floor, but M26 must show that a deletion request is `blocked_by_policy`, `queued_offline`, `applied_local`, `awaiting_sync`, or `verified` rather than collapsing states.

### 7.2 Deletion-by-scope

Supported scopes are explicit and typed:

- object and descendants;
- source/version and all derived artifacts;
- workspace;
- profile;
- tenant assignment on this device;
- connector account/root;
- “forget recent interval” as governed by M5;
- local cache/index generation;
- sync outbox and remote record tombstones where the transport supports them.

Deletion must traverse Honeycomb, EventLedger metadata allowed by policy, FTS, vectors, diffs, trails, briefs, tasks, sheets, media/transcript segments, MCP caches, model queues, export staging, and sync outbox. It must report stores not reachable, stores not yet processed, backup limitations, and external connector deletion status.

A local delete is not proof of remote deletion. CloudKit tombstones, exported copies, managed backups, filesystem snapshots, Time Machine, and SIEM copies each have separate lifecycle status. Crypto-shredding is an optional M6/M26 implementation outcome, not an assumed guarantee.

### 7.3 Legal hold and eDiscovery

M26 defines a **local policy marker** only if a deployment supplies a valid authority, scope, issuer, expiry/release, and audit record. The marker can block Hive-initiated deletion for matching objects and disclose that state to the user. It cannot guarantee preservation against OS-level deletion, disk loss, unmanaged copies, screenshots, external connector retention, or administrator actions outside Hive.

Hive does not implement legal advice, discovery search, collection certification, or litigation workflow. The product must use “retention hold marker” unless a separately approved legal/compliance workstream establishes the stronger contract.

### 7.4 Backup and recovery

Every backup/restore action carries source tenant/workspace scope, schema, encryption profile, creation time, policy generation, and verification result. Raw SQLite copying is not called transactional; WAL/shared-memory state and Online Backup API boundaries are documented by M0. Restore into a different tenant or profile is denied by default. A restored database is quarantined until identity, policy, schema, integrity, and deletion generations are reconciled.

## 8. Encryption and key custody decision

M26 consumes M6’s encryption ADR rather than preselecting SQLCipher or a Secure Enclave design.

Required candidate evidence:

- page/WAL/temp/backup coverage;
- FTS and vector behavior;
- startup, unlock, biometric, lock, and offline behavior;
- key generation, rotation, revocation, recovery, and device replacement;
- migration and restore compatibility;
- performance, battery, thermal, and crash impact;
- licensing/distribution and M25 signing/notarization impact;
- whether an administrator or service can decrypt content;
- deletion/crypto-shredding verification limits.

Key rules:

- Secrets and credentials remain Keychain-only and never enter prompts, logs, exports, or source fixtures.
- A Keychain reference is not itself a database-encryption claim.
- Secure Enclave keys may be non-exportable; this can complicate multi-device recovery and must be user-visible.
- Enterprise recovery keys require a separate, explicit custody decision; Hive must not invent an administrator backdoor.
- Remote sync is denied until the destination, payload class, key version, and policy permit it.
- Lock, logout, tenant unassignment, policy revocation, and key failure have distinct states and recovery paths.

## 9. Deployment, administration, and browser-first behavior

### 9.1 Managed deployment evidence

M26 documents, but does not assume, the deployment controls needed for an enterprise claim:

- signed/notarized app and any privileged helper;
- hardened runtime and least-privilege entitlements;
- MDM-managed configuration and profile identity;
- update channel, rollback, and emergency disable behavior;
- device inventory/assignment authority outside Hive;
- admin access review, incident response, and key custody procedures;
- support boundaries for personal Macs, shared Macs, offline devices, and unmanaged copies.

### 9.2 Browser-first degradation matrix

| Failure | Browser | Memory | Enterprise status |
|---|---|---|---|
| No tenant assignment | Full browsing | Personal scope only; enterprise writes denied | `unassigned` |
| Policy expired | Full browsing | Existing local reads labeled stale; high-risk writes/remote calls denied | `policy_stale` |
| Network unavailable | Full browsing | Local permitted operations continue; sync/export report queued/offline | `offline` |
| Key unavailable | Full browsing | Encrypted enterprise memory unavailable; no plaintext fallback | `locked` |
| Ledger integrity failure | Full browsing | Consequential enterprise operations denied; inspection/export may be partial | `audit_blocked` |
| Connector revoked | Full browsing | Existing data stale/retention governed; new sync denied; deletion state visible | `revoked` |
| MDM removed | Full browsing | Tenant unassignment flow; no silent conversion to personal data | `unmanaged` |
| Enterprise service down | Full browsing | Last valid local policy and local-only path within TTL | `service_unavailable` |

No failure state may hide ordinary navigation, tabs, private browsing, or the zero-history browser path.

### 9.3 Accessibility and user comprehension

Enterprise status is visible without exposing sensitive tenant names or content. Every denial explains the operation, scope, policy reason, and next safe action. VoiceOver labels include scope and stale/offline state; keyboard users can inspect, export, cancel, retry, revoke, and delete; dynamic type does not truncate the actual policy reason; reduced motion/transparency is respected. Admin-only controls are not rendered as disabled pretend-actions in personal mode.

## 10. Work packages

### M26-A — Tenant identity and policy admission

Define typed tenant assignment, signed/versioned policy snapshots, scope intersection, policy cache TTL, revocation, offline behavior, and a complete admission coverage map. Reuse M0–M6/M19/M23 authorities; do not create a second permission system.

**Done when:** identity/policy fixtures pass; unknown/stale/revoked policies fail closed at every listed high-risk boundary; personal browsing and personal memory remain separable; no model/tool can mutate policy.

### M26-B — Enterprise object model and source portability

Specify migrations for common ownership envelopes, typed edges, revisions, derived-artifact dependencies, connector/account identity, and deterministic enterprise content/provenance export. Map every existing object type and document null/personal/enterprise ownership.

**Done when:** every canonical object has one ownership/lifecycle answer; cross-tenant reads, copied derived artifacts, and scope-changing restores are rejected; export manifests are deterministic and omission-aware.

### M26-C — Audit integrity and verifiable exports

Add the versioned event taxonomy, scope-aware hash-chain/Merkle decision, export envelope, redaction, cancellation/resume, independent verifier contract, and EventLedger retention interaction. Keep raw content and secrets out of default audit evidence.

**Done when:** fixtures verify ordering, tamper detection, scope boundaries, partial export, redaction, deletion markers, key failure, and honest unanchored/verified states.

### M26-D — Lifecycle, encryption, sync, and recovery

Execute the M6 encryption ADR; define tenant-scoped sync/outbox, backup/restore quarantine, retention floors/ceilings, deletion-by-scope, derived-data cascade, key rotation, offline queues, unassignment, and local hold markers. Do not implement collaboration or shared graph semantics.

**Done when:** lifecycle fixtures distinguish request/applied/verified/unavailable; no deleted object remains retrievable through a derived path; remote/backup status is honest; encryption claims match measured coverage.

### M26-E — Enterprise surfaces and browser-first release gate

Build the minimal status/policy/audit/export/deletion surfaces only after A–D contracts pass. Validate M19/M23 connector presentation, M10/M11/M16 privileged boundaries, M25 renderer packaging, accessibility, clean-profile behavior, and managed/unmanaged/offline matrices.

**Done when:** an enterprise user can inspect scope/policy, perform an authorized export, request/delete permitted data, see stale/offline/key/ledger states, and continue browsing with enterprise services disabled. No UI implies collaboration, legal hold, SOC 2 certification, or remote deletion certainty.

## 11. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M26-01 | Valid tenant assignment | Accepted with exact opaque identity |
| M26-02 | Missing tenant assignment | Personal-only; enterprise operation denied |
| M26-03 | Tenant mismatch in object | Read/write denied without existence leak |
| M26-04 | Workspace mismatch | Object excluded before ranking |
| M26-05 | Profile mismatch | Object excluded; no fallback to current profile |
| M26-06 | Expired policy | Browsing works; high-risk operations denied |
| M26-07 | Revoked policy | New enterprise operations denied; state visible |
| M26-08 | Unsupported security field | Affected operation denied |
| M26-09 | Monotonic policy rollback | Older policy rejected |
| M26-10 | Offline within policy TTL | Allowed local operations labeled offline |
| M26-11 | Offline past TTL | High-risk operation denied |
| M26-12 | Connector grant outside tenant | Sync denied |
| M26-13 | Connector revocation during sync | Queue stops and records revocation |
| M26-14 | Cross-tenant FTS query | No rows, counts, or snippets leak |
| M26-15 | Cross-tenant vector query | No candidates enter ranking |
| M26-16 | Cross-tenant cache collision | Cache entries remain isolated |
| M26-17 | Deleted source with live brief | Brief is unavailable/deletion-pending, not stale-success |
| M26-18 | Derived vector after delete | Vector is removed or excluded before ranking |
| M26-19 | Personal object copied into enterprise | Explicit promotion required; no implicit reassignment |
| M26-20 | Enterprise object copied personal | Denied unless policy explicitly permits sanitized export |
| M26-21 | Hostile connector prompt injection | Content remains data; no authority change |
| M26-22 | Credential-shaped connector content | Redacted; never logged or prompted |
| M26-23 | Audit event duplicate retry | One stable event, idempotent result |
| M26-24 | Audit event reordered | Verification fails with exact sequence reason |
| M26-25 | Audit event payload tamper | Hash verification fails |
| M26-26 | Audit export scope narrowing | Output contains only requested permitted scope |
| M26-27 | Audit export scope widening | Widening denied by native scope |
| M26-28 | Audit export cancellation | Partial bundle labeled incomplete and resumable |
| M26-29 | Audit export redaction | Raw content/secrets absent; omission recorded |
| M26-30 | Unanchored local export | Status says locally tamper-evident/unanchored |
| M26-31 | Merkle inclusion proof | Valid proof verifies independently when mode exists |
| M26-32 | Invalid signing key | Export is partial/failed, never verified |
| M26-33 | Retention ceiling | Expired eligible data is selected deterministically |
| M26-34 | Retention floor | User delete reports blocked_by_policy |
| M26-35 | Deletion by source | All reachable derived stores are reconciled |
| M26-36 | Deletion by workspace | No object remains retrievable in that scope |
| M26-37 | Deletion by tenant assignment | Local tenant data is quarantined/purged per policy |
| M26-38 | Deletion while offline | Request is queued and not falsely marked applied |
| M26-39 | Backup restore into wrong tenant | Restore quarantined and rejected |
| M26-40 | WAL-inclusive snapshot | Snapshot consistency is verified before restore |
| M26-41 | Key unavailable | No plaintext fallback; enterprise memory locked |
| M26-42 | Key rotation mid-sync | Old/new versions reconcile without cross-scope replay |
| M26-43 | Cloud tombstone unavailable | Local deletion reports awaiting_sync |
| M26-44 | Local hold marker | Matching deletion blocked and audited |
| M26-45 | Hold release | Eligible deletion resumes with lineage |
| M26-46 | MDM unassignment | No silent personal conversion or policy bypass |
| M26-47 | Accessibility audit/export flow | Keyboard/VoiceOver can inspect and complete permitted path |
| M26-48 | All enterprise services disabled | Browser, tabs, private mode, and personal start page remain usable |

## 12. Exit gates

| Gate | Requirement |
|---|---|
| M26-A | Tenant/profile/workspace identity tuple and signed policy snapshot validate deterministically; unknown, stale, revoked, and mismatched states have explicit outcomes. |
| M26-B | Admission coverage matrix proves policy is evaluated before retrieval, serialization, model context, sync, export, cache, connector, and action boundaries. |
| M26-C | Canonical object envelope, typed ownership, edge intersection, derived-artifact dependency, and migration mapping are documented with no second memory authority. |
| M26-D | Cross-tenant, cross-workspace, cache, FTS, vector, connector, and model-context isolation fixtures pass without existence or timing leaks in the tested surface. |
| M26-E | Audit events are scope-aware, idempotent, tamper-evident at the selected integrity mode, and default-redacted. |
| M26-F | Audit/content export is deterministic, cancellable, resumable, omission-aware, and independently verifiable or honestly marked unanchored/partial. |
| M26-G | Retention and deletion-by-scope traverse primary and derived stores and distinguish requested, blocked, queued, applied, awaiting-sync, failed, and verified. |
| M26-H | Backup/restore, WAL, key rotation, key failure, tenant unassignment, and offline recovery preserve scope and do not claim unsupported erasure. |
| M26-I | M6 encryption ADR is executed or explicitly held with measured limitations; Keychain/SyncCipher/FileVault language is truthful. |
| M26-J | M19/M23 connector grants, revocation, stale state, credentials, content classification, and deletion use the same tenant/policy authority. |
| M26-K | Managed/unmanaged/offline/browser-first and accessibility paths pass with enterprise services disabled or unavailable. |
| M26-L | Documentation, security review, export verifier, deployment evidence boundary, and product copy all distinguish implementation from SOC 2-track support; M27 collaboration remains deferred. |

## 13. Evidence and research references

- AICPA, [2017 Trust Services Criteria with revised points of focus 2022](https://www.aicpa-cima.com/resources/download/2017-trust-services-criteria-with-revised-points-of-focus-2022) — control/evidence framework; not a product certification.
- NIST, [SP 800-207 Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final) — no implicit trust from network location; per-resource policy and continuous evaluation.
- NIST, [SP 800-53 Rev. 5](https://csrc.nist.gov/pubs/sp/800/53/rev-5/final) — least privilege, audit, configuration, and privacy control families.
- Apple, [CloudKit encrypting user data](https://developer.apple.com/documentation/cloudkit/encrypting-user-data) — CloudKit encryption and application-controlled protection boundaries.
- Apple, [iCloud data security overview](https://support.apple.com/en-us/102651) — standard/advanced protection and metadata limitations.
- Apple, [Keychain data protection](https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web) — hardware/data-protection-backed secret custody; not database encryption.
- Apple, [Advanced Data Protection for iCloud](https://support.apple.com/guide/security/advanced-data-protection-for-icloud-secf6276da8a/web) — useful comparison for key sovereignty; not proof that Hive inherits the model.
- IETF, [RFC 9162 Certificate Transparency v2](https://www.rfc-editor.org/rfc/rfc9162) — append-only Merkle-log concepts used as an integrity reference, not a compliance claim.
- SQLite, [transactions](https://www.sqlite.org/lang_transaction.html), [WAL](https://www.sqlite.org/wal.html), [foreign keys](https://www.sqlite.org/foreignkeys.html), and [Online Backup API](https://www.sqlite.org/backup.html) — storage/recovery boundaries inherited from M0.
- Apple, [Platform Deployment](https://support.apple.com/guide/deployment/welcome/web) — managed deployment is an organizational boundary, not automatically a Hive runtime guarantee.

## 14. Implementation order and stop conditions

1. Re-read M0–M6, M19, M23, M25, current source, and all call sites before any implementation.
2. Implement M26-A identity/policy contract and fixtures first.
3. Implement M26-B object ownership and admission coverage before adding enterprise UI.
4. Execute M26-C audit/export verifier before promising audit-trail exports.
5. Execute M26-D only after M6 encryption evidence and deletion/recovery fixtures are available.
6. Add M26-E surfaces last, with enterprise services optional and browser-first regression coverage.

Stop immediately if:

- an implementation introduces a second memory or permission authority;
- a tenant is inferred from an email domain, Apple account, CloudKit container, or network;
- a post-retrieval filter is used as the only isolation control;
- a model or connector can mutate policy or permissions;
- a local deletion is labeled complete without dependent-store and remote-status evidence;
- a legal hold or SOC 2 certification is implied without the separate organizational contract;
- browser navigation or private mode depends on enterprise availability.

## 15. Definition of done

M26 is **verified** only when M26-A through M26-E have fresh build/test/runtime evidence, all 48 fixtures and 12 gates pass, an independent export verifier validates the selected audit mode, encryption/deletion claims match measured evidence, enterprise and personal scopes remain isolated across restart/recovery, and clean-profile browsing works with tenant assignment, network, connectors, sync, models, and enterprise UI disabled. Until then, M26 remains `planned` or `blocked` by the exact missing evidence; it is never marketed as enterprise compliance or collaboration.
