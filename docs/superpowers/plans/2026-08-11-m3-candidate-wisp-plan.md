# Hive M3 — Candidate-Only WISP Capture Implementation Plan

> **For agentic workers:** This is an execution plan, not an implementation. Use the approved execution workflow only after M0, M1, and M2 exit gates have fresh evidence. Do not edit Swift, JavaScript probes, or model files during this planning pass.

**Goal:** Test whether quiet browser-native memory is useful while ensuring automatic capture creates only bounded, local, reviewable candidates and can never silently become durable memory, model context, or user authority.

**Architecture:** M3 uses a dedicated candidate SQLite store at `Application Support/Hive/wisp-candidates.sqlite3`, separate from Honeycomb's durable node/edge graph, FTS, Markdown export, and M1 capture-attempt authority. The candidate store is nevertheless a first-class M0-managed storage participant: its writes, snapshot/restore, health state, quarantine, and recovery-journal records are coordinated through the same `StorageEpochCoordinator` and triple-snapshot manifest; it is never an untracked third database. A deterministic DOM probe emits only URL/title and numeric interaction signals. Native policy validates every event before storage. Candidates may appear in a user-visible candidate surface and a candidate-scoped HotMemory working set, but candidate data is excluded from Swarm context by the shared admission boundary. Explicit Save/Approve invokes a typed promotion API that creates or reuses a durable Honeycomb `.source` through M1's attempt-level audit contract, then deletes the candidate.

**Tech Stack:** Swift 6 actors; system SQLite3; existing CEF console bridge; pure HiveCore admission/policy types; SwiftUI candidate toast/panel; Swift Testing fixtures. No screenshots, OCR, page-body extraction, model call, network call, or third-party dependency.

## Global Constraints

- M3 is **candidate-only**. Automatic capture never inserts a Honeycomb node, edge, durable memory, task, claim, or brief.
- The exact candidate store is `Application Support/Hive/wisp-candidates.sqlite3`; it is not Honeycomb and not the session envelope.
- Candidate storage is schema version 1, actor-isolated, bounded, locally deletable, and subject to M0 storage-health/recovery rules before activation.
- Private browsing is an absolute no-probe/no-candidate path. No private URL, title, target, or derived signal may be persisted or placed in a durable ledger payload.
- The probe captures no screenshots, pixels, DOM subtree, body text, form values, cookies, credentials, page content, or model instructions.
- The native side treats all probe values as untrusted data. A page cannot grant permission, widen scope, trigger promotion, or cause a tool action.
- Candidate data never enters default Swarm context. Candidate visibility in a UI is not context consent.
- Promotion requires an explicit user action and must reuse M1's `MemoryRetrievalAdmission`/capture-attempt semantics; it may not directly flip `.candidate` to `.durable` in HotMemory.
- Candidate-level discarded events are aggregate diagnostics only; do not persist raw URLs, titles, page text, or rejection payloads in EventLedger.
- M3 does not add promise detection, daily digest consolidation, vectors, page diffs, screenshots, VLMs, remote services, or model-generated classification.

## Canonical Decision: Dedicated Candidate Store

The older WISP specification left two alternatives open: a Honeycomb `.wisp` node type or a dedicated candidate table. M3 chooses the dedicated store and rejects the `.wisp` graph-node alternative for this milestone.

### Why this boundary is required

1. A candidate is not durable knowledge and must not appear in Honeycomb's durable graph, FTS, Markdown export, graph counts, or durable-node deletion semantics.
2. A dedicated store makes the default-deny model-context rule structural rather than dependent on every Honeycomb query remembering a special node type.
3. Candidate retention, nuke, cap, quarantine, and corruption recovery can evolve independently without expanding the canonical Honeycomb node enum before the retention contract is proven.
4. Promotion has a clear seam: candidate snapshot → explicit user confirmation → M1 durable source/attempt/event path.
5. Candidate volume can be bounded and swept without confusing visit history, durable sources, or graph provenance.

The candidate store is a separate **candidate authority**, not a second durable memory authority. Honeycomb remains the only durable knowledge authority. EventLedger remains the authority for consequential promotion, deletion, and consent evidence.

## Current Audited Truth

