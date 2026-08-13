# M30 — Personal Work Loop & Proactive Agenda Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M30 Personal work loop & proactive agenda
> **Depends on:** M0–M6 storage/provenance/lifecycle/MCP/encryption contracts; M10 Sidecar scope/approval; M12 Command Center; M13 Projects & Tasks; M18 Focus Sessions; M21 Wellness Rhythms; M22 Menu-Bar Modes & Presets; M23 Mail/Calendar read-only modules; M26 tenant/policy/lifecycle; M27 collaboration/sync; M28 Flow runtime; M29 memory/context governance.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary authorities reused:** M13 Project/Task authority, M18 FocusSession and power/lock authority, M21 reminder suppression authority, M28 trigger/run authority, M29 context/preference/signal authority, EventLedger consent/revocation, Honeycomb provenance, and M26/M27 scope policy.
>
> M30 is a coordination and presentation layer for a personal work loop. It does not create a second task store, scheduler, memory profile, notification authority, or automation engine. It assembles an honest agenda from admitted objects and explicit user choices; it proposes, explains, and waits for user decisions rather than silently mutating tasks, schedules, goals, or external systems.

## 0. Decision summary

The smallest safe M30 architecture is:

```text
M13 projects/tasks + M19/M23 read-only sources + M5 approved digest inputs
  → M30 objective/task readiness projection
    → M28 trigger/run reconciliation
      → M29 admission/context packet
        → deterministic agenda synthesis
          → user-visible proposal / quiet cue / authorized notification
            → explicit accept, snooze, dismiss, complete, or open
              → M13/M18/M21/M28 authority + EventLedger receipt
```

| Slice | User value | Hard boundary |
|---|---|---|
| **W1 — Objectives and work loop** | See why a task matters and what is ready next | M30 projects typed objectives; it does not invent a personality, life score, or hidden goal model |
| **W2 — Agenda synthesis** | Start the day with a bounded, source-linked plan | Agenda is a deterministic projection, not a promise that Hive knows the user’s whole day |
| **W3 — Proactive proposals** | Surface useful next actions without hunting | Suggestions are explicit proposals; no silent task mutation, external action, or automatic promotion |
| **W4 — Notification and reconciliation** | Receive the right reminder at the right channel—or none | User authorization, category controls, suppression, and best-effort scheduling are explicit; missed runs are reconciled honestly |
| **W5 — Evaluation and browser-first integration** | Make the loop useful without becoming noisy or creepy | Cold-start, no-notification, private, locked, offline, deletion, accessibility, and fatigue metrics gate release |

M30 does **not** ship an always-on personal agent, cross-application activity tracking, passive screen/audio observation, autonomous task rescheduling, autonomous external communication, hidden goal inference, engagement optimization, or a claim that a sleeping/offline Mac executed work.

## 1. Current truth and reusable authorities

### 1.1 Existing surfaces

| Existing surface | Current truth | M30 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| `ProjectStore` / `TaskStore` | Code-present Honeycomb-backed project/task primitives and planned M13 lifecycle | Stable IDs, source lineage, due dates, dependencies, Action Inbox projection | M30 must not create another task database or silently rewrite lifecycle |
| M13 plan | Defines explicit Brief-to-task promotion, lifecycle, dependencies, dates, export, deletion | Canonical task authority and user promotion | M30 cannot bypass M13 consent or treat suggestions as tasks |
| M2 Brief / M5 digest plans | Deterministic Brief and planned approved digest inputs | Agenda evidence and daily summary candidates | Brief/digest output is not an agenda authority or a task mutation |
| M18 Focus Sessions | Planned task-linked session authority, bounded awake lease, power/lock/thermal behavior | “Start focus session” presentation and suppression state | M30 cannot acquire leases, infer activity, or own wellness state |
| M21 Wellness Rhythms | Planned reminder lifecycle, smart pause, quiet/fail-quiet behavior | Notification suppression and user pause controls | M30 cannot infer meeting/presenting/dictation or force breaks |
| M22 Menu-Bar Modes | Planned optional typed projection over Command Center | Optional quiet agenda cue/status entry | M30 cannot add a second command authority or silently install a helper |
| M23 Mail/Calendar | Planned local-first read-only sources and advisory proposals | Calendar/mail evidence only where explicitly connected and admitted | Connector data cannot create goals/tasks or notification authority automatically |
| M28 Flow runtime | Planned durable triggers, run history, approval waits, missed-fire reconciliation | Execution/reconciliation authority for any accepted Flow action | M30 cannot become a scheduler or replay side effects itself |
| M29 governance | Planned separate memory/preferences/signals/context packets and deletion generations | Admission, explanation, scope, preference, and privacy boundary | M30 cannot persist inferred goals, widen context, or send profile state remotely |
| `UserNotifications` / macOS lifecycle | Platform capability, not proof of authorization, delivery, or execution | Category authorization and honest delivery states | A scheduled notification is not proof that a user saw it or that a Flow ran |

