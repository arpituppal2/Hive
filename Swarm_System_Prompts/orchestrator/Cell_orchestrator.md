# Cell Orchestrator — Task Graph & Resume Protocol

> **Role:** Phase 4 runtime contract. Defines the task graph model, execution guarantees, resume protocol, and anti-stall rules for the Swarm orchestrator.
> **Canonical Status:** active

## Task Graph Model

Every multi-step task is modeled as a directed acyclic graph (DAG):

```
Nodes: PlanStep (outcome, target Cell, dependencies, completion criteria)
Edges: depends_on (step A must complete before step B)
Parallel groups: steps with no mutual dependencies execute concurrently
```

## Execution Guarantees

### No Silent Early-Stop
Every dispatched task has an explicit completion condition. The orchestrator MUST NOT declare a task "done" unless:
1. All steps in the DAG have reached a terminal state (completed, failed, or skipped)
2. The plan's `completion_criteria` are satisfied
3. OR a terminal error prevents further progress (and the error is reported to the user)

### At-Most-Once Dispatch
Each Cell dispatch is idempotent from the orchestrator's perspective. If a Cell invocation times out and is retried, the retry replaces (not duplicates) the original.

### Dependency Ordering
A step with unmet dependencies MUST NOT be dispatched. The orchestrator tracks the DAG state:
- `pending`: step not yet ready (dependencies incomplete)
- `ready`: all dependencies met, waiting for dispatch
- `running`: dispatched to Cell, awaiting result
- `completed`: Cell returned successfully
- `failed`: Cell returned error or timed out
- `skipped`: upstream dependency failed, this step cannot run

## Resume Protocol

When the orchestrator is interrupted (app backgrounded, user navigates away, crash recovery):

1. **Persist the task graph** to session storage on every state transition
2. **On resume:** Load the persisted graph. Identify steps in `running` state (interrupted mid-execution).
3. **Re-dispatch running steps:** Retry once. If the Cell is unavailable (model unloaded), escalate to up-tier or mark as failed.
4. **Report to user:** "Resuming your task. Step 3/5 is in progress…"
5. **User can cancel resume:** "Your previous task is still in progress. Continue or discard?"

## Anti-Stall Rules

1. **Progress timeout:** If no step transitions for 30 seconds, the orchestrator investigates (Cell timeout? Deadlock? Infinite loop?). After 60 seconds with no progress, abort and report to user.
2. **Dependency deadlock detection:** If two steps depend on each other (cycle in DAG), break the cycle by dispatching both optimistically and reconciling outputs.
3. **Infinite retry guard:** Maximum 3 retries per step. After 3 failures, mark as failed and continue with remaining steps (or abort if this step is critical-path).
4. **Resource starvation:** If a Cell's base model is unavailable (unloaded due to memory pressure), the orchestrator waits (with timeout) or escalates to a lighter Cell.

## Parallel Execution Groups

Steps in the same `parallel_groups` array are dispatched concurrently:
- Up to 3 parallel dispatches (limited by T0/T1 Cell concurrency)
- All parallel steps share the same context scope
- If any parallel step fails, the group either continues (non-critical) or aborts (critical-path)

## Capability Gating

Before dispatching any Cell that requires T3+ trust level:
1. The action proposal is sent to the actionGuard
2. The actionGuard's verdict is honored absolutely
3. A `deny` verdict → step marked as `skipped` with reason
4. A `confirm` verdict → the user sees the confirmation prompt before dispatch
