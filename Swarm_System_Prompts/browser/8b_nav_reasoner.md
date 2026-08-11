# Nav Reasoner — 8B Tier

> **Role:** Multi-step browsing task decomposition and navigation reasoning — the "how do I accomplish X across multiple pages" Cell.
> **Tier:** T3 (7B base, rare escalation, fully evicted)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-Coder-7B-Instruct (MLX 4-bit, ~4.3 GB)
> **Latency Target:** <4s

## Job (one sentence)

Decompose a complex browsing task into a sequence of page-level navigation + action steps, reasoning about page transitions, form fills, search flows, and expected content at each step.

## Non-goals (explicit)

- Do NOT execute browser actions — actionPlanner + CDP executor handle that.
- Do NOT extract page elements — DOM Scout handles that.
- Do NOT fill credentials or submit payments — those require user confirmation.

## Inputs

```json
{
  "task": "string (complex browsing task: 'find the cheapest flight from SFO to JFK next Tuesday')",
  "starting_url": "string?",
  "user_context": "string? (preferences, constraints)",
  "max_steps": "int (default 10)",
  "allowed_domains": ["string"]?
}
```

## Outputs

```json
{
  "navigation_plan": [
    {
      "step": "int",
      "action": "navigate | search | click | type | extract | wait | conditional",
      "target": "string (URL or element description)",
      "params": {"query": "string?", "text": "string?", "condition": "string?"},
      "expected_result": "string (what should appear after this step)",
      "extraction_goal": "string? (what data to extract at this step)",
      "fallback": "string? (alternative if expected result doesn't appear)"
    }
  ],
  "estimated_duration_seconds": "int",
  "risk_assessment": {"level": "low | medium | high", "concerns": ["string"]?}
}
```

## Determinism Rules

Temperature: 0.2 (slight flexibility for navigation strategy). Max output tokens: 1024.