**Current implementation classification:** Hive has code-present task/project and Brief foundations plus planned contracts for digest, focus, notifications, and Flow runtime. It does not yet have a verified unified work-loop or proactive agenda system. No M30 claim may be marked verified from a card, timer, notification request, or mock agenda alone.

### 1.2 Authority table

| Concern | Single authority | M30 rule |
|---|---|---|
| Project/task truth | M13 Project/Task authority | Agenda references stable objects and never duplicates their lifecycle |
| Objective/goal | M30 typed Objective projection over user-authored project intent | No hidden goal inference; objective creation/editing is explicit and reversible |
| Memory/context | M29 admission and ContextPacket | Agenda candidates are admitted before ranking or model use |
| Trigger/run | M28 Flow trigger and durable run authority | M30 requests/reconciles; it does not execute or invent runs |
| Power/lock/session | M18 FocusSession authority | Start/pause/end/awake behavior remains M18-owned |
| Reminder suppression | M21 rhythm/suppression authority | Unknown context fails quiet; M30 does not inspect other apps to decide |
| Notification permission | macOS UserNotifications + M30 category preference | Authorization is explicit and delivery is represented as requested/accepted/denied/unknown |
| Consent/audit | Native UI + EventLedger | Accept/snooze/dismiss/complete/notification-policy decisions are typed and auditable |
| Scope/policy | M26/M27/M29 intersection | Shared, tenant, private, deleted, and connector content cannot widen authority |
| External action | M10/M11/M16/M17/M28 approval/policy | A proposal never equals execution |

## 2. Product boundary and non-goals

### 2.1 In scope

1. A typed, user-authored Objective projection linked to one or more M13 projects/tasks.
2. Task readiness classification based on explicit state, dependencies, due date, source provenance, policy, and user-selected context.
3. A bounded daily/weekly AgendaManifest with inputs, omissions, time-zone/local-day identity, stale states, and provenance.
4. Deterministic agenda sections: due/overdue, ready next actions, scheduled/connected events, waiting/blocked, recently approved follow-ups, and optional quiet suggestions.
5. Explicit proactive proposals with reason, scope, source, expiry, action type, reversibility, and Accept/Snooze/Dismiss/Open controls.
6. Separate notification categories and user controls for agenda, due-task reminders, Flow/approval waits, and system/error receipts.
7. Best-effort schedule and notification reconciliation after restart, sleep, offline periods, timezone changes, authorization changes, and missed occurrences.
8. M29-governed context packets for any model phrasing or ranking; deterministic fallback remains usable without a model.
9. Local fatigue and usefulness evaluation using minimal event categories, not content surveillance.
10. Accessible browser-first surfaces in the Morning Brief, Action Inbox, Command Center, optional menu bar, and authorized notifications.

### 2.2 Explicit non-goals

