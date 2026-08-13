# M28 — Trustworthy Automation & Flow Runtime Execution Plan

> **Date:** 2026-08-11
> **Status:** planning canon; documentation-only; no implementation implied
> **Roadmap label:** M28 Trustworthy automation & Flow runtime
> **Depends on:** M0–M6 storage/provenance/lifecycle/MCP/encryption contracts; M10 Sidecar scope/approval; M11 Studio bounded execution/rollback; M12 Command Center authority/receipts; M13 Projects & Tasks; M16 Worker/Permission Center; M17 typed desktop actions; M18 Focus Sessions; M19 Connectors; M23 Mail/Calendar read-only modules; M26 tenant/policy/lifecycle; M27 collaboration/encrypted sync.
> **Parent canon:** `docs/superpowers/plans/2026-08-11-memory-wedge-execution-v2.md`
> **Roadmap:** `docs/superpowers/plans/2026-08-11-product-roadmap.md`
> **Packaged mirror:** `Sources/Hive/Resources/Swarm_System_Prompts/00_INDEX.md`
> **Primary code seams audited:** `Sources/HiveCore/Bee/BeeJob.swift`, `Sources/HiveCore/Bee/BeeQueue.swift`, `Sources/HiveCore/Tools/ToolInvocation.swift`, `Sources/HiveCore/Tools/ToolRegistry.swift`, `Sources/HiveCore/Tools/PolicyEngine.swift`, `Sources/Hive/BrowserState+Approval.swift`, `Sources/Hive/BrowserState+Studio.swift`, `Sources/HiveCore/Commands/CommandRegistry.swift`, `Sources/HiveCore/EventLedger/EventLedgerStore.swift`.
>
> M28 is the first reusable automation contract, not an autonomous “do anything” agent. A Flow is a user-visible, versioned sequence of typed outcomes and bounded activities. A Flow run persists enough history to resume, retry, pause for approval, cancel, reconcile uncertainty, and explain what happened. Every consequential activity still passes the existing native policy, approval, worker, connector, browser, and EventLedger boundaries.

## 0. Decision summary

M28 turns the existing one-shot action seams into a safe reusable runtime:

```text
user intent / explicit trigger
  → typed Flow definition and version
    → admission: scope + policy + capability + data class
      → deterministic run plan
        → durable run/event history
          → typed activity dispatch
            → approval wait or bounded execution
              → result verification / compensation / retry
                → provenance + receipt + next step
                  → terminal review or resumable pause
```

| Slice | User value | Hard boundary |
|---|---|---|
| **F1 — Flow definition** | Save a useful sequence once and inspect it later | Flow is declarative, versioned, typed, and user-owned; model output cannot silently publish an executable Flow |
| **F2 — Durable run state** | Resume after app/worker/network failure without guessing | Append-only run history is authoritative; materialized state is rebuildable; unknown side effects remain unknown |
| **F3 — Activity registry** | Reuse browser, memory, Studio, connector, and Worker actions safely | Activities receive typed arguments only after native admission; no arbitrary shell/script/URL/AppleScript escape hatch |
| **F4 — Human gates and scheduling** | Pause for approval or run a bounded reminder/refresh at a useful time | Approval is an external signal bound to an exact revision; macOS scheduling is best-effort and missed runs are disclosed |
| **F5 — Recovery, evidence, and review** | Understand, retry, compensate, stop, or disable a Flow | Retries are at-least-once unless proven idempotent; compensation is typed and limited; no universal rollback claim |

M28 does **not** ship autonomous sending, purchasing, account mutation, deletion, privileged desktop loops, unrestricted coding, background surveillance, public workflow sharing, or a marketplace. Those require later product and security gates.

## 1. Current truth and reusable authorities

### 1.1 Existing primitives

| Existing surface | Current truth | M28 reuse | Missing or unsafe to overextend |
|---|---|---|---|
| `BeeJob` | Codable job value with broad string payload, status, attempts, timestamps, and provenance | Status vocabulary and migration evidence | Not a Flow definition, not a durable run history, and string payloads are not a typed security boundary |
| `BeeQueue` | Actor with in-memory jobs, in-memory task handles, retry/cancel/verify methods, and an in-memory EventLedger | Cancellation/verification vocabulary and a migration seam | Jobs disappear on restart; execution includes broad `Process`, file-write, navigation, tool, and custom paths; no durable checkpoint, idempotency, approval wait, or worker boundary |
| `ToolInvocation` | Typed action envelope with target, preview, trust level, rollback, evidence, and approval scope | Activity admission and exact approval binding | Tool schema/policy is not itself durable workflow state or a scheduler |
| `ToolRegistry` | Typed tool schemas, risk classes, input fields, timeout/rollback metadata | Activity catalog and native validation | Registry validation is not a sandbox and cannot make an unsafe adapter safe by declaration alone |
| `PolicyEngine` | Non-bypassable schema/trust/policy evaluation for structured invocations | Run/step admission before activity arguments reach an executor | It does not persist run history or decide retry/compensation semantics |
| `BrowserState+Approval` | Durable EventLedger decision before approved execution; pending actions and session grants | Human approval signal, consent ordering, and native kill path | Approval must bind Flow ID, run ID, step revision, input hash, scope generation, and expiry |
| `BrowserState+Studio` | Bounded Studio workspace execution, diff/check, and rollback seam | File/code activities only through M11 | M28 cannot broaden Studio into arbitrary background coding or bypass its diff/checkpoint rules |
| `CommandRegistry` | Typed built-in command definitions and local search | Explicit user trigger and Flow invocation surface | A command row is not a Flow scheduler or arbitrary macro language |
| `EventLedgerStore` | Append-only event authority with idempotent recording/query seams | Run, step, policy, approval, retry, cancellation, and outcome evidence | Existing Bee events are too coarse to prove durable execution or exact side-effect status |
| M27 operation log | Planned encrypted shared operation log with deterministic materialization | Optional future shared Flow definition/run metadata | A shared Flow cannot gain authority from sync content; sharing executable runs is deferred |

