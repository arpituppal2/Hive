# EXECUTION_PLAN — Hive/Swarm: From Prompts to Product

> **Canonical status:** active
> **Created:** 2026-07-27
> **Purpose:** Bridges all 44 system prompt files into a single actionable timeline with phases, milestones, costs, and decision gates.
> **Dependencies:** MODEL_SPEC.md, TRAINING_DATA_GUIDE.md, MODEL_QUALITY.md, seed_intent_plan.md, competitive-dossier.md, AGENTS.md

## 0. The Strategic Thread

**Hive wins by being:**
1. A **credible daily browser** first (P0 — entry wedge)
2. A **memory layer** that accumulates context silently (P1 — compounding advantage)
3. A **research + action layer** that uses that memory (P2 — switching cost)
4. A **desktop intelligence layer** that replaces 10+ apps (P3+ — full platform)
5. **Local-first, privacy-first** throughout (the permanent moat)

Every phase below flows from this thread. Nothing is built before its prerequisite.

---

## Phase P0: Browser Credibility + Build Recovery (Weeks 1-4)

### Goal
Ship a browser that people can use daily BEFORE any AI features are needed.

### Prerequisites
- [x] System prompts defined (32 specialist Cells)
- [x] Training pipeline specified (MODEL_SPEC, TRAINING_DATA_GUIDE, MODEL_QUALITY)
- [ ] Swift build green (BUILD-001, BUILD-002 in AGENTS.md)
- [ ] Core browser navigation working (tabs, back/forward, session restore)
- [ ] Browser import working (Chrome, Safari, Firefox, Arc, Brave, Edge)

### Key Deliverables

| Milestone | Week | Description | References |
|-----------|------|-------------|------------|
| Build green | 1 | Resolve BUILD-001, BUILD-002. swift build + swift test pass. | AGENTS.md §6.2 |
| Core navigation | 2 | Tabs, back/forward, reload, find-in-page, private mode, download lifecycle | SPEC.md |
| Browser import | 2 | Import profiles from Chrome, Safari, Firefox, Brave, Edge, Arc | ImportManager.swift |
| Session restore | 3 | Restart preserves open tabs, scroll position, form state | BrowserTab.swift |
| Layout modes | 3 | Top, vertical, bottom tab layouts — all keyboard accessible | TopChromeView.swift |
| Content blocking | 3 | Ad/tracker blocking with visible privacy report | TrackerBlocker.swift |
| Reader mode | 4 | Article extraction, font customization, dark mode | ReaderModeView.swift |
| Tab hibernation | 4 | Auto-hibernate idle tabs, exclude audio/pinned | TabHibernationEngine.swift |
| **Gate: 100 daily active users** | 4 | Ship to internal testers. Must get 100 DAU before P1 spend. | — |

### Budget
| Item | Cost | 
|------|------|
| Developer time (4 weeks) | Fully internal |
| Test devices (M1 MacBook, M4 MacBook) | Already owned |
| **Total P0** | **$0** (existing infra) |

### Decision Gates
- **Gate 1 (end of Week 4):** 100 DAU in internal testing? If no → extend P0. If yes → proceed to P1.
- **Kill criterion:** If browser import is unreliably partial (<70% coverage for any target browser) → simplify import scope to Chrome + Safari only.

---

## Phase P1: Memory + Real Swarm (Weeks 5-10)

### Goal
Honeycomb knowledge graph working. Swarm can answer cited questions from memory.

### Prerequisites
- [x] seed_intent_plan.md defines 3,200 seed intents
- [x] TRAINING_DATA_GUIDE defines data generation pipeline
- [ ] Router Cell training data generated (Phase 1-2)
- [ ] Honeycomb SQLite schema designed and implemented
- [ ] Page capture working (manual + auto)

### Key Deliverables

| Milestone | Week | Description | References |
|-----------|------|-------------|------------|
| Router data gen | 5 | Generate 5K training pairs for 5 router Cells | seed_intent_plan §1, TRAINING_DATA_GUIDE §2.1 |
| Router model train | 6 | Train 100M intent/spam/urgency via distillation | MODEL_SPEC §3 (100M hyperparams) |
| Honeycomb schema | 5 | SQLite nodes/edges, FTS5, typed relations, migration system | AGENTS.md §8.3 |
| Page capture | 6 | Manual capture + auto-extract on page interaction | BrowserTab.capturePage |
| Librarian data gen | 7 | Generate 5K training pairs for 2 librarian Cells | seed_intent_plan §5 |
| Librarian model train | 8 | Train 100M + 1B librarian via distillation | MODEL_SPEC §3 |
| Claim extraction | 8 | Librarian extracts claims → Honeycomb graph | librarian/1b_librarian.md |
| Research data gen | 9 | Generate 5K training pairs for research_synthesizer | seed_intent_plan §9.2 |
| Research model train | 10 | Train 8B research_synthesizer via distillation | MODEL_SPEC §3 (8B MoE) |
| Swarm cited answers | 10 | User asks → retrieves from Honeycomb → cites sources | researcher/8b_research_synthesizer.md |
| **Gate: Cited answer accuracy** | 10 | ≥85% of answers have correctly resolved sources. | MODEL_QUALITY.md |