- A second task/project/goal database, a calendar replacement, a full time-blocking application, or a universal life-management taxonomy.
- Hidden goal/personality/identity/emotion inference or a “personal operating score.”
- Passive screen/audio/keystroke/dwell tracking, cross-app activity analytics, or engagement optimization.
- Automatic conversion of memory, email, calendar, page, model, or connector content into a task, objective, reminder, or notification subscription.
- Autonomous task rescheduling, due-date changes, dependency edits, external sends, purchases, calendar writes, or Flow approvals.
- Notification spam, modal interruptions for unknown context, guilt/shame copy, streaks, badges, or punitive productivity mechanics.
- Guaranteed delivery, guaranteed user attention, guaranteed background execution, or execution while the Mac/process is absent or asleep.
- Remote behavioral profiles, model fine-tuning on work-loop data, advertising, third-party analytics, or cross-tenant agenda learning.
- A model/page/connector/notification payload acting as a system instruction or changing policy, permissions, scope, retention, or notification authorization.
- A universal “catch me up on everything” context packet; agenda scope and token/data budgets remain bounded and visible.

## 3. Work-loop object model

### 3.1 Objective projection

An Objective is intentionally smaller than a goal-management platform:

```text
Objective {
  objective_id: stable UUID
  owner_scope: profile | workspace | project | tenant-assigned-workspace
  title: bounded user-authored text
  purpose: bounded user-authored text
  status: active | paused | completed | archived | deleted
  linked_project_ids: stable IDs
  linked_task_ids: stable IDs
  preferred_context: optional typed scope reference
  review_cadence: none | daily | weekly | user_selected
  source_event_id: EventLedger ID
  revision: Int
  created_at: Date
  updated_at: Date
}
```

M30 does not infer an Objective from browsing or query behavior. A model or digest may propose one, but the user must create or accept it explicitly. Objective text is untrusted data when passed to a model and cannot become a system instruction.

### 3.2 Task readiness projection

M30 reads M13 task truth and emits a projection, not a second state machine:

```text
TaskReadiness {
  task_id: stable UUID
  task_revision: Int
  objective_id: UUID?
  state: ready | blocked | waiting | scheduled | overdue | completed | deleted | unknown
  blockers: [typed reason]
  dependency_summary: bounded metadata
  due_state: none | upcoming | due_today | overdue | invalid | timezone_unknown
  source_summary: provenance-safe metadata
  recommended_surface: action_inbox | agenda | brief | quiet_notification | none
  computed_at: Date
  policy_generation: UInt64
}
```

`ready` means “the current M13 state has no known blocker under the selected scope,” not “Hive knows this is the best thing in life.” M30 must preserve unknown/stale/blocked states rather than force a ranking.

### 3.3 Agenda manifest

```text
AgendaManifest {
  manifest_id: stable UUID
  local_day: YYYY-MM-DD
  time_zone_identifier: String
  generated_at: Date
  input_generations: [source/policy/task/context generations]
  sections: [AgendaSection]
  omitted: [OmissionReason]
  stale_inputs: [SourceStatus]
  notification_policy: category state summary
  context_scope_summary: privacy-safe summary
  model_used: none | local | foundation | remote_with_consent
  manifest_hash: canonical hash
  status: fresh | partial | stale | unavailable | deleted
}
```

The manifest is reproducible from frozen admitted inputs. It contains source/task/objective IDs and bounded labels, not secrets, raw connector payloads, full browser history, or hidden signals. A model may phrase a frozen manifest but cannot add an item or change its state.

### 3.4 Proactive proposal

```text
ProactiveProposal {
  proposal_id: stable UUID
  kind: review_task | open_source | start_focus | inspect_blocker
    | approve_flow_wait | review_digest | narrow_scope
  target_ids: stable IDs
  reason_code: due_today | overdue | dependency_cleared | explicit_objective
    | user_requested | approved_flow_signal | stale_input | none
  source_ids: provenance IDs
  scope_summary: privacy-safe summary
  expires_at: Date
  presentation: in_app | command_center | menu_bar | notification
  notification_category: agenda | due_task | flow_wait | system_receipt | none
  required_action: open | accept | snooze | dismiss | approve
  reversibility: no_mutation | local_state_only | existing_approval_required
  status: proposed | shown | accepted | snoozed | dismissed | expired | withdrawn
}
```

Proposals cannot contain executable commands, secrets, arbitrary URLs with credentials, hidden instructions, or unbounded pasted source text. Accepting a proposal routes to the existing typed authority; it does not directly mutate a task or run a Flow unless the existing approval contract permits it.

## 4. Agenda synthesis and scope

