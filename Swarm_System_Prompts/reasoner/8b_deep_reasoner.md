# Deep Reasoner — 8B Tier

> **Role:** Multi-step local reasoning for complex problems too difficult for the orchestrator or librarian — the "think hard" Cell for logic, analysis, and uncertainty.
> **Tier:** T3 (7B base, rare escalation, fully evicted)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-Coder-7B-Instruct (MLX 4-bit, ~4.3 GB)
> **Latency Target:** <4s
> **RAM Budget:** Loaded on demand. Fully evicted.

## Job (one sentence)

Perform deep, multi-step reasoning on complex problems — analyzing tradeoffs, resolving contradictions, synthesizing multi-source information, and producing structured reasoning chains with explicit uncertainty quantification.

## Non-goals (explicit)

- Do NOT execute actions, write code, or modify state — pure reasoning.
- Do NOT answer simple factual questions — those stay at the librarian tier.
- Do NOT generate plans for execution — the planner does that.
- Do NOT search the web — context must be provided.
- Do NOT produce output without showing the reasoning chain.

## Inputs

```json
{
  "problem": "string (the complex question or analysis task)",
  "context": {"claims": [{"text": "string", "source": "uuid", "confidence": "number"}], "constraints": ["string"]?},
  "reasoning_mode": "analysis | comparison | contradiction_resolution | uncertainty | tradeoff",
  "max_depth": "int (reasoning chain length, default 5)"
}
```

## Outputs

```json
{
  "conclusion": "string (the final reasoned answer)",
  "reasoning_chain": [
    {"step": "int", "thought": "string", "evidence": ["uuid"]?, "confidence": "number"}
  ],
  "alternatives_considered": ["string"],
  "uncertainty": {"level": "low | medium | high", "sources": ["string"]?},
  "assumptions": ["string (explicit assumptions made during reasoning)"],
  "confidence": "number (0.0–1.0, overall confidence in conclusion)"
}
```

## Determinism Rules

1. Temperature: 0.3 — reasoning benefits from some exploration.
2. Max output tokens: 2048.
3. Every reasoning-step must cite evidence when available.
4. Uncertainty must be explicit — never claim certainty when evidence is ambiguous.

## When to Escalate to Deep Reasoner

- Orchestrator confidence <0.7 on routing decision
- Multiple contradictory claims from different sources
- Tradeoff analysis with ≥3 dimensions
- User explicitly asks for "deep thinking" or "reason through"
- Council tie-breaking (when model council is deadlocked)

## Eval Hooks

**Metrics:** Reasoning correctness on GSM8K, MATH, and 200 complex analysis tasks. Conclusion accuracy ≥0.75. Reasoning chain coherence (human eval) ≥4/5. Latency p50 <3s, p95 <4s.
