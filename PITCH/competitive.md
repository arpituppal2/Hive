# Competitive Landscape

> Hive/Swarm is not one category challenger. It is a workflow-consolidation challenger.
>
> Wedge audience: people who already rejected default browsers because they care how they work.
> Expansion audience: people whose day is split between browser tabs, notes, docs, and coding agents.
> Mainstream pull: people who stay on Chrome or Safari until something is so obviously better that switching feels rational.
>
> The thesis: browsers know what you're looking at, knowledge tools know what you care about,
> coding agents know how to act — and nobody has fused those three into one local-first Apple-native system.
>
> Filled incrementally across M0–M13. Key question: what does each competitor nail, where is each
> weak, and what's the specific consolidation Hive/Swarm owns in that category?

---

## 1. Browsing Shell

The surface where users spend their time. Competitors here are the niche browsers our wedge audience
has already adopted — people who rejected Chrome/Safari because they care how they work.

### Arc
- **Nails:** Vertical tabs, spaces/workspaces, split-view, command bar, design-forward chrome
- **Weak:** No memory extraction, no knowledge persistence, no agentic tools, no code execution
- **Hive/Swarm wedge:** Arc's spatial tab model + automatic memory extraction + Swarm acting on that
  memory. Arc shows you tabs; Hive remembers what's in them and acts on it.

### Zen
- **Nails:** Firefox-based, vertical tabs, compact layout, privacy stance
- **Weak:** Early-stage, small feature surface, no memory/agent story
- **Hive/Swarm wedge:** Zen's compact density + persistent knowledge + execution. Migration path for
  Firefox power users who want vertical tabs and don't want to give up privacy.

### Vivaldi
- **Nails:** Extreme customization, tab stacking, built-in notes/mail/calendar, power-user density
- **Weak:** Chromium bloat, inconsistent UX, no AI/memory integration
- **Hive/Swarm wedge:** Vivaldi's power-user density + Apple-native performance + unified memory.
  Vivaldi gives you controls; Hive gives you controls that feed into a knowledge system.

### Safari / Orion
- **Nails:** Apple-native performance, battery life, iCloud integration, minimal chrome
- **Weak:** Limited extension ecosystem (Safari), no workspace model, no memory/agent tools
- **Hive/Swarm wedge:** Safari-level native feel + workspace model + memory + execution. For
  Safari/Orion users, Hive is the upgrade path that keeps the Apple-native sensibility.

