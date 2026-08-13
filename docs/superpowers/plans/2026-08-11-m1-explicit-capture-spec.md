# Hive M1 — Explicit Capture, Inspection, and Forgetting

> **Date:** 2026-08-11
> **Status:** planning contract; no implementation is implied by this document
> **Parent plan:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Code owners:** `Sources/Hive/BrowserState+Brief.swift`, `Sources/Hive/BriefCaptureView.swift`, `Sources/Hive/KnowledgePanel.swift`, `Sources/HiveCore/Browser/MemoryAdmission.swift`, `Sources/HiveCore/Browser/PageCaptureAdmission.swift`, `Sources/HiveCore/Browser/HotMemoryStore.swift`, `Sources/HiveCore/Honeycomb/HoneycombStore.swift`, `Sources/HiveCore/EventLedger/EventLedgerStore.swift`
> **Dependencies:** M0 storage/migration/recovery contract; current Honeycomb/EventLedger/HotMemory APIs
> **Non-dependencies:** model availability, web research provider, WISP/ambient capture, vectors, MCP, remote services
>
> This is the smallest trustworthy browser-memory loop:
>
> ```text
> Browse → explicitly Capture → see exactly what was saved → Inspect/Search → Export or Forget
> ```
>
> M1 does not add ambient capture. It does not infer durable memories from browsing. It does not make a model necessary for capture, inspection, export, or deletion.

---

## 1. Product decision

Hive earns permission to remember by making the first explicit capture legible and reversible.

A user must be able to answer these questions without reading documentation:

1. **What did Hive save?** URL, title, host, capture time, capture method, and the exact content class.
2. **Where did it go?** A Honeycomb node and optional project edge; HotMemory is warmed only when the active AI-context scope allows it.
3. **Will Swarm see it?** Only if the active context scope allows durable memory; when context is disabled, manual capture remains in Knowledge but is not warmed into HotMemory or model context.
4. **Was it already saved?** The capture result must say duplicate/reused, not pretend a new object was created.
5. **How do I remove it?** One visible path reaches inspect, export, and destructive delete/forget controls.
6. **What happens if storage fails?** Hive says so, keeps the browser usable, preserves unsaved note text, and never shows a false success.

The product language must distinguish:

- **URL/title capture:** durable metadata about the page, with no page body retained by this M1 path.
- **Readable-content capture:** a future, separately scoped capability requiring extraction, size limits, provenance, retention, and deletion tests.
- **Candidate memory:** model-derived/session data, never part of the durable M1 user journey.

Do not label the current M1 action “Save article,” “Read later,” or “Full page capture” unless the implementation actually stores the corresponding content. The honest default label is **Capture page metadata** or **Capture page** with an immediately visible “URL, title, host, and timestamp” receipt.

---

## 2. Current implementation truth

The following behavior is present in source and tests, but remains **code-present until M0 and the M1 runtime gates are executed on a clean profile**.

### 2.1 Admission and privacy

- `MemoryAdmissionPolicy.userAuthoredCapture(isPrivate:)` returns `.durable` only for non-private content and rejects private content.
- `PageCaptureAdmission.evaluate(isPrivate:)` returns `.deniedPrivateBrowsing` for private pages with an explicit user message.
- `PageCaptureDeliveryPolicy` permits manual persistence without Swarm context consent, but does not permit private or stale/canceled requests.
- `BrowserState.captureCurrentPage()` separately checks `isPrivateBrowsing` through the admission policy and checks the sticky Honeycomb/EventLedger degraded flags before writing.
- `HotMemoryStore` rejects private entries unless the active scope explicitly allows private content; the default browser scope does not.
- The M1 consent rule applies to notes as well as pages: when `aiContextAllowed == false`, a note remains durable in Knowledge but does not warm HotMemory.

### 2.2 Page capture

`BrowserState.captureCurrentPage()` currently:

1. Fails closed if knowledge or audit persistence is degraded.
2. Requires a non-private, usable `PageContext` with a URL.
3. Derives a deterministic node ID from the page URL.
4. Hashes the raw absolute URL plus title for deduplication.
5. Looks for an existing `.source` node by content hash.
6. On a duplicate, warms HotMemory and returns the existing node ID; the current early return does not yet record a duplicate audit event and is an M1 implementation gap.
7. On a new page, writes a `.source` Honeycomb node with URL, host, capture timestamp, and `manual_capture` metadata.
8. Warms HotMemory with `sourceHint: "captured"`; the current path does not yet receive the explicit Swarm/context-consent decision and must be tightened under §6.2.
9. Records a `.capture` EventLedger event with the actual node ID in `contextIDs`; the current event ID is random and the duplicate path currently skips the event.
10. Returns a partial-persistence error if the durable node exists but the audit event cannot be recorded.

The current node does not retain a page body in this path. `PageContext.text` is not written by `captureCurrentPage()`.

### 2.3 Note capture

`BrowserState.captureNote(_:)` currently:

- trims whitespace;
- rejects empty notes and private browsing;
- hashes the note content for deduplication;
- stores a `.note` node with user-authored `content` metadata;
- warms HotMemory with `sourceHint: "explicit"`;
- records a `.capture` event;
- keeps the caller responsible for preserving the input on failure.

Note capture is part of the M1 contract because it is the lowest-friction durable “Remember” path and should share the same failure, provenance, inspect, export, and delete rules as page metadata capture.

### 2.4 Inspection and deletion

`KnowledgePanel` currently provides:

- recent durable node listing;
- HotMemory listing filtered to durable, non-private entries;
- search over Honeycomb FTS5;
- a node inspector with provenance and timestamps;
- correction/revision history;
- Markdown export through a user-selected save panel;
- destructive delete with an audit-before / delete / audit-after chain;
- HotMemory removal after durable deletion.

`HoneycombStore.isInspectableNode` rejects candidate, private, and known legacy model-derived records. Candidate/session records must never appear in the durable M1 receipt, Knowledge list, search, export, or delete-as-durable-memory flow.

### 2.5 Current gaps

The M1 implementation pass must not assume these are solved merely because adjacent APIs exist:

- Capture UI currently describes Honeycomb/hot-memory behavior but does not expose a formal result type such as new versus duplicate.
- The page hash uses the raw absolute URL and title. A canonicalization policy is not yet specified in code.
- Honeycomb and EventLedger are separate stores; inserting a node and then recording an event is not a distributed transaction.

An `audit incomplete` node is a distinct durable state, not a prose-only flag. M0 owns the schema transaction; M1 consumes it through one canonical Honeycomb field/state:

```text
honeycomb_capture_attempts.audit_status TEXT NOT NULL DEFAULT 'unknown_legacy'
allowed values: unknown_legacy | pending | complete | incomplete
```

The M0 migration must add a `honeycomb_capture_attempts` table transactionally, reject unknown values at the adapter boundary, and update FTS/retrieval fixtures. Required columns are `attempt_id` (primary key), `node_id` (foreign key to the stored/reused node), `event_id`, `result_kind`, `audit_status`, `scope_json`, `created_at`, and `reconciled_at`. New explicit capture writes an attempt with `pending` before the audit attempt; `recordIfAbsent` success changes that attempt to `complete`; a failed audit changes it to `incomplete`. Existing nodes receive no fabricated attempt; their absence of an attempt is treated as `unknown_legacy` and remains excluded from model context until a deterministic reconciliation pass proves a matching complete capture event, after which the pass may create a complete attempt record. There is no automatic “assume complete” migration. A duplicate's failed attempt therefore quarantines only that capture attempt/result, never downgrades the already-complete node.

Define one shared, pure `MemoryRetrievalAdmission` predicate with this exact shape:

```text
MemoryRetrievalAdmission.evaluate(
  node: HoneycombStore.Node,
  captureAttempt: HoneycombStore.CaptureAttempt?,
  admission: MemoryAdmission,
  scope: ContextScope,
  isPrivate: Bool,
  isCandidate: Bool
) -> allowed | denied(reason)
```

