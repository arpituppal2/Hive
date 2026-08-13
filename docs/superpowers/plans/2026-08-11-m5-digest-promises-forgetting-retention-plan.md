# Hive Memory Wedge M5 — Digest, Promises, Forgetting, and Retention

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Depends on:** M0 storage/migration/recovery, M1 explicit capture, M2 Brief credibility, M3 candidate-only WISP, M4 source versions/diffs/trails/hybrid retrieval
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Primary source specs:** `MORNING_BRIEF_SPEC.md`, `WISP_CAPTURE_SPEC.md`, `MEMORY_ARCHITECTURE_SPEC.md`, `HONEYCOMB_SPEC.md`
>
> M5 makes memory self-maintaining without making it self-authorizing. It adds a reviewable proposal layer for commitments and learned facts, a deterministic digest envelope, and explicit retention/deletion contracts. It does not add ambient authority, silent task creation, model-controlled promotion, or a claim of forensic erasure from ordinary SQLite deletion.

## 0. Scope and non-goals

### In scope

1. **Promise candidates:** detect possible commitments only from approved, user-authored writing surfaces; preserve exact evidence spans and source/version identity; resolve time expressions deterministically where possible.
2. **Approval-centered digest:** assemble a bounded, reproducible daily review from real candidates, retained sources, tasks, diffs/trails, and approved events; any model-generated prose is a rendering step over a fixed input manifest.
3. **Approval lifecycle:** accept, edit, deny, snooze, and expire proposals without conflating those actions with source deletion.
4. **Reinforcement and forgetting:** keep explicit importance, reinforcement, expiry, and user override state; apply retention only to eligible typed objects.
5. **Scoped purge:** define “Forget last 10 minutes” across every M5-owned store and derived index/cache, with restart reconciliation and honest deletion evidence.

### Out of scope

- Automatic promotion of a candidate into a Task, Claim, Preference, or durable Source.
- Reading arbitrary page text, screenshots, audio, or private/kill-list surfaces.
- Sending reminders, modifying calendars, or contacting another person without a separately approved action.
- A remote model as a required dependency.
- Claiming SSD/flash forensic erasure from `DELETE`, `VACUUM`, or WAL checkpoint alone.
- Changing existing Swift/runtime files as part of this planning slice.

## 1. Current code truth and authority order

Existing primitives are reusable but do not satisfy M5 on their own:

| Existing surface | Reusable contract | M5 gap |
|---|---|---|
| `HiveTask` / `TaskStore` | Typed `.task` node, open/in-progress/done/cancelled states, due date, source links, action inbox | No promise-candidate source, confirmation lineage, or immutable evidence span contract |
| `Brief` / `BriefStore` | Source-linked Markdown artifact and `references` edges | No versioned digest manifest, approval state, or deterministic item identity |
| `ProactiveBriefPlanner` | Pure deterministic planning and honest empty state | Inputs are generic memory items; no candidate/approval/forgetting model |
| `EventLedgerStore` | Append-only events, idempotent writes, consent action kinds, retention deletion | No dedicated proposal/digest/retention action taxonomy or purge journal |
| `RetentionCapability` | Signed, scoped, single-use authority for retention-class operations | Not a general memory lifecycle; M5 must reuse it only for privileged purge paths |
| M3 WISP candidate store | Candidate-only, bounded, deny-on-unknown, explicit Save promotion | M5 must not let digest approval bypass M1 promotion/audit rules |
| M4 versions/retrieval | Immutable source versions, temporal validity, deletion-aware indexes | M5 must filter stale/deleted/private/audit-incomplete inputs before assembly |

Precedence for implementation is: fresh source/tests → this M5 plan → M0–M4 detailed plans → active packaged specs → historical mega-plan. A product spec may describe a desired capability; it does not make an absent API verified.

## 2. Unified data contracts

M5 adds these planned records with one authoritative storage decision: they live in a dedicated schema-versioned SQLite lifecycle store at `Application Support/Hive/m5-lifecycle.sqlite3`. This is not a second memory graph or retrieval authority. It owns proposal/digest/approval/reinforcement/purge lifecycle state only; durable Sources, Claims, Tasks, Briefs, FTS, vectors, diffs, and edges remain owned by Honeycomb/M4, and audit events remain owned by EventLedger. The M5 store is a first-class M0 storage participant: its schema version, WAL/foreign-key/health state, snapshot manifest, recovery journal, write barrier, and restore reconciliation are included in the coordinator contract before M5 implementation. Its planned schema tables are `promise_candidates`, `learned_fact_proposals`, `digest_manifests`, `digest_items`, `approval_records`, `reinforcements`, `purge_journals`, and `purge_steps`; all rows carry stable IDs, provenance, timestamps, lifecycle state, and deletion scope. No other store may become an authoritative copy of these lifecycle records.

