# Hive M13 — Projects & Tasks

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M13 Projects & tasks
> **Depends on:** M0 storage/recovery, M1 explicit capture, M2 Brief credibility, M3 candidate-only WISP, M4 source versions/diffs/trails/retrieval, M5 digest/retention, M6 read-only MCP/encryption decision, M10 Sidecar B1–B4, M11 Studio loop, M12 Command Center
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Related contracts:** `docs/superpowers/plans/2026-08-11-m2b-brief-credibility-plan.md`, `docs/superpowers/plans/2026-08-11-m4-diffs-trails-hybrid-retrieval-plan.md`, `docs/superpowers/plans/2026-08-11-m5-digest-promises-forgetting-retention-plan.md`, `docs/superpowers/plans/2026-08-11-m10-sidecar-b1-b4-plan.md`, `docs/superpowers/plans/2026-08-11-m12-command-center-plan.md`
> **Primary code seams:** `Sources/HiveCore/Browser/Project.swift`, `Sources/HiveCore/Honeycomb/ProjectStore.swift`, `Sources/HiveCore/Honeycomb/TaskStore.swift`, `Sources/HiveCore/Browser/Brief.swift`, `Sources/HiveCore/Honeycomb/BriefStore.swift`, `Sources/HiveCore/Browser/ProactiveBriefPlanner.swift`, `Sources/HiveCore/Honeycomb/HoneycombStore.swift`
>
> M13 turns retained knowledge into reviewable work. It does not create a generic task-management silo. A source-backed Brief can suggest a project outcome and next actions; the user reviews and explicitly promotes them; tasks retain source/brief provenance, live inside a project, respect dependencies and privacy scope, appear in a deterministic action inbox, and can be completed, cancelled, exported, restored, or deleted without losing the evidence that produced them.

## 0. Decision summary

M13 delivers one coherent workflow:

```text
retained Brief / source evidence
  → extract bounded next-action candidates
    → user reviews proposal and provenance
      → create or select Project
        → promote selected candidates to Tasks
          → link source/brief evidence
            → set explicit state, priority, due date, and dependencies
              → surface unblocked work in Action Inbox
                → complete / cancel / defer / edit
                  → review provenance and audit trail
                    → export, restore, or delete by explicit scope
```

| Slice | User value | Hard boundary |
|---|---|---|
| **P1 — Shared project/task graph** | See work, evidence, briefs, and sources as one connected system | Honeycomb owns current object state; typed edges are the relation authority |
| **P2 — Brief-to-work promotion** | Turn a useful brief into concrete next actions without surprise task creation | AI/model output is a proposal; only explicit user confirmation creates an authoritative Project or Task |
| **P3 — Lifecycle and action inbox** | Know what is open, blocked, overdue, next, done, or cancelled | State transitions are typed, validated, idempotent, and auditable; blocked is derived from dependencies |
| **P4 — Time and dependencies** | Make deadlines and prerequisites trustworthy | Instants/timezones are explicit; dependency cycles are rejected; recurrence and notifications are deferred |
| **P5 — Provenance, deletion, and export** | Keep work explainable and portable | Source/Brief evidence survives task edits; deletion/restore is scoped, reversible where possible, and audited |

M13 is not a full Things/Linear/Notion replacement. It does not add team collaboration, cycles/sprints, recurrence, calendar synchronization, push notifications, assignees, permissions for multiple users, autonomous task mutation, or arbitrary AI-written project state.

## 1. Current code truth

The repository already contains useful Honeycomb primitives but not a verified brief-to-task journey.

| Existing surface | Current evidence/reuse | M13 gap or qualification |
|---|---|---|
| `Project` | Codable project object with title, purpose, active/archived lifecycle, provenance, Honeycomb conversion | Needs explicit ownership/scope, promotion lineage, revision/deletion state, and stable project creation/update events |
| `ProjectStore` | Project CRUD, FTS search, `belongsTo` task membership, project task query, Markdown export | Membership and deletion semantics need transactional promotion, restore/tombstone policy, deterministic ordering, and source/brief relation queries |
| `HiveTask` / `TaskStore` | Task states, priorities, due date, source IDs, action inbox, `references`, `dependsOn`, blocked-task query, Markdown project export | Needs canonical transition rules, source/brief/project lineage, idempotent promotion, cycle detection, timezone contract, derived inbox views, and audit authority |
| `Brief` / `BriefStore` | Durable Markdown brief, source IDs, `references` edges, editable/exportable source-linked artifact | Needs bounded next-action proposal contract and a typed bridge to user-confirmed Project/Task promotion |
| `ProactiveBriefPlanner` | Deterministic brief sections from bounded memory/calendar inputs; honest empty fallbacks | It does not yet create task proposals and must not be expanded into silent task creation |
| Honeycomb nodes/edges | Typed `.project`, `.task`, `.brief`, `.source`, `.claim` nodes and relations including `belongsTo`, `references`, `dependsOn`, `nextAction` | M13 must define relation direction, uniqueness, cycle checks, deletion behavior, and query authority for project views |
| `HotMemoryStore` | Project/workspace/profile context isolation and project-scoped retrieval seams | Must not treat task/project visibility as a reason to admit private, candidate, forgotten, deleted, or audit-incomplete source data |
| `EventLedgerStore` | Append-only consent/action/audit authority | M13 must define promotion, transition, dependency, due-date, deletion, restore, export, and AI-proposal event taxonomy |
| Existing tests | Project isolation, memory lifecycle, briefs, sources, dependency/task primitives, and planner tests exist | No verified compound flow proves proposal review → project/task creation → source lineage → inbox → done → export/delete |

