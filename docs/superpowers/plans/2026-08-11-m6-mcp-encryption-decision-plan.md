# Hive Memory Wedge M6 — Read-Only Local MCP and Encryption Decision

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Depends on:** M0 storage/migration/recovery, M1 explicit capture, M2 import/Brief credibility, M3 candidate-only WISP, M4 source versions/diffs/trails/hybrid retrieval, M5 digest/promises/forgetting/retention
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Primary specs:** `HONEYCOMB_SPEC.md`, `MEMORY_ARCHITECTURE_SPEC.md`, `MORNING_BRIEF_SPEC.md`, `WISP_CAPTURE_SPEC.md`, `ROUTING_SPEC.md`
> **Related plans:** `2026-08-11-m0-storage-migration-recovery-spec.md`, `2026-08-11-m1-explicit-capture-spec.md`, `2026-08-11-m5-digest-promises-forgetting-retention-plan.md`
>
> M6 is the boundary between Hive's private memory substrate and external local tools such as coding agents. It exposes a deliberately small, read-only, provenance-preserving query surface. It does not turn the browser into a general-purpose MCP host, expose arbitrary files, accept remote clients, or make encryption claims that have not been measured and documented.

## 0. Decision summary

M6 has two separate deliverables:

1. **Read-only local memory adapter:** an MCP-compatible server surface exposing a fixed allow-list of memory queries after explicit installation and connection consent.
2. **At-rest encryption ADR:** an evidence gate comparing plain SQLite + FileVault, SQLCipher, and an application/session-key design. M6 does not preselect SQLCipher or claim that FileVault protects a running unlocked process.

The default transport order is:

```text
stdio child process (first)
  → private Unix-domain socket (only if a persistent helper is justified)
    → loopback Streamable HTTP (last, only with Origin/Host validation)
```

A local client receives a capability-scoped identity, not an ambient browser session. The server can answer only approved read queries within the granted scope. It cannot write Honeycomb, EventLedger, WISP candidates, the M5 lifecycle store, files, credentials, browser tabs, or external services.

### M6 non-negotiables

- No runtime MCP code is implied by this document.
- No query may widen its own scope, request private content, bypass `MemoryRetrievalAdmission`, or return a candidate merely because it exists.
- No source text, URL path, credential-shaped value, private content, or raw database path enters a default diagnostic or authorization log.
- No token is accepted as proof of authority until its issuer, audience, version, expiry, scope, connection identity, and revocation state pass validation.
- No localhost HTTP listener binds to `0.0.0.0` or accepts arbitrary browser origins.
- `stdio` stdout is reserved for protocol messages; diagnostics go to stderr.
- A deleted or forgotten object must disappear from every exposed query and derived retrieval generation after the deletion contract says it is complete.
- A backup is not a secure-erasure claim. A database delete is not a claim that SSD remnants or existing user backups were destroyed.
- M6 remains optional: disabling it leaves browsing and the core memory UI usable.

## 1. Current code truth and reusable seams

The repository contains useful policy primitives but no MCP runtime. These facts are the implementation boundary:

| Existing surface | Current reusable behavior | M6 integration gap |
|---|---|---|
| `ContextScope` | Encodes profile/workspace/project/tab/page/private boundaries and admission checks | MCP requests need a server-side scope derived from consent, not caller-provided flags alone |
| `ContextScopeSummary` | Privacy-safe category/count display without IDs or content | Connection UI needs a similar summary plus client identity and expiry |
| `ContextRedactor` | Credential redaction, bounded text, sensitivity labels, instruction fencing | MCP response serialization must apply it before output, not only before model prompts |
| `MemoryRetrievalAdmission` / `MemoryAdmission` | Excludes private, candidate, unknown, pending, incomplete, forgotten, and out-of-scope records from model retrieval | Every MCP query adapter must call the same predicate before ranking and serialization |
| `SwarmResponseContextPolicy` | Redacts titles and URLs and blocks private/mismatched tab context | MCP must use an object-level source redaction policy, not just tab metadata helpers |
| `ResponseLifecycleToken` / `ContextTransitionToken` | Invalidates stale work after a newer request or browser-context transition | MCP request cancellation must be bound to connection and request identity |
| `KeychainSecretStore` | Stores generic secrets in macOS Keychain, accessible when unlocked | M6 needs a separate versioned connection-token authority and no plaintext config fallback |
| `KeychainHMACKeyStore` | Versioned Keychain-backed HMAC material and fail-closed provisioning | M6 can reuse the key versioning pattern; it is not itself a client identity registry |
| `RetentionCapability` | Signed, scoped, single-use retention authority | M6 read access must not reuse a destructive retention capability as a general bearer token |
| `EventLedgerStore` | Append-only, idempotent events and consent/revocation event kinds | M6 needs connection-issued/accepted/revoked/query-denied event taxonomy |
| `SyncCipher` | AES-GCM authenticated envelope for injected-key payloads | It is not a database encryption layer, key-custody policy, or SQLCipher substitute |
| Honeycomb/EventLedger | Separate SQLite authorities with FTS, provenance, deletion, and planned M0 four-store snapshots | M6 must query through stores and snapshot/recovery boundaries, never open database files directly |

