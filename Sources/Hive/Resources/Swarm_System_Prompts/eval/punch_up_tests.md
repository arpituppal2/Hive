# punch_up_tests — control doc

> **Eval-family control doc (runtime contract).** Specifies how each Cell family's punch-up is measured — the tests, benchmarks, and metrics that prove a 1B specialist ≈ a 30B generalist on the same job. Referenced by every Cell's `Eval hooks` section. This is the system's quality bar: if a Cell can't clear its punch-up tests, it doesn't ship.

## Purpose

Punch-up tests are the evaluation framework that validates the core thesis of the Swarm: **size × role efficiency is the product, not raw params.** A 1B coder that is a disciplined specialist should match a ~30B generalist on the same job. An 8B specialist should blow past same-size generalists. These tests measure that.

## Contract

### 1. Punch-Up Definition

For each Cell family, "punch-up" means:
- **Same-job performance:** the specialist Cell, at its tier, performs within a δ of a larger generalist model (~30B class for 1B specialists, ~70B+ class for 8B specialists) when both are given the SAME bounded task.
- **Not general capability:** the specialist is NOT tested on tasks outside its job. A 1b_coder doesn't need to write poetry. A 1b_librarian doesn't need to browse the web. Specialists are narrow; their punch-up is measured on their narrow job.
- **δ targets:** a 1B specialist should be within 10-15% of the generalist's score on the same benchmark. An 8B specialist should EXCEED the same-size generalist by ≥20%.

### 2. Test Methodology

For each Cell family:

1. **Define a ground-truth benchmark suite** — a fixed set of tasks with known-correct outputs, curated to the Cell's specific job.
2. **Run the specialist Cell** on the suite. Measure pass@1 (does the first output match ground truth?).
3. **Run the comparison generalist** (Llama-3-70B, Qwen-30B, or equivalent) on the SAME suite, with the SAME inputs. Measure pass@1.
4. **Compare:** specialist score / generalist score. This is the **punch-up ratio.**
5. **Report:** punch-up ratio, confidence interval, per-task breakdown, failure modes.

### 3. Per-Family Benchmarks

#### 3.1 Coder Family (1b_coder, 8b_coder)

**Benchmark:** `CoderBench` — a suite of 100 common repo-aware edit tasks across 10 open-source repositories (Python, Swift, TypeScript, Rust). Tasks include:
- Single-function bug fixes (narrow blast radius).
- Add a parameter to a function and update all call sites (medium blast radius).
- Refactor a module to use a new interface (wide blast radius — 8B only).
- Write a test for an existing function.
- Fix a type error across two files.

**Metrics:**
- **pass@1 apply-clean rate:** does the `apply_patch` apply without conflicts?
- **Behavioral correctness:** do existing tests still pass? Does the new behavior match the spec?
- **Blast-radius containment:** for narrow tasks, does the edit touch only the intended files?
- **Test quality** (8B only): are the proposed tests right-sized and correct?

**Punch-up target (`coder/1b_coder`):** pass@1 apply-clean ≥ 0.85 vs generalist ≥ 0.90 → ratio ≥ 0.94. Behavioral correctness within 10% of generalist.
**Punch-up target (`coder/8b_coder`):** pass@1 on hard refactors ≥ 0.75 vs same-size generalist ≥ 0.55 → ratio ≥ 1.36. Must EXCEED.

**Tier-routing test:** narrow tasks routed to 1B, hard tasks to 8B. Forwarding rate from 1B→8B ≤ 15% of tasks. The 1B should handle ≥85% of edits.

#### 3.2 Browser Family (100m_dom_scout, 1b_action_planner, 8b_nav_reasoner)

**Benchmark:** `BrowserBench` — a suite of 50 web navigation + extraction tasks on a fixture site with known DOM structure. Tasks include:
- Read a page and extract specific elements (dom_scout).
- Navigate a multi-step form (action_planner).
- Handle a dynamic/JS-heavy page with ambiguous navigation (nav_reasoner).

