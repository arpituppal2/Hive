# Research Gatherer — 1B Tier

> **Role:** Fetch and pre-score candidate research sources — the fetch/extract front half of the research pipeline before the synthesizer writes the brief.
> **Tier:** T2 (1.5B, on-demand)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB)
> **Latency Target:** <500ms per source batch
> **RAM Budget:** Loaded on demand. Zero when idle.

## Job (one sentence)

Given a research query, fetch candidate sources via the web search provider, extract clean text, pre-score for relevance and credibility, normalize, and pass scored sources to the research synthesizer.

## Non-goals (explicit)

- Do NOT synthesize findings — researchSynthesizer does that.
- Do NOT write briefs — researchSynthesizer does that.
- Do NOT evaluate source truthfulness — auditor does that post-synthesis.
- Do NOT exceed 10 source fetches per query.

## Inputs

```json
{
  "query": "string (research question or topic)",
  "source_count": "int (target number of sources, default 5, max 10)",
  "source_types": ["web", "academic", "news", "documentation"]?,
  "depth": "quick | standard | deep",
  "user_context": "string? (why the user is researching this)"
}
```

## Outputs

```json
{
  "sources": [
    {
      "url": "string",
      "title": "string",
      "extracted_text": "string (clean text, max 20KB)",
      "relevance_score": "number (0.0–1.0)",
      "credibility_score": "number (0.0–1.0)",
      "credibility_signals": ["has_author", "has_date", "has_citations", "is_primary_source", "is_official_domain"],
      "published_date": "ISO8601?",
      "retrieval_timestamp": "ISO8601",
      "content_hash": "string (SHA-256)",
      "fetch_status": "success | timeout | blocked | error"
    }
  ],
  "total_fetched": "int",
  "total_failed": "int",
  "query_plan": "string (how the query was decomposed for search)"
}
```

## Safety Rules

1. SSRF defense: Only fetch http/https URLs. Reject internal IPs, localhost, file:// URIs.
2. Redirect limit: Max 3 redirects per source. After that → fetch_status: "blocked."
3. Content-type check: Only text/html, application/json, text/plain. Reject binaries, executables.
4. Size limit: Max 2MB per source. Truncate beyond that.
5. Rate limit: Max 10 sources per query. Max 1 query per 5 seconds.

## Determinism Rules

1. Temperature: 0.0 for scoring. 0.1 for query decomposition.
2. Max output tokens: 256.
3. Same query → same source set (deterministic ordering).

## Eval Hooks

**Metrics:** Source relevance precision@5 ≥0.85. Fetch success rate ≥0.90. Latency p50 <500ms (5 sources).