**Absent:** MCP negotiation, JSON-RPC framing, stdio lifecycle, local HTTP/socket listener, connection registry, scope grants, tool schemas, resource URIs, response pagination, request cancellation, MCP integration tests, and encryption ADR evidence.

The authority order is: fresh source/tests → M0–M5 plans → this M6 plan → active packaged specs → historical mega-plan. A planned MCP adapter is not a verified external integration until clean-profile runtime evidence passes the M6 gates.

## 2. Threat model and trust boundaries

### 2.1 Untrusted inputs

Treat all of the following as untrusted:

- MCP client names, configuration paths, command arguments, environment variables, and declared capabilities.
- JSON-RPC method names, IDs, parameters, schema values, pagination cursors, and requested scopes.
- Web/page text, titles, URLs, imported content, messages, candidate evidence, screenshots, and model output stored in memory.
- Local client process behavior, even when it runs under the same macOS user.
- Loopback HTTP `Origin`, `Host`, `Referer`, forwarded headers, and DNS resolution.
- Existing token files, stale sockets, symlinks, and backup/restore artifacts.

### 2.2 Trust boundaries

```text
External local client
  │  stdio / private socket / loopback HTTP
  ▼
MCP transport + JSON-RPC validator
  │  authenticated connection identity + request scope
  ▼
MCP read-only policy adapter
  │  MemoryRetrievalAdmission + ContextScope + ContextRedactor
  ▼
Honeycomb / EventLedger / M4 retrieval / M5 lifecycle read adapters
  │  no direct database-file access
  ▼
Provenance-safe result serializer + minimal audit event
```

The transport is not the authority. A valid JSON-RPC message is not consent. A valid token is not permission to retrieve every object. A client-supplied `scope` is a request to evaluate, not an authorization grant.

### 2.3 Threats M6 must contain

| Threat | Required containment |
|---|---|
| Malicious local client enumerates memory | Explicit connection grant, allow-listed methods, object-level admission, bounded pagination, rate/volume limits |
| Stolen or copied token | Keychain-backed token metadata, short lifetime or explicit revocation, audience/issuer/version checks, rotation, no token in logs |
| Client asks for private/candidate/deleted data | Server-side admission before ranking and serialization; deny-on-unknown |
| Prompt injection in stored web text | Return content as attributed data with provenance; never interpret it as server instructions |
| Path traversal or database theft | No filesystem paths or arbitrary file/query arguments; adapters access stores through typed APIs |
| Stdio protocol corruption | stdout contains only valid MCP/JSON-RPC messages; diagnostics to stderr; malformed input gets a structured error |
| Loopback DNS rebinding / hostile website | Prefer stdio; if HTTP exists, bind loopback only and validate Origin/Host plus exact endpoint |
| Stale result after delete/context transition | Per-request lifecycle token and generation check immediately before serialization |
| Cross-store deletion lag | Query all dependent authorities/generations and return `deletion_pending` rather than stale success |
| Backup leaks | Backup classification, encryption decision, retention/deletion propagation, no raw file copy in WAL mode |
| Confused deputy through an agent | Client cannot use memory content to obtain broader capability; no memory output is executable authority |

## 3. Transport decision

### 3.1 Stdio is the first implementation target

The first M6 adapter is a child-process stdio server launched by an explicitly approved local client configuration. The server:

- reads newline-delimited JSON-RPC/MCP messages from stdin;
- writes only valid protocol messages to stdout;
- writes diagnostics to stderr, with secrets/content redacted;
- exits when stdin closes or the connection is revoked;
- does not become a persistent launchd daemon by default;
- receives a minimal sanitized environment and no inherited provider keys;
- uses an explicit application-owned data access path, not arbitrary client paths;
- runs as the invoking user and never elevates privileges.

The stdio command must be a Hive-owned, signed/verified executable path selected by Hive. M6 must not run package-manager commands, shell snippets, or arbitrary client-provided binaries as the server.

The server must reject or safely answer:

- malformed JSON;
- invalid JSON-RPC version or request shape;
- unknown methods;
- duplicate request IDs in one connection;
- oversized messages and parameter strings;
- invalid UTF-8 or invalid cursor encoding;
- unknown fields where strict decoding is required;
- requests after revocation or connection expiry;
- requests for methods outside the granted capability set.

### 3.2 Unix-domain socket is optional, not a free upgrade

A private Unix socket may be evaluated only if a persistent helper is required for an approved user journey. If implemented, it must:

- live under an application-owned, user-private runtime directory;
- create the directory with restrictive permissions and reject symlink substitution;
- create the socket with effective `0600` permissions and verify them after creation;
- bind the socket to the current user identity and connection generation;
- remove the socket on shutdown/revocation and recover stale sockets safely;
- never use a world-writable temporary directory as its authority boundary.