### 4.1 Input admission

Agenda assembly intersects:

```text
user-requested agenda scope
  ∩ profile/workspace/project scope
  ∩ M26 tenant policy
  ∩ M27 membership/shared scope
  ∩ M29 privacy/deletion generation
  ∩ M13 task/project lifecycle
  ∩ M18/M21 suppression state
  ∩ M23 explicit connector grants
  ∩ M28 trigger/run visibility
```

A relevant source that fails admission is omitted and represented only by a safe reason category. Agenda ranking never bypasses M29 admission, private mode, deletion, tenant policy, or connector revocation.

### 4.2 Deterministic section order

M30 v1 uses a stable section order and bounded caps:

1. **Needs attention:** due today, overdue, or an expiring approved wait, each with typed reason;
2. **Ready next:** user-selected project/objective tasks with satisfied dependencies;
3. **Scheduled:** explicitly connected calendar/Flow events with stale/authorization labels;
4. **Waiting/blocked:** tasks awaiting dependency, approval, connector refresh, or user input;
5. **Recently approved:** user-approved follow-ups not yet acknowledged;
6. **Optional suggestions:** only explicit-scope, low-noise proposals that pass M29 and M21.

No section may imply completeness. Empty sections are omitted or labeled empty; the manifest reports caps and omissions. The agenda never fabricates calendar events, deadlines, task completion, or user intent.

### 4.3 Time and reconciliation truth

M30 uses explicit local-day and timezone identity. Timezone changes create a new manifest generation and re-evaluate due states; they do not silently rewrite user-authored due dates. Invalid or ambiguous dates remain visible as `timezone_unknown`/`invalid` and require user correction.

M28 owns scheduled Flow occurrence identity and run reconciliation. M30 may show `scheduled`, `missed`, `reconciled`, `skipped`, `awaiting_approval`, `started_unknown`, or `recovery_required`; it must never imply a missed notification or Flow actually executed. After sleep/restart/offline, one bounded catch-up summary replaces a burst of stale notifications.

## 5. Proactive behavior and notification policy

### 5.1 Proposal rules

A proposal may surface only when:

- its target is admitted and not private, deleted, revoked, unknown, or stale beyond the allowed class;
- its reason code is explicit and reproducible;
- it has a bounded expiry and presentation channel;
- it can be dismissed, snoozed, paused, or disabled;
- it does not require hidden behavioral inference;
- it cannot trigger a consequential external action without the existing approval gate;
- it is coalesced with nearby proposals and respects M21 suppression;
- it is rendered as a proposal, not as a command or fact.

Unknown context suppresses rather than interrupts. The default for a new profile is in-app agenda only; notification authorization is never requested merely because a task exists.

### 5.2 Notification categories

M30 defines separate local preferences and consent records for:

| Category | Default | Examples | Never does |
|---|---|---|---|
| `agenda` | in-app only | daily agenda ready, bounded catch-up | no urgent push by default |
| `due_task` | off until chosen | due/overdue local task | no automatic rescheduling |
| `flow_wait` | off until chosen | exact approval wait/expiry | no approval by notification tap alone unless M28 binds it explicitly |
| `system_receipt` | system-controlled | persistence/error/revocation receipt | no marketing or engagement copy |

macOS authorization state is represented as `not_requested`, `authorized`, `denied`, `provisional_or_limited`, `unknown`, or `revoked`. Hive distinguishes “scheduled” from “delivered,” “presented,” and “user acted.” A notification action is an input to the native approval controller, never a bypass.

### 5.3 Fatigue controls

M30 v1 uses deterministic local controls:

- one daily agenda maximum;
- one coalesced catch-up after missed periods;
- per-category cooldown and quiet hours chosen by the user;
- snooze options that do not alter task due dates;
- suppression while M18/M21 says locked/presenting/meeting/dictation/power/thermal constrained;
- a global pause and per-category disable;
- no repeated retry loop when notification authorization or delivery is unknown.

M30 may measure counts of proposed/shown/accepted/snoozed/dismissed/expired by category and coarse scope. It must not store notification body text as a behavioral profile or optimize for engagement.

