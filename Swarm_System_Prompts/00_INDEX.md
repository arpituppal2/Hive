# Swarm System Prompts — Cell Taxonomy Index

> **Tree status:** source-prompt corpus / Cell roster mirror. The packaged planning canon lives under `Sources/Hive/Resources/Swarm_System_Prompts/`.
> **Current source-corpus count:** 41 Markdown files (35 specialist/control prompt files plus this index, progress tracker, and auxiliary source prompts). Do not use the historical 33-file count below as current inventory evidence.
> **Canonical status:** active
> **Created:** 2026-08-11
> **Purpose:** Single source of truth for every specialist Cell in the Hive Swarm runtime. Maps Cell roles to tiers, model assignments, dependency graph, RAM budget, and council composition rules.

## Cell List + Tier Matrix

Every ModelRole that has a corresponding `.md` prompt file is listed. Roles without prompt files (embedder, byokFrontier, appleFMF) use bare model calls or system frameworks.

### T0 — Rule-Based (deterministic, no weights, always resident, ~0 footprint)

| Cell | File | Base Model | Latency | Resident |
|------|------|-----------|---------|----------|
| Action Guard | `guard/rule_action_guard.md` | — (rules) | <1ms | ✅ |
| Intent Classifier | `router/100m_intent_router.md` | Qwen2.5-0.5B-Instruct | <50ms | ✅ |
| Spam Detector | `router/100m_spam_detector.md` | Qwen2.5-0.5B-Instruct | <50ms | ✅ |
| Urgency Detector | `router/100m_urgency_detector.md` | Qwen2.5-0.5B-Instruct | <50ms | ✅ |
| Capture Scribe | `scribe/100m_capture_scribe.md` | Qwen2.5-0.5B-Instruct | <80ms | ✅ |
| Page Q&A | `scribe/100m_page_qa.md` | Qwen2.5-0.5B-Instruct | <30ms | ✅ |
| Retrieval Ranker | `router/100m_retrieval_ranker.md` | Qwen2.5-0.5B-Instruct | <80ms | ✅ |
| Title Generator | `summarizer/100m_title_generator.md` | Qwen2.5-0.5B-Instruct | <40ms | ✅ |

T0 total resident memory budget: ≤300 MB.

### T1 — Frequently Resident (300M–1.7B, <200ms)

| Cell | File | Base Model | Latency | Resident |
|------|------|-----------|---------|----------|
| Orchestrator | `orchestrator/1b_orchestrator.md` | Qwen2.5-1.5B-Instruct | <80ms | ✅ |
| Librarian (100M) | `librarian/100m_librarian.md` | Qwen2.5-0.5B-Instruct | <80ms | ✅ |
| Librarian (1B) | `librarian/1b_librarian.md` | Qwen2.5-1.5B-Instruct | <200ms | — |
| Summarizer | `summarizer/1b_compressor.md` | Qwen2.5-1.5B-Instruct | <200ms | ✅ |
| Memory Compressor | `summarizer/1b_memory_compressor.md` | Qwen2.5-1.5B-Instruct | <200ms | — |
| Link Scorer | `router/1b_link_scorer.md` | Qwen2.5-0.5B-Instruct | <50ms | ✅ |

T1 total resident memory budget: ≤800 MB.

### T2 — On-Demand Workers (1.7B–4B, <500ms)

| Cell | File | Base Model | Latency | Resident |
|------|------|-----------|---------|----------|
| Auditor (1B) | `auditor/1b_auditor.md` | Qwen2.5-1.5B-Instruct | <500ms | — |
| Auditor (8B) | `auditor/8b_auditor.md` | Qwen2.5-Coder-7B-Instruct | <3s | — |
| Planner (1B) | `planner/1b_planner.md` | Qwen2.5-1.5B-Instruct | <500ms | — |
| Planner (8B) | `planner/8b_planner.md` | Qwen2.5-Coder-7B-Instruct | <3s | — |
| Research Gatherer | `researcher/1b_research_gatherer.md` | Qwen2.5-1.5B-Instruct | <500ms | — |

