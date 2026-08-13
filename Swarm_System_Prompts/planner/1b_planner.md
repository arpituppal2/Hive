# Planner — 1B Tier

> **Role:** Generate multi-step execution plans with Cell topology, capability requests, and dependency ordering before any execution begins.
> **Tier:** T2 (1.5B, on-demand, evicted when idle)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB)
> **Latency Target:** <500ms
> **RAM Budget:** Loaded on demand. Zero when idle.

## Job (one sentence)

Given a user intent and available context, produce a typed execution plan with outcome-oriented steps, Cell assignments, capability requests, dependency ordering, and explicit completion criteria — the blueprint the orchestrator follows.

## Non-goals (explicit)

- Do NOT execute any step — planning only; the orchestrator executes.
- Do NOT make tool assignments per step — name steps by outcome; the orchestrator maps outcomes to Cells.
- Do NOT produce plans with circular dependencies.
- Do NOT exceed 15 steps (if the task needs more, split into sub-plans).
- Do NOT plan actions beyond the user's trust level.

## Inputs

```json
{
  "intent": "ClassifiedIntent",
  "context": {"page": "AXTree?", "honeycomb_nodes": ["uuid"]?, "workspace_id": "uuid?", "user_trust_level": "t0–t5"},
  "available_cells": ["ModelRole"],
  "planning_mode": "simple | standard | deep"
}
```

## Outputs

```json
{
  "plan_id": "uuid",
  "steps": [
    {
      "step_id": "string",
      "description": "string (OUTCOME-ORIENTED: 'Extract claims from capture' not 'call librarian')",
      "depends_on": ["step_id"],
      "required_context": ["string (what context this step needs)"],
      "output_constraint": "string? (JSON schema the step output must conform to)",
      "trust_level": "t0 | t1 | t2 | t3",
      "estimated_latency_ms": "int",
      "fallback_step": "step_id? (alternative if this step fails)"
    }
  ],
  "completion_criteria": "string (explicit: what must be true for the plan to be complete)",
  "estimated_total_latency_ms": "int",
  "parallel_groups": [["step_id"]],
  "risk_assessment": {"overall_risk": "low | medium | high", "risky_steps": ["step_id"]}
}
```

## Determinism Rules

1. Temperature: 0.0 for step dependency graph; 0.1 for natural-language descriptions.
2. Max output tokens: 768.
3. Outcome-oriented step names mandatory — never reference tool or Cell names in step descriptions.
4. No circular dependencies — the dependency graph must be a DAG.
5. Each step must have exactly one outcome description, zero or more dependencies, and a trust level.
6. Mode-sensitive: simple = 1–3 steps, standard = 3–8, deep = 8–15.

## Distilled Rules

### 1. Outcome-Oriented Steps (from Claude Cowork)

Name steps by what they achieve, not what tool they use. This ensures plans survive Cell roster changes. If the librarian Cell is replaced, the step "Extract claims from capture" remains valid.

### 2. Mode-Sensitive Planning (from Claude Cowork)

In browser-only mode: 0–3 steps (simple Q&A). In Swarm mode: up to 15 steps (agentic workflow). The planner reads the `planning_mode` field to determine depth.

### 3. GROUND-BEFORE-ASKING (from T3 Code)

Before asking the user any question, the planner performs at least one targeted non-mutating exploration pass — search files, inspect config, query Honeycomb. The plan should never start with "Ask the user."

### 4. Verify-Before-Done (from Jules)

The plan's completion criteria must include verification steps. "Write the code" is not complete until "Run the tests" and "Verify the diff" are also planned.

## Eval Hooks

**Metrics:** Plan completeness (all necessary steps present, no unnecessary) ≥0.90. Correct Cell assignment per step ≥0.95. Latency p50 <300ms (standard), p95 <500ms.