**Current implementation classification:** `BeeQueue` is **code-present but not a durable Flow runtime**. The M28 plan must not claim resume, exactly-once effects, persistent scheduling, or safe arbitrary automation from the current queue.

### 1.2 Authority table

| Concern | Single authority | M28 rule |
|---|---|---|
| User intent | Browser UI/Command Center/explicit Flow editor | Page, connector, model, or Flow data cannot rewrite intent or expand scope |
| Flow definition | Versioned native Flow store | Model may draft a proposal; native validation and user save publish it |
| Run history | M28 durable RunStore/event log | UI projections and summaries are rebuildable, never the sole state |
| Activity capability | Typed ActivityRegistry + existing ToolRegistry | No activity is executable because it appears in JSON or model text |
| Policy | M10/M11/M16/M17/M26 policy authorities | Flow orchestration cannot downgrade a tool’s trust or permission class |
| Consent | Existing approval controller/EventLedger | Approval is exact, expiring, and cannot be reused for a changed step |
| Scheduling | Native trigger authority plus OS integration | A timer is a request/reconciliation hint, not proof that work ran while asleep |
| Secrets | Keychain/connector authorities | Run history contains `SecretRef` metadata only, never secret material |
| Verification | Typed activity verifier | Model text, exit-like prose, or a remote response cannot declare success |
| Stop/revoke | Browser-owned cancellation/grant controller | Stop is idempotent, invalidates queued work, and cannot require model cooperation |
| Provenance | Honeycomb/EventLedger/M19/M26/M27 authorities | Each output links to inputs, policy, activity, and actual result state |

## 2. Product boundary and non-goals

### 2.1 In scope

1. User-created or user-approved versioned Flow definitions.
2. Typed steps with explicit input/output schemas and declared capability/data scopes.
3. Durable local run history with event IDs, step attempts, checkpoints, leases, and recovery states.
4. Deterministic planning/replay of Flow control state without replaying completed side effects.
5. Bounded activity execution through browser, memory, Studio, connector, Worker, and Command Center authorities.
6. Retry policies with timeout, backoff, jitter, maximum attempts, and non-retryable error classes.
7. Idempotency keys and result deduplication for activities that claim idempotent behavior.
8. Human approval waits as durable external signals with exact binding and expiry.
9. Explicit one-shot, manual, event-driven, and best-effort scheduled triggers.
10. Stop, pause, resume, disable, retry, compensate, inspect, export, and delete lifecycle paths.
11. Provenance from Flow revision → run → step → input/output artifacts → EventLedger.
12. Browser-first, privacy, accessibility, prompt-injection, offline, locked, and degraded behavior.

### 2.2 Explicit non-goals

- Exactly-once external side effects; M28 only provides at-least-once dispatch plus idempotency where an activity proves it.
- A general-purpose programming language, arbitrary loops, recursion, dynamic code, or model-generated executable scripts.
- Unrestricted shell, AppleScript, CGEvent, browser JavaScript injection, filesystem traversal, package installation, credential entry, or network fetches.
- Autonomous send/reply/publish/purchase/account/payment/calendar mutation or destructive deletion.
- Hidden background surveillance, all-day screen reading, passive microphone capture, or implicit context expansion.
- Public Flow marketplace, anonymous sharing, cross-tenant Flow inheritance, or automatic import of executable Flow logic from M27 shared content.
- A guarantee that a Mac executes a scheduled Flow while asleep, powered off, locked, thermally constrained, or without an authorized process.
- A universal undo button for external effects, side effects outside Hive, or activities without a verified compensation contract.
- Treating a model’s plan, tool call, generated JSON, or page instruction as a security boundary.

## 3. Flow definition contract

### 3.1 Versioned Flow object

A Flow is a user-owned immutable revision plus a native projection:

```text
FlowDefinition {
  flow_id: stable UUID
  revision_id: stable UUID
  owner_scope: profile | project | tenant-assigned-workspace
  title: bounded user title
  purpose: bounded outcome description
  trigger: manual | event | schedule | resume_only
  input_schema: typed bounded schema
  steps: ordered typed FlowStep list
  output_schema: typed bounded schema
  data_scope: explicit scope expression
  capability_requests: declared capability classes
  failure_policy: typed retry/stop/compensation policy
  schedule_policy: optional bounded schedule
  enabled: Bool
  created_at: Date
  published_at: Date?
  supersedes_revision: UUID?
  definition_hash: canonical hash
  status: draft | published | disabled | revoked | archived
}
```

A published revision is immutable. Editing creates a new revision; active runs retain the revision they started with. Disabling a Flow prevents new runs but does not silently mutate an already-running revision; a policy or grant revocation may stop it.

### 3.2 Typed step model

```text
FlowStep {
  step_id: stable UUID within revision
  ordinal: Int
  outcome: bounded outcome-oriented label
  activity_id: registered typed activity
  input_bindings: typed literals / prior output references / approved context refs
  output_schema: typed schema
  data_scope: intersection with Flow scope
  capability_scope: declared narrow capability request
  timeout: bounded duration
  retry_policy: RetryPolicy
  approval_policy: none | before_step | before_each_attempt | on_recovery
  verifier_id: registered verifier
  compensation_id: registered typed compensation?
  on_failure: stop | retry | branch_to_bounded_step | await_user
  step_hash: canonical hash
}
```

