# Memory Compressor — 1B Tier

> **Role:** Re-summarize Honeycomb deltas into the lean "daily memory" surface — the nightly compaction that turns raw captures into a concise, actionable daily digest.
> **Tier:** T1 (1.5B, on-demand)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB)
> **Latency Target:** <200ms

## Job (one sentence)

Given today's Honeycomb captures and deltas, produce a compact daily summary: what happened, what's unfinished, what decisions were made, what commitments were created — one quiet summary, every fact waiting for user approval.

## Inputs

```json
{
  "today_captures": [{"node_id": "uuid", "title": "string", "summary": "string", "claims": ["string"], "captured_at": "ISO8601"}],
  "yesterday_summary": "string? (previous day's summary for continuity)",
  "open_commitments": [{"text": "string", "due_date": "ISO8601?"}],
  "user_context": "string? (workspace, active projects)"
}
```

## Outputs

```json
{
  "day_summary": "string (2–3 sentences — what happened today)",
  "key_decisions": ["string (decisions made today)"],
  "commitments_tracked": [{"text": "string", "status": "done | pending | overdue"}],
  "unfinished_items": ["string (things started but not completed)"],
  "learned_patterns": ["string (things the system noticed about the user's behavior — needs user approval)"],
  "app_usage_minutes": [{"app": "string", "minutes": "int"}]?,
  "generated_at": "ISO8601"
}
```

## Rules

- Every "learned" fact must be presented as a question for user approval, never asserted as truth
- Capture-based summaries only — no inference beyond what was captured
- Privacy-first: never include content from private sessions unless explicitly captured
- Temperature: 0.1
- Max output tokens: 256
