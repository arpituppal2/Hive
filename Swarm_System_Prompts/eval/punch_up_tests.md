# Punch-Up Tests — Eval Methodology

> **Role:** Phase 4 runtime contract. Defines how every Cell's punch-up claim is tested against larger generalist models.
> **Canonical Status:** active

## Core Principle

> "A 1B specialist Cell must outperform a 30B generalist model on its specific job."

This is measured through held-out benchmark suites designed per Cell, with disjoint eval sets that the LoRA adapter never saw during training.

## Benchmark Design Rules

1. **Disjoint held-out:** The test set must be completely disjoint from the training data (different sources, different time periods, different domains when possible).
2. **Anti-memoization:** The eval must detect memorization, not understanding. Include adversarial examples designed to trick models that memorized patterns.
3. **Size-normalized scoring:** Metrics are normalized per parameter to compute punch-up ratio: `accuracy_specialist / accuracy_generalist × (params_generalist / params_specialist)`.
4. **Latency-weighted:** Punch-up claims include latency. A specialist that's 2× slower than the generalist doesn't "punch up" even if accuracy is higher.

## Per-Cell Benchmark Suites

### Router Family

| Cell | Benchmark | Size | Baseline Model | Punch-Up Target | Held-Out Verdict |
|------|-----------|------|----------------|-----------------|-----------------|
| intentClassifier | 600 labeled intents (100/category) | 6-way classification | Qwen2.5-14B generalist | 0.93 accuracy | LOSES-but-gain (+0.40 over base) |
| spamDetector | 2,000 labeled (500 spam/clean/low/injection) | 4-way classification | Qwen2.5-14B generalist | 1.00 F1 | MATCH |
| urgencyDetector | 600 labeled (200/level) | 3-way classification | Qwen2.5-14B generalist | 0.75 accuracy | MATCH |
| linkScorer | 500 query-candidate sets | Ranking (NDCG@10) | Qwen2.5-14B generalist | NDCG ≥0.85 | Not yet evaluated |
| retrievalRanker | 400 query-node sets | Ranking (NDCG@10) | Qwen2.5-14B generalist | NDCG ≥0.88 | Not yet evaluated |

### Coder Family

| Cell | Benchmark | Size | Baseline Model | Punch-Up Target |
|------|-----------|------|----------------|-----------------|
| coder/1b | HumanEval + 200 single-file edits | Code generation + edit | Qwen2.5-32B generalist | Pass@1 ≥0.70 on HumanEval |
| coder/8b | SWE-bench + multi-file edits | Software engineering | GPT-4-class (120B+) | Pass@1 ≥0.35 on SWE-bench |

### Research Family

| Cell | Benchmark | Punch-Up Target |
|------|-----------|-----------------|
| researchGatherer | 300 research queries, source relevance | Precision@5 ≥0.85 |
| researchSynthesizer | 100 research briefs, human eval | Quality ≥4/5, hallucination ≤3% |

### Common Metrics (All Cells)

| Metric | Target | How Measured |
|--------|--------|-------------|
| Accuracy/F1 | Per-cell target | Disjoint held-out test set |
| Latency (p50, p95, p99) | Per-tier budget | Measured on M1 Air 8GB |
| Parameter efficiency | Punch-up ratio ≥1.0 | (accuracy/params) vs generalist |
| Determinism | Same input → same output | 10 identical invocations |
| Degradation | Graceful on unavailable model | Mock/OTS fallback accuracy |

## Evaluation Pipeline

```
1. Author seed intents → 100 per Cell (3,200 total)
2. Augment → 5,000 training pairs per Cell
3. Create disjoint held-out test set (500–2,000 per Cell)
4. Run baseline (OTS base model, no LoRA) on held-out
5. Run LoRA-fine-tuned model on held-out
6. Compare against 14B/30B/70B generalist baselines
7. Compute punch-up ratio
8. Record verdict: MATCH / LOSES-but-gain / NO_GAIN
9. Only flip loraAdapter in ModelManifest for MATCH or LOSES-but-gain
```

## Verdict Classifications

| Verdict | Meaning | Action |
|---------|---------|--------|
| MATCH | Specialist ≥ generalist on accuracy with better latency/cost | Flip to instructLoRA |
| LOSES-but-gain | Specialist < generalist but > OTS base by ≥0.15 | Flip to instructLoRA (beats base; ship) |
| NO_GAIN | Specialist ≤ OTS base or gain <0.15 | Keep instructOffTheShelf |
| HURTS | LoRA adapter is worse than OTS base | Remove loraAdapter; keep OTS |

## Anti-Memoization Tests

Each benchmark includes:
1. **Paraphrased inputs:** Same task, different wording → should produce same classification
2. **Adversarial examples:** Inputs designed to trigger wrong classification if memorized
3. **Out-of-distribution:** Inputs from domains not in training data
4. **Edge cases:** Empty input, max-length input, special characters, Unicode, emoji