Step names describe outcomes, not implementation calls: “Extract claims from the retained capture,” not “call librarian/1b.” The activity mapping is native and can change without invalidating the outcome-oriented Flow vocabulary.

Allowed control constructs in v1:

- sequential steps;
- bounded `if` over typed verifier output;
- bounded fan-out over a fixed list with a declared maximum;
- explicit human approval wait;
- explicit terminal success/failure/partial states.

Forbidden in v1:

- unbounded loops or recursion;
- dynamic step creation from model/page/connector text;
- arbitrary reflection or code evaluation;
- a step that changes its own policy, capability, retry, or approval contract;
- a Flow that invokes another Flow unless the nested revision is explicitly referenced and depth is capped;
- hidden network, secret, clipboard, private-tab, or desktop context.

### 3.3 Input binding and scope

Inputs are one of:

```text
literal(value, declared data class)
prior_output(step_id, output_field)
user_input(field, explicit at run start)
attached_source(source_id, retained provenance)
attached_tab(tab_id, explicit M10 scope)
project_object(object_id, M26/M13 admission)
connector_item(item_id, M19/M23 admission)
secret_ref(secret_id, purpose, destination activity)
```

Every binding carries a privacy/data class and source generation. A Flow cannot bind “all tabs,” “all memory,” “the home directory,” or “whatever the page says” as an implicit input. Context is intersected at run admission, again before each step, and again before any remote or privileged dispatch.

### 3.4 Flow publication and validation

Publishing requires native validation:

1. all activity IDs and verifier IDs resolve in the current registry;
2. schemas and bindings type-check;
3. step graph is acyclic or uses only bounded approved control constructs;
4. capability/data scopes are no broader than the owner’s current policy;
5. every consequential step declares approval/verification/compensation behavior;
6. timeouts, output limits, retry caps, fan-out caps, and nesting depth are bounded;
7. no forbidden activity, secret destination, private scope, arbitrary code, or hidden trigger exists;
8. canonical definition hash is computed and EventLedger records publication.

A model may produce a `FlowProposal`, never a published `FlowDefinition` directly.

## 4. Durable run and event-history contract

### 4.1 Run record

```text
FlowRun {
  run_id: stable UUID
  flow_id: UUID
  flow_revision_id: UUID
  owner_scope: resolved native scope
  trigger_kind: manual | event | schedule | recovery
  trigger_id: stable local ID?
  input_manifest_id: UUID
  definition_hash: String
  policy_revision: String
  context_generation: UInt64
  cancellation_generation: UInt64
  state: admitted | queued | running | waiting_approval | waiting_retry | paused | stopping | partial | succeeded | failed | cancelled | blocked | unknown_effect | recovery_required | deleted
  current_step_id: UUID?
  started_at: Date?
  updated_at: Date
  finished_at: Date?
}
```

The run store is an M0-managed local persistence participant. It must use schema migrations, atomic event append, crash recovery, bounded WAL/backup behavior, deletion generations, and no plaintext secret values. The exact storage path and schema version are implementation decisions after M0 evidence; this plan does not create a second EventLedger authority.

### 4.2 Event history

Each state transition is an immutable, idempotent event:

```text
FlowEvent {
  event_id: stable UUID
  run_id: UUID
  sequence: monotonic local sequence
  event_type: run_created | admitted | step_scheduled | step_started
    | heartbeat | step_completed | step_failed | retry_scheduled
    | approval_requested | approval_received | cancellation_requested
    | compensation_started | compensation_completed | checkpointed
    | output_verified | recovery_required | run_terminal
  flow_revision_id: UUID
  step_id: UUID?
  attempt: Int?
  idempotency_key: String?
  input_manifest_id: UUID?
  output_artifact_id: UUID?
  policy_event_id: UUID?
  consent_event_id: UUID?
  error_class: typed enum?
  result_class: typed enum?
  redacted_summary: bounded text?
  created_at: Date
}
```

Events are append-only. A projection may cache current state, but recovery rebuilds it from valid event history. Duplicate event IDs are idempotent only when bytes match; same ID with different bytes is an integrity failure.

### 4.3 Replay rules

- Replay reconstructs orchestration state and completed outputs from history.
- Completed activities are not re-executed merely because the process restarted.
- Non-deterministic values (current time, random IDs, OS state, network responses) enter the history through explicit recorded events or activity results.
- The orchestrator may not read the wall clock, random source, global mutable state, page body, or connector directly while deciding a replayed branch.
- A changed Flow revision never reinterprets an old run.
- A missing/corrupt event, sequence gap, invalid hash, or unrecognized schema moves the run to `recovery_required`; it does not guess a success state.
- Side-effect status is explicit: `not_started`, `started_unknown`, `completed_verified`, `completed_unverified`, `failed`, `cancelled`.

M28 uses the durable-execution pattern of replaying control history while isolating non-deterministic activities. It does not claim Temporal’s server guarantees; the first runtime is local-first and must disclose its device/process limits.

### 4.4 Checkpoint and leases

Before dispatching a side-effecting activity, the run appends a checkpoint containing:

```text
run_id, flow_revision_id, step_id, attempt
input_manifest_hash, policy_revision, capability_generation
approval_binding_hash, idempotency_key, compensation reference
```

A worker/activity lease has a bounded expiry and heartbeat interval. Lease expiry does not prove the activity stopped; it produces `started_unknown` until a verifier or adapter-specific reconciliation resolves it. No retry is admitted while an unresolved non-idempotent side effect may still be running.

## 5. Activity registry and execution boundary

### 5.1 Activity descriptor