### Budget
| Item | Cost |
|------|------|
| Teacher API calls (Phase 1-2, 10 Cells) | ~$15K |
| A100 compute (train 5 × 100M + 2 × 1B + 1 × 8B) | ~$25K |
| Developer time (6 weeks) | Internal |
| **Total P1** | **~$40K** |

### Decision Gates
- **Gate 2 (end of Week 10):** Swarm answers from memory with ≥85% citation accuracy? If no → improve retrieval pipeline. If yes → proceed to P2.
- **Kill criterion:** If router Cells don't match punch-up targets (100M beats Qwen2.5-7B on routing accuracy) → revert to rule-based routing and re-scope.

---

## Phase P2: Studio + Project Workflows (Weeks 11-16)

### Goal
Hive Studio (code editor), project spaces, task management. The "act" layer.

### Prerequisites
- [ ] Honeycomb memory has ≥10K captured pages from P1 testing
- [ ] Swarm research pipeline is reliable
- [ ] Coder Cell training data generated
- [ ] Planner Cell training data generated

### Key Deliverables

| Milestone | Week | Description | References |
|-----------|------|-------------|------------|
| Coder data gen | 11 | Generate 5K pairs for 1B coder, 5K for 8B coder | seed_intent_plan §3 |
| Coder model train | 12 | Train coder Cells via distillation | MODEL_SPEC §3 |
| Project spaces | 11 | Honeycomb-backed project views with pinned context | AGENTS.md §7.2 |
| Studio: project select | 12 | User selects project root → scope set | STUDIO-001 |
| Studio: plan/diff loop | 13 | Planner → coder → diff preview → approval flow | STUDIO-002 |
| Studio: test runner | 14 | Run user-approved tests in sandboxed environment | HiveCore/Code/CodeRunner.swift |
| Task inbox | 14 | Capture actions as tasks, surface via Honeycomb | AGENTS.md §7.7 |
| Daily brief | 15 | Nightly consolidation → daily brief with open loops | summarizer/1b_memory_compressor.md |
| Command center | 16 | Global search, typed commands, keyboard shortcuts | CMD-001 |
| **Gate: Studio usability** | 16 | Can make a real code change → review diff → run tests → confirm | — |

### Budget
| Item | Cost |
|------|------|
| Teacher API calls (Phase 1-3, 8 more Cells) | ~$15K |
| A100 compute (train 2 × 1B + 1 × 8B coder + 2 × planner) | ~$30K |
| Developer time (6 weeks) | Internal |
| **Total P2** | **~$45K** |

### Decision Gates
- **Gate 3 (end of Week 16):** YC demo works end-to-end (browse → capture → research → act)? If no → fix weak link. If yes → proceed to P3 + prepare YC application.
- **Kill criterion:** If 8B coder cannot match Claude Haiku on single-file coding tasks → drop Studio to "research only" and rebuild coder pipeline.

---

## Phase P3: Desktop Intelligence + YC Demo (Weeks 17-22)

### Goal
Ship the full YC demo. Add personal-computer capabilities. Launch to public.

### Prerequisites
- [ ] P0-P2 milestones all met
- [ ] YC application window open (early 2027?)
- [ ] Privacy architecture audited

### Key Deliverables

| Milestone | Week | Description | References |
|-----------|------|-------------|------------|
| YC demo video | 17 | 3-min demo: browse → capture → research → Studio edit → test | AGENTS.md §2.3 |
| YC application | 17 | Submit with demo video + competitive analysis | competitive-dossier.md |
| Worker helper | 18 | Signed helper process for OS-level actions | PC-001 |
| Permission center | 18 | UI for Accessibility, Screen Recording, Files grants | PC-001 |
| Desktop observe | 19 | Screen/window observation, approved file actions | PC-002/003 |
| Hive Sheets v1 | 20 | Table with typed columns, formulas, CSV import | SHEET-001/002 |
| Focus sessions | 20 | Bounded keep-awake, task-linked notifications | WELL-001 |
| Wellness breaks | 21 | Gentle break reminders with smart pause | WELL-002 |
| Public launch | 22 | Ship on Developer ID (not App Store — more capability) | DIST-001 |
| **Gate: Product-market fit** | 22 | 1K DAU, <5% churn, organic growth signals? | — |

### Budget
| Item | Cost |
|------|------|
| Teacher API calls (remaining Cells) | ~$10K |
| A100 compute (all remaining Cells) | ~$15K |
| Developer time (6 weeks) | Internal |
| Signing + notarization | $100/yr |
| **Total P3** | **~$25K** |

### Decision Gates
- **Gate 4 (end of Week 22):** 1K DAU with <5% weekly churn? If no → iterate on P0/P1 features (the wedge). If yes → proceed to P4.
- **Kill criterion:** If churn >20% after launch → analyze drop-off point → pivot to fix that specific gap. Do not add new features until churn is fixed.

---

## Phase P4: Platform Growth (Months 6-12)

