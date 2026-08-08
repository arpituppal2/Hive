# AUGMENTATION_LOG — Per-Cell Frontier Gap Patches

> Canonical status: active
> Created: 2026-07-27
> Read this before: modifying any Cell prompt's frontier gap section, adding new distillation rules

## 0. Purpose

This document records every **frontier gap** found during Phase 3 alignment and the **patch applied** to close it. A gap is a capability, safety measure, output structure, or tool discipline that the top 3 frontier references enforce but the Cell was missing. Every patch is recorded with its source reference so future agents can trace provenance.

**Format:**
```
Cell: [name]
Date: [YYYY-MM-DD]
Frontier refs: [3 references used]
Gap: [what was missing]
Patch: [what was added]
Source: [which frontier ref provided the pattern]
```

---

## 1. Router Family

### 100m_intent_router

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | GPT-5.5 Instant, Claude 3.5 Haiku, Gemini 2.0 Flash | Missing confidence calibration for ambiguous intents | Added `confidence` float to output schema; required to output <0.5 for ambiguous | GPT-5.5 Instant confidence scoring |
| 2026-07-27 | GPT-5.5 Instant, Claude 3.5 Haiku, Gemini 2.0 Flash | No multi-intent detection | Added `multi_intent` route + `sub_intents` array with per-route confidence | Gemini 2.0 Flash multi-class routing |
| 2026-07-27 | Claude 3.5 Haiku | No out-of-vocabulary handling | Added `out_of_scope` route with confidence <0.3 — Cell must return `UNSURE` rather than best-guess | Claude Haiku uncertainty protocol |

### 100m_spam_detector

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude 3.5 Haiku, GPT-5.5 Instant, Perplexity Comet | No hard-coded kill-list domains for known spam sources | Added `PASS_THROUGH` list for legitimate domains that trigger spam patterns (newsletters, security alerts) | Perplexity Comet source trust |
| 2026-07-27 | GPT-5.5 Instant | No adversarial prompt-injection specific detection | Added `injection_score` metric separate from `spam_score` — injection detected by structural patterns not content | GPT-5.5 injection guardrails |

### 100m_urgency_detector

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Sonnet 4.6, GPT-5.1 Efficient | No deadline parsing from natural language | Added `deadline` extraction — parse "by EOD", "next week", "Friday", "in 3 hours" into absolute timestamps | Claude Sonnet temporal understanding |
| 2026-07-27 | Claude Sonnet 4.6 | No escalation rules for critical | Added mandatory `critical` → orchestrator notification path | Claude Cowork dispatch patterns |

### 1b_link_scorer

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | GPT-5.1 Efficient, Perplexity Comet, Brave Search | No recency boost | Added `recency_factor` — multiply score by decay weight based on content age | Brave Search recency ranking |
| 2026-07-27 | Perplexity Comet | No source diversity requirement | Added diversity bonus — penalize links from same domain in top-5 | Perplexity Comet diversity heuristic |

### 100m_retrieval_ranker

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Perplexity Comet, Brave Search, Stack Overflow AI | No cross-encoder re-ranking step | Added second-pass re-ranking for top-20 candidates using lightweight scorer | Perplexity Comet retrieval pipeline |
| 2026-07-27 | Stack Overflow AI | No tag/type-based boosting | Added source-type boost: `documentation > article > forum > social` | Stack Overflow answer ranking |

---

## 2. Browser Family

### 100m_dom_scout

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Code DOM agent, Playwright patterns, Perplexity Comet | No accessibility tree parsing | Added `aria_roles`, `alt_text`, `label` extraction to element schema | Claude Code accessibility-aware DOM |
| 2026-07-27 | Claude Code DOM agent | No shadow DOM handling | Added `shadow_root: bool` flag + fallback traversal strategy | Claude Code shadow DOM support |

### 1b_action_planner

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Code Opus 4.7, GPT-5.3 Codex, Gemini 3 Pro | No undo/rollback for destructive actions | Added `rollback` field to each action: `{"action": "delete", "rollback": "create_element_with_previous_content"}` | Claude Code action reversibility |
| 2026-07-27 | GPT-5.3 Codex | No confidence threshold for plan approval | Added `plan_confidence` — if <0.7, return to planner instead of executing | Codex staged execution |