- `MemoryAdmissionPolicy.modelExtraction(isPrivate:)` returns `.candidate` for non-private input and `nil` for private input.
- `MemoryAdmissionPolicy.userAuthoredCapture(isPrivate:)` permits `.durable` only for non-private explicit capture.
- `PageCaptureAdmission.evaluate(isPrivate:)` rejects private capture.
- `PageCaptureDeliveryPolicy` already distinguishes manual capture from auto capture and denies auto persistence when AI context is not allowed; M3 must not bypass this policy family.
- `HotMemoryStore.HotEntry` already carries `admission: MemoryAdmission`, private/scope fields, and candidate-vs-durable semantics, but candidate ingress and promotion are not yet wired.
- Existing probes (`mediaStateProbeScript`, `linkPeekProbeScript`, `autofillProbeScript`) establish the self-guarding IIFE, console-bridge, delimiter escaping, and event-driven timer conventions.
- `HoneycombStore.NodeType` has no `.wisp` type. M3 must not add one.
- Existing `SwarmMemoryAdmissionTests` prove candidate memory can exist without a durable Honeycomb node and private model extraction creates no candidate; M3 extends this behavior to the browser probe.
- Existing `captureCurrentPage()` is the durable M1 path, but current code is not yet M1-verified. M3 promotion must target the planned typed promotion contract, not assume current source presence is sufficient.

## Data Contracts

### `WispKind`

Exactly these values are allowed:

```text
settled | tabswitch | reader | linkout
```

M3 rollout starts with `settled`; other kinds remain disabled until their individual fixtures pass.

### `WispCandidate`

The candidate store schema and Swift value are version 1:

```text
WispCandidate {
  candidateID: UUID
  schemaVersion: 1
  contentHash: String
  observedURL: URL
  canonicalURL: URL
  host: String
  observedTitle: String
  kind: WispKind
  scrollDepthPercent: Int?       // 0...100, settled/tabswitch/reader
  dwellSeconds: Int              // 0...86_400, bounded
  targetURL: URL?                // linkout only; http/https after validation
  capturedAt: Date
  expiresAt: Date                // capturedAt + 7 days
  profileID: String
  workspaceID: String
  sourceTabID: String
  status: pending | visible | promoting | dismissed | promoted | expired | deleted | quarantined
}
```

Storage rules:

- `observedURL` preserves the URL reported by the committed tab after strict HTTP(S)/userinfo validation; `canonicalURL` is the versioned deduplication form produced by the approved URL canonicalizer. Both are retained because M1 provenance distinguishes what was observed from what was used for identity. Fragments, tracking parameters, and other normalization changes are removed only according to that versioned policy; M3 must not invent silent stripping rules.
- `host`, `observedTitle`, and optional target are bounded before insertion. Titles are trimmed and capped at 512 Unicode scalars; hosts are parser-derived, never accepted as authority from a free-form payload.
- `contentHash` is SHA-256 of the versioned canonical candidate identity: `wisp.v1\n<canonical-url>\n<observed-title>\n<kind>`. Numeric signal changes do not mint unlimited duplicates; the interval policy below replaces the shallower candidate.
- `profileID`, `workspaceID`, and `sourceTabID` are native-owned scope values. A missing scope rejects the candidate; it never becomes global by default. The candidate store's snapshot/recovery scope is the same profile/workspace authority, not a second global store.
- Candidate rows contain no body text, DOM, screenshot bytes, cookies, credentials, form values, raw model output, or page-provided instructions.
- Candidate rows are not exported through Honeycomb Markdown export. Candidate export, if enabled in M3, is a separate explicit JSON export containing only bounded URL/title/kind/time metadata and is never a model-context import.

### Exact SQLite store

Path: `Application Support/Hive/wisp-candidates.sqlite3`.

Schema version: `1`.

Required schema:

```sql
CREATE TABLE wisp_candidates (
  candidate_id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL CHECK (schema_version = 1),
  content_hash TEXT NOT NULL,
  observed_url TEXT NOT NULL,
  canonical_url TEXT NOT NULL,
  host TEXT NOT NULL,
  observed_title TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('settled','tabswitch','reader','linkout')),
  scroll_depth_percent INTEGER,
  dwell_seconds INTEGER NOT NULL,
  target_url TEXT,
  captured_at REAL NOT NULL,
  expires_at REAL NOT NULL,
  profile_id TEXT NOT NULL,
  workspace_id TEXT NOT NULL,
  source_tab_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending','visible','promoting','dismissed','promoted','expired','deleted','quarantined')),
  promotion_node_id TEXT,
  promotion_attempt_id TEXT,
  promotion_lease_id TEXT,
  promotion_lease_owner TEXT,
  promotion_lease_expires_at REAL,
  created_at REAL NOT NULL,
  CHECK (
    (status = 'promoting' AND promotion_lease_id IS NOT NULL AND promotion_lease_owner IS NOT NULL AND promotion_lease_expires_at IS NOT NULL)
    OR
    (status <> 'promoting' AND promotion_lease_id IS NULL AND promotion_lease_owner IS NULL AND promotion_lease_expires_at IS NULL)
  ),
  updated_at REAL NOT NULL,
  UNIQUE(profile_id, workspace_id, content_hash)
);

CREATE INDEX wisp_candidates_scope_time
  ON wisp_candidates(profile_id, workspace_id, captured_at DESC);
CREATE INDEX wisp_candidates_expiry
  ON wisp_candidates(expires_at);
CREATE INDEX wisp_candidates_status
  ON wisp_candidates(status);
```