**Not verified:** a user can open a retained Brief, inspect a proposed next action, explicitly promote it into a selected/new Project, see its retained evidence, manage dependencies and due dates, complete it, and recover/export/delete it with fresh ledger evidence. Existing CRUD or edge methods do not prove this journey.

## 2. Product contract

### 2.1 Browser-first and progressive disclosure

- Projects and Tasks are discovered from a Brief, Command Center, Knowledge view, or explicit project action; the browser does not launch into an empty task dashboard.
- A missing Honeycomb store, EventLedger, model, calendar, or notification capability leaves browsing and retained source inspection usable.
- Opening a project never implies that all browser history, private tabs, or current page contents enter the project. Only explicit retained objects and approved context are shown.
- A task can exist without a model. Model help may propose titles, grouping, dates, or next actions, but deterministic storage and user confirmation own creation and state.
- Closing a project panel does not delete tasks or change state. Destructive delete, archive, forget, and purge are separate, labeled operations.
- The default project view is an action-oriented work surface: project purpose, current tasks, blocked work, source evidence, and next actions—not a generic dashboard of every object.

### 2.2 User-visible vocabulary

```text
proposal          — model/deterministic suggestion; not authoritative work
needs_review      — proposal requires user decision
unassigned        — task has no project; visible in inbox but not silently filed
open              — actionable task not started
in_progress       — user has started the task
blocked           — derived: one or more prerequisites remain incomplete
scheduled         — has an explicit future due instant; still open
overdue           — due instant has passed while open/in progress
done              — user-confirmed completion
cancelled         — user-confirmed non-completion; retained for audit
archived          — project/task hidden from active defaults but retained
stale             — proposal/view computed against an older object generation
deleted           — user requested deletion; object is unavailable to normal retrieval
restorable        — deleted object remains in bounded recovery/undo window
purged            — deletion completed under retention policy; no normal restore
```

`blocked` and `overdue` are derived projections, not competing stored task states. A task cannot be both `done` and actionable, and a cancelled task cannot silently re-enter the inbox.

## 3. P1 — Shared project/task graph

### 3.1 Canonical object model

M13 uses one Honeycomb graph for Projects, Tasks, Briefs, Sources, Claims, and Studio artifacts. It does not create a second task database or a UI-only project list.

```text
Project {
  project_id: stable ID
  title: bounded user-authored title
  purpose: bounded outcome statement
  lifecycle: active | archived
  scope: profile/workspace/project privacy scope
  provenance: user | promoted_from_brief | imported
  created_at / updated_at: Date
  generation: monotonic revision generation
  deletion_state: active | deleted | restorable | purged
}

Task {
  task_id: stable ID
  title: bounded actionable outcome
  notes: bounded user-editable detail
  state: open | in_progress | done | cancelled
  priority: low | medium | high
  project_id: Project ID?
  source_ids: retained Source IDs
  brief_ids: retained Brief IDs
  proposal_id: Proposal ID?
  due: DueSpec?
  dependency_ids: prerequisite Task IDs
  provenance: user | promoted_from_brief | imported | studio_result
  created_at / updated_at / completed_at / cancelled_at
  generation: monotonic revision generation
  deletion_state: active | deleted | restorable | purged
}

NextActionProposal {
  proposal_id: stable ID
  source_brief_id: Brief ID
  source_ids: retained Source IDs
  title: proposed action
  rationale: bounded explanation
  confidence: advisory only
  suggested_priority: low | medium | high?
  suggested_due: DueSpec?
  suggested_project_title: bounded suggestion?
  idempotency_key: stable source/brief/proposal hash
  state: candidate | accepted | rejected | expired | superseded
  created_at / updated_at
}
```

The current `HiveTask.Priority` implementation has a low/medium/high contract. M13 does not silently introduce `urgent`; a future priority expansion requires a schema/version decision and migration fixture.

### 3.2 Relation authority

M13 freezes these directed relations:

| Relation | Direction | Meaning | Cardinality/constraints |
|---|---|---|---|
| `belongsTo` | Task → Project | Task is filed in a project | At most one active project per task in M13 |
| `references` | Task → Source | Task evidence references a retained Source | Many-to-many; idempotent |
| `derivedFrom` | Task → Brief | Task was promoted from a Brief | Many-to-many; promotion lineage retained |
| `supports` | Claim → Task/Brief/Project | Claim supports an outcome or artifact | Many-to-many; source-backed only |
| `dependsOn` | Task → Task | Task requires prerequisite | No self-edge; no cycles; idempotent |
| `nextAction` | Brief → Proposal | Brief produced a reviewable proposal | Proposal is not a Task until promotion |
| `produces` | Task → Artifact/StudioRun | Completion may produce an artifact | Only when actual artifact exists |

A relation is not authoritative because it appears in a rendered card. The graph store and its transaction/revision rules are authoritative; UI caches are rebuildable projections.

### 3.3 Scope and visibility

Every project/task query carries profile/workspace/project scope and a memory admission revision:

```text
ProjectTaskScope {
  profile_id: stable ID
  workspace_id: stable ID?
  project_id: stable ID?
  include_archived: Bool
  include_deleted: Bool
  memory_revision: generation
  privacy_policy_revision: String
}
```

Rules:

- Deleted, forgotten, private, candidate, audit-incomplete, and unknown-legacy Sources cannot become task evidence merely because a task references their IDs.
- A task title/notes may be retained as user-authored data even when a source is deleted, but the UI labels the evidence as unavailable and never invents replacement provenance.
- Project switching invalidates stale task/project views and pending promotion proposals.
- Cross-profile/workspace promotion is blocked unless the user explicitly selects the destination and the source admission policy allows the retained objects.
- Generic search and M12 Command Center adapters use the same scope predicates; there is no hidden “all tasks” escape hatch.

## 4. P2 — Brief-to-project/task promotion

### 4.1 Proposal generation

A Brief may expose a bounded “next actions” section only when the action is grounded in retained Brief content and source evidence. Proposal generation can be deterministic, model-assisted, or unavailable; all paths use the same output contract.

```text
BriefActionExtraction {
  brief_id: Brief ID
  brief_generation: UInt64
  candidate_actions: [NextActionProposal]
  extraction_provider: deterministic | local_model | remote_opt_in | unavailable
  model_is_real_inference: Bool?
  source_evidence_ids: retained IDs
  extraction_revision: String
  state: ready | unavailable | blocked | stale
}
```

Requirements:

- Candidate titles are actionable outcomes (“Compare three local model runtimes”), not vague summaries (“Research”); the UI may show a rationale and evidence span.
- A proposal never changes Project or Task state. It can be dismissed, edited, accepted, or rejected.
- The proposal contains source/brief IDs and a stable idempotency key; it does not retain raw hidden prompts or unbounded Brief content in the task record.
- Prompt injection in Brief/source text cannot change destination project, priority, assignee, due date, permissions, or approval state.
- If source resolution is unavailable, the proposal may be shown as ungrounded/advisory but cannot be promoted until the user confirms the text and retention policy allows the lineage.
- Duplicate extraction of the same Brief generation returns the same candidate identity rather than creating duplicate candidates.

### 4.2 User promotion flow

```text
brief_open
  → request_next_actions
  → proposal_ready | unavailable | blocked | stale
  → user_reviews_proposal
  → edit_title/notes/project/date/priority? 
  → choose_existing_project | create_project_draft
  → confirm_promotion
  → validate_scope_and_generation
  → transactionally_create_or_link_project
  → transactionally_create_task
  → link_sources_and_brief_lineage
  → record_promotion_event
  → promoted | blocked | conflict | failed
```

The confirmation surface shows:

1. proposed task title and editable text;
2. selected/new project and purpose;
3. source/Brief provenance and unavailable evidence warnings;
4. state and priority;
5. due date/timezone interpretation, if any;
6. dependency changes, if any;
7. whether an existing task with the same idempotency key already exists;
8. undo/delete behavior;
9. model/provider label when model assistance was used.

A user may create a blank Project or Task directly from M12/M13 without a Brief. That path uses `provenance: user` and has no fake source lineage.

### 4.3 Promotion idempotency

Promotion is idempotent across retries and crashes:

```text
promotion_key = hash(
  brief_id,
  brief_generation,
  proposal_id,
  normalized_user_edited_title,
  destination_project_id,
  source_generation
)
```

The store records the promotion attempt before or atomically with the object/edge transaction according to the M0 storage contract. A retry returns the existing Project/Task IDs and does not duplicate them. If the user materially edits the title/project or accepts a newer Brief generation, the key changes and a new task may be intentional.

### 4.4 Project creation from a Brief

Creating a Project from a Brief is a user-reviewed proposal:

```text
ProjectPromotion {
  brief_id: Brief ID
  source_ids: retained IDs
  suggested_title: bounded
  suggested_purpose: bounded
  selected_title: bounded user-confirmed text
  selected_purpose: bounded user-confirmed text
  project_id: existing or newly created ID
  task_proposal_ids: selected candidates
  promotion_key: idempotency key
}
```

