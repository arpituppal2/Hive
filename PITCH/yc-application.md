# Hive — YC Application Draft (2026–2027 cycle)

> **Canonical status:** active draft
> **Created:** 2026-08-11
> **Sources:** AGENTS.md (canonical product), `docs/superpowers/specs/2026-08-11-hive-memory-megaphase-design.md`, `RESEARCH/competitive-megadossier.md` (243 apps), `RESEARCH/conversion-playbook.md`, `2026-08-11-yc-demo-execution.md`
> **Market research:** AI-browser war (OpenAI Atlas, Perplexity Comet, Dia/Atlassian, Gemini-in-Chrome), DMA choice screens (Firefox +99–111% EU DAU), Manifest V3 fallout, 2026 local-AI hardware (M4/M5, MLX tool-calling)

## 0. The application in one breath

> **The Hive Browser turns what you browse into an organized, actionable memory.**
>
> It is a native macOS browser where every page you capture becomes a searchable, citable source; where Swarm — a local, role-specialized AI — answers with citations to what you actually opened, turns research into projects with next actions, and makes one safe, approved code change. It replaces the browser, the read-later app, the knowledge base, the research tool, and the coding assistant — with one local-first memory your data never leaves.

## 1. The narrow description (the first 10 seconds)

Two sentences, no jargon, no "AI browser" claim:

> **"The Hive Browser is a browser that remembers what you read and acts on it. Ask it anything about your research — it answers with citations to the pages you actually opened, then turns that into projects, tasks, and one safe code change."**

Why this framing (research-verified): YC explicitly advises a narrow, clear description over a broad vision (AGENTS.md §2.2). The AI-browser field is crowded with *ambition* (Atlas, Comet, Dia, Gemini-in-Chrome); the winning slot is *proof* — one unforgettable compound workflow.

## 2. Application answers (draft)

### What does your company do? (2 sentences)
"The Hive Browser is a native macOS browser with an integrated memory and AI layer (Swarm). Every page you capture becomes a citable source; Swarm answers with real citations, builds projects and next actions from your research, and performs one safe, approved, auditable code change — all local-first, with your data never leaving your Mac."

### What is the problem?
"People lose work at every context boundary: browser to notes, notes to research, research to tasks, tasks to code. The average knowledge worker pays ~$1,500/yr across a browser, read-later app, knowledge base, research tool, AI chat, and task app — and none of them talk to each other, and none of them saw the tabs, emails, or research that made the work real."

### What is your solution?
"One browser that owns the context. Capture is one-click and DOM-level (no screen-recording permission). Retrieval is hybrid (full-text + semantic + recency) over a local knowledge graph. Answers cite stored Source objects, never generated labels. Projects, tasks, and code runs are typed objects in the same graph. Everything is local-first, reversible, and exportable."

### Who are your competitors? (the war map)
| Competitor | Bet | Weakness Hive exploits |
|---|---|---|
| **OpenAI Atlas** (2025) | Cloud ChatGPT everywhere; Browser Memories in the cloud | Cloud-memory privacy; $20–200/mo paywall; macOS-first fragmentation |
| **Perplexity Comet** (2025) | Search-agent wrapper; went free Oct 2025 | **CometJacking** (prompt injection via webpages); invasive screen permissions; scraping lawsuits |
| **Dia (The Browser Company)** (2025) | Enterprise productivity via Atlassian ($610M acquisition) | Abandoned Arc's consumer base; cloud-tethered |
| **Gemini-in-Chrome** | Retrofit Chrome with Gemini; Personal Intelligence from Gmail/Photos | Antitrust scrutiny; forced cloud data sharing |
| **Readwise/Rewisp/Obsidian** | Standalone memory/knowledge tools | Context-blind: they never saw the tabs |
| **Hive** | **Local-first memory as the browser itself** | Honest labels, DOM-level capture, cited answers, no subscription tax, one app |

### Why now?
1. **The AI-browser war legitimized the category** (2025–2026: Atlas, Comet, Dia, Gemini-in-Chrome) — but every entrant bet on **cloud memory**. Local-first is the unclaimed white space, and the privacy counter-story is already validated by Brave's growth (100M+ MAU, $100M+ revenue) and the Manifest V3 exodus (uBlock crippled → users seeking alternatives).
2. **Hardware crossed the line** (2026): M4/M5 neural accelerators, MLX with native tool-calling and OpenAI-compatible servers; 16GB Macs run 9–12B models; the M1 8GB floor runs the full Cell roster (100M–8B) via cohort sharing. Local-first AI is now a *performance* story, not just a privacy story.
3. **DMA choice screens** gave independent browsers real distribution (Firefox +99–111% EU DAU; alternatives +30–250% downloads). New browsers are now *installed*.
4. **Orphan cohort**: Pocket, Omnivore, Arc (frozen after the $610M Atlassian acquisition), and others died or stalled 2024–2025 — millions of users actively looking for a permanent home.
5. **Feature convergence emptied the category**: vertical tabs, tab groups, AI assistants, and password managers are now free in every browser. A new browser cannot win on chrome — the only unclaimed differentiator is *memory that acts*.