### 8b_nav_reasoner

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | GPT-5.5 Thinking, Claude Code Opus 4.8 | No exploration-exploitation tradeoff | Added `exploration_strategy`: if first attempt fails, try alternative navigation path before declaring stuck | GPT-5.5 multi-path reasoning |
| 2026-07-27 | Claude Code Opus 4.8 | No session state carryover | Added session context: previously viewed pages, failed selectors, successful patterns | Claude Code session memory |

---

## 3. Coder Family

### 1b_coder

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Code Fable 5, GPT-5.5 Thinking, Codex | No project convention discovery | Added CONVENTION-READ: read `.claude.md`, `README.md`, `CONTRIBUTING.md` before editing | Fable 5 project awareness |
| 2026-07-27 | GPT-5.5 Thinking | No test-before-edit verification | Added VERIFY-FIRST: run existing tests before making changes to ensure baseline passes | Codex test-aware editing |
| 2026-07-27 | Claude Code Sonnet 4.6 | No diff-only output requirement | Added DIFF-ONLY: output only the diff, never the entire file; include context lines | Claude Code efficient editing |

### 8b_coder

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Code Opus 4.8, GPT-5.5 Pro, Gemini 3.1 Pro | No multi-file dependency graph awareness | Added `dep_graph` field: parse imports/dependencies across all open files before editing | Claude Code cross-file analysis |
| 2026-07-27 | GPT-5.5 Pro | No rollback capability | Added `git_rollback: bool` — if true, create git stash before edits, restore on failure | GPT-5.5 safe editing |

### 100m_sheet_specialist

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude for Excel, Notion AI, Gemini Data Analysis | No formula error detection | Added `formula_check`: validate formula syntax before generating, flag potential circular refs | Claude for Excel formula validation |
| 2026-07-27 | Notion AI databases | No data type inference for mixed columns | Added column type guesser: detect date/currency/percentage formats from sample data | Notion AI smart property detection |

### 100m_document_specialist

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude for Word, Notion AI, Gemini make-a-doc | No style guide enforcement | Added `style_guide_check`: read existing document styles before applying formatting | Claude for Word style consistency |
| 2026-07-27 | Gemini make-a-doc | No section cross-reference tracking | Added `cross_ref_validator`: verify all "see section X" references exist | Gemini document coherence |

### 100m_presentation_specialist

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude for PowerPoint, Claude Design make-a-deck, Claude Visualize | No typography system | Added design token system: font pairing (display + body + utility), type scale, weights | Claude Design frontend-design skill |
| 2026-07-27 | Claude Visualize | No chart data validation | Added `chart_check`: verify chart data accuracy, label matching, axis scaling | Claude Visualize data integrity |

---

## 4. Planner Family

### 1b_planner

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Cowork, GPT-5.1 Efficient, Gemini 2.0 Flash | No resource estimation | Added `estimated_tokens` and `estimated_cell_calls` per plan step | Claude Cowork effort estimation |
| 2026-07-27 | GPT-5.1 Efficient | No parallelizability annotation | Added `parallel_with`: field to mark steps that can run concurrently | GPT-5.1 efficient planning |

### 8b_planner

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Opus 4.7, GPT-5.5 Thinking, Gemini 3 Pro | No contingency planning | Added `fallback_plan` schema: if primary plan fails at step N, alternative approach | GPT-5.5 contingency reasoning |
| 2026-07-27 | Claude Opus 4.7 | No dependency graph recovery | Added `critical_path`: compute longest dependency chain, flag as risk | Claude Opus risk-aware planning |

---

## 5. Librarian Family

### 100m_librarian

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Gemini Search AI Mode, Perplexity AI, Brave Search | No query expansion | Added query rewrite: expand abbreviations, correct typos, add synonyms before search | Gemini Search AI query understanding |
| 2026-07-27 | Brave Search | No result snippet extraction | Added `snippet` field: extract 2-3 sentence summary from each result | Brave Search answer snippets |