Socket access is defense in depth, not a replacement for connection identity and scope validation.

### 3.3 Loopback HTTP is last and must be hostile-origin safe

Loopback Streamable HTTP is not required for the first M6 slice. If product evidence later justifies it:

- bind only to `127.0.0.1` and/or `::1`, never `0.0.0.0`;
- choose a per-session port or authenticated endpoint, never rely on port secrecy;
- validate exact `Origin` and `Host` values; reject absent or unrecognized browser origins according to the selected transport contract;
- reject forwarded-host/proxy headers and unexpected schemes;
- apply the same token, scope, admission, pagination, cancellation, and audit rules as stdio;
- test DNS rebinding and hostile-webpage requests explicitly;
- disclose that any local process may attempt to connect to loopback and that auth remains mandatory.

M6 must not call a loopback listener “private” merely because it binds to localhost.

## 4. MCP protocol surface

### 4.1 Initialization and capability negotiation

The server must complete protocol initialization before serving memory queries. The handshake records:

```text
MCPConnection {
  connection_id: UUID
  client_name: bounded string
  client_version: bounded string?
  protocol_version: allow-listed version
  transport: stdio | unix_socket | loopback_http
  granted_scopes: sorted ScopeGrant[]
  granted_methods: sorted MethodID[]
  issued_at: Date
  expires_at: Date
  token_version: Int
  state: pending | active | expired | revoked | closed
}
```

The server must advertise only the fixed methods/resources actually enabled. It must not advertise a write-capable tool namespace and then rely on runtime denial as the primary safety mechanism.

Protocol-version mismatch is an honest incompatibility error, not a silent downgrade. Unknown optional protocol features may be ignored only where the selected MCP version permits it; unknown security-critical fields fail closed.

### 4.2 Fixed read-only query methods

M6 exposes these methods only:

#### `search_memory`

Purpose: retrieve approved, scoped memory objects through lexical/hybrid retrieval.

```json
{
  "query": "string, 1..500 chars",
  "scope": {
    "profile_id": "server-issued scope reference",
    "workspace_id": "server-issued scope reference",
    "project_id": "server-issued scope reference or null",
    "include_sources": true,
    "include_briefs": true,
    "include_tasks": true,
    "include_promises": true,
    "include_changed_sources": true
  },
  "as_of": "RFC3339 timestamp or null",
  "limit": "1..20",
  "cursor": "opaque cursor or null"
}
```

Rules:

- The caller cannot set `includesPrivateContent`, candidate admission, raw database paths, model/provider, or an unrestricted profile/workspace.
- The server intersects requested scope with the connection grant and active policy.
- Results are ranked only after `MemoryRetrievalAdmission` and deletion/retention filters.
- Results include bounded snippets, object type, stable opaque object ID, provenance label, source/version IDs where allowed, timestamps, and a `content_state`.
- The response states whether results are lexical-only, hybrid, incomplete, or deletion-filtered; it does not claim a retrieval generation that was unavailable.

#### `get_promises`

Purpose: retrieve confirmed tasks/promises and reviewable candidates that the connection grant explicitly includes.

```json
{
  "state": "confirmed | open | due | proposed_review",
  "from": "RFC3339 timestamp or null",
  "to": "RFC3339 timestamp or null",
  "limit": "1..50",
  "cursor": "opaque cursor or null"
}
```

Rules:

- `proposed_review` is opt-in and returns review-only state; it cannot be presented as a confirmed user commitment.
- Candidate evidence is returned only when the connection grant includes review proposals and the source passes admission.
- Due-date ambiguity, actor uncertainty, and user-edited fields remain visible.
- The method never confirms, edits, snoozes, promotes, or completes a promise.

#### `what_changed`

Purpose: retrieve reproducible retained-text diffs for a source or bounded query.

```json
{
  "source_id": "opaque source ID or null",
  "query": "string or null",
  "since": "RFC3339 timestamp",
  "until": "RFC3339 timestamp or null",
  "limit": "1..20",
  "cursor": "opaque cursor or null"
}
```

Rules:

- It uses M4 `SourceVersion` and `PageDiff` authorities only.
- It returns `changed`, `unchanged`, `insufficient_retained_text`, `deleted`, or `unavailable` explicitly.
- It never fetches a live URL, runs a browser action, invents a change from metadata, or asks a model to compare text.
- Deleted versions are not resurrected by a URL or title query.

#### `get_sources`

Purpose: retrieve source provenance and bounded retained evidence for approved source IDs.

```json
{
  "source_ids": ["opaque IDs, max 20"],
  "include_evidence": false,
  "limit": "1..20"
}
```

Rules:

- `include_evidence` requires an explicit connection grant because evidence may contain user-authored text.
- URLs use the same redaction policy as Swarm metadata; query strings, fragments, userinfo, and private paths are omitted unless a separate user-visible grant explicitly permits them.
- Evidence is bounded, attributed to source/version/span IDs, and fenced as untrusted data.
- The server returns `redacted`, `withheld`, or `deleted` state instead of silently substituting content.

### 4.3 Resources versus tools

M6 should expose query operations as read-only tools or resource reads according to the selected MCP version, but the safety contract is Hive-specific:

- A resource URI is an opaque, server-issued identifier, not a filesystem URI.
- No `file://`, arbitrary `sqlite://`, `http://`, or user-provided path URI is accepted.
- A memory result is data, not an instruction or permission.
- No write-capable tool is advertised in M6.
- Future write tools require a separate milestone, typed action envelope, approval UI, policy engine, and EventLedger contract; they are explicitly deferred here.

### 4.4 Response envelope

Every successful response includes a bounded metadata envelope:

```text
MemoryResponse {
  request_id: JSON-RPC ID
  connection_id: opaque ID
  scope_summary: privacy-safe categories only
  results: typed result array
  next_cursor: opaque cursor?
  retrieval_state: complete | lexical_only | unavailable | deletion_pending
  redaction_summary: category counts, never secret values
  generated_at: Date
  policy_revision: String
}
```

The envelope never contains the bearer token, raw scope IDs outside the granted opaque namespace, raw database paths, provider keys, hidden prompts, or unbounded diagnostics.

## 5. Scope, consent, and connection identity

### 5.1 Installation consent is separate from connection consent

M6 has two user-visible decisions:

1. **Install/enable:** allow Hive to expose a read-only local memory adapter to a named client, with transport, executable identity, data class, and revocation explanation.
2. **Connect/grant:** allow one specific client identity to receive one specific scope and method set until an explicit expiry or revocation.

Installing a server must not grant a client access automatically. A client reconnecting after revocation must require a new decision; a copied configuration must not silently restore prior access.

### 5.2 Grant model

```text
ScopeGrant {
  grant_id: UUID
  client_id: stable verified identity
  transport: stdio | unix_socket | loopback_http
  methods: fixed allow-list
  profile_id: optional server-bound ID
  workspace_id: optional server-bound ID
  project_id: optional server-bound ID
  include_sources: Bool
  include_evidence: Bool
  include_tasks: Bool
  include_promises: Bool
  include_proposals: Bool
  issued_at: Date
  expires_at: Date
  state: pending | active | expired | revoked
  consent_event_id: EventLedger ID
  token_version: Int
}
```

Rules:

- The least-privilege default is current selected project/workspace, `search_memory` + `get_sources` metadata, no private content, no evidence, no proposals, no write methods.
- A global/life scope is a separate explicit grant with a stronger warning and shorter default lifetime.
- Private browsing is never included by default and requires a future, separate product decision; M6 may reject it entirely.
- Scope grants are intersected with object provenance and current lifecycle state. Matching a workspace does not admit a project-tagged object when no project was granted.
- A client cannot request a broader scope by including a different scope object in a method call.

### 5.3 Token identity and storage

M6 has one authoritative grant-lifecycle store: `EventLedgerStore`. Installation consent, grant issuance, expiry, revocation, disconnect state, token generation, and policy revision are represented by an idempotent, versioned EventLedger consent/revocation event sequence; no second M6 connection database is introduced. Keychain stores only the opaque token material under the server-owned token ID and key version. Token material must not be stored in UserDefaults, MCP configuration JSON, logs, or EventLedger payloads. EventLedger is the authority for whether a token ID/grant is active; Keychain availability is a prerequisite for validating the token, not an alternate grant state.

The validator checks:

```text
TokenClaims {
  token_id: UUID
  issuer: "hive-mcp-connection-controller"
  audience: exact server identity
  client_id: stable identity
  grant_id: UUID
  key_version: positive Int
  issued_at: Date
  expires_at: Date
  nonce: unique value
}
```

- Token comparison is constant-time where applicable.
- Expired, revoked, wrong-audience, wrong-issuer, wrong-client, unknown-version, malformed, and grant-mismatch tokens fail closed.
- Token rotation creates a new token/grant generation and invalidates the old generation after a bounded overlap only if explicitly documented.
- A token is not a retention capability and cannot invoke destructive operations.
- If Keychain is unavailable or locked according to the selected access class, the adapter returns `authorization_unavailable` and does not fall back to plaintext.

### 5.4 Consent and revocation state machine

```text
not_installed
  → install_pending
  → installed_disabled | installed_no_grant
  → grant_pending
  → active
  → expired | revoked | disconnected
  → grant_pending (only after fresh user consent)
```

Required transitions:

- `install_pending → installed_no_grant`: installation accepted; no memory is released.
- `grant_pending → active`: user approved exact client, methods, scope, and expiry; EventLedger consent event commits.
- `active → revoked`: user or policy revokes; token generation is invalidated before the UI reports completion.
- `active → expired`: server denies new requests; pending requests finish only if policy permits, otherwise cancel and return `authorization_expired`.
- `active → disconnected`: client/stdin/socket closes; no grant is deleted merely because a process disconnected.
- Any failed ledger consent write: grant remains pending/blocked; no access is reported as active.

Revocation must stop new requests immediately, invalidate cached scope decisions, terminate stdio/socket sessions where possible, and make already-materialized results subject to the user-visible retention/deletion policy. Revocation cannot retroactively erase data already copied by a client; the UI must say so.

## 6. Query admission, redaction, and provenance

### 6.1 Admission order

Every request follows this order; no adapter may reorder it to rank first and filter later:

1. Parse and validate JSON-RPC/MCP envelope.
2. Validate connection state, token, method, request size, and rate limits.
3. Intersect requested scope with the active `ScopeGrant`.
4. Construct a server-owned `ContextScope`; ignore caller attempts to widen it.
5. Resolve object IDs through typed stores, not raw SQL or file paths.
6. Apply M0/M1/M3/M4/M5 lifecycle filters and `MemoryRetrievalAdmission`.
7. Apply source privacy and retention/deletion state.
8. Rank admitted results, using M4 hybrid retrieval or honest lexical fallback.
9. Redact bounded fields with `ContextRedactor` and source-specific URL/title policies.
10. Re-check lifecycle/context generation immediately before serialization.
11. Emit response and a minimal audit record.

If any required authority is unavailable, return a typed partial/unavailable state. Never treat an unavailable store as an empty memory result.

### 6.2 Result classes

Each item must carry a state that prevents external clients from mistaking absence for proof:

```text
content_state:
  available
  redacted
  withheld_private
  withheld_scope
  candidate_review_only
  audit_incomplete
  deleted
  deletion_pending
  unavailable
  stale_version
```

Default query methods omit objects that are not available and admissible. Detail requests may return a metadata-only withheld/deleted tombstone when that state is necessary to explain a user-visible result, but must not leak the deleted content or hidden identifiers.

### 6.3 Prompt-injection boundary

Memory content is returned as quoted, attributed data. The adapter adds an untrusted-data fence for evidence/snippets and explicitly states that source text cannot change client permissions, server policy, tool availability, or user intent. The MCP server never executes instructions found in memory and never forwards source text as an instruction to another local tool.

### 6.4 Audit minimization

Each accepted/denied query records only:

```text
MCPQueryAudit {
  event_id: stable idempotent query event
  connection_id: opaque ID
  client_id: stable non-secret ID
  grant_id: opaque ID
  method: fixed method ID
  scope_class: global | profile | workspace | project
  result_count: Int
  redaction_categories: [String]
  retrieval_state: enum
  decision: allowed | denied | unavailable | cancelled
  started_at: Date
  completed_at: Date?
  policy_revision: String
}
```

It does not record query text, snippets, URLs, credentials, evidence, full cursors, or bearer tokens by default. User-visible audit history may show method, client, scope class, count, and time; it must not become a shadow memory database.

## 7. Deletion, forgetting, and backup semantics

### 7.1 Deletion propagation

M6 is read-only but must respect deletion from M1–M5. A query cannot return an object just because a stale vector, FTS row, diff, digest item, or cursor still references it.

The deletion sequence is:

1. Source of authority marks the object deleted/forgotten under its typed scope.
2. M0/M5 journal records the operation and generation.
3. Dependent FTS, vector, diff, trail, digest, candidate, and cache indexes are invalidated or removed.
4. EventLedger records the eligible deletion/forget decision without copying deleted content.
5. Query adapters check the deletion generation before ranking and before serialization.
6. Only after all participants reconcile may the response state move from `deletion_pending` to absent/complete.

`Forget last 10 minutes`, source deletion, candidate dismissal, digest omission, connection revocation, and token deletion are distinct operations. MCP revocation does not delete memory. Memory deletion does not revoke every client grant unless the user selects that separate action.

### 7.2 Backup/restore

M6 uses the M0 four-store snapshot contract. The MCP adapter must:

- stop or invalidate reads while a store is `recovering`, `requires_reconciliation`, or `blocked`;
- never open a backup file directly as a query source;
- revalidate scope, deletion generations, token/grant state, and policy revision after restore;
- invalidate cursors across restore epochs;
- disclose if a restored snapshot predates a deletion or revocation event;
- invalidate all active M6 token generations after any restore epoch until fresh consent is recorded, even if the restored EventLedger projection says a grant was active;
- fail closed for uncertain object state rather than returning pre-delete content.

Backups are separate data copies with their own retention and encryption classification. M6 must define whether a user’s “delete” operation includes backup expiration, and must report what cannot be immediately erased from existing OS-managed backup systems.

## 8. Encryption ADR

### 8.1 Decision question

Which at-rest protection should Hive use for local memory stores and their backup artifacts while preserving trustworthy FTS, WAL/recovery, performance, migration, distribution, and deletion behavior?

