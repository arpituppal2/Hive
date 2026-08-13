# Conversion Playbook — Turning Users of Every Replaced App Into Hive Users

> **Canonical status:** active
> **Created:** 2026-08-11
> **Companion to:** `competitive-megadossier.md` (the 243-app universe), `2026-08-11-yc-demo-execution.md` (the demo spine)
> **Grounded in:** 2024–2026 switching-behavior research — PKM abandonment causes, the Omnivore/Pocket refugee wave, AI-assistant switching + the ChatGPT memory controversy, productivity WTP psychology, Setapp/Raycast bundling evidence, browser-switching sentiment

## 0. The Conversion Thesis

**People don't switch for features; they switch at moments of pain, price, or panic.** Every app closure, price hike, breach, and feature regression is a **migration event** — a moment when users are actively looking for a new home. Hive's conversion strategy is to be the *permanent home* at every one of those moments, and to make the switch itself the first demonstration of the product (the import IS the demo).

The three universal switching triggers (research-verified):
1. **Pain** — triage fatigue, tab chaos, sync failure, feature bloat (the everyday trigger)
2. **Price** — subscription creep, surprise hikes, paywall walls (the predictable trigger)
3. **Panic** — shutdown, breach, acqui-hire, data-loss threat (the urgent trigger)

## 1. The Refugee Cohorts (migration events, past + ongoing)

| Cohort | Event | Emotional state | What they need | Hive's play |
|---|---|---|---|---|
| **Pocket refugees** | Pocket shut down July 2025 (export-only until Oct 2025) | Data-loss anxiety, grief over saved libraries | One-click import of Pocket exports; a permanent home | Pocket CSV/JSON importer; "your library lives where you browse" |
| **Omnivore refugees** | Acquired + killed Nov 2024 (two-week export window) | Betrayal; cynicism toward free VC tools | Open-source escape, data ownership | Open formats + local-first; "owned, not rented" messaging |
| **Roam exodus** | $15/mo pricing, slow development | Price resentment, feature stagnation | Structured alternative with backlinks | Roam JSON importer → Honeycomb graph; backlinks native |
| **LastPass refugees** | 2022–2023 breach + 2024–2026 phishing waves | Trust collapse, urgency | Security-by-architecture | Keychain-derived vault; "breach-proof by construction" |
| **Arc refugees** | Arc in maintenance mode (2025) | Product abandonment; the Spaces idea orphaned | Spaces that persist and grow | Spaces + research trails + auto-archive (Phase C) |
| **ChatGPT memory casualties** | Feb 2025 "silent memory implosion" | Memory loss horror; distrust of cloud memory | Local, auditable, exportable memory | Honeycomb memory with memory page + digest approval + export |
| **Instapaper price-doublers** | Premium doubled 2024, no new features | Value-perception shift | Modern features at the old price | Bundled; reader + memory + recall at a fraction |
| **Google Photos refugees** | Free unlimited storage ended 2021; privacy scanning concerns | Subscription fatigue + privacy unease | Local-first photo search | Local CLIP embeddings; "indexes in your Silicon" |

**The playbook rule:** for every cohort, ship the importer BEFORE the marketing. The import experience is the first proof of the product's thesis — data from a dead product resurrected into a living memory, losslessly.

## 2. The Eight Conversion Funnels (segment by segment)

