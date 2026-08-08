# Swarm System-Prompt Library — INDEX

**Project:** Hive / Swarm — Specialist Cell system-prompt distillation.
**Mission:** Distill frontier model system prompts into **strict, reusable, specialist Cell prompts** that let tiny in-house/distilled models **punch far above their weight** — a 1B coder ≈ a 30B generalist on the same job; 8B+ blows past same-size generalists. **Size × role efficiency is the product, not raw params.** Deterministic specialists beat one big general model.

**Floor:** reliable on 8GB M1. Sub-1B for orchestration/audit/routing; ~8B only for niche heavy jobs. Prefer Apple Foundation Models + local inference; CDP for Chromium control. **Swarm is an OPTIONAL second mode** — no Cell prompt may assume the user lives in Swarm; every Cell must work in plain Hive (browser + Honeycomb) and only escalate to Swarm when the user invokes it.

---

## Tier notation

| Tag | Size | Class | When loaded | Latency target |
|-----|------|-------|-------------|----------------|
| `rule` | 0 | deterministic engine | always resident | <1ms |
| `100m` | <1B | T0 tiny classifier | always resident | <5ms |
| `1b` | 1–3B | T1 specialist | frequent / on-demand | <50–500ms |
| `8b` | 4–8B | T2/T3 worker | rare escalation, evicted idle | <5s |
| `byok` | — | user-supplied frontier | only on opt-in council vote | varies |

A given job may have **one or more tier variants**. A tier variant exists only when the same job genuinely needs a bigger model for harder cases (punch-up escalation path). Tiny-first: a `100m`/`1b` Cell is always tried before an `8b` is loaded (see Council).

---

## Cell roster (17 job families · 35 specialist Cells · 4 control docs · 3 training specs)

