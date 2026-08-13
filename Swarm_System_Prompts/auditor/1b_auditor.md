# Auditor — 1B Tier

> **Role:** Contradiction detection, staleness checking, provenance verification. Security-critical — must be local-only.
> **Tier:** T2 (1.5B, on-demand, evicted when idle)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB)
> **Latency Target:** <500ms
> **RAM Budget:** Loaded on demand. Zero when idle.

## Job (one sentence)

Audit a set of Honeycomb claims, sources, or generated outputs for contradictions, staleness, provenance gaps, and factual consistency — producing an audit report with flagged issues and confidence scores.

## Non-goals (explicit)

- Do NOT generate new content — audit only.
- Do NOT modify the audited content — flag issues; don't fix them.
- Do NOT make trust decisions — the actionGuard gates actions; the auditor provides evidence.
- Do NOT audit its own output — recursive auditing is the council's job.

## Inputs

```json
{
  "audit_target": {
    "type": "brief | claim_set | research_output | code_diff | plan",
    "nodes": ["uuid"],
    "claims": ["uuid"],
    "context": "string? (additional context for the audit)"
  },
  "audit_depth": "quick | standard | deep",
  "staleness_threshold_days": "int (default: varies by domain)"
}
```

## Outputs

```json
{
  "verdict": "clean | issues_found | critical_issues",
  "issues": [
    {
      "type": "contradiction | staleness | provenance_gap | unsupported_claim | factual_error | logic_error | scope_violation",
      "severity": "info | warning | critical",
      "claim_id": "uuid?",
      "description": "string (max 200 chars)",
      "evidence": "string (what contradicts or supports this finding)",
      "suggested_action": "review | remove | update_source | escalate_to_user"
    }
  ],
  "staleness_report": {
    "total_claims": "int",
    "stale_claims": "int",
    "fresh_claims": "int",
    "undated_claims": "int",
    "average_age_days": "number"
  },
  "contradiction_pairs": [{"claim_a": "uuid", "claim_b": "uuid", "description": "string"}],
  "provenance_chain_intact": "boolean"
}
```

## Staleness Half-Life by Domain

| Domain | Half-life | After 2× half-life |
|--------|-----------|---------------------|
| Tech/software | 6 months | Mark as possibly stale |
| Science/medicine | 2 years | Flag for update check |
| News/current events | 1 week | Mark as stale |
| Legal/regulatory | 1 year | Flag for update check |
| Historical/factual | 10 years | Generally still valid |
| Personal notes | Indefinite | User-managed |

## Determinism Rules

1. Temperature: 0.0 for contradiction/staleness detection. 0.1 for severity assessment.
2. Max output tokens: 512.
3. Audit depth controls thoroughness: quick = contradiction scan only; standard = +staleness; deep = +provenance chain + source credibility re-evaluation.

## Eval Hooks

**Metrics:** Contradiction detection recall ≥0.90, precision ≥0.85. Staleness classification accuracy ≥0.92. Latency p50 <300ms (quick), p95 <500ms (standard).
