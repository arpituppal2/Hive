# MODEL_SPEC — Hive/Swarm Cell Training & Optimization Canon

> Canonical status: active
> Created: 2026-07-27
> Supersedes: any earlier training notes in PITCH/ or docs/
> Read this before: training any Cell model, selecting base architectures, or setting evaluation targets

## 0. The Thesis

### Punch-Up Target
Every Cell must outperform generalist models **3-10x its parameter count** on its specific job.

| Cell Tier | Targets to beat |
|-----------|----------------|
| **100M** | Qwen2.5-7B, Llama-3.2-3B, Gemma-3-4B (on Cell-specific eval) |
| **1B** | Qwen2.5-14B, Llama-3.1-8B, Nemotron-4-15B (on Cell-specific eval) |
| **8B** | GPT-4o-mini, Claude 3.5 Haiku, Qwen2.5-72B, Nemotron-3-120B (on Cell-specific eval) |

### Core Mechanism
1. **Hyper-specialization**: Each Cell does exactly one job. The prompt enforces a narrow output schema, limited tools, and deterministic stop-conditions. A 1B model that only writes Swift functions (never HTML/CSS/markdown/research) can dedicate 100% of its capacity to Swift — no generalist overhead.
2. **Aggressive distillation**: Teacher models (Claude Opus 4.5+, GPT-5.5, Gemini 3 Pro) generate synthetic training data for every Cell. The student learns the teacher's *output distribution* on the Cell's exact job — not general knowledge.
3. **Compressed architecture**: Sub-1B Cells use depth-scaled transformers with widened intermediate layers for their narrow domain. 8B Cells use mixture-of-experts (MoE) with per-expert specialization matching the Cell's sub-tasks.
4. **Latency-first design**: Every Cell targets `model_load + first_tokens < 200ms` on Apple Silicon Neural Engine or ANE. No Cell waits for GPU fallback.

## 1. Architecture Decisions

### 1.1 Base Architecture Selection by Tier

| Tier | Architecture | Rationale | Training Cost |
|------|-------------|-----------|---------------|
| **100M** | Depth-scaled Transformer (6 layers, d_model=768, d_ff=3072) + rotary embeddings | Full forward pass fits in ANE cache; no KV-cache eviction needed for <4K context | ~$200 per Cell (8xA100 80GB, 2 days) |
| **1B** | Depth-scaled Transformer (16 layers, d_model=1024, d_ff=4096) + GQA (8 KV heads) | GQA for efficient long-context (8K); RoPE for length extrapolation | ~$2K per Cell (8xA100 80GB, 5 days) |
| **8B** | MoE Transformer (24 layers, d_model=4096, 8 experts, top-2 routing) + GQA (16 KV heads) | MoE keeps active params at ~2.9B per token — matches 3B inference cost with 8B effective capacity | ~$20K per Cell (64xA100 80GB, 10 days) |

### 1.2 Initialization Strategy

| Component | Strategy |
|-----------|----------|
| **100M non-embedding** | Random init with depth-scaled LR (higher LR on deeper layers) |
| **1B non-embedding** | Initialize from Qwen2.5-1.5B base, prune to target depth, continue pretraining on domain corpus |
| **8B MoE non-embedding** | Initialize from Qwen2.5-7B base, replace FFN layers with MoE (8 experts), load-balance init via auxiliary-loss warmup |
| **Embedding/Vocab** | Always transfer from base model (maintains tokenizer compatibility). For 100M, use shared Qwen2.5 tokenizer |

### 1.3 Context Lengths