### 2.1 PromiseCandidate

```text
PromiseCandidate {
  id: stable candidate UUID
  source_id: retained Source or SourceVersion ID
  source_version_id: exact retained version, if available
  surface: approved_writing_surface enum
  actor: user | other | unknown
  evidence_span: {start_utf8, end_utf8, exact_text_hash}
  normalized_action: bounded string, never model authority
  target_text: optional bounded string
  due_expression: original text, optional
  due_at: optional Date
  due_resolution: exact | relative_to_source | ambiguous | missing
  confidence: deterministic score + rule reasons
  state: proposed | confirmed | edited | denied | snoozed | expired | converted | deleted
  created_at: Date
  updated_at: Date
  retention_class: candidate | confirmed_task_link
  provenance: capture/event identity
}
```

Rules:

- The candidate must retain an exact evidence span and source identity. A summary without a span is not eligible for approval.
- `normalized_action`, `actor`, and `due_at` are suggestions. They are never copied into a Task without the user’s confirmation or edit.
- Unknown actor, ambiguous date, quoted text, question form, negation, hypothetical language, hedge, or content outside an approved writing surface lowers eligibility or yields `needs_review`; it never becomes an automatic task.
- Candidate identity is deterministic over source version, evidence hash, surface, and normalized rule version. Reprocessing the same source creates no duplicate.
- Proposed candidates are excluded from default long-term retrieval except on the digest/review surface. Promotion is a separate M1-compatible operation.

### 2.2 DigestManifest and DigestItem

```text
DigestManifest {
  id: stable local ID for user + local calendar day + generation
  day_start: local calendar-day boundary
  input_cutoff: exact Date
  source_ids: sorted retained IDs
  candidate_ids: sorted proposed/confirmed IDs
  task_ids: sorted active task IDs
  event_ids: sorted eligible ledger IDs
  retrieval_generation: M4 vector/lexical generation identifiers
  policy_snapshot_hash: privacy + retention + scope rules
  renderer: deterministic | local_model(provider/model) | unavailable
  content_hash: hash of canonical manifest
  state: assembled | shown | partially_reviewed | completed | superseded | deleted
}

DigestItem {
  id: stable hash(manifest_id + item_kind + target_id)
  kind: promise | changed_source | open_task | episode | learned_fact_proposal
  target_id: source/candidate/task/claim ID
  evidence_ids: exact source/version/event IDs
  provenance_label: short user-visible origin
  proposal_text: bounded and attributable
  action_set: review | approve | edit | deny | snooze | open_source | forget
  state: pending | approved | edited | denied | snoozed | withdrawn | deleted
}
```

The manifest is the reproducibility boundary. A renderer may phrase a digest item, but it may not add an item, source, date, fact, or action absent from the manifest. If the local model is unavailable, render structured deterministic text or an honest unavailable state; never fabricate a successful summary.

### 2.3 ApprovalRecord, LearnedFactProposal, and Reinforcement

```text
LearnedFactProposal {
  id: stable proposal ID
  source_id: retained Source or SourceVersion ID
  evidence_span: {start_utf8, end_utf8, exact_text_hash}
  proposed_type: preference | claim | entity_relation
  proposed_value: bounded typed value
  validity: {valid_from, valid_until?}
  extraction_rule_version: versioned deterministic/model-assisted rule identity
  state: proposed | approved | edited | denied | withdrawn | deleted
  provenance: capture/event/consolidation identity
}

ApprovalRecord {
  id: stable event ID
  proposal_id: candidate_or_digest_item ID
  proposal_kind: promise | learned_fact
  decision: approve | edit | deny | snooze | withdraw
  edited_fields: allow-listed field map, optional
  actor: user
  evidence_ids: unchanged source/version IDs
  timestamp: Date
  consent_event_id: EventLedger ID
}

Reinforcement {
  target_id: typed durable object ID
  signal: explicit_approval | explicit_pin | user_open | user_query | citation_use | dismissal | failed_search_rescue
  weight_delta: bounded deterministic value
  occurred_at: Date
  provenance_event_id: EventLedger ID
}
```

