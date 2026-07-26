# Hive Multi-Model AI Architecture

## Overview

Hive/Swarm uses a concurrent multi-model AI runtime where every AI role is served by a specialized, locally-running model under 7B parameters — with most continuous intelligence using models under 1B.

**Architecture principle:** Memory first → Structured state second → Small specialized local models → Large model only when necessary.

## Model Ladder

| Tier | Size | Roles | Always Loaded | Latency Target |
|------|------|-------|---------------|----------------|
| T0 Tiny | ~100M | Intent classifier, Spam detector, Urgency detector, Link scorer | Yes | <5ms |
| T1 Small | 300M-1B | Orchestrator, Librarian, Summarizer, Retrieval Ranker, Title Generator, Memory Compressor | Yes (Orch, Lib) | <50ms |
| T2 Medium | 1B-3B | Auditor, Planner | On-demand | <500ms |
| T3 Heavy | 3B-7B | Deep Reasoner, Code Generator, Research Synthesizer | Rare escalation | <5s |
| Cloud BYOK | Frontier | User-owned keys (GPT-5, Claude, Gemini) | Fallback only | Varies |

## Provider Policy

**Apple Foundation Models (FMF):** Used ONLY for narrow, low-risk tasks:
- Lightweight structured extraction
- Simple refinement/formatting
- Short summarization (<500 chars)
- Dialog transforms (yes/no/confirm)
- Low-stakes tool call wrappers

**FMF is FORBIDDEN for:**
- Master orchestration
- Memory integrity
- Contradiction auditing
- Long-horizon planning
- Provenance-critical rewriting
- System-trust decisions
- Complex multi-document synthesis

## Model Role Inventory

### Orchestrator (T1, ~600M)
- Task classification, route selection, bee spawning
- Base: Qwen2.5-0.5B-Instruct + LoRA fine-tune
- I/O: OrchestratorInput → OrchestratorOutput

### Librarian (T1, ~500M)
- Document typing, claim extraction, metadata tagging
- Base: Qwen2.5-0.5B-Instruct + LoRA fine-tune
- I/O: LibrarianInput → LibrarianOutput

### Auditor (T2, ~2B)
- Contradiction detection, stale claim detection, provenance checks
- Base: Qwen2.5-1.5B-Instruct + LoRA fine-tune
- I/O: AuditorInput → AuditorOutput

### Planner (T2, ~1.5B)
- Multi-step plan generation, bee topology selection
- Base: Qwen2.5-1.5B-Instruct + LoRA fine-tune
- I/O: PlannerInput → PlannerOutput

### Action Guard (T0, Rule-based)
- Permission-aware action safety checks
- Deterministic rules only — no model needed

### Summarizer (T1, ~400M)
- Compression without loss of key claims
- Base: Phi-3-mini-4k-instruct → quantized
- I/O: SummarizerInput → SummarizerOutput

## Training Pipeline

### Prerequisites
- macOS with Apple Silicon (M1+)
- MLX framework (`pip install mlx mlx-lm`)
- 32GB+ RAM recommended for training (inference runs on 8GB)

### Fine-tuning Flow
1. Generate dataset: `DatasetGenerator.generateAllDatasets()`
2. Export training configs: `TrainingPipeline.exportAllArtifacts()`
3. Train: `python {modelID}_train.py` (MLX script)
4. Convert: `python {modelID}_convert.py` → CoreML .mlpackage
5. Register: Update `ModelRegistry` status to `.active`

### Dataset Schemas
Each dataset has:
- Input/output JSON schemas
- Train/val/test splits (70/15/15)
- Positive and negative examples
- Edge cases and adversarial tests
- Annotation rules
- Scoring metric

## Bee System Integration

Bees are concurrent subagents with:
- Central blackboard (MemoryStore)
- Bounded scopes with typed outputs
- Rollback recipes for reversible actions
- Evidence requirements for verification
- Reasoning budget selection (standard/extended/maximum)
- Automatic escalation when confidence drops below 0.7

## Resource Governance

Target: M1 MacBook Air, 8GB unified memory, macOS 26+

Budget:
- Always-loaded models: <300MB (T0 rule engines)
- Frequent models: <800MB (T1 specialists)
- On-demand models: <2000MB (T2 workers)
- Reserved for system: 1500MB
- Max total AI memory: 4000MB

## Evaluation

**Test suites per role:**
- Intent Classification: 20 tests, ≥95% pass required
- Spam Detection: 10 tests, ≥95% pass required
- Auditor: 10 tests, ≥99% pass required (security-critical)
- Safety: 10 tests, 100% pass required (0 false negatives)

**100/100 target:** All acceptance tests must pass before release.

## Future Retraining

1. Collect telemetry from user interactions (local only)
2. Identify weak bins in calibration report
3. Generate additional training examples for weak areas
4. Fine-tune with updated datasets
5. A/B test new model against baseline
6. Deploy when eval passes thresholds