## 6. Model and prompt-injection boundary

M29 governs every context packet used by M30. The default path is deterministic synthesis over admitted typed data. A local model may phrase a frozen `AgendaManifest`; it cannot add, delete, reorder across the native section policy, change due/readiness state, create an Objective, or select a notification category.

Task titles, objective text, page text, mail, calendar, connector payloads, shared M27 content, and Flow outputs are untrusted data. They cannot:

- become system instructions;
- publish or alter a Flow;
- create a task/objective/proposal without explicit native admission;
- request secrets or broaden scope;
- approve a Flow, notification category, or external action;
- suppress deletion, audit, stop, or verification;
- inject raw text into a notification in a way that impersonates Hive or a system alert.

Any model-generated agenda item is a proposal with source and reason metadata, not an authoritative item. If model/context/ranking is unavailable, deterministic agenda and controls remain available.

## 7. Lifecycle, background, and failure states

- **Fresh launch:** rebuild from current admitted M13/M18/M21/M23/M28/M29 generations; never assume prior display means current truth.
- **Restart/crash:** persist manifest identity and proposal decisions before presentation; reconcile stale proposals and missed occurrences; no duplicate catch-up burst.
- **Sleep/lock:** do not claim work ran; M18/M21 suppression controls presentation and M28 reconciles activity state.
- **Offline:** local task/objective/agenda works from labeled local data; connector/remote/Flow states are stale or unavailable; no invented completion.
- **Notification denied:** in-app agenda and Command Center remain complete; no repeated authorization prompt.
- **Policy/ledger unavailable:** no proactive mutation or consequential proposal acceptance; ordinary browsing remains usable.
- **Deleted/revoked scope:** withdraw affected proposals and manifests; show deletion/revocation status without leaking content.
- **Timezone change:** generate a new manifest and show changed due-state reasons; never silently alter user-owned dates.
- **Accessibility/reduced motion:** all agenda/proposal states are semantic; no motion-only status; VoiceOver exposes reason, scope, expiry, and action.

## 8. Evaluation contract

### 8.1 Frozen local corpus and metrics

M30 uses synthetic/local project, task, objective, calendar, Flow, notification, and memory fixtures. Metrics include:

- readiness classification precision and unknown-state recall;
- agenda inclusion/exclusion correctness and provenance coverage;
- due-date/timezone correctness;
- stale/missed/reconciled occurrence honesty;
- proposal acceptance, dismissal, snooze, expiry, and duplicate rates by category;
- notification authorization/delivery-state truthfulness;
- context leakage, prompt-injection resistance, deletion/revocation propagation;
- cold-start usefulness, browser-first degradation, VoiceOver/keyboard coverage;
- local p50/p95 generation latency and bounded memory use;
- fatigue indicators reported descriptively, never optimized as engagement objectives.

No single aggregate score proves that a proactive loop is useful. Report by scope, category, state, and no-notification baseline.

### 8.2 Stop conditions

Do not enable a proactive surface if:

- a proposal can mutate a task, objective, due date, notification preference, or Flow without explicit native authority;
- a notification action can bypass M28 approval or M16/M17 permission gates;
- an agenda includes private/deleted/revoked/cross-tenant content;
- the system claims a Flow or reminder ran during sleep/process absence without evidence;
- a model can add/change/remove agenda truth rather than phrase a frozen manifest;
- unknown context causes interruption instead of quiet suppression;
- notification denial causes repeated prompts or browser degradation;
- a deleted task/memory/connector scope remains in a cached manifest or proposal;
- copied or untrusted text can impersonate Hive/system notification content;
- M30 stores raw activity surveillance or optimizes for engagement.

## 9. Failure matrix

M30 requires fake clocks, synthetic tasks/projects/objectives, fake notification authorization/delivery states, fake M18/M21 suppression, fake M23 connectors, fake M28 run states, fake M29 generations, and no production network or real personal content.