A `LearnedFactProposal` is review-only until explicit approval. Approval may create or update exactly one typed Claim/Preference/Entity relation through the same durable audit boundary used by Task promotion; it must preserve the original evidence span, validity window, source/version IDs, and proposal lineage. Editing changes only allow-listed proposed fields and never changes the evidence. Denial/withdrawal prevents promotion and blocks immediate resurfacing. Deleting the source or proposal cascades to the derived Claim/Preference unless the user explicitly retains the derived object with a new provenance decision.

Approval is authoritative only for the fields the user approved or edited. Dismissal is a UI suppression and negative signal; it is not deletion. Denial of a proposed fact prevents promotion and records a negative decision; it does not erase the source unless the user chooses Forget/Delete.

## 3. Promise detection contract

### 3.1 Input boundary

The detector runs only on an allow-listed writing-surface class established by native metadata: user-authored notes, drafts, mail/message composition surfaces, and explicitly enabled text editors. It does not run on arbitrary web pages, ads, AI chats, password managers, banking, private windows, screenshots, or speech unless a future contract explicitly opts in. Unknown surface classification is deny/skip.

The detector receives normalized text plus metadata and returns structured candidates. It must not receive credentials, full browser history, or unrelated page context.

### 3.2 Deterministic rule stages

1. **Segmentation:** retain sentence/paragraph offsets and exact UTF-8 evidence.
2. **Speech-act gate:** require a first-person user commitment pattern or an explicit assignment accepted by the user. Questions, requests to another person, quoted text, conditionals, hypotheticals, negations, and marketing language are rejected or marked `needs_review`.
3. **Action extraction:** capture a bounded verb/object phrase; reject empty, purely social, or non-actionable text.
4. **Temporal extraction:** parse only supported absolute and relative forms (`today`, `tomorrow`, weekday, ISO/date-like forms, `by EOD`, `next week`) against the source timestamp and locale/time zone. Unsupported or ambiguous expressions remain `due_resolution: ambiguous|missing`.
5. **Evidence and confidence:** emit rule reasons, exact span, source version, and confidence band. Confidence is a review-prioritization hint, not permission.
6. **Dedupe:** hash source-version/evidence/action rule identity; update the same candidate rather than create duplicates.

No candidate may be promoted because a model called it a promise. A model may assist with ranking or presentation only after deterministic extraction, and its output must remain subordinate to the evidence span and approval controller.

### 3.3 Candidate state machine

```text
not_seen
  → proposed
      ├─ approve → confirmed → M1 explicit task promotion → converted
      ├─ edit → edited → user confirms → confirmed
      ├─ deny → denied (terminal unless user reopens)
      ├─ snooze → snoozed → proposed at explicit future time
      ├─ expiry → expired
      └─ forget/delete → deleted
```

A `confirmed` candidate can create or link one `HiveTask` only after the M1 durable capture/audit boundary succeeds. If Honeycomb succeeds and the ledger/audit write fails, the result is inspectable but quarantined and cannot enter normal retrieval or claim success. Reprocessing is idempotent by candidate/task lineage.

### 3.4 Promise evaluation gates

M5 must ship a frozen, redacted fixture corpus with positive and hard-negative examples across writing surfaces, locales/time zones, questions, negation, hedging, quotations, copy/paste, dates, and repeated text. Report:

- candidate precision at the review threshold;
- recall on explicit first-person commitments;
- false-positive rate on questions, negations, quotes, hypotheticals, and non-writing surfaces separately;
- due-date exact-match and ambiguity rate;
- duplicate rate after replay;
- evidence-span exactness;
- user correction rate after approval.

M5 does not promise a universal NLP score. A release gate requires a locked threshold chosen from the fixture baseline, zero durable auto-promotion, and no privacy-boundary false positives.

## 4. Digest assembly and approval UX

### 4.1 Assembly algorithm

At a fixed local-calendar cutoff:

1. Acquire the M0 write barrier/epoch and read a consistent snapshot of candidate, Honeycomb, EventLedger, and M4 index generations.
2. Apply the shared privacy/admission predicate before ranking: exclude private, kill-list, unknown-policy, candidate-only outside review, audit-incomplete, deleted, expired, and out-of-scope records.
3. Select bounded inputs by deterministic category order: pending promises, due/overdue confirmed tasks, retained source changes, approved events, then learned-fact proposals.
4. Resolve evidence IDs to retained SourceVersion/Task/Event records; unresolved evidence makes the item unavailable, never invented.
5. Sort with explicit tie-breaks: category priority, due time or observed time, stable ID. Apply per-category and total caps.
6. Persist the canonical manifest before rendering. A shown digest always has a manifest hash.
7. Render deterministic text or an explicitly labeled local-model rendering from only the manifest. Store renderer/provider and model realness honestly.

