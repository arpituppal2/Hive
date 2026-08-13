# Link Scorer — 1B Tier

> **Role:** Rank candidate links/sources for retrieval before the reasoner sees them — the gatekeeper of source quality.
> **Tier:** T1 (0.5B base, frequently resident)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB, shared)
> **Latency Target:** <50ms
> **RAM Budget:** Shares 0.5B base. Zero incremental.

## Job (one sentence)

Score and rank up to 20 candidate URLs/sources given a search query, returning ordered results with composite relevance × credibility scores.

## Non-goals (explicit)

- Do NOT fetch page content — researchGatherer does that.
- Do NOT extract claims from scored sources — librarian does that.
- Do NOT synthesize — researchSynthesizer does that.
- Do NOT make keep/skip decisions on individual sources — return scores; consumer decides threshold.

## Inputs

```json
{
  "query": "string (user's search/research query)",
  "candidates": [{"url": "string", "title": "string", "snippet": "string", "domain": "string"}],
  "max_results": "int (default 10)"
}
```

## Outputs

```json
{
  "scored_links": [
    {
      "url": "string",
      "title": "string",
      "composite_score": "number (0.0–1.0)",
      "relevance_score": "number (0.0–1.0)",
      "credibility_score": "number (0.0–1.0)",
      "freshness_score": "number (0.0–1.0)",
      "diversity_penalty": "number (0.0–1.0 multiplier)",
      "reason": "string (max 60 chars — why this score)"
    }
  ],
  "status": "ok | blocked (no relevant sources found)"
}
```

## Scoring Rules

**Relevance (40%):** Query-term overlap, semantic similarity, snippet relevance to query intent.
**Credibility (35%):** Domain authority (.gov > .edu > known-org > .com), has author/date/citations signals, not known-fake-news domain.
**Freshness (15%):** Recency of publication (if detectable). Fresh > 1yr > 5yr > undated.
**Diversity penalty (10%):** After first result from same domain, reduce each subsequent same-domain result by 0.05.

**All candidates scored near zero** — If every candidate has composite <0.3, return `status: "blocked"` with reason: "no relevant sources found."

## Determinism Rules

1. Temperature: 0.0
2. Max output tokens: 16 per candidate
3. Same candidates + same query → identical ranking (deterministic)

## Eval Hooks

**Metrics:** NDCG@10 ≥0.85 vs human-ranked relevance. Latency p50 <30ms, p99 <50ms.
