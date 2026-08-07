# Swarm System Prompts — Progress Log

## Phases
- [x] **Phase 0** — Audit & plan (INDEX + PROGRESS created)
- [x] **Phase 1** — Scaffold (all Cell×tier files created as stubs)
- [x] **Phase 2** — Distill (≥5 full passes completed)
- [x] **Phase 3** — Frontier alignment (all non-stub Cells aligned)
- [x] **Phase 4** — Runtime contracts (RAM, council, orchestrator, eval docs present)

| Pass 40 | 2026-08-02 | **LEAKED-FRONTIER AUDIT — 12 leaked system prompts read in full (Claude Opus 4.7/4.6/4.5, Sonnet 4.5, Haiku 4.5, GPT-5, GPT-4.5, Gemini 2.5 Pro, Grok 4, Perplexity, Kimi K2 ×2). Created researcher/1b_research_gatherer (the search→fetch→evidence loop — the documented gap where synthesizer refuses to search, link_scorer never fetches, dom_scout only reads open tabs).** 15 distilled rules with verbatim extracts: query-syntax bans + 1–6 word queries + distinct-query rule, call-count ladder (1/3–5/5–10), rate-of-change search gate, tool/answer phase split, 3-call budget, no-identical-requests, batched fetches, browse-instruction arg, distribution-of-sources, 15-word quote cap, harmful-content exclusion, proceed-and-document. AUGMENTATION_LOG +53 patches (52→53). INDEX roster 32→33 Cells, 43→44 files. Punch-up verdict: OTS-only (expected NO_GAIN, rule-rich × deterministic). | 1 new Cell + INDEX + AUGMENTATION_LOG + PROGRESS |
| Pass 35 | 2026-07-27 | **TRAINING RUNNER SPEC** — Created TRAINING_RUNNER_SPEC.md (537 lines) bridging all 46 spec files to executable pipeline. Defines: data flow (seed→augment→pair→train→eval→export), MLX LoRA config format, 8 quality gates from MODEL_QUALITY, CoreML export + RAM budget, Makefile workflow, cost tracking. Fixed 7 code-review issues (batch size, RAM estimates, budget alignment, quality gates, field names, dependencies). | 1 new file + 7 fixes |
| Pass 34 | 2026-07-27 | **Prior expansion wave — 2 Cells expanded with 13 rules from 7 provider extracts.** auditor/1b_auditor (7 rules from Claude Research Instructions, Stack Overflow AI Assist, Claude Cowork, Perplexity Comet → 127→152 lines). council/model_council (6 rules from Cowork Dispatch, Apple Intelligence, GPT-5.5 Instant → 102→123 lines). Total library: 10,939 lines across 43 files. Zero TRUNCATED markers in any file. All specialist Cells ≥140 lines (most >150). All control docs expanded. | 2 Cells expanded |
| Pass 33 | 2026-07-27 | **NINTH EXPANSION WAVE — 5 Cells expanded with 55 rules from 28 provider extracts.** router/100m_intent_router (12 rules from 6 providers — GPT-5.5, Sonnet, Grok, Apple Intelligence, Copilot CLI, Comet). browser/100m_dom_scout (12 rules from 6 providers — Playwright, Comet, Claude-in-Chrome, Brave, Fellou, Apple Intelligence). browser/8b_nav_reasoner (12 rules from 6 providers — Comet, Claude-in-Chrome, Playwright, Codex CU, Brave, Claude Code). planner/1b_planner (10 rules from 5 providers — Gemini CLI, Comet, Codex, Cowork, GPT-5.5 Thinking). council/1b_council_chair (9 rules from 5 providers — deduplicated against Pass 31; removed 2 duplicate GPT-5.5 rules). Fix: dedup of GPT-5.5 Instant rules between Pass 31 and 33 in council_chair. Total files: 10,892 lines, zero TRUNCATED markers. | 5 Cells + 1 dedup fix |
| Pass 32 | 2026-07-27 | **EIGHTH EXPANSION WAVE — 8 Cells massively expanded with verbatim extracts from 49 provider extracts.** Core 8B Cells: reasoner/8b_deep_reasoner (15 rules from 6 providers — GPT-5.5 Thinking, DeepSeek R1, Claude Opus 4.7, Kimi K3, Grok 4.5, Perplexity Deep Research). coder/8b_coder (13 rules from 6 providers — Claude Code Fable 5, OpenAI Codex, Aider, Cursor, Claude Code Sonnet 5, GitHub Copilot). planner/8b_planner (12 rules from 6 providers — Claude Cowork Dispatch, Muse Spark 1.1, Gemini CLI, Perplexity Comet, OpenAI Codex, Claude Opus 5). auditor/8b_auditor (12 rules from 5 providers — Codex Auto Review, Claude Research Instructions, Claude Cowork, Claude in Chrome, NotebookLM). Core 1B Cells: coder/1b_coder (13 rules from 6 providers). 100M Cells: librarian/100m_librarian (12 rules from 7 providers). Summarizer: 1b_compressor (12 rules from 6 providers), 1b_memory_compressor (12 rules from 7 providers — deduplicated against existing Rewisp rules). **All 8 Cells now ≥141 lines (7 of 8 ≥150).** Fix: deduplicated 5 overlapping Rewisp rules in 1b_memory_compressor. | 8 Cells + 1 dedup fix |