| ID | Fixture | Required assertion |
|---|---|---|
| M30-01 | Create Objective explicitly | User-authored projection persists through M13/M30 authority; no hidden profile |
| M30-02 | Model proposes Objective | Proposal only until user accepts; no task mutation |
| M30-03 | Delete Objective | Linked projection/agenda/proposals withdraw; task authority remains explicit |
| M30-04 | Task ready with satisfied dependencies | Ready projection appears with stable task revision |
| M30-05 | Task blocked by dependency | Not shown as ready; blocker reason is visible |
| M30-06 | Task state changes during assembly | Stale projection rejected; manifest regenerates |
| M30-07 | Overdue task with invalid timezone | `timezone_unknown`/invalid; no invented due state |
| M30-08 | Timezone changes at local-day boundary | New manifest generation; user date not silently rewritten |
| M30-09 | Empty project/objective | Honest empty section; no fabricated next action |
| M30-10 | Deleted task in cache | Withdrawn before presentation/serialization |
| M30-11 | Private task/source | Excluded from agenda and proposals |
| M30-12 | Cross-tenant relevant task | Excluded before ranking/synthesis |
| M30-13 | Revoked connector event | Withdrawn/stale-labeled; no proposal from revoked data |
| M30-14 | Calendar unavailable | Agenda remains useful with explicit omission |
| M30-15 | Flow awaiting approval | Shows exact wait state; notification cannot auto-approve |
| M30-16 | Flow `started_unknown` | Shows reconciliation required; no completion claim |
| M30-17 | Missed scheduled occurrence | One bounded catch-up/reconciliation; no invented execution |
| M30-18 | Mac asleep at schedule time | No claim of execution; next launch reconciles |
| M30-19 | Offline agenda | Local admitted data works; remote/connector states stale |
| M30-20 | Restart after proposal shown | No duplicate proposal; status rebuilds from event history |
| M30-21 | Crash before proposal decision commit | Proposal remains pending or is withdrawn deterministically |
| M30-22 | Accept proposal | Routes through typed native action/approval; no direct mutation bypass |
| M30-23 | Snooze proposal | Presentation time changes only; task due date unchanged |
| M30-24 | Dismiss proposal | No repeat until explicit expiry/reset policy |
| M30-25 | Proposal expires | Withdrawn and absent from future manifests |
| M30-26 | Duplicate equivalent proposals | Coalesced by deterministic identity |
| M30-27 | Daily agenda cap | At most one daily agenda presentation per local-day policy |
| M30-28 | Quiet hours | Presentation suppressed and reconciled later without burst |
| M30-29 | M18 lock/sleep suppression | No intrusive reminder; state reason visible |
| M30-30 | M21 presenting/meeting/dictation suppression | Quiet/in-app fallback; no inference from screenshots |
| M30-31 | Thermal/battery constraint | No background retry storm or lease mutation |
| M30-32 | Notification not requested | In-app agenda works; no implicit authorization request |
| M30-33 | Notification denied | No repeated prompts; in-app/Command Center remains usable |
| M30-34 | Notification delivered but not acted | State is not marked completed/approved |
| M30-35 | Notification action taps approval | Native exact approval binding still required |
| M30-36 | Notification body contains page injection | Sanitized/omitted; cannot impersonate system instruction |
| M30-37 | Task title says “ignore policy” | Data-only; no authority change |
| M30-38 | Objective asks for secret | Rejected/redacted; no secret access |
| M30-39 | Model adds agenda item | Native manifest rejects; phrasing-only model path |
| M30-40 | Model changes due state | Native state wins; output marked advisory/invalid |
| M30-41 | M29 adaptive ranking disabled | Deterministic baseline remains useful |
| M30-42 | M29 deletion generation advances | Manifest/proposals/caches invalidated |
| M30-43 | M28 Flow disabled | No new run; existing state remains honest |
| M30-44 | M13 task deleted during acceptance | Native revision check rejects; no resurrection |
| M30-45 | Shared M27 objective arrives | Untrusted/explicit-scope data; no personal objective creation |
| M30-46 | Tenant policy denies agenda source | Omitted with safe reason; no leakage |
| M30-47 | No-notification preference | In-app only; no authorization request |
| M30-48 | Cold-start profile | Useful empty/first-run agenda; no fabricated personalization |
| M30-49 | Accessibility/reduced-motion path | Keyboard/VoiceOver/large text work; no motion-only state |
| M30-50 | Browser with M30 unavailable | Navigation/tabs/private mode remain complete |

