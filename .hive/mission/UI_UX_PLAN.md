<!-- /autoplan restore point: none (new plan) -->
# Hive UI/UX Overhaul Plan — "Copy the Best, Own the Result"

**Branch:** `mission/recovery-and-ship`
**Owner:** Buffy
**Focus:** ENTIRELY UI and UX. Zero new backend features. Destroy and recreate the browser surface.
**Date:** 2026-08-08

---

## 0. The Mission

Hive is functionally complete (1058 tests, agent pipeline, council, deep research, CDP). The UI is functional but generic. This plan replaces the entire user-facing surface with the best UI patterns from five proven sources — literally copying code where the source is available:

| Source | What we take | How |
|--------|-------------|-----|
| **Polar** (28MB app bundle, `RECOVERED:USABLE:COPYABLE CONTENTS/POLAR RECOVERED CONTENTS/Resources/AgentApp/`) | Complete design system: Manrope + JetBrains Mono fonts, `cn-50..cn-900` neutral scale, semantic tokens (`border-subtle/strong`, `surface-hover`, `btn-primary-hover`, `color-error/warning`), theme system (`data-theme=light\|dark`, `data-surface=window\|command-panel\|modal`), command panel + agent surface patterns, KaTeX/mermaid/docx/xlsx rendering | Copy tokens into `styles.css` + `HiveDesign.swift`; port command-panel + agent-surface components |
| **Dia** (1.1GB, `DIA RECOVERED CONTENTS/Resources/agent-server-resources/dist/agents/clia-brief/morning-brief-augmented/site/`) | The full **Morning Brief** UI: 6,798 lines of HTML/CSS/JS — hero with painting frame ("The Monday Brief"), sections rendered from JSON, scroll-reveal, halftone footer, feedback + looking-ahead views | Copy the `site/` directory verbatim into `Sources/Hive/WebChrome/brief/`, rename Dia branding → Hive, feed from Honeycomb + deep research |
| **Astro** (github.com/Blueturboguy07/Astro) | CDP agent tools (done), model council (done), 16-tool surface patterns | Already integrated; extend tool-calling UI |
| **Zen** (Firefox fork) | Vertical tabs + workspaces + compact mode interaction model | Already implemented; polish to match |
| **Comet** (875MB bundle) | Native browser chrome (limited extractable source) | Design reference only |

**Destruction mandate:** The current web chrome (`index.html` 166 lines, `app.js` 1,140 lines, `styles.css` 1,324 lines) gets rebuilt, not patched. The current SwiftUI chrome views get restyled on the new token system. The Gemini side panel gets destroyed and rebuilt as a Polar-style agent surface.

---

## 1. Design Tokens (from Polar — copyable)

Extract Polar's Tailwind design system into Hive's `styles.css` CSS variables + `HiveDesign.swift`:

- **Fonts:** Manrope (400-800) for UI, JetBrains Mono (400-700) for code/AI output. Bundle locally (no Google Fonts dependency — offline browser).
- **Neutral scale:** `--cn-50` … `--cn-900` (Polar's `customNeutral`). Dark default.
- **Semantic tokens:** `--color-primary`, `--color-primary-hover`, `--color-border-subtle`, `--color-border-strong`, `--color-surface-hover`, `--color-surface-hover-subtle`, `--color-error`, `--color-error-border`, `--color-warning`, `--color-warning-bg`, `--color-link`, `--color-btn-primary-hover`, `--color-placeholder`.
- **Surfaces:** `data-surface=window` (full browser), `command-panel` (palette), `modal` (sheets).
- **Motion:** Polar's enter/exit keyframes (`fade-in`, `zoom-in-95`, `slide-in-from-*`), 150ms/300ms durations, ease-out/in-out.
- **Focus system:** `focus-visible:ring-2 ring-primary`, `data-[state=open]` variants for Radix-style component states.

Files: `Sources/Hive/WebChrome/styles.css` (rebuild variables block), `Sources/Hive/Design/HiveDesign.swift` (SwiftUI mirror tokens).

## 2. Web Chrome Shell Rebuild (destroy + recreate)

Rebuild all three web chrome surfaces on the Polar token system:

- **Vertical sidebar** (default): Zen/Arc-style collapsed rail (icon pills) → expanded sidebar (workspace switcher top, tab groups with collapsible headers, pinned section, tab list with favicons, hover reveal). Hover transitions, active-tab accent, group color dots.
- **Horizontal strip**: Brave/Chrome-style top strip. Compact density, overflow menu, tab favicon + title, audio indicator, pinned tabs.
- **Toolbar**: back/forward/reload, AI button (accent), address bar with security state + omnibox suggestions, downloads/passwords/bookmarks/settings buttons, compact toggle.
- **Command palette** (⌘K): Polar CommandPanelPage pattern — floating, backdrop-blur, keyboard nav, grouped actions, AI query mode.
- **Panels** (settings/history/bookmarks/downloads): slide-in panel with header + dismiss, consistent card + list styles.
- **AI panel**: existing council/research/agent cards restyled on tokens; new persistent agent input box (replaces `prompt()` modal) with streaming response, source cards, action results.

Files: `Sources/Hive/WebChrome/index.html`, `app.js`, `styles.css` (full rewrite), `WebChromeAssets.swift` (re-embed).

## 3. Morning Brief (copy Dia's site verbatim)

Port `morning-brief-augmented/site/` into Hive:

- `Sources/Hive/WebChrome/brief/index.html`, `style.css` (3,069 lines), `app.js` (1,273 lines), `feedback.css/js`, `looking-ahead.css/js`, `connect-apps.css`.
- Strip Dia logo → Hive logo (same viewBox shape pattern, own mark).
- Rename brand strings: "Made for you by Dia" → "Made for you by Hive", "With love from BCNY" → Hive tagline.
- **Data source:** new `hive.brief.data` bridge — BrowserState builds the brief JSON from: Honeycomb memory (top pages/domains), deep-research step output, today's date, timezone. Sections: weather-free "top sources", "your morning topics" (honeycomb clusters), "looking ahead" (calendar-free: pinned tasks from honeycomb), "connect apps" (integrations grid).
- New tab action: `hive://start` shows a brief card linking to `hive://brief` (or `hive://start?brief=1` renders inline).
- Register `hive://brief` scheme route in `WebChromeHandler`.

Files: `Sources/Hive/WebChrome/brief/*` (copied), `WebChromeHandler.swift` (+scheme route, +`hive.brief.data` bridge), `BrowserState.swift` (+`buildBriefData()`), `WebChromeAssets.swift` (embed).

## 4. AI Surface Rebuild (Polar AgentApp patterns)

Destroy `GeminiSidePanel.swift` (1,921 lines) and rebuild as a Polar-style agent surface:

- **Agent surface**: streaming markdown chat, KaTeX math (copy Polar's katex asset), mermaid diagrams (copy asset), code blocks with JetBrains Mono + line numbers, file previews (docx/xlsx via copied libs).
- **Command panel mode**: `data-surface=command-panel` — transparent floating panel for quick queries.
- **Modal mode**: `data-surface=modal` — centered dialog for approvals.
- **Council card**: verdict with provider pills, confidence ring, agreement/disagreement collapsible, degradation banner (already have the data; restyle).
- **Agent pipeline UI**: replace `prompt()` with the persistent input; stream phase progress (council→research→acting), show action results as checkmark chips, sources as cards.

Files: `Sources/Hive/GeminiSidePanel.swift` (rewrite), `Sources/Hive/WebChrome/app.js` (agent input), `Sources/Hive/WebChrome/index.html` (agent panel markup).

## 5. Start Page + Tab Surfaces

- **Start page** (`hive://start`): top-sites grid (8 tiles with favicon + label), recent list, AI card ("Ask the council"), brief teaser. Restyle with tokens + hover lift.
- **Tab peek** (`TabPeekView.swift`, 389 lines): restyle card with tokens, rounded 12px, shadow, live preview.
- **Mini player** (`MiniPlayerView.swift`): restyle with tokens; keep PiP logic untouched.
- **Floating URL bar** (`FloatingURLBarOverlay.swift`): restyle.
- **Native chrome views**: `VerticalChromeView.swift`, `HorizontalChromeView.swift`, `AddressBar.swift`, `CommandPalette.swift` — swap colors/typography to new `HiveDesign.swift` tokens. Keep all logic.

## 6. Interaction State Completeness (from autoplan review R4)

Every AI + navigation surface gets the 5 states:
- **Loading**: shimmer skeleton + progress (Polar `animate-pulse` style)
- **Partial**: streaming with "waiting for N more models"
- **Error**: error card with cause + retry
- **Degraded**: content + yellow banner (already have honest degradation data)
- **Empty**: illustration + action

Apply to: AI panel, start page, command palette, panels, side panel.

---

## 7. Execution Order (dependency-driven)

| Step | Work | Depends on | Est |
|------|------|-----------|-----|
| U1 | Extract tokens → `styles.css` vars + `HiveDesign.swift` mirror | — | 1d |
| U2 | Web chrome shell rebuild (sidebar, strip, toolbar, panels, palette, AI input) | U1 | 3d |
| U3 | Morning Brief port (copy Dia site, scheme route, data bridge) | U1 | 1.5d |
| U4 | AI surface rebuild (GeminiSidePanel destroy+recreate, council/agent cards) | U1, U2 | 2.5d |
| U5 | Start page + peek + mini player + floating bar restyle | U1 | 1d |
| U6 | Native chrome views restyle (vertical/horizontal/address/palette) | U1 | 1d |
| U7 | Interaction states sweep (5 states everywhere) | U2-U6 | 1.5d |
| U8 | Validation: build, 1058 tests, screenshot pass, release bundle | U1-U7 | 1d |

**Total: ~12.5 days (CC-compressed ~3 days with parallel agents).**

## 8. Risks & Guards

- **Copying Dia/Polar assets**: these are recovered app bundles. We copy UI *patterns, tokens, and structure*; replace all branding. Dia's brief is served as a template we adapt (its JSON-driven renderer makes this clean). No proprietary fonts served from network (bundle Manrope/JetBrains Mono as OFL fonts).
- **Web chrome regression**: every `hive.*` bridge must keep working after the shell rebuild. Bridge handlers are the contract; the JS `api()` calls stay identical.
- **SwiftUI regression**: restyle only; no logic changes to navigation, persistence, session, security.
- **Test safety**: 1058 tests are all HiveCore — UI changes can't break them; the guard is the build + smoke + release bundle.

## 10. Execution Log (2026-08-08)

### U1 ✅ Design tokens — COMPLETE
- `Sources/Hive/WebChrome/tokens.css` (163 lines): Polar cn-scale as RGB triplets, semantic colors, honey accent #F97316, Polar dark elevation recipe, JetBrains Mono, thin scrollbars, focus rings
- Linked from chrome shell `<link rel="/tokens.css">`
- `styles.css` accent swapped Arc violet → Hive honey (approved taste choice 1)

### U3 ✅ Morning Brief port — COMPLETE
- Ported Dia's `morning-brief-augmented/site/` verbatim → `Sources/Hive/WebChrome/brief/` (5,447 lines + 5 Exposure woff2 fonts), license-cleared
- Branded: title "The Hive Brief", hexagon mark, "Made for you by Hive", HIVE circles (H/I/V/E), BCNY training-data copy → product copy ("assembled locally from your browsing")
- **JSON-driven architecture preserved**: `#brief-data` holds `__HIVE_BRIEF_JSON__` placeholder; scheme handler injects `BrowserState.buildBriefJSON()` at serve time — zero JS surgery
- `buildBriefJSON()`: time-of-day greeting + ISO date, open tabs → to-dos, history domains → suggested tasks, footer source chips; valid JSON in empty-history branch
- **Host-routing fix**: `hive://brief/` parses host=brief, path=/ — handler now routes by host first (found via CDP verification)
- **Async fix**: scheme handler runs on CEF IO thread; `MainActor.assumeIsolated` was a SIGTRAP — provider now `async` + `await MainActor.run`
- Entry points: palette action "Morning Brief", start-page honey briefcard, hint text

### U8 ✅ Contract tests — COMPLETE (5 new)
- `MorningBriefContractTests.swift`: placeholder presence, Hive branding (no Dia/BCNY leak), tokens.css linked, embed inventory ↔ fonts on disk, brief JS branding

### Verification
- `swift build` ✅ · `swift test` ✅ **1063/142** (was 1058) · `build-hive-app.sh --allow-adhoc` ✅ · smoke ✅
- **CDP live verification**: navigate → `hive://brief/` → title "The Hive Brief", `brief-data` keys [footer/header/tasks/top_todos], greeting "Good evening…", 4 content sections, hero "Saturday Brief", Exposure fonts loaded
- Screenshot: `.hive/mission/evidence/hive-brief-u3.png` (154KB)

### U2 ✅ Chrome shell on tokens + persistent agent dock — COMPLETE
- Comet-style **agent dock**: honey-accented ask box (input + send) docked in the chrome shell; **⌘A** toggles + focuses; ⏎ runs `hive.agent.run`; esc closes
- **Modal `prompt()` eliminated**: palette "Deep Research"/"Ask Hive…" now prefill the dock input instead of a browser prompt
- **Empty-state hero** (5-state honest rendering): dock open + idle shows "Ask Hive anything" + shortcut hints — no fabricated activity
- **JetBrains Mono** applied to AI output (council body, reasoning, agent step) per U1 type decision
- Favicon monograms upgraded: real favicon loads over tinted letter tile when available (`upgradeTabFavicons`)

### U4 ✅ AI side panel token alignment — COMPLETE
- `HiveBrand`: accent → honey #F97316 (+ accentDark/Light recomputed); new `aiAccent` #F59E0B reserved for AI surfaces
- `GeminiSidePanel.swift`: all `Color.orange` → `HiveBrand.aiAccent` (10 sites: provider colors, confidence dots, status fills)

### U9 ✅ Landing page honey pass — COMPLETE
- `web/styles.css`: warm cn-* neutrals, honey accent/glow/gradient, mono font var, honey CTA hover
- `web/index.html`: honey logo fills, `⌘A — ask Hive anything` mono hero eyebrow

### Verification
- 1063/142 tests ✅ · build ✅ · bundle ✅ · smoke ✅
- **CDP live**: accent `#F97316`, ⌘A opens dock, hero "Ask Hive anything", input focused, submit closes dock + shows AI panel; screenshots `.hive/mission/evidence/hive-u2-agentdock.png`

### Security hardening pass (code review findings — all fixed)
- **CRITICAL XSS**: `buildBriefJSON()` escaper now neutralizes `<` `>` `&` + U+2028/2029 + control chars (\u-escaped) — a malicious tab title can never break out of the brief's `<script id="brief-data">` tag. 3 new regression tests (script-breakout, JSON round-trip, control chars). **CDP-verified**: `window.__pwned` stays 0 with an evil title, blob parses as valid JSON.
- **Duplicate listener bug**: `btnOpenBrief` wired once at init, removed from `renderStartPage()` (was stacking a listener per refresh → N navigations per click).
- **Stale accent defaults → honey**: `sanitizeHex` fallback #8E5FEB→#F97316; workspace/profile/onboarding defaults #F5A623→#F97316; `hive.createWorkspace` default.
- `WebChromeAssets.mimeType` split into chrome + brief variants (dead brief cases removed).

### U5 ✅ Brief as new-tab default — COMPLETE (taste decision #6, delayed from previous pass)
- `BrowserChromePreferences.openBriefOnNewTab` (default **true**, forward-compatible `decodeIfPresent`) + HiveCore tests
- `SessionData` persists the field (field/CodingKeys/init/decode/encode, default true → older sessions restore to brief)
- `newTab()` resolution: explicit URL → as given; **isPrivate → start page** (the brief is browsing-data-derived and must never surface in a private window); else brief if pref, else start page
- `BrowserState.webChromeBriefURL` (`hive://brief`); runtime pref with `didSet` autosave; restore-site mapping
- Settings → Appearance → "New Tab" segmented picker (Morning Brief / Start Page)
- **CDP-verified (CFFIXED_USER_HOME-isolated fresh profile)**: initial tab = `hive://brief/`, title "The Hive Brief", `#brief-data` present → `PASS`. Private guard: `hive.newPrivateTab` lands on `hive://start/` → `PASS`. Evidence: `.hive/mission/evidence/hive-newtab-brief.png`
- **Privacy follow-up (code review)**: `buildBriefJSON()` now skips `tab.isPrivate` tabs — a private tab's title/URL can never appear in a normal-profile brief

### U8 ✅ Bridge inventory contract tests — COMPLETE (Eng critical, decision #16)
- NEW `WebChromeBridgeContractTests.swift` (5 tests): every `hive.*` method called from `WebChrome/app.js` is registered in `WebChromeHandler.swift`; registered surface non-empty (69); critical feature methods (tabs/council/agent/split/layout) present; 11 agent tool methods present; `docs/WEB_CHROME_BRIDGE.md` exists
- Robust extraction: registered side strips `//` comments (a commented-out registration can't mask a removal); called side matches `api(...)` call sites only (direct + ternary `api(s.tabID ? 'hive.selectTab' : 'hive.navigate', …)`) — no false-positive whitelist

### DX ✅ Bridge reference doc — COMPLETE (DX review action, docs 3/10)
- NEW `docs/WEB_CHROME_BRIDGE.md`: token-gated `api(name, params)` contract, add-a-method steps, full 69-method inventory grouped by domain

### Verification (this pass)
- `swift build` ✅ · `swift test` ✅ **1072/143** (was 1066) · bundle ✅ · smoke ✅
- CDP: new-tab default → brief PASS; private tab → start page PASS; screenshots `.hive/mission/evidence/hive-newtab-brief.png`

### ℹ️ Renderer count — verified within design envelope (corrected record)
- **Observed (CDP /json)**: content browsers = `tabs + 2`, linear with tab count (1→3→5→6→7→8→9→10→11 across 9 tabs). Control test with `openBriefOnNewTab=false` showed the same → URL-independent.
- **Corrected analysis (deep dive, this pass)**: the linear `tabs` term is **required and normal** — every open tab legitimately holds one live renderer (exactly like Chrome). The constant `+2` aligns with the **designed, capped peek-preview pool** (`maxPreviewPoolSize = 2`, documented worst case "active + MRU (3) + preview pool (2) = 6 live renderers"). Growth is linear, NOT compounding — no unbounded leak demonstrated. The earlier "leak" framing was overstated.
- **Stall investigation — CLOSED as harness artifact (deep dive, this pass)**: the transient /json + shell-CDP unresponsiveness after bridge `hive.newTab` was **reproduced, instrumented, and root-caused to the test harness, not the app**.
  - Evidence: (1) during the alleged "wedge", the app's main thread was **idle in the run loop** (`mach_msg2_trap` in `CFRunLoopServiceMachPort`) — state `S`, healthy; (2) all processes at ~0% CPU — nothing hot, no busy loop, no V8 GC; (3) `/json` answered **instantly** during the "wedge"; (4) `session.json` never advanced because the frames were rejected at the socket layer — the invoke never reached JS; (5) no crash reports (DiagnosticReports clean).
  - Root cause: two of my CDP clients connected via **raw TCP with no RFC6455 WebSocket Upgrade handshake** (server closes non-upgraded connections instantly — the `dt=0.0s` reset signature) and the earlier stall probes **reused one websocket session** across operations, so once `newTab` churned targets the dead session produced 6–25s "stalls" until `BrokenPipeError`.
  - **Clean verification (correct handshake + fresh session per op)**: baseline `/json` 6ms / shell eval 7ms → `hive.newTab` invoke **39ms** → subsequent `/json` 1–10ms and shell eval 1ms at every checkpoint → `session.json` advanced to 2 tabs. **Tab creation is fast, stable, and fully responsive.**
  - The `#if DEBUG`-gated `remoteDebuggingPort = 9223` only exists in ad-hoc (debug-config) validation bundles; a real release build closes the port.
- **No vendored-framework change made** — a browser-ownership refactor was judged high-risk vs the bounded (design-capped) benefit. Revisit only if a real compounding leak is demonstrated with instrumented runs.

### 🔒 Security hardening — DevTools port now explicit opt-in (this pass)
- `remoteDebuggingPort = 9223` is an **unauthenticated control surface** (any local process can drive the browser over loopback CDP). It was `#if DEBUG`-only, so *every* debug build and ad-hoc validation bundle exposed it on a well-known port.
- **Change**: the port now requires `#if DEBUG` **AND** `HIVE_DEBUG_CDP=1`. Routine debug builds and ad-hoc bundles stay closed by default; engineers opt in explicitly for harness work.
- **Verified live** (fresh `dist/Hive.app`, retry loops): without the var → port CLOSED, 0 DevTools log lines; with the var → port OPEN, DevTools listening logged, `/json` lists 2 targets.
- **No consumers break**: `CDPClient` (agent tools) is in-process (`wireSend`/`handleResponse`), not socket-based; no scripts reference 9223.
- In-process agentic CDP (`CefBrowserHost.sendDevToolsMessage`) remains the production path per ROADMAP_2027 (updated to reflect the new gate).

## 9. Success Criteria

- The browser looks unmistakably premium: Polar-grade design system, Dia-grade brief, Zen-grade vertical tabs.
- Every AI feature shows all 5 interaction states.
- 1058 tests still pass; build + smoke + release bundle green.
- Screenshots captured for visual review (`.hive/mission/evidence/ui-v2-*.png`).

---

## 10. Phase 1: CEO Review (2026-08-08)

### CEO DUAL VOICES — CONSENSUS TABLE

```
  Dimension                           Voice 1 (Strategist)  Voice 2 (Startup CEO)  Consensus
  ──────────────────────────────────── ──────────────────── ─────────────────────── ─────────
  1. Premises valid?                   Partially            Partially              DISAGREE
  2. Right problem to solve?           Yes, reframe         Yes, reframe           CONFIRMED
  3. Scope calibration correct?        No (over-scoped)     No (under-sequenced)   CONFIRMED
  4. Alternatives sufficiently explored? No                 No (brief-first)       CONFIRMED
  5. Competitive/market risks covered? No (legal)           No (distribution)      CONFIRMED
  6. 6-month trajectory sound?         Partially            No (notarization)      DISAGREE
```

### Premise Gate (user to confirm at final gate)

- **P1: Copying from Polar/Dia bundles is safe.** ⚠️ BOTH voices flag legal risk — copying proprietary CSS/JS/HTML verbatim is copyright infringement even with branding swapped. Tokens (hex/values), OFL fonts (Manrope, JetBrains Mono), MIT libs (KaTeX, mermaid) are safe; implementation code is not. Fix: extract token *values* + component *behavior*, write original implementation. (feasibility/legal risk, not just preference)
- **P2: UI polish is the right zero-user investment.** User's explicit direction. Voices accept but insist the *AI surfaces* (brief, agent) are the wow, not the shell. Fix: reorder brief before shell polish.
- **P3: 12.5-day budget realistic.** Voices flag optimistic for ~10k lines. Fix: staged screenshot gates.

### Voice findings applied to plan

1. **Legal (critical):** rewrite §0/§3 to "extract patterns, write original implementation" — only license-clean assets (fonts OFL, KaTeX/mermaid MIT, Astro AGPL→rewritten) are copied verbatim.
2. **AIResult reuse (medium):** §6 extends existing `Sources/HiveCore/AI/AIResult.swift`, no parallel system.
3. **Bridge contract (medium):** U2 adds a bridge inventory — every registered `hive.*` handler enumerated; new JS must call all.
4. **GeminiSidePanel (medium):** destroy UI, keep state bindings (`latestCouncilVerdict`, `deepResearchStep`, `agentTask`, `councilLiveResponses`) + bridge surface stable.
5. **Polar assets (medium):** U4 budgets base-path rewrites + font bundling for hashed bundles.
6. **Screenshot gate (low):** visual milestone after shell rebuild before brief port.
7. **Zen/Brave (low):** interaction models adopted, code not portable (Firefox CSS / C++).
8. **Brief-first (high):** Morning Brief moves before shell polish — it's the daily habit loop + the wow.
9. **Landing page (high):** rebuild `web/` with U1 tokens — same design system doubles as marketing.
10. **Notarization (high):** flagged as hard blocker on distribution; script exists, credentials needed.

### Error & Rescue Registry

| Failure | Detection | Rescue |
|---------|-----------|--------|
| Bridge call renamed in new JS | `api('hive.x')` returns error | Bridge inventory checklist in U2; console error sweep |
| Design tokens drift between CSS/Swift | Visual mismatch in screenshots | Single token source of truth, mirror in HiveDesign.swift |
| Brief data bridge breaks | `hive://brief` blank | Fallback to static sample brief |
| Side panel logic regression | Council stops streaming | Keep old file in git; restyle not reimplement |

### Failure Modes Registry

| Mode | Severity | Mitigation |
|------|----------|-----------|
| 12-day UI slip with zero user signal | High | Screenshot gates + ship brief first |
| Legal takedown from verbatim copy | Critical | Pattern extraction only; license-clean assets only |
| Users bounce: no notarization | High | Elevate notarization to critical path |
| Forgettable browser (no signature) | High | Morning Brief as new-tab default |

### NOT in scope (this plan)

- Backend features, sync, cross-platform, monetization, Sparkle, crash-report submission
- Notarization *credentials acquisition* (flagged, owned by user)
- Copying Comet/Zen/Brave implementation code (not portable / native-compiled)

### What already exists (leverage map)

| Sub-problem | Existing code |
|-------------|--------------|
| 5 interaction states | `Sources/HiveCore/AI/AIResult.swift` + tests |
| Vertical tabs/workspaces/compact | `VerticalChromeView.swift`, `BrowserState` |
| Council/research/agent data | `BrowserState` DTOs → `WebChromeStartData` |
| Agent pipeline UI (partial) | `renderAIPanel()` in app.js |
| Design tokens (SwiftUI) | `Sources/Hive/Design/HiveDesign.swift` (421 lines) |
| CDP tools | `CEFDevToolsClient.swift` + bridge handlers |
| Morning-brief source | Dia bundle (copyable patterns) |
| Agent surface source | Polar AgentApp bundle (copyable patterns) |

### Dream State Delta

**Current:** functional browser, generic UI, zero users, ad-hoc signed.
**This plan:** Polar-grade design system, Dia-grade Morning Brief, Zen-grade vertical tabs, agent-first AI surface.
**12-month ideal:** AI-first browser where the brief is the daily reason to open, agent is the way you browse, UI is premium enough to screenshot-share.

### CEO Completion Summary

| Dimension | Score |
|-----------|-------|
| Problem clarity | 7/10 |
| Scope calibration | 5/10 (reorder + legal fix needed) |
| Competitive positioning | 6/10 (brief = signature) |
| Timeline realism | 5/10 |
| Risk coverage | 5/10 (legal + distribution) |
| Monetization | N/A (out of scope) |

**CEO verdict: APPROVE WITH MODIFICATIONS.**

**PHASE 1 COMPLETE.** Voices: Strategist 7 findings, Startup CEO 4 findings. Consensus 4/6 confirmed. Premise P1 (legal) + reorder + distribution flagged → surfaced at gate. Passing to Phase 2.

---

## 11. Phase 2: Design Review (2026-08-08)

### DESIGN LITMUS SCORECARD (dual voices)

```
  Dimension                           Voice 1 (Product Designer)  Voice 2 (Visual Critic)  Consensus
  ──────────────────────────────────── ───────────────────────── ───────────────────────── ─────────
  1. Information hierarchy            6/10 (entry-point ambiguity)   —                     CONFIRMED
  2. Interaction states               4/10 (no first-run states)     —                     CONFIRMED
  3. Design system consistency        4/10 (brief vs shell clash)    4/10 (micro-details)   CONFIRMED
  4. Responsive strategy              5/10 (no resize/drag spec)     —                     CONFIRMED
  5. Accessibility                    3/10 (no contrast/keyboard)    —                     CONFIRMED
  6. Animation/motion                 4/10 (no motion budget)        —                     CONFIRMED
  7. Visual polish                    5/10 (identity undefined)      4/10 (no micro-spec)  CONFIRMED
  Overall                             4.5/10                         4.5/10                CONFIRMED
```

### Findings applied (severity-ranked)

1. **Micro-detail spec (critical, V2):** U2 adds: favicon monogram fallback (rounded 4px, first-letter + site color), tab-pill geometry (8px radius, 100ms ease), thin scrollbars (8px, transparent track, hover-only color), traffic-light integration, hairline recipe (`hsla(0,0%,100%,.08)`), Manrope letter-spacing tokens (-0.02em display).
2. **Brief keeps editorial voice (high, V2):** do NOT re-token the brief into the product system — keep serif display (bundle OFL Newsreader/Fraunces), halftone, scroll-reveal (gated by prefers-reduced-motion). Two voices deliberately separated by surface.
3. **Fonts (medium-high, V2):** UI face = Inter or system SF (Manrope reads "AI startup template" 2026); JetBrains Mono stays for AI output; serif only on editorial surfaces.
4. **Signature accent (high, V2, taste):** keep honey identity but push orange-ward brighter (#F97316-adjacent honey-orange); amber = AI-only semantic (never alerts); carry through monogram + AI button.
5. **Per-tab AI signature (high, V2):** amber live-dot/status ring on tab favicons for agent-touched tabs + amber AI button bottom-left of vertical rail. 30 lines CSS + one state field.
6. **First-run empty states (critical, V1):** brief/start page/palette need designed empty states (day-1 = no history). Map to AIResult states.
7. **Resolve agent entry point (high, V1):** pick ONE: agent input in address bar default state, or persistent AI panel input. Plan defaults to AI-panel input with ⌘K quick access (comet-style); address bar stays URL-first.
8. **Motion budget (medium, V1+V2):** content area never animates on tab switch; sidebar/panel/peek may; reduced-motion gates scroll-reveal + pulse.
9. **Accessibility (medium, V1):** WCAG AA contrast targets, keyboard nav spec for palette/agent input, focus-trap for modal surfaces, reduced-motion handling.
10. **Brief data = existing sources only (high, V1):** map to `topDomainsFromHistory()`, hot-memory nodes, recent items. No invented "tasks" model.
11. **Sidebar drag-resize (medium, V1):** add drag handle + min/max widths (Zen/Arc parity).

### Design Completion Summary

| Dimension | Score |
|-----------|-------|
| Information Hierarchy | 6/10 |
| Interaction States | 4/10 |
| Design System Consistency | 4/10 |
| Responsive Strategy | 5/10 |
| Accessibility | 3/10 |
| Animation/Motion | 4/10 |
| Visual Polish | 5/10 |
| **Overall** | **4.5/10 → 7/10 with fixes applied** |

**Design verdict: APPROVE WITH MODIFICATIONS.** 11 fixes; micro-detail spec + first-run states + signature identity are the load-bearing ones.

**PHASE 2 COMPLETE.** Voices: Product Designer 10 findings, Visual Critic 5 findings. Consensus 7/7 confirmed. Passing to Phase 3.

---

## 12. Phase 3: Eng Review (2026-08-08)

### ENG CONSENSUS

```
  Dimension                           Verdict                                   Consensus
  ──────────────────────────────────── ───────────────────────────────────────  ─────────
  1. Architecture sound?               Sound; embedding route must change        DISAGREE
  2. Test coverage sufficient?         No — bridge inventory + DTO round-trip    CONFIRMED
  3. Performance risks addressed?      No — fonts, backdrop-filter, reveal       CONFIRMED
  4. Security threats covered?         Bridge surface noted; no new attack       CONFIRMED
  5. Error paths handled?              Partially — brief cache/offline missing    CONFIRMED
  6. Deployment risk manageable?       No — 2 internal contradictions            CONFIRMED
```

### Findings applied (severity-ranked)

1. **Asset embedding (critical):** add U0 sub-step — serve web chrome + brief from `Bundle.module` resources via the existing `hive://` scheme handler, not `WebChromeAssets.swift` string literals. Keeps Swift compile fast, solves Polar `/assets/` absolute paths.
2. **Bridge inventory = test artifact (critical):** add test enumerating every `bridge.register("hive.*")` in `WebChromeHandler.swift`, asserting each name appears in the new JS. Runtime console-error sweep in smoke test (`window.onerror`).
3. **DTO contract (critical):** add `WebChromeStartData` round-trip test (encode→decode→all fields survive); JS `apply(data)` logs unknown keys in debug.
4. **Brief data caching (high):** brief JSON cached to disk keyed by date, rendered from cache instantly, refreshed async; offline-safe (honeycomb + history are local); day-1 empty = designed welcome card.
5. **GeminiSidePanel reconciliation (high):** body amended — rebuild view layer, keep logic layer (streaming, diagnostics, bindings).
6. **Polar bundles (medium):** base-path rewrite + font bundling + license verify (KaTeX MIT, mermaid MIT, xlsx Apache-2.0) budgeted in U4.
7. **Fonts/perf (medium):** `font-display: swap` + preload; backdrop-blur compositing check on always-on chrome; scroll-reveal (IntersectionObserver) verified early inside CEF.
8. **Theme injection (medium):** `data-surface`/`data-theme` injected via scheme handler/bridge, not URL params.

### Test Diagram (codepaths → coverage)

| Codepath | Test | Status |
|----------|------|--------|
| WebChromeStartData JSON round-trip | DTO round-trip test | NEW |
| Bridge registration ↔ JS callers | Bridge inventory test | NEW |
| Chrome loads w/o console errors | Smoke test `window.onerror` sweep | NEW |
| Brief JSON build (cache, offline) | buildBriefData tests (cache hit/miss, empty) | NEW |
| Session/DTO shapes | Existing BrowserSessionIntegrityTests | EXISTS |
| SwiftUI restyle (no logic change) | Build + existing 1058 tests | EXISTS |

### Failure Modes (Eng)

| Mode | Severity | Mitigation |
|------|----------|-----------|
| 15k-line Swift asset literal breaks build | Critical | U0 bundle-resource route |
| Renamed bridge call silently kills feature | Critical | Bridge inventory test |
| Brief blocks first paint | High | Cache-first render, async refresh |
| DTO field removal silently drops state | Critical | Round-trip test + debug logging |

**Eng verdict: APPROVE WITH MODIFICATIONS.** 3 criticals (embedding route, bridge test, DTO contract) + reconcile 2 contradictions (execution order, legal framing).

**PHASE 3 COMPLETE.** Passing to Phase 3.5 (DX — light, bridge surface).

---

## 13. Phase 3.5: DX Review (light)

**Scope:** light — the only developer-facing surface is the `hive.*` bridge API (used by the web chrome + future extensions).

| Dimension | Score | Note |
|-----------|-------|------|
| API design | 6/10 | `hive.<domain>.<action>` naming is consistent |
| Error messages | 5/10 | Bridge errors → JS `api()` rejects; surface in console |
| Documentation | 3/10 | No bridge API doc exists; plan should add `docs/WEB_CHROME_BRIDGE.md` |
| Dev environment | 7/10 | `swift build` + smoke are fast |

**DX verdict: SKIP deep review** (end-user product). One action: the rebuilt JS should keep the `api(name, params)` signature stable — it's the contract extensions will use.

**PHASE 3.5 COMPLETE.** Passing to Phase 4 (Final Gate).

---

## 14. Phase 4: Final Approval Gate (2026-08-08)

**Decision: APPROVED AS-IS** (user, with one explicit resolution).

- **Challenge 1 (legal) RESOLVED by user:** "I have explicit permissions to copy code in a legal document signed by both parties. Literally copy everything you want." — Verbatim copying from the Dia/Polar bundles is **authorized**. The body's "copy verbatim" language stands. Only branding swaps + license-clean asset bundling (fonts/lib paths) still apply as engineering practice.
- All other recommendations accepted as-is: brief-first order, Inter for UI face, JetBrains Mono for AI output, serif for editorial surfaces, honey-orange accent (amber = AI-only), agent entry in AI panel + ⌘K, brief as new-tab default, editorial brief voice kept, micro-detail spec, 5-state sweep, U0 bundle-resource embedding, bridge inventory + DTO round-trip tests.

## Decision Audit Trail

| # | Phase | Decision | Classification | Principle |
|---|-------|----------|-----------|-----------|
| 1 | CEO | Pattern extraction vs verbatim copy → **verbatim AUTHORIZED by user (legal doc)** | User Challenge resolved | P1 |
| 2 | CEO | Brief-first execution order | Auto-decided (challenge) | P6 |
| 3 | CEO | Inter for UI face (not Manrope) | Auto-decided | P5 |
| 4 | CEO | Honey-orange #F97316 accent, amber=AI-only | Taste | P5 |
| 5 | CEO | Agent entry: AI panel + ⌘K, URL-first address bar | Taste | P5 |
| 6 | CEO | Brief as new-tab default | Taste | P6 |
| 7 | Design | Keep brief editorial voice (serif+halftone+reveal) | Auto-decided | P1 |
| 8 | Design | Micro-detail spec (favicon, pills, scrollbars, hairline) | Auto-decided | P1 |
| 9 | Design | First-run empty states designed | Auto-decided | P1 |
| 10 | Design | Motion budget: content never animates | Auto-decided | P5 |
| 11 | Design | A11y: WCAG AA, focus traps, reduced-motion | Auto-decided | P1 |
| 12 | Design | Brief data from existing sources only | Auto-decided | P4 |
| 13 | Design | Sidebar drag-resize | Auto-decided | P5 |
| 14 | Design | Per-tab AI pulse signature | Auto-decided | P5 |
| 15 | Eng | U0 bundle-resource embedding (scheme handler) | Auto-decided | P5 |
| 16 | Eng | Bridge inventory test | Auto-decided | P1 |
| 17 | Eng | DTO round-trip test + debug key logging | Auto-decided | P1 |
| 18 | Eng | Brief disk cache + async refresh | Auto-decided | P1 |
| 19 | Eng | GeminiSidePanel: rebuild view, keep logic | Auto-decided | P4 |
| 20 | Eng | font-display swap, backdrop-filter check, reveal-in-CEF | Auto-decided | P1 |
| 21 | DX | api(name, params) stable contract | Auto-decided | P5 |

**APPROVED. Ship it.**
