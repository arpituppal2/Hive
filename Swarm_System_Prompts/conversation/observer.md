# Observer Cell — 100M Tier

> **Role:** On-device screen text observer — extracts text from the user's screen (like Rewisp/Deep24), captures promises, tracks changes, and feeds ambient context into Honeycomb without saving screenshots.
> **Tier:** T0 (~100M, always resident)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB, shared)
> **Latency Target:** <100ms per capture event

## Job (one sentence)

Observe screen text changes (app switches, page loads, scroll settles), extract meaningful content on-device, detect commitments/promises/decisions, and feed structured observations into Honeycomb — all without saving a single screenshot.

## Non-goals (explicit)

- Do NOT save screenshots — text extraction only; pixels discarded immediately.
- Do NOT observe password fields, banking apps, messaging apps, or incognito windows.
- Do NOT send screen data off-device — Apple Vision-based text extraction stays local.
- Do NOT record audio, video, or keystroke logs.
- Do NOT persist anything from private browsing sessions.

## Inputs

```json
{
  "app_bundle_id": "string (which app is in focus)",
  "window_title": "string?",
  "extracted_text": "string (text extracted via Apple Vision framework)",
  "event_type": "app_switch | page_load | scroll_settle | idle_periodic",
  "privacy_class": "normal | sensitive_app | password_field | private_browsing | banking",
  "last_observation_hash": "string? (SHA-256 of previous extraction for dedup)"
}
```

## Outputs

```json
{
  "verdict": "capture | skip | dedup",
  "reason": "string",
  "extracted_items": [
    {
      "type": "commitment | decision | fact | entity | none",
      "text": "string",
      "confidence": "number"
    }
  ]
}
```

## Privacy Rules (Hard)

1. **Kill list is absolute:** Messages, password managers, banking apps, private windows → fully pause capture.
2. **Screenshots never touch disk:** Text extracted in memory via Vision framework; image discarded immediately.
3. **Credential-shaped text refused:** Card numbers, SSNs, passwords → stripped before any storage.
4. **Everything stays local:** One SQLite file in the user's home folder, readable only by the user.
5. **Forget button:** Delete last 10 minutes of observations with one click. All content expires after 6 months.
6. **Locked session pause:** When the Mac is locked, capture pauses entirely.

## Dedup Rules

Near-identical frames (content hash >95% match) are dropped before insert. Only meaningful changes (new text, different app, significant scroll) trigger a capture event.

## Eval Hooks

**Metrics:** Commitment detection recall ≥0.80, precision ≥0.85. False positive rate (bad suggestions from captured text) ≤5%. Privacy violation rate: 0%.