The digest is a review queue, not a hidden write queue. Opening it does not approve anything. Each item’s provenance and evidence affordance are visible; the full text is progressive disclosure.

### 4.2 UX states

- **No items:** show a quiet, useful empty state; do not imply that Hive watched or learned nothing.
- **Pending:** item awaits review; no durable promotion.
- **Approved/edited:** show the resulting Task/Claim and its source link.
- **Denied:** remove from the active digest and keep the denial record needed to avoid immediate resurfacing.
- **Snoozed:** suppress until the exact local time or next explicit review window.
- **Unavailable:** explain missing/deleted/insufficient evidence; never fill the gap with generated prose.
- **Partially reviewed:** preserve per-item decisions and allow resume after restart.

Digest approval must be available from the browser surface and a structured Memory page. A natural-language “what do you know?” view may query approved state, but it cannot bypass the same approval/deletion semantics.

### 4.3 Scheduling and platform limits

A digest schedule is best-effort local scheduling, not a runtime guarantee. On macOS, use a visible local launch/scheduling path and `UserNotifications` only after notification permission; check authorization before scheduling and show a recoverable disabled state. EventKit is optional and separate from the digest. If the app was not running at the nominal time, assemble on next launch with a recorded actual cutoff and do not pretend it ran in the background.

## 5. Retention, reinforcement, and forgetting

### 5.1 Eligibility classes

| Class | Default behavior | Can be reinforced? | Can appear in normal retrieval? |
|---|---|---:|---:|
| Candidate/proposal | bounded short retention; review-only | yes, as a suggestion signal | no |
| User-approved Source/Claim/Task | governed durable retention | yes | yes if current/in-scope |
| Denied proposal | retain minimal negative decision until dedupe window expires | no | no |
| Dismissed digest item | suppress item instance; source remains | negative signal | source may remain |
| Forgotten/deleted object | cascade/tombstone per store policy | no | no |
| Pinned user object | exempt from automatic expiry until unpinned | yes | yes if scope allows |

M5 uses the existing six-month importance-based decay as a product default only after measuring storage and usefulness. It must be configurable, visible, and never overwrite a user-pinned or legally/explicitly retained object. Decay is not deletion: an expired object is excluded from normal retrieval before physical purge.

### 5.2 Reinforcement rules

- Explicit approve/edit/pin is the strongest positive signal.
- A user query/open/citation may increase a bounded local score, but cannot silently convert a candidate or alter factual content.
- Failed searches may rescue an eligible durable item into a review suggestion; rescue never bypasses privacy, temporal validity, or deletion.
- Dismissal decreases resurfacing priority for the same digest identity; repeated dismissals may propose a setting change, not silently delete.
- Every reinforcement is idempotent by event ID and carries the target object’s provenance.

### 5.3 “Forget last 10 minutes” contract

The action accepts an explicit invocation time and optional profile/workspace scope. It computes `[invocationTime - 10m, invocationTime]` using stored timestamps, then creates a durable purge journal **before** deleting. The journal is an M0 storage participant and is included in the same coordinator-owned snapshot epoch:

```text
PurgeJournal {
  purge_id: stable UUID
  requested_at: Date
  window_start: Date
  window_end: Date
  profile_id: optional stable profile ID
  workspace_id: optional stable workspace ID
  policy_snapshot_hash: hash of privacy/scope rules
  target_manifest_hash: hash of sorted object IDs and generation IDs
  state: requested | planned | executing | completed | partial_needs_repair | blocked_storage | cancelled_before_commit
  current_step: ordered step ID
  created_at: Date
  updated_at: Date
}

PurgeStep {
  purge_id: UUID
  step_id: candidates | sources | derived_indexes | digest_state | derived_objects | ledger_metadata | reconcile
  store_name: exact M0 participant/adapter name
  target_ids_hash: hash of sorted IDs, never raw private text
  expected_generation: optional M4/index generation
  state: pending | executing | committed | skipped | failed | needs_reconcile
  affected_count: optional Int
  error_code: optional stable redacted code
  committed_at: optional Date
}
```

