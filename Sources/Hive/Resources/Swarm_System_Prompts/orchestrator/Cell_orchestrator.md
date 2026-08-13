# Cell_orchestrator — control doc

> **Orchestrator-family control doc (runtime contract).** Specifies the task-graph protocol, the no-silent-early-stop rule, the resume protocol, and the dispatch lifecycle. Referenced by `orchestrator/1b_orchestrator.md`, every Cell's `Stop / done conditions` section, and `planner/*` (which produces the task graph the orchestrator executes).

## Purpose

The Cell_orchestrator contract defines how the orchestrator turns a plan into execution, how it handles blocked Cells, how it resumes from interruption, and the single most important system-level invariant: **no Cell may silently stop early.** Every unfinished task must surface as `status:"blocked"` with a reason — never as `status:"complete"` with half the work done.

## Contract

### 1. Task-Graph Model

A task graph is a directed acyclic graph (DAG) of steps, where:
- **Nodes** = outcome-oriented steps, each owned by a specific Cell at a specific tier.
- **Edges** = data dependencies (step B needs step A's output).
- **Cohorts** (from `8b_planner`) = sub-graphs that can execute in parallel. Within a cohort, steps are serial by default.
- **Verify step** = mandatory final step in every non-trivial graph. Must complete before the goal is marked `complete`.

The orchestrator's `update_plan` tool is the serialized form:
```json
{ "summary": "<…>",
  "steps": [
    { "step": "<outcome-oriented>", "status": "pending"|"in_progress"|"completed", "owner_cell": "<…>", "tier": "<…>" }
  ],
  "verify_step": { "step_index": <int>, "owner_cell": "<…>" }
}
```

### 2. Dispatch Lifecycle

For each step in the task graph:

1. **Pre-dispatch check:** is the step's owner_cell in the roster? Is the tier within RAM budget (ask `ram_manager`)? Is the guard's verdict `allow` if this is a privileged action?
2. **Load Cell:** request `ram_manager` to load the Cell at the requested tier. If denied → retry at a smaller tier. If smallest tier denied → `blocked:"ram_cap_exceeded"`.
3. **Dispatch:** send the step (outcome + inputs) to the Cell. Mark step `in_progress`.
4. **Await result:** the Cell returns `{status, ...}`.
   - `status:"complete"` + `confidence ≥ 0.7` → mark step `completed`. If this is the verify step, mark goal `complete`.
   - `status:"complete"` + `confidence < 0.7` → convene council (confidence-threshold rule).
   - `status:"blocked"` → inspect `escalate` hint. If it names a bigger tier → convene council for size selection. If it names a different Cell → re-dispatch there. If structural (missing data, ambiguous) → ask user or convene council.
5. **Post-step:** if step mutated state (wrote to Honeycomb, files, etc.), schedule `auditor/1b_auditor` on the affected nodes. Log to EventLedger.
6. **Next step:** move to the next ready step (all dependencies completed).

### 3. No-Silent-Early-Stop (System-Level Invariant)

**This is the single most important rule in the entire Swarm system.**

Every Cell MUST return one of:
- `status:"complete"` — the work is done, the output is valid, confidence is stated.
- `status:"blocked"` — the work cannot be completed; here's why; here's what to try next.

A Cell MUST NEVER return `status:"complete"` when the work is partially done. Specific anti-patterns:
- **Half-applied patch:** `status:"complete"` but only 2 of 4 files were edited.
- **Skipped verify step:** `status:"complete"` but the verify step was never dispatched.
- **Silent drop:** `status:"complete"` but key claims were dropped without rationales.
- **Phantom success:** `status:"complete"` but the output schema is empty or default-valued.
- **Assumed success:** `status:"complete"` but the Cell didn't actually attempt the step (it inferred it was unnecessary).

The orchestrator enforces this at the system level:
- A `complete` goal requires ALL steps `completed` INCLUDING the verify step.
- A `complete` goal requires `update_goal.status:"complete"`.
- If ANY step in the graph is `blocked`, the goal is `blocked`.
- If the orchestrator encounters an ambiguous `complete` (confidence < 0.7, verify step skipped, output schema violated), it treats it as `blocked` and convenes the council.

### 4. Resume Protocol

The orchestrator must be resumable from interruption (context compaction, tab close, browser restart, RAM eviction). The resume protocol:

1. **On resume, read `update_goal` from Honeycomb/EventLedger** — what was the last goal? What was its status?
2. **Read `update_plan`** — which steps are `completed`, which are `in_progress`, which are `pending`?
3. **If a step was `in_progress`:**
   - Check if the Cell's output was persisted (in Honeycomb or EventLedger).
   - If yes → mark `completed` and continue.
   - If no → re-dispatch the step. The Cell should be idempotent or the orchestrator should surface the ambiguity.
4. **If the goal was `blocked`:** surface the blocked reason to the user (via chat): "Your previous task was blocked because [reason]. Should I retry, try differently, or abandon?"
5. **If the entire plan is stale (user context shifted):** ask the planner to re-plan from the current Honeycomb state.
6. **Never restart from scratch** unless the user explicitly asks. The resume protocol preserves progress.

### 5. Parallel Dispatch Rules

Steps with `can_parallelize_with` or independent cohorts may run concurrently:

- **Within a cohort:** steps with non-overlapping `can_parallelize_with` indices may run in parallel.
- **Across cohorts:** cohorts with no dependency edge in the DAG may run in parallel.
- **RAM constraint:** concurrent steps must not exceed the concurrent-Cell cap (one working 1B + warm orchestrator, or one 8B). If parallel dispatch would breach this, the orchestrator serializes.
- **Guard constraint:** privileged actions run serially after the guard gates them — no parallel privileged dispatch.

### 6. Guard Integration

Before EVERY privileged action (T3+), the orchestrator MUST:
1. Send the action envelope to `guard/rule_action_guard`.
2. If `verdict:"deny"` → log the deny; surface to user; do NOT execute. Do NOT re-route around the guard.
3. If `verdict:"allow"` → log the allow; execute; schedule auditor afterwards.
4. The guard's verdict is absolute. The council cannot override a deny.

### 7. User Interaction Protocol

The orchestrator may interact with the user (via chat) only for:
- **Ambiguity resolution:** underspecified multi-step request before building a plan.
- **Blocked surfacing:** a goal is blocked and the orchestrator can't resolve it.
- **Cloud opt-in:** BYOK escalation requires explicit user approval.
- **Guard deny surfacing:** "The guard blocked this action. Here's why. Do you want to override?"

The orchestrator must NOT:
- Ask the user for permission on every step (the autonomy contract).
- Ask the user to choose between equivalent tiers (the council does that).
- Ask the user to debug a Cell failure (that's the orchestrator's job).

### 8. EventLedger Integration

Every consequential event is logged:
- Goal start / goal complete / goal blocked.
- Step dispatch / step complete / step blocked.
- Guard verdict (allow/deny) + action envelope.
- Council convened + verdict.
- Cell load / Cell eviction (from ram_manager).
- User interaction (ambiguity question, block surfacing, cloud opt-in, guard deny surfacing).

### 9. Cross-References

- `orchestrator/1b_orchestrator.md` — The orchestrator Cell that executes this contract.
- `planner/1b_planner.md` + `planner/8b_planner.md` — The planners that produce the task graph.
- `guard/rule_action_guard.md` — The guard, gated before every privileged action.
- `council/model_council.md` — The council, convened on low-confidence or escalation.
- `router/ram_manager.md` — The ram_manager, gating every Cell load.
- Every Cell's `Stop / done conditions` section — the per-Cell `status:"blocked"` contract.

### 10. Invariants (testable)

1. **No completed goal without a completed verify step** — the `update_goal.status:"complete"` invariant.
2. **No completed goal with any `in_progress` or `pending` step** — all steps must be `completed` or the goal is `blocked`.
3. **No privileged action without a guard verdict** — every T3+ action in the dispatch log has a `guarded_actions` entry.
4. **No load without ram_manager approval** — every Cell load goes through the ram_manager.
5. **No silent goal abandonment** — a goal that can't be completed is `blocked` with a reason, never silently dropped.
6. **Resume preserves progress** — on resume, completed steps stay completed; in_progress steps are re-dispatched or verified.

## Open questions
_(none yet — filled in Phase 4 as implementation begins)_