The implementation must use parameterized SQL only. Candidate store startup uses the M0 storage vocabulary (`healthy`, `recovering`, `degradedEphemeral`, `blocked`), verifies foreign keys/journal mode/schema version, and never replaces a corrupt database with a new empty one. The store registers with M0's `StorageEpochCoordinator`; its writes are admitted through the shared gate, its recovery-journal records are included in the M0 reconciliation matrix, and its snapshot is included in the M0 triple snapshot manifest. A candidate-only snapshot that cannot be included in the M0 triple is marked `requires_reconciliation` and is not an automatic restore source. If the store is unavailable, the browser continues and the probe is disabled; no candidate-success UI appears.

The store actor exposes these typed operations:

```text
open() -> StorageHealth
insertOrReplace(candidate) -> CandidateWriteResult
listVisible(scope, limit) -> [WispCandidate]
markDismissed(candidateID, reason) -> Void
beginPromotion(candidateID, owner, now, leaseDuration) -> PromotionLease
renewPromotion(leaseID, owner, now) -> PromotionLease
completePromotion(leaseID, owner, nodeID, attemptID) -> Void
markPromotionFailed(leaseID, owner, reason) -> Void
expire(now) -> ExpiryReport
nuke(window, scope) -> CandidateDeletionReport
delete(candidateID, reason) -> Void
reconcileAfterRestart() -> CandidateRecoveryReport
```

`beginPromotion` is one atomic `BEGIN IMMEDIATE` transition from `pending|visible` to `promoting`, the explicit leased promotion state. Legal transitions are `pending → visible → promoting → promoted|visible|quarantined`, plus `visible → dismissed|expired|deleted`; `promoting` cannot be dismissed, expired, or evicted until its lease is released or reconciled. The schema invariant requires a `promoting` row to have a non-null lease ID, native owner, and expiry, and requires every other status to clear all three lease fields. Lease acquisition, renewal, expiry reclamation, completion, and failure are each one transaction; no partially updated lease is observable. The lease is durable in the candidate row (`promotion_lease_id`, native owner token, expiry), single-use, scope-bound, and never derived from model output. A caller without the matching unexpired lease cannot complete or fail promotion. Lease expiry is recovered deterministically on restart: an uncommitted lease returns to `visible` if the candidate is still valid; a lease with a durable promotion linkage is reconciled against M1 before retry. Two concurrent Save actions therefore produce at most one M1 attempt lineage. `completePromotion` and candidate deletion are not assumed to be one transaction with Honeycomb/EventLedger; the recovery journal and M0 reconciliation record the cross-store boundary.

A candidate store write is never treated as Honeycomb durability and never grants model admission. It is a first-class M0 storage participant: every mutating operation obtains a `StorageEpochCoordinator` write permit, every triple snapshot includes it and its schema version, and corruption is quarantined rather than replaced by an empty database.

## Probe Contract

### Probe installation

The probe is injected only after a committed load for a normal-profile HTTP(S) page, using the existing CEF console bridge and self-guarding IIFE convention:

```js
(function(){
  if (window.__hiveWispProbeInstalled) return;
  window.__hiveWispProbeInstalled = true;
  // event-driven settled probe only in M3 Stage 1
})();
```

Native code must check immediately before injection:

- tab is non-private;
- URL is HTTP(S);
- browser memory/candidate capture preference is enabled;
- `WispCapturePrivacyPolicy` returns `allow` (not unknown/deny) for the native host, profile, private state, and metadata-only password-form signal;
- host is not on the policy's absolute kill list;
- host is not in the policy's user site opt-out set;
- no active password-form signal is present;
- candidate store health is `healthy` or an explicitly supported non-durable candidate mode;
- tab/profile/workspace scope is available.

If any check fails, do not inject. A page cannot re-enable the probe by calling a bridge method.