The coordinator owns the order and admission barrier:

1. `requested`: validate scope and create the journal in the authoritative M5 lifecycle store.
2. `planned`: enumerate immutable target IDs and expected store/index generations; no timestamp re-query is allowed during repair.
3. `executing`: pause new memory writes, flush pending work, and mark one step `executing` at a time.
4. Commit steps in dependency order: (a) mark the `PurgeJournal` and all `PurgeStep` rows as executing and retain them outside the deletion target set; (b) delete M5 lifecycle proposals/digest/approval/reinforcement rows while preserving the active purge journal/steps; (c) WISP candidates/tombstones; (d) M1 durable captures/source versions; (e) M4 diffs, vectors, FTS, retrieval caches, and trail edges; (f) Task/Claim/Brief derived objects only when their provenance is entirely inside scope, otherwise detach evidence and mark `evidence_deleted`; (g) minimal eligible ledger metadata while preserving the deletion event; (h) reconcile every adapter, then mark the purge steps and journal `committed`/`completed` only after all postconditions pass. Purge-journal and purge-step rows are never deleted by the purge they coordinate; their separate retention policy is evaluated only after completion and recovery evidence is durable.
5. `reconcile`: query the M5 lifecycle adapter plus every Honeycomb/EventLedger/WISP/M4 adapter by the journal’s target IDs and expected generation markers. A step is `committed` only when its postcondition is observed; absent/unknown postconditions are `needs_reconcile`.
6. Resume/restart: continue from the first non-committed step using the retained journal/step rows; never repeat consent, reselect targets by wall-clock time, or infer success from counts alone.
7. `completed`: allowed only when every required step is `committed` or explicitly `skipped` with a recorded reason and no affected ID is retrievable.

The purge is crash-resumable and idempotent because each adapter accepts `(purge_id, step_id, target_ids_hash)` and records its postcondition. A crash after a store commit leaves that step `committed` or `needs_reconcile`; it cannot be reported as complete until reconciliation. Unknown or non-reconcilable state fails closed and remains visible in Privacy/Memory settings.

It must not claim that SQLite deletion, FTS maintenance, WAL checkpoint, or `VACUUM` guarantees physical SSD erasure. If SQLCipher/crypto-shredding is later selected, that is a separate M6 decision and evidence gate.

### 5.4 Deletion matrix

| Data | Delete action | Derived cleanup | Evidence |
|---|---|---|---|
| Candidate | delete/tombstone | candidate indexes/cache | candidate ID + purge journal |
| SourceVersion | delete by version/source scope | diffs, vectors, FTS, trails | source/version IDs |
| Approved Claim/Task | delete or detach evidence | retrieval/index/cache | object ID + user choice |
| Digest item | withdraw/delete item | manifest regeneration | manifest/item ID |
| Approval/reinforcement | delete scoped record where policy permits | score rebuild | event ID, no raw text |
| EventLedger | retention-prune only | none; preserve minimal purge evidence | deletion event |

## 6. Failure matrix

| Failure | Required behavior | Must not claim |
|---|---|---|
| Surface classification unknown | no detector, no candidate | safe capture |
| Date ambiguous | candidate lacks due date and asks for edit | exact reminder |
| Evidence source deleted | item unavailable; no generated replacement | remembered fact |
| Candidate store unavailable | digest omits candidates and shows degraded state | complete digest |
| Ledger unavailable | no approval promotion or purge completion claim | audited success |
| Honeycomb write fails | keep proposal pending/retryable | created Task |
| Partial multi-store purge | journal remains repairable; retrieval blocks affected IDs | fully forgotten |
| Notification permission denied | in-app next-launch digest remains available | scheduled notification |
| App absent at nominal time | assemble on next launch with actual cutoff | background execution |
| Local model unavailable | deterministic renderer or honest unavailable state | model-generated summary |
| Crash during consolidation | rerun from manifest/source IDs idempotently | duplicate episode |
| Private/kill-list data appears | reject and do not retain raw payload | privacy-safe capture |

## 7. Tests and acceptance gates

### 7.1 Unit and fixture tests