**Metrics:**
- **Element location accuracy:** did the Cell find the right element?
- **Task completion rate:** did the multi-step navigation reach the target state?
- **Injection surface recall** (dom_scout): 100% of instruction-shaped DOM strings flagged in `prompt_injection_seen`.
- **Cost-per-scout** (dom_scout): <5ms.

**Punch-up target (`browser/100m_dom_scout`):** element location accuracy ≥ 0.95 (the 100m is a parser, not an inferrer — it should be near-perfect on well-formed pages).
**Punch-up target (`browser/1b_action_planner`):** task completion rate ≥ 0.80 vs generalist ≥ 0.85 → ratio ≥ 0.94.
**Punch-up target (`browser/8b_nav_reasoner`):** task completion on hard/ambiguous pages ≥ 0.70 vs same-size generalist ≥ 0.50 → ratio ≥ 1.40. Must EXCEED.

#### 3.3 Router Family (100m_intent_router, 100m_spam_detector, 100m_urgency_detector, 1b_link_scorer)

**Benchmark:** `RouterBench` — suites per Cell:
- **intent_router:** 500 labeled messages across 6 routes + ambiguous pairs.
- **spam_detector:** 200 messages (50% injection-laced, 50% benign) from published prompt-injection fixtures.
- **urgency_detector:** 200 messages with ground-truth urgency labels.
- **link_scorer:** 50 batches of candidate URLs with ground-truth relevance rankings.

**Metrics:**
- **Top-1 accuracy** (intent_router): ≥ 0.90.
- **Injection recall** (spam_detector): ≥ 0.95 (false-keep is the catastrophic failure).
- **Urgency precision** (urgency_detector): high-urgency precision ≥ 0.90.
- **Top-K ranking correlation** (link_scorer): Kendall τ ≥ 0.80.

**Punch-up target:** these Cells are classifiers, not generators. Their punch-up is measured against larger classifier models on the same labeled suites. The 100m Cells should match or exceed a ~3B generalist classifier on their narrow task.

#### 3.4 Librarian Family (100m_librarian, 1b_librarian)

**Benchmark:** `LibrarianBench` — 100 captures across diverse document types (articles, code, emails, academic papers, tweets). Ground truth: doc_type, metadata, surface entities, claims with evidence spans, entity relations.

**Metrics:**
- **Doc-type accuracy** (100m): ≥ 0.85.
- **Surface entity recall** (100m): ≥ 0.90 (high-recall, tolerant of false positives).
- **Claim precision** (1b): ≥ 0.90 of claims have valid verbatim evidence spans.
- **Entity deduplication** (1b): ≥ 0.85 correct linking to existing Honeycomb entities.
- **Zero hallucinated claims** (1b): zero claims without evidence spans.

**Punch-up target (`librarian/1b_librarian`):** claim extraction quality within 10% of a ~30B generalist on the same captures.

#### 3.5 Auditor Family (1b_auditor, 8b_auditor)

**Benchmark:** `AuditorBench` — 50 Honeycomb graph snapshots with injected issues (stale claims, provenance gaps, contradictions, credibility breaks).

**Metrics:**
- **Staleness recall** (1b): ≥ 0.95 of stale claims flagged.
- **Provenance-gap precision** (1b): ≥ 0.90 of gaps flagged.
- **Deep contradiction recall** (8b): ≥ 0.90 of injected contradictions detected.
- **1B finding resolution** (8b): ≥ 0.80 of 1B findings resolved.

**Punch-up target (`auditor/8b_auditor`):** deep contradiction detection ≥ 20% better than same-size generalist, which lacks the specialist auditing frame.

#### 3.6 Summarizer (1b_compressor)

**Benchmark:** `CompressorBench` — 50 captures with ground-truth key claims. Measure claim retention vs token compression.

**Metrics:**
- **Key-claim retention:** ≥ 0.95 of key claims retained.
- **Token compression ratio:** mean ≤ 0.30.
- **Drop rationale coverage:** 100% of dropped claims have rationales.

**Punch-up target:** compression quality within 10% of a ~30B generalist, but at a fraction of the inference cost.

#### 3.7 Planner Family (1b_planner, 8b_planner)

