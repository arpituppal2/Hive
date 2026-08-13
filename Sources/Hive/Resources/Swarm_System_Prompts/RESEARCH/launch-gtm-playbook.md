# LAUNCH_GTM_PLAYBOOK — Taking Hive to Market (Q3 2026 launch)

> **Canonical status:** active
> **Created:** 2026-08-11
> **Purpose:** The concrete go-to-market mechanics for the Hive Browser launch, grounded in the launch history of Arc, Zen Browser, Raycast, Linear, Superhuman, and Rewisp plus the conversion-research in conversion-playbook.md. This is the *how*; conversion-playbook.md is the *who* (8 refugee cohorts); competitive-megadossier.md is the *why* (the $1,500/yr stack).
> **Dependencies:** conversion-playbook.md, PITCH/yc-application.md, docs/superpowers/plans/2026-08-11-product-roadmap.md
> **North star:** launch is day zero of the feedback loop, not the finish line. Metrics: waitlist→install 15–25%, activation >40%, W1 retention 25–35% (consumer).

---

## 1. The positioning spine (repeat everywhere, unchanged)

**The browser that remembers what you read and acts on it.** Local-first memory. No cloud memory, no screenshots ever, one-click import from Chrome/Arc/Safari.

- **Enemy, not competitor:** the browser you already have (default inertia) — not Atlas, not Comet, not Dia. Every piece of launch copy names the *user job* ("your tabs forget everything"), never a competitor feature diff.
- **The orphan hook:** Pocket is dead. Omnivore is dead. Arc is in maintenance. Instapaper doubled its price. Every launch asset carries a one-click import story for one of these cohorts (conversion-playbook §2).
- **The trust hook:** ChatGPT's memory implosion made cloud memory scary; Hive's answer is "your memory never leaves this Mac" — said once, plainly, with the code on GitHub.

---

## 2. Phase 0 — Pre-launch engine (now → T-6 weeks)

### 2.1 The waitlist with a qualification gate (Superhuman/Arc model)

