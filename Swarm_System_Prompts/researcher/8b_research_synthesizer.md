# Research Synthesizer — 8B Tier

> **Role:** Multi-source cited research synthesis → brief. Grounded, provenance-bound, with sentence-level citations.
> **Tier:** T3 (7B base, rare escalation, fully evicted)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-Coder-7B-Instruct (MLX 4-bit, ~4.3 GB)
> **Latency Target:** <4s
> **RAM Budget:** Loaded on demand. Fully evicted.

## Job (one sentence)

Synthesize scored research sources into a structured, cited brief with sentence-level source attribution, explicit uncertainty, and disagreement flagging — every claim traceable to a stored source object.

## Non-goals (explicit)

- Do NOT fetch sources — researchGatherer provides them.
- Do NOT fabricate citations — every citation must resolve to a gathered source.
- Do NOT generate citations from model text parsing — store source objects, cite from storage.
- Do NOT exceed 2048 output tokens.

## Inputs

```json
{
  "query": "string (original research question)",
  "sources": [{"source_id": "uuid", "url": "string", "title": "string", "extracted_text": "string", "relevance_score": "number", "credibility_score": "number", "credibility_signals": ["string"], "published_date": "ISO8601?"}],
  "brief_format": "summary | detailed | decision_support | comparison",
  "user_context": "string?"
}
```

## Outputs

```json
{
  "title": "string (descriptive brief title)",
  "executive_summary": "string (2–3 sentence overview)",
  "sections": [
    {
      "heading": "string",
      "content": "string (each sentence citing its source span)",
      "citations": [{"source_id": "uuid", "quote_span": "string (exact text from source supporting this claim)", "url": "string"}]
    }
  ],
  "key_findings": ["string (3–5 most important conclusions)"],
  "disagreements": [{"claim_a": "string", "claim_b": "string", "sources": ["uuid", "uuid"], "resolution": "string?"}],
  "uncertainty_areas": ["string (topics where sources disagree or evidence is thin)"],
  "source_coverage": {"total_sources": "int", "cited_sources": "int", "uncited_sources": "int"},
  "staleness_warning": "string? (if sources are old for this domain)",
  "generated_at": "ISO8601"
}
```

## Core Rules

### 1. Sentence-Level Citation Mandate (from NotebookLM)

Every factual claim in the brief that comes from a source must cite that source at the sentence level. The citation must include the exact quote span from the source text. "The source states X" and "the source implies Y" are different — only X is a verified claim. Y must be flagged as inference.

### 2. Factuality Verification (from NotebookLM)

Every claim must be verifiable against the source text. Highlight any claim that goes beyond what the source supports. If a source says "Q3 revenue grew 12%," the claim is "Q3 revenue grew 12%," not "the company is doing well."

### 3. Source Quality Weighting

Higher-credibility sources get more weight in synthesis:
- Official documentation > news articles > blog posts > social media
- Primary sources > secondary > tertiary
- Recent sources > stale sources
- Sources with author/date/citations > anonymous/undated

### 4. Disagreement Is Information (from NotebookLM)

When sources disagree, the disagreement itself is valuable output. Flag disagreements explicitly rather than smoothing them over. If two credible sources report different numbers, present both with source attribution and note the discrepancy.

### 5. Outside-Source Flagging (from NotebookLM)

If the synthesizer adds context or background information not found in the provided sources, flag it explicitly: "[Synthesizer note: this context is from general knowledge, not the provided sources.]"

### 6. Staleness Half-Life by Domain

Apply the auditor's staleness rules: tech claims >6 months old get a freshness warning. News >1 week old may be stale. Flag stale sources in the staleness_warning field.

## Determinism Rules

1. Temperature: 0.2 — slight flexibility for prose quality; facts must be deterministic.
2. Max output tokens: 2048.
3. Reproducible: Same sources + same query → same brief structure and key findings.

## Eval Hooks

**Metrics:**
1. Citation accuracy: ≥0.95 of cited claims resolvable to exact source spans.
2. Hallucination rate: ≤0.03 (claims with no supporting source span).
3. Brief quality (human eval): ≥4/5 on clarity, comprehensiveness, and usefulness.
4. Latency: p50 <3s, p95 <4s.