### M3 Stage 1 message

Only `settled` ships first:

```text
HIVE_WISP|settled|<encoded-url>|<encoded-title>|<depth-percent>|<dwell-seconds>
```

Rules:

- URL and title use `encodeURIComponent` before delimiter composition.
- The probe reads location, title, scroll position, and elapsed time only.
- It emits once per page visit after at least 4 seconds of dwell and at least 600ms without a scroll event.
- Scroll depth is clamped to 0...100.
- Dwell is clamped to 0...86,400 seconds.
- No interval polling, DOM subtree extraction, body text, screenshots, or form values.
- A page event is a proposal, not permission and not a promotion request.

### Deferred message classes

`tabswitch`, `reader`, and `linkout` are not enabled in Stage 1. Each requires its own deterministic fixture and review because each adds lifecycle or destination semantics. No promise classifier or page-body reader runs as part of M3.

## Native Validation Contract

Every console message is parsed as hostile input and passes a pure validator before any store or HotMemory side effect.

### Canonical privacy detector and deny-on-unknown rule

All M3 privacy decisions come from one browser-owned metadata-only policy: `WispCapturePrivacyPolicy`. It reads native tab URL/host, profile/private state, the user's site opt-out set, the absolute sensitive-host kill list, and the boolean password-form presence signal already exposed by the browser's autofill/password boundary. It never reads form values, field text, cookies, credentials, page body, or DOM content beyond that boolean metadata signal. The probe and candidate UI do not maintain copies of this policy.

The policy has three outcomes: `allow`, `deny(reason)`, and `unknown(reason)`. Both `deny` and `unknown` prevent probe injection and reject an already-delivered message. Unavailable host classification, private-state ambiguity, missing profile policy, stale password-detector state, or scope uncertainty is therefore fail-closed. A page cannot call a bridge method to override the result. The policy's decision and version are typed diagnostics only; raw URL/title data is not logged.

Every probe injection and every message admission must use this policy, and the privacy fixture suite must prove that no unknown state reaches the candidate store.

Every console message is parsed as hostile input and passes a pure validator before any store or HotMemory side effect:

```text
WispAdmission.evaluate(
  message,
  tabContext,
  hostPolicy,
  scope,
  candidateStoreHealth,
  now
) -> accepted(WispCandidateDraft) | rejected(WispRejectionReason)
```

Required rejection reasons:

```text
malformedMessage
unsupportedKind
privateBrowsing
nonHTTPURL
invalidTargetURL
emptyOrOversizedTitle
invalidNumericSignal
killListHost
siteOptOut
passwordFormPresent
missingScope
storeUnavailable
stalePageVisit
rateLimited
piiShape
```

Validation order is fixed:

1. Parse exact message grammar and field count.
2. Decode URL/title fields with strict length limits.
3. Resolve the native tab identity and compare the observed URL with the active committed page; stale callbacks are rejected.
4. Apply private/profile/workspace/scope policy.
5. Apply HTTP(S), host kill-list, site opt-out, password-form, and PII-shape gates.
6. Clamp/validate numeric values.
7. Compute canonical candidate identity/content hash.
8. Apply rate and interval policy.
9. Produce a candidate draft; only the candidate-store actor may persist it.

Discard counters are aggregate-only and typed by rejection reason. They must never contain raw URL/title values, and they must not become EventLedger rows containing page data.

## Candidate Deduplication and Rate Policy

- Candidate uniqueness is `(profileID, workspaceID, contentHash)`.
- A repeated identical settled event is a no-op.
- A later event for the same URL within 15 minutes may replace the earlier candidate only when its signal is strictly stronger under this deterministic order: `reader > settled`; deeper scroll wins within the same kind; later dwell wins when depth ties.
- The candidate store has a hard total bound per profile: at most 400 active (`pending|visible|promoting`) rows, 200 retained lifecycle/tombstone rows, and 600 total rows or 8 MiB of candidate-store payload, whichever is reached first. Expired/dismissed/deleted/promoted tombstones are swept after their stated reconciliation window; if the total bound is reached, eligible tombstones are removed first, then the oldest lowest-priority active candidate. Promoting and quarantined rows are never evicted silently. If non-evictable rows exhaust the total bound, insertion fails closed with `storeCapacityBlocked`, probe admission stops, and the UI reports cleanup/recovery required; the implementation must not delete a quarantined row or silently exceed the bound. A bound breach is a visible cleanup-degraded state, not an unbounded write.
- Native validation is bounded and synchronous/pure except for one candidate-store admission check; it must not invoke a model or fetch a URL.
- Candidate insertion must not touch `historyItems`, browser session persistence, Honeycomb, or EventLedger.

