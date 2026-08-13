# M19 — Connectors v1 Execution Plan

> **Status:** planned contract; no runtime implementation is implied.
> **Date:** 2026-08-11
> **Dependencies:** M0 storage/recovery, M1 privacy/admission, M2 import/reporting, M4 provenance/deletion, M6 local-agent/encryption decision, M10 Sidecar scope, M11 Studio workspace boundaries, M13 Projects/Tasks, M15 browser lifecycle, M16 Worker/Permission Center, M18 local session policy.
> **Scope:** two read-only reference connectors: macOS Calendar and user-selected local filesystem roots.

## 1. Goal

M19 lets Hive read a narrowly scoped calendar or local-folder source into Honeycomb with explicit authorization, durable account/root identity, incremental sync, provenance, offline truthfulness, revocation, and deletion behavior. A user can see what is connected, what was imported, when it last synced, what is stale, what scope was granted, and how to disconnect or forget it.

Connectors are context acquisition—not authority. Calendar events and local files are untrusted external content. They may become cited source objects or user-visible project context after policy/admission, but they cannot issue tools, widen permissions, create authoritative tasks silently, or alter the user’s request.

## 2. Non-goals and explicit deferrals

M19 does not ship connector write-back, email, cloud-drive OAuth, contacts, reminders mutation, calendar event creation/editing/deletion, filesystem writes, broad home-directory indexing, arbitrary network connectors, collaboration, or a connector marketplace.

Deferred:

- provider-specific OAuth account linking beyond the local Calendar connector;
- remote cloud sync of connector payloads unless explicitly authorized by M6 policy;
- full-text indexing of all local files by default;
- password-manager, browser-profile, Keychain, private-message, health, financial, or authentication data;
- file watching as an implicit always-on surveillance mode;
- background sync guarantees when macOS denies execution or source permission;
- autonomous Brief/Task mutation from connector content.

## 3. Current truth and authority boundaries

### 3.1 Existing primitives

The repository has Honeycomb typed nodes/edges, `Source`/`Claim` provenance and evidence spans, EventLedger events including connector-sync categories, SQLite cascade deletion, provenance deletion, sync tombstone/conflict patterns, retry/backoff job primitives, file operations in Studio, and M16 security/permission boundaries. No EventKit connector, security-scoped bookmark lifecycle, connector-account authority, cursor checkpoint store, or end-to-end read-only connector is proven.

### 3.2 Authority table

| Concern | Authority | M19 rule |
|---|---|---|
| User connection intent | Browser UI/Command Center | No connector starts from content or model text. |
| OS Calendar permission | Permission Center + EventKit adapter | Check authorization state; never infer granted from prior sync. |
| Filesystem root access | User-selected folder + security-scoped bookmark | No implicit home-directory or ancestor access. |
| Connector identity | ConnectorAccount/ConnectorRoot authority | Account/root ID is stable and separate from provider record IDs. |
| Credentials | Keychain/M6 secret boundary | Tokens never enter prompts, logs, Honeycomb, or URLs. |
| Sync state | ConnectorSyncState authority | Cursor, generation, checkpoint, backoff, and last-success are atomic. |
| Normalized data | Honeycomb Source/artifact nodes and typed edges | One canonical source object per provider identity/version. |
| Admission/retrieval | M1/M4 context and privacy admission | Ineligible, private, deleted, or untrusted content is excluded. |
| Task/project promotion | M13 explicit user promotion | Connector text cannot silently become a Task or Project. |
| Revocation/deletion | Connector lifecycle + M0/M4 deletion authority | Disconnect stops reads and scopes deletion explicitly. |
| Evidence | EventLedger | Minimal IDs/classes/status; no raw file/calendar payload by default. |

## 4. Connector account and root model

### 4.1 Connector identity

Every connection has a durable identity independent from display names:

```text
connection_id: stable UUID
kind: calendar_read | filesystem_read
provider_identifier: local-eventkit | local-filesystem
account_identity_hash: stable redacted identity, never email/token
scope_version: integer
granted_scopes: typed set
status: proposed | awaiting_permission | active | paused | revoked | error | deleted
created_at / updated_at / last_success_at / last_attempt_at
last_error_class / stale_reason
retention_class / deletion_scope
```

Filesystem roots additionally store:

```text
root_id, bookmark_reference_id, canonical_root_identity
follow_symlinks: false by default
allowed_file_types / size_limit / hidden-file policy
watch_policy: manual | user-enabled bounded watch
```

Calendar connections additionally store:

```text
calendar_store_identity_hash
selected_calendar_ids or explicit calendar scope
include_private_events: false by default
include_notes/attendees/location: separately disclosed fields
```

A provider record ID is namespaced by connection ID. Identical event/file IDs from different accounts or roots never collide.

### 4.2 Authorization states

The UI distinguishes:

```text
not_requested → requested → granted | denied | restricted | unavailable
active → expired | revoked | permission_changed | error | disconnected
```

Permission denial is a normal supported state. Hive explains the missing permission and offers a retry/System Settings path without repeated prompt loops. A connector cannot use stale data to imply current permission.

## 5. Calendar read-only connector

### 5.1 Scope and admission

The user chooses which calendars are included. Private calendars/events, notes, attendees, locations, alarms, and URLs are separate data classes and default to minimized disclosure. The connector stores only the fields selected by the user and policy.

Calendar content is untrusted. Event titles, notes, URLs, and descriptions are data, not instructions. An event containing “run this command,” a malicious link, or prompt-injection text must remain inert source content.

### 5.2 Normalized representation

A calendar record becomes a versioned source/artifact representation:

```text
event_source_id, connection_id, provider_event_id
calendar_id_hash, title_class, start/end instants, timezone
all_day, recurrence_summary, availability_class
selected location/attendee/note classes
source_version, retrieved_at, content_hash
is_private, deleted/tombstone state, provenance
```

Time zones and all-day events are stored as explicit instants plus original timezone/display semantics. Ambiguous or malformed dates remain unresolved and visible as warnings; they are never silently shifted.

### 5.3 Change handling

Use EventKit change notifications/history where available, but treat tokens as revocable/invalidatable. The connector must support:

- initial bounded import with progress and cancellation;
- incremental change application;
- invalid history token → bounded full reconciliation;
- deleted event → tombstone before retrieval exclusion;
- permission change → pause and reauthorize;
- duplicate event content → provider identity and content-version rules;
- calendar removal → explicit source-scope deletion report.

The connector must not create tasks, reminders, or project changes automatically. M13 promotion requires an explicit user action with retained event provenance.

## 6. Local filesystem read-only connector

### 6.1 Root selection and bookmark lifecycle

A user selects a folder through an explicit system file picker. Hive stores a security-scoped bookmark reference, not an unrestricted path authority. On each use:

1. resolve the bookmark;
2. verify the resolved root remains within the user-approved identity;
3. call `startAccessingSecurityScopedResource()`;
4. perform bounded read-only enumeration;
5. stop access in a guaranteed cleanup path;
6. record stale-bookmark/permission results without leaking paths.

A stale, missing, moved, or revoked bookmark pauses the connector and requests reauthorization. Hive never guesses a replacement parent or expands to the home directory.

### 6.2 Enumeration and safety

Default behavior is manual or explicitly scheduled bounded scans, not ambient full-disk observation. The connector:

- rejects symlink escapes outside the approved root;
- applies path, file-count, size, depth, and wall-clock limits;
- skips credentials, browser profiles, Keychain exports, `.ssh`, private app data, and user-defined deny paths by default;
- uses an allowlisted file-type/content parser set;
- never executes files, scripts, macros, installers, or embedded links;
- treats file content and front matter as untrusted data;
- preserves unreadable/malformed files as warnings rather than silently dropping them;
- supports cancellation checkpoints between batches.