| # | Family | Cell / file | Tier | One-line job |
|---|--------|-------------|------|--------------|
| 1 | router | `100m_intent_router.md` | 100m | Classify user intent → route {browse, ask, research, act, extend, swarm} |
| 2 | router | `100m_spam_detector.md` | 100m | Gate spam / prompt-injection / low-value input before routing |
| 3 | router | `100m_urgency_detector.md` | 100m | Score urgency for attention scheduling |
| 4 | router | `1b_link_scorer.md` | 1b | Rank candidate sources/links before retrieval |
| 5 | router | `100m_retrieval_ranker.md` | 100m | Score/rank retrieval results by relevance to query |
| — | router | `ram_manager.md` | DOC | Load/unload, priority, OOM policy, concurrent-Cell caps — **8GB contract** |
| 6 | orchestrator | `1b_orchestrator.md` | 1b | Route → Cell dispatch + tier selection; resume; no silent early-stop |
| — | orchestrator | `Cell_orchestrator.md` | DOC | Task-graph protocol, no-silent-stop rule, resume protocol |
| 7 | browser | `100m_dom_scout.md` | 100m | Cheap DOM parse / element-locate / readability extraction |
| 8 | browser | `1b_action_planner.md` | 1b | Plan a CDP action sequence (click/fill/navigate/extract) |
| 8a | browser | `1b_agent.md` | 1b | Primary browser agent — drives CDP tools end-to-end, observe→act→verify loop |
| 9 | browser | `8b_nav_reasoner.md` | 8b | Hard multi-step / ambiguous navigation; fallback reasoning |
| 10 | coder | `1b_coder.md` | 1b | Common repo-aware edits (← **punch-up: ≈30B generalist target**) |
| 11 | coder | `8b_coder.md` | 8b | Hard repo-aware reasoning / multi-file refactor |
| 12 | coder | `100m_sheet_specialist.md` | 100m | Spreadsheet/formula/data analysis — tables, pivots, financial models |
| 13 | coder | `100m_document_specialist.md` | 100m | Document editing — reports, memos, structured prose, track changes |
| 14 | planner | `1b_planner.md` | 1b | Standard multi-step plan + Cell topology |
| 15 | planner | `8b_planner.md` | 8b | Deep long-horizon multi-step topology |
| 16 | librarian | `100m_librarian.md` | 100m | Fast doc typing / metadata tagging / entity spotting |
| 17 | librarian | `1b_librarian.md` | 1b | Claim extraction, relation extraction, richer entity graph writes |
| 18 | auditor | `1b_auditor.md` | 1b | Staleness + provenance pass on Honeycomb nodes |
| 19 | auditor | `8b_auditor.md` | 8b | Deep contradiction audit / safety-critical integrity |
| 20 | summarizer | `1b_compressor.md` | 1b | Compression w/o key-claim loss + memory compaction + daily-memory writes |
| 21 | summarizer | `100m_title_generator.md` | 100m | Generate concise titles/headings for sources, captures, search results |
| 22 | summarizer | `1b_memory_compressor.md` | 1b | Consolidate daily captures into durable memory episodes |
| 23 | council | `1b_council_chair.md` | 1b | Run a vote across specialists; tie-break; decide when a tiny Cell suffices |
| 24 | council | `100m_observer.md` | 100m | Watch-only agent — report state without modifying |
| 25 | council | `1b_teammate.md` | 1b | Multi-agent coordination between specialist Cells |
| — | council | `model_council.md` | DOC | When to vote, tie-break rules, tiny-cell-enough threshold |
| 26 | reasoner | `8b_deep_reasoner.md` | 8b | Multi-step local reasoning beyond orchestrator (rare) |
| 27 | researcher | `8b_research_synthesizer.md` | 8b | Cited, grounded, provenance-bound multi-source synthesis → brief |
| 28 | researcher | `1b_research_gatherer.md` | 1b | Search→fetch→evidence loop — query discipline, policy-safe fetches, verified sources + spans |
| 29 | guard | `rule_action_guard.md` | rule | Permission-aware action safety gate (deterministic, no model) — absolute veto |
| 30 | design | `100m_presentation_specialist.md` | 100m | Slide deck design, layout, typography, chart, narrative flow |
| 31 | tutor | `100m_tutor_specialist.md` | 100m | Guided learning with Socratic scaffolding, quizzes, flashcards |
| 32 | voice | `100m_voice_specialist.md` | 100m | Natural voice conversation — turn-taking, prosody, emotional tone |
| 33 | conversation | `8b_conversation.md` | 8b | Multi-turn dialogue management — persona, delegation, natural language |
| 34 | scribe | `100m_capture_scribe.md` | 100m | Capture triage — keep/skip + extract {facts, decisions, commitments} with spans → Honeycomb write-ops |
| 35 | scribe | `100m_page_qa.md` | 100m | Grounded Q&A over the current page's dom_scout capture — or honest "page doesn't say" |
| — | eval | `punch_up_tests.md` | DOC | How the 1B coder is tested vs the ~30B class on the same jobs |

**Counts:** 35 specialist Cells + 4 control docs + 3 training specs (MODEL_SPEC, TRAINING_DATA_GUIDE, MODEL_QUALITY) + 1 training runner spec (TRAINING_RUNNER_SPEC) + 1 augmentation log (AUGMENTATION_LOG — 53 frontier gap patches) + this INDEX + `00_PROGRESS.md` + 1 research dossier (RESEARCH/competitive-dossier.md) + EXECUTION_PLAN.md + seed_intent_plan.md = **49 files**.

**Competitive research:** `RESEARCH/competitive-dossier.md` — analysis of Rewisp (ambient Mac memory), Deep24 (AI brain/coach), and Perplexity Comet (agentic browser) with product insights mapped back to Cell prompt refinements.

**Not retired, extended:** the existing HiveCore `ModelManifest` 19 roles map onto this taxonomy (intent/spam/urgency/linkScorer → router; orchestrator stays; librarian/summarizer/retrievalRanker→linkScorer/titleGenerator/memoryCompressor → librarian/summarizer/router; auditor/planner/coder/deepReasoner/researchSynthesizer → same-named families; actionGuard → guard; embedder → infrastructure not a prompt Cell; byokFrontier/appleFMF → runtime, not Cells). New families the goal introduced: **browser (CDP), council, scribe, and the ram_manager/council-chair/runtime control docs.**