The ADR must measure the actual macOS toolchain and SQLite build used by Hive. It must not rely on a different Linux SQLite, a mock, or a vendor marketing claim.

### 8.2 Candidates

| Option | Benefits | Costs/risks | Decision evidence required |
|---|---|---|---|
| Plain SQLite + FileVault | Zero new dependency; native SQLite/FTS; simplest migrations and debugging; OS-integrated protection at rest | Does not protect a running unlocked user session/process; database/WAL/temp content is readable to an authorized process; copied/unmounted backups need separate treatment; no app-level key boundary | Threat model for unlocked session, backup/export behavior, WAL/temp classification, measured startup/search, deletion wording |
| SQLCipher or equivalent page-level codec | Database pages, FTS, WAL/journal, and backups can remain ciphertext; transparent query model; protects copied files without active key | Dependency/build/distribution/licensing review; integration with macOS SQLite and Online Backup; key custody and unlock/lock policy; migration complexity; temp-store configuration; performance | License clearance, actual FTS/WAL/backup tests, key-unavailable behavior, migration/upgrade fixture, startup/query/space measurements, secure configuration review |
| Application-level/per-record encryption with Keychain/Touch ID session key | Fine-grained release/lock controls; can keep the database inaccessible while session key is unavailable; CryptoKit-based primitives avoid database fork | FTS over encrypted text is not native; likely requires decrypted indexes or custom search; complex cache/key zeroization; migration and backup logic; more plaintext exposure during indexing | Search design and latency, memory/key lifecycle, lock/unlock tests, crash/backup behavior, deletion semantics, implementation and maintenance cost |

**Important qualification:** `SyncCipher` is an authenticated envelope for payloads and is not evidence that a SQLite database, WAL, FTS index, temporary file, or backup is encrypted. `KeychainSecretStore` protects stored secrets; it does not encrypt arbitrary database pages.

### 8.3 Required measurements

The ADR must produce a reproducible report with:

1. **Search:** FTS correctness and p50/p95 latency over representative 10k/50k/100k-object fixtures; lexical fallback behavior; index size.
2. **Writes:** capture, digest, purge, and concurrent-reader latency under WAL; checkpoint behavior; busy/lock failure handling.
3. **Startup/unlock:** cold open, key retrieval, schema migration, quick check, and first query on supported M1/M2-class hardware; locked/Keychain-unavailable behavior.
4. **Backups:** Online Backup API and restore for all M0 participants; interruption, WAL, integrity, manifest, and deletion-generation tests.
5. **Migration:** plain→encrypted if applicable, version upgrade, wrong-key, corrupt-key, interrupted migration, rollback, and future-version behavior.
6. **Leakage:** main DB, WAL, SHM, temp files, exports, crash artifacts, logs, and diagnostics; no claim may exceed observed evidence.
7. **Lifecycle:** session lock, app quit, crash, force kill, sleep/wake, and revoked connection while a query is active.
8. **Distribution:** dependency licensing, notarization/signing implications, binary size, update/migration burden, and supported macOS versions.

### 8.4 Key custody rules

Regardless of the selected option:

- Keys are generated/stored through a versioned Keychain authority; no plaintext key in config, UserDefaults, logs, source, tests, or MCP tokens.
- A Keychain failure is a typed unavailable state, not permission to open an unencrypted fallback database.
- Touch ID/LocalAuthentication is a user-experience gate, not a cryptographic guarantee by itself. The ADR must specify what is protected by Keychain access class, what remains in process memory, and what happens when the session locks.
- Key rotation must preserve or explicitly invalidate old snapshots and pending recovery records; it must never silently discard the only decryptable copy.
- Secure deletion language must distinguish logical deletion, cryptographic erasure, backup expiry, APFS/SSD behavior, and client copies.

### 8.5 ADR outcome states

```text
not_measured
  → measured_inconclusive
  → option_selected
  → implementation_ready
  → verified_in_production_configuration
```

The M6 exit gate requires `option_selected` with evidence and an explicit list of claims Hive is not making. It does not require shipping the selected encryption implementation in the same slice. If no option clears the dependency/licensing/performance gates, retain the current posture honestly as `plain SQLite + FileVault, limitations disclosed` and create a follow-up gate; never label it app-encrypted.

## 9. Implementation work packages after approval

### M6-A — Connection authority and consent

- Define the versioned connection/grant event schema with `EventLedgerStore` as the sole lifecycle authority; do not create a fifth M0 database.
- Store only token material in Keychain, referenced by a stable token ID and key version; reuse Keychain/HMAC versioning without conflating connection tokens with retention capabilities.
- Add install, grant, expire, revoke, disconnect, and rotate state transitions with idempotent event IDs and a deterministic active-state projection.
- Emit minimal consent/revocation/query audit events through EventLedger; token values never enter events.
- Add a user-facing permission surface showing client, transport, methods, scope class, expiry, last use, and revoke action.
- Define restart/restore behavior: EventLedger restore replays the grant projection, but a restore epoch invalidates all active token generations until the user reconsents; Keychain token material is never restored from an application database backup.