### How will you get users? (conversion in brief)
**Research verdict: import friction is THE switching barrier — the entire browser-switch decision dies in the first hour at the password wall, a broken site, or a muscle-memory clash.** So conversion starts with perfect import: one-click, universal, lossless migration (7 browsers + refugee importers for Pocket/Omnivore/Roam — the orphan cohort is actively looking for a permanent home right now). Then the first-question moment ("what was I reading about X?") which Chrome cannot answer, then the digest (daily return loop), then projects (stickiness), then studio (revenue surface). Eight segment funnels + refugee-response playbook in `RESEARCH/conversion-playbook.md`.

### How do you make money?
**The market already answered this question: users will not pay for a browser as a browser.** Arc's $30/mo Arc Max attempt collapsed — consumers treat the browser as OS-level infrastructure, and paywalled AI sidebars are commodity (Chrome/Safari/Edge/Firefox all ship AI wrappers free by 2026; vertical tabs, tab groups, and password managers fully converged). The differentiator can no longer be chrome features — it's memory. So: local-first core **free forever** (browser + memory + local AI). Paid tier gates the **service layer**: multi-device encrypted sync, encrypted backup, team collaboration, and advanced/BYOK model routing — the Obsidian model, research-validated. Anchor pricing against the ~$1,500/yr stack (the Setapp lesson: bundle beats per-tool resistance). Privacy is in the pricing copy (~20% WTP lift, Amex-cliff-respecting).

### What do you know that others don't?
"Memory apps fail because they capture at the OS level (OCR — lossy, permission-heavy, scary) or stand alone (context-blind). The browser is the only surface with DOM-level structure, origin-scoped privacy, and the full context of the user's work — so browser-native memory is strictly better than both Rewisp-style OCR capture and Readwise-style standalone reading. And every AI-browser competitor chose cloud memory, which is exactly the trust problem users just lived through with ChatGPT's Feb 2025 memory implosion."

### What are the 3 biggest risks?
1. **Browser credibility** — users won't trust memory from a browser that can't survive daily-driver use. Mitigation: P0 browser quality bar (AGENTS.md §10.1), C1–C4 polish, demo gate.
2. **AI-browser convergence** — Google/OpenAI could ship local-first memory. Mitigation: Cells (size×role efficiency) + the memory substrate are hard to bolt onto Chrome; and regulation constrains Google's advantage.
3. **Team/build scope** — one app that replaces many is a scope monster. Mitigation: progressive disclosure (browse → remember → ask → organize → act), demo-first proof, phased roadmap.

### The critical flaw we name ourselves
**The browser must be genuinely excellent before the memory is worth trusting — and a browser is the hardest thing a small team can build.** That's why the roadmap leads with the browser-credibility bar (P0 acceptance in AGENTS.md §10.1), why the demo films on the M1 8GB floor (the promise is the floor), and why every quarter ships a credibility item before a memory item. We are not claiming to out-engineer Google's rendering stack; we are claiming to out-own the *context* — DOM-level capture, origin-scoped privacy, and a local graph that no search giant can bolt onto Chrome without the same antitrust gravity that already constrains it.

## 3. Demo beat sheet (the 3-minute proof)

Per `2026-08-11-yc-demo-execution.md` — one compound workflow, no feature tour:

1. Import a real profile → a project space opens (0:00)
2. Research a decision across tabs (0:25)
3. Sources captured in one click, provenance visible (0:50)
4. "Write a cited brief on what I just read" — every claim cites a stored Source (1:15)
5. One key: brief → project with decisions, questions, next actions (1:45)
6. Open a repo; Swarm plans, shows the diff, user approves, test runs, EventLedger records (2:15)
7. Back in the browser — project shows the run attached; nothing lost (2:50)

**No fake theater**: every citation resolves; every model label is honest; every action was approved (AGENTS.md §4.8).

## 4. Why us / the team

- **Vision:** one browser-native workspace that replaces the browser, knowledge, research, coding, task, and desktop-utility stack — "your second brain is the browser, and it acts."
- **Builder:** this repository is the proof — 167 app files, 1,881 tests, built app, a Swarm spec library, and a 243-app competitive dossier. The product is not a mockup; the demo is scripted against verified code.
- **The Hive/Swarm split:** Hive is the ever-evolving browser; Swarm is its intelligence, like Google inside Chrome — but local, honest, and permissioned.

## 5. The ask

We are building the browser that remembers and acts. We need the YC network for distribution, hiring, and the discipline of the 12-week demo deadline. Demo video: 3 minutes, the compound workflow above, recorded on an M1 8GB Mac — because the floor is the promise.
