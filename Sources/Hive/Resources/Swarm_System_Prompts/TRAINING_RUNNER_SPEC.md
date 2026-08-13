# TRAINING_RUNNER_SPEC — From Specs to Executable Pipeline

> **Canonical status:** active
> **Created:** 2026-07-27
> **Purpose:** Bridges all 46 existing `.md` spec files into an executable training pipeline. Defines the exact code structure, data flow, configuration, and commands needed to transform seed intents → training pairs → trained Cell models.
> **Design constraint:** "100M" tier Cells currently run on Qwen3-0.6B-4bit (~400MB RAM). True 100M models trained from scratch are Phase 2 optimization. See §2.3 note.
> **Dependencies:** seed_intent_plan.md, TRAINING_DATA_GUIDE.md, MODEL_SPEC.md, EXECUTION_PLAN.md, all 32 Cell prompts
> **Outputs:** `hive-train/` directory with Python scripts and MLX config

## 0. Directory Structure

```
hive-train/                          # Training project root
├── config/                          # Per-Cell training configs
│   ├── router/                      #   P0 priority
│   ├── browser/                     #   P1 priority
│   ├── coder/                       #   P2 priority
│   ├── planner/                     #   P3 priority
│   ├── librarian/                   #   P3 priority
│   ├── auditor/                     #   P4 priority
│   ├── summarizer/                  #   P4 priority
│   ├── council/                     #   P5 priority
│   ├── reasoner/                    #   P5 priority
│   ├── researcher/                  #   P5 priority
│   └── guard/design/tutor/voice/   #   P6 priority
├── data/                            # Generated training data
│   ├── seed/                        #   Raw seed intents
│   ├── augmented/                   #   Expanded (50x) seed variants
│   ├── pairs/                       #   Teacher-generated (input,output) pairs
│   ├── distilled/                   #   Distilled teacher outputs
│   └── eval/                        #   Evaluation fixtures
├── scripts/                         # Python/Shell training scripts
│   ├── generate_seeds.py            #   Convert seed_intent_plan.md → JSONL
│   ├── augment.py                   #   Expand seeds to 50 variants each
│   ├── pair.py                      #   Call teacher model for completions
│   ├── train.py                     #   Run MLX LoRA/distillation training
│   ├── eval.py                      #   Run MODEL_QUALITY evaluation suite
│   ├── export.py                    #   CoreML/ANE export
│   └── deploy.py                    #   Copy to Hive bundle
├── models/                          # Checkpoint storage
│   ├── base/                        #   Base model weights (HF cache)
│   ├── lora/                        #   LoRA adapter checkpoints
│   └── exported/                    #   CoreML .mlpackage files
├── results/                         # Eval results, logs, metrics
├── requirements.txt                 # Python dependencies
└── Makefile                         # Top-level workflow commands
```

## 1. Data Flow (Phase 1 — Seed → Augmented → Paired)

### 1.1 Extract Seeds from Spec

**Input:** `Swarm_System_Prompts/seed_intent_plan.md`
**Script:** `scripts/generate_seeds.py`

The script parses the seed_intent_plan.md and extracts structured seeds:

```python
# Pseudocode — exact implementation TBD
def extract_seeds(md_path: str) -> list[SeedIntent]:
    """Parse seed_intent_plan.md and extract all 3,200 seed intents.

    Strategy: Section headers define Cell identity (e.g. "### 1.1 router/100m_intent_router").
    Within each Cell section:
    - "Normal (70)" -> category=normal
    - "Edge (15)" -> category=edge
    - "Adversarial (15)" -> category=adversarial

    For each bullet item, create a SeedIntent with:
    - id: "{cell_role}_{nnn}" where nnn is incrementing
    - cell: section header's Cell filename
    - category: normal|edge|adversarial
    - input: structured dict matching the Cell's expected input schema
    - expected_output_schema: JSON schema string
    - tags: ["category_tag", "difficulty_tag"]

    Schema validation: each seed intent is validated against the Cell's
    expected input schema (from seed_intent_plan.md Appendix).
    """
    ...
```

**Output:** `data/seed/{cell_role}/v1/seeds.jsonl` — one JSONL file per Cell, 100 records each.

### 1.2 Augment Seeds (50x Expansion)

**Input:** `data/seed/` (100 seeds per Cell)
**Script:** `scripts/augment.py`

