# MODEL_QUALITY — Hive/Swarm Cell Eval Benchmarks & Punch-Up Target Matrix

> Canonical status: active
> Created: 2026-07-27
> Read this before: evaluating Cell models, comparing against frontier baselines

## 0. The Punch-Up Thesis

Every Cell is evaluated against two baselines:
1. **Size-matched generalist** (same params, but general-purpose)
2. **Target frontier** (the model we claim to beat)

| Cell | Params | Size-Matched Baseline | Target Frontier | Win Condition |
|------|--------|----------------------|-----------------|---------------|
| Intent classifier | 100M | Llama-3.2-1B | GPT-5.5 Instant | +5% F1 |
| Spam detector | 100M | Llama-3.2-1B | Claude 3.5 Haiku | +2% Precision@90% recall |
| Urgency detector | 100M | Llama-3.2-1B | Claude Sonnet 4.6 | +0.05 Macro F1 |
| Link scorer | 1B | Qwen2.5-1.5B | GPT-5.1 Efficient | +0.03 NDCG@10 |
| Retrieval ranker | 100M | Llama-3.2-1B | Perplexity Comet | +0.02 MRR |
| DOM scout | 100M | Llama-3.2-1B | Claude Code DOM | +2% accuracy |
| Action planner | 1B | Qwen2.5-1.5B | Claude Code Opus 4.7 | +3% plan success |
| Nav reasoner | 8B | Qwen2.5-7B | GPT-5.5 Thinking | +2% completion rate |
| 1B coder | 1B | Qwen2.5-1.5B-Coder | Qwen2.5-32B-Coder | +5% Pass@1 |
| 8B coder | 8B | Qwen2.5-7B-Coder | GPT-4o | +3% Pass@1 |
| Sheet specialist | 100M | Llama-3.2-1B | Claude for Excel | +3% accuracy |
| Document specialist | 100M | Llama-3.2-1B | Claude for Word | +2% format score |
| Presentation specialist | 100M | Llama-3.2-1B | Claude Design | +0.3 designer score |
| 1B planner | 1B | Qwen2.5-1.5B | Claude Sonnet 4.6 | +5% feasibility |
| 8B planner | 8B | Qwen2.5-7B | Claude Opus 4.7 | +3% quality |
| 100M librarian | 100M | Llama-3.2-1B | Brave Search | +0.02 Recall@5 |
| 1B librarian | 1B | Qwen2.5-1.5B | Perplexity Comet | +0.02 NDCG@10 |
| 1B auditor | 1B | Qwen2.5-1.5B | Claude Sonnet 4.6 | +3% F1 |
| 8B auditor | 8B | Qwen2.5-7B | GPT-5.5 Thinking | +0.5% recall (safety) |
| 1B compressor | 1B | Qwen2.5-1.5B | Claude Haiku | +5% info retention |
| Title generator | 100M | Llama-3.2-1B | Perplexity AI | +3% relevance |
| Memory compressor | 1B | Qwen2.5-1.5B | Rewisp patterns | +2% fact retention |
| Council chair | 1B | Qwen2.5-1.5B | Claude Opus 4.7 | +5% decision quality |
| Observer | 100M | Llama-3.2-1B | Claude Code observer | +2% accuracy |
| Teammate | 1B | Qwen2.5-1.5B | Claude Code teammate | +3% coordination |
| 8B reasoner | 8B | Qwen2.5-7B | GPT-5.5 Thinking | +2% final accuracy |
| Research synth | 8B | Qwen2.5-7B | Perplexity Deep Research | +3% citation accuracy |
| Action guard | 100M + rules | Hybrid: 100M ML classifier + rule-based fallback | All frontier models + rule-based guard | ≥99.5% recall (ML layer catches ~99%, rule layer catches remaining 0.5%) |
| Tutor | 100M | Llama-3.2-1B | Gemini Guided Learning | +0.1 effect size |
| Voice | 100M | Llama-3.2-1B | Claude Voice Mode | +0.3 naturalness |
| Conversation | 8B | Qwen2.5-7B | Claude Sonnet 4.6 | +3% engagement |

## 1. Evaluation Methodology

### 1.1 Metrics Definitions

| Metric | Definition |
|--------|-----------|
| Pass@1 | Fraction of tasks where first generated solution passes all tests |
| CodeBLEU | Structure-aware BLEU for code (AST matching + dataflow matching) |
| F1 | Harmonic mean of precision and recall |
| NDCG@K | Normalized Discounted Cumulative Gain at rank K |
| MRR | Mean Reciprocal Rank |
| Recall@K | Fraction of relevant items in top K |
| Macro F1 | F1 averaged across all classes |
| Constraint satisfaction | Fraction of outputs that satisfy all prompt constraints |
| Format compliance | Fraction of outputs matching required schema exactly |
| Latency p50/p95 | Time from input to first token on M1 8GB |

### 1.2 Evaluation Protocol