```text
ActivityDescriptor {
  activity_id: stable namespace + version
  outcome: bounded user-facing outcome
  input_schema: typed schema
  output_schema: typed schema
  capability_class: observe | local_read | local_write | browser_act | connector_read | privileged
  data_classes_in/out: allow-list
  executor: native adapter ID
  verifier: native verifier ID
  idempotency: naturally_idempotent | key_idempotent | repeatable_no_side_effect | unknown
  timeout_max: bounded duration
  output_max: bytes/records
  network_policy: none | local_only | allowlisted
  approval_default: none | per_run | per_step | per_attempt
  compensation: typed adapter ID?
  cancellation: cooperative | forceable | cannot_confirm
  status: active | deprecated | disabled
}
```

Examples of initially eligible activities:

- read current explicitly attached tab metadata;
- inspect a retained Source or project object;
- run deterministic local extraction over a bounded artifact;
- create a draft Honeycomb proposal without promotion;
- propose a Studio diff without writing;
- run a previously approved bounded check through M11;
- refresh a read-only M19/M23 connector within its existing scope;
- navigate the active browser through the existing typed browser policy when the user explicitly requested it.

Activities requiring later gates or disabled in M28:

- send/reply/publish/purchase/account mutation;
- external calendar/mail mutation;
- arbitrary code execution or package installation;
- file writes outside M11 Studio;
- desktop actions outside M16/M17;
- password/card/credential entry;
- raw browser JavaScript injection;
- remote model invocation without M26/user-visible context consent;
- deletion or destructive batch changes.

### 5.2 Admission order

The executor receives executable arguments only after this order succeeds:

```text
Flow revision/hash
  → run state/generation
    → input binding and privacy admission
      → activity schema validation
        → capability/policy evaluation
          → approval/consent check
            → idempotency/recovery check
              → checkpoint append
                → worker/connector/browser dispatch
```

A failure at any earlier stage is a typed `blocked`, `stale`, `awaiting_approval`, or `recovery_required` state. It must not fall through to a less restricted executor.

### 5.3 Worker and connector handoff

- M11 owns project-root/file/check authority; M28 submits a typed activity request and receives a receipt.
- M16 owns worker identity, capability grants, TCC truthfulness, and stop/revoke; M28 cannot mint or widen a grant.
- M17 owns target-bound desktop observation/actions; M28 can request a declared action, never a freeform sequence.
- M19/M23 own connector credentials, cursors, scopes, revocation, and deletion; M28 receives scoped records, never raw tokens.
- M10/M12 own sidecar approvals and command receipts; M28 invokes their typed interfaces rather than cloning them.

## 6. Retry, timeout, heartbeat, and idempotency

### 6.1 Retry policy

```text
RetryPolicy {
  mode: never | bounded_exponential
  max_attempts: 0...5
  initial_delay: bounded duration
  backoff_multiplier: 1...4
  max_delay: bounded duration
  jitter: none | full
  retryable_errors: explicit typed classes
  non_retryable_errors: explicit typed classes
  retry_requires_reapproval: Bool
}
```

Default is no retry for consequential actions and at most three attempts for read-only/idempotent activities. A retry is never selected because prose “looks transient.” The error class and adapter contract decide.

Retries use at-least-once semantics. An activity may claim `key_idempotent` only when it accepts the native idempotency key and guarantees duplicate requests return the same logical result or a safe already-applied receipt. “The request probably ran” is not idempotency.

### 6.2 Idempotency key

The native runtime derives two distinct identifiers, never the model:

```text
logical_operation_key = hive-m28-idempotency-v1 || run_id || flow_revision_id || step_id
transport_delivery_id = hive-m28-delivery-v1 || logical_operation_key || delivery_attempt
```

The `logical_operation_key` is stable across worker retry/restart for the same logical step. `delivery_attempt` may increase for transport bookkeeping, but it never creates permission to repeat an unresolved non-idempotent side effect. The activity/result store retains logical key → input hash → result/unknown state, plus delivery IDs for diagnostics. Reusing a logical key with different input, scope, policy, or activity version is a hard error. A retry is admitted only after the prior delivery is verified complete, verified not-started, or the activity’s declared key-idempotency contract safely deduplicates it; otherwise the run remains `started_unknown`/`recovery_required`.

### 6.3 Timeouts and heartbeats

Each activity declares:

- schedule-to-start bound;
- start-to-close bound;
- total run/step bound;
- heartbeat interval for long work;
- output and memory bound;
- cancellation/termination behavior.

A heartbeat proves only that the adapter reported progress, not that an external side effect committed. Heartbeat details are bounded, typed, redacted, and persisted as progress metadata—not raw logs or secrets. The UI shows `running`, `heartbeat_stale`, `timed_out`, `termination_uncertain`, or `completed_unverified` distinctly.

### 6.4 Error taxonomy

```text
validation_error       — deterministic input/schema/Flow defect; no retry
policy_denied          — native authority denied; no automatic retry
approval_expired       — user action required; no silent retry
scope_revoked          — grant/context invalid; recovery or reapproval
transient_unavailable   — bounded retry if activity declares it
rate_limited           — retry after server/adapter delay if allowed
timeout                — retry only if idempotency/reconciliation permits
cancelled              — terminal for this run unless user explicitly resumes
started_unknown        — reconcile before retry
verification_failed    — review/compensation; no generic retry
permanent_failure      — terminal/branch/await-user
integrity_failure      — quarantine/disable; no retry
```

## 7. Approval waits, scheduling, and triggers

### 7.1 Human approval as a durable signal

A `before_step` or recovery approval creates:

```text
ApprovalWait {
  wait_id: stable UUID
  run_id: UUID
  flow_revision_id: UUID
  step_id: UUID
  input_manifest_hash: String
  preview_revision: String
  scope_summary: redacted bounded text
  risk/trust: typed
  expires_at: Date  // mandatory bounded wall-clock deadline; nil is invalid
  monotonic_deadline_ns: UInt64  // mandatory in-session enforcement deadline
  clock_epoch: UInt64  // native wall-clock reconciliation generation
  decision: pending | approved | denied | expired | revoked
  consent_event_id: UUID?
}
```

The run enters `waiting_approval` and consumes no active worker slot. Every consequential or privileged wait has a mandatory, bounded `expires_at`; an unbounded approval is invalid. Approval is valid only for the exact run, revision, step, input hash, policy revision, capability generation, clock epoch, and preview. The native authority records both a wall-clock `expires_at` and a monotonic deadline captured at admission; the monotonic deadline is the enforcement clock while the process/session remains alive. A changed input, target, scope, policy, Flow revision, or clock-reconciliation epoch expires the wait. On restart or monotonic-clock discontinuity, the authority compares the persisted wall-clock deadline with the new wall clock: a forward jump expires the wait immediately; a backward jump or untrusted clock advances `clock_epoch`, marks the wait `approval_time_uncertain`, and requires fresh approval rather than extending it. Every clock decision is an idempotent durable event. User denial is terminal for that attempt; the Flow may define an explicit bounded branch to `await_user`, never an automatic bypass.

Approval notifications and deep links are hints. The authoritative decision is the native approval UI/EventLedger, not a URL token, page text, connector message, or model response.

### 7.2 Trigger types

| Trigger | M28 behavior | Boundary |
|---|---|---|
| Manual | User starts an exact published revision with explicit inputs | Standard scope/policy/approval admission |
| Resume | Native recovery asks to resume a paused/approved run | Revalidates revision, policy, grants, and unknown effects |
| Event | A typed local event such as explicit capture/promotion or connector cursor change | Event schema/owner/scope allow-list; no arbitrary page text trigger |
| Schedule | One-shot or bounded recurring local request | Best-effort; missed fires reconcile on launch/wake; no sleep execution claim |
| External callback | Deferred M28; only typed trusted adapter signals may be added later | No bearer approval URLs or arbitrary webhooks in v1 |

### 7.3 Scheduling contract

```text
SchedulePolicy {
  schedule_id: stable UUID
  timezone: explicit IANA identifier
  start_at: Date?
  recurrence: none | daily | weekly(selected days) | fixed_count
  maximum_occurrences: bounded Int?
  misfire: skip | run_once_on_reconcile | ask_user
  catch_up_limit: bounded Int
  enabled: Bool
  last_requested_fire: Date?
  last_reconciled_fire: Date?
  clock_epoch: UInt64
}
```

Each local occurrence has a canonical identity before dispatch:

```text
schedule_occurrence_id = hive-m28-occurrence-v1 || schedule_id || flow_revision_id
  || timezone || canonical_local_occurrence || recurrence_index
```

The native scheduler transactionally persists `schedule_occurrence_id` with its state (`planned | missed | reconciled | dispatched | skipped`) before creating a run. Reconciliation of the same occurrence is idempotent; the same ID with different schedule/revision/timezone bytes is an integrity error. On launch/wake, it calculates missed occurrences from wall-clock timestamps and records `missed`, `reconciled`, or `skipped` explicitly, subject to the catch-up limit. A crash after occurrence admission cannot create a duplicate run because the occurrence ID and run linkage are durable before dispatch. It does not claim a run happened while the app/process was unavailable. Sleep, lock, thermal, battery, notification denial, network loss, connector revocation, and user disablement remain visible causes.

macOS `launchd`/LaunchAgent integration, if used, is a wake/launch mechanism and process supervisor, not the Flow authority. `KeepAlive`/calendar triggers cannot provide durable business state, activity idempotency, approval semantics, or universal execution during sleep. M28 must work correctly when no helper is installed: next-launch reconciliation is the fallback.

## 8. Compensation, rollback, and irreversible effects

### 8.1 Compensation classes

| Class | Contract | User-facing state |
|---|---|---|
| `transactional` | Adapter proves atomic commit/rollback | Rollback may be offered after verification |
| `compensating` | Typed inverse reduces an already-committed effect | “Compensate,” with a new policy/approval path where needed |
| `reconcile_only` | Adapter can determine actual state but cannot undo | Recovery/review, no undo claim |
| `none` | No reliable inverse or verification | Irreversible warning; disabled for unattended Flow |

A compensation is a new typed activity with its own idempotency key, policy, approval, verification, and evidence. It is not an exception handler that runs arbitrary model-generated instructions.

### 8.2 M28 unattended rule

Unattended scheduled/event Flows may only run activities that are:

- read-only or draft-only;
- local and bounded;
- explicitly idempotent or repeatable without side effects;
- within an active, non-revoked scope;
- not private/sensitive/credential-bearing;
- verifiable without external mutation;
- allowed by the user’s Flow policy.

Any write, external communication, privileged desktop action, account mutation, purchase, deletion, or irreversible effect enters `waiting_approval` or is blocked. A Flow cannot use a prior broad session grant to turn an unattended activity into a privileged one.

### 8.3 Partial completion

For fan-out or multi-step runs, the runtime records every completed/unknown/failed step. Failure does not pretend the entire Flow rolled back. The review surface offers per-step retry, compensation, export, disable, or stop according to the contract.

## 9. Secrets, data handling, and prompt injection

### 9.1 Secret references

A Flow stores:

```text
SecretRef {
  secret_id: opaque native ID
  provider/connector: typed owner
  purpose: bounded activity purpose
  allowed_destination: exact activity ID
  scope: connector/account/workspace scope
  version: key/token generation
}
```

Secret material is resolved only inside the authorized activity adapter, never passed to the orchestrator, model, Flow proposal, EventLedger, CloudKit, log, preview, or output artifact. A missing/locked/rotated secret yields `authorization_unavailable` or `secret_unavailable`, not plaintext fallback.

### 9.2 Data minimization

Run inputs/outputs are manifests and bounded artifacts. Raw page bodies, mail, calendar, file, OCR, screenshots, private-tab state, and connector content are retained only if the originating authority and user retention policy permit it. Remote model use requires M26 policy plus visible provider/model/context disclosure; a Flow does not silently widen data egress.

### 9.3 Prompt-injection boundary

Page text, connector items, task titles, source claims, repository instructions, Flow descriptions, shared M27 operations, model output, and activity results are untrusted data. They cannot:

- create or publish a Flow;
- change the Flow graph, retry, approval, schedule, or capability policy;
- select a secret, broaden data scope, or choose a destination;
- approve, deny, retry, compensate, delete, send, or publish;
- suppress a warning, stop, audit event, or verification failure;
- turn a text instruction into a new activity or executable argument;
- declare a side effect complete without the native verifier.

The run UI distinguishes user intent, Flow definition, untrusted input, model proposal, policy decision, user consent, activity result, and verifier result.

## 10. Observability, provenance, and user experience

### 10.1 Run surface

Every run exposes:

- Flow title and immutable revision;
- trigger and actual start/reconciliation time;
- current/last step and outcome-oriented description;
- scope/data class/capabilities;
- approval waits and expiry;
- attempts, retry reason, timeout/heartbeat state;
- input/output provenance and artifact links;
- verified/unverified/unknown side-effect state;
- stop, pause, disable, retry, compensate, export, and delete controls where valid;
- browser-first degraded reason when memory/model/network/worker/connector is unavailable.

No UI says “completed” when the run is `started_unknown`, `partial`, `waiting_approval`, `cancelled`, `failed`, or `completed_unverified`.

### 10.2 Accessibility and motion

- Flow creation, revision review, trigger selection, scope preview, approval, Stop, retry, compensation, schedule reconciliation, and deletion are keyboard reachable.
- VoiceOver announces Flow title, revision, step, status, risk, scope, and next safe action.
- Color is never the only indicator of pending/failed/unknown/blocked states.
- Reduced Motion removes timeline/spring effects without hiding state transitions or delaying essential controls.
- Dynamic type and high contrast preserve the Stop/deny/safe-cancel controls and long error explanations.
- Waiting for approval is a stable, inspectable state rather than a spinner; reconnect/reopen restores focus to the waiting run.

## 11. Failure matrix

M28 requires deterministic synthetic flows, fake clocks, fake workers/connectors, no real credentials, and no production network.

| ID | Fixture | Required assertion |
|---|---|---|
| M28-01 | Draft Flow has unknown activity ID | Cannot publish or execute |
| M28-02 | Step schema mismatch | Validation blocks publication with path-specific error |
| M28-03 | Flow contains dynamic model-created step | Rejected; graph remains immutable |
| M28-04 | Unbounded loop/recursion | Rejected at publication |
| M28-05 | Flow revision edited while run is active | Run retains original revision; new run uses new revision |
| M28-06 | Duplicate publish request | Idempotent single publication event |
| M28-07 | Model proposal claims publication | Remains proposal; no executable definition |
| M28-08 | Scope binds all tabs/all memory/home directory | Rejected or requires explicit bounded attachment |
| M28-09 | Private tab/source bound as input | Excluded/blocked; no run context leak |
| M28-10 | Connector item contains prompt injection | Data only; no graph/policy/action change |
| M28-11 | Run store unavailable at creation | Run does not execute; browser remains usable |
| M28-12 | Crash after run-created event | Recovery resumes from durable state without duplicate creation |
| M28-13 | Crash after step checkpoint before dispatch | Recovery reconciles pending step; no blind duplicate non-idempotent dispatch |
| M28-14 | Crash after external dispatch before result | `started_unknown`; reconcile before retry |
| M28-15 | Corrupt event or sequence gap | `recovery_required`; no guessed success |
| M28-16 | Duplicate event ID identical bytes | Idempotent acknowledgement |
| M28-17 | Duplicate event ID different bytes | Integrity failure/quarantine |
| M28-18 | Completed step on replay | Output reused; activity not re-executed |
| M28-19 | Nondeterministic wall clock during replay | Rejected or uses recorded time event |
| M28-20 | Nondeterministic random ID during replay | Uses native pre-recorded ID; replay remains byte-equivalent |
| M28-21 | Retryable connector timeout | Bounded retry with recorded backoff and attempt |
| M28-22 | Non-retryable policy denial | No retry; terminal blocked state |
| M28-23 | Retry cap exceeded | Terminal failed/await-user state; no infinite loop |
| M28-24 | Retry key input changes | Hard idempotency error; no reuse |
| M28-25 | Activity declares idempotent without key enforcement | Registry rejects descriptor |
| M28-26 | Heartbeat becomes stale | Timeout/reconciliation state; no success claim |
| M28-27 | Worker lease expires with possible side effect | `started_unknown`; retry blocked until reconcile |
| M28-28 | User presses Stop during queued step | Queue admission invalidated; no dispatch |
| M28-29 | User presses Stop during active activity | Cancellation/termination uncertainty recorded |
| M28-30 | Grant revoked during run | New steps blocked; active activity stopped/reconciled |
| M28-31 | Approval wait expires | No execution; explicit reapproval required |
| M28-32 | Approval payload/scope/policy hash changes | Wait invalidated; fresh preview required |
| M28-33 | Approval deep link opened in wrong profile | No decision accepted; native UI required |
| M28-34 | Approval denied with fallback branch | Only declared bounded branch runs; no bypass |
| M28-35 | Schedule fires while app is asleep | No false run; next launch records missed/reconciled state |
| M28-49 | Crash during schedule reconciliation | Durable `schedule_occurrence_id` links one occurrence to at most one run; replay is idempotent |
| M28-50 | Approval wall clock jumps forward/backward or monotonic clock resets | Forward jump expires; backward/discontinuous clock advances epoch and requires fresh approval |
| M28-36 | Multiple missed schedule occurrences | Catch-up limit and misfire policy applied deterministically |
| M28-37 | Timezone/DST transition | Fake-clock fixture yields explicit local-time behavior |
| M28-38 | User disables Flow while queued | No new dispatch; active revision reports policy stop |
| M28-39 | launchd/helper absent | Manual/next-launch reconciliation remains usable |
| M28-40 | Read-only unattended Flow | Runs only within declared local scope and emits receipt |
| M28-41 | Unattended write/send/delete step | Requires approval or is blocked |
| M28-42 | SecretRef missing/locked/rotated | Typed unavailable state; no plaintext fallback |
| M28-43 | Secret appears in output/log/preview | Redaction test fails closed; secret is not persisted |
| M28-44 | Compensation available after partial run | New typed compensation requires its own policy/verification |
| M28-45 | No compensation for external effect | Irreversible/reconcile-only label; no undo claim |
| M28-46 | Fan-out exceeds bound | Publication/admission rejects before work |
| M28-47 | Shared M27 Flow revision arrives | Treated as untrusted proposal; no auto-publish/authority grant |
| M28-48 | Accessibility/reduced-motion/degraded browser path | Flow controls remain operable; browsing works with runtime disabled |