The predicate rejects candidates/private/out-of-scope nodes and rejects the specific `captureAttempt` being evaluated when that attempt is `pending`, `incomplete`, or absent/`unknown_legacy`. A node may still have a separate prior complete attempt: a later duplicate attempt that fails audit is not allowed to introduce a new working-set entry, but it does not downgrade or block the node's previously reconciled durable capture when that prior complete attempt is the one being evaluated. Every shared caller must use this predicate. For a node with multiple attempts, retrieval first selects an eligible `complete` attempt for the requested scope; it must not blindly select the newest or latest failed attempt. Honeycomb model queries resolve that selected attempt through this predicate; HotMemory entries carry the admitted `attemptID` and `auditStatus` or perform an authoritative Honeycomb lookup before assembly; `PageContextBroker` evaluates it before returning a node; the retrieval ranker receives only already-admitted records. Durable provenance alone is never a bypass. Only successful stable-attempt reconciliation may set `audit_status: "complete"`. For the failed duplicate attempt specifically, until that attempt is reconciled successfully:

- Honeycomb user inspection/export may show it with the explicit incomplete label;
- default Honeycomb model-retrieval queries exclude it;
- HotMemory never admits or assembles it;
- `PageContextBroker`/context-scope assembly rejects it even if a caller supplies its ID;
- the retrieval-ranker input excludes it before ranking;
- the UI exposes only the audit-retry/recovery path, not a “use in AI context” action.

Reconciliation clears the state only after `EventLedgerStore.recordIfAbsent` succeeds with the matching attempt identity. This enforcement must live in the shared retrieval/admission boundary, not only in `KnowledgePanel`.
- If the node write succeeds and the audit write fails, the current code returns `partialPersistence` without an automatic rollback. M1 fixes the product contract without pretending the stores are atomic: the node remains inspectable/exportable with a visible `audit incomplete` status, is quarantined from model context, and is eligible for retry through the same stable capture-attempt identity. It is not silently deleted and not presented as fully captured.
- Knowledge-panel deletion removes the durable Honeycomb node and HotMemory entry, but “forget” from a Swarm context strip is a separate session-scoped operation. The UI must label these as different scopes.
- A raw SQLite delete is not proof of cryptographic erasure. M1 may promise logical deletion from Hive retrieval/search/graph paths, not forensic disk erasure.
- Existing tests prove many primitives independently; they do not yet prove the complete clean-profile browser journey.

---

## 3. M1 state machine

The capture controller should expose a typed, user-visible outcome. Exact type names are implementation details, but the states and semantics are required.

```text
idle
  → validating
      ├─ privateBlocked
      ├─ noUsablePage
      ├─ persistenceDegraded
      └─ ready
            → checkingDuplicate
                ├─ duplicateReused
                └─ newNode
                      → warmingHotMemory (only when AI context is allowed)
                          → recordingAudit
                              ├─ captured
                              └─ partialAudit
```

Notes have the same shape, replacing page validation with note validation.

### 3.1 Required result taxonomy

| Result | Durable node | HotMemory | Audit | User-facing meaning |
|---|---:|---:|---:|---|
| `capturedNew` | created | warmed only when AI context is allowed; otherwise suppressed | success | “Captured page metadata.” |
| `duplicateReused` | existing reused | refreshed only when AI context is allowed; otherwise suppressed | success/idempotent | “Already captured; reopened the existing memory.” |
| `capturedNote` | created | warmed only when AI context is allowed; otherwise suppressed | success | “Saved note.” |
| `privateBlocked` | none | none | no EventLedger event; no durable denial telemetry | “Private pages are never saved.” |
| `noUsablePage` | none | none | none | “Open an ordinary web page first.” |
| `persistenceDegraded` | none | none | none | “Memory is unavailable; browsing still works.” |
| `partialAudit` | node may exist | suppressed until audit reconciliation | failed/missing | “Saved locally, but the trust record failed. Hive will not call this fully captured.” |
| `staleOrCanceled` | none | none | none | “The old capture request was discarded.” |
| `storageFailure` | unknown/none | must not claim durable warm | failed or unavailable | “Capture failed; try again after storage recovery.” |

