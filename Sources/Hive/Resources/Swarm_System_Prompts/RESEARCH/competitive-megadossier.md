# Competitive Mega-Dossier — The Full Replacement Universe

> **Canonical status:** active
> **Created:** 2026-08-11
> **Companion to:** `competitive-dossier.md` (direct battlefield: browsers, KM, coding agents, AI research, utilities)
> **Purpose:** The hundreds-of-apps map. Every category Hive will absorb, every app's user job, why it wins, its weaknesses, and what Hive ships instead. Where `competitive-dossier.md` covers the 35 direct competitors, this document covers the entire 243-app replacement universe across 31 categories.
> **Method:** Web research over 2024–2026 market data + Jobs-to-Be-Done analysis. Every entry: positioning → user job → why it wins → weaknesses → monetization → Hive counter-move.

---

## HOW TO READ THIS DOSSIER

Each category entry follows the same five-part anatomy:

| Field | Question it answers |
|---|---|
| **Positioning** | One line: what the product is |
| **User job** | The JTBD it is hired for (never "collect email" — always the underlying need) |
| **Why it wins** | The flywheel, moat, or habit that keeps users |
| **Weaknesses** | Friction, churn, pricing, trust, and architectural gaps Hive can exploit |
| **Hive counter-move** | The browser-native, memory-first, local-first replacement |

The strategic frame: **Hive is not 100 apps bolted together. Hive is one substrate (browser + Honeycomb memory + Swarm Cells) that progressively discloses one absorbed job at a time.** Every entry below maps an external product to a Hive module and a memory primitive.

---

## §1 — PERSONAL FINANCE (8 apps)

### 1.1 Monarch Money
- **Positioning:** The "spiritual successor to Mint" — multi-account tracking with couples collaboration.
- **User job:** "Where did my money go, without logging into five bank portals — and can my partner see it too?"
- **Why it wins:** Best-in-class multi-user sharing, deep UI customization, Mint-refugee trust.
- **Weaknesses:** $99.99/yr is steep for a tracking dashboard; bank-sync dropouts; tier-splitting price hikes (2026).
- **Monetization:** Subscription only. No free tier worth using.
- **Hive counter-move:** Ambient finance — transactions tagged automatically from email/order pages you already browse. Zero separate login. Cost: bundled, not subscribed. Couples via Hive shared spaces.

### 1.2 YNAB
- **Positioning:** Zero-based budgeting cult with a coaching library.
- **User job:** "Force me to give every dollar a job so I stop living paycheck to paycheck."
- **Why it wins:** Behavioral philosophy, community, 34-day trial.
- **Weaknesses:** Extreme learning curve; requires constant manual maintenance; $109/yr.
- **Monetization:** Subscription.
- **Hive counter-move:** YNAB's rules engine as a Hive Sheet formula layer — rule 1 (give every dollar a job) is a deterministic local formula, not a subscription philosophy.

### 1.3 Tiller Money
- **Positioning:** Transactions fed directly into Google Sheets/Excel.
- **User job:** "I want my financial data in a format I can script and formula over."
- **Why it wins:** Complete data ownership; spreadsheet power users.
- **Weaknesses:** Zero mobile polish; formula maintenance burden; $79/yr.
- **Monetization:** Annual subscription.
- **Hive counter-move:** Hive Sheets with a live finance feed is Tiller minus the Google Sheets bridge. Data is local, typed, exportable — the Tiller job without the spreadsheet tax.

### 1.4 Copilot Money
- **Positioning:** The prettiest finance app — mobile-first, Apple-only.
- **User job:** "I want my finances to look and feel delightful."
- **Why it wins:** Aesthetic perfection, smart categorization.
- **Weaknesses:** No Android; rising price; categorization drift where AI unlearns custom rules.
- **Monetization:** $13/mo.
- **Hive counter-move:** Native Mac quality (SPEC.md design bar) with local categorization rules that never drift because they're user-owned typed rules, not opaque cloud models.

### 1.5 Lunch Money
- **Positioning:** Indie, developer-friendly, multi-currency tracking.
- **User job:** "Track money across currencies with an API I can script against."
- **Why it wins:** Transparency, API access, crypto support, fair pricing.
- **Weaknesses:** Thin mobile; manual portfolio setup.
- **Monetization:** Pay-what-you-want around $10/mo.
- **Hive counter-move:** The same openness natively — Hive's command center is the API. Multi-currency is a Sheet column type.

### 1.6 Quicken Classic / Simplifi
- **Positioning:** Legacy desktop finance (Classic) and the modern cloud spin-off (Simplifi).
- **User job:** "Trusted brand, deep investment/tax tracking."
- **Why it wins:** Brand trust from 40 years of desktop accounting.
- **Weaknesses:** Rigid transfer handling, aggregator bugs, clunky transitions.
- **Monetization:** ~$5.99/mo.
- **Hive counter-move:** None needed beyond the above — legacy brand trust decays with every price hike.

### 1.7 Rocket Money
- **Positioning:** Subscription-finder + bill negotiator.
- **User job:** "Find my forgotten recurring charges and kill them."
- **Why it wins:** Instant ROI — recovers its own cost in week one.
- **Weaknesses:** Aggressive upselling, hard-to-cancel premium, shallow budgeting.
- **Monetization:** Freemium + sliding premium + success fees.
- **Hive counter-move:** Subscription detection is a **Hive Memory** wisp job (recurring-charge patterns across email + banking exports). The "leak-plugger" value becomes a nightly digest card, not a separate subscription.

### 1.8 User-job synthesis (finance)
1. Tracking ("where did it go") → **Hive ledger views**
2. Budgeting ("what can I spend") → **Hive Sheet formula rules**
3. Net worth ("am I richer") → **Honeycomb number nodes + sparklines**
4. Forecasting ("can I afford X") → **local deterministic projections**
5. Leak-plugging ("what's recurring") → **Memory wisp patterns**

---

## §2 — PASSWORDS & IDENTITY (7 apps)