### Chrome / Edge
- **Nails:** Ubiquity, extension ecosystem, profile switching, dev tools
- **Weak:** Privacy concerns, no workspace model, no knowledge layer, Google telemetry
- **Hive/Swarm wedge:** Chrome-level keyboard parity + local-first memory + no telemetry. For
  Chrome/Edge users, Hive is the switch that adds a knowledge layer without removing what they
  know. (Tier 3 — won't win these users first.)

---

## 2. Knowledge Store

Where captured information lives and compounds. Competitors here are tools users currently run
alongside their browser — Obsidian, Notion, Apple Notes, Logseq. Hive embeds the knowledge store
directly into the browser.

### Obsidian
- **Nails:** Local-first markdown, bidirectional links, graph view, plugin ecosystem, offline
- **Weak:** No browser integration (capture requires plugins or copy-paste), no AI (without plugins),
  no agentic tools, no code execution
- **Hive/Swarm wedge:** Obsidian-class wiki (git-backed markdown, bidir links, CloudKit sync) that
  auto-populates from browsing. No plugins needed. Swarm queries, summarizes, and links across the
  knowledge base. Obsidian is a knowledge tool you feed manually; Hive feeds itself.

### Notion
- **Nails:** Flexible database+page model, team collaboration, templates, block-based editing
- **Weak:** Cloud-only (no offline), slow, no browser integration, AI is bolted-on and expensive
- **Hive/Swarm wedge:** Local-first + CloudKit sync = offline + private. Memory auto-populates from
  browsing. Notion is a canvas you build; Hive builds the canvas from what you browse.

### Apple Notes / Freeform
- **Nails:** Native, fast, iCloud sync, Apple Pencil support
- **Weak:** No knowledge graph, no bidirectional links, minimal organization primitives
- **Hive/Swarm wedge:** Same native feel + graph structure + auto-capture. Notes is a scratchpad;
  Hive's memory is a structured knowledge base.

---

## 3. Coding + Action

Where intent becomes execution. Competitors here are the AI coding agents and computer-use tools
that users currently run in separate windows. Swarm embeds this into the same workspace.

### Cursor / Codex CLI / Claude Code
- **Nails:** Multi-file code edits, terminal integration, run/observe loop, diff-based review
- **Weak:** Code-only context; no browser integration, no persistent memory, no research/wiki
- **Hive/Swarm wedge:** Same code-agent depth + triggered directly from browsing context. Read a
  docs page → Swarm implements the pattern. Research a bug → Swarm writes the fix. No copy-paste
  between browser and terminal.

### Cowork (Anthropic)
- **Nails:** Computer-use agent, Accessibility-based screen reading, AppleScript automation,
  human-in-the-loop confirm for every destructive action
- **Weak:** No browser integration, no knowledge wiki, no memory persistence across sessions
- **Hive/Swarm wedge:** Swarm matches Cowork's agentic loop + adds persistent memory wiki +
  cross-app browser orchestration. Cowork acts on your screen; Swarm acts on your memory.

### GitHub Copilot
- **Nails:** In-editor completion, chat, agent mode, VS Code integration
- **Weak:** Editor-locked, no browser context, no knowledge layer, no local model option
- **Hive/Swarm wedge:** Copilot helps you write code in an editor. Swarm helps you go from
  browsing docs → understanding APIs → writing code → running tests — all in one flow.

---

## 4. Research + Q&A

Where questions get answered with provenance. Competitors here are AI search and research tools.
Swarm adds persistent context carryover — research doesn't evaporate when the tab closes.

### Perplexity
- **Nails:** Cited research, real-time web search with provenance, Deep Research mode
- **Weak:** Research-only; no memory persistence, no code/terminal, no OS control, no browser
- **Hive/Swarm wedge:** Swarm research matches Perplexity citations + persistent memory wiki +
  cross-session provenance. Perplexity answers a question; Swarm answers a question and files it
  in your knowledge base with bidirectional links.

### NotebookLM
- **Nails:** Source-grounded synthesis, document upload, audio overviews
- **Weak:** Upload-only context (no live browsing), no agent tools, Google-locked
- **Hive/Swarm wedge:** Same source-grounded approach + live browsing context + local-first.
  NotebookLM grounds in documents you upload; Swarm grounds in everything you've ever browsed.

### ChatGPT / Claude (chat)
- **Nails:** General chat, broad knowledge, brand ubiquity
- **Weak:** No real memory (conversation-scoped), no OS control, no browser, no code execution
- **Hive/Swarm wedge:** Persistent git-backed memory wiki survives conversations. Tool-plane
  executes, not just chats. BYOK lets users bring frontier models into Swarm's execution surface.

---

## 5. Personal System

The manual glue users apply between all of the above. This is the biggest unclaimed territory.

### The Copy-Paste Workflow (status quo)
- **What it looks like:** Read in browser → copy to Obsidian → ask Perplexity → paste answer →
  open Cursor → write code → run in terminal → document in Notion
- **Cost:** Context loss, attention fragmentation, re-finding things, manual provenance
- **Hive/Swarm wedge:** Zero handoffs. One memory. One surface. Browse, capture, ask, act — all
  in the same system with the same context.

No single product currently competes across all five categories. That's the consolidation play.

---

## The Unclaimed Wedge

**No single app combines: browser with auto-extract memory + persistent knowledge wiki + cited
research + code/terminal agent + computer-use agent + cross-app orchestration — all local-first
by default with a free on-device model and a BYOK frontier ceiling.**

Competitors are point solutions in individual categories. Hive/Swarm is the integration play:
browsing, knowledge, and execution share one memory, one dispatcher, one surface. The user
switches between reading (Hive) and thinking/doing (Swarm) without losing context, without
copy-paste, and without stitching five apps together.