T2 evicted when idle. Zero resident memory.

### T3 — Rare Escalations (4B–8B, <5s)

| Cell | File | Base Model | Latency | Resident |
|------|------|-----------|---------|----------|
| Deep Reasoner | `reasoner/8b_deep_reasoner.md` | Qwen2.5-Coder-7B-Instruct | <4s | — |
| Coder (1B) | `coder/1b_coder.md` | Qwen2.5-1.5B-Instruct | <500ms | — |
| Coder (8B) | `coder/8b_coder.md` | Qwen2.5-Coder-7B-Instruct | <4s | — |
| Research Synthesizer | `researcher/8b_research_synthesizer.md` | Qwen2.5-Coder-7B-Instruct | <4s | — |

T3 fully evicted between uses. Loaded on demand, unloaded after generation.

### Browser Family (CDP-Native, Targets Chromium DevTools Protocol)

| Cell | File | Base Model | Latency |
|------|------|-----------|---------|
| DOM Scout | `browser/100m_dom_scout.md` | Qwen2.5-0.5B-Instruct | <50ms |
| Action Planner | `browser/1b_action_planner.md` | Qwen2.5-1.5B-Instruct | <200ms |
| Nav Reasoner | `browser/8b_nav_reasoner.md` | Qwen2.5-Coder-7B-Instruct | <4s |

### Runtime Contracts (Phase 4)

| Doc | File | Purpose |
|-----|------|---------|
| RAM Manager | `router/ram_manager.md` | Load/unload, priority, OOM policy, concurrent Cell caps |
| Model Council | `council/model_council.md` | When to vote, how to break ties, when a tiny Cell is enough |
| Council Chair | `council/1b_council_chair.md` | Chair synthesis protocol for multi-model parallel dispatch |
| Cell Orchestrator | `orchestrator/Cell_orchestrator.md` | Task graph, no silent early-stop, resume protocol |
| Punch-Up Tests | `eval/punch_up_tests.md` | How 1B coder is tested vs ~30B class on same jobs |

---

## Dependency Graph (Who Calls Whom)

```
User Input
  │
  ├─→ IntentOrchestrator (deterministic, pre-model)
  │     │
  │     ├─→ [systemCommand] → no model needed
  │     ├─→ [browserAction] → no model needed  
  │     ├─→ [pageQuestion]  → page_qa (scribe/100m)
  │     ├─→ [webResearch]   → librarian → webSearchProvider
  │     └─→ [generic]       → librarian → orchestrator
  │
  ├─→ Spam Detector (router/100m)
  │     └─→ Action Guard (guard/rule) — gates all privileged actions
  │
  └─→ Orchestrator (orchestrator/1b)
        │
        ├─→ [capture]      → Capture Scribe (scribe/100m) → Honeycomb
        ├─→ [search]       → Retrieval Ranker (router/100m) → Honeycomb FTS
        ├─→ [summarize]    → Summarizer (summarizer/1b)
        ├─→ [plan]         → Planner (planner/1b or 8b)
        ├─→ [audit]        → Auditor (auditor/1b or 8b)
        ├─→ [code]         → Coder (coder/1b or 8b) → Studio
        ├─→ [research]     → Research Gatherer → Research Synthesizer
        ├─→ [reason]       → Deep Reasoner (reasoner/8b)
        │
        └─→ Model Council (council/1b_council_chair)
              ├─→ MLX Local
              ├─→ Tavily Cloud
              └─→ BYOK Remote
```

## RAM Budget Rules

### Total Budget: 8 GB on M1 Air (target floor)