### 2.1 1Password
- **Positioning:** The premium zero-knowledge vault with Secret Key.
- **User job:** "Every credential, document, and API key — impossible to phish, effortless to fill."
- **Why it wins:** Secret Key dual-layer crypto, Watchtower, Travel Mode, polish.
- **Weaknesses:** No free tier, creeping price, no live chat.
- **Monetization:** $2.99–$5.99/mo.
- **Hive counter-move:** Browser-native vault (autofill is the browser's job anyway) + **Keychain-backed** secrets. The Secret Key lesson: derive a local key so a stolen vault file is useless — implement without the subscription.

### 2.2 Bitwarden
- **Positioning:** Open-source, generous free tier.
- **User job:** "Secure credentials with zero trust in any vendor."
- **Why it wins:** Open source, $10/yr, free tier.
- **Weaknesses:** Clinical UI, autofill wobble.
- **Monetization:** Free + cheap premium.
- **Hive counter-move:** Match the openness (auditable, exportable) with native-grade UI. Hive's password manager already ships save/capture/autofill/generator.

### 2.3 LastPass
- **Positioning:** The cautionary tale.
- **User job:** (formerly) easy cross-platform vault.
- **Why it wins:** Nothing anymore — post-breach trust collapse.
- **Weaknesses:** 2022–2023 vault breach + 2024–2026 phishing campaigns; mass exodus.
- **Monetization:** Subscription, declining.
- **Hive counter-move:** The trust lesson: breach-proof by architecture (Keychain + local derivation), not by promise. Market the counterfactual: "Your vault file is encrypted with a key that never leaves your Mac."

### 2.4 Dashlane
- **Positioning:** Autofill + auto-password-changer.
- **User job:** "Change breached passwords without visiting every site."
- **Why it wins:** Auto-changer, high-accuracy autofill.
- **Weaknesses:** Expensive, 25-item free cap, heavy extension.
- **Monetization:** $3.33–$5.42/mo.
- **Hive counter-move:** Auto-change is a browser action flow (typed, permissioned, audit-logged) — exactly what Hive's action ladder is built for.

### 2.5 Proton Pass
- **Positioning:** Privacy-first vault with email aliasing.
- **User job:** "Vault + identity shielding under Swiss privacy law."
- **Why it wins:** SimpleLogin aliases, open source, free tier.
- **Weaknesses:** No emergency access, no live chat.
- **Monetization:** $2.49/mo.
- **Hive counter-move:** Email aliasing as a native Hive identity feature; aliases auto-generated per site during signup, stored as typed identity objects.

### 2.6 NordPass / 2.7 iCloud Keychain
- **Positioning:** Budget XChaCha20 vault (NordPass) / Apple's free system keychain (Keychain).
- **User job:** Cheap or free credentials with platform trust.
- **Why it wins:** Price (both), OS integration (Keychain).
- **Weaknesses:** Keychain is walled-garden (bad on Windows/Android, no family sharing, no rich items); NordPass renewal hikes.
- **Hive counter-move:** Hive's vault is the browser's answer to Keychain's lock-in — same OS-level feel, but exportable, family-shareable, and cross-platform.

### 2.8 Identity synthesis
- Passwords + passkeys + TOTP + aliases + secure notes = one **Identity object graph** in Honeycomb.
- Autofill is a browser capability; the vault is a typed store; breach monitoring is a Memory wisp. No separate app should exist.

---

## §3 — EMAIL (8 apps)

### 3.1 Gmail
- **Positioning:** The default inbox; ad-funded at consumer level.
- **User job:** "Receive, triage, archive, and search my mail for free."
- **Why it wins:** Scale, free, labels/archive paradigm, +aliases.
- **Weaknesses:** Ad clutter, tab confusion, privacy scanning, no true triage intelligence.
- **Monetization:** Ads + Workspace.
- **Hive counter-move:** Hive Mail (P3+): local-first index of any IMAP account with AI triage that screens, bundles, and silent-files noise — no ads, no scanning-for-ads.

### 3.2 Superhuman
- **Positioning:** $30/mo keyboard-speed email for executives.
- **User job:** "Process email at the speed of thought, zero mouse, zero missed follow-ups."
- **Why it wins:** Keyboard velocity, split inbox, read receipts, CRM integration.
- **Weaknesses:** Price, Gmail/Outlook wrapper dependency (API quotas), suite-forcing.
- **Monetization:** $30–$40/mo suite.
- **Hive counter-move:** Keyboard-first is a **command center** trait, not a product. Hive's omnibar + command palette gives the same velocity natively; AI triage runs on-device; price is bundled.

### 3.3 HEY
- **Positioning:** The opinionated anti-inbox ($99/yr, Basecamp).
- **User job:** "Let a philosophy gatekeep my email so I only see people."
- **Why it wins:** The Screener, paper-trail grouping, tracker blocking, radical stance.
- **Weaknesses:** Closed ecosystem (no IMAP), no free tier, playful UI alienates enterprise.
- **Monetization:** $99/yr.
- **Hive counter-move:** The Screener becomes an on-device classifier Cell (100M router tier) that learns the user's senders — autonomous intent filtering without a fixed subscription or a new email provider.

### 3.4 Spark
- **Positioning:** Cross-platform smart inbox with team features.
- **User job:** "Unified inbox across providers with team drafts."
- **Why it wins:** Smart Inbox, multi-provider, team collaboration.
- **Weaknesses:** Upsell pressure, AI quotas.
- **Monetization:** $8.25–$20/mo.
- **Hive counter-move:** Multi-provider unified inbox is a connector; team drafts are Hive shared spaces. Same job, no per-seat AI tax.

### 3.5 Airmail / 3.6 Fastmail / 3.7 Edison / 3.8 Shortwave
- **Positioning:** Apple-native client / standards-first JMAP provider / free unified inbox / Gmail-speed AI wrapper.
- **User job:** Fast native feel (Airmail); ownership + aliases (Fastmail); free consolidation (Edison); Superhuman speed without the price (Shortwave).
- **Why they win:** Niche DX excellence.
- **Weaknesses:** Airmail price hikes; Fastmail's plain UI; Edison's data monetization scandal risk; Shortwave's Gmail dependency.
- **Hive counter-move:** The Hive mail surface absorbs each: native Mac feel (Airmail), standards compliance + masked email (Fastmail), free consolidation (Edison), keyboard+AI speed (Shortwave) — without any of the wrappers' failure modes.

### 3.9 Email user-job synthesis
1. **Triage hub** → on-device intent filter (HEY/Superhuman job)
2. **Record of truth** → Honeycomb sources (every thread is a Source node; promises become Claims)
3. **Anxiety control** → promise catching + follow-up Cells (Memory wisps over writing surfaces)
4. **Drafting** → Swarm writer with context from Honeycomb (never a generic chatbot)

---

## §4 — CALENDAR (6 apps)

### 4.1 Google Calendar
- **Positioning:** Free default calendar.
- **User job:** "Know what's next and don't miss it."
- **Why it wins:** Free, universal, invites.
- **Weaknesses:** Cluttered UI, no natural-language input, weak AI.
- **Hive counter-move:** Hive Calendar (P3+): local-first calendar with typed event nodes, natural-language input via a 1B parser Cell, and AI scheduling that respects your Hive task graph.

### 4.2 Fantastical
- **Positioning:** The natural-language calendar king.
- **User job:** "Type 'lunch with Sam Friday 1pm' and it just works."
- **Why it wins:** Best-in-class NL parsing, time zones, templates.
- **Weaknesses:** Subscription creep, Mac-only legacy.
- **Monetization:** ~$4.99–$6.99/mo.
- **Hive counter-move:** The NL parser is a Cell job (deterministic rules + small model), bundled. Calendar events live as Honeycomb nodes linkable to tasks, sources, and emails.

### 4.3 Notion Calendar (ex-Cron)
- **Positioning:** Calendar fused with Notion databases.
- **User job:** "See my calendar next to my tasks and projects."
- **Why it wins:** Notion integration, keyboard speed, clean UI.
- **Weaknesses:** Depends on Notion; standalone value thin.
- **Hive counter-move:** Hive's calendar is natively fused with Hive's task + project graph — no integration layer needed because they share one object model.

### 4.4 Vimcal / 4.5 BusyCal / 4.6 Reclaim.ai / 4.7 Calendly
- **Positioning:** Speed-focus calendar / power-user local calendar / AI time-blocking / scheduling links.
- **User job:** Velocity (Vimcal); deep features offline (BusyCal); auto-protect focus time (Reclaim); let others book me (Calendly).
- **Why they win:** Focused DX.
- **Weaknesses:** Each is a single trick; Reclaim adds a subscription on top of your calendar; Calendly is a separate SaaS for what is a link generator.
- **Hive counter-move:** Scheduling links = a Hive command ("Share my availability"); time-blocking = task scheduler Cells that propose blocks; focus protection = Focus Sessions with awake leases. All from one calendar object graph.

---

## §5 — COMMUNICATION & MEETINGS (10 apps)

### 5.1 Slack
- **Positioning:** Enterprise channel-based collaboration hub.
- **User job:** "Coordinate work asynchronously with channels, threads, and integrations."
- **Why it wins:** Integration gravity (Salesforce, GitHub, Jira), Workflow Builder, Connect.
- **Weaknesses:** Cost per seat, notification fatigue, info sprawl, high governance burden.
- **Monetization:** Per-seat SaaS.
- **Hive counter-move:** Hive's shared spaces + context broker give the channel model natively with Memory — every conversation threads into Honeycomb, so nothing is lost to channel sprawl.

### 5.2 Discord
- **Positioning:** Real-time community platform.
- **User job:** "Run a living community with voice and bots."
- **Why it wins:** Free voice rooms, role hierarchy, bot ecosystem, low latency.
- **Weaknesses:** No enterprise compliance/DLP; IA decay without moderation.
- **Hive counter-move:** Hive Spaces with role-based access + community capture — communities get Memory (what was decided, who promised what) that Discord cannot provide.

### 5.3 Telegram / 5.4 WhatsApp / 5.5 Signal
- **Positioning:** Broadcast-scale cloud messaging / universal consumer reach / privacy-hardened messaging.
- **User job:** Reach (Telegram), ubiquity (WhatsApp), confidentiality (Signal).
- **Why they win:** Network effects; each is infrastructure.
- **Weaknesses:** Telegram default cloud encryption; WhatsApp metadata; Signal ecosystem thinness.
- **Hive counter-move:** Hive is not another messaging app. Hive connects via connectors (read-only, permissioned) and captures promises/decisions into Memory — the browser-native layer **above** the messaging duopoly. Signal-level E2EE stays in Signal; Hive records only what the user approves.

### 5.6 Microsoft Teams
- **Positioning:** The M365-bundled enterprise chat+meetings hub.
- **User job:** "One tenant for chat, meetings, and docs inside M365."
- **Why it wins:** Bundle gravity + Azure AD.
- **Weaknesses:** Bloat, resource use, admin sprawl.
- **Hive counter-move:** The anti-Teams: fast, local, memory-first. Where Teams is heavy infrastructure, Hive is a browser that happens to know your whole work context.

### 5.7–5.9 Otter / Fireflies / Fathom
- **Positioning:** Meeting transcription and AI summaries.
- **User job:** "Never hand-write meeting notes again; capture decisions and action items."
- **Why they win:** Transcription accuracy, CRM automation (Fireflies), generous free tier (Fathom).
- **Weaknesses:** Post-call lag (no live assist), bot friction (participants see the bot), no memory surfacing during the call.
- **Hive counter-move:** **Hive Live Meeting Memory** — the meeting is a Source; live on-device transcription (whisper-class local model); during the call, Swarm surfaces past context from Honeycomb; after the call, decisions/actions are typed objects. No bot joins; capture is local.

### 5.10 Communication synthesis
- Fragmentation tax is the enemy. Hive's answer: one **unified memory layer** over N messengers via read-only connectors, plus browser-native capture. Nobody replaces WhatsApp; somebody replaces the *context switching* between WhatsApp, Slack, and email. That somebody is Hive.

---

## §6 — VIDEO & CREATIVE (9 apps)

### 6.1 CapCut
- **Positioning:** Free, template-driven mobile video editor (ByteDance).
- **User job:** "Make a polished short video in minutes with zero learning."
- **Why it wins:** Templates, auto-captions, price (free), TikTok synergy.
- **Weaknesses:** Data/privacy concerns, watermark pressure, shallow pro controls.
- **Hive counter-move:** Hive Studio (P3+): template-driven clips + auto-captions from local ASR, no data exfiltration. Creative artifacts are Honeycomb objects with full provenance.

### 6.2 Canva
- **Positioning:** Design-for-everyone (docs, video, social).
- **User job:** "Produce passable visual content without a designer."
- **Why it wins:** Templates + collaboration + freemium.
- **Weaknesses:** Generic output (AI-slop aesthetics), subscription creep, brand dilution.
- **Hive counter-move:** Hive Studio + Cells with strict brand tokens (SPEC.md warm palette). The design system is enforced by prompt contract, so output never reads as Canva-generic.

### 6.3–6.5 After Effects / Premiere / DaVinci Resolve / Final Cut
- **Positioning:** Pro NLE + motion graphics + color science.
- **User job:** Professional editing, compositing, color grading.
- **Why they win:** Industry-standard depth, plugin ecosystems.
- **Weaknesses:** Learning curves, subscription rent (Adobe), hardware demands.
- **Hive counter-move:** Not a replacement — a *first-mile* capture: Hive captures source clips, transcripts, storyboards, and drafts; exports to these tools when pros need them. The browser owns the memory of the project; the NLE owns the pixels.

### 6.6 Blender
- **Positioning:** Free, open-source 3D creation suite.
- **User job:** 3D modeling/animation on a budget.
- **Why it wins:** Free, community, incredible depth.
- **Weaknesses:** Steepest learning curve in software.
- **Hive counter-move:** Tutorial/context layer: Hive captures the tutorial you watched, the file you opened, the step you're on — walkthrough memory that Blender cannot offer.

### 6.7 Runway ML
- **Positioning:** AI video generation/editing tools.
- **User job:** "Generate or edit video with AI prompts."
- **Why it wins:** First-mover AI video, Gen-3/4 models, creative tools.
- **Weaknesses:** Cost per generation, output consistency, reliability.
- **Hive counter-move:** Hive's media Cells route to local or BYOK generation with typed contracts; generations are versioned artifacts in Honeycomb with their prompts retained.

### 6.8 Descript
- **Positioning:** "Edit video like a doc" — transcript-based editing.
- **User job:** "Edit by deleting words, not scrubbing timelines."
- **Why it wins:** The transcript-editing paradigm, overdub.
- **Weaknesses:** Heavy processing, cloud dependency.
- **Hive counter-move:** Transcript-first editing is a natural Hive Studio mode — local ASR + text-as-timeline + typed audio/video artifacts.

### 6.9 Video user-job synthesis
1. Quick polish → templates + local AI (CapCut/Canva job)
2. Pro editing → interoperate, don't replace (Premiere/Resolve job)
3. AI generation → typed, versioned generation (Runway job)
4. Learning → walkthrough memory (Blender job)
The browser owns **project memory**; no editor does.

---

## §7 — PHOTOS (10 apps)

### 7.1 Google Photos
- **Positioning:** The default cloud photo backup + search.
- **User job:** "Back up my photos invisibly and find any photo by description later."
- **Why it wins:** Zero-thought backup, best-in-class semantic search (CLIP), Memories.
- **Weaknesses:** Unlimited storage era over (2021); 15GB shared pool; privacy scanning; lock-in via Takeout pain.
- **Monetization:** Google One storage subscriptions.
- **Hive counter-move:** **Hive Photos** (local-first): DOM/import-based ingestion + on-device CLIP-class embeddings (nomic embedder roadmap) + local semantic search + optional zero-knowledge backup. The privacy pitch writes itself: "Google Photos indexes in the cloud; Hive indexes in your Silicon."

### 7.2 Apple Photos
- **Positioning:** OS-integrated photo library.
- **User job:** Same as Google Photos, inside the Apple walled garden.
- **Why it wins:** OS integration, on-device intelligence, ADP E2EE option.
- **Weaknesses:** 5GB free, Windows/web experience, lock-in.
- **Hive counter-move:** Complement, then absorb the job: Hive captures web images, screenshots, and receipts (things Apple Photos never organizes) and links photos to projects/sources.

### 7.3 Adobe Lightroom / 7.4 Capture One / 7.5 Photomator / 7.6 Darkroom
- **Positioning:** Raw editing (LR), tethered pro shooting (C1), Apple-native AI editing (Photomator), fast batch (Darkroom).
- **User job:** Non-destructive raw editing; pro tethering; quick AI enhancement.
- **Why they win:** Depth, camera profiles, Apple silicon optimization.
- **Weaknesses:** Adobe subscription rent + AI-training backlash; Capture One price hikes (6% 2026); Apple-only.
- **Hive counter-move:** Hive's editing layer is non-destructive by design (every edit = a typed transform in Honeycomb, fully reversible — DEC-007 reversibility). Interop with Lightroom via local catalogs. Never rent software.

### 7.7 Flickr / 7.8 500px
- **Positioning:** Legacy photo communities.
- **User job:** Showcase + community + licensing.
- **Why they win:** Community heritage.
- **Weaknesses:** Traffic decline, paywall aggression, algorithm bias.
- **Hive counter-move:** Hive Profiles give photographers a local-first portfolio that publishes anywhere — the community is the user's own graph, not a platform feed.

### 7.9 Immich / 7.10 PhotoPrism
- **Positioning:** Self-hosted Google Photos clones.
- **User job:** Own your photo library, fully private.
- **Why they win:** Open source, absolute privacy.
- **Weaknesses:** Setup overhead, ML container RAM hunger (6–8GB), maintenance.
- **Hive counter-move:** Hive is the zero-setup Immich: the browser already runs locally, the embeddings run on the M-series chip, and the library is a Honeycomb store — no Docker, no YAML, no maintenance.

### 7.11 Photo user-job synthesis
1. Capture/invisibility → automatic ingestion into Hive
2. Retrieval ("the needle") → local CLIP embeddings + FTS5
3. Safety/permanence → local + optional zero-knowledge backup
4. Polish → typed non-destructive edits
5. Sharing → permissioned links from the local graph

---

## §8 — CAREER & JOBS (8 apps)

### 8.1 LinkedIn
- **Positioning:** The professional identity monopoly + job board + feed.
- **User job:** "Maintain a professional identity, network, and discover jobs."
- **Why it wins:** Network-effect moat; everyone has a profile; recruiters live there.
- **Weaknesses:** Feed enshittification, engagement-bait, data harvesting, identity theater, AI features bolted on.
- **Monetization:** Recruiter/Learning/Premium tiers.
- **Hive counter-move:** A **local-first professional profile** that is the source of truth; LinkedIn becomes one export target. Hive Profile keeps a typed identity object (roles, skills, artifacts) that can publish anywhere — plus job discovery from the research trail (roles you read about, companies you browse, comp you saw on Levels.fyi). The moat flips: your career graph is yours.

### 8.2 Glassdoor
- **Positioning:** Company reviews + salaries.
- **User job:** "Check a company before I apply."
- **Why it wins:** Crowdsourced data scale.
- **Weaknesses:** Real-name controversies, review manipulation, declining trust.
- **Hive counter-move:** Company research as a Hive research trail: reviews, news, salary data, people, products — assembled from real sources with provenance, saved as a Brief.

### 8.3 Levels.fyi
- **Positioning:** Compensation transparency.
- **User job:** "Know what I should be paid."
- **Why it wins:** Crowdsourced comp data, clean UI.
- **Weaknesses:** Self-report bias, tech-only coverage.
- **Hive counter-move:** Comp data captured into a Hive research brief per company with freshness labels (Section 11 research bar: staleness visible).

### 8.4 Otta / 8.5 Cord / 8.6 Read.cv / 8.7 Handshake / 8.8 Wellfound
- **Positioning:** Design-friendly job boards / AI recruiting / portfolio-profiles / campus recruiting / startup jobs.
- **User job:** Find the right role without job-board sludge.
- **Why they win:** Niche curation, UI quality.
- **Weaknesses:** Each is a fragmented silo with its own login and duplicate profile.
- **Hive counter-move:** One career object graph + a unified job search across every board via connectors, deduplicated, with a research trail per opportunity. Recruiting is a browser job — Hive already knows what you read, applied to, and researched.

---

## §9 — EDUCATION & LEARNING (10 apps)

### 9.1 Duolingo
- **Positioning:** Gamified language learning.
- **User job:** "Build a daily learning habit that doesn't feel like work."
- **Why it wins:** Streaks, leagues, characters, effective micro-lessons.
- **Weaknesses:** Energy-limit monetization backlash, ad wall on free tier, AI-worker controversies.
- **Hive counter-move:** Streak mechanics in Hive's daily digest (approve/learn cards) — intrinsic gamification without punishment loops.

### 9.2 Khan Academy
- **Positioning:** Nonprofit mastery-learning.
- **User job:** "Actually understand a concept before moving on."
- **Why it wins:** Mastery learning, free, Khanmigo AI tutor.
- **Weaknesses:** Humanities thin, no peer learning.
- **Hive counter-move:** Mastery as a Honeycomb claim graph: each concept is a Claim node with prerequisites and evidence; the tutor Cell checks understanding before unlocking next.

### 9.3 Brilliant
- **Positioning:** Interactive first-principles STEM.
- **User job:** "Learn math/CS by doing, not watching."
- **Why it wins:** Interactive widgets, immediate reward.
- **Weaknesses:** Expensive, difficulty jumps.
- **Hive counter-move:** Interactive problem sets as Hive Cards; the tutor Cell adapts difficulty from mastery state.

### 9.4 MasterClass / 9.5 Skillshare
- **Positioning:** Celebrity inspiration / project-based creative learning.
- **User job:** Inspiration (MasterClass); build-something (Skillshare).
- **Why they win:** Production value; project community.
- **Weaknesses:** Low long-term retention; passive viewing; quality variance.
- **Hive counter-move:** Capture the lecture you watched into Memory; surface the project step you're on; the retention problem (people binge once) is solved by spaced-repetition review cards in the digest.

### 9.6 Udemy / 9.7 Coursera
- **Positioning:** Course marketplace / university-backed credentials.
- **User job:** Tactical skill (Udemy); credentialed career switch (Coursera).
- **Why they win:** Depth, credentials.
- **Weaknesses:** Low completion rates, quality variance, subscription fatigue.
- **Hive counter-move:** Hive doesn't compete with credentialing — it makes course content *stick*: notes, highlights, quizzes, and reviews fold into the learner's knowledge graph from any provider.

### 9.8 Quizlet / 9.9 Anki
- **Positioning:** Flashcards / spaced-repetition power tool.
- **User job:** "Memorize large volumes with minimal effort."
- **Why they win:** Anki's SM-2/FSRS algorithms; Quizlet's social study sets.
- **Weaknesses:** Anki's brutal setup + UI; Quizlet's paywalls.
- **Hive counter-move:** **Hive Recall** — auto-generate cards from anything you read (highlight → cloze card via a Cell), spaced repetition built into the new-tab interstitial and digest. The Anki job with zero card-writing friction.

### 9.10 Learning user-job synthesis
1. Career/credential → interoperate with Coursera-class providers
2. Immediate rescue ("exam tomorrow") → Hive Q&A over captures
3. Identity/expression → creative Cells
4. Retention → **Hive Recall** (spaced repetition over your actual browsing)
The browser is the only place where learning, reading, and review all happen in one loop.

---

## §10 — HEALTH & WELLNESS (10 apps)

### 10.1 Apple Health
- **Positioning:** The OS-level health aggregator.
- **User job:** "All my biometrics in one private place."
- **Why it wins:** OS integration, E2EE, on-device.
- **Weaknesses:** Fragmented third-party permissions; no coaching.
- **Hive counter-move:** Hive reads HealthKit (permissioned) and adds the *context* layer: "Your resting HR rose the week you started that project" — linking health signals to your actual life events, which no health app knows.

### 10.2 Whoop / 10.3 Oura
- **Positioning:** Recovery/strain wearables (band / ring).
- **User job:** "Tell me when to push and when to rest."
- **Why they win:** HRV-grade sensing, readiness scores, Coach.
- **Weaknesses:** $30/mo (Whoop) + hardware; cloud processing; false strain flags.
- **Hive counter-move:** Hive integrates their APIs into a wellness dashboard that also knows your work context — readiness meets calendar: "You're down 20% HRV and tomorrow is your demo. Schedule prep today, present fresh."

### 10.4 MyFitnessPal
- **Positioning:** Calorie/macro logging.
- **User job:** "Log what I eat."
- **Why it wins:** Crowdsourced food DB.
- **Weaknesses:** Ad bloat, unverified DB entries, breach history.
- **Hive counter-move:** Photo-to-log via local vision + typed nutrition nodes; private by default.

### 10.5 Fastic / 10.6 Zero
- **Positioning:** Fasting timers.
- **User job:** "Track a fasting window."
- **Why they win:** Simplicity, streaks.
- **Weaknesses:** Upsell walls, notification spam, no clinical grounding.
- **Hive counter-move:** Fasting as a timer Card in Hive; the wellness guard (WELL-001) keeps it gentle and off-device for analytics (AGENTS.md §7.9 policy).

### 10.7 Reflectly
- **Positioning:** AI journaling / CBT-adjacent mood tracking.
- **User job:** "Process feelings by journaling with a gentle guide."
- **Why it wins:** Conversational journaling.
- **Weaknesses:** Sensitive text through cloud LLMs; paywalls on past entries.
- **Hive counter-move:** **Hive Journal** with on-device journaling Cells — mood, memory, and reflection stay in Honeycomb; the digest surfaces patterns ("You're happiest on days you exercise").

### 10.8 Headspace / 10.9 Calm / 10.10 Apple Fitness+
- **Positioning:** Meditation / sleep audio / guided workouts.
- **User job:** Stress relief, sleep, exercise guidance.
- **Why they win:** Content libraries, brand.
- **Weaknesses:** Subscription repetition, content fatigue.
- **Hive counter-move:** Hive Wellness links these jobs to the user's actual schedule and stress signals; break reminders that respect calls/screen-share (WELL-002). Not a content company — a context company.

### 10.11 Wellness synthesis
The job is not "track" — it is **reassurance + early warning + behavioral feedback + cognitive offload**. Hive's unique asset: it knows *why* your week was stressful (the launch, the deadline, the move) because it saw the work. No health app has that.

---

## §11 — MAC UTILITIES (10 apps)

### 11.1 Raycast / 11.2 Alfred
- **Positioning:** Keyboard launchers / command centers.
- **User job:** "Do anything with a keystroke — launch, search, transform, automate."
- **Why they win:** Velocity; Raycast's extension store (1,600+); Alfred's one-time price.
- **Weaknesses:** Raycast Pro subscription; Alfred's node-workflow complexity; both are separate from your browser context.
- **Monetization:** Freemium+Pro / one-time Powerpack.
- **Hive counter-move:** **Hive Command Center** (CMD-001): the omnibar IS the command palette; it already knows tabs, history, memory, and project context. Raycast can't suggest "resume that research trail from Tuesday" — Hive can, because Hive has the memory.

### 11.3 Magnet / 11.4 Rectangle / 11.5 Amethyst
- **Positioning:** Window snapping / tiling.
- **User job:** "Arrange windows without dragging."
- **Why they win:** Keyboard snap, automatic tiling.
- **Weaknesses:** Each is a single-trick utility; no saved multi-app layouts.
- **Hive counter-move:** **Hive Layouts** (P3): saved workspace layouts tied to projects — "Coding" opens IDE+tabs+terminal; "Research" opens split browser. Requires Accessibility permission, per AGENTS.md §7.8.

### 11.6 Bartender
- **Positioning:** Menu-bar organization.
- **User job:** "Hide menu bar clutter; surface only what matters now."
- **Why it wins:** The notch ate the menu bar.
- **Weaknesses:** Post-acquisition churn (users fled to Ice/Hidden Bar).
- **Hive counter-move:** Contextual menu-bar modes (P4, optional helper) — show VPN/build/meeting states when relevant. Opt-in, never default chrome.

### 11.7 Amphetamine
- **Positioning:** Keep-awake.
- **User job:** "Don't sleep during my compile/upload/meeting."
- **Why it wins:** Free, conditional triggers.
- **Hive counter-move:** **Focus Sessions** with bounded awake leases (WELL-001) — tied to explicit tasks, revocable on battery/thermal, visible expiration.

### 11.8 HazeOver
- **Positioning:** Focus dimming.
- **User job:** "Dim everything but the active window."
- **Why it wins:** Instant visual hierarchy.
- **Hive counter-move:** Focus dimming as a Focus Session companion — the browser dims background chrome during deep work.

### 11.9 BetterTouchTool / 11.10 Karabiner
- **Positioning:** Gesture/macro power tools / keyboard remapping.
- **User job:** "Make my hardware obey my reflexes."
- **Why they win:** Unmatched depth.
- **Weaknesses:** Deep learning curve; single-purpose.
- **Hive counter-move:** Hive's command center accepts user-defined commands/snippets (CMD-001) but does not chase BTT/Karabiner depth — that's a power-user niche Hive coexists with, then absorbs via presets.

### 11.11 Utility synthesis
Every utility above solves one fragment of "make my Mac conform to my flow." Hive's answer is **context**: the command center that knows your work, layouts tied to projects, awake leases tied to tasks. Fragments merge when they share context.

---

## §12 — READING & BOOKMARKS (8 apps)

### 12.1 Pocket (Mozilla) — **SHUT DOWN July 2025**
- **Positioning:** The original save-for-later.
- **User job:** "Save it now, read it later, without losing it."
- **Why it won:** One-click save, clean reading view.
- **Why it died:** Stagnation, recommendation bloat, weak search, Mozilla deprioritization.
- **Lesson for Hive:** The category is up for grabs. The leader died. **The save button must be native, and the saved article must be searchable by full text + meaning.** Hive ships this in Phase A (wisp capture → Honeycomb Source).

### 12.2 Instapaper
- **Positioning:** Typography-first read-later.
- **User job:** Pure distraction-free reading.
- **Why it wins:** Minimalism.
- **Weaknesses:** Price doubled (2024) with no new features; no AI; slow development.
- **Hive counter-move:** Reader mode is already native (SPEC.md). Reading list already ships. The differentiator: every saved article auto-extracts claims into Honeycomb.

### 12.3 Raindrop.io
- **Positioning:** Visual bookmark manager.
- **User job:** "Organize bookmarks beautifully with full-text save."
- **Why it wins:** Generous free tier, unlimited highlighting, visual collections.
- **Weaknesses:** No offline reading; no RSS/newsletter ingestion.
- **Hive counter-move:** Hive bookmarks ARE the browser's bookmarks — plus full-text + highlights + memory. The browser-native advantage: no extension, no sync service, no second place to look.

### 12.4 Readwise / 12.5 Reader
- **Positioning:** The highlight-and-resurface gold standard ($120/yr).
- **User job:** "Turn consumption into retained knowledge — resurface what I highlighted."
- **Why it wins:** Omnichannel ingestion (articles, EPUB, PDF, RSS, newsletters, YouTube, X threads), gold-standard highlighting, spaced-repetition resurfacing, Ghostreader AI.
- **Weaknesses:** No free tier, steep price, steep learning curve, middleman architecture (highlights must export to Obsidian/Notion).
- **Hive counter-move:** **This is Hive's core.** Every page read → Source node; every highlight → Claim node with spans; resurfacing in the new-tab interstitial + daily digest; Ghostreader → on-device Q&A Cells with citations to real source objects. Readwise's whole architecture (middleman sync) becomes unnecessary — the graph is native.

### 12.6 Matter / 12.7 Omnivore (dead) / 12.8 Wallabag
- **Positioning:** Design-conscious mobile reading / open-source read-later (dead) / self-hosted read-later.
- **User job:** The same save-and-read job, variously executed.
- **Why they win:** Design (Matter), open source (Omnivore/Wallabag).
- **Weaknesses:** Omnivore acquired-and-killed (ElevenLabs, Nov 2024) — an industry warning about VC acqui-hires; Matter paywalls highlights; Wallabag's utilitarian UI.
- **Hive counter-move:** The market is volatile — leaders die, prices double. A browser-native memory-first reader is structurally immune: no separate company, no separate subscription, no data-migration cliff.

### 12.9 Reading user-job synthesis (three jobs)
1. **Anxiety relief** ("I won't lose it") → native save, guaranteed
2. **Triage airlock** ("later, not now") → reading list + digest
3. **Synthesis** ("make it stick") → highlights → Claims → spaced repetition → Briefs

---

## §13 — TAB MANAGEMENT (8 apps)

### 13.1 OneTab / 13.2 Toby / 13.3 Tablerone / 13.4 Session Buddy / 13.5 Workona
- **Positioning:** Tab collapse / visual boards / session manager / crash recovery / project workspaces.
- **User job:** Kill RAM and clutter (OneTab); organize research (Toby); save sessions with previews (Tablerone); survive crashes (Session Buddy); isolate projects (Workona).
- **Why they win:** Each patches one failure of native tabs.
- **Why they all churn:** Manual organization tax; the "graveyard" anti-pattern (finding a tab in a 500-item list is slower than re-searching); cross-browser silos; native convergence.
- **Hive counter-move:** Hive already ships hibernation, session persistence, spaces, split view, and command palette. The missing piece (Phase C): **auto-archiving** — tabs that age past a threshold collapse into a searchable session automatically. No extension, no manual naming, crash-proof by design.

### 13.6 Chrome tab groups / 13.7 Safari tab groups / 13.8 Arc spaces
- **Positioning:** Native grouping / iCloud-synced groups / browser-as-OS spaces.
- **User job:** Context separation.
- **Why they win:** Native; no install.
- **Weaknesses:** Chrome groups die on crash; Safari groups rigid; Arc entered maintenance mode (2025) — its *spaces* paradigm is now an open opportunity.
- **Hive counter-move:** Hive Spaces = Arc's spaces done persistently and Memory-aware: each space has its own tab set, session, and research trail, and the context broker keeps them isolated. Auto-archive + research trails (A4) make spaces self-organizing.

### 13.9 Tab-management synthesis
The meta-lesson: **manual tab organization is a tax users stop paying.** The browser must organize automatically (semantic tab threading, auto-archive, crash-proof state) — which is exactly what the wisp/capture + research-trail architecture enables.

---

## §14 — LOCAL AI (7 tools)

### 14.1 Ollama / 14.2 LM Studio / 14.3 Jan / 14.4 GPT4All / 14.5 Msty / 14.6 LocalAI
- **Positioning:** Local model runtimes and GUIs.
- **User job:** Private, offline, low-cost AI.
- **Why they win:** Privacy, offline resilience, cost predictability, no token fatigue.
- **Weaknesses:** Manual model management; Linux GUI gap (Ollama); closed source (LM Studio); hardware floors; model-repo confusion for beginners.
- **Hive counter-move:** **Hive Models** — a browser-embedded model manager (ModelStore already in HiveCore): resolve → download on first use → cache → route by role with honest provider labels. The Cells roster (ModelManifest, 19 roles) defines exactly which model serves which job, so users never choose models — Hive does, and shows its work.

### 14.7 Apple Foundation Models
- **Positioning:** Apple's on-device/Private Cloud Compute stack.
- **User job:** OS-native AI with strong privacy.
- **Why it wins:** Silicon integration, E2EE private cloud.
- **Weaknesses:** Hardware gatekeeping, long downloads, limited customization.
- **Hive counter-move:** Hive routes through FMF for six narrow low-risk roles (already coded in ProviderPolicy) and MLX for high-trust roles. FMF is a runtime, not a strategy; Hive's strategy is the manifest.

### 14.8 Local-AI synthesis
The user job is **capability without compromise** — private, offline, affordable, and good enough. Hive's Cells turn local AI from a hobby (which model today?) into a utility (the job gets done, honestly labeled). The dispatcher fallback order (MLX → FMF → honest mock) already encodes this.

---

## §15 — SEARCH (7 engines)

### 15.1 Google
- **Positioning:** The ad-funded search monopoly.
- **User job:** Find, verify, synthesize (mostly "find").
- **Why it wins:** Index scale, habit, default.
- **Weaknesses:** Declining quality (SEO spam), AI Overview hallucinations, CTR cannibalization (34–61% drops), antitrust verdict, publisher lawsuits.
- **Hive counter-move:** Hive Search = **personal-first hybrid retrieval**: local memory (what you've seen/read) + live web (Brave-class API) + AI synthesis with citations to real Source objects. "Find what I saw Tuesday" is impossible on Google and native to Hive.

### 15.2 Bing/Copilot
- **Positioning:** Microsoft's index + OpenAI models.
- **User job:** Search + task execution.
- **Why it wins:** Enterprise bundling.
- **Weaknesses:** Upsell aggression, interface bloat.
- **Hive counter-move:** No counter needed; Hive uses best-index APIs behind a privacy boundary.

### 15.3 Brave Search
- **Positioning:** Independent index, zero-logging, agentic API leader (Agent Score 14.89, ~669ms).
- **User job:** Private search + agent-grade API.
- **Why it wins:** Independence + privacy + speed.
- **Weaknesses:** Niche local/entity coverage.
- **Hive counter-move:** **Partner, not fight.** Brave-class search as Hive's default provider (SWARM-002), wrapped in Hive's memory-first retrieval and citation pipeline.

### 15.4 Kagi
- **Positioning:** Paid, ad-free search ($10/mo).
- **User job:** Quality search without surveillance.
- **Why it wins:** Lenses, domain controls, quality.
- **Weaknesses:** Price barrier.
- **Hive counter-move:** Hive delivers Kagi-class control (user-downrank domains, lenses) natively — without the separate subscription, because search is a browser function.

### 15.5 Perplexity
- **Positioning:** Conversational answer engine.
- **User job:** Synthesize an answer with sources.
- **Why it wins:** Best-in-class synthesis UX.
- **Weaknesses:** Latency (11s+ APIs), hallucinated citations, publisher lawsuits.
- **Hive counter-move:** Swarm research (already real: Tavily/Vane providers, SourceFetcher, ClaimExtractor, CitationFormatter) with **citations that resolve to stored Source objects** — the exact thing Perplexity cannot prove (AGENTS.md §11.1).

### 15.6 Arc Search
- **Positioning:** "Browse for Me" agentic search.
- **User job:** Skip the click-through; get the digest.
- **Why it wins:** Novelty + aggregation.
- **Weaknesses:** Parsing messiness; Arc in maintenance.
- **Hive counter-move:** Browse-for-me as a Swarm research session over the user's actual memory + live sources.

### 15.7 Search synthesis (three JTBD)
1. Find → hybrid index (memory + web)
2. Verify → real citations + source quality scores
3. Synthesize → grounded briefs, not link lists
Google optimized 1 and abandoned 2–3. Perplexity automated 3 and faked 2. Hive does all three with provenance.

---

## §16 — NOTES & DOCUMENTS (10 apps)

### 16.1 Apple Notes / 16.2 Google Docs
- **Positioning:** Default capture (Notes) / collaborative writing (Docs).
- **User job:** Quick capture; real-time document collaboration.
- **Why they win:** Zero-setup defaults; collaboration.
- **Weaknesses:** Notes: weak formatting/cross-platform. Docs: cloud-only, privacy, cluttered UI.
- **Hive counter-move:** Hive Notes = capture from anywhere in the browser (selection → note → Honeycomb), plus Docs-class collaboration later via local-first sync. The wedge: Hive notes are linked to what you were reading.

### 16.3 Bear / 16.4 Ulysses
- **Positioning:** Markdown-first writing (Bear) / long-form publishing (Ulysses).
- **User job:** Distraction-free writing with beautiful type.
- **Why they win:** Craft.
- **Weaknesses:** Apple-only; subscription (Ulysses).
- **Hive counter-move:** Hive Writer (P2 Studio) with Markdown + publishing targets; the memory layer auto-links sources to drafts.

### 16.5 Craft / 16.6 Anytype / 16.7 Standard Notes
- **Positioning:** Block docs / local-first object graphs / E2EE notes.
- **User job:** Beautiful blocks (Craft); own-your-graph (Anytype); encrypted notes (Standard Notes).
- **Why they win:** Design, local-first architecture, encryption.
- **Weaknesses:** Free-tier limits; learning curves; niche communities.
- **Hive counter-move:** Honeycomb IS the Anytype-style local object graph — with a browser's distribution and a Cells-powered brain on top.

### 16.8 Obsidian
- **Positioning:** Plain-text markdown vault + graph + plugins.
- **User job:** Own your notes as files; link ideas; see the graph.
- **Why it wins:** Files you own, backlinks, plugin ecosystem, offline.
- **Weaknesses:** BYO-sync friction, plugin sprawl, steep setup, no native memory of *what you read on the web*.
- **Hive counter-move:** Hive Wiki (already ships: WikiStore + backlinks + graph browser) with one decisive upgrade: **captures auto-enter the vault**. Obsidian starts empty and stays empty unless you file; Hive fills itself from browsing (Phase A).

### 16.9 Notion
- **Positioning:** All-in-one workspace (docs + databases).
- **User job:** Structured project knowledge with databases.
- **Why it wins:** The page+property+view primitive; templates; team adoption.
- **Weaknesses:** Cloud-only, slow at scale, poor offline, AI add-on tax.
- **Hive counter-move:** Hive Projects/Sheets/Views over Honeycomb objects (DEC-009) — same primitive, local-first, memory-aware. The killer difference: Notion databases need manual entry; Hive databases fill themselves from captured browsing.

### 16.10 Notes synthesis (four JTBD)
1. Capture → zero-friction, context-linked
2. Organize → fluid structure, not archive fatigue
3. Retrieve → semantic + backlinks
4. Write → synthesis with source grounding
**Every incumbent fails at least one. Hive's structure (one graph for browsing + notes) makes capture and retrieval native to the act of working.**

---

## §17 — ENTERPRISE SAAS (10 platforms)

### 17.1 Salesforce
- **Positioning:** Cloud CRM inventor, GTM system of record.
- **User job:** Model any sales org: accounts, contacts, deals, territories.
- **Why it wins:** Data model depth, 5,000+ AppExchange apps, MuleSoft, admin ecosystem.
- **Weaknesses:** Complexity creep ("Frankenstein" orgs), admin dependency ($80–150k/yr admins), rep UX fatigue.
- **Hive lesson:** Structured relational objects matter, but configuration must be fluid inline editing, not admin screens. Hive's counter: personal CRM as a Sheet + memory over captured email/meeting context.

### 17.2 HubSpot
- **Positioning:** SMB GTM standard.
- **User job:** Marketing+sales+service on one contact DB without engineers.
- **Why it wins:** Usable product, inbound philosophy, free tier.
- **Weaknesses:** Price escalation at Pro/Enterprise; feature gating.
- **Hive lesson:** Consumer-grade onboarding + immediate time-to-value. Hive's counter: same job, local-first, from the browser where the work already happens.

### 17.3 Zoho
- **Positioning:** 50+ apps in one suite.
- **User job:** One vendor for everything.
- **Why it wins:** Breadth + native internal integration.
- **Weaknesses:** Per-app polish gaps; setup cohesion cost.
- **Hive lesson:** The all-in-one instinct is validated — but breadth without a shared memory layer is just sprawl. Hive's breadth shares one object graph (DEC-009).

### 17.4 Monday.com / 17.5 Airtable
- **Positioning:** Work OS / spreadsheet-database hybrid.
- **User job:** Visual project workflows; relational data with spreadsheet familiarity.
- **Why they win:** Board/widget flexibility; field-type + multi-view power.
- **Weaknesses:** Shallow depth beyond niche; record limits + seat pricing at scale.
- **Hive lesson:** The table-database hybrid is the power-user primitive. Hive Sheets (SHEET-001) must ship typed columns, views, formulas, and source-backed rows.

### 17.6 ServiceNow / 17.7 Workday / 17.8 SAP / 17.9 Oracle
- **Positioning:** ITSM platform / HCM+Finance / ERP / ERP+DB.
- **User job:** Enterprise governance, compliance, transactional integrity.
- **Why they win:** Object-model depth, audit trails, regulatory fit, integration ecosystems.
- **Weaknesses:** Six-to-seven-figure licenses, mandatory consultants, multi-month rollouts, rigid frameworks, hostile UX.
- **Hive lesson:** Hive never competes here directly. But the architecture lessons transfer: **one object model** (Workday unifies people+finance), **audit trails** (EventLedger), **governed workflows** (action ladder). Hive's enterprise story is the memory layer above these systems, not a replacement.

### 17.10 Atlassian
- **Positioning:** Jira+Confluence+Bitbucket: dev workflow standard.
- **User job:** Where work is discussed (docs), tracked (issues), and built (code) — tightly linked.
- **Why it wins:** The dev-workflow triad, marketplace.
- **Weaknesses:** "Jira ticket hell," cloud migration pain, config sprawl.
- **Hive lesson:** The triad is exactly Hive's Studio thesis: project briefs (docs) ↔ tasks (issues) ↔ code runs — one graph. Hive's version has no ticket-hell because tasks derive from real work (captures, briefs, promises) instead of being created as bureaucratic overhead.

---

## §18 — DEVELOPER PLATFORMS (6 platforms)

### 18.1 GitHub
- **Positioning:** The social coding platform + contribution graph.
- **User job:** Host code, collaborate, signal credibility.
- **Why it wins:** Network effects, social coding, the green-squares habit loop, Copilot integration.
- **Weaknesses:** Microsoft dependence debates; contribution-graph gaming; discoverability.
- **Hive lesson:** The contribution graph is a *motivation technology* — visible, consistent effort tracking. Hive's digest and memory graphs are the same technology applied to life: "3 research trails active, 2 promises kept, 14 captures today."

### 18.2 GitLab / 18.3 Bitbucket
- **Positioning:** Integrated DevOps / Atlassian's Git.
- **User job:** CI/CD + repo management in one place.
- **Why they win:** Single-vendor pipelines.
- **Weaknesses:** Complexity; integration lock-in.
- **Hive lesson:** Hive Studio must be git-aware (rollback via patch/backup per AGENTS.md §11.2) but provider-agnostic.

### 18.4 Stripe
- **Positioning:** The developer-beloved payments API.
- **User job:** "Take payments without payment-infrastructure pain."
- **Why it wins:** **Developer experience as product**: clean docs, typed SDKs, predictable API, great DX.
- **Hive lesson:** Stripe proves beloved-tool economics: the best developer experience wins regardless of incumbency. Hive's Cells, Studio, and MCP server must meet the same bar — typed contracts, honest labels, testable behavior.

### 18.5 Shopify
- **Positioning:** The merchant standard.
- **User job:** "Run a store without building infrastructure."
- **Why it wins:** Merchant trust, ecosystem, turnkey operations.
- **Weaknesses:** Transaction fees, app subscription creep.
- **Hive lesson:** The merchant job is research+decisions+fulfillment — Hive's commerce memory (product research trails, price tracking, supplier pages) is a wedge *before* store-building.

### 18.6 Vercel / Netlify
- **Positioning:** Deployment DX.
- **User job:** "Ship a site with zero ops."
- **Why they win:** Git-push-to-deploy magic.
- **Hive lesson:** Deployment is a Studio action flow: preview → approve → deploy → EventLedger record. The browser-native studio ships the same magic with audit.

---

## §19 — MEDIA & ENTERTAINMENT (8 platforms)

### 19.1 Spotify
- **Positioning:** The audio ecosystem (music+podcasts+audiobooks).
- **User job:** Personal audio with perfect discovery.
- **Why it wins:** Discovery flywheel (Discover Weekly, AI DJ), 184-country reach.
- **Weaknesses:** Price hikes, interface bloat, artist payout politics.
- **Hive lesson:** Recommendation is the moat — but Hive's recommendation runs over the user's *entire* digital life, not just one catalog. "You liked this track while reading X" is a Hive-level memory no streamer has.

### 19.2 Apple Music / 19.3 YouTube / 19.4 Netflix / 19.5 Twitch / 19.6 TikTok-class short video
- **Positioning:** Fidelity/ecosystem music; the video monopoly; SVOD scale; live community; attention feeds.
- **User job:** Listen, watch, discover, connect, be entertained.
- **Why they win:** Catalogs, recommendations, network effects, cultural gravity.
- **Weaknesses:** Price segmentation, ad aggression, recommendation rabbit holes, content saturation.
- **Hive lesson:** Hive doesn't replace streaming. Hive **organizes the seams**: Watch Later with context, media memory ("that clip from the talk you watched Tuesday"), and cross-platform queues. Plex/Jellyfin's local-library job becomes "your media, your recommendations, no cloud auth wall."

### 19.7 Plex / 19.8 Jellyfin
- **Positioning:** Local media servers.
- **User job:** Own + stream your library.
- **Why they win:** Sovereignty.
- **Weaknesses:** Plex commercialization + cloud-auth dependency; Jellyfin learning curve.
- **Hive counter-move:** Hive Media Browser (P3+): local libraries as Honeycomb media nodes with local embedding recommendations — Jellyfin sovereignty with consumer polish.

---

## §20 — AUTOMATION (9 tools)

### 20.1 Apple Shortcuts / 20.2 HomeKit / 20.3 Home Assistant
- **Positioning:** Visual personal automation / local smart home / power-user home hub.
- **User job:** Automate repetitive personal and home tasks.
- **Why they win:** Free + Apple integration; local privacy (HomeKit/HA).
- **Weaknesses:** Fragile background execution (Shortcuts); YAML learning curve (HA); opaque automation code.
- **Hive counter-move:** Hive Flows (P2, versioned flow model) as the typed automation layer: browser actions + local files + connectors with EventLedger audit. "Flows," not "shortcuts" — durable, replayable, reversible.

### 20.4 IFTTT / 20.5 Zapier / 20.6 Make / 20.7 n8n
- **Positioning:** Consumer glue / enterprise SaaS pipelines / visual canvas / developer workflows.
- **User job:** Connect apps without code.
- **Why they win:** Integration breadth; reliability at enterprise tier.
- **Weaknesses:** Zapier's punitive task pricing (every step burns a task); IFTTT's stripped logic + delays; Make/n8n learning curves; all are *blind* — they don't know your context.
- **Hive counter-move:** Hive Flows know the user's actual context (current project, active research, memory). A flow that triggers on "when I finish researching X" is impossible in Zapier and native to Hive.

### 20.8 Selenium/Playwright/Puppeteer / 20.9 Browser agents (Operator, Perplexity Computer)
- **Positioning:** Programmatic browser automation / natural-language computer use.
- **User job:** Automate web tasks deterministically (frameworks) or by description (agents).
- **Why they win:** Power (frameworks); accessibility (agents).
- **Weaknesses:** Frameworks break on DOM change (flaky selectors); agents are slow, unreliable, and risky with credentials.
- **Hive counter-move:** Hive's action ladder (SWARM-004): **typed actions over DOM+API with semantic anchors** — deterministic by default, LLM only on anomalies, permission-gated, audit-logged. The computer-use layer (PC-001) adds scoped OS observation. This is the anti-Operator: fast, reversible, and never credential-exposed.

### 20.10 Automation synthesis
The user job is **"make my repetitive work disappear without creating new risk."** Zapier solves connectivity but not intelligence; browser agents solve intelligence but not reliability. Hive's typed-action + EventLedger + approval-center stack is the only architecture that solves all three.

---

## §21 — AI CHAT ASSISTANTS (4 apps)

### 21.1 ChatGPT
- **Positioning:** The dominant AI assistant app (multi-model, Canvas, Projects, GPT Store).
- **User job:** "Have an AI that remembers me, does my work, and produces artifacts — without me re-explaining everything."
- **Why it wins:** Brand + capability lead; global memory; Canvas artifacts; voice mode.
- **Weaknesses:** Memory becomes stale/bloated; automatic memory feels intrusive; rate limits; walled garden (remembers you only in ChatGPT).
- **Monetization:** Free / Plus $20 / Pro $200.
- **Hive counter-move:** Swarm panel with the same artifact capability — but memory is **local and unified** across every provider. "ChatGPT remembers you in ChatGPT; Hive remembers you everywhere."

### 21.2 Claude
- **Positioning:** The writing/coding-quality assistant (Projects, Artifacts, Skills).
- **User job:** Same assistant job with higher-quality prose and project-scoped context.
- **Why it wins:** Projects = persistent instructions + knowledge base (the gold standard for scoped context); artifact quality.
- **Weaknesses:** No automatic cross-chat memory; message caps on heavy models; no native image generation.
- **Monetization:** Free / Pro $20 / Max $100+.
- **Hive counter-move:** Claude's Projects lesson (persistent instructions + knowledge base) is Hive's Projects primitive natively — with automatic context from the user's actual browsing instead of manual uploads.

### 21.3 Gemini
- **Positioning:** Google's assistant with Workspace hooks (Deep Research, Live, NotebookLM).
- **User job:** Assistant work fused with my Google files.
- **Why it wins:** Native Gmail/Docs/Drive access; Deep Research; NotebookLM's source-grounded notebooks.
- **Weaknesses:** Tone default; fragmented naming (Gems vs Notebooks); Workspace lock-in; data flows to Google.
- **Monetization:** Free / ~$19.99/mo Advanced.
- **Hive counter-move:** NotebookLM's insight — source-grounded Q&A over *your* corpus — is Hive's core research contract (SWARM-002), grounded over Honeycomb Sources instead of uploaded PDFs.

### 21.4 Assistant synthesis
- **The user job is context offloading + artifact production.** Standalone apps are walled gardens: you must copy-paste pages, upload files, re-explain context. A browser-embedded assistant has ambient awareness of the active tab, the error on screen, the research trail — and its memory is a **vendor-independent context bus** that routes prompts to whichever frontier model wins today. That is the four-way edge (context, memory, action, cost) no standalone app can replicate.

---

## §22 — CODE EDITORS & TERMINALS (9 apps)

### 22.1 VS Code
- **Positioning:** The extensible default editor (Electron/TS, 100k+ extensions).
- **User job:** "Edit any codebase with my whole plugin stack and AI copilot."
- **Why it wins:** Extension ecosystem, remote dev (SSH/WSL/DevContainers), Copilot integration.
- **Weaknesses:** ~3.5GB RAM, startup latency, helper-process sprawl, Copilot usage-based billing.
- **Hive counter-move:** Hive Studio's editor covers the 80% case (edit → plan/diff/test/review) with the browser-native advantage: it already sees the docs, issues, and research that led to the code.

### 22.2 JetBrains / 22.3 Sublime Text / 22.4 Neovim / 22.5 Zed
- **Positioning:** Deep language-aware IDEs / fast C++ editor / modal keyboard editor / Rust speed-first editor.
- **User job:** Semantic power (JetBrains); raw speed (Sublime); typing velocity (Neovim); native-fast AI collaboration (Zed).
- **Why they win:** Depth; minimalism; modal muscle memory; 2ms latency + 220MB (Zed).
- **Weaknesses:** RAM/indexing (JetBrains); AI stagnation (Sublime); config rot (Neovim); small ecosystem (Zed).
- **Hive lesson:** Zed proves **performance is a feature**: DOM/Electron bloat is a structural tax. Hive's studio must be lean and native-feeling; the memory layer (repo grokking, issue-to-code links) is the compounding edge no editor has.

### 22.6 iTerm2 / 22.7 Warp / 22.8 Ghostty / 22.9 Alacritty
- **Positioning:** Feature-rich macOS terminal / AI-native Rust terminal / GPU-accelerated Zig terminal / minimalist GPU terminal.
- **User job:** Run commands with speed and workflow ergonomics.
- **Why they win:** Triggers/tmux-CC (iTerm2); AI + blocks (Warp); 3x throughput (Ghostty); purity (Alacritty).
- **Weaknesses:** iTerm2 memory; Warp cloud/telemetry + subscription; Ghostty lacks legacy features.
- **Hive counter-move:** Studio's bounded project runner (STUDIO-002) is the *governed* terminal: every command typed, logged, and reversible — the anti-Warp (no telemetry, no subscription) with EventLedger audit.

---

## §23 — RSS & NEWS READERS (7 apps)

### 23.1 Feedly / 23.2 Inoreader / 23.3 NetNewsWire / 23.4 Miniflux / 23.5 NewsBlur
- **Positioning:** Cloud feed readers (Feedly Leo AI; Inoreader rules; NetNewsWire native; Miniflux self-hosted; NewsBlur intelligence training).
- **User job:** "Stay precisely informed on my domains without drowning in noise or surveillance."
- **Why they win:** Aggregation + filtering + (Feedly) AI summaries; NetNewsWire's free native polish; Miniflux's privacy.
- **Weaknesses:** Feedly's aggressive upsell (Leo behind $12.99); Inoreader's dense UI; NetNewsWire Apple-only; Miniflux sparse; NewsBlur dated.
- **Hive counter-move:** RSS is a **feed Cell** in Hive: every feed item is a Source candidate; dedupe/cluster cross-posts into one timeline card; AI summaries on-device; highlights auto-extract into Honeycomb. The RSS resurgence (post-Google-Reader, post-enshittification) is Hive's ingestion moat.

### 23.6 Apple News / 23.7 Flipboard
- **Positioning:** Curated mainstream news / social magazine.
- **User job:** Passive high-production news consumption.
- **Why they win:** Editorial curation; visual discovery.
- **Weaknesses:** Closed ecosystems; no RSS; engagement-optimized feeds.
- **Hive counter-move:** Hive's morning digest replaces the passive news scroll with a **synthesis** of what matters to the user's projects — from feeds the user controls.

### 23.8 RSS synthesis (four sub-jobs)
1. Ingestion (the pipe) → feed Cells
2. Filtering (the sieve) → intent classifiers + dedupe clustering
3. Comprehension (the accelerator) → on-device summaries
4. Action/archiving (the memory) → sources + highlights into Honeycomb

---

## §24 — CLIPBOARD & SCREEN CAPTURE (7 apps)

### 24.1 Maccy / 24.2 Paste / 24.3 CleanShot X / 24.4 Loom / 24.5 ScreenFlow / 24.6 Snagit / 24.7 Skitch
- **Positioning:** Clipboard history / visual clipboard + sync / screenshot suite / async video messages / pro screencasting / doc capture + annotation / quick markup.
- **User job:** "Reuse what I copied, capture what I see, and communicate visually without friction."
- **Why they win:** Keyboard-first clipboard (Maccy); iCloud paste (Paste); scrolling capture + OCR + cloud (CleanShot X); async video (Loom); tutorial-grade capture (ScreenFlow/Snagit).
- **Weaknesses:** Subscription fatigue for a clipboard; CleanShot renewal model; Loom's 5-min free cap + Atlassian price jumps; Skitch abandoned; per-tool fragmentation.
- **Hive counter-move:** **Hive Capture** — screenshots, clips, and clips-to-memory are browser commands; annotations are typed edits; recordings land in Honeycomb as media artifacts; Loom-class sharing links generated locally. The wisp pipeline (Phase A) already captures the *page text*; capture module adds the pixels.

---

## §25 — CLOUD STORAGE & FILE MANAGEMENT (9 apps)

### 25.1 Dropbox / 25.2 iCloud Drive / 25.3 Google Drive / 25.4 OneDrive / 25.5 Sync.com / 25.6 Nextcloud
- **Positioning:** Sync folders / OS-ecosystem storage / web-first docs / Windows-bundled / zero-knowledge cloud / self-hosted sovereignty.
- **User job:** "My files everywhere, synced, shared, safe."
- **Why they win:** Dropbox invented the sync folder; iCloud is invisible on Apple; Google bundles; OneDrive ships with Windows; Sync.com zero-knowledge; Nextcloud sovereignty.
- **Weaknesses:** Tiny free tiers everywhere (2–15GB); no zero-knowledge at the majors; price hikes; desktop daemon bloat (Dropbox); forced folder redirect (OneDrive); setup overhead (Nextcloud).
- **Hive counter-move:** Hive is **local-first** (DEC-004): the working set lives on the Mac; cloud is an optional encrypted sync target (SQLCipher at rest, A6). Connectors read from Drive/Dropbox/OneDrive without making the browser the storage vendor.

### 25.7 Forklift / 25.8 Path Finder / 25.9 Commander One
- **Positioning:** Dual-pane file managers for power users.
- **User job:** "Manage files with keyboard speed and remote mounts."
- **Why they win:** SFTP/S3/WebDAV connections, dual-pane workflow.
- **Weaknesses:** Subscription creep; Finder-depth fights.
- **Hive counter-move:** Studio's project file browser covers the code-adjacent job; the command center adds "open in Finder/terminal" fast paths. Hive doesn't replace Finder — it replaces the *context switching* around files.

---

## §26 — TASK, HABIT & FOCUS APPS (9 apps)

### 26.1 Todoist / 26.2 TickTick / 26.3 Things 3
- **Positioning:** Cross-platform task capture / all-in-one tasks+calendar+habits / Apple-native beauty.
- **User job:** "Capture every commitment and trust a system to surface what matters today."
- **Why they win:** Natural-language capture (Todoist); habit+calendar fusion (TickTick); Things' Quick Entry and Today view.
- **Weaknesses:** Manual entry burden; subscription fatigue; context-blind (tasks don't know what you were working on).
- **Hive counter-move:** Hive tasks are **born from work**: captures, promises (A3), briefs, and meeting actions create tasks automatically. The Today view is the digest. Manual entry is the fallback, not the norm.

### 26.4 Habitica / 26.5 Streaks
- **Positioning:** RPG habit tracking / iOS streak tracker.
- **User job:** "Make habit-building feel like a game."
- **Why they win:** Gamification that works (Habitica parties, Streaks' simplicity).
- **Weaknesses:** Novelty decay; effort tax.
- **Hive counter-move:** Intrinsic gamification in the digest — approval loops and gentle streaks without punishment mechanics (WELL-002 principle).

### 26.6 Forest / 26.7 Freedom / 26.8 Cold Turkey / 26.9 Opal
- **Positioning:** Focus/blocking apps (plant-a-tree, cross-device blocking, deep-blocker, iOS screentime).
- **User job:** "Stop me from distracting myself."
- **Why they win:** Simple, effective, cross-device blocking.
- **Weaknesses:** Blocking is blunt — it doesn't understand *why* you're distracted; subscription stacks.
- **Hive counter-move:** **Focus Sessions** (WELL-001) with awake leases tied to real tasks; the browser's own tab/digest surfaces manage distraction from within the context that causes it.

---

## §27 — SHOPPING & TRAVEL (7 apps)

### 27.1 Honey / 27.2 Rakuten / 27.3 Capital One Shopping
- **Positioning:** Coupon finder / cashback portal / price comparison.
- **User job:** "Never overpay, and get money back automatically."
- **Why they win:** Automatic coupon testing; cashback; price-drop alerts.
- **Weaknesses:** Affiliate-link hijacking (class actions); locked gift-card rewards; payout delay; aggressive tracking + notification spam; credits illiquidity.
- **Hive counter-move:** **Hive Price Memory** — local price history per product from pages you actually visit; drop alerts in the digest; ethical attribution (preserve creator links by default). No data-broker monetization.

### 27.4 TripIt / 27.5 Hopper / 27.6 Kayak / 27.7 Airbnb
- **Positioning:** Itinerary parsing / price prediction + freezing / meta-search / lodging marketplace.
- **User job:** "Plan a trip without losing my mind across emails and sites; don't overpay."
- **Why they win:** Email-to-itinerary (TripIt); price-freeze (Hopper); aggregation (Kayak).
- **Weaknesses:** Pro paywalls; hidden fees; drip pricing (Airbnb cleaning fees); service bottlenecks.
- **Hive counter-move:** Trip planning is a **research trail** (A4): the browser already saw the flights, the hotel, the neighborhood, the reviews. Itinerary extraction from confirmation pages (like the order-confirmation wisp) builds the trip object — with price history from the same trail. The memory version of TripIt that TripIt cannot build.

---

## §28 — WEATHER & AMBIENT BRIEFING (5 apps)

### 28.1 CARROT Weather / 28.2 Dark Sky (killed by Apple) / 28.3 Apple Weather / 28.4 AccuWeather / 28.5 Windy
- **Positioning:** Snarky hyperlocal / minute-precision pioneer / native WeatherKit / data-dense global / pro visualization.
- **User job:** Three jobs: tactical defense (what do I wear), scheduling logistics (can I ride at 3pm), anxiety reduction (is that storm serious).
- **Why they win:** Personality (CARROT); Dark Sky's 7-minute rain precision (now baked into Apple Weather via WeatherKit); depth (Windy).
- **Weaknesses:** Feature paywalling; widget fatigue; no task correlation — no weather app knows your outdoor task conflicts with the rain window.
- **Hive counter-move:** The **morning digest** (A5) synthesizes weather × calendar × tasks × memory: "Rain at 9 — your bike ride task conflicts; I moved it to tomorrow." Weather is a variable constraint on human activity; Hive is the only layer that sees both the forecast and the schedule.

---

## §29 — MAC SYSTEM UTILITIES (6 apps)

### 29.1 CleanMyMac X / 29.2 DaisyDisk / 29.3 iStat Menus / 29.4 AppCleaner / 29.5 OmniDiskSweeper / 29.6 Setapp
- **Positioning:** All-in-one cleanup / disk map / menu-bar monitoring / clean uninstall / surgical size audit / the all-you-can-eat Mac subscription.
- **User job:** "Keep my Mac fast, clean, and visible — without thinking about maintenance."
- **Why they win:** One-click scans (CleanMyMac); beautiful disk maps (DaisyDisk); live telemetry (iStat); deep uninstalls (AppCleaner).
- **Weaknesses:** Duplicate native functions; price; blind one-click flagging; per-tool fragmentation.
- **Hive counter-move:** The browser's **memory pressure manager** is the first system-health surface that matters (tabs + hibernation = RAM). A system-health dashboard (CPU/RAM/disk) in the command center with Safe Cleanup — the CleanMyMac job done natively, and only when it can be *reversible*.
- **Setapp lesson (pricing):** Bundling beats per-tool resistance; anchor tools (CleanMyMac/Ulysses/CleanShot) drive adoption of peripheral modules; unified licensing raises churn cost; offer both all-inclusive and à-la-carte. This is exactly Hive's suite model — the anchor is the browser itself.

---

## §30 — SOCIAL MEDIA MANAGEMENT (6 apps)

### 30.1 Buffer / 30.2 Hootsuite / 30.3 Later / 30.4 Sprout Social / 30.5 TweetDeck/X Pro / 30.6 Typefully
- **Positioning:** Scheduling + analytics across platforms.
- **User job:** "Post consistently everywhere without living in every app."
- **Why they win:** Cross-platform scheduling, calendars, analytics, AI caption help.
- **Weaknesses:** Per-seat SaaS costs; shallow analytics without enterprise tiers; content is managed but the *ideas* behind content live elsewhere (drafts, notes, memory).
- **Hive counter-move:** Publishing is a **Flow** (P2): the draft lives in Hive Writer with sources; the caption is written by Cells with brand voice; scheduling is a calendar action; analytics feed back into the content memory. The management layer inherits the creative context that Buffer never sees.

---

## §31 — PODCASTS & AUDIO (4 apps)

### 31.1 Overcast / 31.2 Pocket Casts / 31.3 Apple Podcasts / 31.4 Audible
- **Positioning:** Smart-speed podcast player / cross-platform player / default Apple player / audiobook subscription.
- **User job:** "Never miss my shows; listen with smart speed; keep my place everywhere."
- **Why they win:** Smart Speed + Voice Boost (Overcast); cross-platform queues (Pocket Casts); default ubiquity (Apple); the audiobook catalog (Audible).
- **Weaknesses:** Subscription stacks; episode backlog anxiety; no memory of *what you learned* from an episode.
- **Hive counter-move:** Podcast episodes are **Sources** — transcripts (local ASR) mean highlights, quotes, and claims flow into Honeycomb like any page. "I heard this in a podcast two months ago" becomes searchable. The audio player is a Hive mode; the memory of the audio is the moat.

---

## §32 — CROSS-CATEGORY SYNTHESIS

### 32.1 The absorption ladder (what Hive replaces, in order)

| Stage | Absorbed jobs | User-visible form | Substrate |
|---|---|---|---|
| **Browse** (now) | Chrome/Safari/Arc/Firefox/Edge — tabs, sessions, privacy, reader, downloads, passwords | The browser itself | WKWebView/CEF + BrowserState |
| **Remember** (Phase A) | Readwise, Pocket-class, tab managers, session savers, Rewisp-class memory | Wisps → Honeycomb, digests, what-changed | Honeycomb + EventLedger + capture |
| **Ask** (Phase B) | Perplexity, Comet Sidecar, AI chat wrappers | Swarm panel with real citations + scopes | Research pipeline + Cells |
| **Organize** (Phase C) | Obsidian/Notion/Craft/Anytype wikis + task apps | Projects, wiki, briefs, tasks, sheets | Honeycomb object graph |
| **Act** (P2) | Zapier/Shortcuts/browser agents + code studios | Flows, Studio, action ladder | Typed tools + approval center |
| **Extend** (P3+) | Raycast/utilities, finance, health, mail, media, calendar | Command center + modular suite | Cells + connectors + Sheets |

### 32.2 The killer insight across all 30 categories
Every standalone app above is **context-blind**. Monarch doesn't know why you spent more (it never saw the launch). Readwise doesn't know what you were researching (it never saw the tabs). Fantastical doesn't know the deadline is for that client (it never saw the email). Raycast doesn't know the research trail from Tuesday.

**Hive's compounding advantage is that the browser is where all context originates.** Every absorbed job gets strictly better by inheriting the context of the browsing session — and every capture makes the next job smarter. That is the flywheel the mega-dossier proves category-by-category.

### 32.3 The memory moat (what nobody can copy)
Standalone apps cannot replicate Hive's memory because:
1. **They lack the ingestion surface.** Only a browser sees every page, tab, and selection.
2. **They lack the structure.** Only a browser-native graph ties sources → claims → tasks → projects.
3. **They lack the trust posture.** OS-level capture (Rewisp) needs Screen Recording permission and scares users. Browser capture is origin-scoped and privacy-native.
4. **They lack the action surface.** Memory is only valuable when it can act — research, draft, file, code, remind. Only a browser with typed tools does that.

### 32.4 Pricing/business-model synthesis
Every subscription in this dossier (finance $100/yr, password $60/yr, reading $120/yr, email $360/yr, calendar $84/yr, utilities $120/yr, health $360/yr, automation $240/yr, media $180/yr) adds to a **$1,500+/yr tax** on a single user. Hive's bundled model — one browser, local-first core free, paid modular suite — attacks the aggregate, not each competitor. The conversion pitch is simple: **"You already pay for ten tools that can't talk to each other. Hive is one browser that does their jobs with your memory inside."**

### 32.5 Conversion strategy per segment
- **Browser switchers** (Arc refugees, Brave privacy users): import fidelity, spaces, memory. The switch cost is import — make it perfect (C4).
- **PKM power users** (Obsidian/Notion): auto-filling vault from browsing; no setup tax.
- **Read-later refugees** (Pocket/Omnivore dead, Instapaper price-doubled): native save + full-text search + memory.
- **AI researchers** (Perplexity users): real citations + stored sources + provenance.
- **Mac power users** (Raycast/Magnet/Bartender): command center + layouts + focus — bundled.
- **Privacy-first users** (Brave/Kagi/Proton crowd): local-first by default, honest labels, no data economy.
- **Superhuman/HEY users**: keyboard velocity + autonomous filtering — at a fraction of the price.
- **The 2026 orphan cohort**: every app that shut down (Pocket, Omnivore) or raised prices (Instapaper, Capture One) — each closure is a migration event Hive should meet with one-click import.

### 32.6 The five-year endgame
Hive starts as the browser you don't think about. It becomes the memory you can't live without. Then the memory becomes the surface — projects, actions, automation, and eventually the office/home operating layer. The mega-dossier is the map of every product between here and there. **We do not need to win any single category in year one. We need to own the context all of them are missing.**

---

## APPENDIX A — APP COUNT & COVERAGE LEDGER

| Category | Apps analyzed | Hive module that absorbs the job |
|---|---|---|
| §1 Finance | 8 | Hive Ledger + Sheets + Memory wisps |
| §2 Passwords/Identity | 7 | Vault (ships) + Identity graph |
| §3 Email | 8 | Hive Mail (P3) + intent filter |
| §4 Calendar | 7 | Hive Calendar (P3) + NL parser Cell |
| §5 Communication/Meetings | 10 | Connectors + Live Meeting Memory |
| §6 Video/Creative | 9 | Hive Studio + media Cells |
| §7 Photos | 10 | Hive Photos (local embeddings) |
| §8 Career | 8 | Hive Profile + research trails |
| §9 Education | 10 | Hive Recall + tutor Cells |
| §10 Health/Wellness | 10 | Hive Wellness + wellness guard |
| §11 Mac Utilities | 10 | Command Center + Focus Sessions |
| §12 Reading/Bookmarks | 8 | Phase A capture + recall |
| §13 Tab Management | 8 | Native + auto-archive (C2) |
| §14 Local AI | 7 | ModelStore + Dispatcher (ships) |
| §15 Search | 7 | Hybrid retrieval + research pipeline |
| §16 Notes/Docs | 10 | Wiki + Notes + Projects |
| §17 Enterprise | 10 | Architecture lessons only |
| §18 Developer Platforms | 6 | Studio + git-aware flows |
| §19 Media | 8 | Media Browser + seams |
| §20 Automation | 9 | Flows + action ladder + computer use |
| §21 AI Chat Assistants | 4 | Swarm panel + vendor-independent memory bus |
| §22 Editors & Terminals | 9 | Studio editor + governed project runner |
| §23 RSS & News | 7 | Feed Cells + reading module |
| §24 Clipboard & Capture | 7 | Hive Capture + snippet ring |
| §25 Cloud Storage & Files | 9 | Local-first file layer + connectors |
| §26 Task/Habit/Focus | 9 | Task inbox + Focus Sessions |
| §27 Shopping & Travel | 7 | Price Memory + trip research trails |
| §28 Weather & Ambient | 5 | Morning digest + context synthesis |
| §29 System Utilities | 6 | Memory pressure manager + system dashboard |
| §30 Social Media | 6 | Publishing Flows + content memory |
| §31 Podcasts & Audio | 4 | Audio module + transcript Sources |
| **Total** | **243 app-level analyses** | **31 absorbed modules + 4 existing substrates** |

## APPENDIX B — FEEDBACK LOOP

This dossier is a living document. Every time a competitor ships, dies, or raises prices, update the affected entry and re-run the synthesis in §21. New categories (gaming, travel, shopping, government services) should be added as new sections using the same five-part anatomy. The source-of-truth rule from AGENTS.md §1.1 applies: this document informs, code and evidence decide.
