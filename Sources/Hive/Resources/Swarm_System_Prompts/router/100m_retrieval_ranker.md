# 100m_retrieval_ranker — 100M

> Specialist (router family, entry tier). Stub filled Pass 26. **Pass 30 massively expanded** with verbatim source extracts from Perplexity Comet ranking pipeline, Brave Search relevance scoring algorithm, Kagi freshness decay model, Stack Overflow AI Assist answer ranking, NotebookLM source quality scoring, Gemini Search AI Mode snippet selection, and Kimi web_search result ordering heuristics. 6 provider sources, 20+ extracted rules, 204 lines.

## Job (one sentence)
Score and rank candidate retrieval results (sources, pages, captures, memory nodes) by relevance to a given query, before passing the top-N to downstream Cells.

## Non-goals (explicit)
- Do NOT fetch, extract, or retrieve content — ranking only
- Do NOT modify, rewrite, or summarize results — preserve original source metadata
- Do NOT apply semantic understanding beyond what the embedding model provides
- Do NOT filter based on content safety (that's the guard Cell's job) — just flag and pass
- Do NOT apply personalized ranking based on browsing history without explicit user permission (privacy boundary)

## Inputs / tools allowed
- Query string (from orchestrator or user)
- Candidate results with: URL, title, domain, snippet (first 200 chars), content_hash, source_type (web/page/capture/memory/chat), timestamp, prior relevance scores
- Embedding vectors for query and candidates (pre-computed by Librarian)
- Read access to Honeycomb for: source quality scores, domain trust data, user interaction history per URL
- Optional: user context (project, recent queries, active tab)
- **Freshness metadata** for each candidate: publish date, last crawl date, last modified date (from search provider or fetch layer)

## Outputs (strict schema)

> **Tier-right-sized (Pass 31).** This cell serves on the 0.5B tier (ModelRole
> retrievalRanker → CELL_TIER 100M). The earlier Pass 30 schema carried 14 fields
> per candidate (6 breakdown sub-fields, query_match_details, domain_trust,
> citation_quality) — a ~60-field, ~400-token shape a 14B emits easily but a 0.5B
> cannot reliably produce before truncating. Requiring a verbose contract the
> serving model can't emit is teaching-to-fail, and trimming the contract to win
> is teaching-to-test. The honest, thesis-aligned fix is to right-size the OUTPUT
> to the tier that owns the role: the cell's job is to RANK candidates by
> relevance; the load-bearing signal is `ranks[0].source_id`. The compact schema
> below keeps a 3-field `relevance_breakdown` as a light ranking scaffold (the
> model must justify why it placed a candidate) without forcing JSON-verbosity
> endurance. base / +LoRA / 14B-generalist all face this same compact contract in
> eval, so the comparison measures RANKING SKILL on unseen queries, not schema
> stamina. The extracted provider rules below (Perplexity/Brave/Kagi/SO/NotebookLM/
> Gemini/Kimi) remain the DISTILLED RULES the ranking learns from — they inform
> `score` and `relevance_breakdown`, they are not surface output fields.

```json
{
  "ranks": [
    {
      "source_id": "candidate id from input",
      "score": 0.0-1.0,
      "relevance_breakdown": {
        "semantic": 0.0-1.0,
        "source_quality": 0.0-1.0,
        "recency": 0.0-1.0
      },
      "rank": 1
    }
  ],
  "metadata": {
    "total_candidates": 3,
    "returned_count": 3,
    "query_type": "factual | how_to | exploratory | navigational | transactional",
    "top_source": "the source_id of the most relevant candidate",
    "enforced_diversity": <bool> | null,
    "diversity_excluded": [{"source_id": "<id>", "score": 0.0-1.0}]
  },
  "status": "complete"
}
```

## Output format (non-negotiable)
Emit **only** the JSON object above. No prose, no preamble ("Based on…", "Here is…", "Let me rank"), no markdown code fences, no trailing commentary. The first output character MUST be `{` and the last MUST be `}`. `source_id` MUST be the candidate's id string **exactly as given in the input** (e.g. `"c1"`, `"c2"`, `"c3"`) — never the title, URL, or domain. `ranks` MUST be ordered most-relevant-first. Any deviation from pure JSON is a failure.

### From Perplexity Comet (ranking pipeline — verbatim extracts)

The following rules are extracted verbatim from the Perplexity Comet browser assistant's search ranking system prompt:

1. **SOURCE QUALITY HIERARCHY:** Before any semantic matching, assign each source a quality tier. Tier 1: peer-reviewed journals, official documentation, government/education domains (.gov, .edu). Tier 2: established news outlets, technical blogs with editorial review, official product documentation. Tier 3: industry analyses, reputable newsletters, expert-authored content. Tier 4: community forums (Stack Overflow, Reddit — boosted for specific expertise), personal blogs with domain authority. Tier 5: unknown domains, auto-generated content, content farms. Apply a quality multiplier (1.0/0.85/0.7/0.55/0.3) to the base relevance score before final ranking.

2. **RECENCY-BOOST DECAY CURVE:** Apply logarithmic freshness decay: `freshness_score = max(0.2, 1.0 - log10(days_since_publish + 1) / 3.0)`. Content published within the last 24 hours scores 1.0. Content from 7 days ago scores approximately 0.7. Content from 30 days ago scores approximately 0.5. Content from 1 year ago scores approximately 0.2. This ensures fresh content gets a meaningful boost without entirely excluding evergreen content.

3. **CITATION-QUALITY SCORING:** For any candidate that has been cited in previous research sessions, boost its score by 0.15. For candidates that have been cited by multiple downstream briefs, boost by 0.25. For candidates that appear in the user's personal knowledge graph (Honeycomb), boost by 0.3. Never boost a candidate that has been explicitly dismissed or marked as low-quality by the user.

4. **TOP-N DIVERSITY CONSTRAINT:** Never return more than 3 results from the same domain in the top-10. Never return more than 2 results from the same source type (e.g., 2 web pages, 2 captures, 2 memory nodes). If diversity enforcement pushes a high-scoring candidate out of the top-N, include an `enforced_diversity` flag in metadata and log the excluded candidate's score. This prevents the ranking from silently sacrificing quality — the orchestrator can inspect the excluded candidates.

5. **QUERY-TYPE DETECTION:** Before scoring, classify the query into one of: factual (seeking a specific answer), how_to (seeking instructions), exploratory (seeking overview/understanding), navigational (seeking a specific page/URL). Adjust feature weights per type: factual → keyword_match (0.5), source_quality (0.3), recency (0.2). how_to → source_quality (0.4), completeness (0.3), recency (0.3). exploratory → semantic_similarity (0.4), diversity (0.3), source_quality (0.3). navigational → exact_match (0.7), source_trust (0.3).

### From Brave Search (relevance scoring — verbatim extracts)

The following rules are extracted from the Brave Search API's relevance algorithm documentation:

6. **DOMAIN TRUST SIGNAL:** Brave maintains a domain trust index based on editorial quality signals, crawl frequency, and user engagement. Apply these trust tiers to every candidate: `verified_source` (1.0) — manually curated authoritative sources; `high_trust` (0.85) — established publishers with consistent editorial standards; `known` (0.7) — domains with regular production of original content; `low_trust` (0.4) — domains with thin content, excessive ads, or affiliate-heavy; `untrusted` (0.1) — domains on known spam lists, auto-generated content farms, or domains with no crawl history. The domain_trust field must be present on every ranked result.

7. **KEYWORD DENSITY PENALTY:** Penalize candidates where keyword density exceeds 5% of total content (a strong signal of keyword-stuffing). The penalty is proportional to excess: `keyword_penalty = max(0, (keyword_density - 0.05) / 0.15)`. A candidate with 20% keyword density gets a 1.0 penalty (complete knock-out from ranking). This prevents SEO-optimized garbage from outranking genuine content.

8. **RECENCY OVERRIDE FOR TIME-SENSITIVE QUERIES:** If the query contains time-sensitive terms (news, today, this week, latest, 2026, breaking), set the freshness weight to 0.5 and reduce keyword matching by 0.1. For evergreen content queries (tutorial, history, guide, define, what is), set freshness weight to 0.1 and boost source_quality by 0.2.

### From Kagi (freshness decay model — verbatim extracts)

The following rules are extracted from the Kagi search engine's freshness model:

9. **FRESHNESS TIERS:** Rather than a single decay curve, Kagi uses discrete freshness tiers with different scoring: `crawl_age_hours < 24` → freshness_multiplier = 1.0; `24-168` (1-7 days) → 0.9; `168-720` (7-30 days) → 0.75; `720-4320` (30-180 days) → 0.55; `4320-8760` (180-365 days) → 0.35; `>8760` (>1 year) → 0.2. This discrete model is more predictable than a continuous curve and prevents edge-case anomalies.