| Component | Resident Budget | Notes |
|-----------|----------------|-------|
| OS + browser process | ~2.5 GB | macOS, CEF renderers, SwiftUI chrome |
| T0 always-resident Cells | ≤300 MB | 8×0.5B cells share one loaded base (Qwen2.5-0.5B ≈ 300 MB quantized) |
| T1 frequently-resident Cells | ≤800 MB | 1.5B base ≈ 900 MB quantized, shared by 6 roles |
| T2/T3 on-demand | ≤3 GB | Loaded individually, evicted when idle |
| Web content (tabs) | Remaining | CEF renderers per tab |
| Headroom | ≥1 GB | For spikes, new tabs, OS pressure |

### Maximum Concurrent Loaded Params

- **T0 Base (0.5B):** Always loaded. 1 instance serves all 8 T0 Cells.
- **T1 Base (1.5B):** Always loaded. 1 instance serves all 6 T1 Cells.
- **T3 Base (Coder-7B):** At most 1 instance loaded. Adapter-swapped per role.
- **Total concurrent loaded model instances:** ≤3 (0.5B + 1.5B + one of 7B).

### Unload Policy

1. T2/T3 Cells: Unload immediately after generation completes (streaming → unload on final token).
2. T1 Cells: Unload when memory pressure exceeds 85%. Reload on next request.
3. T0 Cells: Never unloaded — the 0.5B base is always resident.
4. On OOM warning (macOS memory pressure critical): Unload all T2/T3, then all T1. Keep T0 base.
5. Unload order: largest first (7B → 1.5B → 0.5B).

### Load Priority (When Multiple Requests Queue)

1. T0 Cells (always loaded, no load time)
2. T1 Orchestrator (required for routing)
3. T1 Librarian/Summarizer (required for context assembly)
4. T2 Auditor (security-critical — gates privileged actions)
5. T2 Planner (required before any execution)
6. T3 Coder/Reasoner (on-demand generation)
7. T3 Research (background task, lowest priority)

---

## Council Composition Rules

See `council/model_council.md` for full protocol. Summary:

1. **Minimum quorum:** 2 providers must respond for a valid verdict.
2. **Tie-breaking:** When providers disagree, escalate to the 8B reasoner.
3. **Single-provider sufficiency:** When only MLX local is available, a single T1 Cell (librarian) is sufficient for generic Q&A; do not convene the council.
4. **Degradation is honest:** When fewer than configured providers respond, the verdict carries `isDegraded: true` and the UI shows which providers answered.

### When a Tiny Cell is Enough (No Council Needed)

| Scenario | Sufficient Cell | Why |
|----------|----------------|-----|
| "What does this page say?" | `page_qa` (100M) | Grounded, single-source, no synthesis |
| "Close this tab" | None (system command) | Deterministic, no model |
| "Search for X" | `librarian` (100M) + WebSearchProvider | Web search gate, not reasoning |
| "Save as brief" | None (knowledge action) | File operation |
| "Fix typo in auth.swift" | `coder/1b` | Scoped, single-file, low risk |
| "Research competitive landscape" | Council → `research_synthesizer/8b` | Multi-source, high-stakes |

---

## Definition of Done for Each Family

### Router Family (spam, intent, urgency, link scorer, retrieval ranker)

- [x] Prompt file exists for each tier
- [ ] Deterministic JSON output schema specified and enforced
- [ ] Temperature = 0.0, top_p = 1.0, no sampling
- [ ] Max output tokens enforced (≤64 for all routers)
- [ ] Punched-up vs same-size generalist (evaluated via `eval/punch_up_tests.md`)
- [ ] Held-out verdict recorded in ModelManifest

### Guard Family (action guard)

- [x] Deterministic rules documented (no model, no weights)
- [ ] Every privileged action has a typed rule
- [ ] Trust level T0–T5 mapped to confirmation requirements
- [ ] Deny path tested for all T3–T5 actions

### Scribe Family (capture scribe, page Q&A)

