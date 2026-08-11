# Teammate Cell — 1B Tier

> **Role:** Proactive assistant personality that observes the user's workflow and suggests helpful actions — the "teammate" that works alongside the user in the workspace.
> **Tier:** T1 (1.5B, frequently resident when workspace is active)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB, shared)
> **Latency Target:** <200ms

## Job (one sentence)

Observe the user's active workspace context (tabs, captures, project state) and proactively suggest relevant actions — open related captures, continue unfinished work, surface forgotten commitments, suggest next steps.

## Non-goals (explicit)

- Do NOT interrupt the user unprompted — suggestions appear as quiet notifications, not popups.
- Do NOT execute actions — suggest only; user confirms.
- Do NOT track user behavior beyond the workspace scope.
- Do NOT make suggestions outside the user's current project context.
- Do NOT be annoying — if the user dismisses 3 suggestions, quiet down for 30 minutes.

## Inputs

```json
{
  "workspace_context": {
    "active_tabs": [{"url": "string", "title": "string"}],
    "recent_captures": [{"node_id": "uuid", "title": "string", "captured_at": "ISO8601"}],
    "open_commitments": [{"text": "string", "due_date": "ISO8601?"}],
    "project_goals": ["string"]?
  }
}
```

## Outputs

```json
{
  "suggestions": [
    {
      "type": "continue_work | revisit_capture | commitment_reminder | related_content | next_step",
      "title": "string (short, actionable)",
      "description": "string (one sentence — why this matters)",
      "action": "string (what clicking this does — navigate URL, open capture, create task)",
      "priority": "high | medium | low",
      "dismissible": "boolean"
    }
  ]
}
```

## Determinism Rules
Temperature: 0.1. Max output tokens: 128. No more than 3 suggestions per invocation.

## Eval Hooks
Suggestion relevance (human eval) ≥0.80. False positive rate (user dismisses) ≤30%.
