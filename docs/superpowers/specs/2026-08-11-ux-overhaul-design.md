# Hive UX Overhaul — Design Spec

> **Date:** 2026-08-11
> **Status:** Approved (design), awaiting implementation plan
> **Scope:** Full redesign of the Hive Browser chrome — native SwiftUI and web chrome shell — as two complete, opinionated modes sharing one token contract.
> **Reference sources:** Chromium `layout_constants.cc`, Zen browser source (`src/zen/common/styles/`), Brave Leo design tokens (`src/tokens/browser.tokens.json`), in-repo Polar package, in-repo Brief package, Comet design research, Dia design research.

---

## 1. Vision

Hive has **two full postures**, and users pick one and live there. Each must be *complete*, not a compromise.

| | **Chrome Mode** (horizontal) | **Zen Mode** (vertical) |
|---|---|---|
| Feels like | Chrome M3 — familiar, dense, trustworthy | Arc/Zen/Dia — minimal, floating, distinctive |
| Tab posture | 34px pill strip on top, grouped, scrollable | Sidebar: space rail → Essentials → Pinned → tabs, 74px icon-rail collapse |
| Chrome treatment | Classic toolbar + omnibox pill + M3 surface tint | Floating glass over an ambient canvas; auto-hide pill |
| Character | Utilitarian precision — every pixel does work | Negative space + craft — content is the star |
| Who | Migrating Chrome users who want familiarity | Power users who live in vertical tabs |

Dia's positioning validates this: *"Imagine Chrome, only with far more design polish and playful animations, built around an AI-first environment."* Hive ships that polish as two complete looks instead of one compromise.

**Shared DNA (both modes):** the same honey accent, the same type ramp, the same surface ladder, the same spring language, the same component shapes. The modes differ in *chrome density and material*, never in identity.

---

## 2. The Token Contract (fixes "not one product")

The core structural sin: native `HiveDesign` and web `tokens.css` are two systems that happen to share an accent. Both get rebuilt against one canonical spec.

