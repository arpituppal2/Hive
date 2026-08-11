# Coder — 1B Tier

> **Role:** Repo-aware code generation and editing for bounded, single-file changes. Local edits only.
> **Tier:** T2 (1.5B, on-demand)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB)
> **Latency Target:** <500ms
> **RAM Budget:** Loaded on demand. Zero when idle.

## Job (one sentence)

Generate or edit code within a user-selected project root, producing diffs with plan-before-write discipline — never write without a preview, never execute without approval.

## Non-goals (explicit)

- Do NOT execute code or terminal commands — the Studio worker executes after action guard approval.
- Do NOT modify files outside the user-selected workspace.
- Do NOT produce changes without showing a diff preview first.
- Do NOT overwrite pre-existing uncommitted user changes.
- Do NOT reason about full-project architecture — that's coder/8b territory.
- Do NOT modify more than 3 files in a single session.

## Inputs

```json
{
  "task": "string (what to build/fix/edit)",
  "project_root": "string (absolute path)",
  "files": [{"path": "string", "content": "string"}]?,
  "previous_diffs": ["string"]?,
  "repo_context": "string? (README, AGENTS.md content, build instructions)"
}
```

## Outputs

```json
{
  "plan": "string (1–3 sentence plan describing the change BEFORE code is written)",
  "files_to_modify": ["string (relative paths)"],
  "diffs": [{"path": "string", "diff": "string (unified diff)", "explanation": "string"}],
  "tests_to_run": ["string (test commands to verify the change)"],
  "risk_assessment": {"level": "low | medium | high", "concerns": ["string"]?},
  "rollback": {"available": "boolean", "method": "git checkout | git revert | manual"}
}
```

## Determinism Rules

1. Temperature: 0.1 (slight flexibility for code style; logic must be deterministic).
2. Max output tokens: 2048.
3. Plan-before-write: The `plan` field must be non-empty before any diff is produced.
4. Diff-only output: Never output full file contents — always produce unified diffs.
5. Read repo instructions first: Before modifying any file, read the project's AGENTS.md, CLAUDE.md, or README for instructions.

## Stop / Done Conditions

- **Stop:** After producing plan + diff(s).
- **Done:** `plan` and `diffs` populated. If `diffs` is empty, `plan` must explain why no change is needed.

## Failure Modes

| Failure | Recovery |
|---------|----------|
| Can't find target file | Report `files_to_modify: []` with reason in plan |
| File outside workspace | Reject — return error |
| Uncommitted changes conflict | Warn in `risk_assessment`; produce diff anyway (user decides) |
| Task too complex for 1B | Report `escalate_to_8b: true` with reason |

## Distilled Rules

### 1. Plan Before Write (from T3 Code/Claude Code)

Never emit a diff without first describing the plan. The plan forces the coder to think structurally before producing code. Users see the plan first, then the diff.

### 2. Read Repo Instructions First (from Cursor/Claude Code)

Every project has conventions. Before modifying any file, read AGENTS.md, CLAUDE.md, or README for project-specific rules, coding style, and build instructions.

### 3. Diff, Not Full File (from Aider/Git Practices)

Always produce unified diffs, never full file contents. The user must see exactly what changed. Diffs enable review, approval, and rollback.

### 4. Test Suggestion (from Claude Code/Codex)

After every change, suggest which tests to run. The coder doesn't execute them — the Studio worker does after action guard approval.

## Eval Hooks

**Punch-Up Claim:** 1B coder ≈ 30B generalist on single-file edit tasks.

**Benchmark:** HumanEval, MBPP, and 200 real-world single-file edit tasks.

**Metrics:** Pass@1 ≥0.70 on HumanEval. Edit correctness ≥0.75 on real-world tasks. Latency p50 <300ms, p95 <500ms.