Every eval run follows this protocol:
1. **Freeze eval set** — same 300-5K examples, no modifications during eval
2. **Load model** — cold start, measure load latency
3. **Run inference** — temperature=0 for deterministic Cells, temperature=0.3 for creative Cells
4. **Collect metrics** — per-example scores + aggregate
5. **Compare to baseline** — run baseline model on same eval set with same protocol
6. **Record** — append to this document's eval history

### 1.3 Statistical Significance

- Minimum 300 eval examples per Cell (minimum 1,000 for Cells with punch-up targets <3% delta, where 300 examples yields ∼±3-5% 95% CI on binary metrics — too wide to detect small effects)
- Report 95% confidence intervals (bootstrap, 10K resamples)
- A "win" requires p<0.05 (paired bootstrap test) AND effect size >0.1
- For small-target-delta Cells (action guard, conversation, link scorer): sequential testing with early stopping (every 100 examples, check if stopping boundary crossed) to avoid wasting compute on already-decisive comparisons

## 2. Eval Set Specifications

### 2.1 Router Eval Sets

**Hive-Intent-1K** — 1,000 utterances across 12 intent classes
- Sources: 100 human-written + 900 synthetically generated
- Distribution: 60% normal, 20% edge cases, 10% adversarial, 10% out-of-scope
- Classes: browser_navigate, browser_search, browser_capture, browser_hibernate, swarm_ask, swarm_research, swarm_code, swarm_organize, system_preference, system_help, multi_intent, out_of_scope
- Held-out classes (for distribution shift test): system_preference

**Hive-Spam-500** — 500 messages, adversarial split
- 250 legitimate, 250 spam/prompt-injection
- Hard examples: legitimate messages that use spam-like language ("URGENT: Your subscription is expiring" — actual system message)
- Protected: 50 examples never shown during training

**Hive-Urgency-500** — 500 messages, 4 urgency levels (low, medium, high, critical)
- Equal distribution across levels
- 50 time-critical examples (deadline-aware)
- 50 deliberately ambiguous (model must output uncertainty, not guess)

**Hive-Links-2K** — 2,000 URL+context pairs
- Sources: 1,000 spidered web pages + 1,000 synthetic
- Features: URL, page title, meta description, surrounding text, user query
- Relevance judged by 3-teacher panel (majority vote ground truth)

### 2.2 Browser Eval Sets

**Hive-DOM-5K** — 5,000 page snapshots
- 3,000 from Chrome UX Report top 10K sites
- 1,000 from SPAs (React, Vue, Angular)
- 500 from mobile-responsive sites
- 500 from accessibility-poor sites
- Each page has 5-15 labeled interactive elements

**Hive-Actions-2K** — 2,000 page+goal pairs
- 1,000 single-action goals (click button, fill form, extract text)
- 1,000 multi-action goals (complete checkout, compare products, fill multi-step form)
- Simulated environment validates plan success

**Hive-Nav-1K** — 1,000 multi-step browsing tasks
- Average 5.2 steps per task
- Tasks require: navigation + data extraction + cross-reference + decision
- Example: "Find the best-reviewed laptop under $1500 and add it to my comparison spreadsheet"

### 2.3 Coder Eval Sets

**Hive-Code-1B-5K** — 5,000 single-file coding tasks
- Languages: Swift (40%), Python (30%), TypeScript (20%), Shell (10%)
- Task types: bug fix (30%), feature add (30%), refactor (20%), test write (10%), document (10%)
- Each task includes: file content, task description, correct solution (hidden), test suite
- Baseline models evaluated on same 5K tasks

**Hive-Code-8B-3K** — 3,000 multi-file coding tasks
- Average 4.7 files per task
- Task types: cross-file refactor (30%), feature across modules (30%), architecture change (20%), code review (20%)
- Each task includes: project snapshot, task description, correct diff, existing test suite + new tests

**Hive-Sheets-1K** — 1,000 spreadsheet tasks
- Formula: SUM, AVERAGE, COUNTIF, VLOOKUP, nested IFs, array formulas
- Transformation: filter, sort, pivot, group by, date parsing
- Data quality: clean, missing values, duplicates, mixed types, dates in multiple formats
- Output: correct formula string OR transformed table preview

**Hive-Docs-500** — 500 document formatting tasks
- Formats: Markdown, HTML, ReStructuredText, LaTeX (simple)
- Tasks: apply heading hierarchy, cross-reference, table format, code block language tag
- Evaluation: string comparison + semantic structure comparison (AST)

**Hive-Decks-500** — 500 presentation generation tasks
- Slide counts: 5-20 slides
- Topics: product pitch, research summary, quarterly review, educational, technical deep-dive
- Evaluation: format compliance + expert design rating (5-point scale)

### 2.4 Memory & Retrieval Eval Sets