### 2.1 What carries forward
- Honey palette (`.hiveAccent` #F97316), warm mahogany neutrals
- Surface ladder principle (depth from luminosity, not drop shadows)
- The spring animation table (`HiveDesign.Animation`)
- 4px spacing grid, unified radius scale
- Reduced-motion contract

### 2.2 New canonical enums in `HiveDesign`
- `HiveDesign.Chrome` — every horizontal-mode chrome dimension (Section 4)
- `HiveDesign.Zen` — every vertical-mode chrome dimension (Section 5)
- `HiveDesign.Elevation` — the three elevation recipes (Section 3)

### 2.3 `tokens.css` v2
The web chrome's Polar-derived neutral ramp is replaced with exact hex equivalents of the `.hive*` surface colors. Same accent, same spacing steps, same `--spring-*` table, same icon stroke width (1.8), same elevation recipes. One ramp, two encodings (Swift Color + CSS hex).

---

## 3. Depth & Elevation (source: Brave Leo + Polar)

- **Cards / panels / rows:** no drop shadow. Surface ladder (canvas → level1 → level2 → level3) provides depth. Confirmed by Polar `--shadow-card: none`.
- **Elevated** (context menus, popovers, dropdowns): Brave Leo's exact recipe —
  `0 4px 8px rgba(0,0,0,.10), 0 1px 2px rgba(0,0,0,.10), inset 0 1px .5px rgba(255,255,255,.32)`
  (two-layer soft shadow + subtle top inner highlight; Leo source: `radius:8/offsetY:4 #0000001a`, `radius:2/offsetY:1 #0000001a`, `radius:.5/offsetY:1 #ffffff52`).
- **Overlay** (sheets, modals): Polar `0 16px 48px rgba(0,0,0,.55)`.
- **Hover surfaces:** 8% white (Chrome-mode, matches Chromium hover fill), 10% white (Zen-mode, Zen `--zen-toolbar-element-bg-hover`).

---

## 4. Chrome Mode — Horizontal (source: Chromium `layout_constants.cc`)

| Element | Value | Source |
|---|---|---|
| Tab height | 34px | `kTabHeight` |
| Tab strip padding | 6px | `kTabStripPadding` |
| Tab close button | 14px | `kTabCloseButtonSize` |
| Tab pre/post title padding | 8px / 4px | `kTabPreTitlePadding` / `kTabAfterTitlePadding` |
| Tab max width | 240px | existing Hive (`HiveDesign.Tab.maxWidth`) |
| Omnibox height | 34px | `kLocationBarHeight` |
| Omnibox child corner radius | 12px | `kLocationBarChildCornerRadius` |
| Omnibox icons | 16px | `kLocationBarIconSize` |
| Omnibox internal spacing | 4px | `kLocationBarChildInternalSpacing` |
| Toolbar element padding | 4px | `kToolbarElementPadding` |
| Toolbar icon default margin | 2px | `kToolbarIconDefaultMargin` |
| Location bar margin | 9px | `kLocationBarMargin` |
| Toolbar corner radius | 8px | `kToolbarCornerRadius` |
| Toolbar divider | 2px wide, 9px spacing | `kToolbarDividerWidth` / `kToolbarDividerSpacing` |
| Icon hit area | 32–36px (Chrome convention) | existing Hive `HitTarget` |

### 4.1 Signature details
- **M3 surface tint:** toolbar picks up ~4% tint of the active page's theme color; falls back to canvas when unavailable. (Approved.)
- Active tab = filled surface + 2px honey indicator; hover = 8% white.
- Grouped tabs: colored 8px-radius headers with name + count chip (already wired in web chrome; port to native).
- Panels: right-side 320px, level1, 12px radius, 44px header.

---

## 5. Zen Mode — Vertical (source: Chromium vertical-tab constants + Zen browser)

| Element | Value | Source |
|---|---|---|
| Sidebar expanded / max | 240px / 360px | existing Hive |
| Compact icon rail | 74px | Zen `--zen-toolbox-max-width` |
| Vertical tab height | 30px | Chromium `kVerticalTabHeight` |
| Pinned tab height | 32px | `kVerticalTabPinnedHeight` |
| Vertical tab min width | 32px | `kVerticalTabMinWidth` |
| Strip horizontal padding | 12px | `kVerticalTabStripHorizontalPadding` |
| Strip vertical padding (expanded/collapsed) | 12px / 8px | `kVerticalTabStripUncollapsedVerticalPadding` / `kVerticalTabStripCollapsedVerticalPadding` |
| Vertical tab corner radius | 8px | `kVerticalTabCornerRadius` |
| New-tab / collapse buttons | 32px | `kVerticalTabStripNewTabButtonSize` / `kVerticalTabStripCollapseButtonSize` |
| Toolbar height | 37px | Zen `--zen-toolbar-height` |
| Floating chrome gap | 10px | Zen `--zen-compact-float` |
| Floating reveal duration | 0.25s | Zen `--zen-compact-mode-time` |
| Floating omnibox | pill, 50px radius, 28px tall | Zen `zen-omnibox.css` |
| Hover weight | 10% white | Zen `--zen-toolbar-element-bg-hover` |
| Active-tab scale | 0.985 | Zen `--zen-active-tab-scale` |
| Content edge | 1px border + 8px rounded | Zen `--zen-appcontent-border` / Chromium `kToolbarCornerRadius` |
| Canvas (dark) | #1b1b1b | Zen `--zen-main-browser-background` |
| Toolbar buttons | 16px, 6px inner padding | Zen `--zen-toolbar-button-size` / `--zen-toolbar-button-inner-padding` |
| Traffic lights | overlay sidebar top-left | Zen `--zen-traffic-light-size` (6–7px) |

### 5.1 Sidebar structure (top → bottom)
1. **Space switcher rail** — 48px strip of gradient space icons + "+", active indicator dot, hover pop (Arc).
2. **Essentials** — 64px tiles, favicon + label (Arc).
3. **Pinned** — 32px rows, bold (Chromium pinned height).
4. **Tabs** — 30px rows, 8px radius, favicon + truncated title; hover reveals close/mute inline. Active = honey-muted wash; sleeping tabs desaturated (Zen).

### 5.2 Floating chrome (the Dia/Zen signature)
- Toolbar + address bar float as a **glass pill** over the content's top edge.
- Scroll down auto-hides; scroll up returns. 10px offset, 0.25s ease.
- Web content sits on an ambient canvas with a rounded, separated outer edge: ~8px rounded window interior, 1px fractional border, subtle canvas glow behind the page (Zen `content-element-separation`).
- Unfocused windows dim their accent (Zen inactive-window grey-out).

---

## 6. States & Motion (one contract, both modes)

| State | Rule |
|---|---|
| Hover | level2 / 8% white (Chrome mode) or 10% white (Zen mode, per Section 3), 120ms quick spring |
| Press | level3 / 12% white, 80ms |
| Focus ring | 2px honey, 3px gap, always visible on keyboard nav, hidden on mouse |
| Selected/active | honey-muted wash (12%) |
| Disabled | 35% opacity |

**Motion:** reuse `HiveDesign.Animation` springs. Micro 80–120ms; chrome transitions 250–350ms with overshoot; entrance choreography staggered 50ms capped at 500ms; workspace switch crossfade + 8px directional slide; tab close 160ms collapse + reflow. **Reduced Motion:** all collapses to 80ms opacity fades.

---

## 7. Editorial Identity (source: in-repo Brief package + Comet research)

- Start page and knowledge surfaces: warm canvas `#111`, honey accent, **1160px measure** (Brief `--content-max`).
- **8–16px radius band** for cards/panels everywhere (Comet's friendly, modern, consumer-grade feel).
- Editorial serif display + SF body on the start page; generous line-height; existing Hive micro-label system stays.
- Yellow `#FFE500` is *not* adopted for Hive brand — reserved as a reference for the editorial direction only; honey remains the brand accent.

---

## 8. Web Chrome Alignment

1. **Tokens:** replace the Polar-derived neutral ramp with exact hex equivalents of `.hiveCanvas/.hiveSurface1/2/3/.hiveHairline`; same accent, spacing, `--spring-*` table, icon stroke.
2. **Geometry:** the web chrome consumes the same chrome-mode numbers (34px tabs, 6px strip padding, 34px/12px omnibox, 8% hover, 2px/3px focus ring).
3. **States:** same hover/press/focus rules in CSS.
4. **Signatures carry over:** M3 surface tint, tab audio badges, sleeping-tab desaturation, progress bar.

---

## 9. Product Ideas Absorbed (Dia/Comet)

- **Omnibox as universal command center** — ⌘K and ⌘L converge on one mental model.
- **Organized tabs** — auto-named, auto-grouped (Chrome-mode; `createTabGroup` already wired in web chrome, extend natively).
- **Remembered splits** per routine (Dia) — split state persists per space.
- **Sidecar AI panel** — right-side 320px (Comet; formalize the existing agent dock geometry).
- **Morning Brief** — the start page's hero keeps the editorial treatment.

These are *absorbed into the design language*; core chrome geometry is the spec's primary scope. Items flagged for later phases (Section 10) are not part of the P0 implementation plan.

---

## 10. Implementation Phasing

| Phase | Scope | Verify |
|---|---|---|
| **P0** | Token contract: `HiveDesign.Chrome`/`.Zen`/`.Elevation` enums + `tokens.css` v2 with spec values | `swift build`, JS syntax check |
| **P1** | Chrome mode: native toolbar/tabs/omnibox/panels rebuild against `HiveDesign.Chrome` | build + per-view visual checklist |
| **P2** | Zen mode: sidebar zones, floating auto-hide pill, ambient canvas, rounded content edge | build + per-view visual checklist |
| **P3** | Web chrome alignment (tokens + geometry + states + surface tint) | build + JS check |
| **P4** | State/motion polish pass, reduced-motion audit, final review | code review + full test |

Each phase ships as its own commit. Every value in the spec is the acceptance target; no drift without updating this document.

**Deferred (not in P0–P4):** organized-tab auto-naming, remembered splits, sidecar geometry formalization beyond current state, Zen-mode accent dimming on unfocused windows (if complexity exceeds phase budget — revisit in P4 review).

---

## 11. Validation

- `swift build` green after every phase; `node -c` on web chrome JS; `swift test` at phase ends.
- A per-view visual checklist accompanies each phase (spacing on the 4px grid, no overlap, correct radius per this spec, hover/press/focus states present, reduced-motion honored).
- Final code review (code-reviewer) before each phase commit.
