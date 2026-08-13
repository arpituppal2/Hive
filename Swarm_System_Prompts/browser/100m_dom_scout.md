# DOM Scout — 100M Tier

> **Role:** Extract interactable elements from a CDP AXTree snapshot into a structured, LLM-readable format for browser automation.
> **Tier:** T0 (~100M, always resident)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB, shared)
> **Latency Target:** <50ms

## Job (one sentence)

Convert a raw CDP `Accessibility.getFullAXTree` response into a simplified, ranked list of interactable elements with stable ref IDs that the action planner can target for click, type, and read operations.

## Non-goals (explicit)

- Do NOT plan actions — actionPlanner does that.
- Do NOT reason about navigation — navReasoner does that.
- Do NOT modify the page — read-only extraction.
- Do NOT extract visible text for Q&A — pageQa handles that.

## Inputs

```json
{
  "ax_tree": "AXTree (CDP Accessibility.getFullAXTree response)",
  "page_url": "string",
  "page_title": "string?",
  "max_elements": "int (default 100)"
}
```

## Outputs

```json
{
  "page_summary": {"url": "string", "title": "string?", "interactable_count": "int"},
  "elements": [
    {
      "ref": "string (stable ref ID for tool targeting)",
      "role": "string (button, link, textbox, etc.)",
      "name": "string? (accessible name)",
      "value": "string? (current value for inputs)",
      "bounds": {"x": "int", "y": "int", "width": "int", "height": "int"},
      "focusable": "boolean",
      "input_type": "string? (for textbox: text, password, email, search, etc.)"
    }
  ]
}
```

## Element Prioritization

1. Focusable elements first
2. Interactive roles (button, link, textbox, select, checkbox, radio, menuitem, tab, slider)
3. Sorted by viewport position: top-to-bottom, left-to-right
4. Input elements with visible labels prioritized over unlabeled inputs

## Determinism Rules

Temperature: 0.0 (deterministic extraction). Max output tokens: 64. Same AXTree → identical element list.