### 1b_librarian

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Perplexity Comet, Notion AI, Kagi Assistant | No claim-to-source confidence scoring | Added `evidence_span` field: exact text range supporting each claim, with confidence | Notion AI source citation |
| 2026-07-27 | Kagi Assistant | No freshness-aware retrieval ordering | Added `stale_if_older_than`: deprecate sources beyond retention window, boost recent | Kagi freshness algorithm |

---

## 6. Auditor Family

### 1b_auditor

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | GPT-5.1 Efficient, Claude Sonnet 4.6, Grok 4.2 | No hallucination detection | Added `hallucination_score`: cross-check output claims against known sources; flag unsupported assertions | GPT-5.1 factuality checking |
| 2026-07-27 | Grok 4.2 | No contradiction detection between outputs | Added `contradiction_scan`: compare new output against existing Honeycomb claims | Grok truth-seeking patterns |

### 8b_auditor

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | GPT-5.5 Pro, Claude Opus 4.8, DeepSeek Chat | No security-specific audit patterns | Added `security_vulnerability` category: check for SQL injection, XSS, path traversal, auth bypass patterns | GPT-5.5 security audit |
| 2026-07-27 | DeepSeek Chat | No prompt injection in outputs | Added `injection_check`: verify generated output cannot be used to jailbreak downstream systems | DeepSeek output safety |

---

## 7. Summarizer Family

### 1b_compressor

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Sonnet 4.6, GPT-5.1 Efficient, Gemini 2.0 Flash | No action item preservation guarantee | Added `action_items: []` field that MUST be preserved verbatim from source — never summarized | Claude Sonnet action tracking |
| 2026-07-27 | Gemini 2.0 Flash | No structural preservation | Added `preserve_structure` flag: if true, maintain original heading hierarchy in compressed output | Gemini Flash structure awareness |

### 100m_title_generator

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Perplexity AI, Gemini Search AI Mode, NotebookLM | No multiple title candidates | Added output schema: generate 3 title candidates with scores | Perplexity title generation |
| 2026-07-27 | NotebookLM | No length constraint | Added strict length limits: `max_chars=80`, `max_words=12` | NotebookLM title conciseness |

### 1b_memory_compressor

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Rewisp patterns, Claude nightly, Notion AI consolidation | No importance scoring | Added `importance: 0.0-1.0` — facts with >0.9 are exempt from expiry | Rewisp importance model |
| 2026-07-27 | Notion AI | No episode merging | Added `merge_with` field: link related episodes from same topic across days | Notion AI topic consolidation |

---

## 8. Council Family

### 1b_council_chair

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Opus 4.7, GPT-5.5 Thinking, Gemini 3 Pro | No explicit reasoning trace | Added `reasoning_trace`: document each voter's position before making decision | Claude Opus transparent deliberation |
| 2026-07-27 | GPT-5.5 Thinking | No confidence-weighted voting | Added confidence weighting: votes from higher-confidence Cells count more | GPT-5.5 weighted consensus |

### 100m_observer

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Code observer, GPT-5.1 Efficient | No change detection | Added `state_diff`: before/after comparison of observed state, highlight changes | Claude Code observer delta reporting |

### 1b_teammate

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Code teammate, GPT-5.5 Instant, Gemini 3 Flash | No write-scope conflict detection | Added `conflict_scan`: check if another Cell is editing same file/scope — if so, queue or request merge | Claude Code multi-agent coordination |
| 2026-07-27 | Claude Code teammate | No progress reporting to coordinator | Added `progress_update` schema: periodic status reports without blocking execution | Claude Code worker agent patterns |

---

## 9. Reasoner & Research

### 8b_deep_reasoner

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | GPT-5.5 Thinking, Claude Opus 4.8, DeepSeek Chat | No explicit step verification | Added `verify_step(N)`: after each reasoning step, verify it's correct before proceeding | GPT-5.5 Thinking self-verification |
| 2026-07-27 | DeepSeek Chat | No uncertainty labeling per step | Added `confidence_per_step` array: label each reasoning step as certain/plausible/guess | DeepSeek honest reasoning |

### 8b_research_synthesizer

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Perplexity Deep Research, NotebookLM, Google AI Search Mode | No source disagreement labeling | Added `disagreement` field: flag when sources contradict each other, with percentage of sources holding each view | NotebookLM conflicting viewpoint handling |
| 2026-07-27 | Google AI Search Mode | No query plan | Added `query_chain`: the sequence of search queries used to discover sources, not just the final result set | Google AI Search Mode research process |

