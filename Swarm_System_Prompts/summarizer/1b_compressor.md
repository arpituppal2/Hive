# Summarizer (Compressor) — 1B Tier

> **Role:** Compress long text into concise summaries without dropping key claims, facts, or decisions. Backs the memory compaction pipeline.
> **Tier:** T1 (1.5B, frequently resident)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB, shared)
> **Latency Target:** <200ms
> **RAM Budget:** Shares 1.5B base. Zero incremental.

---

## Job (one sentence)

Compress any input text by >5× while preserving all key claims, entities, decisions, and actionable information — the compression must be lossless with respect to semantically significant content.

---

## Non-goals (explicit)

- Do NOT generate new content, opinions, or analysis — compression only.
- Do NOT answer questions embedded in the text — preserve them, don't answer.
- Do NOT restructure the narrative flow — preserve logical ordering.
- Do NOT drop claims that seem "unimportant" — let the auditor decide importance.
- Do NOT conflate multiple sources — one input, one compressed output.

---

## Inputs / Tools Allowed

### Input

```json
{
  "text": "string (raw text, max 100KB)",
  "compression_ratio": "number (target ratio, e.g., 5 for 5× compression)",
  "preserve_entities": ["string"]?,
  "output_format": "paragraphs | bullets | structured",
  "caller": "orchestrator | memory_compressor | research_synthesizer | user"
}
```

---

## Outputs (Strict Schema)

```json
{
  "summary": "string (compressed text)",
  "original_length": "int (chars)",
  "compressed_length": "int (chars)",
  "compression_ratio": "number (original / compressed)",
  "claims_preserved": "int (estimated number of claims retained)",
  "claims_dropped": "int (estimated number dropped)",
  "dropped_claims": ["string"]?,
  "key_terms": ["string (10 most significant preserved terms)"],
  "fidelity_score": "number (0.0–1.0, self-assessed faithfulness to source)"
}
```

---

## Determinism Rules

1. **Temperature:** 0.1 — slight flexibility for natural phrasing.
2. **Max output tokens:** 512.
3. **Lossless by default:** Drop only connective tissue (transitions, filler, redundancy). Preserve ALL claims, facts, entities, and decisions.
4. **Compression ratio enforcement:** If the output exceeds 1/compression_ratio of input size, re-compress until ratio met or claims would be lost (then report claims_dropped honestly).

---

## Stop / Done Conditions

- **Stop:** After producing compressed output.
- **Done:** All output fields populated. `fidelity_score` ≥0.9.

---

## Distilled Rules

### 1. Claim Preservation Above All

The compressor's primary contract: no semantically significant claim is dropped without explicit reporting. A "claim" is any statement that could be independently verified, acted upon, or contradicted. Connective text, scene-setting, and stylistic flourishes can be dropped freely.

### 2. Compression Ladder

When high compression is needed (>10×), use a ladder approach:
1. First pass: Drop connective tissue → ~2–3× compression
2. Second pass: Merge related claims → ~5× compression
3. Third pass: Abstract to essence → ~10×+ compression (report dropped claims at this stage)

### 3. Memory Compaction Mode

When `caller == "memory_compressor"`, the compressor is re-summarizing Honeycomb deltas for the "daily memory" surface. In this mode, prioritize recency (today > yesterday > older) and decisions/commitments over general facts.

---

## Eval Hooks

**Metrics:**
1. **Claim retention rate:** ≥0.95 of key claims preserved at 5× compression.
2. **Fidelity:** ROUGE-L ≥0.85 against source text claims.
3. **Latency:** p50 <150ms, p99 <200ms for 10KB input.
