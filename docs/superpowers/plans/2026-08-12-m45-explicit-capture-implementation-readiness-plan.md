# M45 — Explicit Capture Implementation Readiness

> **Date:** 2026-08-12
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M45 Explicit Capture Implementation Readiness
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Predecessor:** `docs/superpowers/plans/2026-08-12-m44-governance-traceability-implementation-readiness-plan.md`
> **Product contract:** `docs/superpowers/plans/2026-08-11-m1-explicit-capture-spec.md`
> **Dependencies:** M0 storage/migration/recovery; current HoneycombStore, EventLedgerStore, HotMemoryStore, browser profile/private boundaries, and M1 capture UX contract
> **Primary code seams:** `Sources/Hive/BrowserState+Brief.swift`, `Sources/Hive/BriefCaptureView.swift`, `Sources/Hive/KnowledgePanel.swift`, `Sources/Hive/ProjectDetailPanel+Capture.swift`, `Sources/HiveCore/Browser/MemoryAdmission.swift`, `Sources/HiveCore/Browser/PageCaptureAdmission.swift` when present, `Sources/HiveCore/Browser/MemoryRetrievalAdmission.swift` when implemented, `Sources/HiveCore/Browser/HotMemoryStore.swift`, `Sources/HiveCore/Honeycomb/HoneycombStore.swift`, `Sources/HiveCore/EventLedger/EventLedgerStore.swift`
> **Research anchors:** Apple `WKWebView` JavaScript evaluation and App Sandbox/file access; SQLite WAL, transactions, foreign keys, and backup; W3C WCAG 2.2 status/error guidance; M0/M1 contracts and current source/test inventory
> **Non-dependencies:** model availability, model training, WISP/ambient capture, page-body extraction, screenshots, vectors, MCP, sync, remote services, import, and Brief generation
>
> M45 is the bounded handoff between the M1 contract and a future runtime implementation. It does not claim that explicit capture is implemented, verified, or ready to ship; `handoff-ready` is not implemented or verified. The first runtime slice remains:
>
> ```text
> Browse → user chooses Capture → truthful result → inspect/search/export/forget
> ```

## 0. Decision summary

Explicit capture is the smallest credible first runtime slice after M44 because it proves the browser-to-memory wedge without requiring ambient surveillance, model routing, network research, import conversion, or a new authority. It is a user-triggered action with a narrow payload and a reversible inspection/deletion path.

| Candidate | Why not first | M45 decision |
|---|---|---|
| **M1 explicit page/note capture** | Smallest durable user value, existing UI/store seams, clear private/no-write boundary | **Selected** |
| M2 import and Brief credibility | Bulk ingestion and read-only projections depend on stronger capture/provenance semantics and broader fixtures | Defer until M1 runtime evidence exists |
| M15 browser credibility | Valuable but broad: navigation, sessions, downloads, permissions, media, and recovery | Continue as a parallel roadmap concern, not this handoff |
| AI/model routing or training | Not required for a user-chosen metadata capture and would widen privacy, runtime, and resource scope | Explicitly excluded |

M45 freezes five implementation work packages:

```text
A contract and owner reconciliation
  → B capture state/result and provenance seam
    → C cross-store ordering and recovery boundary
      → D browser-first UX, privacy, and accessibility matrix
        → E bounded runtime handoff and evidence decision
```

M45 adds no new Honeycomb authority, EventLedger authority, ledger, database, model, governance layer, remote service, or telemetry system; there is no new store, ledger, authority, or governance layer in this documentation-only handoff. M45 is not a substitute for M0 migration work. M0 owns the transactional schema/migration contract; the future M1 runtime consumes that contract.

## 1. Current implementation truth

The current checkout must be treated as **code-present, not verified** for this slice.

### 1.1 What exists on disk

- `BrowserState+Brief.swift` contains `captureCurrentPage()` and `captureNote(_:)`.
- `BriefCaptureView` and `KnowledgePanel` expose capture entry points.
- `MemoryAdmissionPolicy.userAuthoredCapture(isPrivate:)` rejects private capture and admits only non-private user-authored capture as durable-eligible.
- `HoneycombStore` provides typed nodes, content-hash lookup, FTS-backed inspection/search, deletion, WAL setup, and foreign-key setup.
- `EventLedgerStore` provides append-only audit events, `recordIfAbsent`, WAL setup, and foreign-key setup.
- `HotMemoryStore` provides the in-memory working set and scope fields, but its capture callers must be made consent-aware before M1 can be considered complete.
- The current page capture path inserts/reuses a node, warms HotMemory, then records an audit event; Honeycomb and EventLedger are separate stores and are not one distributed transaction.