The fixture matrix contains **50 cases**. New cases require an update to this plan and all progress mirrors.

## 10. Work packages after approval

### M30-A — Objective projection and task readiness

- Reuse M13 Project/Task authority and define the narrow Objective projection, task readiness reasons, stable revisions, blocker/unknown states, and explicit create/edit/archive/delete lifecycle.
- Add M30-01…M30-10 with fake clocks and deterministic revisions.

**Done when:** users can explicitly define why a project/task matters and see truthful ready/blocked/overdue/unknown states without a second task store or hidden goal inference.

### M30-B — Agenda manifest and deterministic synthesis

- Define the versioned AgendaManifest, local-day/timezone identity, section order/caps, omission/stale statuses, input generations, provenance, and deterministic empty/cold-start behavior.
- Reuse M2/M5/M13/M23/M28/M29 outputs without duplicating their storage or admission authorities.
- Add M30-11…M30-21.

**Done when:** the same admitted inputs and generations produce the same bounded agenda, and stale/deleted/revoked/missed states are visible rather than invented.

### M30-C — Proposals, acceptance, and work-loop surfaces

- Define proposal identity, reason codes, expiry, coalescing, presentation channels, Accept/Snooze/Dismiss/Open lifecycle, and exact native routing on acceptance.
- Project into Morning Brief, Action Inbox, Command Center, and optional menu bar without a second command authority.
- Add M30-22…M30-26 and ensure M13/M28 approval/revision checks remain authoritative.

**Done when:** proactive assistance is useful, dismissible, reversible where possible, and never silently mutates a task, schedule, Flow, or external system.

### M30-D — Notification consent and reconciliation

- Add per-category notification preferences and EventLedger consent/revocation records; represent authorization, scheduling, delivery, presentation, and user-action states distinctly.
- Reconcile M28 occurrences, sleep/restart/offline/timezone changes, M18/M21 suppression, quiet hours, cooldown, daily caps, and denial without a notification storm.
- Add M30-27…M30-38.

**Done when:** the user receives no notification unless the category is authorized, no tap bypasses approval, and missed work is reconciled honestly with one bounded catch-up path.

### M30-E — Model boundary, evaluation, and browser-first validation

- Keep deterministic agenda synthesis authoritative; permit only phrasing over a frozen manifest through M29 ContextPacket.
- Run injection/poisoning, deletion/revocation, cold-start, fatigue, latency, accessibility, no-notification, offline/locked, and clean-profile browser fixtures.
- Add M30-39…M30-50 and record descriptive usefulness/fatigue evidence without engagement optimization.

**Done when:** M30 improves discoverability and follow-through without hidden surveillance, model authority, notification coercion, privacy leakage, or browser degradation.

## 11. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M30-A | Objective authority | Explicit typed Objective projection linked to M13 objects; no hidden goal inference |
| M30-B | Task readiness | Stable revision-aware ready/blocked/waiting/overdue/unknown projection |
| M30-C | Agenda manifest | Versioned bounded manifest with local-day/timezone, provenance, omissions, stale state, and input generations |
| M30-D | Proposal lifecycle | Explainable, expiring, coalesced proposal with Accept/Snooze/Dismiss/Open and exact native routing |
| M30-E | Notification consent | Category-specific preference/consent; scheduled/delivered/presented/acted states distinct |
| M30-F | Reconciliation | Sleep/restart/offline/timezone/authorization/suppression states reconcile without invented execution or notification bursts |
| M30-G | M29 privacy | Admission-first context, deletion/revocation propagation, no remote profile/signal state by default |
| M30-H | M28 authority | No run/approval/side effect bypass; started_unknown/missed/recovery states remain honest |
| M30-I | Injection resistance | Task/objective/page/connector/shared text is data-only and cannot alter authority |
| M30-J | Fatigue boundary | Category caps/cooldowns/quiet hours/pause; descriptive metrics only, no engagement optimization |
| M30-K | Accessibility | Keyboard, VoiceOver, dynamic type/large text, high contrast, reduced-motion, semantic status |
| M30-L | Browser-first release | 50 fixtures, clean profile, no-notification, offline/locked/private, M30-disabled browser path |