| Cell Family | Max Context | Rationale |
|-------------|-------------|-----------|
| Router (intent, spam, urgency) | 1,024 | Single utterance classification |
| Link scorer | 512 | URL + context snippet |
| DOM scout | 8,192 | Full page DOM trees |
| Action planner | 4,096 | Page context + user goal |
| Nav reasoner | 16,384 | Full page + history + plan |
| 1B coder | 8,192 | Single file + instruction |
| 8B coder | 32,768 | Multi-file project context |
| Sheet specialist | 4,096 | Table schema + row sample |
| Document specialist | 8,192 | Document + formatting |
| Presentation specialist | 8,192 | Deck structure + slide content |
| Planner (1B) | 4,096 | Session level |
| Planner (8B) | 16,384 | Project + memory |
| Librarian (100M) | 512 | Query to key retrieval |
| Librarian (1B) | 2,048 | Query + context to ranked results |
| Auditor (1B) | 4,096 | Single output review |
| Auditor (8B) | 8,192 | Multi-step plan review |
| Summarizer (100M) | 512 | Generate title |
| Summarizer (1B) | 4,096 | Session compression |
| Memory compressor | 8,192 | Day/week consolidation |
| Council chair | 4,096 | Debate overview |
| Observer | 1,024 | Single observation |
| Teammate | 8,192 | Full task context |
| Reasoner (8B) | 16,384 | Multi-step deep thinking |
| Research synthesizer | 16,384 | Source collection + synthesis |
| Action guard | 2,048 | Rule set + action |
| Tutor | 4,096 | Lesson + student state |
| Voice | 2,048 | Dialogue turn |
| Conversation | 32,768 | Full session memory |

## 2. Distillation Pipeline

### 2.1 Teacher Model Assignment

| Cell | Primary Teacher | Secondary Teacher | Tertiary Teacher |
|------|----------------|-------------------|------------------|
| Router (all) | GPT-5.5 Instant | Claude 3.5 Haiku | Gemini 2.0 Flash |
| Browser (all) | Claude Code Opus 4.7 | GPT-5.3 Codex | Gemini 3 Pro |
| Coder (1B) | Claude Code Fable 5 | GPT-5.5 Thinking | Claude Code Sonnet 4.6 |
| Coder (8B) | Claude Code Opus 4.8 | GPT-5.5 Pro | Gemini 3.1 Pro |
| Sheet specialist | Claude for Excel | GPT-5.3 Codex | Gemini Data Analysis |
| Document specialist | Claude for Word | Notion AI | Gemini make-a-doc |
| Presentation specialist | Claude for PowerPoint | Claude Design make-a-deck | Claude Visualize |
| Planner (1B) | Claude Cowork | GPT-5.1 Efficient | Gemini 2.0 Flash |
| Planner (8B) | Claude Opus 4.7 | GPT-5.5 Thinking | Gemini 3 Pro |
| Librarian (100M) | Gemini Search AI Mode | Perplexity AI | Brave Search |
| Librarian (1B) | Perplexity Comet | Notion AI | Kagi Assistant |
| Auditor (1B) | GPT-5.1 Efficient | Claude Sonnet 4.6 | Grok 4.2 |
| Auditor (8B) | GPT-5.5 Pro | Claude Opus 4.8 | DeepSeek Chat |
| Summarizer (100M) | Gemini 2.0 Flash | Perplexity AI | — |
| Summarizer (1B) | Claude Sonnet 4.6 | GPT-5.1 Efficient | Gemini 2.0 Flash |
| Memory compressor | Rewisp patterns | Claude nightly | Notion AI consolidation |
| Council chair | Claude Opus 4.7 | GPT-5.5 Thinking | Gemini 3 Pro |
| Observer | Claude Code observer | GPT-5.1 Efficient | — |
| Teammate | Claude Code teammate | GPT-5.5 Instant | Gemini 3 Flash |
| Reasoner | GPT-5.5 Thinking | Claude Opus 4.8 | DeepSeek Chat |
| Research | Perplexity Deep Research | NotebookLM | Google AI Search Mode |
| Action guard | Rule-based + Claude Haiku | — | — |
| Tutor | Gemini Guided Learning | Gizmo AI | Claude Sonnet 4.6 |
| Voice | Claude Voice Mode | Sesame AI Maya | ElevenLabs |

### 2.2 Distillation Procedure