The Project retains `derivedFrom`/lineage metadata to the Brief without copying the entire Brief content into project metadata. A Brief can contribute to multiple Projects when the user explicitly chooses each destination; no automatic “move” semantics exist.

## 5. P3 — Task lifecycle and Action Inbox

### 5.1 Stored task state machine

```text
open
  → in_progress
  → done
  → open (explicit reopen)

open | in_progress
  → cancelled
  → open (explicit restore/reopen while retained)

any active state
  → deleted (explicit delete; audit/tombstone path)
```

Transition rules:

- Only an explicit user action or an approved typed action may transition a task to `done`, `cancelled`, `deleted`, or reopen it.
- A model may suggest a transition but cannot perform it without M10/M12 typed approval where the action is consequential.
- `done` records `completed_at`; reopening clears it and records the reason/event.
- `cancelled` records `cancelled_at`; it is not shown as active even if its due date passes.
- Editing title/notes/priority/due date/dependencies bumps task generation and records a revision/event.
- A task cannot be marked `done` while its own write/related artifact is still in an unknown or failed state unless the user explicitly confirms completion without artifact verification.
- State transitions are idempotent: repeating `done` on an already done task returns an already-in-state result, not a duplicate event or a new completion time.

### 5.2 Derived states

At query time, using one injected `now` and timezone:

```text
if state == done       → done
if state == cancelled  → cancelled
if unmet dependencies   → blocked
if due instant < now    → overdue
if due instant >= now   → scheduled
otherwise               → actionable
```

A task may be both `blocked` and `overdue`; the UI shows both labels and explains the prerequisite. Derived state is never persisted as a mutable duplicate that can drift from task/dependency truth.

### 5.3 Action Inbox contract

The Action Inbox is a deterministic projection over active tasks:

```text
ActionInboxQuery {
  scope: ProjectTaskScope
  now: Date
  timezone: IANA timezone
  filters: all | next | overdue | blocked | today | upcoming | unassigned
  limit: bounded integer
  generation: graph revision
}
```

Default ordering:

1. overdue and unblocked;
2. due today and unblocked;
3. active unblocked with due date ascending;
4. active unblocked without due date by priority high→medium→low;
5. blocked tasks grouped separately by earliest blocking prerequisite;
6. stable `updatedAt`, then task ID tie-breakers.

The existing `getActionInbox` overdue/priority query is a reusable primitive, but M13 must add dependency-aware filtering, fixed `now`, due-date tie-breakers, scope, and stable final ordering. A task does not disappear because it is blocked; it remains inspectable with the reason and prerequisite links.

### 5.4 Project view

A Project view contains:

- outcome/purpose and lifecycle;
- open/in-progress next actions;
- blocked tasks with prerequisite chain;
- overdue/today/upcoming sections;
- completed/cancelled history behind progressive disclosure;
- linked Briefs, Sources, Claims, and Studio artifacts;
- provenance and audit details;
- explicit export, archive, delete, and restore controls.

It does not claim a progress percentage unless the calculation is defined and based on a stable task set. M13 may show counts (`3 of 8 tasks done`) but must label the denominator and treatment of cancelled tasks.

## 6. P4 — Time, due dates, and dependencies

### 6.1 Due-date contract

M13 stores a due specification rather than treating a formatted display string as truth:

```text
DueSpec {
  instant_utc: Date
  source_timezone: IANA timezone identifier
  display_policy: absolute_instant | local_wall_time
  original_input: bounded user text?
  precision: date | minute
  confirmed: Bool
}
```

Rules:

- A date-only due date is a date in the user’s selected timezone, not midnight UTC rendered elsewhere.
- A time-bearing due date stores the resolved instant and source timezone. Display converts to the current user timezone with a clear local-time label.
- Relative phrases such as “next Tuesday at 3” require a reference `now`, timezone, and explicit confirmation before they become authoritative.
- Ambiguous abbreviations or missing timezone context remain `needs_review`; no silent default is used for a consequential reminder/date.
- Past due dates are allowed when explicitly entered; imports do not silently move them to today.
- M13 does not schedule OS notifications. Due dates are data and inbox projections; reminder delivery is a later capability.

### 6.2 Dependency contract

`dependsOn` means the source task cannot be considered unblocked until the target prerequisite is `done` or `cancelled` under the declared policy.

Required checks before adding an edge:

1. both IDs exist and are active tasks;
2. source and target are in a compatible scope;
3. no self-edge;
4. no duplicate edge;
5. adding the edge does not create a cycle;
6. user sees the dependency direction in preview;
7. the change is idempotently recorded.

Cycle detection is deterministic graph traversal from the proposed prerequisite back to the dependent task. A cycle is rejected before the edge write. Removing a dependency immediately recomputes blocked projections; it does not auto-start a task.

M13 supports direct dependencies only in the UI. Transitive blocked explanations may be shown as a bounded chain with a cycle-safe visited set.

