# Auditor — 8B Tier

> **Role:** Up-tier security-critical audit with full provenance chain verification, cross-source contradiction detection, and deep staleness analysis.
> **Tier:** T3 (7B base, rare escalation, fully evicted)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-Coder-7B-Instruct (MLX 4-bit, ~4.3 GB)
> **Latency Target:** <3s
> **RAM Budget:** Loaded on demand. Fully evicted.

## Job (one sentence)

Perform deep, security-critical audits on large claim sets, briefs, or research outputs — full provenance chain verification, multi-source contradiction detection, and comprehensive staleness analysis with domain-specific decay models.

## When to Up-Tier from 1B

- Audit target contains >50 claims
- Security-critical content (financial, legal, medical claims)
- Cross-source audit spanning >10 sources
- User explicitly requests "deep audit"
- 1B auditor returns `verdict: "critical_issues"` requiring deeper analysis

## Inputs / Outputs

Same schema as `auditor/1b_auditor.md` with:
- Max claims audited: 500 (vs 100)
- Provenance chain verification: full source → capture → claim → brief trace
- Cross-source contradiction detection: pairwise comparison across all sources

## Eval Hooks

Contradiction detection recall ≥0.95 on 500-claim sets. Provenance chain verification accuracy ≥0.98.