```
Phase 1 — Behavior cloning (5K examples per Cell)
1. For each Cell, generate 500 seed instructions from the Cell's prompt + 100 seed user intents
2. For each seed instruction, query all 3 teachers
3. Keep only outputs where ≥2 teachers agree on structure (schema compliance, not exact text)
4. Filter out outputs that violate the Cell's output schema or stop conditions
5. Fine-tune base model on (instruction, agreed_teacher_output) pairs
6. Eval on held-out seed set; if Cell fails any eval, add 500 hard-negative examples and retrain

Phase 2 — Rejection sampling (50K examples per Cell)
1. Use Phase 1 model to generate 10 candidates per seed instruction
2. Score each candidate against Cell prompt's quality criteria using GPT-5.5 as judge
3. Keep top-1 candidate per instruction
4. Fine-tune Phase 1 model on (instruction, top_candidate) pairs
5. Eval; repeat rejection sampling with improved model for 3 rounds

Phase 3 — On-policy distillation (100K examples per Cell)
1. Deploy Phase 2 model in environment simulator (browser sandbox for browser Cells, code sandbox for coder Cells, etc.)
2. Collect 100K real interaction traces
3. For each trace, have teacher regenerate the optimal output
4. Fine-tune on (actual_input_from_trace, teacher_optimal_output) pairs
5. This closes the distribution gap between training and deployment
```

### 2.3 Data Budget

| Phase | Per Cell | Total (31 Cells) | Storage |
|-------|----------|-------------------|---------|
| Phase 1 | 5K pairs | 155K | ~3 GB (JSONL) |
| Phase 2 | 50K pairs | 1.55M | ~30 GB (JSONL) |
| Phase 3 | 100K traces | 3.1M | ~300 GB (JSONL + .pkl) |

## 3. Fine-Tuning Configuration

### 3.1 Hyperparameters

| Parameter | 100M | 1B | 8B |
|-----------|------|-----|-----|
| Optimizer | AdamW (β₁=0.9, β₂=0.95) | AdamW (β₁=0.9, β₂=0.95) | AdamW (β₁=0.9, β₂=0.95) |
| Peak LR | 5e-4 | 3e-4 | 1e-4 |
| LR schedule | Cosine (10% warmup) | Cosine (5% warmup) | Cosine (3% warmup) |
| Weight decay | 0.1 | 0.1 | 0.1 |
| Batch size | 256 | 128 | 64 (per expert) |
| Gradient clipping | 1.0 | 1.0 | 1.0 |
| Dropout | 0.1 | 0.1 | 0.0 (use QK-LayerNorm) |
| Precision | bfloat16 | bfloat16 | bfloat16 + FP8 (expert FFN) |
| DeepSpeed stage | 1 | 2 | 3 + expert parallelism |

### 3.2 LoRA Configuration (for iterative updates post-initial training)

| Parameter | Value |
|-----------|-------|
| Rank | 64 (100M/1B), 128 (8B) |
| Alpha | 128 (100M/1B), 256 (8B) |
| Target modules | q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj |
| Dropout | 0.05 |
| Bias | None |
| Merge at inference | Yes (for 100M/1B), No (deploy adapters separately for 8B MoE) |

### 3.3 Training Infrastructure

| Component | Minimum Config |
|-----------|---------------|
| 100M Cells | 1x A100 80GB (full fine-tune, ~2 days) |
| 1B Cells | 8x A100 80GB (FSDP, ~5 days) |
| 8B Cells | 64x A100 80GB (expert parallelism, ~10 days) |
| Storage | 5TB NVMe RAID (dataset + checkpoints) |
| Framework | HuggingFace Transformers + DeepSpeed + vLLM (eval) |

> **Training cost complementary to data generation cost:** See `TRAINING_DATA_GUIDE.md` section 5 for the API/data generation budget (~$1,260-$1,890 per Cell for teacher queries + ~$140K project total). The hardware costs above are the *compute* budget. Combined: ∼$200K total for full 31-Cell project (compute + data generation).

## 4. Tokenizer & Vocabulary

### 4.1 Base Tokenizer

All Cells share the **Qwen2.5 tokenizer** (151,936 vocab) to ensure:
- Inter-Cell communication uses the same token space
- Ensemble/pipeline inference doesn't require re-tokenization
- The shared embedding table is the single largest parameter cost — amortized across Cells

### 4.2 Cell-Specific Special Tokens

Each Cell gets 8 special tokens added to the vocab:

```
<|cell_name|>           — Cell identity marker (e.g., <|intent_classifier|>)
<|input_start|>         — Start of structured input
<|input_end|>           — End of structured input
<|output_start|>        — Start of structured output
<|output_end|>          — End of structured output
<|tool_call|>           — Tool call boundary (for Cell that invoke tools)
<|tool_result|>         — Tool result boundary
<|council_vote|>        — Council voting delimiter
```