### 6.3 No recurrence in M13

Recurrence is explicitly deferred. Do not approximate recurrence by auto-creating copies when a task is completed. A future recurrence contract must choose RFC 5545/`RRULE` semantics, timezone/floating-time behavior, missed-instance policy, idempotency, notification integration, and deletion/undo behavior before implementation.

## 7. P5 — Provenance, deletion, restore, and export

### 7.1 Provenance contract

Every promoted task retains:

```text
TaskProvenance {
  task_id: Task ID
  proposal_id: Proposal ID?
  source_brief_ids: retained Brief IDs
  source_ids: retained Source IDs
  source_generations: [ID + generation/hash]
  promotion_key: stable idempotency key
  actor: user | approved_model_action | import
  created_event_id: EventLedger ID
}
```

Task provenance is append-only lineage. Editing a task does not rewrite the source Brief or claim. If a source is later edited/deleted, the task remains but displays `evidence changed`, `evidence unavailable`, or `evidence purged` according to the retained generation.

A source citation is not inferred from a task title. A task with no retained evidence says “user-created” or “source unavailable”; it never displays a synthetic citation.

### 7.2 Deletion and restore

M13 reuses M0/M5 lifecycle authority:

```text
active
  → delete_requested
  → deleted/restorable
  → restored | purged
```

Rules:

- Deleting a Task removes it from active inbox/project views but preserves a tombstone, lineage identifiers, and EventLedger record during the retention window.
- Deleting a Project requires an explicit scope preview listing affected Tasks and relation edges. M13 default is archive rather than cascading deletion.
- If the user chooses cascade deletion, each Task deletion is individually represented in the transaction/result; source/brief nodes are not deleted merely because a task/project is deleted.
- Restore revalidates the destination scope, parent Project, dependencies, and source availability. Missing parents/edges become explicit repair choices.
- Purge follows M5 retention and deletion generations. After purge, normal retrieval cannot reconstruct the task or claim its old evidence exists.
- A deletion failure or partial cascade remains visible and retryable; no generic “deleted” toast is shown for unknown outcome.

### 7.3 Export contract

Project export is a versioned, deterministic bundle:

```text
HiveProjectExport v1 {
  manifest: schema/version/export timestamp
  project: project object
  tasks: task objects and states
  relations: belongsTo/dependsOn/references/derivedFrom
  provenance: source/brief IDs, generations, redacted metadata
  sources: optional retained metadata or explicit unavailable markers
  revisions: optional user-selected history
}
```

Markdown export remains human-readable; JSON export preserves IDs, states, timestamps, timezone metadata, and relations. Private/deleted source content is excluded or represented by a lifecycle marker. Export never claims to include content that was not retained or allowed by policy.

## 8. Audit and authority contract

### 8.1 Authority separation

```text
Brief/source evidence
  → proposal extractor (advisory)
    → user review/confirmation
      → Honeycomb project/task transaction
        → EventLedger promotion/transition evidence
          → inbox/project projections
```

- Honeycomb is authoritative for current Project, Task, Brief, Source, and typed-edge state.
- EventLedger is authoritative for consent, promotion intent, state transitions, deletion/restore/purge decisions, and operation outcomes.
- Search/index/cache/UI state is a rebuildable projection.
- The model is never authoritative for IDs, permissions, task state, deadlines, provenance, dependency direction, or deletion.

### 8.2 Event taxonomy

M13 records minimal stable events, without raw secrets or unbounded content:

```text
project.created / project.updated / project.archived / project.restored
proposal.created / proposal.accepted / proposal.rejected / proposal.expired
promotion.started / promotion.succeeded / promotion.replayed / promotion.blocked
 task.created / task.updated / task.started / task.completed / task.reopened
 task.cancelled / task.deleted / task.restored / task.purged
relation.added / relation.removed / relation.rejected_cycle
schedule.set / schedule.changed / schedule.cleared
export.started / export.succeeded / export.failed
```

Each event includes actor, scope, object IDs, generation, policy/reason, idempotency key where relevant, result state, and parent operation. It excludes raw Brief text, private source content, credentials, full task notes, and arbitrary model prompts by default.

### 8.3 Failure authority

If Honeycomb commits but EventLedger cannot record the event, the operation enters `audit_incomplete` and is excluded from model/action retrieval according to the shared M0/M1 admission rules until reconciliation. If EventLedger records intent but Honeycomb fails, the event records failure and no object is presented as created. If outcome is unknown after a crash, the object/operation is reconciled before retry; no duplicate promotion is assumed safe.

## 9. AI and prompt-injection boundary

Briefs, Sources, Claims, imported content, task notes, project instructions, and model output are untrusted data. They may propose work but cannot:

- create a Project or Task without explicit user confirmation;
- assign themselves ownership or permissions;
- alter priority, due date, dependency, lifecycle, or deletion state without a typed approved action;
- hide or delete source provenance;
- promote private/candidate/deleted evidence;
- create a dependency cycle;
- emit notifications or external messages;
- widen project/profile/workspace scope;
- mark a task done based only on text claiming success.