## Pass Log

| Pass | Date | Scope | Files Touched |
| Pass 27 | 2026-07-27 | **Ninth source prompt mining — Full model training infrastructure defined.** Reads: Claude Code agent definitions (Plan architect, Explore search, General Purpose multi-step, Worker autonomous, Claude Code Guide docs retrieval). Claude Design Starter components (deck-stage.js — 2,200-line web component). Claude Code frontend-design skill. **Created MODEL_SPEC.md, TRAINING_DATA_GUIDE.md, MODEL_QUALITY.md.** | 3 training specs + 3 Claude Code agents |
| Pass 28 | 2026-07-27 | **Tenth wave — Conversation Cell + AUGMENTATION_LOG + competitive dossier.** Created conversation/8b_conversation.md (32K context). Fixed all 7 code-review issues. Created AUGMENTATION_LOG.md (52 frontier gap patches). Launched 4 competitive research agents. Created PITCH/research-dossier.md. | 3 files + 5 fixes |
| Pass 29 | 2026-07-27 | **MASSIVE CELL EXPANSION WAVE — 4 Cells expanded with verbatim source extracts.** Read 9 remaining Claude Design skills (animated-video, 3d-object, maps-geography, flier, html-email, save-as-pdf, save-as-standalone-html, wireframe, hi-fi-design). Launched 4 more competitive research agents (enterprise SaaS, creative tools, developer tools, email/communication). **Expanded 4 Cells to 500+ lines with verbatim extracts:** conversation/8b_conversation.md (12+ source prompts: Claude Voice Mode, Cowork, Notion AI, Gemini, ChatGPT Agent Mode, GPT-5 Listener/Robot/Nerd, Grok, Pi, Kimi, Apple Intelligence). tutor/100m_tutor_specialist.md (15 rules from Gemini Guided Learning, 12 from Gizmo, Khan Academy, Sonnet, Kimi). voice/100m_voice_specialist.md (12 rules from Claude Voice Mode, 8 from ElevenLabs, 10 from Sesame Maya, Character AI, Gemini Live, Mobile iOS). design/100m_presentation_specialist.md (12 rules from Claude for PowerPoint, 8 from make-a-deck, 6 from frontend-design, Visualize color system). Fixed 6/7 code-review issues (labels, contradictions, laugh guardrails, frontier gap refs). | 4 Cells massively expanded + 4 research agents + 6 fixes |
|------|------|-------|---------------|
| Pass 1 | 2026-07-26 | Source prompt sweep: Claude-in-Chrome, Claude Cowork, Claude Design, Claude for Excel/Word/PowerPoint, Codex, Composer/Cursor/Codebuff | All 20 Cell files |
| Pass 2 | 2026-07-26 | Commands: Cursor, Aider, Claude Code, Cline/Claude Dev, Copilot, Gemini CLI, Ollama, Zed, CodeGPT, Continue, Cody, Tabnine, Sourcegraph | All 20 Cell files |
| Pass 3 | 2026-07-26 | Frontier alignment: Opus/Sonnet/Haiku for coder/planner/auditor/librarian; Perplexity for researcher | 16 Cell files |
| Pass 4 | 2026-07-26 | Deep research prompts: NotebookLM, Gemini Deep Research, Perplexity Pro, Google AI Studio, Gemini Workspace, Gemini 2.5 Pro | Researcher, Librarian, Oracle, Planner |
| Pass 5 | 2026-07-26 | Safety prompts: Claude Opus/Sonnet/Haiku guardrails, Grok, Gemini, Llama, Mistral, Pi | Guard, Auditor, Council, Router |
| Pass 6 | 2026-07-26 | Consolidation pass — merged overlapping rules, fixed conflicts | All 20 Cell files + progress + index |
| Pass 7 | 2026-07-26 | Competitive expansion — 19 product categories across major competitive landscape | 101-section dossier + 8 Cells |
| Pass 8 | 2026-07-27 | Second source prompt mining — 14 new prompts (Cursor Rules, Aider, Codex CLI, Copilot, Gemini CLI, Cody, Sourcegraph Cody, Ollama, Cline, Continue.dev, Tabnine, Amazon Q, CodeGemma, Qwen Coder) | Coder, Planner, Auditor, Orchestrator |
| Pass 9 | 2026-07-27 | Third competitive expansion — 20 new categories (100+ total) | Dossier + Planner, Librarian, Coder |
| Pass 10 | 2026-07-27 | Consolidation + frontier alignment refresh — sync with 100+ categories | All 20 Cells + dossier |
| Pass 11 | 2026-07-27 | Fourth competitive expansion — 3 new categories: parenting, calendar, note-taking (113 total, 340+ products) | Dossier + Librarian |
| Pass 12 | 2026-07-27 | Fifth competitive expansion — 11 new categories: social media, file sharing, mindfulness, habit tracking, meditation, sleep tracking, weather, expense tracking, CRM, marketing automation, project management (124 total, 420+ products) | Dossier + Librarian + Planner |
| Pass 13 | 2026-07-27 | Third source prompt mining — 10 new prompts (Anthropic Interviewer, Claude for Word, Claude for Excel, Claude for PowerPoint, Claude Fable 5, Claude Sonnet 4.6, Claude Voice Mode, Claude Mobile iOS, Grok personalities, Grok expert) | All Cells |
| Pass 14 | 2026-07-27 | Sixth competitive expansion + second wave source mining — 180+ products across 39 categories (travel, real estate, insurance, banking, investing, legal, tax, payroll, HR, recruitment, ATS, video editing, photo management, note-taking, b2b SaaS, consumer AI, indie productivity) | Dossier + All 20 Cells |
| Pass 15 | 2026-07-27 | Fourth source prompt mining — Claude Research Instructions, Gemini CLI, Gemini Chrome, Claude Sonnet 4.6 no-tools, Claude Opus 4.6, Claude Opus 4.6 no-tools, Grok 4.1-beta, Claude Haiku 3.5, additional Grok variants | All 20 Cells |
| Pass 16 | 2026-07-27 | Fifth source prompt mining — 10 new prompts: t3-code, Confer, Zed, Warp 2.0, Devin CLI, Amp Code, CommandCode CLI, Google Gemini workspaces, Perplexity AI, Perplexity Comet | All 20 Cells |
| Pass 17 | 2026-07-27 | Seventh competitive expansion — 10 new categories: weather, expense tracking/spreadsheets, real estate/proptech, cloud/web hosting, password managers, developer tooling, AI platforms, business analytics | Dossier + All 20 Cells |
| Pass 18 | 2026-07-27 | Eighth competitive expansion — 7 new categories: browser-native desktop utility/app launcher, window management, menu bar management, focus/screen time, wellness, AI voice assistants, AI browser assistants | Dossier + All 20 Cells |
| Pass 19 | 2026-07-27 | Ninth competitive expansion — 4 new categories: productivity method/GTD deep dive, gamification/discipline, habit tracking analysis, digital minimalism philosophy | Dossier + All 20 Cells |
| Pass 20 | 2026-07-27 | Tenth competitive expansion — 4 new categories: journaling/diary, personal CRM, AI companion/boyfriend/girlfriend apps, human connection versus AI connection analysis | Dossier + All 20 Cells |
| Pass 21 | 2026-07-27 | Consolidation pass — merged overlapping extracted rules across all Cells. 8 canonical invariants (NEVER-INVENT, TOOL-FIRST, TOOL CALL DISCIPLINE, BANNED WORDS/ANTI-SLOP, SOURCE PROVENANCE, SCOPE DISCIPLINE, VERIFY-BEFORE-DONE, PARALLEL FETCHES) consolidated into lead section. Cell-specific pass rules preserved below. | All 20 Cells |
| Pass 22 | 2026-07-27 | Expanded CellPromptLoader.swift cellRoleMapping (10→13 roles), upTier support, created 3 dedicated prompts (retrievalRanker, titleGenerator, memoryCompressor), fixed build + tests | CellPromptLoader.swift, HiveApp.swift, 3 new .md files |
| Pass 23 | 2026-07-27 | 11th competitive expansion — 8 new categories (real estate, cloud storage, password managers, career platforms, gaming, photo management, education, streaming). 500+ products across 101 categories. | Dossier + Control docs + file integrity |
| Pass 24 | 2026-07-27 | Sixth source prompt mining. 90+ prompts across 11 providers. Claude Code (Fable 5, Opus 4.7/4.8/4.6, Sonnet 4.6/5, Haiku 4.5 + agents), Cowork/Dispatch/Design, Voice Mode, Mobile iOS, In Chrome, Fable 5, Perplexity Comet/Deep Research/AI/Computer, t3-code, Confer, Zed, Warp 2.0, Devin CLI, Amp Code (11 modes), CommandCode CLI, Gemini CLI, Jules, Workspace, NotebookLM, ChatGPT GPT-5 Agent Mode, GPT-5.5 Thinking, OpenAI Deep Research, GitHub Copilot full, VS Code Copilot, Copilot macOS, Meta Spark, Grok 4.5/4.3/4.2, Docker Gordon AI, Brave Search, Stack Overflow AI. Created 100m_observer + 1b_teammate. | 2 new Cells |
| Pass 25 | 2026-07-27 | Seventh source prompt mining. 65+ prompts: Claude Design Skills (8 files), Excel/Word/PowerPoint, Visualize, Interviewer, Research Instructions, Cursor, DeepSeek, Microsoft Copilot CLI/macOS/VSCode/Word/GitHub, Google (Gemini 2.5 Pro/3 Flash/Search AI/AI Studio/2.5 Flash Image/Diffusion/In Chrome/YouTube/3.1 Pro/2.5 Pro API/2.0 Flash/Guided Learning/Nano Banana 2/Antigravity CLI), OpenAI (GPT-5.5 Instant/5.3 Codex/5.3 Instant/5.5 API/5.1 variants), xAI (Grok 4.1/4/3), Misc (Gizmo/Reddit Answers/T3 Chat/MiniMax M2.5/Fellou/OpenCode). | 65+ prompts. 150+ total. |
| Pass 26 | 2026-07-27 | Eighth source prompt mining. 7 additional prompts: Pi, Notion AI, Kimi K2.6/K3, Mistral Medium 3.5/Code. All 11 provider directories fully inventoried. **Filled 3 stubs** (100m_title_generator, 1b_memory_compressor, 100m_retrieval_ranker). **Created 5 new specialists**: 100m_sheet_specialist, 100m_document_specialist, 100m_presentation_specialist, 100m_tutor_specialist, 100m_voice_specialist. | 3 stubs filled, 5 new Cells created. |
| Pass 27 | 2026-07-27 | Ninth source prompt mining — model training infrastructure. Created MODEL_SPEC.md, TRAINING_DATA_GUIDE.md, MODEL_QUALITY.md. | 3 training specs |
| Pass 28 | 2026-07-27 | Conversation Cell + AUGMENTATION_LOG + competitive dossier. | 3 new files |
| Pass 29 | 2026-07-27 | 4 Cells massively expanded (conversation, tutor, voice, presentation). | 4 Cells |
| Pass 30 | 2026-07-27 | **SECOND EXPANSION WAVE** — 6 Cells massively expanded with verbatim extracts from 6-7 providers each. Router (4): retrieval_ranker, spam_detector, intent_router, urgency_detector. Browser (1): dom_scout. Coder (1): document_specialist. All 4 code-review fixes applied. | 6 Cells + 4 fixes |
| Pass 31 | 2026-07-27 | **CORE CELL EXPANSION WAVE** — 3 core Cells massively expanded with verbatim extracts + 2 high-tier 8B Cells expanded. Council (1): 1b_council_chair (GPT-5.5, Sonnet, Muse Spark, Apple Intelligence, Cowork Dispatch, Copilot CLI — 9 rules). Planner (1): 1b_planner (Cowork, Gemini CLI, Copilot CLI, GPT-5.5, Comet, Gordon — 9 rules). Auditor (1): 1b_auditor (NotebookLM, Codex Auto Review, Jules, GPT-5.5 Pro, Opus 4.7 — 7 rules). Research (1): 8b_research_synthesizer (Perplexity Deep Research, NotebookLM, Gemini 3.1 Pro, Claude Research, GPT-5.5 Thinking — 10 rules). Browser (1): 8b_nav_reasoner (Comet, Claude-in-Chrome, Claude Code computer-use, Playwright — 7 rules). All consolidated invariants preserved. 3 corrupted files recovered from truncation. | 5 Cells expanded + 3 files recovered |

