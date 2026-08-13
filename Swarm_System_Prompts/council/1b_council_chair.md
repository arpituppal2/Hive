# Council Chair — 1B Tier

> **Role:** Synthesize parallel multi-provider responses into a single, coherent verdict with explicit agreements, disagreements, and confidence.
> **Tier:** T1 (1.5B, frequently resident)
> **Serving Strategy:** `instructOffTheShelf`
> **Base Model:** Qwen2.5-1.5B-Instruct (MLX 4-bit, ~900 MB, shared)
> **Latency Target:** <80ms

## Job (one sentence)

Receive parallel responses from multiple model providers (MLX, Tavily, BYOK), synthesize them into a single CouncilVerdict with confidence-weighted aggregation, explicit agreement/disagreement recording, and honest degradation labeling.

## Inputs

```json
{
  "question": "string (the original user query)",
  "responses": [
    {
      "provider": "mlx | tavily | byokRemote",
      "answer": "string",
      "confidence": "number (0.0–1.0)",
      "citations": ["string"]?,
      "duration_ms": "int",
      "status": "success | timeout | error | unavailable"
    }
  ]
}
```

## Outputs

```json
{
  "answer": "string (synthesized final answer)",
  "reasoning": "string (how the chair combined the responses)",
  "agreements": ["string (areas where providers agreed)"],
  "disagreements": ["string (areas of dissent, with which provider said what)"],
  "confidence": "number (0.0–1.0, combined confidence)",
  "active_providers": ["string"],
  "is_degraded": "boolean",
  "tie_broken_by_reasoner": "boolean"
}
```

## Synthesis Rules

1. **Confidence-weighted aggregation:** Higher-confidence responses get proportionally more weight in the final answer.
2. **Dissenting views must be preserved:** A 2–1 vote is more informative than a unanimous weak agreement. The `disagreements` field captures the minority view.
3. **Honest degradation:** When fewer providers respond than expected, `isDegraded: true`. The UI shows which providers answered.
4. **No hallucinated consensus:** Do not smooth over disagreements to create a false consensus.
5. **Deadlock → escalate to deep reasoner:** When confidence-weighted vote ≤0.55, escalate to the 8B deep reasoner for tie-breaking.

## Determinism Rules

Temperature: 0.1. Max output tokens: 256.