The promotion UI must distinguish “suggested by Swarm” from “created by you.” If model inference is unavailable or labeled mock, the proposal state and provider label remain honest; deterministic user-created tasks do not require model availability.

## 10. Accessibility and interaction contract

- Project creation, proposal review, project selection, task editing, due-date confirmation, dependency preview, completion, cancellation, delete, restore, export, and source inspection are keyboard reachable.
- Task state is conveyed semantically and not by color alone. “Blocked by X,” “overdue,” “done,” and “evidence unavailable” are accessible labels.
- The action inbox supports predictable arrow-key navigation, Enter/Space state actions, and a separate action menu for secondary operations.
- Inline editing has an explicit commit/cancel path; Escape never silently discards unsaved edits without a clear rule.
- Dependency dialogs show direction (“This task waits for…”) and focus the safe cancel path for destructive changes.
- Date/time controls announce timezone, precision, confirmation state, and ambiguity warnings.
- Project/task lists support dynamic type, high contrast, VoiceOver, reduced motion, and bounded live updates. Completing a task announces the new state once, not every projection refresh.
- Deletion/restore confirmations list scope and affected objects; focus returns to the originating row/panel after completion.
- Export progress and partial/failure states are accessible and do not claim success before the file/bundle exists.

## 11. Failure matrix

M13 requires deterministic synthetic Honeycomb graphs and no real credentials, notifications, remote network, or production user data.

| ID | Fixture | Required assertion |
|---|---|---|
| M13-1 | Empty Brief with no actions | No proposal/task invented; useful empty state |
| M13-2 | Brief with two source-backed actions | Two bounded proposals with source/Brief IDs and evidence state |
| M13-3 | Prompt injection in Brief/source text | Treated as data; cannot change project, priority, due date, or state |
| M13-4 | Model unavailable/mock-labeled | Deterministic fallback or honest unavailable; no fake proposal confidence |
| M13-5 | Proposal accepted without user confirmation | No Project/Task created |
| M13-6 | Proposal edited before promotion | Promotion key reflects edits; selected values become authoritative |
| M13-7 | Duplicate promotion request, five concurrent retries | Exactly one Project/Task lineage; retries return existing IDs |
| M13-8 | Brief generation changes after proposal | Proposal becomes stale; re-review required |
| M13-9 | Cross-profile/workspace promotion | Blocked until explicit destination and admission pass |
| M13-10 | Candidate/private/deleted Source in proposal | Evidence withheld; task cannot claim grounded provenance |
| M13-11 | Existing Project selected | Task links once via `belongsTo`; no duplicate edge |
| M13-12 | New Project draft cancelled | No Project or Task persisted |
| M13-13 | Invalid/empty task title | Promotion blocked; no placeholder task |
| M13-14 | State transition open→done repeated | Idempotent already-done result; one completion lineage |
| M13-15 | Cancelled task queried in inbox | Not actionable; remains in history |
| M13-16 | Reopen done task | Explicit transition, completion time cleared/recorded, inbox re-entry |
| M13-17 | Dependency self-edge | Rejected before write |
| M13-18 | Dependency duplicate edge | No duplicate; stable existing relation returned |
| M13-19 | Dependency cycle | Rejected deterministically; graph unchanged |
| M13-20 | Dependency blocks task | Task remains visible with prerequisite explanation and blocked projection |
| M13-21 | Prerequisite completed/cancelled | Blocked projection recomputes; task does not auto-start |
| M13-22 | Due date “next Tuesday at 3” without timezone | Needs confirmation; no authoritative schedule |
| M13-23 | Due date across DST boundary | Stored instant/display timezone remain correct |
| M13-24 | Date-only due date in non-UTC timezone | Day semantics preserved; no UTC midnight shift |
| M13-25 | Past due date explicitly entered | Preserved and shown overdue; not silently moved |
| M13-26 | Recurrence request | Explicitly unsupported/deferred; no duplicate task generation |
| M13-27 | Inbox ordering ties | Fixed `now`, due date, priority, updatedAt, and ID yield stable order |
| M13-28 | Project scope switch while inbox open | Old view invalidated; no cross-project leakage |
| M13-29 | Task source deleted after creation | Task remains with unavailable evidence marker; no synthetic citation |
| M13-30 | Project archive | Removed from active default; tasks remain queryable by explicit scope |
| M13-31 | Project delete preview | Affected tasks/edges listed; default archive remains non-destructive |
| M13-32 | Partial task/project delete | Typed partial failure; retryable; no false success |
| M13-33 | Restore missing parent/dependency | Repair choice required; no orphan silently reattached |
| M13-34 | Purged source/task | Normal retrieval excludes it; old evidence not claimed as live |
| M13-35 | Export with private/deleted source | Content excluded/marked unavailable; IDs and lifecycle preserved |
| M13-36 | Export interrupted | Partial file not reported complete; retry safe |
| M13-37 | Honeycomb commit/EventLedger failure | Audit-incomplete/reconciliation state; no unsupported verified object |
| M13-38 | Crash after promotion transaction | Restart reconciliation prevents duplicate Project/Task |
| M13-39 | Model claims task completed but native state open | Native task state wins; no completion event |
| M13-40 | Notification capability absent | Due date/inbox still work; no fake reminder sent |
| M13-41 | Keyboard-only project/task journey | Create, promote, edit, complete, block, export, delete/restore all work |
| M13-42 | VoiceOver/dynamic type/reduced motion/high contrast | State, provenance, dates, and actions remain operable |