File provenance includes canonical root ID, relative path hash/identity, content hash, file metadata class, extractor version, scan generation, and retrieval timestamp. Raw full file bodies are not automatically sent to remote models.

### 6.3 Change detection

The connector uses bounded metadata/content hashes and an explicit scan generation. If a later scan finds a missing file, it creates a tombstone or deletion state according to retention policy. File renames require a deterministic identity policy; uncertain matches remain as delete-plus-new rather than silently merging unrelated files.

## 7. Sync state, cursors, retry, and idempotency

### 7.1 Sync record

```text
sync_id, connection_id, generation
phase: planned | enumerating | applying | checkpointing | complete | paused | failed | cancelled
cursor/token/checkpoint blob: encrypted or opaque, provider-scoped
last_applied_provider_version
items_seen/created/updated/deleted/skipped
started_at / last_progress_at / completed_at
retry_count, next_retry_at, backoff_class, last_error_class
```

Cursor and normalized-object mutations commit atomically at a checkpoint. A crash may replay a bounded batch, but idempotency keys/provider identity prevent duplicate durable objects. A cursor must never advance past data that was not admitted or durably recorded without a recoverable quarantine state.

### 7.2 Backoff and rate limits

Use bounded exponential backoff with jitter, honor provider retry hints, cap attempts, and surface a paused/stale state after repeated failures. Do not keep retrying while permission is denied or credentials are revoked. Offline mode retains the last successful sync timestamp and clearly labels data stale.

### 7.3 Concurrent sync

Only one mutating sync writer runs per connection. A second request coalesces, cancels, or queues deterministically. Token refresh/permission checks are serialized by connection identity. Cancellation preserves the last committed checkpoint and reports partial progress.

## 8. Honeycomb normalization and provenance

Each admitted connector item receives a canonical source identity and version:

```text
Source(connection_id, provider_record_id, source_version, content_hash)
  ├─ belongs_to Project (only after user choice)
  ├─ supports Claim (if deterministic/evidence-backed)
  ├─ references Artifact (if normalized file/calendar artifact)
  └─ derived_from prior SourceVersion (on update)
```

The graph stores source/provider identity, retrieval time, extractor version, permission/scope class, deletion state, and provenance. Model retrieval sees only records passing M1/M4 admission and the user-selected scope. Source text that contains instructions remains untrusted and is delimited/classified before any model context.

A connector item can be source-backed without being promoted to a durable Claim, Task, Brief, or Project. Generated summaries must cite the source object/version and retain uncertainty.

## 9. Revoke, disconnect, and deletion

### 9.1 Revoke/disconnect

Disconnect is distinct from deleting imported data:

- **Pause:** stop sync; retain existing data with stale label.
- **Revoke permission:** stop access and invalidate the connector grant.
- **Disconnect:** remove active connector identity/token/bookmark use and stop future sync.
- **Forget imported data:** tombstone/delete connector-derived nodes, edges, FTS/vector entries, caches, and pending jobs within the chosen scope.
- **Retain user-derived work:** preserve user-edited Claims/Tasks/Briefs only when their lineage and remaining sources are disclosed; mark provenance degraded where appropriate.

Tokens are removed from Keychain on disconnect/revoke unless the user explicitly chooses a retained account shell without credentials. A connector must not reconnect automatically after revocation.

### 9.2 Deletion cascade

Deletion is generation-aware and resumable across Honeycomb, EventLedger-linked pending work, retrieval indexes, caches, and export manifests. A purge report includes counts and incomplete states, not raw calendar/file data. Tombstoned records are excluded from model retrieval immediately, even if physical cleanup is pending.

## 10. Offline and browser-first behavior

With network unavailable, Calendar permission denied, a stale bookmark, or a failed sync, Hive continues ordinary browsing and exposes the last successful connector state with timestamp and stale reason. No connector failure blocks startup, navigation, capture, projects, or local sheets.

