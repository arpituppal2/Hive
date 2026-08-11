# Page Q&A — 100M Tier

> **Role:** Grounded question-answering over the current page's content — Arc/Comet "ask on this page" parity.
> **Tier:** T0 (~100M, always resident)
> **Serving Strategy:** `instructOffTheShelf` (held-out-distill candidate; stays OTS until eval proves gain)
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB, shared)
> **Latency Target:** <30ms
> **RAM Budget:** Shares 0.5B base. Zero incremental.

---

## Job (one sentence)

Answer factual questions about the currently active page using only the page's extracted content — no web search, no Honeycomb, no model hallucination.

---

## Non-goals (explicit)

- Do NOT answer questions beyond the page's content — say "This page doesn't contain that information."
- Do NOT search the web or Honeycomb — page-only, grounded.
- Do NOT generate opinions, recommendations, or creative content — factual extraction only.
- Do NOT modify the page, click elements, or interact with the browser.
- Do NOT summarize the full page unless asked — answer the specific question.
- Do NOT exceed 128 output tokens.

---

## Inputs / Tools Allowed

### Input

```json
{
  "question": "string (the user's question about the page)",
  "page_content": {
    "url": "string",
    "title": "string",
    "text": "string (extracted clean text, max 10KB)",
    "ax_tree_summary": "string? (simplified AXTree for structure)"
  },
  "previous_qa": [{"question": "string", "answer": "string"}]?
}
```

---

## Outputs (Strict Schema)

```json
{
  "answer": "string (concise, factual, max 200 chars)",
  "grounded": "boolean (true = answer found in page content; false = page doesn't contain this info)",
  "evidence_span": "string (exact text from page that supports the answer, if grounded)",
  "confidence": "number (0.0–1.0)",
  "not_found_reason": "string? (when grounded == false — why the page doesn't answer this)"
}
```

---

## Determinism Rules

1. **Temperature:** 0.0 — deterministic extraction, no creativity.
2. **Max output tokens:** 128.
3. **Grounded-only:** Every answer MUST cite an evidence span from the page text. If no evidence span exists, `grounded: false`.
4. **No extrapolation:** Do not infer beyond what the page states. "The page doesn't say" is a valid and preferred answer to "the page implies."
5. **Same question + same page → same answer:** Deterministic output for identical inputs.

---

## Stop / Done Conditions

- **Stop:** After producing answer or not-found response.
- **Done:** `answer` and `grounded` populated. If `grounded == true`, `evidence_span` must be non-null.

---

## Distilled Rules

### 1. Grounded-Only Extraction

The page Q&A Cell must never "hallucinate" answers. If the page text doesn't contain the information, say so clearly. This builds user trust: the user learns that when Hive says "the page says X," it's actually on the page.

**Rule:** Every positive answer cites exact page text. No answer without evidence.

### 2. Arc/Comet Parity

Arc's "Ask on Page" and Comet's page-aware Q&A set the user expectation: you should be able to ask "what does this page say about X" and get a grounded answer instantly. Hive matches this with a 100M Cell — sub-30ms, on-device, no API calls.

---

## Eval Hooks

**Test Suite:** 200 question-page pairs with gold answers and evidence spans.

**Metrics:**
1. **Answer accuracy:** ≥0.90 F1 against gold answers.
2. **Groundedness:** 0% hallucination rate (answers with `grounded: true` but no matching evidence span).
3. **Appropriate refusal:** ≥0.95 correct refusal rate (says "not on page" when truly not).
4. **Latency:** p50 <20ms, p99 <30ms.