M30 is **verified** only when all 12 gates pass with fresh build/test/runtime evidence and a clean-profile daily-loop journey is demonstrated. A task list, calendar card, notification request, timer, model-generated suggestion, or polished agenda UI alone is `scaffold`/`code-present`, not a verified personal work loop.

## 12. Implementation order and stop conditions

After M0–M29 contracts have fresh evidence:

1. Freeze fake-clock, synthetic-objective, task, connector, notification, suppression, Flow, context, and deletion-generation fixtures.
2. Implement M30-A Objective/readiness projection without proactive presentation.
3. Implement M30-B AgendaManifest and deterministic synthesis with in-app-only output.
4. Implement M30-C proposal lifecycle and native acceptance routing.
5. Implement M30-D notification categories, consent, reconciliation, suppression, and catch-up.
6. Implement M30-E frozen-manifest model phrasing, evaluation, accessibility, fatigue, and clean-profile integration.
7. Enable Morning Brief/Action Inbox first; enable menu-bar and notifications only after separate consent and reconciliation evidence.
8. Re-run M5 digest, M13 task, M18 session, M21 suppression, M22 preset, M23 connector, M28 Flow, and M29 context/deletion paths.
9. Record exact evidence and remaining risk in the canonical progress mirrors.

Stop and do not widen scope if:

- M30 creates a second task/objective/scheduler/notification authority;
- a proposal silently changes task/objective/due-date/Flow/notification state;
- a notification tap bypasses exact approval or policy;
- missed sleep/offline/restart occurrences are represented as executed;
- unknown context interrupts instead of suppressing;
- private/deleted/revoked/cross-tenant data enters an agenda, proposal, or notification;
- model output changes manifest truth, section policy, due state, or notification category;
- a deleted scope remains in a manifest/proposal/cache/notification payload;
- notification denial causes repeated prompts or browser degradation;
- raw page/task/connector text can impersonate Hive or macOS notification authority;
- the system collects passive activity telemetry or optimizes engagement;
- M30 claims legal compliance, guaranteed delivery, guaranteed background execution, or universal deletion beyond measured evidence.

## 13. Explicitly deferred

- Autonomous task rescheduling, calendar writes, send/reply/publish/purchase, Flow approval by notification alone, and destructive actions.
- Hidden goal/personality/emotion inference, personal operating scores, streaks, shame copy, badges, and engagement optimization.
- Passive screen/audio/keystroke/dwell capture and cross-application behavior analytics.
- Remote behavioral profiles, cloud agenda learning, model fine-tuning on work-loop data, advertising, and third-party analytics.
- A full calendar/time-blocking replacement, recurring task engine, social/team goals, public agenda sharing, or generic project-management clone.
- A guarantee that notifications are delivered, read, or acted upon; a guarantee that a Mac executes while asleep/offline/process-absent.
- A second scheduler, task store, memory store, notification authority, or Flow runtime.

## 14. Evidence references

Platform and scheduling:

- [Apple UserNotifications](https://developer.apple.com/documentation/usernotifications)
- [Apple Manage login items and background tasks on Mac](https://support.apple.com/guide/deployment/manage-login-items-background-tasks-mac-depdca572563/web)
- [Apple ServicesBackgroundTasks](https://developer.apple.com/documentation/devicemanagement/servicesbackgroundtasks)

Privacy, risk, and human control:

- [GDPR — Regulation (EU) 2016/679](https://eur-lex.europa.eu/eli/reg/2016/679/oj)
- [NIST Privacy Framework](https://www.nist.gov/privacy-framework)
- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)
- [NIST SP 800-63A Privacy Considerations](https://pages.nist.gov/800-63-4/sp800-63a/privacy/)
- [OWASP LLM01: Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)

These sources establish platform, privacy, scheduling, and threat-model constraints. The M30 object schemas, agenda sections, proposal lifecycle, notification categories, fixture matrix, caps, and exit gates are Hive-specific proposed contracts and require implementation evidence before any capability status changes.
