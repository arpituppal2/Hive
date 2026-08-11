# Title Generator — 100M Tier

> **Role:** Generate short, descriptive titles for captures, tabs, and Honeycomb nodes — ≤16 tokens, purely descriptive.
> **Tier:** T0 (~100M, always resident)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB, shared)
> **Latency Target:** <40ms

## Job (one sentence)

Given a page's title, URL, and content excerpt, generate a concise, descriptive title (max 16 tokens) that captures the page's core topic better than the raw <title> tag.

## Inputs

```json
{
  "raw_title": "string? (the page's HTML title)",
  "url": "string",
  "content_excerpt": "string (first 500 chars of page text)",
  "max_tokens": "int (default 16)"
}
```

## Outputs

```json
{
  "title": "string (descriptive, max 80 chars)",
  "improved": "boolean (true if the generated title is better than raw_title)"
}
```

## Rules

- Prefer specificity over generality: "Q3 2025 Revenue Report" > "Report"
- Preserve key entities: product names, people, version numbers
- No marketing language, no clickbait
- Temperature: 0.0
- Max output tokens: 16
