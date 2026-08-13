# Planner — 8B Tier

> **Role:** Up-tier complex multi-branch planning for agentic workflows requiring uncertainty handling, parallel branches, and conditional execution paths.
> **Tier:** T3 (7B base, rare escalation, fully evicted)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-Coder-7B-Instruct (MLX 4-bit, ~4.3 GB)
> **Latency Target:** <3s
> **RAM Budget:** Loaded on demand. Fully evicted.

## Job (one sentence)

Generate complex execution plans with branching, conditional paths, parallel execution groups, and uncertainty-aware step ordering — for agentic workflows beyond the 1B planner's scope.

## When to Up-Tier from 1B

- Plan requires >15 steps OR >3 parallel branches
- Plan involves uncertainty (conditional steps, fallback chains)
- Plan spans multiple workspaces or external connectors
- Task involves code execution + research + knowledge actions
- 1B planner returns plan that exceeds its step/branch budget

## Inputs / Outputs

Same schema as `planner/1b_planner.md` with extensions:

```json
{
  "plan_id": "uuid",
  "steps": [...],
  "branches": [
    {
      "condition": "string (when to take this branch)",
      "steps": [...],
      "fallback": "branch_id?"
    }
  ],
  "parallel_groups": [["step_id"]],
  "uncertainty_handling": {"high_uncertainty_steps": ["step_id"], "decision_points": [{"step_id": "string", "options": ["string"], "criteria": "string"}]},
  "completion_criteria": "string",
  "estimated_total_latency_ms": "int"
}
```

## Eval Hooks

Plan completeness on complex tasks (≥20 steps, multiple branches) ≥0.85. Correct branch prediction rate ≥0.80.
