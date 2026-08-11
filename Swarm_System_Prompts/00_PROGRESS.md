# Swarm System Prompts — Progress Tracker

> **Canonical status:** active
> **Last updated:** 2026-08-11
> **Purpose:** Tracks every Cell file creation/update. Checked boxes = prompt file exists and is populated.

## Phase 0 — Audit & Plan ✅

- [x] Inventory source system prompts (SYSTEM PROMPT LEAKS/ no longer on disk — using Swift source code CellPromptLoader.swift + ModelManifest.swift as canonical reference)
- [x] Propose Cell taxonomy (19 ModelRoles → 23 Cell prompt files + 5 runtime contracts + 3 browser family = 31 files)
- [x] Write `00_INDEX.md`
- [x] Write `00_PROGRESS.md` (this file)

## Phase 1 — Scaffold ✅

- [x] Create `Swarm_System_Prompts/` directory
- [x] Create all 14 role subdirectories: guard, router, scribe, orchestrator, librarian, summarizer, auditor, planner, reasoner, coder, researcher, council, eval, browser

## Phase 2 — Distill ✅ Pass 1 Complete (2026-08-11)

### Guard Family
- [x] `guard/rule_action_guard.md` — T0 rule-based action gating

### Router Family
- [x] `router/100m_intent_router.md` — T0 intent classifier
- [x] `router/100m_spam_detector.md` — T0 spam detection
- [x] `router/100m_urgency_detector.md` — T0 urgency scoring
- [x] `router/1b_link_scorer.md` — T1 link candidate scoring
- [x] `router/100m_retrieval_ranker.md` — T0 Honeycomb retrieval ranking

### Scribe Family
- [x] `scribe/100m_capture_scribe.md` — T0 automatic capture triage
- [x] `scribe/100m_page_qa.md` — T0 grounded page Q&A

### Orchestrator Family
- [x] `orchestrator/1b_orchestrator.md` — T1 top-level routing and dispatch
- [x] `orchestrator/Cell_orchestrator.md` — Phase 4 runtime contract

### Librarian Family
- [x] `librarian/100m_librarian.md` — T0 entity/claim extraction
- [x] `librarian/1b_librarian.md` — T1 up-tier librarian

### Summarizer Family
- [x] `summarizer/1b_compressor.md` — T1 text compression
- [x] `summarizer/100m_title_generator.md` — T0 title generation
- [x] `summarizer/1b_memory_compressor.md` — T1 memory delta compaction

### Auditor Family
- [x] `auditor/1b_auditor.md` — T2 auditor
- [x] `auditor/8b_auditor.md` — T3 up-tier auditor

### Planner Family
- [x] `planner/1b_planner.md` — T2 planner
- [x] `planner/8b_planner.md` — T3 up-tier planner

### Reasoner Family
- [x] `reasoner/8b_deep_reasoner.md` — T3 deep reasoning

### Coder Family
- [x] `coder/1b_coder.md` — T2 coder (primary)
- [x] `coder/8b_coder.md` — T3 up-tier coder

### Researcher Family
- [x] `researcher/1b_research_gatherer.md` — T2 research gatherer
- [x] `researcher/8b_research_synthesizer.md` — T3 research synthesis

### Browser Family
- [x] `browser/100m_dom_scout.md` — T0 DOM element extraction
- [x] `browser/1b_action_planner.md` — T1 CDP action planning
- [x] `browser/8b_nav_reasoner.md` — T3 multi-step navigation reasoning

### Council Family
- [x] `council/model_council.md` — Phase 4: voting/tie-breaking contract
- [x] `council/1b_council_chair.md` — T1 chair synthesis

### Runtime Contracts
- [x] `router/ram_manager.md` — Phase 4: load/unload, priority, OOM
- [x] `eval/punch_up_tests.md` — Phase 4: benchmark methodology

## Phase 3 — Frontier Alignment

Not started. Requires source prompt leaks from frontier providers (Claude, GPT, Gemini, Perplexity, etc.) for gap analysis.

## Phase 4 — Runtime Contracts

Not started. Pending completion of all Cell prompt files.

## Distillation Pass Log

| Pass | Date | Description | Files Touched | Status |
|------|------|-------------|---------------|--------|
| Pass 1 | 2026-08-11 | Initial Cell prompt creation from Swift source analysis — ALL 33 files populated with full template sections | All 33 files | ✅ Complete |
| Pass 1 verify | 2026-08-11 | swift build passes; all 33 .md files on disk; CellPromptLoader mappings verified against all created files | 33 files | ✅ Complete |

## File Status Summary

| Directory | Files Needed | Files Created | Populated |
|-----------|-------------|---------------|-----------|
| guard/ | 1 | 1 | 1 |
| router/ | 6 | 6 | 6 |
| scribe/ | 2 | 2 | 2 |
| orchestrator/ | 2 | 2 | 2 |
| librarian/ | 2 | 2 | 2 |
| summarizer/ | 3 | 3 | 3 |
| auditor/ | 2 | 2 | 2 |
| planner/ | 2 | 2 | 2 |
| reasoner/ | 1 | 1 | 1 |
| coder/ | 2 | 2 | 2 |
| researcher/ | 2 | 2 | 2 |
| browser/ | 3 | 3 | 3 |
| council/ | 2 | 2 | 2 |
| eval/ | 1 | 1 | 1 |
| Root | 2 | 2 | 2 |
| **Total** | **33** | **33** | **33** |

## Known Blockers

None. All source material (Swift source code) is available on disk.

## Next Action

Write all Cell `.md` prompt files, starting with the most critical: guard, router family, and orchestrator.