`duplicateReused` must not be reported as `capturedNew`. A duplicate may increment HotMemory access only when AI context is allowed and must record an idempotent capture event, but the result must say that no new node was created. The current duplicate early return skips that event and must change under M1.

`partialAudit` is not a normal success. It must set or preserve the sticky audit-degraded state, expose recovery guidance, and make the node discoverable for later reconciliation without silently upgrading it to a healthy audited capture.

### 3.2 No false receipt rule

The success view may appear only after the required result state is known. A spinner is not a success state. A Honeycomb insert alone is not a fully successful capture when the M1 contract requires an audit event.

---

## 4. Capture payload and provenance contract

### 4.1 Page metadata payload

Every new page capture must preserve:

```json
{
  "node_type": "source",
  "url": "https://example.com/path",
  "host": "example.com",
  "title": "User-visible page title",
  "captured_at": "ISO-8601",
  "capture_method": "manual_page_metadata",
  "privacy_class": "normal",
  "content_class": "url_title_host_only",
  "content_hash": "sha256(...)"
}
```

The values above are the user-visible/provenance contract, not a demand that all fields be duplicated in metadata if the canonical node schema already carries them. The storage adapter must have one authoritative mapping.

Required provenance facts:

- source URL as observed at capture;
- canonical URL used for deduplication, if different;
- page title as observed at capture;
- host/origin;
- capture timestamp;
- capture method;
- normal/private classification;
- profile/workspace/project scope where applicable;
- node ID actually stored;
- stable capture-attempt ID;
- audit event ID once recorded, or explicit `audit incomplete` status;
- whether the result was new or reused.

The current implementation does not yet persist all of these fields: it uses `method: "manual_capture"`, omits the explicit content/privacy class and scope/audit status, and creates a random audit ID. These are deliberate M1 deltas, not verified current behavior. Existing records must not be silently rewritten; the implementation must define a compatibility/defaulting rule for legacy nodes.

No password, cookie, form value, screenshot, raw DOM, full page body, access token, or model-generated claim enters the M1 page metadata payload.

### 4.2 URL policy

Until a dedicated canonicalizer exists, use the observed URL as the reproducibility identity and say so in the plan/runtime evidence. When canonicalization is implemented, it must:

1. parse with a standards-compliant URL parser, never a regex;
2. preserve scheme, authority, path, and meaningful query parameters;
3. resolve dot segments and normalize equivalent host casing according to the parser;
4. define fragment behavior explicitly;
5. define tracking-parameter stripping as a user-visible, versioned policy—not an invisible assumption;
6. retain both observed and canonical forms when they differ;
7. include the canonicalizer version in provenance so old dedup decisions remain explainable.

M1 must not silently strip arbitrary query parameters. A tracking parameter can be part of the resource identity.

### 4.3 Note payload

A user-authored note must retain:

- the exact user-entered content after only whitespace normalization;
- a stable content hash;
- capture timestamp;
- `provenance: "user"`;
- normal privacy classification;
- profile/workspace/project scope;
- the audit event ID and node ID.

The note inspector may show and export the note body because it is user-authored durable content. The page metadata path may not claim the same body-retention behavior.

---

## 5. Side-effect ordering and cross-store boundary

M1 does not pretend Honeycomb and EventLedger are one transaction.

### 5.1 Required ordering

```text
admission + scope validation
  → Honeycomb dedup lookup
    → Honeycomb insert/reuse
      → conditional HotMemory warm (only when AI context is allowed)
        → EventLedger capture record
          → publish typed result + UI receipt
```

For a new node, the capture event must reference the returned stored node ID, not a provisional ID. For a duplicate, the event must reference the reused node ID and identify the result as `duplicate_reused`.

### 5.2 Honeycomb failure

If dedup lookup or insertion fails:

- do not warm HotMemory as durable;
- do not show a success receipt;
- latch knowledge persistence degradation through the existing browser health boundary;
- preserve the page and note input for retry where applicable;
- keep navigation, tabs, and ordinary browser use available.

### 5.3 EventLedger failure

If Honeycomb succeeds but the required audit event fails:

- return `partialAudit`, never `capturedNew`;
- latch audit persistence degradation;
- keep the node inspectable and exportable with a visible `audit incomplete` state;
- quarantine that node from model context and default retrieval until the audit retry succeeds; the shared `MemoryRetrievalAdmission` predicate must enforce this across Honeycomb model queries, HotMemory assembly, PageContextBroker admission, and retrieval-ranker inputs;
- never fabricate a completed event ID;
- retain the stable capture-attempt ID, node ID, and scope for M0 reconciliation;
- do not automatically delete the node as an unreviewed compensation action.

This is the fixed M1 choice; implementation must not replace it with an undocumented “keep visible” versus “quarantine” fork.

The M1 implementation must create a `captureAttemptID` at the start of each user invocation and retain it through UI retry/recovery. The ledger event ID is derived from that attempt identity (for example, a versioned namespace/key derivation), and the event is written with `recordIfAbsent`. A retry of the same attempt therefore cannot duplicate the event; a later, separate user invocation may create a separate event even if it reuses the same node.

### 5.4 Project linking

Project linking is a separate graph mutation after the page source exists. It must:

- be idempotent by `(sourceID, projectID, belongsTo)`;
- report a partial project-link failure separately from capture success;
- never duplicate an edge on repeated capture;
- preserve the page capture receipt even if the optional project edge fails;
- allow retry from the project surface.

---

## 6. Browser-first and privacy boundaries

### 6.1 Private browsing

Private capture is an absolute no-write path for M1:

- no Honeycomb node;
- no EventLedger payload containing private URL/title;
- no HotMemory entry;
- no search/index/export/revision row;
- no browser history or session persistence side effect;
- no remote or local model invocation.

A user-visible denial message is allowed and should explain the boundary without echoing the private URL or title into durable UI state.

### 6.2 Swarm disabled / context disallowed

Manual capture remains a browser-owned durable action even when Swarm is disabled or `aiContextAllowed == false`, consistent with `PageCaptureDeliveryPolicy`.

In that mode:

- Honeycomb and Knowledge inspection remain available if persistence is healthy;
- HotMemory is not warmed by the manual capture path;
- no model, auto-triage, or remote provider is invoked;
- the receipt must not imply that Swarm will use the capture.

M1 chooses suppression: when `aiContextAllowed == false`, manual capture still persists to Honeycomb/Knowledge, but it does not call `HotMemoryStore.didAccessNode`. This keeps explicit browser memory useful without allowing a context-disabled capture to enter the model working set. The capture receipt must say “Saved to Knowledge; not added to AI context.”

### 6.3 Disabled memory / persistence degraded

A memory/storage failure must not disable:

- navigation;
- tabs and tab switching;
- private browsing;
- downloads and ordinary page rendering;
- the zero-history start page.

The browser must disclose that durable memory is unavailable and must not offer a button that appears to capture successfully while writes are blocked.

### 6.4 Scope

Every durable capture belongs to the active profile/workspace scope. A project edge may add a narrower project scope; it must not widen the capture to other profiles. Missing scope metadata is not permission to make a node global.

---

## 7. Inspect, search, export, and forget UX

### 7.1 Capture receipt

Immediately after capture, show:

- result: **New capture** or **Already captured**;
- content class: **URL + title + host** for the current M1 path;
- title and host, safely truncated;
- timestamp;
- destination: **Knowledge** and, if applicable, the project name;
- privacy label: **Normal profile**;
- actions: **Inspect**, **Open page**, **Export**, **Forget/Delete**, **Done**.

Do not hide the duplicate state behind a generic green checkmark.

### 7.2 Knowledge list

The Knowledge panel should show durable, inspectable records only. Each row should expose enough metadata to distinguish:

- page source versus note;
- new/reused capture where the receipt is still open;
- provenance;
- relative capture time;
- scope;
- whether audit reconciliation is pending.

Candidate/session data must not appear in this list merely because it is hot or recent.

### 7.3 Inspector

The inspector must expose:

- type;
- title/label;
- observed URL and canonical URL if available;
- capture method and timestamp;
- provenance;
- profile/workspace/project scope;
- audit status/event ID;
- content class and retention class;
- revision history where corrections exist;
- linked sources/edges where present.

The inspector must not display raw internal IDs as the primary user-facing explanation, but may show a copyable diagnostic identifier in an advanced section.

### 7.4 Export

Export must be explicit and user initiated. The Markdown record must include provenance and must not claim to contain the page body when it contains only metadata. It must exclude secrets, internal transport metadata, candidate records, and private records.

### 7.5 Forget versus delete

Use distinct language:

- **Forget from context:** removes a node from the current HotMemory/context surface and blocks passive re-addition for the defined session/scope. It is reversible only through the explicit restore path.
- **Delete durable memory:** removes the Honeycomb node, FTS row, graph edges, revision history, and HotMemory entry according to the M0 deletion contract. It is logically destructive and should require confirmation.
- **Forget last time window:** remains deferred to M5; do not imply that M1’s single-node delete provides time-window erasure.

A successful delete must not leave the node searchable, exportable, or retrievable by the default context broker. A failed delete remains visible with a failure state and retry path.

---

## 8. Failure and recovery matrix

| Scenario | Required behavior | Browser impact | Test fixture |
|---|---|---|---|
| normal new page | create Source, warm only when AI context is allowed, audit, receipt | none | clean profile capture |
| identical repeated page | reuse node, refresh access only when AI context is allowed, idempotent audit | none | repeated capture |
| same URL, changed title | result follows defined hash policy; no silent claim of identity | none | title variation |
| tracking query variation | preserve or canonicalize per documented policy | none | query fixture |
| private page | reject before durable ingress | none | private capture |
| blank/internal URL | reject as no usable page | none | `about:blank` / `hive://` |
| no active page | reject with actionable guidance | none | new tab capture |
| Honeycomb unavailable | no success; latch degraded state | browsing continues | injected open/write failure |
| Honeycomb dedup read fails | treat as storage failure, not cache miss | browsing continues | injected query failure |
| Honeycomb insert fails | no HotMemory durable warm | browsing continues | injected insert failure |
| EventLedger unavailable after node write | `partialAudit`, no false success, reconciliation state | browsing continues | injected ledger failure |
| audit retry | stable event identity; `recordIfAbsent` succeeds exactly once | none | retry after recovery |
| HotMemory warm fails/actor canceled | durable result remains honest; context remains absent | browsing continues | cancellation fixture |
| project edge fails | capture succeeds, project link is retryable partial | none | injected edge failure |
| malformed/hostile title | bounded, escaped UI; no script or layout break | none | title injection fixture |
| note write failure | preserve typed note text; show retry | browsing continues | injected note failure |
| delete failure | do not dismiss inspector; show retry/error | browsing continues | injected delete failure |
| stale callback | no write/no receipt | none | request-generation fixture |

M1 does not test ambient probes, model-generated claims, screenshots, page-body extraction, vector retrieval, or remote services. Those belong to later gates.

---

## 9. Test and evidence plan

### 9.1 Pure policy tests

Extend or preserve tests for:

- normal/private admission;
- manual capture with and without Swarm context consent;
- stale/canceled request no-effects behavior;
- URL parsing/canonicalization policy once implemented;
- inspectability of durable versus candidate/private/legacy records;
- result taxonomy encoding and stable wire values.

### 9.2 Store integration tests

Add deterministic fixtures for:

- new Source creation with required metadata and `audit_status: pending → complete`;
- duplicate reuse and no duplicate node;
- actual returned node ID in audit context;
- idempotent audit retry;
- legacy `unknown_legacy` row excluded from every model-retrieval path until reconciliation;
- `MemoryRetrievalAdmission` parity across Honeycomb queries, HotMemory assembly, PageContextBroker, and ranker inputs;
- Honeycomb failure before HotMemory;
- EventLedger failure after Honeycomb and explicit partial state;
- project edge idempotency;
- delete cascade through FTS, edges, revisions, and HotMemory;
- export metadata-only truthfulness;
- private capture leaves zero durable rows and no private ledger payload;
- hostile title/URL rendering safety.