The fixture matrix contains **50 cases**. New cases require an update to this plan and all progress mirrors.

## 12. Work packages after approval

### M28-A — Flow definition, publication, and scope

- Freeze the versioned Flow/Step/Proposal schemas, canonical hashing, input bindings, bounded control graph, publication validator, and owner/revision lifecycle.
- Reuse M10/M12/M13/M26 scope and provenance rules; no second command, task, or permission authority.
- Add proposal-vs-published state, explicit trigger policy, capability/data-class declarations, and accessibility-ready review.
- Add M28-01…M28-10 before any execution path is enabled.

**Done when:** a user can inspect and publish one valid bounded Flow, invalid/model-authored/dynamic flows remain inert, and every input has explicit scope/provenance.

### M28-B — Durable run store, event history, and replay

- Make the Flow run store an M0-managed persistence participant with migrations, atomic event append, deletion generation, backup/recovery, and redacted payload rules.
- Implement run/step state projections from append-only history; preserve immutable Flow revision identity.
- Define deterministic clocks/IDs/replay and checkpoint/lease semantics; never replay completed side effects blindly.
- Add M28-11…M28-20 before enabling retries or schedules.

**Done when:** crash/restart/replay reconstructs the same control state, unknown side effects are explicit, and no duplicate non-idempotent dispatch is admitted.

### M28-C — Typed activity registry and bounded execution

- Define activity descriptors, typed input/output schemas, verifier IDs, idempotency declarations, timeout/heartbeat/output limits, and adapter lifecycle.
- Route M11/M16/M17/M19/M23/M10/M12 operations through their existing authorities; remove any path where Flow payload becomes a shell/file/script command.
- Add native stop/revoke/generation checks and per-activity receipts.
- Add M28-21…M28-30 before unattended operation is considered.

**Done when:** every enabled activity is typed, bounded, policy-admitted, verifiable, and unable to widen authority through model/page/connector content.

### M28-D — Approval waits, triggers, and best-effort scheduling

- Implement durable approval waits bound to run/revision/step/input/policy/capability generation and expiry.
- Implement manual/resume/event/schedule trigger records with fake-clock reconciliation, timezone/DST behavior, catch-up limits, and missed-fire disclosure.
- Keep launchd/LaunchAgent optional and subordinate to the local run authority; no claim of execution during sleep or process absence.
- Add M28-31…M28-40, plus occurrence/reconciliation fixtures M28-49…M28-50, before any user-facing recurring Flow toggle.

**Done when:** a Flow can pause and resume through native approval, manual and bounded local triggers are truthful, and missed schedules never become invented successful runs.

### M28-E — Compensation, secrets, observability, and integrated validation

- Add typed compensation/reconcile-only/irreversible classes, SecretRef resolution, run review, export/deletion, EventLedger links, and accessibility/degraded states.
- Enforce unattended rule: only read-only/draft/idempotent local activities may run without fresh approval.
- Run M28-41…M28-50, clean-profile browser-first paths, private/locked/offline/revoked states, and recovery/reconciliation drills.
- Record fresh evidence before changing any capability label.

**Done when:** users can understand, stop, retry, approve, compensate, disable, export, or delete a run without false success or universal undo claims.

## 13. Exit gates