## HotMemory and Context Boundary

Candidate HotMemory entries may be used to render the candidate surface only. They must be inserted with:

```text
admission: .candidate
sourceHint: "wisp"
isPrivate: false
profileID: native current profile
workspaceID: native current workspace
```

A shared predicate is required and must be the only candidate admission seam:

```text
WispContextAdmission.evaluate(
  candidate,
  contextScope,
  userIntent
) -> denied(.candidateNotDurable | .private | .outOfScope | .forgotten) | allowedForCandidateUI
```

`WispContextAdmission` is called by the concrete `HotMemoryStore.assembleContext`/candidate-listing boundary, `PageContextBroker` assembly, retrieval-ranker input construction, `ProactiveBriefPlanner` memory-card construction, Honeycomb model-retrieval adapters, and candidate export adapters. Those callers may not filter candidates by convention or raw enum checks. The predicate must first delegate durable-source checks to M1's `MemoryRetrievalAdmission.evaluate` with the selected eligible complete capture attempt; candidates have no eligible complete attempt and therefore receive only the `allowedForCandidateUI` branch. Negative tests must pass a candidate ID through each concrete caller and prove zero model-context, Brief, ranker, Honeycomb-retrieval, or export admission. There is deliberately no `allowedForModelContext` result in M3. A candidate may be displayed in the dedicated candidate UI without becoming model-visible.

HotMemory candidate entries must be removed when the candidate is dismissed, expired, nuked, promoted, scope-revoked, or the candidate store becomes unavailable. A failed promotion never upgrades the entry's admission.

## Promotion Contract

Promotion is a typed, explicit action:

```text
PromoteWispRequest {
  candidateID: UUID
  userConfirmation: explicit
  requestedScope: ContextScope
}
```

The promotion controller must:

1. Resolve the candidate from the candidate store and acquire a one-shot promotion lease.
2. Revalidate expiry, scope, private state, source-tab identity, and candidate status.
3. Call the trusted user-authored/promotion admission path; model output cannot call this API.
4. Create or reuse a Honeycomb `.source` using the candidate's bounded URL/title metadata and the M1 metadata/provenance contract. No automatic body extraction occurs.
5. Create the M1 `HoneycombStore.CaptureAttempt` with `attemptID`, stable `capture/<attemptID>/v1` event ID, scope, and `pending` status.
6. Record the admitted non-private durable `.capture` EventLedger event with the actual stored/reused node ID through `recordIfAbsent`.
7. Mark the capture attempt complete only after the ledger event succeeds. If Honeycomb succeeds and ledger fails, retain the source as audit-incomplete and exclude it through M1 `MemoryRetrievalAdmission`; do not delete it silently.
8. Only after durable promotion/reconciliation succeeds, mark the candidate `promoted`, store `promotion_node_id`/`promotion_attempt_id`, delete its candidate HotMemory entry, and bump the durable memory revision.
9. If the user cancels, leaves the source scope, or the candidate is expired, do nothing and keep the candidate unpromoted.

A later manual page capture must deduplicate against the promoted source under M1's canonical identity policy. Promotion is not allowed to create a second durable source solely because it originated from a candidate.

Promotion and candidate deletion/forget actions are EventLedger-audited with redacted context IDs and typed action kinds. Candidate creation/discard is not a durable audit event containing source data.

## Retention, Forgetting, and Recovery

### Candidate retention

- Visible/pending candidates expire exactly 7 days after `capturedAt`.
- Nightly expiry runs only when the candidate store is healthy; if unavailable, the browser reports recovery-needed and does not claim cleanup completed.
- Expiry transitions rows to `expired`, removes candidate HotMemory, and records aggregate counts only.
- Dismissed, deleted, and expired rows remain as non-visible tombstones for at most 24 hours or until the relevant HotMemory/recovery acknowledgement is durable, whichever is later. A failed cleanup leaves a bounded hidden tombstone and a cleanup-degraded state; it does not create an unbounded retry log.
- Promoted rows retain only a redacted promotion linkage for 24 hours after successful M1 reconciliation, then are physically deleted. If the linkage cannot reconcile, the row becomes `quarantined` and remains covered by the 200-tombstone/8 MiB bound; it is never silently discarded.
- A scheduled sweep enforces both the active-row and total-store bounds. Sweep health is aggregate metadata included in M0 diagnostics, not a raw-content event.