The fixture matrix contains **42 cases**. New cases require an update to this plan and the progress mirrors.

## 12. Work packages after approval

### M13-A — Canonical Project/Task schema and graph relations

- Freeze Project, Task, NextActionProposal, DueSpec, provenance, deletion, generation, and relation schemas.
- Reuse Honeycomb typed nodes/edges and M0 migration/recovery authority; do not create a parallel task database.
- Add relation direction/cardinality/cycle contracts and deterministic project/task query views.
- Add schema, edge, scope, deletion, and revision fixtures.

### M13-B — Brief next-action proposals and explicit promotion

- Define deterministic/model-assisted extraction output with honest provider state and retained source evidence.
- Add review/edit/select/create-project flow with explicit confirmation and stable promotion idempotency.
- Make duplicate retries, stale Brief generations, cross-scope promotion, and EventLedger ordering fail closed.
- Keep proposals non-authoritative until promotion.

### M13-C — Lifecycle, action inbox, and project views

- Freeze task transition rules, derived blocked/overdue/scheduled states, inbox filters/order, and project summary semantics.
- Reuse `TaskStore.getActionInbox` as a starting primitive but add scope, dependency, due-date, and stable tie-break contracts.
- Add explicit complete/reopen/cancel/archive actions and truthful receipts through M12/M10 approval where needed.
- Add keyboard/accessibility and degraded-store behavior.

### M13-D — Time and dependency integrity

- Freeze DueSpec instant/timezone/precision/confirmation semantics and reject ambiguous dates until confirmed.
- Add cycle-safe dependency insertion/removal, bounded transitive explanations, and recomputed blocked projections.
- Keep recurrence, notifications, EventKit, calendar sync, assignees, and collaboration deferred.
- Add DST, timezone, cycle, stale-generation, and inbox-order fixtures.

### M13-E — Provenance, deletion/restore, export, and clean-profile validation

- Link promoted tasks to Brief/Source generations and expose unavailable/purged evidence honestly.
- Define tombstone/restorable/purge behavior through M0/M5 lifecycle authority; default Project delete to archive.
- Add deterministic Markdown/JSON export with relation and lifecycle metadata.
- Run the compound clean-profile path: open Brief → review proposal → promote → inspect source lineage → manage dependency/date → complete → export → restore/delete.
- Record fresh evidence before changing any capability label to verified.

## 13. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M13-A | Project, Task, Brief, Source, Proposal, DueSpec, provenance, deletion, and relation schemas are versioned and share Honeycomb authority | schema/migration/graph tests |
| M13-B | Brief next-actions are bounded proposals; explicit user confirmation is required for authoritative Project/Task creation | proposal/promotion UI and integration tests |
| M13-C | Promotion is idempotent across retries/crashes and records source/Brief lineage | concurrency/idempotency/EventLedger fixtures |
| M13-D | Task lifecycle transitions are typed, valid, idempotent, and auditable | transition/state tests |
| M13-E | Action Inbox is scope-safe, dependency-aware, deterministic, and honest about overdue/blocked work | query/order fixtures + clean-profile path |
| M13-F | Due dates preserve explicit instant/timezone/precision and ambiguous input requires confirmation | timezone/DST tests |
| M13-G | Dependency cycles/self-edges/duplicates are rejected; blocked projections recompute correctly | graph integrity tests |
| M13-H | Project/task/source/brief views never leak private/candidate/deleted/audit-incomplete evidence | admission/privacy fixtures |
| M13-I | Archive/delete/restore/purge behavior is explicit, scoped, reversible where promised, and never silently cascades | lifecycle/recovery tests |
| M13-J | Markdown/JSON export preserves user-visible work, IDs, relations, provenance, timestamps, and lifecycle markers | round-trip/export tests |
| M13-K | EventLedger is complete before verified promotion/transition/deletion claims; audit failures reconcile visibly | audit/recovery tests |
| M13-L | Keyboard, VoiceOver, reduced motion, dynamic type, high contrast, degraded store/model, and clean-profile paths work | accessibility/manual evidence |