### 9.3 UI/runtime evidence

On a clean non-private profile:

1. Open a normal HTTPS page.
2. Open Capture Page and verify the receipt says URL/title/host metadata.
3. Capture once; verify **New capture**.
4. Capture again; verify **Already captured**, with one durable node.
5. Open Knowledge; inspect provenance and audit state.
6. Search the title/host; open the source.
7. Export Markdown; verify content class and provenance.
8. Delete the node; confirm it disappears from list/search/export/context.
9. Attempt capture in private mode; verify no durable row and an honest denial.
10. Disable Swarm/context and repeat manual capture; verify browser remains useful and no model call is required.
11. Inject persistence failure; verify browsing continues and capture does not show success.

Record exact commands, profile state, screenshots or runtime observations where allowed, and remaining limitations before changing the capability label to `verified`.

### 9.4 M1 exit gates

M1 closes only when all gates pass:

| Gate | Requirement |
|---|---|
| M1-A | Normal/private admission and no-private-write invariant pass. |
| M1-B | New versus duplicate result is explicit and deterministic. |
| M1-C | Page metadata payload and provenance are accurate; no body-retention overclaim. |
| M1-D | EventLedger context ID resolves to the actual stored/reused node. |
| M1-E | Honeycomb/EventLedger partial failure is visible, retryable, and never false success; `audit_status` transitions are durable, and incomplete/pending/legacy-unknown nodes are excluded by Honeycomb model retrieval, HotMemory, context-broker admission, and retrieval-ranker input until reconciliation. |
| M1-F | HotMemory warm and scope behavior are tested; no private/candidate leak. |
| M1-G | Knowledge search and inspection resolve only inspectable durable nodes. |
| M1-H | Export is user initiated, provenance stamped, and content-class honest. |
| M1-I | Forget-from-context and delete-durable-memory are distinct and tested. |
| M1-J | Delete removes search/FTS/edges/revisions/context according to policy. |
| M1-K | Browser remains useful with Swarm disabled and persistence degraded. |
| M1-L | Clean-profile runtime path passes without model/network dependency. |

All 12 gates require current evidence. Code presence or an in-memory unit test alone is insufficient for M1 verification.

---

## 10. Implementation order after approval

This document intentionally stops before code changes. Once approved, implement in this order:

1. Add a small pure capture-result/provenance contract and fixture tests.
2. Decide and document raw-versus-canonical URL identity without silently changing existing data.
3. Make capture receipt states truthful: new, duplicate, partial, blocked, degraded.
4. Thread explicit context consent into capture; suppress HotMemory when consent is off.
5. Make audit event identity retryable with the stable `capture/<attemptID>/v1` ID, persist `HoneycombStore.CaptureAttempt`, and audit duplicate reuse.
6. Consume the M0 `honeycomb_capture_attempts` migration; implement the exact shared `MemoryRetrievalAdmission.evaluate(...)` predicate with no bypass, and enforce the incomplete/pending/unknown exclusions across Honeycomb retrieval, HotMemory, context-broker admission, and retrieval-ranker input.
7. Add/complete Knowledge receipt → inspect/export/delete/forget affordances without widening candidate visibility.
8. Add failure-injection and clean-profile UI/runtime coverage.
9. Run focused tests, `swift build`, `swift test`, and the browser runtime gate.
10. Append evidence to AGENTS.md only after fresh build/test/runtime results.

Do not begin M3/WISP implementation or local model training as part of M1.

---

## 11. Explicit deferrals

- Automatic/ambient page capture and WISP candidates.
- Full readable article extraction, screenshots, PDFs, web archives, and DOM snapshots.
- Promise detection, daily digest, reinforcement, forgetting curves, and time-window nuke.
- Vectors, page diffs, temporal claims, MCP, sync, and SQLCipher.
- Remote model routing or model training.
- Cryptographic deletion claims.

M1 is deliberately narrow: a user chose to save a page or note, Hive tells the truth about what was saved, and the user can find, inspect, export, and remove it.
