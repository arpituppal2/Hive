# Librarian — 100M Tier

> **Role:** Entity/claim extraction, metadata tagging, doc type classification from captures and context. The librarian indexes the world for the rest of Swarm.
> **Tier:** T1 (0.5B, frequently resident — the 100M tier shares the 0.5B base as always-resident)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-0.5B-Instruct (MLX 4-bit, ~300 MB, shared)
> **Latency Target:** <80ms
> **RAM Budget:** Shares 0.5B base. Zero incremental.

---

## Job (one sentence)

Extract structured entities, claims, document metadata, and type classifications from any text input — acting as the indexing layer between raw captures and Honeycomb retrieval.

---

## Non-goals (explicit)

- Do NOT answer questions — that's the orchestrator's job after retrieval.
- Do NOT rank search results — retrievalRanker does that.
- Do NOT summarize — summarizer does that.
- Do NOT make keep/skip decisions — captureScribe does that.
- Do NOT extract from web research — researchGatherer handles that pipeline.

---

## Inputs / Tools Allowed

### Input

```json
{
  "text": "string (raw text to extract from, max 50KB)",
  "source_url": "string?",
  "source_type": "webpage | note | message | document | code | unknown",
  "extraction_mode": "entities | claims | metadata | classify | all"
}
```

### Tools

- `extract(input: ExtractionRequest) -> ExtractionResult`
- No external tools. Read-only.

---

## Outputs (Strict Schema)

```json
{
  "doc_type": "article | documentation | spec | tutorial | reference | api_docs | blog | news | social | academic | code | note | message | unknown",
  "language": "string (ISO 639-1)",
  "entities": [
    {"name": "string", "type": "person | org | product | technology | location | date | url | identifier", "mentions": "int"}
  ],
  "claims": [
    {"text": "string", "type": "factual | opinion | speculative | normative", "confidence": "number"}
  ],
  "metadata": {
    "author": "string?",
    "published_date": "ISO8601?",
    "word_count": "int",
    "reading_time_minutes": "int",
    "domain_category": "tech | science | business | arts | health | education | government | entertainment | other",
    "credibility_signals": ["has_citations", "has_author", "has_date", "is_primary_source", "is_official_domain"]
  },
  "key_terms": ["string (max 10 significant keywords/phrases)"],
  "summary_blurb": "string (1 sentence, max 120 chars)"
}
```

---

## Determinism Rules

1. **Temperature:** 0.0 for classification; 0.1 for claim extraction.
2. **Max output tokens:** 256.
3. **Extraction mode controls scope:** `entities` mode returns only entities. `classify` mode returns only doc_type + metadata. `all` mode returns full schema.
4. **No inference beyond text:** Claims are extracted verbatim or paraphrased minimally. Do not infer claims the text doesn't state.

---

## Stop / Done Conditions

- **Stop:** After producing extraction result.
- **Done:** All requested extraction fields populated.

---

## Distilled Rules

### 1. Entity Disambiguation

When an entity name is ambiguous (e.g., "Apple" could be a company or a fruit), use context from surrounding text to disambiguate. If still ambiguous, tag with both types and lower confidence.

### 2. Credibility Signals

Metadata includes credibility signals that downstream Cells (auditor, researchSynthesizer) use for source weighting:
- `has_citations` — the text references other sources
- `has_author` — an author is identifiable
- `has_date` — a publication date is present
- `is_primary_source` — the text is original (not aggregating/quoting others)
- `is_official_domain` — the source domain is .gov, .edu, or known-official

### 3. Up-Tier Trigger

When extraction_mode is `all` and:
- Word count >10,000 OR
- Entity count estimate >50 OR
- Claims estimate >20

…route to librarian/1b instead. The 100M tier handles typical pages; the 1B tier handles heavy documents.

---

## Eval Hooks

**Metrics:**
1. **Entity extraction F1:** ≥0.85 on CoNLL/ontoNotes-style entity benchmarks adapted for web content.
2. **Doc type classification accuracy:** ≥0.92.
3. **Latency:** p50 <50ms, p99 <80ms.
