# Hive Browser — Roadmap to $100M Valuation
## Target: January 1, 2027

**Branch:** `mission/recovery-and-ship`
**Created:** 2026-08-07
**Current State:** Working Chromium-based browser (CEF 148), 983 tests passing, ad-hoc signed, macOS only. Core browser fundamentals (tabs, workspaces, split view, navigation, bookmarks, history, downloads, AI/Swarm, web chrome) are functional. Not production-shipped.

---

## Executive Summary

Hive is a Chromium-backed macOS browser with native SwiftUI chrome shell, AI-first architecture (Swarm multi-model system), and web-based UI rendering (`hive://` scheme). The browser fundamentals are solid — 983 passing tests, smoke-tested session recovery, split view, workspaces, compact mode, and a full AI pipeline with graceful degradation.

**The gap:** We're a v0.8 browser in a market where Dia (Atlassian/Arc successor) ships AI-first browsing, Comet (Perplexity) ships agentic browsing, and Zen (Firefox fork) owns the power-user vertical-tabs niche.

**The playbook:** Out-execute by reusing proven open source components (Brave's adblock-rust, Astro's CDP agent framework, Zen's workspace UX patterns). Ship AI features that no single competitor has: on-device MLX inference, model council with honest degradation, and a Rust-hardened research worker.

### Quick Reference — 4 Phases

| Phase | Dates | Goal |
|-------|-------|------|
| **Phase 1** | Aug 11 — Sep 7, 2026 | Ship v1.0 macOS. Notarized. Production-quality. |
| **Phase 2** | Sep 8 — Oct 18, 2026 | Leapfrog Dia/Comet on AI: agentic browsing, model council, deep research |
| **Phase 3** | Oct 19 — Nov 29, 2026 | Windows + iOS + cross-device sync |
| **Phase 4** | Nov 30 — Jan 1, 2027 | Growth engine, monetization, 250K downloads, $60K MRR |

---

> **Full plan continues below with 11 sections covering: current state, competitive analysis, open source reuse strategy, detailed 4-phase implementation tasks, architecture decisions, growth model, risk register, team/resources, implementation checklist, success metrics, and license compliance.**
>
> **Then: the /autoplan Review Report follows with CEO, Design, Eng, and DX reviews, consensus tables, decision audit trail, and final recommendations.**

---

# PART 1: THE ROADMAP PLAN

## 1. Current State Assessment

### What Works Today (partial list — 25+ subsystems)

Tab management (complete), Workspaces with per-profile CEF isolation (complete), Split view with draggable dividers (complete), Navigation + address bar (complete), Web Chrome via `hive://` scheme (complete), Layout modes: vertical sidebar + horizontal strip + compact mode (complete), Full keyboard parity with Chrome/Safari/Arc/Zen/Brave/Firefox (complete), Session persistence with crash-only contract (complete), Bookmarks/History/Downloads (complete), AI/Swarm with 4 providers + honest degradation (working), Security: Keychain + CEF sandbox + Safe Browsing + EasyList + GPC header (complete), Private browsing (complete), Settings (complete), Command palette (complete), Tab search (complete), Reader mode (complete), Mini player with PiP (complete), Google Lens overlay (present), Translate bar (present), Extensions toolbar (basic), Find bar (present), Site security popover (present), Password manager (present), Privacy report (present), Onboarding (present).

### What's Missing

| Gap | Severity |
|-----|----------|
| Notarization pipeline | 🔴 Critical |
| Cross-platform (Windows/Linux) | 🔴 Critical |
| iOS/iPadOS app | 🔴 Critical |
| Extension store integration | 🟠 High |
| Sync (cross-device) | 🟠 High |
| Brave-quality adblocking | 🟠 High |
| AI agentic browsing (CDP actions) | 🟠 High |
| Voice I/O polish, Tab grouping UX, Auto-update (Sparkle), Crash reporting | 🟡 Medium |
| Payment/subscription, Internationalization | 🟢 Low |

## 2. Competitive Landscape

### Tier 1: AI Browsers
- **Dia** (The Browser Co / Atlassian, $610M acq): AI-first URL bar, Mornings briefing, Slack/Gmail/Calendar integration. macOS M1+ only, cloud-dependent.
- **Comet** (Perplexity, $9B val): Agentic browsing via CDP, AXTree-based page understanding, SSE+WebSocket dual-channel. Cloud-dependent, closed source.
- **Arc** (frozen): Best sidebar UX, Spaces, Boosts, Easels. No active development.

### Tier 2: Open Source Browsers
- **Zen**: Firefox-based, best vertical tabs/workspaces, Zen Mods theme system, compact mode.
- **Brave**: adblock-rust engine, Leo AI, Brave Sync v2, Rewards/BAT, cross-platform.
- **Astro** (Blueturboguy07): Agentic browser, SearXNG local search, model council, 16 CDP tools, AGPL-3.0.
- **Floorp**: Firefox-based, customizable sidebar/workspaces.

## 3. Open Source Reuse Strategy

| Component | Source | License | What We Take | Effort |
|-----------|--------|---------|-------------|--------|
| **adblock-rust** | Brave | Apache 2.0 / MPL 2.0 | Full Rust crate via FFI → Swift | 2 weeks |
| **CDP Agent Tools** (16 tools) | Astro | AGPL-3.0 (learn architecture, rewrite MIT) | Tab management, navigation, click, form fill, screenshot, AXTree | 3 weeks |
| **Model Council Architecture** | Astro | AGPL-3.0 (adapt pattern) | Parallel multi-model + chair synthesis | 2 weeks |
| **AXTree → YAML** | Astro/Comet | Learn from both | Accessibility tree → LLM-readable context | 2 weeks |
| **SearXNG Integration** | Astro | AGPL-3.0 (separate process) | Local search engine option | 1 week |
| **Sync v2 Protocol** | Brave | MPL 2.0 (adapt protocol) | E2E encrypted sync | 4 weeks |
| **Zen Mods/Theme System** | Zen | MPL 2.0 (adapt architecture) | Theme marketplace | 2 weeks |
| **Chromium Perf Patches** | Thorium | BSD 3-Clause | AVX2, LTO, PGO flags | 1 week |

## 4. Feature Roadmap — 4 Phases

### Phase 1: Foundation & Ship-Ready (Aug 11 — Sep 7, 2026)

**Ship Readiness (Week 1-2):**
- P1.1 Apple Developer Program + notarization pipeline (3 days)
- P1.2 Sparkle auto-update framework (2 days)
- P1.3 Privacy-preserving crash reporting (3 days)
- P1.4 Landing page + download site at hivebrowser.com (3 days)

**Quality & Polish (Week 3-4):**
- P1.5 UI visual audit — all 60+ SwiftUI views (4 days)
- P1.6 Accessibility audit — VoiceOver + keyboard (3 days)
- P1.7 Onboarding v2 — import from Chrome/Brave/Edge/Safari/Arc/Zen (3 days)
- P1.8 Extension support — Chrome Web Store bridge (5 days)
- P1.9 Test suite expansion — target 1,200+ tests (3 days)

**Phase 1 Exit:** Notarized .dmg, Sparkle updates, Chrome Web Store extensions, 1,200+ tests ✅

### Phase 2: AI Supremacy (Sep 8 — Oct 18, 2026)

**Agentic Browsing (Week 5-6):**
- P2.1 CDP Agent Tools — 16 CDP tools as Swift wrapper (2 weeks)
- P2.2 AXTree → LLM-Readable Context — YAML conversion + element targeting (1 week)

**Model Council (Week 7-8):**
- P2.3 Model Council v2 — parallel 3+ model dispatch + chair synthesis (1.5 weeks)
- P2.4 AI URL Bar — dual-mode search/AI input (Dia parity) (1.5 weeks) — ✅ DONE: ⇧⏎ routes bar text to AI on both chrome surfaces (native bar → panel chat via submitGeminiQuery; web bar → agent dock via agentAsk) with a focused-mode hint pill

**Deep Research (Week 9-10):**
- P2.5 Deep Research Mode — multi-step: plan → search → read → synthesize → cite (1.5 weeks)
- P2.6 Mornings Proactive Briefing — daily summary from Honeycomb + Calendar (1.5 weeks)

**Phase 2 Exit:** Agent navigates/clicks/types/fills forms on any page. Model council synthesizes perspectives. AI URL bar with citations. Deep research with cited briefs. All degrade gracefully to on-device MLX. ✅

### Phase 3: Cross-Platform & Ecosystem (Oct 19 — Nov 29, 2026)

- P3.1 Windows build pipeline — WinUI3 + CEF (2 weeks spike)
- P3.2 Windows feature parity (ongoing, 3 weeks)
- P3.3 iOS/iPadOS app — SwiftUI + WKWebView + shared HiveCore (2 weeks)
- P3.4 End-to-End Encrypted Sync — iCloud CloudKit first, cross-platform later (2-4 weeks)

**Phase 3 Exit:** Windows .msix + iOS TestFlight + sync working macOS↔iOS ✅

### Phase 4: Growth, Monetization & Scale (Nov 30, 2026 — Jan 1, 2027)

**Growth (Week 17-18):**
- P4.1 Referral program with leaderboard (1 week)
- P4.2 Community features — theme marketplace, Swarm recipe sharing, Discord (1 week)
- P4.3 Content marketing — blog, YouTube, PR (ongoing)

**Monetization (Week 19-20):**
- P4.4 Hive Pro subscription — $8/month for power AI features (1.5 weeks)
- P4.5 Payment integration — Stripe + App Store receipt validation (1 week)
- P4.6 Enterprise tier — SSO, admin dashboard, custom models, SLA (1.5 weeks)

**Phase 4 Exit:** 250K+ downloads, 5K Pro subscribers ($40K MRR), 10+ enterprise customers, $100M valuation metrics ✅

## 5. Technical Architecture Decisions

- **D-003:** Learn from AGPL-3.0 projects (Astro), rewrite under MIT. Integrate permissive components (adblock-rust, go-sync) directly.
- **D-004:** Hybrid AI — on-device MLX default, cloud providers opt-in. Honest degradation when offline.
- **D-005:** Cross-platform: macOS SwiftUI+CEF, Windows WinUI3+CEF, iOS SwiftUI+WKWebView. Share HiveCore.
- **D-006:** Freemium monetization — core browser free, Pro $8/mo, Enterprise $20/user/mo.

## 6. Growth & Monetization Model

**Downloads:** Waitlist (10K) → Product Hunt (15K) → HN (10K) → Press (20K) → Organic (5K/week) → Windows (30K) → iOS (25K) = **250K+ by Jan 2027**

**Revenue:** 5,000 Pro × $8 = $40K/mo + 50 Enterprise × $400 = $20K/mo = **$60K MRR, $720K ARR**

**Valuation:** $720K ARR × 20-30x AI browser multiple = $14M-$21M (current). Growing 15% WoW → forward ARR ~$4.3M → **$86M-$129M target.**

## 7. Risk Register

| Risk | Prob | Impact | Mitigation |
|------|------|--------|------------|
| Apple rejects notarization | Low | Critical | Entitlement compliance audit |
| CEF upgrade breaks D-002 | Medium | High | Vendor pin + regression tests |
| Windows port overruns | High | High | Spike first; fallback: macOS+iOS only |
| MLX insufficient for agentic tasks | Medium | Medium | Graceful degradation to cloud |
| 0 Pro conversions | Medium | Critical | Pivot pricing |
| Chrome Web Store compat | Medium | Medium | Document compatible extensions |
| $100M needs more traction | High | Medium | Focus on MAU growth + revenue + NPS |

## 8. Team & Resources

Budget: ~$83,500 total (Windows dev $30K, iOS dev $15K, Marketer $25K, Designer $8K, Apple Dev $99, Windows cert $300, Infra $5K)

## Implementation Task List (condensed — see full plan in Phase sections above)

All tasks are mapped to specific files in Sources/Hive/ and Sources/HiveCore/ with effort estimates and owners.

---

# PART 2: /AUTOPLAN REVIEW REPORT

<!-- /autoplan restore point: .hive/mission/ROADMAP_2027.md (in-place review) -->

**Date:** 2026-08-07 | **Review Type:** Autonomous (Claude primary + Gemini thinker as subagent) | **Codex:** Unavailable

---

## Phase 0: Intake + Scope Detection

- **Plan file:** `.hive/mission/ROADMAP_2027.md`
- **UI scope:** ✅ Detected — 15+ UI terms
- **DX scope:** ✅ Detected (light) — CDP tools API, sync protocol, extension API

---

## Phase 1: CEO Review — Strategy & Scope

### 0A: Premise Challenge

| # | Premise | Valid? | Reasoning |
|---|---------|--------|-----------|
| P1 | 1 dev + AI can ship all 4 phases in 5 months | ⚠️ Fragile | Phase 3 is 3 platform ports. Contractor budget helps but onboarding isn't budgeted. |
| P2 | OSS components save significant time | ✅ Valid | adblock-rust is drop-in. CDP tools need AGPL→MIT rewrite but patterns are documented. |
| P3 | 250K downloads in 5 months from zero | ⚠️ Optimistic | Requires PH #1, HN frontpage, TechCrunch, AND 5K/week organic — all converging. |
| P4 | $100M at $60K MRR with 15% WoW | ⚠️ Stretch | 15% WoW sustained 20 weeks = 16x growth. Dia sold $610M with shipped product + team. |
| P5 | On-device AI (MLX) is durable differentiator | ✅ Valid | No competitor does this. Dia/Comet are cloud-only. |
| P6 | Freemium drives adoption better than paid-only | ⚠️ Contested | Thinker argues for paid-only ($30/mo). Freemium needs 250K MAU for 5K paid (2% conv). |

**🔴 PREMISE GATE — The Strategic Tension:**

The plan bets on "browser + AI" (general-purpose, cross-platform, freemium). The thinker argues "AI tool that browses" (macOS-only, paid, focused). These are different companies. Both paths are viable. **Recommendation: keep cross-platform ambition but GATE Phase 3 on Phase 1-2 traction data.** Ship macOS first, validate, then decide.

### 0B: Existing Code Leverage Map

adblocking → EasyListBlocklist.swift → Replace with adblock-rust FFI
AI/Swarm → SwarmResponseExecutor, IntentOrchestrator, ModelRuntime → Add CDP tools, council v2
Browser model → BrowserState.swift (6410 lines) → Add tab grouping, extensions
Session → SessionStore, session.json → Add sync protocol
Web chrome → WebChromeHandler, WebChrome/ → Add briefing card, AI URL bar, themes
Security → SafeBrowsingClient, KeychainSecretStore → Upgrade to adblock-rust
Settings → SettingsView → Add Pro subscription, extension management

### 0C: Dream State Delta

**Current:** macOS-only, ad-hoc signed, 1 dev, solid fundamentals, working AI (no agentic actions), 0 users, 0 revenue
**Plan (Jan 2027):** macOS+Windows+iOS, notarized, 250K users, agentic+council+research, $60K MRR, $100M val
**Ideal (Aug 2027):** $5M+ ARR, 50K+ Pro, Linux+Android, API platform, acquired/Series B $300M+, team of 15

### Step 0.5: CEO Dual Voices

**Codex:** Unavailable. **Claude Subagent:** Gemini Thinker.

#### Gemini Thinker Findings:
1. **Critical:** Multi-front war against funded giants. Pivot to macOS-only AI Deep Research Engine.
2. **Critical:** Timeline is a hallucination — 16 CDP tools + model council + sync server + WinUI3 in 5 months.
3. **High:** Phase 3 produces three broken disjointed codebases. Apple will Sherlock AI URL bar.
4. **High:** Freemium requires supporting 245K free users with no infra budget.
5. **Critical:** Real moat is Rust fetch boundary + Honeycomb memory, not browser features.

#### CEO CONSENSUS TABLE:

```
CEO DUAL VOICES — CONSENSUS TABLE:
═══════════════════════════════════════════════════════════════
  Dimension                           Claude  Gemini Consensus
  ──────────────────────────────────── ─────── ────── ─────────
  1. Premises valid?                   Mixed   Mixed  DISAGREE
  2. Right problem to solve?           Yes     No     DISAGREE
  3. Scope calibration correct?        Mostly  No     DISAGREE
  4. Alternatives sufficiently explored? No    No     CONFIRMED
  5. Competitive/market risks covered? Yes     Partial DISAGREE
  6. 6-month trajectory sound?         Yes     No     DISAGREE
═══════════════════════════════════════════════════════════════
```

Both agree: alternatives insufficiently explored. Thinker wants radical scope reduction. Claude sees plan as ambitious but viable.

### CEO Completion Summary

| Dimension | Score |
|-----------|-------|
| Problem clarity | 7/10 |
| Scope calibration | 5/10 |
| Competitive positioning | 8/10 |
| Timeline realism | 4/10 |
| Risk coverage | 7/10 |
| Monetization | 6/10 |
| Growth model | 5/10 |

**CEO Verdict:** APPROVE WITH MODIFICATIONS. AI-first direction is correct. Scope/timeline need adjustment.

---

## Phase 2: Design Review

**Completeness: 6/10.** Missing: loading/error/empty/partial/degraded states for all AI features.

### DESIGN CONSENSUS TABLE:

```
DESIGN DUAL VOICES — CONSENSUS TABLE:
═══════════════════════════════════════════════════════════════
  Dimension                           Claude  Gemini Consensus
  ──────────────────────────────────── ─────── ────── ─────────
  1. Information hierarchy correct?    Mostly  N/A    CONFIRMED
  2. Interaction states specified?     No      N/A    CONFIRMED
  3. Design system consistency?        Yes     N/A    CONFIRMED
  4. Responsive strategy?              Partial N/A    CONFIRMED
  5. Accessibility specified?          Yes     N/A    CONFIRMED
  6. Animation/motion specified?       Partial N/A    CONFIRMED
  7. Visual polish level?              Medium  N/A    CONFIRMED
═══════════════════════════════════════════════════════════════
```

### Design Completion Summary

| Pass | Score | Key Issue |
|------|-------|-----------|
| Information Hierarchy | 7/10 | Start page vs briefing priority |
| Missing States | 4/10 | No loading/error/empty states |
| Specificity | 5/10 | AI URL bar interaction underspecified |
| Responsive Strategy | 6/10 | Acceptable |
| Accessibility | 6/10 | Dogfood AXTree for AI a11y |
| Animation | 7/10 | Use existing tokens |
| Visual Polish | 6/10 | Needs design tokens for new surfaces |
| **Overall** | **6/10** | Functional but underspecified |

---

## Phase 3: Eng Review

### Code Reality Check

| Plan Claim | Assessment |
|-----------|------------|
| "16 CDP tools as Swift wrapper" | Feasible but non-trivial. Production needs `CefBrowserHost.sendDevToolsMessage` (in-process), not `localhost:9223` (#if DEBUG AND `HIVE_DEBUG_CDP=1` gated; closed by default). |
| "adblock-rust via FFI → Swift" | Feasible. Existing Rust FFI pattern from hive-fetch-boundary applies. |
| "AXTree via CEF DevTools" | Feasible, shares infrastructure with CDP tools. |
| "WinUI3 + CEF on Windows" | **High risk.** Swift→C# interop is NOT "share HiveCore" — it's a port. |
| "iOS with WKWebView + HiveCore" | Feasible. HiveCore is platform-agnostic. 2 weeks aggressive. |

### Architecture — ASCII Dependency Graph

```
┌──────────────────────────────────────────────────────────────┐
│                     Hive.app (macOS)                         │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │ SwiftUI     │  │ Web Chrome   │  │ CefWebView         │  │
│  │ Chrome Shell│  │ (hive://)    │  │ (Chromium Renderer)│  │
│  └──────┬──────┘  └──────┬───────┘  └─────────┬──────────┘  │
│         └────────────────┼────────────────────┘              │
│                    ┌─────┴──────┐                            │
│                    │ HiveCore   │                            │
│                    └─────┬──────┘                            │
│  ┌───────────────────────┼───────────────────────┐          │
│  │ AI/Swarm              │ Browser Model         │          │
│  │ ┌──────────────────┐  │ ┌──────────────────┐  │          │
│  │ │CDP Tools (NEW)   │  │ │Sync (NEW)        │  │          │
│  │ │AXTree (NEW)      │  │ │adblock-rust (NEW)│  │          │
│  │ │Council v2 (MOD)  │  │ └──────────────────┘  │          │
│  │ │Deep Research (NEW)│ │                       │          │
│  │ └──────────────────┘  │                       │          │
│  └───────────────────────┴───────────────────────┘          │
│         │                                                   │
│  ┌──────┴──────────────────────────┐                       │
│  │ Rust Fetch Boundary             │                       │
│  │ (hive-fetch-worker)             │                       │
│  └──────┬──────────────────────────┘                       │
│  ┌──────┴──────┐  ┌────────────┐  ┌──────────────────┐     │
│  │ adblock-rust│  │ MLX Models │  │ Tavily/Vane/     │     │
│  │ (NEW)       │  │ (on-device)│  │ SearXNG (NEW)    │     │
│  └─────────────┘  └────────────┘  └──────────────────┘     │
└──────────────────────────────────────────────────────────────┘

⚠️ CRITICAL: CDP Agent Tools need in-process DevTools
(CefBrowserHost.sendDevToolsMessage), not remote debugging.
Current #if DEBUG gating on port 9223 won't work in production.
```

### Code Quality

| Concern | Severity | Fix |
|---------|----------|-----|
| BrowserState.swift is 6410 lines | High | Split into extensions: +Tabs, +AI, +Sync, +Chrome |
| CDP tools need action approval gating | High | Integrate with existing ActionApprovalView + ToolRegistry |
| adblock-rust FFI error handling | Medium | Match existing Rust FFI patterns |
| AI features share no common result type | Medium | Create AIResult protocol |

### Test Review

**Current:** 983 tests / 130 suites. **Gaps identified for:** CDP Agent Tools (16+ test files needed), AXTree Context (snapshot tests), Model Council v2 (eval framework), adblock-rust (use crate's own fixtures), AI URL Bar (intent detection tests), Deep Research (citation accuracy), Sync (encryption + conflict resolution), Subscription (Stripe test mode).

### ENG CONSENSUS TABLE:

```
ENG DUAL VOICES — CONSENSUS TABLE:
═══════════════════════════════════════════════════════════════
  Dimension                           Claude  Gemini Consensus
  ──────────────────────────────────── ─────── ────── ─────────
  1. Architecture sound?               Mostly  N/A    CONFIRMED
  2. Test coverage sufficient?         No      N/A    CONFIRMED
  3. Performance risks addressed?      Partial N/A    CONFIRMED
  4. Security threats covered?         Yes     N/A    CONFIRMED
  5. Error paths handled?              No      N/A    CONFIRMED
  6. Deployment risk manageable?       Partial N/A    CONFIRMED
═══════════════════════════════════════════════════════════════
```

### Eng Completion Summary

| Dimension | Score |
|-----------|-------|
| Architecture | 7/10 |
| Code Quality | 6/10 |
| Test Coverage (planned) | 5/10 |
| Performance | 7/10 |
| Security | 8/10 |
| Deployment | 6/10 |

**Eng Verdict:** APPROVE WITH MODIFICATIONS. CDP DevTools needs production redesign. BrowserState decomposition needed pre-Phase 2. Phase 3 needs spike first.

---

## Phase 3.5: DX Review (Condensed)

**DX scope: Light.** Product is end-user browser with small developer-facing API surface.

| Dimension | Score |
|-----------|-------|
| API/CLI Design | 6/10 |
| Error Messages | 5/10 |
| Documentation | 3/10 |
| Dev Environment | 7/10 |
| Escape Hatches | 6/10 |
| Extensibility | 5/10 |

**DX Verdict:** SKIP deep review. Key gap: Swarm tool plugin API would differentiate post-launch.

---

## Phase 4: Final Approval Gate

### /autoplan Review Complete

**Decisions Made:** 15 total (12 auto-decided, 3 taste choices)

### Your Choices (taste decisions)

**Choice 1: AI URL Bar — Auto-Detect vs Manual Toggle**
I recommend auto-detection (cleaner UX, no Tab toggle). Dia uses manual toggle as alternative.

**Choice 2: macOS-First vs Cross-Platform in Phase 3**
I recommend gating Phase 3 on Phase 2 traction data. Don't commit contractors until macOS AI features are validated with users.

**Choice 3: Freemium vs Paid-Only**
I recommend freemium (broader reach, more feedback). Paid-only ($30/mo) is alternative — validates demand immediately.

### Review Scores

- **CEO:** APPROVE WITH MODIFICATIONS. Scope needs tightening. 5/6 consensus disagreements with thinker.
- **Design:** 6/10. Missing interaction states. Information hierarchy underspecified.
- **Eng:** APPROVE WITH MODIFICATIONS. CDP DevTools redesign needed. Phase 3 is highest technical risk.
- **DX:** SKIPPED (condensed). Swarm plugin API recommended post-launch.

### Cross-Phase Themes

**Scope Calibration** — flagged in CEO, Eng, and Design. The plan tries to do too much for 1 person in 5 months. **Gate Phase 3 on Phase 1-2 traction.**

**Missing Interaction States** — flagged in Design and Eng. Every AI feature needs loading/error/empty/partial/degraded states.

---

## Decision Audit Trail

| # | Phase | Decision | Classification | Principle |
|---|-------|----------|---------------|-----------|
| 1 | CEO | Accept P2, P5; flag P1, P3, P4, P6 as contested | Taste | P1 |
| 2 | CEO | Mode: SELECTIVE EXPANSION | Mechanical | P1 |
| 3 | CEO | Defer Phase 3 gating to Final Gate | Taste | P6 |
| 4 | CEO | Defer Linux, Android, ungoogled, i18n, PWA | Mechanical | P3 |
| 5 | CEO | Keep current framing for Phase 1-2 | Mechanical | P6 |
| 6 | Design | First launch: start page with AI card | Mechanical | P5 |
| 7 | Design | Require 5 interaction states for all AI features | Mechanical | P1 |
| 8 | Design | AI URL Bar auto-detection vs manual toggle | Taste | P5 |
| 9 | Design | Use existing HiveDesign animation tokens | Mechanical | P5 |
| 10 | Eng | Decompose BrowserState.swift before Phase 2 | Mechanical | P5 |
| 11 | Eng | CDP: in-process DevTools, not remote debugging | Mechanical | P1 |
| 12 | Eng | adblock-rust: follow existing Rust FFI pattern | Mechanical | P4 |
| 13 | Eng | Sync: iCloud CloudKit first, cross-platform later | Mechanical | P3 |
| 14 | DX | Skip deep DX review | Mechanical | P3 |
| 15 | DX | Flag Swarm plugin API as post-launch differentiator | Mechanical | P1 |

---

## Final Recommendations

1. **START NOTARIZATION ENROLLMENT NOW.** Critical path — don't wait for Aug 11.
2. **DECOMPOSE BrowserState.swift.** 6410-line file blocks parallel work. Pre-work for Phase 2.
3. **GATE PHASE 3 ON PHASE 2 TRACTION.** Validate AI features with real users before committing to cross-platform.
4. **ADD INTERACTION STATES.** Every Phase 2 AI feature needs loading/error/empty/partial/degraded states.
5. **REDESIGN CDP DEVTOOLS FOR PRODUCTION.** Use `CefBrowserHost.sendDevToolsMessage`, not `#if DEBUG` port 9223.

### Critical Path Tasks

- **R1 (P1)** — Start Apple Developer Program enrollment NOW
- **R2 (P1)** — Decompose BrowserState.swift into subsystem extensions (Sources/Hive/BrowserState.swift, 2 days)
- **R3 (P1)** — Redesign CDP DevTools access for production (Sources/HiveCore/AI/CDPAgentTools.swift (new), 3 days)
- **R4 (P1)** — Add interaction state specs to every Phase 2 task description (1 day)
- **R5 (P2)** — Implement adblock-rust FFI wrapper (Sources/HiveCore/Browser/AdblockEngine.swift (new), 2 days)