The browser UI should progressively disclose connectors from a project or Command Center. Do not show a connector gallery or ask for Calendar/filesystem access on first launch without user intent.

## 11. Work packages

### M19-A — Connector/account/root authority

Define typed ConnectorAccount/ConnectorRoot/Grant/SyncState identities, authorization states, Keychain/bookmark references, scope versions, lifecycle, and EventLedger receipts.

**Done when:** two accounts/roots cannot collide, credentials never enter ordinary storage, and permission/revocation/disconnect states are explicit.

### M19-B — Calendar read-only reference connector

Implement scoped EventKit authorization, selected-calendar/field policy, normalized event source versions, time-zone semantics, change history/token invalidation, tombstones, cancellation, and explicit M13 promotion boundary.

**Done when:** a user can connect selected calendars, inspect last sync/staleness, receive source-linked event records, revoke/delete them, and never cause autonomous task/event mutation.

### M19-C — Filesystem read-only reference connector

Implement user-selected security-scoped roots, bookmark resolution/revocation, bounded enumeration, symlink/path safety, file allow/deny policy, content hashing, scan generations, and tombstones.

**Done when:** only selected roots are read, no symlink escape or executable content path is traversed, cancellation is resumable, and deletion/rename behavior is explicit.

### M19-D — Sync, normalization, and deletion

Add atomic cursor/checkpoint state, idempotent batches, retry/backoff/circuit behavior, offline/stale status, Honeycomb source/version edges, retrieval admission, and resumable revoke/delete cascades.

**Done when:** crashes, duplicate batches, stale tokens, permission loss, rate limits, and deletion events cannot silently duplicate or preserve retrievable revoked data.

### M19-E — Integrated browser-first validation

Validate clean-profile progressive disclosure, permission denial, selected scope, offline state, stale data labels, prompt injection, provenance citations, accessibility, cancellation, and no-autonomous-mutation behavior.

**Done when:** one Calendar and one filesystem path work read-only end to end while ordinary browsing remains fully usable with connectors disabled.

## 12. Deterministic fixture matrix