### 1b_research_gatherer (NEW — Pass 40, 2026-08-02)

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-08-02 | 12 leaked frontier prompts (Claude Opus 4.7/4.6/4.5, Sonnet 4.5, Haiku 4.5, GPT-5, GPT-4.5, Gemini 2.5 Pro, Grok 4, Perplexity, Kimi K2 ×2) | No Cell owned the search→fetch→evidence loop — synthesizer refuses to search, link_scorer never fetches, dom_scout only reads open tabs | New Cell: query-syntax bans + 1–6 word queries + distinct-query rule; call-count ladder (1/3–5/5–10); rate-of-change search gate; tool/answer phase split; 3-call budget; no-identical-requests; batched fetches; distribution-of-sources for controversy; 15-word quote cap; harmful-content exclusion; proceed-and-document | Claude 4.6 search instructions + Claude 4.7 search_first + Perplexity tool rules + Grok 4 browse/search policy + GPT-4.5 web triggers + Claude 4.6 copyright policy + Claude 4.7 harmful_content_safety |

---

## 10. Guard

### rule_action_guard

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | All frontier models + rule-based guard | Absolute veto needed | Added hard-coded denial patterns: `rm -rf /`, `sudo`, `chmod 777`, `curl | bash`, base64-encoded commands, eval of user-supplied strings | OpenAI prompt injection paper |
| 2026-07-27 | Apple App Sandbox | Outbound network must be denied by default | Added `network_deny` rule: all outbound connections blocked unless explicitly approved per-task | Apple sandbox security model |
| 2026-07-27 | Claude Code security model | Secret exfiltration patterns | Added regex patterns for API key, token, credential exfiltration attempts in tool arguments | Claude Code security |

---

## 11. Tutor, Voice, Conversation

### 100m_tutor_specialist

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Gemini Guided Learning, Gizmo AI, Claude Sonnet 4.6 | No student model | Added `student_state` input: current knowledge level, misconceptions, learning style | Gizmo AI student modeling |
| 2026-07-27 | Gemini Guided Learning | No scaffolding level | Added `scaffolding`: `direct | prompted | exploratory` — adjust based on student progress | Gemini Socratic method |

### 100m_voice_specialist

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Claude Voice Mode, Sesame AI Maya, ElevenLabs | No turn-taking markers | Added `turn_type`: `initiate | respond | interrupt | confirm | handoff` — controls when system speaks | Claude Voice conversation flow |
| 2026-07-27 | ElevenLabs | No prosody markup | Added `prosody` field: emotion, emphasis words, speaking rate adjustments | ElevenLabs voice generation |

### 8b_conversation

| Date | Frontier Refs | Gap | Patch | Source |
|------|---------------|-----|-------|--------|
| 2026-07-27 | Notion AI, Claude Voice Mode, Gemini 3 Pro webapp | No human handoff mechanism | Added `human_handoff` delegate target: when no Cell can handle, ask orchestrator to get user input directly | ChatGPT Agent Mode fallback |
| 2026-07-27 | GPT-5.5 Thinking | No reasoning transparency | Added optional `thinking` field: brief internal reasoning visible to UI for optional display | GPT-5.5 Thinking visible reasoning |
| 2026-07-27 | Claude Cowork | No context summarization before pruning | Added pre-prune summary: "Let me recap what we've covered so far..." before truncating old conversation history | Claude Cowork conversation management |

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total frontier refs consulted | 44 unique models/services |
| Total gaps identified | 53 |
| Total patches applied | 53 |
| Cells with 2+ patches | 23 |
| Cells with 0 patches (all gaps closed in initial prompt) | 0 |
| Most common gap type | Missing output schema field (28 patches) |
| Most common source for patch pattern | GPT-5.5 Thinking / Pro (12 patches) |
| Safety-critical patches | 7 (guard, auditor-8b, conversation) |

*2026-08-02: Pass 40 added `researcher/1b_research_gatherer` (53rd patch, 12 leaked-frontier refs). Frontier ref count raised 32 → 44 to include the leaked-prompt sources.*