M13 is **verified** only when all 12 gates pass with fresh build/test/runtime evidence and the full Brief→Project→Task→Inbox→Done→Export/Delete journey is demonstrated. CRUD methods, a task list, a generated proposal, or a project card in isolation is `scaffold`/`code-present`, not verified M13.

## 14. Implementation order and stop conditions

After M0–M6 and M10–M12 have fresh evidence:

1. Freeze synthetic Projects, Tasks, Briefs, Sources, proposals, scopes, dates, dependencies, and deletion fixtures.
2. Implement M13-A canonical schema/graph/relation contracts.
3. Implement M13-B proposal review and explicit promotion with idempotency.
4. Implement M13-C lifecycle/inbox/project views and truthful transitions.
5. Implement M13-D due-date/dependency integrity without recurrence/notifications.
6. Implement M13-E provenance/deletion/export/recovery and clean-profile validation.
7. Run M13-1…M13-13 before enabling promotion.
8. Run M13-14…M13-29 before exposing lifecycle/inbox/dependency actions.
9. Run M13-30…M13-40 before exposing delete/restore/export in the default project view.
10. Run M13-41…M13-42 in clean profile and degraded configurations.
11. Re-run M10 Sidecar and M12 Command Center paths so proposals/actions cannot bypass M13 confirmation or M0/M5 lifecycle authority.
12. Record exact results and remaining risks in the canonical progress log.

Stop and do not widen scope if:

- model output or Brief text can create a Task/Project without explicit user confirmation;
- promotion can duplicate after retry, crash, or concurrent acceptance;
- a task loses its source/Brief lineage when edited;
- private, candidate, deleted, or audit-incomplete evidence becomes grounded task context;
- dependency edges can create cycles or blocked state is stored separately and drifts;
- ambiguous dates become authoritative without timezone/confirmation;
- recurrence silently clones tasks or notification delivery is claimed without an OS result;
- deletion silently cascades or rollback can discard pre-existing user work;
- export claims content/relations that were not retained or allowed;
- Honeycomb/EventLedger disagreement is hidden behind a success state;
- M13 creates a generic dashboard that users must enter before browsing remains useful.

## 15. Explicitly deferred

- Recurring tasks, RRULE expansion, missed-occurrence policy, and automatic task cloning.
- UserNotifications, Calendar/Reminders/EventKit sync, scheduled background reminders, and alarm delivery.
- Assignees, teams, collaboration, shared projects, role-based access, and multi-user conflict resolution.
- Cycles/sprints, capacity/velocity metrics, Gantt/critical-path UI, and project rollups beyond bounded counts.
- Automatic task creation from ambient screen/email/chat content.
- Model-authorized state changes, bulk reassignments, bulk deletion, or silent date changes.
- Full Notion database/formula semantics and a separate task database.
- Remote task connectors, cloud sync, and external issue tracker mutation.
- Notifications, purchases, messages, account actions, and OS-level automation.

## 16. Evidence references

Project/task/product patterns:

- [Linear conceptual model](https://linear.app/docs/conceptual-model)
- [Linear projects](https://linear.app/docs/projects)
- [Linear cycles](https://linear.app/docs/use-cycles)
- [Things support: Today/Upcoming/Anytime/Someday](https://culturedcode.com/things/support/articles/4001304/)
- [Things guide](https://culturedcode.com/things/guide/)
- [Notion relations and rollups](https://www.notion.com/help/relations-and-rollups)
- [Todoist recurring dates](https://www.todoist.com/help/articles/introduction-to-recurring-dates-YUYVJJAV)
- [Asana task dependencies](https://help.asana.com/s/article/task-dependencies)
- [Apple Reminders for Mac](https://support.apple.com/guide/reminders/welcome/mac)

Technical/data semantics:

- [SQLite foreign keys](https://www.sqlite.org/foreignkeys.html#fk_enable)
- [SQLite transactions](https://www.sqlite.org/lang_transaction.html)
- [RFC 5545 iCalendar](https://www.rfc-editor.org/rfc/rfc5545)
- [ISO 8601 date and time](https://www.iso.org/iso-8601-date-and-time-format.html)
- [Apple UserNotifications](https://developer.apple.com/documentation/usernotifications)
- [Apple EventKit](https://developer.apple.com/documentation/eventkit)
- [WAI-ARIA treeview pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treeview/)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)

Security and provenance:

- [OWASP LLM01: Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [OWASP LLM02: Sensitive Information Disclosure](https://genai.owasp.org/llmrisk/llm02-sensitive-information-disclosure/)
- [OpenAI — Designing agents to resist prompt injection](https://openai.com/index/designing-agents-to-resist-prompt-injection/)
- [SQLite Online Backup API](https://www.sqlite.org/backup.html)

These sources establish product patterns, platform/data constraints, and threat categories. The M13 object model, promotion flow, lifecycle/inbox semantics, DueSpec, dependency rules, provenance/deletion/export contract, failure matrix, and exit gates are Hive-specific proposed contracts and require implementation evidence before capability labels change.