```python
# Pseudocode
def augment_seeds(seeds: list[SeedIntent], augmentations: int = 50) -> list[SeedIntent]:
    """Expand each seed intent into 50 variants.

    Augmentation strategies (from TRAINING_DATA_GUIDE §1.2):
    1. PARAPHRASE: Rewrite input while preserving semantic meaning and expected output
    2. NOISE: Add typos, formatting variations, extra whitespace, emoji
    3. DOMAIN_SWITCH: Change domain-specific terms (e.g., "Swift" -> "Rust")
    4. REGISTER_TRANSLATION: Formal <-> casual <-> technical
    5. TEMPORAL_SHIFT: Change time references (today/yesterday/last week)
    6. SCOPE_CHANGE: Widen/narrow the scope of the request
    7. TONE_CHANGE: Add/remove politeness, urgency, vagueness
    8. ADVERSARIAL: For category=adversarial seeds only — strengthen injection patterns

    Distribution: 50 variants per seed, distributed as:
    - 15 template-based deterministic variants
    - 25 LLM-generated variants (using GPT-4o Mini or equivalent)
    - 10 rule-based noise variants
    """
    ...
```

**Output:** `data/augmented/{cell_role}/v1/seeds_augmented.jsonl` — 5,000 records per Cell (50×100).

**Expected Counts:**
| Stage | Records per Cell | Total (32 Cells) |
|-------|-----------------|-------------------|
| Raw seeds | 100 | 3,200 |
| Augmented (50×) | 5,000 | 160,000 |
| Phase 1 pairs | 5,000 | 160,000 |
| Phases 1-3 total | ~155K | ~5M |

### 1.3 Generate Teacher Completions

**Input:** `data/augmented/{cell_role}/v1/seeds_augmented.jsonl`
**Script:** `scripts/pair.py`

```python
# Pseudocode
def generate_teacher_pairs(augmented_seeds: list[SeedIntent],
                            teacher_model: str = "claude-opus-4",
                            max_concurrency: int = 10) -> list[TrainPair]:
    """For each augmented seed, call the teacher model to produce the output.

    The teacher model is loaded with the Cell's full system prompt
    (from the Cell's .md file in Swarm_System_Prompts/) as its system instruction,
    and the seed intent's input as the user message.

    The teacher model generates the expected output, which is validated
    against the Cell's full output schema.

    Retry policy:
    - Schema validation failure -> retry up to 3 times with temperature 0.1
    - API error -> exponential backoff, retry up to 5 times
    - Content filter -> flag for review, do not retry
    """
    ...
```

**Output:** `data/pairs/{cell_role}/v1/train_pairs.jsonl`

### 1.4 Teacher Selection by Cell Priority

| Priority | Cell Family | Teacher Model | Est. Cost/Cell |
|----------|-------------|---------------|----------------|
| P0 | Router (5) | Claude Opus 4.8 | ~$600 (5K pairs) |
| P1 | Browser (3) | Claude Opus 4.8 | ~$600 |
| P2 | Coder (4) | Claude Opus 4.8 + GPT-5.5 | ~$1,200 |
| P3 | Planner (2), Librarian (2) | Claude Opus 4.8 | ~$600 |
| P4 | Auditor (2), Summarizer (3) | Claude Opus 4.8 + GPT-5.5 | ~$1,200 |
| P5 | Council (3), Reasoner, Research | Claude Opus 4.8 + GPT-5.5 | ~$1,200 |
| P6 | Guard, Design, Tutor, Voice, Conversation | Claude Opus 4.8 | ~$600 |

**Total Phase 1 teacher cost:** ~$30K (160,000 pairs across 32 Cells @ ~$600-$1,200/Cell)

## 2. Distillation Training (Phase 2 — MLX LoRA)

### 2.1 Configuration File Format

Each Cell gets a YAML config at `config/{family}/{cell_role}.yaml`:

```yaml
# config/router/intent_router.yaml
cell_role: intent_router
tier: 100M
base_model: mlx-community/Qwen3-0.6B-Instruct-4bit
training:
  method: lora
  rank: 16
  alpha: 32
  dropout: 0.05
  target_modules: [q_proj, v_proj, o_proj, up_proj, down_proj]
  train_batch_size: 8
  eval_batch_size: 16
  gradient_accumulation_steps: 4
  learning_rate: 2e-4
  lr_scheduler: cosine
  num_epochs: 3
  warmup_ratio: 0.03
  max_seq_length: 1024
  save_steps: 100
  eval_steps: 50
  logging_steps: 10
data:
  train_file: data/pairs/intent_router/v1/train_pairs.jsonl
  eval_split: 0.1  # 10% held out for eval
  prompt_template: |
    System: {system_prompt}
    User: {input}
    Assistant: {output}
distillation:
  temperature: 1.0
  kl_weight: 0.5
  mse_weight: 0.3
  vocab_weight: 0.2
```

### 2.2 Training Script

```python
# scripts/train.py
# Pseudocode — uses MLX LM for on-device training

import mlx.core as mx
import mlx.nn as nn
from mlx_lm import load, generate, LoRALinear

def train_cell(config_path: str):
    """Train a single Cell using MLX LoRA.

    1. Load base model (Qwen, Llama, or nomic embedder)
    2. Apply LoRA adapters to target modules
    3. Load training pairs from data/
    4. Format with Cell's system prompt (from Swarm_System_Prompts/)
    5. Run distillation training:
       - Forward pass through student (LoRA) and frozen teacher (base)
       - Compute KL divergence + MSE loss
       - Backprop through LoRA adapters only
       - Update LoRA weights
    6. Save LoRA checkpoint to models/lora/{cell_role}/v1/
    7. Run eval on holdout set
    8. Log metrics to results/{cell_role}/train_log.json
    """
    ...
```

### 2.3 Training Configuration by Tier

| Tier | Base Model | LoRA Rank | Batch Size | LR | Max Seq | Est. Time |
|------|-----------|-----------|------------|-----|---------|-----------|
| 100M | Qwen3-0.6B-Instruct-4bit | 16 | 8 | 2e-4 | 1,024 | ~15 min |
| 1B | Qwen3-0.6B-Instruct-4bit | 32 | 4 | 1e-4 | 4,096 | ~30 min |
| 8B | Qwen2.5-Coder-7B-Instruct-4bit | 64 | 2 | 5e-5 | 8,192 | ~2 hrs |
| 8B (deep) | Qwen2.5-Coder-7B-Instruct-4bit | 64 | 2 | 3e-5 | 16,384 | ~4 hrs |

**Note on 100M tier:** The smallest Qwen3-0.6B is 600M params — heavier than the "100M" target from prompt spec. True 100M models (e.g., Microsoft Phi-3-mini at 3.8B is also too big) require training tiny transformers from scratch on distilled data. Until those are built, "100M" Cells run on Qwen3-0.6B-4bit (which uses ~400MB RAM after quantization) — within the 8GB M1 budget. True 100M models are Phase 2 optimization.

## 3. Evaluation (Phase 2 — Continuous)

### 3.1 Eval Loop

```python
# scripts/eval.py
def evaluate_cell(cell_role: str, checkpoint_path: str):
    """Run the full MODEL_QUALITY evaluation suite for a Cell.

    For each eval fixture in data/eval/{cell_role}/:

    1. Load the LoRA-adapted model
    2. For each fixture (input_desc, input, expected_output, labels):
       a. Generate output with temperature=0 (deterministic)
       b. Compare against expected output:
          - Exact schema match
          - Semantic similarity (embedding cosine)
          - Key-field extraction accuracy
          - Reject rate on adversarial fixtures
       c. Record scores
    3. Compute aggregate metrics:
       - Accuracy, precision, recall, F1
       - Schema compliance rate
       - Adversarial rejection rate
       - Latency (tokens/sec on M1)
       - RAM usage (peak + steady-state)
    4. Compare against MODEL_QUALITY.md punch-up targets
    5. Log results to results/{cell_role}/eval_results.json
    """
    ...
```

### 3.2 Eval Fixtures

Each eval fixture is a JSON record:

```json
{
  "fixture_id": "intent_router_e001",
  "cell": "intent_router",
  "input_desc": "Simple navigation request",
  "input": {
    "message": "Go to github.com",
    "context": {
      "active_tab": null,
      "active_project": null,
      "conversation_history": []
    }
  },
  "expected_output": {
    "route": "browse",
    "confidence": 0.95,
    "reason": "Explicit navigation intent",
    "status": "complete"
  },
  "tags": ["normal", "easy"],
  "punch_up_target": "accuracy >= 0.95 on normal category"
}
```