- LearnedFactProposal preserves evidence/source/version lineage; approve/edit creates exactly one typed Claim/Preference/Entity relation through the durable audit boundary; deny/withdraw/delete never leaves a retrievable derived object.
- PurgeJournal and PurgeStep persist before writes and remain retained through final reconciliation; restart at every step resumes by IDs and generation markers, never by reselecting the time window; completion requires postcondition reconciliation.
- Candidate parser emits exact UTF-8 evidence spans and stable IDs.
- Questions, negations, hedges, quotations, hypotheticals, ads, AI chats, private windows, kill-list hosts, and unknown surfaces produce no durable candidate.
- Absolute/relative date fixtures pin locale, time zone, DST boundary, ambiguous weekday, and missing-date behavior.
- Replay is idempotent; candidate edits preserve original evidence and lineage.
- Digest manifest is byte-stable for identical snapshot inputs and changes generation when any input/deletion policy changes.
- Item caps, category order, tie-breaks, and provenance labels are deterministic.
- Approval/deny/edit/snooze/withdraw survive restart and append one idempotent consent event.
- Approved candidate creates exactly one linked Task through the M1 audit boundary.
- Denied candidates do not immediately resurface; denied source content remains independently deletable.
- Reinforcement is bounded, idempotent, and cannot promote candidates.
- Decay excludes expired records before ranking; pinned records survive expiry; forgotten records never rank.
- Purge fixtures cover every store and derived index, crash/restart at each phase, partial storage failure, repair, and no-ghost retrieval.

### 7.2 Integration and browser gates

M5 closes only when a clean profile demonstrates:

1. A commitment typed on an approved writing surface appears as a candidate with evidence and no task yet.
2. The user edits/approves it; exactly one linked Task appears with a truthful due-date state.
3. A digest contains only real, in-scope, non-private items with provenance and resumable per-item decisions.
4. A denied/forgotten item does not return through FTS, vectors, diffs, cache, brief, or MCP-preparation paths.
5. Restart during approval, consolidation, and purge recovers to a visible consistent state.
6. The browser remains usable with memory/Swarm disabled, and no model/network permission is required for the deterministic path.

### 7.3 Exit gate M5

M5 is complete only when:

- the frozen promise corpus meets its locked precision/recall/false-positive/evidence-span gates;
- zero automatic promotion is observed across replay and adversarial fixtures;
- digest manifests are reproducible, bounded, provenance-linked, and honest about renderer availability;
- approval decisions are durable, resumable, and ledger-audited;
- retention/forgetting is typed, visible, configurable, and deletion-aware;
- the 10-minute purge is crash-resumable across candidates, sources, versions, diffs, vectors, FTS, trails, digest state, caches, and eligible ledger metadata;
- no deleted/private/unknown/audit-incomplete record is retrievable after restart;
- secure-erasure claims remain explicitly bounded until M6 encryption evidence exists.

## 8. Implementation order and stop conditions

### Task M5-A — Promise candidate substrate

Create the M5 lifecycle store migration and M0 participant registration first. Then create the versioned candidate schema, approved-surface classifier boundary, deterministic parser, temporal resolver, evidence-span model, dedupe, and fixture corpus. Do not add digest UI or Task conversion until candidate replay and privacy gates pass.

### Task M5-B — Approval and Task lineage

Add proposal state transitions, consent ledger identity, edit semantics, and an M1-compatible promotion adapter. Do not let the UI call `TaskStore.createTask` directly from model or parser output.

### Task M5-C — Digest manifest and renderer

Add fixed-snapshot assembly, manifest persistence, bounded item schemas, deterministic renderer, local-model renderer adapter, and resumable approval UI. Do not schedule notifications before in-app next-launch semantics work.

### Task M5-D — Retention and reinforcement

Add typed reinforcement/decay state and deterministic eligibility filters. Do not use a black-box learned forgetting curve; any learned local score is bounded, inspectable, and subordinate to explicit user overrides.

### Task M5-E — Scoped purge and recovery

Add the versioned `PurgeJournal`/`PurgeStep` schema in the authoritative M5 lifecycle store, M0 write-barrier and snapshot participation for `m5-lifecycle.sqlite3`, ordered store adapters, target-ID/generation postconditions, derived-index invalidation, restart reconciliation, and no-ghost retrieval tests. Do not claim physical erasure or mark the gate complete if any required store is unreconciled.

### M5 implementation stop conditions

- Stop before code if M0 recovery/write-barrier participation is not available.
- Stop promotion if the EventLedger decision cannot be durably recorded.
- Stop retrieval if source/version, privacy, audit, or deletion admission is unknown.
- Stop purge completion if any dependent store or generation marker cannot be reconciled.
- Keep the browser path available and truthful under all memory failures.