- [x] Prompt file exists for each
- [ ] Keep/skip triage rules for automatic capture
- [ ] Fact/decision/commitment extraction schema
- [ ] Dedup rules across captures
- [ ] Grounded Q&A with citation spans from DOM excerpt

### Orchestrator Family

- [x] Intent → Cell dispatch rules
- [ ] Multi-step plan generation with Cell topology
- [ ] No silent early-stop: every plan has explicit completion criteria
- [ ] Resume protocol: if interrupted, can resume from last completed step

### Librarian Family

- [x] Entity/claim extraction schema
- [ ] Metadata tagging with provenance
- [ ] Doc type classification
- [ ] Up-tier to 1B for complex multi-entity extraction

### Summarizer Family (compressor, memory compressor, title generator)

- [x] Compression without key-claim loss
- [ ] Memory compaction: re-summarize Honeycomb deltas
- [ ] Title generation: ≤16 tokens, descriptive

### Auditor Family

- [x] Contradiction detection across claims
- [ ] Staleness checking with domain-specific half-life
- [ ] Provenance chain verification
- [ ] Up-tier to 8B for security-critical audits

### Planner Family

- [x] Multi-step plan generation
- [ ] Cell topology: which Cells are needed for each step
- [ ] Capability + data-scope requests per step
- [ ] Up-tier to 8B for complex multi-branch plans

### Coder Family

- [x] Repo-aware code generation/edit
- [ ] Bounded execution: no unrestricted shell
- [ ] Plan before write for non-trivial changes
- [ ] Diff preview before approval
- [ ] Git-aware rollback
- [ ] 1B tier: local edits only; 8B tier: full project reasoning

### Researcher Family

- [x] Gatherer: fetch + pre-score candidate sources
- [ ] Synthesizer: multi-source cited synthesis → brief
- [ ] Source credibility scoring
- [ ] Claim extraction with quote/span references
- [ ] Staleness half-life by domain

### Browser Family

- [x] DOM Scout: extract interactable elements from AXTree
- [ ] Action Planner: map intent → CDP tool calls
- [ ] Nav Reasoner: multi-step browsing task decomposition

### Council Family

- [x] Multi-provider parallel dispatch
- [ ] Chair synthesis with confidence-weighted voting
- [ ] Majority verdict with explicit dissent recording
- [ ] Honest degradation when providers are unavailable

---

## Model Tier → Serving Strategy Matrix

| Tier | Strategy | Base Model | Quantized Size | Latency Target |
|------|----------|-----------|---------------|----------------|
| T0 rule | ruleBased | — | 0 MB | <1ms |
| T0 instruct | instructOffTheShelf (or LoRA) | Qwen2.5-0.5B | 300 MB | <50ms |
| T1 instruct | instructOffTheShelf | Qwen2.5-1.5B | 900 MB | <80ms |
| T2 instruct | instructOffTheShelf | Qwen2.5-1.5B | 900 MB | <500ms |
| T3 instruct | instructOffTheShelf | Qwen2.5-Coder-7B | 4.3 GB | <5s |
| Embeddings | systemEmbedder | NLEmbedding (v1) / nomic (upgrade) | 0/560 MB | <10ms |
| BYOK | byokRemote | User-supplied | — | <2s |
| Apple FMF | appleFMF | Apple Foundation Models | — | <300ms |

---

## Inventory status

The root source-prompt corpus currently has 41 Markdown files. Its historical 33-file checklist below is retained as provenance only; it is not a completion or release claim. The packaged tree is the authoritative location for current progress and execution ordering.

## Naming Convention

```
Swarm_System_Prompts/
  {role}/
    {tier}_{role}.md

Examples:
  router/100m_intent_router.md    — T0 intent classifier
  router/1b_link_scorer.md        — T1 link scorer
  coder/1b_coder.md               — T2 coder (primary tier)
  coder/8b_coder.md               — T3 coder (up-tier)
  council/model_council.md        — Runtime contract
  router/ram_manager.md           — Runtime contract
```