Each Cell gets 100 eval fixtures (matching the 100 seed intent distribution: 70 normal, 15 edge, 15 adversarial).

## 4. CoreML/ANE Export (Phase 3 — Deployment)

### 4.1 Export Script

```python
# scripts/export.py
def export_to_coreml(cell_role: str, checkpoint_path: str):
    """Convert MLX LoRA model to CoreML .mlpackage for on-device deployment.

    1. Load base model + LoRA adapter
    2. Fuse LoRA weights into base model (merge for inference)
    3. Quantize to FP16 (or INT8 for memory-critical Cells)
    4. Export to CoreML with:
       - Fixed input shape (batch=1, seq_len=cell_max_context)
       - ANE-compatible ops (replace non-ANE ops where possible)
       - Metadata: cell_role, version, input_schema, output_schema
    5. Save to models/exported/{cell_role}/{version}.mlpackage
    6. Compute on-device metrics:
       - Model size (MB)
       - RAM at inference (MB)
       - First-token latency (ms)
       - Throughput (tokens/sec)
    7. Validate against 8GB M1 budget:
       - Peak RAM <= 2GB per Cell (allows 4 Cells concurrent)
       - First-token latency < 500ms (100M/1B), < 2000ms (8B)
       - Model file size <= 500MB (100M), <= 2GB (1B), <= 4GB (8B)
    """
    ...
```

### 4.2 RAM Budget Validation

Per `router/ram_manager.md`, the 8GB M1 budget:

| Tier | Max Loaded | Max RAM/Cell | Max Concurrent |
|------|-----------|-------------|----------------|
| 100M | 6 Cells | ~200MB | 4 (800MB) |
| 1B | 3 Cells | ~600MB | 2 (1.2GB) |
| 8B | 1 Cell | ~4GB | 1 (4GB) — includes ~500MB KV cache for 16K context |
| Embedder | 1 | ~100MB | 1 (100MB) |
| **Total safe budget** | | | **~5.1GB** — leaves ~2.9GB headroom for OS and browser |

The export script validates that exported models fit within these budgets.

## 5. Deployment Integration

### 5.1 Model Registry Integration

Each exported model registers with the existing `ModelManifest.swift`:

```json
// models/manifest.json — parsed by ModelManifest.swift
{
  "models": {
    "intent_router": {
      "cell_role": "intent_router",
      "tier": "100M",
      "provider": "mlx",
      "path": "models/exported/intent_router/v1.mlpackage",
      "ram_mb": 180,
      "max_context": 1024,
      "punch_up": "accuracy >= 0.95 vs Qwen2.5-7B",
      "status": "verified"
    },
    ...
  }
}
```

### 5.2 Swarm Integration

The `Dispatcher.shared` actor in HiveCore/AI/Dispatcher.swift loads models from the manifest. Integration point:

```swift
// Pseudocode — existing Dispatcher integration
// NOTE: The actual field is `ModelManifest.entries[role]` (not `modelManifest[role]`).
extension Dispatcher {
    func loadTrainedModel(for role: ModelRole) async -> ModelRuntime {
        guard let entry = ModelManifest.entries[role],
              let config = trainedModelRegistry[entry.cellName],
              config.status == "verified" else {
            return MockRuntime() // Fallback to mock
        }
        return MLXRuntime(config: config)
    }
}
```

## 6. End-to-End Workflow (Makefile)

```makefile
# Makefile — Top-level training commands

.PHONY: all router browser coder eval clean deploy

# Default: train all P0 Cells (router family)
all: router

# P0: Router family (5 Cells — gate all traffic)
router: router/intent router/spam router/urgency router/link_scorer router/retrieval_ranker

router/intent:
	python scripts/generate_seeds.py --cell intent_router
	python scripts/augment.py --cell intent_router --variants 50
	python scripts/pair.py --cell intent_router --teacher claude-opus-4
	python scripts/train.py --config config/router/intent_router.yaml
	python scripts/eval.py --cell intent_router --checkpoint models/lora/intent_router/v1
	python scripts/export.py --cell intent_router --checkpoint models/lora/intent_router/v1

# P1: Browser family
browser: browser/dom_scout browser/action_planner browser/nav_reasoner

# P2: Coder family
coder: coder/1b coder/8b coder/sheet coder/document

# Run all evals
eval:
	python scripts/eval.py --cell all

# Deploy all verified models to Hive bundle
deploy:
	python scripts/deploy.py --source models/exported/ --dest ../Sources/HiveCore/Models/
	echo "Updated ModelManifest.swift with new model paths"

# Clean temporary training artifacts
clean:
	rm -rf data/augmented/ data/pairs/ data/distilled/
	rm -rf models/lora/
	echo "Cleaned augmented data and LoRA checkpoints. Seeds and exported models preserved."
```

