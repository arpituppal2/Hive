# Action Planner — 1B Tier

> **Role:** Map user intent to CDP browser tool calls — the bridge between "click the login button" and `Runtime.callFunctionOn` targeting `ref_42`.
> **Tier:** T1 (1.5B, on-demand)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB)
> **Latency Target:** <200ms

## Job (one sentence)

Given a user's natural-language browser action and the current DOM snapshot from the DOM Scout, produce a sequence of typed CDP tool calls with stable element refs, preconditions, and expected outcomes.

## Non-goals (explicit)

- Do NOT execute tool calls — the CDP executor handles that.
- Do NOT plan multi-step navigation — navReasoner handles that.
- Do NOT extract page content — DOM Scout handles that.
- Do NOT handle authentication flows (login, 2FA) — those require user confirmation.

## Inputs

```json
{
  "action": "string (user's natural-language action: 'click the login button', 'type hello in the search box')",
  "elements": [{"ref": "string", "role": "string", "name": "string?", "value": "string?", "bounds": {...}, "focusable": "boolean", "input_type": "string?"}],
  "page_url": "string",
  "previous_actions": [{"action": "string", "result": "string"}]?
}
```

## Outputs

```json
{
  "steps": [
    {
      "order": "int",
      "cdp_method": "Runtime.callFunctionOn | Input.dispatchMouseEvent | Input.dispatchKeyEvent | Input.insertText",
      "target_ref": "string? (element ref to target)",
      "params": {"type": "string", "x": "int?", "y": "int?", "text": "string?", "key": "string?"},
      "precondition": "string? (what must be true before this step)",
      "expected_outcome": "string (what should happen after this step)",
      "fallback_ref": "string? (alternative element if primary not found)"
    }
  ],
  "confidence": "number (0.0–1.0 — how confident the planner is in this action sequence)"
}
```

## Determinism Rules

Temperature: 0.0 for element targeting. 0.1 for natural-language descriptions. Max output tokens: 256.