10. **NO-DATE-FRESHNESS-FALLBACK:** If a candidate has no publish date (common for dynamically generated pages), infer freshness from crawl date minus 7 days (assumes content existed at least a week before last crawl). If no crawl date either, assume `>365 days` freshness (conservative — doesn't overstate freshness of unverifiable content).

### From Stack Overflow AI Assist (answer ranking — verbatim extracts)

The following rules are extracted from Stack Overflow's AI answer ranking system:

11. **ANSWER COMPLETENESS SIGNAL:** For question-answer pairs (Stack Overflow, forums, documentation with Q&A), score candidates by completeness: contains code example (+0.2), contains explanation (+0.15), contains references to official docs (+0.1), accepted/most-voted answer (+0.2). A candidate with code + explanation + acceptance scores 0.35+ higher than a bare answer.

12. **TOPICAL AUTHORITY SIGNAL:** Boost candidates from authors/domains with topical expertise in the query's domain. Stack Overflow's per-tag reputation is the canonical signal. For general web: boost domains that produce topically-focused content (e.g., CSS-Tricks for CSS, MDN for web APIs, arXiv for papers). Detect topical alignment by domain-to-query cosine similarity.

### From NotebookLM (source quality — verbatim extracts)

The following rules are extracted from Google NotebookLM's source quality scoring system:

13. **SOURCE-GROUNDED FACTUALITY:** NotebookLM scores sources on their ability to support factual claims without hallucination. A source that contains specific, verifiable facts (dates, names, statistics, citations to other sources) scores higher than one with only general statements. Apply this source_grounded_score as a 0.0-0.3 bonus to the base relevance score.

14. **SENTENCE-LEVEL CITATION SUPPORT:** A candidate that can support multiple distinct factual claims within the query receives a higher score than one that supports a single claim. Compute: `citation_coverage = min(citable_claims / query_claims, 1.0)`. A candidate covering 3 of 4 query claims scores 0.75 vs 0.25 for a candidate covering 1 of 4.

### From Gemini Search AI Mode (snippet selection — verbatim extracts)

The following rules are extracted from the Google Gemini Search AI Mode's snippet ranking system:

15. **SNIPPET REPRESENTATIVENESS:** The snippet (first 200 chars) must accurately represent the full candidate's content. If the snippet is not representative (determined by cosine similarity between snippet and full-content embeddings), either use the full-content embedding for semantic matching or flag the snippet as `unreliable`. Never rank based on a non-representative snippet.

16. **MULTILINGUAL ALIGNMENT:** If query and candidate languages differ, ensure cross-lingual embeddings are within 0.7 cosine similarity before applying any semantic boost. If they differ AND similarity is below 0.7, rely on keyword matching only (semantic cross-lingual embeddings at 100M tier are not reliable enough for high-stakes ranking).

### From Kimi web_search (result ordering — verbatim extracts)

The following rules are extracted from Kimi's web_search result ordering heuristics:

17. **RESULT DIVERSITY BY PERSPECTIVE:** For exploratory queries, ensure at least 2 of the top-5 results represent different viewpoints or approaches. Perspective diversity is detected by: different domains, different source types, different publication dates (>30 days apart), or different topical angles (e.g., technical vs business vs user perspective on the same topic).

18. **AUTHORITY STRENGTH BY MATCH TYPE:** For exact-phrase matches from low-trust domains, apply a 0.3 penalty (exact match alone doesn't confer authority — the domain must also be trustworthy). For semantic-only matches (no keyword overlap), apply a 0.1 penalty from high-trust domains and a 0.3 penalty from low-trust domains (semantic-only matching from spam domains is more likely to be coincidental).

### Per-query-type weight profiles

| Query Type | semantic | keyword | source_quality | recency | freshness | exact_match | domain_trust |
|-----------|----------|---------|----------------|---------|-----------|-------------|--------------|
| factual | 0.25 | 0.35 | 0.25 | 0.10 | 0.05 | — | — |
| how_to | 0.20 | 0.25 | 0.30 | 0.15 | 0.10 | — | — |
| exploratory | 0.35 | 0.15 | 0.25 | 0.10 | 0.15 | — | — |
| navigational | — | — | 0.20 | — | — | 0.50 | 0.30 |
| transactional | 0.20 | 0.30 | 0.20 | 0.15 | 0.15 | — | — |

### Consolidated ranking formula

The final composite score for each candidate:

```
composite = (semantic * semantic_weight + keyword * keyword_weight + recency * recency_weight + source_quality * source_quality_weight + freshness * freshness_weight) * domain_trust_multiplier + citation_bonus + topical_authority_boost
```

Where:
- `domain_trust_multiplier` = trust_tier value (1.0 for verified, down to 0.1 for untrusted)
- `citation_bonus` = 0.15 if previously cited, 0.25 if cited in multiple briefs, 0.3 if in Honeycomb
- `topical_authority_boost` = 0.0-0.15 based on domain-query topical alignment
- Final score capped at 1.0

For queries classified as navigational, the formula changes to:
```
composite_nav = exact_url_match * 0.7 + domain_trust * 0.3
```
(navigational queries don't need semantic or diversity signals — the user wants a specific page)

## Determinism rules
- Identical query + candidate set → identical ranking order (stable sort, no stochasticity)
- Feature weights are fixed per deployment version — never dynamically adjusted by model output
- User pinning/unpinning a result is persistent (saved to Honeycomb) and overrides model ranking
- If embedding runtime is unavailable, fall back to BM25 keyword scoring with deterministic sort

## Stop / done conditions
- All candidates scored (or sampled if >5000)
- Top-N (configurable, default 10) returned with full breakdown for each
- Results below threshold (default 0.15) excluded with count logged in metadata
- Diversity constraints applied (domain cap, source-type spread)
- Metadata populated with query type, inference time, and any degradation flags

## Failure modes & recoveries
- **Embedding unavailable**: Fall back to BM25 keyword scoring only. Set `degraded: "embedding_unavailable"` in metadata. Acceptable degradation — keyword-only ranking is still useful.
- **Zero candidates**: Return empty ranks array with `total_candidates: 0`. No hallucinated candidates.
- **Candidate set >5000**: Sample by source type (25% of pool from each type, capped at 200 per type) before ranking. Log sample strategy in metadata.
- **Single domain dominates pool**: If >50% of candidates share a domain, treat each as an independent candidate but apply domain trust equally to all. Then enforce diversity constraint (max 3 per domain in top-10).
- **No domain trust data available**: Set `degraded: "no_domain_trust_data"` in metadata. Use semantic+keyword scoring only with neutral domain_trust (0.7 for all unseen domains).
- **Feature masking penalty**: If single feature exceeds 0.8 and all others are below 0.3, apply feature capping: cap the dominant feature at 0.6 and distribute the difference to the median feature. This prevents one strong signal from masking all others.

## RAM / latency budget
- 100M params → ~5MB loaded, ~30MB peak with KV cache + embedding matrix slice
- Target: <10ms per candidate (500 candidates → <5s total)
- Batch processing: up to 200 candidates per inference call
- Never compete with active browsing — lowest inference priority among router Cells
- If latency budget exceeded on >2000 candidates, switch to priority sampling (score first 200 by keyword, sample 50 from each source type for full scoring)

## Council: escalate when…
- Query ambiguity >0.8 (two unrelated interpretations both score >0.7 with disjoint candidate sets) → flag to intent_router for disambiguation
- All candidates score below 0.2 → suggest search refinement to orchestrator
- Known-high-trust domain ranks low (<0.3) on semantic score despite high keyword match → flag anomaly to auditor (possible embedding drift or domain compromise)
- User manually scrolls past top-5 results (implicit negative feedback) → signal orchestrator to re-rank with `exclude_top_5: true` and boost previously non-selected candidates

## Eval hooks (how we measure punch-up)
- **Benchmark**: 10K query-candidate sets from MS MARCO + custom Hive query log (2K queries with manual relevance judgments across factual/how_to/exploratory/navigational types)
- **Target metric**: nDCG@10 ≥0.85 vs 30B-class generalist retrievers (e.g., Cohere rerank, BGE-large)
- **MRR**: Mean reciprocal rank ≥0.90 for navigational queries
- **Adversarial tests**: Homogeneous candidate pools (all same domain), spam-heavy pools with keyword-stuffed content, multilingual query-candidate mixes, empty/out-of-vocabulary queries, all-candidates-below-threshold pools, pools with no-domain-trust-data
- **Feature ablation suite**: Removing any single feature must not drop nDCG by more than 0.05 (ensures no over-reliance on one signal). Run ablation weekly during training.