### 1.2 Known gaps that M45 must hand to implementation

- The live page and note APIs return only a node ID, not the M1 result taxonomy (`capturedNew`, `duplicateReused`, `partialAudit`, blocked, degraded, and so on).
- The page duplicate early return currently warms HotMemory and returns without recording the required duplicate audit event.
- The current audit ID is random rather than derived from a stable capture-attempt identity; retry idempotency is therefore not yet proven by the live capture path.
- The live capture path warms HotMemory without threading the M1 `aiContextAllowed`/scope decision through the call.
- Current metadata uses `method: "manual_capture"` but does not yet expose every M1 provenance field, including explicit content/privacy class, scope, stable attempt ID, and audit status.
- The M1 contract requires `honeycomb_capture_attempts` and a shared `MemoryRetrievalAdmission` predicate. `MemoryRetrievalAdmission.swift` is not present in the current source inventory; this is an implementation dependency, not evidence that the contract is wired.
- The current Honeycomb/EventLedger sequence can leave a node present when audit recording fails. M45 fixes the required product behavior at the contract boundary: visible `audit incomplete`, no false success, quarantine from model context, and stable retry; it does not claim atomic rollback.
- Existing unit tests cover adjacent primitives, but no current evidence proves the clean-profile end-to-end journey described by the M1 gates.

These gaps remain **planned/blocked**, not silently reclassified as verified. A future implementation owner must re-audit the checkout and update exact symbols before writing code.

## 2. Canonical authority and ownership

M45 binds each concern to an existing authority. It does not create a projection that can promote itself or replace an owner.

| Concern | Canonical owner | M45 handoff rule |
|---|---|---|
| User capture intent and UI state | Browser capture controller owned by `BrowserState` and its capture views | A view may display a result but may not infer durable success from a spinner, node ID, or local UI state |
| Durable Source/Note node, metadata, FTS, edges, revisions, logical deletion | `HoneycombStore` | No shadow capture database, JSON receipt store, or UI-only durable record |
| Append-only capture/audit evidence | `EventLedgerStore` | Use the existing ledger and `recordIfAbsent`; no second capture ledger or mutable audit projection |
| Capture-attempt/audit-status reconciliation schema | M0-owned Honeycomb migration and adapter | M45 consumes the M0 contract; it does not migrate the database or invent a parallel attempt store |
| Session working set | `HotMemoryStore` | Hotness is not durable admission; every entry must preserve scope/admission and obey the shared retrieval predicate |
| Durable admission | `MemoryAdmissionPolicy` plus the future shared M1 retrieval/admission seam | A model or HotMemory caller cannot grant durability or widen scope |
| Private browsing | Existing browser profile/private state and admission policy | Private capture is an absolute no-write path, not a special durable class |
| Optional project link | Existing Honeycomb graph/project owner | Link failure is a separately visible retryable partial result, never a reason to duplicate the source node |
| Evidence status | M44 evidence contract and the future implementation owner | M45 may be `handoff-ready` only; `verified` requires fresh evidence with identity binding and owner approval |

If two owners disagree, the future implementation owner records the conflict as `blocked` or `unresolved`; M45 does not resolve an authority conflict by preference or document order.

## 3. M45-A — Contract and owner reconciliation

Before implementation, the owner must reconcile the M1 prose with the actual checkout:

1. Confirm exact current signatures and call sites for page capture, note capture, project linking, HotMemory warming, Honeycomb lookup/insert, EventLedger recording, and degradation flags.
2. Confirm whether M0 has landed the `honeycomb_capture_attempts` schema. If absent, M1 remains blocked on M0; M45 does not add the migration.
3. Confirm whether `PageCaptureAdmission` exists and is used. If absent or unused, record that as a source-contract gap rather than claiming its policy is active.
4. Confirm whether a shared `MemoryRetrievalAdmission` exists. If absent, all claims about pending/incomplete/unknown audit exclusion remain planned.
5. Confirm the active profile/workspace/project scope source and its behavior on restart, private mode, and locked/unavailable state.
6. Confirm the actual EventLedger idempotency API and the exact stable-ID derivation accepted by its owner.
7. Confirm the current Honeycomb deletion cascade and FTS behavior against the M0 deletion contract.
8. Record the exact source revision, environment, evidence scope, and limitations for each reconciliation result.