### 2.1 Browser switchers (Chrome/Arc/Brave/Zen/Safari users)
- **Trigger:** RAM pain, privacy unease, ad clutter, or Arc's abandonment.
- **Friction:** import (bookmarks/passwords/history), default-inertia, extension loss.
- **Convert with:** perfect import (C4) + instant memory value (the first captured page becomes a searchable source — Chrome can't do that) + "your browser should remember what you read."
- **Moment of delight:** the first "what was that page about X?" answered from local memory.

### 2.2 PKM power users (Obsidian/Notion/Logseq/Roam)
- **Trigger:** setup tax, plugin rot, sync pain, lock-in fear, or a migration event (Roam).
- **Friction:** structural loss in migration (links, backlinks, properties).
- **Convert with:** markdown/JSON importers that preserve links → Honeycomb graph; and the decisive advantage — **the vault fills itself from browsing** (Obsidian starts empty and stays empty unless you file; Hive fills itself).
- **Moment of delight:** the first research trail that auto-links a capture to an existing project.

### 2.3 Read-later refugees (Readwise/Instapaper/Matter users + orphan cohorts)
- **Trigger:** price (Readwise $120/yr, Instapaper doubling), shutdowns, or the "digital hoarder" guilt.
- **Friction:** highlight/annotation portability.
- **Convert with:** full-text save native to the browser; highlights → Claims → spaced repetition (Hive Recall); no middleman sync architecture.
- **Moment of delight:** a highlight from March resurfacing in today's new-tab interstitial, tied to the source.

### 2.4 AI assistant users (ChatGPT/Claude/Gemini)
- **Trigger:** rate limits, memory loss (Feb 2025 implosion), subscription fatigue ($60/mo across three), context loss between chats.
- **Friction:** copy-paste context tax; distrust of cloud memory.
- **Convert with:** the four edges (context, memory, action, cost) from `competitive-megadossier.md` §21.4; **vendor-independent memory** — route prompts to any frontier model while memory stays local.
- **Moment of delight:** asking about something from a tab read yesterday and getting a cited answer with zero copy-paste.

### 2.5 Email/calendar/task premium users (Superhuman/Hey/Fantastical/Todoist)
- **Trigger:** price anchors ($30/mo Superhuman), triage fatigue, the task-app cycle (confusing tool architecture with productivity).
- **Friction:** ecosystem breakage (OAuth, universal GCal invites), subscription fatigue.
- **Convert with:** keyboard velocity + autonomous filtering as *browser* traits (bundled, not subscribed); tasks born from work (promises, briefs, meeting actions) instead of manual entry.
- **Moment of delight:** the first promise caught from an email and reminded on the due day — no task app installed.

### 2.6 Privacy-first users (Brave/Kagi/Proton crowd)
- **Trigger:** surveillance fatigue, data-economy disgust.
- **Friction:** trust in a new vendor.
- **Convert with:** local-first by default (DEC-004), honest labels (no fake theater), Keychain-derived security, open formats + export. The trust pitch is architectural, not rhetorical.
- **Moment of delight:** the privacy report showing what was captured, stored, and — crucially — what was refused.

### 2.7 Mac power users (Raycast/Magnet/Bartender)
- **Trigger:** per-tool subscriptions, fragmentation tax, the notch eating the menu bar.
- **Friction:** losing their muscle-memory toolchains.
- **Convert with:** the command center + layouts + focus sessions bundled into the browser they already open; user-defined commands/snippets (CMD-001).
- **Moment of delight:** a command palette that knows the research trail, not just apps.

### 2.8 The 2026 orphan cohort (every future closure)
- **Trigger:** any app shutdown/acqui-hire (the pattern: Omnivore, Pocket, Dark Sky, Arc, Rewind's pivot).
- **Friction:** export windows measured in weeks.
- **Convert with:** a standing "refugee response" playbook: monitor shutdowns → ship importer in days → publish a migration guide → meet the cohort where they grieve (HN/Reddit threads).
- **Moment of delight:** the importer resurrecting their library losslessly when the old app is already gone.

## 3. Onboarding Sequence (the first 10 minutes)

1. **Import (2 min):** choose a browser profile; watch bookmarks/passwords/history land. For PKM/read-later cohorts, a second "bring your library" step.
2. **First capture (1 min):** the onboarding page itself is captured as the first Source — the product demonstrates its own thesis during setup.
3. **First question (3 min):** "Ask about anything you were reading last week" — one hybrid-retrieval answer with a citation to a real capture.
4. **First digest (next morning):** the 9 PM/AM digest with approve/deny — the memory approval loop starts on day 1, teaching trust.
5. **First project (day 2–3):** prompt suggests converting a research trail into a project with next actions.
6. **First action (week 1, optional):** studio or flow, gated behind approval — proving actions are safe.

**Onboarding rule:** never force a workspace dashboard before the browser has earned trust (AGENTS.md §2.4). Every unlock is dismissible and reversible.

## 4. Pricing Psychology (research-verified)

1. **Anchor against the stack, not the category:** "You already pay ~$1,500/yr for tools that can't talk to each other." $15/mo against that anchor reads as an 88% discount (contrast-anchor effect).
2. **Setapp lesson (validated):** bundling beats per-tool resistance; anchor tools drive adoption; unified licensing raises churn cost; offer BOTH all-inclusive and à-la-carte.
3. **Free-tier strategy for local-first:** keep local creation/storage free forever (Obsidian's own model — builds trust + viral adoption); gate **sync, encrypted backup, and team/advanced-AI** features. Never a "trapdoor" unlimited free tier (conversion stalls <1–2%).
4. **Ownership framing:** paid tiers are for *convenience and ecosystem growth*, never for renting access to the user's own local data (respects the local-first psychological contract).
5. **The Amex cliff:** stay under the $100/yr psychological cliff for any single tier; HEY's data shows privacy features carry ~20% WTP lift — name the privacy architecture in pricing copy.

## 5. Anti-Churn (the other half of conversion)

- **Reversible by design (DEC-007):** import, memory edits, files, code changes, tasks — every consequential change retains rollback/delete. Users stay when leaving is easy (the "portability paradox": easy export = more trust = more loyalty).
- **The memory is the lock-in, and it's user-owned:** the more the vault fills, the more valuable Hive is — but the vault is exportable (Markdown/SQLite/JSON), so the lock-in is value, not captivity.
- **Digest as retention:** the daily approval loop is a habit loop (the Duolingo/Rewisp lesson) — it brings users back daily without punitive streaks.
- **Honest capability labels:** no disabled-button theater; no "AI enabled" gating of browser features (AGENTS.md §4.8, §10.1). Trust compounds; deception churns.

## 6. Measurement

| Metric | Target (post-launch) | Where it's measured |
|---|---|---|
| Import completion rate | > 80% of imports fully complete | ImportManager reports (BROW-003) |
| First-question success | > 60% of new users ask within 48h | Swarm panel telemetry (local) |
| Digest engagement | > 50% of DAU approve/deny ≥ 1 item/day | Nightly digest logs |
| W1 retention | > 40% (vs ~25% browser norms) | local event ledger (privacy-safe, aggregate) |
| Migration-event response time | importer shipped ≤ 7 days after a shutdown news | refugee-response playbook |
| Churn-on-price-hike | no surprise hikes, ever — price is a promise | pricing policy |

## 7. The one-sentence conversion story

> **"Every app you pay for is context-blind: it never saw the tabs, the email, or the research that made the work real. Hive is the browser that saw all of it — so it remembers, answers, organizes, and acts where the others can't. And because the memory is yours, local, and exportable, it's the only home you won't have to leave."**