### M6-B — Stdio protocol adapter

- Implement strict JSON-RPC/MCP framing and initialization.
- Validate message size, IDs, schemas, cancellation, and unknown methods.
- Ensure stdout cleanliness and stderr redaction.
- Launch only an approved Hive-owned executable with sanitized environment and no arbitrary command execution.
- Add lifecycle handling for EOF, crash, restart, revocation, and token expiry.

### M6-C — Read-only query adapter

- Implement the four fixed methods with typed request/response schemas.
- Route all reads through Honeycomb/EventLedger/M4/M5 adapters and shared admission.
- Add bounded pagination/cursors tied to storage epoch, grant, policy revision, and deletion generation.
- Apply redaction, provenance, evidence fencing, and final stale-generation checks.
- Return honest unavailable/deletion-pending/lexical-only states.

### M6-D — Optional private socket/loopback evaluation

- Do not implement until stdio passes.
- Measure whether a persistent helper solves a real user journey that stdio cannot.
- If selected, add private socket permissions or loopback Origin/Host defenses and threat fixtures.
- Keep the transport behind the same connection authority; transport choice cannot widen scope.

### M6-E — Encryption and backup ADR

- Build the benchmark fixture and measurement harness without storing user data.
- Run the plain SQLite + FileVault baseline first.
- Evaluate SQLCipher/equivalent only after licensing and dependency approval; evaluate application-level encryption only with a credible FTS design.
- Test M0 four-store Online Backup API, restore, deletion generations, Keychain lock/unavailability, and crash paths.
- Publish the ADR with selected option, rejected alternatives, measured results, and unsupported claims.

## 10. Acceptance and security test matrix

M6 is not complete with a handshake demo. Tests must be deterministic and use synthetic fixtures with no secrets or real browsing history.

| ID | Fixture | Required assertion |
|---|---|---|
| M6-1 | Valid initialization | Only enabled read methods/resources are advertised; no write capability appears |
| M6-2 | Malformed JSON/JSON-RPC | Structured protocol error; stdout remains valid protocol; diagnostics go to redacted stderr |
| M6-3 | Oversized/unknown request | Rejected before store access; bounded error; no crash |
| M6-4 | Wrong protocol version | Explicit incompatibility; no silent downgrade |
| M6-5 | No consent/grant | Authorization denied; no query reaches Honeycomb/EventLedger |
| M6-6 | Expired/revoked token | Denied immediately; cached scope cannot be reused |
| M6-7 | Wrong issuer/audience/client/grant/key version | Denied; no token or claim value enters logs |
| M6-8 | Caller widens profile/workspace/project/private flags | Server-owned scope intersection rejects the widened request |
| M6-9 | Private/kill-list/unknown-policy object | Omitted or withheld; never returned as available |
| M6-10 | Candidate/pending/incomplete/audit-unknown object | Excluded by shared admission across every query method |
| M6-11 | Prompt injection in source evidence | Returned only as attributed untrusted data; no permission/tool change |
| M6-12 | Path/URI traversal | No arbitrary file/database/network path is opened |
| M6-13 | Deleted source with stale FTS/vector/diff/cursor | Deleted or deletion-pending state; no stale content |
| M6-14 | Restore changes storage epoch | Old cursors rejected; queries re-evaluate admission and deletion generations |
| M6-15 | Query cancelled/context transition | No stale response serialized after cancellation or context generation change |
| M6-16 | Store unavailable/corrupt/recovering | Typed unavailable state; never an empty-success result |
| M6-17 | Stdio EOF/crash/restart | Connection closes safely; reauthorization follows grant policy |
| M6-18 | Unix socket, if implemented | Private directory, `0600`, no symlink substitution, stale socket recovery |
| M6-19 | Loopback hostile origin, if implemented | Non-loopback bind fails; hostile/missing Origin or Host is rejected |
| M6-20 | Token rotation | Old generation behavior matches documented overlap; new generation works |
| M6-21 | Consent ledger failure | Grant remains pending/blocked; UI never reports active access |
| M6-22 | Backup/restore includes M6 grant authority | EventLedger snapshot includes the versioned grant/consent/revocation event schema and revision; Keychain token material is explicitly excluded; restore invalidates all active token generations until fresh consent |
| M6-23 | Plain SQLite baseline | FTS/WAL/backup/deletion measurements are recorded with limitations |
| M6-24 | Encryption candidate wrong key/corrupt key | Fail closed; no plaintext fallback; recovery state is explicit |
| M6-25 | Query audit minimization | Audit contains method/scope/count/state only; no query text, evidence, URL, token, or secret |

The fixture matrix contains **25 cases**. New cases must update this plan and the progress entry.