No source symbol, fixture, mock, or plan text may be promoted to `verified` by this work package.

## 4. M45-B — Typed result and provenance handoff

The future capture owner must expose a typed result with stable wire values. Type names may differ, but semantics cannot.

### 4.1 Required result states

| Result | Durable node | HotMemory | Ledger | User meaning |
|---|---:|---:|---:|---|
| `capturedNew` | created | warm only if context scope allows | complete | New page metadata or note saved |
| `duplicateReused` | existing reused | refresh only if context scope allows | idempotent success | Already captured; no new node created |
| `capturedNote` | created | warm only if context scope allows | complete | User note saved |
| `privateBlocked` | none | none | no private payload | Private pages are never saved |
| `noUsablePage` | none | none | none | Open a normal web page first |
| `persistenceDegraded` | none | none | none | Memory is unavailable; browsing continues |
| `partialAudit` | node may exist | suppressed | failed/incomplete | Saved locally, but not fully audited |
| `staleOrCanceled` | none | none | none | Old request discarded without effects |
| `storageFailure` | unknown/none | none | unavailable/failed | Capture failed; retry after recovery |
| `projectLinkPartial` | source capture remains valid | unchanged | source audit remains valid | Optional project link needs retry |

`duplicateReused` must never be reported as `capturedNew`. A stable duplicate event records the reused node and attempt identity without creating a second node. `partialAudit` is not a normal success and must not render a green success receipt.

### 4.2 Page metadata contract

M1 retains metadata only, not readable body content:

```json
{
  "node_type": "source",
  "observed_url": "https://example.test/path",
  "canonical_url": "https://example.test/path",
  "host": "example.test",
  "title": "Synthetic page title",
  "captured_at": "ISO-8601",
  "capture_method": "manual_page_metadata",
  "privacy_class": "normal",
  "content_class": "url_title_host_only",
  "scope": "profile/workspace/project",
  "content_hash": "sha256(...)"
}
```

The canonical storage owner decides which facts are columns versus metadata. The implementation must preserve observed and canonical URL forms when they differ, define fragment behavior, avoid invisible arbitrary tracking-parameter stripping, and version any canonicalizer. M45 does not authorize page-body, DOM, screenshot, PDF, password, cookie, token, form-value, or model-claim retention.

### 4.3 Note contract

A note preserves the exact user-authored text after documented whitespace normalization, a stable content hash, timestamp, `provenance: "user"`, privacy/scope metadata, node ID, attempt ID, and audit status. The note inspector/export may show the note body because it was explicitly authored; that does not expand page capture into body capture.

## 5. M45-C — Ordering, partial persistence, and recovery

Honeycomb and EventLedger remain separate stores. The required sequence is:

```text
admission + profile/private/scope validation
  → create stable capture attempt (M0 owner)
    → Honeycomb dedup lookup
      → Honeycomb insert or reuse
        → conditional HotMemory warm
          → EventLedger recordIfAbsent
            → complete/incomplete attempt state
              → typed result and receipt
```

### 5.1 Stable attempt identity

Each user invocation receives a stable attempt identity before side effects. The attempt ID MUST be generated exactly once at the user-action boundary by the system UUID generator as a UUID version 4, rendered in canonical lowercase RFC 4122 hyphenated form (`8-4-4-4-12` hexadecimal characters), persisted in the M0-owned capture-attempt record before Honeycomb lookup/insert, and reused by every UI retry, process-restart recovery, and audit reconciliation for that attempt. It MUST NOT be derived from model output, page text, URL, title, timestamp, profile, workspace, or a mutable UI counter. The audit event ID MUST be derived from that identity using the exact versioned encoding `capture/<attemptID>/v1`: literal lowercase `capture`, one `/`, the canonical lowercase UUID, one `/v1`, and no additional timestamp, profile, workspace, or random suffix. The same attempt ID MUST produce byte-for-byte the same event ID; a different UUID MUST produce a different event ID, and an existing event with the same ID but any non-equivalent payload is a conflict that remains `blocked` until the owner resolves it. A retry of the same attempt must be idempotent; a later user invocation may produce a separate event while reusing the same durable node.