### Nuke last 10 minutes

M3 defines nuke only for the dedicated candidate store and candidate HotMemory. It does **not** claim to erase durable Honeycomb sources or OS/database forensic remnants; the broader cross-store nuke belongs to M5.

The operation is scope-bound and transactional within the candidate store:

```text
nukeCandidates(since: Date, scope: ContextScope)
```

It deletes or tombstones candidates with `capturedAt >= since` for the active profile/workspace, removes matching candidate HotMemory entries, and returns counts by status. It never touches private data because private data never entered the store. It does not erase browser history, tabs, Honeycomb, EventLedger, or system-level traces in M3.

### Crash/restart reconciliation

On startup:

- The candidate store opens through the M0 `StorageEpochCoordinator`; its recovery journal is classified before new probe writes are admitted.
- `pending` candidates with valid expiry become `visible` after revalidation.
- Expired leases are reclaimed atomically; a lease with no durable promotion linkage returns to `visible`, while a lease with a Honeycomb node/attempt linkage is reconciled against Honeycomb and M1 attempt state. Any row violating the lease/status invariant is quarantined, never repaired by guessing.
- `promoted` rows with a stored node/attempt linkage are reconciled against Honeycomb and M1 attempt state; if complete, delete the candidate after the retention acknowledgement; if incomplete, preserve the candidate linkage for retry without creating a second source.
- Rows with unknown schema/status are quarantined, never treated as visible. Quarantine is included in the M0 triple snapshot/recovery record and cannot be evicted as ordinary cap cleanup.
- A missing/corrupt candidate store disables probe injection and candidate UI while ordinary browsing remains available; it never creates a replacement empty store automatically.

## Candidate UI and Privacy Surface

M3 uses progressive disclosure:

1. A quiet, dismissible toast: **“Hive noticed this page — Save to memory?”**
2. Actions: **Save**, **Not now**, **Never for this site**.
3. Candidate panel: visible candidates with source title/host, time, kind, bounded signal, scope, expiry, and exact “candidate — not in AI context” label.
4. Every row has **Save**, **Forget**, and **Never for this site** where applicable.
5. The kill list is inspectable in Privacy settings; the user can add/remove site opt-outs.
6. The UI never says “Hive remembers this” until promotion completes.
7. If candidate storage is degraded, the toast is absent and the browser remains normal.
8. Candidate surface must support keyboard, VoiceOver, reduced motion, dynamic type, and safe escaping of hostile titles.

No model explanation is required to show or reject a candidate. The UI must not narrate hidden inference or imply that the page asked to be saved.

## Failure and Threat Matrix

| Scenario | Required result | Must not happen |
|---|---|---|
| private tab | probe not injected; no candidate/store row/ledger payload | private URL/title persistence |
| kill-list host | probe not injected or event rejected; aggregate reason only | post-hoc scrub as a substitute for pause |
| password form | probe not injected/rejected; no candidate | password field values captured |
| site opt-out | no probe/candidate for host | silent re-enable on navigation |
| malformed bridge message | deterministic rejection; bounded aggregate counter | crash or parser overread |
| prompt injection in title | title treated as inert text; candidate never promotes autonomously | instruction execution or model call |
| stale callback | reject against committed tab URL/visit identity | candidate for a previous page |
| store unavailable/corrupt | disable candidate feature; browsing continues | empty-store replacement or success toast |
| duplicate event | idempotent no-op/replacement by policy | duplicate candidate rows |
| cap exceeded | deterministic eviction of eligible candidate only | promoted/quarantined row eviction |
| expiry sweep failure | visible cleanup-degraded state; retry later | claim all candidates expired |
| user Save | explicit M1 promotion path and audit | direct admission flip or silent durable write |
| promotion ledger failure | audit-incomplete source quarantined by M1; candidate not falsely promoted | fully captured label or duplicate retry source |
| user Forget | candidate removed/hidden and HotMemory cleared | durable Honeycomb deletion claim |
| nuke | candidate-window deletion only, scope-bound | claim browser-history/forensic erasure |
| model unavailable | candidate UI still works; no promotion | model required for capture |
| network unavailable | candidate UI still works; no network call | remote upload |

## M3 Execution Tasks

### Task C1 — Choose and implement the candidate-store contract

**Files:**
- Create: `Sources/HiveCore/Browser/WispCandidate.swift`
- Create: `Sources/HiveCore/Browser/WispCandidateStore.swift`
- Modify: M0 storage health/migration boundary only through the approved storage adapter
- Test: `Tests/HiveCoreTests/WispCandidateStoreTests.swift`