**Hive-Lib-1K** — 1,000 direct retrieval queries
- Queries have exactly one correct answer in corpus
- Corpus: 10K synthetic Honeycomb entries
- Metrics: Recall@1, Recall@5

**Hive-Lib-500** — 500 ambiguous retrieval queries
- Queries have 2-5 equally relevant answers
- Corpus: same as Hive-Lib-1K
- Metrics: NDCG@10, MRR

**Hive-Compress-1K** — 1,000 session compression tasks
- Source sessions: 500-2,000 tokens each
- Target: compress to <20% length while preserving all action items, decisions, and key facts
- Evaluation: human judges rate info retention (1-5) + fact extraction accuracy

**Hive-Memory-500** — 500 daily log consolidation tasks
- Source: 10-30 wisps each (from synthetic Rewisp-style captures)
- Target: one-paragraph daily summary
- Evaluation: fact retention (% of ground-truth facts preserved), coherence rating

**Hive-Titles-2K** — 2,000 content-to-title pairs
- Content: 500-2,000 word articles, notes, chat transcripts
- Ground truth: human-written titles from metadata or editors
- Metrics: BLEU, Rouge-L, relevance rating (1-5)

### 2.5 Planning & Reasoning Eval Sets

**Hive-Plan-1K** — 1,000 session-level planning tasks
- Single-user browser sessions
- Evaluate: plan completeness, step ordering correctness, resource estimation accuracy

**Hive-Plan-500** — 500 complex multi-step planning tasks
- Multi-project, multi-session planning
- Evaluate: dependency tracking, priority ordering, feasibility

**Hive-Reason-1K** — 1,000 deep reasoning tasks
- Types: mathematical (20%), logical (20%), multi-hop research reasoning (30%), counterfactual (15%), constraint satisfaction (15%)
- Source: adapted from MATH, GSM8K, ARC + Hive-specific scenarios
- Must evaluate: step-by-step correctness (not just final answer)

**Hive-Research-300** — 300 multi-source research tasks
- 3-10 conflicting/complementary sources per task
- Must: synthesize claims, attribute sources, flag conflicts, note uncertainty
- Evaluation: citation accuracy, claim correctness, synthesis quality

### 2.6 Safety & Robustness Eval Sets

**Hive-Guard-2K** — 2,000 action attempts
- 1,600 benign actions (80%)
- 400 dangerous actions (20%): destructive commands, PII exfiltration, privilege escalation, etc.
- Cell must: pass all benign, block all dangerous
- Metric: ≥99.5% recall on dangerous actions, ≥99% precision on benign

**Hive-Audit-1K** — 1,000 model outputs for auditing
- 700 outputs with injected errors (1-3 errors each, realistic)
- 300 clean outputs (no errors)
- Cell must: detect all errors in error-injected outputs, flag no errors in clean outputs
- Metric: error detection F1

**Hive-Audit-500** — 500 multi-step plans for security review
- Plans may contain: data leaks, privilege violations, safety violations
- Cell must flag every violation with exact location and severity

### 2.7 Conversation & Human Interaction Eval Sets

**Hive-Tutor-500** — 500 student interaction scenarios
- Subjects: math (K-12), programming (beginner), science (middle school), language learning
- Student types: struggling, progressing, advanced, distracted
- Evaluate: learning gain (simulated), student satisfaction, pedagogical correctness

**Hive-Voice-1K** — 1,000 dialogue turns
- Contexts: casual chat, task assistance, information lookup, system control
- Must: feel natural, handle interruptions, use appropriate register
- Evaluate: human-likeness rating (1-5), task success rate

**Hive-Team-300** — 300 multi-agent coordination tasks
- 2-5 Cells must coordinate to complete a task
- Evaluate: coordination efficiency, conflict resolution, output quality

## 3. Eval History

| Date | Cell | Eval Set | Score | Baseline Score | Delta | Model Version |
|------|------|----------|-------|---------------|-------|---------------|
| — | — | — | — | — | — | No models yet trained |

> *This table will be filled as Cell models are trained and evaluated. Each entry should record the Cell name, eval set, score achieved, baseline score, delta with statistical significance, and exact model version (commit or S3 path).*

## 4. Regression Test Suite

Every Cell must pass the following regression tests before deployment:

### 4.1 Latency Regression
- Load model from cold start: <500ms (100M), <1s (1B), <3s (8B)
- First token latency: <50ms (100M), <100ms (1B), <200ms (8B)
- Throughput: >100 tok/s (100M), >50 tok/s (1B), >25 tok/s (8B)

### 4.2 Quality Regression
- No >5% degradation on any single metric vs previous best
- No >2% degradation on composite score vs previous best
- Zero regression on safety/guard metrics (recall must stay ≥99.5%)

### 4.3 Memory Regression
- Cell model must fit in allocated RAM budget per RAM manager
- Loading Cell must not increase RSS of other Cells by >5%
- Unloading Cell must free ≥90% of its RSS within 5 seconds
