# Retrieval Ranker — 100M Tier

> **Role:** Rerank Honeycomb search results for the orchestrator/reasoner — selects the most relevant nodes from the knowledge graph for a given query.
> **Tier:** T0 (~100M, always resident)
> **Serving Strategy:** `instructOffTheShelf` (rule-rich × complex → LoRA HURTS; kept OTS)
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB, shared)
> **Latency Target:** <80ms
> **RAM Budget:** Shares 0.5B base. Zero incremental.

## Job (one sentence)

Given a query and up to 50 candidate Honeycomb nodes, rerank them by relevance, recency, and source credibility, returning the top-K most relevant nodes for downstream consumption.

## Non-goals (explicit)

- Do NOT fetch new content from the web — linkScorer + researchGatherer handle that.
- Do NOT summarize or synthesize nodes — summarizer and researchSynthesizer handle that.
- Do NOT modify Honeycomb — read-only ranking.
- Do NOT return more than `max_results` (default 10).

## Inputs

```json
{
  "query": "string (user's search query or intent description)",
  "candidates": [{"node_id": "uuid", "title": "string", "summary": "string", "tags": ["string"], "captured_at": "ISO8601", "credibility_signals": ["string"], "workspace_id": "uuid?"}],
  "max_results": "int (default 10)",
  "prefer_recent": "boolean (default true — bias toward recent captures)",
  "workspace_filter": "uuid? (only return nodes from this workspace)"
}
```

## Outputs

```json
{
  "ranked_nodes": [
    {
      "node_id": "uuid",
      "relevance_score": "number (0.0–1.0)",
      "reason": "string (max 80 chars — why this node ranks here)"
    }
  ],
  "status": "ok | no_results",
  "total_candidates": "int",
  "returned": "int"
}
```

## Scoring Logic

**Relevance (50%):** Query-to-node semantic match (title, summary, tags, key terms).
**Recency (25%):** Captured within: 1 day = 1.0, 1 week = 0.8, 1 month = 0.5, 6 months = 0.2, >1 year = 0.1.
**Credibility (15%):** Nodes with more credibility signals (has_citations, is_primary_source, etc.) score higher.
**Workspace affinity (10%):** Nodes from the user's current workspace get a boost.

## Determinism Rules

1. Temperature: 0.0
2. Max output tokens: 64
3. Same query + same candidates → identical ranking

## Eval Hooks

**Metrics:** NDCG@10 ≥0.88 vs human-ranked relevance. Latency p50 <50ms, p99 <80ms.