**Required behavior:**

1. Implement schema-v1 dedicated candidate SQLite store at the exact path above and register it with the M0 `StorageEpochCoordinator`, triple snapshot manifest, and recovery-journal reconciliation matrix.
2. Use parameterized SQL, actor isolation, bounded queries, startup health checks, migration/version checks, quarantine, paired backup/restore validation, and no silent empty reset.
3. Implement insert/replace, visible listing, dismissal, promotion lease, expiry, scoped nuke, deletion, and restart reconciliation.
4. Prove active/tombstone/size caps, `pending → visible → promoting → promoted|visible|quarantined` transitions, duplicate identity, lease expiry/recovery, and corruption behavior.
5. Keep candidate storage outside Honeycomb nodes/edges/FTS/Markdown export.

### Task C2 — Implement pure probe grammar and native admission

**Files:**
- Create: `Sources/HiveCore/Browser/WispAdmission.swift`
- Create: `Sources/HiveCore/Browser/WispProbeMessage.swift`
- Test: `Tests/HiveCoreTests/WispAdmissionTests.swift`

**Required behavior:**

1. Parse only the exact Stage 1 `HIVE_WISP|settled|...` grammar.
2. Decode and bound all fields; reject malformed, stale, private, unsafe, opt-out, kill-list, credential, PII-shaped, missing-scope, and rate-limited events.
3. Use native tab/page identity to reject stale callbacks.
4. Compute versioned content hash and deterministic replacement policy.
5. Produce aggregate rejection counts with no raw event payload.
6. Never call a model, URL fetcher, or privileged action.

### Task C3 — Inject the Stage 1 settled probe behind native guards

**Files:**
- Modify: the existing BrowserState/CEF probe injection owner identified during implementation audit
- Test: `Tests/HiveCoreTests/WispProbeContractTests.swift`

**Required behavior:**

1. Inject only after committed normal HTTP(S) page load and all native guards pass.
2. Use a self-guarding IIFE and existing console bridge encoding conventions.
3. Emit once after 4-second dwell and 600ms scroll settle; clamp numeric fields.
4. Add no interval polling, body text, screenshots, forms, or DOM subtree extraction.
5. Never inject in private tabs, kill-list sites, opt-out hosts, or unavailable candidate-store state.
6. Remove/disable the probe on navigation, private-mode transition, scope change, or cancellation.

### Task C4 — Add candidate HotMemory/UI boundary

**Files:**
- Modify: `Sources/HiveCore/Browser/HotMemoryStore.swift` only through a focused candidate API
- Create: `Sources/HiveCore/Browser/WispContextAdmission.swift`
- Modify: candidate panel/toast owner identified during implementation audit
- Test: `Tests/HiveCoreTests/WispContextAdmissionTests.swift`

**Required behavior:**

1. Insert candidate HotMemory entries with `.candidate`, `sourceHint: "wisp"`, native scope, and no model-context eligibility.
2. Route candidate listing/assembly through the one `WispContextAdmission` predicate at every concrete context, ranker, Brief, Honeycomb-retrieval, and export boundary; do not rely on caller-side filtering.
3. Remove entries on dismiss, expire, nuke, promotion, scope revoke, or store failure.
4. Provide the explicit “candidate — not in AI context” label.
5. Prove candidate IDs are rejected by `MemoryRetrievalAdmission`/selected-attempt resolution and cannot reach current-page context, Honeycomb retrieval, PageContextBroker, ranker input, Morning Brief, or export.
6. Add keyboard/accessibility/reduced-motion contract tests for the candidate surface.

### Task C5 — Implement explicit promotion through M1

**Files:**
- Create: `Sources/HiveCore/Browser/WispPromotion.swift`
- Modify: `Sources/Hive/BrowserState+Brief.swift` or the approved durable-capture owner
- Modify: `Sources/HiveCore/Honeycomb/HoneycombStore.swift` only through the M1 promotion adapter
- Modify: `Sources/HiveCore/EventLedger/EventLedgerStore.swift` only through typed promotion/audit calls
- Test: `Tests/HiveCoreTests/WispPromotionTests.swift`

**Required behavior:**