## 7. Cost Tracking

### 7.1 Per-Cell Cost Estimate

| Cost Component | Est. per 5K pairs (100M Cell) | Est. per 5K pairs (8B Cell) |
|----------------|------------------------------|------------------------------|
| Teacher API (Claude Opus 4.8) | ~$600 (5K × ~$0.12/request) | ~$1,200 (5K × ~$0.24/request) |
| MLX compute (M1 Mac) | $0 (local) | $0 (local) |
| A100 cloud compute (optional) | ~$20/hr × 1hr = $20 | ~$20/hr × 4hr = $80 |
| **Total per Cell** | **~$620** | **~$1,280** |

### 7.2 Budget Tracking

Each training run logs to `results/budget.json`:

```json
{
  "budget": {
    "allocated": 100000,
    "spent": 0,
    "remaining": 100000
  },
  "cells_trained": [],
  "cells_pending": [
    "intent_router (~$620)",
    "spam_detector (~$620)",
    "urgency_detector (~$620)",
    "... (32 total)"
  ],
  "estimated_total": 31200,
  "notes": "Phase 1 teacher queries only. Full pipeline (Phases 1-3) estimated ~$40K data + ~$70K compute = ~$110K (per EXECUTION_PLAN §Total). See EXECUTION_PLAN.md for full budget breakdown by phase."
}
```

## 8. Quality Gates (From MODEL_QUALITY.md)

Before a model can be marked `verified` in the manifest, it must pass:

| Gate | Test | Threshold |
|------|------|-----------|
| Schema compliance | Output validates against Cell's JSON schema | 100% |
| Normal accuracy | Correct output on 70 normal eval fixtures | ≥90% |
| Edge robustness | Graceful handling on 15 edge fixtures | ≥80% |
| Adversarial rejection | Correctly rejects or safely handles 15 adversarial fixtures | ≥90% |
| Latency | First-token latency on M1 | ≤500ms (100M/1B), ≤2s (8B) |
| RAM | Peak RAM on M1 | ≤2GB (100M/1B), ≤4GB (8B) |
| Punch-up | Per-Cell targets from MODEL_QUALITY.md §0 (e.g., 1B coder = Qwen2.5-Coder-7B, router = Qwen2.5-7B) | Per-Cell thresholds |
| Size | .mlpackage file size | ≤500MB (100M), ≤2GB (1B), ≤4GB (8B) |

---

## Appendix: Quick Reference

### Command Cheatsheet

```bash
# Generate seeds for all cells
python scripts/generate_seeds.py --all

# Generate seeds for one family
python scripts/generate_seeds.py --family router

# Augment seeds for one cell
python scripts/augment.py --cell intent_router --variants 50

# Generate teacher pairs for one cell
python scripts/pair.py --cell intent_router --teacher claude-opus-4

# Train all P0 cells
make router

# Train single cell
make router/intent

# Evaluate a trained cell
python scripts/eval.py --cell intent_router --checkpoint models/lora/intent_router/v1

# Export for deployment
python scripts/export.py --cell intent_router --checkpoint models/lora/intent_router/v1

# Run full pipeline for a cell (generate → augment → pair → train → eval → export)
make router/intent

# Deploy all verified models
make deploy

# Check budget
cat results/budget.json
```

## Environment Variables

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `ANTHROPIC_API_KEY` | Yes (Phase 1) | — | Teacher model (Claude Opus 4.8) |
| `OPENAI_API_KEY` | Optional (Phase 2) | — | Secondary teacher (GPT-5.5) |
| `HF_TOKEN` | Optional | — | Download gated base models |
| `TRAINING_BUDGET_USD` | No | 100000 | Hard cap on API spend |
| `MLX_LM_CACHE` | No | ~/.cache/huggingface | Base model cache dir |
| `TRAINING_DEVICE` | No | cpu | Device for MLX training |