| Gate | Requirement | Evidence |
|---|---|---|
| M28-A | Flow schema/publication | Typed versioned definitions, canonical hash, scope/graph validation |
| M28-B | Proposal boundary | Model/page/connector/shared content cannot publish or alter executable Flow policy |
| M28-C | Durable run history | Atomic event append, migrations, recovery, deletion, redaction |
| M28-D | Deterministic replay | Same valid history reconstructs byte-equivalent control state |
| M28-E | Activity registry | Typed inputs/outputs, verifier, timeout, capability, idempotency, compensation metadata |
| M28-F | Admission ordering | No executor receives arguments before scope/policy/approval/checkpoint gates |
| M28-G | Retry/unknown truthfulness | At-least-once semantics, bounded retry, stale heartbeat, unknown side-effect handling |
| M28-H | Approval waits | Exact revision/input/scope/policy binding, expiry, native UI, no bearer-token authority |
| M28-I | Scheduling truthfulness | Fake-clock DST/misfire/catch-up tests; no sleep/process-absence execution claim |
| M28-J | Stop/revoke | Queued invalidation, active cancellation/reconciliation, worker/grant revocation |
| M28-K | Compensation/secrets | Typed inverse limits, SecretRef-only history, no plaintext fallback |
| M28-L | Browser-first release | 50 fixtures, accessibility, private/offline/locked/degraded paths, clean-profile evidence |

M28 is **verified** only when all 12 gates pass with fresh build/test/runtime evidence and a clean-profile compound Flow is demonstrated. A queue, timer, JSON prompt, closure callback, green mock result, or retry loop in isolation is `scaffold`/`code-present`, not trustworthy automation.

## 14. Implementation order and stop conditions

After the upstream M0–M27 contracts have fresh evidence:

1. Freeze deterministic fake-clock, fake-worker, fake-connector, approval, and side-effect fixtures.
2. Implement M28-A publication/schema validation without any execution.
3. Implement M28-B durable run history/replay/recovery before retries or schedules.
4. Implement M28-C one read-only local activity through the typed registry and verifier.
5. Implement M28-D one approval wait and one manual resume path.
6. Implement M28-E one best-effort schedule for a read-only/draft activity, with missed-run reconciliation.
7. Add bounded retry/idempotency for a single read-only connector activity.
8. Add compensation only for one proven local reversible action; keep external effects disabled.
9. Run all 50 fixtures and the browser-first path with runtime disabled.
10. Re-run M10–M19 approval, worker, connector, and command paths to prove no bypass.
11. Record exact evidence and remaining risks in the canonical progress mirrors.

Stop and do not widen scope if:

- Flow text, page text, connector text, shared content, or model output can publish a Flow or change its authority;
- a run can resume by re-executing an unknown non-idempotent side effect;
- a retry is selected without a typed error/idempotency contract;
- approval is represented only by a notification URL, model response, or stale UI flag;
- a schedule claims execution while the app/process was unavailable;
- a timer or launchd job becomes a second run authority;
- a secret is placed in a Flow definition, event, output, log, model context, or CloudKit record;
- a Flow can invoke arbitrary shell/file/AppleScript/browser JS/desktop actions;
- cancellation changes only UI state or descendants may continue untracked;
- compensation is described as universal undo;
- a shared M27 revision silently becomes executable;
- the Flow runtime blocks ordinary browsing when disabled, locked, offline, or unavailable.

## 15. Explicitly deferred

- Remote/server-hosted workflow execution and cross-device run authority.
- External webhooks/callback tokens, public triggers, and bearer approval URLs.
- Autonomous send/reply/publish/purchase/payment/account/calendar mutation.
- Unrestricted shell, scripts, package installation, browser JavaScript, AppleScript, raw CGEvent, or broad computer-use loops.
- Background screen/audio capture, passive surveillance, and hidden model context.
- Dynamic model-authored graphs, unbounded loops, recursion, reflection, and arbitrary code.
- Exactly-once external effects, universal rollback, and guaranteed execution during sleep/power-off.
- Flow marketplace, anonymous links, cross-tenant inheritance, and auto-publish from M27.
- Training or downloading models as a prerequisite for M28; routing may use existing honest local/runtime labels.

## 16. Evidence references

Durable workflow and retry patterns:

- [Temporal — Idempotency and Durable Execution](https://temporal.io/blog/idempotency-and-durable-execution)
- [Temporal — Activity Definition](https://docs.temporal.io/activity-definition)
- [Temporal — Workflows](https://docs.temporal.io/workflows)
- [AWS Step Functions — Error handling, retry, catch, timeout, heartbeat](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-error-handling.html)
- [AWS Step Functions — Callback with task token/manual approval](https://aws.amazon.com/blogs/compute/implementing-serverless-manual-approval-steps-in-aws-step-functions-and-amazon-api-gateway/)
- [AWS Step Functions — Wait state](https://docs.aws.amazon.com/step-functions/latest/dg/state-wait.html)

macOS execution and scheduling:

- [Apple — Creating launch daemons and agents](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
- [Apple — Applying launch environment and library constraints](https://developer.apple.com/documentation/security/applying-launch-environment-and-library-constraints)
- [Apple — App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Apple — UserNotifications](https://developer.apple.com/documentation/usernotifications)

Security and agent boundaries:

- [RFC 7636 — Proof Key for Code Exchange by OAuth Public Clients](https://www.rfc-editor.org/rfc/rfc7636)
- [RFC 9700 — OAuth 2.0 Security Best Current Practice](https://www.rfc-editor.org/rfc/rfc9700)
- [NIST SP 800-63B — Digital Identity Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [OWASP LLM01 — Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [OpenAI — Designing agents to resist prompt injection](https://openai.com/index/designing-agents-to-resist-prompt-injection/)
- [Anthropic — Prompt injection defenses](https://www.anthropic.com/research/prompt-injection-defenses)
- [Microservices.io — Saga pattern](https://microservices.io/patterns/data/saga.html)

These sources establish documented workflow, platform, authentication, and threat-model facts. The M28 Flow schemas, state machines, fixture matrix, admission order, and product boundaries are Hive-specific proposed contracts and require implementation evidence before any capability status changes.