1. Require `PromoteWispRequest` with explicit user confirmation and current scope.
2. Revalidate candidate status, expiry, source identity, privacy, and scope.
3. Create/reuse a `.source` with M1 metadata and attempt-level audit identity.
4. Use `recordIfAbsent` and M1 `MemoryRetrievalAdmission`; audit-incomplete promotion remains quarantined.
5. Delete the candidate only after durable promotion/reconciliation succeeds.
6. Prove later manual capture deduplicates to the promoted source and no direct candidate→durable flip exists.

### Task C6 — Add retention, nuke, privacy, and adversarial fixtures

**Files:**
- Test: `Tests/HiveCoreTests/WispRetentionTests.swift`
- Test: `Tests/HiveCoreTests/WispPrivacyFixtureTests.swift`
- Test: `Tests/HiveCoreTests/WispPromptInjectionTests.swift`

**Required fixtures:**

- private tab and private-mode transition;
- banking, password-manager, messaging, authentication, and user opt-out hosts;
- password-form present and credential-shaped title/URL;
- malformed/oversized bridge messages and hostile titles;
- stale page callback after navigation;
- duplicate settled signals and stronger-signal replacement;
- 401st candidate cap behavior;
- seven-day expiry and failed sweep;
- scoped nuke last ten minutes;
- candidate-to-promotion success;
- Honeycomb success/EventLedger failure during promotion;
- restart with pending/promoted/quarantined rows;
- candidate exclusion through the shared `WispContextAdmission` seam from HotMemory model context, PageContextBroker, Honeycomb retrieval, Brief, export, and ranker inputs;
- no screenshot/body/network/model invocation instrumentation.

## M3 Acceptance Gates

| Gate | Requirement | Fresh evidence |
|---|---|---|
| M3-1 | Dedicated schema-v1 candidate store participates in M0 health, epoch-gated writes, paired snapshot/restore, quarantine, and recovery-journal semantics | storage/recovery integration tests |
| M3-2 | Candidate store is outside Honeycomb nodes/edges/FTS/export | schema and negative-query tests |
| M3-3 | Stage 1 settled probe is injected only behind native guards | probe contract + runtime fixture |
| M3-4 | Private/kill-list/password/opt-out paths produce zero candidate rows | adversarial privacy fixtures |
| M3-5 | Probe grammar, bounds, stale callback, and dedup are deterministic | pure admission tests |
| M3-6 | Candidate cap/TTL/expiry/nuke are scoped and deletion-tested | retention integration tests |
| M3-7 | Candidate HotMemory entries are explicitly `.candidate` and never model-visible | admission parity tests |
| M3-8 | Candidate UI is truthful, dismissible, accessible, and says not in AI context | UI/runtime evidence |
| M3-9 | Explicit Save promotes only through M1 source/attempt/audit path | promotion integration tests |
| M3-10 | Promotion failure leaves audit-incomplete source quarantined and candidate unpromoted | failure-injection fixture |
| M3-11 | Candidate creation/discard has no raw durable audit payload | ledger/redaction tests |
| M3-12 | No body text, screenshot, OCR, form values, model, or network path exists in Stage 1 | static/runtime instrumentation |
| M3-13 | Browser remains useful when candidate store/probe is disabled | clean-profile runtime path |
| M3-14 | No automatic promotion, task creation, promise inference, or authority widening | negative behavior suite |

M3 is `verified` only when all gates pass after M0–M2 have fresh evidence and a clean-profile runtime path. Probe code on disk is `code-present`, not verified.

## Implementation Order and Stop Conditions

1. Complete M0 storage/recovery gates before creating the candidate store.
2. Land pure candidate schema, status transitions, and admission tests before probe injection.
3. Ship Stage 1 settled-only probe with candidate store and no promotion before adding other trigger classes.
4. Prove candidate exclusion from all model/context/Brief/export paths before adding candidate UI claims.
5. Add explicit promotion only after M1 attempt-level capture is verified.
6. Add TTL/nuke/recovery and adversarial fixtures before enabling the feature broadly.
7. Run focused tests, `swift build`, `swift test`, and clean-profile runtime evidence.
8. Stop M3 before reader body extraction, screenshots/VLMs, promise detection, digest consolidation, vectors, remote services, or autonomous actions.

## Explicit Deferrals

- Honeycomb `.wisp` node type.
- Candidate inclusion in Swarm model context.
- Automatic durable promotion or model-selected promotion.
- Page body, reader text, DOM subtree, screenshot, OCR, VLM, or audio capture.
- Promise/commitment detection and task creation.
- Nightly candidate consolidation into durable episodes.
- Cross-store “forget last ten minutes” beyond candidate store + candidate HotMemory.
- Remote sync, analytics containing content, or cloud model calls.