- Landing page with a **two-question intake** (Superhuman's proven pattern): *"What browser do you use today?"* + *"What's the one thing you lose track of most?"*
- Segment signups by cohort: Arc refugee / Pocket-orphan / Chrome-exhausted / Obsidian-heavy / privacy-first. Each segment gets a different onboarding path and a different launch-day email.
- **Target: 400–1,000 highly qualified signups** before launch. Research (B2B + consumer launch data) puts that range at 3–5× the odds of top-tier launch visibility versus a cold launch.
- **The referral twist:** Arc's invite-only FOMO worked; the cheap modern version is a referral ladder ("3 friends join, you get early access + a founder walkthrough"). Runs on the waitlist only — never turns into spam.

### 2.2 The beta community (Raycast/Zen model)

- Gated **Discord + TestFlight** with three channels: `#bug-reports`, `#feature-requests`, `#showcase` (users post their workspace/setup — free evangelism footage).
- Beta builds 2×/week; every bug report that lands in a fix within 48h gets a public "shipped thanks to @user" in `#showcase`. This is the W1-retention culture, built before launch.
- **The first-100 playbook starts here:** founder joins every first-100 user's first session (10-min call), watches the install/import/use flow live, fixes the top 3 frictions the same day. First-100 users who are heard become the HN/Reddit defenders who matter on launch day.

### 2.3 Build-in-public breadcrumbs (T-6 → T-1 weeks)

One substantive post per week, alternating platforms, always a *craft* story not an ad:

- Wk 6: "We're building a browser where the memory is a database, not a cloud" (architecture — Honeycomb, local-first)
- Wk 5: "How we imported a Chrome profile with 40k bookmarks without losing one" (import craft)
- Wk 4: "Why we won't ever take screenshots" (privacy-by-construction; Rewisp's exact move)
- Wk 3: "The probe that detects a password form without ever reading the page" (DOM-probe craft)
- Wk 2: "What 243 app teardowns taught us about why people switch" (the megadossier, as a post)
- Wk 1: "The morning brief that reads your real browsing, not your calendar" (feature reveal + TestFlight link)

Each post ends with one soft CTA (TestFlight, waitlist, GitHub star). No "check out my app" posts ever.

---

## 3. Phase 1 — Launch day (T-0, 24 hours)

### 3.1 Product Hunt (midnight PST)

| Window | Action |
|---|---|
| 00:01 PST | Live. Maker comment posted immediately: who we are, the pain, the one-link CTA. |
| 00:15–04:00 | First waitlist cohort email blast (the 150–200 most qualified). Reply to **every comment within 8 min** (PH measures maker-engagement velocity). Target 150–200 upvotes in the randomized window. |
| 04:00–12:00 | Full-list email at peak open (~06:00 PST). Founder X/LinkedIn posts. No vote rings — PH penalties are automatic. |
| 12:00–24:00 | Second maker comment: the day's top learnings + a "we shipped 3 fixes from launch-day bugs" update. |

### 3.2 Hacker News (Show HN)

- Title format: `Show HN: Hive – a browser that keeps a local, searchable memory of what you read` (plain, technical, no adjectives).
- Post in a low-congestion window (early AM Pacific or Sunday). First comment invites the brutal critique the HN crowd respects: *"We capture at the DOM, never screenshots — here's our privacy model and the PII-strip list. Tear it apart."*
- HN rewards constraint stories. Lead with the memory-database architecture and the 8GB-RAM budget (the router/Cell story from ROUTING_SPEC).

### 3.3 Reddit

- No launch posts in r/apple or r/browsers. Instead: **build-in-public continuation** — the Wk-1 morning-brief post goes live the same morning as PH, with the TestFlight link. r/arc (Arc refugees), r/selfhosted + r/PrivacyGuides (local-first angle), r/macapps.
- The orphans' subreddits (r/readwise, r/ObsidianMD, r/Anytype) get the *import* story, not the browser story — "your vault/reader exports import into a browser that keeps them readable" (conversion-playbook §2 mechanics).

### 3.4 Press + creators (pre-embargo, 2 weeks before)

- **One narrative hook, one exclusive:** pitch tech press with a *story* — "the browser that keeps your memory on your Mac while every AI browser sends it to the cloud" — with a functional build 48h before embargo. Target TechCrunch/The Verge as the single primary (they cover browsers as culture, not products).
- **5–10 micro-creators ($500–600 each)** — Mac-setup YouTubers, browser reviewers, productivity-X power users (not macro-influencers). Builds 2 weeks early, reviews drop synchronized with launch day. The review must be a *use-it* video (import a real Chrome profile on camera — that's the demo), not a spec read.

---

## 4. Phase 2 — Post-launch (T+1 → T+6 weeks)

### 4.1 The memory-wedge feedback loop

- The W1 question isn't DAU — it's **"did the first capture delight?"** Instrument activation as: import → first page saved → first digest → first "what did I read about X?" answer. Each is a funnel stage with a target (>40% overall activation).
- Weekly ship cadence for 6 weeks, each named after a user who asked for it ("shipped the nuke button, thanks @…"). This is the momentum Arc had and lost.
- **Refugee-led migration weeks:** one week per cohort, targeted at the subreddit/forum where the dead app's users gathered — Pocket refugees (their export is a click away), Omnivore refugees, Arc refugees. Each week has a landing page: `hive.app/import/pocket` etc.

### 4.2 Monetization timing (from yc-application evidence)

- **Free at launch, complete.** The browser must be fully free for the first N months — Arc's $30/mo mistake was charging for the browser itself. Charge later, at the *service* layer (sync/backup, team, BYOK model routing), never for the core.
- The free tier is the local-first model (Obsidian's proven play): storage is free, *sync* is the paid tier. Memory is the free differentiator; sync is the premium.
- If a paid tier appears in the first 90 days, it is **"Pro" as thank-you**, not a paywall: early-access features, backup, multi-device sync — and the $100/yr anchor against the $1,500/yr stack it replaces (pricing psychology from conversion-playbook §4).

---

## 5. Metrics dashboard (launch control)

| Metric | Target | Where it comes from |
|---|---|---|
| Waitlist → install | 15–25% | Waitlist emails → app-open, cohort-tagged |
| Activation (import → first save → first answer) | >40% | Funnel events, per cohort |
| W1 retention | 25–35% (consumer) | Day-1 → Day-8 return |
| W1 retention, dev/Arc cohort | >50% | Same |
| First-capture-to-digest completion | >30% | Digest event |
| Nuke / forget usage | 0 errors, <5% of users/day | Support signals (nuke must never fail) |
| Per-cohort import completion | >60% | Import flow funnel (import started → finished → kept) |
| Memory answer hit-rate ("did the answer cite a real saved page?") | 100% grounded | Citation audit (W-10 in WISP_CAPTURE_SPEC; citation invariant in HONEYCOMB_SPEC) |

### Failure modes we pre-commit to

1. **Performance bloat = instant uninstall.** If a single tab, the chrome shell, or the memory layer exceeds the SPEC.md memory budget on the M1 8GB floor, memory features get cut before the browser does (AGENTS.md rule: browser credibility ships first).
2. **Import death in the first hour** — the #1 browser-switch killer. The import flow is the most-tested surface at launch; any import that fails *partially* must report exactly what failed (existing import-report semantics), never silently drop data.
3. **"This is just another browser"** — if activation says users import and leave, the memory wedge isn't visible enough. Fix the first-save moment (the toast + the brief), not the marketing.
4. **Theater accusations** — no fake streaming, no fake citations, no model labels that lie (ROUTING_SPEC no-theater rules are launch commitments, not just internal rules). One caught lie is a launch-killer; the honesty invariant tests (HiveCoreTests) are a release gate.

---

## 6. Launch calendar (tied to product-roadmap.md)

| Date | Milestone | GTM event |
|---|---|---|
| T-6 wk | M1 demo gate + waitlist live | Landing page + intake gate up; build-in-public Wk 1 |
| T-4 wk | Beta (TestFlight + Discord) | First 100 users onboarded with founder calls |
| T-2 wk | Press embargo + creator builds out | Exclusive pitch delivered; reviews recorded |
| T-0 | **Launch** | PH midnight + Show HN + Reddit continuation + reviews drop |
| T+1 wk | Pocket/Omnivore import week | Cohort landing pages + subreddit stories |
| T+2 wk | Arc-refugee import week | r/arc + "what Arc could have been" angle |
| T+3 wk | Memory-week (digest + wisp) | Feature-led posts, first "did you notice?" shareables |
| T+6 wk | M2 verified + W1-review post | Launch retrospective: numbers, learnings, roadmap |

Every date defers to the product gates: **if a milestone's exit criteria aren't met (build green, tests green, M2 stages 1–3 verified), the GTM event moves, not the code.** No launch before the browser is credible — that is the whole strategy.