The attempt record must distinguish `unknown_legacy`, `pending`, `complete`, and `incomplete`; this exact state set is mandatory for the handoff and is not an illustrative enum. A generated UUID v4 attempt ID is never reused for a different user invocation, even when both invocations reuse the same Honeycomb node. Existing nodes do not receive fabricated successful attempts. An incomplete duplicate attempt quarantines that attempt/result without downgrading a previously complete durable attempt for the same node.

### 5.2 Honeycomb failure

On lookup/insert failure, the future runtime must not warm HotMemory or show success. It reports a bounded, text-readable error, latches the existing knowledge degradation boundary, preserves note input for retry where possible, and leaves navigation, tabs, private browsing, downloads, and ordinary rendering usable.

### 5.3 EventLedger failure

If Honeycomb succeeds but the audit write fails, the future runtime returns `partialAudit`, marks the attempt incomplete, keeps the node inspectable/exportable with an explicit audit-incomplete label, suppresses HotMemory/model-context admission for that attempt, and offers stable retry. It does not fabricate an event ID, silently delete the node, or claim cryptographic erasure.

### 5.4 Cancellation and restart

Cancellation before durable admission produces no node, no HotMemory entry, and no success receipt. Cancellation after a node write is handled as a partial attempt and reconciled through the same attempt identity; it is never silently treated as a completed capture. On restart, pending/incomplete/unknown attempts remain visible to recovery and excluded from model retrieval until the canonical reconciliation rule succeeds.

## 6. M45-D — Browser-first, privacy, and accessibility matrix

Every future runtime slice must explicitly cover all dimensions below. “Where applicable” is not sufficient; if a dimension truly cannot apply, the owner records evidence-backed `not_applicable` with scope and rationale.

| Dimension | Required behavior | Forbidden claim |
|---|---|---|
| Normal online | Capture loaded page metadata without requiring a model or remote service | Full-page or research capture |
| Offline after page load | Capture may proceed from already-available metadata if local stores are healthy; no network retry is implied | “Offline sync” or remote freshness |
| Offline before page load | Show no-usable-page/network limitation; browser remains usable | Successful capture of unavailable content |
| Private browsing | Reject before durable ingress; no URL/title in Honeycomb, EventLedger, HotMemory, search, export, or history | Private memory support |
| Locked/unavailable profile | Fail closed or use only an explicitly approved non-private local scope; disclose unavailable scope | Guessing a global scope |
| Storage degraded | No false success; browsing remains usable; retry path visible | Silent in-memory durability |
| Audit degraded | `partialAudit`/blocked; no model-context admission | Fully captured status |
| Swarm/model disabled | Manual capture remains useful in Knowledge; HotMemory is suppressed when context is disallowed | “Swarm will remember/use this” |
| Permission denied | Explain the specific denied action and offer ordinary browsing fallback | Repeated prompts or bypass |
| Accessibility | Status/result/error is text-readable, focus-safe, keyboard reachable, and not color-only | Accessibility conformance claim without runtime evidence |
| Reduced motion | Receipt and panel state do not depend on animation | Motion-only confirmation |
| Stale/canceled callback | No side effect or success receipt for an obsolete request | Last callback wins |
| Hostile title/URL | Bound and escaped display; diagnostic data separated from user-facing text | Raw page text in logs/telemetry |

Apple’s `WKWebView.evaluateJavaScript` is asynchronous and can fail with a scripting error; M45 therefore does not require page-body extraction and treats any future extraction as a separate bounded capability. macOS App Sandbox limits file access to the container or explicitly user-selected/security-scoped resources; M1 export remains user initiated. W3C WCAG 2.2 status-message guidance informs the receipt/error contract, but M45 does not claim conformance.

## 7. Inspect, export, forget, and delete boundary

The future receipt must show:

- **New capture** or **Already captured**;
- **URL + title + host** as the retained content class;
- timestamp, profile/workspace scope, and destination;
- audit status, including **audit incomplete** when applicable;
- actions for Inspect, Open page, Export, Forget from context, Delete durable memory, and Done where each is valid.

The UI must distinguish:

- **Forget from context:** session/scope working-set removal through HotMemory; not durable deletion.
- **Delete durable memory:** Honeycomb logical deletion with FTS/edge/revision/HotMemory effects according to M0; not forensic disk erasure.
- **Export:** explicit user action through the existing user-selected file boundary; metadata-only export must not claim page-body retention.

Candidate/session records, private records, failed or unknown attempts, credentials, cookies, raw DOM, screenshots, and internal transport metadata must not appear in the ordinary Knowledge list, default model retrieval, or export.

## 8. M45-E — Bounded implementation handoff

Once M45 is approved for execution, the future owner may implement only this order:

1. Reconcile the actual source symbols and M0 schema status; record blocked dependencies first.
2. Add the pure typed result/provenance/attempt contract and deterministic fixture tests.
3. Implement the stable attempt/audit identity using the existing EventLedger API.
4. Make page and note capture return explicit new/duplicate/partial/blocked/degraded outcomes.
5. Thread profile/workspace/project scope and `aiContextAllowed` through HotMemory admission.
6. Add the shared retrieval/admission seam and enforce pending/incomplete/unknown exclusion across every model-context path; no bypass in UI or ranker.
7. Add truthful receipt, inspector, export, forget, delete, retry, and accessibility states.
8. Add injected failure/cancellation/restart fixtures and a clean-profile runtime path.
9. Run the smallest relevant tests, then build/test/runtime evidence under one recorded source revision, environment, and evidence scope.
10. Append evidence to the canonical handoff only after owner review; do not label M1 `verified` from this plan.

### Preconditions

- M0 migration/recovery contract is implemented and freshly evidenced, or the capture-attempt-dependent work remains blocked.
- Honeycomb/EventLedger paths are available and their degradation behavior is observable.
- A non-private clean profile and a synthetic fixture corpus are available for runtime evidence.
- The owner has confirmed the actual current source symbols and no unrelated user changes will be overwritten.

### Stop conditions

Stop and leave the slice `blocked` or `unavailable` when:

- private data could enter any durable/audit/model-context path;
- a failed lookup is treated as a cache miss;
- a duplicate is presented as new;
- an audit failure is presented as complete;
- HotMemory can be warmed while context is disabled or scope is unknown;
- a new store/ledger/authority is required;
- navigation, tabs, private mode, or ordinary rendering becomes unavailable;
- evidence lacks source revision, environment, scope, observed result, or limitation;
- a test/fixture/mock is being used as user-observable runtime proof.

### Rollback/deletion scope

M45 authorizes no runtime mutation. The future implementation must define rollback before execution: logical deletion/reconciliation of synthetic nodes and attempts, removal of FTS/edges/HotMemory entries through canonical owners, and no promise of forensic disk erasure. Private fixtures must prove zero durable/audit writes rather than rely on cleanup after the fact.

## 9. Deterministic fixture and evidence matrix

All fixtures are synthetic, local, bounded, and free of real browsing history, credentials, private URLs, raw DOM, screenshots, or user content. Fixture definitions are not results. Each result binds `trace_id`, `source_revision`, `environment`, `evidence_scope`, `evidence_kind`, observed output, limitation, owner, and timestamp.

### 9.1 Fifty fixtures

| IDs | Fixture family | Required assertion |
|---|---|---|
| M45-01–05 | normal new page | Valid HTTPS metadata creates one Source with honest content class, scope, and audit completion |
| M45-06–10 | duplicate/reuse | Repeated page and repeated note reuse the node, return duplicate explicitly, and create idempotent audit evidence |
| M45-11–15 | URL/title identity | Query, fragment, host casing, title change, and canonicalizer-version behavior are explicit and reproducible |
| M45-16–20 | private/no-write | Private page, private note, private project, private title, and private failure leave zero durable/audit/HotMemory rows |
| M45-21–25 | storage failures | Dedup read, node insert, FTS update, delete, and degraded-store open fail without false success or browser shutdown |
| M45-26–30 | audit failures | Ledger unavailable, conflicting stable event, retry, restart with pending, and restart with incomplete remain visible and excluded from model context |
| M45-31–35 | scope/context | Swarm disabled, context disallowed, profile mismatch, workspace mismatch, and unknown scope never widen admission |
| M45-36–40 | cancellation/restart | Cancel before write, cancel after node write, stale callback, process restart, and duplicate retry produce no contradictory result |
| M45-41–45 | inspection/lifecycle | Inspect, metadata-only export, forget context, durable delete cascade, and failed delete preserve truthful state |
| M45-46–50 | browser/accessibility/safety | Offline loaded page, unavailable page, denied permission, hostile title/URL, and keyboard/reduced-motion status path remain usable and text-readable |