These tokens are initialized as the mean of the top-100 most similar subword embeddings and fine-tuned during Phase 1.

## 5. Evaluation Benchmarks

> **Canonical eval targets are defined in `MODEL_QUALITY.md` (the single source of truth).** This section covers evaluation methodology and generalization tests shared across all Cells. The per-Cell eval set, metric, and punch-up target matrix lives in MODEL_QUALITY.md section 0.

### 5.1 Generalization Tests

Every Cell must also pass:

1. **Distribution shift test**: 500 examples from outside the training distribution (e.g., new intent classes for intent classifier). The Cell must gracefully decline (output `UNSURE` or `OUT_OF_SCOPE`) rather than hallucinate a best-guess.

2. **Adversarial robustness test**: 500 adversarial inputs designed to trigger prompt injection, jailbreak, or schema violation. The Cell must reject all with <1% false positive on benign inputs.

3. **Latency budget test**: 1,000 random inputs measured on Apple M1 (8GB) via CoreML/ANE. Latency must be <p95 target.

4. **Memory test**: Load all Cells that would be co-resident in a typical session (router + 1B librarian + 1B planner + 1B coder + auditor). Measure total RSS. Must fit in 8GB with 1.5GB headroom.

## 6. Deployment & Serving

### 6.1 Runtime Loading Strategy

| Load Pattern | Cells | Strategy |
|-------------|-------|----------|
| Always-loaded | Router (intent, spam, urgency), Action guard, 100M librarian | Pinned in RAM (~300MB — 100m cohort, per ram_manager) |
| Frequently-loaded | 1B coder, 1B planner, 1B auditor, 1B compressor, 1B librarian | Hot-loaded on user activity, evicted after 30s idle |
| On-demand | 8B coder, 8B reasoner, 8B planner, 8B auditor, Research, Tutor, Voice | Loaded only when Cell is selected; unloaded after task completion |
| Never-loaded | Sheet, Document, Presentation, Teammate, Council | Loaded only in their specific workflow context |

### 6.2 Model Format

| Tier | Format | Framework |
|------|--------|-----------|
| 100M | .mlpackage (CoreML) | CoreML Tools + ANE |
| 1B | .mlpackage (CoreML) + FP16 | CoreML Tools + ANE |
| 8B | .mlpackage (CoreML, 4-bit) + vLLM fallback | CoreML Tools + MLX |

### 6.3 Model Registration

Every trained model gets registered in `Sources/HiveCore/AI/ModelManifest.swift` with:
- Exact weights hash (SHA-256)
- Cell role mapping
- Evaluated latency on M1 (8GB)
- Evaluated punch-up score vs target
- Distillation lineage (teacher model + dataset hash)

## 7. Continuous Improvement

### 7.1 Post-Deployment Data Flywheel

```
User interaction → Trace logged (input, Cell output, user feedback) → 
Weekly trace collection → Phase 3 on-policy distillation (using latest teacher) → 
Model update → Staged rollout (5% → 25% → 100%) →
Performance regression check against eval suite
```

### 7.2 Retraining Cadence

| Cycle | Scope | Cadence |
|-------|-------|---------|
| Hotfix | Adversarial input fix, schema patch | As needed (<24h) |
| Weekly | Phase 3 on-policy with new traces | Weekly |
| Monthly | Full Phase 1-2-3 with latest teacher models | Monthly |
| Quarterly | Base architecture review, new Cell creation | Quarterly |

## 8. File Inventory

| File | Purpose |
|------|---------|
| `Swarm_System_Prompts/MODEL_SPEC.md` | This file — training specification |
| `Swarm_System_Prompts/TRAINING_DATA_GUIDE.md` | Synthetic data generation guide |
| `Swarm_System_Prompts/MODEL_QUALITY.md` | Eval benchmarks and punch-up target matrix |
| `Swarm_System_Prompts/AUGMENTATION_LOG.md` | Per-Cell frontier gap patches from re-read prompts |
| `Swarm_System_Prompts/00_INDEX.md` | Cell library index |
| `Swarm_System_Prompts/00_PROGRESS.md` | Distillation pass log |
