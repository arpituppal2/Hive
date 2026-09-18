# Design Plan Review — Hive v2 Wedge Test

Plan reviewed: `docs/designs/hive-v2-wedge-test.md` (commit 96c21859, status APPROVED)
Review method: gstack `/plan-design-review` (designer's-eye 7-pass methodology)
Date: 2026-08-23

## Assumptions (stated up front)

This review ran non-interactively per task instruction. Where the skill would
normally pause for the user, reasonable decisions were made and are marked
**[auto-decision]**:

1. Review target = the plan file named above (scope gate option B).
2. Mockup generation skipped: no design binary wired into this environment, and
   the deliverable here is a written review. The report specifies mockup work as
   a W1 task instead of producing throwaway artifacts now.
3. "Founder taste" is treated as the scarce resource the process must protect;
   recommendations optimize for cheap, frequent taste-checkpoints rather than
   big up-front design documents.

## Pre-review audit

- **No DESIGN.md exists.** The repo carries no active design system.
  `design-system/hive-browser/pages/` is an empty directory left by the reset.
- **The surviving v1 design system is the wrong shape for chrome.**
  `references/prior-art/hive-design-system/hive-browser/MASTER.md` is a
  landing-page system: teal `#0D9488` primary, orange `#EA580C` CTA, Inter
  everywhere, card/button/modal CSS, GSAP load staggers, a "Hero > Features >
  CTA" section order. Almost none of it applies to a tab strip, sidebar, or
  omnibox. A browser built from this vocabulary gets marketing-page bones, and
  marketing-page bones are one plausible cause of v1's "fundamentally impossible
  to use" chrome. Reusing it wholesale would repeat the mistake.
- **Prior reviews exist but none are design reviews.** Git history shows CEO
  approval and an adversarial review scoring 9/10 — both strategy-tier. Neither
  evaluated pixel-level or interaction-level decisions, because the plan barely
  contains any. This pass is the first to look.
- **UI scope:** large. Single-window macOS browser: vertical tab sidebar,
  omnibox toolbar, capture control, ask-with-citations panel, orientation
  switcher (timeboxed), settings surface, first-run/download flow. This plan is
  mostly UI. The review proceeds.

## Step 0 — Initial design completeness rating

**Overall: 2.5/10.**

The plan is rigorous about everything it can count: bridge contract tests,
golden-set thresholds, retention denominators, floor-machine performance. But
its own problem statement says v1 died because the UI was unusable, and the
founder's stated #1 pain is chrome quality — yet the plan contains zero
designed pixels. The phrase "executed to the Zen bar" (Premise 3, line 70) is
the entire chrome specification. It is a vibe, not a spec, and AI agent builders
cannot implement a vibe. Quality gates catch broken; they do not produce
excellent. The plan measures whether the chrome works and hopes it's good.

**What a 10 looks like for THIS plan:** a companion chrome spec that (a) shows
the window layout as a diagram with regions and z-order, (b) names tokens —
type, spacing, color roles, radii, motion durations and easings — mined from the
Zen and Comet references, (c) gives per-component interaction specs including
all states, (d) defines "Zen bar" as a scored checklist with screenshot
comparisons, and (e) bakes a dogfooding/screenshot-review loop into W1-W5 so
taste is exercised weekly, not asserted at W5.

---

## Pass 1 — Information Architecture: 3/10

The plan names surfaces (tabs, omnibox, capture, ask) but never places them.
Nothing defines: what lives in the left sidebar vs the top toolbar; where the
capture button sits; whether Ask is a panel, popover, or sidebar section; what
happens to content width when it opens; where traffic-light window buttons go
(Zen integrates them into the sidebar header); whether there is a single
toolbar (Zen's single-toolbar mode) or two bars.

**Fix to 10:** add a window-region diagram and a navigation flow to the plan.
Constraint-worship pass — the chrome shows exactly four persistent things:
sidebar (tabs), toolbar (omnibox + nav + capture), content, and (on demand) the
ask panel. Everything else is hidden behind overflow menus. Concretely:

```
+--------+---------------------------------------------------+
| [][ ][]|  <- back/fwd/reload | omnibox............ | cap | ask |
| tabs   +---------------------------------------------------+
| ...    |                                                   |
|        |               web content                         |
| [+ new]|                                                   |
+--------+---------------------------------------------------+
   ^ single left sidebar: traffic lights + tabs + new-tab,
     collapsible to a 34px icon rail (Zen pattern)
```

Ask panel opens docked right or as an overlay sheet — pick one in W1, because
content reflow behavior differs and it touches the bridge inventory
(`ask.request/stream-chunk` needs a layout contract too).

## Pass 2 — Interaction State Coverage: 4/10

Credit where due: capture failure ("Couldn't extract this page" + raw-text
fallback, line 111) and Ask refusal (line 125) are specified. Those are the two
hardest states in the product and they're covered. But chrome states are absent:

```
FEATURE        | LOADING         | EMPTY            | ERROR            | SUCCESS      | PARTIAL
---------------|-----------------|------------------|------------------|--------------|------------------
Tab            | spinner favicon | n/a              | crash/page-error | loaded title | restored w/o history
Sidebar (0 tabs)| n/a            | warm empty state?| n/a              | n/a          | n/a
Omnibox        | inline progress | hint text        | DNS/offline page | n/a          | n/a
Capture        | button state?   | n/a              | specified ✓      | confirm anim?| SPA viewport-only
Ask panel      | stream chunks ✓ | "nothing captured yet" warmth | refusal ✓ | cited answer | claim dropped mid-answer
First run      | 3GB dl progress | n/a              | resume/fail UX   | ready        | n/a
```

Unspecified today: what the user SEES while a capture is in flight (button
spinner? toast?), whether a successful capture confirms itself or stays silent,
what the sidebar looks like with zero tabs on first launch, what Ask shows
before the first capture exists (this is the tester's first impression of the
wedge feature), and what a dropped-claim looks like mid-stream when the
validate-retry loop removes a citation from a rendered answer.

**Fix to 10:** every row above gets a one-line visual description in the plan.
Empty states get warmth + a primary action (skill principle: empty states are
features) — e.g. zero-capture Ask state reads "Capture a page and I can answer
from it" with a capture-button highlight, not blank.

## Pass 3 — User Journey & Emotional Arc: 2/10

No journey is described anywhere. The wedge sentence sells a feeling — "your
browser remembers" — and the plan designs none of the moments that create it.
Time horizons:

- **First 5 seconds (visceral):** launch → signed shell renders. Is there a
  flash of unstyled chrome? Does the sidebar animate in or pop? v1 testers
  churned on feel; this moment decides the demo's fate ("demoable in one take",
  line 75, is a feelings claim with no feelings design).
- **First 5 minutes (behavioral):** the magic loop is browse → capture → ask →
  see citation. The citation click-through (does tapping a citation highlight
  the stored span? scroll a reader view?) is unspecified — and it is THE moment
  that proves local memory is real.
- **Week 2 (reflective):** trust that captures are private and permanent. The
  plan handles privacy truthfully in architecture but never surfaces it in UI —
  one line in Settings ("N captures stored locally, never uploaded") converts
  the differentiator into something a tester can point at.

**Fix to 10:** storyboard the first-session arc in five scenes (launch, first
page, first capture, first answer, second-day return) and specify one designed
detail per scene. The first-capture confirmation and the first cited answer are
the two scenes that deserve actual motion design.

## Pass 4 — Specificity / AI Slop Risk: 2/10

Classified as APP UI (workspace-driven, task-focused) — landing-page hard
rejections don't apply, App UI rules do: calm surface hierarchy, dense but
readable, minimal chrome, utility language.

The plan describes zero specific UI. No typeface, no type scale, no color
roles, no spacing values, no radii, no easing curves. Meanwhile the references
sit ten feet away with exact answers:

- Zen chrome: collapsed rail `--tab-collapsed-width: 34px`; compact mode
  `--tab-min-width: 48px` + `6px` gutter (`references/zen-desktop/src/zen/tabs/
  zen-tabs/vertical-tabs.css:436,697-699`); micro-transitions `0.1-0.2s`
  ease-in-out throughout (`zen-theme.css:204`, `vertical-tabs.css:205`); compact
  reveal delay `0.2s` (`vertical-tabs-topbar.inc.css:19`).
- Comet captured shell: dark default with light variant, Manrope + JetBrains
  Mono, native→web theming via injected params (`references/prior-art/
  comet-polar-ui/index.html:8-23`) — a working precedent for v2's exact
  web-chrome architecture.

Also flagged: the slop blacklist's item 11 — v1's MASTER.md uses Inter for
everything, the canonical "gave up on typography" signal. Do not inherit it.

**Fix to 10:** a token block in the plan (see Implementation Tasks T1). One
display/UI face + one mono for citations (Manrope/JetBrains Mono is already
proven in the Comet reference and reads technical-premium; anything but Inter-
by-default). Motion budget: chrome moves at 120-200ms ease-out, nothing bounces
(v1 MASTER.md's `back.out(1.4)` staggers are explicitly wrong for informational
UI — its own notes say so).

## Pass 5 — Design System Alignment: 1/10

No DESIGN.md, so there is nothing to align to — and the only candidate artifact
is misfit (see audit). Worse, the plan's Dependencies section mines `archive/v1`
for engineering parts (CEF patterns, adblock FFI, FTS schema) and never says
what, if anything, survives from the v1 design language. Silent inheritance is
how the teal/orange landing system leaks into v2 chrome.

**Fix to 10:** one paragraph in the plan titled "Design system disposition":
v1 MASTER.md is archived as reference-only; no tokens carry forward; W1 ships a
new `CHROME-SPEC.md` (tokens + components + states) as the single source agents
implement against. This costs 30 minutes and prevents an entire class of
accidental retro-design.

## Pass 6 — Responsive & Accessibility: 2/10

Desktop-only macOS, so "responsive" means window behavior — and browsers get
resized constantly. Unspecified: minimum window size; what the sidebar does
below ~900px width (auto-collapse to the 34px rail is the Zen answer); whether
compact mode (hover-edge reveal, sidebar floats OVER content) is in scope at
all; fullscreen video behavior; the toolbar's breakpoint when omnibox truncates.

Accessibility is absent, and for a browser, keyboard support IS the product,
not an accommodation: Cmd+T/Cmd+W, Cmd+L omnibox focus, Cmd+Shift+A tab search,
arrow-key tab navigation, visible focus rings on every chrome control, 4.5:1
contrast on all chrome text, ≥28px hit targets on tab close buttons. None are
named. Note the nine core flows are scripted via CDP — CDP clicks coordinates,
so a build could pass all nine flows with completely broken keyboard support.

**Fix to 10:** add a keyboard map table and window-breakpoint rules to the
plan; extend one E2E assertion to keyboard-only execution of navigate/new-tab/
switch (cheap, catches the worst case).

## Pass 7 — Unresolved Design Decisions

Decisions that will haunt implementation if left ambiguous:

| Decision needed | If deferred, what happens |
|---|---|
| Sidebar: pinned / collapsible-to-rail / compact-overlay — which modes ship? | Agent builds a plain static column; "slides properly on the left" never happens; v1 repeats |
| Where Ask lives (docked panel vs overlay) | Two half-implementations fighting over content-area resize logic |
| Traffic lights inside sidebar header or floating? | Ugly default CEF titlebar or overlapping buttons — instant "unpolished" read on first screenshot |
| Dark/light default + theming contract | Every component hardcodes colors; dark mode becomes a W6 retrofit |
| Tab overflow at 40+ tabs (scroll? shrink? group?) | Tester with real workload hits jank or unusable squish — exactly who you recruited |
| First-run: download UX + empty states sequence | 3GB resumable download is mentioned (line 192) with zero UI description; testers bounce at minute zero |
| Citation click-through presentation | The proof-of-memory moment ships as raw text |
| What "switcher overruns" means, numerically | Timebox quietly stretches; half-built toggle ships broken (v1 pattern) |

Each needs one decision line in the plan. Recommendations embedded in tasks
below. **[auto-decision]** In a normal interactive run these become eight
sequential AskUserQuestions; here they are surfaced as the open-items list the
founder resolves in one sitting.

---

## The five review dimensions (task-specific deep dive)

### 1. Does the plan say enough about HOW chrome quality gets achieved?

No — and this is the review's central finding. The plan achieves quality
*assurance* (contract tests, nine CDP flows, golden-set eval, floor-machine
gates) and confuses it with quality *creation*. Gates verify behavior; they
cannot verify feel. A tab can close correctly in an E2E test while the sidebar
janks, the focus ring is invisible, and the whole thing looks like a dev build.

What "Zen-grade" actually costs, measured in the reference clone: Zen's
polished sidebar behavior spans `ZenCompactMode.mjs` (35.5KB of logic), a
platform-native edge-hit detector (`ZenMouseTracker.cpp/.mm` — C++ on Windows,
Objective-C++ on macOS), and hundreds of lines of layout CSS resolving
interactions like "collapsed sidebar under reversed window buttons"
(`zen-tabs.css:84-108`). None of this is reachable from the words "executed to
the Zen bar." It is reachable from: steal their numbers (widths, timings),
steal their state matrix, and iterate against screenshots.

The plan needs an achievement mechanism, not just a bar: CHROME-SPEC.md as the
agents' implementation contract (W1), plus the screenshot-diff and dogfooding
loops specified in section 5 below.

### 2. Is the timeboxed switcher with vertical-only fallback the right call?

Yes — correct scope discipline, and the product-quality gate already honors the
fallback ("tab-orientation switch (or documented vertical-only fallback)",
line 219). Vertical-first matches both the founder's daily reality and the Zen
reference. Three tightenings required:

1. Define the timebox numerically. "Overruns" needs a trigger: e.g. end of W2
   without an end-to-end working toggle demo = cut. Otherwise a timebox
   silently becomes a stretch goal — the exact scope-absorption the slip policy
   (line 182-184) forbids everywhere else.
2. Add the half-ship rule: a partially working switcher NEVER ships, even
   behind a flag. v1's death mode was shipping mechanisms that sort-of worked.
   The fallback must be binary: complete toggle or no toggle.
3. If cut, record it visibly (settings note or release note to testers) so W5+
   testers treat horizontal absence as roadmap, not bug — otherwise your pricing
   probe collects "missing feature" noise instead of demand signal.

### 3. What's missing to prevent repeating v1's UI failure?

Ranked by leverage:

1. **Token system (day one).** Spacing scale, type ramp, color roles, radii,
   motion durations/easings as CSS variables in one file, seeded from Zen's
   measured values (section Pass 4). Agents drift without anchors; tokens ARE
   the anchor. v1 had a design system document but the wrong one — marketing
   components, no chrome primitives.
2. **Interaction specs per component, states included.** The state table from
   Pass 2 and the sidebar/omnibox/tab specs from Passes 1/6. The bridge
   protocol section (line 139) proves the team knows how to spec a contract —
   chrome needs the same treatment: every state enumerated, every dimension
   numbered.
3. **Motion specs.** Durations + easings per transition class (reveal 160ms
   ease-out, panel slide 200ms ease-out, hover 100ms linear, compact-mode
   reveal-delay 200ms — Zen's actual values). v1's "sidebars that didn't slide"
   were arguably motion failures, not layout failures.
4. **Visual regression in CI.** Screenshot diffs of ~15 canonical chrome states
   (first run, 0/1/40 tabs, capture in-flight, ask open, error pages, collapsed
   rail) alongside the CDP behavioral tests. This is the missing twin of the
   nine-flow suite: flows prove it works, screenshots prove it looks intended.
   CEF supports offscreen capture; cost is roughly a day.
5. **Dogfooding cadence with teeth** — next section.

### 4. Is "Zen bar" defined measurably enough to gate against?

No. It appears once (line 70), undefined, and nothing in the milestones or
quality gate references it again. As written it cannot fail, and an unfailable
gate is decoration. Operationalize it as a scored checklist evaluated twice
(end of W2, end of W4) against the floor machine:

| # | Criterion | Pass condition |
|---|---|---|
| 1 | Sidebar slide/reveal animation | ≤200ms, named easing, 60fps on M1 8GB, no layout jank |
| 2 | Collapsed rail ↔ expanded toggle | 34px rail, persists across restart, no content shift flicker |
| 3 | Traffic lights integration | Inside chrome, no double titlebar, correct spacing |
| 4 | Tab anatomy | favicon + truncated title + close hit-target ≥24px, active state unmistakable |
| 5 | Omnibox | focus ring, inline progress, one-key reach (Cmd+L) |
| 6 | Side-by-side screenshot vs Zen at 3 matched states | Founder blind-rating: "which is the shipped browser?" indistinguishable or favorable |
| 7 | Keyboard completeness | Core map works, focus visible everywhere |
| 8 | Motion restraint | No bounce/overshoot on informational UI; reduced-motion honored |

Criterion 6 is the important one: it converts taste into a repeatable ritual
(side-by-side, blind-ish rating) instead of an adjective. Score <7/8 = chrome
not done, regardless of E2E green.

### 5. What design-process changes belong in W1-W5?

- **W1:** Write CHROME-SPEC.md (tokens, region diagram, component specs, state
  table, motion table, Zen-bar checklist) BEFORE bridge implementation; capture
  reference screenshots of Zen at matched states. Cost: 1-2 days, mostly
  transcription from the reference clone.
- **W2 onward:** Daily founder dogfood rule — "if I reached for Safari, file a
  chrome bug." The plan already obligates daily capture (Dependencies, line
  237); extend the same discipline to chrome feel. Weekly Friday screenshot
  review: 10 canonical states pasted beside Zen equivalents; anything that
  loses gets a ticket. This is how taste gets exercised weekly instead of being
  outsourced (the plan's own closing warning, line 256-258).
- **W3:** Screenshot-diff suite lands in CI with the E2E flows.
- **W4:** Reserve explicit polish capacity — the week currently holds only the
  eval gate and E2E; add a chrome-polish pass driven by the W4 Zen-bar scoring.
  Polish that has no calendar slot does not happen.

---

## NOT in scope (considered, deferred)

- **Compact/overlay sidebar mode** — recommend deferring to post-test. It is
  Zen's hardest feature (native edge-tracking) and orthogonal to the memory
  wedge. Ship pinned + collapse-to-rail only.
- **Workspaces/spaces, split view, glance, folders** — Zen features deliberately
  out; the plan's subtraction posture is correct. Confirm in writing so agents
  don't mine the reference clone for scope.
- **Light/dark theming beyond one default** — ship dark-first (matches Comet
  reference and category expectations), defer a theme picker.
- **Full a11y audit (VoiceOver, etc.)** — keyboard support ships; screen-reader
  depth waits for demand evidence.

## What already exists (reuse)

- `references/zen-desktop/src/zen/` — measured widths, timings, state matrix,
  CSS structure for vertical tabs and sidebar. Mine, don't reinvent. MPL-2.0:
  study freely, written permission before copying code.
- `references/prior-art/comet-polar-ui/index.html` — proven native↔web-chrome
  theming contract (injected theme/surface params) for v2's identical
  architecture, plus a viable type pairing (Manrope + JetBrains Mono).
- `references/prior-art/dia-brief-ui/` — Hive's existing brand mark (hexagon)
  and editorial tone for any first-run/welcome surface.
- Bridge contract test pattern (`WebChromeBridgeContractTests`) — extend the
  same contract-thinking to chrome visuals via the screenshot suite.

## Implementation Tasks

Synthesized from findings above.

- [ ] **T1 (P1, human: ~4h / CC: ~45min)** — CHROME-SPEC.md — tokens, region diagram, state table, motion table, Zen-bar checklist
  - Surfaced by: Passes 1-5, 7 — plan specifies zero visual decisions; agents cannot implement a vibe
  - Files: `docs/designs/chrome-spec.md`, seed values from `references/zen-desktop/src/zen/tabs/zen-tabs/vertical-tabs.css`
  - Verify: every component in the nine flows has tokens + states resolvable from this one doc
- [ ] **T2 (P1, human: ~30min / CC: ~10min)** — Plan edit: define switcher timebox trigger + no-half-ship rule
  - Surfaced by: Dimension 2 — "overruns" undefined; half-working toggles are v1's death mode
  - Files: `docs/designs/hive-v2-wedge-test.md` (Chrome row + quality gate)
  - Verify: plan states the numeric trigger and the binary ship rule
- [ ] **T3 (P1, human: ~1h / CC: ~20min)** — Plan edit: Zen-bar scored checklist into quality gate
  - Surfaced by: Dimension 4 — "Zen bar" currently unfailable
  - Files: `docs/designs/hive-v2-wedge-test.md` (Product quality gate section)
  - Verify: checklist scored at W2 and W4; <7/8 blocks external exposure
- [ ] **T4 (P1, human: ~1h / CC: ~20min)** — Plan edit: W1-W5 process additions (dogfood rule, Friday screenshot review, CI screenshot diffs, W4 polish slot)
  - Surfaced by: Dimension 5, Milestones table
  - Files: `docs/designs/hive-v2-wedge-test.md`
  - Verify: each week row gains its design-process exit criterion
- [ ] **T5 (P2, human: ~1h / CC: ~20min)** — Resolve the eight open decisions (Pass 7 table) in one sitting
  - Surfaced by: Pass 7 — each deferred row has a named failure mode
  - Files: `docs/designs/hive-v2-wedge-test.md`
  - Verify: no row of the table remains undecided before W2 starts
- [ ] **T6 (P2, human: ~1d / CC: ~3h)** — Screenshot-diff harness: ~15 canonical chrome states in CI
  - Surfaced by: Dimension 3 item 4 — flows prove behavior, screenshots prove intent
  - Files: CI config + test scaffolding (pattern: resurrected `hive-ci.yml`)
  - Verify: red/green demonstrated on an intentional style change
- [ ] **T7 (P2, human: ~2h / CC: ~30min)** — Design-system disposition paragraph (v1 MASTER.md = reference-only)
  - Surfaced by: Pass 5 — silent inheritance risk of teal/orange landing system
  - Files: `docs/designs/hive-v2-wedge-test.md`
  - Verify: no v1 token appears in chrome source
- [ ] **T8 (P3, human: follow-up / CC: follow-up)** — Empty-state copy set (0 tabs, 0 captures, first answer, refused answer)
  - Surfaced by: Pass 2 — tester's first impression of the wedge is currently blank
  - Files: CHROME-SPEC.md then implementation
  - Verify: every empty state has warmth + primary action

## Completion Summary

```
+====================================================================+
|         DESIGN PLAN REVIEW — COMPLETION SUMMARY                    |
+====================================================================+
| System Audit         | No DESIGN.md; v1 system is marketing-shape  |
| Step 0               | Initial 2.5/10                              |
| Pass 1  (Info Arch)  | 3/10  -> 8/10 with region diagram added     |
| Pass 2  (States)     | 4/10  -> 8/10 with state table added        |
| Pass 3  (Journey)    | 2/10  -> 7/10 with 5-scene storyboard       |
| Pass 4  (AI Slop)    | 2/10  -> 8/10 with token block + type pair  |
| Pass 5  (Design Sys) | 1/10  -> 8/10 with disposition + CHROME-SPEC|
| Pass 6  (Responsive) | 2/10  -> 7/10 with keyboard map + windows   |
| Pass 7  (Decisions)  | 8 surfaced, 0 resolved (non-interactive run)|
+--------------------------------------------------------------------+
| NOT in scope         | written (4 items)                           |
| What already exists  | written                                     |
| TODOS.md updates     | folded into T5-T8 (no TODOS.md exists)      |
| Approved Mockups     | 0 generated (binary unavailable; T1 covers) |
| Decisions made       | 4 [auto-decision] (assumptions section)     |
| Decisions deferred   | 8 (Pass 7 table)                            |
| Overall design score | 2.5/10 -> est. 8/10 if tasks land           |
+====================================================================+
```

## Verdict

**REVISE.** The plan's demand-side engineering is genuinely strong — kill
criteria, denominators, contract tests, floor machines. But it commits the
exact error that killed v1: treating chrome quality as an outcome to hope for
rather than a thing to specify and rehearse. The founder's #1 pain deserves the
same rigor the retrieval pipeline got: tokens, states, motion numbers, a
failable Zen-bar checklist, and a weekly screenshot ritual. All fixes are
documentation-stage (roughly 1.5 days total), none threaten the 5-week
timeline, and T2/T5 protect the one scope decision the plan already got right.

**UNRESOLVED DECISIONS:**
- Sidebar modes: pinned + collapse-to-rail recommended; compact-overlay deferred (needs founder confirm)
- Ask surface: docked panel vs overlay sheet
- Traffic-light placement inside sidebar header
- Default theme (dark recommended) and theming contract
- Tab overflow strategy at 40+ tabs
- First-run download/empty-state sequence
- Citation click-through presentation
- Numeric switcher-timebox trigger