## Current File Inventory

| Role | Tier | File | Status |
|------|------|------|--------|
| orchestrator | 1B | `orchestrator/1b_orchestrator.md` | filled |
| Cell orchestrator | n/a | `orchestrator/Cell_orchestrator.md` | contract |
| planner | 1B | `planner/1b_planner.md` | filled |
| planner | 8B | `planner/8b_planner.md` | filled |
| coder | 1B | `coder/1b_coder.md` | filled |
| coder | 8B | `coder/8b_coder.md` | filled |
| coder (sheets) | 100M | `coder/100m_sheet_specialist.md` | filled (new) |
| coder (docs) | 100M | `coder/100m_document_specialist.md` | filled (new) |
| librarian | 100M | `librarian/100m_librarian.md` | filled |
| librarian | 1B | `librarian/1b_librarian.md` | filled |
| researcher | 8B | `researcher/8b_research_synthesizer.md` | filled |
| researcher | 1B | `researcher/1b_research_gatherer.md` | filled |
| summarizer | 1B | `summarizer/1b_compressor.md` | filled |
| summarizer | 100M | `summarizer/100m_title_generator.md` | filled (was stub) |
| summarizer | 1B | `summarizer/1b_memory_compressor.md` | filled (was stub) |
| auditor | 1B | `auditor/1b_auditor.md` | filled |
| auditor | 8B | `auditor/8b_auditor.md` | filled |
| browser | 100M | `browser/100m_dom_scout.md` | filled |
| browser | 1B | `browser/1b_action_planner.md` | filled |
| browser | 8B | `browser/8b_nav_reasoner.md` | filled |
| council | 1B | `council/1b_council_chair.md` | filled |
| council | 100M | `council/100m_observer.md` | filled |
| council | 1B | `council/1b_teammate.md` | filled |
| council chair | n/a | `council/model_council.md` | contract |
| reasoner | 8B | `reasoner/8b_deep_reasoner.md` | filled |
| router | 100M | `router/100m_intent_router.md` | filled |
| router | 100M | `router/100m_spam_detector.md` | filled |
| router | 100M | `router/100m_urgency_detector.md` | filled |
| router | 1B | `router/1b_link_scorer.md` | filled |
| router | 100M | `router/100m_retrieval_ranker.md` | filled (was stub) |
| guard | rule | `guard/rule_action_guard.md` | filled |
| eval | n/a | `eval/punch_up_tests.md` | contract |
| design | 100M | `design/100m_presentation_specialist.md` | filled (new) |
| tutor | 100M | `tutor/100m_tutor_specialist.md` | filled (new) |
| voice | 100M | `voice/100m_voice_specialist.md` | filled (new) |
| conversation | 8B | `conversation/8b_conversation.md` | filled |
| scribe | 100M | `scribe/100m_capture_scribe.md` | filled |
| scribe | 100M | `scribe/100m_page_qa.md` | filled |
| index | n/a | `00_INDEX.md` | current |
| progress | n/a | `00_PROGRESS.md` | current |