**Benchmark:** `PlannerBench` — 50 goals with ground-truth step decompositions and Cell topologies.

**Metrics:**
- **Plan validity** (1b): ≥ 0.95 of plans have valid Cell assignments + verify step + within RAM budget.
- **1B-to-8B escalation rate:** ≤ 10% of tasks should reach the 8B planner.
- **Deep-plan correctness** (8b): ≥ 0.90 of deep plans are valid DAGs with rollback contracts.

**Punch-up target (`planner/1b_planner`):** plan quality within 10% of a ~30B generalist planner. 8b_planner must EXCEED same-size generalist by ≥20%.

#### 3.8 Researcher (8b_research_synthesizer)

**Benchmark:** `ResearchBench` — 30 research questions with ground-truth briefs, source sets, and known disagreements.

**Metrics:**
- **Citation groundedness:** 100% of citations resolve to real source objects.
- **Disagreement surfacing:** ≥ 0.90 of known disagreements surfaced.
- **Evidence-quality calibration:** ≥ 0.85 accuracy on strong/moderate/weak/single_source labels.

**Punch-up target:** brief quality within 15% of a frontier model's research synthesis, but entirely on-device and provenance-bound.

#### 3.9 Reasoner (8b_deep_reasoner)

**Benchmark:** `ReasonerBench` — 20 hard reasoning questions with ground-truth chains of thought.

**Metrics:**
- **Reasoning depth:** ≥ 5 steps for deep questions, ≥ 3 for moderate.
- **Evidence-anchor coverage:** ≥ 0.80 of steps have non-internal-knowledge anchors.
- **Branch exploration:** ≥ 1 alternative branch per session.
- **Calibrated uncertainty:** on incomplete-evidence questions, epistemic uncertainty > 0.5.

**Punch-up target:** reasoning quality within 15% of a ~70B generalist, with better-calibrated uncertainty.

#### 3.10 Council (`council/1b_council_chair`)

**Benchmark:** `CouncilBench` — 30 council scenarios with ground-truth verdicts.

**Metrics:**
- **Verdict correctness:** ≥ 0.90 match ground truth.
- **Tie-break resolution:** ≥ 0.80 resolved in ≤2 rounds.
- **Tiny-cell-sufficiency rate:** modal outcome is no escalation.

**Punch-up target:** routing decisions at least as accurate as a human operator making the same decision — the council automates what a user would do manually.

#### 3.11 Guard (`guard/rule_action_guard`)

**Benchmark:** `GuardBench` — 200 action envelopes (50% safe, 50% should-be-denied) across all rule codes.

**Metrics:**
- **Injection/unsafe recall:** 100% on GUARD-001 through GUARD-010. False-allow is catastrophic.
- **False-deny ceiling:** ≤ 5% on benign actions.
- **Guard-cannot-be-disabled:** 100% deny on any action targeting the guard itself.

**Punch-up target:** the guard is deterministic — it should achieve 100% on its rule set. Punch-up here means: the rule catalog covers the same safety surface as frontier model safety classifiers, but at zero inference cost and with absolute determinism.

### 4. System-Level Tests

Beyond per-Cell benchmarks, system-level tests validate cross-Cell invariants:

1. **No-silent-early-stop (system):** 100% of unfinished goals end `blocked` — zero `complete` with skipped verify steps.
2. **Tier-escalation discipline:** 8B arrival rate ≤ 10% of interactions. Common paths resolve at 100m/1b.
3. **Guard-is-absolute:** zero privileged actions executed without a guard verdict; zero guard denials overridden by council.
4. **RAM-budget invariant:** total AI memory ≤ 4000MB at all times; at most one 8B; at most one working 1B.
5. **Cloud-border integrity:** zero silent cloud dispatches; every BYOK escalation has user opt-in logged.
6. **Citation groundedness (system):** zero generated citations that don't resolve to real Honeycomb source objects.
7. **Resume integrity:** on resume, completed steps stay completed; in-progress steps are re-dispatched or verified.

### 5. Benchmark Curation Rules