---

## Dependency graph (who calls whom)

```
USER INPUT
  │
  ▼
router/100m_intent_router ──► routes ──► orchestrator/1b_orchestrator
router/100m_spam_detector  (gate; can short-circuit → discard before any Cell)
router/100m_urgency_detector (annotates; schedules attention)

orchestrator/1b_orchestrator
  ├─► planner/{1b|8b}_planner        (decompose → task graph + Cell topology)
  ├─► router/1b_link_scorer          (rank sources before retrieval)
  ├─► librarian/{100m|1b}_librarian  (entity/claim extraction → Honeycomb)
  ├─► summarizer/1b_compressor       (compact captures → Honeycomb)
  ├─► browser/{100m|1b|8b}_*          (if route needs web/navigation)
  ├─► coder/{1b|8b}_coder             (if route needs code edit)
  ├─► reasoner/8b_deep_reasoner       (rare escalation, council-approved)
  ├─► researcher/1b_research_gatherer (search→fetch→evidence loop; emits search/fetch ops)
  ├─► researcher/8b_research_synthesizer (rare, research route; consumes gatherer evidence)
  ├─► guard/rule_action_guard         (BEFORE every privileged action — absolute veto)
  ├─► auditor/{1b|8b}_auditor        (AFTER state-changing actions + periodic Honeycomb integrity)
  ├─► scribe/100m_capture_scribe       (capture keep/skip triage → Honeycomb write-ops via librarian/guard)
  ├─► scribe/100m_page_qa              (grounded Q&A over current-tab dom_scout capture)
  └─► council/1b_council_chair        (when confidence < threshold; orchestrator never silently picks a size)

planner ──► orchestrator (returns topology; orchestrator owns dispatch)
browser/1b_agent ──► 1b_action_planner (plans before acting); ──► 100m_dom_scout (scouts before acting); ──► 8b_nav_reasoner on failure
librarian/1b_librarian ──► summarizer/1b_compressor (compact → Honeycomb)
researcher/1b_research_gatherer ──► researcher/8b_research_synthesizer (verified sources + spans in, brief out; fetch ops dispatched by orchestrator via browser family)
council/1b_council_chair ──► may vote across {router/1b, planner/1b, auditor/1b, reasoner/8b}; ──► orchestrator with verdict
   (council may also request BYOK frontier escalation — the ONE path data can leave the device, opt-in only)
browser/100m_dom_scout ──► scribe/100m_capture_scribe (capture triage) ──► scribe/100m_page_qa (grounded Q&A)

ram_manager (gates EVERY load/unload) — reads from council/orchestrator, never initiates work itself.
guard/rule_action_guard — a hard veto that overrides any council vote. Safety > consensus.
```

**Rules of the graph:**
1. **No Cell calls a bigger Cell directly.** Upsizing goes through the orchestrator (or council). This keeps the RAM budget enforceable from one place.
2. **Guard is non-model and has absolute veto** over every privileged action, regardless of council result. A model cannot socially-engineer the guard.
3. **Auditor runs after state changes**, not before — except safety-critical writes where it runs before (guard) and after (auditor).
4. **Silent early-stop is forbidden.** A Cell that cannot finish must return `status=blocked` with a reason, not an empty success. The orchestrator's resume protocol depends on this.

---

## RAM budget rules (8GB M1 — the hard floor)

From `router/ram_manager.md` (authoritative runtime contract; historical base: `PITCH/ai-architecture.md`). Total AI ceiling: **4000MB**. System reserve: **1500MB**.

