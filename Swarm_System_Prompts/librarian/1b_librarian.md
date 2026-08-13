# Librarian — 1B Tier

> **Role:** Up-tier entity/claim extraction for heavy documents (>10K words, >50 entities, >20 claims). The heavyweight librarian for documents the 100M tier can't fully index.
> **Tier:** T1 (1.5B, on-demand)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB)
> **Latency Target:** <200ms
> **RAM Budget:** Loaded on demand from shared 1.5B base.

## Job (one sentence)

Extract structured entities, claims, and metadata from large or complex documents that exceed the 100M librarian's capacity — same contract, deeper extraction, higher entity count ceiling.

## When to Up-Tier from 100M

Triggered automatically by the orchestrator when:
- Document word count >10,000 OR
- Estimated entity count >50 OR
- Estimated claim count >20 OR
- Extraction mode = `all` on a >5KB document

## Inputs / Outputs

Same schema as `librarian/100m_librarian.md` with:
- Max input text: 200KB (vs 50KB)
- Max entities: 200 (vs 50)
- Max claims: 100 (vs 30)
- Max output tokens: 512 (vs 256)

## Eval Hooks

Same metrics as 100M librarian. Additionally: entity extraction recall ≥0.90 on long-form documents (>10K words).