### Goal
Grow from 1K to 100K users. Build marketplace. Expand capabilities.

### Prerequisites
- [ ] P0-P3 milestones met with retention data
- [ ] >1K DAU with <5% churn
- [ ] Positive user feedback on core loop

### Key Deliverables

| Milestone | Timeline | Description | References |
|-----------|----------|-------------|------------|
| Mod marketplace | Month 6 | Community-driven extension system (like Zen Mods + Raycast) | competitive-dossier §1.2 |
| Plugin API | Month 7 | Sandboxed JS plug-in system with permission model | ENG-001 |
| Connectors | Month 7-8 | Calendar, email, file system, dev tools connectors | CONN-001 |
| Collaboration | Month 9 | Shared projects, published briefs, team spaces | AGENTS.md §7.2 |
| Advance Sheets | Month 9-10 | Charts, pivot tables, agent-assisted analysis | SHEET-001 |
| Mobile companion | Month 10-11 | iOS companion app (capture + quick search) | — |
| Enterprise features | Month 11-12 | SSO, audit logging, team management, compliance | — |
| Signing (Mac App Store) | Month 12 | Optional MAS build for consumer distribution | DIST-001 |

### Growth Strategy (from competitive-dossier §9)

| Channel | Expected Impact | Investment |
|---------|----------------|------------|
| **Arc diaspora** | Target Arc users post-pivot — they need a new browser | Content marketing: "Hive is what Arc should have been" |
| **Privacy converts** | Brave/LibreWolf users open to better UX | Privacy-first messaging, open-source transparency |
| **Developer word-of-mouth** | Hive Studio differentiator | Open-source repo, developer blog |
| **Productivity YouTubers** | Visual voyeurism drives downloads | Demo videos featuring Honeycomb memory magic |
| **Obsidian/Notion refugees** | Knowledge management converts | \"Your browser is now your second brain\" narrative |

---

## Total Project Budget

| Phase | Data Generation | Compute | Timeline | Team Size |
|-------|----------------|---------|----------|-----------|
| P0: Browser | $0 | $0 | 4 weeks | 2-3 engineers |
| P1: Memory | $15K | $25K | 6 weeks | 2-3 engineers |
| P2: Studio | $15K | $30K | 6 weeks | 2-3 engineers |
| P3: Desktop | $10K | $15K | 6 weeks | 2-3 engineers |
| P4: Growth | TBD | TBD | 6 months | 3-5 engineers |
| **Total (P0-P3)** | **$40K** | **$70K** | **22 weeks** | **2-3 engineers** |
| **Grand Total** | **~$110K** | **22 weeks to public launch** | | |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **On-device model quality insufficient** | Medium | High | Start with mock/simulated Cells (provider is "mock"), upgrade to real models when ready |
| **Browser import unreliable** | Low | Critical | Pivot to clean-profile onboarding. Can't ship a browser that corrupts imported data. |
| **Prompt injection bypasses guard** | Medium | Critical | Guard is rule-based (no model). Run adversarial fixture suite before every release. |
| **Honeycomb graph becomes unmanageable** | Medium | Medium | Bounded retention (6-month ceiling per Rewisp). Importance-based pruning before it grows unbounded. |
| **YC window missed** | Low | Medium | Self-fund through P0-P2. Apply to next batch. Revenue from premium features (BYOK, Studio, Teams). |
| **Apple rejects Developer ID build** | Low | High | Keep App Store sandboxed build as fallback. Limited feature set but acceptable for consumer launch. |
| **User discovers memory feature creepy** | Medium | Medium | Privacy-first positioning from day 1. Kill list, local-only, opt-in memory sharing. Rewisp proves this model works. |

---

## Success Metrics by Phase

| Phase | North Star | Supporting Metrics |
|-------|------------|-------------------|
| P0 | 100 DAU (internal) | Import success rate, session restore reliability, crash-free rate |
| P1 | Citation accuracy ≥85% | Capture count per user, query → answer latency, memory retention rate |
| P2 | Studio: complete a real edit | Task completion rate, diff acceptance rate, test pass rate |
| P3 | 1K DAU, <5% churn | Demo-to-download conversion, DAU/WAU ratio, NPS |
| P4 | 100K DAU | Organic growth rate, marketplace installs, connector adoption |

---

## Cross-Reference Index

| Document | Key Sections for Execution |
|----------|--------------------------|
| AGENTS.md | §2.3 (YC demo spine), §12 (phased roadmap), §14 (audit protocol) |
| MODEL_SPEC.md | §2 (distillation pipeline), §3 (hyperparameters), §6 (deployment) |
| TRAINING_DATA_GUIDE.md | §2 (per-Cell data strategy), §5 (cost budget), §6 (checklist) |
| MODEL_QUALITY.md | §0 (eval matrix), punch-up targets per Cell |
| seed_intent_plan.md | §1-9 (per-Cell seeds), §10 (priority order), Appendix (schemas) |
| competitive-dossier.md | §9 (conversion strategy), §74 (browser feature matrix), §77 (Apple moat) |
| hard-link-smart-ask.md | Conversion funnel, demo scripts, competitive pitch |