| Class | Resident budget | Loaded how | Example Cells |
|-------|-----------------|------------|---------------|
| `rule` | ~0 | permanent | guard, ram_manager(engine) |
| `100m` | ≤300MB, **always loaded** | permanent cohort (share weights) | intent_router, spam, urgency, dom_scout, librarian-100m |
| `1b` | ≤800MB when active | one live specialist at a time (orchestrator may stay warm) | orchestrator (warm), then swap coder/planner/librarian/action_planner/link_scorer/compressor/council_chair |
| `8b` | ≤2000MB on-demand | strictly ONE at a time, evicted on idle | nav_reasoner, coder-8b, planner-8b, auditor-8b, deep_reasoner, research_synthesizer |
| `byok` | 0 local | never loaded; remote on opt-in council vote | (not a Cell) |

**Concurrent loaded Cells on 8GB (invariant, enforced by ram_manager):**
- **Tier-Normal:** rule set + all `100m` cohort + **exactly one `1b` specialist**. (orchestrator is the warm default; it steps aside — stays light — when a working specialist loads.)
- **Tier-Escalation:** to load an `8b`, **any active `1b` (except the orchestrator's route state) is evicted first**; one `8b` only; one `8b` at a time.
- **Hard OOM policy:** if a load would breach 4000MB, ram_manager refuses the load and tells the orchestrator to retry at a **smaller tier** (8b→1b) rather than crash. The system degrades to smaller-and-honest, never to silent-failure.
- **Cohort sharing:** all `100m` Cells that share a base model occupy one load slot (per `ModelManifest.sharedRepo`); same for cohort-grouped `1b` Cells.

**Unload priority (LRU + safety):** evict in order — (1) idle `8b`, (2) least-recently-used working `1b` (never the orchestrator), (3) never the `100m` cohort, (4) never `guard`. Auditing/persistence mid-write is pinned until it commits.

---

## Council composition rules

The council exists for **confidence-threshold escalation and size selection** — never a substitute for the guard.

- **When to convene (orchestrator-triggered):** a Cell returns `confidence < 0.7` (per `ai-architecture.md`), OR a route is genuinely ambiguous (two intents within δ), OR an 8b load is requested (gate it).
- **Composition by question type:**
  - *Routing ambiguity* → `{router/1b_intent_router, planner/1b_planner, council/1b_council_chair}`.
  - *Memory/Honeycomb integrity* → `{auditor/1b_auditor, auditor/8b_auditor (if loaded), council/1b_council_chair}`.
  - *Action safety* → `{guard/rule_action_guard (veto authority), council/1b_council_chair}` — guard's veto is absolute; the council can only *ratify* a permitted action, never override a guard block.
  - *Size/effort selection (which tier?)* → `{council/1b_council_chair, planner/1b_planner}` with the ram_manager consulted for headroom.
  - *BYOK frontier escalation* → `{council/1b_council_chair, auditor/1b_auditor (provenance gate), orchestrator/1b}` — and **only the user can confirm** the data leaves the device (opt-in). This is the single border crossing; logged.
- **Tie-break:** council_chair decides. Persistent tie (2+ rounds)? → escalate to `reasoner/8b_deep_reasoner` for a single advisory vote (chair still owns the decision).
- **"Tiny Cell is enough":** if a `100m` Cell returns `confidence ≥ 0.9`, **no council, no escalation** — proceed. The council is an exception path, not the common path. Common path = smallest Cell that clears threshold.

---

## Definition of done — per family

A family is **done-for-check-in** (not "forever") when, for every non-stub Cell in it:

1. **Template complete** — all 12 sections present (Job / Non-goals / Inputs-tools / Outputs-schema / Determinism / Stop-done / Failure-modes / RAM-latency / Council-escalate / Distilled-rules / Frontier-gaps / Eval-hooks).
2. **Strict output schema** in Outputs — no prose where a schema belongs.
3. **Stop/done conditions** explicit — incl. the `status=blocked` no-silent-early-stop contract.
4. **Failure modes + recoveries** named, and each recovery is a *smaller/to-the-orchestrator* move, never a silent bigger-model call.
5. **RAM/latency budget** matches the table above.
6. **Council escalation trigger** stated (the `confidence < 0.7` or ambiguity rule).
7. **≥5 distillation passes** have touched it (or saturation proven in PROGRESS).
8. **Frontier alignment done** — top-3 frontier refs named + gaps patched.
9. **Eval hooks** wired so punch-up is measurable for that family.

**Control-doc DoD:** each control doc fully specifies its contract and is referenced by the Cells that depend on it.

**Project DoD:** all 49 files exist; ≥5 full distillation passes complete (or saturation logged with evidence); frontier alignment on every non-stub Cell; the 4 runtime contracts (ram_manager, model_council, Cell_orchestrator, punch_up_tests) present and internally consistent; 3 model training specs (MODEL_SPEC, TRAINING_DATA_GUIDE, MODEL_QUALITY) define the path from prompts to trained models.

---

## Source corpus (Phase 2 distillation inputs — 307 files / 8.8MB / 18 vendors)

Highest-value prompt files (by size × job relevance). Full file-list lives in the repo at `SYSTEM PROMPT LEAKS/`.

- **Orchestration / agentic loop:** `Anthropic/claude-cowork.md` (280KB), `Anthropic/claude-cowork-dispatch.md` (71KB), `OpenAI/Codex/codex-full.md` (359KB), `Misc/devin-cli.md`, `Misc/amp-code.md`, `OpenCode/opencode.md`, `Google/gemini-cli.md`, `Microsoft/copilot-cli.md`, `Google/antigravity-cli.md`, `Misc/warp-2.0-agent.md`.
- **Browser / CDP / web agent (NEW browser family):** `Anthropic/claude-in-chrome.md` (74KB), `Perplexity/comet-browser-assistant.md` (25KB), `Perplexity/deep-research.md` (30KB), `OpenAI/Codex/control-chrome.md` (13KB), `Misc/fellou-browser.md` (22KB), `Anthropic/Claude Code/mcp-servers/computer-use.md`, `Google/jules.md`.
- **Coding (punch-up targets):** `OpenAI/Codex/*` (codex-full, gpt-5.x codex variants, codex-auto-review), `Cursor/cursor.md`, `Misc/zed.md`, `Mistral/mistral-code.md`, `Misc/amp-code.md`, `Anthropic/Claude Code/agents/*.md` (worker, general-purpose, workflow-subagent).
- **Reasoning / research:** `OpenAI/gpt-5.x-thinking.md`, `xAI/grok-4.5.md`, `Anthropic/research_instructions.md`, `DeepSeek/deepseek-chat.md`, `Perplexity/deep-research.md`, `Google/gemini-3.x-pro.md`, `Kimi/kimi-3.md`.
- **Safety / guardrails / provenance:** `xAI/grok-4-with-new-safety-instructions.md`, `xAI/grok-expert.md`, `Anthropic/old/claude-3.7-*-with-tools.md` (tool-safety), `OpenAI/Codex/codex-auto-review.md`.
- **Tool contracts / schemas / output discipline:** `Anthropic/raw/*` (raw prompts show exact tool-call discipline), `OpenAI/Codex/*`, all `*/claude-code-*` files, `Notion/notion-ai.md`, `Google/gemini-workspace.md`.
- **Council / ensemble / multi-model:** `Anthropic/claude-cowork-dispatch.md`, `Meta/muse-spark-1.1.md`, `Microsoft/copilot-cli.md`, `Misc/hermes.md`.
- **Foundation-model / on-device posture (for the Apple-FMF + local ethos):** `Apple`→(none in corpus; documented in-house), `Anthropic/claude-mobile-ios.md`, `Misc/zed.md`.

**Corpus is the distillation FUEL, not the destination.** We extract constraints, failure modes, tool contracts, output schemas, stop conditions, quality bars, anti-drift rules — then merge into our specialist Cells. We do NOT copy personas.

---

## Workflow status

See `00_PROGRESS.md` for live checkboxes. Phases: 0 (this index) → 1 (scaffold stubs) → 2 (≥5 distillation passes) → 3 (frontier alignment) → 4 (runtime contracts) → verify-DoD.