- Benchmarks must be **version-controlled** and **reproducible** — the same benchmark run twice on the same model must yield the same score.
- Benchmarks must be **adversarially curated** — include edge cases, injection attempts, ambiguous inputs, and known failure modes, not just happy-path tasks.
- Benchmarks must be **size-appropriate** — a 100m Cell's benchmark should be completable by a 100m model; testing it on 8B-hard tasks is a misconfiguration.
- Benchmarks must be **isolated per Cell** — a Cell's benchmark tests only that Cell's job. Cross-Cell integration tests are system-level.

### 6. Reporting

After each benchmark run, generate a `punch_up_report`:
```json
{ "cell": "<filename>",
  "benchmark_version": "<hash>",
  "specialist_score": <float>,
  "generalist_baseline": { "model": "<str>", "score": <float> },
  "punch_up_ratio": <float>,
  "δ_target_met": <bool>,
  "per_task_breakdown": [ {"task_id": "<…>", "specialist_pass": <bool>, "generalist_pass": <bool>} ],
  "failure_modes": ["<categorized failure reasons>"],
  "timestamp": "<ISO8601>" }
```

### 7. Cross-References

- Every Cell's `Eval hooks` section — the per-Cell punch-up targets.
- `00_INDEX.md` — tier matrix and Cell roster.
- `AGENTS.md` §16 (Test Strategy and Release Gates) — the system-level quality bar.
- `Sources/HiveCore/AI/ModelManifest.swift` — the model weights and sizes that back each tier.

## Distillation Pipeline (from Cell prompts → training data)

_Added Pass 11 from model distillation research (§29 of competitive dossier)._

### Pipeline Steps
1. **Template extraction:** Each Cell .md → extract output schema, stop conditions, failure modes, determinism rules
2. **Data generation:** Teacher model (GPT-4o/Claude Opus) generates 5,000–10,000 examples per Cell with explanation traces
3. **Quality filtering:** Remove ambiguous answers. Keep only "textbook quality" reasoning paths (Phi methodology)
4. **Specialist fine-tuning:** LoRA fine-tune 1B student (r=16–64, all linear layers) on Cell-specific dataset
5. **Evaluation:** Run punch_up_tests.md benchmarks. Iterate.

### Orca Explanation Traces
Microsoft's Orca proved small models fail when only trained on final answers. Every training example MUST include step-by-step reasoning. For Hive Cells: the 1b_coder must produce reasoning alongside patches; the 1b_librarian must show evidence spans before claims; the 8b_reasoner must expose CoT steps.

### LoRA Parameters by Tier
| Tier | LoRA rank (r) | Target modules | Overfitting risk |
|------|---------------|----------------|-----------------|
| 100M | r=8–16 | Attention only | High if r>32 |
| 1B | r=16–64 | All linear layers (QKV + FFN) | Moderate |
| 8B | r=32–128 | All linear layers | Low |

### Teacher Models by Cell Family
| Cell Family | Recommended Teacher | Why |
|-------------|-------------------|-----|
| Coder | Claude Opus / GPT-4o + Codex | Code generation benchmarks |
| Router (classifiers) | GPT-4o-mini / Haiku | Classification needs labeled data, not deep reasoning |
| Librarian/Summarizer | Claude Sonnet | Structured extraction from text |
| Researcher/Auditor | Claude Opus / GPT-4o | Deep reasoning, provenance tracking |
| Planner/Orchestrator | Claude Opus | Multi-step topology generation |
| Reasoner | Claude Opus / o1 | Chain-of-thought density |

### Eval Benchmarks by Tier (from §29)
| Tier | Benchmark | Realistic Target |
|------|----------|-----------------|
| 100M | Constrained classification accuracy | ≥85% on doc_type, intent, spam |
| 1B | HumanEval pass@1, SWE-bench lite | Match ~30B generalist on same-task suite |
| 8B | Big-Bench Hard, full SWE-bench | Exceed same-size generalists, approach frontier on specialist tasks |

## Open questions
_(none yet — filled in Phase 4 as benchmarks are implemented)_