### 9.2 Evidence requirements

- **Unit/policy evidence:** exact test command, source revision, environment, fixture IDs, and result.
- **Store evidence:** database mode/profile, migration version, fixture IDs, row/edge/FTS counts, and limitation.
- **Runtime evidence:** clean non-private profile, exact navigation/capture/inspect/delete path, source revision, environment, evidence scope, observed UI result, and accessibility/manual fallback observations.
- **Negative evidence:** private/offline/denied/degraded paths must show the absence of prohibited writes, not merely an error string.
- **Freshness:** stale, conflicting, or scope-mismatched evidence is `blocked`, never current `verified` evidence.

## 10. Twelve M45 exit gates

| Gate | Requirement |
|---|---|
| M45-A | Actual source symbols, owners, M0 dependency, and missing seams are reconciled without status inflation. |
| M45-B | Typed result taxonomy distinguishes new, duplicate, partial, blocked, degraded, stale, and project-link partial outcomes. |
| M45-C | Page and note provenance is complete, scope-bound, metadata-only for pages, and content-class honest. |
| M45-D | Stable attempt/event identity is defined against the existing EventLedger `recordIfAbsent` owner. |
| M45-E | Honeycomb/EventLedger partial failure is visible, retryable, and never false success; no distributed-transaction claim is made. |
| M45-F | Pending, incomplete, and unknown attempts are excluded from every model-context/retrieval path until canonical reconciliation. |
| M45-G | HotMemory warming obeys explicit context consent and profile/workspace/project scope. |
| M45-H | Private mode proves zero durable, audit, HotMemory, search, export, history, and model writes. |
| M45-I | Offline, locked/unavailable, denied, cancellation, restart, and persistence-degraded fallbacks preserve ordinary browsing. |
| M45-J | Receipt, inspector, export, forget, delete, retry, keyboard, reduced-motion, and status/error behavior are explicit and text-readable. |
| M45-K | Fifty synthetic fixtures and evidence records bind source revision, environment, scope, observed result, limitation, and owner; fixtures are not results. |
| M45-L | A future owner’s fresh build/test/user-observable runtime evidence passes all relevant gates; only then may the implementation milestone decide whether M1 is `verified`. |

M45 itself can close only as a documentation handoff. It cannot close M1 runtime verification, compliance, security certification, accessibility conformance, production readiness, or a ship decision.

## 11. Research and overclaim boundaries

- Apple documents `WKWebView.evaluateJavaScript` as asynchronous and fallible; M45 therefore requires explicit error/cancellation handling and does not treat JavaScript evaluation as proof of page-body capture.
- Apple App Sandbox/file-access documentation supports container storage and explicit user-selected/security-scoped access; M45 does not authorize arbitrary filesystem reads.
- SQLite documents WAL as a local concurrency mode with one writer and connection-scoped foreign-key enforcement; M45 requires existing owners to configure and evidence these settings but does not claim they make Honeycomb and EventLedger atomic together.
- W3C WCAG 2.2 status/error guidance supports programmatically discoverable status and text error identification; M45 uses this as a design constraint, not as an accessibility certification.
- A local SQLite delete is logical product deletion, not proof of forensic erasure; that distinction remains visible in every receipt/export/plan.

## 12. Explicit deferrals

- Ambient/WISP capture, screen monitoring, screenshots, OCR, page-body extraction, PDFs, and DOM snapshots.
- Promise detection, daily digest, reinforcement, forgetting curves, and time-window deletion.
- Vectors, page diffs, research synthesis, model routing, model training, and remote providers.
- Import/migration and Brief generation.
- MCP, sync, SQLCipher, connectors, OS automation, and external notifications.
- New ledger/store/authority/governance layer.

**M45 is complete as a planning handoff only when the five work packages, 50 fixture mappings, 12 gates, owner boundaries, evidence identity requirements, and browser-first fallback are all present and structurally validated.**