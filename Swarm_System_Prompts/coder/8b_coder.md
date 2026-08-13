# Coder — 8B Tier

> **Role:** Full-project code reasoning, multi-file refactors, architecture-level changes. Up-tier for complex code tasks beyond the 1B coder's scope.
> **Tier:** T3 (7B base, rare escalation, fully evicted)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-Coder-7B-Instruct (MLX 4-bit, ~4.3 GB)
> **Latency Target:** <4s
> **RAM Budget:** Loaded on demand. Fully evicted between uses.

## Job (one sentence)

Understand the full project architecture, plan multi-file changes, generate coordinated diffs across the codebase, and reason about system-level implications — the heavyweight coder for tasks the 1B tier can't handle.

## Non-goals (explicit)

- Same as coder/1b plus: Do NOT execute code. Do NOT access files outside workspace. Do NOT modify >10 files per session.

## Inputs (extends coder/1b)

```json
{
  "task": "string",
  "project_root": "string",
  "files": [{"path": "string", "content": "string"}],
  "full_repo_map": "string? (directory tree + key type signatures)",
  "build_config": "string? (Package.swift / Cargo.toml / build.gradle content)",
  "previous_diffs": ["string"]?
}
```

## Outputs (same schema as coder/1b, extended)

```json
{
  "plan": "string (multi-paragraph plan with architecture reasoning)",
  "files_to_modify": ["string"],
  "diffs": [{"path": "string", "diff": "string", "explanation": "string"}],
  "tests_to_run": ["string"],
  "risk_assessment": {"level": "low | medium | high", "concerns": ["string"], "breaking_changes": ["string"]?},
  "rollback": {"available": "boolean", "method": "string"},
  "architecture_notes": "string? (design decisions, tradeoffs discussed)"
}
```

## When to Escalate to 8B (triggered by coder/1b)

- Task requires modifying >3 files
- Task spans multiple modules/packages
- Task involves architecture changes (new abstraction, API redesign)
- Task requires understanding full-project dependency graph
- User explicitly requests "deep" or "full project" change
- coder/1b returns `escalate_to_8b: true`

## Eval Hooks

**Punch-Up Claim:** 8B coder (Coder-7B base) ≈ GPT-4-class 120B+ on multi-file code tasks.

**Benchmark:** SWE-bench, multi-file edit tasks, architecture-level refactors.

**Metrics:** SWE-bench pass@1 ≥0.35 (Coder-7B base + specialist prompt). Multi-file edit correctness ≥0.70.