**Total: 49 .md files** — 35 specialist Cells + 4 control docs + 3 model training docs + TRAINING_RUNNER_SPEC.md + seed_intent_plan.md + EXECUTION_PLAN.md + AUGMENTATION_LOG + INDEX + PROGRESS + research dossier (RESEARCH/competitive-dossier.md).

### Status: **35 Cell prompts filled** — zero stubs. **4 control docs present.** **3 training specs.** **Training runner spec.** **Seed intent plan** (8,200 intents). **Execution plan** (4 phases, 22 weeks). **Total: 13,098 lines.**

| Category | Count | Status |
|----------|-------|--------|
| Specialist Cell .md files | 35 | All filled, zero stubs |
| Control documents | 4 | RAM, council, orchestrator, eval |
| Model training specs | 3 | MODEL_SPEC, TRAINING_DATA_GUIDE, MODEL_QUALITY |
| Seed intent plan | 1 | seed_intent_plan.md — 830 lines |
| Execution plan | 1 | EXECUTION_PLAN.md — 267 lines |
| Conversation Cell | 1 | conversation/8b_conversation.md |
| AUGMENTATION_LOG | 1 | 53 frontier gap patches |
| INDEX + PROGRESS | 2 | Current |
| Research dossier (RESEARCH/) | 1 | 105 sections — competitive analysis |
| Training runner spec | 1 | TRAINING_RUNNER_SPEC.md — 540 lines |
| **Total .md files** | **49** | **Full coverage — complete Hive/Swarm specification** |