## 11. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M6-A | Installation and connection consent are separate, explicit, scoped, revocable, and auditable | permission-flow tests + clean-profile manual path |
| M6-B | Token identity is versioned, audience-bound, Keychain-backed, expirable, rotatable, and fail-closed | token/Keychain tests |
| M6-C | Stdio framing is strict and stdout contains no diagnostics | protocol harness + malformed-input fixtures |
| M6-D | Only four fixed read methods are exposed with typed schemas and bounded output | schema/conformance tests |
| M6-E | Shared scope/admission/redaction policy is enforced before retrieval and again before serialization | cross-method privacy/admission tests |
| M6-F | Private, candidate, unknown, audit-incomplete, deleted, and unavailable states never become false successful results | adversarial lifecycle fixtures |
| M6-G | Cancellation, context transitions, storage epochs, and revocation prevent stale output | lifecycle/concurrency tests |
| M6-H | Every query is minimally auditable without creating a shadow content store | ledger/redaction tests |
| M6-I | M0 four-store backup/restore and M5 deletion generations are respected | restore/deletion integration fixtures |
| M6-J | Optional socket/loopback transport, if selected, passes its distinct permission/origin threat tests | transport-specific tests |
| M6-K | Encryption ADR measures all required candidates and states selected/rejected options plus unsupported claims | reproducible ADR artifact |
| M6-L | Browser remains usable with MCP disabled, revoked, unavailable, or encryption undecided | clean-profile browser runtime path |

M6 is **verified** only when all 12 gates pass with fresh build/test evidence, a clean-profile permission/revocation path, restore invalidation of active grants, and an ADR based on the actual supported macOS configuration. A protocol stub, mock response, or source-only conformance claim is `scaffold` or `code-present`, not `verified`.

## 12. Implementation order and stop conditions

After M0–M5 exit gates are genuinely evidenced:

1. Freeze the M6 synthetic fixture corpus and connection/grant schema.
2. Implement/verify connection consent and token authority before starting any transport.
3. Implement stdio framing and initialization with no memory query path.
4. Add one read method (`search_memory`) through the full admission/redaction/audit path.
5. Add the remaining three methods and shared pagination/cancellation/deletion-generation behavior.
6. Run the complete M6-1…M6-17 matrix before considering socket/HTTP.
7. Decide whether persistent socket/loopback transport solves a measured need; otherwise defer it.
8. Run the encryption baseline and candidate ADR against the M0 backup/restore fixture.
9. Run clean-profile browser, revoke, restart, restore, and deletion paths.
10. Record exact evidence and unsupported claims in the canonical progress log.

Stop immediately and do not widen scope if:

- any query can reach a store without a server-owned grant;
- the adapter opens a database path supplied by a client;
- private/candidate/deleted content can pass through ranking before filtering;
- a stale cursor can return post-delete content;
- revocation depends on client cooperation;
- Keychain failure causes plaintext fallback;
- loopback transport is added without a real user journey and origin tests;
- an encryption option is described as selected without reproducible measurements.

## 13. Explicitly deferred

- Any MCP write tool, action tool, browser-control tool, shell/file tool, or connector mutation.
- Remote MCP, OAuth server, multi-user identity, team sharing, or network exposure.
- Private-content MCP access.
- Arbitrary resource URIs, file browsing, raw Honeycomb SQL, or database-file downloads.
- Persistent launchd helper before stdio evidence and a measured need.
- SQLCipher integration before the ADR clears licensing, distribution, migration, and performance gates.
- Per-record encryption without a credible FTS/search and cache-key design.
- Client-side memory caching outside the server's retention/deletion contract.

## 14. Evidence references

Protocol and security:

- [MCP transports](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports)
- [MCP security best practices](https://modelcontextprotocol.io/specification/draft/basic/security_best_practices)
- [MCP authorization tutorial](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/authorization)
- [JSON-RPC 2.0 specification](https://www.jsonrpc.org/specification)

macOS security and secrets:

- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Apple LocalAuthentication](https://developer.apple.com/documentation/localauthentication)
- [Apple App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Apple File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/WhereToPutFiles/WhereToPutFiles.html)

SQLite and encryption:

- [SQLite Online Backup API](https://www.sqlite.org/backup.html)
- [SQLite WAL](https://www.sqlite.org/wal.html)
- [SQLite VACUUM and VACUUM INTO](https://www.sqlite.org/lang_vacuum.html)
- [SQLite secure deletion](https://www.sqlite.org/pragma.html#pragma_secure_delete)
- [SQLCipher design](https://www.zetetic.net/sqlcipher/design/)
- [SQLCipher API](https://www.zetetic.net/sqlcipher/sqlcipher-api/)

These sources establish platform/protocol behavior. The scope grants, four read methods, lifecycle states, audit minimization, deletion generations, M6 fixture matrix, and encryption selection criteria are Hive-specific proposed contracts and require implementation evidence before capability labels change.