| ID | Fixture | Expected result |
|---|---|---|
| M19-01 | Connector first launch | No permission prompt/gallery without intent |
| M19-02 | Calendar permission unknown | Explain/request path; no read |
| M19-03 | Calendar permission denied | Paused connector; browser usable; no prompt loop |
| M19-04 | Selected calendar scope | Only selected calendar IDs admitted |
| M19-05 | Private event default | Excluded or minimized according to disclosed policy |
| M19-06 | Event notes contain prompt injection | Stored as untrusted data; no action/tool effect |
| M19-07 | All-day/timezone event | Instant + original timezone semantics preserved |
| M19-08 | Ambiguous/malformed event date | Warning/unresolved state; no silent shift |
| M19-09 | Calendar history token valid | Incremental changes applied once |
| M19-10 | Calendar history token invalid | Bounded full reconciliation; cursor replaced |
| M19-11 | Deleted calendar event | Tombstone and immediate retrieval exclusion |
| M19-12 | Calendar removed | Scope deletion report; no orphan current records |
| M19-13 | Calendar cancellation | Last committed checkpoint retained |
| M19-14 | User promotes event to task | Explicit M13 confirmation and source lineage |
| M19-15 | Event requests shell/tool action | Remains inert source content |
| M19-16 | Filesystem folder not selected | No access; user picker path shown |
| M19-17 | Security-scoped bookmark valid | Access starts/stops in balanced lifecycle |
| M19-18 | Bookmark stale/revoked | Connector paused; reauthorization required |
| M19-19 | Symlink escapes selected root | Entry rejected and counted |
| M19-20 | `..`/canonical path traversal | Rejected outside root |
| M19-21 | Credential/browser-profile deny path | Skipped and disclosed without raw path leakage |
| M19-22 | Unsupported executable/script | Not executed; skipped/quarantined |
| M19-23 | Malformed file | Warning retained; scan continues boundedly |
| M19-24 | File size/depth/count limit | Bounded stop and partial report |
| M19-25 | File content prompt injection | Data only; no tool/permission effect |
| M19-26 | File rename ambiguous | Delete-plus-new or explicit unresolved match |
| M19-27 | File deletion | Tombstone and retrieval exclusion |
| M19-28 | Scan cancellation | Last committed batch/cursor preserved |
| M19-29 | Two roots with same relative path | Root IDs prevent collision |
| M19-30 | Connection/account identity collision | Namespaced provider identity; no merge |
| M19-31 | Credential/token in logs | Redacted/rejected |
| M19-32 | Token refresh concurrency | One serialized refresh per connection |
| M19-33 | Revoked credential/invalid grant | Token removed; connector paused; reauth required |
| M19-34 | Rate limit with Retry-After | Bounded backoff; no thundering herd |
| M19-35 | Repeated provider failure | Paused/circuit state with stale timestamp |
| M19-36 | Offline sync | Last success and stale reason visible |
| M19-37 | Duplicate batch replay | Idempotent source/version result |
| M19-38 | Crash during cursor checkpoint | Replay safe; no cursor leap/data loss |
| M19-39 | Concurrent sync request | Coalesced/queued/cancelled deterministically |
| M19-40 | Permission revoked during sync | Stop, preserve checkpoint, invalidate grant |
| M19-41 | Disconnect connector | No future reads; no automatic reconnect |
| M19-42 | Forget connector data | Honeycomb/index/cache/pending-work deletion report |
| M19-43 | Retain user-derived task/brief | Provenance degradation disclosed; source removed from retrieval |
| M19-44 | EventLedger failure before sync commit | Sync waits/quarantines; no unlogged admission |
| M19-45 | Connector data exported | Scope/provenance/deletion metadata included; secrets excluded |
| M19-46 | AI unavailable | Read-only connector and source inspection remain usable |
| M19-47 | Accessibility connector UI | Scope, status, stale, revoke/delete controls exposed |
| M19-48 | Reduced motion/high contrast/dynamic size | No hidden status or clipped recovery control |

## 13. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M19-A | Connector identity/scopes | Typed account/root/grant lifecycle tests |
| M19-B | Calendar read-only | Authorization, scope, timezone, change-token, tombstone evidence |
| M19-C | Filesystem read-only | Bookmark, root containment, symlink, limit, cancellation evidence |
| M19-D | Credential boundary | Keychain-only token handling and redaction tests |
| M19-E | Cursor/idempotency | Atomic checkpoints, duplicate replay, crash recovery tests |
| M19-F | Backoff/offline truth | Retry-After/jitter, circuit/pause, stale status evidence |
| M19-G | Provenance/admission | Honeycomb source/version lineage and retrieval exclusion |
| M19-H | Prompt-injection isolation | Calendar/file content cannot change authority or invoke tools |
| M19-I | Revoke/disconnect/delete | Permission, token, pending work, index, cache, and tombstone cascade |
| M19-J | EventLedger | Ordered, minimal, redacted sync/consent/error evidence |
| M19-K | Accessibility/browser-first | Keyboard, VoiceOver, degraded connector-disabled browsing |
| M19-L | Truthful status | No verified connector claim without current fixtures and runtime evidence |

## 14. Implementation order and handoff

Implement M19-A before either connector. Implement Calendar and filesystem adapters separately behind the same lifecycle contract. Implement normalization/checkpoint/deletion before any recurring sync. Keep all connector content untrusted and read-only until M13 promotion and M10/M11 action contracts explicitly govern a later mutation.

The next smallest safe implementation slice is **M19-A: typed connector identity, scope, authorization, and sync-state schemas**, with fake Calendar/filesystem adapters for lifecycle tests. No model training or background process is part of M19.
